from urllib.parse import quote

from conftest import read_text, run_cli

PHRASES = [
    "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM",
    "Báo cáo kết quả kiểm tra hồ sơ đất đai",
    "Ủy ban nhân dân quận Ninh Kiều",
    "chuyển nhượng một phần thửa đất",
]


def test_pdf_to_md_beside_source(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    proc = run_cli("convert", pdf, "--to", "md")
    assert proc.returncode == 0, proc.stderr

    md = pdf.with_suffix(".md")
    text = read_text(md)
    for phrase in PHRASES:
        assert phrase in text
    assert any(line.startswith("#") and "Báo cáo" in line for line in text.splitlines())
    assert any(line.startswith("|") and "Xuân Khánh" in line for line in text.splitlines())

    assets = pdf.parent / "text_vi_assets"
    images = list(assets.glob("*.png"))
    assert images and f"text_vi_assets/{images[0].name}" in text


def test_existing_output_is_not_overwritten(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    existing = pdf.with_suffix(".md")
    existing.write_text("giữ nguyên", encoding="utf-8")

    proc = run_cli("convert", pdf, "--to", "md")
    assert proc.returncode == 0, proc.stderr
    assert existing.read_text(encoding="utf-8") == "giữ nguyên"
    renamed = pdf.parent / "text_vi (1).md"
    assert "Ninh Kiều" in read_text(renamed)
    assert quote("text_vi (1)_assets/") in read_text(renamed)  # Docling mã hoá URL liên kết ảnh


def test_overwrite_flag_replaces_output(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    pdf.with_suffix(".md").write_text("cũ", encoding="utf-8")
    proc = run_cli("convert", pdf, "--to", "md", "--overwrite")
    assert proc.returncode == 0, proc.stderr
    assert "Ninh Kiều" in read_text(pdf.with_suffix(".md"))
    assert not (pdf.parent / "text_vi (1).md").exists()
