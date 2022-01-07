//
//  MidiRecorderKernel.cpp
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorderKernel.h"

#include "Constants.h"
#include "Logging.h"
#include "NoteTracker.h"
#include "QueuedMidiMessage.h"

#define DEBUG_MIDI_INPUT 0
#define DEBUG_MIDI_OUTPUT 0

MidiRecorderKernel::MidiRecorderKernel() : _state() {
    TPCircularBufferInit(&_state.midiBuffer, 16384);
}

void MidiRecorderKernel::cleanup() {
    TPCircularBufferCleanup(&_state.midiBuffer);
    _ioState.reset();
}

bool MidiRecorderKernel::isBypassed() {
    return _bypassed;
}

void MidiRecorderKernel::setBypass(bool shouldBypass) {
    _bypassed = shouldBypass;
}

void MidiRecorderKernel::rewind(double timeSampleSeconds) {
    // turn off recording
    _state.processedUIEndRecord.clear();

    // rewind to start position or complete beginning
    double start_position = _state.startPositionBeats;
    if (_state.playPositionBeats > start_position) {
        _state.playPositionBeats = start_position;
    }
    else {
        _state.playPositionBeats = 0.0;
    }
    
    if (_isPlaying) {
        _state.transportStartSampleSeconds = timeSampleSeconds - _state.playPositionBeats * _state.beatsToSeconds;
    }
    else {
        _state.processedUIRewind.clear();
        _state.transportStartSampleSeconds = 0.0;
    }

    // ensure there are no lingering notes
    turnOffAllNotes();
}

void MidiRecorderKernel::sendRpnMessage(uint8_t cable, uint8_t channel, uint16_t number, uint16_t value) {
    if (cable >= MIDI_TRACKS || channel > 0xf) {
        return;
    }
    
    if (_ioState.midiOutputEventBlock) {
        unsigned number_msb = (number & 0x3fff) >> 7;
        unsigned number_lsb = number & 0x7f;
        unsigned value_msb = (value & 0x3fff) >> 7;
        unsigned value_lsb = value & 0x7f;

        uint8_t data[3] = { 0, 0, 0 };
        data[0] = 0xb0 | channel;
        
        Float64 time = _ioState.timestamp->mSampleTime;
        data[1] = 0x65; data[2] = number_msb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x64; data[2] = number_lsb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x06; data[2] = value_msb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x26; data[2] = value_lsb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x65; data[2] = 0x7f;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x64; data[2] = 0x7f;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
    }
}

void MidiRecorderKernel::sendMCM(int t) {
    MPEState& mpe_state = _state.track[t].mpeState;
    if (!mpe_state.enabled) {
        return;
    }
    
    _state.track[t].processedActivityOutput.clear();

    if (mpe_state.zone1Active) {
        sendRpnMessage(t, 0, 0x6, mpe_state.zone1Members.load() << 7);
        sendRpnMessage(t, 0, 0x0, (int)mpe_state.zone1ManagerPitchSens.load() << 7);
        for (int i = 0; i < mpe_state.zone1Members.load(); ++i) {
            sendRpnMessage(t, 0x1 + i, 0x0, (int)mpe_state.zone1MemberPitchSens.load() << 7);
        }
    }
    if (mpe_state.zone2Active) {
        sendRpnMessage(t, 0xf, 0x6, mpe_state.zone2Members.load() << 7);
        sendRpnMessage(t, 0xf, 0x0, (int)mpe_state.zone2ManagerPitchSens.load() << 7);
        for (int i = 0; i < mpe_state.zone2Members.load(); ++i) {
            sendRpnMessage(t, 0xe - i, 0x0, (int)mpe_state.zone2MemberPitchSens.load() << 7);
        }
    }
}

