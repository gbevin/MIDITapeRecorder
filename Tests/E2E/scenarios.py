# menu-driven regression scenarios against the running app (separate inputs per track, Src1-4)
# usage: python3 scenarios.py [A B C D G]   (all when none given)
import sys, time; from hostlib import *
routing(1)
def stopped():
    u = ui()
    if u["play"]: click("Play / Stop", TR); time.sleep(0.8); u = ui()
    return u
def playback(name, seconds):
    # with Repeat off the transport stops by itself at the session end; only a
    # transport still running (looping content) gets the stop click
    cap = Capture(name); click("Rewind to Start", TR); time.sleep(0.3); click("Play / Stop", TR); time.sleep(seconds)
    if state()["play"]: click("Play / Stop", TR); time.sleep(0.5)
    return cap.stop()
def prefix_or_restart(got, expected):
    # a playback that ended and got restarted by a racing stop click repeats the sequence
    return got == expected or (got[:len(expected)] == expected and expected[:len(got) - len(expected)] == got[len(expected):])
SENT = []          # (track, note, velocity, wall time) of every pattern note-on; spawning sendmidi is slow on a loaded machine
def pattern(tracks, rounds=8):
    t0 = time.time()
    for r in range(rounds):
        for t in tracks: SENT.append((t, 60 + t*4 + r % 3, 90 + t, time.time())); send(t, "on", 60 + t*4 + r % 3, 90 + t)
        time.sleep(0.15)
        for t in tracks: send(t, "off", 60 + t*4 + r % 3, 0)
        time.sleep(0.25)
    return time.time() - t0
def expect_pattern(by, tracks, label):
    ok = True; worst = 0.0
    for t in (1,2,3,4):
        got = [(n, v) for _, n, v in by.get(t, [])]
        sent = [(n, v, ts) for tt, n, v, ts in SENT if tt == t]
        want = [(n, v) for n, v, _ in sent] if t in tracks else []
        if got != want: ok = False; print("    track %d: got %s want %s" % (t, got, want))
        elif sent:
            # spacing of the played notes against the spacing of the sends
            for (tp, _, _), (_, _, ts) in zip(by[t], sent):
                worst = max(worst, abs((tp - by[t][0][0]) - (ts - sent[0][2])))
    print("  %s -> %s (worst spacing deviation vs the sends %.0f ms)" % (label, "OK" if ok else "MISMATCH", worst * 1000))
    return ok
results = {}
which = sys.argv[1:] or ["A","B","C","D","G"]

if "A" in which:
    print("=== A: four-track take through the menus (Record while stopped, first message starts the transport)")
    stopped(); clear_all(); menu_want(repeat=0, record=0, arm1=1, arm2=1, arm3=1, arm4=1)
    click("Record", TR); time.sleep(0.5); u = ui(); print("  after Record: play=%d record=%d (record waits for the first message)" % (u["play"], u["record"]))
    SENT.clear(); dur = pattern((1,2,3,4)); u = ui(); print("  during take: play=%d record=%d (sends took %.1f s)" % (u["play"], u["record"], dur))
    time.sleep(1.0); u = stopped(); print("  after stop: play=%d record=%d" % (u["play"], u["record"]))
    ev = playback("A", dur + 2.5); by = noteons(ev); show(by, "playback")
    results["A"] = expect_pattern(by, (1,2,3,4), "A four tracks 8/8 each, no cross-talk")

if "B" in which:
    print("=== B: record on the fly while playing, then Record off keeps the transport running")
    stopped(); clear_all(); menu_want(repeat=0, record=0, arm1=1, arm2=1, arm3=0, arm4=0)
    click("Record", TR); time.sleep(0.4); SENT.clear(); dur = pattern((1,2)); time.sleep(0.8); click("Play / Stop", TR); time.sleep(0.8)
    menu_want(repeat=1, record=0, arm1=1, arm2=0)
    click("Rewind to Start", TR); time.sleep(0.3); click("Play / Stop", TR); time.sleep(1.0)
    click("Record", TR); time.sleep(0.3); u = ui(); print("  after Record while playing: play=%d record=%d" % (u["play"], u["record"]))
    send(1, "on", 100, 111); time.sleep(0.2); send(1, "off", 100, 0); time.sleep(0.3); send(1, "on", 101, 112); time.sleep(0.2); send(1, "off", 101, 0); time.sleep(0.3)
    click("Record", TR); time.sleep(0.5); u = ui(); print("  after Record off while playing: play=%d record=%d (transport must keep running)" % (u["play"], u["record"]))
    keeps_running = u["play"] and not u["record"]
    stopped(); menu_want(repeat=0)
    ev = playback("B", dur + 2.0); by = noteons(ev); show(by, "playback")
    t1 = [n for _, n, _ in by.get(1, [])]; t2 = [(n, v) for _, n, v in by.get(2, [])]
    punched = 100 in t1 and 101 in t1 and 0 < sum(1 for n in t1 if n < 100) < 8
    t2ok = t2 == [(n, v) for tt, n, v, _ in SENT if tt == 2]
    results["B"] = keeps_running and punched and t2ok
    print("  B keeps running=%s, track 1 punched (%d original notes left + 2 new)=%s, track 2 untouched=%s -> %s" % (keeps_running, sum(1 for n in t1 if n < 100), punched, t2ok, "OK" if results["B"] else "MISMATCH"))

