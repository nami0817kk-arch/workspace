"""プレミア20クラブ紹介を、ヴィラの見本の形で組み立てる（2026-09-19）。

ユーザー指示「取り入れたいのは、全部」「スタメン図は不要、登録選手一覧だけでよい」
「今夏、出ていった主力と今夏、加わった選手は不要」を受けて作ったヴィラの見本
（research/20260919_pl03_villa.yaml）と同じ節の並びにする。

    日本人がいれば入口（why） → 基礎DATA（main） → そのクラブの話
    → 1990年以降の名選手 → 登録選手一覧 → 今季のここまで

**有名なファンの節は 2026-09-20 に廃止した**（ユーザー指示）。板の9枚目も愛称にしてある。
**宿敵の節も 2026-09-20 に廃止した**（ユーザー指示「宿敵は不要」）。

材料（すべて research/pl_data/）:
    <key>.json       基礎DATAの板（下請けが Wikipedia 原文から調べた）
    <key>_raw.json   登録選手と今季の結果（tools/plsquad.py が原文から抜いた）
    kana.json        選手名のカタカナ
**そのクラブの話は、2026-09-16 の旧台本の節をそのまま使う**
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
# **これ未満の出場数は「有名な選手」として出さない。**「1試合」は紹介にならない
CAPS_MIN = 10
# 代表の名前（Wikipedia の英語表記）を日本語に
TEAM_JA = {"England": "イングランド", "Scotland": "スコットランド", "Wales": "ウェールズ",
           "Northern Ireland": "北アイルランド", "Republic of Ireland": "アイルランド",
           "France": "フランス", "Spain": "スペイン", "Portugal": "ポルトガル",
           "Germany": "ドイツ", "Netherlands": "オランダ", "Belgium": "ベルギー",
           "Italy": "イタリア", "Switzerland": "スイス", "Austria": "オーストリア",
           "Denmark": "デンマーク", "Sweden": "スウェーデン", "Norway": "ノルウェー",
           "Poland": "ポーランド", "Czech Republic": "チェコ", "Croatia": "クロアチア",
           "Serbia": "セルビア", "Slovenia": "スロベニア", "Slovakia": "スロバキア",
           "Hungary": "ハンガリー", "Ukraine": "ウクライナ", "Greece": "ギリシャ",
           "Turkey": "トルコ", "Brazil": "ブラジル", "Argentina": "アルゼンチン",
           "Uruguay": "ウルグアイ", "Colombia": "コロンビア", "Ecuador": "エクアドル",
           "Paraguay": "パラグアイ", "Chile": "チリ", "Peru": "ペルー",
           "Mexico": "メキシコ", "United States": "アメリカ", "Canada": "カナダ",
           "Jamaica": "ジャマイカ", "Senegal": "セネガル", "Ivory Coast": "コートジボワール",
           "Ghana": "ガーナ", "Nigeria": "ナイジェリア", "Cameroon": "カメルーン",
           "Mali": "マリ", "Guinea": "ギニア", "Morocco": "モロッコ",
           "Algeria": "アルジェリア", "Tunisia": "チュニジア", "Egypt": "エジプト",
           "South Africa": "南アフリカ", "Japan": "日本", "South Korea": "韓国",
           "Australia": "オーストラリア", "New Zealand": "ニュージーランド", "Israel": "イスラエル", "Georgia": "ジョージア",
           "Albania": "アルバニア", "Kosovo": "コソボ", "Iceland": "アイスランド",
           "Finland": "フィンランド", "Romania": "ルーマニア", "Zimbabwe": "ジンバブエ",
           "DR Congo": "コンゴ民主共和国", "Uzbekistan": "ウズベキスタン",
           "Curaçao": "キュラソー", "Cape Verde": "カーボベルデ", "Angola": "アンゴラ",
           "Burkina Faso": "ブルキナファソ", "Gambia": "ガンビア", "Benin": "ベナン"}
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
                # **主将の印を戻した**（2026-09-20）。落としていたのは、原文の印を
                # `|` の手前だけ読んでいて副主将まで拾っていたから（リヴァプールで4人が
                # 「主将」になった）。plsquad.py が見える字で判じるようにしたので戻せる
                extra = ("・主将" if p.get("captain") else "") + ("・レンタル" if p.get("loan") else "")
                args += ["--row", f"{kana.get(p['name'], p['name'])}|{NAT.get(p['nat'], p['nat'])}・{age(p['dob'])}歳{extra}|"]
            subprocess.run(args, check=True, capture_output=True)
            # **同じ引数をとっておく**。あとで「話している選手だけ明るい板」を
            # 作り直すのに要る。ここで作れないのは、誰を紹介するかが
            # 読み上げを組み立てるときに決まるから
            made.append({"out": out, "label": label, "count": len(people), "args": args})
    return made


def lit_board(board: dict, names: list[str]) -> str:
    """その板の、**話している選手の行だけ明るい**版を作る（2026-09-21）。

    Gemini の指摘「10人ぶんの名前を出したまま読み上げても、どれがその人か
    探せない」を受けた（ユーザーが選んだ案）。名前が1つも無ければ元の板のまま。
    """
    names = [n for n in names if n]
    if not names:
        return board["out"]
    out = board["out"].replace(".png", "_f.png")
    args = list(board["args"])
    args[2] = str(ROOT / out)
    for name in names:
        args += ["--focus", name]
    done = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
    if done.returncode or "■" in (done.stderr or ""):
        # **黙って全部沈んだ板を出さない。**当たらなければ元の板に戻す
        print(f"　板の名前が当たりません（{board['label']}）: {done.stderr.strip()}")
        return board["out"]
    return out


def split_card(section: dict, per_card: int = 3) -> dict:
    """長い節の表カードを2〜3枚に割る（2026-09-24）。

    **1枚のカードが20〜56秒そのまま出ていた**（review の「カードの持ち」が
    18クラブで鳴った）。ボーンマスは `story_sections` で手で割ってあるので通る。
    残りは旧台本の節をそのまま使うため、7〜12行が1枚のカードで通っていた。

    割るのは**行**ではなく**表の中身**。話が進むにつれて表も進むので、
    「まだ話していない行が先に画面へ出る」（2026-09-20 に手割りを選んだ理由）も薄まる。
    表以外のカード（引用・箇条書き）は割らない。
    """
    card = dict(section.get("card") or {})
    say = list(section.get("say") or [])
    rows = list(card.get("rows") or [])
    # **4行でも割る**（2026-09-24 の2回目。6行以上にしていたら、5行の節が
    # 21〜28秒で残った）。3行の節（18秒）は割らない
    if str(card.get("type")) != "table" or len(say) < 4 or len(rows) < 2:
        return section
    # 10行を超える節は4枚まで（フォレストのクラフは12行で、3枚でも21.8秒あった）
    chunks = min(4, max(2, -(-len(say) // per_card)), len(rows))
    size = -(-len(rows) // chunks)
    parts = [rows[i:i + size] for i in range(0, len(rows), size)]
    step = len(say) / len(parts)
    marks = {int(round(k * step)): parts[k] for k in range(1, len(parts))}
    out = []
    for index, item in enumerate(say):
        if index in marks:
            item = dict(item) if isinstance(item, dict) else {"text": item}
            item["card"] = dict(card, rows=marks[index])
        out.append(item)
    return dict(section, say=out, card=dict(card, rows=parts[0]))


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
    # **下地はスタジアムの「中」の実写**（2026-09-23 指摘「最初の画面が魅力的ではなくて、
    # 視聴者が離れそう」）。外観は駐車場と建物だけで人が写っておらず、
    # 最初の12秒がそれ一枚だった。中の写真は満員の客席とピッチが入る。
    # 外観は「本拠地」のタイルで使うので、画面は節の途中でちゃんと変わる
    stem = facts['crest'].split('/')[-1].replace('.png', '')
    bg = f"assets/backgrounds/stadium_{stem}_in.png"
    if not (ROOT / bg).exists():
        bg = f"assets/backgrounds/stadium_{stem}.png"
    if not (ROOT / bg).exists():
        bg = None

    # 板。**「いま見る理由」も基礎DATAの画面に入れる**（2026-09-23 指示
    # 「基礎データに今見る理由もいれよう」）。柱の下に3つ並ぶ
    reason_args = [a for r in (ov.get("reasons_rows") or [])[:3]
                   if len(r) > 1 for a in ("--reason", str(r[1]))]
    # **クラブのキャッチコピーを板に入れる**（2026-09-23 指示「データにチームの
    # キャッチコピーを入れてそこを読もう」）。読み上げの1行目（`opening`）と同じ文。
    # どの板にも薄く入っていて、**1行目を読んでいるあいだだけ明るい**
    tagline = str(ov.get("opening") or "").strip().rstrip("。")
    if tagline:
        reason_args += ["--tagline", tagline]

    def data_board(rel: str, *extra: str) -> str:
        """基礎DATAの板を書き出す。**縦版（<名前>_v.png）も一緒に作る**（2026-09-23）。

        ショートは 16:9 の板を敷くと左右が切れて読めない。`shorts._drop_boards` が
        `_v` の付いた縦版を探して差し替えるので、ここで両方そろえておく
        """
        for args, out in (((), rel), (("--portrait",), rel.replace(".png", "_v.png"))):
            subprocess.run([sys.executable, str(ROOT / "tools" / "clubdata.py"), str(ROOT / out),
                            "--spec", str(DATA / f"{key}.json")] + list(extra) + reason_args + list(args),
                           check=True, capture_output=True)
        return rel

    data_board(f"assets/stats/pl_{key}_data.png")
    # 理由を読み上げている行は、柱だけを明るく残す
    reasons_board = ""
    if reason_args:
        reasons_board = data_board(f"assets/stats/pl_{key}_data_r.png", "--focus", "reasons")
    # **トロフィーの板も毎回描き直す**（2026-09-22 ユーザー指摘「ヨーロッパ合計になってる
    # クラブがいくつかある」。`trophies` を直しても、ここで描き直していなかった）
    if (DATA / f"{key}.json").exists():
        subprocess.run([sys.executable, str(ROOT / "tools" / "trophies.py"),
                        str(ROOT / f"assets/stats/pl_{key}_cups.png"),
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
    # **いま見る理由**（2026-09-22 指示「今そのクラブを見る理由を最初につけて視聴者の
    # 興味を上げたい」）。<key>_say.yaml の `reasons`（2〜3行）・`reasons_rows`（柱）。
    # **2026-09-23 指示「基礎データに今見る理由もいれよう」で、独立した節をやめて
    # 基礎DATAの頭に入れた。**板は最初の10秒から出たまま、柱の3つが明るい状態で
    # 理由を読み、そのあと1行ずつ右の一覧が明るくなる。ショートはここから始まる
    reasons = list(ov.get("reasons") or [])
    # 入口
    if japanese and not reasons:
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
    # **ショート専用の前置きも、日本人が2人なら2人とも**（2026-09-22）。題は2人なのに
    # この行だけ1人目で、パレスの鎌田大地がショートから消えていた
    # **理由も1つずつ明るくする**（2026-09-23。3つ並べたまま読むと、柱が明るい板が
    # 18.8秒つづけて出ていた＝12秒→24秒の崖にちょうど重なる）。
    # どの理由の話かは <key>_say.yaml の `reasons_focus`（1始まり・0はぜんぶ明るい）。
    # 書いていなければ行数で割り振る
    r_focus = list(ov.get("reasons_focus") or [])
    n_reasons = len([r for r in (ov.get("reasons_rows") or [])[:3] if len(r) > 1])

    r_rows = [str(r[1]) for r in (ov.get("reasons_rows") or [])[:3] if len(r) > 1]
    r_last = 1

    def reason_of(text: str) -> int:
        """その行はどの理由の話か。**読み上げ文と柱の一言を突き合わせる**（2026-09-24）。

        行数で割り振っていたら、**明るい理由と読み上げがずれた**
        （指摘「読み上げとズレてる」。アーセナルは「連覇争い」を読んでいるのに②が明るい）。
        当たらない行（「こう話しています」のような振り）は**前の行のまま**にする。
        """
        nonlocal r_last
        pairs = {text[i:i + 2] for i in range(len(text) - 1)}
        best, score = 0, 0
        for index, row in enumerate(r_rows, start=1):
            hit = len(pairs & {row[i:i + 2] for i in range(len(row) - 1)})
            if hit > score:
                best, score = index, hit
        # **2つでは当たらない行まで動く**（「22年」だけが重なって①へ戻った）
        if score >= 3:
            r_last = best
        return r_last

    def reason_board(n: int, text: str = "") -> str:
        if not reasons_board or not n_reasons:
            return img
        k = r_focus[n] if n < len(r_focus) else reason_of(text)
        if not k:
            return reasons_board
        return data_board(f"assets/stats/pl_{key}_data_r{k}.png", "--focus", f"reasons:{k}")

    say = []
    if reasons:
        for rn, r in enumerate(reasons):
            item = dict(r) if isinstance(r, dict) else {"text": r}
            item.setdefault("image", reason_board(rn, str(item.get("text") or "")))
            # 柱に同じ一言が出ているので、語りの行は字幕を重ねない。
            # **代弁の行だけは残す**（発言は板のどこにも出ていない）
            if "voice" not in item:
                item.setdefault("no_telop", True)
            say.append(item)
    else:
        say = [{"short_only": True, "text": f"{'と'.join(jp_names[:2])}の所属クラブを、基本のデータで見ていきます。" if japanese else "このクラブの、基本のデータです。"}]
    # **板を出している行に字幕は重ねない**（2026-09-20 指示
    # 「画面と字幕のが同じ場合は、字幕不要」）。基礎DATAの板の上に読み上げ文を
    # 重ねたら、9枚のタイルがほとんど読めなくなっていた
    # **1行ごとに、いま話しているタイルだけを明るく残した板に差し替える**（2026-09-20）。
    # 1枚のまま通すと48秒、画面がまったく変わらなかった（上限20秒）。
    # どのタイルの話かは `data_focus` で書ける。書いていなければ、タイルの
    # 見出しか大きな字が文に出てくるかで当てる。**当たらない行は板そのまま**
    tiles = facts["tiles"]

    def focus_of(text: str, fallback: int | None) -> int | None:
        if fallback is not None:
            return fallback
        for i, (label, big, _small) in enumerate(tiles):
            if big and big in text:
                return i
            if label and label in text:
                return i
        return None

    def board_for(i: int | None) -> str:
        if i is None:
            return img
        return data_board(f"assets/stats/pl_{key}_data{i}.png", "--focus", str(i))

    # **話している題材の画面にする**（2026-09-20 指示「各題材ごとに別画面に
    # 映るようにしたい」「スタジアムの話では、スタジアムに映る感じに」）。
    # 本拠地のタイルだけは板ではなく**スタジアムの中の写真**にする。
    # 写真は板と違って読ませる絵ではないので、**字幕は出す**
    # （板と同じ字を重ねない、という決まりに反しない）。
    # ほかの行に別の絵を当てたいときは <key>_say.yaml の `screens`（行番号→絵）
    # 下地が「中」になったので、本拠地のタイルは「外観」を出す（同じ絵にしない）
    inside = f"assets/backgrounds/stadium_{stem}.png"
    if not (ROOT / inside).exists() or inside == bg:
        inside = ""
    screens = {int(k): v for k, v in (ov.get("screens") or {}).items()}

    # **ホームタウンの話では地図を出す**（2026-09-20 指示。イングランドの地図に
    # 20クラブの紋章を置き、その回のクラブだけ大きく残す。tools/plmap.py）
    town_map = f"assets/stats/pl_{key}_map.png"
    if not (ROOT / town_map).exists():
        town_map = ""
    # **優勝回数の話ではトロフィーの板を出す**（2026-09-21 指示。見本はアーセナルの
    # トロフィーキャビネット。画像は使わず tools/trophies.py で描いている）
    cups = f"assets/stats/pl_{key}_cups.png"
    if not (ROOT / cups).exists():
        cups = ""
    # **昨季の順位の話では、昨季の最終順位表を出す**（2026-09-21 指示。見本は
    # 順位表アプリの画面。画像は使わず tools/plast.py で描いている）。
    # **20クラブで同じ表を使い、明るい行だけが違う**ので、自分の順位が
    # 他の19クラブの中のどこかとして見える
    last = f"assets/stats/pl_{key}_last.png"
    if not (ROOT / last).exists():
        last = ""
    # **昇格したクラブは昨季の表にいない**（2026-09-21。コヴェントリー・ハル・
    # イプスウィッチ）。そのまま出すと20クラブの表が出るのに**どの行も光らない**
    if last:
        table = json.loads((DATA / "last_season.json").read_text(encoding="utf-8"))["table"]
        if not any(r.get("key") == key for r in table):
            last = ""
    # **オーナーと選手の話では顔写真を出す**（2026-09-20 指示）。
    # tools/plfaces.py が Wikipedia の記事の代表画像から集めたもの。
    # **自由に使えるものが無い人は写真無し**（作らない・探し回らない）
    faces_path = DATA / "faces.json"
    faces = json.loads(faces_path.read_text(encoding="utf-8")).get(key, {}) if faces_path.exists() else {}
    owner_face = next((v["file"] for v in faces.values()
                       if v.get("role") == "owner" and v.get("file")), "")

    def picture(n: int, i: int | None) -> tuple[str, bool]:
        """(その行に出す絵, 字幕を消すか)"""
        if n in screens:
            return screens[n], False
        if i is not None and inside and str(tiles[i][0]).startswith("本拠地"):
            return inside, False
        if i is not None and town_map and str(tiles[i][0]).startswith("ホームタウン"):
            return town_map, True
        if i is not None and owner_face and str(tiles[i][0]).startswith("オーナー"):
            return owner_face, False
        if i is not None and cups and str(tiles[i][0]).startswith("タイトル歴"):
            return cups, True
        # **「タイトル歴」を読み上げないクラブがある**（2026-09-21。ブレントフォードと
        # ハルは「直近のタイトル」の行で「大きなタイトルはまだありません」と言っている）。
        # そのクラブだけ、こちらの行にトロフィーの板を当てる。両方あるクラブでは
        # 板が2行続いて12秒を超えるので、**片方の行が無いときだけ**
        if (i is not None and cups and str(tiles[i][0]).startswith("直近のタイトル")
                and not any(str(tiles[j][0]).startswith("タイトル歴")
                            for j in picks if j is not None)):
            return cups, True
        if i is not None and last and str(tiles[i][0]).startswith("プレミア最高位"):
            return last, True
        return board_for(i), True

    # **ショートでは、どの行でも基礎DATAの縦版が出るようにする**（2026-09-23）。
    # 地図・トロフィー・昨季の順位表も 16:9 なので、縦では読めない。
    # `shorts._drop_boards` は `<名前>_v.png` を探すので、**その名前で
    # 縦版の板（その行を明るくしたもの）**を置いておく。中身は違ってよい——
    # ショートで見せたいのは「いまどのデータの話か」だから
    _picture = picture

    def picture(n: int, i: int | None) -> tuple[str, bool]:  # noqa: F811
        shot, mute = _picture(n, i)
        if i is not None and shot.endswith(".png") and not shot.startswith(f"assets/stats/pl_{key}_data"):
            # 置き場は **assets/stats**（下地の置き場に縦版を置くと、
            # `_add_face` が「写真」と見て冒頭から敷いてしまう）
            twin = f"assets/stats/{Path(shot).stem}_v.png"
            subprocess.run([sys.executable, str(ROOT / "tools" / "clubdata.py"), str(ROOT / twin),
                            "--spec", str(DATA / f"{key}.json"), "--focus", str(i), "--portrait"]
                           + reason_args, check=True, capture_output=True)
        return shot, mute

    picks = list(ov.get("data_focus") or [])
    # **ホームタウンの行が無いクラブが多い**（2026-09-20）。手で書いた読み上げは
    # 本拠地とまとめてしまっていて、20クラブのうち17クラブに「ホームタウンは〜」の
    # 行が無かった。**地図を出す行がそもそも無い。**タイルから1行作って足す
    town_i = next((i for i, x in enumerate(tiles) if str(x[0]).startswith("ホームタウン")), None)
    if ov.get("data") and town_i is not None and town_i not in picks:
        label, big, small = tiles[town_i]
        line = f"ホームタウンは{big}。" + (f"{small.rstrip('。')}です。" if small else "")
        at = min(2, len(ov["data"]))
        ov = dict(ov, data=list(ov["data"][:at]) + [line] + list(ov["data"][at:]))
        picks = picks[:at] + [town_i] + picks[at:]
    # **昨季の順位表を必ず出す**（2026-09-21）。「プレミア最高位」のタイルを
    # 読み上げに入れていないクラブが多く、せっかく作った順位表の板が出ないままだった。
    # ホームタウンの地図と同じ直し方で、1行つくって足す
    last_i = next((i for i, x in enumerate(tiles) if str(x[0]).startswith("プレミア最高位")), None)
    if ov.get("data") and last and last_i is not None and last_i not in picks:
        table = json.loads((DATA / "last_season.json").read_text(encoding="utf-8"))["table"]
        me = next((r for r in table if r.get("key") == key), None)
        if me:
            ov = dict(ov, data=list(ov["data"]) + [f"昨季は**{me['rank']}位**。勝ち点は{me['points']}でした。"])
            picks = picks + [last_i]

    if ov.get("data"):
        for n, text in enumerate(ov["data"]):
            i = focus_of(text, picks[n] if n < len(picks) else None)
            if i is None:
                print(f"  ！ {key} の基礎DATA {n + 1}行目は、どのタイルか当てられませんでした", file=sys.stderr)
            shot, mute = picture(n, i)
            say.append({"image": shot, "text": text, "no_telop": True} if mute
                       else {"image": shot, "text": text})
    else:
        n = 0
        for i, (label, big, small) in enumerate(tiles):
            if label.startswith("有名なファン"):
                continue
            text = f"{label}は、**{big}**。" + (f"{small.rstrip('。')}。" if small else "")
            shot, mute = picture(n, i)
            say.append({"image": shot, "text": text, "no_telop": True} if mute
                       else {"image": shot, "text": text})
            n += 1
    sections.append(sec(id="data", heading="いま見る理由と基礎DATA" if reasons else f"{club} 基礎DATA",
                        main=True, tier="背景",
                        telop=(str(ov.get("reasons_telop") or "いま、このクラブを見る理由") if reasons
                               else facts["tiles"][0][1] + "創立"),
                        narrator="キャスター" if reasons else "解説", say=say,
                        sources=[wiki] + ([season_url] + [u for u in (ov.get("reasons_sources") or [])
                                                          if u not in (wiki, season_url)] if reasons else [])))
    # **有名なファンの節は作らない**（2026-09-20 指示「有名なファンは廃止」）。
    # <key>.json の `fans` / `fan_story` は残っているが、台本では一切使わない。
    # 板の9枚目も「有名なファン」ではなく「愛称」にしてある（research/pl_data/<key>.json）。
    # そのクラブの話・宿敵は旧台本から
    story_sec = next((s for s in old["sections"] if s["id"] == ov.get("story")), None) or next((s for s in old["sections"] if s.get("main")), None) or next(
        (s for s in old["sections"] if s["id"] not in ("name", "ground", "season", "rival", "legends", "titles")), None)
    # 割り方を手で書いた回は、そちらを使う。1枚のカードを20秒以上出しっぱなしに
    # しないため（機械に割らせると、話していない行が画面に先に出る）
    if ov.get("story_sections"):
        for s in ov["story_sections"]:
            # **手で割った節の表も、長ければさらに割る**（2026-09-24）。
            # ハルの逸話は story_sections の中にあり、ここだけ割られずに25.8秒あった
            sections.append(split_card(sec(**s)))
    elif story_sec:
        story_sec = {k: v for k, v in story_sec.items() if k != "main"}
        if bg:
            story_sec["bg"] = bg
        sections.append(split_card(story_sec))
    # **このクラブの特徴**（2026-09-23 指示「チームの特徴とかも加えられる？」→「三つの要素入れたい！」）。
    # プレーの色（監督のサッカーを一言。陣形の数字は言わない。9/16「戦術の節は入れない」はそのまま）・
    # 運営の型・クラブの気質の3行。<key>_say.yaml の `features`／`features_rows`／`features_telop`／
    # `features_sources`。基礎DATAの直後、クラブの話の前。ショートには入れない
    if ov.get("features"):
        f_say = list(ov["features"])
        # 1行目（プレーの色＝監督の話）に監督の顔を置く。写真のある行が先にあれば、
        # research が3行目でカードを下ろして顔だけにする（名選手の節と同じ仕掛け）。
        # 置かないと表が22秒出っぱなしになった（review「カードの持ち」）
        f_face = next((v.get("file", "") for v in faces.values()
                       if isinstance(v, dict) and v.get("role") == "manager"), "")
        if f_face:
            f_say[0] = {"text": f_say[0], "image": f_face}
        sections.append(sec(id="features", heading="このクラブの特徴", tier="背景",
                            telop=str(ov.get("features_telop") or "このクラブの特徴"),
                            narrator="解説",
                            card={"type": "table", "title": "このクラブの特徴", "columns": ["", ""],
                                  "rows": ov.get("features_rows") or []},
                            say=f_say,
                            sources=[wiki] + [u for u in (ov.get("features_sources") or []) if u != wiki],
                            **({"bg": bg} if bg else {})))
    # **「へえ」の逸話を1つ**（2026-09-22 ユーザー指示「1.2を実施」）。Gemini の点検で
    # 「データの読み上げで、覚えて帰る逸話が無い」と言われた。<key>_say.yaml の `episode`。
    # 原文は Wikipedia のクラブ記事で裏を取ったものだけ
    if ov.get("episode"):
        ep = dict(ov["episode"])
        ep.setdefault("id", "episode")
        ep.setdefault("tier", "背景")
        ep.setdefault("narrator", "解説")
        if bg:
            ep["bg"] = bg
        sections.append(split_card(sec(**ep)))
    # 名選手（1990年以降）
    leg = next((c for c in legends_all if c["club"].replace("・", "").replace("AFC", "") in club.replace("・", "") or club.replace("・", "") in c["club"].replace("・", "")), None)
    if leg:
        rows = ov.get("legend_rows") or [[l["name"], l["era"], l["why"][:24]] for l in leg["legends"]]
        # **3列目は12字まで**（2026-09-23 指摘「表をもう少し大きく」）。写真の横に置く
        # カードは幅900pxしかなく、24字だと字が22pxまで縮んで「…」で切れていた。
        # 中身は読み上げとテロップで言っているので、表は見出しの役でよい
        rows = [[str(r[0]), str(r[1]), str(r[2])[:12]] if len(r) > 2 else list(r) for r in rows]
        lsay = ov.get("legends") or [f"{l['name']}。{l['numbers'].split('。')[0]}。" for l in leg["legends"]]
        # **1人ずつ節を分け、カードは名前が出たぶんだけ増やす**（2026-09-20）。
        # 3人を1枚のカードでまとめると**22秒**、同じ絵のまま出っぱなしになった（上限20秒）。
        # 増やす形なら、**まだ話していない選手が先に画面に出ることがない**
        srcs = [l["source"] for l in leg["legends"]]
        # **1人に何行でも書ける**（2026-09-22 指示「このクラブの3人の内容をもう少し濃くしたい」）。
        # <key>_say.yaml の `legends` の要素が list なら、その行を全部その選手の節に置く。
        # 顔写真は1行目に付け、あとの行にも残る（hold_photo）。
        # 出典は `legend_sources`（選手ごとの URL の list）があれば足す
        extra_srcs = ov.get("legend_sources") or []
        for i, line in enumerate(lsay):
            # **その選手の顔を出す**（2026-09-20 指示「選手の話の時には写真をだす」）。
            # 名前は legend_rows の1列目（読み上げの文とは限らない）で引く
            who = str(rows[i][0]) if i < len(rows) else ""
            face = (faces.get(who) or {}).get("file", "")
            texts = list(line) if isinstance(line, list) else [line]
            say_lines = [{"text": texts[0], "image": face} if face else texts[0]] + texts[1:]
            more = list(extra_srcs[i]) if i < len(extra_srcs) and extra_srcs[i] else []
            body = {"id": "legends" if i == 0 else f"legends{i + 1}",
                    "heading": "このクラブを語る3人" if i == 0 else f"このクラブを語る3人（{i + 1}人目）",
                    "tier": "背景", "telop": "1990年以降の名選手", "narrator": "キャスター",
                    "card": {"type": "table", "title": "1990年以降の名選手",
                             "columns": ["名前", "在籍", "残したもの"], "rows": rows[:i + 1]},
                    "say": say_lines,
                    "sources": srcs + [u for u in more if u not in srcs]}
            sections.append(sec(**body))
    # **宿敵の節は作らない**（2026-09-20 指示「宿敵は不要」）。
    # 旧台本には残っているが、20本すべてで落とす。
    # <key>_say.yaml の `rival_sections` も使わない（戻すときのために残してある）。
    # **今季の監督**（2026-09-22 指示「今季の監督が誰かも加えよう」「選手と監督の紹介は順番逆」→ 登録選手の前）。
    # <key>_say.yaml の `manager`（読み上げの行）・`manager_rows`（板）・`manager_sources`。
    # 顔は faces.json の role "manager"（tools/plmanagers.py が集める）
    if ov.get("manager"):
        m_face = next((v.get("file", "") for v in faces.values()
                       if isinstance(v, dict) and v.get("role") == "manager"), "")
        m_lines = list(ov["manager"])
        m_say = [{"text": m_lines[0], "image": m_face} if m_face else m_lines[0]] + m_lines[1:]
        sections.append(sec(id="manager", heading="今季の監督", tier="報道",
                            telop=str(ov.get("manager_telop") or "今季の監督"),
                            narrator="キャスター",
                            card={"type": "table", "title": "今季の監督", "columns": ["", ""],
                                  "rows": ov.get("manager_rows") or []},
                            say=m_say,
                            sources=[wiki] + [u for u in (ov.get("manager_sources") or []) if u != wiki]))
    # 登録選手（2026-09-20 指示「選手紹介をもう少し内容増やしてほしい／
    # 各ポジの有名選手、キャプテンを紹介」）。
    # **「有名」は代表の出場数で決める。**好き嫌いで選ばない。
    # 各選手の Wikipedia にある A代表の出場数（plsquad.py が控えている）の
    # 上から2人までを、その位置の板といっしょに読む
    total = sum(1 for p in raw["squad"] if age(p["dob"]) is not None)
    cap = next((p for p in raw["squad"] if p.get("captain")), None)
    # **主将は、その人の位置の板といっしょに出す**（2026-09-20）。
    # 節の頭で名前だけ言うと、画面は前の節の写真（名選手の顔）が残ったままで、
    # **別人の顔を見せながら主将の名前を読む**ことになっていた。
    # 頭の行にも板を当てて、前の節の写真が流れ込まないようにする
    first_board = squad_boards[0]["out"] if squad_boards else ""
    ssay = [{"text": f"今季の登録選手は{total}人です。", "image": first_board, "no_telop": True}
            if first_board else f"今季の登録選手は{total}人です。"]
    seen = set()
    for board in squad_boards:
        out, label, n = board["out"], board["label"], board["count"]
        if label in seen:
            ssay.append({"image": out, "text": f"{label}の続きです。", "no_telop": True})
            continue
        seen.add(label)
        here = [p for p in raw["squad"]
                if dict(POS).get(p["pos"]) == label and age(p["dob"]) is not None]
        names = [kana.get(p["name"], p["name"]) for p in here]
        jp = [n2 for n2 in names if n2 in jp_names]
        tail = f"日本の{jp[0]}がいます。" if jp else ""
        if cap and dict(POS).get(cap["pos"]) == label:
            cap_name = kana.get(cap["name"], cap["name"])
            more = f"リーグ戦で**{cap['club_caps']}試合**に出ています。" if (cap.get("club_caps") or 0) >= 50 else ""
            tail += f"主将を務めるのが**{cap_name}**。{more}"
        # **1枚の板は12秒まで**（検査の上限）。主将の話を足す位置は、
        # 有名な選手を1人に減らして収める
        room = 1 if tail else 2

        def worth(p):
            """代表歴だけでなく、クラブでの積み上げも見て選ぶ（2026-09-21 指示）。"""
            return (p.get("club_caps") or 0) + (p.get("caps") or 0) * 3

        def about(p):
            """その選手について言えることを、1〜2個だけ。"""
            # **手で書いた一文があれば、それを使う**（2026-09-21）。移籍金のように
            # Wikipedia の infobox からは取れないが、**視聴者がいちばん反応する数字**を
            # 入れるための口。<key>_say.yaml の `squad_about`（選手名→文）
            said = (ov.get("squad_about") or {}).get(kana.get(p["name"], p["name"]))
            if said:
                return said
            bits = []
            if (p.get("caps") or 0) >= CAPS_MIN and p.get("team"):
                bits.append(f"{TEAM_JA.get(p['team'], p['team'])}代表で**{p['caps']}試合**")
            if (p.get("club_caps") or 0) >= 80:
                bits.append(f"リーグ戦で**{p['club_caps']}試合**")
            if (p.get("club_goals") or 0) >= 15:
                # **「16得点」だけでは何の得点か分からない**（2026-09-21）。
                # 他の選手が「◯◯代表で◯試合」なので、耳では通算とも今季とも取れる
                bits.append(f"リーグ戦で**{p['club_goals']}得点**")
            if not bits and (p.get("club_caps") or 0) >= 30:
                bits.append(f"リーグ戦で**{p['club_caps']}試合**")
            if not bits:
                return ""
            return f"{kana.get(p['name'], p['name'])}は" + bits[0] + "。"

        known = [x for x in sorted(here, key=lambda p: -worth(p))
                 if about(x) and not (cap and x["name"] == cap["name"])][:room]
        note = "".join(about(p) for p in known)
        extra = (ov.get("squad") or {}).get(label, "")
        # **読み上げで名前を出す人だけ、板の行を明るくする**
        lit = ([jp[0]] if jp else []) + ([cap_name] if cap and dict(POS).get(cap["pos"]) == label else [])
        lit += [kana.get(p["name"], p["name"]) for p in known]
        # **1文ずつ別の行にする**（2026-09-22）。「ディフェンダーは10人。主将は…。◯◯は代表で…」を
        # 1行で読むと50〜80字になり、合成音声で一息に聞き取れない（読み手の指摘）。
        # 板は同じものを各行に付ける（板の明るい行は変えない）
        whole = f"{label}は{n}人。{tail}{note}{extra}"
        shot = lit_board(board, lit)
        for piece in [s + "。" for s in whole.split("。") if s.strip()]:
            ssay.append({"image": shot, "text": piece, "no_telop": True})
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
        # **いまの順位を必ず載せる**（2026-09-21 指示「今季は、今の順位を載せる」）。
        # 順位表は research/pl_data/standings.json に控えてある
        stand = json.loads((DATA / "standings.json").read_text(encoding="utf-8"))["table"].get(key)
        say_season = [f"プレミアリーグは{len(games)}試合を終えて、**{record}**です。"]
        if stand:
            rows = [["順位", f"**{stand['rank']}位** / 20クラブ"],
                    ["勝ち点", f"{stand['points']}"],
                    ["成績", stand["record"]]] and rows
            say_season.append(f"順位は**{stand['rank']}位**、勝ち点は**{stand['points']}**です。")
            if stand["rank"] >= 18:
                say_season.append("いまは降格圏にいます。")
            elif stand["rank"] <= 4:
                say_season.append("この順位を保てば、来季のチャンピオンズリーグに出られます。")
        sections.append(sec(id="season", heading="今季のここまで", tier="報道",
                            telop=f"{len(games)}試合で{record}。{stand['rank']}位" if stand else f"{len(games)}試合で{record}",
                            narrator="解説",
                            card={"type": "table", "title": "プレミアリーグの結果", "columns": ["節", "相手", "結果"], "rows": rows},
                            # `season_image`（<key>_say.yaml）: 今季の節の1行目に置く写真。
                            # 結果の表が6行で22秒出っぱなしになった回（アーセナル）だけ、
                            # 写真を先に置いて3行目で表を下ろす（名選手の節と同じ仕掛け）
                            say=([{"text": say_season[0], "image": str(ov["season_image"])}] + say_season[1:]
                                 if ov.get("season_image") and say_season else say_season) + (ov.get("season") or []),
                            sources=[season_url]))

    # **日本人が2人いるクラブは2人とも題に出す**（2026-09-21）。
    # 1人目だけだと、パレスが「冨安健洋がいる」になって鎌田大地が消えていた
    title_head = (f"{'と'.join(jp_names[:2])}がいる{club}" if japanese else club)
    # キャッチコピーを明るくした板（＝最初の画面）
    opening_board = ""
    if tagline:
        opening_board = data_board(f"assets/stats/pl_{key}_data_t.png", "--focus", "tagline")

    note = {
        "format": "news", "voice_min": 0, "slot": "premier_1", "date": "2026年9月19日",
        # `people_extra`: 本人の言葉を読ませる人（監督・名選手）。声の割り当てと、言葉の早さの点検に使う
        "people": jp_names + [club] + [str(x) for x in (ov.get("people_extra") or [])],
        # **題は手で書く**（2026-09-22 指示「タイトルをもっと視聴者が見たいと思うものに」）。
        # <key>_say.yaml の `title`／`short_title`。無ければ「◯◯ってどんなクラブ？」
        "short_title": str(ov.get("short_title") or ov.get("title") or f"{title_head}ってどんなクラブ？")[:40],
        # **公開する題の後ろにシリーズ名**（2026-09-23 指示「サブタイトルにプレミアリーグチーム紹介として」）。
        # 「題｜プレミアリーグチーム紹介」。読み上げには入らない（subtitles.write_outputs）
        "series": "プレミアリーグチーム紹介",
        "theme": {"id": old["theme"]["id"], "league": "england", "league_name": "プレミアリーグ", "kind": "other",
                  # **シリーズの名札は付けない**（2026-09-21 指示「②プレミア20クラブ紹介はいらない」）。
                  # 検索で来る言葉はクラブ名で、連番はタイトルの尺を食うだけだった
                  "topic": club, "title": str(ov.get("title") or f"{title_head}ってどんなクラブ？"),
                  "question": "どんなクラブなのか",
                  # **宿敵の節を落としたら、宿敵を約束する引きが残った**（2026-09-20）。
                  # 「宿敵は、同じ街の赤いクラブです」と言って、その話を一度もしない。
                  # 中身に残っている話へ書き換える（<key>_say.yaml の `hook`）
                  "hook": ov.get("hook") or old["theme"].get("hook", ""),
                  # **クラブを表す一言**（2026-09-21 指示）。タイトルより前に読む
                  "lead": ov.get("opening", ""),
                  # **最初の画面は基礎DATAの板**（2026-09-23 指摘「最初の画面が
                  # データではない」）。キャッチコピーを明るくした板を当てる。
                  # **「この動画で分かること」は置かない**（同じ日の指摘
                  # 「データでわかるから不要」）。板に9項目と理由3つが出ているので、
                  # 流れの一覧は同じことの二度出しだった
                  "opening_image": opening_board},
        # **サムネの文字は台本に合わせて書き直す**（2026-09-20）。旧台本のものを
        # そのまま持ってくると、ボーンマスが「FAカップで1人9得点」のままになった。
        # **作り直した台本にその話は無い。**約束したことを中で答えられない
        # **サムネの背景は基礎DATAの板**（2026-09-24 指示「もっと、背景は、データを利用」）。
        # 動画の1コマ目と同じ絵になるので、開いた人が「これで合っている」と分かる。
        # `crest_main` は残す（**縦のサムネ**はエンブレムの地のまま。板は 16:9 で、
        # 縦に切ると読めない）
        "thumbnail": dict(old["thumbnail"], **(ov.get("thumbnail") or {}),
                          **({"board": opening_board} if opening_board else {})),
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
