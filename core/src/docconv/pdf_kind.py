"""Nhận biết PDF có lớp text hay là bản scan."""

from pathlib import Path

import pypdfium2 as pdfium


def page_count(pdf: Path) -> int:
    return len(pdfium.PdfDocument(str(pdf)))


def has_text_layer(pdf: Path, min_chars_per_page: int = 20) -> bool:
    """PDF có lớp text nếu trung bình mỗi trang có ít nhất `min_chars_per_page` ký tự."""
    doc = pdfium.PdfDocument(str(pdf))
    chars = sum(len(page.get_textpage().get_text_range().strip()) for page in doc)
    return chars >= min_chars_per_page * max(len(doc), 1)
