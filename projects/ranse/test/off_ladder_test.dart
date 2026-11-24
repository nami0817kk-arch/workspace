import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/craft_life.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/off_ladder.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/scene_art.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 段の外の暮らしの段（項目24）と、住まいの絵（項目22）・大事件の絵（項目26）の振り分け（2026-11-25）。

/// 身分を [cls] に置き換えた生まれ。
Birth _asClass(Birth b, String cls) {
  final c = classById(cls);
  return Birth(
    cls: c,
    region: b.region,
    faction: b.faction,
    startYear: b.startYear,
    month: b.month,
    day: b.day,
    female: b.female,
    order: b.order,
    stats: b.stats,
    traits: b.traits,
    rarity: b.rarity,
    name: b.name,
    label: clsLabel(c, b.female, b.order),
    sameClass: b.sameClass,
    birthRank: calcBirthRank(c, b.female, b.order),
  );
}

/// 身分を [cls]・性別を [female] にし、[age] 歳の大人にした人生（選択肢は消してある）。
Game _adult(String cls, {bool female = false, int age = 20, int seed = 0}) {
  for (var s = seed;; s++) {
    final rng = Rng(s + 7000);
    final g = Game(rng: rng);
    g.start(_asClass(rollBirth(rng, asFemale: female), cls));
    if (g.finished) continue;
    g.prompt = null;
    g.l.t = age * 2;
    return g;
  }
}

/// 生業に留まる選び方: 重点では仕官・奉公を探さず、岐路は無作為（病に伏したら養う）。
int _stayPick(Game g, Prompt p, Rng r) {
  final y = p.choices.indexWhere((c) => c.label == '病を養う');
  if (y >= 0) return y;
  if (p.title == 'この年の心がけ') {
    final ok = [
      for (var i = 0; i < p.choices.length; i++)
        if (!p.choices[i].label.contains('仕官') &&
            !p.choices[i].label.contains('奉公'))
          i,
    ];
    return ok[r.range(0, ok.length - 1)];
  }
  return r.range(0, p.choices.length - 1);
}

