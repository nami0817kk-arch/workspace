import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';
import 'women_life.dart';

/// 仏門の道（2026-11-23、ユーザー「作り込みをストップというまで続けて」）。
///
/// 人生の約1割強が仏門に進むのに、仏門だけの今年の重点は「修行に打ち込む」「人々に説いて回る」の二つ、
/// 岐路も `ways.dart` の住持・遊行・弟子ほどだったので、寺の暮らしの重点と岐路を足した。
/// id・旗は `tm_`（最期の仏門の `p_`、暮らしと嗜みの `ps_` と紛れないように）。
///
/// - 重点 5（[templeFocusOptions]）: 寺の田畑と台所・経典と論義（尼は女人の講）・施餓鬼や弔い・子らの手習い・山の行。
///   いつもの重点と暮らしと嗜みの重点のうしろに、1年に [templeFocusCap] まで足す。
///   はじめて選んだ年は始めの岐路（一生に一度）、2回目からは選んだ年の半分ほどで小さな岐路
///   （`<id>_again`、`repeat`）。どちらも `onlyForced`。
/// - 岐路 15（[kTempleSceneIds]。一生に一度、重み2〜2.5）。使僧は男の僧だけ、出家を願う後家は尼だけ。
///   僧に斬り合いの手は出さない（寺領に踏み込んだ兵の場面だけ、武に優れた男の僧に門を固める手がある）。

/// 1年に「今年の重点」に足す、仏門の重点の数の上限。
/// 仏門のいつもの重点（4つ）と、暮らしと嗜みの重点（`kPastimesPerYear`）に足すので、二つまで。
const kTemplePerYear = 2;

/// その人に、その年に足す仏門の重点の上限。尼には女性の暮らしの重点「女人の参る寺を守る」が一つ足されるので、一つ減らす。
int templeFocusCap(Game g) =>
    womanKind(g) == WomanKind.nun ? kTemplePerYear - 1 : kTemplePerYear;

/// 仏門の暮らしをしている（`adultFocusOptions` の分け方と同じ順: 隠居・商い・野の道が先）。
bool templeLife(Game g) {
  final l = g.l;
  if (!g.hasFlag('priesthood') || g.hasFlag('retired')) return false;
  if (l.rank == 0 && (g.hasFlag('way_merchant') || g.hasFlag('way_outlaw'))) {
    return false;
  }
  return true;
}

int _c(int v) => clampInt(v, 0, 99);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _down(Game g, int n) => g.l.net = g.l.net >= n ? g.l.net - n : 0;
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;

String _season(Game g) => g.l.t % 2 == 0
    ? g.rng.pick(['田植えの終わった頃', '若葉の頃', '梅雨の晴れ間'])
    : g.rng.pick(['稲刈りの済んだ頃', '木枯らしの吹く頃', '雪の便りの届く頃']);

/// 回を重ねた年の書き出し（2回目は [second]、以降は [more] から一つ。{季} は時節）。
String _intro(Game g, String tag, String second, List<String> more) =>
    (_n(g, tag) <= 2 ? second : g.rng.pick(more)).replaceAll('{季}', _season(g));

/// 始めの一回がまだなら始めの岐路。済んでいれば、半分ほどの年に小さな岐路。
String? _forcedFor(Game g, String id) {
  if (!g.hasFlag('scene:$id')) return id;
  return g.rng.chance(.5) ? '${id}_again' : null;
}

/// 寺のある国から近い家（勢力の残っている家だけ）。
List<String> _nearHouses(Game g, int n) {
  final a = g.alive;
  if (a.isEmpty) return const [];
  return [
    for (final f in nearest(a, (f) => f.name, region: g.l.region, n: n)) f.name,
  ];
}

String _hn(Game g, String n) => '${houseName(g, n)}家';

/// 若い僧・尼（場面の言い分け）。
String _young(Game g) => g.l.female ? '若い尼' : '若い僧';

// ======================================================================
// 重点
// ======================================================================

class _TFocus {
  const _TFocus(this.tag, this.ok, this.make);
  final String tag;
  final bool Function(Game g) ok;
  final FocusDef Function(Game g) make;
}

final _focuses = <_TFocus>[
  // ---- 寺の田畑と台所を切り盛りする（政・銭）----
  _TFocus(
    'tm_estate',
    templeLife,
    (g) => FocusDef(
      'tm_estate',
      '寺の田畑と台所を切り盛りする',
      '寺の蔵が締まり、銭も回る。俗事に追われて、修行は進まない',
      (g) {
        if (g.rng.chance(.5)) g.l.sei = _c(g.l.sei + 1);
        g.l.gold += g.rng.range(2, 6);
        g.l.hp -= 2;
      },
      forced: _forcedFor(g, 'tm_estate'),
    ),
  ),

  // ---- 経典を学び、論義に備える（尼は女人の講で説く備え。知）----
  _TFocus(
    'tm_sutra',
    templeLife,
    (g) => FocusDef(
      'tm_sutra',
      g.l.female ? '経典を学び、講で説く備えをする' : '経典を学び、論義に備える',
      '教えが深まり、人前で名を上げる折も来る。詰まれば恥をかく',
      (g) {
        final l = g.l;
        l.chi = _c(
          l.chi + (l.chi < 85 ? g.rng.range(1, 3) : (g.rng.chance(.5) ? 1 : 0)),
        );
        l.hp -= 1;
        g.j(1);
      },
      forced: _forcedFor(g, 'tm_sutra'),
    ),
  ),

  // ---- 施餓鬼や弔いを務める（人脈・銭・名声）----
  _TFocus(
    'tm_rites',
    templeLife,
    (g) => FocusDef(
      'tm_rites',
      '施餓鬼や弔いを務める',
      '檀家とのつながりが深まり、布施も入る。死に向き合う務めは心を削る',
      (g) {
        g.l.net += g.rng.range(1, 3);
        g.l.gold += g.rng.range(1, 4);
        if (g.rng.chance(.4)) g.l.fame += 1;
        g.j(-1);
      },
      forced: _forcedFor(g, 'tm_rites'),
    ),
  ),

  // ---- 子らに手習いを教える（人脈・名声）----
  _TFocus(
    'tm_teach',
    (g) => templeLife(g) && g.age >= 22,
    (g) => FocusDef(
      'tm_teach',
      '寺で子らに手習いを教える',
      '子らに慕われ、寺の名も上がる。いたずら盛りの相手は骨が折れる',
      (g) {
        g.l.net += g.rng.range(1, 2);
        if (g.rng.chance(.4)) g.l.fame += 1;
        if (g.rng.chance(.3)) g.l.chi = _c(g.l.chi + 1);
        g.j(3);
      },
      forced: _forcedFor(g, 'tm_teach'),
    ),
  ),

  // ---- 山にこもって行をする（体・幸福・知。危うさもある）----
  _TFocus(
    'tm_retreat',
    (g) => templeLife(g) && g.age <= 65,
    (g) =>
        FocusDef('tm_retreat', '山にこもって行をする', '心と体が研ぎ澄まされる。山の行は、身を損なう者もいる', (g) {
          if (g.rng.chance(.3)) g.l.bu = _c(g.l.bu + 1);
          if (g.rng.chance(.4)) g.l.chi = _c(g.l.chi + 1);
          g.l.hp -= 4;
          g.j(4);
        }, forced: _forcedFor(g, 'tm_retreat')),
  ),
];

