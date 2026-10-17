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


def make_scan_pdf(src: Path, dst: Path, dpi: int = 200) -> None:
    """Raster hoá từng trang rồi ghép lại thành PDF chỉ có ảnh (không có lớp text)."""
    pdf = pdfium.PdfDocument(str(src))
    pages = [p.render(scale=dpi / 72).to_pil().convert("L") for p in pdf]
    pages[0].save(dst, save_all=True, append_images=pages[1:], resolution=dpi)


if __name__ == "__main__":
    FIXTURES.mkdir(exist_ok=True)
    make_text_pdf(FIXTURES / "text_vi.pdf")
    make_scan_pdf(FIXTURES / "text_vi.pdf", FIXTURES / "scan_vi.pdf")
    print("Đã tạo", *sorted(p.name for p in FIXTURES.glob("*.pdf")))
