import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 城主・家老・宿老（位5〜7）の年の岐路（2026-11-23）。id・旗は `cl_`。
///
/// `lords.dart` に城主・家老の岐路は17あるが、考えて選ぶ遊び方では成人の約3割が城主以上に届き、その年は長い。
/// `lords.dart`（町割り・年貢の増徴・暴れ川・検地・牢人・若侍の失態・老臣の諫言・人質・寵臣・国替え・国境の小競り合い・
/// 敵の密書・嫡男の器・娘の縁組・実家との手切れ・腹心の囁き・兵糧の蓄え）、`retainer_life.dart`（`rt_`）、
/// `battles.dart`（籠城の夜の見回り・兵糧の尽きかけた城・采配）、`talents.dart`（縄張り・同盟の使者）とは題材を変えてある。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kCastlePrev]）。段を踏んだ年は旗 `cl_at:<筋>:<年>` に残し、
/// 次の段は何年か空けてから出す（[kCastleGap]）。
///
/// - 城を預かる: 石垣の普請／家中の借銀 → 返済の催促／寺社の掟／入会の山の訴え → 裁きのその後／刈田／
///   籠城の備え（井戸・兵糧・水の手）→ 囲まれた城／城の内の間者 → 捕らえた・泳がせた・暇を出したその後／主家の目付。
/// - 家老として: 主君の世継ぎ選び → 若殿の代／主君を諫める → 諫めたその後／他家との縁組の交渉 → 盟約の揺らぎ／
///   譜代の老臣との対立 → 老臣の死の床／主家の危機の評定（降るか戦うか）。
/// - 城主の家: 跡取りの育て方 → 育った跡取り／嫡男の嫁／長陣の留守を奥方に預けるか → 留守のあいだのこと。
///   奥方（嫁いだ女性）には、家臣の妻子を城の奥に預かる・家臣の娘の縁組の世話。
/// - 誰に出るか: 城を預かる身は男と、留守の城を守り抜いて女城主と呼ばれた女性（`onna_jo`）。
///   奥方の場面は嫁いだ女性（位5〜7）。後見・女大名（位8以上）には出さない。
/// - 位は上げない（大名への道は下剋上と `game.dart` の仕組みに任せ、功・信頼・名声・人の縁で返す）。
/// - 能力（武・知・政・魅）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

/// 城主・家老・宿老として仕えている（位5〜7・隠居でない・仏門でない・主家が生きている）。
bool clServing(Game g) =>
    g.l.rank >= 5 &&
    g.l.rank <= 7 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 城を預かり、家中の政に関わる身（男と、女城主と呼ばれた女性）。
bool clLord(Game g) =>
    clServing(g) && (!g.l.female || g.hasFlag('onna_jo'));

/// 城主の家の奥方（位5〜7で嫁いでいる女性）。
bool clWife(Game g) =>
    clServing(g) && g.l.female && g.l.married && g.l.people.containsKey('伴侶');

