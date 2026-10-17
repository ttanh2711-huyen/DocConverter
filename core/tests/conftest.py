import json
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"


def read_text(path: Path) -> str:
    return unicodedata.normalize("NFC", path.read_text(encoding="utf-8"))


def run_cli(*args, cwd=None) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, "-m", "docconv", *map(str, args)],
                          capture_output=True, text=True, cwd=cwd, timeout=900)


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