void MidiRecorderKernel::play() {
    if (_isPlaying == NO) {
        _state.processedStopAndRewind.test_and_set();
        _state.processedUIStopAndRewind.test_and_set();

        // send out MPE configuration messages based on each track's MPE mode
        if (_state.sendMpeConfigOnPlay.test()) {
            for (int t = 0; t < MIDI_TRACKS; ++t) {
                if (!_state.track[t].recording.test()) {
                    sendMCM(t);
                }
            }
        }

        _isPlaying = YES;
    }
}

void MidiRecorderKernel::stop() {
    _state.transportStartSampleSeconds = 0.0;
    _isPlaying = NO;
}

void MidiRecorderKernel::endRecording(int track) {
    MidiTrackState& track_state = _state.track[track];
    
    track_state.recording.clear();
    
    // if this is a direct recording, just move all the data over
    if (!track_state.recordedData || track_state.recordedData->empty()) {
        track_state.recordedData = std::move(track_state.pendingRecordedData);
        track_state.recordedPreview = std::move(track_state.pendingRecordedPreview);

        // we auto-trim new recordings when this is an active preference
        if (_state.autoTrimRecordings.test() && track_state.recordedData) {
            track_state.recordedData->trimDuration();
        }
    }
    // if this is an overdub, replace the new sections
    else {
        // ensure that the recorded preview has the same length as the pending preview
        // anyting that's longer can just be moved over
        RecordedPreviewVector& pending_pixels = track_state.pendingRecordedPreview->getPixels();
        RecordedPreviewVector& recorded_pixels = track_state.recordedPreview->getPixels();

        for (unsigned long p = recorded_pixels.size(); p < pending_pixels.size(); ++p) {
            recorded_pixels.push_back(pending_pixels[p]);
        }
        
        RecordedBeatVector& pending_beats = track_state.pendingRecordedData->getBeats();
        RecordedBeatVector& recorded_beats = track_state.recordedData->getBeats();

        // process the individual beats of the pending recording
        double start = track_state.pendingRecordedData->getStart();
        double stop = track_state.pendingRecordedData->getDuration();
        int start_beat = (int)start;
        int stop_beat = MIN((int)stop, (int)pending_beats.size() - 1);
        
        // track the erased note changes during the overdub recording
        NoteTracker erased_state;
        for (int beat = start_beat; beat <= stop_beat && beat < recorded_beats.size(); ++beat) {
            RecordedDataVector& data = recorded_beats[beat];
            for (RecordedMidiMessage& message : data) {
                if (message.offsetBeats < start || message.offsetBeats > stop) {
                    continue;
                }
                
                erased_state.trackNotesForMessage(message);
            }
        }
        std::vector<NoteOnMessage> note_ons = erased_state.allNoteOnMessages();
        std::vector<NoteOffMessage> note_offs = erased_state.allNoteOffMessages();

        // process the beats that were affected by the overdub
        for (int beat = start_beat; beat <= stop_beat && beat < pending_beats.size(); ++beat) {
            RecordedDataVector& pending_data = pending_beats[beat];

            int start_pixel = MAX(beat * PIXELS_PER_BEAT, start * PIXELS_PER_BEAT);
            int stop_pixel = MIN(MIN(start_pixel + PIXELS_PER_BEAT, stop * PIXELS_PER_BEAT), (int)pending_pixels.size());

            // if the beat is longer than the original recording, simply move all the data over
            // the preview pixels have already been moved over
            if (beat >= recorded_beats.size()) {
                recorded_beats.push_back(std::move(pending_beats[beat]));
            }
            else {
                // copy the relevant preview pixels
                for (int p = start_pixel; p < stop_pixel; ++p) {
                    recorded_pixels[p] = pending_pixels[p];
                }
                
                // if the beat is not either of the extremeties of the overdub
                if (beat != start_beat && beat != stop_beat) {
                    // move all the data
                    recorded_beats[beat] = std::move(pending_beats[beat]);
                }
                // start beat of the overdub
                else if (beat == start_beat) {
                    RecordedDataVector& recorded_data = recorded_beats[beat];

                    // trim the messages at the end of the beat to not overlap with the overdub
                    while (!recorded_data.empty() && recorded_data.back().offsetBeats >= start) {
                        recorded_data.pop_back();
                    }
                    
                    // add the potential note offs that have been erased through the overdub to prevent hanging notes
                    if (note_offs.size() > 0) {
                        for (NoteOffMessage& note_off : note_offs) {
                            RecordedMidiMessage message;
                            message.offsetBeats = start;
                            message.length = 3;
                            memcpy(&message.data[0], &note_off.data[0], 3);
                            recorded_data.push_back(message);
                        }
                    }
                    
                    // add the internal start overdub message
                    recorded_data.push_back(RecordedMidiMessage::makeOverdubStartMessage(start));

                    // add the overdub events
                    auto it = pending_data.begin();
                    while (it != pending_data.end()) {
                        recorded_data.push_back(std::move(*it));
                        it++;
                    }
                }
                // stop beat of the overdub
                else if (beat == stop_beat) {
                    RecordedDataVector& recorded_data = recorded_beats[beat];

                    // trim the messages at the start of the beat to not overlap with the overdub
                    while (!recorded_data.empty() && recorded_data.front().offsetBeats <= stop) {
                        recorded_data.erase(recorded_data.begin());
                    }
                
                    // add the overdub events
                    auto it = pending_data.rbegin();
                    while (it != pending_data.rend()) {
                        recorded_data.insert(recorded_data.begin(), std::move(*it));
                        it++;
                    }
                    
                    // turn off all overdub notes that are still lingering
                    if (_noteStates[track].hasLingeringNotes()) {
                        std::vector<NoteOffMessage> messages = _noteStates[track].turnOffAllNotesAndGenerateMessages();
                        if (!messages.empty() && _ioState.midiOutputEventBlock) {
                            for (NoteOffMessage& note_off : messages) {
                                RecordedMidiMessage message;
                                message.offsetBeats = stop;
                                message.length = 3;
                                memcpy(&message.data[0], &note_off.data[0], 3);
                                recorded_data.push_back(message);
                            }
                        }
                    }
                    
                    // add the internal stop overdub message
                    recorded_data.push_back(RecordedMidiMessage::makeOverdubStopMessage(stop));

                    // add the potential note ons that have been erased through the overdub
                    if (note_ons.size() > 0) {
                        for (NoteOnMessage& note_on : note_ons) {
                            RecordedMidiMessage message;
                            message.offsetBeats = stop;
                            message.length = 3;
                            memcpy(&message.data[0], &note_on.data[0], 3);
                            recorded_data.push_back(message);
                        }
                    }
                }
            }
        }
        
        // update the other state values
        track_state.recordedPreview->applyOverdubInfo(*track_state.pendingRecordedPreview);
        track_state.recordedData->applyOverdubInfo(*track_state.pendingRecordedData);
    }
}

