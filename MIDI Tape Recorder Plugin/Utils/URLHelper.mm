//
//  URLHelper.mm
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "URLHelper.h"

#import <UIKit/UIKit.h>

void openURL(NSURL* url) {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        UIApplication* application = [UIApplication performSelector:@selector(sharedApplication)];
        if (application && [application respondsToSelector:@selector(openURL:)]) {
            [application performSelector:@selector(openURL:) withObject:url];
        }
    }
}

void openDonateURL() {
    openURL([NSURL URLWithString:@"https://www.paypal.com/donate/?hosted_button_id=GPXMXLYEU6WKS"]);
}
