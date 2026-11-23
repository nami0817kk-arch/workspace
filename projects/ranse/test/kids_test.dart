import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/family.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 子の名と性別（2026-11-24）。子ごとの記録（`Life.children`）を持ち、場面はその歳・性別に合う
/// 実在の子を選んで、その名で語る。縁の役割（嫡男・娘・子 など）は子の記録と同じ名を指す。

/// 息子がいるときだけ出る場面。
const _sonScenes = {
  'fa_genpuku',
  'fa_uijin',
  'fa_kokorozashi',
  'fa_yome',
  'fa_hoto',
  'fa_shuppon',
  'fa_atome',
  'fa_hitojichi',
  'l_heir_edu',
  'l_successor',
  'cl_atotori',
  'cl_yome',
  'dm_w_genpuku',
  'ok_kyoiku',
  'regent',
};

/// 娘がいるときだけ出る場面。
const _daughterScenes = {
  'fa_mogi',
  'w_daughter',
  'l_daughter',
  'wl_daughter_service',
};

Game _born(int seed) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(rollBirth(rng));
  return g;
}

/// 元服・裳着まで生きた人生（大人の最初の「今年の重点」が出ているところ）。
Game? _adult(int seed) {
  final g = _born(seed);
  final r = Rng(seed + 5);
  var n = 0;
  while (!g.finished && g.age < 15 && n++ < 400) {
    final p = g.prompt;
    if (p == null) return null;
    g.choose(r.range(0, p.choices.length - 1));
  }
  n = 0;
  while (!g.finished && g.prompt?.title != '今年の重点' && n++ < 20) {
    g.choose(0);
  }
  return g.finished || g.prompt?.title != '今年の重点' ? null : g;
}

/// [seed] から先で、最初に大人になれた人生。
Game _firstAdult(int seed) {
  for (var s = seed; ; s++) {
    final g = _adult(s);
    if (g != null) return g;
  }
}

/// 子の記録と数・縁の役割が食い違っていないこと。
void _consistent(Game g, String where) {
  final l = g.l;
  final alive = l.children.where((k) => k.alive).toList();
  expect(l.kids, alive.length, reason: '$where: 子の数と生きている子の記録');
  expect(
    l.kidsHome,
    l.children.where((k) => k.fate == KidFate.home).length,
    reason: '$where: 家にいる子の数',
  );
  expect(l.kidsHome, lessThanOrEqualTo(l.kids), reason: where);
  expect(
    l.kidYears.length,
    alive.where((k) => k.born != null).length,
    reason: '$where: 年の一覧',
  );
  // 生きている子の名は重ならない（役割が指す子が一人に決まる）。
  expect(
    alive.map((k) => k.name).toSet().length,
    alive.length,
    reason: '$where: 子の名の重なり ${alive.map((k) => k.name)}',
  );
  // 縁の役割の名は、生きている子の記録の名と一致する。
  for (final r in kKidRoles) {
    final p = l.people[r];
    if (p == null) continue;
    final k = alive.where((x) => x.name == p.name).toList();
    expect(k, isNotEmpty, reason: '$where: 役割「$r」の${p.name}に当たる子の記録がない');
    if (r == '嫡男') expect(k.first.female, isFalse, reason: '$where: 嫡男が娘');
    if (r == '娘' || r == '奉公に出た娘') {
      expect(k.first.female, isTrue, reason: '$where: $r が息子');
    }
    // 家を出た役割の子は、家にいない。
    if (const ['人質に出した子', '人質の子', '勘当した子', '出奔した子', '寺に入った子'].contains(r)) {
      expect(k.first.home, isFalse, reason: '$where: $r なのに家にいる');
    }
  }
  // 亡くなった子に歳より先の没年はない。
  for (final k in l.children.where((k) => !k.alive)) {
    if (k.born != null && k.endYear != null) {
      expect(k.endYear!, greaterThanOrEqualTo(k.born!), reason: where);
    }
  }
}

