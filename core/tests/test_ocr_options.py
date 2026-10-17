from docling.datamodel.pipeline_options import EasyOcrOptions, OcrMacOptions

from conftest import read_text, run_cli
from docconv.pdf_docling import OcrSettings, pipeline_options


def test_default_settings_use_ocrmac_vietnamese():
    opts = pipeline_options(OcrSettings(), force_ocr=False)
    assert opts.do_ocr and opts.do_table_structure
    assert isinstance(opts.ocr_options, OcrMacOptions)
    assert opts.ocr_options.lang == ["vi-VT", "en-US"]
    assert not opts.ocr_options.force_full_page_ocr


def test_easyocr_language_codes():
    opts = pipeline_options(OcrSettings(engine="easyocr", langs=("vi", "en")), force_ocr=True)
    assert isinstance(opts.ocr_options, EasyOcrOptions)
    assert opts.ocr_options.lang == ["vi", "en"]
    assert opts.ocr_options.force_full_page_ocr


def test_ocr_off_and_no_tables():
    opts = pipeline_options(OcrSettings(mode="off", tables=False), force_ocr=False)
    assert not opts.do_ocr
    assert not opts.do_table_structure


def test_force_mode_forces_ocr_even_for_text_pdf():
    opts = pipeline_options(OcrSettings(mode="force"), force_ocr=False)
    assert opts.ocr_options.force_full_page_ocr


def test_cli_flags_reach_conversion(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    proc = run_cli("convert", pdf, "--ocr", "off", "--no-tables")
    assert proc.returncode == 0, proc.stderr
    text = read_text(pdf.with_suffix(".md"))
    assert "Ninh Kiều" in text  # lớp text vẫn đọc được khi tắt OCR
    # Tắt nhận dạng cấu trúc bảng: bảng còn nhưng không tách thành từng ô.
    assert not any(line.startswith("| Xuân Khánh") for line in text.splitlines())


def test_cli_rejects_unknown_engine(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    try:
        run_cli("convert", pdf, "--ocr-engine", "tesseract")
    except SystemExit as e:
        assert e.code == 2
    else:
        raise AssertionError("phải báo lỗi tham số")
