//
//  HostViewController.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "HostViewController.h"

#import "AudioEngineHost.h"
#import "HostSession.h"
#import "HostTrackFile.h"
#import "MidiPortManager.h"
#import "MidiSettingsViewController.h"
#import "TransportCommands.h"
#import "WelcomeViewController.h"

static NSString* const kWelcomeShownKey = @"welcome.shown";
static NSString* const kDocumentNameKey = @"document.name";
static NSString* const kDocumentBookmarkKey = @"document.bookmark";

// which document-picker flow is in flight (the delegate is shared).
typedef NS_ENUM(NSInteger, HostPickerOperation) {
    HostPickerOperationNone = 0,
    HostPickerOperationImportMidi,
    HostPickerOperationExportMidi,
    HostPickerOperationOpenSession,
    HostPickerOperationSaveSession,
};

@interface HostViewController () <UIDocumentPickerDelegate>
@end

@implementation HostViewController {
    AudioEngineHost* _host;
    MidiPortManager* _portManager;
    UIViewController* _pluginViewController;
    UIActivityIndicatorView* _spinner;
    UILabel* _tempoLabel;
    UILabel* _titleLabel;
    double _tempoAccumulator;
    CGFloat _tempoLastX;

    // current document: the name shown in the window title and used as the default
    // export/save name, the open session's file URL (for in-place Save), and which
    // picker flow is in flight.
    NSString* _documentName;
    NSURL* _currentSessionURL;
    HostPickerOperation _pendingPickerOperation;

    // a session file handed to us before the AU finished instantiating (cold
    // launch via "Open in…"); opened once instantiation completes.
    NSURL* _pendingOpenURL;
    BOOL _pendingOpenInPlace;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.color = [UIColor whiteColor];
    [self.view addSubview:_spinner];
    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    [_spinner startAnimating];

    _host = [[AudioEngineHost alloc] init];
    _host.tempo = [self savedTempo];

    _portManager = [[MidiPortManager alloc] init];
    _portManager.host = _host;
    _host.delegate = _portManager;

    // autosave the working session when the app is backgrounded or quit, so a
    // recording isn't lost on exit.
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(saveAutosave)
                   name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(saveAutosave)
                   name:UIApplicationWillTerminateNotification object:nil];

    __weak HostViewController* weakSelf = self;
    [_host instantiateWithCompletion:^(NSError* _Nullable error) {
        HostViewController* strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf->_spinner stopAnimating];
        if (error != nil) {
            [strongSelf presentInstantiationError:error];
            return;
        }
        [strongSelf embedPluginViewController];
        [strongSelf->_portManager start];
        [strongSelf restoreAutosaveIfAvailable];
        // a file we were launched with takes precedence over the restored autosave.
        if (strongSelf->_pendingOpenURL != nil) {
            NSURL* url = strongSelf->_pendingOpenURL;
            BOOL inPlace = strongSelf->_pendingOpenInPlace;
            strongSelf->_pendingOpenURL = nil;
            [strongSelf openSessionURL:url inPlace:inPlace];
        }
        [strongSelf maybeShowWelcome];
    }];
}

#pragma mark - Session persistence

- (NSURL*)autosaveURL {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* directory = [fm URLForDirectory:NSApplicationSupportDirectory
                                  inDomain:NSUserDomainMask
                         appropriateForURL:nil
                                    create:YES
                                     error:nil];
    return [directory URLByAppendingPathComponent:@"Autosave.mtrec"];
}

// a session document (full state + tempo) of the current state.
- (NSData*)currentSessionData {
    if (!_host.isRunning) {
        return nil;
    }
    return [HostSession dataWithFullState:(_host.fullState ?: @{}) tempo:_host.tempo];
}

- (void)saveAutosave {
    NSData* data = [self currentSessionData];
    if (data != nil) {
        [data writeToURL:[self autosaveURL] atomically:YES];
    }
}

