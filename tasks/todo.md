# Todo: DocConverter

Lệnh chuẩn (sau khi có dự án):
- Test lõi: `cd core && uv run pytest`
- Build/test app: `cd app && swift build -c release && swift test`
- Đóng gói: `scripts/make-app.sh`

Máy đích: **Mac Intel (x86_64), macOS 15.8+**. Giao diện tiếng Việt.

---

## Phase 0: Spike, giảm rủi ro

### Task 1: Môi trường Docling chạy được trên macOS Intel 15.8

**Mô tả:** Cài `uv` và Python 3.12. Cài Docling với `torch==2.2.2`, `torchvision==0.17.2`, `numpy<2`; tìm phiên bản Docling cao nhất còn chạy được rồi khóa bằng `uv.lock`. Viết script chuyển PDF có text tiếng Việt và PDF scan tiếng Việt sang Markdown, lưu ảnh vào `<tên>_assets/`.

**Tiêu chí nghiệm thu:**
- [x] `uv sync` thành công; phiên bản Docling/torch được ghi vào `spikes/NOTES.md`
- [x] PDF có text → `.md` giữ đúng dấu tiếng Việt, heading, bảng; ảnh nằm trong `<tên>_assets/`
- [x] PDF scan với `ocrmac` (thử `vi-VT`) → `.md` đọc được; ghi lại thời gian/trang, RAM tối đa và so sánh nhanh với EasyOCR `['vi','en']`

**Kiểm chứng:**
- [x] `uv run python spikes/pdf_to_md.py fixtures/text_vi.pdf` chạy xong, không có traceback
- [x] Thủ công: mở `.md` và so với PDF gốc

**Kết quả:** ✅ Hoàn tất 2026-10-17. Docling 2.73.1 (phải ghim `docling-parse<=4.7.2`), torch 2.2.2. ocrmac 6/6 cụm từ, EasyOCR 4/6. Xem `spikes/NOTES.md`.

**Phụ thuộc:** Không có
**File dự kiến:** `spikes/pyproject.toml`, `spikes/uv.lock`, `spikes/pdf_to_md.py`, `spikes/NOTES.md`
**Quy mô:** S

### Task 2: So sánh các phương án PDF → DOCX giữ bố cục

**Mô tả:** Dùng bộ 4–5 PDF thật của người dùng (văn bản hành chính có quốc hiệu, bảng biểu, nhiều cột, ảnh/con dấu, bản scan). Tạo DOCX theo các phương án:
- **A:** Docling → HTML → pandoc (đối chứng)
- **B:** Docling → bộ ghi `python-docx` thử nghiệm
- **C:** `pdf2docx` cho PDF có text

Cài `pdf2docx` chung venv với Docling để phát hiện xung đột phụ thuộc. Viết hàm thử nghiệm nhận biết "PDF có lớp text hay là scan". Chấm điểm theo các tiêu chí: khổ giấy/lề, căn lề, cột, bảng (gộp ô), ảnh, font/cỡ chữ, dấu tiếng Việt, ngắt trang.

**Tiêu chí nghiệm thu:**
- [x] Có đủ DOCX của mọi phương án cho từng PDF mẫu, mở được trong Word/Pages
- [x] Có bảng chấm điểm và đề xuất trong `spikes/NOTES.md`; ghi rõ `pdf2docx` có chung venv được với Docling không
- [x] Hàm nhận biết text/scan phân loại đúng toàn bộ PDF mẫu

**Kiểm chứng:**
- [x] `uv run python spikes/pdf_to_docx_compare.py fixtures/` tạo ra `out/{A,B,C}/`
- [x] `textutil -convert txt` đọc được mọi file DOCX
- [x] Thủ công: người dùng mở và so từng file với PDF gốc

**Kết quả:** ✅ 2026-10-17, dùng fixture tự tạo (chưa có PDF thật). Chọn C (pdf2docx) cho PDF có text, B (Docling → python-docx) cho bản scan. Xem `spikes/NOTES.md`.

**Phụ thuộc:** Task 1
**File dự kiến:** `spikes/pdf_to_docx_compare.py`, `spikes/docx_writer_proto.py`, `spikes/NOTES.md`, `tasks/plan.md`
**Quy mô:** M

## Checkpoint 0: Có tiếp tục được không
- [x] Docling chạy ổn định trên máy Intel
- [x] **Người dùng đã chọn phương án DOCX** (dự kiến: C cho PDF có text, B cho PDF scan); quyết định số 3 trong plan.md đã được cập nhật

---

## Phase 1: Lõi chuyển đổi (CLI)

### Task 3: CLI `docconv` + PDF → MD đầu-cuối

