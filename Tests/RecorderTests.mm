//
//  RecorderTests.mm
//  MIDI Tape Recorder
//
//  Logic tests for the MIDI recording and playback engine. They drive the real
//  MidiRecorderKernel + MidiQueueProcessor/MidiTrackRecorder through a simulated
//  render loop, with no audio hardware or host involved.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <XCTest/XCTest.h>
#import <AudioToolbox/AudioToolbox.h>

#include <cmath>
#include <functional>
#include <vector>

#include "MidiRecorderKernel.h"
#import "MidiQueueProcessor.h"
#import "MidiTrackRecorder.h"
#include "Constants.h"
#include "MidiRecordedData.h"
#include "RecordedMidiMessage.h"

#import "MidiClockTempoTracker.h"
#import "HostTrackFile.h"
#import "HostSession.h"

namespace {

#pragma mark - Render configuration

constexpr double   kSampleRate    = 44100.0;
constexpr uint32_t kFrameCount    = 512;

// tempos in beats per minute.
constexpr double kDefaultTempo = 120.0;
constexpr double kFastTempo    = 240.0;
constexpr double kSlowTempo    = 30.0;

// sample offset of an injected event inside its render buffer (mid-buffer).
constexpr int kEventOffset      = 10;
// last representable sample offset inside a render buffer.
constexpr int kLastFrameOffset  = int(kFrameCount) - 1;

#pragma mark - MIDI vocabulary

// channel voice status nibbles (high nibble; low nibble is the channel).
constexpr uint8_t kNoteOff         = 0x80;
constexpr uint8_t kNoteOn          = 0x90;
constexpr uint8_t kPolyKeyPressure = 0xA0;
constexpr uint8_t kControlChange   = 0xB0;
constexpr uint8_t kProgramChange   = 0xC0;
constexpr uint8_t kChannelPressure = 0xD0;
constexpr uint8_t kPitchBend       = 0xE0;

// wire channel is 0-based; the tests use channel 1.
constexpr uint8_t kChannel1 = 0;

// note numbers (middle C == 60).
constexpr uint8_t kNoteC4  = 60;
constexpr uint8_t kNoteCs4 = 61;
constexpr uint8_t kNoteD4  = 62;
constexpr uint8_t kNoteE4  = 64;
constexpr uint8_t kNoteG4  = 67;
constexpr uint8_t kNoteA4  = 69;

// data values.
constexpr uint8_t kVelocityOn           = 100;
constexpr uint8_t kVelocityOff          = 0;
constexpr uint8_t kModWheelCC           = 1;
constexpr uint8_t kModWheelValue        = 64;
constexpr uint8_t kAftertouchValue      = 96;
constexpr uint8_t kProgramNumber        = 5;
constexpr uint8_t kChannelPressureValue = 80;
constexpr uint8_t kPitchBendCenterLSB   = 0x00;
constexpr uint8_t kPitchBendCenterMSB   = 0x40;

// one channel voice MIDI message of 1-3 bytes.
struct MidiMessage {
    uint8_t data[3] = {0, 0, 0};
    int length = 0;

    bool operator==(const MidiMessage& o) const {
        return length == o.length &&
               data[0] == o.data[0] && data[1] == o.data[1] && data[2] == o.data[2];
    }
};

MidiMessage noteOn(uint8_t channel, uint8_t note, uint8_t velocity) {
    return { { uint8_t(kNoteOn | channel), note, velocity }, 3 };
}
MidiMessage noteOff(uint8_t channel, uint8_t note, uint8_t velocity = kVelocityOff) {
    return { { uint8_t(kNoteOff | channel), note, velocity }, 3 };
}
MidiMessage polyKeyPressure(uint8_t channel, uint8_t note, uint8_t pressure) {
    return { { uint8_t(kPolyKeyPressure | channel), note, pressure }, 3 };
}
MidiMessage controlChange(uint8_t channel, uint8_t controller, uint8_t value) {
    return { { uint8_t(kControlChange | channel), controller, value }, 3 };
}
MidiMessage programChange(uint8_t channel, uint8_t program) {
    return { { uint8_t(kProgramChange | channel), program, 0 }, 2 };
}
MidiMessage channelPressure(uint8_t channel, uint8_t pressure) {
    return { { uint8_t(kChannelPressure | channel), pressure, 0 }, 2 };
}
MidiMessage pitchBend(uint8_t channel, uint8_t lsb, uint8_t msb) {
    return { { uint8_t(kPitchBend | channel), lsb, msb }, 3 };
}

bool isNoteOn(const MidiMessage& m)  { return (m.data[0] & 0xf0) == kNoteOn && m.data[2] > 0; }
bool isNoteOff(const MidiMessage& m) {
    uint8_t status = m.data[0] & 0xf0;
    return status == kNoteOff || (status == kNoteOn && m.data[2] == 0);
}

#pragma mark - Harness

// a MIDI event observed on the hosted AU's output, with its scheduled sample time.
struct OutputEvent {
    double sampleTime;
    uint8_t cable;
    MidiMessage message;
};

// drives the real kernel + recorder classes through a hand-stepped render loop.
struct RecorderHarness {
    MidiRecorderKernel kernel;
    MidiQueueProcessor* qp = nil;
    AudioTimeStamp ts;
    int bufferIndex = 0;
    double currentTempo = kDefaultTempo;
    double integratedPlayhead = 0.0;        // independent integration of framesBeats
    std::vector<OutputEvent> output;

    RecorderHarness() {
        memset(&ts, 0, sizeof(ts));
        ts.mFlags = kAudioTimeStampSampleTimeValid;

        kernel._ioState.sampleRate = kSampleRate;
        RecorderHarness* self_ = this;
        kernel._ioState.midiOutputEventBlock =
            ^OSStatus(AUEventSampleTime t, uint8_t cable, NSInteger len, const uint8_t* bytes) {
                OutputEvent e;
                e.sampleTime = (double)t;
                e.cable = cable;
                e.message.length = (int)len;
                for (int i = 0; i < 3; ++i) {
                    e.message.data[i] = (i < len) ? bytes[i] : 0;
                }
                self_->output.push_back(e);
                return noErr;
            };

        qp = [[MidiQueueProcessor alloc] init];
        [qp setState:&kernel._state];
    }

    MidiTrackRecorder* recorder(int track) { return [qp recorder:track]; }

    // absolute sample position of an offset inside the current render buffer.
    double absoluteSample(int sampleOffset) const {
        return double(bufferIndex) * kFrameCount + sampleOffset;
    }

    void setupBuffer(double tempo) {
        currentTempo = tempo;
        double s2b = tempo / 60.0;
        kernel._state.tempo = tempo;
        kernel._state.secondsToBeats = s2b;
        kernel._state.beatsToSeconds = 60.0 / tempo;
        ts.mSampleTime = double(bufferIndex) * kFrameCount;
        kernel._ioState.timestamp = &ts;
        kernel._ioState.frameCount = kFrameCount;
        kernel._ioState.framesBeats = (double(kFrameCount) / kSampleRate) * s2b;
        kernel._ioState.timeSampleSeconds = (ts.mSampleTime - double(kFrameCount)) / kSampleRate;
    }

    // record-enables a track (routing cable == track index) ahead of transport start.
    void arm(int track) {
        kernel._state.track[track].sourceCable = track;
        kernel._state.track[track].recordEnabled.test_and_set();
        [recorder(track) setRecord:YES];
    }

    // starts the transport and begins recording for every armed track.
    void start() {
        setupBuffer(kDefaultTempo);
        kernel._state.playPositionBeats = 0.0;
        kernel._state.processedPlay.clear();
        kernel.handleScheduledTransitions();                // play()
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            kernel._state.processedBeginRecording[t].clear();
        }
        kernel.handleScheduledTransitions();                // begin recording
    }

    void armAndStart(int track) {
        arm(track);
        start();
    }

    // --- Per-buffer primitives -------------------------------------------------

    void beginBuffer(double tempo) {
        setupBuffer(tempo);
        kernel.handleBufferStart();
    }

    // injects one MIDI message into the open buffer at a sample offset; returns the
    // tempo-integrated playhead beat at that offset.
    double inject(int sampleOffset, uint8_t cable, const MidiMessage& msg) {
        double beat = integratedPlayhead + (double(sampleOffset) / kSampleRate) * (currentTempo / 60.0);
        AUMIDIEvent ev;
        memset(&ev, 0, sizeof(ev));
        ev.eventType = AURenderEventMIDI;
        ev.eventSampleTime = (AUEventSampleTime)(ts.mSampleTime + sampleOffset);
        ev.length = msg.length;
        ev.cable = cable;
        ev.data[0] = msg.data[0];
        ev.data[1] = msg.data[1];
        ev.data[2] = msg.data[2];
        kernel.handleMIDIEvent(ev);
        return beat;
    }

    void endBuffer() {
        kernel.processOutput();
        integratedPlayhead += kernel._ioState.framesBeats;
        bufferIndex += 1;
    }

    // runs one empty render buffer (idle / playback).
    void advance(double tempo) {
        beginBuffer(tempo);
        endBuffer();
    }

    // runs one render buffer that injects a single message; returns its beat.
    double record(double tempo, int sampleOffset, uint8_t cable, const MidiMessage& msg) {
        beginBuffer(tempo);
        double beat = inject(sampleOffset, cable, msg);
        endBuffer();
        return beat;
    }

    // --- Loop-record primitives ------------------------------------------------

    // one render buffer in render-loop order (buffer start, optional injected
    // message, output), then drains the recorder queue so the recorder processes
    // the buffer's messages immediately -- as it does continuously from the UI
    // render loop in the real app. deliberately does NOT run scheduled transitions,
    // so a caller can inspect a just-captured pass before applyScheduledTransitions
    // blends it.
    void loopBuffer(bool doInject, int sampleOffset, uint8_t cable, const MidiMessage& msg) {
        setupBuffer(kDefaultTempo);
        kernel.handleBufferStart();
        if (doInject) {
            inject(sampleOffset, cable, msg);
        }
        kernel.processOutput();
        integratedPlayhead += kernel._ioState.framesBeats;
        bufferIndex += 1;
        [qp processMidiQueue:&kernel._state.midiBuffer];
    }

    // applies the kernel's scheduled transitions -- in a loop-record scenario this
    // performs any pending overdub blend flagged by a cycle capture.
    void applyScheduledTransitions() {
        kernel.handleScheduledTransitions();
    }

