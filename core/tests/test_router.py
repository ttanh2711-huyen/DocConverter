from pathlib import Path

import pytest

from docconv.router import UnsupportedFormat, kind_of


@pytest.mark.parametrize("name, kind", [
    ("a.pdf", "pdf"), ("A.PDF", "pdf"),
    ("a.docx", "markitdown"), ("a.xlsx", "markitdown"), ("a.xls", "markitdown"),
    ("a.pptx", "markitdown"), ("a.html", "markitdown"), ("a.htm", "markitdown"),
    ("a.csv", "markitdown"), ("a.json", "markitdown"), ("a.xml", "markitdown"),
    ("a.epub", "markitdown"), ("a.zip", "markitdown"), ("a.msg", "markitdown"),
    ("a.jpg", "markitdown"), ("a.png", "markitdown"), ("a.txt", "markitdown"),
])
def test_kind_of_supported(name, kind):
    assert kind_of(Path(name)) == kind


@pytest.mark.parametrize("name", ["a.doc", "a.ppt", "a.pages", "noext"])
def test_kind_of_unsupported(name):
    with pytest.raises(UnsupportedFormat, match="Không hỗ trợ định dạng"):
        kind_of(Path(name))
