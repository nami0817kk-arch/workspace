"""物語の型: 「雪辱戦」「勝ち上がり」「一騎打ち」などを、数行の指定からエピソード(episode.py)に組む。純粋な Python。

戦いだけの動画に、起承転結(負ける → 鍛える → 再戦して勝つ)と、台詞・ナレーション・場面カード・BGM の雰囲気を付ける。
人物の名前・色・武器は引数で変えられる。戦いの中身は fight.py(蹴り/連打/反撃/大技)。

    story: {arc: revenge, hero: ミドリ, rival: アカ}

arc:
    revenge     雪辱戦(敗北 → 修行 → 再戦で勝つ)。約 35 秒
    tournament  勝ち上がり(1回戦 → 準決勝 → 決勝。相手が強くなる)。約 40 秒
    duel        一騎打ち(因縁の相手に挑む。1本)。約 15 秒
    protect     守る戦い(追い詰められる → 守るために立ち上がる)。約 25 秒
    mentor      師の教え(稽古で負ける → 教えを胸に強敵を倒す)。約 25 秒
"""
from __future__ import annotations

from typing import Dict, List

GREEN = [0.3, 0.68, 0.1]
RED = [0.8, 0.1, 0.08]
BLUE = [0.15, 0.4, 0.9]
GRAY = [0.55, 0.55, 0.58]
PURPLE = [0.55, 0.2, 0.7]


def _card(text: str, sub: str = "", dur: float = 2.0, style: str = "title") -> dict:
    c = dict(text=text, dur=dur, style=style)
    if sub:
        c["sub"] = sub
    return dict(card=c)


def revenge(hero: str, rival: str, hero_color=GREEN, rival_color=RED, **_) -> dict:
    items: List[dict] = [
        _card("雪辱戦", f"{hero} vs {rival}", 2.4),
        dict(scene=dict(name="s1_defeat", fight=dict(
            weapon="sword", kick=False, hits=3, counter=False, finisher="none", palette="cool", mood="tense", stage="night",
            colors=dict(A=rival_color, B=hero_color),
            lines=[dict(at="opening", dur=1.8, kind="narr", text=f"最強を名乗る剣士{hero}は、宿敵{rival}に挑んだ。"),
                   dict(at="rise", dt=-0.3, dur=1.2, kind="say", who="A", text="その程度か？"),
                   dict(at="last", dt=0.0, dur=1.2, kind="say", who="B", text="くっ…！"),
                   dict(at="ko", dt=0.2, dur=1.8, kind="narr", text=f"{hero}は、敗れた。"),
                   ]))),
        _card("一か月後", "", 1.6, "time"),
        dict(scene=dict(name="s2_training", fight=dict(
            weapon="sword", kick=False, hits=4, counter=False, finisher="none", palette="cool", mood="calm", stage="dojo",
            colors=dict(A=hero_color, B=GRAY),
            lines=[dict(at="opening", dur=1.8, kind="narr", text="来る日も、来る日も、ただ剣を振った。"),
                   dict(at="combo", dt=0.0, dur=1.0, kind="say", who="A", text="もっと…速く！"),
                   dict(at="last", dt=0.1, dur=1.2, kind="say", who="A", text="見えた…！"),
                   ]))),
        _card("決戦の日", "", 1.6, "time"),
        dict(scene=dict(name="s3_rematch", fight=dict(
            weapon="sword", kick=True, hits=3, counter=True, finisher="launch_slash", palette="warm", mood="battle", stage="sunset",
            colors=dict(A=hero_color, B=rival_color),
            lines=[dict(at="opening", dur=1.6, kind="narr", text=f"再び、{rival}の前に立った。"),
                   dict(at="opening", dt=1.0, dur=1.2, kind="say", who="B", text="また来たのか。"),
                   dict(at="kick", dt=-0.5, dur=1.0, kind="say", who="A", text="今度は、負けない！"),
                   dict(at="counter", dt=0.15, dur=1.0, kind="say", who="B", text="なに…！？"),
                   dict(at="finisher", dt=-0.25, dur=1.1, kind="shout", text="必殺・燕返し！"),
                   dict(at="ko", dt=0.5, dur=1.8, kind="say", who="B", text="見事だ…"),
                   ]))),
        _card("完", f"{hero}は、もっと強くなる。", 2.4),
    ]
    return dict(name="ep_revenge", mood_cards="sad", items=items)


def tournament(hero: str, rival: str, hero_color=GREEN, rival_color=RED, **_) -> dict:
    rounds = [("第1回戦", BLUE, dict(weapon="none", kick=False, hits=2, counter=False, finisher="none", palette="cool", mood="battle", stage="field"),
               [dict(at="opening", dur=1.6, kind="narr", text=f"勝ち上がりの大会。{hero}の最初の相手は、素手の格闘家。"),
                dict(at="last", dur=1.0, kind="say", who="A", text="まずは一勝！")]),
              ("準決勝", PURPLE, dict(weapon="sword", kick=True, hits=2, counter=True, finisher="none", palette="warm", mood="battle", stage="dojo"),
               [dict(at="opening", dur=1.6, kind="narr", text="相手は、剣の使い手。簡単には勝たせてくれない。"),
                dict(at="counter", dt=0.15, dur=1.0, kind="say", who="B", text="やるな！"),
                dict(at="last", dur=1.0, kind="say", who="A", text="まだまだ！")]),
              ("決勝", rival_color, dict(weapon="sword", kick=True, hits=3, counter=True, finisher="launch_slash", palette="warm", mood="battle", stage="sunset"),
               [dict(at="opening", dur=1.8, kind="narr", text=f"決勝の相手は、無敗の王者{rival}。"),
                dict(at="finisher", dt=-0.25, dur=1.1, kind="shout", text="これが、俺の全力だ！"),
                dict(at="ko", dt=0.5, dur=1.8, kind="narr", text=f"{hero}が、優勝を決めた。")])]
    items: List[dict] = [_card("勝ち上がり", f"{hero}の挑戦", 2.2)]
    for i, (name, col, spec, lines) in enumerate(rounds):
        items.append(_card(name, "", 1.5))
        items.append(dict(scene=dict(name=f"r{i + 1}", fight=dict(spec, colors=dict(A=hero_color, B=col), lines=lines))))
    items.append(_card("完", "", 2.0))
    return dict(name="ep_tournament", mood_cards="calm", items=items)


