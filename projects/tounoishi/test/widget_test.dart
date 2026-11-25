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
    expect(html, contains('ゴブリン＝進化・配合'));
    expect(html, isNot(contains('肥料・埋め戻す・ここに集まれ・主役への命令のメニューが開く')));
    // v58: 骨はモンスターが倒れても出さない（自動プレイで4周目に400〜2000本たまった）
    expect(html, isNot(contains("g.bone=(g.bone||0)+1;")));
    // 掲載画像の道具がメニューを開けるように
    expect(html, contains('pop:openPop,'));
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
    // 骨の兵の弓兵・盾兵（v66 から通路のメニューには出さない。仕組みは残す）
    expect(html, contains("if(a=='bonea'||a=='boned'){"));
    expect(html, contains('(m.rng||S.range)?g.en.filter('));
    // 図鑑の掛け合わせ表と、見つけた組み合わせの記録
    expect(html, contains('<h3 class="dexh">血と特性と上の技</h3>'));
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
    // v66 から配合は血の濃さで受け継ぐ（ゴブリンの一族）
    expect(html, contains('function bloodOf(a,b){'));
    expect(html, contains('layEgg(gobKey(ch.sz,ch.hd),a.env,a.f,a.x,a.y,BREED_T,{gob:ch,hpk:sumK(),atkk:sumK()});'));
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
    expect(html, contains("{n:'濃い血',")); // v66 で骨の軍団から差し替え
    // 前のチャレンジ（掘ると生まれる前提）の記録は引き継がない
    expect(html, contains("kvGet('tou-chal2')"));
    expect(html, isNot(contains("{n:'花の守り',")));
    // 次の波が来るまでコアが無事なら守ったとみなす
    expect(html, contains('function chalWaves(n){return g.wave>n||'));
    expect(html, contains('if(g.noSum){'));
  });

  test('ストーリーを今の仕組みで作り直してタイトルに戻す（0.7.46・試作 v63）', () {
    final html = File(gameAsset).readAsStringSync();
    // v68: タイトルは年代記とチャレンジに。ストーリーはタイトルから外した
    expect(html, isNot(contains('id="tstory"')));
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
    expect(html, contains('function sumWhy(){'));
    // v66 から候補3匹のボタンを、呼べないときは押せなくする
    expect(html, contains("'<button data-cpick=\"'+i+'\"'+(why?' disabled':'')"));
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

  test('ゴブリンの一族: 候補3匹から召喚・血の濃さで配合・特性の段と上の技・弱点（0.7.49・試作 v66）', () {
    final html = File(gameAsset).readAsStringSync();
    // ゴブリン6通り（体格 小中大 × 得手 殴る・投げる）
    for (final k in ['gob_sm', 'gob_st', 'gob_mm', 'gob_mt', 'gob_lm', 'gob_lt']) {
      expect(html, contains('$k:{line:'), reason: k);
    }
    // 召喚: はぐれゴブリンの候補3匹から1匹、引き直し
    expect(html, contains('function summonPick(a,i){'));
    expect(html, contains('function summonReroll(){'));
    expect(html, contains('g.sumCand=[gobCand(),gobCand(),gobCand()]'));
    // 血の濃さ: 濃い＝同じ特性の段+1、薄い＝新しい特性
    expect(html, contains("return {r:r,k:r>=0.5?'koi':r>0?'futsu':'usui'};"));
    expect(html, contains("if(B.k=='koi'){if(la&&lb)l=Math.min(3,l+1);"));
    // 特性10・上の技10・弱点6
    expect(html, contains("iyashi:{n:'癒し',"));
    expect(html, contains("noroi:{n:'呪い',"));
    expect(html, contains("var CMB={bakuen:{n:'爆炎',a:'doku',b:'hono',"));
    expect(html, contains("var WK={yowai:{n:'体が弱い',"));
    // 固いが受ける傷に効く（v61 では効いていなかった）
    expect(html, contains('ad=dmgTaken(tt,ad);tt.hp-=ad;'));
    // 見つけた上の技は周をまたいで残す（アプリ側にも保存）
    expect(html, contains("kvSet('tou-combo',"));
    // 卵がかえるときに止まらない（v66 の途中で eg.sp を空にして止まった）
    expect(html, contains("var gb=m&&m.gob;if(gb)say("));
    // 外したもの: 通路の骨の兵・コマンドの骨の兵と卵
    expect(html, isNot(contains('<button data-x="bone5"')));
    expect(html, isNot(contains('<div id="cmdbone"></div>')));
  });

  test('前の仕組みの名残を外す（0.7.50・試作 v67）', () {
    final html = File(gameAsset).readAsStringSync();
    // ゴブリンが倒れてもゴーストは湧かない・冒険者の亡骸は残さない
    expect(html, isNot(contains("mkCr('ghost','mag',m.f,m.x,m.y,2);")));
    expect(html, isNot(contains("else if(e.k!='doll')addCorpse(e);")));
    // 記憶の棚はゴブリンの形に
    expect(html, contains("{k:'pool',n:'始めの魂',"));
    expect(html, contains("{k:'mate',n:'始めの仲間',d:'新しい塔に、はぐれゴブリン ＋1匹',"));
    expect(html, isNot(contains("{k:'soil',n:'始めの土を選ぶ',")));
    // 文に前の仕組み（養分・魔法陣・ふん・ドラゴン）を出さない
    expect(html, isNot(contains('養分の濃い土（白っぽい模様）を探して掘ろう')));
    expect(html, isNot(contains('魔法陣を試してみて')));
    expect(html, isNot(contains('魔法陣やふんで足止め')));
  });

  test('一族の年代記: 始祖・寿命5波・子ども・10波ごとの節目・巣荒らし・閉じた記録（0.7.51・試作 v68）', () {
    final html = File(gameAsset).readAsStringSync();
    // タイトルは年代記（難しさ3つ）と閉じた年代記・チャレンジ
    expect(html, contains('<p class="lbl">新しい年代記を始める</p>'));
    expect(html, contains('id="trec"'));
    expect(html, contains("bt.onclick=function(){chStart(bt.getAttribute('data-d'));};"));
    // 始祖の夫婦を3組から選ぶ
    expect(html, contains('<h2>始祖を選ぶ</h2>'));
    expect(html, contains("C.fd='始祖'+p[0].nm+'と'+p[1].nm;"));
    // 寿命5波・卵は次の波でかえって子ども（半分の力）・その次で大人
    expect(html, contains('var LIFE=5,'));
    expect(html, contains('function mkKid(m){m.kid=1;m.mhp*=0.5;m.hp=m.mhp;m.atkk*=0.5;}'));
    expect(html, contains('if(m.kid&&g.wave-m.bw>=2){growUp(m);grown++;}'));
    expect(html, contains('if(g.wave-m.bw>LIFE&&!m.chief)died.push(m);'));
    expect(html, contains("if(m.kid)return '子どものうちは配合できない';"));
    expect(html, contains('eg.chw=1;eg.bw=g.wave;eg.hatch=1e12;'));
    // 終わりなし・10波ごとの節目（くじ・5波前に知らせ）
    expect(html, contains('function nW(){return g&&g.party?1:g&&g.chron?1e9:WAVES.length;}'));
    expect(html, contains("EVN={yu:'伝承の勇者',clan:'よその一族の襲来',plague:'はやり病'}"));
    expect(html, contains('if(g.wave%10==5){var ks=Object.keys(EVN);C.ev=ks[rnd(ks.length)];C.evW=g.wave+5;'));
    // 節目を越えると洞窟が広がる（階は増やさない）
    expect(html, contains('if(C.reach<COREX){C.reach++;'));
    expect(html, contains('||!!(g&&g.chron&&Math.abs(x-COREX)>g.chron.reach);}'));
    expect(html, contains('F=CHNEW?1:3;'));
    // よその一族の戦士は捕まえると薄い血に
    expect(html, contains('if(e.clan&&g.chron&&Math.random()<0.5)chCapture(e);'));
    // コアが壊されても一族の半分を失って続く・0匹で閉じる
    expect(html, contains('if(g.chron){chCoreLost();return;}'));
    expect(html, contains("var gs=shuffle(g.cr.filter(function(m){return m.gob;})),n=Math.floor(gs.length/2);"));
    expect(html, contains("&&!g.cr.some(function(m){return m.gob;})&&!g.eggs.length)chClose();"));
    expect(html, contains("kvSet('tou-chron',JSON.stringify(A));"));
  });

  test('ゴブリンのすみかの見た目: 暗い岩肌・松明・暮らしの跡（0.7.51・試作 v69）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains("if(g.chron){ctx.drawImage(chTile(bedrock(f,x,y)?'bed':c.open?'floor':'rock',v),px,py);continue;}"));
    expect(html, contains("lx.fillStyle=g.chron?'rgba(5,3,8,0.42)':'rgba(6,4,14,0.14)';"));
    expect(html, contains("chTorch(4);chDeco('straw');chDeco('straw');"));
    expect(html, contains("if(g.chron)chDeco('helm');"));
    // v73 で骨・食べ残し・ひっかき傷を足した（新しい並びは v73 のテスト）
    // 年代記では前の養分を土に戻さない（黄色・紫の玉が出ていた）
    expect(html, contains('if(n<=0||(g&&g.chron))return;'));
  });

  test('ゴブリンの絵: 一族6通りとよその一族の戦士（0.7.52・試作 v70）', () {
    final html = File(gameAsset).readAsStringSync();
    for (final k in ['gob_sm', 'gob_st', 'gob_mm', 'gob_mt', 'gob_lm', 'gob_lt', 'gob_clan']) {
      expect(html, contains(" $k:'data:image/png;base64,"), reason: k);
    }
    expect(html, contains("var GOBSPR={gob_sm:'gob_sm',gob_st:'gob_st',gob_mm:'gob_mm',gob_mt:'gob_mt',gob_lm:'gob_lm',gob_lt:'gob_lt'}"));
    expect(html, contains("e.clan=1;e.spr='gob_clan';"));
  });

  test('年代記では子が自動で生まれる・配合のボタンは無い（0.7.53・試作 v71）', () {
    final html = File(gameAsset).readAsStringSync();
    // 波のはじめ（寿命・成長のあと）に大人どうしが組になって卵を産む。魂は使わない
    expect(html, contains("var ne=C.st?chBreed():0,et=ne?'卵が'+ne+'つ生まれた。':'';"));
    expect(html, contains('function chBreed(){var room=chRoom(),'));
    // v72 で一族の上限は外した（重さのための安全弁 500 だけ）
    expect(html, contains('function chCap(){return 1e9;}'));
    expect(html, contains('function chRoom(){return Math.max(0,CH_CAP-g.cr.length-chEggN());}'));
    expect(html, isNot(contains("return '一族がいっぱい")));
    // 配合は年代記では使わない（ボタンを出さず、コマンドは自動の説明に）
    expect(html, contains("function breedWhy(m){if(g&&g.chron)return '年代記では子は自動で生まれる';"));
    expect(html, contains("if(!g.chron)h+='<button data-m=\"breed\""));
    expect(html, contains("hh.textContent=g.chron?'子づくり（自動）':'配合する';if(g.chron)return chBrInfo()"));
    expect(html, isNot(contains('2匹を配合して子を残そう')));
  });

  test('周りの国の警戒: 一族が増えるほど攻めてくる人数と強さが増す（0.7.54・試作 v72）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains("ALN=['静か','村のうわさ','領主の見張り','王国の討伐令','諸国の同盟','大討伐']"));
    expect(html, contains('C.alert=((C.alert||0)*0.97)+chGobs().length*0.1'));
    expect(html, contains('g.round=1+Math.floor(g.wave/6)+Math.floor((g.chron.alert||0)/80);'));
    expect(html, contains('if(chOn()){var ax=Math.min(80,chAlertAdd());'));
    expect(html, contains("*(1+al/300),atk:"));
    // 波が片付く前に次の波が来ても、節目はそこで判定する
    expect(html, contains('if(g.chron.evNow&&g.chron.evW<=g.wave)chMile();'));
    expect(html, contains("</small><small>警戒：'+ALN[chAlertSt()]+' · 友好：'"));
    expect(html, contains('var gap=w.length>12?Math.max(1,48/w.length):4;'));
  });

  test('ゴブリンの巣穴: 広間・丸い角・木の根・たき火・産卵場（0.7.54・試作 v73）', () {
    final html = File(gameAsset).readAsStringSync();
    expect(html, contains('chDen();chHome();'));
    expect(html, contains(' if(g.chron)chCave(f);'));
    expect(html, contains('function chFireDraw('));
    expect(html, contains('function chNestCell(){'));
    expect(html, contains("var DECOS=['straw','bone','scrap','scratch','pot','bone','rack','scratch'];"));
    expect(html, contains('eg.y*CS+CS-(eg.oy||0),20);'));
  });

  test('族長が看取って受け継ぐ・交渉で警戒を下げる（0.7.55・試作 v74）', () {
    final html = File(gameAsset).readAsStringSync();
    // 始祖の1匹が族長。寿命で死なない
    expect(html, contains('C.st=1;chMakeChief(g.cr.filter(function(m){return m.fd;})[0],null);'));
    expect(html, contains('if(g.wave-m.bw>LIFE&&!m.chief)died.push(m);'));
    // 寿命で死んだ仲間から1つ受け継ぐ（8つまで・段3まで）
    expect(html, contains('var CHIEF_TR=8,'));
    expect(html, contains('chIt=chInherit(died);'));
    // 倒れたら特性の多い大人が跡を継ぐ（同じ波の跡継ぎは年代記に1行だけ）
    expect(html, contains('if(m.chief&&g.chron&&g.chron.st&&g.cr.indexOf(m)>=0){g.cr.splice(g.cr.indexOf(m),1);chSucceed(m);g.cr.push(m);}'));
    expect(html, contains('q=C.sucW==g.wave;C.sucW=g.wave;'));
    // 交渉: 貢ぎ物（警戒を3割下げる・1波に1回）と、同盟の国を寝返らせる
    expect(html, contains('g.soul-=c;C.tribW=g.wave;C.alert*=0.7;'));
    expect(html, contains('if(s1>=4&&s0<4)C.allies=3;'));
    expect(html, contains("C.alert-=(C.alert-floor)/C.allies;C.allies--;"));
    expect(html, contains("else if(b=t.closest('[data-chdip]')){chDip(b.getAttribute('data-chdip'));}"));
    expect(html, contains('if(g.chron)return chBrInfo()+chDipHTML()'));
  });

  test('村と交易: 品・行商人・銀貨・友好（0.7.56・試作 v75）', () {
    final html = File(gameAsset).readAsStringSync();
    // 波のはじめに品を作り、ときどき行商人が来る（4波来なければ必ず）
    expect(html, contains('var made=Math.floor(ad.length/5)+Math.floor(tr/12);'));
    expect(html, contains('if(g.wave-last>=4||Math.random()<0.3+0.1*fs){C.mer=1;C.merW=g.wave;}'));
    // 売ると銀貨と友好
    expect(html, contains("FRN=['知らない','取引相手','顔なじみ','友好の村']"));
    expect(html, contains('C.friend=(C.friend||0)+Math.min(30,n*0.5);'));
    // 銀貨で武器（一族の攻撃+12%ずつ）と貢ぎ物
    expect(html, contains('function atkOf(m){return atkOf0(m)*(m.gob&&g&&g.chron?1+0.12*(g.chron.arms||0):1);}'));
    expect(html, contains('var c=Math.ceil(chTribCost()/3);'));
    // 友好が高いほど警戒が上がりにくい・見逃す冒険者・攻めてこない波
    expect(html, contains('chGobs().length*0.1*(1-0.15*chFrSt());'));
    expect(html, contains('if(fs2>=3&&Math.random()<0.3){w=[];g.chron.peace=1;}'));
    expect(html, contains("else if(b=t.closest('[data-chtr]'))"));
    expect(html, contains('if(g.chron){chDecoDraw();chMarketDraw();}'));
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
