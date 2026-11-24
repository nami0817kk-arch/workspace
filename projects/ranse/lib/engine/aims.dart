import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 心がけに足した三つ（2026-11-25、ユーザーが決めた項目）。
///
/// - **謀反の支度をする**（`gk_`）: 城主〜宿老（位5〜7）で戦える人の心がけ。選んだ年ごとに支度が積もり（旗 `gk_prep:<n>`）、
///   積もるほど「下剋上の誘い」（`adult.dart` の `gekokujo`）が来やすく、成功しやすくなる（[gkPrepBonus]、`Game.betrayChance`）。
///   支度は露見しうる（[gkExposeChance]。主君の信頼が高いほど疑われにくい）。露見すると詰問の岐路（申し開き・腹を切る・国を逃れる・先に兵を挙げる）。
///   支度が [kGkReady] に届けば、誘いを待たずに自分から兵を挙げる岐路が出る。
/// - **縁のある人を訪ねる**（`vz_`）: `l.people` にいる縁の人（幼なじみ・師・好敵手・弟妹・弟子・朋輩 ほか。伴侶・子・主君・有名人は除く）を、
///   年ごとに一人か二人、心がけの候補に出す（乱数を使わずに年で決める）。訪ねると絆（`Person.bond`）が上がり、ときに短い岐路
///   （昔語り・頼みごと・揉めごと）が起きる。最期の場にいる人（`ending.dart` の `_witness`）は絆の深い順なので、訪ねた人が最期に来やすい。
///   縁の物語（`bonds.dart`）の段の決まりには触れない（場面の id が別で、段の旗も立てない）。
/// - **よその家に仕え直す道を探る**（`kg_`）: 主家に仕える位1〜7の人の心がけ。選ぶと必ず岐路が起き、主家に近い家から二つほど誘いが来る。
///   勢いのある家は位を一つ下げて迎え、並か小さな家は位はそのまま（匂わせに書く）。移ると主君が変わり、主君の信頼は低いところから始まる。
///   主君に知られると、とどまっても咎め（信頼と功が下がる）を受ける。見聞録と歩んだ道に残す。
///
/// どれも新しい `die()` は謀反の露見だけ。死ぬ結果は匂わせに書いてある。

// ======================================================================
// 謀反の支度
// ======================================================================

/// 自分から兵を挙げられる支度の段。
const kGkReady = 4;

/// 自分から兵を挙げるときに、成功の見込みに掛ける倍率。
const kGkSelfRise = .7;

/// 積もった支度（選んだ年の数。露見・挙兵・解いたら0に戻る）。
int gkPrep(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('gk_prep:')) return int.tryParse(f.substring(8)) ?? 0;
  }
  return 0;
}

void _setPrep(Game g, int n) {
  g.l.flags.removeWhere((f) => f.startsWith('gk_prep:'));
  if (n > 0) g.setFlag('gk_prep:$n');
}

/// 謀反の支度をしていたことを消す（挙兵した・露見した・解いた）。
void gkClear(Game g) => _setPrep(g, 0);

/// 支度ができる身（城主〜宿老で戦える、主家が生きている、隠居でも仏門でもない）。
bool gkCan(Game g) {
  final l = g.l;
  return l.rank >= 5 &&
      l.rank <= 7 &&
      l.lord != null &&
      (g.fa[l.lord]?.alive ?? false) &&
      g.canFight &&
      g.active &&
      !g.hasFlag('priesthood');
}

/// 支度で上がる下剋上の成功の見込み（`Game.betrayChance` に足す）。四つまで積もる。
/// 自分から兵を挙げられるようにした分、一つあたりは小さくした（測って決めた。CLAUDE.md の「自分から下剋上を狙う」）。
double gkPrepBonus(Game g) {
  final n = gkPrep(g);
  return (n > 4 ? 4 : n) * .02;
}

/// 支度で上がる「下剋上の誘い」の来やすさ（`gekokujo` の重みに足す）。
double gkInviteWeight(Game g) {
  final n = gkPrep(g);
  return (n > 5 ? 5 : n) * .4;
}

