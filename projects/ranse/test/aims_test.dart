import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/adult.dart';
import 'package:ranse/engine/aims.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/bonds.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 心がけに足した三つ（2026-11-25）: 謀反の支度・縁のある人を訪ねる・よその家に仕え直す道を探る。
final _digits = RegExp('[0-9０-９%％]');

List<String> _labels(Game g) =>
    adultFocusOptions(g).map((o) => o.label).toList();

String _home(Game g) =>
    (g.fa[g.l.home]?.alive ?? false) ? g.l.home : g.alive.first.name;

/// 元服を済ませた男（女なら [female]）の Game。年の初めの問いが出ている。
Game _adult(int seed, {bool female = false}) {
  for (var s = seed; ; s++) {
    final rng = Rng(s + 12000);
    final b = rollBirth(rng);
    if (b.female != female) continue;
    final g = Game(rng: rng)..start(b);
    final r = Rng(s + 13000);
    var n = 0;
    while (!g.finished && n++ < 400 && !(g.atYearStart && g.age >= 18)) {
      g.choose(r.range(0, g.prompt!.choices.length - 1));
    }
    if (g.atYearStart && g.l.rank < 8) return g;
  }
}

void _serve(Game g, int rank) {
  g.l
    ..rank = rank
    ..maxRank = rank
    ..lord = _home(g)
    ..fav = 40
    ..troops = rank >= 5 ? 30 : 0;
  for (final f in ['priesthood', 'retired', 'way_merchant', 'way_outlaw']) {
    g.l.flags.remove(f);
  }
}

void _checkChoices(Prompt p) {
  for (final c in p.choices) {
    expect(c.hint, isNotNull, reason: '${p.title}: ${c.label}');
    expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
    expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
  }
}