void MidiRecorderKernel::setParameter(AUParameterAddress address, AUValue value) {
    bool set = bool(value);
    switch (address) {
        case ID_RECORD_1:
            if (set) _state.track[0].recordEnabled.test_and_set();
            else     _state.track[0].recordEnabled.clear();
            break;
        case ID_RECORD_2:
            if (set) _state.track[1].recordEnabled.test_and_set();
            else     _state.track[1].recordEnabled.clear();
            break;
        case ID_RECORD_3:
            if (set) _state.track[2].recordEnabled.test_and_set();
            else     _state.track[2].recordEnabled.clear();
            break;
        case ID_RECORD_4:
            if (set) _state.track[3].recordEnabled.test_and_set();
            else     _state.track[3].recordEnabled.clear();
            break;
        case ID_MONITOR_1:
            if (set) _state.track[0].monitorEnabled.test_and_set();
            else     _state.track[0].monitorEnabled.clear();
            break;
        case ID_MONITOR_2:
            if (set) _state.track[1].monitorEnabled.test_and_set();
            else     _state.track[1].monitorEnabled.clear();
            break;
        case ID_MONITOR_3:
            if (set) _state.track[2].monitorEnabled.test_and_set();
            else     _state.track[2].monitorEnabled.clear();
            break;
        case ID_MONITOR_4:
            if (set) _state.track[3].monitorEnabled.test_and_set();
            else     _state.track[3].monitorEnabled.clear();
            break;
        case ID_MUTE_1:
            if (set) _state.track[0].muteEnabled.test_and_set();
            else     _state.track[0].muteEnabled.clear();
            break;
        case ID_MUTE_2:
            if (set) _state.track[1].muteEnabled.test_and_set();
            else     _state.track[1].muteEnabled.clear();
            break;
        case ID_MUTE_3:
            if (set) _state.track[2].muteEnabled.test_and_set();
            else     _state.track[2].muteEnabled.clear();
            break;
        case ID_MUTE_4:
            if (set) _state.track[3].muteEnabled.test_and_set();
            else     _state.track[3].muteEnabled.clear();
            break;
        case ID_REWIND:
            if (set) _state.rewindTrigger.test_and_set();
            else     _state.rewindTrigger.clear();
            break;
        case ID_PLAY:
            if (set) _state.playActive.test_and_set();
            else     _state.playActive.clear();
            break;
        case ID_RECORD:
            if (set) _state.recordArmed.test_and_set();
            else     _state.recordArmed.clear();
            break;
        case ID_REPEAT:
            if (set) _state.repeatEnabled.test_and_set();
            else     _state.repeatEnabled.clear();
            break;
        case ID_GRID:
            if (set) _state.grid.test_and_set();
            else     _state.grid.clear();
            break;
        case ID_CHASE:
            if (set) _state.chase.test_and_set();
            else     _state.chase.clear();
            break;
        case ID_PUNCH_INOUT:
            if (set) _state.punchInOut.test_and_set();
            else     _state.punchInOut.clear();
            break;
        case ID_CLEAR_ALL:
            if (set) _state.clearAllTrigger.test_and_set();
            else     _state.clearAllTrigger.clear();
            break;
        case ID_CLEAR_1:
            if (set) _state.track[0].clearTrigger.test_and_set();
            else     _state.track[0].clearTrigger.clear();
            break;
        case ID_CLEAR_2:
            if (set) _state.track[1].clearTrigger.test_and_set();
            else     _state.track[1].clearTrigger.clear();
            break;
        case ID_CLEAR_3:
            if (set) _state.track[2].clearTrigger.test_and_set();
            else     _state.track[2].clearTrigger.clear();
            break;
        case ID_CLEAR_4:
            if (set) _state.track[3].clearTrigger.test_and_set();
            else     _state.track[3].clearTrigger.clear();
            break;
    }
}

