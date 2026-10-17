"""Tính đường dẫn đầu ra và tránh ghi đè."""

from pathlib import Path


def dest_dir(src: Path, base: Path, out_mode: str, out: Path | None) -> Path:
    """Thư mục ghi kết quả cho `src`.

    beside: cạnh tệp gốc. dir: `out/<thư mục chứa src, tương đối so với base>`.
    """
    if out_mode == "beside":
        return src.parent
    assert out is not None
    try:
        rel = src.parent.relative_to(base)
    except ValueError:
        rel = Path()
    return out / rel


def unique(path: Path) -> Path:
    """`a.md` → `a (1).md`, `a (2).md`… cho tới khi chưa tồn tại (với .md: cả thư mục ảnh đi kèm)."""
    def taken(p: Path) -> bool:
        return p.exists() or (p.suffix == ".md" and (p.parent / f"{p.stem}_assets").exists())

    if not taken(path):
        return path
    n = 1
    while taken(candidate := path.with_name(f"{path.stem} ({n}){path.suffix}")):
        n += 1
    return candidate
