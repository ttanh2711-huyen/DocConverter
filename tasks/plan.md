# Kế hoạch triển khai: DocConverter (macOS 15.8+, Intel)

## Tổng quan

Ứng dụng macOS chạy trên macOS 15.8 trở lên, trên **Mac Intel (x86_64)**, để chuyển đổi tài liệu cho nhu cầu cá nhân. Giao diện bằng **tiếng Việt**.

- **PDF → .md và .docx**: dùng **Docling**. File .docx cần **giữ bố cục như bản gốc**; với PDF có sẵn text, được phép dùng `pdf2docx` nếu cho kết quả giống bản gốc hơn.
- **Các định dạng khác → .md**: dùng **markitdown** (DOCX, PPTX, XLSX/XLS, HTML, CSV, JSON, XML, EPUB, ZIP, Outlook .msg, ảnh…).

Tính năng chính:

- **Đầu vào:** chọn file (nhiều file), chọn cả thư mục (có tuỳ chọn quét thư mục con), kéo thả file/thư mục.
- **Đầu ra:** lưu **cạnh file gốc** hoặc vào **thư mục tuỳ chọn**. Với thư mục tuỳ chọn, giữ nguyên cấu trúc thư mục con. Ảnh của file .md lưu vào thư mục `<tên>_assets/` bên cạnh.
- **Xoá bản gốc (tuỳ chọn):** chỉ thực hiện sau khi mọi định dạng đầu ra của file đó đã tạo thành công. File gốc được chuyển vào **Thùng rác**.
- Hiển thị tiến trình từng file, cho phép huỷ, báo lỗi, mở kết quả trong Finder.

## Quyết định đã chốt với người dùng (2026-10-17)

| # | Câu hỏi | Trả lời |
|---|---|---|
| 1 | Kiến trúc UI | SwiftUI làm vỏ, lõi bằng Python |
| 2 | Máy chạy | **Chỉ Mac Intel**; bỏ Apple Silicon |
| 3 | Phân phối | Dùng cá nhân (ký ad-hoc, không notarize) |
| 4 | Chất lượng DOCX | Giữ bố cục như bản gốc |
| 5 | Tính năng | Chọn file, chọn thư mục, kéo thả; lưu cạnh gốc hoặc thư mục tuỳ chọn; tuỳ chọn xoá bản gốc |
| 6 | Ảnh trong .md | Lưu thư mục ảnh riêng bên cạnh |
| 7 | Ngôn ngữ giao diện | Tiếng Việt |
| 8 | `pdf2docx` cho PDF có text | Chấp nhận, nếu giống bản gốc hơn |

## Môi trường máy (đã kiểm tra)

| Mục | Giá trị | Hệ quả |
|---|---|---|
| macOS | 15.8.1 (24H32) | Đúng mức tối thiểu cần hỗ trợ |
| CPU | x86_64 (Intel) | PyTorch chỉ có wheel macOS Intel đến bản **2.2.2** → ghim bản này |
| RAM / ổ đĩa | 16 GB / còn trống 415 GB | Đủ |
| Python | chỉ có 3.9.6 của hệ thống | Cài Python 3.12 qua `uv` |
| uv / brew / pandoc | chưa có | Cài `uv` bằng trình cài đặt độc lập |
| Xcode | chỉ có Command Line Tools (Swift 6.1.2) | Build bằng SwiftPM, tự đóng gói `.app` bằng script |

## Quyết định kiến trúc

1. **Lõi Python `docconv` (CLI) và vỏ SwiftUI.** App chạy CLI làm tiến trình con và đọc sự kiện dạng **JSON Lines**. Lõi kiểm thử được độc lập; Docling có lỗi thì app không sập theo.
2. **Chỉ x86_64:**
   - App Swift build bằng `swift build -c release` (native x86_64), không cần bản universal.
   - Python ghim `python 3.12`, `torch==2.2.2`, `torchvision==0.17.2`, `numpy<2`, **`docling-parse<=4.7.2`** (bản cuối có wheel x86_64), nên uv chọn **docling 2.73.1**. Tất cả khóa bằng `uv.lock` (đã kiểm chứng ở Task 1).
   - Nếu sau này cần Apple Silicon: thêm environment marker cho torch và build thêm `--triple arm64` rồi ghép bằng `lipo`. Không làm trong phạm vi lần này.