/// 支度が露見する見込み（支度の年ごと）。積もるほど、主君の信頼が低いほど露見しやすい。
double gkExposeChance(Game g) =>
    clampD(.04 + gkPrep(g) * .025 + (40 - g.l.fav) / 400, .02, .3);

String _riseHint(double p) {
  if (p >= .55) return '機は熟している。敗れれば、命はない';
  if (p >= .3) return '分の悪い賭けではない。敗れれば、命はない';
  return '家中にはまだ主君を慕う者が多い。敗れれば、命はない';
}

/// 兵を挙げる（`Game.doBetray` を通す。支度は消える）。
String _rise(Game g, double p) {
  gkClear(g);
  g.setFlag('gk_rose');
  final r = g.doBetray(p);
  if (g.l.rank == 8) {
    g.mark('主家を討ち、${houseName(g, g.l.lord)}家を乗っ取った');
  }
  return r;
}

FocusDef? _gkFocus(Game g) {
  if (!gkCan(g)) return null;
  return FocusDef(
    'gk_prep',
    '謀反の支度をする',
    '家中の不満を束ね、密かに時を待つ。露見すれば、命はない',
    (g) => _setPrep(g, gkPrep(g) + 1),
    forced: 'gk_plot',
  );
}

void _gkPlot(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  if (g.rng.chance(gkExposeChance(g))) {
    _gkExposed(g, next);
    return;
  }
  final n = gkPrep(g);
  if (n >= kGkReady) {
    // 誘いを待たずに自分から挙げる兵は、担ぐ者たちの勢いがないぶん、誘いに乗るより少し分が悪い。
    final p = g.betrayChance() * kGkSelfRise;
    g.ask('挙兵の時', '支度は整った。味方に付いた将も兵も、合図を待っている。$house家を討つか。', [
      Choice.h('兵を挙げる', _riseHint(p), () => _rise(g, p)),
      Choice.h('まだ機を待つ', '支度は保てる。待つほど、露見の恐れは増す', () => '合図は出さず、もう一年待つことにした。'),
      Choice.h('支度を解き、主君に仕え直す', '企ては消える。家中の疑いも、いずれ晴れる', () {
        gkClear(g);
        l.fav = clampInt(l.fav + 5, 0, 100);
        g.j(2);
        return '味方の将たちに詫びを入れ、企てを解いた。胸のつかえが下りた。';
      }),
    ], after: () => _thenUsual(g, next));
    return;
  }
  final head = n <= 1
      ? '$house家の主君への不満を口にする者たちと、ひそかに会った。'
      : '支度は少しずつ形になってきた。夜ごと、屋敷に人が出入りする。';
  g.ask('謀反の支度', '$head今年は何を進める？', [
    Choice.h('不満を抱く家臣を味方に引き入れる', '支度は大きく進む。口の軽い者が混じれば、露見しやすくなる', () {
      _setPrep(g, gkPrep(g) + 1);
      l.fav = clampInt(l.fav - 3, 0, 100);
      return '不満を抱く家臣を、一人また一人と味方に引き入れた。';
    }),
    Choice.h('兵糧と武具を密かに蓄える', '銭がかかる。挙兵のときの兵が増える', () {
      final c = l.gold < 20 ? l.gold : 20;
      l.gold -= c;
      l.troops += 5;
      return '蔵の奥に、兵糧と武具を少しずつ運び込ませた。';
    }),
    Choice.h('表では務めに励み、疑いをそらす', '支度は進まないが、主君の目は和らぐ', () {
      l.fav = clampInt(l.fav + 4, 0, 100);
      return '評定ではいつもより口数を増やし、主君の覚えをつないだ。';
    }),
  ], after: () => _thenUsual(g, next));
}

