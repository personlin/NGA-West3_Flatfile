# NGA-West3 RDS Files Usage

本資料夾提供 R 使用者可直接讀取的 `.rds` 檔案。SQLite 版本負責 normalized relational querying；RDS 版本則偏向 R/data.table 的建模與資料探索工作流，保留各 component flatfile 的 wide shape，方便直接選欄、join 與轉 long。

輸出位置：

```text
output/rds/
```

## 檔案內容

| File | 說明 |
|---|---|
| `nga_west3_core_normalized.rds` | list，包含 events、finite faults、segments、networks、stations、sites、basin depth estimates、motion/path/processing core、C1/C2 classifications、documentation |
| `nga_west3_h1_flatfile.rds` | H1 component wide flatfile |
| `nga_west3_h2_flatfile.rds` | H2 component wide flatfile |
| `nga_west3_v_flatfile.rds` | Vertical component wide flatfile |
| `nga_west3_rotd0_flatfile.rds` | RotD0 wide flatfile |
| `nga_west3_rotd50_flatfile.rds` | RotD50 wide flatfile |
| `nga_west3_rotd100_flatfile.rds` | RotD100 wide flatfile |
| `nga_west3_eas_flatfile.rds` | EAS wide flatfile |
| `nga_west3_rds_manifest.rds` / `.csv` | RDS 檔案清單、筆數、欄位數 |

所有 component flatfile RDS 已排除原始 release 中 `motion_id = -999` 的 placeholder rows；每個 component 皆為 175,244 筆有效 records。

## 基本讀取

```r
library(data.table)

core <- readRDS("output/rds/nga_west3_core_normalized.rds")
manifest <- readRDS("output/rds/nga_west3_rds_manifest.rds")
rotd50 <- readRDS("output/rds/nga_west3_rotd50_flatfile.rds")

manifest
names(core)
nrow(rotd50)
```

## Core Object 結構

`nga_west3_core_normalized.rds` 是一個 named list：

```r
names(core)
```

主要元素：

```text
events
event_types
finite_faults
finite_fault_kinematic_parameters
finite_fault_segments
networks
stations
sites
basin_depth_estimates
motion_path_processing
c1c2_classifications
documentation
```

`documentation` 內含原始 Excel documentation 的欄位說明與 code tables，可用於查欄位定義。

## 範例：RotD50 建模資料

```r
library(data.table)

core <- readRDS("output/rds/nga_west3_core_normalized.rds")
rotd50 <- readRDS("output/rds/nga_west3_rotd50_flatfile.rds")

model_dt <- rotd50[
  magnitude >= 5 &
    rrup <= 100 &
    vs30 > 0,
  .(
    motion_id,
    event_id,
    station_id,
    magnitude,
    rrup,
    rjb,
    vs30,
    pga_rotd50,
    `psa_rotd50(1p000s)`
  )
]

summary(model_dt)
```

## 範例：使用 core tables join

```r
library(data.table)

core <- readRDS("output/rds/nga_west3_core_normalized.rds")
setDT(core$events)
setDT(core$stations)
setDT(core$sites)
setDT(core$motion_path_processing)

motion_core <- core$motion_path_processing[
  ,
  .(motion_id, event_id, station_id, path_id, rrup, ravg, processing_type)
]

motion_core <- merge(
  motion_core,
  core$events[, .(event_id, event_name, magnitude, event_country, event_type)],
  by = "event_id",
  all.x = TRUE
)

station_site <- merge(
  core$stations[, .(station_id, site_id, station_code, network_id)],
  core$sites[, .(site_id, vs30, z1p0_preferred, z2p5_preferred)],
  by = "site_id",
  all.x = TRUE
)

motion_core <- merge(motion_core, station_site, by = "station_id", all.x = TRUE)
```

## 範例：轉 PSA 欄位為 long format

```r
library(data.table)

rotd50 <- readRDS("output/rds/nga_west3_rotd50_flatfile.rds")
psa_cols <- grep("^psa_rotd50\\(", names(rotd50), value = TRUE)

psa_long <- melt(
  rotd50,
  id.vars = c("motion_id", "event_id", "station_id", "rrup", "magnitude", "vs30"),
  measure.vars = psa_cols,
  variable.name = "period_field",
  value.name = "psa"
)

psa_long[, period_s := as.numeric(
  sub("p", ".", sub("^psa_rotd50\\((.*)s\\)$", "\\1", period_field), fixed = TRUE)
)]
```

## 重建 RDS

```bash
Rscript scripts/build_nga_west3_rds.R
```

腳本會覆寫 `output/rds/` 中的 RDS 與 manifest。

## 驗證摘要

本次輸出：

```text
H1: 175244 rows, 299 columns
H2: 175244 rows, 299 columns
V: 175244 rows, 314 columns
RotD0: 175244 rows, 280 columns
RotD50: 175244 rows, 280 columns
RotD100: 175244 rows, 280 columns
EAS: 175244 rows, 555 columns
core motion_path_processing: 175244 rows
invalid motion_id=-999 rows: 0
```
