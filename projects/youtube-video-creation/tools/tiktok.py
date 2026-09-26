"""TikTok に手で上げるための一式を、1日ぶんまとめて作る（2026-09-16）。

**自動では投稿しない。**TikTok の投稿APIのガイドラインに
「自分やチームが管理するアカウントへ上げるための道具」は不可と明記されている
（Not acceptable: A utility tool to help upload contents to the account(s)
you or your team manages）。審査前は非公開でしか上げられず、1本ごとに
人の操作と同意も要る。**だから作るのは「上げる準備」まで**で、投稿そのものは
ユーザーが TikTok Studio（Web）で行い、時刻を予約する（2026-09-16 決定）。

    python tools/tiktok.py 20260916          # その日のショートを全部
    python tools/tiktok.py output/20260916_mitoma_short ...   # 個別に

できるもの（`output/tiktok/<日付>/`）:

    01_mitoma.mp4        そのまま上げる動画（ショートの書き出しをコピー）
    01_mitoma.txt        説明欄に貼る文（題名・ハッシュタグ・クレジット）
    一覧.txt             上げる順番と、各ファイルの名前

**動画を見せていないショートは入れない。**YouTube と同じ関門
（`research/screened.json`）を通す。見せたあとに書き出し直したものも外す。

**クレジットは必ず残す。**CC BY の写真は表示しないと利用条件を満たさず、
VOICEVOX もキャラクターごとに表記が要る。YouTube の概要欄と同じ内容を
TikTok の説明欄にも入れる。
"""
from __future__ import annotations

import argparse
import io
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, ".")

from src import screening  # noqa: E402

OUT = Path("output/tiktok")
# 説明欄の長さ。TikTok の上限は変わってきたので、**低いほうの2,200字**で見る
CAPTION_MAX = 2200
# TikTok はハッシュタグを並べすぎると読みにくい。YouTube と同じ3つに
# 「海外サッカー」を足した4つまで
HASHTAG_MAX = 4

# **YouTube への行き方は、説明欄のいちばん上に置く**（2026-09-16 指示
# 「tiktokの説明画面にもyoutubeへのパスを載っけたい」）。
# それまでは出典やクレジットと一緒に**いちばん下**にあり、しかも
# `@kaigai-soccer-riyuu` とだけ書いていた。**TikTok で @ から始まる文字列は
# TikTok の利用者のことなので、YouTube のチャンネル名だと読めない。**
#
# 3行に分けてあるのは、**押せるリンクが作れない**ため。TikTok の説明欄の
# URL はただの文字で、押しても飛ばない。だから「探し方」を書く:
#   ・チャンネル名（検索窓に入れる言葉）
#   ・URL（打ち込む人のため）
# 動画の最後の読み上げ（`shorts.TIKTOK_OUTRO`）と同じ言い方に揃える
YOUTUBE_LINES = [
    "▶ 続きと本編はYouTubeで",
    "　チャンネル名「海外サッカーの理由」",
    "　youtube.com/@kaigai-soccer-riyuu",
]


def targets(args: list[str]) -> list[Path]:
    dirs: list[Path] = []
    for arg in args:
        path = Path(arg)
        if path.is_dir():
            dirs.append(path)
        elif re.fullmatch(r"\d{8}[a-z]?", arg):
            # **1分を超える TikTok 用があれば、そちらを使う**（2026-09-16）。
            # ショート（58秒まで）は報酬の対象にならない
            for short in sorted(Path("output").glob(f"{arg}_*_short")):
                longer = short.with_name(short.name.removesuffix("_short") + "_tiktok")
                dirs.append(longer if (longer / "video.mp4").exists() else short)
    dirs = [d for d in dirs if (d / "video.mp4").exists()]
    # **YouTube に予約した順に並べる。**台帳には予約した順で控えが残っている。
    # 名前の順だと、8時に出るイラオラより12時のキャラガーが先頭に来ていた
    from src import posted
    order = {row.get("build"): i for i, row in enumerate(posted._load(posted.LEDGER))}
    def rank(d: Path) -> int:
        base = d.name.removesuffix("_tiktok").removesuffix("_short") + "_short"
        return order.get(base, len(order))
    return sorted(dirs, key=rank)


