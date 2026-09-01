# ir-analysis

株探の適時開示から PDF を取得し、Claude API（haiku）で分析して Excel に出す。
日次の投資判断の材料づくりが目的。**分析の失敗で全体を止めない**設計
（API エラーは neutral / low に落として続行する）。

## 前提

- Python 3.12。依存は `requirements.txt` に `==` で固定（.venv の実測値）。`>=` に緩めない。
- API キーは `.env`（gitignore 済み）。キー名は `.env.example` にある。
- モデルは `claude-haiku-4-5-20251001` を使う（コスト優先。1日数十件を回すため）。
- `data/` 配下（PDF・レポート・DB）は全て gitignore 済みの生成物。手で消してよい。

## よく使うコマンド

```bash
pytest                                 # テスト（ネットワーク不要）
python main.py run --category kessan   # 決算のみ取得・分析
```

## 手を入れるときに気をつけること

- `extract_pdf_links_from_html` は取得先の HTML 構造に依存。壊れると例外ではなく
  「0件」になり気づきにくい。テストの固定 HTML と合わせて更新する。
- `analyze_ir` は API 失敗時に例外を投げず neutral に落とす。バッチ全体を
  1件の失敗で止めないための意図的な設計。握りつぶしに見えるが消さない。
- Claude の応答は JSON を期待しているが ```json フェンス付きで返ることがあり、
  その剥がし処理が入っている。プロンプトを変えるときはここも確認する。
