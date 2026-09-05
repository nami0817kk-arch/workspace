"""楽天ウェブサービスのクライアント。

この環境からは楽天へ到達できない（ネットワークポリシーで遮断）ため、
実際の通信は GitHub Actions 上でのみ行う。ここでは
- レスポンス形の揺れを吸収する解釈処理
- 1秒1回のリクエスト制限の遵守
をテストで検証できるように、通信と解釈を分けて実装する。
"""
import json
import os
import time
import urllib.parse
import urllib.error
import urllib.request

# 旧 app.rakuten.co.jp/services/api/ は 2026-05-13 に廃止された。
# 新方式は applicationId に加えて accessKey が必須で、ホストも API ごとに違う
# （商品検索は ichibams、ジャンル検索は ichibagt）。
SEARCH_URL = "https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701"
GENRE_URL = "https://openapi.rakuten.co.jp/ichibagt/api/IchibaGenre/Search/20260701"

# 楽天の制限は「1アプリIDにつき1秒1回」。余裕を持たせる。
MIN_INTERVAL = 1.1
MAX_HITS = 30          # 1リクエストで取れる上限
MAX_PAGE = 100


class RakutenError(RuntimeError):
    pass


def credentials() -> tuple[str, str, str]:
    """アプリID・アクセスキー・アフィリエイトIDを環境変数から読む。

    アプリIDはリクエストURLに乗る準公開の識別子だが、それでもリポジトリには置かない。
    アクセスキーは秘密情報。どちらも GitHub Actions のシークレットから環境変数で渡す。
    """
    app_id = os.environ.get("RAKUTEN_APP_ID", "").strip()
    access_key = os.environ.get("RAKUTEN_ACCESS_KEY", "").strip()
    missing = [n for n, v in (("RAKUTEN_APP_ID", app_id),
                              ("RAKUTEN_ACCESS_KEY", access_key)) if not v]
    if missing:
        raise RakutenError(
            f"{' と '.join(missing)} が設定されていません。"
            "GitHub のリポジトリ設定 > Secrets and variables > Actions に登録してください。")
    return app_id, access_key, os.environ.get("RAKUTEN_AFFILIATE_ID", "").strip()


class Throttle:
    """最後のリクエストから MIN_INTERVAL 秒空ける。"""

    def __init__(self, interval: float = MIN_INTERVAL, sleep=time.sleep, clock=time.monotonic):
        self.interval = interval
        self._sleep = sleep
        self._clock = clock
        self._last = None

    def wait(self) -> float:
        now = self._clock()
        if self._last is None:
            self._last = now
            return 0.0
        delay = self.interval - (now - self._last)
        if delay > 0:
            self._sleep(delay)
            self._last = self._clock()
            return delay
        self._last = now
        return 0.0


def item_of(entry: dict) -> dict:
    """API のバージョンによって Items の要素が
    {"Item": {...}} だったり {...} そのものだったりするので吸収する。
    """
    if isinstance(entry, dict) and isinstance(entry.get("Item"), dict):
        return entry["Item"]
    return entry if isinstance(entry, dict) else {}


def _first_image(item: dict) -> str:
    for key in ("mediumImageUrls", "smallImageUrls"):
        urls = item.get(key) or []
        for u in urls:
            url = u.get("imageUrl") if isinstance(u, dict) else u
            if url:
                # 末尾の ?_ex=128x128 を外すと大きい画像が得られる
                return str(url).split("?")[0]
    return ""


def parse_items(payload: dict) -> list[dict]:
    """検索レスポンスを、こちらで扱う形に正規化する。

    価格が取れない・商品コードが無い要素は捨てる。あとの計算がすべて
    価格に依存するので、ここで落としておかないと壊れた行が下流に流れる。
    """
    out = []
    for entry in payload.get("Items") or []:
        item = item_of(entry)
        code = str(item.get("itemCode") or "").strip()
        try:
            price = int(item.get("itemPrice"))
        except (TypeError, ValueError):
            continue
        if not code or price <= 0:
            continue
        try:
            review_average = float(item.get("reviewAverage") or 0)
        except (TypeError, ValueError):
            review_average = 0.0
        try:
            review_count = int(item.get("reviewCount") or 0)
        except (TypeError, ValueError):
            review_count = 0
        out.append({
            "item_code": code,
            "name": str(item.get("itemName") or "").strip(),
            "price": price,
            "shop": str(item.get("shopName") or "").strip(),
            # affiliateUrl はアフィリエイトIDを渡したときだけ返る。
            # 無ければ通常URLにフォールバックする（収益は出ないが表示は壊れない）。
            "url": str(item.get("affiliateUrl") or item.get("itemUrl") or "").strip(),
            "is_affiliate": bool(item.get("affiliateUrl")),
            "image": _first_image(item),
            "review_count": review_count,
            "review_average": review_average,
            "genre_id": str(item.get("genreId") or "").strip(),
        })
    return out


