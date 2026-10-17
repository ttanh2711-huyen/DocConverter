"""Phát sự kiện tiến trình: JSON Lines cho app (xem PROTOCOL.md) hoặc chữ cho người dùng."""

import json
from typing import TextIO


class Emitter:
    def __init__(self, out: TextIO, err: TextIO, as_json: bool):
        self.out, self.err, self.as_json = out, err, as_json

    def __call__(self, event: str, **fields) -> None:
        if self.as_json:
            self.out.write(json.dumps({"event": event, **fields}, ensure_ascii=False) + "\n")
            self.out.flush()
            return
        name = fields.get("file", "").rsplit("/", 1)[-1]
        if event == "start":
            print(f"[{fields['index']}/{fields['total']}] {name}", file=self.err)
        elif event == "done":
            for path in fields["outputs"]:
                print(path, file=self.out)
        elif event in ("warning", "skipped"):
            print(f"Cảnh báo: {fields['message']}", file=self.err)
        elif event == "error":
            print(f"Lỗi: {fields['message']}", file=self.err)
        elif event == "cancelled":
            print("Đã huỷ.", file=self.err)
