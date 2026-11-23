import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 中堅の侍の岐路（2026-11-23）。id・旗は `rt_`。
///
/// 足軽（位1〜2）は `ashigaru.dart`・`ashigaru_life.dart`、城主以上（位5〜）は `lords.dart` に厚い岐路があるが、
/// その間の馬廻・侍大将（女性なら奥女中・上臈）の年、主君の近くで仕え、兵を率い始める段に固有の岐路が少なかったので足した。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kRetainerPrev]）。段を踏んだ年は
/// 旗 `rt_at:<筋>:<年>` に残し、次の段は何年か空けてから出す（[kRetainerGap]）。
///
/// - 主君の側で: 寵臣との張り合い → 寵臣が主君の怒りを買う（張り合った・取り入った・離れていたで手が分かれる）／
///   主君の秘密（胸に納める・重臣に知らせる・知60で主君に申し上げる）→ 主君に試される／
///   傅役（厳しく・慈しんで）→ 若君の元服 → 若君の初めての戦／口上の使い・婚儀の使い・鷹狩りの供・宿直・年始の席次。
/// - 兵を率いる: 新しく付いた配下（古参を立てる・若者を鍛える・掟で当たる）→ 配下の不始末／手柄を配下に譲るか。
///   知行地（定めどおり・軽く・重く）→ 軽く・定めどおりなら堤の普請、重くしたなら百姓の直訴。
/// - 家中の政: 譜代と新参（どちらにつくか）→ 争いが表に出る／普請の奉行／重臣の娘との縁組。
/// - 奥で仕える女性（奥女中・上臈、未婚）: 奥の派閥（御台所方・側室方）→ 側室が男子を産んだあと／若君の乳母の座／御台所の使い。
///   主君の秘密・年始の席次・婚儀（女性は嫁入りの支度）は書き分けて女性にも出す。
/// - 位は上げない（城主への道は `game.dart` の昇進に任せ、功・信頼・名声で返す）。
/// - 能力（武・知・政・魅・運）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

/// 馬廻・侍大将（奥女中・上臈）として仕えている（位3〜4・隠居でない・仏門でない・主家が生きている）。
bool rtServing(Game g) =>
    g.l.rank >= 3 &&
    g.l.rank <= 4 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 兵を率いる侍（男）。
bool rtSamurai(Game g) => rtServing(g) && !g.l.female && g.canFight;

/// 奥で仕える女性（嫁いでいない）。
bool rtOku(Game g) => rtServing(g) && g.l.female && !g.l.married;

