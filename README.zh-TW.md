# NGA-West3 衍生資料產品

[English README](README.md)

本 repository 記錄一套可重現的工作流程，用來從 2025-09-19 公開發布的 NGA-West3 flatfiles 建置衍生資料產品。

## 資料來源

本工作流程使用的 NGA-West3 flatfiles 屬於次世代衰減關係-西部第三版（Next Generation Attenuation-West3，NGA-West3）計畫的一部分。相關資料資源記載於 UCLA GIRS 技術報告第 2025-07 號（Stewart, 2025），並可透過太平洋地震工程研究中心（PEER）的 Ground Motion Database 取得。詳見文末[參考文獻](#參考文獻)。

GitHub repository 會刻意維持精簡，只保存腳本、文件、比較摘要與 release manifests。大型衍生檔案，例如 SQLite 與 RDS 輸出，應透過 Google Drive release folders 發布。

## 文件同步

這份繁體中文 README 與英文 `README.md` 應保持同步。未來若更新任一版本中的設定步驟、檔案路徑、release policy、Shiny app 說明或重建指令，請在同一次變更中同步更新另一個版本。

## Repository 內容

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

## 大型資料政策

下列檔案不納入 Git 追蹤：

- 原始 component flatfiles：`NGA_West3_*_Flatfile_20250919.csv`
- 衍生 SQLite database：`output/sqlite/nga_west3_20250919.sqlite`
- 衍生 RDS files：`output/rds/*.rds`

請將這些檔案發布到版本化的 Google Drive folder，例如：

```text
NGA-West3/releases/2025-09-19/
```

上傳後，若需要穩定的逐檔 reference，可在 release manifest 中填入 `google_drive_file_id` 欄位。

## 建置輸出

SQLite：

```text
output/sqlite/nga_west3_20250919.sqlite
```

使用說明在 `docs/sqlite_usage.md`。

RDS：

```text
output/rds/
```

使用說明在 `docs/rds_usage.md`。

## Shiny App 計劃

Shiny dashboard 的提案計劃記錄於 `docs/shiny_app_development_plan.md`。此計劃使用 SQLite 作為主要查詢後端，並以小型 RDS cache 支援地圖/統計頁面，再針對 R-native 探索流程 lazy-load 大型 RDS files。

## Shiny App

初版 Shiny dashboard 實作位於 `shiny-app/`。

從 Google Drive release 下載 SQLite database 至 `output/sqlite/`：

```bash
python3 scripts/download_nga_west3_release.py
```

請從 repository root 執行：

```r
shiny::runApp("shiny-app")
```

App 預期本地 SQLite 與 RDS 輸出分別位於 `output/sqlite/` 與 `output/rds/`。可選路徑覆寫與 app cache 說明請見 `shiny-app/README.md`。

若也要下載 Analysis page 使用的 optional RDS products 至 `output/rds/`：

```bash
python3 scripts/download_nga_west3_release.py --include-rds
```

## 準備 Google Drive Release

產生 manifests 與被 Git 忽略的本地 staging folder：

```bash
python3 scripts/prepare_google_drive_release.py
```

若要將大型資料檔以 hardlink stage 到單一本地 folder 方便上傳：

```bash
python3 scripts/prepare_google_drive_release.py --stage-data hardlink
```

Staging folder 為：

```text
google_drive_release/2025-09-19/
```

其中 `sqlite/` 與 `rds/` 子資料夾會被 Git 忽略。

## 驗證下載

從 Google Drive 下載檔案後，請驗證 checksums：

```bash
shasum -a 256 -c manifests/nga_west3_20250919_SHA256SUMS.txt
```

請在包含已下載 `sqlite/` 與 `rds/` 資料夾的目錄中執行此指令。

## 重新建置

建置 SQLite：

```bash
python3 scripts/build_nga_west3_sqlite.py
```

建置 RDS：

```bash
Rscript scripts/build_nga_west3_rds.R
```

## 參考文獻

Stewart, J. P. (2025). *Data Resources for NGA-West3 Project*. UCLA GIRS Technical Report No. 2025-07. University of California, Los Angeles. https://www.risksciences.ucla.edu/girs-reports/2025/07

Pacific Earthquake Engineering Research Center (PEER). (n.d.). *Ground Motion Database*. https://gmdatabase.org/
