//
//  HostSession.h
//  MIDI Tape Recorder
//
//  serializes a standalone session — the hosted unit's full state (all recorded
//  tracks + settings) plus the host tempo — to and from a property-list document,
//  used both for autosave/restore and for named .mtrec session files.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// uniform Type Identifier and file extension for session documents (declared in
// the app's Info.plist).
extern NSString* const HostSessionUTI;
extern NSString* const HostSessionFileExtension;

@interface HostSession : NSObject

// serializes a session to a binary property-list. returns nil if `fullState` is
// missing or not a valid property list.
+ (nullable NSData*)dataWithFullState:(NSDictionary*)fullState tempo:(double)tempo;

// parses session data. returns NO (and leaves the out-params untouched) if the
// data isn't a session document this app understands.
+ (BOOL)readData:(NSData*)data
       fullState:(NSDictionary* _Nullable * _Nonnull)fullState
           tempo:(double*)tempo;

@end

NS_ASSUME_NONNULL_END
