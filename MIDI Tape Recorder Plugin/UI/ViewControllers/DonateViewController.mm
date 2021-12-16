//
//  DonateViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "DonateViewController.h"

#import "URLHelper.h"

@implementation DonateViewController

#pragma mark IBActions

- (IBAction)donate:(id)sender {
    [self closeDonateView:nil];
    openDonateURL();
}

- (IBAction)closeDonateView:(id)sender {
    [_mainViewController closeDonateView];
}

@end
