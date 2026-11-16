import 'dart:convert';

/// 保存した値（布陣・設定）を、ページの読み込み前に window.__BOOT として渡す。
/// ページ側の `/*__BOOT__*/` の位置に差し込む。
/// 別アプリから戻ったとき、ページが生きているかを見る式。#app に中身があれば1以上を返す
const aliveProbe = '(function(){var a=document.getElementById("app");return a?a.childElementCount:0;})()';

/// 生きているかを見た結果から、読み直すかを決める（2026-11-15「別アプリから戻ると真っ白画面になる」）。
/// iOS は数、Android は文字で返る。読めない・0 なら真っ白なので読み直す
bool needsReload(Object? probeResult) {
  if (probeResult == null) return true;
  final n = num.tryParse(probeResult.toString().replaceAll('"', '').trim());
  return n == null || n <= 0;
}

String injectBoot(String html, Map<String, String> store) {
  // </script> を含む値でページが壊れないように、< をエスケープして渡す
  final json = jsonEncode({'store': store}).replaceAll('<', '${String.fromCharCode(92)}u003c');
  return html.replaceFirst('/*__BOOT__*/', 'window.__BOOT=$json;');
}
