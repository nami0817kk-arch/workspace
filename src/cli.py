"""コマンドラインから台本→動画を作る。

    python -m src.cli init-assets              仮の背景・立ち絵を生成
    python -m src.cli speakers                 VOICEVOX の話者/スタイルID一覧
    python -m src.cli build <台本> --backend core   合成方式を明示する
    python -m src.cli make-clip <画像>         静止画から背景クリップを作る
    python -m src.cli scan                     候補テーマを拾う検索リスト
    python -m src.cli pick research/x.yaml     候補を採点して枠に割り振る
    python -m src.cli x                        記者Xアカウントの検索リスト
    python -m src.cli fresh <URL>...           拾ったURLの新しさを判定
    python -m src.cli sources                  情報源の網と確度の上限
    python -m src.cli review scripts/x.md      公開前の点検
    python -m src.cli plan                     枠ごとの取材リストを出す
    python -m src.cli draft research/x.yaml    取材メモを検証して台本にする
    python -m src.cli new                      テンプレートから台本の下書きを作る
    python -m src.cli check scripts/sample.md  台本の書式と想定尺だけ確認
    python -m src.cli build scripts/sample.md  動画・字幕・サムネを書き出し
    python -m src.cli upload output/sample     出来上がりを YouTube に投稿
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .assets import ensure_assets
from .config import ConfigError, load_config
from .pipeline import build
from .plan import PlanError
from .research import ResearchError
from .script_model import ScriptError, load_script
from .thumbnail import build_thumbnail
from .tts import TtsError


def main(argv: list[str] | None = None) -> int:
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

    p_review = sub.add_parser("review", help="書き出したものを公開前に点検する")
    p_review.add_argument("script")
    p_review.add_argument("--out", default=None, help="出力先（既定: output/<台本名>）")

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
    p_plan.add_argument(
        "--league", default=None,
        help="match ルーティンで、どのリーグの試合かを指定する（england / spain / germany など）",
    )

    p_scan = sub.add_parser("scan", help="候補テーマを拾うための検索リストを出す")
    p_scan.add_argument("--date", default=None, help="基準日 YYYY-MM-DD（既定: 今日）")
    p_scan.add_argument("--write", action="store_true", help="候補ファイルの雛形を作る")

    p_pick = sub.add_parser("pick", help="候補を採点して枠に割り振り、深掘りの検索を出す")
    p_pick.add_argument("candidates")

    sub.add_parser("sources", help="情報源の網と、群ごとに置ける確度を表示する")

    p_fresh = sub.add_parser("fresh", help="検索で拾ったURLの新しさを判定する")
    p_fresh.add_argument("urls", nargs="*", help="URL。省略すると標準入力から読む")
    p_fresh.add_argument("--no-record", action="store_true", help="索引の記録を更新しない")

    p_x = sub.add_parser("x", help="記者Xアカウントの検索リスト／投稿URLの確認")
    p_x.add_argument("urls", nargs="*", help="投稿URL。省略すると検索リストを出す")
    p_x.add_argument("--topic", default=None, help="この語で各アカウントを検索する")

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

    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
        return _dispatch(args, config)
    except (ConfigError, ScriptError, TtsError, PlanError, ResearchError) as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1


def _dispatch(args, config) -> int:
    if args.command == "init-assets":
        created = ensure_assets(config, force=args.force)
        print(f"生成: {len(created)} ファイル" if created else "不足している素材はありません")
        for path in created[:6]:
            print(f"  {path}")
        if len(created) > 6:
            print(f"  ... 他 {len(created) - 6} 件")
        return 0

    if args.command == "speakers":
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

    if args.command == "check":
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

    if args.command == "build":
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

    if args.command == "review":
        from .review import built_duration, inspect, manual_checks

        script = load_script(args.script)
        out = Path(args.out) if args.out else Path(f"output/{Path(args.script).stem}")
        duration = built_duration(out)

        print(f"■ 公開前の点検　{script.title}")
        findings = inspect(script, out, duration)
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

    if args.command == "thumbnail":
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
                subtitle=look["subtitle"], background=script.background,
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

    if args.command == "plan":
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
            target.write_text(worksheet(routine, today), encoding="utf-8")
            print(f"取材メモ: {target}")
            print(f"埋めたら `python -m src.cli draft {target}` で台本になります")
        return 0

    if args.command == "scan":
        from datetime import date as _date

        from . import candidates as candidates_mod
        from .config import _resolve
        from .plan import load_plan, tokens

        plan = load_plan()
        today = _date.fromisoformat(args.date) if args.date else _date.today()
        words = tokens(today, 24)
        scan = plan.scan

        print(f"■ 候補スキャン　{words['{date_ja}']}")
        if scan.get("when"):
            print(f"　目安の時刻: {scan['when']}")
        print()
        number = 0
        for item in scan.get("queries") or []:
            label = str(item.get("label", ""))

            # per_league の行は、追っているリーグのぶんに展開する。
            # 全リーグまとめて1本で引くと、どの試合の記事か分からないまま返ってくる
            if item.get("per_league"):
                for key in scan.get("match_leagues") or []:
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

    if args.command == "sources":
        from datetime import date as _date

        from .plan import load_plan

        plan = load_plan()
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

    if args.command == "fresh":
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

        ledger = "research/freshness.yaml"
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
                path = freshness.save(ledger, updated)
                print(f"索引の記録を更新しました: {path}")
            else:
                print("索引は前回から進んでいません（記録は変えていません）")
        return 0

    if args.command == "x":
        from . import xposts
        from .plan import load_plan

        plan = load_plan()
        stale = int(plan.social.get("stale_hours", 24))

        backend = str(plan.social.get("backend", "search"))

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
            lag = int(plan.social.get("stale_hours", 72))
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
            for problem in xposts.review(url, plan.accounts, stale):
                print(f"    ! {problem}")
        return 0

    if args.command == "pick":
        from . import candidates as candidates_mod
        from . import coverage as coverage_mod
        from . import freshness
        from .plan import load_plan

        plan = load_plan()
        date_label, items = candidates_mod.load_candidates(args.candidates)

        # hours_ago を書いていない候補は、url から割り出す
        observations = freshness.load("research/freshness.yaml")

        def age_of(url: str):
            ref = freshness.read(url)
            return freshness.hours_ago(ref, observations) if ref.known else None

        for note in candidates_mod.fill_ages(items, age_of):
            print(f"! {note}")

        ranked = candidates_mod.score(items, plan.scoring)

        # 1日3本だと、朝に出した話が夜にまた上がってくる。記録と突き合わせて外す
        ledger = coverage_mod.load(plan.coverage.get("ledger", "research/covered.yaml"))
        covered = coverage_mod.duplicates(
            ledger,
            [c.id for c in ranked],
            int(plan.coverage.get("repeat_within_hours", 36)),
        )
        ranked, dropped = candidates_mod.exclude_covered(ranked, covered)

        print(f"■ 候補の採点　{date_label}　{len(ranked)}件")
        for item in ranked:
            detail = " ".join(f"{k}+{v}" for k, v in item.breakdown.items()) or "加点なし"
            print(f"  {item.score:2d}点  {item.title}　［{item.tier}／{item.hours_ago:g}時間前］")
            print(f"        {detail}")
        for item in dropped:
            entry = covered[item.id]
            print(f"  ーー　{item.title}　（{entry.slot}で既出 {entry.at:%m/%d %H:%M}）")
        print()

        chosen, fallbacks = candidates_mod.assign(ranked, plan.scoring, plan.slots)

        for slot in plan.slots:
            pick = chosen.get(slot)
            routine = plan.routines.get(slot)
            name = routine.name if routine else slot
            if pick is None:
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

    if args.command == "draft":
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
                ledger, notes.slot or "-", [(notes.theme_id, notes.title)]
            )
        print(f"台本: {target}")
        print(f"`python -m src.cli check {target}` で書式と尺を確認してください")
        return 0

    if args.command == "new":
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

    if args.command == "make-clip":
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
        print(f"クリップ: {out}")
        print(f"台本の frontmatter に  bg: {out}  と書けば背景に使えます")
        return 0

    if args.command == "upload":
        from .upload import upload

        build_dir = Path(args.build_dir)
        video = build_dir / "video.mp4"
        description_file = build_dir / "description.txt"
        if not video.exists():
            print(f"動画がありません: {video}", file=sys.stderr)
            return 1
        text = description_file.read_text(encoding="utf-8") if description_file.exists() else ""
        title, _, body = text.partition("\n")
        video_id = upload(
            video,
            title.strip() or build_dir.name,
            body.strip(),
            privacy=args.privacy,
            thumbnail=build_dir / "thumbnail.png",
        )
        print(f"投稿しました: https://youtu.be/{video_id} ({args.privacy})")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