SECRET_PARAMS = ("applicationId", "accessKey", "affiliateId")


def redact(url: str) -> str:
    """例外やログに載せるため、URL から認証情報を落とす。

    アクセスキーはクエリに乗るので、そのまま出すと Actions のログに残る。
    """
    parts = urllib.parse.urlsplit(url)
    kept = [(k, v) for k, v in urllib.parse.parse_qsl(parts.query)
            if k not in SECRET_PARAMS]
    return urllib.parse.urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urllib.parse.urlencode(kept), ""))


RATE_LIMIT_RETRIES = 3
MAX_INTERVAL = 5.0


def _get(url: str, params: dict, throttle: Throttle, opener=urllib.request.urlopen) -> dict:
    query = urllib.parse.urlencode({k: v for k, v in params.items() if v not in (None, "")})
    full = f"{url}?{query}"
    req = urllib.request.Request(full, headers={"User-Agent": "price-tracker/1.0"})
    for attempt in range(RATE_LIMIT_RETRIES + 1):
        throttle.wait()
        try:
            with opener(req, timeout=30) as res:
                return json.loads(res.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            # 楽天は 403 などの本文に理由を JSON で返す。これを拾わないと
            # スコープ未設定・ドメイン制限・キー誤りのどれなのか切り分けられない。
            try:
                detail = exc.read().decode("utf-8", "replace").strip()[:500]
            except Exception:
                detail = ""
            # 429 は間隔を守っていても出る。以降の間隔を広げて数回だけやり直す。
            # 広げたまま続けるのは、1件だけ通しても次でまた落ちるため。
            if exc.code == 429 and attempt < RATE_LIMIT_RETRIES:
                throttle.interval = min(throttle.interval * 1.5, MAX_INTERVAL)
                continue
            raise RakutenError(
                f"HTTP {exc.code} {redact(full)} : {detail or '(本文なし)'}") from exc


def raw_search(genre_id: str, hits: int, throttle: Throttle, page: int = 1,
               opener=urllib.request.urlopen) -> dict:
    """検索の生レスポンスをそのまま返す。

    API 側のフィールド名が変わったとき、こちらの解釈処理を疑う前に
    実際に何が返っているかを見るために使う（--show-fields）。
    """
    app_id, access_key, affiliate_id = credentials()
    return _get(SEARCH_URL, {
        "applicationId": app_id,
        "accessKey": access_key,
        "affiliateId": affiliate_id,
        "genreId": genre_id,
        "hits": min(MAX_HITS, hits),
        "page": page,
        # 旧APIの standard は売れ筋に近い並びだったが、新API(20260701)の standard は
        # レビュー0の雑多な出品が上位に来る（2026-09-05 実測: PC・周辺機器の上位が
        # かき氷シロップ等で、itemCode 指定で引き直しても本当にレビュー0）。
        # レビュー数の多い順なら定番商品が返り、価格履歴を貯める対象として適切。
        "sort": "-reviewCount",
        "format": "json",
        "formatVersion": 2,
    }, throttle, opener)


def search_genre(genre_id: str, hits: int, throttle: Throttle,
                 opener=urllib.request.urlopen) -> list[dict]:
    """ジャンル内の商品をレビュー数の多い順に hits 件ぶん取る（売れ筋の代理指標）。"""
    items, page = [], 1
    while len(items) < hits and page <= MAX_PAGE:
        payload = raw_search(genre_id, hits - len(items), throttle, page, opener)
        batch = parse_items(payload)
        if not batch:
            break
        items.extend(batch)
        if page >= int(payload.get("pageCount") or 1):
            break
        page += 1
    return items[:hits]


def genre_children(genre_id: str, throttle: Throttle,
                   opener=urllib.request.urlopen) -> list[dict]:
    """ジャンルの直下の子ジャンルを返す。狙う分野をデータから決めるために使う。"""
    app_id, access_key, _ = credentials()
    payload = _get(GENRE_URL, {
        "applicationId": app_id,
        "accessKey": access_key,
        "genreId": genre_id,
        "format": "json",
        "formatVersion": 2,
    }, throttle, opener)
    out = []
    for child in payload.get("children") or []:
        node = child.get("child") if isinstance(child.get("child"), dict) else child
        gid = str(node.get("genreId") or "").strip()
        if gid:
            # 新API(20260701)はジャンル名を nameJa で返す。旧名 genreName も
            # 読めるようにしておく（片方しか無い応答が混ざっても名前を落とさない）。
            name = node.get("nameJa") or node.get("genreName") or ""
            out.append({"genre_id": gid, "name": str(name).strip()})
    return out
