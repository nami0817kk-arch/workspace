import 'adult.dart';
import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'peace.dart';
import 'rng.dart';
import 'scholar.dart';

/// 政・魅・運で身を立てる道（2026-11-25、ユーザー「他のステータスはどう？」→ 案の3つすべて）。
///
/// 知の道（`scholar.dart`）と同じく、能力が高いほど出世に効くようにした。前は 15歳の能力で分けても、
/// 城主以上に届く割合は 40未満と60以上で5〜8ポイントしか違わなかった。
///
/// - **政の道**（`ms_`）: 重点「所領の仕置きをする」（位1から、政で功と銭）／代官の口（身分なし・政65から）／
///   勘定頭の推挙（戦える位1〜5・政55から。仕置きを選んだ年が多いほど来やすい。受けると `ms_kanjo` で、昇進に兵の代わりに政の目安 [kBunChi] が要る）／
///   商人の士分への取り立て（政65からの御用商人か大店）／蔵の不正の疑い（勘定頭で家老から）。重く取りすぎた年貢は一揆を呼ぶ。
/// - **魅の道**（`mj_`）: 重点「人を集める」（銭を払わずに郎党が集まる＝侍の昇進に要る兵）／重点「敵方の将を調略する」
///   （戦の世・位3から・魅55から。功が大きい。しくじれば斬られることも）／主君の側近（魅60から。毎年信頼と功が積もる）／
///   代替わりで遠ざけられる岐路。
/// - **運の道**（`mu_`）: 重点「運を天に任せる」（一か八かの手柄。外れれば信頼と銭を失い、まれに命も）／
///   巡り合わせ（運75から、一生に二度まで。主君の窮地に居合わせ、位が二つ上がることも。身分なしなら取り立て）。
///
/// 新しい `die()` は三つ（調略の先で斬られる・抜け駆けで討たれる・蔵の不正で腹を切らされる）。

bool _serving(Game g) {
  final l = g.l;
  return !g.isChild &&
      l.rank >= 1 &&
      l.rank <= 7 &&
      l.lord != null &&
      (g.fa[l.lord]?.alive ?? false) &&
      g.active &&
      !g.hasFlag('priesthood');
}

bool _freeCommoner(Game g) {
  final l = g.l;
  return !g.isChild &&
      l.rank == 0 &&
      g.active &&
      !g.hasFlag('priesthood') &&
      !g.hasFlag('way_outlaw');
}

void _thenUsual(Game g, void Function() next) =>
    g.finished ? next() : g.usualYearScene();

int _stamp(Game g, String key) {
  for (final f in g.l.flags) {
    if (f.startsWith('$key@')) return int.tryParse(f.substring(key.length + 1)) ?? -999;
  }
  return -999;
}

// ======================================================================
// 政の道
// ======================================================================

/// 勘定頭の道にいる（代官の口で仕えた人・勘定頭に推されて受けた人・士分に取り立てられた商人）。
bool msKanjo(Game g) => g.hasFlag('ms_kanjo');

/// 勘定頭の人が、兵の代わりに政の目安で上がれるか（目安は知の道と同じ表）。
bool msPromoOk(Game g, int to) => msKanjo(g) && g.l.sei >= (kBunChi[to] ?? 99);

/// 勘定頭の男の位の呼び名。
const kKanjoRanksM = <int, String>{1: '小役人', 2: '勘定方', 3: '代官', 4: '郡奉行'};

bool msShiokiCan(Game g) => _serving(g) && g.l.rank >= 1 && g.l.sei >= 40;

double msShiokiChance(Game g) => clampD(.35 + g.l.sei / 220, .3, .85);

void _shiokiYear(Game g) {
  final l = g.l;
  if (g.rng.chance(msShiokiChance(g))) {
    l.merit += l.sei ~/ 7 + g.rng.range(1, 3);
    l.gold += l.sei ~/ 8;
    l.fav = clampInt(l.fav + g.rng.range(2, 4), 0, 100);
  } else {
    l.merit += 2;
    l.fav = clampInt(l.fav - g.rng.range(2, 5), 0, 100);
  }
  if (l.sei < 90 && g.rng.chance(.5)) l.sei++;
}