AUValue MidiRecorderKernel::getParameter(AUParameterAddress address) {
    // Return the goal. It is not thread safe to return the ramping value.
    switch (address) {
        case ID_RECORD_1:
            return _state.track[0].recordEnabled.test();
        case ID_RECORD_2:
            return _state.track[1].recordEnabled.test();
        case ID_RECORD_3:
            return _state.track[2].recordEnabled.test();
        case ID_RECORD_4:
            return _state.track[3].recordEnabled.test();
        case ID_MONITOR_1:
            return _state.track[0].monitorEnabled.test();
        case ID_MONITOR_2:
            return _state.track[1].monitorEnabled.test();
        case ID_MONITOR_3:
            return _state.track[2].monitorEnabled.test();
        case ID_MONITOR_4:
            return _state.track[3].monitorEnabled.test();
        case ID_MUTE_1:
            return _state.track[0].muteEnabled.test();
        case ID_MUTE_2:
            return _state.track[1].muteEnabled.test();
        case ID_MUTE_3:
            return _state.track[2].muteEnabled.test();
        case ID_MUTE_4:
            return _state.track[3].muteEnabled.test();
        case ID_REWIND:
            return _state.rewindTrigger.test();
        case ID_PLAY:
            return _state.playActive.test();
        case ID_RECORD:
            return _state.recordArmed.test();
        case ID_REPEAT:
            return _state.repeatEnabled.test();
        case ID_GRID:
            return _state.grid.test();
        case ID_CHASE:
            return _state.chase.test();
        case ID_PUNCH_INOUT:
            return _state.punchInOut.test();
        case ID_CLEAR_ALL:
            return _state.clearAllTrigger.test();
        case ID_CLEAR_1:
            return _state.track[0].clearTrigger.test();
        case ID_CLEAR_2:
            return _state.track[1].clearTrigger.test();
        case ID_CLEAR_3:
            return _state.track[2].clearTrigger.test();
        case ID_CLEAR_4:
            return _state.track[3].clearTrigger.test();
        default:
            return 0.f;
    }
}

