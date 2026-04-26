# NGA-West3 Shiny App Development Plan

This plan describes a Shiny dashboard for exploring the derived NGA-West3 SQLite and RDS products. The app should favor fast browsing, filtered maps, server-side tables, and lightweight summary charts without requiring users to load every large data product at startup.

## Backend Strategy

Use a hybrid backend:

- SQLite is the canonical backend for interactive browsing.
- Small RDS cache files accelerate common map and summary views.
- Large RDS flatfiles are lazy-loaded only for R-native exploratory workflows.

This approach is more robust than an all-RDS app for multi-user or deployed Shiny usage, while still preserving the speed of R-native objects where they help most.

### SQLite Responsibilities

Use `output/sqlite/nga_west3_20250919.sqlite` for:

- Map point queries for events, stations, and selected combined views.
- Server-side table browsing and pagination.
- Filter choices for event type, country, network, component, and magnitude/date ranges.
- Aggregations that can be expressed efficiently in SQL, such as counts by event type, country, network, component, and year.
- Canonical joins across `events`, `stations`, `sites`, `networks`, `motions`, `paths`, and `intensity_measures`.

Avoid collecting large tables unless the user explicitly requests an export or a narrowed analysis subset.

### RDS Cache Responsibilities

Create small app-specific cache files, for example:

```text
shiny-app/data/cache/
  events_map.rds
  stations_map.rds
  event_summary.rds
  station_summary.rds
  network_summary.rds
  motion_summary_by_event_station.rds
```

These caches should contain only the columns needed by the app's high-traffic views. They can be regenerated from SQLite and should not be treated as canonical source data.

Suggested cache contents:

- `events_map.rds`: `event_id`, `event_name`, longitude, latitude, `event_type`, simplified source class, country, magnitude, datetime, motion count.
- `stations_map.rds`: `station_id`, `station_code`, station/site coordinates, `network_id`, `network_code`, `network_name`, site country, `vs30`, motion count.
- `event_summary.rds`: counts by event type, simplified source class, country, magnitude bin, and year.
- `station_summary.rds`: counts by country, network, terrain class, and VS30 bin.
- `network_summary.rds`: counts by network type, operation organization, stations, and motions.
- `motion_summary_by_event_station.rds`: compact counts and distance ranges by event/station pair for quick linked views.

### Large RDS Responsibilities

Use `output/rds/*.rds` only when the user enters an analysis-oriented workflow, such as:

- Exploring a component wide flatfile, for example RotD50.
- Plotting PGA/PGV/PSA/EAS distributions from a selected component.
- Exporting an R-native modeling subset.
- Comparing wide component columns without repeated SQL JSON extraction.

Load these objects lazily and show clear loading state. Do not load the full RDS directory at app startup.

## App Structure

Recommended project layout:

```text
shiny-app/
  app.R
  R/
    db.R
    filters.R
    cache.R
    module_overview.R
    module_map.R
    module_tables.R
    module_stats.R
    module_analysis.R
    module_about.R
  data/
    cache/
  www/
  _brand.yml
```

Use `shiny` and `bslib` for a modern Bootstrap 5 dashboard. Prefer `page_navbar()` for top-level navigation, cards for outputs, value boxes for key metrics, and full-screen cards for maps and plots.

## Navigation

### Overview

Show high-level status and counts:

- Events.
- Stations.
- Sites.
- Motions.
- Components.
- Available source classes and countries.

Initial charts:

- Events by source class and event type.
- Events by country.
- Stations by country and network.
- Motions by component.
- Magnitude distribution.

### Map

Provide an interactive map with three modes:

- Epicenters.
- Stations.
- Epicenters and stations.

Map filters:

- Simplified source class: `crustal`, `subduction`, `induced`, `undetermined`.
- Original event type: `Shallow Crustal`, `Interface`, `Intraslab`, `Outer-rise`, `Stable Continental`, `Induced`, `Undetermined`.
- Event country and subdivision.
- Site country and subdivision.
- Network code, name, and type.
- Magnitude range.
- Date range.
- Motion count threshold.

Suggested simplified source-class mapping:

