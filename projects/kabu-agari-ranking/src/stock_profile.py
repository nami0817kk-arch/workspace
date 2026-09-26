"""銘柄の基本属性（市場区分・業種・売買単位）を貯めておく。

**変わらないものだけを持つ。** 同じページには PER・PBR・時価総額もあるが、
それらは毎日変わる。載せるなら毎日全銘柄ぶん取り直すことになり、取得元への
回数が桁で増える（相手は既に GitHub Actions の IP を 405 で弾いている）。
取り直さなければ古い数字を出し続けることになり、株価の指標で古い数字は
誤りと同じ。そのうえ、それらは他所にもある数字で、このサイトが持つ意味が薄い。

対して市場区分・業種・売買単位は年に数回しか変わらないので、
**銘柄ごとに1回取れば足りる**。だから未知のコードが出たときだけ取りに行く。

貯める先は `data/stocks.json`。ランキングの日次ファイルと同じ場所に置くが、
性質が違う（日付を持たない、後から取り直せる）ので1ファイルにまとめてある。
"""
import json
import time
from pathlib import Path

from kabutan import fetch_stock_page, parse_stock_profile

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CACHE_NAME = "stocks.json"
CACHE_PATH = _DATA_DIR / CACHE_NAME

# 1回の実行で取りに行く上限。取得元に負荷を掛けないためと、
# 万一ページの構造が変わっていたときに空振りを大量に出さないため。
FETCH_LIMIT = 40

# 連続して叩かない。取得元は個人サイトではないが、こちらの都合で
# 速く回す理由が無い（未知の銘柄は1日に数件しか出ない）。
FETCH_INTERVAL_SEC = 1.5

# 途中保存の間隔（件）。まとめて取るときに落ちても取り直しにならないように。
_SAVE_EVERY = 20


def load(path: Path | None = None) -> dict[str, dict]:
    """貯めてある属性。無ければ空。

    属性が読めなくても描画は続ける（無ければその行を出さないだけ）。
    ランキングが出ないほうが損が大きい。
    """
    path = path or CACHE_PATH
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"  [WARN] {path.name} が読めません（無視して続けます）: {e}")
        return {}
    return data.get("stocks", {}) if isinstance(data, dict) else {}


def save(profiles: dict[str, dict], path: Path | None = None) -> None:
    path = path or CACHE_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"stocks": dict(sorted(profiles.items()))}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def label(profile: dict | None, *, unit: bool = True) -> str:
    """画面に1行で出すときの表記。取れていない項目は黙って落とす。

    Args:
        unit: 売買単位まで入れるか。meta description のような
            文の途中に差し込む場所では長くなるので落とす。
    """
    if not profile:
        return ""
    parts = [profile[k] for k in ("market", "industry") if profile.get(k)]
    if unit and profile.get("unit"):
        parts.append(f"売買単位{profile['unit']}")
    return "／".join(parts)


def needed_codes(days: list[dict], stock_page_codes) -> list[str]:
    """属性を画面に出す銘柄のコード。

    出すのは**銘柄ページを持つ銘柄**と**ストップ高になった銘柄**だけ。
    ランキングの表には出さない（列を増やすとスマホで銘柄名が折り返す。
    表の位置を 849px → 469px まで詰めた意味が消える）。
    """
    codes = {str(c) for c in stock_page_codes}
    for day in days:
        for row in day.get("stop_high") or []:
            if row.get("at_limit"):
                codes.add(str(row["code"]))
    return sorted(codes)


def sync(codes, profiles: dict[str, dict] | None = None, *,
         limit: int = FETCH_LIMIT, interval: float = FETCH_INTERVAL_SEC) -> dict[str, dict]:
    """未知のコードだけ取りに行って、貯めてある属性に足す。

    取得に失敗したコードは記録しない（次の実行でまた試す）。
    取得できたが何も読み取れなかったコードは空で記録する
    （上場廃止などで永遠に読み取れないものを毎日叩かないため）。
    """
    profiles = dict(profiles if profiles is not None else load())
    unknown = [str(c) for c in codes if str(c) not in profiles]
    if not unknown:
        return profiles

    targets = unknown[:limit]
    if len(unknown) > limit:
        print(f"  銘柄属性: 未取得 {len(unknown)} 件のうち {limit} 件を取得します"
              f"（残りは次回）。")
    else:
        print(f"  銘柄属性: 未取得 {len(targets)} 件を取得します。")

    fetched = 0
    for i, code in enumerate(targets):
        if i:
            time.sleep(interval)
        html = fetch_stock_page(code)
        if html is None:
            continue
        profiles[code] = parse_stock_profile(html)
        fetched += 1
        # 途中で落ちてもそこまでを残す（同じ銘柄を取り直す理由が無い）
        if fetched % _SAVE_EVERY == 0:
            save(profiles)

    if fetched:
        save(profiles)
        print(f"  銘柄属性: {fetched} 件を {CACHE_PATH.name} に保存しました"
              f"（累計 {len(profiles)} 銘柄）。")
    return profiles
