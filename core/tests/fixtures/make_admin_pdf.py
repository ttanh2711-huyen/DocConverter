"""Tạo PDF quyết định hai cột (phần đầu và phần ký) cho test trích thông tin:
    uv run python tests/fixtures/make_admin_pdf.py tests/fixtures/quyet_dinh_2cot.pdf
"""

import sys
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

F = "/System/Library/Fonts/Supplemental/"
pdfmetrics.registerFont(TTFont("T", F + "Times New Roman.ttf"))
pdfmetrics.registerFont(TTFont("TB", F + "Times New Roman Bold.ttf"))
pdfmetrics.registerFont(TTFont("TI", F + "Times New Roman Italic.ttf"))
c = canvas.Canvas(sys.argv[1], pagesize=A4)
W, H = A4
L, Rc = 150, 400  # tâm cột trái, cột phải
def t(x, y, s, f="T", size=13, center=True):
    c.setFont(f, size)
    (c.drawCentredString if center else c.drawString)(x, y, s)
y = H - 60
t(L, y, "ỦY BAN NHÂN DÂN", "TB"); t(Rc, y, "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", "TB", 12)
y -= 16
t(L, y, "TỈNH CÀ MAU", "TB"); t(Rc, y, "Độc lập - Tự do - Hạnh phúc", "TB")
y -= 30
t(L, y, "Số: 1234/QĐ-UBND"); t(Rc, y, "Cà Mau, ngày 15 tháng 3 năm 2026", "TI")
y -= 50
t(W / 2, y, "QUYẾT ĐỊNH", "TB", 14); y -= 18
t(W / 2, y, "Về việc phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời", "TB"); y -= 30
t(W / 2, y, "CHỦ TỊCH ỦY BAN NHÂN DÂN TỈNH CÀ MAU", "TB"); y -= 30
for line in ["Căn cứ Luật Tổ chức chính quyền địa phương ngày 19 tháng 02 năm 2025;",
             "Theo đề nghị của Giám đốc Sở Nông nghiệp và Môi trường."]:
    t(70, y, line, "TI", center=False); y -= 18
y -= 10; t(W / 2, y, "QUYẾT ĐỊNH:", "TB"); y -= 26
for line in ["Điều 1. Phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời.",
             "Điều 2. Quyết định này có hiệu lực kể từ ngày ký."]:
    t(70, y, line, center=False); y -= 18
y -= 30
t(70, y, "Nơi nhận:", "TB", 12, center=False); t(Rc, y, "KT. CHỦ TỊCH", "TB")
y -= 15; t(70, y, "- Như Điều 2;", "T", 11, center=False); t(Rc, y, "PHÓ CHỦ TỊCH", "TB")
y -= 15; t(70, y, "- Lưu: VT, NC.", "T", 11, center=False)
y -= 60; t(Rc, y, "Nguyễn Văn Bình", "TB")
c.save()
