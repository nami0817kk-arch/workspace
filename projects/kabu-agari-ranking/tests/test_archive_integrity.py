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
