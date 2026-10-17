#!/bin/bash
# Đóng gói DocConverter.app vào dist/.
#   scripts/make-app.sh        bản phát hành
#   scripts/make-app.sh --dev  trỏ app tới venv của core/ (không cần thiết lập môi trường lần đầu)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV=0; [[ "${1:-}" == "--dev" ]] && DEV=1

cd "$ROOT/app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/DocConverter"

APP="$ROOT/dist/DocConverter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DocConverter"
cp "$ROOT/app/Resources/Info.plist" "$APP/Contents/Info.plist"

if [[ $DEV == 1 ]]; then
  /usr/libexec/PlistBuddy -c "Add :DocConverterDevPython string $ROOT/core/.venv/bin/python" "$APP/Contents/Info.plist"
fi

codesign --force --deep -s - "$APP"
echo "Đã tạo $APP"
