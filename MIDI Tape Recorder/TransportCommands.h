//
//  TransportCommands.h
//  MIDI Tape Recorder
//
//  registry of the hosted unit's host-facing trigger/toggle parameters, exposed in
//  the standalone app as keyboard commands. each command resolves its shortcut from
//  user defaults (for future remapping) falling back to a built-in default, so the
//  menu bar and hardware-keyboard handling share one source of truth.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTRCommandKind) {
    MTRCommandKindToggle,    // the parameter value is on/off state; perform flips it
    MTRCommandKindTrigger,   // momentary pulse; perform sets it to 1
};

@interface MTRTransportCommand : NSObject

@property (nonatomic, readonly) NSString* identifier;            // stable key (defaults + UIKeyCommand propertyList)
@property (nonatomic, readonly) NSString* title;
@property (nonatomic, readonly) NSString* parameterIdentifier;  // AU parameter identifier to drive
@property (nonatomic, readonly) MTRCommandKind kind;

// the effective shortcut: a user override if one has been stored, otherwise the
// built-in default. an empty input means the command has no shortcut assigned.
@property (nonatomic, readonly) NSString* shortcutInput;
@property (nonatomic, readonly) UIKeyModifierFlags shortcutModifiers;

@end

@interface MTRTransportCommands : NSObject

// all commands, in display order (global transport first, then per-track).
+ (NSArray<MTRTransportCommand*>*)allCommands;

// the global transport commands (Play, Record, Rewind, Repeat, Grid, Chase, Punch).
+ (NSArray<MTRTransportCommand*>*)globalCommands;

// the edit commands (Undo, Redo).
+ (NSArray<MTRTransportCommand*>*)editCommands;

// the per-track commands for the given track (0-3): record-enable, monitor, mute, clear.
+ (NSArray<MTRTransportCommand*>*)commandsForTrack:(int)track;

+ (nullable MTRTransportCommand*)commandForIdentifier:(NSString*)identifier;

@end

NS_ASSUME_NONNULL_END
