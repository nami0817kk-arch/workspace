# -*- coding: utf-8 -*-
"""板の字がスマホで読めるかの点検（tools/typecheck.py、2026-10-08）。

**✓ しか出ない点検は意味が無い**ので、壊れた例（狭い置き場・薄い緑に白い字・
半透明の板）を食わせて × になることを必ず見る。
"""
from pathlib import Path

from PIL import Image

from src import cards
from src.config import load_config
from tools import typecheck


def _config():
    return load_config(Path(__file__).resolve().parents[1] / "config" / "project.yaml")


def _fonts():
    config = _config()
    return str(config.video.font_path()), str(config.video.latin_font_path())


CONVERT3 = {
    "type": "convert", "title": "週給を円に直すと",
    "steps": [["35万", "ポンド", "サカの週給"], ["1820万", "ポンド", "52週ぶん"],
              ["約38", "億円", "1ポンド＝209円"]],
    "via": ["×52週", "×209円"], "source": "報道",
}
TABLE = {
    "type": "table", "title": "アルテタの新しい契約", "columns": ["項目", "内容"],
    "rows": [["契約の期限", "2030年6月まで"], ["年俸", "最大2500万ポンド"]],
}
# **壊れた例**（2026-10-08）。板は置き場に収まる高さで描くようになったが、
# **行が多すぎる表だけは収まらない**（行の高さの下限 42px × 14行 ＋ 題と見出しで 800px）。
# 置き場は 539px なので、本編・単独では 0.67 倍に縮んで行の字が 3.8pt になる
LONG_TABLE = {
    "type": "table", "title": "長い表", "columns": ["季", "順位", "勝点"],
    "rows": [[f"20{10 + i}-{11 + i}", f"{i + 1}位", str(90 - i * 3)] for i in range(14)],
}


# ---------------------------------------------------------------- 基準の引き直し


def test_スマホでの実寸は画面の幅で決まる():
    """同じ px が、本編（1920幅）とショート（1080幅）で違う大きさに見える。

    px で基準を引くと嘘になる、というのがこの道具の前提。
    """
    assert round(typecheck.phone_pt(28, 1920), 1) == 5.7     # typo.CREDIT と同じ
    assert round(typecheck.phone_pt(28, 1080), 1) == 10.1
    assert typecheck.phone_pt(28, 1080) > typecheck.phone_pt(28, 1920)


def test_読める下限を切ったら直す_目安を切ったら注意():
    assert typecheck.judge_size(3.2, "出典") == "×"
    assert typecheck.judge_size(5.7, "出典") == "○"
    assert typecheck.judge_size(6.5, "行の字") == "△"      # 目安 9.8pt
    assert typecheck.judge_size(9.8, "行の字") == "○"


def test_知らない描き方も役として出す():
    """`cards.py` に新しい図が足されても、字を黙って落とさない。"""
    role = typecheck.role_of("_newcard.<locals>.draw_box <- render", "35", 30,
                             cards.TEXT, None)
    assert "_newcard" in role


def test_数字と単位を分けて数える():
    """put_number は数字を大きく・単位を半分で描くので、1回の呼び出しに役が2つある。"""
    assert typecheck.role_of("put_number <- _stats.<locals>.draw_item", "1820", 86,
                             cards.BRAND_GOLD, "ls") == "数字"
    assert typecheck.role_of("put_number <- _stats.<locals>.draw_item", "万ポンド", 43,
                             cards.BRAND_GOLD, "ls") == "単位"


# ---------------------------------------------------------------- コントラスト


def test_半透明の板は合成したあとの色で測る():
    """合成前の色で測ると、本番より良い数字が出て嘘になる。"""
    assert cards.PANEL[3] == 248                     # 板の地はわずかに透ける
    composed = typecheck.over(cards.PANEL)
    assert composed != tuple(cards.PANEL[:3])        # 白い下地のぶん明るくなる
    before = typecheck.contrast(cards.SUB, cards.PANEL[:3])
    after = typecheck.contrast(cards.SUB, composed)
    assert after < before                            # 合成後のほうが比は落ちる


