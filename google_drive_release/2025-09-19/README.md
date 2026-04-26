# NGA-West3 Derived Data Release 2025-09-19

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
