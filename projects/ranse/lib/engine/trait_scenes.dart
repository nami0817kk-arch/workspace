import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'peace.dart';
import 'rng.dart';

part 'trait_scenes2.dart';
part 'trait_scenes3.dart';

/// 特性の効く場面（2026-11-24、特性100の1回目）。id・旗は `tr_`（子どもは `tr_c_`）。
///
/// ユーザー「ゲームに効くのを増やしたい。影響が強いほどレア」。特性を100にし（`data.dart` の `kTraits`）、
/// 1回目はそのうち25の特性に、段に合った効き方を作った（[kTraitScenesDone]）。
///
/// - **よくある**: 一生に一度の小さな出来事を一つ（力比べ・大食いの賭け・酒の席 など）。
/// - **珍しい**: 既存の仕組みに小さく掛ける（合戦の危うさと手柄＝[traitBattleRisk]・[traitBattleGain]・合戦で説く手＝[traitPersuade]
///   （`battles.dart`）／読み書きの伸び（`childhood.dart`）／熱病と家族の病の手（`childhood.dart`・`family.dart`）／
///   仕入れの旅の儲け（`ways.dart`））＋場面を一つ。
/// - **稀**: 新しい道や出会いが開く筋（二〜三の段）。
/// - **幻**: 一生の筋が変わる場面を四つ（落胤＝実の父の家からの使い→名乗り→異母兄、正夢＝夢見の一生）。
///
/// 筋の後段は、前の段の旗（[kTraitPrev]）があり、前の段から年が空いたとき（[kTraitGap]。段を踏んだ年は旗 `tr_at:<筋>:<年>`）だけ出る。
/// 死ぬ結果は数%で、匂わせに危うさを書いてある。位を大きく動かすのは落胤の名乗りと異母兄の場面だけ。

// ---------------------------------------------------------------- 表

/// 効き方を作った特性 → その特性の場面の id（手や倍率だけの所は `kTraitHooks`）。テストが使う。
/// 1回目の25（この下）と、2回目の25（`trait_scenes2.dart`）・3回目の25（`trait_scenes3.dart`）。表はここ一つ。
const kTraitScenesDone = <String, List<String>>{
  // よくある
  'power': ['tr_power'],
  'beauty': ['tr_beauty'],
  'glutton': ['tr_glutton'],
  'drinker': ['tr_drinker'],
  'loud': ['tr_loud'],
  'coward': ['tr_coward'],
  'hothead': ['tr_hothead'],
  'pious': ['tr_pious'],
  'frugal': ['tr_frugal'],
  // 珍しい
  'swift': ['tr_swift'],
  'nighteye': ['tr_nighteye'],
  'prodigy': ['tr_c_prodigy'],
  'tongue': ['tr_tongue'],
  'rider': ['tr_rider'],
  'gunner': ['tr_gunner'],
  'herbal': ['tr_herbal'],
  'appraiser': ['tr_appraiser'],
  // 稀
  'lucky': ['tr_lucky_eki', 'tr_lucky_arrow', 'tr_lucky_find'],
  'faces': ['tr_faces_spy', 'tr_faces_lord'],
  'twin': ['tr_twin_rumor', 'tr_twin_meet', 'tr_twin_swap'],
  'nanban': ['tr_nanban_padre', 'tr_nanban_tsuji', 'tr_nanban_ship'],
  'sixth': ['tr_sixth_night', 'tr_sixth_parting'],
  'painter': ['tr_c_painter', 'tr_painter_studio', 'tr_painter_castle'],
  // 幻
  'rakuin': [
    'tr_rakuin_charm',
    'tr_rakuin_envoy',
    'tr_rakuin_name',
    'tr_rakuin_brother',
  ],
  'yume': ['tr_yume_fire', 'tr_yume_morning', 'tr_yume_tell', 'tr_yume_last'],
  // ---------------- 2回目（trait_scenes2.dart）
  // よくある
  'nimble': ['tr_nimble'],
  'light_sleeper': ['tr_light_sleeper'],
  'swimmer': ['tr_swimmer'],
  'kind': ['tr_kind'],
  'honest': ['tr_honest'],
  'gambler': ['tr_gambler'],
  'singer': ['tr_singer'],
  'cook': ['tr_cook'],
  'weather': ['tr_weather'],
  'handwriting': ['tr_handwriting'],
  // 珍しい
  'iron_gut': ['tr_iron_gut'],
  'painless': ['tr_painless'],
  'longlived': ['tr_longlived'],
  'brave': ['tr_brave'],
  'builder': ['tr_builder'],
  'tactics': ['tr_tactics'],
  'archer': ['tr_archer'],
  'sakai_kin': ['tr_sakai_kin'],
  // 稀
  'surgeon': ['tr_surgeon_wound', 'tr_surgeon_call'],
  'general': ['tr_general_men', 'tr_general_follow', 'tr_general_lord'],
  'go': ['tr_go_board', 'tr_go_lord', 'tr_go_house'],
  'deathless': ['tr_deathless_fall', 'tr_deathless_talk'],
  'dowser': ['tr_dowser_well', 'tr_dowser_call'],
  // 幻
  'kensei': [
    'tr_kensei_first',
    'tr_kensei_license',
    'tr_kensei_duel',
    'tr_kensei_school',
  ],
  'ryujin': [
    'tr_c_ryujin',
    'tr_ryujin_boat',
    'tr_ryujin_rain',
    'tr_ryujin_storm',
    'tr_ryujin_shrine',
  ],
  // ---------------- 3回目（trait_scenes3.dart）
  // よくある
  'walker': ['tr_walker'],
  'big': ['tr_big'],
  'small': ['tr_small'],
  'stubborn': ['tr_stubborn'],
  'cheerful': ['tr_cheerful'],
  'worrier': ['tr_worrier'],
  'curious': ['tr_curious'],
  'filial': ['tr_filial'],
  'patient': ['tr_patient'],
  'animals': ['tr_animals'],
  // 珍しい
  'keen_ear': ['tr_keen_ear'],
  'sea_legs': ['tr_sea_legs'],
  'calm': ['tr_calm'],
  'generous': ['tr_generous'],
  'poet': ['tr_poet'],
  'tea': ['tr_tea'],
  'temple_kin': ['tr_temple_kin'],
  'fallen': ['tr_fallen'],
  // 稀
  'stars': ['tr_stars_omen', 'tr_stars_day', 'tr_stars_book'],
  'smith': ['tr_smith_forge', 'tr_smith_blade'],
  'flute': ['tr_flute_night', 'tr_flute_call'],
  'mosugo': ['tr_mosugo_vow', 'tr_mosugo_pray'],
  'kamikakushi': ['tr_kami_mountain', 'tr_kami_hermit', 'tr_kami_child'],
  // 幻
  'imiko': [
    'tr_c_imiko',
    'tr_imiko_blame',
    'tr_imiko_parent',
    'tr_imiko_turn',
    'tr_imiko_star',
  ],
  'kitsune': [
    'tr_c_kitsune',
    'tr_kitsune_guess',
    'tr_kitsune_shrine',
    'tr_kitsune_hunt',
    'tr_kitsune_fox',
  ],
};

/// 特性の効き方のうち、場面のほかに既存の仕組みへ掛けたもの（覚え書き。テストと CLAUDE.md 用）。
const kTraitHooks = <String, String>{
  'swift': '合戦の討死の危うさが下がる（battles.dart）',
  'nighteye': '合戦の討死の危うさが少し下がる（battles.dart）',
  'rider': '先陣・本陣で討死の危うさが下がり、手柄が増える（battles.dart）',
  'gunner': '鉄砲を覚えていれば合戦の手柄が増える（battles.dart）',
  'tongue': '合戦の場で人を説く手が通りやすい（battles.dart）',
  'prodigy': '読み書き・寺の手習いの伸びが大きい（childhood.dart）',
  'herbal': '熱病・子の病・連れ合いの病に薬草を煎じる手（childhood.dart・family.dart）',
  'appraiser': '仕入れの旅で儲けやすい（ways.dart）',
  // 2回目
  'iron_gut': '凶作の冬に飢えにくい（adult.dart）',
  'painless': '合戦の討死の危うさが少し下がる（battles.dart）',
  'longlived': '五十からの老いの坂がゆるい（game.dart）',
  'brave': '先陣での手柄が増える（battles.dart）',
  'builder': '泰平の世の手伝い普請に、自ら石組みを指図する手（peace.dart）',
  'tactics': '合戦の討死の危うさが少し下がり、手柄が少し増える（battles.dart）',
  'archer': '先陣でない持ち場での手柄が増える（battles.dart）',
  'sakai_kin': '仕入れの旅（隣国・船）で当たりやすい（ways.dart）',
  'general': '組頭より上なら合戦の手柄が増える（battles.dart）',
  'deathless': '合戦の討死の危うさが下がる（battles.dart）',
  'kensei': '合戦の討死の危うさが下がり、手柄が増える（battles.dart）',
  // 3回目
  'worrier': '凶作の冬に飢えにくい（adult.dart）',
  'patient': '籠城で飢えにくい（ways.dart）',
  'keen_ear': '刺客に討たれにくい（ways.dart）',
  'sea_legs': '仕入れの船が嵐に呑まれにくい（ways.dart）',
  'calm': '大水・大地震で命を落としにくい（ways.dart）',
  'generous': '給金が払えない年にも兵が逃げない（game.dart）',
  'poet': '連歌の会で名が上がりやすい（pastimes.dart）',
  'tea': '茶の湯の稽古で人の輪が広がりやすい（pastimes.dart）',
  'temple_kin': '主君に腹を切れと命じられたとき、叔父の寺へ駆け込む手（ways.dart）',
  'fallen': '仕官の口が通りやすい（adult.dart）',
};

