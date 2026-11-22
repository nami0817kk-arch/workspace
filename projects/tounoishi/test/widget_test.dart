import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tounoishi/main.dart';

void main() {
  // WebView 本体はテスト環境で動かないので、同梱物と保存の窓口の約束を確かめる。
  test('ゲームの HTML が同梱されていて、試作の中身である', () {
    final f = File(gameAsset);
    expect(f.existsSync(), isTrue, reason: '$gameAsset が無い');
    final html = f.readAsStringSync();
    expect(html, contains('<meta charset="utf-8">'));
    expect(html, contains('塔の意志'));
    expect(html, contains('id="c"'));
    expect(html, contains('window.__t'));
  });

  test('ゲームがアプリへの保存の窓口と起動時の受け口を持っている', () {
    final html = File(gameAsset).readAsStringSync();
    // ゲーム側の名前とアプリ側の名前がずれると、保存が黙って消える
    expect(html, contains('window.TouStore'));
    expect(html, contains('window.__boot'));
    expect(html, contains('window.__saveNow'));
    for (final k in storeKeys) {
      expect(html, contains("'$k'"), reason: 'ゲームが $k を保存していない');
    }
  });

  test('保存の知らせを読み解く', () {
    final r = parseStoreMessage('{"k":"tou-save","v":"abc"}');
    expect(r?.key, 'tou-save');
    expect(r?.value, 'abc');
    final del = parseStoreMessage('{"k":"tou-best","v":null}');
    expect(del?.key, 'tou-best');
    expect(del?.value, isNull);
    expect(parseStoreMessage('{"k":"other","v":"x"}'), isNull);
    expect(parseStoreMessage('こわれた文字'), isNull);
    expect(parseStoreMessage('{"k":"tou-dex","v":3}'), isNull);
  });

  test('pubspec の assets に HTML が登録されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(gameAsset));
  });
}
