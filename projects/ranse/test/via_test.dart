import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/talents.dart';
import 'package:ranse/engine/trait_scenes.dart';

import 'bot.dart';

/// 能力・特性で増えた手の印（`Choice.via`、2026-11-24）。ユーザー「智が優れて意味ある？」。
/// 能力・特性・持ち物の条件つきで出る手に、どのおかげで出たかの印が付く。
final _digits = RegExp('[0-9０-９%％]');

/// 斬り合い・槍働きの手の名に出る言葉。戦えない人（`Game.canFight` でない女性）の武の手には出さない
/// （その身に合う形＝薙刀の心得・身のこなし・力仕事だけ）。
final _blade = RegExp('斬|槍で|槍を|太刀|一騎打ち|討ち|首を');

class _Seen {
  /// via の語 → 出た数。
  final via = <String, int>{};

  /// 岐路の手の数（「今年の重点」を除く）。
  var choices = 0;

  /// 場面が起きた訳（`Prompt.cause`）の語 → 出た数。
  final cause = <String, int>{};

  /// 訳の付かない岐路の数と、【才】の一行に付いた訳の数。
  var plain = 0, saiLines = 0;

  /// 戦えない人に出た武の手の数。
  var buNoFight = 0;

  int get ability =>
      via.entries.where((e) => viaIsAbility(e.key)).fold(0, (a, e) => a + e.value);
}

/// [seed] の人生を終わりまで流す。[stat] があれば、選ぶたびに五つの能力をその値に置き直す。
/// [traits] は生まれた日に持たせる特性。出た手の via を数え、出た瞬間に決まりを確かめる。
void _life(
  int seed,
  _Seen out, {
  int? stat,
  List<String> traits = const [],
  bool smart = false,
}) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(rollBirth(rng));
  for (final t in traits) {
    if (t == 'onna' && !g.l.female) continue;
    if (!g.l.traits.contains(t)) g.l.traits.add(t);
  }
  final r = Rng(seed + 77);
  var n = 0;
  while (!g.finished && n++ < 4000) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (stat != null) {
      // 出ている問いは置き直す前の能力で作られているので、数えるのは置き直したあとに出た問いだけ（n > 1）。
      g.l
        ..bu = stat
        ..chi = stat
        ..sei = stat
        ..mi = stat
        ..un = stat;
    }
    // 「今年の重点」には、場面の訳は付かない。
    if (p!.title == '今年の重点') expect(p.cause, isNull);
    if (p.title != '今年の重点' && (stat == null || n > 1)) {
      // 場面が起きた訳（能力で起きる岐路は能力の字、特性の場面は特性の名）。
      final pc = p.cause;
      if (pc == null) {
        out.plain++;
      } else {
        out.cause[pc] = (out.cause[pc] ?? 0) + 1;
        expect(viaKnown(pc), isTrue, reason: '決めた語にない訳「$pc」: ${p.title}');
        if (!viaIsAbility(pc)) {
          final t = kTraits.firstWhere((t) => t.name == pc);
          expect(g.has(t.id), isTrue, reason: '$pc を持たない人に、その特性の場面: ${p.title}');
        } else if (stat != null && stat < 45) {
          fail('能力$statの人に、能力で起きる岐路「$pc」: ${p.title}');
        }
      }
      for (final c in p.choices) {
        out.choices++;
        final v = c.via;
        if (v == null) continue;
        out.via[v] = (out.via[v] ?? 0) + 1;
        expect(viaKnown(v), isTrue, reason: '決めた語にない via「$v」: ${c.label}');
        expect(_digits.hasMatch(v), isFalse, reason: v);
        // (c) 印が付いても、手の名と匂わせに数字は出さない。
        expect(c.hint, isNotNull, reason: c.label);
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
        // 特性の名の印は、その特性を持つ人にだけ。持ち物の印は、持つ人にだけ。
        if (!viaIsAbility(v) && !kViaItems.contains(v)) {
          final t = kTraits.firstWhere((t) => t.name == v);
          expect(g.has(t.id), isTrue, reason: '$v を持たない人に印が出た: ${c.label}');
        }
        if (v == '鉄砲') expect(g.l.gun, isTrue, reason: c.label);
        // 戦えない人には、斬り合いの武の手を出さない。
        if (v.contains('武') && !g.canFight) {
          out.buNoFight++;
          expect(_blade.hasMatch(c.label), isFalse, reason: '戦えない人に斬り合いの手: ${c.label}');
        }
        // 能力の低い人生（置き直した値が段に届かない）には、能力の印は出ない。
        if (stat != null && stat < 45) {
          expect(viaIsAbility(v), isFalse, reason: '能力$statの人に「$v」: ${c.label}');
        }
      }
    }
    g.choose(smart ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  // 能力の段を越えた【才】の一行には、どの能力かの訳が付く。ほかの行には付かない。
  for (final e in g.l.log) {
    if (e.txt.startsWith('【才】')) {
      expect(e.cause != null && kViaAbilities.contains(e.cause), isTrue, reason: e.txt);
      out.saiLines++;
    } else {
      expect(e.cause, isNull, reason: e.txt);
    }
  }
}

