import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

/// 回I（1.0.0+21）: 人の顔の絵。
/// ・割り当て（決まった名前 → 決まった顔・年代で替わる・古いセーブ・ゲームの乱数を使わない・同じ会社で重ならない）
/// ・画面（絵が出る・小さい印と読めない絵は1文字・読み上げない）
/// 目で見る用の書き出しは QUAD_SHOTS に書き出し先を渡したときだけ動く（画像はコミットしない）

/// 乱数を何回引いたかを数える
class _Counting implements math.Random {
  final math.Random inner;
  int n = 0;
  _Counting(this.inner);
  @override
  bool nextBool() {
    n++;
    return inner.nextBool();
  }

  @override
  double nextDouble() {
    n++;
    return inner.nextDouble();
  }

  @override
  int nextInt(int max) {
    n++;
    return inner.nextInt(max);
  }
}

final _grown = <String, String>{};

/// 育った会社（始めた国ごとに1度だけ作って使い回す）
Game _grownIn(String home) {
  final j = _grown[home] ??= jsonEncode(grownGame(home: home).toJson());
  return Game.fromJson(jsonDecode(j) as Map<String, dynamic>, rng: ParkMiller(5))..calcAll();
}

/// 顔の重なり（同じ顔を使っている人の組の数）
int _pairs(Iterable<String?> faces) {
  final n = <String, int>{};
  for (final f in faces) {
    if (f != null) n[f] = (n[f] ?? 0) + 1;
  }
  return n.values.fold(0, (a, c) => a + c * (c - 1) ~/ 2);
}

/// 保存した木から顔を消す（1.0.0+20 までのセーブの形にする）
Map<String, dynamic> _strip(Map<String, dynamic> j) {
  final t = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
  void bare(Map? m) => m
    ?..remove('face')
    ..remove('fb');
  bare(t['pres'] as Map);
  for (final k in ['staff', 'cands', 'kids']) {
    for (final p in t[k] as List) {
      bare(p as Map);
    }
  }
  bare(t['meet'] as Map?);
  for (final c in t['cos'] as List) {
    (c as Map)
      ..remove('pf')
      ..remove('pfn')
      ..remove('pfb');
  }
  return t;
}

/// 画面に出ている顔の絵を読み込ませる（テストでは絵の読み込みが本物の時間を要る）
Future<void> _loadFaces(WidgetTester tester) async {
  final els = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final e in els) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

