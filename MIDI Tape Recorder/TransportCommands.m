//
//  TransportCommands.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "TransportCommands.h"

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
        commands = @[
            MakeCommand(@"play", @"Play / Stop", @"play", MTRCommandKindToggle, @" ", 0),
            MakeCommand(@"record", @"Record", @"record", MTRCommandKindToggle, @"r", 0),
            MakeCommand(@"rewind", @"Rewind to Start", @"rewind", MTRCommandKindTrigger, @"\r", 0),
            MakeCommand(@"repeat", @"Repeat (Loop)", @"repeat", MTRCommandKindToggle, @"l", 0),
            MakeCommand(@"grid", @"Snap to Grid", @"grid", MTRCommandKindToggle, @"g", 0),
            MakeCommand(@"chase", @"Chase", @"chase", MTRCommandKindToggle, @"c", 0),
            MakeCommand(@"punchInOut", @"Punch In / Out", @"punchInOut", MTRCommandKindToggle, @"p", 0),
        ];
    });
    return commands;
}

+ (NSArray<MTRTransportCommand*>*)editCommands {
    static NSArray* commands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        commands = @[
            MakeCommand(@"undo", @"Undo", @"undo", MTRCommandKindTrigger, @"z", UIKeyModifierCommand),
            MakeCommand(@"redo", @"Redo", @"redo", MTRCommandKindTrigger, @"z",
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
                    [NSString stringWithFormat:@"record%d", n], MTRCommandKindToggle, num, 0),
        MakeCommand([NSString stringWithFormat:@"monitor%d", n],
                    [NSString stringWithFormat:@"Monitor Track %d", n],
                    [NSString stringWithFormat:@"monitor%d", n], MTRCommandKindToggle, num, UIKeyModifierAlternate),
        MakeCommand([NSString stringWithFormat:@"mute%d", n],
                    [NSString stringWithFormat:@"Mute Track %d", n],
                    [NSString stringWithFormat:@"mute%d", n], MTRCommandKindToggle, num, UIKeyModifierShift),
        // clearing a track is destructive, so it ships without a default shortcut.
        MakeCommand([NSString stringWithFormat:@"clear%d", n],
                    [NSString stringWithFormat:@"Clear Track %d", n],
                    [NSString stringWithFormat:@"clear%d", n], MTRCommandKindTrigger, @"", 0),
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
