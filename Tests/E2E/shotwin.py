# screenshot of the app window (needs the Screen Recording grant): python3 shotwin.py out.png
import subprocess, sys
out = subprocess.run(["osascript","-e",'tell application "System Events" to tell process "MIDI Tape Recorder" to get {position, size} of window 1'], capture_output=True).stdout.decode().strip()
x, y, w, h = [int(v) for v in out.replace(",", " ").split()]
subprocess.run(["screencapture", "-x", "-R", "%d,%d,%d,%d" % (x, y, w, h), sys.argv[1]])
subprocess.run(["sips", "-Z", "1000", sys.argv[1]], capture_output=True)
