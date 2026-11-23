import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 能力・特性で増えた手の印（`Choice.via`、2026-11-24）。ユーザー「智が優れて意味ある？」。
/// 能力・特性・持ち物の条件つきで出る手に、どのおかげで出たかの印が付く。
final _digits = RegExp('[0-9０-９%％]');

class _Seen {
  /// via の語 → 出た数。
  final via = <String, int>{};

  /// 岐路の手の数（「今年の重点」を除く）。
  var choices = 0;

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
    if (p!.title != '今年の重点' && (stat == null || n > 1)) {
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
        // 能力の低い人生（置き直した値が段に届かない）には、能力の印は出ない。
        if (stat != null && stat < 45) {
          expect(viaIsAbility(v), isFalse, reason: '能力$statの人に「$v」: ${c.label}');
        }
      }
    }
    g.choose(smart ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
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
    // 武・知・政・魅のどれの印も出る。
    for (final a in ['武', '知', '政', '魅']) {
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
