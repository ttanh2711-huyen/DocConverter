"""Dòng lệnh `docconv` (giao thức với app: PROTOCOL.md)."""

import argparse
import json
import logging
import os
import shutil
import signal
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

from docconv.events import Emitter
from docconv.ocr import OcrSettings
from docconv.paths import dest_dir, unique
from docconv.router import SUPPORTED_EXTS, UnsupportedFormat, kind_of


class Cancelled(BaseException):
    """Nhận SIGTERM/SIGINT."""


@dataclass
class Job:
    src: Path
    base: Path


@dataclass
class Skip:
    src: Path
    message: str


def _hidden(path: Path, root: Path) -> bool:
    return any(part.startswith(".") for part in path.relative_to(root).parts)


def collect(inputs: list[Path], manifest: list[dict], recursive: bool, exclude: Path | None) -> list[Job | Skip]:
    items: list[Job | Skip] = [Job(Path(m["src"]), Path(m.get("base") or Path(m["src"]).parent)) for m in manifest]
    for inp in inputs:
        inp = inp.expanduser().absolute()
        if not inp.is_dir():
            items.append(Job(inp, inp.parent))
            continue
        pattern = "**/*" if recursive else "*"
        for p in sorted(inp.glob(pattern)):
            if not p.is_file() or _hidden(p, inp) or (exclude and p.is_relative_to(exclude)):
                continue
            if p.suffix.lower() in SUPPORTED_EXTS:
                items.append(Job(p, inp))
            else:
                items.append(Skip(p, f"Không hỗ trợ định dạng {p.suffix or '(không có đuôi)'}: {p.name}"))
    return items


class Converter:
    """Chuyển một tệp; mọi đầu ra được tạo trong thư mục tạm rồi mới chuyển vào chỗ."""

    def __init__(self, formats: list[str], overwrite: bool, emit: Emitter, ocr=None):
        self.formats, self.overwrite, self.emit, self.ocr = formats, overwrite, emit, ocr

    def _final(self, dest: Path, stem: str, ext: str) -> Path:
        path = dest / f"{stem}{ext}"
        return path if self.overwrite else unique(path)

    def run(self, src: Path, dest: Path) -> list[Path]:
        kind = kind_of(src)
        dest.mkdir(parents=True, exist_ok=True)
        tmp = Path(tempfile.mkdtemp(prefix=".docconv-tmp-", dir=dest))
        try:
            produced = self._pdf(src, dest, tmp) if kind == "pdf" else self._other(src, dest, tmp)
            return [self._move(p, dest) for p in produced]
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def _move(self, p: Path, dest: Path) -> Path:
        target = dest / p.name
        if target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()
        shutil.move(p, target)
        return target

    def _pdf(self, src: Path, dest: Path, tmp: Path) -> list[Path]:
        from docconv import docx_export, pdf_docling
        from docconv.pdf_kind import has_text_layer, page_count

        is_text = has_text_layer(src)
        result = None
        if "md" in self.formats or ("docx" in self.formats and not is_text):
            self.emit("progress", file=str(src), stage="analyze",
                      message=f"Đang phân tích bố cục ({page_count(src)} trang)"
                      + ("" if is_text else ", nhận dạng chữ (OCR)"))
            result = pdf_docling.analyze(src, force_ocr=not is_text, settings=self.ocr or OcrSettings())
        produced: list[Path] = []
        if "md" in self.formats:
            self.emit("progress", file=str(src), stage="markdown", message="Đang ghi Markdown")
            md = tmp / self._final(dest, src.stem, ".md").name
            produced += pdf_docling.save_markdown(result, md)
        if "docx" in self.formats:
            self.emit("progress", file=str(src), stage="docx", message="Đang tạo Word")
            out = tmp / self._final(dest, src.stem, ".docx").name
            if is_text:
                produced.append(docx_export.text_pdf_to_docx(src, out))
            else:
                produced.append(docx_export.scan_pdf_to_docx(result, out))
        return produced

    def _other(self, src: Path, dest: Path, tmp: Path) -> list[Path]:
        from docconv import markitdown_conv

        if "docx" in self.formats:
            self.emit("warning", file=str(src),
                      message=f"Định dạng Word (.docx) chỉ áp dụng cho PDF — bỏ qua cho {src.name}")
        self.emit("progress", file=str(src), stage="markdown", message="Đang ghi Markdown")
        return [markitdown_conv.to_markdown(src, tmp / self._final(dest, src.stem, ".md").name)]


