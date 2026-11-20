# 下調べ: 宇宙はマイナス270℃なのに、宇宙ステーションは熱がこもって困っている。なぜ冷えないのか

調べた日: 2026-11-06。各項目は「数字・単位／出どころ（名前・URL）／原文の該当句／一次か二次か」。
「原文」は資料の英語をそのまま短く。PDF は取り出した文字で確かめた（取り出しで字が崩れた所は注記）。

---

## 1. 宇宙の背景の温度と「熱を奪う物が無い」

- **2.725 ± 0.002 K（約 −270.4℃）**
  - NASA LAMBDA「The COBE Far Infrared Absolute Spectrophotometer (FIRAS)」 https://lambda.gsfc.nasa.gov/product/cobe/about_firas.html
  - 原文: "Mather et al. ... give the definitive CMB temperature: 2.725±0.002 K."
  - 論文: Mather et al. 1999, ApJ 512, 511（arXiv: https://arxiv.org/abs/astro-ph/9810373）
  - 一次
- **（参考）2.7260 ± 0.0013 K** — Fixsen 2009, ApJ 707, 916（WMAP で FIRAS を校正し直した値） https://arxiv.org/abs/0911.1955
  - 原文: "to obtain a CMB temperature of 2.7260±0.0013"
  - 一次。2.725 と 2.726 のどちらでも「約 2.7K」で言えば食い違わない
- **ISS の高さ（約400km）の空気の密度: 約 10⁻¹³〜10⁻¹¹ kg/m³（太陽の活動で100倍ほど上下）**
  - NASA CR-205357「Neutral Orbital Altitude Density Effects on the International Space Station」(Smith ほか, 1997) Table A
    https://ntrs.nasa.gov/api/citations/19970028145/downloads/19970028145.pdf
  - 原文: 400 km の行 "0.28069E-12 ... 0.14324E-10"（外気圏温度 600K〜1600K の列）。最も濃かった 1957-09-23 の例で "at 450 km, 400 km and 300 km, the density values are: 0.15699 x 10^-10, 0.26025 x 10^-10 ..."
  - 一次（表は文字の取り出しで列が崩れている。桁は合っているが、細かい値は PDF の表で見直すこと）
- **地上の空気の密度: 1.225 kg/m³**（U.S. Standard Atmosphere 1976 の海面値。教科書級の定数）
  - 一次（表の本体 NTRS 19770009539 は 10MB 超で今回開けず。値そのものは定番）
  - → 400km の空気は地上の **約1兆分の1（10⁻¹²）**。「温度」はあっても、ぶつかって熱を持ち去る分子がほぼ無い、という説明の数字はこれ
- **「空気が無いので日なたはすぐ熱く、日陰はすぐ冷える」の言い方**
  - JAXA「Thermal Vacuum Test of the Inter-orbit Communication System - Exposed Facility Subsystem」 https://iss.jaxa.jp/iss/kibo/develop_status_42_e.html
  - 原文: "Without air convection to transfer heat, surface areas exposed to the sunlight quickly heat and shaded surfaces get cold."
  - 一次

## 2. ISS の熱の出し方（能動熱制御システム ATCS）

出どころは全部、NASA/Boeing「Active Thermal Control System (ATCS) Overview」
https://www.nasa.gov/wp-content/uploads/2021/02/473486main_iss_atcs_overview.pdf （一次。2006年ごろの資料、"At assembly complete" の書き方が残る）

- **仕組み: 中は水、外はアンモニアの2段**
  - 原文: "The IATCS consists of loops that circulate water through the interior" / "The heated ammonia circulates through large radiators ... releasing the heat by radiation to space"
  - アンモニアを外だけにする理由: "All EATCS components are located outside the pressurized volumes to prevent crew contact with ammonia."（毒なので）
- **捨てられる熱: 70 kW（1ループ 35 kW × 2）**
  - 原文: "designed to provide 35 kW of heat rejection per loop for a total capability of 70 kW"
  - 前の仮の仕組み（EEATCS）は 14 kW: "a substantial upgrade in heat rejection capacity from the 14kW capability"
