"""Trích thông tin văn bản hành chính từ Markdown (dạng bảng của markitdown và dạng đoạn của Docling)."""

from docconv.metadata import DocMeta, canon, extract, lines_of

# Văn bản Word: phần đầu và phần ký nằm trong bảng; markitdown gộp các đoạn trong một ô.
QUYET_DINH_TABLE = """
| ỦY BAN NHÂN DÂN TỈNH CÀ MAU -------- | CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM Độc lập - Tự do - Hạnh phúc --------------- |
| --- | --- |
| Số: 1234/QĐ-UBND | *Cà Mau, ngày 15 tháng 3 năm 2026* |

**QUYẾT ĐỊNH**

**Về việc phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời**

**CHỦ TỊCH ỦY BAN NHÂN DÂN TỈNH CÀ MAU**

*Căn cứ Luật Tổ chức chính quyền địa phương ngày 19 tháng 02 năm 2025;*

**QUYẾT ĐỊNH:**

**Điều 1.** Phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời.

| ***Nơi nhận:*** - Như Điều 3; - Lưu: VT, NC. | **KT. CHỦ TỊCH PHÓ CHỦ TỊCH** *(Đã ký)* **Nguyễn Văn Bình** |
| --- | --- |
"""

# PDF qua Docling: mỗi đoạn một dòng, tiêu đề có dấu "#".
CONG_VAN_DOCLING = """
ỦY BAN NHÂN DÂN

TỈNH CÀ MAU

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Số: 45/UBND-KT

V/v triển khai thực hiện chuyển đổi số năm 2026

Cà Mau, ngày 02 tháng 10 năm 2026

Kính gửi: Các sở, ban, ngành tỉnh.

Ủy ban nhân dân tỉnh đề nghị các đơn vị triển khai thực hiện.

Nơi nhận:

- Như trên;
- Lưu: VT.

KT. CHỦ TỊCH

PHÓ CHỦ TỊCH

<!-- image -->

Lê Thị Hoa
"""

NGHI_DINH = """
## CHÍNH PHỦ

Số: 123/2024/NĐ-CP

## CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Hà Nội, ngày 20 tháng 9 năm 2024

## NGHỊ ĐỊNH

Quy định chi tiết một số điều của Luật Đất đai

Căn cứ Luật Tổ chức Chính phủ ngày 19 tháng 6 năm 2015;

Theo đề nghị của Bộ trưởng Bộ Tài nguyên và Môi trường;

TM. CHÍNH PHỦ

KT. THỦ TƯỚNG

PHÓ THỦ TƯỚNG

Trần Hồng Hà
"""

SO_SUB_AGENCY = """
UBND TỈNH CÀ MAU

SỞ NÔNG NGHIỆP VÀ MÔI TRƯỜNG

Số: 08/KH-SNNMT

Cà Mau, ngày 5/1/2026

KẾ HOẠCH

Kiểm tra công tác quản lý đất đai năm 2026

GIÁM ĐỐC

Phạm Minh Tuấn
"""


def test_decision_in_word_tables():
    m = extract(QUYET_DINH_TABLE)
    assert m.doc_type == "Quyết định"
    assert m.number == "1234/QĐ-UBND"
    assert m.date == "2026-03-15"
    assert m.issuer == "ỦY BAN NHÂN DÂN TỈNH CÀ MAU"
    assert m.signer == "Nguyễn Văn Bình"
    assert m.position == "KT. CHỦ TỊCH, PHÓ CHỦ TỊCH"
    assert m.summary.startswith("Về việc phê duyệt Kế hoạch") or m.summary.startswith("phê duyệt Kế hoạch")


def test_official_letter_from_docling():
    m = extract(CONG_VAN_DOCLING)
    assert m.doc_type == "Công văn"
    assert m.number == "45/UBND-KT"
    assert m.date == "2026-10-02"
    assert m.issuer == "ỦY BAN NHÂN DÂN TỈNH CÀ MAU"
    assert (m.signer, m.position) == ("Lê Thị Hoa", "KT. CHỦ TỊCH, PHÓ CHỦ TỊCH")
    assert m.summary == "triển khai thực hiện chuyển đổi số năm 2026"


