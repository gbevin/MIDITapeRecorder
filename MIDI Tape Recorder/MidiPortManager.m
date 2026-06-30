//
//  MidiPortManager.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiPortManager.h"
#import "MidiClockTempoTracker.h"

#import <mach/mach_time.h>

// MIDI_TRACKS in the plugin
static const int kTrackCount = 4;
static const int kCableCount = 4;

NSString* const MidiPortManagerDidChangeEndpointsNotification = @"MidiPortManagerDidChangeEndpointsNotification";
NSString* const MidiPortManagerDidUpdateTempoNotification = @"MidiPortManagerDidUpdateTempoNotification";

static NSString* const kVirtualSourceUIDKey = @"midi.virtual.source.uid";
static NSString* const kVirtualDestUIDKey = @"midi.virtual.dest.uid";
static NSString* const kFollowClockKey = @"midi.followClock";
// set once, the first time routing is established, so the default assignment is
// applied only on a fresh install and never overrides later user choices.
static NSString* const kDefaultRoutingAppliedKey = @"midi.defaultRoutingApplied";

// converts a CoreMIDI host timestamp (mach absolute time units, 0 = now) to
// seconds.
static double HostTimeToSeconds(MIDITimeStamp timeStamp) {
    static mach_timebase_info_data_t info;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mach_timebase_info(&info);
    });
    if (timeStamp == 0) {
        timeStamp = mach_absolute_time();
    }
    return (double)timeStamp * (double)info.numer / (double)info.denom * 1.0e-9;
}

static NSString* InputKey(int track) {
    return [NSString stringWithFormat:@"midi.input.track.%d", track];
}

static NSString* OutputKey(int cable) {
    return [NSString stringWithFormat:@"midi.output.cable.%d", cable];
}

#pragma mark - MidiEndpointInfo

@implementation MidiEndpointInfo
- (instancetype)initWithName:(NSString*)name uniqueID:(MIDIUniqueID)uniqueID {
    self = [super init];
    if (self) {
        _name = [name copy];
        _uniqueID = uniqueID;
    }
    return self;
}
@end

#pragma mark - Helpers

// determines the number of data bytes following a MIDI status byte.
static NSInteger MidiMessageDataLength(uint8_t status) {
    // note off/on, poly AT, CC
    if (status >= 0x80 && status <= 0xBF) return 2;
    // program change, channel AT
    if (status >= 0xC0 && status <= 0xDF) return 1;
    // pitch bend
    if (status >= 0xE0 && status <= 0xEF) return 2;
    switch (status) {
        // MTC quarter frame
        case 0xF1: return 1;
        // song position
        case 0xF2: return 2;
        // song select
        case 0xF3: return 1;
        // f6 tune request, realtime, etc.
        default:   return 0;
    }
}

static MIDIUniqueID UniqueIDForEndpoint(MIDIEndpointRef endpoint) {
    MIDIUniqueID uid = 0;
    MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uid);
    return uid;
}

static NSString* NameForEndpoint(MIDIEndpointRef endpoint) {
    CFStringRef name = NULL;
    if (MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) != noErr || name == NULL) {
        if (MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name) != noErr) {
            return @"Unknown";
        }
    }
    NSString* result = (__bridge_transfer NSString*)name;
    return result ?: @"Unknown";
}

#pragma mark - MidiPortManager

@implementation MidiPortManager {
    MIDIClientRef _client;
    MIDIPortRef _inputPort;
    MIDIPortRef _outputPort;
    // our output other apps can read
    MIDIEndpointRef _virtualSource;
    // our input other apps can write to
    MIDIEndpointRef _virtualDestination;
    MIDIUniqueID _virtualSourceUID;
    MIDIUniqueID _virtualDestinationUID;

    MIDIUniqueID _inputUID[4];
    MIDIUniqueID _outputUID[4];

    NSMutableArray<NSNumber*>* _connectedSources;

    // MIDI clock tempo tracking.
    BOOL _followClock;
    MidiClockTempoTracker* _clockTracker;
    CFTimeInterval _lastTempoPost;
    dispatch_source_t _clockTimer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectedSources = [NSMutableArray array];
        _clockTracker = [[MidiClockTempoTracker alloc] init];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        for (int t = 0; t < kTrackCount; ++t) {
            _inputUID[t] = (MIDIUniqueID)[defaults integerForKey:InputKey(t)];
        }
        for (int c = 0; c < kCableCount; ++c) {
            _outputUID[c] = (MIDIUniqueID)[defaults integerForKey:OutputKey(c)];
        }
        // default to following MIDI clock when the preference is unset.
        id followClock = [defaults objectForKey:kFollowClockKey];
        _followClock = (followClock == nil) ? YES : [followClock boolValue];
    }
    return self;
}

