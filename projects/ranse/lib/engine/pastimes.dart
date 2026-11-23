import 'childhood.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 大人の「今年の重点」に足す、暮らしと嗜みの重点（2026-11-23、ユーザー「寺子屋に通うなど選択肢もほしい」
/// 「このような作り込みを続けて」）。
///
/// - 重点 10: 寺社に参る・茶の湯・連歌・鷹狩り・湯治・弓馬／槍の稽古・新田／漁・子の手習い・琴と香・書物を写す。
///   身分・道（隠居・商い・野の道・仏門・一国の主・主家に仕える身・身分のない身）・性別・年頃で出し分ける。
/// - 1年に出すのは、いつもの重点に**2つまで**（[kPastimesPerYear]。当てはまるものが3つ以上なら、
///   その年に出す2つを無作為に選ぶ）。
/// - はじめて選んだ年は「始めの一回」の岐路（一生に一度）。2回目からは、選んだ年の半分ほどで小さな岐路
///   （`<id>_again`、`repeat`。書き出しを回数で変える）。どちらも `onlyForced`（重点で選んだ年にしか起きない）。
///
/// id・旗は `ps_`（最期の仏門の `p_` と紛れないように）。

/// 1年に「今年の重点」に足す、暮らしと嗜みの重点の数の上限。
const kPastimesPerYear = 2;

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;

/// いまの暮らしの場（`adultFocusOptions` の分け方と同じ順で決める）。
enum _Ctx { retired, merchant, outlaw, monk, lord, retainer, none }

_Ctx _ctx(Game g) {
  final l = g.l;
  if (g.hasFlag('retired')) return _Ctx.retired;
  if (g.hasFlag('way_merchant') && l.rank == 0) return _Ctx.merchant;
  if (g.hasFlag('way_outlaw') && l.rank == 0) return _Ctx.outlaw;
  if (g.hasFlag('priesthood')) return _Ctx.monk;
  if (l.rank >= 8) return _Ctx.lord;
  if (l.rank >= 1) return _Ctx.retainer;
  return _Ctx.none;
}

String _season(Game g) => g.l.t % 2 == 0
    ? g.rng.pick(['田植えの終わった頃', '若葉の頃', '梅雨の晴れ間'])
    : g.rng.pick(['稲刈りの済んだ頃', '木枯らしの吹く頃', '雪の便りの届く頃']);

/// 回を重ねた年の書き出し（2回目は [second]、以降は [more] から一つ。{季} は時節）。
String _intro(Game g, String tag, String second, List<String> more) =>
    (_n(g, tag) <= 2 ? second : g.rng.pick(more)).replaceAll('{季}', _season(g));

String _house(Game g) => g.l.lord == null ? '主' : houseName(g, g.l.lord);

/// 子（縁のある子がいればその名）。
String _kidName(Game g) =>
    g.l.people['子']?.name ?? g.l.people['娘']?.name ?? '子';

void _kidBond(Game g, int n) {
  final k = g.l.people['子'] ?? g.l.people['娘'];
  if (k != null) k.bond = _c100(k.bond + n);
}

/// 始めの一回がまだなら始めの岐路。済んでいれば、半分ほどの年に小さな岐路。
String? _forcedFor(Game g, String id) {
  if (!g.hasFlag('scene:$id')) return id;
  return g.rng.chance(.5) ? '${id}_again' : null;
}

// ======================================================================
// 重点
// ======================================================================

/// 暮らしと嗜みの重点の一つ。[ok] は乱数を使わずに出せるかを決め、[make] が重点を作る。
class _Pastime {
  const _Pastime(this.tag, this.ok, this.make);
  final String tag;
  final bool Function(Game g) ok;
  final FocusDef Function(Game g) make;
}

bool _teaOk(Game g) {
  final l = g.l;
  return switch (_ctx(g)) {
    _Ctx.merchant || _Ctx.lord => true,
    _Ctx.retainer => !l.female && l.rank >= 3,
    _Ctx.none => l.cls.id == 'merchant',
    _Ctx.retired => (!l.female && l.maxRank >= 3) || l.cls.id == 'merchant',
    _ => false,
  };
}

bool _rengaOk(Game g) {
  final l = g.l;
  if (l.female) return false;
  return switch (_ctx(g)) {
    _Ctx.merchant || _Ctx.lord || _Ctx.monk => true,
    _Ctx.retainer => l.rank >= 3,
    _Ctx.none => l.cls.id == 'merchant' || l.cls.id == 'priest',
    _Ctx.retired => l.maxRank >= 3 || l.cls.id == 'merchant',
    _ => false,
  };
}

bool _bookOk(Game g) {
  final l = g.l;
  if (l.chi < 45) return false;
  return switch (_ctx(g)) {
    _Ctx.monk || _Ctx.retired || _Ctx.lord || _Ctx.merchant => true,
    _Ctx.retainer => l.rank >= 3,
    _Ctx.none => l.cls.id == 'priest' || l.cls.id == 'merchant',
    _ => false,
  };
}

