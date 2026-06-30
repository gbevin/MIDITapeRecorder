//
//  WelcomeViewController.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "WelcomeViewController.h"

@implementation WelcomeViewController {
    UIStackView* _contentStack;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIImageView* icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.heightAnchor constraintEqualToConstant:76].active = YES;

    UILabel* title = [[UILabel alloc] init];
    title.text = @"Welcome to MIDI Tape Recorder";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 0;
    title.textAlignment = NSTextAlignmentCenter;

    UILabel* tagline = [[UILabel alloc] init];
    tagline.text = @"Perfectly and effortlessly record and play MIDI.";
    tagline.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    tagline.adjustsFontForContentSizeCategory = YES;
    tagline.numberOfLines = 0;
    tagline.textAlignment = NSTextAlignmentCenter;

    UILabel* intro = [[UILabel alloc] init];
    intro.text = @"Capture your performance with sample-accurate precision, just like an audio tape recorder — every nuance reproduced exactly as you played it, with no quantization or editing. It excels at expressive MPE performances. Two quick steps to get going:";
    intro.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    intro.textColor = [UIColor secondaryLabelColor];
    intro.numberOfLines = 0;
    intro.textAlignment = NSTextAlignmentCenter;

    UIView* step1 = [self stepWithNumber:@"1"
                                    text:@"Open MIDI Settings and pick a MIDI input for each track you want to record, plus an output to play it back to."];
    UIView* step2 = [self stepWithNumber:@"2"
                                    text:@"Record-arm a track with its “R” button, then press Record and Play to start capturing."];

    UILabel* pluginNote = [[UILabel alloc] init];
    pluginNote.text = @"MIDI Tape Recorder is also an open-source AUv3 plug-in — load it inside DAWs and hosts like AUM, Cubasis, or Logic to record expressive MIDI and MPE performances alongside your other tracks.";
    pluginNote.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    pluginNote.textColor = [UIColor secondaryLabelColor];
    pluginNote.numberOfLines = 0;
    pluginNote.textAlignment = NSTextAlignmentCenter;

    UIButton* openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [openButton setTitle:@"Open MIDI Settings" forState:UIControlStateNormal];
    [openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    openButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    openButton.backgroundColor = [UIColor systemBlueColor];
    openButton.layer.cornerRadius = 12;
    [openButton.heightAnchor constraintEqualToConstant:50].active = YES;
    [openButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];

    UIButton* gotItButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [gotItButton setTitle:@"Got It" forState:UIControlStateNormal];
    gotItButton.titleLabel.font = [UIFont systemFontOfSize:17];
    [gotItButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [gotItButton addTarget:self action:@selector(dismissWelcome) forControlEvents:UIControlEventTouchUpInside];

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, title, tagline, intro, step1, step2, pluginNote, openButton, gotItButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack = stack;
    [stack setCustomSpacing:16 afterView:icon];
    [stack setCustomSpacing:6 afterView:title];
    [stack setCustomSpacing:18 afterView:intro];
    [stack setCustomSpacing:18 afterView:step2];
    [stack setCustomSpacing:18 afterView:pluginNote];
    [stack setCustomSpacing:8 afterView:openButton];
    // host the content in a scroll view so it stays usable on short screens
    // (e.g. iPhone landscape, where the app itself is used): the content centers
    // when it fits and scrolls vertically when it doesn't.
    UIScrollView* scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    [scroll addSubview:stack];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide* content = scroll.contentLayoutGuide;
    UILayoutGuide* frame = scroll.frameLayoutGuide;

    NSLayoutConstraint* width = [stack.widthAnchor constraintEqualToConstant:420];
    width.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        // the scroll view fills the safe area
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],

        // lock horizontal scrolling to the visible width
        [content.widthAnchor constraintEqualToAnchor:frame.widthAnchor],
        // make the scrollable area at least as tall as the viewport so the
        // content can be centered when it's shorter than the screen
        [content.heightAnchor constraintGreaterThanOrEqualToAnchor:frame.heightAnchor],

        // center the content; the >= top/bottom let it grow and scroll when tall
        [stack.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:content.topAnchor constant:24],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-24],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-24],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:420],
        width,
    ]];

}

// size the form-sheet presentation (iPad) to the laid-out content height plus the
// 24pt top/bottom padding and any safe-area insets, so the bottom button and its
// spacing are never clipped. on screens too short to show it all (e.g. iPhone
// landscape, where form sheets present full-screen), the scroll view takes over.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat contentHeight = _contentStack.frame.size.height;
    if (contentHeight <= 0.0) {
        return;
    }
    UIEdgeInsets insets = self.view.safeAreaInsets;
    // the content is centered, so this 64pt splits into ~32pt top/bottom padding
    // (plus any safe-area insets) — clear breathing room around the bottom button.
    CGSize size = CGSizeMake(420 + 48,
                             ceil(contentHeight) + 64 + insets.top + insets.bottom);
    if (fabs(self.preferredContentSize.height - size.height) > 0.5 ||
        fabs(self.preferredContentSize.width - size.width) > 0.5) {
        self.preferredContentSize = size;
    }
}

// a numbered step: a circular badge followed by the wrapping description.
- (UIView*)stepWithNumber:(NSString*)number text:(NSString*)text {
    UILabel* badge = [[UILabel alloc] init];
    badge.text = number;
    badge.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    badge.textColor = [UIColor whiteColor];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = [UIColor systemBlueColor];
    badge.layer.cornerRadius = 14;
    badge.clipsToBounds = YES;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [badge.widthAnchor constraintEqualToConstant:28],
        [badge.heightAnchor constraintEqualToConstant:28],
    ]];

    UILabel* label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    label.numberOfLines = 0;

    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[badge, label]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 12;
    return row;
}

- (void)openSettings {
    void (^block)(void) = self.onOpenSettings;
    [self dismissViewControllerAnimated:YES completion:^{
        if (block) {
            block();
        }
    }];
}

- (void)dismissWelcome {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