void MidiRecorderKernel::handleBufferStart(double timeSampleSeconds) {
    QueuedMidiMessage message;
    message.timeSampleSeconds = timeSampleSeconds;
    if (_state.followHostTransport.test() && _ioState.transportMoving.test()) {
        message.offsetBeats = _ioState.currentBeatPosition;
        message.hasBeatTime = true;
    }
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
}

void MidiRecorderKernel::handleScheduledTransitions(double timeSampleSeconds) {
    // we rely on the single-threaded nature of the audio callback thread to coordinate
    // important state transitions at the beginning of the callback, before anything else
    // this prevents split-state conditions to change semantics in the middle of processing

    // host transport sync
    bool transport_changed = !_ioState.transportChangeProcessed.test_and_set();
    if (_ioState.transportMoving.test()) {
        // transport starting while record is armed or
        // record arming while host transport is already moving
        if (transport_changed || !_state.processedRecordArmed.test_and_set()) {
            _state.processedUIStop.test_and_set();
            _state.processedStop.test_and_set();
            
            if (_state.recordArmed.test()) {
                for (int t = 0; t < MIDI_TRACKS; ++t) {
                    if (_state.track[t].recordEnabled.test()) {
                        _state.processedBeginRecording[t].clear();
                    }
                }
            }
            
            _state.processedPlay.clear();
            _state.processedUIPlay.clear();
        }
    }
    // stop transport when host stopped moving
    else if (transport_changed) {
        _state.processedStop.clear();
        _state.processedUIStop.clear();
    }

    // crop all
    if (!_state.processedCropAll.test_and_set()) {
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            MidiTrackState& track_state = _state.track[t];
            track_state.recording.clear();
            track_state.recordedData = std::move(track_state.pendingRecordedData);
            track_state.recordedPreview = std::move(track_state.pendingRecordedPreview);
        }
        
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            _state.processedUIRebuildPreview[t].clear();
        }
    }

    // individual track states
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        MidiTrackState& track_state = _state.track[t];
        
        // begin recording
        if (!_state.processedBeginRecording[t].test_and_set()) {
            turnOffAllNotesForTrack(t);
            track_state.recording.test_and_set();
        }

        // end recording
        if (!_state.processedEndRecording[t].test_and_set()) {
            endRecording(t);
            _state.processedUIRebuildPreview[t].clear();
        }

        // import
        if (!_state.processedImport[t].test_and_set()) {
            turnOffAllNotesForTrack(t);
        }

        // ensure notes off
        if (!_state.processedNotesOff[t].test_and_set()) {
            turnOffAllNotesForTrack(t);
        }
        
        // invalidate
        if (!_state.processedInvalidate[t].test_and_set()) {
            track_state.recordedData.reset();
            track_state.recordedPreview.reset();
            _state.processedUIRebuildPreview[t].clear();
        }

        // send MCM
        if (!_state.processedSendMCM[t].test_and_set()) {
            sendMCM(t);
        }
    }
    
    // repeat
    if (!_state.processedActivateRepeat.test_and_set()) {
        _state.repeatActive.test_and_set();
    }
    if (!_state.processedDeactivateRepeat.test_and_set()) {
        _state.repeatActive.clear();
    }

    // rewind
    if (!_state.processedRewind.test_and_set()) {
        rewind(timeSampleSeconds);
    }

    // play
    if (!_state.processedPlay.test_and_set()) {
        _state.transportStartSampleSeconds = timeSampleSeconds - _state.playPositionBeats * _state.beatsToSeconds;
        play();
    }

    // stop
    if (!_state.processedStop.test_and_set()) {
        stop();
    }

    // stop and rewind
    if (!_state.processedStopAndRewind.test_and_set()) {
        stop();
        rewind(timeSampleSeconds);
    }

    // reach end
    if (!_state.processedReachEnd.test_and_set()) {
        _isPlaying = NO;
        _state.processedUIStopAndRewind.clear();
    }
}

