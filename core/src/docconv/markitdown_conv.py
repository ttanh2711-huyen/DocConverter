"""Định dạng khác (Office, HTML, CSV…) → Markdown bằng markitdown."""

from functools import lru_cache
from pathlib import Path

from markitdown import MarkItDown


@lru_cache(maxsize=1)
def _md() -> MarkItDown:
    return MarkItDown(enable_plugins=False)


def to_markdown(src: Path, md_path: Path) -> Path:
    text = _md().convert(str(src)).text_content
    md_path.write_text(text, encoding="utf-8")
    return md_path
