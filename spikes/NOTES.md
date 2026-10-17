# Ghi chú spike

## Task 1: Docling trên macOS Intel 15.8 (2026-10-17)

### Môi trường đã chạy được

| Gói | Phiên bản | Ghi chú |
|---|---|---|
| Python | 3.12.15 (uv) | `uv python install 3.12` |
| uv | 0.13.1 | cài ở `~/.local/bin` |
| torch / torchvision | 2.2.2 / 0.17.2 | bản cuối có wheel macOS x86_64 |
| numpy | 1.26.4 | `numpy<2` |
| **docling** | **2.73.1** | bị giới hạn bởi docling-parse (xem dưới) |
| **docling-parse** | **4.7.2** | **bản cuối có wheel macOS x86_64 cho cp312** |
| docling-core / docling-ibm-models | 2.101.1 / 3.15.0 | |
| ocrmac / easyocr | 1.0.1 / 1.7.2 | |

**Phát hiện quan trọng:** Nếu không ghim, uv chọn docling 2.140.0 kèm docling-parse 7.22.3. Bản này chỉ có wheel arm64, nên uv phải biên dịch từ mã nguồn và bị treo hơn 20 phút. Cần ghim `docling-parse<=4.7.2`; khi đó uv tự chọn docling 2.73.1. Ràng buộc này phải mang theo sang `core/pyproject.toml` (Task 3) và vào bước bootstrap (Task 12).

Log của Docling báo `Accelerator device: 'mps'`: máy Intel này có GPU Metal, nên torch 2.2.2 dùng được MPS.

### Kết quả (fixture tự tạo: 1 trang A4, quốc hiệu, heading, bảng 3×4, 1 ảnh)

Các fixture được tạo bằng `uv run python make_fixtures.py`. `scan_vi.pdf` là bản raster 200 dpi, không có lớp text.

| Trường hợp | Kết quả | Thời gian* | RAM tối đa |
|---|---|---|---|
| `text_vi.pdf` (lớp text) | 6/6 cụm từ đúng dấu; heading `##`; bảng Markdown đúng; ảnh trong `text_vi_assets/` | ~25 s/trang (lần đầu ~99 s do tải và nạp mô hình) | ~1.0 GB |
| `scan_vi.pdf`, ocrmac `vi-VT` | 6/6 cụm từ; sai 3 dấu thanh: "Kiền nghị", "biên động", "đôi với"; bảng đúng | 6–9 s | ~1.0 GB |
| `scan_vi.pdf`, EasyOCR `vi,en` | 4/6 cụm từ; **đảo thứ tự từ** trong đoạn văn, thiếu chữ; một ô bảng bị đảo ("Lợi Hưng") | 20–38 s | ~1.2 GB |

\* Đo cả thời gian khởi tạo `DocumentConverter` trong cùng tiến trình.

### Kết luận
- Docling chạy được trên máy Intel → **tiếp tục kế hoạch**.
- **Dùng ocrmac làm OCR mặc định**; EasyOCR chỉ để dự phòng (kém hơn rõ với tiếng Việt).
- Nên thử lại với PDF scan thật (chất lượng ảnh thấp hơn, có con dấu) ở Task 2.
- Docling 2.73.1 cũ hơn bản mới nhất khoảng 70 bản phát hành. Cần kiểm tra ở Task 2 xem API mà phương án B cần (bbox, khổ trang) có đủ không.

### Chạy lại
```
cd spikes
uv sync
uv run python make_fixtures.py
uv run pytest -s
uv run python pdf_to_md.py fixtures/text_vi.pdf --out out/text
uv run python pdf_to_md.py fixtures/scan_vi.pdf --out out/scan --ocr force --engine ocrmac
```
