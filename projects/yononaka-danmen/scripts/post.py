# -*- coding: utf-8 -*-
"""YouTube へ予約投稿する（チャンネル「日本のなぜ」）。

**歴史の地層（projects/rekishi-chiso/chiso/cli.py）の投稿まわりを写した。**
向こうで踏んで直したことが全部入っている。

    python scripts/post.py whoami                         # どのチャンネルに繋がっているか
    python scripts/post.py reauth                         # 許可を取り直す（ブラウザが開く）
    python scripts/post.py screen 台本.yaml                # 動画を見せた控え（**関門**）
    python scripts/post.py upload 台本.yaml --at "2026-10-09 19:00"
    python scripts/post.py describe 台本.yaml              # 概要欄の文面だけ見る

**関門を外さない。** upload は、動画をユーザーに見せて OK をもらい `screen` を打った
控え（approvals/<台本>.screened.json）が無いと動かない。動画を作り直すと
sha256 が変わるので、確認もやり直しになる。

**チャンネルの取り違えを機械で止める。** 2026-10-08、Studio を開いたら「歴史の地層」の
カスタマイズ画面が出て、危うくそちらのアイコンを差し替えるところだった。
`_service` が、許可したチャンネルの名前に「日本のなぜ」が入っているかを毎回確かめる。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import upload as up  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(r"C:/Users/なみ/dev/output/yononaka-danmen")
APPROVALS = ROOT / "approvals"
POSTED = ROOT / "posted.json"
CHANNEL = "日本のなぜ"
TAGS = ["ニュース解説", "なぜ", "日本", "数字", "制度", "解説", "社会", "経済"]


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def video_of(path: Path) -> Path:
    return OUT / "{}.mp4".format(path.stem)


def screened_path(path: Path) -> Path:
    return APPROVALS / "{}.screened.json".format(path.stem)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def description(sc: dict) -> str:
    """概要欄。**出典を必ず載せる**（このチャンネルの決まり）。"""
    lines = [str(sc.get("question", "")).strip(), ""]
    body = []
    for sec in sc.get("sections", []):
        name = str(sec.get("name", "")).strip()
        if name:
            body.append("・{}".format(name))
    if body:
        lines += ["この回で見ること"] + body + [""]
    src = [str(s) for s in sc.get("sources", []) if str(s).strip()]
    if src:
        lines += ["出典"] + ["・{}".format(s) for s in src] + [""]
    when = str(sc.get("date", "")).strip()
    if when:
        lines += ["価格・数字は {} 時点のものです。".format(when), ""]
    lines += ["図はすべて自作です。", "運営：のこぎり社"]
    return "\n".join(lines).strip()


def _service(need_manage: bool = False):
    """許可を読み、**チャンネルが「日本のなぜ」かを確かめる**。違えば止める。"""
    try:
        svc = up.service(need_manage=need_manage)
    except up.NeedConsent as err:
        print(str(err))
        return None
    name = up.channel_title(svc)
    if CHANNEL not in name:
        print("許可しているチャンネルが違います: {}\n".format(name) + up.REAUTH)
        return None
    print("  チャンネル：{}".format(name))
    return svc


def cmd_whoami(args) -> int:
    svc = _service()
    return 0 if svc is not None else 2


def cmd_reauth(args) -> int:
    backup = up.reauth()
    if backup:
        print("古い許可は {} に残しました".format(backup.name))
    print("許可を取り直しました")
    return 0


def cmd_describe(args) -> int:
    print(description(load(Path(args.script))))
    return 0


def cmd_screen(args) -> int:
    """**本番の動画をユーザーが見て OK と言ったときだけ打つ。**"""
    path = Path(args.script)
    video = video_of(path)
    if not video.exists():
        print("本番の動画がありません: {}".format(video))
        return 1
    APPROVALS.mkdir(parents=True, exist_ok=True)
    screened_path(path).write_text(
        json.dumps({"video": video.name, "sha256": sha256(video)}, ensure_ascii=False) + "\n",
        encoding="utf-8")
    print("動画の確認を控えました: {}（動画を作り直したら確認し直し）".format(screened_path(path).name))
    return 0


def cmd_upload(args) -> int:
    path = Path(args.script)
    sc = load(path)
    video = video_of(path)
    a = screened_path(path)
    if not a.exists() or not video.exists() or \
            json.loads(a.read_text(encoding="utf-8"))["sha256"] != sha256(video):
        print("本番の動画をユーザーに見せて OK をもらってから screen してください"
              "（動画を作り直したら確認し直し）")
        return 2
    key = "{}:main".format(path.stem)
    done = up.already_posted(POSTED, key)
    if done:
        print("もう投稿してあります: https://youtu.be/{}（{}）".format(done["video_id"], done["publish_at"]))
        return 1
    publish_at = up.publish_time(args.at)
    title = str(sc.get("title", "")).strip()
    if not title:
        print("台本に title がありません")
        return 2
    tags = list(dict.fromkeys(TAGS + [str(t) for t in sc.get("tags", [])]))
    thumb = OUT / "{}_thumbnail.png".format(path.stem)
    svc = _service()
    if svc is None:
        return 2
    print("投稿します：{}".format(title))
    print("  公開 {}（日本時間）".format(args.at))
    vid = up.upload(svc, video, title, description(sc), tags, publish_at,
                    thumb if thumb.exists() else None)
    up.record(POSTED, {"key": key, "video_id": vid, "title": title, "publish_at": args.at})
    print("予約しました: https://youtu.be/{}".format(vid))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="YouTube へ予約投稿する（日本のなぜ）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("whoami").set_defaults(fn=cmd_whoami)
    sub.add_parser("reauth").set_defaults(fn=cmd_reauth)
    s = sub.add_parser("describe"); s.add_argument("script"); s.set_defaults(fn=cmd_describe)
    s = sub.add_parser("screen"); s.add_argument("script"); s.set_defaults(fn=cmd_screen)
    s = sub.add_parser("upload")
    s.add_argument("script")
    s.add_argument("--at", required=True, help="公開時刻 'YYYY-MM-DD HH:MM'（日本時間・9〜24時）")
    s.set_defaults(fn=cmd_upload)
    args = ap.parse_args()
    try:
        return int(args.fn(args))
    except up.UploadError as err:
        print("！ {}".format(err))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
