import io
assign = """0 T01 wide
1 B03 wide
2 B05 wide
3 B06 wide
4 T01 left
5 B05 right
6 T01 right
7 B03 left
8 B04 wide
9 B03 right
10 B03 wide
11 B05 left
12 B03 left
13 B04 left
14 B04 right
15 B04 wide
16 B08 wide
17 T01 wide
18 B04 left
19 B04 right
20 T01 right
21 B02 wide
22 B02 left
23 B01 wide
24 B01 left
25 B17 wide
26 B02 right
27 B05 wide
28 B05 left
29 B01 right
30 B17 wide
31 B02 wide
32 B04 right
33 B03 wide
34 B06 left
35 B06 wide
36 B06 right
37 B06 wide
38 B01 wide
39 B06 left
40 B17 left
41 B05 wide
42 B17 right
43 B06 right
44 T01 wide
45 B05 right
46 B02 wide
47 B12 wide
48 B06 wide
49 B06 left
50 B07 wide
51 B07 left
52 B06 right
53 B07 right
54 B05 wide
55 B01 wide
56 B17 wide
57 B17 left
58 B05 wide
59 B01 left
60 B17 right
61 B17 wide
62 B01 right
63 B05 left
64 B10 wide
65 B10 left
66 B05 right
67 B10 right
68 B10 wide
69 B17 wide
70 B01 wide
71 B10 left
72 B05 left
73 B17 left
74 B05 right
75 B01 wide
76 B08 wide
77 B05 wide
78 B09 left
79 B06 wide
80 B08 left
81 B08 right
82 B09 wide
83 B09 right
84 B02 wide
85 B09 left
86 B17 wide
87 B17 right
88 B05 right
89 B05 wide
90 B11 wide
91 B05 left
92 B08 wide
93 B10 wide
94 B11 left
95 B17 left
96 B04 wide
97 B05 wide
98 B08 right
99 B10 right
100 B05 left
101 B01 wide
102 B12 wide
103 B08 left
104 B01 left
105 B01 right
106 B15 wide
107 B04 left
108 B05 wide
109 B14 wide
110 B14 left
111 B11 wide
112 B12 left
113 B13 wide
114 B12 wide
115 B05 wide
116 T01 wide
117 B06 wide
118 B17 wide
119 B08 wide
120 B04 wide
121 B05 wide
122 B15 wide
end B15 wide""".splitlines()
cr = "crops: {wide: [1.12, 0.5, 0.5], left: [1.18, 0.4, 0.5], right: [1.18, 0.62, 0.5]}"
sc = {
 'T01': '夕暮れの海辺の港町。山と海にはさまれた狭い土地に、平安時代末の木造の御殿と港の船が見える（福原の想像図・人は小さな遠景、サムネと同じ絵）',
 'B01': '京の院の御所の一室、簾の奥の灯と、控える公家の後ろ姿（顔は描かない。義経の回の B01 を使う）',
 'B02': '朝霧の平安京の大路を進む、牛車と護衛の騎馬の長い行列（遠景・顔は描かない）',
 'B03': '山裾の別荘の庭、池と木造の建物、遠くに海（福原の清盛の山荘の想像図、人は描かない）',
 'B04': '瀬戸内の港、海に築いた人工島と防波の石積み、中国風の大きな船と日本の船（大輪田泊・経が島の想像図）',
 'B05': '灯のそばの机に広げた古い日記の巻物と筆（字は読めない。義経の回の B18 を使う）',
 'B06': '山と海にはさまれた狭い平地に、杭と縄で碁盤の目を測る人々の小さな遠景（条里を割る想像図）',
 'B07': '川を下る船に積まれた、解体した木造建物の柱と板（遷都のとき建物を運ぶ想像図、人は小さな遠景）',
 'B08': '霧のかかる山上の古い寺の堂塔の遠景（比叡山の想像図、字・旗は入れない）',
 'B09': '冬の朝、遠くに雪をかぶった富士山、川の対岸に並ぶ幕と焚き火の遠景（戦いは描かない）',
 'B10': '山の中の新しい木造の御殿、足場と材木が積まれた造営中の想像図（福原の新造内裏、人は描かない）',
 'B11': '夕暮れの京の屋敷の門の前を、牛車の列が帰ってくる遠景（顔は描かない）',
 'B12': '発掘された土の面に並ぶ石の列と、測量の杭（福原京の大路跡の想像図、現代の人は描かない）',
 'B13': '小さな鍛冶場の炉の火、金床、金槌、並べた鉄の釘（人は描かない）',
 'B14': '荒れた地面が畑に変わっていく、壊した家の木材が川辺に積まれた夕景（方丈記の想像図、人は小さな遠景）',
 'B15': '夕暮れの誰もいない海辺の草むらと、遠くの山（福原の跡の想像図、終了画面。右半分を空けた構図）',
 'B17': '薄暗い広間に向かい合って座る、公家の装束の人々の後ろ姿（会議の想像図、顔は描かない）',
}
ai = []
for k, v in sc.items():
    if k == 'B15':
        ai.append(f"  {k}: {{scene: {v}, crops: {{left: [1.12, 0.45, 0.5], wide: [1.12, 0.5, 0.5]}}, lock: [1.0, 0.5, 0.5]}}")
    else:
        ai.append(f"  {k}: {{scene: {v}, pan: h, {cr}}}")
