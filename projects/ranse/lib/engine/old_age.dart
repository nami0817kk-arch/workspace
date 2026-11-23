import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 晩年（五十歳ごろから）と隠居の暮らしの岐路と重点（2026-11-23）。id・旗は `oa_`。
///
/// 長く生きた人生ほど波乱に富んだ人生、というコンセプトなのに、晩年の岐路は `ways.dart` の
/// 「壮年と晩年」（子の門出・隠居・旧友の死・孫・老いての出陣・老いの病・辞世）と、
/// 隠居の重点三つ（子や孫と過ごす・書と歌・旧知を訪ねる）くらいしかなかったので足した。
///
/// - **重点6**（[oldAgeFocusOptions]。`adultFocusOptions` が暮らしと嗜みのうしろに足す）:
///   庭を造る（隠居した元侍・商人・大名）／若い者に昔語りをする（五十五から誰でも）／
///   寺に寄進して菩提を弔う（隠居か六十から）／伊勢・熊野・高野へ詣でる（隠居）／
///   家の来し方を書き残す（字の読める隠居か、五十五からの侍・商人）／孫に手習いを教える（孫のいる五十五から）。
///   仏門の人には出さない（寺の暮らしの重点がある）。1年に足すのは隠居で2つ、隠居でない人は1つまで
///   （[oldAgeFocusCap]）。当てはまるかは乱数を使わずに決め（[oldAgeTags]）、五十前の人生では乱数を使わない。
///   はじめて選んだ年は始めの岐路、2回目からは半分ほどの年に `<id>_again`（`pastimes.dart` と同じ作り）。
/// - **晩年の岐路**（[kOldAgeSceneIds]。一生に一度）: 家督を譲った子との行き違い・家の危機に呼び戻される・
///   昔の敵や恩人の消息・葬いの支度・形見分け・遺言・昔の悪事の報い・孫の縁談・老いらくの恋・物忘れ・
///   最後の旅・幼い日の面影・古戦場・老舗の行方・老僧・老いた忍び・若い殿の相談・老いた信者・村の長老・嫁との間。
///   若い頃の旗（好敵手・師・手習い・戦・商い・仏門・忍び・乱取りなど）で筋が分かれるものは、
///   その旗がなければ出ない（[kOldAgeRoots]。テストが使う）。
/// - 死ぬ結果は四つで稀（呼び戻されて陣頭に立つ・昔の恨みを知らぬ顔・影を追う老いた忍び・最後の旅の宿で天寿）。

/// 晩年の岐路と重点が出はじめる歳。
const kOldAgeMinAge = 50;

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;

bool _retired(Game g) => g.hasFlag('retired');
bool _monk(Game g) => g.hasFlag('priesthood');
bool _merchantPast(Game g) =>
    g.hasFlag('way_merchant') || g.l.cls.id == 'merchant';
bool _lordAlive(Game g) =>
    g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);
bool _hasMago(Game g) =>
    g.l.people.containsKey('孫') ||
    g.hasFlag('grandchild') ||
    g.hasFlag('fa_mago_name');

String _season(Game g) => g.l.t % 2 == 0
    ? g.rng.pick(['梅のほころぶ頃', '若葉の頃', '梅雨の晴れ間'])
    : g.rng.pick(['稲刈りの済んだ頃', '木枯らしの吹く頃', '雪の便りの届く頃']);

/// 回を重ねた年の書き出し（2回目は [second]、以降は [more] から一つ。{季} は時節）。
String _intro(Game g, String tag, String second, List<String> more) =>
    (_n(g, tag) <= 2 ? second : g.rng.pick(more)).replaceAll('{季}', _season(g));

/// 孫（縁のある孫がいればその名）。
String _mago(Game g) => g.l.people['孫']?.name ?? '孫';

void _magoBond(Game g, int n) {
  final p = g.l.people['孫'];
  if (p != null) p.bond = _c100(p.bond + n);
}

/// 家を継いだ子（嫡男・子・娘の順）。
String _heirName(Game g) =>
    g.l.people['嫡男']?.name ??
    g.l.people['子']?.name ??
    g.l.people['養子']?.name ??
    '跡を継いだ子';

void _heirBond(Game g, int n) {
  final p = g.l.people['嫡男'] ?? g.l.people['子'] ?? g.l.people['養子'];
  if (p != null) p.bond = _c100(p.bond + n);
}

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

/// 晩年の重点が出うる人（五十から・仏門でない）。
bool _elder(Game g) => g.age >= kOldAgeMinAge && !_monk(g);

final _focuses = <_Focus>[
  // ---- 庭を造る（隠居した元侍・商人・大名）----
  _Focus(
    'oa_garden',
    (g) =>
        _elder(g) &&
        _retired(g) &&
        (g.l.maxRank >= 3 || _merchantPast(g)),
    (g) => FocusDef('oa_garden', '隠居所の庭に、石を据え木を植える', '心が落ち着く。石も木も銭がかかる', (g) {
      _pay(g, 3);
      _heal(g, 10);
      g.j(5);
    }, forced: _forcedFor(g, 'oa_garden')),
  ),
  // ---- 若い者に昔語りをする（五十五から誰でも）----
  _Focus(
    'oa_tales',
    (g) => _elder(g) && g.age >= 55,
    (g) => FocusDef('oa_tales', '若い者に昔語りをする', '若い者が集まってくる。話すほど昔が近くなる', (g) {
      g.l.net += g.rng.range(1, 2);
      if (g.rng.chance(.3)) g.l.fame += 1;
      g.j(4);
    }, forced: _forcedFor(g, 'oa_tales')),
  ),
  // ---- 寺に寄進し、菩提を弔う（隠居か六十から）----
  _Focus(
    'oa_kuyo',
    (g) => _elder(g) && (_retired(g) || g.age >= 60),
    (g) => FocusDef('oa_kuyo', '寺に寄進し、亡き人の菩提を弔う', '胸のつかえが下りる。蔵の銭は減る', (g) {
      _pay(g, 4);
      g.j(4);
      if (g.rng.chance(.3)) g.l.un = _c(g.l.un + 1);
    }, forced: _forcedFor(g, 'oa_kuyo')),
  ),
  // ---- 伊勢・熊野・高野へ詣でる（隠居）----
  _Focus(
    'oa_pilgrim',
    (g) => _elder(g) && _retired(g) && !g.hasFlag('way_outlaw'),
    (g) => FocusDef('oa_pilgrim', '伊勢や熊野へ詣でる旅に出る', '一生の思い出になる。老いた足に旅はこたえる', (g) {
      _pay(g, 4);
      g.l.hp -= 6;
      g.l.net += 1;
      g.j(8);
    }, forced: _forcedFor(g, 'oa_pilgrim')),
  ),
  // ---- 家の来し方を書き残す（字の読める隠居か、五十五からの侍・商人）----
  _Focus(
    'oa_record',
    (g) =>
        _elder(g) &&
        g.l.chi >= 40 &&
        (_retired(g) ||
            (g.age >= 55 && (g.l.rank >= 3 || g.hasFlag('way_merchant')))),
    (g) => FocusDef('oa_record', '家の来し方を書き残す', '子孫に伝わる。筆は思うように進まない', (g) {
      if (g.rng.chance(.4)) g.l.chi = _c(g.l.chi + 1);
      if (g.rng.chance(.3)) g.l.fame += 1;
      g.j(2);
    }, forced: _forcedFor(g, 'oa_record')),
  ),
  // ---- 孫に手習いを教える（孫のいる五十五から）----
  _Focus(
    'oa_tenarai',
    (g) =>
        _elder(g) &&
        g.age >= 55 &&
        _hasMago(g) &&
        !g.hasFlag('way_outlaw'),
    (g) => FocusDef('oa_tenarai', '孫に手習いを教える', '孫との絆が深まる。目が霞んで手本が書きにくい', (g) {
      g.j(6);
      _magoBond(g, 5);
    }, forced: _forcedFor(g, 'oa_tenarai')),
  ),
];

/// その年に足せる晩年の重点の数。隠居は2つ、隠居でない人は1つ。
int oldAgeFocusCap(Game g) => _retired(g) ? 2 : 1;

/// 歳・身分・道に合う晩年の重点の tag（乱数を使わない。テストも使う）。
List<String> oldAgeTags(Game g) => [
  for (final f in _focuses)
    if (f.ok(g)) f.tag,
];

