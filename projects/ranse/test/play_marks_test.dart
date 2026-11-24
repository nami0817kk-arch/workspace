import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/history_shift.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/life_record.dart';
import 'package:ranse/engine/major_scenes.dart';
import 'package:ranse/engine/play_views.dart';
import 'package:ranse/engine/rng.dart';

/// 画面と記録まわりの作り込み（2026-11-25）のうち、エンジンで決まるところ。
/// 見聞録の絞り込み・縁の言葉・これまでの人生の記録・稀な生まれ・歴史が動いた知らせ・大きな岐路の印。

/// 無作為に選んで最後まで遊ぶ。[each] は手を選ぶ前と後に呼ぶ。
void _play(Game g, Rng r, void Function(Prompt p, List<String> before) each) {
  var n = 0;
  while (!g.finished && n++ < 4000) {
    final p = g.prompt!;
    final before = historyKeys(g);
    g.choose(r.range(0, p.choices.length - 1));
    each(p, before);
  }
}

void main() {
  // ---------- 7. 見聞録の絞り込み ----------
  group('見聞録の絞り込み', () {
    final log = [
      LogEntry('1560春夏', '【世】桶狭間で今川義元が討たれた。', 'big'),
      LogEntry('1560春夏', '【世】武田家が北条家の領地を切り取った。', ''),
      LogEntry('1561春夏', '今年は武芸を磨く。武+2', ''),
      LogEntry('1562春夏', '【再会】太郎と酒を酌み交わした。', 'good'),
    ];
    final names = ['太郎'];

    test('世の動きは【世】の行だけ、自分のことはそれ以外', () {
      expect(
        [for (final e in log) logMatches(LogFilter.world, e, names)],
        [true, true, false, false],
      );
      expect(
        [for (final e in log) logMatches(LogFilter.self, e, names)],
        [false, false, true, true],
      );
      expect(
        [for (final e in log) logMatches(LogFilter.all, e, names)],
        [true, true, true, true],
      );
    });

    test('縁のある人は、いま縁のある人の名を含む行', () {
      expect(
        [for (final e in log) logMatches(LogFilter.people, e, names)],
        [false, false, false, true],
      );
      expect(
        [
          for (final e in log)
            logMatches(LogFilter.people, e, const <String>[]),
        ],
        [false, false, false, false],
      );
    });

    test('実際の人生でも、世の動きの行が絞り込める（全体＝自分のこと＋世の動き）', () {
      var worlds = 0;
      for (var seed = 0; seed < 40; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng)..start(rollBirth(rng));
        _play(g, Rng(seed + 7), (p, b) {});
        final all = filterLog(LogFilter.all, g.l.log, g.l);
        final self = filterLog(LogFilter.self, g.l.log, g.l);
        final world = filterLog(LogFilter.world, g.l.log, g.l);
        expect(self.length + world.length, all.length);
        for (final e in filterLog(LogFilter.people, g.l.log, g.l)) {
          expect(g.l.people.values.any((p) => e.txt.contains(p.name)), isTrue);
        }
        worlds += world.length;
      }
      expect(worlds, greaterThan(0));
    });
  });

  // ---------- 12. 縁の深さ ----------
  test('絆は言葉で出し、縁の物語の境目（50）で言葉が変わる', () {
    expect(bondWord(100), '深い絆');
    expect(bondWord(80), '深い絆');
    expect(bondWord(79), '打ち解けた仲');
    expect(bondWord(50), '打ち解けた仲');
    expect(bondWord(49), 'ぎこちない');
    expect(bondWord(25), 'ぎこちない');
    expect(bondWord(24), '冷えた仲');
    expect(bondWord(0), '冷えた仲');
    for (var b = 0; b <= 100; b++) {
      expect(bondWord(b), isNot(matches(RegExp(r'[0-9０-９]'))));
    }
  });

  // ---------- 17. これまでの人生 ----------
  group('これまでの人生の記録', () {
    Game finished(int seed) {
      final rng = Rng(seed);
      final g = Game(rng: rng)..start(rollBirth(rng));
      _play(g, Rng(seed + 1), (p, b) {});
      return g;
    }

    test('終わった人生から一件作れ、保存の形を往復できる', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = finished(seed);
        expect(g.finished, isTrue);
        final r = LifeRecord.of(g);
        expect(r.name, g.l.name);
        expect(r.born, g.l.startYear);
        expect(r.age, g.age);
        expect(r.region, g.l.region);
        expect(r.title, isNotEmpty);
        expect(r.text, isNotEmpty);
        expect(r.cause, isNotEmpty);
        expect(r.path.length, lessThanOrEqualTo(LifeRecord.kPathLines));
        final back = LifeRecord.fromJson(r.toJson());
        expect(back.toJson(), r.toJson());
        expect(back.id, r.id);
      }
    });

    test('欠けた古い記録も読める', () {
      final r = LifeRecord.fromJson({});
      expect(r.name, isNotEmpty);
      expect(r.tier, isNull);
      expect(r.path, isEmpty);
    });

    test('新しい順に積み、同じ人生は二度記さず、上限を越えたら古いものから捨てる', () {
      final a = LifeRecord.of(finished(3));
      final b = LifeRecord.of(finished(4));
      var list = addLifeRecord([], a);
      list = addLifeRecord(list, a);
      expect(list.length, 1);
      list = addLifeRecord(list, b);
      expect(list.map((e) => e.id).toList(), [b.id, a.id]);
      var many = <LifeRecord>[];
      for (var i = 0; i < kMaxLifeRecords + 20; i++) {
        many = addLifeRecord(
          many,
          LifeRecord.fromJson({...a.toJson(), 'n': '人$i'}),
        );
      }
      expect(many.length, kMaxLifeRecords);
      expect(many.first.name, '人${kMaxLifeRecords + 19}');
      expect(many.last.name, '人20');
    });
  });

  // ---------- 25. 稀な生まれ ----------
  test('稀な生まれは、万に一人以上か稀・幻の特性を持つ生まれだけ', () {
    final rng = Rng(5);
    var special = 0;
    const n = 4000;
    for (var i = 0; i < n; i++) {
      final b = rollBirth(rng);
      final rareTrait = b.traits.any(
        (t) => t.tier == TraitTier.rare || t.tier == TraitTier.mythic,
      );
      final want = b.rarity >= kSpecialBirthRarity || rareTrait;
      expect(isSpecialBirth(b), want);
      expect(specialBirthHead(b) != null, want);
      if (want) special++;
    }
    // 引いた瞬間が特別に見えるよう、稀な生まれは一部だけ（測った割合は CLAUDE.md）。
    expect(special, greaterThan(0));
    expect(special / n, lessThan(.35));
  });

  // ---------- 30. 歴史が動いた知らせ ----------
  group('歴史が動いた知らせ', () {
    Game young(int seed) {
      for (var s = seed; s < seed + 200; s++) {
        final rng = Rng(s);
        final g = Game(rng: rng)..start(rollBirth(rng));
        if (!g.finished) return g;
      }
      throw StateError('生き延びる人生が見つからない');
    }

    test('選んだ手で世界線が変わると一度だけ知らせ、次の手で消える', () {
      final g = young(1);
      expect(historyKeys(g), isEmpty);
      g.prompt = Prompt('試しの岐路', '', [
        Choice.h('信長を救う', '匂わせ', () {
          g.setFlag('history_honnoji');
          return null;
        }),
      ], () {});
      g.choose(0);
      expect(g.historyShift?.key, 'nobunaga');
      expect(g.historyShift?.title, kLineNames['nobunaga']);
      expect(g.historyShift?.text, kHistoryShiftNotes['nobunaga']);
      // 変わらない手を選ぶと消える。
      g.prompt = Prompt('次の岐路', '', [
        Choice.h('見送る', '何も起きない', () => null),
      ], () {});
      g.choose(0);
      expect(g.historyShift, isNull);
    });

    test('小さな分岐も知らせ、閉じれば消える', () {
      final g = young(2);
      g.prompt = Prompt('試しの岐路', '', [
        Choice.h('踏みとどまる', '匂わせ', () {
          g.setFlag('history_nagashino');
          return null;
        }),
      ], () {});
      g.choose(0);
      expect(g.historyShift?.title, kSmallBranchNames['history_nagashino']);
      g.dismissHistoryShift();
      expect(g.historyShift, isNull);
    });

    test('すでに変わっていた歴史は、もう一度は知らせない', () {
      final g = young(3)..setFlag('history_okehazama');
      g.prompt = Prompt('試しの岐路', '', [
        Choice.h('進む', '匂わせ', () => null),
      ], () {});
      g.choose(0);
      expect(g.historyShift, isNull);
    });

    test('知らせの文は、世界線と小さな分岐のすべてにある', () {
      for (final k in kLineNames.keys.where((k) => k != 'real')) {
        expect(kHistoryShiftNotes[k], isNotNull, reason: k);
      }
      for (final k in kSmallBranchNames.keys) {
        expect(kHistoryShiftNotes[k], isNotNull, reason: k);
      }
      for (final t in kHistoryShiftNotes.values) {
        expect(t, isNot(matches(RegExp(r'[0-9０-９]'))));
      }
    });

    test('ふつうに遊んでも、知らせは歴史が変わった手のあとにだけ出る', () {
      var shifts = 0;
      for (var seed = 0; seed < 150; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng)..start(rollBirth(rng));
        _play(g, Rng(seed + 3), (p, before) {
          final grew = historyKeys(g).any((k) => !before.contains(k));
          expect(g.historyShift != null, grew, reason: '$seed ${p.title}');
          if (grew) shifts++;
        });
      }
      expect(shifts, greaterThanOrEqualTo(0));
    });
  });

  // ---------- 31. 大きな岐路の印 ----------
  group('大きな岐路の印', () {
    test('表の場面の id は、すべて実在する', () {
      final g = Game();
      final ids = {
        for (final s in [...g.childScenes, ...g.adultScenes]) s.id,
      };
      for (final id in kMajorScenes.keys) {
        expect(ids, contains(id), reason: id);
      }
      // 少数に絞る（多すぎると印の重みがなくなる）。
      expect(kMajorScenes.length, lessThanOrEqualTo(20));
    });

    test('印は表の場面にだけ付き、毎年の心がけには付かない', () {
      var marked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed * 7 + 1);
        final g = Game(rng: rng)..start(rollBirth(rng));
        _play(g, Rng(seed), (p, b) {
          if (!p.major) return;
          marked++;
          expect(p.title, isNot('この年の心がけ'));
          expect(
            kMajorScenes.keys.any((id) => g.hasFlag('scene:$id')),
            isTrue,
            reason: p.title,
          );
        });
      }
      expect(marked, greaterThan(0));
    });
  });
}