void _gkExposed(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  final n = gkPrep(g);
  gkClear(g);
  g.setFlag('gk_exposed');
  final p = g.betrayChance() * .7;
  g.ask('謀反の露見', '支度の噂が、$house家の主君の耳に入った。評定の間に呼び出され、詰問を受ける。', [
    Choice.h('申し開きをする', '言葉ひとつで首がつながるかもしれない。しくじれば、腹を切らされる', () {
      final ok = g.rng.chance(
        clampD(.3 + (l.mi + l.chi) / 400 + l.fav / 300, .15, .8),
      );
      if (ok) {
        l.fav = clampInt(l.fav - 15, 0, 100);
        g.j(-6);
        return '讒言に過ぎぬと言い張り、どうにか首はつながった。だが主君の目は冷えた。';
      }
      g.die('謀反の企てを問われ、腹を切らされた', 'seppuku');
      return '申し開きは通らなかった。その夜、腹を切るよう命じられた。';
    }),
    Choice.h('潔く腹を切る', '家の名は守れるかもしれない。命はない', () {
      g.die('謀反の企てを詫び、自ら腹を切った', 'seppuku');
      return '言い訳はせず、静かに腹を切ると申し出た。';
    }),
    Choice.h('国を逃れる', '命は拾えるかもしれない。身分も主家も失う', () {
      if (g.rng.chance(.2)) {
        g.die('謀反の企てが露見し、逃れる途中で討手に討たれた', 'ansatsu');
        return '夜陰に紛れて逃れたが、峠で討手に追いつかれた。';
      }
      l
        ..rank = 0
        ..lord = null
        ..troops = 0
        ..fav = 0
        ..ronin = true
        ..gold = (l.gold * .3).floor();
      l.fame -= 10;
      g.j(-15);
      g.mark('謀反の企てが露見し、国を逃れた');
      return '屋敷を捨て、わずかな供と国境を越えた。主も身分も、もう無い。';
    }),
    if (n >= 2 && g.canFight)
      Choice.h('先に兵を挙げる', '支度は半ば。勝てば主家を乗っ取れる。敗れれば、命はない', () => _rise(g, p)),
  ], after: () => _thenUsual(g, next));
}

// ======================================================================
// 縁のある人を訪ねる
// ======================================================================

/// 訪ねられる縁の役割と、匂わせ（伴侶・子・主君・有名人は入れない）。並びは候補の順。
const kVisitRoles = <String, String>{
  '幼なじみ': '昔の話に花が咲く。幼い日の絆がよみがえる',
  '師': '教えを受けた日々を思い出す。師の言葉は今も効く',
  '好敵手': '張り合った相手と膝を交える。わだかまりが解けるかもしれない',
  '弟妹': '離れて暮らす弟妹の顔を見る。家の話もしたい',
  '弟子': '育てた者の様子を見に行く。頼られることもある',
  '手習いの仲間': '机を並べた仲間と会う。互いの暮らしは違ってしまった',
  '奥の朋輩': '奥で共に仕えた朋輩と会う。積もる話がある',
  '片割れ': '血を分けた片割れと会う。言葉より先に通じるものがある',
  '連歌の友': '旅の連歌師と一座を囲む。歌は人の縁をつなぐ',
  '湯治場の縁': '湯治場で知り合った隠居を訪ねる。老いた人の話は深い',
  '同郷の仲間': '同じ村から出た仲間と会う。故郷の話が尽きない',
  '古参の足軽': '槍の心得を教えてくれた古参を訪ねる',
  '忍びの仲間': '里の仲間とひそかに会う。人目は避けねばならない',
  '恩のある豪商': '恩のある商人に挨拶に行く。手土産が要る',
  '商いの恩人': '商いの恩人に挨拶に行く。手土産が要る',
  '馬喰の縁': '馬喰に会いに行く。馬の話なら尽きない',
  '槍の弟子': '槍を教えた若者の様子を見に行く',
  '武芸の弟子': '武芸を教えた者の様子を見に行く',
  '薙刀の弟子': '薙刀を教えた者の様子を見に行く',
  '職人の弟子': '技を教えた弟子の仕事場を見に行く',
  '鉄砲の弟子': '鉄砲を教えた者の様子を見に行く',
  '若い足軽': '目をかけた若い足軽の様子を見に行く',
  '手習いの教え子': '手習いを教えた子の様子を見に行く',
  '侍女': '仕えてくれた侍女の暮らしを見に行く',
  '身分違いの友': '身分の違う友と会う。人目を気にせず話せる',
};

