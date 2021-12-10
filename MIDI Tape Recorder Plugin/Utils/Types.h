//
//  Types.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/10/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <memory>
#include <vector>

#include "PreviewPixelData.h"
#include "RecordedMidiMessage.h"

struct PreviewPixelData;

typedef std::unique_ptr<std::vector<RecordedMidiMessage>> RecordedData;
typedef std::unique_ptr<std::vector<int>> RecordedBookmarks;
typedef std::shared_ptr<std::vector<PreviewPixelData>> RecordedPreview;
