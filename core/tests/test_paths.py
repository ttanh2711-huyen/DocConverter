from pathlib import Path

from docconv.paths import dest_dir, unique


def test_dest_dir_beside():
    assert dest_dir(Path("/a/b/x.pdf"), base=Path("/a"), out_mode="beside", out=None) == Path("/a/b")


def test_dest_dir_mirrors_structure_under_out():
    src = Path("/in/sub/deep/x.pdf")
    assert dest_dir(src, base=Path("/in"), out_mode="dir", out=Path("/out")) == Path("/out/sub/deep")


def test_dest_dir_file_directly_in_base():
    assert dest_dir(Path("/in/x.pdf"), base=Path("/in"), out_mode="dir", out=Path("/out")) == Path("/out")


def test_dest_dir_base_not_ancestor_falls_back_to_out_root():
    assert dest_dir(Path("/other/x.pdf"), base=Path("/in"), out_mode="dir", out=Path("/out")) == Path("/out")


def test_unique(tmp_path):
    p = tmp_path / "a.md"
    assert unique(p) == p
    p.write_text("x")
    assert unique(p) == tmp_path / "a (1).md"
    (tmp_path / "a (1)_assets").mkdir()
    assert unique(p) == tmp_path / "a (2).md"
    assert unique(tmp_path / "a (1).docx") == tmp_path / "a (1).docx"