/// いま訪ねられる縁の人（役割の並び順）。
List<Person> visitCandidates(Game g) => [
  for (final r in kVisitRoles.keys)
    if (g.l.people[r] != null && !personDied(g, g.l.people[r]!.name))
      g.l.people[r]!,
];

/// この年に心がけに出す、訪ねる人（乱数を使わずに年で決める。候補が三人からは二人）。
List<Person> visitPicks(Game g) {
  final c = visitCandidates(g);
  if (c.isEmpty) return const [];
  final i = g.year % c.length;
  if (c.length < 3) return [c[i]];
  return [c[i], c[(i + 1) % c.length]];
}

/// 訪ねている人の役割（旗 `vz_who:<役割>`）。
String? _visiting(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('vz_who:')) return f.substring(7);
  }
  return null;
}

List<FocusDef> _visitFocus(Game g) {
  if (g.age < 16 || g.isChild) return const [];
  return [
    for (final p in visitPicks(g))
      FocusDef('vz', '${p.name}を訪ねる', kVisitRoles[p.role]!, (g) {
        g.l.flags.removeWhere((f) => f.startsWith('vz_who:'));
        g.setFlag('vz_who:${p.role}');
        final q = g.l.people[p.role];
        if (q != null) q.bond = clampInt(q.bond + g.rng.range(6, 12), 0, 100);
        g.l.net += 1;
        g.l.hp -= 2;
        g.j(3);
      }, forced: 'vz_visit'),
  ];
}

/// 訪ねた年に短い岐路が起きる見込み。
const kVisitSceneChance = .45;

void _visit(Game g, void Function() next) {
  final role = _visiting(g);
  g.l.flags.removeWhere((f) => f.startsWith('vz_who:'));
  final p = role == null ? null : g.l.people[role];
  if (p == null || !g.rng.chance(kVisitSceneChance)) {
    // 岐路が起きなかった年は、ふつうの年と同じく岐路を引く（訪ねたことが、その年の岐路を押しのけない）。
    g.usualYearScene();
    return;
  }
  final l = g.l;
  final name = p.name;
  void bond(int d) => p.bond = clampInt(p.bond + d, 0, 100);
  final kind = g.rng.wpick([0, 1, 2], (k) => [3.0, 2.0, 1.5][k]);
  switch (kind) {
    case 0:
      g.ask('昔語り', '$nameのもとを訪ねた。湯を沸かす間にも、昔の話が次々と出てくる。', [
        Choice.h('夜更けまで語り明かす', '絆はいっそう深まる。翌朝はつらい', () {
          bond(6);
          g.j(4);
          l.hp -= 2;
          return '$nameと、夜が白むまで語り明かした。';
        }),
        Choice.h('胸の内の悩みを打ち明ける', '聞いてもらえば、心が軽くなる', () {
          bond(4);
          g.j(3);
          return '誰にも言えずにいたことを、$nameにだけ打ち明けた。';
        }),
        Choice.h('早めに辞する', '長居はしない。何も変わらない', () {
          bond(1);
          return '茶を一杯もらい、日のあるうちに辞した。';
        }),
      ], after: () => _thenUsual(g, next));
    case 1:
      final c = l.gold < 15 ? l.gold : 15;
      g.ask('縁の人の頼み', '$nameが、言いにくそうに頼みごとを切り出した。暮らしが苦しく、手を貸してほしいという。', [
        if (c > 0)
          Choice.h('銭を用立てる', '蓄えは減る。恩は残る', () {
            l.gold -= c;
            bond(10);
            g.setFlag('vz_lent');
            return '$nameに銭を用立てた。何度も頭を下げられた。';
          }),
        Choice.h('口を利いて働き口を探す', '人の縁を使う。うまくいけば喜ばれる', () {
          if (l.net > 0) l.net -= 1;
          bond(g.rng.chance(.6) ? 8 : 2);
          return '知り合いに頼み、$nameの働き口を探して回った。';
        }),
        Choice.h('断る', '縁は冷える', () {
          bond(-8);
          g.j(-2);
          return '「今は手が回らぬ」と断った。$nameは黙って頷いた。';
        }),
      ], after: () => _thenUsual(g, next));
    default:
      g.ask('縁の人との諍い', '$nameと、つまらぬことで言い争いになった。互いに引っ込みがつかない。', [
        Choice.h('先に頭を下げる', '縁は守れる。少し悔しい', () {
          bond(5);
          g.j(-1);
          return '先に頭を下げた。$nameも笑って詫びを返した。';
        }),
        Choice.h('酒を酌み交わして水に流す', '酒代はかかる。酔えば元どおり', () {
          if (l.gold >= 2) l.gold -= 2;
          bond(3);
          g.j(2);
          return '酒を酌み交わすうち、何で揉めたのかも忘れた。';
        }),
        Choice.h('言い分を通す', '筋は通る。縁は冷える', () {
          bond(-10);
          return '一歩も引かずに帰った。$nameとは、しばらく音信が途絶えた。';
        }),
      ], after: () => _thenUsual(g, next));
  }
}

