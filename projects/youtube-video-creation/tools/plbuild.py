"""プレミア20クラブ紹介を、ヴィラの見本の形で組み立てる（2026-09-19）。

ユーザー指示「取り入れたいのは、全部」「スタメン図は不要、登録選手一覧だけでよい」
「今夏、出ていった主力と今夏、加わった選手は不要」を受けて作ったヴィラの見本
（research/20260919_pl03_villa.yaml）と同じ節の並びにする。

    日本人がいれば入口（why） → 基礎DATA（main） → 有名なファン → そのクラブの話
    → 1990年以降の名選手 → 宿敵 → 登録選手一覧 → 今季のここまで

材料（すべて research/pl_data/）:
    <key>.json       基礎DATAの板と有名なファン（下請けが Wikipedia 原文から調べた）
    <key>_raw.json   登録選手と今季の結果（tools/plsquad.py が原文から抜いた）
    kana.json        選手名のカタカナ
**そのクラブの話と宿敵は、2026-09-16 の旧台本の節をそのまま使う**
（ユーザーに一度見せて通っている中身。作り直さない）。

    python tools/plbuild.py arsenal 02 20260916_pl02_arsenal.yaml
"""
from __future__ import annotations

import datetime
import json
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research" / "pl_data"
TODAY = datetime.date(2026, 9, 19)
NUM = "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳"
POS = [("GK", "ゴールキーパー"), ("DF", "ディフェンダー"), ("MF", "ミッドフィールダー"), ("FW", "フォワード")]
NAT = {"JPN": "日本", "ENG": "イングランド", "SCO": "スコットランド", "WAL": "ウェールズ", "NIR": "北アイルランド",
       "IRL": "アイルランド", "FRA": "フランス", "ESP": "スペイン", "POR": "ポルトガル", "GER": "ドイツ",
       "NED": "オランダ", "BEL": "ベルギー", "ITA": "イタリア", "SUI": "スイス", "AUT": "オーストリア",
       "DEN": "デンマーク", "SWE": "スウェーデン", "NOR": "ノルウェー", "POL": "ポーランド", "CZE": "チェコ",
       "CRO": "クロアチア", "SRB": "セルビア", "SVN": "スロベニア", "SVK": "スロバキア", "HUN": "ハンガリー",
       "UKR": "ウクライナ", "GRE": "ギリシャ", "TUR": "トルコ", "BRA": "ブラジル", "ARG": "アルゼンチン",
       "URU": "ウルグアイ", "COL": "コロンビア", "ECU": "エクアドル", "PAR": "パラグアイ", "CHI": "チリ",
       "PER": "ペルー", "VEN": "ベネズエラ", "MEX": "メキシコ", "USA": "アメリカ", "CAN": "カナダ",
       "JAM": "ジャマイカ", "SEN": "セネガル", "CIV": "コートジボワール", "GHA": "ガーナ", "NGA": "ナイジェリア",
       "CMR": "カメルーン", "MLI": "マリ", "GUI": "ギニア", "BFA": "ブルキナファソ", "COD": "コンゴ民主共和国",
       "MAR": "モロッコ", "ALG": "アルジェリア", "TUN": "チュニジア", "EGY": "エジプト", "RSA": "南アフリカ",
       "ZIM": "ジンバブエ", "ZAM": "ザンビア", "GAB": "ガボン", "GAM": "ガンビア", "KOR": "韓国", "AUS": "オーストラリア",
       "NZL": "ニュージーランド", "ISR": "イスラエル", "GEO": "ジョージア", "ARM": "アルメニア", "ALB": "アルバニア",
       "KOS": "コソボ", "BIH": "ボスニア・ヘルツェゴビナ", "MNE": "モンテネグロ", "MKD": "北マケドニア",
       "ISL": "アイスランド", "FIN": "フィンランド", "EST": "エストニア", "LTU": "リトアニア", "ROU": "ルーマニア",
       "BUL": "ブルガリア", "CUW": "キュラソー", "SUR": "スリナム", "HAI": "ハイチ", "CPV": "カーボベルデ",
       "ANG": "アンゴラ", "BEN": "ベナン", "TOG": "トーゴ", "UZB": "ウズベキスタン", "IRN": "イラン",
       "KSA": "サウジアラビア", "CHN": "中国", "BER": "バミューダ", "GRN": "グレナダ", "SLE": "シエラレオネ",
       "LUX": "ルクセンブルク", "CYP": "キプロス", "CRC": "コスタリカ", "HON": "ホンジュラス", "PAN": "パナマ",
       "BOL": "ボリビア", "DRC": "コンゴ民主共和国", "CGO": "コンゴ共和国", "SSD": "南スーダン", "LBY": "リビア",
       "KEN": "ケニア", "UGA": "ウガンダ", "MOZ": "モザンビーク", "EQG": "赤道ギニア", "GNB": "ギニアビサウ",
       "MTN": "モーリタニア", "NIG": "ニジェール", "DOM": "ドミニカ共和国", "TRI": "トリニダード・トバゴ",
       "FRO": "フェロー諸島", "LVA": "ラトビア", "BLR": "ベラルーシ", "MDA": "モルドバ", "AZE": "アゼルバイジャン",
       "KAZ": "カザフスタン", "SYR": "シリア", "IRQ": "イラク", "JOR": "ヨルダン", "PHI": "フィリピン",
       "IDN": "インドネシア", "THA": "タイ", "VIE": "ベトナム", "IND": "インド", "QAT": "カタール", "MLT": "マルタ",
       "GIB": "ジブラルタル", "AND": "アンドラ", "SMR": "サンマリノ", "LIE": "リヒテンシュタイン",
       "MNE ": "モンテネグロ", "BDI": "ブルンジ", "RWA": "ルワンダ", "SDN": "スーダン", "COM": "コモロ",
       "MAD": "マダガスカル", "TAN": "タンザニア", "ETH": "エチオピア", "LBR": "リベリア", "SLV": "エルサルバドル",
       "GUA": "グアテマラ", "NCA": "ニカラグア", "CUB": "キューバ", "PUR": "プエルトリコ", "MSR": "モントセラト",
       "GUY": "ガイアナ", "BAH": "バハマ", "BRB": "バルバドス", "ATG": "アンティグア・バーブーダ",
       "SKN": "セントクリストファー・ネイビス", "LCA": "セントルシア", "VIN": "セントビンセント",
       "DMA": "ドミニカ国", "GLP": "グアドループ", "MTQ": "マルティニーク", "GUF": "フランス領ギアナ"}


