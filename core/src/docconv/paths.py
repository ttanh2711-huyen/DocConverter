"""Tính đường dẫn đầu ra và tránh ghi đè."""

from pathlib import Path


def unique(path: Path) -> Path:
    """`a.md` → `a (1).md`, `a (2).md`… cho tới khi chưa tồn tại (kể cả thư mục ảnh đi kèm)."""
    def taken(p: Path) -> bool:
        return p.exists() or (p.parent / f"{p.stem}_assets").exists()

    if not taken(path):
        return path
    n = 1
    while taken(candidate := path.with_name(f"{path.stem} ({n}){path.suffix}")):
        n += 1
    return candidate
