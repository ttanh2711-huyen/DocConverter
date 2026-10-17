import pytest

from conftest import read_text, run_cli


@pytest.mark.parametrize("name, expected", [
    ("quyet_dinh.docx", ["Quyết định giao đất", "Trần Văn Lộc", "1.250,5"]),
    ("thong_ke.xlsx", ["| Phường", "Xuân Khánh", "98"]),
    ("ke_hoach.pptx", ["Kế hoạch sử dụng đất năm 2027", "Rà soát quỹ đất công"]),
    ("thong_bao.html", ["Thông báo lịch tiếp công dân", "Thứ Năm hằng tuần"]),
    ("danh_sach.csv", ["Lê Thị Hồng", "Phạm Quốc Việt"]),
])
def test_other_formats_to_md(copy_fixture, name, expected):
    src = copy_fixture(name)
    proc = run_cli("convert", src)
    assert proc.returncode == 0, proc.stderr
    text = read_text(src.with_suffix(".md"))
    for phrase in expected:
        assert phrase in text


def test_xlsx_becomes_markdown_table(copy_fixture):
    src = copy_fixture("thong_ke.xlsx")
    assert run_cli("convert", src).returncode == 0
    rows = [line for line in read_text(src.with_suffix(".md")).splitlines() if line.startswith("|")]
    assert any("Tân An" in r and "120" in r for r in rows)


def test_unsupported_format_fails_with_clear_message(copy_fixture):
    src = copy_fixture("cu.doc")
    proc = run_cli("convert", src)
    assert proc.returncode != 0
    assert "Không hỗ trợ định dạng .doc" in proc.stderr + proc.stdout
    assert not src.with_suffix(".md").exists()


def test_docx_output_requested_for_non_pdf_is_skipped_with_warning(copy_fixture):
    src = copy_fixture("quyet_dinh.docx")
    proc = run_cli("convert", src, "--to", "md,docx")
    assert proc.returncode == 0, proc.stderr
    assert src.with_suffix(".md").exists()
    assert not (src.parent / "quyet_dinh (1).docx").exists()
    assert "chỉ áp dụng cho PDF" in proc.stderr + proc.stdout
