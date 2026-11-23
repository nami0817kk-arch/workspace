import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';
import 'variety.dart';

/// 大人（15歳〜）。幼少期と同じく、1年ごとに「今年の重点」を選び、
/// その年の途中で岐路が起きることがある。
///
/// 重点の中には、選んだ年に必ず起きる岐路を持つものがある
/// （仕官の口を探す → 仕官、戦に備える → 出陣、版図を広げる → 侵攻、縁談を探す → 縁談）。
/// 結果は匂わせるだけで、成功率の数字は出さない。

const _poor = ['farmer', 'fisher', 'beggar'];

/// 故郷の主家。史実で滅んでいれば、いま天下で最も強い家。
String homeLord(Game g) {
  final n = g.rng.pick(kRegions.firstWhere((r) => r.n == g.l.region).f);
  if (g.fa[n]?.alive ?? false) return n;
  return (g.alive..sort((a, b) => b.power.compareTo(a.power))).first.name;
}

void _heal(Life l, int n) => l.hp = l.hp + n > l.maxhp ? l.maxhp : l.hp + n;

// ======================================================================
// 今年の重点
// ======================================================================

List<FocusDef> adultFocusOptions(Game g) {
  final l = g.l;
  final rng = g.rng;

  final work = FocusDef('work', '働いて稼ぐ', '暮らしは楽になる。体はすり減る', (g) {
    var gain = l.cls.id == 'merchant'
        ? rng.range(12, 30) + l.sei ~/ 5
        : rng.range(4, 12);
    if (g.has('abacus')) gain = (gain * 1.5).round();
    l.gold += gain;
    l.hp -= 4;
    if (l.sei < 90 && rng.chance(.4)) l.sei++;
  });
  final train = FocusDef('train', '武芸を磨く', '腕は上がる。生傷は絶えない', (g) {
    l.bu = clampInt(
      l.bu + (l.bu > 70 ? (rng.chance(.6) ? 1 : 0) : rng.range(2, 4)),
      0,
      99,
    );
    l.hp -= 3;
  });
  final study = FocusDef('study', '学問に励む', '見えるものが増える。腕っぷしは育たない', (g) {
    final bonus = g.hasFlag('temple') || l.cls.id == 'priest' ? 1 : 0;
    l.chi = clampInt(
      l.chi + (l.chi > 70 ? (rng.chance(.6) ? 1 : 0) : rng.range(2, 3) + bonus),
      0,
      99,
    );
    g.j(1);
  });
  final social = FocusDef('social', '人と交わる', '顔が広くなる。酒代もかかる', (g) {
    l.net += rng.range(2, 4) + (l.mi > 60 ? 1 : 0);
    if (rng.chance(.4)) l.mi = clampInt(l.mi + 1, 0, 99);
    l.gold = l.gold >= 2 ? l.gold - 2 : 0;
    g.j(4);
  });
  final rest = FocusDef(
    'rest',
    l.married ? '家族と過ごす' : '体を休める',
    '心と体が戻る。世の中は待ってくれない',
    (g) {
      _heal(l, 40);
      g.j(l.married ? 10 : 7);
      final sp = l.people['伴侶'];
      if (sp != null) sp.bond = clampInt(sp.bond + 5, 0, 100);
    },
  );
  final marry = FocusDef('marry', l.female ? '嫁ぎ先を探す' : '妻を探す', '縁があれば、家が持てる', (
    g,
  ) {
    l.net += 1;
  }, forced: 'engagement');

  // 隠居の身
  if (g.hasFlag('retired')) {
    return [
      FocusDef('family', l.kids > 0 ? '子や孫と過ごす' : '静かに暮らす', '穏やかな日々。体も心も休まる', (
        g,
      ) {
        _heal(l, 30);
        g.j(8);
      }),
      FocusDef('write', '書をしたため、歌を詠む', '生きた証を残す。名は後に残るかもしれない', (g) {
        l.chi = clampInt(l.chi + rng.range(0, 2), 0, 99);
        l.fame += rng.range(1, 3);
        g.j(4);
      }),
      FocusDef('visit', '旧知を訪ねて歩く', '懐かしい顔に会える。旅は老いた体にこたえる', (g) {
        l.net += rng.range(1, 3);
        l.hp -= 6;
        g.j(6);
      }),
    ];
  }

  // 商いの道
  if (g.hasFlag('way_merchant') && l.rank == 0) {
    return [
      FocusDef('trade', '商いを広げる', '蔵は膨らむ。損を出す年もある', (g) {
        var gain =
            rng.range(-4, 20) + l.sei ~/ 5 + (g.hasFlag('goyo') ? 10 : 0);
        if (g.has('abacus')) gain = (gain * 1.5).round();
        l.gold = l.gold + gain < 0 ? 0 : l.gold + gain;
        l.hp -= 3;
        if (l.sei < 90 && rng.chance(.4)) l.sei++;
      }),
      FocusDef('journey', '仕入れの旅に出る', '遠くの品は高く売れる。道中は物騒だ', (g) {
        l.net += 1;
      }, forced: 'trade_trip'),
      social,
      study,
      rest,
      if (!l.married && g.age >= 16 && g.age < 45) marry,
    ];
  }

  // 野に生きる道（野盗・流れ者・抜け忍）
  if (g.hasFlag('way_outlaw') && l.rank == 0) {
    return [
      FocusDef('prey', '獲物を狙う', '銭は手に入る。恨みも積もる', (g) {
        l.gold += rng.range(2, 12);
        l.fame -= 1;
        l.hp -= 4;
        if (rng.chance(.3)) l.bu = clampInt(l.bu + 1, 0, 99);
      }, forced: 'raid'),
      FocusDef('hide', '山に潜んで息をひそめる', '追手はかわせる。暮らしは痩せる', (g) {
        _heal(l, 20);
        l.gold = l.gold >= 2 ? l.gold - 2 : 0;
      }),
      train,
      FocusDef('drift', '国をまたいで流れる', '新しい土地に出会う。帰る場所は遠くなる', (g) {
        l.net += 1;
        g.j(2);
      }, forced: 'wander_road'),
    ];
  }

  // 仏門の道
  if (g.hasFlag('priesthood')) {
    return [
      FocusDef('practice', '修行に打ち込む', '心は澄む。世の栄達とは無縁になる', (g) {
        l.chi = clampInt(l.chi + rng.range(1, 3), 0, 99);
        l.fame += rng.range(1, 3);
        g.j(4);
      }),
      FocusDef('preach', '人々に説いて回る', '名が広まる。旅は体にこたえる', (g) {
        l.net += rng.range(2, 4);
        l.fame += rng.range(2, 4);
        l.hp -= 3;
      }),
      study,
      rest,
    ];
  }

  // 一国の主
  if (l.rank >= 8) {
    return [
      FocusDef('develop', '領国を富ませる', '国は豊かになる。兵は増えない', (g) {
        final f = g.fa[l.lord]!;
        final up = 2 + l.sei / 15 + rng.range(0, 3);
        f.power += up;
        l.gold += (up * 6).round();
      }),
      FocusDef('arm', '軍備を整える', '戦に強くなる。蔵の銭は減る', (g) {
        final f = g.fa[l.lord]!;
        final spend = l.gold >= 30 ? 30 : l.gold;
        l.gold -= spend;
        f.power += spend / 30 * (5 + rng.range(0, 5) + l.bu / 20);
      }),
      FocusDef(
        'conquer',
        '版図を広げる',
        '隣国に兵を出す。勝てば国が広がる',
        (g) {},
        forced: 'invade',
      ),
      study,
      rng.chance(.5) ? social : rest,
      if (!l.married && g.age < 50) marry,
    ];
  }

  // 主家に仕える身
  if (l.rank >= 1) {
    final serve = FocusDef(
      'serve',
      l.female ? '奥向きに尽くす' : '主君に尽くす',
      '覚えがめでたくなる。自分の時間は減る',
      (g) {
        final m =
            (l.rank >= 3 ? l.sei / 6 : l.sei / 10).round() + rng.range(2, 6);
        l.merit += m;
        l.fav = clampInt(l.fav + rng.range(3, 7), 0, 100);
        if (l.rank >= 3) l.gold += (l.sei / 8).round();
        final f = g.fa[l.lord];
        if (f != null) f.power += .5;
      },
    );
    final war = FocusDef('war', '戦に備える', '兵を集め、出陣に加わる。手柄も、討死もありうる', (g) {
      // 位が表の外（大名以上）になっていても落ちないよう、いちばん上の位の値を使う。
      final cap = kTroopCap[l.rank.clamp(0, kTroopCap.length - 1)];
      var n = cap - l.troops;
      if (l.gold < n) n = l.gold;
      final lim = 15 + l.mi ~/ 8;
      if (lim < n) n = lim;
      if (n > 0) {
        l.gold -= n;
        l.troops += n;
      }
      if (rng.chance(.5)) l.bu = clampInt(l.bu + 1, 0, 99);
    }, forced: 'battle');
    return [
      serve,
      if (g.canFight) war,
      if (!g.canFight || l.rank < 5) l.rank < 5 ? work : train,
      if (g.canFight) train,
      study,
      rng.chance(.5) ? social : rest,
      if (!l.married && g.age >= 16 && g.age < 45) marry,
    ];
  }

  // 身分のない身
  final seek = FocusDef(
    'seek',
    l.female ? '奉公先を探す' : '仕官の口を探す',
    '身を立てる道を探す。門前払いもある',
    (g) {
      l.net += 1;
    },
    forced: 'shikan',
  );
  return [
    seek,
    work,
    train,
    study,
    rng.chance(.5) ? social : rest,
    if (!l.married && g.age >= 16 && g.age < 45) marry,
  ];
}