void _kura(Game g, void Function() next) {
  if (!g.rng.chance(.35) || !msShiokiCan(g)) {
    g.usualYearScene();
    return;
  }
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('年貢の割り付け', '$house家から預かった村々の、今年の年貢を決める時が来た。実りは並だ。', [
    Choice.h('重く取って蔵を満たす', '主家の蔵は膨らむ。村の恨みも積もる', () {
      l.merit += 6;
      l.gold += 10;
      if (g.hasFlag('ms_heavy') && g.rng.chance(.35)) {
        l.fav = clampInt(l.fav - 12, 0, 100);
        l.merit = l.merit - 15 < 0 ? 0 : l.merit - 15;
        g.j(-6);
        g.setFlag('ms_ikki');
        return '重ねた取り立てに、村々が一揆を起こした。鎮めるのに手間取り、主君の目は冷えた。';
      }
      g.setFlag('ms_heavy');
      return '例年より一割重く取った。蔵は満ちたが、村からの挨拶はなかった。';
    }),
    Choice.h('例年どおりに取る', '波風は立たない。手柄も小さい', () {
      l.merit += 3;
      return '例年どおりの割り付けで済ませた。';
    }),
    if (l.sei >= 60)
      Choice.h('田ごとに実りを見て割り付け直す', '手間はかかる。年貢も村の信も上がる', () {
        l.merit += 8;
        l.fav = clampInt(l.fav + 3, 0, 100);
        l.flags.remove('ms_heavy');
        g.setFlag('ms_fair');
        return '田を一枚ずつ見て回り、割り付けを直した。年貢は増え、村の不満は減った。';
      }, via: '政'),
  ], after: () => _thenUsual(g, next));
}

bool msDaikanCan(Game g) =>
    _freeCommoner(g) &&
    g.l.sei >= 65 &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('ms_daikan_no');

void _daikan(Game g, void Function() next) {
  final l = g.l;
  final lord = homeLord(g);
  final house = houseName(g, lord);
  g.ask('代官の口', '$house家の奉行が村へ来た。年貢の勘定が誰より確かだと聞いた、村々を預かる代官の下で働かぬか、という。', [
    Choice.h('勘定で仕える', '身分を得る。帳面で上がっていく道だ', () {
      l
        ..rank = 1
        ..lord = lord
        ..fav = 25
        ..ronin = false;
      if (l.maxRank < 1) l.maxRank = 1;
      g.setFlag('ms_kanjo');
      g.j(5);
      g.mark('勘定の腕を買われ、$house家の代官の下で働いた');
      return '$house家に、勘定の役として仕えることになった。';
    }),
    Choice.h('村にとどまる', '口は断る。二度と来ないかもしれない', () {
      g.setFlag('ms_daikan_no');
      return '「村を離れるわけにはまいりませぬ」と断った。';
    }),
  ], after: next);
}

bool msKanjoOfferCan(Game g) =>
    _serving(g) &&
    g.canFight &&
    g.l.rank >= 1 &&
    g.l.rank <= 5 &&
    g.l.sei >= 55 &&
    !msKanjo(g) &&
    !scBun(g) &&
    !g.hasFlag('ms_kanjo_no');

void _kanjoOffer(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('勘定頭の推挙', '$house家の蔵の帳尻が合わず、家老が頭を抱えている。勘定に明るいあなたに、蔵と年貢を預けたいという。', [
    Choice.h('勘定頭の役を受ける', '兵を集めずとも政で上がれる。戦の手柄は少なくなる', () {
      g.setFlag('ms_kanjo');
      l.fav = clampInt(l.fav + 4, 0, 100);
      g.mark('$house家の蔵と年貢を預かる身となった');
      return '槍を置き、蔵の鍵を預かった。';
    }),
    Choice.h('槍働きにとどまる', '役は断る。これまでどおり戦で身を立てる', () {
      g.setFlag('ms_kanjo_no');
      return '「勘定は性に合いませぬ」と断った。';
    }),
  ], after: next);
}

bool msShibunCan(Game g) =>
    !g.isChild &&
    g.l.rank == 0 &&
    g.active &&
    g.hasFlag('way_merchant') &&
    g.l.sei >= 65 &&
    (g.hasFlag('goyo') || g.l.gold >= 300) &&
    !g.hasFlag('ms_shibun_no');

