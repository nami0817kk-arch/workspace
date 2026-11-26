import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/l10n/data_en.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// ひらがな・カタカナ・漢字・全角の記号
final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

/// 英語の画面でも日本語のまま出してよい文（言語を選ぶボタン）
const _allowed = {'日本語', '言語 / Language'};

Future<GameController> _pump(WidgetTester tester, {Size size = const Size(390, 844), Game? game, String lang = 'en', Map<String, Object> init = const {}}) async {
  SharedPreferences.setMockInitialValues(init);
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
  ctl.game = game;
  tester.view.physicalSize = centerAs(size);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(QuadrillionApp(controller: ctl));
  await tester.pump();
  return ctl;
}

Game _midGame([int months = 150]) {
  final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < months; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  s.deals.add(Deal(co: s.cos.firstWhere((c) => c.alive && c.parent != 'player').id, type: 'sales', since: s.year));
  s.kids.add(s.mkPerson(0)
    ..age = 25
    ..kid = true);
  s.biz.first.pipe.add(Pipe(k: 'enter', c: 'us', mode: 'solo', cost: 1e9, left: 3));
  s.biz.first.pipe.add(Pipe(k: 'dev', cost: 1e8, left: 2));
  s.biz.first.war = 3;
  s.biz.first.ad = 3;
  s.seen['fusion'] = 1;
  s.calcAll();
  return s;
}

/// 画面に描かれている文をすべて集める
List<String> _texts(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    out.add((e.widget as RichText).text.toPlainText());
  }
  for (final e in find.byWidgetPredicate((w) => w is EditableText).evaluate()) {
    out.add((e.widget as EditableText).controller.text);
  }
  return out;
}

/// 日本語の文字が残っている文（言語を選ぶボタンは除く）
List<String> _japanese(WidgetTester tester) => _texts(tester).where((t) => !_allowed.contains(t) && _cjk.hasMatch(t)).toList();

