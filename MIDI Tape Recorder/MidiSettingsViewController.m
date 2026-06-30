//
//  MidiSettingsViewController.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiSettingsViewController.h"

#import <objc/runtime.h>

NSString* const kHostTempoKey = @"host.tempo";

// Key under which a row label's tap gesture stashes the switch it should toggle.
static const void* const kRowSwitchKey = &kRowSwitchKey;

@implementation MidiSettingsViewController {
    MidiPortManager* _portManager;
    AudioEngineHost* _host;

    // one per track
    NSMutableArray<UIButton*>* _inputButtons;
    // one per cable
    NSMutableArray<UIButton*>* _outputButtons;
    UISwitch* _followClockSwitch;
    UISlider* _tempoSlider;
    UILabel* _tempoValueLabel;
    UISwitch* _backgroundAudioSwitch;
}

- (instancetype)initWithPortManager:(MidiPortManager*)portManager host:(AudioEngineHost*)host {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _portManager = portManager;
        _host = host;
        _inputButtons = [NSMutableArray array];
        _outputButtons = [NSMutableArray array];
        self.title = @"MIDI Settings";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(done)];
    [self buildForm];
    [self refreshRouting];
    [self refreshTempoUI];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshRouting)
                                                 name:MidiPortManagerDidChangeEndpointsNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshTempoUI)
                                                 name:MidiPortManagerDidUpdateTempoNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Form construction

