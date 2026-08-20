//
//  TransportCommands.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "TransportCommands.h"

#include "MidiRecorderParamIds.h"

// per-command override keys, written by a future shortcut editor. absent for now,
// so the built-in defaults apply.
static NSString* InputDefaultsKey(NSString* identifier) {
    return [NSString stringWithFormat:@"shortcut.%@.input", identifier];
}
static NSString* ModifiersDefaultsKey(NSString* identifier) {
    return [NSString stringWithFormat:@"shortcut.%@.modifiers", identifier];
}

@implementation MTRTransportCommand {
    NSString* _defaultInput;
    UIKeyModifierFlags _defaultModifiers;
}

- (instancetype)initWithIdentifier:(NSString*)identifier
                             title:(NSString*)title
                         parameter:(NSString*)parameterIdentifier
                              kind:(MTRCommandKind)kind
                             input:(NSString*)input
                         modifiers:(UIKeyModifierFlags)modifiers {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _title = [title copy];
        _parameterIdentifier = [parameterIdentifier copy];
        _kind = kind;
        _defaultInput = [input copy];
        _defaultModifiers = modifiers;
    }
    return self;
}

- (NSString*)shortcutInput {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:InputDefaultsKey(_identifier)];
    return [stored isKindOfClass:[NSString class]] ? stored : _defaultInput;
}

- (UIKeyModifierFlags)shortcutModifiers {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:ModifiersDefaultsKey(_identifier)];
    return stored != nil ? (UIKeyModifierFlags)[stored integerValue] : _defaultModifiers;
}

@end

@implementation MTRTransportCommands

static MTRTransportCommand* MakeCommand(NSString* identifier, NSString* title, NSString* parameter,
                                        MTRCommandKind kind, NSString* input, UIKeyModifierFlags modifiers) {
    return [[MTRTransportCommand alloc] initWithIdentifier:identifier
                                                     title:title
                                                 parameter:parameter
                                                      kind:kind
                                                     input:input
                                                 modifiers:modifiers];
}

+ (NSArray<MTRTransportCommand*>*)globalCommands {
    static NSArray* commands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // the first argument is the command's own identifier (it keys the stored
        // shortcut preferences, so it stays stable); the third is the AU
        // parameter the command drives
        commands = @[
            MakeCommand(@"play", @"Play / Stop", MTRParamIdPlay, MTRCommandKindToggle, @" ", 0),
            MakeCommand(@"record", @"Record", MTRParamIdRecord, MTRCommandKindToggle, @"r", 0),
            MakeCommand(@"rewind", @"Rewind to Start", MTRParamIdRewind, MTRCommandKindTrigger, @"\r", 0),
            MakeCommand(@"repeat", @"Repeat (Loop)", MTRParamIdRepeat, MTRCommandKindToggle, @"l", 0),
            MakeCommand(@"grid", @"Snap to Grid", MTRParamIdGrid, MTRCommandKindToggle, @"g", 0),
            MakeCommand(@"chase", @"Chase", MTRParamIdChase, MTRCommandKindToggle, @"c", 0),
            MakeCommand(@"punchInOut", @"Punch In / Out", MTRParamIdPunchInOut, MTRCommandKindToggle, @"p", 0),
        ];
    });
    return commands;
}

+ (NSArray<MTRTransportCommand*>*)editCommands {
    static NSArray* commands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        commands = @[
            MakeCommand(@"undo", @"Undo", MTRParamIdUndo, MTRCommandKindTrigger, @"z", UIKeyModifierCommand),
            MakeCommand(@"redo", @"Redo", MTRParamIdRedo, MTRCommandKindTrigger, @"z",
                        UIKeyModifierCommand | UIKeyModifierShift),
        ];
    });
    return commands;
}

+ (NSArray<MTRTransportCommand*>*)commandsForTrack:(int)track {
    int n = track + 1;
    NSString* num = @(n).stringValue;
    return @[
        MakeCommand([NSString stringWithFormat:@"record%d", n],
                    [NSString stringWithFormat:@"Record Enable Track %d", n],
                    MTRParamIdRecordTrack(n), MTRCommandKindToggle, num, 0),
        MakeCommand([NSString stringWithFormat:@"monitor%d", n],
                    [NSString stringWithFormat:@"Monitor Track %d", n],
                    MTRParamIdMonitorTrack(n), MTRCommandKindToggle, num, UIKeyModifierAlternate),
        MakeCommand([NSString stringWithFormat:@"mute%d", n],
                    [NSString stringWithFormat:@"Mute Track %d", n],
                    MTRParamIdMuteTrack(n), MTRCommandKindToggle, num, UIKeyModifierShift),
        // clearing a track is destructive, so it ships without a default shortcut.
        MakeCommand([NSString stringWithFormat:@"clear%d", n],
                    [NSString stringWithFormat:@"Clear Track %d", n],
                    MTRParamIdClearTrack(n), MTRCommandKindTrigger, @"", 0),
    ];
}

+ (NSArray<MTRTransportCommand*>*)allCommands {
    static NSArray* commands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray* all = [NSMutableArray arrayWithArray:[self globalCommands]];
        [all addObjectsFromArray:[self editCommands]];
        for (int t = 0; t < 4; ++t) {
            [all addObjectsFromArray:[self commandsForTrack:t]];
        }
        commands = [all copy];
    });
    return commands;
}

+ (MTRTransportCommand*)commandForIdentifier:(NSString*)identifier {
    for (MTRTransportCommand* command in [self allCommands]) {
        if ([command.identifier isEqualToString:identifier]) {
            return command;
        }
    }
    return nil;
}

@end
