#!/usr/bin/env bash
# One-time setup: generate android/ios platform folders, add permissions, fetch packages.
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "Flutter SDK not found: https://docs.flutter.dev/get-started/install"; exit 1; }

# flutter create must not clobber our sources, so stash them around it
mkdir -p .keep && cp -r lib test pubspec.yaml analysis_options.yaml .keep/
flutter create --org com.visionassistant --project-name vision_assistant --platforms android,ios .
rm -rf lib test && cp -r .keep/lib lib && cp -r .keep/test test
cp .keep/pubspec.yaml pubspec.yaml && cp .keep/analysis_options.yaml analysis_options.yaml
rm -rf .keep

python3 tools/patch_platforms.py
flutter pub get
echo
echo "Done. Run:  flutter run --release     (use a physical phone - the camera does not work in most emulators)"
