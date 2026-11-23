import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 年中行事と季節の岐路（2026-11-24）。id・旗は `sn_`（子どもは `sn_c_`）。
///
/// 身分・道ごとの岐路は厚くなったが、正月・端午・七夕・盆・月見・重陽・年の暮れといった、
/// 誰の一生にも巡ってくる季節の行事の場面がほとんどなかったので足した。
/// `regions.dart`（祇園会・御柱・鳥追い など国の祭り）・`village.dart`（田植え・秋祭り）・`temple.dart`（施餓鬼）・
/// `trade_farm.dart`（商人の暮れの掛け取り）・`childhood_more.dart`（縫い物の手習い）とは題材を変えてある。
///
/// - **出し方**: ほかの岐路を押しのけないよう、ふつうの年の候補には入れず、**岐路の起きない静かな年**
///   （`Game.sceneChance` に外れ、縁の筋の続きも出なかった年）に [kSeasonQuietChance] で一つ出す（`Game._adultYearScene`）。
///   子どもも同じく、岐路の起きなかった年に [kSeasonChildQuietChance] で一つ出す（`Game._yearScene`。幼少期の岐路の数の目安には数えない）。
/// - **季節が巡る**: 岐路を走らせている間の `Game.season` はいつも同じ半年（大人は春夏・子どもは秋冬）なので使えない。
///   場面ごとに季節（[kSeasonOf]、0 春・1 夏・2 秋・3 冬）を持ち、前に出た季節の行事と同じ季節のものは出にくくする（旗 `sn_last:<季節>`）。
/// - **身分で書き分ける**: 武家は主君への年賀・流鏑馬・灯籠、大名は国人の年賀、百姓は虫送り、町人は八朔の贈り物、
///   僧は盆の棚経、暮らしの苦しい人は大晦日の掛け取り。誰にでも出る行事（初夢・月見・年越し）は縁のある人で書き分ける。
/// - **筋**（[kSeasonPrev]・[kSeasonGap]。段を踏んだ年は旗 `sn_at:<筋>:<年>`）: 盆踊りで出会った人 → 翌年からの再会／
///   月見の約束 → 約束の月／流鏑馬 → 指南か雪辱／煤払いで見つけた古い文 → 返事／子どもの七夕の願い → 大人の七夕。
/// - 年越し（[kSeasonRepeatIds]）だけは何度でも出る（三年あけて。書き出しを回数で変える）。ほかは一生に一度。
/// - 死ぬのは印地打ちの石つぶてだけ（まれ）。位は動かさない。

// ---------------------------------------------------------------- 出し方

/// 大人の静かな年に、季節の行事が一つ巡ってくる確率。
const kSeasonQuietChance = .55;

/// 子どもの、岐路の起きなかった年に、季節の行事が一つ巡ってくる確率。
const kSeasonChildQuietChance = .4;

/// 季節の行事の岐路か（ふつうの年の候補から外し、静かな年にだけ出す）。
bool isSeasonScene(String id) => id.startsWith('sn_');

// ---------------------------------------------------------------- 誰に出るか

bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);

/// 主家に仕える武家（位1〜7・隠居でない・仏門でない・主家が生きている）。
bool snBushi(Game g) =>
    g.l.rank >= 1 && g.l.rank <= 7 && g.active && !g.hasFlag('priesthood') && _lordAlive(g);

/// 戦える武家（流鏑馬・灯籠）。
bool snWarrior(Game g) => snBushi(g) && g.canFight;

/// 奥で仕える女性（武家で、嫁いでいない女性）。
bool snOku(Game g) => snBushi(g) && g.l.female && !g.l.married;

/// 一国の主（位8）。
bool snLord(Game g) =>
    g.l.rank == 8 && g.active && !g.hasFlag('priesthood') && _lordAlive(g);

/// 寺にいる僧・尼。
bool snMonk(Game g) => g.hasFlag('priesthood') && g.active;

bool _commoner(Game g) =>
    g.l.rank == 0 && !g.hasFlag('priesthood') && !g.hasFlag('way_outlaw') && g.active;

/// 田を作る百姓・浜の者（商いの道に入っていない）。
bool snFarmer(Game g) =>
    _commoner(g) &&
    !g.hasFlag('way_merchant') &&
    const ['farmer', 'fisher'].contains(g.l.cls.id);

