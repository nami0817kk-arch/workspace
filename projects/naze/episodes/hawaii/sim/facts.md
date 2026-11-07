# ハワイの水はどこから — 数字と出典（2026-11-07 に一次資料で確かめた）

インチ・ガロン・フィートのメートル法への換算は自分の計算。

## 雨
- ワイアレアレ（カウアイ島）年降水量の平年値 393.85 in ≈ 1万mm。マナ（同じ島の西）20.23 in ≈ 514mm。ホノルル空港 16.41 in ≈ 417mm — NWS Honolulu「Rain gage data table, December 2025」https://www.weather.gov/media/hfo/hydrosum/data_tbl_1225.pdf
  - ワイアレアレ ÷ マナ ≈ 19倍（計算）
  - 州の統計書（DLNR 1995）ではワイアレアレの平均 444 in、1982年に 666 in — State of Hawaii Data Book 2020 Table 5.54
- マウナケア山頂付近 204mm（州で最少）、雨は中腹で一番多い。逆転層は約 2,200m — Rainfall Atlas of Hawaiʻi（ハワイ大学、1978–2007）https://rainfall.geography.hawaii.edu/rainfall
- 日本の年平均降水量 約1,700mm — 国土交通省「日本の水資源の現況」
- 東京の年降水量の平年値 1,598.2mm — 気象庁（1991–2020）

## 風
- 貿易風は北東から。夏は 80〜95% の時間、冬は月平均 50〜80%。逆転層はふつう 5,000〜7,000 ft（約1,500〜2,100m）。その上は相対湿度がふつう 40% 未満 — WRCC「Climate of Hawaii」https://wrcc-archive.dri.edu/Climate/narrative_hi.php
- 風が山の斜面で押し上げられ、冷えて雲と雨になる — Rainfall Atlas of Hawaiʻi

## 地下水
- 淡水レンズ: 地下水面が海面より 1 ft 上なら、海面下 40 ft まで真水（海水が真水より約 40分の1 重い）— USGS Fact Sheet FS 126-00「Ground Water in Hawaii」(2000) https://dlnr.hawaii.gov/mk/files/2016/11/B.17w-USGS-Ground-Water-in-Hawaii.pdf
- 地下水はハワイの家庭用水の約 99%。州全体に降る雨は約 210億ガロン/日（≈ 8,000万m³/日）、汲む地下水はその 3% 未満 — 同上
- オアフ島の水道はほぼ 100% が地下水（almost 100 percent）— Honolulu Board of Water Supply https://www.boardofwatersupply.com/water-resources/watershed-partnerships
- オアフ島の 1 日の汲み上げ 約 1.24億〜1.43億ガロン/日（≈ 47万〜54万m³/日、2026年の月平均）— BWS 2026 Groundwater Status Reports
- コオラウ山脈の山頂に降った一滴が地下水になるまで 25 年かかることがある。オアフ島には普通の日で約 20億ガロンの雨、その 3分の1 近くが地下水に — BWS「Hawaiʻi's Water Cycle」

## 川・滝・距離
- ハナレイ川（カウアイ島）平均流量 129百万ガロン/日 ≈ 49万m³/日。ワイメア川 19.7 マイル ≈ 32km — State of Hawaii Data Book 2023 Table 5.15
- 通年流れる川 376 本（州全体の推定）— DLNR 水資源委員会 https://dlnr.hawaii.gov/cwrm/surfacewater/sw-activities/usgs-streamstats/
- アカカの滝 442 ft ≈ 135m — DLNR 州立公園局
- ホノルル〜サンフランシスコ 3,857km — State of Hawaii Data Book 2024 Table 5.01（USGS 1980）

## 自分で測った（sim/fetch.py、Terrain Tiles z10 を 1 度 240 画素）
- ワイアレアレの高さ 約1,555m、マウナケア 約4,152m、マウナロア 約4,133m（格子でならした値。公式はマウナケア 4,207m）
