// 才能の星5つ(裏は数字)と、幼少期に才能が上がる分かれ道(2026-10-21)。
import 'package:baseball_manager/game/childhood.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/talent.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role role, {int potential = 50, Map<Ability, int> gifts = const {}}) =>
    Player(
      name: 't',
      role: role,
      age: 8,
      potential: potential,
      abilities: {for (final a in abilitiesOf(role)) a: 20},
      gifts: gifts,
    );

void main() {
  test('素質は星1〜5つ。境目は 42・54・66・78', () {
    final stars = {
      0: 1, 41: 1, 42: 2, 53: 2, 54: 3, 65: 3, 66: 4, 77: 4, 78: 5, 100: 5, //
    };
    stars.forEach((pot, n) => expect(talentStarCount(pot), n, reason: '$pot'));
    expect(talentStars(60), '★★★☆☆');
    // 30〜90 に散らばる素質が、星1〜5つにほぼ均等に分かれる
    final count = List.filled(6, 0);
    for (var v = 30; v <= 90; v++) {
      count[talentStarCount(v)]++;
    }
    for (var n = 1; n <= 5; n++) {
      expect(count[n], greaterThanOrEqualTo(9), reason: '星$n');
    }
  });

  test('天賦は -2〜+2 が星1〜5つ(0 が星3つ)', () {
    expect([for (var g = -2; g <= 2; g++) giftStarCount(g)], [1, 2, 3, 4, 5]);
    expect(giftStars(0), '★★★☆☆');
    expect(giftStars(2), '★★★★★');
    expect(giftStars(-2), '★☆☆☆☆');
    expect(giftStarCount(9), 5); // 範囲外は丸める
  });

  test('giftUp: 指定の能力の天賦が+1。上限なら、使う能力のうち最も低いものを上げる', () {
    final p = _p(Role.batter);
    final up = giftUp(p, Ability.contact);
    expect(up.gift(Ability.contact), 1);
    // 使わない能力(打者の球威)を指定したら、使う能力のうち天賦がいちばん低い能力
    final low = _p(Role.batter, gifts: {
      Ability.contact: 1,
      Ability.power: 1,
      Ability.eye: 0,
      Ability.speed: 1,
      Ability.fielding: 1,
    });
    expect(giftUp(low, Ability.stuff).gift(Ability.eye), 1);
    // 指定の能力がもう上限なら、別の能力を上げる
    final top = _p(Role.batter, gifts: {Ability.contact: giftMax});
    final r = giftUp(top, Ability.contact);
    expect(r.gift(Ability.contact), giftMax);
    expect(abilitiesOf(Role.batter).where((a) => r.gift(a) == 1).length, 1);
    // 全部上限なら変わらない
    final all = _p(Role.pitcher, gifts: {
      for (final a in abilitiesOf(Role.pitcher)) a: giftMax
    });
    expect(giftUp(all, Ability.stuff).gifts, all.gifts);
  });

  test('才能が上がる分かれ道が3つあり、幼少期(6〜12歳)に出る', () {
    final ids = ['kid-talent-coach', 'kid-talent-mentor', 'kid-talent-flash'];
    for (final id in ids) {
      final st = childhoodStepById(id)!;
      expect(st.isChildhood, isTrue, reason: id);
      expect(st.age, inInclusiveRange(6, 12), reason: id);
      // 才能が上がる選択肢(素質か天賦)がちゃんとある
      var talentUp = 0;
      for (final role in [Role.batter, Role.pitcher]) {
        for (final ch in st.event.choices) {
          final base = _p(role);
          final r = ch.apply(base, const Condition(),
              abilitiesOf(role).first);
          if (r.player.potential > base.potential ||
              abilitiesOf(role).any((a) => r.player.gift(a) > base.gift(a))) {
            talentUp++;
          }
        }
      }
      expect(talentUp, greaterThanOrEqualTo(2), reason: id);
    }
  });

  test('素質が上がると星が増える。上がる量は控えめ(1つの選択で+4まで)', () {
    for (final id in ['kid-talent-coach', 'kid-talent-mentor', 'kid-talent-flash']) {
      for (final ch in childhoodStepById(id)!.event.choices) {
        final base = _p(Role.batter, potential: 53);
        final r = ch.apply(base, const Condition(), Ability.contact);
        expect(r.player.potential - base.potential, inInclusiveRange(0, 4),
            reason: '$id ${ch.label}');
      }
    }
    final coach = childhoodStepById('kid-talent-coach')!;
    final r = coach.event.choices.first
        .apply(_p(Role.batter, potential: 53), const Condition(), Ability.contact);
    expect(talentStarCount(r.player.potential), 3); // 星2つ→3つ
  });

  test('出来事の結果の文に、才能の星の変化が出る', () {
    final before = _p(Role.batter, potential: 53);
    final after = before.copyWith(potential: 57);
    expect(
        eventResultText(before, const Condition(), after, const Condition()),
        contains('才能 ★★☆☆☆→★★★☆☆'));
    // 星が変わらない小さな上昇
    final low = _p(Role.batter, potential: 44);
    final small = low.copyWith(potential: 47);
    expect(
        eventResultText(low, const Condition(), small, const Condition()),
        contains('才能が伸びた'));
    // 能力ごとの才能
    final g = giftUp(before, Ability.contact);
    expect(eventResultText(before, const Condition(), g, const Condition()),
        contains('ミートの才能 ★★★☆☆→★★★★☆'));
  });
}