3. **PDF → DOCX giữ bố cục.** Docling trích *cấu trúc* chứ không tái tạo trang 1:1, và chưa có bộ xuất DOCX gốc. Task 2 so sánh trên PDF thật của người dùng:
   - **A.** Docling → HTML → pandoc: chỉ để đối chứng, mất bố cục.
   - **B.** Docling → bộ ghi `python-docx` tự viết, dùng khổ trang, lề, bbox, cỡ chữ, bảng, ảnh.
   - **C.** `pdf2docx` cho PDF có sẵn text; Docling (OCR) → bộ ghi B cho PDF scan.
   - **Đã chốt (Task 2):** PDF có lớp text dùng **C** (giống bản gốc nhất, nhanh hơn ~15 lần); PDF scan dùng **B**. A bị loại. Router trong lõi tự nhận biết PDF có lớp text hay là bản scan để chọn đường đi.
   - Markdown luôn đi qua Docling.
4. **OCR mặc định dùng `ocrmac` (Apple Vision)**; EasyOCR (`vi`, `en`) làm dự phòng. Mặc định chỉ OCR khi trang không có lớp text; có tuỳ chọn ép OCR.
5. **Đường dẫn đầu ra do lõi tính** (`--out-mode beside|dir`, `--out`, `--base`) để kiểm thử được bằng pytest. Trùng tên thì thêm hậu tố ` (1)`; không ghi đè nếu không được yêu cầu.
6. **Xoá bản gốc do app thực hiện** bằng `FileManager.trashItem`, chỉ khi sự kiện `done` báo đủ mọi output và các file đó tồn tại, có kích thước > 0. Mặc định tắt; bật lần đầu thì hỏi xác nhận. Không xoá khi file lỗi, bị huỷ, chỉ ra được một phần output, hoặc output trùng file gốc.
7. **Giao diện tiếng Việt:** chuỗi tiếng Việt viết thẳng trong SwiftUI (chưa cần đa ngôn ngữ). Thông báo lỗi từ lõi cũng bằng tiếng Việt.
8. **Môi trường được quản lý:** lần chạy đầu, app dùng `uv` đi kèm để tạo venv trong `~/Library/Application Support/DocConverter/` và tải mô hình Docling. Từ đó trở đi chạy offline. Ký ad-hoc (`codesign -s -`).

## Đồ thị phụ thuộc

```
Môi trường Python 3.12 + torch 2.2.2 (Intel)                ← rủi ro cao, làm trước
    │
    ├── Docling chạy được trên PDF mẫu ──┬── PDF → MD
    │                                    └── PDF → DOCX giữ bố cục (B và/hoặc C, chọn ở Checkpoint 0)
    ├── pdf2docx (nếu chọn C)
    ├── markitdown ── Định dạng khác → MD
    │
    └── Router + tính đường dẫn đầu ra + CLI + giao thức JSON Lines
            │
            └── App SwiftUI (tiếng Việt) ── ConversionRunner
                    ├── Đầu vào: chọn file / chọn thư mục / kéo thả
                    ├── Đầu ra: cạnh gốc / thư mục tuỳ chọn, chọn định dạng
                    ├── Xoá bản gốc (vào Thùng rác) sau khi thành công
                    ├── Huỷ / lỗi / Finder
                    ├── Cài đặt OCR
                    └── Bootstrap môi trường + đóng gói .app
```

## Danh sách task (chi tiết trong `tasks/todo.md`)

### Phase 0: Spike, giảm rủi ro
- [x] Task 1: Môi trường Docling chạy được trên macOS Intel 15.8
- [x] Task 2: So sánh các phương án PDF → DOCX giữ bố cục

