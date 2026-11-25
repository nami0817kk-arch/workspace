import 'adult.dart';
import 'childhood.dart';
import 'game.dart';
import 'history_lines.dart';
import 'peace.dart';
import 'rng.dart';

/// 知で身を立てる道（2026-11-25、ユーザー「知で上り詰めることは可能？」→ 案の4つすべて）。id・旗は `sc_`。
///
/// 前は出世に要る功がほぼ合戦でしか入らず、知の高さは出世にまったく効いていなかった
/// （毎年「学問に励む」を選ぶと城主に届くのは成人の0.9%）。知で功を積み、位を上がれる道を四つ足した。
///
/// 1. **祐筆の口**（`sc_yuhitsu`）: 身分のない知60以上の人に、近くの家から「書き物を任せたい」と声がかかる。
///    学問を続けた年が多いほど来やすい。仕えると、役方（`sc_bun`）として位1から始まる。
/// 2. **献策する**（重点 `sc_kensaku`）: 仕える身で知40以上の人の重点。知が高いほど功が入り、外れれば主君の信頼が下がる。
///    選んだ年の一部で評定の岐路（`sc_council`）が起きる。泰平の世でも選べる。
/// 3. **役方の道**（`sc_bugyo`）: 戦える侍（位2〜5）で知58以上の人に、奉行に推される岐路。受けると `sc_bun`。
///    役方の人は、昇進に兵の数が要らず、代わりに知の目安（[kBunChi]）が要る。合戦の手柄は少なくなる（[scholarBattleGain]）。
///    家老から上では讒言を受ける岐路（`sc_slander`）があり、しくじると失脚し、まれに腹を切らされる。
/// 4. **軍師**（`sc_gunshi`）: 知75以上の戦える侍（位3〜7）に、陣の采配を任せたいという岐路。受けると合戦の強さが
///    武ではなく武と知の高いほうで決まり（[scholarBattleBu]）、手柄も少し増える。
///
/// 位は直接は上げない（祐筆の口で位1になるのを除く）。昇進は `Game` の毎年の昇進のまま。

/// 役方の人が、その位に上がるのに要る知（兵の数の代わり）。キーは「なる先の位」。
const kBunChi = <int, int>{2: 0, 3: 50, 4: 58, 5: 66, 6: 72, 7: 78};

/// 役方の道にいる（祐筆の口で仕えた人か、奉行に推されて受けた人）。
bool scBun(Game g) => g.hasFlag('sc_bun');

/// 陣の采配を任された（軍師）。
bool scGunshi(Game g) => g.hasFlag('sc_gunshi');

/// 昇進の兵の条件の代わりに、知の目安で上がれるか（役方の人だけ）。
bool scholarPromoOk(Game g, int to) => scBun(g) && g.l.chi >= (kBunChi[to] ?? 99);

/// 合戦の強さに使う武（軍師は武と知の高いほう）。
int scholarBattleBu(Game g) =>
    scGunshi(g) && g.l.chi > g.l.bu ? g.l.chi : g.l.bu;

/// 合戦の手柄に掛ける倍率（軍師は少し増え、役方の人は少なくなる）。
double scholarBattleGain(Game g) => scGunshi(g)
    ? 1.15
    : scBun(g)
    ? .7
    : 1;

/// 役方の男の位の呼び名（城主から上はいつもの呼び名）。
const kBunRanksM = <int, String>{1: '書役', 2: '祐筆', 3: '奉行衆', 4: '奉行'};

/// 画面に出す位の呼び名（役方の男だけ、位1〜4を役方の呼び名にする）。
String scholarRankName(Game g, int r) =>
    !g.l.female && scBun(g) && kBunRanksM.containsKey(r) ? kBunRanksM[r]! : g.rk[r];

bool _serving(Game g) {
  final l = g.l;
  return l.rank >= 1 &&
      l.rank <= 7 &&
      l.lord != null &&
      (g.fa[l.lord]?.alive ?? false) &&
      g.active &&
      !g.hasFlag('priesthood');
}

