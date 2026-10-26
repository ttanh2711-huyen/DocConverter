"""Trích thông tin văn bản hành chính (thể thức theo Nghị định 30/2020/NĐ-CP) từ văn bản đã chuyển:
loại văn bản, số và ký hiệu, ngày ban hành, cơ quan ban hành, người ký, chức vụ, trích yếu.

Chỉ dùng quy tắc (không cần mạng hay mô hình). Trường nào không nhận ra thì để trống.
"""

import re
import unicodedata
from dataclasses import asdict, dataclass
from datetime import date

# Tên loại văn bản (theo thứ tự ưu tiên khi so khớp: tên dài trước).
DOC_TYPES = [
    "Thông tư liên tịch", "Văn bản hợp nhất", "Bản thỏa thuận", "Bản ghi nhớ", "Giấy ủy quyền", "Giấy giới thiệu",
    "Giấy nghỉ phép", "Phiếu chuyển", "Phiếu gửi", "Phiếu báo", "Giấy mời", "Thư công", "Công điện", "Công văn",
    "Bộ luật", "Luật", "Pháp lệnh", "Nghị quyết", "Nghị định", "Quyết định", "Chỉ thị", "Thông tư", "Quy chế",
    "Quy định", "Thông báo", "Hướng dẫn", "Chương trình", "Kế hoạch", "Phương án", "Đề án", "Dự án", "Báo cáo",
    "Biên bản", "Tờ trình", "Hợp đồng", "Lệnh",
]

# Chữ viết tắt loại văn bản trong ký hiệu (phần sau dấu "/" đầu tiên, trước dấu "-").
TYPE_CODES = {
    "NQ": "Nghị quyết", "NĐ": "Nghị định", "QĐ": "Quyết định", "CT": "Chỉ thị", "TT": "Thông tư",
    "TTLT": "Thông tư liên tịch", "QC": "Quy chế", "QYĐ": "Quy định", "TB": "Thông báo", "HD": "Hướng dẫn",
    "CTR": "Chương trình", "KH": "Kế hoạch", "PA": "Phương án", "ĐA": "Đề án", "DA": "Dự án", "BC": "Báo cáo",
    "BB": "Biên bản", "TTR": "Tờ trình", "HĐ": "Hợp đồng", "CĐ": "Công điện", "BGN": "Bản ghi nhớ",
    "BTT": "Bản thỏa thuận", "GUQ": "Giấy ủy quyền", "GM": "Giấy mời", "GGT": "Giấy giới thiệu",
    "GNP": "Giấy nghỉ phép", "PG": "Phiếu gửi", "PC": "Phiếu chuyển", "PB": "Phiếu báo", "VBHN": "Văn bản hợp nhất",
    "L": "Luật",
}

# Đơn vị hành chính đứng ở dòng thứ hai của tên cơ quan ("ỦY BAN NHÂN DÂN" / "TỈNH CÀ MAU").
_ADMIN_UNITS = ("TỈNH ", "THÀNH PHỐ ", "HUYỆN ", "QUẬN ", "THỊ XÃ ", "THỊ TRẤN ", "XÃ ", "PHƯỜNG ", "ĐẶC KHU ")
_DELEGATION = re.compile(r"^(TM|KT|TL|TUQ|Q|T/M|K/T|T/L)\s*[./]")
_SIGN_NOISE = re.compile(r"^[(\[]?\s*(đã ký|ký|ký tên|ký, ghi rõ họ tên|signature|chữ ký)[^)\]]*[)\]]?$", re.I)

_NUMBER = re.compile(r"(?:^|\s)(?:Số|SỐ|số)\s*[:.]?\s*((?:\d+\s*)?(?:/\s*\d{4}\s*)?/\s*[A-ZĐ][A-ZĐa-zđ0-9.\-–]*)")
_DATE_WORDS = re.compile(r"ngày\s+(\d{1,2})\s+tháng\s+(\d{1,2})\s+năm\s+(\d{4})", re.I)
_DATE_SLASH = re.compile(r"ngày\s+(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{4})", re.I)