    // --- Finalize / playback ---------------------------------------------------

    std::vector<RecordedMidiMessage> finalizeAndGetRecorded(int track) {
        [qp processMidiQueue:&kernel._state.midiBuffer];
        [recorder(track) setRecord:NO];

        std::vector<RecordedMidiMessage> result;
        auto& pending = kernel._state.track[track].pendingRecordedData;
        if (pending) {
            for (auto& beat : pending->getBeats()) {
                for (auto& m : beat) {
                    result.push_back(m);
                }
            }
        }
        return result;
    }

    // moves a finalized (pending) recording into the active recorded slot, which is
    // what the MIDI-file export reads from.
    void captureRecording(int track) {
        kernel._state.processedEndRecording[track].clear();
        kernel.handleScheduledTransitions();                // endRecording moves pending -> recorded
    }

    // moves the just-recorded data into the active recorded slot and arms playback.
    void prepareForPlayback(int track) {
        captureRecording(track);

        double duration = 0.0;
        if (kernel._state.track[track].recordedData) {
            duration = kernel._state.track[track].recordedData->getDuration();
        }
        kernel._state.startPositionBeats = 0.0;
        // a far stop position keeps playback from auto-ending during the test
        kernel._state.stopPositionBeats = duration + 100.0;
        kernel._state.playPositionBeats = 0.0;

        kernel._state.processedPlay.clear();
        kernel.handleScheduledTransitions();
        output.clear();
        bufferIndex = 0;
        integratedPlayhead = 0.0;
    }

    std::vector<RecordedMidiMessage> messagesIn(const std::unique_ptr<MidiRecordedData>& data) {
        std::vector<RecordedMidiMessage> result;
        if (data) {
            for (auto& beat : data->getBeats()) {
                for (auto& m : beat) {
                    result.push_back(m);
                }
            }
        }
        return result;
    }

    std::vector<RecordedMidiMessage> recordedMessages(int track) {
        return messagesIn(kernel._state.track[track].recordedData);
    }

    std::vector<RecordedMidiMessage> pendingMessages(int track) {
        return messagesIn(kernel._state.track[track].pendingRecordedData);
    }
};

// the beat offset a single elapsed-time * one-tempo multiply would produce, used to
// show that tempo-integrated recording lands somewhere clearly different.
double singleTempoOffset(double eventSampleTime, double recordStartSeconds, double tempo) {
    double eventTimeSeconds = eventSampleTime / kSampleRate;
    return (eventTimeSeconds - recordStartSeconds) * (tempo / 60.0);
}

std::vector<OutputEvent> outputsOnCable(const std::vector<OutputEvent>& evs, uint8_t cable) {
    std::vector<OutputEvent> out;
    for (auto& e : evs) {
        if (e.cable == cable) out.push_back(e);
    }
    return out;
}

std::vector<OutputEvent> noteOnsOf(const std::vector<OutputEvent>& evs) {
    std::vector<OutputEvent> ons;
    for (auto& e : evs) {
        if (isNoteOn(e.message)) ons.push_back(e);
    }
    return ons;
}

// seconds between MIDI clock pulses (0xF8) for a given tempo, i.e. the inverse of
// the tracker's BPM derivation.
double clockPulseInterval(double bpm) {
    return 60.0 / (bpm * MidiClockPulsesPerQuarter);
}

#pragma mark - Standard MIDI File helpers

// standard MIDI File meta-event markers.
constexpr uint8_t kMetaPrefix     = 0xff;
constexpr uint8_t kMetaSetTempo   = 0x51;
constexpr uint8_t kMetaEndOfTrack = 0x2f;

// microseconds-per-quarter-note encoded by an SMF Set Tempo meta event.
double microsecondsPerBeatFor(double bpm) { return 60000000.0 / bpm; }

// reads big-endian fields directly, independent of host byte order (SMF is always
// big-endian on disk).
uint16_t beU16(NSData* d, NSUInteger off) {
    const uint8_t* b = (const uint8_t*)d.bytes + off;
    return (uint16_t)((b[0] << 8) | b[1]);
}
uint32_t beU32(NSData* d, NSUInteger off) {
    const uint8_t* b = (const uint8_t*)d.bytes + off;
    return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
           ((uint32_t)b[2] << 8)  |  (uint32_t)b[3];
}
bool tag4(NSData* d, NSUInteger off, const char* tag) {
    if (off + 4 > d.length) return false;
    return memcmp((const uint8_t*)d.bytes + off, tag, 4) == 0;
}

// offset of the first occurrence of an "MTrk" chunk, or NSNotFound.
NSUInteger firstTrackChunkOffset(NSData* file) {
    for (NSUInteger i = 0; i + 4 <= file.length; ++i) {
        if (tag4(file, i, "MTrk")) return i;
    }
    return NSNotFound;
}

// only the recordable channel-voice messages (export drops INTERNAL markers).
std::vector<RecordedMidiMessage> channelOnly(const std::vector<RecordedMidiMessage>& msgs) {
    std::vector<RecordedMidiMessage> out;
    for (auto& m : msgs) {
        if (m.type == MIDI_1_0) out.push_back(m);
    }
    return out;
}

bool sameBytes(const RecordedMidiMessage& r, const MidiMessage& m) {
    return r.length == m.length &&
           r.data[0] == m.data[0] && r.data[1] == m.data[1] && r.data[2] == m.data[2];
}

// builds a 14-byte MThd header with the given fields (big-endian), for feeding
// deliberately malformed files to the importer.
NSData* makeFileHeader(uint32_t headerLength, uint16_t format, uint16_t ntrks, uint16_t division) {
    uint8_t bytes[14];
    memcpy(bytes, "MThd", 4);
    bytes[4]  = (headerLength >> 24) & 0xff; bytes[5] = (headerLength >> 16) & 0xff;
    bytes[6]  = (headerLength >> 8) & 0xff;  bytes[7] = headerLength & 0xff;
    bytes[8]  = (format >> 8) & 0xff;        bytes[9] = format & 0xff;
    bytes[10] = (ntrks >> 8) & 0xff;         bytes[11] = ntrks & 0xff;
    bytes[12] = (division >> 8) & 0xff;      bytes[13] = division & 0xff;
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

// --- Host fullState <-> .mid bridge helpers ---

// a RecordedMidiMessage at a beat offset, from a test MidiMessage.
RecordedMidiMessage recordedAt(const MidiMessage& m, double offsetBeats) {
    RecordedMidiMessage r;
    r.offsetBeats = offsetBeats;
    r.length = m.length;
    r.data[0] = m.data[0];
    r.data[1] = m.data[1];
    r.data[2] = m.data[2];
    return r;
}

// a "Recorder<n>" fullState entry: a raw RecordedMidiMessage blob + duration.
NSDictionary* recorderEntry(const std::vector<RecordedMidiMessage>& msgs, double durationBeats) {
    NSData* blob = [NSData dataWithBytes:msgs.data() length:msgs.size() * sizeof(RecordedMidiMessage)];
    return @{ @"Recorded": blob, @"Duration": @(durationBeats) };
}

std::vector<RecordedMidiMessage> messagesFromRecorderEntry(NSDictionary* entry) {
    std::vector<RecordedMidiMessage> out;
    NSData* blob = [entry objectForKey:@"Recorded"];
    if ([blob isKindOfClass:[NSData class]]) {
        const RecordedMidiMessage* p = (const RecordedMidiMessage*)blob.bytes;
        NSUInteger n = blob.length / sizeof(RecordedMidiMessage);
        out.assign(p, p + n);
    }
    return out;
}

// records the given messages on a track (one per buffer, spaced apart), finalizes
// and captures them to the active recorded data, then returns those messages.
std::vector<RecordedMidiMessage> recordAndCapture(RecorderHarness& h, int track,
                                                 const std::vector<MidiMessage>& msgs,
                                                 int spacing = 8) {
    h.armAndStart(track);
    for (size_t k = 0; k < msgs.size(); ++k) {
        h.record(kDefaultTempo, kEventOffset, (uint8_t)track, msgs[k]);
        for (int b = 1; b < spacing; ++b) {
            h.advance(kDefaultTempo);
        }
    }
    h.finalizeAndGetRecorded(track);   // drains the queue into pending
    h.captureRecording(track);          // pending -> recorded (what export reads)
    return h.recordedMessages(track);
}

// loop length (beats) used by the loop-record tests. deliberately not an integer
// number of render buffers, so the loop wraps mid-buffer and each new pass begins a
// fraction of a beat past the loop head -- the case that distinguishes a pass pinned
// to the loop start from one that begins at its first re-recorded event.
constexpr double kLoopLengthBeats = 0.1;

// arms track 0, starts the transport and enables a repeating loop over
// [0, kLoopLengthBeats], with continuous loop record on unless `loopRecord` is NO.
void startLoopRecord(RecorderHarness& h, bool loopRecord = true) {
    h.arm(0);
    h.start();
    h.kernel._state.startPositionBeats = 0.0;
    h.kernel._state.stopPositionBeats = kLoopLengthBeats;
    h.kernel._state.repeatEnabled.test_and_set();
    h.kernel._state.repeatActive.test_and_set();
    if (loopRecord) {
        h.kernel._state.loopRecord.test_and_set();
    }
}

// records one event early in the first loop pass, then advances until the loop wraps
// once, so the kernel has processed the loop end.
void driveToLoopEndWithEvent(RecorderHarness& h) {
    const MidiMessage note = noteOn(kChannel1, kNoteC4, kVelocityOn);
    double prevPlay = h.kernel._state.playPositionBeats;
    int bufferInPass = 0;
    for (int step = 0; step < 200; ++step) {
        h.loopBuffer(bufferInPass == 1, kEventOffset, /*cable*/ 0, note);
        double nowPlay = h.kernel._state.playPositionBeats;
        if (nowPlay < prevPlay) {
            return;
        }
        prevPlay = nowPlay;
        bufferInPass += 1;
    }
}

// the loop-window span (start and duration, in beats) of a captured pass, as seen
// just before its overdub blend.
struct CapturedPass {
    double start;
    double duration;
};

// drives a continuous loop-record take on track 0 until `numCaptures` passes have
// been captured. for each buffer it asks `injectFor(pass, bufferInPass)` for an
// optional message to inject (pass and buffer indices are 1- and 0-based). each
// captured pass's window is appended to `outCaptures` (captured before the blend
// consumes it), then the blend is applied so the pass becomes the base that the next
// pass overdubs. `pass`/`buffer` slots let a test place base material at the loop
// head and overdub material elsewhere, or leave a cycle silent.
void driveLoopRecord(RecorderHarness& h, int numCaptures,
                     const std::function<bool(int pass, int buffer, MidiMessage& out)>& injectFor,
                     std::vector<CapturedPass>& outCaptures) {
    int pass = 1;
    int bufferInPass = 0;
    int captures = 0;
    double prevPlay = h.kernel._state.playPositionBeats;

    for (int step = 0; step < 1000 && captures < numCaptures; ++step) {
        MidiMessage msg;
        bool doInject = injectFor(pass, bufferInPass, msg);

        bool pendingWasEmpty = (h.kernel._state.track[0].pendingRecordedData == nullptr);
        h.loopBuffer(doInject, kEventOffset, /*cable*/ 0, msg);

        // a pass capture shows up as pending data appearing; snapshot its window, then
        // blend it so the next pass overdubs onto it.
        auto& pending = h.kernel._state.track[0].pendingRecordedData;
        if (pendingWasEmpty && pending != nullptr) {
            outCaptures.push_back({ pending->getStart(), pending->getDuration() });
            captures += 1;
            h.applyScheduledTransitions();
        }

        // the playhead decreasing means the loop wrapped, i.e. a new pass began.
        double nowPlay = h.kernel._state.playPositionBeats;
        if (nowPlay < prevPlay) {
            pass += 1;
            bufferInPass = 0;
        }
        else {
            bufferInPass += 1;
        }
        prevPlay = nowPlay;
    }
}

}  // namespace

