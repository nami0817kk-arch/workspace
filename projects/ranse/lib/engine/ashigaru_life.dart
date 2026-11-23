import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 足軽・雑兵の暮らしの岐路（2026-11-23）。id・旗は `al_`。
///
/// 足軽（位1〜2）の固有の岐路は `ashigaru.dart` の8つ（長屋・博打・乱取り・朋輩の死・長槍・恩賞・逃げ散る夜・国への便り）と、
/// 出陣のたびの合戦の状況（`battles.dart`）だけだったので、陣中の暮らし・戦の前後・身の振り方を足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kAshigaruPrev]）。段を踏んだ年は
/// 旗 `al_at:<筋>:<年>` に残し、次の段は何年か空けてから出す（[kAshigaruGap]）。
///
/// - 兵糧の筋: 兵糧の配り → くすねた者には兵糧の詮議／正しく配った者には米蔵の番。
/// - 組頭の筋: 新しい組頭の目 → 気に入られた者には偽りの証の頼み、睨まれた者には危うい物見 → 組頭の後釜。
/// - 同郷の筋: 同じ村から出た者たちとの誓い → 抜け駆け → 村へ帰るか（戻らなかった仲間の母を訪ねる手も）。
/// - 鉄砲の筋（一五五〇年から）: 鉄砲組に回される → 雨の鉄砲 → 長篠のあと（一五七六年から）若い者に撃ち方を教える。
/// - 古参の筋: 古参の足軽の心得 → 古参の暇 → 自分が若い足軽に伝える。
/// - 前のファイルの旗から: 乱取りに加わった者（`randori`）には人買い、乱取りで村人を逃がした者（`spared_village`）には
///   落ち延びる道で匿われる手。主家が滅んで降った足軽（`game.dart` の `lordLost` が立てる `al_kuragae`）には降った先の暮らし。
/// - ひとつきり: 首実検・不寝番・陣中の腹の病・褒美の田（一五八九年まで）・足軽大将への取り立て・
///   帰農（一五八八年の刀狩の前と後で意味が変わる。刀狩の起きない世では前のまま）・牢人の暮らし（足軽あがりで主を失った者）・落ち延びる道。
/// - 能力（武・知・政・魅・運）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

/// 足軽・雑兵として仕えている男（位1〜2・戦える・隠居でない・主家が生きている）。
bool alServing(Game g) =>
    !g.l.female &&
    g.l.rank >= 1 &&
    g.l.rank <= 2 &&
    g.canFight &&
    g.active &&
    !g.hasFlag('priesthood') &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 足軽あがりで、いまは身分のない男（最高位が足軽か足軽組頭）。
bool alFormer(Game g) =>
    !g.l.female &&
    g.l.rank == 0 &&
    g.l.maxRank >= 1 &&
    g.l.maxRank <= 2 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw');

/// この岐路が出てよい人（どちらかに当たる）。テストも使う。
bool alLife(Game g) => alServing(g) || alFormer(g);

