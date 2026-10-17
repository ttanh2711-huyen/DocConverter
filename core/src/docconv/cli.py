"""Dòng lệnh `docconv`."""

import argparse
import sys
from pathlib import Path

from docconv import pdf_docling
from docconv.paths import unique


def _target(src: Path, ext: str, overwrite: bool) -> Path:
    path = src.with_suffix(ext)
    return path if overwrite else unique(path)


def convert_one(src: Path, formats: list[str], overwrite: bool) -> list[Path]:
    result = pdf_docling.analyze(src)
    outputs: list[Path] = []
    if "md" in formats:
        outputs += pdf_docling.save_markdown(result, _target(src, ".md", overwrite))
    return outputs


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="docconv", description="Chuyển đổi tài liệu sang Markdown/Word.")
    sub = ap.add_subparsers(dest="command", required=True)
    c = sub.add_parser("convert", help="Chuyển đổi tệp")
    c.add_argument("inputs", nargs="+", type=Path)
    c.add_argument("--to", default="md", help="md, docx hoặc md,docx (docx chỉ áp dụng cho PDF)")
    c.add_argument("--overwrite", action="store_true", help="Ghi đè tệp đầu ra đã có")
    return ap


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    formats = [f.strip() for f in args.to.split(",") if f.strip()]
    for src in args.inputs:
        for out in convert_one(src.expanduser(), formats, args.overwrite):
            print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
