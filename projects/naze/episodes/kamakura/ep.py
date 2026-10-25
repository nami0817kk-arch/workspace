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
    tex_opts=dict(valley=0.0),
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
    lines=[
        dict(id="q", text="なぜ幕府は、鎌倉に置かれたの？", sub="なぜ幕府は\n【鎌倉】に\n置かれたの？", style="question", say="なぜばくふは、かまくらに、おかれたの？"),
        dict(id="data", text="国土地理院の標高データで、鎌倉の地形を立体にしてみました。", sub="国土地理院の標高データで、\n鎌倉の地形を立体にしてみました。"),
        dict(id="umi", text="まちの南は、海。", sub="まちの南は、【海】。",
             labels=[dict(point="umi", text="相模湾", color=O.BLUE, at=0.1)]),
        dict(id="yama", text="そして残りの三方は、山に囲まれています。", sub="そして残りの三方は、\n【山】に囲まれています。",
             labels=[dict(point="yama_w", text="山", color=O.OCHRE, at=0.35), dict(point="yama_n", text="山", color=O.OCHRE, at=0.45),
                     dict(point="yama_e", text="山", color=O.OCHRE, at=0.55)]),
        dict(id="shiro", text="この山の連なりは、中世、まちを三方から囲む、自然の城壁として使われました。",
             sub="この山の連なりは、中世、|まちを三方から囲む、\n【自然の城壁】として使われました。"),
        dict(id="kiri", text="山を越える道は、尾根を垂直に掘り下げた、切通。", sub="山を越える道は、\n尾根を垂直に掘り下げた、【切通】。",
             say="やまをこえるみちは、おねを、すいちょくにほりさげた、きりどおし。",
             labels=[dict(point="nagoe", text="名越切通", color=O.YEL, at=0.4)]),
        dict(id="nana", text="代表的な切通は七つ。鎌倉七口と呼ばれます。", sub="代表的な切通は七つ。\n【鎌倉七口】と呼ばれます。",
             say="だいひょうてきな、きりどおしは、ななつ。かまくらななくちと、よばれます。",
             labels=[dict(point="nagoe", text="名越", color=O.YEL, at=0.0, below=True), dict(point="asaina", text="朝夷奈", color=O.YEL, at=0.15),
                     dict(point="kobukuro", text="巨福呂坂", color=O.YEL, at=0.3)]),
        dict(id="mamori", text="まちに入るには、切通を通るか、山を越えるしかありません。守りに強いまちだったのです。",
             sub="まちに入るには、切通を通るか、\n山を越えるしかありません。|【守りに強い】\nまちだったのです。", say="まちにはいるには、きりどおしを、とおるか、やまをこえるしかありません。まもりに、つよいまちだったのです。"),
        dict(id="yukari", text="さらに鎌倉は、頼朝の祖先、源頼義が八幡宮を祀った、源氏ゆかりの土地でもありました。",
             sub="さらに鎌倉は、頼朝の祖先・源頼義が\n八幡宮を祀った、|【源氏ゆかり】の\n土地でもありました。",
             say="さらにかまくらは、よりともの、そせん、みなもとのよりよしが、はちまんぐうを、まつった、げんじゆかりの、とちでもありました。",
             labels=[dict(point="yuiwakamiya", text="由比若宮（1063年）", color=O.OCHRE, at=0.2), dict(point="hachimangu", text="鶴岡八幡宮（1180年〜）", color=O.WHITE, at=0.55)]),
        dict(id="end", text="守りやすい地形と、源氏ゆかりの地。鎌倉は、武士の都にぴったりの場所だったのです。",
             sub="守りやすい地形と、\n【源氏ゆかりの地】。", style="end",
             say="まもりやすい、ちけいと、げんじゆかりの、ち。かまくらは、ぶしの、みやこに、ぴったりの、ばしょだったのです。"),
    ],
    shots=[
        dict(line="q", a=dict(look="center", dist=4.0, height=10.5, yaw=0), b=dict(look="center", dist=4.2, height=10.0, yaw=0)),
        dict(line="data", a=dict(look="center", dist=4.2, height=10.0, yaw=0), b=dict(look="center", dist=6.5, height=5.0, yaw=0)),
        dict(line="umi", a=dict(look="umi", dist=4.0, height=2.6, yaw=-10), b=dict(look="umi", dist=3.6, height=2.3, yaw=5)),
        dict(line="yama", a=dict(look="center", dist=4.6, height=3.6, yaw=0), b=dict(look="center", dist=4.3, height=3.4, yaw=10)),
        dict(line="shiro", a=dict(look="center", dist=7.5, height=5.5, yaw=-35), b=dict(look="center", dist=7.5, height=5.5, yaw=35)),
        dict(line="kiri", a=dict(look="nagoe", dist=2.6, height=1.5, yaw=20), b=dict(look="nagoe", dist=2.2, height=1.3, yaw=35)),
        dict(line="nana", a=dict(look=[1.2, 0.3], dist=5.0, height=6.8, yaw=0), b=dict(look=[1.2, 0.3], dist=5.2, height=7.0, yaw=-8)),
        dict(line="mamori", a=dict(look="wakamiya", dist=5.0, height=3.0, yaw=-15), b=dict(look="wakamiya", dist=4.6, height=2.8, yaw=0)),
        dict(line="yukari", a=dict(look="wakamiya", dist=3.6, height=2.6, yaw=0), b=dict(look="wakamiya", dist=3.3, height=2.4, yaw=8)),
        dict(line="end", a=dict(look="center", dist=5.0, height=5.5, yaw=0), b=dict(look="center", dist=5.6, height=6.4, yaw=0)),
    ],
)
