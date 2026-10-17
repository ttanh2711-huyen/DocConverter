"""Tuỳ chọn OCR/nhận dạng bảng (không import Docling để CLI khởi động nhanh)."""

from dataclasses import dataclass


@dataclass(frozen=True)
class OcrSettings:
    mode: str = "auto"  # auto: chỉ OCR trang không có chữ; off: tắt; force: OCR mọi trang
    engine: str = "ocrmac"  # ocrmac (Apple Vision) | easyocr
    langs: tuple[str, ...] = ("vi", "en")
    tables: bool = True  # nhận dạng cấu trúc bảng
