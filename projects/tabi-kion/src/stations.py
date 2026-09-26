"""ページを作る地点。気象庁の地上気象観測（気象台・特別地域気象観測所）の地点だけを使う。

**地点名は観測所の名前のまま出す。** 観光地の名前に置き換えると、別の場所の数字を
その観光地の数字のように見せることになる。近くの観光地は `nearby` に「近くの観光地」として
書き添えるだけにする（例: 網代は熱海市にあるが、ページ名は「網代」）。

slug は URL に使う。一度公開したら変えない（検索の評価がリセットされる）。
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Station:
    code: str  # 気象庁の地点番号（5桁）
    name: str  # 観測所名（気象庁の表記）
    slug: str
    pref: str
    nearby: str = ""  # 近くの観光地（観測所の名前と違うときだけ）


STATIONS: tuple[Station, ...] = (
    Station("47412", "札幌", "sapporo", "北海道"),
    Station("47411", "小樽", "otaru", "北海道"),
    Station("47430", "函館", "hakodate", "北海道"),
    Station("47407", "旭川", "asahikawa", "北海道", "旭山動物園・美瑛"),
    Station("47418", "釧路", "kushiro", "北海道", "釧路湿原"),
    Station("47409", "網走", "abashiri", "北海道", "知床・流氷"),
    Station("47433", "倶知安", "kutchan", "北海道", "ニセコ"),
    Station("47575", "青森", "aomori", "青森県", "奥入瀬・八甲田"),
    Station("47584", "盛岡", "morioka", "岩手県"),
    Station("47590", "仙台", "sendai", "宮城県", "松島"),
    Station("47690", "日光", "nikko", "栃木県", "中禅寺湖・奥日光"),
    Station("47622", "軽井沢", "karuizawa", "長野県"),
    Station("47618", "松本", "matsumoto", "長野県", "上高地・安曇野"),
    Station("47610", "長野", "nagano", "長野県", "善光寺"),
    Station("47640", "河口湖", "kawaguchiko", "山梨県", "富士五湖"),
    Station("47617", "高山", "takayama", "岐阜県", "飛騨高山・白川郷"),
    Station("47605", "金沢", "kanazawa", "石川県"),
    Station("47600", "輪島", "wajima", "石川県", "能登"),
    Station("47668", "網代", "ajiro", "静岡県", "熱海"),
    Station("47666", "石廊崎", "irozaki", "静岡県", "南伊豆"),
    Station("47759", "京都", "kyoto", "京都府"),
    Station("47780", "奈良", "nara", "奈良県"),
    Station("47778", "潮岬", "shionomisaki", "和歌山県", "南紀白浜・串本"),
    Station("47741", "松江", "matsue", "島根県", "出雲"),
    Station("47765", "広島", "hiroshima", "広島県", "宮島"),
    Station("47893", "高知", "kochi", "高知県"),
    Station("47817", "長崎", "nagasaki", "長崎県"),
    Station("47815", "大分", "oita", "大分県", "別府・湯布院"),
    Station("47819", "熊本", "kumamoto", "熊本県", "阿蘇"),
    Station("47827", "鹿児島", "kagoshima", "鹿児島県", "桜島"),
    Station("47836", "屋久島", "yakushima", "鹿児島県"),
    Station("47909", "名瀬", "naze", "鹿児島県", "奄美大島"),
    Station("47936", "那覇", "naha", "沖縄県"),
    Station("47940", "名護", "nago", "沖縄県", "沖縄北部・美ら海水族館"),
    Station("47918", "石垣島", "ishigakijima", "沖縄県", "竹富島・小浜島"),
    Station("47927", "宮古島", "miyakojima", "沖縄県"),
    Station("47678", "八丈島", "hachijojima", "東京都"),
    Station("47662", "東京", "tokyo", "東京都"),
    Station("47772", "大阪", "osaka", "大阪府"),
    Station("47636", "名古屋", "nagoya", "愛知県"),
    Station("47807", "福岡", "fukuoka", "福岡県"),
)

BY_CODE = {s.code: s for s in STATIONS}
BY_SLUG = {s.slug: s for s in STATIONS}

# 比べる相手の地点（出発地として多いところ）。ページに「東京より◯℃低い」と出す。
COMPARE_WITH: tuple[str, ...] = ("47662", "47772")
