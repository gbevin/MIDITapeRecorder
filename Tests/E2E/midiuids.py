import ctypes, ctypes.util
cm = ctypes.CDLL("/System/Library/Frameworks/CoreMIDI.framework/CoreMIDI")
cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
cm.MIDIGetNumberOfSources.restype = ctypes.c_ulong
cm.MIDIGetNumberOfDestinations.restype = ctypes.c_ulong
cm.MIDIGetSource.restype = ctypes.c_uint32; cm.MIDIGetSource.argtypes=[ctypes.c_ulong]
cm.MIDIGetDestination.restype = ctypes.c_uint32; cm.MIDIGetDestination.argtypes=[ctypes.c_ulong]
cm.MIDIObjectGetIntegerProperty.argtypes=[ctypes.c_uint32, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int32)]
cm.MIDIObjectGetStringProperty.argtypes=[ctypes.c_uint32, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
cf.CFStringCreateWithCString.restype=ctypes.c_void_p; cf.CFStringCreateWithCString.argtypes=[ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
cf.CFStringGetCString.argtypes=[ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
kUID = cf.CFStringCreateWithCString(None, b"uniqueID", 0x08000100)
kName = cf.CFStringCreateWithCString(None, b"name", 0x08000100)
def name(ep):
    s=ctypes.c_void_p(); cm.MIDIObjectGetStringProperty(ep, kName, ctypes.byref(s))
    buf=ctypes.create_string_buffer(256); cf.CFStringGetCString(s, buf, 256, 0x08000100); return buf.value.decode()
def uid(ep):
    v=ctypes.c_int32(); cm.MIDIObjectGetIntegerProperty(ep, kUID, ctypes.byref(v)); return v.value
print("SOURCES:")
for i in range(cm.MIDIGetNumberOfSources()): ep=cm.MIDIGetSource(i); print("  %-32s uid=%d" % (name(ep), uid(ep)))
print("DESTINATIONS:")
for i in range(cm.MIDIGetNumberOfDestinations()): ep=cm.MIDIGetDestination(i); print("  %-32s uid=%d" % (name(ep), uid(ep)))
