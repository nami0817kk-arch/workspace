# -*- coding: utf-8 -*-
"""出す前の点検。**当て推量せず、全部当てる。**

    python tool/preflight.py

`flutter test` と `flutter analyze` が見ているのは「コードが壊れていないか」で、
**提出に必要なものが揃っているか**は見ていない。アイコンのアルファチャンネルは
その典型で、テストは全部緑のまま、**Apple のアップロードで初めて弾かれる**
（実際にボールのアイコンの頃からずっと入っていた）。

ここで見るのは、そういう「テストの外側」だけ:

- iOS アイコンが Contents.json のぶん揃っていて、アルファが無いこと
- 掲載する絵が App Store の寸法であること
- 商品ID・バンドルID・法務ページのURLが1つに揃っていること
- Info.plist に要るものがあり、要らない権限の説明文が無いこと
- 雛形の文字列（"A new Flutter project"）が残っていないこと

**直せるものは直さない**——ここは報告だけして、直すのは人（か、次の作業）が決める。
`tool/check_release.py` は「ビルドしたものに管理画面が入っていないか」を見る別の道具で、
そちらは `flutter build web --release` の後に走らせる。
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)

failures = []
notes = []


def check(label, ok, detail=""):
    mark = "OK  " if ok else "**  "
    print(f"  {mark}{label}" + (f"  — {detail}" if detail else ""))
    if not ok:
        failures.append(label)


def note(text):
    print(f"  --  {text}")
    notes.append(text)


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def png_info(path):
    """幅・高さ・色の種類を IHDR から読む（4 と 6 がアルファ付き）。"""
    with open(path, "rb") as f:
        head = f.read(26)[16:26]
    width = int.from_bytes(head[0:4], "big")
    height = int.from_bytes(head[4:8], "big")
    return width, height, head[9]


def main():
    print("== アイコン ==")
    with open(os.path.join(ICONS, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    wanted = [i["filename"] for i in contents["images"] if i.get("filename")]
    missing = [w for w in wanted if not os.path.exists(os.path.join(ICONS, w))]
    check("Contents.json のぶんが揃っている", not missing, ", ".join(missing))

    pngs = glob.glob(os.path.join(ICONS, "*.png"))
    # **1024 は透過も角丸も持てない。** Apple はアップロードの時点で弾く。
    alpha = [os.path.basename(p) for p in pngs if png_info(p)[2] in (4, 6)]
    check("アルファチャンネルが無い", not alpha, ", ".join(alpha))

    big = os.path.join(ICONS, "Icon-App-1024x1024@1x.png")
    check("1024x1024 がある", os.path.exists(big)
          and png_info(big)[:2] == (1024, 1024))

    print("== 掲載する絵 ==")
    for folder, size in (
        ("marketing/screenshots", (1290, 2796)),
        ("marketing/screenshots_ipad", (2064, 2752)),
    ):
        files = sorted(glob.glob(os.path.join(ROOT, folder, "*.png")))
        wrong = [
            os.path.basename(p) for p in files if png_info(p)[:2] != size
        ]
        check(
            f"{folder} が {size[0]}x{size[1]}",
            bool(files) and not wrong,
            f"{len(files)}枚" + ("  ずれ: " + ", ".join(wrong) if wrong else ""),
        )

    print("== 識別子 ==")
    listing = read("STORE_LISTING.md")
    ids = re.findall(
        r"'(soccer_career_[a-z_]+)'", read("lib", "monetize", "purchase_service.dart")
    )
    check(
        "商品IDが掲載情報にもある",
        all(f"`{i}`" in listing for i in ids),
        ", ".join(ids),
    )

    pbx = read("ios", "Runner.xcodeproj", "project.pbxproj")
    bundles = {
        b
        for b in re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);", pbx)
        if not b.endswith(".RunnerTests")
    }
    check("バンドルIDが1つ", len(bundles) == 1, ", ".join(sorted(bundles)))
    check(
        "バンドルIDが掲載情報と同じ",
        bundles and f"`{list(bundles)[0]}`" in listing,
    )

    base = re.search(
        r"legalBase = '([^']+)'", read("lib", "ui", "screens", "support_screen.dart")
    ).group(1)
    # soccer-career.pages.dev は**他人のサイト**（同じ着想の別アプリが先に取っている）。
    check("法務ページのURLが -49p 側", "-49p" in base, base)
    for page in ("privacy", "terms", "support"):
        check(f"legal/{page}.html がある",
              os.path.exists(os.path.join(ROOT, "legal", f"{page}.html")))
        check(f"{page} のURLが掲載情報にある", f"{base}/{page}.html" in listing)

    print("== Info.plist ==")
    plist = read("ios", "Runner", "Info.plist")
    check("AdMob のアプリIDがある", "GADApplicationIdentifier" in plist)
    if "ca-app-pub-3940256099942544" in plist:
        note("AdMob のアプリIDは **Google のテスト用のまま**"
             "（差し替えるまで収益は発生しない）")
    check(
        "SKAdNetwork が40件以上",
        plist.count("SKAdNetworkIdentifier") >= 40,
        f"{plist.count('SKAdNetworkIdentifier')}件",
    )
    check("輸出コンプライアンスが自動回答される",
          "ITSAppUsesNonExemptEncryption" in plist)
    # ATT は求めない（2026-09-26 決定）ので、説明文が入っていたらそちらが間違い。
    check("ATT の説明文が無い", "NSUserTrackingUsageDescription" not in plist)
    perms = re.findall(r"<key>(NS\w*UsageDescription)</key>", plist)
    check("使っていない権限の説明文が無い", not perms, ", ".join(perms))

    print("== 雛形の残り ==")
    for path in ("pubspec.yaml", "web/index.html", "web/manifest.json"):
        text = read(*path.split("/"))
        check(f"{path} に雛形の文字列が無い",
              "A new Flutter project" not in text)

    print("== 公開する文面 ==")
    # **個人名は公開文面に出さない**（公開名義は「つるはし社」）。
    for path in ("legal/privacy.html", "legal/terms.html", "legal/support.html"):
        text = read(*path.split("/"))
        hits = [w for w in ("なみ", "0817") if w in text]
        check(f"{path} に個人名が無い", not hits, ", ".join(hits))
    check("プライバシーポリシーに名義がある",
          "つるはし社" in read("legal", "privacy.html"))
    check("サポートページに連絡先がある",
          "sakamane.support@gmail.com" in read("legal", "support.html"))

    print()
    if failures:
        print(f"要対応 {len(failures)} 件:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("提出まわりの点検は全部通りました。")
    if notes:
        print("（ただし下記はコンソール側の作業として残っています）")
        for n in notes:
            print(f"  - {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