### Checkpoint 0
- [ ] Docling chạy ổn định; **người dùng chọn phương án DOCX** sau khi xem file mẫu

### Phase 1: Lõi chuyển đổi (CLI)
- [x] Task 3: CLI `docconv` + PDF → MD đầu-cuối
- [x] Task 4: PDF → DOCX theo phương án đã chọn
- [ ] Task 5: Định dạng khác → MD bằng markitdown + router
- [ ] Task 6: Chạy theo lô, thư mục đệ quy, đường dẫn đầu ra, giao thức JSON Lines

### Checkpoint 1
- [ ] `uv run pytest` xanh; CLI chuyển được thư mục hỗn hợp với cả hai chế độ đầu ra

### Phase 2: Ứng dụng macOS
- [ ] Task 7: Vỏ SwiftUI: thả 1 PDF → nhận .md
- [ ] Task 8: Đầu vào: chọn file, chọn thư mục, kéo thả, danh sách job
- [ ] Task 9: Đầu ra: định dạng, lưu cạnh gốc / thư mục tuỳ chọn
- [ ] Task 10: Tuỳ chọn xoá bản gốc (vào Thùng rác) sau khi thành công
- [ ] Task 11: Huỷ, hiển thị lỗi, mở trong Finder

### Checkpoint 2
- [ ] Toàn bộ luồng chạy được từ app; người dùng dùng thử với tài liệu thật

### Phase 3: Đóng gói và hoàn thiện
- [ ] Task 12: Thiết lập môi trường lần đầu
- [ ] Task 13: Cài đặt OCR
- [ ] Task 14: Đóng gói `.app`, ký ad-hoc, README

### Checkpoint 3
- [ ] Cài từ `.zip` trên user mới, chạy offline sau lần đầu; người dùng nghiệm thu

## Cơ hội làm song song

- Task 4 và Task 5 làm song song được sau Task 3.
- Task 7 bắt đầu được ngay khi `PROTOCOL.md` của Task 6 đã chốt (thử UI với CLI giả).
- Phía lõi của Task 13 làm song song được với Phase 2.

## Rủi ro và giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| DOCX không đủ "giống bản gốc" (văn bản nhiều cột, quốc hiệu, con dấu, bảng gộp ô) | **Cao** | Task 2 so sánh trên PDF thật; dùng `pdf2docx` (C) cho PDF có text; người dùng chọn ở Checkpoint 0 |
| Docling bản mới yêu cầu torch > 2.2.2 | **Cao** | Spike ở Task 1, ghim bản Docling cuối cùng còn tương thích |
| Xoá nhầm bản gốc | **Cao** | Chỉ chuyển vào Thùng rác; chỉ sau khi xác minh output; mặc định tắt; xác nhận lần đầu; có test cho các ca lỗi, huỷ, trùng đường dẫn |
| Xung đột phụ thuộc giữa `pdf2docx`/PyMuPDF và Docling | Trung bình | Kiểm tra ở Task 2 trong cùng một venv; nếu xung đột thì chạy `pdf2docx` trong venv riêng |
| OCR tiếng Việt sai dấu | Trung bình | Thử ocrmac và EasyOCR với PDF scan thật; cho chọn engine |
| Chạy trên CPU Intel chậm | Trung bình | Tiến trình theo trang, cho phép huỷ, tuỳ chọn tắt nhận dạng bảng |
| Bản cài nặng (torch + mô hình ~2–3 GB) | Trung bình | Tải về khi chạy lần đầu, không nhúng vào `.app` |
| markitdown không đọc `.doc`/`.ppt` đời cũ | Thấp | Báo "không hỗ trợ"; có thể đổi `.doc` qua `textutil` của macOS |
| Gatekeeper chặn app ký ad-hoc | Thấp | README hướng dẫn mở bằng chuột phải → Mở |

## Câu hỏi mở

Không còn câu hỏi nào. Quyết định tiếp theo của người dùng là chọn phương án DOCX ở Checkpoint 0.
