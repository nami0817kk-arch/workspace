"""画像に誰が写っているかを、Wikimedia の構造化データで確かめる。

**ファイル名は根拠にならない。** 実測で、ファイル名に `Ayase Ueda` と入った
写真の被写体が、構造化データでは別人（Joris Kramer）だった。そのまま使えば
誤った人物を本人として放送するところだった。ライセンス判定は3件とも OK を
返していて、機械では防げていなかった。

Commons の `depicts`（P180）に、写っているものが Wikidata の ID で入っている。
ここに目的の人物がいるかどうかで判断する。

**指定が無い写真は「本人ではない」ではなく「確かめられない」。** 使うかどうかは
人が現物を見て決める。ここでは断定しない。
"""

from __future__ import annotations

from dataclasses import dataclass, field

import requests

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
WIKIDATA_API = "https://www.wikidata.org/w/api.php"
DEPICTS = "P180"
TIMEOUT = 25
UA = "youtube-video-creation/1.0 (image subject check)"


class SubjectError(Exception):
    pass


@dataclass
class Subjects:
    """1枚の画像に写っているとされるもの。"""

    title: str
    ids: list[str] = field(default_factory=list)
    names: list[str] = field(default_factory=list)

    @property
    def stated(self) -> bool:
        """被写体の指定があるか。無ければ確かめようがない。"""
        return bool(self.ids)

    def includes(self, *names: str) -> bool:
        """その人物が写っていると明記されているか。

        Wikidata のラベルは言語ごとに別なので、日本語名と英語名の**どちらか**が
        当たれば本人とみなす。英語名だけで照合すると、日本語ラベルしか
        持たない項目を取りこぼす（実測でメッシが弾かれた）。
        """
        keys = [n.strip().lower() for n in names if n and n.strip()]
        return any(k in n.lower() for k in keys for n in self.names)


def _get(url: str, params: dict, session=None, tries: int = 3) -> dict:
    """問い合わせる。429 は待って数回やり直す。

    1件につき Commons と Wikidata へ2回聞くので、続けて叩くとすぐ 429 になる。
    こちらが速すぎるだけなので、待てば通る（実測）。
    """
    import time

    client = session or requests
    for attempt in range(tries):
        try:
            response = client.get(
                url, params=params, headers={"User-Agent": UA}, timeout=TIMEOUT
            )
        except requests.RequestException as error:
            raise SubjectError(f"被写体を確かめられません: {error}") from error
        if response.status_code != 429:
            break
        if attempt < tries - 1:
            time.sleep(2.0 * (attempt + 1))
    if response.status_code == 429:
        raise SubjectError(
            "続けて問い合わせすぎました（HTTP 429）。しばらく待ってから試してください"
        )
    if response.status_code != 200:
        raise SubjectError(f"被写体の問い合わせが失敗しました（HTTP {response.status_code}）")
    try:
        return response.json()
    except ValueError as error:
        raise SubjectError(f"応答を読めません: {error}") from error


def fetch(title: str, session=None) -> Subjects:
    """Commons のファイル名から、写っているものの一覧を取る。

    title は "File:xxx.jpg" の形。credits.json の title から作れる。
    """
    name = title if title.startswith("File:") else f"File:{title}"
    payload = _get(COMMONS_API, {
        "action": "wbgetentities", "sites": "commonswiki", "titles": name,
        "props": "claims", "format": "json",
    }, session)

    entity = next(iter((payload.get("entities") or {}).values()), {})
    claims = entity.get("statements") or entity.get("claims") or {}
    ids: list[str] = []
    for claim in claims.get(DEPICTS, []):
        try:
            ids.append(claim["mainsnak"]["datavalue"]["value"]["id"])
        except (KeyError, TypeError):
            continue
    if not ids:
        return Subjects(title=name)

    labels = _get(WIKIDATA_API, {
        "action": "wbgetentities", "ids": "|".join(ids[:50]),
        "props": "labels", "languages": "ja|en", "format": "json",
    }, session)
    names: list[str] = []
    for entry in (labels.get("entities") or {}).values():
        for lang in ("ja", "en"):
            value = (entry.get("labels") or {}).get(lang, {}).get("value")
            if value:
                names.append(value)
    return Subjects(title=name, ids=ids, names=names)


PORTRAIT = "P18"


def is_portrait_of(title: str, *names: str, session=None) -> bool:
    """その人物の Wikidata 項目が、この画像を P18 に挙げているか。

    Commons の depicts が無い写真でも、人物側から辿れば身元が取れる。
    実測（2026-09-04）で、キエーザとエキティケの写真がこれに当たった。
    """
    wanted = _file_name(title)
    for name in [n for n in names if n and n.strip()]:
        hits = _get(WIKIDATA_API, {
            "action": "wbsearchentities", "format": "json", "language": "en",
            "uselang": "en", "search": name.strip(), "limit": 5,
        }, session).get("search", [])
        for hit in hits:
            entity = _get(WIKIDATA_API, {
                "action": "wbgetentities", "format": "json",
                "ids": hit["id"], "props": "claims",
            }, session).get("entities", {}).get(hit["id"], {})
            for claim in (entity.get("claims") or {}).get(PORTRAIT, []):
                try:
                    value = claim["mainsnak"]["datavalue"]["value"]
                except (KeyError, TypeError):
                    continue
                if _file_name(str(value)) == wanted:
                    return True
    return False


def _file_name(title: str) -> str:
    """File: の前置きと下線・空白の違いを吸収した比較用の名前。"""
    name = title[5:] if title.startswith("File:") else title
    return name.replace("_", " ").strip().lower()


def verify(title: str, *names: str, session=None) -> tuple[bool, str]:
    """その写真に、渡した人物が写っていると言い切れるか。

    名前は日本語と英語の両方を渡してよい（どちらかが当たれば本人とみなす）。
    返すのは (使ってよいか, 理由)。**確かめられないものは False にする。**
    誤った人物を出すより、使わないほうがよい。
    """
    label = " / ".join(n for n in names if n)
    found = fetch(title, session)
    if not found.stated:
        # depicts が無い写真は多い。人物の Wikidata 項目が「その人の画像」
        # （P18）としてこの1枚を挙げているなら、それも本人である根拠になる。
        # ファイル名と違い、人が項目に紐づけた指定なので信用できる。
        if is_portrait_of(title, *names, session=session):
            return True, f"Wikidata が {label} の画像として挙げている1枚です"
        return False, "被写体の指定がありません。ファイル名だけでは本人と断定できません"
    if found.includes(*names):
        return True, f"被写体に {label} が明記されています"
    return False, f"被写体は {' / '.join(found.names) or '不明'} で、{label} は含まれていません"