// ======================================================================
// 主家を移る
// ======================================================================

/// 仕え直す道を探れる身（主家に仕える位1〜7、隠居でも仏門でもない、主家が生きている。移った年から二年はあける）。
bool kgCan(Game g) {
  final l = g.l;
  if (l.rank < 1 || l.rank > 7 || l.lord == null) return false;
  if (!(g.fa[l.lord]?.alive ?? false) || !g.active) return false;
  if (g.hasFlag('priesthood')) return false;
  if (_kgSince(g) < 2) return false;
  return kgOffers(g).length >= 2;
}

int _kgSince(Game g) {
  int? y;
  for (final f in g.l.flags) {
    if (f.startsWith('kg_moved@')) y = int.tryParse(f.substring(9));
  }
  return y == null ? 999 : g.year - y;
}

/// 誘いの来うる家（主家に近い、生きている家。自分が当主の家は無い）。
List<Faction> kgOffers(Game g) {
  final lord = g.l.lord!;
  return nearest(
    g.alive.where((f) => f.name != lord),
    (f) => f.name,
    faction: lord,
    n: 4,
  );
}

/// 誘ってきた家の勢い（2 勢いのある家・1 並・0 小さな家）。
int kgStrength(Game g, Faction f) {
  final ps = g.alive.map((f) => f.power).toList()..sort();
  final mid = ps[ps.length ~/ 2];
  if (f.power > mid * 1.3) return 2;
  if (f.power < mid * .7) return 0;
  return 1;
}

/// 移った先の位（勢いのある家は一つ下げて迎え、ほかはそのまま）。
int kgNewRank(Game g, Faction f) {
  final r = g.l.rank;
  return kgStrength(g, f) == 2 ? (r - 1 < 1 ? 1 : r - 1) : r;
}

/// 主君に知られる見込み（主君の信頼が低いほど、目を付けられている）。
double kgNoticeChance(Game g) => clampD(.2 + (40 - g.l.fav) / 300, .08, .4);

FocusDef? _kgFocus(Game g) {
  if (!kgCan(g)) return null;
  return FocusDef(
    'kg_seek',
    'よその家に仕え直す道を探る',
    '近い家からの誘いを待つ。主君に知られれば、咎めを受ける',
    (g) => g.l.net += 1,
    forced: 'kg_offer',
  );
}

