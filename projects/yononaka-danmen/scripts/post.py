# -*- coding: utf-8 -*-
"""YouTube へ予約投稿する（チャンネル「日本のなぜ」）。

**歴史の地層（projects/rekishi-chiso/chiso/cli.py）の投稿まわりを写した。**
向こうで踏んで直したことが全部入っている。

    python scripts/post.py whoami                         # どのチャンネルに繋がっているか
    python scripts/post.py reauth                         # 許可を取り直す（ブラウザが開く）
    python scripts/post.py screen 台本.yaml                # 動画を見せた控え（**関門**）
    python scripts/post.py upload 台本.yaml --at "2026-10-09 19:00"
    python scripts/post.py describe 台本.yaml              # 概要欄の文面だけ見る
    python scripts/post.py thumb-set 台本.yaml             # 投稿済みの動画のサムネイルを差し替える
    python scripts/post.py screen-shorts 台本.yaml         # ショートを見せた控え（**関門**）
    python scripts/post.py upload-shorts 台本.yaml --from "2026-10-10 21:00"   # ショートを枠に順に予約

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


PHOTO_DIR = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/photos")


def photo_keys(sc: dict) -> list[str]:
    """台本で使っている写真の名前（サムネ・節・図）。"""
    keys = [(sc.get("thumbnail") or {}).get("photo")]
    for sec in sc.get("sections", []):
        keys.append(sec.get("photo"))
        for fig in [sec.get("figure") or {}] + list(sec.get("more") or []):
            keys.append(fig.get("photo"))
    out = []
    for k in keys:
        k = str(k or "").strip()
        if k and k != "なし" and k not in out:
            out.append(k)
    return out


def photo_credits(sc: dict) -> list[str]:
    """**作者名の表示が要る写真**（CC BY・CC BY-SA）を「題・作者・ライセンス」で返す。
    2026-10-10 に足した。それまで概要欄に写真の作者を出しておらず、CC BY の写真が無表示だった。
    Pexels は表示不要なので出さない。"""
    # 控えは2か所ある（fetch_assets が書く credits.json と、手で取ったときの sources.json）。両方を見る
    cred = []
    try:
        cred += json.loads((PHOTO_DIR / "credits.json").read_text(encoding="utf-8"))
    except FileNotFoundError:
        pass
    try:
        for c in json.loads((PHOTO_DIR.parent / "sources.json").read_text(encoding="utf-8")):
            cred.append({"file": c.get("file"), "source": c.get("site"), "title": c.get("title"),
                         "creator": c.get("author"), "license": c.get("license")})
    except (FileNotFoundError, AttributeError):
        pass
    out = []
    for k in photo_keys(sc):
        for c in cred:
            f = str(c.get("file", ""))
            if str(k).lower() not in f.lower() or c.get("source") == "pexels":
                continue
            lic = str(c.get("license", ""))
            if lic.upper().startswith("CC0") or "public domain" in lic.lower():
                continue
            title = str(c.get("title", "")).rsplit(".", 1)[0]
            # 出典の欄に手で書いてある写真は出さない（カルテルの回は sources: に入れてあり、二重に出た）
            if any(title and title in str(src) for src in sc.get("sources", [])):
                break
            line = "・{}／{}／{}（Wikimedia Commons）".format(title, c.get("creator") or "作者不明", lic)
            if line not in out:
                out.append(line)
            break
    return out


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
    # 声のクレジット（VOICEVOX:剣崎雌雄 は規約で必須）。config.yaml の credit から
    try:
        cfg = yaml.safe_load((ROOT / "config.yaml").read_text(encoding="utf-8"))
        credits = [str(p["credit"]) for p in cfg.get("cast", {}).values() if p.get("credit")]
    except FileNotFoundError:
        credits = []
    if credits:
        lines += ["声：" + "、".join(credits), ""]
    pc = photo_credits(sc)
    if pc:
        lines += ["写真"] + pc + [""]
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
    # **作り直した版は --remake で別の控えにする**（2026-10-10、カルテルの回を組み直して出し直した）。
    # 同じ台本の二重投稿は、版ごとに止まる
    key = "{}:main".format(path.stem) + (":{}".format(args.remake) if getattr(args, "remake", None) else "")
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


def cmd_thumb_set(args) -> int:
    """投稿済みの動画のサムネイルを差し替える（台本からサムネイルを作り直してから）。"""
    path = Path(args.script)
    done = up.already_posted(POSTED, "{}:main".format(path.stem))
    if not done:
        print("まだ投稿していません")
        return 1
    thumb = OUT / "{}_thumbnail.png".format(path.stem)
    if not thumb.exists():
        print("サムネイルがありません: {}".format(thumb))
        return 1
    svc = _service()
    if svc is None:
        return 2
    svc.thumbnails().set(videoId=done["video_id"], media_body=str(thumb)).execute()
    print("サムネイルを差し替えました: https://youtu.be/{}".format(done["video_id"]))
    return 0


def cmd_desc_set(args) -> int:
    """投稿済みの本編の概要欄を、今の台本から作り直して差し替える（題名・タグ・公開設定は触らない）。
    2026-10-10、公開済みのカルテルの回に写真の作者名を足すために作った。"""
    path = Path(args.script)
    sc = load(path)
    # 作り直した回は「:main:v2」で控えてある。**いちばん新しい版**に当てる（古い版は非公開にしてある）
    key = "{}:main".format(path.stem)
    log = json.loads(POSTED.read_text(encoding="utf-8")) if POSTED.exists() else []
    hits = [e for e in log if e.get("key") == key or str(e.get("key", "")).startswith(key + ":v")]
    if not hits:
        print("まだ投稿していません")
        return 1
    done = hits[-1]
    svc = _service(need_manage=True)
    if svc is None:
        return 2
    vid = done["video_id"]
    items = svc.videos().list(part="snippet", id=vid).execute().get("items", [])
    if not items:
        print("動画が見つかりません: {}".format(vid))
        return 1
    sn = items[0]["snippet"]
    new = description(sc)
    if sn.get("description", "") == new:
        print("概要欄は今のままで同じです")
        return 0
    body = {"id": vid, "snippet": {"title": sn["title"], "categoryId": sn["categoryId"],
                                   "description": new, "tags": sn.get("tags", []),
                                   "defaultLanguage": sn.get("defaultLanguage", "ja")}}
    svc.videos().update(part="snippet", body=body).execute()
    print("概要欄を差し替えました: https://youtu.be/{}".format(vid))
    return 0


SHORTS_DIR = OUT / "shorts"
# ショートの公開時刻（CLAUDE.md「出す時間」。9時より前には出さない）
SHORT_HOURS = [9, 11, 12, 13, 16, 17, 18, 19, 20, 21]   # 2026-10-10 ユーザー指示


def short_video(path: Path, sid: str) -> Path:
    return SHORTS_DIR / "{}_short_{}.mp4".format(path.stem, sid)


def short_ids(sc: dict) -> list[str]:
    return [k for k in (sc.get("shorts") or {}) if k not in ("intro", "top")]


def short_title(spec: dict) -> str:
    return "{} #shorts".format(str(spec.get("title", "")).replace("／", " ").strip())


def short_description(sc: dict, spec: dict) -> str:
    """ショートの概要欄。**リンクは貼らない**（CLAUDE.md。内容で本編へ引っぱる）。本編の題名だけ書く。"""
    lines = [str(spec.get("tease", "")).replace("／", ""), "",
             "答えは本編「{}」で。".format(str(sc.get("title", "")).strip()), ""]
    src = [str(s) for s in sc.get("sources", []) if str(s).strip()]
    if src:
        lines += ["出典（本編と同じ）"] + ["・{}".format(s) for s in src] + [""]
    pc = photo_credits(sc)          # 出典の欄に無い写真の作者名（CC BY は表示が条件）
    if pc:
        lines += ["写真"] + pc + [""]
    try:
        cfg = yaml.safe_load((ROOT / "config.yaml").read_text(encoding="utf-8"))
        credits = [str(p["credit"]) for p in cfg.get("cast", {}).values() if p.get("credit")]
    except FileNotFoundError:
        credits = []
    if credits:
        lines += ["声：" + "、".join(credits), ""]
    lines += ["運営：のこぎり社", "#shorts"]
    return "\n".join(lines).strip()


def cmd_screen_shorts(args) -> int:
    """**ショートをユーザーが見て OK と言ったときだけ打つ。** 1本ずつ控える。"""
    path = Path(args.script)
    sc = load(path)
    APPROVALS.mkdir(parents=True, exist_ok=True)
    got = {}
    for sid in short_ids(sc):
        v = short_video(path, sid)
        if not v.exists():
            print("ショートの動画がありません: {}".format(v))
            return 1
        got[sid] = {"video": v.name, "sha256": sha256(v)}
    (APPROVALS / "{}.shorts.screened.json".format(path.stem)).write_text(
        json.dumps(got, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("ショート {} 本の確認を控えました".format(len(got)))
    return 0


def cmd_upload_shorts(args) -> int:
    """ショートを、`--from` の時刻から SHORT_HOURS の枠に順に予約する。"""
    from datetime import datetime, timedelta
    path = Path(args.script)
    sc = load(path)
    a = APPROVALS / "{}.shorts.screened.json".format(path.stem)
    if not a.exists():
        print("ショートをユーザーに見せて OK をもらってから screen-shorts してください")
        return 2
    ok = json.loads(a.read_text(encoding="utf-8"))
    start = datetime.strptime(args.start, "%Y-%m-%d %H:%M")
    slots, day = [], start.replace(hour=0, minute=0)
    while len(slots) < len(short_ids(sc)):
        for h in SHORT_HOURS:
            t = day.replace(hour=h)
            if t >= start:
                slots.append(t)
        day += timedelta(days=1)
    svc = _service()
    if svc is None:
        return 2
    for sid, at in zip(short_ids(sc), slots):
        v = short_video(path, sid)
        if sid not in ok or ok[sid]["sha256"] != sha256(v):
            print("{}: 見せた動画と違います（作り直したら確認し直し）".format(sid))
            return 2
        key = "{}:short:{}".format(path.stem, sid)
        if up.already_posted(POSTED, key):
            print("{}: もう予約してあります".format(sid))
            continue
        spec = sc["shorts"][sid]
        when = at.strftime("%Y-%m-%d %H:%M")
        tags = list(dict.fromkeys(["shorts", "カルテル"] + TAGS))
        print("{} {} → {}".format(sid, short_title(spec), when))
        vid = up.upload(svc, v, short_title(spec), short_description(sc, spec), tags, up.publish_time(when))
        up.record(POSTED, {"key": key, "video_id": vid, "title": short_title(spec), "publish_at": when})
        print("  予約しました: https://youtu.be/{}".format(vid))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="YouTube へ予約投稿する（日本のなぜ）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("whoami").set_defaults(fn=cmd_whoami)
    sub.add_parser("reauth").set_defaults(fn=cmd_reauth)
    s = sub.add_parser("describe"); s.add_argument("script"); s.set_defaults(fn=cmd_describe)
    s = sub.add_parser("screen"); s.add_argument("script"); s.set_defaults(fn=cmd_screen)
    s = sub.add_parser("thumb-set"); s.add_argument("script"); s.set_defaults(fn=cmd_thumb_set)
    s = sub.add_parser("desc-set"); s.add_argument("script"); s.set_defaults(fn=cmd_desc_set)
    s = sub.add_parser("screen-shorts"); s.add_argument("script"); s.set_defaults(fn=cmd_screen_shorts)
    s = sub.add_parser("upload-shorts"); s.add_argument("script")
    s.add_argument("--from", dest="start", required=True, help="最初の枠の時刻 'YYYY-MM-DD HH:MM' 以降に順に置く")
    s.set_defaults(fn=cmd_upload_shorts)
    s = sub.add_parser("upload")
    s.add_argument("script")
    s.add_argument("--at", required=True, help="公開時刻 'YYYY-MM-DD HH:MM'（日本時間・9〜24時）")
    s.add_argument("--remake", help="作り直した版の名前（例 v2）。投稿の控えを分ける")
    s.set_defaults(fn=cmd_upload)
    args = ap.parse_args()
    try:
        return int(args.fn(args))
    except up.UploadError as err:
        print("！ {}".format(err))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