const _yearHead = <(int, String)>[
  (15, '若さだけは、誰にも負けない。'),
  (20, '体に力がみなぎる年頃だ。'),
  (25, '己の行く末が、ぼんやりと見えてきた。'),
  (30, '働き盛りの年になった。'),
  (40, '若い者の背中を見る歳になった。'),
  (50, '白いものが混じり始めた。'),
  (60, '残りの年を数える歳になった。'),
];

/// 今年の重点を聞くときの一文。歳と身分で変え、家族や縁のある人に一言触れる。
String adultYearText(Game g) {
  final l = g.l;
  final a = g.age;
  var head = _yearHead.first.$2;
  for (final h in _yearHead) {
    if (a >= h.$1) head = h.$2;
  }
  final String status;
  if (g.hasFlag('priesthood')) {
    status = '仏門に身を置いて迎える年。';
  } else if (l.rank >= 8) {
    status = '${houseName(g, l.lord)}家の当主として迎える年。';
  } else if (l.rank >= 1) {
    status = '${houseName(g, l.lord)}家の${g.rk[l.rank]}として迎える年。';
  } else {
    status = l.ronin ? '主を持たぬ身で迎える年。' : '身を立てる当ては、まだない。';
  }
  final extra = <String>[];
  final sp = l.people['伴侶'];
  if (sp != null && l.married) extra.add('家では${sp.name}が待っている。');
  if (l.kids > 0) extra.add('子は${l.kids}人。');
  return '$a歳。$head\n$status${extra.isEmpty ? '' : '\n${extra.join('')}'}\n今年は何に重きを置く？';
}

// ======================================================================
// 岐路の場面
// ======================================================================

String _lordHint(Game g, String n, String home) {
  if (n == home) return '故郷の主家。話は通りやすい';
  final ps = g.alive.map((f) => f.power).toList()..sort();
  final mid = ps[ps.length ~/ 2];
  final p = g.fa[n]!.power;
  if (p > mid * 1.3) return '勢いのある家。門は狭いが、出世の目は大きい';
  if (p < mid * .7) return '小さな家。入りやすいが、先は細い';
  return '並の家。可もなく不可もない';
}

String _invadeHint(double p) {
  if (p >= .7) return '組みしやすい相手に見える';
  if (p >= .45) return '五分の戦いになりそうだ';
  return '無謀かもしれない';
}

String _betrayHint(double p) {
  if (p >= .55) return '機は熟している。失敗すれば、命はない';
  if (p >= .3) return '分の悪い賭けではない。失敗すれば、命はない';
  return '家中にはまだ主君を慕う者が多い。失敗すれば、命はない';
}

