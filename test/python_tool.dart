import 'dart:convert';
import 'dart:io';

/// tool/i18n/ のスキャナを動かせる Python の実行ファイル名を返す。無ければ null。
///
/// `python3` 決め打ちにはできない。Windows には `python3` という実行ファイルが
/// 無く、代わりに Microsoft Store へ誘導するだけのスタブが同じ名前で置かれて
/// いる。これは終了コード 9009 と "Python was not found" を返すだけなので、
/// 「無い」ことを stderr の "No such file or directory" で判定していると
/// 素通りしてしまい、検査そのものが失敗として報告される。
/// 実際に `--version` が通ったものだけを採用する。
String? resolvePythonForTools() {
  for (final exe in const ['python3', 'python']) {
    try {
      final probe = Process.runSync(
        exe,
        ['--version'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (probe.exitCode == 0) return exe;
    } on ProcessException {
      // その名前の実行ファイルが無い。次の候補を試す。
    }
  }
  return null;
}
