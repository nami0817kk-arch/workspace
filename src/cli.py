"""コマンドラインから台本→動画を作る。

    python -m src.cli init-assets              仮の背景・立ち絵を生成
    python -m src.cli speakers                 VOICEVOX の話者/スタイルID一覧
    python -m src.cli build <台本> --backend core   合成方式を明示する
    python -m src.cli make-clip <画像>         静止画から背景クリップを作る
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

    p_thumb = sub.add_parser("thumbnail", help="サムネイルだけ作り直す")
    p_thumb.add_argument("script")
    p_thumb.add_argument("--out", default=None)

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
    except (ConfigError, ScriptError, TtsError) as exc:
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

    if args.command == "thumbnail":
        script = load_script(args.script)
        out = Path(args.out) if args.out else Path(f"output/{Path(args.script).stem}/thumbnail.png")
        path = build_thumbnail(
            config,
            script.meta.get("thumbnail_title", script.title),
            out,
            subtitle=str(script.meta.get("thumbnail_subtitle", "")),
        )
        print(f"サムネ: {path}")
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