- (void)dealloc {
    if (_clockTimer) {
        dispatch_source_cancel(_clockTimer);
    }
}

- (void)start {
    __weak MidiPortManager* weakSelf = self;

    MIDIClientCreateWithBlock(CFSTR("MIDI Tape Recorder"), &_client, ^(const MIDINotification* message) {
        if (message->messageID == kMIDIMsgSetupChanged) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf handleSetupChanged];
            });
        }
    });

    MIDIOutputPortCreate(_client, CFSTR("Output"), &_outputPort);

    MIDIInputPortCreateWithBlock(_client, CFSTR("Input"), &_inputPort, ^(const MIDIPacketList* pktlist, void* srcConnRefCon) {
        MIDIEndpointRef source = (MIDIEndpointRef)(uintptr_t)srcConnRefCon;
        [weakSelf dispatchPacketList:pktlist fromUniqueID:UniqueIDForEndpoint(source)];
    });

    [self setupVirtualEndpoints];
    [self applyDefaultRoutingIfNeeded];

    [self rebindInputs];
    [self startClockTimer];
    [self postEndpointsChanged];
}

// on a fresh install, route the first track in and out through the app's own
// virtual endpoints so it records and plays out of the box. runs only once; the
// remaining tracks stay unassigned and any later user choices are preserved.
- (void)applyDefaultRoutingIfNeeded {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDefaultRoutingAppliedKey]) {
        return;
    }
    [defaults setBool:YES forKey:kDefaultRoutingAppliedKey];

    // track 1 records from "MIDI Tape Recorder Input" (our virtual destination)...
    _inputUID[0] = _virtualDestinationUID;
    [defaults setInteger:_virtualDestinationUID forKey:InputKey(0)];

    // ...and plays out to "MIDI Tape Recorder Output" (our virtual source).
    _outputUID[0] = _virtualSourceUID;
    [defaults setInteger:_virtualSourceUID forKey:OutputKey(0)];
}

// periodically detects when the incoming MIDI clock has stopped, since no
// callback fires once pulses cease.
- (void)startClockTimer {
    _clockTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_clockTimer, dispatch_time(DISPATCH_TIME_NOW, 0),
                              (uint64_t)(0.25 * NSEC_PER_SEC), (uint64_t)(0.05 * NSEC_PER_SEC));
    __weak MidiPortManager* weakSelf = self;
    dispatch_source_set_event_handler(_clockTimer, ^{
        MidiPortManager* strongSelf = weakSelf;
        if (strongSelf && [strongSelf->_clockTracker expireIfStaleAtSeconds:HostTimeToSeconds(0)]) {
            [strongSelf postTempoUpdate];
        }
    });
    dispatch_resume(_clockTimer);
}

- (void)setupVirtualEndpoints {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    MIDISourceCreate(_client, CFSTR("MIDI Tape Recorder Output"), &_virtualSource);
    _virtualSourceUID = [self persistentUniqueIDForKey:kVirtualSourceUIDKey
                                              endpoint:_virtualSource
                                              defaults:defaults];

    __weak MidiPortManager* weakSelf = self;
    MIDIDestinationCreateWithBlock(_client, CFSTR("MIDI Tape Recorder Input"), &_virtualDestination,
                                   ^(const MIDIPacketList* pktlist, void* srcConnRefCon) {
        MidiPortManager* strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf dispatchPacketList:pktlist fromUniqueID:strongSelf->_virtualDestinationUID];
        }
    });
    _virtualDestinationUID = [self persistentUniqueIDForKey:kVirtualDestUIDKey
                                                   endpoint:_virtualDestination
                                                   defaults:defaults];
}

