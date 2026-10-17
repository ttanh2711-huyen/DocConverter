import io
import json
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

import pytest

from docconv import cli

FIXTURES = Path(__file__).parent / "fixtures"


def read_text(path: Path) -> str:
    return unicodedata.normalize("NFC", path.read_text(encoding="utf-8"))


def run_cli(*args) -> subprocess.CompletedProcess:
    """Chạy CLI ngay trong tiến trình test để dùng lại mô hình Docling đã nạp."""
    argv = list(map(str, args))
    out, err = io.StringIO(), io.StringIO()
    code = cli.main(argv, out=out, err=err)
    return subprocess.CompletedProcess(argv, code, out.getvalue(), err.getvalue())


def run_cli_process(*args, **kwargs) -> subprocess.Popen:
    """Chạy CLI như tiến trình riêng (dùng cho test tín hiệu, stdout sạch)."""
    return subprocess.Popen([sys.executable, "-m", "docconv", *map(str, args)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kwargs)


def events(proc: subprocess.CompletedProcess) -> list[dict]:
    return [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]


@pytest.fixture
def workdir(tmp_path):
    """Thư mục làm việc có tên chứa dấu tiếng Việt và khoảng trắng."""
    d = tmp_path / "Tài liệu đầu vào"
    d.mkdir()
    return d


@pytest.fixture
def copy_fixture(workdir):
    def _copy(name: str, dest: Path | None = None) -> Path:
        target = (dest or workdir) / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(FIXTURES / name, target)
        return target
    return _copy