final _pastimes = <_Pastime>[
  // ---- 寺社に参る（仏門の人を除く誰でも。運・幸福）----
  _Pastime(
    'ps_shrine',
    (g) => _ctx(g) != _Ctx.monk,
    (g) => FocusDef('ps_shrine', '寺社に参り、願をかける', '心が晴れる。神仏が聞き届けるかは分からない', (g) {
      _pay(g, 1);
      if (g.rng.chance(.35)) g.l.un = _c(g.l.un + 1);
      g.j(5);
    }, forced: _forcedFor(g, 'ps_shrine')),
  ),

  // ---- 茶の湯を学ぶ（侍・商人。魅・人脈）----
  _Pastime(
    'ps_tea',
    _teaOk,
    (g) => FocusDef('ps_tea', '茶の湯を学ぶ', '人の輪が広がる。道具に銭が消える', (g) {
      _pay(g, 3);
      if (g.rng.chance(.5)) g.l.mi = _c(g.l.mi + 1);
      g.l.net += g.rng.range(1, 2);
      if (_ctx(g) == _Ctx.retainer) g.l.fav = _c100(g.l.fav + 2);
      g.j(2);
    }, forced: _forcedFor(g, 'ps_tea')),
  ),

  // ---- 連歌の会に出る（侍・僧・商人の男。知・魅）----
  _Pastime(
    'ps_renga',
    _rengaOk,
    (g) => FocusDef('ps_renga', '連歌の会に出る', '言葉の腕が磨かれる。座の顔ぶれも覚えられる', (g) {
      if (_ctx(g) != _Ctx.monk) _pay(g, 2);
      if (g.rng.chance(.5)) g.l.chi = _c(g.l.chi + 1);
      if (g.rng.chance(.3)) g.l.mi = _c(g.l.mi + 1);
      g.l.net += 1;
      if (g.rng.chance(.4)) g.l.fame += 1;
      g.j(3);
    }, forced: _forcedFor(g, 'ps_renga')),
  ),

  // ---- 鷹狩り（城主・家老・大名。戦える男。武・人脈）----
  _Pastime(
    'ps_hawk',
    (g) =>
        !g.l.female &&
        g.canFight &&
        ((_ctx(g) == _Ctx.retainer && g.l.rank >= 5) || _ctx(g) == _Ctx.lord),
    (g) => FocusDef(
      'ps_hawk',
      _ctx(g) == _Ctx.lord ? '鷹狩りに出る' : '主君の鷹狩りの供をする',
      '体がほぐれ、近しい者と語らえる。野山は荒れている',
      (g) {
        g.l.hp -= 2;
        if (g.rng.chance(.4)) g.l.bu = _c(g.l.bu + 1);
        g.l.net += 1;
        if (_ctx(g) == _Ctx.retainer) g.l.fav = _c100(g.l.fav + 3);
        g.j(3);
      },
      forced: _forcedFor(g, 'ps_hawk'),
    ),
  ),

  // ---- 湯治に行く（誰でも。中年から。体を治す）----
  _Pastime(
    'ps_onsen',
    (g) => g.age >= 35,
    (g) => FocusDef('ps_onsen', '湯治に行く', '体の痛みが抜ける。山の湯までの道は遠い', (g) {
      _heal(g, 50);
      _pay(g, 3);
      g.j(6);
    }, forced: _forcedFor(g, 'ps_onsen')),
  ),

  // ---- 弓・馬の稽古／槍の稽古（主家に仕える、戦える人）----
  _Pastime('ps_arms', (g) => _ctx(g) == _Ctx.retainer && g.canFight, (g) {
    final yari = g.l.rank <= 2;
    return FocusDef(
      'ps_arms',
      yari ? '槍の稽古に励む' : '弓・馬の稽古に励む',
      yari ? '槍の腕が上がり、組頭の目にも留まる。体は痛む' : '腕が上がり、家中で一目置かれる。落馬は怖い',
      (g) {
        final l = g.l;
        l.bu = _c(
          l.bu + (l.bu < 80 ? g.rng.range(1, 2) : (g.rng.chance(.5) ? 1 : 0)),
        );
        l.merit += g.rng.range(2, 4);
        l.hp -= 3;
      },
      forced: _forcedFor(g, 'ps_arms'),
    );
  }),

  // ---- 荒れ野を拓く（百姓）／網を繕い沖へ出る（漁民）----
  _Pastime(
    'ps_land',
    (g) =>
        _ctx(g) == _Ctx.none &&
        (g.l.cls.id == 'farmer' || g.l.cls.id == 'fisher'),
    (g) {
      final fisher = g.l.cls.id == 'fisher';
      return FocusDef(
        'ps_land',
        fisher ? '網を繕い、沖へ出る' : '荒れ野を拓いて田を広げる',
        fisher ? '獲れれば暮らしが潤う。海は気まぐれだ' : '何年か先に実る。いまは骨が折れるだけ',
        (g) {
          final l = g.l;
          if (fisher) {
            l.gold += g.rng.range(3, 8);
            l.hp -= 4;
            if (g.rng.chance(.3)) l.un = _c(l.un + 1);
          } else {
            // 拓いた年が重なるほど、田が実ってくる。
            l.gold += g.rng.range(1, 3) + (_n(g, 'ps_land') >= 3 ? 3 : 0);
            l.hp -= 5;
            if (g.rng.chance(.3)) l.sei = _c(l.sei + 1);
          }
        },
        forced: _forcedFor(g, 'ps_land'),
      );
    },
  ),

  // ---- 子に手習いをさせる（子のいる人。子との絆）----
  _Pastime(
    'ps_kid',
    (g) =>
        g.l.kids > 0 &&
        g.age >= 22 &&
        _ctx(g) != _Ctx.monk &&
        _ctx(g) != _Ctx.outlaw,
    (g) => FocusDef('ps_kid', '子に手習いをさせる', '子との絆が深まる。いずれ子の身を助ける', (g) {
      _pay(g, 1);
      g.j(6);
      if (g.rng.chance(.3)) g.l.chi = _c(g.l.chi + 1);
      _kidBond(g, 5);
    }, forced: _forcedFor(g, 'ps_kid')),
  ),

  // ---- 琴や香を学ぶ（奥で仕える女性）----
  _Pastime(
    'ps_koto',
    (g) => _ctx(g) == _Ctx.retainer && g.l.female,
    (g) =>
        FocusDef('ps_koto', '奥の務めの合間に、琴や香を学ぶ', '雅な嗜みは身を助ける。務めがおろそかになるかも', (g) {
          if (g.rng.chance(.5)) g.l.mi = _c(g.l.mi + 1);
          g.l.fav = _c100(g.l.fav + 1);
          g.j(5);
        }, forced: _forcedFor(g, 'ps_koto')),
  ),

  // ---- 書物を写す（字の読める人）----
  _Pastime(
    'ps_book',
    _bookOk,
    (g) => FocusDef(
      'ps_book',
      _ctx(g) == _Ctx.monk ? '経や書物を写す' : '書物を写す',
      '知恵が深まる。目と肩は疲れる',
      (g) {
        final l = g.l;
        l.chi = _c(
          l.chi + (l.chi < 85 ? g.rng.range(1, 2) : (g.rng.chance(.5) ? 1 : 0)),
        );
        l.hp -= 1;
        g.j(2);
      },
      forced: _forcedFor(g, 'ps_book'),
    ),
  ),
];

