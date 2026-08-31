import io
import time
from datetime import date, datetime
from pathlib import Path

import pdfplumber
import requests
from bs4 import BeautifulSoup

BASE_URL = "https://s.kabutan.jp/disclosures/"
PDF_BASE = "https://tdnet-pdf.kabutan.jp"
DATA_DIR = Path(__file__).parent.parent.parent / "data" / "pdfs"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
}

CATEGORY_MAP = {
    "kessan":  "決算",
    "gyoseki": "業績修正",
    "haitou":  "配当",
    "jishakab": "自社株買い",
    "zoshi":   "増資",
}


def fetch_disclosure_list(target_date: str | None = None, category: str | None = None) -> list[dict]:
    """
    株探の適時開示一覧を取得する。
    target_date: "YYYY-MM-DD" 形式。省略時は当日。
    category: "kessan" / "gyoseki" / "haitou" など。省略時は全件。
    """
    params = {}
    if target_date:
        params["date"] = target_date
    if category:
        params["category"] = category

    resp = requests.get(BASE_URL, params=params, headers=HEADERS, timeout=15)
    resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")
    results = []

    for row in soup.select("table.si-table tbody tr, ul.si-list li, div.disclosure-item, tr"):
        pdf_tag = row.find("a", href=lambda h: h and "tdnet-pdf.kabutan.jp" in h)
        if not pdf_tag:
            continue

        pdf_url = pdf_tag["href"]
        title = pdf_tag.get_text(strip=True) or row.get_text(" ", strip=True)[:80]

        company_tag = row.find("a", href=lambda h: h and "/stocks/" in h)
        company = company_tag.get_text(strip=True) if company_tag else ""

        code_tag = row.find(class_=lambda c: c and "code" in c.lower()) if row.get("class") else None
        code = code_tag.get_text(strip=True) if code_tag else ""

        results.append({
            "company": company,
            "code":    code,
            "title":   title,
            "pdf_url": pdf_url,
            "date":    target_date or str(date.today()),
        })

    return results


def extract_pdf_links_from_html(html: str) -> list[dict]:
    """HTMLからPDFリンクを直接抽出する（フォールバック用）。"""
    soup = BeautifulSoup(html, "html.parser")
    results = []
    seen = set()

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if "tdnet-pdf.kabutan.jp" not in href or href in seen:
            continue
        seen.add(href)

        title = a.get_text(strip=True)
        parent_text = a.parent.get_text(" ", strip=True) if a.parent else ""

        results.append({
            "company": "",
            "code":    "",
            "title":   title or parent_text[:80],
            "pdf_url": href,
            "date":    str(date.today()),
        })

    return results


def fetch_disclosures(target_date: str | None = None, category: str | None = None) -> list[dict]:
    """開示一覧を取得し、PDFリンクを確実に返す。"""
    params = {}
    if target_date:
        params["date"] = target_date
    if category:
        params["category"] = category

    resp = requests.get(BASE_URL, params=params, headers=HEADERS, timeout=15)
    resp.raise_for_status()

    items = extract_pdf_links_from_html(resp.text)
    return items


def download_pdf(pdf_url: str) -> bytes | None:
    """PDFをダウンロードしてバイト列を返す。"""
    try:
        resp = requests.get(pdf_url, headers=HEADERS, timeout=30)
        resp.raise_for_status()
        return resp.content
    except Exception as e:
        print(f"  [warn] PDF取得失敗: {pdf_url} — {e}")
        return None


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """pdfplumberでPDFからテキストを抽出する。"""
    text_parts = []
    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    text_parts.append(t)
    except Exception as e:
        return f"[PDF解析エラー: {e}]"
    return "\n".join(text_parts)


def fetch_and_extract(target_date: str | None = None, category: str | None = None, max_items: int = 20) -> list[dict]:
    """
    開示一覧取得 → PDF取得 → テキスト抽出 を一括で行う。
    各アイテムに "text" キーを追加して返す。
    """
    items = fetch_disclosures(target_date=target_date, category=category)
    if not items:
        print("開示情報が見つかりませんでした。")
        return []

    print(f"  {len(items)} 件の開示情報を取得（上位 {max_items} 件を処理）")
    results = []

    for item in items[:max_items]:
        pdf_bytes = download_pdf(item["pdf_url"])
        if pdf_bytes:
            item["text"] = extract_text_from_pdf(pdf_bytes)
        else:
            item["text"] = ""
        results.append(item)
        time.sleep(0.5)

    return results