shots = []
for a in assign:
    n, k, c = a.split()
    shots.append(f"  - {n} ai:{k} {c}")
shots = "\n".join(shots)
chap = """  0: {label: 序章 171日の都, now: 1180年6月2日, dates: {1: 1180年6月1日, 2: 1180年5月30日, 3: 1180年6月15日, 5: null}}
  1: {label: 第1章 なぜ福原だったのか, now: 1162年, dates: {10: 1168年, 12: 1169年3月, 13: 1170年, 14: 1173年, 15: 1180年3月19日, 21: 1179年11月, 22: null}}
  2: {label: 第2章 乱世に生まれて, now: 1179年11月14日, dates: {23: 1180年2月21日, 25: 1180年4月9日, 26: 1180年5月26日, 27: 1180年5月23日, 29: 1180年5月30日, 30: 1180年6月1日, 31: 1180年6月2日, 34: null}}
  3: {label: 第3章 分岐1 都の土地が足りていたら, now: 1180年6月9日, dates: {38: 1180年6月15日, 42: 1180年6月17日, 44: null, 47: 2026年11月, 48: null}}
  4: {label: 第4章 分岐2 公家が福原を都と認めていたら, now: 1180年7月16日, dates: {58: 1180年8月8日, 62: 1180年8月12日, 63: 1180年8月17日, 64: 1180年8月29日, 67: 1180年10月20日, 71: 1180年11月13日, 72: null}}
  5: {label: 第5章 分岐3 福原にとどまっていたら, now: 1180年9月5日, dates: {79: 1180年9月9日, 80: 1180年10月20日, 83: 1180年11月1日, 86: 1180年11月5日, 88: 1180年11月19日, 90: 1180年11月26日, 93: null}}
  6: {label: 第6章 その後 福原のあと, now: 1180年12月28日, dates: {104: 1181年閏2月4日, 107: 1183年, 108: null, 113: 2025年9月, 114: null}}
  7: {label: まとめ もしも福原遷都が成功していたら, now: null, dates: {}}"""
