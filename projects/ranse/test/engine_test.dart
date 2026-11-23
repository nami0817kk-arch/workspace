import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/adult.dart';
import 'package:ranse/engine/battles.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/bonds.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/family.dart';
import 'package:ranse/engine/endings_catalog.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/pastimes.dart';
import 'package:ranse/engine/regions.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/talents.dart';
import 'package:ranse/engine/temple.dart';
import 'package:ranse/engine/ways.dart';
import 'package:ranse/engine/women_life.dart';

import 'bot.dart';

/// 生き延びて元服まで進める生まれを探して始める。
Game startSurvivor(int seed) {
  final rng = Rng(seed);
  var g = Game(rng: rng);
  var guard = 0;
  do {
    g = Game(rng: rng);
    g.start(rollBirth(rng));
  } while (g.finished && guard++ < 50);
  return g;
}

/// 選択肢をランダムに選び、人生の終わりまで進める。
/// どの年も、選択肢（今年の重点か岐路）が必ず出ていること。
void playOut(
  Game g,
  Rng pickRng, {
  int limit = 1500,
  void Function(Prompt p)? onPrompt,
}) {
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    onPrompt?.call(p!);
    g.choose(pickRng.range(0, p!.choices.length - 1));
  }
}

/// 幼少期だけを、ランダムに選んで最後まで進める（元服の手前まで）。
void playChildhood(Game g, Rng pickRng, {void Function(Prompt p)? onPrompt}) {
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '幼少期なのに選択肢が出ていない');
    onPrompt?.call(p!);
    g.choose(pickRng.range(0, p!.choices.length - 1));
  }
}

String jsonOf(Game g) => jsonEncode({
  'life': g.l.toJson(),
  'world': g.fa.values.map((f) => f.toJson()).toList(),
});

