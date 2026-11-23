import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 1.0.0+10 の使いやすさの直し：会議の発言を人ごとに・2列の欄の項目名を1行に・上の帯の社長の名前・月を進めたあとの保存
///
/// 画面の書き出し（目で見る用）は QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）
final _out = Platform.environment['QUAD_SHOTS'];

final _jp = RegExp('[぀-ヿ㐀-鿿！-～]');

/// 本物のフォントで描く（字の幅で折り返しを確かめるため）
Future<void> _loadFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    jp.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await jp.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

Game? _cached;

/// 途中のゲーム（事業・部下・候補・株主・上場した現地法人と、それを狙う宿敵がいる）
Game _midGame() {
  final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < 150; i++) {
    botMonth(g);
  }
  resolveEvents(g);
  g.calcAll();
  final b = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).first;
  b.ctry = {g.home, ...g.ctryOf(b), 'us', 'cn'}.toList();
  g.calcAll();
  g.ap = 3;
  g.makeLocal(b, 'us');
  final c = g.locals().single;
  g.subIPO(c);
  final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
  c.locRiv = foe.id;
  c.locRivPct = 26;
  if (!g.staff.any((p) => p.partner)) {
    g.staff.add(g.mkPerson(.5)
      ..partner = true
      ..stake = 5);
  }
  g.calcAll();
  return g;
}

Future<GameController> _pump(WidgetTester tester, Game g, {required double width, double height = 844, String lang = 'ja'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang)..game = g;
  addTearDown(() => L.lang = 'ja');
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  return ctl;
}

final _shotKey = GlobalKey();

/// 経営会議で意見がぶつかる場面を作る（責任者を相棒にして、新しい事業の高い提案が出やすくする）
GameEvent? _conflict(Game g) {
  // 1.0.0+12 から提案は「店を3つ」のような単位の値段なので、手元を一番高い業種の元手の3倍ほどにして、2つの案が手元を取り合うようにする
  final cash = g.biz.where((b) => b.mgr != null).map((b) => g.capexOf(indm[b.ind]!)).fold(0.0, (a, x) => a > x ? a : x) * 3;
  for (final p in g.staff.where((p) => g.biz.any((b) => b.mgr == p.id))) {
    p.partner = true;
  }
  for (var i = 0; i < 500; i++) {
    for (final p in g.staff) {
      p.auto = false;
    }
    g.cash = cash;
    g.events.clear();
    g.holdMeeting((m, [t = '']) {});
    final hit = g.events.where((e) => msgKey(e.title) == '経営会議：意見がぶつかった').firstOrNull;
    if (hit != null) return hit;
  }
  return null;
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_out == null) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final im = await ro.toImage(pixelRatio: 2);
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

/// 1行の高さ（その字の大きさで）
double _lineH(TextStyle st) {
  final tp = TextPainter(text: TextSpan(text: 'あA', style: st), textDirection: TextDirection.ltr)..layout();
  return tp.height;
}

/// 2列の欄の1つを調べた結果
class _KvCheck {
  final String label;
  final bool oneLine, valueOneLine;
  final double scale;

  /// 前の版の並べ方（名前に幅の2/5、英語は3/5）なら折り返していたか
  final bool wrappedBefore;
  _KvCheck(this.label, this.oneLine, this.valueOneLine, this.scale, this.wrappedBefore);
}

/// 今の画面にある2列の欄を全部調べる
List<_KvCheck> _checkKvs(WidgetTester tester) {
  final out = <_KvCheck>[];
  final lh = _lineH(ts(size: 13));
  for (final e in find.byType(Kv).evaluate()) {
    final kv = e.widget as Kv;
    final kvBox = e.renderObject as RenderBox;
    final label = find.descendant(of: find.byWidget(kv), matching: find.byKey(const ValueKey('kv-label')));
    final lp = tester.renderObject<RenderParagraph>(label);
    final oneLine = lp.size.height < lh * 1.4;
    final scale = tester.getRect(label).width / lp.size.width;
    var valueOne = true;
    for (final p in find.descendant(of: find.byWidget(kv), matching: find.byType(RichText)).evaluate()) {
      final rp = p.renderObject as RenderParagraph;
      if (rp == lp) continue;
      if (rp.size.height > lh * 1.4) valueOne = false;
    }
    final text = tx(kv.k);
    final natural = (TextPainter(text: TextSpan(text: text, style: ts(size: 13, color: Pal.mute)), textDirection: TextDirection.ltr)..layout()).width;
    final oldW = (kvBox.size.width - 6) * (L.en ? 3 / 5 : 2 / 5);
    out.add(_KvCheck(text, oneLine, valueOne, scale, natural > oldW + .5));
  }
  return out;
}

