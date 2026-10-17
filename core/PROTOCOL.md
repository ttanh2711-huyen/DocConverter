# Giao thức CLI `docconv` ↔ app

## Lệnh

```
docconv convert [INPUT ...] [--manifest FILE|-] [--recursive]
                [--to md|docx|md,docx]
                [--out-mode beside|dir] [--out DIR]
                [--overwrite] [--json]
```

- `INPUT` là tệp hoặc thư mục. Với thư mục, chỉ lấy tệp ngay trong thư mục đó; thêm `--recursive` để lấy cả thư mục con. Tệp/thư mục ẩn (tên bắt đầu bằng `.`) bị bỏ qua mà không báo. Tệp có đuôi không hỗ trợ trong thư mục sinh sự kiện `skipped`.
- `--manifest`: danh sách JSON `[{"src": "/đường/dẫn/tệp", "base": "/thư/mục/gốc"}]`, đọc từ tệp hoặc từ stdin (`-`). `base` không bắt buộc (mặc định là thư mục chứa tệp). App dùng cách này để gửi đúng danh sách tệp người dùng đã chọn, kèm thư mục gốc dùng để giữ cấu trúc thư mục con.
- `--to`: định dạng đầu ra. `docx` chỉ áp dụng cho PDF; với tệp khác sinh sự kiện `warning` và vẫn tạo `.md`.
- `--out-mode beside` (mặc định): ghi cạnh tệp gốc. `--out-mode dir --out DIR`: ghi vào `DIR/<đường dẫn tương đối của thư mục chứa tệp so với base>/`.
- Không ghi đè: nếu tên đã tồn tại thì thêm hậu tố ` (1)`, ` (2)`…; `--overwrite` để ghi đè.
- Ảnh của `.md` (từ PDF) nằm trong thư mục `<tên>_assets/` cạnh tệp `.md`.
- Mọi đầu ra được tạo trong thư mục tạm `.docconv-tmp-*` cùng thư mục đích, và chỉ được chuyển vào chỗ khi tệp đó **đã thành công toàn bộ**. Lỗi hoặc huỷ thì không để lại tệp dở dang.

## Sự kiện (`--json`)

Mỗi dòng stdout là **một đối tượng JSON** (UTF-8). Log của thư viện đi ra stderr. Trường `file` luôn là đường dẫn tuyệt đối của tệp nguồn.

| `event` | Trường khác | Ý nghĩa |
|---|---|---|
| `start` | `file`, `index` (từ 1), `total`, `kind` (`pdf`\|`markitdown`), `pages` (số trang PDF hoặc `null`) | Bắt đầu xử lý một tệp |
| `progress` | `file`, `stage` (`analyze`\|`markdown`\|`docx`), `message` | Chuyển sang bước mới |
| `warning` | `file`, `message` | Cảnh báo, vẫn tiếp tục |
| `done` | `file`, `outputs` (danh sách đường dẫn tuyệt đối: `.md`, thư mục `_assets`, `.docx`), `seconds` | Tệp đã xong; mọi đầu ra đã nằm đúng chỗ |
| `skipped` | `file`, `message` | Bỏ qua (đuôi không hỗ trợ khi quét thư mục) |
| `error` | `file`, `message` (tiếng Việt, cho người dùng), `detail` (kỹ thuật) | Tệp lỗi; các tệp khác vẫn tiếp tục |
| `cancelled` | | Nhận SIGTERM/SIGINT; đã dọn tệp dở dang |
| `finished` | `ok`, `failed`, `skipped`, `cancelled` (bool) | Dòng cuối cùng |

Ví dụ:

```json
{"event": "start", "file": "/Users/a/Tài liệu/x.pdf", "index": 1, "total": 2, "kind": "pdf", "pages": 2}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "analyze", "message": "Đang phân tích bố cục (2 trang)"}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "markdown", "message": "Đang ghi Markdown"}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "docx", "message": "Đang tạo Word"}
{"event": "done", "file": "/Users/a/Tài liệu/x.pdf", "outputs": ["/Users/a/Tài liệu/x.md", "/Users/a/Tài liệu/x_assets", "/Users/a/Tài liệu/x.docx"], "seconds": 12.4}
{"event": "start", "file": "/Users/a/Tài liệu/cu.doc", "index": 2, "total": 2, "kind": null, "pages": null}
{"event": "error", "file": "/Users/a/Tài liệu/cu.doc", "message": "Không hỗ trợ định dạng .doc: cu.doc", "detail": "UnsupportedFormat"}
{"event": "finished", "ok": 1, "failed": 1, "skipped": 0, "cancelled": false}
```

## Mã thoát

| Mã | Ý nghĩa |
|---|---|
| 0 | Mọi tệp thành công (có thể có `skipped`) |
| 1 | Lỗi tham số, hoặc mọi tệp đều lỗi |
| 2 | Có tệp thành công và có tệp lỗi |
| 130 | Bị huỷ (SIGTERM/SIGINT) |
