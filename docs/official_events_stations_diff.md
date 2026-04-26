# 官方 GMDB events/stations/motions 與本地 release 差異來源初步分析

資料下載時間：2026-04-25  
官方 API：<https://gmdatabase.org/pages/api_documentation>  
輸出資料夾：`output/official_api_compare/`

## 下載檔案

| File | 說明 |
|---|---|
| `official_events.csv` | 官方 `/events` API 下載結果 |
| `official_stations.csv` | 官方 `/stations` API 下載結果 |
| `official_motions.csv` | 官方 `/motions` API 下載結果 |
| `official_event_types.csv` | 官方 `/eventTypes` API 下載結果 |
| `official_networks.csv` | 官方 `/networks` API 下載結果 |
| `events_only_official.csv` | 官方有、本地 SQLite 沒有的 event rows |
| `events_only_local.csv` | 本地 SQLite 有、官方 API 沒有的 event rows |
| `stations_only_official.csv` | 官方有、本地 SQLite 沒有的 station rows |
| `stations_only_local.csv` | 本地 SQLite 有、官方 API 沒有的 station rows |
| `motions_only_official.csv` | 官方有、本地 SQLite 沒有的 motion rows |
| `motions_only_local.csv` | 本地 SQLite 有、官方 API 沒有的 motion rows |
| `comparison_summary.json` | 機器可讀摘要 |

## 總量差異

| Dataset | 官方 API unique IDs | 本地 SQLite unique IDs | 共同 | 官方-only | 本地-only |
|---|---:|---:|---:|---:|---:|
| events | 7,488 | 7,309 | 7,287 | 201 | 22 |
| stations | 16,259 | 13,398 | 13,398 | 2,861 | 0 |
| motions | 191,723 | 175,244 | 175,191 | 16,532 | 53 |

重點：

- `stations`：本地 stations 完全是官方 stations 的 subset。官方多 2,861 個 station。
- `events`：兩邊不是單純 subset。官方多 201 個 event，但本地也有 22 個 official API 沒回傳的 event。
- `motions`：官方多 16,532 筆，本地多 53 筆。官方多出的 motions 幾乎都可由 stable continental / induced event 與 station catalog 差異解釋。

## Events 差異來源

官方-only events 主要來自非 NGA-West3 shallow-crustal release 的 event types：

| event_type_id | event_type | 官方-only count |
|---:|---|---:|
| 7 | Stable Continental | 147 |
| 5 | Induced | 50 |
| 1 | Shallow Crustal | 3 |
| 6 | Undetermined | 1 |

官方-only events 依國家：

| Country | Count |
|---|---:|
| United States of America | 135 |
| Canada | 54 |
| Mexico | 4 |
| Cuba | 2 |
| Greece | 2 |
| Italy | 2 |
| India | 1 |
| Uzbekistan | 1 |

官方-only event ID 分布呈現幾個連續區段：

| ID range | Count | 初步判讀 |
|---|---:|---|
| 2116-2210 | 95 | 多為 stable continental events，例如 Canada / Eastern North America |
| 2250-2350 | 101 | stable continental 與 induced events，含 Oklahoma/Texas 等 |
| 2486 | 1 | Italy aftershock |
| 2530 | 1 | Italy aftershock |
| 2722 | 1 | Greece event |
| 3007 | 1 | Greece undetermined |
| 3580 | 1 | 2024 New Jersey earthquake |

本地-only events 共 22 筆，全部是 Italy shallow-crustal release records，event_id 為：

```text
3608, 3611, 3612, 3613, 3614, 3615, 3616, 3617, 3618, 3622, 3624,
3626, 3627, 3629, 3630, 3634, 3635, 3636, 3637, 3638, 3639, 3640
```

這 22 筆在本地都連到 motions，共 203 筆 motions。官方 `/events` API 以目前帳號權限下載時沒有回傳這些 event_id，也沒有同名 `event_name`。初步判讀有兩種可能：

1. 官方線上 operational database 與 2025-09-19 flatfile release 的版本不同，義大利資料有後續刪除、重編號或未公開狀態差異。
2. 官方 API 依權限或 public flag 過濾，使部分 release 中的 Italy events 不出現在目前 `/events` 回傳集合。

## Stations 差異來源

官方多出的 2,861 個 station 全部都有 `site_id`。其中：

| 類型 | Count |
|---|---:|
| network_id 也存在於本地 `networks` | 1,988 |
| network_id 不存在於本地 `networks` | 873 |

官方-only stations 前幾大 network：

| network_id | code | network_name | official-only stations |
|---:|---|---|---:|
| 21 | TA | USArray Transportable Array | 850 |
| 83 | CJ | Community Seismic Network | 498 |
| 36 | CN | Canadian National Seismograph Network | 205 |
| 90 | N4 | Central and Eastern US Network | 152 |
| 47 | NM | Cooperative New Madrid Seismic Network | 84 |
| 10 | GS | US Geological Survey Networks | 82 |
| 24 | US | United States National Seismic Network | 68 |
| 44 | LD | Lamont-Doherty Cooperative Seismographic Network | 58 |
| 111 | ZL | Northern Embayment Lithospheric Experiment | 47 |
| 92 | O2 | Oklahoma Consolidated Temporary Seismic Networks | 45 |

初步判讀：