def sections(text: str) -> tuple[str, dict[str, list[str]], list[str], list[str]]:
    """description.txt を 題名・■の節・ハッシュタグ・畳んだ注記 に割る。"""
    title, _, body = text.partition("\n")
    body, _, folded = body.partition("─" * 12)
    parts: dict[str, list[str]] = {"": []}
    current = ""
    tags: list[str] = []
    for line in body.splitlines():
        line = line.rstrip()
        if line.startswith("■ "):
            current = line[2:].strip()
            parts[current] = []
        elif line.startswith("#"):
            tags += line.split()
        elif line:
            parts.setdefault(current, []).append(line)
    notes = [x for x in folded.splitlines() if x.strip()]
    return title.strip(), parts, tags, notes


def caption(build_dir: Path) -> str:
    title, parts, tags, notes = sections(
        io.open(build_dir / "description.txt", encoding="utf-8").read())
    lead = [x for x in parts.get("", []) if x.strip() and x.strip() != title
            and not x.startswith("※")]
    hashtags = []
    for tag in tags + ["#海外サッカー"]:
        if tag not in hashtags:
            hashtags.append(tag)
    # **出典は媒体名だけ。**TikTok の説明欄ではリンクが押せず、長いURLは邪魔になる
    outlets = []
    for url in parts.get("出典", []):
        host = re.sub(r"^https?://(www\.)?", "", url).split("/")[0]
        if host and host not in outlets:
            outlets.append(host)

    out = [title]
    if lead:
        out += ["", lead[0]]
    # **ハッシュタグより先に置く。**TikTok の説明欄はハッシュタグから下が
    # 折りたたまれるので、下に置くと開いた人にしか見えない
    out += [""] + YOUTUBE_LINES
    out += ["", " ".join(hashtags[:HASHTAG_MAX])]
    tail: list[str] = []
    if outlets:
        tail.append("出典: " + " / ".join(outlets))
    tail += parts.get("クレジット", [])
    tail += notes
    if tail:
        out += [""] + tail
    return "\n".join(out).strip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("what", nargs="+", help="日付（20260916）か、ショートの出力先")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    dirs = targets(args.what)
    if not dirs:
        print("ショートの書き出しが見つかりません", file=sys.stderr)
        return 1
    day = re.match(r"\d{8}", dirs[0].name)
    out = Path(args.out) if args.out else OUT / (day.group(0) if day else "misc")
    out.mkdir(parents=True, exist_ok=True)

    listed, skipped = [], []
    for index, build in enumerate(dirs, 1):
        if not screening.is_screened(build) or screening.changed_since_screening(build):
            skipped.append(build.name)
            continue
        name = re.sub(r"^\d{8}[a-z]?_", "", build.name).removesuffix("_short").removesuffix("_tiktok")
        stem = f"{len(listed) + 1:02d}_{name}"
        shutil.copyfile(build / "video.mp4", out / f"{stem}.mp4")
        text = caption(build)
        (out / f"{stem}.txt").write_text(text, encoding="utf-8")
        listed.append((stem, len(text), build.name.endswith("_tiktok")))

    lines = [f"TikTok に上げる一式（{len(listed)}本）", "",
             "TikTok Studio で動画を選び、同じ名前の .txt を説明欄に貼って、時刻を予約する。", ""]
    for stem, length, long_cut in listed:
        warn = f"　※説明欄が{length}字（{CAPTION_MAX}字を超えています）" if length > CAPTION_MAX else ""
        kind = "" if long_cut else "　※1分未満（報酬の対象外）"
        lines.append(f"  {stem}.mp4　／　{stem}.txt{kind}{warn}")
    (out / "一覧.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"作りました: {out}")
    for stem, length, long_cut in listed:
        print(f"  {stem}　説明欄 {length}字　{'1分超' if long_cut else 'ショート（1分未満）'}")
    # **入れなかったものを最後の行に残す**（upload と同じ理由）
    for name in skipped:
        print(f"  × {name}: 動画をまだ見せていない（または見せたあとに書き出し直した）")
    print(f"\n■ 入れた {len(listed)}本 / 入れなかった {len(skipped)}本", flush=True)
    return 0 if listed else 1


if __name__ == "__main__":
    raise SystemExit(main())