@dataclass
class DocMeta:
    doc_type: str = ""
    number: str = ""
    date: str = ""  # yyyy-mm-dd
    issuer: str = ""
    signer: str = ""
    position: str = ""
    summary: str = ""

    def to_dict(self) -> dict:
        return {k: v for k, v in asdict(self).items() if v}

    @property
    def is_document(self) -> bool:
        """Có đủ dấu hiệu là văn bản hành chính để ghi vào sổ."""
        return bool(self.number or (self.doc_type and (self.date or self.signer)))


# MARK: - Chuẩn hoá

_TONE_FIX = {  # cách bỏ dấu cũ → mới, để so khớp "UỶ"/"ỦY", "HOÀ"/"HÒA"
    "oà": "òa", "oá": "óa", "oả": "ỏa", "oã": "õa", "oạ": "ọa", "oè": "òe", "oé": "óe", "oẻ": "ỏe", "oẽ": "õe",
    "oẹ": "ọe", "uỳ": "ùy", "uý": "úy", "uỷ": "ủy", "uỹ": "ũy", "uỵ": "ụy",
}


def canon(text: str) -> str:
    """Chữ thường, NFC, thống nhất cách bỏ dấu, gộp khoảng trắng."""
    s = unicodedata.normalize("NFC", text).lower()
    for old, new in _TONE_FIX.items():
        s = s.replace(old, new)
    return re.sub(r"\s+", " ", s).strip()


def _clean_line(line: str) -> str:
    line = re.sub(r"<!--.*?-->", " ", line)
    line = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", line)  # ảnh
    line = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line)  # liên kết → chữ
    line = re.sub(r"<br\s*/?>", " ", line, flags=re.I)
    line = line.replace("\\", "")
    line = re.sub(r"^\s*(#{1,6}|>|[-*+•]\s|\d+\.\s)\s*", "", line)
    line = re.sub(r"(\*\*|__|\*|_{1,2}(?=\w)|(?<=\w)_{1,2})", "", line)
    line = re.sub(r"^[\s\-_–—=*.]+$", "", line)  # đường kẻ dưới tên cơ quan / quốc hiệu
    line = re.sub(r"[\s\-_–—=]{3,}$", "", line)
    line = re.sub(r"^[\s\-_–—=]{3,}", "", line)
    return re.sub(r"\s+", " ", line).strip()


def lines_of(text: str) -> list[str]:
    """Tách văn bản (Markdown/chữ thường) thành các dòng sạch; mỗi ô bảng là một dòng."""
    out: list[str] = []
    for raw in unicodedata.normalize("NFC", text).splitlines():
        if re.fullmatch(r"\s*\|?[\s:\-|]+\|?\s*", raw) and "-" in raw:
            continue  # dòng kẻ của bảng Markdown
        cells = raw.split("|") if raw.strip().startswith("|") or raw.count("|") >= 2 else [raw]
        for cell in cells:
            cleaned = _clean_line(cell)
            if cleaned:
                out.append(cleaned)
    return out


def _is_upper(s: str, min_letters: int = 3) -> bool:
    letters = [c for c in s if c.isalpha()]
    return len(letters) >= min_letters and sum(c.isupper() for c in letters) / len(letters) >= 0.85


def _is_national_motto(s: str) -> bool:
    c = canon(s)
    return c.startswith("cộng hòa xã hội chủ nghĩa") or c.startswith("độc lập") or "tự do - hạnh phúc" in c \
        or "tự do – hạnh phúc" in c


# MARK: - Từng trường

def _find_number(lines: list[str]) -> tuple[int, str]:
    for i, line in enumerate(lines[:60]):
        m = _NUMBER.search(line)
        if m:
            return i, re.sub(r"\s+", "", m.group(1)).replace("–", "-").rstrip(".-")
    return -1, ""