void _shibun(Game g, void Function() next) {
  final l = g.l;
  final lord = homeLord(g);
  final house = houseName(g, lord);
  g.ask('士分の誘い', '$house家の家老が店に来た。蔵の切り盛りを任せたい、ついては刀を差し、家中に加われという。', [
    Choice.h('刀を差して仕える', '商いを離れ、武家の勘定方になる。もう町人には戻れない', () {
      l
        ..rank = 2
        ..lord = lord
        ..fav = 30
        ..ronin = false;
      if (l.maxRank < 2) l.maxRank = 2;
      l.flags.remove('way_merchant');
      g.setFlag('ms_kanjo');
      g.setFlag('ms_shibun');
      g.j(4);
      g.mark('商いを離れ、$house家に士分として迎えられた');
      return '暖簾を番頭に譲り、$house家の勘定方として刀を差した。';
    }),
    Choice.h('商いを続ける', '話は断る。店はこのまま', () {
      g.setFlag('ms_shibun_no');
      return '「手前は商人でございます」と、丁重に断った。';
    }),
  ], after: next);
}

bool msSuspectCan(Game g) => _serving(g) && msKanjo(g) && g.l.rank >= 6;

void _suspect(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('蔵の疑い', '$house家の蔵から米が消えている、という訴えが出た。蔵を預かるあなたに目が向いている。', [
    Choice.h('帳面と蔵を開いて見せる', '筋が通れば疑いは晴れる。しくじれば役を追われ、腹を切らされることもある', () {
      if (g.rng.chance(clampD(.45 + l.sei / 250 + l.chi / 400, .4, .9))) {
        l.fav = clampInt(l.fav + 3, 0, 100);
        g.setFlag('ms_cleared');
        return '蔵役人の一人が米を横に流していたのを、帳面から突き止めた。';
      }
      if (g.rng.chance(.12)) {
        g.die('蔵の米を掠めたと問われ、腹を切らされた', 'seppuku');
        return '申し開きは通らなかった。';
      }
      l.fav = clampInt(l.fav - 20, 0, 100);
      l.merit = l.merit - 40 < 0 ? 0 : l.merit - 40;
      g.j(-8);
      g.setFlag('ms_fallen');
      return '疑いは晴れず、蔵の鍵を取り上げられた。';
    }),
    Choice.h('蔵の鍵を返して身を引く', '命と家は守れる。政で上がる道は閉じる', () {
      l.flags.remove('ms_kanjo');
      l.fav = clampInt(l.fav - 3, 0, 100);
      g.setFlag('ms_resigned');
      return '自ら蔵の鍵を返した。';
    }),
  ], after: () => _thenUsual(g, next));
}

// ======================================================================
// 魅の道
// ======================================================================

/// 主君の側近（毎年、主君の信頼と功が積もる）。
bool mjKinju(Game g) => g.hasFlag('mj_kinju');

bool mjGatherCan(Game g) =>
    _serving(g) &&
    g.canFight &&
    g.l.rank >= 2 &&
    g.l.mi >= 40 &&
    g.l.troops < kTroopCap[g.l.rank.clamp(0, kTroopCap.length - 1)];

void _gatherYear(Game g) {
  final l = g.l;
  final cap = kTroopCap[l.rank.clamp(0, kTroopCap.length - 1)];
  var n = l.mi ~/ 12 + g.rng.range(0, 2);
  if (l.troops + n > cap) n = cap - l.troops;
  if (n > 0) l.troops += n;
  l.net += 1;
  if (l.mi < 90 && g.rng.chance(.3)) l.mi++;
}

bool mjChoryakuCan(Game g) =>
    _serving(g) && g.l.rank >= 3 && g.l.mi >= 55 && !peaceTime(g) && g.alive.length > 2;