bool _farmBorn(Game g) => const ['farmer', 'fisher'].contains(g.l.cls.id);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kAshigaruPrev = <String, List<String>>{
  'al_hyoro_audit': ['al_hyoro_skim'],
  'al_hyoro_trust': ['al_hyoro_fair', 'al_hyoro_ledger', 'al_hyoro_confessed'],
  'al_kumi_witness': ['al_kumi_liked'],
  'al_kumi_harsh': ['al_kumi_glare'],
  'al_kumi_fate': ['al_false_witness', 'al_kumi_tact', 'al_kumi_endured', 'al_kumi_appealed'],
  'al_murato_rash': ['al_murato_vow'],
  'al_murato_home': ['al_murato_held', 'al_murato_together', 'al_murato_lost'],
  'al_teppo_rain': ['al_teppo_yes'],
  'al_teppo_teach': ['al_teppo_yes'],
  'al_kosan_end': ['al_kosan_taught'],
  'al_kosan_teach': ['al_kosan_seen_off', 'al_kosan_kept', 'al_kosan_parted'],
  // 前のファイル・仕組みの旗から出る段（空ける年はない）。
  'al_hitokai': ['randori'],
  'al_kuragae': ['al_kuragae'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kAshigaruGap = <String, (String, int)>{
  'al_hyoro_audit': ('hyoro', 1),
  'al_hyoro_trust': ('hyoro', 1),
  'al_kumi_witness': ('kumi', 1),
  'al_kumi_harsh': ('kumi', 1),
  'al_kumi_fate': ('kumi', 1),
  'al_murato_rash': ('murato', 1),
  'al_murato_home': ('murato', 2),
  'al_teppo_rain': ('teppo', 1),
  'al_teppo_teach': ('teppo', 1),
  'al_kosan_end': ('kosan', 2),
  'al_kosan_teach': ('kosan', 1),
};

/// この岐路の id（テストが使う）。
const kAshigaruLifeIds = [
  'al_hyoro',
  'al_hyoro_audit',
  'al_hyoro_trust',
  'al_kumi_eye',
  'al_kumi_witness',
  'al_kumi_harsh',
  'al_kumi_fate',
  'al_murato',
  'al_murato_rash',
  'al_murato_home',
  'al_hitokai',
  'al_teppo',
  'al_teppo_rain',
  'al_teppo_teach',
  'al_kubi',
  'al_fuyoban',
  'al_ekiri',
  'al_kosan',
  'al_kosan_end',
  'al_kosan_teach',
  'al_kuragae',
  'al_onsho_ta',
  'al_toritate',
  'al_kino',
  'al_ronin',
  'al_ochiru',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('al_at:$chain:'));
  g.setFlag('al_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int alSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('al_at:$chain:')) {
      return g.year - int.parse(f.substring('al_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool alChainReady(Game g, String id) {
  final prev = kAshigaruPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kAshigaruGap[id];
  if (gap == null) return true;
  return alSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _lose(Game g, double rate) => g.l.gold = (g.l.gold * (1 - rate)).floor();
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

/// 旗 `<頭><名>` から名を取り出す。なければ [fallback]。
String _named(Game g, String head, String fallback) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return fallback;
}

/// 主家に近い敵の家（内部の名）。いなければ null。
String? _enemy(Game g) {
  final lf = g.l.lord;
  if (lf == null) return null;
  final c = nearest(g.alive.where((f) => f.name != lf), (f) => f.name, faction: lf, n: 3);
  return c.isEmpty ? null : g.rng.pick(c).name;
}

/// 足軽をやめて身分のない身になる（村へ帰る・牢人になる）。
void _leave(Game g, {required bool ronin}) {
  final l = g.l;
  l.rank = 0;
  l.lord = null;
  l.troops = 0;
  l.ronin = ronin;
}

/// 主家の勢いが、近い敵より弱いか（負け戦の場面が出やすい）。
bool _lordWeak(Game g) {
  final lord = g.l.lord;
  final lf = lord == null ? null : g.fa[lord];
  if (lf == null) return false;
  final near = nearest(g.alive.where((f) => f.name != lord), (f) => f.name, faction: lord, n: 3);
  return near.any((f) => f.power > lf.power);
}

/// 重み。筋の始まり・ひとつきりは [_w1]、前の段を踏んだ人だけに出る後段は [_w2]。
const _w1 = 6.0;
const _w2 = 30.0;

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
  (g) => who(g) && alChainReady(g, id),
  run,
);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildAshigaruLifeScenes() => [
  ..._campScenes(),
  ..._battleSideScenes(),
  ..._courseScenes(),
];

// ---------------------------------------------------------------- 陣中の暮らし

List<SceneDef> _campScenes() => [
  // ============================================ 筋: 兵糧
  SceneDef('al_hyoro', 16, 55, (g) => _w1, alServing, (g, next) {
    final l = g.l;
    g.ask('兵糧の配り', '小荷駄の奉行に言いつけられ、組の者たちに兵糧を配ることになった。米俵の前に、腹を空かせた足軽たちが列をつくっている。', [
      Choice.h('枡を正しく量る', '誰からも恨まれない。取り分は増えない', () {
        l.net += 1;
        g.setFlag('al_hyoro_fair');
        _stamp(g, 'hyoro');
        return '枡のふちを棒でならし、一人ずつ同じだけ配った。文句を言う者はいなかった。';
      }),
      Choice.h('組頭の分を多めに盛る', '組頭の覚えはよくなる。朋輩は見ている', () {
        l.fav = _c(l.fav + 4);
        l.net = l.net >= 1 ? l.net - 1 : 0;
        _stamp(g, 'hyoro');
        return '組頭の椀にだけ、山盛りによそった。後ろの列から、舌打ちが聞こえた。';
      }),
      Choice.h('少しずつくすねて売る', '銭になる。帳尻が合わなければ咎めを受ける', () {
        l.gold += g.rng.range(3, 6);
        g.j(-2);
        g.setFlag('al_hyoro_skim');
        _stamp(g, 'hyoro');
        return '俵の底から少しずつ抜いた米を、陣に来る商人に売った。';
      }),
      if (l.sei >= 60)
        Choice.h('帳面をつけながら配る', '手間はかかる。勘定のできる者は目に留まる', () {
          l.fav = _c(l.fav + 3);
          l.merit += 3;
          g.setFlag('al_hyoro_ledger');
          _stamp(g, 'hyoro');
          g.mark('陣中の兵糧の配りを、帳面をつけて取り仕切った');
          return '誰に何合を渡したか、帳面に書きつけていった。小荷駄の奉行が、帳面を覗き込んでうなった。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('al_hyoro_audit', 18, 50, _w2, alServing, (g, next) {
    final l = g.l;
    g.ask('兵糧の詮議', '小荷駄の米が帳面より少ないと、奉行が詮議を始めた。足軽たちが一人ずつ呼ばれていく。次は、あなたの番だ。', [
      Choice.h('白を切る', '言い逃れられるかもしれない。目の利く奉行には通じない', () {
        l.flags.remove('al_hyoro_skim');
        _stamp(g, 'hyoro');
        if (g.rng.chance(clampD(.5 + l.chi / 250 + l.un / 500, .35, .85))) {
          return '「存じませぬ」と言い通した。奉行は長いこと顔を見ていたが、やがて次の者を呼んだ。';
        }
        if (g.rng.chance(.06)) {
          g.die('兵糧をくすねた咎を問われ、陣の外れで首を打たれた', 'seppuku');
          return '奉行は黙って、背後の侍に目で合図した。';
        }
        l.fav = _c(l.fav - 10);
        l.hp -= 10;
        _lose(g, .5);
        g.setFlag('al_hyoro_caught');
        return '嘘は見抜かれた。棒で打たれ、くすねた分の倍を取り立てられた。';
      }),
      Choice.h('名乗り出て詫びる', '罰は受ける。命まではとられまい', () {
        l.flags.remove('al_hyoro_skim');
        l.fav = _c(l.fav - 6);
        _lose(g, .4);
        g.j(-2);
        g.setFlag('al_hyoro_confessed');
        _stamp(g, 'hyoro');
        return '奉行は「正直は買う」と言い、扶持を削るだけで許した。';
      }),
      Choice.h('朋輩に罪を着せる', '自分は助かる。着せられた者の目は忘れられない', () {
        l.flags.remove('al_hyoro_skim');
        l.net = l.net >= 3 ? l.net - 3 : 0;
        g.j(-8);
        g.setFlag('al_hyoro_framed');
        _stamp(g, 'hyoro');
        return '朋輩が棒で打たれ、陣を追われていった。振り返った目が、あなたを見ていた。';
      }),
    ], after: next);
  }),

  _chain('al_hyoro_trust', 18, 50, _w2, alServing, (g, next) {
    final l = g.l;
    g.ask('米蔵の番', '兵糧の配りぶりを見ていた小荷駄の奉行が、陣の米蔵の番を任せたいと言ってきた。槍を振るう場からは、少し遠のく。', [
      Choice.h('引き受ける', '信は厚くなる。戦場での手柄は遠のく', () {
        l.fav = _c(l.fav + 6);
        l.merit += 4;
        l.gold += 3;
        g.setFlag('al_kura_ban');
        _stamp(g, 'hyoro');
        g.mark('小荷駄の奉行に見込まれ、陣の米蔵の番を任された');
        return '米蔵の鍵を腰に下げた。夜ごと鼠の音に耳を澄ます役目だが、扶持は少し増えた。';
      }),
      Choice.h('槍の組に残る', '手柄の道は開いたままだ。奉行は残念がる', () {
        l.bu = _c(l.bu + 1);
        _stamp(g, 'hyoro');
        return '奉行は「惜しいな」と笑い、ほかの者に鍵を渡した。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 組頭
  SceneDef('al_kumi_eye', 16, 50, (g) => _w1, (g) => alServing(g) && g.l.rank == 1, (g, next) {
    final l = g.l;
    g.ask('組頭の目', '組に新しい組頭が来た。気の荒い男で、初日から足軽を一人、棒で打ち据えた。誰に目をかけ、誰を睨むか、皆が息をひそめて見ている。', [
      Choice.h('付け届けをする', '覚えはよくなる。銭は減る', () {
        _pay(g, 3);
        l.fav = _c(l.fav + 5);
        g.setFlag('al_kumi_liked');
        _stamp(g, 'kumi');
        return '干し魚と酒を届けると、組頭は「気が利くな」と目を細めた。';
      }),
      Choice.h('槍の腕を見せる', '腕が立てば認められる。しくじれば笑い者だ', () {
        _stamp(g, 'kumi');
        if (g.rng.chance(clampD(.3 + l.bu / 150, .3, .9))) {
          l.fav = _c(l.fav + 4);
          l.bu = _c(l.bu + 1);
          g.setFlag('al_kumi_liked');
          return '稽古で組頭の槍を三度払った。組頭は唸り、「名は何という」と聞いた。';
        }
        g.j(-3);
        g.setFlag('al_kumi_glare');
        return '組頭に槍を叩き落とされ、皆の前で転がされた。組頭は鼻で笑った。';
      }),
      Choice.h('打たれた者をかばって諫める', '朋輩の信は得る。組頭には睨まれる', () {
        l.net += 3;
        g.j(2);
        g.setFlag('al_kumi_glare');
        _stamp(g, 'kumi');
        return '「打つほどのことではございませぬ」と言うと、組頭の目が、じっとこちらに据わった。';
      }),
      Choice.h('黙って従う', '目立たずに済む。何も変わらない', () {
        _stamp(g, 'kumi');
        return '目を伏せて、嵐が過ぎるのを待った。';
      }),
    ], after: next);
  }),

  _chain('al_kumi_witness', 17, 45, _w2, alServing, (g, next) {
    final l = g.l;
    g.ask('組頭の頼み', '組頭に呼ばれた。「先の戦で、わしが兜首を取ったのを見たな」。見てはいない。首は、討たれた朋輩が取ったものだった。', [
      Choice.h('見たと証す', '組頭の覚えはめでたい。死んだ朋輩の手柄は消える', () {
        l.fav = _c(l.fav + 6);
        l.merit += 3;
        g.j(-6);
        g.setFlag('al_false_witness');
        _stamp(g, 'kumi');
        return '首帳には、組頭の名が記された。その夜、討たれた朋輩の顔が浮かんで眠れなかった。';
      }),
      Choice.h('見ていないと言う', '筋は通る。組頭の目は冷たくなる', () {
        l.fav = _c(l.fav - 6);
        g.j(3);
        l.flags.remove('al_kumi_liked');
        g.setFlag('al_kumi_refused');
        g.setFlag('al_kumi_glare');
        _stamp(g, 'kumi');
        return '組頭は黙って背を向けた。翌日から、あなたにだけ声をかけなくなった。';
      }),
      if (l.mi >= 60)
        Choice.h('朋輩の名を添えて証す', '角は立たない。口のうまさが要る', () {
          l.fav = _c(l.fav + 2);
          l.net += 2;
          g.setFlag('al_kumi_tact');
          _stamp(g, 'kumi');
          return '「組頭と、討たれた朋輩が共に取った首」と申し立てた。組頭は苦い顔をしたが、何も言わなかった。朋輩の家には恩賞の米が届いた。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('al_kumi_harsh', 17, 45, _w2, alServing, (g, next) {
    final l = g.l;
    g.ask('睨まれた足軽', '組頭は、危うい役目ばかりをあなたに回すようになった。今夜も、敵陣の近くまで物見に出よという。', [
      Choice.h('黙って務める', '腕と度胸は認められる。夜の物見は命がけだ', () {
        _stamp(g, 'kumi');
        if (g.rng.chance(.04)) {
          g.die('組頭に回された危うい物見の役目で、敵の矢を受けて果てた', 'senshi');
          return '闇の中で、弓の弦の鳴る音がした。';
        }
        l.bu = _c(l.bu + 1);
        l.merit += 4;
        g.setFlag('al_kumi_endured');
        return '敵の篝火の数を数えて戻った。組頭は舌打ちしたが、侍大将の耳にあなたの名が届いた。';
      }),
      Choice.h('侍大将に訴え出る', '筋が通れば組頭が咎められる。通らなければ組にいられない', () {
        _stamp(g, 'kumi');
        if (g.rng.chance(clampD(.35 + (l.chi + l.mi) / 400, .3, .8))) {
          l.fav = _c(l.fav + 3);
          g.setFlag('al_kumi_appealed');
          g.mark('理不尽な組頭を、侍大将に訴え出た');
          return '侍大将は話を聞き、組頭を呼びつけた。それきり、危うい役目はほかの者にも回るようになった。';
        }
        l.fav = _c(l.fav - 8);
        g.j(-4);
        return '「足軽の分際で」と一喝されただけだった。組頭の目は、いっそう冷たくなった。';
      }),
      Choice.h('仮病で役目を逃れる', '今夜は助かる。臆病者と言われる', () {
        l.fame -= 2;
        g.j(-2);
        _stamp(g, 'kumi');
        return '腹を押さえてうずくまった。代わりに出た朋輩が、明け方に青い顔で戻ってきた。';
      }),
    ], after: next);
  }),

  _chain('al_kumi_fate', 20, 50, _w2, alServing, (g, next) {
    final l = g.l;
    // 足軽のうちは組頭の後釜、すでに組頭なら、いくつもの組を束ねる足軽頭の後釜。
    final kumi = l.rank == 1;
    final text = kumi
        ? '組頭が先の戦で深手を負い、陣を去ることになった。侍大将が組の者を見渡して「後を任せられる者はおるか」と言った。'
        : 'いくつもの組を束ねてきた足軽頭が、先の戦で深手を負い、陣を去ることになった。侍大将が組頭たちを見渡して「後を任せられる者はおるか」と言った。';
    g.ask(kumi ? '組頭の後釜' : '足軽頭の後釜', text, [
      Choice.h('名乗り出る', '組を率いる身になれるかもしれない。妬む者も出る', () {
        _stamp(g, 'kumi');
        final p = .4 + l.fav / 200 + (g.hasFlag('al_kumi_endured') ? .15 : 0);
        if (l.merit >= 10 && g.rng.chance(clampD(p, .3, .9))) {
          g.j(6);
          g.setFlag('al_kumi_head');
          if (kumi) {
            l.rank = 2;
            if (l.maxRank < 2) l.maxRank = 2;
            l.merit += 3;
            g.mark('組頭の後を継ぎ、足軽組頭に取り立てられた');
            return '侍大将は「やってみよ」と言った。その日から、組の者があなたの指図で動いた。';
          }
          l.merit += 8;
          l.fame += 3;
          l.fav = _c(l.fav + 4);
          g.mark('足軽頭の後を継ぎ、いくつもの組を預かった');
          return '侍大将は「やってみよ」と言った。いくつもの組の足軽たちが、あなたの采配を待つようになった。';
        }
        g.j(-3);
        return '侍大将は、ほかの者を選んだ。';
      }),
      Choice.h('朋輩を推す', '恨みは買わない。組はまとまる', () {
        l.net += 3;
        g.j(2);
        g.setFlag('al_kumi_backed');
        _stamp(g, 'kumi');
        return kumi
            ? '腕の立つ朋輩を推した。新しい組頭は、何かとあなたに相談するようになった。'
            : '古株の組頭を推した。新しい足軽頭は、何かとあなたに相談するようになった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 古参
  SceneDef('al_kosan', 16, 40, (g) => _w1, alServing, (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('古参の足軽', '組に、幾度もの戦を生き延びたという古参の足軽、$nがいる。歯の抜けた口で「長生きの心得を教えてやろうか」と笑った。', [
      Choice.h('教えを乞う', '生き延びる知恵が身につく。手柄の立て方とは違う', () {
        g.meet('古参の足軽', n, 55);
        l.flags.removeWhere((f) => f.startsWith('al_kosan_name:'));
        g.setFlag('al_kosan_name:$n');
        g.setFlag('al_kosan_taught');
        l.un = _c(l.un + 1);
        l.bu = _c(l.bu + 1);
        _stamp(g, 'kosan');
        return '「前に出すぎず、遅れすぎず。槍は突くより叩け。腹が減ったら、まず草鞋を直せ」。$nは、そう言って笑った。';
      }),
      Choice.h('笑って聞き流す', '若い血は止まらない。年寄りの話は退屈だ', () {
        g.j(1);
        _stamp(g, 'kosan');
        return '「年寄りの話は長い」と笑って立ち去った。$nは、何も言わずに草鞋を編んでいた。';
      }),
    ], after: next);
  }),

  _chain('al_kosan_end', 20, 45, _w2, (g) => alServing(g) && g.l.people.containsKey('古参の足軽'), (g, next) {
    final l = g.l;
    final p = l.people['古参の足軽']!;
    g.ask('古参の足軽の暇', '${p.name}が膝を痛め、槍を持てなくなった。組頭は扶持を打ち切って暇を出すという。帰る村も、もうないらしい。', [
      Choice.h('自分の銭で村まで送る', '恩は返せる。銭と日数がかかる', () {
        _pay(g, 4);
        g.j(5);
        l.people.remove('古参の足軽');
        g.setFlag('al_kosan_seen_off');
        _stamp(g, 'kosan');
        g.mark('暇を出された古参の足軽を、己の銭で縁者の村まで送り届けた');
        return '遠縁の者がいるという山あいの村まで、${p.name}を背負うようにして歩いた。別れ際、「よう生き延びたな」と肩を叩かれた。';
      }),
      Choice.h('組頭に掛け合い、小荷駄の番に回してもらう', '老いた身にも役目が残る。組頭に借りができる', () {
        l.fav = _c(l.fav - 3);
        p.bond = clampInt(p.bond + 10, 0, 100);
        g.setFlag('al_kosan_kept');
        _stamp(g, 'kosan');
        return '組頭は渋い顔をしたが、荷駄の番ならと折れた。${p.name}は黙って頭を下げた。';
      }),
      Choice.h('別れの酒を酌み交わす', '心は通う。その先は知れない', () {
        g.j(2);
        l.people.remove('古参の足軽');
        g.setFlag('al_kosan_parted');
        _stamp(g, 'kosan');
        return '陣小屋の隅で、濁り酒を分け合った。翌朝、${p.name}の寝床はもう空だった。';
      }),
    ], after: next);
  }),

  _chain('al_kosan_teach', 22, 60, _w2, alServing, (g, next) {
    final l = g.l;
    final master = _named(g, 'al_kosan_name:', '古参の足軽');
    g.ask('若い足軽', '初めて陣に来た若い足軽が、槍を逆さに持って震えている。いつかの自分を見るようだった。$masterの言葉が、口をついて出かけた。', [
      Choice.h('教わった心得を伝える', '若い者は生き延びるかもしれない。教える者になる', () {
        g.meet('若い足軽', g.rng.pick(kGivenM), 50);
        l.net += 2;
        g.j(4);
        g.setFlag('al_kosan_passed');
        _stamp(g, 'kosan');
        g.mark('古参の足軽に教わった心得を、若い足軽に伝えた');
        return '「前に出すぎず、遅れすぎず」。言いながら、$masterの抜けた歯を思い出して、少し笑った。';
      }),
      Choice.h('自分で学べと突き放す', '甘やかさない。若い者は自分で道を探す', () {
        g.j(-1);
        _stamp(g, 'kosan');
        return '「槍の持ち方くらい、見て覚えろ」と言った。若い足軽は、唇を噛んでうなずいた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり
  SceneDef('al_fuyoban', 16, 55, (g) => _w1, alServing, (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('不寝番', '野陣の不寝番に立った夜更け、隣の持ち場の$nが槍を抱いたまま眠り込んでいた。不寝番の居眠りは、見つかれば重い咎めになる。', [
      Choice.h('小突いて起こし、黙っておく', '朋輩に恩を売れる。見つかれば二人とも咎めを受ける', () {
        if (g.rng.chance(.15)) {
          l.fav = _c(l.fav - 5);
          l.hp -= 5;
          return '起こしたところを組頭に見つかり、二人並んで棒で打たれた。';
        }
        l.net += 2;
        g.setFlag('al_covered_sleeper');
        return '$nは飛び起きて、拝むように手を合わせた。';
      }),
      Choice.h('組頭に告げる', '掟どおりだ。朋輩には恨まれる', () {
        l.fav = _c(l.fav + 4);
        l.net = l.net >= 3 ? l.net - 3 : 0;
        g.setFlag('al_reported_sleeper');
        return '$nは扶持を削られた。それから、あなたと目を合わせなくなった。';
      }),
      Choice.h('二つの持ち場を一人で見張る', '夜は長い。体はこたえる', () {
        l.hp -= 6;
        l.fav = _c(l.fav + 2);
        return '東の空が白むまで、二つの持ち場を行き来した。$nは何も知らずに目を覚ました。';
      }),
    ], after: next);
  }),

  SceneDef('al_ekiri', 16, 60, (g) => _w1, alServing, (g, next) {
    final l = g.l;
    g.ask('陣中の腹の病', '長い陣で、腹を下す者が相次いだ。汚れた川の水を飲んだ者から倒れていく。陣小屋には、うめき声が満ちている。', [
      Choice.h('倒れた者の世話をする', '朋輩は救われる。病をもらうかもしれない', () {
        if (g.rng.chance(.04)) {
          g.die('陣に流行った腹の病を看取るうち、自らも倒れた', 'byo');
          return '三日目の夜、あなたも起き上がれなくなった。';
        }
        l.net += 3;
        l.mi = _c(l.mi + 1);
        g.setFlag('al_nursed_camp');
        if (g.rng.chance(.3)) {
          l.hp -= 12;
          return '粥を運び、汚れた筵を替えた。やがて自分も腹を下したが、どうにか持ち直した。';
        }
        return '粥を運び、汚れた筵を替えた。起き上がれるようになった朋輩が、黙って頭を下げた。';
      }),
      if (l.chi >= 55)
        Choice.h('水を沸かしてから飲めと説く', '知恵があれば病は広がらない。聞かぬ者もいる', () {
          l.fav = _c(l.fav + 4);
          l.merit += 3;
          g.setFlag('al_boiled_water');
          g.mark('陣に病が流行ったとき、水を沸かして飲むよう説いて回った');
          return '鍋で沸かした湯を冷まして飲ませた。倒れる者は目に見えて減り、組頭が侍大将に話を上げた。';
        }, via: '知'),
      Choice.h('離れた所で寝起きする', '病はもらいにくい。薄情と言われる', () {
        l.net = l.net >= 1 ? l.net - 1 : 0;
        return '陣小屋を離れ、木の根を枕に寝た。うめき声は、そこまでは届かなかった。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 戦の前後

List<SceneDef> _battleSideScenes() => [
  // ============================================ 筋: 同郷
  SceneDef('al_murato', 16, 45, (g) => _w1, (g) => alServing(g) && _farmBorn(g), (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('同じ村の者', '陣触れで集められた中に、同じ村から出てきた若い者たちがいた。田の畦で一緒に泥にまみれた顔ぶれだ。', [
      Choice.h('皆で生きて村へ帰ろうと誓う', '心強い仲間になる。誓いは重くもなる', () {
        g.meet('同郷の仲間', n, 60);
        g.setFlag('al_murato_vow');
        g.j(3);
        _stamp(g, 'murato');
        return '$nが音頭をとり、皆で小さな盃を回した。「生きて、また田植えをしよう」';
      }),
      Choice.h('村のことは忘れて手柄を立てる', '身軽に動ける。村の者とは疎くなる', () {
        l.merit += 2;
        l.net = l.net >= 1 ? l.net - 1 : 0;
        g.setFlag('al_murato_apart');
        _stamp(g, 'murato');
        return '「ここでは村は関わりない」と言うと、$nは寂しそうに笑った。';
      }),
    ], after: next);
  }),

  _chain('al_murato_rash', 17, 50, _w2, (g) => alServing(g) && g.l.people.containsKey('同郷の仲間'), (g, next) {
    final l = g.l;
    final p = l.people['同郷の仲間']!;
    g.ask('抜け駆け', '${p.name}が「手柄を立てて、村の者を見返してやる」と、夜明け前に敵陣へ抜け駆けすると言い出した。', [
      Choice.h('引き止める', '仲間は生き延びる。手柄は遠のく', () {
        p.bond = clampInt(p.bond + 10, 0, 100);
        g.setFlag('al_murato_held');
        _stamp(g, 'murato');
        return '「誓いを忘れたか」と腕をつかんだ。${p.name}は長いこと黙っていたが、やがて槍を置いた。';
      }),
      Choice.h('共に抜け駆けする', '手柄は大きい。帰れぬかもしれない', () {
        _stamp(g, 'murato');
        g.setFlag('al_murato_together');
        if (g.rng.chance(.05)) {
          g.die('同郷の若い者と抜け駆けして敵陣へ駆け込み、槍に貫かれた', 'senshi');
          return '霧の向こうから、槍の穂先が並んで現れた。';
        }
        if (g.rng.chance(clampD(.35 + l.bu / 200 + l.un / 400, .3, .8))) {
          l.merit += 8;
          l.fame += 4;
          g.mark('同郷の仲間と抜け駆けし、敵の兜首を挙げた');
          return '眠る敵の陣に二人で躍り込み、兜首を一つ挙げた。軍法破りと叱られたが、首は首だった。';
        }
        l.hp -= 15;
        l.fav = _c(l.fav - 5);
        return '敵に気づかれ、${p.name}を引きずるようにして逃げ戻った。組頭には、きつく叱られた。';
      }),
      Choice.h('好きにさせる', '止める義理はない。帰って来なければ悔いが残る', () {
        _stamp(g, 'murato');
        if (g.rng.chance(.6)) {
          l.people.remove('同郷の仲間');
          l.flags.removeWhere((f) => f.startsWith('al_murato_dead:'));
          g.setFlag('al_murato_dead:${p.name}');
          g.setFlag('al_murato_lost');
          g.j(-8);
          return '${p.name}は戻らなかった。夕方、敵の陣の前に、見覚えのある鎌の柄が転がっていたと聞いた。';
        }
        p.bond = clampInt(p.bond - 10, 0, 100);
        g.setFlag('al_murato_held');
        return '${p.name}は、傷だらけで戻ってきた。「止めてくれてもよかったろう」と、恨めしそうに言った。';
      }),
    ], after: next);
  }),

  _chain('al_murato_home', 20, 50, _w2, alServing, (g, next) {
    final l = g.l;
    final lost = g.hasFlag('al_murato_lost');
    final dead = _named(g, 'al_murato_dead:', '同郷の仲間');
    final text = lost
        ? '戦が一段落し、同じ村から出てきた者たちに暇が出た。懐には、戻らなかった$deadが遺した鎌の柄がある。'
        : '戦が一段落し、同じ村から出てきた者たちに暇が出た。「帰ろう、田植えに間に合う」と、皆が笑っている。';
    g.ask('村へ帰る道', text, [
      Choice.h('槍を置いて村へ帰る', '田と家族が待つ。槍の道はここで閉じる', () {
        _leave(g, ronin: false);
        g.j(8);
        g.setFlag('al_went_home');
        _stamp(g, 'murato');
        g.mark('同郷の者たちと連れ立って、槍を置いて村へ帰った');
        return '峠を越えると、懐かしい田が見えた。誰かが、田植え唄を口ずさみ始めた。';
      }),
      Choice.h('陣に残る', '出世の道は続く。村は遠くなる', () {
        l.fav = _c(l.fav + 3);
        g.j(-2);
        g.setFlag('al_stayed_on');
        _stamp(g, 'murato');
        return '帰っていく背中を、陣の柵の内から見送った。';
      }),
      if (lost)
        Choice.h('戻らなかった仲間の家を訪ねる', '果たせなかった誓いを詫びる。母の涙を見ることになる', () {
          l.mi = _c(l.mi + 2);
          l.net += 2;
          g.j(-3);
          g.setFlag('al_told_mother');
          _stamp(g, 'murato');
          g.mark('戻らなかった同郷の仲間の家を訪ね、その母に最期を語った');
          return '鎌の柄を渡すと、$deadの母は、それを胸に抱いて長いこと動かなかった。';
        }),
    ], after: next);
  }),

  // ============================================ 乱取りのあと（`ashigaru.dart` の旗から）
  _chain('al_hitokai', 16, 50, _w2, alServing, (g, next) {
    final l = g.l;
    g.ask('人買い', '乱取りで捕らえられた村の女や子どもが、陣の外れに縄でつながれている。人買いの商人が来て、値をつけ始めた。あなたが連れてきた子も、その中にいる。', [
      Choice.h('人買いに売る', '銭になる。あの子の行く末は知れない', () {
        l.gold += g.rng.range(4, 8);
        g.j(-8);
        g.setFlag('al_sold_captive');
        return '銭を受け取った。縄を引かれていく子は、一度も振り返らなかった。';
      }),
      Choice.h('縄を解いて逃がす', '朋輩には笑われる。子は親のもとへ帰れるかもしれない', () {
        l.net = l.net >= 1 ? l.net - 1 : 0;
        g.j(5);
        g.setFlag('al_freed_captive');
        g.mark('乱取りで捕らえた子の縄を解き、親のもとへ逃がした');
        return '夜のうちに縄を切り、村の方角を指さした。子は裸足のまま、闇へ駆けていった。';
      }),
      Choice.h('国へ連れ帰って育てる', '下人として養う。食い扶持は増える', () {
        _pay(g, 2);
        g.j(2);
        g.meet('連れ帰った子', g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF), 40);
        g.setFlag('al_took_child');
        return '名を聞くと、子は小さな声で答えた。国へ帰る道すがら、その子は一言もしゃべらなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 鉄砲（一五五〇年から）
  SceneDef(
    'al_teppo',
    17,
    55,
    (g) => _w1 + (g.year >= 1570 ? 1 : 0),
    (g) => alServing(g) && g.year >= 1550 && !g.l.gun,
    (g, next) {
      final l = g.l;
      g.ask('鉄砲組', '組頭が「これからは鉄砲だ」と言い、足軽の何人かを鉄砲組に回すと告げた。あなたも名を呼ばれた。', [
        Choice.h('鉄砲を担ぐ', '新しい戦の形に乗る。火縄と玉薬の扱いは厄介だ', () {
          l.gun = true;
          g.setFlag('al_teppo_yes');
          _stamp(g, 'teppo');
          g.mark('足軽の組から、鉄砲組に回された');
          return '重い筒を肩に担いだ。火縄の煙が目にしみた。';
        }),
        Choice.h('槍のままでいたいと願う', '慣れた槍で戦える。鉄砲の世には遅れる', () {
          l.bu = _c(l.bu + 1);
          g.setFlag('al_teppo_no');
          _stamp(g, 'teppo');
          return '「槍で生きてきた」と言うと、組頭は肩をすくめ、ほかの者の名を呼んだ。';
        }),
        if (l.chi >= 60)
          Choice.h('玉薬の合わせ方まで習う', '目が利けば重宝される。火の扱いを誤れば危うい', () {
            l.gun = true;
            l.merit += 3;
            g.setFlag('al_teppo_yes');
            g.setFlag('al_teppo_powder');
            _stamp(g, 'teppo');
            g.mark('鉄砲組に回され、玉薬の合わせ方まで覚えた');
            if (g.rng.chance(.1)) {
              l.hp -= 15;
              return '硝石と硫黄と炭の加減を覚えた。一度、火の粉が飛んで眉を焦がした。';
            }
            return '硝石と硫黄と炭の加減を覚えた。鉄砲頭が「お前は筒より薬だな」と笑った。';
          }, via: '知'),
      ], after: next);
    },
  ),

  _chain('al_teppo_rain', 18, 50, _w2, (g) => alServing(g) && g.l.gun, (g, next) {
    final l = g.l;
    final ef = _enemy(g);
    final en = ef == null ? '敵' : houseName(g, ef);
    g.ask('雨の鉄砲', '$en勢との戦の朝、雨が降り出した。鉄砲組の火縄が湿り、筒の中まで濡れていく。敵は、それを見越したように押し出してきた。', [
      Choice.h('火縄を懐に抱いて守る', '運と手際がよければ撃てる。撃てなければ的になる', () {
        _stamp(g, 'teppo');
        final ok = g.rng.chance(clampD(.4 + l.un / 250 + l.chi / 400, .3, .85));
        if (ok) g.setFlag('al_teppo_rain_ok');
        final pre = ok ? '懐で守った火縄で、ただ一人撃ち続けた。' : '火縄はとうとう湿り、筒はただの棒になった。';
        return pre + g.battle('main', enemy: ef, risk: ok ? .8 : 1.3, gain: ok ? 1.4 : .8, edge: ok ? .06 : -.04);
      }),
      Choice.h('鉄砲を捨て、槍に持ち替える', '腕に覚えがあれば戦える。鉄砲組の名折れだ', () {
        _stamp(g, 'teppo');
        final r = g.battle('van', enemy: ef, risk: l.bu >= 60 ? .9 : 1.2, gain: 1.1);
        return '濡れた筒を投げ捨て、落ちていた槍を拾った。$r';
      }),
      if (g.hasFlag('al_teppo_powder'))
        Choice.h('油紙に包んだ玉薬を配る', '仕度の差が出る。手柄は組のものになる', () {
          _stamp(g, 'teppo');
          l.merit += 4;
          l.fav = _c(l.fav + 5);
          g.setFlag('al_teppo_rain_ok');
          g.mark('雨の戦で、油紙に包んでおいた玉薬を鉄砲組に配った');
          final r = g.battle('main', enemy: ef, risk: .7, gain: 1.0, edge: .08);
          return '油紙の包みを開くと、乾いた玉薬が出てきた。鉄砲組の筒が、雨の中で次々に火を噴いた。$r';
        }),
    ], after: next);
  }),

  _chain(
    'al_teppo_teach',
    22,
    55,
    _w2,
    (g) => alServing(g) && g.l.gun && g.year >= 1576,
    (g, next) {
      final l = g.l;
      final told = worldLine(g) == 'real' && !g.hasFlag('history_nagashino')
          ? '三河の長篠で、鉄砲を揃えた織田と徳川の軍が武田の騎馬を退けたという話が、陣中にも届いた。'
          : '鉄砲を揃えた家が騎馬の軍を退けたという噂が、陣中にも届いた。';
      g.ask('鉄砲の稽古', '$told侍大将は鉄砲組を増やすと言い、撃ち方を若い足軽に教える役をあなたに振った。', [
        Choice.h('若い者に一から教える', '組の腕が上がる。教える者として名が残る', () {
          l.merit += 4;
          l.fav = _c(l.fav + 4);
          l.net += 2;
          g.setFlag('al_teppo_teacher');
          g.meet('鉄砲の弟子', g.rng.pick(kGivenM), 50);
          _stamp(g, 'teppo');
          g.mark('鉄砲組の小頭として、若い足軽たちに撃ち方を教えた');
          return '火縄の挟み方、玉の込め方、引き金を落とす間合い。若い者たちの筒先が、少しずつ揃っていった。';
        }),
        Choice.h('自分は撃ち手のままでいる', '腕は鈍らない。役目はほかの者へ回る', () {
          l.bu = _c(l.bu + 1);
          _stamp(g, 'teppo');
          return '「教えるのは性に合わぬ」と断った。的場では、今日も自分の筒だけを磨いた。';
        }),
        if (l.chi >= 55)
          Choice.h('撃つ者と込める者を分ける工夫を説く', '知恵が回れば重く用いられる。古株には嫌われる', () {
            l.merit += 6;
            l.fame += 3;
            l.net = l.net >= 1 ? l.net - 1 : 0;
            g.setFlag('al_teppo_teacher');
            g.setFlag('al_teppo_drill');
            _stamp(g, 'teppo');
            g.mark('鉄砲組に、撃つ者と込める者を分ける工夫を説いた');
            return '込める者が筒を渡し、撃つ者は撃つだけ。的場の音が、途切れなくなった。侍大将が、足を止めて見ていた。';
          }, via: '知'),
      ], after: next);
    },
  ),

  // ============================================ ひとつきり
  SceneDef(
    'al_kubi',
    17,
    55,
    (g) => _w1,
    (g) => alServing(g) && g.hasFlag('first_battle') && g.l.merit >= 5,
    (g, next) {
      final l = g.l;
      g.ask('首実検', '戦のあと、討ち取った首を抱えて首実検の列に並んだ。あなたの首は、名も知れぬ雑兵のものだ。前の男は、ろくに見もせずに「名のある侍の首」と言い立てている。', [
        Choice.h('名のある侍の首と申し立てる', '通れば恩賞は大きい。偽りと知れれば咎めは重い', () {
          g.setFlag('al_kubi_lied');
          if (g.rng.chance(clampD(.3 + l.mi / 250 + l.un / 400, .25, .7))) {
            l.merit += 8;
            l.gold += 4;
            g.j(-3);
            return '首帳に、聞いたこともない侍の名が書き込まれた。恩賞の銭は重かったが、首の顔はまともに見られなかった。';
          }
          if (g.rng.chance(.05)) {
            g.die('偽りの首を差し出した咎で、腹を切らされた', 'seppuku');
            return '首を検めた老臣が、静かに顔を上げた。';
          }
          l.fav = _c(l.fav - 10);
          l.fame -= 3;
          g.j(-4);
          return '「この首の歯は、鉄漿で染めておらぬ」。老臣の一言で、陣中の笑い者になった。';
        }),
        Choice.h('ありのまま雑兵の首と申し出る', '恩賞は小さい。正直は覚えられる', () {
          l.merit += 2;
          l.fav = _c(l.fav + 4);
          g.setFlag('al_kubi_honest');
          return '老臣は首を一瞥し、「正直な者よ」と帳面に印をつけた。';
        }),
        Choice.h('首を洗って弔ってから差し出す', '恩賞は変わらない。心は少し軽くなる', () {
          l.merit += 2;
          g.j(4);
          g.setFlag('al_kubi_mourned');
          g.mark('首実検の前に、討ち取った雑兵の首を洗い、経を唱えた');
          return '川で首の泥を落とし、知っているだけの経を唱えた。若い顔だった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'al_ochiru',
    17,
    50,
    (g) => _w1 * (_lordWeak(g) ? 1.5 : 1),
    (g) => alServing(g) && g.hasFlag('first_battle'),
    (g, next) {
      final l = g.l;
      g.ask('落ち延びる道', '負け戦で陣が崩れ、散り散りに落ち延びることになった。山道の先の村で、竹槍を持った村人たちが道を塞いでいる。落ち武者の具足は、いい値で売れるのだ。', [
        Choice.h('懐の銭を投げて道を開けさせる', '命は買える。銭は消える', () {
          _lose(g, .6);
          g.j(-2);
          return '銭をばらまくと、村人たちは地べたに這いつくばった。その隙に駆け抜けた。';
        }),
        Choice.h('斬り抜ける', '腕が立てば抜けられる。囲まれれば終わりだ', () {
          if (g.rng.chance(clampD(.4 + l.bu / 150, .35, .9))) {
            l.bu = _c(l.bu + 1);
            l.fame += 1;
            return '先頭の竹槍を叩き折ると、村人たちは蜘蛛の子を散らすように逃げた。';
          }
          if (g.rng.chance(.08)) {
            g.die('負け戦から落ち延びる途中、竹槍を持つ村人に囲まれて果てた', 'senshi');
            return '振り返ると、後ろの道も竹槍で塞がれていた。';
          }
          l.hp -= 20;
          return '竹槍に脇腹を突かれながら、どうにか藪へ転げ込んだ。';
        }),
        if (g.hasFlag('spared_village'))
          Choice.h('かつて乱取りから逃がした村の者だと名乗る', 'あの日の恩を覚えている者がいるかもしれない', () {
            g.j(6);
            g.setFlag('al_ochi_remembered');
            g.mark('落ち延びる山道で、かつて乱取りから逃がした村の者たちに匿われた');
            return '村人たちは顔を見合わせた。やがて腰の曲がった老婆が進み出て、「裏山の道を教えてくれたお人じゃ」と言った。その夜は、納屋の藁の中で眠った。';
          }),
      ], after: next);
    },
  ),
];

// ---------------------------------------------------------------- 身の振り方

List<SceneDef> _courseScenes() => [
  // 主家が滅び、勝った家に降った足軽（`game.dart` の `lordLost` が旗を立てる）。
  _chain('al_kuragae', 17, 55, _w2, alServing, (g, next) {
    final l = g.l;
    final h = houseName(g, l.lord);
    g.ask('降った足軽', '主家が滅び、$h家の足軽として組み入れられた。新しい組頭は「降った者は、まず先手で使う」と言い、古い主家の者たちは肩身を狭くしている。', [
      Choice.h('先手を願い出て忠を示す', '覚えはよくなる。先手は命がけだ', () {
        if (g.rng.chance(.04)) {
          g.die('主家が滅んだのち、降った先の先手に立って果てた', 'senshi');
          return '先手の列のいちばん前で、敵の槍衾が迫ってきた。';
        }
        l.fav = _c(l.fav + 8);
        l.merit += 4;
        g.setFlag('al_kuragae_proved');
        return '先手で槍をふるい、生きて戻った。組頭は「降った者にしては、やる」と言った。';
      }),
      Choice.h('古い主家の旗印を密かに持ち続ける', '心は折れない。見つかれば疑われる', () {
        g.j(3);
        g.setFlag('al_old_banner');
        g.mark('滅んだ主家の旗印の切れ端を、降った後も懐に持ち続けた');
        if (g.rng.chance(.15)) {
          l.fav = _c(l.fav - 8);
          return '旗印の切れ端を組頭に見咎められた。「まだ前の主を慕うか」と、扶持を削られた。';
        }
        return '旗印の切れ端を、守り袋に縫い込んだ。誰にも見せなかった。';
      }),
      Choice.h('暇を乞うて牢人になる', '二君に仕えずに済む。食い扶持はなくなる', () {
        _leave(g, ronin: true);
        g.j(2);
        g.setFlag('al_kuragae_left');
        g.mark('主家が滅んだのち、降った先に仕えず牢人の身を選んだ');
        return '槍を返し、具足を脱いだ。肩が軽く、懐も軽かった。';
      }),
    ], after: next);
  }),

  SceneDef(
    'al_onsho_ta',
    20,
    55,
    (g) => _w1,
    (g) => alServing(g) && g.l.merit >= 20 && g.year < 1590,
    (g, next) {
      final l = g.l;
      g.ask('褒美の田', '度重なる働きに、侍大将から褒美として、村の田を少し宛てがうと言い渡された。', [
        Choice.h('田を受け、陣触れのない年は自ら耕す', '暮らしの根ができる。戦と田の両方を背負う', () {
          l.gold += 2;
          g.j(5);
          g.setFlag('al_onsho_ta');
          g.mark('戦の褒美に田を賜り、陣触れのない年は自ら耕した');
          return '自分の名で年貢を納める田が、初めてできた。畦に立つと、足の裏が土を覚えていた。';
        }),
        Choice.h('田は親兄弟に任せる', '家は潤う。自分は槍の道に励める', () {
          l.net += 2;
          l.fav = _c(l.fav + 2);
          g.setFlag('al_ta_family');
          return '田の世話を兄弟に頼んだ。秋に、新米の俵が陣まで届いた。';
        }),
        Choice.h('田を銭に替えてもらう', '銭はすぐ手に入る。根は持たない', () {
          l.gold += 10;
          return '侍大将は「欲のない奴か、欲の深い奴か」と笑い、銭を下した。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'al_toritate',
    22,
    55,
    (g) => _w1 + 1,
    (g) => alServing(g) && g.l.rank == 2 && g.l.merit >= 28 && g.l.fav >= 25,
    (g, next) {
      final l = g.l;
      g.ask('足軽大将の話', '侍大将から、足軽の組をいくつか束ねる役に取り立てたいと話があった。足軽から侍の列に加わるのは、めったにないことだ。', [
        Choice.h('取り立てを受ける', '侍の列に加わる。足軽の朋輩とは遠くなる', () {
          l.rank = 3;
          if (l.maxRank < 3) l.maxRank = 3;
          if (l.troops < 5) l.troops = 5;
          l.fame += 5;
          g.j(6);
          g.setFlag('al_toritate');
          g.mark('足軽から身を起こし、足軽の組を束ねる侍に取り立てられた');
          return '馬を一頭与えられた。長屋の朋輩たちが、どこか遠い目で見送った。';
        }),
        Choice.h('組頭のまま、朋輩と並んでいたいと願う', '朋輩の信は厚い。出世の道はここで止まるかもしれない', () {
          l.net += 4;
          g.j(2);
          g.setFlag('al_stayed_kumi');
          return '侍大将は呆れた顔をしたが、長屋に戻ると、朋輩たちが酒を用意して待っていた。';
        }),
      ], after: next);
    },
  ),

  // 帰農。一五八八年の刀狩の前は田と陣触れを行き来できたが、その後は二つに一つになる。
  SceneDef(
    'al_kino',
    24,
    50,
    (g) => _w1,
    (g) => alServing(g) && _farmBorn(g) && !g.hasFlag('al_went_home'),
    (g, next) {
      final l = g.l;
      // 刀狩が起きた世（秀吉が天下を取った世）の一五八八年からは、村と陣を行き来できなくなる。
      final katana = g.year >= 1588 && !sceneSkippedInLine(g, 'h_katanagari');
      if (!katana) {
        g.ask('村からの文', '田植えの時分に、村の父から文が来た。「人手が足りぬ。戻って田を継いでくれ」。いまなら、また陣触れがあれば鍬を置いて出ればよい。', [
          Choice.h('槍を置いて村へ戻る', '田と家族が待つ。槍の道はここで閉じる', () {
            _leave(g, ronin: false);
            g.j(6);
            g.setFlag('al_kino');
            g.mark('槍を置いて村へ戻り、親の田を継いだ');
            return '村に戻ると、父の背が小さくなっていた。翌朝から、鍬を握った。';
          }),
          Choice.h('陣に残る', '出世の道は続く。田は荒れるかもしれない', () {
            l.fav = _c(l.fav + 2);
            g.j(-3);
            g.setFlag('al_kino_stayed');
            return '「もう少しだけ」と返事を書いてもらった。父からの文は、それきり途絶えた。';
          }),
        ], after: next);
        return;
      }
      g.ask('城下か村か', '刀狩の令が出て、村に戻る者は刀や槍を差し出せという。足軽として城下に残るか、刀を置いて百姓に戻るか。この先は、二つを行き来することはできないらしい。', [
        Choice.h('刀を差し出し、百姓に戻る', '戦に駆り出されることはなくなる。二度と侍の列には戻れない', () {
          _leave(g, ronin: false);
          g.j(5);
          g.setFlag('al_kino_katanagari');
          g.mark('刀狩の年に槍を置き、刀を差し出して村へ戻った');
          return '役人の前に刀を置いた。村へ帰る道で、腰がやけに軽かった。';
        }),
        Choice.h('城下に移り、足軽として生きる', '扶持で暮らす身になる。村の田とは縁が切れる', () {
          l.fav = _c(l.fav + 3);
          g.j(-2);
          g.setFlag('al_joka');
          g.mark('刀狩の年、村を離れて城下の足軽長屋に移り住んだ');
          return '村の田は弟に譲り、城下の長屋に移った。もう、田植えの季節を気にすることもない。';
        }),
      ], after: next);
    },
  ),

  // 足軽あがりで主を失った牢人。
  SceneDef(
    'al_ronin',
    18,
    55,
    (g) => _w1 + 1,
    (g) => alFormer(g) && g.l.ronin,
    (g, next) {
      final l = g.l;
      g.ask('牢人の暮らし', '主を失った足軽あがりの牢人に、世間の風は冷たい。木賃宿の板の間で、懐の銭を数える夜が続く。', [
        Choice.h('口入れ屋で次の奉公先を探す', '扶持にありつけるかもしれない。足元を見られる', () {
          l.net += 1;
          g.setFlag('al_ronin_seek');
          if (g.rng.chance(.5)) {
            l.gold += 2;
            return '奉公の口はなかったが、普請場の人足仕事で、どうにか食いつないだ。';
          }
          return '口入れ屋は、帳面をめくりもせずに首を振った。';
        }),
        Choice.h('野盗の誘いに乗る', '食うには困らない。もう表の道には戻れぬかもしれない', () {
          g.setFlag('way_outlaw');
          l.gold += 5;
          g.j(-4);
          g.setFlag('al_ronin_bandit');
          g.mark('食い詰めた牢人の身で、野盗の仲間に加わった');
          return '宿で声をかけてきた男についていくと、山の中に焚き火があった。';
        }),
        Choice.h('村に身を寄せ、百姓仕事を手伝う', '暮らしは細いが落ち着く。刀は錆びる', () {
          l.ronin = false;
          g.j(4);
          g.setFlag('al_ronin_farm');
          return '人手の足りない村で、田の草取りを手伝った。夕餉の粥が、やけにうまかった。';
        }),
      ], after: next);
    },
  ),
];