- (void)restoreAutosaveIfAvailable {
    NSData* data = [NSData dataWithContentsOfURL:[self autosaveURL]];
    if (data == nil) {
        return;
    }
    NSDictionary* fullState = nil;
    double tempo = _host.tempo;
    if ([HostSession readData:data fullState:&fullState tempo:&tempo]) {
        [self applySessionContent:fullState tempo:tempo];
        // restoring the state shouldn't leave an undoable step on launch.
        [_host triggerParameterWithIdentifier:@"clearUndoHistory"];
        // restore the document's name and file handle saved alongside the autosave,
        // so the working session keeps its identity (and Save/Rename) across launches
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        _documentName = [defaults stringForKey:kDocumentNameKey];
        _currentSessionURL = [self urlForBookmark:[defaults dataForKey:kDocumentBookmarkKey]];
        [self documentChanged];
    }
}

// applies a session's content (tracks + tempo) without changing the current
// document's name or file.
- (void)applySessionContent:(NSDictionary*)fullState tempo:(double)tempo {
    _host.tempo = tempo;
    [[NSUserDefaults standardUserDefaults] setDouble:tempo forKey:kHostTempoKey];
    _host.fullState = fullState;
}

// applies a session's content and makes it the current named document.
- (void)applySessionFullState:(NSDictionary*)fullState tempo:(double)tempo
                         name:(NSString*)name url:(NSURL*)url {
    [self applySessionContent:fullState tempo:tempo];
    [self setDocumentName:name url:url];
}

// sets the current document identity (name shown in the title; URL for in-place
// Save/Rename within this run), persists the name so it survives relaunch, and
// refreshes the UI.
- (void)setDocumentName:(NSString*)name url:(NSURL*)url {
    _documentName = name;
    _currentSessionURL = url;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if (name.length > 0) {
        [defaults setObject:name forKey:kDocumentNameKey];
    }
    else {
        [defaults removeObjectForKey:kDocumentNameKey];
    }

    // persist a security-scoped bookmark so the file handle survives relaunch
    // (enabling Save and Rename without re-picking the location).
    NSData* bookmark = url != nil ? [self bookmarkForURL:url] : nil;
    if (bookmark != nil) {
        [defaults setObject:bookmark forKey:kDocumentBookmarkKey];
    }
    else {
        [defaults removeObjectForKey:kDocumentBookmarkKey];
    }

    [self documentChanged];
}

// creates a security-scoped bookmark for a user-chosen file. the creation option
// differs by platform (macOS requires the security-scope flag; iOS does not).
- (NSData*)bookmarkForURL:(NSURL*)url {
    NSURLBookmarkCreationOptions options = 0;
#if TARGET_OS_MACCATALYST
    options = NSURLBookmarkCreationWithSecurityScope;
#endif
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData* bookmark = [url bookmarkDataWithOptions:options
                    includingResourceValuesForKeys:nil
                                     relativeToURL:nil
                                             error:nil];
    if (scoped) {
        [url stopAccessingSecurityScopedResource];
    }
    return bookmark;
}

// resolves a stored bookmark back to its (security-scoped) URL, or nil if it can't
// be resolved (e.g. the file moved or was deleted).
- (NSURL*)urlForBookmark:(NSData*)bookmark {
    if (bookmark == nil) {
        return nil;
    }
    NSURLBookmarkResolutionOptions options = 0;
#if TARGET_OS_MACCATALYST
    options = NSURLBookmarkResolutionWithSecurityScope;
#endif
    BOOL stale = NO;
    NSURL* url = [NSURL URLByResolvingBookmarkData:bookmark
                                          options:options
                                    relativeToURL:nil
                              bookmarkDataIsStale:&stale
                                            error:nil];
    return url;
}

// reflects a document change in the UI (the window title, on Mac).
- (void)documentChanged {
#if TARGET_OS_MACCATALYST
    [self updateMacWindowTitle];
#else
    // lead the iOS top bar with the current document name (without extension);
    // an unsaved session reads as "Untitled".
    if (_titleLabel != nil) {
        _titleLabel.text = _documentName.length > 0 ? _documentName.stringByDeletingPathExtension
                                                    : @"Untitled";
    }
#endif
}

