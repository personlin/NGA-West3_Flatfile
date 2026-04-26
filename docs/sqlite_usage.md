# NGA-West3 SQLite Database Usage

本資料庫由 NGA-West3 2025-09-19 public flatfiles 重新建置，依據 `GIRS-2025-07_Data Resources for NGA-West3 Project.pdf` 第 2 章對資料資源的描述，將 release 中可取得的 source、station-site、ground-motion flatfiles 與 supplementary metadata 拆成較適合後續應用的關聯式表格。

輸出檔案：

```text
output/sqlite/nga_west3_20250919.sqlite
```

## 建置依據與處理原則

- 報告指出正式 GMDB 為 32 張關聯式表，並以九類 flatfile 對 model developers 發布：source metadata、station metadata、H1、H2、V、RotD0、RotD50、RotD100、EAS。
- 本專案只有 release flatfiles，沒有完整 operational GMDB dump；因此此 SQLite 是由 flatfiles 反推的 normalized application database，不假設未釋出的內部表存在。
- `event`、`finite_fault`、`finite_fault_segment`、`station`、`site`、`network`、`motion`、`path`、`time_series_metadata`、`intensity_measure` 與 spectra 均拆表保存。
- 原始 release 內 `motion_id = -999` 的 placeholder rows 已排除；其他欄位中的 `-999` 仍保留，因其通常代表官方缺值/不可用代碼。
- PSA/EAS ordinates 數量很大。為避免產生上億列 long table，頻譜使用 `spectral_axes` 保存座標軸，`response_spectra.psa_json` 與 `effective_amplitude_spectra.eas_json` 保存對應 JSON array。這與報告中 time-series data 以 JSON 保存的做法一致。

## 主要資料表

| Table | 說明 |
|---|---|
| `release_files` | 本次建置使用的 release 檔案、角色、筆數、欄位數、SHA-256 |
| `field_catalog` | Excel documentation 中的欄位名稱、資料型別、描述 |
| `code_definitions` | Housing、COSMOS station type、VS30 code、Z code |
| `citations` | 官方 documentation citations |
| `events`, `event_types` | 地震事件與事件類型 |
| `finite_faults`, `finite_fault_kinematic_parameters`, `finite_fault_segments` | 斷層模型與 segment 資訊；source flatfile 中 16 組 segment 欄位已 unpivot |
| `networks`, `stations`, `sites`, `basin_depth_estimates` | 測站、場址與 basin depth estimates |
| `motions` | ground-motion 主表，連接 event、station、path |
| `paths` | source-to-site path metrics |
| `time_series_metadata` | processing/filter/instrument metadata |
| `intensity_measures` | 各 component 的 PGA、PGV、CAV、IA 與 IA percentile times |
| `spectral_axes` | PSA period 或 EAS frequency 座標軸 |
| `response_spectra` | PSA JSON array，每列一個 `motion_id` + `component` |
| `effective_amplitude_spectra` | EAS JSON array，每列一個 `motion_id` |
| `c1c2_classifications` | North America C1/C2 supplementary classifications |

## 基本使用

```bash
sqlite3 output/sqlite/nga_west3_20250919.sqlite
```

檢查資料量：

```sql
SELECT 'events', count(*) FROM events
UNION ALL SELECT 'motions', count(*) FROM motions
UNION ALL SELECT 'response_spectra', count(*) FROM response_spectra
UNION ALL SELECT 'effective_amplitude_spectra', count(*) FROM effective_amplitude_spectra;
```

查 RotD50 PGA 與常用 metadata：

```sql
SELECT
  m.motion_id,
  e.event_name,
  e.magnitude,
  s.vs30,
  p.rrup,
  im.pga
FROM motions AS m
JOIN events AS e USING (event_id)
JOIN stations AS st USING (station_id)
JOIN sites AS s USING (site_id)
JOIN paths AS p USING (path_id)
JOIN intensity_measures AS im
  ON im.motion_id = m.motion_id AND im.component = 'RotD50'
WHERE e.magnitude >= 6.5
  AND p.rrup <= 20
LIMIT 20;
```

取 RotD50 的 1.0 秒 PSA：

```sql
WITH axis AS (
  SELECT ordinate_index - 1 AS json_index
  FROM spectral_axes
  WHERE spectrum_type = 'PSA'
    AND component = 'RotD50'
    AND axis_value = 1.0
)
SELECT
  rs.motion_id,
  json_extract(rs.psa_json, '$[' || axis.json_index || ']') AS psa_1s
FROM response_spectra AS rs
CROSS JOIN axis
WHERE rs.component = 'RotD50'
LIMIT 20;
```

取 EAS 10 Hz：

```sql
WITH axis AS (
  SELECT ordinate_index - 1 AS json_index
  FROM spectral_axes
  WHERE spectrum_type = 'EAS'
    AND component = 'EAS'
    AND axis_value = 10.0
)
SELECT
  eas.motion_id,
  json_extract(eas.eas_json, '$[' || axis.json_index || ']') AS eas_10hz
FROM effective_amplitude_spectra AS eas
CROSS JOIN axis
LIMIT 20;
```

查欄位說明：

```sql
SELECT field_name, data_type, description
FROM field_catalog
WHERE source_sheet = 'PSA Field Descriptions'
  AND field_name IN ('rrup', 'ravg', 'vs30', 'pga_rotd50');
```

## 重建資料庫

使用 Python 3 environment；需要 `openpyxl`：

```bash
python3 scripts/build_nga_west3_sqlite.py
```

腳本會覆寫：

```text
output/sqlite/nga_west3_20250919.sqlite
```

## 驗證摘要

本次輸出已通過：

```text
PRAGMA integrity_check: ok
events: 7309
stations: 13398
sites: 12702
motions: 175244
intensity_measures: 1051464
response_spectra: 1051464
effective_amplitude_spectra: 175244
spectral_axes: 1055
invalid motion_id=-999 rows: 0
```