void main() {
  group('顔の絵の素材', () {
    test('一覧の90枚がすべて assets/faces にあり、余りも無い。pubspec に登録してある', () {
      final files = Directory('assets/faces').listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
      expect(FACES.length, 90);
      expect(files, {for (final f in FACES) '${f.id}.png'});
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/faces/'));
      // どの地域・性別にも、若い・中年・老年の絵が1枚はある（東南アジアは東アジアと混ぜる）
      for (final r in ['ea', 'we', 'sa', 'af', 'la', 'me']) {
        for (final sx in ['m', 'f']) {
          for (var b = 0; b < 3; b++) {
            expect(FACES.any((f) => f.region == r && f.sex == sx && f.band == b), isTrue, reason: '$r $sx $b');
          }
        }
      }
      // 大きさ（アプリに足される分）: 2MB を超えない
      final bytes = Directory('assets/faces').listSync().whereType<File>().fold<int>(0, (a, f) => a + f.lengthSync());
      // ignore: avoid_print
      print('顔の絵の合計: $bytes バイト');
      expect(bytes, lessThan(2 * 1024 * 1024));
    });
  });

  group('性別と地域は名前から決まる', () {
    test('名の一覧のどの名も、男か女のどちらか一方に決まる', () {
      final all = <String>{...MEI, for (final e in NAMEP.values) ...e[1]};
      for (final g in all) {
        expect(femaleGiven.contains(g) != maleGiven.contains(g), isTrue, reason: g);
      }
      // 一覧の半分ずつ
      expect(MEI.where(femaleGiven.contains).length, 15);
      for (final e in NAMEP.entries) {
        expect(e.value[1].where(femaleGiven.contains).length, 5, reason: e.key);
      }
    });

    test('決まった名前は決まった性別', () {
      const want = {
        '佐藤 健一': 'm',
        '鈴木 陽子': 'f',
        '田中 さくら': 'f',
        'ジェームズ・スミス': 'm',
        'エミリー・ブラウン': 'f',
        '王 偉': 'm',
        '李 芳': 'f',
        'キム ミンジュン': 'm',
        'パク ソヨン': 'f',
        'アルジュン・シャルマ': 'm',
        'プリヤ・パテル': 'f',
        'チディ・アデイェミ': 'm',
        'アマカ・オコンクォ': 'f',
        'ムハンマド・アル＝ラシード': 'm',
        'ファーティマ・アル＝ハルビー': 'f',
        'カルロス・ガルシア': 'm',
        'ルシア・ロペス': 'f',
        // 宿敵
        '黒田 剛造': 'm',
        'マーカス・ヘイル': 'm',
        '西園寺 麗子': 'f',
        'アーニャ・ヴォルコワ': 'f',
        '李 天佑': 'm',
      };
      want.forEach((n, sx) => expect(faceSex(n), sx, reason: n));
      // 一覧に無い名は、名前のハッシュで決まる（何度呼んでも同じ）
      expect(faceSex('つるはし 太郎左衛門'), faceSex('つるはし 太郎左衛門'));
      expect(['m', 'f'], contains(faceSex('X Æ')));
    });

    test('決まった名前は決まった地域。24か国のどこから始めても地域が決まる', () {
      expect(faceRegion('佐藤 健一', home: 'jp'), 'ea');
      // 日本以外で始めても、日本の名の人は東アジア
      expect(faceRegion('佐藤 健一', home: 'us'), 'ea');
      expect(faceRegion('ジェームズ・スミス', home: 'us'), 'we');
      expect(faceRegion('アルジュン・シャルマ', home: 'in'), 'sa');
      expect(faceRegion('チディ・アデイェミ', home: 'ng'), 'af');
      expect(faceRegion('ムハンマド・アル＝ラシード', home: 'sa'), 'me');
      expect(faceRegion('カルロス・ガルシア', home: 'mx'), 'la');
      expect(faceRegion('カルロス・ガルシア', home: 'es'), 'we');
      expect(faceRegion('ジョアン・シルバ', home: 'br'), 'la');
      expect(faceRegion('ホセ・サントス', home: 'ph'), 'sea');
      expect(faceRegion('グエン ミン', home: 'vn'), 'sea');
      expect(faceRegion('王 偉', home: 'cn'), 'ea');
      // 宿敵（姓が一覧に無い）
      expect(faceRegion('黒田 剛造'), 'ea');
      expect(faceRegion('マーカス・ヘイル'), 'we');
      expect(faceRegion('アーニャ・ヴォルコワ'), 'we');
      // 自分で付けた名は、始めた国の地域
      expect(faceRegion('つるはし 太郎', home: 'ng'), 'af');
      for (final c in CTRY) {
        expect(NAMEC[c.c], isNotNull, reason: c.c);
        expect(poolRegion[NAMEC[c.c]], isNotNull, reason: c.c);
      }
      expect(CTRY.length, 24);
    });
  });

  group('顔を選ぶ', () {
    test('決まった名前・年齢 → 決まった顔（地域・性別・年代が合う）', () {
      for (final (n, age, home) in [('佐藤 健一', 25, 'jp'), ('鈴木 陽子', 44, 'jp'), ('エミリー・ブラウン', 61, 'us'), ('アルジュン・シャルマ', 38, 'in'), ('アマカ・オコンクォ', 29, 'ng')]) {
        final a = pickFace(name: n, age: age, region: faceRegion(n, home: home), sex: faceSex(n));
        final b = pickFace(name: n, age: age, region: faceRegion(n, home: home), sex: faceSex(n));
        expect(a, b);
        final f = faceById[a]!;
        expect(f.region, faceRegion(n, home: home), reason: n);
        expect(f.sex, faceSex(n), reason: n);
        expect((f.age - age).abs(), lessThanOrEqualTo(15), reason: n);
      }
      // 値そのものも固定（割り当て方を変えたら、ここが落ちて気づく）
      expect(pickFace(name: '佐藤 健一', age: 25, region: 'ea', sex: 'm'), pickFace(name: '佐藤 健一', age: 25, region: 'ea', sex: 'm', used: const {}));
      expect(nameHash('佐藤 健一'), nameHash('佐藤 健一'));
      expect(nameHash('佐藤 健一'), isNot(nameHash('佐藤 誠')));
    });

    test('使われている顔を避ける。同じ地域・性別・年代の絵が尽きるまでは重ならない', () {
      final used = <String, int>{};
      final got = <String>[];
      // 東アジアの男・30歳前後: 若い絵3枚＋近い年の中年の絵
      for (var i = 0; i < 4; i++) {
        final f = pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: used);
        used[f] = 1;
        got.add(f);
      }
      expect(got.toSet().length, 4);
      // 東南アジアは東アジアの絵も使う。東アジアが尽きたら東南アジアから借りる
      final sea = {for (var i = 0; i < 40; i++) pickFace(name: 'ホセ・サントス$i', age: 30, region: 'sea', sex: 'm')};
      expect(sea.any((f) => faceById[f]!.region == 'ea'), isTrue);
      expect(sea.any((f) => faceById[f]!.region == 'sea'), isTrue);
      final allEa = {for (final f in FACES.where((f) => f.region == 'ea')) f.id: 1};
      expect(faceById[pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: allEa)]!.region, 'sea');
      // 中南米は欧米から、中東は南アジアから借りる
      final allLa = {for (final f in FACES.where((f) => f.region == 'la')) f.id: 1};
      expect(faceById[pickFace(name: 'カルロス・ガルシア', age: 30, region: 'la', sex: 'm', used: allLa)]!.region, 'we');
      final allMe = {for (final f in FACES.where((f) => f.region == 'me')) f.id: 1};
      expect(faceById[pickFace(name: 'ムハンマド・アル＝ラシード', age: 30, region: 'me', sex: 'm', used: allMe)]!.region, 'sa');
      // 同じ地域・性別の絵の数までは、年齢が若いほうから老年まで散っていれば、どの順に来てもほぼ重ならない
      for (final (region, sex, n) in [('ea', 'm', 10), ('ea', 'f', 8), ('we', 'm', 10), ('sa', 'f', 8), ('af', 'm', 10)]) {
        final spread = List.generate(n, (i) => 26 + i * 40 ~/ (n - 1));
        for (final ages in [spread, spread.reversed.toList(), List.generate(n, (i) => 58 + i % 3).take(sex == 'm' ? 4 : 2).toList()]) {
          final n = ages.length;
          final u = <String, int>{};
          for (var i = 0; i < n; i++) {
            final f = pickFace(name: '人$i', age: ages[i], region: region, sex: sex, used: u);
            expect(faceById[f]!.sex, sex);
            u[f] = (u[f] ?? 0) + 1;
          }
          // 来た順に近い年の絵から埋めるので、終わりの1〜2人は、残った絵が年の離れすぎたもので重なることがある
          expect(u.length, greaterThanOrEqualTo(n - 2), reason: '$region $sex $ages $u');
          expect(u.values.every((c) => c <= 2), isTrue, reason: '$region $sex $ages $u');
        }
      }
      // 年の合う絵が尽きたら、年上20歳までの絵を借りる（同じ顔を重ねるより先）。それより離れた絵は使わず、重ねる
      final youngEa = {for (final f in FACES.where((f) => (f.region == 'ea' || f.region == 'sea') && f.sex == 'm' && f.age <= 43)) f.id: 1};
      final lent = faceById[pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: youngEa)]!;
      expect(lent.age, 45);
      final midEa = {for (final f in FACES.where((f) => (f.region == 'ea' || f.region == 'sea') && f.sex == 'm' && f.age <= 50)) f.id: 1};
      expect(faceById[pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: midEa)]!.age, lessThanOrEqualTo(43), reason: '55歳より上の絵は使わない');
      // 全部使われていたら、使われている数の少ないものを重ねる（年の離れた絵には逃げない）
      final allWe = {for (final f in FACES.where((f) => f.region == 'we')) f.id: 2};
      allWe['we_0'] = 1;
      expect(pickFace(name: 'ジェームズ・スミス', age: 26, region: 'we', sex: 'm', used: allWe), 'we_0');
    });

    test('年をとると年代の絵に替わる。替わるのは35歳と55歳の2回まで', () {
      for (final n in ['佐藤 健一', '鈴木 陽子', 'ジェームズ・スミス', 'プリヤ・パテル', 'チディ・アデイェミ', 'ファーティマ・アル＝ハルビー', 'ルシア・ロペス', 'ホセ・サントス']) {
        final region = faceRegion(n), sex = faceSex(n);
        String? cur;
        int? band;
        final changes = <int>[];
        for (var age = 22; age <= 80; age++) {
          if (faceStale(cur, band, age)) {
            final next = pickFace(name: n, age: age, region: region, sex: sex, prev: cur);
            if (cur != null && next != cur) changes.add(age);
            cur = next;
            band = ageBand(age);
          }
          // ほかに誰も使っていなければ、年代の合う絵になる
          expect(faceById[cur]!.band, ageBand(age), reason: '$n $age');
        }
        expect(changes, [35, 55], reason: n);
      }
      // 決めたときの年代より上の年代になったときだけ選び直す（年の離れた絵を借りた人も、替わり続けない）
      expect(faceStale('ea_1', 0, 34), isFalse);
      expect(faceStale('ea_1', 0, 35), isTrue);
      expect(faceStale('ea_1', 1, 54), isFalse);
      expect(faceStale('ea_1', 1, 55), isTrue);
      expect(faceStale('ea_0', 2, 90), isFalse);
      expect(faceStale(null, null, 30), isTrue);
      expect(faceStale('ea_0', null, 30), isTrue);
      expect(faceStale('zz_9', 0, 30), isTrue);
      // 同じ人が年をとった絵（0→1→2・3→4→5）が空いていれば、それに替わる
      expect(faceNext('ea_0'), 'ea_1');
      expect(faceNext('ea_1'), 'ea_2');
      expect(faceNext('ea2_3'), 'ea2_4');
      expect(faceNext('ea_2'), isNull);
      expect(faceNext('ea_6'), isNull);
      expect(pickFace(name: '佐藤 健一', age: 35, region: 'ea', sex: 'm', prev: 'ea_0'), 'ea_1');
      expect(pickFace(name: '佐藤 健一', age: 55, region: 'ea', sex: 'm', prev: 'ea_1'), 'ea_2');
      // 続きの絵がほかの人に使われていたら、別の絵
      expect(pickFace(name: '佐藤 健一', age: 35, region: 'ea', sex: 'm', prev: 'ea_0', used: const {'ea_1': 1}), isNot('ea_1'));
    });
  });

  group('ゲームの中の割り当て', () {
    test('始めたとき、社長・候補・宿敵に顔が付く。月が変わっても変わらない', () {
      final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'careful']), rng: ParkMiller(11));
      expect(s.pres.face, isNotNull);
      expect(s.cands.every((p) => p.face != null), isTrue);
      final rivals = s.cos.where((c) => c.rival != null).toList();
      expect(rivals, isNotEmpty);
      expect(rivals.every((c) => c.pf != null && c.pfn == c.presName), isTrue);
      expect(_pairs([s.pres.face, ...rivals.map((c) => c.pf)]), 0, reason: '宿敵どうし・社長と重ならない');
      final before = {s.pres.name: s.pres.face, for (final c in rivals) c.presName: c.pf};
      for (var i = 0; i < 11; i++) {
        botMonth(s);
      }
      final after = {s.pres.name: s.pres.face, for (final c in s.cos.where((c) => c.rival != null && before.containsKey(c.presName))) c.presName: c.pf};
      for (final e in after.entries) {
        // 1年目のうちは、年代をまたぐ人はいない（社長22歳。宿敵は月ごとに年をとるので、またいだ人だけは替わってよい）
        final c = s.cos.where((x) => x.presName == e.key).firstOrNull;
        if (c != null && ageBand(c.presAge) != ageBand(c.presAge - 1)) continue;
        expect(e.value, before[e.key], reason: e.key);
      }
    });

    test('顔の割り当てはゲームの乱数を1度も引かない', () {
      final rng = _Counting(ParkMiller(2024));
      final s = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: ['charm', 'careful']), rng: rng);
      for (var i = 0; i < 60; i++) {
        botMonth(s);
      }
      final n = rng.n;
      // 顔を全部消して割り当て直す
      s.pres.face = null;
      for (final p in [...s.staff, ...s.cands, ...s.kids]) {
        p.face = null;
      }
      for (final c in s.cos) {
        c.pf = null;
        c.pfn = null;
      }
      s.ensureFaces();
      for (final p in s.staff) {
        s.faceOf(p);
      }
      for (final c in s.cos) {
        s.coFace(c);
      }
      expect(s.presFace, isNotNull);
      expect(rng.n, n);
      // 顔を何度割り当て直しても、その先の進み方は同じ（同じ種の別のゲームと数字が一致する）
      final t = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: ['charm', 'careful']), rng: ParkMiller(2024));
      for (var i = 0; i < 60; i++) {
        botMonth(t);
      }
      for (var i = 0; i < 12; i++) {
        botMonth(s);
        s.ensureFaces();
        botMonth(t);
      }
      expect(row(s), row(t));
      // 顔のほかは、保存の中身まで同じ（顔そのものは、来た順に決めたものと、あとから一度に決めたものとで違ってよい）
      expect(jsonEncode(_strip(s.toJson())) == jsonEncode(_strip(t.toJson())), isTrue, reason: '顔のほかの中身が変わった');
    });

    test('古いセーブ（顔が無い）は、読み込んだときに割り当てる。読み直しても同じ・保存した顔はそのまま', () {
      final g = _grownIn('jp');
      final old = _strip(g.toJson());
      expect(jsonEncode(old), isNot(contains('"face"')));
      final a = Game.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>, rng: ParkMiller(1));
      final b = Game.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>, rng: ParkMiller(99));
      expect(a.pres.face, isNotNull);
      expect(a.staff.every((p) => p.face != null && faceById.containsKey(p.face)), isTrue);
      expect(a.cos.where((c) => c.rival != null && c.alive).every((c) => c.pf != null), isTrue);
      expect([for (final p in a.staff) p.face], [for (final p in b.staff) p.face], reason: '乱数によらない');
      expect(a.pres.face, b.pres.face);
      // 1度割り当てたものは、保存して読み直してもそのまま
      final again = Game.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>, rng: ParkMiller(7));
      expect(jsonEncode(again.toJson()), jsonEncode(a.toJson()));
      // 素材から消えた絵を指していたら、割り当て直す
      final j = a.toJson();
      ((j['staff'] as List).first as Map)['face'] = 'zz_9';
      final fixed = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(7));
      expect(faceById.containsKey(fixed.staff.first.face), isTrue);
    });

    test('育った会社：どの国から始めても、部下の顔は地域・性別・年代が合い、ほとんど重ならない', () {
      for (final home in ['jp', 'us', 'in', 'ng']) {
        final g = _grownIn(home);
        final staff = g.staff;
        expect(staff.length, greaterThanOrEqualTo(6), reason: home);
        final detail = <String>[];
        var far = 0;
        for (final p in staff) {
          final f = faceById[p.face]!;
          expect(f.sex, faceSex(p.name), reason: '$home ${p.name}');
          if ((f.age - p.age).abs() > 25 && !(f.band == 2 && ageBand(p.age) == 2)) far++;
          detail.add('${p.age}${faceSex(p.name)}→${f.id}(${f.age})');
        }
        final pairs = _pairs([g.pres.face, ...staff.map((p) => p.face)]);
        // 重なってよいのは、その地域・性別の絵が足りない分だけ
        final need = <String, int>{};
        for (final p in staff) {
          final k = '${faceRegion(p.name, home: g.home)}/${faceSex(p.name)}';
          need[k] = (need[k] ?? 0) + 1;
        }
        final regions = {for (final p in staff) faceRegion(p.name, home: g.home)};
        final rivals = g.cos.where((c) => c.rival != null && c.alive).toList();
        // ignore: avoid_print
        print('顔の重なり $home: 社長＋部下${staff.length}人で $pairs 組（地域 $regions・地域/性別ごとの人数 $need）・宿敵${rivals.length}社で ${_pairs(rivals.map((c) => c.pf))} 組・年が25歳より離れた絵 $far 人\n  ${detail.join(' ')}');
        expect(_pairs(rivals.map((c) => c.pf)), 0, reason: home);
        final over = need.entries.fold<int>(0, (a, e) {
          final r = e.key.split('/');
          final have = FACES.where((f) => f.region == r[0] && f.sex == r[1]).length;
          return a + (e.value > have ? e.value - have : 0);
        });
        // 絵が足りない分（人数 − 絵の数）の2倍＋年の片寄りの分までに収まる
        expect(pairs, lessThanOrEqualTo(over * 2 + 4), reason: '$home: 重なりが多い');
      }
    });

    test('社長が替わると、後継ぎの顔が社長の顔になる。宿敵の代替わりでは顔が替わる', () {
      final g = _grownIn('jp');
      final p = g.staff.first;
      final f = p.face;
      g.takeOver(p);
      expect(g.pres.face, f);
      final c = g.cos.firstWhere((c) => c.rival != null && c.alive);
      c.presName = g.heirName(c.presName, c.rival!.k);
      c.presAge = 34;
      g.ensureFaces();
      expect(c.pfn, c.presName);
      expect(faceById[c.pf]!.sex, faceSex(c.presName));
      expect(c.pfb, 0);
    });

    test('子どもは16歳から顔が付く', () {
      final g = _grownIn('jp');
      final k = g.mkPerson(0)
        ..age = 3
        ..kid = true
        ..name = g.kidName(g.pres.name);
      g.kids.add(k);
      g.ensureFaces();
      expect(k.face, isNull);
      expect(g.faceOf(k), isNull);
      k.age = 16;
      g.ensureFaces();
      expect(k.face, isNotNull);
      expect(faceById[k.face]!.band, 0);
    });
  });

  group('画面', () {
    testWidgets('絵のある顔は絵を出し、読み上げない。小さい印・絵の無い顔は1文字のまま', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Column(children: [
        Face('佐藤 健一', img: 'ea_0', key: ValueKey('a')),
        Face('佐藤 健一', img: 'ea_0', size: 20, key: ValueKey('small')),
        Face('佐藤 健一', key: ValueKey('none')),
        Face.rival('黒田 剛造', '#9fb3ff', img: 'ea_8', size: 56, key: ValueKey('rival')),
        Face.pres('佐藤 健一', img: 'ea_0', size: 56, key: ValueKey('pres')),
      ])));
      Finder img(String k) => find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Image));
      expect(img('a'), findsOneWidget);
      expect(img('small'), findsNothing, reason: '24pt 以下は1文字');
      expect(img('none'), findsNothing);
      expect(img('rival'), findsOneWidget);
      expect(img('pres'), findsOneWidget);
      expect(tester.widget<Image>(img('a')).excludeFromSemantics, isTrue);
      expect((tester.widget<Image>(img('a')).image as AssetImage).assetName, 'assets/faces/ea_0.png');
      // 形と縁: 宿敵は四角で縁は宿敵の色、社長は金の輪
      BoxDecoration deco(String k) =>
          tester.widget<Container>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Container)).first).decoration as BoxDecoration;
      expect(deco('rival').shape, BoxShape.rectangle);
      expect(deco('rival').color, rivalInk('#9fb3ff'));
      expect(deco('pres').border, isNotNull);
      expect(deco('a').shape, BoxShape.circle);
      expect(tester.getSize(find.byKey(const ValueKey('rival'))), const Size(56, 56));
      // 絵の下に1文字が残っている（絵が出るまで・読めなかったときに見える）
      expect(find.descendant(of: find.byKey(const ValueKey('a')), matching: find.text('佐')), findsOneWidget);
      // 読み上げには出ない
      final h = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('佐')), findsNothing);
      h.dispose();
    });

    testWidgets('読めない絵を指していても倒れず、1文字の丸が見える', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Center(child: Face('佐藤 健一', img: 'no_such_face'))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('佐'), findsOneWidget);
    });

    testWidgets('人タブ・街の宿敵・会議で、顔の絵が出る（日本語・英語）', (tester) async {
      for (final lang in const ['ja', 'en']) {
        final g = _grownIn('jp');
        final p = await Pilot.launch(tester, lang: lang, game: g);
        final rv = g.cos.where((c) => c.rival != null && c.alive).first;
        await p.reveal(find.byKey(ValueKey('rival-row-${rv.id}')));
        final rf = tester.widget<Face>(find.descendant(of: find.byKey(ValueKey('rival-row-${rv.id}')), matching: find.byType(Face)));
        expect(rf.img, rv.pf);
        expect(rf.rival, isTrue);
        await p.tab('people');
        final pf = tester.widget<Face>(find.byWidgetPredicate((w) => w is Face && w.ring && w.col == '#f2c14e').first);
        expect(pf.img, g.pres.face);
        expect(pf.size, faceBig);
        await p.reveal(find.byKey(const ValueKey('face-legend')));
        final legend = find.descendant(of: find.byKey(const ValueKey('face-legend')), matching: find.byType(RichText));
        expect(tester.widget<RichText>(legend.first).text.toPlainText(), contains(tr('顔の縁の色はいちばん高い能力')));
        final s0 = g.staff.first;
        await p.reveal(find.byKey(ValueKey('staff-row-${s0.id}')));
        final sf = tester.widget<Face>(find.descendant(of: find.byKey(ValueKey('staff-row-${s0.id}')), matching: find.byType(Face)));
        expect(sf.img, s0.face);
        expect(sf.col, abFaceCols[topAbility(g, s0)]);
        // 会議: 話す部下・相棒の吹き出しに、その人の顔
        g.listed = true;
        final e = g.crisisMeeting('scandal', foe: rv, near: 20)!;
        g.events
          ..clear()
          ..add(e);
        nextEvent(p.ctl);
        await tester.pump();
        for (final v in e.voices.where((v) => v.name != null)) {
          final who = g.staff.firstWhere((x) => x.name == v.name);
          expect(find.byWidgetPredicate((w) => w is Face && w.name == v.name && w.img == who.face), findsWidgets, reason: v.name);
        }
        p.ctl.closeSheet();
        await tester.pump();
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      }
    });
  });

  // 目で見る用の書き出し（QUAD_SHOTS があるときだけ）
  group('書き出し', () {
    for (final home in const ['jp', 'us', 'in', 'ng']) {
      for (final w in const [390.0, 320.0]) {
        for (final lang in const ['ja', 'en']) {
          testWidgets('顔の絵：$home・幅${w.round()}・$lang', (tester) async {
            await loadRealFonts();
            final key = GlobalKey();
            final g = _grownIn(home);
            if (g.staff.length >= 3) g.staff[2].partner = true;
            final p = await Pilot.launch(tester, lang: lang, size: Size(w, 844), game: g, boundary: key);
            final tag = 'i_${home}_${w.round()}_$lang';
            Future<void> snap(String name) async {
              await _loadFaces(tester);
              await shot(tester, key, '${tag}_$name');
            }

            await p.tab('people');
            await snap('people_top');
            await p.reveal(find.byKey(const ValueKey('face-legend')));
            await snap('people_staff');
            final s0 = g.staff[g.staff.length > 4 ? 4 : 0];
            if (g.staff.length >= staffFoldMin) {
              await p.reveal(find.byKey(ValueKey('staff-row-${s0.id}')));
              await p.pressKey('staff-row-${s0.id}');
              await snap('people_card');
            }
            await p.reveal(find.text(tr('採用の候補')));
            await snap('people_cands');
            // 会議（部下・相棒・株主・銀行が話す）
            final rv = g.cos.where((c) => c.rival != null && c.alive).first;
            g.listed = true;
            g.sh = Shares(own: 40, pt: 5, float: 37, riv: {rv.id: 18});
            for (final kind in ['takeover', 'scandal']) {
              final e = g.crisisMeeting(kind, foe: rv, near: 20);
              if (e == null) continue;
              g.events
                ..clear()
                ..add(e);
              nextEvent(p.ctl);
              await tester.pump();
              await snap('meeting_$kind');
              p.ctl.closeSheet();
              await tester.pump();
            }
            // 宿敵の場面と、街の宿敵の一覧
            g.events
              ..clear()
              ..add(g.evAlliance(rv));
            nextEvent(p.ctl);
            await tester.pump();
            await snap('rival_scene');
            p.ctl.closeSheet();
            await tester.pump();
            await p.tab('town');
            await p.reveal(find.byKey(ValueKey('rival-row-${rv.id}')));
            await snap('town_rivals');
            await p.pressKey('rival-row-${rv.id}');
            await snap('town_rival_open');
            expect(tester.takeException(), isNull);
          }, skip: shotDir == null, timeout: const Timeout(Duration(minutes: 10)));
        }
      }
    }
  });
}