@interface RecorderTests : XCTestCase
@end

@implementation RecorderTests

#pragma mark - Recording position

// a note recorded partway into a constant-tempo take lands at the integrated
// playhead position.
- (void)testConstantTempoRecordsAtPlayhead {
    RecorderHarness h;
    h.armAndStart(0);

    const int totalBuffers = 100;
    double expected = 0.0;
    for (int b = 0; b < totalBuffers; ++b) {
        if (b == totalBuffers - 1) {
            expected = h.record(kDefaultTempo, kEventOffset, kChannel1,
                                noteOn(kChannel1, kNoteC4, kVelocityOn));
        }
        else {
            h.advance(kDefaultTempo);
        }
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), 1u, @"exactly one note is recorded");
    XCTAssertEqualWithAccuracy(recorded[0].offsetBeats, expected, 0.01,
                               @"recorded beat matches the integrated playhead");
}

// under a tempo change mid-recording, the recorded beat tracks the tempo-integrated
// playhead across both tempos, landing well clear of a single elapsed-time * one-tempo
// estimate.
- (void)testVariableTempoRecordsAtIntegratedPlayhead {
    RecorderHarness h;
    h.armAndStart(0);
    double recordStartSeconds = h.kernel._state.transportStartSampleSeconds.load();

    const int fastBuffers = 100;
    const int slowBuffers = 100;
    const int totalBuffers = fastBuffers + slowBuffers;
    double expectedIntegrated = 0.0;
    double eventSampleTime = 0.0;
    for (int b = 0; b < totalBuffers; ++b) {
        double tempo = (b < fastBuffers) ? kFastTempo : kSlowTempo;
        if (b == totalBuffers - 1) {
            eventSampleTime = h.absoluteSample(kEventOffset);
            expectedIntegrated = h.record(tempo, kEventOffset, kChannel1,
                                          noteOn(kChannel1, kNoteC4, kVelocityOn));
        }
        else {
            h.advance(tempo);
        }
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), 1u);

    double singleTempo = singleTempoOffset(eventSampleTime, recordStartSeconds, kSlowTempo);

    XCTAssertEqualWithAccuracy(recorded[0].offsetBeats, expectedIntegrated, 0.02,
                               @"recorded beat equals the tempo-integrated playhead");
    XCTAssertGreaterThan(expectedIntegrated, singleTempo + 1.0,
                         @"the two-tempo scenario separates the integrated playhead from a single-tempo estimate");
    XCTAssertGreaterThan(recorded[0].offsetBeats, singleTempo + 1.0,
                         @"recorded beat tracks the integrated playhead, well clear of a single-tempo estimate");
}

// several notes recorded in sequence keep increasing offsets with even spacing.
- (void)testMultipleNotesAreMonotonicAndEvenlySpaced {
    RecorderHarness h;
    h.armAndStart(0);

    const int spacing = 43;
    const int noteCount = 3;
    std::vector<double> expected;
    for (int b = 0; b < spacing * noteCount; ++b) {
        if ((b + 1) % spacing == 0) {
            expected.push_back(h.record(kDefaultTempo, kEventOffset, kChannel1,
                                        noteOn(kChannel1, kNoteC4, kVelocityOn)));
        }
        else {
            h.advance(kDefaultTempo);
        }
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), size_t(noteCount));

    for (size_t i = 0; i < recorded.size(); ++i) {
        XCTAssertEqualWithAccuracy(recorded[i].offsetBeats, expected[i], 0.01);
        if (i > 0) {
            XCTAssertGreaterThan(recorded[i].offsetBeats, recorded[i - 1].offsetBeats,
                                 @"offsets are strictly increasing");
        }
    }
    double gap1 = recorded[1].offsetBeats - recorded[0].offsetBeats;
    double gap2 = recorded[2].offsetBeats - recorded[1].offsetBeats;
    XCTAssertEqualWithAccuracy(gap1, gap2, 0.01, @"note spacing is even");
}

#pragma mark - Round-trip playback

// recording then playing back reproduces the notes in order with matching spacing.
- (void)testRoundTripPlaybackPreservesTiming {
    RecorderHarness h;
    h.armAndStart(0);

    const int spacing = 43;
    const uint8_t pitches[] = { kNoteC4, kNoteCs4, kNoteD4 };
    const int noteCount = int(sizeof(pitches) / sizeof(pitches[0]));
    for (int b = 0; b < spacing * noteCount; ++b) {
        int idx = b / spacing;
        if ((b + 1) % spacing == 0) {
            h.record(kDefaultTempo, kEventOffset, kChannel1,
                     noteOn(kChannel1, pitches[idx], kVelocityOn));
        }
        else {
            h.advance(kDefaultTempo);
        }
    }
    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), size_t(noteCount));

    h.prepareForPlayback(0);
    const int playbackBuffers = spacing * (noteCount + 1);
    for (int b = 0; b < playbackBuffers; ++b) {
        h.advance(kDefaultTempo);
    }

    auto noteOns = noteOnsOf(h.output);
    XCTAssertEqual(noteOns.size(), size_t(noteCount), @"all recorded notes play back");

    for (size_t i = 0; i < noteOns.size(); ++i) {
        XCTAssertEqual(noteOns[i].message.data[1], pitches[i], @"pitches play back in order");
        if (i > 0) {
            // notes were recorded `spacing` buffers apart, so playback is too
            double expectedGap = double(spacing) * kFrameCount;
            double gap = noteOns[i].sampleTime - noteOns[i - 1].sampleTime;
            XCTAssertEqualWithAccuracy(gap, expectedGap, 1.0,
                                       @"playback spacing matches the recorded spacing");
        }
    }
}

#pragma mark - Sample-accurate timing

// each note plays back at the exact sample position it was recorded at, regardless
// of where inside a render buffer it fell.
- (void)testPlaybackIsSampleAccurate {
    RecorderHarness h;
    h.armAndStart(0);

    struct Injection { int buffer; int offset; uint8_t pitch; };
    const Injection injections[] = {
        { 17, 0,               kNoteC4 },   // first sample of the buffer
        { 53, kEventOffset,    kNoteE4 },   // mid-buffer
        { 91, kLastFrameOffset, kNoteG4 },  // last sample of the buffer
    };
    const int injectionCount = int(sizeof(injections) / sizeof(injections[0]));

    // expected absolute sample position per pitch
    std::vector<std::pair<uint8_t, double>> expectedSamples;

    int lastBuffer = injections[injectionCount - 1].buffer;
    int ii = 0;
    for (int b = 0; b <= lastBuffer; ++b) {
        if (ii < injectionCount && injections[ii].buffer == b) {
            const Injection& in = injections[ii];
            double sample = h.absoluteSample(in.offset);
            expectedSamples.push_back({ in.pitch, sample });
            h.record(kDefaultTempo, in.offset, kChannel1, noteOn(kChannel1, in.pitch, kVelocityOn));
            ii += 1;
        }
        else {
            h.advance(kDefaultTempo);
        }
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), size_t(injectionCount));

    h.prepareForPlayback(0);
    for (int b = 0; b <= lastBuffer + 1; ++b) {
        h.advance(kDefaultTempo);
    }

    auto noteOns = noteOnsOf(h.output);
    XCTAssertEqual(noteOns.size(), size_t(injectionCount));

    for (auto& expected : expectedSamples) {
        uint8_t pitch = expected.first;
        double expectedSample = expected.second;
        bool found = false;
        for (auto& on : noteOns) {
            if (on.message.data[1] == pitch) {
                found = true;
                XCTAssertEqualWithAccuracy(on.sampleTime, expectedSample, 1.0,
                                           @"note plays back within one sample of its recorded position");
                XCTAssertEqual((long long)llround(on.sampleTime), (long long)llround(expectedSample),
                               @"note plays back at the exact recorded sample");
            }
        }
        XCTAssertTrue(found, @"each recorded pitch plays back");
    }
}

#pragma mark - Message types and ordering

