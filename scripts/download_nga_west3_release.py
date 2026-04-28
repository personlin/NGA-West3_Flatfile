#!/usr/bin/env python3
"""
Download derived NGA-West3 products from the Google Drive release.

By default this downloads the SQLite database needed for the Shiny app.
Use --include-rds to download the optional RDS products for analysis workflows.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
from pathlib import Path
from urllib.parse import quote, unquote
from urllib.request import Request, build_opener


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "manifests" / "nga_west3_20250919_manifest.csv"
CHUNK_SIZE = 1024 * 1024


class DownloadError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def selected_rows(rows: list[dict[str, str]], include_rds: bool) -> list[dict[str, str]]:
    selected = []
    for row in rows:
        rel = row["relative_path"]
        if rel.startswith("sqlite/"):
            selected.append(row)
        elif include_rds and rel.startswith("rds/"):
            selected.append(row)
    return selected



def filename_from_disposition(header: str | None) -> str | None:
    if not header:
        return None
    match = re.search(r'filename\*=UTF-8\'\'([^;]+)', header)
    if match:
        return unquote(match.group(1))
    match = re.search(r'filename="?([^";]+)"?', header)
    if match:
        return match.group(1)
    return None


def request(opener, url: str):
    return opener.open(Request(url, headers={"User-Agent": "nga-west3-downloader/1.0"}))


def download_drive_file(file_id: str, destination: Path) -> None:
    opener = build_opener()
    # Use the usercontent endpoint with confirm=t to bypass the virus-scan warning
    # page that Google Drive shows for large files (the old /uc?export=download
    # confirmation-token flow no longer works reliably).
    url = f"https://drive.usercontent.google.com/download?id={quote(file_id)}&export=download&authuser=0&confirm=t"
    response = request(opener, url)
    content_type = response.headers.get("Content-Type", "")

    if "text/html" in content_type:
        html = response.read().decode("utf-8", errors="replace")
        if "You need access" in html or "Sign in" in html:
            raise DownloadError(f"Google Drive file {file_id} is not publicly downloadable.")
        raise DownloadError(f"Unexpected HTML response downloading {file_id}. The file may not be publicly shared.")

    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_suffix(destination.suffix + ".part")
    total = response.headers.get("Content-Length")
    total_size = int(total) if total and total.isdigit() else None
    downloaded = 0
    with tmp.open("wb") as fh:
        while True:
            chunk = response.read(CHUNK_SIZE)
            if not chunk:
                break
            fh.write(chunk)
            downloaded += len(chunk)
            if total_size:
                percent = downloaded / total_size * 100
                print(f"\r  {destination.name}: {percent:5.1f}%", end="", flush=True)
    if total_size:
        print()
    tmp.replace(destination)

    received_name = filename_from_disposition(response.headers.get("Content-Disposition"))
    if received_name and received_name != destination.name:
        print(f"  note: downloaded file name is {received_name}, saved as {destination.name}")


def download_rows(rows: list[dict[str, str]], output_dir: Path, overwrite: bool) -> None:
    missing_ids = [row["relative_path"] for row in rows if not row.get("google_drive_file_id")]
    if missing_ids:
        raise DownloadError(
            "Manifest is missing google_drive_file_id values for:\n"
            + "\n".join(f"  - {path}" for path in missing_ids)
        )

    for row in rows:
        destination = output_dir / row["relative_path"]
        if destination.exists() and not overwrite:
            existing_hash = sha256_file(destination)
            if existing_hash == row["sha256"]:
                print(f"ok: {row['relative_path']}")
                continue
            raise DownloadError(f"{destination} exists but checksum does not match. Use --overwrite to replace it.")

        print(f"downloading: {row['relative_path']}")
        download_drive_file(row["google_drive_file_id"], destination)
        digest = sha256_file(destination)
        if digest != row["sha256"]:
            destination.unlink(missing_ok=True)
            raise DownloadError(f"Checksum mismatch for {row['relative_path']}.")
        print(f"verified: {row['relative_path']}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="Release manifest with Google Drive file IDs.")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "output", help="Directory that will receive sqlite/ and rds/ subdirectories.")
    parser.add_argument("--include-rds", action="store_true", help="Download RDS products in addition to Shiny SQLite data.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing files.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = selected_rows(read_manifest(args.manifest), include_rds=args.include_rds)
    try:
        download_rows(rows, args.output_dir, overwrite=args.overwrite)
    except DownloadError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
