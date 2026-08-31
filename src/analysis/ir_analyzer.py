import os
from pathlib import Path
import anthropic
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).parent.parent.parent / ".env")

_client: anthropic.Anthropic | None = None

SYSTEM_PROMPT = """あなたは日本株のスイングトレードを支援するIRアナリストです。
企業の適時開示・IR資料を読み、スイングトレーダーにとって重要な情報を簡潔に抽出してください。"""

ANALYSIS_PROMPT = """以下のIR資料を分析してください。

【企業情報】
企業名: {company}
開示タイトル: {title}
開示日: {date}

【本文】
{text}

---
以下の形式でJSON形式で回答してください（日本語）:

{{
  "summary": "3行以内の要約",
  "impact": "positive / negative / neutral",
  "impact_reason": "株価への影響理由（1〜2文）",
  "key_points": ["重要ポイント1", "重要ポイント2", "重要ポイント3"],
  "swing_relevance": "high / medium / low",
  "swing_note": "スイングトレードの観点からのコメント（1文）",
  "numbers": {{
    "売上": "数値があれば",
    "営業利益": "数値があれば",
    "修正内容": "上方修正・下方修正など"
  }}
}}

JSONのみ出力してください。余計なテキストは不要です。"""


def get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))
    return _client


def analyze_ir(item: dict, max_text_chars: int = 3000) -> dict:
    """
    IRテキストをClaude APIで分析し、結果をitemに追記して返す。
    item には company / title / date / text が必要。
    """
    text = item.get("text", "")
    if not text.strip():
        item["analysis"] = {"summary": "テキスト取得不可", "impact": "neutral", "swing_relevance": "low"}
        return item

    truncated = text[:max_text_chars]
    if len(text) > max_text_chars:
        truncated += "\n...(以下省略)"

    prompt = ANALYSIS_PROMPT.format(
        company=item.get("company", "不明"),
        title=item.get("title", ""),
        date=item.get("date", ""),
        text=truncated,
    )

    try:
        client = get_client()
        message = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = message.content[0].text.strip()

        import json
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        item["analysis"] = json.loads(raw)

    except Exception as e:
        item["analysis"] = {
            "summary": f"分析エラー: {e}",
            "impact": "neutral",
            "swing_relevance": "low",
        }

    return item


def analyze_batch(items: list[dict], verbose: bool = True) -> list[dict]:
    """複数のIRアイテムを順番に分析する。"""
    results = []
    for i, item in enumerate(items, 1):
        if verbose:
            print(f"  [{i}/{len(items)}] 分析中: {item.get('title', '')[:40]}")
        analyze_ir(item)
        results.append(item)
    return results