// every channel-voice message type is recorded and replayed verbatim, in order,
// preserving status, data bytes and message length (including 2-byte messages).
- (void)testAllMessageTypesPreservedInOrder {
    RecorderHarness h;
    h.armAndStart(0);

    const std::vector<MidiMessage> expected = {
        noteOn(kChannel1, kNoteC4, kVelocityOn),
        polyKeyPressure(kChannel1, kNoteC4, kAftertouchValue),
        controlChange(kChannel1, kModWheelCC, kModWheelValue),
        programChange(kChannel1, kProgramNumber),
        channelPressure(kChannel1, kChannelPressureValue),
        pitchBend(kChannel1, kPitchBendCenterLSB, kPitchBendCenterMSB),
        noteOff(kChannel1, kNoteC4, kVelocityOff),
    };

    const int spacing = 8;  // buffers between successive messages
    for (size_t i = 0; i < expected.size(); ++i) {
        h.record(kDefaultTempo, kEventOffset, kChannel1, expected[i]);
        for (int b = 1; b < spacing; ++b) {
            h.advance(kDefaultTempo);
        }
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), expected.size(), @"every message is recorded");
    for (size_t i = 0; i < recorded.size() && i < expected.size(); ++i) {
        MidiMessage got = { { recorded[i].data[0], recorded[i].data[1], recorded[i].data[2] },
                            recorded[i].length };
        XCTAssertTrue(got == expected[i], @"recorded message %zu matches verbatim", i);
    }

    h.prepareForPlayback(0);
    const int playbackBuffers = spacing * (int(expected.size()) + 1);
    for (int b = 0; b < playbackBuffers; ++b) {
        h.advance(kDefaultTempo);
    }

    auto played = outputsOnCable(h.output, 0);
    XCTAssertEqual(played.size(), expected.size(), @"every message plays back");
    for (size_t i = 0; i < played.size() && i < expected.size(); ++i) {
        XCTAssertTrue(played[i].message == expected[i],
                      @"played message %zu matches verbatim and in order", i);
    }
}

// multiple messages inside the same render buffer keep their exact submission order
// and their relative sample offsets on playback.
- (void)testOrderWithinBufferIsPreserved {
    RecorderHarness h;
    h.armAndStart(0);

    const int recordBuffer = 30;
    const int offsetA = 5;
    const int offsetB = 100;
    const int offsetC = 400;
    const MidiMessage msgA = controlChange(kChannel1, kModWheelCC, kModWheelValue);
    const MidiMessage msgB = noteOn(kChannel1, kNoteA4, kVelocityOn);
    const MidiMessage msgC = noteOff(kChannel1, kNoteA4, kVelocityOff);

    for (int b = 0; b < recordBuffer; ++b) {
        h.advance(kDefaultTempo);
    }
    h.beginBuffer(kDefaultTempo);
    h.inject(offsetA, kChannel1, msgA);
    h.inject(offsetB, kChannel1, msgB);
    h.inject(offsetC, kChannel1, msgC);
    h.endBuffer();
    h.advance(kDefaultTempo);

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), 3u, @"all three messages in the buffer are recorded");

    h.prepareForPlayback(0);
    for (int b = 0; b < recordBuffer + 2; ++b) {
        h.advance(kDefaultTempo);
    }

    auto played = outputsOnCable(h.output, 0);
    XCTAssertEqual(played.size(), 3u);
    if (played.size() == 3) {
        XCTAssertTrue(played[0].message == msgA, @"control change plays first");
        XCTAssertTrue(played[1].message == msgB, @"note on plays second");
        XCTAssertTrue(played[2].message == msgC, @"note off plays third");
        XCTAssertLessThan(played[0].sampleTime, played[1].sampleTime, @"sample times rise in order");
        XCTAssertLessThan(played[1].sampleTime, played[2].sampleTime, @"sample times rise in order");
    }
}

#pragma mark - Routing and edge cases

// events are routed to tracks strictly by cable index: notes on cable 0 land on
// track 0 and notes on cable 1 land on track 1, with no cross-bleed.
- (void)testCableRoutingIsolatesTracks {
    RecorderHarness h;
    h.arm(0);
    h.arm(1);
    h.start();

    const int totalBuffers = 80;
    for (int b = 0; b < totalBuffers; ++b) {
        h.beginBuffer(kDefaultTempo);
        if (b == 20) h.inject(kEventOffset, /*cable*/0, noteOn(kChannel1, kNoteE4, kVelocityOn));
        if (b == 40) h.inject(kEventOffset, /*cable*/1, noteOn(kChannel1, kNoteG4, kVelocityOn));
        if (b == 60) h.inject(kEventOffset, /*cable*/1, noteOn(kChannel1, kNoteA4, kVelocityOn));
        h.endBuffer();
    }

    auto track0 = h.finalizeAndGetRecorded(0);
    auto track1 = h.finalizeAndGetRecorded(1);

    XCTAssertEqual(track0.size(), 1u, @"track 0 holds exactly its one note");
    XCTAssertEqual(track1.size(), 2u, @"track 1 holds exactly its two notes");
    if (track0.size() == 1) XCTAssertEqual(track0[0].data[1], kNoteE4);
    if (track1.size() == 2) {
        XCTAssertEqual(track1[0].data[1], kNoteG4);
        XCTAssertEqual(track1[1].data[1], kNoteA4);
    }
}

// a note-on followed later by its note-off is recorded and replayed as a pair,
// preserving the held duration.
- (void)testNoteOnThenNoteOffRoundTrip {
    RecorderHarness h;
    h.armAndStart(0);

    const int onBuffer = 20;
    const int offBuffer = 60;
    const int heldBuffers = offBuffer - onBuffer;
    const int totalBuffers = 100;
    for (int b = 0; b < totalBuffers; ++b) {
        h.beginBuffer(kDefaultTempo);
        if (b == onBuffer)  h.inject(kEventOffset, kChannel1, noteOn(kChannel1, kNoteC4, kVelocityOn));
        if (b == offBuffer) h.inject(kEventOffset, kChannel1, noteOff(kChannel1, kNoteC4, kVelocityOff));
        h.endBuffer();
    }

    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), 2u, @"note-on and note-off are both recorded");

    h.prepareForPlayback(0);
    for (int b = 0; b < totalBuffers + 20; ++b) {
        h.advance(kDefaultTempo);
    }

    double onTime = -1.0, offTime = -1.0;
    int onCount = 0, offCount = 0;
    for (auto& e : h.output) {
        if (isNoteOn(e.message))  { onCount++;  onTime = e.sampleTime; }
        else if (isNoteOff(e.message) && e.message.data[1] == kNoteC4) { offCount++; offTime = e.sampleTime; }
    }
    XCTAssertEqual(onCount, 1, @"exactly one note-on plays back");
    XCTAssertEqual(offCount, 1, @"exactly one note-off plays back");
    XCTAssertGreaterThan(offTime, onTime, @"note-off follows its note-on");

    double expectedHeld = double(heldBuffers) * kFrameCount;
    XCTAssertEqualWithAccuracy(offTime - onTime, expectedHeld, 1.0,
                               @"held duration is preserved through the round trip");
}

// a take with no input produces an empty track and emits nothing on playback.
- (void)testNoInputProducesEmptyTrack {
    RecorderHarness h;
    h.armAndStart(0);
    for (int b = 0; b < 50; ++b) {
        h.advance(kDefaultTempo);
    }
    auto recorded = h.finalizeAndGetRecorded(0);
    XCTAssertEqual(recorded.size(), 0u, @"no notes are recorded without input");

    h.prepareForPlayback(0);
    for (int b = 0; b < 60; ++b) {
        h.advance(kDefaultTempo);
    }
    XCTAssertEqual(noteOnsOf(h.output).size(), 0u, @"empty track plays nothing");
}

#pragma mark Continuous loop record

// continuous loop record re-records the whole loop window on each cycle: every pass
// is pinned to the loop start, so an overdub spans the entire window and replaces the
// previous content across it, including material recorded at the very loop head. uses
// CC (the customer's automation use case), which also keeps note on/off boundary
// handling in the overdub blend out of the picture.
- (void)testLoopRecordOverdubReplacesExistingLoopHead {
    RecorderHarness h;
    startLoopRecord(h);

    // base material recorded at the loop head on pass 1; overdub recorded later in
    // the loop on pass 2 (deliberately NOT at the head).
    const MidiMessage headCC = controlChange(kChannel1, 0x14, 100);
    const MidiMessage overCC = controlChange(kChannel1, 0x15, 100);

    std::vector<CapturedPass> captures;
    driveLoopRecord(h, /*numCaptures*/ 2, [&](int pass, int buffer, MidiMessage& out) {
        if (pass == 1 && buffer == 0) { out = headCC; return true; }  // base, at head
        if (pass == 2 && buffer == 2) { out = overCC; return true; }  // overdub, mid-loop
        return false;
    }, captures);

    XCTAssertEqual(captures.size(), 2u, @"expected a base and an overdub capture");
    if (captures.size() == 2) {
        // each captured pass spans the loop from its start, so an overdub covers the
        // whole window rather than only [first event, loop end).
        XCTAssertEqualWithAccuracy(captures[0].start, 0.0, 1e-9, @"base pass starts at the loop head");
        XCTAssertEqualWithAccuracy(captures[1].start, 0.0, 1e-9,
            @"overdub pass starts at the loop head so it spans the existing head material");
    }

    // end to end: after the overdub blends, the loop holds the overdub and none of
    // the base head material.
    const auto recorded = channelOnly(h.recordedMessages(0));
    bool hasOverdub = false;
    bool hasBaseHead = false;
    for (const auto& m : recorded) {
        if (sameBytes(m, overCC))  hasOverdub  = true;
        if (sameBytes(m, headCC))  hasBaseHead = true;
    }
    XCTAssertTrue(hasOverdub, @"overdub CC is present after the loop-record overdub");
    XCTAssertFalse(hasBaseHead, @"head material is replaced by the overdub");
}

// a silent loop cycle takes the no-event reset path instead of a capture. the fresh
// pass that path produces is also pinned to the loop start, so a following overdub
// still spans the whole window, head included.
- (void)testLoopRecordSilentCycleStillReplacesLoopHead {
    RecorderHarness h;
    startLoopRecord(h);

    const MidiMessage headCC = controlChange(kChannel1, 0x14, 100);
    const MidiMessage overCC = controlChange(kChannel1, 0x15, 100);

    std::vector<CapturedPass> captures;
    driveLoopRecord(h, /*numCaptures*/ 2, [&](int pass, int buffer, MidiMessage& out) {
        if (pass == 1 && buffer == 0) { out = headCC; return true; }  // base, at head
        // pass 2 is intentionally silent -> reset path
        if (pass == 3 && buffer == 2) { out = overCC; return true; }  // overdub, mid-loop
        return false;
    }, captures);

    XCTAssertEqual(captures.size(), 2u, @"a silent cycle produces no capture");
    if (captures.size() == 2) {
        XCTAssertEqualWithAccuracy(captures[0].start, 0.0, 1e-9, @"base pass starts at the loop head");
        XCTAssertEqualWithAccuracy(captures[1].start, 0.0, 1e-9,
            @"overdub after a silent cycle starts at the loop head");
    }

    const auto recorded = channelOnly(h.recordedMessages(0));
    bool hasOverdub = false;
    bool hasBaseHead = false;
    for (const auto& m : recorded) {
        if (sameBytes(m, overCC))  hasOverdub  = true;
        if (sameBytes(m, headCC))  hasBaseHead = true;
    }
    XCTAssertTrue(hasOverdub, @"overdub CC is present after the overdub");
    XCTAssertFalse(hasBaseHead, @"head material is replaced even across a silent cycle");
}

