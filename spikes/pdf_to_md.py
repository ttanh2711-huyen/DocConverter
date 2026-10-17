"""Spike: chuyển PDF sang Markdown bằng Docling trên macOS Intel.

Dùng: uv run python pdf_to_md.py <file.pdf> [--out DIR] [--ocr auto|force] [--engine ocrmac|easyocr]
"""

import argparse
import resource
import time
from dataclasses import dataclass
from pathlib import Path

from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import EasyOcrOptions, OcrMacOptions, PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling_core.types.doc import ImageRefMode


@dataclass
class Result:
    markdown: Path
    seconds: float
    peak_rss_mb: float


def _ocr_options(engine: str, force: bool):
    if engine == "ocrmac":
        return OcrMacOptions(lang=["vi-VT", "en-US"], force_full_page_ocr=force)
    if engine == "easyocr":
        return EasyOcrOptions(lang=["vi", "en"], force_full_page_ocr=force)
    raise ValueError(f"Engine OCR không hợp lệ: {engine}")


def convert(pdf: Path, out_dir: Path, ocr: str = "auto", engine: str = "ocrmac") -> Result:
    opts = PdfPipelineOptions(
        do_ocr=True,
        ocr_options=_ocr_options(engine, force=(ocr == "force")),
        generate_picture_images=True,
        images_scale=2.0,
    )
    converter = DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})

    start = time.perf_counter()
    doc = converter.convert(pdf).document
    out_dir.mkdir(parents=True, exist_ok=True)
    md = out_dir / f"{pdf.stem}.md"
    doc.save_as_markdown(md, artifacts_dir=Path(f"{pdf.stem}_assets"), image_mode=ImageRefMode.REFERENCED)
    seconds = time.perf_counter() - start

    peak_rss_mb = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024 / 1024  # macOS: bytes
    return Result(md, seconds, peak_rss_mb)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", type=Path)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--ocr", choices=["auto", "force"], default="auto")
    ap.add_argument("--engine", choices=["ocrmac", "easyocr"], default="ocrmac")
    args = ap.parse_args()
    r = convert(args.pdf, args.out or args.pdf.parent, args.ocr, args.engine)
    print(f"{r.markdown}  ({r.seconds:.1f}s, RAM tối đa {r.peak_rss_mb:.0f} MB)")


if __name__ == "__main__":
    main()
