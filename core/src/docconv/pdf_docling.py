"""PDF → DoclingDocument → Markdown."""

import shutil
from functools import lru_cache
from pathlib import Path

from docling.datamodel.base_models import InputFormat
from docling.datamodel.document import ConversionResult
from docling.datamodel.pipeline_options import EasyOcrOptions, OcrMacOptions, PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling_core.types.doc import ImageRefMode

from docconv.ocr import OcrSettings

# Mã ngôn ngữ chung (vi, en) → mã của Apple Vision.
_OCRMAC_LANG = {"vi": "vi-VT", "en": "en-US"}


def pipeline_options(settings: OcrSettings, force_ocr: bool) -> PdfPipelineOptions:
    force = force_ocr or settings.mode == "force"
    if settings.engine == "easyocr":
        ocr = EasyOcrOptions(lang=list(settings.langs), force_full_page_ocr=force)
    else:
        ocr = OcrMacOptions(lang=[_OCRMAC_LANG.get(x, x) for x in settings.langs], force_full_page_ocr=force)
    return PdfPipelineOptions(
        do_ocr=settings.mode != "off",
        ocr_options=ocr,
        do_table_structure=settings.tables,
        generate_picture_images=True,
        generate_parsed_pages=True,  # cần cho bộ ghi DOCX của bản scan (chiều cao dòng OCR)
        images_scale=2.0,
    )


@lru_cache(maxsize=None)
def _converter(settings: OcrSettings, force_ocr: bool) -> DocumentConverter:
    opts = pipeline_options(settings, force_ocr)
    return DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})


def analyze(pdf: Path, force_ocr: bool = False, settings: OcrSettings = OcrSettings()) -> ConversionResult:
    return _converter(settings, force_ocr).convert(pdf)


def assets_dir_name(md_path: Path) -> str:
    return f"{md_path.stem}_assets"


def save_markdown(result: ConversionResult, md_path: Path) -> list[Path]:
    """Ghi Markdown; ảnh vào thư mục `<tên>_assets/` cạnh file. Trả về các đường dẫn đã tạo."""
    assets = md_path.parent / assets_dir_name(md_path)
    result.document.save_as_markdown(md_path, artifacts_dir=Path(assets.name), image_mode=ImageRefMode.REFERENCED)
    if assets.exists() and not any(assets.iterdir()):
        shutil.rmtree(assets)
    return [md_path] + ([assets] if assets.exists() else [])