// stopping right after a loop wrap, while a just-captured pass is still awaiting its
// overdub blend, defers the finish: the recorder holds the final partial pass and,
// via flushDeferredFinish, hands it off once the pending pass has blended, so the
// partial pass is blended in turn. exercises that stop / capture-blend ordering.
- (void)testLoopRecordStopWhileCapturePendingKeepsFinalPass {
    RecorderHarness h;
    startLoopRecord(h);

    const MidiMessage firstCC = controlChange(kChannel1, 0x14, 100);  // pass 1, so it captures
    const MidiMessage finalCC = controlChange(kChannel1, 0x15, 100);  // pass 2, the final partial pass

    int pass = 1;
    int bufferInPass = 0;
    bool captured = false;              // pass 1 captured to pending; left unblended for this scenario
    bool pendingOccupiedAtStop = false;  // records that the stop landed while a blend was pending
    bool stopped = false;
    double prevPlay = h.kernel._state.playPositionBeats;

    for (int step = 0; step < 200 && !stopped; ++step) {
        MidiMessage msg;
        bool doInject = false;
        if (pass == 1 && bufferInPass == 1) { doInject = true; msg = firstCC; }
        else if (pass == 2 && bufferInPass == 1) { doInject = true; msg = finalCC; }

        bool pendingWasEmpty = (h.kernel._state.track[0].pendingRecordedData == nullptr);
        h.loopBuffer(doInject, kEventOffset, /*cable*/ 0, msg);

        // detect pass 1's capture. leave the blend unapplied, so the pass stays in
        // pendingRecordedData when the stop below lands.
        if (pendingWasEmpty && h.kernel._state.track[0].pendingRecordedData != nullptr) {
            captured = true;
        }

        // a buffer after the final partial pass records its event, stop while the
        // captured pass is still awaiting its blend.
        if (captured && pass == 2 && bufferInPass == 2) {
            pendingOccupiedAtStop = (h.kernel._state.track[0].pendingRecordedData != nullptr);
            [h.recorder(0) setRecord:NO];
            stopped = true;
        }

        double nowPlay = h.kernel._state.playPositionBeats;
        if (nowPlay < prevPlay) { pass += 1; bufferInPass = 0; }
        else { bufferInPass += 1; }
        prevPlay = nowPlay;
    }

    XCTAssertTrue(stopped, @"reached the stop-after-wrap window");
    XCTAssertTrue(pendingOccupiedAtStop, @"the stop landed while a captured pass was awaiting its blend");

    // settle like the real render loop: the kernel blends the pending pass, then the
    // recorder hands off the deferred partial pass, which then also blends.
    for (int i = 0; i < 6; ++i) {
        h.applyScheduledTransitions();        // kernel blends any pending pass
        [h.recorder(0) flushDeferredFinish];  // recorder hands off the deferred partial once pending clears
    }

    // the captured pass blends first (making the recording non-empty), then the
    // deferred partial pass blends on top, so its event appears in the final recording.
    const auto recorded = channelOnly(h.recordedMessages(0));
    bool hasFinal = false;
    for (const auto& m : recorded) {
        if (sameBytes(m, finalCC)) hasFinal = true;
    }
    XCTAssertFalse(recorded.empty(), @"the captured pass blended into the recording");
    XCTAssertTrue(hasFinal, @"the final partial pass's event appears after a stop that lands while the capture blend is pending");
}

// the loopRecord toggle selects what happens at the loop end while recording. with it
// off (the default), the loop end flags the punch-out signal; with it on, the kernel
// instead flags each recording track to capture its pass and keep going.
- (void)testLoopRecordToggleSelectsLoopEndBehavior {
    {   // toggle off: punch out at the loop end
        RecorderHarness h;
        startLoopRecord(h, /*loopRecord*/ false);
        driveToLoopEndWithEvent(h);

        XCTAssertFalse(h.kernel._state.processedUIEndRecord.test(),
                       @"with loop record off, the loop end flags a punch-out");
        XCTAssertTrue(h.kernel._state.processedCaptureRecording[0].test(),
                      @"with loop record off, no continue-recording capture is flagged");
    }

    {   // toggle on: keep recording past the loop end
        RecorderHarness h;
        startLoopRecord(h, /*loopRecord*/ true);
        driveToLoopEndWithEvent(h);

        XCTAssertTrue(h.kernel._state.processedUIEndRecord.test(),
                      @"with loop record on, the loop end does not punch out");
        XCTAssertFalse(h.kernel._state.processedCaptureRecording[0].test(),
                       @"with loop record on, the loop end flags a continue-recording capture");
    }
}

// loop record with notes (rather than CC): an overdub replaces note material at the
// loop head, and the recorded stream stays note-balanced with nothing left sounding.
- (void)testLoopRecordNotesOverdubReplacesHeadAndStaysBalanced {
    RecorderHarness h;
    startLoopRecord(h);

    // a complete base note at the loop head on pass 1; a different complete note as
    // the overdub on pass 2
    const MidiMessage baseOn  = noteOn(kChannel1, kNoteC4, kVelocityOn);
    const MidiMessage baseOff = noteOff(kChannel1, kNoteC4, kVelocityOff);
    const MidiMessage overOn  = noteOn(kChannel1, kNoteG4, kVelocityOn);
    const MidiMessage overOff = noteOff(kChannel1, kNoteG4, kVelocityOff);

    std::vector<CapturedPass> captures;
    driveLoopRecord(h, /*numCaptures*/ 2, [&](int pass, int buffer, MidiMessage& out) {
        if (pass == 1 && buffer == 0) { out = baseOn;  return true; }
        if (pass == 1 && buffer == 1) { out = baseOff; return true; }
        if (pass == 2 && buffer == 2) { out = overOn;  return true; }
        if (pass == 2 && buffer == 3) { out = overOff; return true; }
        return false;
    }, captures);

    XCTAssertEqual(captures.size(), 2u);

    const auto recorded = channelOnly(h.recordedMessages(0));
    bool hasBaseOn = false;
    bool hasOverOn = false;
    int netSounding = 0;   // note-ons minus note-offs
    for (const auto& m : recorded) {
        const MidiMessage mm = { { m.data[0], m.data[1], m.data[2] }, m.length };
        if (mm == baseOn) hasBaseOn = true;
        if (mm == overOn) hasOverOn = true;
        if (isNoteOn(mm))  netSounding += 1;
        if (isNoteOff(mm)) netSounding -= 1;
    }
    XCTAssertFalse(hasBaseOn, @"the base head note is replaced by the overdub");
    XCTAssertTrue(hasOverOn, @"the overdub note is present");
    XCTAssertEqual(netSounding, 0, @"note-ons and note-offs balance, leaving nothing sounding");
}

// with punch in/out active inside the loop, each captured pass covers the punch
// window rather than the whole loop, so an overdub replaces only the punched region.
- (void)testLoopRecordPunchLimitsReplacementToPunchWindow {
    RecorderHarness h;
    startLoopRecord(h);   // loop [0, kLoopLengthBeats]

    const double punchIn = 0.025;
    const double punchOut = 0.075;
    h.kernel._state.punchInPositionBeats = punchIn;
    h.kernel._state.punchOutPositionBeats = punchOut;
    h.kernel._state.punchInOut.test_and_set();

    // buffer 2 (~0.046 beats) falls inside the punch window
    const MidiMessage note = noteOn(kChannel1, kNoteC4, kVelocityOn);
    std::vector<CapturedPass> captures;
    driveLoopRecord(h, /*numCaptures*/ 2, [&](int pass, int buffer, MidiMessage& out) {
        if (buffer == 2) { out = note; return true; }
        return false;
    }, captures);

    XCTAssertEqual(captures.size(), 2u);
    if (captures.size() == 2) {
        // the pass created by a capture is pinned to punch-in and clamped to punch-out,
        // rather than spanning the whole loop
        XCTAssertEqualWithAccuracy(captures[1].start, punchIn, 1e-9,
            @"an overdub pass starts at punch-in, not the loop start");
        XCTAssertEqualWithAccuracy(captures[1].duration, punchOut, 1e-9,
            @"an overdub pass ends at punch-out, not the loop end");
    }
}

// multi-track loop record: two armed tracks, where track 1 records a base note on the
// first pass and then stays silent while track 0 keeps loop-recording. A cycle's
// "had events" decision is per track, so the silent track keeps its content, records
// no empty overdub, and is not left with a pending pass, while track 0's overdub still
// lands.
- (void)testLoopRecordMultiTrackSilentTrackKeepsContent {
    RecorderHarness h;
    h.arm(0);
    h.arm(1);
    h.start();
    h.kernel._state.startPositionBeats = 0.0;
    h.kernel._state.stopPositionBeats = kLoopLengthBeats;
    h.kernel._state.repeatEnabled.test_and_set();
    h.kernel._state.repeatActive.test_and_set();
    h.kernel._state.loopRecord.test_and_set();

    const MidiMessage t0Note    = noteOn(kChannel1, kNoteC4, kVelocityOn);
    const MidiMessage t1BaseOn  = noteOn(kChannel1, kNoteE4, kVelocityOn);
    const MidiMessage t1BaseOff = noteOff(kChannel1, kNoteE4, kVelocityOff);

    int pass = 1;
    int bufferInPass = 0;
    int t0Captures = 0;
    double prevPlay = h.kernel._state.playPositionBeats;

    for (int step = 0; step < 400 && t0Captures < 2; ++step) {
        h.beginBuffer(kDefaultTempo);
        if (bufferInPass == 2) h.inject(kEventOffset, /*cable*/ 0, t0Note);            // track 0, every pass
        if (pass == 1 && bufferInPass == 0) h.inject(kEventOffset, /*cable*/ 1, t1BaseOn);   // track 1, pass 1 only
        if (pass == 1 && bufferInPass == 1) h.inject(kEventOffset, /*cable*/ 1, t1BaseOff);
        h.endBuffer();
        [h.qp processMidiQueue:&h.kernel._state.midiBuffer];

        // a capture shows up as track 0's pending data appearing; blend both tracks
        if (h.kernel._state.track[0].pendingRecordedData != nullptr) {
            t0Captures += 1;
            h.applyScheduledTransitions();
        }

        double nowPlay = h.kernel._state.playPositionBeats;
        if (nowPlay < prevPlay) { pass += 1; bufferInPass = 0; }
        else { bufferInPass += 1; }
        prevPlay = nowPlay;
    }

    XCTAssertEqual(t0Captures, 2, @"track 0 overdubs across cycles");

    // track 0's overdub landed
    bool t0HasNote = false;
    for (const auto& m : channelOnly(h.recordedMessages(0))) {
        const MidiMessage mm = { { m.data[0], m.data[1], m.data[2] }, m.length };
        if (mm == t0Note) t0HasNote = true;
    }
    XCTAssertTrue(t0HasNote, @"the loop-recording track keeps recording its overdubs");

    // track 1 was armed but silent after its first pass: its content survives, and it
    // is neither captured empty nor left pending
    XCTAssertTrue(h.kernel._state.track[1].pendingRecordedData == nullptr,
                  @"a silent armed track is not left with a pending pass");
    bool t1HasBase = false;
    for (const auto& m : channelOnly(h.recordedMessages(1))) {
        const MidiMessage mm = { { m.data[0], m.data[1], m.data[2] }, m.length };
        if (mm == t1BaseOn) t1HasBase = true;
    }
    XCTAssertTrue(t1HasBase, @"a silent armed track keeps its content while another track loop-records");
}

