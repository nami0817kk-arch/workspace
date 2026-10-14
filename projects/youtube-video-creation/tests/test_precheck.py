# -*- coding: utf-8 -*-
"""見せる前の点検を1コマンドで当てる道具（tools/precheck.py、2026-10-06「過去指摘内容は聞かれないで平気な作りにして」）。

項目ごとに、壊れた例が × になり、正しい例が ✓ になることを見る（✓ しか出ない点検は壊れていても気づけない）。
"""
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tools.precheck as pc  # noqa: E402
from src.script_model import parse_script  # noqa: E402

HEAD = "---\ntitle: 久保建英が語ったこと\n---\n\n"


def script(body: str, meta: str = ""):
    head = HEAD if not meta else f"---\ntitle: 久保建英が語ったこと\n{meta}\n---\n\n"
    return parse_script(head + body)


def marks(item):
    return [m for m, _ in item.found]


# ---------------------------------------------------------------- 1. draft の点検

class _Notes:
    def __init__(self, series="", voices=("ネット民",)):
        self.series = series
        self.sections = [type("S", (), {"voices": list(voices)})()]


@pytest.fixture
def draft_env(monkeypatch, tmp_path):
    """取材メモと research の関数を差し替える（draft と同じ並びで分け方だけを見る）。"""
    import src.plan
    import src.research as research

    notes_file = tmp_path / "x.yaml"
    notes_file.write_text("x", encoding="utf-8")
    monkeypatch.setattr(pc, "notes_path", lambda _p: notes_file)
    monkeypatch.setattr(src.plan, "load_plan", lambda: None)
    monkeypatch.setattr(research, "verify", lambda n, p: [])
    monkeypatch.setattr(research, "check_repeats", lambda n, p: [])
    state = {"notes": _Notes(), "hints": []}
    monkeypatch.setattr(research, "load_notes", lambda _p: state["notes"])
    monkeypatch.setattr(research, "advise", lambda n, p: list(state["hints"]))
    script_file = tmp_path / "x.md"
    script_file.write_text("x", encoding="utf-8")
    later = time.time() + 10
    os.utime(script_file, (later, later))
    return state, script_file


BODY_OK = "## オープニング\nキャスター: 久保建英が語ったこと。\n\n## 山場\n@main: true\nキャスター: 久保建英の言葉です。\n久保建英: 勝ててよかった。\n"


def test_draftの止める指摘はバツ(draft_env):
    state, path = draft_env
    state["hints"] = ["節A と 節B で同じことを言っています（『勝ててよかった』）"]
    item = pc.check_draft(path, script(BODY_OK, "topic: 久保建英"))
    assert pc.BAD in marks(item)


def test_draftのヒントは三角で出典の数え方は出さない(draft_env):
    state, path = draft_env
    state["hints"] = ["節『X』は数字の行が3行ありますが、画面に表を出していません",
                      "theme.hook が空です。**その行は出しません**"]
    item = pc.check_draft(path, script(BODY_OK, "topic: 久保建英"))
    assert marks(item) == [pc.WARN]
    assert "1件" in item.note


def test_draftが通ればまる(draft_env):
    _, path = draft_env
    item = pc.check_draft(path, script(BODY_OK, "topic: 久保建英"))
    assert item.mark == pc.OK


def test_ニュースで反応が無ければバツ_シリーズなら三角(draft_env):
    state, path = draft_env
    state["notes"] = _Notes(voices=("久保建英",))
    assert pc.BAD in marks(pc.check_draft(path, script(BODY_OK, "topic: 久保建英")))
    state["notes"] = _Notes(series="監督の経歴", voices=("久保建英",))
    assert marks(pc.check_draft(path, script(BODY_OK, "topic: 久保建英"))) == [pc.WARN]


def test_取材メモが無ければ三角(monkeypatch, tmp_path):
    monkeypatch.setattr(pc, "notes_path", lambda _p: tmp_path / "none.yaml")
    item = pc.check_draft(tmp_path / "x.md", script(BODY_OK))
    assert marks(item) == [pc.WARN]


# ---------------------------------------------------------------- 2. 語りの長さ