/// 身分・道・性別・年頃に合う、暮らしと嗜みの重点の tag（乱数を使わない。テスト用にも出す）。
List<String> pastimeTags(Game g) => [
  for (final p in _pastimes)
    if (p.ok(g)) p.tag,
];

/// その年に出す、暮らしと嗜みの重点（[kPastimesPerYear] まで）。
///
/// 当てはまるものが多いときは、その年に出すものを無作為に選ぶ（並びの順は保つ）。
/// 岐路を決める乱数（`_forcedFor`）は、選ばれたものにだけ使う。
List<FocusDef> pastimeFocusOptions(Game g) {
  final cand = [
    for (final p in _pastimes)
      if (p.ok(g)) p,
  ];
  if (cand.length > kPastimesPerYear) {
    final keep = <int>{};
    while (keep.length < kPastimesPerYear) {
      keep.add(g.rng.range(0, cand.length - 1));
    }
    return [
      for (var i = 0; i < cand.length; i++)
        if (keep.contains(i)) cand[i].make(g),
    ];
  }
  return [for (final p in cand) p.make(g)];
}

// ======================================================================
// 岐路（どれも重点で選んだ年にだけ起きる）
// ======================================================================

SceneDef _first(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(id, 15, 100, (g) => 1, (g) => true, run, onlyForced: true);

SceneDef _again(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(
      '${id}_again',
      15,
      100,
      (g) => 1,
      (g) => true,
      run,
      onlyForced: true,
      repeat: true,
    );

List<SceneDef> buildPastimeScenes() => [
  // ==================================================================
  // 寺社に参る
  // ==================================================================
  _first('ps_shrine', (g, next) {
    final where = _ctx(g) == _Ctx.outlaw
        ? '人目を避けて、山奥の古い社に参った。'
        : '土地の古い寺社に参った。参道には、願をかける人の列ができている。';
    g.ask('願掛け', '$where何を願う？', [
      Choice.h('家の者の無事を願う', '欲のない願いだ。叶えば、穏やかな日が続く', () {
        g.setFlag('ps_wish_home');
        g.j(5);
        final sp = g.l.people['伴侶'];
        if (sp != null && g.l.married) sp.bond = _c100(sp.bond + 5);
        return '家の者の顔を一人ずつ思い浮かべて、手を合わせた。';
      }),
      Choice.h('身の栄えを願い、寄進もする', '大きな願いには、大きな寄進がいる。通じるかは神仏しだい', () {
        g.setFlag('ps_wish_rise');
        if (g.l.gold < 5) {
          g.j(-1);
          return '寄進するほどの銭がなく、小さな賽銭だけを投げた。';
        }
        g.l.gold -= 5;
        if (g.rng.chance(.3 + g.l.un / 300)) {
          g.l.fame += 2;
          g.l.un = _c(g.l.un + 2);
          g.mark('寺社に寄進して願をかけ、願が通じた');
          return '願が通じたのか、ほどなくして良い話が舞い込んだ。';
        }
        return '寄進は受け取られた。神仏の返事は、まだない。';
      }),
      Choice.h('何も願わず、ただ手を合わせる', '何も求めない。心は軽くなる', () {
        _heal(g, 10);
        g.j(3);
        return '風の音を聞きながら、しばらく境内に座っていた。';
      }),
    ], after: next);
  }),
  _again('ps_shrine', (g, next) {
    final head = _intro(g, 'ps_shrine', 'また寺社に参った。', [
      '{季}、また参詣に出た。',
      '参道の茶屋の婆が、あなたの顔を覚えていた。',
      '境内の大杉の下で、ひと息ついた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('参詣', '$head山門の脇で、痩せた子が手を差し出している。', [
        Choice.h('銭を与える', '銭は減る。施しは巡り巡って返るとも言う', () {
          _pay(g, 2);
          g.j(4);
          if (g.rng.chance(.3)) g.l.un = _c(g.l.un + 1);
          return '子は銭を握りしめ、何度も頭を下げた。';
        }),
        Choice.h('素通りする', '何も変わらない。少し胸が痛む', () {
          g.j(-1);
          return '振り返らずに、山門をくぐった。';
        }),
      ], after: next);
      return;
    }
    g.ask('参詣', '$head社の者が、籤を引いていけと勧める。', [
      Choice.h('籤を引く', '吉と出るか、凶と出るか', () {
        if (g.rng.chance(.5 + g.l.un / 400)) {
          g.j(6);
          return '吉と出た。足取りが軽くなった。';
        }
        g.j(-4);
        return '凶と出た。籤を境内の木に結んで帰った。';
      }),
      Choice.h('引かずに帰る', '何も変わらない。知らずに済むこともある', () {
        g.j(1);
        return '手を合わせるだけにして、帰り道についた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 茶の湯
  // ==================================================================
  _first('ps_tea', (g, next) {
    g.ask('茶の湯の席', '町の茶人の席に招かれた。床には、名物と噂される茶碗が飾られている。客は皆、黙って亭主の手元を見つめている。', [
      Choice.h('茶碗を言葉を尽くして褒める', '亭主は喜ぶ。目の肥えた客には見抜かれる', () {
        if (g.rng.chance(.3 + g.l.mi / 150)) {
          g.l.net += 3;
          g.setFlag('ps_tea_praise');
          return '亭主は相好を崩し、次の席にも呼ぶと言った。';
        }
        g.j(-2);
        return '褒め言葉が上滑りし、隣の客が小さく笑った。';
      }),
      Choice.h('よく分からぬと正直に言う', '恥はかく。正直を好む人もいる', () {
        if (g.rng.chance(.5)) {
          g.l.chi = _c(g.l.chi + 2);
          g.setFlag('ps_tea_honest');
          return '亭主は「それでよい」と笑い、茶の心を説いてくれた。';
        }
        g.j(-1);
        return 'しばし座が白けた。';
      }),
      Choice.h('譲ってほしいと申し出る', '銭は飛ぶ。名物を持てば、人の見る目が変わる', () {
        if (g.l.gold < 30) {
          g.j(-2);
          return '「茶碗が泣きますな」と、やんわり断られた。';
        }
        g.l.gold -= 30;
        g.l.fame += 3;
        g.l.net += 2;
        g.setFlag('ps_meibutsu');
        g.mark('茶の湯の席で、名物の茶碗を譲り受けた');
        return '大枚をはたき、名物の茶碗を手に入れた。噂はすぐに広まった。';
      }),
    ], after: next);
  }),
  _again('ps_tea', (g, next) {
    final head = _intro(g, 'ps_tea', 'また茶の湯の席に招かれた。', [
      '{季}、茶の湯の席に招かれた。',
      '湯の沸く音に、心が静まる。',
      '狭い茶室で、思いがけない客と膝を並べた。',
    ]);
    final merchant = _ctx(g) == _Ctx.merchant || g.l.cls.id == 'merchant';
    final rumor = merchant
        ? '隣の客が、遠国で米の値が上がりそうだと耳打ちしてきた。'
        : '隣の客が、近く大きな普請があるらしいと耳打ちしてきた。';
    g.ask('茶の湯の席', '$head$rumor', [
      Choice.h('話に乗る', '耳寄りな話かもしれない。外れることもある', () {
        if (g.rng.chance(.45 + g.l.un / 400)) {
          final gain = g.rng.range(6, 15);
          g.l.gold += gain;
          return '噂は当たった。先回りした分だけ、懐が潤った。';
        }
        _pay(g, 5);
        g.j(-2);
        return '噂は外れた。動いた分だけ、銭が減った。';
      }),
      Choice.h('聞き流して茶を味わう', '儲けはない。心は落ち着く', () {
        g.j(4);
        return '一服の茶を、ゆっくりと味わった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 連歌
  // ==================================================================
  _first('ps_renga', (g, next) {
    final c = _ctx(g);
    final host = c == _Ctx.retainer
        ? '${_house(g)}家の殿の句'
        : (c == _Ctx.lord ? '客の句' : '座の主の句');
    g.ask('連歌の会', '旅の連歌師を招いた会に連なった。あなたの番が回ってきた。前の句は、散る花を詠んでいる。', [
      Choice.h('素直に付ける', '無難な句になる。座は滞りなく進む', () {
        g.j(2);
        g.l.net += 1;
        return '素直な句を付けた。連歌師が小さくうなずいた。';
      }),
      Choice.h('機知を効かせて付ける', '座が沸くか、白けるか。腕しだい', () {
        if (g.l.chi >= 60 || g.rng.chance(g.l.chi / 150)) {
          g.l.fame += 2;
          g.meet('連歌の友', '旅の連歌師', 40);
          g.setFlag('ps_renga_praised');
          g.mark('連歌の会で、旅の連歌師に句を褒められた');
          return '座がどっと沸いた。旅の連歌師が、あなたの句を書き留めていった。';
        }
        g.j(-3);
        return '句の意味が通らず、座が静まり返った。';
      }),
      Choice.h('$hostを立てる付け方をする', '自分は目立たない。座の主は喜ぶ', () {
        if (c == _Ctx.retainer) {
          g.l.fav = _c100(g.l.fav + 5);
        } else {
          g.l.net += 3;
        }
        return '前の句を引き立てる句を付けた。座の主の機嫌がよくなった。';
      }),
    ], after: next);
  }),
  _again('ps_renga', (g, next) {
    final head = _intro(g, 'ps_renga', 'また連歌の会に出た。', [
      '{季}、連歌の会に出た。',
      '懐紙に句が書き連ねられていく。',
      '会の顔ぶれにも、すっかり馴染んだ。',
    ]);
    if (_ctx(g) == _Ctx.retainer) {
      g.ask('連歌の会', '$head座の一人が詠んだ句が、主家への恨みとも聞こえた。', [
        Choice.h('殿に知らせる', '忠義は示せる。告げ口と恨まれもする', () {
          g.l.fav = _c100(g.l.fav + 6);
          g.j(-2);
          g.setFlag('ps_renga_report');
          return '殿は黙って聞き、その者を遠ざけた。座の者は、あなたを避けるようになった。';
        }),
        Choice.h('聞かなかったことにする', '波風は立たない。後で知れれば咎められるかも', () {
          if (g.rng.chance(.15)) {
            g.l.fav = _c100(g.l.fav - 6);
            return 'のちに、その座にいたことを咎められた。';
          }
          g.j(1);
          return '何事もなく、会は終わった。';
        }),
        Choice.h('返しの句でたしなめる', '座は収まる。腕が要る', () {
          if (g.l.chi >= 60 || g.rng.chance(.3)) {
            g.l.fame += 2;
            g.l.net += 2;
            return '返しの句に、座の者が膝を打った。詠んだ当人も、苦笑いして頭を下げた。';
          }
          g.j(-2);
          return '返しの句は空回りし、かえって座が気まずくなった。';
        }),
      ], after: next);
      return;
    }
    g.ask('連歌の会', '$head会のあと、遠国から来た客が、旅の珍しい話を始めた。', [
      Choice.h('夜更けまで聞き入る', '見聞が広がる。翌日は眠い', () {
        g.l.chi = _c(g.l.chi + 1);
        g.l.net += 1;
        g.l.hp -= 2;
        return '遠い国の湊や城の話に、夜の更けるのも忘れた。';
      }),
      Choice.h('早めに帰って休む', '体は休まる。話の続きは分からない', () {
        _heal(g, 8);
        return '一足先に、座を辞した。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 鷹狩り
  // ==================================================================
  _first('ps_hawk', (g, next) {
    final lord = _ctx(g) == _Ctx.lord;
    g.ask(
      '鷹狩り',
      lord
          ? '領内の野で鷹を放った。獲物を追って、鷹が百姓の麦畑に降りた。'
          : '${_house(g)}家の殿の鷹狩りの供をした。殿の鷹が、獲物を追って百姓の麦畑に降りた。',
      [
        Choice.h('畑に踏み込んで獲物を取る', '獲物は手に入る。百姓の恨みを買う', () {
          if (lord) {
            g.l.fame -= 1;
            g.j(2);
          } else {
            g.l.fav = _c100(g.l.fav + 4);
          }
          return '麦を踏み分けて、鷹と獲物を拾い上げた。畑の端で、百姓が黙って頭を下げていた。';
        }),
        Choice.h('畑を回り込み、詫びの銭を置く', '手間も銭もかかる。領民の噂になる', () {
          _pay(g, 3);
          g.l.fame += 2;
          g.setFlag('ps_hawk_kind');
          g.mark('鷹狩りで降りた麦畑の主に、詫びの銭を置いた');
          return '畑の主に詫びの銭を置いた。その話は、思いのほか遠くまで伝わった。';
        }),
        lord
            ? Choice.h('畑の主を呼び、村の様子を聞く', '国の実の姿が分かる。供の者は待たされる', () {
                g.l.sei = _c(g.l.sei + 2);
                g.l.net += 1;
                return '百姓は震えながらも、年貢と水のことを語った。';
              })
            : Choice.h('殿に、畑を避けるよう申し上げる', '筋は通る。殿の機嫌しだい', () {
                if (g.rng.chance(.2 + g.l.fav / 150)) {
                  g.l.fav = _c100(g.l.fav + 3);
                  g.l.fame += 1;
                  return '殿は「もっともだ」とうなずき、鷹を呼び戻した。';
                }
                g.l.fav = _c100(g.l.fav - 4);
                return '殿は不機嫌に黙り込んだ。';
              }),
      ],
      after: next,
    );
  }),
  _again('ps_hawk', (g, next) {
    final head = _intro(g, 'ps_hawk', 'また鷹狩りに出た。', [
      '{季}、鷹狩りに出た。',
      '鷹匠が、今日の鷹は機嫌がいいと笑った。',
      '馬の背で風を切るのは、何よりの気晴らしだ。',
    ]);
    final lord = _ctx(g) == _Ctx.lord;
    g.ask('鷹狩り', '$head追い立てた大きな猪が、崖際へ逃げ込んだ。', [
      Choice.h('馬で深追いする', '大物が獲れる。崖は険しく、落ちれば無事では済まない', () {
        if (g.rng.chance(.03)) {
          g.die('鷹狩りで猪を追い、馬ごと谷へ落ちた', 'sai');
          return '馬が足を踏み外した。';
        }
        if (g.rng.chance(.35)) {
          g.l.hp -= 15;
          return '落馬し、しばらく足を引きずった。';
        }
        g.l.bu = _c(g.l.bu + 1);
        g.l.fame += 1;
        g.j(4);
        return '見事な猪を仕留めた。';
      }),
      Choice.h('手綱を引いて引き返す', '獲物は逃がす。怪我もない', () {
        g.j(1);
        return '猪は藪の向こうへ消えた。';
      }),
      Choice.h(lord ? '若い者に手柄を譲る' : '殿に獲物を譲る', '自分の手柄にはならない。周りは喜ぶ', () {
        if (lord) {
          g.l.net += 2;
        } else {
          g.l.fav = _c100(g.l.fav + 3);
        }
        return '獲物を譲った。帰りの道は賑やかだった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 湯治
  // ==================================================================
  _first('ps_onsen', (g, next) {
    g.ask('湯治場', '山あいの湯に着いた。湯けむりの向こうで、見知らぬ年寄りが手招きしている。', [
      Choice.h('並んで湯に浸かり、話し込む', '思わぬ縁が結べるかもしれない。長湯は体にさわる', () {
        g.l.net += 2;
        if (g.rng.chance(.5)) {
          g.meet('湯治場の縁', '湯治場で会った隠居', 40);
          g.setFlag('ps_onsen_friend');
          g.mark('湯治場で、遠国の隠居と縁を結んだ');
          return '年寄りは遠国の大きな家の隠居だった。いつでも訪ねてこい、と言う。';
        }
        g.l.hp -= 3;
        return '長話の末、少し湯あたりした。';
      }),
      Choice.h('碁の相手をする', '勝てば喜ばれ、負ければもっと喜ばれる', () {
        g.j(4);
        g.l.net += 1;
        return g.l.chi >= 55
            ? '三番打って二番勝った。年寄りは悔しがりながらも上機嫌だった。'
            : '手もなくひねられた。年寄りは上機嫌で酒をおごってくれた。';
      }),
      Choice.h('黙って湯に浸かる', '体がよく休まる。何も起きない', () {
        _heal(g, 20);
        g.j(2);
        return '湯の中で、長年の疲れがほどけていった。';
      }),
    ], after: next);
  }),
  _again('ps_onsen', (g, next) {
    final head = _intro(g, 'ps_onsen', 'また山の湯に浸かった。', [
      '{季}、山の湯に浸かった。',
      '湯治場の宿の主が、あなたの顔を見て笑った。',
      '湯の匂いをかぐと、体の痛みが和らぐ気がする。',
    ]);
    g.ask('湯治場', '$head帰る日の朝、山に雨雲がかかった。', [
      Choice.h('宿でもう一日待つ', '銭はかかる。体は無事だ', () {
        _pay(g, 2);
        _heal(g, 10);
        return '雨音を聞きながら、もう一日湯に浸かった。';
      }),
      Choice.h('雨をおして山を越える', '早く戻れる。ぬかるんだ崖道は危うい', () {
        if (g.rng.chance(.03)) {
          g.die('湯治の帰りに、雨の山道で足を滑らせた', 'sai');
          return 'ぬかるみに足を取られた。';
        }
        if (g.rng.chance(.3)) {
          g.l.hp -= 10;
          return '足をくじき、湯治の甲斐が半ば消えた。';
        }
        g.j(1);
        return 'ずぶ濡れになったが、無事に山を越えた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 弓・馬の稽古／槍の稽古
  // ==================================================================
  _first('ps_arms', (g, next) {
    if (g.l.rank <= 2) {
      g.ask('槍合わせ', '稽古場で、組頭が「腕を見てやる」と稽古槍を手に立った。足軽仲間が周りを囲んだ。', [
        Choice.h('本気で打ち込む', '勝てば名が上がる。組頭の面目を潰すかもしれない', () {
          if (g.l.bu + g.rng.range(0, 30) > 65) {
            g.l.merit += 5;
            g.l.fame += 1;
            g.mark('稽古の槍合わせで、組頭から一本取った');
            return '組頭の槍を払い、胸元に穂先を止めた。周りがどよめいた。';
          }
          g.l.hp -= 8;
          return '強かに打ち据えられた。「まだまだだな」と組頭が笑った。';
        }),
        Choice.h('胸を借りるつもりで受ける', '学ぶことが多い。手柄にはならない', () {
          g.l.bu = _c(g.l.bu + 2);
          return '何度も転がされながら、槍の間合いを体で覚えた。';
        }),
        Choice.h('組頭に花を持たせる', '組頭の覚えがよくなる。腕は伸びない', () {
          g.l.fav = _c100(g.l.fav + 4);
          return 'ほどよく負けてみせた。組頭は上機嫌だった。';
        }),
      ], after: next);
      return;
    }
    g.ask('弓始め', '年の初めの弓始めで、家中の者が居並ぶ前で的を射ることになった。', [
      Choice.h('的の真ん中を狙う', '当たれば名が上がる。外せば笑われる', () {
        if (g.rng.chance(.2 + g.l.bu / 120)) {
          g.l.fame += 2;
          g.l.fav = _c100(g.l.fav + 4);
          g.mark('弓始めで、的の真ん中を射抜いた');
          return '矢は的の真ん中に吸い込まれた。殿が扇を打ち鳴らした。';
        }
        g.j(-3);
        return '矢は的の縁をかすめて外れた。後ろで忍び笑いが聞こえた。';
      }),
      Choice.h('落ち着いて確かに当てる', '目立たないが、恥もかかない', () {
        g.l.fav = _c100(g.l.fav + 1);
        g.j(1);
        return '的の内に、確かに矢を収めた。';
      }),
      Choice.h('若い者に先を譲る', '若い者は喜ぶ。殿の目には留まらない', () {
        g.l.net += 2;
        return '若い者が射るのを、後ろから見守った。';
      }),
    ], after: next);
  }),
  _again('ps_arms', (g, next) {
    final head = _intro(g, 'ps_arms', 'また稽古場に立った。', [
      '{季}、稽古場に立った。',
      '稽古場の床が、汗で黒く光っている。',
      '若い者たちが、あなたの稽古を遠巻きに見ている。',
    ]);
    g.ask('稽古場', '$head稽古相手の若い者が、力みすぎて筋を痛めた。', [
      Choice.h('手当てして、力の抜き方を教える', '稽古は進まない。若い者に慕われる', () {
        g.l.net += 2;
        g.l.merit += 1;
        g.j(2);
        return '若い者は、次の日から誰よりも早く稽古場に来るようになった。';
      }),
      Choice.h('相手を替えて稽古を続ける', '腕は上がる。若い者は置いていかれる', () {
        g.l.bu = _c(g.l.bu + 1);
        g.l.hp -= 3;
        return '日が暮れるまで、槍と弓を振るい続けた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 荒れ野を拓く／網と沖
  // ==================================================================
  _first('ps_land', (g, next) {
    if (g.l.cls.id == 'fisher') {
      g.ask('網と沖', '網を繕い終えた。浜の年寄りが、今年は沖の潮が変わったと言う。', [
        Choice.h('年寄りの言う沖へ出る', '大漁もありうる。見慣れない海だ', () {
          if (g.rng.chance(.5)) {
            g.l.gold += 10;
            g.setFlag('ps_sea_luck');
            return '舟べりまで魚が上がった。浜の者が目を丸くした。';
          }
          g.l.hp -= 5;
          return '潮に流され、空の網を引いて戻った。';
        }),
        Choice.h('見慣れた磯で漁る', '獲れ高はほどほど。海は穏やかだ', () {
          g.l.gold += 3;
          return 'いつもの磯で、いつもどおりの魚が獲れた。';
        }),
        Choice.h('若い者に網の繕い方を教える', '漁は少ない。浜の者に慕われる', () {
          g.l.net += 2;
          g.j(2);
          return '若い者の指が、少しずつ網目を覚えていった。';
        }),
      ], after: next);
      return;
    }
    g.ask('荒れ野を拓く', '村はずれの荒れ野を拓くことにした。どこから鍬を入れる？', [
      Choice.h('川沿いの土地', '土は肥えている。大水が来れば流される', () {
        g.setFlag('ps_field_river');
        g.mark('川沿いの荒れ野を拓いた');
        return '川沿いに鍬を入れた。土は黒く、よく肥えている。';
      }),
      Choice.h('山裾の土地', '石が多く、実りは薄い。水に流される心配はない', () {
        g.setFlag('ps_field_hill');
        g.mark('山裾の荒れ野を拓いた');
        return '石を一つずつ掘り出した。手の皮が厚くなった。';
      }),
      Choice.h('隣村との境の野', '広くて平らだ。隣村が黙っているかは分からない', () {
        g.setFlag('ps_field_border');
        g.mark('隣村との境の野を拓いた');
        if (g.rng.chance(.4)) {
          g.j(-4);
          return '隣村の者が、境を越えていると怒鳴り込んできた。話はこじれたままだ。';
        }
        g.l.gold += 3;
        return '広い田が取れた。隣村は、今のところ何も言ってこない。';
      }),
    ], after: next);
  }),
  _again('ps_land', (g, next) {
    if (g.l.cls.id == 'fisher') {
      final head = _intro(g, 'ps_land', 'また沖へ出た。', [
        '{季}、また沖へ出た。',
        '朝靄の浜から、舟を押し出した。',
        '繕った網が、潮の匂いを吸っている。',
      ]);
      g.ask('沖の群れ', '$head沖に、魚の群れが見えた。', [
        Choice.h('群れを追って沖へ出る', '大漁になる。陸が見えなくなるほど遠い', () {
          if (g.rng.chance(.03)) {
            g.die('魚の群れを追って沖へ出たまま、戻らなかった', 'yukue');
            return '舟は、群れを追って沖の彼方へ消えた。';
          }
          if (g.rng.chance(.5)) {
            g.l.gold += 12;
            return '舟が沈みそうなほどの大漁だった。';
          }
          g.l.hp -= 5;
          return '群れを見失い、くたびれ果てて戻った。';
        }),
        Choice.h('群れの端だけを狙う', '獲れ高はほどほど。無理はしない', () {
          g.l.gold += 4;
          return '欲をかかずに網を上げ、日のあるうちに浜へ戻った。';
        }),
      ], after: next);
      return;
    }
    final head = _intro(g, 'ps_land', '今年も、拓いた田に出た。', [
      '{季}、拓いた田に出た。',
      '拓いた田の畦を、ゆっくりと歩いた。',
      '鍬の柄が、手の形にすり減ってきた。',
    ]);
    if (g.hasFlag('ps_field_river') && g.rng.chance(.5)) {
      g.ask('新しい田', '$head大雨が続き、川の水が田の際まで来た。', [
        Choice.h('夜通し土俵を積む', '田は守れるかもしれない。増した川辺は危うい', () {
          if (g.rng.chance(.02)) {
            g.die('増水した川辺で土俵を積むうち、流された', 'sai');
            return '足元の土が崩れた。';
          }
          if (g.rng.chance(.6)) {
            g.l.gold += 5;
            return '夜明けに水が引いた。田は守られた。';
          }
          g.j(-5);
          return '土俵は流され、田は泥に沈んだ。';
        }),
        Choice.h('村の高台へ逃げる', '命は守れる。田は運しだい', () {
          if (g.rng.chance(.5)) return '水は田の手前で引いた。胸をなでおろした。';
          g.j(-5);
          return '水が引くと、田は泥に埋まっていた。';
        }),
      ], after: next);
      return;
    }
    g.ask('新しい田', '$head拓いた田に、今年も穂が揺れている。実りをどうする？', [
      Choice.h('村の者に分ける', '暮らしは楽にならない。村の者は恩を忘れない', () {
        g.l.net += 3;
        g.l.fame += 1;
        g.j(3);
        return '米を分けた家々から、礼の青菜が届いた。';
      }),
      Choice.h('蔵に積む', '蔵は膨らむ。妬む者もいる', () {
        g.l.gold += 8;
        return '蔵の米俵が、また一つ増えた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 子の手習い
  // ==================================================================
  _first('ps_kid', (g, next) {
    final n = _kidName(g);
    g.ask('子の手習い', '$nが、字を覚える年頃になった。どうやって学ばせる？', [
      Choice.h('寺へ通わせる', '和尚への謝礼がいる。子は広い世間を知る', () {
        _pay(g, 3);
        g.setFlag('ps_kid_tera');
        _kidBond(g, 3);
        return '$nは、毎朝寺へ駆けていくようになった。';
      }),
      Choice.h('自分で教える', '手間はかかる。子との絆は深まる', () {
        g.setFlag('ps_kid_home');
        _kidBond(g, 10);
        g.j(4);
        if (g.l.chi >= 50) return '夜ごと灯の下で字を教えた。$nは飲み込みが早かった。';
        g.l.chi = _c(g.l.chi + 1);
        return '教えるうちに、自分も字を学び直すことになった。';
      }),
      Choice.h('字より先に家業を覚えさせる', '食べていく術が身につく。子は不満かもしれない', () {
        g.setFlag('ps_kid_work');
        g.l.gold += 2;
        _kidBond(g, -3);
        return '$nは口を尖らせながらも、仕事を覚えていった。';
      }),
    ], after: next);
  }),
  _again('ps_kid', (g, next) {
    final n = _kidName(g);
    final parent = g.l.female ? '母上' : '父上';
    final head = _intro(g, 'ps_kid', '今年も、$nの手習いを見てやった。', [
      '{季}、$nの手習いを見てやった。',
      '$nの字が、少しずつ大人びてきた。',
      '手習いの反故が、部屋の隅に積み上がっている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('子の手習い', '$head$nが、習った字で書いた文を差し出した。拙い字で「$parentへ」とある。', [
        Choice.h('文を大事にしまう', '子は喜ぶ。字の誤りはそのまま', () {
          _kidBond(g, 5);
          g.j(6);
          return '文を畳んで、懐の奥にしまった。';
        }),
        Choice.h('字の誤りを直してやる', '子の字は上達する。子は少しがっかりする', () {
          _kidBond(g, 1);
          g.j(2);
          return '朱を入れて返すと、$nは唇を噛んで書き直した。';
        }),
      ], after: next);
      return;
    }
    g.ask('子の手習い', '$head$nが、手習いの帰りに喧嘩をして、顔を腫らして帰ってきた。', [
      Choice.h('理由を聞かずに叱る', '筋は通す。子は口を閉ざすかもしれない', () {
        _kidBond(g, -4);
        return '$nは黙って、夕餉に手をつけなかった。';
      }),
      Choice.h('まず訳を聞く', '子は心を開く。甘いと言われるかもしれない', () {
        _kidBond(g, 6);
        g.j(2);
        return '友をかばっての喧嘩だった。$nの頭を、黙って撫でた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 琴と香（奥で仕える女性）
  // ==================================================================
  _first('ps_koto', (g, next) {
    g.ask('琴と香', '奥方さまが、宴の席で琴の弾ける者はいないかとお尋ねになった。', [
      Choice.h('名乗り出て弾く', 'うまくいけば奥方さまの覚えがめでたい。しくじれば恥', () {
        if (g.rng.chance(.25 + g.l.mi / 120)) {
          g.l.fav = _c100(g.l.fav + 8);
          g.l.merit += 3;
          g.setFlag('ps_koto_played');
          g.mark('奥方さまの宴で、琴を弾いた');
          return '弦の音が座に満ちた。奥方さまが、手ずから菓子を下された。';
        }
        g.l.fav = _c100(g.l.fav - 2);
        g.j(-4);
        return '指がもつれ、弦が鳴りそこねた。顔から火が出る思いだった。';
      }),
      Choice.h('香を焚いて座を整える役を申し出る', '目立たないが、気が利くと思われる', () {
        g.l.fav = _c100(g.l.fav + 3);
        return '香の煙が、宴の座を静かに包んだ。';
      }),
      Choice.h('控えている', '何も起きない。務めに障りもない', () {
        return '琴は、年かさの女中が弾いた。';
      }),
    ], after: next);
  }),
  _again('ps_koto', (g, next) {
    final head = _intro(g, 'ps_koto', 'また奥で琴を習った。', [
      '{季}、奥で琴の稽古をした。',
      '香の名を、またいくつか覚えた。',
      '奥の廊下に、琴の音が流れている。',
    ]);
    g.ask('香合わせ', '$head奥で、香を聞き当てる香合わせの席が開かれた。', [
      Choice.h('言い当てて勝ちにいく', '勝てば一目置かれる。勝ちすぎれば妬まれる', () {
        if (g.rng.chance(.5)) {
          g.l.fav = _c100(g.l.fav + 3);
          g.j(3);
          return '香の名を次々に言い当てた。上臈の方が、目を細めた。';
        }
        g.j(-2);
        return '最後の一つで聞き違えた。';
      }),
      Choice.h('ほどほどにして座を和ませる', '座が和む。目立たない', () {
        g.l.net += 1;
        g.j(2);
        return '笑いの絶えない席になった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 書物を写す
  // ==================================================================
  _first('ps_book', (g, next) {
    final monk = _ctx(g) == _Ctx.monk;
    g.ask('写本', '写す書物を借りられることになった。どれを写す？', [
      Choice.h('兵法の書', '戦の理が分かる。読むだけで強くはならない', () {
        g.l.chi = _c(g.l.chi + 2);
        if (g.canFight && !monk) g.l.bu = _c(g.l.bu + 1);
        g.setFlag('ps_book_war');
        return '陣立ての図を、一枚ずつ写し取った。';
      }),
      Choice.h('医薬の書', '薬の知恵がつく。いつか誰かを救うかもしれない', () {
        g.l.chi = _c(g.l.chi + 1);
        g.setFlag('ps_book_med');
        g.mark('医薬の書を写し、薬の知恵を得た');
        return '草の名と煎じ方を、細かな字で書き写した。';
      }),
      monk
          ? Choice.h('経典', '功徳を積む。心が澄む', () {
              g.j(5);
              g.l.fame += 1;
              return '一字ごとに手を合わせるように、経を写した。';
            })
          : Choice.h('古い物語や歌の書', '心が豊かになる。暮らしの役には立たない', () {
              g.j(6);
              g.l.mi = _c(g.l.mi + 1);
              return '遠い昔の恋の歌に、ふと手が止まった。';
            }),
    ], after: next);
  }),
  _again('ps_book', (g, next) {
    final head = _intro(g, 'ps_book', 'また書物を写した。', [
      '{季}、灯の下で筆を執った。',
      '写し終えた書が、棚に並びはじめた。',
      '墨をする音だけが、部屋に響いている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('写本', '$head借りた古い書の間から、山の印を描いた古い絵図が落ちた。', [
        Choice.h('絵図をたどって山へ入る', '何かが埋まっているのかもしれない。ただの落書きかもしれない', () {
          if (g.rng.chance(.15 + g.l.un / 400)) {
            g.l.gold += 20;
            g.mark('古い書に挟まれた絵図をたどり、埋められた銭を掘り当てた');
            return '印の岩の根元から、古い銭の詰まった壺が出てきた。';
          }
          g.l.hp -= 5;
          g.j(-2);
          return '山を三日歩き回り、何も見つからなかった。';
        }),
        Choice.h('持ち主に返す', '正直は損をしない。得もしない', () {
          g.l.net += 1;
          g.l.fame += 1;
          return '持ち主は絵図を見て、懐かしそうに笑った。';
        }),
      ], after: next);
      return;
    }
    g.ask('写本', '$head写した書を、ぜひ譲ってほしいという者が訪ねてきた。', [
      Choice.h('譲って銭にする', '銭になる。手元からは書が消える', () {
        g.l.gold += 6;
        return '写しは、思いのほかよい値で引き取られた。';
      }),
      Choice.h('貸すだけにする', '銭にはならない。縁はつながる', () {
        g.l.net += 2;
        return '借りた者は、礼に珍しい書を貸してくれた。';
      }),
    ], after: next);
  }),
];
