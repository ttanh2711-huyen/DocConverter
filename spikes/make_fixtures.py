"""Tạo PDF mẫu tiếng Việt cho spike: một bản có lớp text và một bản scan (chỉ ảnh)."""

from pathlib import Path

import pypdfium2 as pdfium
from PIL import Image, ImageDraw
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image as RLImage
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

FIXTURES = Path(__file__).parent / "fixtures"
FONT_DIR = Path("/System/Library/Fonts/Supplemental")


def _styles():
    pdfmetrics.registerFont(TTFont("TNR", str(FONT_DIR / "Times New Roman.ttf")))
    pdfmetrics.registerFont(TTFont("TNR-B", str(FONT_DIR / "Times New Roman Bold.ttf")))
    pdfmetrics.registerFont(TTFont("TNR-I", str(FONT_DIR / "Times New Roman Italic.ttf")))
    pdfmetrics.registerFont(TTFont("TNR-BI", str(FONT_DIR / "Times New Roman Bold Italic.ttf")))
    pdfmetrics.registerFontFamily("TNR", normal="TNR", bold="TNR-B", italic="TNR-I", boldItalic="TNR-BI")
    pdfmetrics.registerFontFamily("TNR-B", normal="TNR-B", bold="TNR-B", italic="TNR-BI", boldItalic="TNR-BI")
    body = ParagraphStyle("body", fontName="TNR", fontSize=13, leading=18)
    return {
        "center": ParagraphStyle("center", parent=body, fontName="TNR-B", alignment=1),
        "h1": ParagraphStyle("h1", parent=body, fontName="TNR-B", fontSize=18, leading=24, spaceAfter=8),
        "h2": ParagraphStyle("h2", parent=body, fontName="TNR-B", fontSize=15, leading=20, spaceBefore=8),
        "body": body,
    }


def _chart_png(path: Path) -> None:
    img = Image.new("RGB", (600, 360), "white")
    d = ImageDraw.Draw(img)
    for i, (h, c) in enumerate([(220, "#c0392b"), (180, "#2980b9"), (290, "#27ae60")]):
        x = 80 + i * 170
        d.rectangle([x, 330 - h, x + 110, 330], fill=c)
    d.line([40, 330, 580, 330], fill="black", width=3)
    d.line([40, 20, 40, 330], fill="black", width=3)
    img.save(path)


def make_text_pdf(path: Path) -> None:
    s = _styles()
    chart = FIXTURES / "chart.png"
    _chart_png(chart)
    table = Table(
        [["Phường", "Số hồ sơ", "Đã giải quyết"],
         ["Tân An", "120", "115"],
         ["Xuân Khánh", "98", "90"],
         ["Hưng Lợi", "143", "137"]],
        colWidths=[160, 120, 140],
    )
    table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), "TNR"),
        ("FONTNAME", (0, 0), (-1, 0), "TNR-B"),
        ("FONTSIZE", (0, 0), (-1, -1), 12),
        ("GRID", (0, 0), (-1, -1), 0.8, colors.black),
    ]))
    story = [
        Paragraph("CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", s["center"]),
        Paragraph("Độc lập - Tự do - Hạnh phúc", s["center"]),
        Spacer(1, 16),
        Paragraph("Báo cáo kết quả kiểm tra hồ sơ đất đai", s["h1"]),
        Paragraph("Căn cứ Luật Đất đai năm 2024, Ủy ban nhân dân quận Ninh Kiều báo cáo kết quả "
                  "kiểm tra việc cấp Giấy chứng nhận quyền sử dụng đất như sau.", s["body"]),
        Paragraph("1. Tổng hợp số liệu", s["h2"]),
        Spacer(1, 6),
        table,
        Spacer(1, 12),
        RLImage(str(chart), width=300, height=180),
        Paragraph("2. Kiến nghị", s["h2"]),
        Paragraph("Đề nghị Sở Nông nghiệp và Môi trường hướng dẫn thủ tục đăng ký biến động đối với "
                  "trường hợp chuyển nhượng một phần thửa đất.", s["body"]),
    ]
    SimpleDocTemplate(str(path), pagesize=A4).build(story)


def _stamp_png(path: Path) -> None:
    img = Image.new("RGBA", (400, 400), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 10, 390, 390], outline=(200, 0, 0, 255), width=14)
    d.ellipse([70, 70, 330, 330], outline=(200, 0, 0, 255), width=6)
    d.polygon([(200, 120), (225, 185), (295, 185), (240, 225), (260, 290),
               (200, 250), (140, 290), (160, 225), (105, 185), (175, 185)], fill=(200, 0, 0, 255))
    img.save(path)


