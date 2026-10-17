#!/bin/bash
# Thiết lập môi trường Python cho DocConverter (chạy ở lần mở app đầu tiên).
#   bootstrap-env.sh          cài/cập nhật venv + tải mô hình Docling
#   bootstrap-env.sh --check  mã thoát 0 nếu môi trường hợp lệ và đúng phiên bản
# Đặt cạnh: uv (tệp chạy), core/ (pyproject.toml, uv.lock, src/), sample.pdf.
# In "STEP <n>/<tổng> <mô tả>" để app hiển thị tiến trình.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SUPPORT="${DOCCONV_APP_SUPPORT:-$HOME/Library/Application Support/DocConverter}"
VENV="$SUPPORT/venv"
STAMP="$VENV/.docconv-version"
UV="${DOCCONV_UV:-$HERE/uv}"
[[ -x "$UV" ]] || UV="$(command -v uv)"

want_version() {
  # Đường dẫn tương đối để mã không phụ thuộc vị trí của app.
  (cd "$HERE/core" && shasum -a 256 uv.lock pyproject.toml src/docconv/*.py) | shasum -a 256 | cut -c1-16
}

check() {
  [[ -x "$VENV/bin/python" ]] || return 1
  [[ -f "$STAMP" && "$(cat "$STAMP")" == "$(want_version)" ]] || return 1
  "$VENV/bin/python" -c "import docconv, docling, markitdown, pdf2docx" 2>/dev/null
}

if [[ "${1:-}" == "--check" ]]; then
  check && exit 0 || exit 1
fi

mkdir -p "$SUPPORT"
echo "STEP 1/4 Chuẩn bị Python 3.12"
"$UV" python install 3.12

echo "STEP 2/4 Cài thư viện chuyển đổi (khoảng 2 GB, có thể mất vài phút)"
rm -rf "$SUPPORT/core"
cp -R "$HERE/core" "$SUPPORT/core"
UV_PROJECT_ENVIRONMENT="$VENV" "$UV" sync --project "$SUPPORT/core" --frozen --no-dev --no-editable --python 3.12

echo "STEP 3/4 Tải mô hình nhận dạng bố cục và bảng"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$HERE/sample.pdf" "$WORK/sample.pdf"
"$VENV/bin/python" -m docconv convert "$WORK/sample.pdf" --to md >/dev/null

echo "STEP 4/4 Kiểm tra"
want_version > "$STAMP"
check
echo "XONG"