void MidiRecorderKernel::handleParameterEvent(AUParameterEvent const& parameterEvent) {
    // we only have parameter state switches, so we don't need to ramp and it's all related to
    // user interface funtionality, so being sample accurate is not critical either
    setParameter(parameterEvent.parameterAddress, parameterEvent.value);
}

void MidiRecorderKernel::handleMIDIEvent(AUMIDIEvent const& midiEvent) {
    if (midiEvent.cable < 0 || midiEvent.cable >= MIDI_TRACKS) {
        return;
    }

    if (isBypassed()) {
        // pass through MIDI events
        if (_ioState.midiOutputEventBlock) {
            passThroughMIDIEvent(midiEvent, midiEvent.cable);
        }
    }
    else {
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            MidiTrackState& track_state = _state.track[t];
            
            if (track_state.monitorEnabled.test() && !track_state.muteEnabled.test() && track_state.sourceCable == midiEvent.cable) {
                _state.track[t].processedActivityOutput.clear();
                passThroughMIDIEvent(midiEvent, t);
            }
        }
        
        // only queue channel voice messages
        if ((midiEvent.data[0] & 0xf0) != 0xf0) {
            queueMIDIEvent(midiEvent);
        }
    }
}

void MidiRecorderKernel::processOutput() {
    // determine if we're recording and/or playing
    bool recording_tracks = false;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        MidiTrackState& track_state = _state.track[t];
        if (track_state.recording.test() &&
            (!_state.punchInOut.test() || _state.activePunchInOut())) {
            recording_tracks = true;
        }
    }

    // get a consistent repeat active state
    bool repeat_active = _state.repeatActive.test();
    
    // if the host transport is moving or the position changed, make that take precedence
    double play_position = _state.playPositionBeats;
    bool play_position_changed = false;
    if (_ioState.transportMoving.test() || !_ioState.transportPositionProcessed.test_and_set()) {
        if (repeat_active) {
            double effective_max_duration = _state.stopPositionBeats - _state.startPositionBeats;
            play_position = fmod(_ioState.currentBeatPosition, effective_max_duration);
        }
        else {
            play_position = _ioState.currentBeatPosition;
        }
        play_position += _state.startPositionBeats;
        play_position_changed = true;
    }
    
    if (!_isPlaying) {
        // we update the play position if the host changed it
        if (play_position_changed) {
            _state.playPositionBeats = play_position;
        }
        
        // make sure we have no lingering notes
        turnOffAllNotes();
    }
    else {
        // determine the beat position of the playhead
        const double frames_seconds = double(_ioState.frameCount) / _ioState.sampleRate;
        const double frames_beats = frames_seconds * _state.secondsToBeats;

        // calculate the range of beat positions between which the recorded messages
        // should be played
        double beatrange_begin = play_position;
        double beatrange_end = beatrange_begin + frames_beats;

        // if there's a significant discontinuity between the output processing calls,
        // forcible ensure that all notes are turned off
        if (ABS(play_position - _state.playPositionBeats) >= frames_beats) {
            turnOffAllNotes();
        }

        // store the play position for the next process call
        _state.playPositionBeats = beatrange_end;
        
        // detect whether we wrap around in this buffer
        double beatrange_wraparound = 0.0;
        if (repeat_active) {
            if (beatrange_end > _state.stopPositionBeats) {
                beatrange_wraparound = beatrange_end - _state.stopPositionBeats;
                beatrange_end = _state.stopPositionBeats;
            }
        }

        // output the MIDI messages
        outputMidiMessages(beatrange_begin, beatrange_end);

        // handle repeat
        if (repeat_active) {
            // check if we've reached the stop position and set up the repeat
            if (beatrange_end == _state.stopPositionBeats) {
                // ensure there are no lingering notes
                turnOffAllNotes();
                
                // check whether any events were recorded during this cycle and end recording if there were
                bool end_recording = false;
                for (int t = 0; t < MIDI_TRACKS; ++t) {
                    if (_state.track[t].hasRecordedEvents.test()) {
                        end_recording = true;
                        break;
                    }
                }
                
                // start over from the start position for the next process call
                _state.playPositionBeats = _state.startPositionBeats.load();
                _state.transportStartSampleSeconds = _state.transportStartSampleSeconds + (_state.stopPositionBeats - _state.startPositionBeats) * _state.beatsToSeconds;

                // check if we should finish the recording or reset it since no events were recorded
                if (end_recording) {
                    _state.processedUIEndRecord.clear();
                    recording_tracks = false;
                }
                else {
                    for (int t = 0; t < MIDI_TRACKS; ++t) {
                        _state.processedResetRecording[t].clear();
                        _state.processedUIRebuildPreview[t].clear();
                    }
                }
            }

            // handle the possible in-buffer wrap around
            if (beatrange_wraparound > 0.0) {
                beatrange_begin = _state.startPositionBeats;
                beatrange_end = beatrange_begin + beatrange_wraparound;
                
                // output MIDI messages for the wrap-around section
                outputMidiMessages(beatrange_begin, beatrange_end);

                // store the advanced play position for the next process call
                _state.playPositionBeats = beatrange_end;
            }
        }
        // if we're playing at least one track and reached the stop position, end playing
        else if (!recording_tracks && beatrange_end >= _state.stopPositionBeats) {
            _state.processedReachEnd.clear();
        }
    }
}