- (void)buildForm {
    UIScrollView* scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];

    UIStackView* form = [[UIStackView alloc] init];
    form.axis = UILayoutConstraintAxisVertical;
    form.spacing = 8;
    form.translatesAutoresizingMaskIntoConstraints = NO;
    form.layoutMarginsRelativeArrangement = YES;
    form.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 20, 24, 20);
    [scroll addSubview:form];

    [NSLayoutConstraint activateConstraints:@[
        [form.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [form.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [form.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [form.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [form.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];

    // inputs.
    NSMutableArray<UIView*>* inputRows = [NSMutableArray array];
    for (int t = 0; t < 4; ++t) {
        UIButton* button = [self makePopUpButton];
        [_inputButtons addObject:button];
        [inputRows addObject:[self rowWithTitle:[NSString stringWithFormat:@"Track %d", t + 1] control:button]];
    }
    [self addSectionToForm:form header:@"Inputs" rows:inputRows
                    footer:@"Choose the MIDI source recorded onto each track."];

    // outputs.
    NSMutableArray<UIView*>* outputRows = [NSMutableArray array];
    for (int t = 0; t < 4; ++t) {
        UIButton* button = [self makePopUpButton];
        [_outputButtons addObject:button];
        [outputRows addObject:[self rowWithTitle:[NSString stringWithFormat:@"Track %d", t + 1] control:button]];
    }
    [self addSectionToForm:form header:@"Outputs" rows:outputRows
                    footer:@"Choose where each track's playback is sent."];

    // transport.
    _followClockSwitch = [[UISwitch alloc] init];
    [_followClockSwitch addTarget:self action:@selector(followClockChanged:) forControlEvents:UIControlEventValueChanged];
    UIView* followRow = [self rowWithTitle:@"Follow MIDI Clock" control:_followClockSwitch];

    _tempoValueLabel = [[UILabel alloc] init];
    _tempoValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    _tempoValueLabel.textColor = [UIColor secondaryLabelColor];
    UIView* tempoRow = [self rowWithTitle:@"Tempo" control:_tempoValueLabel];

    _tempoSlider = [[UISlider alloc] init];
    _tempoSlider.minimumValue = 20;
    _tempoSlider.maximumValue = 300;
    _tempoSlider.continuous = YES;
    [_tempoSlider addTarget:self action:@selector(tempoChanged:) forControlEvents:UIControlEventValueChanged];
    UIView* sliderRow = [self paddedRowWithContent:_tempoSlider];

    [self addSectionToForm:form header:@"Transport" rows:@[followRow, tempoRow, sliderRow]
                    footer:@"When Follow MIDI Clock is on, tempo tracks the MIDI clock received on any input; otherwise the slider sets it."];

    // virtual ports. these endpoints are always published, so they're shown as
    // plain informational text rather than a card of tappable-looking rows.
    UIView* vIn = [self virtualPortRowWithTitle:@"MIDI Tape Recorder Input" subtitle:@"Receives MIDI from other apps"];
    UIView* vOut = [self virtualPortRowWithTitle:@"MIDI Tape Recorder Output" subtitle:@"Sends MIDI to other apps"];
    [self addInfoSectionToForm:form header:@"Virtual Ports"
                         intro:@"MIDI Tape Recorder always publishes these two virtual ports, so other apps on this device can exchange MIDI with it without any hardware or cables."
                          rows:@[vIn, vOut]
                        footer:nil];

#if !TARGET_OS_MACCATALYST
    // background audio. (Mac apps keep running regardless, so this is iOS-only.)
    _backgroundAudioSwitch = [[UISwitch alloc] init];
    _backgroundAudioSwitch.on = _host.backgroundAudioEnabled;
    [_backgroundAudioSwitch addTarget:self action:@selector(backgroundAudioChanged:) forControlEvents:UIControlEventValueChanged];
    UIView* backgroundRow = [self rowWithTitle:@"Run in Background" control:_backgroundAudioSwitch];
    [self addSectionToForm:form header:@"Audio" rows:@[backgroundRow]
                    footer:@"Keep recording and playing while the app is in the background or the screen is locked. Turn off to save power when you only use the recorder in the foreground."];

    // about. (On Mac this lives in the Help menu instead.)
    UIView* welcomeRow = [self buttonRowWithTitle:@"Show Welcome Screen" action:@selector(showWelcomeTapped)];
    [self addSectionToForm:form header:@"About" rows:@[welcomeRow] footer:nil];
#endif
}

#if !TARGET_OS_MACCATALYST
- (void)backgroundAudioChanged:(UISwitch*)sender {
    _host.backgroundAudioEnabled = sender.isOn;
}
#endif

// a full-width tappable row that runs an action (styled like a settings button).
- (UIView*)buttonRowWithTitle:(NSString*)title action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return button;
}

- (void)showWelcomeTapped {
    void (^block)(void) = self.onShowWelcome;
    [self dismissViewControllerAnimated:YES completion:^{
        if (block) {
            block();
        }
    }];
}

// appends a section: an uppercase header label, the grouped card of rows, and a
// footer description, with appropriate spacing between sections.
- (void)addSectionToForm:(UIStackView*)form
                  header:(NSString*)header
                    rows:(NSArray<UIView*>*)rows
                  footer:(NSString*)footer {
    UIView* headerLabel = [self insetLabelWithText:[header uppercaseString]
                                              font:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
                                             color:[UIColor secondaryLabelColor]];
    [form addArrangedSubview:headerLabel];
    [form setCustomSpacing:6 afterView:headerLabel];

    UIView* card = [self cardWithRows:rows];
    [form addArrangedSubview:card];

    if (footer.length > 0) {
        [form setCustomSpacing:6 afterView:card];
        UIView* footerLabel = [self insetLabelWithText:footer
                                                  font:[UIFont systemFontOfSize:13]
                                                 color:[UIColor secondaryLabelColor]];
        [form addArrangedSubview:footerLabel];
        [form setCustomSpacing:22 afterView:footerLabel];
    }
    else {
        [form setCustomSpacing:22 afterView:card];
    }
}

// appends an informational section: a header, an optional explanatory paragraph,
// the rows laid out directly on the grouped background (no rounded card, so they
// don't read as tappable settings), and an optional footer.
- (void)addInfoSectionToForm:(UIStackView*)form
                      header:(NSString*)header
                       intro:(NSString*)intro
                        rows:(NSArray<UIView*>*)rows
                      footer:(NSString*)footer {
    UIView* headerLabel = [self insetLabelWithText:[header uppercaseString]
                                              font:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
                                             color:[UIColor secondaryLabelColor]];
    [form addArrangedSubview:headerLabel];
    [form setCustomSpacing:6 afterView:headerLabel];

    if (intro.length > 0) {
        UIView* introLabel = [self insetLabelWithText:intro
                                                 font:[UIFont systemFontOfSize:13]
                                                color:[UIColor secondaryLabelColor]];
        [form addArrangedSubview:introLabel];
        [form setCustomSpacing:10 afterView:introLabel];
    }

    UIView* lastRow = nil;
    for (UIView* row in rows) {
        [form addArrangedSubview:row];
        lastRow = row;
    }

    if (footer.length > 0 && lastRow != nil) {
        [form setCustomSpacing:6 afterView:lastRow];
        UIView* footerLabel = [self insetLabelWithText:footer
                                                  font:[UIFont systemFontOfSize:13]
                                                 color:[UIColor secondaryLabelColor]];
        [form addArrangedSubview:footerLabel];
        [form setCustomSpacing:22 afterView:footerLabel];
    }
    else if (lastRow != nil) {
        [form setCustomSpacing:22 afterView:lastRow];
    }
}

// a multi-line label inset to align with card content.
- (UIView*)insetLabelWithText:(NSString*)text font:(UIFont*)font color:(UIColor*)color {
    UILabel* label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* wrap = [[UIView alloc] init];
    [wrap addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-16],
        [label.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [label.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
    ]];
    return wrap;
}

// a rounded card grouping rows with hairline separators between them.
- (UIView*)cardWithRows:(NSArray<UIView*>*)rows {
    UIView* card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 10;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView* stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSUInteger i = 0; i < rows.count; ++i) {
        if (i > 0) {
            [stack addArrangedSubview:[self separator]];
        }
        [stack addArrangedSubview:rows[i]];
    }

    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
    ]];
    return card;
}

- (UIView*)separator {
    UIView* line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [line.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES;
    return line;
}

// a row with a leading title label and a trailing control.
- (UIView*)rowWithTitle:(NSString*)title control:(UIView*)control {
    UILabel* label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor labelColor];
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    control.translatesAutoresizingMaskIntoConstraints = NO;
    [control setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[label, control]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;

    // For a switch row, let a tap on the title (which stretches to fill the row up
    // to the switch) toggle it too, so the whole row responds and not just the
    // small switch. The switch keeps handling taps and drags on itself directly.
    if ([control isKindOfClass:[UISwitch class]]) {
        label.userInteractionEnabled = YES;
        UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchLabelTapped:)];
        objc_setAssociatedObject(tap, kRowSwitchKey, control, OBJC_ASSOCIATION_ASSIGN);
        [label addGestureRecognizer:tap];
    }
    return row;
}

