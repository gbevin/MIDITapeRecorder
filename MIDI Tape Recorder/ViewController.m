//
//  ViewController.m
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel* versionLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* shortVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    NSString* buildNumber = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    _versionLabel.text = [NSString stringWithFormat:@"v%@ build %@", shortVersion, buildNumber];
}

@end
