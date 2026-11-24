import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/childhood.dart';
import 'package:ranse/engine/childhood_focus.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 重点の tag → 画面に出る名。
const _labels = {
  'yumiba': '弓と馬の稽古に励む',
  'yakuso': '野山で薬草を摘む',
  'uta': '歌と書を習う',
  'komori': '弟妹の子守をする',
  'kawa': '川で魚を獲る',
  'tsukai': '市で使い走りをする',
  'kyo': '経を覚える',
};

/// 重点 → その重点に合う生まれ（身分・女か・生まれ順）。
const _fit = <String, (String, bool, int)>{
  'yumiba': ('samurai', false, 2),
  'yakuso': ('farmer', true, 2),
  'uta': ('lowsamurai', true, 1),
  'komori': ('farmer', true, 1),
  'kawa': ('fisher', false, 3),
  'tsukai': ('merchant', false, 2),
  'kyo': ('priest', false, 2),
};

/// 大人の岐路 → 出てよい旗（どれか一つ）。
const _echoNeeds = <String, List<String>>{
  'e4_yumi': ['cf_yumi_praised'],
  'e4_herb': ['cf_herb_healer'],
  'e4_uta': ['cf_uta_praised', 'cf_fine_hand'],
  'e4_sib': ['cf_sib_close', 'cf_sib_strong'],
  'e4_river': ['cf_read_river'],
  'e4_ootana': ['cf_ootana_offer', 'cf_errand_trusted'],
  'e4_sutra': ['cf_sutra_comfort', 'cf_sutra_listened'],
};

final _stageIds = {for (final v in kChildFocusStages.values) ...v};
bool _ours(String id) => _stageIds.contains(id) || id.startsWith('e4_');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seen = <String, List<Choice>>{};

Birth _birth(Rng r, String cls, {bool female = false, int order = 1}) {
  final b = rollBirth(r);
  final k = kClasses.firstWhere((c) => c.id == cls);
  return Birth(
    cls: k,
    region: b.region,
    faction: b.faction,
    startYear: b.startYear,
    month: b.month,
    day: b.day,
    female: female,
    order: order,
    stats: b.stats,
    traits: b.traits,
    rarity: b.rarity,
    name: b.name,
    label: clsLabel(k, female, order),
    sameClass: b.sameClass,
    birthRank: calcBirthRank(k, female, order),
  );
}

/// [cls] の子を5歳まで生かして返す（亡くなれば引き直す）。
Game _kid(int seed, String cls, {bool female = false, int order = 1}) {
  for (var i = 0; i < 50; i++) {
    final rng = Rng(seed * 61 + i);
    final g = Game(rng: rng);
    g.start(_birth(rng, cls, female: female, order: order));
    if (!g.finished) return g;
  }
  throw StateError('生き延びる子がいない');
}

/// 新しく立った `scene:` の旗のうち、この作り込みの岐路の id。
Set<String> _newScenes(Game g, Set<String> known) => {
  for (final f in g.l.flags)
    if (f.startsWith('scene:') && !known.contains(f) && _ours(f.substring(6)))
      f.substring(6),
};

class _Run {
  final order = <String>[]; // 出た順
  final ages = <String, int>{};
}

/// 人生の終わりまで（[childOnly] なら元服まで）進める。
_Run _play(
  Game g,
  int Function(Game g, Prompt p) pick, {
  bool childOnly = false,
  void Function(Game g)? atAdult,
}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:')).toSet();
  var adultDone = false;
  var n = 0;
  while (!g.finished && n++ < 3000) {
    if (childOnly && !g.isChild) break;
    final p = g.prompt;
    expect(p, isNotNull, reason: '選択肢が出ていない（${g.age}歳）');
    if (!adultDone && !g.isChild && p!.title == 'この年の心がけ') {
      adultDone = true;
      atAdult?.call(g);
      known = g.l.flags.where((f) => f.startsWith('scene:')).toSet();
    }
    for (final id in _newScenes(g, known)) {
      out.order.add(id);
      out.ages[id] = g.age;
      _seen[id] = p!.choices;
      final need = _echoNeeds[id];
      if (need != null) {
        expect(need.any(g.hasFlag), isTrue, reason: '$id が前の旗なしに出た');
      }
    }
    known = g.l.flags.where((f) => f.startsWith('scene:')).toSet();
    g.choose(pick(g, p!));
  }
  return out;
}

