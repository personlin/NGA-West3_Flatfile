# Official GMDB Events/Stations Difference Summary

## Counts

| Dataset | Official API unique IDs | Local SQLite unique IDs | Common | Official only | Local only |
|---|---:|---:|---:|---:|---:|
| events | 7488 | 7309 | 7287 | 201 | 22 |
| stations | 16259 | 13398 | 13398 | 2861 | 0 |
| motions | 191723 | 175244 | 175191 | 16532 | 53 |

## First 20 Official-Only IDs

- events: [2116, 2117, 2118, 2119, 2120, 2121, 2122, 2123, 2124, 2125, 2126, 2127, 2128, 2129, 2130, 2131, 2132, 2133, 2134, 2135]
- stations: [4326, 4349, 4812, 5568, 5595, 5696, 5913, 6014, 6083, 6096, 6099, 6102, 6104, 6120, 6126, 6128, 6138, 6266, 6267, 6268]
- motions: [22272, 24396, 32741, 34160, 36048, 36133, 36391, 36620, 37028, 37578, 38008, 38169, 38709, 40066, 40067, 40068, 40069, 40070, 40071, 40072]

## First 20 Local-Only IDs

- events: [3608, 3611, 3612, 3613, 3614, 3615, 3616, 3617, 3618, 3622, 3624, 3626, 3627, 3629, 3630, 3634, 3635, 3636, 3637, 3638]
- stations: []
- motions: [144297, 144306, 144312, 144313, 144317, 144318, 144323, 144324, 144332, 144338, 144339, 144341, 144344, 144345, 144377, 144379, 144380, 144381, 144382, 144392]

## Official-Only Events by Country

- United States of America: 135
- Canada: 54
- Mexico: 4
- Cuba: 2
- Greece: 2
- Italy: 2
- India: 1
- Uzbekistan: 1

## Official-Only Events by event_type_id

- 7: 147
- 5: 50
- 1: 3
- 6: 1

## Official-Only Stations by network_id

- 21: 850
- 83: 498
- 36: 205
- 90: 152
- 47: 84
- 10: 82
- 24: 68
- 44: 58
- 111: 47
- 92: 45
- 49: 35
- 68: 35
- 117: 34
- 71: 32
- 58: 30
- 62: 27
- 113: 26
- 85: 26
- 73: 25
- 53: 24
- 72: 24
- 120: 23
- 50: 23
- 87: 23
- 93: 21
- 57: 19
- 60: 19
- 94: 19
- 103: 18
- 46: 17

## Official-Only Motions by Event Status

- event_official_only: 16434
- event_in_local: 98

## Official-Only Motions by Station Status

- station_official_only: 15809
- station_in_local: 723

## Official-Only Motions by Event Type

- Stable Continental: 9063
- Induced: 7369
- Shallow Crustal: 100

## Official-Only Motions by Event Country

- United States of America: 14537
- Canada: 1965
- Mexico: 17
- Cuba: 10
- Italy: 2
- Uzbekistan: 1

## Official-Only Motions by Station Network

- TA / USArray Transportable Array (EarthScope_TA): 6094
- CN / Canadian National Seismograph Network (CNSN): 1399
- US / United States National Seismic Network (USNSN): 1274
- NM / Cooperative New Madrid Seismic Network (): 1231
- GS / US Geological Survey Networks: 1097
- N4 / Central and Eastern US Network: 971
- NX / Nanometrics Research Network: 740
- LD / Lamont-Doherty Cooperative Seismographic Network (LCSN): 590
- 9L / Stanford Geophysics Donor Data Collection: 512
- IU / Global Seismograph Network - IRIS/USGS (GSN): 377
- AG / Arkansas Seismic Network (): 351
- OK / Oklahoma Seismic Network (): 272
- ZL / Northern Embayment Lithospheric Experiment: 237
- NE / New England Seismic Network (NESN): 165
- PE / Pennsylvania State Seismic Network (PASEIS): 100
- ET / CERI Southern Appalachian Seismic Network (): 70
- CO / South Carolina Seismic Network (SCSN): 53
- XB / Sweetwater Array: 51
- O2 / Oklahoma Consolidated Temporary Seismic Networks: 49
- SP / South Carolina Earth Physics Project (SCEPP): 47
- NQ / NetQuakes: 45
- WU / The Southern Ontario Seismic Network (): 44
- XO / Ozark Illinois Indiana Kentucky (OIINK) Flexible Array Experiment (OIINK): 38
- 6E / Wabash Valley Seismic Zone: 35
- XR / Seismicity near the Nemaha fault in northern Oklahoma: 34
- XR / The Florida to Edmonton Broadband Experiment (FLED): 34
- XF / Laramie Telemetered Broad-band Array (Laramie): 30
- YB / Deep Fault Structure Beneath the Mojave from a High Density, Passive Seismic Profile (Mojave Experiment): 30
- ZW / North Texas Earthquake Study: Azle and Irving/Dallas: 29
- OH / Ohio Seismic Network: 28

## Output Files

- `official_events.csv`
- `official_stations.csv`
- `official_motions.csv`
- `events_only_official.csv`
- `events_only_local.csv`
- `stations_only_official.csv`
- `stations_only_local.csv`
- `motions_only_official.csv`
- `motions_only_local.csv`
- `comparison_summary.json`
