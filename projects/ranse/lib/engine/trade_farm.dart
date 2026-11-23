import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 商人と百姓の一生の岐路（2026-11-23）。id・旗は `tf_`（商人は `tf_m_`、百姓は `tf_f_`）。
///
/// 侍・女性・僧・縁の場面は厚いのに、町で商う大人と村で田を作る大人の岐路が薄かったので足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kTradeFarmPrev]）。段を踏んだ年は
/// 旗 `tf_at:<筋>:<年>` に残し、次の段は何年か空けてから出す（[kTradeFarmGap]）。
///
/// - 商人の筋: 座（座の寄合 → 座の争い → 座の終わり、座を抜けた人は楽市の店）／米（買い占め → 蔵へ押し寄せる町の者）／
///   店の者（見込みのある小僧 → 暖簾分け → 跡取り）／掛け（掛け取り → 掛けの返り）。
/// - 百姓の筋: 堰（堰の普請 → 鉄火起請）／指出（指出 → 隠し田の露見・年貢の減免）／
///   惣（惣の掟 → 村の裁き → 村請）／種籾（種籾 → 借りた種籾の返済）。
/// - 能力（武・知・政・魅）が高いと出る手や、結果の変わる手がある。年と国で出方が変わるもの
///   （関所は織田の領国では一五七〇年から無い・指出は太閤検地の前だけ・徳政一揆は畿内で一五七〇年まで・楽市は一五四九年から）。

// ---------------------------------------------------------------- 誰に出るか

/// 商いで暮らす人（商いの道に入った人と、町人・商人の家の人）。身分がなく、隠居でも仏門でも野の道でもない。
bool tfMerchant(Game g) {
  final l = g.l;
  if (l.rank != 0 || !g.active || l.ronin) return false;
  if (g.hasFlag('priesthood') || g.hasFlag('way_outlaw')) return false;
  return g.hasFlag('way_merchant') || l.cls.id == 'merchant';
}

/// 村で田畑や浜に生きる人（百姓・漁民）。身分がなく、商い・野・仏門の道に入っていない。
bool tfFarmer(Game g) {
  final l = g.l;
  return l.rank == 0 &&
      g.active &&
      !l.ronin &&
      const ['farmer', 'fisher'].contains(l.cls.id) &&
      !g.hasFlag('priesthood') &&
      !g.hasFlag('way_merchant') &&
      !g.hasFlag('way_outlaw');
}

