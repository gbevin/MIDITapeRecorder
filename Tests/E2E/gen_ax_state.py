# turns the cached button paths (ax_paths.txt) into a one-shot state reader (ax_state.applescript)
import sys
src, dst = sys.argv[1], sys.argv[2]
lines = [l.rstrip("\n") for l in open(src) if "|" in l]
body = ['tell application "System Events"', '  set out to {}']
for l in lines:
    d, p = l.split("|", 1)
    body += ['  try', '    set end of out to "%s:" & ((value of attribute "AXSelected" of %s) as text)' % (d, p), '  on error', '    set end of out to "%s:?"' % d, '  end try']
body += ['  set AppleScript\'s text item delimiters to " "', '  return out as text', 'end tell']
open(dst, "w").write("\n".join(body) + "\n")
