import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';
import 'women_life.dart';

/// 奥で仕える女性と、嫁いだ女性の一生の岐路（2026-11-23）。id・旗は `ok_`。
///
/// 人生の約2割が女の道に進むのに、中堅の岐路（`retainer_life.dart` の `rt_`）で奥女中・上臈に出せる場面は8つほどで、
/// 嫁ぐと出なくなっていた。`women.dart`（`w_`）・`women_life.dart`（`wl_`）・`family.dart`（`fa_`）と題材を重ねずに、
/// 奥で仕える年・嫁いだ年・後家となった晩年に岐路を足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kOkuPrev]）。段を踏んだ年は旗 `ok_at:<筋>:<年>` に残し、
/// 次の段は何年か空けてから出す（[kOkuGap]）。
///
/// - 奥で仕える（下女〜大局、未婚。`womanKind` が奥）: 御台所のお目見え → 奥の金子 → 帳面の改め／
///   奥の男の影 → 朋輩のその後 →（晩年）奥の朋輩との再会／奥の疱瘡／里帰りの供／囲まれた日の奥 → 落城の夜／奥に残るか。
/// - 嫁いだ武家の女性（`womanKind` が武家の妻）: 婚家の姑 → 姑の病／留守の家／夫の囲い女 → 囲い女の子／捕らわれた夫／
///   実家と婚家の手切れ → 実家からの密書・両家の和／嫡男の手習い → 育った子／婚家の跡目／主家の和の証 → 預けられた屋敷。
/// - 後家と晩年: 後家の暮らし → 髪を下ろすか／孫娘の嫁ぎ先。
/// - 位は上げない（奥の出世は `women_life.dart` の「奥の出世」、後見・女大名は `adult.dart` のまま）。
/// - 戦えない女性に斬り合いの手は出さない（囲まれた日に塀の上に立つのは `canFight` の女武者だけ）。

// ---------------------------------------------------------------- 誰に出るか

const _bukeCls = ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'ronin'];

/// 奥で仕えている女性（未婚・主家が生きている）。
bool okServing(Game g) =>
    womanKind(g) == WomanKind.oku &&
    g.active &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// いまの連れ合いを戦で亡くしたか（`adult.dart` の「夫の死」で家を守ると決めた人は、夫婦の印が残ったままになる）。
/// 歩んだ道の文（「◯◯を戦で亡くし」）を、いまの連れ合いの名で見る（再び嫁いだ人は名が変わるので外れる）。
bool okLostToWar(Game g) {
  final n = g.l.people['伴侶']?.name;
  return n != null && g.l.path.any((p) => p.contains('$nを戦で亡くし'));
}

/// 武家に嫁いでいる女性（連れ合いがいる）。
bool okWife(Game g) =>
    womanKind(g) == WomanKind.wife &&
    g.active &&
    g.l.people.containsKey('伴侶') &&
    !okLostToWar(g);

/// 武家の後家（連れ合いを亡くした。離縁して実家へ帰った人は除く）。隠居していてもよい。
bool okWidow(Game g) {
  final l = g.l;
  return l.female &&
      (!l.married || okLostToWar(g)) &&
      l.people.containsKey('伴侶') &&
      !g.hasFlag('ok_ryoke_left') &&
      !g.hasFlag('priesthood') &&
      l.rank < 8 &&
      !(l.rank == 0 && (g.hasFlag('way_outlaw') || g.hasFlag('way_merchant'))) &&
      (l.maxRank >= 1 || _bukeCls.contains(l.cls.id));
}

/// 老いた女性（仏門・当主を除く）。隠居していてもよい。
bool okElder(Game g) =>
    g.l.female &&
    !g.hasFlag('priesthood') &&
    g.l.rank < 8 &&
    !(g.l.rank == 0 && g.hasFlag('way_outlaw'));