void MidiRecorderKernel::passThroughMIDIEvent(AUMIDIEvent const& midiEvent, int cable) {
    if (_ioState.midiOutputEventBlock) {
        Float64 frame_offset = midiEvent.eventSampleTime - _ioState.timestamp->mSampleTime;
        _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + frame_offset, cable, midiEvent.length, midiEvent.data);
    }
}

void MidiRecorderKernel::outputMidiMessages(double beatRangeBegin, double beatRangeEnd) {
    // process all the messages on all the tracks
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        MidiTrackState& track_state = _state.track[t];
        
        // play when there are recorded messages and the track is not recording, or it's recording and outside the punch in/out range
        if (track_state.recordedData && !track_state.recordedData->empty() &&
            (!track_state.recording.test() || _state.inactivePunchInOut())) {
            // iterate over all the beats inside this processing range
            for (int beat = (int)beatRangeBegin; beat <= (int)beatRangeEnd; ++beat) {
                // if the beat falls outside of the range of recorded messages, we're done
                if (beat >= track_state.recordedData->beatCount()) {
                    break;
                }
            
                // process through the messages until we find the ones that should be played
                for (const RecordedMidiMessage& message : track_state.recordedData->beatData(beat)) {
                    // check if the message is outdated
                    if (message.offsetBeats < beatRangeBegin) {
                        continue;
                    }
                    // check if the time offset of the message falls within the advancement of the playhead
                    else if (message.offsetBeats < beatRangeEnd) {
                        // if the track is not muted and a MIDI output block exists,
                        // send the message
                        if (!track_state.muteEnabled.test() && _ioState.midiOutputEventBlock) {
                            const double offset_seconds = (message.offsetBeats - beatRangeEnd) * _state.beatsToSeconds;
                            const double offset_samples = offset_seconds * _ioState.sampleRate;
                            
                            // handle internal messages
                            if (message.type == INTERNAL) {
                                if (message.isOverdubStart() || message.isOverdubStop()) {
                                    turnOffAllNotesForTrack(t);
                                }
                            }
                            // handle regular MIDI messages
                            else if (message.type == MIDI_1_0) {
                                // indicate output activity
                                track_state.processedActivityOutput.clear();
                                
                                // track note on/off states
                                _noteStates[t].trackNotesForMessage(message);

#if DEBUG_MIDI_OUTPUT
                                logRecordedMidiMessage(t, @"OUT", message);
#endif
                                // send the MIDI output message
                                _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + offset_samples,
                                                              t, message.length, &message.data[0]);
                            }
                        }
                        // if the track is muted, ensure we have no lingering note on messages
                        else {
                            turnOffAllNotesForTrack(t);
                        }
                    }
                    // stop playing recorded messages if the one we processed is scheduled for later
                    else {
                        break;
                    }
                }
            }
        }
    }
}

