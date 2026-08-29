"""コマンドラインから台本→動画を作る。

    python -m src.cli init-assets              仮の背景・立ち絵を生成
    python -m src.cli speakers                 VOICEVOX の話者/スタイルID一覧
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
from .subtitles import chapters, _clock
from .thumbnail import build_thumbnail


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
    p_build.add_argument("--keep-work", action="store_true", help="中間フレームを残す")

    p_thumb = sub.add_parser("thumbnail", help="サムネイルだけ作り直す")
    p_thumb.add_argument("script")
    p_thumb.add_argument("--out", default=None)

    p_upload = sub.add_parser("upload", help="ビルド結果を YouTube に投稿する")
    p_upload.add_argument("build_dir", help="build の出力ディレクトリ")
    p_upload.add_argument("--privacy", default="private", choices=["private", "unlisted", "public"])

    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
        return _dispatch(args, config)
    except (ConfigError, ScriptError) as exc:
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
        from .tts import VoicevoxClient

        client = VoicevoxClient(config.voicevox.url, config.voicevox.timeout)
        if not client.available():
            print(
                f"VOICEVOX ENGINE に接続できません: {config.voicevox.url}\n"
                "VOICEVOX アプリを起動してから実行してください。",
                file=sys.stderr,
            )
            return 1
        for speaker in client.speakers():
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
        ensure_assets(config)
        result = build(
            args.script,
            config,
            out_dir=Path(args.out) if args.out else None,
            use_tts=not args.no_tts,
            keep_work=args.keep_work,
        )
        if not result.used_voicevox:
            print("※ VOICEVOX に接続できなかったため無音で書き出しました（尺確認用）")
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
