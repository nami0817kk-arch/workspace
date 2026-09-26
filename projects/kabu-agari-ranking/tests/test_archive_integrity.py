"""実際の data/ に当てる検査。

ここだけは作り物ではなく本物のデータを見る。data/ は取り直しのきかない
資産で、ファイル名と中身の日付のずれのような壊れ方は、見た目には何も
起きないまま進む。push のたびに CI が気づけるようにしておく。
"""
from pathlib import Path

import validate

_DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def test_保存済みデータに矛盾が無い():
    problems = validate.archive_problems(_DATA_DIR)
    assert not problems, "data/ の矛盾:\n" + "\n".join(problems)


def test_検査そのものが働いている(tmp_path):
    # 検査が常に空を返すだけになっていないことを見る
    (tmp_path / "2026-09-18.json").write_text(
        '{"rec_date": "2026-09-17", "gainers": []}', encoding="utf-8"
    )
    assert validate.archive_problems(tmp_path)


def test_読み替え後の日付が重なったら赤にする(tmp_path):
    # 2026-08-31 は 2026-09-01 に読み替えられる。09-02 のファイルが増えると、
    # 09-01.json（→09-02）と重なる。読み替えの連鎖を踏まえて見る必要がある。
    for name, rec in (("2026-09-01", "2026-09-01"), ("2026-09-02", "2026-09-02")):
        (tmp_path / f"{name}.json").write_text(
            f'{{"rec_date": "{rec}", "gainers": []}}', encoding="utf-8"
        )
    problems = validate.archive_problems(tmp_path)
    assert any("二重" in p for p in problems), problems