def test_語りが40字を超えればバツ():
    long = "あ" * 41
    item = pc.check_line_length(script(f"## 節\nキャスター: {long}\n"))
    assert marks(item) == [pc.BAD]


def test_40字までと字幕の無い行と本人の言葉はまる():
    body = ("## 節\nキャスター: " + "あ" * 40 + "\n解説: " + "い" * 60 + "\n  no_telop: true\n"
            "久保建英: " + "う" * 60 + "\n")
    assert pc.check_line_length(script(body)).mark == pc.OK


# ---------------------------------------------------------------- 3. 言ってはいけない言い方

@pytest.mark.parametrize("line", [
    "英紙ガーディアンは、代表が彼の力を引き出したと書きました。",
    "この話は、どの記事にも書かれていません。",
    "このチャンネルでは9月6日に、ミランを扱いました。",
    "試合は2-1でした。",
    "ゴール前に現れて、蹴る。それだけです。",
    "掲示板のまとめには15件の書き込みがありました。",
])
def test_言ってはいけない言い方はバツ(line):
    item = pc.check_wording(script(f"## 節\nキャスター: {line}\nキャスター: 次の話です。\n"))
    assert pc.BAD in marks(item), line


def test_引用の前置きの媒体名と季の書き方はまる():
    body = ("## 節\nキャスター: スペイン紙マルカは、こう書きました。\n久保建英: 勝ててよかった。\n"
            "キャスター: 2025-26シーズンは、2対1で勝ちました。\n")
    assert pc.check_wording(script(body)).mark == pc.OK


# ---------------------------------------------------------------- 4. ネットの反応

def test_反応が4件ならバツ():
    body = "## ネットの反応\n" + "".join(f"ネット民: 反応{i}です。\n" for i in range(4))
    assert pc.BAD in marks(pc.check_reactions(script(body)))


def test_続きの行は1件に数え_3件までならまる():
    body = ("## ネットの反応\nネット民: " + "あ" * 30 + "。\nネット民: " + "い" * 30 + "。\n  cont: true\n"
            "ネット民: 二件目です。\nネット民: 三件目です。\n")
    assert pc.check_reactions(script(body)).mark == pc.OK


def test_長い反応を分けていなければバツ():
    text = "あ" * 30 + "。" + "い" * 30 + "。"
    assert pc.BAD in marks(pc.check_reactions(script(f"## ネットの反応\nネット民: {text}\n")))


# ---------------------------------------------------------------- 5. 本と本のあいだ

def _write(path: Path, title: str, lines: list[str]) -> Path:
    body = "".join(f"キャスター: {t}\n" for t in lines)
    path.write_text(f"---\ntitle: {title}\n---\n\n## オープニング\nキャスター: {title}。\n\n## 節\n{body}",
                    encoding="utf-8")
    return path


def test_同じ日の本と言い回しが重なればバツ_数字だけなら三角(monkeypatch, tmp_path):
    a = _write(tmp_path / "20261006_a.md", "久保建英の話",
               ["久保建英は右サイドから中へ切り込んで左足で決めました。", "シュートの成功率は36%です。"])
    b = _write(tmp_path / "20261006_b.md", "三笘薫の話",
               ["三笘薫も右サイドから中へ切り込んで左足で決めました。", "決まる見込みは36%でした。"])
    monkeypatch.setattr(pc, "neighbours", lambda targets: [a.resolve(), b.resolve()])
    item = pc.check_cross([a], {})[a]
    assert pc.BAD in marks(item)
    assert any(m == pc.WARN and "36%" in t for m, t in item.found)


def test_前の日の本との短い型の言い回しは三角(monkeypatch, tmp_path):
    a = _write(tmp_path / "20261006_a.md", "久保建英の話", ["監督は試合のあと、こう説明しています。"])
    b = _write(tmp_path / "20261005_b.md", "三笘薫の話", ["主将は会見で、こう説明しています。"])
    monkeypatch.setattr(pc, "neighbours", lambda targets: [a.resolve(), b.resolve()])
    item = pc.check_cross([a], {})[a]
    assert marks(item) == [pc.WARN]


