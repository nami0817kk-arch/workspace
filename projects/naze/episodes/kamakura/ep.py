"""地形の回「なぜ幕府は鎌倉に置かれたのか」。

出典(notes.md にも):
- 鎌倉市「古都鎌倉のストーリー」(世界遺産): 南が海、三方を山に囲まれた内側に鶴岡八幡宮と若宮大路。尾根を垂直に掘り下げた「切通」
  https://www.city.kamakura.kanagawa.jp/sekaiisan/documents/story.pdf
- 鎌倉市 歴史的風致維持向上計画 2-2-6: 山稜部は中世「まちの中心部を三方から取り囲む自然の城壁」。中心部に出入りするには切通を通るか山境を越える他なく、
  防御システムとしても機能。代表的な七つの切通は「七口」(名越・朝夷奈・巨福呂坂・亀ヶ谷坂・仮粧坂・大仏・極楽寺)
  https://www.city.kamakura.kanagawa.jp/fuuchi/documents/2-2-6.pdf
- 鶴岡八幡宮の由緒(康平6年 1063 源頼義が由比郷に石清水八幡宮を勧請、治承4年 1180 頼朝が現在地へ遷す): 複数の資料で一致
- 標高: 国土地理院 標高タイル(地点の標高は自分で読んだ値)
- 地点の位置: 国土地理院 地名検索(msearch.gsi.go.jp)。鶴岡八幡宮・由比若宮は地図からの読み
"""
from naze import overlay as O

