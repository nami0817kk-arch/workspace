"""YouTube への予約投稿（日本のなぜのチャンネル）。

**歴史の地層（projects/rekishi-chiso/chiso/upload.py）から写した。**
元はサッカーのチャンネルで踏んで直したもの：
- 予約公開は private ＋ publishAt
- サムネイルで落ちても動画の id は返す（掛け直すと同じ動画が2本になる。2026-09-08 に実際に起きた）
- 掛け直す前に、同じ題名が少し前に上がっていないかを見る（二重投稿の防止）
- 許可の取り直しは `reauth` だけ（同意画面で毎回アカウントを選ばせる）。ほかのコマンドはブラウザを開かず、
  許可が足りない・失効しているときは NeedConsent で止まる（10-08。同意はユーザーがする）
新しく足したもの：字幕ファイル（SRT）の登録、控え（posted.json）、英語の題名と説明（localizations）。
投稿の手順は scripts/post.py。

鍵と許可はリポジトリの外に置く（workspace は public）：
    C:/Users/なみ/dev/output/yononaka-danmen/secrets/client_secret.json   … Google Cloud「yononaka-danmen」のクライアント
    C:/Users/なみ/dev/output/yononaka-danmen/secrets/token.json           … 「日本のなぜ」のチャンネルを選んで許可したもの
API の枠はサッカーと分けてある（別の Google Cloud プロジェクト。2026-10-04 ユーザー決定）。
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",     # 字幕・概要欄の直し・再生リスト・英語の題名（videos.update）
]
# 再生リスト（playlists.insert・playlistItems.insert）と videos.update はどちらかが要る。
# force-ssl で足りるので youtube は求めない（足すと今の許可の更新が invalid_scope で落ちる）
MANAGE_SCOPES = {"https://www.googleapis.com/auth/youtube", "https://www.googleapis.com/auth/youtube.force-ssl"}
SECRETS = Path(os.environ.get("DANMEN_SECRETS", r"C:/Users/なみ/dev/output/yononaka-danmen/secrets"))
JST = timezone(timedelta(hours=9))
OPEN_HOUR, CLOSE_HOUR = 9, 24        # 公開は9時から24時（チャンネル共通の決まり）
CATEGORY_EDUCATION = "27"
REAUTH = ("許可を取り直す必要があります（ブラウザでの同意はユーザーが行う）。\n"
          "  python scripts/post.py reauth   … ブラウザが開くので、Google アカウントを選び、"
          "「日本のなぜ」のチャンネルを選んで、すべての項目を許可する。\n"
          "  古い許可は secrets/token.<日時>.json.old に残ります")


class UploadError(RuntimeError):
    pass


class NeedConsent(UploadError):
    """今の許可では足りない・失効している。reauth をユーザーに打ってもらう。"""


def _deps():
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError as exc:
        raise UploadError("投稿用の依存がありません: pip install -r requirements-upload.txt") from exc
    return Request, Credentials, InstalledAppFlow, build, MediaFileUpload


def credentials(secrets: Path = SECRETS):
    """保存してある許可を読む（期限切れなら更新して書き戻す）。ブラウザは開かない。
    無い・失効しているときは NeedConsent（取り直しは reauth で、ユーザーが同意する）。"""
    Request, Credentials, *_ = _deps()
    token = secrets / "token.json"
    if not token.exists():
        raise NeedConsent(f"許可がありません: {token}\n" + REAUTH)
    cred = Credentials.from_authorized_user_file(str(token))      # 許可したときのスコープのまま読む
    if not cred.valid:
        if not (cred.expired and cred.refresh_token):
            raise NeedConsent("保存してある許可が使えません。\n" + REAUTH)
        try:
            cred.refresh(Request())
        except Exception as err:  # noqa: BLE001
            if "invalid_grant" in str(err) or "invalid_scope" in str(err):
                raise NeedConsent(f"保存してある許可が失効しています（{str(err)[:60]}）。\n" + REAUTH) from err
            raise
        token.write_text(cred.to_json(), encoding="utf-8")
    return cred


def granted_scopes(cred) -> set[str]:
    """Google が実際に認めているスコープ（token.json の scopes 欄は書いた側の申告なので当てにしない）。"""
    import urllib.parse
    import urllib.request
    data = urllib.parse.urlencode({"access_token": cred.token}).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/tokeninfo", data=data, timeout=30) as r:
        return set(json.load(r).get("scope", "").split())


def can_manage(scopes: set[str]) -> bool:
    return bool(scopes & MANAGE_SCOPES)


def service(secrets: Path = SECRETS, need_manage: bool = False, scopes_of=granted_scopes):
    """YouTube Data API。need_manage で再生リスト・videos.update の許可があるかを先に確かめる。"""
    *_, build, _ = _deps()
    cred = credentials(secrets)
    if need_manage and not can_manage(scopes_of(cred)):
        raise NeedConsent("今の許可は投稿（youtube.upload）だけで、再生リストと英語の題名を書き込めません。\n" + REAUTH)
    return build("youtube", "v3", credentials=cred)


def reauth(secrets: Path = SECRETS, run_flow=None, now: datetime | None = None) -> Path | None:
    """許可を取り直す（ユーザーがブラウザで同意する）。古い token.json は消さずに別名へ写してから。
    返り値は古い許可の控えの場所（無ければ None）。"""
    import shutil
    token, client = secrets / "token.json", secrets / "client_secret.json"
    if not client.exists():
        raise UploadError(f"クライアント情報がありません: {client}（Google Cloud の yononaka-danmen から）")
    backup = None
    if token.exists():
        stamp = (now or datetime.now(JST)).strftime("%Y%m%d-%H%M%S")
        backup = token.with_name(f"token.{stamp}.json.old")
        shutil.copy2(token, backup)
    if run_flow is None:
        *_, InstalledAppFlow, _, _ = _deps()

        def run_flow():
            # 10-04：prompt=consent だけだと、前に選んだ「海外サッカーの理由」が黙って使われた（2回）。
            # select_account でアカウント・ブランドアカウントを選ぶ画面を必ず出す
            return InstalledAppFlow.from_client_secrets_file(str(client), SCOPES).run_local_server(
                port=0, prompt="select_account consent")
    print("■ ブラウザで許可の画面を開きます。**「日本のなぜ」のチャンネルを選んで**、すべての項目を許可してください")
    cred = run_flow()
    token.parent.mkdir(parents=True, exist_ok=True)
    token.write_text(cred.to_json(), encoding="utf-8")
    return backup


def channel_title(svc) -> str:
    got = svc.channels().list(part="snippet", mine=True).execute()
    items = got.get("items") or []
    return items[0]["snippet"]["title"] if items else ""


def publish_time(text: str, now: datetime | None = None) -> str:
    """'2026-10-05 19:00'（日本時間）を RFC3339（UTC）にする。過去と、9時〜24時の外は止める。"""
    now = now or datetime.now(JST)
    try:
        at = datetime.strptime(text.strip(), "%Y-%m-%d %H:%M").replace(tzinfo=JST)
    except ValueError as exc:
        raise UploadError(f"公開時刻は 'YYYY-MM-DD HH:MM'（日本時間）で書きます: {text}") from exc
    if at <= now + timedelta(minutes=15):
        raise UploadError(f"公開時刻が過ぎているか近すぎます（15分以上先にする）: {text}")
    if not (OPEN_HOUR <= at.hour < CLOSE_HOUR):
        raise UploadError(f"公開は {OPEN_HOUR}時から{CLOSE_HOUR}時のあいだにします: {text}")
    return at.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def recently_uploaded(svc, title: str, minutes: int = 180) -> str | None:
    """同じ題名の動画が少し前に上がっていないか（掛け直しで2本にしないため）。"""
    ch = svc.channels().list(part="contentDetails", mine=True).execute()
    uploads = ch["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    got = svc.playlistItems().list(part="snippet", playlistId=uploads, maxResults=15).execute()
    edge = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    for item in got.get("items") or []:
        sn = item["snippet"]
        try:
            at = datetime.fromisoformat((sn.get("publishedAt") or "").replace("Z", "+00:00"))
        except ValueError:
            continue
        if at >= edge and sn.get("title", "").strip() == title.strip():
            return str(sn["resourceId"]["videoId"])
    return None


def upload(svc, video: Path, title: str, description: str, tags: list[str], publish_at: str,
           thumbnail: Path | None = None, captions: Path | None = None, made_for_kids: bool = False,
           localizations: dict | None = None) -> str:
    """予約投稿して videoId を返す。サムネイルと字幕は落ちても警告だけ（あとで付け直せる）。"""
    *_, MediaFileUpload = _deps()
    if not video.exists():
        raise UploadError(f"動画がありません: {video}")
    dup = recently_uploaded(svc, title)
    if dup:
        raise UploadError(f"同じ題名の動画がもう上がっています: https://youtu.be/{dup}（掛け直さない）")
    body = {
        "snippet": {"title": title[:100], "description": description[:5000], "tags": tags[:30],
                    "categoryId": CATEGORY_EDUCATION, "defaultLanguage": "ja", "defaultAudioLanguage": "ja"},
        "status": {"privacyStatus": "private", "publishAt": publish_at,
                   "selfDeclaredMadeForKids": made_for_kids},
    }
    part = "snippet,status"
    if localizations:                      # 英語の題名と説明（日本語が既定の言語）
        body["localizations"] = localizations
        part += ",localizations"
    req = svc.videos().insert(part=part, body=body,
                              media_body=MediaFileUpload(str(video), chunksize=-1, resumable=True))
    resp = None
    while resp is None:
        status, resp = req.next_chunk()
        if status:
            print(f"  アップロード {int(status.progress() * 100)}%")
    vid = resp["id"]
    if thumbnail and thumbnail.exists():
        try:
            svc.thumbnails().set(videoId=vid, media_body=str(thumbnail)).execute()
        except Exception as err:  # noqa: BLE001 - 動画はもう上がっている
            print(f"! サムネイルは付きませんでした（{str(err)[:80]}）。あとで thumb-set で付けてください")
    if captions and captions.exists():
        try:
            svc.captions().insert(part="snippet", body={"snippet": {"videoId": vid, "language": "ja",
                                                                     "name": "日本語", "isDraft": False}},
                                  media_body=MediaFileUpload(str(captions), mimetype="application/octet-stream")
                                  ).execute()
        except Exception as err:  # noqa: BLE001
            print(f"! 字幕は付きませんでした（{str(err)[:80]}）")
    return vid


def record(log: Path, entry: dict) -> None:
    """投稿の控え（同じ台本を二度出さないため）。"""
    data = json.loads(log.read_text(encoding="utf-8")) if log.exists() else []
    data.append(entry)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def already_posted(log: Path, key: str) -> dict | None:
    if not log.exists():
        return None
    for e in json.loads(log.read_text(encoding="utf-8")):
        if e.get("key") == key:
            return e
    return None
