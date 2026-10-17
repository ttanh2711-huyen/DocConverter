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
cp "$ROOT/app/Resources/AppIcon.icns" "$APP/Contents/Resources/"

# Môi trường Python được tạo ở lần chạy đầu (bootstrap-env.sh) từ các tệp này.
RES="$APP/Contents/Resources"
cp "$ROOT/scripts/bootstrap-env.sh" "$RES/"
cp "${UV_BIN:-$(command -v uv || echo "$HOME/.local/bin/uv")}" "$RES/uv"
mkdir -p "$RES/core"
cp "$ROOT/core/pyproject.toml" "$ROOT/core/uv.lock" "$RES/core/"
rsync -a --exclude __pycache__ "$ROOT/core/src" "$RES/core/"
cp "$ROOT/core/tests/fixtures/text_vi.pdf" "$RES/sample.pdf"

if [[ $DEV == 1 ]]; then
  /usr/libexec/PlistBuddy -c "Add :DocConverterDevPython string $ROOT/core/.venv/bin/python" "$APP/Contents/Info.plist"
fi

codesign --force --deep -s - "$APP"
codesign --verify --deep "$APP"
echo "Đã tạo $APP"

if [[ $DEV == 0 ]]; then
  rm -f "$ROOT/dist/DocConverter.zip"
  ditto -c -k --keepParent "$APP" "$ROOT/dist/DocConverter.zip"
  echo "Đã tạo $ROOT/dist/DocConverter.zip"
fi