def _user_message(e: Exception, src: Path) -> str:
    if isinstance(e, UnsupportedFormat):
        return str(e)
    if type(e).__name__ == "PdfiumError":
        return f"Không đọc được tệp PDF (tệp hỏng hoặc không phải PDF): {src.name}"
    if isinstance(e, FileNotFoundError):
        return f"Không tìm thấy tệp: {src}"
    return f"Chuyển đổi thất bại: {src.name} ({e})"


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="docconv", description="Chuyển đổi tài liệu sang Markdown/Word.")
    sub = ap.add_subparsers(dest="command", required=True)
    c = sub.add_parser("convert", help="Chuyển đổi tệp hoặc thư mục")
    c.add_argument("inputs", nargs="*", type=Path)
    c.add_argument("--manifest", help='Tệp JSON [{"src":..., "base":...}] hoặc "-" để đọc từ stdin')
    c.add_argument("--recursive", action="store_true", help="Bao gồm thư mục con")
    c.add_argument("--to", default="md", help="md, docx hoặc md,docx (docx chỉ áp dụng cho PDF)")
    c.add_argument("--out-mode", choices=["beside", "dir"], default="beside")
    c.add_argument("--out", type=Path, help="Thư mục đầu ra khi --out-mode dir")
    c.add_argument("--overwrite", action="store_true", help="Ghi đè tệp đầu ra đã có")
    c.add_argument("--json", action="store_true", help="In sự kiện JSON Lines ra stdout (cho app)")
    c.add_argument("--ocr", choices=["auto", "off", "force"], default="auto",
                   help="auto: chỉ OCR trang không có chữ; off: tắt; force: OCR mọi trang")
    c.add_argument("--ocr-engine", choices=["ocrmac", "easyocr"], default="ocrmac")
    c.add_argument("--ocr-lang", default="vi,en", help="Ngôn ngữ OCR, ví dụ vi,en")
    c.add_argument("--no-tables", action="store_true", help="Tắt nhận dạng cấu trúc bảng (nhanh hơn)")
    return ap


def _read_manifest(arg: str | None) -> list[dict]:
    if not arg:
        return []
    text = sys.stdin.read() if arg == "-" else Path(arg).read_text(encoding="utf-8")
    return json.loads(text)


def main(argv: list[str] | None = None, out: TextIO | None = None, err: TextIO | None = None) -> int:
    out, err = out or sys.stdout, err or sys.stderr
    ap = build_parser()
    args = ap.parse_args(argv)
    if args.out_mode == "dir" and not args.out:
        ap.error("--out-mode dir cần --out")
    formats = [f.strip() for f in args.to.split(",") if f.strip()]
    if not formats or set(formats) - {"md", "docx"}:
        ap.error("--to chỉ nhận md, docx hoặc md,docx")
    out_root = args.out.expanduser().absolute() if args.out else None

    emit = Emitter(out, err, args.json)
    items = collect(args.inputs, _read_manifest(args.manifest), args.recursive, out_root)
    if not items:
        ap.error("không có tệp đầu vào")

    def on_signal(signum, frame):
        raise Cancelled()

    previous = {s: signal.signal(s, on_signal) for s in (signal.SIGTERM, signal.SIGINT)}
    ocr = OcrSettings(mode=args.ocr, engine=args.ocr_engine,
                      langs=tuple(x.strip() for x in args.ocr_lang.split(",") if x.strip()), tables=not args.no_tables)
    converter = Converter(formats, args.overwrite, emit, ocr)
    jobs = [i for i in items if isinstance(i, Job)]
    ok = failed = skipped = 0
    cancelled = False
    try:
        for item in items:
            if isinstance(item, Skip):
                skipped += 1
                emit("skipped", file=str(item.src), message=item.message)
        for index, job in enumerate(jobs, 1):
            src = job.src
            try:
                kind = kind_of(src)
            except UnsupportedFormat:
                kind = None
            pages = None
            if kind == "pdf":
                try:
                    from docconv.pdf_kind import page_count
                    pages = page_count(src)
                except Exception:
                    pages = None
            emit("start", file=str(src), index=index, total=len(jobs), kind=kind, pages=pages)
            started = time.perf_counter()
            try:
                outputs = converter.run(src, dest_dir(src, job.base, args.out_mode, out_root))
            except Exception as e:  # lỗi của một tệp không dừng cả lô
                failed += 1
                emit("error", file=str(src), message=_user_message(e, src), detail=f"{type(e).__name__}: {e}")
                continue
            ok += 1
            emit("done", file=str(src), outputs=[str(p) for p in outputs],
                 seconds=round(time.perf_counter() - started, 1))
    except Cancelled:
        cancelled = True
        emit("cancelled")
    finally:
        for s, h in previous.items():
            signal.signal(s, h)
    emit("finished", ok=ok, failed=failed, skipped=skipped, cancelled=cancelled)
    if cancelled:
        return 130
    if failed:
        return 2 if ok else 1
    return 0


def entry() -> None:
    """Điểm vào khi chạy như tiến trình: ở chế độ --json, chỉ sự kiện được ra stdout."""
    logging.basicConfig(level=logging.WARNING, stream=sys.stderr)
    out = None
    if "--json" in sys.argv:
        events_fd = os.dup(1)
        os.dup2(2, 1)  # mọi thứ thư viện in ra stdout (kể cả mã C) chuyển sang stderr
        sys.stdout = sys.stderr
        out = os.fdopen(events_fd, "w", encoding="utf-8", buffering=1)
    sys.exit(main(out=out))


if __name__ == "__main__":
    entry()