void _join(Game g, String lord, {int fav = 20}) {
  final l = g.l;
  l.rank = 1;
  if (l.maxRank < 1) l.maxRank = 1;
  l.lord = lord;
  l.fav = fav;
  l.ronin = false;
}

String _spouseName(Game g) {
  final given = g.l.female ? g.rng.pick(kGivenM) : g.rng.pick(kGivenF);
  if (g.l.rank >= 1) return '${g.rng.pick(kSurnames)}家の$given';
  return given;
}

List<SceneDef> buildAdultScenes() {
  int f(Game g, String tag) => g.l.focus[tag] ?? 0;
  bool notMonk(Game g) => !g.hasFlag('priesthood');

  return [
    // ------------------------------------------------------------------
    // 重点から必ず起きる岐路
    // ------------------------------------------------------------------
    SceneDef(
      'shikan',
      15,
      84,
      (g) => 1,
      (g) => g.l.rank == 0 && notMonk(g),
      (g, next) {
        final l = g.l;
        final home = homeLord(g);
        final opts = <String>[if (g.fa[home]?.alive ?? false) home];
        final pool = g.alive
            .map((f) => f.name)
            .where((n) => n != home)
            .toList();
        while (opts.length < 3 && pool.isNotEmpty) {
          opts.add(pool.removeAt(g.rng.range(0, pool.length - 1)));
        }
        final base =
            .25 +
            (l.bu + l.chi + l.mi) / 400 +
            l.net * .02 +
            l.fame / 200 +
            (l.gold / 200 > .2 ? .2 : l.gold / 200) +
            (l.cls.id == 'ronin' ? .1 : 0) +
            (g.hasFlag('letter') ? .2 : 0) -
            (l.female ? .05 : 0);
        g.ask(l.female ? '奉公先' : '仕官', '門を叩く先を選ぶ。', [
          for (final n in opts)
            Choice.h('$n家', _lordHint(g, n, home), () {
              final strong = _lordHint(g, n, home).startsWith('勢い');
              final p = clampD(
                base + (n == home ? .15 : 0) - (strong ? .1 : 0),
                .1,
                .9,
              );
              if (g.rng.chance(p)) {
                _join(g, n, fav: strong ? 15 : 20);
                g.j(5);
                g.mark('$n家に${g.rk[1]}として仕えた');
                return '$n家に${g.rk[1]}として取り立てられた！';
              }
              g.j(-3);
              return '$n家に願い出たが、門前払いを食らった。';
            }),
          Choice.h('今年は見送る', '何も起きない', () => '今年は、門を叩かずに過ごした。'),
        ], after: next);
      },
      repeat: true,
      onlyForced: true,
    ),

    SceneDef(
      'battle',
      15,
      70,
      (g) => 2.5,
      (g) =>
          g.l.rank >= 1 &&
          g.l.rank < 8 &&
          g.canFight &&
          g.active &&
          g.hasFlag('first_battle'),
      (g, next) {
        g.ask('出陣', battleIntro(g), [
          Choice.h('先陣を駆ける', '大きな手柄か、討死か', () => g.battle('van')),
          Choice.h('本陣に控える', '手柄も危うさも、ほどほど', () => g.battle('main')),
          Choice.h('後詰めにまわる', '命は守りやすい。手柄は小さい', () => g.battle('rear')),
          Choice.h('病と称して断る', '命は守れる。主君の目は冷たくなる', () {
            g.l.fav = clampInt(g.l.fav - 8, 0, 100);
            g.j(-2);
            return '病と称して陣を離れた。主君は何も言わなかった。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'invade',
      15,
      84,
      (g) => 1,
      (g) => g.l.rank == 8,
      (g, next) {
        final l = g.l;
        final me = g.fa[l.lord]!;
        final tg = g.alive.where((x) => x != me).toList()
          ..sort((a, b) => a.power.compareTo(b.power));
        final sk = 1 + (l.bu + l.chi + l.un) / 600;
        g.ask('侵攻', invadeIntro(g), [
          for (final t in tg.take(5))
            Choice.h(
              '${t.name}家',
              _invadeHint(g.invadeP(me, t, sk)),
              () => g.doInvade(t, sk),
            ),
          Choice.h('今年は兵を動かさない', '国は休まる。好機は逃げるかもしれない', () {
            g.j(2);
            return '今年は兵を動かさず、国を休ませた。';
          }),
        ], after: next);
      },
      repeat: true,
      onlyForced: true,
    ),

    SceneDef('engagement', 16, 50, (g) => 1.2, (g) => !g.l.married, (g, next) {
      final name = _spouseName(g);
      g.ask('縁談', '$nameとの縁談が持ち上がった。', [
        Choice.h('受ける', '家が持てる。背負うものも増える', () {
          final l = g.l;
          l.married = true;
          l.net += 3;
          l.gold += 5 + l.rank * 4;
          g.j(10);
          g.meet('伴侶', name, 50);
          g.mark('$nameと夫婦になった');
          return '$nameと夫婦になった。家に灯がともる。';
        }),
        Choice.h('断る', '身軽なままでいられる', () {
          g.j(-1);
          return '縁談は断った。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef(
      'gekokujo',
      20,
      70,
      (g) => .5 + (g.has('amb') ? .7 : 0) + (g.l.fav < 30 ? .6 : 0),
      (g) =>
          g.l.rank >= 5 &&
          g.l.rank < 8 &&
          g.l.lord != null &&
          g.canFight &&
          g.active,
      (g, next) {
        final p = g.betrayChance();
        g.ask('下剋上の誘い', '家中の不満を抱える者たちが、あなたを担ごうとしている。主家を討つか。', [
          Choice.h('兵を挙げる', _betrayHint(p), () {
            final r = g.doBetray(p);
            if (g.l.rank == 8) g.mark('主家を討ち、${houseName(g, g.l.lord)}家を乗っ取った');
            return r;
          }),
          Choice.h('時期を待つ', '機はまた巡る。巡らないかもしれない', () => '誘いは聞かなかったことにした。'),
        ], after: next);
      },
      repeat: true,
    ),

    // ------------------------------------------------------------------
    // 青年の章（15〜29歳）の岐路。幼少期の選択がここで効く。
    // ------------------------------------------------------------------
    SceneDef(
      'first_battle',
      15,
      26,
      (g) => 5,
      (g) =>
          g.l.rank >= 1 &&
          g.l.rank < 8 &&
          g.canFight &&
          g.active &&
          !g.hasFlag('first_battle'),
      (g, next) {
        g.setFlag('first_battle');
        g.ask('初陣', '初陣の日が来た。槍を握る手が震える。', [
          Choice.h('先陣に名乗り出る', '名を上げる好機。生きて帰れる保証はない', () {
            final r = g.battle('van');
            if (g.l.dead == null) g.mark('初陣で先陣を駆けた');
            return r;
          }),
          Choice.h('本陣の守りにつく', '危うさは少ない。手柄も少ない', () {
            final r = g.battle('main');
            if (g.l.dead == null) g.mark('初陣を本陣で迎えた');
            return r;
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'friend_reunion',
      16,
      29,
      (g) => 3,
      (g) => g.l.people.containsKey('幼なじみ'),
      (g, next) {
        final fr = g.l.people['幼なじみ']!;
        if (fr.bond >= 40) {
          g.ask('幼なじみ', '幼なじみの${fr.name}が訪ねてきた。「一緒に、ひと旗揚げないか」', [
            Choice.h('共に道を歩む', '心強い。だが、友の運命に巻き込まれもする', () {
              fr.bond = clampInt(fr.bond + 15, 0, 100);
              g.l.net += 3;
              g.j(5);
              g.setFlag('friend_ally');
              g.mark('幼なじみの${fr.name}と、共に道を歩むと決めた');
              return '${fr.name}と、互いの背中を預けると誓い合った。';
            }),
            Choice.h('自分の道を行く', '身軽だ。友とは疎遠になる', () {
              fr.bond = clampInt(fr.bond - 15, 0, 100);
              g.mark('幼なじみの誘いを断り、ひとりの道を選んだ');
              return '${fr.name}の誘いは断った。背中が少し寂しそうだった。';
            }),
          ], after: next);
        } else {
          g.ask('幼なじみ', '仲違いしたままの${fr.name}が、いまや羽振りよく暮らしていると聞いた。', [
            Choice.h('頭を下げて縁を結び直す', '誇りは傷つく。縁は戻るかもしれない', () {
              if (g.rng.chance(.5 + g.l.mi / 200)) {
                fr.bond = clampInt(fr.bond + 30, 0, 100);
                g.l.net += 2;
                g.j(4);
                g.mark('仲違いした${fr.name}と、縁を結び直した');
                return '${fr.name}は笑って、昔のことは忘れたと言った。';
              }
              g.j(-4);
              return '${fr.name}は、目も合わせなかった。';
            }),
            Choice.h('張り合う', '負けん気は力になる。恨みも生む', () {
              g.l.bu = clampInt(g.l.bu + 2, 0, 99);
              g.setFlag('rival');
              g.l.people.remove('幼なじみ');
              g.meet('好敵手', fr.name, 10);
              g.mark('${fr.name}を生涯の好敵手と定めた');
              return '${fr.name}にだけは負けない。そう誓った。';
            }),
          ], after: next);
        }
      },
    ),

    SceneDef(
      'master_return',
      16,
      29,
      (g) => 2.5,
      (g) => g.l.people.containsKey('師'),
      (g, next) {
        final m = g.l.people['師']!;
        final l = g.l;
        g.ask('師との再会', '${m.name}が、あなたを訪ねてきた。', [
          if (l.rank == 0)
            Choice.h('推挙状を書いてもらう', '名のある家への道が開くかもしれない', () {
              g.setFlag('letter');
              m.bond = clampInt(m.bond + 10, 0, 100);
              g.mark('${m.name}から推挙状を授かった');
              return '${m.name}は黙って筆を取り、推挙状を書いてくれた。';
            }),
          Choice.h('教えを請い直す', '学びは深まる。世の動きからは遅れる', () {
            if (g.hasFlag('master_bu')) {
              l.bu = clampInt(l.bu + 3, 0, 99);
            } else {
              l.chi = clampInt(l.chi + 3, 0, 99);
            }
            m.bond = clampInt(m.bond + 15, 0, 100);
            return '久しぶりに、${m.name}の教えを受けた。';
          }),
          if ((g.hasFlag('temple') || g.hasFlag('monk')) && l.rank < 5)
            Choice.h('出家して仏門に入る', '世俗の出世はここで終わる。別の道が始まる', () {
              g.setFlag('priesthood');
              l.rank = 0;
              l.lord = null;
              l.troops = 0;
              l.chi = clampInt(l.chi + 5, 0, 99);
              g.j(6);
              g.mark('${m.name}のもとで出家し、仏門に入った');
              return '髪を剃り、${m.name}の弟子として仏門に入った。';
            }),
        ], after: next);
      },
    ),

    SceneDef(
      'nobunaga_again',
      18,
      40,
      (g) => 6,
      (g) =>
          g.hasFlag('met_nobunaga') &&
          (g.fa['織田']?.alive ?? false) &&
          g.l.rank < 5 &&
          notMonk(g),
      (g, next) {
        final l = g.l;
        g.ask('信長', '尾張の若殿・吉法師は、いまや織田信長と名乗っている。その信長が、幼い日に野で遊んだ子を覚えていた。', [
          Choice.h('信長に仕える', '型破りな主。大きく出世するか、すり潰されるか', () {
            final p = g.l.people['若殿'];
            if (p != null) {
              g.l.people.remove('若殿');
              g.meet('主君', '織田信長', p.bond + 20);
            }
            if (l.lord == '織田') {
              l.fav = clampInt(l.fav + 15, 0, 100);
              g.mark('信長に、幼き日の縁を覚えられていた');
              return '信長は「あの時の小僧か」と笑った。覚えがめでたくなった。';
            }
            if (l.rank == 0) {
              _join(g, '織田', fav: 40);
            } else {
              l.lord = '織田';
              l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
              l.fav = 35;
            }
            g.j(6);
            g.mark('幼き日の縁で、織田信長に仕えた');
            return '信長のもとに馳せ参じた。';
          }),
          Choice.h('今の暮らしを守る', '縁はここで途切れる', () {
            g.mark('信長の誘いを断った');
            return '丁重に断った。信長はつまらなそうな顔をした。';
          }),
        ], after: next);
      },
      // 信長が生きている年だけ（本能寺の変は1582年。信長が生き延びた世では1598年まで）。
      ageOk: (g, a) {
        final y = g.l.startYear + a;
        return y >= 1552 && y <= (g.hasFlag('history_honnoji') ? 1597 : 1581);
      },
    ),

    SceneDef(
      'kenshin_again',
      18,
      40,
      (g) => 6,
      (g) =>
          g.hasFlag('met_kenshin') &&
          (g.fa['上杉']?.alive ?? false) &&
          g.l.rank < 5 &&
          notMonk(g),
      (g, next) {
        final l = g.l;
        g.ask('越後の主', '寺で言葉を交わした少年は、いまや長尾景虎（のちの上杉謙信）として越後を治めている。', [
          Choice.h('景虎に仕える', '義を重んじる主。戦は多い', () {
            if (l.rank == 0) {
              _join(g, '上杉', fav: 40);
            } else {
              l.lord = '上杉';
              l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
              l.fav = 35;
            }
            g.l.people.remove('少年');
            g.meet('主君', '長尾景虎', 45);
            g.j(5);
            g.mark('幼き日の縁で、長尾景虎に仕えた');
            return '春日山に上り、景虎に仕えた。';
          }),
          Choice.h('今の道を行く', '縁はここで途切れる', () => '越後の主の噂は、遠くに聞くだけにした。'),
        ], after: next);
      },
      // 謙信が生きている年だけ（1578年に没）。
      ageOk: (g, a) {
        final y = g.l.startYear + a;
        return y >= 1548 && y <= 1577;
      },
    ),

    // ------------------------------------------------------------------
    // 身分のない身の岐路
    // ------------------------------------------------------------------
    SceneDef(
      'draft',
      15,
      40,
      (g) => 2.5,
      (g) =>
          g.l.rank == 0 &&
          !g.l.female &&
          !g.l.ronin &&
          g.l.cls.rank == 0 &&
          notMonk(g),
      (g, next) {
        final home = homeLord(g);
        g.ask('足軽の徴募', '$home家が合戦に備え、百姓から人手を集めている。', [
          Choice.h('足軽として従う', '身分が得られる。戦場に立つことになる', () {
            _join(g, home);
            g.mark('$home家の足軽として徴された');
            return '$home家の足軽となった。';
          }),
          Choice.h('逃げ隠れる', '村に残れる。臆病者と呼ばれる', () {
            g.l.hp -= 6;
            g.l.fame -= 2;
            g.j(-2);
            return '山に隠れてやり過ごした。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'hokou',
      15,
      35,
      (g) => 2.5,
      (g) => g.l.rank == 0 && g.l.female && !g.l.ronin && notMonk(g),
      (g, next) {
        final home = homeLord(g);
        g.ask('奉公の口', '$home家の奥向きで、下女を探している。', [
          Choice.h('奉公に上がる', '城の中で生きる道が開く。気苦労は多い', () {
            _join(g, home);
            g.mark('$home家の奥に奉公に上がった');
            return '$home家の下女として奉公に上がった。';
          }),
          Choice.h('断る', '慣れた暮らしに留まれる', () => '慣れた暮らしに留まることにした。'),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'zori',
      15,
      30,
      (g) => 1.5,
      (g) => g.l.rank == 0 && !g.l.female && g.l.mi >= 45 && notMonk(g),
      (g, next) {
        final top =
            (g.alive..sort((a, b) => b.power.compareTo(a.power))).first.name;
        g.ask('草履取りの口', '有力な$top家の重臣が、草履取りを探している。', [
          Choice.h('志願する', '最も低いところからの出発。気に入られれば道は開ける', () {
            final l = g.l;
            if (g.rng.chance(clampD(.25 + l.mi / 200 + l.un / 400, .1, .8))) {
              _join(g, top, fav: 30);
              g.j(5);
              g.mark('草履取りから$top家に取り立てられた');
              return '気に入られ、$top家に取り立てられた！';
            }
            return '他の志願者に押し負けた。';
          }),
          Choice.h('見送る', '誇りは守れる。機会は去る', () => '縁がなかったと思うことにした。'),
        ], after: next);
      },
    ),

    SceneDef(
      'village_fire',
      15,
      84,
      (g) => 1.5,
      (g) => g.l.rank == 0 && notMonk(g),
      (g, next) {
        g.ask('村が戦火に', '近くで合戦があり、村に火の手が上がった。', [
          Choice.h('家財を持って逃げる', '命は守れる。蓄えは失う', () {
            g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
            g.l.hp -= 6;
            g.j(-8);
            return '命だけは守ったが、蓄えを失った。';
          }),
          Choice.h('落ち武者を襲い、具足を奪う', '銭になる。手負いの武者は恐ろしい', () {
            if (g.rng.chance(.4 + g.l.bu / 200)) {
              g.l.gold += 12;
              g.l.bu += 1;
              g.j(-4);
              g.mark('落ち武者を襲い、具足を奪った');
              return '具足と刀を手に入れ、銭12貫になった。';
            }
            g.l.hp -= 20;
            g.j(-6);
            return '反撃され、手傷を負った。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'famine_adult',
      15,
      84,
      (g) => 1.5,
      (g) => g.l.rank == 0 && _poor.contains(g.l.cls.id) && notMonk(g),
      (g, next) {
        g.ask('凶作', '長雨で稲が実らない。年貢の取り立ては容赦ない。', [
          Choice.h('蓄えを切り崩して食いつなぐ', '蓄えがあれば、飢えはしのげる', () {
            if (g.l.gold < 3 && g.rng.chance(.15)) {
              g.die('凶作の冬、蓄えが尽きて飢え死にした', 'ue');
              return '蓄えは、とうに尽きていた。春を待たずに力尽きた。';
            }
            g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
            g.l.hp -= 8;
            g.j(-5);
            return '飢えをしのいだが、体力を削られた。';
          }),
          Choice.h('山に入って獲物を狩る', '獲れれば助かる。獲れなければ…', () {
            g.l.bu++;
            g.l.hp -= 5;
            if (g.rng.chance(.5)) {
              g.l.gold += 4;
              return '獲物を捕らえ、肉と毛皮で銭4貫を得た。';
            }
            g.j(-4);
            return '収穫なく、ひもじさだけが残った。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'ikki',
      15,
      60,
      (g) => 1,
      (g) => g.l.rank == 0 && _poor.contains(g.l.cls.id) && notMonk(g),
      (g, next) {
        g.ask('一揆の誘い', '村の者が、年貢の引き下げを求め一揆に加われと誘ってきた。', [
          Choice.h('加わる', '勝てば暮らしが変わる。負ければ命が危うい', () {
            final l = g.l;
            if (g.rng.chance(clampD(.3 + (l.bu + l.un) / 300, .2, .7))) {
              l.fame += 12;
              l.gold += 8;
              g.j(5);
              g.mark('一揆に加わり、勝ち取った');
              return '一揆は成功し、名が知れた。銭8貫の分け前も。';
            }
            l.hp -= 30;
            l.fame -= 5;
            g.j(-8);
            g.mark('一揆に加わり、鎮圧された');
            return '一揆は鎮圧された。傷を負い、逃げ延びた。';
          }),
          Choice.h('断る', '巻き込まれずに済む。村での立場は悪くなる', () {
            g.l.net = g.l.net >= 1 ? g.l.net - 1 : 0;
            return '関わらずに過ごした。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'monk_teacher',
      15,
      40,
      (g) => 1.5 + f(g, 'study') * .3,
      (g) => g.l.rank == 0 && g.l.chi < 80,
      (g, next) {
        g.ask('旅の僧', '旅の僧が、読み書きを教えてやろうと言う。', [
          Choice.h('弟子入りして学ぶ', '知恵がつく。暮らしの手は止まる', () {
            g.l.chi += 4;
            g.l.hp -= 5;
            return '寝食を忘れて学び、知が4上がった。';
          }),
          Choice.h('断る', '今の暮らしを優先する', () => '忙しい身。誘いは断った。'),
        ], after: next);
      },
    ),

    // ------------------------------------------------------------------
    // 誰にでも起きうる岐路
    // ------------------------------------------------------------------
    SceneDef('plague', 15, 84, (g) => 1.5, (g) => true, (g, next) {
      g.ask('疫病', '近隣で熱病が広がっている。', [
        Choice.h('薬師に頼る（銭5貫）', '銭はかかる。軽く済むかもしれない', () {
          final l = g.l;
          if (l.gold < 5) {
            l.hp -= g.rng.range(15, 30);
            return '銭が足りず、薬師に断られて寝込んだ。';
          }
          l.gold -= 5;
          l.hp -= g.rng.range(3, 10);
          return '薬のおかげで軽く済んだ。';
        }),
        Choice.h('耐えしのぐ', '体の強さと運しだい', () {
          if (g.rng.chance(.4 + g.l.un / 250)) {
            g.l.hp -= g.rng.range(5, 12);
            return '運よく熱は早く引いた。';
          }
          g.l.hp -= g.rng.range(20, 40);
          g.j(-4);
          return '高熱にうなされ、死の淵を見た。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef('bandits', 15, 60, (g) => 1.5, (g) => g.l.rank <= 2, (g, next) {
      g.ask('野盗の襲来', '野盗の一団が村を襲った。', [
        Choice.h('立ち向かう', '腕に覚えがあれば名が上がる。なければ…', () {
          final l = g.l;
          if (g.rng.chance(clampD(.2 + l.bu / 130 + l.un / 400, .1, .85))) {
            l.fame += 5;
            l.bu += 2;
            l.merit += 3;
            g.j(3);
            g.mark('野盗を撃退した');
            return '野盗を撃退し、名が少し知れ渡った。';
          }
          l.hp -= 20;
          l.gold = l.gold >= 4 ? l.gold - 4 : 0;
          g.j(-5);
          return '返り討ちにあい、傷を負い金品も奪われた。';
        }),
        Choice.h('隠れてやり過ごす', '命は守れる。蓄えは奪われる', () {
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          return '身を隠して難を逃れたが、蓄えを奪われた。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef(
      'swordsman',
      15,
      40,
      (g) => 1.2 + f(g, 'train') * .3,
      (g) => g.l.bu < 75,
      (g, next) {
        g.ask('剣客との出会い', '腕の立つ剣客が、手ほどきを授けてもよいと言う。', [
          Choice.h('銭5貫で教えを乞う', '腕は確かに伸びる。銭がかかる', () {
            if (g.l.gold < 5) return '銭が足りず、教えを乞えなかった。';
            g.l.gold -= 5;
            g.l.bu += 4;
            g.mark('剣客に手ほどきを受けた');
            return '一手の理を得て、武が4上がった。';
          }),
          Choice.h('丁重に断る', '独りで磨く道を行く', () => '独学で行くことにした。'),
        ], after: next);
      },
    ),

    SceneDef('merchant_deal', 15, 84, (g) => 1, (g) => g.l.gold >= 10, (
      g,
      next,
    ) {
      g.ask('商人の儲け話', '商人が、銭10貫を預ければ倍にすると持ちかけてきた。', [
        Choice.h('乗る（銭10貫）', 'うまくいけば大きい。うまい話には裏があるとも言う', () {
          g.l.gold -= 10;
          if (g.rng.chance(.45 + g.l.un / 250 + g.l.chi / 500)) {
            g.l.gold += 25;
            return '商いは当たり、銭25貫になって戻った！';
          }
          g.j(-4);
          return '商人は姿をくらました。騙されたのだ。';
        }),
        Choice.h('断る', '銭は減らない。増えもしない', () => 'うまい話には裏がある。断った。'),
      ], after: next);
    }, repeat: true),

    SceneDef(
      'gun',
      15,
      60,
      (g) => 2,
      (g) => !g.l.gun && g.canFight && !g.hasFlag('priesthood'),
      (g, next) {
        g.ask('鉄砲', '南蛮渡来の鉄砲を目にする機会を得た。', [
          Choice.h('銭8貫で撃ち方を習う', '戦の形が変わる道具だという。銭はかかる', () {
            if (g.l.gold < 8) return '銭が足りなかった。';
            g.l.gold -= 8;
            g.l.gun = true;
            g.mark('鉄砲の撃ち方を覚えた');
            if (g.has('gunner')) {
              g.l.bu += 5;
              return '見事な筋！鉄砲の腕を身につけた。合戦で有利になる。';
            }
            return '鉄砲の扱いを覚えた。合戦で有利になる。';
          }),
          Choice.h('見るだけにする', '何も変わらない', () => '轟音に肝を冷やしただけだった。'),
        ], after: next);
      },
      ageOk: (g, a) => g.l.startYear + a >= 1543,
    ),

    SceneDef(
      'ninja_mission',
      15,
      60,
      (g) => 1.5,
      (g) => g.l.cls.id == 'ninja' && g.l.rank < 8 && !g.hasFlag('nukenin'),
      (g, next) {
        g.ask('忍びの務め', '里から、他国への潜入任務が届いた。', [
          Choice.h('引き受ける', '銭と情報が手に入る。しくじれば命が危うい', () {
            final l = g.l;
            if (g.rng.chance(.5 + l.chi / 300)) {
              l.gold += 15;
              l.fame += 3;
              l.net += 2;
              return '任務を果たし、銭15貫と情報網を得た。';
            }
            l.hp -= 25;
            g.j(-5);
            return '任務は失敗。深手を負って逃げ帰った。';
          }),
          Choice.h('断る', '里の頭目の機嫌は悪くなる', () => '里の頭目は不満げだったが、受け入れた。'),
        ], after: next);
      },
      repeat: true,
    ),

    // ------------------------------------------------------------------
    // 主家に仕える身の岐路
    // ------------------------------------------------------------------
    SceneDef(
      'slander',
      15,
      84,
      (g) => 1.5,
      (g) => g.l.rank >= 2 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask('同僚の讒言', '出世を妬む者が、主君に根も葉もない噂を吹き込んだ。', [
          Choice.h('銭10貫で口を封じる', '確実に収まる。銭は惜しい', () {
            if (g.l.gold < 10) {
              g.l.fav -= 8;
              return '銭が足りず、噂は広まってしまった。';
            }
            g.l.gold -= 10;
            return '銭で黙らせ、事なきを得た。';
          }),
          Choice.h('堂々と申し開く', '筋が通れば信頼が増す。通らなければ…', () {
            final l = g.l;
            if (g.rng.chance(clampD(.3 + (l.chi + l.mi) / 250, .2, .85))) {
              l.fav += 5;
              return '筋道だった弁明が評価され、かえって信頼が増した。';
            }
            l.fav -= 10;
            g.j(-4);
            return '弁明は通らず、信頼を損ねた。';
          }),
          Choice.h('放っておく', '何もしなければ、噂はひとり歩きする', () {
            g.l.fav -= 10;
            return '噂は広まり、信頼が落ちた。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'secret_mission',
      15,
      84,
      (g) => 2,
      (g) => g.l.rank >= 2 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask('密命', '主君が、人目を忍んで重大な役目を命じた。', [
          Choice.h('引き受ける', '果たせば覚えがめでたい。危ない橋でもある', () {
            final l = g.l;
            if (g.rng.chance(
              clampD(.35 + (l.chi + l.mi + l.un) / 400, .2, .85),
            )) {
              l.merit += 12;
              l.fav += 10;
              l.fame += 3;
              g.mark('主君の密命を果たした');
              return '密命を果たし、主君の覚えがめでたくなった。';
            }
            l.hp -= 15;
            l.fav -= 4;
            return '密命は失敗に終わり、傷を負った。';
          }),
          Choice.h('辞退する', '身は安全。主君は不満を覚える', () {
            g.l.fav -= 5;
            return '辞退したが、主君は不満げだった。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'scheme',
      20,
      84,
      (g) => 1.2,
      (g) => g.l.rank >= 3 && g.l.rank < 8 && g.active,
      (g, next) {
        final l = g.l;
        g.ask(
          l.female ? '奥向きの工作' : '調略の好機',
          l.female ? '敵方の奥に、通じる者がいるという。' : '敵方の武将に、寝返りの気配があるという。',
          [
            Choice.h('仕掛ける', '成れば大きな功。露見すれば信頼を失う', () {
              if (g.rng.chance(.3 + (l.chi + l.mi) / 300 + l.un / 500)) {
                final m = 10 + g.rng.range(0, 8);
                final t = l.female ? 0 : g.rng.range(3, 10);
                l.merit += m;
                l.fav += 4;
                l.fame += 3;
                l.troops += t;
                g.mark(l.female ? '奥向きの工作で敵方を切り崩した' : '敵将を寝返らせた');
                return '工作が成功した！${t > 0 ? '敵の兵$tを寝返らせた。' : ''}';
              }
              l.fav -= 6;
              l.hp -= 10;
              g.j(-3);
              return '工作は露見した。信頼を損ねてしまった。';
            }),
            Choice.h('見送る', '何も起きない', () => '危ない橋は渡らなかった。'),
          ],
          after: next,
        );
      },
      repeat: true,
    ),

    SceneDef(
      'lord_death',
      18,
      84,
      (g) => 1,
      (g) => g.l.rank >= 3 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask('主君の急死', '主君が急死した。後継をめぐり家中が割れている。', [
          Choice.h('嫡子を支持する', '筋は通る。大きな見返りはない', () {
            g.l.fav += g.has('loyal') ? 18 : 10;
            g.l.merit += 5;
            g.mark('主君の急死に、嫡子を支えた');
            return '嫡子を支え、忠義の臣と目された。';
          }),
          Choice.h('弟君を担ぐ', '勝てば厚遇。負ければ居場所を失う', () {
            final l = g.l;
            if (g.rng.chance(.4 + (g.has('amb') ? .1 : 0) + l.un / 400)) {
              l.fav += 20;
              l.merit += 20;
              g.mark('家督争いで弟君を担ぎ、勝った');
              return '弟君が家督を継ぎ、擁立の功で厚遇された！';
            }
            l.rank--;
            l.fav = l.fav - 20 < 5 ? 5 : l.fav - 20;
            g.j(-8);
            g.mark('家督争いに敗れ、降格された');
            return '擁立に失敗し、降格された。';
          }),
          Choice.h('静観する', '恨みは買わない。恩も売れない', () => '成り行きを見守った。'),
        ], after: next);
      },
    ),

    SceneDef('tea', 25, 84, (g) => 1, (g) => g.l.rank >= 4 && g.l.rank < 8, (
      g,
      next,
    ) {
      g.ask('茶会', '名のある人物が茶会に招いてくれた。', [
        Choice.h('出席する（銭5貫）', '顔が売れる。作法には気を遣う', () {
          if (g.l.gold < 5) return '銭が足りず、出席を見送った。';
          g.l.gold -= 5;
          g.l.fame += 8;
          g.l.net += 3;
          g.j(3);
          return '茶会で名を上げ、人脈も広がった。';
        }),
        Choice.h('欠席する', '気楽だ。縁は広がらない', () => '茶の湯より、日々の務めを選んだ。'),
      ], after: next);
    }, repeat: true),

    // ------------------------------------------------------------------
    // 女性の道
    // ------------------------------------------------------------------
    SceneDef(
      'husband_death',
      18,
      70,
      (g) => .8,
      (g) => g.l.female && g.l.married && g.l.rank >= 1,
      (g, next) {
        final sp = g.l.people['伴侶'];
        final who = sp?.name ?? '夫';
        g.ask('夫の死', '$whoが戦で命を落とした。', [
          Choice.h('家を守り抜く', '悲しみを抱えたまま、家の要になる', () {
            g.j(-25);
            g.l.merit += 10;
            g.l.fav += 8;
            g.mark('$whoを戦で亡くし、家を守り抜くと決めた');
            return '悲しみを胸に、家を守る決意をした。';
          }),
          Choice.h('出家して尼となる', '心は静まる。世の中からは身を引く', () {
            final l = g.l;
            g.j(-5);
            l.married = false;
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.ronin = true;
            g.setFlag('priesthood');
            _heal(l, 15);
            g.mark('$whoを亡くし、尼となった');
            return '髪を下ろし、亡き夫の菩提を弔う日々が始まった。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'political_marriage',
      16,
      35,
      (g) => 1.5,
      (g) => g.l.female && g.l.rank >= 3 && g.l.rank < 8 && !g.l.married,
      (g, next) {
        final name = '${g.rng.pick(kSurnames)}家の${g.rng.pick(kGivenM)}';
        g.ask('政略結婚', '家のため、$nameへの輿入れが決まった。', [
          Choice.h('受け入れる', '家の格が上がる。心は置き去りになるかもしれない', () {
            final l = g.l;
            l.married = true;
            l.rank = l.rank + 1 > 7 ? 7 : l.rank + 1;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.fav += 10;
            l.net += 4;
            g.j(-6);
            g.meet('伴侶', name, 30);
            g.mark('家のため、$nameへ輿入れした');
            return '輿入れを果たし、家の絆を結んだ。位が上がった。';
          }),
          Choice.h('拒む', '心は守れる。家中の不興を買う', () {
            g.l.fav -= 12;
            g.j(2);
            g.mark('家の決めた輿入れを拒んだ');
            return '縁談を拒み、家中の不興を買った。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'regent',
      20,
      70,
      (g) => 1.2,
      (g) => g.l.female && g.l.rank >= 6 && g.l.rank < 8 && g.l.kids >= 1,
      (g, next) {
        g.ask('後見', '当主が急死した。幼い嫡子に代わり、後見を求める声が上がっている。', [
          Choice.h('後見を引き受ける', '一国の政を担う。敵も多くなる', () {
            final l = g.l;
            l.rank = 8;
            l.maxRank = 8;
            l.fame += 25;
            l.gold += 40;
            l.troops = 0;
            g.j(5);
            g.mark('幼い当主の後見として、一国の政を担った');
            return '幼い当主の後見として、一国の政を担うことになった！';
          }),
          Choice.h('奥に退く', '静かに暮らせる', () {
            g.j(3);
            return '政争から身を引き、静かに暮らすことにした。';
          }),
        ], after: next);
      },
    ),

    // ------------------------------------------------------------------
    // 一国の主の岐路
    // ------------------------------------------------------------------
    SceneDef('retainer_plot', 15, 84, (g) => 1.5, (g) => g.l.rank == 8, (
      g,
      next,
    ) {
      g.ask('重臣の不穏', '重臣の一人が謀反を企てているとの噂がある。', [
        Choice.h('先手を打って粛清する', '芽は摘める。家中は萎縮する', () {
          g.fa[g.l.lord]!.power -= 2;
          g.j(-4);
          return '重臣を粛清した。勢力はやや削がれたが、家中は引き締まった。';
        }),
        Choice.h('様子を見る', '噂なら何も失わない。噂でなければ…', () {
          if (g.rng.chance(.35)) {
            g.fa[g.l.lord]!.power -= 6;
            return '謀反が起き、勢力が大きく損なわれた！';
          }
          return '噂は噂に過ぎなかった。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef('alliance', 15, 84, (g) => 1, (g) => g.l.rank == 8, (g, next) {
      g.ask('同盟の申し出', '近隣の大名が、縁組を通じた同盟を求めてきた。', [
        Choice.h('受ける', '国は安らぐ。縛られもする', () {
          g.fa[g.l.lord]!.power += 3;
          g.l.gold += 20;
          return '同盟が成り、勢力と銭が増えた。';
        }),
        Choice.h('断る', '縛られずに済む。敵を一つ残す', () => '独力で道を切り開くと決めた。'),
      ], after: next);
    }, repeat: true),

    SceneDef('realm_famine', 15, 84, (g) => 1, (g) => g.l.rank == 8, (g, next) {
      g.ask('領内の不作', '領内が不作に見舞われた。', [
        Choice.h('蔵を開いて救う（銭20貫）', '民の心は国の力になる。蔵は空く', () {
          if (g.l.gold < 20) {
            g.fa[g.l.lord]!.power -= 3;
            g.j(-4);
            return '銭が足りず民を救えなかった。勢力が落ちた。';
          }
          g.l.gold -= 20;
          g.fa[g.l.lord]!.power += 1;
          g.j(4);
          g.mark('不作の年に蔵を開き、民を救った');
          return '民を救い、領国の信望が高まった。';
        }),
        Choice.h('年貢を取り立てる', '蔵は満ちる。民は疲れる', () {
          g.fa[g.l.lord]!.power -= 2;
          g.l.gold += 15;
          g.j(-3);
          return '銭は得たが、民は疲弊した。';
        }),
      ], after: next);
    }, repeat: true),
  ];
}