@end

#pragma mark - MIDI clock tempo tracking

// tests for the MIDI-clock-to-tempo logic used by the standalone host's
// MidiPortManager. the math lives in MidiClockTempoTracker so it can be exercised
// directly, without CoreMIDI, audio or UI.
@interface MidiClockTempoTrackerTests : XCTestCase
@end

@implementation MidiClockTempoTrackerTests

// a steady stream of pulses at the interval for a tempo yields exactly that tempo.
- (void)testDerivesTempoFromConstantPulseInterval {
    for (double bpm : { kSlowTempo, kDefaultTempo, kFastTempo }) {
        MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
        double interval = clockPulseInterval(bpm);
        double t = 1000.0;
        for (int i = 0; i < 50; ++i) {
            [tracker pulseAtSeconds:t];
            t += interval;
        }
        XCTAssertEqualWithAccuracy(tracker.tempo, bpm, 1e-6,
                                   @"a constant clock interval resolves to its BPM");
        XCTAssertTrue(tracker.isActive);
    }
}

// the first pulse activates the clock; a tempo needs an interval (two pulses).
- (void)testFirstPulseActivatesSecondEstablishesTempo {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    double interval = clockPulseInterval(kDefaultTempo);
    double t = 10.0;

    BOOL updated = [tracker pulseAtSeconds:t];
    XCTAssertFalse(updated, @"the first pulse has no interval to measure");
    XCTAssertTrue(tracker.isActive, @"but the first pulse activates the clock");
    XCTAssertEqual(tracker.tempo, 0.0, @"no tempo until an interval is measured");

    updated = [tracker pulseAtSeconds:t + interval];
    XCTAssertTrue(updated);
    XCTAssertEqualWithAccuracy(tracker.tempo, kDefaultTempo, 1e-6);
}

// pulse intervals implying an out-of-range tempo are rejected as noise; the range
// endpoints themselves are accepted.
- (void)testIgnoresOutOfRangeTempos {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];

    // below the minimum
    double tooSlow = clockPulseInterval(MidiClockMinBPM - 5.0);
    [tracker pulseAtSeconds:0.0];
    XCTAssertFalse([tracker pulseAtSeconds:tooSlow]);
    XCTAssertEqual(tracker.tempo, 0.0, @"sub-minimum tempo is ignored");

    // above the maximum
    [tracker reset];
    double tooFast = clockPulseInterval(MidiClockMaxBPM + 50.0);
    [tracker pulseAtSeconds:100.0];
    XCTAssertFalse([tracker pulseAtSeconds:100.0 + tooFast]);
    XCTAssertEqual(tracker.tempo, 0.0, @"super-maximum tempo is ignored");

    // exactly the minimum is in range
    [tracker reset];
    double atMin = clockPulseInterval(MidiClockMinBPM);
    [tracker pulseAtSeconds:200.0];
    XCTAssertTrue([tracker pulseAtSeconds:200.0 + atMin], @"the minimum BPM is in range");
    XCTAssertEqualWithAccuracy(tracker.tempo, MidiClockMinBPM, 1e-6);
}

// smoothing blends the running tempo toward newer measurements by the configured
// ratio, without overshooting, and converges under a sustained new tempo.
- (void)testSmoothingBlendsTowardNewTempo {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    double t = 0.0;

    // two pulses establish exactly kDefaultTempo
    double slowInterval = clockPulseInterval(kDefaultTempo);
    [tracker pulseAtSeconds:t]; t += slowInterval;
    [tracker pulseAtSeconds:t];
    XCTAssertEqualWithAccuracy(tracker.tempo, kDefaultTempo, 1e-6);

    // a single faster pulse blends old and new by the smoothing ratio
    double before = tracker.tempo;
    double fastInterval = clockPulseInterval(kFastTempo);
    t += fastInterval;
    [tracker pulseAtSeconds:t];
    double expected = kDefaultTempo * MidiClockSmoothingRetained +
                      kFastTempo * (1.0 - MidiClockSmoothingRetained);
    XCTAssertEqualWithAccuracy(tracker.tempo, expected, 1e-6,
                               @"one step blends old and new by the smoothing ratio");
    XCTAssertGreaterThan(tracker.tempo, before, @"tempo moves toward the faster clock");
    XCTAssertLessThan(tracker.tempo, kFastTempo, @"but never overshoots the new tempo");

    // a sustained fast clock converges to the new tempo
    for (int i = 0; i < 60; ++i) { t += fastInterval; [tracker pulseAtSeconds:t]; }
    XCTAssertEqualWithAccuracy(tracker.tempo, kFastTempo, 0.5,
                               @"sustained fast clock converges to the new tempo");
}

// the clock stays active until strictly past the timeout, then transitions once.
- (void)testTimesOutAfterSilence {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    double interval = clockPulseInterval(kDefaultTempo);
    double t = 0.0;
    [tracker pulseAtSeconds:t]; t += interval;
    [tracker pulseAtSeconds:t];
    XCTAssertTrue(tracker.isActive);

    XCTAssertFalse([tracker expireIfStaleAtSeconds:t + MidiClockTimeout],
                   @"not stale until strictly past the timeout");
    XCTAssertTrue(tracker.isActive);

    XCTAssertTrue([tracker expireIfStaleAtSeconds:t + MidiClockTimeout + 0.01],
                  @"past the timeout it goes inactive");
    XCTAssertFalse(tracker.isActive);
    XCTAssertFalse([tracker expireIfStaleAtSeconds:t + 100.0],
                   @"already inactive, so no further transition");
}

// after a timeout the next clock re-activates and needs a fresh interval to
// measure again.
- (void)testReactivatesAfterTimeout {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    double interval = clockPulseInterval(kFastTempo);
    double t = 0.0;
    [tracker pulseAtSeconds:t]; t += interval;
    [tracker pulseAtSeconds:t];
    XCTAssertTrue(tracker.isActive);

    [tracker expireIfStaleAtSeconds:t + MidiClockTimeout + 1.0];
    XCTAssertFalse(tracker.isActive);

    double t2 = t + 5.0;
    BOOL updated = [tracker pulseAtSeconds:t2];
    XCTAssertTrue(tracker.isActive, @"a pulse re-activates the clock");
    XCTAssertFalse(updated, @"the first pulse after a timeout has no interval to measure");

    updated = [tracker pulseAtSeconds:t2 + interval];
    XCTAssertTrue(updated);
    XCTAssertEqualWithAccuracy(tracker.tempo, kFastTempo, 0.5);
}

// non-increasing pulse timestamps (duplicates or backwards) never derive a tempo.
- (void)testIgnoresNonIncreasingTimestamps {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    [tracker pulseAtSeconds:5.0];
    XCTAssertFalse([tracker pulseAtSeconds:5.0], @"a zero interval cannot produce a tempo");
    XCTAssertEqual(tracker.tempo, 0.0);
    XCTAssertFalse([tracker pulseAtSeconds:4.0], @"a backwards interval cannot either");
    XCTAssertEqual(tracker.tempo, 0.0);
}

// reset returns the tracker to its initial state.
- (void)testResetClearsState {
    MidiClockTempoTracker* tracker = [[MidiClockTempoTracker alloc] init];
    double interval = clockPulseInterval(kDefaultTempo);
    [tracker pulseAtSeconds:1.0];
    [tracker pulseAtSeconds:1.0 + interval];
    XCTAssertGreaterThan(tracker.tempo, 0.0);
    XCTAssertTrue(tracker.isActive);

    [tracker reset];
    XCTAssertEqual(tracker.tempo, 0.0);
    XCTAssertFalse(tracker.isActive);
}

@end

#pragma mark - Standard MIDI File import / export

// tests for the Standard MIDI File writer/reader in MidiQueueProcessor +
// MidiTrackRecorder, checking SMF structural invariants and record round trips.
@interface MidiFileTests : XCTestCase
@end

@implementation MidiFileTests

// the exported file is a well-formed format-1 SMF header framing one track chunk.
- (void)testExportedFileHasValidHeader {
    RecorderHarness h;
    recordAndCapture(h, 0, { noteOn(kChannel1, kNoteC4, kVelocityOn),
                            noteOff(kChannel1, kNoteC4, kVelocityOff) });
    NSData* file = [h.qp recordedTrackAsMidiFile:0];
    XCTAssertNotNil(file);

    XCTAssertTrue(tag4(file, 0, "MThd"), @"file starts with the MThd magic");
    XCTAssertEqual(beU32(file, 4), 6u, @"MThd payload is 6 bytes");
    XCTAssertEqual(beU16(file, 8), 1, @"format 1");
    XCTAssertEqual(beU16(file, 10), 1, @"one non-empty track");
    XCTAssertEqual(beU16(file, 12), (uint16_t)MIDI_BEAT_TICKS, @"division is the tick resolution");

    XCTAssertTrue(tag4(file, 14, "MTrk"), @"a track chunk follows the header");
    uint32_t chunkLength = beU32(file, 18);
    XCTAssertEqual((NSUInteger)(14 + 8 + chunkLength), file.length,
                   @"the MTrk length frames exactly the rest of the file");
}