void main() {
  test('梯子の表: 段は三つ以上・道しるべは段の数より一つ少ない・数字を書かない', () {
    expect(kOffLadders.length, greaterThanOrEqualTo(8));
    for (final e in kOffLadders.entries) {
      final d = e.value;
      expect(d.steps.length, greaterThanOrEqualTo(3), reason: e.key);
      expect(d.hints.length, d.steps.length - 1, reason: e.key);
      expect(d.steps.toSet().length, d.steps.length, reason: e.key);
      for (final t in [d.title, d.top, ...d.steps, ...d.hints]) {
        expect(t, isNotEmpty, reason: e.key);
        expect(_digits.hasMatch(t), isFalse, reason: t);
      }
    }
    // 頼まれた梯子の名。
    expect(kOffLadders['merchant']!.steps, ['振り売り', '店持ち', '大店', '御用商人']);
    expect(kOffLadders['priest']!.steps, ['小僧', '僧', '住持', '高僧']);
    expect(kOffLadders['ninja']!.steps.last, '里の頭');
    expect(kOffLadders['farm']!.steps, ['小百姓', '本百姓', '組頭', '庄屋・名主']);
  });

  test('旗と歳で段が決まる（暮らしごと）', () {
    // 村
    var g = _adult('farmer', age: 20);
    expect(offLadder(g)!.kind, 'farm');
    expect(offLadder(g)!.step, 0);
    g.setFlag('ox');
    expect(offLadder(g)!.step, 1);
    g.setFlag('tf_so_role');
    expect(offLadder(g)!.step, 2);
    g.setFlag('shoya');
    expect(offLadder(g)!.step, 3);
    expect(offLadder(_adult('farmer', age: 30))!.step, 1);
    // 商い（町人の家・商いの道）
    g = _adult('merchant', age: 20);
    expect(offLadder(g)!.kind, 'merchant');
    expect(offLadder(g)!.step, 0);
    g.setFlag('way_merchant');
    expect(offLadder(g)!.step, 1);
    g.setFlag('sp_shop_1');
    expect(offLadder(g)!.step, 2);
    g.setFlag('goyo');
    expect(offLadder(g)!.step, 3);
    g = _adult('farmer', age: 20)..setFlag('way_merchant');
    expect(offLadder(g)!.kind, 'merchant');
    // 町人の家の者は、歳を重ねると家の店を継ぐ。
    expect(offLadder(_adult('merchant', age: 30))!.name, '店持ち');
    // 仏門（男は僧、女は尼）
    g = _adult('farmer', age: 16)..setFlag('priesthood');
    expect(offLadder(g)!.kind, 'priest');
    expect(offLadder(g)!.name, '小僧');
    g.l.t = 25 * 2;
    expect(offLadder(g)!.name, '僧');
    g.setFlag('abbot');
    expect(offLadder(g)!.name, '住持');
    g.setFlag('tm_rongi_praised');
    expect(offLadder(g)!.name, '高僧');
    expect(offLadder(_adult('farmer', female: true)..setFlag('priesthood'))!.kind, 'nun');
    // 忍び
    g = _adult('ninja', age: 18);
    expect(offLadder(g)!.name, '下忍');
    g.setFlag('sh_trust');
    expect(offLadder(g)!.name, '中忍');
    g.setFlag('sh_lord_far');
    expect(offLadder(g)!.name, '上忍');
    g.setFlag('sh_n_heir');
    expect(offLadder(g)!.name, '里の頭');
    expect(offLadder(_adult('ninja')..setFlag('nukenin')..setFlag('way_outlaw')), isNull);
    // 野盗・流れ者
    g = _adult('farmer', age: 20)..setFlag('way_outlaw');
    expect(offLadder(g)!.kind, 'bandit');
    expect(offLadder(g)!.step, 0);
    g.setFlag('sh_band_head');
    expect(offLadder(g)!.name, '一味の頭');
    g = _adult('farmer', age: 20)
      ..setFlag('way_outlaw')
      ..setFlag('wanderer');
    expect(offLadder(g)!.kind, 'wanderer');
    g.setFlag('sh_yojin_kept');
    expect(offLadder(g)!.step, 1);
    g.setFlag('sh_jingari_won');
    expect(offLadder(g)!.step, 2);
    // 職人・河原
    g = _adult('farmer', age: 18)..setFlag('cr_craft');
    expect(offLadder(g)!.kind, 'craft');
    expect(offLadder(g)!.name, '弟子');
    g.setFlag('cr_kurabe_won');
    expect(offLadder(g)!.name, '親方');
    g.setFlag('cr_goyo_done');
    expect(offLadder(g)!.name, '名工');
    g = _adult('beggar', age: 18);
    expect(offLadder(g)!.kind, 'kawara');
    g.setFlag('cr_niwa_master');
    expect(offLadder(g)!.step, 2);
    // 浜・山
    g = _adult('fisher', age: 18);
    expect(offLadder(g)!.kind, crMountainFolk(g) ? 'mountain' : 'sea');
  });

  test('武家と奥の女性・子ども・隠居・村の女性には使わない', () {
    final g = _adult('farmer', age: 25);
    g.l.rank = 1;
    expect(offLadder(g), isNull);
    final w = _adult('farmer', female: true, age: 25);
    expect(offLadder(w), isNull);
    w.l.rank = 3;
    expect(offLadder(w), isNull);
    expect(offLadder(_adult('samurai', age: 25)..l.rank = 3), isNull);
    expect(offLadder(_adult('farmer', age: 25)..setFlag('retired')), isNull);
    final kid = _adult('merchant', age: 10);
    expect(offLadder(kid), isNull);
    // 仏門に入れば、元の位にかかわらず仏門の段（出家で位は外れる）。
    final m = _adult('samurai', age: 40)
      ..l.rank = 0
      ..setFlag('priesthood');
    expect(offLadder(m)!.kind, 'priest');
  });

  test('人生を通して、同じ暮らしのあいだ段は下がらず、位に就けば段の外の梯子は消える。足した岐路は段の手前の人に出る', () {
    final seen = <String, Set<int>>{};
    final newScenes = <String, int>{};
    final choices = <String, List<Choice>>{};
    var lives = 0;
    const classes = ['farmer', 'fisher', 'merchant', 'ninja', 'beggar', 'farmer'];
    for (var i = 0; i < 600; i++) {
      final rng = Rng(8100 + i);
      final g = Game(rng: rng);
      g.start(_asClass(rollBirth(rng), classes[i % classes.length]));
      final pick = Rng(9100 + i);
      String? kind;
      var step = -1;
      var known = <String>{};
      var n = 0;
      lives++;
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        final o = offLadder(g);
        if (g.isChild || g.l.rank != 0) expect(o, isNull);
        if (o != null) {
          if (o.kind == kind) {
            expect(o.step, greaterThanOrEqualTo(step), reason: '${o.kind} の段が下がった（${g.age}歳）');
          }
          kind = o.kind;
          step = o.step;
          (seen[o.kind] ??= {}).add(o.step);
          expect(o.guide, isNotEmpty);
        } else {
          kind = null;
          step = -1;
        }
        final now = g.l.flags.where((f) => f.startsWith('scene:ol_')).toSet();
        for (final f in now.difference(known)) {
          final id = f.substring(6);
          newScenes[id] = (newScenes[id] ?? 0) + 1;
          choices[id] = p.choices;
          // 出た瞬間は、まだ段を上がる前（村は本百姓、浜は船持ち、商いは店持ち）。
          expect(o, isNotNull, reason: id);
          expect((o!.kind, o.step), kOffLadderSceneAt[id], reason: id);
        }
        known = now;
        g.choose(i.isEven ? _stayPick(g, p, pick) : pickAmbitious(g, p, pick));
      }
      expect(g.finished, isTrue);
    }
    for (final e in choices.entries) {
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key}: ${c.label}');
        expect(_digits.hasMatch(c.label) || _digits.hasMatch(c.hint ?? ''), isFalse, reason: c.label);
      }
    }
    // 村・浜・商い・忍び・河原・職人の段が出て、村は組頭より上まで届く人生がある。
    for (final k in ['farm', 'merchant', 'ninja', 'kawara']) {
      expect(seen[k], isNotNull, reason: '$k $seen');
      expect(seen[k]!.length, greaterThanOrEqualTo(2), reason: '$k $seen');
    }
    expect(seen['farm']!.contains(2) || seen['farm']!.contains(3), isTrue, reason: '$seen');
    expect(newScenes['ol_kumigashira'] ?? 0, greaterThan(0), reason: '$newScenes');
    // ignore: avoid_print
    print('【段の外の暮らし】$lives人生　出た段 $seen　足した岐路 $newScenes');
  });

  test('足した岐路は一度ずつ登録されている', () {
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kOffLadderSceneIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
    }
    expect(kOffLadderSceneAt.keys.toSet(), kOffLadderSceneIds.toSet());
    expect(ids.where((x) => x.startsWith('ol_')).length, kOffLadderSceneIds.length);
  });

  group('大事件の絵', () {
    test('表の id はすべて実在し、事件は頼まれた八つ', () {
      final g = Game(rng: Rng(1));
      final ids = {
        ...g.adultScenes.map((s) => s.id),
        ...g.childScenes.map((s) => s.id),
      };
      expect(kEventScenes.keys.toSet(), {
        'okehazama',
        'kawanakajima',
        'nagashino',
        'honnoji',
        'sekigahara',
        'osaka',
        'hiei',
        'shimabara',
      });
      final all = <String>[];
      for (final e in kEventScenes.entries) {
        expect(e.value, isNotEmpty, reason: e.key);
        for (final id in e.value) {
          expect(ids.contains(id), isTrue, reason: '$id（${e.key}）が場面にない');
          all.add(id);
        }
      }
      expect(all.toSet().length, all.length, reason: '同じ id が二つの事件にある');
    });

    test('大事件の場面では専用の絵を選び、絵が無いときは場面の絵に落ちる', () {
      final g = Game(rng: Rng(3));
      g.start(rollBirth(Rng(3)));
      for (final e in kEventScenes.entries) {
        for (final id in e.value) {
          final art = sceneArtFor(g, id, '合戦');
          expect(art, 'event_${e.key}', reason: id);
          expect(artAssetPath(art!), 'assets/images/event_${e.key}.jpg');
          expect(kSceneArts, contains(artFallback(art)), reason: id);
          expect(eventOfScene(id), e.key);
        }
      }
      // 大事件でない場面は、いままでどおり。
      expect(sceneArtFor(g, 'bt_ambush', '夜襲'), 'battle');
      expect(artFallback('battle'), isNull);
      expect(artAssetPath('battle'), 'assets/images/scene_battle.jpg');
      expect(eventOfScene('bt_ambush'), isNull);
      expect(sceneArtFor(g, null, 'この年の心がけ'), isNull);
    });
  });

  group('住まいの絵', () {
    test('身分と道で住まいを選ぶ', () {
      expect(homeArtFor(_adult('farmer', age: 25)), 'farm');
      expect(homeArtFor(_adult('merchant', age: 25)), 'town');
      expect(homeArtFor(_adult('farmer', age: 25)..setFlag('priesthood')), 'temple');
      expect(homeArtFor(_adult('farmer', age: 25)..setFlag('way_outlaw')), 'wild');
      expect(homeArtFor(_adult('ninja', age: 25)), 'wild');
      expect(homeArtFor(_adult('farmer', age: 25)..setFlag('way_merchant')), 'town');
      expect(homeArtFor(_adult('farmer', age: 25)..l.rank = 2), 'samurai');
      expect(homeArtFor(_adult('farmer', age: 25)..l.rank = 5), 'castle');
      expect(homeArtFor(_adult('farmer', female: true, age: 25)..l.rank = 2), 'castle');
      expect(homeArtFor(_adult('daimyo', age: 8)), 'castle');
      expect(homeArtFor(_adult('samurai', age: 8)), 'samurai');
      expect(homeArtFor(_adult('priest', age: 8)), 'temple');
      expect(homeArtPath('farm'), 'assets/images/home_farm.jpg');
    });

    test('どの人生のどの年も、表にある絵のどれかになり、六つすべてが出る', () {
      final seen = <String, int>{};
      for (var i = 0; i < 200; i++) {
        final rng = Rng(6100 + i);
        final g = Game(rng: rng)..start(rollBirth(rng));
        final pick = Rng(6300 + i);
        var n = 0;
        while (!g.finished && n++ < 3000) {
          final h = homeArtFor(g);
          expect(kHomeArts, contains(h));
          seen[h] = (seen[h] ?? 0) + 1;
          final p = g.prompt!;
          g.choose(i.isEven ? pick.range(0, p.choices.length - 1) : pickAmbitious(g, p, pick));
        }
      }
      expect(seen.keys.toSet(), kHomeArts.toSet(), reason: '$seen');
      // ignore: avoid_print
      print('【住まいの絵】$seen');
    });
  });
}