- **主放熱板: 翼2枚 × 放熱板3基 = 6基。1基は8枚のパネル → 計48枚**
  - 原文: "two sets of rotating radiator wings--each composed of three separate radiator ORUs. Each radiator ORU is composed of eight panels"
- **1基の大きさ: 23.3 m × 3.4 m、重さ 1,123 kg**
  - 原文: "Each Radiator ORU measures 76.4 feet (23.3 meters) by 11.2 feet (3.4 meters) and weighs 2,475 pounds (1,122.64 kilograms)"
  - 自分で掛けると 1基 約79 m²、6基で 約475 m²（片面。両面から出すかは資料に書いていない）
- **回して向きを変える**: 回転継手（TRRJ）で ±115°、毎分0〜45°
  - 原文: "radiators that constantly rotate to optimize cooling for the station" / "rotating 230 degrees, at ±115 degrees from its neutral position"
- **白い塗料（Z-93）**: 原文 "Each panel has a white (Z-93) coating which provides optimum thermo-optical properties to maximize heat rejection."
- **アンモニアの温度・凍る温度**
  - 送り出し 2.8℃: "Ammonia supply temperature is currently set at 37 °F (2.8 °C)"
  - 凍るのは −77℃: "Ammonia has an extremely low freezing point of -107 degrees F (-77 °C)"
  - 管は凍っても壊れにくい作り: "flow tubes are freeze tolerant"
  - 放熱板そのものの表面温度は、この資料には無い（未確認）
- **太陽電池の側にも別の放熱板（PVR）が4基。1基 14 kW、3.12 m × 13.6 m、7枚のパネル**
  - 原文: "the PVR can reject up to 14 kW of heat into deep space. The PVR weighs 1,633 pounds (740.7 kilograms) and when deployed measures 10.24 feet (3.12 meters) by 44.62 feet (13.6 meters)" / "a total of four PVRs"
  - 平均では 6 kW: "The PVTCS can dissipate 6,000 Watts of heat per orbit on average"
- **太陽電池パネルとの比べ**
  - 翼の端から端 109 m（NASA「Space Station Facts and Figures」 https://www.nasa.gov/international-space-station/space-station-facts-and-figures/ 、原文 "The solar array wingspan (356 feet, 109 meters)"、一次）
  - 太陽電池の面積: 8翼で 約2,500 m²（27,000 ft²）とする記事あり（Gizmodo、**二次**）。Lockheed Martin の発表（2006）は 8翼 "107 by 38-feet, will encompass an area of 32,528-sq. ft." （約3,000 m²、メーカーの発表なので一次寄り） https://news.lockheedmartin.com/2006-09-14-Massive-Lockheed-Martin-Solar-Arrays-Begin-Providing-Power-to-International-Space-Station
  - → 主放熱板（約475 m²）は太陽電池の **5〜6分の1** ほど。比べに使うなら面積の数え方の違いに注意（下の「危ない点」）

## 3. 日なたと日陰の表面温度・1日の日の出

- **+121℃／−157℃（250°F／−250°F）**
  - よく出る文「熱の仕組みが無ければ日なた側は 250°F、日陰側は −250°F」は NASA の資料の引用として出回っているが、**NASA の原典ページは見つけられなかった**（掲示板・まとめ記事経由＝二次）
  - NASA が書いている方: NASA Spinoff 2011「Thermal Components Boost Performance of HVAC Systems」 https://ntrs.nasa.gov/citations/20120001907 、原文 "with temperatures reaching 250 F when facing the Sun"（日なた側のみ。一次）
- **+120℃／−150℃**（こちらは一次で使える）
  - JAXA（上と同じページ） 原文: "Temperatures in space range from 120°C in the sunlight to -150°C in the shade."
