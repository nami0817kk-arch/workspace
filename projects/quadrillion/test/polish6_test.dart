import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 決まった値だけを返す乱数（確率の分かれ道を決めて試す）
class FixedRandom implements math.Random {
  double v;
  FixedRandom(this.v);
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => (v * max).floor();
  @override
  bool nextBool() => v < .5;
}

final _cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');

void _n(String m, [String t = '']) {}

Game _game([int months = 36, int seed = 606]) {
  final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'careful']), rng: ParkMiller(seed));
  for (var i = 0; i < months; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  return s;
}

Company _rival(Game s, [String? kind]) => s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player' && (kind == null || c.rival!.kind == kind));

/// 去年と今年の数字を決めて取締役会を開く
void _board(Game s, {required double prevPre, required double pre, double own = 30, double float = 70}) {
  s.sh = Shares(own: own, float: float);
  s.listed = true;
  s.yPrev = {'rev': 1e10, 'pre': prevPre, 'cap': 1e11, 'rank': 50};
  s.yAcc = {'rev': 1e10 / 12 * 11, 'pre': pre / 12 * 11, 'n': 11};
  s.events.clear();
  s.holdBoard();
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('取締役会', () {
    test('利益が前年の7割未満で、味方の株が50%未満なら解任動議が出る（答えは3つ）', () {
      final s = _game();
      _board(s, prevPre: 1e9, pre: 6e8);
      expect(s.events, hasLength(1));
      final e = s.events.first;
      expect(msgKey(e.title), '取締役会：解任動議');
      expect(e.choices.map((c) => msgKey(c.l)), ['改革を約束する', '株主に配当を約束して乗り切る', '強気で押し切る']);
      expect(txIn(e.text, 'ja'), contains('前年比'));
      expect(txIn(e.text, 'ja'), contains('悪い'));
    });

    test('持ち株が多ければ、業績が悪くても動議は出ない。相棒と味方の株も数える', () {
      final s = _game();
      _board(s, prevPre: 1e9, pre: 6e8, own: 60, float: 40);
      expect(s.events.single.choices, hasLength(1));
      expect(txIn(s.events.single.text, 'ja'), contains('解任の声は上がりませんでした'));
      // あなた30%＋相棒10%＋味方の会社12% ＝ 52% で動議は出ない
      s.sh = Shares(own: 30, pt: 10, ally: 12, float: 48);
      s.listed = true;
      s.yPrev = {'rev': 1e10, 'pre': 1e9, 'cap': 1e11, 'rank': 50};
      s.yAcc = {'rev': 1e10, 'pre': 5e8, 'n': 12};
      s.events.clear();
      s.holdBoard();
      expect(s.events.single.choices, hasLength(1));
      expect(s.friendlyStake(), closeTo(52, 1e-9));
    });

    test('業績が7割以上なら動議は出ず、伸びれば評価は「良い」', () {
      final s = _game();
      _board(s, prevPre: 1e9, pre: 7.5e8);
      expect(s.events.single.choices, hasLength(1));
      expect(txIn(s.events.single.text, 'ja'), contains('ふつう'));
      _board(s, prevPre: 1e9, pre: 1.3e9);
      expect(txIn(s.events.single.text, 'ja'), contains('良い'));
      expect(txIn(s.events.single.text, 'en'), contains('Good'));
    });

    test('改革を約束すると、1年後に利益が戻れば続投、戻らなければ解任（社長が替わってゲームは続く）', () {
      for (final recovered in [true, false]) {
        final s = _game();
        _board(s, prevPre: 1e9, pre: 5e8);
        s.events.first.choices[0].f();
        expect(s.vow, isNotNull);
        expect(s.vow!['target'], closeTo(9e8, 1));
        final name = s.pres.name, gen = s.gen;
        s.turn += 12;
        _board(s, prevPre: 5e8, pre: recovered ? 9.5e8 : 6e8);
        expect(s.vow, isNull);
        expect(s.events.single.choices, hasLength(1));
        if (recovered) {
          expect(s.pres.name, name);
          expect(txIn(s.events.single.text, 'ja'), contains('約束どおり、利益が戻りました'));
        } else {
          expect(s.gen, gen + 1);
          expect(s.pres.name, isNot(name));
          expect(s.over, isNull);
          expect(s.history.last.k, 'board');
        }
      }
    });

    test('配当を約束すると現金の2割を払って乗り切る', () {
      final s = _game();
      s.cash = 1e9;
      _board(s, prevPre: 1e9, pre: 5e8);
      final name = s.pres.name;
      s.events.first.choices[1].f();
      expect(s.cash, closeTo(8e8, 1));
      expect(s.pres.name, name);
    });

    test('強気で押し切ると、確率で解任される（後継ぎがいればその人が継ぐ）', () {
      final s = _game();
      _board(s, prevPre: 1e9, pre: 5e8);
      final p = s.oustChance();
      expect(p, inInclusiveRange(.1, .85));
      expect(s.events.first.choices[2].s, contains(jsNum(jsRound(p * 100))));
      // 外れ: 押し切れる
      s.rng = FixedRandom(.99);
      final name = s.pres.name;
      s.events.first.choices[2].f();
      expect(s.pres.name, name);
      // 当たり: 解任され、決めておいた後継ぎが社長になる
      _board(s, prevPre: 1e9, pre: 5e8);
      final heir = s.mkPerson(.5)..age = 40;
      s.staff.add(heir);
      s.succ = heir.id;
      s.rng = FixedRandom(0);
      final m = s.events.first.choices[2].f();
      expect(s.pres.name, heir.name);
      expect(txIn(m, 'ja'), contains('解任'));
      expect(s.over, isNull);
    });

    test('部下も子もいなければ、外から社長を呼んで続ける', () {
      final s = _game();
      s.staff.clear();
      s.kids.clear();
      s.succ = null;
      final name = s.pres.name;
      final m = s.oust();
      expect(s.pres.name, isNot(name));
      expect(txIn(m, 'ja'), contains('外から'));
      expect(txIn(m, 'en'), isNot(matches(_cjk)));
    });

    test('毎年1月に1回だけ開かれる', () {
      final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'careful']), rng: ParkMiller(3));
      var boards = 0;
      for (var i = 0; i < 12 * 6; i++) {
        resolveEvents(s);
        botMonth(s);
        final b = s.events.where((e) => msgKey(e.title).startsWith('取締役会')).toList();
        if (b.isNotEmpty) {
          expect(s.q, 1);
          boards++;
        }
      }
      expect(boards, inInclusiveRange(5, 6));
    });
  });

  group('宿敵の物語', () {
    test('初めて同じ業種でぶつかると出会いの場面（型ごとのせりふ）が出る', () {
      final s = _game();
      final c = _rival(s);
      c.rival!.st = 0;
      c.biz.add(CoBiz(ind: s.biz.first.ind, power: 1e6));
      s.events.clear();
      s.storyMonthly(_n);
      expect(c.rival!.st, 1);
      final e = s.events.firstWhere((e) => e.who == c);
      expect(msgKey(e.title), '宿敵との出会い');
      expect(txIn(e.text, 'ja'), contains(storyMeet[c.rival!.kind]!.substring(1, 6)));
      expect(c.rival!.ties, isNotEmpty);
      // 2回目は出ない
      s.events.clear();
      s.storyMonthly(_n);
      expect(s.events.where((e) => msgKey(e.title) == '宿敵との出会い'), isEmpty);
    });

    test('ぶつかるたびに恨みと恩を数え、3つで「因縁が深まる」', () {
      final s = _game();
      final c = _rival(s);
      c.rival!
        ..st = 1
        ..grudge = 0
        ..favor = 0
        ..hurt = 0
        ..vexed = false;
      final b = s.biz.first;
      s.tieRec(c, 'g', M('「{0}」で値下げ合戦を仕掛けた', [I(b.ind)]));
      s.tieRec(c, 'f', M('「{0}」で組んだ', [D('販売の提携')]));
      s.tieRec(c, 'h', M('「{0}」で値下げ合戦を仕掛けられた', [I(b.ind)]));
      s.tieRec(c, 'g', M('株を買い集めた'));
      expect(c.rival!.grudge, 2);
      expect(c.rival!.favor, 1);
      expect(c.rival!.hurt, 1);
      s.events.clear();
      s.storyMonthly(_n);
      expect(s.events.where((e) => msgKey(e.title) == '因縁が深まる'), hasLength(1));
      expect(c.rival!.vexed, isTrue);
      expect(c.rival!.ties.length, lessThanOrEqualTo(6));
    });

    test('決着1: 買収した（倒した宿敵の一族は恨みを覚えて戻ってくる）', () {
      final s = _game();
      final c = _rival(s);
      c.rival!.st = 1;
      c.rival!.grudge = 4;
      s.ret.clear();
      s.events.clear();
      s.rivalDefeated(c);
      expect(c.rival!.st, 2);
      expect(c.rival!.end, 'bought');
      expect(s.history.last.k, 'rival');
      expect(msgKey(s.events.single.title), '決着：{0}');
      expect(s.ret.single.end, 'bought');
      expect(s.ret.single.grudge, 4);
      // 戻ってくる
      s.ret.single.at = s.turn;
      s.rivalReturns(_n);
      final back = s.cos.last;
      expect(back.rival!.kind, 'avenger');
      expect(back.rival!.from, c.name);
      expect(back.rival!.grudge, 4);
      expect(txIn(back.rival!.ties.single, 'ja'), contains(c.name));
      s.events.clear();
      s.storyMonthly(_n);
      final meet = s.events.firstWhere((e) => e.who == back);
      expect(txIn(meet.text, 'ja'), contains('${c.name}を覚えているか'));
      expect(txIn(meet.text, 'en'), isNot(matches(_cjk)));
    });

    test('決着2: 買収された（株の過半数を握られた）', () {
      final s = _game();
      final c = s.cos.firstWhere((c) => c.alive && c.rival != null && c.parent != 'player' && c.rival!.type != 'fund');
      c.rival!.st = 1;
      s.listed = true;
      s.sh = Shares(own: 30, float: 10, riv: {c.id: 60});
      s.nextQuarter();
      expect(s.over, isNotNull);
      expect(c.rival!.end, 'boughtBy');
      expect(s.history.where((h) => h.k == 'rival'), isNotEmpty);
    });

    test('決着3: 和解（組まずに友好のまま3年）', () {
      final s = _game();
      final c = _rival(s);
      c.rival!
        ..st = 1
        ..allied = false;
      s.deals.removeWhere((d) => d.co == c.id);
      for (var i = 0; i < 36; i++) {
        c.rel = 40;
        s.storyMonthly(_n);
        expect(c.rival!.st, 1, reason: '$i か月目');
        s.turn++;
      }
      c.rel = 40;
      s.storyMonthly(_n);
      expect(c.rival!.end, 'peace');
    });

    test('決着4: 組んだ（提携が5年続く。その間は和解にならない）', () {
      final s = _game();
      final c = _rival(s);
      c.rival!
        ..st = 1
        ..allied = true;
      for (var i = 0; i < 60; i++) {
        c.rel = 40;
        s.storyMonthly(_n);
        expect(c.rival!.st, 1, reason: '$i か月目');
        s.turn++;
      }
      s.storyMonthly(_n);
      expect(c.rival!.end, 'ally');
      expect(txIn(s.events.last.text, 'ja'), contains(storyEndLines['ally']![c.rival!.kind]!.substring(1, 5)));
    });

    test('友好が途切れると和解の数えはやり直し', () {
      final s = _game();
      final c = _rival(s);
      c.rival!.st = 1;
      s.deals.removeWhere((d) => d.co == c.id);
      for (var i = 0; i < 30; i++) {
        c.rel = 40;
        s.storyMonthly(_n);
        s.turn++;
      }
      c.rel = 0;
      s.storyMonthly(_n);
      expect(c.rival!.friendSince, -1);
    });

    test('決着した宿敵はそれ以上因縁を数えない（会社は残る）', () {
      final s = _game();
      final c = _rival(s);
      c.rival!.st = 1;
      s.storyEnd(c, 'peace');
      final g = c.rival!.grudge;
      s.tieRec(c, 'g', M('株を買い集めた'));
      expect(c.rival!.grudge, g);
      expect(c.alive, isTrue);
    });

    test('せりふは10の型すべて・決着4通りすべてにあり、英語に日本語が残らない', () {
      const kinds = ['zaibatsu', 'fund', 'genius', 'peer', 'state', 'asia', 'bigtech', 'grit', 'ex', 'avenger'];
      for (final k in kinds) {
        for (final m in [storyMeet, storyClash, ...storyEndLines.values]) {
          final line = m[k];
          expect(line, isNotNull, reason: k);
          expect(enText(line!), isNotNull, reason: line);
          final en = txIn(M(line, [Nm('黒田興産')]), 'en');
          expect(_cjk.hasMatch(en), isFalse, reason: en);
        }
      }
      for (final r in RIVALS) {
        expect(kinds, contains(r.label ?? r.type));
      }
    });
  });

  group('セーブ', () {
    test('物語の状態・因縁・取締役会の約束はセーブを往復する', () {
      final s = _game();
      final c = _rival(s);
      c.rival!
        ..st = 1
        ..grudge = 2
        ..favor = 3
        ..hurt = 1
        ..allied = true
        ..allySince = 5
        ..friendSince = 7
        ..vexed = true
        ..from = '真壁商会';
      s.tieRec(c, 'g', M('株を買い集めた'));
      s.vow = {'due': 120, 'target': 5e8, 'y': 2001};
      s.yPrev = {'rev': 1, 'pre': 2, 'cap': 3, 'rank': 4};
      s.yAcc = {'rev': 5, 'pre': 6, 'n': 7};
      s.ret.add(Return(at: 99, fam: '真壁', west: false, col: '#fff', from: '真壁商会', end: 'bought', grudge: 5));
      final back = Game.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, rng: ParkMiller(1));
      final r = back.coById(c.id)!.rival!;
      expect([r.st, r.grudge, r.favor, r.hurt, r.allied, r.allySince, r.friendSince, r.vexed, r.from], [1, 3, 3, 1, true, 5, 7, true, '真壁商会']);
      expect(r.ties, c.rival!.ties);
      expect(back.vow, s.vow);
      expect(back.yPrev, s.yPrev);
      expect(back.yAcc, s.yAcc);
      expect(back.ret.last.end, 'bought');
      expect(back.ret.last.grudge, 5);
    });

    test('古いセーブ（物語と取締役会の項目がない）は空から始める', () {
      final s = _game();
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      j.remove('yAcc');
      j.remove('yPrev');
      j.remove('vow');
      for (final c in j['cos'] as List) {
        final r = (c as Map)['rival'] as Map?;
        if (r == null) continue;
        for (final k in ['st', 'grudge', 'favor', 'hurt', 'ties', 'friendSince', 'allySince', 'allied', 'vexed', 'end', 'endY', 'from']) {
          r.remove(k);
        }
      }
      for (final r in j['ret'] as List) {
        (r as Map).remove('end');
        r.remove('grudge');
      }
      final back = Game.fromJson(j, rng: ParkMiller(1));
      expect(back.vow, isNull);
      expect(back.yPrev, isNull);
      expect(back.yAcc, isEmpty);
      for (final c in back.cos.where((c) => c.rival != null)) {
        expect(c.rival!.st, 0);
        expect(c.rival!.ties, isEmpty);
        expect(c.rival!.friendSince, -1);
      }
      for (var i = 0; i < 24; i++) {
        botMonth(back);
      }
      expect(back.cap.isFinite, isTrue);
    });
  });

  group('切り替え', () {
    test('extras を切ると、取締役会も物語も動かない（乱数の使い方は試作と同じ）', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024), extras: false);
      for (var i = 0; i < 240; i++) {
        botMonth(s);
      }
      expect(s.yAcc, isEmpty);
      expect(s.yPrev, isNull);
      expect(s.cos.where((c) => c.rival != null && (c.rival!.st != 0 || c.rival!.ties.isNotEmpty)), isEmpty);
      expect(s.history.where((h) => h.k == 'rival' || h.k == 'board'), isEmpty);
    });

    test('extras が有効なら、自動プレイ50年で取締役会と物語が動き、落ちない', () {
      for (final seed in [11, 12, 13]) {
        final s = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(seed));
        final titles = <String>{};
        for (var t = 0; t < 12 * 50 && s.over == null; t++) {
          for (final e in s.events) {
            titles.add(msgKey(e.title));
          }
          botMonth(s);
          expect(s.cash.isFinite && s.cap.isFinite, isTrue);
        }
        expect(titles.any((t) => t.startsWith('取締役会')), isTrue, reason: '$seed');
        expect(titles.contains('宿敵との出会い'), isTrue, reason: '$seed');
        expect(s.cos.where((c) => c.rival != null && c.rival!.st > 0), isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