if "C" in which:
    print("=== C: arming changes while Record is engaged (arm before the first message, arm and disarm during the take)")
    stopped(); clear_all(); menu_want(repeat=0, record=0, arm1=0, arm2=0, arm3=0, arm4=0)
    click("Record", TR); time.sleep(0.4)
    send(2, "on", 70, 100); time.sleep(0.15); send(2, "off", 70, 0); time.sleep(0.3)      # nothing armed: must not start
    u = ui(); print("  message on an unarmed track with Record engaged: play=%d (must stay stopped)" % u["play"]); c_idle = not u["play"]
    click("Record Enable Track 3", TRK(3)); time.sleep(0.4)
    send(3, "on", 72, 100); time.sleep(0.15); send(3, "off", 72, 0)                      # starts the take on track 3
    send(1, "on", 64, 100); time.sleep(0.15); send(1, "off", 64, 0); time.sleep(0.3)      # track 1 not armed: dropped
    u = ui(); print("  after arming track 3 and sending: play=%d record=%d" % (u["play"], u["record"]))
    click("Record Enable Track 1", TRK(1)); time.sleep(0.4)
    send(1, "on", 65, 100); time.sleep(0.15); send(1, "off", 65, 0); time.sleep(0.3)      # armed mid-take: recorded
    click("Record Enable Track 3", TRK(3)); time.sleep(0.4)
    u = ui(); print("  after disarming track 3 (the track that started the take): play=%d record=%d" % (u["play"], u["record"]))
    send(3, "on", 73, 100); time.sleep(0.15); send(3, "off", 73, 0); time.sleep(0.3)      # disarmed mid-take: dropped
    time.sleep(0.5); stopped()
    ev = playback("C", 4.0); by = noteons(ev); show(by, "playback")
    got = {ch: [n for _, n, _ in v] for ch, v in by.items()}
    # the kernel only records tracks whose recording began with the take, so the
    # track armed mid-take stays empty and disarming the starting track ends the take
    results["C"] = c_idle and prefix_or_restart(got.get(3, []), [72]) and 1 not in got
    print("  C expect {3: [72]} got %s -> %s" % (got, "OK" if results["C"] else "MISMATCH"))

if "D" in which:
    print("=== D: Clear Track during a take with Record still engaged (the cleared track stays silent for the rest of the take)")
    stopped(); clear_all(); menu_want(repeat=0, record=0, arm1=1, arm2=1, arm3=0, arm4=0)
    click("Record", TR); time.sleep(0.4)
    for n in (60, 61): send(1, "on", n, 100); send(2, "on", n + 10, 100); time.sleep(0.15); send(1, "off", n, 0); send(2, "off", n + 10, 0); time.sleep(0.3)
    click("Clear Track 1", TRK(1)); time.sleep(0.5); u = ui(); print("  after Clear Track 1 mid-take: play=%d record=%d arm1=%d" % (u["play"], u["record"], u["arm1"]))
    send(1, "on", 62, 100); send(2, "on", 72, 100); time.sleep(0.15); send(1, "off", 62, 0); send(2, "off", 72, 0); time.sleep(0.5)
    stopped()
    ev = playback("D", 6.0); by = noteons(ev); show(by, "playback")
    got = {ch: [n for _, n, _ in v] for ch, v in by.items()}
    # the clear drops the kernel's recording flag for the track, so it stays silent for the rest of the take
    results["D"] = prefix_or_restart(got.get(2, []), [70, 71, 72]) and 1 not in got
    print("  D expect track 2 [70, 71, 72] and track 1 silent after the clear, got %s -> %s" % (got, "OK" if results["D"] else "MISMATCH"))

if "G" in which:
    print("=== G: undo / redo of the last take")
    stopped(); clear_all(); menu_want(repeat=0, record=0, arm1=1, arm2=0, arm3=0, arm4=0)
    click("Record", TR); time.sleep(0.4); SENT.clear(); dur = pattern((1,), rounds=3); time.sleep(0.5); click("Play / Stop", TR); time.sleep(0.8)
    EDIT = 'menu 1 of menu bar item "Edit" of menu bar 1'
    click("Undo", EDIT); time.sleep(0.5); ev = playback("G1", dur + 1.5); n_undo = len(noteons(ev).get(1, []))
    click("Redo", EDIT); time.sleep(0.5); ev = playback("G2", dur + 1.5); n_redo = len(noteons(ev).get(1, []))
    results["G"] = n_undo == 0 and n_redo == 3
    print("  G after undo %d note-ons, after redo %d (expect 0 and 3) -> %s" % (n_undo, n_redo, "OK" if results["G"] else "MISMATCH"))

stopped(); print("RESULTS:", results)
