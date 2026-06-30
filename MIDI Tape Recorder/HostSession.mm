//
//  HostSession.mm
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "HostSession.h"

NSString* const HostSessionUTI = @"com.uwyn.MidiTapeRecorder.session";
NSString* const HostSessionFileExtension = @"mtrec";

// document keys.
static NSString* const kVersionKey = @"version";
static NSString* const kTempoKey = @"tempo";
static NSString* const kFullStateKey = @"fullState";
static const int kCurrentVersion = 1;

@implementation HostSession

+ (NSData*)dataWithFullState:(NSDictionary*)fullState tempo:(double)tempo {
    if (![fullState isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary* document = @{
        kVersionKey: @(kCurrentVersion),
        kTempoKey: @(tempo),
        kFullStateKey: fullState,
    };

    // the AU's fullState is required to be a property list, so the whole document
    // serializes cleanly to a binary plist.
    if (![NSPropertyListSerialization propertyList:document
                                 isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        return nil;
    }
    NSError* error = nil;
    return [NSPropertyListSerialization dataWithPropertyList:document
                                                     format:NSPropertyListBinaryFormat_v1_0
                                                    options:0
                                                      error:&error];
}

+ (BOOL)readData:(NSData*)data
       fullState:(NSDictionary* _Nullable * _Nonnull)fullState
           tempo:(double*)tempo {
    if (data.length == 0) {
        return NO;
    }

    id document = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:NULL
                                                             error:NULL];
    if (![document isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    NSDictionary* state = [document objectForKey:kFullStateKey];
    if (![state isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    if (fullState != NULL) {
        *fullState = state;
    }
    if (tempo != NULL) {
        id tempoValue = [document objectForKey:kTempoKey];
        if ([tempoValue isKindOfClass:[NSNumber class]]) {
            *tempo = [tempoValue doubleValue];
        }
    }
    return YES;
}

@end
