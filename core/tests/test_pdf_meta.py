"""Đọc chữ theo bố cục trang và thông tin chữ ký số trong PDF."""

from docconv.metadata import DocMeta, with_signatures
from docconv.pdf_meta import Signature, _name_from_reason, _page_lines, cert_signer, pdf_date


def test_pdf_date():
    assert pdf_date("D:20260324085349+07'00'") == "2026-03-24T08:53:49+07:00"
    assert pdf_date("D:20260324085349Z") == "2026-03-24T08:53:49Z"
    assert pdf_date("") == ""


def test_name_from_vgca_reason():
    assert _name_from_reason("Trần Chí Hùng<tranchihung@cantho.gov.vn> đã ký lên văn bản này!") == "Trần Chí Hùng"
    assert _name_from_reason("Kèm theo văn bản số 1157/QĐ-UBND của ỦY BAN NHÂN DÂN") == ""


def test_words_inserted_later_join_their_line():
    """Số do chữ ký số vẽ thêm (cuối luồng nội dung, lệch vài điểm) vẫn về đúng dòng và đúng chỗ."""
    words = [
        (107, 93, 124, 108, "Số:"), (160, 93, 214, 108, "/QĐ-UBND"),
        (300, 93, 340, 108, "Cần"), (342, 93, 363, 108, "Thơ,"), (365, 93, 390, 108, "ngày"),
        (420, 93, 450, 108, "tháng"), (470, 93, 520, 108, "năm"), (522, 93, 548, 108, "2026"),
        (126, 91, 158, 109, "1157"), (392, 91, 410, 109, "24"), (452, 91, 462, 109, "3"),
    ]
    assert _page_lines(words) == ["Số: 1157 /QĐ-UBND", "Cần Thơ, ngày 24 tháng 3 năm 2026"]


def _der(tag: int, body: bytes) -> bytes:
    n = len(body)
    length = bytes([n]) if n < 0x80 else bytes([0x80 | ((n.bit_length() + 7) // 8)]) + n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([tag]) + length + body


def _name(cn: str) -> bytes:
    attr = _der(0x30, _der(0x06, bytes.fromhex("550403")) + _der(0x0C, cn.encode()))
    return _der(0x30, _der(0x31, attr))


def _cert(serial: int, issuer: str, subject: str) -> bytes:
    alg = _der(0x30, _der(0x06, bytes.fromhex("2a864886f70d01010b")))
    validity = _der(0x30, _der(0x17, b"260101000000Z") + _der(0x17, b"270101000000Z"))
    tbs = _der(0x30, _der(0xA0, _der(0x02, b"\x02")) + _der(0x02, bytes([serial])) + alg + _name(issuer)
               + validity + _name(subject))
    return _der(0x30, tbs + alg + _der(0x03, b"\x00"))


def test_signer_name_from_certificate():
    """Khi tệp không ghi lý do ký: đọc tên từ chứng thư của người ký (khớp số sê-ri trong SignerInfo)."""
    ca = _cert(1, "Cục Chứng thực số", "Cục Chứng thực số")
    leaf = _cert(7, "Cục Chứng thực số", "Lê Thị Hoa")
    signer_info = _der(0x30, _der(0x02, b"\x01") + _der(0x30, _name("Cục Chứng thực số") + _der(0x02, b"\x07")))
    signed = _der(0x30, _der(0x02, b"\x01") + _der(0x31, b"") + _der(0x30, _der(0x06, bytes.fromhex("2a864886f70d010701")))
                  + _der(0xA0, ca + leaf) + _der(0x31, signer_info))
    cms = _der(0x30, _der(0x06, bytes.fromhex("2a864886f70d010702")) + _der(0xA0, signed)) + b"\x00" * 64
    assert cert_signer(cms) == "Lê Thị Hoa"
    assert cert_signer(b"\x00\x00garbage") == ""


def test_signature_fallbacks():
    sigs = [Signature("Võ Hoài Hận", "2026-03-23T15:59:16+07:00"), Signature("Trần Chí Hùng", "2026-03-24T08:36:19+07:00"),
            Signature("ỦY BAN NHÂN DÂN THÀNH PHỐ CẦN THƠ", "2026-03-24T08:53:49+07:00"),
            Signature("ỦY BAN NHÂN DÂN THÀNH PHỐ CẦN THƠ", "2026-03-24T08:53:55+07:00")]
    m = with_signatures(DocMeta(number="1157/QĐ-UBND"), sigs)
    assert (m.signer, m.issuer, m.date, m.date_source) == ("Trần Chí Hùng", "ỦY BAN NHÂN DÂN THÀNH PHỐ CẦN THƠ",
                                                          "2026-03-24", "ký số")
    assert len(m.signatures) == 3
    kept = with_signatures(DocMeta(date="2026-03-20", signer="Nguyễn A"), sigs)
    assert (kept.date, kept.date_source, kept.signer) == ("2026-03-20", "", "Nguyễn A")