/// この岐路が出てよい人（どれかに当てはまる女性）。テストも使う。
bool okLife(Game g) => okServing(g) || okWife(g) || okWidow(g) || okElder(g);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kOkuPrev = <String, List<String>>{
  'ok_kane': ['ok_midai_fav'],
  'ok_kane_audit': ['ok_kane_honest', 'ok_kane_skim'],
  'ok_uwasa_after': ['ok_uwasa_hid', 'ok_uwasa_told', 'ok_uwasa_warned'],
  'ok_houbai_reunion': ['ok_houbai'],
  'ok_rakujo': ['ok_rojo_kitchen', 'ok_rojo_nurse', 'ok_rojo_lead', 'ok_rojo_wall'],
  'ok_shutome_byo': ['ok_shutome_bow', 'ok_shutome_cold', 'ok_shutome_won'],
  'ok_sobame_child': ['ok_sobame_allow', 'ok_sobame_confront', 'ok_sobame_met'],
  'ok_ryoke_after': ['ok_ryoke_stay', 'ok_ryoke_bridge'],
  'ok_kyoiku_after': ['ok_edu_tera', 'ok_edu_self', 'ok_edu_bu'],
  'ok_hitojichi_life': ['ok_hitojichi_went'],
  'ok_rakushoku': ['ok_goke_quiet', 'ok_goke_ruled', 'ok_goke_teach'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kOkuGap = <String, (String, int)>{
  'ok_kane': ('midai', 2),
  'ok_kane_audit': ('midai', 2),
  'ok_uwasa_after': ('houbai', 1),
  'ok_houbai_reunion': ('houbai', 6),
  'ok_rakujo': ('rojo', 2),
  'ok_shutome_byo': ('shutome', 3),
  'ok_sobame_child': ('sobame', 2),
  'ok_ryoke_after': ('ryoke', 2),
  'ok_kyoiku_after': ('kyoiku', 4),
  'ok_hitojichi_life': ('hitojichi', 1),
  'ok_rakushoku': ('goke', 2),
};

/// この岐路の id（テストが使う）。
const kOkuLifeIds = [
  'ok_omemie',
  'ok_kane',
  'ok_kane_audit',
  'ok_uwasa',
  'ok_uwasa_after',
  'ok_hoso',
  'ok_satogaeri',
  'ok_rojo',
  'ok_rakujo',
  'ok_yome',
  'ok_shutome',
  'ok_shutome_byo',
  'ok_rusu',
  'ok_sobame',
  'ok_sobame_child',
  'ok_toraware',
  'ok_ryoke',
  'ok_ryoke_after',
  'ok_kyoiku',
  'ok_kyoiku_after',
  'ok_katoku',
  'ok_hitojichi',
  'ok_hitojichi_life',
  'ok_goke',
  'ok_rakushoku',
  'ok_mago_yome',
  'ok_houbai_reunion',
];

/// 奥で仕える女性に出る岐路（テストが出た瞬間に確かめる）。
const kOkuServingIds = [
  'ok_omemie',
  'ok_kane',
  'ok_kane_audit',
  'ok_uwasa',
  'ok_uwasa_after',
  'ok_hoso',
  'ok_satogaeri',
  'ok_rojo',
  'ok_rakujo',
  'ok_yome',
];

/// 武家に嫁いだ女性に出る岐路。
const kOkuWifeIds = [
  'ok_shutome',
  'ok_shutome_byo',
  'ok_rusu',
  'ok_sobame',
  'ok_sobame_child',
  'ok_toraware',
  'ok_ryoke',
  'ok_ryoke_after',
  'ok_kyoiku',
  'ok_katoku',
  'ok_hitojichi',
  'ok_hitojichi_life',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('ok_at:$chain:'));
  g.setFlag('ok_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int okSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('ok_at:$chain:')) {
      return g.year - int.parse(f.substring('ok_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool okChainReady(Game g, String id) {
  final prev = kOkuPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kOkuGap[id];
  if (gap == null) return true;
  return okSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _fav(Game g, int n) => g.l.fav = _c(g.l.fav + n);
void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _merit(Game g, int n) => g.l.merit = g.l.merit + n < 0 ? 0 : g.l.merit + n;

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

/// 連れ合い（いなければ「夫」）。
String _husband(Game g) => g.l.people['伴侶']?.name ?? '夫';

void _spouse(Game g, int n) {
  final sp = g.l.people['伴侶'];
  if (sp != null) sp.bond = _c(sp.bond + n);
}

void _bondOf(Game g, String role, int n) {
  final p = g.l.people[role];
  if (p != null) p.bond = _c(p.bond + n);
}

/// 主家の呼び名（「◯◯家」）。主家がなければ [fallback]。
String _lordHouse(Game g, [String fallback = '婚家の主家']) =>
    g.l.lord == null ? fallback : '${houseName(g, g.l.lord)}家';

/// 主家に近いほかの家（内部の名）。いなければ null。
String? _other(Game g) {
  final lf = g.l.lord;
  if (lf == null) return null;
  final c = nearest(g.alive.where((f) => f.name != lf), (f) => f.name, faction: lf, n: 3);
  return c.isEmpty ? null : g.rng.pick(c).name;
}

String _otherName(Game g, String? f) => f == null ? '隣国の家' : '${houseName(g, f)}家';

/// 嫡男（いなければ子）の名。
String _sonName(Game g) =>
    g.l.people['嫡男']?.name ?? g.l.people['子']?.name ?? g.rng.pick(kGivenM);

/// 重み。筋の始まり・ひとつきりは、奥で仕える年が [_wServe]（嫁ぐまでの年は短いので重め）、
/// 嫁いだ年が [_wWife]。前の段を踏んだ人だけに出る後段は [_w2]、晩年は [_wOld]。
/// 奥女中・上臈（位三〜四）の年は `retainer_life.dart` の奥の岐路と分け合うので、軽くする。
double _wServe(Game g) => g.l.rank >= 3 && g.l.rank <= 4 ? 2.5 : 5.0;
const _wWife = 2.0;
const _w2 = 24.0;

/// 晩年の岐路の重み（`old_age.dart` の晩年の岐路が20なので、押し出されないよう重めにする）。
const _wOld = 12.0;

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
  (g) => who(g) && okChainReady(g, id),
  run,
);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildOkuLifeScenes() => [
  ..._servingScenes(),
  ..._wifeScenes(),
  ..._lateScenes(),
];

// ---------------------------------------------------------------- 奥で仕える

List<SceneDef> _servingScenes() => [
  // ============================================ 筋: 御台所の気に入り → 奥の金子 → 帳面の改め
  SceneDef('ok_omemie', 16, 40, _wServe, (g) => okServing(g) && g.l.rank <= 4, (g, next) {
    final l = g.l;
    g.ask('御台所のお目見え', '奥に上がって日の浅い女中たちが、御台所さまにお目見えする日が来た。一人ずつ御前に進み、何か一つ言上せよという。前の者は声が震えて、名乗るのがやっとだった。', [
      Choice.h('型どおりに挨拶だけする', '粗相はしない。目にも留まらない', () {
        _stamp(g, 'midai');
        g.setFlag('ok_omemie_plain');
        return '型どおりに手をつき、名乗って下がった。御台所さまは、次の者に目を移した。';
      }),
      Choice.h('国の話を一つ申し上げる', '気に入られれば側に呼ばれる。出過ぎた者と思われることもある', () {
        _stamp(g, 'midai');
        if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
          _fav(g, 4);
          g.setFlag('ok_midai_fav');
          return '国の祭りの話をすると、御台所さまは扇の陰で笑い、「明日もまいれ」と仰せになった。';
        }
        _fav(g, -2);
        g.j(-2);
        g.setFlag('ok_omemie_plain');
        return '話の途中で、年かさの女中が咳払いをした。下がってから、「御前で長話をするものではない」と叱られた。';
      }),
      if (l.chi >= 60)
        Choice.h('床の間の掛け物の歌を読み解いて申し上げる', '学のほどが知れれば重く用いられる。年かさの女中の目は厳しくなる', () {
          _stamp(g, 'midai');
          _fav(g, 5);
          _merit(g, 2);
          g.setFlag('ok_midai_fav');
          g.setFlag('ok_midai_learned');
          return '古い歌の本歌まで言い当てると、御台所さまは身を乗り出した。その日から、あなたは御前の文箱を預かる役に呼ばれた。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('ok_kane', 18, 50, _w2, okServing, (g, next) {
    final l = g.l;
    g.ask('奥の金子', '御台所さまの気に入りとなったあなたに、奥の台所の金子と、出入りの商人への払いの差配が任された。ある日、出入りの呉服屋が「払いを少し上乗せして帳に付けてくだされば、差額は折半に」と耳打ちしてきた。', [
      Choice.h('断り、帳面をありのままに付ける', '身はきれいなまま。呉服屋は面白くない', () {
        _stamp(g, 'midai');
        _fav(g, 2);
        g.j(1);
        g.setFlag('ok_kane_honest');
        return '呉服屋は愛想笑いをして引き下がった。その月から、反物の届くのが少し遅くなった。';
      }),
      Choice.h('話に乗る', '懐は温まる。帳面はいつか誰かに改められる', () {
        _stamp(g, 'midai');
        l.gold += 8;
        g.j(-1);
        g.setFlag('ok_kane_skim');
        return '月の終わりに、呉服屋の手代が小さな包みを置いていった。夜、包みを行李の底に沈めた。';
      }),
      if (l.sei >= 60)
        Choice.h('出入りの商人を競わせ、払いそのものを下げる', '奥の蔵が潤い、名も上がる。古い出入りの者に恨まれる', () {
          _stamp(g, 'midai');
          _fav(g, 5);
          _merit(g, 3);
          g.setFlag('ok_kane_honest');
          g.setFlag('ok_kane_saved');
          g.mark('奥の台所の払いを改め、出入りの商人を競わせて奥の蔵を潤した');
          return '城下の呉服屋三軒に同じ反物の値を出させた。御台所さまは帳面を見て、「奥にも勘定のできる者がおったか」と笑った。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('ok_kane_audit', 19, 55, _w2, okServing, (g, next) {
    final l = g.l;
    if (g.hasFlag('ok_kane_skim')) {
      g.ask('帳面の改め', '表の勘定方が、奥の金子の帳面を改めに来た。近ごろ、呉服屋への払いが表の見積もりと合わないという。勘定方の若侍は、一枚ずつ指でなぞっている。', [
        Choice.h('夜のうちに帳面を書き直して差し出す', '運と知恵が回れば切り抜けられる。見抜かれれば奥にいられない', () {
          _stamp(g, 'midai');
          if (g.rng.chance(clampD(.35 + l.chi / 400 + l.un / 400, .35, .8))) {
            g.j(-2);
            g.setFlag('ok_kane_escaped');
            return '若侍は首をかしげたが、何も言わずに帳面を閉じた。その晩は眠れなかった。';
          }
          _fav(g, -12);
          _merit(g, -5);
          g.j(-8);
          g.setFlag('ok_kane_caught');
          return '書き直した墨の色の違いを、若侍は見逃さなかった。あなたは金子の役を解かれ、奥の隅の役へ移された。';
        }),
        Choice.h('御台所さまにすべて打ち明ける', '罪は軽くなるかもしれない。気に入りの座は失う', () {
          _stamp(g, 'midai');
          _pay(g, 8);
          _fav(g, -5);
          g.j(2);
          g.setFlag('ok_kane_confessed');
          return '御台所さまは長く黙っていたが、「返せばよい。二度とするな」とだけ言った。胸のつかえが、ようやく下りた。';
        }),
        Choice.h('呉服屋に罪をかぶせる', '己は助かる。呉服屋の恨みは深い', () {
          _stamp(g, 'midai');
          g.j(-4);
          g.setFlag('ok_kane_blamed');
          return '呉服屋は出入りを差し止められた。城下で、あの店が暖簾を下ろしたと聞いた。';
        }),
      ], after: next);
      return;
    }
    g.ask('帳面の改め', '表の勘定方が、奥の金子の帳面を改めに来た。あなたの付けた帳面に誤りはないが、奥全体の払いが表の見積もりと合わないという。', [
      Choice.h('ありのままの帳面を差し出す', '身の潔白は明らかになる。合わない払いの出どころは分からない', () {
        _stamp(g, 'midai');
        _fav(g, 3);
        _merit(g, 2);
        g.setFlag('ok_kane_clean');
        return '勘定方は「この帳面だけは、一文の狂いもない」と言って帰った。';
      }),
      Choice.h('合わない払いの出どころを自ら調べる', '知恵が回れば手柄になる。奥の誰かを敵に回す', () {
        _stamp(g, 'midai');
        if (g.rng.chance(clampD(.45 + l.chi / 300, .45, .85))) {
          _fav(g, 6);
          _merit(g, 4);
          g.setFlag('ok_kane_found');
          g.mark('奥の金子の帳面が表と合わない出どころを、自ら突き止めた');
          return '古い女中の部屋の払いに、同じ反物が三度付けられていた。御台所さまは黙ってうなずき、その女中は里へ下がった。';
        }
        _fav(g, -2);
        g.j(-2);
        return '帳面を何日も繰ったが、出どころは見つからなかった。奥の誰かが、あなたを嗅ぎ回る者と呼び始めた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 奥の男の影 → 朋輩のその後 →（晩年）再会
  SceneDef('ok_uwasa', 17, 45, _wServe, okServing, (g, next) {
    final l = g.l;
    final f = g.rng.pick(kGivenF);
    _keepName(g, 'ok_houbai_name:', f);
    g.ask('奥の男の影', '夜更けに厠へ立った帰り、奥の庭の植え込みに男の影を見た。翌朝、朋輩の女中の$fが、青い顔であなたの袖を引いた。「誰にも言わないで」と。', [
      Choice.h('何も見なかったことにする', '朋輩は救われる。露見すれば共に咎められる', () {
        _stamp(g, 'houbai');
        g.setFlag('ok_uwasa_hid');
        g.setFlag('ok_houbai');
        g.meet('奥の朋輩', f, 60);
        return '$fの手を握り、黙ってうなずいた。$fは泣きながら、何度も頭を下げた。';
      }),
      Choice.h('年寄の女中に告げる', '奥の掟は守られる。朋輩は奥を追われる', () {
        _stamp(g, 'houbai');
        _fav(g, 3);
        _merit(g, 2);
        g.j(-3);
        g.setFlag('ok_uwasa_told');
        return '年寄の女中は顔色ひとつ変えずに聞き、その日のうちに$fは奥から姿を消した。';
      }),
      Choice.h('$fを諭し、男と手を切らせる', '朋輩を守れるかもしれない。聞き入れるかは分からない', () {
        _stamp(g, 'houbai');
        g.setFlag('ok_houbai');
        if (g.rng.chance(clampD(.4 + l.mi / 250, .4, .85))) {
          g.setFlag('ok_uwasa_warned');
          g.meet('奥の朋輩', f, 70);
          return '「奥を追われれば、国の親が泣く」と言うと、$fは長く黙ったあと、「もう会わない」と言った。';
        }
        g.setFlag('ok_uwasa_hid');
        g.meet('奥の朋輩', f, 50);
        return '$fは泣くばかりで、うなずきはしなかった。それでも、あなたは誰にも言わなかった。';
      }),
    ], after: next);
  }),

  _chain('ok_uwasa_after', 18, 50, _w2, okServing, (g, next) {
    final l = g.l;
    final f = _named(g, 'ok_houbai_name:', '朋輩');
    if (g.hasFlag('ok_uwasa_warned')) {
      g.ask('朋輩の礼', '$fは男と手を切り、何事もなかったように奥の務めに戻った。ある晩、あなたの部屋に、手縫いの守り袋がそっと置かれていた。', [
        Choice.h('守り袋を身につける', '朋輩との縁は深まる。奥の誰かに見咎められることはない', () {
          _stamp(g, 'houbai');
          _bondOf(g, '奥の朋輩', 15);
          g.j(3);
          g.setFlag('ok_houbai_close');
          return '守り袋を帯の内に縫い留めた。廊下で行き会うと、$fは小さく笑った。';
        }),
        Choice.h('$fを己の下の役に推す', '朋輩は奥で身を立てられる。贔屓と言われることもある', () {
          _stamp(g, 'houbai');
          _bondOf(g, '奥の朋輩', 10);
          _net(g, 2);
          _fav(g, -1);
          g.setFlag('ok_houbai_close');
          return '$fは文箱の役に就いた。年かさの女中が「仲のよいこと」と言った声には、棘があった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('ok_uwasa_hid')) {
      g.ask('朋輩の身ごもり', '$fが身ごもった。相手は表の若侍で、奥の掟では、ただでは済まない。$fは、暇を願い出る手引きをしてほしいと泣いた。', [
        Choice.h('病と偽って暇を取らせる手はずを整える', '朋輩は里で子を産める。偽りが露見すれば共に咎められる', () {
          _stamp(g, 'houbai');
          if (g.rng.chance(clampD(.7 + l.un / 400, .7, .9))) {
            _bondOf(g, '奥の朋輩', 15);
            g.j(2);
            g.setFlag('ok_houbai_saved');
            g.mark('奥の朋輩の身ごもりを隠し、病と偽って里へ帰した');
            return '薬師に頼んで「胸の病」と書いてもらった。$fは輿に揺られて里へ下がり、春に、男の子が生まれたと文が来た。';
          }
          _fav(g, -8);
          g.j(-4);
          return '偽りは年寄の女中に見抜かれた。$fは里へ帰され、あなたはきつい叱りを受けた。';
        }),
        Choice.h('相手の若侍に責めを負わせるよう訴え出る', '筋は通る。表の侍を敵に回す', () {
          _stamp(g, 'houbai');
          if (g.rng.chance(clampD(.4 + l.sei / 300, .4, .8))) {
            _fav(g, 2);
            _bondOf(g, '奥の朋輩', 10);
            g.setFlag('ok_houbai_wed');
            return '訴えは表に届き、若侍は$fを娶るよう命じられた。祝言の日、$fはあなたを上座に座らせようとした。';
          }
          _fav(g, -4);
          g.j(-3);
          return '若侍は「覚えがない」と言い張った。$fは里へ帰され、表の侍たちはあなたを避けるようになった。';
        }),
        Choice.h('関わらない', '身は守れる。朋輩は一人で泣く', () {
          _stamp(g, 'houbai');
          _bondOf(g, '奥の朋輩', -20);
          g.j(-3);
          return 'あなたは首を振った。$fは何も言わずに部屋へ戻り、ひと月ののち、黙って奥を去った。';
        }),
      ], after: next);
      return;
    }
    g.ask('去った朋輩', '奥を追われた$fの消息が届いた。表の若侍とは添えず、城下の外れで一人、針仕事をして暮らしているという。', [
      Choice.h('銭を包んで届けさせる', '朋輩の暮らしの足しになる。恨みが解けるかは分からない', () {
        _stamp(g, 'houbai');
        _pay(g, 4);
        if (g.rng.chance(.5)) {
          g.setFlag('ok_houbai');
          g.setFlag('ok_houbai_forgave');
          g.meet('奥の朋輩', f, 45);
          return '使いの者が、$fの返事を持ち帰った。「恨んではいない。あなたは務めを果たしただけ」とあった。';
        }
        g.j(-2);
        return '銭の包みは、封も切られずに返ってきた。';
      }),
      Choice.h('会いに行って詫びる', '心は軽くなるかもしれない。門前で追い返されることもある', () {
        _stamp(g, 'houbai');
        if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .8))) {
          g.setFlag('ok_houbai');
          g.setFlag('ok_houbai_forgave');
          g.meet('奥の朋輩', f, 55);
          g.j(3);
          return '$fは戸口でしばらく黙っていたが、やがて白湯を出してくれた。二人で、奥の噂話をして笑った。';
        }
        g.j(-4);
        return '$fは戸を開けなかった。戸の内から、針を運ぶ音だけが聞こえていた。';
      }),
      Choice.h('奥の掟を守ったまでと、胸にしまう', '迷いは見せない。朋輩とはそれきりになる', () {
        _stamp(g, 'houbai');
        g.j(-1);
        return '文を炉にくべた。それきり、$fの名を口にすることはなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 奥の疱瘡
  SceneDef('ok_hoso', 16, 55, _wServe, okServing, (g, next) {
    final l = g.l;
    final h = g.rng.pick(kHimeNames);
    g.ask('奥の疱瘡', '奥で疱瘡が出た。熱を出したのは、幼い姫君の$hさまだ。うつるのを恐れて、女中たちは寝所に近づこうとしない。', [
      Choice.h('看病を申し出る', '姫君の命を支えられる。病はうつることがある', () {
        if (g.rng.chance(.03)) {
          g.die('姫君の疱瘡の看病に詰めるうち、同じ病に倒れた', 'byo');
          return '姫君の熱が引いた朝、あなたの額が焼けるように熱かった。';
        }
        _fav(g, 8);
        _merit(g, 5);
        g.setFlag('ok_hoso_nursed');
        g.mark('奥で疱瘡に罹った姫君を、寝所に詰めて看病した');
        if (g.rng.chance(.3)) {
          l.hp -= 15;
          return '姫君は持ち直した。看病のうちにあなたも熱を出したが、命は取りとめた。頬に、痘痕が一つ残った。';
        }
        return '七日のあいだ枕元を離れなかった。熱の引いた$hさまは、あなたの袖をつかんで眠った。';
      }),
      Choice.h('加持祈祷の僧を呼ぶよう願い出る', '奥の者は落ち着く。病そのものに効くかは分からない', () {
        _fav(g, 1);
        if (g.rng.chance(.6)) {
          g.j(1);
          return '護摩の煙が奥に満ちた。$hさまの熱は、十日ののちに引いた。';
        }
        g.j(-4);
        return '経の声が夜通し続いたが、$hさまの熱は引かなかった。廊下の端で、乳母が泣いていた。';
      }),
      if (l.chi >= 60)
        Choice.h('寝所を離れに移し、看る者を病の済んだ者に限らせる', '奥に病が広がらずに済む。冷たいと言われる', () {
          _fav(g, 5);
          _merit(g, 4);
          g.setFlag('ok_hoso_isolated');
          g.mark('奥に疱瘡が出たとき、寝所を離れに移して病の広がりを止めた');
          return '幼いころに疱瘡を済ませた下女たちを選んで離れに詰めさせた。奥でほかに熱を出す者は出ず、$hさまも持ち直した。';
        }, via: '知'),
    ], after: next);
  }),

  // ============================================ 里帰りの供
  SceneDef('ok_satogaeri', 18, 50, _wServe, (g) => okServing(g) && g.l.rank >= 2, (g, next) {
    final l = g.l;
    final house = _lordHouse(g, '主家');
    g.ask('里帰りの供', '奥方さまが里帰りされることになり、あなたは供の女中に選ばれた。実家の屋敷に着いた晩、襖の向こうで、奥方さまと父君が声をひそめて話すのを聞いてしまった。$houseの行く末に関わる話のようだ。', [
      Choice.h('何も聞かなかったことにする', '奥方さまの信は損なわない。胸に重いものを抱える', () {
        _fav(g, 2);
        g.j(-2);
        g.setFlag('ok_sato_silent');
        return '布団をかぶって、朝まで目を閉じていた。帰りの道中、奥方さまはいつもより口数が多かった。';
      }),
      Choice.h('戻ってから殿のお耳に入れる', '家への忠は立つ。奥方さまの身が危うくなる', () {
        _merit(g, 5);
        g.j(-5);
        g.setFlag('ok_sato_told');
        return '殿は黙って聞き、「よう申した」とだけ言った。それから奥方さまの文は、表の者が改めるようになった。';
      }),
      if (l.chi >= 60)
        Choice.h('奥方さまにだけ、聞いてしまったと打ち明ける', '腹を割れば奥方さまの懐刀になれる。口を封じられる恐れもある', () {
          if (g.rng.chance(clampD(.6 + l.chi / 400, .6, .9))) {
            _fav(g, 6);
            _merit(g, 3);
            g.setFlag('ok_sato_confidant');
            g.mark('奥方の里帰りの供をし、実家での密談を胸に納めて奥方の懐刀となった');
            return '奥方さまは長くあなたを見つめ、「そなたにだけは、話しておく」と言った。両家の和を保つための、父君への頼みごとだった。';
          }
          _fav(g, -6);
          g.j(-4);
          return '奥方さまは「何のことか」と笑ったが、その日から、あなたを身の回りから遠ざけた。';
        }, via: '知'),
    ], after: next);
  }),

  // ============================================ 筋: 囲まれた日の奥 → 落城の夜
  SceneDef('ok_rojo', 16, 60, _wServe, okServing, (g, next) {
    g.ask('囲まれた日の奥', '敵の大軍が押し寄せ、殿の籠もる城が囲まれた。表は兵で埋まり、奥の女たちにも務めが割り振られた。', [
      Choice.h('大釜で米を炊き、握り飯を表へ運ぶ', '兵の腹を支える。火の番で体はこたえる', () {
        _stamp(g, 'rojo');
        g.l.hp -= 5;
        _merit(g, 3);
        g.setFlag('ok_rojo_kitchen');
        return '夜も昼もなく米を炊いた。ひと月ののち、敵は囲みを解いて退いた。手のひらの火ぶくれは、なかなか消えなかった。';
      }),
      Choice.h('傷を負った兵の手当てをする', '多くの命を救える。血と呻きに心が削られる', () {
        _stamp(g, 'rojo');
        g.j(-4);
        _merit(g, 4);
        _net(g, 2);
        g.setFlag('ok_rojo_nurse');
        return '晒しを裂き、焼酎で傷を洗った。ひと月ののち囲みは解け、足軽の一人が「奥の姉さまのおかげで」と頭を下げた。';
      }),
      Choice.h('鉄砲の玉を鋳る', '戦の役に立つ。鉛の煙を吸う', () {
        _stamp(g, 'rojo');
        g.l.hp -= 6;
        _merit(g, 4);
        g.setFlag('ok_rojo_lead');
        return '寺の鐘の飾りまで溶かして玉を鋳た。ひと月ののち、敵は囲みを解いて退いた。';
      }),
      if (g.canFight)
        Choice.h('薙刀を取り、塀の上に立つ', '女武者の名が上がる。矢弾の飛ぶところだ', () {
          _stamp(g, 'rojo');
          if (g.rng.chance(.04)) {
            g.die('囲まれた日に塀の上で薙刀を振るい、流れ矢に倒れた', 'senshi');
            return '塀に取りついた敵を突き落としたとき、首筋に矢が立った。';
          }
          g.l.fame += 5;
          _merit(g, 6);
          g.setFlag('ok_rojo_wall');
          g.mark('囲まれた日に、薙刀を取って塀の上に立った');
          return '塀に梯子をかけた敵を、薙刀で三人まで払い落とした。ひと月ののち囲みは解け、兵たちはあなたを「奥の鬼」と呼んだ。';
        }, via: g.fightVia),
    ], after: next);
  }),

  _chain('ok_rakujo', 18, 65, 14, okServing, (g, next) {
    final hime = g.rng.pick(kHimeNames);
    g.ask('落城の夜', '殿が出張っていた支城が、ふたたび囲まれた。奥の女たちも供をして入っていたが、今度は持ちこたえられそうにない。明朝には奥まで敵が入るという。奥方さまは、白い小袖に着替えている。', [
      Choice.h('姫君の$himeさまを背負い、抜け道から落ちる', '姫君を救えるかもしれない。夜の山道で追手に会うこともある', () {
        _stamp(g, 'rojo');
        if (g.rng.chance(.03)) {
          g.die('囲みの破れる夜、姫君を逃がしたあと行方が知れなくなった', 'yukue');
          return '谷の向こうで、松明がいくつも揺れていた。姫君を岩陰に隠し、あなたは松明のほうへ歩き出した。';
        }
        _fav(g, 10);
        _merit(g, 8);
        g.l.fame += 5;
        g.meet('落とした姫', hime, 70);
        g.setFlag('ok_rakujo_hime');
        g.mark('囲まれた支城が落ちる夜、姫君を背負って抜け道から落ちのびた');
        return '夜通し山道を歩き、明け方、本城の見える峠に出た。背中の$himeさまは、あなたの襟をつかんだまま眠っていた。';
      }),
      Choice.h('奥方さまのお側を離れない', '最後まで務めを果たす。行く末は奥方さまの心しだい', () {
        _stamp(g, 'rojo');
        _fav(g, 6);
        g.j(-6);
        g.setFlag('ok_rakujo_stayed');
        return '奥方さまは「そなたらは生きよ」と言い、女たちを先に裏門から出させた。奥方さまご自身は、殿の迎えの兵と共に、最後に出られた。';
      }),
      Choice.h('朋輩の女中たちをまとめ、明け方に門を出て降る', '多くの女が生き延びる。裏切りと言う者もいる', () {
        _stamp(g, 'rojo');
        _net(g, 4);
        _fav(g, -3);
        g.setFlag('ok_rakujo_led');
        return '白い布を掲げて門を出た。敵の侍大将は女たちに手を出させず、本城への道を開けさせた。';
      }),
    ], after: next);
  }),

  // ============================================ 奥に残るか、嫁ぐか
  SceneDef('ok_yome', 22, 34, _wServe, (g) => okServing(g) && g.l.rank >= 2 && g.l.rank <= 5, (g, next) {
    final l = g.l;
    final name = '${g.rng.pick(kSurnames)}家の${g.rng.pick(kGivenM)}';
    g.ask('奥に残るか', '国の親から縁談の文が届いた。相手は$nameという。だが奥では、「このまま残って、いずれ奥を束ねる身に」という声もある。', [
      Choice.h('暇をいただいて嫁ぐ', '家を持てる。奥で積んだものは置いていく', () {
        l.married = true;
        g.meet('伴侶', name, 50);
        g.j(6);
        g.setFlag('ok_yome_left');
        g.mark('奥の勤めを退き、$nameのもとへ嫁いだ');
        return '朋輩たちが、餞別に紅を一つずつ持ち寄ってくれた。';
      }),
      Choice.h('奥に残る', '奥での道が開ける。嫁ぐ機は遠のく', () {
        _merit(g, 5);
        _fav(g, 3);
        g.j(-2);
        g.setFlag('ok_oku_stayed');
        return '親への返事に、「奥に骨を埋める覚悟」と書いた。筆が少し震えた。';
      }),
      if (l.mi >= 60)
        Choice.h('相手の人となりを奥の伝手で確かめてから決める', '人を見る目が通れば良い縁になる。相手方に知れれば角が立つ', () {
          if (g.rng.chance(.6)) {
            l.married = true;
            g.meet('伴侶', name, 65);
            g.j(8);
            g.setFlag('ok_yome_left');
            g.mark('奥の勤めを退き、$nameのもとへ嫁いだ');
            return '伝手の女中は「酒は飲むが、母御を大事にする人」と言った。あなたは縁談を受けた。';
          }
          g.j(1);
          g.setFlag('ok_oku_stayed');
          return '伝手の女中は、言いにくそうに首を振った。縁談は断り、奥に残った。';
        }, via: '魅'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 嫁いだ武家の女性

List<SceneDef> _wifeScenes() => [
  // ============================================ 筋: 婚家の姑 → 姑の病
  SceneDef('ok_shutome', 17, 40, (g) => _wWife, okWife, (g, next) {
    final l = g.l;
    g.ask('婚家の姑', '婚家の姑は、膳の味から針目まで、何一つ褒めない。今朝も、あなたの炊いた飯を「固い」と言って箸を置いた。', [
      Choice.h('黙って従い、姑の流儀を覚える', '家の中は荒れない。気は塞ぐ', () {
        _stamp(g, 'shutome');
        g.j(-4);
        g.setFlag('ok_shutome_bow');
        return '水加減を姑のやり方に変えた。姑は何も言わなかったが、箸を置くことはなくなった。';
      }),
      Choice.h('夫に間に入ってもらう', '夫しだいで楽になる。姑の目は冷たくなる', () {
        _stamp(g, 'shutome');
        g.setFlag('ok_shutome_cold');
        final sp = l.people['伴侶'];
        if (sp != null && sp.bond >= 50) {
          _spouse(g, 3);
          g.j(2);
          return '${sp.name}が「飯ぐらいで」と母をたしなめた。その晩から、姑はあなたと口をきかなくなった。';
        }
        g.j(-3);
        return '${_husband(g)}は「母の言うことを聞け」と言った。台所で、姑が聞こえよがしに笑った。';
      }),
      if (l.mi >= 60)
        Choice.h('姑の里の料理を習い、膳に出す', '心が通えば姑は味方になる。見え透いたと思われることもある', () {
          _stamp(g, 'shutome');
          if (g.rng.chance(clampD(.5 + l.mi / 300, .5, .85))) {
            g.j(5);
            _net(g, 1);
            g.setFlag('ok_shutome_won');
            return '姑の里の味噌で煮しめを作った。姑はひと口食べて、「母の味じゃ」とつぶやいた。';
          }
          g.j(-2);
          g.setFlag('ok_shutome_bow');
          return '姑は膳を見て、「誰に聞いた」とだけ言った。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('ok_shutome_byo', 20, 58, _w2, okWife, (g, next) {
    final l = g.l;
    if (g.hasFlag('ok_shutome_cold')) {
      g.ask('姑の病', '口もきかなくなっていた姑が、病に臥した。看病の手が足りないと、下女が言いに来た。', [
        Choice.h('枕元に座り、昔の非礼を詫びる', '溝が埋まるかもしれない。姑が受け入れるかは分からない', () {
          _stamp(g, 'shutome');
          if (g.rng.chance(clampD(.5 + l.mi / 300, .5, .85))) {
            g.j(5);
            g.setFlag('ok_shutome_keys');
            g.mark('長く冷えていた姑と、その病の床で和解した');
            return '姑は天井を見たまま、「わらわも嫁いだ日は泣いた」と言った。ほどなく、姑は静かに息を引き取った。';
          }
          g.j(-3);
          return '姑は顔を背けたまま、何も言わなかった。弔いの日、あなたは誰よりも長く手を合わせた。';
        }),
        Choice.h('形ばかり見舞う', '角は立たない。悔いが残るかもしれない', () {
          _stamp(g, 'shutome');
          g.j(-2);
          return '日に一度、枕元に顔を出した。ひと月ののち、姑は息を引き取った。';
        }),
      ], after: next);
      return;
    }
    g.ask('姑の病', '姑が病に臥した。床から、あなたを呼んでいる。', [
      Choice.h('夜通し看病する', '姑との溝は埋まる。体はこたえる', () {
        _stamp(g, 'shutome');
        l.hp -= 8;
        g.j(3);
        g.setFlag('ok_shutome_keys');
        g.mark('病に臥した姑を看取り、婚家の蔵の鍵を託された');
        return '姑は「この家を頼む」と、蔵の鍵をあなたの手に握らせた。ほどなく、眠るように息を引き取った。';
      }),
      Choice.h('下女に任せ、家の務めを続ける', '家は回る。姑の最後の言葉は聞けないかもしれない', () {
        _stamp(g, 'shutome');
        g.j(-2);
        return '台所と帳場を回しているうちに、姑は息を引き取った。最後に何を言ったのかは、下女も覚えていなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 留守の家
  SceneDef('ok_rusu', 18, 55, (g) => _wWife, okWife, (g, next) {
    final l = g.l;
    final who = _husband(g);
    g.ask('留守の家', '$whoが長陣に出て、もう半年になる。屋敷の蔵は細り、知行の村からは「年貢を待ってほしい」という願いが来た。郎党の給金も払わねばならない。', [
      Choice.h('村の願いを聞き、己の小袖を質に入れて給金を払う', '村も郎党も離れない。暮らしは切り詰める', () {
        _pay(g, 3);
        g.j(-2);
        _net(g, 3);
        _spouse(g, 5);
        g.setFlag('ok_rusu_kept');
        g.mark('夫の長陣の留守に、小袖を質に入れて郎党の給金を払い、家を守った');
        return '嫁入りの小袖を質に入れた。帰ってきた$whoは、郎党たちから話を聞き、しばらく黙ってあなたの手を見ていた。';
      }),
      Choice.h('村に年貢を急がせる', '蔵は持ち直す。村の恨みを買う', () {
        l.gold += 6;
        _net(g, -2);
        return '村の名主は、渋い顔で米を運んできた。道で行き会う村の女たちが、目を伏せるようになった。';
      }),
      if (l.sei >= 60)
        Choice.h('村と掛け合い、年貢の一部を麻や薪で納めさせる', '帳尻を合わせれば誰も困らない。手間はかかる', () {
          l.gold += 4;
          _net(g, 2);
          _spouse(g, 5);
          g.setFlag('ok_rusu_kept');
          g.setFlag('ok_rusu_wise');
          g.mark('夫の長陣の留守に、村と掛け合って屋敷の帳尻を合わせた');
          return '麻は郎党の女房たちに織らせ、薪は冬の分を蔵に積んだ。帰った$whoは帳面を見て、「わしより上手い」と笑った。';
        }, via: '政'),
    ], after: next);
  }),

  // ============================================ 筋: 夫の囲い女 → 囲い女の子
  SceneDef('ok_sobame', 22, 45, (g) => _wWife, okWife, (g, next) {
    final l = g.l;
    final who = _husband(g);
    g.ask('夫の囲い女', '$whoが城下の外れに女を囲っている、と下女が耳打ちしてきた。この頃、$whoの帰りが遅いのはそのためらしい。', [
      Choice.h('見て見ぬふりをする', '家の中は荒れない。胸の内は冷える', () {
        _stamp(g, 'sobame');
        g.j(-5);
        g.setFlag('ok_sobame_allow');
        return '何も聞かなかった顔で、夜食の膳を整えた。$whoは目を合わせずに箸を取った。';
      }),
      Choice.h('$whoを問いただす', '思いの丈は言える。夫婦の間に溝ができる', () {
        _stamp(g, 'sobame');
        _spouse(g, -10);
        g.j(1);
        g.setFlag('ok_sobame_confront');
        return '$whoは「武家の男の甲斐性だ」と言い捨てた。その晩、二人は背中合わせで眠った。';
      }),
      if (l.chi >= 60 || l.mi >= 60)
        Choice.h('自ら女のもとを訪ね、人となりを見る', '相手を知れば手の打ちようがある。夫の耳に入れば気まずい', () {
          _stamp(g, 'sobame');
          g.setFlag('ok_sobame_met');
          g.j(-1);
          return '女は、まだ若い機織りの娘だった。あなたを見るなり土間に手をついた。帰り道、怒りよりも、妙な哀れさが胸に残った。';
        }, via: '知魅'),
    ], after: next);
  }),

  _chain('ok_sobame_child', 24, 52, _w2, okWife, (g, next) {
    final l = g.l;
    final who = _husband(g);
    final child = g.rng.pick(kGivenM);
    g.ask('囲い女の子', '城下の女が、$whoの男子を産んだ。$whoは、あなたの顔色ばかりうかがっている。', [
      Choice.h('屋敷に引き取り、己の子として育てる', '家の跡取りが増える。女の恨みを買うかもしれない', () {
        _stamp(g, 'sobame');
        l.addKid(g.year);
        _spouse(g, 10);
        l.fame += 2;
        g.j(-2);
        g.meet('引き取った子', child, 50);
        g.setFlag('ok_sobame_raised');
        g.mark('夫が外に儲けた男子を屋敷に引き取り、己の子として育てた');
        return '赤子に$childと名をつけ、乳母を雇った。夜泣きのたびに、あなたが一番に起きた。';
      }),
      Choice.h('母子に銭を渡し、遠い国へ移らせる', '屋敷は乱れない。夫は黙って恨むかもしれない', () {
        _stamp(g, 'sobame');
        _pay(g, 8);
        _spouse(g, -8);
        g.setFlag('ok_sobame_sent');
        return '女は銭の包みを受け取り、赤子を抱いて街道を西へ下っていった。$whoは、その日一日、口をきかなかった。';
      }),
      Choice.h('$whoに任せ、口を出さない', '角は立たない。家の外に別の母子が残る', () {
        _stamp(g, 'sobame');
        g.j(-4);
        return '$whoは月に二度、城下の外れへ通うようになった。あなたは何も言わなかった。';
      }),
      if (g.hasFlag('ok_sobame_met'))
        Choice.h('女と話をつけ、母子ともに屋敷の離れに迎える', '人柄が通じれば家は一つになる。家中の口はうるさい', () {
          _stamp(g, 'sobame');
          if (g.rng.chance(clampD(.5 + l.mi / 300, .5, .85))) {
            l.addKid(g.year);
            _spouse(g, 12);
            _net(g, 2);
            g.meet('引き取った子', child, 60);
            g.setFlag('ok_sobame_raised');
            g.mark('夫が外に儲けた男子を、その母ともども屋敷の離れに迎えた');
            return '女は「この御恩は」と泣いた。離れから聞こえる$childの泣き声に、$whoはばつの悪そうな顔をした。';
          }
          g.j(-3);
          return '女は「情けは受けられませぬ」と言い、赤子を抱いて城下から姿を消した。';
        }),
    ], after: next);
  }),

  // ============================================ 捕らわれた夫
  SceneDef('ok_toraware', 20, 55, (g) => _wWife, (g) => okWife(g) && g.l.lord != null, (g, next) {
    final l = g.l;
    final who = _husband(g);
    final other = _otherName(g, _other(g));
    g.ask('捕らわれた夫', '$whoが、$otherとの小競り合いで捕らわれた、と郎党が知らせてきた。$otherは、身代の銭を出せば返すと言っている。', [
      Choice.h('家財を売り払って身代を工面する', '夫は帰ってくる。家は貧しくなる', () {
        l.gold = l.gold > 15 ? l.gold - 15 : 0;
        _spouse(g, 12);
        g.j(-3);
        g.setFlag('ok_toraware_ransom');
        return '嫁入り道具の鏡台まで売った。ひと月ののち、髭の伸びた$whoが門をくぐった。';
      }),
      Choice.h('主家に願い出て、捕虜の取り替えを頼む', '銭はかからない。主家が動くかは分からない', () {
        if (g.rng.chance(clampD(.35 + l.net * .01 + l.fav / 300, .35, .8))) {
          _spouse(g, 6);
          g.setFlag('ok_toraware_freed');
          return '主家は捕らえていた敵の侍と$whoを取り替えた。$whoは「主家に借りができた」と苦笑した。';
        }
        _spouse(g, 2);
        g.j(-6);
        return '願いは聞き届けられたが、取り替えの話は半年も滞った。帰ってきた$whoは、ひどく痩せていた。';
      }),
      if (l.mi >= 60 || l.chi >= 60)
        Choice.h('敵方の奥へ文を送り、女どうしで話をつける', '奥の伝手が通れば安く済む。表の者に知れれば内通を疑われる', () {
          if (g.rng.chance(clampD(.5 + (l.mi + l.chi) / 600, .5, .85))) {
            _spouse(g, 15);
            _net(g, 2);
            g.setFlag('ok_toraware_letter');
            g.mark('敵方の奥へ文を送り、捕らわれた夫を取り戻した');
            return '敵方の奥方から返事が来た。「妻の心は、敵も味方も同じ」。半月ののち、$whoは身代なしで帰された。';
          }
          _fav(g, -5);
          g.j(-4);
          return '文は敵方の表の者に渡り、主家の重臣に「内通ではないか」と問われた。$whoは結局、身代を払って帰された。';
        }, via: '知魅'),
    ], after: next);
  }),

  // ============================================ 筋: 実家と婚家の手切れ → 密書・両家の和
  SceneDef('ok_ryoke', 18, 50, (g) => _wWife, (g) => okWife(g) && g.l.lord != null && g.alive.length >= 2, (g, next) {
    final l = g.l;
    final other = _other(g);
    if (other != null) _keepName(g, 'ok_ryoke_house:', other);
    final oname = _otherName(g, other);
    final house = _lordHouse(g);
    g.ask('実家と婚家', '実家の父から文が届いた。実家が仕える$onameと、婚家の主家の$houseが手切れになったという。父は「戻ってこい」と書いている。', [
      Choice.h('婚家にとどまる', '夫と子のそばにいられる。実家とは敵どうしになる', () {
        _stamp(g, 'ryoke');
        _spouse(g, 8);
        g.j(-5);
        g.setFlag('ok_ryoke_stay');
        return '父への返事に、「嫁いだ家の土になります」と書いた。文を託した下男の背中を、門の外まで見送った。';
      }),
      Choice.h('離縁して実家へ帰る', '親のもとへ戻れる。夫と子とはこれきりになるかもしれない', () {
        _stamp(g, 'ryoke');
        l.married = false;
        l.people.remove('伴侶');
        g.j(-10);
        g.setFlag('ok_ryoke_left');
        g.mark('実家と婚家が手切れとなり、離縁して実家へ帰った');
        return '夜明け前、実家の迎えの者と共に屋敷を出た。振り返ると、門の内に、誰も立っていなかった。';
      }),
      if (l.chi >= 60 || l.mi >= 60)
        Choice.h('両家の間を文で取り持ち、手切れを思いとどまらせる', '和がなれば両家の恩人になる。どちらにも内通を疑われる', () {
          _stamp(g, 'ryoke');
          _net(g, 2);
          g.setFlag('ok_ryoke_bridge');
          return '父にも、婚家の舅にも、同じ日に文を書いた。どちらの返事にも、「女の出る幕ではない」とあった。それでも、筆を置かなかった。';
        }, via: '知魅'),
    ], after: next);
  }),

  _chain('ok_ryoke_after', 20, 55, _w2, okWife, (g, next) {
    final l = g.l;
    final hn = _named(g, 'ok_ryoke_house:', '');
    final oname = _otherName(g, hn.isEmpty ? null : hn);
    if (g.hasFlag('ok_ryoke_bridge')) {
      g.ask('両家の和', '文を取り持ち続けて二年、実家の$onameと婚家の主家が、和を結ぶかどうかの談合の席を設けることになった。女の身ながら、あなたにも席が用意された。', [
        Choice.h('談合の席に出て、両家の言い分を伝える', '知恵と人柄が通れば和がなる。しくじれば両家から責められる', () {
          _stamp(g, 'ryoke');
          if (g.rng.chance(clampD(.4 + (l.chi + l.mi) / 500, .4, .85))) {
            l.fame += 8;
            _fav(g, 6);
            g.setFlag('ok_ryoke_peace');
            g.mark('実家と婚家の主家のあいだを取り持ち、和を結ばせた');
            return '両家の重臣が、あなたの読み上げた文に黙ってうなずいた。談合のあと、父が初めて、あなたに頭を下げた。';
          }
          _fav(g, -6);
          g.j(-5);
          return '言い分を伝えるうち、両家の重臣が声を荒らげた。談合は物別れに終わり、どちらの家からも「出過ぎた女」と言われた。';
        }),
        Choice.h('表の者に任せて身を引く', '咎めは受けない。和の行方は分からない', () {
          _stamp(g, 'ryoke');
          g.j(-1);
          return '談合の席には出なかった。和がなったと聞いたのは、ひと月あとのことだった。';
        }),
      ], after: next);
      return;
    }
    g.ask('実家からの密書', '実家の兄から密書が届いた。「婚家の守りの手薄なところを知らせよ。さすれば、戦のあとに夫の命は助ける」とある。', [
      Choice.h('密書を夫に見せる', '婚家への忠は立つ。実家の兄とは縁が切れる', () {
        _stamp(g, 'ryoke');
        _spouse(g, 10);
        _fav(g, 4);
        g.setFlag('ok_ryoke_loyal');
        g.mark('実家の兄の密書を夫に見せ、婚家への忠を通した');
        return '${_husband(g)}は密書を読み、黙って炉にくべた。そして「つらかったな」とだけ言った。';
      }),
      Choice.h('燃やして、なかったことにする', '誰も裏切らずに済む。胸の内は晴れない', () {
        _stamp(g, 'ryoke');
        g.j(-4);
        return '密書を炉にくべた。紙の燃える匂いが、しばらく部屋に残った。';
      }),
      Choice.h('求めに応じて文を返す', '実家は助かるかもしれない。露見すれば命はない', () {
        _stamp(g, 'ryoke');
        if (g.rng.chance(.06)) {
          g.die('婚家の内情を実家へ漏らしたことが露見し、斬られた', 'seppuku');
          return '文を託した下男が、夜道で捕らえられた。';
        }
        g.j(-8);
        g.setFlag('ok_ryoke_spy');
        return '文は届いた。だが兄の兵は来ず、あなたの胸にだけ、秘め事が一つ残った。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 嫡男の手習い → 育った子
  SceneDef('ok_kyoiku', 25, 50, (g) => _wWife, (g) => okWife(g) && g.l.kids >= 1 && g.l.hasKidAged(g.year, 6, 12), (g, next) {
    final k = _sonName(g);
    _keepName(g, 'ok_kyoiku_name:', k);
    final who = _husband(g);
    g.ask('嫡男の手習い', '$kが手習いを始める年頃になった。$whoは「寺へ預けよ」と言い、舅は「武家の子は槍が先だ」と言う。', [
      Choice.h('寺へ預ける', '学は身につく。母の手は離れる', () {
        _stamp(g, 'kyoiku');
        g.j(-2);
        g.setFlag('ok_edu_tera');
        return '$kは、小さな文机を背負って山の寺へ上っていった。';
      }),
      Choice.h('己が手元で書と算を教える', '母子の縁は深まる。武芸は遅れる', () {
        _stamp(g, 'kyoiku');
        g.j(3);
        g.setFlag('ok_edu_self');
        return '夜ごと灯の下で、$kの手を取っていろはを書かせた。';
      }),
      Choice.h('舅の言うとおり、槍の稽古に出す', '武家の子らしく育つ。荒くなるかもしれない', () {
        _stamp(g, 'kyoiku');
        g.setFlag('ok_edu_bu');
        return '$kは、身の丈より長い竹槍を担いで、舅の後ろをついていった。';
      }),
    ], after: next);
  }),

  _chain(
    'ok_kyoiku_after',
    30,
    62,
    _w2,
    (g) =>
        okElder(g) &&
        g.active &&
        g.l.kids >= 1 &&
        g.l.hasKidAged(g.year, 12, 26),
    (g, next) {
      final l = g.l;
      final k = _named(g, 'ok_kyoiku_name:', '子');
      if (g.hasFlag('ok_edu_bu')) {
        g.ask('育った子', '$kが、稽古仲間との喧嘩で相手に傷を負わせた。相手の家は、詫びを入れよと言ってきている。', [
          Choice.h('子を連れて相手の家へ詫びに行く', '事は収まる。子は不満を抱くかもしれない', () {
            _stamp(g, 'kyoiku');
            _net(g, 2);
            g.setFlag('ok_edu_apology');
            return '$kの頭を押さえて、相手の家の門前で並んで頭を下げた。帰り道、$kは一言も口をきかなかったが、夜、「母上、すまぬ」と言いに来た。';
          }),
          Choice.h('武家の子の喧嘩と突っぱねる', '子の面目は立つ。相手の家との溝は深まる', () {
            _stamp(g, 'kyoiku');
            _net(g, -2);
            return '相手の家の使いは、顔を赤くして帰っていった。$kは得意げだった。';
          }),
          if (l.mi >= 60)
            Choice.h('相手の子も屋敷に招き、二人に盃を交わさせる', '人柄が通じれば仇が友になる。相手の家が受けるかは分からない', () {
              _stamp(g, 'kyoiku');
              if (g.rng.chance(.6)) {
                _net(g, 3);
                g.setFlag('ok_edu_friends');
                g.mark('喧嘩をした子とその相手に盃を交わさせ、仇を友に変えた');
                return '二人の若者は、ぎこちなく盃を合わせた。翌年の戦に、二人は並んで出ていった。';
              }
              _net(g, -1);
              return '相手の家は「詫びもせずに盃とは」と、招きを断った。';
            }, via: '魅'),
        ], after: next);
        return;
      }
      final tera = g.hasFlag('ok_edu_tera');
      g.ask('育った子', tera
          ? '寺で学んだ$kの手跡が評判になり、主家の祐筆に取り立てたいという話が来た。だが$kは、「槍を取って手柄を立てたい」と言う。'
          : 'あなたが灯の下で教えた$kの字が、家中で「よい手だ」と評判になり、主家の祐筆に取り立てたいという話が来た。だが$kは、「槍を取って手柄を立てたい」と言う。', [
        Choice.h('祐筆の話を受けさせる', '家の名が上がり、命も危うくない。子の望みはかなわない', () {
          _stamp(g, 'kyoiku');
          _fav(g, 3);
          l.fame += 2;
          g.setFlag('ok_edu_scribe');
          g.mark('育てた子の手跡が認められ、主家の祐筆に取り立てられた');
          return '$kは不服そうだったが、主家の文を書くうちに、殿の覚えもめでたくなった。';
        }),
        Choice.h('子の望みどおり、槍を取らせる', '子は思うままに生きる。戦場に出す母の胸は痛む', () {
          _stamp(g, 'kyoiku');
          g.j(-3);
          g.setFlag('ok_edu_spear');
          return '$kは晴れやかな顔で、父の古い具足を担いでいった。';
        }),
        Choice.h('子と夜通し話し合う', '母子の縁は深まる。答えが出るかは分からない', () {
          _stamp(g, 'kyoiku');
          g.j(2);
          return '明け方、$kは「母上の言うことも分かる」と言った。答えは、もう少し先に延ばすことになった。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 婚家の跡目
  SceneDef('ok_katoku', 24, 50, (g) => _wWife, okWife, (g, next) {
    final l = g.l;
    final who = _husband(g);
    g.ask('婚家の跡目', '舅が隠居を前に、跡目を$whoにするか、$whoの弟にするかで迷っている。弟の嫁は、もう舅の部屋へ足繁く通っている。', [
      Choice.h('黙って舅の決めるに任せる', '家に波風は立たない。跡目がどちらになるかは分からない', () {
        if (g.rng.chance(.5)) {
          _spouse(g, 3);
          g.setFlag('ok_katoku_won');
          return '舅は$whoを跡目に選んだ。弟の嫁は、その日から廊下であなたに道を譲らなくなった。';
        }
        g.j(-4);
        g.setFlag('ok_katoku_lost');
        return '舅は弟を跡目に選んだ。$whoは黙って、屋敷の離れへ移った。';
      }),
      Choice.h('一族の女たちを回って、$whoを推す声を集める', '人の縁が厚ければ跡目は夫に来る。弟の嫁と敵になる', () {
        if (g.rng.chance(clampD(.4 + l.net * .015 + l.mi / 400, .4, .85))) {
          _spouse(g, 10);
          _net(g, 1);
          g.setFlag('ok_katoku_won');
          g.mark('婚家の跡目争いで一族の女たちをまとめ、夫を跡目に据えた');
          return '叔母たちが口をそろえて舅に申し入れた。舅は苦笑して、「女たちには勝てぬ」と$whoを跡目に決めた。';
        }
        g.j(-6);
        g.setFlag('ok_katoku_lost');
        return '一族の女たちは「嫁の出る幕ではない」と口をそろえた。舅は弟を跡目に選んだ。';
      }),
      Choice.h('弟の嫁と話し合い、跡目のあとも支え合う約束を取り交わす', '跡目がどちらでも家は割れない。夫は物足りなく思う', () {
        _net(g, 3);
        _spouse(g, -2);
        g.setFlag('ok_katoku_peace');
        return '弟の嫁と並んで舅の前に出て、「どちらが継いでも、家は一つ」と申し上げた。舅は目を細め、跡目を決めるのを一年延ばした。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 主家の和の証 → 預けられた屋敷
  SceneDef('ok_hitojichi', 18, 45, (g) => _wWife, (g) => okWife(g) && g.l.rank >= 1 && g.l.lord != null && g.alive.length >= 2, (g, next) {
    final l = g.l;
    final other = _other(g);
    if (other != null) _keepName(g, 'ok_hitojichi_house:', other);
    final oname = _otherName(g, other);
    final house = _lordHouse(g);
    final kid = l.kids >= 1 && l.hasKidAged(g.year, 0, 12);
    g.ask('主家の和の証', '$houseが$onameと和を結ぶことになり、証として家臣の妻子を差し出すことになった。名の挙がった中に、あなたもいる。', [
      Choice.h(kid ? '幼い子を連れて$onameへ赴く' : '求めに応じて$onameへ赴く', '夫の家の面目が立つ。帰れる日は和の行方しだいだ', () {
        _stamp(g, 'hitojichi');
        _fav(g, 8);
        _spouse(g, 5);
        g.j(-6);
        g.setFlag('ok_hitojichi_went');
        g.mark('主家の和の証として、$onameの城下へ赴いた');
        return kid ? '子の手を引いて、$onameの城下へ向かう輿に乗った。子は輿の窓から、ずっと後ろを見ていた。' : '$onameの城下へ向かう輿に乗った。見送る${_husband(g)}の姿が、峠の向こうに消えた。';
      }),
      Choice.h('病と称して代わりを立ててもらう', '家を離れずに済む。夫の家の面目は潰れる', () {
        _stamp(g, 'hitojichi');
        _fav(g, -10);
        _spouse(g, -5);
        return '代わりに遠縁の娘が出されることになった。家中の女たちの目が、しばらく冷たかった。';
      }),
    ], after: next);
  }),

  _chain('ok_hitojichi_life', 19, 50, _w2, okWife, (g, next) {
    final l = g.l;
    final hn = _named(g, 'ok_hitojichi_house:', '');
    final oname = _otherName(g, hn.isEmpty ? null : hn);
    g.ask('預けられた屋敷', '$onameの城下の屋敷で暮らして一年あまり。$onameの奥方から、茶の席に招かれた。国からの文は、近ごろ途絶えがちだ。', [
      Choice.h('招きを受け、奥方と親しく交わる', '向こうの奥に味方ができる。国の者には怪しまれる', () {
        _stamp(g, 'hitojichi');
        _net(g, 3);
        g.setFlag('ok_hitojichi_friend');
        if (g.rng.chance(.6)) {
          l.flags.remove('ok_hitojichi_went');
          g.setFlag('ok_hitojichi_home');
          g.mark('預けられた$onameの奥方と心を通わせ、和が固まって国へ帰された');
          return '奥方とは、香を聞き合う仲になった。翌年、和が固まり、国へ帰されることになった。別れの日、奥方は手ずから縫った袋をくれた。';
        }
        return '奥方とは、香を聞き合う仲になった。国の者が、「敵の奥と親しすぎる」と陰で言っていると聞いた。';
      }),
      Choice.h('屋敷にこもり、ひっそりと日を送る', '何事も起きない。心は塞ぐ', () {
        _stamp(g, 'hitojichi');
        g.j(-5);
        return '庭の柿の実が色づくのを、三度数えた。';
      }),
      Choice.h('国へ逃げる手立てを探る', '逃げおおせれば家に帰れる。見つかれば命はない', () {
        _stamp(g, 'hitojichi');
        if (g.rng.chance(.05)) {
          g.die('預けられた屋敷を抜け出す夜に見咎められ、斬られた', 'ansatsu');
          return '裏木戸に手をかけたとき、背後で刀の鞘が鳴った。';
        }
        if (g.rng.chance(clampD(.45 + l.un / 300, .45, .8))) {
          l.flags.remove('ok_hitojichi_went');
          g.setFlag('ok_hitojichi_fled');
          _fav(g, -5);
          _spouse(g, 8);
          g.mark('預けられた$onameの屋敷を抜け出し、国へ逃げ帰った');
          return '物売りの女に身をやつし、三日歩き通して国境を越えた。主家の重臣は渋い顔をしたが、${_husband(g)}は門まで駆け出てきた。';
        }
        g.j(-8);
        _fav(g, -6);
        return '関所の手前で連れ戻された。屋敷の門には、見張りの足軽が立つようになった。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 後家と晩年

List<SceneDef> _lateScenes() => [
  // ============================================ 筋: 後家の暮らし → 髪を下ろすか
  SceneDef('ok_goke', 38, 75, (g) => _wOld, okWidow, (g, next) {
    final l = g.l;
    final old = l.people['伴侶']?.name ?? '夫';
    g.ask('後家の暮らし', '$oldを亡くして、屋敷はめっきり静かになった。親類は「隠居所を建てるから、そちらで静かに」と言う。', [
      Choice.h('隠居所に移り、家のことに口を出さない', '静かに暮らせる。家のことは見えなくなる', () {
        _stamp(g, 'goke');
        g.j(3);
        g.setFlag('ok_goke_quiet');
        return '隠居所の縁側に、$oldの好んだ盆栽を並べた。';
      }),
      Choice.h('屋敷にとどまり、家の内を取り仕切り続ける', '家は締まる。若い者は息が詰まる', () {
        _stamp(g, 'goke');
        _net(g, 1);
        l.gold += 3;
        g.setFlag('ok_goke_ruled');
        g.mark('夫亡きあとも屋敷にとどまり、家の内を取り仕切った');
        return '蔵の鍵は手放さなかった。台所の女たちは、あなたの足音を聞くと背筋を伸ばした。';
      }),
      if (l.maxRank >= 2)
        Choice.h('奥の伝手を頼って、城下の娘たちに作法を教える', '己の暮らしが立つ。親類は世間体を気にする', () {
          _stamp(g, 'goke');
          l.gold += 4;
          l.fame += 2;
          g.j(2);
          g.setFlag('ok_goke_teach');
          g.mark('夫亡きあと、城下の娘たちに奥の作法を教えた');
          return '座敷に娘たちを集め、膳の運び方から教えた。親類は眉をひそめたが、娘の親たちは礼の品を絶やさなかった。';
        }),
    ], after: next);
  }),

  _chain('ok_rakushoku', 42, 85, _w2, okWidow, (g, next) {
    final old = g.l.people['伴侶']?.name ?? '夫';
    g.ask('髪を下ろすか', '$oldの年忌が近い。菩提寺の住持が「髪を下ろし、家にあって菩提を弔ってはどうか」と勧めてきた。', [
      Choice.h('髪を下ろし、家にあって菩提を弔う', '心は静まる。世の華やぎからは身を引く', () {
        _stamp(g, 'goke');
        g.j(5);
        g.setFlag('ok_rakushoku');
        g.mark('亡き夫の菩提を弔うため、家にあって髪を下ろした');
        return '住持の剃刀が、肩のあたりで髪を断った。軽くなった頭で、$oldの位牌に手を合わせた。';
      }),
      Choice.h('髪はそのままに、寺へ寄進を続ける', '俗の暮らしは保てる。銭はかかる', () {
        _stamp(g, 'goke');
        _pay(g, 5);
        g.j(2);
        g.setFlag('ok_goke_kishin');
        return '年忌ごとに、寺へ米と灯明料を届けた。';
      }),
      Choice.h('住持の勧めを断り、家の務めに戻る', '家の役に立てる。迷いは残る', () {
        _stamp(g, 'goke');
        _net(g, 1);
        return '「まだ、家にやることがございます」と答えた。住持は笑って、それ以上は勧めなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 孫娘の嫁ぎ先
  SceneDef('ok_mago_yome', 50, 85, (g) => _wOld, (g) => okElder(g) && g.l.kids >= 1 && g.l.hasKidAged(g.year, 32), (g, next) {
    final l = g.l;
    final m = g.rng.pick(kGivenF);
    g.ask('孫娘の嫁ぎ先', '孫娘の$mに縁談が来た。先方は格の高い家だが、婿は気性が荒いと噂される。子らは、祖母のあなたの考えを聞きに来た。', [
      Choice.h('家のためと、縁談を勧める', '家の格は上がる。孫娘の行く末は分からない', () {
        _fav(g, 2);
        g.j(-2);
        return '$mは黙って頭を下げた。祝言の日、あなたは$mの帯を自ら結んでやった。';
      }),
      Choice.h('婿の人となりを、昔の伝手で確かめさせる', '確かな縁になる。先方に知れれば角が立つ', () {
        if (g.rng.chance(clampD(.45 + l.net * .01, .45, .85))) {
          g.j(3);
          g.setFlag('ok_mago_checked');
          g.mark('孫娘の縁談の相手を昔の伝手で確かめ、孫娘を荒い婿から守った');
          return '昔の伝手の女が、婿が下女を打ち据えた話を確かめてきた。縁談は断り、翌年、$mはおだやかな家へ嫁いだ。';
        }
        _net(g, -1);
        return '先方に知れて、「祖母どのが嗅ぎ回っている」と言われた。縁談は流れ、子らは困った顔をした。';
      }),
      Choice.h('孫娘の気持ちを聞いてやる', '孫娘は救われる。子らの面目は潰れるかもしれない', () {
        g.j(4);
        g.setFlag('ok_mago_heard');
        return '$mは、あなたの膝で泣いた。「おばばさまだけが聞いてくれた」と。';
      }),
      if (l.un >= 60)
        Choice.h('氏神の御籤を引いて、成り行きを占う', '人の噂より、神の前の一本に任せる。吉と出ても凶と出ても、それに従う', () {
          if (g.luck()) {
            g.j(4);
            _net(g, 2);
            return '引いた御籤は「待てば良縁」。縁談を一年延ばしてもらううちに、婿は遠国の番に遣わされ、代わりに来た弟のほうが、おだやかな人だった。$mは、その弟に嫁いだ。';
          }
          g.j(-1);
          return '引いた御籤は「末吉」。吉とも凶ともつかず、子らは首をひねった。縁談は、結局そのまま進んだ。';
        }, via: '運'),
    ], after: next);
  }),

  // ============================================ 奥の朋輩との再会（奥の男の影の筋の終わり）
  _chain('ok_houbai_reunion', 42, 85, _wOld, okElder, (g, next) {
    final f = _named(g, 'ok_houbai_name:', '朋輩');
    final saved = g.hasFlag('ok_houbai_saved');
    g.ask('奥の朋輩', '寺の縁日で、年老いた女に呼び止められた。かつて奥で共に勤めた$fだった。${saved ? '後ろに、背の高い若者が控えている。' : ''}', [
      Choice.h('茶屋に誘い、昔話に日を暮らす', '心が若返る。帰りは遅くなる', () {
        _stamp(g, 'houbai');
        g.j(8);
        _bondOf(g, '奥の朋輩', 10);
        g.setFlag('ok_houbai_reunited');
        g.mark('若い日に奥で共に勤めた$fと、老いてから再会した');
        return saved
            ? '若者は、あの夜に里へ帰した子だった。$fは「この子の命の恩人」と、若者にあなたを拝ませた。'
            : '奥の年寄の口癖を真似て、二人で涙が出るほど笑った。';
      }),
      Choice.h('会釈だけして別れる', '昔は昔のこと。あとで悔やむかもしれない', () {
        _stamp(g, 'houbai');
        g.j(-2);
        return '会釈を交わして、人波に紛れた。家に帰ってから、$fの好きだった菓子の名を思い出した。';
      }),
    ], after: next);
  }),
];
