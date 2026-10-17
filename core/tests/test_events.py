import json
import signal
import time

from conftest import events, run_cli, run_cli_process

REQUIRED = {
    "start": {"file", "index", "total", "kind", "pages"},
    "progress": {"file", "stage", "message"},
    "warning": {"file", "message"},
    "done": {"file", "outputs", "seconds"},
    "skipped": {"file", "message"},
    "error": {"file", "message", "detail"},
    "finished": {"ok", "failed", "skipped", "cancelled"},
}


def test_event_shapes_match_protocol(copy_fixture):
    pdf = copy_fixture("text_vi.pdf")
    doc = copy_fixture("quyet_dinh.docx")
    proc = run_cli("convert", pdf, doc, "--to", "md,docx", "--json")
    assert proc.returncode == 0, proc.stderr
    ev = events(proc)
    for e in ev:
        assert REQUIRED[e["event"]] <= e.keys(), e
    starts = [e for e in ev if e["event"] == "start"]
    assert [(s["index"], s["total"], s["kind"], s["pages"]) for s in starts] == [(1, 2, "pdf", 1), (2, 2, "markitdown", None)]
    assert {e["stage"] for e in ev if e["event"] == "progress" and e["file"] == str(pdf)} == {"analyze", "markdown", "docx"}
    assert any(e["event"] == "warning" and e["file"] == str(doc) for e in ev)
    done_pdf = next(e for e in ev if e["event"] == "done" and e["file"] == str(pdf))
    assert {p.rsplit("/", 1)[-1] for p in done_pdf["outputs"]} == {"text_vi.md", "text_vi_assets", "text_vi.docx"}


def test_process_stdout_is_pure_json(copy_fixture):
    """pdf2docx/PyMuPDF/markitdown có thể in ra stdout; ở chế độ --json chúng phải sang stderr."""
    pdf = copy_fixture("layout_vi.pdf")
    csv = copy_fixture("danh_sach.csv")
    p = run_cli_process("convert", pdf, csv, "--to", "docx", "--json")
    out, err = p.communicate(timeout=600)
    assert p.returncode == 0, err
    lines = [line for line in out.splitlines() if line.strip()]
    assert lines and all(isinstance(json.loads(line), dict) for line in lines)
    assert json.loads(lines[-1])["event"] == "finished"


def test_sigterm_cancels_and_cleans_up(copy_fixture, workdir):
    pdf = copy_fixture("layout_scan_vi.pdf")
    p = run_cli_process("convert", pdf, "--to", "md,docx", "--json")
    first = p.stdout.readline()
    assert json.loads(first)["event"] == "start"
    time.sleep(1)
    p.send_signal(signal.SIGTERM)
    out, _ = p.communicate(timeout=120)
    assert p.returncode == 130
    tail = [json.loads(line) for line in out.splitlines() if line.strip()]
    assert tail[-1]["event"] == "finished" and tail[-1]["cancelled"] is True
    assert sorted(x.name for x in workdir.iterdir()) == ["layout_scan_vi.pdf"]