/// 仏門の暮らしに合う重点の tag（乱数を使わない。テスト用にも出す）。
List<String> templeTags(Game g) => [
  for (final f in _focuses)
    if (f.ok(g)) f.tag,
];

/// その年に出す、仏門の重点（[templeFocusCap] まで）。
/// 当てはまるものが多いときは無作為に選ぶ（並びの順は保つ）。岐路を決める乱数は選ばれたものにだけ使う。
/// 仏門でない人には乱数を使わない（ほかの人生の流れを変えないため）。
List<FocusDef> templeFocusOptions(Game g) {
  final cand = [
    for (final f in _focuses)
      if (f.ok(g)) f,
  ];
  if (cand.isEmpty) return const [];
  final cap = templeFocusCap(g);
  if (cap <= 0) return const [];
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
// 重点で選んだ年の岐路
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

List<SceneDef> _focusScenes() => [
  // ==================================================================
  // 寺の田畑と台所
  // ==================================================================
  _first('tm_estate', (g, next) {
    final l = g.l;
    g.ask(
      '寺の台所',
      '寺の田を預かる百姓たちが、今年は日照りで実りが悪いので、寺に納める米を負けてほしいと頭を下げてきた。蔵の米は、心もとない。',
      [
        Choice.h('願いを聞き入れ、半分に負ける', '百姓たちの心は寺に寄る。寺の台所は苦しくなる', () {
          l.net += 3;
          _pay(g, 3);
          g.j(2);
          g.setFlag('tm_estate_kind');
          return '百姓たちは何度も頭を下げ、秋の終わりに薪を山ほど運んできた。';
        }),
        Choice.h('帳面どおりに納めさせる', '寺の蔵は守れる。百姓たちは陰で寺を恨む', () {
          l.gold += 4;
          _down(g, 2);
          return '米は納められた。百姓たちは、目を合わせずに帰っていった。';
        }),
        Choice.h('自ら田に出て、水の引き方を見直す', '来年からの実りが変わるかもしれない。慣れぬ田仕事は骨が折れる', () {
          l.hp -= 5;
          if (g.rng.chance(.4 + l.sei / 200)) {
            l.sei = _c(l.sei + 2);
            l.gold += 3;
            l.net += 1;
            g.setFlag('tm_estate_field');
            g.mark('寺の田の水の引き方を見直し、実りを増やした');
            return '古い溝をさらい、水の回りを変えた。次の年、寺の田の稲穂は重く垂れた。';
          }
          g.j(-1);
          return '泥にまみれて溝を掘ったが、日照りの前には焼け石に水だった。';
        }),
      ],
      after: next,
    );
  }),
  _again('tm_estate', (g, next) {
    final l = g.l;
    final head = _intro(g, 'tm_estate', 'また寺の台所を預かる一年が過ぎた。', [
      '{季}、寺の蔵の帳面を改めた。',
      '寺男が、台所の薪が足りないとこぼしている。',
      '檀家から届いた米俵を、蔵に積み直した。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('寺の蔵', '$head蔵の米俵に、鼠のかじった穴が見つかった。', [
        Choice.h('猫を飼う', '鼠は減る。寺の者も和む', () {
          g.j(3);
          return '迷い込んだ三毛を飼うことにした。蔵の鼠は、ほどなく姿を消した。';
        }),
        Choice.h('蔵の床を張り替える', '鼠は入らなくなる。銭がかかる', () {
          _pay(g, 4);
          l.gold += 1;
          return '大工を呼び、蔵の床を張り替えた。';
        }),
      ], after: next);
      return;
    }
    g.ask('門前の市', '$head寺で仕込んだ味噌を、門前の市で売ってはどうかと寺男が言う。', [
      Choice.h('市に出す', '寺の台所が潤う。商いに精を出す寺と陰口も叩かれる', () {
        l.gold += g.rng.range(3, 7);
        if (g.rng.chance(.3)) l.fame -= 1;
        return '寺の味噌は評判になり、昼前に売り切れた。';
      }),
      Choice.h('檀家に配る', '銭にはならない。檀家は喜ぶ', () {
        l.net += 2;
        g.j(2);
        return '味噌の壺を抱えて、檀家の家々を回った。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 経典と論義（尼は女人の講）
  // ==================================================================
  _first('tm_sutra', (g, next) {
    final l = g.l;
    if (l.female) {
      g.ask('女人の講', '近在の女たちが集う講で、経の一節を説くことになった。字の読めない女も多く、皆が身を乗り出している。', [
        Choice.h('経の言葉どおりに読み下す', '間違いはない。女たちには難しすぎるかもしれない', () {
          l.chi = _c(l.chi + 1);
          return '女たちは神妙に聞いていたが、半ばで舟を漕ぐ者もいた。';
        }),
        Choice.h('暮らしの喩えに引き寄せて説く', '女たちの胸に届けば、講が賑わう。崩しすぎれば、教えを曲げることになる', () {
          if (g.rng.chance(.35 + (l.chi + l.mi) / 300)) {
            l.fame += 4;
            l.net += 3;
            g.setFlag('tm_ko_praised');
            g.mark('女人の講で、経を暮らしの喩えで説いて慕われた');
            return '竈の火や子の熱に喩えて説くと、涙ぐむ女もいた。次の講には、倍の女たちが集まった。';
          }
          g.j(-3);
          return '喩えが過ぎて、年かさの女に「それでは経が泣きます」とたしなめられた。';
        }),
        Choice.h('一人ずつの悩みを聞く場にする', '女たちの心は軽くなる。経の学びは進まない', () {
          l.net += 2;
          g.j(3);
          return '姑のこと、夫のこと、亡くした子のこと。話は日暮れまで尽きなかった。';
        }),
      ], after: next);
      return;
    }
    g.ask('論義の座', '本山の法会で、論義の座に連なることになった。居並ぶ学僧の前で、経の一節について問いを受ける。', [
      Choice.h('先達の説どおりに答える', '無難に済む。目立つこともない', () {
        l.chi = _c(l.chi + 1);
        g.j(1);
        return '先達の説を引いて答えた。問者は小さくうなずき、次の者へ移った。';
      }),
      Choice.h('自らの解釈を述べる', '冴えていれば名が上がる。外せば、居並ぶ学僧の失笑を買う', () {
        if (g.rng.chance(.2 + l.chi / 150)) {
          l.fame += 5;
          l.chi = _c(l.chi + 2);
          g.setFlag('tm_rongi_praised');
          g.mark('本山の法会の論義で、自らの解釈を述べて称えられた');
          return '座がしんと静まり、やがて老いた学僧が「よう読んだ」とつぶやいた。';
        }
        l.fame -= 2;
        g.j(-4);
        return '言葉が先走り、問者に一言で退けられた。座のあちこちで、忍び笑いが漏れた。';
      }),
      Choice.h('問いの意味を問い返して、時を稼ぐ', '切り抜けられるかもしれない。小賢しいと見られることもある', () {
        if (g.rng.chance(.5)) {
          l.chi = _c(l.chi + 1);
          return '問い返すうちに考えがまとまり、どうにか答えを結んだ。';
        }
        l.fame -= 1;
        return '問者は眉をひそめ、「問いに問いで返すな」と言った。';
      }),
    ], after: next);
  }),
  _again('tm_sutra', (g, next) {
    final l = g.l;
    final head = _intro(g, 'tm_sutra', 'また経典に向かう一年が過ぎた。', [
      '{季}、経蔵にこもって経を読んだ。',
      '灯明の下で、経の注釈を読み進めた。',
      '読み慣れた経の一節に、新しい意味が見えた気がした。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('経蔵', '$head経蔵の古い経巻が、虫に食われているのを見つけた。', [
        Choice.h('書き写して残す', '教えが後の世に残る。目と肩は疲れる', () {
          l.chi = _c(l.chi + 1);
          l.hp -= 3;
          return '一字ずつ、新しい紙に写していった。';
        }),
        Choice.h('虫干しだけにする', '手間は少ない。傷んだところは戻らない', () {
          g.j(1);
          return '晴れた日に経巻を広げ、風を通した。';
        }),
      ], after: next);
      return;
    }
    final young = _young(g);
    g.ask('経蔵', '$head$youngが、経の一節の解き方を尋ねてきた。', [
      Choice.h('自ら考えさせる', '若い者が伸びるかもしれない。突き放されたと思うかもしれない', () {
        if (g.rng.chance(.5)) {
          l.fame += 1;
          return 'ひと月のち、$youngは自分なりの読みを携えて戻ってきた。';
        }
        g.j(-1);
        return '$youngは肩を落として去った。';
      }),
      Choice.h('丁寧に教える', '慕われる。自分の学びの時間は減る', () {
        l.net += 2;
        g.j(2);
        return '夜更けまで、膝を突き合わせて経を読んだ。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 施餓鬼と弔い
  // ==================================================================
  _first('tm_rites', (g, next) {
    final l = g.l;
    g.ask(
      '施餓鬼',
      '盂蘭盆の施餓鬼会を任された。供物の棚の前に、村の者が集まってくる。名も知れず死んだ者の供養も頼みたいと、年寄りが言う。',
      [
        Choice.h('無縁の者も分け隔てなく供養する', '村の者の心に残る。布施は増えない', () {
          l.fame += 2;
          l.net += 2;
          g.j(2);
          g.setFlag('tm_segaki_all');
          g.mark('施餓鬼会で、名も知れず死んだ者たちを分け隔てなく供養した');
          return '行き倒れた旅人、戦で死んだ足軽、流行り病の子。名のない者たちのために、長く経を読んだ。';
        }),
        Choice.h('布施の多い家の名から読み上げる', '寺の蔵は潤う。貧しい家は肩身が狭い', () {
          l.gold += 5;
          _down(g, 1);
          return '名を呼ばれた家の主は胸を張り、後ろの列の者はうつむいた。';
        }),
        Choice.h('自ら供物の棚を回って、施しを足す', '心のこもった会になる。体は疲れる', () {
          l.hp -= 3;
          l.net += 1;
          g.j(4);
          return '炎天の下、棚から棚へ、水と飯を供えて回った。';
        }),
      ],
      after: next,
    );
  }),
  _again('tm_rites', (g, next) {
    final l = g.l;
    final head = _intro(g, 'tm_rites', 'また弔いに呼ばれる一年だった。', [
      '{季}、野辺送りの列に加わった。',
      '弔いの鉦の音が、村の道を遠ざかっていく。',
      '今年も、見知った顔が幾人も鬼籍に入った。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('弔いの夜', '$head裕福な家の主の弔いで、銭を積むから立派な戒名をつけてくれと頼まれた。', [
        Choice.h('頼まれたとおりにつける', '寺の蔵が潤う。人の徳を銭で量ることになる', () {
          l.gold += 6;
          g.j(-2);
          return '格の高い戒名を書いた位牌に、家の者は満足げだった。';
        }),
        Choice.h('故人の生き方に合った名をつける', '筋は通る。家の者は不満かもしれない', () {
          if (g.rng.chance(.5)) {
            _down(g, 1);
            return '家の者は不満げに、布施を少なく包んだ。';
          }
          l.fame += 1;
          return '名の由来を語ると、家の者は黙って聞き入り、やがて深く頭を下げた。';
        }),
      ], after: next);
      return;
    }
    g.ask('野辺送り', '$head貧しい家の野辺送りを頼まれた。布施は、粟がひと袋きりだという。', [
      Choice.h('快く務める', '布施は少ない。家の者は涙を流して喜ぶ', () {
        l.net += 2;
        l.fame += 1;
        g.j(2);
        return '粟の袋を押しいただき、丁寧に経を読んだ。';
      }),
      Choice.h('寺の者に任せる', '手間は省ける。薄情と見られるかもしれない', () {
        if (g.rng.chance(.3)) _down(g, 1);
        return '寺の若い者を行かせた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 子らの手習い
  // ==================================================================
  _first('tm_teach', (g, next) {
    final l = g.l;
    g.ask('手習いの師', '寺の一間で、村の子らに読み書きを教えることになった。初日から、筆も持ったことのない子らがずらりと並んでいる。', [
      Choice.h('厳しく仕込む', '字はよく身につく。逃げ出す子も出る', () {
        g.j(-1);
        if (g.rng.chance(.5)) {
          l.fame += 2;
          g.setFlag('tm_teacher_strict');
          return '一年のうちに、子らは証文くらいは読めるようになった。';
        }
        _down(g, 1);
        return '泣いて逃げ帰る子が出て、親が文句を言いに来た。';
      }),
      Choice.h('遊びを交えて教える', '子らは喜んで通う。覚えはゆっくりだ', () {
        l.net += 3;
        g.j(4);
        g.setFlag('tm_teacher_kind');
        return 'いろは歌を節をつけて唄わせると、子らは帰り道でも唄っていた。';
      }),
      Choice.h('謝礼の払えない子からは、何も取らない', '貧しい子も学べる。寺の台所は痛む', () {
        _pay(g, 2);
        l.fame += 2;
        l.net += 2;
        g.setFlag('tm_teacher_free');
        g.mark('寺で、謝礼の払えない子らにも読み書きを教えた');
        return '噂を聞いて、遠くの村からも子らが通ってくるようになった。';
      }),
    ], after: next);
  }),
  _again('tm_teach', (g, next) {
    final l = g.l;
    final head = _intro(g, 'tm_teach', 'また子らに手習いを教える一年が過ぎた。', [
      '{季}、寺の一間に子らの声が響く。',
      '昔の教え子が、自分の子を連れてきた。',
      '子らの書いた手本が、壁に並んでいる。',
    ]);
    if (g.rng.chance(.5)) {
      final kid = g.rng.pick(kGivenM);
      g.ask('手習いの子ら', '$head教え子の$kidは、ずば抜けて覚えがよい。だが親は、百姓の子に学問は要らぬと言う。', [
        Choice.h('親を説き伏せて、学ばせ続ける', '子の道が開けるかもしれない。親には疎まれる', () {
          if (g.rng.chance(.5 + l.mi / 300)) {
            g.setFlag('tm_bright_pupil');
            g.meet('手習いの教え子', kid, 55);
            g.mark('覚えのよい教え子の親を説き伏せ、学ばせ続けた');
            return '親はしぶしぶ折れた。$kidは、目を輝かせて筆を取った。';
          }
          _down(g, 1);
          return '親は首を縦に振らず、$kidは田へ戻された。';
        }),
        Choice.h('親の言葉に従う', '角は立たない。子は田に戻る', () {
          g.j(-2);
          return '$kidは、最後の日に深々と頭を下げて帰っていった。';
        }),
      ], after: next);
      return;
    }
    g.ask('手習いの子ら', '$head子らが本堂で追いかけっこをして、障子を破った。', [
      Choice.h('叱りつける', '寺の規律は保たれる。子らは縮こまる', () {
        g.j(-1);
        return '子らは並んで頭を垂れた。その日の手習いは、やけに静かだった。';
      }),
      Choice.h('障子の張り替えを手伝わせる', '子らは学ぶ。手間は倍になる', () {
        l.net += 1;
        g.j(3);
        return '糊だらけになりながら、子らと障子を張り替えた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 山の行
  // ==================================================================
  _first('tm_retreat', (g, next) {
    final l = g.l;
    g.ask('山の行', '寺の裏山の奥、滝のかかる岩屋にこもって、行をすることにした。食を断ち、滝に打たれる日々が続く。', [
      Choice.h('決めた日数を、最後まで貫く', '心は研ぎ澄まされる。山の行で、命を落とす者もいる', () {
        if (g.rng.chance(.03)) {
          g.die('山の岩屋にこもって行を続けたまま、帰らなかった', 'yukue');
          return '満願の日を過ぎても、岩屋から下りてくる姿はなかった。';
        }
        l.hp -= 15;
        l.chi = _c(l.chi + 2);
        l.fame += 2;
        g.j(6);
        g.setFlag('tm_retreat_done');
        g.mark('裏山の岩屋にこもり、滝に打たれる行を貫いた');
        return '満願の朝、滝の音がまるで経のように聞こえた。';
      }),
      Choice.h('体の声を聞き、無理なく切り上げる', '体は守れる。悟りは遠いままかもしれない', () {
        l.hp -= 4;
        l.chi = _c(l.chi + 1);
        g.j(3);
        return '日数の半ばで山を下りた。それでも、目に映る景色は少し違って見えた。';
      }),
      Choice.h('里の猟師に頼み、さらに奥の峰へ分け入る', '誰も見ぬ景色に出会える。山は険しく、足を滑らせて命を落とす者もいる', () {
        if (g.rng.chance(.04)) {
          g.die('行の途中、奥の峰で足を滑らせて谷へ落ちた', 'sai');
          return '霧の濃い朝、岩の苔に足を取られた。';
        }
        l.hp -= 10;
        l.chi = _c(l.chi + 3);
        l.un = _c(l.un + 1);
        g.j(8);
        g.setFlag('tm_retreat_peak');
        g.mark('猟師の案内で、奥の峰に分け入って行をした');
        return '峰の上で、雲の海から日が昇るのを見た。';
      }),
    ], after: next);
  }),
  _again('tm_retreat', (g, next) {
    final l = g.l;
    final head = _intro(g, 'tm_retreat', 'また山にこもった。', [
      '{季}、ふたたび裏山の岩屋へ向かった。',
      '滝の水が、去年よりも冷たく感じる。',
      '岩屋の入口の草が、伸び放題になっていた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('山ごもり', '$head夜の岩屋に、獣の気配が近づいてきた。', [
        Choice.h('経を唱え続ける', '心は揺らがない。獣の気まぐれしだいで、傷を負う', () {
          if (g.rng.chance(.15)) {
            l.hp -= 10;
            return '猪に突き倒され、脇腹を痛めた。';
          }
          l.chi = _c(l.chi + 1);
          g.j(3);
          return '気配は、夜明け前にふっと消えた。';
        }),
        Choice.h('火を焚いて夜明けを待つ', '獣は近寄らない。行は乱れる', () {
          g.j(-1);
          return '火の番をしながら、眠れぬ夜を過ごした。';
        }),
      ], after: next);
      return;
    }
    g.ask('山ごもり', '$head山の中で、道に迷った木こりに出会った。', [
      Choice.h('里まで送り届ける', '人助けになる。行は一日遅れる', () {
        l.net += 1;
        g.j(2);
        return '木こりは、里に着くと何度も振り返って手を合わせた。';
      }),
      Choice.h('道だけ教えて、行に戻る', '行は続けられる。少し気にかかる', () {
        l.chi = _c(l.chi + 1);
        return '沢沿いに下れと教え、岩屋へ戻った。';
      }),
    ], after: next);
  }),
];

// ======================================================================
// 仏門の岐路（一生に一度）
// ======================================================================

/// 仏門の暮らしの岐路の id（テスト用）。
const kTempleSceneIds = [
  'tm_shuron',
  'tm_shiso',
  'tm_ryochi',
  'tm_kubi',
  'tm_danka',
  'tm_hakai',
  'tm_honzon',
  'tm_kanja',
  'tm_jono',
  'tm_atome',
  'tm_koji',
  'tm_segyo',
  'tm_kane',
  'tm_kito',
  'tm_goke',
];

List<SceneDef> _lifeScenes() => [
  // ---- 他宗との宗論 ----
  SceneDef('tm_shuron', 20, 80, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    g.ask(
      '辻の宗論',
      '町の辻に他宗の僧が立ち、あなたの寺の教えでは救われぬと声を張り上げている。檀家の中にも、足を止めて聞き入る者が出てきた。',
      [
        Choice.h('辻に出て、論じ返す', '勝てば寺の名が上がる。言い負かされれば、檀家が離れていく', () {
          if (g.rng.chance(.3 + l.chi / 200 + l.mi / 400)) {
            l.fame += 4;
            l.net += 2;
            g.setFlag('tm_shuron_win');
            g.mark('町の辻の宗論で、他宗の僧を言い負かした');
            return '集まった人垣から、どっと声が上がった。相手の僧は、黙って辻を去った。';
          }
          l.fame -= 3;
          _down(g, 2);
          g.j(-5);
          g.setFlag('tm_shuron_lost');
          return '言葉に詰まった。見ていた檀家が、一人、二人と去っていった。';
        }),
        Choice.h('寺で檀家に、静かに教えを説き直す', '騒ぎにはならない。去る者は去る', () {
          _down(g, 1);
          g.j(1);
          return '寺に残った檀家と、経を読み直した。';
        }),
        Choice.h('相手の僧を寺に招き、茶を出して語り合う', '争いは収まるかもしれない。弱腰と笑う者もいる', () {
          if (g.rng.chance(.4 + l.mi / 250)) {
            l.net += 2;
            g.j(3);
            return '茶をすするうちに、相手の僧も国の生まれを語り出した。辻の声は、やがて止んだ。';
          }
          l.fame -= 1;
          return '僧は茶に口もつけずに帰り、辻ではあなたを腰抜けと呼んだ。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 戦の陣中へ使僧として遣わされる（男の僧）----
  SceneDef(
    'tm_shiso',
    25,
    75,
    (g) => 2,
    (g) => templeLife(g) && !g.l.female && g.alive.length >= 2,
    (g, next) {
      final l = g.l;
      final near = _nearHouses(g, 2);
      final a = _hn(g, near.first);
      final b = _hn(g, near.length > 1 ? near[1] : near.first);
      g.ask(
        '使僧',
        '$aと$bが、国境で睨み合っている。和睦を探りたい$aから、使僧として$bの陣へ書状を携えてほしいと頼まれた。僧の身なら、敵の陣にも入れる。',
        [
          Choice.h('引き受け、両家の陣を行き来する', '和がなれば、名は国中に聞こえる。敵陣で斬られた使僧もいる', () {
            if (g.rng.chance(.03)) {
              g.die('和睦の使いに立った敵の陣で、斬られた', 'ansatsu');
              return '陣の幕をくぐったとき、背後で刀の鞘走る音がした。';
            }
            if (g.rng.chance(.35 + (l.chi + l.mi) / 400)) {
              l.fame += 8;
              l.net += 3;
              g.setFlag('tm_shiso_peace');
              g.mark('$aと$bの和睦を、使僧として取り次いだ');
              return '三度目に陣を訪ねた日、両家は起請文を取り交わした。';
            }
            l.fame += 1;
            g.j(-3);
            return '和はならず、ほどなく両家は槍を交えた。';
          }),
          Choice.h('書状を届けるだけにする', '危うさは小さい。和の行方には関われない', () {
            l.net += 1;
            l.fame += 1;
            return '書状を届け、返書を持ち帰った。中身は知らない。';
          }),
          Choice.h('仏門は俗世の争いに関わらぬと断る', '身は安らか。頼んだ家の覚えは悪くなる', () {
            _down(g, 1);
            g.j(1);
            return '使いの侍は、苦い顔で帰っていった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 寺領に兵が踏み込む ----
  SceneDef(
    'tm_ryochi',
    18,
    84,
    (g) => 2.5,
    (g) => templeLife(g) && g.alive.isNotEmpty,
    (g, next) {
      final l = g.l;
      final a = _hn(g, g.rng.pick(_nearHouses(g, 3)));
      final sohei = !l.female && g.canFight && l.bu >= 60;
      g.ask('寺領の兵', '$aの兵が寺の田に踏み込み、ここに陣を張ると言い出した。蔵の米も、兵糧として差し出せという。', [
        Choice.h('禁制の札を掲げて、退くよう説く', '筋は通る。聞き分けのない兵もいる', () {
          if (g.rng.chance(.4 + l.mi / 250 + l.fame / 300)) {
            l.fame += 3;
            g.setFlag('tm_ryochi_kept');
            g.mark('寺領に踏み込んだ兵を、禁制の札を掲げて退かせた');
            return '札を読んだ侍大将は舌打ちし、兵をまとめて引き揚げていった。';
          }
          _pay(g, 6);
          g.j(-4);
          return '兵は札を鼻で笑い、蔵の米を担ぎ出していった。';
        }),
        Choice.h('米を差し出し、本堂だけは守ってもらう', '寺は焼かれずに済む。蔵は空になる', () {
          _pay(g, 8);
          g.j(-2);
          return '米俵が運び出されていく。本堂には、誰も手をつけなかった。';
        }),
        Choice.h('寺の者を連れて、山へ退く', '命は守れる。戻ったとき、寺がどうなっているかは分からない', () {
          if (g.rng.chance(.3)) {
            _pay(g, 5);
            g.j(-6);
            return '兵が去ってから戻ると、仏具がいくつも持ち去られていた。';
          }
          g.j(-2);
          return '数日して戻ると、田は踏み荒らされていたが、寺は無事だった。';
        }),
        if (sohei)
          Choice.h(
            '若い僧を集めて門を固める',
            '寺は守れるかもしれない。血を流せば、命を落とすことも、寺の名に傷がつくこともある',
            () {
              if (g.rng.chance(.05)) {
                g.die('寺の門を守って、兵の槍に倒れた', 'senshi');
                return '門の内へなだれ込んだ兵の槍が、胸に届いた。';
              }
              if (g.rng.chance(.5 + l.bu / 300)) {
                l.fame += 2;
                g.j(-3);
                g.setFlag('tm_sohei');
                g.mark('寺領に踏み込んだ兵を、若い僧たちと門を固めて退けた');
                return '棒と薙刀を構えた僧たちを前に、兵は引き揚げた。仏の前で、長く手を合わせた。';
              }
              l.hp -= 15;
              _pay(g, 6);
              return '門は破られ、蔵の米は奪われた。打たれた傷が、長く疼いた。';
            }, via: '武',
          ),
      ], after: next);
    },
  ),

  // ---- 討たれた将の首の供養 ----
  SceneDef(
    'tm_kubi',
    20,
    84,
    (g) => 2,
    (g) => templeLife(g) && g.alive.isNotEmpty,
    (g, next) {
      final l = g.l;
      final a = _hn(g, _nearHouses(g, 1).first);
      g.ask(
        '首の供養',
        '合戦に勝った$aから、討ち取った敵の将の首が寺へ届けられた。手厚く葬れという。その夜、討たれた将の家の者が、首を返してほしいと裏門を叩いた。',
        [
          Choice.h('ひそかに首を返す', '討たれた将の家は救われる。知れれば、勝った家に咎められる', () {
            if (g.rng.chance(.15)) {
              l.fame -= 2;
              l.hp -= 5;
              g.j(-6);
              return '$aの侍に知れ、寺の門前で手ひどく責め立てられた。';
            }
            l.fame += 3;
            l.net += 2;
            g.setFlag('tm_kubi_returned');
            g.mark('討たれた敵の将の首を、ひそかにその家の者へ返した');
            return '首桶を抱いた男は、闇の中で声を殺して泣いた。';
          }),
          Choice.h('言いつけどおり、寺に手厚く葬る', '勝った家の覚えはよい。訪ねてきた者は泣いて帰る', () {
            l.net += 1;
            g.j(-2);
            return '首塚を築き、香を絶やさぬよう寺の者に言いつけた。';
          }),
          Choice.h('勝った家に、返す許しを願い出る', '筋は通る。許されるかは、勝った家の機嫌しだい', () {
            if (g.rng.chance(.4 + l.mi / 250)) {
              l.fame += 4;
              g.setFlag('tm_kubi_plea');
              g.mark('勝った家に願い出て、討たれた将の首をその家へ返した');
              return '「${l.female ? '尼御前' : '御坊'}に免じて」と、首を返す許しが出た。';
            }
            g.j(-3);
            return '願いは聞き入れられなかった。裏門の男には、首塚の場所だけを教えた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 檀家の争い ----
  SceneDef('tm_danka', 25, 84, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    final old = g.rng.pick(kSurnames);
    var rich = g.rng.pick(kSurnames);
    if (rich == old) {
      rich = kSurnames[(kSurnames.indexOf(old) + 1) % kSurnames.length];
    }
    g.ask(
      '檀家の争い',
      '古くからの檀家の$oldの家と、近ごろ銭を蓄えた$richの家が、墓所の場所と法要の席順で揉めている。どちらも、あなたの一言で決めてほしいという。',
      [
        Choice.h('古くからの家を立てる', '筋は通る。寄進の多い家は離れていくかもしれない', () {
          l.net += 1;
          if (g.rng.chance(.5)) {
            _pay(g, 3);
            return '$richの家は、翌年から寄進をよその寺へ回した。';
          }
          return '$richの家はしぶしぶ引き下がった。';
        }),
        Choice.h('寄進の多い家を立てる', '寺の蔵は潤う。古い檀家の恨みを買う', () {
          l.gold += 6;
          _down(g, 2);
          l.fame -= 1;
          return '$oldの家の年寄りは、黙って席を立った。';
        }),
        Choice.h('両家を並べて、合同の法要を開く', '収まれば両家とも寺に残る。こじれれば、両方に恨まれる', () {
          if (g.rng.chance(.4 + l.sei / 300 + l.mi / 300)) {
            l.net += 3;
            l.fame += 2;
            g.setFlag('tm_danka_judge');
            g.mark('檀家どうしの争いを、合同の法要を開いて収めた');
            return '法要のあと、両家の主が並んで酒を酌み交わしていた。';
          }
          _down(g, 2);
          g.j(-4);
          return '法要の席で、両家の者が声を荒らげた。どちらの家も、あなたを恨んだ。';
        }),
      ],
      after: next,
    );
  }),

  // ---- 破戒の誘い ----
  SceneDef('tm_hakai', 20, 70, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    final lure = l.female ? '帰りには、反物と銭の包みも持たせるという。' : '奥の間には、白粉の女たちも控えている。';
    g.ask('般若湯', '裕福な檀家の法要のあと、宴に引き留められた。「般若湯でございます」と、なみなみと酒が注がれる。$lure', [
      Choice.h('戒を守り、席を立つ', '身は清い。檀家の機嫌は損ねる', () {
        _down(g, 1);
        g.j(1);
        g.setFlag('tm_kept_vows');
        return '杯を伏せ、一礼して座を辞した。';
      }),
      Choice.h('一献だけ受けて、早めに帰る', '角は立たない。噂好きの目もある', () {
        if (g.rng.chance(.2)) l.fame -= 1;
        g.j(2);
        return '一献だけ干し、月明かりの道を寺へ帰った。';
      }),
      Choice.h('勧められるまま、夜更けまで過ごす', '心はほどける。知れれば、寺の名に傷がつく', () {
        g.j(6);
        if (l.female) l.gold += 5;
        if (g.rng.chance(.35)) {
          l.fame -= 4;
          _down(g, 2);
          g.setFlag('tm_hakai');
          g.mark('檀家の宴で戒を破り、噂になった');
          return '翌朝には、村じゅうがその夜のことを知っていた。';
        }
        return '夜更けに寺へ戻った。誰にも見られなかった、はずだ。';
      }),
    ], after: next);
  }),

  // ---- 本尊が盗まれる ----
  SceneDef('tm_honzon', 20, 84, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    void found() {
      l.fame += 3;
      g.j(6);
      g.setFlag('tm_honzon_found');
      g.mark('盗まれた本尊を探し出し、寺に迎え戻した');
    }

    g.ask('消えた本尊', '朝のお勤めに本堂へ入ると、須弥壇の上が空だった。夜のうちに、本尊が盗まれたらしい。', [
      Choice.h('市や古道具屋を探し歩く', '見つかるかは運しだい。足が棒になる', () {
        if (g.rng.chance(.3 + l.un / 250)) {
          found();
          return '三つ先の町の古道具屋の奥に、見覚えのある御顔があった。';
        }
        l.hp -= 5;
        g.j(-5);
        return '町から町へ歩いたが、本尊の行方は知れなかった。';
      }),
      Choice.h('村々に触れを回してもらう', '人の目は多いほどよい。顔の広さがものを言う', () {
        if (g.rng.chance(.25 + (l.net > 60 ? 60 : l.net) / 200)) {
          found();
          return '峠の茶屋の婆が、怪しい荷を担いだ男を覚えていた。本尊は、炭俵の中から出てきた。';
        }
        g.j(-4);
        return '噂は広まったが、本尊は戻らなかった。';
      }),
      Choice.h('仏師に、新しい本尊を刻ませる', '寺は元に戻る。銭はかかる。古い像を惜しむ檀家もいる', () {
        if (l.gold < 10) {
          _pay(g, 10);
          g.j(-3);
          return '銭が足りず、小さな仮の像を据えた。';
        }
        l.gold -= 10;
        g.j(-1);
        return '新しい本尊は木の香りがした。古い檀家は、前の御顔を懐かしんだ。';
      }),
    ], after: next);
  }),

  // ---- 旅の僧（実は間者）----
  SceneDef(
    'tm_kanja',
    18,
    84,
    (g) => 2.5,
    (g) => templeLife(g) && g.alive.isNotEmpty,
    (g, next) {
      final l = g.l;
      final a = _hn(g, _nearHouses(g, 1).first);
      g.ask(
        '一夜の宿',
        '日暮れに、旅の僧が一夜の宿を乞うてきた。だが経の節回しはどこかぎこちなく、草鞋の下の足は、武家の者のように鍛えられている。',
        [
          Choice.h('何も聞かずに泊める', '寺は来る者を拒まない。何を探りに来たのかは分からない', () {
            g.j(1);
            return '僧は夜明け前に、礼の言葉を残して発っていった。';
          }),
          Choice.h('$aの役人に、そっと知らせる', '領主には喜ばれる。仲間の恨みを買い、命を狙われるかもしれない', () {
            if (g.rng.chance(.03)) {
              g.die('寺に泊まった間者を役人に知らせた恨みで、夜道で刺された', 'ansatsu');
              return 'ひと月のち、夜の参道で、背後から近づく足音を聞いた。';
            }
            l.fame += 2;
            l.net += 1;
            g.setFlag('tm_told_spy');
            g.mark('寺に泊まった旅の僧が間者と見抜き、$aに知らせた');
            return '夜半、役人たちが寺を囲んだ。男は、隠し持った密書とともに引き立てられた。';
          }),
          Choice.h(
            '経の問答をしかけて、正体を確かめる',
            '見破れば、相手は夜のうちに消える。見誤れば、本物の僧に恥をかかせる',
            () {
              if (g.rng.chance(.5 + l.chi / 300)) {
                l.chi = _c(l.chi + 1);
                return '男は問答に詰まり、夜明けを待たずに姿を消した。';
              }
              g.j(-3);
              return '男は見事に答えた。疑ったことを、手をついて詫びた。';
            },
          ),
        ],
        after: next,
      );
    },
  ),

  // ---- 本山からの上納の取り立て ----
  SceneDef('tm_jono', 25, 84, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    g.ask('本山の使い', '本山から使いの僧が来て、今年の上納を倍にせよと言い渡した。堂の修繕のためだという。', [
      Choice.h('檀家を回って銭を集める', '納めれば本山の覚えはよい。檀家の懐を痛める', () {
        _down(g, 2);
        l.fame += 1;
        g.setFlag('tm_paid_honzan');
        return '頭を下げて回り、どうにか銭をそろえた。';
      }),
      Choice.h('寺の蔵から出す', '檀家には迷惑をかけない。寺の蔵はやせる', () {
        _pay(g, 10);
        g.j(-2);
        return '蔵の銭箱は、底が見えた。';
      }),
      Choice.h('寺の窮状を書き連ね、減免を願い出る', '筆が立てば聞き入れられる。本山に睨まれることもある', () {
        if (g.rng.chance(.35 + l.chi / 250)) {
          g.j(3);
          return '書状は聞き入れられ、上納は据え置きと決まった。';
        }
        l.fame -= 2;
        g.j(-4);
        g.setFlag('tm_honzan_grudge');
        return '本山からは、叱責の書状が届いた。以後、本山の法会に呼ばれることはなかった。';
      }),
    ], after: next);
  }),

  // ---- 年老いた師の跡目 ----
  SceneDef(
    'tm_atome',
    30,
    70,
    (g) => 2,
    (g) => templeLife(g) && !g.hasFlag('abbot'),
    (g, next) {
      final l = g.l;
      final sib = l.female ? '姉弟子' : '兄弟子';
      final temple = l.female ? '尼寺' : '寺';
      void win() {
        g.setFlag('abbot');
        g.setFlag('tm_atome_won');
        l.fame += 5;
        l.gold += 5;
        g.mark('老いた師の$templeの跡目を継いだ');
      }

      g.ask(
        '跡目',
        'あなたが身を寄せる$templeの老いた師が、床に就いた。跡目を、あなたと$sibのどちらにするか、師はまだ口にしない。$sibは、もう檀家の家々に挨拶して回っている。',
        [
          Choice.h('自らも跡目に名乗り出る', '継げば、多くの者を預かる身になる。敗れれば、寺に居づらくなる', () {
            if (g.rng.chance(.3 + (l.fame + l.net) / 300 + l.chi / 400)) {
              win();
              return '檀家の年寄りたちが、あなたの名を推した。師は、静かにうなずいた。';
            }
            _down(g, 1);
            g.j(-6);
            g.setFlag('tm_atome_lost');
            return '跡目は$sibに決まった。廊下ですれ違うたび、気まずい沈黙が流れた。';
          }),
          Choice.h('$sibに譲り、師の看病に専念する', '寺の和は保たれる。師との最後の日々を過ごせる', () {
            l.net += 2;
            g.j(4);
            g.setFlag('tm_atome_yield');
            return '師の枕元で、昔語りを聞いて過ごした。$sibは、黙ってあなたに頭を下げた。';
          }),
          Choice.h('師に、ふさわしい者を選んでほしいと願う', '師の目に任せる。選ばれるかは、日ごろの行いしだい', () {
            if (g.rng.chance(.25 + l.chi / 300)) {
              win();
              return '師は細い声で、あなたの名を呼んだ。';
            }
            g.j(-1);
            return '師は$sibの名を呼んだ。あなたは、それを受け入れた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 戦の孤児 ----
  SceneDef('tm_koji', 20, 80, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    g.ask('焼け出された子ら', '戦で焼けた村から、親を亡くした子らが寺の門前に集まってきた。腹を空かせ、泣く気力もない。', [
      Choice.h('寺で引き取って育てる', '子らは生きられる。寺の蔵と、あなたの手が足りなくなる', () {
        _pay(g, 6);
        l.net += 2;
        l.fame += 2;
        g.j(4);
        final girl = g.rng.chance(.5);
        g.meet('寺で育てる子', g.rng.pick(girl ? kGivenF : kGivenM), 50);
        g.setFlag('tm_orphans');
        g.mark('戦で親を亡くした子らを、寺に引き取って育てた');
        return '寺の庫裏が、にわかに賑やかになった。';
      }),
      Choice.h('縁者を探して、一人ずつ送り届ける', '手間はかかる。引き取り手が見つからない子もいる', () {
        l.hp -= 4;
        l.net += 1;
        g.j(1);
        return '村から村へ子を連れて歩いた。最後の一人だけは、行き先が見つからなかった。';
      }),
      Choice.h('粥を振る舞い、町の商家に奉公の口を探す', '子らは食べていける。奉公先の暮らしは楽ではない', () {
        l.net += 1;
        g.j(1);
        return '子らは、小さな背に荷を負って町へ下っていった。';
      }),
    ], after: next);
  }),

  // ---- 凶作の冬の施粥 ----
  SceneDef('tm_segyo', 20, 84, (g) => 2, templeLife, (g, next) {
    final l = g.l;
    g.ask('門前の列', '凶作の冬。寺の門前に、痩せた人々が列を作っている。蔵には、寺の者が春まで食いつなぐ分の米しかない。', [
      Choice.h('蔵を開けて粥を炊く', '多くの命がつながる。寺の者も飢え、倒れる者も出る', () {
        if (g.rng.chance(.02)) {
          g.die('凶作の冬、施しの粥を分け与え続け、自らは飢えて倒れた', 'ue');
          return '最後の一椀を子に渡した夜、そのまま起き上がれなかった。';
        }
        l.hp -= 8;
        l.fame += 4;
        l.net += 3;
        g.j(3);
        g.setFlag('tm_segyo');
        g.mark('凶作の冬、寺の蔵を開けて粥を施した');
        return '大鍋の粥は、毎朝のうちに空になった。春まで、寺の者も薄い粥をすすった。';
      }),
      Choice.h('富んだ檀家に、米を出してくれと説いて回る', '集まれば、蔵を空けずに済む。断る家のほうが多い', () {
        if (g.rng.chance(.35 + l.mi / 250)) {
          l.fame += 3;
          l.net += 2;
          g.j(3);
          return '三軒目の家の主が、蔵を開けると言ってくれた。';
        }
        _pay(g, 3);
        g.j(-3);
        return 'どの家も門を閉ざした。寺の蔵から、わずかな米を出すほかなかった。';
      }),
      Choice.h('寺の者の分だけを守る', '寺は冬を越せる。門前の列からは目をそらすことになる', () {
        g.j(-8);
        return '門を閉ざした夜、外の気配が、いつまでも耳を離れなかった。';
      }),
    ], after: next);
  }),

  // ---- 寺の鐘を差し出せ ----
  SceneDef(
    'tm_kane',
    25,
    84,
    (g) => 2,
    (g) => templeLife(g) && g.alive.isNotEmpty,
    (g, next) {
      final l = g.l;
      final a = _hn(g, _nearHouses(g, 1).first);
      g.ask('寺の鐘', '$aの侍が来て、寺の梵鐘を陣鐘に使うから差し出せと命じた。檀家が銭を出し合って鋳た、古い鐘だ。', [
        Choice.h('差し出す', '寺は咎められない。檀家は肩を落とす', () {
          _down(g, 2);
          g.j(-3);
          return '鐘楼が空になった。朝夕の鐘の音が、村から消えた。';
        }),
        Choice.h('銭を納めて、鐘は見逃してもらう', '鐘は残る。寺の蔵が痛む', () {
          if (l.gold < 8) {
            _pay(g, 8);
            g.j(-3);
            return '銭が足りず、鐘は荷車で運ばれていった。';
          }
          l.gold -= 8;
          g.j(1);
          return '侍は銭の包みを懐に入れ、鐘を見上げもせずに帰った。';
        }),
        Choice.h('夜のうちに鐘を下ろし、土に埋めて隠す', '鐘は守れるかもしれない。見つかれば、寺ごと咎められる', () {
          if (g.rng.chance(.25)) {
            l.fame -= 2;
            l.hp -= 10;
            g.j(-6);
            return '掘り返した跡を見つけられた。鐘は運び去られ、あなたは打ち据えられた。';
          }
          l.fame += 3;
          g.setFlag('tm_bell_hidden');
          g.mark('陣鐘に取られそうになった寺の鐘を、土に埋めて守った');
          return '「鐘は、とうに盗まれました」と答えた。侍は、首をかしげて帰っていった。';
        }),
      ], after: next);
    },
  ),

  // ---- 戦勝の祈祷を頼まれる ----
  SceneDef(
    'tm_kito',
    20,
    84,
    (g) => 2,
    (g) => templeLife(g) && g.alive.length >= 2,
    (g, next) {
      final l = g.l;
      final near = _nearHouses(g, 2);
      final a = _hn(g, near.first);
      final b = _hn(g, near.length > 1 ? near[1] : near.first);
      g.ask('戦勝の祈祷', '$aから、近く$bと戦をするので、勝ちを祈ってほしいと頼まれた。寄進の銭も添えてある。', [
        Choice.h('祈祷を引き受ける', '寄進は寺を潤す。負ければ、祈りが足りぬと言われる', () {
          l.gold += 8;
          if (g.rng.chance(.5)) {
            l.fame += 2;
            return '勝ち戦だった。$aから、礼の品が届いた。';
          }
          l.fame -= 2;
          return '負け戦だった。祈りが足りぬと、陰口を叩かれた。';
        }),
        Choice.h('討たれる者すべての冥福を祈る、とだけ答える', '仏の道には沿う。頼んだ家は鼻白む', () {
          l.fame += 1;
          g.j(3);
          g.setFlag('tm_prayed_all');
          return '使いの侍は不満げだったが、寄進の銭は置いていった。';
        }),
        Choice.h('寄進を返して断る', '殺生の勝ちは祈らない。頼んだ家とは気まずくなる', () {
          _down(g, 1);
          g.j(1);
          return '銭の包みを、そのまま使いに返した。';
        }),
      ], after: next);
    },
  ),

  // ---- 出家を願う後家（尼）----
  SceneDef('tm_goke', 25, 75, (g) => 2.5, (g) => templeLife(g) && g.l.female, (
    g,
    next,
  ) {
    final l = g.l;
    g.ask('髪を下ろしたい女', '戦で夫を亡くした武家の後家が、髪を下ろしたいと寺を訪ねてきた。まだ若く、幼い子もいるという。', [
      Choice.h('髪を下ろし、弟子に迎える', '女の心の拠り所になる。残された子の行く末は気にかかる', () {
        if (!l.people.containsKey('弟子')) {
          g.meet('弟子', '弟子の${g.rng.pick(kGivenF)}', 55);
        }
        l.net += 1;
        g.j(3);
        g.setFlag('tm_goke_took');
        g.mark('夫を亡くした武家の後家を、弟子に迎えた');
        return '剃刀を当てると、女は目を閉じて、夫の名を一度だけつぶやいた。';
      }),
      Choice.h('子が育つまでは、と思いとどまらせる', '子は母を失わずに済む。女の嘆きは晴れないかもしれない', () {
        l.net += 1;
        g.j(1);
        g.setFlag('tm_goke_home');
        return '女は泣きながらうなずき、子の待つ家へ帰っていった。';
      }),
      Choice.h('寺にしばらく預かり、心が定まるのを待つ', '急がずに済む。寺の暮らしが一人ぶん重くなる', () {
        _pay(g, 2);
        if (g.rng.chance(.5)) {
          return '女は半年のあいだ寺で過ごし、やがて子のもとへ帰っていった。';
        }
        return '半年ののち、女は自ら剃刀を持ってきた。';
      }),
    ], after: next);
  }),
];

/// 仏門の岐路（重点で選んだ年の岐路 10 と、仏門の暮らしの岐路 15）。
List<SceneDef> buildTempleScenes() => [..._focusScenes(), ..._lifeScenes()];
