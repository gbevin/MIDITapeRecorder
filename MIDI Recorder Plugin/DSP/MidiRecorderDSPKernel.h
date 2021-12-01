//
//  MidiRecorderDSPKernel.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#import "AudioUnitIOState.h"
#import "DSPKernel.h"
#import "MidiRecorderState.h"

enum {
    paramOne = 0,
};

/*
 MidiRecorderDSPKernel
 Performs simple copying of the input signal to the output.
 As a non-ObjC class, this is safe to use from render thread.
 */
class MidiRecorderDSPKernel : public DSPKernel {
public:
    
    // MARK: Member Functions

    MidiRecorderDSPKernel();
    
    void cleanup();

    bool isBypassed();
    void setBypass(bool shouldBypass);
    
    void rewind();
    void play();
    void stop();

    void setParameter(AUParameterAddress address, AUValue value);
    AUValue getParameter(AUParameterAddress address);

    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList);
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override;
    void handleMIDIEvent(AUMIDIEvent const& midiEvent) override;
    void processOutput() override;

    MidiRecorderState _state;
    AudioUnitIOState _ioState;

    // MARK: Member Variables

private:
    void queueMIDIEvent(AUMIDIEvent const& midiEvent);
    void trackNotesForTrack(int track, const RecordedMidiMessage* message);
    void turnOffAllNotes();
    void turnOffAllNotesForTrack(int track);
    
    bool _bypassed          { false };
    bool _isPlaying         { false };
    
    bool _noteStates[MIDI_TRACKS][16][128];
    uint32_t _noteCounts[MIDI_TRACKS];

    AudioBufferList* _inBufferList  { nullptr };
    AudioBufferList* _outBufferList { nullptr };
};
