import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'python_tool.dart';

/// 英語化の取りこぼしを検出する回帰テスト。
///
/// 画面に出る文言を新しく足したとき、`Tr.pick` を通し忘れると、英語表示でも
/// そこだけ日本語のまま残る。人の目では気づきにくいので、リポジトリに置いた
/// スキャナ(tool/i18n/scan_jp.py)を実行して0件であることを確かめる。
void main() {
  test(
    'no Japanese UI string is left outside Tr.pick across lib/',
    () {
      // Python が無い環境ではこの検査は行えないので、テストを落とさず
      // 「検査していない」と分かるようにスキップする。ただしスキャナ自体が
      // 壊れている場合は落とす。黙って検査が無効になるのが一番まずい。
      final python = resolvePythonForTools();
      if (python == null) {
        markTestSkipped('Python が無いため未翻訳の検査を行っていない');
        return;
      }

      final result = Process.runSync(
        python,
        ['tool/i18n/scan_jp.py', 'lib'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(result.exitCode, 0,
          reason: 'スキャナの実行に失敗した(検査できていない)。\n${result.stderr}');

      final out = (result.stdout as String).trim();
      expect(
        out.endsWith('----- 0 untranslated literals in 0 files'),
        isTrue,
        reason: '英語化されていない文言が残っている。\n'
            'それぞれ Tr.pick(日本語, 英語) で包むか、UIの文言でなければ\n'
            '宣言の直前に i18n-ignore を含むコメントを置くこと。\n\n$out',
      );
    },
    // 外部プロセスを起動するため、既定のタイムアウトでは足りないことがある。
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
