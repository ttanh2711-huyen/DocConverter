"""Dòng lệnh `docconv`."""

import argparse
import sys
from pathlib import Path
from typing import TextIO

from docconv import docx_export, pdf_docling
from docconv.paths import unique
from docconv.pdf_kind import has_text_layer


def _target(src: Path, ext: str, overwrite: bool) -> Path:
    path = src.with_suffix(ext)
    return path if overwrite else unique(path)


def convert_pdf(src: Path, formats: list[str], overwrite: bool) -> list[Path]:
    is_text = has_text_layer(src)
    result = None
    if "md" in formats or ("docx" in formats and not is_text):
        result = pdf_docling.analyze(src, force_ocr=not is_text)

    outputs: list[Path] = []
    if "md" in formats:
        outputs += pdf_docling.save_markdown(result, _target(src, ".md", overwrite))
    if "docx" in formats:
        out = _target(src, ".docx", overwrite)
        if is_text:
            outputs.append(docx_export.text_pdf_to_docx(src, out))
        else:
            outputs.append(docx_export.scan_pdf_to_docx(result, out))
    return outputs


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="docconv", description="Chuyển đổi tài liệu sang Markdown/Word.")
    sub = ap.add_subparsers(dest="command", required=True)
    c = sub.add_parser("convert", help="Chuyển đổi tệp")
    c.add_argument("inputs", nargs="+", type=Path)
    c.add_argument("--to", default="md", help="md, docx hoặc md,docx (docx chỉ áp dụng cho PDF)")
    c.add_argument("--overwrite", action="store_true", help="Ghi đè tệp đầu ra đã có")
    return ap


def main(argv: list[str] | None = None, out: TextIO | None = None, err: TextIO | None = None) -> int:
    out, err = out or sys.stdout, err or sys.stderr
    args = build_parser().parse_args(argv)
    formats = [f.strip() for f in args.to.split(",") if f.strip()]
    for src in args.inputs:
        for path in convert_pdf(src.expanduser(), formats, args.overwrite):
            print(path, file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
