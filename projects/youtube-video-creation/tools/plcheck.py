"""プレミア20クラブ紹介を、**過去の指摘事項に照らして**点検する（2026-09-24）。

ユーザー指示「作ったら、私の指摘事項に違反してないか確認してね。参考は、ボーンマス」。
①ボーンマスは1本ずつ見せて直した回なので、**あれが基準**。残りの19本が同じ形に
なっているかを機械で見る。CLAUDE.md の「見せる前の決まり」の表のうち、
**この企画に効くもの**をここに集めてある。

    python tools/plcheck.py                 # 20クラブ全部
    python tools/plcheck.py --club arsenal  # 1クラブだけ
    python tools/plcheck.py --review        # 動画の点検（review）も回す（1本1分）

出るのは ○ と ■ の一覧。**× が1つでもあれば終了コード1**。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# 番号とキー。①は基準（ボーンマス）
CLUBS = [
    (1, "bournemouth"), (2, "arsenal"), (3, "villa"), (4, "brentford"), (5, "brighton"),
    (6, "chelsea"), (7, "coventry"), (8, "palace"), (9, "everton"), (10, "fulham"),
    (11, "hull"), (12, "ipswich"), (13, "leeds"), (14, "liverpool"), (15, "mancity"),
    (16, "manutd"), (17, "newcastle"), (18, "forest"), (19, "sunderland"), (20, "tottenham"),
]

# ショートの尺。上限58秒（`shorts.MAX_SECONDS`）、下限は「短くなりすぎない」ための目安
SHORT_MIN = 46.0
SHORT_MAX = 59.0
# 本編の尺。この企画だけ1本4分15秒〜5分（2026-09-22 ユーザー）
MAIN_MIN = 3 * 60.0
MAIN_MAX = 5 * 60 + 30.0
# 同じ絵が止まっていてよい秒数（review の「見た目の変化」と同じ）
HOLD_MAX = 20.5
# 名選手の表の3列目（2026-09-23「表をもう少し大きく」）
LEGEND_CELL = 12


def _lines(script_json: dict) -> list[dict]:
    return [line for scene in script_json.get("scenes", []) for line in scene.get("lines", [])]


def check(number: int, key: str, with_review: bool) -> list[str]:
    """× の一覧を返す。空なら通っている。"""
    stem = f"20260920_pl{number:02d}_{key}"
    bad: list[str] = []
    note_path = ROOT / "research" / f"{stem}.yaml"
    script_path = ROOT / "scripts" / f"{stem}.md"
    if not note_path.exists() or not script_path.exists():
        return [f"台本か取材メモがありません（{stem}）"]
    note = yaml.safe_load(note_path.read_text(encoding="utf-8"))
    theme = note.get("theme") or {}
    sections = note.get("sections") or []
    script = script_path.read_text(encoding="utf-8")

    # --- 2026-09-23 に決めた形（ボーンマスが基準）---
    if not str(note.get("series") or "").strip():
        bad.append("公開する題にシリーズ名が付きません（series）")
    opening_image = str(theme.get("opening_image") or "")
    if not opening_image.endswith("_data_t.png"):
        bad.append("最初の画面が基礎DATAの板ではありません（opening_image）")
    elif not (ROOT / opening_image).exists():
        bad.append(f"最初の画面の板がありません（{opening_image}）")
    if theme.get("opening_card"):
        bad.append("「この動画で分かること」が残っています（データで分かるので不要）")
    if not str(theme.get("lead") or "").strip():
        bad.append("クラブのキャッチコピーがありません（theme.lead）")
    if any(str(s.get("id")) == "reasons" for s in sections):
        bad.append("「いま見る理由」が別の節のままです（基礎DATAに入れる）")
    data = next((s for s in sections if str(s.get("id")) == "data"), None)
    if data is None:
        bad.append("基礎DATAの節がありません")
    else:
        if not data.get("main"):
            bad.append("基礎DATAの節が山場（main）になっていません")
        images = [str(x.get("image") or "") for x in data.get("say") or [] if isinstance(x, dict)]
        reason_boards = [x for x in images if "_data_r" in x]
        if not reason_boards:
            bad.append("いま見る理由が柱に出ていません（_data_r の板が無い）")
        elif len(set(reason_boards)) < 2:
            bad.append("理由を1つずつ明るくしていません（同じ板が続く）")

    # --- オープニングの3行すべてに板（2026-09-23「変な画面が挟まる」）---
    opening = script.split("## ")[1] if "## " in script else ""
    says = [ln for ln in opening.splitlines() if re.match(r"^[^ \-#@].*[:：]", ln)]
    shown = opening.count(f"image: {opening_image}") if opening_image else 0
    if opening_image and shown < len(says):
        bad.append(f"オープニングで板が抜けている行があります（{shown}/{len(says)}行）")

    # --- 名選手の表は12字まで（2026-09-23「表をもう少し大きく」）---
    for section in sections:
        card = section.get("card") or {}
        for row in (card.get("rows") or []):
            if len(row) > 2 and len(str(row[2])) > LEGEND_CELL:
                bad.append(f"表の3列目が長すぎます（{section.get('id')}: {row[2]}）")
                break

    # --- 読み上げにアルファベットを残さない（2026-09-21）---
    # 見るのは**読み上げる行だけ**（front matter とテロップ・絵の指定は見ない）
    body_text = script.split("\n---\n", 2)[-1]
    for line in body_text.splitlines():
        head, sep, said = line.partition(":")
        if not sep or line.startswith((" ", "@", "#")) or re.search(r"[A-Za-z]", head):
            continue
        found = re.findall(r"[A-Za-z]{3,}", said)
        if found:
            bad.append(f"読み上げにアルファベットが残っています（{found[0]}）")
            break

    # --- 出来上がり ---
    out = ROOT / "output" / stem
    short_out = ROOT / "output" / f"{stem}_short"
    if not (out / "video.mp4").exists():
        bad.append("本編ができていません")
    if not (short_out / "video.mp4").exists():
        bad.append("ショートができていません")
    if not (out / "thumbnail.png").exists():
        bad.append("サムネイルがありません")
    if not (short_out / "crest_bg.png").exists():
        bad.append("ショートの下地がエンブレムになっていません")

    for path, low, high, name in ((out, MAIN_MIN, MAIN_MAX, "本編"),
                                  (short_out, SHORT_MIN, SHORT_MAX, "ショート")):
        data_json = path / "script.json"
        if not data_json.exists():
            continue
        body = json.loads(data_json.read_text(encoding="utf-8"))
        lines = _lines(body)
        total = sum(float(x.get("duration") or 0) for x in lines)
        if not low <= total <= high:
            bad.append(f"{name}の尺が {total:.0f}秒 です（目安 {low:.0f}〜{high:.0f}秒）")
        # 同じ絵・同じ字のまま止まっていないか
        run, prev = 0.0, None
        for x in lines:
            span = float(x.get("duration") or 0)
            now = (str(x.get("image")), str(x.get("telop")))
            run = run + span if now == prev else span
            prev = now
            if run > HOLD_MAX:
                bad.append(f"{name}で画面が {run:.0f}秒 止まります")
                break
        # ショートは板を縦版に差し替えているか（16:9 の板のままなら左右が切れる）
        if name == "ショート":
            for x in lines:
                image = str(x.get("image") or "")
                if image and "assets/stats/" in image and not image.endswith("_v.png"):
                    bad.append(f"ショートに横版の板が出ています（{Path(image).name}）")
                    break

    if with_review:
        done = subprocess.run([sys.executable, "-m", "src.cli", "review", f"scripts/{stem}.md"],
                              cwd=ROOT, capture_output=True, encoding="utf-8", errors="replace")
        for row in (done.stdout or "").splitlines():
            if "×" not in row:
                continue
            # この2つは企画として外している（1行目はキャッチコピー／尺は4〜5分）
            if "1行目" in row or "尺" in row:
                continue
            bad.append("review: " + row.strip().lstrip("× ").strip())
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--club", help="このクラブだけ")
    ap.add_argument("--review", action="store_true", help="動画の点検（review）も回す")
    args = ap.parse_args()

    clubs = [(n, k) for n, k in CLUBS if not args.club or k == args.club]
    ng = 0
    for number, key in clubs:
        bad = check(number, key, args.review)
        head = f"{number:02d} {key}"
        if bad:
            ng += 1
            print(f"■ {head}")
            for row in bad:
                print(f"     - {row}")
        else:
            print(f"○ {head}")
    print(f"\n通った {len(clubs) - ng} / {len(clubs)}")
    return 1 if ng else 0


if __name__ == "__main__":
    raise SystemExit(main())
