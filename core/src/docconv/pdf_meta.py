"""Đọc PDF cho sổ tổng hợp: chữ theo bố cục trang và thông tin chữ ký số.

Văn bản điện tử ký số (ví dụ ký bằng VGCA) thường để trống số và ngày trên trang ("Số:      /QĐ-UBND",
"ngày   tháng   năm 2026"); văn thư điền số, ngày, tháng bằng hình hiển thị của chữ ký số đặt đúng vào chỗ
trống. Vì vậy phải "dàn phẳng" các chữ ký vào trang rồi xếp chữ theo vị trí, không theo thứ tự trong tệp.
"""

import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Signature:
    name: str
    time: str  # ISO 8601, ví dụ 2026-03-24T08:53:49+07:00; rỗng nếu không có


def layout_text(pdf: Path, edge_pages: int = 2) -> str:
    """Chữ của các trang đầu và cuối (kể cả chữ do chữ ký số và chú thích vẽ lên), xếp theo vị trí:
    gom thành dòng theo độ cao, trong dòng xếp trái → phải, cụm cách xa (hai cột) tách thành dòng riêng."""
    import pymupdf

    doc = pymupdf.open(str(pdf))
    try:
        doc.bake()  # chỉ trong bộ nhớ, không ghi lại tệp
    except Exception:
        pass
    n = len(doc)
    pages = sorted(set(range(min(edge_pages, n))) | set(range(max(n - edge_pages, 0), n)))
    out: list[str] = []
    for index in pages:
        out += _page_lines(doc[index].get_text("words"))
    return "\n".join(out)


def _page_lines(words: list) -> list[str]:
    lines: list[dict] = []
    for x0, y0, x1, y1, text, *_ in sorted(words, key=lambda w: (w[1] + w[3]) / 2):
        center, height = (y0 + y1) / 2, max(y1 - y0, 1.0)
        for line in lines[-3:]:
            if abs(center - line["center"]) <= max(height, line["height"]) * 0.5:
                line["words"].append((x0, x1, text))
                break
        else:
            lines.append({"center": center, "height": height, "words": [(x0, x1, text)]})
    out: list[str] = []
    for line in sorted(lines, key=lambda l: l["center"]):
        segment, prev_right = [], None
        for x0, x1, text in sorted(line["words"]):
            if prev_right is not None and x0 - prev_right > max(2.5 * line["height"], 25):
                out.append(" ".join(segment))
                segment = []
            segment.append(text)
            prev_right = x1
        if segment:
            out.append(" ".join(segment))
    return out


# MARK: - Chữ ký số

def signatures(pdf: Path) -> list[Signature]:
    """Các chữ ký số trong tệp (chưa kiểm tra tính hợp lệ), theo thời điểm ký."""
    import pymupdf

    doc = pymupdf.open(str(pdf))
    found: list[Signature] = []
    for xref in range(1, doc.xref_length()):
        try:
            if doc.xref_get_key(xref, "FT")[1] != "/Sig":
                continue
            kind, value = doc.xref_get_key(xref, "V")
        except Exception:
            continue
        if kind != "xref":
            continue
        v = int(value.split()[0])
        name = _pdf_string(doc.xref_get_key(v, "Name")) or _name_from_reason(_pdf_string(doc.xref_get_key(v, "Reason")))
        if not name:
            name = cert_signer(_hex_bytes(doc.xref_get_key(v, "Contents")))
        if name:
            found.append(Signature(name=name, time=pdf_date(_pdf_string(doc.xref_get_key(v, "M")))))
    return sorted(found, key=lambda s: s.time or "~")


def _pdf_string(entry: tuple) -> str:
    kind, value = entry
    return value.strip() if kind == "string" else ""


def _hex_bytes(entry: tuple) -> bytes:
    kind, value = entry
    if kind != "string":
        return b""
    value = value.strip()
    try:
        return bytes.fromhex(value.strip("<>"))
    except ValueError:
        return value.encode("latin-1", "ignore")


def _name_from_reason(reason: str) -> str:
    """VGCA ghi lý do ký dạng "Trần Chí Hùng<hung@cantho.gov.vn> đã ký lên văn bản này!"."""
    m = re.match(r"\s*([^<>]{3,120}?)\s*<[^>]*>\s*đã ký", reason)
    return m.group(1).strip() if m else ""