// shows the welcome screen once, on the first launch.
- (void)maybeShowWelcome {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kWelcomeShownKey]) {
        return;
    }
    [defaults setBool:YES forKey:kWelcomeShownKey];
    [self showWelcome:nil];
}

// presents the welcome screen on demand (from the menu / settings).
- (void)showWelcome:(id)sender {
    WelcomeViewController* welcome = [[WelcomeViewController alloc] init];
    welcome.modalPresentationStyle = UIModalPresentationFormSheet;
    __weak HostViewController* weakSelf = self;
    welcome.onOpenSettings = ^{
        [weakSelf showSettings];
    };
    [self presentViewController:welcome animated:YES completion:nil];
}

- (double)savedTempo {
    double tempo = [[NSUserDefaults standardUserDefaults] doubleForKey:kHostTempoKey];
    return tempo > 0 ? tempo : 120.0;
}

#if TARGET_OS_MACCATALYST
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateMacWindowTitle];
}

// on Mac there's no on-screen tempo readout, so the window title carries the full
// app name plus the live BPM and, when applicable, that the tempo is driven by
// incoming MIDI clock. (The title otherwise falls back to the abbreviated display
// name; this doesn't change the name under the icon.)
- (void)updateMacWindowTitle {
    UIWindowScene* scene = self.view.window.windowScene;
    if (scene == nil) {
        return;
    }
    // lead with the current document's name (session or imported MIDI), without
    // its extension; an unsaved session reads as "Untitled" (document convention).
    NSString* lead = _documentName.length > 0 ? _documentName.stringByDeletingPathExtension
                                              : @"Untitled";
    NSString* title = [NSString stringWithFormat:@"%@ - %d BPM", lead, (int)lround(_host.tempo)];
    if (_portManager.followClock && _portManager.clockActive) {
        title = [title stringByAppendingString:@" · MIDI clock"];
    }
    scene.title = title;
}
#endif

#pragma mark - Session commands

// starts a fresh, untitled session after confirmation (clears all tracks).
- (void)newSession:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"New Session?"
                                            message:@"This clears all tracks and starts over."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak HostViewController* weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"New Session"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
        HostViewController* strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf->_host clearAllTracks];
        [strongSelf resetSessionArrangement];
        [strongSelf setDocumentName:nil url:nil];
        // fire last so the plugin discards the undo steps registered by the
        // clear/reset above instead of letting the user undo back into the
        // previous session.
        [strongSelf->_host triggerParameterWithIdentifier:@"clearUndoHistory"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// resets the per-track and transport arrangement (and tempo) to defaults for a
// clean session. clearAllTracks already clears recordings, locators and the
// detected MPE config; this covers the toggles and tempo that otherwise carry
// over. device routing and global preferences are intentionally left as-is, since
// they aren't part of a session's musical content.
- (void)resetSessionArrangement {
    NSArray<NSString*>* turnOff = @[
        @"record1", @"record2", @"record3", @"record4",
        @"monitor1", @"monitor2", @"monitor3", @"monitor4",
        @"mute1", @"mute2", @"mute3", @"mute4",
        @"repeat", @"grid", @"punchInOut",
    ];
    for (NSString* parameter in turnOff) {
        [_host setParameterWithIdentifier:parameter value:0.0f];
    }
    [_host setParameterWithIdentifier:@"chase" value:1.0f];  // chase is on by default

    // reset the tempo to the default for a new session
    _host.tempo = 120.0;
    [[NSUserDefaults standardUserDefaults] setDouble:120.0 forKey:kHostTempoKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:MidiPortManagerDidUpdateTempoNotification
                                                        object:nil];
}

// opens a .mtrec session, replacing the current tracks and settings.
- (void)openSession:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    _pendingPickerOperation = HostPickerOperationOpenSession;
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ HostSessionUTI ]
                                                              inMode:UIDocumentPickerModeOpen];
    picker.title = @"Open Session";
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// saves to the current session file, or prompts for a location if untitled.
- (void)saveSession:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    if (_currentSessionURL == nil) {
        [self saveSessionAs:sender];
        return;
    }
    NSData* data = [self currentSessionData];
    if (data == nil) {
        return;
    }
    BOOL scoped = [_currentSessionURL startAccessingSecurityScopedResource];
    [data writeToURL:_currentSessionURL atomically:YES];
    if (scoped) {
        [_currentSessionURL stopAccessingSecurityScopedResource];
    }
}