// the track body begins with a Set Tempo meta event carrying the host tempo and
// ends with an End Of Track meta event.
- (void)testExportedTrackHasTempoAndEndOfTrack {
    RecorderHarness h;
    recordAndCapture(h, 0, { noteOn(kChannel1, kNoteE4, kVelocityOn),
                            noteOff(kChannel1, kNoteE4, kVelocityOff) });
    NSData* file = [h.qp recordedTrackAsMidiFile:0];
    const uint8_t* b = (const uint8_t*)file.bytes;

    NSUInteger body = 14 + 8;   // first event, after MThd and the MTrk header
    XCTAssertEqual(b[body + 0], 0x00, @"the tempo event sits at delta 0");
    XCTAssertEqual(b[body + 1], kMetaPrefix);
    XCTAssertEqual(b[body + 2], kMetaSetTempo);
    XCTAssertEqual(b[body + 3], 0x03, @"the tempo payload is 3 bytes");
    uint32_t micros = ((uint32_t)b[body + 4] << 16) | ((uint32_t)b[body + 5] << 8) | b[body + 6];
    XCTAssertEqualWithAccuracy((double)micros, microsecondsPerBeatFor(kDefaultTempo), 1.0,
                               @"the tempo meta encodes the host tempo");

    NSUInteger n = file.length;
    XCTAssertEqual(b[n - 3], kMetaPrefix);
    XCTAssertEqual(b[n - 2], kMetaEndOfTrack, @"the track ends with End Of Track");
    XCTAssertEqual(b[n - 1], 0x00);
}

// an empty track exports a valid header reporting zero tracks and no chunks.
- (void)testEmptyTrackExportsHeaderOnly {
    RecorderHarness h;
    NSData* file = [h.qp recordedTrackAsMidiFile:0];   // nothing recorded
    XCTAssertNotNil(file);
    XCTAssertEqual(file.length, 14u, @"only the MThd header, no track chunks");
    XCTAssertTrue(tag4(file, 0, "MThd"));
    XCTAssertEqual(beU16(file, 10), 0, @"zero tracks");
}

// exporting then importing a track reproduces every message verbatim and in order,
// with timing preserved to within one tick of the file's resolution.
- (void)testRoundTripPreservesMessagesAndTiming {
    RecorderHarness h;
    std::vector<MidiMessage> msgs = {
        noteOn(kChannel1, kNoteC4, kVelocityOn),
        controlChange(kChannel1, kModWheelCC, kModWheelValue),
        noteOff(kChannel1, kNoteC4, kVelocityOff),
        noteOn(kChannel1, kNoteG4, kVelocityOn),
        noteOff(kChannel1, kNoteG4, kVelocityOff),
    };
    auto original = channelOnly(recordAndCapture(h, 0, msgs));
    XCTAssertEqual(original.size(), msgs.size());

    NSData* file = [h.qp recordedTrackAsMidiFile:0];

    // import into a different track ordinal and read it back
    [h.qp midiFileToRecordedTrack:file ordinal:1];
    auto imported = channelOnly(h.pendingMessages(1));

    XCTAssertEqual(imported.size(), original.size(), @"the message count is preserved");
    double tickBeats = 1.0 / (double)MIDI_BEAT_TICKS;
    for (size_t i = 0; i < imported.size() && i < original.size(); ++i) {
        XCTAssertEqual(imported[i].length, original[i].length, @"length preserved at %zu", i);
        XCTAssertEqual(imported[i].data[0], original[i].data[0], @"status preserved at %zu", i);
        XCTAssertEqual(imported[i].data[1], original[i].data[1], @"data1 preserved at %zu", i);
        XCTAssertEqual(imported[i].data[2], original[i].data[2], @"data2 preserved at %zu", i);
        XCTAssertEqualWithAccuracy(imported[i].offsetBeats, original[i].offsetBeats, 2.0 * tickBeats,
                                   @"timing preserved within a tick at %zu", i);
    }
}

// every channel-voice message type survives a file round trip byte-for-byte,
// including the 2-byte program change and channel pressure.
- (void)testRoundTripPreservesAllMessageTypes {
    RecorderHarness h;
    std::vector<MidiMessage> msgs = {
        noteOn(kChannel1, kNoteC4, kVelocityOn),
        polyKeyPressure(kChannel1, kNoteC4, kAftertouchValue),
        controlChange(kChannel1, kModWheelCC, kModWheelValue),
        programChange(kChannel1, kProgramNumber),
        channelPressure(kChannel1, kChannelPressureValue),
        pitchBend(kChannel1, kPitchBendCenterLSB, kPitchBendCenterMSB),
        noteOff(kChannel1, kNoteC4, kVelocityOff),
    };
    recordAndCapture(h, 0, msgs);
    NSData* file = [h.qp recordedTrackAsMidiFile:0];

    [h.qp midiFileToRecordedTrack:file ordinal:2];
    auto imported = channelOnly(h.pendingMessages(2));

    XCTAssertEqual(imported.size(), msgs.size());
    for (size_t i = 0; i < imported.size() && i < msgs.size(); ++i) {
        XCTAssertTrue(sameBytes(imported[i], msgs[i]),
                      @"message %zu (status 0x%02X) survives the round trip",
                      i, msgs[i].data[0]);
    }
}

// a multi-track export reports the number of non-empty tracks and re-imports them
// back onto the correct track ordinals.
- (void)testMultiTrackFileCountAndReimport {
    RecorderHarness h;
    h.arm(0);
    h.arm(1);
    h.start();
    for (int b = 0; b < 40; ++b) {
        h.beginBuffer(kDefaultTempo);
        if (b == 10) h.inject(kEventOffset, 0, noteOn(kChannel1, kNoteC4, kVelocityOn));
        if (b == 15) h.inject(kEventOffset, 1, noteOn(kChannel1, kNoteG4, kVelocityOn));
        if (b == 20) h.inject(kEventOffset, 0, noteOff(kChannel1, kNoteC4, kVelocityOff));
        if (b == 25) h.inject(kEventOffset, 1, noteOff(kChannel1, kNoteG4, kVelocityOff));
        h.endBuffer();
    }
    h.finalizeAndGetRecorded(0);
    h.finalizeAndGetRecorded(1);
    h.captureRecording(0);
    h.captureRecording(1);

    NSData* file = [h.qp recordedTracksAsMidiFile];
    XCTAssertTrue(tag4(file, 0, "MThd"));
    XCTAssertEqual(beU16(file, 10), 2, @"the file reports two non-empty tracks");

    // re-import the whole file into a fresh engine
    RecorderHarness dst;
    [dst.qp midiFileToRecordedTrack:file ordinal:-1];
    auto t0 = channelOnly(dst.pendingMessages(0));
    auto t1 = channelOnly(dst.pendingMessages(1));
    XCTAssertEqual(t0.size(), 2u, @"track 0 round-trips its two messages");
    XCTAssertEqual(t1.size(), 2u, @"track 1 round-trips its two messages");
    if (t0.size() == 2) XCTAssertEqual(t0[0].data[1], kNoteC4);
    if (t1.size() == 2) XCTAssertEqual(t1[0].data[1], kNoteG4);
}

// a leading conductor (meta-only) chunk is skipped so note content lands on the
// first usable track ordinal.
- (void)testImportSkipsConductorTrack {
    RecorderHarness h;
    recordAndCapture(h, 0, { noteOn(kChannel1, kNoteA4, kVelocityOn),
                            noteOff(kChannel1, kNoteA4, kVelocityOff) });
    NSData* single = [h.qp recordedTrackAsMidiFile:0];
    NSUInteger trackOff = firstTrackChunkOffset(single);
    XCTAssertNotEqual(trackOff, (NSUInteger)NSNotFound);
    uint32_t chunkLen = beU32(single, trackOff + 4);
    NSData* realChunk = [single subdataWithRange:NSMakeRange(trackOff, 8 + chunkLen)];

    // header(ntrks=2) + conductor (tempo + EOT only) + the real note chunk
    NSMutableData* file = [makeFileHeader(6, 1, 2, (uint16_t)MIDI_BEAT_TICKS) mutableCopy];
    const uint8_t conductorBody[] = {
        0x00, kMetaPrefix, kMetaSetTempo, 0x03, 0x07, 0xA1, 0x20,  // 120 BPM
        0x00, kMetaPrefix, kMetaEndOfTrack, 0x00,
    };
    uint8_t conductorHeader[8] = { 'M', 'T', 'r', 'k', 0, 0, 0, (uint8_t)sizeof(conductorBody) };
    [file appendBytes:conductorHeader length:8];
    [file appendBytes:conductorBody length:sizeof(conductorBody)];
    [file appendData:realChunk];

    RecorderHarness dst;
    [dst.qp midiFileToRecordedTrack:file ordinal:-1];
    auto t0 = channelOnly(dst.pendingMessages(0));
    XCTAssertEqual(t0.size(), 2u, @"the note track lands on track 0, conductor skipped");
    XCTAssertTrue(dst.pendingMessages(1).empty(), @"nothing spilled onto track 1");
    if (t0.size() == 2) XCTAssertEqual(t0[0].data[1], kNoteA4);
}

// the importer rejects malformed files and leaves the target track untouched.
- (void)testImportRejectsMalformedFiles {
    uint16_t division = (uint16_t)MIDI_BEAT_TICKS;

    NSData* badMagic = [@"NOPE--this--is--not--a--midi--file" dataUsingEncoding:NSASCIIStringEncoding];
    NSArray<NSData*>* bad = @[
        [NSData data],                              // empty
        badMagic,                                   // wrong magic
        makeFileHeader(7, 1, 1, division),          // wrong header length
        makeFileHeader(6, 1, 1, 0xE728),            // SMPTE division (high bit set)
        makeFileHeader(6, 1, 0, division),          // zero tracks
    ];

    for (NSData* file in bad) {
        RecorderHarness dst;
        [dst.qp midiFileToRecordedTrack:file ordinal:0];
        XCTAssertTrue(dst.pendingMessages(0).empty(), @"a malformed file imports nothing");
    }
}

