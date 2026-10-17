#!/bin/bash
# Chạy DocConverter.app ở chế độ tự kiểm tra: nạp tệp/thư mục, bấm Bắt đầu, chụp cửa sổ rồi thoát.
#   scripts/selftest.sh <ảnh.png> <tệp hoặc thư mục>... [-- KEY=VALUE ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SNAP="$1"; shift
FILES=(); EXTRA=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then shift; EXTRA=("$@"); break; fi
  FILES+=("$1"); shift
done
JOINED="$(IFS=:; echo "${FILES[*]}")"
env DOCCONV_TEST_FILES="$JOINED" DOCCONV_TEST_SNAPSHOT="$SNAP" "${EXTRA[@]+"${EXTRA[@]}"}" \
  perl -e 'alarm shift; exec @ARGV' "${SELFTEST_TIMEOUT:-600}" "$ROOT/dist/DocConverter.app/Contents/MacOS/DocConverter"