// prompts for a name, then writes the session to a location the user chooses.
- (void)saveSessionAs:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    NSString* base = _documentName.length > 0 ? _documentName.stringByDeletingPathExtension : @"Untitled";
    __weak HostViewController* weakSelf = self;
    [self promptForSessionName:base
                         title:@"Save Session"
                    saveButton:@"Save"
                    completion:^(NSString* name) {
        [weakSelf exportSessionWithName:name];
    }];
}

// renames the current session's file in place. only valid once the session has
// been saved (the menu item / sheet action is disabled otherwise).
- (void)renameSession:(id)sender {
    if (!_host.isRunning || _currentSessionURL == nil) {
        return;
    }
    NSString* current = _currentSessionURL.lastPathComponent.stringByDeletingPathExtension;
    __weak HostViewController* weakSelf = self;
    [self promptForSessionName:current
                         title:@"Rename Session"
                    saveButton:@"Rename"
                    completion:^(NSString* name) {
        [weakSelf renameCurrentSessionTo:name];
    }];
}

// a text-field alert for naming a session. calls completion with a non-empty,
// filename-safe name (without extension).
- (void)promptForSessionName:(NSString*)defaultName
                       title:(NSString*)title
                  saveButton:(NSString*)saveButton
                  completion:(void (^)(NSString* name))completion {
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:@"Name your session."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
        field.text = defaultName;
        field.placeholder = @"Session name";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:saveButton
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
        NSString* entered = [alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (entered.length == 0) {
            entered = defaultName.length > 0 ? defaultName : @"Untitled";
        }
        completion(entered);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// strips characters that aren't valid in a file name.
- (NSString*)sanitizedFileName:(NSString*)name {
    NSCharacterSet* illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\:?%*|\"<>"];
    NSString* clean = [[name componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@"-"];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return clean.length > 0 ? clean : @"Untitled";
}

- (void)exportSessionWithName:(NSString*)name {
    NSData* data = [self currentSessionData];
    if (data == nil) {
        return;
    }
    NSString* fileName = [[self sanitizedFileName:name] stringByAppendingPathExtension:HostSessionFileExtension];
    NSURL* url = [[NSFileManager.defaultManager temporaryDirectory] URLByAppendingPathComponent:fileName];
    [data writeToURL:url atomically:YES];

    _pendingPickerOperation = HostPickerOperationSaveSession;
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithURL:url
                                                     inMode:UIDocumentPickerModeExportToService];
    picker.title = @"Save Session";
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// renames the current session's file in place (within its own folder).
- (void)renameCurrentSessionTo:(NSString*)name {
    NSURL* directory = _currentSessionURL.URLByDeletingLastPathComponent;
    NSString* fileName = [[self sanitizedFileName:name] stringByAppendingPathExtension:HostSessionFileExtension];
    NSURL* newURL = [directory URLByAppendingPathComponent:fileName];
    if ([newURL isEqual:_currentSessionURL]) {
        return;
    }

    BOOL scoped = [_currentSessionURL startAccessingSecurityScopedResource];
    NSError* error = nil;
    BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:_currentSessionURL toURL:newURL error:&error];
    if (scoped) {
        [_currentSessionURL stopAccessingSecurityScopedResource];
    }

    if (moved) {
        [self setDocumentName:newURL.lastPathComponent url:newURL];
    }
    else {
        [self presentMessage:@"Rename Failed"
                        body:@"The session file couldn't be renamed in its current location."];
    }
}

#pragma mark - Track file commands (macOS menu bar)

// replaces all tracks with the contents of a chosen MIDI file.
- (void)importAllTracks:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    _pendingPickerOperation = HostPickerOperationImportMidi;
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.midi-audio" ]
                                                              inMode:UIDocumentPickerModeImport];
    picker.title = @"Import All Tracks";
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// writes all recorded tracks to a MIDI file the user chooses a destination for.
- (void)exportAllTracks:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    NSData* file = [HostTrackFile midiFileFromFullState:(_host.fullState ?: @{}) tempo:_host.tempo];
    if (file == nil) {
        [self presentMessage:@"Nothing to Export"
                        body:@"Record or import some MIDI before exporting."];
        return;
    }

    NSString* base = _documentName.length > 0 ? _documentName.stringByDeletingPathExtension : @"MIDI Tape Recorder";
    NSString* name = [base stringByAppendingPathExtension:@"mid"];
    NSURL* url = [[NSFileManager.defaultManager temporaryDirectory] URLByAppendingPathComponent:name];
    [file writeToURL:url atomically:YES];

    _pendingPickerOperation = HostPickerOperationExportMidi;
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithURL:url
                                                     inMode:UIDocumentPickerModeExportToService];
    picker.title = @"Export All Tracks";
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