EP = dict(
    kind="terrain",
    title="なぜ幕府は鎌倉に置かれたのか",
    header="なぜ幕府は【鎌倉】に？",
    bbox=(139.515, 35.290, 139.600, 35.343),
    exag=3.0,
    # 低地(まち)は緑、山は黄土。海は標高タイルに値が無く暗い紺になる
    stops=[(-3, (24, 50, 80)), (0.5, (96, 150, 96)), (8, (120, 170, 104)), (16, (150, 180, 110)),
           (28, (176, 158, 100)), (50, (196, 160, 90)), (90, (222, 184, 110)), (150, (246, 226, 170))],
    tex_opts=dict(valley=0.0, photo=True, photo_sat=1.35, photo_gain=1.12),
    points=dict(
        center=(139.553, 35.317),
        hachimangu=(139.5565, 35.3259),
        wakamiya=(139.5523, 35.3203),
        umi=(139.5470, 35.3020),
        yuigahama=(139.5388, 35.3099),
        nagoe=(139.5652, 35.3078),
        asaina=(139.5884, 35.3261),
        kobukuro=(139.5540, 35.3284),
        yuiwakamiya=(139.5536, 35.3115),
        yama_w=(139.5400, 35.3200),     # 三方の尾根(標高は約60m・60m・100m)
        yama_n=(139.5560, 35.3340),
        yama_e=(139.5680, 35.3170),
    ),
    rise="data",
    pins=[dict(point="hachimangu", text="鶴岡八幡宮"), dict(point="yuigahama", text="由比ヶ浜")],
    lines=[
        dict(id="q", text="なぜ幕府は、鎌倉に置かれたの？", sub="なぜ幕府は\n【鎌倉】に\n置かれたの？", style="question", say="なぜばくふは、かまくらに、おかれたの？"),
        dict(id="data", text="答えは、地形にあります。鎌倉の地形を、立体にしてみました。", sub="答えは、【地形】にあります。|鎌倉の地形を、立体にしてみました。"),
        dict(id="umi", text="南は、海。", sub="南は、【海】。",
             labels=[dict(point="umi", text="相模湾", color=O.BLUE, at=0.1)]),
        dict(id="yama", text="東と北と西の三方は、山に囲まれています。", sub="東と北と西の三方は、\n【山】に囲まれています。",
             labels=[dict(point="yama_w", text="山", color=O.OCHRE, at=0.3), dict(point="yama_n", text="山", color=O.OCHRE, at=0.42),
                     dict(point="yama_e", text="山", color=O.OCHRE, at=0.54)]),
        dict(id="shiro", text="山が、城の壁のように、まちを守っているのです。", sub="山が、【城の壁】のように、\nまちを守っているのです。",
             profile=dict(a="yama_w", b="yama_e", at=0.05, names=["西の山", "東の山"])),
        dict(id="kiri", text="敵がまちに入るには、山を越えるか、山を切り開いた細い道、切通を通るしかありません。",
             sub="敵がまちに入るには、山を越えるか、|山を切り開いた細い道\n【切通】を通るしかありません。",
             say="てきがまちにはいるには、やまをこえるか、やまをきりひらいた、ほそいみち、きりどおしを、とおるしかありません。",
             labels=[dict(point="nagoe", text="名越切通", color=O.YEL, at=0.5)]),
        dict(id="mamori", text="道が細いので、少ない人数でも、守りやすかったのです。", sub="道が細いので、少ない人数でも、\n【守りやすかった】のです。"),
        dict(id="nana", text="主な入り口は、たった7つ。鎌倉七口と呼ばれます。", sub="主な入り口は、たった【7つ】。\n「鎌倉七口」と呼ばれます。",
             section=True, compare=dict(value="入り口 7つ", unit="切通", n=7, note="まちの外へ出る道の数", at=0.1),
             say="おもないりぐちは、たったななつ。かまくらななくちと、よばれます。",
             labels=[dict(point="nagoe", text="名越", color=O.YEL, at=0.0, below=True), dict(point="asaina", text="朝夷奈", color=O.YEL, at=0.15),
                     dict(point="kobukuro", text="巨福呂坂", color=O.YEL, at=0.3)]),
        dict(id="yukari", text="もう一つの理由は、ここが頼朝のご先祖さまゆかりの土地だったこと。約120年前、源氏の祖先が、ここに八幡さまをまつっていました。",
             sub="もう一つの理由は、ここが頼朝の\n【ご先祖さまゆかり】の土地だったこと。|約120年前、源氏の祖先が\nここに八幡さまをまつっていました。",
             say="もうひとつのりゆうは、ここが、よりともの、ごせんぞさま、ゆかりの、とちだったこと。やく、ひゃくにじゅうねんまえ、げんじのそせんが、ここに、はちまんさまを、まつっていました。",
             labels=[dict(point="yuiwakamiya", text="由比若宮（1063年）", color=O.OCHRE, at=0.5), dict(point="hachimangu", text="鶴岡八幡宮（1180年〜）", color=O.WHITE, at=0.75)]),
        dict(id="end", text="守りやすい地形と、ご先祖ゆかりの土地。だから頼朝は鎌倉を選んだ、と考えられています。",
             sub="守りやすい地形と、\n【ご先祖ゆかり】の土地。", style="end",
             say="まもりやすい、ちけいと、ごせんぞ、ゆかりの、とち。だから、よりともは、かまくらを、えらんだ、と、かんがえられています。"),
    ],
    shots=[
        dict(line="q", a=dict(look="center", dist=4.0, height=10.5, yaw=0), b=dict(look="center", dist=4.2, height=10.0, yaw=0)),
        dict(line="data", a=dict(look="center", dist=4.2, height=10.0, yaw=0), b=dict(look="center", dist=6.5, height=5.0, yaw=0)),
        dict(line="umi", a=dict(look="umi", dist=4.0, height=2.6, yaw=-10), b=dict(look="umi", dist=3.6, height=2.3, yaw=5)),
        dict(line="yama", a=dict(look="center", dist=4.6, height=3.6, yaw=0), b=dict(look="center", dist=4.3, height=3.4, yaw=10)),
        dict(line="shiro", a=dict(look="center", dist=7.5, height=5.5, yaw=-35), b=dict(look="center", dist=7.5, height=5.5, yaw=35)),
        dict(line="kiri", a=dict(look="nagoe", dist=2.6, height=1.5, yaw=20), b=dict(look="nagoe", dist=2.2, height=1.3, yaw=35)),
        dict(line="mamori", a=dict(look="nagoe", dist=3.2, height=2.0, yaw=-10), b=dict(look="nagoe", dist=3.0, height=1.9, yaw=5)),
        dict(line="nana", a=dict(look=[1.2, 0.3], dist=5.0, height=6.8, yaw=0), b=dict(look=[1.2, 0.3], dist=5.2, height=7.0, yaw=-8)),
        dict(line="yukari", a=dict(look="wakamiya", dist=3.6, height=2.6, yaw=0), b=dict(look="wakamiya", dist=3.3, height=2.4, yaw=8)),
        dict(line="end", a=dict(look="center", dist=5.0, height=5.5, yaw=0), b=dict(look="center", dist=5.6, height=6.4, yaw=0)),
    ],
)