def test_重ならなければまる(monkeypatch, tmp_path):
    a = _write(tmp_path / "20261006_a.md", "久保建英の話", ["久保建英は右から切り込みました。"])
    b = _write(tmp_path / "20261006_b.md", "三笘薫の話", ["三笘薫は左で仕掛けて抜きました。"])
    monkeypatch.setattr(pc, "neighbours", lambda targets: [a.resolve(), b.resolve()])
    assert pc.check_cross([a], {})[a].mark == pc.OK


def test_同じファイルは二度並べない(tmp_path):
    a = pc.ROOT / "scripts" / "20261006_team_brazil.md"
    pool = pc.neighbours([a, a])
    assert len(pool) == len(set(pool))


# ---------------------------------------------------------------- 6. 読み

def test_辞書に無い日本人の名前は三角_ある名前はまる(tmp_path):
    body = "## 節\nキャスター: 監督の言葉です。\n架空太郎監督: 勝ててよかった。\nキャスター: 久保建英さんも話しました。\n"
    item = pc.check_readings(tmp_path / "x.md", script(body), {"久保建英"}, use_engine=False)
    assert [t for m, t in item.found if m == pc.WARN] and "架空太郎" in item.found[0][1]
    ok = pc.check_readings(tmp_path / "x.md", script("## 節\nキャスター: 久保建英が決めました。\n"),
                           {"久保建英"}, use_engine=False)
    assert ok.mark == pc.OK


# ---------------------------------------------------------------- 7. 写真

def _noise(w: int, h: int, seed: int = 0) -> Image.Image:
    rng = np.random.default_rng(seed)
    return Image.fromarray(rng.integers(0, 255, (h, w, 3), dtype=np.uint8))


def _blur_fill(path: Path) -> Path:
    """縦写真を真ん中に置き、左右を同じ写真のぼかしで埋めた 16:9（記事の og:image に多い形）。"""
    photo = _noise(720, 1080, seed=1)
    bed = photo.resize((1920, 2880)).crop((0, 900, 1920, 1980)).filter(ImageFilter.GaussianBlur(30))
    bed.paste(photo, (600, 0))
    bed.save(path, quality=92)
    return path


def _photo_script(tmp_path: Path, image: Path):
    path = tmp_path / "20261006_photo.md"
    path.write_text("x", encoding="utf-8")
    body = f"## オープニング\nキャスター: 題です。\n\n## 節\nキャスター: 写真の行です。\n  image: {image.as_posix()}\n"
    return path, script(body)


def test_ぼかしで埋めた写真はバツ(tmp_path):
    image = _blur_fill(tmp_path / "fill.jpg")
    path, s = _photo_script(tmp_path, image)
    item = pc.check_photos(path, s)
    assert any(m == pc.BAD and "ぼかし" in t for m, t in item.found)


def test_全面がくっきりした写真はまる(tmp_path):
    image = tmp_path / "sharp.jpg"
    # 縦長にして、ショートの縦の画面でも引き伸ばさない大きさにする（横長はショートで1.78倍になり △）
    _noise(1200, 2160).save(image, quality=92)
    (tmp_path / "credits.json").write_text(json.dumps([{"file": "sharp.jpg", "source": "wikimedia",
                                                        "author": "someone"}]), encoding="utf-8")
    path, s = _photo_script(tmp_path, image)
    assert pc.check_photos(path, s).mark == pc.OK


def test_代理店の写真はバツ(tmp_path):
    image = tmp_path / "press.jpg"
    _noise(1920, 1080).save(image, quality=92)
    (tmp_path / "credits.json").write_text(json.dumps([{"file": "press.jpg", "source": "press",
                                                        "credit": "©Getty Images"}]), encoding="utf-8")
    path, s = _photo_script(tmp_path, image)
    assert any(m == pc.BAD and "代理店" in t for m, t in pc.check_photos(path, s).found)


def test_小さい写真を引き伸ばせばバツ(tmp_path):
    image = tmp_path / "small.jpg"
    _noise(640, 360).save(image, quality=92)
    path, s = _photo_script(tmp_path, image)
    assert any(m == pc.BAD and "倍に引き伸ばし" in t for m, t in pc.check_photos(path, s).found)


