#!/usr/bin/env python3
"""
Prepare manifest/checksum files and an optional Google Drive staging folder.

By default this script writes only lightweight metadata files. Use
--stage-data hardlink to place the large SQLite/RDS outputs into the local
Google Drive release folder without duplicating disk blocks on the same volume.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE = "2025-09-19"
SOURCE_VERSION = "20250919"

MANIFEST_DIR = ROOT / "manifests"
STAGING_DIR = ROOT / "google_drive_release" / RELEASE


@dataclass(frozen=True)
class ReleaseFile:
    source: Path
    relative_path: str
    format: str
    description: str


RELEASE_FILES = [
    ReleaseFile(
        ROOT / "output" / "sqlite" / "nga_west3_20250919.sqlite",
        "sqlite/nga_west3_20250919.sqlite",
        "sqlite",
        "Normalized SQLite database reconstructed from public NGA-West3 flatfiles.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_core_normalized.rds",
        "rds/nga_west3_core_normalized.rds",
        "rds",
        "R list containing normalized core tables and documentation tables.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_h1_flatfile.rds",
        "rds/nga_west3_h1_flatfile.rds",
        "rds",
        "H1 component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_h2_flatfile.rds",
        "rds/nga_west3_h2_flatfile.rds",
        "rds",
        "H2 component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_v_flatfile.rds",
        "rds/nga_west3_v_flatfile.rds",
        "rds",
        "Vertical component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_rotd0_flatfile.rds",
        "rds/nga_west3_rotd0_flatfile.rds",
        "rds",
        "RotD0 component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_rotd50_flatfile.rds",
        "rds/nga_west3_rotd50_flatfile.rds",
        "rds",
        "RotD50 component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_rotd100_flatfile.rds",
        "rds/nga_west3_rotd100_flatfile.rds",
        "rds",
        "RotD100 component wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_eas_flatfile.rds",
        "rds/nga_west3_eas_flatfile.rds",
        "rds",
        "EAS wide flatfile for R users.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_rds_manifest.csv",
        "rds/nga_west3_rds_manifest.csv",
        "csv",
        "RDS component manifest produced by the RDS build script.",
    ),
    ReleaseFile(
        ROOT / "output" / "rds" / "nga_west3_rds_manifest.rds",
        "rds/nga_west3_rds_manifest.rds",
        "rds",
        "RDS component manifest in RDS format.",
    ),
]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_rows() -> list[dict[str, str]]:
    created_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    rows: list[dict[str, str]] = []
    missing = [item.source for item in RELEASE_FILES if not item.source.exists()]
    if missing:
        formatted = "\n".join(f"  - {path.relative_to(ROOT)}" for path in missing)
        raise FileNotFoundError(f"Missing release files:\n{formatted}")

    for item in RELEASE_FILES:
        rows.append(
            {
                "release": RELEASE,
                "relative_path": item.relative_path,
                "file_name": Path(item.relative_path).name,
                "format": item.format,
                "description": item.description,
                "size_bytes": str(item.source.stat().st_size),
                "sha256": sha256_file(item.source),
                "google_drive_file_id": "",
                "source_version": SOURCE_VERSION,
                "created_at_utc": created_at,
            }
        )
    return rows


def write_manifest(rows: list[dict[str, str]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_checksums(rows: list[dict[str, str]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(f"{row['sha256']}  {row['relative_path']}\n")


def write_release_readme(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""# NGA-West3 Derived Data Release {RELEASE}

This folder contains large derived NGA-West3 data products that are indexed by the GitHub repository.

## Files

- `sqlite/nga_west3_20250919.sqlite`: normalized SQLite database.
- `rds/*.rds`: R-friendly derived data products.
- `manifest.csv`: file sizes, SHA-256 checksums, descriptions, and optional Google Drive file IDs.
- `SHA256SUMS.txt`: checksum file for command-line verification.

## Verify

Run this from the release folder after download:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## Usage

See the GitHub repository documentation:

- `docs/sqlite_usage.md`
- `docs/rds_usage.md`
- `docs/google_drive_release.md`
""",
        encoding="utf-8",
    )


def stage_file(source: Path, destination: Path, mode: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination.unlink()
    if mode == "hardlink":
        try:
            os.link(source, destination)
            return
        except OSError:
            shutil.copy2(source, destination)
            return
    if mode == "copy":
        shutil.copy2(source, destination)


def stage_data(mode: str) -> None:
    if mode == "none":
        return
    for item in RELEASE_FILES:
        stage_file(item.source, STAGING_DIR / item.relative_path, mode)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stage-data",
        choices=("none", "hardlink", "copy"),
        default="none",
        help="Optionally stage large data files into google_drive_release/.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rows = build_rows()

    manifest_path = MANIFEST_DIR / "nga_west3_20250919_manifest.csv"
    checksum_path = MANIFEST_DIR / "nga_west3_20250919_SHA256SUMS.txt"
    write_manifest(rows, manifest_path)
    write_checksums(rows, checksum_path)

    write_release_readme(STAGING_DIR / "README.md")
    write_manifest(rows, STAGING_DIR / "manifest.csv")
    write_checksums(rows, STAGING_DIR / "SHA256SUMS.txt")
    stage_data(args.stage_data)

    print(f"Wrote {manifest_path.relative_to(ROOT)}")
    print(f"Wrote {checksum_path.relative_to(ROOT)}")
    print(f"Wrote {STAGING_DIR.relative_to(ROOT)}")
    if args.stage_data == "none":
        print("Large data files were not staged. Use --stage-data hardlink before uploading to Drive.")
    else:
        print(f"Large data files staged with mode: {args.stage_data}")


if __name__ == "__main__":
    main()
