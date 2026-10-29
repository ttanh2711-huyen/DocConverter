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


def layout_text(pdf: Path, edge_pages: int = 2) -> str:
    """Lớp chữ của các trang đầu và cuối, mỗi dòng một dòng; các cụm chữ cách xa nhau trên cùng dòng
    (phần đầu và phần ký hai cột của văn bản hành chính) được tách thành dòng riêng."""
    doc = pdfium.PdfDocument(str(pdf))
    n = len(doc)
    pages = sorted(set(range(min(edge_pages, n))) | set(range(max(n - edge_pages, 0), n)))
    lines: list[str] = []
    for index in pages:
        tp = doc[index].get_textpage()
        count = tp.count_chars()
        text = tp.get_text_range(0, count)
        if len(text) != count:  # ký tự ngoài BMP: không ánh xạ 1-1 được, dùng nguyên văn
            lines += text.splitlines()
            continue
        segment, space, prev_right = "", False, None
        for k, ch in enumerate(text):
            if ch in "\r\n":
                if segment.strip():
                    lines.append(segment.strip())
                segment, space, prev_right = "", False, None
                continue
            if ch.isspace():
                space = True
                continue
            left, bottom, right, top = tp.get_charbox(k)
            height = max(top - bottom, 1.0)
            if prev_right is not None and left - prev_right > max(3 * height, 24):
                if segment.strip():
                    lines.append(segment.strip())
                segment = ""
            elif space and segment:
                segment += " "
            segment += ch
            space, prev_right = False, right
        if segment.strip():
            lines.append(segment.strip())
    return "\n".join(lines)
