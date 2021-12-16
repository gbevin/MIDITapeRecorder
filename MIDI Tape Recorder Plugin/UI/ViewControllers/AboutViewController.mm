//
//  AboutViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "AboutViewController.h"

#import "URLHelper.h"

@interface AboutViewController ()
@property (weak, nonatomic) IBOutlet UILabel* versionLabel;
@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (_versionLabel) {
        NSString* shortVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
        NSString* buildNumber = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
        _versionLabel.text = [NSString stringWithFormat:@"v%@ build %@", shortVersion, buildNumber];
    }
}

#pragma mark IBActions

- (IBAction)openWebSite:(id)sender {
    [self closeAboutView:nil];
    openURL([NSURL URLWithString:@"https://github.com/gbevin/MIDITapeRecorder"]);
}

- (IBAction)leaveRating:(id)sender {
    [self closeAboutView:nil];
    openURL([NSURL URLWithString:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=1598618004&pageNumber=0&sortOrdering=3&mt=8"]);
}

- (IBAction)donate:(id)sender {
    [self closeAboutView:nil];
    openDonateURL();
}

- (IBAction)closeAboutView:(id)sender {
    [_mainViewController closeAboutView];
}

@end
