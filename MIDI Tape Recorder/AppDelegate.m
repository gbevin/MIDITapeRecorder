//
//  AppDelegate.m
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "AppDelegate.h"

#import "HostViewController.h"
#import "TransportCommands.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[HostViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

// open a .mtrec session handed to us from Finder/Files ("Open in…") or a
// double-click. forwarded to the host controller, which defers until the AU has
// instantiated if we were cold-launched with the file.
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if (![url isFileURL] ||
        [url.pathExtension caseInsensitiveCompare:@"mtrec"] != NSOrderedSame) {
        return NO;
    }
    HostViewController* host = (HostViewController*)self.window.rootViewController;
    if (![host isKindOfClass:[HostViewController class]]) {
        return NO;
    }
    BOOL inPlace = [options[UIApplicationOpenURLOptionsOpenInPlaceKey] boolValue];
    [host openSessionURL:url inPlace:inPlace];
    return YES;
}

#if TARGET_OS_MACCATALYST
// on Mac the settings are reached through the menu bar (Cmd+,) instead of an
// on-screen control, so nothing overlaps the plugin's own toolbar.
- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder {
    [super buildMenuWithBuilder:builder];

    if (builder.system != UIMenuSystem.mainSystem) {
        return;
    }

    // this app has no text editing, so strip menus that don't apply. in the View
    // menu keep only the Full Screen toggle by removing the toolbar and sidebar
    // groups. the File menu is kept and hosts the track import/export commands.
    [builder removeMenuForIdentifier:UIMenuEdit];
    [builder removeMenuForIdentifier:UIMenuFormat];
    [builder removeMenuForIdentifier:UIMenuToolbar];
    [builder removeMenuForIdentifier:UIMenuSidebar];
    // strip the standard document commands (Open Recent; Duplicate / Move / Rename /
    // export As) so they don't clash with our own session commands. (The matching
    // "Open…" item is suppressed by not declaring the app document-based; see Info.plist.)
    [builder removeMenuForIdentifier:UIMenuOpenRecent];
    if (@available(macCatalyst 16.0, *)) {
        [builder removeMenuForIdentifier:UIMenuDocument];
    }

    // app menu: MIDI Settings (Cmd+,)
    UIKeyCommand* settings = [UIKeyCommand commandWithTitle:@"MIDI Settings…"
                                                      image:nil
                                                     action:@selector(showSettingsCommand:)
                                                      input:@","
                                              modifierFlags:UIKeyModifierCommand
                                               propertyList:nil];
    UIMenu* settingsMenu = [UIMenu menuWithTitle:@""
                                           image:nil
                                      identifier:@"com.uwyn.MidiTapeRecorder.settingsMenu"
                                         options:UIMenuOptionsDisplayInline
                                        children:@[settings]];
    [builder insertSiblingMenu:settingsMenu afterMenuForIdentifier:UIMenuAbout];

    // file menu, top to bottom: session document commands, MIDI import/export,
    // then (separated) clear all.
    UIKeyCommand* newSession = [UIKeyCommand commandWithTitle:@"New Session"
                                                       image:nil
                                                      action:@selector(newSession:)
                                                       input:@"n"
                                               modifierFlags:UIKeyModifierCommand
                                                propertyList:nil];
    UIKeyCommand* openSession = [UIKeyCommand commandWithTitle:@"Open Session…"
                                                        image:nil
                                                       action:@selector(openSession:)
                                                        input:@"o"
                                                modifierFlags:UIKeyModifierCommand
                                                 propertyList:nil];
    UIKeyCommand* saveSession = [UIKeyCommand commandWithTitle:@"Save Session"
                                                        image:nil
                                                       action:@selector(saveSession:)
                                                        input:@"s"
                                                modifierFlags:UIKeyModifierCommand
                                                 propertyList:nil];
    UIKeyCommand* saveSessionAs = [UIKeyCommand commandWithTitle:@"Save Session As…"
                                                          image:nil
                                                         action:@selector(saveSessionAs:)
                                                          input:@"s"
                                                  modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                                                   propertyList:nil];
    UICommand* renameSession = [UICommand commandWithTitle:@"Rename Session…"
                                                     image:nil
                                                    action:@selector(renameSession:)
                                              propertyList:nil];
    UIMenu* sessionOps = [UIMenu menuWithTitle:@""
                                         image:nil
                                    identifier:@"com.uwyn.MidiTapeRecorder.sessionMenu"
                                       options:UIMenuOptionsDisplayInline
                                      children:@[newSession, openSession, saveSession, saveSessionAs, renameSession]];

    UIKeyCommand* importAll = [UIKeyCommand commandWithTitle:@"Import All Tracks…"
                                                       image:nil
                                                      action:@selector(importAllTracks:)
                                                       input:@"i"
                                               modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                                                propertyList:nil];
    UIKeyCommand* exportAll = [UIKeyCommand commandWithTitle:@"Export All Tracks…"
                                                       image:nil
                                                      action:@selector(exportAllTracks:)
                                                       input:@"e"
                                               modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                                                propertyList:nil];
    UIMenu* fileOps = [UIMenu menuWithTitle:@""
                                      image:nil
                                 identifier:@"com.uwyn.MidiTapeRecorder.trackFileMenu"
                                    options:UIMenuOptionsDisplayInline
                                   children:@[importAll, exportAll]];

    UIKeyCommand* clearAll = [UIKeyCommand commandWithTitle:@"Clear All Tracks"
                                                      image:nil
                                                     action:@selector(clearAllTracks:)
                                                      input:@"\b"
                                              modifierFlags:UIKeyModifierCommand
                                               propertyList:nil];
    UIMenu* clearOps = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:@"com.uwyn.MidiTapeRecorder.trackClearMenu"
                                     options:UIMenuOptionsDisplayInline
                                    children:@[clearAll]];

    // insert bottom-up so the order ends up: session, MIDI import/export, clear.
    [builder insertChildMenu:clearOps atStartOfMenuForIdentifier:UIMenuFile];
    [builder insertChildMenu:fileOps atStartOfMenuForIdentifier:UIMenuFile];
    [builder insertChildMenu:sessionOps atStartOfMenuForIdentifier:UIMenuFile];

    // transport menu: global commands inline, then a submenu per track.
    NSMutableArray<UIMenuElement*>* globalElements = [NSMutableArray array];
    for (MTRTransportCommand* command in [MTRTransportCommands globalCommands]) {
        [globalElements addObject:[self menuElementForCommand:command]];
    }
    UIMenu* globalGroup = [UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:@"com.uwyn.MidiTapeRecorder.transport.global"
                                        options:UIMenuOptionsDisplayInline
                                       children:globalElements];

    NSMutableArray<UIMenuElement*>* trackMenus = [NSMutableArray array];
    for (int t = 0; t < 4; ++t) {
        NSMutableArray<UIMenuElement*>* trackElements = [NSMutableArray array];
        for (MTRTransportCommand* command in [MTRTransportCommands commandsForTrack:t]) {
            [trackElements addObject:[self menuElementForCommand:command]];
        }
        [trackMenus addObject:[UIMenu menuWithTitle:[NSString stringWithFormat:@"Track %d", t + 1]
                                              image:nil
                                         identifier:[NSString stringWithFormat:@"com.uwyn.MidiTapeRecorder.transport.track%d", t + 1]
                                            options:0
                                           children:trackElements]];
    }
    UIMenu* tracksGroup = [UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:@"com.uwyn.MidiTapeRecorder.transport.tracks"
                                        options:UIMenuOptionsDisplayInline
                                       children:trackMenus];

    UIMenu* transport = [UIMenu menuWithTitle:@"Transport"
                                        image:nil
                                   identifier:@"com.uwyn.MidiTapeRecorder.transportMenu"
                                      options:0
                                     children:@[globalGroup, tracksGroup]];
    [builder insertSiblingMenu:transport afterMenuForIdentifier:UIMenuFile];

    // edit menu: undo / Redo (driven through our parameter bridge, since the
    // plugin's undo manager lives out-of-process). inserted after File, so it
    // lands between File and Transport.
    NSMutableArray<UIMenuElement*>* editElements = [NSMutableArray array];
    for (MTRTransportCommand* command in [MTRTransportCommands editCommands]) {
        [editElements addObject:[self menuElementForCommand:command]];
    }
    UIMenu* editGroup = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:@"com.uwyn.MidiTapeRecorder.edit.actions"
                                      options:UIMenuOptionsDisplayInline
                                     children:editElements];
    UIMenu* editMenu = [UIMenu menuWithTitle:@"Edit"
                                       image:nil
                                  identifier:@"com.uwyn.MidiTapeRecorder.editMenu"
                                     options:0
                                    children:@[editGroup]];
    [builder insertSiblingMenu:editMenu afterMenuForIdentifier:UIMenuFile];

    // help menu: re-show the welcome screen.
    UICommand* welcome = [UICommand commandWithTitle:@"Show Welcome Screen…"
                                               image:nil
                                              action:@selector(showWelcome:)
                                        propertyList:nil];
    UIMenu* welcomeMenu = [UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:@"com.uwyn.MidiTapeRecorder.welcomeMenu"
                                        options:UIMenuOptionsDisplayInline
                                       children:@[welcome]];
    [builder insertChildMenu:welcomeMenu atStartOfMenuForIdentifier:UIMenuHelp];
}

// a menu element for a transport command: a UIKeyCommand when it has a shortcut,
// otherwise a plain UICommand. the command identifier rides in the property list.
- (UIMenuElement*)menuElementForCommand:(MTRTransportCommand*)command {
    if (command.shortcutInput.length > 0) {
        return [UIKeyCommand commandWithTitle:command.title
                                        image:nil
                                       action:@selector(performTransportCommand:)
                                        input:command.shortcutInput
                                modifierFlags:command.shortcutModifiers
                                 propertyList:command.identifier];
    }
    return [UICommand commandWithTitle:command.title
                                 image:nil
                                action:@selector(performTransportCommand:)
                          propertyList:command.identifier];
}
#endif

@end