void _choryaku(Game g, void Function() next) {
  final l = g.l;
  final me = l.lord!;
  final foes = nearest(g.alive.where((f) => f.name != me), (f) => f.name, faction: me, n: 3);
  if (foes.isEmpty) {
    g.usualYearScene();
    return;
  }
  final foe = foes[g.rng.range(0, foes.length - 1)];
  final en = houseName(g, foe.name);
  final p = clampD(.25 + l.mi / 200, .2, .75);
  g.ask('調略', '$en家の国境の将が、主家に不満を抱いているらしい。寝返らせる手立てを考える。', [
    Choice.h('膝を詰めて口説く', '通れば大きな手柄。しくじれば、その場で斬られることもある', () {
      if (g.rng.chance(p)) {
        l.merit += 8 + l.mi ~/ 10;
        l.fav = clampInt(l.fav + 5, 0, 100);
        l.fame += 3;
        foe.power = foe.power * .95 < 3 ? 3 : foe.power * .95;
        g.setFlag('mj_turned');
        return '夜更けまで語り合い、将は寝返りを約した。$en家の国境が一つ崩れた。';
      }
      if (g.rng.chance(.04)) {
        g.die('$en家の将を調略に赴き、斬られた', 'ansatsu');
        return '将は話を聞くふりをして、刀を抜いた。';
      }
      l.fav = clampInt(l.fav - 4, 0, 100);
      return '将は首を縦に振らなかった。手ぶらで戻った。';
    }),
    Choice.h('文と贈り物で誘う', '危うさは少ない。通る見込みも低い', () {
      if (l.gold >= 8) l.gold -= 8;
      if (g.rng.chance(p * .6)) {
        l.merit += 8 + l.mi ~/ 12;
        l.fav = clampInt(l.fav + 3, 0, 100);
        return '贈り物が効いた。将から内通の返事が届いた。';
      }
      return '返事は来なかった。';
    }),
    Choice.h('今は時でないと見送る', '何も起きない', () => '動くのは、もう少し様子を見てからにした。'),
  ], after: () => _thenUsual(g, next));
}

bool mjKinjuCan(Game g) =>
    _serving(g) && g.l.rank >= 2 && g.l.rank <= 6 && g.l.mi >= 60 && !mjKinju(g) && !g.hasFlag('mj_kinju_no');

void _kinju(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask(l.female ? '奥方さまのお側' : '主君のお側', l.female
      ? '$house家の奥方さまが、あなたを気に入られた。お側で取り次ぎを務めよ、という。'
      : '$house家の主君が、あなたを側近くに召したいと言う。人あたりのよさを買われたらしい。', [
    Choice.h('お側に上がる', '主君の覚えはめでたくなる。妬む者も出る', () {
      g.setFlag('mj_kinju');
      g.setFlag('mj_kinju@${g.year}');
      l.fav = clampInt(l.fav + 8, 0, 100);
      g.mark(l.female ? '$house家の奥方のお側で取り次ぎを務めた' : '$house家の主君の側近くに仕えた');
      return 'お側に上がった。主君の声が、近くで聞こえるようになった。';
    }),
    Choice.h('今の務めにとどまる', '話は断る。何も変わらない', () {
      g.setFlag('mj_kinju_no');
      return '「その器ではございませぬ」と辞した。';
    }),
  ], after: next);
}

bool mjPurgeCan(Game g) => _serving(g) && mjKinju(g) && g.year - _stamp(g, 'mj_kinju') >= 8;

void _purge(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  g.ask('側近の行く末', '$house家に新しい側近たちが現れ、古いお側の者は遠ざけられ始めた。あなたにも冷たい目が向く。', [
    Choice.h('新しい側近たちにも取り入る', '縁が通れば、お側にとどまれる。しくじれば遠ざけられる', () {
      if (g.rng.chance(clampD(.3 + l.mi / 200, .3, .8))) {
        l.net += 2;
        return '新しい側近たちとも酒を酌み交わし、居場所を保った。';
      }
      l.flags.remove('mj_kinju');
      l.fav = clampInt(l.fav - 12, 0, 100);
      g.j(-5);
      return '取り入る隙はなかった。お側を下がるよう言い渡された。';
    }),
    Choice.h('自らお側を下がる', '信頼は少し下がる。妬みからは離れられる', () {
      l.flags.remove('mj_kinju');
      l.fav = clampInt(l.fav - 4, 0, 100);
      return '自ら願い出て、お側を下がった。';
    }),
  ], after: next);
}

// ======================================================================
// 運の道
// ======================================================================

bool muKakeCan(Game g) => _serving(g) && g.l.un >= 40;

