// 公開サイト（site/ と legal/）に、AdMob の確認と App Store の審査に要るファイルが実体として置かれているか。
// projects/goso-boat/test/site_files_test.dart を写したもの。
//
// 2026-10-02 に護送ボートで /robots.txt が無く、Cloudflare Pages がトップページの HTML を返していたため、
// AdMob の「アプリを確認」が「詳細情報が一致しません」で通らなかった（docs/app-pitfalls.md 項目8）。
// 置き忘れを公開前に止める。公開後の実際の返り方は scripts/check-app-site.sh が外から確かめる。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path が無い（実体として置かないと、そのパスにトップページの HTML が返る）');
    return f.readAsStringSync();
  }

  test('robots.txt が全部許可で、AdMob のクローラ（Google-adstxt）の行がある', () {
    final s = read('site/robots.txt');
    expect(s.toLowerCase(), isNot(contains('<html')));
    expect(s, contains('User-agent: *'));
    expect(s, contains('User-agent: Google-adstxt'));
    expect(RegExp(r'^Disallow:\s*/\s*$', multiLine: true).hasMatch(s), isFalse, reason: 'サイト全体を禁止していない');
    expect(RegExp(r'^[\x00-\x7F]*$').hasMatch(s), isTrue, reason: 'robots.txt は英数字だけで書く（日本語のコメントを入れない）');
  });

  test('app-ads.txt に AdMob の発行元の行がある', () {
    expect(read('site/app-ads.txt').trim(), 'google.com, pub-6409014819339195, DIRECT, f08c47fec0942fa0');
  });

  test('404.html がある（無いパスにトップページを返さない）', () {
    expect(read('site/404.html'), contains('<html'));
  });

  test('法務ページ（プライバシー・利用規約・サポート）が塔の意志のもので、日英そろっている', () {
    for (final name in ['privacy', 'terms', 'support']) {
      final s = read('legal/$name.html');
      expect(s, contains('塔の意志'), reason: '$name.html が別のアプリの写しのまま');
      expect(s, contains('lang="en"'), reason: '$name.html に英語の節が無い');
      expect(s, isNot(contains('護送ボート')), reason: '$name.html に写し元の名前が残っている');
      expect(s, contains('つるはし社'));
    }
    final privacy = read('legal/privacy.html');
    for (final w in ['AdMob', 'IDFA', 'myadcenter.google.com', '13歳未満', '返金']) {
      expect(privacy, contains(w), reason: 'privacy.html に「$w」の説明が無い');
    }
    expect(read('legal/support.html'), contains('不適切な広告'), reason: 'support.html に広告の報告の方法が無い');
  });

  test('公開するページに個人の情報を書いていない', () {
    final files = [
      ...Directory('site').listSync().whereType<File>(),
      ...Directory('legal').listSync().whereType<File>(),
    ];
    for (final f in files) {
      final s = f.readAsStringSync().toLowerCase();
      for (final w in ['nami', '0817', 'gmail']) {
        expect(s, isNot(contains(w)), reason: '${f.path} に「$w」がある');
      }
      expect(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(s), isFalse, reason: '${f.path} にメールアドレスがそのまま書かれている（[at] の形にする）');
    }
  });
}