- **ジェイムズ・ウェッブの例ではさらに +85℃〜−233℃**（7. を参照）
- **1周 約90分、1日16周、日の出・日の入り各16回**
  - NASA Facts and Figures 原文: "makes 16 orbits of Earth, traveling through 16 sunrises and sunsets" / "every 90 minutes"
  - 1周のうち日なた約60分・日陰約30分: JAXA 原文 "circles the Earth in 90 minutes, during which time it is cold for 30 minutes, and hot for 60 minutes."（季節・軌道で変わる。ほぼずっと日なたの時期もある＝下の危ない点）
  - 一次

## 4. 人の体の熱と宇宙服の冷やし方

- **人の出す熱: 寝ているとき 88 W、1日の平均 131 W、起きて動くと最大 191 W**
  - NASA JSC「Developing a Daily Metabolic Rate Profile for Human Exploration Missions」ICES-2021-365 https://ntrs.nasa.gov/api/citations/20205010692/downloads/ICES-2021_Metabolic_Paper-Final.pdf
  - 原文: "Maximum (awake) was 686 kJ/hr (191 W, 650 BTU/hr), nominal 24-hour average was 472 kJ/hr (131 W, 447 BTU/hr) and minimum was 317 kJ/hr (88 W, 300 BTU/hr) during sleep."
  - 一次。「安静で約100W」は 88〜131W の間なので言ってよい（"100W" と書いた NASA の一次は見つけていない）
- **宇宙服（EMU）は「水を凍らせて、その氷が真空へ蒸発（昇華）する」ことで冷える**
  - Hill & Taylor（NASA JSC）「Use of Aquaporins to Achieve Needed Water Purity on the ISS for the EMU」 https://ntrs.nasa.gov/api/citations/20120012939/downloads/20120012939.pdf
  - 原文: "forms a layer of ice on the surface of the sublimator that is exposed to vacuum" / "The heat removed ... is dissipated into space via the sublimation of the sublimator ice layer."
  - 穴の大きさ 8〜10 µm: "Due to the very small diameter of the holes in the porous plate (8-10 µm diameter)"
  - 水の三重点で動く: "The sublimator operates at the triple point of water"
  - 一次
- **水の量: 約10ポンド（約4.5 kg）を積んで8時間の船外活動ぶん。予備で+30分**
  - 同上 原文: "approximately 10 pounds (aprox. 4.8 quarts) of ultrapure water" / "enough water to support cooling for an 8-hour extravehicular activity (EVA)" / "an additional 30 minutes of cooling capability"
- **1回の船外活動で宇宙へ捨てる水: 約3.6 kg（8ポンド）／1人**
  - Hodgson ほか「Spacesuit Evaporator-Absorber-Radiator (SEAR)」 https://ntrs.nasa.gov/api/citations/20120004284/downloads/20120004284.pdf
  - 原文: "approximately 3.6 Kg (8 lbm) of water is lost to space for each EVA astronaut"
  - 一次
- **冷却下着（LCVG）: 細い管が 約250フィート（約76 m）、体の約1.8 m² を覆う**
  - Conger ほか「High Performance Torso Cooling Garment」ICES-2016-412 https://ntrs.nasa.gov/api/citations/20160005252/downloads/20160005252.pdf
  - 原文: "the total length of tubing in an average sized EMU LCVG is 250 feet" / "The body area covered by the LCVG is estimated to be 1.776 square meters"
  - 一次（「300フィート」「91 m」とする記事もあるが一次では見つからず）

## 5. 放射で冷える式の定数と、白い塗料の値

- **シュテファン＝ボルツマン定数 σ = 5.670374419 × 10⁻⁸ W m⁻² K⁻⁴（定義値から決まる正確な値）**
  - NIST CODATA https://physics.nist.gov/cgi-bin/cuu/Value?sigma
  - 一次（教科書級の物理定数）
