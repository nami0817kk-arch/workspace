"""コマンドラインから台本→動画を作る。

    python -m src.cli init-assets              仮の背景・立ち絵を生成
    python -m src.cli speakers                 VOICEVOX の話者/スタイルID一覧
    python -m src.cli build <台本> --backend core   合成方式を明示する
    python -m src.cli make-clip <画像>         静止画から背景クリップを作る
    python -m src.cli gather                   フィードと貼り付けを一息で候補に
    python -m src.cli scan                     候補テーマを拾う検索リスト
    python -m src.cli fetch | ... collect      RSSから最新見出し（運用PCで）
    python -m src.cli collect < 検索結果.txt    検索結果から候補ファイルの下書き
    python -m src.cli lint research/x.yaml     候補ファイルの書き間違いを探す
    python -m src.cli saga research/x.yaml     続報かどうかと前回との差分
    python -m src.cli pick research/x.yaml     候補を採点して枠に割り振る
    python -m src.cli x                        記者Xアカウントの検索リスト
    python -m src.cli fresh <URL>...           拾ったURLの新しさを判定
    python -m src.cli today                    今日の進み具合と次の一手
    python -m src.cli stats                    これまで何を出してきたか
    python -m src.cli doctor                   収集の仕組みの健康診断
    python -m src.cli queries                  どの検索が効いているか
    python -m src.cli sources                  情報源の網と確度の上限
    python -m src.cli clubs "見出し"            クラブ名の別名辞書を引く
    python -m src.cli review scripts/x.md      公開前の点検
    python -m src.cli short scripts/x.md       縦9:16のショート
    python -m src.cli plan                     枠ごとの取材リストを出す
    python -m src.cli draft research/x.yaml    取材メモを検証して台本にする
    python -m src.cli new                      テンプレートから台本の下書きを作る
    python -m src.cli check scripts/sample.md  台本の書式と想定尺だけ確認
    python -m src.cli build scripts/sample.md  動画・字幕・サムネを書き出し
    python -m src.cli upload output/sample --dry-run   送る前に中身を見る
    python -m src.cli upload output/sample     出来上がりを YouTube に投稿
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from pathlib import Path

from .assets import ensure_assets
from .config import ConfigError, load_config
from .pipeline import build
from .plan import PlanError
from .research import ResearchError
from .script_model import ScriptError, load_script
from .thumbnail import build_thumbnail
from .tts import TtsError


def _use_utf8(*streams) -> None:
    """出力を UTF-8 にそろえる。

    Windows でコンソールに直接出すぶんには問題ないが、パイプやファイルに
    渡した瞬間、ロケールの文字コード（日本語環境なら cp932）で書こうとする。
    kicker の見出しに入る ü や ß、画面に出す ✓ は cp932 に無いので、
    そこで落ちる。

    `fetch | collect` は本来つないで使う流れなので、ここでそろえておく。
    実運用のPCで、`fetch --check` をパイプに渡して落ちたのが見つかった。
    """
    for stream in streams or (sys.stdout, sys.stderr):
        encoding = (getattr(stream, "encoding", "") or "").lower().replace("-", "")
        if encoding == "utf8":
            continue
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError, OSError):
            pass  # 差し替えられた出力先（テストなど）。そのまま使う


def _columns(text: str) -> int:
    """表示に使う桁数。全角は2桁として数える。"""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in text)


def _fit(text: str, width: int = 60) -> str:
    """見出しを表示の幅で切り詰める。

    文字数で切ると、日本語の見出しだけ倍の幅になって折り返す。
    候補を選ぶ画面なので、そろっていないと並べて比べられない。
    切ったことが分かるように、末尾に … を付ける。
    """
    if _columns(text) <= width:
        return text

    kept: list[str] = []
    used = 0
    for char in text:
        step = 2 if unicodedata.east_asian_width(char) in "WF" else 1
        if used + step > width - 1:
            break
        kept.append(char)
        used += step
    return "".join(kept) + "…"


def candidates_mod_load(path):
    from . import candidates as candidates_mod

    return candidates_mod.load_candidates(path)


def today_short(path) -> str:
    from . import today as today_mod

    return today_mod._short(Path(path))


def _now_on(day) -> "datetime":
    """その日の「いま」。日付を指定されたときは、その日の同じ時刻とみなす。"""
    from datetime import datetime

    if isinstance(day, datetime):
        return day
    now = datetime.now()
    return datetime.combine(day, now.time())


def _deadline_clock(day) -> "datetime":
    """期限までの残り時間を数えるときの「いま」。

    今日ぶんを見ているなら実時刻を使う。朝6:00で固定していたせいで、
    23時に `today` を打つと「残り21時間」と出る一方、実時刻を見ている
    `doctor` は同じ期限を「残り3時間」と言っていた。期限日は1日で決着が
    つくので、この食い違いはそのまま見落としになる。
    別の日を指定されたときは、その日の最初の枠(07:00)が始まる前を基準にする。
    """
    from datetime import datetime, time

    if isinstance(day, datetime):
        return day
    now = datetime.now()
    if day == now.date():
        return now
    return datetime.combine(day, time(6, 0))


def _deadline_notices(plan, day) -> list[str]:
    """移籍期限が近ければ、その告知の行。遠ければ空。"""
    from . import deadlines as deadlines_mod

    body = plan.calendar or {}
    now = _deadline_clock(day)
    return deadlines_mod.notices(
        deadlines_mod.load(plan),
        now,
        notice_days=float(body.get("notice_days", deadlines_mod.NOTICE_DAYS)),
        after_hours=float(body.get("after_hours", deadlines_mod.AFTER_HOURS)),
    )


def _active_deadlines(plan, day) -> list:
    """いま特別編を出すべき期限。"""
    from . import deadlines as deadlines_mod

    body = plan.calendar or {}
    now = _deadline_clock(day)
    return deadlines_mod.active(
        deadlines_mod.load(plan),
        now,
        after_hours=float(body.get("after_hours", deadlines_mod.AFTER_HOURS)),
    )


def main(argv: list[str] | None = None) -> int:
    _use_utf8()
    parser = argparse.ArgumentParser(prog="src.cli", description="ゆっくり実況動画ビルダー")
    parser.add_argument("--config", default=None, help="設定ファイル (既定: config/project.yaml)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_assets = sub.add_parser("init-assets", help="仮の背景・立ち絵を生成する")
    p_assets.add_argument("--force", action="store_true", help="既存ファイルも上書きする")

    sub.add_parser("speakers", help="VOICEVOX の話者一覧を表示する")

    p_check = sub.add_parser("check", help="台本の書式チェックと想定尺の表示")
    p_check.add_argument("script")

    p_build = sub.add_parser("build", help="動画・字幕・サムネイルを書き出す")
    p_build.add_argument("script")
    p_build.add_argument("--out", default=None, help="出力先ディレクトリ")
    p_build.add_argument("--no-tts", action="store_true", help="音声合成せず無音で尺だけ確認する")
    p_build.add_argument("--backend", default=None, choices=["auto", "engine", "core", "silent"],
                         help="音声合成の方式を明示する（既定は config の設定）")
    p_build.add_argument("--keep-work", action="store_true", help="中間フレームを残す")

    p_short = sub.add_parser("short", help="同じ台本から縦9:16のショートを作る")
    p_short.add_argument("script")
    p_short.add_argument("--section", default=None, help="どの節を使うか（既定: 冒頭の次）")
    p_short.add_argument("--out", default=None)
    p_short.add_argument("--no-tts", action="store_true", help="音声なしで尺だけ確認する")

    p_react = sub.add_parser("reactions", help="まとめスレから書き込みを取り出して数える")
    p_react.add_argument("url", help="まとめサイトの記事URL")
    p_react.add_argument("--limit", type=int, default=5, help="カードに載せる件数（既定5）")
    p_react.add_argument("--say", action="store_true",
                         help="読み上げに回す短い反応を、取材メモの say: の形で出す")
    p_react.add_argument("--limit-say", type=int, default=12,
                         help="読み上げに回す件数（既定12）")
    p_react.add_argument("--voice", default="ネット民",
                         help="読み上げる話者名（既定 ネット民）")
    p_react.add_argument("--word", action="append", default=[],
                         help="数える言葉。ラベル:語,語 の形。何度でも指定できる")

    p_handoff = sub.add_parser("handoff", help="手で投稿するための手順書を書き出す")
    p_handoff.add_argument("build_dir", help="build の出力ディレクトリ")

    p_stock = sub.add_parser("stock", help="内容に合う実写の背景を取ってくる")
    p_stock.add_argument("query", help="探す言葉（英語のほうが当たる）")
    p_stock.add_argument("--name", default=None, help="保存名（既定: 探す言葉から作る）")
    p_stock.add_argument("--seconds", type=float, default=8.0, help="必要な尺")

    p_contact = sub.add_parser("contact", help="画面が変わるたびの1枚を並べて見る")
    p_contact.add_argument("script")
    p_contact.add_argument("--out", default=None, help="出力先（既定: output/<台本名>）")
    p_contact.add_argument("--columns", type=int, default=4, help="横に並べる枚数")

    p_review = sub.add_parser("review", help="書き出したものを公開前に点検する")
    p_review.add_argument("script")
    p_review.add_argument("--out", default=None, help="出力先（既定: output/<台本名>）")
    p_review.add_argument("--no-sources", action="store_true",
                          help="出典URLの生死確認を飛ばす（通信しない）")

    p_thumb = sub.add_parser("thumbnail", help="サムネイルだけ作り直す")
    p_thumb.add_argument("--all", action="store_true", help="台本の案を全部作って並べる")
    p_thumb.add_argument("script")
    p_thumb.add_argument("--out", default=None)

    p_plan = sub.add_parser("plan", help="今日ぶんの取材リストを出す")
    p_plan.add_argument(
        "--routine", default="morning",
        help="config/sources.yaml の routines の名前。all で今日の全枠",
    )
    p_plan.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")
    p_plan.add_argument("--write", action="store_true", help="取材メモの雛形を research/ に作る")
    p_plan.add_argument("--shape", default="",
                        help="話の型: transfer / match / quote / discipline / preview。"
                             "**11本つづけて同じ骨格だったので分けた**（節の名前は書き換えてよい）")
    p_plan.add_argument(
        "--league", default=None,
        help="match ルーティンで、どのリーグの試合かを指定する（england / spain / germany など）",
    )

    p_scan = sub.add_parser("scan", help="候補テーマを拾うための検索リストを出す")
    p_scan.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")
    p_scan.add_argument("--write", action="store_true", help="候補ファイルの雛形を作る")

    p_fetch = sub.add_parser("fetch", help="RSSフィードから最新の見出しを取る（運用PCで使う）")
    p_fetch.add_argument("--league", default=None, help="このリーグのフィードだけ")
    p_fetch.add_argument("--hours", type=float, default=24, help="この時間内の見出しだけ（既定: 24）")
    p_fetch.add_argument("--check", action="store_true", help="全フィードの生死を確かめる")
    p_fetch.add_argument("--url", default=None,
                         help="設定に無いURLを1本だけ試す（差し替える前の下見）")
    p_fetch.add_argument("--discover", default=None, metavar="ページURL",
                         help="そのページが宣言しているフィードを探す（当て推量をやめる）")

    p_subject = sub.add_parser("subject", help="画像に誰が写っているかを確かめる")
    p_subject.add_argument("dir", help="credits.json のあるフォルダ")
    p_subject.add_argument("names", nargs="+", help="本人の名前（日本語・英語の両方を渡してよい）")

    p_portrait = sub.add_parser(
        "portrait", help="人物の顔写真を Commons から取る（被写体を確かめてから）")
    p_portrait.add_argument("dir", help="置き先のフォルダ（例: assets/images/martinelli）")
    p_portrait.add_argument("names", nargs="+", help="本人の名前（英語表記が当たりやすい）")
    p_portrait.add_argument("--whole", action="store_true",
                            help="切らずにそのまま本文へ出す用途。改変不可(ND)の写真も使える")
    p_portrait.add_argument("--crop", default="",
                            help="顔だけ切り出す x,y,w,h（画像に対する割合。例: 0.55,0.05,0.4,0.3）")
    p_portrait.add_argument("--file", default="", dest="only",
                            help="この File: だけを使う（現役/監督など、機械に選べない差を人が決める）")

    p_redesc = sub.add_parser(
        "redescribe", help="公開済み動画の概要欄に、写真のクレジットだけを足す")
    p_redesc.add_argument("script", help="台本のパス")
    p_redesc.add_argument("video_id",
                          help="YouTube の動画ID（URLの v= のあと）。"
                               "ハイフン始まりのときは `--` を挟む")
    p_redesc.add_argument("--dry-run", action="store_true",
                          help="送らずに、いまと何が変わるかだけ見る")

    p_thumb = sub.add_parser(
        "setthumb", help="公開済み動画にサムネイルだけを設定する（投稿はやり直さない）")
    sub.add_parser("quota", help="APIの枠をあとどれだけ使えるか（自分で数えた分）")

    p_priv = sub.add_parser("publish", help="公開済み動画の公開設定だけを変える")
    p_priv.add_argument("video_id",
                        help="YouTube の動画ID。ハイフン始まりのときは `--` を挟む")
    p_priv.add_argument("--privacy", default="public",
                        choices=["private", "unlisted", "public"])

    p_thumb.add_argument("build_dir", help="build の出力ディレクトリ")
    p_thumb.add_argument("video_id",
                         help="YouTube の動画ID。**ハイフンで始まるIDがある**"
                              "（例: -gZ3P1gw8QU）。その場合は `--` を挟む: "
                              "setthumb -- <出力先> -gZ3P1gw8QU")

    p_variety = sub.add_parser(
        "variety", help="その日の台本を横に並べて見る（1本ずつでは分からないこと）")
    p_variety.add_argument("scripts", nargs="+", help="台本のパス（複数）")

    p_results = sub.add_parser("results", help="その日の試合結果を候補にする")
    p_results.add_argument("--date", default=None, help="YYYY-MM-DD（既定: 昨日）")
    p_results.add_argument("--league", default=None, help="england/spain/germany/italy/france など")
    p_results.add_argument("--write", action="store_true", help="候補ファイルに書き出す")

    p_gather = sub.add_parser(
        "gather", help="フィードと貼り付けをまとめて取り、候補ファイルまで作る")
    p_gather.add_argument("--hours", type=float, default=24.0, help="何時間以内のものを取るか")
    p_gather.add_argument("--league", default=None, help="このリーグのフィードだけ")
    p_gather.add_argument("--paste", action="store_true",
                          help="標準入力に貼った検索結果も混ぜる")
    p_gather.add_argument("--topics", action="store_true",
                          help="まとめ集約サイト（FOOTBALL TOPIC）の一覧も取り込む")
    p_gather.add_argument("--topics-sort", default="話題", choices=["話題", "新着"],
                          help="話題=クリック数順 / 新着=新しい順（既定: 話題）")
    p_gather.add_argument("--newsnow", action="store_true",
                          help="NewsNow（英語圏の集約サイト）の見出しも取り込む")
    p_gather.add_argument("--newsnow-limit", type=int, default=30,
                          help="NewsNow から取る件数（1件ごとに中継URLを1回叩く）")
    p_gather.add_argument("--no-feeds", action="store_true", help="フィードを使わない")
    p_gather.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")
    p_gather.add_argument("--out", default=None, help="書き出し先")
    p_gather.add_argument("--append", action="store_true", help="既にある候補ファイルに足す")

    p_collect = sub.add_parser("collect", help="検索結果を貼ると候補ファイルの下書きを作る")
    p_collect.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")
    p_collect.add_argument("--out", default=None, help="書き出し先")
    p_collect.add_argument("--append", action="store_true", help="既にあるファイルに足す")
    p_collect.add_argument("--no-merge", action="store_true", help="同じ話をまとめない")
    p_collect.add_argument("--from", dest="source_label", default=None,
                           help="どの検索から拾ったか（scan の名前）。効かない検索を見つけるのに使う")

    p_pick = sub.add_parser("pick", help="候補を採点して枠に割り振り、深掘りの検索を出す")
    p_pick.add_argument("candidates")

    p_saga = sub.add_parser("saga", help="候補が続報かどうかと、前回との差分を見る")
    p_saga.add_argument("candidates", help="候補ファイル")

    p_lint = sub.add_parser("lint", help="候補ファイルの書き間違いを探す")
    p_lint.add_argument("candidates", help="候補ファイル（research/YYYYMMDD_candidates.yaml）")

    p_today = sub.add_parser("today", help="今日の進み具合と、次に打つコマンドを出す")
    p_today.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")

    p_stats = sub.add_parser("stats", help="これまで何を出してきたかを振り返る")
    p_stats.add_argument("--days", type=int, default=14, help="さかのぼる日数（既定: 14）")

    p_queries = sub.add_parser("queries", help="どの検索が効いているかを見る")
    p_queries.add_argument("--days", type=int, default=30)

    sub.add_parser("doctor", help="収集の仕組みが効いているかをまとめて点検する")

    p_sources = sub.add_parser("sources", help="情報源の網と、群ごとに置ける確度を表示する")
    p_sources.add_argument("--new", action="store_true",
                           help="網に無いサイトのうち、繰り返し出てきたものを挙げる")

    p_clubs = sub.add_parser("clubs", help="クラブ名の別名辞書を引く")
    p_clubs.add_argument("text", nargs="?", default=None,
                         help="見出しなど。どのクラブが読み取れるかを見る（省略で一覧）")

    p_fresh = sub.add_parser("fresh", help="検索で拾ったURLの新しさを判定する")
    p_fresh.add_argument("urls", nargs="*", help="URL。省略すると標準入力から読む")
    p_fresh.add_argument("--no-record", action="store_true", help="索引の記録を更新しない")

    p_x = sub.add_parser("x", help="記者Xアカウントの検索リスト／投稿URLの確認")
    p_x.add_argument("urls", nargs="*", help="投稿URL。省略すると検索リストを出す")
    p_x.add_argument("--topic", default=None, help="この語で各アカウントを検索する")
    p_x.add_argument("--note", default=None, help="この投稿を答え合わせ用に控える（内容を書く）")
    p_x.add_argument("--calls", action="store_true", help="控えた投稿の的中を集計する")
    p_x.add_argument("--no-body", action="store_true",
                     help="本文を取りに行かない（通信しない。時刻と鮮度だけ見る）")

    p_draft = sub.add_parser("draft", help="取材メモ(YAML)を検証して台本にする")
    p_draft.add_argument("notes")
    p_draft.add_argument("--out", default=None, help="出力先の台本パス")
    p_draft.add_argument("--check-only", action="store_true", help="検証だけして書き出さない")
    p_draft.add_argument("--allow-repeat", action="store_true", help="重複の警告を無視する")

    p_new = sub.add_parser("new", help="テンプレートから台本の下書きを作る")
    p_new.add_argument("name", nargs="?", default=None, help="ファイル名（既定: 日付）")
    p_new.add_argument("--template", default="weekly", help="scripts/templates/ の名前")
    p_new.add_argument("--date", default=None, help="動画に出す日付（既定: 今日）")

    p_clip = sub.add_parser("make-clip", help="静止画からゆっくり寄る背景クリップを作る")
    p_clip.add_argument("image", help="元になる画像")
    p_clip.add_argument("--out", default=None, help="出力先 (既定: assets/backgrounds/<名前>.mp4)")
    p_clip.add_argument("--seconds", type=float, default=10.0)
    p_clip.add_argument("--zoom", type=float, default=1.18, help="寄りの強さ（1.0で寄らない）")

    p_upload = sub.add_parser("upload", help="ビルド結果を YouTube に投稿する")
    p_upload.add_argument("build_dir", help="build の出力ディレクトリ")
    p_upload.add_argument("--privacy", default="private", choices=["private", "unlisted", "public"])
    p_upload.add_argument(
        "--again", action="store_true",
        help="同じ出力先をもう一度投稿する（既定では二重投稿を止める）")
    p_upload.add_argument("--dry-run", action="store_true",
                          help="送らずに、何が送られるかを見る（認証も通信もしない）")

    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
        return _dispatch(args, config)
    except (ConfigError, ScriptError, TtsError, PlanError, ResearchError) as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1


# --- サブコマンドごとの処理 ---------------------------------------
# main() が組み立てた args と設定を受け取り、終了コードを返す。
# 並び順は main() の add_parser と同じにしてある。


def _cmd_init_assets(args, config) -> int:
    created = ensure_assets(config, force=args.force)
    print(f"生成: {len(created)} ファイル" if created else "不足している素材はありません")
    for path in created[:6]:
        print(f"  {path}")
    if len(created) > 6:
        print(f"  ... 他 {len(created) - 6} 件")
    return 0


def _cmd_speakers(args, config) -> int:
    from .tts import create_backend

    backend = create_backend(config)
    if backend.name == "silent":
        print(
            "VOICEVOX が見つかりません。VOICEVOX アプリを起動するか、\n"
            "`python scripts/setup_voicevox_core.py` でローカル合成を用意してください。",
            file=sys.stderr,
        )
        return 1
    print(f"backend: {backend.name}")
    for speaker in backend.speakers():
        styles = ", ".join(f"{s['name']}={s['id']}" for s in speaker["styles"])
        print(f"{speaker['name']}: {styles}")
    return 0


def _cmd_check(args, config) -> int:
    script = load_script(args.script)
    print(f"タイトル: {script.title}")
    print(f"シーン: {len(script.scenes)} / セリフ: {len(script.lines)} 行 / {script.char_count()} 文字")
    estimate = sum(line.estimated_duration() for line in script.lines)
    estimate += config.voicevox.pause * len(script.lines)
    print(f"想定尺: 約 {int(estimate // 60)}分{int(estimate % 60):02d}秒")
    for scene in script.scenes:
        print(f"  ## {scene.title} ({len(scene.lines)}行)")
    for line in script.lines:  # 話者が config に無ければここで落ちる
        config.resolve_speaker(line.speaker)
    from .reading import check as reading_check
    from .reading import load_dictionary

    # 読み違えそうな箇所を出す。直すかどうかは書き手が決める
    dictionary = load_dictionary()
    seen: set[str] = set()
    for line in script.lines:
        for hint in reading_check(line.text, dictionary):
            if hint.found in seen:
                continue
            seen.add(hint.found)
            arrow = f" → {hint.suggest}" if hint.suggest else ""
            print(f"　読み: {hint.found}{arrow}　（{hint.why}）")

    print("書式OK")
    return 0


def _cmd_build(args, config) -> int:
    if args.backend:
        config.voicevox.backend = args.backend
    ensure_assets(config)
    result = build(
        args.script,
        config,
        out_dir=Path(args.out) if args.out else None,
        use_tts=not args.no_tts,
        keep_work=args.keep_work,
    )
    if result.backend == "silent":
        print("※ VOICEVOX が見つからないため無音で書き出しました（尺確認用）")
    else:
        print(f"音声: VOICEVOX ({result.backend})")
    minutes, seconds = divmod(int(result.duration), 60)
    print(f"完成: {result.video}  ({minutes}分{seconds:02d}秒)")
    print(f"サムネ: {result.thumbnail}")
    for name, path in result.outputs.items():
        print(f"{name}: {path}")
    return 0


def _cmd_short(args, config) -> int:
    from . import shorts
    from .pipeline import build_script

    script = load_script(args.script)
    try:
        short = shorts.trim(script, args.section or "")
    except shorts.ShortError as error:
        print(str(error), file=sys.stderr)
        return 1

    out = Path(args.out) if args.out else shorts.default_path(args.script)
    estimate = shorts._estimate(short)
    print(f"■ ショート　{' → '.join(scene.title for scene in short.scenes)}")
    print(f"　想定尺: 約{estimate:.0f}秒 / セリフ {len(short.lines)}行")

    result = build_script(
        short, shorts.portrait(config), out, use_tts=not args.no_tts
    )
    print(f"完成: {result.video}  ({result.duration:.0f}秒)")
    # **どちらも要る点検。**顔が遅い／冒頭で喋っていない、は別の問題
    for problem in shorts.face_problems(short):
        print(f"  ! {problem}", file=sys.stderr)

    # 冒頭で捨てられていないか、その場で見る。review は --out を渡さないと
    # ショートの出力先を見ないので、作った直後に必ず出るようにしておく
    from .review import check_short_opening

    opening = check_short_opening(Path(result.video))
    if opening is not None and not opening.ok:
        print(f"! {opening.detail}", file=sys.stderr)
    if result.duration > shorts.MAX_SECONDS:
        print(
            f"! {result.duration:.0f}秒あります。ショートは60秒までなので、"
            "--section で短い節を選ぶか、台本のセリフを削ってください",
            file=sys.stderr,
        )
        return 1
    return 0


def _cmd_reactions(args, config) -> int:
    """まとめスレの書き込みを取り出して数える。

    **「多い」と言うには数える。**数えた件数と母数を出すので、台本には
    「47件中12件」のように書ける。数えずに「声が多い」とは書かない。
    """
    from . import reactions as reactions_mod

    try:
        posts = reactions_mod.fetch(args.url)
    except reactions_mod.ReactionError as error:
        print(str(error), file=sys.stderr)
        return 1
    if not posts:
        print("書き込みを取り出せませんでした。ページの作りが違うかもしれません",
              file=sys.stderr)
        return 1

    print(f"■ 書き込み　{len(posts)}件　（母数はこの数）")
    for post in posts[: args.limit]:
        print(f"  >>{post.no}　{_fit(post.short, 56)}")

    words: dict[str, tuple[str, ...]] = {}
    for item in args.word:
        label, _, keys = item.partition(":")
        if label and keys:
            words[label] = tuple(k for k in keys.split(",") if k)
    if words:
        print("\n■ 数えた結果")
        for label, count in reactions_mod.tally(posts, words).items():
            share = count / len(posts) * 100
            print(f"  {label}　{count}件 / {len(posts)}件（{share:.0f}%）")

    if args.say:
        # **読み上げに回す形**（2026-09-07）。カードに載せるだけでは画面が
        # 変わらない。伸びている3チャンネルは尺の58%を他人の声に使い、
        # 1件2〜4秒でぶつ切りに読ませていた（こちらは14%・2.2件だった）
        picked = reactions_mod.say_lines(posts, want=args.limit_say)
        print(f"\n読み上げに回す形（{len(picked)}件 / 母数{len(posts)}件）:")
        print("    say:")
        for post in picked:
            print(f"      - {{voice: {args.voice}, text: {post.text}, telop: {post.text}}}")
        print("    tier: 未確認")
        print(f"    sources:\n      - {args.url}")
        return 0

    print("\n取材メモに貼る形:")
    print("    card:")
    print("      type: reactions")
    print(f"      title: ネットの反応（{len(posts)}件から）")
    print("      items:")
    for post in posts[: args.limit]:
        print(f"        - {{text: {post.short}, label: '>>{post.no}'}}")
    print(f"    tier: 未確認    # 匿名の書き込みなので、単独では根拠にしない")
    print(f"    sources:\n      - {args.url}")
    return 0


def _cmd_handoff(args, config) -> int:
    """手で投稿するときの手順書を書き出す。

    API の1日枠を超えたぶんは Studio から手で上げる。**何をどこに貼るのかを
    毎回思い出すのは無駄**なので、投稿画面の順に並べて1枚に置く。
    """
    from . import handoff as handoff_mod
    from .config import _resolve

    out = _resolve(args.build_dir)
    try:
        target = handoff_mod.write_sheet(out)
    except handoff_mod.HandoffError as error:
        print(str(error), file=sys.stderr)
        return 1
    print(f"手順書: {target}")
    print("  動画・サムネ・字幕の場所と、貼る文面が順番に並んでいます")
    return 0


def _cmd_stock(args, config) -> int:
    """内容に合う実写の背景を取ってくる。

    **背景を決め打ちにしない**（2026-09-05 のユーザー判断）。自前で描いた
    PNG に模様を足すより、実写のほうが強い。取得先は Pexels と Pixabay。
    """
    import re as _re

    from . import stock as stock_mod
    from .config import _resolve

    slug = args.name or _re.sub(r"[^a-z0-9]+", "_", args.query.lower()).strip("_")[:40]
    target = _resolve(f"assets/backgrounds/stock/{slug}.mp4")
    try:
        clip = stock_mod.fetch(args.query, target, args.seconds)
    except stock_mod.StockError as error:
        print(str(error), file=sys.stderr)
        return 1
    size = target.stat().st_size / 1024 / 1024
    print(f"取れました: {target}")
    print(f"  {clip.width}x{clip.height} / {clip.seconds:.0f}秒 / {size:.1f}MB")
    print(f"  撮影 {clip.author}（{clip.source} / {clip.license}）")
    print(f"  {clip.url}")
    print()
    print("台本に書くとき:")
    print(f"  @bg: assets/backgrounds/stock/{slug}.mp4")
    return 0


def _cmd_contact(args, config) -> int:
    """完成した動画から、画面が変わるたびの1枚を並べた紙を作る。

    機械の点検が緑でも、読める・読めないは見るまで分からない。
    見るのを面倒にしない（2026-09-04 の実測から）。
    """
    from .review import contact_sheet

    out = Path(args.out) if args.out else Path(f"output/{Path(args.script).stem}")
    sheet = contact_sheet(out, columns=args.columns)
    if sheet is None:
        print(f"動画か script.json がありません: {out}", file=sys.stderr)
        return 1
    print(f"一覧: {sheet}")
    print("開いて、文字の割れ・写真の大きさ・カードの重なりを見てください")
    return 0


def _cmd_review(args, config) -> int:
    from .review import built_duration, inspect, manual_checks

    script = load_script(args.script)
    out = Path(args.out) if args.out else Path(f"output/{Path(args.script).stem}")
    duration = built_duration(out)

    print(f"■ 公開前の点検　{script.title}")
    findings = inspect(script, out, duration)

    # 出典の生死は機械で見られる。消えた記事を出典に載せたまま投稿しないため
    if not args.no_sources:
        from .review import check_sources

        urls = sorted({line.source_url for line in script.lines if getattr(line, "source_url", "")})
        if not urls:
            urls = _description_urls(out)
        findings += check_sources(urls)

    for finding in findings:
        print(finding.line())

    failed = [f for f in findings if not f.ok]
    print("\n■ 目と耳で確かめる")
    for note in manual_checks():
        print(f"  □ {note}")

    if failed:
        print(f"\n{len(failed)}件、直してから出してください", file=sys.stderr)
        return 1
    print("\n機械で見られるところは問題ありません")
    return 0


def _description_urls(out_dir: Path) -> list[str]:
    """概要欄に載せたURL。台本側に無ければ、実際に出すものから拾う。"""
    import re

    body = (out_dir / "description.txt")
    if not body.exists():
        return []
    return sorted(set(re.findall(r"https?://\S+", body.read_text(encoding="utf-8"))))


def _cmd_thumbnail(args, config) -> int:
    script = load_script(args.script)
    out = Path(args.out) if args.out else Path(f"output/{Path(args.script).stem}/thumbnail.png")
    from .thumbnail import from_meta, variants

    looks = variants(script.meta, script.title) if args.all else [
        dict(from_meta(script.meta, script.title), name="")
    ]

    made = []
    for index, look in enumerate(looks, start=1):
        target = out if len(looks) == 1 else out.with_name(f"{out.stem}_{index}{out.suffix}")
        build_thumbnail(
            config, look["title"], target,
            subtitle=look["subtitle"],
            background=look.get("photo") or script.background,
            focus=look.get("focus"),
            badge=look["badge"], date=look["date"],
            lines=look["lines"], tags=look["tags"],
        )
        made.append((look.get("name") or "", target, look["lines"]))

    for name, target, lines in made:
        head = f"{name}　" if name else ""
        print(f"サムネ: {head}{target}")
        print(f"        {lines[0]} / {lines[1]}")

    if len(made) > 1:
        from .thumbnail import contact_sheet

        sheet = contact_sheet([t for _, t, _ in made], out.with_name("thumbnails.png"))
        print(f"\n並べたもの: {sheet}")
        print("一覧で見て、目を引くほうを選んでください")
    return 0


def _cmd_plan(args, config) -> int:
    from datetime import date as _date

    from .config import _resolve
    from .plan import load_plan, render, worksheet

    from . import coverage as coverage_mod

    plan = load_plan()
    today = _date.fromisoformat(args.date) if args.date else _date.today()

    settings = plan.coverage or {}
    recent = []
    if settings.get("ledger"):
        recent = coverage_mod.recent(
            coverage_mod.load(settings["ledger"]), int(settings.get("show_recent", 12))
        )

    if args.routine == "all":
        if not plan.slots:
            print("cadence.slots が定義されていません", file=sys.stderr)
            return 1
        for key in plan.slots:
            print(render(plan.routine(key), today, recent))
            print()
        return 0

    routine = plan.routine(args.routine)
    print(render(routine, today, recent))

    # 試合結果はリーグごとに引き先が変わる。指定があればその2本を添える
    if args.league:
        queries = plan.match_queries(args.league)
        if not queries:
            known = " / ".join(plan.leagues)
            print(f"\n知らないリーグです: {args.league}（{known}）", file=sys.stderr)
            return 1
        print(f"\n■ {plan.league_name(args.league)} の試合レポートを引く")
        for query in queries:
            print(f"   {query.line()}")
        print("   確認: スコアと得点者は公式で確かめる。見出しのスコアを鵜呑みにしない")

    if args.write:
        target = _resolve(f"research/{today.strftime('%Y%m%d')}_{routine.key}.yaml")
        if target.exists():
            print(f"すでにあります: {target}", file=sys.stderr)
            return 1
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            worksheet(routine, today, getattr(args, "shape", "") or "",
                      plan.skeletons),
            encoding="utf-8")
        print(f"取材メモ: {target}")
        print(f"埋めたら `python -m src.cli draft {target}` で台本になります")
    return 0


def _cmd_scan(args, config) -> int:
    from datetime import date as _date

    from . import candidates as candidates_mod
    from . import timing
    from .config import _resolve
    from .plan import load_plan, tokens

    plan = load_plan()
    today = _date.fromisoformat(args.date) if args.date else _date.today()
    words = tokens(today, 24)
    scan = plan.scan

    print(f"■ 候補スキャン　{words['{date_ja}']}")
    if scan.get("when"):
        print(f"　目安の時刻: {scan['when']}")
    for note in _deadline_notices(plan, today):
        print(f"　{note}")
    # 欧州は日本の深夜に動く。いま何が取れる時間帯かを言う
    for note in timing.advice(plan, _now_on(today)):
        print(f"　{note}")
    print()
    number = 0
    for item in scan.get("queries") or []:
        label = str(item.get("label", ""))

        # per_league の行は、追っているリーグのぶんに展開する。
        # 全リーグまとめて1本で引くと、どの試合の記事か分からないまま返ってくる
        if item.get("per_league"):
            # 先に閉じるリーグから並べる。閉じたあとは翌日まで新しいものが出ない
            for key in timing.order(
                plan, [str(k) for k in (scan.get("match_leagues") or [])], _now_on(today)
            ):
                for query in plan.match_queries(key, official=False):
                    number += 1
                    print(f"{number}. {label}　{query.line()}")
            continue

        text = str(item.get("q", ""))
        for token, value in words.items():
            text = text.replace(token, value)
        group = item.get("domains")
        domains = plan.domains.get(str(group), []) if group else []
        number += 1
        line = f'{number}. {label}: "{text}"'
        if domains:
            line += f"  （{', '.join(domains)} に限定）"
        print(line)
    # 期限日は1日で決着がつく。当日と直後だけ、特別編の検索も並べる
    for item in _active_deadlines(plan, today):
        print(f"\n― 移籍期限（{item.name}・{item.stamp} JST）ぶんの追加検索 ―")
        for step in plan.routine("deadline_day").steps:
            for query in step.queries:
                number += 1
                text = query.text
                for token, value in words.items():
                    text = text.replace(token, value)
                line = f'{number}. {step.id}: "{text}"'
                if query.domains:
                    line += f"  （{', '.join(query.domains)} に限定）"
                print(line)
        break

    for note in str(scan.get("check", "")).splitlines():
        if note.strip():
            print(f"   確認: {note.strip()}")

    if args.write:
        target = _resolve(f"research/{today.strftime('%Y%m%d')}_candidates.yaml")
        if target.exists():
            print(f"\nすでにあります: {target}", file=sys.stderr)
            return 1
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(candidates_mod.worksheet(words["{date_ja}"]), encoding="utf-8")
        print(f"\n候補ファイル: {target}")
        print(f"埋めたら `python -m src.cli pick {target}`")
    return 0


def _cmd_clubs(args, config) -> int:
    from . import clubs as club_book

    book = club_book.load()
    if not book:
        print("クラブ名の辞書がありません: config/clubs.yaml", file=sys.stderr)
        return 1

    if args.text:
        found = club_book.find(args.text, book)
        if not found:
            print("辞書に載っているクラブは見つかりませんでした")
            print("見出しに略称しか無いなら、config/clubs.yaml の aka に足してください")
            return 0
        print(f"■ 読み取れたクラブ　{len(found)}件")
        for club in found:
            mark = "★" if club.big else "・"
            where = f"　{club.league}" if club.league else ""
            print(f"  {mark} {club.canonical}{where}")
        league = club_book.league_of(args.text, book)
        print(f"\nリーグ: {league or '（複数にまたがるので決めない）'}")
        print(f"話題の当たり: {club_book.topic_of(args.text, book)}")
        return 0

    from .plan import load_plan

    plan = load_plan()
    by_league: dict[str, list] = {}
    for club in book:
        by_league.setdefault(club.league or "その他", []).append(club)
    print(f"■ クラブ名の別名辞書　{len(book)}クラブ")
    for key, found in by_league.items():
        name = plan.league_name(key) if key != "その他" else key
        print(f"\n― {name}　{len(found)}クラブ ―")
        for club in found:
            mark = "★" if club.big else "・"
            print(f"  {mark} {club.canonical}　{' / '.join(club.aka)}")
    print("\n★ … ビッグクラブ扱い（候補の採点で加点する）")
    return 0


def _cmd_today(args, config) -> int:
    from datetime import date as _date

    from . import timing
    from . import today as today_mod
    from .plan import load_plan

    plan = load_plan()
    day = _date.fromisoformat(args.date) if args.date else _date.today()
    stamp = day.strftime("%Y%m%d")

    pairs = [(key, plan.routine(key).name) for key in plan.slots]
    candidates, slots = today_mod.survey(pairs, day)

    # ゼロ詰めを外す strftime 書式は Windows に無い。月日は自分で組み立てる
    print(f"■ {day.year}年{day.month}月{day.day}日 の進み具合")
    for note in _deadline_notices(plan, day):
        print(f"  {note}")
    for note in timing.advice(plan, _now_on(day)):
        print(f"  {note}")
    mark = "✓" if candidates.exists() else "・"
    print(f"  {mark} 候補　{today_mod._short(candidates)}")

    for slot in slots:
        done = slot.done
        marks = "".join(
            "✓" if step in done else "・" for step in today_mod.STEPS[1:]
        )
        print(f"  {marks} {slot.name}　{' / '.join(done) or 'まだ何もない'}")

    # フィードが使えるなら、そちらのほうが速く確実に取れる
    first = (
        "python -m src.cli gather"
        if any(feed.get("verified") for feed in (plan.feeds or []))
        else "python -m src.cli scan --write"
    )
    print(f"\n次にこれを打つ:\n  {today_mod.next_step(candidates, slots, stamp, first)}")
    for item in _active_deadlines(plan, day):
        print(
            "\n今日は移籍期限日。通常の枠とは別に特別編を出す:\n"
            "  python -m src.cli plan --routine deadline_day --write"
        )
        break
    return 0


def _cmd_stats(args, config) -> int:
    from . import coverage as coverage_mod
    from . import stats as stats_mod
    from .plan import load_plan

    plan = load_plan()
    entries = coverage_mod.load(plan.coverage.get("ledger", "research/covered.yaml"))
    target = len(plan.slots) or 3   # 1日に出す本数（cadence.slots の数）
    summary = stats_mod.summarise(entries, args.days)

    print(f"■ 直近{args.days}日　{summary.total}本（1日あたり {summary.average:.1f}本 / 目標 {target}本）")
    for row in stats_mod.bars(summary, target):
        print(row)

    if summary.slots:
        print("\n■ 枠ごと")
        for key in plan.slots:
            routine = plan.routines.get(key)
            name = routine.name if routine else key
            print(f"  {name}　{summary.slots.get(key, 0)}本")

    if summary.themes:
        print("\n■ よく扱ったテーマ")
        for key, count in summary.themes:
            print(f"  {count}回　{key}")

    # どのリーグを次に見るか決めるための材料。追えていない期間・いま記事が
    # 出る時間帯か・移籍期限がどうなっているかは、別々の場所に散っていた
    rows = stats_mod.league_status(entries, plan)
    if rows:
        print("\n■ リーグの状況")
        for row in rows:
            print(row.line())

    _, kind_rows = stats_mod.gaps(entries, plan.leagues)
    if any(days != 0 for _, days in kind_rows):
        print("\n■ 追えていない種別")
        for kind, days in kind_rows:
            label = {"transfer": "移籍", "match": "試合結果"}.get(kind, kind)
            if days != 0:
                print(f"  {label}　" + ("一度も扱っていない" if days < 0 else f"{days}日前が最後"))

    notes = stats_mod.advice(summary, target)
    if notes:
        print()
        for note in notes:
            print(f"! {note}")
    return 0


def _cmd_queries(args, config) -> int:
    from . import queries as queries_mod

    rows = queries_mod.tally(queries_mod.load(), args.days)
    if not rows:
        print("まだ記録がありません。")
        print("`collect --from \"検索の名前\"` で、どの検索から拾ったかを控えます")
        return 0

    print(f"■ 直近{args.days}日の検索　候補の少ない順")
    for label, times, hits in rows:
        print(f"  {hits:3d}件 / {times:2d}回　{label}")

    for label in queries_mod.dead(rows):
        print(f"\n! 『{label}』は何度も回して1件も候補になっていません。"
              "検索語を見直すか、config/sources.yaml から外してください")
    return 0


def _cmd_doctor(args, config) -> int:
    from .doctor import diagnose
    from .plan import load_plan

    notes = diagnose(load_plan())
    notes.append(_voice_note(config))
    print("■ 収集の健康診断")
    for note in notes:
        print(note.line())

    failed = [n for n in notes if not n.ok]
    if failed:
        print(f"\n{len(failed)}件、手を入れたほうがよいところがあります")
        return 1
    print("\n問題ありません")
    return 0


def _voice_note(config):
    """音声合成が使える状態か。

    build は VOICEVOX が見つからないと黙って無音で書き出す（尺確認用としては
    正しい）。ただ朝の運用でこれに気づかないと、無音の動画を3本作ってから
    気づくことになる。週1で見る健康診断に、声の確認も入れておく。
    """
    from .doctor import Note
    from .tts import create_backend

    try:
        backend = create_backend(config)
    except Exception as error:
        return Note(False, "音声", f"バックエンドを作れません: {error}")
    if backend.name == "silent":
        return Note(
            False, "音声",
            "VOICEVOX が見つかりません（このまま build すると無音になります）。"
            "アプリを起動するか scripts/setup_voicevox_core.py を実行",
        )
    return Note(True, "音声", f"VOICEVOX（{backend.name}）が使えます")


def _cmd_sources(args, config) -> int:
    from datetime import date as _date

    from .plan import load_plan

    plan = load_plan()

    if args.new:
        from . import newsites

        sites = newsites.load()
        if not sites:
            print("網の外のサイトはまだ控えていません（collect を回すと貯まります）")
            return 0
        picks = newsites.propose(sites)
        print(f"■ 網に足す候補　控え{len(sites)}件のうち{len(picks)}件")
        if not picks:
            print(f"  別々の日に{newsites.MIN_DAYS}回以上出てきたサイトはまだありません")
            print("  1日のうちに何度出ても、網に足す理由にはなりません")
            return 0
        for site in picks:
            print(f"\n  {site.host}　{len(site.days)}日 / のべ{site.seen}回")
            for url in site.examples:
                print(f"    {url}")
        print(
            "\n足すなら config/sources.yaml の domains に書き、"
            "domain_tiers でその群の確度の上限も決めてください。"
            "\n塞がれていて開かないサイトは blocked に入れます"
        )
        return 0

    labels = {
        "official": "クラブ・リーグ公式",
        "official_jp": "公式（日本）",
        "english": "英語の報道機関",
        "japanese": "日本語の報道機関",
        "aggregator": "横断（複数媒体）",
        "stats": "記録・数字",
        "german": "ドイツ語",
        "italian": "イタリア語",
        "french": "フランス語",
        "dutch": "オランダ語",
        "spanish": "スペイン語",
        "social": "SNS",
        "rumour": "噂まとめ",
    }
    print("■ 情報源の網")
    for group, hosts in plan.domains.items():
        if group == "blocked":
            continue
        ceiling = plan.domain_tiers.get(group, "—")
        print(f"\n  {labels.get(group, group)}（{group}）　置ける確度: {ceiling}")
        for host in hosts:
            print(f"    {host}")

    blocked = plan.domains.get("blocked") or []
    print(f"\n■ 取得できない {len(blocked)}件（検索しても結果が返らない）")
    print("  " + " / ".join(str(h) for h in blocked))

    if plan.verified_on:
        print(f"\n最終確認: {plan.verified_on}")
        try:
            days = (_date.today() - _date.fromisoformat(plan.verified_on)).days
        except ValueError:
            days = 0
        if days > 90:
            print(
                f"  ! {days}日たっています。塞がれたサイト・開いたサイトがあるかもしれません。"
                "各群に1本ずつ検索をかけて確かめ、verified_on を更新してください"
            )
    return 0


def _cmd_fresh(args, config) -> int:
    from . import freshness

    urls = args.urls or [line.strip() for line in sys.stdin if line.strip()]
    if not urls:
        print("URLを渡してください（引数か標準入力）", file=sys.stderr)
        return 1

    groups = freshness.rank(urls)
    if not groups:
        print("新しさを判定できるURLがありませんでした。", file=sys.stderr)
        print("対応: skysports.com / espn.com / x.com", file=sys.stderr)
        return 1

    ledger = freshness.LEDGER
    entries = freshness.load(ledger)
    updated, growth = freshness.observe(groups, entries)

    for site, refs in groups.items():
        # 日付がURLに入るサイトは推定が要らないので、伸びの話も出さない
        dated = all(ref.exact for ref in refs)
        pace = None if dated else freshness.rate(entries, site)
        observed_for = freshness.span(entries, site)

        head = f"■ {site}　新しい順に{len(refs)}件"
        if not dated:
            head += f"　（記事IDの伸び: {pace:.0f}/時）" if pace else "　（伸びは記録待ち）"
        print(head)

        for ref in refs:
            age = freshness.hours_ago(ref, entries)
            when = f"{age:.0f}時間前" if age is not None else "不明"
            mark = "確定" if ref.exact else "概算"
            label = ref.posted_on.strftime("%m/%d") if ref.posted_on else str(ref.number)
            print(f"  {label}　{when}（{mark}）")
            print(f"      {ref.url}")

        if pace and observed_for < 24:
            print(
                f"  ※ 観測がまだ{observed_for:.0f}時間ぶんです。記事の出る量は時間帯で"
                "変わるので、数時間より前の概算はずれます。並び順は正確です"
            )
        print()

    skipped = [u for u in urls if not freshness.read(u).known]
    if skipped:
        print(f"判定できなかったURL {len(skipped)}件（日付の手がかりが無い）:")
        for url in skipped:
            print(f"  {url}")
        print()

    for ref, top in freshness.suspects(groups, entries):
        print(
            f"! 前のシーズンの記事かもしれません: {ref.url}\n"
            f"    記事ID {ref.number} は、記録している最大 {top} を大きく下回っています。"
            "見出しが同じでも別の年の試合のことがあります"
        )

    for note in freshness.advice(growth, entries):
        print(f"! {note}")

    if not args.no_record:
        if len(updated) > len(entries):
            # 回すたびに増えるので、書くついでに整理する
            path = freshness.save(ledger, freshness.prune(updated))
            print(f"索引の記録を更新しました: {path}")
        else:
            print("索引は前回から進んでいません（記録は変えていません）")
    return 0


def _cmd_x(args, config) -> int:
    from . import xposts
    from .plan import load_plan

    plan = load_plan()
    stale = int(plan.social.get("stale_hours", 72))

    backend = str(plan.social.get("backend", "search"))

    if args.calls:
        calls = xposts.load_calls()
        if not calls:
            print("まだ控えがありません。`x <URL> --note \"内容\"` で控えます")
            return 0
        print(f"■ 記者の答え合わせ　{len(calls)}件")
        for handle, (hit, miss, pending) in sorted(xposts.hit_rate(calls).items()):
            entry = xposts.trusted(handle, plan.accounts)
            tier = f"［{entry.get('tier', '未確認')}］" if entry else "［未登録］"
            print(f"  @{handle}　{tier}　的中{hit} / 外れ{miss} / 未判明{pending}")
        for note in xposts.review_accounts(calls, plan.accounts):
            print(f"\n! {note}")
        print(f"\n判定は {xposts.LEDGER} の outcome を 的中 / 外れ に直します")
        return 0

    if args.note and args.urls:
        for url in args.urls:
            call = xposts.record_call(url, args.note)
            print(f"控えました: @{call.handle}　{call.at:%m/%d %H:%M} UTC")
        print(f"あとで {xposts.LEDGER} の outcome を直してください")
        return 0

    if not args.urls and backend == "api":
        from . import xapi

        settings = dict(plan.social.get("api") or {})
        handles = [str(a.get("handle", "")) for a in plan.accounts]
        try:
            client = xapi.Client.from_env()
            posts = client.by_accounts(
                handles, args.topic or "", int(settings.get("max_results", 10))
            )
        except xapi.XApiError as error:
            print(f"X API を使えませんでした:\n{error}", file=sys.stderr)
            print("\nconfig/sources.yaml の social.backend を search に戻すと、"
                  "検索経由（無料）で拾えます", file=sys.stderr)
            return 1

        if not posts:
            print("該当する投稿がありませんでした。")
            return 0
        print(f"■ X API　{len(posts)}件（新しい順）")
        for post in posts:
            age = post.hours_ago()
            print(f"\n@{post.handle}　{post.author}　（{age:.0f}時間前）")
            print(f"  {post.text}")
            print(f"  {post.url}")
        return 0

    if not args.urls:
        print("■ 追っているアカウント")
        for entry in plan.accounts:
            handle = str(entry.get("handle", ""))
            print(f"  @{handle}　{entry.get('name', '')}　［{entry.get('tier', '未確認')}］")
            print(f"      {entry.get('note', '')}")
            topic = args.topic or entry.get("name") or handle
            print(f'      検索: "{topic}"  （x.com に限定）')
        lag = stale
        index_lag = int(plan.social.get("index_lag_hours", 48))
        print(
            f"\n  検索に出るのは{index_lag}時間ほど前までの投稿（実測）。"
            "Xは速報には使えない。背景・反応・裏取りに使う"
        )
        print(f"  {lag}時間より古い投稿は、続報が出ていないか確認してから使う")
        print(
            "  social.backend を api にすると、遅れなし・本文も切れずに取れる（有料）"
        )
        for note in str(plan.social.get("check", "")).splitlines():
            if note.strip():
                print(f"  確認: {note}")
        return 0

    for url in args.urls:
        if not xposts.is_post(url):
            print(f"× {url}\n    Xの投稿URLとして読めません")
            continue
        handle, _ = xposts.parse_url(url)
        when = xposts.posted_at(url)
        age = xposts.Post(url=url, posted_at=when).hours_ago()
        entry = xposts.trusted(handle, plan.accounts)
        who = f"{entry['name']}（{entry.get('tier', '未確認')}）" if entry else "未登録"
        lag = int(plan.social.get("index_lag_hours", 48))
        note = "　※検索に出るなかでは新しいほう" if age <= lag else ""
        print(f"@{handle}　{who}")
        print(f"    投稿: {when:%Y-%m-%d %H:%M} UTC　（{age:.0f}時間前）{note}")

        # 本文は埋め込み用のエンドポイントから取る。検索結果と違って切れない
        if not args.no_body:
            from . import xembed

            try:
                post = xembed.fetch(url)
            except xembed.XEmbedError as error:
                print(f"    ! 本文を取れませんでした: {error}")
            else:
                mismatch = xembed.impersonation(url, post)
                if mismatch:
                    print(f"    ! {mismatch}")
                if post.text:
                    for line in post.text.splitlines():
                        print(f"    | {line}")
                    if post.truncated:
                        print("    ! 本文が途中で切れています。この引用は使わないこと")
                else:
                    print("    | （本文なし。画像や動画だけの投稿）")

        for problem in xposts.review(url, plan.accounts, stale):
            print(f"    ! {problem}")
    return 0


def _cmd_fetch(args, config) -> int:
    from . import feeds as feeds_mod
    from .plan import load_plan

    plan = load_plan()

    # フィードのURLは当て推量で探すと外す。ページ自身に聞く
    if args.discover:
        try:
            found = feeds_mod.discover(args.discover)
        except feeds_mod.FeedError as error:
            print(f"× {error}", file=sys.stderr)
            return 1
        if not found:
            print("このページはフィードを宣言していません", file=sys.stderr)
            print("別のページ（トップや各セクション）で試してみてください", file=sys.stderr)
            return 1

        print(f"■ 宣言されているフィード　{args.discover}\n")
        for name, url in found:
            print(f"  {name}")
            print(f"    {url}")
        print("\n中身を見るには:")
        print(f'  python -m src.cli fetch --url "{found[0][1]}"')
        return 0

    # 設定に入れる前に、そのURLが何を返すか見る。
    # Sky のように「全スポーツ版」と「サッカー版」が別URLで並んでいることがあり、
    # 生きているかどうかだけでは中身の違いが分からない
    if args.url:
        try:
            items = feeds_mod.fetch(args.url)
        except feeds_mod.FeedError as error:
            print(f"× 取得できません: {error}", file=sys.stderr)
            return 1
        if not items:
            print("× 取れましたが、項目が1つもありません", file=sys.stderr)
            return 1

        print(f"■ 下見　{args.url}")
        print(f"　{len(items)}件\n")
        for item in items[:20]:
            age = item.hours_ago()
            mark = f"{max(0.0, age):5.1f}時間前" if age is not None else "　時刻なし"
            print(f"  {mark}  {_fit(item.title, 70)}")
        if len(items) > 20:
            print(f"  … 他{len(items) - 20}件")
        print("\n見出しを見て、狙った内容が返っているか確かめてください。")
        print("よければ config/sources.yaml の feeds に足します")
        return 0

    wanted = [
        f for f in plan.feeds
        if not args.league or str(f.get("league")) == args.league
    ]
    if not wanted:
        print("フィードがありません（config/sources.yaml の feeds）", file=sys.stderr)
        return 1

    if args.check:
        alive = 0
        print(f"■ フィードの生死確認　{len(wanted)}本")
        for feed in wanted:
            try:
                items = feeds_mod.fetch(str(feed.get("url", "")))
                newest = items[0].hours_ago() if items else None
                if feeds_mod.is_stale(newest):
                    # 取れるが止まっている。件数だけ見ていると気づけない
                    print(
                        f"  × {feed.get('name')}　{len(items)}件あるが"
                        f"最新が{int(newest // 24)}日前。止まっています。使わないこと"
                    )
                else:
                    print(f"  ✓ {feed.get('name')}　{len(items)}件　{feeds_mod.age_text(newest)}")
                    alive += 1
            except feeds_mod.FeedError as error:
                print(f"  × {feed.get('name')}　{error}")
        print(
            f"\n{alive}/{len(wanted)}本が生きています。"
            "生きたものは verified: true に、死んだものは消してください"
        )
        return 0 if alive else 1

    collected: list = []
    broken: list[str] = []
    for feed in wanted:
        try:
            items = feeds_mod.fetch(str(feed.get("url", "")))
        except feeds_mod.FeedError:
            broken.append(str(feed.get("name")))
            continue
        collected += feeds_mod.recent(items, args.hours)

    # 見出し<タブ>URL で出す。そのまま collect に流せる
    seen: set[str] = set()
    for item in sorted(
        collected,
        key=lambda i: i.hours_ago() if i.hours_ago() is not None else 9e9,
    ):
        if item.url in seen:
            continue
        seen.add(item.url)
        print(item.line())

    # フィードは記事URLと正確な公開時刻を一緒にくれる。
    # 「そのIDがいつの時点のものか」が分かるので、索引の水準を較正できる
    from . import freshness

    entries = freshness.load(freshness.LEDGER)
    entries, tuned = freshness.calibrate(
        [(item.url, item.published) for item in collected if item.published],
        entries,
    )
    if tuned:
        freshness.save(freshness.LEDGER, freshness.prune(entries))
        print(
            f"索引の水準を較正しました: {' / '.join(sorted(tuned))}",
            file=sys.stderr,
        )

    if broken:
        print(f"取得できなかったフィード: {' / '.join(broken)}", file=sys.stderr)
    print(
        f"{len(seen)}件（{args.hours:g}時間以内）。"
        "`| python -m src.cli collect` で候補ファイルにできます",
        file=sys.stderr,
    )
    return 0 if seen else 1


def _cmd_quota(args, config) -> int:
    """枠の残りを見る。**APIは残量を教えてくれない**ので、自分で数えたもの。"""
    from . import quota

    for line in quota.report():
        print(line)
    return 0


def _cmd_publish(args, config) -> int:
    """公開設定だけを変える。**投稿はやり直さない**（動画が二重になる）。"""
    from .upload import UploadError, get_service, set_privacy

    try:
        set_privacy(get_service(), args.video_id, args.privacy)
    except UploadError as err:
        print(f"変えられません: {err}", file=sys.stderr)
        return 1
    except Exception as err:
        print(f"変えられません: {err}", file=sys.stderr)
        return 1
    print(f"■ {args.privacy} にしました: https://youtu.be/{args.video_id}")
    return 0


def _cmd_setthumb(args, config) -> int:
    """サムネイルだけを設定する。**投稿はやり直さない**（動画が二重になる）。"""
    from .upload import UploadError, get_service, set_thumbnail

    thumbnail = Path(args.build_dir) / "thumbnail.png"
    try:
        set_thumbnail(get_service(), args.video_id, thumbnail)
    except UploadError as err:
        print(f"設定できません: {err}", file=sys.stderr)
        return 1
    except Exception as err:
        print(f"設定できません: {err}", file=sys.stderr)
        return 1
    print(f"■ サムネイルを設定: https://youtu.be/{args.video_id}")
    return 0


def _cmd_redescribe(args, config) -> int:
    """公開済み動画の概要欄に、クレジットだけを足す。

    **丸ごと差し替えない。**公開中の動画と手元の台本は尺が違うことがあり、
    章の時刻がずれる（実測 2026-09-06）。足したいのはクレジットだけ。
    """
    from .script_model import parse_script
    from .tts import image_credits, image_details
    from .upload import (UploadError, add_credits, fetch_snippet, get_service,
                         update_description)

    script_path = Path(args.script)
    if not script_path.exists():
        print(f"台本がありません: {script_path}", file=sys.stderr)
        return 1
    script = parse_script(script_path.read_text(encoding="utf-8"))
    top = image_credits(script)
    tail = image_details(script)
    if not top and not tail:
        print("この台本は写真を使っていません")
        return 0

    try:
        service = get_service()
        now = fetch_snippet(service, args.video_id)
    except UploadError as err:
        print(f"取れません: {err}", file=sys.stderr)
        return 1

    before = str(now.get("description") or "")
    after = add_credits(before, top, tail)
    print(f"■ {now.get('title', '')[:40]}")
    if after.strip() == before.strip():
        print("  すでに入っています")
        return 0
    for line in after.split(chr(10)):
        if line and line not in before:
            print(f"    + {line[:88]}")
    if args.dry_run:
        print()
        print("--dry-run なので送っていません")
        return 0
    try:
        update_description(service, args.video_id, after)
    except Exception as err:
        print(f"更新できません: {err}", file=sys.stderr)
        return 1
    print(f"  足しました: https://youtu.be/{args.video_id}")
    return 0


def _cmd_variety(args, config) -> int:
    """その日ぶんを並べて見る。**review は1本ずつしか見ない。**"""
    from .script_model import parse_script
    from .variety import inspect_day

    scripts = []
    for path in args.scripts:
        target = Path(path)
        if not target.exists():
            print(f"台本がありません: {target}", file=sys.stderr)
            return 1
        scripts.append(parse_script(target.read_text(encoding="utf-8")))
    print(f"■ 並べて点検　{len(scripts)}本")
    findings = inspect_day(scripts)
    for finding in findings:
        print(finding.line())
    bad = [f for f in findings if not f.ok]
    if bad:
        print()
        print("  1本ずつの点検では出ません。**似すぎていないか**を見ています")
    return 1 if bad else 0


def _cmd_portrait(args, config) -> int:
    """本人と確認できた顔写真を1枚落とす。**確かめられなければ落とさない。**"""
    from .portrait import PortraitError, save
    from .subjects import SubjectError

    folder = Path(args.dir)
    try:
        entry = save(list(args.names), folder, only=getattr(args, "only", ""),
                     modify=not getattr(args, "whole", False))
    except (PortraitError, SubjectError) as err:
        print(f"取れません: {err}", file=sys.stderr)
        print("  台本の thumbnail_photo は手で用意してください", file=sys.stderr)
        return 1
    if getattr(args, "crop", ""):
        from .portrait import crop_to

        size = crop_to(folder / entry["file"], args.crop)
        print(f"  切り出し: {size[0]}x{size[1]}")
    print(f"■ {folder / entry['file']}")
    print(f"  被写体: {entry['subject_check']}")
    print(f"  出典　: {entry['title']}")
    print(f"  権利　: {entry['license']} / {entry['author']}")
    if entry.get("no_derivatives"):
        print("  ※ 改変不可。**サムネイルと背景には使えません。**"
              "本文に image: で、切らずに出すだけ")
    print(f"  台本に: thumbnail_photo: {folder.as_posix()}/{entry['file']}")
    return 0


def _cmd_subject(args, config) -> int:
    """取った画像に、目的の人物が本当に写っているかを確かめる。

    ファイル名は根拠にならない。実測で、名前がファイル名に入った写真の
    被写体が別人だった。ライセンス判定は OK を返していた。
    """
    import json
    import time

    from . import subjects as subjects_mod
    from .config import _resolve

    ledger = _resolve(args.dir) / "credits.json"
    if not ledger.exists():
        print(f"credits.json がありません: {ledger}", file=sys.stderr)
        return 1

    rows = json.loads(ledger.read_text(encoding="utf-8"))
    rows = rows if isinstance(rows, list) else rows.get("items", [])
    usable = 0
    print(f"■ 被写体の確認　{len(rows)}件　（{' / '.join(args.names)}）")
    for row in rows:
        title = str(row.get("title", ""))
        if not title:
            continue
        # 1件ごとに Commons と Wikidata へ2回聞く。続けて叩くと 429 になる（実測）
        time.sleep(1.0)
        try:
            ok, why = subjects_mod.verify(title, *args.names)
        except subjects_mod.SubjectError as error:
            print(f"  ! {title[:44]}　{error}")
            continue
        print(f"  {'✓' if ok else '×'} {_fit(title, 44)}")
        print(f"      {why}")
        usable += 1 if ok else 0

    print(f"\n{usable}/{len(rows)}件が本人と確かめられました")
    if usable < len(rows):
        print("確かめられなかったものは使わないでください。"
              "ファイル名に名前が入っていても、別人のことがあります")
    return 0 if usable else 1


def _cmd_results(args, config) -> int:
    """試合結果を候補にする。

    フィードは移籍ニュースが中心で、試合結果は数時間で流れ切る。実測で、
    移籍期限の翌日に177件拾って試合結果は0件だった。結果は結果として取る。
    """
    from datetime import date as _date, datetime as _dt, time as _time, timedelta

    from . import collect as collect_mod
    from . import results as results_mod
    from .config import _resolve
    from .plan import load_plan, tokens

    plan = load_plan()
    day = _date.fromisoformat(args.date) if args.date else _date.today() - timedelta(days=1)

    try:
        matches = results_mod.fetch_day(day, plan.leagues)
    except results_mod.ResultsError as error:
        print(f"× {error}", file=sys.stderr)
        return 1

    wanted = [m for m in matches if m.league and (not args.league or m.league == args.league)]
    if not wanted:
        print(f"{day} に、設定しているリーグの試合はありませんでした", file=sys.stderr)
        return 1

    # 試合の中身まで見て、手で立てていたフラグを機械で決める。
    # 1試合ずつ問い合わせるので、--write のときだけ取りに行く
    details = {}
    if args.write:
        for match in wanted:
            try:
                details[match.match_id] = results_mod.fetch_detail(match.match_id)
            except results_mod.ResultsError as error:
                print(f"  ! {match.title()} の中身を取れません: {error}", file=sys.stderr)

    print(f"■ {day} の試合　{len(wanted)}件")
    for match in sorted(wanted, key=lambda m: (m.league, -m.goals)):
        detail = details.get(match.match_id)
        marks = results_mod.flags(match, detail)
        note = ("　" + " ".join(f"[{k}]" for k in marks)) if marks else ""
        best = detail.best if detail else None
        if best:
            note += f"　最高{best[1]}({_fit(best[0], 16)})"
        print(f"  [{plan.league_name(match.league)}] {_fit(match.title(), 40)}　{match.goals}点{note}")

    if not args.write:
        print("\n候補ファイルに書き出すには --write を付けます")
        return 0

    hits = [
        collect_mod.Hit(
            title=f"{m.title()}（{m.competition}）", url=m.url(),
            league=m.league, kind="match",
            flags=results_mod.flags(m, details.get(m.match_id)),
            # 試合の日付は分かっている。空にすると url から割り出せず、
            # 全件が99時間（＝古い扱い）に落ちて新しさの点が付かない
            hours_ago=round(max(0.0, (_dt.now() - _dt.combine(day, _time(21, 0))).total_seconds() / 3600), 1),
        )
        for m in wanted
    ]
    label = tokens(day, 24)["{date_ja}"]
    body = collect_mod.to_yaml(hits, label, merge=False, plan=plan)
    target = _resolve(f"research/{day:%Y%m%d}_results.yaml")
    target.write_text(body, encoding="utf-8")
    print(f"\n候補: {target}")
    print("スコアと得点者は、台本にする段でリーグ公式まで辿ってください")
    return 0


def _host(url: str) -> str:
    """URL からホスト名だけ取り出す。表示用。"""
    from urllib.parse import urlparse

    return (urlparse(url).hostname or url)[:40]


def _cmd_gather(args, config) -> int:
    from datetime import date as _date

    from . import collect as collect_mod
    from . import coverage as coverage_mod
    from . import gather as gather_mod
    from . import lint as lint_mod
    from . import timing
    from .config import _resolve
    from .plan import load_plan, tokens

    plan = load_plan()
    today = _date.fromisoformat(args.date) if args.date else _date.today()

    print(f"■ 収集　{tokens(today, 24)['{date_ja}']}")
    for note in _deadline_notices(plan, today):
        print(f"　{note}")
    for note in timing.advice(plan, _now_on(today)):
        print(f"　{note}")
    print()

    pasted = sys.stdin.read() if args.paste and not sys.stdin.isatty() else ""

    # まとめ集約サイトの一覧。フィードだけでは1日ぶんの材料が足りなかった
    # （2026-09-04 実測。9枠に対して条件を満たす候補が5本）。
    # 取り込み口は貼り付けと同じなので、重複の除去も確度の判定もそのまま効く
    topic_ranks: dict[str, dict] = {}
    if getattr(args, "topics", False):
        from . import topics as topics_mod

        try:
            rows = topics_mod.recent(hours=args.hours)
        except topics_mod.TopicError as error:
            print(f"　まとめ集約サイトを取れません: {error}")
        else:
            listed = topics_mod.lines(rows)
            # 順位と時刻は URL を鍵にして渡す。取り込み口は見出しとURLしか通さない
            topic_ranks = topics_mod.meta(rows)
            head = rows[0] if rows else None
            print(f"　まとめ集約サイトから{len(rows)}件"
                  f"（直近{args.hours:g}時間・人気順）")
            if head:
                print(f"　　一番人気: {head.points}pt　{_fit(head.title, 46)}")
            pasted = f"{pasted}\n{listed}" if pasted.strip() else listed
    # NewsNow。人気の点数は無いが、幅と**リーグの自動判定**を足す
    if getattr(args, "newsnow", False):
        from . import newsnow as newsnow_mod

        try:
            found = newsnow_mod.recent(hours=args.hours, limit=args.newsnow_limit)
        except newsnow_mod.NewsNowError as error:
            print(f"　NewsNow を取れません: {error}")
        else:
            # 取得できないと分かっているサイトは、ここで落とす。
            # 候補に入れても lint が止めるだけで、直す手間が増える
            blocked = [i for i in found if plan.is_blocked(i.url)]
            found = [i for i in found if not plan.is_blocked(i.url)]
            if blocked:
                print(f"　　取得できないサイトを{len(blocked)}件外しました: "
                      + " / ".join(sorted({_host(i.url) for i in blocked}))[:60])
            leagues = sum(1 for i in found if i.league)
            print(f"　NewsNow から{len(found)}件"
                  f"（直近{args.hours:g}時間・うちリーグが分かるもの{leagues}件）")
            block = newsnow_mod.lines(found)
            pasted = f"{pasted}{chr(10)}{block}" if pasted.strip() else block
            topic_ranks.update(newsnow_mod.meta(found))

    haul = gather_mod.run(
        plan,
        topics_meta=topic_ranks,
        hours=args.hours,
        pasted=pasted,
        league=args.league or "",
        covered=coverage_mod.load(plan.coverage.get("ledger", "research/covered.yaml")),
        today=today,
        use_feeds=not args.no_feeds,
    )
    for note in haul.notes:
        print(f"  ! {note}")
    for line in gather_mod.summary(haul):
        print(f"  {line}")

    if not haul.hits:
        print("\n候補になるものがありませんでした", file=sys.stderr)
        return 1

    label = tokens(today, 24)["{date_ja}"]
    body = collect_mod.to_yaml(haul.hits, label, plan=plan)
    bunches = collect_mod.group(haul.hits)

    target = Path(args.out) if args.out else _resolve(
        f"research/{today.strftime('%Y%m%d')}_candidates.yaml"
    )
    if target.exists() and not args.append:
        print(f"\nすでにあります: {target}（足すなら --append）", file=sys.stderr)
        return 1
    target.parent.mkdir(parents=True, exist_ok=True)
    if args.append and target.exists():
        rows = body.split("candidates:\n", 1)[-1]
        with target.open("a", encoding="utf-8") as handle:
            handle.write("\n" + rows)
    else:
        target.write_text(body, encoding="utf-8")

    print(f"\n候補{len(bunches)}件　{target}")
    for bunch in bunches:
        head = bunch[0]
        same = f"　＋{len(bunch) - 1}媒体" if len(bunch) > 1 else ""
        age = f"{head.hours_ago:.0f}時間前" if head.hours_ago >= 0 else (head.posted_on or "—")
        print(f"  {age:12} {_fit(head.title) or '（見出しなし）'}{same}")

    # 埋めるところを、その場で挙げる
    date_label, items = candidates_mod_load(target)
    issues = [i for i in lint_mod.inspect(items, plan) if i.level == "・"]
    if issues:
        print(f"\n埋めるところ {len(issues)}件（tier / topic / league は判断が要ります）")
        for issue in issues[:6]:
            print(issue.line())
    print(f"\n次にこれを打つ:\n  python -m src.cli pick {today_short(target)}")
    return 0


def _cmd_collect(args, config) -> int:
    from datetime import date as _date

    from . import collect as collect_mod
    from . import freshness
    from .config import _resolve
    from .plan import load_plan, tokens

    plan = load_plan()   # 確度の当たりを、情報源の群で置ける上限までに抑えるため
    text = sys.stdin.read()
    hits = collect_mod.enrich(collect_mod.parse(text), freshness.read)
    if not hits:
        print(
            "URLが1つも見つかりませんでした。\n"
            "検索結果を『見出し<タブ>URL』か、見出しの次の行にURL、の形で貼ってください",
            file=sys.stderr,
        )
        return 1

    today = _date.fromisoformat(args.date) if args.date else _date.today()
    label = tokens(today, 24)["{date_ja}"]
    body = collect_mod.to_yaml(hits, label, merge=not args.no_merge, plan=plan)
    bunches = collect_mod.group(hits) if not args.no_merge else [[h] for h in hits]

    target = Path(args.out) if args.out else _resolve(
        f"research/{today.strftime('%Y%m%d')}_candidates.yaml"
    )
    if target.exists() and not args.append:
        print(f"すでにあります: {target}（足すなら --append）", file=sys.stderr)
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)
    if args.append and target.exists():
        # 見出し部分を落として、候補の行だけを足す
        rows = body.split("candidates:\n", 1)[-1]
        with target.open("a", encoding="utf-8") as handle:
            handle.write("\n" + rows)
    else:
        target.write_text(body, encoding="utf-8")

    known = sum(1 for hit in hits if hit.site)
    dated = sum(1 for hit in hits if hit.posted_on)
    print(
        f"{len(hits)}件 → 候補{len(bunches)}件"
        f"　（サイトが分かったもの {known}件 / 日付が読めたもの {dated}件）"
    )
    for bunch in bunches:
        head = bunch[0]
        mark = head.posted_on or (str(head.number) if head.number else "—")
        same = f"　＋{len(bunch) - 1}媒体" if len(bunch) > 1 else ""
        print(f"  {mark:12} {_fit(head.title) or '（見出しなし）'}{same}")
    if args.source_label:
        from . import queries as queries_mod

        queries_mod.record({args.source_label: len(bunches)})
        print(f"『{args.source_label}』から{len(bunches)}件、と記録しました")

    # 網に無いサイトを控える。何度も出るサイトは、たいてい足すべきサイト
    from . import newsites
    from .plan import load_plan

    fresh_hosts = newsites.record([hit.url for hit in hits], load_plan(), today)
    if fresh_hosts:
        print(f"\n網に無いサイト {len(fresh_hosts)}件を控えました: {' / '.join(fresh_hosts[:5])}")
        print("繰り返し出たものは `python -m src.cli sources --new` に挙がります")

    print(f"\n候補ファイル: {target}")
    print("tier / topic / league は判断が要ります。目で見て埋めてください")
    return 0


def _cmd_saga(args, config) -> int:
    from datetime import datetime as _dt

    from . import candidates as candidates_mod
    from . import coverage as coverage_mod
    from . import saga as saga_mod
    from .plan import load_plan

    plan = load_plan()
    date_label, items = candidates_mod.load_candidates(args.candidates)
    entries = coverage_mod.load(plan.coverage.get("ledger", "research/covered.yaml"))
    now = _dt.now()
    found = saga_mod.follow(items, entries, now)

    again = [f for f in found if not f.is_new]
    print(f"■ 続報の見え方　{date_label}　新しい話題 {len(found) - len(again)}件 / 続報 {len(again)}件")
    for item in found:
        print(item.line(now))
        if item.is_new:
            continue
        if item.fresh:
            print(f"      前回のあとに出た出典 {len(item.fresh)}件:")
            for url in item.fresh[:3]:
                print(f"        {url}")
        else:
            print("      前回に無い出典がありません")

    notes = saga_mod.advise(found, now)
    if notes:
        print()
        for note in notes:
            print(f"  ! {note}")
    return 0


def _cmd_lint(args, config) -> int:
    from . import candidates as candidates_mod
    from . import lint as lint_mod
    from .plan import load_plan

    plan = load_plan()
    date_label, items = candidates_mod.load_candidates(args.candidates)
    issues = lint_mod.inspect(items, plan)

    print(f"■ 候補ファイルの点検　{date_label}　{len(items)}件")
    for issue in issues:
        print(issue.line())
    print(f"\n{lint_mod.summarise(issues)}")
    if any(issue.blocking for issue in issues):
        print("× は直してから pick に進んでください", file=sys.stderr)
        return 1
    return 0


def _cmd_pick(args, config) -> int:
    from . import candidates as candidates_mod
    from . import coverage as coverage_mod
    from . import freshness
    from .plan import load_plan

    from . import lint as lint_mod

    plan = load_plan()
    date_label, items = candidates_mod.load_candidates(args.candidates)

    # 綴りを外した項目は既定値に落ちるだけで、黙って効かなくなる。
    # 深掘りの検索を出す前に落とす
    issues = lint_mod.inspect(items, plan)
    blocking = [issue for issue in issues if issue.blocking]
    if blocking:
        print(f"■ 候補ファイルに直すところがあります　{len(blocking)}件")
        for issue in blocking:
            print(issue.line())
        print("\n`python -m src.cli lint <候補file>` で全部見られます", file=sys.stderr)
        return 1
    for issue in issues:
        if issue.level == "!":
            print(issue.line())

    # hours_ago を書いていない候補は、url から割り出す
    observations = freshness.load(freshness.LEDGER)

    def age_of(url: str):
        ref = freshness.read(url)
        return freshness.hours_ago(ref, observations) if ref.known else None

    for note in candidates_mod.fill_ages(items, age_of):
        print(f"! {note}")

    ranked = candidates_mod.score(items, plan.scoring)

    # 1日に何本も出すと、朝に出した話が夜にまた上がってくる。記録と突き合わせて外す
    ledger = coverage_mod.load(plan.coverage.get("ledger", "research/covered.yaml"))
    covered = coverage_mod.duplicates(
        ledger,
        [c.id for c in ranked],
        int(plan.coverage.get("repeat_within_hours", 36)),
    )
    ranked, dropped = candidates_mod.exclude_covered(ranked, covered)

    # 続報かどうかは点数に出ない。同じ話を同じ材料で二度出さないよう、印を付ける
    from datetime import datetime as _dt

    from . import saga as saga_mod

    now = _dt.now()
    threads = {f.candidate.id: f for f in saga_mod.follow(ranked, ledger, now)}

    print(f"■ 候補の採点　{date_label}　{len(ranked)}件")
    for item in ranked:
        detail = " ".join(f"{k}+{v}" for k, v in item.breakdown.items()) or "加点なし"
        thread = threads.get(item.id)
        mark = ""
        if thread and not thread.is_new:
            gap = thread.hours_since(now) or 0.0
            span = f"{gap / 24:.0f}日前" if gap >= 24 else f"{gap:.0f}時間前"
            mark = f"　［続報 {len(thread.past) + 1}本目・前回{span}］"
        print(f"  {item.score:2d}点  {_fit(item.title)}　［{item.tier}／{item.hours_ago:g}時間前］{mark}")
        print(f"        {detail}")
    for item in dropped:
        entry = covered[item.id]
        print(f"  ーー　{_fit(item.title)}　（{entry.slot}で既出 {entry.at:%m/%d %H:%M}）")
    print()

    for note in saga_mod.advise(list(threads.values()), now):
        print(f"  ! {note}")

    chosen, fallbacks = candidates_mod.assign(ranked, plan.scoring, plan.slots)

    for slot in plan.slots:
        pick = chosen.get(slot)
        routine = plan.routines.get(slot)
        name = routine.name if routine else slot
        if pick is None:
            # 空けた理由が分かっているなら、それを出す。「候補がありません」
            # だけだと、下限で見送ったのか本当に無いのかが区別できない
            why = fallbacks.get(slot) or []
            if why:
                print(f"■ {name}: 見送りました　{why[0]}")
            else:
                print(f"■ {name}: 割り当てる候補がありません")
            continue
        print(f"■ {name} → {pick.title}（{pick.score}点）")
        for reason in fallbacks.get(slot, []):
            print(f"   ! {reason}。枠の狙いから外れた候補を入れています")
        entry = plan.league(pick.league)
        official = [str(h) for h in (entry.get("official") or [])]
        media = plan.domains.get(str(entry.get("media")), [])
        for query in candidates_mod.deep_queries(
            pick, plan.deep, plan.domains,
            league_official=official, league_media=media,
            match_q=str(entry.get("match_q") or ""),
        ):
            line = f'   {query["label"]}: "{query["q"]}"'
            if query["domains"]:
                line += f"  （{', '.join(query['domains'])} に限定）"
            print(line)
        print(f"   取材メモ: python -m src.cli plan --routine {slot} --write")
        print()
    return 0


def _cmd_draft(args, config) -> int:
    from .config import _resolve
    from .plan import load_plan
    from . import coverage as coverage_mod
    from .research import advise, check_repeats, load_notes, to_script, verify

    plan = load_plan()
    notes = load_notes(args.notes)

    problems = verify(notes, plan)
    if problems:
        print("取材メモに不備があります:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    repeats = check_repeats(notes, plan)
    if repeats:
        label = "警告" if args.allow_repeat else "重複しています"
        print(f"{label}:", file=sys.stderr)
        for problem in repeats:
            print(f"  - {problem}", file=sys.stderr)
        if not args.allow_repeat:
            return 1

    print(
        f"検証OK: 節 {len(notes.sections)}つ / 出典 {len(notes.sources)}本"
        f"\n  タイトル: {notes.video_title}\n  問い　　: {notes.question}"
    )
    for note in advise(notes, plan):
        print(f"  ヒント: {note}")
    if args.check_only:
        return 0

    target = Path(args.out) if args.out else _resolve(
        f"scripts/{Path(args.notes).stem}.md"
    )
    if target.exists():
        print(f"すでにあります: {target}", file=sys.stderr)
        return 1
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(to_script(notes, plan), encoding="utf-8")

    # 扱った話題を記録して、次の枠で繰り返さないようにする
    ledger = (plan.coverage or {}).get("ledger")
    if ledger:
        coverage_mod.record(
            ledger, notes.slot or "-", [(notes.theme_id, notes.title)],
            league=notes.league, kind=notes.kind,
            topic=notes.topic, sources=notes.sources,
        )
    print(f"台本: {target}")
    print(f"`python -m src.cli check {target}` で書式と尺を確認してください")
    return 0


def _cmd_new(args, config) -> int:
    from datetime import date as _date

    from .config import _resolve

    template = _resolve(f"scripts/templates/{args.template}.md")
    if not template.exists():
        print(f"テンプレートがありません: {template}", file=sys.stderr)
        return 1

    today = _date.today()
    stamp = args.date or f"{today.year}年{today.month}月{today.day}日"
    target = _resolve(f"scripts/{args.name or today.strftime('%Y%m%d')}.md")
    if target.exists():
        print(f"すでにあります: {target}", file=sys.stderr)
        return 1

    text = template.read_text(encoding="utf-8")
    text = text.replace("{{DATE}}", stamp)
    text = text.replace("{{DATE_SHORT}}", f"{today.month}/{today.day}")
    target.write_text(text, encoding="utf-8")
    print(f"下書き: {target}")
    print("{{...}} を埋めてから `python -m src.cli check` で確認してください")
    return 0


def _cmd_make_clip(args, config) -> int:
    from . import ffmpeg
    from .config import _resolve

    source = _resolve(args.image)
    if not source.exists():
        print(f"画像がありません: {source}", file=sys.stderr)
        return 1
    out = Path(args.out) if args.out else _resolve(f"assets/backgrounds/{source.stem}.mp4")
    out.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg.still_to_clip(
        source, out, args.seconds,
        (config.video.width, config.video.height), args.zoom, config.video.fps,
    )
    # 元画像との対応を残す。クリップにすると名前が変わり、CC BY のクレジットを
    # 引けなくなる（表示しないと利用条件を満たさない）
    out.with_suffix(out.suffix + ".source.txt").write_text(
        source.name, encoding="utf-8"
    )
    print(f"クリップ: {out}")
    # 台本には相対パスで書く。絶対パスを書いた台本は、他のPCで開けなくなる
    try:
        hint = out.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        hint = str(out)
    print(f"台本の frontmatter に  bg: {hint}  と書けば背景に使えます")
    return 0


def _cmd_upload(args, config) -> int:
    from datetime import timedelta, timezone

    from . import posted
    from . import upload as upload_mod

    nl = chr(10)   # heredoc 経由だとバックスラッシュが化ける
    JST = timezone(timedelta(hours=9))

    build_dir = Path(args.build_dir)

    # **同じ動画を二度上げない。**2026-09-07 に、投稿処理がまだ走っている
    # 最中に2本目を起こして本編4本を重複公開し、その分で本数の上限を
    # 使い切った。人の注意では防げないので、投稿する側に控えを持たせる。
    seen = posted.find(build_dir)
    if seen and not args.again:
        print("■ この出力先はすでに投稿しています　" + str(build_dir))
        print("  https://youtu.be/" + seen["video_id"] + "　" + seen["at"])
        print(nl + "二重投稿を止めました。別の投稿処理が走っていないか確かめてください。",
              file=sys.stderr)
        print("本当に上げ直すなら --again を付けます", file=sys.stderr)
        return 1

    draft = upload_mod.prepare(build_dir, args.privacy)

    print(f"■ 投稿の中身　{build_dir}")
    for line in draft.lines():
        print(f"  {line}")

    problems = draft.problems
    if problems:
        print()
        for note in problems:
            print(f"  × {note}")
        print("\n直してから投稿してください", file=sys.stderr)
        return 1

    if args.dry_run:
        print("\n--dry-run なので送っていません。"
              "この内容でよければ --dry-run を外してください")
        return 0

    video_id = upload_mod.upload(
        draft.video,
        draft.title,
        draft.description,
        tags=draft.tags,
        privacy=draft.privacy,
        thumbnail=draft.thumbnail,
    )
    posted.record(build_dir, video_id)
    print(f"\n投稿しました: https://youtu.be/{video_id} ({draft.privacy})")
    # **上限の本数は分からない**ので、残りではなく「上げた本数」を出す。
    n = posted.today()
    if n >= posted.SOFT_MAX - 3:
        back = posted.frees_at().astimezone(JST)
        print(f"  枠が戻ってから {n} 本目。この辺りで弾かれることがある"
              f"（次に枠が戻るのは {back:%m/%d %H:%M} JST）")
    return 0


# サブコマンド名 → 処理。main() の add_parser と1対1で対応する。
HANDLERS = {
    "init-assets": _cmd_init_assets,
    "speakers": _cmd_speakers,
    "check": _cmd_check,
    "build": _cmd_build,
    "short": _cmd_short,
    "reactions": _cmd_reactions,
    "handoff": _cmd_handoff,
    "stock": _cmd_stock,
    "review": _cmd_review,
    "contact": _cmd_contact,
    "thumbnail": _cmd_thumbnail,
    "plan": _cmd_plan,
    "scan": _cmd_scan,
    "clubs": _cmd_clubs,
    "today": _cmd_today,
    "stats": _cmd_stats,
    "queries": _cmd_queries,
    "doctor": _cmd_doctor,
    "sources": _cmd_sources,
    "fresh": _cmd_fresh,
    "x": _cmd_x,
    "fetch": _cmd_fetch,
    "subject": _cmd_subject,
    "variety": _cmd_variety,
    "redescribe": _cmd_redescribe,
    "setthumb": _cmd_setthumb,
    "publish": _cmd_publish,
    "quota": _cmd_quota,
    "portrait": _cmd_portrait,
    "results": _cmd_results,
    "gather": _cmd_gather,
    "collect": _cmd_collect,
    "saga": _cmd_saga,
    "lint": _cmd_lint,
    "pick": _cmd_pick,
    "draft": _cmd_draft,
    "new": _cmd_new,
    "make-clip": _cmd_make_clip,
    "upload": _cmd_upload,
}


def _dispatch(args, config) -> int:
    """サブコマンドに応じた処理を呼ぶ。

    知らないコマンドと、途中で return せずに抜けた処理は 1 を返す。
    切り出す前は最後まで落ちて `return 1` に着いていたので、それに合わせる。
    """
    handler = HANDLERS.get(args.command)
    if handler is None:
        return 1
    code = handler(args, config)
    return 1 if code is None else code


if __name__ == "__main__":
    raise SystemExit(main())
