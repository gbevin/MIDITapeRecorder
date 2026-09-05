on walkTree(theEl, thePath, theDepth, theAcc)
  if theDepth > 12 then return theAcc
  set kids to {}
  try
    tell application "System Events" to set kids to UI elements of theEl
  end try
  set i to 0
  repeat with k in kids
    set i to i + 1
    set r to ""
    try
      tell application "System Events" to set r to role of k
    end try
    if r is "AXButton" then
      set d to ""
      try
        tell application "System Events" to set d to description of k
      end try
      if d is in {"play", "record circle", "repeat", "record enable", "input monitor", "mute"} then
        set end of theAcc to d & "|" & "UI element " & i & " of " & thePath
      end if
    else if r is "AXGroup" or r is "AXScrollArea" or r is "AXUnknown" or r is "AXToolbar" then
      set theAcc to my walkTree(k, "UI element " & i & " of " & thePath, theDepth + 1, theAcc)
    end if
    if (count of theAcc) >= 15 then return theAcc
  end repeat
  return theAcc
end walkTree
tell application "System Events" to set w to window 1 of process "MIDI Tape Recorder"
set acc to my walkTree(w, "window 1 of process \"MIDI Tape Recorder\"", 0, {})
set AppleScript's text item delimiters to linefeed
return acc as text
