//
//  MidiPortManager.h
//  MIDI Tape Recorder
//
//  manages CoreMIDI endpoints for the standalone host: routes external (and
//  virtual) MIDI sources into the hosted recorder per track, and routes the
//  recorder's per-cable output to external (or virtual) destinations.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

#import "AudioEngineHost.h"

NS_ASSUME_NONNULL_BEGIN

// posted whenever the available endpoints change (hotplug) so the settings UI
// can reload.
extern NSString* const MidiPortManagerDidChangeEndpointsNotification;

// posted (throttled) when the MIDI-clock-derived tempo or clock-active state
// changes, so the settings UI can refresh the tempo display.
extern NSString* const MidiPortManagerDidUpdateTempoNotification;

// a selectable MIDI endpoint, presented in the settings UI.
@interface MidiEndpointInfo : NSObject
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) MIDIUniqueID uniqueID;
@end

@interface MidiPortManager : NSObject <AudioEngineHostDelegate>

@property (nonatomic, weak, nullable) AudioEngineHost* host;

// available inputs (external sources + our virtual destination) and outputs
// (external destinations + our virtual source), refreshed on hotplug.
@property (nonatomic, readonly) NSArray<MidiEndpointInfo*>* availableInputs;
@property (nonatomic, readonly) NSArray<MidiEndpointInfo*>* availableOutputs;

// creates the CoreMIDI client, ports and virtual endpoints, and restores the
// saved per-track / per-cable routing.
- (void)start;

// per-track input routing (track 0-3). a uniqueID of 0 means "None".
- (MIDIUniqueID)inputUniqueIDForTrack:(int)track;
- (void)setInputUniqueID:(MIDIUniqueID)uniqueID forTrack:(int)track;

// per-cable output routing (cable 0-3). a uniqueID of 0 means "None".
- (MIDIUniqueID)outputUniqueIDForCable:(int)cable;
- (void)setOutputUniqueID:(MIDIUniqueID)uniqueID forCable:(int)cable;

// when enabled (the default), tempo is derived from MIDI clock (0xF8) received
// on any connected input and pushed to the host. when no clock is arriving the
// manually set tempo applies.
@property (nonatomic) BOOL followClock;

// YES while MIDI clock is actively being received.
@property (nonatomic, readonly, getter=isClockActive) BOOL clockActive;

@end

NS_ASSUME_NONNULL_END