- Stations 差異主要不是 ID mismatch，而是官方 station catalog 比 2025-09-19 flatfile release 更廣。
- 多出 stations 大量屬於 Central/Eastern North America、stable continental、induced seismicity、USArray/Canadian/Oklahoma/Texas/New Madrid 等網路。
- 這與 events 官方-only 的 stable continental / induced event types 相互吻合。
- 另外官方也多出不少 `CJ` Community Seismic Network station，表示官方線上 catalog 可能保留比 flatfile release 更完整的 station inventory；flatfile 只保留有進入該 release ground-motion records 的 station subset。

## Motions 差異來源

官方 `/motions` API 下載到 191,723 筆；本地 release SQLite 有 175,244 筆。兩者共同 `motion_id` 為 175,191 筆。

| 類型 | Count |
|---|---:|
| 官方-only motions | 16,532 |
| 本地-only motions | 53 |

官方-only motions 依其 event 是否存在於本地：

| Event status | Count |
|---|---:|
| event 不在本地 `events` | 16,434 |
| event 在本地 `events` | 98 |

官方-only motions 依其 station 是否存在於本地：

| Station status | Count |
|---|---:|
| station 不在本地 `stations` | 15,809 |
| station 在本地 `stations` | 723 |

官方-only motions 依 event type：

| Event type | Count |
|---|---:|
| Stable Continental | 9,063 |
| Induced | 7,369 |
| Shallow Crustal | 100 |

官方-only motions 依 event country：

| Country | Count |
|---|---:|
| United States of America | 14,537 |
| Canada | 1,965 |
| Mexico | 17 |
| Cuba | 10 |
| Italy | 2 |
| Uzbekistan | 1 |

官方-only motions 前幾大 station network：

| Network | Count |
|---|---:|
| TA / USArray Transportable Array | 6,094 |
| CN / Canadian National Seismograph Network | 1,399 |
| US / United States National Seismic Network | 1,274 |
| NM / Cooperative New Madrid Seismic Network | 1,231 |
| GS / US Geological Survey Networks | 1,097 |
| N4 / Central and Eastern US Network | 971 |
| NX / Nanometrics Research Network | 740 |
| LD / Lamont-Doherty Cooperative Seismographic Network | 590 |
| 9L / Stanford Geophysics Donor Data Collection | 512 |
| IU / Global Seismograph Network - IRIS/USGS | 377 |

官方-only motions 前幾大 event：

| event_id / event_name | official-only motions |
|---|---:|
| 2202 / Mineral_2011-08-23 | 555 |
| 2174 / ValDesBois_2010-06-23 | 535 |
| 2204 / Sparks_2011-11-05 | 530 |
| 2194 / Greenbrier_2011-02-28 | 528 |
| 2205 / Sparks_2011-11-06 | 510 |
| 2195 / Sullivan_2011-06-07 | 472 |
| 2203 / Mineral_2011-08-25 | 443 |
| 2181 / Guy_2010-10-15 | 442 |
| 2180 / Slaughterville_2010-10-13 | 440 |
| 2190 / Guy_2010-11-20 | 422 |

本地-only motions 共 53 筆，全部 `public_motion = 0`，且全部屬於本地-only Italy events 的子集。這 22 個本地-only Italy events 在本地共有 203 筆 motions，其中 150 個 `motion_id` 仍存在於官方 `/motions` API，但官方 `/events` API 沒有回傳相對應的 event rows；另外 53 個 motion 則完全不在官方 `/motions` 回傳集合。

這代表 Italy 差異不是單純「整個 event 被排除」；更像是官方 API 對 event 表、motion 表、public flag 或 release/version 的同步狀態不同。

## 目前可以確定的差異來源

1. **官方 API 不只是 NGA-West3 2025-09-19 shallow-crustal flatfile release。**  
   官方 events/motions 多出大量 Stable Continental 與 Induced records，這些並非本地 NGA-West3 release 的主要目標資料。

2. **本地 stations 是官方 station catalog 的 subset。**  
   本地 13,398 個 station 全部存在於官方 API；官方多 2,861 個 station。

3. **本地 events 與官方 events 有少量 release/API 不一致。**  
   官方多 201 筆；本地多 22 筆 Italy events。這 22 筆在本地共有 203 筆 motions，其中 53 筆 motion 也不在官方 `/motions`，且皆為 `public_motion = 0`。

4. **motion 差異主要由官方多出的 stable continental / induced records 帶動。**  
   官方-only motions 有 16,532 筆，其中 16,434 筆的 event 不在本地 `events`，15,809 筆的 station 不在本地 `stations`。

5. **官方 schema 頁顯示的數字與 API 實際下載數字不完全一致。**  
   這次用 API 下載到 events 7,488、stations 16,259、motions 191,723。後續若要完全釐清，應以 API 實際回傳與使用者權限為準。

## 建議下一步

要進一步定位 release/API 差異，建議：

- 下載官方 `/intensityMeasures` 或 `/flatfile`，確認 16,532 個 official-only motions 是否都有 IM/spectra。
- 對 53 個 local-only motions 查官方是否能用 admin/modeler role 或 public flag 條件取得。
- 對本地-only Italy events 追查官方是否有同一 comcat/time/magnitude 但不同 `event_id` 的記錄。
- 若目標是使本地 SQLite 完全對齊官方 API，需決定是否納入 Stable Continental / Induced records；若目標是 NGA-West3 2025-09-19 flatfile release，則目前本地資料庫與 release 概念一致。
