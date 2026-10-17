# DocConverter

Ứng dụng macOS (15 trở lên, máy Intel) chuyển đổi tài liệu cho nhu cầu cá nhân:

- **PDF → Markdown (.md) và/hoặc Word (.docx)**
  - Markdown: dùng [Docling](https://github.com/docling-project/docling), giữ tiêu đề, bảng và ảnh.
  - Word: PDF có sẵn chữ dùng `pdf2docx` (giữ font, cỡ chữ, cột, vị trí ảnh). PDF scan được Docling nhận dạng chữ (OCR bằng Apple Vision), rồi dựng lại khổ giấy, lề, bảng gộp ô và ảnh.
- **Word, Excel, PowerPoint, HTML, CSV, JSON, XML, EPUB, ZIP, Outlook (.msg), ảnh → Markdown**: dùng [markitdown](https://github.com/microsoft/markitdown).

## Cài đặt

1. Giải nén `DocConverter.zip` và kéo `DocConverter.app` vào thư mục **Ứng dụng**.
2. **Lần mở đầu tiên:** app chỉ được ký tại chỗ (ad-hoc), nên macOS sẽ chặn nếu bạn bấm đúp. Hãy **bấm chuột phải vào app → Mở → Mở**. Nếu vẫn bị chặn, vào **Cài đặt hệ thống → Quyền riêng tư & Bảo mật**, kéo xuống và bấm **Vẫn mở**.
3. Màn hình **Chuẩn bị DocConverter** hiện ra. Bấm **Bắt đầu thiết lập**. App sẽ tải Python 3.12, các thư viện chuyển đổi và mô hình nhận dạng (khoảng 2–3 GB) vào `~/Library/Application Support/DocConverter/`. Bước này cần mạng và có thể mất từ vài phút đến hơn 20 phút tuỳ tốc độ mạng. Chỉ phải làm một lần; sau đó app chạy được khi không có mạng.

## Sử dụng

1. Thêm tài liệu bằng một trong các cách:
   - nút **Chọn tệp…**;
   - nút **Chọn thư mục…** (bật **Bao gồm thư mục con** để lấy cả thư mục con);
   - kéo thả tệp/thư mục vào cửa sổ hoặc lên biểu tượng app.
   Tệp ẩn bị bỏ qua. Định dạng không hỗ trợ (ví dụ `.doc`, `.ppt` đời cũ) hiện là **Bỏ qua**.
2. Chọn **Định dạng cho PDF**: Markdown, Word hoặc Cả hai. Các tệp khác luôn được chuyển sang Markdown.
3. Chọn **Lưu vào**:
   - **Cạnh tệp gốc**: kết quả nằm cùng thư mục với tệp gốc.
   - **Thư mục khác**: kết quả nằm trong thư mục bạn chọn và **giữ nguyên cấu trúc thư mục con** của thư mục đầu vào.
4. Bấm **Bắt đầu**. Mỗi tệp hiện trạng thái riêng. Bấm 🔍 để hiện kết quả trong Finder, hoặc ⓘ để xem chi tiết lỗi. **Huỷ** dừng ngay và không để lại tệp dở dang.

Tên kết quả không bao giờ ghi đè tệp có sẵn: nếu `a.md` đã tồn tại, app tạo `a (1).md`. Ảnh trong tệp Markdown nằm trong thư mục `<tên>_assets/` bên cạnh.

### Xoá tệp gốc

Tuỳ chọn **Xoá tệp gốc sau khi chuyển thành công (đưa vào Thùng rác)** mặc định **tắt**. Khi bật (app hỏi xác nhận ở lần đầu), tệp gốc chỉ được chuyển vào **Thùng rác** (khôi phục được) khi tất cả các điều kiện sau đều đúng:

- tệp đó chuyển **thành công**;
- **mọi** định dạng đã yêu cầu đều đã được tạo và không rỗng (ví dụ chọn "Cả hai" thì phải có cả `.md` lẫn `.docx`);
- tệp kết quả không trùng với chính tệp gốc.

Tệp lỗi, bị huỷ, bị bỏ qua hoặc chuyển chưa đủ luôn được giữ nguyên.

### Cài đặt (⌘,)

- **Nhận dạng chữ (OCR)**:
  - *Tự động*: chỉ OCR trang không có chữ.
  - *Tắt*.
  - *Luôn nhận dạng mọi trang*: dùng khi PDF có lớp chữ bị lỗi phông.
- **Công cụ OCR**: Apple Vision (khuyên dùng, đọc tiếng Việt tốt hơn) hoặc EasyOCR. EasyOCR tải mô hình ở lần dùng đầu.
- **Nhận dạng cấu trúc bảng**: tắt để chạy nhanh hơn, nhưng bảng sẽ không được tách thành từng ô.

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| macOS báo "không thể mở vì không xác minh được nhà phát triển" | Bấm chuột phải → Mở (xem mục Cài đặt) |
| Thiết lập lần đầu báo lỗi | Kiểm tra mạng rồi bấm **Thử lại**; nhật ký hiện ngay dưới thanh tiến trình |
| Muốn cài lại môi trường từ đầu | Thoát app, xoá thư mục `~/Library/Application Support/DocConverter`, mở lại app |
| PDF scan ra chữ sai dấu | Bản scan càng rõ (≥ 200 dpi) càng tốt; thử đổi công cụ OCR trong Cài đặt |
| File Word từ bản scan chưa giống bản gốc | Đây là giới hạn của việc dựng lại bố cục từ ảnh: cỡ chữ được ước lượng, không có in nghiêng |
| Chuyển chậm | Lần đầu mỗi phiên phải nạp mô hình (~30 giây); PDF dài hoặc nhiều bảng sẽ lâu hơn trên máy Intel |

## Dành cho phát triển

```
core/       Lõi Python (CLI docconv) — giao thức với app: core/PROTOCOL.md
app/        App SwiftUI (SwiftPM, không cần Xcode)
scripts/    make-app.sh, bootstrap-env.sh, selftest.sh, make-icon.py
spikes/     Thử nghiệm ban đầu (Docling trên Intel, so sánh PDF → DOCX) — xem spikes/NOTES.md
tasks/      Kế hoạch và danh sách việc
```

- Test lõi: `cd core && uv sync && uv run pytest`
- Test app: `cd app && swift test` (thêm `DOCCONV_PYTHON=../core/.venv/bin/python` để chạy cả test tích hợp với lõi thật)
- Bản phát triển (dùng venv của `core/`): `scripts/make-app.sh --dev`
- Bản phát hành: `scripts/make-app.sh` → `dist/DocConverter.app` và `dist/DocConverter.zip`
- Tự kiểm tra giao diện không cần quyền Ghi màn hình: `scripts/selftest.sh ảnh.png <tệp/thư mục>… [-- KEY=VALUE…]` (các biến xem `app/Sources/DocConverter/SelfTest.swift`)

Các phiên bản phải ghim vì máy Intel: `torch==2.2.2`, `docling-parse<=4.7.2` (dẫn tới docling 2.73.1), `onnxruntime<=1.23.2`, `numpy<2`.