/// 2列の欄が出る画面を順に開き、[f] で調べる
Future<void> _eachKvScreen(WidgetTester tester, GameController ctl, Future<void> Function(String) f) async {
  final g = ctl.game!;
  for (final t in ['town', 'biz', 'people', 'stock']) {
    ctl.setTab(t);
    if (t == 'biz') ctl.openBiz = (g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first.id;
    await tester.pump();
    await f(t);
  }
  ctl.setTab('town');
  g.ap = 3;
  g.meet = null;
  g.presAct('seek', 'meet');
  openMeet(ctl);
  await tester.pump();
  await f('meet');
  openSettings(ctl);
  await tester.pump();
  await f('settings');
  ctl.closeSheet();
}

void main() {
  setUpAll(_loadFonts);

  group('2列の欄（kv）の項目名は1行に収まる', () {
    final before = <String>{};
    for (final lang in ['ja', 'en']) {
      for (final w in [320.0, 390.0, 430.0]) {
        testWidgets('全部の画面（$lang・幅${w.toInt()}）', (tester) async {
          final g = _cached = _midGame();
          // 画面の外の欄も組み立てるように、縦を長くしておく
          final ctl = await _pump(tester, g, width: w, height: 9000, lang: lang);
          final bad = <String>[];
          var n = 0;
          await _eachKvScreen(tester, ctl, (screen) async {
            for (final c in _checkKvs(tester)) {
              n++;
              if (c.wrappedBefore) before.add('$lang/$screen/${c.label}@${w.toInt()}');
              if (!c.oneLine) bad.add('$screen「${c.label}」が折り返している');
              if (!c.valueOneLine) bad.add('$screen「${c.label}」の値が折り返している');
              // 縮めるのは入りきらないときの最後の手。ふつうの項目名はそのままの大きさで入る
              if (c.scale < .8) bad.add('$screen「${c.label}」が小さくなりすぎ（${c.scale.toStringAsFixed(2)}）');
            }
          });
          expect(n, greaterThan(40), reason: '欄が見つからない');
          expect(bad, isEmpty, reason: bad.join('\n'));
          expect(tester.takeException(), isNull);
        });
      }
    }
    tearDownAll(() {
      // 前の版の並べ方で折り返していた項目（報告用）
      // ignore: avoid_print
      if (before.isNotEmpty) print('[kv] 前の版で折り返していた項目: ${before.toList()..sort()}');
    });
  });

  group('上の帯の社長の名前', () {
    /// いちばん長い名前（日本の名前と、外国の名前）
    List<String> longest() {
      final all = <String>[
        for (final a in SEI)
          for (final b in MEI) '$a $b',
        for (final e in NAMEP.entries) ...[
          for (final a in e.value[0])
            for (final b in e.value[1]) ...['$a $b', '$b・$a'],
        ],
      ];
      String by(int Function(String) len) => all.reduce((x, y) => len(y) > len(x) ? y : x);
      return {by((x) => x.length), by((x) => romanize(x).length)}.toList();
    }

    for (final lang in ['ja', 'en']) {
      for (final w in [320.0, 390.0]) {
        testWidgets('3代目・52歳でも名前が切れない（$lang・幅${w.toInt()}）', (tester) async {
          final g = _cached ?? _midGame();
          for (final name in longest()) {
            g.pres.name = name;
            g.pres.age = 52;
            g.gen = 3;
            final ctl = await _pump(tester, g, width: w, lang: lang);
            final f = find.byKey(const ValueKey('pres-name'));
            final rp = tester.renderObject<RenderParagraph>(f);
            final shown = (tester.widget<Text>(f)).data!;
            expect(shown, nmL(name), reason: '名前がそのまま出ていない');
            expect(find.byKey(const ValueKey('pres-age')), findsOneWidget);
            expect(tester.widget<Text>(find.byKey(const ValueKey('pres-age'))).data, tr('・{0}歳', [52]));
            expect(tester.getRect(find.byKey(const ValueKey('pres-age'))).right,
                lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('settings-tap'))).left));
            expect(rp.didExceedMaxLines, isFalse, reason: '$shown が切れている');
            final scale = tester.getRect(f).width / rp.size.width;
            expect(scale, greaterThan(.8), reason: '$shown が縮みすぎ（$scale）');
            // 名前は帯の中に収まる（右のボタンに重ならない）
            expect(tester.getRect(f).right, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('settings-tap'))).left));
            // 代は札で出る
            expect(find.byKey(const ValueKey('pres-gen')), findsOneWidget);
            expect(find.descendant(of: find.byKey(const ValueKey('pres-gen')), matching: find.text(tr('{0}代目', [3]))), findsOneWidget);
            if (lang == 'en') expect(_jp.hasMatch(shown), isFalse, reason: shown);
            expect(tester.takeException(), isNull);
            if (name == longest().first) await _shot(tester, 'h_header_${lang}_${w.toInt()}');
            ctl.dispose();
          }
        });
      }
    }

    testWidgets('初代は札を出さない', (tester) async {
      final g = _cached ?? _midGame();
      g.gen = 1;
      await _pump(tester, g, width: 390);
      expect(find.byKey(const ValueKey('pres-gen')), findsNothing);
      expect(find.byKey(const ValueKey('pres-name')), findsOneWidget);
    });
  });

  group('会議の発言を人ごとに', () {
    test('臨時の会議：状況の説明と、話す人ごとの発言（顔の印・肩書き）に分かれる', () {
      final g = _midGame();
      final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
      g.listed = true;
      g.sh = Shares(own: 40, pt: 5, float: 37, riv: {foe.id: 18});
      g.pre = -g.cash / 2.5;
      for (final kind in ['takeover', 'scandal', 'cash']) {
        final e = g.crisisMeeting(kind, foe: foe, near: 20)!;
        expect(e.voices.length, greaterThanOrEqualTo(2), reason: kind);
        // 発言の数と、だれかの案の選択肢の数は同じ（最後は「会議を打ち切る」）
        expect(e.voices.length, e.choices.length - 1, reason: kind);
        for (final v in e.voices) {
          expect(txIn(v.who, 'ja'), isNotEmpty);
          expect(txIn(v.role, 'ja'), isNotEmpty);
          expect(txIn(v.say, 'ja'), isNotEmpty);
          expect(v.name == null, v.kind == 'holder' || v.kind == 'bank', reason: '${v.kind} の顔の丸');
          if (v.name != null) expect(g.staff.any((p) => p.name == v.name), isTrue);
          expect(_jp.hasMatch(txIn(v.say, 'en')), isFalse, reason: txIn(v.say, 'en'));
          expect(_jp.hasMatch(txIn(v.role, 'en')), isFalse, reason: txIn(v.role, 'en'));
        }
        // 状況の説明は地の文で、発言は入れない
        final lead = txIn(e.lead, 'ja');
        expect(lead, contains('臨時の会議を開きました'));
        for (final v in e.voices) {
          expect(lead.contains(txIn(v.say, 'ja')), isFalse);
        }
        expect(_jp.hasMatch(txIn(e.lead, 'en')), isFalse, reason: txIn(e.lead, 'en'));
      }
    });

    test('経営会議で意見がぶつかったとき：二人それぞれの吹き出し', () {
      final g = _midGame();
      final mgrs = g.staff.where((p) => g.biz.any((b) => b.mgr == p.id)).toList();
      expect(mgrs.length, greaterThanOrEqualTo(2));
      final hit = _conflict(g);
      expect(hit, isNotNull);
      final e = hit!;
      expect(e.voices.length, 2);
      for (final v in e.voices) {
        final p = g.staff.firstWhere((x) => x.name == v.name);
        expect(v.kind, p.partner ? 'partner' : 'staff');
        expect(txIn(v.role, 'ja'), anyOf(contains('責任者'), '相棒', '部下'));
        // 吹き出しの名前の人の案を通す選択肢がある
        expect(e.choices.any((c) => txIn(c.l, 'ja') == '${p.name}の案を通す'), isTrue);
      }
      expect(txIn(e.lead, 'ja'), '二人とも自分の案を譲りません。両方やるお金はありません。');
      expect(_jp.hasMatch(txIn(e.lead, 'en')), isFalse);
    });

    test('取締役会：振り返りは地の文、取締役の評価は吹き出し、解任動議はそのあとの地の文', () {
      final g = _midGame();
      final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
      g.sh = Shares(own: 32, pt: 6, float: 50, riv: {foe.id: 12});
      g.listed = true;
      g.yPrev = {'rev': g.rev * 12 * 1.1, 'pre': g.pre.abs() * 12 * 2, 'cap': g.cap * 1.2, 'rank': g.rank + 3.0};
      g.yAcc = {'rev': g.rev * 11, 'pre': g.pre.abs() * 11, 'n': 11};
      g.events.clear();
      g.holdBoard();
      final e = g.events.single;
      expect(msgKey(e.title), '取締役会：解任動議');
      expect(e.voices.single.kind, 'board');
      expect(e.voices.single.name, isNull);
      expect(txIn(e.voices.single.say, 'ja'), 'このままでは困ります');
      expect(txIn(e.voices.single.role, 'ja'), '評価：悪い');
      expect(txIn(e.lead, 'ja'), contains('の振り返り'));
      expect(txIn(e.tail, 'ja'), contains('解任動議が出ました'));
      // 前と同じ全部の文も持っている（記録用）
      expect(txIn(e.text, 'ja'), contains('取締役の評価：悪い'));
    });

    for (final lang in ['ja', 'en']) {
      testWidgets('小窓では人ごとに顔の丸と肩書きつきの吹き出しが縦に並ぶ（$lang）', (tester) async {
        final g = _midGame();
        final ctl = await _pump(tester, g, width: 390, lang: lang);
        final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
        g.listed = true;
        g.sh = Shares(own: 40, pt: 5, float: 37, riv: {foe.id: 18});
        g.pre = -g.cash / 2.5;
        for (final kind in ['takeover', 'scandal', 'cash']) {
          final e = g.crisisMeeting(kind, foe: foe, near: 20)!;
          g.events
            ..clear()
            ..add(e);
          nextEvent(ctl);
          await tester.pump();
          final says = find.byType(VoiceSay);
          expect(says, findsNWidgets(e.voices.length));
          // 縦に並ぶ（上から順に）
          final tops = [for (final x in says.evaluate()) tester.getTopLeft(find.byWidget(x.widget)).dy];
          for (var i = 1; i < tops.length; i++) {
            expect(tops[i], greaterThan(tops[i - 1]));
          }
          // 名前の無い話し手は役割の印、部下・相棒は頭文字の丸
          expect(find.byType(RoleFace), findsNWidgets(e.voices.where((v) => v.name == null).length));
          expect(find.descendant(of: says, matching: find.byType(Face)), findsNWidgets(e.voices.where((v) => v.name != null).length));
          // 状況の説明は吹き出しの外
          expect(find.descendant(of: says, matching: find.textContaining(tx(e.lead).split(L.en ? '. ' : '。').first)), findsNothing);
          expect(find.textContaining(tx(e.lead)), findsOneWidget);
          if (lang == 'en') {
            for (final t in find.descendant(of: says, matching: find.byType(RichText)).evaluate()) {
              final s = (t.widget as RichText).text.toPlainText();
              expect(_jp.hasMatch(s), isFalse, reason: s);
            }
          }
          expect(tester.takeException(), isNull);
          await _shot(tester, 'm_crisis_${kind}_$lang');
          ctl.closeSheet();
        }
        // 取締役会
        g.sh = Shares(own: 32, pt: 6, float: 50, riv: {foe.id: 12});
        g.yPrev = {'rev': g.rev * 12 * 1.1, 'pre': g.pre.abs() * 12 * 2 + 1e9, 'cap': g.cap * 1.2, 'rank': g.rank + 3.0};
        g.yAcc = {'rev': g.rev * 11, 'pre': g.pre.abs() * 11, 'n': 11};
        g.events.clear();
        g.holdBoard();
        nextEvent(ctl);
        await tester.pump();
        expect(find.byType(VoiceSay), findsOneWidget);
        expect(find.byType(RoleFace), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _shot(tester, 'm_board_$lang');
        ctl.closeSheet();
        // 意見の対立
        final hit = _conflict(g);
        g.events
          ..clear()
          ..add(hit!);
        nextEvent(ctl);
        await tester.pump();
        expect(find.byType(VoiceSay), findsNWidgets(2));
        expect(find.byType(RoleFace), findsNothing);
        expect(tester.takeException(), isNull);
        await _shot(tester, 'm_conflict_$lang');
      });
    }
  });

  group('月を進めたあとの保存', () {
    testWidgets('結果を描き終わったところで1回だけ保存する', (tester) async {
      final g = _midGame();
      final ctl = await _pump(tester, g, width: 390);
      final prefs = ctl.prefs!;
      prefs.remove(slotKey(1));
      doNext(ctl);
      expect(ctl.savePending, isTrue);
      expect(prefs.getString(slotKey(1)), isNull, reason: '描く前には保存しない');
      await tester.pump();
      expect(ctl.savePending, isFalse);
      final saved = prefs.getString(slotKey(1));
      expect(saved, isNotNull);
      // 保存の中身は今の月
      expect(Game.fromJson(jsonDecode(saved!) as Map<String, dynamic>, rng: ParkMiller(1)).turn, g.turn);
      // 続けて何度呼んでも予約は1つ。描き終わりの前にほかの保存が走れば、予約はそこで済む
      ctl.closeSheet();
      prefs.remove(slotKey(1));
      ctl.saveSoon();
      ctl.saveSoon();
      expect(ctl.savePending, isTrue);
      ctl.save();
      expect(ctl.savePending, isFalse);
      expect(prefs.getString(slotKey(1)), isNotNull);
      prefs.remove(slotKey(1));
      await tester.pump();
      expect(prefs.getString(slotKey(1)), isNull, reason: '済んだ予約で二度は保存しない');
    });

    testWidgets('アプリが裏に回ると、予約していた保存をすぐ済ませる', (tester) async {
      final g = _midGame();
      final ctl = await _pump(tester, g, width: 390);
      ctl.prefs!.remove(slotKey(1));
      ctl.saveSoon();
      ctl.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(ctl.prefs!.getString(slotKey(1)), isNotNull);
      expect(ctl.savePending, isFalse);
      await tester.pump();
    });
  });
}