void _kake(Game g, void Function() next) {
  final l = g.l;
  final house = houseName(g, l.lord);
  final war = !peaceTime(g) && g.canFight;
  g.ask('一か八か', war
      ? '$house家の陣で、敵の備えに隙が見えた。誰も動かない。いま出れば手柄は大きいが、命の保証はない。'
      : '$house家の評定で、誰もが二の足を踏む難しい役が回ってきた。', [
    Choice.h(war ? '抜け駆けして斬り込む' : '難しい役を買って出る',
        war ? '当たれば大きな手柄。外れれば咎めを受け、討たれることもある' : '当たれば大きな手柄。外れれば、主君の目は冷える', () {
      if (g.luck(.25)) {
        l.merit += 18 + l.un ~/ 8;
        l.fav = clampInt(l.fav + 5, 0, 100);
        l.fame += 4;
        g.j(5);
        g.setFlag('mu_won');
        return war ? '敵の備えはまさに崩れかけていた。一番乗りの手柄を立てた。' : '役は思いのほか滞りなく済んだ。主君は膝を打った。';
      }
      if (war && g.rng.chance(.03)) {
        g.die('抜け駆けして敵陣に斬り込み、討たれた', 'senshi');
        return '隙に見えたのは、敵の誘いだった。';
      }
      l.fav = clampInt(l.fav - 8, 0, 100);
      l.gold = (l.gold * .85).floor();
      g.j(-4);
      return war ? '斬り込んだ先は敵の固い備えだった。からくも逃げ帰り、軍令違反を咎められた。' : '役はしくじった。後始末に蔵の銭も出した。';
    }, via: '運'),
    Choice.h('手堅く務める', '手柄は小さい。外れることも少ない', () {
      l.merit += 4;
      return 'いつもどおり、手堅く務めた。';
    }),
  ], after: () => _thenUsual(g, next));
}

bool _meguriCan(Game g, String id, String? prev) {
  final l = g.l;
  if (g.isChild || !g.active || g.hasFlag('priesthood') || l.un < 75) return false;
  if (prev != null && (!g.hasFlag('scene:$prev') || g.year - _stamp(g, 'mu_meguri') < 5)) return false;
  if (l.rank == 0) return !g.hasFlag('way_outlaw') && !g.hasFlag('way_merchant');
  return _serving(g) && l.rank <= 6;
}

void _meguri(Game g, void Function() next) {
  final l = g.l;
  l.flags.removeWhere((f) => f.startsWith('mu_meguri@'));
  g.setFlag('mu_meguri@${g.year}');
  if (l.rank == 0) {
    final lord = homeLord(g);
    final house = houseName(g, lord);
    g.ask('巡り合わせ', '街道で、落馬した武士を助け起こした。$house家の重臣だった。「礼がしたい。わしの家に来ぬか」', [
      Choice.h('重臣の家に仕える', '身分を得る。運が開けた', () {
        l
          ..rank = 2
          ..lord = lord
          ..fav = 30
          ..ronin = false;
        if (l.maxRank < 2) l.maxRank = 2;
        g.j(8);
        g.mark('街道で$house家の重臣を助け、取り立てられた');
        return '$house家に取り立てられた。';
      }),
      Choice.h('礼は受けずに去る', '何も変わらない', () => '名も告げずに立ち去った。'),
    ], after: next);
    return;
  }
  final house = houseName(g, l.lord);
  g.ask('巡り合わせ', '$house家の主君が、わずかな供で出た先で曲者に襲われた。たまたま居合わせたのは、あなただけだ。', [
    Choice.h('主君を背に庇う', '命を救えば、取り立ては大きい。こちらも無傷では済まない', () {
      l.hp -= g.rng.range(5, 15);
      final to = l.rank + 2 > 7 ? 7 : l.rank + 2;
      final up = to - l.rank;
      l.rank = to;
      if (l.maxRank < to) l.maxRank = to;
      l.fav = clampInt(l.fav + 15, 0, 100);
      l.fame += 6;
      g.j(10);
      g.mark('曲者から$house家の主君を庇い、取り立てられた');
      return '曲者を追い払い、主君は無事だった。その場で、位を$up段引き上げると言い渡された。';
    }),
    Choice.h('人を呼びに走る', '危うさは少ない。手柄も小さい', () {
      l.merit += 6;
      l.fav = clampInt(l.fav + 3, 0, 100);
      return '番の者を呼びに走った。主君は無事だった。';
    }),
  ], after: next);
}