// assigns a stable unique ID to a virtual endpoint so saved routings survive
// relaunches. reuses a previously stored ID, or adopts the system-assigned one.
- (MIDIUniqueID)persistentUniqueIDForKey:(NSString*)key endpoint:(MIDIEndpointRef)endpoint defaults:(NSUserDefaults*)defaults {
    MIDIUniqueID uid = (MIDIUniqueID)[defaults integerForKey:key];
    if (uid == 0) {
        // generate a stable, non-zero unique ID. a value of 0 would collide with
        // the "None" sentinel used by the routing menus, and the system does not
        // always assign a non-zero ID to virtual endpoints (e.g. the simulator).
        uid = (MIDIUniqueID)(arc4random() & 0x7FFFFFFF);
        if (uid == 0) {
            uid = 1;
        }
        [defaults setInteger:uid forKey:key];
    }
    // assign it to the endpoint so the system reports the same ID we use. if the
    // ID happens to be taken, fall back to whatever the system assigned.
    if (MIDIObjectSetIntegerProperty(endpoint, kMIDIPropertyUniqueID, uid) != noErr) {
        MIDIUniqueID assigned = UniqueIDForEndpoint(endpoint);
        if (assigned != 0) {
            uid = assigned;
            [defaults setInteger:uid forKey:key];
        }
    }
    return uid;
}

#pragma mark - Endpoint enumeration

- (NSArray<MidiEndpointInfo*>*)availableInputs {
    NSMutableArray* result = [NSMutableArray array];
    ItemCount count = MIDIGetNumberOfSources();
    for (ItemCount i = 0; i < count; ++i) {
        MIDIEndpointRef source = MIDIGetSource(i);
        MIDIUniqueID uid = UniqueIDForEndpoint(source);
        // skip our own output endpoint, which is not an input
        if (uid == _virtualSourceUID) {
            continue;
        }
        [result addObject:[[MidiEndpointInfo alloc] initWithName:NameForEndpoint(source) uniqueID:uid]];
    }
    [result addObject:[[MidiEndpointInfo alloc] initWithName:@"MIDI Tape Recorder Input"
                                                    uniqueID:_virtualDestinationUID]];
    return result;
}

- (NSArray<MidiEndpointInfo*>*)availableOutputs {
    NSMutableArray* result = [NSMutableArray array];
    ItemCount count = MIDIGetNumberOfDestinations();
    for (ItemCount i = 0; i < count; ++i) {
        MIDIEndpointRef dest = MIDIGetDestination(i);
        MIDIUniqueID uid = UniqueIDForEndpoint(dest);
        // skip our own input endpoint, which is not an output
        if (uid == _virtualDestinationUID) {
            continue;
        }
        [result addObject:[[MidiEndpointInfo alloc] initWithName:NameForEndpoint(dest) uniqueID:uid]];
    }
    [result addObject:[[MidiEndpointInfo alloc] initWithName:@"MIDI Tape Recorder Output"
                                                    uniqueID:_virtualSourceUID]];
    return result;
}

- (MIDIEndpointRef)sourceEndpointForUniqueID:(MIDIUniqueID)uid {
    if (uid == 0) {
        return 0;
    }
    ItemCount count = MIDIGetNumberOfSources();
    for (ItemCount i = 0; i < count; ++i) {
        MIDIEndpointRef source = MIDIGetSource(i);
        if (UniqueIDForEndpoint(source) == uid) {
            return source;
        }
    }
    return 0;
}

- (MIDIEndpointRef)destinationEndpointForUniqueID:(MIDIUniqueID)uid {
    if (uid == 0) {
        return 0;
    }
    ItemCount count = MIDIGetNumberOfDestinations();
    for (ItemCount i = 0; i < count; ++i) {
        MIDIEndpointRef dest = MIDIGetDestination(i);
        if (UniqueIDForEndpoint(dest) == uid) {
            return dest;
        }
    }
    return 0;
}

#pragma mark - Routing configuration

