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

  test('原作との差を埋めた仕組みが入っている（0.5.0・試作 v12）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'dp0:100', // 掘る力
      'function train(', // 主役を鍛える
      'function carryStep(', // 養分を運ぶ
      "pure:'ピュア種'", // 4つ目の変異
      'function drawMinis(', // 塔の全体図
      'var CLINES=', // コアの台詞
      'function sfx(', // 音
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('初代との差を埋めた仕組みが入っている（0.6.0・試作 v13）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'function touchesOpen(', // 掘ったマスの隣だけ掘れる
      'function plantStep(', // コケのツボミと花
      'function rebirth(', // ドラゴンの生まれ変わり
      'function dragonFire(', // 横の炎
      'function stepOn(', // ふん・フェロモン
      'function ringAround(', // 魔法陣
      'function heroSkill(', // 冒険者の MP と技・たいまつ
      'function nextDp(', // 塔が伸びた時の掘る力
      'function upLine(', // 系統の強化
      'function armyPower(', // 軍パワー
      'function advice(', // 負けた時の助言
      'var CHALS=', // チャレンジ
      'var TUT=', // ヒント
      'function phase(', // 朝昼夜
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('pubspec の assets に HTML が登録されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(gameAsset));
  });
}