/// 子どもの岐路の id。
const kTraitChildSceneIds = [
  'tr_c_prodigy',
  'tr_c_painter',
  'tr_c_ryujin',
  'tr_c_imiko',
  'tr_c_kitsune',
];

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kTraitPrev = <String, List<String>>{
  'tr_lucky_arrow': ['tr_lucky_told'],
  'tr_lucky_find': ['tr_lucky_spared'],
  'tr_faces_lord': ['tr_faces_seen'],
  'tr_twin_meet': ['tr_twin_heard'],
  'tr_twin_swap': ['tr_twin_met'],
  'tr_nanban_tsuji': ['tr_nanban_lang'],
  'tr_nanban_ship': ['tr_nanban_tsuji_done'],
  'tr_sixth_parting': ['tr_sixth_heeded', 'tr_sixth_ignored'],
  'tr_painter_castle': ['tr_painter_pupil', 'tr_painter_side'],
  'tr_rakuin_envoy': ['tr_rakuin_knows'],
  'tr_rakuin_name': ['tr_rakuin_met'],
  'tr_rakuin_brother': ['tr_rakuin_named'],
  'tr_yume_morning': ['tr_yume_dreamt'],
  'tr_yume_tell': ['tr_yume_known', 'tr_yume_hidden'],
  'tr_yume_last': ['tr_yume_told', 'tr_yume_silent', 'tr_yume_fled'],
  // 2回目
  'tr_surgeon_call': ['tr_surgeon_seen'],
  'tr_general_follow': ['tr_general_seen'],
  'tr_general_lord': ['tr_general_band', 'tr_general_sent'],
  'tr_go_lord': ['tr_go_known'],
  'tr_go_house': ['tr_go_played'],
  'tr_deathless_talk': ['tr_deathless_back'],
  'tr_dowser_call': ['tr_dowser_tried'],
  'tr_kensei_license': ['tr_kensei_woke'],
  'tr_kensei_duel': ['tr_kensei_master'],
  'tr_kensei_school': ['tr_kensei_dueled'],
  'tr_ryujin_rain': ['tr_ryujin_seen'],
  'tr_ryujin_storm': ['tr_ryujin_asked'],
  'tr_ryujin_shrine': ['tr_ryujin_storm_done'],
  // 3回目
  'tr_stars_day': ['tr_stars_seen'],
  'tr_stars_book': ['tr_stars_served'],
  'tr_smith_blade': ['tr_smith_struck'],
  'tr_flute_call': ['tr_flute_heard'],
  'tr_mosugo_pray': ['tr_mosugo_settled'],
  'tr_kami_hermit': ['tr_kami_walked'],
  'tr_kami_child': ['tr_kami_met'],
  'tr_imiko_parent': ['tr_imiko_faced'],
  'tr_imiko_turn': ['tr_imiko_heard'],
  'tr_imiko_star': ['tr_imiko_turned'],
  'tr_kitsune_shrine': ['tr_kitsune_known'],
  'tr_kitsune_hunt': ['tr_kitsune_visited'],
  'tr_kitsune_fox': ['tr_kitsune_judged'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kTraitGap = <String, (String, int)>{
  'tr_lucky_arrow': ('lucky', 2),
  'tr_lucky_find': ('lucky', 2),
  'tr_faces_lord': ('faces', 2),
  'tr_twin_meet': ('twin', 1),
  'tr_twin_swap': ('twin', 2),
  'tr_nanban_tsuji': ('nanban', 2),
  'tr_nanban_ship': ('nanban', 3),
  'tr_sixth_parting': ('sixth', 2),
  'tr_painter_castle': ('painter', 3),
  'tr_rakuin_envoy': ('rakuin', 1),
  'tr_rakuin_name': ('rakuin', 1),
  'tr_rakuin_brother': ('rakuin', 2),
  'tr_yume_morning': ('yume', 1),
  'tr_yume_tell': ('yume', 2),
  'tr_yume_last': ('yume', 3),
  // 2回目
  'tr_surgeon_call': ('surgeon', 2),
  'tr_general_follow': ('general', 2),
  'tr_general_lord': ('general', 3),
  'tr_go_lord': ('go', 2),
  'tr_go_house': ('go', 3),
  'tr_deathless_talk': ('deathless', 2),
  'tr_dowser_call': ('dowser', 2),
  'tr_kensei_license': ('kensei', 2),
  'tr_kensei_duel': ('kensei', 2),
  'tr_kensei_school': ('kensei', 3),
  'tr_ryujin_rain': ('ryujin', 2),
  'tr_ryujin_storm': ('ryujin', 2),
  'tr_ryujin_shrine': ('ryujin', 3),
  // 3回目
  'tr_stars_day': ('stars', 2),
  'tr_stars_book': ('stars', 3),
  'tr_smith_blade': ('smith', 2),
  'tr_flute_call': ('flute', 2),
  'tr_mosugo_pray': ('mosugo', 2),
  'tr_kami_hermit': ('kami', 1),
  'tr_kami_child': ('kami', 2),
  'tr_imiko_parent': ('imiko', 2),
  'tr_imiko_turn': ('imiko', 2),
  'tr_imiko_star': ('imiko', 3),
  'tr_kitsune_shrine': ('kitsune', 2),
  'tr_kitsune_hunt': ('kitsune', 2),
  'tr_kitsune_fox': ('kitsune', 3),
};

// ---------------------------------------------------------------- 既存の仕組みに掛ける倍率

/// 合戦の討死の危うさの倍率（`battles.dart` の `_fight` が掛ける）。[role] は持ち場。
double traitBattleRisk(Game g, String role) {
  var m = 1.0;
  if (g.has('swift')) m *= .85;
  if (g.has('nighteye')) m *= .92;
  if (g.has('rider') && (role == 'van' || role == 'main')) m *= .85;
  return m * _battleRisk2(g, role);
}

/// 合戦の手柄の倍率（`battles.dart` の `_fight` が掛ける）。
double traitBattleGain(Game g, String role) {
  var m = 1.0;
  if (g.has('rider') && (role == 'van' || role == 'main')) m *= 1.1;
  if (g.has('gunner') && g.l.gun) m *= 1.15;
  return m * _battleGain2(g, role);
}

/// 合戦の場で人を説く見立てに足す値（弁舌巧み）。`battles.dart` の魅の見立てが使う。
int traitPersuade(Game g) => g.has('tongue') ? 12 : 0;

// ---------------------------------------------------------------- 筋の補助

void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('tr_at:$chain:'));
  g.setFlag('tr_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int trSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('tr_at:$chain:')) {
      return g.year - int.parse(f.substring('tr_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool trChainReady(Game g, String id) {
  final prev = kTraitPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kTraitGap[id];
  if (gap == null) return true;
  return trSince(g, gap.$1) >= gap.$2;
}

/// この場面の筋の名（筋でなければ null）。
String? _chainOf(String id) {
  final gap = kTraitGap[id];
  if (gap != null) return gap.$1;
  for (final e in _firstOf.entries) {
    if (e.value == id) return e.key;
  }
  return null;
}

/// 筋の最初の段。
const _firstOf = <String, String>{
  'lucky': 'tr_lucky_eki',
  'faces': 'tr_faces_spy',
  'twin': 'tr_twin_rumor',
  'nanban': 'tr_nanban_padre',
  'sixth': 'tr_sixth_night',
  'painter': 'tr_painter_studio',
  'rakuin': 'tr_rakuin_charm',
  'yume': 'tr_yume_fire',
  // 2回目
  'surgeon': 'tr_surgeon_wound',
  'general': 'tr_general_men',
  'go': 'tr_go_board',
  'deathless': 'tr_deathless_fall',
  'dowser': 'tr_dowser_well',
  'kensei': 'tr_kensei_first',
  'ryujin': 'tr_ryujin_boat',
  // 3回目
  'stars': 'tr_stars_omen',
  'smith': 'tr_smith_forge',
  'flute': 'tr_flute_night',
  'mosugo': 'tr_mosugo_vow',
  'kami': 'tr_kami_mountain',
  'imiko': 'tr_imiko_blame',
  'kitsune': 'tr_kitsune_guess',
};

/// 特性 [trait] を持つ人にだけ出る場面。筋の段を踏んだ年を残す。
SceneDef _tr(
  String id,
  String trait,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) cond,
  void Function(Game g, void Function() next) run,
) => SceneDef(
  id,
  minAge,
  maxAge,
  (g) => w,
  (g) => g.l.dead == null && g.has(trait) && trChainReady(g, id) && cond(g),
  (g, next) {
    final c = _chainOf(id);
    if (c != null) _stamp(g, c);
    run(g, next);
  },
);

// ---------------------------------------------------------------- 補助

void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _hp(Game g, int n) => g.l.hp = clampInt(g.l.hp + n, 1, g.l.maxhp);
void _fav(Game g, int n) => g.l.fav = clampInt(g.l.fav + n, 0, 100);
int _c(int v) => clampInt(v, 0, 99);
double _try(int v, [double base = .45]) => clampD(base + v / 300, base, .85);

bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);

/// 主家に仕える身（位1〜7・隠居でない・仏門でない・主家が生きている）。
bool _serving(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    _lordAlive(g);

/// 戦に出る身（主家に仕え、戦える）。
bool _fighter(Game g) => _serving(g) && g.canFight;

/// 寺にいない・隠居していない。
bool _lay(Game g) => g.active && !g.hasFlag('priesthood');

String _hn(Game g) => g.l.lord == null ? '主家' : '${houseName(g, g.l.lord)}家';

String _newName(Game g, {bool? female}) =>
    '${g.rng.pick(kSurnames)} ${g.rng.pick((female ?? g.rng.chance(.5)) ? kGivenF : kGivenM)}';

/// 旗 `<head><値>` の値（なければ null）。
String? _val(Game g, String head) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return null;
}

/// 自分の国から近い、主家でない生きている家（なければ null）。
String? _nearOther(Game g) {
  final others = g.alive.where((f) => f.name != g.l.lord).toList();
  if (others.isEmpty) return null;
  final near = nearest(others, (f) => f.name, region: g.l.region, n: 3);
  return g.rng.pick(near).name;
}

/// [lord] に仕える（身分のない人が足軽・下女から始める）。
void _join(Game g, String lord, [int rank = 1]) {
  final l = g.l;
  l.lord = lord;
  if (l.rank < rank) l.rank = rank;
  if (l.rank > l.maxRank) l.maxRank = l.rank;
  l.fav = l.fav < 30 ? 30 : l.fav;
  l.ronin = false;
}

// ======================================================================
// 子どもの岐路（`childhood_more.dart` の `buildMoreChildScenes` が足す）
// ======================================================================

List<SceneDef> buildTraitChildScenes() => [
  // ============================================ 珍しい: 神童
  _tr('tr_c_prodigy', 'prodigy', 7, 14, 9, (g) => true, (g, next) {
    final l = g.l;
    g.ask(
      '学僧の問い',
      '旅の学僧が一夜の宿を借りに来た。夕餉の席で、大人たちが答えに詰まった問いを、あなたが横から答えてしまった。学僧は箸を置いて、あなたの顔をじっと見た。',
      [
        Choice.h('問われるままに、知っていることを話す', '学僧の目に留まる。出過ぎた子と思う大人もいる', () {
          l.chi = _c(l.chi + 3);
          g.setFlag('tr_c_prodigy_praised');
          if (!l.people.containsKey('師')) {
            g.meet('師', '旅の学僧 ${g.rng.pick(['宗円', '玄仲', '了雲', '道寛'])}', 40);
            g.mark('宿を借りた旅の学僧に問答で見込まれ、書を送られるようになった');
            return '学僧は夜更けまであなたと話し込み、翌朝、読み終えたら返せと言って書物を一冊置いていった。それから時おり、遠い寺から書が届くようになった。';
          }
          return '学僧は「この子は伸びる」と親に言い残して発った。親は少し誇らしげだった。';
        }),
        Choice.h('黙って下を向き、大人に答えを譲る', '何も起きない。学僧は少し残念そうだった', () {
          l.chi = _c(l.chi + 1);
          return '学僧はあなたのほうを一度見たきりで、翌朝早くに発っていった。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 稀: 絵の才（筋の始まりは大人の「絵師の工房」。これは子どもの日の前触れ）
  _tr('tr_c_painter', 'painter', 6, 14, 9, (g) => true, (g, next) {
    final l = g.l;
    final where = l.cls.rank >= 2
        ? '館の奥の白い襖'
        : (l.cls.id == 'priest' ? '寺の本堂の板戸' : '村のお堂の白壁');
    g.ask(
      '襖の落書き',
      '炭のかけらを拾って、$whereに鷹の絵を描いてしまった。羽の一枚一枚まで描き込んだ鷹は、今にも飛び立ちそうに見える。見つけた大人たちが集まってきた。',
      [
        Choice.h('自分が描いたと名乗り出る', '叱られるかもしれない。目を留める人もいるかもしれない', () {
          g.setFlag('tr_c_painter_owned');
          if (g.rng.chance(.6)) {
            g.j(4);
            return '大人たちは叱るのを忘れて鷹に見入った。消すのは惜しいと言って、その絵はしばらく残された。';
          }
          g.j(-2);
          return 'こっぴどく叱られ、一日がかりで拭き取らされた。それでも、鷹の目だけは最後まで消えなかった。';
        }),
        Choice.h('知らないふりをする', '叱られずに済む。描いたものは誰のものでもなくなる', () {
          return '誰の仕業か分からないまま、絵は拭き取られた。あなたは少しだけ悔しかった。';
        }),
      ],
      after: next,
    );
  }),
  ..._child2(),
  ..._child3(),
];

// ======================================================================
// 大人の岐路（`game.dart` の大人の場面に登録）
// ======================================================================

List<SceneDef> buildTraitScenes() => [
  ..._common(),
  ..._uncommon(),
  ..._rare(),
  ..._mythic(),
  // 2回目（trait_scenes2.dart）
  ..._common2(),
  ..._uncommon2(),
  ..._rare2(),
  ..._mythic2(),
  ..._common3(),
  ..._uncommon3(),
  ..._rare3(),
  ..._mythic3(),
];

// ---------------------------------------------------------------- よくある

List<SceneDef> _common() => [
  // ============================================ 剛力
  _tr('tr_power', 'power', 15, 45, 14, _lay, (g, next) {
    final l = g.l;
    g.ask(
      '力比べ',
      '${_serving(g) ? '普請場' : '村の辻'}で、大石が道をふさいでいた。男たちが三人がかりで押してもびくともしない。誰かが「あいつなら動かせる」とあなたを指さした。',
      [
        Choice.h('一人で大石に肩を入れる', '動かせば名が知れる。腰を痛めることもある', () {
          if (g.rng.chance(.75)) {
            _fame(g, 3);
            _net(g, 3);
            g.setFlag('tr_power_stone');
            g.mark('三人がかりで動かなかった大石を、一人で押しのけた');
            return '顔を真っ赤にして押すと、大石がごろりと転がった。見ていた者たちがどっと沸き、それから力仕事のたびに声がかかるようになった。';
          }
          _hp(g, -8);
          return '石は少し動いたが、腰に嫌な音がした。しばらく寝床から起き上がれなかった。';
        }),
        Choice.h('皆で掛け声を合わせて押そうと言う', '石は動く。手柄は皆のものになる', () {
          _net(g, 2);
          return 'あなたが先頭に立ち、掛け声に合わせて押した。石は道の脇へ落ち、皆で笑い合った。';
        }),
        Choice.h('力比べの賭けにして、見物人から銭を集める', '銭にはなる。見せ物にしたと眉をひそめる者もいる', () {
          if (g.rng.chance(.6)) {
            l.gold += g.rng.range(4, 9);
            _net(g, -1);
            return '銭を賭けさせてから石を動かした。懐は温まったが、年寄りたちは渋い顔をした。';
          }
          _pay(g, 3);
          return '賭けた途端に足を滑らせ、石は動かなかった。集めた銭は返すはめになった。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 人好きのする顔
  _tr('tr_beauty', 'beauty', 15, 50, 14, (g) => g.active, (g, next) {
    final l = g.l;
    final who = g.rng.pick(['旅の連歌師', '国を回る薬売り', '大店の隠居', '湯治帰りの尼']);
    g.ask(
      '通りすがりの縁',
      '渡し舟を待つあいだ、隣に座った$whoが、あなたに話しかけてきた。初めて会ったとは思えないほど話が弾み、舟が着くころには、身の上まで打ち明け合っていた。',
      [
        Choice.h('次に会う約束をして別れる', '縁が続く。思わぬ時に助けになるかもしれない', () {
          _net(g, 4);
          g.setFlag('tr_beauty_met');
          return '$whoは、困ったときには訪ねてこいと言って、住まいを書いた紙をくれた。';
        }),
        Choice.h('身の上の悩みを打ち明けて、知恵を借りる', '心が軽くなる。聞いた話が役に立つかもしれない', () {
          g.j(5);
          l.chi = _c(l.chi + 1);
          return '$whoは笑って聞き、自分も若いころ同じことで迷ったと言った。帰り道、足取りが軽かった。';
        }),
        Choice.h('ほどほどに話を切り上げる', '何も起きない', () => '舟を降りると、$whoは人ごみに紛れて見えなくなった。'),
      ],
      after: next,
    );
  }),

  // ============================================ 大食い
  _tr('tr_glutton', 'glutton', 15, 45, 14, _lay, (g, next) {
    final l = g.l;
    final where = _fighter(g) ? '陣中の炊き出し' : '秋祭りの振る舞い';
    g.ask(
      '大食いの賭け',
      '$whereで、誰がいちばん多く飯を平らげるかの賭けが始まった。あなたの食べっぷりを知る者たちが、あなたの名を挙げている。向こうには、隣の${_fighter(g) ? '組' : '村'}の大男が座っている。',
      [
        Choice.h('受けて立ち、腹がはち切れるまで食う', '勝てば銭と名が手に入る。食べ過ぎて寝込むかもしれない', () {
          if (g.rng.chance(.6)) {
            l.gold += g.rng.range(3, 7);
            _fame(g, 2);
            _net(g, 2);
            g.setFlag('tr_glutton_won');
            return '大男が箸を置いたとき、あなたはまだ茶碗を差し出していた。皆が腹を抱えて笑い、賭けの銭はすべてあなたのものになった。';
          }
          _hp(g, -6);
          g.j(-2);
          return '最後の一杯で腹が悲鳴を上げた。三日ほど、粥しか喉を通らなかった。';
        }),
        Choice.h('飯は腹八分にして、皆の分を残す', '名は上がらない。腹を空かせた者が喜ぶ', () {
          _net(g, 3);
          return '賭けを笑って断り、余った飯を子らに回した。あなたの腹の虫だけが不服そうに鳴いた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 酒豪
  _tr('tr_drinker', 'drinker', 18, 60, 14, _lay, (g, next) {
    final l = g.l;
    if (_serving(g)) {
      g.ask(
        '酒の席',
        '${_hn(g)}の宴が夜更けまで続き、居並ぶ者は次々と酔いつぶれた。素面に近いのはあなただけだ。隣で、酔った重臣の一人が「殿のやり方は長くは続かぬ」と、あらぬことを口走りはじめた。',
        [
          Choice.h('翌朝、聞いたことを殿にそっと伝える', '殿の覚えはよくなる。重臣の恨みを買うかもしれない', () {
            if (g.rng.chance(.65)) {
              _fav(g, 8);
              g.setFlag('tr_drinker_told');
              return '殿は黙って聞き、何も言わずにうなずいた。その重臣は、ほどなく遠い砦へ回された。';
            }
            _fav(g, 2);
            _net(g, -3);
            return '殿は「酒の上のことだ」と取り合わなかった。どこから漏れたのか、重臣はあなたを避けるようになった。';
          }),
          Choice.h('聞かなかったことにして、重臣を寝床まで運ぶ', '恩が一つできる。殿に知れれば、黙っていたと咎められる', () {
            _net(g, 4);
            g.setFlag('tr_drinker_kept');
            return '重臣を背負って寝床へ運んだ。翌朝、重臣は何も覚えていない顔で、あなたに妙に丁寧な礼を言った。';
          }),
        ],
        after: next,
      );
      return;
    }
    g.ask(
      '酒の席',
      '寄り合いのあとの酒盛りで、皆が次々と酔いつぶれた。素面に近いのはあなただけだ。隣で、酔った米問屋の手代が「秋には米の値が跳ね上がる、蔵の主はもう買い占めている」と、口を滑らせた。',
      [
        Choice.h('聞いた話を頼りに、今のうちに米を買っておく', '当たれば儲かる。外れれば銭が寝る', () {
          if (g.rng.chance(.6)) {
            l.gold += g.rng.range(5, 12);
            g.setFlag('tr_drinker_rice');
            return '秋、本当に米の値が跳ね上がった。買っておいた米で、蔵の主に負けない儲けが出た。';
          }
          _pay(g, 4);
          return '秋になっても米の値は動かなかった。手代はあの夜のことを何も覚えていなかった。';
        }),
        Choice.h('村の者たちに、米を売り急ぐなと伝える', '村が助かる。蔵の主ににらまれる', () {
          _net(g, 4);
          _fame(g, 1);
          return '村の者たちは米を売り急がず、秋に値を待って売った。蔵の主は、誰が漏らしたのかと手代を締め上げたらしい。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 声が大きい
  _tr('tr_loud', 'loud', 15, 60, 14, (g) => g.active, (g, next) {
    final l = g.l;
    g.ask('火事の夜', '夜半、厠に起きると、向かいの家の軒から火の粉が上がっていた。皆はまだ眠っている。風は町のほうへ吹いている。', [
      Choice.h('腹の底から叫んで、町じゅうを叩き起こす', '多くの者が助かる。煙に巻かれるかもしれない', () {
        if (g.rng.chance(.85)) {
          _fame(g, 4);
          _net(g, 4);
          g.setFlag('tr_loud_fire');
          g.mark('夜半の火事に、大声で町じゅうを叩き起こした');
          return 'あなたの声は三つ先の辻まで届いた。人々は寝間着のまま飛び出し、火は二軒を焼いただけで消し止められた。';
        }
        _hp(g, -10);
        _fame(g, 2);
        return '叫びながら戸を叩いて回るうちに、煙を吸って倒れた。人々は助かったが、あなたは何日も咳が止まらなかった。';
      }),
      Choice.h('まず自分の家の者を起こし、荷を運び出す', '家は守れる。隣近所には恨まれるかもしれない', () {
        l.gold += 1;
        _net(g, -1);
        return '家の者と荷を連れて逃げた。焼け跡で、向かいの家の者があなたを黙って見ていた。';
      }),
    ], after: next);
  }),

  // ============================================ 臆病
  _tr('tr_coward', 'coward', 16, 50, 14, _lay, (g, next) {
    final l = g.l;
    if (_fighter(g)) {
      g.ask(
        '陣触れの夜',
        '明日の出陣が告げられた。床に入っても、手の震えが止まらない。去年の戦で、隣にいた者が矢を受けて倒れた顔が浮かんで消えない。',
        [
          Choice.h('腹を下したと言って、陣を外してもらう', '命は拾う。臆したと噂されるかもしれない', () {
            _fav(g, -5);
            _net(g, -2);
            g.setFlag('tr_coward_stayed');
            return '組頭は鼻で笑って、あなたを留守居に回した。戦は勝ったが、帰ってきた朋輩たちの目が冷たかった。';
          }),
          Choice.h('震えを抱えたまま、黙って陣に出る', '何も変わらない。恐れを越えれば、一つ強くなる', () {
            g.j(-2);
            l.bu = _c(l.bu + 1);
            return '槍を握る手は、最後まで汗で滑った。それでも、あなたは列を離れなかった。';
          }),
          Choice.h('同じ組の古参に、怖いと打ち明ける', '笑われるかもしれない。心が軽くなるかもしれない', () {
            _net(g, 3);
            g.j(3);
            return '古参は笑わなかった。「怖いと分かる者のほうが長生きする」と言って、自分の守り札を貸してくれた。';
          }),
        ],
        after: next,
      );
      return;
    }
    g.ask('夜の物音', '夜更け、戸の外で、誰かが土を踏む音がした。家の者は眠っている。野盗の噂を聞いたばかりだ。', [
      Choice.h('家の者を起こし、裏口から逃げる支度をさせる', '命は拾う。ただの獣なら笑い話になる', () {
        if (g.rng.chance(.3)) {
          _net(g, 2);
          g.setFlag('tr_coward_fled');
          return '裏の藪に潜んでいるうちに、表の戸が破られた。荷は盗られたが、家の者は皆無事だった。';
        }
        g.j(-1);
        return '夜明けまで藪に潜んでいたが、物音の主は狸だった。家の者は呆れて笑った。';
      }),
      Choice.h('布団をかぶって、音が去るのを待つ', '何も起きないことを祈るしかない', () {
        if (g.rng.chance(.2)) {
          _pay(g, 4);
          return '朝になると、納屋の米俵が一つ消えていた。';
        }
        return '音はやがて遠ざかった。朝になると、庭に獣の足跡が残っていた。';
      }),
    ], after: next);
  }),

  // ============================================ 短気
  _tr('tr_hothead', 'hothead', 16, 55, 14, _lay, (g, next) {
    final l = g.l;
    final who = _serving(g) ? '同じ家中の若侍' : '隣村の男';
    g.ask(
      '侮りの言葉',
      '人の集まる場で、$whoがあなたのことを「口ばかりの奴」と聞こえよがしに言った。周りの者が、あなたの顔色をうかがっている。耳まで熱くなるのが分かる。',
      [
        Choice.h('その場で胸ぐらをつかむ', '黙らせられる。後で咎めを受けるかもしれない', () {
          if (g.rng.chance(.55)) {
            _fame(g, 1);
            _net(g, -2);
            if (_serving(g)) _fav(g, -3);
            g.setFlag('tr_hothead_fought');
            return '相手は顔色を変えて詫びた。ただ、その日のうちに、あなたが乱暴を働いたという噂が広まった。';
          }
          _hp(g, -10);
          _net(g, -2);
          return '取っ組み合いになり、二人とも血を流して引き分けられた。どちらにも叱りが下った。';
        }),
        Choice.h('拳を握りしめて、その場を去る', '争いは避けられる。腹の虫はおさまらない', () {
          g.j(-4);
          _net(g, 1);
          return '黙って背を向けた。その夜は眠れず、壁を一度だけ殴った。';
        }),
        Choice.h('言い返して、皆の前で笑いものにする', '口で勝てば、恨みが残る', () {
          if (g.rng.chance(_try(l.mi, .4))) {
            _fame(g, 2);
            _net(g, -1);
            return '言い返した一言に周りがどっと笑い、$whoは顔を赤くして去った。';
          }
          _fame(g, -1);
          return '言葉が喉で詰まり、かえって自分が笑われた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 信心深い
  _tr('tr_pious', 'pious', 15, 70, 14, (g) => g.active, (g, next) {
    final l = g.l;
    g.ask(
      '旅の聖',
      'ぼろをまとった旅の聖が、門口で鉦を鳴らしている。人々は目を合わせずに通り過ぎていく。あなたは、聖の首に掛けた古い数珠から目が離せなかった。',
      [
        Choice.h('家に招き入れ、粥と寝床を施す', '功徳になる。家の者は少し迷惑がる', () {
          _pay(g, 1);
          g.j(5);
          l.un = _c(l.un + 2);
          g.setFlag('tr_pious_alms');
          return '聖は粥をすすり、翌朝、あなたのために短い経を読んで発った。その年は、不思議と悪いことが起きなかった。';
        }),
        Choice.h('聖について、近くの霊場まで歩く', '心は洗われる。家を何日か空けることになる', () {
          _pay(g, 2);
          g.j(7);
          _hp(g, -3);
          g.setFlag('tr_pious_walked');
          g.mark('旅の聖について霊場まで歩き、経を授かった');
          return '三日かけて山の霊場まで歩いた。聖は別れ際に、短い経を一つ教えてくれた。それから、迷ったときにはその経を唱えるようになった。';
        }),
        Choice.h('わずかな銭を鉢に入れて、手を合わせる', '小さな功徳になる', () {
          _pay(g, 1);
          g.j(2);
          return '聖は深く頭を下げた。鉦の音が、しばらく背中についてきた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 倹約家
  _tr('tr_frugal', 'frugal', 22, 65, 14, _lay, (g, next) {
    final l = g.l;
    final saved = g.rng.range(8, 15);
    l.gold += saved;
    g.ask(
      '蓄えの壺',
      '床下に埋めた壺に、何年もかけて小銭を貯めてきた。気づけば、思った以上に重くなっている。ちょうどそのころ、${l.married ? '連れ合い' : '近所の者'}が、凶作で困っている親類のことを話してきた。',
      [
        Choice.h('壺の銭で、困っている親類を助ける', '恩が残る。貯めた年月は消える', () {
          _pay(g, saved);
          _net(g, 5);
          g.j(3);
          g.setFlag('tr_frugal_gave');
          return '壺を掘り出して銭を渡した。親類は泣いて礼を言い、あなたは空になった壺を、また床下に埋めた。';
        }),
        Choice.h('貸すことにして、少しずつ返してもらう', '銭は戻る。けちと陰口を叩かれる', () {
          l.gold += 2;
          _net(g, -2);
          return '証文を取って貸した。銭はきちんと戻ってきたが、親類はそれきり家に寄りつかなくなった。';
        }),
        Choice.h('黙って壺を埋め直す', '蓄えは残る。誰にも知られない', () {
          g.setFlag('tr_frugal_kept');
          return '何も言わずに壺を埋め直した。重みが、妙に心強かった。';
        }),
      ],
      after: next,
    );
  }),
];

// ---------------------------------------------------------------- 珍しい

List<SceneDef> _uncommon() => [
  // ============================================ 俊足
  _tr('tr_swift', 'swift', 15, 40, 14, _lay, (g, next) {
    final l = g.l;
    if (_fighter(g)) {
      g.ask(
        '早駆けの使い',
        '味方の砦が囲まれ、後詰めの知らせを届けねばならない。馬では敵の見張りに見つかる。誰かが、足の速いあなたの名を挙げた。',
        [
          Choice.h('夜の山道を駆けて、知らせを届ける', '届けば大きな手柄になる。敵の見張りに見つかれば命はない', () {
            if (g.rng.chance(.03)) {
              g.die('早駆けの使いの途中、敵の見張りに射られた', 'senshi');
              return '尾根を越えたところで、敵の見張りの矢が背に刺さった。';
            }
            _fav(g, 8);
            l.merit += 12;
            _fame(g, 3);
            g.setFlag('tr_swift_runner');
            g.mark('囲まれた砦へ、夜の山道を駆けて後詰めの知らせを届けた');
            return '一晩で峠を二つ越えた。知らせを受けた砦の兵が鬨の声を上げ、殿はあなたの足を「千金に値する」と言った。';
          }),
          Choice.h('足に自信のある者は他にもいると辞退する', '何も起きない', () {
            _fav(g, -1);
            return '別の者が使いに立った。知らせは無事に届いたらしい。';
          }),
        ],
        after: next,
      );
      return;
    }
    g.ask(
      '早駆けの使い',
      '町の大店の手代が、あなたの足の速さを聞きつけてやってきた。隣国の取引先へ、今日のうちに文を届けてほしいという。礼ははずむそうだ。',
      [
        Choice.h('引き受けて、日のあるうちに駆け通す', '銭になる。峠道は危うい', () {
          if (g.rng.chance(.85)) {
            l.gold += g.rng.range(5, 10);
            _net(g, 2);
            g.setFlag('tr_swift_runner');
            return '日が沈む前に文を届けた。手代は目を丸くし、それから何度も使いを頼んでくるようになった。';
          }
          _hp(g, -8);
          return '峠道で足をくじき、文は翌日になった。礼は半分に減らされた。';
        }),
        Choice.h('断る', '何も起きない', () => '手代は肩を落として帰っていった。'),
      ],
      after: next,
    );
  }),

  // ============================================ 夜目
  _tr('tr_nighteye', 'nighteye', 15, 55, 14, _lay, (g, next) {
    final l = g.l;
    final camp = _fighter(g);
    g.ask(
      '闇の中の影',
      camp
          ? '陣の夜番に立っていると、月のない闇の向こう、川の浅瀬を黒い影がいくつも渡ってくるのが見えた。隣の番兵には何も見えていない。'
          : '月のない夜、村はずれの道を帰っていると、闇の向こうで、黒い影がいくつも蔵のほうへ動いていくのが見えた。',
      [
        Choice.h('すぐに叫んで、皆に知らせる', '夜討ちなら防げる。見間違いなら笑われる', () {
          if (g.rng.chance(.75)) {
            _fame(g, 3);
            if (camp) {
              _fav(g, 6);
              l.merit += 8;
            } else {
              _net(g, 4);
            }
            g.setFlag('tr_nighteye_warned');
            return camp
                ? '篝火が焚かれ、浅瀬で待ち構えた味方が夜討ちの敵を追い返した。組頭は「よく見えたな」と首をひねった。'
                : '村の者が松明を手に飛び出し、影は散り散りに逃げていった。蔵は無事だった。';
          }
          _fame(g, -1);
          return '松明を向けると、影は鹿の群れだった。しばらく「夜目の鹿見」と笑われた。';
        }),
        if (camp && g.canFight)
          Choice.h('一人で闇にまぎれ、影のあとをつける', '敵の手の内が分かるかもしれない。見つかれば一人きりだ', () {
            if (g.rng.chance(.03)) {
              g.die('闇の中で敵の物見とはち合わせ、討たれた', 'senshi');
              return '影のあとをつけるうちに、背後から別の影に組みつかれた。';
            }
            l.merit += 14;
            _fav(g, 5);
            g.setFlag('tr_nighteye_scouted');
            g.mark('月のない夜、闇にまぎれて敵の物見のあとをつけ、伏兵の場所を知らせた');
            return '影は敵の物見だった。伏兵の場所を突き止めて戻ると、殿は夜のうちに陣を動かした。';
          }),
        Choice.h('見なかったことにする', '何も起きないことを祈る', () {
          if (g.rng.chance(.4)) {
            g.j(-3);
            return '翌朝、${camp ? '浅瀬に近い陣が荒らされていた' : '庄屋の蔵が破られていた'}。あなたは黙っていた。';
          }
          return '何事もなく夜が明けた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 弁舌巧み
  _tr('tr_tongue', 'tongue', 18, 60, 14, _lay, (g, next) {
    final l = g.l;
    final what = _serving(g)
        ? '隣の家中と、境目の山の木を誰が伐るかで揉めている。向こうの使いは口の立つ年寄りで、家中の誰も言い負かせない。'
        : '隣村と、川の水を引く順で揉めている。向こうの年寄りは口が立ち、こちらの者は誰も言い返せない。';
    g.ask('口争い', '$whatあなたに、談判の席に出てくれという話が来た。', [
      Choice.h('談判の席に出て、理を尽くして説く', '言い負かせば名が上がる。言い過ぎれば恨みが残る', () {
        if (g.rng.chance(_try(l.mi + traitPersuade(g), .45))) {
          _fame(g, 4);
          _net(g, 3);
          if (_serving(g)) _fav(g, 5);
          g.setFlag('tr_tongue_won');
          g.mark('揉めていた談判の席に出て、向こうの年寄りを言い負かした');
          return '一つずつ理を並べると、向こうの年寄りは黙り込み、最後には笑って折れた。帰り道、こちらの者たちがあなたを担ぎ上げんばかりだった。';
        }
        _net(g, -2);
        return '言い合いは平行線のまま終わった。向こうの年寄りは、あなたを「口の軽い若造」と呼んでいるらしい。';
      }),
      Choice.h('間に立って、双方の顔が立つ落としどころを探す', '大きな手柄にはならない。どちらにも恨まれない', () {
        _net(g, 4);
        return '日ごとに順を代えることで話がついた。どちらの年寄りも、自分が勝ったような顔で帰っていった。';
      }),
      Choice.h('関わり合いになるのを避ける', '何も起きない', () => '談判は長引き、結局は上の者の裁きを待つことになった。'),
    ], after: next);
  }),

  // ============================================ 馬術の達人
  _tr('tr_rider', 'rider', 15, 50, 14, _lay, (g, next) {
    final l = g.l;
    final serving = _serving(g);
    g.ask(
      '荒馬',
      serving
          ? '${_hn(g)}の厩に、誰も乗りこなせない荒馬が引かれてきた。殿への献上の馬だが、すでに二人が振り落とされて骨を折った。'
          : '市に、誰も乗りこなせない荒馬が売られていた。馬喰は、乗りこなせた者にはただで譲ると笑っている。',
      [
        Choice.h('鞍も置かずに飛び乗る', '乗りこなせば名が上がる。振り落とされれば大怪我だ', () {
          if (g.rng.chance(.7)) {
            _fame(g, 4);
            g.setFlag('tr_rider_horse');
            if (serving) {
              _fav(g, 8);
              g.mark('誰も乗りこなせなかった献上の荒馬を乗りこなした');
              return '荒馬は三度跳ね、それから嘘のようにおとなしくなった。殿は笑って「その馬はお前が使え」と言った。';
            }
            l.gold += 10;
            g.mark('市で誰も乗りこなせなかった荒馬を乗りこなし、譲り受けた');
            return '荒馬は三度跳ね、それから首を垂れた。馬喰は渋い顔で手綱を渡し、あなたはその馬を高値で売った。';
          }
          _hp(g, -12);
          return '四度目に跳ねたところで振り落とされた。肩を打ち、しばらく腕が上がらなかった。';
        }),
        Choice.h('何日もかけて、少しずつ馬を慣らす', '時はかかる。馬との縁は深くなる', () {
          g.j(4);
          if (serving) _fav(g, 4);
          g.setFlag('tr_rider_horse');
          return '毎朝、飼い葉を手から食べさせた。十日目、荒馬は自分から鼻面を寄せてきた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 鉄砲の才
  _tr(
    'tr_gunner',
    'gunner',
    16,
    50,
    14,
    (g) => _lay(g) && !g.l.gun && g.year >= 1550,
    (g, next) {
      final l = g.l;
      g.ask(
        '鉄砲の試し撃ち',
        '${_serving(g) ? '家中に南蛮渡りの鉄砲が届き、若い者に試し撃ちをさせることになった' : '旅の鍛冶が、町はずれで鉄砲の試し撃ちを見せている。誰か撃ってみないかと言っている'}。轟音に皆が尻込みするなか、あなたはなぜか、火縄の匂いに胸が騒いだ。',
        [
          Choice.h('進み出て、筒を構える', '当たれば道が開ける。筒が裂ければ怪我をする', () {
            if (g.rng.chance(.9)) {
              l.gun = true;
              l.bu = _c(l.bu + 3);
              _fame(g, 3);
              if (_serving(g)) _fav(g, 5);
              g.setFlag('tr_gunner_shot');
              g.mark('試し撃ちで、初めて握った鉄砲を的の真ん中に当てた');
              return '初めて握った筒なのに、玉は的の真ん中を撃ち抜いた。見ていた者がどよめき、それから撃ち方を教えてほしいと頼まれるようになった。';
            }
            _hp(g, -10);
            return '筒の継ぎ目から火が噴いた。頬に火傷を負い、玉はどこかへ飛んでいった。';
          }),
          Choice.h(
            '遠巻きに見るだけにする',
            '何も変わらない',
            () => '轟音が三度響き、試し撃ちは終わった。火縄の匂いが、しばらく鼻に残った。',
          ),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 薬の心得
  _tr('tr_herbal', 'herbal', 18, 65, 14, (g) => g.active, (g, next) {
    g.ask(
      '流行り病の村',
      '山向こうの村に、流行り病が出たと聞いた。薬師はおらず、寝込んだ者が日ごとに増えているという。あなたなら、山で採れる草で熱を下げる煎じ薬が作れる。',
      [
        Choice.h('薬草を背負って、村へ入る', '多くの命が助かるかもしれない。病をもらうかもしれない', () {
          if (g.rng.chance(.03)) {
            g.die('流行り病の看病の末に、自らも熱に倒れた', 'byo');
            return '十日のあいだ寝ずに煎じ薬を配り、最後の晩に、自分の額が熱いのに気づいた。';
          }
          _fame(g, 4);
          _net(g, 5);
          _hp(g, -6);
          g.setFlag('tr_herbal_village');
          g.mark('流行り病の村に入り、煎じ薬を配って回った');
          return '十日のあいだ村に寝泊まりして煎じ薬を配った。村を出るとき、助かった者たちが峠まで見送ってくれた。';
        }),
        Choice.h('煎じ方を書いた紙と薬草を、使いに託す', '自分は無事だ。うまく伝わるかは分からない', () {
          _net(g, 2);
          if (g.rng.chance(.6)) {
            _fame(g, 1);
            return '書き付けのとおりに煎じた薬が効いたと、あとで礼の品が届いた。';
          }
          return '薬草は届いたが、煎じ方を誤ったらしい。病はなかなか引かなかったと聞いた。';
        }),
        Choice.h('病が山を越えてこないよう、家にこもる', '身は守れる。後ろめたさが残る', () {
          g.j(-3);
          return '戸を閉ざしてひと月を過ごした。山向こうの村では、多くの者が亡くなったと聞いた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 目利き
  _tr('tr_appraiser', 'appraiser', 18, 65, 14, _lay, (g, next) {
    final l = g.l;
    final item = g.rng.pick(['煤けた茶碗', '鞘の傷んだ短刀', '虫に食われた掛け軸']);
    g.ask(
      '市の掘り出し物',
      '市の外れの古道具屋で、がらくたの山に$itemが埋もれていた。店の主は見向きもしていない。だが、あなたには分かる。これは、名のある者の手になる品だ。',
      [
        Choice.h('がらくたの値で買い取り、目の利く者に売る', '大きな儲けになる。見立て違いなら銭を捨てる', () {
          if (g.rng.chance(.75)) {
            l.gold += g.rng.range(12, 24);
            g.setFlag('tr_appraiser_find');
            g.mark('市の古道具屋のがらくたの山から、名のある品を見つけ出した');
            return '数日後、町の茶人が目の色を変えて買っていった。古道具屋には、少しだけ礼を置いてきた。';
          }
          _pay(g, 3);
          return '磨いてみると、よくできた写しだった。それでも、筋のよい写しだと茶人には褒められた。';
        }),
        if (_serving(g))
          Choice.h('買い取って、殿に献じる', '殿の覚えがよくなる。手元には何も残らない', () {
            _pay(g, 2);
            _fav(g, 8);
            g.setFlag('tr_appraiser_gift');
            return '殿は品を手に取り、しばらく黙って眺めていた。「よく見つけた」と一言あり、その晩の宴に呼ばれた。';
          }),
        Choice.h('店の主に、それは良い品だと教えてやる', '儲けはない。古道具屋に恩が残る', () {
          _net(g, 4);
          return '主は目を丸くし、それから深々と頭を下げた。それからは、よい品が入るたびに声をかけてくれるようになった。';
        }),
      ],
      after: next,
    );
  }),
];

// ---------------------------------------------------------------- 稀

List<SceneDef> _rare() => [
  // ============================================ 強運: 易者の見立て → 兜に止まった矢 → 拾った運
  _tr('tr_lucky_eki', 'lucky', 16, 40, 14, _lay, (g, next) {
    final l = g.l;
    g.ask(
      '易者の見立て',
      '辻の易者が、通りかかったあなたを呼び止めた。筮竹を何度も繰り直し、やがて青い顔で言った。「これほどの運は見たことがない。ただし、運は借り物だ。いつか返す時が来る」',
      [
        Choice.h('借り物なら、今のうちに使い切ってやると笑う', '運を頼みに生きる。天がどう見るかは分からない', () {
          l.un = _c(l.un + 3);
          g.setFlag('tr_lucky_told');
          g.setFlag('tr_lucky_bold');
          return 'あなたが笑うと、易者もつられて笑った。見料はいらないと言われた。';
        }),
        Choice.h('見料をはずみ、返す時の心得を尋ねる', '心構えはできる。銭がかかる', () {
          _pay(g, 2);
          g.j(3);
          g.setFlag('tr_lucky_told');
          g.setFlag('tr_lucky_humble');
          return '易者は「人に分けよ。分けた運は、減らずに戻る」とだけ言った。';
        }),
        Choice.h('辻の易者など当てにしない', '何も変わらない', () {
          g.setFlag('tr_lucky_told');
          return '振り返ると、易者はまだこちらを見ていた。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_lucky_arrow', 'lucky', 17, 60, 20, (g) => g.active, (g, next) {
    final l = g.l;
    final fight = _fighter(g);
    g.ask(
      fight ? '兜に止まった矢' : '落ちてきた梁',
      fight
          ? '乱戦のさなか、ひゅっと風を切る音がして、額に衝撃が走った。気づくと、一本の矢が兜の鉢金に突き立ち、震えている。あと指一本ずれていれば、眉間を射抜かれていた。'
          : '普請中の寺の軒下を通りかかったとき、頭上で縄の切れる音がした。太い梁が、あなたの鼻先をかすめて地面にめり込んだ。あと半歩前にいれば、命はなかった。',
      [
        Choice.h('拾った命だと思い定め、より大きな勝負に出る', '名を上げる好機をつかむかもしれない。運は何度も続かない', () {
          if (fight) {
            l.merit += 15;
            _fame(g, 5);
            _fav(g, 4);
            g.mark('兜に矢を受けながら、そのまま敵陣へ駆け入って手柄を立てた');
            g.setFlag('tr_lucky_spared');
            return '矢を兜に立てたまま敵陣へ駆け入った。その姿を見た味方が奮い立ち、殿は「矢の止まる男」と呼んで笑った。';
          }
          l.gold += g.rng.range(6, 12);
          g.setFlag('tr_lucky_spared');
          return '寺の和尚は「仏が守った」と言って、あなたに普請の帳場を任せた。思いがけない実入りになった。';
        }),
        Choice.h('命あっての物種と、しばらく身を慎む', '命を大事にする。好機は見送る', () {
          g.j(4);
          _hp(g, 5);
          g.setFlag('tr_lucky_spared');
          return '矢と梁のことを思い出すたびに、首筋が寒くなった。その年は、無理をせずに過ごした。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_lucky_find', 'lucky', 19, 70, 20, (g) => g.active, (g, next) {
    final l = g.l;
    final rich = g.rng.pick(['堺の豪商', '京の大きな酒屋', '博多の船持ち']);
    g.ask('拾った運', '雨上がりの街道で、泥に埋もれた革の財布を拾った。ずしりと重い。中には砂金と、$richの名を書いた手形が入っている。', [
      Choice.h('名を頼りに、持ち主へ届ける', '銭は手に入らない。思わぬ縁がつながるかもしれない', () {
        _net(g, 5);
        g.setFlag('tr_lucky_returned');
        if (g.l.people['恩のある豪商'] == null) {
          g.meet('恩のある豪商', _newName(g, female: false), 50);
        }
        if (g.hasFlag('tr_lucky_humble') || g.rng.chance(.6)) {
          l.gold += g.rng.range(10, 20);
          g.mark('街道で拾った$richの財布を届け、その縁で引き立てを受けた');
          return '$richの主は自ら出てきて、あなたの手を握った。「正直者には運がつく」と言って、礼金と、いつでも訪ねてよいという書き付けをくれた。';
        }
        return '$richの主は財布を受け取り、手代に礼の品を持たせた。顔を覚えておくと言われた。';
      }),
      Choice.h('天の授かり物と思って、懐に入れる', '大きな銭になる。借りた運を使ったことになる', () {
        l.gold += g.rng.range(15, 30);
        g.setFlag('tr_lucky_kept');
        if (g.hasFlag('tr_lucky_bold') && g.rng.chance(.3)) {
          l.un = _c(l.un - 6);
          g.j(-4);
          return '砂金で蔵は潤った。だがその年から、何をしても裏目に出るようになった。易者の言葉が、ときどき頭をよぎる。';
        }
        return '砂金で蔵は潤った。財布は川に流した。';
      }),
    ], after: next);
  }),

  // ============================================ 人の顔を忘れない: 見覚えのある顔 → お忍びの客
  _tr('tr_faces_spy', 'faces', 18, 60, 14, _lay, (g, next) {
    final l = g.l;
    final serving = _serving(g);
    g.ask(
      '見覚えのある顔',
      serving
          ? '近ごろ${_hn(g)}に奉公に上がった小者の顔に、見覚えがある。何年も前、他国の城下で見かけた、敵方の家中の下人だ。名も身なりも変えているが、間違いない。'
          : '近ごろ村に住みついた行商の顔に、見覚えがある。何年も前、隣国の宿場で、盗人として追われていた男だ。名も身なりも変えているが、間違いない。',
      [
        Choice.h('すぐに上の者へ知らせる', '間者なら大手柄だ。人違いなら恥をかく', () {
          g.setFlag('tr_faces_seen');
          if (g.rng.chance(.8)) {
            _fame(g, 4);
            if (serving) {
              _fav(g, 10);
              l.merit += 10;
            } else {
              _net(g, 4);
            }
            g.setFlag('tr_faces_caught');
            g.mark(
              serving ? '奉公に紛れ込んだ敵方の間者を、昔見た顔から見破った' : '村に住みついた行商が、昔見た盗人だと見破った',
            );
            return '問い詰めると、男は顔色を変えて逃げ出し、すぐに捕らえられた。懐からは${serving ? '城の絵図' : '盗んだ品の書き付け'}が出てきた。';
          }
          _fame(g, -2);
          return '問い詰められた男は、身に覚えがないと泣いて訴えた。結局、確かなことは分からずじまいだった。';
        }),
        Choice.h('素知らぬ顔で、男の動きを見張る', '確かめてから動ける。その間に何か起きるかもしれない', () {
          g.setFlag('tr_faces_seen');
          if (g.rng.chance(.6)) {
            _fame(g, 2);
            if (serving) _fav(g, 6);
            return '数日見張るうちに、男が夜中に${serving ? '城の堀を測っている' : '庄屋の蔵の錠を探っている'}ところを押さえた。';
          }
          return 'ある朝、男は姿を消していた。何が目当てだったのかは分からない。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_faces_lord', 'faces', 20, 65, 20, (g) => g.active && g.alive.isNotEmpty, (
    g,
    next,
  ) {
    final l = g.l;
    final house = l.lord ?? _nearOther(g);
    if (house == null) {
      next();
      return;
    }
    final hn = '${houseName(g, house)}家';
    final isLord = l.lord == house;
    g.ask(
      'お忍びの客',
      '粗末な身なりの侍が二人、${l.rank == 0 ? 'あなたの家に一夜の宿を求めてきた' : '城下の茶屋の隅に座っている'}。その一人の顔に、見覚えがある。ずっと昔、行列の輿の中にちらりと見た顔だ。$hnの${isLord ? '殿その人' : '当主'}に違いない。',
      [
        Choice.h('素知らぬ顔で、心を込めてもてなす', '正体を明かさずに済む。気づかれていたと分かれば、覚えられる', () {
          g.setFlag('tr_faces_hosted');
          if (l.rank == 0 &&
              !g.hasFlag('way_merchant') &&
              !g.hasFlag('way_outlaw') &&
              g.rng.chance(.6)) {
            _join(g, house);
            _fame(g, 4);
            g.mark('お忍びの$hnの当主を素知らぬ顔でもてなし、召し抱えられた');
            return '翌朝、客は笑って「気づいていたな」と言った。ひと月後、$hnから使いが来て、あなたは${l.female ? '奥に上がる' : '足軽として仕える'}ことになった。';
          }
          if (isLord) _fav(g, 10);
          _fame(g, 3);
          _net(g, 3);
          return '客は「よい目をしている」と言い残して去った。しばらくして、$hnから礼の品が届いた。';
        }),
        Choice.h('ひざまずいて、名を呼ぶ', '驚かせる。忍んでいる者には迷惑かもしれない', () {
          g.setFlag('tr_faces_hosted');
          if (g.rng.chance(.5)) {
            if (isLord) _fav(g, 4);
            _fame(g, 2);
            return '客は一瞬だけ顔をこわばらせ、それから苦笑した。「人の顔を忘れぬ者は、使い道がある」';
          }
          _net(g, -2);
          return '客は「人違いだ」と言って、その夜のうちに発った。あなたの名だけは、きちんと聞いていった。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 双子: 片割れの噂 → 片割れとの対面 → 入れ替わり
  _tr('tr_twin_rumor', 'twin', 18, 45, 14, _lay, (g, next) {
    final where = g.rng.pick(['隣国の宿場', '山向こうの湊', '遠い国の市']);
    g.ask(
      '片割れの噂',
      '旅から戻った知り合いが、妙なことを言った。「$whereで、お前とそっくりの顔を見た。声までそっくりだった」。幼いころに聞かされた話が胸によみがえる。双子は忌まれ、片方は里子に出されたのだと。',
      [
        Choice.h('暇をもらって、$whereへ探しに行く', '会えるかもしれない。会ってどうなるかは分からない', () {
          _pay(g, 3);
          g.setFlag('tr_twin_heard');
          g.setFlag('tr_twin_sought');
          g.setFlag('tr_twin_place:$where');
          return '$whereの宿や市を何日も尋ね歩いた。あの顔の者なら、少し前までここにいたと、何人もが言った。';
        }),
        Choice.h('今さら会っても仕方がないと、胸にしまう', '暮らしは乱れない。心のどこかに残る', () {
          g.setFlag('tr_twin_heard');
          g.setFlag('tr_twin_place:$where');
          g.j(-2);
          return '探しには行かなかった。ただ、水に映った自分の顔を、ときどき長く見るようになった。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_twin_meet', 'twin', 19, 55, 20, (g) => g.active, (g, next) {
    final l = g.l;
    final name = g.rng.pick(l.female ? kGivenF : kGivenM);
    final sought = g.hasFlag('tr_twin_sought');
    g.ask(
      '片割れとの対面',
      '${sought ? '探していた' : '思いがけず'}その人が、あなたの前に立った。$nameと名乗ったその顔は、鏡を見ているようだった。里子に出された先で、${g.rng.pick(['船の水夫として', '寺の下働きとして', '馬借の手伝いとして'])}生きてきたという。',
      [
        Choice.h('手を取って、家に迎え入れる', '血の縁が戻る。暮らしは一人分重くなる', () {
          _pay(g, 3);
          g.j(8);
          g.meet('片割れ', name, 70);
          g.setFlag('tr_twin_met');
          g.setFlag('tr_twin_home');
          g.mark('里子に出された双子の片割れ・$nameと巡り会い、家に迎えた');
          return '$nameは土間に立ったまま、しばらく泣いていた。その晩、二人で同じ夢の話をして、顔を見合わせて笑った。';
        }),
        Choice.h('時おり便りをやりとりする約束をする', '縁はつながる。互いの暮らしは変わらない', () {
          g.j(4);
          g.meet('片割れ', name, 50);
          g.setFlag('tr_twin_met');
          return '別れ際、$nameは「次は俺がそっちへ行く」と言った。それから、年に何度か便りが届くようになった。';
        }),
        Choice.h('名乗らずに、その場を去る', '何も変わらない。知らぬままでいられる', () {
          g.j(-4);
          g.setFlag('tr_twin_parted');
          return '背を向けて歩き出した。振り返ると、$nameも同じように背を向けていた。';
        }),
      ],
      after: next,
    );
  }),
  _tr(
    'tr_twin_swap',
    'twin',
    20,
    60,
    20,
    (g) => g.active && g.l.people.containsKey('片割れ'),
    (g, next) {
      final l = g.l;
      final tw = l.people['片割れ']!.name;
      if (_fighter(g)) {
        g.ask(
          '入れ替わり',
          '明日は大きな戦になる。$twが夜更けに訪ねてきて、思いつめた顔で言った。「明日は俺がお前の具足を着て出る。お前には、まだ死なれては困る者がいる」',
          [
            Choice.h('片割れの申し出を断り、自ら陣に出る', '自分の戦は自分で戦う。片割れは安堵し、少し寂しがる', () {
              _bond(g, '片割れ', 5);
              g.setFlag('tr_twin_refused');
              return '$twの肩を叩いて、首を振った。翌朝、陣へ向かうあなたを、$twは門の外でずっと見送っていた。';
            }),
            Choice.h('二人で同じ具足を着て、影武者として並んで出る', '敵の目を欺ける。どちらかが討たれるかもしれない', () {
              if (g.rng.chance(.04)) {
                g.die('双子の片割れと並んで出た戦で、二人とも帰らなかった', 'senshi');
                return '同じ具足の二人は、敵の目を引きつけすぎた。';
              }
              l.merit += 15;
              _fame(g, 5);
              g.setFlag('tr_twin_kagemusha');
              g.mark('双子の片割れと同じ具足で並び出て、敵を惑わせた');
              return '右にも左にも同じ武者がいる。敵は惑い、狙いを定められないまま崩れた。戦のあと、殿は二人を並べて大笑いした。';
            }),
          ],
          after: next,
        );
        return;
      }
      g.ask(
        '入れ替わり',
        '$twが青い顔で駆け込んできた。博打の借りがかさみ、取り立ての者に追われているという。「お前の顔なら、俺の代わりに申し開きができる」',
        [
          Choice.h('片割れになりすまして、取り立ての者に会う', '片割れは助かるかもしれない。荒っぽい連中だ', () {
            if (g.rng.chance(.6)) {
              _pay(g, 5);
              _bond(g, '片割れ', 15);
              g.setFlag('tr_twin_swapped');
              return '$twの名で頭を下げ、少しずつ返す約束を取りつけた。取り立ての者は、最後まで入れ替わりに気づかなかった。';
            }
            _hp(g, -12);
            _bond(g, '片割れ', 10);
            return '取り立ての者は、話も聞かずに殴りかかってきた。あなたは片割れの代わりに、さんざんに打ち据えられた。';
          }),
          Choice.h('借りを肩代わりして、二度とするなと叱る', '片割れは助かる。蔵は軽くなる', () {
            _pay(g, 10);
            _bond(g, '片割れ', 10);
            return '$twは土間に額をこすりつけた。それからしばらく、賭場には近づかなかったらしい。';
          }),
          Choice.h('自分でまいた種だと突き放す', '巻き込まれずに済む。片割れとの縁は細る', () {
            _bond(g, '片割れ', -20);
            g.setFlag('tr_twin_cold');
            return '$twは黙って出ていった。それから便りが途絶えた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 南蛮の血: 伴天連の目 → 通詞の口 → 南蛮船の誘い
  _tr(
    'tr_nanban_padre',
    'nanban',
    15,
    45,
    14,
    (g) => g.active && g.year >= 1550 && g.year <= 1600,
    (g, next) {
      final l = g.l;
      g.ask(
        '伴天連の目',
        '町の辻で説教をしていた黒衣の伴天連が、人垣の中のあなたに目を留めた。人をかき分けて近づき、あなたの髪と目をしげしげと見て、たどたどしい言葉で「あなたの中に、海の向こうの血がある」と言った。',
        [
          Choice.h('伴天連のもとに通い、海の向こうの言葉を習う', '珍しい言葉が身につく。南蛮かぶれと陰口を叩かれる', () {
            l.chi = _c(l.chi + 4);
            _net(g, -1);
            g.setFlag('tr_nanban_lang');
            g.mark('伴天連のもとに通い、海の向こうの言葉を習った');
            return '南蛮寺の裏の小部屋で、毎晩少しずつ言葉を習った。母方の祖父が口ずさんでいた歌の意味が、ある晩ふいに分かった。';
          }),
          Choice.h('自分はこの国の者だと言って、背を向ける', '何も変わらない', () {
            g.setFlag('tr_nanban_turned');
            return '伴天連は寂しそうに十字を切った。その夜、母に祖父の話を初めて尋ねた。';
          }),
        ],
        after: next,
      );
    },
  ),
  _tr('tr_nanban_tsuji', 'nanban', 17, 55, 20, (g) => g.active && g.year <= 1610, (
    g,
    next,
  ) {
    final l = g.l;
    final serving = _serving(g);
    g.ask(
      '通詞の口',
      serving
          ? '湊に南蛮船が入り、${_hn(g)}の殿が鉄砲と火薬の取り引きを望んでいる。だが、まともに言葉の通じる者がいない。あなたが南蛮の言葉を習ったことを、誰かが殿の耳に入れた。'
          : '湊に南蛮船が入り、町の大店が取り引きの通詞を探している。言葉の通じる者がおらず、礼ははずむという。',
      [
        Choice.h('通詞として、取り引きの席に座る', '道が開ける。言葉を取り違えれば、取り引きが壊れる', () {
          if (g.rng.chance(_try(l.chi, .55))) {
            l.gold += g.rng.range(10, 20);
            _fame(g, 5);
            if (serving) _fav(g, 10);
            g.setFlag('tr_nanban_tsuji_done');
            g.mark('南蛮船の取り引きで通詞を務めた');
            return '船長は、あなたが祖父の国の言葉で話すと目を見開き、それからは何でもあなたを通して話すようになった。取り引きは思った以上の値でまとまった。';
          }
          _fame(g, -2);
          g.setFlag('tr_nanban_tsuji_done');
          return '値の桁を一つ取り違え、席が凍りついた。どうにか取り繕ったが、船長は少し笑っていた。';
        }),
        Choice.h('南蛮の血が人に知れるのを恐れて、断る', '暮らしは静かなまま。開きかけた道は閉じる', () {
          g.setFlag('tr_nanban_hid');
          return '口がないと聞くと、殿も大店も残念がった。あなたは湊に近づかないようにした。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_nanban_ship', 'nanban', 20, 60, 20, (g) => g.active && g.year <= 1612, (
    g,
    next,
  ) {
    final l = g.l;
    g.ask(
      '南蛮船の誘い',
      '顔なじみになった南蛮船の船長が、帆を上げる前の晩にあなたを船に呼んだ。「次の航海に、通詞として乗らないか。海の向こうの湊を見せてやる。お前の祖父の国も、遠くない」',
      [
        Choice.h('船に乗り、海の向こうの湊まで渡る', '見たことのない世を見る。海は人を返さないこともある', () {
          if (g.rng.chance(.05)) {
            g.die('異国の湊を目指して海の彼方へ去り、そのまま戻らなかった', 'yukue');
            return '船は嵐の季節に外海へ出た。それきり、あなたの消息を知る者はいない。';
          }
          l.gold += g.rng.range(20, 40);
          l.chi = _c(l.chi + 5);
          _fame(g, 6);
          g.setFlag('tr_nanban_sailed');
          g.mark('南蛮船に乗って海の向こうの湊まで渡り、二年ののちに戻った');
          return '呂宋の湊で見たこともない果物を食べ、天竺の商人と話した。二年ののちに戻ったとき、あなたの話を聞きに、遠くからも人が来た。';
        }),
        Choice.h('この国で生きると決めて、船を見送る', '暮らしは変わらない。帆影はいつまでも目に残る', () {
          g.j(2);
          g.setFlag('tr_nanban_stayed');
          return '夜明け、船は帆をいっぱいに張って湊を出ていった。船長は甲板から、いつまでも帽子を振っていた。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 虫の知らせ: 胸騒ぎの夜 → 虫の知らせの別れ
  _tr('tr_sixth_night', 'sixth', 16, 60, 14, _lay, (g, next) {
    final l = g.l;
    g.ask(
      '胸騒ぎの夜',
      '夕方から、胸がざわついて仕方がない。何がというのではない。ただ、今夜この家で眠ってはいけない気がする。${l.married ? '連れ合いは' : '家の者は'}、気のせいだと笑っている。',
      [
        Choice.h('家の者を連れて、今夜は寺の軒下に泊まる', '何もなければ笑い話だ', () {
          g.setFlag('tr_sixth_heeded');
          if (g.rng.chance(.6)) {
            _fame(g, 2);
            g.j(4);
            g.mark('胸騒ぎに従って家を空けた夜、家が焼け落ちた');
            return '夜半、家から火が出た。隣の家の竈の火が移ったのだという。焼け跡に立ったとき、皆があなたを黙って見た。';
          }
          g.j(-1);
          return '何事もなく朝が来た。家の者は笑ったが、あなたの胸のざわつきは、なぜか消えていた。';
        }),
        Choice.h('気のせいだと言い聞かせて、眠る', '何もなければそれでよい', () {
          g.setFlag('tr_sixth_ignored');
          if (g.rng.chance(.5)) {
            _hp(g, -12);
            _pay(g, 5);
            return '夜半、煙の匂いで飛び起きた。家の者を連れて逃げ出すのがやっとで、家財の多くを焼いた。';
          }
          return '何事もなく朝が来た。胸のざわつきは、しばらく消えなかった。';
        }),
      ],
      after: next,
    );
  }),
  _tr(
    'tr_sixth_parting',
    'sixth',
    20,
    75,
    20,
    (g) => g.active && _sixthWho(g) != null,
    (g, next) {
      final p = _sixthWho(g)!;
      final name = g.l.people[p]!.name;
      g.ask(
        '虫の知らせの別れ',
        'ある朝、目が覚めたとき、なぜか$p（$name）の顔が浮かんで離れなかった。あの胸のざわつきだ。これは、別れの知らせだと分かる。',
        [
          Choice.h('何もかも置いて、すぐに会いに行く', '間に合うかもしれない。務めを放り出すことになる', () {
            if (_serving(g)) _fav(g, -3);
            _bond(g, p, 10);
            g.j(4);
            g.setFlag('tr_sixth_went');
            g.mark('虫の知らせに駆けつけ、$nameと最後の言葉を交わした');
            return '$nameは床に伏していた。あなたの顔を見ると笑い、「来ると思った」と言った。その夜、手を握ったまま話し込んだ。';
          }),
          Choice.h('文を書いて、早飛脚に託す', '思いは届く。顔は見られない', () {
            _bond(g, p, 5);
            return '何度も書き直した文を託した。ひと月後、$nameが文を胸に抱いて逝ったと知らせが来た。';
          }),
          Choice.h('ただの思い過ごしだと、日々の務めに戻る', '何も変わらない。のちに悔やむかもしれない', () {
            g.j(-5);
            return '十日後、$nameが亡くなったと聞いた。あの朝のことを、何度も思い出した。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 絵の才: 絵師の工房 → 城の襖絵
  _tr('tr_painter_studio', 'painter', 16, 35, 14, _lay, (g, next) {
    final l = g.l;
    final child = g.hasFlag('tr_c_painter_owned');
    g.ask(
      '絵師の工房',
      '${child ? '幼い日に描いた鷹の絵のことを、どこかで聞きつけたらしい。' : ''}京から下ってきた絵師が、あなたの描いた絵を見て、筆を置いた。「この筆は、教えて身につくものではない。わしの工房へ来ぬか」。都の大寺や武家の襖を描いてきた工房だという。',
      [
        Choice.h(
          l.rank == 0 ? 'すべてを置いて、工房に弟子入りする' : '務めの合間に、工房へ通って学ぶ',
          '絵の道が開ける。今の暮らしからは離れる',
          () {
            g.setFlag('tr_painter_pupil');
            g.setFlag('tr_painter');
            l.chi = _c(l.chi + 3);
            g.j(6);
            if (!l.people.containsKey('師')) {
              g.meet('師', '絵師 ${g.rng.pick(['永真', '宗秀', '光信', '元春'])}', 45);
            }
            g.mark('京から下ってきた絵師に見込まれ、工房で絵を学んだ');
            return '工房では、墨をするだけで一年が過ぎた。それでも、兄弟子たちが匙を投げた下絵を、師はあなたに任せるようになった。';
          },
        ),
        Choice.h('絵は楽しみに描くだけにする', '暮らしは変わらない。筆は手放さない', () {
          g.setFlag('tr_painter_side');
          g.j(2);
          return '絵師は惜しそうに首を振り、旅立つ前に良い筆を一本くれた。';
        }),
      ],
      after: next,
    );
  }),
  _tr(
    'tr_painter_castle',
    'painter',
    20,
    70,
    20,
    (g) => g.active && g.alive.isNotEmpty,
    (g, next) {
      final l = g.l;
      final house = l.lord ?? _nearOther(g) ?? g.alive.first.name;
      final hn = '${houseName(g, house)}家';
      final pupil = g.hasFlag('tr_painter_pupil');
      g.ask(
        '城の襖絵',
        '$hnが新しい館の大広間の襖絵を描く者を探している。${pupil ? '師の工房に話が来て、師はあなたに任せると言った' : '楽しみに描いていた絵を見た誰かが、あなたの名を挙げた'}。描くのは、四季の松か、猛る虎か、殿の望みはまだ決まっていない。',
        [
          Choice.h('四季の松を、静かに描く', '長く愛される絵になる。目を引く絵ではない', () {
            l.gold += g.rng.range(15, 25);
            _fame(g, 6);
            if (l.lord == house) _fav(g, 8);
            g.setFlag('tr_painter_castle_done');
            g.mark('$hnの館の大広間に、四季の松の襖絵を描いた');
            return '描き上げるのに一年かかった。襖を閉めると、大広間に松風が吹いたようだと、殿は言った。';
          }),
          Choice.h('猛る虎を、襖いっぱいに描く', '見る者を圧する。気に入られなければ塗り込められる', () {
            if (g.rng.chance(.65)) {
              l.gold += g.rng.range(20, 35);
              _fame(g, 8);
              if (l.lord == house) _fav(g, 10);
              g.setFlag('tr_painter_castle_done');
              g.mark('$hnの館の大広間に、猛る虎の襖絵を描いた');
              return '襖を開けた家臣が、思わず刀の柄に手をかけたという。それから、あなたの虎を見たいという客が絶えなかった。';
            }
            _fame(g, -2);
            return '殿は「客が怯える」と言って、虎の上から金を塗らせた。礼の銭だけは、きちんと届いた。';
          }),
        ],
        after: next,
      );
    },
  ),
];

/// 虫の知らせで浮かぶ人（いまいる縁のある人のうち、老いた師・幼なじみ・片割れ・恩のある豪商の順）。
String? _sixthWho(Game g) {
  for (final r in const ['師', '幼なじみ', '片割れ', '恩のある豪商']) {
    if (g.l.people.containsKey(r)) return r;
  }
  return null;
}

void _bond(Game g, String role, int n) {
  final p = g.l.people[role];
  if (p != null) p.bond = clampInt(p.bond + n, 0, 100);
}

// ---------------------------------------------------------------- 幻

/// 落胤の実の父の家（旗 `tr_rakuin_house:<家>`）。
String? _rakuinHouse(Game g) => _val(g, 'tr_rakuin_house:');

bool _rakuinAlive(Game g) {
  final h = _rakuinHouse(g);
  return h != null && (g.fa[h]?.alive ?? false);
}

/// 正夢の夢の中身（旗 `tr_yume_of:<中身>`）。
String _dream(Game g) => _val(g, 'tr_yume_of:') ?? '燃える寺';

List<SceneDef> _mythic() => [
  // ============================================ 落胤: 形見の守り袋 → 実の父の家の使い → 名乗りの時 → 血を分けた兄
  _tr(
    'tr_rakuin_charm',
    'rakuin',
    15,
    30,
    16,
    (g) => g.active && g.alive.length >= 2,
    (g, next) {
      final l = g.l;
      final cand = g.alive.where((f) => f.name != l.lord).toList()
        ..sort((a, b) => b.power.compareTo(a.power));
      final house = g.rng.pick(cand.take(4).toList()).name;
      final hn = '${houseName(g, house)}家';
      g.setFlag('tr_rakuin_house:$house');
      g.ask(
        '形見の守り袋',
        '母が長い患いの床で、あなたを枕元に呼んだ。震える手で渡されたのは、古い錦の守り袋だった。中には、$hnの紋を染めた小さな布切れが入っている。「あなたの本当の父上は、$hnの殿さまです。若いころ、お屋敷に奉公していたときに…」',
        [
          Choice.h(
            '母の言葉を胸にしまい、守り袋を肌身離さず持つ',
            '今の暮らしは変わらない。いつか、守り袋が物を言うかもしれない',
            () {
              g.setFlag('tr_rakuin_knows');
              g.j(-2);
              g.mark('母の今わの際に、自分が$hnの当主の落胤だと明かされた');
              return '母は、それきり多くを語らなかった。守り袋の紋を、夜ごと灯にかざして見た。';
            },
          ),
          Choice.h('そんな話は聞かなかったことにする', '何も変わらない。守り袋は箱の底にしまう', () {
            g.setFlag('tr_rakuin_knows');
            g.setFlag('tr_rakuin_denied');
            return '守り袋は箱の底にしまった。けれど、$hnの名を聞くたびに、胸の奥がざわついた。';
          }),
        ],
        after: next,
      );
    },
  ),
  _tr(
    'tr_rakuin_envoy',
    'rakuin',
    17,
    45,
    25,
    (g) => g.active && _rakuinAlive(g),
    (g, next) {
      final hn = '${houseName(g, _rakuinHouse(g))}家';
      g.ask(
        '実の父の家の使い',
        '旅装の老いた侍が、あなたを訪ねてきた。$hnの古い家臣だという。あなたの顔を見るなり、はらはらと涙をこぼした。「殿は老いられ、病の床で、昔ゆえあって手放した子の行方を案じておられる。せめて一目会ってはいただけぬか」',
        [
          Choice.h('守り袋を懐に、老臣について$hnの城下へ行く', '実の父に会える。今の暮らしが揺らぐかもしれない', () {
            _pay(g, 2);
            g.setFlag('tr_rakuin_met');
            g.j(5);
            g.mark('$hnの老臣に伴われ、病の床の実の父に対面した');
            return '奥の間の床に、痩せた老人が横たわっていた。守り袋を見せると、老人は布切れを震える指でなぞり、「母に似ている」と言った。';
          }),
          Choice.h('自分の父は育ての父だけだと言って、断る', '今の暮らしを守れる。この縁は二度と来ないかもしれない', () {
            g.setFlag('tr_rakuin_refused');
            g.j(-2);
            _net(g, 1);
            return '老臣は深く頭を下げ、何も言わずに帰っていった。数年後、$hnの殿が亡くなったと風の噂に聞いた。';
          }),
        ],
        after: next,
      );
    },
  ),
  _tr('tr_rakuin_name', 'rakuin', 18, 50, 25, (g) => _lay(g) && _rakuinAlive(g), (
    g,
    next,
  ) {
    final l = g.l;
    final house = _rakuinHouse(g)!;
    final hn = '${houseName(g, house)}家';
    const r = 4;
    g.ask(
      '名乗りの時',
      '$hnから正式な使いが来た。殿はあなたを我が子と認め、一門の末に連なる名を与えると言っている。家中には、素性の知れぬ者を、と眉をひそめる者も多いという。',
      [
        Choice.h('$hnの名を名乗り、一門として仕える', '一門の者として重く用いられる。家中に敵も生まれる', () {
          if (l.lord != house) {
            l.lord = house;
            l.fav = 45;
          } else {
            _fav(g, 15);
          }
          if (l.rank < r) l.rank = r;
          if (l.rank > l.maxRank) l.maxRank = l.rank;
          if (!l.female && l.troops < 20) l.troops = 20;
          l.ronin = false;
          _fame(g, 10);
          g.setFlag('tr_rakuin_named');
          g.mark('$hnの当主の子と認められ、一門に連なる名を与えられた');
          return '大広間で、家臣たちの前に名を披露された。誰もが頭を下げたが、上座に近い一人だけは、最後まであなたを見ようとしなかった。それが、正室の子、あなたの異母兄だった。';
        }),
        Choice.h('名は受けず、扶持だけをありがたく頂く', '暮らしは楽になる。家中の争いには関わらずに済む', () {
          l.gold += 30;
          g.j(4);
          g.setFlag('tr_rakuin_stipend');
          return '使いは不思議そうな顔をしたが、年ごとの扶持を約して帰っていった。名を名乗らない落胤のことは、やがて家中でも口にされなくなった。';
        }),
        Choice.h('何もいらぬ、会えただけでよいと答える', '何も変わらない。父の思いは胸に残る', () {
          g.j(6);
          g.setFlag('tr_rakuin_declined');
          return '使いが帰って間もなく、父が亡くなったと知らせが来た。あなたの名を呼んでいたという。';
        }),
      ],
      after: next,
    );
  }),
  _tr(
    'tr_rakuin_brother',
    'rakuin',
    19,
    60,
    25,
    (g) =>
        _lay(g) &&
        _rakuinAlive(g) &&
        g.l.lord == _rakuinHouse(g) &&
        g.l.rank < 8,
    (g, next) {
      final l = g.l;
      final house = _rakuinHouse(g)!;
      final hn = '${houseName(g, house)}家';
      g.ask(
        '血を分けた兄',
        '父が亡くなり、正室の子である異母兄が$hnを継いだ。兄はあなたを遠ざけ、家中では「落胤を担いで家を割ろうとする者がいる」とささやかれている。ある夜、兄を快く思わない重臣たちが、あなたのもとへ集まってきた。',
        [
          Choice.h('重臣たちを諫め、兄の前で忠誠を誓う', '家は割れない。兄の疑いが晴れるとは限らない', () {
            _fav(g, 10);
            _net(g, 3);
            g.setFlag('tr_rakuin_loyal');
            g.mark('異母兄が家を継ぐと、担ごうとする重臣を諫め、兄に忠誠を誓った');
            return '兄の前で、守り袋を差し出して頭を下げた。兄は長いこと黙っていたが、やがて守り袋をあなたの手に押し戻し、「父の形見だ、持っていろ」と言った。';
          }),
          Choice.h('重臣たちと結び、家督を奪う', '一国の主になれるかもしれない。しくじれば身の破滅だ', () {
            if (g.rng.chance(.3)) {
              l.rank = 8;
              l.maxRank = 8;
              l.fame += 25;
              g.fa[house]!.power = g.fa[house]!.power * .85;
              g.j(5);
              g.setFlag('tr_rakuin_lord');
              g.mark('重臣たちと結んで異母兄を退け、$hnの家督を奪った');
              return '夜明け前、重臣たちの兵が館を囲んだ。兄は抗わずに寺へ入ると言い、あなたは父の座に座った。家中の三分の一が、その日のうちに国を去った。';
            }
            if (g.rng.chance(.25)) {
              g.die('異母兄から家督を奪おうとして露見し、腹を切らされた', 'seppuku');
              return '企ては前の晩に漏れていた。兄は、あなたに父の墓の前で腹を切ることだけは許した。';
            }
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.fav = 0;
            l.ronin = true;
            _fame(g, -10);
            g.j(-10);
            g.setFlag('tr_rakuin_exiled');
            return '企ては漏れていた。重臣たちは捕らえられ、あなたは守り袋一つを懐に、夜の国境を越えて逃れた。';
          }),
          Choice.h('争いの種にならぬよう、家中を去る', '命と心は穏やかになる。名は捨てることになる', () {
            l.lord = null;
            l.rank = 0;
            l.troops = 0;
            l.ronin = true;
            g.j(3);
            g.setFlag('tr_rakuin_left');
            g.mark('異母兄との争いを避けて、父の家を去った');
            return '兄に暇乞いの文を残し、夜明けに城下を出た。峠で振り返ると、父の城の甍が朝日に光っていた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 正夢: 燃える寺の夢 → 夢のとおりの朝 → 夢を告げるか → 最後の夢
  _tr('tr_yume_fire', 'yume', 15, 50, 16, (g) => true, (g, next) {
    final what = g.rng.pick(['燃える寺', '崩れる石垣', '赤く染まる川']);
    g.setFlag('tr_yume_of:$what');
    g.ask(
      '同じ夢',
      'また、あの夢を見た。$whatの夢だ。幼いころから、同じ夢を見たあとには、必ず何かが起きた。今度の夢は、いつもよりずっと鮮やかで、焦げた匂いまでした。',
      [
        Choice.h('夢の中身を、細かく書き留めておく', '夢を確かめられる。書いた物が人目に触れるかもしれない', () {
          g.setFlag('tr_yume_dreamt');
          g.setFlag('tr_yume_wrote');
          return '夜明け前に起き出し、夢で見たものを一つ残らず書き留めた。書き終えると、手が冷たくなっていた。';
        }),
        Choice.h('ただの夢だと、忘れようとする', '何も変わらない。夢は忘れてくれない', () {
          g.setFlag('tr_yume_dreamt');
          g.j(-2);
          return '井戸の水で顔を洗った。それでも、焦げた匂いは鼻の奥に残っていた。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_yume_morning', 'yume', 16, 60, 25, (g) => true, (g, next) {
    final l = g.l;
    final what = _dream(g);
    g.ask(
      '夢のとおりの朝',
      'その日、夢で見たとおりのことが起きた。$whatの景色を、あなたは人々の後ろから、夢と寸分違わぬ形で見ていた。${g.hasFlag('tr_yume_wrote') ? '書き留めた紙を誰かが見ていたらしく、' : ''}「あの者は、前から知っていた」と、人々がささやき合っている。',
      [
        Choice.h('夢見として、人の頼みを聞くようになる', '頼られ、銭も入る。恐れる者も出てくる', () {
          l.gold += g.rng.range(5, 12);
          _fame(g, 5);
          _net(g, -2);
          g.setFlag('tr_yume_known');
          g.mark('見た夢がそのとおりになり、夢見として人に頼られるようになった');
          return '翌月から、失せ物や縁談の行く末を占ってほしいという者が、戸口に並ぶようになった。';
        }),
        Choice.h('偶然だと言い張り、夢のことは誰にも話さない', '静かに暮らせる。夢はやまない', () {
          g.j(-2);
          g.setFlag('tr_yume_hidden');
          return 'あれは偶然だと笑ってみせた。その夜も、夢を見た。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_yume_tell', 'yume', 18, 70, 25, (g) => g.active, (g, next) {
    final l = g.l;
    final serving = _serving(g);
    final whom = serving ? '殿' : (l.married ? '連れ合い' : '村の庄屋');
    g.ask(
      '夢を告げるか',
      'ゆうべの夢で、$whomが${serving ? '次の戦で、泥の中に倒れていた' : '大水に呑まれていた'}。これまでの夢は、一度も外れたことがない。告げれば、不吉なことを言う者として憎まれるかもしれない。',
      [
        Choice.h('$whomに、夢のことを打ち明ける', '運命を変えられるかもしれない。不吉な口と憎まれるかもしれない', () {
          g.setFlag('tr_yume_told');
          if (g.rng.chance(.6)) {
            if (serving) {
              _fav(g, 12);
              g.mark('夢に見た殿の危うさを打ち明け、殿は戦の陣を改めた');
              return '殿はしばらく黙り、それから陣の置き方を改めた。戦は勝った。殿はあなたを近くに呼び、「次も、見たら言え」と言った。';
            }
            _net(g, 5);
            _fame(g, 3);
            g.mark('夢に見た大水を告げ、人々を高台へ移した');
            return '半信半疑のまま、皆で高台へ移った。三日後、川があふれた。';
          }
          if (serving && g.rng.chance(.08)) {
            g.die('不吉な夢を告げたことを咎められ、腹を切らされた', 'seppuku');
            return '殿は顔色を変え、不吉な口を利く者を家中に置けぬと言った。';
          }
          if (serving) _fav(g, -8);
          _net(g, -3);
          return '笑い飛ばされた。けれど、夢はそのとおりにならなかった。あなたの言葉が、何かを変えたのかもしれない。';
        }),
        Choice.h('黙って、自分にできる備えだけをする', '憎まれはしない。夢は変わらないかもしれない', () {
          g.setFlag('tr_yume_silent');
          g.j(-3);
          if (serving) {
            l.merit += 6;
            return '戦の日、あなたは殿のそばを離れなかった。殿は泥に足を取られたが、あなたが抱え起こした。殿は何も知らないまま、あなたの働きを褒めた。';
          }
          return '大水の前の晩、$whomの家の戸を叩いて、無理に高台へ連れ出した。理由は、最後まで言わなかった。';
        }),
        Choice.h('夢から逃れるように、しばらく遠い国へ旅に出る', '見たくないものを見ずに済む。後で悔やむかもしれない', () {
          g.setFlag('tr_yume_fled');
          _pay(g, 3);
          if (serving) _fav(g, -5);
          g.j(-5);
          return 'ひと月ほど遠い国を歩いた。戻ると、夢のとおりのことが起きていた。';
        }),
      ],
      after: next,
    );
  }),
  _tr('tr_yume_last', 'yume', 50, 90, 25, (g) => true, (g, next) {
    g.ask(
      '最後の夢',
      '久しぶりに、あの夢を見た。今度の夢には、自分がいた。静かな部屋に横たわり、周りで誰かが泣いている。窓の外に、見覚えのある季節の花が咲いていた。',
      [
        Choice.h('残された日々で、会いたい人に会い、言い残すことを書く', '心静かに支度ができる。人には不思議がられる', () {
          g.j(10);
          _net(g, 3);
          g.setFlag('tr_yume_ready');
          g.mark('自分の最期を夢に見て、会いたい人に会い、言い残すことを書き置いた');
          return '世話になった人を一人ずつ訪ね、礼を言って回った。最後に、夢の書き付けを全部焼いた。';
        }),
        Choice.h('夢など、最後くらい外れてみせると笑う', '何も変わらない。それでも、心は軽い', () {
          g.j(6);
          g.setFlag('tr_yume_defied');
          return '夢の花が咲く季節を、あなたは数えなかった。';
        }),
      ],
      after: next,
    );
  }),
];