- (void)switchLabelTapped:(UITapGestureRecognizer*)recognizer {
    UISwitch* toggle = objc_getAssociatedObject(recognizer, kRowSwitchKey);
    [toggle setOn:!toggle.isOn animated:YES];
    // setOn:animated: doesn't fire the action, so send it ourselves.
    [toggle sendActionsForControlEvents:UIControlEventValueChanged];
}

// a full-width row (e.g. the tempo slider) with vertical padding.
- (UIView*)paddedRowWithContent:(UIView*)content {
    content.translatesAutoresizingMaskIntoConstraints = NO;
    UIView* row = [[UIView alloc] init];
    [row addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
    ]];
    return row;
}

// an informational endpoint entry: a leading connectivity icon with a title and
// one-line description, inset to align with the section header and footer.
- (UIView*)virtualPortRowWithTitle:(NSString*)title subtitle:(NSString*)subtitle {
    UIImageView* icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left.arrow.right"]];
    icon.tintColor = [UIColor secondaryLabelColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [icon.widthAnchor constraintEqualToConstant:22].active = YES;

    UILabel* t = [[UILabel alloc] init];
    t.text = title;
    t.font = [UIFont systemFontOfSize:16];
    t.textColor = [UIColor labelColor];
    t.numberOfLines = 0;

    UILabel* s = [[UILabel alloc] init];
    s.text = subtitle;
    s.font = [UIFont systemFontOfSize:13];
    s.textColor = [UIColor secondaryLabelColor];
    s.numberOfLines = 0;

    UIStackView* text = [[UIStackView alloc] initWithArrangedSubviews:@[t, s]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    UIStackView* rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text]];
    rowStack.axis = UILayoutConstraintAxisHorizontal;
    rowStack.alignment = UIStackViewAlignmentTop;
    rowStack.spacing = 12;
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* wrap = [[UIView alloc] init];
    [wrap addSubview:rowStack];
    [NSLayoutConstraint activateConstraints:@[
        [rowStack.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:16],
        [rowStack.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-16],
        [rowStack.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:6],
        [rowStack.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-6],
    ]];
    return wrap;
}

