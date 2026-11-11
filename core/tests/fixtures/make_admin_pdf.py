"""Tạo PDF quyết định hai cột (phần đầu và phần ký) cho test trích thông tin:
    uv run python tests/fixtures/make_admin_pdf.py tests/fixtures/quyet_dinh_2cot.pdf
    uv run python tests/fixtures/make_admin_pdf.py tests/fixtures/quyet_dinh_ky_so.pdf --ky-so

--ky-so mô phỏng văn bản điện tử ký bằng VGCA: trang để trống số, ngày, tháng và tên người ký; văn thư điền
số, ngày, tháng bằng hình hiển thị của các chữ ký số (của cơ quan) đặt đúng vào chỗ trống; lãnh đạo ký số
bằng chữ ký riêng. Lý do ký có dạng "<Tên><email> đã ký lên văn bản này!".
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
W, H = A4
L, Rc = 150, 400  # tâm cột trái, cột phải
SIGNED = "--ky-so" in sys.argv
NUMBER_LINE = "Số:          /QĐ-UBND" if SIGNED else "Số: 1234/QĐ-UBND"
DATE_PARTS = ["Cà Mau, ngày", "      ", "tháng", "      ", "năm 2026"]
blanks: dict[str, tuple[float, float, float]] = {}  # tên → (x trái, x phải, y)

c = canvas.Canvas(sys.argv[1], pagesize=A4)


def t(x, y, s, f="T", size=13, center=True):
    c.setFont(f, size)
    (c.drawCentredString if center else c.drawString)(x, y, s)


y = H - 60
t(L, y, "ỦY BAN NHÂN DÂN", "TB"); t(Rc, y, "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", "TB", 12)
y -= 16
t(L, y, "TỈNH CÀ MAU", "TB"); t(Rc, y, "Độc lập - Tự do - Hạnh phúc", "TB")
y -= 30
t(L, y, NUMBER_LINE)
if SIGNED:
    left = L - pdfmetrics.stringWidth(NUMBER_LINE, "T", 13) / 2
    start = left + pdfmetrics.stringWidth("Số: ", "T", 13)
    blanks["số"] = (start, start + pdfmetrics.stringWidth("         ", "T", 13), y)
    x = Rc - pdfmetrics.stringWidth("".join(DATE_PARTS) + "    ", "TI", 13) / 2
    for i, part in enumerate(DATE_PARTS):
        width = pdfmetrics.stringWidth(part + " ", "TI", 13)
        if part.strip():
            t(x, y, part, "TI", center=False)
        else:
            blanks["ngày" if i == 1 else "tháng"] = (x, x + width, y)
        x += width
else:
    t(Rc, y, "Cà Mau, ngày 15 tháng 3 năm 2026", "TI")
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
y -= 60
if not SIGNED:
    t(Rc, y, "Nguyễn Văn Bình", "TB")
c.save()


def sign(path: str) -> None:
    """Thêm các chữ ký số mô phỏng (không có chữ ký mật mã thật, chỉ đủ cấu trúc để đọc)."""
    import pymupdf

    doc = pymupdf.open(path)
    page = doc[0]

    def text_string(s: str) -> str:
        return "<FEFF" + s.encode("utf-16-be").hex().upper() + ">"

    fields: list[int] = []

    def add(name: str, signer: str, when: str, rect=None, text: str = "") -> None:
        v = doc.get_new_xref()
        doc.update_object(v, f"<</Type/Sig/Filter/Adobe.PPKLite/SubFilter/adbe.pkcs7.detached/M(D:{when}+07'00')"
                             f"/Reason {text_string(signer + ' đã ký lên văn bản này!')}"
                             f"/Location {text_string('ỦY BAN NHÂN DÂN TỈNH CÀ MAU')}/Contents<00>/ByteRange[0 0 0 0]>>")
        x0, x1, base = rect or (0, 0, 0)
        rect_text = f"[{x0:.1f} {base - 4:.1f} {x1:.1f} {base + 12:.1f}]"
        ap = ""
        if text:
            form = doc.get_new_xref()
            doc.update_object(form, f"<</Type/XObject/Subtype/Form/BBox[0 0 {x1 - x0:.1f} 16]"
                                    "/Resources<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Times-Roman"
                                    "/Encoding/WinAnsiEncoding>>>>>>>>")
            doc.update_stream(form, f"BT /F1 13 Tf 4 4 Td ({text}) Tj ET".encode())
            ap = f"/AP<</N {form} 0 R>>"
        w = doc.get_new_xref()
        doc.update_object(w, f"<</Type/Annot/Subtype/Widget/FT/Sig/T({name})/F 132/Rect {rect_text}"
                             f"/P {page.xref} 0 R/V {v} 0 R{ap}>>")
        fields.append(w)

    org = "ỦY BAN NHÂN DÂN TỈNH CÀ MAU<vpubnd@camau.gov.vn>"
    add("Signature1", "Nguyễn Văn Bình<nvbinh@camau.gov.vn>", "20260315083619")
    add("Signature2", org, "20260315095349", blanks["số"], "1234")
    add("Signature3", org, "20260315095355", blanks["ngày"], "15")
    add("Signature4", org, "20260315095401", blanks["tháng"], "3")
    refs = " ".join(f"{x} 0 R" for x in fields)
    doc.xref_set_key(page.xref, "Annots", f"[{refs}]")
    doc.xref_set_key(doc.pdf_catalog(), "AcroForm", f"<</Fields[{refs}]/SigFlags 3>>")
    doc.save(path, incremental=True, encryption=0)


if SIGNED:
    sign(sys.argv[1])
