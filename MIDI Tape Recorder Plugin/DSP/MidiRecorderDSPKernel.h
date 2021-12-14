//
//  MidiRecorderDSPKernel.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#import "AudioUnitIOState.h"
#import "DSPKernel.h"
#import "MidiRecorderState.h"

class MidiRecorderDSPKernel : public DSPKernel {
public:
    MidiRecorderDSPKernel();
    
    void cleanup();

    bool isBypassed();
    void setBypass(bool shouldBypass);
    
    void setParameter(AUParameterAddress address, AUValue value);
    AUValue getParameter(AUParameterAddress address);

    void handleBufferStart(double timeSampleSeconds) override;
    void handleScheduledTransitions(double timeSampleSeconds) override;
    void handleParameterEvent(AUParameterEvent const& parameterEvent) override;
    void handleMIDIEvent(AUMIDIEvent const& midiEvent) override;
    void processOutput() override;

    MidiRecorderState _state;
    AudioUnitIOState _ioState;

private:
    void sendRpnMessage(uint8_t cable, uint8_t channel, uint16_t number, uint16_t value);
    void sendMCM(int track);

    void rewind(double timeSampleSeconds);
    void play();
    void stop();

    void passThroughMIDIEvent(AUMIDIEvent const& midiEvent, int cable);
    void queueMIDIEvent(AUMIDIEvent const& midiEvent);
    void trackNotesForTrack(int track, const RecordedMidiMessage& message);
    void turnOffAllNotes();
    void turnOffAllNotesForTrack(int track);
    void outputMidiMessages(double beatRrangeBegin, double beatRangeEnd);

    bool _bypassed          { false };
    bool _isPlaying         { false };
    
    bool _noteStates[MIDI_TRACKS][16][128];
    uint32_t _noteCounts[MIDI_TRACKS];
};