void _noJapanese(WidgetTester tester, String where) {
  final j = _japanese(tester);
  expect(j, isEmpty, reason: '$where に日本語が残っている: ${j.take(12).join(' / ')}');
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('金額の書き方', () {
    test('英語は ¥ と K / M / B / T / Q', () {
      const cases = [
        (0.0, '¥0'),
        (999.0, '¥999'),
        (12345.0, '¥12.3K'),
        (1.5e6, '¥1.5M'),
        (29.94e9, '¥29.9B'),
        (3.512e12, '¥3.51T'),
        // 1.1.0+38 から、丸めると1000になる額は上の桁で書く（前は「¥1,000T」）
        (999.95e12, '¥1Q'),
        (1e15, '¥1Q'),
        (2.5e16, '¥25Q'),
        (-5e8, '-¥500M'),
      ];
      for (final c in cases) {
        expect(yenEn(c.$1), c.$2, reason: '${c.$1}');
      }
      expect(yenEn(double.nan), '-');
    });

    test('yen は言語で書き方が変わる', () {
      L.lang = 'en';
      expect(yen(3.51e12), '¥3.51T');
      L.lang = 'ja';
      expect(yen(3.51e12), '3.51兆円');
    });

    test('包んだ文の金額も見せるときの言語で書く', () {
      final m = M('{0}を借りました', [Y(2.99e10)]);
      expect(txIn(m, 'ja'), '299億円を借りました');
      expect(txIn(m, 'en'), 'Borrowed ¥29.9B');
    });
  });

  group('文の鍵と引数', () {
    test('セーブには鍵と引数が入り、言語を変えても同じセーブから両方の言葉で出せる', () {
      final s = _midGame(60);
      final j = jsonEncode(s.toJson());
      final back = Game.fromJson(jsonDecode(j) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(back.history, isNotEmpty);
      for (final e in [...back.history.map((e) => e.m), ...back.log.map((e) => e.m)]) {
        expect(isMsg(e), isTrue, reason: e);
        expect(_cjk.hasMatch(txIn(e, 'en')), isFalse, reason: txIn(e, 'en'));
        expect(_cjk.hasMatch(txIn(e, 'ja')), isTrue, reason: txIn(e, 'ja'));
      }
    });

    test('古いセーブの日本語の文は、そのまま日本語で出す', () {
      final s = _midGame(12);
      final j = s.toJson();
      (j['history'] as List).add({'y': 1990, 'q': 1, 'k': 'ipo', 'm': '株式を上場した。1億円が入った'});
      (j['log'] as List).add({'m': '古い記録の文', 't': '', 'y': 1990, 'q': 1});
      final back = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(1));
      expect(txIn(back.history.last.m, 'en'), '株式を上場した。1億円が入った');
      expect(txIn(back.log.last.m, 'en'), '古い記録の文');
    });

    test('仕組みの文の日本語の鍵には、すべて英語がある', () {
      // lib/game の日本語の文字列は、仕組みの判定に使うものを除いて英語の表に載っていること
      const notShown = {'バブル景気|バブル崩壊', '・', '。', 'グループ', 'ネクスト'};
      final missing = <String>[];
      for (final f in ['game', 'game_turn', 'game_actions', 'game_view', 'game_story', 'game_local', 'game_mid', 'game_units', 'ind_profile', 'game_corp', 'game_traits', 'traits_data', 'game_names']) {
        final src = File('lib/game/$f.dart').readAsStringSync();
        for (final m in RegExp(r"'((?:[^'\\\n]|\\.)*)'").allMatches(src)) {
          final k = m.group(1)!;
          if (!_cjk.hasMatch(k) || k.contains(r'$') || notShown.contains(k)) continue;
          if (enText(k) == null) missing.add(k);
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('定義の名前（業種200・国24・特性・宿敵の型・時代の大事件など）にすべて英語がある', () {
      expect(IND.length, 200);
      expect(CTRY.length, 24);
      final names = <String>[
        for (final i in IND) i.ja,
        for (final x in SYN) x.ja,
        for (final g in BIG) g.ja,
        for (final t in [...TRAITS, ...STRAITS]) ...[t.nJa, t.gJa, t.bJa],
        for (final c in CTRY) ...[c.ja, c.cityJa],
        for (final c in CULT.values) ...[c.nJa, c.gJa, c.bJa],
        for (final p in PLACES) ...[if (p.nJa.isNotEmpty) p.nJa, p.sJa],
        for (final d in DIFFS) ...[d.nJa, d.dJa],
        for (final m in [RTYPE, MODELN, MODELD, ENTRYN, DEALN, DEALD, DIRTYN, DIRTYD, ABN, CATN, meetLines, traitHints, abDesc, presGrowHow]) ...m.ja.values,
        ...NETMSG.ja,
        ...REGN.ja,
      ];
      final missing = names.where((n) => dataEn[n] == null && enText(n) == null).toList();
      expect(missing, isEmpty, reason: missing.join(' / '));
      L.lang = 'en';
      expect(indm['semi']!.name, 'Semiconductors');
      expect(cm['us']!.n, 'USA');
      expect(MODELN['fc'], 'Franchise');
    });

    test('人と会社の名前はローマ字・元の綴りになる', () {
      final s = _midGame(120);
      L.lang = 'en';
      final names = <String>[
        s.pres.name,
        for (final p in [...s.staff, ...s.cands, ...s.kids]) p.name,
        for (final c in s.cos) ...[c.name, c.presName, if (c.rival != null) ...[c.rival!.pres, c.rival!.co]],
        for (final r in RIVALS) ...[r.pres, r.co],
      ];
      for (final n in names) {
        expect(_cjk.hasMatch(nmL(n)), isFalse, reason: '$n → ${nmL(n)}');
      }
      expect(nmL('マーカス・ヘイル'), 'Marcus Hale');
      expect(nmL('佐藤 健一'), 'Sato Kenichi');
      expect(nmL('暁星食品'), 'Gyosei Foods');
      expect(nmL('オーロラ・システムズ'), 'Aurora Systems');
      expect(nmL('佐藤グループ'), 'Sato Group');
      L.lang = 'ja';
      expect(nmL('マーカス・ヘイル'), 'マーカス・ヘイル');
    });

    test('英語で長く回しても、ニュース・社史・出来事に日本語が残らない', () {
      for (final cfg in [
        SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler'], home: 'jp'),
        SetupConfig(mode: 'quad', year: 2000, traits: ['tech', 'noble'], home: 'us'),
        SetupConfig(mode: 'endless', year: 1980, traits: ['liar', 'frugal'], home: 'cn'),
      ]) {
        final s = Game.newGame(cfg, rng: ParkMiller(99));
        final seen = <String>[];
        for (var i = 0; i < 360; i++) {
          for (final e in s.events) {
            seen.addAll([e.title, e.text, for (final c in e.choices) ...[c.l, c.s]]);
          }
          botMonth(s);
          seen.addAll([...s.advice(), s.goalText(), s.officeName(), s.stageName()]);
        }
        seen.addAll([for (final e in s.log) e.m, for (final e in s.history) e.m, s.won ?? '', s.over ?? '']);
        final bad = seen.map((m) => txIn(m, 'en')).where(_cjk.hasMatch).toSet();
        expect(bad, isEmpty, reason: bad.take(10).join('\n'));
      }
    });
  });

  group('英語の画面', () {
    testWidgets('全タブが開き、日本語が残らない（幅390）', (tester) async {
      final ctl = await _pump(tester, size: const Size(390, 9000), game: _midGame());
      for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
        ctl.setTab(t);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: t);
        _noJapanese(tester, 'タブ $t');
      }
      // 1.1.0+41 から画面の見出しの帯にも画面の名前が出るので、左の切り替えの中の字を押す
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('tab-zukan')), matching: find.text('Codex')));
      await tester.pump();
      expect(ctl.tab, 'zukan');
    });

    testWidgets('全タブが幅320でも崩れない', (tester) async {
      final ctl = await _pump(tester, size: const Size(320, 9000), game: _midGame());
      for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
        ctl.setTab(t);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: t);
      }
    });

    testWidgets('全小窓が開き（幅320）、日本語が残らない', (tester) async {
      final ctl = await _pump(tester, size: const Size(320, 4000), game: _midGame());
      final s = ctl.game!;
      final b = s.biz.first;
      final foe = s.cos.firstWhere((c) => c.rival != null && c.alive && c.parent != 'player');
      final sheets = <String, void Function()>{
        '遊び方': () => showHelp(ctl),
        '設定': () => openSettings(ctl),
        '海外': () => openEnter(ctl, b),
        '稼ぎ方': () => openModel(ctl, 'konbini', b),
        '業態': () => openPivot(ctl, b),
        '裏の手': () => openDirty(ctl, foe),
        '売る': () => openSell(ctl),
        '組む': () => openDeal(ctl, foe),
        '分社': () => openShape(ctl, b),
        '創業': () => openStart(ctl),
        '相棒探し': () {
          s.ap = 3;
          openSeek(ctl);
        },
        'はじめ': () => openIntro(ctl),
        '確認': () => actConfirmed(ctl, '「x」を売る', '本文', '売る', () => null),
        'はじめから': () => confirmRestart(ctl),
      };
      for (final e in sheets.entries) {
        e.value();
        await tester.pump();
        expect(ctl.sheet, isNotNull, reason: e.key);
        expect(tester.takeException(), isNull, reason: e.key);
        if (e.key != '確認') _noJapanese(tester, '小窓 ${e.key}');
        ctl.closeSheet();
        await tester.pump();
      }
      // 出会いの小窓（場所ごと）
      for (final pl in ['lab', 'club', 'baito', 'meet', 'net']) {
        s.ap = 3;
        s.staff.removeWhere((p) => p.partner);
        s.presAct('seek', pl);
        openMeet(ctl);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: pl);
        _noJapanese(tester, '出会い $pl');
        ctl.closeSheet();
        s.meet = null;
        await tester.pump();
      }
      // 月の報告と出来事（いろいろな出来事を積む）
      final p = s.staff.isNotEmpty ? s.staff.first : (s.mkPerson(0)..name = '山田 健一');
      s.events.addAll([
        s.evPoach(foe, p),
        s.evAlliance(foe),
        s.evHostile(foe, 33.4),
        s.evHostile(foe, 50),
        s.evPartnerLeave(p..stake = 5),
      ]);
      doYear(ctl, 3);
      await tester.pump();
      var guard = 0;
      while (ctl.sheet != null && guard++ < 40) {
        expect(tester.takeException(), isNull);
        _noJapanese(tester, '報告・出来事');
        final cont = find.text('Continue');
        final ok = find.text('OK');
        final target = cont.evaluate().isNotEmpty
            ? cont
            : ok.evaluate().isNotEmpty
                ? ok
                : find.byType(ChoiceBtn).last;
        await tester.ensureVisible(target.first);
        await tester.pump();
        await tester.tap(target.first);
        await tester.pump();
      }
      expect(ctl.sheet, isNull);
    });

    testWidgets('はじめの画面とまとめに日本語が残らない', (tester) async {
      final ctl = await _pump(tester, size: const Size(390, 6000));
      _noJapanese(tester, 'はじめの画面');
      expect(find.text('World #1'), findsOneWidget);
      expect(find.text('¥1 Quadrillion'), findsOneWidget);
      final g = _midGame();
      g.won = M('{0}年、世界の企業ランキングで1位になりました', [g.year]);
      ctl.game = g;
      ctl.save();
      ctl.render();
      await tester.pump();
      expect(find.byType(EndScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      _noJapanese(tester, '勝ちのまとめ');
      g.won = null;
      g.over = M('宿敵に株の過半数を握られ、社長の座を追われました');
      ctl.render();
      await tester.pump();
      _noJapanese(tester, '負けのまとめ');
      // 続きからの一覧
      ctl.game = null;
      ctl.render();
      await tester.pump();
      _noJapanese(tester, '続きからの一覧');
    });

    testWidgets('設定で言語を選び直すと、保存されて次に開いたときもその言語', (tester) async {
      final ctl = await _pump(tester, game: _midGame(24), lang: 'ja');
      expect(L.lang, 'ja');
      openSettings(ctl);
      await tester.pump();
      expect(find.text('English'), findsOneWidget);
      await tester.ensureVisible(find.text('English'));
      await tester.pump();
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(L.lang, 'en');
      expect(ctl.prefs!.getString('lang'), 'en');
      // 1.1.0+41 から街の見出しの帯にも「Town」が出るので、左の切り替えの中を見る
      expect(find.descendant(of: find.byKey(const ValueKey('tab-town')), matching: find.text('Town')), findsOneWidget);
      // 端末が日本語でも、選んだ言語が優先される
      final back = GameController(prefs: ctl.prefs, lang: 'ja');
      expect(back, isNotNull);
      expect(L.lang, 'en');
      openSettings(ctl);
      await tester.pump();
      await tester.ensureVisible(find.text('日本語'));
      await tester.pump();
      await tester.tap(find.text('日本語'));
      await tester.pump();
      expect(L.lang, 'ja');
      expect(ctl.prefs!.getString('lang'), 'ja');
      expect(find.descendant(of: find.byKey(const ValueKey('tab-town')), matching: find.text('街')), findsOneWidget);
    });

    testWidgets('選んでいなければ端末の言語に従う（日本語以外は英語）', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      addTearDown(() => tester.platformDispatcher.localeTestValue = const Locale('ja', 'JP'));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      GameController(prefs: prefs);
      expect(L.lang, 'en');
      tester.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
      GameController(prefs: prefs);
      expect(L.lang, 'ja');
    });
  });
}

