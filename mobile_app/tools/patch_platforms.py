#!/usr/bin/env python3
"""Adds the permissions this app needs to the platform folders created by `flutter create`."""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent

# ---- Android ------------------------------------------------------------------
m = root / "android/app/src/main/AndroidManifest.xml"
if m.exists():
    s = m.read_text()
    perms = [
        "android.permission.CAMERA",
        "android.permission.INTERNET",
        "android.permission.VIBRATE",
        "android.permission.RECORD_AUDIO",
        "android.permission.WAKE_LOCK",
    ]
    add = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in s)
    if add:
        s = s.replace("<application", add + "    <application", 1)
    if "usesCleartextTraffic" not in s:
        # Allows http:// to a LAN server during development. Remove for release builds that use https only.
        s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    # speech_to_text needs to query the recognition service on Android 11+
    if "android.speech.RecognitionService" not in s:
        if "<queries>" in s:
            s = s.replace("</queries>", """        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
    </queries>""", 1)
        else:
            s = s.replace("</manifest>", """    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
    </queries>
</manifest>""", 1)
    m.write_text(s)
    print("patched", m)

# ---- iOS ----------------------------------------------------------------------
p = root / "ios/Runner/Info.plist"
if p.exists():
    s = p.read_text()
    keys = {
        "NSCameraUsageDescription": "The camera is used to detect obstacles and describe your surroundings.",
        "NSMicrophoneUsageDescription": "The microphone is used for voice commands.",
        "NSSpeechRecognitionUsageDescription": "Speech recognition is used to understand your voice commands.",
    }
    add = "".join(f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in keys.items() if k not in s)
    if add:
        i = s.rfind("</dict>")
        s = s[:i] + add + s[i:]
        p.write_text(s)
    print("patched", p)
if not (m.exists() or p.exists()):
    sys.exit("No android/ or ios/ folder found - run `flutter create .` first (see setup.sh).")
