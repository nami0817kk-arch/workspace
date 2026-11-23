import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shokan/main.dart';

void main() {
  // WebView 本体はテスト環境で動かないので、同梱物と保存の窓口の約束を確かめる。
  test('ゲームの HTML が同梱されていて、試作の中身である', () {
    final f = File(gameAsset);
    expect(f.existsSync(), isTrue, reason: '$gameAsset が無い');
    final html = f.readAsStringSync();
    expect(html, contains('<meta charset="utf-8">'));
    expect(html, contains('召喚の山札'));
    expect(html, contains('id="pause"'));
    expect(html, contains('id="paused"'));
    expect(html, contains('id="title"'));
  });

  test('保存の仕掛けが入っていて、名前がアプリ側とそろっている', () {
    final html = File(gameAsset).readAsStringSync();
    // ゲーム側の名前とアプリ側の名前がずれると、保存が黙って消える
    expect(html, contains('window.ShokanStore'));
    for (final k in storeKeys) {
      expect(html, contains('"$k"'), reason: '仕掛けが $k を渡していない');
    }
    expect(html, contains("const KEY='shokan-yamafuda-v2'"));
    expect(html, contains("localStorage.setItem('shokan-mute'"));
  });

  test('保存の知らせを読み解く', () {
    final r = parseStoreMessage('{"k":"shokan-yamafuda-v2","v":"abc"}');
    expect(r?.key, 'shokan-yamafuda-v2');
    expect(r?.value, 'abc');
    final del = parseStoreMessage('{"k":"shokan-mute","v":null}');
    expect(del?.key, 'shokan-mute');
    expect(del?.value, isNull);
    expect(parseStoreMessage('{"k":"other","v":"x"}'), isNull);
    expect(parseStoreMessage('こわれた文字'), isNull);
    expect(parseStoreMessage('{"k":"shokan-mute","v":3}'), isNull);
  });

  test('起動時の戻しは値を JSON で渡し、読み込み直しは一度だけ', () {
    final js = restoreJs({'shokan-mute': "1'\"<"});
    expect(js, contains(r'"shokan-mute":"1'));
    expect(js, contains("sessionStorage.getItem('shokan-restored')"));
  });
}