void main() {
  test('場面は一度ずつ登録され、どれも心がけで選んだ年にだけ起きる', () {
    final g = Game(rng: Rng(1));
    for (final id in ['gk_plot', 'vz_visit', 'kg_offer']) {
      final s = g.adultScenes.where((s) => s.id == id).toList();
      expect(s.length, 1, reason: id);
      expect(s.first.onlyForced, isTrue);
      expect(s.first.repeat, isTrue);
    }
  });

  test('謀反の支度: 城主〜宿老で戦える人だけに出て、支度が積もるほど誘いが来やすく成功しやすい。露見は信頼で変わる', () {
    final g = _adult(0);
    _serve(g, 4);
    expect(_labels(g), isNot(contains('謀反の支度をする')));
    _serve(g, 5);
    expect(_labels(g), contains('謀反の支度をする'));
    _serve(g, 8);
    expect(_labels(g), isNot(contains('謀反の支度をする')));
    _serve(g, 6);
    g.setFlag('retired');
    expect(_labels(g), isNot(contains('謀反の支度をする')));
    g.l.flags.remove('retired');
    final w = _adult(0, female: true);
    _serve(w, 6);
    w.l.traits.remove('onna');
    expect(_labels(w), isNot(contains('謀反の支度をする')), reason: '戦えない女性');

    final p0 = g.betrayChance();
    final e0 = gkExposeChance(g);
    g.setFlag('gk_prep:3');
    expect(gkPrep(g), 3);
    expect(g.betrayChance(), greaterThan(p0));
    expect(gkInviteWeight(g), greaterThan(0));
    expect(gkExposeChance(g), greaterThan(e0));
    g.l.fav = 90;
    final hi = gkExposeChance(g);
    g.l.fav = 5;
    expect(gkExposeChance(g), greaterThan(hi), reason: '信頼が低いほど露見しやすい');
    gkClear(g);
    expect(gkPrep(g), 0);
  });

  /// 位5〜7に置いた男の人生。[prep] の見込みで「謀反の支度をする」を選び、ほかは考えて選ぶ。
  ({int lives, int daimyo, Map<String, int> scenes, int deaths, int rises, int won})
  plot(
    int n,
    double prep,
    int base,
  ) {
    var lives = 0, daimyo = 0, deaths = 0, rises = 0, won = 0;
    final scenes = <String, int>{};
    for (var s = 0; s < n; s++) {
      final g = _adult(base + s);
      _serve(g, 5 + s % 3);
      g.resaveYearStart();
      final r = Rng(base + s + 500);
      var k = 0;
      while (!g.finished && k++ < 4000) {
        final p = g.prompt!;
        if (const ['謀反の支度', '挙兵の時', '謀反の露見'].contains(p.title)) {
          scenes[p.title] = (scenes[p.title] ?? 0) + 1;
          _checkChoices(p);
        }
        var i = pickAmbitious(g, p, r);
        if (p.title == 'この年の心がけ') {
          final j = p.choices.indexWhere((c) => c.label == '謀反の支度をする');
          if (j >= 0 && r.chance(prep)) i = j;
        } else if (p.title == '下剋上の誘い' || p.title == '挙兵の時') {
          // 誘いにも、整った支度にも、半ばの見込みで兵を挙げる（どちらの遊び方でも同じ）。
          i = r.chance(.5) ? 0 : 1;
          if (i == 0) {
            rises++;
            g.choose(i);
            if (g.l.rank == 8) won++;
            continue;
          }
        } else if (p.title == '謀反の露見') {
          i = r.range(0, p.choices.length - 1);
        }
        g.choose(i);
      }
      lives++;
      if (g.l.maxRank >= 8) daimyo++;
      if (g.l.dead?.contains('謀反の企て') ?? false) deaths++;
    }
    return (
      lives: lives,
      daimyo: daimyo,
      scenes: scenes,
      deaths: deaths,
      rises: rises,
      won: won,
    );
  }

  test('謀反の支度を選ぶ人生で、支度・挙兵・露見の岐路が出て、大名に届く人が跳ね上がらない', () {
    final none = plot(400, 0, 0);
    final some = plot(400, .5, 0);
    // ignore: avoid_print
    print(
      '【謀反の支度】位5〜7の400人生 大名に届いた 選ばない${none.daimyo}・半ば選ぶ${some.daimyo}'
      '／兵を挙げた 選ばない${none.rises}（成った${none.won}）・半ば選ぶ${some.rises}（成った${some.won}）'
      '／岐路 ${some.scenes}・露見で亡くなった${some.deaths}',
    );
    for (final t in ['謀反の支度', '挙兵の時', '謀反の露見']) {
      expect(some.scenes[t] ?? 0, greaterThan(3), reason: t);
    }
    expect(some.daimyo, greaterThan(none.daimyo), reason: '支度は報われる');
    // 兵を挙げる機会は増えるが、一度の挙兵が成る見込みは、誘いに乗るときと大きく変わらない（半ばを越えない）。
    expect(some.won / some.rises, lessThan(.5), reason: '一度の挙兵が成る見込み');
    // 支度をしても、大名に届くのは四人に一人より少ない（露見と、敗れた挙兵の死がある）。
    expect(some.daimyo / some.lives, lessThan(.25), reason: '跳ね上がらない');
  });

  test('縁のある人を訪ねる: 伴侶・子・主君は候補にならず、年ごとに一人か二人。訪ねると絆が上がる', () {
    final g = _adult(3);
    g.l.people.clear();
    g.meet('伴侶', 'お松', 50);
    g.meet('主君', '殿', 50);
    expect(visitCandidates(g), isEmpty);
    expect(_labels(g).where((x) => x.endsWith('を訪ねる')), isEmpty);
    g.meet('幼なじみ', '太郎', 30);
    expect(visitPicks(g).map((p) => p.name), ['太郎']);
    g.meet('師', '和尚', 40);
    g.meet('好敵手', '次郎', 20);
    final picks = visitPicks(g);
    expect(picks.length, 2);
    expect(_labels(g), containsAll(picks.map((p) => '${p.name}を訪ねる')));
    // 乱数を使わずに決まる（同じ年なら同じ人）。
    expect(visitPicks(g).map((p) => p.name), picks.map((p) => p.name));

    g.resaveYearStart(); // 置き直した縁で、年の初めの問いを作り直す
    final who = picks.first;
    final i = g.prompt!.choices.indexWhere((c) => c.label == '${who.name}を訪ねる');
    expect(i, greaterThanOrEqualTo(0));
    final b0 = who.bond;
    g.choose(i);
    expect(g.l.people[who.role]!.bond, greaterThan(b0));
    expect(g.l.flags.any((f) => f.startsWith('vz_who:')), isFalse);
  });

  test('訪ねる人生で、短い岐路が出て、縁の物語の段の決まりは崩れず、訪ねた人の絆が深くなる', () {
    final kinds = <String, int>{};
    var visits = 0, lives = 0, bondHi = 0;
    for (var s = 0; s < 300; s++) {
      final g = _adult(s * 3 + 1000);
      if (g.l.people['幼なじみ'] == null) g.meet('幼なじみ', '与一', 30);
      if (g.l.people['師'] == null) g.meet('師', '宗円', 35);
      final r = Rng(s + 7700);
      var k = 0;
      final seenBond = <String>{};
      while (!g.finished && k++ < 4000) {
        final p = g.prompt!;
        if (const ['昔語り', '縁の人の頼み', '縁の人との諍い'].contains(p.title)) {
          kinds[p.title] = (kinds[p.title] ?? 0) + 1;
          _checkChoices(p);
        }
        // 縁の物語の段は、前の段の場面のあとにだけ出る。
        for (final f in g.l.flags.where((f) => f.startsWith('scene:bd_'))) {
          final id = f.substring(6);
          if (seenBond.add(id) && kBondPrev.containsKey(id)) {
            expect(g.hasFlag('scene:${kBondPrev[id]}'), isTrue, reason: id);
          }
        }
        var i = s.isEven
            ? pickAmbitious(g, p, r)
            : r.range(0, p.choices.length - 1);
        if (p.title == 'この年の心がけ') {
          final j = p.choices.indexWhere((c) => c.label.endsWith('を訪ねる'));
          if (j >= 0 && r.chance(.5)) {
            i = j;
            visits++;
          }
        }
        g.choose(i);
      }
      lives++;
      final o = g.l.people['幼なじみ'];
      if (o != null && o.bond >= 60) bondHi++;
    }
    // ignore: avoid_print
    print('【訪ねる】$lives人生・訪ねた$visits回・岐路 $kinds・幼なじみの絆が深い人生$bondHi');
    expect(visits, greaterThan(300));
    for (final t in ['昔語り', '縁の人の頼み', '縁の人との諍い']) {
      expect(kinds[t] ?? 0, greaterThan(5), reason: t);
    }
    expect(bondHi, greaterThan(20));
  });

  test('よその家に仕え直す道を探る: 主家に仕える位一〜七だけに出て、必ず岐路が起き、移ると主君と位が変わる', () {
    final g = _adult(5);
    _serve(g, 0);
    g.l.lord = null;
    expect(_labels(g), isNot(contains('よその家に仕え直す道を探る')));
    _serve(g, 8);
    expect(_labels(g), isNot(contains('よその家に仕え直す道を探る')));
    var moved = 0, stayed = 0, scolded = 0, down = 0, same = 0;
    for (var s = 0; s < 300; s++) {
      final x = _adult(s * 5 + 2000);
      final rank = 1 + s % 7;
      _serve(x, rank);
      x.resaveYearStart();
      final i = x.prompt!.choices.indexWhere((c) => c.label == 'よその家に仕え直す道を探る');
      if (i < 0) continue;
      final lord0 = x.l.lord;
      x.choose(i);
      final p = x.prompt!;
      expect(p.title, anyOf('仕え直す誘い', '奥替えの誘い'));
      expect(p.choices.length, 3);
      _checkChoices(p);
      final fav0 = x.l.fav;
      // 手の結果だけを見る（選んだあとに年が進むと、主家が滅んで降るなどで主君や位がまた変わりうる）。
      if (s.isEven) {
        final res = p.choices[0].f!()!;
        moved++;
        expect(x.l.lord, isNot(lord0));
        expect(x.l.rank, inInclusiveRange(rank - 1 < 1 ? 1 : rank - 1, rank));
        if (x.l.rank < rank) {
          down++;
        } else {
          same++;
        }
        expect(x.l.path.last, contains('仕え直した'));
        expect(res, contains('に移った'));
        expect(kgCan(x), isFalse, reason: '移った年から間をあける');
      } else {
        p.choices[2].f!();
        stayed++;
        expect(x.l.lord, lord0);
        if (x.l.fav < fav0) scolded++;
      }
    }
    // ignore: avoid_print
    print('【仕え直す】移った$moved（位が下がった$down・そのまま$same）・とどまった$stayed（咎め$scolded）');
    expect(moved, greaterThan(100));
    expect(down, greaterThan(0));
    expect(same, greaterThan(0));
    expect(scolded, greaterThan(5));
  });

  test('ふつうの人生を流しても例外がなく、新しい岐路の選択肢に匂わせがあり数字が無い', () {
    final seen = <String>{};
    for (var s = 0; s < 600; s++) {
      final rng = Rng(s + 51000);
      final g = Game(rng: rng)..start(rollBirth(rng));
      final r = Rng(s + 52000);
      var k = 0;
      while (!g.finished && k++ < 5000) {
        final p = g.prompt;
        expect(p, isNotNull);
        if (const [
          '謀反の支度',
          '挙兵の時',
          '謀反の露見',
          '昔語り',
          '縁の人の頼み',
          '縁の人との諍い',
          '仕え直す誘い',
          '奥替えの誘い',
        ].contains(p!.title)) {
          seen.add(p.title);
          _checkChoices(p);
        }
        if (p.title == 'この年の心がけ') {
          for (final c in p.choices) {
            expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
            expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
          }
        }
        g.choose(
          s.isEven ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1),
        );
      }
      expect(g.finished, isTrue);
    }
    // ignore: avoid_print
    print('【心がけの三つ】ふつうの600人生で出た岐路 $seen');
    expect(seen.length, greaterThanOrEqualTo(4));
  });
}
