"""取得したデータが「記録に値するか」を保存前に判定する。

このPJTが依存しているのは自分のコードではなく楽天のAPIで、そちらの仕様変更は
例外ではなく**静かな劣化**として現れる。実際に起きたものだけでも:

- 旧APIが廃止され、取得が0件になった（テストは全部モックなので緑のまま）
- ジャンル名の項目が genreName から nameJa に変わり、名前が空文字になった
- アフィリエイトIDが渡らないと、リンクが通常URLに落ちて収益が消える

いずれも例外を投げないので、CI もテストも気づけない。ここで「データとして
成立しているか」を数で見て、割っていたら記録させない。

**記録を止める方を選ぶ理由**: 価格履歴は追記型の資産で、壊れた1日を混ぜると
最安値・値下がりの判定が恒久的に歪む。取り直しはできない。1日欠けるより、
壊れた日を入れない方が損失が小さい。
"""

# 期待件数に対してこれを下回ったら、取得が部分的に失敗している
MIN_COUNT_RATIO = 0.8
# 商品名が空の割合。項目名の変更はここに出る
MAX_BLANK_NAME_RATIO = 0.05
# 価格が取れていない割合。解釈が崩れるとここに出る
MAX_BAD_PRICE_RATIO = 0.01
# アフィリエイトリンクでない割合。超えると収益が発生しない
MAX_NO_AFFILIATE_RATIO = 0.05


def _ratio(count: int, total: int) -> float:
    return count / total if total else 0.0


def check_snapshot(rows: list[dict], expected: int) -> tuple[list[str], list[str]]:
    """記録前の検査。(止めるべき理由, 気に留める理由) を返す。

    expected はジャンル数 × 1ジャンルあたりの取得件数。重複除去で多少減るため、
    完全一致ではなく割合で見る。
    """
    errors: list[str] = []
    warnings: list[str] = []
    total = len(rows)

    if total == 0:
        return ["1件も取得できていません。"], warnings

    if expected > 0 and total < expected * MIN_COUNT_RATIO:
        errors.append(
            f"件数が少なすぎます（{total}件 / 期待 {expected}件の"
            f"{MIN_COUNT_RATIO:.0%}未満）。ジャンル単位で取得に失敗している可能性があります。")

    blank = sum(1 for r in rows if not str(r.get("name") or "").strip())
    if _ratio(blank, total) > MAX_BLANK_NAME_RATIO:
        errors.append(
            f"商品名が空の行が {blank}/{total} 件（{_ratio(blank, total):.1%}）あります。"
            "APIの項目名が変わった可能性があります。")

    bad_price = sum(1 for r in rows if not isinstance(r.get("price"), int) or r["price"] <= 0)
    if _ratio(bad_price, total) > MAX_BAD_PRICE_RATIO:
        errors.append(
            f"価格が取れていない行が {bad_price}/{total} 件"
            f"（{_ratio(bad_price, total):.1%}）あります。")

    no_aff = sum(1 for r in rows if not r.get("is_affiliate"))
    if _ratio(no_aff, total) > MAX_NO_AFFILIATE_RATIO:
        errors.append(
            f"アフィリエイトリンクでない行が {no_aff}/{total} 件"
            f"（{_ratio(no_aff, total):.1%}）あります。"
            "RAKUTEN_AFFILIATE_ID を確認してください。このまま記録しても収益が発生しません。")

    # レビューは元々ほとんど0で返るため、割合ではなく「全滅」だけを見る。
    # 項目そのものが返らなくなった場合の合図として使う。
    if all(int(r.get("review_count") or 0) == 0 for r in rows):
        warnings.append(
            "レビュー件数が全件0です。APIが項目を返さなくなった可能性があります"
            "（価格履歴には影響しません）。")

    return errors, warnings
