import pytest

from src.config import ConfigError, build_config, load_config

RAW = {
    "video": {"width": 1280, "height": 720},
    "voicevox": {"pause": 0.5},
    "cast": {
        "霊夢": {"key": "reimu", "style_id": 2, "aliases": ["れいむ"]},
        "魔理沙": {"key": "marisa", "style_id": 3},
    },
}


def test_build_config_defaults_and_overrides():
    config = build_config(RAW)
    assert config.video.width == 1280
    assert config.video.fps == 30  # 未指定は既定値
    assert config.voicevox.pause == 0.5


def test_resolve_speaker_by_name_alias_and_key():
    config = build_config(RAW)
    assert config.resolve_speaker("霊夢").key == "reimu"
    assert config.resolve_speaker("れいむ").key == "reimu"
    assert config.resolve_speaker("MARISA").key == "marisa"


def test_unknown_speaker_raises():
    config = build_config(RAW)
    with pytest.raises(ConfigError, match="ゆかり"):
        config.resolve_speaker("ゆかり")


def test_style_id_is_required():
    with pytest.raises(ConfigError, match="style_id"):
        build_config({"cast": {"霊夢": {"key": "reimu"}}})


def test_project_config_loads():
    config = load_config()
    assert config.cast
    assert config.video.font_path().exists()


# ---------------------------------------------------------------- 出力の文字コード
# Windows で出力をパイプに渡すと cp932 で書こうとして、
# kicker の見出しの ü や、画面の ✓ で落ちる。実運用のPCで見つかった。

def test_cp932の出力をUTF8にそろえる():
    import io

    from src.cli import _use_utf8

    raw = io.BytesIO()
    stream = io.TextIOWrapper(raw, encoding="cp932")
    _use_utf8(stream)

    stream.write("✓ kicker　Bürki trifft in der 97. Minute")
    stream.flush()
    assert "Bürki" in raw.getvalue().decode("utf-8")


def test_すでにUTF8なら触らない():
    import io

    from src.cli import _use_utf8

    stream = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
    _use_utf8(stream)
    assert stream.encoding.lower().replace("-", "") == "utf8"


def test_差し替えられた出力先でも落ちない():
    from src.cli import _use_utf8

    class Fake:
        encoding = "cp932"

    _use_utf8(Fake())   # reconfigure を持たない。例外を出さずに済ませる


# ---------------------------------------------------------------- 日本語フォント探し
# CI（ubuntu）には日本語フォントが入っていないので、テストが丸ごと回せなかった。
# apt で fonts-noto-cjk を入れれば済むが、ファイル名も置き場所も版ごとに変わる。
# パスを固定で書くと ubuntu が上がるたびに外れるので、置き場所を舐めて探す。

def test_明示の候補があればそれを使う(tmp_path, monkeypatch):
    from src import config as config_mod

    font = tmp_path / "explicit.ttc"
    font.write_bytes(b"x")
    monkeypatch.setattr(config_mod, "FONT_CANDIDATES", [str(font)])
    monkeypatch.setattr(config_mod, "FONT_DIRS", ())
    assert config_mod.VideoConfig().font_path() == font


def test_候補が外れても置き場所から見つける(tmp_path, monkeypatch):
    from src import config as config_mod

    (tmp_path / "opentype" / "noto").mkdir(parents=True)
    font = tmp_path / "opentype" / "noto" / "NotoSansCJK-Regular.ttc"
    font.write_bytes(b"x")

    monkeypatch.setattr(config_mod, "FONT_CANDIDATES", ["/nowhere/none.ttf"])
    monkeypatch.setattr(config_mod, "FONT_DIRS", (str(tmp_path),))
    assert config_mod.VideoConfig().font_path() == font


def test_どこにも無ければ入れ方まで言う(monkeypatch, tmp_path):
    from src import config as config_mod

    monkeypatch.setattr(config_mod, "FONT_CANDIDATES", ["/nowhere/none.ttf"])
    monkeypatch.setattr(config_mod, "FONT_DIRS", (str(tmp_path),))
    with pytest.raises(config_mod.ConfigError, match="fonts-noto-cjk"):
        config_mod.VideoConfig().font_path()


# 声の掛け合いは「ニュースを読む人」と「誰かの声を代弁する人」の2役。
# **代弁は人ごとに声が変わる**（2026-09-05 のユーザー判断）。
# 出てくる人を全部 config に書くのは無理なので、名前から声を決める。


def _with_pool(raw=None):
    from src.config import build_config

    # **深くコピーする。**浅いコピーだと入れ子の dict を共有し、
    # RAW 側に voice_pool が残って別のテストの結果を変えてしまう
    import copy

    raw = copy.deepcopy(raw if raw is not None else RAW)
    raw.setdefault("voicevox", {})["voice_pool"] = [3, 8, 9, 10, 11]
    return build_config(raw)


def test_同じ名前はいつも同じ声():
    """乱数で選ぶと「前回と声が違う」が起きて、同じ人だと分からなくなる。"""
    config = _with_pool()

    first = config.resolve_speaker("キャラガー").style_id
    again = config.resolve_speaker("キャラガー").style_id

    assert first == again


def test_人が違えば声も違う():
    config = _with_pool()

    voices = {config.resolve_speaker(n).style_id
              for n in ("キャラガー", "イラオラ監督", "ネット民", "遠藤航")}

    assert len(voices) >= 2      # 全員同じ声にはならない


def test_configに書いた話者は設定どおり():
    """読み手（キャスター）は固定。代弁の割り当てに巻き込まない。"""
    config = _with_pool()

    member = config.resolve_speaker(next(iter(config.cast)))

    assert member.style_id in {m.style_id for m in config.cast.values()}


def test_候補が無ければ今までどおり弾く():
    """voice_pool を空にすれば、未登録の話者はエラーのまま。"""
    import pytest

    from src.config import ConfigError, build_config

    config = build_config(RAW)

    with pytest.raises(ConfigError):
        config.resolve_speaker("知らない人")


def test_声は候補の中から選ぶ():
    config = _with_pool()

    for name in ("A", "B", "C", "D", "E", "F", "G"):
        assert config.resolve_speaker(name).style_id in config.voice_pool
