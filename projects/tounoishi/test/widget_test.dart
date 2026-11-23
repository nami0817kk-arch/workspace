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

  test('初代の残り・ストーリー・VS が入っている（0.7.0・試作 v14）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'function tapOpen(', // つつく・コアの置き直し
      'function openChestMe(', // 自分で宝箱を開ける
      'var DEMONS=', // デーモン5種
      'function fireCone(', // 扇形の炎
      'function windSpiral(', // 渦の風
      'var STORY=', // ストーリー8面
      'function startVs(', // VS
      'function rankOf(', // ランク
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('バグ直し（0.7.20・試作 v34）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'o.flT=now+160', // 点滅の値がツボミの養分を上書きしない
      "g.title=true;showTitle();", // メニューでタイトルに戻ると止まる
      "function saveKey(", // ストーリー・VS は別の保存枠
      "id=\"tcontm\"", // その続きから
      "g.winSave=1;saveGame();", // 勝った直後も保存
      "(?:_(moss|water|rock|ice|lava|mag))", // 氷・溶岩の層の絵
      "if(g.cr.length>=CAP){eg.hatch=g.t+5;continue;}", // 塔がいっぱいなら卵は待つ
    ]) {
      expect(html, contains(s), reason: s);
    }
    // ランクや設定も localStorage に直接書かず、アプリ側の保存を通す
    expect(html, isNot(contains("localStorage.setItem('tou-")));
  });

  test('新しい種の1つ目の束（0.7.21・試作 v35）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "tsuta:{line:'nut'", // ツタ
      "mogura:{line:'nut'", // モグラ
      "kame:{line:'nut'", // カメ
      "frost:{line:'nut'", // フロスト（氷の層）
      "salamander:{line:'nut'", // サラマンダー（溶岩の層）
      "kagami:{line:'mag'", // カガミ
      "kage:{line:'mag'", // カゲ
      'function varSp(', // 土の色・昼夜で生まれる種が替わる
      'function newSec(', // 新しい種の動き
      'var PH=', // 絵がまだの種は仮の絵
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('新しい種の2つ目の束（0.7.22・試作 v36）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "ant:{line:'nut'", // アリ
      "hachi:{line:'nut'", // ハチ
      "shidemushi:{line:'nut'", // シデムシ
      "bakudan:{line:'nut'", // バクダンダケ
      "umihebi:{line:'nut'", // ウミヘビ
      "purupuru:{line:'mag'", // プルプル
      "manasui:{line:'mag'", // マナスイ
      "noroi:{line:'mag'", // ノロイ人形
      'function bakuBoom(', // 破裂
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('新しい種の3つ目の束（0.7.23・試作 v37）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "yamaarashi:{line:'nut'", // ヤマアラシ
      "iwakui:{line:'nut'", // イワクイ
      "yukidama:{line:'nut'", // ユキダマ（氷の層）
      "magma:{line:'nut'", // マグマスライム（溶岩の層）
      "hotaru:{line:'nut'", // ホタル（夜）
      "himawari:{line:'nut'", // ヒマワリ（昼）
      "fukurou:{line:'mag'", // フクロウ
      "maboroshi:{line:'mag'", // マボロシ
      "slimeking:{line:'sp'", // スライムキング
      "tsuchinoko:{line:'sp'", // ツチノコ
      'function illuOn(', // 幻の壁
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('周回の解放と主役の物語（0.7.24・試作 v39）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'var SHELF=', // 記憶の棚の5項目
      'function applyMeta(', // 新しい塔に棚の分を足す
      'function metaGain(', // 落ちたら記憶がたまる
      'id="tshelf"', // タイトルの記憶の棚
      'function heroTitle(', // 二つ名
      'function lifeText(', // 殿堂の一生
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('つながりを見せる（0.7.25・試作 v40）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'id="conn"', // 一覧のつながりの欄
      'function connHTML(', // 段ごとの種・養分のありか・最近の出来事
      'function nutNow(', // 養分のありか
      'function logEv(', // 最近の出来事
      'HL=null,lpT=0', // 長押しで食べる・食べられる相手を光らせる
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('勇者の見せ場と手を出せる操作（0.7.26・試作 v42）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'function banner(', // 来襲・倒し切った時の帯
      'function yuBar(', // 勇者の体力の帯
      "'！技'", // 技の予告
      'function openPop(', // 長押しのメニュー
      'function doAct(', // 肥料・埋め戻す・集まれ
      'function reachCore(', // 埋めても入口からコアまでの道は切れない
      "m.cmd=='guard'", // 主役に命令
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('新しい25種の絵（0.7.27・試作 v43）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final k in ['tsuta', 'mogura', 'kame', 'frost', 'salamander', 'kagami', 'kage', 'ant', 'hachi', 'shidemushi', 'bakudan', 'umihebi', 'purupuru', 'manasui', 'noroi', 'yamaarashi', 'iwakui', 'yukidama', 'magma', 'hotaru', 'himawari', 'fukurou', 'maboroshi', 'slimeking', 'tsuchinoko']) {
      expect(html, contains(" $k:'data:image/png;base64,"), reason: k);
    }
  });

  test('図鑑の生まれ方のヒントと長押しのヒント（0.7.28・試作 v44）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "var HINT={tsuta:", // 新しい種の生まれ方のヒント
      "slimeking:'スライムが8匹", // スライムキングの出来方
      'function lpHint(', // 長押しのヒントは1度だけ
      "kvSet('tou-tut','2')", // 長押しを知ったら保存する
      "umihebi:{line:'nut',t:4,n:'ウミヘビ',hp:80,mv:0.9,hung:50,atk:11", // 釣り合い
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('珍しい種の知らせと記憶の棚の3項目（0.7.29・試作 v45）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "banner('新しい種！ '", // 初めて図鑑に載った珍しい種を帯で知らせる
      "var nw=!DEX[spc]||!DEX[spc].seen;", // 知らせるのは初めて載った時だけ
      "{k:'mul',n:'記憶の上乗せ'", // 記憶の上乗せ
      "{k:'mate',n:'始めの仲間'", // 始めの仲間
      "{k:'gift',n:'勇者の置き土産'", // 勇者の置き土産
      'g.dp+=e.yu?20+5*(g.giftK||0):1;', // 置き土産の掘る力
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('自分で置く罠とコアの光（0.7.30・試作 v46）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'data-a="trap"', // 長押しのメニューの「罠を置く」
      'function mtrapOn(', // 踏んだ冒険者に傷と足止め
      'if(mtrapOn(e))return;', // 罠で倒れたらその後の処理をしない
      'id="blight"', // コアの光のボタン
      'function coreLight(', // 周りの冒険者の攻撃を半分に
      'if(e.lgtT&&g.t>=e.lgtT){e.lgtT=0;e.atk*=2;}', // 10秒で元に戻る
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('ストーリーの面に氷・溶岩の層（0.7.31・試作 v47）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "land:{f:1,env:'ice'}", // 第3面で2階が氷の層に
      "land:{f:0,env:'lava'}", // 第5面で1階が溶岩の層に
      'function applyLand(', // 面が始まるときに土を変える
      'for(var ls=1;ls<=st;ls++)applyLand(ls);', // 途中の面から始めても、それまでの層は変わっている
      'function landNote(', // 面の紹介に一文
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('法務ページへのリンクがあり、外のブラウザで開く', () {
    final html = File(gameAsset).readAsStringSync();
    // Apple 5.1.1: アプリの中からプライバシーポリシーとサポート（広告の報告）を開けること
    expect(html, contains('https://tounoishi.pages.dev/privacy.html'));
    expect(html, contains('https://tounoishi.pages.dev/support.html'));
    expect(isExternalLink('https://tounoishi.pages.dev/privacy.html'), isTrue);
    expect(isExternalLink('file:///android_asset/flutter_assets/assets/game/index.html'), isFalse);
  });

  test('pubspec の assets に HTML が登録されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(gameAsset));
  });
}
