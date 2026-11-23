import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 忍び・流れ者・野盗の一生の岐路（2026-11-23）。id・旗は `sh_`（忍び `sh_n_`・抜け忍 `sh_nk_`・流れ者と野盗 `sh_o_`）。
///
/// 野に生きる道（`ways.dart` の獲物・山狩り・刺客の依頼・里の掟・追手・旅路・足を洗う）と、
/// 忍びの務め（`adult.dart`）のほかに、この道の大人の岐路がなかったので足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kShadowPrev]）。段を踏んだ年は
/// 旗 `sh_at:<筋>:<年>` に残し、次の段は何年か空けてから出す（[kShadowGap]）。
///
/// - 忍びの筋: 頭の仕事（頭の仕事 → 雇い主を選ぶ → 里の跡目か抜けるか／両方に通じたことの露見）／
///   仲間（捕らわれた仲間 → 見捨てた仲間の恨み・救った仲間の恩）／薬と毒（薬と毒の術 → 毒の役目・病の村）。
/// - 抜け忍の筋: 名を変えた暮らし → 旧知の追手。
/// - 流れ者・野盗の筋: 山の一味（頭の跡目 → 手下の掟 → 一味の行く末）／用心棒（用心棒 → 野盗の襲来 → 村に根付くか）／
///   落ち武者（落ち武者狩り → 逃がした武者の恩）。
/// - ひとつきり: 変装して城下へ・天正の伊賀の戦（一五七九年・一五八一年。近江の里は甲賀として書き分ける）・
///   伊賀の落人・街道の関・陣借り・賭場・旅の一座の護衛。
/// - 能力（武・知・魅・運）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

bool _base(Game g) =>
    g.l.rank == 0 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    !g.hasFlag('way_merchant');

/// 里に残る忍び（抜けず、野にも出ていない）。
bool shSato(Game g) =>
    _base(g) &&
    g.l.cls.id == 'ninja' &&
    !g.hasFlag('nukenin') &&
    !g.hasFlag('way_outlaw');

/// 里を抜けた忍び。
bool shNuke(Game g) => _base(g) && g.hasFlag('nukenin');

/// 野に生きる者（野盗・流れ者・抜け忍）。
bool shOutlaw(Game g) => _base(g) && g.hasFlag('way_outlaw');

/// 野盗（流れ者でも抜け忍でもない）。
bool shBandit(Game g) =>
    shOutlaw(g) && !g.hasFlag('wanderer') && !g.hasFlag('nukenin');

/// 足を洗った者（野の暮らしをやめ、村に暮らす）。
bool shReformed(Game g) =>
    _base(g) && g.hasFlag('reformed') && !g.hasFlag('way_outlaw');

/// この道の岐路が出てよい人（どれかに当たる）。テストも使う。
bool shadowLife(Game g) =>
    shSato(g) || shNuke(g) || shOutlaw(g) || shReformed(g);

