# One-time setup for Windows PowerShell: generate android/ios platform folders, add permissions, fetch packages.
$ErrorActionPreference = "Stop"

Set-Location -Path $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter SDK not found in PATH: https://docs.flutter.dev/get-started/install"
    exit 1
}

# Stash custom sources so flutter create doesn't overwrite them
if (Test-Path .keep) { Remove-Item -Recurse -Force .keep }
New-Item -ItemType Directory -Path .keep | Out-Null
Copy-Item -Recurse lib, test, pubspec.yaml, analysis_options.yaml .keep\

Write-Host "Creating Android and iOS platform files with Flutter..."
flutter create --org com.visionassistant --project-name vision_assistant --platforms android,ios .

Write-Host "Restoring project sources..."
Remove-Item -Recurse -Force lib, test
Copy-Item -Recurse .keep\lib lib
Copy-Item -Recurse .keep\test test
Copy-Item -Force .keep\pubspec.yaml pubspec.yaml
Copy-Item -Force .keep\analysis_options.yaml analysis_options.yaml
Remove-Item -Recurse -Force .keep

Write-Host "Patching platform permissions (camera, audio, vibration, cleartext traffic)..."
python tools\patch_platforms.py

Write-Host "Running flutter pub get..."
flutter pub get

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "To run the app on a connected phone:"
Write-Host "  flutter run"
Write-Host "Or for optimized performance:"
Write-Host "  flutter run --release"