// a track body that ends in the middle of a variable-length quantity (a dangling
// continuation byte) stays within the chunk's bounds: the complete events before
// the truncation are imported and the parse terminates cleanly.
- (void)testImportSurvivesTruncatedVarLen {
    uint16_t division = (uint16_t)MIDI_BEAT_TICKS;
    NSMutableData* file = [makeFileHeader(6, 1, 1, division) mutableCopy];
    const uint8_t body[] = {
        0x00, 0x90, kNoteC4, kVelocityOn,    // note on
        0x00, 0x80, kNoteC4, kVelocityOff,   // note off
        0x81,                                // delta time cut off mid-quantity
    };
    uint8_t trackHeader[8] = { 'M', 'T', 'r', 'k', 0, 0, 0, (uint8_t)sizeof(body) };
    [file appendBytes:trackHeader length:8];
    [file appendBytes:body length:sizeof(body)];

    RecorderHarness dst;
    [dst.qp midiFileToRecordedTrack:file ordinal:0];
    auto msgs = channelOnly(dst.pendingMessages(0));
    XCTAssertEqual(msgs.size(), 2u, @"the complete events before the truncation are imported");
}

// system common events (0xF1-0xF3) carry data bytes; the importer skips them
// together with their data so the events that follow keep parsing in sync.
- (void)testImportSkipsSystemCommonDataBytes {
    uint16_t division = (uint16_t)MIDI_BEAT_TICKS;
    NSMutableData* file = [makeFileHeader(6, 1, 1, division) mutableCopy];
    const uint8_t body[] = {
        0x00, 0xF3, 0x05,                    // song select + its data byte
        0x00, 0xF2, 0x10, 0x20,              // song position + its two data bytes
        0x00, 0x90, kNoteC4, kVelocityOn,    // note on
        0x00, 0x80, kNoteC4, kVelocityOff,   // note off
        0x00, kMetaPrefix, kMetaEndOfTrack, 0x00,
    };
    uint8_t trackHeader[8] = { 'M', 'T', 'r', 'k', 0, 0, 0, (uint8_t)sizeof(body) };
    [file appendBytes:trackHeader length:8];
    [file appendBytes:body length:sizeof(body)];

    RecorderHarness dst;
    [dst.qp midiFileToRecordedTrack:file ordinal:0];
    auto msgs = channelOnly(dst.pendingMessages(0));
    XCTAssertEqual(msgs.size(), 2u, @"the note events after the system common data are imported");
    if (msgs.size() == 2) {
        XCTAssertEqual(msgs[0].data[0] & 0xF0, 0x90, @"the note-on parses with its own status");
        XCTAssertEqual(msgs[0].data[1], kNoteC4);
    }
}

@end

#pragma mark - Host fullState <-> .mid bridge

// tests for HostTrackFile, which the standalone host uses to import/export all
// tracks across the AUv3 boundary via the unit's fullState dictionary.
@interface HostTrackFileTests : XCTestCase
@end

@implementation HostTrackFileTests

// exporting a fullState with two recorded tracks yields a valid two-track SMF.
- (void)testExportFromFullStateProducesValidMultiTrackFile {
    std::vector<RecordedMidiMessage> t0 = {
        recordedAt(noteOn(kChannel1, kNoteC4, kVelocityOn), 0.0),
        recordedAt(noteOff(kChannel1, kNoteC4, kVelocityOff), 1.0),
    };
    std::vector<RecordedMidiMessage> t1 = {
        recordedAt(noteOn(kChannel1, kNoteG4, kVelocityOn), 0.0),
        recordedAt(noteOff(kChannel1, kNoteG4, kVelocityOff), 2.0),
    };
    NSDictionary* fullState = @{
        @"Recorder0": recorderEntry(t0, 2.0),
        @"Recorder1": recorderEntry(t1, 3.0),
    };

    NSData* file = [HostTrackFile midiFileFromFullState:fullState tempo:kDefaultTempo];
    XCTAssertNotNil(file);
    XCTAssertTrue(tag4(file, 0, "MThd"));
    XCTAssertEqual(beU16(file, 8), 1, @"format 1");
    XCTAssertEqual(beU16(file, 10), 2, @"two non-empty tracks exported");
}

// a fullState with no recordings exports nothing.
- (void)testEmptyFullStateExportsNil {
    XCTAssertNil([HostTrackFile midiFileFromFullState:@{} tempo:kDefaultTempo]);
}

// round trip: a fullState exported to a .mid and re-imported reproduces the track
// messages (verbatim, within one tick) and clears tracks the file didn't fill.
- (void)testFullStateRoundTripThroughMidiFile {
    std::vector<RecordedMidiMessage> original = {
        recordedAt(noteOn(kChannel1, kNoteC4, kVelocityOn), 0.0),
        recordedAt(controlChange(kChannel1, kModWheelCC, kModWheelValue), 1.0),
        recordedAt(programChange(kChannel1, kProgramNumber), 2.0),
        recordedAt(noteOff(kChannel1, kNoteC4, kVelocityOff), 3.0),
    };
    NSDictionary* fullState = @{ @"Recorder0": recorderEntry(original, 4.0) };

    NSData* file = [HostTrackFile midiFileFromFullState:fullState tempo:kDefaultTempo];
    XCTAssertNotNil(file);

    NSDictionary* newState = [HostTrackFile fullStateByImporting:file intoFullState:@{}];
    XCTAssertNotNil(newState);

    auto imported = messagesFromRecorderEntry(newState[@"Recorder0"]);
    XCTAssertEqual(imported.size(), original.size());
    double tick = 1.0 / (double)MIDI_BEAT_TICKS;
    for (size_t i = 0; i < imported.size() && i < original.size(); ++i) {
        XCTAssertEqual(imported[i].length, original[i].length, @"length @ %zu", i);
        XCTAssertEqual(imported[i].data[0], original[i].data[0], @"status @ %zu", i);
        XCTAssertEqual(imported[i].data[1], original[i].data[1], @"data1 @ %zu", i);
        XCTAssertEqual(imported[i].data[2], original[i].data[2], @"data2 @ %zu", i);
        XCTAssertEqualWithAccuracy(imported[i].offsetBeats, original[i].offsetBeats, 2.0 * tick,
                                   @"offset @ %zu", i);
    }

    // tracks not present in the file are cleared
    XCTAssertTrue(messagesFromRecorderEntry(newState[@"Recorder1"]).empty(), @"track 1 cleared");
    XCTAssertTrue(messagesFromRecorderEntry(newState[@"Recorder3"]).empty(), @"track 3 cleared");
}

// importing preserves unrelated fullState keys (settings, parameters, ...).
- (void)testImportPreservesUnrelatedFullStateKeys {
    std::vector<RecordedMidiMessage> t0 = {
        recordedAt(noteOn(kChannel1, kNoteC4, kVelocityOn), 0.0),
        recordedAt(noteOff(kChannel1, kNoteC4, kVelocityOff), 1.0),
    };
    NSData* file = [HostTrackFile midiFileFromFullState:@{ @"Recorder0": recorderEntry(t0, 2.0) }
                                                  tempo:kDefaultTempo];

    NSDictionary* existing = @{ @"Grid": @YES, @"Repeat": @NO, @"Recorder0": @{} };
    NSDictionary* newState = [HostTrackFile fullStateByImporting:file intoFullState:existing];
    XCTAssertEqualObjects(newState[@"Grid"], @YES, @"unrelated keys are preserved");
    XCTAssertEqualObjects(newState[@"Repeat"], @NO);
    XCTAssertEqual(messagesFromRecorderEntry(newState[@"Recorder0"]).size(), 2u);
}

// invalid files are rejected, leaving the host with no state to apply.
- (void)testImportRejectsInvalidFiles {
    XCTAssertNil([HostTrackFile fullStateByImporting:[NSData data] intoFullState:@{}]);
    XCTAssertNil([HostTrackFile fullStateByImporting:[@"not a midi file at all" dataUsingEncoding:NSASCIIStringEncoding]
                                       intoFullState:@{}]);
}

@end

#pragma mark - Session document persistence

// tests for HostSession, the serializer behind autosave and .mtrec session files.
@interface HostSessionTests : XCTestCase
@end

@implementation HostSessionTests

// a session round-trips the full state (including recorded track blobs) and tempo.
- (void)testSessionRoundTrip {
    std::vector<RecordedMidiMessage> t0 = {
        recordedAt(noteOn(kChannel1, kNoteC4, kVelocityOn), 0.0),
        recordedAt(noteOff(kChannel1, kNoteC4, kVelocityOff), 1.0),
    };
    NSDictionary* fullState = @{
        @"Recorder0": recorderEntry(t0, 2.0),
        @"Grid": @YES,
        @"Repeat": @NO,
    };

    NSData* data = [HostSession dataWithFullState:fullState tempo:96.0];
    XCTAssertNotNil(data);

    NSDictionary* restored = nil;
    double tempo = 0.0;
    XCTAssertTrue([HostSession readData:data fullState:&restored tempo:&tempo]);
    XCTAssertEqualWithAccuracy(tempo, 96.0, 1e-9, @"tempo is preserved");
    XCTAssertEqualObjects(restored[@"Grid"], @YES, @"settings are preserved");
    XCTAssertEqualObjects(restored[@"Repeat"], @NO);
    XCTAssertEqual(messagesFromRecorderEntry(restored[@"Recorder0"]).size(), 2u,
                   @"recorded track content survives");
    XCTAssertEqualObjects(restored, fullState, @"the full state round-trips exactly");
}

// the loop-record setting round-trips through a saved session alongside the other
// behaviour flags, so it survives closing and reopening a project.
- (void)testSessionPreservesLoopRecordSetting {
    for (id value in @[ @YES, @NO ]) {
        NSDictionary* fullState = @{ @"LoopRecord": value, @"Repeat": @YES };

        NSData* data = [HostSession dataWithFullState:fullState tempo:120.0];
        XCTAssertNotNil(data);

        NSDictionary* restored = nil;
        double tempo = 0.0;
        XCTAssertTrue([HostSession readData:data fullState:&restored tempo:&tempo]);
        XCTAssertEqualObjects(restored[@"LoopRecord"], value,
                              @"the loop-record setting round-trips through a session");
    }
}

// garbage data is rejected rather than misread as a session.
- (void)testSessionRejectsInvalidData {
    NSDictionary* fullState = nil;
    double tempo = 120.0;
    XCTAssertFalse([HostSession readData:[NSData data] fullState:&fullState tempo:&tempo]);
    XCTAssertFalse([HostSession readData:[@"not a session" dataUsingEncoding:NSASCIIStringEncoding]
                               fullState:&fullState tempo:&tempo]);
    XCTAssertEqual(tempo, 120.0, @"invalid data leaves the out tempo untouched");
}

@end
