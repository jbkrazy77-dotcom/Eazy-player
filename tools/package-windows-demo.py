#!/usr/bin/env python3
"""Build a clean, deterministic-layout ZIP for the Windows/WSL demo release."""
from __future__ import annotations

import stat
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "5.2.0-rev45"
PACKAGE_NAME = f"Eazy-player-windows-demo-{VERSION}"
SOURCE_ROOTS = ("README.md", "INSTALL.md", "CHANGELOG.md", "VERSION", "windows-demo")
EXCLUDED_DIRS = {".git", "__pycache__"}
EXCLUDED_SUFFIXES = {".pyc", ".bak"}
EXCLUDED_NAMES = {"eazy.bak_live"}


def should_skip(path: Path) -> bool:
    if path.name in EXCLUDED_DIRS or path.name in EXCLUDED_NAMES:
        return True
    return path.suffix.lower() in EXCLUDED_SUFFIXES


def main() -> int:
    output = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "dist" / f"eazy-windows-demo-{VERSION}.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for entry in SOURCE_ROOTS:
            source = ROOT / entry
            if not source.exists():
                raise SystemExit(f"Required package path is missing: {source}")
            paths = [source] if source.is_file() else sorted(source.rglob("*"))
            for path in paths:
                if should_skip(path) or any(should_skip(parent) for parent in path.parents if parent != ROOT):
                    continue
                if path.is_dir():
                    continue
                relative = path.relative_to(ROOT)
                archive_name = Path(PACKAGE_NAME) / relative
                info = zipfile.ZipInfo(archive_name.as_posix())
                info.compress_type = zipfile.ZIP_DEFLATED
                info.create_system = 3
                mode = stat.S_IMODE(path.stat().st_mode)
                info.external_attr = (mode & 0xFFFF) << 16
                archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f"ZIP integrity test failed at {bad}")
    print(f"Created {output} ({output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
