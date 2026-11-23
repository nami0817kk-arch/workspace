import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'peace.dart';
import 'rng.dart';
import 'women_life.dart';

/// 泰平の世の暮らし（2026-11-24）。id・旗は `pl_`。
///
/// 人生が亡くなるまで続くようになり、一五六八年生まれなら一六〇一年から五十年ほどを泰平の世で過ごす。
/// その世だけの岐路は `peace.dart` の33（多くは年の決まった出来事と、一六一五年ごろまでの身の振り方）で、
/// 毎年の重点もほぼ乱世のままだったので、**戦のない世の勤め・商い・村・寺・家の暮らし**を足した。
/// どれも**一六〇一年からの、戦の絶えた世（[peaceTime]）にだけ**出る。
///
/// - **重点10**（[peaceLifeFocusOptions]。`adultFocusOptions` がうしろに足す。1年に足すのは [kPeaceLifePerYear] まで）:
///   府へ詰める・役方の勤め・道場・手習い所・新田・廻船・謡と俳諧・講の旅・家訓・縁組と跡の算段。
///   はじめて選んだ年は始めの岐路、2回目からは半分ほどの年に `<id>_again`（`pastimes.dart`・`old_age.dart` と同じ作り）。
///   当てはまるかは乱数を使わずに決め（[peaceLifeTags]）、泰平の世でない年には乱数を使わない。
/// - **岐路**（[kPeaceLifeSceneIds]。一生に一度）: 武家・町人・百姓・僧・女性・忍びと野の者・乱世を知る者。
///   前の段の旗がなければ出ない筋は [kPeaceLifeRoots]。
/// - **世界線**: 徳川の世の定め（参勤・改易・末期養子・本末の帳・寺請）を前提にした岐路は [kPeaceLifeEdoScenes] で、
///   史実どおりの世にだけ出る。ほかは、府の名（[plSeat]: 江戸／小田原で北条が残った世は駿府／西軍の世は大坂／
///   信長の世は安土／明智の世は京）と、上に立つ者の呼び名（[plKogi]: 幕府／公儀）を差し替えて、どの世でも出る。
/// - 死ぬ結果は四つで、どれも数分（かぶき者の喧嘩・敵との立ち合い・火の中の蔵・越訴）。匂わせに危うさを書いてある。
/// - 子の出る場面は、子の記録（`Life.children`）からその歳・性別の子を選び、その名で語る。

/// 泰平の世の暮らしが出はじめる年。
const kPeaceLifeFrom = 1601;

/// 1年に「今年の重点」に足す、泰平の世の重点の数の上限。
const kPeaceLifePerYear = 2;

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;

/// 一六〇一年からの、戦の絶えた世（どの世界線でも。今川の世には無い）。
bool plPeace(Game g) => g.year >= kPeaceLifeFrom && peaceTime(g);

bool _real(Game g) => worldLine(g) == 'real';

/// 天下の府の名（その世の、諸家が屋敷を置く町）。
String plSeat(Game g) => switch (worldLine(g)) {
  'west' => '大坂',
  'nobunaga' => '安土',
  'akechi' => '京',
  _ => g.hasFlag('history_odawara') ? '駿府' : '江戸',
};

/// 上に立つ者の呼び名（史実どおりの世で幕府が開かれてからは「幕府」、ほかは「公儀」）。
String plKogi(Game g) => _real(g) && g.year >= 1603 ? '幕府' : '公儀';

/// 天下を握る家（勢力の内部の名）。
String _rulerKey(Game g) => switch (worldLine(g)) {
  'west' || 'nobunaga' => '織田',
  'akechi' => '明智',
  _ => '松平',
};

/// 年代で書き出しを変える（一六一五年まで／一六三五年まで／それから）。
String _era(Game g, String early, String mid, String late) =>
    g.year < 1616 ? early : (g.year < 1636 ? mid : late);

bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);
bool _monk(Game g) => g.hasFlag('priesthood');
bool _retired(Game g) => g.hasFlag('retired');

/// 主家に仕える、戦える男の侍（位1〜7。隠居でない）。
bool _samurai(Game g) =>
    !g.l.female &&
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    _lordAlive(g) &&
    g.canFight &&
    g.active &&
    !_monk(g);

/// 隠居した元侍（男）。
bool _exBushi(Game g) =>
    !g.l.female && _retired(g) && g.l.maxRank >= 1 && !_monk(g);

/// 身分のない牢人（男）。
bool _ronin(Game g) =>
    !g.l.female &&
    g.l.rank == 0 &&
    g.l.ronin &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw') &&
    !_retired(g);

bool _outlaw(Game g) => g.l.rank == 0 && g.hasFlag('way_outlaw') && !_monk(g);
bool _ninja(Game g) =>
    g.l.rank == 0 &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    (g.l.cls.id == 'ninja' || g.hasFlag('nukenin'));

