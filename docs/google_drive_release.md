# Google Drive Release Design

Use Google Drive as the distribution location for large derived products, and use GitHub as the reproducible index.

## Folder Layout

Recommended Drive structure:

```text
NGA-West3/
  releases/
    2025-09-19/
      README.md
      manifest.csv
      SHA256SUMS.txt
      sqlite/
        nga_west3_20250919.sqlite
      rds/
        nga_west3_core_normalized.rds
        nga_west3_h1_flatfile.rds
        nga_west3_h2_flatfile.rds
        nga_west3_v_flatfile.rds
        nga_west3_rotd0_flatfile.rds
        nga_west3_rotd50_flatfile.rds
        nga_west3_rotd100_flatfile.rds
        nga_west3_eas_flatfile.rds
        nga_west3_rds_manifest.csv
        nga_west3_rds_manifest.rds
```

Keep release folders immutable. If a file changes, create a new folder such as `2026-01-15/` instead of overwriting `2025-09-19/`.

## Sharing

Set the release folder to:

- General access: `Anyone with the link`
- Role: `Viewer`

Avoid granting edit access to public users. If a smaller group needs write access, create a separate private working folder and copy finalized files into the public release folder.

## Manifest Columns

The generated manifest contains:

- `release`: release label
- `relative_path`: path inside the Google Drive release folder
- `file_name`: file basename
- `format`: `sqlite`, `rds`, or `csv`
- `description`: human-readable purpose
- `size_bytes`: file size at manifest generation time
- `sha256`: SHA-256 digest
- `google_drive_file_id`: blank placeholder for the Drive file ID after upload
- `source_version`: source flatfile release date
- `created_at_utc`: manifest generation timestamp

After uploading files to Drive, optionally fill `google_drive_file_id` and commit the updated manifest to GitHub.

## Local Staging

Run:

```bash
python3 scripts/prepare_google_drive_release.py --stage-data hardlink
```

This creates:

```text
google_drive_release/2025-09-19/
```

The script hardlinks large data files where possible, so staging usually does not duplicate disk usage. Upload the release folder through Google Drive for desktop or the Drive web UI.

## Download From GitHub Checkout

The current Drive release folder is:

```text
https://drive.google.com/drive/folders/1qXa_GaiXaKVFSx6PQeF3nx_cu7kAYT8Y
```

After the Drive release manifest contains `google_drive_file_id` values, users can download the SQLite database required by the Shiny app into `output/sqlite/`:

```bash
python3 scripts/download_nga_west3_release.py
```

To download the optional RDS products into `output/rds/` too:

```bash
python3 scripts/download_nga_west3_release.py --include-rds
```

The downloader verifies SHA-256 checksums from `manifests/nga_west3_20250919_manifest.csv` after each file is downloaded.