/// この岐路が出てよい人。テストも使う。
bool clLife(Game g) => clLord(g) || clWife(g);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kCastlePrev = <String, List<String>>{
  'cl_gin_due': ['cl_gin_borrowed'],
  'cl_iriai_after': ['cl_iriai_deed', 'cl_iriai_split', 'cl_iriai_taken'],
  'cl_rojo': ['cl_well_dug', 'cl_rice_stored', 'cl_mizunote', 'cl_rojo_none'],
  'cl_kancho_after': ['cl_spy_caught', 'cl_spy_turned', 'cl_spy_sent'],
  'cl_yotsugi_after': ['cl_yt_eldest', 'cl_yt_younger', 'cl_yt_silent', 'cl_yt_both'],
  'cl_isame_after': ['cl_isame_spoke', 'cl_isame_joint', 'cl_isame_obeyed'],
  'cl_domei_after': ['cl_domei_done', 'cl_domei_yielded', 'cl_domei_failed'],
  'cl_fudai_end': ['cl_fudai_beat', 'cl_fudai_bowed', 'cl_fudai_judged', 'cl_fudai_grandson'],
  'cl_atotori_after': ['cl_heir_home', 'cl_heir_kosho', 'cl_heir_tera'],
  'cl_rusu_after': ['cl_rusu_wife', 'cl_rusu_elder', 'cl_rusu_both'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kCastleGap = <String, (String, int)>{
  'cl_gin_due': ('gin', 2),
  'cl_iriai_after': ('iriai', 2),
  'cl_rojo': ('rojo', 2),
  'cl_kancho_after': ('kancho', 2),
  'cl_yotsugi_after': ('yotsugi', 3),
  'cl_isame_after': ('isame', 2),
  'cl_domei_after': ('domei', 3),
  'cl_fudai_end': ('fudai', 2),
  'cl_atotori_after': ('atotori', 4),
  'cl_rusu_after': ('rusu', 1),
};

/// この岐路の id（テストが使う）。
const kCastleLifeIds = [
  'cl_ishigaki',
  'cl_gin',
  'cl_gin_due',
  'cl_jisha',
  'cl_iriai',
  'cl_iriai_after',
  'cl_karita',
  'cl_rojo_bi',
  'cl_rojo',
  'cl_kancho',
  'cl_kancho_after',
  'cl_metsuke',
  'cl_yotsugi',
  'cl_yotsugi_after',
  'cl_isame',
  'cl_isame_after',
  'cl_domei',
  'cl_domei_after',
  'cl_fudai',
  'cl_fudai_end',
  'cl_kiki',
  'cl_atotori',
  'cl_atotori_after',
  'cl_yome',
  'cl_rusu',
  'cl_rusu_after',
  'cl_w_hitojichi',
  'cl_w_enmusubi',
];

/// 奥方（嫁いだ女性）に出る岐路。テストが使う。ほかに `cl_yome` は城を預かる身と奥方の両方に出る。
const kCastleWifeIds = ['cl_w_hitojichi', 'cl_w_enmusubi'];

/// 城を預かる身と奥方の両方に出る岐路。
const kCastleBothIds = ['cl_yome'];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('cl_at:$chain:'));
  g.setFlag('cl_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int clSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('cl_at:$chain:')) {
      return g.year - int.parse(f.substring('cl_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool clChainReady(Game g, String id) {
  final prev = kCastlePrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kCastleGap[id];
  if (gap == null) return true;
  return clSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _fav(Game g, int n) => g.l.fav = _c(g.l.fav + n);
void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _troops(Game g, int n) => g.l.troops = g.l.troops + n < 0 ? 0 : g.l.troops + n;
void _hurt(Game g, int n) => g.l.hp -= n;

void _bond(Person? p, int n) {
  if (p != null) p.bond = _c(p.bond + n);
}

/// 旗 `<頭><名>` から名を取り出す。なければ [fallback]。
String _named(Game g, String head, String fallback) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return fallback;
}

void _keepName(Game g, String head, String name) {
  g.l.flags.removeWhere((f) => f.startsWith(head));
  g.setFlag('$head$name');
}

String _man(Game g) => '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';

/// 主家の呼び名（「◯◯家」）。
String _house(Game g) => '${houseName(g, g.l.lord)}家';

/// 主家に近いほかの家（内部の名）。いなければ null。
String? _other(Game g) {
  final lf = g.l.lord;
  if (lf == null) return null;
  final c = nearest(g.alive.where((f) => f.name != lf), (f) => f.name, faction: lf, n: 3);
  return c.isEmpty ? null : g.rng.pick(c).name;
}

String _otherName(Game g, String? f) => f == null ? '隣国の家' : '${houseName(g, f)}家';

/// 主家が近い家のどれかより弱い（危機の評定・刈田が出やすい）。
bool _lordWeak(Game g) {
  final lf = g.fa[g.l.lord];
  if (lf == null) return false;
  final c = nearest(g.alive.where((f) => f.name != lf.name), (f) => f.name, faction: lf.name, n: 3);
  return c.any((f) => f.power > lf.power * 1.2);
}

/// 連れ合いの名（いなければ「奥方」「夫」）。
String _spouse(Game g) => g.l.people['伴侶']?.name ?? (g.l.female ? '夫' : '奥方');

/// 嫡男の名（家族の岐路で決まっていればその名、なければこの筋で一度決めて残す）。
String _heir(Game g) {
  final p = g.l.people['嫡男'];
  if (p != null) return p.name;
  final n = _named(g, 'cl_heir_name:', '');
  if (n.isNotEmpty) return n;
  final pick = g.rng.pick(kHeirNames);
  _keepName(g, 'cl_heir_name:', pick);
  return pick;
}

/// 重み。筋の始まり・ひとつきりは [_w1]、前の段を踏んだ人だけに出る後段は [_w2]。
const _w1 = 5.5;
const _w2 = 24.0;

/// 奥方の場面の重み（女性に出せる場面は少なく、`ok_` の嫁いだ身の岐路と分け合うため）。
const _wWife = 3.5;

SceneDef _chain(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run,
) => SceneDef(id, minAge, maxAge, (g) => w, (g) => who(g) && clChainReady(g, id), run);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildCastleLifeScenes() => [
  ..._castleScenes(),
  ..._karoScenes(),
  ..._houseScenes(),
];

// ---------------------------------------------------------------- 城を預かる

List<SceneDef> _castleScenes() => [
  // ============================================ ひとつきり: 石垣の普請
  SceneDef('cl_ishigaki', 22, 70, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    g.ask('石垣の普請', '預かる城は、土を盛っただけの古い土塁だ。近ごろ、近江から来た石工の一団が、石を積めば鉄砲の玉も通さぬと売り込んできた。石を山から下ろすには、領内の村の男手が要る。', [
      Choice.h('石工を雇い、腕のいい者に積ませる', '堅い城になる。銭は大きく出ていく', () {
        _pay(g, 25);
        _fame(g, 3);
        _fav(g, 2);
        g.setFlag('cl_ishi_ano');
        g.mark('預かる城に、石工を招いて野面積みの石垣を築かせた');
        return '石工の頭は、石の顔を読むように一つずつ据えていった。半年ののち、雨に濡れた石垣は、黒々と城を抱いていた。';
      }),
      Choice.h('村々に夫役を課して積ませる', '銭はかからない。村の恨みを買う', () {
        _pay(g, 6);
        g.j(-2);
        _net(g, -2);
        g.setFlag('cl_ishi_buyaku');
        return '田植えの前の村から、男たちを山へ駆り出した。石垣は積み上がったが、村の寄合では、あなたの名が出るたびに皆が黙り込んだ。';
      }),
      Choice.h('土塁のままにして、銭を蔵に残す', '蔵は守れる。主家からは怠けと見られるかもしれない', () {
        _fav(g, -2);
        return '石工の一団は、隣の領へ去っていった。土塁の上の草は、今年もよく伸びた。';
      }),
      if (l.chi >= 60)
        Choice.h('自ら縄を張り、要所だけを石で固める', '才が当たれば安く堅くなる。見立てを誤れば無駄になる', () {
          _pay(g, 10);
          if (g.rng.chance(clampD(.5 + l.chi / 300, .5, .85))) {
            _fame(g, 4);
            _fav(g, 3);
            l.merit += 3;
            g.setFlag('cl_ishi_ano');
            g.setFlag('cl_ishi_self');
            g.mark('自ら縄を張り、城の要所を石垣で固めた');
            return '虎口と水の手の曲輪だけを石で固めた。検分に来た主家の重臣は、しばらく石垣を見上げてから「無駄がない」と言った。';
          }
          _fav(g, -1);
          return '石を据えた所は、敵が攻めてくるはずのない斜面だった。石工の頭が、気の毒そうに顔をそむけた。';
        }, via: '知'),
    ], after: next);
  }),

  // ============================================ 筋: 家中の借銀
  SceneDef('cl_gin', 22, 70, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final m = g.rng.pick(['堺屋', '大黒屋', '升屋', '近江屋']);
    _keepName(g, 'cl_gin_name:', m);
    g.ask('家中の借銀', '続く戦で、城の蔵が底をつきかけている。家臣への扶持も滞りがちだ。城下の豪商、$mの主人が、利は高いが銀を用立ててもよいと言ってきた。', [
      Choice.h('$mから銀を借りる', '扶持は払える。返す日はいずれ来る', () {
        l.gold += 30;
        _net(g, 1);
        g.setFlag('cl_gin_borrowed');
        _stamp(g, 'gin');
        return '$mの主人は、証文に印を押すと、深々と頭を下げた。蔵には銀が積まれ、家臣たちの顔に笑みが戻った。';
      }),
      Choice.h('倹約の触れを出し、家中で耐える', '借りは作らない。家臣の不満は募る', () {
        _net(g, -2);
        g.j(-2);
        g.setFlag('cl_gin_saved');
        _stamp(g, 'gin');
        return '膳の数を減らし、城の灯りを早く消させた。あなた自ら麦飯をすすって見せたが、若い家臣たちの不満の声は消えなかった。';
      }),
      if (l.sei >= 60)
        Choice.h('城の蔵入地の帳面を自ら洗い直す', '政の才があれば漏れを見つけられる。手間がかかる', () {
          _stamp(g, 'gin');
          if (g.rng.chance(clampD(.45 + l.sei / 250, .45, .85))) {
            l.gold += 18;
            l.merit += 3;
            _fav(g, 2);
            g.setFlag('cl_gin_ledger');
            g.mark('城の蔵入地の帳面を洗い直し、漏れていた年貢を見つけ出した');
            return '夜ごと帳面を繰った。代官の一人が、三つの村の年貢を少しずつ懐に入れていたのが分かった。取り戻した米で、扶持はどうにか払えた。';
          }
          g.j(-2);
          return '目を赤くして帳面を繰ったが、漏れは見つからなかった。結局、倹約の触れを出すほかなかった。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('cl_gin_due', 24, 74, _w2, clLord, (g, next) {
    final l = g.l;
    final m = _named(g, 'cl_gin_name:', '城下の豪商');
    g.ask('返済の催促', '$mの手代が、証文を携えて城へ来た。返済の期日はとうに過ぎている、利だけでも納めてほしいという。蔵には、まだ十分な銀がない。', [
      Choice.h('蔵の物を売ってでも返す', '城の信用は守れる。蔵はまた空になる', () {
        _pay(g, 25);
        _fame(g, 2);
        _net(g, 2);
        g.setFlag('cl_gin_repaid');
        _stamp(g, 'gin');
        g.mark('城の蔵の具足や茶道具を売り払ってまで、商人からの借銀を返した');
        return '父祖伝来の具足まで売りに出した。$mの主人は、それを聞くと自ら城へ来て「次も、お役に立たせていただきます」と言った。';
      }),
      Choice.h('徳政を盾に、借りを棒引きにさせる', '銀は返さずに済む。城下の商人たちは離れていく', () {
        _fame(g, -3);
        _net(g, -3);
        g.j(1);
        g.setFlag('cl_gin_tokusei');
        _stamp(g, 'gin');
        return '城下に徳政の札を立てさせた。$mは何も言わずに店を畳み、隣国の城下へ移っていった。ほかの商人たちも、城の御用を口実をつけて断るようになった。';
      }),
      if (l.mi >= 60)
        Choice.h('$mの主人を城に招き、御用商人に取り立てて返済を延ばす', '人柄が通じれば借りが縁に変わる。足元を見られることもある', () {
          _stamp(g, 'gin');
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 4);
            l.gold += 5;
            g.setFlag('cl_gin_goyo');
            g.mark('借銀を貸した豪商を城の御用商人に取り立て、返済を延ばさせた');
            return '茶を点てて、城の御用を一手に任せたいと言った。主人はしばらく茶碗を見つめ、「利は、いただかぬことにいたしましょう」と笑った。';
          }
          _pay(g, 10);
          _net(g, -1);
          return '主人は茶を飲み干すと、「御用は御用、証文は証文にございます」と言った。利だけは、その場で払わされた。';
        }, via: '魅'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 寺社の掟
  SceneDef('cl_jisha', 22, 74, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    g.ask('寺社の掟', '城下の古い寺に、年貢を拒んだ村の者が逃げ込んだ。寺は、境内に入った者は誰であれ引き渡さぬのが古くからの掟だと言い張っている。家臣たちは、踏み込めと息巻いている。', [
      Choice.h('寺の掟を立て、出てくるのを待つ', '寺社とは事を構えずに済む。城の威は軽く見られる', () {
        _net(g, 2);
        _fav(g, -1);
        g.setFlag('cl_jisha_waited');
        return '寺の門の外に番を置いただけで、手は出さなかった。ひと月ののち、男は住持に付き添われて自ら出てきた。住持は門の前で、あなたに深く頭を下げた。';
      }),
      Choice.h('兵を入れて引きずり出す', '城の威は示せる。寺社と門徒の恨みを買う', () {
        _fav(g, 2);
        _net(g, -3);
        g.j(-2);
        g.setFlag('cl_jisha_forced');
        return '兵が山門をくぐると、鐘が乱れ打たれた。男は縄を打たれて引き出されたが、その日から、城下の門徒たちはあなたの行列に頭を下げなくなった。';
      }),
      if (l.mi >= 60)
        Choice.h('自ら寺へ出向き、住持と膝を詰める', '人柄が通じれば寺も村も立つ。軽く扱われれば面目を失う', () {
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 4);
            _fame(g, 2);
            g.setFlag('cl_jisha_talked');
            g.mark('寺へ逃げ込んだ百姓のことで、自ら住持と膝を詰めて話をつけた');
            return '住持と夜更けまで話した。年貢は翌年に延べ、男は寺男として寺に置くことで話がついた。住持は帰り際、「よい城主を持った」と村の者に言ったという。';
          }
          _fame(g, -2);
          return '住持は、経を読む声を止めもしなかった。あなたは半刻ほど待たされ、黙って城へ帰った。';
        }, via: '魅'),
    ], after: next);
  }),

  // ============================================ 筋: 入会の山
  SceneDef('cl_iriai', 22, 74, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final a = g.rng.pick(['上の村', '川上の村', '東の村']);
    final b = g.rng.pick(['下の村', '川下の村', '西の村']);
    _keepName(g, 'cl_iriai_a:', a);
    _keepName(g, 'cl_iriai_b:', b);
    g.ask('入会の山の訴え', '領内の$aと$bが、薪と草を刈る入会の山の境を争い、互いの長が城へ訴え出た。$aは古い証文を持ち、$bは昔からそこで刈ってきたと言う。どちらの村にも、鎌を研ぐ若い者が増えている。', [
      Choice.h('古い証文どおりに裁く', '筋は通る。負けた村は納得しない', () {
        _fav(g, 1);
        g.setFlag('cl_iriai_deed');
        _stamp(g, 'iriai');
        return '証文を読み上げさせ、山は$aのものと裁いた。$bの長は平伏したまま、肩を震わせていた。';
      }),
      Choice.h('山を二つに分け、両村に刈らせる', '争いは収まりやすい。どちらも少しずつ損をする', () {
        _net(g, 2);
        g.setFlag('cl_iriai_split');
        _stamp(g, 'iriai');
        return '尾根に杭を打たせ、東と西に分けた。両村の長は顔を見合わせ、やがて渋々うなずいた。';
      }),
      Choice.h('山を城の御林とし、どちらにも刈らせない', '争いの種は消える。両村とも城を恨む', () {
        _fav(g, 2);
        _net(g, -3);
        g.setFlag('cl_iriai_taken');
        _stamp(g, 'iriai');
        return '山の入口に札を立て、城の番人を置いた。両村の長は、そろって黙り込んだ。';
      }),
      if (l.chi >= 60)
        Choice.h('自ら山へ登り、古老に昔の境を尋ね歩く', '才が当たれば両村が得心する。日数はかかる', () {
          _stamp(g, 'iriai');
          if (g.rng.chance(clampD(.5 + l.chi / 300, .5, .85))) {
            _net(g, 4);
            _fame(g, 2);
            g.setFlag('cl_iriai_split');
            g.setFlag('cl_iriai_walked');
            g.mark('入会の山を自ら歩き、古老に昔の境を尋ねて二つの村の争いを裁いた');
            return '両村の古老を連れて尾根を歩いた。苔むした境の石が見つかると、古老たちは「これじゃ、これじゃ」と声を上げた。';
          }
          g.setFlag('cl_iriai_deed');
          return '三日かけて山を歩いたが、古老たちの話は食い違うばかりだった。結局、証文どおりに裁くほかなかった。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('cl_iriai_after', 24, 76, _w2, clLord, (g, next) {
    final a = _named(g, 'cl_iriai_a:', '上の村');
    final b = _named(g, 'cl_iriai_b:', '下の村');
    if (g.hasFlag('cl_iriai_split')) {
      g.ask('二つの村の祭り', '入会の山を分けてから二年。$aと$bが、山の神の祭りを初めて一緒に開くので、城主にも来てほしいと言ってきた。', [
        Choice.h('自ら出向いて酒を酌み交わす', '村の心をつかめる。家臣は軽々しいと眉をひそめる', () {
          _net(g, 4);
          g.j(4);
          g.setFlag('cl_iriai_feast');
          _stamp(g, 'iriai');
          g.mark('かつて山を争った二つの村の祭りに招かれ、百姓たちと酒を酌み交わした');
          return '篝火の前で、両村の長と並んで盃を受けた。若い者たちの相撲を見て、あなたも思わず声を上げた。';
        }),
        Choice.h('祝いの酒樽だけを届けさせる', '城主の格は保てる。村との間は少し遠い', () {
          _net(g, 1);
          _stamp(g, 'iriai');
          return '酒樽に城の印を付けて届けさせた。夜になって、山の方から太鼓の音が聞こえてきた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('cl_iriai_taken')) {
      g.ask('御林の盗伐', '城の御林にした山で、夜ごと木が切られている。番人が捕らえたのは、$bの若い男だった。薪がなければ冬は越せぬと言うばかりだという。', [
        Choice.h('掟どおりに罰する', '御林の掟は守られる。村の恨みは深まる', () {
          _fav(g, 1);
          _net(g, -3);
          g.j(-2);
          _stamp(g, 'iriai');
          return '男は鞭打たれて村へ帰された。その冬、$bの者は誰も城の普請に出てこなかった。';
        }),
        Choice.h('御林を解き、両村に刈らせる', '村は救われる。一度出した触れを曲げることになる', () {
          _net(g, 4);
          _fav(g, -1);
          g.setFlag('cl_iriai_returned');
          _stamp(g, 'iriai');
          g.mark('城の御林にした山を解き、薪に困る村々にふたたび刈らせた');
          return '札を抜かせた。翌朝、山の入口には、両村の者が置いていった干し柿が並んでいた。';
        }),
        Choice.h('男を城の薪割りに使い、罪を償わせる', '罰と情けの間を取る。どちらにも半端に見える', () {
          _net(g, 1);
          _stamp(g, 'iriai');
          return '男は冬の間、城の台所で薪を割った。春になって村へ帰るとき、背に負えるだけの薪を持たせた。';
        }),
      ], after: next);
      return;
    }
    g.ask('逃散の噂', '入会の山を$aのものと裁いてから二年。山を失った$bの者たちが、隣の領へ村ごと逃げようとしているという噂が届いた。', [
      Choice.h('$bの年貢を軽くして引き止める', '村は残る。$aの者が不公平だと言い出す', () {
        _pay(g, 8);
        _net(g, 3);
        g.setFlag('cl_iriai_eased');
        _stamp(g, 'iriai');
        g.mark('山を失った村の年貢を軽くして、逃散を思いとどまらせた');
        return '$bの長を城へ呼び、三年のあいだ年貢を軽くすると約した。長は、しばらく顔を上げられなかった。';
      }),
      Choice.h('関所を固めて逃がさない', '村は留められる。恨みは残る', () {
        _troops(g, -2);
        _net(g, -3);
        _fav(g, 1);
        _stamp(g, 'iriai');
        return '国境の道に兵を置かせた。逃散は止んだが、$bの田は、その年から目に見えて荒れていった。';
      }),
      Choice.h('去る者は追わない', '手間はかからない。田を耕す者が減る', () {
        _pay(g, 6);
        g.j(-2);
        _stamp(g, 'iriai');
        return 'ある朝、$bの家々から煙が上がらなくなった。空いた田に、$aの者が少しずつ鍬を入れ始めた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 刈田（出るか耐えるか）
  SceneDef('cl_karita', 22, 70, (g) => _w1 * (_lordWeak(g) ? 1.5 : 1), clLord, (g, next) {
    final l = g.l;
    final ef = _other(g);
    final en = _otherName(g, ef);
    g.ask('刈田', '物見が駆け戻った。$enの兵が境を越え、実りかけた領内の稲を刈り取っている。城を誘い出す手だと、古参の家臣は言う。村の者は、城の門の前に集まっている。', [
      Choice.h('城を出て、刈田の兵を追い払う', '村は守れる。敵の誘いに乗れば痛手を負う', () {
        final r = g.battle('main', enemy: ef, risk: 1.1, gain: .9);
        if (l.dead != null) return '城の兵を率いて田へ駆けた。$r';
        _net(g, 3);
        g.setFlag('cl_karita_out');
        return '城の兵を率いて田へ駆けた。$r';
      }),
      Choice.h('門を閉ざして耐える', '兵は損なわない。村の者はあなたを見限るかもしれない', () {
        _net(g, -4);
        g.j(-3);
        _fav(g, 1);
        g.setFlag('cl_karita_held');
        return '櫓の上から、刈られていく田を見ていた。日が暮れて敵が引き上げると、門の前の村の者たちも、黙って帰っていった。';
      }),
      if (l.chi >= 60)
        Choice.h('刈らせておき、敵の引き上げる道に兵を伏せる', '才が当たれば刈った稲ごと奪い返せる。読みを誤れば何も取り戻せない', () {
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            final r = g.battle('main', enemy: ef, risk: .7, gain: 1.2, edge: .15);
            if (l.dead != null) return '谷あいの道の両側に兵を伏せた。$r';
            _net(g, 4);
            _fame(g, 3);
            g.setFlag('cl_karita_ambush');
            g.mark('刈田に来た敵の兵を引き上げる道で待ち伏せ、刈られた稲を村へ取り戻した');
            return '谷あいの道の両側に兵を伏せた。稲を背負った敵の兵は、荷を捨てて逃げ散った。$r';
          }
          _net(g, -3);
          return '敵は別の道を通って引き上げた。伏せた兵たちは、夜露に濡れて城へ戻った。';
        }, via: '知'),
      if (_lordWeak(g) || l.fav >= 40)
        Choice.h('主家へ使いを出し、援けの兵を請う', '主家の兵が来れば押し返せる。自分の城も守れぬのかと見られる', () {
          _fav(g, -3);
          _net(g, 1);
          return '主家の兵が着いたのは、三日のちだった。田はもう刈り尽くされていたが、敵はそれを見て境の向こうへ退いた。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 籠城の備え
  SceneDef('cl_rojo_bi', 22, 70, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    g.ask('籠城の備え', '城の水の手は、本丸の古井戸が一つきりだ。兵糧蔵も半ばは空いている。近ごろ、隣国の動きがきな臭い。蔵の銭は、どれか一つにしか回せない。', [
      Choice.h('二の丸にも井戸を掘らせる', '囲まれても水に困らない。掘り当てられるかは運もある', () {
        _pay(g, 12);
        if (g.rng.chance(.75)) {
          g.setFlag('cl_well_dug');
          _stamp(g, 'rojo');
          return '井戸掘りの者たちは、七日目に冷たい水を掘り当てた。あなたは柄杓で一口飲み、黙ってうなずいた。';
        }
        g.setFlag('cl_rojo_none');
        _stamp(g, 'rojo');
        return '掘っても掘っても、出てくるのは乾いた岩ばかりだった。井戸掘りの者たちは、首を振って山を下りた。';
      }),
      Choice.h('兵糧を買い込み、蔵を満たす', '長く持ちこたえられる。米は年ごとに傷む', () {
        _pay(g, 12);
        g.setFlag('cl_rice_stored');
        _stamp(g, 'rojo');
        return '近在の村から米を買い集め、兵糧蔵の戸が閉まらなくなるほど積み上げた。';
      }),
      if (l.chi >= 60)
        Choice.h('古井戸へ下る水の手の曲輪を固める', '才があれば少ない銭で城の弱みを消せる。見立てしだいだ', () {
          _pay(g, 6);
          g.setFlag('cl_mizunote');
          _stamp(g, 'rojo');
          return '谷へ下る水汲みの道に、塀と小さな櫓を設けさせた。古参の家臣は「ここを断たれた城を、いくつも見てまいりました」と言った。';
        }, via: '知'),
      Choice.h('いまは何もしない', '銭は残る。いざというときに悔いるかもしれない', () {
        g.setFlag('cl_rojo_none');
        _stamp(g, 'rojo');
        return '井戸も蔵も、そのままにした。きな臭い噂は、そのうち聞こえなくなった。';
      }),
    ], after: next);
  }),

  _chain('cl_rojo', 24, 74, _w2, clLord, (g, next) {
    final l = g.l;
    final ef = _other(g);
    final en = _otherName(g, ef);
    final well = g.hasFlag('cl_well_dug') || g.hasFlag('cl_mizunote');
    final rice = g.hasFlag('cl_rice_stored');
    final prep = well
        ? '水の手は守られている。'
        : (rice ? '兵糧はあるが、水は本丸の古井戸だけが頼りだ。' : '水も兵糧も心もとない。');
    g.ask('囲まれた城', '$enの大軍が、不意に城を囲んだ。主家の後詰めが来るまで、持ちこたえねばならない。$prep城兵たちは、あなたの顔色を見ている。', [
      Choice.h('門を閉ざし、後詰めを待って守り抜く', '備えがあれば持ちこたえられる。なければ苦しい日々になる', () {
        _stamp(g, 'rojo');
        if (g.rng.chance(.03)) {
          g.die('囲みの中、水の手の曲輪を見回っていて流れ矢を受け、果てた', 'senshi');
          return '水汲みの道を見回っていたとき、どこからか矢が飛んできた。';
        }
        final p = .35 + (well ? .3 : 0) + (rice ? .2 : 0);
        if (g.rng.chance(clampD(p, .3, .9))) {
          _fav(g, 6);
          _fame(g, 5);
          l.merit += 5;
          g.setFlag('cl_rojo_held');
          g.mark('囲まれた城を守り抜き、主家の後詰めが来るまで持ちこたえた');
          return well
              ? '敵は水の手を断とうと幾度も攻め寄せたが、そのたびに追い返された。ひと月ののち、主家の旗が峠に見えると、敵は囲みを解いて去った。'
              : '蔵の米を少しずつ分け、ひと月を耐えた。主家の旗が峠に見えたとき、城兵たちは声を上げて泣いた。';
        }
        _hurt(g, 15);
        _troops(g, -6);
        g.j(-6);
        return '喉の渇きに耐えかねて、夜ごと逃げ出す兵が出た。後詰めが着いたとき、城に残っていたのは半ばの兵だった。';
      }),
      Choice.h('夜討ちをかけて囲みを破る', '囲みが緩めば敵は退く。打って出れば命がけだ', () {
        _stamp(g, 'rojo');
        final r = g.battle('van', enemy: ef, risk: 1.2, gain: 1.1, edge: well ? .05 : 0);
        if (l.dead != null) return '月のない夜、城門を開いて打って出た。$r';
        g.setFlag('cl_rojo_sally');
        return '月のない夜、城門を開いて打って出た。$r';
      }),
      Choice.h('城を開き、兵の命と引き換えに和を請う', '城兵は助かる。主家の信は大きく損なわれる', () {
        _stamp(g, 'rojo');
        _fav(g, -12);
        _fame(g, -3);
        _troops(g, -4);
        g.setFlag('cl_rojo_opened');
        return '城門を開き、兵たちを無事に国へ帰す約を取りつけた。主家の後詰めが着いたのは、その二日あとだった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 城の内の間者
  SceneDef('cl_kancho', 22, 72, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final n = g.rng.pick(['与助', '弥平', '甚六', '久作']);
    _keepName(g, 'cl_spy_name:', n);
    g.ask('台所の男', '城の台所で下働きをしている$nという男が、夜ごと塀の外へ小石に巻いた紙を投げている、と小者が知らせてきた。半年前に城へ入った、口数の少ない男だ。', [
      Choice.h('捕らえて問いただす', '城の内の膿は出せる。背後の者に恨まれる', () {
        g.setFlag('cl_spy_caught');
        _stamp(g, 'kancho');
        _fav(g, 2);
        return '$nは、縄を打たれても何も言わなかった。懐の紙には、城の兵の数と、井戸の場所が書かれていた。';
      }),
      if (l.chi >= 60)
        Choice.h('知らぬふりで泳がせ、偽りの知らせを拾わせる', '才が当たれば敵を欺ける。見抜かれれば城の内が筒抜けのままだ', () {
          g.setFlag('cl_spy_turned');
          _stamp(g, 'kancho');
          return '台所の近くで、わざと兵糧が尽きかけていると話してみせた。その夜も、$nは塀の外へ小石を投げた。';
        }, via: '知'),
      Choice.h('何も言わずに暇を出す', '騒ぎにはならない。何を漏らしたかは分からないままだ', () {
        g.setFlag('cl_spy_sent');
        _stamp(g, 'kancho');
        return '$nに銭を少し持たせて、城から出した。男は一度だけ振り返り、門の外の坂を下りていった。';
      }),
    ], after: next);
  }),

  _chain('cl_kancho_after', 24, 74, _w2, clLord, (g, next) {
    final l = g.l;
    final n = _named(g, 'cl_spy_name:', '台所の男');
    final ef = _other(g);
    final en = _otherName(g, ef);
    if (g.hasFlag('cl_spy_turned')) {
      g.ask('偽りの知らせ', '$nに拾わせた知らせを真に受けたのか、$enの兵が城を落とせると見て、境の峠を越えてきた。物見によれば、兵の数は思いのほか少ない。', [
        Choice.h('峠の下で待ち伏せる', '敵を欺いた好機を生かせる。戦は戦だ', () {
          _stamp(g, 'kancho');
          final r = g.battle('main', enemy: ef, risk: .8, gain: 1.2, edge: .2);
          if (l.dead != null) return '峠の下の林に兵を伏せた。$r';
          _fame(g, 3);
          g.setFlag('cl_spy_trap');
          g.mark('城の内の間者に偽りの知らせを拾わせ、攻め寄せた敵を峠で破った');
          return '峠の下の林に兵を伏せた。油断した敵の列が、谷あいに長く延びていた。$r';
        }),
        Choice.h('城を固めて、敵が気づいて引くのを待つ', '危うさは少ない。手柄もない', () {
          _stamp(g, 'kancho');
          _fav(g, 1);
          return '城の櫓に旗を林のように立てさせた。敵は城の前まで来て、しばらく眺めたのち、引き返していった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('cl_spy_caught')) {
      g.ask('間者の仲間', '捕らえた$nを牢に入れてから、城の周りで見慣れぬ者を見かけるようになった。今朝は、あなたの寝所の縁の下に、焦げた藁束が押し込まれていた。', [
        Choice.h('$nを放ち、仲間の動きを封じる', '城の内は静まる。敵に借りを返したことになる', () {
          _stamp(g, 'kancho');
          _fav(g, -1);
          g.j(1);
          return '夜のうちに$nの縄を解き、城の裏門から出した。それきり、見慣れぬ者の姿は消えた。';
        }),
        Choice.h('番を倍にして、仲間を狩り出す', '城の威は示せる。夜道は危うくなる', () {
          _stamp(g, 'kancho');
          if (g.rng.chance(.03)) {
            g.die('捕らえた間者の仲間を狩り出していた夜、闇から放たれた手裏剣に倒れた', 'ansatsu');
            return '松明を掲げて塀の外を見回っていたとき、闇の中で何かが光った。';
          }
          _fav(g, 3);
          _fame(g, 2);
          g.setFlag('cl_spy_purged');
          return '十日のうちに、城下の宿に潜んでいた二人を捕らえた。藁束を押し込んだのは、そのうちの一人だった。';
        }),
        if (l.mi >= 60)
          Choice.h('$nに飯を与え、仕える気はないかと問う', '人柄が通じれば敵の手の内が分かる。寝首をかかれる恐れもある', () {
            _stamp(g, 'kancho');
            if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
              _fame(g, 2);
              _fav(g, 2);
              g.setFlag('cl_spy_won');
              g.mark('捕らえた間者を許して召し抱え、敵の手の内を聞き出した');
              return '$nは三日のあいだ飯に手をつけなかったが、四日目の朝、牢の格子越しに敵の陣立てを語り始めた。';
            }
            _fav(g, -2);
            return '$nは、牢番が目を離したすきに姿を消していた。床には、食べ残しの飯がそのまま残っていた。';
          }, via: '魅'),
        if (g.canFight && g.l.bu >= 60)
          Choice.h('自ら縁の下に潜み、火付けを取り押さえる', '腕があれば仲間を生け捕れる。闇の中の組み討ちだ', () {
            _stamp(g, 'kancho');
            if (g.might()) {
              _fame(g, 3);
              _fav(g, 2);
              return '三晩目の夜更け、藁束を抱えた影が這い寄ってきた。足首をつかんで引き倒し、縄をかけた。翌朝から、城の周りの見慣れぬ者は一人残らず消えた。';
            }
            _hurt(g, 6);
            return '影は思いのほか素早く、短刀で腕を裂いて塀の向こうへ消えた。藁束だけが、縁の下に残っていた。';
          }, via: '武'),
      ], after: next);
      return;
    }
    g.ask('暇を出した男', '暇を出した$nが、$enの陣中で物見の頭として働いていると、旅の商人が教えてくれた。城の水の手を知っている男だ。', [
      Choice.h('水の手の道を付け替えさせる', '城の弱みを消せる。銭と人手がかかる', () {
        _stamp(g, 'kancho');
        _pay(g, 8);
        _fav(g, 1);
        return '谷へ下る水汲みの道を、別の尾根へ付け替えさせた。古い道には、わざと柵を残しておいた。';
      }),
      Choice.h('気に病まず、捨て置く', '手間はかからない。城の内を知る者が敵にいる', () {
        _stamp(g, 'kancho');
        g.j(-1);
        return '「台所の男に、何が分かる」と笑ってみせた。それでも、夜に一度、目が覚めた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 主家の目付
  SceneDef('cl_metsuke', 24, 74, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final n = _man(g);
    g.ask('主家の目付', '${_house(g)}から、目付の$nが城へ遣わされてきた。城の兵の数と蔵の中を検めるという。あなたの城に、謀反の噂が立っているらしい。', [
      Choice.h('蔵も帳面も、すべて開いて見せる', '疑いは晴れやすい。城の内を明かすことになる', () {
        _fav(g, 5);
        g.setFlag('cl_metsuke_open');
        return '$nは三日かけて蔵と帳面を検め、「何も出ませなんだ」と書き付けて帰っていった。';
      }),
      Choice.h('$nに金子を包み、穏便に済ませてもらう', '話は早く済む。露見すれば疑いは深まる', () {
        _pay(g, 10);
        if (g.rng.chance(.12)) {
          if (g.rng.chance(.3)) {
            g.die('主家の遣わした目付に金子を包んだことが露見し、謀反の心ありとして腹を切らされた', 'seppuku');
            return '$nは、包みをそのまま主家へ持ち帰った。';
          }
          _fav(g, -15);
          return '$nは、包みをそのまま主家へ持ち帰った。弁明に、ひと冬を費やした。';
        }
        _fav(g, 1);
        g.setFlag('cl_metsuke_bribed');
        return '$nは包みを袖に入れ、「よい城でござるな」とだけ言った。検めは半日で終わった。';
      }),
      if (l.mi >= 60)
        Choice.h('$nを酒宴に招き、噂の出どころを探る', '人柄が通じれば疑いの根が分かる。軽く見られることもある', () {
          if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
            _fav(g, 4);
            _net(g, 2);
            g.setFlag('cl_metsuke_friend');
            return '酒が回ると、$nは「噂を流したのは、あなたの城を欲しがる同輩よ」と漏らした。帰り際、$nは「主家へは、よしなに申しておく」と言った。';
          }
          _fav(g, -2);
          return '$nは盃を伏せたまま、「酒で目は曇りませぬ」と言った。検めは、いつもより念入りになった。';
        }, via: '魅'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 家老として

List<SceneDef> _karoScenes() => [
  // ============================================ 筋: 主君の世継ぎ
  SceneDef('cl_yotsugi', 25, 72, (g) => _w1, (g) => clLord(g) && g.l.rank >= 6, (g, next) {
    final l = g.l;
    final a = g.rng.pick(kHeirNames);
    final b = g.rng.pick(kHeirNames.where((x) => x != a).toList());
    _keepName(g, 'cl_yt_a:', a);
    _keepName(g, 'cl_yt_b:', b);
    g.ask('主君の世継ぎ', '主君が病がちになり、家中は世継ぎの話で持ちきりだ。嫡男の$a君は温和だが、戦を好まない。弟の$b君は器量が大きく、若い侍たちが慕っている。重臣の一人として、あなたの言葉は重い。', [
      Choice.h('筋目どおり、嫡男の$a君を推す', '家中の筋は通る。若い侍たちの心は離れる', () {
        _fav(g, 3);
        g.setFlag('cl_yt_eldest');
        _stamp(g, 'yotsugi');
        return '評定の席で、「家は嫡男が継ぐもの」と言い切った。$b君を推す若い侍たちが、あなたを睨んでいた。';
      }),
      Choice.h('器量を取り、弟の$b君を推す', '家は強くなるかもしれない。嫡男方の恨みを買う', () {
        l.merit += 2;
        _fav(g, -2);
        g.setFlag('cl_yt_younger');
        _stamp(g, 'yotsugi');
        return '「乱世に要るのは器量にござる」と申し上げた。$a君の傅役の老臣は、何も言わずに席を立った。';
      }),
      Choice.h('どちらにも与せず、主君のお決めに従う', '恨みは買わない。重臣として頼りないと思われる', () {
        _fav(g, -1);
        g.setFlag('cl_yt_silent');
        _stamp(g, 'yotsugi');
        return '「殿のお心のままに」とだけ申し上げた。主君は、少し寂しそうな顔をした。';
      }),
      if (l.chi >= 60)
        Choice.h('嫡男を立て、弟君を後ろ盾に据える形を説く', '才が当たれば兄弟が並び立つ。両方から疑われることもある', () {
          _stamp(g, 'yotsugi');
          if (g.rng.chance(clampD(.4 + l.chi / 300, .4, .8))) {
            _fav(g, 5);
            l.merit += 3;
            g.setFlag('cl_yt_both');
            g.mark('主君の世継ぎを定める評定で、嫡男を立て、器量の弟君を後ろ盾に据える形を説いた');
            return '家督は$a君に、兵の采配は$b君に、と説いた。主君は長く考え、やがて「それがよい」と言った。';
          }
          _fav(g, -3);
          g.setFlag('cl_yt_silent');
          return '「二人の主を立てる気か」と、評定の席がざわめいた。あなたの言葉は、どちらの側にも届かなかった。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('cl_yotsugi_after', 28, 76, _w2, clLord, (g, next) {
    final l = g.l;
    final a = _named(g, 'cl_yt_a:', '若君');
    final b = _named(g, 'cl_yt_b:', '弟君');
    if (g.hasFlag('cl_yt_both')) {
      g.ask('兄弟の主', '主君が世を去り、$a君が家を継いだ。兵の采配を預かる$b君が、あなたのもとへ来た。「兄上は戦を知らぬ。わしに兵をすべて預けるよう、兄上に申してくれぬか」。', [
        Choice.h('二人の間に立ち、今の形を守らせる', '家は割れずに済む。$b君の不満は残る', () {
          _fav(g, 4);
          _net(g, 2);
          g.setFlag('cl_yt_kept');
          _stamp(g, 'yotsugi');
          g.mark('兄弟の主の間に立ち、家を二つに割らずに守った');
          return '$a君と$b君を一つの座敷に呼び、自ら茶を点てた。二人は口をきかなかったが、茶碗を回すことだけはした。';
        }),
        Choice.h('$b君の言い分を$a君に伝える', '弟君の信を得る。兄君の疑いを招く', () {
          _fav(g, -3);
          l.merit += 2;
          _stamp(g, 'yotsugi');
          return '$a君は話を聞き終えると、「そなたは弟の家臣か」と言った。それきり、あなたは評定で後ろの席に回された。';
        }),
      ], after: next);
      return;
    }
    final heir = g.hasFlag('cl_yt_younger') ? b : a;
    final other = g.hasFlag('cl_yt_younger') ? a : b;
    final mine = g.hasFlag('cl_yt_eldest') || g.hasFlag('cl_yt_younger');
    g.ask('若殿の代', '主君が世を去り、$heir君が家を継いだ。家督を争った$other君を担ぐ者たちが、まだ家中でくすぶっている。${mine ? '若殿は、推したあなたを頼みにしている。' : '若殿は、何も言わなかったあなたを測りかねている。'}', [
      Choice.h('若殿の側に立ち、$other君の取り巻きを遠ざける', '若殿の信は厚くなる。家中に恨みが残る', () {
        _fav(g, mine ? 6 : 3);
        _net(g, -2);
        g.setFlag('cl_yt_purged');
        _stamp(g, 'yotsugi');
        return '$other君を推した重臣たちに、遠い城の番を命じる触れを出させた。家中は静まったが、静かすぎた。';
      }),
      Choice.h('$other君を寺へ入れるよう説き、命を守る', '血は流れない。若殿は甘いと思うかもしれない', () {
        _net(g, 3);
        g.j(2);
        _fav(g, -1);
        g.setFlag('cl_yt_saved');
        _stamp(g, 'yotsugi');
        g.mark('家督を争って敗れた主君の弟君を、寺へ入れて命を救った');
        return '$other君は髪を下ろし、山寺へ入った。発つ朝、あなたにだけ「すまぬ」と言った。';
      }),
      if (l.mi >= 60)
        Choice.h('$other君を担ぐ者たちを、一人ずつ訪ねて説く', '人柄が通じれば家中が一つになる。担ぎ手と通じていると疑われることもある', () {
          _stamp(g, 'yotsugi');
          if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
            _net(g, 5);
            _fav(g, 4);
            g.setFlag('cl_yt_mended');
            g.mark('割れかけた家中を一人ずつ訪ねて説き、若殿のもとにまとめた');
            return '夜ごと、灯りを提げて屋敷を回った。ひと月のち、評定の席に、空いた座は一つもなかった。';
          }
          _fav(g, -5);
          return '若殿の耳に、「あの者が夜ごと誰かの屋敷を訪ねている」と囁く者がいた。';
        }, via: '魅'),
    ], after: next);
  }),

  // ============================================ 筋: 主君を諫める
  SceneDef('cl_isame', 25, 74, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final what = g.rng.pick([
      '勝ち目の薄い遠国への出兵を、また言い出した',
      '名物の茶道具を買い集めるため、家臣の扶持を削れと言い出した',
      '酒の席の戯れに、年若い近習を手討ちにした',
    ]);
    _keepName(g, 'cl_isame_what:', what);
    g.ask('主君の暴走', '近ごろ、主君の振る舞いが目に余る。このたびは、$what。家中の者は皆、目を伏せている。', [
      Choice.h('一人で御前に出て諫める', '主君が変われば家は救われる。逆鱗に触れれば命が危うい', () {
        _stamp(g, 'isame');
        if (g.rng.chance(.03)) {
          g.die('主君の行いを面と向かって諫め、逆鱗に触れて手討ちにされた', 'seppuku');
          return '主君の顔色が変わり、脇の太刀に手が伸びた。';
        }
        g.setFlag('cl_isame_spoke');
        if (g.rng.chance(clampD(.35 + (l.chi + l.mi) / 500 + l.fav / 400, .3, .8))) {
          _fav(g, 3);
          _fame(g, 3);
          return '主君は長く黙り込み、やがて「下がれ」と言った。翌朝、その話はなかったことになっていた。';
        }
        _fav(g, -8);
        return '「そなたまで、わしに逆らうか」。その日から、主君はあなたの顔を見ようとしなくなった。';
      }),
      Choice.h('黙って従う', '身は安泰だ。家は傾いていく', () {
        g.j(-3);
        g.setFlag('cl_isame_obeyed');
        _stamp(g, 'isame');
        return '頭を下げて座を下がった。廊下で、若い侍が恨めしげにあなたを見ていた。';
      }),
      if (l.mi >= 60)
        Choice.h('重臣たちを説いて回り、連名の諫書を出す', '人柄が通じれば主君も聞かざるを得ない。徒党を組んだと見られることもある', () {
          _stamp(g, 'isame');
          if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
            _fav(g, 2);
            _net(g, 4);
            _fame(g, 2);
            g.setFlag('cl_isame_joint');
            g.mark('主君の行いを改めるよう、重臣たちを説いて連名の諫書を差し出した');
            return '七人の重臣が名を連ねた諫書を、主君は二度読み返し、「わしが悪かった」と小さく言った。';
          }
          _fav(g, -6);
          g.setFlag('cl_isame_spoke');
          return '名を連ねると約した重臣たちは、いざとなると誰も筆を取らなかった。諫書には、あなたの名だけが残った。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('cl_isame_after', 27, 76, _w2, clLord, (g, next) {
    final l = g.l;
    if (g.hasFlag('cl_isame_obeyed')) {
      final ef = _other(g);
      final en = _otherName(g, ef);
      g.ask('負け戦の後始末', 'あのとき誰も止めなかった主君の振る舞いが、家を傾けた。$enとの戦に大敗し、主家の兵は散り散りに城へ逃げ帰ってきた。主君は、負けた責めを誰かに負わせようとしている。', [
        Choice.h('自ら責めを負うと申し出る', '家中は救われる。己の立場は危うい', () {
          _stamp(g, 'isame');
          _fav(g, -4);
          _net(g, 4);
          _fame(g, 3);
          g.setFlag('cl_isame_took_blame');
          g.mark('主君の負け戦の責めを、自ら負うと申し出た');
          return '「あのとき止めなんだのは、それがしの咎にござる」。主君は何も言わなかったが、ほかの誰も罰せられなかった。';
        }),
        Choice.h('口をつぐんでやり過ごす', '己は無事だ。誰かが代わりに罰せられる', () {
          _stamp(g, 'isame');
          g.j(-4);
          _net(g, -2);
          return '若い侍大将が一人、腹を切らされた。あのときあなたを恨めしげに見ていた、あの侍だった。';
        }),
      ], after: next);
      return;
    }
    final joint = g.hasFlag('cl_isame_joint');
    g.ask('諫めた者のその後', joint
        ? '連名の諫書から二年。主君は行いを改めたが、名を連ねた重臣たちを、どこか避けるようになった。主君の側近が、あなたにだけ「殿は、あなたを恐れておいでだ」と囁いた。'
        : '諫めてから二年。主君は、あなたを遠ざけたまま、近ごろは別の重臣ばかりを召している。家中では、あなたの城を召し上げるという噂まで立っている。', [
      Choice.h('鷹狩りの供を願い出て、二人きりで話す', '主君の心がほどければ元に戻る。こじれれば遠ざけられたままだ', () {
        _stamp(g, 'isame');
        if (g.rng.chance(clampD(.45 + l.mi / 300 + l.fav / 300, .4, .85))) {
          _fav(g, 8);
          g.setFlag('cl_isame_heard');
          g.mark('諫めて遠ざけられた主君と、鷹狩りの野で二人きりで話し、ふたたび信を得た');
          return '野の端で馬を並べたとき、主君がぽつりと「あのとき、そなたが正しかった」と言った。それきり、二人とも黙って空の鷹を見ていた。';
        }
        _fav(g, -2);
        return '主君は終日、あなたの方を一度も見なかった。帰りの道で、鷹が一羽、山へ逃げた。';
      }),
      Choice.h('城に引きこもり、務めだけを果たす', '波風は立たない。主君との溝はそのままだ', () {
        _stamp(g, 'isame');
        g.j(-2);
        return '城の政に打ち込み、主家の城へは呼ばれたときだけ上った。噂は、いつのまにか消えた。';
      }),
      Choice.h('隠居を願い出て、家督を譲る支度を始める', '身は守れる。重臣の座を手放すことになる', () {
        _stamp(g, 'isame');
        _fav(g, 3);
        g.j(1);
        _net(g, -1);
        return '隠居の願いを差し出すと、主君は「まだ早い」と言って突き返した。その声は、思いのほか柔らかかった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 縁組の交渉
  SceneDef('cl_domei', 25, 72, (g) => _w1, (g) => clLord(g) && g.l.rank >= 6, (g, next) {
    final l = g.l;
    final ef = _other(g);
    final en = _otherName(g, ef);
    _keepName(g, 'cl_domei_house:', en);
    g.ask('縁組の交渉', '主君の名代として、$enへ縁組の交渉に遣わされた。主家の姫を$enの嫡男に嫁がせ、盟を結ぶ。先方は、持参の領地を一つ多く寄越せと言ってきた。', [
      Choice.h('主家の言い分を通し、一歩も引かない', '主家の面目は守れる。話がこじれることもある', () {
        _stamp(g, 'domei');
        if (g.rng.chance(clampD(.35 + (l.chi + l.mi) / 400, .35, .8))) {
          _fav(g, 6);
          l.merit += 4;
          g.setFlag('cl_domei_done');
          g.mark('主君の名代として、他家との縁組と盟約の交渉をまとめた');
          return '三日のあいだ同じ言葉を繰り返した。四日目の朝、先方の家老が根負けしたように笑い、盟約の起請文に筆を取った。';
        }
        _fav(g, -4);
        g.setFlag('cl_domei_failed');
        return '先方の当主は「話にならぬ」と言って席を立った。縁組の話は、宙に浮いたままになった。';
      }),
      Choice.h('先方に譲り、早くまとめる', '盟は早く結べる。主家では弱腰と言われる', () {
        _stamp(g, 'domei');
        _fav(g, -1);
        l.merit += 2;
        g.setFlag('cl_domei_yielded');
        return '持参の領地を一つ足すことで、話はその日のうちにまとまった。帰りの道で、主家の重臣たちにどう申し開くかを考えた。';
      }),
      if (l.chi >= 60)
        Choice.h('先方の家老とひそかに会い、互いの人質で釣り合いを取る', '才が当たれば双方の顔が立つ。裏の取引が漏れれば疑われる', () {
          _stamp(g, 'domei');
          if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
            _fav(g, 7);
            l.merit += 5;
            _fame(g, 2);
            g.setFlag('cl_domei_done');
            g.setFlag('cl_domei_karo');
            g.mark('他家の家老とひそかに会い、縁組の釣り合いを人質で取って盟約をまとめた');
            return '夜、家老の屋敷の裏木戸から入った。領地の代わりに、互いの一門の子を預け合うことで話がついた。家老は別れ際に、「また会うこともあろう」と言った。';
          }
          _fav(g, -5);
          g.setFlag('cl_domei_failed');
          return '家老は話を聞くと、翌朝それを当主に漏らした。「名代が裏で取引を持ちかけた」と、話は主家にまで届いた。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('cl_domei_after', 28, 76, _w2, clLord, (g, next) {
    final l = g.l;
    final en = _named(g, 'cl_domei_house:', '隣国の家');
    if (g.hasFlag('cl_domei_failed')) {
      g.ask('宙に浮いた縁組', 'あなたがまとめそこねた縁組を、別の重臣が代わりにまとめた。$enとの盟は結ばれ、その重臣は主君から太刀を賜った。評定の席で、その重臣があなたの方を見て笑った。', [
        Choice.h('祝いの品を贈り、手柄を称える', '家中の和は保てる。胸の内は晴れない', () {
          _stamp(g, 'domei');
          _net(g, 3);
          g.j(-1);
          return '祝いの太刀を贈った。重臣は少し驚いた顔をして、礼の文を寄越した。';
        }),
        Choice.h('城の政に打ち込み、別の手柄で見返す', '時はかかる。張り合えば角が立つ', () {
          _stamp(g, 'domei');
          l.merit += 3;
          _net(g, -1);
          return 'その年、領内の新しい田の検分に自ら出向き、蔵入りを一割増やした。主君は、帳面を見て一度うなずいた。';
        }),
      ], after: next);
      return;
    }
    final karo = g.hasFlag('cl_domei_karo');
    g.ask('盟約の揺らぎ', '盟を結んだ$enの様子がおかしい。国境の砦に兵が集まり、嫁いだ姫からの文も途絶えた。${karo ? 'そんなおり、あのときの家老から、ひそかに使いが来た。' : '家中では、先に手を打つべしという声が上がっている。'}', [
      if (karo)
        Choice.h('家老の使いに会い、先方の内情を聞く', '盟の行方が見える。こちらの内情も漏れるかもしれない', () {
          _stamp(g, 'domei');
          _fav(g, 6);
          l.merit += 3;
          g.setFlag('cl_domei_warned');
          g.mark('かつて縁組をまとめた他家の家老から内々の知らせを受け、盟約の破れを主家に先んじて伝えた');
          return '使いは、当主が隣の家と通じ始めたこと、姫は無事であることを告げた。あなたは夜通し馬を駆けて、主君にそれを伝えた。';
        }),
      Choice.h('姫の身を案じ、迎えの使いを出すよう説く', '姫は救えるかもしれない。盟を自ら破ることになる', () {
        _stamp(g, 'domei');
        if (g.rng.chance(.55)) {
          _fav(g, 4);
          g.j(3);
          g.setFlag('cl_domei_hime');
          return '迎えの輿は、夜のうちに国境を越えた。姫は輿の中で、あなたの名を聞くと声を上げて泣いた。';
        }
        _fav(g, -3);
        return '使いは国境で追い返された。姫の消息は、それきり分からなくなった。';
      }),
      Choice.h('盟を信じて、手を打たずに待つ', '先に背いたと言われずに済む。不意を突かれるかもしれない', () {
        _stamp(g, 'domei');
        if (g.rng.chance(.5)) {
          g.j(2);
          return 'ひと月ののち、砦の兵は引き上げていった。嫁いだ姫からも、遅れて詫びの文が届いた。';
        }
        _fav(g, -4);
        _troops(g, -3);
        return '盟は、境の砦への夜討ちで破られた。あなたの城の兵も、その夜いくらか討たれた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 譜代の老臣
  SceneDef('cl_fudai', 25, 72, (g) => _w1, clLord, (g, next) {
    final l = g.l;
    final n = _man(g);
    _keepName(g, 'cl_fudai_name:', n);
    g.ask('譜代の老臣', '先々代から仕える老臣の$nが、評定であなたの献策にことごとく逆らう。「成り上がりの言うことなど」と陰で言っているとも聞く。家中の古い者たちは、$nの顔色をうかがっている。', [
      Choice.h('評定の席で、理を尽くして言い負かす', '才があれば家中が認める。老臣の面目を潰すことになる', () {
        _stamp(g, 'fudai');
        if (g.rng.chance(clampD(.4 + l.chi / 250, .4, .85))) {
          l.merit += 3;
          _fav(g, 3);
          _net(g, -2);
          g.setFlag('cl_fudai_beat');
          return '絵図を広げ、兵糧の道を一つずつ指で辿ってみせた。$nは顔を赤くして黙り込み、主君は「それでゆけ」と言った。';
        }
        _fav(g, -3);
        g.setFlag('cl_fudai_beat');
        return '$nは、古い戦の話を持ち出してあなたの言葉を遮った。古い者たちが一斉にうなずき、評定は$nの言うとおりになった。';
      }),
      Choice.h('$nの屋敷を訪ね、頭を下げて教えを請う', '老臣の心は和らぐかもしれない。侮られることもある', () {
        _stamp(g, 'fudai');
        _net(g, 2);
        g.setFlag('cl_fudai_bowed');
        return '手土産を持って屋敷を訪ねた。$nは半刻ほどあなたを待たせ、出てくると、昔の戦の話を一刻も聞かせた。帰り際、「次の評定では黙っておいてやる」とだけ言った。';
      }),
      Choice.h('主君に裁きを仰ぐ', '筋は通る。家中の溝は深くなる', () {
        _stamp(g, 'fudai');
        _fav(g, 1);
        _net(g, -1);
        g.setFlag('cl_fudai_judged');
        return '主君は二人を前に座らせ、「どちらも家の宝よ」と言っただけだった。$nは、主君の前でもあなたの方を見なかった。';
      }),
      if (l.mi >= 60)
        Choice.h('$nの孫を、自分の手元に預かって鍛えると申し出る', '人柄が通じれば一門ごと味方になる。人質を取ったと見られることもある', () {
          _stamp(g, 'fudai');
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 5);
            _fav(g, 2);
            g.setFlag('cl_fudai_grandson');
            g.mark('家中で張り合う譜代の老臣の孫を、自らの手元に預かって鍛えた');
            return '$nは長く黙っていたが、やがて孫を連れてきた。「甘やかしたら承知せぬぞ」。その声は、少し震えていた。';
          }
          _net(g, -2);
          g.setFlag('cl_fudai_judged');
          return '$nは「孫を人質に取る気か」と声を荒らげた。話は、家中に面白おかしく広まった。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('cl_fudai_end', 27, 78, _w2, clLord, (g, next) {
    final l = g.l;
    final n = _named(g, 'cl_fudai_name:', '老臣');
    final close = g.hasFlag('cl_fudai_bowed') || g.hasFlag('cl_fudai_grandson');
    g.ask('老臣の死の床', '$nが病に倒れた。もう長くはないという。$nの屋敷から、あなたを呼ぶ使いが来た。${close ? '' : '長く張り合ってきた相手だ。'}', [
      Choice.h('屋敷へ駆けつける', '最後の言葉を聞ける。何を言われるかは分からない', () {
        _stamp(g, 'fudai');
        if (close) {
          _net(g, 5);
          _fav(g, 3);
          g.setFlag('cl_fudai_entrusted');
          g.mark('長く張り合った譜代の老臣の死の床に呼ばれ、家中のことを託された');
          return '$nは痩せた手であなたの手を握り、「家中の古い者たちを、頼む」と言った。翌朝、$nは息を引き取った。古い者たちは、葬いの列であなたの後ろに並んだ。';
        }
        if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
          _net(g, 3);
          g.j(3);
          g.setFlag('cl_fudai_entrusted');
          g.mark('長く張り合った譜代の老臣の死の床に呼ばれ、家中のことを託された');
          return '$nは天井を見たまま、「わしは、おぬしが嫌いであった。だが、家にはおぬしが要る」と言った。それが最後の言葉になった。';
        }
        g.j(-2);
        return '$nは、あなたの顔を見ると目を閉じ、何も言わなかった。帰り道、あなたは長いこと馬を歩かせた。';
      }),
      Choice.h('務めを理由に、見舞いの品だけを送る', '波風は立たない。悔いが残るかもしれない', () {
        _stamp(g, 'fudai');
        g.j(-2);
        _net(g, -1);
        return '見舞いの品を届けさせた。三日のち、$nの訃報が届いた。何を言おうとしていたのかは、分からないままになった。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 主家の危機（降るか戦うか）
  SceneDef('cl_kiki', 25, 76, (g) => _w1 * (_lordWeak(g) ? 2 : .6), clLord, (g, next) {
    final l = g.l;
    final ef = _other(g);
    final en = _otherName(g, ef);
    g.ask('危機の評定', '$enの大軍が、主家の国境に迫っている。降れば家は残るが、本領の半ばを失う。戦えば、勝っても負けても家は大きく傷つく。評定は二つに割れ、主君は重臣の一人ひとりに意見を問うている。', [
      Choice.h('家の誇りにかけて戦うべしと説く', '家中の士気は上がる。負ければ家が危うい', () {
        _fame(g, 2);
        if (g.rng.chance(.5)) {
          _fav(g, 4);
          g.setFlag('cl_kiki_fight');
          return '若い侍たちが一斉に膝を打った。主君は「よう申した」と言い、陣触れの太鼓が鳴った。$enの軍は、国境の川を前にして、やがて兵を退いた。';
        }
        _fav(g, -2);
        _troops(g, -3);
        g.setFlag('cl_kiki_fight');
        return '主家は兵を出したが、国境の戦で押し返され、砦を二つ失った。誰も口には出さなかったが、評定の席であなたの言葉を覚えている者は多かった。';
      }),
      Choice.h('家を残すために、降ることを説く', '家は残せる。臆病者と陰で言われる', () {
        _fame(g, -2);
        _fav(g, 2);
        g.setFlag('cl_kiki_yield');
        return '「家が残れば、またいつか」と申し上げた。主君は目を閉じて聞き、やがて和を請う使いを出した。若い侍たちは、あなたの方を見なかった。';
      }),
      if (l.chi >= 60)
        Choice.h('和を結ぶ使者を、自ら買って出る', '才が当たれば降らずに済む。敵陣へ乗り込むことになる', () {
          if (g.rng.chance(clampD(.4 + l.chi / 300, .4, .8))) {
            _fav(g, 8);
            _fame(g, 4);
            l.merit += 4;
            g.setFlag('cl_kiki_envoy');
            g.mark('主家の危機に、自ら敵陣へ乗り込んで和を結び、本領を守った');
            return '$enの本陣で、境の砦一つと引き換えに兵を退かせる話をまとめた。帰ると、城門の前に主君自らが立っていた。';
          }
          _fav(g, -3);
          _hurt(g, 10);
          return '敵陣では門前で半日待たされ、帰りには石を投げられた。和は成らず、主家は砦を三つ差し出して降った。';
        }, via: '知'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 城主の家

List<SceneDef> _houseScenes() => [
  // ============================================ 筋: 跡取りの育て方
  SceneDef(
    'cl_atotori',
    28,
    70,
    (g) => _w1,
    (g) => clLord(g) && g.l.kids >= 1 && g.l.hasKidAged(g.year, 8, 14),
    (g, next) {
      final h = _heir(g);
      g.ask('跡取りの育て方', '跡取りの$hが、そろそろ手元を離れてもよい年頃になった。主君の城へ小姓として上げれば、主家の内を知る。寺へ預ければ、学問が身につく。城に置けば、家臣たちと共に育つ。', [
        Choice.h('城に置き、家臣たちと共に育てる', '家臣に慕われる跡取りになる。外の世を知らずに育つ', () {
          g.setFlag('cl_heir_home');
          _stamp(g, 'atotori');
          g.j(2);
          return '$hは、家臣の子らと野を駆け、馬の世話をして育った。夕餉の席で、家臣の名を一人残らず言えるようになった。';
        }),
        Choice.h('主君の城へ小姓として上げる', '主家の覚えがよくなる。主君の気まぐれに晒される', () {
          g.setFlag('cl_heir_kosho');
          _stamp(g, 'atotori');
          _fav(g, 3);
          g.j(-1);
          return '$hは、小さな肩衣を着て主家の城へ上がっていった。門の前で一度だけ振り返り、それから走って中へ入った。';
        }),
        Choice.h('名のある寺へ預け、学問をさせる', '知恵のある主になる。武骨な家臣には頼りなく見える', () {
          _pay(g, 5);
          g.setFlag('cl_heir_tera');
          _stamp(g, 'atotori');
          return '$hを山寺の学僧に預けた。初めての文には、拙い字で「寺の飯はまずい」と書いてあった。';
        }),
      ], after: next);
    },
  ),

  _chain('cl_atotori_after', 32, 76, _w2, (g) => clLord(g) && g.l.kids >= 1, (g, next) {
    final l = g.l;
    final h = _heir(g);
    if (g.hasFlag('cl_heir_kosho')) {
      g.ask('主君の側の跡取り', '主家の城で小姓を務める$hが、主君の勘気をこうむったと知らせが来た。主君の茶碗を取り落として割ったのだという。主君は、$hを城から下げよと言っている。', [
        Choice.h('自ら主家の城へ上がり、詫びる', '子は救えるかもしれない。主君の前で頭を下げることになる', () {
          _stamp(g, 'atotori');
          if (g.rng.chance(clampD(.45 + l.fav / 200, .45, .85))) {
            _fav(g, -1);
            g.setFlag('cl_heir_forgiven');
            g.mark('主君の勘気をこうむった跡取りのため、自ら主家の城へ上がって詫びた');
            return '庭先に額をつけて詫びた。主君は「親が親なら」と苦笑し、$hを許した。$hはそれから、茶碗を両手で持つようになった。';
          }
          _fav(g, -5);
          return '主君は会おうともしなかった。$hは城を下げられ、帰りの道であなたの馬の後ろを黙ってついてきた。';
        }),
        Choice.h('城に戻し、家の内で鍛え直す', '子は手元に戻る。主家の覚えは悪くなる', () {
          _stamp(g, 'atotori');
          _fav(g, -2);
          g.j(1);
          return '$hを城へ連れ帰った。その夜、$hは「父上の顔に泥を塗りました」と言って泣いた。あなたは何も言わず、背中を叩いた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('cl_heir_tera')) {
      g.ask('寺から戻った跡取り', '寺で学んだ$hが、城へ戻ってきた。書状を読み書きし、算用もできる。だが、古参の家臣たちは「槍も満足に振れぬ若殿では」と陰で言っている。', [
        Choice.h('城の帳面と書状を任せる', '跡取りの才が生きる。家臣の不満は残る', () {
          _stamp(g, 'atotori');
          l.gold += 6;
          _net(g, -1);
          g.setFlag('cl_heir_scribe');
          g.mark('寺で学んだ跡取りに、城の帳面と書状を任せた');
          return '$hは三月で城の帳面を改め、蔵の米の漏れを二つ見つけた。古参の家臣たちは、何も言わなくなった。';
        }),
        Choice.h('古参の家臣に預け、槍を仕込ませる', '家臣に認められる跡取りになる。学んだことは錆びる', () {
          _stamp(g, 'atotori');
          _net(g, 2);
          return '$hは毎朝、古参の家臣に打ち据えられて帰ってきた。それでも、夜には灯りの下で書を開いていた。';
        }),
        if (g.canFight && g.l.bu >= 60)
          Choice.h('毎朝、自ら木刀を取って稽古をつける', '腕のある親にしかできない。跡取りは、学びも槍も手放さずに済む', () {
            _stamp(g, 'atotori');
            _net(g, 2);
            _fame(g, 1);
            g.j(2);
            return '夜明けの庭で、$hと木刀を合わせた。打ち据えはしない。受け方と足の運びだけを、毎朝少しずつ。半年ののち、古参の家臣が「若殿の構えは、殿に似てきた」と言った。';
          }, via: '武'),
      ], after: next);
      return;
    }
    g.ask('家臣と育った跡取り', '城で家臣の子らと育った$hが、元服を済ませた。家臣たちは$hを慕っているが、$hは主家の城へ上がったこともなく、外の家のことを何も知らない。', [
      Choice.h('諸国を見て回る旅に出す', '広い世を知る。旅の空には危うさもある', () {
        _stamp(g, 'atotori');
        _pay(g, 5);
        if (g.rng.chance(.85)) {
          g.setFlag('cl_heir_journey');
          g.mark('城で育った跡取りを、諸国を見て回る旅に出した');
          return '一年ののち、$hは日に焼けて戻ってきた。「世の広さを知りました」と言い、京で見た町の話を夜更けまで聞かせた。';
        }
        g.j(-3);
        return '$hは途中の国で野盗に遭い、身ぐるみ剥がれて戻ってきた。命があっただけよかったと、あなたは笑ってみせた。';
      }),
      Choice.h('城に置いたまま、政を少しずつ任せる', '家臣との絆は深まる。外の家のことは知らないままだ', () {
        _stamp(g, 'atotori');
        _net(g, 3);
        return '$hに、城下の訴えを聞く役を任せた。$hは村の長たちの話を、最後まで遮らずに聞いた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 嫡男の嫁（奥方にも出る）
  SceneDef(
    'cl_yome',
    34,
    76,
    (g) => g.l.female ? _wWife : _w1,
    (g) => clLife(g) && g.l.kids >= 1 && g.l.hasKidAged(g.year, 15, 28),
    (g, next) {
      final h = _heir(g);
      final n = '${g.rng.pick(kSurnames)}家';
      g.ask('嫡男の嫁', '$hに嫁を迎える話が持ち上がった。家中の有力な家臣、$nの娘を迎えれば家中は固まる。他家の姫を迎えれば、外に後ろ盾ができる。$hには、ひそかに想う娘がいるらしい。', [
        Choice.h('家臣の$nの娘を迎える', '家中は一つにまとまる。外の後ろ盾は得られない', () {
          _net(g, 4);
          g.setFlag('cl_yome_kashin');
          return '$nは、娘の輿入れの日、門の前で何度も頭を下げた。家中の者たちが総出で、松明を掲げて迎えた。';
        }),
        Choice.h('他家の姫を迎えるよう、主君に願い出る', '外に後ろ盾ができる。家中の者は面白く思わない', () {
          _fav(g, 3);
          _net(g, -2);
          g.setFlag('cl_yome_tako');
          return '主君の取り持ちで、隣国の重臣の姫が輿入れしてきた。$nは祝いの席に、病と称して来なかった。';
        }),
        Choice.h('$hの想う娘を迎えてやる', '$hは喜ぶ。家の得にはならない', () {
          g.j(5);
          _net(g, -1);
          g.setFlag('cl_yome_love');
          g.mark('跡取りの想う娘を、家の釣り合いを問わずに嫁に迎えてやった');
          return '$hの想う娘は、城下の小さな侍の家の娘だった。祝言の夜、$hは何度もあなたの方を見て、照れたように笑った。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 筋: 長陣の留守（男の城主）
  SceneDef(
    'cl_rusu',
    24,
    70,
    (g) => _w1,
    (g) => clLord(g) && !g.l.female && g.l.married && g.l.people.containsKey('伴侶'),
    (g, next) {
      final sp = g.l.people['伴侶'];
      final w = _spouse(g);
      g.ask('留守の鍵', '主家の陣触れで、長陣に出ることになった。城の留守を誰に預けるか決めねばならない。奥方の$wは、城の奥のことなら何でも心得ている。先代から仕える老臣は、城の兵をよく知っている。', [
        Choice.h('$wに城の鍵を預ける', '奥方は張り切る。老臣たちは面白く思わない', () {
          _bond(sp, 8);
          g.setFlag('cl_rusu_wife');
          _stamp(g, 'rusu');
          return '出立の朝、$wに城の鍵の束を渡した。$wは鍵を胸に抱き、「お帰りまで、一つも失くしませぬ」と言った。';
        }),
        Choice.h('老臣に留守居を任せる', '城の守りは確かだ。奥方は少し寂しく思う', () {
          g.setFlag('cl_rusu_elder');
          _stamp(g, 'rusu');
          return '老臣は「命に代えても」と言って、太刀の柄を握った。$wは、門の前で黙って見送った。';
        }),
        Choice.h('城の表を老臣に、奥と蔵を$wに分けて預ける', '互いに目が届く。二人の間がこじれることもある', () {
          _bond(sp, 3);
          g.setFlag('cl_rusu_both');
          _stamp(g, 'rusu');
          return '老臣には兵を、$wには奥と蔵を預けた。二人は並んで頭を下げたが、目を合わせはしなかった。';
        }),
      ], after: next);
    },
  ),

  _chain(
    'cl_rusu_after',
    25,
    72,
    _w2,
    (g) => clLord(g) && !g.l.female && g.l.married && g.l.people.containsKey('伴侶'),
    (g, next) {
      final l = g.l;
      final sp = l.people['伴侶'];
      final w = _spouse(g);
      if (g.hasFlag('cl_rusu_wife')) {
        g.ask('留守のあいだのこと', '長陣から戻ると、留守のあいだに領内の村々が年貢の重さを訴えて城の門に押しかけたと聞かされた。$wは自ら門に出て、村の長たちと話をつけたという。老臣たちは「奥方が勝手に約束をした」と不満を漏らしている。', [
          Choice.h('$wの約束を、そのまま城の約束とする', '奥方の顔が立つ。老臣たちの不満は残る', () {
            _stamp(g, 'rusu');
            _bond(sp, 10);
            _net(g, 2);
            g.setFlag('cl_rusu_kept');
            g.mark('留守のあいだに村々と話をつけた奥方の約束を、そのまま城の約束とした');
            return '村の長たちを城へ呼び、$wの約したとおり、年貢をひと冬だけ延べると告げた。$wは奥で、黙って茶を淹れていた。';
          }),
          Choice.h('約束を改め、老臣たちの言い分を立てる', '家中の筋は通る。奥方の面目は潰れる', () {
            _stamp(g, 'rusu');
            _bond(sp, -10);
            _fav(g, 1);
            g.j(-2);
            return '約束は半ば取り消された。$wはそれから、城の表のことに一切口を出さなくなった。';
          }),
        ], after: next);
        return;
      }
      if (g.hasFlag('cl_rusu_both')) {
        g.ask('留守のあいだのこと', '長陣から戻ると、$wと老臣が口をきいていなかった。蔵の米を城兵に出すか出さないかで、留守のあいだに言い争ったのだという。', [
          Choice.h('二人を呼び、言い分を聞いて裁く', '家の内の筋が立つ。どちらかに恨みが残る', () {
            _stamp(g, 'rusu');
            if (g.rng.chance(clampD(.4 + (l.chi + l.mi) / 400, .4, .8))) {
              _bond(sp, 4);
              _net(g, 2);
              return '二人の言い分を最後まで聞き、蔵の米は半ばを城兵に出したことにして帳面を合わせた。老臣と$wは、帰り際に初めて目を合わせた。';
            }
            _bond(sp, -4);
            return 'どちらの言い分にも理があった。裁きは曖昧になり、二人の溝はそのまま残った。';
          }),
          Choice.h('何も言わずに、次の留守は一人に任せると決める', '騒ぎは大きくならない。二人とも納得しない', () {
            _stamp(g, 'rusu');
            g.j(-1);
            return '何も言わずにおいた。冬になって、$wがそっと「あのときは」と言いかけ、やめた。';
          }),
        ], after: next);
        return;
      }
      g.ask('留守のあいだのこと', '長陣から戻ると、留守居の老臣が城の蔵の米を、断りなく近在の村に貸し付けていた。村の飢えを見かねたのだという。$wは、「奥からは止めようがありませんでした」と言った。', [
        Choice.h('老臣の情けを認め、貸した米を城の施しとする', '村の心はつかめる。蔵は細る', () {
          _stamp(g, 'rusu');
          _pay(g, 6);
          _net(g, 3);
          return '「施しとして、取り立てるな」と命じた。老臣は、肩を落としたまま何度も頭を下げた。';
        }),
        Choice.h('老臣を叱り、米を取り立てさせる', '城の掟は守られる。老臣も村も傷つく', () {
          _stamp(g, 'rusu');
          _fav(g, 1);
          _net(g, -3);
          return '老臣は、自ら村々を回って米を取り立てた。その年の冬、老臣は病を理由に城へ上がらなくなった。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 奥方（嫁いだ女性、位5〜7）
  SceneDef('cl_w_hitojichi', 22, 70, (g) => _wWife, clWife, (g, next) {
    final l = g.l;
    final sp = l.people['伴侶'];
    final w = _spouse(g);
    g.ask('預かった妻子', '城主の$wが長陣に出るにあたり、家臣たちの妻子を城の奥に預かることになった。裏切りを防ぐための、体のいい人質だ。奥の座敷に、見知らぬ女たちと子らが不安げに身を寄せている。', [
      Choice.h('客として丁重にもてなす', '家臣たちの心はつかめる。甘いと言われることもある', () {
        _net(g, 4);
        _bond(sp, 3);
        g.j(2);
        g.setFlag('cl_w_hostages_kind');
        g.mark('城の奥に預かった家臣の妻子を、人質でなく客としてもてなした');
        return '毎朝、自ら子らの手習いを見てやった。長陣から戻った家臣たちは、妻子の顔を見るなり、あなたの方へ深く頭を下げた。';
      }),
      Choice.h('定めどおり、見張りを付けて置く', '城の掟は守られる。女たちは心を閉ざす', () {
        _fav(g, 2);
        g.j(-1);
        return '奥の廊下に番の女を置いた。預かった女たちは、ひそひそ声でしか話さなくなった。';
      }),
      if (l.mi >= 60)
        Choice.h('歌会を開き、女たちの心をほどく', '人柄が通じれば奥がまとまる。軽はずみと見られることもある', () {
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 5);
            _fame(g, 2);
            g.setFlag('cl_w_hostages_kind');
            g.setFlag('cl_w_utakai');
            g.mark('城の奥に預かった家臣の妻女たちと歌会を開き、心を通わせた');
            return '初めは誰も筆を取らなかった。三度目の会で、いちばん年若い女房が、長陣の夫を思う歌を詠んで泣いた。その夜から、奥の座敷に笑い声が聞こえるようになった。';
          }
          g.j(-1);
          return '歌会には誰も筆を取らなかった。女たちは、あなたの顔をうかがうばかりだった。';
        }, via: '魅'),
    ], after: next);
  }),

  SceneDef('cl_w_enmusubi', 24, 70, (g) => _wWife, clWife, (g, next) {
    final l = g.l;
    final n = _man(g);
    g.ask('家臣の娘の縁組', '城の家臣の娘が年頃になり、縁組の世話を頼まれた。家臣の$nは、主家の重臣の家に縁づけたいと望んでいる。だが娘は、城の若い馬廻と想い合っているらしい。', [
      Choice.h('$nの望みどおり、重臣の家に縁づける', '家臣の家は栄える。娘の心は置き去りになる', () {
        _net(g, 2);
        _fav(g, 2);
        g.j(-2);
        return '重臣の家に話を通すと、縁組はすぐにまとまった。輿入れの朝、娘はあなたに礼を言ったが、目は赤かった。';
      }),
      Choice.h('娘の想う若い馬廻に添わせる', '娘は喜ぶ。$nの顔を潰すことになる', () {
        _net(g, -1);
        g.j(3);
        g.setFlag('cl_w_matched');
        g.mark('城の家臣の娘の縁組を世話し、想い合う若侍に添わせた');
        return '$nを奥へ呼び、半日かけて説いた。$nは最後に「奥方さまがそこまで仰せなら」と折れた。祝言の席で、娘は声を上げて笑った。';
      }),
      if (l.chi >= 60 || l.mi >= 60)
        Choice.h('若い馬廻を重臣の養子に入れる段取りをつける', '才が当たれば皆の望みがかなう。手間も根回しも要る', () {
          if (g.rng.chance(clampD(.4 + (l.chi > l.mi ? l.chi : l.mi) / 300, .4, .8))) {
            _net(g, 5);
            _fame(g, 2);
            g.setFlag('cl_w_matched');
            g.mark('家臣の娘の想う若侍を重臣の養子に入れ、家の望みと娘の想いを共にかなえた');
            return '重臣の奥方に文を重ね、跡継ぎのない一門に若い馬廻を養子に入れる話をまとめた。$nは、狐につままれたような顔で祝言の席に座っていた。';
          }
          _net(g, -2);
          return '根回しの文が途中で漏れ、重臣の家から「奥方の差し出口」と苦情が来た。話は、振り出しに戻った。';
        }, via: '知魅'),
    ], after: next);
  }),
];
