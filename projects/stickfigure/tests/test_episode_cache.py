"""エピソードの場面ごとの保存: 目印は同じ場面なら同じ、台本・絵が変われば変わる。前回と同じ目印なら mp4 を使い回す。"""
from stickfig import episode


def _scene(**kw):
    sc = dict(name="s", tau_end=2.0, keys={"A": [dict(t=0.0, dx=0.0)]}, fx=dict(props=[]))
    sc.update(kw)
    return sc


def test_key_is_stable_and_changes_with_scene():
    a, b = _scene(), _scene()
    assert episode.scene_key(a) == episode.scene_key(b)
    assert episode.scene_key(a) != episode.scene_key(_scene(tau_end=2.5))


def test_key_changes_when_referenced_image_changes(tmp_path):
    img = tmp_path / "bg.png"
    img.write_bytes(b"one")
    sc = _scene(stage=dict(image=str(img)))
    k1 = episode.scene_key(sc)
    img.write_bytes(b"two")
    assert episode.scene_key(sc) != k1


def test_cached_returns_mp4_only_for_same_key(tmp_path):
    (tmp_path / "s.mp4").write_bytes(b"x")
    (tmp_path / "scene_key.txt").write_text("abc s.mp4", encoding="utf-8")
    assert episode._cached(tmp_path, "abc") == tmp_path / "s.mp4"
    assert episode._cached(tmp_path, "zzz") is None
    (tmp_path / "s.mp4").unlink()
    assert episode._cached(tmp_path, "abc") is None