**Mô tả:** Tạo `core/` (`src/docconv`) với các phụ thuộc đã ghim từ spike. Lệnh `docconv convert <file> --to md` lưu `.md` cạnh file gốc; ảnh vào `<tên>_assets/` (`ImageRefMode.REFERENCED`). `DocumentConverter` được tạo một lần và dùng lại. Thông báo lỗi bằng tiếng Việt.

**Tiêu chí nghiệm thu:**
- [x] Tạo ra `<tên>.md` cùng thư mục ảnh; mã thoát 0
- [x] Không ghi đè file có sẵn (thêm hậu tố ` (1)`), trừ khi có `--overwrite`
- [x] Đường dẫn chứa dấu tiếng Việt hoặc khoảng trắng vẫn chạy đúng

**Kiểm chứng:**
- [x] `uv run pytest tests/test_pdf_md.py` (có heading, có bảng, có chuỗi tiếng Việt cụ thể, có thư mục ảnh)
- [x] Thủ công: `uv run docconv convert "~/Desktop/Tài liệu.pdf" --to md`

**Kết quả:** ✅ `core/` với docling 2.73.1, ghim thêm `onnxruntime<=1.23.2` (markitdown → magika, bản cuối có wheel x86_64). Liên kết ảnh trong .md được Docling mã hoá URL (`text_vi%20%281%29_assets/…`), vẫn là Markdown hợp lệ.

**Phụ thuộc:** Checkpoint 0
**File dự kiến:** `core/pyproject.toml`, `core/src/docconv/cli.py`, `core/src/docconv/pdf_docling.py`, `core/tests/test_pdf_md.py`, `core/tests/fixtures/`
**Quy mô:** M

### Task 4: PDF → DOCX theo phương án đã chọn

**Mô tả:** Đưa phương án đã chốt vào `docx_export.py`. Nếu dùng C+B: PDF có text đi `pdf2docx`, PDF scan đi Docling (OCR) → bộ ghi `python-docx`. Hỗ trợ `--to docx` và `--to md,docx`; Docling chỉ phân tích PDF một lần cho các output cần nó. Nếu bộ ghi B vượt quá ~5 file thì tách 4a (trang, lề, đoạn, heading) và 4b (bảng, ảnh).

**Tiêu chí nghiệm thu:**
- [ ] DOCX của các PDF mẫu đạt mức điểm đã thống nhất ở Task 2
- [ ] PDF scan vẫn ra được DOCX (qua OCR); PDF có text đi đúng đường đã chọn
- [ ] `--to md,docx` tạo đủ cả hai file

**Kiểm chứng:**
- [ ] `uv run pytest tests/test_pdf_docx.py` (mở bằng `python-docx`: khổ trang và lề khớp PDF ±2 mm, số bảng đúng, có ảnh, có chuỗi tiếng Việt; kiểm tra router text/scan)
- [ ] Thủ công: so với PDF gốc trong Word/Pages

**Phụ thuộc:** Task 3
**File dự kiến:** `core/src/docconv/docx_export.py`, `core/src/docconv/pdf_kind.py`, `core/src/docconv/cli.py`, `core/tests/test_pdf_docx.py`
**Quy mô:** M (L nếu cần B đầy đủ → tách 4a/4b)

### Task 5: Định dạng khác → MD bằng markitdown + router

**Mô tả:** `router.py` chọn bộ chuyển theo đuôi file: `.pdf` đi Docling/DOCX như Task 4, các đuôi hỗ trợ đi markitdown (`markitdown[docx,pptx,xlsx,xls,outlook]` và HTML, CSV, JSON, XML, EPUB, ZIP, ảnh). Định dạng không hỗ trợ trả lỗi rõ ràng. File không phải PDF chỉ cho phép `md`.

**Tiêu chí nghiệm thu:**
- [ ] DOCX, XLSX, PPTX, HTML, CSV trong fixtures chuyển ra `.md` đúng nội dung (XLSX thành bảng Markdown)
- [ ] File không hỗ trợ: mã thoát ≠ 0, thông báo "Không hỗ trợ định dạng .doc"
- [ ] Yêu cầu `docx` cho file không phải PDF: bỏ qua kèm cảnh báo, vẫn tạo `.md`

**Kiểm chứng:**
- [ ] `uv run pytest tests/test_markitdown.py tests/test_router.py`
- [ ] Thủ công: một file Excel thật có tiếng Việt

**Phụ thuộc:** Task 3; song song được với Task 4
**File dự kiến:** `core/src/docconv/router.py`, `core/src/docconv/markitdown_conv.py`, `core/tests/test_markitdown.py`, `core/tests/test_router.py`
**Quy mô:** M

