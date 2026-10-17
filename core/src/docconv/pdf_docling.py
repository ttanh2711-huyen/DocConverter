"""PDF → DoclingDocument → Markdown."""

import shutil
from functools import lru_cache
from pathlib import Path

from docling.datamodel.base_models import InputFormat
from docling.datamodel.document import ConversionResult
from docling.datamodel.pipeline_options import OcrMacOptions, PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling_core.types.doc import ImageRefMode


@lru_cache(maxsize=None)
def _converter(force_ocr: bool) -> DocumentConverter:
    opts = PdfPipelineOptions(
        do_ocr=True,
        ocr_options=OcrMacOptions(lang=["vi-VT", "en-US"], force_full_page_ocr=force_ocr),
        generate_picture_images=True,
        generate_parsed_pages=True,  # cần cho bộ ghi DOCX của bản scan (chiều cao dòng OCR)
        images_scale=2.0,
    )
    return DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})


def analyze(pdf: Path, force_ocr: bool = False) -> ConversionResult:
    return _converter(force_ocr).convert(pdf)


def assets_dir_name(md_path: Path) -> str:
    return f"{md_path.stem}_assets"


def save_markdown(result: ConversionResult, md_path: Path) -> list[Path]:
    """Ghi Markdown; ảnh vào thư mục `<tên>_assets/` cạnh file. Trả về các đường dẫn đã tạo."""
    assets = md_path.parent / assets_dir_name(md_path)
    result.document.save_as_markdown(md_path, artifacts_dir=Path(assets.name), image_mode=ImageRefMode.REFERENCED)
    if assets.exists() and not any(assets.iterdir()):
        shutil.rmtree(assets)
    return [md_path] + ([assets] if assets.exists() else [])
