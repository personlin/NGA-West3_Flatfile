# NGA-West3 Shiny Explorer

Run from the repository root:

```r
shiny::runApp("shiny-app")
```

The app uses `output/sqlite/nga_west3_20250919.sqlite` for browsing and `output/rds/` for lazy component analysis. You can override those paths with:

```bash
export NGA_WEST3_SQLITE=/path/to/nga_west3_20250919.sqlite
export NGA_WEST3_RDS_DIR=/path/to/rds
```

Optional packages unlock richer views:

- `leaflet` for the map.
- `DT` for interactive tables.
- `ggplot2` and `thematic` for polished plots.

Regenerate small app caches from R:

```r
source("shiny-app/R/db.R")
source("shiny-app/R/filters.R")
source("shiny-app/R/cache.R")
build_app_caches()
```