bool _ninja(Game g) => shSato(g) || shNuke(g);
bool _road(Game g) => shOutlaw(g) || shNuke(g);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kShadowPrev = <String, List<String>>{
  'sh_n_lords': ['sh_trust'],
  'sh_n_double': ['sh_hired_both'],
  'sh_n_atome': ['sh_lord_near', 'sh_lord_far', 'sh_lord_none'],
  'sh_n_grudge': ['sh_left_comrade'],
  'sh_n_repay': ['sh_saved_comrade'],
  'sh_n_poison': ['sh_herb_poison'],
  'sh_n_cure': ['sh_herb_med'],
  'sh_nk_hunter': ['sh_nk_town', 'sh_nk_village', 'sh_nk_temple'],
  'sh_o_band_rule': ['sh_band_head'],
  'sh_o_band_end': ['sh_band_code', 'sh_band_loose'],
  'sh_o_yojin_raid': ['sh_yojin_kept', 'sh_yojin_greedy'],
  'sh_o_settle': ['sh_yojin_fought', 'sh_yojin_saved'],
  'sh_o_ochi_repay': ['sh_ochi_spared'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kShadowGap = <String, (String, int)>{
  'sh_n_lords': ('kashira', 2),
  'sh_n_double': ('kashira', 2),
  'sh_n_atome': ('kashira', 3),
  'sh_n_grudge': ('comrade', 3),
  'sh_n_repay': ('comrade', 3),
  'sh_n_poison': ('herb', 2),
  'sh_n_cure': ('herb', 2),
  'sh_nk_hunter': ('newlife', 3),
  'sh_o_band_rule': ('band', 1),
  'sh_o_band_end': ('band', 3),
  'sh_o_yojin_raid': ('yojin', 1),
  'sh_o_settle': ('yojin', 1),
  'sh_o_ochi_repay': ('ochi', 4),
};

/// この道の岐路の id（テストが使う）。
const kShadowLifeIds = [
  'sh_n_kashira',
  'sh_n_lords',
  'sh_n_double',
  'sh_n_atome',
  'sh_n_comrade',
  'sh_n_grudge',
  'sh_n_repay',
  'sh_n_herb',
  'sh_n_poison',
  'sh_n_cure',
  'sh_n_henso',
  'sh_n_iga_first',
  'sh_n_iga_second',
  'sh_n_iga_exiles',
  'sh_nk_newlife',
  'sh_nk_hunter',
  'sh_o_seki',
  'sh_o_band',
  'sh_o_band_rule',
  'sh_o_band_end',
  'sh_o_yojinbo',
  'sh_o_yojin_raid',
  'sh_o_settle',
  'sh_o_jingari',
  'sh_o_bakuchi',
  'sh_o_goei',
  'sh_o_ochimusha',
  'sh_o_ochi_repay',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('sh_at:$chain:'));
  g.setFlag('sh_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int shSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('sh_at:$chain:')) {
      return g.year - int.parse(f.substring('sh_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool shChainReady(Game g, String id) {
  final prev = kShadowPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kShadowGap[id];
  if (gap == null) return true;
  return shSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;
void _lose(Game g, double rate) => g.l.gold = (g.l.gold * (1 - rate)).floor();

/// 今いる国の近くの家（勢いの順）。足りなければ呼び名で埋める。
List<String> _nearHouses(Game g, int n) {
  final near = nearest(g.alive, (f) => f.name, region: g.l.region, n: n + 1);
  near.sort((a, b) => b.power.compareTo(a.power));
  final out = [for (final f in near.take(n)) '${houseName(g, f.name)}家'];
  const fill = ['近くの大名家', '隣国の大名家', '遠国の大名家'];
  for (var i = 0; out.length < n; i++) {
    out.add(fill[i % fill.length]);
  }
  return out;
}

/// 里が近江にある忍びは甲賀の者として書く。
bool _koka(Game g) => g.l.region == '近江';

/// 織田の伊賀攻めが起きる世か（今川が生き延びた世では、織田は早くに滅んでいる）。
bool _odaIga(Game g) => worldLine(g) != 'imagawa';

/// 重み。筋の始まり・ひとつきりは [_w1]、前の段を踏んだ人だけに出る後段は [_w2]。
const _w1 = 3.0;
const _w2 = 8.0;

SceneDef _chain(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run,
) => SceneDef(
  id,
  minAge,
  maxAge,
  (g) => w,
  (g) => who(g) && shChainReady(g, id),
  run,
);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildShadowLifeScenes() => [
  ..._ninjaScenes(),
  ..._nukeScenes(),
  ..._roadScenes(),
];

// ---------------------------------------------------------------- 忍び

List<SceneDef> _ninjaScenes() => [
  // ============================================ 筋: 頭の仕事
  SceneDef('sh_n_kashira', 17, 50, (g) => _w1 + (g.l.chi >= 60 ? 1 : 0), shSato, (
    g,
    next,
  ) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    g.ask('頭の仕事', '里の頭に呼ばれた。「$hの城下へ入れ。何をするかは、お前が選べ」。囲炉裏の火が、頭の顔の皺を深く見せていた。', [
      Choice.h('城下に流言を撒く', '手堅い仕事だ。噂は撒いた者にも返ってくる', () {
        l.gold += 6;
        g.setFlag('sh_trust');
        _stamp(g, 'kashira');
        return '市の立つ日に「殿は病が重い」と囁いて回った。三日で、城下の誰もがその話をしていた。';
      }),
      Choice.h('城の守りを探る', '頭の覚えはよくなる。見咎められれば命はない', () {
        final ok = .55 + l.chi / 250 + l.un / 500;
        if (g.rng.chance(clampD(ok, .4, .9))) {
          l.gold += 10;
          l.fame += 2;
          g.setFlag('sh_trust');
          _stamp(g, 'kashira');
          g.mark('里の頭の命で、城の守りを探り出した');
          return '堀の深さ、櫓の数、夜番の替わる刻。すべてを頭の中に刻んで戻った。';
        }
        if (g.rng.chance(.08)) {
          g.die('敵方の町を探るうちに見咎められ、その場で斬り伏せられた', 'ansatsu');
          return '石垣の陰で、背後から声をかけられた。';
        }
        l.hp -= 15;
        _stamp(g, 'kashira');
        return '夜番に見つかり、手傷を負って逃げ帰った。頭は何も言わなかった。';
      }),
      if (l.chi >= 60)
        Choice.h('城の縄張りを絵図に写す', '目の利く者にしかできない。頭は重く用いる', () {
          l.gold += 12;
          l.fame += 3;
          g.setFlag('sh_trust');
          g.setFlag('sh_ezu');
          _stamp(g, 'kashira');
          g.mark('敵の城の縄張りを、絵図に写し取った');
          return '人足に紛れて普請場に入り、縄張りをそっくり紙に写した。頭は絵図を見て、長く黙っていた。';
        }, via: '知'),
      Choice.h('仕事を断る', '手は汚れない。里での立場は細る', () {
        g.j(-2);
        l.net -= 1;
        _stamp(g, 'kashira');
        return '頭は「そうか」とだけ言った。その冬、仕事の声はかからなかった。';
      }),
    ], after: next);
  }),

  _chain('sh_n_lords', 20, 55, _w2, shSato, (g, next) {
    final l = g.l;
    final hs = _nearHouses(g, 2);
    final a = hs[0], b = hs[1];
    g.ask('雇い主', '里の働きが知れ渡り、$aと$bの両方から、忍びを雇いたいと使いが来た。頭は「お前が決めよ」と言う。', [
      Choice.h('勢いのある$aにつく', '払いはよい。強い家の手先は、恨みも買う', () {
        l.gold += 12;
        g.setFlag('sh_lord_near');
        _stamp(g, 'kashira');
        return '$aの陣に、里の者たちを連れて入った。';
      }),
      Choice.h('劣勢の$bにつく', '払いは細い。恩はより深く覚えられる', () {
        l.gold += 5;
        l.fame += 3;
        l.net += 2;
        g.setFlag('sh_lord_far');
        _stamp(g, 'kashira');
        return '$bの家老は、手を取らんばかりに喜んだ。';
      }),
      Choice.h('両家から銭を取る', '銭は倍になる。露見すれば、どちらも敵になる', () {
        l.gold += 18;
        g.setFlag('sh_hired_both');
        g.setFlag('sh_lord_none');
        _stamp(g, 'kashira');
        g.mark('争う両家に通じ、両方から銭を受け取った');
        return '昼は一方に、夜はもう一方に。どちらの家老も、自分だけが里を雇っていると思っていた。';
      }),
      if (l.chi >= 65)
        Choice.h('両家の動きを見極めてから決める', '目が利けば、勝つ側に乗れる', () {
          l.gold += 10;
          l.fame += 2;
          g.setFlag('sh_lord_near');
          _stamp(g, 'kashira');
          return 'ひと月かけて両家の兵糧と人の出入りを見た。勝つのは$aだと、確かめてから手を結んだ。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('sh_n_double', 22, 60, _w2, _ninja, (g, next) {
    final l = g.l;
    g.ask('露見', '両家に通じていたことが、片方の家に漏れたらしい。里の外れに、見慣れぬ侍が立つようになった。', [
      Choice.h('片方の家に詫びを入れる', '命は繋がるかもしれない。銭は吐き出す', () {
        _lose(g, .5);
        l.fame -= 3;
        l.flags.remove('sh_hired_both');
        return '受け取った銭の多くを差し出し、頭を下げた。侍は、刀の柄から手を離した。';
      }),
      Choice.h('ほとぼりが冷めるまで山に隠れる', '暮らしは痩せる。追う者があきらめるとは限らない', () {
        l.hp -= 10;
        if (g.rng.chance(.07)) {
          g.die('争う両家に通じたことが露見し、山中で闇討ちにされた', 'ansatsu');
          return '隠れ家の戸が、夜半に静かに開いた。';
        }
        l.flags.remove('sh_hired_both');
        return 'ひと冬、山の洞に身を潜めた。春には、侍の姿は消えていた。';
      }),
      Choice.h('漏らした者を突き止める', '里の中に裏切り者がいる。知れば、もう後には引けない', () {
        if (g.rng.chance(clampD(.4 + l.chi / 200, .3, .85))) {
          g.setFlag('sh_found_traitor');
          l.flags.remove('sh_hired_both');
          l.fame += 2;
          g.mark('里の内で通じていた者を突き止めた');
          return '漏らしたのは、同じ囲炉裏を囲んできた者だった。頭がその者をどうしたかは、聞かなかった。';
        }
        l.hp -= 12;
        g.j(-4);
        return '誰が漏らしたのか、ついに分からなかった。里の者の顔が、皆どこか疑わしく見えた。';
      }),
    ], after: next);
  }),

  _chain('sh_n_atome', 30, 62, _w2, shSato, (g, next) {
    final l = g.l;
    final trusted = g.hasFlag('sh_trust') && !g.hasFlag('sh_hired_both');
    g.ask('里の跡目', '老いた頭が床についた。「里を継ぐ者を決めねばならぬ」。囲炉裏の向こうで、何人もの目がこちらを見ていた。', [
      Choice.h('跡目を継ぐ', '里を背負う。掟を守らせる側になる', () {
        if (trusted || g.rng.chance(.4 + l.mi / 300)) {
          g.setFlag('sh_n_heir');
          l.fame += 6;
          l.net += 4;
          g.j(4);
          _stamp(g, 'kashira');
          g.mark('忍びの里の跡目を継ぎ、頭となった');
          return '頭の印の小刀を受け取った。その夜から、里の者はあなたを「お頭」と呼んだ。';
        }
        l.net -= 2;
        g.j(-5);
        _stamp(g, 'kashira');
        return '里の者の多くは、別の者を推した。あなたは頭になれなかった。';
      }),
      Choice.h('若い者に譲り、脇から支える', '争いは起きない。名は上がらない', () {
        g.setFlag('sh_n_elder');
        l.net += 3;
        g.j(3);
        _stamp(g, 'kashira');
        return '腕の立つ若い者を推した。新しい頭は、困るとあなたの小屋に来た。';
      }),
      Choice.h('この機に里を抜ける', '掟から自由になる。追手の影がつきまとう', () {
        g.setFlag('nukenin');
        g.setFlag('way_outlaw');
        g.j(5);
        _stamp(g, 'kashira');
        g.mark('里の跡目争いを機に、忍びの里を抜けた');
        return '跡目の話で里が揺れる隙に、月のない夜、里を出た。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 仲間
  SceneDef('sh_n_comrade', 18, 55, (g) => _w1, _ninja, (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('捕らわれた仲間', '共に仕事に出た$nが、敵の城の牢に捕らわれた。責めに耐えかねれば、里のことを話すかもしれない。', [
      Choice.h('夜に牢へ忍び入り、救い出す', '仲間は生きて帰る。しくじれば、牢がもう一つ埋まる', () {
        final ok = .5 + (l.bu + l.chi) / 400 + l.un / 600;
        if (g.rng.chance(clampD(ok, .4, .9))) {
          g.setFlag('sh_saved_comrade');
          g.meet('忍びの仲間', n, 70);
          l.fame += 3;
          _stamp(g, 'comrade');
          g.mark('敵の牢に捕らわれた仲間を救い出した');
          return '牢番の眠りを見計らい、格子を外した。$nは泣きながら、あなたの背に負われた。';
        }
        if (g.rng.chance(.06)) {
          g.die('捕らわれた仲間を救いに敵の牢へ忍び入り、そのまま戻らなかった', 'yukue');
          return '城の堀に、あなたの影が沈んでいった。';
        }
        l.hp -= 18;
        g.setFlag('sh_left_comrade');
        _stamp(g, 'comrade');
        return '見張りに気づかれ、ひとりで逃げ戻るほかなかった。';
      }),
      Choice.h('見捨てる', '里の掟どおりだ。仲間の顔が夢に出る', () {
        g.setFlag('sh_left_comrade');
        g.j(-6);
        _stamp(g, 'comrade');
        return '「捕らわれた者は、もう死んだ者」。掟を胸の内で繰り返した。';
      }),
      Choice.h('口を割る前に、文で覚悟を促す', '里は守られる。仲間の最期を背負う', () {
        g.setFlag('sh_left_comrade');
        l.net += 1;
        g.j(-8);
        _stamp(g, 'comrade');
        return '差し入れの握り飯に、小さな紙を忍ばせた。数日後、牢の$nが息絶えたと聞いた。';
      }),
    ], after: next);
  }),

  _chain('sh_n_grudge', 22, 70, _w2, shadowLife, (g, next) {
    final l = g.l;
    g.ask('生きていた仲間', '牢で死んだと思っていた昔の仲間が、生きて里の外を歩いているという噂を聞いた。片目を潰され、あなたの名を口にしているらしい。', [
      Choice.h('会いに行って詫びる', '恨みは解けるかもしれない。刃を向けられるかもしれない', () {
        if (g.rng.chance(clampD(.55 + l.mi / 250, .4, .9))) {
          g.setFlag('sh_grudge_eased');
          g.j(5);
          return '長い沈黙のあと、昔の仲間は「掟だったのだ」と言った。そのまま背を向け、去っていった。';
        }
        if (g.rng.chance(.07)) {
          g.die('見捨てた昔の仲間に恨まれ、詫びに訪ねた先で刺された', 'ansatsu');
          return '頭を下げた首筋に、冷たいものが触れた。';
        }
        l.hp -= 15;
        return '話す前に、刃が飛んできた。どうにか逃げたが、詫びる機会はもうない。';
      }),
      Choice.h('身を隠す', '刃は避けられる。恨みは残る', () {
        _lose(g, .2);
        g.j(-3);
        return '住む場所を移した。それでも夜道では、つい後ろを振り返った。';
      }),
      if (g.canFight)
        Choice.h('先に討つ', '恨みの元を絶つ。二度、同じ仲間を捨てることになる', () {
          l.bu = _c(l.bu + 1);
          g.j(-8);
          l.fame -= 3;
          return '待ち伏せは、あっけなく終わった。倒れた仲間の顔を、あなたは見なかった。';
        }, via: g.fightVia),
    ], after: next);
  }),

  _chain('sh_n_repay', 22, 70, _w2, shadowLife, (g, next) {
    final l = g.l;
    final p = l.people['忍びの仲間'];
    final n = p?.name ?? '昔の仲間';
    g.ask('救った仲間', 'かつて牢から救い出した$nが、夜更けに訪ねてきた。「あの夜の借りを返したい。お前を狙う話を聞いた」', [
      Choice.h('知らせを信じて身を移す', '危うさはかわせる。住み慣れた場所は捨てる', () {
        _lose(g, .15);
        l.net += 1;
        g.setFlag('sh_repaid');
        if (p != null) p.bond = _c(p.bond + 10);
        return '翌朝には、小屋を引き払った。三日後、その小屋が焼かれたと聞いた。';
      }),
      Choice.h('一緒に待ち伏せる', '恩を共に返す。刃を交えることになる', () {
        if (g.canFight && g.rng.chance(clampD(.55 + l.bu / 200, .4, .9))) {
          l.fame += 3;
          g.setFlag('sh_repaid');
          if (p != null) p.bond = _c(p.bond + 15);
          return '二人で闇に伏し、来た者たちを追い返した。$nは「これで貸し借りなしだ」と笑った。';
        }
        l.hp -= 15;
        g.setFlag('sh_repaid');
        return '待ち伏せは乱れ、二人とも手傷を負った。それでも、生きて朝を迎えた。';
      }),
      Choice.h('借りなどないと帰す', '気は楽だ。知らせの中身は聞かずに終わる', () {
        if (p != null) p.bond = _c(p.bond - 10);
        l.hp -= 8;
        return '$nは何か言いかけて、帰っていった。ほどなく、帰り道で何者かに襲われた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 薬と毒
  SceneDef('sh_n_herb', 16, 50, (g) => _w1, _ninja, (g, next) {
    final l = g.l;
    g.ask('薬と毒', '里の古い婆さまが、草の根と木の皮を並べて言った。「同じ草が、量しだいで薬にも毒にもなる。お前はどちらを覚える」', [
      Choice.h('病を治す薬を覚える', '人に頼られる。仕事の銭にはなりにくい', () {
        l.chi = _c(l.chi + 2);
        g.setFlag('sh_herb_med');
        _stamp(g, 'herb');
        return '熱を下げる根、血を止める葉。婆さまは、一つずつ口に含ませて覚えさせた。';
      }),
      Choice.h('人を眠らせ、倒す毒を覚える', '仕事に役立つ。毒は扱う者も蝕む', () {
        if (l.chi < 35 && g.rng.chance(.05)) {
          g.die('覚えたての毒の加減を誤り、自らの命を落とした', 'sai');
          return '試しに舐めた汁が、喉を焼いた。';
        }
        if (l.chi < 35) {
          l.hp -= 20;
          g.setFlag('sh_herb_poison');
          _stamp(g, 'herb');
          return '加減を誤り、三日寝込んだ。婆さまは「覚えが悪い」と舌打ちした。';
        }
        l.chi = _c(l.chi + 1);
        g.setFlag('sh_herb_poison');
        _stamp(g, 'herb');
        return '眠り薬、痺れ薬、それ以上のもの。婆さまは、作り方を紙には書かせなかった。';
      }),
      Choice.h('草のことは婆さまに任せる', '何も変わらない', () => '婆さまは肩をすくめ、草を片づけた。'),
    ], after: next);
  }),

  _chain('sh_n_poison', 20, 60, _w2, shadowLife, (g, next) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    g.ask('毒の役目', '$hの重臣の膳に、毒を盛ってほしいという話が来た。覚えた毒の術を知る者は、少ない。', [
      Choice.h('引き受ける', '大きな銭になる。しくじれば首が飛ぶ', () {
        if (g.rng.chance(clampD(.6 + l.chi / 300, .5, .9))) {
          l.gold += 25;
          g.setFlag('sh_poisoner');
          g.mark('毒の術で、ある重臣を病に見せかけて葬った');
          return '重臣は、ひと月寝込んで死んだ。医者は、ただの病と見立てた。';
        }
        if (g.rng.chance(.4)) {
          g.die('毒を盛る役目をしくじり、台所で取り押さえられて斬られた', 'seppuku');
          return '膳を運ぶ手が、ほんの少し震えた。';
        }
        l.hp -= 20;
        return '毒見役が先に倒れた。騒ぎに紛れて、どうにか逃げ出した。';
      }),
      Choice.h('眠り薬だけにとどめると言う', '命は奪わない。依頼主は喜ばない', () {
        l.gold += 6;
        g.j(2);
        return '重臣は大事な評定の朝に寝過ごした。依頼主は不満げに、半分だけ銭を払った。';
      }),
      Choice.h('断る', '銭は惜しい。毒の重さは背負わずに済む', () {
        g.j(1);
        return '使いは、二度と来なかった。';
      }),
    ], after: next);
  }),

  _chain('sh_n_cure', 20, 70, _w2, shadowLife, (g, next) {
    final l = g.l;
    g.ask('病の村', '山向こうの村に熱病が出て、薬師も寄りつかないという。覚えた薬の術を使えば、何人かは救えるかもしれない。', [
      Choice.h('村に入って薬を煎じる', '人が救われる。うつる危うさもある', () {
        if (g.rng.chance(.12)) {
          l.hp -= 30;
          g.setFlag('sh_cured_village');
          return '煎じ続けるうちに、自分も熱に倒れた。治った村の子らが、枕元で水を替えてくれた。';
        }
        l.net += 4;
        l.fame += 4;
        g.j(6);
        g.setFlag('sh_cured_village');
        g.mark('熱病の村に入り、忍びの薬で村人を救った');
        return '半月、寝ずに薬を煎じた。村を出るとき、名も知らぬ老婆が手を合わせた。';
      }),
      Choice.h('薬だけを村の入口に置いてくる', 'うつらずに済む。救える数は減る', () {
        l.net += 1;
        g.j(2);
        return '包みに煎じ方を描いた絵を添えて、村の地蔵の前に置いた。';
      }),
      Choice.h('関わらない', '身は安全だ。何かが胸に残る', () {
        g.j(-3);
        return '山の向こうから、弔いの煙がいく筋も上がった。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり
  SceneDef('sh_n_henso', 18, 55, (g) => _w1 + (g.l.mi >= 60 ? 1 : 0), _ninja, (
    g,
    next,
  ) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    g.ask('変装', '$hの城下に、しばらく潜ることになった。何に化けて入るかで、見えるものも、危うさも変わる。', [
      Choice.h('薬売りに化ける', '城下を広く歩ける。売る薬を知らねば怪しまれる', () {
        if (g.hasFlag('sh_herb_med') || l.chi >= 55) {
          l.gold += 8;
          l.net += 2;
          return '薬箱を背に家々を回った。腹痛の薬が効いたと、屋敷の奥にまで呼ばれた。';
        }
        l.hp -= 10;
        return '薬のことを問われて言葉に詰まり、早々に城下を出た。';
      }),
      Choice.h('虚無僧に化ける', '顔を隠せる。関所では怪しまれやすい', () {
        if (g.rng.chance(.7 + l.un / 400)) {
          l.gold += 6;
          return '天蓋の下から、城の門をくぐる者の顔を数えた。';
        }
        l.hp -= 12;
        return '関所で天蓋を取れと言われ、山へ逃げた。';
      }),
      if (l.mi >= 60)
        Choice.h('猿楽の一座に紛れ込む', '人の心を掴める者だけの手だ。屋敷の奥まで入れる', () {
          l.gold += 12;
          l.fame += 2;
          g.setFlag('sh_henso_master');
          g.mark('猿楽の一座に紛れて、城の奥の宴に入り込んだ');
          return '舞の合間に、酔った重臣の話をすべて聞いた。誰も、囃子方の顔など見ていなかった。';
        }, via: '魅'),
      Choice.h('下働きとして屋敷に住み込む', '長く潜れる。抜け出すのが難しい', () {
        if (g.rng.chance(.75)) {
          l.gold += 10;
          return '半年、水を汲み薪を割った。屋敷の者は、あなたを口のきけない男と思っていた。';
        }
        l.hp -= 15;
        g.j(-3);
        return '持ち物を改められそうになり、夜半に塀を越えた。';
      }),
    ], after: next);
  }),

  // 天正の伊賀の戦（一）: 一五七九年、織田信雄が伊賀に攻め入り、伊賀衆に退けられた。
  SceneDef(
    'sh_n_iga_first',
    16,
    70,
    (g) => 6,
    (g) => shSato(g) && _odaIga(g),
    (g, next) {
      final l = g.l;
      if (_koka(g)) {
        g.ask('伊賀からの使い', '織田信雄が伊賀へ攻め入り、伊賀の者たちに散々に討ち破られたという。伊賀から甲賀の里へ、「次は大軍が来る。手を貸してほしい」と使いが来た。', [
          Choice.h('ひそかに伊賀へ人を送る', '隣の里との義は守る。織田ににらまれる', () {
            l.net += 2;
            g.setFlag('sh_iga_aid');
            return '若い者を幾人か、薬売りに化けさせて伊賀へ送った。';
          }),
          Choice.h('織田の側に立つと決める', '里は守られる。伊賀の者は忘れない', () {
            l.gold += 6;
            g.setFlag('sh_iga_oda');
            return '使いに握り飯を持たせて帰した。甲賀は織田につくと、頭が決めた。';
          }),
        ], after: next);
        return;
      }
      g.ask('伊賀の勝ち戦', '織田信雄が伊賀へ攻め入り、伊賀の者たちに散々に討ち破られたという。里では、伊賀の加勢に行った者の手柄話で持ちきりだ。', [
        Choice.h('伊賀へ行き、次の戦に備える', '名は上がる。織田の本当の大軍は、まだ来ていない', () {
          l.fame += 3;
          l.bu = _c(l.bu + 1);
          g.setFlag('sh_iga_aid');
          return '伊賀の山々を歩き、砦と抜け道を頭に入れた。';
        }),
        Choice.h('勝ち戦を冷めた目で見る', '浮かれずに済む。里の者には臆病に見える', () {
          l.chi = _c(l.chi + 1);
          return '信長がこのまま黙っているはずがない。そう言うと、皆が笑った。';
        }),
      ], after: next);
    },
    ageOk: (g, a) {
      final y = g.l.startYear + a;
      return y >= 1579 && y <= 1580;
    },
  ),

  // 天正の伊賀の戦（二）: 一五八一年、信長が大軍で伊賀を攻め、伊賀は焼かれた。甲賀の者は織田方の道案内をしたと伝わる。
  SceneDef(
    'sh_n_iga_second',
    16,
    75,
    (g) => 8,
    (g) => _ninja(g) && _odaIga(g),
    (g, next) {
      final l = g.l;
      if (_koka(g) && shSato(g)) {
        g.ask('伊賀攻めの道案内', '信長が大軍で伊賀を攻めるという。甲賀の里には、織田方の道案内をせよと命が下った。', [
          Choice.h('命どおり道を案内する', '里は守られる。伊賀の者の恨みを背負う', () {
            l.gold += 10;
            g.setFlag('sh_iga_oda');
            g.j(-4);
            g.mark('織田の伊賀攻めで、甲賀の者として道案内をした');
            return '山の抜け道を、織田の兵に教えた。その夜、伊賀の空が赤く焼けた。';
          }),
          Choice.h('わざと遠回りの道を教える', '伊賀の者が逃げる隙ができる。露見すれば里が危うい', () {
            if (g.rng.chance(clampD(.7 + l.chi / 400, .6, .95))) {
              g.setFlag('sh_iga_sheltered');
              l.net += 2;
              return '谷を一つ多く回らせた。その間に、伊賀の女子どもが山を越えたと、あとで聞いた。';
            }
            l.fame -= 4;
            l.hp -= 15;
            return '道の偽りを見抜かれ、織田の侍に打ち据えられた。命だけは助かった。';
          }),
        ], after: next);
        return;
      }
      final nuke = shNuke(g);
      g.ask(
        '伊賀が焼かれる',
        nuke
            ? '信長の大軍が伊賀を攻めているという。あなたが抜けた里とつながる伊賀の村々が、次々に焼かれていると、峠の茶屋で聞いた。'
            : '信長の大軍が、四方から伊賀へ攻め入った。伊賀とつながる里にも、火の手が迫る。',
        [
          Choice.h('里の者を連れて山へ逃がす', '命は多く残る。焼ける家々は見捨てる', () {
            l.net += 3;
            g.setFlag('sh_iga_led');
            g.mark('伊賀の戦の火の中、里の者を山へ逃がした');
            return '老人を背負い、子の手を引いて、夜の尾根を越えた。振り返ると、谷が燃えていた。';
          }),
          if (g.canFight)
            Choice.h('砦に籠もって織田の兵と戦う', '名は残る。大軍の前に、生きて帰る者は少ない', () {
              if (g.rng.chance(.07)) {
                g.die('天正の伊賀の戦で、焼ける里を背に織田の兵と斬り結んで倒れた', 'senshi');
                return '砦の門が破られ、炎の向こうから槍が並んで押し寄せた。';
              }
              l.hp -= 25;
              l.fame += 5;
              l.bu = _c(l.bu + 1);
              g.setFlag('sh_iga_fought');
              g.mark('天正の伊賀の戦で、織田の兵と戦い抜いた');
              return '三日、砦を守った。落ちる前に、抜け穴から生き残りと逃れた。';
            }, via: g.fightVia),
          Choice.h('関わらず、身を潜める', '命は確かに残る。焼けた里の噂を一生聞く', () {
            g.j(-6);
            return '遠い山の上から、煙が幾日も上がるのを見ていた。';
          }),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => g.l.startYear + a == 1581,
  ),

  // 伊賀を焼け出された忍びが諸国へ散った（一五八一年から）。
  SceneDef(
    'sh_n_iga_exiles',
    18,
    80,
    (g) => _w1 + 1,
    (g) => shadowLife(g) && _odaIga(g),
    (g, next) {
      final l = g.l;
      g.ask('伊賀の落人', '伊賀を焼け出された忍びの一家が、あなたを頼って来た。織田の詮議は、まだ厳しい。', [
        Choice.h('黙ってかくまう', '人の道は守る。見つかれば、ともに罰を受ける', () {
          if (g.rng.chance(.85)) {
            g.setFlag('sh_iga_sheltered');
            l.net += 3;
            g.j(4);
            g.meet('伊賀の落人', g.rng.pick(kGivenM), 60);
            return '納屋の奥に寝床を作った。一家は春まで息をひそめ、やがて東へ去った。';
          }
          _lose(g, .3);
          l.hp -= 10;
          return '詮議の役人に嗅ぎつけられ、銭を渡して見逃してもらった。一家は、その夜のうちに逃げた。';
        }),
        Choice.h('銭と食べ物だけ渡して去らせる', '危うさは小さい。深い縁にはならない', () {
          _lose(g, .1);
          g.j(1);
          return '干し飯と銭を少し包んで渡した。一家は何度も頭を下げて、峠を越えていった。';
        }),
        Choice.h('役人に知らせる', '褒美が出る。伊賀の者の恨みを買う', () {
          l.gold += 8;
          l.fame -= 4;
          g.j(-6);
          g.setFlag('sh_iga_sold');
          return '褒美の銭を受け取った。その晩は、酒の味がしなかった。';
        }),
      ], after: next);
    },
    ageOk: (g, a) {
      final y = g.l.startYear + a;
      return y >= 1581 && y <= 1590;
    },
  ),
];

// ---------------------------------------------------------------- 抜け忍

List<SceneDef> _nukeScenes() => [
  SceneDef('sh_nk_newlife', 19, 60, (g) => _w1 + 1.5, shNuke, (g, next) {
    final l = g.l;
    g.ask('名を変えて', '里を抜けて幾年か。追手をかわし続けるには、どこかに紛れて暮らすほかない。', [
      Choice.h('町に紛れ、日雇いで暮らす', '人が多いほど目立たない。顔見知りも増える', () {
        l.gold += 4;
        l.net += 2;
        g.setFlag('sh_nk_town');
        _stamp(g, 'newlife');
        g.mark('名を変え、町の日雇いに紛れて暮らした');
        return '新しい名で、荷車を引いた。隣の長屋の者は、あなたの昔を何も知らない。';
      }),
      Choice.h('山あいの村で田を借りる', '静かに暮らせる。よそ者は覚えられやすい', () {
        _heal(g, 15);
        g.j(4);
        g.setFlag('sh_nk_village');
        _stamp(g, 'newlife');
        g.mark('名を変え、山あいの村で田を借りて暮らした');
        return '痩せた田を借りて、鍬を握った。村の者は、無口なよそ者を遠巻きに見ていた。';
      }),
      Choice.h('寺男として寺に住み込む', '寺の中は追手も入りにくい。暮らしは慎ましい', () {
        l.chi = _c(l.chi + 1);
        g.j(2);
        g.setFlag('sh_nk_temple');
        _stamp(g, 'newlife');
        return '庭を掃き、鐘を撞いた。住職は、あなたの手の古傷を見ても何も問わなかった。';
      }),
    ], after: next);
  }),

  _chain('sh_nk_hunter', 23, 72, _w2, shNuke, (g, next) {
    final l = g.l;
    final os = l.people['幼なじみ'];
    final who = os != null ? '幼なじみの${os.name}' : '里で同じ師に習った者';
    g.ask('旧知の追手', '名を変えた暮らしの中に、見覚えのある顔が現れた。$whoだ。里の頭の命で来たのだと、目が語っていた。', [
      if (g.canFight)
        Choice.h('先に仕掛ける', '勝てば、また逃げずに済む。昔なじみを手にかける', () {
          if (g.rng.chance(clampD(.5 + l.bu / 200, .4, .85))) {
            l.bu = _c(l.bu + 1);
            g.j(-6);
            if (os != null) l.people.remove('幼なじみ');
            return '刃が交わったのは一度きりだった。倒れた相手の懐から、里の頭の文が出てきた。';
          }
          if (g.rng.chance(.08)) {
            g.die('名を変えて暮らすうち、旧知の忍びに見つかり、その刃に倒れた', 'ansatsu');
            return '相手の刃のほうが、半拍だけ早かった。';
          }
          l.hp -= 25;
          return '深手を負わせ合い、互いに闇へ退いた。';
        }, via: g.fightVia),
      Choice.h('話をして、見逃してくれと頼む', '昔の縁が効くかもしれない。効かなければ逃げ場はない', () {
        final bond = os?.bond ?? 30;
        if (g.rng.chance(clampD(.3 + bond / 200 + l.mi / 300, .25, .85))) {
          g.setFlag('sh_nk_spared');
          g.j(4);
          return '相手は長く黙り、「お前は死んだと、頭には言う」とだけ言って去った。';
        }
        l.hp -= 15;
        _lose(g, .3);
        return '話は通じなかった。持ち物を捨てて、裏の川へ飛び込んだ。';
      }),
      Choice.h('暮らしを捨てて、また逃げる', '命は繋がる。積み上げたものは失う', () {
        _lose(g, .5);
        l.net = l.net ~/ 2;
        _stamp(g, 'newlife');
        return 'その夜のうちに、新しい名もまた捨てた。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 流れ者・野盗

List<SceneDef> _roadScenes() => [
  SceneDef('sh_o_seki', 16, 65, (g) => _w1, _road, (g, next) {
    final l = g.l;
    g.ask('街道の関', '峠の関で、関守が通る者を一人ずつ改めている。人相書きも貼ってあるらしい。', [
      Choice.h('関銭を払って通る', '確かに通れる。懐は寂しくなる', () {
        _lose(g, .15);
        return '関銭を払い、うつむいて関を抜けた。';
      }),
      Choice.h('山の抜け道を行く', '銭はかからない。道を外れれば山に迷う', () {
        if (g.rng.chance(.25 - l.un / 500)) {
          l.hp -= 15;
          return '獣道で足を滑らせ、谷へ転げ落ちた。這い上がるのに丸一日かかった。';
        }
        _heal(g, 5);
        return '杣人の道を抜けた。尾根の向こうに、関の屋根が小さく見えた。';
      }),
      if (l.chi >= 60)
        Choice.h('寺の過書をこしらえて通る', '筆の立つ者にしかできない。見破られれば縄目だ', () {
          if (g.rng.chance(.85)) {
            l.gold += 2;
            g.setFlag('sh_forged_pass');
            return '寺の印をまねた過書を見せると、関守は頭を下げて通した。';
          }
          l.hp -= 10;
          _lose(g, .3);
          return '印の形を怪しまれ、銭を置いて逃げ出した。';
        }, via: '知'),
      if (g.canFight && l.bu >= 65)
        Choice.h('関を押し通る', '腕に覚えがあればできる。関守の槍は飾りではない', () {
          if (g.rng.chance(.05)) {
            g.die('峠の関を押し通ろうとして、関守の槍に突かれた', 'senshi');
            return '関の柵の向こうから、槍が三本突き出された。';
          }
          l.fame -= 2;
          l.bu = _c(l.bu + 1);
          return '関守を突き飛ばし、柵を越えて駆け抜けた。後ろで鐘が鳴り続けていた。';
        }, via: '武'),
    ], after: next);
  }),

  // ============================================ 筋: 山の一味
  SceneDef('sh_o_band', 18, 55, (g) => _w1 + 1.5 + (g.l.bu >= 60 ? 1 : 0), (g) => shBandit(g) && g.canFight, (
    g,
    next,
  ) {
    final l = g.l;
    g.ask('頭の跡目', '一味の頭が、討手の矢を受けて死んだ。手下たちが焚き火を囲み、次の頭を誰にするかで睨み合っている。', [
      Choice.h('名乗りを上げる', '一味を率いる。手下の命も背負う', () {
        if (g.rng.chance(clampD(.45 + l.bu / 250 + l.mi / 250, .4, .9))) {
          g.setFlag('sh_band_head');
          l.fame += 4;
          _stamp(g, 'band');
          g.mark('山の一味の頭となった');
          return '異を唱えた男を、一太刀で黙らせた。焚き火の向こうで、手下たちが膝をついた。';
        }
        l.hp -= 18;
        _stamp(g, 'band');
        return '腕比べに負け、別の男が頭になった。あなたは脇に退いた。';
      }),
      if (l.mi >= 60)
        Choice.h('言葉で手下をまとめる', '人を惹きつける者の手だ。血を流さずに頭になれる', () {
          g.setFlag('sh_band_head');
          l.fame += 3;
          l.net += 2;
          _stamp(g, 'band');
          g.mark('山の一味の頭となった');
          return '「争えば、討手の思うつぼだ」。その一言で、睨み合いはほどけた。';
        }, via: '魅'),
      Choice.h('別の者を推して、下につく', '血は流れない。頭の器量しだいの身になる', () {
        l.net += 1;
        _stamp(g, 'band');
        return '腕の立つ男を推した。新しい頭は、あなたを右腕に置いた。';
      }),
      Choice.h('これを機に一味を離れる', '身軽になる。山の仲間の後ろ盾も失う', () {
        g.j(2);
        _stamp(g, 'band');
        return '夜のうちに、ひとりで山を下りた。';
      }),
    ], after: next);
  }),

  _chain('sh_o_band_rule', 19, 60, _w2, shBandit, (g, next) {
    final l = g.l;
    g.ask('一味の掟', '頭になって幾月か。手下の中に、貧しい村から米まで奪ってくる者がいる。「どうせ奪うなら同じことだ」と言う。', [
      Choice.h('貧しい村から奪うなと掟を立てる', '村の者は一味を見逃す。手下の取り分は減る', () {
        if (l.mi < 40 && g.rng.chance(.3)) {
          g.setFlag('sh_band_loose');
          l.hp -= 10;
          _stamp(g, 'band');
          return '掟を言い渡したが、手下は聞き流した。頭の言葉が軽く扱われ始めた。';
        }
        g.setFlag('sh_band_code');
        l.fame += 2;
        _stamp(g, 'band');
        g.mark('一味に、貧しい村からは奪わぬ掟を立てた');
        return '掟を破った手下を、山から追い出した。麓の村から、ときおり野菜が届くようになった。';
      }),
      Choice.h('好きにさせる', '手下は懐く。恨みは一味にまとめて積もる', () {
        l.gold += 10;
        l.fame -= 4;
        g.setFlag('sh_band_loose');
        _stamp(g, 'band');
        return '手下たちは喜び、獲物はいっそう増えた。麓の村の者の目が、冷たくなった。';
      }),
    ], after: next);
  }),

  _chain('sh_o_band_end', 21, 65, _w2, shBandit, (g, next) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    final code = g.hasFlag('sh_band_code');
    g.ask(
      '一味の行く末',
      code
          ? '$hの侍が、山に使いを寄こした。「村を荒らさぬ一味と聞いた。戦のときは陣借りとして加われ。そうすれば山狩りはせぬ」'
          : '手下の中に、頭の座を狙う者が出てきた。夜な夜な、焚き火の向こうで囁き合っている。',
      [
        if (code)
          Choice.h('一味ごと陣借りの約を結ぶ', '山狩りはやむ。戦があれば駆り出される', () {
            l.gold += 12;
            l.fame += 4;
            g.setFlag('sh_band_pact');
            g.mark('一味ごと、近くの大名の陣借りの約を結んだ');
            return '約定の書付を受け取った。その秋から、山の麓で討手の旗を見なくなった。';
          })
        else
          Choice.h('先に企みの首謀者を斬る', '一味は締まる。手下の心は離れる', () {
            if (g.rng.chance(clampD(.55 + l.bu / 200, .4, .9))) {
              l.bu = _c(l.bu + 1);
              l.fame -= 2;
              return '夜明け前に首謀者の寝床を襲った。残った手下は、目を伏せて従った。';
            }
            if (g.rng.chance(.12)) {
              g.die('一味の手下の謀反に遭い、山の寝床で寝首をかかれた', 'ansatsu');
              return '先を越されていた。寝床の筵に、刃が突き立った。';
            }
            l.hp -= 20;
            return '斬り合いになり、首謀者は逃げた。一味は二つに割れた。';
          }),
        Choice.h('一味を解き、手下に銭を分けて散らす', '山の暮らしは終わる。手下の行く末は知れない', () {
          _lose(g, .5);
          l.flags.remove('way_outlaw');
          g.setFlag('reformed');
          g.setFlag('sh_band_disbanded');
          g.j(5);
          g.mark('山の一味を解き、手下に銭を分けて散らした');
          return '蓄えた銭を等しく分けた。手下たちは一人、また一人と山を下りていった。';
        }),
        Choice.h('今のまま山に居続ける', '何も変わらない。変わらないことが危うい', () {
          l.gold += 5;
          l.fame -= 2;
          return '焚き火の煙は、今夜も山の上に細く上がった。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 筋: 用心棒
  SceneDef('sh_o_yojinbo', 18, 60, (g) => _w1 + (g.l.bu >= 60 ? 1 : 0), (g) => _road(g) && g.canFight, (
    g,
    next,
  ) {
    final l = g.l;
    g.ask('村の用心棒', '野盗に狙われているという村の長が、あなたの刀を見て頼み込んできた。「米と寝床なら出せる」', [
      Choice.h('米と寝床で引き受ける', '村の者に頼られる。野盗が来れば刃を交える', () {
        l.net += 2;
        g.setFlag('sh_yojin_kept');
        _stamp(g, 'yojin');
        return '村はずれの空き家に住み、夜ごと見回りをした。子どもたちが、遠巻きについてきた。';
      }),
      Choice.h('銭も出せと吹っかける', '懐は温まる。村の者の目は冷たい', () {
        l.gold += 8;
        g.setFlag('sh_yojin_greedy');
        _stamp(g, 'yojin');
        return '村じゅうから銭をかき集めさせた。長は、黙って頭を下げた。';
      }),
      Choice.h('断る', '関わらずに済む。村のことは村が背負う', () {
        return '長の肩が落ちるのを見ないようにして、村を出た。';
      }),
      if (l.bu >= 65)
        Choice.h('一人で野盗の根城へ出向く', '腕で話をつける。村を戦場にせずに済む。相手は大勢だ', () {
          if (g.might(.3)) {
            l.fame += 5;
            l.net += 4;
            l.gold += 3;
            g.mark('村を狙う野盗の根城へ一人で出向き、頭を打ち据えて手を引かせた');
            return '根城の焚き火の前で、頭の太刀を三合で叩き落とした。「この村には、わしがいる」。野盗は、その夜のうちに山を移った。村の者が、米のほかに銭まで包んでくれた。';
          }
          l.hp -= 14;
          l.net += 1;
          return '頭は倒したが、手下に囲まれて深手を負った。血まみれで村へ戻ると、長が戸板を持って駆けてきた。野盗は、しばらく来なかった。';
        }, via: '武'),
    ], after: next);
  }),

  _chain('sh_o_yojin_raid', 18, 65, _w2, _road, (g, next) {
    final l = g.l;
    g.ask('野盗の襲来', '月のない夜、村の見張りが鐘を打った。松明を持った野盗が、二十ほど谷を下りてくる。', [
      if (g.canFight)
        Choice.h('村の若い衆と迎え撃つ', '勝てば村の恩人になる。腕が足りねば、真っ先に斬られる', () {
          final ok = .3 + l.bu / 150 + (g.hasFlag('sh_yojin_kept') ? .1 : 0);
          if (g.rng.chance(clampD(ok, .25, .9))) {
            l.fame += 5;
            l.net += 3;
            l.bu = _c(l.bu + 1);
            g.setFlag('sh_yojin_fought');
            _stamp(g, 'yojin');
            g.mark('用心棒として、村を野盗から守り抜いた');
            return '畦に伏せた若い衆と挟み撃ちにした。野盗は松明を捨てて、谷へ逃げ帰った。';
          }
          if (g.rng.chance(l.bu < 45 ? .14 : .06)) {
            g.die('雇われた村で野盗と斬り結び、田の畦で倒れた', 'senshi');
            return '先頭の男と打ち合ううちに、脇から槍が入った。';
          }
          l.hp -= 25;
          _stamp(g, 'yojin');
          return '追い払いはしたが、深手を負った。村の蔵が一つ焼かれた。';
        }, via: g.fightVia),
      Choice.h('女子どもを山の寺へ逃がす', '人は守れる。家と米は奪われる', () {
        l.net += 2;
        g.setFlag('sh_yojin_saved');
        _stamp(g, 'yojin');
        return '女子どもの列を率いて山道を登った。夜が明けて戻ると、蔵は空だったが、誰も死んでいなかった。';
      }),
      Choice.h('野盗の頭と話をつける', '血は流れずに済む。村を売ったと言われるかもしれない', () {
        if (g.rng.chance(clampD(.35 + l.mi / 200, .3, .8))) {
          l.gold += 4;
          g.setFlag('sh_yojin_deal');
          _stamp(g, 'yojin');
          return '米の半分と引き換えに、野盗は引き上げた。村の長の目は、喜んでいなかった。';
        }
        l.hp -= 15;
        l.fame -= 2;
        _stamp(g, 'yojin');
        return '話はこじれ、殴り倒されて縛られた。村は荒らされた。';
      }),
    ], after: next);
  }),

  _chain('sh_o_settle', 20, 70, _w2, _road, (g, next) {
    final l = g.l;
    g.ask('村に根付くか', '野盗の夜から幾月か。村の長が、田と小屋を用意するから、このまま村の者にならぬかと言ってきた。', [
      Choice.h('村の者になる', '帰る場所ができる。刀より鍬を握る日が増える', () {
        l.flags.remove('way_outlaw');
        g.setFlag('reformed');
        g.setFlag('sh_settled');
        _heal(g, 20);
        g.j(8);
        l.net += 3;
        g.mark('用心棒を務めた村に迎えられ、村の者となった');
        return '長から鍬を一本もらった。その春、はじめて自分の田に苗を植えた。';
      }),
      Choice.h('礼だけ受けて、また旅に出る', '身軽なままでいられる。この村には戻らない', () {
        l.gold += 4;
        g.j(2);
        return '村の子らが、峠の下まで見送りに来た。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり
  SceneDef('sh_o_jingari', 18, 50, (g) => _w1 + (g.l.bu >= 60 ? 1 : 0), (g) => _road(g) && g.canFight, (
    g,
    next,
  ) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    g.ask('陣借り', '$hが戦を前に、腕の立つ牢人を集めている。陣借りとして加われば、手柄しだいで褒美も出るという。', [
      Choice.h('陣借りで戦に出る', '手柄を立てれば銭と名が手に入る。討死する者も多い', () {
        if (g.rng.chance(.06)) {
          g.die('陣借りで加わった戦で、名も知られぬまま討たれた', 'senshi');
          return '前の者の背中を追ううちに、矢が胸に立った。';
        }
        if (g.rng.chance(clampD(.35 + l.bu / 200, .3, .8))) {
          l.gold += 15;
          l.fame += 5;
          l.merit += 5;
          g.setFlag('sh_jingari_won');
          g.mark('陣借りで戦に加わり、首を挙げて褒美を得た');
          return '敵の組頭の首を挙げた。陣の奥から、褒美の銭が届いた。';
        }
        l.gold += 4;
        l.hp -= 15;
        return '手柄は立たず、手傷と少しの銭だけが残った。';
      }),
      Choice.h('荷運びの人足として加わる', '命の危うさは小さい。銭も少ない', () {
        l.gold += 5;
        l.hp -= 5;
        return '兵糧を背負って、陣と村を往復した。';
      }),
      Choice.h('戦には関わらない', '何も起きない', () => '陣触れの太鼓を、遠くに聞いた。'),
      if (l.bu >= 60)
        Choice.h('陣触れの場で、腕試しを願い出る', '侍大将の目に留まれば、ただの陣借りでは終わらない。恥をかけば、陣にも入れない', () {
          if (g.might()) {
            l.gold += 8;
            l.fame += 4;
            return '侍大将の前で、槍持ち三人を続けて突き伏せた。「陣借りには惜しい」と、戦のあいだ馬廻りの端に置かれ、戦は後ろで見ているうちに終わった。褒美の銭は、陣借りの倍だった。';
          }
          l.hp -= 5;
          return '二人目の槍に足を払われて転がった。侍大将は、もう別の牢人を見ていた。';
        }, via: '武'),
    ], after: next);
  }),

  SceneDef('sh_o_bakuchi', 18, 70, (g) => _w1, _road, (g, next) {
    final l = g.l;
    g.ask('宿場の賭場', '宿場の外れの荒れ寺で、夜ごと賭場が立っている。胴元は、腕の立つ者に見張りを頼みたいとも言う。', [
      Choice.h('丁半に張る', '当たれば懐が膨らむ。運がなければ身ぐるみ剥がれる', () {
        if (g.rng.chance(clampD(.3 + l.un / 160, .2, .8))) {
          l.gold += g.rng.range(6, 16);
          g.j(3);
          return '賽の目が続けて当たった。夜明けの宿場を、重い懐で歩いた。';
        }
        _lose(g, .5);
        g.j(-4);
        return '気づけば、草鞋の銭まで場に置いていた。';
      }),
      if (g.canFight)
        Choice.h('賭場の見張りに雇われる', '確かな銭になる。揉め事のたびに刀を抜く', () {
          l.gold += 6;
          l.hp -= 6;
          l.net += 1;
          return '負けた客が暴れるたびに、外へ放り出した。胴元は銭をはずんだ。';
        }, via: g.fightVia),
      if (l.chi >= 60)
        Choice.h('壺振りの手口を見破る', '目の利く者にしか見えない。胴元に恨まれる', () {
          l.gold += 10;
          l.fame += 1;
          g.setFlag('sh_saw_cheat');
          return '壺の中の賽の細工を言い当てた。胴元は青い顔で、口止めの銭を握らせてきた。';
        }, via: '知'),
      Choice.h('近寄らない', '何も変わらない', () => '賭場の灯りを横目に、宿へ戻った。'),
    ], after: next);
  }),

  SceneDef('sh_o_goei', 18, 60, (g) => _w1, _road, (g, next) {
    final l = g.l;
    g.ask('旅の一座', '国から国へ渡る猿楽と傀儡の一座が、山越えの護衛を探している。座頭の娘が、あなたを見て笑った。', [
      if (g.canFight)
        Choice.h('護衛を引き受ける', '旅の連れができる。山道では刃を抜くこともある', () {
          if (g.rng.chance(.2) && l.bu < 40) {
            l.hp -= 20;
            _lose(g, .2);
            return '峠で賊に囲まれ、一座の荷の半分を奪われた。座頭は黙って首を振った。';
          }
          l.gold += 7;
          l.net += 2;
          g.j(4);
          return '三つの国を共に越えた。焚き火の夜ごとに、一座は新しい舞を見せてくれた。';
        }, via: g.fightVia),
      Choice.h('一座に加わり、芸を覚える', '居場所ができる。人目に立つ暮らしになる', () {
        l.mi = _c(l.mi + 2);
        l.net += 3;
        g.j(6);
        g.setFlag('sh_joined_troupe');
        g.mark('旅の一座に加わり、諸国を巡った');
        return '太鼓の打ち方を覚えた。村の祭りに呼ばれるたびに、子どもたちが一座を追いかけた。';
      }),
      Choice.h('道連れは断る', '気楽な一人旅が続く', () => '一座の荷車が、街道の先に小さくなっていった。'),
    ], after: next);
  }),

  // ============================================ 筋: 落ち武者
  SceneDef('sh_o_ochimusha', 18, 60, (g) => _w1, (g) => shOutlaw(g) || shReformed(g), (g, next) {
    final l = g.l;
    g.ask('落ち武者狩り', '近くで大きな戦があり、負けた側の侍が山へ逃げ込んでいる。村の者も鎌や竹槍を持って山へ入っていく。', [
      if (g.canFight)
        Choice.h('名のある武者を狩る', '首には褒美がかかる。手負いの侍は死にもの狂いだ', () {
          if (g.rng.chance(.05)) {
            g.die('落ち武者狩りの山で、手負いの武者に斬り返された', 'senshi');
            return '藪から飛び出した武者の太刀が、竹槍ごと腕を払った。';
          }
          l.gold += 12;
          l.fame -= 2;
          return '沢で休む武者を囲み、首を挙げた。勝った側の陣で、褒美の銭を受け取った。';
        }, via: g.fightVia),
      Choice.h('手負いの武者を見逃し、道を教える', '人の道は守る。見つかれば咎めを受ける', () {
        if (g.rng.chance(.88)) {
          g.setFlag('sh_ochi_spared');
          g.j(3);
          _stamp(g, 'ochi');
          return '獣道を教え、干し飯を分けた。武者は名を言いかけて、口をつぐんだ。';
        }
        l.hp -= 12;
        _lose(g, .2);
        return '村の者に見られ、落ち武者の仲間と疑われて打ち据えられた。';
      }),
      Choice.h('打ち捨てられた具足だけ拾う', '危うさは小さい。儲けも小さい', () {
        l.gold += 4;
        return '谷に落ちていた胴丸を拾い、市で売った。';
      }),
    ], after: next);
  }),

  _chain('sh_o_ochi_repay', 24, 75, _w2, shadowLife, (g, next) {
    final l = g.l;
    final h = _nearHouses(g, 1).first;
    g.ask('逃がした武者', '$hの使いが、あなたを探して来た。いつかの山で逃がした落ち武者が、今は$hの重臣になっているという。「あの干し飯の恩を返したい」と。', [
      Choice.h('招きに応じて会いに行く', '恩が返る。昔の暮らしを問われるかもしれない', () {
        l.gold += 15;
        l.fame += 3;
        l.net += 2;
        g.setFlag('sh_ochi_repaid');
        g.mark('逃がした落ち武者に、何年も後に恩を返された');
        return '重臣は上座を降りて、あなたの手を取った。帰りの荷は、米俵で重かった。';
      }),
      Choice.h('名乗るほどのことではないと断る', '気は楽だ。恩は受け取らずに終わる', () {
        g.j(3);
        return '使いは困った顔をして、せめてもと酒を一樽置いていった。';
      }),
    ], after: next);
  }),
];
