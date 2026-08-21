//
//  URLHelper.mm
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "URLHelper.h"

#import <UIKit/UIKit.h>

void openURL(NSURL* url) {
    if (url == nil) {
        return;
    }

    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (UIApplicationClass == nil || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication* application = [UIApplicationClass performSelector:@selector(sharedApplication)];
    if (application == nil) {
        return;
    }

    // The single-argument -openURL: was deprecated in iOS 10 and iOS 26 makes it a
    // no-op (it force-returns NO), so route through the modern
    // -openURL:options:completionHandler:. That API isn't part of the
    // application-extension API this target is compiled against, so reach it via
    // NSInvocation, which the runtime allows (the extension has a live
    // UIApplication that forwards the open request to the host).
    SEL openSel = @selector(openURL:options:completionHandler:);
    if ([application respondsToSelector:openSel]) {
        NSDictionary* options = @{};
        id completion = nil;
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:[application methodSignatureForSelector:openSel]];
        invocation.target = application;
        invocation.selector = openSel;
        [invocation setArgument:&url atIndex:2];
        [invocation setArgument:&options atIndex:3];
        [invocation setArgument:&completion atIndex:4];
        [invocation invoke];
    }
    else if ([application respondsToSelector:@selector(openURL:)]) {
        [application performSelector:@selector(openURL:) withObject:url];
    }
}

void openDonateURL() {
    openURL([NSURL URLWithString:@"http://uwyn.com/donate"]);
}