def test_薄い緑に白い字はコントラストが足りない():
    """壊れた例。`cards._kit` の ○ の丸地（74,200,128）に白の「OK」。"""
    ratio = typecheck.contrast((255, 255, 255), (74, 200, 128))
    assert ratio < typecheck.NEED_LARGE
    assert typecheck.judge_contrast(ratio, 30, edged=False) == "×"
    # 黒い縁を足せば、縁が背後になるので通る
    assert typecheck.judge_contrast(
        typecheck.contrast((255, 255, 255), (0, 0, 0)), 30, edged=True) == "○"


def test_小さい字は本文あつかいで下限が上がる():
    assert typecheck.need_ratio(30, False) == typecheck.NEED_LARGE
    assert typecheck.need_ratio(20, False) == typecheck.NEED_SMALL
    assert typecheck.judge_contrast(3.5, 20, edged=False) == "×"
    assert typecheck.judge_contrast(3.5, 30, edged=False) == "△"


# ---------------------------------------------------------------- 計測のしかけ


def test_計測のラッパは絵を1pxも変えない(tmp_path):
    """本番の描画に手を入れない、がこの道具の条件。

    `cards.ImageDraw` を差し替えて描いた絵と、差し替えずに描いた絵を突き合わせる。
    """
    font, latin = _fonts()
    plain = tmp_path / "plain.png"
    cards.render(CONVERT3, 1420, font, plain, latin)
    shots, spied = typecheck.shoot(CONVERT3, 1420, (1920, 1080), font, latin,
                                   tmp_path / "spied.png", paint=True)
    with Image.open(plain) as opened:
        expected = opened.convert("RGBA")
    assert spied.size == expected.size
    assert spied.tobytes() == expected.tobytes()
    assert shots                                     # 記録はちゃんと取れている
    assert cards.ImageDraw.__name__ == "PIL.ImageDraw"   # 後片付けもしている


def test_字を描かない2周目で背後の色が取れる(tmp_path):
    font, latin = _fonts()
    shots, _ = typecheck.shoot(TABLE, 1420, (1920, 1080), font, latin,
                               tmp_path / "a.png", paint=True)
    _, background = typecheck.shoot(TABLE, 1420, (1920, 1080), font, latin,
                                    tmp_path / "b.png", paint=False)
    heads = [s for s in shots if s.role == "列の見出し"]
    assert heads
    back, edged = typecheck.behind(background, heads[0])
    assert not edged
    # 表の見出し行はチャンネルの深い緑。板の地（濃い紺）とは違う色が拾えている
    assert back == typecheck.over(cards.BRAND_GREEN)


# ---------------------------------------------------------------- 置き方と倍率


def test_置き場が狭いと全部の字が読めない大きさになる(tmp_path):
    """壊れた例。板を無理に縮めて貼れば、どんな字も下限を切る。"""
    font, latin = _fonts()
    narrow = typecheck.Place("試し・狭い置き場", (1920, 1080), 1420, 120)
    result = typecheck.Result()
    typecheck.measure("table", TABLE, narrow, font, latin, tmp_path, result)
    assert result.sizes
    assert all(row.scale < 0.5 for row in result.sizes)
    assert all(row.mark == "×" for row in result.sizes)
    assert result.bad


def test_置き場が広ければ縮まない(tmp_path):
    font, latin = _fonts()
    roomy = typecheck.Place("試し・広い置き場", (1920, 1080), 1420, 2000)
    result = typecheck.Result()
    typecheck.measure("table", TABLE, roomy, font, latin, tmp_path, result)
    assert result.sizes
    assert all(row.scale == 1.0 for row in result.sizes)
    assert not [row for row in result.sizes if row.mark == "×"]


def test_本編の3段の換算は縮まずに注記が読める(tmp_path):
    """**2026-10-08 に直したところ。**それまでは縦に積んで 744px になり、置き場（539px）に
    収まるまで 0.72 倍に縮められて注記が 20px＝スマホ 4.1pt だった（CLAUDE.md に
    「約22px」と書いてあったのも甘かった）。いまは本編だけ横に並べるので縮まない。
    """
    font, latin = _fonts()
    config = _config()
    main = [p for p in typecheck.places(config) if p.name == "本編・単独"][0]
    result = typecheck.Result()
    typecheck.measure("convert（3段）", CONVERT3, main, font, latin, tmp_path, result)
    notes = [row for row in result.sizes if row.role == "注記"]
    assert notes, [row.role for row in result.sizes]
    note = notes[0]
    assert note.asked == 28                 # 板の中では 28px で描いている
    assert note.scale == 1.0                # 置き場に収まるので縮まない
    assert note.screen_px == 28             # 画面でもそのまま 28px
    assert note.pt >= typecheck.FLOOR_PT - 0.05
    assert note.mark != "×"
    assert not result.bad                   # 出典も 28px になったので × は1つも無い


