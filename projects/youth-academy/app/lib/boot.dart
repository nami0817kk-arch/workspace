import 'dart:convert';

/// 保存した値（布陣・設定）を、ページの読み込み前に window.__BOOT として渡す。
/// ページ側の `/*__BOOT__*/` の位置に差し込む。
String injectBoot(String html, Map<String, String> store) {
  // </script> を含む値でページが壊れないように、< をエスケープして渡す
  final json = jsonEncode({'store': store}).replaceAll('<', '${String.fromCharCode(92)}u003c');
  return html.replaceFirst('/*__BOOT__*/', 'window.__BOOT=$json;');
}