- **Z-93 系の白い塗料の太陽光の吸収率 α ≈ 0.14〜0.15（宇宙に置いても変わりにくい）**
  - Finckenor（NASA MSFC）「MISSE Thermal Control Materials with Comparison to Previous Flight Experiments」 https://ntrs.nasa.gov/api/citations/20080031037/downloads/20080031037.pdf
  - 原文（表1）: "Z-93 MISSE-2 ... 0.14 0.14"（打ち上げ前・回収後とも 0.14）、"AZ93 ... 0.15 0.15"
  - 一次（ISS の外で実際にさらした実験）
  - ほかに 未使用の Z-93-P が 0.117〜0.133（NASA TM 2005「Evaluation of LEO Environmental Effects on ISS Thermal Control Materials」 https://ntrs.nasa.gov/api/citations/20050180645/downloads/20050180645.pdf 、原文 "Pristine Z-93-P 2200 0.133 ..."）
  - AZ-93 は約15%: NASA KSC の報告 https://ntrs.nasa.gov/api/citations/20205006191/downloads/CTCC%20Coating%20Study%20Report.pdf 原文 "AZ-93 reflective paint alone has a solar absorptance of about 15%"
- **放射率 ε ≈ 0.91（Z-93P）**
  - NASA TM-1998-208500「Evaluation of Low Earth Orbit Environmental Effects on ISS Thermal Control Materials」 Table 11 https://ntrs.nasa.gov/api/citations/19980234623/downloads/19980234623.pdf
  - 原文: Z-93P（ZPLM）の行に "0.911 / 0.909" 前後
  - 一次。ただし表は文字の取り出しで列が崩れており、どの数字がどの試料かは PDF の表で目で確かめること。「放射率 約0.9」と丸めて言うのが安全
  - 宇宙ステーション計画での目標値（参考）: 放射率 0.9、吸収率は使い始め 0.2・寿命の終わり 0.3（Space Station Freedom 向けの塗料の要求、NTRS の報告の Table I。検索の抜粋で見ただけ＝要確認）
- → 「白い塗料は太陽の光を 85% はね返しながら、熱（赤外線）は 9割の力で出せる」が言える。吸収率／放射率 ≈ 0.15/0.9

## 6. 真空で水と体はどうなるか

- **1966年12月14日、NASA 有人宇宙船センター（ヒューストン）の真空室で宇宙服の事故。12〜15秒で倒れた**
  - Roth（Lovelace 財団）「Rapid (explosive) decompression emergencies in pressure-suited subjects」NASA CR-1223, 1968 https://ntrs.nasa.gov/citations/19690004637 （PDF: https://ntrs.nasa.gov/api/citations/19690004637/downloads/19690004637.pdf ）
  - 原文: "One connector assembly has already failed at the suit fixture leading to loss of consciousness and hypoxia, but no symptoms or signs of lung damage were noted after the pressure drop from 3.7 psia to minimum reading of 0.1 psia in about 0.5 sec (PLSS 005 Test #3, 14 Dec. 1966)"
  - 原文: "The time to collapse of subject (12-15 sec)"
  - 一次。服の中の気圧が 0.5秒で 3.7 psi → 0.1 psi（地上の約150分の1）に落ちた。肺の傷は無かった
  - 本人の名（Jim LeBlanc）・「舌の上のつばが泡立った」・「14秒」は、後の取材やまとめ記事の話（**二次**）。この報告書には名前もつばの話も無い
- **体の温度（37℃）での水の蒸気圧 47 mmHg（約6.3 kPa）** — 気圧がこれより下がると体の水分が泡になる（エブリズム）
  - Roth 同上 原文: "water vapor pressure at 47 mm Hg" / "Almost immediately after decompression to an ambient atmospheric pressure at which ebullism can occur, vapor bubbles form at the entrance of the great veins"
  - 一次（47 mmHg は教科書級の値）
- **真空で水は「先に沸いて、そのあと凍る」**: 宇宙服の昇華器がまさにそれ（4. の "forms a layer of ice ... exposed to vacuum"）。蒸発で熱を奪われて氷になる、の一次の根拠として使える
- **チンパンジーを真空近くに急に下げても生き延びた（米空軍、1967）** — Koestler 編 ARL-TR-67-2 https://apps.dtic.mil/sti/pdfs/AD0647034.pdf （検索の抜粋 "chimpanzees can survive sudden exposure to a near vacuum" で見ただけ。本文は未確認）