/// 田を作る百姓（漁民を除く）。
bool _paddy(Game g) => tfFarmer(g) && g.l.cls.id == 'farmer';

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kTradeFarmPrev = <String, List<String>>{
  'tf_m_za_quarrel': ['tf_za_loyal', 'tf_za_voice'],
  'tf_m_za_end': ['tf_za_held', 'tf_za_split', 'tf_za_bowed'],
  'tf_m_rakuichi': ['tf_rakuichi'],
  'tf_m_crowd': ['tf_kome_hoard'],
  'tf_m_noren': ['tf_detchi_raised'],
  'tf_m_muko': ['tf_banto_kept', 'tf_norenwake'],
  'tf_m_kake_return': [
    'tf_kake_pressed',
    'tf_kake_forgiven',
    'tf_kake_pawn',
    'tf_kake_ledger',
  ],
  'tf_f_tekka': ['tf_seki_built', 'tf_seki_pact'],
  'tf_f_kakushida': ['tf_sashi_hidden'],
  'tf_f_genmen': [
    'tf_sashi_honest',
    'tf_sashi_hidden',
    'tf_sashi_so',
    'tf_sashi_clever',
  ],
  'tf_f_kendan': ['tf_so_role'],
  'tf_f_murauke': ['tf_jige_harsh', 'tf_jige_mercy', 'tf_jige_daikan'],
  'tf_f_shakumai': ['tf_seed_borrowed'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kTradeFarmGap = <String, (String, int)>{
  'tf_m_za_quarrel': ('za', 2),
  'tf_m_za_end': ('za', 3),
  'tf_m_rakuichi': ('za', 2),
  'tf_m_crowd': ('kome', 1),
  'tf_m_noren': ('detchi', 6),
  'tf_m_muko': ('detchi', 3),
  'tf_m_kake_return': ('kake', 4),
  'tf_f_tekka': ('seki', 3),
  'tf_f_kakushida': ('sashi', 2),
  'tf_f_genmen': ('sashi', 2),
  'tf_f_kendan': ('so', 2),
  'tf_f_murauke': ('so', 2),
  'tf_f_shakumai': ('seed', 1),
};

/// 商人の岐路の id（テストが使う）。
const kTradeFarmMerchantIds = [
  'tf_m_za',
  'tf_m_za_quarrel',
  'tf_m_za_end',
  'tf_m_rakuichi',
  'tf_m_kome',
  'tf_m_crowd',
  'tf_m_kozo',
  'tf_m_noren',
  'tf_m_muko',
  'tf_m_kake',
  'tf_m_kake_return',
  'tf_m_sekisho',
  'tf_m_ensho',
  'tf_m_yasen',
  'tf_m_tokusei',
];

/// 百姓の岐路の id（テストが使う）。
const kTradeFarmFarmerIds = [
  'tf_f_seki',
  'tf_f_tekka',
  'tf_f_sashi',
  'tf_f_kakushida',
  'tf_f_genmen',
  'tf_f_so',
  'tf_f_kendan',
  'tf_f_murauke',
  'tf_f_tane',
  'tf_f_shakumai',
  'tf_f_randori',
  'tf_f_jinpu',
  'tf_f_tokusei_ikki',
  'tf_f_hikan',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('tf_at:$chain:'));
  g.setFlag('tf_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int tfSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('tf_at:$chain:')) {
      return g.year - int.parse(f.substring('tf_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool tfChainReady(Game g, String id) {
  final prev = kTradeFarmPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kTradeFarmGap[id];
  if (gap == null) return true;
  final s = tfSince(g, gap.$1);
  return s >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _lose(Game g, double rate) => g.l.gold = (g.l.gold * (1 - rate)).floor();

/// 今いる国の近くで、勢いのある家（主家のない人にとっての「近くの大名」）。
String _nearHouse(Game g) {
  final near = nearest(g.alive, (f) => f.name, region: g.l.region, n: 3);
  if (near.isEmpty) return '近くの大名';
  near.sort((a, b) => b.power.compareTo(a.power));
  return '${houseName(g, near.first.name)}家';
}

/// 今いる国の近くの家のうち、主家（あれば）と別の家。攻め寄せてくる側。
String _foeHouse(Game g) {
  final near = nearest(g.alive, (f) => f.name, region: g.l.region, n: 4);
  if (near.length < 2) return '隣国の軍勢';
  return '${houseName(g, g.rng.pick(near.sublist(1)).name)}家の軍勢';
}

/// 織田の領国（一五七〇年からは関所が払われている国）。
const _odaLands = ['尾張', '美濃', '近江', '山城'];

/// 冷える国（凶作の冬が重い）。
const _coldLands = ['甲斐', '信濃', '越後', '陸奥', '出羽', '会津'];

/// 畿内（徳政一揆の起きた国）。
const _kinai = ['山城', '近江', '摂津'];

/// 重み。筋の始まり・ひとつきりの岐路は [_w1]、前の段を踏んだ人だけに出る後段は [_w2]
/// （前の段を踏んだ人生は少ないので、出るときは出やすくする）。
const _w1 = 3.0;
const _w2 = 5.0;

SceneDef _chain(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run, {
  bool Function(Game g)? also,
}) => SceneDef(
  id,
  minAge,
  maxAge,
  (g) => w,
  (g) => who(g) && tfChainReady(g, id) && (also == null || also(g)),
  run,
);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildTradeFarmScenes() => [
  ..._merchantScenes(),
  ..._farmerScenes(),
];

// ---------------------------------------------------------------- 商人

List<SceneDef> _merchantScenes() => [
  // ============================================ 筋: 座
  SceneDef(
    'tf_m_za',
    20,
    60,
    (g) => _w1,
    (g) => tfMerchant(g) && !g.hasFlag('za_rebel'),
    (g, next) {
      final l = g.l;
      final raku = g.year >= 1549;
      g.ask('座の寄合', '店の品を扱う座の寄合に呼ばれた。座の本所の寺が、納める座役の銭を上げると言ってきたという。仲間の顔は、どれも渋い。', [
        Choice.h('黙って座役を納める', '座の守りは続く。儲けは細る', () {
          _lose(g, .1);
          l.net += 2;
          g.setFlag('tf_za_loyal');
          _stamp(g, 'za');
          return '座役を納めた。本所の使いは、当然という顔で帰っていった。';
        }),
        Choice.h('仲間をまとめ、本所に掛け合う', '座の中で重きをなす。本所ににらまれる', () {
          if (g.rng.chance(.4 + l.mi / 250 + l.sei / 400)) {
            l.fame += 4;
            l.net += 3;
            g.setFlag('tf_za_voice');
            _stamp(g, 'za');
            g.mark('座の仲間をまとめ、本所に座役を下げさせた');
            return '仲間の先頭に立って掛け合い、座役を据え置かせた。';
          }
          l.fame += 1;
          _lose(g, .15);
          g.setFlag('tf_za_voice');
          _stamp(g, 'za');
          return '掛け合いはまとまらず、上がった座役を納めることになった。仲間の目には、あなたが頼もしく映ったらしい。';
        }),
        if (raku)
          Choice.h('座を抜け、楽市の城下へ店を移す', '座の決まりからは自由になる。後ろ盾もなくなる', () {
            _lose(g, .2);
            g.setFlag('tf_rakuichi');
            _stamp(g, 'za');
            g.mark('座を抜け、楽市の城下に店を移した');
            return '暖簾を下ろし、誰でも商える楽市の城下に店を移した。';
          })
        else
          Choice.h('座を抜け、振り売りで歩く', '座の決まりからは自由になる。売り場はなくなる', () {
            _lose(g, .2);
            l.hp -= 6;
            return '店をたたみ、天秤棒を担いで町を売り歩くことにした。';
          }),
      ], after: next);
    },
  ),

  _chain('tf_m_za_quarrel', 22, 65, _w2, tfMerchant, (g, next) {
    final l = g.l;
    g.ask('座の争い', 'よその町の商人たちが、座の許しなく同じ品を持ち込み、市で安く売りさばいている。座の仲間は、あなたの顔を見ている。', [
      Choice.h('本所に訴え出る', '筋は通る。裁きには手間と銭がかかる', () {
        _lose(g, .08);
        if (g.rng.chance(.45 + l.chi / 250)) {
          l.fame += 3;
          g.setFlag('tf_za_held');
          _stamp(g, 'za');
          return '本所の下知が出て、よその商人たちは市から締め出された。';
        }
        g.setFlag('tf_za_bowed');
        _stamp(g, 'za');
        return '本所は動かなかった。よその商人たちは、今日も市に荷を広げている。';
      }),
      Choice.h('若い衆を連れ、荷を差し押さえる', '話は早い。荒事は荒事を呼ぶ', () {
        if (g.rng.chance(.4 + l.bu / 200)) {
          l.gold += 6;
          g.setFlag('tf_za_held');
          _stamp(g, 'za');
          return '荷を差し押さえると、よその商人たちは引き上げていった。';
        }
        l.hp -= 15;
        g.setFlag('tf_za_bowed');
        _stamp(g, 'za');
        return '向こうも人を集めていた。殴り合いになり、こちらが追い散らされた。';
      }),
      if (l.mi >= 60 || l.sei >= 60)
        Choice.h('よその商人と膝を詰め、売り場を分ける', '争いは収まる。座の古株には弱腰と見られる', () {
          l.gold += 4;
          l.net += 3;
          g.setFlag('tf_za_split');
          _stamp(g, 'za');
          g.mark('よその町の商人と売り場を分け、座の争いを収めた');
          return '日と場所を分けて商うことで、話がついた。';
        })
      else
        Choice.h('争いには関わらない', '揉め事は避けられる。座の中で軽んじられる', () {
          l.net = l.net >= 2 ? l.net - 2 : 0;
          g.setFlag('tf_za_bowed');
          _stamp(g, 'za');
          return '争いは仲間に任せた。寄合で、あなたに意見を聞く者はいなくなった。';
        }),
    ], after: next);
  }),

  _chain('tf_m_za_end', 25, 75, _w2, tfMerchant, (g, next) {
    final l = g.l;
    final lord = _nearHouse(g);
    g.ask('座の終わり', '$lordが、城下の座を廃し、誰でも商える楽市とする触れを出した。代々の座の決まりは、一夜で反故になった。', [
      Choice.h('新しい商いの仕方に乗り換える', '先に動けば客をつかめる。古い仲間とは疎遠になる', () {
        if (g.rng.chance(.4 + l.sei / 200)) {
          l.gold += 15;
          g.setFlag('tf_za_adapted');
          g.mark('座が廃されたのち、いち早く新しい商いに乗り換えた');
          return '座の決まりに縛られず、売れる品を売れるだけ売った。';
        }
        _lose(g, .15);
        return '慣れない商いで、思わぬ損を出した。';
      }),
      Choice.h('本所と組み、座を残すよう願い出る', '昔からの暮らしを守ろうとする。時の流れには逆らいにくい', () {
        _lose(g, .1);
        if (g.rng.chance(.15 + l.chi / 400)) {
          l.fame += 4;
          g.setFlag('tf_za_kept');
          return '願いは一部だけ聞き入れられ、店の品には座の扱いが残った。';
        }
        g.j(-4);
        return '願いは聞き入れられなかった。差し出した礼銭も戻らない。';
      }),
      Choice.h('店をたたみ、座の残る国へ移る', '慣れた商いは続けられる。一から客を作り直す', () {
        _lose(g, .3);
        g.setFlag('tf_za_moved');
        g.mark('座が廃された町を去り、よその国で店を開き直した');
        return '荷をまとめ、座の残る国へ移った。';
      }),
    ], after: next);
  }, also: (g) => g.year >= 1568),

  _chain('tf_m_rakuichi', 22, 70, _w2, tfMerchant, (g, next) {
    final l = g.l;
    g.ask('楽市の店', '楽市の城下に構えた店の前に、ある朝、荒くれ者が並んだ。古い座の商人に雇われたらしい。「よそ者が、でかい顔をするな」', [
      Choice.h('市の奉行に訴える', '楽市の掟は押し買いや狼藉を禁じている。役所は腰が重い', () {
        if (g.rng.chance(.6)) {
          l.fame += 3;
          g.setFlag('tf_rakuichi_held');
          g.mark('楽市の掟を盾に、座の商人の嫌がらせを退けた');
          return '奉行所の役人が来て、荒くれ者たちは追い払われた。楽市の掟は生きていた。';
        }
        _lose(g, .1);
        return '訴えは受け付けられたが、何の沙汰もなかった。';
      }),
      Choice.h('用心棒を雇って店を守る', '店は守れる。銭が出ていく', () {
        _lose(g, .12);
        g.setFlag('tf_rakuichi_held');
        return '用心棒が睨みをきかせ、荒くれ者たちは来なくなった。';
      }),
      Choice.h('古い座の商人に礼銭を払う', '揉め事は消える。足元を見られ続ける', () {
        _lose(g, .15);
        g.j(-3);
        return '礼銭を包んだ。荒くれ者たちは、それきり姿を見せなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 米
  SceneDef(
    'tf_m_kome',
    22,
    70,
    (g) => _w1,
    (g) => tfMerchant(g) && g.l.gold >= 20,
    (g, next) {
      final l = g.l;
      final foe = _foeHouse(g);
      g.ask('米の値', '$foeが動くという噂で、町の米の値が日に日に上がっている。蔵には、まだ買い入れる余裕がある。', [
        Choice.h('米を買えるだけ買い占める', '当たれば蔵が建つ。外れれば米が腐る。町の恨みも買う', () {
          g.setFlag('tf_kome_hoard');
          _stamp(g, 'kome');
          if (g.rng.chance(.35 + l.sei / 200)) {
            l.gold += 20 + l.sei ~/ 4;
            l.fame -= 3;
            g.mark('戦の噂に乗じて米を買い占め、大きく儲けた');
            return '値の頂で売り抜けた。蔵の銭は倍になった。町の者の目は冷たい。';
          }
          _lose(g, .35);
          return '噂は外れ、米の値は崩れた。蔵の米を、捨て値で手放した。';
        }),
        Choice.h('町の者には、いつもの値で売り続ける', '儲けは逃す。町の者は覚えている', () {
          l.fame += 5;
          l.net += 3;
          g.j(3);
          g.setFlag('tf_kome_fair');
          g.mark('米の値が上がった年も、町の者にいつもの値で米を売った');
          return '店の前に長い列ができた。いつもの値で売る米屋は、町にここだけだった。';
        }),
        Choice.h('米には手を出さない', '危ない橋は渡らない', () => '米の値が上がり下がりするのを、帳場から眺めていた。'),
      ], after: next);
    },
  ),

  _chain('tf_m_crowd', 22, 80, _w2, tfMerchant, (g, next) {
    final l = g.l;
    g.ask('蔵へ押し寄せる町の者', '凶作の冬。米を抱え込んだ商人がいるという噂を聞きつけ、町の者が手に手に棒を持って店の前に集まってきた。「蔵を開けろ」', [
      Choice.h('蔵を開け、安い値で売る', '大損になる。町との縁はつながる', () {
        _lose(g, .3);
        l.fame += 5;
        g.setFlag('tf_kowashi_opened');
        g.mark('凶作の冬、押し寄せた町の者に蔵を開けて米を売った');
        return '蔵を開けた。人々は米を抱え、頭を下げて帰っていった。';
      }),
      Choice.h('戸を閉ざし、用心棒に守らせる', '蔵は守れるかもしれない。破られれば何も残らない', () {
        if (g.rng.chance(.45 + l.bu / 300)) {
          l.fame -= 4;
          return '夜通し戸を押さえ続けた。夜明け、人々は散っていった。';
        }
        _lose(g, .6);
        l.hp -= 12;
        g.setFlag('tf_kowashi_broken');
        g.mark('凶作の冬、町の者に店と蔵を打ち破られた');
        return '戸が破られ、蔵の米は一粒残らず運び出された。';
      }),
      Choice.h('領主の兵を呼ぶ', '店は守られる。町の者の恨みは深く残る', () {
        if (g.hasFlag('goyo') || g.rng.chance(.5 + l.mi / 300)) {
          l.fame -= 6;
          l.net = l.net >= 4 ? l.net - 4 : 0;
          g.setFlag('tf_kowashi_soldiers');
          return '兵が来て、人々は追い散らされた。町で、あなたに挨拶する者はいなくなった。';
        }
        _lose(g, .5);
        return '兵は間に合わなかった。蔵は空になった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 店の者
  SceneDef('tf_m_kozo', 22, 55, (g) => _w1, (g) => tfMerchant(g) && !g.l.people.containsKey('手代'), (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('見込みのある小僧', '奉公に来た小僧の$nは、教えもしないのに客の顔と好みを覚え、釣り銭を間違えたことがない。', [
      Choice.h('帳面と算盤を仕込む', '店の柱に育つかもしれない。手間はかかる', () {
        g.meet('手代', n, 55);
        g.setFlag('tf_kozo_raised');
        g.setFlag('tf_detchi_raised');
        _stamp(g, 'detchi');
        return '夜ごと、$nに帳面の付け方を教えた。飲み込みは早い。';
      }),
      if (l.sei >= 60)
        Choice.h('取引先へ使いに出し、目を養わせる', '人を見る目が育つ。店の内のことは手薄になる', () {
          g.meet('手代', n, 65);
          l.net += 2;
          g.setFlag('tf_detchi_raised');
          _stamp(g, 'detchi');
          return '$nを方々の店へ使いに出した。帰るたびに、よその商いの話を聞かせてくれる。';
        }),
      Choice.h('下働きのまま使う', '店の中は今のまま。小僧の目の光は消える', () {
        return '$nには、水汲みと掃除を続けさせた。';
      }),
    ], after: next);
  }),

  _chain('tf_m_noren', 30, 75, _w2, tfMerchant, (g, next) {
    final l = g.l;
    final p = l.people['手代'];
    final n = p?.name ?? '手代';
    g.ask('暖簾分け', '手代の$nが、帳場の前に手をついた。「いつか、己の暖簾を掲げとうございます」。店に来て、もう長い。', [
      Choice.h('暖簾を分け、店を持たせる', '店の名は広がる。手放す銭は小さくない', () {
        _lose(g, .2);
        l.fame += 5;
        l.net += 3;
        g.setFlag('tf_norenwake');
        _stamp(g, 'detchi');
        if (p != null) p.bond = _c(p.bond + 20);
        g.mark('手代の$nに暖簾を分け、店を持たせた');
        return '$nは、同じ屋号の暖簾を掲げた。開いた日、あなたが最初の客になった。';
      }),
      Choice.h('番頭として店に留める', '店は確かなものになる。手代の夢は先へ延びる', () {
        g.setFlag('tf_banto_kept');
        _stamp(g, 'detchi');
        l.gold += 6;
        if (p != null) p.bond = _c(p.bond - 5);
        return '$nを番頭に据えた。$nは黙って頭を下げた。';
      }),
      Choice.h('申し出をはねつける', '店の者は思い上がらない。人は離れていく', () {
        l.people.remove('手代');
        g.setFlag('tf_banto_left');
        return '$nは、ほどなく暇を取り、よその店に移っていった。';
      }),
    ], after: next);
  }, also: (g) => g.l.people.containsKey('手代')),

  _chain('tf_m_muko', 38, 70, _w2, tfMerchant, (g, next) {
    final l = g.l;
    final banto = g.hasFlag('tf_banto_kept') ? l.people['手代']?.name : null;
    g.ask('跡取り', '親類が集まり、店の跡のことを言い出した。我が子に継がせるか、器量のある者を婿に迎えて継がせるか。', [
      Choice.h('我が子に継がせると決める', '血筋で家は続く。子の器量しだい', () {
        g.setFlag('tf_heir_own');
        g.j(3);
        return '跡は我が子に、と言い切った。親類は黙った。';
      }),
      Choice.h(
        banto != null ? '番頭の$bantoを婿に迎える' : 'よその店の次男を婿に迎える',
        '店を知る者が継ぐ。我が子の立場は細る',
        () {
          g.setFlag('tf_heir_muko');
          l.net += 2;
          g.mark(banto != null ? '番頭の$bantoを婿に迎え、店の跡を託した' : 'よその店から婿を迎え、店の跡を託した');
          return banto != null ? '$bantoは、婿として店の跡を継ぐことになった。' : '縁を結び、婿を迎えることになった。';
        },
      ),
      Choice.h('今は決めずにおく', '揉め事は先送りになる', () => '跡のことは、もう少し考えると言って座を立った。'),
    ], after: next);
  }, also: (g) => g.l.kids > 0 && g.l.hasKidAged(g.year, 15, 30)),

  // ============================================ 筋: 掛け
  SceneDef('tf_m_kake', 20, 70, (g) => _w1, tfMerchant, (g, next) {
    final l = g.l;
    g.ask('掛け取り', '暮れの掛け取りに回ると、家中の侍の屋敷では、去年の分もまだ払えぬと言われた。「武士に二言はない。いずれ払う」', [
      Choice.h('屋敷に日参して払わせる', '銭は戻る。侍の面子はつぶれる', () {
        l.gold += 8;
        g.setFlag('tf_kake_pressed');
        _stamp(g, 'kake');
        return '七日通い続けて、ようやく払わせた。侍は目を合わせなかった。';
      }),
      Choice.h('払える時でよいと告げる', '銭は戻らないかもしれない。恩は残る', () {
        g.setFlag('tf_kake_forgiven');
        _stamp(g, 'kake');
        l.net += 2;
        return '「払える時で結構でございます」。侍は、深く頭を下げた。';
      }),
      Choice.h('家伝の具足を形に預かる', '取りはぐれはない。侍の恨みも残る', () {
        g.setFlag('tf_kake_pawn');
        _stamp(g, 'kake');
        return '古びた具足を、掛けの形に預かった。';
      }),
      if (l.sei >= 60)
        Choice.h('主家の勘定方に帳面を見せて掛け合う', '帳面に隙がなければ、筋で取れる', () {
          l.gold += 10;
          l.fame += 2;
          g.setFlag('tf_kake_ledger');
          _stamp(g, 'kake');
          return '一文の狂いもない帳面に、勘定方はうなった。掛けは、主家の蔵から払われた。';
        }),
    ], after: next);
  }),

  _chain('tf_m_kake_return', 25, 80, _w2, tfMerchant, (g, next) {
    final l = g.l;
    if (g.hasFlag('tf_kake_forgiven')) {
      g.ask('掛けの返り', '掛けを待ってやったあの侍が、立派な身なりで店に来た。手柄を立てて、出世したという。「あの暮れの恩は忘れぬ」', [
        Choice.h('屋敷の御用を引き受ける', '商いが太くなる。武家との縁は重い', () {
          l.gold += 15;
          l.fame += 4;
          g.setFlag('tf_kake_repaid');
          g.mark('掛けを待ってやった侍が出世し、屋敷の御用を任された');
          return '屋敷の品は、すべてこの店から納めることになった。';
        }),
        Choice.h('掛けの分だけ受け取る', '貸し借りはここで終わる', () {
          l.gold += 6;
          return '溜まっていた掛けを受け取った。侍は利までつけて払った。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('tf_kake_pawn')) {
      g.ask('掛けの返り', '具足を形に預けたあの侍が、血相を変えて来た。戦が近い。具足がなければ出陣できぬという。だが、掛けはまだ払えない。', [
        Choice.h('掛けは後でよいと、具足を返す', '銭は遠のく。侍は命拾いする', () {
          l.net += 3;
          g.setFlag('tf_kake_repaid');
          return '具足を返した。侍は、それを抱えて走っていった。';
        }),
        Choice.h('掛けを払うまでは返さない', '筋は通る。侍は戦に出られない', () {
          l.fame -= 3;
          g.j(-2);
          return '侍は唇を噛んで帰った。のちに、具足を借りて出陣したと聞いた。';
        }),
      ], after: next);
      return;
    }
    g.ask('掛けの返り', '掛けを厳しく取り立てたあの侍が、町の奉行になった。近ごろ、店に運び込む荷にばかり難癖がつく。', [
      Choice.h('詫びの品を届ける', '荷は通るようになる。足元を見られる', () {
        _lose(g, .12);
        return '詫びの品を届けると、荷改めはぱたりと止んだ。';
      }),
      Choice.h('筋を通し、取り合わない', '曲げずに済む。商いは細る', () {
        if (g.rng.chance(.5 + l.net / 300)) {
          l.fame += 2;
          return '町の年寄りたちが間に立ち、難癖はやんだ。';
        }
        _lose(g, .2);
        return '荷は止められ続け、客がよそへ流れた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり
  SceneDef(
    'tf_m_sekisho',
    18,
    70,
    (g) => _w1,
    (g) =>
        tfMerchant(g) &&
        !(g.year >= 1570 && _odaLands.contains(g.l.region)),
    (g, next) {
      final l = g.l;
      g.ask('関所', '荷を運ぶ道に、寺社や国人の関所がいくつも並んでいる。どの関でも関銭を取られ、着く頃には儲けが半ばも残らない。', [
        Choice.h('関ごとに関銭を払う', '荷は確かに届く。儲けは削られる', () {
          l.gold += 3;
          return '関を通るたびに銭を払い、荷を届けた。';
        }),
        Choice.h('関を避け、山道を行く', '関銭は浮く。山道には山賊が出る', () {
          if (g.rng.chance(.05 - l.bu / 3000)) {
            g.die('関所を避けた山道で、山賊に討たれた', 'senshi');
            return '山道で、山賊に囲まれた。';
          }
          if (g.rng.chance(.6 + l.bu / 400)) {
            l.gold += 12;
            return '獣道を抜け、関銭を払わずに荷を届けた。';
          }
          _lose(g, .2);
          l.hp -= 12;
          return '山賊に荷を奪われ、命からがら逃げのびた。';
        }),
        Choice.h('関守に袖の下を握らせる', '安く通れることもある。足元を見られることもある', () {
          if (g.rng.chance(.4 + l.mi / 200)) {
            l.gold += 8;
            return '関守は荷を見もせずに通した。';
          }
          _lose(g, .1);
          return '関守は銭だけ取り、関銭も取った。';
        }),
        if (l.chi >= 60)
          Choice.h('寺社に願い、関を通る過書をもらう', '書状がものを言う。寄進の銭は要る', () {
            l.gold += 10;
            l.net += 2;
            g.setFlag('tf_kasho');
            g.mark('寺社の過書を得て、関所を関銭なしで通った');
            return '寺社の過書を見せると、関守は黙って道を開けた。';
          }),
      ], after: next);
    },
  ),

  SceneDef(
    'tf_m_ensho',
    22,
    70,
    (g) => _w1,
    (g) => tfMerchant(g) && g.l.gold >= 15,
    (g, next) {
      final l = g.l;
      final lord = _nearHouse(g);
      g.ask('煙硝', '南蛮の船が運んでくる煙硝を、分けてもらえる話が来た。鉄砲を抱える家はどこも、喉から手が出るほど欲しがっている。', [
        Choice.h('$lordにだけ納める', '儲けはほどほど。家の覚えはめでたい', () {
          l.gold += 10;
          l.fame += 4;
          g.setFlag('tf_ensho_lord');
          return '$lordの蔵に煙硝を納めた。礼状が届いた。';
        }),
        Choice.h('敵味方を問わず、高く売る', '蔵が建つほど儲かる。露見すれば命はない', () {
          if (g.rng.chance(.05)) {
            g.die('敵方にも煙硝を売っていたことが露見し、斬られた', 'seppuku');
            return '敵方に煙硝を売ったことが露見した。';
          }
          l.gold += 30;
          g.setFlag('tf_ensho_both');
          g.mark('煙硝を敵味方の別なく売りさばいた');
          return '煙硝は、どの家にも言い値で売れた。';
        }),
        if (l.chi >= 60)
          Choice.h('混ぜ物を見抜き、上物だけを仕入れる', '目利きが生きる。手間がかかる', () {
            l.gold += 18;
            l.fame += 3;
            g.setFlag('tf_ensho_eye');
            return '砂の混じった煙硝を突き返し、上物だけを買った。あの店の煙硝なら間違いない、と言われるようになった。';
          }),
        Choice.h('戦の道具には手を出さない', '儲けは逃す。寝覚めは悪くない', () => '煙硝の話は断った。'),
      ], after: next);
    },
    ageOk: (g, a) => g.l.startYear + a >= 1555,
  ),

  SceneDef(
    'tf_m_yasen',
    22,
    75,
    (g) => _w1,
    (g) => tfMerchant(g) && g.l.region != '摂津' && g.l.gold >= 10,
    (g, next) {
      final l = g.l;
      final foe = _foeHouse(g);
      g.ask('矢銭', '$foeが町の近くに陣を張り、矢銭を出せ、出さねば町を焼くと言ってきた。町の年寄りたちが集まり、店ごとの割り当てを決めている。', [
        Choice.h('割り当てどおり出す', '町は焼かれずに済む。蔵は軽くなる', () {
          _lose(g, .25);
          return '矢銭を納めた。軍勢は、町を素通りしていった。';
        }),
        Choice.h('町の者と組み、矢銭を断る', '町の意地は通る。焼かれれば何も残らない', () {
          if (g.rng.chance(.45)) {
            l.fame += 6;
            g.setFlag('tf_yasen_refused');
            g.mark('町の者と組み、軍勢の矢銭を断った');
            return '町の者は堀を浚い、木戸を固めた。軍勢は、町を攻めずに去った。';
          }
          _lose(g, .55);
          l.hp -= 10;
          g.j(-8);
          return '町に火が放たれた。店は焼け落ちた。';
        }),
        if (l.mi >= 60 || l.sei >= 60)
          Choice.h('使いに立ち、額を値切る', '口が立てば町を救える。しくじれば使いが危ない', () {
            if (g.rng.chance(.6 + (l.mi + l.sei) / 600)) {
              _lose(g, .1);
              l.fame += 8;
              l.net += 3;
              g.setFlag('tf_yasen_bargain');
              g.mark('軍勢の陣へ使いに立ち、町の矢銭を値切った');
              return '陣中で大将と向き合い、矢銭を半ばに負けさせた。町の者は、あなたを迎えに出た。';
            }
            _lose(g, .3);
            l.hp -= 8;
            return '大将の機嫌を損ね、矢銭はかえって増えた。';
          }),
      ], after: next);
    },
  ),

  SceneDef(
    'tf_m_tokusei',
    25,
    75,
    (g) => _w1,
    (g) => tfMerchant(g) && g.l.gold >= 40,
    (g, next) {
      final l = g.l;
      final lord = _nearHouse(g);
      g.ask('徳政', '$lordが徳政の触れを出した。貸した銭の証文は、すべて反故になるという。あなたの手元には、町の者や侍に貸した証文の束がある。', [
        Choice.h('証文を破り捨てる', '貸した銭は戻らない。借りた者は救われる', () {
          _lose(g, .3);
          l.net += 4;
          l.fame += 3;
          g.setFlag('tf_tokusei_tore');
          g.mark('徳政の触れに従い、貸した銭の証文を破り捨てた');
          return '証文を火にくべた。借りていた者たちが、店の前で手を合わせた。';
        }),
        Choice.h('分一の銭を納め、証文を生かしてもらう', '貸した銭は守れる。借りた者の恨みを買う', () {
          _lose(g, .12);
          l.net = l.net >= 3 ? l.net - 3 : 0;
          g.setFlag('tf_tokusei_buni');
          return '貸した銭の一部を納め、証文は徳政から除かれた。';
        }),
        Choice.h('借り手と内々に話をつける', '半ばは戻るかもしれない。手間がかかる', () {
          if (g.rng.chance(.4 + l.mi / 200)) {
            _lose(g, .1);
            l.net += 2;
            return '借り手の多くが、少しずつでも返すと約束した。';
          }
          _lose(g, .25);
          return '借り手たちは、触れを盾に首を振った。';
        }),
      ], after: next);
    },
  ),
];

// ---------------------------------------------------------------- 百姓

List<SceneDef> _farmerScenes() => [
  // ============================================ 筋: 堰
  SceneDef('tf_f_seki', 20, 65, (g) => _w1, _paddy, (g, next) {
    final l = g.l;
    g.ask('堰の普請', '村の田に水を引くため、川上に堰を築こうという話が持ち上がった。だが川下の村は、水が来なくなると騒いでいる。', [
      Choice.h('構わず堰を築く', '村の田は潤う。川下の村の恨みを買う', () {
        l.gold += 5;
        l.hp -= 8;
        g.setFlag('tf_seki_built');
        _stamp(g, 'seki');
        return '村じゅうで石を運び、堰を築いた。川下の村の者が、遠くから睨んでいた。';
      }),
      Choice.h('川下の村と、水の分け方を証文にする', '水は少しずつ。争いの種は減る', () {
        l.net += 3;
        g.setFlag('tf_seki_pact');
        _stamp(g, 'seki');
        return '日を分けて堰を開ける約束を、証文に書いて取り交わした。';
      }),
      if (l.chi >= 60)
        Choice.h('落とし口を工夫し、両方の田に水が回るようにする', '知恵が要る。うまくいけば誰も損をしない', () {
          l.fame += 5;
          l.net += 3;
          g.setFlag('tf_seki_pact');
          _stamp(g, 'seki');
          g.mark('堰の落とし口を工夫し、川上と川下の両方の田を潤した');
          return '堰の脇に落とし口を切り、川下へも水が流れるようにした。川下の村の長が、礼を言いに来た。';
        }),
      Choice.h('堰はあきらめる', '揉め事は起きない。日照りの年はつらい', () {
        g.j(-2);
        return '堰の話は立ち消えになった。';
      }),
    ], after: next);
  }),

  _chain('tf_f_tekka', 22, 70, _w2, _paddy, (g, next) {
    final l = g.l;
    final paper = g.hasFlag('tf_seki_pact');
    g.ask('鉄火起請', '日照りの夏、川下の村と水の取り分で争いがこじれ、ついに領主の裁きとなった。領主は鉄火起請で決めるという。真っ赤に焼けた鉄を握り、神前の棚まで運べた側が勝ちだ。', [
      Choice.h('自ら焼けた鉄を握る', '運び切れば村の誉れ。落とせば手も村も失う', () {
        if (g.rng.chance(.35 + l.bu / 250 + l.hp / 600)) {
          l.fame += 10;
          l.net += 5;
          l.hp -= 15;
          g.setFlag('tf_tekka_held');
          g.mark('鉄火起請で焼けた鉄を握り、村の水を勝ち取った');
          return '焼けた鉄を握りしめ、棚まで運び切った。掌の焼け跡は、一生消えなかった。';
        }
        l.hp -= 30;
        g.j(-12);
        g.setFlag('tf_tekka_failed');
        return '三歩目で、鉄が手から落ちた。水は川下の村のものになった。';
      }),
      Choice.h('村の若い者に任せる', '自分の手は焼けない。誰かの手が焼ける', () {
        if (g.rng.chance(.45)) {
          l.gold += 4;
          return '若い者が鉄を運び切った。村は水を守った。';
        }
        g.j(-6);
        return '若い者は鉄を落とした。水は川下の村に取られた。';
      }),
      if (paper || l.chi >= 60)
        Choice.h(paper ? '取り交わした証文を差し出す' : '古い証文を探し出して差し出す', '筋の通った書き物があれば、起請はいらない', () {
          if (g.rng.chance(paper ? .7 : .5 + l.chi / 400)) {
            l.fame += 6;
            g.setFlag('tf_tekka_paper');
            g.mark('水争いの裁きに証文を差し出し、鉄火起請をやめさせた');
            return '領主の役人は証文を読み、起請はやめとなった。水は証文どおりに分けられた。';
          }
          g.j(-4);
          return '証文は取り上げられず、起請の日取りが決まった。若い者が鉄を握り、どうにか運び切った。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 指出
  SceneDef(
    'tf_f_sashi',
    20,
    70,
    (g) => _w1,
    _paddy,
    (g, next) {
      final l = g.l;
      final lord = _nearHouse(g);
      g.ask('指出', '$lordが、村ごとに田畑の広さと取れ高を書き出して差し出せと命じてきた。書いたとおりに、年貢が決まる。', [
        Choice.h('ありのままに書き出す', '後ろ暗いところはない。年貢は重くなる', () {
          _lose(g, .1);
          g.setFlag('tf_sashi_honest');
          _stamp(g, 'sashi');
          return '田の一枚一枚を、ありのままに書き出した。';
        }),
        Choice.h('山あいの隠し田は伏せておく', '年貢は軽くなる。見つかれば咎めを受ける', () {
          l.gold += 6;
          g.setFlag('tf_sashi_hidden');
          _stamp(g, 'sashi');
          return '山あいの小さな田のことは、書かずにおいた。';
        }),
        Choice.h('惣の寄合に諮り、村で口をそろえる', '村は一つになる。一人では決められない', () {
          l.net += 3;
          l.gold += 2;
          g.setFlag('tf_sashi_so');
          _stamp(g, 'sashi');
          return '寄合で話し合い、村じゅうで同じ書き出しを差し出した。';
        }),
        if (l.sei >= 60)
          Choice.h('田の良し悪しを細かく書き分ける', '帳面の才が生きる。嘘はつかずに年貢を軽くできる', () {
            l.gold += 5;
            l.fame += 2;
            g.setFlag('tf_sashi_clever');
            _stamp(g, 'sashi');
            return '日の当たらぬ田、水の悪い田を一枚ずつ書き分けた。役人も文句のつけようがなかった。';
          }),
      ], after: next);
    },
    ageOk: (g, a) => g.l.startYear + a < 1582,
  ),

  _chain('tf_f_kakushida', 22, 75, _w2, _paddy, (g, next) {
    final l = g.l;
    g.ask('隠し田', '代官の手下が、山あいの隠し田を見つけた。「お上を欺いた罪は重いぞ」', [
      Choice.h('罪を認めて詫びる', '咎めは受ける。命までは取られまい', () {
        _lose(g, .3);
        l.fame -= 3;
        g.setFlag('tf_kakushi_confessed');
        return '地に額をつけて詫びた。過料を払い、隠し田は帳面に載った。';
      }),
      Choice.h('代官の手下に銭を握らせる', 'うまくいけば何もなかったことになる。しくじれば罪が重くなる', () {
        if (g.rng.chance(.45 + l.mi / 250)) {
          _lose(g, .15);
          return '手下は銭を懐に入れ、何も見なかったと言った。';
        }
        if (g.rng.chance(.08)) {
          g.die('隠し田を見逃させようとして露見し、処罰された', 'seppuku');
          return '手下は銭を代官に差し出した。';
        }
        _lose(g, .45);
        l.hp -= 10;
        return '銭は突き返され、重い過料を言い渡された。';
      }),
      Choice.h('一家で村を逃げる', '咎めは逃れる。田も家も捨てる', () {
        _lose(g, .6);
        g.j(-12);
        l.net = 0;
        g.setFlag('tf_chosan');
        g.mark('隠し田が露見し、一家で村を捨てて逃げた');
        return '夜のうちに荷をまとめ、隣国の村へ逃げた。';
      }),
    ], after: next);
  }),

  _chain('tf_f_genmen', 22, 75, _w2, _paddy, (g, next) {
    final l = g.l;
    g.ask('年貢の減免', '日照りで稲が実らなかった。だが年貢は例年どおり納めよとの達しだ。寄合では、減免を願い出ようという声が上がっている。', [
      Choice.h('村の総代として願い出る', '聞き入れられれば村が救われる。お上の怒りを買うこともある', () {
        if (g.rng.chance(.4 + l.chi / 250 + l.mi / 400)) {
          l.gold += 5;
          l.fame += 8;
          g.setFlag('tf_genmen_won');
          g.mark('村の総代として年貢の減免を願い出て、聞き入れられた');
          return '願いは聞き入れられ、今年の年貢は軽くなった。';
        }
        if (g.rng.chance(.06)) {
          g.die('年貢の減免を強く願い出て、咎めを受けた', 'seppuku');
          return '願いは「お上に盾つく」とされた。';
        }
        g.j(-8);
        l.hp -= 8;
        return '願いは退けられ、厳しく叱りつけられた。';
      }),
      Choice.h('村じゅうで山へ逃れて訴える', '田を空けて訴えれば、お上も折れることがある。長引けば飢える', () {
        if (g.rng.chance(.45 + l.net / 300)) {
          l.net += 4;
          g.setFlag('tf_chosan_won');
          g.mark('村じゅうで山へ逃れて訴え、年貢を軽くさせた');
          return '田を空けて十日、代官の使いが来て年貢を半ばに減らすと告げた。';
        }
        l.hp -= 12;
        _lose(g, .3);
        return '山の暮らしは苦しく、村の者は一人二人と戻っていった。年貢は減らなかった。';
      }),
      Choice.h('黙って納める', '揉め事は起きない。冬が苦しくなる', () {
        _lose(g, .3);
        l.hp -= 8;
        return '蔵の米をかき集めて納めた。冬は粥ばかりになった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 惣
  SceneDef(
    'tf_f_so',
    25,
    70,
    (g) => _w1,
    tfFarmer,
    (g, next) {
      final l = g.l;
      g.ask('惣の掟', '村の惣で、掟を定め直すことになった。年寄りたちが、あなたにも沙汰人の一人に加われと言う。', [
        Choice.h('沙汰人を引き受ける', '村をまとめる側になる。揉め事を背負う', () {
          l.net += 3;
          l.fame += 3;
          g.setFlag('tf_so_role');
          _stamp(g, 'so');
          return '寄合の上座に、あなたの席ができた。';
        }),
        Choice.h('掟に一条を足すよう申し出る', '村の守りが一つ増える。煙たがる者もいる', () {
          l.net += 1;
          g.setFlag('tf_so_rule');
          return '「よそ者を、惣の許しなく泊めてはならぬ」。あなたの申し出た一条が、掟に加わった。';
        }),
        Choice.h('年寄りに任せる', '気楽でいられる', () => '掟のことは、年寄りたちに任せた。'),
      ], after: next);
    },
  ),

  _chain('tf_f_kendan', 25, 75, _w2, tfFarmer, (g, next) {
    final l = g.l;
    g.ask('村の裁き', '村の蔵から米を盗んだ者が捕まった。隣の家の若い男だ。惣の掟では、盗みは村で裁く。沙汰人のあなたの言葉を、皆が待っている。', [
      Choice.h('掟どおり、家を焼き村から追う', '村の掟は守られる。若い男の家族は路頭に迷う', () {
        l.fame += 3;
        l.net = l.net >= 2 ? l.net - 2 : 0;
        g.j(-4);
        g.setFlag('tf_jige_harsh');
        _stamp(g, 'so');
        return '掟は掟だった。若い男とその家族は、村を出ていった。';
      }),
      Choice.h('盗んだ米を働いて返させ、村に置く', '若い男は救われる。掟を軽く見る者も出る', () {
        l.net += 3;
        g.j(4);
        g.setFlag('tf_jige_mercy');
        _stamp(g, 'so');
        return '若い男は、二度の秋を他人の田で働いて米を返した。';
      }),
      Choice.h('代官に引き渡す', '村の手は汚れない。代官が村に口を出すようになる', () {
        g.setFlag('tf_jige_daikan');
        _stamp(g, 'so');
        return '若い男は代官所へ引かれていった。それから、代官の手下がしばしば村をのぞくようになった。';
      }),
    ], after: next);
  }),

  _chain('tf_f_murauke', 28, 70, _w2, tfFarmer, (g, next) {
    final l = g.l;
    g.ask('村請', '領主の代官が、村の年貢をまとめて請け負う者を立てよと言ってきた。寄合は、あなたの名を挙げた。', [
      Choice.h('請け負う', '村の顔になる。足りなければ自分の蔵から埋める', () {
        l.fame += 6;
        l.net += 3;
        g.setFlag('tf_murauke');
        g.mark('村の年貢を請け負う役に就いた');
        return '代官の前で請文に名を書いた。';
      }),
      if (l.sei >= 60)
        Choice.h('請け負い、家ごとの割り付けを決め直す', '帳面の才が生きる。損をする家からは恨まれる', () {
          l.fame += 8;
          l.net += 2;
          g.setFlag('tf_murauke');
          g.setFlag('tf_murauke_fair');
          g.mark('村の年貢を請け負い、家ごとの割り付けを田の出来で決め直した');
          return '田の出来を一枚ずつ見て回り、年貢の割り付けを決め直した。苦しい家の顔が明るくなった。';
        }),
      Choice.h('ほかの者に譲る', '重荷は負わない', () => '自分には荷が重いと、年寄りの一人に譲った。'),
    ], after: next);
  }, also: (g) => !g.l.female),

  // ============================================ 筋: 種籾
  SceneDef(
    'tf_f_tane',
    18,
    70,
    (g) => _coldLands.contains(g.l.region) ? _w1 * 1.4 : _w1,
    tfFarmer,
    (g, next) {
      final l = g.l;
      final cold = _coldLands.contains(l.region);
      g.ask('種籾', '${cold ? '冷たい夏のあとの、長い冬。' : '凶作の冬。'}家の者は腹を空かせている。蔵に残るのは、春に蒔く種籾だけだ。', [
        Choice.h('種籾には手をつけない', '春は来る。冬を越せるかは分からない', () {
          if (g.rng.chance(l.hp < 40 ? .06 : .02)) {
            g.die('凶作の冬、種籾に手をつけずに飢え死んだ', 'ue');
            return '種籾の俵に、とうとう手をつけなかった。';
          }
          l.hp -= 15;
          g.j(-4);
          g.setFlag('tf_kept_seed');
          g.mark('凶作の冬、飢えても種籾には手をつけなかった');
          return '草の根を煮て冬を越した。春、種籾を蒔いた。';
        }),
        Choice.h('種籾を食べて冬を越す', '今は生きられる。春に蒔くものがない', () {
          _lose(g, .5);
          g.j(-6);
          return '種籾を粥にして食べた。春、よその家の田を手伝って食いつないだ。';
        }),
        Choice.h('寺や土豪から種籾を借りる', '冬も春も越せる。利は重い', () {
          g.setFlag('tf_seed_borrowed');
          _stamp(g, 'seed');
          return '土豪の蔵から、利をつけて返す約束で種籾を借りた。';
        }),
      ], after: next);
    },
  ),

  _chain('tf_f_shakumai', 19, 75, _w2, tfFarmer, (g, next) {
    final l = g.l;
    g.ask('借りた種籾', '借りた種籾を返す日が来た。利は重く、秋の実りでは返しきれない。土豪の手下が、田を見回っている。', [
      Choice.h('田の一枚を手放して返す', '借りは消える。田は痩せる', () {
        g.setFlag('tf_lost_field');
        g.j(-8);
        return '一番よい田を、土豪に渡した。';
      }),
      Choice.h('一家で土豪の田を手伝って返す', '田は残る。体がすり減る', () {
        l.hp -= 15;
        g.setFlag('tf_debt_worked');
        return '一家そろって、三年、土豪の田で働いた。';
      }),
      if (l.mi >= 60)
        Choice.h('土豪に頭を下げ、返す年を延ばしてもらう', '人柄で通ることもある', () {
          if (g.rng.chance(.7)) {
            l.net += 2;
            return '土豪は笑って、来年でよいと言った。';
          }
          g.setFlag('tf_lost_field');
          return '頭を下げても通らなかった。田の一枚を手放した。';
        }),
    ], after: next);
  }),

  // ============================================ ひとつきり
  SceneDef('tf_f_randori', 18, 75, (g) => _w1, tfFarmer, (g, next) {
    final l = g.l;
    final foe = _foeHouse(g);
    g.ask('乱取りの噂', '$foeが近くまで攻め寄せてきた。雑兵たちは通りがかりの村々で、米も牛も人も奪っていくという。', [
      Choice.h('銭を集め、大将から禁制の札をもらう', '札があれば兵は手を出さない。銭は痛い', () {
        _lose(g, .25);
        if (g.rng.chance(.8)) {
          l.net += 3;
          g.setFlag('tf_kinsei');
          g.mark('村の銭を集めて禁制の札をもらい、乱取りから村を守った');
          return '村の入り口に禁制の札を立てた。雑兵たちは札を見て、通り過ぎていった。';
        }
        return '札は間に合わなかった。村の蔵が荒らされた。';
      }),
      Choice.h('家財をまとめ、山小屋へ逃げ込む', '命は守れる。残した物は奪われる', () {
        _lose(g, .3);
        g.setFlag('tf_yamagoya');
        return '村じゅうで山の小屋へ逃げ込んだ。戻ると、家は空になっていた。';
      }),
      if (g.canFight)
        Choice.h('村の男たちと、谷の道で待ち伏せる', '追い返せば村の誉れ。雑兵も命がけだ', () {
          if (g.rng.chance(.05 - l.bu / 3000)) {
            g.die('村を襲う雑兵と戦い、討たれた', 'senshi');
            return '谷の道で、雑兵の槍に貫かれた。';
          }
          if (g.rng.chance(.4 + l.bu / 200)) {
            l.fame += 8;
            l.bu = _c(l.bu + 1);
            g.setFlag('tf_fought_raiders');
            g.mark('村の男たちと待ち伏せ、乱取りの雑兵を追い返した');
            return '石と竹槍で雑兵を追い返した。村の蔵は守られた。';
          }
          l.hp -= 18;
          _lose(g, .2);
          return '雑兵の数が多すぎた。手傷を負って山へ逃げた。';
        }),
      if (l.mi >= 60)
        Choice.h('雑兵の頭に酒を振る舞い、村を素通りさせる', '口と酒でかわせることもある', () {
          if (g.rng.chance(.65)) {
            _lose(g, .08);
            g.setFlag('tf_randori_talked');
            return '酒樽を開けて頭をもてなした。雑兵たちは、千鳥足で次の村へ向かった。';
          }
          _lose(g, .3);
          return '酒は飲まれ、蔵も荒らされた。';
        }),
    ], after: next);
  }),

  SceneDef(
    'tf_f_jinpu',
    25,
    65,
    (g) => _w1,
    tfFarmer,
    (g, next) {
      final l = g.l;
      final son = l.kids > 0 && l.hasKidAged(g.year, 15, 25);
      final lord = _nearHouse(g);
      g.ask('陣触れの村', son
          ? '$lordの陣触れで、村から足軽を出せと言ってきた。寄合では、年頃の子のいるあなたの家に目が集まっている。'
          : '$lordの陣触れで、村から足軽を出せと言ってきた。誰を出すかで、寄合が揉めている。', [
        if (son)
          Choice.h('子を出す', '手柄を立てれば家の誉れ。戻らないこともある', () {
            if (g.rng.chance(.12)) {
              l.loseKid(g.year, 15, 25);
              g.setFlag('fa_lost_child');
              g.j(-25);
              g.mark('陣触れで足軽に出した子を、戦で失った');
              return '戦が終わっても、子は戻らなかった。';
            }
            l.gold += 5;
            g.setFlag('tf_sent_son');
            return '子は手傷ひとつなく戻り、恩賞の銭を手渡してくれた。';
          }),
        Choice.h('銭を出して、代わりの者を雇う', '家の者は出さずに済む。蔵は軽くなる', () {
          _lose(g, .25);
          g.setFlag('tf_paid_substitute');
          return '渡り者に銭を払い、代わりに出てもらった。';
        }),
        if (!l.female)
          Choice.h('自ら陣夫として荷を担いで出る', '家の者は守れる。戦場は荷運びにも容赦がない', () {
            l.hp -= 15;
            l.gold += 3;
            g.setFlag('tf_went_jinpu');
            return '兵糧の俵を担いで、軍勢の後ろを歩いた。戦は見ずに済んだが、肩の皮がむけた。';
          }),
        Choice.h('くじで決めようと言う', '公平だ。外れた家は恨まない', () {
          l.net += 1;
          return 'くじで決まった。当たった家の若い者は、黙って支度を始めた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tf_f_tokusei_ikki',
    18,
    60,
    (g) => _w1 * 1.5,
    (g) => tfFarmer(g) && _kinai.contains(g.l.region),
    (g, next) {
      final l = g.l;
      g.ask('徳政一揆', '馬借や百姓が寄り集まり、徳政を求めて京の土倉へ押し寄せるという。借りた銭の証文を、焼き捨てるのだ。', [
        Choice.h('一揆に加わる', '借りは消えるかもしれない。荒事になる', () {
          if (g.rng.chance(.55)) {
            l.gold += 6;
            g.setFlag('tf_ikki_tokusei');
            g.mark('徳政一揆に加わり、土倉の証文を焼き捨てた');
            return '土倉の門を破り、証文の束を火にくべた。';
          }
          l.hp -= 15;
          return '侍所の兵に追い散らされ、手傷を負って村へ逃げ帰った。';
        }),
        Choice.h('加わらず、村を守る', '荒事には関わらない。借りは残る', () {
          return '村の木戸を閉め、一揆の行列を見送った。';
        }),
        if (l.chi >= 60)
          Choice.h('借り手をまとめ、土倉と内々に話をつける', '知恵で血を流さずに済む。どちらにも恨まれうる', () {
            l.gold += 3;
            l.fame += 4;
            g.setFlag('tf_ikki_talk');
            return '借りた銭の半ばを棒引きにさせる話を、土倉の主とまとめた。';
          }),
      ], after: next);
    },
    ageOk: (g, a) => g.l.startYear + a <= 1570,
  ),

  SceneDef(
    'tf_f_hikan',
    18,
    40,
    (g) => g.l.bu >= 60 ? _w1 * 1.4 : _w1,
    (g) => tfFarmer(g) && !g.l.female,
    (g, next) {
      final l = g.l;
      final strong = l.bu >= 60;
      g.ask('土豪の誘い', strong
          ? '村の土豪が、あなたの腕を見込んで被官に取り立てたいと言う。戦のときは槍を持って従い、その代わり年貢の一部を免じるという。'
          : '村の土豪が、被官に取り立ててやろうと言う。戦のときは荷を担いで従い、その代わり年貢の一部を免じるという。', [
        Choice.h('被官になる', '年貢は軽くなる。土豪の戦に付き合わされる', () {
          l.gold += strong ? 8 : 4;
          l.hp -= 5;
          g.setFlag('tf_hikan');
          g.mark('村の土豪の被官となった');
          return '土豪の屋敷で盃を受け、被官の一人になった。';
        }),
        Choice.h('百姓のままでいる', '誰の戦にも付き合わない。年貢は重いまま', () {
          return '土豪の誘いは、丁重に断った。';
        }),
      ], after: next);
    },
  ),
];