### Task 6: Chạy theo lô, thư mục đệ quy, đường dẫn đầu ra, giao thức JSON Lines

**Mô tả:** Lệnh nhận nhiều file và/hoặc thư mục (`--recursive`), bỏ qua file ẩn và file không hỗ trợ (vẫn báo lại). Đường dẫn đầu ra: `--out-mode beside` hoặc `--out-mode dir --out <thư mục>`, giữ cấu trúc thư mục con tương đối so với `--base`. Cờ `--json` in mỗi dòng một sự kiện `start|progress|done|error|skipped`; sự kiện `done` liệt kê đủ đường dẫn output. File lỗi không làm dừng cả lô. Khi nhận SIGTERM thì dọn file dở dang. Mô tả giao thức trong `core/PROTOCOL.md`.

**Tiêu chí nghiệm thu:**
- [ ] Đầu vào `A/` chứa `A/x.pdf` và `A/sub/y.xlsx`, chạy với `--out-mode dir --out O` → `O/x.md`, `O/x.docx`, `O/sub/y.md`
- [ ] Một lô 5 file có 1 file hỏng: 4 file thành công, 1 sự kiện `error`, mã thoát cho biết có lỗi một phần; stdout chỉ chứa JSON hợp lệ
- [ ] SIGTERM giữa chừng không để lại file output dở dang

**Kiểm chứng:**
- [ ] `uv run pytest tests/test_paths.py tests/test_batch.py tests/test_events.py`
- [ ] Thủ công: `uv run docconv convert fixtures/ --recursive --to md,docx --out-mode dir --out /tmp/o --json | jq .`

**Phụ thuộc:** Task 4, Task 5
**File dự kiến:** `core/src/docconv/cli.py`, `core/src/docconv/paths.py`, `core/src/docconv/events.py`, `core/PROTOCOL.md`, `core/tests/`
**Quy mô:** M

## Checkpoint 1: Lõi hoàn chỉnh
- [ ] `cd core && uv run pytest` xanh hết
- [ ] CLI chuyển được thư mục hỗn hợp ở cả hai chế độ đầu ra
- [ ] Người dùng thử CLI với 3–5 tài liệu thật

---

## Phase 2: Ứng dụng macOS (SwiftUI, SwiftPM, giao diện tiếng Việt)

### Task 7: Vỏ SwiftUI: thả 1 PDF → nhận .md

**Mô tả:** Tạo `app/` bằng SwiftPM (`.macOS(.v15)`). Cửa sổ tiếng Việt có vùng kéo thả một file. `ConversionRunner` chạy `docconv … --json` bằng `Process` (bản dev trỏ tới venv của `core/`) và giải mã sự kiện. `make-app.sh` tối thiểu: `swift build -c release`, tạo bundle `.app` với Info.plist (`LSMinimumSystemVersion` 15.0, `CFBundleDevelopmentRegion` vi).

**Tiêu chí nghiệm thu:**
- [ ] Thả 1 PDF thì `.md` được tạo cạnh file gốc và UI báo "Hoàn tất"; UI không bị đơ
- [ ] Mọi chữ trên giao diện bằng tiếng Việt
- [ ] App mở được bằng double-click

**Kiểm chứng:**
- [ ] `swift build -c release` không lỗi, không cảnh báo concurrency; `swift test` (giải mã các sự kiện mẫu trong PROTOCOL.md)
- [ ] Thủ công: kéo thả một PDF

**Phụ thuộc:** Task 6 (có thể bắt đầu với CLI giả khi PROTOCOL.md đã chốt)
**File dự kiến:** `app/Package.swift`, `app/Sources/DocConverter/{DocConverterApp,ContentView,ConversionRunner}.swift`, `app/Tests/`, `scripts/make-app.sh`
**Quy mô:** M

### Task 8: Đầu vào: chọn file, chọn thư mục, kéo thả, danh sách job

**Mô tả:** Có các nút "Chọn tệp…" (`NSOpenPanel`, chọn nhiều, lọc theo đuôi hỗ trợ) và "Chọn thư mục…" kèm checkbox "Bao gồm thư mục con". Kéo thả nhận cả file lẫn thư mục. `JobStore` liệt kê các file sẽ chuyển, loại trùng, đánh dấu file không hỗ trợ, có nút "Bắt đầu" và hiển thị trạng thái từng file (Đang chờ / Trang x/y / Hoàn tất / Lỗi / Bỏ qua).

