"""公開前の点検。書き出したものを、出す前にひととおり見る。

チェックリストを人が目で追うと、疲れている日ほど飛ばす。
機械で確かめられるものは機械にやらせ、人にしか見られないものだけ残す。
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .script_model import Script
from .subtitles import chapters

# YouTube の実務上の上限。超えると切られる
TITLE_LIMIT = 100
DESCRIPTION_LIMIT = 5000
# 参考チャンネルの尺。短すぎても長すぎても離脱する
MIN_SECONDS = 90
MAX_SECONDS = 240


@dataclass
class Finding:
    ok: bool
    label: str
    detail: str = ""

    def line(self) -> str:
        return f"  {'✓' if self.ok else '×'} {self.label}" + (
            f"　{self.detail}" if self.detail else ""
        )


def inspect(script: Script, out_dir: Path, duration: float | None = None) -> list[Finding]:
    """出せる状態かを見る。× が1つでもあれば直してから出す。"""
    findings: list[Finding] = []

    findings.append(_length("タイトル", script.title, TITLE_LIMIT))

    description = out_dir / "description.txt"
    if description.exists():
        body = description.read_text(encoding="utf-8")
        findings.append(_length("概要欄", body, DESCRIPTION_LIMIT))
    else:
        findings.append(Finding(False, "概要欄", "description.txt がありません"))

    findings.append(_tags(script))
    findings.append(_files(out_dir))
    findings.append(_sources(script))
    findings.append(_tiers(script))
    findings.append(_marks(script))
    findings.append(check_subtitles(out_dir / "subtitles.srt"))
    # ここから下は「完成品」を見る点検。2026-09-04 に見つけた不具合は
    # ぜんぶ目視か実測で出たもので、書式の点検は1件も拾えていなかった。
    # **見て見つけたものは、その場で直すだけでなく、ここに足す。**
    findings.append(_caption_load(out_dir / "subtitles.srt"))
    findings.append(_caption_badges(out_dir / "subtitles.srt"))
    findings.append(_still_length(out_dir / "script.json"))
    findings.append(_screen_change(out_dir / "script.json"))
    findings.append(_photo_credits(script, out_dir))
    findings.append(_double_marks(script))
    loudness = _loudness(out_dir / "video.mp4")
    if loudness is not None:
        findings.append(loudness)
    if duration is not None:
        findings.append(_duration(duration))
    return findings


# 字幕1枚の上限。話者名を足すぶんを見込んで、subtitles 側の上限に余裕を持たせる
CAPTION_MAX = 38
STILL_MAX = 12.0
TIER_MARKS = ("[確定]", "[報道]", "[未確認]", "[背景]")


def _cues(srt_path: Path) -> list[str]:
    import re

    if not srt_path.exists():
        return []
    body = srt_path.read_text(encoding="utf-8")
    return [
        m.group(1).replace("\n", "")
        for m in re.finditer(
            r"\d+\n[\d:,]+ --> [\d:,]+\n(.+?)(?:\n\n|\Z)",
            body, re.S,
        )
    ]


def _caption_load(srt_path: Path) -> Finding:
    """字幕1枚に載る量。多いと目で追えない（テレビは全角15字×2行）。"""
    cues = _cues(srt_path)
    if not cues:
        return Finding(False, "字幕の量", "字幕が読めません")
    longest = max(cues, key=len)
    if len(longest) > CAPTION_MAX:
        return Finding(False, "字幕の量",
                       f"{len(longest)}字の枚があります（上限{CAPTION_MAX}）: {longest[:24]}…")
    return Finding(True, "字幕の量", f"{len(cues)}枚 / 最大{len(longest)}字")


def _caption_badges(srt_path: Path) -> Finding:
    """字幕に画面用の確度バッジが混ざっていないか。

    読み上げていない文字が字幕に出ると、聞こえた音と食い違う。
    """
    found = [m for m in TIER_MARKS if any(m in cue for cue in _cues(srt_path))]
    if found:
        return Finding(False, "字幕の中身",
                       f"画面用のバッジが混ざっています: {' '.join(found)}")
    return Finding(True, "字幕の中身", "読み上げた内容だけ")


def _still_length(script_json: Path) -> Finding:
    """1画面が止まっている時間。長いと見ていて飽きる。"""
    import json

    if not script_json.exists():
        return Finding(False, "画面の切り替わり", "script.json がありません")
    data = json.loads(script_json.read_text(encoding="utf-8"))
    spans = [
        (float(line.get("duration") or 0), (line.get("text") or "")[:20])
        for scene in data.get("scenes", [])
        for line in scene.get("lines", [])
    ]
    if not spans:
        return Finding(False, "画面の切り替わり", "画面が1枚もありません")
    longest, text = max(spans)
    if longest > STILL_MAX:
        return Finding(False, "画面の切り替わり",
                       f"{longest:.1f}秒 止まる画面があります（上限{STILL_MAX:.0f}秒）: {text}…")
    average = sum(s for s, _ in spans) / len(spans)
    return Finding(True, "画面の切り替わり",
                   f"{len(spans)}枚 / 平均{average:.1f}秒 / 最長{longest:.1f}秒")


SAME_SCREEN_MAX = 20.0


def _screen_change(script_json: Path) -> Finding:
    """見た目が変わらないまま続く時間。

    1枚あたりの秒数が短くても、**カードもテロップも同じなら画面は止まって
    見える。**2026-09-04 に contact で一覧にして初めて気づいた。
    「なぜ外れたのか」の節は7枚つづけて同じカードと同じテロップで、
    約40秒ぶん見た目が変わっていなかった。
    """
    import json

    if not script_json.exists():
        return Finding(False, "見た目の変化", "script.json がありません")
    data = json.loads(script_json.read_text(encoding="utf-8"))
    look = None
    span = 0.0
    worst = 0.0
    worst_telop = ""
    for scene in data.get("scenes", []):
        for line in scene.get("lines", []):
            now = (line.get("telop") or "", line.get("card") or "", line.get("image") or "")
            if now == look:
                span += float(line.get("duration") or 0)
            else:
                look, span = now, float(line.get("duration") or 0)
            if span > worst:
                worst, worst_telop = span, now[0]
    if worst > SAME_SCREEN_MAX:
        return Finding(False, "見た目の変化",
                       f"{worst:.0f}秒 変わらない場面があります"
                       f"（上限{SAME_SCREEN_MAX:.0f}秒）: {worst_telop[:24]}")
    return Finding(True, "見た目の変化", f"変わらない最長 {worst:.0f}秒")


def _photo_credits(script: Script, out_dir: Path) -> Finding:
    """使った写真のクレジットが概要欄に出ているか。

    **CC BY 系は表示が必須。**出ていないと利用条件を満たさないまま公開になる。
    実測（2026-09-04）で、行に差し込んだ写真が1件も拾われていなかった。
    """
    used = sorted({
        Path(line.image).name for line in script.lines if getattr(line, "image", None)
    })
    if not used:
        return Finding(True, "写真のクレジット", "写真を使っていません")
    description = out_dir / "description.txt"
    if not description.exists():
        return Finding(False, "写真のクレジット", "概要欄がありません")
    body = description.read_text(encoding="utf-8")
    credits = [ln for ln in body.splitlines() if ln.startswith("画像:")]
    if len(credits) < len(used):
        return Finding(False, "写真のクレジット",
                       f"写真{len(used)}枚に対しクレジット{len(credits)}件。"
                       "CC BY 系は表示が必須です")
    return Finding(True, "写真のクレジット", f"写真{len(used)}枚 / クレジット{len(credits)}件")


def _double_marks(script: Script) -> Finding:
    """句読点が二重になっていないか。合成音声が不自然に間を空ける。"""
    bad = [line.text for line in script.lines if line.text and ("。。" in line.text or "、、" in line.text)]
    if bad:
        return Finding(False, "読み上げの文", f"句読点が二重です: {bad[0][:30]}…")
    return Finding(True, "読み上げの文", "句読点の重なりなし")


def _loudness(video: Path) -> Finding | None:
    """音の大きさ。YouTube は -14 LUFS を基準に音量をそろえる。

    小さすぎると他チャンネルより静かに聞こえる。大きすぎると下げられる。
    """
    import json as _json
    import re
    import subprocess

    if not video.exists():
        return None
    try:
        import imageio_ffmpeg

        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None
    try:
        result = subprocess.run(
            [ffmpeg, "-i", str(video), "-af", "loudnorm=I=-14:TP=-1.5:print_format=json",
             "-f", "null", "-"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    match = re.search(r"\{[^{}]*input_i[^{}]*\}", result.stderr or "", re.S)
    if not match:
        return None
    try:
        measured = float(_json.loads(match.group(0))["input_i"])
    except (ValueError, KeyError):
        return None
    gap = measured - (-14.0)
    if abs(gap) > 2.0:
        way = "小さい" if gap < 0 else "大きい"
        return Finding(False, "音の大きさ",
                       f"{measured:.1f} LUFS（基準 -14 より{abs(gap):.1f} dB {way}）")
    return Finding(True, "音の大きさ", f"{measured:.1f} LUFS（基準 -14）")


def _tags(script: Script) -> Finding:
    """タグ。YouTube は合計500字までで、超えると投稿そのものが弾かれる。"""
    from . import tags as tags_mod

    if not script.tags:
        return Finding(False, "タグ", "1つもありません。検索から見つけてもらえません")
    length = tags_mod.text_length(script.tags)
    long_ones = [t for t in script.tags if len(t) > tags_mod.MAX_TAG_LENGTH]
    if long_ones:
        return Finding(False, "タグ", f"長すぎるタグがあります: {long_ones[0]}")
    if length > tags_mod.MAX_TAGS_TEXT:
        return Finding(False, "タグ", f"合計{length}字（上限{tags_mod.MAX_TAGS_TEXT}字）")
    return Finding(True, "タグ", f"{len(script.tags)}個 / 合計{length}字")


def built_duration(out_dir: Path) -> float | None:
    """ビルドで書き出した script.json から実尺を読む。

    台本ファイル自体には時刻が入っていない（ビルドのときに決まる）ので、
    書き出しの結果を見る。まだビルドしていなければ尺の判定を飛ばす。
    """
    target = out_dir / "script.json"
    if not target.exists():
        return None
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None

    end = 0.0
    for scene in data.get("scenes") or []:
        for line in scene.get("lines") or []:
            end = max(end, float(line.get("start", 0)) + float(line.get("duration", 0)))
    return end or None


def manual_checks() -> list[str]:
    """機械では見られないもの。人が目と耳で確かめる。"""
    return [
        "出典URLを開いて、記事が消えたり内容が変わったりしていないか",
        "確度バッジが画面で正しく出ているか（確定と未確認の取り違えは致命的）",
        "選手名・クラブ名の読み上げが合っているか",
        "サムネの文字が切れていないか、一覧で見て読めるか",
        "BGMがナレーションを潰していないか",
    ]


def _length(label: str, text: str, limit: int) -> Finding:
    size = len(text)
    return Finding(size <= limit, label, f"{size}文字 / 上限{limit}")


def _files(out_dir: Path) -> Finding:
    needed = ["video.mp4", "thumbnail.png", "subtitles.srt", "description.txt"]
    missing = [name for name in needed if not (out_dir / name).exists()]
    if missing:
        return Finding(False, "書き出し", f"足りない: {', '.join(missing)}")
    return Finding(True, "書き出し", f"{len(needed)}件そろっている")


def _sources(script: Script) -> Finding:
    if not script.sources:
        return Finding(False, "出典", "1本もありません")
    return Finding(True, "出典", f"{len(script.sources)}本")


def _tiers(script: Script) -> Finding:
    """確度の付け忘れを見る。ニュースで確度なしの行が続くのは危ない。"""
    labelled = [line for line in script.lines if line.source]
    if not labelled:
        return Finding(False, "確度", "どの行にも source が付いていません")
    return Finding(True, "確度", f"{len(labelled)}行に付いている")


def _marks(script: Script) -> Finding:
    marks = chapters(script)
    if len(marks) < 2:
        return Finding(False, "チャプター", "章が1つしかありません")
    if marks[0][0] != 0.0:
        return Finding(False, "チャプター", "最初が 0:00 になっていません")
    times = [t for t, _ in marks]
    if times != sorted(times):
        return Finding(False, "チャプター", "時刻の順番が乱れています")
    return Finding(True, "チャプター", f"{len(marks)}章")


def _duration(seconds: float) -> Finding:
    shown = f"{int(seconds) // 60}分{int(seconds) % 60}秒"
    if seconds < MIN_SECONDS:
        return Finding(False, "尺", f"{shown}　短すぎます（{MIN_SECONDS // 60}分以上に）")
    if seconds > MAX_SECONDS:
        return Finding(False, "尺", f"{shown}　長すぎます（{MAX_SECONDS // 60}分まで）")
    return Finding(True, "尺", shown)


def check_sources(urls: list[str], fetch=None) -> list[Finding]:
    """出典URLがまだ生きているかを、送る前に機械で見る。

    手引きには「出典URLを開いて確認しろ」とだけ書いてあったが、
    人は5本のURLを毎回は開かない。開かないまま upload に進むと、
    消えた記事を出典に載せた動画が出てしまう（投稿は取り返しがつかない）。

    見るのは生死だけ。内容が変わっていないかまでは機械には分からないので、
    そこは今までどおり目で見る。
    """
    import requests as requests_mod

    fetch = fetch or (lambda url: requests_mod.get(
        url, timeout=15, stream=True,
        headers={"User-Agent": "Mozilla/5.0 (news script builder; source check)"},
    ).status_code)

    findings: list[Finding] = []
    for url in urls:
        try:
            status = int(fetch(url))
        except Exception as error:
            findings.append(Finding(False, "出典URL", f"{url}　開けません（{type(error).__name__}）"))
            continue
        if status == 200:
            findings.append(Finding(True, "出典URL", url))
        elif status in (401, 403, 429):
            # ボット判定・有料の壁。kicker は生きている記事にも 403 を返す（実測）。
            # 消えた証拠ではないので止めないが、目で見る対象として残す
            findings.append(Finding(True, "出典URL", f"{url}　HTTP {status}（機械には開けない。目で確かめる）"))
        else:
            findings.append(Finding(False, "出典URL", f"{url}　HTTP {status}"))
    return findings


def check_subtitles(srt_path: Path) -> Finding:
    """字幕の時刻が壊れていないか。

    逆行・ゼロ秒表示・終了より後の開始は、プレイヤーでは黙って飛ばされるので
    投稿してからしか気づけない。書き出したファイルをそのまま読んで確かめる。
    """
    if not srt_path.exists():
        return Finding(False, "字幕", "subtitles.srt がありません")

    import re

    stamp = re.compile(
        r"(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})"
    )

    def seconds(h, m, s, ms):
        return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000

    previous_end = -1.0
    count = 0
    for line in srt_path.read_text(encoding="utf-8").splitlines():
        match = stamp.fullmatch(line.strip())
        if not match:
            continue
        count += 1
        start = seconds(*match.groups()[:4])
        end = seconds(*match.groups()[4:])
        if end <= start:
            return Finding(False, "字幕", f"{count}番目の表示が0秒以下です（{line.strip()}）")
        if start < previous_end:
            return Finding(False, "字幕", f"{count}番目が前の字幕と重なっています（{line.strip()}）")
        previous_end = end
    if count == 0:
        return Finding(False, "字幕", "時刻の行が1つも読めません")
    return Finding(True, "字幕", f"{count}枚、時刻の乱れなし")


def contact_sheet(out_dir: Path, columns: int = 4, limit: int = 24) -> Path | None:
    """画面が変わるたびに1枚ずつ抜き出して、1枚の紙に並べる。

    **完成品を見る作業を、毎回の手作業から1コマンドにする。**2026-09-04 に
    見つけた不具合（見出しの割れ、写真が小さすぎる、カードの熟語の分断）は
    どれも機械の点検が緑のまま出ていて、実際に見るまで分からなかった。
    見るのが面倒だと見なくなるので、面倒をなくす。
    """
    import json
    import subprocess

    from PIL import Image, ImageDraw

    video = out_dir / "video.mp4"
    script_json = out_dir / "script.json"
    if not video.exists() or not script_json.exists():
        return None
    try:
        import imageio_ffmpeg

        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None

    data = json.loads(script_json.read_text(encoding="utf-8"))
    starts = [
        float(line.get("start") or 0)
        for scene in data.get("scenes", [])
        for line in scene.get("lines", [])
    ]
    if not starts:
        return None
    if len(starts) > limit:  # 多すぎるときは等間隔に間引く
        step = len(starts) / limit
        starts = [starts[int(i * step)] for i in range(limit)]

    frames_dir = out_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    shots: list[tuple[float, Path]] = []
    for index, start in enumerate(starts):
        target = frames_dir / f"contact_{index:02d}.jpg"
        subprocess.run(
            [ffmpeg, "-loglevel", "error", "-ss", f"{start + 1.0:.2f}", "-i", str(video),
             "-frames:v", "1", "-q:v", "4", str(target), "-y"],
            check=False, capture_output=True,
        )
        if target.exists():
            shots.append((start, target))
    if not shots:
        return None

    thumb_w = 480
    thumb_h = int(thumb_w * 9 / 16)
    rows = (len(shots) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * thumb_w, rows * (thumb_h + 26)), (18, 22, 30))
    draw = ImageDraw.Draw(sheet)
    for index, (start, path) in enumerate(shots):
        image = Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.LANCZOS)
        x = (index % columns) * thumb_w
        y = (index // columns) * (thumb_h + 26)
        sheet.paste(image, (x, y))
        draw.text((x + 8, y + thumb_h + 5), f"{index + 1:02d}  {start:5.1f}s",
                  fill=(210, 210, 210))
    target = out_dir / "contact.jpg"
    sheet.save(target, quality=86)
    return target