- (MIDIUniqueID)inputUniqueIDForTrack:(int)track {
    if (track < 0 || track >= kTrackCount) {
        return 0;
    }
    return _inputUID[track];
}

- (void)setInputUniqueID:(MIDIUniqueID)uniqueID forTrack:(int)track {
    if (track < 0 || track >= kTrackCount) {
        return;
    }
    _inputUID[track] = uniqueID;
    [[NSUserDefaults standardUserDefaults] setInteger:uniqueID forKey:InputKey(track)];
    [self rebindInputs];
}

- (MIDIUniqueID)outputUniqueIDForCable:(int)cable {
    if (cable < 0 || cable >= kCableCount) {
        return 0;
    }
    return _outputUID[cable];
}

- (void)setOutputUniqueID:(MIDIUniqueID)uniqueID forCable:(int)cable {
    if (cable < 0 || cable >= kCableCount) {
        return;
    }
    _outputUID[cable] = uniqueID;
    [[NSUserDefaults standardUserDefaults] setInteger:uniqueID forKey:OutputKey(cable)];
}

#pragma mark - Input binding

// connects every available external source. note data is still routed to tracks
// only according to the per-track mapping (see dispatchPacketList), but
// connecting them all lets us detect MIDI clock from any input regardless of
// whether it is mapped to a track. our own virtual source is skipped; the
// virtual destination delivers through its own read block.
- (void)rebindInputs {
    for (NSNumber* endpoint in _connectedSources) {
        MIDIPortDisconnectSource(_inputPort, (MIDIEndpointRef)endpoint.unsignedIntValue);
    }
    [_connectedSources removeAllObjects];

    ItemCount count = MIDIGetNumberOfSources();
    for (ItemCount i = 0; i < count; ++i) {
        MIDIEndpointRef source = MIDIGetSource(i);
        // skip our own output endpoint
        if (UniqueIDForEndpoint(source) == _virtualSourceUID) {
            continue;
        }
        NSNumber* key = @((unsigned int)source);
        if ([_connectedSources containsObject:key]) {
            continue;
        }
        if (MIDIPortConnectSource(_inputPort, source, (void*)(uintptr_t)source) == noErr) {
            [_connectedSources addObject:key];
        }
    }
}

- (void)handleSetupChanged {
    [self rebindInputs];
    [self postEndpointsChanged];
}

- (void)postEndpointsChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:MidiPortManagerDidChangeEndpointsNotification
                                                        object:self];
}

#pragma mark - Incoming MIDI

- (void)dispatchPacketList:(const MIDIPacketList*)pktlist fromUniqueID:(MIDIUniqueID)uid {
    // which tracks should receive note data from this source (may be none, in
    // which case we still scan the stream for MIDI clock).
    uint8_t cables[4];
    int cableCount = 0;
    for (int t = 0; t < kTrackCount; ++t) {
        if (uid != 0 && _inputUID[t] == uid) {
            cables[cableCount++] = (uint8_t)t;
        }
    }

    AudioEngineHost* host = self.host;

    const MIDIPacket* packet = &pktlist->packet[0];
    for (UInt32 i = 0; i < pktlist->numPackets; ++i) {
        [self processBytes:packet->data
                    length:packet->length
                 timestamp:HostTimeToSeconds(packet->timeStamp)
                    cables:cables
                     count:cableCount
                      host:host];
        packet = MIDIPacketNext(packet);
    }
}