// ======================================================================
// 献策する（重点）
// ======================================================================

/// 献策の重点が出る身（仕える位1〜7・知40以上）。
bool scKensakuCan(Game g) => !g.isChild && _serving(g) && g.l.chi >= 40;

/// 献策が通る見込み（知が高いほど通る）。
double scKensakuChance(Game g) => clampD(.35 + g.l.chi / 220, .3, .85);

List<FocusDef> scholarFocusOptions(Game g) {
  if (!scKensakuCan(g)) return const [];
  final l = g.l;
  return [
    FocusDef(
      'sc_kensaku',
      l.female ? '奥の務めに知恵を絞る' : '献策する',
      l.female ? '知恵が奥方さまの役に立てば、覚えがめでたくなる。外れれば、目は冷える' : '知恵で手柄を立てる。策が外れれば、主君の目は冷える',
      (g) {
        if (g.rng.chance(scKensakuChance(g))) {
          l.merit += l.chi ~/ 7 + g.rng.range(1, 3);
          l.fav = clampInt(l.fav + g.rng.range(2, 4), 0, 100);
          if (g.rng.chance(.3)) l.fame += 1;
        } else {
          l.merit += 2;
          l.fav = clampInt(l.fav - g.rng.range(2, 5), 0, 100);
        }
        if (l.chi < 90 && g.rng.chance(.3)) l.chi++;
      },
      forced: 'sc_council',
    ),
  ];
}

/// 献策の年に評定の岐路が起きる見込み（起きない年は、ふつうの年と同じく岐路を引く）。
const kCouncilChance = .35;

void _council(Game g, void Function() next) {
  if (!g.rng.chance(kCouncilChance) || !_serving(g)) {
    g.usualYearScene();
    return;
  }
  final l = g.l;
  final house = houseName(g, l.lord);
  final peace = peaceTime(g);
  final head = l.female
      ? '$house家の奥で、奥方さまが家中の揉めごとに頭を抱えている。知恵を求められた。'
      : peace
      ? '$house家の評定で、領内の年貢と普請の割り振りが決まらない。意見を求められた。'
      : '$house家の評定で、次の戦の手立てが割れている。意見を求められた。';
  g.ask(l.female ? '奥の相談' : '評定', head, [
    Choice.h('思い切った策を説く', '通れば大きな手柄。外れれば、主君の目は冷える', () {
      if (g.rng.chance(clampD(.25 + l.chi / 200, .2, .75))) {
        l.merit += 12 + l.chi ~/ 10;
        l.fav = clampInt(l.fav + 6, 0, 100);
        l.fame += 3;
        g.j(4);
        g.setFlag('sc_bold_won');
        return '一座が黙り込んだあと、主君が膝を打った。策はそのまま用いられた。';
      }
      l.fav = clampInt(l.fav - 8, 0, 100);
      g.j(-3);
      return '策は退けられた。「理屈ばかりの者よ」と陰で囁かれた。';
    }),
    Choice.h('手堅い策を出す', '手柄は小さい。外れることは少ない', () {
      l.merit += 4 + l.chi ~/ 12;
      l.fav = clampInt(l.fav + 2, 0, 100);
      return '誰もが頷ける手立てを述べた。地味だが、主君は覚えておいてくれた。';
    }),
    if (l.mi >= 55)
      Choice.h('同輩の策を立て、裏で手を入れる', '手柄は人に譲る。家中の受けはよくなる', () {
        l.merit += 4;
        l.net += 2;
        l.fav = clampInt(l.fav + 3, 0, 100);
        g.setFlag('sc_gave_credit');
        return '同輩の策の穴を、評定の前にそっと埋めておいた。同輩は何度も礼を言いに来た。';
      }, via: '魅'),
  ], after: () => _thenUsual(g, next));
}

// ======================================================================
// 祐筆の口
// ======================================================================