// ======================================================================
// 入り口と登録
// ======================================================================

/// 毎年の効き（側近は信頼と功が積もる）。`Game._endAdultYear` から。
void abilityWaysYear(Game g) {
  if (mjKinju(g) && _serving(g)) {
    g.l.fav = clampInt(g.l.fav + 2, 0, 100);
    g.l.merit += g.l.mi ~/ 15;
  }
}

/// 昇進の兵の条件の代わり（知の役方と、政の勘定頭）。
bool abilityPromoOk(Game g, int to) => scholarPromoOk(g, to) || msPromoOk(g, to);

/// 次の昇進の一行に出す、兵の代わりの目安（知か政。どちらでもなければ null）。
String? abilityPromoLine(Game g, int to) {
  final need = kBunChi[to];
  if (need == null) return null;
  if (msKanjo(g)) return '政${g.l.sei}/$need';
  if (scBun(g)) return '知${g.l.chi}/$need';
  return null;
}

/// 画面に出す位の呼び名（勘定頭と役方の男だけ、位1〜4を役の呼び名にする）。
String abilityRankName(Game g, int r) {
  if (!g.l.female && msKanjo(g) && kKanjoRanksM.containsKey(r)) return kKanjoRanksM[r]!;
  return scholarRankName(g, r);
}

/// 合戦の手柄の倍率（勘定頭も役方と同じく少なくなる）。
double abilityBattleGain(Game g) =>
    scGunshi(g) ? scholarBattleGain(g) : (msKanjo(g) ? .7 : scholarBattleGain(g));

List<FocusDef> abilityFocusOptions(Game g) => [
  if (msShiokiCan(g))
    FocusDef('ms_shioki', '所領の仕置きをする', '年貢と蔵を整え、手柄にする。読み違えれば主君の目は冷える', _shiokiYear, forced: 'ms_kura'),
  if (mjGatherCan(g))
    FocusDef('mj_gather', '人を集める', '銭を払わずとも、慕って人が集まる。顔も広くなる', _gatherYear),
  if (mjChoryakuCan(g))
    FocusDef('mj_choryaku', '敵方の将を調略する', '口説き落とせば大きな手柄。しくじれば、斬られることもある', (g) {}, forced: 'mj_choryaku'),
  if (muKakeCan(g))
    FocusDef('mu_kake', '運を天に任せる', '一か八かの手柄を狙う。外れれば、失うものも大きい', (g) {}, forced: 'mu_kake'),
];

List<SceneDef> buildAbilityWayScenes() => [
  SceneDef('ms_kura', 15, 99, (g) => 1, msShiokiCan, _kura, repeat: true, onlyForced: true),
  SceneDef('ms_daikan', 16, 50, (g) => 1.5, msDaikanCan, _daikan),
  SceneDef('ms_kanjo', 16, 60, (g) => 10 + (g.l.focus['ms_shioki'] ?? 0) * 4.0, msKanjoOfferCan, _kanjoOffer),
  SceneDef('ms_shibun', 20, 60, (g) => 5, msShibunCan, _shibun),
  SceneDef('ms_suspect', 25, 80, (g) => 6, msSuspectCan, _suspect),
  SceneDef('mj_choryaku', 15, 80, (g) => 1, mjChoryakuCan, _choryaku, repeat: true, onlyForced: true),
  SceneDef('mj_kinju', 16, 60, (g) => 8, mjKinjuCan, _kinju),
  SceneDef('mj_purge', 25, 80, (g) => 5, mjPurgeCan, _purge),
  SceneDef('mu_kake', 15, 80, (g) => 1, muKakeCan, _kake, repeat: true, onlyForced: true),
  SceneDef('mu_meguri', 15, 70, (g) => 4, (g) => _meguriCan(g, 'mu_meguri', null), _meguri),
  SceneDef('mu_meguri2', 20, 75, (g) => 4, (g) => _meguriCan(g, 'mu_meguri2', 'mu_meguri'), _meguri),
];
