//
//  AboutViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "AboutViewController.h"

@interface AboutViewController ()
@property (weak, nonatomic) IBOutlet UILabel* versionLabel;
@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* shortVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    NSString* buildNumber = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    _versionLabel.text = [NSString stringWithFormat:@"v%@ build %@", shortVersion, buildNumber];
}

#pragma mark IBActions

- (void)openURL:(NSURL*)url {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        UIApplication* application = [UIApplication performSelector:@selector(sharedApplication)];
        if (application && [application respondsToSelector:@selector(openURL:)]) {
            [application performSelector:@selector(openURL:) withObject:url];
        }
    }
}

- (IBAction)openWebSite:(id)sender {
    [self openURL:[NSURL URLWithString:@"https://github.com/gbevin/MIDITapeRecorder"]];
}

- (IBAction)leaveRating:(id)sender {
    NSURL* url = [NSURL URLWithString:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=1598618004&pageNumber=0&sortOrdering=3&mt=8"];
    [self openURL:url];
}

- (IBAction)donate:(id)sender {
    NSURL* url = [NSURL URLWithString:@"http://paypal.me/geertbevin"];
    [self openURL:url];
}

- (IBAction)closeAboutView:(id)sender {
    [_mainViewController closeAboutView];
}

@end