void MidiRecorderKernel::turnOffAllNotes() {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        turnOffAllNotesForTrack(t);
    }
}

void MidiRecorderKernel::turnOffAllNotesForTrack(int track) {
    if (track < 0 || track >= MIDI_TRACKS) {
        return;
    }
    
    if (!_noteStates[track].hasLingeringNotes()) {
        return;
    }
    
    std::vector<NoteOffMessage> messages = _noteStates[track].turnOffAllNotesAndGenerateMessages();
    if (!messages.empty() && _ioState.midiOutputEventBlock) {
        for (NoteOffMessage& message : messages) {
#if DEBUG_MIDI_OUTPUT
            uint8_t status = message.data[0] & 0xf0;
            uint8_t channel = message.data[0] & 0x0f;
            uint8_t data1 = message.data[1];
            uint8_t data2 = message.data[2];
            
            NSLog(@"OUT %2s [%3s %3s %3s]",
                  [NSString stringWithFormat:@"%d", channel].UTF8String,
                  [NSString stringWithFormat:@"%d", status].UTF8String,
                  [NSString stringWithFormat:@"%d", data1].UTF8String,
                  [NSString stringWithFormat:@"%d", data2].UTF8String);
#endif
            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + _ioState.frameCount,
                                          track, 3, &message.data[0]);
        }
    }
}

void MidiRecorderKernel::queueMIDIEvent(AUMIDIEvent const& midiEvent) {
    QueuedMidiMessage message;
    message.timeSampleSeconds = double(midiEvent.eventSampleTime) / _ioState.sampleRate;
    if (_state.followHostTransport.test() && _ioState.transportMoving.test()) {
        double offset_seconds = double(midiEvent.eventSampleTime - _ioState.timestamp->mSampleTime) / _ioState.sampleRate;
        message.offsetBeats = _ioState.currentBeatPosition + offset_seconds * _state.secondsToBeats;
        message.hasBeatTime = true;
    }
    message.cable = midiEvent.cable;
    message.length = midiEvent.length;
    message.data[0] = midiEvent.data[0];
    message.data[1] = midiEvent.data[1];
    message.data[2] = midiEvent.data[2];
    
#if DEBUG_MIDI_INPUT
    logQueuedMidiMessage(@"IN ", message);
#endif

    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
}