def make_layout_pdf(path: Path) -> None:
    """Văn bản hành chính 2 trang: header 2 bên, bảng gộp ô, con dấu, trang 2 chia 2 cột."""
    from reportlab.platypus import BaseDocTemplate, Frame, FrameBreak, NextPageTemplate, PageBreak, PageTemplate

    s = _styles()
    small_c = ParagraphStyle("sc", parent=s["body"], fontSize=12, leading=15, alignment=1)
    small_cb = ParagraphStyle("scb", parent=small_c, fontName="TNR-B")
    right = ParagraphStyle("r", parent=s["body"], alignment=2, fontName="TNR")
    justify = ParagraphStyle("j", parent=s["body"], alignment=4)
    stamp = FIXTURES / "stamp.png"
    _stamp_png(stamp)

    W, H = A4
    margin_l, margin_r, margin_t, margin_b = 85, 57, 57, 57  # ~3 cm trái, 2 cm còn lại
    body_w = W - margin_l - margin_r
    one = Frame(margin_l, margin_b, body_w, H - margin_t - margin_b, id="one")
    gap = 18
    col_w = (body_w - gap) / 2
    left = Frame(margin_l, margin_b, col_w, H - margin_t - margin_b, id="l")
    rightf = Frame(margin_l + col_w + gap, margin_b, col_w, H - margin_t - margin_b, id="r")
    doc = BaseDocTemplate(str(path), pagesize=A4, leftMargin=margin_l, rightMargin=margin_r,
                          topMargin=margin_t, bottomMargin=margin_b)
    doc.addPageTemplates([PageTemplate("one", [one]), PageTemplate("two", [left, rightf])])

    header = Table([
        [Paragraph("ỦY BAN NHÂN DÂN<br/>QUẬN NINH KIỀU", small_cb),
         Paragraph("CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM<br/>Độc lập - Tự do - Hạnh phúc", small_cb)],
        [Paragraph("Số: 125/BC-UBND", small_c),
         Paragraph("<i>Ninh Kiều, ngày 15 tháng 10 năm 2026</i>", small_c)],
    ], colWidths=[body_w * 0.4, body_w * 0.6])
    header.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))

    merged = Table([
        ["STT", "Loại hồ sơ", "Năm 2025", "", "Năm 2026", ""],
        ["", "", "Tiếp nhận", "Giải quyết", "Tiếp nhận", "Giải quyết"],
        ["1", "Cấp Giấy chứng nhận lần đầu", "312", "298", "287", "270"],
        ["2", "Đăng ký biến động", "540", "533", "611", "590"],
        ["3", "Chuyển mục đích sử dụng đất", "76", "70", "82", "75"],
        ["", "Tổng cộng", "928", "901", "980", "935"],
    ], colWidths=[30, 150, 63, 63, 63, 63])
    merged.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), "TNR"),
        ("FONTNAME", (0, 0), (-1, 1), "TNR-B"),
        ("FONTNAME", (0, 5), (-1, 5), "TNR-B"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("GRID", (0, 0), (-1, -1), 0.8, colors.black),
        ("SPAN", (0, 0), (0, 1)), ("SPAN", (1, 0), (1, 1)),
        ("SPAN", (2, 0), (3, 0)), ("SPAN", (4, 0), (5, 0)),
        ("ALIGN", (2, 0), (-1, -1), "CENTER"), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))

    signature = Table([[
        "",
        [Paragraph("TM. ỦY BAN NHÂN DÂN<br/>CHỦ TỊCH", small_cb),
         RLImage(str(stamp), width=90, height=90),
         Paragraph("Nguyễn Văn Bình", small_cb)],
    ]], colWidths=[body_w * 0.5, body_w * 0.5])

    col_text = ("Trong kỳ báo cáo, Ủy ban nhân dân quận đã chỉ đạo Văn phòng đăng ký đất đai "
                "chi nhánh Ninh Kiều rà soát toàn bộ hồ sơ tồn đọng, phân loại theo nguyên nhân "
                "và xác định thời hạn giải quyết cụ thể cho từng trường hợp. ")
    story = [
        header, Spacer(1, 18),
        Paragraph("BÁO CÁO", ParagraphStyle("t", parent=s["h1"], alignment=1, spaceAfter=2)),
        Paragraph("Tình hình giải quyết thủ tục hành chính về đất đai", small_cb),
        Spacer(1, 12),
        Paragraph("Thực hiện Kế hoạch số 45/KH-UBND, Ủy ban nhân dân quận Ninh Kiều báo cáo tình hình "
                  "giải quyết thủ tục hành chính trong lĩnh vực đất đai như sau:", justify),
        Paragraph("I. KẾT QUẢ THỰC HIỆN", s["h2"]), Spacer(1, 6),
        merged, Spacer(1, 12),
        Paragraph("II. ĐÁNH GIÁ CHUNG", s["h2"]),
        Paragraph("Tỷ lệ hồ sơ giải quyết đúng hạn đạt 95,4%, tăng 2,3% so với cùng kỳ.", justify),
        Spacer(1, 12), signature,
        NextPageTemplate("two"), PageBreak(),
        Paragraph("III. NGUYÊN NHÂN VÀ GIẢI PHÁP", s["h2"]),
        Paragraph(col_text * 4, justify),
        FrameBreak(),
        Paragraph("IV. KIẾN NGHỊ", s["h2"]),
        Paragraph("Đề nghị Sở Nông nghiệp và Môi trường bố trí thêm nhân lực đo đạc, đồng thời "
                  "hướng dẫn thống nhất cách xác định ranh giới thửa đất khi tách thửa. " * 3, justify),
    ]
    doc.build(story)


def make_scan_pdf(src: Path, dst: Path, dpi: int = 200) -> None:
    """Raster hoá từng trang rồi ghép lại thành PDF chỉ có ảnh (không có lớp text)."""
    pdf = pdfium.PdfDocument(str(src))
    pages = [p.render(scale=dpi / 72).to_pil().convert("L") for p in pdf]
    pages[0].save(dst, save_all=True, append_images=pages[1:], resolution=dpi)


if __name__ == "__main__":
    FIXTURES.mkdir(exist_ok=True)
    make_text_pdf(FIXTURES / "text_vi.pdf")
    make_scan_pdf(FIXTURES / "text_vi.pdf", FIXTURES / "scan_vi.pdf")
    make_layout_pdf(FIXTURES / "layout_vi.pdf")
    make_scan_pdf(FIXTURES / "layout_vi.pdf", FIXTURES / "layout_scan_vi.pdf")
    print("Đã tạo", *sorted(p.name for p in FIXTURES.glob("*.pdf")))
