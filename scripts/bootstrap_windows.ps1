$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not in PATH. Install Flutter first."
}

flutter config --enable-windows-desktop
flutter create --platforms=windows --project-name droid_purifier .
flutter pub get

New-Item -ItemType Directory -Force -Path tools | Out-Null
$zip = Join-Path $env:TEMP "platform-tools.zip"
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip
if (Test-Path "tools/platform-tools") { Remove-Item "tools/platform-tools" -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath tools -Force
Remove-Item $zip -Force

Write-Host "Ready. Run: flutter run -d windows"
