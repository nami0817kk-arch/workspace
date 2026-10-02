# 護送ボート（goso-boat）

警官と囚人を舟で向こう岸へ渡す川渡りパズルの iOS アプリ（Flutter）。
App Store「脱獄させるな！護送ボート：川渡りパズル」（App ID 6816818739、2026-09-30 公開）。

決まり・面の作り方・広告と課金の方針は [CLAUDE.md](CLAUDE.md)、リリースの手順は [docs/RELEASE.md](docs/RELEASE.md)。

## 動かし方

Windows ではホームのパスに日本語が入っていると flutter analyze が通らないので、ASCII のドライブを当ててから実行する。

```powershell
subst G: "C:\Users\なみ\dev\workspace"
cd G:\projects\goso-boat
flutter pub get
flutter analyze
flutter test                      # 合否は CI（goso-boat-ci.yml）で見る
flutter run                       # iOS シミュレータ・実機（Mac が要る）
```

## よく使うもの

```bash
dart run tool/gen_levels.dart                                     # assets/levels.json を作り直す（手で直さない）
flutter gen-l10n                                                  # lib/l10n/*.arb を変えたら
python tool/subset_fonts.py                                       # ARB に字を足したら（CI の --check が落ちる）
flutter test tool/screenshots/capture_test.dart --update-goldens  # ストアの掲載画像を作り直す
bash ../../scripts/check-app-site.sh goso-boat.pages.dev          # 公開サイトを AdMob 向けに点検
```

## 公開まわり

- 法務ページ・app-ads.txt・robots.txt: `legal/` と `site/` を `goso-boat-site.yml` が https://goso-boat.pages.dev に出す
- TestFlight へ: Actions の `goso-boat-ios-release.yml` を `upload_to_testflight` にチェックして手で回す