/// 祐筆の口が来うる身（身分なし・知60以上・仏門・商い・野の道でない）。
bool scYuhitsuCan(Game g) {
  final l = g.l;
  return !g.isChild &&
      l.rank == 0 &&
      l.chi >= 60 &&
      g.active &&
      !g.hasFlag('priesthood') &&
      !g.hasFlag('way_merchant') &&
      !g.hasFlag('way_outlaw') &&
      !g.hasFlag('sc_yuhitsu_no');
}

/// 祐筆の口の重み（学問を続けた年が多いほど来やすい）。
double scYuhitsuWeight(Game g) {
  // 学問を選んだことのない人にはほとんど来ない（庶民の生業・百姓の人生を、侍の家へ引き抜きすぎないため）。
  final n = g.l.focus['study'] ?? 0;
  if (n < 2) return .3;
  return 2 + (n > 10 ? 10 : n) * 2.5;
}

void _yuhitsu(Game g, void Function() next) {
  final l = g.l;
  final lord = homeLord(g);
  final house = houseName(g, lord);
  g.ask(
    l.female ? '奥の祐筆' : '祐筆の口',
    l.female
        ? '$house家の奥から使いが来た。字が書け、物の分かる女を、奥方さまの文の書き役に迎えたいという。'
        : '$house家の家老から使いが来た。学問の評判を聞いた、書状と帳面を任せたい、という。槍ではなく、筆で仕える口だ。',
    [
      Choice.h('筆で仕える', '身分を得る。知恵で上がっていく道だ', () {
        l
          ..rank = 1
          ..lord = lord
          ..fav = 25
          ..ronin = false;
        if (l.maxRank < 1) l.maxRank = 1;
        g.setFlag('sc_bun');
        g.setFlag('sc_yuhitsu');
        g.j(5);
        g.mark(l.female ? '学問を買われ、$house家の奥の書き役に迎えられた' : '学問を買われ、$house家の書き役に取り立てられた');
        return '$house家に、書き役として仕えることになった。';
      }),
      Choice.h('今はまだ学びたい', '口は断る。また声がかかるかはわからない', () {
        g.setFlag('sc_yuhitsu_no');
        return '「まだ学び足りませぬ」と、使いに頭を下げた。';
      }),
    ],
    after: next,
  );
}

// ======================================================================
// 役方の道（奉行に推される）と讒言
// ======================================================================

bool scBugyoCan(Game g) =>
    _serving(g) &&
    g.l.rank >= 2 &&
    g.l.rank <= 5 &&
    g.l.chi >= 58 &&
    !scBun(g) &&
    !g.hasFlag('sc_bugyo_no');

void _bugyo(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  final what = peaceTime(g) ? '勘定と普請を預かる奉行' : '兵糧と年貢を預かる奉行';
  g.ask('奉行の推挙', '$house家の家老が、あなたを$whatに推したいと言ってきた。槍働きからは遠のくが、帳面と裁きで家を支える役だ。', [
    Choice.h('奉行の役を受ける', '兵を集めずとも知恵で上がれる。戦の手柄は少なくなる', () {
      g.setFlag('sc_bun');
      g.setFlag('sc_bugyo');
      l.fav = clampInt(l.fav + 4, 0, 100);
      g.mark('$house家の奉行に推され、役方の道に入った');
      return '槍を蔵に納め、帳面の山の前に座った。';
    }),
    Choice.h('槍働きにとどまる', '役は断る。これまでどおり戦で身を立てる', () {
      g.setFlag('sc_bugyo_no');
      return '「まだ槍で働きとうございます」と断った。';
    }),
  ], after: next);
}

/// 讒言の岐路が出る身（役方で家老から上、主家に仕えている）。
bool scSlanderCan(Game g) => _serving(g) && scBun(g) && g.l.rank >= 6;