#pragma mark - Pop-up buttons

- (UIButton*)makePopUpButton {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    if (@available(iOS 14.0, *)) {
        button.showsMenuAsPrimaryAction = YES;
    }
    return button;
}

// rebuilds the title and menu of every routing button from the current state.
- (void)refreshRouting {
    for (int i = 0; i < (int)_inputButtons.count; ++i) {
        [self configureButton:_inputButtons[i] isInput:YES index:i];
    }
    for (int i = 0; i < (int)_outputButtons.count; ++i) {
        [self configureButton:_outputButtons[i] isInput:NO index:i];
    }
}

- (void)configureButton:(UIButton*)button isInput:(BOOL)isInput index:(int)index {
    NSArray<MidiEndpointInfo*>* endpoints = isInput ? _portManager.availableInputs : _portManager.availableOutputs;
    MIDIUniqueID current = isInput ? [_portManager inputUniqueIDForTrack:index]
                                   : [_portManager outputUniqueIDForCable:index];
    [button setTitle:[self nameForUniqueID:current inEndpoints:endpoints] forState:UIControlStateNormal];

    if (@available(iOS 14.0, *)) {
        __weak MidiSettingsViewController* weakSelf = self;
        NSMutableArray<UIMenuElement*>* children = [NSMutableArray array];
        UIAction* none = [UIAction actionWithTitle:@"None" image:nil identifier:nil handler:^(__kindof UIAction* action) {
            [weakSelf applyRoutingUniqueID:0 isInput:isInput index:index];
        }];
        none.state = (current == 0) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [children addObject:none];

        for (MidiEndpointInfo* info in endpoints) {
            MIDIUniqueID uid = info.uniqueID;
            UIAction* action = [UIAction actionWithTitle:info.name image:nil identifier:nil handler:^(__kindof UIAction* a) {
                [weakSelf applyRoutingUniqueID:uid isInput:isInput index:index];
            }];
            // guard against a 0 endpoint id colliding with the "None" sentinel.
            action.state = (current != 0 && uid == current) ? UIMenuElementStateOn : UIMenuElementStateOff;
            [children addObject:action];
        }
        button.menu = [UIMenu menuWithTitle:@"" children:children];
    }
}

- (void)applyRoutingUniqueID:(MIDIUniqueID)uniqueID isInput:(BOOL)isInput index:(int)index {
    if (isInput) {
        [_portManager setInputUniqueID:uniqueID forTrack:index];
    }
    else {
        [_portManager setOutputUniqueID:uniqueID forCable:index];
    }
    [self refreshRouting];
}

- (NSString*)nameForUniqueID:(MIDIUniqueID)uid inEndpoints:(NSArray<MidiEndpointInfo*>*)endpoints {
    if (uid == 0) {
        return @"None";
    }
    for (MidiEndpointInfo* info in endpoints) {
        if (info.uniqueID == uid) {
            return info.name;
        }
    }
    return @"Unavailable";
}

#pragma mark - Transport

- (void)followClockChanged:(UISwitch*)sender {
    _portManager.followClock = sender.isOn;
    [self refreshTempoUI];
}

- (void)tempoChanged:(UISlider*)slider {
    double tempo = lround(slider.value);
    _host.tempo = tempo;
    [[NSUserDefaults standardUserDefaults] setDouble:tempo forKey:kHostTempoKey];
    _tempoValueLabel.text = [NSString stringWithFormat:@"%d BPM", (int)tempo];
    // let observers (e.g. the host's top-bar tempo readout) reflect the change.
    [[NSNotificationCenter defaultCenter] postNotificationName:MidiPortManagerDidUpdateTempoNotification object:nil];
}

- (void)refreshTempoUI {
    BOOL synced = _portManager.followClock && _portManager.clockActive;
    _followClockSwitch.on = _portManager.followClock;
    _tempoSlider.enabled = !synced;
    _tempoSlider.value = (float)_host.tempo;
    _tempoValueLabel.text = synced ? [NSString stringWithFormat:@"%d BPM · MIDI clock", (int)lround(_host.tempo)]
                                   : [NSString stringWithFormat:@"%d BPM", (int)lround(_host.tempo)];
}

@end