def age(dob: str) -> int | None:
    if not dob:
        return None
    y, m, d = map(int, dob.split("-"))
    return TODAY.year - y - ((TODAY.month, TODAY.day) < (m, d))


def boards(key: str, club: str, colors: list[str], squad: list[dict], kana: dict) -> list[tuple[str, str, int]]:
    """位置ごとに1枚。12人を超える位置は2枚に割る。年齢が分からない人は載せない（CLAUDE.md）。"""
    made = []
    for pos, label in POS:
        people = [p for p in squad if p["pos"] == pos and age(p["dob"]) is not None]
        chunks = [people] if len(people) <= 12 else [people[:len(people) // 2 + len(people) % 2], people[len(people) // 2 + len(people) % 2:]]
        for i, chunk in enumerate(chunks):
            if not chunk:
                continue
            suffix = "" if len(chunks) == 1 else "①②"[i]
            out = f"assets/stats/pl_{key}_{pos.lower()}{i + 1 if len(chunks) > 1 else ''}.png"
            args = [sys.executable, str(ROOT / "tools" / "squadboard.py"), str(ROOT / out), "--full",
                    "--colors", f"{colors[0]},#15090f",
                    "--title", f"{club} {label}{suffix}（{len(people)}人）", "--note", "年齢は2026年9月19日時点"]
            for p in chunk:
                # 主将の印は付けない。原文の印は副主将も拾い、リヴァプールで4人が「主将」になった
                extra = "・レンタル" if p.get("loan") else ""
                args += ["--row", f"{kana.get(p['name'], p['name'])}|{NAT.get(p['nat'], p['nat'])}・{age(p['dob'])}歳{extra}|"]
            subprocess.run(args, check=True, capture_output=True)
            made.append((out, label, len(people)))
    return made


def build(key: str, number: int, old_file: str) -> Path:
    facts = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
    raw = json.loads((DATA / f"{key}_raw.json").read_text(encoding="utf-8"))
    kana = json.loads((DATA / "kana.json").read_text(encoding="utf-8"))
    legends_all = json.loads((DATA / "pl_legends.json").read_text(encoding="utf-8"))
    old = yaml.safe_load((ROOT / "research" / old_file).read_text(encoding="utf-8"))
    # **読み上げる文はクラブごとに手で書く**（<key>_say.yaml）。板の文字をそのまま
    # 読ませると「収容 60,704人。」「(2018年〜)」のようになった（2026-09-20）
    ov_path = DATA / f"{key}_say.yaml"
    ov = yaml.safe_load(ov_path.read_text(encoding="utf-8")) if ov_path.exists() else {}
    club = old["theme"]["topic"]
    wiki = f"https://en.wikipedia.org/wiki/{raw['club_title']}"
    season_url = f"https://en.wikipedia.org/wiki/{raw['season_title']}"
    bg = f"assets/backgrounds/stadium_{facts['crest'].split('/')[-1].replace('.png', '')}.png"
    if not (ROOT / bg).exists():
        bg = None

    # 板
    subprocess.run([sys.executable, str(ROOT / "tools" / "clubdata.py"), str(ROOT / f"assets/stats/pl_{key}_data.png"),
                    "--spec", str(DATA / f"{key}.json")], check=True, capture_output=True)
    squad_boards = boards(key, club, facts["colors"], raw["squad"], kana)

    japanese = [p for p in raw["squad"] if p["nat"] == "JPN"]
    jp_names = [kana.get(p["name"], p["name"]) for p in japanese]

    def sec(**kw):
        if bg:
            kw.setdefault("bg", bg)
        kw.setdefault("official", False)
        return kw

    sections = []
    # 入口
    if japanese:
        who = "と".join(jp_names)
        lines = []
        for p in japanese:
            pos = dict(POS)[p["pos"]]
            lines.append(f"{kana.get(p['name'], p['name'])}は{age(p['dob'])}歳の{pos}です。")
        sections.append(sec(id="why", heading=f"{who}がいるクラブ", tier="報道",
                            telop=f"{who}が所属する{club}", narrator="キャスター",
                            say=ov.get("why") or ([f"日本人選手の{who}が所属しているのが、{club}です。"] + lines
                            + ["では、どんなクラブなのか。まずは基本のデータから見ていきます。"]),
                            sources=[wiki]))
    # 基礎DATA
    img = f"assets/stats/pl_{key}_data.png"
    say = [{"short_only": True, "text": f"{jp_names[0]}の所属クラブを、基本のデータで見ていきます。" if japanese else "このクラブの、基本のデータです。"}]
    if ov.get("data"):
        say += [{"image": img, "text": t} for t in ov["data"]]
    else:
        for label, big, small in facts["tiles"]:
            if label.startswith("有名なファン"):
                continue
            text = f"{label}は、**{big}**。" + (f"{small.rstrip('。')}。" if small else "")
            say.append({"image": img, "text": text})
    sections.append(sec(id="data", heading=f"{club} 基礎DATA", main=True, tier="背景",
                        telop=facts["tiles"][0][1] + "創立", narrator="解説", say=say,
                        sources=[wiki]))
    # 有名なファン
    fans = facts.get("fans") or []
    if fans:
        fsay = ov.get("fans") or [f"有名なファンもいます。いちばん知られているのは、**{fans[0]['name']}**。{fans[0]['who']}です。"]
        story = facts.get("fan_story") or {}
        if story.get("text") and not ov.get("fans"):
            fsay.append(story["text"])
        if len(fans) > 1 and not ov.get("fans"):
            fsay.append("ほかにも、" + "、".join(f"{f['who']}の{f['name']}" for f in fans[1:4]) + "の名前が挙がります。")
        sections.append(sec(id="fans", heading="有名なファン", tier="報道",
                            telop=f"{fans[0]['name']}も応援している", narrator="キャスター",
                            card={"type": "table", "title": f"{club}の有名なファン", "columns": ["", ""],
                                  "rows": [[f["name"], f["who"]] for f in fans[:5]]},
                            say=fsay,
                            sources=sorted({f["source"] for f in fans if f.get("source")} | ({story["source"]} if story.get("source") else set()))))
    # そのクラブの話・宿敵は旧台本から
    story_sec = next((s for s in old["sections"] if s["id"] == ov.get("story")), None) or next((s for s in old["sections"] if s.get("main")), None) or next(
        (s for s in old["sections"] if s["id"] not in ("name", "ground", "season", "rival", "legends", "titles")), None)
    rival_sec = next((s for s in old["sections"] if s["id"] == "rival"), None)
    if story_sec:
        story_sec = {k: v for k, v in story_sec.items() if k != "main"}
        if bg:
            story_sec["bg"] = bg
        sections.append(story_sec)
    # 名選手（1990年以降）
    leg = next((c for c in legends_all if c["club"].replace("・", "").replace("AFC", "") in club.replace("・", "") or club.replace("・", "") in c["club"].replace("・", "")), None)
    if leg:
        rows = ov.get("legend_rows") or [[l["name"], l["era"], l["why"][:24]] for l in leg["legends"]]
        lsay = ov.get("legends") or [f"{l['name']}。{l['numbers'].split('。')[0]}。" for l in leg["legends"]]
        sections.append(sec(id="legends", heading="このクラブを語る3人", tier="背景",
                            telop="1990年以降の名選手", narrator="キャスター",
                            card={"type": "table", "title": "1990年以降の名選手",
                                  "columns": ["名前", "在籍", "残したもの"], "rows": rows},
                            say=lsay, sources=[l["source"] for l in leg["legends"]]))
    if rival_sec:
        rival_sec = dict(rival_sec)
        if bg:
            rival_sec["bg"] = bg
        sections.append(rival_sec)
    # 登録選手
    ssay = [f"今季の登録選手は{sum(1 for p in raw['squad'] if age(p['dob']) is not None)}人です。"]
    seen = set()
    for out, label, n in squad_boards:
        if label in seen:
            ssay.append({"image": out, "text": f"{label}の続きです。"})
            continue
        seen.add(label)
        names = [kana.get(p["name"], p["name"]) for p in raw["squad"] if dict(POS).get(p["pos"]) == label and age(p["dob"]) is not None]
        jp = [n2 for n2 in names if n2 in jp_names]
        tail = f"日本の{jp[0]}もここにいます。" if jp else ""
        extra = (ov.get("squad") or {}).get(label, "")
        ssay.append({"image": out, "text": f"{label}は{n}人。{tail}{extra}"})
    sections.append(sec(id="squad", heading="今季の登録選手", tier="報道", telop="今季の登録選手",
                        narrator="キャスター", say=ssay, sources=[wiki]))
    # 今季のここまで（プレミアの節だけ）
    games = pl_games(key)
    if games:
        rows, w, d, l = [], 0, 0, 0
        for date, rnd, t1, score, t2 in games:
            home = club_matches(t1, raw["club_title"])
            a, b = [int(x) for x in score.replace("−", "–").replace("-", "–").split("–")[:2]]
            mine, theirs = (a, b) if home else (b, a)
            w += mine > theirs; d += mine == theirs; l += mine < theirs
            opp = ja_club(t2 if home else t1)
            rows.append([f"第{rnd}節", f"{opp}（{'ホーム' if home else 'アウェー'}）", f"{mine}対{theirs}"])
        record = f"{w}勝{d}引き分け{l}敗".replace("0勝", "").replace("0引き分け", "").replace("0敗", "")
        sections.append(sec(id="season", heading="今季のここまで", tier="報道", telop=f"{len(games)}試合で{record}",
                            narrator="解説",
                            card={"type": "table", "title": "プレミアリーグの結果", "columns": ["節", "相手", "結果"], "rows": rows},
                            say=[f"プレミアリーグは{len(games)}試合を終えて、**{record}**です。"] + (ov.get("season") or []),
                            sources=[season_url]))

    title_head = f"{jp_names[0]}がいる{club}" if japanese else club
    note = {
        "format": "news", "voice_min": 0, "slot": "premier_1", "date": "2026年9月19日",
        "people": jp_names + [club],
        "short_title": f"{title_head}ってどんなクラブ？"[:40],
        "theme": {"id": old["theme"]["id"], "league": "england", "league_name": "プレミアリーグ", "kind": "other",
                  "topic": club, "title": f"{title_head}ってどんなクラブ？ {NUM[number - 1]}プレミア20クラブ紹介",
                  "question": "どんなクラブなのか", "hook": old["theme"].get("hook", "")},
        "thumbnail": dict(old["thumbnail"]),
        "sections": sections,
    }
    out = ROOT / "research" / f"20260920_pl{number:02d}_{key}.yaml"
    header = (f"# プレミアリーグ20クラブ紹介 {NUM[number - 1]}{club}（2026-09-20 ヴィラの見本の形で作り直し）\n"
              f"# tools/plbuild.py で組み立て。材料は research/pl_data/{key}*.json と旧台本 {old_file}\n")
    out.write_text(header + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=1000), encoding="utf-8")
    return out


PL_TITLES = None


def pl_games(key: str) -> list[list[str]]:
    """プレミアの試合だけ。**スコアの形をしていて、両方が20クラブ**のもの。
    まだの試合は次の行（| report =）を拾っていた。欧州の試合も節番号が数字で混ざった。
    マンUのシーズン記事は結果をリーグの記事から読み込んでいて取れないので、
    **相手側の記事から拾う**（2026-09-19）。"""
    import re as _re
    raws = {p.name[:-9]: json.loads(p.read_text(encoding="utf-8")) for p in DATA.glob("*_raw.json")}
    titles = {k: v["club_title"] for k, v in raws.items()}
    me = titles[key]

    def is_pl(team):
        return any(club_matches(team, t) for t in titles.values())

    found = {}
    for k, v in raws.items():
        for date, rnd, t1, score, t2 in v["results"]:
            if not rnd.strip().isdigit() or not _re.fullmatch(r"\d+\s*[–−-]\s*\d+", score.strip()):
                continue
            if not (is_pl(t1) and is_pl(t2)):
                continue
            if club_matches(t1, me) or club_matches(t2, me):
                found[int(rnd)] = [date, rnd, t1, score.strip(), t2]
    return [found[r] for r in sorted(found)]


def ja_club(team: str) -> str:
    """相手の名前を日本語に。基礎DATAの板の題（「〇〇 基礎DATA」）から引く。"""
    for raw_file in DATA.glob("*_raw.json"):
        title = json.loads(raw_file.read_text(encoding="utf-8"))["club_title"]
        facts = DATA / raw_file.name.replace("_raw", "")
        if club_matches(team, title) and facts.exists():
            return json.loads(facts.read_text(encoding="utf-8"))["title"].replace(" 基礎DATA", "")
    return team


def club_matches(team: str, club_title: str) -> bool:
    base = club_title.replace("_", " ").replace(" F.C.", "").replace(" A.F.C.", "").replace("AFC ", "")
    t = team.replace("AFC ", "").strip()
    # 頭の1語で比べると、マンチェスター・シティとユナイテッドを取り違える
    return base == t or base in t or t in base


def main() -> int:
    key, number, old_file = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    print(build(key, number, old_file))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
