// 公開ページ(legal/・site/)が揃っていて、公開してよい内容かを見る。
// 2026-10-02 に /robots.txt が無く、Cloudflare Pages がトップページの HTML を返したことがある
// (docs/app-pitfalls.md 項目8)ので、実体として置くことも見る。
import 'dart:io';

import 'package:baseball_manager/ui/links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path が無い');
    return f.readAsStringSync();
  }

  Map<String, String> load() => {
        for (final n in ['privacy', 'terms', 'support'])
          n: read('legal/$n.html'),
        'index': read('site/index.html'),
        '404': read('site/404.html'),
      };

  test('法務ページは日英で、問い合わせ先があり、mailto を使っていない', () {
    final pages = load();
    for (final n in ['privacy', 'terms', 'support']) {
      final s = pages[n]!;
      expect(s, contains('lang="ja"'), reason: n);
      expect(s, contains('lang="en"'), reason: n);
      expect(s, contains('info[at]dailyquarry.com'), reason: n);
      // Cloudflare の難読化が mailto を壊す(docs/public-identity.md)
      expect(s.toLowerCase().contains('mailto:'), isFalse, reason: n);
      expect(s, contains('つるはし社'), reason: n);
    }
  });

  test('公開物に個人の名前・ユーザー名を出さない', () {
    final pages = load();
    final re = RegExp(r'\bnami\b|0817|なみ', caseSensitive: false);
    for (final e in pages.entries) {
      expect(re.hasMatch(e.value), isFalse, reason: e.key);
    }
  });

  test('プライバシーポリシーは、データ収集なし・広告と課金なしの現状と一致している', () {
    final pages = load();
    final s = pages['privacy']!;
    expect(s, contains('収集しません'));
    expect(s, contains('広告もアプリ内課金もありません'));
    expect(s, contains('端末の中にだけ保存'));
    // 広告・課金を入れるときは、ここを直してから出す
    expect(s.contains('AdMob'), isFalse);
  });

  test('robots.txt が全部許可で、404.html がある(無いパスにトップページを返さない)', () {
    final r = read('site/robots.txt');
    expect(r.toLowerCase(), isNot(contains('<html')));
    expect(r, contains('User-agent: *'));
    expect(RegExp(r'^Disallow:\s*/\s*$', multiLine: true).hasMatch(r), isFalse);
    expect(load()['404']!, contains('<html'));
  });

  test('アプリが開くURL(Links)は、ワークフローの公開先と同じ', () {
    // (リポジトリの外から回したとき=ドライブを割り当てた作業場所では、ワークフローが見えないので飛ばす)
    final wfFile = File('../../.github/workflows/baseball-site.yml');
    if (wfFile.existsSync()) {
      expect(wfFile.readAsStringSync(), contains('baseball-ikusei'));
    }
    expect(Links.privacy.toString(),
        'https://baseball-ikusei.pages.dev/privacy.html');
    expect(Links.support.toString(),
        'https://baseball-ikusei.pages.dev/support.html');
    expect(
        Links.terms.toString(), 'https://baseball-ikusei.pages.dev/terms.html');
    for (final u in [Links.privacy, Links.support, Links.terms]) {
      // 対応するページが legal/ にある
      expect(File('legal/${u.pathSegments.last}').existsSync(), isTrue);
    }
  });
}