void main() {
  test('via の語の決まり: 能力は一字か二字、特性と持ち物は名', () {
    for (final a in kViaAbilities) {
      expect(viaIsAbility(a), isTrue);
      expect(viaKnown(a), isTrue);
    }
    expect(viaIsAbility('知魅'), isTrue);
    expect(viaIsAbility('武知政'), isFalse);
    expect(viaIsAbility('薬の心得'), isFalse);
    expect(viaKnown('薬の心得'), isTrue);
    expect(viaKnown('女武者'), isTrue);
    expect(viaKnown('鉄砲'), isTrue);
    expect(viaKnown('知恵'), isFalse);
    expect(viaKnown(''), isFalse);
    // 特性の名が、能力の字だけの語と紛れない。
    for (final t in kTraits) {
      expect(viaIsAbility(t.name), isFalse, reason: t.name);
    }
    // 印のない手は null（既存の呼び出しはそのまま通る）。
    expect(Choice.h('手', '匂わせ', () => null).via, isNull);
    expect(Choice('手').via, isNull);
    expect(Choice.h('手', '匂わせ', () => null, via: '知').via, '知');
  });

  test('能力の高い人生には能力の印の付いた手が多く出て、低い人生には出ない', () {
    final high = _Seen(), low = _Seen();
    for (var s = 0; s < 400; s++) {
      _life(52000 + s, high, stat: 95, smart: s.isOdd);
      _life(52000 + s, low, stat: 20, smart: s.isOdd);
    }
    // ignore: avoid_print
    print('【印】能力95: 岐路の手${high.choices}のうち能力の印${high.ability} ${high.via}／能力20: 手${low.choices}のうち${low.ability} ${low.via}');
    expect(low.ability, 0);
    expect(high.ability, greaterThan(150));
    // 武と運の高い人には、武と運で増えた手が多く出る（2026-11-24 に武59・運40の手を足した）。
    expect(high.via['武'] ?? 0, greaterThan(120));
    expect(high.via['運'] ?? 0, greaterThan(80));
    // 戦えない人にも武の手（身に合う形）は出る。斬り合いの手でないことは出た瞬間に確かめている。
    expect(high.buNoFight, greaterThan(0));
    // 能力で起きる岐路には訳が付き、能力の低い人生には付かない。訳の付かない岐路がほとんど。
    // ignore: avoid_print
    print('【訳】能力95: ${high.cause}・訳なし${high.plain}・【才】${high.saiLines}／能力20: ${low.cause}');
    expect(low.cause.keys.where(viaIsAbility), isEmpty);
    for (final a in kViaAbilities) {
      expect(high.cause.keys.any((k) => k.contains(a)), isTrue, reason: '$aで起きる岐路に訳が付かない');
    }
    expect(high.plain, greaterThan(high.cause.values.fold<int>(0, (a, b) => a + b) * 5));
    // 武・知・政・魅・運のどれの印も出る。
    for (final a in kViaAbilities) {
      expect(
        high.via.keys.any((k) => viaIsAbility(k) && k.contains(a)),
        isTrue,
        reason: '$aの印が一度も出ない',
      );
    }
  });

  test('特性を持たせた人生には、特性の名の印が出る', () {
    final seen = _Seen();
    for (var s = 0; s < 400; s++) {
      _life(
        53000 + s,
        seen,
        traits: const ['herbal', 'onna', 'builder', 'dialects', 'temple_kin'],
        smart: s.isOdd,
      );
    }
    // ignore: avoid_print
    print('【印】特性を持たせた人生: ${seen.via}');
    expect(seen.via['薬の心得'] ?? 0, greaterThan(0));
    expect(seen.via['女武者'] ?? 0, greaterThan(0));
    final names = seen.via.keys.where((k) => !viaIsAbility(k) && !kViaItems.contains(k));
    expect(names.length, greaterThanOrEqualTo(2));
    // 特性の場面には、その特性の名の訳が付く（持たない人に出ないことは出た瞬間に確かめている）。
    // ignore: avoid_print
    print('【訳】特性を持たせた人生: ${seen.cause}');
    final traitCauses = seen.cause.keys.where((k) => !viaIsAbility(k));
    expect(traitCauses.length, greaterThanOrEqualTo(3));
  });

  test('場面の訳の表: 能力の岐路は能力の字、特性の場面は特性の名、ふつうの岐路には付かない', () {
    final g = Game(rng: Rng(1));
    var tal = 0, tr = 0;
    for (final s in [...g.adultScenes, ...g.childScenes]) {
      final c = sceneCauseFor(s.id);
      if (s.id.startsWith('tal_low_')) {
        expect(c, isNull, reason: s.id);
      } else if (s.id.startsWith('tal_')) {
        expect(c != null && viaIsAbility(c), isTrue, reason: s.id);
        tal++;
      } else if (s.id.startsWith('tr_')) {
        expect(c != null && kTraits.any((t) => t.name == c), isTrue, reason: s.id);
        tr++;
      } else {
        expect(c, isNull, reason: s.id);
      }
    }
    expect(tal, greaterThanOrEqualTo(38));
    expect(tr, greaterThanOrEqualTo(150));
    expect(sceneCauseFor(null), isNull);
    expect(sceneCauseFor('tal_bu_gozen'), '武');
    expect(sceneCauseFor('tal_un_ship'), '運');
    expect(sceneCauseFor('tal_combo_shisha'), '政魅');
    expect(sceneCauseFor('tal_c_shika'), '運');
    expect(sceneCauseFor('bandits'), isNull);
    // 表のどの特性の場面も、その特性の名になる。
    for (final e in kTraitScenesDone.entries) {
      final name = kTraits.firstWhere((t) => t.id == e.key).name;
      for (final id in e.value) {
        expect(sceneCauseFor(id), name, reason: id);
      }
    }
  });

  test('ふつうの人生でも、印は決めた語だけで、手の名と匂わせに数字がない', () {
    final seen = _Seen();
    for (var s = 0; s < 400; s++) {
      _life(54000 + s, seen, smart: s.isOdd);
    }
    // ignore: avoid_print
    print('【印】ふつうの人生: 岐路の手${seen.choices}のうち印つき${seen.via.values.fold(0, (a, b) => a + b)} ${seen.via}');
    expect(seen.via, isNotEmpty);
  });
}