def pdf_date(value: str) -> str:
    """"D:20260324085349+07'00'" → "2026-03-24T08:53:49+07:00"."""
    m = re.match(r"D?:?(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?([Zz]|[+-]\d{2}'?\d{2}'?)?", value or "")
    if not m:
        return ""
    y, mo, d, h, mi, s, tz = m.groups()
    out = f"{y}-{mo or '01'}-{d or '01'}T{h or '00'}:{mi or '00'}:{s or '00'}"
    if tz and tz not in "Zz":
        digits = tz.replace("'", "")
        out += f"{digits[:3]}:{digits[3:5]}"
    elif tz:
        out += "Z"
    return out


# MARK: - Đọc tên người ký từ chứng thư (PKCS#7/CMS) khi tệp không ghi lý do ký

_CN, _O = bytes.fromhex("550403"), bytes.fromhex("55040a")


def _tlv(data: bytes, pos: int) -> tuple[int, int, int, int]:
    """(tag, vị trí nội dung, vị trí kết thúc, vị trí kế tiếp). Hỗ trợ độ dài không xác định (BER)."""
    tag = data[pos]
    pos += 1
    if tag & 0x1F == 0x1F:  # tag nhiều byte
        while data[pos] & 0x80:
            pos += 1
        pos += 1
    first = data[pos]
    pos += 1
    if first == 0x80:  # độ dài không xác định: tìm 00 00 cùng cấp
        start, cur = pos, pos
        while data[cur:cur + 2] != b"\x00\x00":
            _, _, _, cur = _tlv(data, cur)
        return tag, start, cur, cur + 2
    if first & 0x80:
        n = first & 0x7F
        length = int.from_bytes(data[pos:pos + n], "big")
        pos += n
    else:
        length = first
    return tag, pos, pos + length, pos + length


def _children(data: bytes, start: int, end: int) -> list[tuple[int, int, int]]:
    out, pos = [], start
    while pos < end and data[pos:pos + 2] != b"\x00\x00":
        tag, s, e, nxt = _tlv(data, pos)
        out.append((tag, s, e))
        pos = nxt
    return out


def _string(tag: int, raw: bytes) -> str:
    if tag == 0x1E:
        return raw.decode("utf-16-be", "ignore")
    if tag == 0x0C:
        return raw.decode("utf-8", "ignore")
    return raw.decode("latin-1", "ignore")


def _name_attrs(data: bytes, start: int, end: int) -> dict[bytes, str]:
    attrs: dict[bytes, str] = {}
    for _, s, e in _children(data, start, end):  # SET
        for _, s2, e2 in _children(data, s, e):  # SEQUENCE {OID, giá trị}
            parts = _children(data, s2, e2)
            if len(parts) == 2 and parts[0][0] == 0x06:
                tag, vs, ve = parts[1]
                attrs.setdefault(data[parts[0][1]:parts[0][2]], _string(tag, data[vs:ve]))
    return attrs


def cert_signer(cms: bytes) -> str:
    """Tên chủ thể (CN) trong chứng thư của người ký; rỗng nếu không đọc được."""
    try:
        _, s, e, _ = _tlv(cms, 0)  # ContentInfo
        content = [c for c in _children(cms, s, e) if c[0] == 0xA0][0]
        _, s, e = _children(cms, content[1], content[2])[0]  # SignedData
        parts = _children(cms, s, e)
        certs, serial_wanted = [], None
        for tag, cs, ce in parts:
            if tag == 0xA0:  # certificates
                for _, xs, xe in _children(cms, cs, ce):
                    tbs = _children(cms, *_children(cms, xs, xe)[0][1:])
                    if tbs and tbs[0][0] == 0xA0:
                        tbs = tbs[1:]
                    serial, subject = cms[tbs[0][1]:tbs[0][2]], tbs[4]
                    certs.append((serial, _name_attrs(cms, subject[1], subject[2])))
            elif tag == 0x31 and certs:  # signerInfos
                for _, ss, se in _children(cms, cs, ce):
                    sid = _children(cms, ss, se)[1]
                    if sid[0] == 0x30:  # IssuerAndSerialNumber
                        serial_wanted = cms[_children(cms, sid[1], sid[2])[1][1]:_children(cms, sid[1], sid[2])[1][2]]
                    break
        for serial, attrs in certs:
            if serial_wanted is None or serial == serial_wanted:
                return attrs.get(_CN) or attrs.get(_O) or ""
    except Exception:
        return ""
    return ""