def test_台本が指す写真が無ければバツ(tmp_path):
    path, s = _photo_script(tmp_path, tmp_path / "gone.jpg")
    assert any(m == pc.BAD and "ありません" in t for m, t in pc.check_photos(path, s).found)


# ---------------------------------------------------------------- 8. 4コマの下見

def test_下見のバツはバツ_三角は三角(monkeypatch, tmp_path):
    a = tmp_path / "a.md"
    found = {False: [("×", "冒頭 0:03 (a) 冒頭に顔が1つも見つかりません")], True: [("△", "中ほど 顔に近い")]}
    monkeypatch.setattr(pc, "_preview_one", lambda args: (args[0], args[1], found[args[1]], "", 0.1))
    item = pc.run_previews([a], jobs=1)[a]
    assert item.found == [(pc.BAD, "本編: 冒頭 0:03 (a) 冒頭に顔が1つも見つかりません"), (pc.WARN, "ショート: 中ほど 顔に近い")]


def test_下見に何も無ければまる(monkeypatch, tmp_path):
    a = tmp_path / "a.md"
    monkeypatch.setattr(pc, "_preview_one", lambda args: (args[0], args[1], [], "", 0.1))
    assert pc.run_previews([a], jobs=1)[a].mark == pc.OK


# ---------------------------------------------------------------- 9. シリーズ

def test_シリーズの知らせは三角_ニュースは見ない(monkeypatch, tmp_path):
    import src.research as research

    notes_file = tmp_path / "x.yaml"
    notes_file.write_text("x", encoding="utf-8")
    monkeypatch.setattr(pc, "notes_path", lambda _p: notes_file)
    monkeypatch.setattr(research, "_advise_series_opening", lambda n: ["節『基礎DATA』: 強い一点がありません"])
    monkeypatch.setattr(research, "_advise_series_numbers", lambda n: [])
    monkeypatch.setattr(research, "load_notes", lambda _p: _Notes(series="監督の経歴"))
    assert marks(pc.check_series(tmp_path / "x.md")) == [pc.WARN]
    monkeypatch.setattr(research, "load_notes", lambda _p: _Notes(series=""))
    item = pc.check_series(tmp_path / "x.md")
    assert item.skipped and item.mark == pc.OK


def test_シリーズで知らせが無ければまる(monkeypatch, tmp_path):
    import src.research as research

    notes_file = tmp_path / "x.yaml"
    notes_file.write_text("x", encoding="utf-8")
    monkeypatch.setattr(pc, "notes_path", lambda _p: notes_file)
    monkeypatch.setattr(research, "_advise_series_opening", lambda n: [])
    monkeypatch.setattr(research, "_advise_series_numbers", lambda n: [])
    monkeypatch.setattr(research, "load_notes", lambda _p: _Notes(series="監督の経歴"))
    item = pc.check_series(tmp_path / "x.md")
    assert item.mark == pc.OK and "言葉の早さは見ない" in item.note


# ---------------------------------------------------------------- 10. 流れの点検の控え

def test_流れの控えが無いか古ければバツ_新しければまる(monkeypatch, tmp_path):
    monkeypatch.setattr(pc, "ROOT", tmp_path)
    s = tmp_path / "scripts" / "20261006_x.md"
    s.parent.mkdir()
    s.write_text("x", encoding="utf-8")
    assert pc.check_flow(s).mark == pc.BAD                       # 無い
    record = tmp_path / "output" / "flow" / "20261006_x.md"
    record.parent.mkdir(parents=True)
    record.write_text("# 流れの点検", encoding="utf-8")
    old = time.time() - 100
    os.utime(record, (old, old))
    assert pc.check_flow(s).mark == pc.BAD                       # 台本より古い
    new = time.time() + 100
    os.utime(record, (new, new))
    assert pc.check_flow(s).mark == pc.OK


# ---------------------------------------------------------------- まとめ

def test_手で見る行は表から出し_書き出しのあとの行は1行にまとめる(capsys):
    pc.print_hand_rules([("**1本に問いは1つ**。それに答えない節は入れない", "09-22"),
                         ("**動画を送る前に facecheck を回す**", "10-03")])
    out = capsys.readouterr().out
    assert " 1. 1本に問いは1つ" in out
    assert "書き出したあと" in out and "動画を送る前に" in out
