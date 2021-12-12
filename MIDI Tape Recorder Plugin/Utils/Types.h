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

typedef std::vector<RecordedMidiMessage> RecordedDataVector;
typedef std::unique_ptr<RecordedDataVector> RecordedData;

typedef std::vector<int> RecordedBookmarksVector;
typedef std::unique_ptr<RecordedBookmarksVector> RecordedBookmarks;

typedef std::vector<PreviewPixelData> RecordedPreviewVector;
typedef std::shared_ptr<RecordedPreviewVector> RecordedPreview;
