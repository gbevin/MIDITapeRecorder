# drive and read the standalone host through lldb on the host process only (never the appex):
# toggles/triggers/sets are scheduled on the host run loop and fire after lldb detaches
import subprocess, time, re, os, signal
HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get("MTR_E2E_WORK", os.path.join(HERE, ".work"))
os.makedirs(WORK, exist_ok=True); os.chdir(WORK)
HOST = subprocess.check_output(["pgrep","-f","Debug-maccatalyst/MIDI Tape Recorder.app/Contents/MacOS/MIDI Tape Recorder$"]).decode().split()[0]
VC = open(os.path.join(WORK, "host_vc_addr.txt")).read().strip()
IDS = ["play","record","repeat","record1","record2","record3","record4","monitor1","monitor2","monitor3","monitor4","mute1","mute2","mute3","mute4"]
def _lldb(exprs):
    script = "\n".join(["process attach -p %s" % HOST, "script lldb.debugger.SetAsync(False)",
                        'expr -l objc++ -- id $host = (id)[(id)%s valueForKey:@"host"]; 1' % VC] + exprs + ['expr -l objc++ -- (void)CFRunLoopWakeUp((CFRunLoopRef)CFRunLoopGetMain()); 1', "detach", "quit"]) + "\n"
    out = subprocess.run(["lldb"], input=script.encode(), capture_output=True).stdout.decode()
    if "error:" in out: print("LLDB ERROR:", out[-800:])
    return out
def state():
    out = _lldb(['expr -l objc++ -- (int)[$host parameterIsOn:@"%s"]' % i for i in IDS])
    vals = re.findall(r"\(int\) \$\d+ = (\d)", out)[1:]      # the $host assignment prints the first (int)
    return dict(zip(IDS, [v == "1" for v in vals]))
def fmt(s): return " ".join("%s=%d" % (k, s[k]) for k in IDS if k in s)
def _sched(calls, delay):
    # calls: (selector, arg) pairs; each fires on the run loop `delay` s (+50 ms per item) after detach
    return ['expr -l objc++ -- (void)[$host performSelector:@selector(%s) withObject:@"%s" afterDelay:%.3f]; 1' % (sel, arg, delay + i * 0.05) for i, (sel, arg) in enumerate(calls)]
def toggle(*ids, delay=0.05): _lldb(_sched([("toggleParameterWithIdentifier:", i) for i in ids], delay))
def trigger(*ids, delay=0.05): _lldb(_sched([("triggerParameterWithIdentifier:", i) for i in ids], delay))
def clear_all(): _lldb(_sched([("clearAllTracks", "x")], 0.05)); time.sleep(1.0)
def setp(pairs, delay=0.05):
    # the live values decide which parameters need a toggle, so a repeated set is a no-op
    s = state(); ids = [k for k, v in pairs if s[k] != (v >= 0.5)]
    if ids: toggle(*ids, delay=delay); time.sleep(0.1 + 0.05 * len(ids))
def want(**kw):
    # bring named parameters to the wanted on/off state and verify
    setp([(k, 1.0 if v else 0.0) for k, v in kw.items()]); time.sleep(0.4 + 0.05*len(kw))
    s = state(); bad = {k: s[k] for k, v in kw.items() if s[k] != bool(v)}
    if bad: print("WANT MISMATCH:", bad)
    return s
class Capture:
    def __init__(self, name, port="MIDI Tape Recorder Output"):
        subprocess.run(["pkill","-f","receivemidi dev"]); time.sleep(0.3)
        self.path = "mt_%s.txt" % name; self.f = open(self.path, "w")
        self.p = subprocess.Popen(["python3",os.path.join(HERE,"ptywrap.py"),"receivemidi","dev",port,"ts","nn"], stdout=self.f, stderr=subprocess.STDOUT); time.sleep(0.8)
    def stop(self):
        time.sleep(0.5); subprocess.run(["pkill","-TERM","-f","receivemidi dev"]); time.sleep(0.7); self.f.close()
        return parse(self.path)