| Simplified Class | Event Types |
|---|---|
| `crustal` | `Shallow Crustal`, `Stable Continental` |
| `subduction` | `Interface`, `Intraslab`, `Outer-rise` |
| `induced` | `Induced` |
| `undetermined` | `Undetermined` |

Performance rules:

- Default to a limited view using common filters or an initial point cap.
- Enable marker clustering by default.
- Warn when a query would return too many points.
- Provide a `Show all` option, but keep it explicit.
- Query only columns required for map markers and popups.
- Prefer precomputed `events_map.rds` and `stations_map.rds` for common map interactions; fall back to SQLite for advanced filters.

### Tables

Use server-side table rendering. `DT` is a good first choice; `reactable` can be considered for smaller, presentation-oriented summary tables.

Table groups should follow the existing SQLite schema:

- Earthquakes: `events`, `event_types`.
- Stations and sites: `stations`, `sites`, `basin_depth_estimates`.
- Networks: `networks`.
- Ground motions: `motions`, `paths`, `time_series_metadata`, `intensity_measures`.
- Spectra metadata: `spectral_axes`, `response_spectra`, `effective_amplitude_spectra`.
- Documentation: `release_files`, `field_catalog`, `code_definitions`, `citations`.

Implementation notes:

- Use server-side pagination and search.
- Default to common columns for large tables.
- Offer advanced column selection.
- Avoid expanding spectral JSON arrays in general table views.
- Export only the currently filtered result set.

### Statistics

Use SQLite aggregations or small RDS summary caches for:

- Event count by event type, simplified source class, country, and year.
- Station count by country, network, terrain class, and VS30 bin.
- Motion count by component, event type, network, and magnitude bin.
- Magnitude histogram.
- RRUP/RJB distributions.
- VS30 distribution.
- PGA/PGV distributions by component.

Use `ggplot2` for static plots and add `plotly` only when interaction materially improves exploration.

### Analysis

This page can use lazy-loaded RDS flatfiles:

- Select component: H1, H2, V, RotD0, RotD50, RotD100, EAS.
- Load selected RDS on demand.
- Filter by magnitude, distance, VS30, country, event type, and network.
- Preview selected wide columns.
- Produce quick plots for PGA/PGV/PSA/EAS distributions.
- Export filtered modeling subsets.

Keep this separate from the main browsing pages so normal users do not pay the memory cost.

### About

Include:

- Data version: `2025-09-19`.
- Links to SQLite and RDS usage docs.
- Google Drive release instructions.
- Checksum verification instructions.
- A brief note explaining the hybrid backend.

## Implementation Phases

### Phase 1: Skeleton and Data Access

- Create `shiny-app/` structure.
- Add `bslib::page_navbar()` UI.
- Implement SQLite connection helper.
- Implement cache detection helper.
- Add overview value boxes.

### Phase 2: Map

- Build map UI and server module.
- Add event/station/map mode selector.
- Add source class, event type, country, network, magnitude, and date filters.
- Add marker clustering and point-count safeguards.
- Generate first `events_map.rds` and `stations_map.rds` caches.

### Phase 3: Tables

- Implement table selector by schema group.
- Use server-side `DT`.
- Add common-column defaults and advanced columns.
- Add filtered CSV export.

### Phase 4: Statistics

- Build summary query functions.
- Add core count charts and histograms.
- Use cached summaries where helpful.
- Add linked filters shared with the map where practical.

### Phase 5: RDS Analysis

- Add lazy RDS loading for selected component files.
- Add analysis filters and preview table.
- Add quick distribution plots.
- Add export of filtered modeling subset.

### Phase 6: Polish and Deployment

- Add loading states, empty states, and friendly query warnings.
- Add app-level theme with `bslib`.
- Add README for running the Shiny app.
- Add smoke tests for DB availability and key query functions.
- Document memory expectations for local and deployed usage.

## Initial Package List

Core:

- `shiny`
- `bslib`
- `DBI`
- `RSQLite`
- `dplyr`
- `dbplyr`
- `data.table`

UI and outputs:

- `leaflet`
- `DT`
- `ggplot2`
- `plotly`
- `bsicons`

Optional:

- `reactable`
- `memoise`
- `cachem`
- `promises`
- `mirai`