(Life, Map<String, Faction>) fromJson(String s) {
  final back = jsonDecode(s) as Map<String, dynamic>;
  final life = Life.fromJson(back['life'] as Map<String, dynamic>);
  final world = {
    for (final e in (back['world'] as List))
      (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
  };
  return (life, world);
}

void main() {
  test('年表の出来事は、年と月の順に起きる（同じ年の中でも前後しない）', () {
    final ids = kHistoryInOrder.map((e) => e.id).toList();
    for (var i = 1; i < kHistoryInOrder.length; i++) {
      final a = kHistoryInOrder[i - 1], b = kHistoryInOrder[i];
      expect(a.year * 100 + a.month <= b.year * 100 + b.month, isTrue);
    }
    bool before(String a, String b) => ids.indexOf(a) < ids.indexOf(b);
    expect(before('kenou', 'takamatsu'), isTrue);
    expect(before('takamatsu', 'honnoji'), isTrue);
    expect(before('honnoji', 'tensho_jingo'), isTrue);
    expect(before('tottori', 'kenou'), isTrue);
    expect(before('kanegasaki', 'anegawa'), isTrue);
    expect(before('motonari_death', 'hiei'), isTrue);
    expect(before('azuchi_shuron', 'arioka'), isTrue);
    expect(before('koriyama', 'shingen'), isTrue);
  });

  test('松平の家は、1567年から徳川と呼ぶ（今川が生き延びた世では松平のまま）', () {
    final rng = Rng(5);
    final g = Game(rng: rng);
    g.start(rollBirth(rng));
    g.l.t = (1566 - g.l.startYear) * 2;
    expect(houseName(g, '松平'), '松平');
    g.l.t = (1570 - g.l.startYear) * 2;
    expect(houseName(g, '松平'), '徳川');
    expect(houseName(g, '織田'), '織田');
    g.setFlag('history_okehazama');
    expect(houseName(g, '松平'), '松平');
  });

  test('どの国にも位置があり、近い家ほど隔たりが小さい', () {
    for (final r in kRegions) {
      expect(kRegionPos.containsKey(r.n), isTrue, reason: r.n);
    }
    expect(
      factionDistance('会津', '伊達'),
      lessThan(factionDistance('会津', '長宗我部')),
    );
    expect(factionDistance('土佐', '毛利'), lessThan(factionDistance('土佐', '伊達')));
    expect(factionDistance('近江', '浅井'), 0);
    // 家どうしでも、近い順に並ぶ（侵攻先・好敵手・人質先・小競り合いの相手に使う）。
    final names = kFactionBase.keys.where((n) => n != '伊達');
    final near = nearest(names, (n) => n, faction: '伊達', n: 3);
    expect(near, containsAll(['蘆名', '最上']));
    expect(near, isNot(contains('島津')));
    expect(
      nearest(names, (n) => n, region: '薩摩', n: 2),
      everyElement(isIn(['大友', '龍造寺', '島津'])),
    );
  });

  test('仕官・奉公の先に、遠国の家は出ない（会津から四国・九州へは行かない）', () {
    const far = {'長宗我部', '島津', '大友', '龍造寺', '毛利', '尼子'};
    var asked = 0;
    for (var seed = 0; seed < 3000 && asked < 30; seed++) {
      final rng = Rng(seed);
      final b = rollBirth(rng);
      if (b.region.n != '会津' && b.region.n != '陸奥') continue;
      final g = Game(rng: rng);
      g.start(b);
      final r = Rng(seed + 1);
      var n = 0;
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        if (p.title == '仕官' || p.title == '奉公先') {
          asked++;
          // 先頭は故郷の家（滅んでいれば天下で最も強い家）なので、2つめ以降を見る。
          for (final c in p.choices.skip(1)) {
            expect(far.any((f) => c.label == '$f家'), isFalse, reason: c.label);
          }
        }
        g.choose(r.range(0, p.choices.length - 1));
      }
    }
    expect(asked, greaterThan(0));
  });

  test('子どもの重点に「寺へ手習いに通う」が出て、初めて選んだ年に手習いの岐路が起きる', () {
    var checked = 0;
    for (var seed = 0; seed < 400 && checked < 20; seed++) {
      final rng = Rng(seed + 9100);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished || g.l.cls.id == 'priest') continue;
      final p = g.prompt!;
      if (p.title != '今年の重点') continue;
      final i = p.choices.indexWhere((c) => c.label == '寺へ手習いに通う');
      expect(i, isNonNegative, reason: g.l.cls.id);
      g.choose(i);
      // 手習いの岐路まで進める（間に史実の岐路などが挟まることはない年の初め）。
      expect(g.prompt!.title, '寺の手習い');
      g.choose(0);
      expect(g.hasFlag('tera_diligent'), isTrue);
      checked++;
    }
    expect(checked, greaterThan(10));
  });

  test('家柄で増える子どもの重点: 商家の子に算盤、武家の子に道場', () {
    var merchant = 0, samurai = 0;
    for (var seed = 0; seed < 4000; seed++) {
      final rng = Rng(seed + 9300);
      final b = rollBirth(rng);
      if (b.cls.id != 'merchant' && b.cls.id != 'samurai') continue;
      final g = Game(rng: rng);
      g.start(b);
      final r = Rng(seed);
      var n = 0;
      // 8歳を過ぎるまで進めて、重点の選択肢を見る。
      while (!g.finished && n++ < 200) {
        final p = g.prompt!;
        if (p.title == '今年の重点' && g.age >= 8) {
          final labels = p.choices.map((c) => c.label).toList();
          if (b.cls.id == 'merchant') {
            expect(labels, contains('算盤と商いを習う'));
            merchant++;
          } else {
            expect(labels, contains('道場で稽古をつけてもらう'));
            samurai++;
          }
          break;
        }
        g.choose(r.range(0, p.choices.length - 1));
      }
      if (merchant >= 5 && samurai >= 3) break;
    }
    expect(merchant, greaterThan(0));
    expect(samurai, greaterThan(0));
  });

  test('どんな生まれでも最後まで進み、例外を出さない', () {
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed + 10000));
      expect(g.finished, isTrue, reason: 'seed=$seed が終わらない');
      expect(g.l.dead != null || g.l.end != null, isTrue);
    }
  });

  test('300人生を最後まで流しても、時間がかからない（終わらない回り方がない）', () {
    final sw = Stopwatch()..start();
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed + 4242);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed);
      var c = 0;
      while (!g.finished && c++ < 3000) {
        g.choose(r.range(0, g.prompt!.choices.length - 1));
      }
      expect(g.finished, isTrue, reason: 'seed=$seed が3000回の選択で終わらない');
    }
    expect(sw.elapsed.inSeconds, lessThan(60));
  });

  test('実測（記録用）: 遊ぶ時間の目安と最高位の分布を CI の記録に出す', () {
    for (final smart in [false, true]) {
      final mins = <double>[];
      final ranks = List.filled(10, 0);
      // 場面ごとの「1人生での最多回数」の合計と、出た人生の数（繰り返しの多さを見る）。
      final maxPerLife = <String, int>{}, lives = <String, int>{};
      for (var seed = 0; seed < 1000; seed++) {
        final rng = Rng(seed + 4242);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        var c = 0, s = 0;
        final perLife = <String, int>{};
        while (!g.finished && c < 3000) {
          final p = g.prompt!;
          if (p.title != '今年の重点') {
            s++;
            perLife[p.title] = (perLife[p.title] ?? 0) + 1;
          }
          c++;
          g.choose(
            smart ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1),
          );
        }
        // 重点1回=10秒、岐路1回=40秒の目安。
        mins.add(((c - s) * 10 + s * 40) / 60);
        if (g.age >= 15) ranks[g.l.maxRank]++;
        perLife.forEach((t, n) {
          maxPerLife[t] = (maxPerLife[t] ?? 0) + n;
          lives[t] = (lives[t] ?? 0) + 1;
        });
      }
      final rep = maxPerLife.keys.toList()
        ..sort(
          (a, b) => (maxPerLife[b]! / lives[b]!).compareTo(
            maxPerLife[a]! / lives[a]!,
          ),
        );
      // ignore: avoid_print
      print(
        '【繰り返し】${smart ? '考えて選ぶ' : 'ランダム'}: '
        '${rep.take(8).map((t) => '$t ${(maxPerLife[t]! / lives[t]!).toStringAsFixed(1)}回/人生（${lives[t]}人生）').join('・')}',
      );
      mins.sort();
      double q(double p) => mins[(mins.length * p).floor()];
      // ignore: avoid_print
      print(
        '【実測】${smart ? '考えて選ぶ' : 'ランダム'}: 遊ぶ時間 中央${q(.5).toStringAsFixed(1)}分'
        '・90%点${q(.9).toStringAsFixed(1)}分・最長${mins.last.toStringAsFixed(1)}分'
        '／最高位 ${ranks.join(',')}',
      );
      expect(mins.last, greaterThan(0));
    }
  });

  test('何度も起きる岐路（出陣・侵攻）は、書き出しが回を重ねると変わる', () {
    final texts = <String, Set<String>>{};
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed + 4242);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed);
      var c = 0;
      while (!g.finished && c++ < 3000) {
        final p = g.prompt!;
        if (p.title == '出陣' || p.title == '侵攻') {
          texts.putIfAbsent(p.title, () => {}).add(p.text);
        }
        g.choose(pickAmbitious(g, p, r));
      }
    }
    expect(texts['出陣']?.length ?? 0, greaterThanOrEqualTo(5));
  });

  test('女性の人生に固有の岐路（奥・お産・実家・再縁・娘の嫁ぎ先など）が出る', () {
    final seen = <String>{};
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 31);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (!g.l.female) continue;
      playOut(g, Rng(seed));
      seen.addAll(
        g.l.flags
            .where((f) => f.startsWith('scene:w_'))
            .map((f) => f.substring(6)),
      );
    }
    expect(seen.length, greaterThanOrEqualTo(7), reason: '$seen');
  });

  test('子ども時代の岐路は、生まれによって顔ぶれが変わる（同じ場面ばかりにならない）', () {
    final seen = <String>{};
    var pairsSame = 0, pairs = 0;
    List<String>? prev;
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed + 77);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished) continue;
      playChildhood(g, Rng(seed));
      final mine =
          g.l.flags
              .where((f) => f.startsWith('scene:') && !f.startsWith('scene:h_'))
              .toList()
            ..sort();
      seen.addAll(mine);
      if (prev != null) {
        pairs++;
        if (prev.join() == mine.join()) pairsSame++;
      }
      prev = mine;
    }
    expect(seen.length, greaterThanOrEqualTo(22), reason: '$seen');
    expect(pairsSame / pairs, lessThan(.05));
  });

  test('信長・謙信との再会は、本人が生きている年にだけ起きる', () {
    for (var seed = 0; seed < 400; seed++) {
      final rng = Rng(seed + 3);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished) continue;
      g.setFlag('met_nobunaga');
      g.setFlag('met_kenshin');
      playOut(
        g,
        Rng(seed),
        onPrompt: (p) {
          if (p.title == '信長' && !g.hasFlag('history_honnoji')) {
            expect(g.year, lessThanOrEqualTo(1581));
          }
          if (p.title == '越後の主') expect(g.year, lessThanOrEqualTo(1577));
        },
      );
    }
  });

  test('足軽の暮らしの岐路（長屋・博打・乱取り・朋輩の死など）が出る', () {
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      final rng = Rng(seed + 55);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playChildhood(g, Rng(seed));
      if (g.finished || g.l.female) continue;
      g.l
        ..rank = 1
        ..maxRank = 1
        ..lord = g.alive.first.name
        ..fav = 20;
      playOut(g, Rng(seed + 1));
      seen.addAll(
        g.l.flags
            .where((f) => f.startsWith('scene:a_'))
            .map((f) => f.substring(6)),
      );
    }
    expect(seen.length, greaterThanOrEqualTo(6), reason: '$seen');
  });

  test('村の暮らしの岐路（田植え・寄合・牛・祭り・子の熱など）が出る', () {
    final seen = <String>{};
    for (var seed = 0; seed < 400; seed++) {
      final rng = Rng(seed + 66);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.finished || g.l.cls.id != 'farmer') continue;
      // 仕官などせず、村で働き続ける選び方。
      var n = 0;
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        var i = p.choices.indexWhere((c) => c.label == '働いて稼ぐ');
        if (i < 0) i = p.choices.length - 1;
        g.choose(i);
      }
      seen.addAll(
        g.l.flags
            .where((f) => f.startsWith('scene:v_'))
            .map((f) => f.substring(6)),
      );
    }
    expect(seen.length, greaterThanOrEqualTo(6), reason: '$seen');
  });

  test('実測（記録用）: 大名から始めて版図を広げ続けると、天下統一に届くか', () {
    var lives = 0, victory = 0;
    final maxShares = <double>[];
    for (var seed = 0; seed < 200; seed++) {
      final rng = Rng(seed + 31337);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playChildhood(g, Rng(seed));
      if (g.finished) continue;
      g.choose(0); // 元服
      if (g.finished) continue;
      final home = g.fa[g.l.home]!.alive ? g.l.home : g.alive.first.name;
      g.l
        ..rank = 8
        ..maxRank = 8
        ..lord = home
        ..gold = 100;
      // 元服の年の選択肢は前の身分で作られているので、休んで次の年から大名として測る。
      final rest = g.prompt!.choices.indexWhere((c) => c.label.contains('休'));
      g.choose(rest < 0 ? g.prompt!.choices.length - 1 : rest);
      lives++;
      var best = 0.0, n = 0;
      final r = Rng(seed);
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        if (g.l.rank == 8 && g.share > best) best = g.share;
        var i = -1;
        if (p.title == '今年の重点') {
          i = p.choices.indexWhere((c) => c.label == '版図を広げる');
          if (g.l.gold < 30 || r.chance(.25)) {
            i = p.choices.indexWhere((c) => c.label == '軍備を整える');
          }
          if (g.l.hp < g.l.maxhp * .4) {
            i = p.choices.indexWhere(
              (c) => c.label.contains('休') || c.label.contains('家族'),
            );
          }
        } else if (p.title == '侵攻') {
          i = 0; // いちばん弱い相手
        }
        if (i < 0) i = pickAmbitious(g, p, r);
        g.choose(i);
      }
      if (g.l.victory) victory++;
      maxShares.add(best);
    }
    maxShares.sort();
    double q(double p) => maxShares[(maxShares.length * p).floor()];
    // ignore: avoid_print
    print(
      '【天下】大名から始めた$lives人生: 天下統一 $victory'
      '・最大の占有率 中央${(q(.5) * 100).round()}%・90%点${(q(.9) * 100).round()}%・最高${(maxShares.last * 100).round()}%',
    );
    expect(lives, greaterThan(50));
  });

  test('身分の名前は、仏門・商い・野の道・隠居を書き分ける', () {
    final rng = Rng(3);
    final g = Game(rng: rng);
    var b = rollBirth(rng);
    g.start(b);
    while (g.finished) {
      b = rollBirth(rng);
      g.start(b);
    }
    g.l.t = 40; // 20歳
    g.l.rank = 0;
    expect(g.rankName(), contains('無役'));
    g.setFlag('priesthood');
    expect(g.rankName(), g.l.female ? '尼' : '僧');
    expect(g.nextPromo(), '仏の道を歩む');
    g.l.flags.remove('priesthood');
    g.setFlag('way_merchant');
    expect(g.rankName(), '商人');
    g.l.flags.remove('way_merchant');
    g.l.ronin = true;
    expect(g.rankName(), g.l.female ? '流浪の身' : '浪人');
    g.l.rank = 3;
    g.setFlag('retired');
    expect(g.rankName(), startsWith('隠居（元'));
  });

  test('実測（記録用）: 手書きの最期のうち、実際に出会えるもの', () {
    final seen = <String>{};
    final tierCount = <Tier, int>{};
    final phantomIds = <String, int>{};
    const leans = [
      <String>[],
      ['働いて稼ぐ', '人の倍の田を植える'],
      ['店を構える', '商いを広げる', '仕入れの旅に出る'],
      ['髪を下ろす', '出家して仏門に入る', '修行に打ち込む'],
      ['仲間に加わる', 'あてのない旅に出る', '獲物を狙う'],
    ];
    for (var seed = 0; seed < 6000; seed++) {
      final rng = Rng(seed + 77777);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed);
      final lean = leans[seed % leans.length];
      final smart = seed % 3 == 0;
      var n = 0;
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        var i = -1;
        for (final w in lean) {
          final k = p.choices.indexWhere((c) => c.label == w);
          if (k >= 0) i = k;
        }
        if (i < 0) {
          i = smart ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1);
        }
        g.choose(i);
      }
      final e = buildEnding(g);
      if (e.handId != null) seen.add(e.handId!);
      if (e.tier != null) tierCount[e.tier!] = (tierCount[e.tier!] ?? 0) + 1;
      if (e.tier == Tier.phantom) {
        phantomIds[e.handId!] = (phantomIds[e.handId!] ?? 0) + 1;
      }
    }
    final byWay = <String, List<int>>{};
    for (final e in kHandEndings) {
      final v = byWay.putIfAbsent(e.way, () => [0, 0]);
      v[1]++;
      if (seen.contains(e.id)) v[0]++;
    }
    // ignore: avoid_print
    print(
      '【最期の到達】6000人生で出た手書きの最期 ${seen.length}／${kHandEndings.length}: '
      '${byWay.entries.map((e) => '${e.key} ${e.value[0]}/${e.value[1]}').join('・')}',
    );
    // 希少度ごとに、何人生に一度出たか（幻は数百回に一度の狙い）。
    // ignore: avoid_print
    print(
      '【希少度の出方】6000人生: '
      '${Tier.values.map((t) => '${kTierNames[t]} ${tierCount[t] ?? 0}回（${(tierCount[t] ?? 0) == 0 ? '-' : '${(6000 / tierCount[t]!).toStringAsFixed(1)}人生に1回'}）').join('・')}',
    );
    final ph = phantomIds.entries.toList()..sort((a, b) => b.value - a.value);
    // ignore: avoid_print
    print('【出た幻】${ph.map((e) => '${e.key}×${e.value}').join(' ')}');
    expect(seen, isNotEmpty);
  });

  test('同じ種なら同じ人生になる', () {
    String run(int seed) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed + 1));
      return '${g.l.name}/${g.age}/${g.l.maxRank}/${g.l.dead ?? g.l.end}/${g.score}/${g.l.path.join('|')}';
    }

    expect(run(7), run(7));
  });

  test('乳幼児の死亡は五人に一人くらい（10〜30%）', () {
    var died = 0;
    const n = 3000;
    for (var i = 0; i < n; i++) {
      final rng = Rng(i);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (g.l.dead != null && g.age < 5) died++;
    }
    final rate = died / n;
    expect(rate, greaterThan(.10));
    expect(rate, lessThan(.30));
  });

  test('岐路の選択肢は結果を匂わせる一言を持ち、数字（成功率）は出さない（一生を通して）', () {
    for (var seed = 0; seed < 200; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(
        g,
        Rng(seed + 5),
        onPrompt: (p) {
          if (p.title == '元服' || p.title == '裳着') return;
          for (final c in p.choices) {
            expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
            expect(
              c.hint!,
              isNot(contains('%')),
              reason: '${p.title}/${c.label}',
            );
            expect(
              c.hint!,
              isNot(contains('成功率')),
              reason: '${p.title}/${c.label}',
            );
            expect(
              c.label,
              isNot(contains('%')),
              reason: '${p.title}/${c.label}',
            );
          }
        },
      );
    }
  });

  group('幼少期', () {
    test('毎年「今年の重点」を選び、その途中で岐路が起きる', () {
      var checked = 0, scenes = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        final titles = <String>[];
        playChildhood(g, Rng(seed), onPrompt: (p) => titles.add(p.title));
        if (g.l.dead != null) continue;
        checked++;
        expect(
          titles.where((t) => t == '今年の重点').length,
          10,
          reason: 'seed=$seed',
        );
        final n = titles.where((t) => t != '今年の重点').length;
        scenes += n;
        // 1年に1つまで。史実の岐路はその年に必ず出るので、10年すべてで出ることもある。
        expect(n, inInclusiveRange(2, 10), reason: 'seed=$seed $titles');
        expect(g.prompt?.title, anyOf('元服', '裳着'), reason: 'seed=$seed');
        expect(g.age, 15);
      }
      expect(checked, greaterThan(100));
      expect(scenes / checked, inInclusiveRange(4, 8));
    });

    test('選んだ道が歩んだ道・縁のある人・旗として残る', () {
      var withPath = 0, withPeople = 0, total = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        playChildhood(g, Rng(seed + 9));
        if (g.l.dead != null) continue;
        total++;
        if (g.l.path.isNotEmpty) withPath++;
        if (g.l.people.isNotEmpty) withPeople++;
        expect(
          g.l.flags.where((f) => f.startsWith('scene:')).length,
          lessThanOrEqualTo(10),
        );
      }
      expect(withPath / total, greaterThan(.8));
      expect(withPeople / total, greaterThan(.3));
    });

    test('有名人との出会いは、史実の年代にだけ起きる', () {
      var seen = 0;
      for (var seed = 0; seed < 2500; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        playChildhood(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (p.title == '城下の若殿') {
              seen++;
              expect(g.l.region, '尾張');
              expect(g.year, inInclusiveRange(1542, 1546));
            }
            if (p.title == '寺の少年') {
              seen++;
              expect(g.l.region, '越後');
              expect(g.year, inInclusiveRange(1537, 1543));
            }
          },
        );
      }
      expect(seen, greaterThan(0), reason: '2500人で一度も出会いが起きない');
    });

    test('幼少期の途中で保存した状態から、その年を最初からやり直せる', () {
      final saved = <String>[];
      final rng = Rng(3);
      var g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
      var guard = 0;
      g.start(rollBirth(rng));
      while (g.finished && guard++ < 50) {
        g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
        g.start(rollBirth(rng));
      }
      expect(g.finished, isFalse);
      expect(saved, isNotEmpty, reason: '年の始まりで保存していない');
      final (life, world) = fromJson(saved.last);
      final g2 = Game(rng: Rng(99));
      g2.restore(life, world);
      expect(g2.prompt?.title, '今年の重点');
      expect(g2.l.name, g.l.name);
      expect(g2.age, inInclusiveRange(5, 14));
    });
  });

  group('大人（15歳〜）', () {
    test('元服のあとも毎年「今年の重点」が一度ずつ出る', () {
      var checked = 0;
      for (var seed = 0; seed < 150; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0); // 元服
        final years = <int>[];
        playOut(
          g,
          Rng(seed + 3),
          onPrompt: (p) {
            if (p.title == '今年の重点') years.add(g.age);
          },
        );
        if (years.isEmpty) continue;
        checked++;
        // 同じ年に二度聞かれない。年は一つずつ進む。
        for (var i = 1; i < years.length; i++) {
          expect(years[i], years[i - 1] + 1, reason: 'seed=$seed $years');
        }
        expect(years.first, 15);
      }
      expect(checked, greaterThan(80));
    });

    test('重点で選んだ年には、その岐路が必ず起きる（仕官・出陣・縁談）', () {
      for (var seed = 0; seed < 200; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0); // 元服
        var n = 0;
        while (!g.finished && n++ < 30) {
          final p = g.prompt!;
          if (p.title != '今年の重点') {
            g.choose(0);
            continue;
          }
          final labels = p.choices.map((c) => c.label).toList();
          const forced = {
            '仕官の口を探す': '仕官',
            '奉公先を探す': '奉公先',
            '妻を探す': '縁談',
            '嫁ぎ先を探す': '縁談',
          };
          final hit = forced.keys.where(labels.contains).toList();
          if (hit.isEmpty) {
            g.choose(0);
            continue;
          }
          g.choose(labels.indexOf(hit.first));
          if (g.finished) break;
          expect(
            g.prompt?.title,
            forced[hit.first],
            reason: 'seed=$seed ${hit.first}',
          );
          g.choose(0);
        }
      }
    });

    test('「戦に備える」を選ぶと、最初は初陣、そのあとは出陣になる', () {
      var firsts = 0, battles = 0;
      for (var seed = 0; seed < 300; seed++) {
        final g = startSurvivor(seed);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0);
        var n = 0;
        while (!g.finished && n++ < 40) {
          final p = g.prompt!;
          if (p.title == '今年の重点' && p.choices.any((c) => c.label == '戦に備える')) {
            final had = g.hasFlag('first_battle');
            g.choose(p.choices.indexWhere((c) => c.label == '戦に備える'));
            if (g.finished) break;
            expect(g.prompt?.title, had ? '出陣' : '初陣', reason: 'seed=$seed');
            had ? battles++ : firsts++;
            // 最後に並ぶ手を選んで進める（出陣は状況ごとに手の数が2〜3で変わる）。
            final q = g.prompt!;
            g.choose(q.choices.length - 1);
            continue;
          }
          g.choose(0);
        }
      }
      expect(firsts, greaterThan(0));
      expect(battles, greaterThan(0));
    });

    test('女性は合戦・下剋上の岐路に出ない（女武者と当主を除く）', () {
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (!g.l.female || g.finished) continue;
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (g.has('onna') || g.l.rank == 8) return;
            expect(
              p.title,
              isNot(anyOf('出陣', '初陣', '下剋上の誘い')),
              reason: 'seed=$seed',
            );
            expect(
              p.choices.map((c) => c.label),
              isNot(contains('戦に備える')),
              reason: 'seed=$seed',
            );
          },
        );
      }
    });

    test('幼い日に信長と遊んだ人は、のちに信長と再会しうる（史実の年代で）', () {
      var reunions = 0;
      for (var seed = 0; seed < 6000 && reunions == 0; seed++) {
        final rng = Rng(seed);
        final b = rollBirth(rng);
        if (b.region.n != '尾張') continue;
        final g = Game(rng: rng);
        g.start(b);
        if (g.finished) continue;
        playChildhood(g, Rng(seed));
        if (g.finished || !g.hasFlag('met_nobunaga')) continue;
        g.choose(0);
        playOut(
          g,
          Rng(seed),
          limit: 200,
          onPrompt: (p) {
            if (p.title == '信長') {
              reunions++;
              expect(g.year, greaterThanOrEqualTo(1552));
            }
          },
        );
      }
      expect(reunions, greaterThan(0), reason: '信長との再会が一度も起きない');
    });

    test('大人の途中で保存しても、旗・縁・道を含めて往復でき、その年から再開できる', () {
      final saved = <String>[];
      final rng = Rng(3);
      var g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
      var guard = 0;
      do {
        g = Game(rng: rng, onCheckpoint: (g) => saved.add(jsonOf(g)));
        g.start(rollBirth(rng));
        playChildhood(g, Rng(1));
      } while (g.finished && guard++ < 50);
      g.choose(0); // 元服 → 15歳の年の始まりで保存される
      expect(g.prompt?.title, '今年の重点');
      final last = saved.last;
      final (life, world) = fromJson(last);
      expect(jsonEncode(life.toJson()), jsonEncode(g.l.toJson()));
      expect(life.path, g.l.path);
      expect(life.flags, g.l.flags);
      expect(life.people.keys, g.l.people.keys);
      expect(life.focus, g.l.focus);
      final g2 = Game(rng: Rng(42));
      g2.restore(life, world);
      expect(g2.prompt?.title, '今年の重点');
      expect(g2.age, 15);
      expect(world.length, g.fa.length);
    });
  });

  test('生まれの稀少度: 大名の子は農民より桁違いに珍しい', () {
    final rng = Rng(1);
    final daimyo = <double>[], farmer = <double>[];
    for (var i = 0; i < 6000; i++) {
      final b = rollBirth(rng);
      expect(b.rarity, greaterThan(1));
      expect(b.rarity, lessThanOrEqualTo(kPopulation));
      if (b.cls.id == 'daimyo') daimyo.add(b.rarity);
      if (b.cls.id == 'farmer') farmer.add(b.rarity);
    }
    expect(farmer, isNotEmpty);
    double median(List<double> l) {
      l.sort();
      return l[l.length ~/ 2];
    }

    // 生まれた年・月日・国を数えないので、ありふれた農民の子は数十分の1ほど。民の数（千五百万）を超えない。
    expect(median(farmer), lessThan(200));

    if (daimyo.isNotEmpty) {
      expect(median(daimyo), greaterThan(median(farmer) * 100));
    }
    final cls = kClasses.firstWhere((c) => c.id == 'daimyo');
    final total = kClasses.fold<double>(0, (s, c) => s + c.w);
    expect(kPopulation * cls.w / total, lessThan(1000));
  });

  test('1600年を過ぎると乱世が終わる', () {
    for (var seed = 0; seed < 40; seed++) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playOut(g, Rng(seed));
      if (g.l.dead == null) {
        expect(g.l.end, anyOf('era', 'victory'));
      }
      if (g.l.end == 'era') expect(g.year, greaterThan(1600));
    }
  });

  group('道と死に方（最期1000本の分け目）', () {
    test('亡くなった人生には、必ず8種のどれかの死に方が付き、10の道のどれかに入る', () {
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed * 7 + 3);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.l.dead != null) {
          expect(kDeathKinds.keys, contains(g.l.deathKind), reason: g.l.dead);
        }
        expect(kWays.keys, contains(lifeWay(g.l)));
        if (g.age < 15) expect(lifeWay(g.l), 'young');
      }
    });

    test('多くの人生を通すと、8種の死に方と、大名・天下人以外の道がどれも現れる', () {
      final kinds = <String>{}, ways = <String>{};
      final wantWays = kWays.keys.where((k) => k != 'tenka' && k != 'daimyo');
      // 暗殺はランダムな選択では600人生に1回ほどと稀なので、そろうまで（5000人生まで）流す
      // （1500人生で切ると、岐路が増えて乱数の流れが変わるたびに出たり出なかったりした）。
      for (var seed = 0; seed < 5000; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed + 1));
        if (g.l.deathKind != null) kinds.add(g.l.deathKind!);
        ways.add(lifeWay(g.l));
        if (seed >= 1500 &&
            kinds.containsAll(kDeathKinds.keys) &&
            ways.containsAll(wantWays)) {
          break;
        }
      }
      expect(kinds, containsAll(kDeathKinds.keys));
      expect(ways, containsAll(wantWays));
    });

    test('世の動きは史実の年表に沿う（主家を自分が継いでいなければ）', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        // 歴史が変わった世では年表も変わる（明智の世では北条が残る、など）。
        if (g.isChild || worldLine(g) != 'real') continue;
        final y = g.year;
        bool alive(String n) => g.fa[n]!.alive;
        bool ruled(String n) => g.l.lord == n && g.l.maxRank >= 8;
        if (y > 1569 && !ruled('斎藤')) expect(alive('斎藤'), isFalse);
        if (y > 1583 && !ruled('武田') && !g.hasFlag('history_nagashino')) {
          expect(alive('武田'), isFalse);
        }
        if (y > 1591 && !ruled('北条') && !g.hasFlag('history_odawara')) {
          expect(alive('北条'), isFalse);
        }
        if (y > 1568 && y < 1600 && g.l.maxRank < 8) {
          expect(alive('織田'), isTrue, reason: '$y');
        }
        checked++;
      }
      expect(checked, greaterThan(100));
    });

    test('世界線の出し分けの表に書いた岐路・出来事は、すべて実在する', () {
      final g = Game();
      final ids = {
        for (final s in [...g.childScenes, ...g.adultScenes]) s.id,
      };
      for (final id in skipTableIds()) {
        expect(ids, contains(id), reason: id);
      }
      final ev = {for (final e in kHistory) e.id};
      for (final id in skipEventIds()) {
        expect(ev, contains(id), reason: id);
      }
    });

    test('歴史が変わった世では、その世に合わない史実は起きず、その世だけの出来事が起きる', () {
      const cases = {
        'history_okehazama': ('imagawa', 1569, 'x_imagawa_jouraku'),
        'history_honnoji': ('nobunaga', 1585, 'x_osaka_nobunaga'),
        'history_yamazaki': ('akechi', 1584, 'x_akechi_rule'),
      };
      cases.forEach((flag, c) {
        final (line, byYear, altEvent) = c;
        var reached = 0;
        for (var seed = 0; seed < 300; seed++) {
          final rng = Rng(seed);
          final g = Game(rng: rng);
          g.start(rollBirth(rng));
          if (g.finished) continue;
          g.setFlag(flag);
          expect(worldLine(g), line);
          playOut(g, Rng(seed));
          // 無作為に選ぶうちに、別の分岐点でも歴史を変えて別の世へ移った人生は数えない。
          if (worldLine(g) != line) continue;
          for (final id in kSkipScenes[line]!) {
            expect(g.hasFlag('scene:$id'), isFalse, reason: '$line で $id が出た');
          }
          if (g.year > byYear && !g.isChild) {
            reached++;
            expect(g.hasFlag('h:$altEvent'), isTrue, reason: '$line $altEvent');
          }
        }
        expect(reached, greaterThan(10), reason: line);
      });
      // 今川の世では、織田は1561年に滅ぶ（自分が織田の当主でなければ）。
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_okehazama');
        playOut(g, Rng(seed));
        if (g.year > 1562 && !g.isChild && g.l.maxRank < 8) {
          expect(g.fa['織田']!.alive, isFalse);
        }
      }
    });

    test('城主・家老・大名の人生も最後まで進み、岐路は匂わせだけで数字を出さない', () {
      var lordScenes = 0;
      for (final rank in [6, 8]) {
        for (var seed = 0; seed < 150; seed++) {
          final rng = Rng(seed * 13 + rank);
          final g = Game(rng: rng);
          g.start(rollBirth(rng));
          playChildhood(g, Rng(seed));
          if (g.finished) continue;
          final home = g.fa[g.l.home]!.alive ? g.l.home : g.alive.first.name;
          g.l
            ..rank = rank
            ..maxRank = rank
            ..lord = home
            ..fav = 50
            ..troops = 40
            ..gold = 80;
          playOut(
            g,
            Rng(seed + 1),
            onPrompt: (p) {
              if (p.title == '元服' || p.title == '裳着') return;
              for (final c in p.choices) {
                expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
                expect(c.hint!, isNot(contains('%')), reason: p.title);
                expect(c.hint!, isNot(contains('成功率')), reason: p.title);
              }
            },
          );
          lordScenes += g.l.flags.where((f) => f.startsWith('scene:l_')).length;
        }
      }
      expect(lordScenes, greaterThan(100));
    });

    test('どの人生にも結末（称号・最期の文・選んだ道3〜4行）が付き、共有の文に載る', () {
      final titles = <String>{};
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed + 31);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final e = buildEnding(g);
        titles.add(e.title);
        expect(e.title, isNotEmpty);
        expect(e.text, isNot(contains('null')), reason: e.text);
        expect(e.title, isNot(contains('null')));
        expect(e.highlights.length, lessThanOrEqualTo(4));
        if (g.l.path.isNotEmpty) expect(e.highlights, isNotEmpty);
        for (final h in e.highlights) {
          expect(g.l.path, contains(h));
        }
        final s = shareText(g, e);
        expect(s, contains(e.title));
        expect(s, contains('分の1'));
        if (e.tier != null && e.tier != Tier.common) {
          expect(s, contains(e.tierName!));
        } else {
          expect(s, isNot(contains('最期 ―')));
        }
      }
      // 道 × 死に方 × 幸福で、称号はばらける。
      expect(titles.length, greaterThan(40));
    });

    test('連れ合いのいる人生では、最期の文に連れ合いが出る', () {
      var checked = 0;
      for (var seed = 0; seed < 400 && checked < 20; seed++) {
        final rng = Rng(seed + 77);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final sp = g.l.people['伴侶'];
        if (sp == null || !g.l.married || g.age < 15) continue;
        checked++;
        final e = buildEnding(g);
        if (e.handId != null) continue; // 手書きの最期は、それぞれの文で書く
        expect(e.text, contains(sp.name));
      }
      expect(checked, greaterThan(5));
    });

    test('再開すると前回までのあらすじが出て、章の区切りは一度だけ見聞録に残る', () {
      var resumed = 0, chapters = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 5);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        // 途中（31歳を過ぎた年の始まり）まで進める。
        var n = 0;
        while (!g.finished && n++ < 2000) {
          if (g.age >= 31 && g.prompt?.title == '今年の重点') break;
          g.choose(Rng(seed + n).range(0, g.prompt!.choices.length - 1));
        }
        if (g.finished) continue;
        resumed++;
        final heads = g.l.log.where((e) => e.txt.startsWith('【壮年の章】')).length;
        expect(heads, 1);
        chapters += heads;
        final (life, world) = fromJson(jsonOf(g));
        final g2 = Game(rng: Rng(seed));
        g2.restore(life, world);
        expect(g2.prompt?.title, '今年の重点');
        expect(g2.lastResults.first.txt, contains('前回までのあらすじ'));
        // あらすじは見聞録には残らず、章の区切りも増えない。
        expect(g2.l.log.where((e) => e.txt.contains('あらすじ')), isEmpty);
        expect(g2.l.log.where((e) => e.txt.startsWith('【壮年の章】')).length, 1);
      }
      expect(resumed, greaterThan(10));
      expect(chapters, resumed);
    });

    test('大きな出来事のあった人生では、最期の文に「思えば、〜こともあった。」が入る', () {
      var checked = 0;
      for (var seed = 0; seed < 400 && checked < 30; seed++) {
        final rng = Rng(seed + 4242);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        var n = 0;
        while (!g.finished && n++ < 3000) {
          g.choose(pickAmbitious(g, g.prompt!, r));
        }
        if (g.age < 15) continue;
        final heavy = g.l.path
            .take(g.l.path.length - 1)
            .any((p) => RegExp('信長|秀吉|家康|本能寺|桶狭間|城主|大名|家老').hasMatch(p));
        if (!heavy) continue;
        checked++;
        final e0 = buildEnding(g);
        if (e0.handId != null) continue; // 手書きの最期は、それぞれの文で書く
        final t = e0.text;
        expect(t, contains('思えば、'), reason: t);
        expect(t, contains('こともあった。'));
      }
      expect(checked, greaterThan(5));
    });

    test('乱世を生き抜いた人生の最期の文には、新しい世の迎え方の結びが入る', () {
      var checked = 0;
      for (var seed = 0; seed < 600 && checked < 20; seed++) {
        final rng = Rng(seed + 5);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.l.end != 'era') continue;
        checked++;
        final e0 = buildEnding(g);
        if (e0.handId != null) continue; // 手書きの最期は、それぞれの文で書く
        final t = e0.text;
        expect(t, matches(RegExp('世を迎えた|世の始まりに立った|胸を躍らせた')), reason: t);
        expect(t, isNot(contains('null')));
      }
      expect(checked, greaterThan(5));
    });

    test('連れ合いを亡くした人の最期の文に、亡き連れ合いは最期の場の人として出ない', () {
      var checked = 0;
      for (var seed = 0; seed < 400 && checked < 20; seed++) {
        final rng = Rng(seed + 11);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.age < 15) continue;
        // 夫婦だった相手を亡くした形にする。
        g.meet('伴侶', '亡き連れ合い', 99);
        g.l.married = false;
        checked++;
        final t = buildEnding(g).text;
        expect(t, isNot(contains('亡き連れ合いが')), reason: t);
        expect(t, isNot(contains('聞いた亡き連れ合い')), reason: t);
      }
      expect(checked, greaterThan(5));
    });

    test('亡くなった有名人（本能寺のあとの信長など）は、最期の場の人として出ない', () {
      var checked = 0;
      for (var seed = 0; seed < 600 && checked < 15; seed++) {
        final rng = Rng(seed + 13);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        if (g.age < 15 || g.year <= 1582 || worldLine(g) == 'nobunaga') {
          continue;
        }
        g.l.married = false;
        g.l.people
          ..clear()
          ..['主君'] = Person('主君', '織田信長', 99);
        checked++;
        expect(buildEnding(g).text, isNot(contains('織田信長が')));
        expect(buildEnding(g).text, isNot(contains('聞いた織田信長')));
      }
      expect(checked, greaterThan(5));
    });

    test('有名人が亡くなっているかは、世界線に合わせて決まる', () {
      final rng = Rng(1);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      g.l.t = (1590 - g.l.startYear) * 2; // 1590年にする
      expect(g.year, 1590);
      expect(personDied(g, '織田信長'), isTrue);
      expect(personDied(g, '羽柴秀吉'), isFalse);
      expect(personDied(g, '徳川家康'), isFalse); // 表にない人は亡くならない扱い
      g.setFlag('history_honnoji');
      expect(personDied(g, '織田信長'), isFalse); // 信長が生き延びた世
    });

    test('手書きの最期: 幼くして亡くなる人生には必ず付き、差し込みが残らず、いろいろな最期が出る', () {
      final ids = kHandEndings.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: '最期の id が重複している');
      final seen = <String>{};
      var young = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final rng = Rng(seed + 400);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final e = buildEnding(g);
        if (kHandWays.contains(e.way)) {
          expect(
            e.handId,
            isNotNull,
            reason: '${e.way} ${e.kind} ${g.age}歳 ${g.l.dead}',
          );
          expect(e.tier, isNotNull);
          expect(e.text, isNot(contains('{')), reason: e.text);
          expect(e.text, isNot(contains('null')), reason: e.text);
        }
        if (g.age >= 15) continue;
        young++;
        expect(e.key, startsWith('hand:y_'));
        seen.add(e.handId!);
      }
      expect(young, greaterThan(300));
      expect(seen.length, greaterThanOrEqualTo(15), reason: '$seen');
    });

    test('手書きの最期: 村・商い・仏門・忍びの道の人生にも必ず付き、道ごとにいろいろな最期が出る', () {
      final seen = <String, Set<String>>{};
      // 道に入りやすい選び方も混ぜる（仕官せず働く／商いの誘いに乗る／出家する／野に出る）。
      for (var seed = 0; seed < 3000; seed++) {
        final rng = Rng(seed + 9100);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        final lean = seed % 4;
        var n = 0;
        while (!g.finished && n++ < 3000) {
          final p = g.prompt!;
          var i = -1;
          const pref = [
            ['働いて稼ぐ', '人の倍の田を植える'],
            ['店を構える', '商いを広げる'],
            ['髪を下ろす', '出家して仏門に入る', '修行に打ち込む'],
            ['仲間に加わる', 'あてのない旅に出る', '獲物を狙う'],
          ];
          for (final w in pref[lean]) {
            final k = p.choices.indexWhere((c) => c.label == w);
            if (k >= 0) i = k;
          }
          if (i < 0) i = r.range(0, p.choices.length - 1);
          g.choose(i);
        }
        if (g.age < 15) continue;
        final e = buildEnding(g);
        if (!kHandWays.contains(e.way)) continue;
        expect(e.handId, isNotNull, reason: '${e.way} ${e.kind} ${g.l.dead}');
        expect(e.text, isNot(contains('{')), reason: e.text);
        seen.putIfAbsent(e.way, () => {}).add(e.handId!);
      }
      for (final w in [
        'village',
        'merchant',
        'priest',
        'shadow',
        'samurai',
        'woman',
      ]) {
        expect(
          seen[w]?.length ?? 0,
          greaterThanOrEqualTo(8),
          reason: '$w ${seen[w]}',
        );
      }
      final ids = kHandEndings.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('手書きの最期: 10の道すべてで、どの人生にも手書きの最期が付く（城主・大名・天下人は身分を強制して確かめる）', () {
      expect(kHandEndings.length, greaterThanOrEqualTo(1000));
      for (final rank in [6, 8]) {
        final seen = <String>{};
        for (var seed = 0; seed < 150; seed++) {
          final rng = Rng(seed * 17 + rank);
          final g = Game(rng: rng);
          g.start(rollBirth(rng));
          playChildhood(g, Rng(seed));
          if (g.finished || g.l.female) continue;
          g.l
            ..rank = rank
            ..maxRank = rank
            ..lord = g.alive.first.name
            ..fav = 50
            ..troops = 40;
          playOut(g, Rng(seed + 1));
          final e = buildEnding(g);
          expect(e.handId, isNotNull, reason: '${e.way} ${e.kind} ${g.l.dead}');
          expect(e.text, isNot(contains('{')), reason: e.text);
          seen.add(e.handId!);
        }
        expect(seen.length, greaterThanOrEqualTo(8), reason: '位$rank $seen');
      }
      // 天下人: 天下統一した人生
      final g = Game(rng: Rng(1));
      g.start(rollBirth(Rng(2)));
      playChildhood(g, Rng(3));
      if (!g.finished) {
        g.l
          ..rank = 9
          ..maxRank = 9
          ..victory = true
          ..end = 'victory';
        final e = buildEnding(g);
        expect(e.way, 'tenka');
        expect(e.handId, isNotNull);
        expect(e.handId, startsWith('t_'));
      }
    });

    test('選んだ道の抜き出しは、初めと終わりを残し、順番を崩さない', () {
      final path = [for (var i = 0; i < 12; i++) '$i歳　出来事$i'];
      path[6] = '20歳　信長に仕えた';
      final h = pickHighlights(path);
      expect(h.length, 4);
      expect(h.first, path.first);
      expect(h.last, path.last);
      expect(h, contains('20歳　信長に仕えた'));
      expect(pickHighlights(path.take(3).toList()), path.take(3).toList());
    });

    test('考えて選べば出世できる（城主以上に届く人生があり、女性も奥で位を上げられる）', () {
      var adults = 0, castle = 0, women = 0, womenUp = 0;
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed + 4242);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        var n = 0;
        while (!g.finished && n++ < 3000) {
          g.choose(pickAmbitious(g, g.prompt!, r));
        }
        if (g.age < 15) continue;
        adults++;
        if (g.l.maxRank >= 5) castle++;
        if (g.l.female && g.l.maxRank >= 1 && !g.has('onna')) {
          women++;
          if (g.l.maxRank >= 3) womenUp++;
        }
      }
      expect(castle / adults, greaterThan(.1), reason: '城主以上 $castle/$adults');
      expect(women, greaterThan(20));
      expect(womenUp / women, greaterThan(.3), reason: '女性の昇進 $womenUp/$women');
    });

    test('明智の世では、1582年のあとに明智家が勢力として立ち、光秀に味方した人は明智家に仕える', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_yamazaki');
        playOut(g, Rng(seed));
        if (g.year <= 1583 || g.isChild) continue;
        // 別の分岐点（桶狭間など）でも歴史を変えて、別の世へ移った人生は数えない。
        if (worldLine(g) != 'akechi') continue;
        checked++;
        expect(g.fa['明智'], isNotNull, reason: '${g.year}');
        // 光秀に味方した織田の家臣は、明智家に移り主君が光秀になる。
        // （仕官や徴募で明智家に入っただけの人は、光秀との縁がないので主君の登録はない）
        if (g.hasFlag('akechi_retainer') && g.l.lord == '明智') {
          expect(g.l.people['主君']?.name, '明智光秀');
        }
      }
      expect(checked, greaterThan(10));
    });

    test('町人として桶狭間で歴史を変えた人には、義元からの礼の場面が来る', () {
      var shown = 0;
      for (var seed = 0; seed < 600 && shown < 3; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        final b = rollBirth(rng);
        if (b.startYear > 1545) continue;
        g.start(b);
        if (g.finished) continue;
        g
          ..setFlag('history_okehazama')
          ..setFlag('scene:h_x_okehazama_warn');
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (p.title == '義元の使い') shown++;
          },
        );
      }
      expect(shown, greaterThan(0));
    });

    test('奥で仕える女性には、若侍の失態・老臣の諫言（侍の家の当主の場面）が出ない', () {
      for (var seed = 0; seed < 150; seed++) {
        final rng = Rng(seed * 7 + 1);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished || !g.l.female || g.has('onna')) continue;
        g.l
          ..rank = 6
          ..maxRank = 6
          ..lord = g.alive.first.name
          ..fav = 50;
        playOut(g, Rng(seed + 1));
        expect(g.hasFlag('scene:l_young_blunder'), isFalse);
        expect(g.hasFlag('scene:l_elder_advice'), isFalse);
      }
    });

    test('前に選んだことが、何年もあとに返ってくる（伏線の回収の岐路が出る）', () {
      const flags = [
        'hid_oda_heir',
        'iga_goe',
        'hid_sword',
        'hid_gracia_maids',
        'reformed',
        'assassin',
        'friend_ally',
        'hostage',
        'saw_namban',
        'craftsman',
        'new_field',
        'shoya',
        'saw_battle',
        'family_head',
        'silent_hero',
      ];
      final seen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 900);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        for (final f in flags) {
          g.setFlag(f);
        }
        g.meet('幼なじみ', '与一', 60);
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (p.title == '元服' || p.title == '裳着') return;
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
            }
          },
        );
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:e_'))
              .map((f) => f.substring(6)),
        );
      }
      expect(seen.length, greaterThanOrEqualTo(12), reason: '$seen');
    });

    test('能力・暮らしと嗜み・寺の手習いの旗や縁が、何年もあとに返ってくる（伏線の回収 その2）', () {
      const flags = [
        'tera_friends',
        'tera_diligent',
        'ps_renga_praised',
        'ps_renga_report',
        'ps_onsen_friend',
        'ps_meibutsu',
        'ps_book_med',
        'ps_book_war',
        'ps_field_border',
        'ps_kid_tera',
        'ps_hawk_kind',
        'tal_left_lord',
        'tal_tenka_ichi',
        'tal_ikki_head',
        'tal_taught_youth',
      ];
      final digits = RegExp(r'[0-9０-９%]');
      final seen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 5200);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        for (final f in flags) {
          g.setFlag(f);
        }
        g.meet('師', '手習いの和尚', 50);
        g.meet('連歌の友', '旅の連歌師', 40);
        g.meet('湯治場の縁', '湯治場で会った隠居', 40);
        // 三人に一人は主家に仕える身にして、家中の岐路も見る。
        if (seed % 3 == 0 && g.l.rank == 0 && !g.hasFlag('priesthood')) {
          g.l
            ..rank = 3
            ..maxRank = 3
            ..lord = g.alive.first.name
            ..fav = 40;
        }
        var count = g.l.flags.where((f) => f.startsWith('scene:e2_')).length;
        playOut(
          g,
          Rng(seed + 1),
          onPrompt: (p) {
            final now = g.l.flags.where((f) => f.startsWith('scene:e2_')).length;
            if (now == count) return;
            count = now;
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
              expect(c.hint!, isNot(contains(digits)), reason: '${p.title}/${c.hint}');
              expect(c.label, isNot(contains(digits)), reason: '${p.title}/${c.label}');
            }
          },
        );
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:e2_'))
              .map((f) => f.substring(6)),
        );
      }
      // 16 のうち 10 以上。
      expect(seen.length, greaterThanOrEqualTo(10), reason: '$seen');
    });

    test('能力の岐路と願掛けの旗が、何年もあとに返ってくる（伏線の回収 その3）', () {
      const flags = [
        'tal_karo_grudge',
        'tal_envied',
        'tal_favorite',
        'tal_gamble_debt',
        'tal_wrote_book',
        'tal_exposed_fraud',
        'tal_bribe',
        'tal_kenchi',
        'tal_fushin',
        'tal_beloved_captain',
        'tal_followers',
        'tal_night_raid',
        'tal_alliance',
        'tal_machiwari',
        'tal_shinan',
        'tal_c_sumo_win',
        'tal_c_white_deer',
        'tal_c_horse',
        'ps_wish_home',
      ];
      final digits = RegExp(r'[0-9０-９%]');
      final seen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 7300);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        for (final f in flags) {
          g.setFlag(f);
        }
        // 二人に一人は主家に仕える身にして、家中の岐路も見る（出城の縄張りをした侍として）。
        if (seed.isEven && g.l.rank == 0 && !g.hasFlag('priesthood')) {
          g.l
            ..rank = 3
            ..maxRank = 3
            ..lord = g.alive.first.name
            ..fav = 40;
          g.mark('出城の縄張りを任され、守りの堅い城を築いた');
        }
        var count = g.l.flags.where((f) => f.startsWith('scene:e3_')).length;
        playOut(
          g,
          Rng(seed + 1),
          onPrompt: (p) {
            final now = g.l.flags.where((f) => f.startsWith('scene:e3_')).length;
            if (now == count) return;
            count = now;
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
              expect(c.hint!, isNot(contains(digits)), reason: '${p.title}/${c.hint}');
              expect(c.label, isNot(contains(digits)), reason: '${p.title}/${c.label}');
            }
          },
        );
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:e3_'))
              .map((f) => f.substring(6)),
        );
      }
      // 19 のうち 12 以上。
      expect(seen.length, greaterThanOrEqualTo(12), reason: '$seen');
    });

    test('長篠で武田が兵を退いた人生では、1582年に武田が滅ばず、武田の滅亡にまつわる岐路も出ない', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_nagashino');
        playOut(g, Rng(seed));
        for (final id in kFlagSkipScenes['history_nagashino']!) {
          expect(g.hasFlag('scene:$id'), isFalse, reason: id);
        }
        if (g.year > 1583 &&
            !g.isChild &&
            g.l.maxRank < 8 &&
            worldLine(g) == 'real') {
          checked++;
          expect(g.fa['武田']!.alive, isTrue, reason: '${g.year}');
        }
      }
      expect(checked, greaterThan(10));
    });

    test('小田原で北条が早く降った人生では、1590年のあとも北条が残り、家康の関東移封が起きない', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_odawara');
        playOut(g, Rng(seed));
        expect(g.hasFlag('scene:h_e_edo'), isFalse);
        if (g.year > 1591 &&
            !g.isChild &&
            g.l.maxRank < 8 &&
            worldLine(g) == 'real') {
          checked++;
          expect(g.fa['北条']!.alive, isTrue, reason: '${g.year}');
          expect(
            g.hasFlag('h:edo') && g.l.log.any((e) => e.txt.contains('江戸に入った')),
            isFalse,
          );
        }
      }
      expect(checked, greaterThan(5));
    });

    test('変えた歴史（世界線と小さな分岐）が、今の世と最期の文にまとめて出る', () {
      for (var seed = 0; seed < 100; seed++) {
        final rng = Rng(seed + 8);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g
          ..setFlag('history_nagashino')
          ..setFlag('history_odawara');
        expect(changedHistory(g), ['長篠で武田の騎馬が崩れなかった', '小田原で北条の家が残った']);
        playOut(g, Rng(seed));
        if (g.age < 15) continue;
        final t = buildEnding(g).text;
        expect(t, contains('その世は、長篠で武田の騎馬が崩れなかった、小田原で北条の家が残った世だった。'));
        return;
      }
      fail('成人した人生が見つからない');
    });

    test('川中島で信玄が討たれた人生では、三方ヶ原や信玄の陣没が起きない', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.setFlag('history_kawanakajima');
        playOut(g, Rng(seed));
        // 別の分岐点でも歴史を変えて、別の世（今川の世など）へ移った人生は数えない。
        if (worldLine(g) != 'real') continue;
        for (final id in kFlagSkipScenes['history_kawanakajima']!) {
          expect(g.hasFlag('scene:$id'), isFalse, reason: id);
        }
        expect(g.l.log.any((e) => e.txt.contains('武田信玄が陣中で没した')), isFalse);
      }
    });

    test('死に方は保存の往復で残る', () {
      for (var seed = 0; seed < 40; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(g, Rng(seed));
        final (back, _) = fromJson(jsonOf(g));
        expect(back.deathKind, g.l.deathKind);
      }
    });

    test('史実の岐路（桶狭間・本能寺・長篠・関ヶ原ほか）は、その年にだけ起きる', () {
      const years = {
        '桶狭間': 1560,
        '本能寺': 1582,
        '比叡山': 1571,
        '川中島': 1561,
        '姉川': 1570,
        '三方ヶ原': 1572,
        '長篠': 1575,
        '山崎': 1582,
        '賤ヶ岳': 1583,
        '小田原評定': 1590,
        '関ヶ原': 1600,
      };
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            final y = years[p.title];
            if (y != null) expect(g.year, y, reason: p.title);
          },
        );
      }
    });
  });

  group('能力で起きる岐路', () {
    final digits = RegExp(r'[0-9０-９%]');

    /// 新しく出た能力の岐路の選択肢に、匂わせがあり数字が無いことを確かめる。
    void Function(Prompt p) hintCheck(Game g, Set<String> seenNow) {
      seenNow.addAll(g.l.flags.where((f) => f.startsWith('scene:tal_')));
      return (p) {
        final now = g.l.flags.where((f) => f.startsWith('scene:tal_')).toSet();
        if (now.length == seenNow.length) return;
        seenNow
          ..clear()
          ..addAll(now);
        for (final c in p.choices) {
          expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
          expect(
            c.hint!,
            isNot(contains(digits)),
            reason: '${p.title}/${c.hint}',
          );
          expect(
            c.label,
            isNot(contains(digits)),
            reason: '${p.title}/${c.label}',
          );
        }
      };
    }

    test('能力の高い大人には、能力の岐路がいろいろ出て、匂わせがあり数字が無い', () {
      final seen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 4400);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.l
          ..bu = 95
          ..chi = 95
          ..sei = 95
          ..mi = 95
          ..un = 95;
        // 半分は主家に仕える身にして、家中の岐路も見る。
        if (seed.isEven && g.l.rank == 0 && !g.hasFlag('priesthood')) {
          g.l
            ..rank = 2
            ..maxRank = 2
            ..lord = g.alive.first.name
            ..fav = 30;
        }
        final mine = <String>{};
        playOut(g, Rng(seed + 1), onPrompt: hintCheck(g, mine));
        seen.addAll(
          g.l.flags
              .where(
                (f) =>
                    f.startsWith('scene:tal_') && !f.startsWith('scene:tal_c_'),
              )
              .map((f) => f.substring(6)),
        );
      }
      expect(seen.length, greaterThanOrEqualTo(16), reason: '$seen');
    });

    test('能力の低い大人には、低い能力の岐路（陣触れ・証文・厄）が出る', () {
      final seen = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 4700);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.l
          ..bu = 10
          ..chi = 10
          ..un = 10;
        final mine = <String>{};
        playOut(g, Rng(seed + 1), onPrompt: hintCheck(g, mine));
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:tal_low_'))
              .map((f) => f.substring(6)),
        );
      }
      expect(seen.length, greaterThanOrEqualTo(2), reason: '$seen');
    });

    test('才のある子には、幼少期の能力の岐路が出る', () {
      final seen = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 4900);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        g.l
          ..bu = 70
          ..chi = 70
          ..sei = 70
          ..mi = 70
          ..un = 70;
        final mine = <String>{};
        playChildhood(g, Rng(seed), onPrompt: hintCheck(g, mine));
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:tal_c_'))
              .map((f) => f.substring(6)),
        );
      }
      expect(seen.length, greaterThanOrEqualTo(5), reason: '$seen');
    });

    test('能力が段（60・75・90）を越えた一言は、同じ段で二度出ない', () {
      int lines(Game g) => g.l.log.where((e) => e.txt.startsWith('【才】')).length;
      final g = startSurvivor(12);
      expect(g.finished, isFalse);
      g.l
        ..bu = 10
        ..chi = 10
        ..sei = 10
        ..mi = 10
        ..un = 10;
      final n0 = lines(g);
      g.l.bu = 95;
      talentMilestones(g);
      expect(lines(g), n0 + 1, reason: '一度に三つの段を越えても、一行だけ');
      talentMilestones(g);
      expect(lines(g), n0 + 1);
      g.l.bu = 40;
      talentMilestones(g);
      g.l.bu = 95;
      talentMilestones(g);
      expect(lines(g), n0 + 1, reason: '下がってまた越えても、二度は出ない');
      g.l.chi = 65;
      talentMilestones(g);
      g.l.chi = 80;
      talentMilestones(g);
      g.l.chi = 92;
      talentMilestones(g);
      expect(lines(g), n0 + 4, reason: '段ごとに一行ずつ');
      for (final s in ['chi']) {
        for (final t in [60, 75, 90]) {
          expect(g.hasFlag('talent:$s:$t'), isTrue);
        }
      }

      // 一生を通しても、同じ一行は二度出ず、段の数（5×3）を超えない。
      for (var seed = 0; seed < 60; seed++) {
        final rng = Rng(seed + 5100);
        final h = Game(rng: rng);
        h.start(rollBirth(rng));
        playOut(
          h,
          Rng(seed),
          onPrompt: (p) {
            if (h.isChild || h.age % 5 != 0) return;
            h.l
              ..bu = clampInt(h.l.bu + 8, 0, 99)
              ..chi = clampInt(h.l.chi + 8, 0, 99);
          },
        );
        final got = h.l.log
            .where((e) => e.txt.startsWith('【才】'))
            .map((e) => e.txt)
            .toList();
        expect(got.length, lessThanOrEqualTo(15));
        expect(got.toSet().length, got.length, reason: '$got');
      }
    });
  });

  group('大人の重点の選択肢（暮らしと嗜み）', () {
    final digits = RegExp(r'[0-9０-９%]');
    // 重点の名 → (tag, はじめて選んだ年の岐路の題)
    const labels = <String, (String, Set<String>)>{
      '寺社に参り、願をかける': ('ps_shrine', {'願掛け'}),
      '茶の湯を学ぶ': ('ps_tea', {'茶の湯の席'}),
      '連歌の会に出る': ('ps_renga', {'連歌の会'}),
      '鷹狩りに出る': ('ps_hawk', {'鷹狩り'}),
      '主君の鷹狩りの供をする': ('ps_hawk', {'鷹狩り'}),
      '湯治に行く': ('ps_onsen', {'湯治場'}),
      '槍の稽古に励む': ('ps_arms', {'槍合わせ'}),
      '弓・馬の稽古に励む': ('ps_arms', {'弓始め'}),
      '網を繕い、沖へ出る': ('ps_land', {'網と沖'}),
      '荒れ野を拓いて田を広げる': ('ps_land', {'荒れ野を拓く'}),
      '子に手習いをさせる': ('ps_kid', {'子の手習い'}),
      '奥の務めの合間に、琴や香を学ぶ': ('ps_koto', {'琴と香'}),
      '書物を写す': ('ps_book', {'写本'}),
      '経や書物を写す': ('ps_book', {'写本'}),
    };
    const titles = {
      '願掛け', '参詣', '茶の湯の席', '連歌の会', '鷹狩り', '湯治場', '槍合わせ', '弓始め', //
      '稽古場', '網と沖', '沖の群れ', '荒れ野を拓く', '新しい田', '子の手習い', '琴と香', '香合わせ', '写本',
    };

    /// 生まれの身分で大人の年頃の人を作る（重点の出し分けを見るだけなので、遊ばずに歳と身分を置く）。
    Game adultOf(String cls, {bool? female, int seedBase = 0}) {
      for (var seed = 0; seed < 20000; seed++) {
        final rng = Rng(seed + seedBase);
        final b = rollBirth(rng);
        if (b.cls.id != cls) continue;
        final g = Game(rng: rng);
        g.start(b);
        if (female != null && g.l.female != female) continue;
        if (g.has('onna')) continue;
        g.l.t = 40 * 2;
        return g;
      }
      fail('$cls の生まれが見つからない');
    }

    test('身分・道ごとに合う重点が出る（商人に茶の湯、百姓に新田、城主に鷹狩り）', () {
      final m = adultOf('merchant');
      expect(pastimeTags(m), contains('ps_tea'));
      expect(pastimeTags(m), isNot(contains('ps_land')));

      final f = adultOf('farmer');
      expect(pastimeTags(f), containsAll(['ps_land', 'ps_shrine', 'ps_onsen']));
      expect(pastimeTags(f), isNot(contains('ps_tea')));
      expect(pastimeTags(f), isNot(contains('ps_hawk')));

      final s = adultOf('farmer', female: false, seedBase: 1);
      s.l
        ..rank = 5
        ..maxRank = 5
        ..lord = s.alive.first.name;
      expect(pastimeTags(s), containsAll(['ps_hawk', 'ps_arms', 'ps_tea']));
      expect(pastimeTags(s), isNot(contains('ps_land')));

      // 仏門の人に鷹狩り・寺社参り・茶の湯は出ない。
      final p = adultOf('priest', female: false);
      p.setFlag('priesthood');
      p.l.chi = 70;
      expect(pastimeTags(p), containsAll(['ps_renga', 'ps_book']));
      expect(pastimeTags(p), isNot(contains('ps_hawk')));
      expect(pastimeTags(p), isNot(contains('ps_shrine')));

      // 奥で仕える女性（戦えない）には琴と香。稽古・鷹狩りは出ない。
      final w = adultOf('farmer', female: true, seedBase: 2);
      w.l
        ..rank = 5
        ..maxRank = 5
        ..lord = w.alive.first.name;
      expect(w.canFight, isFalse);
      expect(pastimeTags(w), contains('ps_koto'));
      expect(pastimeTags(w), isNot(contains('ps_arms')));
      expect(pastimeTags(w), isNot(contains('ps_hawk')));

      // 子のいる人には子の手習い。若い人に湯治は出ない。
      f.l.kids = 2;
      expect(pastimeTags(f), contains('ps_kid'));
      f.l.t = 20 * 2;
      expect(pastimeTags(f), isNot(contains('ps_onsen')));
    });

    test('選んだ年にその岐路が起き、1年に足す重点は上限まで、匂わせがあり数字が無い', () {
      final firsts = <String>{};
      final again = <String>{};
      var capped = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 6100);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        g.choose(0); // 元服・裳着
        if (g.finished) continue;
        g.l.chi = 60;
        // 身分を散らして、いろいろな重点を見る。
        if (seed % 3 == 1 && g.l.rank == 0 && !g.hasFlag('priesthood')) {
          g.l
            ..rank = seed % 2 == 0 ? 5 : 2
            ..maxRank = 5
            ..lord = g.alive.first.name
            ..fav = 30;
        }
        if (seed % 4 == 0) g.l.kids = 1;
        final r = Rng(seed + 1);
        var n = 0;
        String? expectTitle;
        Set<String>? expectTitles;
        // 元服の直後の重点は、上で身分を置き直す前に作られているので、数の突き合わせから外す。
        var fresh = true;
        while (!g.finished && n++ < 3000) {
          final p = g.prompt!;
          if (expectTitles != null) {
            expect(
              p.title,
              isIn(expectTitles),
              reason: 'seed=$seed $expectTitle',
            );
            expectTitles = null;
          }
          if (titles.contains(p.title)) {
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
              expect(
                c.hint!,
                isNot(contains(digits)),
                reason: '${p.title}/${c.hint}',
              );
              expect(
                c.label,
                isNot(contains(digits)),
                reason: '${p.title}/${c.label}',
              );
            }
          }
          if (p.title == '今年の重点' && !g.isChild) {
            final mine = [
              for (var i = 0; i < p.choices.length; i++)
                if (labels.containsKey(p.choices[i].label)) i,
            ];
            final tags = pastimeTags(g);
            expect(mine.length, lessThanOrEqualTo(kPastimesPerYear));
            if (!fresh) {
              expect(
                mine.length,
                tags.length < kPastimesPerYear ? tags.length : kPastimesPerYear,
                reason: 'seed=$seed $tags',
              );
              if (tags.length > kPastimesPerYear) capped++;
            }
            fresh = false;
            for (final i in mine) {
              final c = p.choices[i];
              expect(c.hint, isNotNull);
              expect(c.hint!, isNot(contains(digits)), reason: c.hint);
              expect(c.label, isNot(contains(digits)), reason: c.label);
            }
            if (mine.isNotEmpty && r.chance(.7)) {
              final i = mine[r.range(0, mine.length - 1)];
              final (tag, first) = labels[p.choices[i].label]!;
              if (!g.hasFlag('scene:$tag')) {
                expectTitle = p.choices[i].label;
                expectTitles = first;
                firsts.add(tag);
              }
              g.choose(i);
              continue;
            }
          }
          g.choose(r.range(0, p.choices.length - 1));
        }
        again.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:ps_') && f.endsWith('_again'))
              .map((f) => f.substring(6)),
        );
      }
      expect(firsts.length, greaterThanOrEqualTo(8), reason: '$firsts');
      expect(again.length, greaterThanOrEqualTo(5), reason: '$again');
      expect(capped, greaterThan(0));
    });
  });

  group('子と家族の岐路', () {
    // 子がいないと出ない岐路（養子・子を亡くした悲しみ・連れ合いの岐路を除く）。
    const kidScenes = {
      'fa_genpuku',
      'fa_mogi',
      'fa_uijin',
      'fa_kokorozashi',
      'fa_yome',
      'fa_sick',
      'fa_hoto',
      'fa_shuppon',
      'fa_atome',
      'fa_tameshi',
      'fa_mago',
      'fa_hitojichi',
      'fa_hitojichi_back',
    };

    /// 成人した人生を、連れ合いと子のいる家にする（五人に一人は子のない夫婦）。
    /// 三人に一人（男）は主家に仕える侍にして、武家の岐路も見る。
    void makeFamily(Game g, int seed) {
      final l = g.l;
      if (seed % 3 == 0 &&
          !l.female &&
          !g.hasFlag('priesthood') &&
          !g.hasFlag('way_outlaw')) {
        l
          ..rank = 3
          ..maxRank = 3
          ..lord = g.alive.first.name
          ..fav = 40;
      }
      l.married = true;
      g.meet('伴侶', l.female ? '中村家の太郎' : '中村家のお福', 60);
      l.kids = seed % 5 == 0 ? 0 : 2 + seed % 2;
      // 子を数えるのは15歳から。家族の岐路は30歳前後から多いので、年を進めておく。
      l.t = 30 * 2;
    }

    test('子のいる大人の人生で、家族の岐路が出る（匂わせがあり、数字が無い）', () {
      final digits = RegExp(r'[0-9０-９%]');
      final seen = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 9100);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        // 大人の年の始まり（今年の重点）で、家族を持たせる。
        if (g.prompt?.title != '今年の重点') {
          g.choose(0);
          if (g.finished || g.prompt?.title != '今年の重点') continue;
        }
        makeFamily(g, seed);
        var count = g.l.flags.where((f) => f.startsWith('scene:fa_')).length;
        playOut(
          g,
          Rng(seed + 1),
          onPrompt: (p) {
            final now = g.l.flags
                .where((f) => f.startsWith('scene:fa_'))
                .length;
            if (now == count) return;
            count = now;
            for (final c in p.choices) {
              expect(
                c.hint,
                isNotNull,
                reason: '${p.title}/${c.label} に匂わせが無い',
              );
              expect(
                c.hint!,
                isNot(contains(digits)),
                reason: '${p.title}/${c.hint}',
              );
              expect(
                c.label,
                isNot(contains(digits)),
                reason: '${p.title}/${c.label}',
              );
            }
          },
        );
        seen.addAll(
          g.l.flags
              .where((f) => f.startsWith('scene:fa_'))
              .map((f) => f.substring(6)),
        );
      }
      // 17 のうち 11 以上。
      expect(seen.length, greaterThanOrEqualTo(11), reason: '$seen');
    });

    test('子のいない人に子の岐路は出ず、僧には家族の岐路が出ない', () {
      var checked = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 9500);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.finished) continue;
        final before = <String>{};
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            final now = g.l.flags
                .where((f) => f.startsWith('scene:fa_'))
                .toSet();
            for (final f in now.difference(before)) {
              final id = f.substring(6);
              checked++;
              expect(g.hasFlag('priesthood'), isFalse, reason: '僧に $id');
              if (kidScenes.contains(id)) {
                expect(g.l.kids, greaterThan(0), reason: '子のいない人に $id');
              }
            }
            before.addAll(now);
          },
        );
      }
      expect(checked, greaterThan(20));
    });

    test('子の生まれた年は保存の往復で残り、古い保存（年が無い）も読める', () {
      final g = startSurvivor(4242);
      g.l
        ..kids = 0
        ..addKid(1550)
        ..addKid(1553);
      final (back, _) = fromJson(jsonOf(g));
      expect(back.kids, 2);
      expect(back.kidYears, [1550, 1553]);
      expect(back.eldestKidAge(1565), 15);
      expect(back.youngestKidAge(1565), 12);
      // 古い保存: kidYears が無い。子は「年の分からない子」になる。
      final m = jsonDecode(jsonOf(g)) as Map<String, dynamic>;
      (m['life'] as Map<String, dynamic>).remove('kidYears');
      final (old, _) = fromJson(jsonEncode(m));
      expect(old.kids, 2);
      expect(old.kidYears, isEmpty);
      expect(old.eldestKidAge(1565), isNull);
      expect(old.hasKidAged(1565, 12, 16), isTrue);
      // 子を亡くすと、その歳の子の年が外れる。
      back.loseKid(1565, 0, 12);
      expect(back.kidYears, [1550]);
      expect(back.kids, 1);
    });

    /// 主家に仕える侍（位3）の男で、連れ合いのいる大人の人生を作る（40歳）。
    Game? bukeFather(int seed) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playChildhood(g, Rng(seed + 1));
      if (g.finished ||
          g.l.female ||
          g.hasFlag('priesthood') ||
          g.hasFlag('way_outlaw') ||
          g.hasFlag('retired') ||
          g.alive.isEmpty) {
        return null;
      }
      g.l
        ..rank = 3
        ..maxRank = 3
        ..lord = g.alive.first.name
        ..fav = 40
        ..married = true
        ..t = 40 * 2;
      g.meet('伴侶', '中村家のお福', 60);
      return g;
    }

    test('いちばん上の子が幼いあいだは、元服・初陣・家督の場面が出ない（子が育つと出る）', () {
      final scenes = {for (final s in buildFamilyScenes()) s.id: s};
      bool ok(Game g, String id) => scenes[id]!.cond(g);
      var checked = 0;
      for (var seed = 0; seed < 40 && checked < 5; seed++) {
        final g = bukeFather(seed + 9900);
        if (g == null) continue;
        checked++;
        final l = g.l;
        final y = g.year;
        void kidsBorn(List<int> ages) {
          l
            ..kids = 0
            ..kidYears.clear();
          for (final a in ages) {
            l.addKid(y - a);
          }
        }

        // 生まれたばかりと二つの子。
        kidsBorn([2, 0]);
        l.people.remove('嫡男');
        expect(ok(g, 'fa_genpuku'), isFalse);
        expect(ok(g, 'fa_mogi'), isFalse);
        expect(ok(g, 'fa_yome'), isFalse);
        expect(ok(g, 'fa_atome'), isFalse);
        expect(ok(g, 'fa_sick'), isTrue);
        g.meet('嫡男', '太郎', 60);
        expect(ok(g, 'fa_uijin'), isFalse);
        expect(ok(g, 'fa_shuppon'), isFalse);
        expect(ok(g, 'fa_tameshi'), isFalse);

        // 十四と十二の子。
        kidsBorn([14, 12]);
        l.people.remove('嫡男');
        expect(ok(g, 'fa_genpuku'), isTrue);
        expect(ok(g, 'fa_mogi'), isTrue);
        expect(ok(g, 'fa_sick'), isTrue);
        g.meet('嫡男', '太郎', 60);
        expect(ok(g, 'fa_uijin'), isTrue);
        expect(ok(g, 'fa_tameshi'), isFalse);
        expect(ok(g, 'fa_atome'), isFalse, reason: '弟がまだ幼い');

        // 二十二と十八の子。
        kidsBorn([22, 18]);
        expect(ok(g, 'fa_genpuku'), isFalse, reason: '嫡男がいる');
        expect(ok(g, 'fa_uijin'), isTrue);
        expect(ok(g, 'fa_shuppon'), isTrue);
        expect(ok(g, 'fa_tameshi'), isTrue);
        expect(ok(g, 'fa_yome'), isTrue);
        expect(ok(g, 'fa_atome'), isTrue);
        expect(ok(g, 'fa_sick'), isFalse, reason: '幼い子がいない');
        l.people.remove('嫡男');
        expect(ok(g, 'fa_genpuku'), isFalse, reason: '元服の歳の子がいない');

        // 古い保存（年の分からない子）は、今までどおり親の歳で見る。
        l
          ..kids = 2
          ..kidYears.clear();
        expect(ok(g, 'fa_genpuku'), isTrue);
        g.meet('嫡男', '太郎', 60);
        expect(ok(g, 'fa_uijin'), isTrue);
        expect(ok(g, 'fa_tameshi'), isTrue);
      }
      expect(checked, greaterThanOrEqualTo(3));
    });

    test('生まれたばかりの子を持たせて生きると、元服・初陣・家督は子が育ってから出る', () {
      final seen = <String>{};
      var lives = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 9700);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        if (g.prompt?.title != '今年の重点') {
          g.choose(0);
          if (g.finished || g.prompt?.title != '今年の重点') continue;
        }
        final l = g.l;
        if (!l.female && !g.hasFlag('priesthood') && !g.hasFlag('way_outlaw')) {
          l
            ..rank = 3
            ..maxRank = 3
            ..lord = g.alive.first.name
            ..fav = 40;
        }
        l
          ..married = true
          ..t = 26 * 2
          ..kids = 0
          ..kidYears.clear();
        g.meet('伴侶', l.female ? '中村家の太郎' : '中村家のお福', 60);
        l
          ..addKid(g.year)
          ..addKid(g.year);
        lives++;
        final before = <String>{};
        playOut(
          g,
          Rng(seed + 1),
          onPrompt: (p) {
            final now = g.l.flags
                .where((f) => f.startsWith('scene:fa_'))
                .toSet();
            for (final f in now.difference(before)) {
              final id = f.substring(6);
              seen.add(id);
              final y = g.year;
              final eldest = g.l.eldestKidAge(y);
              String why() => '$id: 子の歳 ${g.l.kidYears.map((k) => y - k)}';
              switch (id) {
                case 'fa_genpuku' || 'fa_mogi':
                  expect(g.l.hasKidAged(y, 11, 17), isTrue, reason: why());
                case 'fa_uijin':
                  expect(g.l.hasKidAged(y, 13, 20), isTrue, reason: why());
                case 'fa_tameshi':
                  expect(eldest, greaterThanOrEqualTo(20), reason: why());
                case 'fa_mago':
                  expect(eldest, greaterThanOrEqualTo(18), reason: why());
                case 'fa_yome':
                  expect(g.l.hasKidAged(y, 15, 28), isTrue, reason: why());
              }
            }
            before.addAll(now);
          },
        );
      }
      expect(lives, greaterThan(100));
      for (final id in ['fa_genpuku', 'fa_mogi', 'fa_uijin', 'fa_tameshi']) {
        expect(seen, contains(id), reason: '$seen');
      }
    });
  });

  group('国ごとの暮らしの岐路', () {
    /// 生まれを引き、国だけを [region] に置き換える。
    Birth birthIn(Rng rng, String region) {
      final b = rollBirth(rng);
      final reg = kRegions.firstWhere((r) => r.n == region);
      return Birth(
        cls: b.cls,
        region: reg,
        faction: reg.f.first,
        startYear: b.startYear,
        month: b.month,
        day: b.day,
        female: b.female,
        order: b.order,
        stats: b.stats,
        traits: b.traits,
        rarity: b.rarity,
        name: b.name,
        label: b.label,
        sameClass: b.sameClass,
        birthRank: b.birthRank,
      );
    }

    test('22国すべてに国の岐路があり、表の岐路はすべて実在する', () {
      final g = Game();
      final ids = {
        for (final s in [...g.adultScenes, ...g.childScenes]) s.id,
      };
      for (final r in kRegions) {
        expect(
          kRegionScenes.values,
          contains(r.n),
          reason: '${r.n}に国の岐路が無い',
        );
      }
      for (final id in kRegionScenes.keys) {
        expect(id.startsWith('rg_'), isTrue, reason: id);
        expect(ids, contains(id), reason: '$id が場面の一覧に無い');
      }
      // 子どもの岐路も5つ以上ある。
      expect(
        kRegionScenes.keys.where((id) => id.startsWith('rg_c_')).length,
        greaterThanOrEqualTo(5),
      );
    });

    test('国ごとに人生を流すと、その国の岐路が出て、ほかの国の岐路は出ない（匂わせがあり、数字が無い）', () {
      final digits = RegExp(r'[0-9０-９%]');
      final seenAll = <String>{};
      final regionsHit = <String>{};
      for (var ri = 0; ri < kRegions.length; ri++) {
        final region = kRegions[ri].n;
        for (var i = 0; i < 40; i++) {
          final seed = 12000 + ri * 100 + i;
          final rng = Rng(seed);
          final g = Game(rng: rng);
          g.start(birthIn(rng, region));
          if (g.finished) continue;
          var count = 0;
          playOut(
            g,
            Rng(seed + 1),
            onPrompt: (p) {
              final now = g.l.flags
                  .where((f) => f.startsWith('scene:rg_'))
                  .toList();
              if (now.length == count) return;
              count = now.length;
              for (final f in now) {
                final id = f.substring(6);
                expect(kRegionScenes[id], region, reason: '$regionの人生に $id');
              }
              for (final c in p.choices) {
                expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
                expect(
                  c.hint!,
                  isNot(contains(digits)),
                  reason: '${p.title}/${c.hint}',
                );
                expect(
                  c.label,
                  isNot(contains(digits)),
                  reason: '${p.title}/${c.label}',
                );
              }
            },
          );
          final got = g.l.flags
              .where((f) => f.startsWith('scene:rg_'))
              .map((f) => f.substring(6))
              .toList();
          for (final id in got) {
            expect(kRegionScenes[id], region, reason: '$regionの人生に $id');
          }
          seenAll.addAll(got);
          if (got.isNotEmpty) regionsHit.add(region);
        }
      }
      // 22国のうち18国以上で、その国の岐路が出る。岐路は36のうち24種以上。
      final missedRegions = [
        for (final r in kRegions)
          if (!regionsHit.contains(r.n)) r.n,
      ];
      final missedScenes = [
        for (final id in kRegionScenes.keys)
          if (!seenAll.contains(id)) id,
      ];
      expect(
        regionsHit.length,
        greaterThanOrEqualTo(18),
        reason: '出なかった国: $missedRegions',
      );
      expect(
        seenAll.length,
        greaterThanOrEqualTo(24),
        reason: '出なかった岐路: $missedScenes',
      );
    });
  });

  group('合戦の状況', () {
    /// 戦に出続ける侍の人生。重点は「戦に備える」（なければ仕官の口を探す・主君に尽くす）、岐路は考えて選ぶ。
    /// 出陣の岐路のたびに、出た状況の id（旗 bsr0:）を順に控える。
    List<String> warLife(int seed, void Function(Game g, Prompt p)? onBattle) {
      final g = startSurvivor(seed + 7100);
      final seq = <String>[];
      final r = Rng(seed);
      var n = 0;
      while (!g.finished && n++ < 3000) {
        final p = g.prompt!;
        if (p.title == '今年の重点') {
          final labels = p.choices.map((c) => c.label).toList();
          final i = [
            '戦に備える',
            '仕官の口を探す',
            '主君に尽くす',
          ].map(labels.indexOf).firstWhere((i) => i >= 0, orElse: () => -1);
          g.choose(i >= 0 && r.chance(.85) ? i : pickAmbitious(g, p, r));
          continue;
        }
        if (p.title == '出陣') {
          final id = recentBattles(g).first;
          seq.add(id);
          onBattle?.call(g, p);
        }
        g.choose(pickAmbitious(g, p, r));
      }
      return seq;
    }

    test('状況は約16あり、id が重複せず、身分の幅が正しい', () {
      final ids = kBattleSits.map((s) => s.id).toList();
      expect(ids.length, greaterThanOrEqualTo(15));
      expect(ids.toSet().length, ids.length);
      for (final s in kBattleSits) {
        expect(s.lo, greaterThanOrEqualTo(1), reason: s.id);
        expect(s.hi, lessThanOrEqualTo(7), reason: s.id);
        expect(s.lo, lessThanOrEqualTo(s.hi), reason: s.id);
      }
    });

    test('戦に出続ける侍の人生で、いろいろな状況が出て、同じ状況が続けて出にくく、匂わせがあり数字が無い', () {
      final seen = <String>{};
      var battles = 0, repeats = 0, pairs = 0;
      final digits = RegExp(r'[0-9０-９%％]');
      for (var seed = 0; seed < 300; seed++) {
        final seq = warLife(seed, (g, p) {
          expect(g.canFight, isTrue);
          expect(p.choices.length, inInclusiveRange(2, 3), reason: p.text);
          for (final c in p.choices) {
            expect(c.hint, isNotNull, reason: '${p.text}/${c.label}');
            expect(c.hint!, isNot(matches(digits)), reason: c.hint);
            expect(c.label, isNot(matches(digits)), reason: c.label);
            expect(c.hint!, isNot(contains('成功率')));
          }
          expect(p.text, isNot(contains('null')));
        });
        battles += seq.length;
        seen.addAll(seq);
        for (var i = 1; i < seq.length; i++) {
          pairs++;
          if (seq[i] == seq[i - 1]) repeats++;
        }
      }
      final missed = [
        for (final s in kBattleSits)
          if (!seen.contains(s.id)) s.id,
      ];
      // 作った状況の6〜7割以上が出る。
      expect(
        seen.length,
        greaterThanOrEqualTo((kBattleSits.length * .65).ceil()),
        reason: '出なかった状況: $missed（出陣 $battles回）',
      );
      expect(battles, greaterThan(300));
      // 同じ状況が二度続けて出るのはごく稀（直近の状況は外して選ぶ）。
      expect(repeats / pairs, lessThan(.05), reason: '$repeats/$pairs');
    });

    test('直近の状況は旗に残り、保存の往復で失われない', () {
      for (var seed = 0; seed < 60; seed++) {
        final g = startSurvivor(seed + 7100);
        final r = Rng(seed);
        var n = 0;
        while (!g.finished && n++ < 3000) {
          final p = g.prompt!;
          if (p.title == '出陣' && recentBattles(g).length >= 2) {
            final before = recentBattles(g);
            expect(before.length, lessThanOrEqualTo(kRecentBattles));
            expect(before.toSet().length, before.length);
            final (life, _) = fromJson(jsonOf(g));
            final back = Game(rng: Rng(1))..life = life;
            expect(recentBattles(back), before);
            return;
          }
          if (p.title == '今年の重点') {
            final i = p.choices.indexWhere((c) => c.label == '戦に備える');
            g.choose(i >= 0 ? i : pickAmbitious(g, p, r));
            continue;
          }
          g.choose(pickAmbitious(g, p, r));
        }
      }
      fail('出陣を二度以上した人生が見つからなかった');
    });

    test('侍大将以上には采配の状況が出て、足軽には出ない', () {
      var command = 0;
      for (var seed = 0; seed < 300; seed++) {
        warLife(seed, (g, p) {
          final id = recentBattles(g).first;
          final s = kBattleSits.firstWhere((x) => x.id == id);
          expect(g.l.rank, inInclusiveRange(s.lo, s.hi), reason: id);
          if (id == 'bt_command') command++;
        });
      }
      expect(command, greaterThan(0));
    });
  });

  group('女性の生き方', () {
    final digits = RegExp(r'[0-9０-９%]');
    // 重点の名 → (tag, はじめて選んだ年の岐路の題)
    const focusLabels = <String, (String, String)>{
      '奥方さまの文の取り次ぎを務める': ('wl_letters', '文の取り次ぎ'),
      '若い侍女たちを仕込む': ('wl_maids', '侍女の仕込み'),
      '屋敷の内を切り盛りする': ('wl_house', '屋敷の切り盛り'),
      '店を切り盛りする': ('wl_shop', '店の帳場'),
      '機を織って市へ出す': ('wl_loom', '市の機織り'),
      '村の女たちと田植え唄を合わせる': ('wl_song', '田植え唄'),
      '女人の参る寺を守る': ('wl_refuge', '寺へ逃げてきた女'),
      '薙刀を若い女たちに教える': ('wl_naginata', '薙刀の弟子'),
    };
    const titles = {
      '文の取り次ぎ', '侍女の仕込み', '屋敷の切り盛り', '店の帳場', '市の機織り', '田植え唄', //
      '寺へ逃げてきた女', '薙刀の弟子', '取り次ぎ', '侍女たち', '家の内', '店先', '機の音', '唄の輪', //
      '寺の務め', '薙刀の稽古場', '奥の出世', '奥方の密命', '落ち延びた姫', '野の弔い', '討死の報せ', //
      '郎党の女房たち', '家督を守る', '娘の奉公', '倒れた夫', '頼母子の講', '市の揉め事', '米の値', //
      '逃げてきた女', '取り上げ',
    };

    /// 裳着まで進めた女性を、暮らし方の型に置き直す
    /// （0 奥で仕える・1 武家の妻・2 商家の女・3 村の女・4 尼・5 幼い子のいる武家の後家）。
    Game? womanOf(int seed, int kind) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (!g.l.female) return null;
      playChildhood(g, Rng(seed + 1));
      if (g.finished) return null;
      g.choose(0); // 裳着
      if (g.finished || g.hasFlag('priesthood')) return null;
      final l = g.l;
      void serve() => l
        ..rank = 2
        ..maxRank = 2
        ..lord = g.alive.first.name
        ..fav = 30;
      void free() => l
        ..rank = 0
        ..lord = null;
      switch (kind) {
        case 0:
          serve();
          l.married = false;
        case 1:
          serve();
          l.married = true;
          g.meet('伴侶', '中村家の太郎', 50);
        case 2:
          free();
          g.setFlag('way_merchant');
          if (seed % 2 == 0) {
            l.married = true;
            g.meet('伴侶', '小川屋の吉蔵', 50);
          }
        case 3:
          if (l.cls.id != 'farmer' && l.cls.id != 'fisher') return null;
          free();
        case 4:
          free();
          l.married = false;
          g.setFlag('priesthood');
        case 5:
          serve();
          l.married = false;
          g.meet('伴侶', '青木家の次郎', 50);
          l.addKid(g.year + 6); // 二十一の年に生まれる子（家督の岐路は幼い子がいるあいだだけ）
      }
      return g;
    }

    test('暮らし方の型ごとに女性の重点が出て、男性には出ない', () {
      final want = <int, (WomanKind, List<String>)>{
        0: (WomanKind.oku, ['wl_letters', 'wl_maids']),
        1: (WomanKind.wife, ['wl_house']),
        2: (WomanKind.merchant, ['wl_shop']),
        3: (WomanKind.village, ['wl_loom', 'wl_song']),
        4: (WomanKind.nun, ['wl_refuge']),
      };
      final all = {for (final v in want.values) ...v.$2};
      final found = <int>{};
      for (var seed = 0; seed < 400 && found.length < want.length; seed++) {
        for (final k in want.keys) {
          if (found.contains(k)) continue;
          final g = womanOf(seed + 7000, k);
          if (g == null || g.has('onna')) continue;
          final (kind, tags) = want[k]!;
          expect(womanKind(g), kind, reason: 'kind=$k');
          // その型の重点だけが出る。
          expect(womanLifeTags(g).toSet(), tags.toSet(), reason: 'kind=$k');
          expect(all.containsAll(tags), isTrue);
          found.add(k);
        }
      }
      expect(found.length, want.length);

      // 女武者には薙刀の重点が足される（尼になると出ない）。
      var onna = 0;
      for (var seed = 0; seed < 20000 && onna < 3; seed++) {
        final rng = Rng(seed);
        final b = rollBirth(rng);
        if (!b.female || !b.traits.any((t) => t.id == 'onna')) continue;
        final g = Game(rng: rng);
        g.start(b);
        g.l.t = 25 * 2;
        expect(womanLifeTags(g), contains('wl_naginata'));
        g.setFlag('priesthood');
        expect(womanLifeTags(g), isNot(contains('wl_naginata')));
        onna++;
      }
      expect(onna, greaterThan(0));

      // 男性には、どの身分でも出ない。
      var men = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 9100);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.l.female) continue;
        g.l.t = 30 * 2;
        for (final setUp in <void Function()>[
          () {},
          () => g.l
            ..rank = 3
            ..lord = g.alive.first.name,
          () => g.l.married = true,
          () => g.setFlag('priesthood'),
        ]) {
          setUp();
          expect(womanKind(g), isNull);
          expect(womanLifeTags(g), isEmpty);
          expect(
            adultFocusOptions(g).where((f) => f.tag.startsWith('wl_')),
            isEmpty,
          );
        }
        men++;
      }
      expect(men, greaterThan(50));
    });

    test('女性の人生で、重点の岐路と型ごとの岐路が出て、1年の重点は上限まで、匂わせがあり数字が無い', () {
      final firsts = <String>{};
      final again = <String>{};
      final life = <String>{};
      var capped = 0, lives = 0;
      for (var seed = 0; seed < 900; seed++) {
        final g = womanOf(seed + 3300, seed % 6);
        if (g == null) continue;
        lives++;
        final r = Rng(seed + 2);
        var n = 0;
        String? expectTitle;
        // 裳着の直後の重点は、型を置き直す前に作られているので、数の突き合わせから外す。
        var fresh = true;
        while (!g.finished && n++ < 3000) {
          final p = g.prompt!;
          if (expectTitle != null) {
            expect(p.title, expectTitle, reason: 'seed=$seed');
            expectTitle = null;
          }
          if (titles.contains(p.title)) {
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
              expect(c.hint!, isNot(contains(digits)), reason: c.hint);
              expect(c.label, isNot(contains(digits)), reason: c.label);
            }
          }
          if (p.title == '今年の重点' && !g.isChild) {
            final mine = [
              for (var i = 0; i < p.choices.length; i++)
                if (focusLabels.containsKey(p.choices[i].label)) i,
            ];
            final tags = womanLifeTags(g);
            expect(mine.length, lessThanOrEqualTo(kWomenLifePerYear));
            if (!fresh) {
              expect(
                mine.length,
                tags.length < kWomenLifePerYear
                    ? tags.length
                    : kWomenLifePerYear,
                reason: 'seed=$seed $tags',
              );
              if (tags.length > kWomenLifePerYear) capped++;
            }
            fresh = false;
            for (final i in mine) {
              final c = p.choices[i];
              expect(c.hint!, isNot(contains(digits)), reason: c.hint);
              expect(c.label, isNot(contains(digits)), reason: c.label);
            }
            if (mine.isNotEmpty && r.chance(.6)) {
              final (tag, first) = focusLabels[p.choices[mine.first].label]!;
              if (!g.hasFlag('scene:$tag')) {
                expectTitle = first;
                firsts.add(tag);
              }
              g.choose(mine.first);
              continue;
            }
          }
          g.choose(r.range(0, p.choices.length - 1));
        }
        for (final f in g.l.flags) {
          if (!f.startsWith('scene:wl_')) continue;
          final id = f.substring(6);
          if (id.endsWith('_again')) again.add(id);
          if (kWomanLifeSceneIds.contains(id)) life.add(id);
        }
      }
      expect(lives, greaterThan(150));
      expect(firsts.length, greaterThanOrEqualTo(7), reason: '$firsts');
      expect(again.length, greaterThanOrEqualTo(5), reason: '$again');
      // 型ごとの岐路14のうち、6〜7割以上が出る。
      expect(life.length, greaterThanOrEqualTo(9), reason: '$life');
      expect(capped, greaterThan(0));
    });

    test('男性の人生には、女性の生き方の岐路が出ない', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 4400);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (g.l.female) continue;
        playOut(g, Rng(seed));
        expect(
          g.l.flags.where((f) => f.startsWith('scene:wl_')),
          isEmpty,
          reason: 'seed=$seed',
        );
      }
    });
  });

  group('仏門の道', () {
    final digits = RegExp(r'[0-9０-９%]');
    // 重点の名 → tag
    const focusLabels = <String, String>{
      '寺の田畑と台所を切り盛りする': 'tm_estate',
      '経典を学び、論義に備える': 'tm_sutra',
      '経典を学び、講で説く備えをする': 'tm_sutra',
      '施餓鬼や弔いを務める': 'tm_rites',
      '寺で子らに手習いを教える': 'tm_teach',
      '山にこもって行をする': 'tm_retreat',
    };
    // はじめて選んだ年の岐路の題（経典は男女で違う）
    String firstTitle(String tag, bool female) => switch (tag) {
      'tm_estate' => '寺の台所',
      'tm_sutra' => female ? '女人の講' : '論義の座',
      'tm_rites' => '施餓鬼',
      'tm_teach' => '手習いの師',
      _ => '山の行',
    };
    const titles = {
      '寺の台所', '女人の講', '論義の座', '施餓鬼', '手習いの師', '山の行', //
      '寺の蔵', '門前の市', '経蔵', '弔いの夜', '野辺送り', '手習いの子ら', '山ごもり', //
      '辻の宗論', '使僧', '寺領の兵', '首の供養', '檀家の争い', '般若湯', '消えた本尊', //
      '一夜の宿', '本山の使い', '跡目', '焼け出された子ら', '門前の列', '寺の鐘', '戦勝の祈祷', //
      '髪を下ろしたい女',
    };

    /// 元服・裳着まで進めた人を、仏門に入れ直す。
    Game? monkOf(int seed) {
      final rng = Rng(seed);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      playChildhood(g, Rng(seed + 1));
      if (g.finished) return null;
      g.choose(0); // 元服・裳着
      if (g.finished) return null;
      final l = g.l;
      l
        ..rank = 0
        ..lord = null
        ..troops = 0
        ..married = false;
      l.flags.remove('way_merchant');
      l.flags.remove('way_outlaw');
      g.setFlag('priesthood');
      return g;
    }

    test('僧・尼に仏門の重点が出て、俗人と隠居には出ない', () {
      var men = 0, women = 0;
      for (var seed = 0; seed < 300; seed++) {
        final g = monkOf(seed + 5100);
        if (g == null) continue;
        g.l.t = 30 * 2;
        expect(templeLife(g), isTrue);
        final tags = templeTags(g);
        expect(tags, containsAll(['tm_estate', 'tm_sutra', 'tm_rites']));
        expect(tags, contains('tm_teach'));
        final opts = adultFocusOptions(g)
            .where((f) => f.tag.startsWith('tm_'))
            .toList();
        expect(opts.length, templeFocusCap(g));
        // 尼は「女人の参る寺を守る」が足される分、一つ少ない。
        expect(
          templeFocusCap(g),
          g.l.female ? kTemplePerYear - 1 : kTemplePerYear,
        );
        for (final o in opts) {
          expect(o.hint, isNot(contains(digits)));
          expect(o.label, isNot(contains(digits)));
          expect(o.label, isNot(contains(RegExp('妻|嫁|休|家族'))));
        }
        if (g.l.female) {
          women++;
        } else {
          men++;
        }
        // 隠居した僧には出ない。
        g.setFlag('retired');
        expect(templeTags(g), isEmpty);
        g.l.flags.remove('retired');
        // 還俗した（旗を外した）人には出ない。
        g.l.flags.remove('priesthood');
        expect(templeTags(g), isEmpty);
        expect(
          adultFocusOptions(g).where((f) => f.tag.startsWith('tm_')),
          isEmpty,
        );
      }
      expect(men, greaterThan(20));
      expect(women, greaterThan(20));

      // 俗人には、どの身分でも出ない。
      for (var seed = 0; seed < 200; seed++) {
        final rng = Rng(seed + 9300);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        g.l.t = 30 * 2;
        if (g.hasFlag('priesthood')) continue;
        for (final setUp in <void Function()>[
          () {},
          () => g.l
            ..rank = 3
            ..lord = g.alive.first.name,
          () => g.setFlag('way_merchant'),
        ]) {
          setUp();
          expect(templeTags(g), isEmpty);
          expect(
            adultFocusOptions(g).where((f) => f.tag.startsWith('tm_')),
            isEmpty,
          );
        }
      }
    });

    test('仏門の人生で、重点の岐路と仏門の岐路が出て、1年の重点は上限まで、匂わせがあり数字が無い', () {
      final firsts = <String>{};
      final again = <String>{};
      final life = <String>{};
      var lives = 0;
      for (var seed = 0; seed < 600; seed++) {
        final g = monkOf(seed + 6100);
        if (g == null) continue;
        lives++;
        final r = Rng(seed + 3);
        var n = 0;
        String? expectTitle;
        // 元服の直後の重点は、仏門に入れ直す前に作られているので、数の突き合わせから外す。
        var fresh = true;
        while (!g.finished && n++ < 3000) {
          final p = g.prompt!;
          if (expectTitle != null) {
            expect(p.title, expectTitle, reason: 'seed=$seed');
            expectTitle = null;
          }
          if (titles.contains(p.title)) {
            expect(p.choices.length, inInclusiveRange(2, 4));
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label}');
              expect(c.hint!, isNot(contains(digits)), reason: c.hint);
              expect(c.label, isNot(contains(digits)), reason: c.label);
            }
          }
          if (p.title == '今年の重点' && !g.isChild) {
            final mine = [
              for (var i = 0; i < p.choices.length; i++)
                if (focusLabels.containsKey(p.choices[i].label)) i,
            ];
            final cap = templeFocusCap(g);
            expect(mine.length, lessThanOrEqualTo(kTemplePerYear));
            if (!fresh) {
              final tags = templeTags(g);
              expect(
                mine.length,
                tags.length < cap ? tags.length : cap,
                reason: 'seed=$seed $tags',
              );
            }
            fresh = false;
            if (mine.isNotEmpty && r.chance(.6)) {
              final i = mine[r.range(0, mine.length - 1)];
              final tag = focusLabels[p.choices[i].label]!;
              if (!g.hasFlag('scene:$tag')) {
                expectTitle = firstTitle(tag, g.l.female);
                firsts.add(tag);
              }
              g.choose(i);
              continue;
            }
          }
          g.choose(r.range(0, p.choices.length - 1));
        }
        for (final f in g.l.flags) {
          if (!f.startsWith('scene:tm_')) continue;
          final id = f.substring(6);
          if (id.endsWith('_again')) again.add(id);
          if (kTempleSceneIds.contains(id)) life.add(id);
        }
      }
      expect(lives, greaterThan(200));
      expect(firsts.length, 5, reason: '$firsts');
      expect(again.length, greaterThanOrEqualTo(4), reason: '$again');
      // 仏門の岐路15のうち、6〜7割以上が出る。
      expect(life.length, greaterThanOrEqualTo(10), reason: '$life');
    });

    test('俗人の人生には仏門の岐路が出ず、使僧は男の僧・後家の出家は尼にだけ出る', () {
      for (var seed = 0; seed < 300; seed++) {
        final rng = Rng(seed + 4700);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        String? why;
        playOut(
          g,
          Rng(seed),
          onPrompt: (p) {
            if (p.title == '使僧' && g.l.female) why = '尼に使僧';
            if (p.title == '髪を下ろしたい女' && !g.l.female) why = '僧に後家の出家';
            if (titles.contains(p.title) && !g.hasFlag('priesthood')) {
              why = '俗人に${p.title}';
            }
          },
        );
        expect(why, isNull, reason: 'seed=$seed');
      }
    });
  });

  group('縁のある人の物語', () {
    final digits = RegExp(r'[0-9０-９%]');
    final scenes = {for (final s in buildBondScenes()) s.id: s};

    /// 元服を越えた男の人生（仏門・野の道でない）を探し、侍の位3にして、
    /// 幼なじみ・好敵手・師・連れ合いを持たせる。
    Game bondGame(int seed) {
      for (var s = seed; ; s++) {
        final rng = Rng(s);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(s + 1));
        if (g.finished ||
            g.l.female ||
            g.hasFlag('priesthood') ||
            g.hasFlag('way_outlaw')) {
          continue;
        }
        g.l
          ..rank = 3
          ..maxRank = 3
          ..lord = g.alive.first.name
          ..fav = 40
          ..married = true
          ..kids = 0;
        g.meet('伴侶', '中村家のお福', 50);
        g.meet('幼なじみ', '源太', 50);
        g.meet('好敵手', '藤助', 40);
        g.meet('師', '旅の剣客', 50);
        return g;
      }
    }

    /// 縁 [k] の段を [ago] 年前に踏んだことにする。
    void stampAgo(Game g, String k, int ago) {
      g.l.flags.removeWhere((f) => f.startsWith('bd_${k}_at:'));
      g.setFlag('bd_${k}_at:${g.year - ago}');
    }

    void clearStages(Game g) => g.l.flags.removeWhere(
      (f) => f.startsWith('scene:bd_') || f.startsWith('bd_'),
    );

    test('段は前の段がないと出ず、前の段から年が空くと出る', () {
      expect(scenes.length, 18);
      expect(kBondChains.values.expand((e) => e).toSet(), scenes.keys.toSet());
      final g = bondGame(100);
      for (final c in kBondChains.values) {
        clearStages(g);
        expect(scenes[c.first]!.cond(g), isTrue, reason: '${c.first} は最初の段');
      }
      for (final e in kBondPrev.entries) {
        final id = e.key;
        final k = id.substring(3, 5);
        clearStages(g);
        g.meet('師', '旅の剣客', 50);
        g.meet('好敵手', '藤助', 40);
        g.meet('幼なじみ', '源太', 50);
        if (id == 'bd_ms_grave') g.setFlag('bd_ms_dead');
        expect(
          scenes[id]!.cond(g),
          isFalse,
          reason: '$id は前の段（${e.value}）がないと出ない',
        );
        g.setFlag('scene:${e.value}');
        stampAgo(g, k, 0);
        expect(scenes[id]!.cond(g), isFalse, reason: '$id は前の段と同じ年には出ない');
        stampAgo(g, k, 10);
        expect(scenes[id]!.cond(g), isTrue, reason: '$id は前の段から年が空けば出る');
      }
      // 果たし合いで好敵手を斬った人には、好敵手の死の段は出ない。
      clearStages(g);
      g.l.people.remove('好敵手');
      g.setFlag('scene:bd_rv_end');
      stampAgo(g, 'rv', 10);
      expect(scenes['bd_rv_death']!.cond(g), isFalse);
    });

    test('絆の深さで、次の段の筋が分かれる（選んだ手で絆が上下する）', () {
      String titleOf(Game g, String id) {
        scenes[id]!.run(g, () {});
        return g.prompt!.title;
      }

      final g = bondGame(200);
      final fr = g.l.people['幼なじみ']!;
      fr.bond = 70;
      expect(titleOf(g, 'bd_os_turn'), '友との盃');
      fr.bond = 20;
      expect(titleOf(g, 'bd_os_turn'), '友との溝');
      fr.bond = 70;
      expect(titleOf(g, 'bd_os_old'), '老いた友');
      fr.bond = 20;
      expect(titleOf(g, 'bd_os_old'), '友の病');

      final rv = g.l.people['好敵手']!;
      rv.bond = 70;
      expect(titleOf(g, 'bd_rv_end'), '好敵手と盃');
      rv.bond = 20;
      expect(titleOf(g, 'bd_rv_end'), '果たし状');
      // 侍でない人には、果たし状でなく訴えになる。
      g.l.rank = 0;
      expect(titleOf(g, 'bd_rv_end'), '訴え');
      g.l.rank = 3;

      g.l.people['師']!.bond = 70;
      expect(titleOf(g, 'bd_ms_keep'), '師の形見');
      expect(g.l.people.containsKey('師'), isFalse, reason: '亡くなった師は人物から外れる');
      g.meet('師', '旅の剣客', 20);
      expect(titleOf(g, 'bd_ms_keep'), '師の死');

      // 頼みを断ると絆が下がり、聞き入れると上がる。
      fr.bond = 50;
      g.setFlag('bd_os_high');
      scenes['bd_os_ask']!.run(g, () {});
      g.choose(g.prompt!.choices.length - 1);
      expect(fr.bond, 30);
      scenes['bd_os_ask']!.run(g, () {});
      g.choose(0);
      expect(fr.bond, greaterThan(30));

      // 連れ合いの縁側: 約束を残した人には、約束を果たす手が出る。
      g.l.people['伴侶']!.bond = 70;
      scenes['bd_sp_engawa']!.run(g, () {});
      final plain = g.prompt!.choices.length;
      g.setFlag('bd_sp_promise');
      scenes['bd_sp_engawa']!.run(g, () {});
      expect(g.prompt!.choices.length, plain + 1);
    });

    test('敵味方に分かれる段は、戦える侍で、男の幼なじみのときだけ出る', () {
      final g = bondGame(300);
      clearStages(g);
      g.setFlag('scene:bd_os_ask');
      stampAgo(g, 'os', 10);
      expect(scenes['bd_os_foes']!.cond(g), isTrue);
      g.l.rank = 0;
      expect(scenes['bd_os_foes']!.cond(g), isFalse, reason: '主家に仕えていない');
      g.l.rank = 3;
      g.meet('幼なじみ', 'お梅', 50);
      expect(scenes['bd_os_foes']!.cond(g), isFalse, reason: '幼なじみが女');
    });

    test('縁のある人を持たせた人生で、段を追った岐路が出て、最後の段まで届く人生があり、匂わせがあり数字が無い', () {
      final seen = <String>{};
      final titles = <String>{};
      var finals = 0;
      final finalChains = <String>{};
      for (var seed = 0; seed < 400; seed++) {
        final rng = Rng(seed + 11300);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        playChildhood(g, Rng(seed));
        if (g.finished) continue;
        final l = g.l;
        // 縁のある人を持たせる（三人に一人の男は主家に仕える侍）。
        if (seed % 3 == 0 &&
            !l.female &&
            !g.hasFlag('priesthood') &&
            !g.hasFlag('way_outlaw')) {
          l
            ..rank = 3
            ..maxRank = 3
            ..lord = g.alive.first.name
            ..fav = 40;
        }
        if (!l.people.containsKey('幼なじみ')) {
          g.meet('幼なじみ', seed.isEven ? '源太' : 'お梅', 30 + seed % 40);
        }
        if (!l.people.containsKey('師')) {
          g.meet('師', seed.isEven ? '旅の剣客' : '寺の和尚', 30 + seed % 40);
        }
        if (!g.hasFlag('priesthood') && !l.married) {
          l.married = true;
          g.meet('伴侶', l.female ? '中村家の太郎' : '中村家のお福', 30 + seed % 40);
        }
        final order = <String>[];
        var count = 0;
        playOut(
          g,
          Rng(seed + 1),
          onPrompt: (p) {
            final now = g.l.flags
                .where((f) => f.startsWith('scene:bd_'))
                .toList();
            if (now.length == count) return;
            count = now.length;
            for (final f in now) {
              if (!order.contains(f)) order.add(f);
            }
            titles.add(p.title);
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: '${p.title}/${c.label} に匂わせが無い');
              expect(c.hint!, isNot(contains(digits)), reason: '${p.title}/${c.hint}');
              expect(c.label, isNot(contains(digits)), reason: '${p.title}/${c.label}');
            }
          },
        );
        final ids = g.l.flags
            .where((f) => f.startsWith('scene:bd_'))
            .map((f) => f.substring(6))
            .toSet();
        seen.addAll(ids);
        // 前の段は必ず先に出ている。
        for (final id in ids) {
          final prev = kBondPrev[id];
          if (prev == null) continue;
          expect(ids, contains(prev), reason: 'seed=$seed $id の前に $prev が無い');
          expect(
            order.indexOf('scene:$prev'),
            lessThan(order.indexOf('scene:$id')),
            reason: 'seed=$seed $prev → $id の順',
          );
        }
        for (final e in kBondChains.entries) {
          if (ids.contains(e.value.last)) {
            finals++;
            finalChains.add(e.key);
          }
        }
      }
      // 18 のうち 15 以上が出る。
      expect(seen.length, greaterThanOrEqualTo(15), reason: '$seen');
      // 段がそろって最後の段まで届く人生がある（縁の種類も二つ以上）。
      expect(finals, greaterThanOrEqualTo(3), reason: '$finalChains');
      expect(finalChains.length, greaterThanOrEqualTo(2), reason: '$finalChains');
      // 絆の深さで筋が分かれる（同じ段の両方の筋が出る）。
      expect(titles, containsAll(['友との盃', '友との溝']), reason: '$titles');
    });
  });
}
