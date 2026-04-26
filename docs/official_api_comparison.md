# 本地 NGA-West3 SQLite/RDS 與官方 Ground Motion Database API 差異比較

比較對象：

- 官方 API 文件：<https://gmdatabase.org/pages/api_documentation>
- 官方 schema 頁：<https://gmdatabase.org/schema>
- 本地 SQLite：`output/sqlite/nga_west3_20250919.sqlite`
- 本地 RDS：`output/rds/`

## 一句話結論

官方 API 是 Ground Motion Database 的線上 operational database 查詢介面，包含版本、權限、collection、geometry、time-series、完整 citation/junction table，以及官方的 table/flatfile endpoint 邏輯。

本地資料庫是由 NGA-West3 2025-09-19 public flatfiles 反推建立的離線分析資料庫。它保留 release flatfiles 中可取得的 source、station/site、motion/path、processing metadata、IM、PSA、EAS 與 documentation，但不包含未隨 flatfiles 發布的 operational GMDB 內部資料與 API 行為。

## 主要差異總表

| 面向 | 官方 GMDB API / schema | 本地 SQLite/RDS |
|---|---|---|
| 資料來源 | 線上 GMDB operational database | 2025-09-19 release flatfiles |
| 使用方式 | HTTP API，需登入取得 bearer token | 本地 SQLite / RDS 檔案，不需網路與登入 |
| 權限模型 | 依 user/modeler/admin role 控制資料可見性 | 無權限控管；只包含本地 release 中已有資料 |
| 資料筆數 | 官方 schema 目前列出 `motion` 191,822、`event` 7,496、`station` 14,153 | 本地有效 `motions` 175,244、`events` 7,309、`stations` 13,398 |
| time series | 有 `time_series_data`，保存 `acc_h1/acc_h2/acc_v` JSON | 沒有 time-series acceleration histories，因 release flatfiles 未提供 |
| spectra 結構 | 官方底層有 `response_spectra`/`fourier_spectra` ordinate table；schema 也列出 `psa_h1` 等 component-wide tables | PSA/EAS 用 `spectral_axes` + JSON array 保存，避免上億列 long table |
| flatfile endpoint | 官方 API 可即時 join tables，並用 query string 選 fields/components | 本地已預先 materialize 成 normalized tables；RDS 保留 component wide flatfiles |
| collection/version | 有 `collection`、`collection_motion`、`version`、`version_time_series_metadata` | 無完整 collection/version 系統；只以 `release_files` 記錄來源檔與 SHA-256 |
| geometry | 有 `geometry`、`event_geometry`、`site_geometry`，GeoJSON 與 spatial metadata | 未納入 GeoJSON geometry，因本次 release 主要 flatfiles 未提供完整 geometry objects |
| ID mapping | 有 `event_eqid`、`station_ssn` junction tables，可支援多 collection ID | 本地把 `NGA_West2_EQID/SSN/RSN` 直接放在 `events/stations/motions` |
| citations | 官方 `citation` 有 text、url、hash | 本地 `citations` 由 documentation Excel 匯入，欄位簡化為 citation/doi_or_url |
| API query behavior | 支援 pagination、sort、where、contain、matching、flatfile params | 沒有 HTTP endpoint；使用 SQL 或 R/data.table 自行查詢 |

## Table-by-table 對照

### 本地有、官方也有或可對應

| 本地 table | 官方對應 | 差異 |
|---|---|---|
| `events` | `event` | 本地多放 `nga_west2_eqid` 與 `event_type` 文字；官方 ID mapping 在 `event_eqid` |
| `event_types` | `event_type` | 對應 |
| `finite_faults` | `finite_fault` | 本地欄位來自 source flatfile，缺官方 `ffm_reference` |
| `finite_fault_kinematic_parameters` | `finite_fault_kinematic_parameter` | 本地額外保留 `event_id` 方便 join |
| `finite_fault_segments` | `finite_fault_segment` | 本地沒有官方 `finite_fault_segment_id`；以 `(event_id, finite_fault_id, segment_index)` 作 composite key |
| `networks` | `network` | 對應，欄位來自 station metadata flatfile |
| `stations` | `station` | 本地缺 `station_elevation`；多放 `nga_west2_ssn` |
| `sites` | `site` | 本地包含 release flatfile 中的 WNA/NZ/Taiwan 等額外 site descriptors；缺官方完整 geometry junction |
| `basin_depth_estimates` | `basin_site` + `basin_model` | 本地以 `model_name` 文字直接表示 model，沒有 `basin_model_id` 外鍵表 |
| `motions` | `motion` | 本地多放 NGA-West2 mapping 與 `nyquist_frequency`；官方 mapping 在 junction tables |
| `paths` | `path` | 對應，欄位來自 H1 flatfile core |
| `time_series_metadata` | `time_series_metadata` | 本地缺 `user_id`、`public_time_series`、`konno_omachi_points`、`smoothing_bandwidth`、`window_width`；EAS smoothing metadata 移到 `effective_amplitude_spectra` |
| `intensity_measures` | `intensity_measure` | 官方是一列含多 component 欄位；本地拆成 `(motion_id, component)` long-ish 形式 |
| `response_spectra` | `response_spectra` / `psa_*` | 官方可用 ordinate table 或 API flattened component columns；本地每 motion+component 一個 JSON array |
| `effective_amplitude_spectra` | `fourier_spectra` | 官方 `fourier_spectra` 可含 `fas_h1/fas_h2/fas_v/eas`；本地只保存 release EAS，不保存 FAS |
| `c1c2_classifications` | official supplement / aftershock-mainshock concept | 本地來自 `NGA_West3_C1C2_North_America_20250919.xlsx`，不是官方 core table |
| `citations` | `citation` | 本地簡化欄位，沒有 `citation_hash` |
| `code_definitions` | `vs30_code`、`z_code`、housing docs、COSMOS docs | 本地把多個 code sheet 合併在一張 generalized lookup table |