void _kgOffer(Game g, void Function() next) {
  final l = g.l;
  final cur = l.lord!;
  final pool = kgOffers(g);
  // 勢いのいちばんある家と、もう一つ（近い家から）。
  final strong = [...pool]..sort((a, b) => b.power.compareTo(a.power));
  final first = strong.first;
  final rest = pool.where((f) => f != first).toList();
  final second = rest[g.rng.range(0, rest.length - 1)];
  final offers = [first, second];
  final known = g.rng.chance(kgNoticeChance(g));
  String hint(Faction f) => switch (kgStrength(g, f)) {
    2 => '勢いのある家。迎えはするが、位は一つ下がる。出世の目は大きい',
    1 => '並の家。位はそのままで迎えるという',
    _ => '小さな家。位はそのままで、重く用いるという。先は細い',
  };
  g.ask(
    l.female ? '奥替えの誘い' : '仕え直す誘い',
    '人づてに、近い家々の意向を探った。${offers.map((f) => '${houseName(g, f.name)}家').join('と')}から、迎えたいという話が来た。'
    '${known ? '\nだが、この動きは${houseName(g, cur)}家の主君の耳にも入ったらしい。' : ''}',
    [
      for (final f in offers)
        Choice.h('${houseName(g, f.name)}家に移る', hint(f), () {
          final prev = houseName(g, cur);
          final to = houseName(g, f.name);
          final r = kgNewRank(g, f);
          final down = r < l.rank;
          l
            ..lord = f.name
            ..rank = r
            ..fav = 25
            ..merit = (l.merit * .5).round()
            ..troops = (l.troops * .5).floor();
          if (known) l.fame -= 3;
          g.l.flags.removeWhere((x) => x.startsWith('kg_moved@'));
          g.setFlag('kg_moved@${g.year}');
          g.setFlag('kg_moved');
          g.j(down ? -2 : 3);
          g.mark('$prev家を去り、$to家に仕え直した');
          return '$prev家に暇を乞い、$to家に移った。位は${g.rk[r]}${down ? 'に下がった' : 'のまま'}。'
              '${known ? '去り際、旧主の目は冷たかった。' : ''}';
        }),
      Choice.h(
        '今の主家にとどまる',
        known ? '話は断る。探ったことは知られている。咎めは免れない' : '話は断る。何事もなかったように務めに戻る',
        () {
          if (!known) return '誘いはありがたく聞くだけにして、${houseName(g, cur)}家での務めに戻った。';
          l.fav = clampInt(l.fav - 15, 0, 100);
          l.merit = l.merit - 10 < 0 ? 0 : l.merit - 10;
          g.j(-5);
          return 'よその家と通じたと咎められ、しばらく出仕を差し止められた。';
        },
      ),
    ],
    after: () => _thenUsual(g, next),
  );
}

// ======================================================================
// 入り口と登録
// ======================================================================

/// 大人の「この年の心がけ」に足す三つ（謀反の支度・縁の人を訪ねる・仕え直す道を探る）。
List<FocusDef> aimFocusOptions(Game g) {
  if (g.isChild) return const [];
  final out = <FocusDef>[];
  final gk = _gkFocus(g), kg = _kgFocus(g);
  if (gk != null) out.add(gk);
  if (kg != null) out.add(kg);
  return out..addAll(_visitFocus(g));
}

List<SceneDef> buildAimScenes() => [
  SceneDef(
    'gk_plot',
    15,
    99,
    (g) => 1,
    gkCan,
    _gkPlot,
    repeat: true,
    onlyForced: true,
  ),
  SceneDef(
    'vz_visit',
    15,
    99,
    (g) => 1,
    (g) => true,
    _visit,
    repeat: true,
    onlyForced: true,
  ),
  SceneDef(
    'kg_offer',
    15,
    99,
    (g) => 1,
    kgCan,
    _kgOffer,
    repeat: true,
    onlyForced: true,
  ),
];

/// 心がけで起きた岐路のあとに、ふつうの年と同じく岐路を引く（この三つの岐路が、その年のほかの岐路を押しのけない。
/// 押しのける形だと、中堅の侍・野の道・河原者の人生で、それぞれの道の岐路が減った）。亡くなっていれば年の終わりへ。
void _thenUsual(Game g, void Function() next) =>
    g.finished ? next() : g.usualYearScene();