void _slander(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('役方への妬み', '槍で身を立てた古株たちが、「帳面で私腹を肥やしている」と$house家の主君に言い立てた。呼び出しがかかった。', [
    Choice.h('帳面を揃えて申し開く', '筋が通れば疑いは晴れる。しくじれば役を追われ、腹を切らされることもある', () {
      if (g.rng.chance(clampD(.45 + l.chi / 250 + l.sei / 400, .4, .9))) {
        l.fav = clampInt(l.fav + 3, 0, 100);
        g.setFlag('sc_cleared');
        return '一冊ずつ帳面を開いて見せた。古株たちは口をつぐみ、主君は頷いた。';
      }
      if (g.rng.chance(.12)) {
        g.die('役方の不正を問われ、腹を切らされた', 'seppuku');
        return '申し開きは聞き入れられなかった。';
      }
      l.fav = clampInt(l.fav - 20, 0, 100);
      l.merit = l.merit - 40 < 0 ? 0 : l.merit - 40;
      g.j(-8);
      g.setFlag('sc_fallen');
      return '申し開きは通らず、役を取り上げられた。しばらく出仕も差し止められた。';
    }),
    if (l.mi >= 55)
      Choice.h('古株の頭を訪ね、膝を詰める', '話が通れば、言い立てごと消える。こじれれば恨みが残る', () {
        if (g.rng.chance(.4 + l.mi / 250)) {
          l.net += 2;
          g.setFlag('sc_cleared');
          return '酒を下げて古株の頭を訪ね、夜更けまで話した。言い立ては取り下げられた。';
        }
        l.fav = clampInt(l.fav - 8, 0, 100);
        return '頭は会ってはくれたが、話は物別れに終わった。';
      }, via: '魅'),
    Choice.h('役を返上して身を引く', '命と家は守れる。知恵で上がる道は閉じる', () {
      l.flags.remove('sc_bun');
      l.fav = clampInt(l.fav - 3, 0, 100);
      g.j(-3);
      g.setFlag('sc_resigned');
      return '自ら役を返上した。帳面の山は、別の者の机へ移った。';
    }),
  ], after: next);
}

// ======================================================================
// 軍師
// ======================================================================

bool scGunshiCan(Game g) =>
    _serving(g) &&
    g.canFight &&
    g.l.rank >= 3 &&
    g.l.chi >= 75 &&
    !scGunshi(g) &&
    !peaceTime(g) &&
    !g.hasFlag('sc_gunshi_no');

void _gunshi(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('采配の預かり', '$house家の主君が、陣立てを任せられる者を探している。評定での見立ての確かさが、主君の耳に届いたらしい。', [
    Choice.h('陣の采配を預かる', '戦で知恵が物を言うようになる。負ければ責めも負う', () {
      g.setFlag('sc_gunshi');
      l.fav = clampInt(l.fav + 5, 0, 100);
      l.fame += 4;
      g.mark('$house家の陣立てを任される身となった');
      return '主君から采配を預かった。次の戦からは、陣の絵図を引くのはあなたの役だ。';
    }),
    Choice.h('一介の将のままでいる', '役は断る。何も変わらない', () {
      g.setFlag('sc_gunshi_no');
      return '「その器ではございませぬ」と辞した。';
    }),
  ], after: next);
}

// ======================================================================
// 登録
// ======================================================================

List<SceneDef> buildScholarScenes() => [
  SceneDef(
    'sc_council',
    15,
    99,
    (g) => 1,
    scKensakuCan,
    _council,
    repeat: true,
    onlyForced: true,
  ),
  SceneDef('sc_yuhitsu', 15, 50, scYuhitsuWeight, scYuhitsuCan, _yuhitsu),
  SceneDef('sc_bugyo', 18, 60, (g) => 10, scBugyoCan, _bugyo),
  SceneDef('sc_slander', 25, 80, (g) => 6, scSlanderCan, _slander),
  SceneDef('sc_gunshi', 20, 65, (g) => 9, scGunshiCan, _gunshi),
];

void _thenUsual(Game g, void Function() next) =>
    g.finished ? next() : g.usualYearScene();