// clears every track, after confirmation.
- (void)clearAllTracks:(id)sender {
    if (!_host.isRunning) {
        return;
    }
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Clear All Tracks?"
                                            message:@"This removes the recordings from every track."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak HostViewController* weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear All"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
        HostViewController* strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf->_host clearAllTracks];
        [strongSelf setDocumentName:nil url:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    HostPickerOperation operation = _pendingPickerOperation;
    _pendingPickerOperation = HostPickerOperationNone;

    if (urls.count == 0) {
        return;
    }
    NSURL* url = urls[0];

    switch (operation) {
        case HostPickerOperationImportMidi:
            [self importMidiFromURL:url];
            break;
        case HostPickerOperationOpenSession:
            [self openSessionFromURL:url];
            break;
        case HostPickerOperationSaveSession:
            // the export copy is now the current session document
            [self setDocumentName:url.lastPathComponent url:url];
            break;
        case HostPickerOperationExportMidi:
        case HostPickerOperationNone:
            break;
    }
}

- (void)importMidiFromURL:(NSURL*)url {
    NSData* data = [NSData dataWithContentsOfURL:url];
    NSString* name = url.lastPathComponent;
    // import mode hands us a temporary copy; clean it up
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    NSDictionary* newState = [HostTrackFile fullStateByImporting:data
                                                   intoFullState:(_host.fullState ?: @{})];
    if (newState == nil) {
        [self presentMessage:@"Import Failed"
                        body:@"This file isn't a MIDI file the recorder can read."];
        return;
    }

    _host.fullState = newState;
    // importing MIDI into the session makes it the current (untitled) document
    [self setDocumentName:name url:nil];
}