## 7. ほかの例

- **アポロの「バーベキュー・ロール」（正式名 Passive Thermal Control）: 毎秒0.3°＝1時間に3回転**
  - NASA Apollo 11 Flight Journal（Day 2） https://apollojournals.org/afj/ap11fj/06day2-tv.html （nasa.gov/history/afj/ の同名ページは今回は目次に飛ばされた）
  - 原文: "The Apollo 11 stack is currently in its barbecue roll mode, more formally known as Passive Thermal Control." / "in order to distribute the heating effect of the Sun and the cooling effect of space" / "The rate of rotation is 0.3° per second"
  - 一次（NASA の注釈つき記録）。0.3°/秒 × 3600秒 ÷ 360° = 3回転/時（自分で計算）
  - 「1時間に1〜3回転」（Universe Today、二次）、「1時間に1回」（ネットの記事、二次）と書く所もある
- **ジェイムズ・ウェッブの日よけ: 5層、テニスコートほど（21.197 m × 14.162 m）**
  - NASA「Webb's Sunshield」 https://science.nasa.gov/mission/webb/webbs-sunshield
  - 原文: "The sunshield consists of five layers" / "21.197 m x 14.162 m (69.5 ft x 46.5 ft)"
  - 太陽側 +85℃・宇宙側 −233℃: "Hot side of the sunshield (185°F / 85°C) ... cold side (-388°F / -233°C)"
  - 差 約299℃: "approximately 570°F (299°C) across its 5 layers"
  - 計算上の最高・最低: "383K or approximately 230 degrees F" / "36K or around -394 degrees F"（+110℃／−237℃。図の +85／−233 と食い違う＝下の危ない点）
  - 膜の厚さ: 1層目 0.05 mm、ほか4層 0.025 mm
  - 一次
- **魔法瓶と同じ理屈（層と層のあいだの真空が断熱）**
  - NASA「How Does Webb Stay Cold?」 https://science.nasa.gov/mission/webb/science-overview/science-explainers/how-does-webb-stay-cold
  - 原文（検索の抜粋）: "the vacuum gap insulates well. One big thick sunshield would conduct the heat from the bottom to the top more than five layers separated by vacuum." / 層は触れ合わない "that would allow the transfer of heat from one layer to the next"
  - 一次（ページ本体の文言は検索の抜粋で見た。台本に使う前に一度ページで確かめる）
  - 魔法瓶の発明（デュワー、1890年代）の一次は今回は調べていない

## 8. 「えっ」と思う事実（あと5つ）

1. **宇宙服は「氷」で冷やしている** — 真空にさらした板の上で水が凍り、その氷が蒸発して熱を捨てる（4. Hill & Taylor、一次）。宇宙が寒いから冷えるのではなく、自分の水を捨てて冷えている。1回の船外活動で 約3.6 kg の水が宇宙へ消える（Hodgson、一次）
2. **ISS の冷却液は「凍らないように」アンモニア** — 水は0℃で凍るが、アンモニアは −77℃まで凍らない（ATCS Overview、一次）。「冷えすぎて凍る」心配もしている。熱交換器には冷たいアンモニアの塊が来たら水側を守る仕掛けまである: "in the event a cold slug is detected at the pump outlet to prevent ITCS coolant from freezing"（一次）
3. **放熱板は日陰を探して首を振る** — 回転継手で ±115°動かして、向きを変え続ける（ATCS Overview、一次。「日陰を探す」の言い方は NTRS の別の報告の要約で見ただけ＝要確認）
4. **ISS では1日に16回、日の出と日の入りがある** — 45分ごとに昼と夜が入れ替わる（NASA Facts and Figures、一次）。そのたびに外は100℃以上の温度差
5. **真空にさらされた人は、爆発も凍りもしなかった** — 1966年のヒューストンの事故では 12〜15秒で倒れ、肺の傷は無かった（Roth NASA CR-1223、一次）。映画のように「一瞬で凍る」「破裂する」は俗説
- 予備: ウェッブの日よけの膜は 0.025 mm（髪の毛より薄い。髪の太さの数字は未調査）で 300℃の差を作る（NASA、一次）