def _find_date(lines: list[str]) -> str:
    def parse(line: str) -> str:
        for pattern in (_DATE_WORDS, _DATE_SLASH):
            m = pattern.search(line)
            if m:
                d, mth, y = map(int, m.groups())
                try:
                    return date(y, mth, d).isoformat()
                except ValueError:
                    continue
        return ""

    head = lines[:60]
    # Ưu tiên dòng "Địa danh, ngày … tháng … năm …" ở phần đầu văn bản.
    for line in head:
        if re.search(r"[^\d\s,]\s*,\s*ngày\s+\d", line, re.I) and (found := parse(line)):
            return found
    for line in head[:20]:
        if found := parse(line):
            return found
    return ""


def _type_from_line(line: str) -> str:
    """Tên loại văn bản viết hoa ở đầu dòng; Docling có thể nối luôn trích yếu phía sau
    ("QUYẾT ĐỊNH Về việc …")."""
    words = line.split()
    head: list[str] = []
    for w in words:
        if not _is_upper(w, 1):
            break
        head.append(w)
    if not head or (len(head) < len(words) and not canon(" ".join(words[len(head):])).startswith(("về ", "v/v"))):
        return ""
    c = canon(" ".join(head)).rstrip(":")
    for t in DOC_TYPES:
        name = canon(t)
        if c == name or (c.startswith(name + " ") and len(c) <= len(name) + 40 and t in ("Luật", "Bộ luật")):
            return t
    return ""


def _find_type(lines: list[str], number: str) -> tuple[int, str]:
    for i, line in enumerate(lines[:60]):
        if t := _type_from_line(line):
            return i, t
    if number and "/" in number:
        code = number.split("/")[-1].split("-")[0].upper()
        if code in TYPE_CODES:
            return -1, TYPE_CODES[code]
        if any(canon(l).startswith("v/v") for l in lines[:40]) or len(number.split("/")[-1].split("-")) >= 2:
            return -1, "Công văn"  # ký hiệu dạng "45/UBND-KT": không có chữ viết tắt tên loại
    if any(canon(l).startswith("v/v") for l in lines[:40]):
        return -1, "Công văn"
    return -1, ""


def _find_issuer(lines: list[str], number_at: int, type_at: int) -> str:
    end = number_at if number_at >= 0 else (type_at if type_at >= 0 else min(len(lines), 12))
    candidates: list[str] = []
    for i, line in enumerate(lines[:end + 1]):
        part = line
        if i == number_at:  # ô gộp "TÊN CƠ QUAN Số: 12/QĐ-UBND": chỉ lấy phần trước "Số"
            m = re.search(r"(?:^|\s)(?:Số|SỐ|số)\s*[:.]?\s*\d*\s*/", line)
            part = line[:m.start()] if m else ""
        elif i == end and number_at < 0:
            break  # dòng tên loại văn bản
        part = part.strip(" ,;:")
        if not part or _is_national_motto(part) or re.search(r"ngày\s+\d", part, re.I):
            continue
        if _is_upper(part) and not _type_from_line(part):
            candidates.append(part)
    if not candidates:
        return ""
    last = candidates[-1]
    if len(candidates) >= 2 and last.startswith(_ADMIN_UNITS):
        return f"{candidates[-2]} {last}"
    return last


def _is_name(words: list[str]) -> bool:
    return 2 <= len(words) <= 5 and all(w.isalpha() and w[0].isupper() and (len(w) == 1 or w[1:].islower())
                                        for w in words)


def _find_signer(lines: list[str]) -> tuple[str, str]:
    stop = len(lines)
    window = range(stop - 1, max(stop - 45, -1), -1)
    for i in window:
        line = lines[i]
        if _SIGN_NOISE.match(line):
            continue
        words = line.split()
        # Họ tên ở cuối dòng; phần trước (nếu có) phải là chức vụ viết hoa (ô bảng gộp nhiều đoạn).
        for n in range(min(5, len(words)), 1, -1):
            name_words = words[-n:]
            prefix = " ".join(words[:-n])
            prefix = _SIGN_NOISE.sub("", re.sub(r"\((đã ký|ký)[^)]*\)", "", prefix, flags=re.I)).strip()
            if _is_name(name_words) and (not prefix or _is_upper(prefix)):
                position = prefix or _position_above(lines, i)
                if position:
                    return " ".join(name_words), _tidy_position(position)
                break
    return "", ""