/// この岐路が出てよい人（侍か、奥で仕える女性）。テストも使う。
bool rtLife(Game g) => rtSamurai(g) || rtOku(g);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kRetainerPrev = <String, List<String>>{
  'rt_chohei_fall': ['rt_chohei_rival', 'rt_chohei_ally', 'rt_chohei_apart'],
  'rt_himitsu_test': ['rt_secret_kept', 'rt_secret_told', 'rt_secret_owned'],
  'rt_mori_genpuku': ['rt_mori_strict', 'rt_mori_kind'],
  'rt_mori_uijin': ['rt_mori_grown'],
  'rt_haika_fault': ['rt_haika_kosan', 'rt_haika_young', 'rt_haika_strict'],
  'rt_haika_tegara': ['rt_haika_kosan', 'rt_haika_young', 'rt_haika_strict'],
  'rt_chigyo_mizu': ['rt_chigyo_fair', 'rt_chigyo_light'],
  'rt_chigyo_uttae': ['rt_chigyo_heavy'],
  'rt_habatsu_clash': ['rt_habatsu_fudai', 'rt_habatsu_shinzan', 'rt_habatsu_none'],
  'rt_o_habatsu_after': ['rt_o_midai', 'rt_o_sokushitsu', 'rt_o_apart'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kRetainerGap = <String, (String, int)>{
  'rt_chohei_fall': ('chohei', 2),
  'rt_himitsu_test': ('himitsu', 1),
  'rt_mori_genpuku': ('mori', 2),
  'rt_mori_uijin': ('mori', 1),
  'rt_haika_fault': ('haika', 1),
  'rt_haika_tegara': ('haika', 2),
  'rt_chigyo_mizu': ('chigyo', 1),
  'rt_chigyo_uttae': ('chigyo', 1),
  'rt_habatsu_clash': ('habatsu', 2),
  'rt_o_habatsu_after': ('ohabatsu', 2),
};

/// この岐路の id（テストが使う）。
const kRetainerLifeIds = [
  'rt_chohei',
  'rt_chohei_fall',
  'rt_himitsu',
  'rt_himitsu_test',
  'rt_moriyaku',
  'rt_mori_genpuku',
  'rt_mori_uijin',
  'rt_shisha',
  'rt_kongi',
  'rt_takagari',
  'rt_tonoi',
  'rt_sekiji',
  'rt_haika',
  'rt_haika_fault',
  'rt_haika_tegara',
  'rt_chigyo',
  'rt_chigyo_mizu',
  'rt_chigyo_uttae',
  'rt_habatsu',
  'rt_habatsu_clash',
  'rt_bugyo',
  'rt_konin',
  'rt_o_habatsu',
  'rt_o_habatsu_after',
  'rt_o_menoto',
  'rt_o_tsukai',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('rt_at:$chain:'));
  g.setFlag('rt_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int rtSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('rt_at:$chain:')) {
      return g.year - int.parse(f.substring('rt_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool rtChainReady(Game g, String id) {
  final prev = kRetainerPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kRetainerGap[id];
  if (gap == null) return true;
  return rtSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

int _c(int v) => clampInt(v, 0, 100);
void _fav(Game g, int n) => g.l.fav = _c(g.l.fav + n);
void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

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

/// 主家に近いほかの家（内部の名）。いなければ null。
String? _other(Game g) {
  final lf = g.l.lord;
  if (lf == null) return null;
  final c = nearest(g.alive.where((f) => f.name != lf), (f) => f.name, faction: lf, n: 3);
  return c.isEmpty ? null : g.rng.pick(c).name;
}

String _otherName(Game g, String? f) => f == null ? '隣国の家' : '${houseName(g, f)}家';

/// 主君の呼び方（侍は「主君」、奥の女性は「殿」）。
String _lordWord(Game g) => g.l.female ? '殿' : '主君';

void _bond(Person? p, int n) {
  if (p != null) p.bond = _c(p.bond + n);
}

/// 重み。筋の始まり・ひとつきりは [_w1]、前の段を踏んだ人だけに出る後段は [_w2]。
const _w1 = 6.0;
const _w2 = 30.0;

/// 奥で仕える女性に出る場面の重み（女性に出せる場面は侍より少なく、嫁げば出なくなるため重くする）。
double _wf(Game g) => g.l.female ? _w1 * 1.6 : _w1;

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
  (g) => who(g) && rtChainReady(g, id),
  run,
);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildRetainerLifeScenes() => [
  ..._sideScenes(),
  ..._commandScenes(),
  ..._houseScenes(),
  ..._okuScenes(),
];

// ---------------------------------------------------------------- 主君の側で

List<SceneDef> _sideScenes() => [
  // ============================================ 筋: 寵臣
  SceneDef('rt_chohei', 18, 50, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    final n = '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
    _keepName(g, 'rt_chohei_name:', n);
    g.ask('寵臣との張り合い', '主君の側に仕える者のなかに、$nという小姓あがりの若い侍がいる。主君は何かにつけて$nを呼び、近ごろは、あなたが申し上げることまで$nの口から先に主君の耳に入っている。', [
      Choice.h('槍働きで張り合う', '手柄で並べば主君の目も変わる。張り合えば角が立つ', () {
        l.merit += 3;
        l.fame += 2;
        _fav(g, 1);
        g.setFlag('rt_chohei_rival');
        _stamp(g, 'chohei');
        return '次の戦で、$nより先に敵の柵へ取りついた。主君は「どちらも頼もしい」と笑ったが、$nの目はもう笑っていなかった。';
      }),
      Choice.h('$nに取り入る', '主君への道は通りやすくなる。寵臣の浮き沈みに巻き込まれる', () {
        _pay(g, 3);
        _fav(g, 4);
        _net(g, 1);
        g.setFlag('rt_chohei_ally');
        _stamp(g, 'chohei');
        return '国の名産の干し柿を届けると、$nは「おぬしの話は、わしから殿に申し上げておこう」と請け合った。';
      }),
      Choice.h('張り合わず、己の務めに励む', '目立ちはしない。恨みも買わない', () {
        g.j(1);
        g.setFlag('rt_chohei_apart');
        _stamp(g, 'chohei');
        return '寵臣の噂には耳を貸さず、馬の世話と槍の稽古に明け暮れた。';
      }),
      if (l.mi >= 60)
        Choice.h('$nと酒を酌み交わし、腹を割って話す', '人柄が通じれば味方になる。下心と見られることもある', () {
          _stamp(g, 'chohei');
          if (g.rng.chance(clampD(.45 + l.mi / 300, .45, .85))) {
            _net(g, 3);
            _fav(g, 2);
            g.setFlag('rt_chohei_ally');
            g.setFlag('rt_chohei_friend');
            return '夜更けまで飲んだ。$nは「殿の側は寂しいものよ」とこぼし、帰り際に深く頭を下げた。';
          }
          _fav(g, -2);
          g.setFlag('rt_chohei_rival');
          return '$nは盃に口もつけず、「何が望みだ」と言った。それきり、二人の間には冷たい風が吹いた。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('rt_chohei_fall', 20, 55, _w2, rtSamurai, (g, next) {
    final l = g.l;
    final n = _named(g, 'rt_chohei_name:', '寵臣');
    final rival = g.hasFlag('rt_chohei_rival');
    final ally = g.hasFlag('rt_chohei_ally');
    g.ask('寵臣の失脚', '$nが主君の怒りを買った。酒の席で、主君の亡き父を軽んじる戯れ言を口にしたという。主君は「腹を切らせよ」と言い放ち、家中は静まり返っている。', [
      Choice.h('命乞いに加わる', '寵臣は救われるかもしれない。主君の怒りがこちらへ向くこともある', () {
        _stamp(g, 'chohei');
        final p = .4 + l.mi / 300 + l.fav / 400 + (ally ? .1 : 0) + (rival ? .1 : 0);
        if (g.rng.chance(clampD(p, .35, .85))) {
          _net(g, 3);
          g.j(4);
          l.fame += 2;
          g.setFlag('rt_chohei_saved');
          g.mark('主君の怒りを買った同輩の命乞いに進み出て、許しを得た');
          return rival
              ? '張り合ってきたあなたが進み出たので、主君は驚いた顔をした。やがて「そなたがそこまで言うなら」と刀を収めた。$nは、地に額をつけたまま震えていた。'
              : '膝をついて頭を下げ続けた。主君は長い沈黙ののち「蟄居でよい」と言った。$nは、あとで一人で礼に来た。';
        }
        _fav(g, -6);
        g.j(-4);
        return '「そなたも同じ心か」と主君に睨まれ、座を下がらされた。$nは、翌朝、腹を切った。';
      }),
      Choice.h('黙って見届ける', '巻き込まれずに済む。家中の目が冷たくなることもある', () {
        _stamp(g, 'chohei');
        g.setFlag('rt_chohei_silent');
        g.j(-3);
        if (ally) {
          _fav(g, -3);
          return '$nは、翌朝、腹を切った。寵臣に近かった者として、あなたもしばらく主君の座敷から遠ざけられた。';
        }
        return '$nは、翌朝、腹を切った。主君は何事もなかったように、次の鷹狩りの日取りを決めた。';
      }),
      if (rival)
        Choice.h('空いた席を狙って働く', '主君の側に上がれる。人の不幸に乗ったと陰で言われる', () {
          _stamp(g, 'chohei');
          _fav(g, 6);
          l.merit += 2;
          _net(g, -2);
          g.j(-2);
          g.setFlag('rt_chohei_took');
          return '$nのいた座敷の隅に、いつのまにかあなたが座るようになった。陰で「鳶のようだ」と言う者もいた。';
        }),
    ], after: next);
  }),

  // ============================================ 筋: 主君の秘密（奥の女性にも出る）
  SceneDef('rt_himitsu', 18, 55, _wf, rtLife, (g, next) {
    final l = g.l;
    final e = _otherName(g, _other(g));
    final lw = _lordWord(g);
    final text = l.female
        ? '夜更けに奥の離れへ茶を運ぶと、殿が見慣れぬ僧形の男と向き合っていた。漏れ聞こえた言葉から、相手は敵方の$eの使いだと分かった。'
        : '宿直の夜、主君の居間の明かりが遅くまで消えなかった。障子の影に、見慣れぬ僧形の男がいる。漏れ聞こえた言葉から、相手は敵方の$eの使いだと分かった。';
    g.ask('$lwの秘め事', text, [
      Choice.h('見なかったことにして胸に納める', '$lwの秘密を守る。重荷を一人で抱える', () {
        g.j(-1);
        g.setFlag('rt_secret_kept');
        _stamp(g, 'himitsu');
        return '何も見なかった顔で、そっとその場を離れた。その夜は、なかなか眠れなかった。';
      }),
      Choice.h('重臣にそっと知らせる', '家のためにはなる。$lwがそれを知れば危うい', () {
        l.merit += 2;
        g.setFlag('rt_secret_told');
        _stamp(g, 'himitsu');
        return '翌朝、古くから仕える重臣の屋敷を訪ね、見たことだけを伝えた。重臣は黙って聞き、「よう知らせた」と言った。';
      }),
      if (l.chi >= 60)
        Choice.h('翌朝、胸に納めたとだけ$lwに申し上げる', '才が通じれば信を得る。$lwの顔色しだいだ', () {
          g.setFlag('rt_secret_owned');
          _stamp(g, 'himitsu');
          if (g.rng.chance(clampD(.55 + l.chi / 400, .55, .85))) {
            _fav(g, 5);
            return '$lwはしばらく黙っていたが、やがて「そなたは口が堅いか」と問い、うなずくと、小さく笑った。';
          }
          _fav(g, -4);
          return '$lwの顔が、さっと青ざめた。「余計なことを」と言い捨てて、席を立った。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('rt_himitsu_test', 19, 58, _w2, rtLife, (g, next) {
    final l = g.l;
    final lw = _lordWord(g);
    if (g.hasFlag('rt_secret_told')) {
      g.ask('$lwの問いただし', '重臣が$lwを諫めたという。$lwは「誰が告げた」と、あの夜に近くにいた者を一人ずつ呼び出している。次は、あなたの番だ。', [
        Choice.h('告げたのは己だと名乗り出る', '筋は通る。$lwの怒りを正面から受ける', () {
          _stamp(g, 'himitsu');
          if (g.rng.chance(clampD(.45 + l.mi / 400 + l.fav / 400, .4, .8))) {
            _fav(g, 3);
            l.fame += 2;
            g.setFlag('rt_secret_named');
            return '$lwは長いことあなたを見ていたが、「家を思うてのことか」とだけ言い、それきり咎めなかった。';
          }
          _fav(g, -12);
          g.j(-5);
          return '$lwは扇で膝を打ち、「下がれ」と言った。それから長いあいだ、あなたが側に呼ばれることはなかった。';
        }),
        Choice.h('知らぬと黙り通す', '名は伏せたままだ。疑いの目は消えない', () {
          _stamp(g, 'himitsu');
          if (g.rng.chance(.04)) {
            g.die('$lwの秘め事を漏らしたと疑われ、帰りの夜道で何者かに斬り捨てられた', 'ansatsu');
            return '屋敷へ戻る道の暗がりに、誰かが立っていた。';
          }
          _fav(g, -4);
          return '「存じませぬ」と言い通した。$lwは何も言わなかったが、それからは目を合わせなくなった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('rt_secret_owned')) {
      g.ask('$lwの相談', '$lwが、また一人であなたを呼んだ。人払いをした座敷で、「あの件、そなたならどう見る」と声を落とした。', [
        Choice.h('和を結ぶのが家のためと申し上げる', '$lwの迷いに寄り添う。家中には知られぬ重荷が増える', () {
          _fav(g, 6);
          l.merit += 3;
          g.setFlag('rt_confidant');
          _stamp(g, 'himitsu');
          g.mark('$lwの秘めた談合に、ひそかに相談を受ける身となった');
          return '$lwは深くうなずき、「そなたに聞いてよかった」と言った。';
        }),
        Choice.h('敵方の使いは偽りかもしれぬと申し上げる', '用心は家を守る。$lwの望みに水を差す', () {
          _fav(g, 3);
          l.merit += 2;
          g.setFlag('rt_confidant');
          _stamp(g, 'himitsu');
          g.mark('$lwの秘めた談合に、ひそかに相談を受ける身となった');
          return '$lwは眉をひそめたが、「たしかめてみよう」と言った。座敷を下がるとき、背中に視線を感じた。';
        }),
        Choice.h('己の分を越えると辞する', '危うい話から離れられる。$lwの信は少し離れる', () {
          _fav(g, -2);
          _stamp(g, 'himitsu');
          return '「それは重臣の方々に」と頭を下げた。$lwは「そうか」と言い、それきりその話はしなかった。';
        }),
      ], after: next);
      return;
    }
    // 胸に納めた者。
    g.ask('$lwの試し', '$lwに一人で呼ばれた。「あの夜、そなたは見ておったな」。$lwは目を細めた。「口の堅い者が要る」', [
      Choice.h('密かな使いを引き受ける', '$lwの信は厚くなる。敵方との文を運ぶのは危うい', () {
        _fav(g, 8);
        l.merit += 4;
        g.setFlag('rt_confidant');
        _stamp(g, 'himitsu');
        g.mark('$lwの秘めた談合を胸に納め、密かな使いを任された');
        return l.female
            ? '奥の文箱に紛れさせて、敵方への文を運んだ。誰にも気づかれなかった。'
            : '商人の身なりで国境を越え、敵方の寺へ文を届けた。戻ると、$lwは黙って盃をくれた。';
      }),
      Choice.h('何も存じませぬと押し通す', '巻き込まれずに済む。$lwは少し寂しそうな顔をする', () {
        _fav(g, 1);
        _stamp(g, 'himitsu');
        return '「何も存じませぬ」と頭を下げた。$lwは「それでよい」と笑ったが、目は笑っていなかった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 傅役
  SceneDef('rt_moriyaku', 22, 55, (g) => _w1 + (g.l.rank == 4 ? 1 : 0), rtSamurai, (g, next) {
    final l = g.l;
    final k = g.rng.pick(kHeirNames);
    g.ask('傅役', '主君の若君、$kは数えで十二になる。主君があなたを呼び、「$kの傅役を頼みたい」と言った。若君の守り育ては、家の行く末を預かる役目だ。', [
      Choice.h('厳しく鍛える', '強い主に育つかもしれない。若君には煙たがられる', () {
        g.meet('傅いた若君', k, 40);
        _fav(g, 4);
        l.merit += 2;
        g.setFlag('rt_mori_strict');
        _stamp(g, 'mori');
        return '夜明け前から木刀を握らせた。$kは歯を食いしばりながらも、決して木刀を放さなかった。';
      }),
      Choice.h('慈しんで育てる', '若君に慕われる。甘いと言う者もいる', () {
        g.meet('傅いた若君', k, 65);
        _fav(g, 4);
        g.j(3);
        g.setFlag('rt_mori_kind');
        _stamp(g, 'mori');
        return '野に連れ出しては、草の名や鳥の声を教えた。$kは、何かあるとまずあなたのもとへ駆けてくるようになった。';
      }),
      if (l.chi >= 60)
        Choice.h('読み書きと兵法を自ら教える', '知恵のある主に育つ。教える者の才が問われる', () {
          g.meet('傅いた若君', k, 55);
          _fav(g, 5);
          l.merit += 2;
          g.setFlag('rt_mori_strict');
          g.setFlag('rt_mori_learned');
          _stamp(g, 'mori');
          return '文机を並べ、孫子の一節を読み聞かせた。$kは、わからぬところを何度でも尋ねてきた。';
        }, via: '知'),
      Choice.h('荷が重いと辞する', '気楽ではある。主君の期待を裏切る', () {
        _fav(g, -4);
        _stamp(g, 'mori');
        return '主君は「そうか」と言い、ほかの者を傅役に選んだ。';
      }),
    ], after: next);
  }),

  _chain(
    'rt_mori_genpuku',
    25,
    60,
    _w2,
    (g) => rtSamurai(g) && g.l.people.containsKey('傅いた若君'),
    (g, next) {
      final l = g.l;
      final p = l.people['傅いた若君']!;
      final strict = g.hasFlag('rt_mori_strict');
      final word = strict ? '「そなたには、よう叱られた」と苦笑した。' : '「そなたがおらねば、ここまで来られなんだ」と目を潤ませた。';
      g.ask('若君の元服', '${p.name}が元服の日を迎えた。烏帽子をかぶった若君が、あなたの前で頭を下げ、$word', [
        Choice.h('若君の側近として仕えたいと願い出る', '若君の代に重く用いられる。いまの主君の側からは遠のく', () {
          _bond(p, 15);
          _fav(g, 2);
          g.setFlag('rt_mori_grown');
          g.setFlag('rt_mori_close');
          _stamp(g, 'mori');
          return '主君は「それがよかろう」と言った。その日から、${p.name}の座敷の次の間が、あなたの詰め所になった。';
        }),
        Choice.h('一歩退いて見守る', '出しゃばらずに済む。縁は細くなる', () {
          _bond(p, -5);
          g.setFlag('rt_mori_grown');
          _stamp(g, 'mori');
          return '祝いの席の末座で、${p.name}の晴れ姿を見ていた。それで十分だった。';
        }),
        if (strict)
          Choice.h('最後に一つ、厳しい言葉を贈る', '若君の胸に残る。祝いの席に水を差す', () {
            _bond(p, 8);
            l.fame += 2;
            g.setFlag('rt_mori_grown');
            _stamp(g, 'mori');
            return '「主は、家臣の命を預かる身にございます」。座が静まった。${p.name}は、長いことあなたの顔を見ていた。';
          }),
      ], after: next);
    },
  ),

  _chain(
    'rt_mori_uijin',
    26,
    62,
    _w2,
    (g) => rtSamurai(g) && g.l.people.containsKey('傅いた若君'),
    (g, next) {
      final l = g.l;
      final p = l.people['傅いた若君']!;
      final ef = _other(g);
      final en = _otherName(g, ef);
      g.ask('若君の初めての戦', '${p.name}が、はじめて戦に出ることになった。敵は$enの勢だ。主君は「傅役のそなたが付いてやれ」と言った。', [
        Choice.h('若君の脇を固める', '若君は守れる。矢面に立てば命がけだ', () {
          _stamp(g, 'mori');
          if (g.rng.chance(.03)) {
            g.die('傅いた若君の脇を固めて敵の槍の前に立ち、身代わりとなって果てた', 'senshi');
            return '若君へ伸びた槍の穂先の前に、身を投げ出した。';
          }
          final r = g.battle('main', enemy: ef, risk: 1.1, gain: .8);
          if (l.dead != null) return '若君の馬の轡を取り、寄せてくる敵を払い続けた。$r';
          _bond(p, 12);
          _fav(g, 6);
          g.setFlag('rt_mori_shielded');
          g.mark('傅いた若君の初めての戦で、その脇を固めて守り抜いた');
          return '若君の馬の轡を取り、寄せてくる敵を払い続けた。$r';
        }),
        Choice.h('若君に手柄を立てさせる', '若君の名は上がる。危うい所へ連れて行くことになる', () {
          _stamp(g, 'mori');
          _bond(p, 6);
          g.setFlag('rt_mori_glory');
          final r = g.battle('van', enemy: ef, risk: 1.0, gain: 1.0);
          if (l.dead != null) return r;
          return '若君と並んで敵の柵へ駆け寄り、若君の槍が敵の雑兵を突き伏せるのを見届けた。$r';
        }),
        Choice.h('後ろに控えさせ、戦を見せるだけにする', '若君は無事だ。物足りなく思うかもしれない', () {
          _stamp(g, 'mori');
          _bond(p, -3);
          final r = g.battle('rear', enemy: ef);
          return '後詰めの陣から、戦の流れを指さして教えた。若君は唇を噛んで、前の方ばかり見ていた。$r';
        }),
      ], after: next);
    },
  ),

  // ============================================ ひとつきり
  SceneDef('rt_shisha', 20, 55, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    final h = _otherName(g, _other(g));
    g.ask('口上の使い', '主君の口上を携えて$hへ遣わされた。国境の争いについての申し入れだ。$hの当主は口上を聞くなり、脇息を叩いて「帰って主にそう伝えよ」と怒鳴った。', [
      Choice.h('怯まずに口上を最後まで述べる', '胆が据わっていれば一目置かれる。相手の怒りを煽るかもしれない', () {
        if (g.rng.chance(clampD(.3 + (l.bu + l.mi) / 400, .3, .8))) {
          l.fame += 4;
          _fav(g, 4);
          l.merit += 2;
          g.setFlag('rt_shisha_firm');
          g.mark('使者として他家へ赴き、怒鳴る当主の前で主君の口上を述べ切った');
          return '声を落とさずに最後まで述べた。当主は黙り込み、やがて「肝の太い使いよ」と言って、返書を持たせた。';
        }
        _fav(g, -3);
        l.hp -= 5;
        return '口上の途中で、侍たちに両腕を取られて門の外へ放り出された。主君は返事のないことに顔をしかめた。';
      }),
      Choice.h('頭を下げて引き下がる', '無事に帰れる。主君は不満だろう', () {
        _fav(g, -2);
        return '平伏して座を下がった。帰りの道で、口上の続きを何度も胸の内で繰り返した。';
      }),
      if (l.chi >= 60)
        Choice.h('先方の家老にひそかに会って話を通す', '裏の道が開けば話はまとまる。表の面目は立たない', () {
          _fav(g, 5);
          l.merit += 3;
          g.setFlag('rt_shisha_back');
          return '夜、家老の屋敷の裏木戸を叩いた。家老は「当主はああ言うが」と苦笑し、国境の杭を少し引く約束をした。';
        }, via: '知'),
    ], after: next);
  }),

  // 婚儀の使い（侍）／嫁入りの支度（奥の女性）。
  SceneDef('rt_kongi', 20, 55, _wf, rtLife, (g, next) {
    final l = g.l;
    final h = _otherName(g, _other(g));
    if (l.female) {
      g.ask('嫁入りの支度', '殿の姫が$hへ嫁ぐことになり、嫁入りの支度を任された。長持の数、衣装の数で家の格が量られる。奥の蔵の銭は、決して多くない。', [
        Choice.h('家の格に恥じぬよう華やかに整える', '先方に侮られない。奥の蔵は細る', () {
          _fav(g, 3);
          l.fame += 2;
          _net(g, -1);
          g.setFlag('rt_kongi_done');
          return '金蒔絵の長持が、門の外まで列をつくった。勘定方は、帳面を見て頭を抱えた。';
        }),
        Choice.h('倹約して整える', '蔵は守れる。姫は寂しく思うかもしれない', () {
          _fav(g, 1);
          g.j(-1);
          return '古い長持を塗り直して使った。姫は何も言わなかったが、出立の朝、少しだけうつむいていた。';
        }),
        if (l.sei >= 60)
          Choice.h('借りる品と誂える品を分け、帳面にして整える', '算用が立てば見栄えも蔵も守れる。手間は大きい', () {
            _fav(g, 6);
            l.merit += 3;
            g.setFlag('rt_kongi_done');
            g.mark('殿の姫の嫁入り支度を、帳面をつけて取り仕切った');
            return '寺から借りた屏風、町で誂えた打掛、奥の蔵から出した漆器。帳面のとおりに揃った長持の列を、老女が目を細めて見ていた。';
          }, via: '政'),
      ], after: next);
      return;
    }
    g.ask('婚儀の使い', '主君の姫が$hへ嫁ぐことになり、あなたが婚儀の使者として先方へ遣わされた。結納の口上の席で、先方の重臣が「格下の家からの縁組よ」と聞こえよがしに言った。', [
      Choice.h('聞き流して口上を述べ切る', '婚儀はつつがなく運ぶ。家の面目は少し削れる', () {
        _fav(g, 3);
        g.setFlag('rt_kongi_done');
        g.mark('主君の姫の婚儀の使者として、先方での口上を務め上げた');
        return '眉ひとつ動かさずに口上を述べ終えた。帰って報せると、主君は「よう堪えた」と言った。';
      }),
      Choice.h('その言葉を咎める', '家の面目は守れる。婚儀がこじれるかもしれない', () {
        if (g.rng.chance(clampD(.35 + l.bu / 300 + l.mi / 300, .35, .8))) {
          l.fame += 3;
          _fav(g, 4);
          g.setFlag('rt_kongi_done');
          return '「ただいまのお言葉、主に伝えてよろしいか」と問うと、重臣は顔色を変えて詫びた。';
        }
        _fav(g, -5);
        return '座が凍りつき、婚儀の日取りが一月延びた。主君は苦い顔で、あなたを叱った。';
      }),
      if (l.mi >= 60)
        Choice.h('笑って切り返し、座を和ませる', '口のうまさが要る。うまくいけば両家の縁も深まる', () {
          _fav(g, 5);
          _net(g, 3);
          l.fame += 2;
          g.setFlag('rt_kongi_done');
          g.mark('主君の姫の婚儀の使者として、先方での口上を務め上げた');
          return '「格の違いは、姫の器量で埋めてご覧に入れましょう」と笑うと、先方の当主が手を打って笑った。';
        }, via: '魅'),
    ], after: next);
  }),

  SceneDef('rt_takagari', 18, 55, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    g.ask('鷹狩りの供', '主君の鷹狩りの供をした。若い同輩の$nが、主君の自慢の鷹を据え損ね、鷹は空の彼方へ逃げてしまった。主君は顔を赤くして「手討ちにしてくれる」と刀に手をかけた。', [
      Choice.h('前に出てかばう', '同輩は助かるかもしれない。主君の怒りを浴びる', () {
        if (g.rng.chance(clampD(.4 + l.mi / 300 + l.fav / 400, .35, .85))) {
          _net(g, 3);
          g.j(3);
          l.fame += 1;
          g.setFlag('rt_takagari_shielded');
          g.mark('主君の鷹を逃がして手討ちにされかけた同輩を、身を挺してかばった');
          return '$nの前に膝をつき、「鷹は必ずや探し出します」と申し上げた。主君は荒い息のまま刀を収めた。$nは、その夜あなたの宿所へ来て泣いた。';
        }
        _fav(g, -8);
        l.hp -= 5;
        return '「そなたも同罪か」と蹴り倒された。$nは扶持を召し上げられ、あなたも半年のあいだ供を外された。';
      }),
      Choice.h('鷹を探しに山へ走る', '見つかれば怒りは収まる。山は広い', () {
        if (g.rng.chance(clampD(.25 + l.un / 250 + l.bu / 400, .25, .75))) {
          _fav(g, 5);
          l.fame += 2;
          g.setFlag('rt_takagari_hawk');
          return '日暮れ前、杉の梢に足緒を絡ませた鷹を見つけた。鷹を据えて戻ると、主君の顔はもう笑っていた。$nは命拾いした。';
        }
        l.hp -= 6;
        return '尾根を三つ越えても、鷹の影は見えなかった。戻ったときには、$nはもう陣を追われていた。';
      }),
      Choice.h('黙って控える', '己の身は守れる。同輩の行く末は知れない', () {
        g.j(-4);
        return '目を伏せて、膝の土を見ていた。重臣たちのとりなしで$nは手討ちを免れたが、それきり姿を見なくなった。';
      }),
    ], after: next);
  }),

  SceneDef('rt_tonoi', 18, 50, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    g.ask('宿直の夜', '主君の寝所の宿直に立った夜更け、庭の植え込みが不意に揺れた。黒い影が、縁の下へ滑り込むのが見えた。', [
      Choice.h('刀を抜いて影を追う', '腕が立てば曲者を捕らえられる。闇の中の斬り合いだ', () {
        if (g.rng.chance(clampD(.3 + l.bu / 150, .3, .9))) {
          l.fame += 4;
          _fav(g, 6);
          l.merit += 3;
          g.setFlag('rt_tonoi_caught');
          g.mark('主君の寝所の宿直の夜、忍び入った曲者を捕らえた');
          return '縁の下から引きずり出した男の懐から、毒を塗った小刀が出てきた。主君は寝間着のまま出てきて、あなたの肩を叩いた。';
        }
        if (g.rng.chance(.03)) {
          g.die('宿直の夜、主君の寝所に忍び入った曲者と闇の中で斬り結び、果てた', 'ansatsu');
          return '闇の中で、刃が月の光を一度だけ返した。';
        }
        l.hp -= 15;
        return '腕を浅く斬られ、影は塀を越えて消えた。翌朝、主君は寝所の警固を倍にした。';
      }),
      Choice.h('声を上げて人を呼ぶ', '屋敷中が目を覚ます。曲者は逃げるかもしれない', () {
        _fav(g, 2);
        return '「曲者」と叫ぶと、屋敷中に灯がともった。影は消えたが、主君は「よう気づいた」と言った。';
      }),
      Choice.h('主君を起こし、奥の間へ移す', '主君の身は守れる。曲者は取り逃がす', () {
        _fav(g, 4);
        g.setFlag('rt_tonoi_guarded');
        return '主君を奥の間へ導き、襖の前に座り込んで夜明けを待った。曲者の姿は、どこにもなかった。';
      }),
    ], after: next);
  }),

  // 年始の席次（奥の女性にも出る）。
  SceneDef('rt_sekiji', 18, 55, _wf, rtLife, (g, next) {
    final l = g.l;
    final n = l.female ? g.rng.pick(kGivenF) : '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
    final text = l.female
        ? '年始の挨拶で、奥の女中の並びが改められた。あなたは、あなたより後に奥へ上がった$nの後ろに置かれた。'
        : '年始の御礼の席で、あなたの座がいつもより下に置かれていた。上の席には、あなたより後に取り立てられた$nが座っている。';
    g.ask('年始の席次', text, [
      Choice.h('黙って座る', '波風は立たない。侮られるかもしれない', () {
        g.j(-2);
        return '黙って座り、型どおりの挨拶を述べた。$nは、こちらを見ようとしなかった。';
      }),
      Choice.h('筋を申し立てる', '道理が通れば座は戻る。強く出れば妬みも買う', () {
        if (g.rng.chance(clampD(.4 + l.fav / 300, .4, .75))) {
          l.fame += 2;
          g.setFlag('rt_sekiji_won');
          return '取次の者に申し立てると、翌日には並びが元に戻った。$nの家の者が、陰で舌打ちをしていたと聞いた。';
        }
        _fav(g, -4);
        return '「年の始めから座のことか」と笑われた。並びは、そのままだった。';
      }),
      if (l.chi >= 60)
        Choice.h('古い書付を示して申し立てる', '証があれば言い分は通る。調べる手間がかかる', () {
          l.fame += 3;
          _fav(g, 2);
          g.setFlag('rt_sekiji_won');
          return '先代のころの席次の書付を探し出して示すと、取次の者は黙って並びを直した。';
        }, via: '知'),
      Choice.h('笑って譲る', '器の大きさは見られる。出世の妬みは和らぐ', () {
        _net(g, 2);
        g.j(1);
        g.setFlag('rt_sekiji_yield');
        return '「座で働くわけではございませぬ」と笑うと、$nは少し気まずそうに頭を下げた。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 兵を率いる

List<SceneDef> _commandScenes() => [
  // ============================================ 筋: 配下
  SceneDef('rt_haika', 18, 50, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    final a = g.rng.pick(kGivenM);
    var b = g.rng.pick(kGivenM);
    if (b == a) b = '$b丸';
    _keepName(g, 'rt_haika_old:', a);
    _keepName(g, 'rt_haika_new:', b);
    g.ask('新しい配下', '新しく、あなたの手の者に二人が加えられた。幾度も戦をくぐった古参の$aと、村から連れて来られたばかりの若い$bだ。$aは、あなたを値踏みするように見ている。', [
      Choice.h('古参の$aを立てて、知恵を借りる', '組は落ち着く。侮られるかもしれない', () {
        g.meet('配下の古参', a, 55);
        l.troops += 2;
        g.setFlag('rt_haika_kosan');
        _stamp(g, 'haika');
        return '「戦のことは、おぬしの方がよく知っておろう」と言うと、$aは少し驚いた顔をして、それから深く頭を下げた。';
      }),
      Choice.h('若い$bを手元で鍛える', '育てば頼りになる。古参は面白くない', () {
        g.meet('配下の若者', b, 55);
        l.troops += 2;
        _net(g, -1);
        g.setFlag('rt_haika_young');
        _stamp(g, 'haika');
        return '朝ごとに$bを呼び、槍の構えから教えた。$aは、遠くから黙って見ていた。';
      }),
      Choice.h('掟を定め、誰にも同じように当たる', '筋は通る。情は薄いと思われる', () {
        l.troops += 2;
        _fav(g, 2);
        g.setFlag('rt_haika_strict');
        _stamp(g, 'haika');
        return '組の掟を書いて陣屋の柱に貼った。古参も若い者も、同じように読んだ。';
      }),
    ], after: next);
  }),

  _chain('rt_haika_fault', 19, 52, _w2, rtSamurai, (g, next) {
    final l = g.l;
    final young = g.hasFlag('rt_haika_young');
    final x = young ? _named(g, 'rt_haika_new:', '若い配下') : _named(g, 'rt_haika_old:', '古参の配下');
    final p = l.people[young ? '配下の若者' : '配下の古参'];
    g.ask('配下の不始末', '配下の$xが、陣を張った村で百姓と揉め、鍬を持った男を殴り倒したという。村の長老が、あなたの陣屋へ訴えに来た。', [
      Choice.h('自ら村へ出向いて詫び、銭を払う', '村の恨みは和らぐ。銭と面目が減る', () {
        _pay(g, 4);
        _fav(g, 2);
        _bond(p, 8);
        g.setFlag('rt_haika_covered');
        _stamp(g, 'haika');
        g.mark('配下の不始末を、自ら村へ出向いて詫びた');
        return '殴られた男の家の土間で、頭を下げた。後ろで$xが、唇を噛んで同じように頭を下げていた。';
      }),
      Choice.h('掟どおり配下を罰する', '軍の規律は保たれる。配下は心を閉ざすかもしれない', () {
        _fav(g, 3);
        _bond(p, -15);
        g.setFlag('rt_haika_punished');
        _stamp(g, 'haika');
        return '村の者たちの前で、$xを棒で打たせた。$xは一度も声を上げなかった。';
      }),
      Choice.h('村の訴えを退ける', '配下はかばえる。村の恨みが残る', () {
        _bond(p, 6);
        g.j(-2);
        g.setFlag('rt_haika_shielded');
        _stamp(g, 'haika');
        if (g.rng.chance(.3)) {
          _fav(g, -5);
          return '長老を追い返した。数日後、村からの訴えが主君の耳にまで届き、あなたは呼び出されて叱られた。';
        }
        return '長老を追い返した。村の者たちの冷たい目が、陣を払うまで背中に刺さっていた。';
      }),
      if (l.sei >= 60)
        Choice.h('償いの米を出し、配下に村の普請を手伝わせる', '算段が立てば村とも和める。配下の汗で償う', () {
          _pay(g, 2);
          _fav(g, 4);
          l.merit += 1;
          _bond(p, 4);
          g.setFlag('rt_haika_covered');
          _stamp(g, 'haika');
          g.mark('配下の不始末の償いに、配下を率いて村の溝さらいを手伝わせた');
          return '$xは泥にまみれて村の溝をさらった。三日目には、殴られた男が$xに握り飯を差し出していた。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('rt_haika_tegara', 20, 55, _w2, rtSamurai, (g, next) {
    final l = g.l;
    final young = g.hasFlag('rt_haika_young');
    final x = young ? _named(g, 'rt_haika_new:', '若い配下') : _named(g, 'rt_haika_old:', '古参の配下');
    final p = l.people[young ? '配下の若者' : '配下の古参'];
    final lead = g.hasFlag('rt_haika_punished')
        ? 'かつて村の者の前で打たせた$xが、'
        : (young ? 'あなたが手元で鍛えてきた$xが、' : '配下の$xが、');
    g.ask('配下の手柄', '先の戦で、$lead敵の兜首を挙げた。だが首帳には、組を率いたあなたの名で記すのが習いだという。', [
      Choice.h('首帳に配下の名を記させる', '配下は奮い立つ。あなたの手柄は減る', () {
        l.merit += 1;
        _net(g, 3);
        _bond(p, 15);
        g.j(3);
        g.setFlag('rt_haika_handed');
        _stamp(g, 'haika');
        g.mark('配下の挙げた兜首を、己の手柄とせず配下の名で首帳に記させた');
        return '首帳に$xの名が書かれた。$xは首帳の前で、しばらく動けずにいた。その日から、組の者たちの目の色が変わった。';
      }),
      Choice.h('習いどおり己の名で記す', '手柄は大きい。配下の目には残る', () {
        l.merit += 6;
        l.fame += 2;
        _bond(p, -10);
        _stamp(g, 'haika');
        return '首帳にはあなたの名が書かれ、恩賞の銭が下った。$xは、何も言わずに槍の手入れをしていた。';
      }),
      Choice.h('恩賞を配下と分け合う', '角は立たない。どちらにも物足りない', () {
        l.merit += 3;
        l.gold += 2;
        _net(g, 1);
        _bond(p, 5);
        _stamp(g, 'haika');
        return '首帳には己の名を記し、下った銭の半ばを$xに渡した。$xは黙って受け取った。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 知行地
  SceneDef('rt_chigyo', 20, 55, (g) => _w1 + (g.l.rank == 4 ? 1 : 0), rtSamurai, (g, next) {
    final l = g.l;
    g.ask('知行地の年貢', '働きが認められ、小さな知行地を宛てがわれた。村の名主が年貢の帳面を抱えて挨拶に来た。去年は日照りで、村の蔵は乏しいという。', [
      Choice.h('定めどおりに年貢を取る', '筋は通る。村の暮らしは楽ではない', () {
        l.gold += 3;
        g.setFlag('rt_chigyo_fair');
        _stamp(g, 'chigyo');
        return '帳面どおりの米が、秋に屋敷の蔵へ運び込まれた。名主は、黙って頭を下げて帰っていった。';
      }),
      Choice.h('今年は年貢を軽くする', '村の者に慕われる。己の蔵は乏しくなる', () {
        g.j(2);
        _net(g, 1);
        g.setFlag('rt_chigyo_light');
        _stamp(g, 'chigyo');
        return '「今年は三分を負けてやれ」と言うと、名主は目を丸くした。秋祭りの日、村から濁り酒が届いた。';
      }),
      Choice.h('年貢を重くして軍役の備えに回す', '兵と蔵は満ちる。村の恨みを買う', () {
        l.gold += 6;
        l.troops += 2;
        g.j(-2);
        g.setFlag('rt_chigyo_heavy');
        _stamp(g, 'chigyo');
        return '名主は青い顔で帳面を閉じた。冬のあいだに、村から若い者が何人か姿を消したと聞いた。';
      }),
      if (l.sei >= 60)
        Choice.h('村の田を見て回り、田ごとに年貢を決める', '算用が立てば取りこぼしも恨みも少ない。手間がかかる', () {
          l.gold += 4;
          l.merit += 2;
          g.setFlag('rt_chigyo_fair');
          g.setFlag('rt_chigyo_survey');
          _stamp(g, 'chigyo');
          return '名主と畦を歩き、日照りに負けた田と持ちこたえた田を分けて帳面に記した。名主は「このようなお侍は初めてだ」と言った。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('rt_chigyo_mizu', 21, 58, _w2, rtSamurai, (g, next) {
    final l = g.l;
    g.ask('知行地の川', '長雨で、知行地の村を流れる川があふれかけている。名主が屋敷まで駆けてきて、「お侍さまのお力で、堤を」と頭を下げた。', [
      Choice.h('己の銭で人足を雇い、堤を築かせる', '田は守れる。銭は飛ぶ', () {
        _pay(g, 8);
        _net(g, 3);
        g.j(3);
        g.setFlag('rt_chigyo_levee');
        _stamp(g, 'chigyo');
        g.mark('知行地の村の川に、己の銭で人足を雇って堤を築かせた');
        return '雨の中、村の者と人足が土俵を積み上げた。水は堤の縁までせり上がったが、越えなかった。';
      }),
      Choice.h('村の者に任せる', '銭はかからない。田が水に浸かるかもしれない', () {
        _stamp(g, 'chigyo');
        if (g.rng.chance(.5)) {
          _pay(g, 3);
          g.j(-3);
          return '川は堤を越え、低い田が泥に沈んだ。その秋、年貢の米は半ばしか届かなかった。';
        }
        return '村の者たちは夜通し土を盛り、どうにか持ちこたえた。礼を言いに来る者はいなかった。';
      }),
      if (l.chi >= 60)
        Choice.h('川の曲がりを見て、水を逃がす落とし口を切らせる', '知恵が当たれば安く済む。外れれば田が沈む', () {
          _stamp(g, 'chigyo');
          if (g.rng.chance(clampD(.55 + l.chi / 300, .55, .9))) {
            _net(g, 3);
            l.merit += 2;
            _fav(g, 2);
            g.setFlag('rt_chigyo_levee');
            g.mark('知行地の村の川に、水を逃がす落とし口を切らせて田を守った');
            return '荒れ地のほうへ落とし口を切ると、水はそちらへ逃げていった。名主は、あなたの手を握って離さなかった。';
          }
          _pay(g, 3);
          g.j(-3);
          return '落とし口から出た水が、思わぬ田へ流れ込んだ。名主は何も言わなかったが、目が恨めしげだった。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('rt_chigyo_uttae', 21, 58, _w2, rtSamurai, (g, next) {
    final l = g.l;
    g.ask('百姓の直訴', '知行地の百姓たちが、年貢の重さに耐えかねて、城下まで直訴に及んだという。主君は「そなたの知行のことだ。始末をつけよ」と言った。', [
      Choice.h('百姓の訴えを聞き、年貢を軽くする', '村は落ち着く。蔵と兵の備えは細る', () {
        l.gold = l.gold >= 4 ? l.gold - 4 : 0;
        _fav(g, 2);
        _net(g, 2);
        g.j(2);
        l.flags.remove('rt_chigyo_heavy');
        g.setFlag('rt_chigyo_heard');
        _stamp(g, 'chigyo');
        g.mark('重い年貢を訴え出た知行地の百姓の声を聞き、年貢を軽くした');
        return '訴えの頭を屋敷に呼び、膝を突き合わせて話を聞いた。帰っていく百姓たちの足取りは、来たときより軽かった。';
      }),
      Choice.h('訴えの頭を捕らえて見せしめにする', '年貢は取れる。村の恨みは深くなる', () {
        g.j(-5);
        _stamp(g, 'chigyo');
        g.setFlag('rt_chigyo_harsh');
        if (g.rng.chance(.35)) {
          l.troops = l.troops >= 2 ? l.troops - 2 : 0;
          _fav(g, -4);
          return '頭を牢に入れると、その冬、村の者たちは田を捨てて山へ逃げた。主君は「始末をつけよと申したはずだ」と眉をひそめた。';
        }
        _fav(g, 1);
        return '頭を牢に入れると、村は静まり返った。年貢の米は届いたが、村の誰もあなたの顔を見なくなった。';
      }),
      if (l.sei >= 55)
        Choice.h('名主を呼び、年貢を据え置く代わりに夫役を減らす', '算段が立てば双方が折れる。主君の普請の人手は減る', () {
          _fav(g, 1);
          _net(g, 2);
          l.merit += 1;
          g.setFlag('rt_chigyo_heard');
          _stamp(g, 'chigyo');
          g.mark('重い年貢を訴え出た知行地の百姓の声を聞き、夫役を減らして折り合いをつけた');
          return '名主と夜更けまで帳面を突き合わせた。年貢は据え置き、城の普請に出す人足を半ばにした。百姓たちは、渋い顔ながらも村へ戻った。';
        }, via: '政'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 家中の政

List<SceneDef> _houseScenes() => [
  // ============================================ 筋: 譜代と新参
  SceneDef('rt_habatsu', 20, 55, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    final newcomer = l.birthRank < 3;
    final note = newcomer ? '身を起こして侍の列に加わったあなたは、譜代の衆からは新参と見られている。' : '';
    g.ask('譜代と新参', '家中が二つに割れている。古くから仕える譜代の衆と、近年取り立てられた新参の衆だ。$noteそれぞれの頭から、酒の席に誘われた。', [
      Choice.h('譜代の衆につく', '家中の重みが味方になる。古い流儀に縛られる', () {
        _fav(g, 2);
        _net(g, 1);
        g.setFlag('rt_habatsu_fudai');
        _stamp(g, 'habatsu');
        return newcomer
            ? '譜代の頭は「新参にしては話が分かる」と盃をくれた。新参の衆は、あなたを裏切り者を見る目で見た。'
            : '譜代の頭は「そなたの家とは先代からの付き合いよ」と盃をくれた。';
      }),
      Choice.h('新参の衆につく', '勢いのある側だ。古い家々には睨まれる', () {
        l.merit += 2;
        _net(g, 1);
        g.setFlag('rt_habatsu_shinzan');
        _stamp(g, 'habatsu');
        return '新参の頭は「これからの家を作るのは我らよ」と笑った。譜代の老臣が廊下ですれ違いざま、わざと咳払いをした。';
      }),
      Choice.h('どちらの誘いも断る', '誰の手下にもならない。後ろ盾もない', () {
        g.setFlag('rt_habatsu_none');
        _stamp(g, 'habatsu');
        return '「主君ひとりに仕える身ゆえ」と、どちらの席にも出なかった。どちらの頭も、面白くなさそうな顔をした。';
      }),
    ], after: next);
  }),

  _chain('rt_habatsu_clash', 22, 58, _w2, rtSamurai, (g, next) {
    final l = g.l;
    final String title, text;
    if (g.hasFlag('rt_habatsu_fudai')) {
      title = '譜代の企て';
      text = '譜代の頭が、新参の頭に謀反の心ありと主君に申し上げるという。「そなたも証人になれ」と言われた。証になるものは、何もない。';
    } else if (g.hasFlag('rt_habatsu_shinzan')) {
      title = '新参の訴え';
      text = '新参の頭が、譜代の老臣が兵糧の米を横流ししていると訴え出るという。あなたにも、老臣の帳面を調べる手伝いをせよと言う。';
    } else {
      title = '割れた評定';
      text = '譜代と新参の争いが、ついに評定の場にまで持ち込まれた。どちらにもつかぬあなたに、主君が「そなたはどう見る」と問うた。';
    }
    final mediate = l.mi >= 60 || g.hasFlag('rt_habatsu_none');
    g.ask(title, text, [
      Choice.h(g.hasFlag('rt_habatsu_shinzan') ? '帳面を洗い出す' : '頭の言い分に乗る', '味方の頭の覚えはめでたい。争いの火に油を注ぐ', () {
        _stamp(g, 'habatsu');
        g.j(-3);
        if (g.hasFlag('rt_habatsu_shinzan') && g.rng.chance(clampD(.3 + l.chi / 200, .3, .8))) {
          l.merit += 4;
          _fav(g, 4);
          return '帳面の数と蔵の米が合わなかった。老臣は隠居を命じられ、新参の頭はあなたの肩を叩いた。';
        }
        if (g.rng.chance(.5)) {
          _fav(g, 2);
          l.merit += 2;
          return '訴えは通り、相手の頭は遠い城へ移された。家中の半ばが、あなたを冷たい目で見るようになった。';
        }
        _fav(g, -6);
        return '主君は「証のない訴えで家を割るか」と一喝した。頭はあなたを見捨て、知らぬ顔をした。';
      }),
      Choice.h('関わらぬと断る', '己の手は汚れない。味方の頭の信は失う', () {
        _stamp(g, 'habatsu');
        _net(g, -2);
        g.j(1);
        return '「それがしは存じませぬ」と頭を下げた。頭は舌打ちをして、それきりあなたを席に呼ばなくなった。';
      }),
      if (mediate)
        Choice.h('両方の頭を一つの席に呼び、間を取り持つ', '人柄が通じれば家中は収まる。どちらからも疑われるかもしれない', () {
          _stamp(g, 'habatsu');
          if (g.rng.chance(clampD(.35 + l.mi / 250, .35, .85))) {
            _fav(g, 6);
            _net(g, 4);
            l.fame += 3;
            g.setFlag('rt_habatsu_mediated');
            g.mark('家中の譜代と新参の争いを、両方の頭を一つの席に呼んで収めた');
            return '二人の頭を茶の席に招き、互いの言い分を最後まで言わせた。帰り際、二人はぎこちなく会釈を交わした。';
          }
          _fav(g, -2);
          _net(g, -2);
          return '席の途中で、二人の頭は刀の柄に手をかけて立ち上がった。どちらからも「あちらの回し者か」と言われた。';
        }, via: l.mi >= 60 ? '魅' : null),
    ], after: next);
  }),

  SceneDef('rt_bugyo', 22, 55, (g) => _w1, rtSamurai, (g, next) {
    final l = g.l;
    g.ask('普請の奉行', '主君が城の堀を広げることになり、あなたに普請の奉行を申しつけた。人足は近在の村から集める。秋の取り入れの前に終えよとのことだ。', [
      Choice.h('期日を守らせるため、厳しく追い立てる', '期日には間に合う。村の者の恨みを買う', () {
        l.merit += 4;
        _fav(g, 3);
        g.j(-3);
        _net(g, -2);
        return '鞭を持った小者を見回らせた。堀は期日に掘り上がったが、倒れた人足の数は誰も数えなかった。';
      }),
      Choice.h('人足に粥を振る舞い、励まして進める', '人は進んで働く。銭がかかる', () {
        _pay(g, 4);
        l.merit += 3;
        _net(g, 3);
        g.setFlag('rt_bugyo_kind');
        g.mark('城の堀の普請の奉行を務め、人足に粥を振る舞って励ました');
        return '昼ごとに大鍋で粥を炊かせた。人足たちは唄を歌いながら土を運び、堀は期日の少し前に仕上がった。';
      }),
      if (l.sei >= 60)
        Choice.h('村ごとに持ち場を割り付け、競わせる', '算用が立てば早く仕上がる。割り付けを誤れば揉める', () {
          l.merit += 5;
          _fav(g, 5);
          g.setFlag('rt_bugyo_wise');
          g.mark('城の堀の普請で、村ごとに持ち場を割り付けて期日より早く仕上げた');
          return '縄を張って村ごとの持ち場を分け、早く終えた村には酒を出すと触れた。堀は半月早く仕上がり、主君は馬で見に来た。';
        }, via: '政'),
      Choice.h('戦場の務めを願って辞する', '槍の道を守れる。主君の期待を外す', () {
        _fav(g, -3);
        l.bu = _c(l.bu + 1);
        return '「土を掘るより槍を振るいとうございます」と申し上げた。主君は「欲のないことよ」と苦笑した。';
      }),
    ], after: next);
  }),

  SceneDef(
    'rt_konin',
    20,
    40,
    (g) => _w1 * .8,
    (g) => rtSamurai(g) && !g.l.married,
    (g, next) {
      final l = g.l;
      final h = g.rng.pick(kSurnames);
      final f = g.rng.pick(kGivenF);
      g.ask('重臣の娘', '家中の重臣、$h家から、娘の$fを娶らぬかと話があった。重臣の家と縁を結べば、家中での後ろ盾になる。その代わり、$h家の争いごとにも巻き込まれる。', [
        Choice.h('話を受ける', '家中に後ろ盾ができる。重臣の家の重さも背負う', () {
          l.married = true;
          g.meet('伴侶', '$h家の$f', 45);
          _net(g, 3);
          _fav(g, 3);
          l.gold += 5;
          g.j(5);
          g.setFlag('rt_konin_wed');
          g.mark('家中の重臣$h家の娘$fを娶り、家中に縁を結んだ');
          return '$fは、婚礼の夜、「父の言いつけで参りました」とだけ言った。それから少しずつ、口数が増えていった。';
        }),
        Choice.h('己の才覚で立ちたいと断る', '誰にも借りを作らない。重臣の顔をつぶす', () {
          _fav(g, -2);
          g.j(1);
          g.setFlag('rt_konin_refused');
          return '丁重に断ると、$h家の重臣は「若い者は」と笑ったが、それから評定であなたの献策に一言多く口を挟むようになった。';
        }),
      ], after: next);
    },
  ),
];

// ---------------------------------------------------------------- 奥で仕える女性

List<SceneDef> _okuScenes() => [
  // ============================================ 筋: 奥の派閥
  SceneDef('rt_o_habatsu', 16, 50, (g) => _wf(g) + 1, rtOku, (g, next) {
    final s = g.rng.pick(kGivenF);
    _keepName(g, 'rt_o_soku_name:', s);
    g.ask('奥の派閥', '奥が二つに割れている。御台所さまに付く古くからの女中たちと、近ごろ殿の寵を受けた側室の$sさまに付く若い女中たちだ。どちらの部屋からも、あなたを呼ぶ声がかかった。', [
      Choice.h('御台所さまに付く', '奥の古い重みが味方になる。殿の目からは遠のく', () {
        _fav(g, 2);
        g.setFlag('rt_o_midai');
        _stamp(g, 'ohabatsu');
        return '御台所さまの部屋に上がると、年かさの女中たちが「よう来た」と迎えてくれた。';
      }),
      Choice.h('側室の$sさまに付く', '勢いのある側だ。御台所さまの怒りを買う', () {
        g.l.merit += 2;
        g.setFlag('rt_o_sokushitsu');
        _stamp(g, 'ohabatsu');
        return '$sさまは、あなたの手を取って「頼りにしています」と笑った。廊下で、御台所さま付きの女中たちが口をつぐんだ。';
      }),
      Choice.h('どちらにも与しない', '誰の手先にもならない。どちらからも心を許されない', () {
        g.setFlag('rt_o_apart');
        _stamp(g, 'ohabatsu');
        return 'どちらの部屋にも、決まった用のほかは足を向けなかった。「冷たい人」と言う者もいた。';
      }),
    ], after: next);
  }),

  _chain('rt_o_habatsu_after', 18, 55, _w2, rtOku, (g, next) {
    final l = g.l;
    final s = _named(g, 'rt_o_soku_name:', '側室');
    if (g.hasFlag('rt_o_midai')) {
      g.ask('御台所さまの命', '側室の$sさまが男子を産んだ。御台所さまはあなたを呼び、「あちらの部屋の者が何を話しておるか、聞いてまいれ」と命じた。', [
        Choice.h('命に従って探る', '御台所さまの信は厚くなる。見つかれば奥にいられない', () {
          _stamp(g, 'ohabatsu');
          if (g.rng.chance(clampD(.5 + l.chi / 300, .5, .85))) {
            _fav(g, 5);
            l.merit += 2;
            g.j(-2);
            return '縫い物を届けるふりをして、あちらの部屋の話に耳を澄ませた。御台所さまは、聞いたことを黙って書き留めさせた。';
          }
          _fav(g, -6);
          g.j(-4);
          return '襖の陰にいるところを、あちらの女中に見咎められた。御台所さまは「わらわは知らぬ」と言い、あなたは奥の隅の役へ移された。';
        }),
        Choice.h('お断りする', '己の心は守れる。御台所さまは冷たくなる', () {
          _stamp(g, 'ohabatsu');
          _fav(g, -4);
          g.j(1);
          return '「人の話を盗み聞くのは」と言いかけると、御台所さまは扇で口元を隠し、「もうよい」と言った。';
        }),
        if (l.chi >= 60)
          Choice.h('聞いたふりをして、当たり障りのないことだけを申し上げる', '知恵が回れば誰も傷つかない。嘘を重ねることになる', () {
            _stamp(g, 'ohabatsu');
            _fav(g, 3);
            _net(g, 1);
            return '「若君の夜泣きのことばかり話しておりました」と申し上げた。御台所さまは少し笑い、それきり同じことは命じなかった。';
          }, via: '知'),
      ], after: next);
      return;
    }
    if (g.hasFlag('rt_o_sokushitsu')) {
      g.ask('側室の男子', '側室の$sさまが男子を産み、奥での重みが一度に増した。あなたにも上の役が回ってきそうだが、御台所さまの部屋の者たちの目が冷たい。', [
        Choice.h('$sさまの引き立てを受ける', '奥で重く用いられる。御台所さまの怒りを買う', () {
          _stamp(g, 'ohabatsu');
          _fav(g, 5);
          l.merit += 3;
          if (g.rng.chance(.3)) {
            g.j(-4);
            return '若君付きの役を賜った。その晩、あなたの部屋の前に、裂かれた小袖が置かれていた。';
          }
          g.j(2);
          return '若君付きの役を賜った。$sさまは「あなたがいてくれてよかった」と言った。';
        }),
        Choice.h('御台所さまの部屋へ挨拶に上がる', '溝を浅くできる。$sさまは面白くない', () {
          _stamp(g, 'ohabatsu');
          _net(g, 2);
          return '祝いの品を持って御台所さまの部屋へ上がった。御台所さまは「わきまえておるな」とだけ言った。';
        }),
        if (l.mi >= 60)
          Choice.h('若君の祝いを、両方の部屋から贈る形に整える', '人柄が通じれば奥は和む。どちらの顔も立てねばならない', () {
            _stamp(g, 'ohabatsu');
            _fav(g, 5);
            _net(g, 3);
            g.setFlag('rt_o_mediated');
            g.mark('奥の御台所方と側室方のあいだを取り持ち、若君の祝いを両方の部屋から贈らせた');
            return '御台所さまの名で守り刀を、$sさまの名で産着を。殿は二つの祝いを並べて見て、「奥が一つになったか」と目を細めた。';
          }, via: '魅'),
      ], after: next);
      return;
    }
    g.ask('奥の溝', '御台所さまと側室の$sさまの溝が深まり、女中たちの諍いが絶えない。どちらにも与しないあなたに、殿の母君が「間を取り持て」と仰せになった。', [
      Choice.h('引き受けて、両方の部屋を行き来する', '人柄が通じれば奥は和む。しくじればどちらからも恨まれる', () {
        _stamp(g, 'ohabatsu');
        if (g.rng.chance(clampD(.4 + l.mi / 250, .4, .85))) {
          _fav(g, 6);
          _net(g, 3);
          g.setFlag('rt_o_mediated');
          g.mark('殿の母君の命で、奥の御台所方と側室方のあいだを取り持った');
          return '両方の部屋を何度も行き来し、言い分を和らげて伝えた。ひと冬が過ぎるころ、二つの部屋の女中が並んで縫い物をするようになった。';
        }
        _fav(g, -3);
        g.j(-3);
        return 'どちらの部屋でも「あちらの肩を持つ」と言われた。殿の母君は、ため息をついた。';
      }),
      Choice.h('荷が重いとお断りする', '巻き込まれずに済む。母君の覚えは薄れる', () {
        _stamp(g, 'ohabatsu');
        _fav(g, -2);
        return '母君は「そなたでも無理か」と言い、それきりその話はしなかった。';
      }),
    ], after: next);
  }),

  SceneDef('rt_o_menoto', 18, 50, _wf, rtOku, (g, next) {
    final l = g.l;
    g.ask('若君の乳母', '奥に若君が生まれた。乳母を誰にするかで、奥が揉めている。乳母の家は若君の代に重く用いられるからだ。御台所さまはあなたに「乳の出る、身元の確かな者を探せ」と仰せになった。', [
      Choice.h('城下の足軽の女房を、身元を確かめて推す', '若君のためにはなる。重臣の家々は面白くない', () {
        _fav(g, 3);
        l.merit += 2;
        _net(g, -1);
        g.setFlag('rt_o_menoto_fair');
        return '気立てのよい、乳のよく出る女房を見つけた。重臣の奥方たちは鼻白んだが、若君はよく乳を飲み、よく眠った。';
      }),
      Choice.h('重臣の家の推す者を通す', '角は立たない。重臣に恩を売れる', () {
        _fav(g, 1);
        _net(g, 3);
        return '重臣の家の縁者を推した。重臣の奥方から、礼の反物が届いた。';
      }),
      Choice.h('己の縁者を推す', '己の家の行く末が開ける。私を挟んだと言われる', () {
        if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .75))) {
          _fav(g, 4);
          g.j(3);
          g.setFlag('rt_o_menoto_kin');
          return '従姉が乳母に決まった。国の親から、涙のにじんだ文が届いた。';
        }
        _fav(g, -6);
        return '「私の縁者を推すとは」と御台所さまに叱られた。乳母には、ほかの者が決まった。';
      }),
    ], after: next);
  }),

  SceneDef('rt_o_tsukai', 18, 50, _wf, rtOku, (g, next) {
    final l = g.l;
    g.ask('御台所さまの使い', '御台所さまの実家へ、内々の文を届けるよう命じられた。文の中身は知らされていない。近道の峠には、近ごろ物騒な者が出るという。', [
      Choice.h('供を連れて近道の峠を越える', '早く着ける。峠は危うい', () {
        if (g.rng.chance(.03)) {
          g.die('御台所の内々の文を携えて実家へ向かう峠道で、何者かに襲われた', 'ansatsu');
          return '峠の杉木立の陰から、覆面の男たちが現れた。';
        }
        _fav(g, 4);
        l.merit += 3;
        g.setFlag('rt_o_tsukai_done');
        g.mark('御台所の内々の文を、峠を越えて実家へ届けた');
        return '峠の茶屋でも足を止めずに歩き通した。実家の奥方は文を読むなり、「よう急いでくれた」と手を取った。';
      }),
      Choice.h('遠回りの街道を行く', '危うさは少ない。遅れれば咎められる', () {
        if (g.rng.chance(.5)) {
          _fav(g, 2);
          g.setFlag('rt_o_tsukai_done');
          return '三日遅れて着いたが、文は間に合った。御台所さまは「無事で何より」と言った。';
        }
        _fav(g, -3);
        return '着いたときには、文の用はもう済んでいた。御台所さまは、何も言わなかった。';
      }),
      if (l.chi >= 60)
        Choice.h('文を帯に縫い込み、偽の文を別に持つ', '知恵が回れば無事に届く。気を張り詰める旅になる', () {
          _fav(g, 6);
          l.merit += 3;
          g.setFlag('rt_o_tsukai_done');
          g.setFlag('rt_o_tsukai_wit');
          g.mark('御台所の内々の文を帯に縫い込み、峠を越えて実家へ届けた');
          return '峠で荷を検められたが、男たちは偽の文を奪って去った。帯の内の文は、誰にも触れられずに届いた。';
        }, via: '知'),
    ], after: next);
  }),
];
