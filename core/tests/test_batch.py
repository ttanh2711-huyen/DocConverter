import json
import shutil

from conftest import FIXTURES, events, run_cli


def _tree(root):
    return sorted(str(p.relative_to(root)) for p in root.rglob("*") if p.is_file() and "_assets" not in str(p))


def _make_input(workdir):
    a = workdir / "A"
    (a / "sub").mkdir(parents=True)
    shutil.copy(FIXTURES / "layout_vi.pdf", a / "x.pdf")
    shutil.copy(FIXTURES / "thong_ke.xlsx", a / "sub" / "y.xlsx")
    shutil.copy(FIXTURES / "danh_sach.csv", a / ".an.csv")
    shutil.copy(FIXTURES / "cu.doc", a / "cu.doc")
    return a


def test_recursive_dir_mode_mirrors_structure(workdir):
    a = _make_input(workdir)
    out = workdir / "O"
    proc = run_cli("convert", a, "--recursive", "--to", "md,docx", "--out-mode", "dir", "--out", out, "--json")
    assert proc.returncode == 0, proc.stderr
    assert _tree(out) == ["sub/y.md", "x.docx", "x.md"]
    ev = events(proc)
    assert [e["file"] for e in ev if e["event"] == "skipped"] == [str(a / "cu.doc")]
    assert ev[-1] == {"event": "finished", "ok": 2, "failed": 0, "skipped": 1, "cancelled": False}
    assert not any(".an" in json.dumps(e, ensure_ascii=False) for e in ev)


def test_non_recursive_only_top_level(workdir):
    a = _make_input(workdir)
    proc = run_cli("convert", a, "--to", "md", "--json")
    assert proc.returncode == 0, proc.stderr
    assert (a / "x.md").exists()
    assert not (a / "sub" / "y.md").exists()


def test_partial_failure_continues_batch(workdir, copy_fixture):
    files = [copy_fixture(n) for n in ["danh_sach.csv", "thong_bao.html", "quyet_dinh.docx", "thong_ke.xlsx"]]
    broken = workdir / "hong.pdf"
    broken.write_bytes(b"day khong phai PDF")
    proc = run_cli("convert", *files, broken, "--json")
    assert proc.returncode == 2
    ev = events(proc)
    assert sum(e["event"] == "done" for e in ev) == 4
    errors = [e for e in ev if e["event"] == "error"]
    assert len(errors) == 1 and errors[0]["file"] == str(broken) and errors[0]["message"]
    assert ev[-1]["ok"] == 4 and ev[-1]["failed"] == 1
    assert not list(workdir.glob(".docconv-tmp-*"))
    assert not (workdir / "hong.md").exists()


def test_all_failed_exit_code_1(workdir, copy_fixture):
    src = copy_fixture("cu.doc")
    assert run_cli("convert", src, "--json").returncode == 1


def test_manifest_with_base(workdir):
    a = _make_input(workdir)
    out = workdir / "O"
    manifest = workdir / "jobs.json"
    manifest.write_text(json.dumps([{"src": str(a / "sub" / "y.xlsx"), "base": str(a)}]), encoding="utf-8")
    proc = run_cli("convert", "--manifest", manifest, "--out-mode", "dir", "--out", out, "--json")
    assert proc.returncode == 0, proc.stderr
    assert _tree(out) == ["sub/y.md"]
    done = [e for e in events(proc) if e["event"] == "done"][0]
    assert done["outputs"] == [str(out / "sub" / "y.md")]