/// 町で商う者（商いの道に入ったか、町人の家の人）。
bool snTown(Game g) =>
    _commoner(g) && (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

/// 暮らしの苦しい者（身分なし・銭が乏しい。商人の掛け取りは `trade_farm.dart` にあるので、商いの道の人は除く）。
bool snPoor(Game g) => _commoner(g) && !g.hasFlag('way_merchant') && g.l.gold < 20;

/// この岐路を出してよい人（テストも使う）。死んでいなければ誰でも、あとは場面ごとの条件で絞る。
bool snLife(Game g) => g.l.dead == null;

// ---------------------------------------------------------------- 表

/// 大人の岐路の id（テストが使う）。
const kSeasonIds = [
  'sn_nenga',
  'sn_lord_nenga',
  'sn_hatsuyume',
  'sn_setsubun',
  'sn_hina',
  'sn_inji',
  'sn_mushiokuri',
  'sn_tanabata',
  'sn_tanabata_kaeri',
  'sn_bon_mukaebi',
  'sn_bon_odori',
  'sn_bon_odori_after',
  'sn_toro',
  'sn_tanagyo',
  'sn_hassaku',
  'sn_tsukimi',
  'sn_tsukimi_after',
  'sn_yabusame',
  'sn_yabusame_after',
  'sn_choyo',
  'sn_kaketori',
  'sn_susuharai',
  'sn_susuharai_after',
  'sn_toshikoshi',
];

/// 子どもの岐路の id（テストが使う）。
const kSeasonChildIds = [
  'sn_c_kite',
  'sn_c_kakizome',
  'sn_c_hina',
  'sn_c_shobu',
  'sn_c_tanabata',
  'sn_c_bonodori',
  'sn_c_inoko',
  'sn_c_mochi',
];

/// 何度でも出る岐路（三年あけて）。
const kSeasonRepeatIds = ['sn_toshikoshi'];

/// 岐路の季節（0 春・1 夏・2 秋・3 冬）。旧暦で、七月からを秋とする。
const kSeasonOf = <String, int>{
  'sn_nenga': 0,
  'sn_lord_nenga': 0,
  'sn_hatsuyume': 0,
  'sn_setsubun': 0,
  'sn_hina': 0,
  'sn_inji': 1,
  'sn_mushiokuri': 1,
  'sn_tanabata': 2,
  'sn_tanabata_kaeri': 2,
  'sn_bon_mukaebi': 2,
  'sn_bon_odori': 2,
  'sn_bon_odori_after': 2,
  'sn_toro': 2,
  'sn_tanagyo': 2,
  'sn_hassaku': 2,
  'sn_tsukimi': 2,
  'sn_tsukimi_after': 2,
  'sn_yabusame': 2,
  'sn_yabusame_after': 2,
  'sn_choyo': 2,
  'sn_kaketori': 3,
  'sn_susuharai': 3,
  'sn_susuharai_after': 0,
  'sn_toshikoshi': 3,
  'sn_c_kite': 0,
  'sn_c_kakizome': 0,
  'sn_c_hina': 0,
  'sn_c_shobu': 1,
  'sn_c_tanabata': 2,
  'sn_c_bonodori': 2,
  'sn_c_inoko': 3,
  'sn_c_mochi': 3,
};

/// 身分で出し分ける岐路 → 出てよい人（テストが使う）。
final kSeasonWho = <String, bool Function(Game)>{
  'sn_nenga': snBushi,
  'sn_yabusame': snWarrior,
  'sn_yabusame_after': snWarrior,
  'sn_toro': snWarrior,
  'sn_lord_nenga': snLord,
  'sn_mushiokuri': snFarmer,
  'sn_hassaku': snTown,
  'sn_tanagyo': snMonk,
  'sn_kaketori': snPoor,
};

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kSeasonPrev = <String, List<String>>{
  'sn_bon_odori_after': ['sn_odori_met'],
  'sn_tsukimi_after': ['sn_tsuki_promise'],
  'sn_yabusame_after': ['sn_yabu_hit', 'sn_yabu_miss'],
  'sn_susuharai_after': ['sn_susu_sent'],
  'sn_tanabata_kaeri': ['sn_c_wish_rise', 'sn_c_wish_family', 'sn_c_wish_hand'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kSeasonGap = <String, (String, int)>{
  'sn_bon_odori_after': ('odori', 1),
  'sn_tsukimi_after': ('tsuki', 1),
  'sn_yabusame_after': ('yabu', 2),
  'sn_susuharai_after': ('susu', 1),
  'sn_tanabata_kaeri': ('wish', 6),
};

// ---------------------------------------------------------------- 筋と季節の補助

void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('sn_at:$chain:'));
  g.setFlag('sn_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int snSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('sn_at:$chain:')) {
      return g.year - int.parse(f.substring('sn_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool snChainReady(Game g, String id) {
  final prev = kSeasonPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kSeasonGap[id];
  if (gap == null) return true;
  return snSince(g, gap.$1) >= gap.$2;
}

/// 前に出た季節の行事の季節。まだなければ -1。
int snLastSeason(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('sn_last:')) return int.parse(f.substring(8));
  }
  return -1;
}

void _turn(Game g, String id) {
  g.l.flags.removeWhere((f) => f.startsWith('sn_last:'));
  g.setFlag('sn_last:${kSeasonOf[id] ?? 0}');
}

/// 前と同じ季節の行事は出にくくする（季節が巡るように）。
double _sw(Game g, String id, double w) =>
    snLastSeason(g) == (kSeasonOf[id] ?? 0) ? w * .3 : w;

SceneDef _sn(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run, {
  bool repeat = false,
}) => SceneDef(
  id,
  minAge,
  maxAge,
  (g) => _sw(g, id, w),
  (g) => who(g) && snChainReady(g, id),
  (g, next) {
    _turn(g, id);
    run(g, next);
  },
  repeat: repeat,
);

// ---------------------------------------------------------------- 補助

void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _hp(Game g, int n) => g.l.hp = clampInt(g.l.hp + n, 1, g.l.maxhp);
int _c(int v) => clampInt(v, 0, 100);
double _try(int v, [double base = .45]) => clampD(base + v / 300, base, .85);

String? _who(Game g, String role) => g.l.people[role]?.name;

/// いまも夫婦でいる連れ合いの名。
String? _spouse(Game g) => g.l.married ? _who(g, '伴侶') : null;

void _bond(Game g, String role, int n) {
  final p = g.l.people[role];
  if (p != null) p.bond = clampInt(p.bond + n, 0, 100);
}

const _kidRoles = ['嫡男', '娘', '子', '養子'];

/// 名のある子の役割（嫡男・娘・子・養子）。いなければ null。
String? _kidRole(Game g) {
  for (final r in _kidRoles) {
    if (g.l.people.containsKey(r)) return r;
  }
  return null;
}

/// 名のある子の名。いなければ null。
String? _kidName(Game g) {
  final r = _kidRole(g);
  return r == null ? null : _who(g, r);
}

String _named(Game g, String head, String fallback) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return fallback;
}

String _hn(Game g) => g.l.lord == null ? '主家' : '${houseName(g, g.l.lord)}家';

// ======================================================================
// 大人の岐路
// ======================================================================

List<SceneDef> buildSeasonScenes() => [
  ..._spring(),
  ..._summer(),
  ..._autumn(),
  ..._winter(),
];

// ---------------------------------------------------------------- 春（正月・節分・上巳）

List<SceneDef> _spring() => [
  // ============================================ 武家: 主君への年賀
  _sn('sn_nenga', 15, 70, 3, snBushi, (g, next) {
    final l = g.l;
    final h = _hn(g);
    if (snOku(g)) {
      g.ask('奥の年始', '元日の朝、奥の女たちは晴れ着をまとい、$hの奥方さまのもとへ年始の挨拶に上がる。並ぶ順は古くからの格で決まっていて、新しく上がった者は廊下の端に控える。今年、奥方さまの前に出す祝いの品の役が、あなたに回ってきた。', [
        Choice.h('しきたりどおりの品を、しきたりどおりに捧げる', '咎められることはない。誰の目にも残らない', () {
          l.fav += 2;
          return '昆布と勝栗を三方に載せ、作法のとおりに捧げた。奥方さまは軽くうなずいただけだった。';
        }),
        Choice.h('自ら縫った小さな袋に、香を入れて添える', '奥方さまの目に留まるかもしれない。年かさの女中には出過ぎと見られる', () {
          if (g.rng.chance(_try(l.mi, .5))) {
            l.fav += 5;
            g.setFlag('sn_nenga_noticed');
            return '奥方さまは袋を手に取り、香を聞いて「誰の縫い目か」と尋ねた。年かさの女中が、黙ってあなたのほうを見た。';
          }
          _net(g, -2);
          return '袋は三方の端に置かれたまま、誰の手にも取られなかった。下がる廊下で、年かさの女中に袖を引かれた。';
        }),
        if (l.chi >= 55)
          Choice.h('祝いの品に、古い歌を書いた短冊を添える', '歌の分かる奥方さまなら喜ぶ。書き損じれば恥になる', () {
            if (g.rng.chance(_try(l.chi, .5))) {
              l.fav += 6;
              _fame(g, 2);
              g.setFlag('sn_nenga_noticed');
              return '春を寿ぐ古い歌を一首、細い筆で書いた。奥方さまは声に出して読み、侍女たちに回して見せた。';
            }
            l.fav -= 1;
            return '墨がにじみ、字が一つ崩れた。奥方さまは何も言わず、短冊は伏せて置かれた。';
          }),
      ], after: next);
      return;
    }
    g.ask('年始の礼', '元日、$hの館の大広間に家中の者が居並ぶ。主君の前に一人ずつ進み出て、年始の礼を述べ、盃をいただく。あなたの席は、去年より${l.rank >= 3 ? '少し前' : 'まだ後ろのほう'}だ。', [
      Choice.h('型どおりに礼を述べ、盃をいただく', '何事もなく済む。主君の目には残らない', () {
        l.fav += 2;
        return '口上を述べ、盃を干して下がった。廊下には、まだ礼を待つ者が並んでいた。';
      }),
      Choice.h('身の丈を越えた太刀を献じる', '主君の覚えはよくなる。蔵は軽くなり、朋輩には妬まれる', () {
        _pay(g, 12);
        l.fav += 6;
        _net(g, -1);
        g.setFlag('sn_nenga_tachi');
        return '白鞘の太刀を三方に載せて差し出した。主君は鞘を払って刃を眺め、「よい年になりそうだ」と笑った。';
      }),
      if (l.mi >= 60)
        Choice.h('請われて、年始の謡を一番うたう', '座が華やぐ。声が外れれば笑い者になる', () {
          if (g.rng.chance(_try(l.mi, .5))) {
            l.fav += 5;
            _fame(g, 3);
            _net(g, 2);
            g.setFlag('sn_nenga_utai');
            g.mark('年始の礼の席で、請われて謡を一番うたった');
            return '朗々とうたい終えると、主君が扇で膝を打った。その年から、年始の謡はあなたの役になった。';
          }
          _fame(g, -1);
          return '二の句で声がかすれた。主君は笑って盃を差し出したが、広間の隅で忍び笑いが聞こえた。';
        }),
    ], after: next);
  }),

  // ============================================ 大名: 国人の年賀
  _sn('sn_lord_nenga', 18, 84, 4, snLord, (g, next) {
    final l = g.l;
    final kokujin = '${g.rng.pick(kSurnames)}家';
    g.ask('年賀に来ない国人', '正月、国中の国人や寺社の名代が、次々と年賀の礼に城へ上がってくる。だが、山あいに所領を持つ$kokujinの当主だけが、病と称して名代も寄こさない。家臣たちは、隣国に通じているのではないかとささやき合っている。', [
      Choice.h('使いを出して、病の見舞いの品を届けさせる', '角は立たない。侮られたままになるかもしれない', () {
        _pay(g, 4);
        _net(g, 2);
        g.setFlag('sn_lord_nenga_mild');
        return '見舞いの品を携えた使いが、雪の山道を登っていった。春になって、$kokujinの当主から丁寧な礼状が届いた。';
      }),
      Choice.h('次の評定に呼びつけ、来なければ所領を召し上げると告げる', '家中は引き締まる。追い詰められた国人は隣国へ走るかもしれない', () {
        if (g.rng.chance(.6)) {
          l.fame += 2;
          return '$kokujinの当主は、青い顔で評定の末席に座った。それからは、どの国人も年賀を欠かさなくなった。';
        }
        _net(g, -2);
        g.fa[l.lord]!.power = g.fa[l.lord]!.power * .98;
        return '$kokujinは返事を寄こさず、春のうちに所領ごと隣国へ寝返った。';
      }),
      if (l.mi >= 60)
        Choice.h('鷹狩りにかこつけて、自ら山の館を訪ねる', '心がつかめれば一門のような味方になる。山の館は守りが薄い', () {
          if (g.rng.chance(_try(l.mi, .5))) {
            _net(g, 4);
            _fame(g, 2);
            g.fa[l.lord]!.power += 1;
            g.setFlag('sn_lord_nenga_visit');
            g.mark('年賀に来なかった山あいの国人の館を自ら訪ね、心をつかんだ');
            return '主が自ら来るとは思わなかったのだろう。当主は庭に飛び出して平伏した。囲炉裏端で酒を酌み交わし、帰りには当主の子が鷹を据えて供についてきた。';
          }
          _net(g, -1);
          return '館の門は閉ざされたままで、留守を預かる老臣が平伏して詫びるばかりだった。';
        }),
    ], after: next);
  }),

  // ============================================ 誰でも: 初夢
  _sn('sn_hatsuyume', 15, 80, 2.5, snLife, (g, next) {
    final l = g.l;
    final sp = _spouse(g);
    final dream = g.rng.pick([
      ('大きな船が、帆に風をはらんで港に入ってくる夢', true),
      ('見知らぬ山の頂から、朝日を拝む夢', true),
      ('古い家の柱が、音もなく折れる夢', false),
      ('幼い日に住んだ家の土間に、自分が一人で立っている夢', false),
    ]);
    g.ask('初夢', '正月二日の夜、宝船の絵を枕の下に敷いて眠った。見たのは、${dream.$1}だった。目が覚めても、その景色がまぶたに残っている。', [
      Choice.h(sp == null ? '誰にも言わず、胸にしまっておく' : '$spにだけ話して聞かせる', '夢は口に出さぬほうがよいとも言う。心の内は軽くなる', () {
        g.j(dream.$2 ? 4 : 1);
        if (sp != null) {
          _bond(g, '伴侶', 3);
          return '$spは黙って聞き、「よい年になりますように」と白湯を差し出した。';
        }
        return '夢のことは誰にも話さなかった。その年の暮れに、ふと思い出した。';
      }),
      Choice.h('社の禰宜に夢解きを頼む', '吉と出れば勇む。凶と出れば一年気にかかる', () {
        _pay(g, 1);
        if (dream.$2 || g.rng.chance(.4)) {
          g.j(6);
          l.un = _c(l.un + 2);
          g.setFlag('sn_yume_good');
          return '禰宜は「福が向こうから来る夢だ」と言った。帰り道、足取りが軽かった。';
        }
        g.j(-3);
        return '禰宜は少し黙ってから「身の回りの者を大事にせよ」とだけ言った。';
      }),
      Choice.h('夢など当てにせず、朝から仕事に出る', '迷いは生まれない。福も呼び込まない', () {
        l.gold += 2;
        return '枕の下の絵を丸めて、いつもどおり働きに出た。';
      }),
    ], after: next);
  }),

  // ============================================ 子のある人: 節分
  _sn(
    'sn_setsubun',
    20,
    65,
    3,
    (g) => g.l.kids > 0 && g.l.hasKidAged(g.year, 2, 12),
    (g, next) {
      final k = _kidName(g);
      final kid = k ?? '幼い子';
      g.ask('節分の鬼', '年越しの夜（節分）、家の戸口に柊と鰯の頭を挿し、豆を打って鬼を追う。$kidは、鬼が来ると聞いてから、夕方より柱の陰に隠れて出てこない。', [
        Choice.h('自ら鬼の面をかぶり、追われ役になる', '子は笑って豆を打つ。少し痛い', () {
          g.j(6);
          _hp(g, -1);
          final role = _kidRole(g);
          if (role != null) _bond(g, role, 4);
          g.setFlag('sn_setsubun_oni');
          return '面をかぶって戸口に立つと、$kidは泣きべそをかきながら豆をつかんで投げてきた。最後には、自分から鬼を外まで追い出した。';
        }),
        Choice.h('子を抱いて、一緒に豆を打つ', '子は安心する。鬼を追う役は誰もいない', () {
          g.j(4);
          return '$kidを膝に乗せ、小さな手に豆を握らせて「鬼は外」と言わせた。';
        }),
        Choice.h('鬼など来ぬと叱って、早く寝かせる', '夜は静かだ。子は少し寂しがる', () {
          g.j(1);
          return '$kidは布団の中で、遠くの家々の「鬼は外」の声をいつまでも聞いていた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 子のある人: 上巳の祓え
  _sn(
    'sn_hina',
    18,
    55,
    3,
    (g) => g.l.kids > 0 && g.l.hasKidAged(g.year, 0, 9) && !g.hasFlag('priesthood'),
    (g, next) {
      final k = _kidName(g) ?? '子';
      g.ask('上巳の祓え', '三月三日、紙で人の形（ひとがた）を作り、子の体をなでて穢れを移し、川へ流す。$kの分のひとがたを、自分の手で作ることにした。', [
        Choice.h('子の無事だけを祈って、川へ流す', '心は静まる。祈りは川とともに去る', () {
          g.j(4);
          g.setFlag('sn_hina_prayed');
          return '$kの小さな手を添えて、ひとがたを川面に置いた。くるくると回りながら、下流へ消えていった。';
        }),
        Choice.h('色紙で着物を着せた、美しいひいなを作って飾る', '子は喜ぶ。祓えの形からは外れると年寄りが眉をひそめる', () {
          _pay(g, 2);
          g.j(5);
          g.setFlag('sn_hina_doll');
          return '色紙を重ねて、小さな着物を着せた。$kは一日じゅう、ひいなを抱いて離さなかった。';
        }),
        Choice.h('戦や病で亡くした者の分も、ひとがたを作る', '胸の内が少し晴れる。川辺で涙が出る', () {
          g.j(2);
          _net(g, 1);
          return '名を書いたひとがたを並べて流した。隣で流していた女が、黙って頭を下げた。';
        }),
      ], after: next);
    },
  ),
];

// ---------------------------------------------------------------- 夏（端午・虫送り）

List<SceneDef> _summer() => [
  // ============================================ 若い男: 端午の印地打ち
  _sn(
    'sn_inji',
    15,
    26,
    3,
    (g) =>
        !g.l.female &&
        g.l.rank <= 2 &&
        g.active &&
        !g.hasFlag('priesthood'),
    (g, next) {
      final l = g.l;
      g.ask('端午の印地打ち', '五月五日、軒に菖蒲を挿したあと、川原で若い衆が東西に分かれて石を投げ合う印地打ちが始まる。毎年、怪我人が出る。今年は隣の町の者たちが、腕の立つ者を集めてきたという。', [
        Choice.h('前に出て、石をかいくぐって組み打ちに行く', '名を上げられる。石つぶては時に命を奪う', () {
          if (g.rng.chance(.02)) {
            g.die('端午の川原で、印地打ちの石つぶてをこめかみに受け、そのまま起き上がらなかった', 'sai');
            return '飛んできた石が見えなかった。';
          }
          if (g.rng.chance(_try(l.bu, .4))) {
            l.bu = _c(l.bu + 2);
            _fame(g, 2);
            _net(g, 2);
            g.setFlag('sn_inji_won');
            return '石の雨をくぐって相手の頭を組み伏せると、向こうの列が崩れた。夕方、若い衆に担がれて町へ戻った。';
          }
          _hp(g, -8);
          return '額に石を受けて倒れ、仲間に引きずられて下がった。傷は、ひと月残った。';
        }),
        Choice.h('後ろから石を拾って渡す役に回る', '怪我は少ない。手柄もない', () {
          l.bu = _c(l.bu + 1);
          _net(g, 1);
          return '袂いっぱいに石を集め、前の者に渡し続けた。日暮れには、腕が上がらなくなっていた。';
        }),
        Choice.h('年寄りと一緒に、間に入って止めさせる', '血は流れない。若い衆には臆病と言われる', () {
          if (g.rng.chance(_try(l.mi, .35))) {
            _net(g, 2);
            _fame(g, 1);
            g.setFlag('sn_inji_stopped');
            return '両方の頭を呼んで、菖蒲湯の酒で手打ちにさせた。年寄りたちが、あなたの背をたたいた。';
          }
          _net(g, -1);
          return '声は石の音にかき消された。結局、二人が担がれて帰った。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 百姓: 虫送り
  _sn('sn_mushiokuri', 16, 70, 3.5, snFarmer, (g, next) {
    final l = g.l;
    g.ask('虫送り', '梅雨明けの田に、稲の葉を食う虫が湧いた。村では夜、松明を連ね、鉦と太鼓を打ち鳴らして虫を村境の外へ送り出す。田の神に、今年の実りを願う夜でもある。', [
      Choice.h('松明を掲げて、行列の先頭を歩く', '田の神に姿を見せられる。夜通し歩き、体はこたえる', () {
        _net(g, 3);
        g.j(3);
        _hp(g, -3);
        g.setFlag('sn_mushi_led');
        return '松明の火が畦道に長く連なった。村境の辻で藁の人形を焼くと、火の粉が夜空に舞い上がった。';
      }),
      Choice.h('銭を出して、社に田の神の祈祷を頼む', '心強い。銭が出ていく', () {
        _pay(g, 3);
        g.j(2);
        return '禰宜が田の畦に立って祝詞を上げた。そのあとも、虫は少しずつ減っていった。';
      }),
      if (l.chi >= 55)
        Choice.h('行列に加わりつつ、田に灰と油をまく工夫を村に広める', '知恵が当たれば虫は目に見えて減る。古い者は神事に手を加えるのを嫌う', () {
          if (g.rng.chance(_try(l.chi, .5))) {
            l.gold += 4;
            _net(g, 2);
            _fame(g, 2);
            g.setFlag('sn_mushi_ash');
            g.mark('虫の湧いた夏、田に灰と油をまいて虫を払う工夫を村に広めた');
            return '朝露の乾かぬうちに灰をまき、水口から油を垂らした。虫は葉から落ち、秋の田は隣村より重く垂れた。';
          }
          _net(g, -1);
          return '灰は風に飛ばされ、虫は減らなかった。年寄りに「神様に任せておけ」とたしなめられた。';
        }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 秋（七夕・盆・八朔・月見・流鏑馬・重陽）

List<SceneDef> _autumn() => [
  // ============================================ 女性: 七夕の願い
  _sn(
    'sn_tanabata',
    15,
    55,
    3,
    (g) => g.l.female && !g.hasFlag('priesthood'),
    (g, next) {
      final l = g.l;
      final sp = _spouse(g);
      g.ask('七夕', '七月七日の夜、梶の葉に願いを書き、竹に結んで星に供える。女たちは機織りや手習いの上達を願う。${sp == null ? '' : '$spは、何を書くのかと覗き込んでくる。'}', [
        Choice.h('機織りと針の上達を願う', '手仕事が上がる。願いはささやかだ', () {
          l.sei = _c(l.sei + 2);
          g.j(2);
          return '梶の葉に、細い字で「はたおり」と書いた。夜風に、竹の葉がさらさらと鳴った。';
        }),
        Choice.h(sp == null ? '人に言えない想いを、そっと書く' : '$spとの暮らしが続くよう願う', '胸の内が少し軽くなる。見られれば恥ずかしい', () {
          g.j(5);
          if (sp != null) {
            _bond(g, '伴侶', 4);
            g.setFlag('sn_tanabata_couple');
            return '葉を裏返して結んだのに、$spには見られていた。何も言わずに、隣で星を見上げていた。';
          }
          return '誰にも見えぬよう、葉の裏に小さく書いた。天の川が、いつもより白く見えた。';
        }),
        if (l.chi >= 50)
          Choice.h('歌を詠んで梶の葉に書き、星に手向ける', '歌の才があれば人の口にのぼる。気取っていると言われるかもしれない', () {
            if (g.rng.chance(_try(l.chi, .45))) {
              _fame(g, 2);
              l.mi = _c(l.mi + 2);
              g.setFlag('sn_tanabata_uta');
              return '星合いの歌を一首書いて結んだ。翌日、近所の娘たちがその歌を口ずさんでいた。';
            }
            return '言葉が五つ七つに収まらず、結局「ねがい」とだけ書いた。';
          }),
      ], after: next);
    },
  ),

  // ============================================ 筋の後段: 幼い日の七夕の願い
  _sn('sn_tanabata_kaeri', 20, 70, 6, snLife, (g, next) {
    final l = g.l;
    final wish = g.hasFlag('sn_c_wish_rise')
        ? '「えらくなる」'
        : g.hasFlag('sn_c_wish_family')
        ? '「みんな　ぶじで」'
        : '「じがうまくなるように」';
    final came = g.hasFlag('sn_c_wish_rise')
        ? l.maxRank >= 3 || l.gold >= 80
        : g.hasFlag('sn_c_wish_family')
        ? !g.hasFlag('fatherdead') && !g.hasFlag('fa_lost_child')
        : l.chi >= 50;
    g.ask('幼い日の願い', '七夕の竹に、子どもたちが梶の葉を結んでいる。ふと、幼い日に自分も$wishと書いたことを思い出した。${came ? 'あの願いは、いくらかは叶ったのかもしれない。' : 'あの願いは、叶わなかった。'}', [
      Choice.h('子どもたちに、自分の幼い日の願いを話して聞かせる', '子らは目を丸くする。昔の自分が少し照れくさい', () {
        g.j(4);
        _net(g, 2);
        if (came) {
          g.setFlag('sn_wish_kept');
          g.mark('七夕の竹の下で、幼い日の願いを子らに語った');
        }
        return '「本当に叶うの」と、小さな子が聞いた。笑ってうなずき、その子の梶の葉を高い枝に結んでやった。';
      }),
      Choice.h('もう一度、梶の葉に同じ願いを書く', '心がまだ若い。叶わぬ願いを抱え直すことにもなる', () {
        g.j(came ? 3 : 1);
        l.un = _c(l.un + 2);
        return '大人の手で、幼い日と同じ言葉を書いた。字は上手くなったが、願いは変わらなかった。';
      }),
      Choice.h('黙って竹を見上げ、通り過ぎる', '何も変わらない。胸に小さな灯がともる', () {
        g.j(1);
        return '天の川の下を、家路についた。';
      }),
    ], after: next);
  }),

  // ============================================ 亡くした者のいる人: 盆の迎え火
  _sn(
    'sn_bon_mukaebi',
    18,
    85,
    4,
    (g) =>
        g.hasFlag('fatherdead') ||
        g.hasFlag('fa_lost_child') ||
        g.hasFlag('fa_spouse_died') ||
        g.hasFlag('bd_ms_dead'),
    (g, next) {
      final master = _named(g, 'bd_ms_name:', '');
      final whom = g.hasFlag('fa_lost_child')
          ? '幼くして逝った子'
          : g.hasFlag('fa_spouse_died')
          ? '先に逝った連れ合い'
          : g.hasFlag('bd_ms_dead')
          ? (master.isEmpty ? '亡き師' : '亡き師の$master')
          : '亡き父';
      g.ask('盆の迎え火', '七月十三日の夕暮れ、門口で苧殻を焚いて、亡き者の魂を迎える。今年は、$whomが帰ってくる初めての盆のように思えてならない。', [
        Choice.h('火の前で、$whomの名を呼ぶ', '胸の内が晴れる。涙を見せることにもなる', () {
          g.j(5);
          _net(g, 1);
          g.setFlag('sn_bon_called');
          return '細い煙が、まっすぐに空へのぼった。名を呼ぶと、背中のほうで、誰かが戸を開けたような気がした。';
        }),
        Choice.h('精霊棚に、$whomの好んだものを供える', '供えは手間がかかる。心はこもる', () {
          _pay(g, 2);
          g.j(4);
          return '茄子と瓜で牛と馬を作り、棚の前に好物の干し柿を並べた。三日のあいだ、灯明を絶やさなかった。';
        }),
        Choice.h('火を焚いたら、すぐに家に入る', '悲しみは深く沈めたままにする。何も変わらない', () {
          g.j(-1);
          return '苧殻が燃え尽きる前に、戸を閉めた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 筋: 盆踊り
  _sn(
    'sn_bon_odori',
    15,
    28,
    4,
    (g) =>
        !g.l.married &&
        g.l.rank <= 2 &&
        g.active &&
        !g.hasFlag('priesthood') &&
        !g.hasFlag('sn_odori_met'),
    (g, next) {
      final l = g.l;
      final name = l.female ? g.rng.pick(kGivenM) : g.rng.pick(kGivenF);
      g.ask('盆踊り', '盆の夜、寺の境内に大きな輪ができた。笛と太鼓に合わせて、村や町の者が夜更けまで踊る。輪の向こうで、笠を目深にかぶった${l.female ? '若い男' : '娘'}が、あなたと同じ手振りで踊っている。', [
        Choice.h('輪の中で隣に回り、声をかける', '縁が生まれるかもしれない。笑われて終わることもある', () {
          g.j(6);
          if (g.rng.chance(_try(l.mi, .55))) {
            g.setFlag('sn_odori_met');
            g.setFlag('sn_odori_name:$name');
            _stamp(g, 'odori');
            return '笠の下から、$nameと名乗る声がした。夜明け近く、輪がほどけるまで、二人で踊り続けた。';
          }
          return '声をかけると、笠の主は笑って輪の向こうへ消えた。';
        }),
        Choice.h('同じ手振りで踊り続け、目が合うのを待つ', '気づいてもらえるかは運しだい。気楽だ', () {
          g.j(4);
          if (g.rng.chance(_try(l.un, .35))) {
            g.setFlag('sn_odori_met');
            g.setFlag('sn_odori_name:$name');
            _stamp(g, 'odori');
            return '輪がほどけるとき、笠の主のほうから「また来年も」と声をかけてきた。名は$nameといった。';
          }
          return '目は一度だけ合ったが、それきりだった。';
        }),
        Choice.h('仲間と飲み食いして、踊りは見ているだけにする', '何も起きない。気楽な夜だ', () {
          g.j(3);
          _net(g, 1);
          return '石段に座って、輪の灯りを眺めていた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 筋の後段: 翌年の盆
  _sn(
    'sn_bon_odori_after',
    16,
    45,
    30,
    (g) => g.active && !g.hasFlag('priesthood'),
    (g, next) {
      final l = g.l;
      final name = _named(g, 'sn_odori_name:', l.female ? '与作' : 'お福');
      if (l.married) {
        // ほかの人と夫婦になったあとの盆。
        final sp = _who(g, '伴侶') ?? '連れ合い';
        g.ask('盆の再会', '盆の輪のそばで、見覚えのある笠の人とすれ違った。あの年の盆に一緒に踊った$nameだ。$nameも、もう誰かの連れ合いになったらしい。', [
          Choice.h('呼び止めて、あの年の盆の話をする', '懐かしい。$spに知れれば気まずい', () {
            g.j(4);
            if (g.rng.chance(.3)) _bond(g, '伴侶', -3);
            g.setFlag('sn_odori_memory');
            return '二人で笑いながら、あの年の太鼓の音や、夜明けの境内の話をした。別れ際、$nameは「達者で」と言った。';
          }),
          Choice.h('$spの手を引いて、輪の中へ入る', '今の暮らしを大事にできる。少し胸が痛む', () {
            g.j(3);
            _bond(g, '伴侶', 4);
            return '輪の向こうで、笠が小さく揺れて、人ごみに消えていった。';
          }),
        ], after: next);
        return;
      }
      g.ask('約束の盆', '今年も、盆の輪ができた。あの年の$nameは来るだろうかと、日が暮れる前から境内の石段に座っていた。やがて、見覚えのある笠が人ごみの中に揺れた。', [
        Choice.h('夫婦になってほしいと告げる', '思いが通じれば家を持てる。身内に反対されるかもしれない', () {
          if (g.rng.chance(_try(l.mi, .55))) {
            l.married = true;
            g.meet('伴侶', name, 60);
            g.j(10);
            _net(g, 2);
            g.setFlag('sn_odori_wed');
            g.mark('盆踊りで出会った$nameと、次の年の盆に夫婦の約束を交わした');
            return '$nameは笠を取り、黙ってうなずいた。秋の取り入れが終わると、二人は小さな家を構えた。';
          }
          g.j(-4);
          g.setFlag('sn_odori_parted');
          return '$nameはうつむいて、親の決めた相手がいると言った。踊りの輪に戻っていく背を、見送るしかなかった。';
        }),
        Choice.h('今年も夜明けまで踊るだけにする', '楽しい夜が続く。縁はそれ以上進まない', () {
          g.j(6);
          return 'あの年と同じ手振りで、あの年より近くで踊った。別れ際、$nameは「また来年」と言った。';
        }),
        Choice.h('身の上の違いを思って、声をかけずに帰る', '傷つかずに済む。あとで悔いが残るかもしれない', () {
          g.j(-2);
          g.setFlag('sn_odori_parted');
          return '笠の揺れる輪に背を向けて、石段を下りた。太鼓の音が、家の戸口まで追いかけてきた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 武家: 灯籠流し
  _sn(
    'sn_toro',
    17,
    70,
    3.5,
    (g) => snWarrior(g) && g.hasFlag('first_battle'),
    (g, next) {
      final l = g.l;
      g.ask('灯籠流し', '盆の終わりの夜、川に灯籠を流して、精霊を送る。今年の戦で、同じ組の者が幾人も帰らなかった。川原には、遺された家の者たちが集まっている。', [
        Choice.h('討ち死にした朋輩の名を、一人ずつ灯籠に書く', '遺された家の者に頭を下げられる。思い出す顔がつらい', () {
          _net(g, 3);
          g.j(2);
          g.setFlag('sn_toro_comrades');
          return '覚えている名を書き尽くすと、灯籠は両手に余った。流れに乗った灯は、しばらく寄り添うように揺れていた。';
        }),
        Choice.h('自分が討った敵の分も、名を知らぬまま灯籠を流す', '心が少し軽くなる。朋輩には甘いと言われるかもしれない', () {
          g.j(4);
          if (g.rng.chance(.3)) l.fav -= 1;
          g.setFlag('sn_toro_foe');
          g.mark('盆の灯籠流しで、戦で討った名も知らぬ敵の灯籠を流した');
          return '名を書く代わりに、小さく丸を一つ描いた。隣にいた老いた足軽が、黙って手を合わせた。';
        }),
        Choice.h('灯籠は家の者に任せ、遠くから見送る', '何も変わらない。胸のつかえは残る', () {
          return '土手の上から、川を下っていく灯の列を眺めていた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 僧: 盆の棚経
  _sn('sn_tanagyo', 18, 85, 4, snMonk, (g, next) {
    final l = g.l;
    g.ask('盆の棚経', '盆には、檀家の家々の精霊棚の前で経をあげて回る。回る家は多く、日は短い。布施の多い家ほど、早く来てほしいと寺に使いを寄こしてくる。', [
      Choice.h('貧しい家、遠い家から先に回る', '名もない家の者に慕われる。布施の多い家は機嫌を損ねる', () {
        _net(g, 3);
        _fame(g, 1);
        l.gold -= l.gold >= 2 ? 2 : l.gold;
        g.setFlag('sn_tanagyo_poor');
        g.mark('盆の棚経を、貧しい家・遠い家から先に回った');
        return '山の奥の一軒家では、老婆が戸口で待っていた。経のあいだ、ずっと手を合わせて泣いていた。';
      }),
      Choice.h('布施の多い家から順に回る', '寺は潤う。村の口は厳しい', () {
        l.gold += 6;
        _net(g, -2);
        return '大きな家の棚の前では、膳まで出された。夕暮れ、遅れた家の戸口で、小さな子に恨めしそうに見られた。';
      }),
      if (l.chi >= 55)
        Choice.h('経のあとに、その家の亡き者の話を聞き、短い法話をする', '家の者の心に残る。回りきれない家が出る', () {
          _net(g, 4);
          _fame(g, 2);
          g.setFlag('sn_tanagyo_talk');
          return '亡き者の話を聞いてから経をあげると、家の者の顔が和らいだ。その年、回りきれなかった家には、盆明けに詫びて回った。';
        }),
    ], after: next);
  }),

  // ============================================ 町人: 八朔の贈り物
  _sn('sn_hassaku', 18, 75, 4, snTown, (g, next) {
    final l = g.l;
    g.ask('八朔の贈り物', '八月一日（八朔）は、日ごろ世話になる相手に贈り物をする日だ。得意先の武家の屋敷にも、毎年品を届けている。今年は、隣の店が屋敷へ立派な反物を届けたと噂が立った。', [
      Choice.h('隣の店に負けぬ品を届ける', '得意先はつなぎとめられる。蔵が軽くなる', () {
        _pay(g, 12);
        _net(g, 2);
        l.gold += g.rng.chance(.5) ? 10 : 0;
        return '京の織物を一反、桐の箱に入れて届けた。秋の具足の繕いの注文が、そっくりこちらに回ってきた。';
      }),
      Choice.h('例年どおりの品に、心ばかりの文を添える', '銭はかからない。得意先が離れるかもしれない', () {
        if (g.rng.chance(.5)) {
          _net(g, 1);
          return '用人から、文の礼が届いた。品より文が嬉しかった、と書いてあった。';
        }
        l.gold -= l.gold >= 4 ? 4 : l.gold;
        return 'その秋、屋敷の注文の半ばは隣の店に移った。';
      }),
      if (l.sei >= 55)
        Choice.h('屋敷の台所に通じて、奥方の好みを調べてから品を選ぶ', '品が当たれば長い付き合いになる。探りを入れたと知れれば嫌われる', () {
          if (g.rng.chance(_try(l.sei, .5))) {
            l.gold += 12;
            _net(g, 3);
            g.setFlag('sn_hassaku_fit');
            g.mark('八朔の贈り物で、得意先の武家の奥方の好みを言い当てた');
            return '奥方が香を好むと聞き、名のある香木を少しだけ届けた。翌年から、屋敷の買い物はすべてこちらを通すようになった。';
          }
          _net(g, -2);
          return '台所の女中に銭を握らせたことが用人に知れ、門前でたしなめられた。';
        }),
    ], after: next);
  }),

  // ============================================ 夫婦: 十五夜
  _sn(
    'sn_tsukimi',
    18,
    80,
    3.5,
    (g) => _spouse(g) != null && !g.hasFlag('priesthood'),
    (g, next) {
      final l = g.l;
      final sp = _spouse(g)!;
      g.ask('十五夜', '八月十五夜、縁側に芒と団子を供えた。家の者が寝静まったあと、$spが二つの盃を持ってきて、隣に座った。雲が切れて、月が顔を出した。', [
        Choice.h('来年もこうして月を見ようと約束する', '絆が深まる。約束は重く残る', () {
          _bond(g, '伴侶', 6);
          g.j(6);
          g.setFlag('sn_tsuki_promise');
          g.setFlag('sn_tsuki_with:$sp');
          _stamp(g, 'tsuki');
          return '$spは笑って、指を一本立てた。「来年も、そのまた先も」。';
        }),
        Choice.h('若い日のことを、夜更けまで語り合う', '心が通う。翌朝は眠い', () {
          _bond(g, '伴侶', 4);
          g.j(5);
          _hp(g, -1);
          return '二人が初めて会った日のことを、$spは驚くほどよく覚えていた。';
        }),
        if (l.chi >= 55)
          Choice.h('月を題に歌を詠み、$spに書いて渡す', '歌が届けば忘れられない夜になる。気恥ずかしい', () {
            _bond(g, '伴侶', 5);
            g.j(4);
            g.setFlag('sn_tsuki_promise');
            g.setFlag('sn_tsuki_with:$sp');
            g.setFlag('sn_tsuki_uta');
            _stamp(g, 'tsuki');
            return '懐紙に一首書いて渡した。$spは月明かりで二度読み、黙って袂にしまった。';
          }),
      ], after: next);
    },
  ),

  // ============================================ 筋の後段: 約束の月
  _sn('sn_tsukimi_after', 19, 85, 24, (g) => !g.hasFlag('priesthood'), (g, next) {
    // 約束を交わした連れ合いと、いまも夫婦でいるときだけ「約束の月」。
    final promised = _named(g, 'sn_tsuki_with:', '');
    final now = _spouse(g);
    final sp = now != null && (promised.isEmpty || promised == now) ? now : null;
    if (sp != null) {
      g.ask('約束の月', '今年も十五夜が来た。$spは何も言わず、あの年と同じ縁側に芒を挿している。${g.hasFlag('sn_tsuki_uta') ? 'あの夜の歌の紙は、まだ袂の小箱に入っているらしい。' : ''}', [
        Choice.h('約束どおり、二人で月を見る', '絆はいっそう深まる', () {
          _bond(g, '伴侶', 6);
          g.j(6);
          g.setFlag('sn_tsuki_kept');
          g.mark('十五夜の約束を守り、次の年も$spと縁側で月を見た');
          return '薄い雲の間に、月が出た。$spが、ほら、と指さした。';
        }),
        Choice.h('仕事を口実に、今年は先に寝る', '体は休まる。$spは寂しがる', () {
          _bond(g, '伴侶', -5);
          _hp(g, 2);
          return '夜半に目が覚めると、縁側に一人分の盃が伏せてあった。';
        }),
      ], after: next);
      return;
    }
    g.ask('一人の月', '十五夜が来た。いつか月を見ながら約束を交わした連れ合いは、もう隣にいない。縁側には、芒を挿す者もいない。', [
      Choice.h('一人で芒を挿し、二つの盃を並べる', '悲しみに向き合える。夜はひどく長い', () {
        g.j(2);
        g.setFlag('sn_tsuki_alone');
        return '盃の一つに酒を注ぎ、もう一つにも注いだ。月が雲に隠れるまで、縁側を離れなかった。';
      }),
      Choice.h('戸を閉めて、月を見ないようにする', '胸は痛まない。何かを置き去りにする', () {
        g.j(-3);
        return '戸の隙間から、白い光が一筋だけ差し込んでいた。';
      }),
    ], after: next);
  }),

  // ============================================ 武家: 秋の祭礼の流鏑馬
  _sn('sn_yabusame', 16, 50, 3.5, (g) => snWarrior(g) && g.l.rank >= 2, (g, next) {
    final l = g.l;
    final h = _hn(g);
    g.ask('流鏑馬', '秋の祭礼で、$hの家中から流鏑馬の射手を出すことになった。馬を駆けさせながら、馬場に立てた三つの的を射る。家中の者だけでなく、町や村の者も桟敷に詰めかける。', [
      Choice.h('射手に名乗り出る', '射抜けば家中の誉れになる。外せば笑われる', () {
        _stamp(g, 'yabu');
        if (g.rng.chance(_try(l.bu, .4))) {
          _fame(g, 4);
          l.fav += 3;
          g.setFlag('sn_yabu_hit');
          g.mark('秋の祭礼の流鏑馬で、駆ける馬の上から的を射抜いた');
          return '鏑矢が鳴り、板の的が二つに割れた。桟敷から、どっと声が上がった。';
        }
        _fame(g, -1);
        g.setFlag('sn_yabu_miss');
        return '二の的で手綱がぶれ、矢は的をかすめて土に刺さった。馬場の外で、子どもが真似をして笑っていた。';
      }),
      Choice.h('若い者に射手を譲り、馬の世話を引き受ける', '若い者に恩を売れる。自分の名は上がらない', () {
        _net(g, 3);
        return '若い射手は二つの的を射抜き、馬を下りるとまっすぐにあなたのもとへ礼を言いに来た。';
      }),
      if (l.bu >= 70)
        Choice.h('三つの的を、続けざまに射抜いてみせると宣言する', '成れば国中に名が響く。宣言して外せば恥は大きい', () {
          _stamp(g, 'yabu');
          if (g.rng.chance(_try(l.bu, .3))) {
            _fame(g, 7);
            l.fav += 5;
            g.setFlag('sn_yabu_hit');
            g.setFlag('sn_yabu_three');
            g.mark('秋の祭礼の流鏑馬で、三つの的を続けざまに射抜いた');
            return '一の的、二の的、三の的。鏑矢が三度鳴るあいだ、馬場は静まり返っていた。最後の的が割れると、主君が立ち上がった。';
          }
          _fame(g, -3);
          g.setFlag('sn_yabu_miss');
          return '三の的を外した。宣言の言葉を覚えている者たちの目が、背中に痛かった。';
        }),
    ], after: next);
  }),

  // ============================================ 筋の後段: 流鏑馬のその後
  _sn('sn_yabusame_after', 18, 60, 24, snWarrior, (g, next) {
    final l = g.l;
    if (g.hasFlag('sn_yabu_hit')) {
      g.ask('射手の指南', '流鏑馬で的を射抜いて以来、祭礼が近づくと、若い侍たちが馬の乗り方や弓の引き方を尋ねに来るようになった。今年は、家中の重臣の子が、正式に指南を頼みに来た。', [
        Choice.h('引き受けて、馬場で一から教える', '若い者に慕われる。暇はなくなる', () {
          _net(g, 4);
          l.fav += 3;
          g.setFlag('sn_yabu_master');
          g.mark('流鏑馬の射手を育てる指南を引き受けた');
          return '朝靄の馬場で、若者の手綱を何度も直した。その秋、若者は二つの的を射抜いて、真っ先にあなたの顔を探した。';
        }),
        Choice.h('自分もまだ修行の身だと断る', '慎み深いと見られる。重臣の覚えは得られない', () {
          return '若者は残念そうに頭を下げた。その年の射手は、別の者が育てた。';
        }),
      ], after: next);
      return;
    }
    g.ask('流鏑馬の雪辱', '的を外した流鏑馬から、季節が巡った。今年の祭礼でも、射手を出すことになった。あのときの笑い声が、まだ耳に残っている。', [
      Choice.h('もう一度、射手に名乗り出る', '射抜けば雪辱が果たせる。また外せば名は地に落ちる', () {
        if (g.rng.chance(_try(l.bu, .45))) {
          _fame(g, 5);
          l.fav += 3;
          g.setFlag('sn_yabu_redeemed');
          g.mark('一度外した流鏑馬で、次の祭礼に的を射抜いて雪辱を果たした');
          return '馬場の土を踏み固めて臨んだ。鏑矢が鳴り、的が割れた。今度は、誰も笑わなかった。';
        }
        _fame(g, -2);
        g.j(-3);
        return 'また、矢は土に刺さった。馬を下りると、膝が笑っていた。';
      }),
      Choice.h('射手は人に任せ、桟敷から見る', '恥はかかない。心残りは消えない', () {
        g.j(-1);
        return '若い射手が的を射抜くたび、拳を握っている自分に気づいた。';
      }),
    ], after: next);
  }),

  // ============================================ 年寄り: 重陽
  _sn('sn_choyo', 45, 90, 3.5, snLife, (g, next) {
    final sp = _spouse(g);
    final kid = _kidName(g);
    g.ask('重陽', '九月九日、菊の花びらを酒に浮かべて、長寿を祈る日だ。前の晩に菊にかぶせておいた綿で、今朝は顔をぬぐった。${sp != null ? '$spが、菊酒の盃を差し出してくる。' : kid != null ? '$kidが、庭の菊を手折って持ってきた。' : '庭の菊が、今年もよく咲いた。'}', [
      Choice.h('菊酒を飲み、残りの年を数えずに暮らそうと決める', '心が穏やかになる', () {
        g.j(5);
        _hp(g, 2);
        if (sp != null) _bond(g, '伴侶', 3);
        return '花びらの浮いた酒は、思ったより苦かった。それでも、二杯目を注いでもらった。';
      }),
      Choice.h('先に逝った者たちのために、盃を一つ多く並べる', '懐かしい名を思い出す。少し寂しい', () {
        g.j(2);
        g.setFlag('sn_choyo_absent');
        return '幼なじみ、師、戦で別れた者。名を一つずつ口にして、盃を伏せた。';
      }),
      Choice.h('若い者の家々に菊を届けて回る', '人とのつながりが深まる。足は疲れる', () {
        _net(g, 3);
        _hp(g, -2);
        g.setFlag('sn_choyo_gave');
        return '杖をついて近所を回ると、どの家でも「長生きしてくだされ」と言われた。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 冬（掛け取り・煤払い・年越し）

List<SceneDef> _winter() => [
  // ============================================ 暮らしの苦しい人: 大晦日の掛け取り
  _sn('sn_kaketori', 18, 75, 4, snPoor, (g, next) {
    final l = g.l;
    g.ask('大晦日の掛け取り', '大晦日の昼、町の店の手代が、帳面を抱えて戸口に立った。春から借りにしてきた塩や油の代を、今日のうちに払えという。手元の銭では、とても足りない。', [
      Choice.h('居留守を使って、戸を閉ざす', '今日はしのげる。年が明ければもっと厳しく取り立てられる', () {
        if (g.rng.chance(.5)) {
          g.j(-2);
          return '手代は戸を叩き続け、日が暮れると帰っていった。年明け、店の前を通れなくなった。';
        }
        _net(g, -2);
        _pay(g, 4);
        return '子どもが戸を開けてしまった。手代は土間に座り込み、払うまで帰らなかった。';
      }),
      Choice.h('晴れ着を質に入れて、払いを済ませる', '年を越す心は軽くなる。正月に着るものがない', () {
        g.j(-1);
        _net(g, 1);
        g.setFlag('sn_kake_paid');
        return '一枚きりの晴れ着を質屋に運んだ。手代は帳面に墨を引き、「よいお年を」と頭を下げた。';
      }),
      Choice.h('正直にわけを話し、春までの猶予を頼む', '人柄が通じれば待ってもらえる。断られれば恥をかく', () {
        if (g.rng.chance(_try(l.mi, .45))) {
          _net(g, 2);
          return '手代は帳面を閉じ、「主人に話しておく」と言った。春、店の主人のほうから、仕事の口を持ってきた。';
        }
        _net(g, -1);
        _pay(g, 3);
        return '手代は首を横に振った。有り金を残らず渡し、残りは年明けに持っていくと約束した。';
      }),
      if (l.sei >= 55)
        Choice.h('帳面を見せてもらい、一つずつ突き合わせる', '付け違いが見つかれば払いは減る。何も出なければ手代を怒らせる', () {
          if (g.rng.chance(_try(l.sei, .45))) {
            l.gold += 3;
            _fame(g, 1);
            g.setFlag('sn_kake_checked');
            return '同じ油が二度付けてあるのを見つけた。手代は青くなり、その分を帳面から消した。';
          }
          _net(g, -1);
          return '帳面に誤りはなかった。手代はわざとらしくため息をついて、残らず取り立てていった。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 煤払いで見つけた古い文
  _sn(
    'sn_susuharai',
    25,
    75,
    3.5,
    (g) => _who(g, '幼なじみ') != null && !g.hasFlag('priesthood'),
    (g, next) {
      final os = _who(g, '幼なじみ')!;
      g.ask('煤払い', '十二月十三日、年に一度の煤払いで、家じゅうの物をすべて外へ出した。古い葛籠の底から、子どものころ$osと交わした、つたない字の文が出てきた。「おとなになっても　いっしょに」とある。', [
        Choice.h('$osに、久しぶりの文を書いて送る', '縁がつながるかもしれない。返事が来るかは分からない', () {
          g.j(3);
          g.setFlag('sn_susu_sent');
          _stamp(g, 'susu');
          return '煤だらけの手を洗い、灯りの下で筆を取った。書き出しに迷って、三度書き直した。';
        }),
        Choice.h('古い文は、大事にしまい直す', '思い出は胸に残る。何も起きない', () {
          g.j(2);
          return '葛籠の底に、そっと戻した。';
        }),
        Choice.h('子どもの戯れと笑って、焚き火にくべる', '身軽になる。少しだけ惜しい', () {
          _bond(g, '幼なじみ', -2);
          return '紙は一瞬で燃え上がり、煙と一緒に空へのぼった。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 筋の後段: 正月の返事
  _sn('sn_susuharai_after', 26, 80, 24, snLife, (g, next) {
    final os = _who(g, '幼なじみ');
    if (os != null) {
      g.ask('正月の返事', '年が明けて、$osから返事が届いた。「あの文はわたしも持っている」とあり、春になったら会いに行きたいと書いてある。', [
        Choice.h('すぐに返事を書き、こちらから会いに行く', '絆は深まる。道中は銭と日がかかる', () {
          _pay(g, 4);
          _bond(g, '幼なじみ', 8);
          g.j(6);
          g.setFlag('sn_susu_reunited');
          g.mark('煤払いで見つけた子どもの日の文がきっかけで、$osと会った');
          return '峠を越えて訪ねると、$osは門口に立って待っていた。二人とも、文を懐に入れてきていた。';
        }),
        Choice.h('文のやり取りだけを続ける', '縁は細く長く続く', () {
          _bond(g, '幼なじみ', 4);
          g.j(3);
          return 'それから毎年、正月には$osから文が届くようになった。';
        }),
      ], after: next);
      return;
    }
    g.ask('戻ってきた文', '年が明けて、暮れに送った文が戻ってきた。届け先の家の者が、宛ての人はもういないと書き添えていた。', [
      Choice.h('戻ってきた文を、子どもの日の文と一緒にしまう', '悲しみは静かに収まる', () {
        g.j(-1);
        return '二通の文を重ねて、葛籠の底に入れた。';
      }),
      Choice.h('その家を訪ねて、手を合わせる', '心の区切りがつく。道中は遠い', () {
        _pay(g, 3);
        g.j(2);
        _net(g, 1);
        return '小さな墓の前に、子どもの日の文を供えて帰った。';
      }),
    ], after: next);
  }),

  // ============================================ 誰でも: 年越し（何度でも）
  _sn(
    'sn_toshikoshi',
    15,
    95,
    1.5,
    (g) => _toshiReady(g),
    (g, next) {
      final l = g.l;
      final n = _toshiCount(g) + 1;
      _toshiStamp(g, n);
      final sp = _spouse(g);
      final kid = _kidName(g);
      final head = n <= 1
          ? '大晦日の夜が更けていく。'
          : g.rng.pick([
              'また一年が過ぎた。大晦日の夜、囲炉裏の火を見つめている。',
              '今年も大晦日が来た。年ごとに、一年が短くなっていく気がする。',
              '除夜の鐘が、遠くの寺から聞こえはじめた。',
              '雪の大晦日だ。戸の外で、風が鳴っている。',
            ]);
      final who = sp != null
          ? '$spが、年越しの膳を整えている。'
          : kid != null
          ? '$kidが、眠い目をこすりながら起きている。'
          : snMonk(g)
          ? '寺では、年越しの勤めの支度が始まっている。'
          : '';
      g.ask('年越し', '$head$who', [
        Choice.h(sp != null || kid != null ? '家の者と膳を囲んで、年を越す' : '火のそばで、静かに年を越す', '心が満ちる。何も起きない', () {
          g.j(5);
          if (sp != null) _bond(g, '伴侶', 2);
          return sp != null
              ? '$spと、今年あったことを一つずつ話した。話し終わらないうちに、年が明けた。'
              : '火が小さくなるまで、今年のことを思い返していた。';
        }),
        Choice.h('夜通し働き、年明けの支度を片づける', '暮らしが少し楽になる。体は休まらない', () {
          l.gold += 3;
          _hp(g, -2);
          return '縄をない、草鞋を編み、気がつくと東の空が白んでいた。';
        }),
        Choice.h('寺へ行って、除夜の鐘を聞く', '心が洗われる。夜道は寒い', () {
          g.j(4);
          _net(g, 1);
          if (n >= 3) g.setFlag('sn_joya_regular');
          return '境内には、近在の者たちが集まっていた。鐘の音が一つ鳴るたびに、白い息が夜空に消えた。';
        }),
      ], after: next);
    },
    repeat: true,
  ),
];

/// 年越しを迎えた回数（旗 `sn_toshi_n:<回>`）。
int _toshiCount(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('sn_toshi_n:')) return int.parse(f.substring(11));
  }
  return 0;
}

void _toshiStamp(Game g, int n) {
  g.l.flags.removeWhere((f) => f.startsWith('sn_toshi_n:') || f.startsWith('sn_toshi_at:'));
  g.setFlag('sn_toshi_n:$n');
  g.setFlag('sn_toshi_at:${g.year}');
}

/// 年越しは三年あけて出す。
bool _toshiReady(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('sn_toshi_at:')) return g.year - int.parse(f.substring(12)) >= 3;
  }
  return true;
}

// ======================================================================
// 子どもの岐路
// ======================================================================

const _poorKids = ['farmer', 'fisher', 'beggar'];
const _bushiKids = ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'daimyo'];

List<SceneDef> buildSeasonChildScenes() => [
  // ============================================ 正月の凧揚げ
  _sn('sn_c_kite', 6, 13, 3, snLife, (g, next) {
    final l = g.l;
    final os = _who(g, '幼なじみ');
    g.ask('凧揚げ', '正月、空っ風の吹く野原で、子どもたちが凧（いかのぼり）を揚げている。${os == null ? 'あなたの凧は、家の者が竹を削って作ってくれたものだ。' : '$osと二人で、竹と紙で作った凧を持ってきた。'}', [
      Choice.h('誰より高く揚げようと、糸を繰り出す', '空の高みは気持ちがいい。糸が切れることもある', () {
        if (g.rng.chance(.6)) {
          g.j(6);
          l.un = _c(l.un + 2);
          return '凧は豆粒のように小さくなり、ほかの子らが口を開けて見上げた。';
        }
        g.j(-2);
        return 'ぷつりと糸が切れ、凧は山のほうへ流れていった。';
      }),
      Choice.h(os == null ? '小さい子に糸を持たせてやる' : '$osに糸を持たせてやる', '喜ばれる。自分の番は短い', () {
        _net(g, 2);
        g.j(3);
        if (os != null) _bond(g, '幼なじみ', 5);
        g.setFlag('sn_c_kite_shared');
        return os == null
            ? '小さな子は両手で糸を握りしめ、空を見上げたまま動かなかった。'
            : '$osは糸を引くたびに歓声を上げた。帰り道、凧は二人で交代に抱えて帰った。';
      }),
      Choice.h('ほかの子の凧と、糸を絡めて切り合う', '勝てば得意になる。負ければ泣く', () {
        l.bu = _c(l.bu + 1);
        if (g.rng.chance(_try(l.bu, .4))) {
          g.j(5);
          return '相手の糸がぷつりと切れ、野原じゅうの子が歓声を上げた。';
        }
        g.j(-3);
        return '自分の凧が落ちていった。悔しくて、晩飯がのどを通らなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 書き初め
  _sn(
    'sn_c_kakizome',
    7,
    14,
    3,
    (g) =>
        (g.l.focus['learn'] ?? 0) + (g.l.focus['tera'] ?? 0) + (g.l.focus['uta'] ?? 0) > 0 ||
        const ['priest', 'samurai', 'kokujin', 'daimyo', 'merchant'].contains(g.l.cls.id),
    (g, next) {
      final l = g.l;
      g.ask('書き初め', '正月二日、新しい筆をおろして、年の初めの字を書く。書いた紙は、小正月の火で焚き上げる。高く舞い上がれば、字が上手くなるという。', [
        Choice.h('紙いっぱいに、大きく一字を書く', '気持ちがいい。字は荒れる', () {
          g.j(4);
          l.bu = _c(l.bu + 1);
          return '「春」と一字、紙からはみ出すほどに書いた。墨が飛んで、着物まで黒くなった。';
        }),
        Choice.h('手本どおりに、丁寧に書く', '字が整う。少し退屈だ', () {
          l.chi = _c(l.chi + 2);
          return '一画ずつ息を止めて書いた。焚き上げの火で、紙は高く舞った。';
        }),
        if (l.chi >= 45)
          Choice.h('覚えたばかりの古い歌を、一首書いてみる', '大人を驚かせられる。間違えれば笑われる', () {
            if (g.rng.chance(_try(l.chi, .5))) {
              l.chi = _c(l.chi + 3);
              _fame(g, 1);
              g.setFlag('sn_c_kakizome_praised');
              return '仮名をつなげて、一首を書き上げた。見ていた大人が、その紙を焚き上げずに取っておけと言った。';
            }
            g.j(-1);
            return '途中で一字抜けているのに気づいた。兄に指さして笑われた。';
          }),
      ], after: next);
    },
  ),

  // ============================================ 女の子: ひいな遊び
  _sn('sn_c_hina', 5, 11, 3, (g) => g.l.female, (g, next) {
    final l = g.l;
    g.ask('ひいな遊び', '三月三日、母が紙と布切れで小さな人形（ひいな）を作ってくれた。夕方には、ひとがたと一緒に川へ流して、子の穢れを祓うのだという。', [
      Choice.h('言われたとおり、川へ流す', '母は安心する。少し惜しい', () {
        g.j(2);
        l.un = _c(l.un + 2);
        return '流れていくひいなに、小さく手を振った。';
      }),
      Choice.h('こっそり一つだけ、袂に隠して持ち帰る', '宝物ができる。見つかれば叱られる', () {
        g.j(5);
        g.setFlag('sn_c_hina_kept');
        return '袂の中で、ひいなの着物の手ざわりを確かめながら眠った。';
      }),
      Choice.h('人形を持たない近所の子に、一つ分けてやる', '友ができる。自分の分は減る', () {
        _net(g, 2);
        l.mi = _c(l.mi + 2);
        return '近所の子は、ひいなを胸に抱いて、川辺まで走っていった。';
      }),
    ], after: next);
  }),

  // ============================================ 男の子: 端午の菖蒲
  _sn('sn_c_shobu', 5, 12, 3, (g) => !g.l.female, (g, next) {
    final l = g.l;
    final bushi = _bushiKids.contains(l.cls.id);
    g.ask('端午', bushi
        ? '五月五日、屋敷の軒に菖蒲が挿され、父が菖蒲の葉で編んだ小さな兜をかぶせてくれた。庭では、兄たちが木刀を手に打ち合っている。'
        : '五月五日、軒に菖蒲を挿し、子どもたちは菖蒲の葉を束ねて地面を打ち、音の大きさを競う。川原では、大きな子らが石を投げ合う真似をしている。', [
      Choice.h(bushi ? '兜をかぶったまま、兄たちに木刀で挑む' : '菖蒲の束で、誰より大きな音を出す', '強くなる。痛い目も見る', () {
        l.bu = _c(l.bu + 2);
        _hp(g, -2);
        return bushi ? '一太刀も入らなかったが、兄は「筋がいい」と言った。' : 'ぱんと乾いた音が響き、ほかの子らが目を丸くした。';
      }),
      Choice.h('菖蒲の湯に入って、早く寝る', '体が丈夫になるという', () {
        _hp(g, 4);
        return '湯に浮かんだ菖蒲の葉を、鉢巻きにして遊んだ。';
      }),
      Choice.h(bushi ? '庭の隅で、菖蒲の葉で刀を作る' : '石投げの真似の輪に入る', '面白い。叱られるかもしれない', () {
        g.j(4);
        if (!bushi && g.rng.chance(.3)) {
          _hp(g, -3);
          return '小石が額に当たって、たんこぶができた。それでも、夕方まで輪から抜けなかった。';
        }
        return bushi ? '菖蒲の刀を腰に差して、日が暮れるまで庭を走り回った。' : '石を投げる真似をして、日が暮れるまで川原を走り回った。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 七夕の願い
  _sn('sn_c_tanabata', 6, 14, 3, snLife, (g, next) {
    g.ask('七夕の願い', '七月七日、大人に習って、梶の葉に願いを書くことになった。字がまだ上手く書けないので、家の者が手を添えてくれる。', [
      Choice.h('「えらくなる」と書く', '大きな夢だ。叶うかは分からない', () {
        g.setFlag('sn_c_wish_rise');
        _stamp(g, 'wish');
        g.j(3);
        return '葉からはみ出しそうな大きな字で書いた。家の者が笑って、いちばん高い枝に結んでくれた。';
      }),
      Choice.h('「みんな　ぶじで」と書く', 'やさしい願いだ。家の者が目を細める', () {
        g.setFlag('sn_c_wish_family');
        _stamp(g, 'wish');
        g.j(3);
        _net(g, 1);
        return '書いた葉を見せると、母は黙って頭をなでてくれた。';
      }),
      Choice.h('「じがうまくなるように」と書く', '字が上達するかもしれない。地味な願いだ', () {
        g.setFlag('sn_c_wish_hand');
        _stamp(g, 'wish');
        g.l.chi = _c(g.l.chi + 1);
        return '書いた字は、願いとは裏腹に曲がっていた。';
      }),
    ], after: next);
  }),

  // ============================================ 子どもの盆踊り
  _sn('sn_c_bonodori', 6, 14, 3, snLife, (g, next) {
    final l = g.l;
    g.ask('盆の夜', '盆の夜、寺の境内の盆踊りに、子どもたちも加わった。太鼓の音に人が集まり、境内は昼のように明るい。輪の外れで、小さな子が一人で泣いている。', [
      Choice.h('泣いている子の手を引いて、親を探す', '人に喜ばれる。踊りは見逃す', () {
        _net(g, 3);
        l.mi = _c(l.mi + 2);
        g.setFlag('sn_c_lost_helped');
        return '境内を三度回って、ようやく母親を見つけた。母親は何度も頭を下げ、あなたの手に飴を握らせた。';
      }),
      Choice.h('大人に混じって、輪の中で踊る', '楽しい。踊りが上手くなる', () {
        g.j(6);
        l.mi = _c(l.mi + 1);
        return '大人の手振りを真似ているうちに、いつのまにか輪の真ん中にいた。';
      }),
      Choice.h('太鼓の撥を貸してもらう', '太鼓叩きに目をかけられる。腕がだるくなる', () {
        l.bu = _c(l.bu + 1);
        g.j(4);
        return '撥を握ると、太鼓叩きの男が後ろから手を添えてくれた。どん、と腹に響いた。';
      }),
    ], after: next);
  }),

  // ============================================ 村の子: 亥の子
  _sn('sn_c_inoko', 6, 12, 3, (g) => _poorKids.contains(g.l.cls.id), (g, next) {
    final l = g.l;
    g.ask('亥の子', '十月の亥の日、村の子どもたちは、縄をつけた石で家々の庭を突いて回り、亥の子餅をもらう。突きながら歌うのが習わしだ。いちばん大きな家の主が、今年は餅を出さないと言って戸を閉めた。', [
      Choice.h('みんなで、その家の前でいっそう大きく歌う', '子どもらは喜ぶ。大人に叱られる', () {
        g.j(4);
        if (g.rng.chance(.5)) return '戸が開いて、主が渋い顔で餅を投げてよこした。子どもたちは歓声を上げた。';
        _net(g, -1);
        return '家の者が出てきて怒鳴った。みんなで蜘蛛の子を散らすように逃げた。';
      }),
      Choice.h('もらった餅を、小さい子に分けてやる', '小さい子に慕われる。自分の分は減る', () {
        _net(g, 3);
        l.mi = _c(l.mi + 1);
        g.setFlag('sn_c_inoko_shared');
        return '餅を割って分けると、いちばん小さな子が、あなたの袖をつかんで離さなくなった。';
      }),
      Choice.h('閉めた家のことは放っておき、次の家へ行く', '揉めない。何も変わらない', () {
        g.j(2);
        return '次の家では、餅が二つずつ配られた。';
      }),
    ], after: next);
  }),

  // ============================================ 年の暮れの餅つき
  _sn('sn_c_mochi', 5, 12, 3, snLife, (g, next) {
    final l = g.l;
    final poor = _poorKids.contains(l.cls.id) && l.gold < 10;
    g.ask('年の暮れ', poor
        ? '年の暮れ、隣の家から餅をつく音が聞こえてくる。今年は不作で、家では餅米が手に入らなかった。母が、湯に溶いた粟を椀に分けている。'
        : '年の暮れ、庭に臼と杵が出され、家じゅうで正月の餅をつく。湯気の中で、大人たちが掛け声を合わせている。', [
      Choice.h(poor ? '母の手伝いをして、何も言わずに粟をすする' : '杵を持たせてもらい、一緒につく', '家の者が目を細める', () {
        g.j(3);
        l.bu = _c(l.bu + 1);
        return poor ? '粟は薄かったが、母と並んで食べると温かかった。' : '杵は重く、三度ついたところで腕が上がらなくなった。大人たちが笑った。';
      }),
      Choice.h(poor ? '隣の家の手伝いに行く' : 'つきたての餅を、こっそりつまみ食いする', poor ? '少し分けてもらえるかもしれない。母は恥ずかしがる' : 'うまい。見つかれば叱られる', () {
        if (poor) {
          _net(g, 2);
          if (g.rng.chance(.7)) {
            g.j(4);
            return '臼の周りを片づけていると、隣の婆さまが餅を三つ、紙に包んで持たせてくれた。';
          }
          return '手伝いは喜ばれたが、餅は余らなかった。';
        }
        g.j(4);
        return '熱い餅を口に入れて、目を白黒させた。母には見つかっていたらしく、背中をたたかれた。';
      }),
      Choice.h('鏡餅の形を整える役を引き受ける', poor ? '粟で小さな鏡餅を作る。家の者が喜ぶ' : '手先が器用になる。形が崩れれば作り直し', () {
        l.sei = _c(l.sei + 2);
        return poor ? '粟を固めて、小さな鏡餅を作り、神棚に供えた。' : '何度も丸め直して、ようやく二段に重なった。';
      }),
    ], after: next);
  }),
];