void main() {
  test('表: 重点7・続けた年の岐路14がすべて子どもの岐路に、大人の岐路7が大人の岐路に一度ずつある', () {
    expect(kChildFocusStages.length, 7);
    expect(_stageIds.length, 14);
    final g = Game(rng: Rng(1));
    for (final id in _stageIds) {
      final hits = g.childScenes.where((s) => s.id == id).toList();
      expect(hits.length, 1, reason: id);
      expect(hits.first.onlyForced, isTrue, reason: id);
    }
    for (final id in kChildFocusEchoIds) {
      expect(g.adultScenes.where((s) => s.id == id).length, 1, reason: id);
    }
    expect(_echoNeeds.keys.toSet(), kChildFocusEchoIds.toSet());
  });

  test('身分・性別・年頃で、出る重点が分かれる', () {
    Set<String> tags(
      String cls,
      int age, {
      bool female = false,
      int order = 1,
      bool monk = false,
    }) {
      final g = _kid(age * 7 + cls.length, cls, female: female, order: order);
      g.l.t = age * 2;
      if (monk) g.setFlag('monk');
      final t = childFocusTags(g).toSet();
      // 画面に出す重点の一覧にも、同じものが入っている。
      final labels = childFocusOptions(g).map((o) => o.label).toSet();
      for (final k in _labels.keys) {
        expect(
          labels.contains(_labels[k]),
          t.contains(k),
          reason: '$cls $age $k',
        );
      }
      return t;
    }

    expect(tags('samurai', 9), {'yumiba'});
    expect(tags('samurai', 8), isEmpty);
    expect(tags('daimyo', 12), {'yumiba'});
    expect(tags('samurai', 9, female: true), {'uta'});
    expect(tags('daimyo', 7, female: true), {'uta'});
    expect(tags('ashigaru', 10, order: 2), isEmpty); // 足軽の子に弓馬は出さない
    expect(tags('ashigaru', 10).contains('komori'), isTrue); // 子守は長子の十一まで
    expect(tags('farmer', 7), {'yakuso', 'komori', 'kawa'});
    expect(tags('farmer', 7, female: true, order: 2), {'yakuso'});
    expect(tags('farmer', 12), {'yakuso', 'kawa'});
    expect(tags('farmer', 9, monk: true), {'yakuso', 'kyo'});
    expect(tags('fisher', 8, order: 3), {'yakuso', 'kawa'});
    expect(tags('merchant', 8, order: 2), {'tsukai'});
    expect(tags('merchant', 8, female: true), {'uta', 'komori', 'tsukai'});
    expect(tags('priest', 6), {'kyo'});
    expect(tags('priest', 7), {'yakuso', 'kyo'});
    expect(tags('beggar', 9, order: 2), {'yakuso', 'kawa', 'tsukai'});
    expect(tags('ninja', 10), isEmpty);
    expect(tags('ronin', 6).contains('komori'), isTrue);
    // 重点の名と匂わせに数字が無い。
    for (final cls in ['samurai', 'farmer', 'merchant', 'priest', 'beggar']) {
      for (final female in [false, true]) {
        final g = _kid(3, cls, female: female);
        g.l.t = 9 * 2;
        for (final o in childFocusOptions(g)) {
          expect(o.hint.isNotEmpty, isTrue);
          expect(_digits.hasMatch(o.label + o.hint), isFalse, reason: o.label);
        }
      }
    }
  });

  test('重点を続けた子に、一の段・二の段の岐路が出る（毎年選ぶ子・半分の年だけ選ぶ子）', () {
    final lines = <String>[];
    for (final tag in kChildFocusStages.keys) {
      final st = kChildFocusStages[tag]!;
      final fit = _fit[tag]!;
      for (final share in [1.0, .5]) {
        var a2 = 0, sawA = 0, a4 = 0, sawB = 0, lives = 0;
        for (var s = 0; s < 120; s++) {
          final g = _kid(
            s + tag.length * 1000,
            fit.$1,
            female: fit.$2,
            order: fit.$3,
          );
          final r = Rng(s + 77);
          final run = _play(g, (g, p) {
            if (p.title == 'この年の心がけ' && g.isChild && r.chance(share)) {
              final i = p.choices.indexWhere((c) => c.label == _labels[tag]);
              if (i >= 0) return i;
            }
            return r.range(0, p.choices.length - 1);
          }, childOnly: true);
          lives++;
          final n = g.l.focus[tag] ?? 0;
          if (n >= 2) {
            a2++;
            if (g.hasFlag('scene:${st[0]}')) sawA++;
          }
          if (n >= 4) {
            a4++;
            if (g.hasFlag('scene:${st[1]}')) sawB++;
          }
          // 二の段は、一の段より二年以上あとにだけ出る。
          if (run.ages.containsKey(st[1])) {
            expect(
              run.ages.containsKey(st[0]),
              isTrue,
              reason: '${st[1]} が一の段なしに出た',
            );
            expect(
              run.ages[st[1]]! - run.ages[st[0]]!,
              greaterThanOrEqualTo(2),
              reason: st[1],
            );
          }
          // 岐路が出たのは、その重点を二度以上選んだ子だけ。
          for (final id in run.order) {
            final t = kChildFocusStages.entries
                .where((e) => e.value.contains(id))
                .map((e) => e.key)
                .firstOrNull;
            if (t != null) {
              expect(g.l.focus[t] ?? 0, greaterThanOrEqualTo(2), reason: id);
            }
          }
        }
        if (share == 1.0) {
          expect(a2, greaterThan(lives * .5), reason: tag);
          expect(sawA / a2, greaterThanOrEqualTo(.95), reason: '$tag 一の段');
          expect(sawB / a4, greaterThanOrEqualTo(.9), reason: '$tag 二の段');
        } else {
          expect(sawA, greaterThan(0), reason: '$tag 半分の年');
        }
        lines.add(
          '$tag(${share == 1 ? '毎年' : '半分'}) 一の段 $sawA/$lives・二の段 $sawB/$lives',
        );
      }
    }
    // ignore: avoid_print
    print('【子どもの重点の岐路】${lines.join(' / ')}');
  });

  test('大人の岐路は、子どもの旗がなければ出ない（ふつうの人生）', () {
    var lives = 0, echoes = 0;
    for (var s = 0; s < 600; s++) {
      final rng = Rng(s + 31000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished) continue;
      lives++;
      final r = Rng(s);
      final run = _play(
        g,
        (g, p) => s.isEven
            ? r.range(0, p.choices.length - 1)
            : pickAmbitious(g, p, r),
      );
      echoes += run.order.where((id) => id.startsWith('e4_')).length;
    }
    // ignore: avoid_print
    print('【子どもの重点の大人の岐路】ふつうの $lives 人生で $echoes');
    expect(lives, greaterThan(300));
  });

  test('子どもの旗を立てた大人には、大人の岐路がいろいろ出る', () {
    final seenIds = <String>{};
    var adults = 0;
    for (var s = 0; s < 300; s++) {
      final rng = Rng(s + 52000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished) continue;
      final r = Rng(s + 5);
      final run = _play(
        g,
        (g, p) => s.isEven
            ? r.range(0, p.choices.length - 1)
            : pickAmbitious(g, p, r),
        atAdult: (g) {
          adults++;
          for (final f in [
            'cf_yumi_praised',
            'cf_herb_healer',
            'cf_uta_praised',
            'cf_sib_close',
            'cf_sib_name:お松',
            'cf_read_river',
            'cf_errand_trusted',
            'cf_sutra_comfort',
          ]) {
            g.setFlag(f);
          }
        },
      );
      seenIds.addAll(run.order.where((id) => id.startsWith('e4_')));
    }
    expect(adults, greaterThan(150));
    expect(seenIds.length, greaterThanOrEqualTo(6), reason: '$seenIds');
  });

  test('出た岐路の選択肢には匂わせがあり、label・hint に数字が無い', () {
    // 上のテストで集めたもの（このテストだけ流したときのために、ここでも少し流す）。
    for (final tag in kChildFocusStages.keys) {
      final fit = _fit[tag]!;
      for (var s = 0; s < 30; s++) {
        final g = _kid(s + 9000, fit.$1, female: fit.$2, order: fit.$3);
        final r = Rng(s);
        _play(g, (g, p) {
          if (p.title == 'この年の心がけ' && g.isChild) {
            final i = p.choices.indexWhere((c) => c.label == _labels[tag]);
            if (i >= 0) return i;
          }
          return r.range(0, p.choices.length - 1);
        }, childOnly: true);
      }
    }
    expect(_seen.keys.where(_stageIds.contains).length, 14);
    for (final e in _seen.entries) {
      expect(e.value.length, inInclusiveRange(2, 4), reason: e.key);
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key}: ${c.label}');
        expect(c.hint!.isNotEmpty, isTrue);
        expect(
          _digits.hasMatch(c.label + c.hint!),
          isFalse,
          reason: '${e.key}: ${c.label}',
        );
      }
    }
  });

  test('遺されたもの: 子どもの重点の旗と大人の旗で行が出て、子どもには子ども向けの行だけ', () {
    final g = _kid(5, 'farmer');
    g.l.t = 12 * 2;
    g.setFlag('cf_herb_healer');
    g.setFlag('cf_sib_close');
    g.setFlag('cf_sib_name:お松');
    final kid = remembrances(g);
    expect(kid.any((s) => s.contains('薬草')), isTrue);
    expect(kid.any((s) => s.contains('お松')), isTrue);
    g.setFlag('e4_herb_saved');
    g.l.t = 40 * 2;
    final adult = remembrances(g);
    expect(adult.any((s) => s.contains('熱の出た村')), isTrue);
    // 同じ組（herb）からは一行だけ。
    expect(adult.where((s) => s.contains('薬草')).length, 1);
    final rows = kRemembrances
        .where((r) => r.id.startsWith('cf_') || r.id.startsWith('e4_'))
        .toList();
    expect(rows.length, inInclusiveRange(8, 12));
    for (final r in rows) {
      expect(_digits.hasMatch(r.say(g)), isFalse, reason: r.id);
    }
  });
}