void main() {
  group('子の記録', () {
    test('保存の往復で、子の名・性別・生まれた年・行き先が残る', () {
      final g = _firstAdult(4242);
      final l = g.l;
      l.kids = 0;
      final a = l.addKid(1550);
      final b = l.addKid(1553, female: true);
      final c = l.addKid(1556, female: false, name: '藤助');
      l.kidLeft(b, KidFate.wed, 1570);
      l.kidDied(c, 1560);
      a.rename('源太');
      final back = Life.fromJson(
        jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>,
      );
      expect(back.children.length, 3);
      expect(back.kids, 2);
      expect(back.kidsHome, 1);
      expect(
        jsonEncode(back.children.map((k) => k.toJson()).toList()),
        jsonEncode(l.children.map((k) => k.toJson()).toList()),
      );
      expect(back.children[0].name, '源太');
      expect(back.children[0].childName, a.childName);
      expect(back.children[1].fate, KidFate.wed);
      expect(back.children[2].alive, isFalse);
      expect(back.children[2].ageAt(1600), 4);
      expect(back.kidYears, [1550, 1553]);
    });

    test('古い保存（子の数と生まれた年だけ）を読める。足りない分は名と生年から決まる', () {
      final g = _firstAdult(4243);
      final l = g.l;
      l.kids = 0;
      l.people.removeWhere((r, _) => kKidRoles.contains(r));
      final m = jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>;
      m.remove('children');
      m['kids'] = 4;
      m['kidYears'] = [1550, 1553, 1556];
      (m['people'] as List)
        ..add({'r': '嫡男', 'n': '太郎', 'b': 60})
        ..add({'r': '娘', 'n': 'お梅', 'b': 70})
        ..add({'r': '寺に入った子', 'n': '次郎', 'b': 50});
      final s = jsonEncode(m);
      final old = Life.fromJson(jsonDecode(s) as Map<String, dynamic>);
      expect(old.kids, 4);
      expect(old.children.length, 4);
      expect(old.kidYears, [1550, 1553, 1556]);
      expect(old.kidAgeUnknown, isTrue);
      // 縁の役割に名のある子は、その名と性別・行き先で。
      expect(old.kidNamed('太郎')!.female, isFalse);
      expect(old.kidNamed('お梅')!.female, isTrue);
      expect(old.kidNamed('次郎')!.fate, KidFate.temple);
      expect(old.kidsHome, 3);
      // 名は重ならず、空でない。
      expect(old.children.map((k) => k.name).toSet().length, 4);
      expect(old.children.every((k) => k.name.isNotEmpty), isTrue);
      // もう一度読んでも同じ子になる（乱数を使わない）。
      final again = Life.fromJson(jsonDecode(s) as Map<String, dynamic>);
      expect(
        jsonEncode(again.children.map((k) => k.toJson()).toList()),
        jsonEncode(old.children.map((k) => k.toJson()).toList()),
      );
      // 子の数より多い役割（亡くした子を指したまま残っていたもの）は外れる。
      m['kids'] = 1;
      m['kidYears'] = [1550];
      final few = Life.fromJson(
        jsonDecode(jsonEncode(m)) as Map<String, dynamic>,
      );
      expect(few.kids, 1);
      expect(few.people.containsKey('嫡男'), isTrue);
      expect(few.people.containsKey('娘'), isFalse);
      expect(few.people.containsKey('寺に入った子'), isFalse);
      // 年の一覧も無いもっと古い保存。
      m
        ..remove('kidYears')
        ..['kids'] = 2;
      final older = Life.fromJson(
        jsonDecode(jsonEncode(m)) as Map<String, dynamic>,
      );
      expect(older.kids, 2);
      expect(older.kidYears, isEmpty);
      expect(older.hasKidAged(1565, 12, 16), isTrue);
    });

    test('子を亡くすと、その子を指す縁の役割も外れる。数だけ入れた子にも名と性別が付く', () {
      final g = _firstAdult(4244);
      final l = g.l;
      l.kids = 0;
      final son = l.addKid(g.year - 14, female: false);
      final girl = l.addKid(g.year - 3, female: true);
      g.meet('嫡男', son.name, 60);
      g.meet('娘', girl.name, 60);
      // 三つの子を病で亡くす。
      final lost = l.loseKid(g.year, 0, 10);
      expect(lost, same(girl));
      expect(l.kids, 1);
      expect(l.people.containsKey('娘'), isFalse);
      expect(l.people.containsKey('嫡男'), isTrue);
      l.kidDied(son, g.year);
      expect(l.kids, 0);
      expect(l.people.containsKey('嫡男'), isFalse);
      expect(l.children.length, 2);
      // 数だけ入れた子（年の分からない子）は、男の子と女の子が交互。
      l.kids = 2;
      final unknown = l.children.where((k) => k.alive).toList();
      expect(unknown.length, 2);
      expect(unknown.every((k) => k.born == null), isTrue);
      expect(unknown[0].female, isNot(unknown[1].female));
      // 役割の名が子の記録に無ければ、合う子の名をその名に改めて結ぶ。
      g.meet('嫡男', '太郎', 60);
      expect(l.kidOfRole('嫡男'), isNotNull);
      expect(l.kidOfRole('嫡男')!.female, isFalse);
      _consistent(g, '結び直し');
    });

    test('家族の欄: 連れ合いと子を一行ずつ。嫡男・長女などの呼び名、行き先、亡くなった子', () {
      final g = _firstAdult(4245);
      final l = g.l;
      l
        ..kids = 0
        ..married = true;
      l.people.removeWhere((r, _) => kKidRoles.contains(r));
      g.meet('伴侶', '中村家のお福', 60);
      final y = g.year;
      final s1 = l.addKid(y - 16, female: false, name: '太郎');
      final d1 = l.addKid(y - 14, female: true, name: 'お梅');
      final s2 = l.addKid(y - 10, female: false, name: '次郎');
      final d2 = l.addKid(y - 8, female: true, name: 'お松');
      g.meet('嫡男', s1.name, 60);
      l.kidLeft(d1, KidFate.wed, y);
      l.kidDied(s2, y - 5);
      final rows = l.familyRows(y);
      expect(rows.length, 5);
      expect(rows[0].$1, '連れ合い');
      expect(rows[0].$2, '中村家のお福');
      expect(rows[1], ('嫡男', '太郎・16歳', false));
      expect(rows[2], ('長女', 'お梅・14歳・嫁いだ', false));
      expect(rows[3], ('次男', '次郎（5歳で亡くなった）', true));
      expect(rows[4], ('次女', 'お松・8歳', false));
      expect(l.kidLabel(d2), '次女');
      // 養子。
      final a = l.addKid(y - 9, female: false, name: '五郎', adopted: true);
      expect(l.kidLabel(a), '養子');
      // 子も連れ合いもいなければ空。
      l
        ..kids = 0
        ..married = false;
      l.children.clear();
      l.people.remove('伴侶');
      expect(l.familyRows(y), isEmpty);
    });
  });

  group('子の場面', () {
    test('息子の場面は息子がいるときだけ、娘の場面は娘がいるときだけ条件が合う', () {
      final scenes = {for (final s in buildFamilyScenes()) s.id: s};
      var checked = 0;
      for (var seed = 0; seed < 60 && checked < 6; seed++) {
        final g = _adult(seed + 8800);
        if (g == null || g.l.female || g.hasFlag('priesthood')) continue;
        if (g.hasFlag('way_outlaw')) continue;
        checked++;
        final l = g.l;
        l
          ..rank = 3
          ..maxRank = 3
          ..lord = g.alive.first.name
          ..fav = 40
          ..married = true
          ..t = 40 * 2;
        g.meet('伴侶', '中村家のお福', 60);
        final y = g.year;
        void kidsOf(bool female, List<int> ages) {
          l.kids = 0;
          l.children.clear();
          l.people.removeWhere((r, _) => kKidRoles.contains(r));
          for (final a in ages) {
            l.addKid(y - a, female: female);
          }
        }

        // 娘だけの家: 元服・人質の供・嫁取り・跡目は出ない。裳着は出る。
        kidsOf(true, [16, 14]);
        expect(scenes['fa_genpuku']!.cond(g), isFalse, reason: '娘だけの家に元服');
        expect(scenes['fa_hitojichi']!.cond(g), isFalse);
        expect(scenes['fa_yome']!.cond(g), isFalse);
        expect(scenes['fa_atome']!.cond(g), isFalse);
        expect(scenes['fa_mogi']!.cond(g), isTrue, reason: '娘のいる家に裳着');
        // 息子だけの家: 裳着は出ない。元服は出る。
        kidsOf(false, [16, 14]);
        expect(scenes['fa_mogi']!.cond(g), isFalse, reason: '息子だけの家に裳着');
        expect(scenes['fa_genpuku']!.cond(g), isTrue);
        expect(scenes['fa_atome']!.cond(g), isTrue);
        expect(scenes['fa_yome']!.cond(g), isTrue);
        // 家を出た子は、場面に選ばれない。
        for (final k in l.children) {
          l.kidLeft(k, KidFate.away, y);
        }
        expect(scenes['fa_genpuku']!.cond(g), isFalse, reason: '家を出た子に元服');
        expect(l.kids, 2);
        expect(l.kidsHome, 0);
      }
      expect(checked, greaterThanOrEqualTo(3));
    });

    test(
      '三千人生を流して、どの時点でも子の数と子の記録が一致し、縁の役割の名が子の記録の名を指し、'
      '息子の場面は息子がいるときだけ・娘の場面は娘がいるときだけ出て、同じ子に元服と裳着の両方が起きない',
      () {
        final seen = <String, int>{};
        var checks = 0, withKids = 0, lostKids = 0, left = 0;
        for (var seed = 0; seed < 3000; seed++) {
          final Game g;
          // 三人に一人は、元服のあと連れ合いと幼い子を持たせる（子の場面が多く出る）。
          if (seed % 3 == 2) {
            final a = _adult(seed + 61000);
            if (a == null) continue;
            g = a;
            final l = g.l;
            if (!l.female &&
                seed % 2 == 0 &&
                !g.hasFlag('priesthood') &&
                !g.hasFlag('way_outlaw')) {
              l
                ..rank = 3 + seed % 4
                ..maxRank = l.rank
                ..lord = g.alive.first.name
                ..fav = 40;
            }
            l
              ..married = true
              ..t = 24 * 2;
            g.meet('伴侶', l.female ? '中村家の太郎' : '中村家のお福', 60);
            l
              ..addKid(g.year - 2)
              ..addKid(g.year)
              ..addKid(g.year);
          } else {
            g = _born(seed + 61000);
          }
          final r = Rng(seed + 9);
          final smart = seed % 2 == 0;
          final before = <String>{};
          // 元服した子・裳着を迎えた子（記録そのもの）。
          final genpuku = <Kid>{};
          final mogi = <Kid>{};
          var n = 0;
          while (!g.finished && n++ < 4000) {
            final p = g.prompt;
            expect(p, isNotNull);
            final l = g.l;
            _consistent(g, '種$seed ${g.age}歳 ${p!.title}');
            checks++;
            final now = l.flags.where((f) => f.startsWith('scene:')).toSet();
            for (final f in now.difference(before)) {
              final id = f.substring(6);
              final why =
                  '種$seed $id: 子 ${l.children.map((k) => '${k.name}(${k.female ? '女' : '男'}/${k.fate})')}';
              if (_sonScenes.contains(id)) {
                seen[id] = (seen[id] ?? 0) + 1;
                expect(
                  l.children.any((k) => k.alive && !k.female),
                  isTrue,
                  reason: why,
                );
              }
              if (_daughterScenes.contains(id)) {
                seen[id] = (seen[id] ?? 0) + 1;
                expect(
                  l.children.any((k) => k.alive && k.female),
                  isTrue,
                  reason: why,
                );
              }
              if (id == 'fa_genpuku') {
                final k = l.sonAged(g.year, 11, 17);
                expect(k, isNotNull, reason: why);
                genpuku.add(k!);
                // 問いの文は、その子の名で語る。
                expect(p.text, contains(k.name), reason: why);
              }
              if (id == 'fa_mogi') {
                final k = l.daughterAged(g.year, 11, 17);
                expect(k, isNotNull, reason: why);
                mogi.add(k!);
                expect(p.text, contains(k.name), reason: why);
              }
            }
            before.addAll(now);
            g.choose(
              smart
                  ? pickAmbitious(g, p, r)
                  : r.range(0, p.choices.length - 1),
            );
          }
          final l = g.l;
          expect(genpuku.intersection(mogi), isEmpty, reason: '種$seed');
          expect(genpuku.every((k) => !k.female), isTrue);
          expect(mogi.every((k) => k.female), isTrue);
          if (l.children.isNotEmpty) withKids++;
          lostKids += l.children.where((k) => !k.alive).length;
          left += l.children.where((k) => k.alive && !k.home).length;
          // 終わったあとも食い違わない（亡くなる年に子を亡くした人生など）。
          final alive = l.children.where((k) => k.alive).length;
          expect(l.kids, alive, reason: '種$seed 終わり');
          // 保存の往復でも同じ。
          if (seed % 50 == 0) {
            final back = Life.fromJson(
              jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>,
            );
            expect(back.kids, l.kids);
            expect(back.kidsHome, l.kidsHome);
            expect(back.familyRows(g.year), l.familyRows(g.year));
          }
        }
        // ignore: avoid_print
        print(
          '【子の記録】確かめた問い $checks・子のいた人生 $withKids・亡くした子 $lostKids・家を出た子 $left・'
          '出た子の場面 $seen',
        );
        expect(withKids, greaterThan(600));
        expect(lostKids, greaterThan(50));
        expect(left, greaterThan(20));
        // 息子の場面・娘の場面がどちらも出ている。
        expect(seen['fa_genpuku'] ?? 0, greaterThan(10));
        expect(seen['fa_mogi'] ?? 0, greaterThan(10));
        expect(
          seen.keys.where(_daughterScenes.contains).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          seen.keys.where(_sonScenes.contains).length,
          greaterThanOrEqualTo(6),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test('子の名は、兄弟姉妹・連れ合い・自分の名と重ならず、同じ種なら同じ名になる', () {
      for (var seed = 0; seed < 40; seed++) {
        final a = _adult(seed + 7700);
        final b = _adult(seed + 7700);
        if (a == null || b == null) continue;
        for (final g in [a, b]) {
          g.l.kids = 0;
          for (var i = 0; i < 6; i++) {
            g.l.addKid(g.year + i);
          }
        }
        final na = a.l.children.map((k) => '${k.name}/${k.female}').toList();
        final nb = b.l.children.map((k) => '${k.name}/${k.female}').toList();
        expect(na, nb);
        expect(a.l.children.map((k) => k.name).toSet().length, 6);
        for (final k in a.l.children) {
          final pool = k.female
              ? [...kGivenF, ...kHimeNames]
              : [...kGivenM, ...kHeirNames];
          expect(pool, contains(k.name));
        }
      }
    });
  });
}
