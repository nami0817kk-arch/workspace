// 公開サイト（site/）に、AdMob の確認に要るファイルが実体として置かれているか。
//
// 2026-10-02 に /robots.txt が無く、Cloudflare Pages がトップページの HTML を返していたため、
// AdMob の「アプリを確認」が「詳細情報が一致しません」で通らなかった（docs/app-pitfalls.md 項目8）。
// 置き忘れを公開前に止める。公開後の実際の返り方は scripts/check-app-site.sh が外から確かめる。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String name) {
    final f = File('site/$name');
    expect(f.existsSync(), isTrue, reason: 'site/$name が無い（実体として置かないと、そのパスにトップページの HTML が返る）');
    return f.readAsStringSync();
  }

  test('robots.txt が全部許可で、AdMob のクローラ（Google-adstxt）の行がある', () {
    final s = read('robots.txt');
    expect(s.toLowerCase(), isNot(contains('<html')));
    expect(s, contains('User-agent: *'));
    expect(s, contains('User-agent: Google-adstxt'));
    expect(RegExp(r'^Disallow:\s*/\s*$', multiLine: true).hasMatch(s), isFalse, reason: 'サイト全体を禁止していない');
  });

  test('app-ads.txt に AdMob の発行元の行がある', () {
    expect(read('app-ads.txt').trim(), 'google.com, pub-6409014819339195, DIRECT, f08c47fec0942fa0');
  });

  test('404.html がある（無いパスにトップページを返さない）', () {
    expect(read('404.html'), contains('<html'));
  });
}