def test_ショートでは同じ板の注記が基準を満たす(tmp_path):
    """ショートは 1080 幅で画面いっぱいに出るので、同じ 28px が倍近く大きく見える。"""
    font, latin = _fonts()
    config = _config()
    short = [p for p in typecheck.places(config) if p.name.startswith("ショート")][0]
    result = typecheck.Result()
    typecheck.measure("convert（3段）", CONVERT3, short, font, latin, tmp_path, result)
    notes = [row for row in result.sizes if row.role == "注記"]
    assert notes
    assert notes[0].pt > typecheck.FLOOR_PT
    assert notes[0].mark == "○"


def test_置き方はrenderから引く():
    """板の幅と置ける高さは `src/render.py` の決まりに付いていく。"""
    config = _config()
    names = [p.name for p in typecheck.places(config)]
    assert names == ["本編・単独", "本編・写真と横並び", "ショート・縦に積む"]
    main = [p for p in typecheck.places(config) if p.name == "本編・単独"][0]
    assert main.width == int(1920 * 0.74)
    from src import render as render_mod

    layout = render_mod.Layout(1920, 1080, config.video.show_characters)
    top, bottom = layout.media_slot
    assert main.room == bottom - top


def test_横に並べる板は縮まないので置き場を超えると知らせる(tmp_path):
    """壊れた例は**行の多い表**にした（2026-10-08）。

    3段の換算は置き場に収まるよう作り直したので、もうはみ出さない。
    行の高さには下限（`cards.TABLE_ROW_MIN_H`）があるので、**行が多すぎる表だけは
    いまでも収まらない**。そのときに知らせが出ることを見る。
    """
    font, latin = _fonts()
    config = _config()
    beside = [p for p in typecheck.places(config) if p.beside][0]
    result = typecheck.Result()
    typecheck.measure("長い表", LONG_TABLE, beside, font, latin, tmp_path, result)
    assert all(row.scale == 1.0 for row in result.sizes)
    assert any("置き場" in note for note in result.notes)


def test_板は本編の置き場に収まる高さで描かれる(tmp_path):
    """**この直しの本体。**見本の板はどれも、本編の2つの置き方で倍率1.00になる。

    2026-10-08 より前は scatter 0.75・convert（3段）0.72・table 0.81・line 0.82 で、
    板の中の 28px が画面では 20〜23px になっていた。
    """
    font, latin = _fonts()
    config = _config()
    specs = typecheck.samples()
    for place in typecheck.places(config):
        if place.name.startswith("ショート"):
            continue
        result = typecheck.Result()
        for name, spec in specs.items():
            typecheck.measure(name, spec, place, font, latin, tmp_path, result)
        shrunk = sorted({row.card for row in result.sizes if row.scale < 1.0})
        assert shrunk == [], f"{place.name} で縮む板: {shrunk}"
        assert result.notes == [], result.notes       # はみ出す板も無い


def test_ショートの板は本編のために詰めない(tmp_path):
    """ショートの置き場は 983px あるので、詰める理由が無い。

    本編に合わせて一律に低くすると、縦の画面で図だけが小さくなる。
    """
    font, latin = _fonts()
    config = _config()
    short = [p for p in typecheck.places(config) if p.name.startswith("ショート")][0]
    main = [p for p in typecheck.places(config) if p.name == "本編・単独"][0]
    specs = typecheck.samples()
    for name in ("scatter", "line"):
        tall = cards.render(specs[name], short.width, font,
                            tmp_path / f"{name}_s.png", latin, slot=short.room)
        flat = cards.render(specs[name], main.width, font,
                            tmp_path / f"{name}_m.png", latin, slot=main.room)
        with Image.open(tall) as a, Image.open(flat) as b:
            assert a.height > b.height, name