// entry point for files handed to the app from outside (see the header). defers
// until the AU is running, then either adopts the file as the current document
// (in place) or loads a copy's content and discards it.
- (void)openSessionURL:(NSURL*)url inPlace:(BOOL)inPlace {
    if (url == nil) {
        return;
    }
    if (!_host.isRunning) {
        _pendingOpenURL = url;
        _pendingOpenInPlace = inPlace;
        return;
    }

    if (inPlace) {
        [self openSessionFromURL:url];
        return;
    }

    // a throwaway copy (e.g. dropped in our Documents/Inbox). load its content as
    // a named-but-unsaved session, then remove the copy so it doesn't linger.
    NSData* data = [NSData dataWithContentsOfURL:url];
    NSDictionary* fullState = nil;
    double tempo = _host.tempo;
    if (![HostSession readData:data fullState:&fullState tempo:&tempo]) {
        [self presentMessage:@"Open Failed"
                        body:@"This isn't a MIDI Tape Recorder session file."];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        return;
    }
    [self applySessionFullState:fullState tempo:tempo name:url.lastPathComponent url:nil];
    [_host triggerParameterWithIdentifier:@"clearUndoHistory"];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

- (void)openSessionFromURL:(NSURL*)url {
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData* data = [NSData dataWithContentsOfURL:url];
    if (scoped) {
        [url stopAccessingSecurityScopedResource];
    }

    NSDictionary* fullState = nil;
    double tempo = _host.tempo;
    if (![HostSession readData:data fullState:&fullState tempo:&tempo]) {
        [self presentMessage:@"Open Failed"
                        body:@"This isn't a MIDI Tape Recorder session file."];
        return;
    }
    [self applySessionFullState:fullState tempo:tempo name:url.lastPathComponent url:url];
    // loading a session shouldn't leave undo steps that reach back into the
    // previous document's content.
    [_host triggerParameterWithIdentifier:@"clearUndoHistory"];
}

- (void)presentMessage:(NSString*)title body:(NSString*)body {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:body
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Transport key commands

// shared action for every transport/track command, driven from the macOS menu bar
// and from hardware-keyboard UIKeyCommands. the command identifier rides along in
// the sender's property list.
- (void)performTransportCommand:(id)sender {
    NSString* identifier = nil;
    if ([sender respondsToSelector:@selector(propertyList)]) {
        id propertyList = [sender propertyList];
        if ([propertyList isKindOfClass:[NSString class]]) {
            identifier = propertyList;
        }
    }
    if (identifier == nil || !_host.isRunning) {
        return;
    }

    MTRTransportCommand* command = [MTRTransportCommands commandForIdentifier:identifier];
    if (command == nil) {
        return;
    }
    if (command.kind == MTRCommandKindTrigger) {
        [_host triggerParameterWithIdentifier:command.parameterIdentifier];
    }
    else {
        [_host toggleParameterWithIdentifier:command.parameterIdentifier];
    }
}

// mirror undo/redo availability onto their menu items (and key commands), matching
// the plugin's own enabled/disabled buttons. the plugin pushes the live
// canUndo/canRedo parameter values across the boundary.
- (void)validateCommand:(UICommand*)command {
    [super validateCommand:command];

    // rename only applies once the session exists as a saved file.
    if (command.action == @selector(renameSession:)) {
        [self setCommand:command disabled:(_currentSessionURL == nil)];
        return;
    }

    if (command.action != @selector(performTransportCommand:) ||
        ![command.propertyList isKindOfClass:[NSString class]]) {
        return;
    }
    NSString* identifier = command.propertyList;

    NSString* availabilityParameter = nil;
    if ([identifier isEqualToString:@"undo"]) {
        availabilityParameter = @"canUndo";
    }
    else if ([identifier isEqualToString:@"redo"]) {
        availabilityParameter = @"canRedo";
    }
    if (availabilityParameter == nil) {
        return;  // other commands stay enabled
    }

    [self setCommand:command disabled:!(_host.isRunning && [_host parameterIsOn:availabilityParameter])];
}

- (void)setCommand:(UICommand*)command disabled:(BOOL)disabled {
    if (disabled) {
        command.attributes |= UIMenuElementAttributesDisabled;
    }
    else {
        command.attributes &= ~UIMenuElementAttributesDisabled;
    }
}

#if !TARGET_OS_MACCATALYST
// on iOS/iPadOS there is no menu bar, so the commands are offered to a hardware
// keyboard through the responder chain. (On Mac they live in the Transport menu.)
- (NSArray<UIKeyCommand*>*)keyCommands {
    NSMutableArray<UIKeyCommand*>* commands = [NSMutableArray array];
    for (MTRTransportCommand* command in [MTRTransportCommands allCommands]) {
        if (command.shortcutInput.length == 0) {
            continue;
        }
        // title + propertyList are set at creation (both are read-only afterwards)
        UIKeyCommand* keyCommand = [UIKeyCommand commandWithTitle:command.title
                                                            image:nil
                                                           action:@selector(performTransportCommand:)
                                                            input:command.shortcutInput
                                                    modifierFlags:command.shortcutModifiers
                                                     propertyList:command.identifier];
        if (@available(iOS 15.0, *)) {
            keyCommand.wantsPriorityOverSystemBehavior = YES;
        }
        [commands addObject:keyCommand];
    }
    return commands;
}
#endif

- (void)embedPluginViewController {
    UIViewController* plugin = _host.pluginViewController;
    if (plugin == nil) {
        return;
    }
    _pluginViewController = plugin;

    UILayoutGuide* guide = self.view.safeAreaLayoutGuide;

    // the plugin's view pins to the safe area. on iPhone/iPad a slim app bar sits
    // above it holding the settings entry; on Mac the settings are in the menu bar
    // (see AppDelegate's buildMenuWithBuilder:) so the plugin fills to the top.
    NSLayoutYAxisAnchor* pluginTop = guide.topAnchor;
#if !TARGET_OS_MACCATALYST
    UIView* topBar = [self makeTopBar];
    [self.view addSubview:topBar];
    [NSLayoutConstraint activateConstraints:@[
        [topBar.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [topBar.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [topBar.heightAnchor constraintEqualToConstant:44],
    ]];
    pluginTop = topBar.bottomAnchor;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTempoLabel)
                                                 name:MidiPortManagerDidUpdateTempoNotification
                                               object:nil];
#endif

#if TARGET_OS_MACCATALYST
    // keep the window-title BPM readout live as the tempo or clock state changes.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateMacWindowTitle)
                                                 name:MidiPortManagerDidUpdateTempoNotification
                                               object:nil];
#endif

    [self addChildViewController:plugin];
    plugin.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:plugin.view];
    [NSLayoutConstraint activateConstraints:@[
        [plugin.view.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [plugin.view.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [plugin.view.topAnchor constraintEqualToAnchor:pluginTop],
        [plugin.view.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
    ]];
    [plugin didMoveToParentViewController:self];
}

#if !TARGET_OS_MACCATALYST
// a slim app bar with the app name, a live tempo readout and a settings button,
// used on iPhone/iPad.
- (UIView*)makeTopBar {
    UIView* bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [UIColor blackColor];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Untitled";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [bar addSubview:title];
    _titleLabel = title;

    _tempoLabel = [[UILabel alloc] init];
    _tempoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _tempoLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    _tempoLabel.textAlignment = NSTextAlignmentRight;
    [_tempoLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_tempoLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    // the tempo readout is interactive: drag left/right to nudge, tap to type a value.
    _tempoLabel.userInteractionEnabled = YES;
    [_tempoLabel addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(tempoPanned:)]];
    [_tempoLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tempoTapped:)]];
    [bar addSubview:_tempoLabel];

    UIButton* settings = [UIButton buttonWithType:UIButtonTypeSystem];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    [settings setTitle:@"MIDI Settings" forState:UIControlStateNormal];
    settings.titleLabel.font = [UIFont systemFontOfSize:16];
    settings.tintColor = [UIColor whiteColor];
    [settings addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:settings];

    UIButton* sessions = [UIButton buttonWithType:UIButtonTypeSystem];
    sessions.translatesAutoresizingMaskIntoConstraints = NO;
    [sessions setTitle:@"Sessions" forState:UIControlStateNormal];
    sessions.titleLabel.font = [UIFont systemFontOfSize:16];
    sessions.tintColor = [UIColor whiteColor];
    [sessions addTarget:self action:@selector(showSessionsMenu:) forControlEvents:UIControlEventTouchUpInside];
    [sessions setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [sessions setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [bar addSubview:sessions];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:16],
        [title.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [settings.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-16],
        [settings.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [sessions.trailingAnchor constraintEqualToAnchor:settings.leadingAnchor constant:-16],
        [sessions.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [_tempoLabel.trailingAnchor constraintEqualToAnchor:sessions.leadingAnchor constant:-16],
        [_tempoLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:_tempoLabel.leadingAnchor constant:-8],
    ]];

    [self updateTempoLabel];
    return bar;
}

// presents the session document commands as an action sheet from the top-bar
// "Sessions" button (on Mac these live in the File menu instead).
- (void)showSessionsMenu:(UIButton*)sender {
    UIAlertController* sheet =
        [UIAlertController alertControllerWithTitle:@"Session"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    __weak HostViewController* weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"New Session"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* a) { [weakSelf newSession:nil]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Open Session…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* a) { [weakSelf openSession:nil]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Save Session"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* a) { [weakSelf saveSession:nil]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Save Session As…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* a) { [weakSelf saveSessionAs:nil]; }]];
    UIAlertAction* rename = [UIAlertAction actionWithTitle:@"Rename Session…"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* a) { [weakSelf renameSession:nil]; }];
    // rename only applies once the session has been saved to a file.
    rename.enabled = (_currentSessionURL != nil);
    [sheet addAction:rename];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // on iPad an action sheet must be a popover anchored to its button.
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

// reflects the current tempo, highlighted when driven by incoming MIDI clock.
- (void)updateTempoLabel {
    if (_tempoLabel == nil) {
        return;
    }
    _tempoLabel.text = [NSString stringWithFormat:@"%d BPM", (int)lround(_host.tempo)];
    BOOL synced = _portManager.followClock && _portManager.clockActive;
    _tempoLabel.textColor = synced ? [UIColor systemGreenColor] : [UIColor colorWithWhite:1.0 alpha:0.6];
}

// while clock is driving the tempo, manual edits would just be overridden, so
// the widget is inert in that state (matching the disabled slider in settings).
- (BOOL)tempoIsClockDriven {
    return _portManager.followClock && _portManager.clockActive;
}

- (void)tempoPanned:(UIPanGestureRecognizer*)pan {
    if ([self tempoIsClockDriven]) {
        return;
    }
    UIView* reference = pan.view.superview;
    CGPoint location = [pan locationInView:reference];

    if (pan.state == UIGestureRecognizerStateBegan) {
        _tempoAccumulator = _host.tempo;
        _tempoLastX = location.x;
        return;
    }
    if (pan.state != UIGestureRecognizerStateChanged) {
        return;
    }

    CGFloat dx = location.x - _tempoLastX;
    _tempoLastX = location.x;

    // the farther the touch is (vertically) from the widget, the coarser the
    // change; right next to it the control is fine.
    CGFloat verticalDistance = fabs(location.y - CGRectGetMidY(pan.view.frame));
    double sensitivity = MIN(3.0, 0.1 + verticalDistance * 0.005);   // BPM per point

    _tempoAccumulator = MAX(20.0, MIN(300.0, _tempoAccumulator + dx * sensitivity));
    [self applyTempo:round(_tempoAccumulator)];
}

- (void)tempoTapped:(UITapGestureRecognizer*)tap {
    if ([self tempoIsClockDriven]) {
        return;
    }
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Tempo"
                                                                  message:@"Enter tempo in BPM (20–300)"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    double current = _host.tempo;
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = [NSString stringWithFormat:@"%d", (int)lround(current)];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak HostViewController* weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        NSString* text = alert.textFields.firstObject.text;
        double bpm = text.doubleValue;
        if (bpm > 0) {
            [weakSelf applyTempo:round(bpm)];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyTempo:(double)bpm {
    bpm = MAX(20.0, MIN(300.0, bpm));
    _host.tempo = bpm;
    [[NSUserDefaults standardUserDefaults] setDouble:bpm forKey:kHostTempoKey];
    // updates the bar (via the observer) and the settings slider if it is open.
    [[NSNotificationCenter defaultCenter] postNotificationName:MidiPortManagerDidUpdateTempoNotification object:nil];
}
#endif

// action reachable from the Mac menu bar / Cmd+, via the responder chain.
- (void)showSettingsCommand:(id)sender {
    [self showSettings];
}

- (void)showSettings {
    if (self.presentedViewController != nil || _portManager == nil || _host == nil) {
        return;
    }
    MidiSettingsViewController* settings = [[MidiSettingsViewController alloc] initWithPortManager:_portManager host:_host];
    __weak HostViewController* weakSelf = self;
    settings.onShowWelcome = ^{
        [weakSelf showWelcome:nil];
    };
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)presentInstantiationError:(NSError*)error {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Unable to Start"
                                                                  message:[NSString stringWithFormat:@"The MIDI Tape Recorder audio unit could not be loaded.\n\n%@", error.localizedDescription]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
