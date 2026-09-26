# shaho-tekiyo

社会保険（健康保険・厚生年金）の短時間労働者への適用拡大について、
「自分は加入対象になるか」を判定する静的サイト。詳しい背景・設計判断は `CLAUDE.md` を参照。

## 開発

```bash
python -m venv .venv
source .venv/bin/activate   # Windows は .venv\Scripts\Activate.ps1
pip install -r requirements.txt pytest

pytest                  # テスト
python src/render.py    # output/ に静的サイトを生成
```

## 構成

- `src/eligibility.py` — 加入判定ロジック（法定の適用日程）
- `src/render.py` — 静的サイト生成
- `src/site_config.py` — 公開ドメイン・名義・連絡先
- `templates/` — Jinja2 テンプレート
- `tests/` — pytest