def test_decree_with_collective_signature():
    m = extract(NGHI_DINH)
    assert (m.doc_type, m.number, m.date, m.issuer) == ("Nghị định", "123/2024/NĐ-CP", "2024-09-20", "CHÍNH PHỦ")
    assert (m.signer, m.position) == ("Trần Hồng Hà", "KT. THỦ TƯỚNG, PHÓ THỦ TƯỚNG")
    assert m.summary == "Quy định chi tiết một số điều của Luật Đất đai"


def test_sub_agency_and_slash_date():
    m = extract(SO_SUB_AGENCY)
    assert (m.doc_type, m.number, m.date) == ("Kế hoạch", "08/KH-SNNMT", "2026-01-05")
    assert m.issuer == "SỞ NÔNG NGHIỆP VÀ MÔI TRƯỜNG"
    assert (m.signer, m.position) == ("Phạm Minh Tuấn", "GIÁM ĐỐC")
    assert m.summary == "Kiểm tra công tác quản lý đất đai năm 2026"


def test_type_from_number_code_when_title_missing():
    m = extract("UBND HUYỆN U MINH\n\nSố: 17/TB-UBND\n\nU Minh, ngày 01 tháng 02 năm 2026\n\nNội dung.")
    assert (m.doc_type, m.issuer, m.date) == ("Thông báo", "UBND HUYỆN U MINH", "2026-02-01")


def test_non_administrative_text_is_not_a_document():
    m = extract("| Phường | Số hồ sơ |\n| --- | --- |\n| Tân An | 120 |\n| Xuân Khánh | 98 |")
    assert m == DocMeta()
    assert not m.is_document
    assert extract(QUYET_DINH_TABLE).is_document


def test_invalid_date_is_ignored():
    assert extract("Số: 1/QĐ-UBND\n\nCà Mau, ngày 31 tháng 2 năm 2026").date == ""


def test_canon_unifies_old_and_new_tone_marks():
    assert canon("UỶ BAN  NHÂN DÂN") == canon("ỦY BAN NHÂN DÂN")
    assert canon("CỘNG HOÀ") == canon("Cộng hòa")


def test_lines_split_table_cells_and_strip_markup():
    assert lines_of("| **A** | *B* |\n| --- | --- |\n## C\n- D;") == ["A", "B", "C", "D;"]


def test_subject_line_sharing_cell_with_number():
    m = extract("| Số: 2468/UBND-KT V/v rà soát quỹ đất công năm 2027 | Cần Thơ, ngày 09 tháng 10 năm 2026 |")
    assert (m.number, m.summary, m.doc_type) == ("2468/UBND-KT", "rà soát quỹ đất công năm 2027", "Công văn")


# Đầu ra thật của Docling cho một PDF hai cột: tên loại và trích yếu chung dòng,
# khối "Nơi nhận" nằm xen giữa chức vụ và họ tên.
DOCLING_REAL = """
## ỦY BAN NHÂN DÂN TỈNH CÀ MAU

## CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM Độc lập - Tự do - Hạnh phúc

Số: 1234/QĐ-UBND

Cà Mau, ngày 15 tháng 3 năm 2026

## QUYẾT ĐỊNH Về việc phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời

## CHỦ TỊCH ỦY BAN NHÂN DÂN TỈNH CÀ MAU

Căn cứ Luật Tổ chức chính quyền địa phương ngày 19 tháng 02 năm 2025;

## QUYẾT ĐỊNH:

Điều 1. Phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời.

## Nơi nhận:

KT. CHỦ TỊCH PHÓ CHỦ TỊCH

- Như Điều 2;

- Lưu: VT, NC.

Nguyễn Văn Bình
"""


def test_docling_two_column_pdf():
    m = extract(DOCLING_REAL)
    assert (m.doc_type, m.number, m.date) == ("Quyết định", "1234/QĐ-UBND", "2026-03-15")
    assert m.issuer == "ỦY BAN NHÂN DÂN TỈNH CÀ MAU"
    assert m.summary == "Về việc phê duyệt Kế hoạch sử dụng đất năm 2026 của huyện Trần Văn Thời"
    assert (m.signer, m.position) == ("Nguyễn Văn Bình", "KT. CHỦ TỊCH, PHÓ CHỦ TỊCH")
