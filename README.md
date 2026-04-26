# NGA-West3 Derived Data Products

This repository documents a reproducible workflow for building derived NGA-West3 data products from the 2025-09-19 public flatfiles.

The GitHub repository is intentionally kept small. It stores scripts, documentation, comparison summaries, and release manifests. Large derived files, such as SQLite and RDS outputs, should be published through Google Drive release folders.

## Repository Contents

```text
scripts/
  build_nga_west3_sqlite.py
  build_nga_west3_rds.R
  compare_official_events_stations.py
docs/
  sqlite_usage.md
  rds_usage.md
  official_api_comparison.md
  official_events_stations_diff.md
  google_drive_release.md
output/official_api_compare/
manifests/
  nga_west3_20250919_manifest.csv
  nga_west3_20250919_SHA256SUMS.txt
```

## Large Data Policy

The following files are not tracked in Git:

- Original component flatfiles: `NGA_West3_*_Flatfile_20250919.csv`
- Derived SQLite database: `output/sqlite/nga_west3_20250919.sqlite`
- Derived RDS files: `output/rds/*.rds`

Publish those files in Google Drive under a versioned folder such as:

```text
NGA-West3/releases/2025-09-19/
```

After uploading, fill the `google_drive_file_id` column in the release manifest if you want stable per-file references.

## Build Outputs

SQLite:

```text
output/sqlite/nga_west3_20250919.sqlite
```

Usage notes are in `docs/sqlite_usage.md`.

RDS:

```text
output/rds/
```

Usage notes are in `docs/rds_usage.md`.

## Prepare a Google Drive Release

Generate manifests and an ignored local staging folder:

```bash
/Users/person/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/prepare_google_drive_release.py
```

To stage hardlinks to the large data files for upload from a single local folder:

```bash
/Users/person/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/prepare_google_drive_release.py --stage-data hardlink
```

The staging folder is:

```text
google_drive_release/2025-09-19/
```

The `sqlite/` and `rds/` subfolders are ignored by Git.

## Verify Downloads

After downloading files from Google Drive, verify checksums:

```bash
shasum -a 256 -c manifests/nga_west3_20250919_SHA256SUMS.txt
```

Run the command from the directory that contains the downloaded `sqlite/` and `rds/` folders.

## Rebuild

Build SQLite:

```bash
/Users/person/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/build_nga_west3_sqlite.py
```

Build RDS:

```bash
/usr/local/bin/Rscript scripts/build_nga_west3_rds.R
```