// splits a raw byte stream into individual MIDI messages (handling running
// status, system realtime interleaving and SysEx). note data is scheduled on
// the mapped cables; MIDI clock pulses drive tempo detection. system realtime
// messages are not recorded onto tracks.
- (void)processBytes:(const uint8_t*)data
              length:(UInt16)length
           timestamp:(double)timestamp
              cables:(const uint8_t*)cables
               count:(int)cableCount
                host:(AudioEngineHost*)host {
    NSInteger i = 0;
    uint8_t runningStatus = 0;
    while (i < length) {
        uint8_t b = data[i];

        // system realtime, single byte
        if (b >= 0xF8) {
            if (b == 0xF8) {
                [self handleClockPulseAtSeconds:timestamp];
            }
            i += 1;
            continue;
        }

        // SysEx
        if (b == 0xF0) {
            NSInteger start = i;
            i += 1;
            while (i < length && data[i] != 0xF7) {
                i += 1;
            }
            // include the terminating 0xF7
            if (i < length) {
                i += 1;
            }
            NSInteger len = i - start;
            if (host != nil) {
                for (int c = 0; c < cableCount; ++c) {
                    [host scheduleMIDIOnCable:cables[c] length:len data:&data[start]];
                }
            }
            runningStatus = 0;
            continue;
        }

        uint8_t status;
        if (b & 0x80) {
            status = b;
            i += 1;
            runningStatus = (b < 0xF0) ? b : 0;
        }
        else {
            // stray data byte
            if (runningStatus == 0) {
                i += 1;
                continue;
            }
            status = runningStatus;
        }

        NSInteger dataBytes = MidiMessageDataLength(status);
        // truncated message
        if (i + dataBytes > length) {
            break;
        }
        uint8_t msg[3];
        msg[0] = status;
        for (NSInteger k = 0; k < dataBytes; ++k) {
            msg[1 + k] = data[i + k];
        }
        if (host != nil) {
            for (int c = 0; c < cableCount; ++c) {
                [host scheduleMIDIOnCable:cables[c] length:(1 + dataBytes) data:msg];
            }
        }
        i += dataBytes;
    }
}

#pragma mark - MIDI clock tempo

- (BOOL)followClock {
    return _followClock;
}

- (void)setFollowClock:(BOOL)followClock {
    _followClock = followClock;
    [[NSUserDefaults standardUserDefaults] setBool:followClock forKey:kFollowClockKey];
    [self postTempoUpdate];
}

- (BOOL)isClockActive {
    return _clockTracker.active;
}

// called from the CoreMIDI thread for each MIDI clock pulse (24 per quarter
// note). derives a smoothed tempo and pushes it to the host while clock is
// being followed.
- (void)handleClockPulseAtSeconds:(double)now {
    BOOL wasActive = _clockTracker.active;
    BOOL tempoUpdated = [_clockTracker pulseAtSeconds:now];

    if (tempoUpdated && _followClock) {
        self.host.tempo = _clockTracker.tempo;
    }

    // notify the UI on activation and at most ~4 times per second thereafter.
    CFTimeInterval wall = HostTimeToSeconds(0);
    if (!wasActive || (wall - _lastTempoPost) > 0.25) {
        _lastTempoPost = wall;
        [self postTempoUpdate];
    }
}

- (void)postTempoUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MidiPortManagerDidUpdateTempoNotification
                                                            object:self];
    });
}

#pragma mark - AudioEngineHostDelegate (outgoing MIDI)

- (void)audioEngineHost:(AudioEngineHost*)host
       outputMIDIOnCable:(uint8_t)cable
                  length:(NSInteger)length
                    data:(const uint8_t*)data {
    if (cable >= kCableCount || length <= 0) {
        return;
    }
    MIDIUniqueID uid = _outputUID[cable];
    if (uid == 0) {
        return;
    }
    [self sendBytes:data length:length toUniqueID:uid];
}

- (void)sendBytes:(const uint8_t*)data length:(NSInteger)length toUniqueID:(MIDIUniqueID)uid {
    NSInteger bufferSize = sizeof(MIDIPacketList) + length + 64;
    Byte stackBuffer[512];
    Byte* buffer = (NSInteger)sizeof(stackBuffer) >= bufferSize ? stackBuffer : (Byte*)malloc(bufferSize);

    MIDIPacketList* pktList = (MIDIPacketList*)buffer;
    MIDIPacket* packet = MIDIPacketListInit(pktList);
    packet = MIDIPacketListAdd(pktList, bufferSize, packet, 0, length, data);

    if (packet != NULL) {
        if (uid == _virtualSourceUID) {
            MIDIReceived(_virtualSource, pktList);
        }
        else {
            MIDIEndpointRef dest = [self destinationEndpointForUniqueID:uid];
            if (dest != 0) {
                MIDISend(_outputPort, dest, pktList);
            }
        }
    }

    if (buffer != stackBuffer) {
        free(buffer);
    }
}

@end