def duel(hero: str, rival: str, hero_color=GREEN, rival_color=RED, **_) -> dict:
    items = [_card("一騎打ち", f"{hero} vs {rival}", 2.0),
             dict(scene=dict(name="duel", fight=dict(
                 weapon="sword", kick=True, hits=3, counter=True, finisher="launch_slash", palette="warm", mood="battle", stage="night",
                 colors=dict(A=hero_color, B=rival_color),
                 lines=[dict(at="opening", dur=1.8, kind="narr", text=f"因縁の決着。{hero}は、{rival}の前に立った。"),
                        dict(at="kick", dt=-0.5, dur=1.0, kind="say", who="A", text="ここで終わらせる！"),
                        dict(at="finisher", dt=-0.25, dur=1.1, kind="shout", text="必殺・燕返し！")]))),
             _card("完", "", 1.8)]
    return dict(name="ep_duel", mood_cards="sad", items=items)


def protect(hero: str, rival: str, hero_color=GREEN, rival_color=RED, **_) -> dict:
    items: List[dict] = [
        _card("守る者", f"{hero}の戦い", 2.2),
        dict(scene=dict(name="p1_corner", fight=dict(
            weapon="sword", kick=False, hits=2, counter=False, finisher="none", palette="cool", mood="tense", stage="sunset",
            colors=dict(A=rival_color, B=hero_color),
            lines=[dict(at="opening", dur=1.8, kind="narr", text=f"村を襲う{rival}の前に、{hero}がひとり立ちはだかった。"),
                   dict(at="rise", dt=-0.3, dur=1.2, kind="say", who="A", text="どけ。邪魔をするな。"),
                   dict(at="last", dur=1.2, kind="say", who="B", text="ぐっ……！"),
                   ]))),
        _card("それでも", "", 1.5, "time"),
        dict(scene=dict(name="p2_stand", fight=dict(
            weapon="sword", kick=True, hits=4, counter=False, finisher="launch_slash", palette="warm", mood="battle", stage="sunset",
            colors=dict(A=hero_color, B=rival_color),
            lines=[dict(at="opening", dur=1.6, kind="narr", text="背中には、守るべき人たちがいる。"),
                   dict(at="kick", dt=-0.5, dur=1.1, kind="say", who="A", text="ここは、通さない！"),
                   dict(at="finisher", dt=-0.25, dur=1.1, kind="shout", text="守り抜く！"),
                   dict(at="ko", dt=0.5, dur=1.8, kind="narr", text="朝日が、村を照らした。"),
                   ]))),
        _card("完", "", 2.0),
    ]
    return dict(name="ep_protect", mood_cards="sad", items=items)


def mentor(hero: str, rival: str, hero_color=GREEN, rival_color=RED, **_) -> dict:
    items: List[dict] = [
        _card("師の教え", f"{hero}と、師匠", 2.2),
        dict(scene=dict(name="m1_spar", fight=dict(
            weapon="sword", kick=False, hits=3, counter=False, finisher="none", palette="cool", mood="calm", stage="dojo",
            colors=dict(A=BLUE, B=hero_color),
            lines=[dict(at="opening", dur=1.8, kind="narr", text=f"道場。{hero}は、師匠に稽古をつけてもらっていた。"),
                   dict(at="rise", dt=-0.3, dur=1.2, kind="say", who="A", text="力任せでは、勝てぬ。"),
                   dict(at="last", dur=1.2, kind="say", who="B", text="まだ、届かない……！"),
                   ]))),
        _card("旅立ちの日", "", 1.6, "time"),
        dict(scene=dict(name="m2_boss", fight=dict(
            weapon="sword", kick=True, hits=3, counter=True, finisher="launch_slash", palette="warm", mood="battle", stage="field",
            colors=dict(A=hero_color, B=rival_color),
            lines=[dict(at="opening", dur=1.6, kind="narr", text=f"旅の果て、{rival}との決戦。"),
                   dict(at="counter", dt=0.15, dur=1.0, kind="say", who="B", text="力で、ねじ伏せてやる！"),
                   dict(at="last", dt=0.1, dur=1.0, kind="say", who="A", text="力じゃない……見切るんだ！"),
                   dict(at="finisher", dt=-0.25, dur=1.1, kind="shout", text="師の一閃！"),
                   ]))),
        _card("完", f"教えは、{hero}の中に生きている。", 2.4),
    ]
    return dict(name="ep_mentor", mood_cards="calm", items=items)


ARCS = dict(revenge=revenge, tournament=tournament, duel=duel, protect=protect, mentor=mentor)


def build_story(spec: dict) -> dict:
    arc = spec.get("arc", "revenge")
    if arc not in ARCS:
        raise ValueError(f"物語の型 {arc} はない。使えるのは {', '.join(ARCS)}")
    kw = {k: v for k, v in spec.items() if k != "arc"}
    ep = ARCS[arc](hero=kw.pop("hero", "ミドリ"), rival=kw.pop("rival", "アカ"), **kw)
    if "name" in spec:
        ep["name"] = spec["name"]
    return ep
