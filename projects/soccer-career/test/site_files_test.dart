/// **公開サイトに置き忘れてはいけないファイル。**
///
/// Cloudflare Pages は**見つからない経路に index.html を返す**ので、
/// `robots.txt` の実体が無いと `/robots.txt` にトップページの HTML が
/// 返る。AdMob はそこで止まり、`app-ads.txt` の確認まで進まない
/// （「app-ads.txt が設定されている可能性がありますが、詳細情報が
/// 一致しません」と出る）。**サカマネ・護送ボート・選手キャリアの
/// 3本とも踏んだ**（docs/app-pitfalls.md の「AdMob が app-ads.txt を見つけられない」）。
///
/// ここが見るのは「`web/` に実体があるか」まで。**実際に配信されている
/// 中身**は、公開のワークフローが deploy の後に curl で確かめる。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('robots.txt が実体として置いてある', () {
    final file = File('web/robots.txt');
    expect(file.existsSync(), isTrue,
        reason: '無いと /robots.txt にトップページの HTML が返る');

    final body = file.readAsStringSync();
    // app-ads.txt を読みにくるクローラーを塞がない。
    expect(body, contains('Google-adstxt'));
    expect(body, isNot(contains('Disallow: /\n')),
        reason: '全部を塞ぐと app-ads.txt まで読まれなくなる');

    // **中身は英数字だけにする。** 手順書（ios-app-release）の指示で、
    // 護送ボートが「確認済み」になったときの形もそうだった。こちらは
    // 日本語のコメントを書いていたので 2026-10-08 に外した——AdMob の
    // 確認は一度外すと読み直しに最大24時間かかるので、押す前に揃えた。
    final nonAscii = body.runes.where((r) => r > 127).toList();
    expect(nonAscii, isEmpty,
        reason: 'robots.txt に ASCII 以外が入っている: '
            '${String.fromCharCodes(nonAscii)}');
  });

  test('404.html が実体として置いてある', () {
    expect(File('web/404.html').existsSync(), isTrue,
        reason: '無いと、無い経路に 200 でトップページが返る');
  });

  test('app-ads.txt が、AdMob の発行者IDの1行になっている', () {
    final body = File('web/app-ads.txt').readAsStringSync().trim();
    expect(body, contains('google.com'));
    expect(body, contains('pub-6409014819339195'));
    expect(body, contains('DIRECT'));
  });
}