**Tiêu chí nghiệm thu:**
- [ ] Cả 3 cách (chọn file, chọn thư mục, kéo thả) đều thêm file vào danh sách; file trùng chỉ hiện một lần
- [ ] Bật/tắt tuỳ chọn "Bao gồm thư mục con" cho ra danh sách khác nhau đúng như mong đợi
- [ ] Tiến trình theo trang cập nhật trong lúc chuyển

**Kiểm chứng:**
- [ ] `swift test` (`JobStoreTests`: loại trùng, lọc đuôi, chuyển trạng thái theo chuỗi sự kiện)
- [ ] Thủ công: thử từng cách nhập với một thư mục hỗn hợp

**Phụ thuộc:** Task 7
**File dự kiến:** `ContentView.swift`, `InputPanel.swift`, `JobStore.swift`, `Tests/DocConverterTests/JobStoreTests.swift`
**Quy mô:** M

### Task 9: Đầu ra: định dạng, lưu cạnh gốc / thư mục tuỳ chọn

**Mô tả:** Chọn định dạng cho PDF (Markdown / Word / Cả hai). Chọn nơi lưu: "Cạnh tệp gốc" hoặc "Thư mục khác…" (giữ cấu trúc thư mục con), và hiện nơi lưu đang chọn. Truyền đúng `--out-mode/--out/--base` cho CLI. Các lựa chọn được ghi nhớ qua `@AppStorage`.

**Tiêu chí nghiệm thu:**
- [ ] "Cạnh tệp gốc": output nằm cùng thư mục với từng file gốc
- [ ] "Thư mục khác": output nằm trong thư mục đã chọn với đúng cấu trúc thư mục con
- [ ] Mở lại app vẫn giữ định dạng và nơi lưu đã chọn

**Kiểm chứng:**
- [ ] `swift test` (`ArgumentsTests`: dựng đúng tham số CLI cho từng tổ hợp tuỳ chọn)
- [ ] Thủ công: chạy cùng một thư mục với hai chế độ, so sánh kết quả

**Phụ thuộc:** Task 8
**File dự kiến:** `OutputOptionsView.swift`, `ConversionRunner.swift`, `AppSettings.swift`, `Tests/DocConverterTests/ArgumentsTests.swift`
**Quy mô:** M

### Task 10: Tuỳ chọn xoá bản gốc (vào Thùng rác) sau khi thành công

**Mô tả:** Checkbox "Xoá tệp gốc sau khi chuyển thành công (đưa vào Thùng rác)", mặc định **tắt**. Bật lần đầu thì hiện hộp xác nhận. Sau sự kiện `done`, app kiểm tra mọi output yêu cầu đều tồn tại và có kích thước > 0, rồi mới gọi `FileManager.trashItem`. Nếu `trashItem` thất bại thì giữ nguyên file và báo lỗi. Trạng thái job hiển thị "Đã đưa tệp gốc vào Thùng rác".

**Tiêu chí nghiệm thu:**
- [ ] Thành công: file gốc nằm trong Thùng rác (khôi phục được), output vẫn nguyên vẹn
- [ ] File lỗi, bị huỷ, bị bỏ qua, hoặc chỉ ra được một phần output: file gốc **không** bị đụng tới
- [ ] Output trùng đường dẫn với file gốc: không xoá

**Kiểm chứng:**
- [ ] `swift test` (`SourceDisposerTests` với thư mục tạm, phủ đủ các ca trên)
- [ ] Thủ công: chạy một lô có 1 file hỏng và bật tuỳ chọn này, rồi kiểm tra Thùng rác

**Phụ thuộc:** Task 9
**File dự kiến:** `SourceDisposer.swift`, `OutputOptionsView.swift`, `JobStore.swift`, `Tests/DocConverterTests/SourceDisposerTests.swift`
**Quy mô:** S

### Task 11: Huỷ, hiển thị lỗi, mở trong Finder

**Mô tả:** Nút "Huỷ" gửi SIGTERM tới tiến trình con. Lỗi từng file hiển thị dễ đọc bằng tiếng Việt, có phần "Chi tiết" (stderr). Có nút "Hiện trong Finder" cho output. Thoát app khi đang chạy thì hỏi xác nhận và dừng tiến trình con.

**Tiêu chí nghiệm thu:**
- [ ] Huỷ: các job đang chạy hoặc đang chờ chuyển sang "Đã huỷ", không còn tiến trình python chạy ngầm, không có file dở dang, không xoá bản gốc nào
- [ ] File hỏng hiện thông báo dễ hiểu
- [ ] "Hiện trong Finder" chọn đúng file output

**Kiểm chứng:**
- [ ] Thủ công: huỷ một PDF dài, rồi `pgrep -f docconv` không trả về gì
- [ ] Thủ công: thả một file `.pdf` giả (đổi đuôi từ `.txt`)

