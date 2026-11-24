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

  test('掘ったときは塔の上限に関係なく生まれる（0.7.33・試作 v49）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'if(g.cr.length>=CAP&&!(opt&&opt.force))return null;', // 上限は自然に増えるときだけ
      "mkCr('guardian','sp',f,cx,cy,0,{force:1})", // 守護獣
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('空っぽ・吸われていた土を掘ったときの知らせ（0.7.34・試作 v50）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'sc.nut--;sc.sk=1;', // モンスターが吸った土に印
      'c.nut-=t;c.sk=1;', // 錬金術師が吸った土に印
      'if(a[7])c.sk=1;', // 保存から戻しても印が残る
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('盤を28×28に広げ、古い保存は20×20のまま続ける（0.7.35・試作 v51）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'NEWN=28', // 新しい塔の大きさ
      'function setN(n)', // 盤の大きさを切り替える
      'setN(o.N||20)', // 大きさの無い古い保存は20×20
      '{v:1,N:N,F:F,', // 保存に大きさを入れる
      'function key3(f,x,y){return (f*N+y)*N+x;}', // 番号が大きさでぶつからない
      'return Math.round(30*F*N*N/400);', // 自然に増える上限は広さに比例
      'function szH(){return 1+SZH*(N-20)/8;}', // 冒険者を広さに合わせて強く
    ]) {
      expect(html, contains(s), reason: s);
    }
    expect(html, isNot(contains('f*400+y*20+x')), reason: '20マス前提の番号が残っている');
  });

  test('1本指は盤のスクロール、「掘る」ボタンの間だけ掘る（0.7.36・試作 v52）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      '<button id="zdig" aria-pressed="false">', // 掘るボタン
      'function setDig(on)', // 押すまで続く切り替え
      'pan:!DIG', // ボタンが消えていれば指で盤を動かす
      'function focusCore()', // 最初はコアのあたりを今までのマスの大きさで
      "document.getElementById('zdig').onclick=", // ボタンで切り替える
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('モンスターの長押しで食べさせる・進化させる（0.7.37・試作 v53）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      "openPop(HL.hero?'hero':'mon',", // 主役でなくてもメニューが開く
      'function feedTarget(m)', // 3マス以内の食べられる相手
      'function evolve(m,k)', // 甲・牙
      'var EVO_XP=5;', // 経験5点で進化できる
      'killer.xp=(killer.xp||0)+2;', // 倒すと2点
      "label(o.evo?'⇑':'↑',", // 進化できる印（2回目は⇑）
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('掛け合わせる・遠征（0.7.38・試作 v54・v55）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      'function breedChild(a,b)', // 生まれる種の決め方
      'if(g.breed&&breedTap(', // 相手をタップして選ぶ
      'var BREED_COST=3,BREED_CD=30,BREED_T=20;', // v61 から魂3・30秒休む・20秒で卵
      '<div id="expd"></div>', // 一覧の遠征の欄
      'function expChance(ms,d)', // 見込み
      'if(g.exp)expBack();', // 波を守り切ると帰る
      'var EXP_MAX=3,', // 3匹まで
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('新しい資源 魂と骨（0.7.39・試作 v56）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final s in [
      '<small id="res2" class="res2">', // 掘る力の下に魂と骨
      'var sg=e.yu?10:(e.boss||e.title)?3:2;g.soul=(g.soul||0)+sg;g.bone=(g.bone||0)+(e.yu?5:1);', // 倒すと魂と骨（v58 から骨は1、勇者5・v61 から魂2）
      'var EVO2_XP=12,EVO2_SOUL=5,REV_SOUL=15,HATCH_SOUL=2;', // 魂の使い道
      'function revive(id)', // 倒れた主役を1回よみがえらせる
      'var BONE_S=5,BONE_L=12,BONE_T=3,BONE_K=8;', // 骨の使い道
      'hitEn(e,t.bone?30:15,', // 骨の罠は傷30
      'g.soul=g.soul||0;g.bone=g.bone||0;g.fallen=g.fallen||[];', // 古い保存でも動く
    ]) {
      expect(html, contains(s), reason: s);
    }
  });

  test('長押しのヒントが今のメニューに合っている（0.7.40・試作 v57）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('モンスター＝進化・配合'));
    expect(html, isNot(contains('肥料・埋め戻す・ここに集まれ・主役への命令のメニューが開く')));
    // v58: 骨はモンスターが倒れても出さない（自動プレイで4周目に400〜2000本たまった）
    expect(html, isNot(contains("g.bone=(g.bone||0)+1;")));
    // 掲載画像の道具がメニューを開けるように
    expect(html, contains('window.__t={pop:openPop,'));
    // 掲載画像の道具は 28×28 の座標に引き伸ばす
    final cap = File('tool/screenshots/capture.py').readAsStringSync();
    expect(cap, contains('function __s(v){return Math.round(v*(__N()-1)/19);}'));
    // v61 から掘っても生まれないので、掲載画像の場面は祭壇から召喚して作る
    expect(cap, contains('function __sum(f,ks){'));
    expect(cap, contains("('04_cmd', r"));
  });

  test('遠征の行き先・骨の弓兵と盾兵・掛け合わせ表（0.7.42・試作 v59）', () {
    final html = File(gameAsset).readAsStringSync();
    // 遠征は行き先を3つから選ぶ（森＝易しい、墓地＝魂と骨、竜の谷＝難しい）
    expect(html, contains("var EXD={mori:{n:'近くの森',k:0.6,"));
    expect(html, contains("haka:{n:'古い墓地',k:1.0,"));
    expect(html, contains("tani:{n:'竜の谷',k:1.8,"));
    expect(html, contains('g.exp={ms:ms,ch:ch,d:d};'));
    expect(html, contains("var xd=ev.target.closest('[data-expd]');"));
    // 骨の兵に弓兵（3マス先まで）と盾兵（固い）
    expect(html, contains('<button data-x="bonea"'));
    expect(html, contains('<button data-x="boned"'));
    expect(html, contains('(m.rng||S.range)?g.en.filter('));
    // 図鑑の掛け合わせ表と、見つけた組み合わせの記録
    expect(html, contains('<h3 class="dexh">配合と特性</h3>'));
    expect(html, contains('brdAdd(a.sp,b.sp,ch.sp);'));
    expect(html, contains("kvSet('tou-brd',"));
  });

  test('掛け合わせ・骨の兵・卵をコマンドの一覧から選べる（0.7.43・試作 v60）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('<button class="btn" id="bcmd">コマンド</button>'));
    expect(html, contains('<div id="spane-cmd" hidden>'));
    // 掛け合わせの本体は盤のタップとコマンドで共通
    expect(html, contains('function breedDo(a,b){'));
    expect(html, contains('return breedDo(a,b);}'));
    expect(html, contains('data-cbrgo="1"'));
    // 骨の兵は階と種類を選び、コアに近い通路に出す
    expect(html, contains('function cmdBoneSpot(f){'));
    expect(html, contains("boneAct(k,f,p[0],p[1]);"));
    // 卵をすぐかえす
    expect(html, contains("if(e)boneAct('hatch',e.f,e.x,e.y);"));
  });

  test('芯の作り直し: 掘っても生まれない・召喚・配合と特性・コアの体力（0.7.44・試作 v61）', () {
    final html = File(gameAsset).readAsStringSync();
    // 掘る＝通路を広げるだけ。土に養分・魔分を持たせない
    expect(html, contains('// v61: 掘っても何も生まれない。通路を広げるだけ'));
    expect(html, contains("a.push({env:envAt(f,x,y),nut:0,mag:0,open:false,dt:-1,chest:false});"));
    expect(html, isNot(contains('// 各階で、掘った広さに応じて下の段が土から少しずつ湧く')));
    // モンスターは食べ合わず、自分で増えない
    expect(html, contains('  abil(m);'));
    expect(html, isNot(contains('if(S.t==1)feed1(m,S);else eat(m,S);')));
    // 召喚: 祭壇・魂・供物（倒した冒険者の持ち物）
    expect(html, contains('function summonAt(a,k){'));
    expect(html, contains("var LOOT={sw:{n:'剣',"));
    expect(html, contains('<div id="cmdsum"></div>'));
    expect(html, contains('<button data-x="altar"'));
    // 配合: 子は親のどちらか、特性を3つまで受け継ぐ
    expect(html, contains('function breedTraits(a,b){'));
    expect(html, contains('layEgg(ch.sp,ch.env,a.f,a.x,a.y,BREED_T,{tr:trs});'));
    expect(html, contains('var TR={doku:'));
    expect(html, isNot(contains("if(A.line!=B.line)return {sp:'chimera',env:'sp'};")));
    // コアに体力。殴られて0で負け、運び出しは無い
    expect(html, contains('function hitCore(e){'));
    expect(html, contains('<div class="stat">コアの体力<b id="core">-</b></div>'));
    expect(html, isNot(contains("say(enName(e)+'がコアを奪った！")));
    // VS は元の仕組みで作った面のため、タイトルから外したまま（チャレンジは v62、ストーリーは v63 で作り直して戻した）
    expect(html, isNot(contains('id="tvs"')));
  });

  test('チャレンジを今の仕組みで作り直してタイトルに戻す（0.7.45・試作 v62）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('id="tchal"'));
    expect(html, contains("{n:'魂30',"));
    expect(html, contains("{n:'三つの特性',"));
    expect(html, contains("{n:'コアを守り抜く',"));
    expect(html, contains("{n:'掘る力20',"));
    expect(html, contains("{n:'骨の軍団',"));
    // 前のチャレンジ（掘ると生まれる前提）の記録は引き継がない
    expect(html, contains("kvGet('tou-chal2')"));
    expect(html, isNot(contains("{n:'花の守り',")));
    // 次の波が来るまでコアが無事なら守ったとみなす
    expect(html, contains('function chalWaves(n){return g.wave>n||'));
    expect(html, contains('if(g.noSum){'));
  });

  test('ストーリーを今の仕組みで作り直してタイトルに戻す（0.7.46・試作 v63）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('id="tstory"'));
    // 面ごとの手当て（魂・供物）とコアの全快
    expect(html, contains('var SGIFT=[[24,1],'));
    expect(html, contains('function stageGift(st){'));
    expect(html, contains('g.core.mhp=CORE_HP+80*(g.st-1);'));
    // 面の土を別の層に変える仕組みは外した（生まれる種が変わらないため）
    expect(html, contains('function applyLand(st){return 0;'));
    // ストーリーでは面の進み具合で呼べる種が強くなる
    expect(html, contains('function sumLv(){'));
    // 記録は作り直した面で取り直す
    expect(html, contains("kvGet('tou-srank2')"));
    expect(html, contains("kvGet('tou-story2')"));
  });

  test('召喚できない理由をコマンドの画面に出す（0.7.47・試作 v64）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('function sumWhy(k){'));
    expect(html, contains("'<button class=\"btn go\" data-csgo=\"1\"'+(sumWhy(k)?' disabled':'')"));
    // 盤の下の知らせはシートに隠れるので、コマンドの画面の一番上にも出す
    expect(html, contains('<div class="cmsg2" id="cmdmsg"></div>'));
  });

  test('前の版の塔を続きから開くと新しい仕組みに合わせる（0.7.48・試作 v65）', () {
    final html = File(gameAsset).readAsStringSync();
    // 祭壇が無い保存＝前の版。祭壇・魂・供物・コアの体力を渡し、湧いたモンスターは40匹まで
    expect(html, contains('var oldTower=!g.alt;if(oldTower)fromOldTower();'));
    expect(html, contains('function fromOldTower(){'));
    expect(html, contains('var OLD_KEEP=40;'));
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