/// 町の者（商いの道・商家の生まれ。身分なし。牢人・野の道・仏門を除く）。
bool _town(Game g) =>
    g.l.rank == 0 &&
    !g.l.ronin &&
    !_monk(g) &&
    !g.hasFlag('way_outlaw') &&
    (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

/// 村の百姓・浜の者（身分なし。商い・野・仏門でない）。
bool _villager(Game g) =>
    g.l.rank == 0 &&
    (g.l.cls.id == 'farmer' || g.l.cls.id == 'fisher') &&
    !g.l.ronin &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw');

/// 戦場を知る者。
bool _veteran(Game g) => g.hasFlag('first_battle');

void _stamp(Game g, String k) => g.setFlag('$k@${g.year}');

/// [k] の印を付けてからの年（付いていなければ -1）。
int _since(Game g, String k) {
  for (final f in g.l.flags) {
    if (f.startsWith('$k@')) {
      return g.year - (int.tryParse(f.substring(k.length + 1)) ?? g.year);
    }
  }
  return -1;
}

/// 旗 `<k>:<名>` に残した名。
String? _named(Game g, String k) {
  for (final f in g.l.flags) {
    if (f.startsWith('$k:')) return f.substring(k.length + 1);
  }
  return null;
}

void _spouseBond(Game g, int n) {
  final p = g.l.people['伴侶'];
  if (p != null) p.bond = _c100(p.bond + n);
}

String _season(Game g) => g.l.t % 2 == 0
    ? g.rng.pick(['花の頃', '若葉の頃', '梅雨の晴れ間'])
    : g.rng.pick(['稲刈りの済んだ頃', '木枯らしの吹く頃', '初雪の頃']);

/// 回を重ねた年の書き出し（2回目は [second]、以降は [more] から一つ。{季} は時節）。
String _intro(Game g, String tag, String second, List<String> more) =>
    (_n(g, tag) <= 2 ? second : g.rng.pick(more)).replaceAll('{季}', _season(g));

/// 始めの一回がまだなら始めの岐路。済んでいれば、半分ほどの年に小さな岐路。
String? _forcedFor(Game g, String id) {
  if (!g.hasFlag('scene:$id')) return id;
  return g.rng.chance(.5) ? '${id}_again' : null;
}

// ======================================================================
// 重点
// ======================================================================

class _Focus {
  const _Focus(this.tag, this.ok, this.make);
  final String tag;
  final bool Function(Game g) ok;
  final FocusDef Function(Game g) make;
}

/// 謡の稽古の側（位のある男の侍・隠居した元侍）。ほかは俳諧の座。
bool _utai(Game g) => (_samurai(g) && g.l.rank >= 2) || _exBushi(g);

/// 道場を開く側（腕の立つ牢人・隠居した元侍・位のある侍）。ほかは通う側。
bool _dojoTeach(Game g) =>
    g.l.bu >= 55 && (_ronin(g) || _exBushi(g) || (_samurai(g) && g.l.rank >= 2));

/// 縁組を考える年頃の、家にいる子（上の子から）。
Kid? _matchKid(Game g) => g.l.kidAged(g.year, 14, 30);

final _focuses = <_Focus>[
  // ---- 府へ詰める・参府の供（主家に仕える侍）----
  _Focus(
    'pl_tsume',
    (g) => _samurai(g) && g.year >= 1604,
    (g) => FocusDef(
      'pl_tsume',
      g.l.lord == _rulerKey(g) ? '${plSeat(g)}の城の番を勤める' : '${plSeat(g)}の屋敷に詰める',
      '顔が広くなり、覚えも得られる。国元を離れた暮らしは物入りだ',
      (g) {
        g.l.net += g.rng.range(1, 3);
        g.l.merit += g.rng.range(2, 4);
        g.l.fav = _c100(g.l.fav + 1);
        _pay(g, 4);
        g.j(-1);
      },
      forced: _forcedFor(g, 'pl_tsume'),
    ),
  ),
  // ---- 役方の勤め（勘定・普請・町の役所）----
  _Focus(
    'pl_yaku',
    (g) => _samurai(g) && g.l.rank <= 6,
    (g) => FocusDef('pl_yaku', '勘定や普請の役方の勤めに励む', '算盤と帳面で覚えを得る。槍を握る暇は減る', (g) {
      g.l.merit += g.rng.range(3, 6);
      if (g.l.sei < 90 && g.rng.chance(.5)) g.l.sei++;
      g.l.fav = _c100(g.l.fav + g.rng.range(1, 2));
    }, forced: _forcedFor(g, 'pl_yaku')),
  ),
  // ---- 道場を開く／通う ----
  _Focus(
    'pl_dojo',
    (g) =>
        !g.l.female &&
        g.age <= 72 &&
        (_samurai(g) ||
            _ronin(g) ||
            _exBushi(g) ||
            (_town(g) && !_retired(g))),
    (g) => _dojoTeach(g)
        ? FocusDef('pl_dojo', '道場を開き、若い者に稽古をつける', '弟子の束脩で暮らしが立つ。戦場の技が、型になっていく', (g) {
            g.l.gold += g.rng.range(2, 6);
            if (g.rng.chance(.3)) g.l.fame += 1;
            g.l.hp -= 2;
          }, forced: _forcedFor(g, 'pl_dojo'))
        : FocusDef('pl_dojo', '町の道場に通い、木刀を振る', '腕は上がる。月謝と生傷は付いて回る', (g) {
            if (g.rng.chance(.6)) g.l.bu = _c(g.l.bu + 1);
            _pay(g, 2);
            g.l.hp -= 2;
          }, forced: _forcedFor(g, 'pl_dojo')),
  ),
  // ---- 手習い所を開く（字の読める、主を持たぬ人）----
  _Focus(
    'pl_terako',
    (g) =>
        g.l.rank == 0 &&
        g.l.chi >= 50 &&
        !g.hasFlag('way_outlaw') &&
        (_ronin(g) || _monk(g) || _retired(g) || _town(g) || _villager(g)),
    (g) => FocusDef('pl_terako', '手習い所を開き、子らに読み書きを教える', '「お師匠さま」と呼ばれる。束脩はわずかだ', (g) {
      g.l.gold += g.rng.range(1, 4);
      g.l.net += g.rng.range(1, 2);
      g.j(3);
    }, forced: _forcedFor(g, 'pl_terako')),
  ),
  // ---- 新田を拓く（百姓）----
  _Focus(
    'pl_shinden',
    (g) => _villager(g) && g.age <= 65 && !_retired(g),
    (g) => FocusDef('pl_shinden', '村の衆と水を引き、新田を拓く', '田が増えれば暮らしは太る。鍬を振るう体はきしむ', (g) {
      g.l.gold += g.rng.range(2, 7);
      g.l.hp -= 5;
    }, forced: _forcedFor(g, 'pl_shinden')),
  ),
  // ---- 廻船と遠国の商い（商いの道）----
  _Focus(
    'pl_kaisen',
    (g) => _town(g) && g.hasFlag('way_merchant') && !_retired(g),
    (g) => FocusDef('pl_kaisen', '廻船に荷を積み、遠国と商う', '当たれば蔵が建つ。海が荒れれば、荷は戻らない', (g) {
      final gain = g.rng.range(-6, 22) + g.l.sei ~/ 6;
      g.l.gold = g.l.gold + gain < 0 ? 0 : g.l.gold + gain;
    }, forced: _forcedFor(g, 'pl_kaisen')),
  ),
  // ---- 謡の稽古／俳諧の座 ----
  _Focus(
    'pl_haikai',
    (g) =>
        g.year >= 1608 &&
        g.l.chi >= 35 &&
        !g.hasFlag('way_outlaw') &&
        (_utai(g) ||
            _town(g) ||
            (_retired(g) && !_monk(g)) ||
            womanKind(g) == WomanKind.wife),
    (g) => FocusDef(
      'pl_haikai',
      _utai(g) ? '謡と仕舞の稽古に通う' : '俳諧の座に連なる',
      '座の縁が広がる。月謝と付き合いに銭が出る',
      (g) {
        g.l.net += g.rng.range(1, 3);
        _pay(g, 2);
        if (g.rng.chance(.3)) g.l.chi = _c(g.l.chi + 1);
        g.j(4);
      },
      forced: _forcedFor(g, 'pl_haikai'),
    ),
  ),
  // ---- 講の旅（村と町の者）----
  _Focus(
    'pl_ko',
    (g) =>
        g.year >= 1605 &&
        (_villager(g) || _town(g)) &&
        g.age <= 72 &&
        g.l.gold >= 8,
    (g) => FocusDef(
      'pl_ko',
      g.l.female ? '講の仲間と、善光寺へ詣でる' : '講の仲間と、伊勢へ詣でる',
      '一生に一度の旅になる。道中は長く、路銀もかかる',
      (g) {
        _pay(g, 6);
        g.l.hp -= 4;
        g.l.net += 2;
        g.j(8);
      },
      forced: _forcedFor(g, 'pl_ko'),
    ),
  ),
  // ---- 家訓をまとめる（子のいる、家を構えた人）----
  _Focus(
    'pl_kakun',
    (g) =>
        g.age >= 45 &&
        g.l.kids > 0 &&
        g.l.chi >= 40 &&
        !_monk(g) &&
        !g.hasFlag('way_outlaw') &&
        (g.l.rank >= 3 ||
            (_exBushi(g) && g.l.maxRank >= 3) ||
            (_town(g) && g.l.gold >= 50) ||
            g.hasFlag('shoya') ||
            g.hasFlag('pl_yakunin')),
    (g) => FocusDef('pl_kakun', '家訓をしたため、子らに読み聞かせる', '家の行く末の拠り所になる。筆を執ると、己の来し方が問われる', (g) {
      if (g.rng.chance(.4)) g.l.chi = _c(g.l.chi + 1);
      if (g.rng.chance(.3)) g.l.fame += 1;
      g.j(2);
    }, forced: _forcedFor(g, 'pl_kakun')),
  ),
  // ---- 縁組と跡の算段 ----
  _Focus(
    'pl_engumi',
    (g) =>
        g.age >= 40 &&
        !_monk(g) &&
        !g.hasFlag('way_outlaw') &&
        (g.l.rank >= 1 || _town(g) || _villager(g)) &&
        (_matchKid(g) != null ||
            (g.l.kids == 0 &&
                g.l.married &&
                g.age >= 45 &&
                !g.l.people.containsKey('養子'))),
    (g) => FocusDef('pl_engumi', '子らの縁組と、家の跡の算段をする', '家と家の結びつきが先々を決める。支度には銭が要る', (g) {
      g.l.net += g.rng.range(1, 2);
      _pay(g, 2);
    }, forced: _forcedFor(g, 'pl_engumi')),
  ),
];

/// 泰平の世の重点の tag（始めの岐路の id でもあり、`<tag>_again` も持つ）。
const kPeaceLifeFocusTags = [
  'pl_tsume',
  'pl_yaku',
  'pl_dojo',
  'pl_terako',
  'pl_shinden',
  'pl_kaisen',
  'pl_haikai',
  'pl_ko',
  'pl_kakun',
  'pl_engumi',
];

/// 年・身分・道に合う泰平の世の重点の tag（乱数を使わない。テストも使う）。
List<String> peaceLifeTags(Game g) => [
  if (plPeace(g))
    for (final f in _focuses)
      if (f.ok(g)) f.tag,
];

/// その年に出す泰平の世の重点（[kPeaceLifePerYear] まで。多ければその年に出すものを無作為に選び、並びは保つ）。
/// 泰平の世でない年には何も足さず、乱数も使わない。
List<FocusDef> peaceLifeFocusOptions(Game g) {
  if (!plPeace(g)) return const [];
  final cand = [
    for (final f in _focuses)
      if (f.ok(g)) f,
  ];
  if (cand.length > kPeaceLifePerYear) {
    final keep = <int>{};
    while (keep.length < kPeaceLifePerYear) {
      keep.add(g.rng.range(0, cand.length - 1));
    }
    return [
      for (var i = 0; i < cand.length; i++)
        if (keep.contains(i)) cand[i].make(g),
    ];
  }
  return [for (final f in cand) f.make(g)];
}

// ======================================================================
// 筋と出し分けの表
// ======================================================================

/// 筋: 前の段の旗がなければ出ない岐路（id → 要る旗のどれか）。テストも使う。
const kPeaceLifeRoots = <String, List<String>>{
  'pl_kanjo_cho': ['pl_kanjo'],
  'pl_fushin_ba': ['pl_fushin'],
  'pl_kataki_end': ['pl_kataki_tabi'],
  'pl_saishikan': [
    'pc_ronin',
    'pc_ronin_naishoku',
    'pc_ronin_tenarai',
    'pc_ronin_yojinbo',
  ],
  'pl_saiken': ['pl_kaji'],
  'pl_hoko_kaeri': ['pl_hoko_kid'],
  'pl_soba': ['pl_hikyaku'],
  'pl_shinden_kuwa': ['pl_yosui'],
  'pl_ban': ['pc_banshi'],
  'pl_mukashi_nakama': ['pl_katagi'],
};

/// その筋の岐路に要る旗のどれかがあるか（筋でない岐路は真）。テストも使う。
bool plRooted(Game g, String id) {
  final rs = kPeaceLifeRoots[id];
  return rs == null || rs.any(g.hasFlag);
}

/// 徳川の世の定めを前提にした岐路（史実どおりの世にだけ出る）。
const kPeaceLifeEdoScenes = {
  'pl_kaieki',
  'pl_sankin_cost',
  'pl_matsugo',
  'pl_honmatsu',
  'pl_terauke_tsutome',
};

/// 泰平の世の一生に一度の岐路の id（テストが使う）。
const kPeaceLifeSceneIds = [
  // 武家
  'pl_yakugae',
  'pl_kanjo_cho',
  'pl_fushin_ba',
  'pl_rusui',
  'pl_kaieki',
  'pl_kenyaku',
  'pl_sankin_cost',
  'pl_katakiuchi',
  'pl_kataki_end',
  'pl_kabuki',
  'pl_junshi_kin',
  'pl_katoku',
  'pl_matsugo',
  'pl_saishikan',
  // 町人・商人
  'pl_machiwari',
  'pl_nakama',
  'pl_kaji',
  'pl_saiken',
  'pl_hoko_kid',
  'pl_hoko_kaeri',
  'pl_shibai',
  'pl_hikyaku',
  'pl_soba',
  // 百姓
  'pl_kenchi',
  'pl_murauke',
  'pl_yosui',
  'pl_shinden_kuwa',
  'pl_chosan',
  'pl_tenarai',
  'pl_shoya',
  'pl_nengu',
  // 僧
  'pl_honmatsu',
  'pl_terauke_tsutome',
  'pl_tomurai',
  'pl_gakuryo',
  // 女性
  'pl_rusu',
  'pl_okuzutome',
  'pl_enkiri',
  'pl_goke',
  'pl_musume_hoko',
  // 忍び・野の者
  'pl_ban',
  'pl_mushuku',
  'pl_mukashi_nakama',
  // 乱世を知る者
  'pl_gatari',
  'pl_furukizu',
  'pl_teki',
  'pl_bugu',
  'pl_tomadoi',
  'pl_gunki',
];

/// 泰平の世の岐路の重み（`peace.dart` の岐路の倍。泰平の世の年には、乱世のままの岐路よりこちらが先に出る）。
const kPeaceLifeWeight = 80.0;

SceneDef _first(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(id, 15, 100, (g) => 1, plPeace, run, onlyForced: true);

SceneDef _again(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(
      '${id}_again',
      15,
      100,
      (g) => 1,
      plPeace,
      run,
      onlyForced: true,
      repeat: true,
    );

/// 一生に一度の泰平の世の岐路。筋のあるものは [kPeaceLifeRoots] の旗がなければ出ず、
/// [kPeaceLifeEdoScenes] のものは史実どおりの世にだけ出る。
SceneDef _s(
  String id,
  int minAge,
  int maxAge,
  bool Function(Game g) cond,
  void Function(Game g, void Function() next) run, {
  double w = kPeaceLifeWeight,
}) => SceneDef(
  id,
  minAge,
  maxAge,
  (g) => w,
  (g) =>
      plPeace(g) &&
      (!kPeaceLifeEdoScenes.contains(id) || _real(g)) &&
      plRooted(g, id) &&
      cond(g),
  run,
);

List<SceneDef> buildPeaceLifeScenes() => [
  ..._focusScenes(),
  ..._bukeScenes(),
  ..._townScenes(),
  ..._villageScenes(),
  ..._templeScenes(),
  ..._womenScenes(),
  ..._shadowScenes(),
  ..._veteranScenes(),
];

// ======================================================================
// 重点の岐路（始めの一回と、回を重ねた年）
// ======================================================================

List<SceneDef> _focusScenes() => [
  // ==================================================================
  // 府へ詰める
  // ==================================================================
  _first('pl_tsume', (g, next) {
    final l = g.l;
    final seat = plSeat(g);
    g.ask(
      '勤番',
      'はじめて、勤めで$seatへ上った。'
          '${_era(g, '町はどこも普請の槌音ばかりで、諸家の屋敷が競うように建っていく。', '町は見違えるほど広がり、諸家の屋敷が軒を連ねている。', '町は人であふれ、国元の城下がひなびて見える。')}'
          '長屋の一間に荷を解くと、古参が耳打ちした。「ここでは、槍より付き合いだ」。',
      [
        Choice.h('他家の者と付き合い、噂を拾う', '耳が早くなる。酒代は己の懐から出る', () {
          l.net = _c(l.net + 5);
          _pay(g, 4);
          g.setFlag('pl_tsume_mimi');
          return '湯屋と茶店で、他家の勤番と顔なじみになった。どの家が普請を命じられ、どの家の跡目が揉めているか。国元にいては聞こえぬ話ばかりだった。';
        }),
        Choice.h('門の外へは出ず、勤めに徹する', '堅い男と覚えられる。$seatの町は、塀の向こうのままだ', () {
          l.fav = _c100(l.fav + 6);
          l.merit += 4;
          g.setFlag('pl_tsume_katai');
          return '門番、火の番、使い番。言い付かった勤めを、一日も欠かさなかった。帰国の折、組頭が殿にその名を挙げた。';
        }),
        Choice.h('非番の日に、町を見て歩く', '見聞は広がる。見るもの聞くもの、銭がかかる', () {
          _pay(g, 5);
          l.chi = _c(l.chi + 1);
          g.j(6);
          g.setFlag('pl_tsume_seen');
          g.mark('勤番で$seatへ上り、新しい町を見て歩いた');
          return '橋のたもとの市、河岸に並ぶ蔵、辻の見世物。国元への土産話は、一晩では語りきれなかった。';
        }),
        if (l.mi >= 60)
          Choice.h('他家の留守居の寄り合いに、顔を出させてもらう', '人好きのする者なら、輪に入れる。分をわきまえぬと見られることもある', () {
            l.net = _c(l.net + 8);
            l.fame += 2;
            l.merit += 3;
            g.setFlag('pl_tsume_mimi');
            return '末席で酌をして回るうち、古株の留守居たちに名を覚えられた。「あの家の若いのは、話が分かる」。その一言が、のちのち家の役に立った。';
          }, via: '魅'),
      ],
      after: next,
    );
  }),
  _again('pl_tsume', (g, next) {
    final l = g.l;
    final seat = plSeat(g);
    final head = _intro(g, 'pl_tsume', 'また$seatへ上った。', [
      '{季}、$seatの長屋に荷を解いた。',
      '$seatの勤めにも、すっかり慣れた。',
      '長屋の壁の染みまで、もう見覚えがある。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('勤番', '$head国元から文が届いた。家の者が、病で寝付いたという。', [
        Choice.h('暇を願い出て、国元へ帰る', '家の者は心強い。勤めを途中で抜けた者として、名が残る', () {
          l.fav = _c100(l.fav - 3);
          g.j(4);
          _spouseBond(g, 6);
          return '組頭は渋い顔で暇をくれた。夜を日に継いで街道を下り、枕元に座ったときには、熱はもう引きはじめていた。';
        }),
        Choice.h('薬代を送り、勤めを続ける', '勤めに穴は開かない。文を待つ日が続く', () {
          _pay(g, 4);
          l.merit += 3;
          g.j(-2);
          return '飛脚に薬代を託した。次の文が届くまで、ひと月かかった。持ち直したと読んで、ようやく飯の味がした。';
        }),
      ], after: next);
      return;
    }
    g.ask('勤番', '$head火の番の夜、塀の向こうの屋敷から火の手が上がった。他家の屋敷だ。持ち場を離れれば、咎めを受けるかもしれない。', [
      Choice.h('手桶を持って、駆けつける', '火は隣へ移るものだ。持ち場を空けた咎めは、あとで考える', () {
        l.fame += 2;
        l.net = _c(l.net + 3);
        l.hp -= 4;
        return '塀を越えて水を運び、小屋ひとつで火を食い止めた。翌朝、その家の留守居が、角樽を提げて礼に来た。';
      }),
      Choice.h('持ち場を守り、屋敷の者を起こして回る', '勤めの筋は通る。向こうの火は、向こうの者に任せる', () {
        l.merit += 3;
        l.fav = _c100(l.fav + 2);
        return '屋根に水を打たせ、荷を庭に出させた。火の粉は幾度も飛んできたが、こちらの屋敷は瓦一枚焦げなかった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 役方の勤め
  // ==================================================================
  _first('pl_yaku', (g, next) {
    final l = g.l;
    g.ask(
      '役方の勤め',
      '役所の板の間に、帳面が山と積まれている。'
          '${_era(g, '戦のあいだ後回しにされてきた蔵と年貢の勘定が、一度に押し寄せた。', '家中の出世は、槍先から筆先へ移ったと、誰もが言う。', '役所には、戦を知らぬ若い者ばかりが机を並べている。')}'
          '上役が、手を付ける仕事を選べと言う。',
      [
        Choice.h('蔵米の出入りを洗い直す', '家の台所が見えてくる。合わぬ数に、夜なべが続く', () {
          l.merit += 6;
          if (l.sei < 90) l.sei++;
          l.hp -= 3;
          g.setFlag('pl_yaku_kura');
          return '俵の数と帳面の数を、蔵ごとに突き合わせた。鼠と湿気と、数え違い。合わぬ訳が一つずつ分かるたび、家の台所の姿が見えてきた。';
        }),
        Choice.h('城下の橋と道の普請を見回る', '足で稼ぐ勤めだ。町と村の者に、顔を覚えられる', () {
          l.merit += 4;
          l.net = _c(l.net + 4);
          l.hp -= 2;
          g.setFlag('pl_yaku_michi');
          return '朽ちた橋板、崩れた路肩、詰まった溝。書き上げて回るうち、どこの村の誰が話の分かる男か、頭に入った。';
        }),
        Choice.h('古い証文を整理し、境の争いに備える', '地味な仕事だ。いざというとき、家を救うのは紙になる', () {
          l.merit += 4;
          l.chi = _c(l.chi + 1);
          g.setFlag('pl_yaku_shomon');
          return '虫の食った安堵状や売券を、年ごとに綴じ直した。戦の世なら槍で決めた境を、これからは紙で争うのだ。';
        }),
        if (l.sei >= 60)
          Choice.h('役所の手順そのものを改める書付を出す', '通れば、家中の勤めが変わる。古参の顔を潰すことにもなる', () {
            l.merit += 10;
            l.fav = _c100(l.fav + 5);
            l.net = _c(l.net - 2);
            g.setFlag('pl_yaku_aratame');
            g.mark('役所の勤めの手順を改める書付を出し、家中に用いられた');
            return '誰が受け、誰が改め、誰が判を押すか。一枚の書付にまとめて差し出すと、家老はしばらく黙って読み、「明日からこれでやれ」と言った。';
          }, via: '政'),
      ],
      after: next,
    );
  }),
  _again('pl_yaku', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_yaku', '今年も役所に詰めた。', [
      '{季}、役所の机に向かった。',
      '帳面の山は、今年も減らない。',
      '算盤の珠の音にも、耳が慣れた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('役方の勤め', '$head年の瀬の勘定が、どうしても合わない。差は、わずかだ。', [
        Choice.h('合うまで、幾晩でも突き合わせる', '筋は通る。目と肩がもたない', () {
          l.hp -= 5;
          l.merit += 4;
          return '三晩めの明け方、写し違いの一行を見つけた。墨を入れ直し、ようやく筆を置いた。';
        }),
        Choice.h('合わぬまま、訳を添えて上役に出す', '正直ではある。詰めの甘い者と見られるかもしれない', () {
          l.fav = _c100(l.fav + (g.rng.chance(.5) ? 2 : -2));
          return '「合わぬものを合ったと書くよりは良い」。上役はそう言って、帳面を受け取った。その顔色までは読めなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('役方の勤め', '$head村から、願い書が届いた。書式が違い、宛名も違う。それでも、切羽詰まった様子は読み取れる。', [
      Choice.h('書き直しを手伝い、上へ取り次ぐ', '村は助かる。そこまでするのは、役目の外だ', () {
        l.net = _c(l.net + 4);
        l.fame += 1;
        return '庄屋を呼び、宛名と書き出しを教えた。書き直された願い書は、次の評定に間に合った。';
      }),
      Choice.h('定めどおり、差し戻す', '落ち度はない。村の願いは、ひと月遅れる', () {
        l.merit += 2;
        return '「書式が整わねば、受けられぬ」。使いの百姓は、黙って願い書を懐に戻した。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 道場
  // ==================================================================
  _first('pl_dojo', (g, next) {
    final l = g.l;
    if (_dojoTeach(g)) {
      g.ask(
        '道場',
        '土間に板を張り、看板を掲げた。'
            '${_era(g, '戦が絶えて、腕に覚えのある者が町にあふれている。', '近ごろは、戦場を知らぬ師範の道場のほうが、門弟が多いという。', '剣術は、いまや侍のたしなみの一つになった。流儀の名と免状が物を言う。')}'
            '最初の弟子入りは、三人。何を教えるか。',
        [
          Choice.h('戦場で役に立つ技だけを教える', '本物ではある。板の間の稽古には、荒すぎる', () {
            l.fame += 2;
            g.setFlag('pl_dojo_jitsu');
            g.mark('道場を開き、戦場で身に付けた技を若い者に教えた');
            return '組み討ち、足払い、倒れた相手への止め。弟子の一人は三日で来なくなった。残った二人は、目の色が変わった。';
          }),
          Choice.h('型と礼を重んじて教える', '弟子は増える。戦場の技とは、別のものになっていく', () {
            l.gold += g.rng.range(5, 10);
            l.net = _c(l.net + 3);
            g.setFlag('pl_dojo_kata');
            return '礼に始まり礼に終わる稽古は、親たちに評判が良かった。春には、板の間が手狭になった。';
          }),
          Choice.h('町人や百姓の子も、分け隔てなく入れる', '門弟は増える。侍の弟子は、嫌がるかもしれない', () {
            l.net = _c(l.net + 6);
            l.fame += 1;
            g.setFlag('pl_dojo_open');
            g.mark('道場を開き、町人や百姓の子にも分け隔てなく教えた');
            return '魚屋の倅と足軽の子が、同じ板の間で木刀を合わせた。眉をひそめて去る者もいたが、稽古の声は倍になった。';
          }),
        ],
        after: next,
      );
      return;
    }
    g.ask(
      '道場',
      '町に道場ができた。${_era(g, '師範は、どこかの家を牢人した男だという。', '戦場を知らぬ若い師範が、板の間で型を教えている。', '免状を出す流儀の道場で、月謝も安くない。')}'
          '${_veteran(g) ? '戦場で覚えた我流の腕が、板の間でどこまで通じるか。' : '木刀を握るのは、久しぶりだ。'}',
      [
        Choice.h('一から型を習う', '体に染みた癖を直すのは、骨が折れる', () {
          l.bu = _c(l.bu + 2);
          l.hp -= 3;
          g.setFlag('pl_dojo_manabi');
          return '足の運びから直された。ひと月、素振りだけをさせられた。それでも、木刀の先がぶれなくなった。';
        }),
        Choice.h('師範に、一本立ち合いを願う', '腕のほどが知れる。打たれれば、痛いだけでは済まない', () {
          if (g.rng.chance(.3 + l.bu / 200)) {
            l.fame += 2;
            l.bu = _c(l.bu + 1);
            g.setFlag('pl_dojo_ippon');
            return '型を捨てて踏み込んだ一本が、師範の小手を打った。板の間が静まり、師範は笑って木刀を引いた。「どこで覚えた」。';
          }
          l.hp -= 8;
          l.bu = _c(l.bu + 1);
          return '打ち込んだ木刀は空を切り、次の瞬間、胴を抜かれて板の間に転がっていた。息が戻るまで、しばらくかかった。';
        }),
        Choice.h('稽古のあとの付き合いを楽しむ', '腕はさほど上がらない。顔なじみは増える', () {
          l.net = _c(l.net + 5);
          g.j(4);
          return '稽古のあと、井戸端で汗を拭きながら話し込んだ。身分も生業も違う者たちと、同じ湯屋へ流れた。';
        }),
      ],
      after: next,
    );
  }),
  _again('pl_dojo', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_dojo', 'また道場の板の間に立った。', [
      '{季}、道場の板の間に立った。',
      '板の間の節の位置まで、足が覚えている。',
      '道場の若い者の顔ぶれが、また少し変わった。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('道場', '$head他流の男が、立ち合いを求めて訪ねてきた。旅の埃にまみれ、目だけが光っている。', [
        Choice.h('立ち合いを受ける', '道場の名は上がるか、地に落ちるかだ', () {
          if (g.rng.chance(.35 + l.bu / 200)) {
            l.fame += 3;
            return '三本のうち二本を取った。男は深く礼をして、草鞋を履いた。門弟たちの背筋が、少し伸びた。';
          }
          l.hp -= 8;
          l.fame -= 1;
          return '二本続けて取られた。男は礼をして去り、板の間には気まずい静けさが残った。';
        }),
        Choice.h('茶を出し、路銀を包んで帰す', '怪我人は出ない。逃げたと言いふらされるかもしれない', () {
          _pay(g, 3);
          l.net = _c(l.net + 1);
          return '男は包みを受け取り、茶を一口で飲み干して出ていった。腹を空かせていただけかもしれない。';
        }),
      ], after: next);
      return;
    }
    g.ask('道場', '$head道場の若い者が、町で喧嘩をして刀に手を掛けたという。相手の親が、怒鳴り込んできた。', [
      Choice.h('共に頭を下げ、若い者をかばう', '若い者は恩に着る。道場の評判には傷が付く', () {
        l.net = _c(l.net + 4);
        l.fame -= 1;
        return '板の間に手を突いて詫びた。その夜、若い者は黙って道場の雑巾がけをしていた。';
      }),
      Choice.h('道場への出入りを差し止める', '筋は通る。行き場をなくした若い者が、どこへ流れるか', () {
        l.fame += 1;
        g.j(-2);
        return '「抜く気で柄に手を掛ける者に、教える技はない」。若い者は木刀を置いて出ていった。その後の噂は、良いものではなかった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 手習い所
  // ==================================================================
  _first('pl_terako', (g, next) {
    final l = g.l;
    g.ask(
      '手習い所',
      '${_monk(g) ? '寺の庫裏の一間' : '家の一間'}に、机を並べた。'
          '${_era(g, '字の読める者は、まだこのあたりに数えるほどしかいない。', '触れも年貢の割付も、近ごろはみな書付で回ってくる。字が読めねば、損をする世だ。', 'いまでは、どの町にも手習いの師匠がいる。')}'
          '集まった子らに、何から教えるか。',
      [
        Choice.h('いろはと、己の名の書き方から', '誰でも付いてこられる。先へ進みたい子は、退屈する', () {
          l.net = _c(l.net + 4);
          g.j(4);
          g.setFlag('pl_terako_iroha');
          return '筆の持ち方から教えた。墨だらけの手で、己の名を初めて書けた子が、紙を持って家へ走っていった。';
        }),
        Choice.h('証文の読み方と、算盤を', '親は喜ぶ。子らには、いささか難しい', () {
          l.gold += g.rng.range(3, 7);
          l.fame += 1;
          g.setFlag('pl_terako_soroban');
          g.mark('手習い所を開き、子らに証文の読み方と算盤を教えた');
          return '借用の証文、年貢の請取、売り買いの覚え。手本はすべて、暮らしに出てくる書付にした。束脩を弾む親が増えた。';
        }),
        Choice.h('女の子も、同じ机に座らせる', '通う子は増える。眉をひそめる親もいる', () {
          l.net = _c(l.net + 5);
          l.fame += 1;
          g.setFlag('pl_terako_girls');
          g.mark('手習い所を開き、女の子にも同じ机で読み書きを教えた');
          return '「女に字など」と言う親には、「帳面の付けられる嫁は、どこでも重宝される」と答えた。机の半分が、女の子で埋まった。';
        }),
        if (l.chi >= 70)
          Choice.h('手本を、己で書き下ろす', '土地の名と暮らしを織り込んだ手本になる。筆を執る夜が続く', () {
            l.fame += 3;
            l.hp -= 3;
            g.setFlag('pl_terako_tehon');
            g.mark('子らのために、土地の名と暮らしを織り込んだ手習いの手本を書いた');
            return '村々の名、川の名、月ごとの野良仕事。子らの知っている言葉だけで綴った手本は、やがて隣の村の師匠にも写されていった。';
          }, via: '知'),
      ],
      after: next,
    );
  }),
  _again('pl_terako', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_terako', '今年も机を並べた。', [
      '{季}、子らの声が戻ってきた。',
      '机の落書きが、また増えている。',
      'はじめの頃の子が、もう弟や妹を連れてくる。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('手習い所', '$head束脩を持ってこられなくなった子がいる。親が寝付いたらしい。戸口で、入ろうか帰ろうか迷っている。', [
        Choice.h('黙って机に座らせる', '子は通い続けられる。ほかの親に知れれば、うちもと言われる', () {
          g.j(4);
          l.net = _c(l.net + 2);
          return '「墨をするのを手伝え」とだけ言った。子は誰より早く来て、誰より丁寧に墨をするようになった。';
        }),
        Choice.h('畑のものでよいと、親に伝える', '筋は立つ。親の気が、かえって重くなるかもしれない', () {
          l.gold += 1;
          l.net = _c(l.net + 1);
          return '次の朝、戸口に大根が三本置いてあった。子は、何食わぬ顔で机に座っていた。';
        }),
      ], after: next);
      return;
    }
    g.ask('手習い所', '$head手に負えぬ子が一人いる。机に落書きをし、隣の子の草紙に墨を塗り、叱ると逃げる。', [
      Choice.h('厳しく叱り、居残りをさせる', 'ほかの子への示しは付く。その子は、来なくなるかもしれない', () {
        l.fame += 1;
        g.j(-1);
        return '日の暮れるまで、いろはを百ぺん書かせた。次の日、その子は来た。むくれた顔で、いちばん後ろに座った。';
      }),
      Choice.h('その子の得手を探してやる', '手間はかかる。化ければ、いちばんの弟子になる', () {
        l.net = _c(l.net + 3);
        g.j(3);
        return '落書きの馬が、妙に上手かった。絵手本を写させてみると、半日、筆を離さなかった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 新田
  // ==================================================================
  _first('pl_shinden', (g, next) {
    final l = g.l;
    g.ask(
      '新田',
      '${plKogi(g)}の触れが回ってきた。荒れ地を拓いた者には、数年のあいだ年貢を免ずるという。'
          '${_era(g, '戦のあいだ打ち捨てられた田が、まだあちこちに葦を生やしている。', '拓きやすい土地は、もうあらかた田になった。残るのは、水の来ぬ原か、水の引かぬ沼だ。', '近ごろは、町の商人が銭を出して、沼や干潟を丸ごと田に変える話まで聞く。')}'
          'どこに鍬を入れるか。',
      [
        Choice.h('川べりの葦原を拓く', '水には困らない。大水の年には、すべて流される', () {
          l.gold += g.rng.range(4, 9);
          l.hp -= 4;
          g.setFlag('pl_shinden_kawa');
          g.mark('川べりの葦原を拓き、新田にした');
          return '葦の根は、鍬を三本だめにした。それでも秋には、黒い泥から、見たこともないほど太い穂が出た。';
        }),
        Choice.h('山裾の原を拓く', '水が遠い。実りは薄いが、流されることはない', () {
          l.gold += g.rng.range(2, 5);
          l.hp -= 5;
          g.setFlag('pl_shinden_yama');
          return '石を拾い、樋を継いで沢の水を引いた。小さな田が五枚。大水の年も、ここだけは実った。';
        }),
        Choice.h('村の入会の野に、手を付ける', '近くて拓きやすい。秣や薪を取ってきた家々が、黙っていない', () {
          l.gold += g.rng.range(4, 8);
          l.net = _c(l.net - 5);
          g.setFlag('pl_shinden_iriai');
          return '田にはなった。寄り合いでは、馬の草をどこで刈ればよいのかと、年寄りに詰め寄られた。';
        }),
        if (l.un >= 60)
          Choice.h('古老の言う「昔、田だった所」を掘ってみる', '言い伝えが真なら、畦も水路も土の下にある。ただの藪かもしれない', () {
            if (g.luck()) {
              l.gold += g.rng.range(8, 14);
              g.setFlag('pl_shinden_furuta');
              g.mark('言い伝えを頼りに藪を掘り、埋もれていた古い田を起こした');
              return '藪を払うと、石で組んだ古い水口が出てきた。いつの世の誰が拓いた田か、もう誰も知らない。水を落とすと、昔のとおりに流れた。';
            }
            l.hp -= 4;
            return '掘っても掘っても、木の根と石ばかりだった。古老は「はて、もう一つ向こうの谷だったか」と首をひねった。';
          }, via: '運'),
      ],
      after: next,
    );
  }),
  _again('pl_shinden', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_shinden', '今年も新田に鍬を入れた。', [
      '{季}、新田の畦に立った。',
      '拓いた田の土が、年ごとに黒くなってきた。',
      '新田の向こうに、また誰かが鍬を入れはじめた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('新田', '$head拓いた田が、まずまずの実りを付けた。手元に、わずかな余りが出る。', [
        Choice.h('手伝ってくれた者たちに、酒と餅を振る舞う', '来年も人手に困らない。余りは、それで消える', () {
          l.net = _c(l.net + 5);
          g.j(4);
          return '畦に筵を敷き、皆で餅をついた。泥だらけの顔が、どれも笑っていた。';
        }),
        Choice.h('種籾と肥やしを買い足す', '来年の実りに回る。今年の楽しみはない', () {
          l.gold += g.rng.range(2, 5);
          return '干鰯を一俵、種籾を二升。納屋の隅に積んで、来年の春を待った。';
        }),
      ], after: next);
      return;
    }
    g.ask('新田', '$head年貢を免じられる年季が明け、役人が縄を持って新田にやって来た。', [
      Choice.h('ありのままに測らせる', '咎めはない。年貢は、今年から掛かる', () {
        _pay(g, 3);
        l.fame += 1;
        return '竿が当てられ、帳に付けられた。己の拓いた田が、初めて村の石高に数えられた。';
      }),
      Choice.h('畦を寄せて、狭く見せる', '年貢は軽くなる。見破られれば、過料だ', () {
        if (g.rng.chance(.7)) {
          l.gold += 4;
          return '役人は畦の新しさに目を留めたが、何も言わずに竿を進めた。';
        }
        _pay(g, 8);
        l.fame -= 1;
        return '「この畦は、昨日今日のものだな」。竿の先で崩され、過料を言い渡された。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 廻船
  // ==================================================================
  _first('pl_kaisen', (g, next) {
    final l = g.l;
    g.ask(
      '廻船',
      '${_era(g, '戦が絶え、湊ごとの関銭も海賊も消えた。荷は、海を行くほうが安くて速い。', '上方から${plSeat(g) == '大坂' ? '東国' : plSeat(g)}へ、木綿や油や酒を積んだ船が行き交っている。', '北国の米を、西の海を回して上方へ運ぶ船があると伝わる。')}'
          '船問屋が、何を積むかと尋ねる。',
      [
        Choice.h('米と塩を積む', 'どこでも売れる。利は薄い', () {
          l.gold += g.rng.range(6, 12);
          g.setFlag('pl_kaisen_kome');
          return '俵は無事に着き、値どおりに売れた。驚くような儲けはないが、帳面は黒い。';
        }),
        Choice.h('木綿と古手と油を積む', '利は大きい。品の目利きができねば、掴まされる', () {
          if (g.rng.chance(.35 + l.chi / 150)) {
            l.gold += g.rng.range(15, 28);
            g.setFlag('pl_kaisen_momen');
            g.mark('廻船に木綿と油を積み、遠国との商いで身代を太らせた');
            return '麻しか知らなかった土地で、木綿は飛ぶように売れた。帰りの船には、その土地の紅花を積んだ。';
          }
          _pay(g, 8);
          return '古手の俵の中ほどは、虫食いだらけだった。上だけ良い品を並べる手口に、まんまと掛かった。';
        }),
        Choice.h('船を一艘、己の持ち船にする', '運び賃を払う側から、取る側に回る。沈めば、すべて己の損だ', () {
          if (l.gold < 60) {
            g.j(-1);
            return '船大工の言い値を聞いて、黙って帰ってきた。今の身代では、帆柱一本がやっとだ。';
          }
          l.gold -= 60;
          l.fame += 3;
          g.setFlag('pl_funamochi');
          g.mark('廻船を一艘持ち、船持ちの商人になった');
          return '船おろしの日、舳先に酒を注いだ。己の屋号を染めた帆が、湊の風をはらんだ。';
        }),
        if (l.un >= 60)
          Choice.h('荒れる季節の初荷に賭ける', 'ほかの船が出ぬうちに着けば、言い値で売れる。海は、気まぐれだ', () {
            if (g.luck(.3)) {
              l.gold += g.rng.range(25, 40);
              g.setFlag('pl_kaisen_hatsuni');
              return '三日続いた西風が、船出の朝だけ凪いだ。湊に入ったのは、この船一艘。荷は、桟橋の上で売り切れた。';
            }
            _pay(g, 12);
            return '船は途中の湊で十日も風待ちをした。着いたときには、ほかの船も入っていて、値は崩れていた。';
          }, via: '運'),
      ],
      after: next,
    );
  }),
  _again('pl_kaisen', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_kaisen', '今年も船に荷を積んだ。', [
      '{季}、湊に荷を出した。',
      '船問屋の番頭とも、すっかり顔なじみだ。',
      '帆の向こうの空を読むのが、癖になった。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('廻船', '$head荷を積んだ船が、沖で時化に遭った。荷の半分を海へ捨てて、どうにか湊へ逃げ込んだという。捨てられたのは、ほかの荷主の荷だ。', [
        Choice.h('損を、荷主みなで分け合う', '助かった荷も、捨てた荷のおかげだ。こちらの懐は痛む', () {
          _pay(g, 6);
          l.net = _c(l.net + 5);
          l.fame += 1;
          return '助かった荷の値に応じて、損を割った。捨てられた荷の主は、何も言わずに頭を下げた。';
        }),
        Choice.h('己の荷は無事だったと、口をつぐむ', '損はない。次に捨てられるのが己の荷でも、文句は言えない', () {
          l.gold += 4;
          l.net = _c(l.net - 3);
          return '荷は無事に売れた。船問屋の座敷で、誰もこちらの顔を見なかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('廻船', '$head船が着いてみると、その品の値が崩れていた。ほかの船も、同じ品を積んできたらしい。', [
      Choice.h('損を承知で、売り切る', '傷は浅い。儲けは消える', () {
        _pay(g, 3);
        return '言い値の七分で、すべて売った。空になった船に、帰りの荷を積ませた。';
      }),
      Choice.h('蔵を借りて、値が戻るのを待つ', '戻れば儲かる。戻らねば、蔵賃のぶんだけ損が増える', () {
        if (g.rng.chance(.5)) {
          l.gold += g.rng.range(6, 12);
          return 'ふた月待つと、品薄になって値が戻った。蔵の戸を開けた日に、買い手が列をなした。';
        }
        _pay(g, 7);
        return '値は戻らなかった。蔵賃を払い、結局は七分で売った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 謡の稽古／俳諧の座
  // ==================================================================
  _first('pl_haikai', (g, next) {
    final l = g.l;
    if (_utai(g)) {
      g.ask('謡の稽古', '殿が能を好まれるので、家中に謡が流行っている。祝いの席で一節も謡えぬ者は、肩身が狭い。戦場で喉を嗄らした声が、節に乗るものかどうか。', [
        Choice.h('師匠について、一から習う', '時はかかる。座の付き合いが変わる', () {
          l.mi = _c(l.mi + 1);
          l.fav = _c100(l.fav + 3);
          g.setFlag('pl_utai');
          return '「腹から声を出すのは、陣中と同じでござる」。師匠にそう言われてから、節が少し据わった。';
        }),
        Choice.h('祝言の小謡だけ、覚えておく', '恥はかかずに済む。それより先へは進まない', () {
          l.net = _c(l.net + 2);
          return '「高砂」の一節だけを、行き帰りの道で繰り返した。婚礼の席では、どうにか役目を果たした。';
        }),
        Choice.h('鼓も合わせて習う', '囃子の座に入れる。道具も月謝も、高い', () {
          _pay(g, 8);
          l.net = _c(l.net + 5);
          g.setFlag('pl_utai');
          g.setFlag('pl_tsuzumi');
          return '鼓の皮を湿し、調べを締める。打つ手の形が決まるまで、半年かかった。囃子の座では、身分の上下が少しだけ緩む。';
        }),
        if (l.mi >= 60)
          Choice.h('祝いの席で、進んで一番を謡う', '声と度胸があれば、殿の目に留まる。外せば、物笑いだ', () {
            l.fav = _c100(l.fav + 6);
            l.fame += 2;
            g.setFlag('pl_utai');
            g.mark('祝いの席で謡を披露し、殿の目に留まった');
            return '座が静まり、声だけが梁に響いた。謡い終えると、上座から扇が下された。';
          }, via: '魅'),
      ], after: next);
      return;
    }
    g.ask(
      '俳諧の座',
      '古い連歌よりくだけた、俳諧という遊びが流行っている。俗な言葉も、洒落も、句にしてよいのだという。'
          '${g.year >= 1633 ? '京の名のある師匠の流れを汲むという点者が、この町にも来ている。' : ''}'
          '月に一度の座に、誘われた。',
      [
        Choice.h('点者に、句を見てもらう', '筋は良くなる。添削で、己の句が跡形もなくなる', () {
          l.chi = _c(l.chi + 1);
          _pay(g, 2);
          g.setFlag('pl_haikai_ten');
          return '十句出して、丸が付いたのは一句。それも、下の五文字を直されていた。それでも、その一句を幾度も口の中で転がした。';
        }),
        Choice.h('仲間と気楽に、句を付け合う', '顔なじみが増える。句は、上手くはならない', () {
          l.net = _c(l.net + 5);
          g.j(4);
          g.setFlag('pl_haikai_za');
          return '酒が回るにつれ、句は怪しくなった。誰かの駄洒落に、座がどっと沸いた。身分も生業も、この座では言いっこなしだ。';
        }),
        Choice.h('銭を出して、板行の集に句を載せてもらう', '名が紙に残る。句の出来は、銭では買えない', () {
          _pay(g, 10);
          l.fame += 2;
          g.setFlag('pl_haikai_nyushu');
          g.mark('俳諧の集に、己の句を載せた');
          return '刷り上がった集の、終わり近くに己の名があった。国の名と、たった一句。それを、幾度も開いて眺めた。';
        }),
        if (l.chi >= 60)
          Choice.h('座の発句を、買って出る', '座を引っ張る役だ。滑れば、一晩じゅう気まずい', () {
            l.fame += 3;
            l.net = _c(l.net + 4);
            g.setFlag('pl_haikai_hokku');
            g.mark('俳諧の座で発句を詠み、一座をうならせた');
            return '季の言葉に、町の誰もが知る出来事を掛けた。一拍おいて、座が膝を打った。点者が、懐紙にそれを書き留めた。';
          }, via: '知'),
      ],
      after: next,
    );
  }),
  _again('pl_haikai', (g, next) {
    final l = g.l;
    final what = _utai(g) ? '稽古' : '座';
    final head = _intro(g, 'pl_haikai', 'また$whatに出た。', [
      '{季}、$whatに出た。',
      '$whatの顔ぶれにも、すっかり馴染んだ。',
      '$whatの帰り道は、いつも足が軽い。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask(_utai(g) ? '謡の稽古' : '俳諧の座', '$head${_utai(g) ? '同じ師匠のもとに、大店の主が通っている。稽古の順は、身分ではなく入門の順だという。その男が、先だ。' : '座に、隠居した侍が加わった。上座を空けるべきかどうか、皆が顔を見合わせている。'}', [
        Choice.h('ここでは身分を言わぬものと、同じ席に着く', '座の習いには適う。外で、何と言われるか', () {
          l.net = _c(l.net + 4);
          g.j(2);
          return '並んで座り、同じ手本を覗き込んだ。帰りがけ、互いに会釈をして、別々の道へ分かれた。';
        }),
        Choice.h('世の習いどおり、席の上下を付ける', '角は立たない。座の空気は、少し固くなる', () {
          l.fame += 1;
          g.j(-1);
          return '席は改められた。その晩は、誰もが行儀よく、誰も笑わなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask(_utai(g) ? '謡の稽古' : '俳諧の座', '$head${_utai(g) ? '寺の勧進の舞台で、一番舞わぬかと声が掛かった。' : '寺に奉納する句の額に、名を連ねぬかと声が掛かった。'}', [
      Choice.h('引き受ける', '晴れの場だ。しくじれば、長く語り草になる', () {
        if (g.rng.chance(.7)) {
          l.fame += 2;
          g.j(4);
          return _utai(g) ? '舞い納めて橋掛かりを戻るとき、見所のどよめきが背に届いた。' : '堂の長押に額が掛かった。己の句を、参る者が声に出して読んでいく。';
        }
        l.fame -= 1;
        g.j(-2);
        return _utai(g) ? '途中で詞を忘れ、地謡に助けられた。しばらくは、その話ばかりされた。' : '額が掛かってから、季の言葉を取り違えていたと気づいた。もう、直しようがない。';
      }),
      Choice.h('まだその器ではないと、辞退する', '恥はかかない。次に声が掛かるとは限らない', () {
        g.j(1);
        return '「いずれ、また」と頭を下げた。その日は、見る側に回った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 講の旅
  // ==================================================================
  _first('pl_ko', (g, next) {
    final l = g.l;
    final dest = l.female ? '善光寺' : '伊勢';
    g.ask(
      '講の旅',
      '${_town(g) ? '町' : '村'}の講で籤を引き、今年の代参に当たった。皆が少しずつ積んだ銭を預かって、$destへ詣でる。'
          '${_era(g, '街道に野盗が出なくなり、関銭も取られなくなった。', '街道には宿場と一里塚が整い、女子どもでも旅ができるようになった。', '街道は、参詣の者と商いの荷で、昼も夜も人が絶えない。')}'
          '${l.female ? '女人も分け隔てなく迎える寺だと聞く。' : ''}生まれた国を出るのは、これが初めてだ。',
      [
        Choice.h('講の銭で慎ましく参り、皆に札を持ち帰る', '務めは果たせる。道草は食えない', () {
          l.net = _c(l.net + 5);
          g.j(5);
          g.setFlag('pl_ko_daisan');
          g.mark('講の代参として、$destへ詣でた');
          return '${l.female ? '本堂の暗がりで、皆の名を一人ずつ唱えた。' : '宮川で身を清め、玉砂利を踏んで、皆の名を一人ずつ唱えた。'}持ち帰った札は、一軒ずつ配って歩いた。';
        }),
        Choice.h('己の銭を足して、帰りに上方を見物する', '一生の語り草になる。蓄えは目に見えて減る', () {
          _pay(g, 8);
          l.chi = _c(l.chi + 1);
          g.j(8);
          g.setFlag('pl_ko_kenbutsu');
          g.mark('$destへ詣でた帰りに、上方の町を見て歩いた');
          return '大きな橋、瓦葺きの町並み、川を上り下りする荷船。口を開けて歩いていて、幾度も人にぶつかった。';
        }),
        Choice.h('道中の村々で、作物や商いのやり方を見て帰る', '土産は札だけではなくなる。物見遊山と見られるかもしれない', () {
          l.chi = _c(l.chi + 1);
          l.gold += g.rng.range(2, 6);
          g.setFlag('pl_ko_tane');
          g.mark('$destへの旅の道中で、他国の作物の種を持ち帰った');
          return '見たことのない菜の種を、宿の主に分けてもらった。帰って蒔くと、この土地でも芽を出した。';
        }),
      ],
      after: next,
    );
  }),
  _again('pl_ko', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_ko', 'また講の旅に出た。', [
      '{季}、講の仲間と街道に出た。',
      '草鞋の紐を結ぶ手つきも、慣れたものだ。',
      '宿場ごとの名物を、もう空で言える。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('講の旅', '$head峠の茶屋で、道連れになった年寄りの巡礼が、熱を出して動けなくなった。', [
        Choice.h('熱が下がるまで、付き添う', '年寄りは助かる。講の仲間とは、はぐれる', () {
          l.fame += 1;
          g.j(3);
          _pay(g, 2);
          return '二晩、額の手ぬぐいを替えた。三日めの朝、年寄りは手を合わせて、こちらの名を尋ねた。';
        }),
        Choice.h('茶屋の者に銭を預けて、先を急ぐ', '旅は続けられる。あの年寄りがどうなったかは、分からずじまいだ', () {
          _pay(g, 2);
          g.j(-1);
          return '茶屋の婆に銭を握らせた。峠を下りながら、幾度か振り返った。';
        }),
      ], after: next);
      return;
    }
    g.ask('講の旅', '$head大雨で川が止まった。渡しの再開は、いつになるか分からない。宿賃は、日ごとに出ていく。', [
      Choice.h('水が引くのを待つ', '体は休まる。路銀は減る', () {
        _pay(g, 4);
        _heal(g, 8);
        return '宿の二階から、濁った川を眺めて四日を過ごした。同宿の者と、国の話をし尽くした。';
      }),
      Choice.h('上流の橋まで、山道を回る', '銭は減らない。足にはこたえる', () {
        l.hp -= 6;
        return '丸二日、山道を歩いた。橋を渡りきったとき、膝が笑っていた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 家訓
  // ==================================================================
  _first('pl_kakun', (g, next) {
    final l = g.l;
    final buke = l.rank >= 1 || _exBushi(g);
    g.ask(
      '家訓',
      '戦の世には、家を保つのは槍と運だった。これからは、${buke ? '勤めと倹約' : '信用と倹約'}だ。'
          '${_era(g, '乱世を知らぬ子らに、何を言い残すか。', '戦を知る者は、家にもう己ひとりになった。', '孫の代は、もう戦の話を昔話としか思っていない。')}'
          '白い紙を前に、一条目を考える。',
      [
        Choice.h('「奢るな。身の程を守れ」と書く', '家は長く続く。大きくはならない', () {
          g.setFlag('pl_kakun_kenyaku');
          g.j(2);
          return '「衣は木綿、膳は一汁一菜。普請と祝儀に見栄を張るな」。書いてみると、己が守れていない条ばかりだった。';
        }),
        Choice.h(buke ? '「主に背くな。届けを怠るな」と書く' : '「客を欺くな。${plKogi(g)}の触れに背くな」と書く', '咎めを受けぬ家になる。それだけで足りる世かどうか', () {
          g.setFlag('pl_kakun_chu');
          l.fame += 1;
          return '${buke ? '家を潰すのは、いまや敵の槍ではなく、届けひとつの遅れだ。' : '店を潰すのは、いまや戦ではなく、信用ひとつの傷だ。'}そう書き添えて、筆を置いた。';
        }),
        Choice.h('己のしくじりを、ありのままに書く', '子らは神妙に聞く。親の威厳は、少し減る', () {
          g.setFlag('pl_kakun_shippai');
          g.j(3);
          g.mark('家訓に、己のしくじりをありのまま書き残した');
          return '逃げた戦、騙された商い、言えなかった詫び。読み聞かせると、子らは笑わずに聞いていた。';
        }),
        if (l.chi >= 60)
          Choice.h('帳面の付け方から書状の作法まで、細かに書き添える', '読めば家が回る書になる。書き上げるまでに、幾月もかかる', () {
            l.fame += 2;
            l.hp -= 2;
            g.setFlag('pl_kakun_jitsu');
            g.mark('暮らしの作法を細かに記した家訓を書き上げた');
            return '年貢の請取の綴じ方、借銭の証文の文言、弔いと祝いの包みの相場。心得ではなく、やり方を書いた。綴じると、指二本の厚さになった。';
          }, via: '知'),
      ],
      after: next,
    );
  }),
  _again('pl_kakun', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_kakun', 'また家訓の綴りを開いた。', [
      '{季}、家訓の綴りを開いた。',
      '家訓の紙の端が、手擦れで丸くなってきた。',
      '正月には家訓を読み聞かせるのが、家の習いになった。',
    ]);
    final k = l.kidAged(g.year, 15, 45);
    if (k != null && g.rng.chance(.5)) {
      g.ask('家訓', '$head${k.name}が、家訓に背いた。人に頼まれて、借銭の請け人の判を押したという。', [
        Choice.h('家訓どおり、きつく咎める', '掟は掟だ。子の情けを、踏みにじることになる', () {
          l.fame += 1;
          g.j(-2);
          return '${k.name}は畳に手を突いた。「友を見捨てろと、家訓にはあるのですか」。答えに、少し詰まった。';
        }),
        Choice.h('訳を聞き、家訓に一条を書き足す', '掟が生きたものになる。甘いと言う者もいる', () {
          l.net = _c(l.net + 2);
          g.j(2);
          return '「請け人に立つときは、失ってもよい額までとせよ」。${k.name}と二人で、文言を考えた。';
        }),
      ], after: next);
      return;
    }
    g.ask('家訓', '$head一条、書き足したいことがある。', [
      Choice.h('「火の用心を怠るな」', '当たり前のことだ。当たり前のことで、家は焼ける', () {
        g.j(1);
        return '「寝る前に竈と行灯を己の目で見よ。人に任せるな」。書いてから、己で竈を見に立った。';
      }),
      Choice.h('「年寄りの言うことを、鵜呑みにするな」', '己の首を絞める一条だ。子らは、笑うだろう', () {
        l.fame += 1;
        g.j(2);
        return '「世は変わる。この書も、古くなれば改めよ」。読み聞かせると、いちばん下の子が、声を出して笑った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 縁組と跡の算段
  // ==================================================================
  _first('pl_engumi', (g, next) {
    final l = g.l;
    final k = _matchKid(g);
    if (k == null) {
      g.ask('跡の算段', '跡を継ぐ子がいない。戦の世なら、家は腕のある者が力で継いだ。いまは、届けと証文がなければ、田も${l.rank >= 1 ? '禄' : '店'}も他人のものになる。養子の口を、探しはじめた。', [
        Choice.h('親類の子を、養子に迎える', '血は近い。親類の口出しも、付いてくる', () {
          final name = g.rng.pick(l.freeNames(kGivenM));
          l.addKid(g.year - 14, female: false, name: name, adopted: true);
          g.meet('養子', name, 45);
          g.setFlag('pl_yoshi');
          g.mark('親類から養子を迎え、家の跡を定めた');
          return '兄の家の次男、$nameを迎えた。まだ声変わりの途中の少年が、仏壇の前で、ぎこちなく手を合わせた。';
        }),
        Choice.h('見込みのある若い者を、身内の外から迎える', '器量は確かだ。親類は、面白くない', () {
          final name = g.rng.pick(l.freeNames(kGivenM));
          l.addKid(g.year - 18, female: false, name: name, adopted: true);
          g.meet('養子', name, 55);
          l.net = _c(l.net - 3);
          g.setFlag('pl_yoshi');
          g.mark('身内の外から見込みのある若者を養子に迎えた');
          return '長く家に出入りしていた$nameに、話を切り出した。若者は長いこと黙り、それから深く頭を下げた。';
        }),
        Choice.h('急がず、もう少し探す', '悔いのない相手を選べる。己に何かあれば、間に合わない', () {
          g.j(-1);
          return '幾つかの話を聞いたが、決め手がなかった。算段は、来年に持ち越した。';
        }),
      ], after: next);
      return;
    }
    final name = k.name;
    g.ask(
      '縁組の算段',
      '$nameの縁組を、考える年頃になった。戦の世なら、縁組は味方を増やす手立てだった。いまは、家の格と、持参の銭と、相手の家の評判が物を言う。'
          '仲人が、二つの話を持ってきた。',
      [
        Choice.h('格の釣り合う、堅い家との話を進める', '波風のない縁になる。支度は、格のぶんだけ要る', () {
          _pay(g, 8);
          l.net = _c(l.net + 5);
          g.setFlag('pl_engumi_kaku');
          if (k.female) {
            l.kidLeft(k, KidFate.wed, g.year);
            g.mark('$nameを、格の釣り合う家へ縁づけた');
            return '結納を交わし、秋に$nameを送り出した。門口で振り返った顔は、もう他家の者の顔をしていた。';
          }
          g.mark('$nameに、格の釣り合う家から嫁を迎えた');
          return '結納を交わし、秋に祝言を挙げた。台所に、聞き慣れぬ足音が一つ増えた。';
        }),
        Choice.h('格は下だが、裕福な家との話を進める', '暮らしの心配はなくなる。陰口は、聞こえてくる', () {
          l.gold += g.rng.range(8, 14);
          l.fame -= 1;
          g.setFlag('pl_engumi_tomi');
          if (k.female) {
            l.kidLeft(k, KidFate.wed, g.year);
            return '支度はすべて、向こうの家が調えた。$nameは、絹の小袖に埋もれるようにして輿に乗った。';
          }
          return '嫁は、長持を七棹も連ねてやって来た。親類の年寄りが、数を数えて黙り込んだ。';
        }),
        Choice.h('本人の気持ちを聞き、今年は見送る', '恨まれることはない。良い話は、待ってはくれない', () {
          g.j(3);
          g.setFlag('pl_engumi_matsu');
          return '$nameは長いこと黙ってから、「もう少し、この家にいとうございます」と言った。仲人には、丁重に断りを入れた。';
        }),
      ],
      after: next,
    );
  }),
  _again('pl_engumi', (g, next) {
    final l = g.l;
    final head = _intro(g, 'pl_engumi', 'また家の先々のことを考えた。', [
      '{季}、家の先々のことを考えた。',
      '縁組の話は、不思議と重なって来るものだ。',
      '仲人の顔を見ると、用向きが分かるようになった。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('縁組の算段', '$head縁続きの家に、祝い事がある。包む額で、これからの付き合いの深さが決まる。', [
        Choice.h('格より多めに包む', '頼りにされる家になる。次も同じだけ、期待される', () {
          _pay(g, 6);
          l.net = _c(l.net + 5);
          return '祝いの席で、上座に近い膳が用意されていた。帰りがけ、先方の主が門まで送りに出た。';
        }),
        Choice.h('世間並みに包む', '無理はない。目立ちもしない', () {
          _pay(g, 2);
          l.net = _c(l.net + 1);
          return '世間並みの包みに、世間並みの礼が返ってきた。それで十分だ。';
        }),
      ], after: next);
      return;
    }
    g.ask('縁組の算段', '$head仲人が、親類の娘の縁談の口利きを頼んできた。相手の家のことを、少し知っている。良い噂ばかりではない。', [
      Choice.h('知っていることを、ありのまま伝える', '娘のためにはなる。相手の家の恨みを買うかもしれない', () {
        l.fame += 1;
        l.net = _c(l.net + (g.rng.chance(.5) ? 3 : -2));
        return '「借銭があると聞く。己の目で確かめなされ」。話は流れた。のちに、その家が店を畳んだと聞いた。';
      }),
      Choice.h('余計なことは言わず、口だけ利く', '角は立たない。あとで何かあれば、寝覚めが悪い', () {
        l.net = _c(l.net + 2);
        g.j(-1);
        return '当たり障りのないことだけを言って、仲人を帰した。祝言の知らせが来たときも、まだ少し気がかりだった。';
      }),
    ], after: next);
  }),
];

// ======================================================================
// 武家
// ======================================================================

/// 跡取りにする息子（嫡男の役割の子がその歳ならその子、なければ家にいる息子のいちばん上）。
Kid? _heirSon(Game g) =>
    roleKid(g, '嫡男', 15, 45, false) ?? g.l.sonAged(g.year, 15, 45);

/// 生きている息子がいない（家を出た息子も含めて）。
bool _noSons(Game g) => g.l.kidsAged(g.year, 0, 999, false, false).isEmpty;

void _joinHouse(Game g, String lord, int fav) {
  final l = g.l;
  l.rank = 1;
  if (l.maxRank < 1) l.maxRank = 1;
  l.lord = lord;
  l.fav = fav;
  l.troops = 0;
  l.ronin = false;
}

List<SceneDef> _bukeScenes() => [
  // ---- 役替え（番方から役方へ）----
  _s('pl_yakugae', 18, 70, (g) => _samurai(g) && g.l.rank <= 6 && g.year >= 1602, (g, next) {
    final l = g.l;
    final house = houseName(g, l.lord);
    g.ask(
      '役替え',
      '$house家の家中で、役替えの触れが出た。'
          '${_era(g, '槍働きの場は、もう無い。番方の人数は減らされ、蔵と普請の役所が人を求めている。', '家中で重んじられるのは、いまや算用の達者な者ばかりだ。', '家中の者の大半は、もう戦を知らない。役所の席次が、そのまま家の格になった。')}'
          'どの役を願い出るか。',
      [
        Choice.h('勘定方を願い出る', '算盤と帳面の勤めだ。地味だが、家の蔵を握る', () {
          if (l.sei < 90) l.sei++;
          l.merit += 5;
          g.setFlag('pl_kanjo');
          g.mark('槍を置き、勘定方の勤めに就いた');
          return '具足櫃を納戸の奥へ押しやり、算盤を買った。はじめの月は、珠を弾く指が、槍を握るより疲れた。';
        }),
        Choice.h('普請方を願い出る', '堤や石垣の丁場を預かる。体は使うが、形に残る', () {
          l.merit += 5;
          l.hp -= 3;
          g.setFlag('pl_fushin');
          g.mark('槍を置き、普請方の勤めに就いた');
          return '縄張りの見方は、陣を敷くのと似ていた。違うのは、築いたものを誰も攻めてこないことだ。';
        }),
        Choice.h('番方に残り、城の番を勤める', '武辺の面目は立つ。出世の道は細くなる', () {
          l.bu = _c(l.bu + 1);
          l.fav = _c100(l.fav + 3);
          g.setFlag('pl_bankata');
          return '門の番、櫓の番、夜回り。槍は毎朝磨いた。それを使う日が来ないことを、誰もが知っていた。';
        }),
        if (l.chi >= 60)
          Choice.h('右筆の試しを受ける', '筆と文案の役だ。殿の側近くに仕えることになる', () {
            l.fav = _c100(l.fav + 8);
            l.merit += 6;
            g.setFlag('pl_yuhitsu');
            g.mark('筆を見込まれ、右筆として殿の側に仕えた');
            return '${plKogi(g)}への届けの文案を、三通り書いて差し出した。家老はいちばん短い一通を取り、「これだ」と言った。';
          }, via: '知'),
      ],
      after: next,
    );
  }),

  // ---- 合わぬ帳尻（勘定方の続き）----
  _s('pl_kanjo_cho', 18, 75, _samurai, (g, next) {
    final l = g.l;
    void clean() {
      l.merit += 10;
      l.fav = _c100(l.fav + 6);
      g.setFlag('pl_kanjo_clean');
      g.mark('勘定方として、蔵米の帳尻の合わぬ訳を明らかにした');
    }

    g.ask('合わぬ帳尻', '蔵米の出入りを洗っていて、帳尻の合わぬ年を見つけた。たどると、上役の印に行き着く。戦の世なら、兵糧の融通で済んだ話だ。いまは、書付がすべて残る。', [
      Choice.h('帳面を添えて、家老に申し出る', '筋は通る。上役の一族を、敵に回す', () {
        if (g.rng.chance(.7)) {
          clean();
          return '家老は帳面を三日預かった。四日め、上役は「病につき」役を退いた。蔵の鍵は、こちらに回ってきた。';
        }
        l.fav = _c100(l.fav - 6);
        l.net = _c(l.net - 4);
        g.j(-4);
        return '帳面は、家老の手元で止まった。上役と家老は、縁続きだった。翌月、蔵から遠い役に回された。';
      }),
      Choice.h('上役に内々に告げ、穴を埋めさせる', '波風は立たない。貸しを一つ、作ることになる', () {
        l.net = _c(l.net + 5);
        g.setFlag('pl_kanjo_quiet');
        return '上役は顔色を変え、それから長く息を吐いた。ひと月のうちに、俵は蔵に戻っていた。以来、上役はこちらの願いを断らない。';
      }),
      Choice.h('見なかったことにする', '身は安泰だ。帳面の穴は、いつか誰かが見つける', () {
        g.j(-3);
        g.setFlag('pl_kanjo_blind');
        return '帳面を閉じ、元の棚に戻した。それからしばらく、蔵の前を通るたびに足が早くなった。';
      }),
      if (l.chi >= 65)
        Choice.h('古い帳面をすべて突き合わせ、動かぬ証を揃えてから申し出る', '言い逃れはさせない。揃うまで、誰にも気取られてはならない', () {
          clean();
          l.merit += 4;
          return '十年ぶんの蔵帳と、村々の請取を突き合わせた。差し出した綴りを前に、家老も上役も、一言も返せなかった。';
        }, via: '知'),
    ], after: next);
  }),

  // ---- 丁場（普請方の続き）----
  _s('pl_fushin_ba', 18, 72, _samurai, (g, next) {
    final l = g.l;
    g.ask(
      '丁場',
      '川の堤の普請を預かった。'
          '${_era(g, '戦のあいだ荒れたままの堤は、大水のたびに切れてきた。', '城下を水から守る、大きな堤だ。', '新しく拓いた田を守るための堤だ。')}'
          '人足は、近在の百姓たち。田植えの時期が迫り、村々から、人足を返してくれという願いが届いている。',
      [
        Choice.h('期日どおりに仕上げさせる', '上の覚えは良い。村の恨みは残る', () {
          l.merit += 8;
          l.fav = _c100(l.fav + 4);
          l.fame -= 1;
          g.setFlag('pl_fushin_strict');
          return '堤は、梅雨の前に仕上がった。その年、近在の田植えは半月遅れ、秋の実りは薄かった。';
        }),
        Choice.h('田植えのあいだ人足を返し、秋に仕上げる', '村は助かる。遅れの咎めは、己が負う', () {
          l.fav = _c100(l.fav - 3);
          l.net = _c(l.net + 6);
          l.fame += 2;
          g.setFlag('pl_fushin_done');
          g.mark('堤の普請で、田植えの人足を村へ返した');
          return '評定で遅れを咎められ、始末書を書いた。秋、仕上がった堤の上に、村の者が酒を持って待っていた。';
        }),
        Choice.h('己の銭で、日雇いを集める', '田も期日も守れる。持ち出しは痛い', () {
          _pay(g, 12);
          l.merit += 5;
          g.setFlag('pl_fushin_done');
          return '町の口入れ屋に人を頼んだ。流れ者の人足たちは、荒っぽいが仕事は早かった。懐は、すっかり軽くなった。';
        }),
        if (l.sei >= 60)
          Choice.h('村ごとに丁場を割り、仕上げた村から帰す', '競わせれば、早い。割り方を誤れば、村どうしの喧嘩になる', () {
            l.merit += 10;
            l.net = _c(l.net + 4);
            l.fame += 2;
            g.setFlag('pl_fushin_done');
            g.mark('堤の普請を村ごとの割り丁場にして、田植えの前に仕上げた');
            return '杭を打って丁場を割り、村の名を書いた札を立てた。どの村も、隣に負けまいと夜明け前から土を運んだ。田植えの三日前に、最後の村が帰っていった。';
          }, via: '政'),
      ],
      after: next,
    );
  }),

  // ---- 留守居 ----
  _s(
    'pl_rusui',
    30,
    75,
    (g) =>
        _samurai(g) &&
        g.l.rank >= 3 &&
        g.l.lord != _rulerKey(g) &&
        g.year >= 1605,
    (g, next) {
      final l = g.l;
      final seat = plSeat(g);
      final kogi = plKogi(g);
      void took() {
        g.setFlag('pl_rusui');
        g.mark('$seatの屋敷の留守居役を勤めた');
      }

      g.ask(
        '留守居',
        '$seatの屋敷の、留守居役を命じられた。$kogiの役人や他家の留守居と付き合い、触れの裏を聞き出し、家に落ち度のないよう先回りする役だ。'
            '${_era(g, '', '届けひとつの遅れで咎めを受けた家の話を、近ごろよく聞く。', '諸家の留守居は茶屋に寄り合い、互いに先例を教え合っているという。')}',
        [
          Choice.h('寄り合いに、欠かさず顔を出す', '耳は早くなる。付き合いの費えは、かさむ一方だ', () {
            l.net = _c(l.net + 7);
            _pay(g, 8);
            took();
            return '茶屋の二階で、毎月同じ顔ぶれと盃を交わした。どの家に普請が当たりそうか、誰よりも早く国元へ知らせた。';
          }),
          Choice.h('先例を書き留め、家の手控えを作る', '後の者が助かる。人付き合いは、広がらない', () {
            l.chi = _c(l.chi + 1);
            l.merit += 7;
            took();
            g.setFlag('pl_rusui_hikae');
            return '献上の品の数、使者の口上、届けの書式。一つずつ書き留めた手控えは、次の留守居に引き継がれた。';
          }),
          Choice.h('病を言い立てて、役を辞する', '気疲れはない。殿の当ては外れる', () {
            l.fav = _c100(l.fav - 5);
            g.j(2);
            return '「槍のほかに能のない男でござる」。殿は苦い顔をしたが、無理強いはしなかった。';
          }),
          if (l.mi >= 60)
            Choice.h('$kogiの役人の懐に、入り込む', '家の願いが通りやすくなる。深入りすれば、家ごと巻き込まれる', () {
              l.net = _c(l.net + 8);
              l.fav = _c100(l.fav + 6);
              l.merit += 5;
              took();
              return '碁の相手から始めて、やがて屋敷に招かれるようになった。触れが出る前の晩に、中身を知っていることもあった。';
            }, via: '魅'),
        ],
        after: next,
      );
    },
  ),

  // ---- 改易の噂 ----
  _s(
    'pl_kaieki',
    25,
    84,
    (g) =>
        (_samurai(g) || (_exBushi(g) && _lordAlive(g))) &&
        g.l.lord != '松平' &&
        g.year >= 1619 &&
        g.year <= 1645,
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      g.ask(
        '改易の噂',
        '${g.year < 1632 ? '福島家が、城の石垣を届けなしに繕った咎で、安芸と備後を召し上げられた。' : '肥後の加藤家が、取り潰しになった。'}'
            '次は$house家だという噂が、城下に流れている。噂ひとつで、家中が浮き足立った。',
        [
          Choice.h('噂に取り合わず、いつもどおり過ごす', '家中は落ち着く。もし真なら、備えはない', () {
            l.fav = _c100(l.fav + 5);
            g.setFlag('pl_kaieki_calm');
            return '若い者には、「噂で腹は切れぬ」と言って聞かせた。噂は、ひと月ほどで別の家の名に変わった。';
          }),
          Choice.h('蓄えを分け、家の者の落ち着き先を探しておく', '備えにはなる。殿を見限ったと、取られかねない', () {
            _pay(g, 6);
            l.net = _c(l.net + 3);
            l.fav = _c100(l.fav - 3);
            g.setFlag('pl_kaieki_prep');
            return '妻の里と、縁続きの寺に、内々に文を出した。何事もなく年は暮れたが、文を出したことは、いつか誰かの耳に入るだろう。';
          }),
          Choice.h('城の普請や届けに落ち度がないか、洗い直すよう進言する', '家のためになる。重臣の仕事に、口を挟むことになる', () {
            l.merit += 6;
            l.fav = _c100(l.fav + 3);
            g.setFlag('pl_kaieki_check');
            g.mark('改易の噂の立った年、家の届けを洗い直すよう進言した');
            return '調べると、三年前の櫓の修繕が、届けより一間大きかった。急ぎ、詫びを添えて届け直した。咎めは無かった。';
          }),
          if (g.hasFlag('pl_rusui'))
            Choice.h('留守居の頃の伝手で、噂の出どころを確かめる', '確かな筋に聞ける。嗅ぎ回ること自体が、目に付く', () {
              l.merit += 8;
              l.fav = _c100(l.fav + 5);
              l.net = _c(l.net + 2);
              g.setFlag('pl_kaieki_check');
              return '昔の寄り合いの仲間に、文を三通出した。返事は同じだった。「その話は、どこからも出ていない」。殿に、そう申し上げた。';
            }),
        ],
        after: next,
      );
    },
  ),

  // ---- 家中の倹約 ----
  _s('pl_kenyaku', 20, 72, (g) => _samurai(g) && g.year >= 1604, (g, next) {
    final l = g.l;
    g.ask('倹約の触れ', '家の蔵が、底をついた。${plSeat(g)}の屋敷の費えと、${plKogi(g)}から命じられる普請が、年貢では賄いきれない。家中に倹約の触れが出て、禄の一部を「借り上げ」として差し引くという。', [
      Choice.h('黙って従い、暮らしを切り詰める', '家中の手本にはなる。台所は苦しくなる', () {
        _pay(g, 6 + l.rank * 2);
        l.fav = _c100(l.fav + 5);
        g.setFlag('pl_kenyaku_obey');
        return '下男に暇を出し、膳から魚が消えた。朝の登城だけは、火熨斗を当てた袴で通した。';
      }),
      Choice.h('家の者と、内職を始める', '日々の米にはなる。侍の体面は、傷つく', () {
        l.gold += g.rng.range(4, 9);
        l.fame -= 1;
        g.setFlag('pl_kenyaku_naishoku');
        g.mark('禄を借り上げられ、内職で家を支えた');
        return '夜ごと、家じゅうで提灯を張った。問屋の手代は裏口から来る。糊の匂いが、畳に染み付いた。';
      }),
      Choice.h('屋敷の庭を、畑にする', '菜には困らなくなる。客に見せられる庭ではなくなる', () {
        l.gold += 3;
        _heal(g, 6);
        g.j(2);
        g.setFlag('pl_kenyaku_hatake');
        return '松を残して、あとは掘り返した。大根と茄子と、垣根には豆。鍬を握る手は、まだ鈍っていなかった。';
      }),
      if (l.sei >= 60)
        Choice.h('上の費えから削るよう、書付を出す', '筋は通る。重臣の機嫌を損ねるかもしれない', () {
          if (g.rng.chance(.65)) {
            l.merit += 10;
            l.fame += 3;
            g.setFlag('pl_kenyaku_ue');
            g.mark('家中の倹約に、上の費えから削るよう書付を出した');
            return '殿の鷹、奥の衣装、${plSeat(g)}の進物。項目と額を並べた書付は、評定で読み上げられた。借り上げの率は、下の者ほど軽く改められた。';
          }
          l.fav = _c100(l.fav - 6);
          return '書付は、家老の文箱から出てこなかった。「身の程を知れ」と、人づてに聞かされた。';
        }, via: '政'),
    ], after: next);
  }),

  // ---- 参勤の費え（城主より上・大名）----
  _s(
    'pl_sankin_cost',
    20,
    80,
    (g) =>
        g.l.rank >= 5 &&
        g.active &&
        _lordAlive(g) &&
        g.l.lord != '松平' &&
        g.year >= 1635,
    (g, next) {
      final l = g.l;
      final seat = plSeat(g);
      final lord = l.rank >= 8;
      g.ask(
        '参勤の費え',
        '${lord ? '参勤の年が巡ってくる。' : '殿の参勤の行列の差配を、任された。'}'
            '$seatまでの行列の人数、宿場ごとの払い、$seatの屋敷の一年の費え。勘定方の出した見積もりは、年貢の半ばを越えていた。',
        [
          Choice.h('家の格どおりの行列を仕立てる', '体面は保てる。蔵は空になる', () {
            _pay(g, lord ? 60 : 15);
            l.fame += 3;
            g.setFlag('pl_sankin_grand');
            return '毛槍を振り、挟箱を連ねて、行列は街道を埋めた。沿道の者は土下座し、宿場の主は揉み手で迎えた。払いの帳面は、見ないことにした。';
          }),
          Choice.h('供の人数を削り、道中の日数を詰める', '蔵は守れる。貧乏な家だと、沿道に知れ渡る', () {
            if (!lord) l.merit += 6;
            l.fame -= 1;
            g.setFlag('pl_sankin_lean');
            g.mark('参勤の行列を切り詰め、家の蔵を守った');
            return '夜明け前に発ち、日暮れまで歩かせた。宿場をひとつ飛ばすたびに、勘定方が帳面に線を引いた。';
          }),
          Choice.h('上方の商人から、借りる', '当座はしのげる。利は、年ごとに積もる', () {
            l.gold += 20;
            g.setFlag('pl_sankin_debt');
            return '来年の年貢米を形に、証文に判を押した。商人は、腰は低いが目は笑っていなかった。';
          }),
          if (l.sei >= 60)
            Choice.h('宿場と前もって値を決め、国の産物を$seatで売って費えに充てる', '回れば、参勤が商いになる。武家の商法と、笑われるかもしれない', () {
              l.gold += 25;
              if (!lord) l.merit += 8;
              g.setFlag('pl_sankin_lean');
              g.mark('国の産物を$seatで売り、参勤の費えを賄った');
              return '行列の荷駄に、国の紙と蝋を積んだ。$seatの屋敷の蔵から問屋へ卸すと、道中の払いがそっくり浮いた。';
            }, via: '政'),
        ],
        after: next,
      );
    },
  ),

  // ---- 敵討ちの届け ----
  _s(
    'pl_katakiuchi',
    20,
    58,
    (g) =>
        ((_samurai(g) && g.l.rank <= 5) || _ronin(g)) &&
        g.canFight &&
        g.year >= 1603,
    (g, next) {
      final l = g.l;
      final sam = l.rank >= 1;
      g.ask(
        '敵討ちの届け',
        '弟が、酒の席の口論で斬られた。斬った男は、その夜のうちに国を出た。'
            '${_era(g, '戦の世なら、一族で追って討つだけの話だった。', '', '')}'
            'いまは、敵討ちにも届けが要る。${sam ? '殿に願い出て' : '奉行所に届け出て'}帳に付けてもらって、はじめて討っても咎めを受けない。討ち果たすまで、国には戻れないのが習いだ。',
        [
          Choice.h('届けを出し、敵を探す旅に出る', '武士の面目は立つ。何年かかるか、巡り合えるかも分からない', () {
            _pay(g, 8);
            l.fame += 2;
            g.j(-4);
            g.setFlag('pl_kataki_tabi');
            _stamp(g, 'pl_kataki_y');
            g.mark('弟の敵を討つ届けを出し、旅に出た');
            return '届けの写しを懐に、街道へ出た。宿場ごとに人相書きを見せて回る。手がかりは、西へ向かったという噂ひとつだった。';
          }),
          Choice.h('弟の子を立て、後見として送り出す', '筋は通る。若い者に、重い荷を負わせる', () {
            l.fav = _c100(l.fav + 2);
            g.j(-3);
            g.setFlag('pl_kataki_oi');
            return '元服したばかりの甥に、弟の刀を持たせた。門口で深く頭を下げて出ていった背は、まだ細かった。';
          }),
          Choice.h('堪えて、暮らしを続ける', '家の者は守れる。陰で、何と言われるか', () {
            l.fame -= 3;
            l.fav = _c100(l.fav - 2);
            g.j(-3);
            g.setFlag('pl_kataki_none');
            return '弟の位牌に、毎朝手を合わせた。「腰抜け」という声は、聞こえぬふりをした。戦で散々人を斬ってきた手で、もう一人斬る気には、どうしてもなれなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 巡り合い（敵討ちの続き）----
  _s('pl_kataki_end', 22, 70, (g) => _since(g, 'pl_kataki_y') >= 2 && g.canFight, (g, next) {
    final l = g.l;
    final long = _since(g, 'pl_kataki_y') >= 5;
    void done(String how) {
      l.fame += 8;
      l.fav = _c100(l.fav + 8);
      l.merit += 6;
      g.j(4);
      g.setFlag('pl_kataki_done');
      g.mark(how);
    }

    g.ask(
      '巡り合い',
      '街道の宿場町で、ついに敵を見つけた。${long ? '探しはじめてから、幾年も過ぎた。互いの髪に、白いものが混じっている。' : ''}'
          '男は名を変え、手習いの師匠をして暮らしていた。裏の井戸端で、幼い子が遊んでいる。',
      [
        Choice.h('名乗りを上げ、尋常に立ち合う', '本懐を遂げれば、胸を張って帰れる。返り討ちに遭う者もいる', () {
          if (g.rng.chance(.04)) {
            g.die('敵討ちの旅の果てに立ち合い、返り討ちに遭った', 'ansatsu');
            return '踏み込んだ足が、砂利に滑った。';
          }
          if (g.rng.chance(.45 + l.bu / 200)) {
            done('旅の果てに、弟の敵を討ち果たした');
            return '男は逃げなかった。「待っていた」と言って、古い刀を抜いた。三合めで、勝負は付いた。届けの写しを、土地の役人に差し出した。';
          }
          l.hp -= 20;
          g.setFlag('pl_kataki_wounded');
          return '互いに手傷を負い、男は裏の竹藪へ逃げた。次の朝、その家は空だった。傷の癒えるのを待って、国へ戻った。';
        }),
        Choice.h('子の姿を見て、刀を収める', '誰も斬らずに済む。国へは、討ち損じたと告げるほかない', () {
          l.fame -= 2;
          g.j(4);
          g.setFlag('pl_kataki_spared');
          g.mark('弟の敵を見つけながら、刀を収めて帰った');
          return '柄に掛けた手を、ゆっくり離した。男はこちらに気づき、子を背にかばって、深く頭を下げた。何も言わずに、宿場を出た。';
        }),
        Choice.h('土地の役人に届け、立ち会いを願う', '作法どおりだ。そのあいだに、逃げられるかもしれない', () {
          if (g.rng.chance(.5)) {
            done('届けの作法どおりに、弟の敵を討ち果たした');
            return '役人の立ち会いのもと、竹矢来の中で向き合った。見物の者が、垣の外を幾重にも囲んだ。勝負は、一太刀で付いた。';
          }
          g.j(-3);
          return '役人が帳面を繰っているあいだに、男は家の者を連れて姿を消した。また一から、探し直しだ。国へ、その旨を書き送った。';
        }),
        if (l.bu >= 65)
          Choice.h('峰で打ち据え、髻を切って持ち帰る', '命は取らずに、本懐の形は付く。腕に、よほどの差がなければできない', () {
            if (g.might()) {
              done('弟の敵を打ち据え、髻を切って本懐とした');
              return '二合で刀を叩き落とし、峰で肩を打った。膝を突いた男の髻を、小柄で切った。「弟には、これで堪えてもらう」。';
            }
            l.hp -= 10;
            return '手加減のぶんだけ、踏み込みが浅くなった。男の刀が、こちらの二の腕をかすめた。そのまま、竹藪へ逃げられた。';
          }, via: '武'),
      ],
      after: next,
    );
  }),

  // ---- かぶき者 ----
  _s(
    'pl_kabuki',
    20,
    65,
    (g) =>
        !g.l.female &&
        (_samurai(g) || _ronin(g) || _town(g)) &&
        g.year >= 1603 &&
        g.year <= 1652,
    (g, next) {
      final l = g.l;
      final sam = l.rank >= 1;
      g.ask(
        'かぶき者',
        '辻で、異様な風体の若い者たちが道を塞いでいる。'
            '${_era(g, '長い朱鞘の大太刀に、女物のような派手な小袖。鞘に「生き過ぎたり」と刻んだ者がいると伝わる。', '大髭に、天鵞絨の襟。揃いの長煙管を、これ見よがしにくわえている。', '白柄の刀を揃いで差した武家の倅たちと、それに張り合う町の男伊達だ。')}'
            '戦に出そこねた者たちが、行き場のない血気を持て余している。${sam ? '供の若党' : '連れの若い者'}が、肩が触れたと絡まれた。',
        [
          Choice.h('頭を下げて、道を譲る', '怪我はない。笑い声を、背に聞くことになる', () {
            l.fame -= 1;
            g.j(-2);
            g.setFlag('pl_kabuki_yield');
            return '連れの袖を引いて、脇へ寄った。「腰の物は飾りか」と、背中に声が飛んだ。振り向かなかった。';
          }),
          Choice.h('一喝して、連れを引き取る', '戦場を知る者の声だ。相手が退くとは限らない', () {
            if (g.rng.chance(_veteran(g) ? .7 : .45)) {
              l.fame += 3;
              g.setFlag('pl_kabuki_katsu');
              return '「人を斬ったことのある者は、前へ出ろ」。静かに言うと、若い者たちは顔を見合わせた。誰も、出なかった。';
            }
            if (g.rng.chance(.06)) {
              g.die('辻でかぶき者の喧嘩に巻き込まれ、斬られた', 'ansatsu');
              return '後ろの一人が、いきなり抜いた。';
            }
            l.hp -= 12;
            return '言い終わらぬうちに、鞘で殴りかかられた。連れと二人、番所の者が来るまで、袋叩きにされた。';
          }),
          Choice.h('町の番所に、知らせに走る', '手は汚れない。それまで、連れが無事かどうか', () {
            l.net = _c(l.net + 1);
            return '番所の者を連れて戻ると、辻にはもう誰もいなかった。連れは、鼻血を拭きながら笑っていた。';
          }),
          if (l.bu >= 60 && g.canFight)
            Choice.h('鞘ごと抜いて、頭分を打ち据える', '抜かずに片を付ける。腕がなければ、ただの喧嘩になる', () {
              if (g.might()) {
                l.fame += 5;
                g.setFlag('pl_kabuki_katsu');
                g.mark('辻でかぶき者の頭分を、鞘のまま打ち据えた');
                return '踏み込んで、鞘の鐺で鳩尾を突いた。頭分が膝を突くと、残りは蜘蛛の子を散らすように逃げた。朱鞘の大太刀だけが、辻に転がっていた。';
              }
              l.hp -= 10;
              return '頭分は、思いのほか腕が立った。鞘と鞘で打ち合ううち、番所の者が割って入った。互いに、痣だらけだった。';
            }, via: '武'),
        ],
        after: next,
      );
    },
  ),

  // ---- 追腹の禁 ----
  _s(
    'pl_junshi_kin',
    45,
    84,
    (g) =>
        ((_samurai(g) && g.l.rank >= 3) ||
            (_exBushi(g) && g.l.maxRank >= 3 && _lordAlive(g))) &&
        g.year >= 1620,
    (g, next) {
      final l = g.l;
      g.ask('追腹の禁', '病の床の殿が、重臣を枕元に集めた。「わしが死んでも、追腹は固く無用。腹を切る忠義があるなら、生きて跡継ぎを支えよ」。主君の跡を追う者の数を、家どうしで競うような風さえある世だ。殿に取り立てられて今日がある者たちは、顔を見合わせた。', [
        Choice.h('お言葉に従うと、誓う', '命は長らえる。供をせぬのかと、陰で言う者もあろう', () {
          l.fav = _c100(l.fav + 6);
          g.setFlag('pl_junshi_obey');
          g.mark('殿の追腹の禁に従い、生きて跡継ぎを支えると誓った');
          return '「承りました」。声が、少し震えた。殿は目を閉じたまま、小さくうなずいた。';
        }),
        Choice.h('黙って頭を下げ、胸のうちは明かさない', '嘘は吐かずに済む。殿の目は、ごまかせないかもしれない', () {
          g.j(-2);
          g.setFlag('pl_junshi_silent');
          return '畳に額を付けたまま、何も言わなかった。「そなたは」と殿が名を呼んだ。それでも、顔を上げられなかった。';
        }),
        Choice.h('髪を下ろして菩提を弔う許しを、願い出る', '腹は切らず、世は捨てる。勤めからは、身を引くことになる', () {
          l.fav = _c100(l.fav + 3);
          g.j(2);
          g.setFlag('pl_junshi_bodai');
          return '「それならば、許す」。殿は、かすかに笑った。「経は、短いのにしてくれ。長いのは退屈だ」。';
        }),
        if (l.sei >= 60)
          Choice.h('禁を、家の掟として書付に残すよう進言する', '口約束では、いざというとき破られる。殿の死を前提にした話を、枕元ですることになる', () {
            l.merit += 8;
            l.fame += 2;
            g.setFlag('pl_junshi_okite');
            g.mark('追腹の禁を、家の掟として書き残すよう進言した');
            return '右筆が呼ばれ、殿の言葉がそのまま書き取られた。花押が据えられた書付は、家老の手で文箱に納められた。';
          }, via: '政'),
      ], after: next);
    },
  ),

  // ---- 家督の届け ----
  _s('pl_katoku', 50, 80, (g) => _samurai(g) && _heirSon(g) != null && g.year >= 1605, (g, next) {
    final l = g.l;
    final k = _heirSon(g)!;
    final name = k.name;
    g.ask('家督の届け', '$nameも、もう一人前だ。跡目を固めるには、殿に届けを出し、跡継ぎの御目見得を済ませねばならない。届けも御目見得も済まぬうちに当主が倒れれば、跡目は危うい。戦の世には、槍一本あれば家は継げた。', [
      Choice.h('届けを出し、$nameを御目見得に連れていく', '跡目は固まる。己の席は、やがて譲ることになる', () {
        l.fav = _c100(l.fav + 3);
        if (!l.people.containsKey('嫡男')) g.meet('嫡男', name, 60);
        g.setFlag('pl_katoku_done');
        g.mark('$nameの跡目の届けを済ませた');
        return '大広間の敷居際で、$nameは畳に手を突いた。殿が、一言だけ声を掛けた。帰り道、$nameの袴の裾は、汗で色が変わっていた。';
      }),
      Choice.h('$nameを${plSeat(g)}詰めに出し、世間を見せてから決める', '一回り大きくなって帰る。悪い遊びを覚えて帰るかもしれない', () {
        _pay(g, 5);
        l.net = _c(l.net + 2);
        g.setFlag('pl_katoku_tsume');
        return '一年のち、$nameは日に焼けて帰ってきた。言葉つきが少し変わり、国元の噂話に、鼻で笑うようになっていた。';
      }),
      Choice.h('届けは、まだ先に延ばす', '己の勤めは続く。もしものとき、家は揺らぐ', () {
        g.j(1);
        g.setFlag('pl_katoku_wait');
        return '「まだ早い」と言うと、$nameは黙って引き下がった。襖の向こうで、小さな溜め息が聞こえた。';
      }),
    ], after: next);
  }),

  // ---- 跡継ぎのない家（末期の養子は認められない）----
  _s(
    'pl_matsugo',
    48,
    82,
    (g) =>
        !g.l.female &&
        g.l.rank >= 2 &&
        g.active &&
        _lordAlive(g) &&
        g.l.lord != '松平' &&
        g.year >= 1605 &&
        g.year <= 1651 &&
        _noSons(g) &&
        !g.l.people.containsKey('養子') &&
        !g.hasFlag('pl_yoshi'),
    (g, next) {
      final l = g.l;
      final d = l.daughterAged(g.year, 12, 30);
      void adopt(int age, int bond) {
        final name = g.rng.pick(l.freeNames(kGivenM));
        l.addKid(g.year - age, female: false, name: name, adopted: true);
        g.meet('養子', name, bond);
        g.setFlag('pl_yoshi');
      }

      g.ask('跡継ぎのない家', '跡を継ぐ男子がいない。当主が死の床で慌てて養子を願い出ても、${plKogi(g)}は認めない。そうして絶えた家の牢人が、町にあふれている。元気なうちに、養子を届けておくほかない。', [
        if (d != null)
          Choice.h('${d.name}に、婿を取る', '血は繋がる。婿が家風に合うかは、迎えてみねば分からない', () {
            adopt(22, 50);
            g.setFlag('pl_muko');
            g.mark('娘に婿を迎え、家の跡目を届け出た');
            return '同じ家中の三男坊を、婿に迎えた。祝言の席で、${d.name}は一度も婿の顔を見なかった。それでも、届けは無事に通った。';
          })
        else
          Choice.h('親類の次男を、養子に迎える', '血は近い。親類の口出しも、付いてくる', () {
            adopt(16, 45);
            g.mark('親類から養子を迎え、家の跡目を届け出た');
            return '弟の家の次男を迎えた。届けの書付に、養子の名を書き入れる手が、少し震えた。';
          }),
        Choice.h('家中の見込みある若者を、養子に願い出る', '器量は確かだ。親類は、面白くない', () {
          adopt(20, 55);
          l.net = _c(l.net - 3);
          l.merit += 3;
          g.mark('家中の若者を養子に迎え、跡目を届け出た');
          return '組下でいちばん筋の良い若者に、話を切り出した。若者は一晩考え、翌朝、紋の違う裃で挨拶に来た。';
        }),
        Choice.h('家は、己の代で終えると決める', '誰にも気兼ねはない。禄も名も、己とともに消える', () {
          g.j(-2);
          g.setFlag('pl_no_heir');
          return '位牌の並ぶ仏壇の前に、長いこと座っていた。己で終わりにする。そう決めると、妙に肩が軽くなった。';
        }),
      ], after: next);
    },
  ),

  // ---- 再仕官の口（牢人の続き）----
  _s('pl_saishikan', 20, 68, (g) => _ronin(g) && g.alive.isNotEmpty, (g, next) {
    final l = g.l;
    final key = (g.fa[l.home]?.alive ?? false) ? l.home : g.alive.first.name;
    final house = houseName(g, key);
    g.ask(
      '再仕官の口',
      '牢人暮らしも、長くなった。'
          '${_era(g, '', 'どの家も人を減らす一方で、召し抱えの口はいよいよ細い。', '取り潰された家の牢人が、町にあふれている。')}'
          'そこへ、口利きの話が来た。$house家が、新田の検分と年貢の割付のできる者を探しているという。槍の腕は問わない。筆と算盤の立つ者を、と。',
      [
        Choice.h('筆と算盤で仕える', '侍の身分は戻る。槍一筋だった頃の己には、顔向けできない', () {
          if (g.rng.chance(.35 + l.chi / 150)) {
            _joinHouse(g, key, 20);
            g.setFlag('pl_saishikan_done');
            g.mark('牢人の身から、筆と算盤で$house家に召し抱えられた');
            return '試しの算用を、どうにか解いた。扶持はわずかだが、門に表札を掛けられる。刀は、床の間に置いた。';
          }
          g.j(-3);
          return '試しの算用で、検地帳の石盛りを取り違えた。「槍なら確かなのだろうが」と、役人は気の毒そうに言った。';
        }),
        Choice.h('武芸で召し抱えよと、押して願う', '己を曲げずに済む。いまどき、通る話かどうか', () {
          if (g.rng.chance(.1 + l.bu / 400)) {
            _joinHouse(g, key, 25);
            g.setFlag('pl_saishikan_done');
            g.mark('牢人の身から、武芸一つで$house家に召し抱えられた');
            return '庭先で槍の型を見せると、年かさの家老が身を乗り出した。「まだ、こういう男がいたか」。若殿の稽古相手として、扶持が出た。';
          }
          l.fame += 1;
          return '「槍の達者なら、家中に余っておる」。門前で、丁重に断られた。';
        }),
        Choice.h('断って、町で暮らし続ける', '気ままな暮らしは守れる。侍に戻る道は、これで閉じる', () {
          g.j(2);
          g.setFlag('pl_machi_ronin');
          return '口利きの者に、礼だけ言って帰した。長屋の者たちは、何も聞かずに、いつもどおり味噌を貸してくれた。';
        }),
        if (l.chi >= 60)
          Choice.h('検地帳の誤りを、その場で指摘してみせる', '腕を見せるには、いちばん早い。役人の面目を、潰すことにもなる', () {
            _joinHouse(g, key, 35);
            l.merit += 8;
            g.setFlag('pl_saishikan_done');
            g.mark('牢人の身から、筆と算盤で$house家に召し抱えられた');
            return '見本に出された帳面の、三枚目の足し違いを指でさした。役人は算盤を入れ直し、黙って奥へ引っ込んだ。出てきたときには、扶持の額が増えていた。';
          }, via: '知'),
      ],
      after: next,
    );
  }),
];

// ======================================================================
// 町人・商人
// ======================================================================

/// 奉公に出した子（旗に残した名の子が、いまも奉公に出ているとき）。
Kid? _hokoKid(Game g) {
  final k = g.l.kidNamed(_named(g, 'pl_hoko'));
  return k != null && k.alive && k.fate == KidFate.service ? k : null;
}

void _sendToShop(Game g, Kid k) {
  final l = g.l;
  l.kidLeft(k, KidFate.service, g.year);
  if (k.female && !l.people.containsKey('奉公に出た娘')) {
    g.meet('奉公に出た娘', k.name, 55);
  }
  l.gold += 3;
  g.setFlag('pl_hoko_kid');
  g.setFlag('pl_hoko:${k.name}');
  _stamp(g, 'pl_hoko_y');
  g.mark('${k.name}を、大店へ年季奉公に出した');
}

List<SceneDef> _townScenes() => [
  // ---- 城下の町割り ----
  _s('pl_machiwari', 18, 75, (g) => _town(g) && g.year <= 1630, (g, next) {
    final l = g.l;
    void omote() {
      l.fame += 2;
      g.setFlag('pl_omote');
      g.mark('新しい城下の表通りに、店の間口を構えた');
    }

    g.ask('町割り', '城下に、新しい町割りの縄が張られた。侍は城のまわり、寺は町はずれ、商人と職人は生業ごとに町を分けて住めという。戦の世には、町は堀と土塁の内に身を寄せ合っていた。これからの町は、道がまっすぐで、遠くまで見通せる。表通りの間口は、冥加の銭と籤で決まる。', [
      Choice.h('冥加の銭を積み、表通りに間口を取る', '人通りは店の命だ。蓄えの多くが消える', () {
        if (l.gold < 30) {
          g.j(-1);
          return '積める銭が足りず、割り当てられたのは横町の奥だった。';
        }
        l.gold -= 30;
        omote();
        return '大手の門からまっすぐ延びる通りに、間口三間。暖簾を掛けた朝、通りの向こうの端まで、人の頭が続いていた。';
      }),
      Choice.h('裏通りに広い地所を取り、蔵を建てる', '目立たない。荷を置く場所には、困らなくなる', () {
        _pay(g, 10);
        g.setFlag('pl_ura_kura');
        return '裏の堀端に、蔵を二棟並べた。船から直に荷が揚がる。表通りの店が、荷を預けに来るようになった。';
      }),
      Choice.h('古い町に残る', '馴染みの客はいる。人の流れは、新しい城下へ移っていく', () {
        g.j(2);
        g.setFlag('pl_furumachi');
        return '向かいも隣も、新しい城下へ移っていった。空き家の増えた通りで、古い看板を掛け続けた。';
      }),
      if (l.un >= 60)
        Choice.h('銭は積まず、間口の籤に賭ける', '当たれば、ただで表通りだ。外れれば、残り物を引く', () {
          if (g.luck()) {
            omote();
            return '引いた籤には、辻の角地の番号が書いてあった。銭を積んだ大店の主たちが、こちらを睨んだ。';
          }
          return '引いたのは、寺町の手前の、日当たりの悪い一画だった。';
        }, via: '運'),
    ], after: next);
  }),

  // ---- 問屋の仲間 ----
  _s('pl_nakama', 20, 78, (g) => _town(g) && g.hasFlag('way_merchant') && g.year >= 1608, (g, next) {
    final l = g.l;
    g.ask(
      '仲間',
      '同じ品を商う問屋たちが、内々に「仲間」を組もうとしている。値を崩さず、新参を入れず、掛けを踏み倒す客には皆で売らない。'
          '戦の世の座は、寺社や公家に銭を納めて守ってもらうものだった。いまは、守ってくれる者がいない。'
          '${_real(g) ? '${plKogi(g)}は、商人が徒党を組んで値を決めることを喜ばない。表向きは、ただの講だ。' : ''}',
      [
        Choice.h('仲間に入る', '商いは安定する。抜け駆けは、できなくなる', () {
          l.gold += 10;
          l.net = _c(l.net + 4);
          g.setFlag('pl_nakama');
          g.mark('問屋の仲間に連なり、値と信用を守った');
          return '月に一度、寺の座敷に寄り合う。値を申し合わせ、払いの悪い客の名を回す。帳面の波が、なだらかになった。';
        }),
        Choice.h('入らずに、安値で売って客を取る', '客は付く。問屋たちを、残らず敵に回す', () {
          if (g.rng.chance(.5)) {
            l.gold += 18;
            l.fame += 1;
            g.setFlag('pl_yasuuri');
            return '仲間の値より一割安く売った。店先に、朝から列ができた。問屋たちは、道で会っても目を合わせない。';
          }
          _pay(g, 8);
          g.setFlag('pl_yasuuri');
          return '仲間が手を回し、どの荷主も品を回してくれなくなった。空の棚を前に、ひと月を過ごした。';
        }),
        Choice.h('仲間の世話役を引き受ける', '顔は利く。揉め事は、すべて持ち込まれる', () {
          l.net = _c(l.net + 8);
          g.j(-2);
          g.setFlag('pl_nakama');
          g.setFlag('pl_nakama_gyoji');
          return '値の申し合わせを破った店、掛けの取り立ての順、跡目のない店の株の行方。寄り合いのたびに、頭の痛い話が積まれた。';
        }),
        if (l.sei >= 60)
          Choice.h('仲間の掟を書付にし、新参も銭を納めれば入れる道を作る', '閉じた仲間は、いずれ恨まれる。古株は、渋るだろう', () {
            l.fame += 3;
            l.net = _c(l.net + 6);
            g.setFlag('pl_nakama');
            g.mark('問屋の仲間の掟を定め、新参の入る道を作った');
            return '掟は七か条。最後の一条に、新参の加入の作法を書き入れた。古株は渋ったが、「恨まれて潰される仲間より、頼られる仲間を」と押し切った。';
          }, via: '政'),
      ],
      after: next,
    );
  }),

  // ---- 火事 ----
  _s('pl_kaji', 18, 80, (g) => _town(g) && g.year >= 1604, (g, next) {
    final l = g.l;
    void burned() {
      g.setFlag('pl_kaji');
      _stamp(g, 'pl_kaji_y');
    }

    g.ask(
      '火事',
      '夜半、半鐘が鳴った。${_era(g, '板葺きと茅葺きの家が軒を連ねる町に、', '家の建て込んだ町に、', '人であふれる町に、')}'
          '風上から火が走ってくる。戦の火なら、逃げる先は山だった。町の火は、逃げる先も町だ。何を先にするか、決めねばならない。',
      [
        Choice.h('蔵の戸に目塗りをして、身一つで逃げる', '品は蔵が守る。目塗りが甘ければ、すべて灰だ', () {
          burned();
          if (g.rng.chance(.7)) {
            g.setFlag('pl_kaji_kura');
            return '味噌まで使って戸の隙間を塗り込め、川端へ走った。三日のち、焼け野原の中に、蔵だけが黒く立っていた。戸を開けると、品は無事だった。';
          }
          l.gold = l.gold ~/ 2;
          return '焼け跡で蔵の戸を開けると、中から熱い風が吹き出した。目塗りの隙から、火が入っていた。';
        }),
        Choice.h('帳面と証文だけを抱えて逃げる', '品は焼ける。掛けの証さえあれば、商いは立て直せる', () {
          burned();
          l.gold -= l.gold ~/ 3;
          g.setFlag('pl_kaji_cho');
          g.mark('大火の夜、帳面と証文だけを抱えて逃げた');
          return '大福帳を風呂敷に包み、井戸に吊るしてから逃げた。店は柱一本残らなかった。濡れた帳面を、河原で一枚ずつ干した。';
        }),
        Choice.h('店は捨てて、隣の年寄りと子を連れ出す', '人は助かる。店の物を運ぶ暇は、なくなる', () {
          burned();
          l.gold = l.gold ~/ 2;
          l.fame += 4;
          l.net = _c(l.net + 6);
          g.setFlag('pl_kaji_hito');
          g.mark('大火の夜、店を捨てて隣の年寄りと子を連れ出した');
          return '隣の婆を背負い、子の手を引いて、橋まで走った。振り向くと、己の店の屋根が、音を立てて落ちるところだった。';
        }),
        Choice.h('火の中、もう一度蔵へ戻る', '運び出せる品は増える。火の回りは、思うより早い', () {
          if (g.rng.chance(.04)) {
            g.die('大火の夜、蔵へ荷を取りに戻り、煙に巻かれた', 'sai');
            return '蔵の中で、出口が分からなくなった。';
          }
          burned();
          l.hp -= 12;
          return '反物の包みを三つ担ぎ出したところで、梁が落ちた。眉と髪を焦がして、川へ飛び込んだ。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 焼け跡（火事の続き）----
  _s('pl_saiken', 18, 82, (g) => _town(g) && _since(g, 'pl_kaji_y') >= 1, (g, next) {
    final l = g.l;
    g.ask(
      '焼け跡',
      '焼け跡に、仮の小屋が立ち並びはじめた。材木の値は跳ね上がり、大工の手間賃も上がった。'
          '${g.hasFlag('pl_kaji_cho') ? '持ち出した帳面には、得意先への掛けが残っている。相手もまた、焼け出された者たちだ。' : '得意先も、みな焼け出された者たちだ。'}',
      [
        Choice.h('掛けの取り立てを待ち、品を貸し売りする', '恩は忘れられない。こちらの懐が、先に尽きるかもしれない', () {
          _pay(g, 10);
          l.net = _c(l.net + 8);
          l.fame += 3;
          g.setFlag('pl_saiken_trust');
          g.mark('焼け跡で掛けの取り立てを待ち、得意先の立ち直りを助けた');
          return '「払いは、屋根が葺けてからでいい」。帳面に、また掛けが増えた。翌年の暮れ、踏み倒した客は一人もいなかった。';
        }),
        Choice.h('材木を買い付けて、高値のうちに売る', '儲けは大きい。焼け出された町の者は、顔を覚えている', () {
          l.gold += 25;
          l.fame -= 3;
          g.setFlag('pl_saiken_zaimoku');
          return '川上の山から筏を組ませ、言い値で売った。蔵がもう一つ建つほど儲かった。道で会う者の挨拶が、短くなった。';
        }),
        Choice.h('借銭をして、土蔵造りの店に建て直す', '次の火には強い。借りた銭は、重い', () {
          _pay(g, 20);
          g.setFlag('pl_dozo');
          g.mark('焼け跡に、土蔵造りの店を建て直した');
          return '壁は厚い土、屋根は瓦、窓には土の扉。左官の手間は、板葺きの五軒ぶん掛かった。黒い壁の店は、通りでいちばん重たげに見えた。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 奉公の口（町と村の子）----
  _s(
    'pl_hoko_kid',
    28,
    70,
    (g) =>
        (_town(g) || _villager(g)) &&
        g.year >= 1604 &&
        g.l.kidAged(g.year, 10, 15) != null,
    (g, next) {
      final l = g.l;
      final k = l.kidAged(g.year, 10, 15)!;
      final name = k.name;
      g.ask(
        '奉公の口',
        '口入れの者が、$nameに奉公の話を持ってきた。'
            '${_era(g, '城下に店を構えはじめた呉服の店が', '上方に本店のある大店が、城下の出店に', '${plSeat(g)}に出店を持つ大店が')}、'
            '子飼いの${k.female ? '下女' : '丁稚'}を探している。年季は十年。${k.female ? '行儀と針を仕込まれ' : '読み書きと算盤を仕込まれ'}、盆と正月のほかは家に帰れない。',
        [
          Choice.h('奉公に出す', '飯と仕込みには困らない。次に会うときは、他人の家の者の顔をしている', () {
            _sendToShop(g, k);
            return '風呂敷包みひとつを背負わせて、口入れの者に預けた。$nameは角を曲がるまで、一度も振り返らなかった。';
          }),
          Choice.h('家の仕事を継がせる', '手元に置ける。外の世間を、知らぬまま育つ', () {
            g.j(2);
            g.setFlag('pl_hoko_kept');
            return '口入れの者を帰した。$nameは、ほっとしたような、がっかりしたような顔で、土間の隅から見ていた。';
          }),
          Choice.h('$nameに、己で決めさせる', '恨まれることはない。子どもの決めることだ', () {
            if (g.rng.chance(.5)) {
              _sendToShop(g, k);
              return '$nameは長いこと考えて、「行く」と言った。その晩、母親が黙って、新しい草履を編んだ。';
            }
            g.j(2);
            g.setFlag('pl_hoko_kept');
            return '$nameは首を横に振った。口入れの者は肩をすくめ、次の家へ回っていった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 藪入り（奉公に出した子の続き）----
  _s(
    'pl_hoko_kaeri',
    34,
    84,
    (g) => _hokoKid(g) != null && _since(g, 'pl_hoko_y') >= 6,
    (g, next) {
      final l = g.l;
      final k = _hokoKid(g)!;
      final name = k.name;
      g.ask(
        '藪入り',
        '$nameが、久しぶりに帰ってきた。'
            '${k.female ? '言葉つきも立ち居も、すっかり店の奥の者のそれだ。土産の包みを解きながら、話を切り出した。店の主が、手代の一人との縁組を世話すると言っている。' : '前垂れ姿も板に付き、手代に取り立てられたという。土産の包みを解きながら、話を切り出した。主が、暖簾を分けて小さな店を持たせてくれると言っている。ただし、元手の半分は、こちらで用意せねばならない。'}',
        [
          if (k.female)
            Choice.h('縁組を、喜んで受ける', '店の後ろ盾のある縁だ。里は、いよいよ遠くなる', () {
              l.kidLeft(k, KidFate.wed, g.year);
              l.net = _c(l.net + 4);
              g.j(5);
              g.setFlag('pl_hoko_done');
              g.mark('奉公に出した$nameが、店の世話で縁づいた');
              return '祝言は、店の奥座敷で挙げられた。末席から見る$nameは、堂々としたものだった。奉公に出した日の小さな背を、思い出した。';
            })
          else
            Choice.h('蓄えをはたいて、元手を出してやる', '$nameは一軒の主になる。こちらの老い先の蓄えは、薄くなる', () {
              _pay(g, 20);
              g.j(6);
              g.setFlag('pl_hoko_done');
              g.setFlag('pl_noren');
              g.mark('奉公に出した$nameに、暖簾分けの元手を出してやった');
              return '間口二間の小さな店に、本家と同じ紋の暖簾が掛かった。$nameは、客の前で、こちらを「父の家の者」ではなく「大事なお得意」として扱った。';
            }),
          Choice.h('家に戻ってきてほしいと、頼む', '家は賑やかになる。あの子が積んだ年季は、ここで途切れる', () {
            if (g.rng.chance(.5)) {
              l.kidBack(k);
              if (l.people['奉公に出た娘']?.name == name) {
                l.people.remove('奉公に出た娘');
              }
              g.j(4);
              g.setFlag('pl_hoko_back');
              return '$nameは長いこと黙り、それからうなずいた。店には、丁重な詫びの文を書いた。家の帳面は、その年から見違えるほど整った。';
            }
            g.j(-2);
            return '$nameは、静かに首を横に振った。「もう、あちらが己の家のようなものです」。責める言葉は、出てこなかった。';
          }),
          Choice.h('$nameの思うとおりにさせる', '悔いは残らない。どちらに転んでも、口は出せない', () {
            g.j(3);
            g.setFlag('pl_hoko_done');
            return '「お前の一生だ」とだけ言った。$nameは少し驚いた顔をして、それから、奉公に出てから初めて、子どもの頃の笑い方をした。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 芝居町 ----
  _s(
    'pl_shibai',
    18,
    75,
    (g) =>
        g.year >= 1603 &&
        (_town(g) || _ronin(g) || (_samurai(g) && g.l.rank <= 6)),
    (g, next) {
      final l = g.l;
      final sam = l.rank >= 1;
      final String stage;
      if (g.year < 1629) {
        stage = '河原に小屋が掛かり、かぶき踊りが町じゅうの噂になっている。男のなりをした女が、茶屋遊びのさまを舞って見せるという。';
      } else if (g.year < 1652) {
        stage = '女の舞台は風紀を乱すと差し止められ、いまは前髪の若衆が舞っている。芝居小屋の並ぶ一角は、塀で囲われた廓と並べて、町の「悪所」と呼ばれている。';
      } else {
        stage = '小屋には櫓が上がり、前髪を落とした役者たちが、筋のある芝居を幾幕も続けて見せるようになった。';
      }
      g.ask(
        '芝居町',
        '$stage${sam ? '侍が出入りしては外聞が悪いが、編笠で顔を隠して通う者は多い。' : '店の者も客も、寄ると触るとその話だ。'}',
        [
          Choice.h('一度、見物に出かける', '浮世の憂さは晴れる。癖になる者も多い', () {
            _pay(g, 3);
            g.j(7);
            g.setFlag('pl_shibai_seen');
            return '筵張りの小屋に、人いきれと太鼓の音が満ちていた。舞台の灯が消えたあとも、しばらく耳の底で囃子が鳴っていた。';
          }),
          Choice.h('贔屓の役者に祝儀を弾み、桟敷の常連になる', '粋な客と呼ばれる。身代を傾けた者の話も聞く', () {
            _pay(g, 15);
            g.j(8);
            l.net = _c(l.net + 5);
            l.fame += 1;
            g.setFlag('pl_shibai_hiiki');
            g.mark('芝居町の桟敷の常連として知られた');
            return '桟敷には、己の名を染めた幕が下がった。贔屓の役者が、舞台から目で挨拶をよこす。帳面の「遊興」の項が、月ごとに太っていった。';
          }),
          Choice.h('悪所には、近づかない', '銭も評判も減らない。話の輪には、入れない', () {
            g.j(-1);
            g.setFlag('pl_shibai_none');
            return '囃子の音は、風に乗って家まで届いた。聞こえぬふりをして、帳面を繰った。';
          }),
          if (!sam && _town(g))
            Choice.h('店の者を、月に一度だけ皆で連れていく', '隠れて通い詰められるよりは良い。払いは、すべて主持ちだ', () {
              _pay(g, 6);
              l.net = _c(l.net + 4);
              g.setFlag('pl_shibai_mise');
              return '丁稚から番頭まで、揃いの手ぬぐいで土間に並んだ。翌朝の店は、誰もが芝居の口真似をして、妙に活気があった。';
            }),
        ],
        after: next,
      );
    },
  ),

  // ---- 飛脚 ----
  _s('pl_hikyaku', 20, 78, (g) => _town(g) && g.hasFlag('way_merchant') && g.year >= 1615, (g, next) {
    final l = g.l;
    g.ask(
      '飛脚',
      '街道の宿場ごとに人と馬を継ぎ、決まった日に文と荷を運ぶ飛脚ができた。'
          '${_real(g) ? '月に三度、上方と${plSeat(g)}を往き来するのだと伝わる。' : ''}'
          '戦の世には、文ひとつ届けるにも命がけだった。飛脚問屋が、得意先にならぬかと回ってきた。',
      [
        Choice.h('遠国の相場の知らせを、飛脚で取り寄せる', '値の動きが、人より早く分かる。知らせの代は、安くない', () {
          _pay(g, 6);
          l.chi = _c(l.chi + 1);
          g.setFlag('pl_hikyaku');
          return '月に三度、細かい字で埋まった書付が届く。米、綿、油、銀。遠い町の値が、店の奥に座ったまま分かるようになった。';
        }),
        Choice.h('手形を飛脚に託し、銀を運ばずに商う', '道中で盗まれる心配はなくなる。手形が紙くずになれば、大損だ', () {
          l.gold += 8;
          g.setFlag('pl_hikyaku');
          g.setFlag('pl_kawase');
          return '重い銀箱の代わりに、一枚の紙が街道を走る。はじめは半信半疑だったが、向こうの両替屋は、紙と引き換えに、きちんと銀を出した。';
        }),
        Choice.h('今までどおり、手代を歩かせる', '顔を合わせての商いだ。早さでは、もう敵わない', () {
          g.j(1);
          return '「紙切れより、人の足と目だ」。飛脚問屋は愛想よく笑って、隣の店へ回っていった。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 相場（飛脚の続き）----
  _s('pl_soba', 20, 80, (g) => _town(g) && g.hasFlag('way_merchant'), (g, next) {
    final l = g.l;
    void won() {
      g.setFlag('pl_soba_won');
      g.mark('飛脚の早耳で、米の相場を当てた');
    }

    g.ask('相場', '飛脚の知らせが届いた。上方の米市で、値が動きはじめたという。西国の作柄が悪いらしい。この町の値は、まだ動いていない。知らせが町に広まるまで、三日か四日。', [
      Choice.h('蔵が埋まるほど、米を買い込む', '当たれば、蔵がもう一つ建つ。外れれば、身代が傾く', () {
        if (g.rng.chance(.55)) {
          l.gold += 35;
          won();
          return '五日めに、町の値が跳ねた。買い値の倍近くで、蔵を空にした。算盤を入れる指が、震えた。';
        }
        _pay(g, 25);
        g.setFlag('pl_soba_lost');
        return '知らせは、早とちりだった。西国の雨は持ち直し、値は元に戻った。蔵いっぱいの米を、損を切って売った。';
      }),
      Choice.h('得意先に回す分だけ、手堅く押さえる', '大儲けはない。客に迷惑は掛けずに済む', () {
        l.gold += 8;
        l.net = _c(l.net + 3);
        g.setFlag('pl_soba_katai');
        return '値が上がっても、得意先には前の値で納めた。「あの店は、こういうときに頼りになる」と、言われるようになった。';
      }),
      Choice.h('買わずに、町の者に値上がりを知らせる', '儲けはない。困る者は、減る', () {
        l.fame += 4;
        l.net = _c(l.net + 5);
        g.setFlag('pl_soba_told');
        g.mark('米の値上がりをいち早く町に知らせ、買い占めをしなかった');
        return '町年寄の家へ、書付を持って走った。値が上がる前に、長屋の者たちは米を買い置くことができた。同業の者には、馬鹿だと笑われた。';
      }),
      if (l.un >= 60)
        Choice.h('買い込んだうえ、空模様に賭けて売り時を延ばす', '雨が続けば、値はまだ上がる。晴れれば、儲けは消える', () {
          if (g.luck(.3)) {
            l.gold += 50;
            won();
            return '皆が売りに回った日にも、蔵の戸を閉めていた。その晩から、また雨になった。十日のち、町じゅうの米屋が頭を下げに来た。';
          }
          l.gold += 5;
          return '欲をかいて待つうちに、晴れ間が続いた。値は下がりはじめ、慌てて売ったときには、儲けは雀の涙だった。';
        }, via: '運'),
    ], after: next);
  }),
];

// ======================================================================
// 百姓
// ======================================================================

List<SceneDef> _villageScenes() => [
  // ---- 検地の縄 ----
  _s('pl_kenchi', 18, 75, (g) => _villager(g) && g.year <= 1645, (g, next) {
    final l = g.l;
    g.ask(
      '縄入れ',
      '検地の役人が、村に入った。'
          '${_era(g, '先の検地から、もう何年にもなる。そのあいだに拓いた田も、荒れた田もある。', '領主が替わってから、初めての総検地だ。', '新田が増えたので、縄を入れ直すという。')}'
          '田の一枚ごとに竿を当て、上中下を決めて帳に付ける。谷あいの奥に、帳に載っていない小さな田がある。',
      [
        Choice.h('ありのまま案内する', '咎めは受けない。年貢は増える', () {
          _pay(g, 4);
          l.fame += 1;
          g.setFlag('pl_kenchi_honest');
          return '谷の奥の田にも竿が当てられ、帳に付いた。役人は「正直な村だ」と言ったが、秋の年貢は、きっちり増えていた。';
        }),
        Choice.h('奥の田のことは、黙っている', '年貢は増えない。村の誰かが漏らせば、ただでは済まない', () {
          if (g.rng.chance(.75)) {
            l.gold += 6;
            g.setFlag('pl_kakushida');
            return '役人は谷の入り口で引き返した。奥の田の米は、その年も、どの帳面にも載らずに村の腹に収まった。';
          }
          _pay(g, 10);
          l.fame -= 2;
          return '隣村との境争いで負けた男が、役人に耳打ちした。奥の田は帳に付き、村じゅうに過料が掛かった。';
        }),
        Choice.h('役人に酒を出し、田の位を一つ下げてもらう', '昔からのやり方だ。堅物に当たれば、藪蛇になる', () {
          _pay(g, 5);
          if (g.rng.chance(.6)) {
            l.gold += 7;
            g.setFlag('pl_kenchi_sake');
            return '役人は盃を重ね、竿を持つ手が少し緩んだ。上の田が中に、中の田が下に、帳の上でだけ痩せていった。';
          }
          return '役人は盃に手を付けなかった。「戦の世の役人と、同じに思うな」。酒は、そのまま持ち帰らされた。';
        }),
        if (l.sei >= 60)
          Choice.h('案内役を買って出て、痩せ地の実情を筋道立てて申し立てる', '言い分が通れば、村じゅうが助かる。役人の心証しだいだ', () {
            l.gold += 5;
            l.net = _c(l.net + 5);
            l.fame += 2;
            g.setFlag('pl_kenchi_annai');
            g.mark('検地の案内役として、村の痩せ地の実情を申し立てた');
            return '水の来ぬ年の数、石の出る深さ、日の当たる刻。田ごとに訳を述べると、役人は筆を止めて聞いた。帳の位は、実りに見合ったものになった。';
          }, via: '政'),
      ],
      after: next,
    );
  }),

  // ---- 村請 ----
  _s('pl_murauke', 20, 78, (g) => _villager(g) && g.year >= 1604, (g, next) {
    final l = g.l;
    void helped(String how) {
      l.fame += 2;
      g.setFlag('pl_murauke_helped');
      g.mark(how);
    }

    g.ask('村請', '年貢は、家ごとではなく、村でまとめて納めることになっている。今年、隣の家が、働き手を病で亡くして納められない。欠けた分は、村の残りの家で埋めねばならない。寄り合いは、夜更けまで続いた。', [
      Choice.h('欠けた分を、多めに引き受ける', '隣は助かる。己の家の冬は、苦しくなる', () {
        _pay(g, 6);
        l.net = _c(l.net + 7);
        helped('年貢を納められぬ家の分を、多めに引き受けた');
        return '「うちで、三俵持つ」。寄り合いが静まった。次に手を挙げたのは、いちばん貧しい家の主だった。';
      }),
      Choice.h('家ごとに、等しく割るよう言う', '恨みっこなしだ。貧しい家には、重い', () {
        _pay(g, 2);
        l.net = _c(l.net + 1);
        return '頭数で割った。誰も文句は言わなかったが、帰り道、誰も口を利かなかった。';
      }),
      Choice.h('その家の田を、村で預かって耕すよう言う', '年貢は埋まる。その家は、田を失ったも同じになる', () {
        l.gold += 3;
        l.net = _c(l.net - 2);
        g.setFlag('pl_murauke_azukari');
        return '田は村の預かりになった。その家の後家と子らは、己の田で、小作のように働くことになった。';
      }),
      if (l.mi >= 60)
        Choice.h('手を出し合って、その家の田を一年だけ手伝う話をまとめる', '田も家も守れる。皆を、その気にさせられればだ', () {
          l.net = _c(l.net + 8);
          l.fame += 1;
          helped('働き手を出し合い、年貢を納められぬ家の田を守った');
          return '「来年は、うちがそうなるかもしれん」。一軒ずつ回って、同じことを言った。田植えの日、その家の田には、村じゅうの者が並んだ。';
        }, via: '魅'),
    ], after: next);
  }),

  // ---- 用水の普請 ----
  _s('pl_yosui', 18, 70, (g) => _villager(g) && g.year >= 1603, (g, next) {
    final l = g.l;
    g.ask(
      '用水の普請',
      '川上に堰を築き、村まで水路を引く普請が始まる。'
          '${_era(g, '戦のあいだは、堰を築いても、敵に切られるか陣場にされるかだった。', '', '近ごろは、山を掘り抜いて水を通すような普請の話まで聞く。')}'
          '水が来れば、畑を田に変えられる。村ごとに、人足と銭の割り当てが回ってきた。',
      [
        Choice.h('人足に出て、土を運ぶ', '銭は掛からない。体は、ひと夏でがたが来る', () {
          l.hp -= 8;
          l.net = _c(l.net + 4);
          g.setFlag('pl_yosui');
          g.mark('用水の普請に人足として出て、村に水を引いた');
          return '畚を担いで、ひと夏。秋の終わり、水路の底を、濁った水が音を立てて走ってきた。村じゅうの者が、土手に並んで見ていた。';
        }),
        Choice.h('銭を出して、人足は雇ってもらう', '体は守れる。蓄えは減る', () {
          _pay(g, 8);
          g.setFlag('pl_yosui');
          return '割り当ての銭を、庄屋に届けた。水が来た日、土手には上がらず、己の畑の端から、それを見た。';
        }),
        Choice.h('割り当てを渋り、普請には加わらない', '体も銭も減らない。水が来ても、分けてもらえるかどうか', () {
          l.net = _c(l.net - 5);
          g.setFlag('pl_yosui_no');
          return '水路は、己の畑の脇を通って、先へ流れていった。水口を切らせてくれと頼むと、寄り合いは長いこと黙っていた。';
        }),
        if (l.mi >= 60)
          Choice.h('川上の村との、水の分け前の掛け合いを買って出る', 'まとまれば、水争いの種が消える。こじれれば、己のせいになる', () {
            l.net = _c(l.net + 7);
            l.fame += 2;
            g.setFlag('pl_yosui');
            g.setFlag('pl_yosui_kake');
            g.mark('用水の水の分け前を、川上の村と掛け合ってまとめた');
            return '川上の村の年寄りと、三晩、酒を飲んだ。昼は川上、夜は川下。取り決めを書付にして、双方の庄屋が判を押した。';
          }, via: '魅'),
      ],
      after: next,
    );
  }),

  // ---- 水の来た原（用水の続き）----
  _s('pl_shinden_kuwa', 20, 76, _villager, (g, next) {
    final l = g.l;
    final son = l.sonAged(g.year, 16, 40);
    g.ask('水の来た原', '用水が通り、村はずれの原に水が来た。拓いた者の田になり、はじめの数年は年貢も軽い。${son != null ? '${son.name}は、分家して己の田を持ちたいと言っている。' : ''}', [
      Choice.h('家の者総出で拓き、持ち田を増やす', '家は太る。鍬を振るう歳では、もうないが', () {
        l.hp -= 6;
        l.gold += 8;
        g.setFlag('pl_shinden_own');
        g.mark('用水の通った原を拓き、家の田を増やした');
        return '石を拾い、根を掘り、畦を塗った。三年めの秋、原だった所から、家の者が一年食えるだけの米が上がった。';
      }),
      if (son != null)
        Choice.h('拓いた田を${son.name}に分け、分家させる', '家は二つになる。本家の田は、増えない', () {
          l.kidLeft(son, KidFate.away, g.year);
          g.j(5);
          l.net = _c(l.net + 3);
          g.setFlag('pl_bunke');
          g.mark('拓いた田を${son.name}に分け、分家させた');
          return '原の端に、小さな家が建った。戦の世なら、次男三男は、足軽に出るか寺に入るかだった。${son.name}は、己の田の畦に立って、長いこと水を見ていた。';
        })
      else
        Choice.h('村の若い者に譲り、種籾を貸す', '村に家が一軒増える。己の得には、ならない', () {
          l.net = _c(l.net + 6);
          l.fame += 2;
          g.setFlag('pl_shinden_yuzuri');
          return '田を持てずにいた若い夫婦に、原を譲った。秋、最初の一俵を、夫婦は真っ先に届けに来た。';
        }),
      Choice.h('手は出さない', '今ある田で足りる。原は、ほかの誰かのものになる', () {
        g.j(1);
        return '原は、隣の家が拓いた。畦越しに、見事な稲を眺める秋が、何度か過ぎた。';
      }),
    ], after: next);
  }),

  // ---- 夜逃げの誘い ----
  _s('pl_chosan', 20, 70, (g) => _villager(g) && g.year >= 1608, (g, next) {
    final l = g.l;
    g.ask(
      '夜逃げの誘い',
      '隣の家の主が、夜更けに戸を叩いた。年貢の未進がかさみ、もう田も牛も残っていない。今夜、家の者を連れて村を出るという。'
          '${_era(g, '新しく拓かれる村では、来る者を拒まず、当座の種籾まで貸すそうだ。', '町へ出れば、日雇いの口はいくらでもあるそうだ。', '町へ出れば、日雇いの口はいくらでもあるそうだ。')}'
          '「お前のところも、苦しかろう。一緒に来ないか」。走った者が出れば、残った者が年貢を負う。',
      [
        Choice.h('黙って見送る', '隣人は助かる。その分の年貢は、残った者にかかる', () {
          _pay(g, 3);
          g.j(-2);
          g.setFlag('pl_chosan_miokuri');
          return '握り飯を持たせ、戸を閉めた。明け方、隣の家は空だった。竈の灰は、まだ温かかった。';
        }),
        Choice.h('思いとどまらせ、未進の猶予を掛け合う', '田と家は残る。聞き入れられるかは、分からない', () {
          if (g.rng.chance(.4 + l.mi / 200)) {
            l.net = _c(l.net + 6);
            l.fame += 2;
            g.setFlag('pl_chosan_tometa');
            g.mark('夜逃げしかけた隣人を引き留め、未進の猶予を掛け合った');
            return '夜明けまで話し、朝いちばんに二人で庄屋の門を叩いた。三年の年賦で、話がついた。隣の主は、土間に額を付けた。';
          }
          g.j(-2);
          return '庄屋は首を横に振った。「一軒許せば、皆が言い出す」。次の夜、隣の家は空になった。';
        }),
        Choice.h('共に、村を出る', '年貢からは逃れられる。先祖の田と墓を、捨てることになる', () {
          l.gold = l.gold ~/ 2;
          l.net = _c(l.net - 8);
          g.j(-5);
          g.setFlag('pl_hashiri');
          g.mark('年貢に追われ、先祖の田を捨てて村を出た');
          return '鍋と種籾だけを背負い、月のない道を歩いた。峠で一度だけ振り返ると、村は闇に沈んで、どこにあるのかも分からなかった。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 手習い ----
  _s('pl_tenarai', 20, 75, (g) => _villager(g) && g.year >= 1612, (g, next) {
    final l = g.l;
    final k = l.kidAged(g.year, 7, 13);
    g.ask(
      '手習い',
      '村の寺で、住持が子らに読み書きを教えはじめた。'
          '${_era(g, '触れも年貢の割付も、近ごろは書付で回ってくる。', '年貢の割付も、村の帳も、触れも、いまは皆書付だ。字が読めねば、言われるままに判を押すほかない。', '近ごろは、町から来た牢人が師匠をしている村もある。')}'
          '${k != null ? '${k.name}を通わせるかどうか。野良の手は、一人減る。' : '大人でも、夜なら教えてやると住持は言う。'}',
      [
        if (k != null)
          Choice.h('${k.name}を、寺に通わせる', '字の読める子になる。野良の手は減る', () {
            g.j(3);
            g.setFlag('pl_tenarai_kid');
            g.mark('${k.name}を、寺の手習いに通わせた');
            return 'ひと冬で、${k.name}は年貢の請取を読めるようになった。「ここ、去年より一斗多い」。指でさされて、目を凝らした。';
          })
        else
          Choice.h('夜、己が習いに通う', '年を取ってからの手習いだ。笑う者もいる', () {
            l.chi = _c(l.chi + 3);
            g.setFlag('pl_tenarai_self');
            g.mark('年を取ってから、寺で読み書きを習った');
            return '節くれだった指に、筆はなかなか馴染まなかった。それでも春には、己の名と村の名を、人に見せられる字で書けた。';
          }),
        if (k != null)
          Choice.h('冬のあいだだけ、通わせる', '野良には響かない。覚えたことは、夏のうちに半分忘れる', () {
            l.gold += 1;
            g.setFlag('pl_tenarai_kid');
            return '雪が解けると、${k.name}は筆を置いて苗代に入った。それでも、己の名と数だけは、忘れなかった。';
          })
        else
          Choice.h('己の名と数の書き方だけ、教わる', '判を押す前に、数だけは確かめられる', () {
            l.chi = _c(l.chi + 1);
            return '三晩で切り上げた。それでも、証文の数のところだけは、己の目で確かめられるようになった。';
          }),
        Choice.h('百姓に字は要らないと、断る', '働き手は減らない。書付は、読める者の言うままになる', () {
          l.gold += 2;
          return '「字で腹は膨れん」。住持は何も言わず、ただ少し寂しそうに笑った。';
        }),
        if (l.chi >= 55)
          Choice.h('住持を手伝い、子らに数の勘定を教える', '村に字と数が根付く。野良の暇は、減る', () {
            l.net = _c(l.net + 5);
            l.fame += 2;
            g.setFlag('pl_tenarai_tetsudai');
            g.mark('村の寺の手習いを手伝い、子らに数の勘定を教えた');
            return '俵の数、反別、利息。子らの知っているもので、足し算と割り算を教えた。親たちが、戸口から覗きに来るようになった。';
          }, via: '知'),
      ],
      after: next,
    );
  }),

  // ---- 村の役 ----
  _s(
    'pl_shoya',
    38,
    78,
    (g) =>
        _villager(g) &&
        !g.l.female &&
        g.year >= 1603 &&
        (g.l.net >= 15 || g.hasFlag('shoya')),
    (g, next) {
      final l = g.l;
      void open(String how) {
        g.setFlag('pl_yakunin');
        g.setFlag('pl_yakunin_open');
        g.mark(how);
      }

      g.ask(
        '村の役',
        '${g.hasFlag('shoya') ? '庄屋の勤めは、戦の世とは様変わりした。' : '村の役人を決める寄り合いで、名が挙がった。'}'
            '年貢の割付、人別の帳、道と橋の普請、触れの読み聞かせ。上の言い付けを村に下ろし、村の願いを上へ取り次ぐ。'
            '戦の世の村の頭は、槍を持って村を守った。いまの村の頭は、筆を持って板挟みになる。',
        [
          Choice.h('引き受け、帳面を村の誰にでも見せる', '村の者は安心する。己の落ち度も、隠せなくなる', () {
            l.net = _c(l.net + 6);
            l.fame += 3;
            open('村の役を引き受け、年貢の帳面を村の誰にでも見せた');
            return '割付の帳を、寄り合いの真ん中に広げた。字の読める者が、読めぬ者に読んで聞かせた。文句は出たが、陰口は減った。';
          }),
          Choice.h('引き受け、上の言い付けを堅く守る', '代官の覚えは良い。村の者とのあいだに、溝ができる', () {
            l.gold += 4;
            l.net = _c(l.net - 2);
            g.setFlag('pl_yakunin');
            return '触れは一字も違えずに読み聞かせ、年貢は期日の三日前に揃えさせた。代官は名を覚えてくれたが、祭りの酒の席で、隣に座る者が減った。';
          }),
          Choice.h('年寄りを立て、己は補佐に回る', '矢面には立たずに済む。決めるのは、己ではなくなる', () {
            l.net = _c(l.net + 3);
            g.setFlag('pl_yakunin_hosa');
            return '帳面を付け、使いに走り、決めごとは年寄りの口から言ってもらった。それはそれで、気の楽な役回りだった。';
          }),
          if (l.sei >= 60)
            Choice.h('割付の決め方を寄り合いで書付にし、毎年読み上げる', '誰が役に就いても、同じに回る村になる。決めるまでが、ひと苦労だ', () {
              l.net = _c(l.net + 5);
              l.fame += 4;
              open('年貢の割付の決め方を、村の書付に定めた');
              return '田の位ごとの掛け目、欠けた家の分の割り方、役人の取り分。幾晩も揉めて、ようやく一枚の書付になった。村じゅうの家の主が、名を書いて判を押した。';
            }, via: '政'),
        ],
        after: next,
      );
    },
  ),

  // ---- 凶作と年貢の願い ----
  _s(
    'pl_nengu',
    22,
    78,
    (g) => _villager(g) && g.year >= 1610 && (g.year < 1640 || g.year > 1644),
    (g, next) {
      final l = g.l;
      final head = g.hasFlag('pl_yakunin');
      g.ask(
        '凶作',
        '${_era(g, '夏に冷たい雨が続き、', '日照りで溜池が干上がり、', '長雨と虫で、')}稲は半分も実らなかった。それでも年貢は、いつもの年のとおりに割り付けられてきた。'
            '${head ? '村の役を務める身として、どう動くか、皆がこちらを見ている。' : '寄り合いで、どうするかを決めねばならない。'}'
            '戦の世なら、鎌と竹槍で一揆を起こした。いまは、願いにも作法がある。',
        [
          Choice.h('村の名で、年貢を減らす願い書を出す', '作法どおりの願いだ。聞き届けられるかは、代官しだいだ', () {
            if (g.rng.chance(head ? .7 : .5)) {
              l.gold += 4;
              l.net = _c(l.net + 4);
              g.setFlag('pl_nengu_negai');
              g.mark('凶作の年、村の名で年貢を減らす願いを出し、聞き届けられた');
              return '代官は、己で田を見に来た。穂を一本抜いて、指でしごいた。三日のち、三分引きの書付が届いた。';
            }
            _pay(g, 5);
            return '願い書は、朱で「不相叶」と書かれて戻ってきた。種籾に手を付けて、納めるほかなかった。';
          }),
          Choice.h('代官を飛び越え、上の役所へ直に訴える', '届けば、村は救われる。越訴は御法度、頭取は命がけだ', () {
            if (g.rng.chance(.04)) {
              g.die('実りのない年、村のために越訴し、頭取として仕置きを受けた', 'seppuku');
              return '訴えは取り上げられ、年貢は減った。頭取の名は、帳に残った。';
            }
            if (g.rng.chance(.6)) {
              l.gold += 6;
              l.fame += 6;
              l.net = _c(l.net + 6);
              g.setFlag('pl_nengu_osso');
              g.mark('凶作の年、咎めを覚悟で上の役所へ直に訴えた');
              return '城下の役所の門前に、願い書を掲げて座った。三日めに、奥へ呼ばれた。年貢は半分になり、代官は替えられた。咎めは、叱りだけで済んだ。';
            }
            _pay(g, 8);
            l.fame += 3;
            return '訴えは取り上げられず、村に過料が掛かった。それでも、村の者は誰も、こちらを責めなかった。';
          }),
          Choice.h('種籾と牛を質に入れて、納める', '咎めは受けない。来年の作付けが、危うくなる', () {
            _pay(g, 10);
            g.j(-3);
            g.setFlag('pl_nengu_paid');
            return '牛を引いていく質屋の背を、子らが黙って見送った。年貢は、期日どおりに納まった。';
          }),
          if (l.chi >= 60)
            Choice.h('田ごとの出来を書き上げ、検見のやり直しを願う', '数で示せば、役人も退けにくい。書き上げるまで、夜なべが続く', () {
              l.gold += 5;
              l.fame += 3;
              g.setFlag('pl_nengu_negai');
              g.mark('凶作の年、田ごとの出来を書き上げて検見のやり直しを願った');
              return '一枚ごとに穂の数を数え、籾の重さを量って、帳に付けた。差し出すと、役人は帳と田を見比べ、黙って竿を取り直した。';
            }, via: '知'),
        ],
        after: next,
      );
    },
  ),
];

// ======================================================================
// 僧・寺
// ======================================================================

List<SceneDef> _templeScenes() => [
  // ---- 本末の帳 ----
  _s(
    'pl_honmatsu',
    20,
    84,
    (g) => _monk(g) && g.year >= 1632 && !g.hasFlag('pc_matsuji'),
    (g, next) {
      final l = g.l;
      g.ask('本末の帳', '${plKogi(g)}が、国じゅうの寺に、どの本山に連なるかを書き上げて出せと命じた。本山を持たぬ寺は、寺として認められない。この寺は、古くはどの宗とも言い切れぬ草庵から始まった。名のある本山の末に連なれば、上納と人事に口を出される。', [
        Choice.h('大きな本山の末寺として、書き上げる', '寺の格は定まる。上納と指図が、毎年届く', () {
          _pay(g, 5);
          l.fame += 1;
          g.setFlag('pl_matsuji');
          return '本山から、寺号を記した書付と、上納の額を記した書付が、一緒に届いた。山門の額を、掛け替えた。';
        }),
        Choice.h('近くの古い寺を本寺に仰ぎ、小さくまとまる', '付き合いは気安い。寺の格は、低いままだ', () {
          l.net = _c(l.net + 4);
          g.setFlag('pl_matsuji_chiisa');
          return '隣の谷の古寺の和尚と、茶を飲みながら話を決めた。帳の上では、末寺の末寺。暮らしは、何も変わらなかった。';
        }),
        Choice.h('帳に載らぬまま、村の堂守として残る', '誰の指図も受けない。寺とは認められず、葬いも出せなくなるかもしれない', () {
          g.j(2);
          l.fame -= 2;
          g.setFlag('pl_mujaku');
          return '書き上げは、出さなかった。帳の上では、ここに寺はない。それでも朝の鐘は撞き、村の者は手を合わせに来た。';
        }),
        if (l.chi >= 60)
          Choice.h('寺の古い由緒を調べ上げ、それに合う本山を選んで申し立てる', '筋の通った書き上げになる。蔵の古文書と、幾月も向き合うことになる', () {
            l.chi = _c(l.chi + 1);
            l.fame += 3;
            g.setFlag('pl_matsuji_yuisho');
            g.mark('寺の由緒を調べ上げ、本末の帳に書き上げた');
            return '虫食いの過去帳と、棟札と、村の年寄りの話。突き合わせると、開山の僧の名と、学んだ山が浮かび上がった。書き上げは、一字の直しもなく受け取られた。';
          }, via: '知'),
      ], after: next);
    },
  ),

  // ---- 寺請の判 ----
  _s('pl_terauke_tsutome', 20, 84, (g) => _monk(g) && g.year >= 1638, (g, next) {
    final l = g.l;
    g.ask('寺請の判', '檀家の一人ひとりについて、「この者は切支丹にあらず、当寺の檀那に紛れなし」と書いて判を押すのが、寺の務めになった。判をもらいに、男が来た。寺に参る姿を、これまで一度も見たことがない。手を合わせる仕草が、どこかぎこちない。', [
      Choice.h('何も問わずに、判を押す', '男と家の者は救われる。偽りと知れれば、寺も咎めを受ける', () {
        if (g.rng.chance(.9)) {
          g.j(2);
          g.setFlag('pl_terauke_mercy');
          g.mark('素性を問わずに寺請の判を押し、一家を守った');
          return '男は、畳に額を擦り付けた。それから月に一度、本堂の隅に座るようになった。何に手を合わせているのかは、問わなかった。';
        }
        _pay(g, 10);
        l.fame -= 4;
        g.setFlag('pl_terauke_mercy');
        return '訴人があり、男の家は役人に踏み込まれた。判を押した寺も呼び出され、きつい叱りと過料を受けた。';
      }),
      Choice.h('月々の参詣を約束させてから、押す', '寺に落ち度は残らない。男の胸のうちまでは、変えられない', () {
        l.net = _c(l.net + 3);
        g.setFlag('pl_terauke_yakusoku');
        return '男はうなずき、約束を守った。経のあいだ、唇は動いていたが、声は聞こえなかった。';
      }),
      Choice.h('判を断り、役人に知らせる', '寺は安泰だ。あの男と家の者がどうなるかは、分かっている', () {
        l.fame += 1;
        g.j(-6);
        g.setFlag('pl_terauke_told');
        return '数日のち、男の家は空になった。戸口に、小さな草履が片方、落ちていた。その夜の勤行は、声が出なかった。';
      }),
    ], after: next);
  }),

  // ---- 葬い ----
  _s('pl_tomurai', 20, 84, (g) => _monk(g) && g.year >= 1602, (g, next) {
    final l = g.l;
    g.ask(
      '葬い',
      '${_era(g, '戦の世には、弔いといえば討死した者の供養だった。', '首のない骸を弔った日々は、もう遠い。', '戦で死んだ者を弔ったことのある僧は、もう己くらいのものだ。')}'
          'いまは、畳の上で死んだ年寄りを、家の者が泣いて送る。村の水呑みの家から、葬いを頼まれた。布施にできるものは、何もないという。',
      [
        Choice.h('布施なしで、ねんごろに弔う', '家の者は救われる。寺の台所は、霞を食うことになる', () {
          g.j(4);
          l.fame += 3;
          l.net = _c(l.net + 4);
          g.setFlag('pl_tomurai_free');
          g.mark('布施を出せぬ家の葬いを、ねんごろに弔った');
          return '野辺送りの列の先頭を歩き、経は省かずに読んだ。後日、その家の子が、山で採った茸を黙って庫裏に置いていった。';
        }),
        Choice.h('野良の手伝いを、布施代わりに受ける', '互いに気兼ねがない。寺男の仕事が、少し減る', () {
          l.gold += 1;
          l.net = _c(l.net + 3);
          g.setFlag('pl_tomurai_te');
          return '七日ごとに、家の主が寺の畑を打ちに来た。四十九日が済んでも、月に一度は鍬を持って現れた。';
        }),
        Choice.h('葬いの講を作らせ、貧しい家の分は皆で賄わせる', '誰もが弔ってもらえる村になる。講の世話は、寺の仕事になる', () {
          l.net = _c(l.net + 5);
          l.fame += 2;
          g.setFlag('pl_tomurai_ko');
          g.mark('葬いの講を作り、貧しい家の弔いを村じゅうで賄わせた');
          return '家ごとに、月に米ひと握り。誰かが死ねば、講の蓄えから棺と布施が出る。はじめは渋った家も、己の親を送る段になって、黙った。';
        }),
        Choice.h('布施がなければ、引導だけ渡す', '寺の決まりは守られる。村の者は、見ている', () {
          l.gold += 2;
          l.fame -= 2;
          return '短い経を一つ読んで、帰った。野辺送りの列は、僧のないまま、畦道を行った。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 学寮 ----
  _s(
    'pl_gakuryo',
    20,
    72,
    (g) => _monk(g) && g.year >= 1606 && !g.hasFlag('pc_gakuryo'),
    (g, next) {
      final l = g.l;
      g.ask(
        '学寮',
        '本山が学寮を建て、諸国の寺から僧を集めて講釈を始めた。'
            '${_real(g) && g.year >= 1615 ? '${plKogi(g)}の法度にも、僧は学問に励めとある。' : ''}'
            '戦の世には、僧も槍を取り、寺は砦だった。いまは、学寮に幾年籍を置いたかで、寺の格と衣の色が決まるという。',
        [
          Choice.h('寺を弟子に預け、学寮に上る', '学は深まる。留守の寺と檀家が、気がかりだ', () {
            l.chi = _c(l.chi + 4);
            l.fame += 2;
            l.net = _c(l.net - 2);
            g.setFlag('pl_gakuryo');
            g.mark(g.age >= 50 ? '老いてから学寮に上り、若い僧と机を並べた' : '学寮に上り、宗の学問を修めた');
            return '${g.age >= 50 ? '孫ほどの歳の僧たちと、同じ講釈を聞いた。' : '諸国の訛りが入り交じる寮で、同じ講釈を聞いた。'}若い頃に聞きかじった教えの、根と幹が、はじめて繋がった。';
          }),
          Choice.h('見込みのある弟子を、代わりに送る', '寺は空けずに済む。弟子が戻ってくるとは、限らない', () {
            _pay(g, 5);
            l.net = _c(l.net + 4);
            g.setFlag('pl_gakuryo_deshi');
            return '路銀と添え状を持たせて、弟子を送り出した。年に一度、細かい字で埋まった文が届く。分からぬ言葉が、年ごとに増えていった。';
          }),
          Choice.h('学寮には行かず、村で経を読み続ける', '檀家は喜ぶ。寺の格は、上がらない', () {
            g.j(3);
            l.fame -= 1;
            g.setFlag('pl_gakuryo_no');
            return '「学のある坊さまより、来てくれる坊さまがええ」。村の婆にそう言われて、少し救われた。';
          }),
          if (l.chi >= 70)
            Choice.h('学寮に招かれ、講ずる側に回る', '名は諸国に知れる。言葉の一つひとつを、突かれることになる', () {
              l.fame += 6;
              l.chi = _c(l.chi + 1);
              g.setFlag('pl_gakuryo');
              g.setFlag('pl_gakuryo_ko');
              g.mark('学寮に招かれ、諸国の僧に講じた');
              return '百人の僧を前に、高座に上った。問いは鋭く、夜更けまで続いた。乱れた世を歩いて得たものを、はじめて言葉にして、人に手渡した。';
            }, via: '知'),
        ],
        after: next,
      );
    },
  ),
];

// ======================================================================
// 女性
// ======================================================================

List<SceneDef> _womenScenes() => [
  // ---- 留守宅（夫が府に詰める）----
  _s(
    'pl_rusu',
    20,
    65,
    (g) =>
        womanKind(g) == WomanKind.wife &&
        g.l.rank < 5 &&
        g.year >= 1605,
    (g, next) {
      final l = g.l;
      g.ask(
        '留守宅',
        '夫が、${plSeat(g)}詰めを命じられた。戻るのは、早くて一年先。国元の留守宅には、年寄りと子らと、借り上げで減った禄が残る。'
            '戦の留守なら、生きて帰るかを案じた。いまの留守は、帰るまでの勘定を案じる。',
        [
          Choice.h('機を織り、内職で家計を守る', '日々の米にはなる。夜なべで、目と肩がやられる', () {
            l.gold += 5;
            l.hp -= 3;
            g.setFlag('pl_rusu_hata');
            g.mark('夫の留守のあいだ、機を織って家計を守った');
            return '夜更けまで、筬の音を響かせた。織り上がった木綿は、問屋が裏口から引き取っていく。夫への文には、そのことは書かなかった。';
          }),
          Choice.h('月ごとに文を書き、家の様子を知らせる', '夫の心は、家から離れない。飛脚の代は、ばかにならない', () {
            _pay(g, 2);
            _spouseBond(g, 8);
            g.j(2);
            g.setFlag('pl_rusu_fumi');
            return '子の背丈、庭の柿、姑の咳。小さなことばかり書いた。返事は短かったが、帰ってきた夫は、文を一通残らず持ち帰っていた。';
          }),
          Choice.h('留守宅の女たちで寄り合い、助け合う', '心強い。噂話の輪にも、入ることになる', () {
            l.net = _c(l.net + 6);
            g.setFlag('pl_rusu_yoriai');
            return '味噌の貸し借り、子の預け合い、病人の看取り。組屋敷の女たちは、夫たちのいない一年を、互いの台所を行き来して越えた。';
          }),
          if (l.chi >= 55)
            Choice.h('禄の出入りを帳面に付け、借銭を一つずつ返す', '家の台所が立ち直る。切り詰めた膳に、年寄りは渋い顔をする', () {
              l.gold += 8;
              g.setFlag('pl_rusu_cho');
              g.mark('夫の留守のあいだ、帳面を付けて家の借銭を返した');
              return '米、味噌、薪、油、付け届け。一文残らず書き付けた。帰ってきた夫は、借銭の証文が半分に減っているのを見て、帳面を幾度も繰った。';
            }, via: '知'),
        ],
        after: next,
      );
    },
  ),

  // ---- 行儀見習い（泰平の奥）----
  _s(
    'pl_okuzutome',
    22,
    75,
    (g) =>
        g.l.female &&
        !_monk(g) &&
        g.active &&
        g.l.rank >= 2 &&
        g.l.rank <= 7 &&
        _lordAlive(g) &&
        g.year >= 1604,
    (g, next) {
      final l = g.l;
      void taught(String how) {
        g.setFlag('pl_oku_shinan');
        g.mark(how);
      }

      g.ask('行儀見習い', '奥に、町の大店や在の庄屋の娘たちが、行儀見習いに上がってくるようになった。戦の世には、奥に上がるのは人質か、家の浮沈を背負った娘だった。いまの娘たちは、嫁入りの箔を付けに来る。${l.rank >= 4 ? 'その娘たちを預かる役が、回ってきた。' : 'その娘たちの世話を、言い付かった。'}', [
        Choice.h('厳しく躾け、奥の作法を叩き込む', '奥の格は保たれる。泣いて宿下がりする娘も出る', () {
          l.merit += 6;
          l.fav = _c100(l.fav + 3);
          taught('泰平の奥で、行儀見習いの娘たちを厳しく仕込んだ');
          return '襖の開け閉て、膳の運び、口の利き方。半年で、娘たちの足音が消えた。親元からは、礼の品が届いた。';
        }),
        Choice.h('読み書きと歌も教え、宿下がりのあとに役立つようにする', '娘たちの身になる。奥の勤めの外だと、言う者もいる', () {
          l.net = _c(l.net + 5);
          l.merit += 3;
          taught('行儀見習いの娘たちに、読み書きと歌を教えた');
          return '夜、灯の下で、仮名の手本を書いてやった。宿下がりのあと、嫁ぎ先の帳面を任されたという文が、幾通か届いた。';
        }),
        Choice.h('親元の付け届けの多い娘から、良い役に付ける', '懐は潤う。奥の目は、節穴ではない', () {
          l.gold += 12;
          l.fav = _c100(l.fav - 4);
          g.setFlag('pl_oku_tsuketodoke');
          return '反物と菓子折が、部屋の隅に積まれた。老女が、廊下ですれ違いざまに、こちらの帯をちらりと見た。';
        }),
        if (l.mi >= 60)
          Choice.h('一人ひとりの気性を見て、合う勤めに就ける', '娘たちに慕われる。手間は、人の倍かかる', () {
            l.net = _c(l.net + 8);
            l.fame += 2;
            l.merit += 4;
            taught('行儀見習いの娘たちに慕われ、宿下がりのあとも文が絶えなかった');
            return '口の重い娘は書き物の役に、気の回る娘は取り次ぎの役に。宿下がりの日、娘たちは廊下に並んで、畳に手を突いた。';
          }, via: '魅'),
      ], after: next);
    },
  ),

  // ---- 駆け込み ----
  _s(
    'pl_enkiri',
    25,
    72,
    (g) =>
        g.l.female &&
        !_monk(g) &&
        g.l.rank < 8 &&
        !g.hasFlag('way_outlaw') &&
        g.year >= 1603,
    (g, next) {
      final l = g.l;
      void helped(String how) {
        l.fame += 3;
        g.setFlag('pl_enkiri_helped');
        g.mark(how);
      }

      g.ask(
        '駆け込み',
        '夜明け前、${l.rank >= 1 ? '家中の軽い身分の家の' : '近所の'}若い嫁が、${l.rank >= 1 ? '勝手口の' : ''}戸を叩いた。顔に、痣がある。夫に離縁を乞うても、去り状は書いてもらえない。'
            '${_real(g) ? '鎌倉の尼寺に駆け込んで幾年か勤めれば、縁が切れると聞いたという。' : '山の尼寺に駆け込んで幾年か勤めれば、縁が切れると聞いたという。'}'
            '追手は、もう近くまで来ているかもしれない。',
        [
          Choice.h('尼寺まで、付き添う', '女の足で幾日もかかる。途中で追いつかれれば、連れ戻される', () {
            l.hp -= 6;
            if (g.rng.chance(.7)) {
              g.j(4);
              helped('夫から逃れた女に付き添い、縁切りの尼寺まで送り届けた');
              return '裏道を選んで、幾日も歩いた。山門が見えたとき、嫁は草履を脱いで、門の内へ投げ込んだ。それで、駆け込みは成ったことになるのだという。';
            }
            g.j(-4);
            return '二日めの宿場で、追手に囲まれた。嫁は、駕籠に押し込まれて連れ戻された。こちらを振り返った目を、長く忘れられなかった。';
          }),
          Choice.h('家にかくまい、仲人と親元を呼んで話をつける', '筋道は立つ。夫の家が、黙って引き下がるかどうか', () {
            if (g.rng.chance(.6)) {
              l.net = _c(l.net + 5);
              helped('夫から逃れた女をかくまい、離縁の話をまとめさせた');
              return '嫁の父親と仲人が、夫の家に乗り込んだ。持参の道具を返させ、去り状を書かせた。嫁は、里の家の土間で、声を上げて泣いた。';
            }
            l.net = _c(l.net - 3);
            return '夫の家は、「家の恥を外に出した」と逆に怒鳴り込んできた。嫁は、引きずられるようにして帰っていった。';
          }),
          Choice.h('辛抱するよう諭して、帰す', '揉め事には巻き込まれない。あの痣を、また見ることになる', () {
            g.j(-4);
            g.setFlag('pl_enkiri_sent');
            return '「どこの家も、そんなものだ」。己の口から出た言葉が、ひどく古びて聞こえた。嫁は黙って頭を下げ、暗い道を戻っていった。';
          }),
          if (l.mi >= 60)
            Choice.h('夫の家に出向き、去り状を書かせる', '話が早い。相手は、酒癖の悪い男だ', () {
              l.net = _c(l.net + 4);
              helped('乱暴な夫の家に出向き、去り状を書かせた');
              return '土間に立ったまま、近所じゅうに聞こえる声で、痣の数を数え上げた。男は青くなり、震える手で去り状を書いた。';
            }, via: '魅'),
        ],
        after: next,
      );
    },
  ),

  // ---- 女手（後家の商い・田）----
  _s(
    'pl_goke',
    35,
    75,
    (g) =>
        g.l.female &&
        g.l.rank == 0 &&
        !g.l.married &&
        g.l.kids > 0 &&
        (_town(g) || _villager(g)) &&
        g.year >= 1603,
    (g, next) {
      final l = g.l;
      final town = _town(g);
      final what = town ? '店' : '田';
      void own(String how) {
        g.setFlag('pl_goke_own');
        g.mark(how);
      }

      g.ask('女手', '連れ合いのいない身で、$whatは女手ひとつで守ってきた。親類が寄り合って言う。女の名では、${town ? '仲間の寄り合いにも出られず、掛けの証文も軽く見られる' : '村の寄り合いに席がなく、水の番も回ってこない'}。後見を立てるか、婿を取れ、と。', [
        Choice.h('己の名のまま、切り回し続ける', '誰の指図も受けない。世間の風は、冷たい', () {
          if (g.rng.chance(.5 + l.sei / 200)) {
            l.gold += 10;
            l.fame += 3;
            own('女手ひとつで、己の名のまま$whatを守り通した');
            return '${town ? '掛けの取り立てにも、仕入れの掛け合いにも、己で出向いた。' : '水の番にも、道普請にも、己で出た。'}はじめは鼻で笑った男たちが、三年めには、向こうから挨拶をするようになった。';
          }
          _pay(g, 5);
          g.setFlag('pl_goke_own');
          return '${town ? '掛けを踏み倒され、' : '水を後回しにされ、'}苦しい年が続いた。それでも、名は誰にも渡さなかった。';
        }),
        Choice.h('後見を立て、表のことは任せる', '世間は静かになる。帳面を、他人が開くことになる', () {
          l.gold += 3;
          g.j(-2);
          g.setFlag('pl_goke_koken');
          return '${town ? '古い番頭' : '亡き人の弟'}が、表に立つようになった。寄り合いから戻るたび、決まったことだけを、あとから聞かされた。';
        }),
        Choice.h('子が一人前になるまでと期限を切り、帳面は渡さない', '親類の顔は立つ。期限が来れば、また同じ話になる', () {
          l.net = _c(l.net + 2);
          g.setFlag('pl_goke_own');
          return '「あの子が継ぐまでの、預かりです」。そう言うと、親類は顔を見合わせて引き下がった。帳面は、枕元に置いて寝た。';
        }),
        if (l.sei >= 60)
          Choice.h('寄り合いに出向き、名代としての席を認めさせる', '筋道を立てれば、通るかもしれない。前例は、ない', () {
            l.fame += 4;
            l.net = _c(l.net + 5);
            own('女の身で、寄り合いに名代としての席を認めさせた');
            return '${town ? '納めてきた冥加の銭' : '納めてきた年貢と出してきた人足'}を、年ごとに書き上げて持っていった。「これだけ負うてきた家に、席がないのは道理に合いませぬ」。年寄りたちは、長いこと黙ってから、座を一つ空けた。';
          }, via: '政'),
      ], after: next);
    },
  ),

  // ---- 娘の奉公（御殿へ行儀見習いに）----
  _s(
    'pl_musume_hoko',
    28,
    70,
    (g) =>
        !_monk(g) &&
        g.year >= 1606 &&
        ((g.l.rank >= 1 && g.l.rank <= 4) || (_town(g) && g.l.gold >= 40)) &&
        !g.l.people.containsKey('奉公に出た娘') &&
        g.l.daughterAged(g.year, 11, 16) != null,
    (g, next) {
      final l = g.l;
      final d = l.daughterAged(g.year, 11, 16)!;
      final name = d.name;
      void send(int cost) {
        _pay(g, cost);
        g.meet('奉公に出た娘', name, 60);
        g.setFlag('pl_musume_hoko');
        g.mark('$nameを、御殿奉公に上がらせた');
      }

      g.ask('娘の奉公', '$nameに、御殿奉公の口が掛かった。${l.rank >= 1 ? '家老の奥方' : '殿の姫君'}の側に上がり、行儀と手跡と琴を仕込まれる。幾年か勤めて宿下がりすれば、良い縁談が来る。支度の着物と付け届けは、こちら持ちだ。', [
        Choice.h('支度を整えて、上がらせる', '$nameの先々は明るくなる。家の蓄えは、目に見えて減る', () {
          send(12);
          return '誂えた小袖は、家の誰の着物より上等だった。駕籠に乗る前、$nameは玄関で、作法どおりの辞儀をして見せた。もう、半分は御殿の者だった。';
        }),
        Choice.h('手元に置き、家で仕込む', '銭は掛からない。良い縁談の口は、狭くなる', () {
          g.j(3);
          g.setFlag('pl_musume_ie');
          return '断りの口上は、病がちということにした。$nameは、台所で大根を刻みながら、時折、遠くを見るような顔をした。';
        }),
        Choice.h('$nameの望みを聞く', '恨まれることはない。娘ごころは、分からぬものだ', () {
          if (g.rng.chance(.5)) {
            send(8);
            return '$nameは、目を輝かせて「参ります」と言った。支度は切り詰めたが、当人は気にも留めなかった。';
          }
          g.j(2);
          g.setFlag('pl_musume_ie');
          return '$nameは、畳の目を数えるようにうつむいて、「家にいとうございます」と言った。それで、話は終わった。';
        }),
      ], after: next);
    },
  ),
];

// ======================================================================
// 忍び・野の者
// ======================================================================

List<SceneDef> _shadowScenes() => [
  // ---- 番の夜（番士になった忍びの続き）----
  _s('pl_ban', 25, 84, (g) => !_monk(g), (g, next) {
    final l = g.l;
    final son = l.sonAged(g.year, 10, 30);
    g.ask(
      '番の夜',
      '城の門の番に就いて、幾年かになる。夜ごと、同じ塀を見回り、同じ刻に拍子木を打つ。忍び込む者など、一人も来ない。里で仕込まれた技は、使わぬまま錆びていく。'
          '${son != null ? '${son.name}が、技を教えてくれと言う。' : '同じ番の若い者が、昔の技を見せてくれとせがむ。'}',
      [
        Choice.h('技を、一つ残らず伝える', '技は絶えない。使う当てのない技を、背負わせることになる', () {
          g.setFlag('pl_waza_tsutae');
          g.mark('使う当てのない忍びの技を、次の代に伝えた');
          return '月のない夜を選んで、塀の越え方、錠の外し方、息の殺し方を教えた。${son != null ? son.name : '若い者'}は飲み込みが早かった。それが、少し恐ろしかった。';
        }),
        Choice.h('塀の越え方ではなく、塀の守り方として教える', '勤めの役に立つ。里の者が聞けば、嘆くだろう', () {
          l.gold += 3;
          l.fame += 2;
          g.setFlag('pl_waza_mamori');
          g.mark('忍びの技を、城を守る心得に作り替えて教えた');
          return '「己なら、どこから入るか」。そう考えさせて、塀の弱い所を一つずつ塞がせた。番頭が、その心得を書き留めさせた。';
        }),
        Choice.h('技は、己の代で終わらせる', '誰も、あの暮らしを継がずに済む。里の名は、消える', () {
          g.j(2);
          g.setFlag('pl_waza_owari');
          return '「忘れた」と言って、笑ってごまかした。その夜、非番の暗がりで、ひとり塀を越えてみた。体は、まだ覚えていた。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 人改め（野の者の身の振り方）----
  _s('pl_mushuku', 20, 75, (g) => _outlaw(g) && !_ninja(g) && g.year >= 1614, (g, next) {
    final l = g.l;
    void katagi(String how) {
      g.setFlag('pl_katagi');
      g.mark(how);
    }

    g.ask(
      '人改め',
      '町にも村にも、人を改める帳ができた。'
          '${_era(g, 'どこの寺の檀那か、どこの村の者か。答えられぬ者は、宿も借りられない。', 'どこの誰とも帳に載らぬ者は、宿も借りられず、日雇いの口もない。', '街道には番所が立ち、宿なしは見つかりしだい追い払われる。')}'
          '乱れた世の隙間で生きてきた身に、もう隙間がない。',
      [
        Choice.h('口入れ屋を頼り、武家屋敷の中間奉公に入る', '屋根と飯は付く。頭を下げて暮らすことになる', () {
          l.gold += 5;
          g.setFlag('pl_chugen');
          katagi('野の暮らしを捨て、口入れ屋の世話で中間奉公に入った');
          return '口入れ屋は、素性を聞かなかった。請け人の判も、銭で買えた。紺の看板を着て、槍持ちの列の後ろを歩いた。';
        }),
        Choice.h('金山へ流れ、金掘りになる', '素性は問われない。坑の中で、体は早く潰れる', () {
          l.gold += 12;
          l.hp -= 10;
          g.setFlag('pl_kanayama');
          katagi('野の暮らしを捨て、山の金掘りになった');
          return '山の者は、互いの昔を尋ねない。鑿と槌を握り、灯ひとつで岩の奥へ潜った。銭にはなった。咳が、止まらなくなった。';
        }),
        Choice.h('街道の人足に紛れ、荷を担ぐ', 'その日暮らしだ。顔なじみは、できる', () {
          l.gold += 4;
          l.net = _c(l.net + 3);
          katagi('野の暮らしを捨て、街道の人足になった');
          return '宿場の問屋場で、荷を割り振られるのを待つ。昔は襲う側だった荷駄を、いまは担いで峠を越える。';
        }),
        Choice.h('山に籠もり、帳の外で生き続ける', '誰にも頭は下げない。冬は、年ごとにこたえる', () {
          l.hp -= 4;
          g.j(1);
          g.setFlag('pl_yama');
          return '炭焼きの捨てた小屋に、住み着いた。里へ下りるのは、年に二度。帳の上では、とうに死んだ者になっている。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 昔の仲間（堅気になった者の続き）----
  _s('pl_mukashi_nakama', 22, 80, (g) => !_monk(g), (g, next) {
    final l = g.l;
    g.ask('昔の仲間', '夜更けに、戸を叩く者がいる。昔、同じ山で暮らした男だった。追われているという。「一晩でいい」。${g.hasFlag('pl_chugen') ? 'ここは、武家屋敷の長屋だ。' : ''}見つかれば、己の素性も洗われる。', [
      Choice.h('一晩だけ泊め、夜明け前に握り飯を持たせて出す', '昔の恩は返せる。誰かに見られていれば、己も終わりだ', () {
        if (g.rng.chance(.85)) {
          g.j(3);
          g.setFlag('pl_nakama_hid');
          g.mark('堅気になってからも、追われる昔の仲間を一晩かくまった');
          return '男は土間の隅で、泥のように眠った。夜明け前、握り飯を懐に入れて、何も言わずに出ていった。その後のことは、知らない。';
        }
        _pay(g, 10);
        l.fame -= 3;
        g.setFlag('pl_nakama_hid');
        return '隣の者が、見ていた。番所に呼ばれ、三日留め置かれた。昔のことは、どうにか知らぬ存ぜぬで通した。過料は、重かった。';
      }),
      Choice.h('銭を握らせて、戸を閉める', '関わらずに済む。あの目は、忘れられない', () {
        _pay(g, 4);
        g.j(-3);
        return '戸の隙間から、銭を差し出した。男はそれを受け取り、少し笑って、闇に消えた。';
      }),
      Choice.h('番所に、知らせる', '己の身は固まる。あの男がどうなるかは、分かっている', () {
        l.gold += 6;
        g.j(-8);
        g.setFlag('pl_nakama_sold');
        return '褒美の銭が出た。それで酒を買ったが、少しも酔えなかった。同じ山で、同じ鍋をつついた男だった。';
      }),
    ], after: next);
  }),
];

// ======================================================================
// 乱世を知る者
// ======================================================================

List<SceneDef> _veteranScenes() => [
  // ---- 首の話（戦を知らぬ子らに）----
  _s('pl_gatari', 50, 84, (g) => _veteran(g) && g.year >= 1618, (g, next) {
    final l = g.l;
    final who = l.people['孫']?.name ?? '近所の子ら';
    g.ask(
      '首の話',
      '$whoが、戦の話をせがむ。「首を取ったことは、あるの」。子らにとって、戦は軍記読みの語る晴れやかな絵巻だ。'
          '${_era(g, '', '戦を己の目で見た者は、年ごとに減っていく。', '戦を己の目で見た者は、このあたりでは、もう己ひとりになった。')}'
          '目を輝かせて、こちらを見ている。',
      [
        Choice.h('手柄話を、少し大きくして聞かせる', '子らは喜ぶ。話すうちに、己でも真と思えてくる', () {
          g.j(4);
          l.fame += 1;
          g.setFlag('pl_told_big');
          return '敵の数は倍に、己の槍は三間に伸びた。子らは息を呑み、もう一度、もう一度とせがんだ。';
        }),
        Choice.h('飢えと泥と、死んだ者の顔を、ありのまま話す', '子らは黙り込む。それでも、知っておくべきことだ', () {
          g.j(-1);
          l.fame += 2;
          g.setFlag('pl_told_true');
          g.mark('戦を知らぬ子らに、戦場のありのままを語って聞かせた');
          return '首は重いこと、三日も経てば臭うこと、取った相手に母親がいたこと。子らは、途中から誰も口を利かなくなった。一人が、黙ってこちらの袖を握った。';
        }),
        Choice.h('「忘れた」と笑って、話を逸らす', '思い出さずに済む。子らは、つまらなそうだ', () {
          g.setFlag('pl_told_none');
          return '「年寄りは、昨日の飯も忘れる」。子らは口を尖らせて、表へ駆けていった。忘れてなど、いなかった。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 古傷 ----
  _s('pl_furukizu', 48, 84, (g) => _veteran(g) && g.year >= 1603, (g, next) {
    final l = g.l;
    g.ask('古傷', '寒い朝、古傷が疼いて、床から起き上がれなかった。槍を受けた脇腹だ。あの日、隣にいた男は、傷ひとつ負う間もなく死んだ。医者は、温めるほかないと言う。戦は絶えても、戦の残したものは、体の中で生きている。', [
      Choice.h('湯治に出る', '痛みは和らぐ。銭と日数が掛かる', () {
        _pay(g, 5);
        _heal(g, 20);
        g.j(3);
        g.setFlag('pl_kizu_yu');
        return '湯の中で、同じような傷を持つ年寄りと隣り合った。どこの戦かは、互いに聞かなかった。ただ、黙って湯に浸かった。';
      }),
      Choice.h('痛みを押して、いつもどおり働く', '暮らしは回る。傷は、年ごとに重くなる', () {
        l.hp -= 6;
        l.gold += 3;
        g.setFlag('pl_kizu_oshi');
        return '晒をきつく巻いて、表へ出た。若い者には、腰を痛めたと言っておいた。';
      }),
      Choice.h('傷のいわれを、家の者に初めて話す', '胸のつかえが下りる。聞かされるほうは、重い', () {
        g.j(3);
        l.net = _c(l.net + 2);
        g.setFlag('pl_kizu_told');
        g.mark('古傷のいわれを、老いて初めて家の者に話した');
        return 'どの戦の、どの朝の、誰の槍だったか。話し終えると、家の者は何も言わずに、傷の上に温めた石を当ててくれた。';
      }),
      if (g.has('herbal'))
        Choice.h('己で薬を合わせ、近所の古傷持ちにも分ける', '薬草の心得が生きる。山へ採りに行くのが、ひと苦労だ', () {
          _heal(g, 15);
          l.net = _c(l.net + 5);
          l.fame += 2;
          g.setFlag('pl_kizu_kusuri');
          return '陣中で覚えた膏薬を、久しぶりに練った。噂を聞いて、足を引きずる年寄りが、幾人も戸口に並んだ。皆、同じ頃の傷だった。';
        }, via: '薬の心得'),
    ], after: next);
  }),

  // ---- 同じ戦場にいた男 ----
  _s('pl_teki', 45, 84, (g) => _veteran(g) && !g.l.female && g.year >= 1603, (g, next) {
    final l = g.l;
    g.ask('同じ戦場', '${l.rank >= 1 && g.active ? '手伝い普請の丁場' : '街道の茶店'}で、隣り合った男の国訛りに、覚えがあった。話すうち、同じ戦場の、向かい側にいたと知れた。あの日、こちらの槍先にいたかもしれぬ男が、いまは同じ握り飯を食っている。', [
      Choice.h('酒を酌み交わし、あの日の話をする', '胸の底のものが、ほどけるかもしれない。古い怒りが、戻るかもしれない', () {
        g.j(5);
        l.net = _c(l.net + 4);
        g.setFlag('pl_foe_sake');
        g.mark('かつての敵と酒を酌み交わし、同じ戦場の話をした');
        return '「あの土手の上の鉄砲は、お主らか」「あれで、兄が死んだ」。しばらく黙り、それから、互いの盃に酒を注いだ。別れ際、男は深く頭を下げた。';
      }),
      Choice.h('何も言わず、会釈だけして別れる', '波風は立たない。聞けたはずのことは、聞けずじまいだ', () {
        g.j(1);
        return '握り飯を食い終え、互いに会釈して、別々の道へ出た。振り返ると、男も振り返っていた。';
      }),
      Choice.h('あの戦で死んだ者のことを、尋ねる', '知りたかったことが、分かるかもしれない。知らぬほうが良かったことも', () {
        if (g.rng.chance(.5)) {
          g.j(4);
          g.setFlag('pl_foe_asked');
          return '行方の知れなかった朋輩の最期を、男は見ていた。「見事なものだった」。それだけで、長年のつかえが、少し下りた。';
        }
        g.j(-3);
        return '男の口から出たのは、聞きたくなかった話だった。朋輩は、逃げるところを背から突かれたのだという。茶が、苦くなった。';
      }),
    ], after: next);
  }),

  // ---- 具足櫃 ----
  _s(
    'pl_bugu',
    45,
    84,
    (g) =>
        !_monk(g) &&
        !g.l.female &&
        (g.l.maxRank >= 1 || _veteran(g)) &&
        g.year >= 1616,
    (g, next) {
      final l = g.l;
      g.ask(
        '具足櫃',
        '納戸の具足櫃を、久しぶりに開けた。威の糸は色あせ、鼠が籠手をかじっている。古道具屋が、買い取ると言ってきた。戦のない世に、古い具足は場所ふさぎだと、家の者は言う。'
            '${_era(g, '', '近ごろは、飾って見せるためのきらびやかな具足を、新しく誂える家もあるという。', '近ごろの若い者は、具足の着け方も知らない。')}',
        [
          Choice.h('売り払う', '銭になり、納戸も空く。二度と、手元には戻らない', () {
            l.gold += 10;
            g.j(-2);
            g.setFlag('pl_bugu_sold');
            return '古道具屋は、胴の矢の跡を指でなぞって、値を少し引いた。荷車に積まれていく櫃を、門口で見送った。';
          }),
          Choice.h('手入れをして、家の宝として残す', '子や孫に、己の生きた世を残せる。手入れは、死ぬまで続く', () {
            _pay(g, 3);
            g.setFlag('pl_bugu_kept');
            g.mark('戦のない世にも、古い具足の手入れを欠かさなかった');
            return '威の糸を替え、錆を落とし、油を引いた。床の間に据えると、家の者は、少し遠巻きにそれを眺めた。';
          }),
          Choice.h('寺に納め、討った者と討たれた者の供養を頼む', '具足も己も、役目を終える。家には、何も残らない', () {
            _pay(g, 3);
            g.j(4);
            l.fame += 1;
            g.setFlag('pl_bugu_tera');
            g.mark('古い具足を寺に納め、敵味方の供養を頼んだ');
            return '住持は、胴の内側に書かれた名を読み上げてから、経を上げた。具足は、本堂の隅の暗がりに据えられた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 静かな夜（戦のない世への戸惑いと安堵）----
  _s('pl_tomadoi', 45, 84, (g) => g.year >= (kPeaceStart[worldLine(g)] ?? 1601) + 15, (g, next) {
    final l = g.l;
    final String fear;
    if (_villager(g)) {
      fear = '田を焼かれる心配も、人を攫われる心配もない。';
    } else if (_town(g)) {
      fear = '店を焼かれる心配も、矢銭を取り立てられる心配もない。';
    } else if (_monk(g)) {
      fear = '寺を焼かれる心配も、骸を運び込まれる朝もない。';
    } else {
      fear = '陣触れの太鼓は、もう鳴らない。';
    }
    g.ask(
      '静かな夜',
      '夜半に、目が覚めた。${_era(g, '戦が絶えてから、もう幾年にもなる。', '戦が絶えてから、もう幾年にもなる。', '戦が絶えてから、もう一世代が過ぎた。')}'
          '犬が吠えても、半鐘が鳴っても、誰も具足を探さない。$fear'
          'それなのに、枕元に${g.canFight ? '刀' : '履物と包み'}を置かずには眠れない己がいる。',
      [
        Choice.h('枕元の備えを、今夜から片付ける', '戦は終わったのだと、己に言い聞かせる。体が、それを信じるかどうか', () {
          g.j(5);
          g.setFlag('pl_ando');
          g.mark('戦のない世に慣れ、枕元の備えを片付けた');
          return 'はじめの幾晩かは、かえって眠れなかった。ひと月のち、鶏の声で目が覚めた。朝まで一度も起きなかったのは、いつ以来か、思い出せなかった。';
        }),
        Choice.h('備えは、死ぬまで解かない', '用心に越したことはない。安らぐ夜は、来ない', () {
          l.bu = _c(l.bu + 1);
          g.j(-1);
          g.setFlag('pl_sonae');
          return '世が治まったと聞くのは、これが初めてではない。枕元のものを確かめてから、もう一度、目を閉じた。';
        }),
        Choice.h('眠れぬ夜に、死んだ者たちの名を数える', '忘れずにいられる。数えるほど、夜は長くなる', () {
          g.j(1);
          g.setFlag('pl_kazoe');
          g.mark('眠れぬ夜ごとに、乱世で死んだ者たちの名を数えた');
          return '親、兄弟、朋輩、名も知らぬまま見送った者。数え終わる前に、東の空が白んだ。この静かな夜を、あの者たちは知らない。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 軍記読み ----
  _s('pl_gunki', 50, 84, (g) => _veteran(g) && !_monk(g) && g.year >= 1624, (g, next) {
    final l = g.l;
    g.ask('軍記読み', '辻で、軍記読みが人を集めている。${_real(g) ? '近ごろ板行された、信長公の一代記だという。' : '先の世の合戦の物語だという。'}聞いていると、己のいたあの戦の段になった。話は面白い。だが、あの朝は霧など出ていなかったし、あの将は、あんな立派な口上を述べなかった。', [
      Choice.h('黙って最後まで聞き、銭を投げる', '波風は立たない。あれが、真として残っていく', () {
        _pay(g, 1);
        g.j(3);
        g.setFlag('pl_gunki_heard');
        return '見てきたような嘘を、気持ちよく聞いた。死んだ朋輩が、絵巻の中の勇士のように語られるのは、悪い気がしなかった。';
      }),
      Choice.h('「そこは違う」と、声を上げる', '真は伝わるかもしれない。野暮な年寄りと、笑われるかもしれない', () {
        if (g.rng.chance(.5)) {
          l.fame += 2;
          l.net = _c(l.net + 3);
          g.setFlag('pl_gunki_tadashi');
          return '人垣が、こちらを向いた。「爺さま、見たのか」。軍記読みは扇を置き、「ならば、続きはこのお方に」と場を譲った。日の暮れるまで、語らされた。';
        }
        g.j(-2);
        return '「爺さま、話の腰を折るな」。人垣から、笑いと野次が飛んだ。軍記読みは扇で台を打ち、何事もなかったように先を続けた。';
      }),
      Choice.h('家に帰り、子や孫に本当のところを話す', '家の中には、真が残る。家の外には、出ていかない', () {
        g.j(2);
        l.net = _c(l.net + 2);
        g.setFlag('pl_gunki_ie');
        return '「書物には、こう書いてあるそうだが」と前置きして、見たままを話した。孫は、どちらが本当かと、首をかしげていた。';
      }),
      if (l.chi >= 55)
        Choice.h('見たままを聞き書きにまとめ、寺に納める', '書いたものは、己より長く残る。筆を執れば、思い出したくないことも出てくる', () {
          l.fame += 4;
          l.hp -= 2;
          g.setFlag('pl_kikigaki');
          g.mark('軍記の語らぬ戦のありさまを、聞き書きにして寺に納めた');
          return '霧のなかった朝のこと、口上など述べる暇のなかった将のこと、名も残らぬ雑兵の死にざま。綴じた一冊を、住持は経蔵の棚に納めた。';
        }, via: '知'),
    ], after: next);
  }),
];
