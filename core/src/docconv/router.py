"""Chọn bộ chuyển đổi theo đuôi tệp."""

from pathlib import Path

MARKITDOWN_EXTS = {
    ".docx", ".pptx", ".xlsx", ".xls",
    ".html", ".htm", ".csv", ".json", ".xml", ".txt",
    ".epub", ".zip", ".msg",
    ".jpg", ".jpeg", ".png",
}
SUPPORTED_EXTS = {".pdf"} | MARKITDOWN_EXTS


class UnsupportedFormat(ValueError):
    pass


def kind_of(path: Path) -> str:
    """"pdf" (Docling/pdf2docx) hoặc "markitdown"; ném UnsupportedFormat nếu không hỗ trợ."""
    ext = path.suffix.lower()
    if ext == ".pdf":
        return "pdf"
    if ext in MARKITDOWN_EXTS:
        return "markitdown"
    raise UnsupportedFormat(f"Không hỗ trợ định dạng {ext or '(không có đuôi)'}: {path.name}")