def parse(path):
    out = []
    for l in open(path):
        m = re.match(r"(\d+):(\d+):(\d+)\.(\d+)\s+channel\s+(\d+)\s+(\S+)\s*(.*)$", l.strip().replace("\r",""))
        if not m: continue
        h,mi,s,ms,ch,typ,rest = m.groups(); t = int(h)*3600+int(mi)*60+int(s)+int(ms)/10**len(ms)
        out.append((t, int(ch), typ, [int(x) for x in rest.split() if x.lstrip('-').isdigit()]))
    return out
def send(track, *args): subprocess.run(["sendmidi","dev","Drive%d" % track,"ch",str(track)] + [str(a) for a in args])
B1 = "on 61 100 pb 8292 cc 74 61 cp 31 pb 8342 cc 74 71 cp 41 off 61 0".split()
B2 = "on 49 90 pb 8092 cc 74 51 cp 21 pb 8042 cc 74 56 cp 26 off 49 0".split()
def counts(ev): 
    c = {}
    for e in ev: c[e[1]] = c.get(e[1], 0) + 1
    return c

UI_KEYS = ["play","record","repeat","arm1","mon1","mute1","arm2","mon2","mute2","arm3","mon3","mute3","arm4","mon4","mute4"]
def ui():
    # plugin button state through accessibility (~1 s), independent of the host cache
    out = [w for w in subprocess.run(["osascript",os.path.join(WORK,"ax_state.applescript")], capture_output=True).stdout.decode().split() if ":" in w]
    return dict(zip(UI_KEYS, [w.split(":")[-1] == "true" for w in out]))
def fmtui(u): return " ".join("%s=%d" % (k, u[k]) for k in UI_KEYS if k in u)
def click(item, menu):
    subprocess.run(["osascript","-e",'tell application "MIDI Tape Recorder" to activate',"-e",'tell application "System Events" to tell process "MIDI Tape Recorder" to click menu item "%s" of %s' % (item, menu)], capture_output=True)
TR = 'menu 1 of menu bar item "Transport" of menu bar 1'
def TRK(n): return 'menu 1 of menu item "Track %d" of menu 1 of menu bar item "Transport" of menu bar 1' % n
ROUTING = open(os.path.join(WORK, "ax_routing.txt")).read().strip()
def routing_selected():
    out = subprocess.run(["osascript","-e",'tell application "System Events" to (value of attribute "AXSelected" of %s) as text' % ROUTING], capture_output=True).stdout.decode().strip()
    return out == "true"
def routing(separate):
    # selected = separate input per track (4>4); unselected = first input to all tracks (1>4)
    if routing_selected() != bool(separate):
        subprocess.run(["osascript","-e",'tell application "MIDI Tape Recorder" to activate',"-e",'tell application "System Events" to click %s' % ROUTING], capture_output=True); time.sleep(0.5)
    return routing_selected()
def menu_want(**kw):
    # bring the plugin UI to the wanted state through the app's menu commands (the user path)
    names = {"play": ("Play / Stop", TR), "record": ("Record", TR), "repeat": ("Repeat (Loop)", TR)}
    for n in (1,2,3,4):
        names["arm%d" % n] = ("Record Enable Track %d" % n, TRK(n)); names["mon%d" % n] = ("Monitor Track %d" % n, TRK(n)); names["mute%d" % n] = ("Mute Track %d" % n, TRK(n))
    u = ui(); changed = False
    for k, v in kw.items():
        if u[k] != bool(v): click(*names[k]); changed = True; time.sleep(0.4)
    if changed:
        u = ui(); bad = {k: u[k] for k, v in kw.items() if u[k] != bool(v)}
        if bad: print("MENU WANT MISMATCH:", bad)
    return u
def noteons(ev):
    by = {}
    t0 = ev[0][0] if ev else 0
    for t, ch, typ, d in ev:
        if typ == "note-on" and d[1] > 0: by.setdefault(ch, []).append((round(t - t0, 3), d[0], d[1]))
    return by
def show(by, label):
    print("  %s: %d note-ons on channels %s" % (label, sum(len(v) for v in by.values()), sorted(by)))
    for ch in sorted(by): print("    ch%d: %s" % (ch, ", ".join("%d@%.2f" % (n, t) for t, n, v in by[ch])))
