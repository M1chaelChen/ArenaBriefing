#!/usr/bin/env python3
"""Package only the TOC and its explicitly listed Lua files."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).resolve().parents[1]
addon = root / "ArenaBriefing"
toc = addon / "ArenaBriefing.toc"
files = [toc] + [addon / line.strip() for line in toc.read_text().splitlines()
                 if line.strip() and not line.startswith("#")]
output = root / "dist/ArenaBriefing-0.1.2.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    for path in files:
        if not path.is_file() or path.parent != addon:
            raise ValueError(f"Invalid manifest entry: {path}")
        archive.write(path, path.relative_to(root))
    archive.write(root / "README.md", "ArenaBriefing/README.md")
    archive.write(root / "LICENSE", "ArenaBriefing/LICENSE")
print(output)