/// その年に出す晩年の重点（[oldAgeFocusCap] まで。多ければその年に出すものを無作為に選び、並びは保つ）。
List<FocusDef> oldAgeFocusOptions(Game g) {
  final cand = [
    for (final f in _focuses)
      if (f.ok(g)) f,
  ];
  final cap = oldAgeFocusCap(g);
  if (cand.length > cap) {
    final keep = <int>{};
    while (keep.length < cap) {
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
// 筋（若い頃の旗で出る岐路）
// ======================================================================

/// 若い頃の旗で筋が分かれる岐路 → 出るのに要る旗（どれか一つ）。
/// `role:<役割>` は縁のある人、`cls:<身分>` は生まれの身分。テストも使う。
const kOldAgeRoots = <String, List<String>>{
  'oa_old_foe': [
    'role:好敵手',
    'bd_rv_slew',
    'bd_rv_dead',
    'bt_slew_general',
    'tal_night_raid',
    'bt_spared_foe',
  ],
  'oa_benefactor': [
    'role:師',
    'bd_ms_dead',
    'tera_diligent',
    'sword_lessons',
  ],
  'oa_sin': [
    'randori',
    'al_sold_captive',
    'al_hyoro_skim',
    'tal_bribe',
    'e3_bribe_hidden',
    'tf_sashi_hidden',
    'tf_kome_hoard',
    'killed_friend',
    'turncoat',
    'oath_breaker',
    'al_hyoro_framed',
    'al_kubi_lied',
    'sh_poisoner',
    'sh_hired_both',
  ],
  'oa_mago_match': ['role:孫', 'grandchild', 'fa_mago_name'],
  'oa_child_days': [
    'met_nobunaga',
    'saw_nobunaga',
    'met_kenshin',
    'dog',
    'saw_battle',
    'tera_friends',
    'tera_diligent',
  ],
  'oa_battlefield': [
    'first_battle',
    'bt_slew_general',
    'bt_rearguard_done',
    'bt_ambush_win',
    'tal_beloved_captain',
  ],
  'oa_shop': [
    'way_merchant',
    'goyo',
    'tf_norenwake',
    'tf_heir_own',
    'tf_heir_muko',
    'lifelong_trade',
    'cls:merchant',
  ],
  'oa_monk': ['priesthood'],
  'oa_shinobi': [
    'nukenin',
    'sh_n_heir',
    'sh_n_elder',
    'sh_iga_fought',
    'sh_herb_poison',
    'cls:ninja',
  ],
  'oa_faith': ['kirishitan', 'kirishitan_ok'],
  'oa_village': [
    'shoya',
    'tf_so_role',
    'tf_so_rule',
    'tf_genmen_won',
    'tf_murauke',
    'new_field',
    'tf_seki_built',
    'e2_ikki_eased',
    'tal_ikki_head',
  ],
  'oa_heir_rift': ['role:嫡男', 'role:子', 'role:養子', 'heir'],
};

bool _rootOk(Game g, String r) {
  if (r.startsWith('role:')) return g.l.people.containsKey(r.substring(5));
  if (r.startsWith('cls:')) return g.l.cls.id == r.substring(4);
  return g.hasFlag(r);
}

/// その筋の岐路に要る旗のどれかがあるか（筋でない岐路は真）。テストも使う。
bool oaRooted(Game g, String id) {
  final rs = kOldAgeRoots[id];
  return rs == null || rs.any((r) => _rootOk(g, r));
}

/// 晩年の一生に一度の岐路の id（テストが使う）。
const kOldAgeSceneIds = [
  'oa_heir_rift',
  'oa_recalled',
  'oa_old_foe',
  'oa_benefactor',
  'oa_funeral',
  'oa_katami',
  'oa_yuigon',
  'oa_sin',
  'oa_mago_match',
  'oa_late_love',
  'oa_forget',
  'oa_last_journey',
  'oa_child_days',
  'oa_battlefield',
  'oa_shop',
  'oa_monk',
  'oa_shinobi',
  'oa_young_lord',
  'oa_faith',
  'oa_village',
  'oa_yome',
];

/// 晩年の重点の始めの岐路（`<tag>_again` も持つ）。
const kOldAgeFocusTags = [
  'oa_garden',
  'oa_tales',
  'oa_kuyo',
  'oa_pilgrim',
  'oa_record',
  'oa_tenarai',
];

// ======================================================================
// 岐路
// ======================================================================

SceneDef _first(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(id, kOldAgeMinAge, 100, (g) => 1, (g) => true, run, onlyForced: true);

SceneDef _again(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(
      '${id}_again',
      kOldAgeMinAge,
      100,
      (g) => 1,
      (g) => true,
      run,
      onlyForced: true,
      repeat: true,
    );

/// 晩年の一生に一度の岐路。筋のあるものは [kOldAgeRoots] の旗がなければ出ない。
SceneDef _late(
  String id,
  int minAge,
  double w,
  bool Function(Game g) cond,
  void Function(Game g, void Function() next) run,
) => SceneDef(
  id,
  minAge,
  100,
  (g) => w,
  (g) => oaRooted(g, id) && cond(g),
  run,
);

/// 晩年の岐路の重み（ほかの岐路に埋もれない程度）。
const _w = 7.0;

List<SceneDef> buildOldAgeScenes() => [
  ..._focusScenes(),
  ..._lateScenes(),
];

List<SceneDef> _focusScenes() => [
  // ==================================================================
  // 庭を造る
  // ==================================================================
  _first('oa_garden', (g, next) {
    g.ask('庭造り', '隠居所の庭を造ることにした。年かさの庭師が、どんな庭にするかと尋ねる。', [
      Choice.h('池を掘り、名のある石を据える', '見事な庭になる。銭は湯水のように消える', () {
        if (g.l.gold < 15) {
          g.j(-1);
          return '銭が足りず、池は小さな水たまりで終わった。';
        }
        g.l.gold -= 15;
        g.l.fame += 2;
        g.setFlag('oa_garden_grand');
        g.mark('隠居所に、池と名石の庭を造った');
        return '池に空が映り、据えた石が島のように見えた。見物に来る者も出た。';
      }),
      Choice.h('野の草花と、手に入る石だけで造る', '銭はかからない。庭は四季ごとに顔を変える', () {
        g.setFlag('oa_garden_wild');
        g.j(6);
        return '野から移した草花が、思いのほかよく根付いた。';
      }),
      Choice.h('亡き人の好んだ木を一本だけ植える', '庭は寂しい。木は人より長く生きる', () {
        g.setFlag('oa_garden_tree');
        g.j(3);
        g.mark('隠居所の庭に、亡き人の好んだ木を一本植えた');
        return '小さな苗木に水をやり、しばらくそばに立っていた。';
      }),
    ], after: next);
  }),
  _again('oa_garden', (g, next) {
    final head = _intro(g, 'oa_garden', 'また庭に出た。', [
      '{季}、庭に出た。',
      '庭師が、今年は苔がよくついたと言う。',
      '縁側から、庭の石をしばらく眺めた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('庭', '$head夜のうちに雪が積もり、庭木の枝がしなっている。', [
        Choice.h('夜更けに雪を払いに出る', '木は守れる。寒さは老いた体にさわる', () {
          g.l.hp -= 6;
          g.j(3);
          return '手を真っ赤にして、枝の雪を一つずつ落とした。';
        }),
        Choice.h('折れるに任せる', '体は無事だ。庭は少し寂しくなる', () {
          g.j(-2);
          return '明け方、枝の折れる音を床の中で聞いた。';
        }),
      ], after: next);
      return;
    }
    g.ask('庭', '$head近所の子らが、庭の池の鯉をのぞきに忍び込んでくる。', [
      Choice.h('叱って追い払う', '庭は静かになる。子らは寄りつかなくなる', () {
        g.j(-1);
        return '子らは蜘蛛の子を散らすように逃げていった。';
      }),
      Choice.h('菓子を出して迎え入れる', '庭が賑やかになる。鯉は落ち着かない', () {
        g.l.net += 1;
        g.j(5);
        return '子らは池の縁に並び、鯉に名前をつけはじめた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 昔語り
  // ==================================================================
  _first('oa_tales', (g, next) {
    final warrior = g.hasFlag('first_battle');
    g.ask('昔語り', '囲炉裏のそばに、若い者たちが集まってきた。昔の話を聞かせてくれとせがんでいる。', [
      if (warrior)
        Choice.h('戦の話をする', '若い者は目を輝かせる。話は少し大きくなる', () {
          g.setFlag('oa_tales_war');
          g.l.fame += 1;
          return '槍を合わせた日のことを語ると、若い者たちは身を乗り出した。';
        }),
      Choice.h('苦しかった年の話をする', '若い者は黙って聞く。耳の痛い話だ', () {
        g.setFlag('oa_tales_hard');
        g.l.net += 2;
        g.mark('若い者たちに、苦しかった年の話を語り聞かせた');
        return '飢えた冬と、失ったものの話をした。囲炉裏の火がはぜる音だけが響いた。';
      }),
      Choice.h('笑い話で座を沸かせる', '座は和む。教えになるかは分からない', () {
        g.j(5);
        return 'しくじり話をすると、若い者たちは腹を抱えて笑った。';
      }),
    ], after: next);
  }),
  _again('oa_tales', (g, next) {
    final head = _intro(g, 'oa_tales', 'また若い者たちが話を聞きに来た。', [
      '{季}、若い者たちが囲炉裏のそばに集まった。',
      '同じ話を、もう何度目かに語った。',
      '若い者の顔ぶれが、また少し変わった。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('昔語り', '$head一人が、その話は嘘だろうと笑った。', [
        Choice.h('声を荒らげて叱る', '座は凍る。話の重みは守れる', () {
          g.j(-2);
          return '若い者は首をすくめた。その日の座は、早くお開きになった。';
        }),
        Choice.h('笑って、少し盛ったと認める', '座は和む。話の値打ちは少し下がる', () {
          g.l.net += 1;
          g.j(3);
          return '皆が笑い、あなたもつられて笑った。';
        }),
        Choice.h('古傷や古い書付を見せる', '話に重みが出る。見せたくないものもある', () {
          g.l.fame += 1;
          return '若い者は黙り込み、それからは真顔で聞くようになった。';
        }),
      ], after: next);
      return;
    }
    g.ask('昔語り', '$head一人が、話に出てきた遠い土地へ行ってみたいと言い出した。', [
      Choice.h('行ってみろと背中を押す', '若い者は旅立つ。帰ってくるかは分からない', () {
        g.j(2);
        return '若い者は、目を輝かせて礼を言った。';
      }),
      Choice.h('昔と今は違うと止める', '若い者は残る。少し不満そうだ', () {
        return '若い者は、黙ってうなずいた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 菩提を弔う
  // ==================================================================
  _first('oa_kuyo', (g, next) {
    final fought = g.hasFlag('first_battle');
    g.ask('菩提', '亡き人の菩提を弔うため、寺に寄進することにした。誰のために手を合わせる？', [
      Choice.h('父母のために', 'いちばん古い借りを返す。心が落ち着く', () {
        g.setFlag('oa_kuyo_parents');
        g.j(5);
        return '父母の名を記した札の前で、長いあいだ手を合わせた。';
      }),
      if (fought)
        Choice.h('戦で死んだ敵と味方のために、供養塔を建てる', '敵も味方も弔う。眉をひそめる者もいる', () {
          if (g.l.gold < 10) {
            _pay(g, 3);
            return '銭が足りず、小さな石を一つ据えるだけになった。';
          }
          g.l.gold -= 10;
          g.l.fame += 2;
          g.setFlag('oa_kuyo_tou');
          g.mark('敵味方の別なく、戦で死んだ者の供養塔を建てた');
          return '敵の名も味方の名も分け隔てなく刻んだ塔が、寺の裏に立った。';
        })
      else
        Choice.h('名もなく死んでいった者たちのために', '誰も覚えていない者を弔う。寺は首をかしげる', () {
          g.setFlag('oa_kuyo_nameless');
          g.j(4);
          return '飢えや病で死んだ村の者たちの名を、思い出せるだけ住持に伝えた。';
        }),
      Choice.h('自分の後生のために', '欲のない願いではない。寺は喜ぶ', () {
        g.j(3);
        return '住持は寄進を受け取り、手厚く経をあげてくれた。';
      }),
    ], after: next);
  }),
  _again('oa_kuyo', (g, next) {
    final head = _intro(g, 'oa_kuyo', 'また寺に参った。', [
      '{季}、寺に参った。',
      '寺の石段が、年ごとに高くなる気がする。',
      '線香の煙が、本堂の梁まで上っていく。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('寄進', '$head住持が、本堂の屋根の繕いに寄進を頼んできた。', [
        Choice.h('快く出す', '寺は助かる。蔵は寂しくなる', () {
          _pay(g, 6);
          g.l.fame += 1;
          g.j(3);
          return '住持は深々と頭を下げた。';
        }),
        Choice.h('いまは出せぬと断る', '銭は残る。住持の目は少し冷たい', () {
          g.j(-1);
          return '住持は、それ以上は何も言わなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('法要', '$head法要の席に、見知らぬ年寄りが来て手を合わせていた。昔あなたに助けられた者の縁者だという。', [
      Choice.h('座敷に招いて話を聞く', '思わぬ縁がつながる。長話になる', () {
        g.l.net += 2;
        g.j(4);
        return '忘れていた昔の一日のことを、年寄りは細かに覚えていた。';
      }),
      Choice.h('会釈だけして帰る', '何も変わらない。少し気にかかる', () {
        return '振り返ると、年寄りはまだ手を合わせていた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 詣での旅
  // ==================================================================
  _first('oa_pilgrim', (g, next) {
    final f = g.l.female;
    g.ask('詣での旅', '老いの身で、一度は詣でておきたい所がある。どこへ行く？', [
      Choice.h('伊勢へ', '人の多い道で心強い。御師の宿で手厚く迎えられる', () {
        g.setFlag('oa_pilgrim_ise');
        g.j(6);
        g.mark('老いて、伊勢へ詣でた');
        return '五十鈴川の流れで手を清め、宮の森に深く頭を下げた。';
      }),
      Choice.h('熊野へ', '山道は険しい。蘇りの地と言われる', () {
        g.l.hp -= 8;
        g.setFlag('oa_pilgrim_kumano');
        g.j(8);
        g.mark('老いて、熊野の三つの社を詣でた');
        return '杖にすがって峠を越え、那智の滝の飛沫を浴びた。';
      }),
      Choice.h('高野へ', '亡き人の供養になる。山の奥は女人を拒む', () {
        g.setFlag('oa_pilgrim_koya');
        g.j(5);
        return f
            ? '女人の入れる堂で、奥の院の方角に手を合わせた。'
            : '奥の院の杉木立の中で、亡き人の名を一人ずつ唱えた。';
      }),
    ], after: next);
  }),
  _again('oa_pilgrim', (g, next) {
    final head = _intro(g, 'oa_pilgrim', 'また詣での旅に出た。', [
      '{季}、また詣での道を歩いた。',
      '街道の茶屋の婆が、あなたの顔を覚えていた。',
      '同じ道を、また一つ歳を重ねて歩いた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('道中', '$head路銀の尽きた若い巡礼と、道連れになった。', [
        Choice.h('路銀を分けてやる', '銭は減る。巡礼は涙を流す', () {
          _pay(g, 3);
          g.j(4);
          return '若い巡礼は、何度も振り返って手を合わせた。';
        }),
        Choice.h('宿場で別れる', '何も失わない。少し胸が痛む', () {
          return '宿場の辻で、若い巡礼と別れた。';
        }),
      ], after: next);
      return;
    }
    g.ask('道中', '$head峠の手前で、足が言うことをきかなくなった。', [
      Choice.h('駕籠を雇って越える', '銭はかかる。足は守れる', () {
        _pay(g, 3);
        return '駕籠の中で揺られながら、峠の景色を眺めた。';
      }),
      Choice.h('茶屋で足を止め、一日待つ', '旅は延びる。足は少し戻る', () {
        _heal(g, 8);
        return '茶屋の縁台で、行き交う旅人を一日眺めていた。';
      }),
      Choice.h('杖にすがって歩き通す', '意地は通る。体は痛む', () {
        g.l.hp -= 8;
        g.j(2);
        return '日の暮れる頃、ようやく峠を越えた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 家の記録
  // ==================================================================
  _first('oa_record', (g, next) {
    g.ask('家の記', '家の来し方を書き残すことにした。筆をとって、何から書く？', [
      Choice.h('家の手柄と、受けた恩を', '子孫の誇りになる。都合の悪いことは書かれない', () {
        g.setFlag('oa_record_glory');
        g.j(3);
        return '先祖の手柄と自分の手柄を、晴れがましく書き連ねた。';
      }),
      Choice.h('しくじったことも包み隠さず', '子孫の戒めになる。読む者は顔をしかめる', () {
        g.setFlag('oa_record_true');
        g.mark('しくじりも包み隠さず、家の記録を書き残した');
        return '恥ずかしい話も、筆を止めずに書いた。書き終えると、肩が軽くなった。';
      }),
      if (g.l.chi >= 65)
        Choice.h('世の動きと、見聞きした人々のことを', '家の記を越えて、世の記になる。筆は重い', () {
          g.setFlag('oa_record_era');
          g.l.fame += 3;
          g.mark('見聞きした乱世の人々のことを、記録に書き残した');
          return '会った人、聞いた噂、見た戦を、年を追って細かに書き記した。';
        }),
    ], after: next);
  }),
  _again('oa_record', (g, next) {
    final head = _intro(g, 'oa_record', 'また筆をとった。', [
      '{季}、灯の下で記録の続きを書いた。',
      '書き溜めた紙が、文箱からあふれそうだ。',
      '墨をする手が、近ごろ少し震える。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('家の記', '$head読み返すと、若い頃の自分に腹の立つところがあった。', [
        Choice.h('書き直す', '記録は整う。本当のことは少し薄れる', () {
          g.j(2);
          return '若い自分を、少しだけ立派に書き直した。';
        }),
        Choice.h('そのまま残す', '恥は残る。嘘も残らない', () {
          g.j(-1);
          return '筆を置き、昔の自分に苦笑いした。';
        }),
      ], after: next);
      return;
    }
    g.ask('家の記', '$head家の者が、記録の一節を消してくれと頼んできた。親類の恥が書いてあるという。', [
      Choice.h('頼みを聞いて消す', '親類は胸をなでおろす。記録には穴が開く', () {
        g.l.net += 1;
        return '墨で塗りつぶした行を、しばらく見つめていた。';
      }),
      Choice.h('消さずに残す', '親類は不満だ。記録は嘘をつかない', () {
        g.j(-2);
        return '親類は、それきり寄りつかなくなった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 孫の手習い
  // ==================================================================
  _first('oa_tenarai', (g, next) {
    final m = _mago(g);
    g.ask('孫の手習い', '$mが、筆を持ちたいとせがんだ。手本は何にする？', [
      Choice.h('自分の名と、家の名から', '家のことを覚える。字は硬くなる', () {
        g.setFlag('oa_tenarai_taught');
        _magoBond(g, 5);
        return '$mは、家の名を三度書き損じ、四度目にようやく書けた。';
      }),
      Choice.h('古い歌を手本にする', '字がやわらかくなる。覚えるのに時がかかる', () {
        g.setFlag('oa_tenarai_taught');
        g.setFlag('oa_tenarai_uta');
        _magoBond(g, 8);
        g.j(3);
        return '歌の意味を尋ねる$mに、一つずつ話して聞かせた。';
      }),
      Choice.h('帳面の字と勘定を先に', '暮らしの役に立つ。孫は退屈する', () {
        g.setFlag('oa_tenarai_taught');
        _magoBond(g, 2);
        return '$mはあくびをこらえながら、数の字を覚えていった。';
      }),
    ], after: next);
  }),
  _again('oa_tenarai', (g, next) {
    final m = _mago(g);
    final head = _intro(g, 'oa_tenarai', 'また$mの手習いを見てやった。', [
      '{季}、$mの手習いを見てやった。',
      '$mの字が、あなたの字に似てきた。',
      '手習いの反故で、$mが紙の兜を折っている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('孫の手習い', '$head手習いの紙の隅に、あなたの顔が描いてあった。', [
        Choice.h('笑って褒める', '孫は喜ぶ。手習いは進まない', () {
          _magoBond(g, 6);
          g.j(5);
          return '似ていると言うと、$mは得意げに鼻をこすった。';
        }),
        Choice.h('手習いに戻れとたしなめる', '字は上達する。孫は少ししょげる', () {
          _magoBond(g, -1);
          return '$mは口を尖らせて、また筆を握った。';
        }),
      ], after: next);
      return;
    }
    g.ask('孫の手習い', '$head$mが、手本の字を一つ間違えて覚えていた。あなたが書き違えた字だった。', [
      Choice.h('自分の書き違いだと正直に言う', '孫は笑う。手本の威厳は少し減る', () {
        _magoBond(g, 5);
        g.j(3);
        return '$mは、${g.l.female ? 'おばば' : 'おじじ'}も間違えるのかと大笑いした。';
      }),
      Choice.h('黙って手本を書き直す', '威厳は保てる。少し後ろめたい', () {
        return '夜のうちに、手本をそっと書き直しておいた。';
      }),
    ], after: next);
  }),
];

List<SceneDef> _lateScenes() => [
  // ==================================================================
  // 家督を譲った子との行き違い
  // ==================================================================
  _late('oa_heir_rift', 52, _w, (g) => _retired(g) && g.l.kids > 0, (g, next) {
    final h = _heirName(g);
    g.ask('家督の行き違い', '$hが、あなたの代から家を支えてきた者を遠ざけ、若い者ばかりを重く用いている。遠ざけられた者が、隠居所へ泣きついてきた。', [
      Choice.h('$hを呼んで叱る', 'けじめはつく。子との間に溝ができる', () {
        _heirBond(g, -10);
        g.setFlag('oa_heir_scolded');
        return '$hは黙って頭を下げたが、その目は笑っていなかった。';
      }),
      Choice.h('黙って任せる', '家はもう子のものだ。古い者の恨みは残る', () {
        g.setFlag('oa_heir_trusted');
        g.j(-2);
        return '泣きついてきた者に、何もしてやれぬと詫びた。';
      }),
      if (g.l.mi >= 60)
        Choice.h('酒を酌み交わして、子の考えを聞く', '子の胸の内が分かる。言葉を選ぶ腕が要る', () {
          _heirBond(g, 8);
          g.setFlag('oa_heir_talked');
          g.mark('家督を譲った子と酒を酌み交わし、胸の内を聞いた');
          return '$hにも考えがあった。夜更けまで語り合い、古い者の使いどころを一つだけ頼んだ。';
        })
      else
        Choice.h('遠ざけられた者を、隠居所に引き取る', '古い者は救われる。子は面白くない', () {
          g.l.net += 2;
          _heirBond(g, -3);
          g.setFlag('oa_heir_took_old');
          return '古い者は、隠居所の庭の手入れを喜んで引き受けた。';
        }),
    ], after: next);
  }),

  // ==================================================================
  // 家の危機に呼び戻される
  // ==================================================================
  _late(
    'oa_recalled',
    55,
    _w,
    (g) => _retired(g) && g.l.maxRank >= 3 && _lordAlive(g),
    (g, next) {
      final house = houseName(g, g.l.lord);
      g.ask('呼び戻し', '$house家が危うい。若い者では埒が明かず、隠居のあなたに呼び出しがかかった。', [
        if (g.canFight)
          Choice.h('甲冑をまとい、陣頭に立つ', '若い者の士気が上がる。老いた身に戦場は酷だ', () {
            if (g.rng.chance(.04)) {
              g.die('隠居の身で呼び戻され、陣頭に立ったまま帰らなかった', 'senshi');
              return '若い者たちの先に立ち、そのまま帰らなかった。';
            }
            g.l.fame += 4;
            g.l.hp -= 12;
            g.setFlag('oa_recalled_led');
            g.mark('隠居の身で呼び戻され、家の危機に陣頭に立った');
            return '白髪の将の姿に、若い者たちが奮い立った。家はひとまず持ちこたえた。';
          }),
        Choice.h('評定に出て、策だけを授ける', '命の危うさはない。策が当たるかは知恵しだい', () {
          if (g.l.chi >= 60 || g.rng.chance(g.l.chi / 150)) {
            g.l.fame += 3;
            g.setFlag('oa_recalled_plan');
            g.mark('隠居の身で呼び戻され、評定で策を授けた');
            return '古い戦の知恵が、若い者たちの目を開かせた。';
          }
          g.j(-3);
          return '策は古いと、若い者たちに聞き流された。';
        }),
        if (g.l.chi >= 70)
          Choice.h('和睦の使者に立つ', '戦わずに済むかもしれない。敵の陣へ行くのは老いた身にこたえる', () {
            g.l.hp -= 6;
            if (g.rng.chance(.5 + g.l.mi / 300)) {
              g.l.fame += 4;
              g.setFlag('oa_recalled_peace');
              g.mark('隠居の身で、和睦の使者に立った');
              return '敵の将は、白髪の使者の言葉に耳を傾けた。和睦はまとまった。';
            }
            return '話はまとまらず、追い返された。';
          }),
        Choice.h('老いた者の出る幕ではないと断る', '体は守れる。家中の目は冷たくなる', () {
          g.j(-2);
          return '使いの者は、肩を落として帰っていった。';
        }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 昔の敵の消息
  // ==================================================================
  _late('oa_old_foe', 50, _w, (g) => true, (g, next) {
    final rv = g.l.people['好敵手'];
    if (rv != null) {
      g.ask('昔の好敵手', '好敵手の${rv.name}が、杖をついて訪ねてきた。どちらが先に逝くか確かめに来た、と笑う。', [
        Choice.h('碁盤を出して一局打つ', '昔の勝ち負けの続きになる。夜は長い', () {
          rv.bond = _c100(rv.bond + 8);
          g.setFlag('oa_foe_peace');
          g.j(6);
          return '一局のつもりが三局になった。勝ち負けは、どちらも口にしなかった。';
        }),
        Choice.h('若い日の手柄を言い合う', '座は賑やかになる。言い争いにもなる', () {
          if (g.rng.chance(.5)) {
            rv.bond = _c100(rv.bond + 4);
            g.j(4);
            return '互いの話を少しずつ大きくしながら、腹を抱えて笑った。';
          }
          rv.bond = _c100(rv.bond - 4);
          return 'どちらの手柄が上かで、昔のように睨み合った。';
        }),
        Choice.h('会わずに帰す', '昔の因縁は掘り返さない。少し心残りだ', () {
          g.j(-2);
          return '門の外で、杖の音が遠ざかっていった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('bd_rv_slew') || g.hasFlag('bd_rv_dead')) {
      g.ask('好敵手の子', '亡き好敵手の子が訪ねてきた。父は最後まで、あなたの名を口にしていたという。', [
        Choice.h('父の若い日のことを語って聞かせる', '子は父を知る。古い傷も少し開く', () {
          g.setFlag('oa_foe_peace');
          g.j(3);
          return '子は涙を浮かべて聞き入り、また来てもよいかと尋ねた。';
        }),
        Choice.h('自分の刀か筆を形見に渡す', '子は驚く。縁が次の代へ続く', () {
          g.setFlag('oa_foe_peace');
          g.l.net += 2;
          return '子は両手で受け取り、深く頭を下げた。';
        }),
        Choice.h('多くは語らずに帰す', '何も起きない。胸の奥が少し疼く', () {
          return '子の背中に、どこか好敵手の面影が見えた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('bt_spared_foe')) {
      g.ask('見逃した敵', '昔、戦場で見逃した敵の兵が、立派な身なりで訪ねてきた。あの日の礼を言いに来たという。', [
        Choice.h('座敷に上げて酒を出す', '思わぬ縁になる。昔の話は尽きない', () {
          g.setFlag('oa_foe_peace');
          g.l.net += 2;
          g.j(5);
          return 'あの日のことを、互いの側から語り合った。';
        }),
        Choice.h('礼には及ばぬと帰す', '何も変わらない。あの日の選択は報われた', () {
          g.j(2);
          return '男は門の外で、もう一度深く頭を下げた。';
        }),
      ], after: next);
      return;
    }
    g.ask('討った将の子', '若い日に戦場で討った敵の将の子が、老いて訪ねてきた。恨みを言いに来たのではない、と言う。', [
      Choice.h('討った日のことを、ありのままに語る', '子は父の最期を知る。つらい話になる', () {
        g.setFlag('oa_foe_peace');
        g.mark('討った敵の将の子に、その最期をありのままに語った');
        return '子は最後まで黙って聞き、父は立派だったかと一つだけ尋ねた。';
      }),
      Choice.h('将の墓に参らせてほしいと頼む', '子は戸惑う。けじめはつく', () {
        g.setFlag('oa_foe_peace');
        g.l.hp -= 5;
        g.j(3);
        return '敵だった家の墓所で、子と並んで手を合わせた。';
      }),
      Choice.h('会わずに帰す', '昔の血は掘り返さない。子は何を思うか', () {
        g.j(-3);
        return '門番が、客は何も言わずに帰ったと告げた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 恩人の縁
  // ==================================================================
  _late('oa_benefactor', 50, _w, (g) => g.l.gold >= 0, (g, next) {
    String who;
    final ms = g.l.people['師'];
    String? dead;
    for (final f in g.l.flags) {
      if (f.startsWith('bd_ms_name:')) dead = f.substring(11);
    }
    if (ms != null) {
      who = '師の${ms.name}';
    } else if (dead != null) {
      who = '亡き師の$dead';
    } else if (g.hasFlag('tera_diligent')) {
      who = '手習いの和尚';
    } else if (g.hasFlag('sword_lessons')) {
      who = '剣の指南役';
    } else {
      who = '師';
    }
    g.ask('恩人の孫', '若い日に世話になった$whoの孫が、家が絶えかけて頼ってきた。', [
      Choice.h('引き取って面倒を見る', '恩が返せる。食い扶持が一つ増える', () {
        _pay(g, 4);
        g.setFlag('oa_benefactor_kin');
        g.j(4);
        g.mark('若い日の恩人の孫を、家に引き取った');
        return '孫は、祖父によく似た目で家の中を見回した。';
      }),
      Choice.h('銭を持たせて送り出す', '恩の半ばは返せる。行く末は見届けられない', () {
        _pay(g, 5);
        return '孫は銭を押しいただき、街道を下っていった。';
      }),
      if (g.l.mi >= 60 || g.l.net >= 40)
        Choice.h('知る家へ口を利いてやる', '顔が要る。うまくいけば孫は身を立てる', () {
          g.setFlag('oa_benefactor_placed');
          g.l.net -= 1;
          return '昔なじみの家が、孫を引き受けてくれた。';
        })
      else
        Choice.h('昔の恩は昔のことだと断る', 'これ以上の荷は負わない。胸は晴れない', () {
          g.j(-5);
          return '孫の足音が遠ざかるまで、戸口に立てなかった。';
        }),
    ], after: next);
  }),

  // ==================================================================
  // 葬いの支度
  // ==================================================================
  _late('oa_funeral', 60, _w, (g) => true, (g, next) {
    final who = _monk(g) ? '弟子の僧たち' : '寺の住持';
    g.ask('葬いの支度', '$whoが、そろそろ葬いの段取りを決めておいてほしいと言う。', [
      Choice.h('家の格にふさわしく、盛大に', '家の名は上がる。残る者の懐は痛む', () {
        g.setFlag('oa_funeral_grand');
        return '葬いの列の順まで、細かく書き付けて渡した。';
      }),
      Choice.h('質素にし、余る銭は貧しい者に', '名は残らないかもしれない。徳は残る', () {
        g.setFlag('oa_funeral_plain');
        g.j(4);
        g.mark('葬いは質素にと言い置き、余る銭を施した');
        return '残る銭の使い道を、一つずつ書き付けた。';
      }),
      Choice.h('葬いは要らぬ。墓も小さな石一つでよい', '残る者は戸惑う。気は楽だ', () {
        g.setFlag('oa_funeral_none');
        g.j(2);
        return '聞いた者は困った顔をしたが、あなたは晴れ晴れとしていた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 形見分け
  // ==================================================================
  _late(
    'oa_katami',
    60,
    _w,
    (g) => g.l.kids > 0 || g.l.people.isNotEmpty,
    (g, next) {
      final String thing;
      if (g.hasFlag('ps_meibutsu') && !g.hasFlag('e2_gave_meibutsu')) {
        thing = '名物の茶碗';
      } else if (g.hasFlag('bd_ms_keepsake')) {
        thing = '師から受け継いだ形見';
      } else if (g.hasFlag('first_battle')) {
        thing = '長年の戦をともにした刀';
      } else {
        thing = '長年使い込んだ品々';
      }
      g.ask('形見分け', '形見分けの品を、誰に遺すか決めておくことにした。$thingを、誰に遺す？', [
        Choice.h('跡を継ぐ子に', '家の宝として残る。誰も驚かない', () {
          g.setFlag('oa_katami_heir');
          _heirBond(g, 3);
          return '$thingを、家の者の前で跡継ぎに渡すと言い置いた。';
        }),
        Choice.h('長く仕えてくれた者に', '家の者は驚く。受け取った者は生涯忘れない', () {
          g.setFlag('oa_katami_servant');
          g.l.net += 2;
          g.mark('$thingを、長く仕えてくれた者に遺すと決めた');
          return '名を告げられた者は、言葉も出ずに平伏した。';
        }),
        Choice.h('寺に納める', '誰の手にも渡らない。争いの種にもならない', () {
          g.setFlag('oa_katami_temple');
          g.j(2);
          return '$thingは、いずれ寺の蔵に眠ることになった。';
        }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 遺言
  // ==================================================================
  _late('oa_yuigon', 62, _w, (g) => g.l.kids > 0, (g, next) {
    g.ask('遺言', '家の者を枕元に集め、言い置くことを決める日が来た。何を言い残す？', [
      Choice.h('争うな、と', '家はまとまる。言葉だけで縛れるかは分からない', () {
        g.setFlag('oa_yuigon_peace');
        g.j(3);
        return '子らは顔を見合わせ、黙ってうなずいた。';
      }),
      Choice.h('家を大きくせよ、と', '子らは奮い立つ。無理をする者も出る', () {
        g.setFlag('oa_yuigon_rise');
        return '子らの目に火がともった。それが吉と出るかは分からない。';
      }),
      if (g.l.chi >= 60)
        Choice.h('書状にしたため、寺に預ける', '誰も勝手に書き換えられない。子らは顔を見合わせる', () {
          g.setFlag('oa_yuigon_letter');
          g.mark('遺言を書状にしたため、寺に預けた');
          return '封をした書状を、住持に預けた。中身は誰にも明かさなかった。';
        }),
      Choice.h('何も言わぬ', '子らは自分で考える。迷う者も出る', () {
        g.setFlag('oa_yuigon_none');
        return 'それぞれの道を行け。それだけを胸の内で思った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 昔の悪事の報い
  // ==================================================================
  _late('oa_sin', 50, _w, (g) => true, (g, next) {
    final String text;
    if (g.hasFlag('randori') || g.hasFlag('al_sold_captive')) {
      text = '若い日の乱取りで焼かれた村の者だという年寄りが、門の前に座り込んでいる。';
    } else if (const [
      'al_hyoro_skim',
      'tal_bribe',
      'e3_bribe_hidden',
      'tf_sashi_hidden',
      'tf_kome_hoard',
    ].any(g.hasFlag)) {
      text = '若い日の後ろ暗い銭のことを知る者が、老いて訪ねてきた。黙っている代わりに銭をよこせと言う。';
    } else {
      text = '若い日に裏切った者の縁者が、恨みを抱いて近くに住みついたと聞いた。';
    }
    g.ask('昔の報い', text, [
      Choice.h('会って、ありのままを詫びる', '胸のつかえが下りる。許されるかは相手しだい', () {
        if (g.rng.chance(.5 + g.l.mi / 300)) {
          g.setFlag('oa_sin_atoned');
          g.j(6);
          g.mark('若い日の過ちを、相手の前で詫びた');
          return '相手は長いあいだ黙っていたが、やがて小さくうなずいた。';
        }
        g.j(-5);
        return '相手は何も言わずに去った。詫びは届かなかった。';
      }),
      Choice.h('銭で済ませる', '事は収まる。銭は消え、悔いは残る', () {
        _pay(g, 10);
        g.setFlag('oa_sin_paid');
        g.j(-2);
        return '銭を渡すと、相手は鼻で笑って去っていった。';
      }),
      Choice.h('知らぬ顔をする', '何も変わらない。夜道には気をつける', () {
        if (g.rng.chance(.04)) {
          g.die('若い日の恨みを抱く者に、夜道で襲われた', 'ansatsu');
          return '提灯の明かりの外から、誰かが近づいてきた。';
        }
        g.j(-3);
        return '門を閉ざした。それからは、夜の足音が気になるようになった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 孫の縁談
  // ==================================================================
  _late(
    'oa_mago_match',
    60,
    _w,
    // 孫が年頃になっている（上の子が三十を越えている）。年の分からない子は親の歳で見る。
    (g) => (g.l.eldestKidAge(g.year) ?? (g.age >= 62 ? 99 : 0)) >= 32,
    (g, next) {
      final m = _mago(g);
      g.ask('孫の縁談', '$mに縁談が持ち込まれた。家の者は、あなたの一言を待っている。', [
        Choice.h('家の釣り合いを見て決める', '家は安泰。孫の気持ちは後回しになる', () {
          g.setFlag('oa_mago_match_house');
          _magoBond(g, -3);
          return '相手の家の格を聞き、よかろうと一言だけ言った。';
        }),
        Choice.h('孫の好きにさせる', '孫は喜ぶ。家の者はやきもきする', () {
          g.setFlag('oa_mago_match_love');
          _magoBond(g, 8);
          g.j(4);
          return '$mは、あなたの袖をつかんで礼を言った。';
        }),
        Choice.h('相手の家を自分の目で確かめに行く', '老いた足には遠い。確かめれば悔いはない', () {
          g.l.hp -= 6;
          g.setFlag('oa_mago_match_seen');
          _magoBond(g, 4);
          return '相手の家の台所まで見て回り、これならよいと帰ってきた。';
        }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 老いらくの恋
  // ==================================================================
  _late(
    'oa_late_love',
    55,
    _w * .6,
    (g) => !g.l.married && g.age <= 75 && !_monk(g),
    (g, next) {
      final f = g.l.female;
      final name = g.rng.pick(f ? kGivenM : kGivenF);
      g.ask(
        '老いらくの恋',
        f
            ? '近ごろ、同じ寺に参る、連れ合いを亡くした$nameと話すのが楽しみになった。家の者は、陰で笑っている。'
            : '近ごろ、茶を運んでくる、連れ合いを亡くした$nameと話すのが楽しみになった。家の者は、陰で笑っている。',
        [
          Choice.h('思いを打ち明け、共に暮らす', '老いの身に灯がともる。家の者は眉をひそめる', () {
            if (g.rng.chance(.6 + g.l.mi / 300)) {
              g.l.married = true;
              g.meet('伴侶', name, 60);
              g.setFlag('oa_late_love_wed');
              g.j(12);
              g.mark('老いて、思いを寄せた$nameと共に暮らし始めた');
              return '$nameは、しばらく黙ってから、小さくうなずいた。';
            }
            g.j(-4);
            return 'いまさら、とやんわり断られた。';
          }),
          Choice.h('茶飲み友だちのままでいる', '穏やかな日が続く。胸の内は言わずじまい', () {
            g.setFlag('oa_late_love_kept');
            g.j(5);
            return '縁側で茶をすすりながら、とりとめのない話をした。';
          }),
          Choice.h('家の者の目を気にして、会うのをやめる', '波風は立たない。寂しさが増す', () {
            g.j(-6);
            return 'それきり、$nameの姿を見かけても声をかけなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ==================================================================
  // 物忘れ
  // ==================================================================
  _late('oa_forget', 65, _w, (g) => true, (g, next) {
    final who = _hasMago(g) ? '孫の名' : '家の者の名';
    g.ask('物忘れ', '近ごろ、人の名がすぐに出てこない。今朝は$whoを呼び違えた。', [
      if (g.l.chi >= 60)
        Choice.h('日ごとのことを書き留める', '物忘れが和らぐ。書いたことも忘れるかもしれない', () {
          g.setFlag('oa_forget_diary');
          g.j(2);
          return '枕元に紙と筆を置き、その日のことを短く書き付けるようにした。';
        }),
      Choice.h('碁や歌で頭を使う', '少しは冴えが戻る。疲れやすい', () {
        g.l.hp -= 3;
        if (g.rng.chance(.5)) g.l.chi = _c(g.l.chi - 1);
        return '碁盤に向かうと、頭の霧が少し晴れる気がした。';
      }),
      Choice.h('家の者に頼り、気にしないことにする', '家の者の手を煩わせる。心は軽い', () {
        g.l.chi = _c(g.l.chi - 2);
        g.j(2);
        return '名を呼び違えるたびに、家の者が笑って言い直してくれた。';
      }),
      Choice.h('笑い飛ばす', '家の者もつられて笑う。物忘れは進む', () {
        g.l.chi = _c(g.l.chi - 3);
        g.j(4);
        return '歳をとれば、忘れることも増えるものだ。そう言って笑った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 最後の旅
  // ==================================================================
  _late('oa_last_journey', 66, _w, (g) => g.l.hp > 20, (g, next) {
    final sp = g.l.married ? g.l.people['伴侶'] : null;
    g.ask('最後の旅', '体の動くうちに、もう一度だけ旅に出たいと思った。どこへ行く？', [
      Choice.h('若い日を過ごした土地へ', '懐かしい顔は、もういないかもしれない', () {
        if (g.rng.chance(.05)) {
          g.die('最後の旅の途上、宿で眠るように息を引き取った', 'tenju');
          return '懐かしい土地を見た夜、宿の床で静かに目を閉じた。';
        }
        g.setFlag('oa_last_home');
        g.j(8);
        g.mark('老いて、若い日を過ごした土地をもう一度歩いた');
        return '変わったものと変わらないものを、一つずつ確かめて歩いた。';
      }),
      if (g.hasFlag('first_battle'))
        Choice.h('若い日に初めて戦った野へ', '死んだ者たちに会いに行く旅になる', () {
          g.setFlag('oa_last_field');
          g.j(2);
          return '風の渡る野に立ち、名を覚えている者の数だけ手を合わせた。';
        }),
      if (sp != null)
        Choice.h('${sp.name}と、まだ見ぬ海を見に', '二人の思い出になる。老いた二人には遠い', () {
          sp.bond = _c100(sp.bond + 10);
          g.setFlag('oa_last_together');
          g.l.hp -= 6;
          g.j(10);
          return '浜に並んで座り、日が沈むまで波を眺めた。';
        }),
      Choice.h('旅はもうよい、と家に残る', '体は守れる。心残りがあるかもしれない', () {
        _heal(g, 5);
        return '縁側から、遠い山の端を眺めるだけにした。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 幼い日の面影
  // ==================================================================
  _late('oa_child_days', 55, _w, (g) => true, (g, next) {
    if (g.hasFlag('met_nobunaga') || g.hasFlag('saw_nobunaga')) {
      g.ask('幼い日の面影', '孫たちに、幼い日に尾張の野で見た、うつけと呼ばれた若殿の話をせがまれた。', [
        Choice.h('見たままを語る', '話は小さい。嘘はない', () {
          g.setFlag('oa_child_days_told');
          g.j(3);
          return '瓜をかじりながら馬を飛ばす若殿の姿を、思い出せるかぎり語った。';
        }),
        Choice.h('少し大きく語る', '孫たちは喜ぶ。話は勝手に広まる', () {
          g.setFlag('oa_child_days_told');
          g.l.fame += 1;
          g.j(5);
          return 'いつのまにか、若殿と相撲を取った話になっていた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('met_kenshin')) {
      g.ask('幼い日の面影', '越後の寺で言葉を交わした少年が、のちの謙信公だった。その話を、若い者たちが聞きたがる。', [
        Choice.h('寺での一日を語る', '若い者は耳を澄ます。昔の日が近くなる', () {
          g.setFlag('oa_child_days_told');
          g.j(4);
          return '少年の澄んだ目のことを語ると、座は静かになった。';
        }),
        Choice.h('多くは語らない', '話は胸にしまっておく', () {
          g.j(1);
          return 'ただ、強い目をした子だった、とだけ言った。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('dog')) {
      g.ask('幼い日の面影', '縁側で日に当たっていると、白い子犬が迷い込んできた。幼い日に飼っていたシロにそっくりだ。', [
        Choice.h('飼うことにする', '暮らしが賑やかになる。老いた身に世話は手間だ', () {
          g.setFlag('oa_child_days_dog');
          g.j(8);
          return '子犬は、その日から縁側の下に住みついた。';
        }),
        Choice.h('飼い主を探してやる', '子犬は帰る。少し寂しい', () {
          g.j(2);
          return '隣村の子が、泣きながら子犬を抱き取っていった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('saw_battle')) {
      g.ask('幼い日の面影', '幼い日に戦を見た野を、久しぶりに通った。いまは一面の田になっている。', [
        Choice.h('畦に腰を下ろし、しばらく眺める', '心が静まる。昔の声が聞こえる気がする', () {
          g.setFlag('oa_child_days_told');
          g.j(3);
          return '稲穂の揺れる音の向こうに、あの日の鬨の声が聞こえた気がした。';
        }),
        Choice.h('足を止めずに通り過ぎる', '何も起きない', () {
          return '振り返らずに、野を通り過ぎた。';
        }),
      ], after: next);
      return;
    }
    g.ask('幼い日の面影', '幼い日に手習いに通った寺が、取り壊されると聞いた。', [
      Choice.h('寄進して、本堂だけでも残させる', '銭は減る。幼い日の場所が残る', () {
        _pay(g, 8);
        g.setFlag('oa_child_days_temple');
        g.mark('幼い日に手習いに通った寺に寄進し、本堂を残させた');
        return '机を並べた本堂の板の間に、もう一度座ってみた。';
      }),
      Choice.h('最後に一度、見に行く', '名残は惜しめる。何も残らない', () {
        g.j(2);
        return '柱に残る、誰かの落書きを指でなぞった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 古戦場
  // ==================================================================
  _late('oa_battlefield', 55, _w, (g) => true, (g, next) {
    g.ask('古戦場', '若い日に戦った野を通りかかった。いまは一面の麦畑で、畦の端に崩れかけた塚がある。', [
      Choice.h('敵味方の別なく、塚に手を合わせる', '心が静まる。何も変わらない', () {
        g.setFlag('oa_field_prayed');
        g.j(3);
        return '塚の前で、名も知らぬ者たちのために手を合わせた。';
      }),
      Choice.h('土地の者に銭を渡し、塚を直させる', '死んだ者が眠れる。銭は減る', () {
        _pay(g, 5);
        g.setFlag('oa_field_mound');
        g.mark('若い日に戦った野の塚を、土地の者に直させた');
        return '翌年通りかかると、塚には新しい石が据えられ、花が供えてあった。';
      }),
      Choice.h('連れの若い者に、ここで何があったかを語る', '戦の重みが伝わる。思い出したくないこともある', () {
        g.setFlag('oa_field_told');
        g.l.net += 1;
        return '若い者は、麦畑を見る目を変えた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 老舗の行方
  // ==================================================================
  _late(
    'oa_shop',
    55,
    _w,
    (g) => g.l.rank == 0 && !_monk(g) && (_retired(g) || g.age >= 60),
    (g, next) {
      g.ask('店の行方', '店の若い者たちが大きな取引でしくじり、蔵が空になりかけていると、古い番頭が知らせてきた。', [
        Choice.h('店に戻って采配を振るう', '店は持ち直すかもしれない。若い者の顔は潰れる', () {
          g.l.hp -= 5;
          if (g.rng.chance(.5 + g.l.sei / 200)) {
            g.l.gold += 10;
            g.setFlag('oa_shop_saved');
            g.mark('老いて店に戻り、傾きかけた店を立て直した');
            return '古い取引先を一軒ずつ回り、店はどうにか持ち直した。';
          }
          g.j(-4);
          return '昔のやり方は、もう通じなかった。';
        }),
        Choice.h('蓄えておいた銭を出す', '蔵は埋まる。手元は寂しくなる', () {
          _pay(g, g.l.gold ~/ 2);
          g.setFlag('oa_shop_funded');
          return '床下の甕から銭を出し、黙って番頭に渡した。';
        }),
        if (g.l.sei >= 60)
          Choice.h('帳面を見て、しくじりの元だけを教える', '若い者が学ぶ。手間はかかる', () {
            g.setFlag('oa_shop_taught');
            g.l.net += 1;
            g.mark('しくじった店の帳面を見て、若い者に商いの急所を教えた');
            return '帳面の一行を指で叩くと、若い者たちは青くなり、それから深くうなずいた。';
          }),
        Choice.h('任せたのだから口は出さぬ', '店は若い者のものだ。潰れるかもしれない', () {
          if (g.rng.chance(.5)) {
            g.j(-6);
            return '店は人手に渡った。暖簾が外されるのを、遠くから見ていた。';
          }
          g.j(2);
          return '若い者たちは、自分たちの手でどうにか持ち直した。';
        }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 老僧
  // ==================================================================
  _late('oa_monk', 55, _w, (g) => true, (g, next) {
    g.ask('老僧', '寺に、若い僧たちが教えを請いに集まるようになった。都の大きな寺からも、招きの使いが来た。', [
      Choice.h('都の寺へ上る', '名は上がる。山の寺の者たちは寂しがる', () {
        g.l.fame += 5;
        g.setFlag('oa_monk_capital');
        g.mark('老いて、都の大きな寺に招かれた');
        return '都の寺の大きな本堂で、多くの人を前に説いた。';
      }),
      Choice.h('山の寺に残り、若い僧を育てる', '名は広まらない。教えは残る', () {
        g.setFlag('oa_monk_stayed');
        g.l.net += 2;
        g.j(4);
        return '使いを丁重に帰し、明くる朝も若い僧たちと庭を掃いた。';
      }),
      if (g.l.chi >= 65)
        Choice.h('一生かけて学んだことを書にまとめる', '後の世に残る。目と肩がつらい', () {
          g.setFlag('oa_monk_book');
          g.l.fame += 2;
          g.mark('一生かけて学んだ教えを、書にまとめた');
          return '灯の下で筆を運び、冬が三度過ぎるころに書き上げた。';
        }),
    ], after: next);
  }),

  // ==================================================================
  // 老いた忍び
  // ==================================================================
  _late('oa_shinobi', 50, _w, (g) => !_monk(g), (g, next) {
    g.ask('老いた忍び', '里の若い者が、誰にも教えていない術を伝えてくれと頼みに来た。同じころ、昔の雇い主の家の者らしい影が、家の周りをうろついている。', [
      Choice.h('術を若い者に伝える', '術は生き残る。若い者が背負うものも増える', () {
        g.setFlag('oa_shinobi_passed');
        g.l.net += 1;
        g.mark('老いて、秘めていた術を里の若い者に伝えた');
        return '夜ごと、灯を消した部屋で、指の運びから教えた。';
      }),
      Choice.h('術を記した巻物を焼き、墓まで持っていく', '術は絶える。誰も危うくならない', () {
        g.setFlag('oa_shinobi_burned');
        g.j(2);
        return '巻物が炎の中で丸まっていくのを、最後まで見届けた。';
      }),
      Choice.h('影の正体を確かめに出る', '昔の勘が戻る。老いた体が追いつくかは分からない', () {
        if (g.rng.chance(.04)) {
          g.die('老いた身で昔の雇い主の影を追い、闇の中で斬られた', 'ansatsu');
          return '影は一つではなかった。';
        }
        if (g.l.bu + g.rng.range(0, 40) > 55) {
          g.l.fame += 1;
          g.j(4);
          return '影を追いつめると、昔の雇い主の家の若い忍びだった。様子を見に来ただけだと、慌てて逃げていった。';
        }
        g.l.hp -= 8;
        return '影は消えた。追ううちに足をくじいた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 若い殿の相談（隠居した家臣）
  // ==================================================================
  _late(
    'oa_young_lord',
    55,
    _w,
    (g) =>
        _retired(g) &&
        g.l.maxRank >= 3 &&
        g.l.maxRank <= 7 &&
        _lordAlive(g),
    (g, next) {
      final house = houseName(g, g.l.lord);
      g.ask('若い殿の相談', '$house家の若い殿が、お忍びで隠居所を訪ねてきた。家中の古い者を退け、新しい掟を敷きたいと言う。', [
        Choice.h('若い者の世だと励ます', '若い殿は喜ぶ。古い者は恨むかもしれない', () {
          g.setFlag('oa_lord_backed');
          g.l.fav = _c100(g.l.fav + 5);
          return '若い殿は晴れやかな顔で帰っていった。';
        }),
        Choice.h('急ぐなと諫める', '筋は通る。若い殿は不機嫌になるかもしれない', () {
          if (g.rng.chance(.5)) {
            g.setFlag('oa_lord_warned');
            g.l.fame += 1;
            return '若い殿はしばらく考え込み、やがて頭を下げた。';
          }
          g.l.fav = _c100(g.l.fav - 5);
          return '若い殿は口を結んだまま、席を立った。';
        }),
        if (g.l.chi >= 65)
          Choice.h('古い者と若い者を、一つの席に呼ぶよう勧める', '家中がまとまるかもしれない。知恵と顔が要る', () {
            g.setFlag('oa_lord_bridge');
            g.l.fame += 2;
            g.mark('若い殿に、古い者と若い者を一つ席に呼ぶよう勧めた');
            return '古い者と若い者が同じ膳を囲んだ。わだかまりは、少しずつほどけていった。';
          }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 老いた信者（伴天連追放のあと）
  // ==================================================================
  _late(
    'oa_faith',
    50,
    _w,
    (g) => g.year >= 1587 && !_monk(g),
    (g, next) {
      g.ask('老いた信者', '伴天連を追う令が出てから、教えを守る者の肩身は狭い。臨終には司祭を呼びたいが、近くにはもういない。', [
        Choice.h('ひそかに十字を握って祈る', '信は守れる。見つかれば家に累が及ぶ', () {
          g.setFlag('oa_faith_kept');
          g.j(3);
          return '夜ごと、小さな十字を握りしめて祈った。';
        }),
        Choice.h('寺の檀家として葬られることにする', '家は守れる。心は揺れる', () {
          g.setFlag('oa_faith_temple');
          g.j(-3);
          return '寺に名を届けた夜、長いあいだ眠れなかった。';
        }),
        Choice.h('長崎まで司祭を訪ねる旅に出る', '会えれば心が満ちる。老いた身に旅は遠い', () {
          g.l.hp -= 12;
          _pay(g, 5);
          g.setFlag('oa_faith_journey');
          g.mark('老いて、長崎まで司祭を訪ねた');
          return '長崎の小さな家で、年老いた司祭が手を取って祈ってくれた。';
        }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 村の長老
  // ==================================================================
  _late(
    'oa_village',
    55,
    _w,
    (g) => g.l.rank == 0 && !_monk(g) && !g.hasFlag('way_merchant'),
    (g, next) {
      g.ask('村の長老', '村の寄合で、若い衆と年寄りの言い分が割れた。若い衆は山の入会を隣村と分け直したいと言う。皆が、あなたの顔を見ている。', [
        Choice.h('昔からの決まりを守れと言う', '年寄りは喜ぶ。若い衆は不満を溜める', () {
          g.setFlag('oa_village_old');
          return '若い衆は黙り込んだ。寄合は、いつもより早く終わった。';
        }),
        Choice.h('若い衆に任せてみる', '村が変わる。しくじれば年寄りが怒る', () {
          g.setFlag('oa_village_young');
          g.l.net += 1;
          return '若い衆の顔が明るくなった。年寄りたちは渋い顔をした。';
        }),
        if (g.l.sei >= 60 || g.l.mi >= 60)
          Choice.h('隣村の長老と、じかに話をつけに行く', '争いを避けられるかもしれない。老いた足には遠い', () {
            g.l.hp -= 5;
            g.setFlag('oa_village_settled');
            g.mark('老いて、隣村の長老と山の入会の話をつけた');
            return '隣村の長老とは、若い頃に水争いで睨み合った仲だった。二人で笑い、話はその日のうちについた。';
          }),
      ], after: next);
    },
  ),

  // ==================================================================
  // 嫁との間（老いた母）
  // ==================================================================
  _late(
    'oa_yome',
    50,
    _w * .8,
    (g) =>
        g.l.female &&
        !_monk(g) &&
        (g.l.eldestKidAge(g.year) ?? (g.age >= 50 ? 99 : 0)) >= 18,
    (g, next) {
      g.ask('嫁との間', '息子の嫁が、家の流儀に馴染まない。煮物の味も、供え物の並べ方も違う。', [
        Choice.h('家の流儀を厳しく仕込む', '家の流儀は守られる。嫁は陰で泣く', () {
          g.setFlag('oa_yome_strict');
          return '嫁は唇を噛んで、言われたとおりにした。';
        }),
        Choice.h('嫁の流儀に任せる', '家の味が変わる。嫁は気が楽になる', () {
          g.setFlag('oa_yome_kind');
          g.j(2);
          return '嫁の煮物は、少し甘かった。慣れると悪くなかった。';
        }),
        Choice.h('嫁の里の料理を教わる', '嫁は驚く。二人の間がほどける', () {
          g.setFlag('oa_yome_learned');
          g.j(4);
          g.mark('息子の嫁に、その里の料理を教わった');
          return '台所に並んで立つと、嫁は初めて声を立てて笑った。';
        }),
      ], after: next);
    },
  ),
];