---

## 危ない点（食い違い・俗説）

- **「宇宙は寒い」**: 半分だけ正しい。背景の光の温度は 2.7K だが、ISS の高さには熱を運ぶ空気がほぼ無い（地上の約1兆分の1）ので、物は「冷たい物に触れて冷える」ことができない。冷える道は放射（赤外線を出す）だけ。日なたでは太陽の光で +120℃にもなる（JAXA）。「宇宙は寒い」ではなく「宇宙は熱を受け取ってくれる相手がいない」が正確
- **「宇宙に出ると一瞬で凍る」**: 俗説。真空は断熱材（魔法瓶の中身）と同じで、体の熱はすぐには逃げない。先に起きるのは水分の沸騰・蒸発（37℃での蒸気圧 47 mmHg、Roth）と酸素不足による失神（12〜15秒）。表面の水分は蒸発で冷えて凍ることはあるが、体全体が「一瞬で」凍るわけではない
- **「血が沸騰する」**: 体の中は血圧があるので、血管の中の血がそのまま沸くわけではない、という説明が多い（二次）。Roth は静脈の入口に蒸気の泡ができると書く（一次）。台本は「体の水分が泡立つ」くらいに留めるのが安全
- **+121℃／−157℃**: NASA の原典ページが見つからない。一次で言うなら JAXA の **+120℃／−150℃**。NASA の podcast には「+500°F（約260℃）〜 −150°F」という別の値もある（ISS ではなく宇宙機一般、二次の要約で見た）。数字は「約±150℃」程度に丸めて言うのが安全
- **ウェッブの日よけの温度**: 同じ NASA のページの中で、図は +85℃／−233℃、計算モデルは 383K（+110℃）／36K（−237℃）。どちらを使うか決めて、出どころを1つに
- **日なた60分・日陰30分**: 季節と軌道の向きで変わる。太陽の当たる角度（β角）が大きい時期は、ISS がほとんど日陰に入らない周回が続く（今回は一次を確かめていない）。「ふつうは」と付ける
- **放熱板の面積と太陽電池の面積の比べ**: 放熱板 6基 約475 m² は片面の計算。太陽電池は 約2,500 m²（二次）〜 約3,000 m²（メーカー）と数え方で違う。比べに使うなら「放熱板は太陽電池の 5分の1ほど」と幅を持たせる
- **70 kW**: 設計上の上限。実際にいつも 70 kW 捨てているわけではない。ロシア側の区画は別の仕組みで、70 kW に入っていない（"from all U.S. and International Partner modules except the Russian modules"）。さらに太陽電池側の PVR が 4基 × 14 kW ある
- **ATCS Overview は 2006年ごろの資料**: "At assembly complete, there will be ..." の未来形が残る。今の ISS の数（放熱板 6基・PVR 4基）は資料の完成形の通りと見てよいが、2021年以降の新しい太陽電池（iROSA）の追加などで太陽電池の面積は増えている（未調査）
- **1966年の事故**: 年を 1965年とする記事・「14秒」「87秒で 14,000フィート相当まで戻した」など細部が記事ごとに違う（二次）。一次（Roth）にあるのは「1966年12月14日・0.5秒で 0.1 psia・12〜15秒で倒れた・肺の傷なし」だけ。本人の名前と「つばが泡立った」の話は二次と明記する
- **人の熱「約100W」**: NASA の一次は 88 W（睡眠）〜131 W（1日平均）〜191 W（起きて最大）。「約100W」は丸めた言い方
- **宇宙の 2.725K を「マイナス270℃」**: 2.725K = −270.425℃。「マイナス270℃」は正しい丸め。「絶対零度に近い」も可
- **Z-93 の放射率**: 0.91 は表の読み取りが崩れた資料から。台本は「約0.9」で
