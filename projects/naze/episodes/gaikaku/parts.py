"""首都圏外郭放水路(型 I 見かけない・なのに＋A 水の行方): 本編 5 章とショート 5 本の台本と画面。ch1〜ch5・s1〜s5 の ep.py がここから読む。
台本は scripts.md(ユーザー確認済み 2026-11-18)。画面の作りは屋久島の回(episodes/yakushima/parts.py)と scene.py を写した。

数字の出典(国土交通省 関東地方整備局 江戸川河川事務所 ktr.mlit.go.jp/edogawa の「施設概要」「先端技術」):
- 調圧水槽: 長さ177m・幅78m・高さ18m、地下22m、柱 59 本(1 本 奥行き7m・幅2m・高さ18m・約500トン)、天井が多目的広場(サッカー場)。
  浮き上がりを抑えるため底・天井を厚くした。底と側壁の厚さは最小 3.5m、コンクリート約12万6000m³
- 立坑: 5 本、深さ約70m・内径約30m(掘削深さ 第1 76.5・第2 71.4・第3 74.8・第4 68.8・第5 74.5m)。地下連続壁の深さ140m(国内最深)。
  第3立坑は倉松川・中川から最大毎秒100m³・約60m落下(渦流式ドロップシャフト)。第3・第5はドロップシャフト
- トンネル: 延長約6.3km・最大内径約10.9m・土かぶり50m以上・最大水圧約0.6メガパスカル・シールド機外径12.04m
- 排水機場(庄和): ポンプ 4 台(1 台 毎秒50m³・合計毎秒200m³=25m プール 1 杯)・揚程14m(国内最大)・ガスタービン 1 台 1万4000馬力(航空機用)・
  地下23.6mまで掘った建物・樋管 6 本(1 本 横5.4m・縦4.2m)
- 効果: 2000 年 7 月台風 3 号(雨160mm)浸水114ha・236 戸 → 2002 年 7 月台風 6 号(雨164mm)浸水 2ha・0 戸(試験通水)。
  2004 年 10 月までの試験通水の洪水調節総量 約2500万m³(東京ドーム約20杯)。流域は「お皿のような地形」、川の勾配が緩やか、都市化で雨が一気に川へ
- 事業費約2,300億円・工事着手 1993 年 3 月・2006 年 6 月完成(国土交通省関東地方整備局の資料。NISTEP 科学技術動向 2006 年 7 月号は 13 年間の工事期間)
- 東京ドーム 4.67ha(建築面積)・容積 124 万m³
自分で測った・計算したもの(sim/measure.py。国土地理院の標高タイル z12、立坑の位置は OpenStreetMap の点):
- 春日部市役所の標高 約5.8m・荒川河口 約1m・まっすぐ約36km → 約5m下がる=1km で約14cm=100m で約1.4cm(1円玉9枚=1.5mm×9)
- 東西約27km・南北約39km の箱(139.65〜139.95E・35.80〜36.15N)の陸地の 56% が標高10m以下・19% が5m以下
- 第3立坑の底: 標高5.5m − 掘削深さ74.8m ≒ 海面下約69m
- 60m の自由落下: v=√(2×9.8×60)=34.3m/s=時速約123km(空気抵抗なし)
- 調圧水槽の容積 177×78×18=約25万m³(東京ドームの約5分の1)。浮力は内側の体積の水の重さ 約25万トン(壁と底を入れるともっと大きい)。
  コンクリート 12万6000m³×比重2.4=約30万トン。柱 59 本×約500トン=約3万トン。満水を毎秒200m³で汲むと 約21分
- 水圧 0.6MPa÷(1000×9.8)=約61m の水の深さ。ポンプの仕事 1000×9.8×200×14=約27MW、ガスタービン 1 万4000馬力×4=約41MW(1 馬力=0.7355kW)
- 浸水114ha ÷ 4.67ha ≒ 24 個、2ha ÷ 4.67ha ≒ 0.4 個
地点は地図から読んだ(読み)。"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
PH = HERE.parents[1] / "out" / "gaikaku" / "photos"
_SRC = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))

CREDIT = "地図: 国土地理院・NASA・Terrain Tiles"
RED, YEL, WHITE, BLUE = (240, 90, 80), (255, 214, 64), (255, 255, 255), (120, 190, 255)
GREY, GREEN = (170, 180, 200), (110, 200, 110)
RIVER = (70, 210, 255)
WARM = (255, 140, 70)

# 地点(経度, 緯度)。OpenStreetMap の点・国土地理院の地名検索(読み)
SH = {1: (139.8100, 35.9954), 2: (139.7971, 35.9903), 3: (139.7761, 35.9919), 4: (139.7607, 35.9935), 5: (139.7472, 35.9930)}
PUMP = (139.8117, 35.9973)
EDOGAWA = (139.8265, 35.9990)
KASUKABE, ARAKAWA = (139.7548, 35.9740), (139.8470, 35.6560)
TUNNEL = [SH[5], SH[4], SH[3], SH[2], SH[1], (139.8108, 35.9962)]

JAPAN = (139.0, 36.0, 8.0, 0)
KANTO = (139.8, 35.95, 1.9, 0)
AREA = (139.8, 35.975, 1.1, 0)
AREA_T = (139.8, 35.85, 1.0, 40)
CH = (139.779, 35.9935, 0.10, 0)
CH_T = (139.779, 35.980, 0.09, 40)
TANKV = (139.8100, 35.9965, 0.02, 0)
AREA_P = (139.8, 35.975, 0.9, 0)
CH_P = (139.779, 35.9935, 0.085, 0)
BOXPTS = [(139.65, 36.15), (139.95, 36.15), (139.95, 35.80), (139.65, 35.80), (139.65, 36.15)]


def MAP(view, *layers, view_to=None, step=None, tr=None):
    s = dict(shot="map", view=view, layers=list(layers))
    for k, v in (("view_to", view_to), ("step", step), ("tr", tr)):
        if v is not None:
            s[k] = v
    return s


def LABEL(at_ll, text, size=56, color=WHITE, at=0.0, on=None, id=None):
    d = dict(kind="label", at_ll=at_ll, text=text, size=size, color=color, id=id or f"lab_{text}", at=at)
    if on:
        d["on"] = on
    return d


def PIN(at_ll, text, id=None, at=0.0, size=44):
    return dict(kind="pin", at_ll=at_ll, text=text, id=id or f"pin_{text}", at=at, size=size)


def LINE(pts, color=YEL, width=6, id=None, at=0.0):
    return dict(kind="route", pts=pts, color=color, width=width, id=id or f"route_{pts[0]}", at=at)


def ARROW(a, b, color=YEL, width=14, id=None, at=0.0):
    return dict(kind="arrow", a=a, b=b, color=color, width=width, id=id or f"arr_{a}", at=at)


def TUN(tag="", w=10):
    return LINE(TUNNEL, YEL, w, id=f"tun{tag}")


def PHOTO(name, step=None, pan=None, zoom=None, tr=None):
    s = _SRC[name]
    d = dict(shot="illust", path=str(PH / f"{name}.jpg"), label=f"写真: {s['artist']}（{s['license']}）", step=step)
    if pan:
        d["pan"] = pan
    if zoom:
        d["zoom"] = zoom
    if tr:
        d["tr"] = tr
    return d


def CARD(big, sub=None, note=None, view=CH, step=None, count=True, tr=None):
    d = dict(shot="card", big=big, sub=sub, note=note, view=view, step=step, count=count)
    if tr:
        d["tr"] = tr
    return d


def BARS(items, title=None, note=None, fmt="{}", step=None, tr=None):
    d = dict(shot="bars", items=items, title=title, note=note, fmt=fmt, step=step)
    if tr:
        d["tr"] = tr
    return d


def UNDER(upto=6, step=None, tr=None, **kw):
    d = dict(shot="under", upto=upto, step=step)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


def SHAFT(mode="free", step=None, tr=None, **kw):
    d = dict(shot="shaft", mode=mode, step=step)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


def TANK(mode="plan", step=None, tr=None, **kw):
    d = dict(shot="tank", mode=mode, step=step)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


def FLAT(mode="profile", step=None, tr=None, **kw):
    d = dict(shot="flat", mode=mode, step=step)
    d.update(kw)
    if tr:
        d["tr"] = tr
    return d


MLIT, MINE = "国土交通省 江戸川河川事務所", "自分で測った（国土地理院の標高）"
FLOOD = BARS([("2000年7月 台風3号", 114, RED), ("2002年7月 台風6号", 2, BLUE)], title="浸水した土地（ヘクタール）", note=MLIT + "（雨はどちらも約160mm）", fmt="{}")
DOMES = BARS([("2000年7月", 24, RED), ("2002年7月", 0.4, BLUE)], title="浸水を東京ドームで数えると（個）", note="浸水面積÷4.67ha（自分で計算）", fmt="{}")
RESCUE = BARS([("2000年7月 台風3号", 236, RED), ("2002年7月 台風6号", 0, BLUE)], title="浸水した家（戸）", note=MLIT + "（雨は160mmと164mm）", fmt="{}")

ANSWERS = [("標高10m以下が56%の「お皿」", "海へ流れにくい"),
           ("国道16号の下、地下50m", "約6.3kmの通路を掘れた"),
           ("すぐ隣に、余裕のある江戸川", "毎秒200m³を逃がせた")]
_CV = [(AREA, AREA), (CH, CH), (CH_T, CH_T)]
CARDS_N = lambda n: dict(shot="cards", items=ANSWERS, n=n, view=_CV[n - 1][0], view_to=_CV[n - 1][1], step=4)  # noqa: E731

P = {}

# ---- 第1章 サッカー場の地下 ------------------------------------------------------------------------------
P["ch1"] = dict(title="第1章 サッカー場の地下", cta=False, lines=[
    dict(id="a1", text="埼玉県春日部市。サッカー場の地下に、巨大な空間があります。", scene=PHOTO("tankgold", step=0)),
    dict(id="a2", text="長さ177m、幅78m、高さ18m。", scene=CARD("177m × 78m × 18m", sub="調圧水槽の大きさ", note=MLIT, view=CH_T, step=0, count=False)),
    dict(id="a3", text="その中に、高さ18mの柱が、59本も並んでいます。", scene=TANK("plan", step=0, title="地下を上から見た柱", note=MLIT)),
    dict(id="a4", text="柱は1本が約500トン。大型バス、およそ50台ぶんの重さです。", scene=CARD("約500トン", sub="柱1本の重さ（大型バス 約50台ぶん）", note=MLIT, view=CH, step=0, count=False)),
    dict(id="a5", text="人は、ここを「地下神殿」と呼びます。でも、神殿ではありません。", scene=PHOTO("tank", step=0, pan=(0.12, 0.0, -0.08, 0.02), tr="whip")),
    dict(id="a6", text="洪水を逃がすための、川の一部です。", scene=MAP(CH_T, TUN("a6"), PIN(PUMP, "地下神殿", id="p_a6"), step=0, view_to=CH)),
    dict(id="a7", text="首都圏外郭放水路。地下約50mを、全長6.3kmにわたって流れる、地下の川です。", scene=UNDER(3, step=0, tr="zoom")),
    dict(id="a8", text="工事は約13年。事業費は約2,300億円かかりました。", scene=CARD("約2,300億円", sub="事業費（工事は約13年）", note=MLIT, view=CH, step=0, count=False)),
    dict(id="a9", text="なぜ、川を地面の下に造ったのか。", style="question", sub="地下50mに川を\n【造った】理由", scene=MAP(AREA, step=0)),
    dict(id="a10", text="答えを先に言います。", section=True),
    dict(id="a11", text="3つの条件が重なったからです。", scene=CARD("3つの条件", view=AREA_T, step=0, count=False)),
    dict(id="a12", text="1つ目。ここが、水が海へ流れにくい「お皿」の土地だったこと。", scene=MAP(AREA, LINE(BOXPTS, RED, 8, id="box_a12"), step=0)),
    dict(id="a13", text="2つ目。国道16号の下、地下50mに、6.3kmの通路を掘れたこと。", scene=UNDER(3, step=0)),
    dict(id="a14", text="3つ目。すぐ隣に、余裕のある江戸川があったこと。", scene=MAP(CH, TUN("a14"), LINE([PUMP, EDOGAWA], RIVER, 12, id="out_a14"), PIN(EDOGAWA, "江戸川", id="p_a14e"), step=0)),
    dict(id="a15", text="大雨のとき、水はこの地下の川に流れこみ、ポンプで江戸川へ送り出されます。", scene=UNDER(6, step=0)),
    dict(id="a16", text="数字は国土交通省の資料から。土地の高さは、国土地理院の標高データで、自分で測りました。", scene=MAP(CH_T, PIN(SH[3], "第3立坑", id="p_a16"), step=0)),
    dict(id="a17", text="まず、この町が「お皿」だという話から見ます。", section=True, scene=MAP(KANTO, step=0, view_to=AREA)),
])

# ---- 第2章 水が流れないお皿 --------------------------------------------------------------------------------
P["ch2"] = dict(title="第2章 水が流れないお皿", cta=False, lines=[
    dict(id="b1", text="1つ目の条件、土地の形です。", scene=MAP(KANTO, step=1, tr="zoom", view_to=AREA)),
    dict(id="b2", text="春日部市役所の標高は、約5.8m。", scene=MAP(AREA, PIN(KASUKABE, "春日部", id="p_b2"), step=1)),
    dict(id="b3", text="東京湾の入り口、荒川の河口は、約1m。", scene=MAP(AREA, LINE([KASUKABE, ARAKAWA], YEL, 8, id="ln_b3"), PIN(KASUKABE, "春日部", id="p_b3"), PIN(ARAKAWA, "荒川の河口", id="p_b3a"), step=1, view_to=(139.8, 35.82, 0.95, 0))),
    dict(id="b4", text="春日部から河口まで、まっすぐ約36km。", scene=CARD("約36km", sub="春日部 → 荒川の河口", note=MINE, view=(139.8, 35.82, 0.95, 0), step=1)),
    dict(id="b5", text="そのあいだに下がる高さは、たった約5mです。", scene=FLAT("profile", step=1, title="春日部から荒川の河口まで", note=MINE)),
    dict(id="b6", text="計算すると、1kmで約14cm。100m進んで、1円玉9枚ぶんしか下がりません。", scene=FLAT("coin", step=1, title="1kmで約14cm", note="自分で計算")),
    dict(id="b7", text="水は低いほうへ流れます。でも、こんなに平らだと、ほとんど進みません。", scene=MAP(AREA_T, step=1)),
    dict(id="b8", text="しかも、まわりを大きな川が囲んでいます。利根川、江戸川、荒川。", scene=MAP(KANTO, PIN((139.72, 36.12), "利根川", id="p_b8t"), PIN((139.84, 35.95), "江戸川", id="p_b8e"), PIN((139.74, 35.78), "荒川", id="p_b8a"), step=1, view_to=AREA)),
    dict(id="b9", text="どれも堤防に囲まれていて、水は横へ逃げられません。", scene=MAP(AREA, step=1, view_to=(139.8, 35.95, 0.7, 40))),
    dict(id="b10", text="東西約27km、南北約39kmのこの一帯。陸地の56%が、標高10m以下です。", scene=CARD("56%が標高10m以下", sub="東西約27km・南北約39kmの陸地", note=MINE, view=AREA, step=1, count=False)),
    dict(id="b11", text="5m以下も、19%あります。", scene=BARS([("標高10m以下", 56, BLUE), ("標高5m以下", 19, YEL)], title="この一帯の陸地の割合（%）", note=MINE, fmt="{}", step=1)),
    dict(id="b12", text="海へ流れにくい土地に、大雨が降ります。", section=True, scene=MAP(AREA_T, LINE(BOXPTS, RED, 8, id="box_b12"), step=1)),
    dict(id="b13", text="昔は、田んぼや低い土地が、雨水をためる役をしていました。", scene=MAP(AREA, step=1, view_to=(139.8, 35.96, 0.5, 0))),
    dict(id="b14", text="ところが、町が広がりました。地面は、屋根とアスファルトに覆われました。", scene=MAP(AREA, step=1, view_to=(139.76, 35.975, 0.2, 0), tr="zoom")),
    dict(id="b15", text="雨は地面にしみこまず、一気に川へ流れこみます。", scene=CARD("一気に川へ", sub="しみこまない雨", view=(139.76, 35.975, 0.2, 0), step=1, count=False)),
    dict(id="b16", text="国土交通省は、この一帯を「お皿のような地形」と呼んでいます。", scene=MAP(AREA_T, step=1)),
    dict(id="b17", text="皿に水が注がれて、出口は細い。あふれるのは、時間の問題でした。", scene=PHOTO("weir", step=1)),
    dict(id="b18", text="あふれたのは、中川、倉松川、大落古利根川、幸松川、18号水路。5つの川です。", scene=CARD("5つの川", sub="中川・倉松川・大落古利根川・幸松川・18号水路", note=MLIT, view=CH, step=1, count=False)),
    dict(id="b19", text="外郭放水路ができる前の、2000年7月。台風3号の雨は、合計160mmでした。", scene=CARD("160mm", sub="2000年7月 台風3号の雨（合計）", note=MLIT, view=AREA_T, step=1)),
    dict(id="b20", text="浸水した土地は114ヘクタール。東京ドーム、約24個ぶんです。", scene=DOMES),
    dict(id="b21", text="浸水した家は、236戸でした。", scene=CARD("236戸", sub="2000年7月の台風3号で浸水した家", note=MLIT, view=AREA, step=1)),
    dict(id="b22", text="この水を、どこへ逃がすのか。", section=True, scene=MAP(AREA, step=1)),
    dict(id="b23", text="選ばれたのが、地下50mでした。", scene=UNDER(3, step=1, tr="zoom")),
])

# ---- 第3章 地下50mの川 ------------------------------------------------------------------------------------
P["ch3"] = dict(title="第3章 地下50mの川", cta=False, lines=[
    dict(id="c1", text="2つ目の条件。地下50mに、川の通路を掘ることです。", scene=UNDER(3, step=2, tr="zoom")),
    dict(id="c2", text="水の入口は、川の堤防の一部を低くした「越流堤」です。", scene=PHOTO("weir", step=2, pan=(0.0, 0.05, 0.0, -0.05))),
    dict(id="c3", text="川の水位が、この高さを超えると、水が自然に流れこみます。", scene=MAP(CH, PIN(SH[5], "第5立坑", id="p_c3a"), PIN(SH[3], "第3立坑", id="p_c3b"), step=2)),
    dict(id="c4", text="ポンプもスイッチも、要りません。", scene=UNDER(4, step=2)),
    dict(id="c5", text="流れこんだ水は、まず「立坑」に落ちます。", section=True, scene=SHAFT("free", step=2, title="第3立坑の断面")),
    dict(id="c6", text="立坑は、地下に掘った巨大な円筒。全部で5本あります。", scene=MAP(CH_T, PIN(SH[5], "第5", id="p_c6a"), PIN(SH[4], "第4", id="p_c6b"), PIN(SH[3], "第3", id="p_c6c"), PIN(SH[2], "第2", id="p_c6d"), PIN(SH[1], "第1", id="p_c6e"), step=2)),
    dict(id="c7", text="深さは約70m、内径は約30m。自由の女神がすっぽり入る大きさです。", scene=CARD("深さ約70m・内径約30m", sub="立坑1本の大きさ（自由の女神が入る）", note=MLIT, view=CH, step=2, count=False)),
    dict(id="c8", text="第3立坑の底は、海面より約70mも下です。", scene=CARD("海面より約70m下", sub="第3立坑の底（標高5.5m−深さ74.8m）", note=MINE, view=CH_T, step=2, count=False)),
    dict(id="c9", text="ここには、倉松川と中川から、最大で毎秒100m³の水が入ります。", scene=MAP(CH, PIN(SH[3], "第3立坑", id="p_c9"), LABEL((139.7761, 36.0010), "最大 毎秒100m³", 54, WARM, on="毎秒"), step=2, view_to=(139.7761, 35.9925, 0.05, 0))),
    dict(id="c10", text="毎秒100m³は、25mプール半分ぶんの水が、1秒で来る量です。", scene=CARD("25mプール 半分/秒", sub="毎秒100m³", note=MLIT, view=CH, step=2, count=False)),
    dict(id="c11", text="その水が落ちる高さは、約60m。", section=True, scene=SHAFT("free", step=2, title="第3立坑の断面")),
    dict(id="c12", text="計算すると、落ちきったときの速さは時速約120km。空気の抵抗は、考えないことにします。", scene=CARD("時速約120km", sub="60m落ちた水の速さ（空気の抵抗なし）", note="自分で計算", view=CH_T, step=2, count=False)),
    dict(id="c13", text="高速道路を走る車より速い水が、底に当たり続ければ、底が壊れます。", scene=SHAFT("free", step=2, title="そのまま落とすと")),
    dict(id="c14", text="そこで、水を壁に沿って流す「渦流式ドロップシャフト」にしました。", section=True, scene=SHAFT("spiral", step=2, title="渦流式ドロップシャフト")),
    dict(id="c15", text="壁を伝ってらせんに落ちるので、底に当たる衝撃が和らぎます。", scene=SHAFT("both", step=2, title="そのまま落とす / 壁を伝う")),
    dict(id="c16", text="立坑の下から、トンネルが始まります。", section=True, scene=UNDER(3, step=2)),
    dict(id="c17", text="全長6.3km。内径は最大約10.9m。", scene=CARD("全長6.3km・内径約10.9m", sub="トンネル", note=MLIT, view=CH, step=2, count=False)),
    dict(id="c18", text="土の厚さは、50m以上です。", scene=MAP(CH_T, TUN("c18"), step=2)),
    dict(id="c19", text="深くなるほど、水圧は強くなります。トンネルが受ける水圧は、最大約0.6メガパスカル。", scene=CARD("約0.6メガパスカル", sub="トンネルが受ける水圧（最大）", note=MLIT, view=CH, step=2, count=False)),
    dict(id="c20", text="水の深さに直すと、約60mぶんです。", scene=CARD("水の深さ 約60m", sub="0.6メガパスカル÷（水の重さ）", note="自分で計算", view=CH_T, step=2, count=False)),
    dict(id="c21", text="この水圧の中で、直径約12mの掘削機が、トンネルを掘り進めました。", scene=UNDER(3, step=2)),
    dict(id="c22", text="立坑の壁は、深さ140mまで地下に埋めた壁で囲みました。国内でいちばん深い壁です。", scene=CARD("深さ140m", sub="立坑を囲む地下の壁（国内最深）", note=MLIT, view=CH, step=2, count=False)),
    dict(id="c23", text="ふだんのトンネルは、空っぽです。雨が降ったときだけ、水が走ります。", scene=UNDER(6, step=2)),
    dict(id="c24", text="走ってきた水は、最後に巨大な水槽に入ります。", scene=MAP(CH, TUN("c24"), PIN(PUMP, "調圧水槽", id="p_c24"), step=2, view_to=TANKV)),
])

# ---- 第4章 59本の柱 -------------------------------------------------------------------------------------
P["ch4"] = dict(title="第4章 59本の柱", cta=False, lines=[
    dict(id="d1", text="地下のトンネルを走った水は、巨大な水槽に流れこみます。", scene=UNDER(5, step=3, tr="zoom")),
    dict(id="d2", text="調圧水槽。長さ177m、幅78m、高さ18m。", scene=PHOTO("tankgold", step=3)),
    dict(id="d3", text="容積を計算すると、約25万m³。東京ドームの、およそ5分の1です。", scene=BARS([("調圧水槽", 25, BLUE), ("東京ドーム", 124, GREY)], title="容積（万m³）", note="自分で計算", fmt="{}", step=3)),
    dict(id="d4", text="役目は、水の勢いを弱めることです。", scene=TANK("plan", count=False, step=3, title="調圧水槽を上から見る")),
    dict(id="d5", text="ポンプが急に止まったとき、逆に押し返す水も、ここで受け止めます。", scene=UNDER(5, step=3)),
    dict(id="d6", text="ところが、この水槽には、大きな問題がありました。", section=True, scene=PHOTO("tank2", step=3, pan=(0.0, 0.0, 0.08, 0.0))),
    dict(id="d7", text="地下水の浮力です。", scene=CARD("地下水の浮力", view=CH_T, step=3, count=False)),
    dict(id="d8", text="水槽は、地下水の多い地面の中に造られています。", scene=TANK("float", step=3, span=(0.0, 0.2), title="地下の水槽にかかる力")),
    dict(id="d9", text="水が空っぽの水槽は、水に沈めた空の箱と同じです。", scene=TANK("float", step=3, span=(0.12, 0.3), title="水に沈めた空の箱")),
    dict(id="d10", text="内側の体積から計算すると、少なく見積もっても、25万トンぶんの水と同じ浮力です。", scene=CARD("25万トン以上", sub="空の水槽が受ける浮力（内側の体積から）", note="自分で計算", view=CH, step=3, count=False)),
    dict(id="d11", text="ほうっておけば、水槽は地面から浮き上がってしまいます。", scene=TANK("float", step=3, span=(0.2, 0.3), title="浮き上がる？")),
    dict(id="d12", text="そこで、重さを足しました。", section=True, scene=TANK("float", step=3, span=(0.3, 0.75), title="重さを足す")),
    dict(id="d13", text="底と壁の厚さは、最小でも3.5m。", scene=CARD("厚さ 3.5m以上", sub="底と壁（最小）", note=MLIT, view=CH_T, step=3, count=False)),
    dict(id="d14", text="使ったコンクリートは約12万6000m³。重さに直すと、およそ30万トンです。", scene=BARS([("地下水の浮力", 25, BLUE), ("コンクリートの重さ", 30, YEL)], title="浮力と重さ（万トン）", note=MLIT + "・自分で計算", fmt="{}", step=3)),
    dict(id="d15", text="天井の上には、土を盛りました。いま、その上が、サッカー場です。", scene=TANK("float", step=3, span=(0.78, 1.0), title="天井の上は、サッカー場")),
    dict(id="d16", text="さらに、天井と床を、柱でつなぎました。", scene=TANK("plan", count=False, step=3, title="柱が天井と床をつなぐ")),
    dict(id="d17", text="柱は59本。1本の大きさは、奥行き7m、幅2m、高さ18m。", scene=TANK("plan", step=3, title="調圧水槽の柱")),
    dict(id="d18", text="1本が約500トン。59本で、約3万トンです。", scene=BARS([("柱1本", 500, YEL), ("大型バス1台", 10, GREY)], title="重さ（トン）", note=MLIT, fmt="{:,}", step=3)),
    dict(id="d19", text="柱は、天井を支えるだけではありません。水槽が浮き上がるのを、押さえつける重しでもあります。", scene=PHOTO("tankgold", step=3, zoom=(1.06, 1.15))),
    dict(id="d20", text="神殿のように見える柱の並びは、浮き上がらないための設計でした。", scene=CARD("神殿 ＝ 重し", view=CH_T, step=3, count=False)),
    dict(id="d21", text="水槽の水は、ここから、隣のポンプ場へ送られます。", scene=MAP(CH, TUN("d21"), PIN(PUMP, "ポンプ場", id="p_d21"), step=3, view_to=TANKV)),
])

# ---- 第5章 毎秒200m³ -------------------------------------------------------------------------------------
P["ch5"] = dict(title="第5章 毎秒200m³", cta=True, lines=[
    dict(id="e1", text="3つ目の条件。逃がし先です。", scene=MAP(CH, LINE([PUMP, EDOGAWA], RIVER, 12, id="out_e1"), PIN(EDOGAWA, "江戸川", id="p_e1"), step=4, tr="zoom")),
    dict(id="e2", text="水槽の隣の庄和排水機場。地下23.6mの建物に、ポンプが4台あります。", scene=PHOTO("ryuq", step=4)),
    dict(id="e3", text="1台が、毎秒50m³。4台そろうと、毎秒200m³です。", scene=BARS([("ポンプ1台", 50, BLUE), ("4台そろうと", 200, YEL)], title="1秒に汲み出す水（m³）", note=MLIT, fmt="{}", step=4)),
    dict(id="e4", text="25mプール1杯の水を、1秒で汲み出す力です。", scene=CARD("25mプール 1杯/秒", sub="毎秒200m³", note=MLIT, view=CH, step=4, count=False)),
    dict(id="e5", text="水を持ち上げる高さは14m。排水機場として、国内最大です。", scene=CARD("14m", sub="水を持ち上げる高さ（国内最大）", note=MLIT, view=CH_T, step=4)),
    dict(id="e6", text="ポンプを回すのは、飛行機のエンジンを改造したガスタービン。", section=True, scene=PHOTO("ryuq", step=4, pan=(0.0, 0.1, 0.0, -0.05))),
    dict(id="e7", text="1台が1万4000馬力。4台で5万6000馬力です。", scene=BARS([("ガスタービン1台", 14000, BLUE), ("4台", 56000, YEL)], title="出力（馬力）", note=MLIT, fmt="{:,}", step=4)),
    dict(id="e8", text="100馬力の車に直せば、560台ぶんです。", scene=CARD("100馬力の車 560台ぶん", sub="5万6000馬力", note="自分で計算", view=CH, step=4, count=False)),
    dict(id="e9", text="毎秒200m³の水を、14m持ち上げる力を計算すると、約27メガワット。", scene=CARD("約27メガワット", sub="水を持ち上げる力（200m³/秒×14m）", note="自分で計算", view=CH_T, step=4, count=False)),
    dict(id="e10", text="ガスタービン4台の出力の、およそ3分の2にあたります。", scene=BARS([("水を持ち上げる力", 27, BLUE), ("ガスタービン4台の出力", 41, YEL)], title="大きさ（メガワット）", note="自分で計算", fmt="{}", step=4)),
    dict(id="e11", text="水槽の約25万m³なら、約21分で汲み出せる速さです。", scene=CARD("約21分", sub="水槽1杯（約25万m³）を汲み出す時間", note="自分で計算", view=CH, step=4, count=False)),
    dict(id="e12", text="汲み出された水は、6本の樋管を通って、江戸川に出ます。", scene=UNDER(6, step=4)),
    dict(id="e13", text="樋管1本の大きさは、横5.4m、縦4.2m。山手線の車両が、余裕で収まります。", scene=CARD("横5.4m × 縦4.2m", sub="樋管1本（6本ある）", note=MLIT, view=CH_T, step=4, count=False)),
    dict(id="e14", text="江戸川には、ゆとりがありました。", scene=MAP(CH, LINE([PUMP, EDOGAWA], RIVER, 12, id="out_e14"), PIN(EDOGAWA, "江戸川", id="p_e14"), step=4)),
    dict(id="e15", text="だから、あふれそうな川の水を、江戸川へ逃がせたのです。", scene=MAP(AREA, TUN("e15", 8), LINE([PUMP, EDOGAWA], RIVER, 12, id="out_e15"), step=4)),
    dict(id="e16a", text="効果を見ます。放水路ができる前、2000年7月の台風3号。", section=True, scene=CARD("2000年7月 台風3号", sub="放水路ができる前", note=MLIT, view=AREA_T, step=4, count=False)),
    dict(id="e16", text="雨は160mmで、浸水は114ヘクタール、236戸でした。", scene=RESCUE),
    dict(id="e17", text="一部が完成した2002年7月。台風6号の雨は164mm。ほぼ同じ雨でした。", scene=CARD("164mm", sub="2002年7月 台風6号の雨（前の台風とほぼ同じ）", note=MLIT, view=AREA, step=4)),
    dict(id="e18", text="浸水は、2ヘクタール。浸水した家は、0戸でした。", scene=FLOOD),
    dict(id="e19", text="東京ドーム約24個ぶんの浸水が、約0.4個ぶんまで減りました。", scene=DOMES),
    dict(id="e20a", text="試験通水を始めてからの2年4か月で、約2,500万m³の洪水を調節しました。", scene=CARD("約2,500万m³", sub="2002年6月〜2004年10月に調節した洪水", note=MLIT, view=AREA_T, step=4)),
    dict(id="e20", text="東京ドーム、約20杯ぶんです。", scene=CARD("東京ドーム 約20杯", sub="約2,500万m³ ÷ 約124万m³（自分で計算）", note=MLIT, view=AREA, step=4)),
    dict(id="e21", text="答えをまとめます。", section=True, scene=CARDS_N(1)),
    dict(id="e22", text="海へ流れにくい、標高10m以下が56%の「お皿」だったこと。", scene=CARDS_N(1)),
    dict(id="e23", text="国道16号の下、地下50mに、6.3kmの通路を掘れたこと。", scene=CARDS_N(2)),
    dict(id="e24", text="余裕のある江戸川が、すぐ隣にあったこと。", scene=CARDS_N(3)),
    dict(id="e25", text="だから、川は地下に造られました。", scene=UNDER(6, step=4)),
    dict(id="e26", text="次に、大雨のニュースで「外郭放水路が稼働」と聞いたら、地下50mで水が走っている様子を、思い出してください。", scene=PHOTO("tankgold", step=4, pan=(0.1, 0.0, -0.06, 0.02))),
])

# ---- ショート 5 本 ---------------------------------------------------------------------------------------
P["s1"] = dict(title="地下神殿の柱が59本ある理由", lines=[
    dict(id="s1_1", text="サッカー場の地下22mに、柱が59本並ぶ空間があります。", scene=PHOTO("tankgold")),
    dict(id="s1_2", text="首都圏外郭放水路の、調圧水槽です。", scene=MAP(CH_P, PIN(PUMP, "調圧水槽", id="p_s11"), view_to=TANKV)),
    dict(id="s1_3", text="長さ177m、幅78m、高さ18m。", scene=TANK("plan", count=False, title="地下を上から見る")),
    dict(id="s1_4", text="なぜ、こんなに柱が必要なのか。", style="question", sub="柱が59本\n【必要】な理由", scene=PHOTO("tank", pan=(0.1, 0.0, -0.06, 0.02))),
    dict(id="s1_5", text="答えは、水槽が浮き上がるのを、押さえるためです。", scene=TANK("float", span=(0.15, 0.3), title="浮き上がる水槽")),
    dict(id="s1_6", text="水槽は、地下水の多い地面の中にあります。", scene=TANK("float", span=(0.0, 0.2), title="地下水の中の水槽")),
    dict(id="s1_7", text="空っぽの水槽は、水に沈めた箱と同じです。", scene=CARD("沈めた空の箱", view=CH_P, count=False)),
    dict(id="s1_8", text="内側の体積から計算すると、25万トンぶんの水と同じ浮力です。", scene=CARD("25万トン", sub="空の水槽が受ける浮力", note="自分で計算", view=CH_P)),
    dict(id="s1_9", text="柱は1本が約500トン。59本で、約3万トンです。", scene=TANK("plan", title="上から見た柱")),
    dict(id="s1_10", text="コンクリートの壁と床、天井の上の土も、重しになっています。", scene=BARS([("浮力", 25, BLUE), ("コンクリートの重さ", 30, YEL)], title="万トン", note=MLIT + "・自分で計算", fmt="{}")),
    dict(id="s1_11", text="浮力に負けない重さを、足し続けた結果が、あの景色です。", scene=PHOTO("tankgold", zoom=(1.06, 1.12))),
    dict(id="s1_12", text="次に地下神殿の写真を見たら、柱の数を数えてください。", scene=TANK("plan", title="上から見た柱")),
])
P["s2"] = dict(title="25mプールを1秒で空にするポンプ", lines=[
    dict(id="s2_1", text="25mプール1杯の水を、1秒で汲み出すポンプがあります。", scene=CARD("25mプール 1杯/秒", view=CH_P, count=False)),
    dict(id="s2_2", text="首都圏外郭放水路の、庄和排水機場です。", scene=PHOTO("ryuq")),
    dict(id="s2_3", text="1台が毎秒50m³、4台で毎秒200m³。", scene=BARS([("ポンプ1台", 50, BLUE), ("4台そろうと", 200, YEL)], title="1秒に汲み出す水（m³）", note=MLIT, fmt="{}")),
    dict(id="s2_4", text="なぜ、そんな力が出せるのか。", style="question", sub="毎秒200m³を\n【汲み出す】力", scene=PHOTO("ryuq", pan=(0.0, 0.1, 0.0, -0.05))),
    dict(id="s2_5", text="答えは、飛行機のエンジンを改造した、ガスタービンです。", scene=PHOTO("ryuq", zoom=(1.06, 1.12))),
    dict(id="s2_6", text="1台が1万4000馬力。4台で5万6000馬力。", scene=BARS([("1台", 14000, BLUE), ("4台", 56000, YEL)], title="出力（馬力）", note=MLIT, fmt="{:,}")),
    dict(id="s2_7", text="100馬力の車に直せば、560台ぶんです。", scene=CARD("100馬力の車 560台", view=CH_P, count=False)),
    dict(id="s2_8", text="水を毎秒200m³、14m持ち上げる力を計算すると、約27メガワット。", scene=CARD("約27メガワット", sub="200m³/秒×14m", note="自分で計算", view=CH_P)),
    dict(id="s2_9", text="ガスタービン4台の出力の、およそ3分の2です。", scene=BARS([("水を持ち上げる力", 27, BLUE), ("ガスタービン4台", 41, YEL)], title="メガワット", note="自分で計算", fmt="{}")),
    dict(id="s2_10", text="汲み出された水は、江戸川へ流れていきます。", scene=MAP(CH_P, LINE([PUMP, EDOGAWA], RIVER, 12, id="out_s2"), PIN(EDOGAWA, "江戸川", id="p_s2"))),
    dict(id="s2_11", text="次に雨が続いたら、地下で飛行機のエンジンが回っているかもしれません。", scene=PHOTO("ryuq", zoom=(1.06, 1.15))),
])
P["s3"] = dict(title="地下に落ちる水を、そのまま落とせない理由", lines=[
    dict(id="s3_1", text="地下の川には、60mの高さから、水が落ちてきます。", scene=SHAFT("free", title="第3立坑")),
    dict(id="s3_2", text="首都圏外郭放水路の、第3立坑です。", scene=MAP(CH_P, PIN(SH[3], "第3立坑", id="p_s31"), view_to=(139.7761, 35.9925, 0.04, 0))),
    dict(id="s3_3", text="最大で、毎秒100m³。25mプール半分ぶんが、1秒で落ちます。", scene=CARD("25mプール 半分/秒", sub="毎秒100m³", note=MLIT, view=CH_P, count=False)),
    dict(id="s3_4", text="なぜ、そのまま落とさないのか。", style="question", sub="水を\n【そのまま落とせない】", scene=PHOTO("shaft")),
    dict(id="s3_5", text="計算すると、60m落ちた水の速さは、時速約120km。", scene=CARD("時速約120km", sub="60m落ちた水（空気の抵抗なし）", note="自分で計算", view=CH_P)),
    dict(id="s3_6", text="高速道路の車より速い水が、底に当たり続けるのです。", scene=SHAFT("free", title="底に当たる水")),
    dict(id="s3_7", text="底が、壊れてしまいます。", scene=PHOTO("shaft")),
    dict(id="s3_8", text="そこで、水を壁に沿って流す「渦流式ドロップシャフト」にしました。", scene=SHAFT("spiral", title="渦流式ドロップシャフト")),
    dict(id="s3_9", text="らせんを描いて落ちるので、衝撃が和らぎます。", scene=SHAFT("both", title="そのまま / 壁を伝う")),
    dict(id="s3_10", text="立坑の深さは約70m、内径は約30m。自由の女神が入る大きさです。", scene=CARD("深さ約70m・内径約30m", sub="自由の女神が入る大きさ", note=MLIT, view=CH_P, count=False)),
    dict(id="s3_11", text="次に滝を見たら、水の速さを思い出してください。", scene=PHOTO("shaft", zoom=(1.06, 1.1))),
])
P["s4"] = dict(title="春日部が水に弱い理由", lines=[
    dict(id="s4_1", text="春日部から東京湾まで、まっすぐ約36km。", scene=MAP(AREA_P, LINE([KASUKABE, ARAKAWA], YEL, 8, id="ln_s4"), PIN(KASUKABE, "春日部", id="p_s41"), view_to=(139.8, 35.82, 0.8, 0))),
    dict(id="s4_2", text="そのあいだに下がる高さは、たった約5mです。", scene=FLAT("profile", title="春日部から荒川の河口まで", note=MINE)),
    dict(id="s4_3", text="なぜ、この一帯は洪水に悩まされたのか。", style="question", sub="洪水に\n【悩まされた】一帯", scene=MAP(AREA_P, LINE(BOXPTS, RED, 8, id="box_s4"))),
    dict(id="s4_4", text="答えは、土地がお皿のように平らだからです。", scene=MAP((139.8, 35.9, 0.75, 40))),
    dict(id="s4_5", text="計算すると、1kmで約14cm。100m進んで、1円玉9枚ぶんしか下がりません。", scene=FLAT("coin", title="1kmで約14cm", note="自分で計算")),
    dict(id="s4_6", text="利根川、江戸川、荒川に囲まれ、水は横へ逃げられません。", scene=MAP((139.7, 35.9, 1.6, 0), PIN((139.72, 36.12), "利根川", id="p_s46t"), PIN((139.84, 35.95), "江戸川", id="p_s46e"), PIN((139.74, 35.78), "荒川", id="p_s46a"))),
    dict(id="s4_7", text="この一帯の陸地の56%は、標高10m以下です。", scene=CARD("56%が標高10m以下", sub="東西約27km・南北約39km", note=MINE, view=AREA_P, count=False)),
    dict(id="s4_8", text="そこへ、町が広がり、雨が一気に川へ流れこむようになりました。", scene=MAP(AREA_P, view_to=(139.76, 35.975, 0.2, 0))),
    dict(id="s4_9", text="水は、あふれるしかありません。", scene=PHOTO("weir")),
    dict(id="s4_10", text="次に川の流れを見たら、土地の傾きを思い出してください。", scene=FLAT("profile", title="ほとんど傾かない土地")),
])
P["s5"] = dict(title="同じ雨なのに、浸水が114ヘクタールから2ヘクタールになった理由", lines=[
    dict(id="s5_1", text="2000年7月、台風3号。雨は160mmでした。", scene=CARD("160mm", sub="2000年7月 台風3号の雨", note=MLIT, view=AREA_P)),
    dict(id="s5_2", text="浸水は114ヘクタール、236戸。", scene=RESCUE),
    dict(id="s5_3", text="2002年7月、台風6号。雨は164mm。ほぼ同じです。", scene=CARD("164mm", sub="2002年7月 台風6号の雨", note=MLIT, view=AREA_P)),
    dict(id="s5_4", text="浸水は、2ヘクタール。浸水した家は、0戸でした。", scene=FLOOD),
    dict(id="s5_5", text="なぜ、同じ雨で、こんなに違ったのか。", style="question", sub="同じ雨で\n【浸水が減った】理由", scene=MAP(AREA_P)),
    dict(id="s5_6", text="答えは、首都圏外郭放水路が、水を地下へ逃がしたからです。", scene=UNDER(6)),
    dict(id="s5_7", text="川からあふれそうな水を、地下50mのトンネルへ。", scene=MAP(CH_P, TUN("s57"), PIN(SH[3], "第3立坑", id="p_s57"))),
    dict(id="s5_8", text="そして、ポンプで江戸川へ送り出します。", scene=PHOTO("ryuq")),
    dict(id="s5_9", text="東京ドーム約24個ぶんの浸水が、約0.4個ぶんまで減りました。", scene=DOMES),
    dict(id="s5_10", text="試験通水の2年4か月で、約2,500万m³の洪水を調節しています。", scene=CARD("約2,500万m³", sub="2002年6月〜2004年10月", note=MLIT, view=AREA_P)),
    dict(id="s5_11", text="次に大雨のニュースを見たら、地下の川のことを思い出してください。", scene=PHOTO("tankgold", zoom=(1.06, 1.1))),
])

# ---- 読み ------------------------------------------------------------------------------------------------
YOMI = [("首都圏外郭放水路", "しゅとけんがいかくほうすいろ"), ("外郭放水路", "がいかくほうすいろ"), ("春日部", "かすかべ"), ("調圧水槽", "ちょうあつすいそう"),
        ("庄和排水機場", "しょうわはいすいきじょう"), ("排水機場", "はいすいきじょう"), ("越流堤", "えつりゅうてい"), ("立坑", "たてこう"), ("樋管", "ひかん"),
        ("渦流式ドロップシャフト", "うずりゅうしきドロップシャフト"), ("倉松川", "くらまつがわ"), ("大落古利根川", "おおおとしふるとねがわ"), ("幸松川", "さちまつがわ"),
        ("中川", "なかがわ"), ("利根川", "とねがわ"), ("江戸川", "えどがわ"), ("荒川", "あらかわ"), ("国道16号", "こくどうじゅうろくごう"), ("山手線", "やまのてせん"),
        ("18号水路", "ジュウハチゴオスイロ"), ("台風3号", "たいふうさんごう"), ("台風6号", "たいふうろくごう"), ("東京ドーム", "とうきょうドーム"),
        ("ヘクタール", "ヘクタール"), ("2000年", "二千年"), ("2002年", "二千二年"), ("2004年", "二千四年"), ("177m", "百七十七メートル"), ("78m", "七十八メートル"),
        ("18m", "十八メートル"), ("59本", "五十九本"), ("約500トン", "約五百トン"), ("50台", "五十台"), ("560台", "五百六十台"),
        ("約2,300億円", "約二千三百億円"), ("約13年", "約十三年"), ("約50m", "約五十メートル"), ("50m", "五十メートル"), ("6.3km", "六点三キロ"), ("約5.8m", "約五点八メートル"),
        ("約1m", "約一メートル"), ("約36km", "約三十六キロ"), ("約5m", "約五メートル"), ("約14cm", "約十四センチ"), ("1kmで", "一キロで"), ("100m", "百メートル"),
        ("1円玉9枚", "一円玉九枚"), ("約27km", "約二十七キロ"), ("約39km", "約三十九キロ"), ("56%", "五十六パーセント"), ("19%", "十九パーセント"),
        ("10m以下", "十メートル以下"), ("5m以下", "五メートル以下"), ("160mm", "百六十ミリ"), ("164mm", "百六十四ミリ"), ("114ヘクタール", "百十四ヘクタール"),
        ("236戸", "二百三十六戸"), ("約24個", "約二十四個"), ("約0.4個", "約〇点四個"), ("2ヘクタール", "二ヘクタール"), ("0戸", "ゼロ戸"),
        ("約70m", "約七十メートル"), ("約30m", "約三十メートル"), ("約60m", "約六十メートル"), ("毎秒100m³", "毎秒百立方メートル"), ("毎秒200m³", "毎秒二百立方メートル"),
        ("毎秒50m³", "毎秒五十立方メートル"), ("約25万m³", "約二十五万立方メートル"), ("約2,500万m³", "約二千五百万立方メートル"), ("12万6000m³", "十二万六千立方メートル"),
        ("m³", "立方メートル"), ("25m", "二十五メートル"), ("25万トン", "二十五万トン"), ("30万トン", "三十万トン"), ("約3万トン", "約三万トン"),
        ("時速約120km", "時速約百二十キロ"), ("約10.9m", "約十点九メートル"), ("約12m", "約十二メートル"), ("0.6メガパスカル", "れいてんろくメガパスカル"),
        ("23.6m", "二十三点六メートル"), ("14m", "十四メートル"), ("1万4000馬力", "一万四千馬力"), ("5万6000馬力", "五万六千馬力"), ("100馬力", "百馬力"),
        ("約27メガワット", "約二十七メガワット"), ("約21分", "約二十一分"), ("5.4m", "五点四メートル"), ("4.2m", "四点二メートル"), ("3.5m", "三点五メートル"),
        ("140m", "百四十メートル"), ("2年4か月", "二年四か月"), ("約20杯", "約二十杯"), ("7m", "七メートル"), ("2m", "二メートル"), ("22m", "二十二メートル"),
        ("5本", "ごほん"), ("5分の1", "ごぶんのいち"), ("3分の2", "さんぶんのに"), ("6本", "ろっぽん"), ("4台", "よんだい"), ("1台", "いちだい"),
        ("1つ目", "ひとつめ"), ("2つ目", "ふたつめ"), ("3つ目", "みっつめ"), ("3つ", "みっつ"), ("1杯", "いっぱい"), ("1秒", "いちびょう"),
        ("1本", "いっぽん"), ("1km", "一キロ"), ("地下水", "ちかすい"), ("真下", "ました"), ("浮力", "ふりょく"), ("神殿", "しんでん"), ("洪水", "こうずい"),
        ("試験通水", "シケンツウスイ"), ("越えた", "こえた"), ("超える", "こえる"), ("盛りました", "もりました"), ("2枚", "にまい"), ("堤防", "ていぼう"), ("水位", "すいい"), ("標高", "ひょうこう"),
        ("国土地理院", "こくどちりいん"), ("国土交通省", "こくどこうつうしょう"), ("自由の女神", "じゆうのめがみ"), ("地下連続壁", "ちかれんぞくへき")]


def yomi(s):
    for a, b in YOMI:
        s = s.replace(a, b)
    return s


SAY = {}


def ep_for(name: str) -> dict:
    p = dict(P[name])
    res = []
    for l in p["lines"]:
        if (name, l["id"]) in SAY:
            l = dict(l, say=SAY[(name, l["id"])])
        elif "say" not in l:
            y = yomi(l["text"])
            if y != l["text"]:
                l = dict(l, say=y)
        res.append(l)
    p["lines"] = res
    return dict(kind="sim", aspect="portrait" if name.startswith("s") else "landscape", credit=CREDIT, **p)
