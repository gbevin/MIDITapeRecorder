# in-window arming trials with absolute timing: the record toggle is scheduled for a wall-clock
# instant T on the host run loop (NSTimer fire date, so lldb's detach time doesn't matter) and the
# burst is spawned at T + gap - spawn latency; tracks 1+2 armed, separate inputs (4>4)
# usage: python3 arming_window.py [name:gap_seconds ...]   e.g. w1:-0.04 w2:0.0 w3:0.02 w4:0.04 w5:0.06
# expected on a correct build: every gap from 0 s up records all 3 bursts on both tracks
import sys, time, subprocess; from hostlib import *; from hostlib import _lldb
SPAWN = float(os.environ.get("MTR_E2E_SPAWN_LATENCY", "0.09"))
specs = sys.argv[1:] or ["w1:-0.04","w2:-0.02","w3:0.0","w4:0.01","w5:0.02","w6:0.03","w7:0.04","w8:0.05","w9:0.06","w10:0.08"]
routing(1)
def schedule_toggle_at(ident, T):
    cf = T - 978307200.0
    _lldb(['expr -l objc++ -- (void)[$host performSelector:@selector(toggleParameterWithIdentifier:) withObject:@"%s" afterDelay:(%.6f - (double)CFAbsoluteTimeGetCurrent())]; 1' % (ident, cf)])
for spec in specs:
    name, gap = spec.split(":"); gap = float(gap)
    clear_all(); want(play=0, record=0, repeat=0, record1=1, record2=1, record3=0, record4=0)
    T = time.time() + 5.5                      # lldb attach/detach takes ~3 s; the timer's fire date is absolute
    schedule_toggle_at("record", T); margin = T - time.time()
    t_send = T + gap - SPAWN
    while time.time() < t_send: time.sleep(0.0005)
    t0 = time.time()
    subprocess.run(["sendmidi","dev","Drive1","ch","1"] + B1); subprocess.run(["sendmidi","dev","Drive2","ch","2"] + B2)
    for r in range(2):
        time.sleep(0.3); subprocess.run(["sendmidi","dev","Drive1","ch","1"] + B1); subprocess.run(["sendmidi","dev","Drive2","ch","2"] + B2)
    time.sleep(1.2); mid = state(); toggle("record"); time.sleep(1.5); after = state()
    cap = Capture("v4" + name); trigger("rewind"); setp([("play", 1.0)]); time.sleep(3.5); setp([("play", 0.0)]); ev = cap.stop(); c = counts(ev)
    t1, t2 = c.get(1, 0), c.get(2, 0)
    verdict = {(24, 24): "all 3 bursts", (16, 16): "first burst NOT recorded", (0, 0): "nothing recorded"}.get((t1, t2), "MIXED")
    print("trial %s: burst spawned %+.0f ms around the record toggle (spawn latency %.0f ms, lldb done %.2f s before T) | take play=%d record=%d | after off play=%d record=%d | track1=%d track2=%d -> %s" % (
        name, (t0 + SPAWN - T) * 1000, SPAWN * 1000, margin, mid["play"], mid["record"], after["play"], after["record"], t1, t2, verdict), flush=True)
print("DONE")