### 官方有、本地沒有

| 官方 table / API resource | 本地狀態 | 影響 |
|---|---|---|
| `aftershock_mainshock` | 無 | 本地只有 C1/C2 supplementary classification，沒有完整 aftershock-mainshock pair CRJB table |
| `basin_model` | 無獨立表 | 本地 basin model 只用文字欄位 |
| `collection`、`collection_motion` | 無 | 無法重現官方 collection grouping 與 per-collection record sequence number 系統 |
| `event_eqid`、`station_ssn` | 無獨立 junction table | 本地只保留 NGA-West2 ID 欄位，不能支援多 collection ID mapping |
| `event_geometry`、`site_geometry`、`geometry` | 無 | 無法做官方 GeoJSON region/basin/geometry 關聯查詢 |
| `time_series_data` | 無 | 本地無 acceleration time histories，只能用 IM/spectra/metadata |
| `version`、`version_time_series_metadata` | 無 | 無官方 schema-level version tracking |
| `vs30_citation` | 無 | 本地 site 只有 citation id 欄位，沒有多 citation junction |
| `frequencies`、`periods` | 無獨立表 | 本地用 `spectral_axes` 同時表達 PSA periods 與 EAS frequencies |
| `psa_h1`、`psa_h2`、`psa_v`、`psa_rotd0`、`psa_rotd50`、`psa_rotd100` | 無同名表 | 本地 `response_spectra` 以 component + JSON array 統一保存 |
| `fourier_spectra.fas_h1/fas_h2/fas_v` | 無 | 本地 release 只有 EAS flatfile，未重建 FAS |

### 本地有、官方沒有同名 core table

| 本地 table | 用途 |
|---|---|
| `release_files` | 保存本次 release 檔案角色、筆數、欄位數、SHA-256 |
| `field_catalog` | 保存 Excel documentation 的欄位說明 |
| `code_definitions` | 合併 housing、COSMOS、VS30、Z code documentation |
| `spectral_axes` | 保存 PSA period / EAS frequency 座標軸，對應 JSON array index |
| `effective_amplitude_spectra` | release EAS 的 compact representation |
| `c1c2_classifications` | 北美 C1/C2 supplementary workbook |

## Spectra 結構差異

官方文件指出 `response_spectra` 與 `fourier_spectra` 底層每個 ordinate 有自己的 row，例如 `response_spectra_id, period, psa_rotd0, psa_rotd50, ...`。API 為了使用者便利，會把 view flatten 成每列一個 motion/time-series，並用欄名如 `psa_rotd50_0p100` 查詢與排序。

本地 SQLite 則採用：

```text
spectral_axes(spectrum_type, component, ordinate_index, axis_value, axis_unit, source_field)
response_spectra(motion_id, component, damping, psa_json)
effective_amplitude_spectra(motion_id, konno_omachi_points, smoothing_bandwidth, window_width, eas_json)
```

原因是 release CSV 已經是 wide flatfile，若全部轉成 ordinate long table，PSA 會產生約：

```text
175244 motions * 6 components * 111 periods = 116,712,504 rows
```

EAS 也會增加約：

```text
175244 motions * 389 frequencies = 68,169,916 rows
```

因此本地以 JSON array 保持完整 ordinate，同時透過 `spectral_axes` 保留 period/frequency 對照。

## API 行為差異

官方 API 支援：

- `/events?limit=20&sort=magnitude&direction=desc`
- `/responseSpectra?sort=psa_rotd50_0p10`
- `/flatfile?response_spectra_components=psa_rotd50&fields=...`
- `where`、`contain`、`matching`、pagination、role-based access

本地 SQLite 不提供 HTTP API，但可用 SQL 完成相同查詢。例：

```sql
WITH axis AS (
  SELECT ordinate_index - 1 AS json_index
  FROM spectral_axes
  WHERE spectrum_type = 'PSA'
    AND component = 'RotD50'
    AND axis_value = 0.1
)
SELECT
  m.motion_id,
  e.event_name,
  e.magnitude,
  json_extract(rs.psa_json, '$[' || axis.json_index || ']') AS psa_rotd50_0p1s
FROM motions AS m
JOIN events AS e USING (event_id)
JOIN response_spectra AS rs
  ON rs.motion_id = m.motion_id AND rs.component = 'RotD50'
CROSS JOIN axis
ORDER BY psa_rotd50_0p1s DESC
LIMIT 20;
```

## 實務建議

若目標是重現官方 API：

1. 需要新增 API-compatible views，例如 `flatfile_view`、`response_spectra_flat_view`。
2. 可把 `response_spectra` JSON 展開為 view，而不是實體 long table。
3. 若需要與官方 endpoint 命名一致，可新增 views：`event`, `motion`, `site`, `station`, `path`, `intensity_measure` 等單數表名或 camelCase API adapter。
4. 若要完整追上官方 schema，必須從官方 API 或其他 supplementary release 補入 geometry、collection、version、time_series_data、vs30_citation、aftershock_mainshock、FAS 等資料。
5. 若只做 model development 或資料分析，目前本地結構更輕、更離線友善；若要與官方 API 查詢結果逐欄一致，則需要建立 compatibility layer。