# ---------------------------------------------------------------- 取材メモから拾う


def test_取材メモの板を拾う(tmp_path):
    note = tmp_path / "note.yaml"
    note.write_text(
        "date: 2026年10月8日\n"
        "sections:\n"
        "- id: money\n"
        "  card:\n"
        "    type: stats\n"
        "    title: 契約の中身\n"
        "    items:\n"
        "    - ['4', 年, 2030年まで]\n"
        "  say:\n"
        "  - text: 本文です。\n"
        "    card:\n"
        "      type: table\n"
        "      title: 順位と勝ち点\n"
        "      columns: [季, 順位]\n"
        "      rows: [['2024-25', 2位], ['2025-26', 1位]]\n"
        "      highlight_row: 0\n"
        "  - text: 次の行です。\n"
        "    card:\n"
        "      type: table\n"
        "      title: 順位と勝ち点\n"
        "      columns: [季, 順位]\n"
        "      rows: [['2024-25', 2位], ['2025-26', 1位]]\n"
        "      highlight_row: 1\n"
        "  - text: 板なしの行です。\n"
        "    card: none\n",
        encoding="utf-8")
    found = typecheck.collect_note(note)
    # 光らせる行だけが違う表は1枚に畳む（cards.same_table と同じ見方）
    assert sorted(found) == ["stats「契約の中身」", "table「順位と勝ち点」"]
    # 代表に採るのは光らせてある版
    assert "highlight_row" in found["table「順位と勝ち点」"]
    assert found["stats「契約の中身」"]["type"] == "stats"


def test_板の書かれていない取材メモは空(tmp_path):
    note = tmp_path / "empty.yaml"
    note.write_text("date: 2026年10月8日\nsections: []\n", encoding="utf-8")
    assert typecheck.collect_note(note) == {}


# ---------------------------------------------------------------- 入口


def test_基準を切るものがあれば終了コード1(tmp_path, capsys):
    """**壊れた例を取材メモから食わせる**（2026-10-08）。

    それまでは「convert」で鳴っていたが、直したので全部の見本が通るようになった。
    `--note` に行の多い表を書いた取材メモを渡して、× が出ることを見る。
    """
    note = tmp_path / "note.yaml"
    rows = "\n".join(f"    - ['20{10 + i}-{11 + i}', '{i + 1}位', '{90 - i * 3}']"
                      for i in range(14))
    note.write_text(
        "date: 2026年10月8日\n"
        "sections:\n"
        "- id: long\n"
        "  card:\n"
        "    type: table\n"
        "    title: 長い表\n"
        "    columns: [季, 順位, 勝点]\n"
        "    rows:\n" + rows + "\n",
        encoding="utf-8")
    out = tmp_path / "typecheck.md"
    code = typecheck.main(["--note", str(note), "--out", str(out)])
    assert code == 1
    printed = capsys.readouterr().out
    assert "直すもの" in printed
    assert out.exists()
    saved = out.read_text(encoding="utf-8")
    assert "## 1. 字の大きさ" in saved and "## 2. コントラスト" in saved
    assert "手で見る" in saved


def test_基準を満たす板だけなら終了コード0(tmp_path, capsys):
    code = typecheck.main(["calc", "--no-save"])
    assert code == 0
    assert "切るものはありません" in capsys.readouterr().out


def test_型で絞る():
    picked = typecheck._filter(typecheck.samples(), ["stats", "convert"])
    assert sorted(picked) == ["convert（2段）", "convert（3段）", "stats"]


def test_見本は全部の型をそろえている(tmp_path):
    """`cards.CARD_TYPES` に型が足されたら、見本も足す（測り漏らさないため）。"""
    photos = typecheck._dummy_photos(tmp_path)
    kinds = {str(spec["type"]) for spec in typecheck.samples(photos).values()}
    missing = set(cards.CARD_TYPES) - kinds
    assert not missing, f"見本の無い型: {sorted(missing)}（typecheck.samples に足す）"


def test_赤ペンの添え書きは画面に直接描くので縮まない():
    rows = typecheck.mark_rows(_config())
    assert rows
    assert all(row.scale == 1.0 for row in rows)
    from src import marks

    assert {row.asked for row in rows} == {int(v) for v in marks.NOTE_SIZES}
