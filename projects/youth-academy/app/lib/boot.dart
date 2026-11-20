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

/// 保存（prefs）から、ページへ渡す値を集める。`ya_` で始まる「文字」の値だけを拾う。
/// 文字の並びなど別の型が `ya_` に混ざっていても落ちない（2026-11-17：課金の控えが文字の並びで入っていて、起動が止まった）
Map<String, String> collectStore(Map<String, Object?> all, {String prefix = 'ya_'}) {
  final store = <String, String>{};
  all.forEach((key, v) {
    if (key.startsWith(prefix) && v is String) store[key.substring(prefix.length)] = v;
  });
  return store;
}

String injectBoot(String html, Map<String, String> store) {
  // </script> を含む値でページが壊れないように、< をエスケープして渡す
  final json = jsonEncode({'store': store}).replaceAll('<', '${String.fromCharCode(92)}u003c');
  return html.replaceFirst('/*__BOOT__*/', 'window.__BOOT=$json;');
}