**Phụ thuộc:** Task 10
**File dự kiến:** `ConversionRunner.swift`, `JobStore.swift`, `ContentView.swift`
**Quy mô:** S

## Checkpoint 2: App dùng được hằng ngày (bản dev)
- [ ] `uv run pytest` và `swift test` xanh
- [ ] Luồng đầy đủ: nhập (3 cách) → chọn định dạng và nơi lưu → chuyển → (xoá gốc) → mở file
- [ ] Người dùng dùng thử với tài liệu công việc thật

---

## Phase 3: Đóng gói và hoàn thiện

### Task 12: Thiết lập môi trường lần đầu

**Mô tả:** Nhúng `uv` (x86_64) cùng mã nguồn/wheel `docconv` và `uv.lock` vào `.app/Contents/Resources`. Lần đầu mở app hiện màn hình "Đang chuẩn bị…": tạo venv Python 3.12 trong `~/Library/Application Support/DocConverter/`, cài theo `uv.lock`, tải mô hình Docling. Có tiến trình và nút "Thử lại" khi mất mạng.

**Tiêu chí nghiệm thu:**
- [ ] Trên user mới, mở app lần đầu sẽ tự thiết lập xong rồi chuyển đổi được
- [ ] Tắt mạng sau khi thiết lập vẫn chuyển được PDF
- [ ] Khi `docconv` trong bản app mới khác bản cũ, app phát hiện và cập nhật venv

**Kiểm chứng:**
- [ ] `scripts/bootstrap-env.sh --check` trả mã 0 khi môi trường hợp lệ
- [ ] Thủ công: tạo user mới → mở app → chuyển file → tắt Wi‑Fi → chuyển lại

**Phụ thuộc:** Checkpoint 2
**File dự kiến:** `scripts/bootstrap-env.sh`, `EnvironmentManager.swift`, `SetupView.swift`, `scripts/make-app.sh`
**Quy mô:** M

### Task 13: Cài đặt OCR

**Mô tả:** Lõi có thêm cờ `--ocr {auto,off,force}`, `--ocr-engine {ocrmac,easyocr}`, `--ocr-lang vi,en`, `--no-tables`. App có cửa sổ "Cài đặt" để chỉnh các cờ này.

**Tiêu chí nghiệm thu:**
- [ ] `force` OCR trên PDF scan tiếng Việt cho dấu đúng ở mức người dùng chấp nhận
- [ ] `off` chạy nhanh hơn với PDF có text, kết quả không đổi
- [ ] Cài đặt được lưu lại và truyền đúng cờ cho CLI

**Kiểm chứng:**
- [ ] `uv run pytest tests/test_ocr_options.py`; `swift test` (dựng tham số)
- [ ] Thủ công: so sánh ocrmac và EasyOCR trên cùng một PDF scan

**Phụ thuộc:** Task 6 (lõi), Task 9 (UI)
**File dự kiến:** `core/src/docconv/pdf_docling.py`, `core/src/docconv/cli.py`, `core/tests/test_ocr_options.py`, `app/Sources/DocConverter/SettingsView.swift`
**Quy mô:** M

### Task 14: Đóng gói `.app`, ký ad-hoc, README

**Mô tả:** Hoàn thiện `make-app.sh`: build release, tạo bundle, icon, Info.plist (`LSMinimumSystemVersion`, kiểu tài liệu nhận được), ký `codesign --force --deep -s -`, nén thành `dist/DocConverter.zip`. README bằng tiếng Việt gồm: cài đặt, mở lần đầu (Gatekeeper), định dạng hỗ trợ, chế độ lưu, cách xoá bản gốc hoạt động, OCR, xử lý sự cố.

**Tiêu chí nghiệm thu:**
- [ ] Một lệnh `scripts/make-app.sh` tạo ra `dist/DocConverter.zip` từ bản clone sạch
- [ ] `codesign --verify --deep dist/DocConverter.app` hợp lệ
- [ ] README đủ các mục kể trên

**Kiểm chứng:**
- [ ] Chạy script trên bản clone sạch
- [ ] Thủ công: giải nén và mở trên user mới

**Phụ thuộc:** Task 12, Task 13
**File dự kiến:** `scripts/make-app.sh`, `app/Resources/Info.plist`, `app/Resources/AppIcon.icns`, `README.md`
**Quy mô:** S

## Checkpoint 3: Hoàn tất
- [ ] Toàn bộ test xanh; `make-app.sh` build sạch
- [ ] Cài trên user mới, chạy offline sau lần đầu
- [ ] Đạt mọi tiêu chí với tài liệu thật; người dùng nghiệm thu
