import unicodedata
from pathlib import Path

import pytest

from pdf_to_md import convert

FIXTURES = Path(__file__).parent.parent / "fixtures"

PHRASES = [
    "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM",
    "Báo cáo kết quả kiểm tra hồ sơ đất đai",
    "Ủy ban nhân dân quận Ninh Kiều",
    "Giấy chứng nhận quyền sử dụng đất",
    "Sở Nông nghiệp và Môi trường",
    "chuyển nhượng một phần thửa đất",
]


def _read(md: Path) -> str:
    return unicodedata.normalize("NFC", md.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def text_md(tmp_path_factory):
    out = tmp_path_factory.mktemp("text")
    return convert(FIXTURES / "text_vi.pdf", out).markdown


def test_text_pdf_keeps_vietnamese_diacritics(text_md):
    md = _read(text_md)
    for phrase in PHRASES:
        assert phrase in md


def test_text_pdf_has_headings_and_table(text_md):
    md = _read(text_md)
    assert any(line.startswith("#") and "Báo cáo" in line for line in md.splitlines())
    table_rows = [line for line in md.splitlines() if line.startswith("|")]
    assert any("Xuân Khánh" in r and "98" in r and "90" in r for r in table_rows)


def test_text_pdf_images_go_to_assets_dir(text_md):
    assets = text_md.parent / f"{text_md.stem}_assets"
    images = list(assets.glob("*.png"))
    assert images
    assert f"{assets.name}/{images[0].name}" in text_md.read_text(encoding="utf-8")


@pytest.mark.parametrize("engine", ["ocrmac", "easyocr"])
def test_scan_pdf_ocr_recovers_most_vietnamese_text(tmp_path, engine):
    result = convert(FIXTURES / "scan_vi.pdf", tmp_path, ocr="force", engine=engine)
    md = _read(result.markdown)
    hits = [p for p in PHRASES if p.lower() in md.lower()]
    print(f"\n{engine}: {len(hits)}/{len(PHRASES)} cụm từ, {result.seconds:.1f}s, "
          f"RAM tối đa {result.peak_rss_mb:.0f} MB")
    assert len(hits) >= 4, md
