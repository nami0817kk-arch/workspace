# 電子レンジはなぜ温まるのか — 出典の控え（2026-10-28）

| 台本の数字・説明 | 出典 | 確かさ |
|---|---|---|
| 電子レンジの周波数は 2,450MHz ±50MHz（電波法施行規則 第46条の7、型式確認） | e-Gov https://laws.e-gov.go.jp/law/325M50080000014 | A |
| 2.4〜2.5GHz は世界共通の ISM 帯（産業・科学・医療用）。ITU 無線通信規則 5.150 | ITU-R SM.2180 https://itu.int/dms_pub/itu-r/opb/rep/R-REP-SM.2180-2010-PDF-E.pdf | B |
| 熱は食品の中で生まれるが「中から外へ」ではない。外側の層がマイクロ波で温まり、内側は外から伝わる熱で温まる | FDA https://www.fda.gov/radiation-emitting-products/resources-you-radiation-emitting-products/microwave-ovens | A |
| マイクロ波が入るのは1〜1.5インチ（約2.5〜3.8cm） | USDA（保存版）／ネブラスカ大学 https://food.unl.edu/article/microwave-safety/ | A/B |
| 「内側から加熱」は厳密には正しくない（東芝の担当者） | 家電Watch 2025-07-30 https://kaden.watch.impress.co.jp/docs/topic/topic/2033561.html | B |
| 国民生活センター：「表面から温めるのではなく…食品全体を加熱」 | https://www.kokusen.go.jp/news/data/n-20260325_1.html | A。台本は「オーブンのように表面だけを熱するのではない」も言ってぶつからないようにする |
| 2.45GHz は水の共鳴ではない。割り当てで決まった | West Texas A&M 大 Baird https://wtamu.edu/~cbaird/sq/mobile/2014/10/15/why-are-the-microwaves-in-a-microwave-oven-tuned-to-water/ | A |
| 水がいちばん吸うのは約20GHz（25℃）。2.45GHz はそれより低いので中まで入る | キール大学 https://www.tf.uni-kiel.de/matwis/amat/elmat_en/kap_3/advanced/t3_4_1.html ／ロンドン・サウスバンク大 | A/B |
| 水 25℃・2.45GHz：ε'≈77、ε''≈9.4 | ノッティンガム大学のデータ（抜粋）、デバイの式で自分でも確認（77.2、9.2） | B |
| 氷：ε''≈0.001〜0.003 | Koh 1997 Cold Regions Sci. Tech. 25(2) | B |
| 解凍で融けた所にマイクロ波が集まり、一部が煮える | 家電Watch（東芝）／米国特許 4,520,250 | B/A |
| 特許 US2,495,429、発明者パーシー・スペンサー、レイセオン社、出願 1945-10-08 | https://patents.google.com/patent/US2495429A/en | A |
| チョコバーが溶けた話は「伝えられている」（菓子の種類は資料で違う） | 全米発明家殿堂 https://www.invent.org/blog/inventors/microwave ／米議会図書館 https://blogs.loc.gov/inside_adams/2021/01/microwaves/ | 逸話として言う |
| 初代 Radarange は1947年、重さ約340kg・高さ約1.8m | 全米発明家殿堂 | B |
| シャープが1961年に日本初の電子レンジを開発、1962年量産。1966年 R-600 が日本初のターンテーブル式 | シャープ https://global.sharp/corporate/info/his/only_one/el/range.html | A |
| フラット庫内は床下のアンテナが回って電波の向きを変える | 家電Watch／国民生活センター | A/B |
| 普及率 1970年 2.1% → 2004年 96.5%（内閣府 消費動向調査、2004年で調査終了） | https://www.esri.cao.go.jp/jp/stat/shouhi/shouhi.html | A |

| 半分に切ったブドウの火花は、粒の中に電波が集まるため | Khattak, Bianucci, Slepkov 2019, PNAS 116(10):4000-4005（カナダ・トレント大学） | 高 |

## 自分で計算した数字
- 1秒に 2.45×10⁹ 回 → 24億5千万回、電場の向きは1秒に49億回入れ替わる（1周期に2回）。台本は「1秒に24億5千万回」
- 波長 λ0 = 299,792,458 ÷ 2.45×10⁹ = **12.2cm**。定在波の熱い所の間隔は半波長 **約6cm**（理想の場合）
- 水の電力の浸透深さ Dp ≈ λ0·√ε' / (2π·ε'') = 12.24 × 8.8 ÷ (6.28 × 9.4) ≈ **1.8cm**（電力が37%になる深さ）。2cm の水を通ると約3分の1、4cm で約10分の1、6cm で約30分の1
- 氷の Dp ≈ 12.24 × √3.17 ÷ (6.28 × 0.003) ≈ **約12m**（ほぼ素通り）
- 吸収の比 9.4 ÷ 0.003 ≈ 3,000倍 → 「数千分の1」と言う

- 周波数ごとの深さ（デバイの式、25℃の水）: 0.915GHz 13.3cm／2.45GHz 1.87cm／5.8GHz 0.35cm／20GHz 0.04cm。水の中の波長は 2.45GHz で 1.39cm
- 実験2（scratchpad の mw3.py）: 10cm四方・5℃・500W・上下から・厚さ方向の熱伝導だけ。最高点が100℃のとき中心は 2cm 96℃／4cm 78℃／6cm 54℃／10cm 23℃。
  6cm を 10秒入れて20秒休むと中心 70℃。湯気で逃げる熱と横からの熱は数えない仮の計算

## 言い切らないこと
- 「中から温まるは嘘」とだけ言わない。「熱は食品の中で生まれる。ただし生まれるのは表面から数cm。中心は外から伝わる熱」
- 浸透を1つの数字で言わない。水の計算は約2cm、食品の目安は2.5〜4cm と添える
- 「水の共鳴は22GHz」は言わない（水蒸気の吸収線）
- 2.45GHz が選ばれた理由は「世界共通の割り当て」と「中まで入る」まで
- 熱い所の間隔は「およそ6cm」
- チョコの話は「〜と伝えられています」
- 普及率は「2004年に96.5%」
- 肉の数値は使わない