def _is_recipient(line: str) -> bool:
    """Dòng thuộc khối "Nơi nhận" (Docling có thể đặt xen giữa chức vụ và họ tên người ký)."""
    c = canon(line)
    return c.startswith(("nơi nhận", "như ", "lưu", "- ")) or line.rstrip().endswith(";")


def _position_above(lines: list[str], i: int) -> str:
    parts: list[str] = []
    for j in range(i - 1, max(i - 13, -1), -1):
        line = lines[j]
        if _SIGN_NOISE.match(line) or re.fullmatch(r"\(.*\)", line) or _is_recipient(line):
            continue
        if _is_upper(line) and len(parts) < 3:
            parts.insert(0, line)
            continue
        break
    return " ".join(parts)


def _tidy_position(position: str) -> str:
    """"TM. ỦY BAN NHÂN DÂN KT. CHỦ TỊCH PHÓ CHỦ TỊCH" → "KT. CHỦ TỊCH, PHÓ CHỦ TỊCH"."""
    position = re.sub(r"\s+", " ", position).strip(" ,;")
    pieces = re.split(r"\s(?=(?:TM|KT|TL|TUQ|Q)\.\s)", position)
    if len(pieces) > 1:
        # Bỏ phần "TM. <tập thể>" khi theo sau còn chức danh cụ thể.
        pieces = [p for p in pieces if not p.startswith("TM.")] or pieces
    last = pieces[-1]
    m = _DELEGATION.match(last)
    if m:
        # "KT. CHỦ TỊCH PHÓ CHỦ TỊCH": tách chức danh thật sau phần uỷ quyền.
        for title in ("PHÓ CHỦ TỊCH", "PHÓ GIÁM ĐỐC", "THỨ TRƯỞNG", "PHÓ TRƯỞNG", "PHÓ CHÁNH", "PHÓ THỦ TƯỚNG",
                      "PHÓ CHỦ NHIỆM", "PHÓ VIỆN TRƯỞNG", "PHÓ HIỆU TRƯỞNG", "PHÓ CỤC TRƯỞNG", "PHÓ BÍ THƯ",
                      "CHÁNH VĂN PHÒNG", "TRƯỞNG PHÒNG", "TRƯỞNG BAN"):
            k = last.find(" " + title)
            if k > 0:
                return f"{last[:k]}, {last[k + 1:]}"
    return last


def _find_summary(lines: list[str], number_at: int, type_at: int) -> str:
    for line in lines[:50]:
        # "V/v …" có thể nằm chung ô với số ký hiệu: "Số: 45/UBND-KT V/v triển khai…"
        m = re.search(r"(?:^|\s)(?:V/v|v/v|V/V)\s*[:.]?\s*(.+)$", line)
        if m:
            return m.group(1).strip()
        m = re.search(r"(?:^|\s)((?:Về việc|VỀ VIỆC)\s*[:.]?\s*.+)$", line)
        if m and (m.start() == 0 or _type_from_line(line)):
            return m.group(1).strip()
    if type_at >= 0:
        for line in lines[type_at + 1:type_at + 4]:
            c = canon(line)
            if c.startswith("căn cứ") or _type_from_line(line) or _is_national_motto(line):
                break
            if len(line) >= 8 and not re.search(r"ngày\s+\d", line):
                return line
    return ""


def extract(text: str) -> DocMeta:
    lines = lines_of(text)
    if not lines:
        return DocMeta()
    number_at, number = _find_number(lines)
    type_at, doc_type = _find_type(lines, number)
    signer, position = _find_signer(lines)
    return DocMeta(
        doc_type=doc_type,
        number=number,
        date=_find_date(lines),
        issuer=_find_issuer(lines, number_at, type_at),
        signer=signer,
        position=position,
        summary=_find_summary(lines, number_at, type_at)[:400],
    )
