# Vision Assistant: backend + mobile app

```
backend/      Your "Version 2 (wall fix)" server, patched for mobile use
mobile_app/   Flutter app (Android + iOS)
MOBILE_PROTOCOL.md
```

## 1. Run the backend
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env          # set API_KEY to a long random string
python app.py                 # serves on :8000
```
Phones must reach it over the network: same Wi-Fi (`http://<pc-ip>:8000`) or a tunnel (`ngrok http 8000`, which gives HTTPS and is required on iOS for anything outside your LAN).

### What I changed in the backend
- Per-session state (`?sid=`) instead of one global frame, so describe/ask work per phone. The bundled web client still works (it uses the `default` session).
- Optional API key (`API_KEY`), applied to REST and the WebSocket.
- `GET /health`, `GET /api/faces`, `DELETE /api/faces/{name}`.
- `?depth=0` stops the base64 depth map being sent to the phone.
- Unknown faces are no longer auto-saved (`FACE_AUTO_REGISTER=false`).
- Fixed `_get_distance_for_box`, which never returned the matched distance.
- Added missing `psutil`, `requests`, `pillow`, `numpy` to requirements.

## 2. Build the app
Needs the Flutter SDK (3.19+) and a physical phone.
```bash
cd mobile_app
./setup.sh                    # creates android/ios folders, adds permissions, pub get
flutter test
flutter run --release
```
First launch: enter the server address and API key in Settings, press **Test connection**, then Save.

## 3. Using it
Four big buttons: **Describe**, **Voice** (continuous voice commands), **Auto** (periodic descriptions), **Settings**.
Hazards are spoken and vibrate: centre 1 pulse, left 2, right 3, urgent 3 long. If no result arrives for 3 s the app says "Detection lost. Please stop and be careful."
Voice commands: "what do you see", "read the text", "who is here", "is the path clear", "start/stop analysis", "register face", "help", "stop listening".

## Known limitations
- **Not compiled or run in the environment I built it in** (no Flutter SDK, no model weights). Expect to fix small issues on first build.
- The app works only in the foreground (it stops when the screen locks or you switch apps). Background camera access needs an Android foreground service and is not possible on iOS.
- Needs the server online. On-device inference (TFLite/CoreML) is not included.
- The default YOLOv8n cannot detect stairs, curbs, potholes, doors or poles, so those hazards never trigger. Fine-tune a model before relying on this for navigation.
- Camera frame rotation is applied from the sensor orientation. Verify on your iPhone that frames arrive upright (left and right alerts depend on it).
- Android cleartext (http) is enabled for LAN development; remove `usesCleartextTraffic` for an https-only release.
- Assistive aid only; not a replacement for a cane or guide dog.
