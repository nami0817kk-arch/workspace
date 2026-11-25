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
  final j = _grown[home] ??= () {
    final g = grownGame(home: home);
    // 1.1.0+26 から店などの数で伸びが遅くなり、国によっては部下を雇えるほどの利益が出ない。顔を見るために、候補と同じ作り方の部下を足す
    while (g.staff.length < 10) {
      g.staff.add(g.mkPerson(0));
    }
    g.ensureFaces();
    return jsonEncode(g.toJson());
  }();
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
  for (final k in ['staff', 'cands', 'kids', 'alumni']) {
    for (final p in (t[k] as List?) ?? const []) {
      bare(p as Map);
    }
  }
  bare(t['meet'] as Map?);
  // 1.1.0+30 から、社長の経歴（後を継いだ人の写し）も顔を持つ
  bare((t['life'] as Map?)?['bio'] as Map?);
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
    test('一覧の220枚がすべて assets/faces にあり、余りも無い。pubspec に登録してある', () {
      final files = Directory('assets/faces').listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
      expect(FACES.length, 220);
      expect(faceById.length, 220, reason: '同じ名前の絵が2つある');
      expect(files, {for (final f in FACES) '${f.id}.png'});
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/faces/'));
      // 外した絵（実在のブランドの印・実在の人物に似る・崩れた絵）は入れない
      for (final id in ['la3_0', 'af3_8', 'saf_0', 'sam_7', 'saf2_6']) {
        expect(faceById.containsKey(id), isFalse, reason: id);
      }
      // 1.0.0+24 で足した絵のうち、見た目に合わせて札を直したもの
      expect((faceById['me4_0']!.region, faceById['me4_0']!.sex), ('af', 'f'));
      expect(faceById['mix4_6']!.region, 'sa');
      expect(faceById['saf2_3']!.age, lessThan(45), reason: '白髪の無い30代後半');
      expect(faceById['sam_3']!.age, greaterThanOrEqualTo(50));
      // 年齢の違う別の人の並びは、同じ人の続きにしない
      for (final id in ['saf_1', 'sam_0', 'saf2_0', 'mix4_0', 'la4_0', 'aff_0', 'me4_0']) {
        expect(faceNext(id), isNull, reason: id);
      }
      // 見た目が東アジアの we_4・we_5 は東アジア
      expect(faceById['we_4']!.region, 'ea');
      expect(faceById['we_5']!.region, 'ea');
      // 1.0.0+23 で見た目に合わせて直した絵（ea_8 は30代の東南アジアの男・sa_4/sa_5/sa_7 は東アジア・sa_2/ea2_8 は欧米）
      expect(faceById['ea_8']!.region, 'sea');
      expect(faceById['ea_8']!.age, lessThan(45));
      expect([for (final id in ['sa_4', 'sa_5', 'sa_7']) faceById[id]!.region], ['ea', 'ea', 'ea']);
      expect([for (final id in ['sa_2', 'ea2_8']) faceById[id]!.region], ['we', 'we']);
      for (final id in ['we_8', 'sa_8', 'mx_8']) {
        expect(faceById[id]!.age, lessThanOrEqualTo(45), reason: '$id は白髪の無い40歳前後');
      }
      // ほぼ同じ絵の組は、見た目では1つ（同じ地域・性別の絵どうし、または地域を直した絵）
      expect(faceLook('we_4'), 'ea_4');
      expect(faceLook('sa_5'), 'ea_5');
      expect(faceLook('ea2_8'), 'we2_8');
      expect(faceLook('ea_0'), 'ea_0');
      for (final f in FACES) {
        final l = faceById[faceLook(f.id)]!;
        expect(l.sex, f.sex, reason: f.id);
        expect(faceLook(l.id), l.id, reason: '代表は自分自身');
      }
      // 地域・性別ごとの枚数（1.0.0+24。1.0.0+23 は 17/22・21/15・9/5・15/11・9/7・8/7・8/6）
      int n(String r, String sx) => FACES.where((f) => f.region == r && f.sex == sx).length;
      expect([for (final r in ['ea', 'we', 'sa', 'af', 'me', 'la', 'sea']) '${n(r, 'm')}/${n(r, 'f')}'], ['17/22', '21/15', '21/21', '15/21', '13/11', '12/13', '9/9']);
      // どの地域・性別にも、若い（32歳まで）・中年（38〜52歳）・老年（60歳から）の絵が1枚はある
      for (final r in ['ea', 'we', 'sa', 'af', 'la', 'me', 'sea']) {
        for (final sx in ['m', 'f']) {
          for (final (lo, hi) in [(0, 32), (38, 52), (60, 99)]) {
            expect(FACES.any((f) => f.region == r && f.sex == sx && f.age >= lo && f.age <= hi), isTrue, reason: '$r $sx $lo-$hi');
          }
        }
      }
      // 大きさ（アプリに足される分）: 4MB を超えない（160枚で約2.5MB、220枚で約3.4MB）
      final bytes = Directory('assets/faces').listSync().whereType<File>().fold<int>(0, (a, f) => a + f.lengthSync());
      // ignore: avoid_print
      print('顔の絵の合計: $bytes バイト');
      expect(bytes, lessThan(4 * 1024 * 1024));
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
      // 東南アジアと東アジアは互いに借りない（1.0.0+23）。空きが無ければ自分の地域の中で重ねる
      final sea = {for (var i = 0; i < 40; i++) pickFace(name: 'ホセ・サントス$i', age: 30, region: 'sea', sex: 'm')};
      expect(sea.every((f) => faceById[f]!.region == 'sea'), isTrue, reason: '$sea');
      final allSea = {for (final f in FACES.where((f) => f.region == 'sea')) f.id: 1};
      expect(faceById[pickFace(name: 'ホセ・サントス', age: 30, region: 'sea', sex: 'm', used: allSea)]!.region, 'sea');
      final allEa = {for (final f in FACES.where((f) => f.region == 'ea')) faceLook(f.id): 1};
      for (final sx in ['m', 'f']) {
        for (var age = 16; age <= 90; age += 3) {
          final f = faceById[pickFace(name: '佐藤 健一$age', age: age, region: 'ea', sex: sx, used: allEa)]!;
          expect(f.region, 'ea', reason: '$sx $age ${f.id}');
          expect(faceFits(f.id, 'ea'), isTrue);
        }
      }
      expect(faceFits('sea3_1', 'ea'), isFalse);
      expect(faceFits('ea_1', 'sea'), isFalse);
      for (var i = 0; i < 40; i++) {
        final u = <String, int>{};
        for (var k = 0; k < 19; k++) {
          final f = pickFace(name: '佐藤 健一$i', age: 22 + (k * 3 + i) % 50, region: 'ea', sex: k.isEven ? 'm' : 'f', used: u);
          u[f] = (u[f] ?? 0) + 1;
        }
        expect(u.keys.every((f) => faceById[f]!.region == 'ea'), isTrue, reason: '東アジアの人19人なら東アジアの絵で足りる $u');
      }
      // 中南米は欧米から、中東は南アジアから借りる
      final allLa = {for (final f in FACES.where((f) => f.region == 'la')) f.id: 1};
      expect(faceById[pickFace(name: 'カルロス・ガルシア', age: 30, region: 'la', sex: 'm', used: allLa)]!.region, 'we');
      final allMe = {for (final f in FACES.where((f) => f.region == 'me')) f.id: 1};
      expect(faceById[pickFace(name: 'ムハンマド・アル＝ラシード', age: 30, region: 'me', sex: 'm', used: allMe)]!.region, 'sa');
      // 同じ地域・性別の絵の数までは、年齢が若いほうから老年まで散っていれば、どの順に来てもほぼ重ならない。年の差は必ず12歳まで
      for (final (region, sex, n) in [('ea', 'm', 10), ('ea', 'f', 8), ('we', 'm', 10), ('sa', 'f', 5), ('af', 'm', 10)]) {
        final spread = List.generate(n, (i) => 26 + i * 40 ~/ (n - 1));
        for (final ages in [spread, spread.reversed.toList(), List.generate(n, (i) => 58 + i % 3).take(sex == 'm' ? 4 : 2).toList()]) {
          final n = ages.length;
          final u = <String, int>{};
          for (var i = 0; i < n; i++) {
            final f = pickFace(name: '人$i', age: ages[i], region: region, sex: sex, used: u);
            expect(faceById[f]!.sex, sex);
            expect((faceById[f]!.age - ages[i]).abs(), lessThanOrEqualTo(faceGapMax), reason: '$region $sex ${ages[i]} $f');
            u[faceLook(f)] = (u[faceLook(f)] ?? 0) + 1;
          }
          expect(u.length, greaterThanOrEqualTo(n - 2), reason: '$region $sex $ages $u');
          expect(u.values.every((c) => c <= 2), isTrue, reason: '$region $sex $ages $u');
        }
      }
      // 年の合う絵が尽きたら、年の離れた絵に逃げずに、年の合う絵を重ねる（見た目の食い違いを重なりより重く見る）
      final youngEa = {for (final f in FACES.where((f) => f.region == 'ea' && f.sex == 'm' && f.age <= 43)) faceLook(f.id): 1};
      final lent = faceById[pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: youngEa)]!;
      expect(lent.region, 'ea');
      expect(lent.age, inInclusiveRange(16, 40));
      // 重ねるのは、同じ画面に並ぶ人（重い）より、ほかの人（軽い）の顔を先に
      final weighed = {for (final f in FACES.where((f) => f.region == 'ea' && f.sex == 'm')) faceLook(f.id): 2}..['ea2_0'] = 1;
      expect(pickFace(name: '佐藤 健一', age: 28, region: 'ea', sex: 'm', used: weighed), 'ea2_0');
      // 全部使われていたら、使われている数の少ないものを重ねる（年の離れた絵には逃げない）
      final allWe = {for (final f in FACES.where((f) => f.region == 'we')) f.id: 2};
      allWe['we_0'] = 1;
      expect(pickFace(name: 'ジェームズ・スミス', age: 26, region: 'we', sex: 'm', used: allWe), 'we_0');
    });

    test('本人と絵の年の差が12歳を超えたら、その時点で年の近い絵に替わる。替えたら少なくとも3年は保つ', () {
      for (final n in ['佐藤 健一', '鈴木 陽子', 'ジェームズ・スミス', 'プリヤ・パテル', 'アルジュン・シャルマ', 'チディ・アデイェミ', 'アマカ・オコンクォ', 'ファーティマ・アル＝ハルビー',
        'ムハンマド・アル＝ラシード', 'ルシア・ロペス', 'カルロス・ガルシア', 'ホセ・サントス', 'グエン ミン']) {
        for (final home in ['jp', 'us', 'in', 'ng', 'sa', 'mx', 'ph', 'vn']) {
          final region = faceRegion(n, home: home), sex = faceSex(n);
          String? cur;
          var since = 0;
          final changes = <int>[];
          for (var age = 16; age <= 95; age++) {
            if (faceStale(cur, age, region: region, sex: sex)) {
              final next = pickFace(name: n, age: age, region: region, sex: sex, prev: cur);
              if (cur != null && next != cur) {
                // 替えたら少なくとも3年は保つ（とても年をとって、使える絵が1枚しか無い年ごろは別）
                if (age - since < faceHoldYears) expect(faceGapLimit(region, sex, age), greaterThan(faceGapMax), reason: '$n $home $age $changes');
                changes.add(age);
              }
              cur = next;
              since = age;
            }
            final f = faceById[cur]!;
            // 年の差は12歳まで（その地域・性別に12歳より近い絵が1枚も無い年ごろだけ、いちばん近い絵まで）
            expect((f.age - age).abs(), lessThanOrEqualTo(faceGapLimit(region, sex, age)), reason: '$n $home $age ${f.id}');
            expect(f.sex, sex);
            expect(faceFits(f.id, region), isTrue);
          }
          // 一生（16〜95歳）で替わるのは数回
          expect(changes.length, inInclusiveRange(2, 8), reason: '$n $home $changes');
        }
      }
      // 選び直すのは、年の差が12歳を超えたとき・地域か性別が合わないとき・絵が無いとき
      expect(faceStale('ea_1', 57, region: 'ea', sex: 'm'), isFalse, reason: '45歳の絵と12歳差');
      expect(faceStale('ea_1', 58, region: 'ea', sex: 'm'), isTrue);
      expect(faceStale('ea_1', 33, region: 'ea', sex: 'm'), isFalse);
      expect(faceStale('ea_1', 32, region: 'ea', sex: 'm'), isTrue);
      expect(faceStale('ea_1', 45, region: 'ea', sex: 'f'), isTrue, reason: '性別が違う');
      expect(faceStale('ea_8', 38, region: 'ea', sex: 'm'), isTrue, reason: 'ea_8 は東南アジアの絵');
      expect(faceStale('sea3_1', 45, region: 'ea', sex: 'm'), isTrue, reason: '東アジアの人に東南アジアの絵');
      expect(faceStale(null, 30, region: 'ea', sex: 'm'), isTrue);
      expect(faceStale('zz_9', 30, region: 'ea', sex: 'm'), isTrue);
      // とても年をとった人で、12歳より近い絵が無いときは、いちばん近い絵まで許す（替わり続けない）
      expect(faceGapLimit('ea', 'm', 95), 15);
      expect(faceStale('eam_8', 95, region: 'ea', sex: 'm'), isFalse);
      // 1.0.0+24 で80歳の南アジアの女の絵が入ったので、90歳でも12歳まで
      expect(faceGapLimit('sa', 'f', 90), faceGapMax);
      expect(faceGapLimit('ea', 'm', 40), faceGapMax);
      // 同じ人が年をとった絵（0→1→2・3→4→5）が空いていれば、それに替わる
      expect(faceNext('ea_0'), 'ea_1');
      expect(faceNext('ea_1'), 'ea_2');
      expect(faceNext('ea2_3'), 'ea2_4');
      expect(faceNext('ea_2'), isNull);
      expect(faceNext('ea_6'), isNull);
      // 地域を直した絵・年齢の違う別の人の並びは、続きにしない
      expect(faceNext('we_3'), isNull);
      expect(faceNext('sa_1'), isNull, reason: 'sa_2 は欧米に直した');
      expect(faceNext('we_4'), 'we_5', reason: 'どちらも東アジアの同じ人');
      expect(faceNext('eam_0'), isNull);
      expect(faceNext('wef_3'), isNull);
      expect(faceNext('af3_0'), isNull);
      expect(faceNext('me3_0'), 'me3_1');
      expect(faceNext('sea3_3'), 'sea3_4');
      expect(faceNext('mx2_0'), isNull, reason: '女 → 男');
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
        // 1年目のうちは、社長（22歳）の顔は替わらない。宿敵は年の差が12歳を超えた人だけ替わってよい
        final c = s.cos.where((x) => x.presName == e.key).firstOrNull;
        if (c != null && (faceById[before[e.key]]!.age - c.presAge).abs() > faceGapMax) continue;
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

    test('1.0.0+22 のセーブ：年の差12歳超・東南アジアの絵の東アジアの人だけ、読み込んだときに選び直す。合っている顔はそのまま', () {
      final g = _grownIn('jp');
      final j = g.toJson();
      final staff = (j['staff'] as List).cast<Map<String, dynamic>>();
      final eaM = staff.where((p) => faceRegion(p['name'] as String, home: 'jp') == 'ea' && faceSex(p['name'] as String) == 'm').toList();
      expect(eaM.length, greaterThanOrEqualTo(3));
      // 1.0.0+22 で実際にあった形: 68歳の人に ea_8（30代の東南アジアの絵）・47歳の人に sea3_1・年代の古い印 fb=2
      eaM[0]
        ..['age'] = 68
        ..['face'] = 'ea_8'
        ..['fb'] = 2;
      eaM[1]
        ..['face'] = 'sea3_1'
        ..['fb'] = 1;
      eaM[2]['face'] = 'ea2_6';
      eaM[2]['age'] = 60;
      final keep = {
        for (final p in staff)
          if (!identical(p, eaM[0]) && !identical(p, eaM[1]) && !identical(p, eaM[2])) p['name'] as String: p['face'] as String?
      };
      final a = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(7));
      Person by(Map m) => a.staff.firstWhere((p) => p.name == m['name'] && p.age == m['age']);
      for (final m in eaM.take(3)) {
        final p = by(m);
        final f = faceById[p.face]!;
        expect(f.region, 'ea', reason: '${p.name} ${p.face}');
        expect((f.age - p.age).abs(), lessThanOrEqualTo(faceGapMax), reason: '${p.name} ${p.age} ${p.face}');
        expect(p.fb, p.age, reason: '選び直した年齢を記録する');
      }
      // 68歳の人には60代〜70代の東アジアの男の絵
      expect(faceById[by(eaM[0]).face]!.age, inInclusiveRange(56, 80));
      // 合っていた顔は、重なりを解くとき以外はそのまま（9割以上）
      final same = a.staff.where((p) => keep[p.name] == p.face).length;
      expect(same, greaterThanOrEqualTo((keep.length * .9).floor()), reason: '$same / ${keep.length}');
    });

    test('1.0.0+21 のセーブで欧米の人が we_4・we_5（東アジアに直した絵）を持っていたら、読み込んだときに選び直す', () {
      final g = _grownIn('us');
      final w = g.staff.firstWhere((p) => faceRegion(p.name, home: g.home) == 'we' && faceSex(p.name) == 'f');
      final e = g.staff.where((p) => faceRegion(p.name, home: g.home) == 'ea' && faceSex(p.name) == 'f').firstOrNull;
      final rv = g.cos.firstWhere((c) => c.rival != null && c.alive);
      final j = g.toJson();
      for (final p in j['staff'] as List) {
        if ((p as Map)['name'] == w.name) p['face'] = 'we_4';
        if (e != null && p['name'] == e.name) p['face'] = 'we_5';
      }
      for (final c in j['cos'] as List) {
        if ((c as Map)['id'] == rv.id) {
          c['presName'] = 'アーニャ・ヴォルコワ';
          c['pfn'] = 'アーニャ・ヴォルコワ';
          c['pf'] = 'we_5';
        }
      }
      final a = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, rng: ParkMiller(7));
      final w2 = a.staff.firstWhere((p) => p.name == w.name);
      expect(faceById[w2.face]!.region, 'we', reason: w2.face);
      // 東アジアの人が持っていた we_5 は、年が合えばそのまま（合わなければ東アジアの別の絵）
      if (e != null) {
        final e2 = a.staff.firstWhere((p) => p.name == e.name);
        if ((65 - e2.age).abs() <= faceGapMax) expect(e2.face, 'we_5');
        expect(faceById[e2.face]!.region, 'ea');
      }
      final rv2 = a.cos.firstWhere((c) => c.id == rv.id);
      expect(faceById[a.coFace(rv2)]!.region, 'we');
    });

    test('育った会社：どの国から始めても、社長と部下の顔は地域・性別が合い、年の差は12歳まで。重なりは絵の足りない分だけ', () {
      for (final home in ['jp', 'us', 'in', 'ng', 'mx', 'sa']) {
        final g = _grownIn(home);
        final staff = g.staff;
        expect(staff.length, greaterThanOrEqualTo(6), reason: home);
        final detail = <String>[];
        var far = 0, lent = 0;
        for (final (name, age, face) in [(g.pres.name, g.pres.age, g.pres.face), for (final p in staff) (p.name, p.age, p.face)]) {
          final f = faceById[face]!;
          final reg = faceRegion(name, home: g.home);
          expect(f.sex, faceSex(name), reason: '$home $name');
          expect(faceFits(f.id, reg), isTrue, reason: '$home $name ${f.id}');
          // 東アジアの人に東南アジアの絵は付かない（1.0.0+23）
          if (reg == 'ea') expect(f.region, 'ea', reason: '$home $name ${f.id}');
          // 年の差12歳超が残らない
          expect((f.age - age).abs(), lessThanOrEqualTo(faceGapMax), reason: '$home $name $age ${f.id}');
          if ((f.age - age).abs() > 12) far++;
          if (f.region != reg) lent++;
          detail.add('$age${faceSex(name)}→${f.id}(${f.age})');
        }
        // 古いセーブのような食い違いは、読み込みのときにも残らない（読み直しても同じ顔）
        final again = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(3));
        expect([for (final p in again.staff) p.face], [for (final p in staff) p.face], reason: home);
        // 重なりは見た目で数える（ほぼ同じ絵の組は1つ）
        final pairs = _pairs([g.pres.face, ...staff.map((p) => p.face)].map((f) => f == null ? null : faceLook(f)));
        // 重なってよいのは、その地域・性別の絵が足りない分だけ
        final need = <String, int>{};
        for (final p in staff) {
          final k = '${faceRegion(p.name, home: g.home)}/${faceSex(p.name)}';
          need[k] = (need[k] ?? 0) + 1;
        }
        final regions = {for (final p in staff) faceRegion(p.name, home: g.home)};
        final rivals = g.cos.where((c) => c.rival != null && c.alive).toList();
        // ignore: avoid_print
        print('顔の重なり $home: 社長＋部下${staff.length}人で $pairs 組（地域 $regions・地域/性別ごとの人数 $need）・宿敵${rivals.length}社で ${_pairs(rivals.map((c) => c.pf))} 組・年が12歳より離れた絵 $far 人・別地域の絵 $lent 人\n  ${detail.join(' ')}');
        expect(_pairs(rivals.map((c) => c.pf)), 0, reason: home);
        // 宿敵の顔も地域が合う（欧州の宿敵に東アジアの顔が付かない）。年の差も12歳まで
        for (final c in rivals) {
          expect(faceFits(c.pf, faceRegion(c.presName)), isTrue, reason: '$home ${c.presName} ${c.pf}');
          if (faceRegion(c.presName) == 'we') expect(faceById[c.pf]!.region, 'we', reason: '$home ${c.presName} ${c.pf}');
          expect((faceById[c.pf]!.age - c.presAge).abs(), lessThanOrEqualTo(faceGapMax), reason: '$home ${c.presName} ${c.presAge} ${c.pf}');
        }
        final over = need.entries.fold<int>(0, (a, e) {
          final r = e.key.split('/');
          final have = FACES.where((f) => f.region == r[0] && f.sex == r[1]).length;
          return a + (e.value > have ? e.value - have : 0);
        });
        // 絵が足りない分（人数 − 絵の数）の3倍＋年の片寄りの分までに収まる
        // （1.0.0+23 から、年の差12歳を超える絵より重ねるほうを選ぶ。1.0.0+23 のインド開始は南アジアの女の絵が5枚しか無く25組。
        // 1.0.0+24 で南アジアの絵を足して1組）
        expect(pairs, lessThanOrEqualTo(over * 3 + 4), reason: '$home: 重なりが多い');
        if (home == 'in') expect(pairs, lessThanOrEqualTo(3), reason: 'インド開始の重なり');
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
      expect(c.pfb, 34, reason: '顔を決めたときの年齢');
      expect((faceById[c.pf]!.age - 34).abs(), lessThanOrEqualTo(faceGapMax));
    });

    test('宿敵の代替わりのあと、場面の文に出る名前は今の社長（初代の名前が残らない）', () {
      final g = _grownIn('jp')..listed = true;
      final c = g.cos.firstWhere((c) => c.rival != null && c.alive);
      final first = c.presName;
      // 初代の名前（この盤面では、すでに1度代替わりしている宿敵もある）
      final founder = c.rival!.pres;
      // 代替わり（月の進みと同じ書き換え）
      String heir;
      var i = 0;
      do {
        heir = g.heirName(first, c.rival!.k);
      } while (heir == first && ++i < 20);
      c
        ..presName = heir
        ..presAge = 38;
      g.ensureFaces();
      expect(c.rival!.pres, founder, reason: '初代の名前は記録として残る');
      final texts = <String>[];
      void add(GameEvent? e) {
        if (e == null) return;
        texts.add(txIn(e.text, 'ja'));
        for (final ch in e.choices) {
          texts.add(txIn(ch.s, 'ja'));
        }
      }

      add(g.evAlliance(c));
      add(g.evPoach(c, g.staff.first));
      add(g.evHostile(c, 40));
      g.sh = Shares(own: 40, pt: 5, float: 37, riv: {c.id: 18});
      add(g.crisisMeeting('takeover', foe: c, near: 20));
      for (final k in sceneTitle.keys) {
        final s = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(5));
        final sc = s.cos.firstWhere((x) => x.id == c.id);
        sc.rival!.grudge = 3;
        add(s.rivalScene(sc, k));
      }
      // 決着の場面（社史・場面の文）
      g.events.clear();
      c.rival!.st = 1;
      g.storyEnd(c, 'peace');
      add(g.events.lastOrNull);
      expect(texts.length, greaterThan(8));
      final all = texts.join('\n');
      expect(all, contains(heir), reason: all);
      expect(all, isNot(contains(first)), reason: all);
      if (founder != heir) expect(all, isNot(contains(founder)), reason: all);
      // 選んだ結果の文も今の社長
      final pact = g.rivalScene(c, 'pact');
      if (pact != null) {
        for (final ch in pact.choices) {
          final s = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(5));
          final sc = s.cos.firstWhere((x) => x.id == c.id);
          final r = s.rivalScene(sc, 'pact')!.choices[pact.choices.indexOf(ch)].f();
          expect(txIn(r, 'ja'), isNot(contains(first)));
          if (founder != heir) expect(txIn(r, 'ja'), isNot(contains(founder)));
        }
      }
      // 顔の名札も今の社長
      expect(c.pfn, heir);
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
      // 若い東アジアの絵が会社の人で埋まっていれば、東南アジアから借りる前に年上20歳までの東アジアの絵を使う
      expect(faceById[k.face]!.age, lessThanOrEqualTo(16 + 20), reason: k.face);
      expect(faceById[k.face]!.region, faceRegion(k.name, home: g.home), reason: k.face);
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
        // 横向きの画面は低いので、社長のカードが見える所まで送る（1.1.0+25）
        // 1.1.0+27 から人の画面は2列（左の一覧の社長は小さな顔、右の社長の中身は大きな顔）
        expect(await p.reveal(find.byWidgetPredicate((w) => w is Face && w.ring && w.col == '#f2c14e' && w.size == faceBig)), isTrue);
        final pf = tester.widget<Face>(find.byWidgetPredicate((w) => w is Face && w.ring && w.col == '#f2c14e' && w.size == faceBig).first);
        expect(pf.img, g.pres.face);
        expect(pf.size, faceBig);
        await p.reveal(find.byKey(const ValueKey('face-legend')));
        final legend = find.descendant(of: find.byKey(const ValueKey('face-legend')), matching: find.byType(RichText));
        expect(tester.widget<RichText>(legend.first).text.toPlainText(), contains(tr('顔の縁の色はいちばん高い能力')));
        final s0 = g.staff.first;
        // 左の一覧は区分ごと（事業を任せている人は「責任者」）
        p.ctl.setPeopleSeg(g.biz.any((b) => b.mgr == s0.id) ? 'mgr' : 'exec');
        await tester.pump();
        await p.reveal(find.byKey(ValueKey('person-row-${s0.id}')));
        final sf = tester.widget<Face>(find.descendant(of: find.byKey(ValueKey('person-row-${s0.id}')), matching: find.byType(Face)));
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
    for (final home in const ['jp', 'us', 'in', 'ng', 'mx', 'sa']) {
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
            // 宿敵の代替わりのあとの場面（名札・本文の名前・顔が今の社長）
            final first = rv.presName;
            var heir = first;
            for (var i = 0; i < 20 && heir == first; i++) {
              heir = g.heirName(first, rv.rival!.k);
            }
            rv
              ..presName = heir
              ..presAge = 38;
            g.ensureFaces();
            for (final (name, e) in [('alliance', g.evAlliance(rv)), ('poach', g.rivalScene(rv, 'poach'))]) {
              if (e == null) continue;
              g.events
                ..clear()
                ..add(e);
              nextEvent(p.ctl);
              await tester.pump();
              await snap('rival_heir_$name');
              p.ctl.closeSheet();
              await tester.pump();
            }
            expect(tester.takeException(), isNull);
          }, skip: shotDir == null, timeout: const Timeout(Duration(minutes: 10)));
        }
      }
    }
  });
}