head = f"""# 物語型の本編（横 16:9）の見た目と絵の割り当て：もしも平清盛の福原遷都が成功していたら（scripts/kiyomori-fukuhara-if-story.yaml）。chiso/storymain.py が読む。
# 11-13 作成（11/17 19:00 公開）。yoshitsune_main_look.yaml を写した。台本には手を入れない（承認のあと）。
# 絵の方針：AI 絵（Gemini）。T01・B02〜B04・B06〜B15・B17 はこの回のために作る。B01（京の院の御所の簾）・B05（日記の巻物）は義経の回（yoshitsune-if）の B01・B18 のコピー。
#   実在の人物の顔は描かない（後ろ姿・遠景）。旗・家紋・字は入れない。戦い・遺体・火の手は描かない（南都・内裏の火は絵にしない）。
script: scripts/kiyomori-fukuhara-if-story.yaml
out: kiyomori_fukuhara_if_story_main
art_dir: out/story/kiyomori-fukuhara-if/ph
main_art_dir: out/story/kiyomori-fukuhara-if/main
ai_disclosure: この動画の人物・情景の画像は、Google の画像生成AI（Gemini）で作った想像上のイメージで、記録映像・実在の写真ではありません（画面の右上に「AI生成画像」と出しています）。

chapters:
{chap}

references:
  - "九条兼実『玉葉』（治承4年5月〜11月・治承5年閏2月の各条。国立国会図書館次世代デジタルライブラリーの全文テキストで確認、原本画像との照合は未了）"
  - "『百錬抄』・『吾妻鏡』治承4年条・『愚管抄』・『平家物語』・『元亨釈書』（同上）／鴨長明『方丈記』（國文大觀底本・Wikisource）"
  - "神戸市文書館 源平特集『福原遷都』・用語解説（高橋昌明, 2005）・神戸市兵庫区『大輪田の泊と平清盛の時代』・神戸市記者資料（2025-09-13, 2026-11-04）・摂津市・兵庫県の公開資料"
  - "日本歴史地名大系『福原』（平凡社）・世界大百科事典『港湾』・日本大百科全書・京都市『都市史03 条坊制』"
  - "島崎晋（マネーポストWEB 2024-10-20。山内晋次・下向井龍彦の説を引く）"
no_tag_from: 116

ai:
"""
tail = """
credits: {}

shots:
%s

figures:
  - {from: 40, to: 42, spec: {type: map, reveal: true, title: 都の候補地（6月15日〜17日）, bounds: [134.5, 136.0, 34.4, 35.2], places: [[和田, 135.18, 34.66], [小屋野, 135.40, 34.77], [印南野, 134.85, 34.78], [京都, 135.77, 35.01]]}}
  - {from: 32, to: 33, spec: {type: map, reveal: true, title: 6月2日の夜の宿, bounds: [134.9, 135.9, 34.5, 35.15], places: [[京都, 135.77, 35.01], [大物, 135.41, 34.73], [福原, 135.17, 34.70]]}}

focus: {}

fx:
  B15: {mist: {region: [0.0, 0.55, 1.0, 1.0]}}
  B08: {mist: {region: [0.0, 0.5, 1.0, 1.0]}}

paint_fx: {}

parts:
  - {type: quote, from: 1, to: 1, label: 史料, text: 泊まる所がない／すぐに来てはいけない, source: 清盛の返事（玉葉 1180年6月1日。今の言葉に）}
  - {type: quote, from: 2, to: 2, label: 史料, text: 乱世に生まれて、このような事を見る／悲しむべき宿業なり, source: 九条兼実『玉葉』（1180年5月30日。今の言葉に）}
  - {type: versus3, from: 14, to: 14, every: 3,
     items: [[高橋昌明, 1175年に築造], [百科事典, 1196年に重源が完成]]}
  - {type: versus3, from: 32, to: 32, every: 4,
     items: [[玉葉, 6月2日は大物に泊まる], [百錬抄, 6月2日は寺江の宮に入る]]}
  - {type: quote, from: 41, to: 41, label: 史料, text: 愚かな心で考えると／遷都は無いほうがよい, source: 九条兼実『玉葉』（1180年6月15日。今の言葉に）}
  - {type: quote, from: 44, to: 44, label: 史料, text: その地は狭くて、条里を割るにたらず／北は山に沿って高く、南は海に近く下る, source: 鴨長明『方丈記』（1212年。今の言葉に）}
  - {type: versus3, from: 84, to: 84, every: 4,
     items: [[玉葉, 追討使の帰京は11月5日], [百錬抄, 追討使の帰京は11月3日]]}
  - {type: versus3, from: 88, to: 88, every: 4,
     items: [[19日の知らせ, 26日出発・12月2日入京], [21日の知らせ, 23日出発・26日入京]]}
  - {type: quote, from: 91, to: 91, label: 史料, text: 神は福を降さず／人はみな、禍と呼ぶ, source: 九条兼実『玉葉』（1180年11月26日。今の言葉に）}
  - {type: quote, from: 109, to: 109, label: 史料, text: 都の風は、たちまち改まり／ただ田舎びた武士と変わらない, source: 鴨長明『方丈記』（1212年。今の言葉に）}
  - {type: quote, from: 121, to: 121, label: 史料, text: 衆庶の怨みを散じ／万民の望みに叶う, source: 九条兼実『玉葉』（1180年11月26日。今の言葉に）}

stills:
  - {line: 0, note: 冒頭（0秒）171日}
  - {line: 2, note: 序章 兼実の宿業}
  - {line: 14, note: 第1章 経が島の食い違い}
  - {line: 32, note: 第2章 夜の宿の食い違い}
  - {line: 41, note: 第3章 地図と兼実の言葉}
  - {line: 84, note: 第5章 追討使の食い違い}
  - {line: 88, note: 第5章 還都の日程}
  - {line: 109, note: 第6章 方丈記}
  - {end: true, note: 終了画面の空き}
""" % shots
io.open('scripts/story/kiyomori_fukuhara_main_look.yaml', 'w', encoding='utf-8').write(head + "\n".join(ai) + "\n" + tail)
print('ok')
