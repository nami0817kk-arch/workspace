import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 縁のある人の物語（2026-11-23）。幼なじみ・好敵手・師・連れ合いとの縁が、
/// 一生を通じて何段も続く岐路。id・新しい旗は `bd_` で始める。
///
/// - 段は前の段の場面（`scene:<id>`）があるときだけ出る。段の間は何年か空ける
///   （段を踏んだ年を旗 `bd_<縁>_at:<年>` に残す。縁は os=幼なじみ・rv=好敵手・ms=師・sp=連れ合い）。
/// - 選んだ手で絆（`Person.bond`）が上下し、絆の深さで次の段の筋が変わる（深ければ和解、浅ければ仲違い など）。
/// - 縁の役割の名（'幼なじみ'・'好敵手'・'師'・'伴侶'）は変えない。亡くなった人は people から外す
///   （連れ合いはここでは亡くならない）。最期の条件が役割と絆を見ているため。
/// - どれも一生に一度。重みは伏線の回収の岐路と同じくらい（段を待った年が長いほど少し出やすい）。

/// 縁ごとの段（順に）。テストが使う。
const kBondChains = <String, List<String>>{
  'os': ['bd_os_gap', 'bd_os_ask', 'bd_os_turn', 'bd_os_foes', 'bd_os_old'],
  'rv': ['bd_rv_match', 'bd_rv_rise', 'bd_rv_peril', 'bd_rv_end', 'bd_rv_death'],
  'ms': ['bd_ms_lesson', 'bd_ms_old', 'bd_ms_keep', 'bd_ms_grave'],
  'sp': ['bd_sp_new', 'bd_sp_hard', 'bd_sp_wish', 'bd_sp_engawa'],
};

/// 段の前の段（`bd_os_foes` は `bd_os_ask` のあとに出る枝。`bd_os_old` は `bd_os_turn` のあと）。
const kBondPrev = <String, String>{
  'bd_os_ask': 'bd_os_gap',
  'bd_os_turn': 'bd_os_ask',
  'bd_os_foes': 'bd_os_ask',
  'bd_os_old': 'bd_os_turn',
  'bd_rv_rise': 'bd_rv_match',
  'bd_rv_peril': 'bd_rv_rise',
  'bd_rv_end': 'bd_rv_peril',
  'bd_rv_death': 'bd_rv_end',
  'bd_ms_old': 'bd_ms_lesson',
  'bd_ms_keep': 'bd_ms_old',
  'bd_ms_grave': 'bd_ms_keep',
  'bd_sp_hard': 'bd_sp_new',
  'bd_sp_wish': 'bd_sp_hard',
  'bd_sp_engawa': 'bd_sp_wish',
};

int _c(int v) => clampInt(v, 0, 100);
int _s(int v) => clampInt(v, 0, 99);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fameDown(Game g, int n) => g.l.fame = g.l.fame >= n ? g.l.fame - n : 0;
void _netDown(Game g, int n) => g.l.net = g.l.net >= n ? g.l.net - n : 0;
void _bond(Person? p, int v) {
  if (p != null) p.bond = _c(p.bond + v);
}

// ---------------- 段の年 ----------------

/// 縁 [k] の段を最後に踏んだ年（無ければ null）。
int? bondStageYear(Game g, String k) {
  final p = 'bd_${k}_at:';
  for (final f in g.l.flags) {
    if (f.startsWith(p)) return int.tryParse(f.substring(p.length));
  }
  return null;
}

void _stamp(Game g, String k) {
  final p = 'bd_${k}_at:';
  g.l.flags.removeWhere((f) => f.startsWith(p));
  g.setFlag('$p${g.year}');
}

/// 前の段 [prev] を踏み、そこから [gap] 年以上たった。
bool _since(Game g, String prev, String k, int gap) {
  if (!g.hasFlag('scene:$prev')) return false;
  final y = bondStageYear(g, k);
  return y != null && g.year - y >= gap;
}

/// 最初の段の重み。
double _first(Game g) => kBondFirstWeight;

/// 次の段からの重み。始まった筋は結末まで見届けられるよう、ほかの岐路より重めから始め、
/// 待った年が長いほど少しずつ出やすくする。
double _wait(Game g, String k, int gap) {
  final y = bondStageYear(g, k);
  if (y == null) return kBondNextWeight;
  return kBondNextWeight + clampInt(g.year - y - gap, 0, kBondWaitMax).toDouble();
}

/// 重みの目安（2026-11-23 に、最後の段まで届く成人が約6%だったので上げた）。
const kBondFirstWeight = 9.0;
const kBondNextWeight = 10.0;
const kBondWaitMax = 8;

/// 岐路の起きない静かな年に、縁の筋の続き（二の段から）が出る確率（`Game._adultYearScene`）。
const kBondQuietChance = .3;

/// 縁の場面を踏んだあと、どの縁の場面も出さない年数。1年に出る縁の場面は1つまでで、
/// 続けて出ないようにする（1本の人生が縁の場面ばかりにならないための歯止め）。
const kBondRestYears = 1;

/// どれかの縁の段を最後に踏んだ年（無ければ null）。
int? lastBondYear(Game g) {
  int? last;
  for (final k in kBondChains.keys) {
    final y = bondStageYear(g, k);
    if (y != null && (last == null || y > last)) last = y;
  }
  return last;
}

/// 縁の場面を出してよい年か（今年も、休みの年のうちも、まだ縁の場面を踏んでいない）。
bool bondRested(Game g) {
  final y = lastBondYear(g);
  return y == null || g.year - y > kBondRestYears;
}

// ---------------- 暮らしの場 ----------------

bool _monk(Game g) => g.hasFlag('priesthood');
bool _outlaw(Game g) => g.hasFlag('way_outlaw') && g.l.rank == 0;
bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);

/// 主家に仕える身（大名その人は除く）。
bool _retainer(Game g) =>
    g.l.rank >= 1 && g.l.rank <= 7 && g.active && !_monk(g) && _lordAlive(g);

/// 主家に仕える侍（戦える人）。
bool _samurai(Game g) => _retainer(g) && g.canFight;

bool _merchant(Game g) =>
    g.l.rank == 0 &&
    g.active &&
    !_monk(g) &&
    !_outlaw(g) &&
    (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

bool _priest(Game g) => _monk(g) && g.active;

String _house(Game g) => houseName(g, g.l.lord);

/// 自分の主家でない、近い家（なければ null）。
String? _nearOther(Game g) {
  final others = g.alive.where((f) => f.name != g.l.lord).toList();
  if (others.isEmpty) return null;
  final near = g.l.lord != null
      ? nearest(others, (f) => f.name, faction: g.l.lord, n: 3)
      : nearest(others, (f) => f.name, region: g.l.region, n: 3);
  return g.rng.pick(near).name;
}

// ================================================================
// 幼なじみ
// ================================================================

Person? _os(Game g) => g.l.people['幼なじみ'];
bool _osFemale(Person p) => p.name.startsWith('お');

/// あなたのほうが上に立った（侍の位が上がった・店を大きくした）。
bool _iRose(Game g) =>
    g.l.rank >= 3 || (_merchant(g) && g.l.gold >= 40);

// ================================================================
// 好敵手
// ================================================================

Person? _rv(Game g) => g.l.people['好敵手'];

/// 張り合う場: bu=侍・oku=奥で仕える女性・shop=商い・tera=寺。無ければ null。
String? _arena(Game g) {
  if (_retainer(g)) return g.canFight ? 'bu' : 'oku';
  if (_merchant(g)) return 'shop';
  if (_priest(g)) return 'tera';
  return null;
}

// ================================================================
// 師
// ================================================================

Person? _ms(Game g) => g.l.people['師'];
bool _swordMaster(Game g, Person p) =>
    g.hasFlag('master_bu') || p.name.contains('剣客');

String? _msName(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('bd_ms_name:')) return f.substring(11);
  }
  return null;
}

/// 師の墓へ連れていける、教えを継ぐ者（弟子・教え子・跡継ぎ）。
Person? _heir(Game g) {
  for (final r in const ['弟子', '槍の弟子', '武芸の弟子', '薙刀の弟子', '手習いの教え子', '嫡男', '子', '養子']) {
    final p = g.l.people[r];
    if (p != null) return p;
  }
  return null;
}

// ================================================================
// 連れ合い
// ================================================================

Person? _sp(Game g) => g.l.married ? g.l.people['伴侶'] : null;
bool _spOk(Game g) => _sp(g) != null && !_monk(g);

/// 縁の場面。どれも [bondRested] の年にだけ出る。
List<SceneDef> buildBondScenes() => [
  for (final s in _bondScenes())
    SceneDef(
      s.id,
      s.minAge,
      s.maxAge,
      s.weight,
      (g) => bondRested(g) && s.cond(g),
      s.run,
      ageOk: s.ageOk,
      repeat: s.repeat,
      onlyForced: s.onlyForced,
    ),
];

List<SceneDef> _bondScenes() => [
  // ================================================================
  // 幼なじみ 一の段: 身分の差が開く。
  SceneDef(
    'bd_os_gap',
    18,
    50,
    (g) => _first(g),
    (g) => _os(g) != null,
    (g, next) {
      final l = g.l;
      final fr = _os(g)!;
      final n = fr.name;
      final high = _iRose(g);
      g.setFlag(high ? 'bd_os_high' : 'bd_os_low');
      _stamp(g, 'os');
      final String text;
      if (high) {
        text = l.rank >= 1
            ? 'いまや${g.rk[l.rank]}となったあなたと、昔のままの暮らしを続ける$nとでは、身分が違ってしまった。道で会うと、$nのほうが先に頭を下げるようになった。'
            : '店を大きくしたあなたと、その日暮らしの$nとでは、暮らしぶりが違ってしまった。$nは、店の敷居をまたぐのをためらうようになった。';
      } else {
        text = _osFemale(fr)
            ? '$nは名のある家に嫁ぎ、奥に入った。会いに行っても、取り次ぎの者が首を振るばかりだ。'
            : '$nは侍に取り立てられ、いまでは馬に乗って通りを行く。屋敷を訪ねても、門の前で長く待たされるようになった。';
      }
      g.ask('開いた身分', text, [
        Choice.h(
          high ? '身分を気にせず、昔のように訪ねる' : '門の前で待ってでも会う',
          '昔のままでいられる。人目を気にする者は眉をひそめる',
          () {
            _bond(fr, 12);
            if (high && l.rank >= 1) l.fav = _c(l.fav - 3);
            g.j(3);
            g.setFlag('bd_os_kept');
            g.mark('身分の開いた幼なじみの$nと、昔のままに会い続けた');
            return high
                ? '$nの家の土間で、昔のように車座になって笑った。'
                : '日が傾くころ、ようやく出てきた$nは、昔と同じ顔で笑った。';
          },
        ),
        Choice.h('折々に文だけを送る', 'つかず離れずでいられる。間合いは少しずつ開く', () {
          _bond(fr, -3);
          g.setFlag('bd_os_letters');
          return '季節ごとに短い文を送った。返事は、いつも少し遅れて届いた。';
        }),
        Choice.h('会うのをやめる', '気は楽になる。友は遠くなる', () {
          _bond(fr, -15);
          g.setFlag('bd_os_apart');
          g.mark('身分の開いた幼なじみの$nと、会うのをやめた');
          return '$nの名を聞いても、聞こえないふりをするようになった。';
        }),
      ], after: next);
    },
  ),

  // 幼なじみ 二の段: 頼みごと。
  SceneDef(
    'bd_os_ask',
    20,
    65,
    (g) => _wait(g, 'os', 2),
    (g) => _os(g) != null && _since(g, 'bd_os_gap', 'os', 2),
    (g, next) {
      final l = g.l;
      final fr = _os(g)!;
      final n = fr.name;
      final high = g.hasFlag('bd_os_high');
      _stamp(g, 'os');
      // 頼みの中身: 口添え（あなたが主家に仕える）・銭（あなたが上）・宿（友が落ちぶれた）。
      final kind = high ? (_retainer(g) ? 'post' : 'coin') : 'roof';
      final String text, hint;
      switch (kind) {
        case 'post':
          text = _osFemale(fr)
              ? '$nが、思い詰めた顔で訪ねてきた。「息子を、${_house(g)}家に奉公させてはもらえぬか。草履取りでも構わぬ」'
              : '$nが、思い詰めた顔で訪ねてきた。「頼む。${_house(g)}家に、口をきいてはもらえぬか。槍持ちでも草履取りでも構わぬ」';
          hint = '友は救われる。しくじれば、口をきいたあなたの名にも傷がつく';
        case 'coin':
          text = '$nが訪ねてきた。凶作で田を手放しかけているという。「少しでいい、銭を貸してほしい」';
          hint = '友は救われる。蔵は軽くなり、返ってくるかは分からない';
        default:
          text = _osFemale(fr)
              ? '$nの嫁ぎ先が傾き、$nは家を出されたと聞いた。ある夜、$nが戸口に立っていた。「しばらく、置いてもらえぬか」'
              : '$nの主家が傾き、$nは禄を失ったと聞いた。ある夜、$nが戸口に立っていた。「しばらく、置いてもらえぬか」';
          hint = '友は救われる。暮らしは苦しくなる';
      }
      g.ask('友の頼み', text, [
        Choice.h('願いを聞き入れる', hint, () {
          g.setFlag('bd_os_helped');
          g.mark('幼なじみの$nの頼みを聞き入れた');
          switch (kind) {
            case 'post':
              if (g.rng.chance(.25)) {
                _bond(fr, 10);
                l.fav = _c(l.fav - 6);
                return '$nの縁者は奉公先でしくじり、口をきいたあなたまで、殿に渋い顔をされた。';
              }
              _bond(fr, 18);
              l.net += 2;
              return '口添えは通った。$nは、何度も頭を下げて帰っていった。';
            case 'coin':
              _pay(g, 8);
              _bond(fr, 18);
              return '$nは銭の包みを両手で受け取り、しばらく顔を上げなかった。';
            default:
              _pay(g, 4);
              _bond(fr, 20);
              g.j(-1);
              return '$nは納屋の隅に寝起きし、黙って薪を割った。ひと冬が過ぎるころ、新しい奉公先を見つけて出ていった。';
          }
        }),
        Choice.h('できる範囲で手を貸す', '角は立たない。友の胸には、物足りなさが残る', () {
          _pay(g, 2);
          _bond(fr, 3);
          g.setFlag('bd_os_half');
          return '少しばかりの銭を包んだ。$nは礼を言ったが、目は笑っていなかった。';
        }),
        Choice.h('断る', '我が身は守れる。友の目は冷えるかもしれない', () {
          _bond(fr, -20);
          g.setFlag('bd_os_refused');
          g.mark('幼なじみの$nの頼みを断った');
          return '「そうか」とだけ言って、$nは帰っていった。振り返らなかった。';
        }),
      ], after: next);
    },
  ),

  // 幼なじみ 三の段: 絆が深ければ和解・恩返し、浅ければ仲違い。
  SceneDef(
    'bd_os_turn',
    22,
    75,
    (g) => _wait(g, 'os', 2),
    (g) => _os(g) != null && _since(g, 'bd_os_ask', 'os', 2),
    (g, next) {
      final fr = _os(g)!;
      final n = fr.name;
      _stamp(g, 'os');
      if (fr.bond >= 50) {
        final text = g.hasFlag('bd_os_helped')
            ? '$nが、あの日の礼だと言って、酒の樽を抱えてやって来た。「借りは返す。それが、子どもの頃からの決まりだろう」'
            : '$nがふらりと訪ねてきた。「あの頃は、互いに若かった」。照れたように、昔の話を始めた。';
        g.ask('友との盃', text, [
          Choice.h('夜通し酒を酌み交わす', '昔に戻れる。翌朝はつらい', () {
            _bond(fr, 12);
            g.j(8);
            g.l.hp -= 2;
            g.setFlag('bd_os_close');
            g.mark('幼なじみの$nと、夜通し酒を酌み交わした');
            return '気づけば、東の空が白んでいた。$nは、昔と同じいびきをかいて眠った。';
          }),
          Choice.h('礼は要らぬと笑って返す', '友の誇りは少し傷つく。気持ちは通う', () {
            _bond(fr, 5);
            g.l.net += 2;
            g.setFlag('bd_os_close');
            return '「相変わらずだな」と、$nは苦笑いして樽を担ぎ直した。';
          }),
        ], after: next);
        return;
      }
      final text = g.hasFlag('bd_os_refused')
          ? '$nが、あなたのことを「出世して昔を忘れた者だ」と、あちこちで言っていると聞いた。'
          : '$nとは、いつの間にか行き来が絶えた。風の噂に、$nがあなたを恨んでいると聞いた。';
      g.ask('友との溝', text, [
        Choice.h('会いに行き、腹を割って話す', '縁が戻るかもしれない。言い争いになるかもしれない', () {
          if (g.rng.chance(.45 + g.l.mi / 200)) {
            fr.bond = fr.bond < 55 ? 55 : fr.bond;
            g.j(8);
            g.setFlag('bd_os_reconciled');
            g.mark('仲違いしかけた幼なじみの$nと、腹を割って話し、和解した');
            return '言いたいことを言い合ったあと、$nは「馬鹿らしい」と吹き出した。';
          }
          _bond(fr, -10);
          g.j(-4);
          g.setFlag('bd_os_rift');
          return '話すほどに、言葉がすれ違った。$nは戸を閉めた。';
        }),
        Choice.h('言わせておく', '騒ぎにはならない。溝は埋まらない', () {
          _bond(fr, -10);
          g.setFlag('bd_os_rift');
          g.mark('幼なじみの$nと、仲違いしたままになった');
          return '噂はやがて静まった。$nとの行き来も、それきり絶えた。';
        }),
        if (_rv(g) == null)
          Choice.h('見返してやると心に決める', '負けん気は力になる。友は好敵手に変わる', () {
            g.l.people.remove('幼なじみ');
            g.meet('好敵手', n, 10);
            g.setFlag('rival');
            g.setFlag('bd_os_to_rival');
            g.mark('幼なじみの$nを、見返すべき好敵手と定めた');
            return '$nにだけは負けない。子どもの頃の喧嘩の続きが、始まった。';
          }),
      ], after: next);
    },
  ),

  // 幼なじみ 枝の段: 敵味方に分かれる（戦える侍・大名だけ。男の幼なじみ）。
  SceneDef(
    'bd_os_foes',
    22,
    60,
    (g) => _wait(g, 'os', 2),
    (g) {
      final fr = _os(g);
      return fr != null &&
          !_osFemale(fr) &&
          g.canFight &&
          (_samurai(g) || (g.l.rank >= 8 && g.active && !_monk(g))) &&
          g.alive.any((f) => f.name != g.l.lord) &&
          _since(g, 'bd_os_ask', 'os', 2);
    },
    (g, next) {
      final l = g.l;
      final fr = _os(g)!;
      final n = fr.name;
      final foe = houseName(g, _nearOther(g));
      _stamp(g, 'os');
      g.ask(
        '敵方の友',
        '$nが$foe家に仕え、組を預かるまでになったと聞いた。次の戦で、$foe家とぶつかる。陣立てを見れば、$nの隊は、あなたの隊の真向かいだ。',
        [
          Choice.h('戦場で、正面から相まみえる', '手柄にはなる。友を討つかもしれず、友に討たれるかもしれない', () {
            _bond(fr, -15);
            if (g.rng.chance(.04)) {
              g.die('敵方にいた幼なじみと槍を合わせ、討たれた', 'senshi');
              return '槍を合わせたとき、$nの顔に迷いはなかった。';
            }
            if (g.rng.chance(.25)) {
              l.people.remove('幼なじみ');
              l.merit += 8;
              g.j(-15);
              g.setFlag('bd_os_slew');
              g.mark('戦場で、敵方の幼なじみ$nを討った');
              return '倒れた$nは、最後に子どもの頃の呼び名であなたを呼んだ。';
            }
            l.merit += 3;
            g.j(-5);
            return '槍を合わせ、互いに手傷を負って分かれた。乱戦の中で、$nの背中を見失った。';
          }),
          Choice.h('こちらへ降るよう、文を送る', '引き入れれば手柄。文が奪われれば、敵と通じていると疑われる', () {
            if (g.rng.chance(.35 + l.chi / 300)) {
              _bond(fr, 15);
              l.net += 3;
              l.merit += 4;
              g.setFlag('bd_os_turned');
              g.mark('敵方にいた幼なじみの$nを、文で味方に引き入れた');
              return '戦の前夜、$nが手勢を連れて陣を抜け、こちらへ馳せ参じた。';
            }
            l.fav = _c(l.fav - 8);
            g.setFlag('bd_os_suspected');
            return '文は$nに届く前に奪われ、あなたは敵と通じていると陰で言われた。';
          }),
          Choice.h('戦の前に、陣替えを願い出る', '友と刃を交えずに済む。臆したと見る者もいる', () {
            l.fav = _c(l.fav - 5);
            _bond(fr, 5);
            g.setFlag('bd_os_avoided');
            return '別の口へ回された。遠くに$nの隊の旗が見えたが、刃は交えずに済んだ。';
          }),
        ],
        after: next,
      );
    },
  ),

  // 幼なじみ 終の段: 晩年の再会。絆が深ければ昔話、浅ければ病の床へ。
  SceneDef(
    'bd_os_old',
    40,
    84,
    (g) => _wait(g, 'os', 3),
    (g) => _os(g) != null && _since(g, 'bd_os_turn', 'os', 3),
    (g, next) {
      final fr = _os(g)!;
      final n = fr.name;
      _stamp(g, 'os');
      if (fr.bond >= 50) {
        g.ask('老いた友', '白髪の$nが、杖をついて訪ねてきた。「生きているうちに、もう一度会っておきたくてな」', [
          Choice.h('縁側で、日が暮れるまで昔話をする', '心が温まる。過ぎた日がまぶしく、少し寂しくなる', () {
            _bond(fr, 5);
            g.j(12);
            g.setFlag('bd_os_oldtalk');
            g.mark('老いた幼なじみの$nと、日が暮れるまで昔話をした');
            return '川で溺れかけた話を、$nは三度もした。三度とも、二人で笑った。';
          }),
          Choice.h('子どもの頃に遊んだ場所を、二人で歩く', '思い出の地に立てる。老いた足には遠い道だ', () {
            g.l.hp -= 4;
            _bond(fr, 8);
            g.j(15);
            g.setFlag('bd_os_walk');
            g.mark('老いた幼なじみの$nと、子どもの頃に遊んだ場所を歩いた');
            return '昔登った木は、思っていたよりずっと低かった。$nが、その幹を叩いて笑った。';
          }),
        ], after: next);
        return;
      }
      g.ask('友の病', '$nが病で長くないと、人づてに聞いた。仲違いしたまま、もう何年も会っていない。', [
        Choice.h('会いに行く', '最後に言葉を交わせるかもしれない。門前払いされるかもしれない', () {
          if (g.rng.chance(.75)) {
            fr.bond = 60;
            g.j(10);
            g.setFlag('bd_os_last_peace');
            g.mark('長く仲違いした幼なじみの$nと、病の床で手を取り合った');
            return '$nは痩せた手であなたの手を握り、「遅いぞ」とだけ言った。';
          }
          g.j(-6);
          g.setFlag('bd_os_never');
          return '戸口に出てきた家の者が、首を横に振った。';
        }),
        Choice.h('行かずに、遠くから祈る', '心は乱れずに済む。悔いが残るかもしれない', () {
          g.j(-4);
          g.setFlag('bd_os_never');
          return '夜、$nの家の方角に向かって、長いこと手を合わせた。';
        }),
      ], after: next);
    },
  ),

  // ================================================================
  // 好敵手 一の段: 腕比べ（好敵手がいなければ、ここで張り合う相手が現れる）。
  SceneDef(
    'bd_rv_match',
    17,
    45,
    (g) => _rv(g) != null ? _first(g) + 1 : _first(g) - 3,
    (g) => _arena(g) != null,
    (g, next) {
      final l = g.l;
      final a = _arena(g)!;
      final fresh = _rv(g) == null;
      if (fresh) {
        g.meet('好敵手', g.rng.pick(l.female ? kGivenF : kGivenM), 25);
      }
      final rv = _rv(g)!;
      final n = rv.name;
      _stamp(g, 'rv');
      final head = fresh
          ? switch (a) {
              'bu' => '同じ頃に${_house(g)}家に仕えた$nとは、何かにつけて比べられてきた。',
              'oku' => '同じ頃に奥へ上がった$nとは、何かにつけて比べられてきた。',
              'shop' => '同じ通りに店を構える$nとは、何かにつけて比べられてきた。',
              _ => '同じ寺で学んだ$nとは、何かにつけて比べられてきた。',
            }
          : '好敵手の$nと、また張り合うときが来た。';
      final body = switch (a) {
        'bu' => '殿の前で、槍の腕比べをすることになった。',
        'oku' => '奥方さまの前で、歌合わせをすることになった。',
        'shop' => '同じ荷の仕入れを、二人で争うことになった。',
        _ => '論義の座で、問答を競うことになった。',
      };
      final skill = switch (a) {
        'bu' => l.bu,
        'oku' => l.mi,
        'shop' => l.sei,
        _ => l.chi,
      };
      g.ask('腕比べ', '$head$body', [
        Choice.h('正面から競う', '勝てば名が上がる。負ければ笑われる', () {
          if (g.rng.chance(.35 + skill / 200)) {
            l.merit += 3;
            l.fame += 2;
            _bond(rv, 8);
            g.j(5);
            g.setFlag('bd_rv_win1');
            g.mark('好敵手の$nとの腕比べに勝った');
            return '勝負がついたあと、$nは悔しそうに、それでも頭を下げた。';
          }
          _bond(rv, 4);
          g.j(-4);
          return '$nに一歩及ばなかった。次こそは、と拳を握った。';
        }),
        Choice.h('裏で手を回して勝つ', '勝ちは近い。相手に気づかれるかもしれない', () {
          l.merit += 2;
          g.setFlag('bd_rv_foul');
          if (g.rng.chance(.4)) {
            _bond(rv, -20);
            return '勝ちは手にした。だが$nは、何をされたか、すっかり気づいていた。';
          }
          _bond(rv, -5);
          return '勝ちは手にした。$nは首をかしげたまま、負けを認めた。';
        }),
        Choice.h('勝ちを譲る', '角は立たない。相手に貸しが残るか、侮られるか', () {
          _bond(rv, 10);
          g.j(-2);
          g.setFlag('bd_rv_yield');
          return 'わざと隙を見せた。$nは勝ったあと、妙な顔でこちらを見ていた。';
        }),
      ], after: next);
    },
  ),

  // 好敵手 二の段: 出世争い。
  SceneDef(
    'bd_rv_rise',
    19,
    60,
    (g) => _wait(g, 'rv', 2),
    (g) => _rv(g) != null && _arena(g) != null && _since(g, 'bd_rv_match', 'rv', 2),
    (g, next) {
      final l = g.l;
      final a = _arena(g)!;
      final rv = _rv(g)!;
      final n = rv.name;
      _stamp(g, 'rv');
      final seat = switch (a) {
        'bu' => '先手の組を預かる役',
        'oku' => '奥の取りまとめの役',
        'shop' => '町の年寄の座',
        _ => '本山の役僧の座',
      };
      void win() {
        if (a == 'bu' || a == 'oku') {
          l.fav = _c(l.fav + 5);
          l.merit += 4;
        } else {
          l.net += 3;
          l.fame += 2;
        }
      }

      g.ask('出世争い', '$seatが一つ空き、あなたと$nの名が並んだ。', [
        Choice.h('働きぶりで争う', '公平に決まる。負けても恥ではない', () {
          _bond(rv, 5);
          if (g.rng.chance(.45)) {
            win();
            g.setFlag('bd_rv_rose');
            g.mark('好敵手の$nと争い、$seatに就いた');
            return '$seatは、あなたに決まった。$nは黙って祝いの品を届けてきた。';
          }
          g.j(-3);
          g.setFlag('bd_rv_passed');
          return '$seatは$nに決まった。悔しかったが、文句のつけようもなかった。';
        }),
        Choice.h('上の者に付け届けをする', '座は近づく。知れれば、相手は黙っていない', () {
          _pay(g, 6);
          _bond(rv, -15);
          g.setFlag('bd_rv_bribed');
          if (g.rng.chance(.7)) {
            win();
            g.mark('付け届けをして、好敵手の$nを退け、$seatに就いた');
            return '$seatはあなたに決まった。$nの冷たい目が、背中に刺さった。';
          }
          return '付け届けは無駄になった。$seatは$nに決まり、噂だけが残った。';
        }),
        Choice.h('$nを推す', '相手は恩に着るかもしれない。自分の出世は遠のく', () {
          _bond(rv, 20);
          l.net += 2;
          g.j(-2);
          g.setFlag('bd_rv_backed');
          g.mark('好敵手の$nを、$seatに推した');
          return '$nは信じられないという顔をして、それから深く頭を下げた。';
        }),
      ], after: next);
    },
  ),

  // 好敵手 三の段: 好敵手の窮地を救うか、見捨てるか。
  SceneDef(
    'bd_rv_peril',
    21,
    65,
    (g) => _wait(g, 'rv', 2),
    (g) => _rv(g) != null && _arena(g) != null && _since(g, 'bd_rv_rise', 'rv', 2),
    (g, next) {
      final l = g.l;
      final a = _arena(g)!;
      final rv = _rv(g)!;
      final n = rv.name;
      _stamp(g, 'rv');
      String saved(String text) {
        _bond(rv, 30);
        g.j(5);
        g.setFlag('bd_rv_saved');
        g.mark('窮地の好敵手$nを救った');
        return text;
      }

      String left(String text) {
        _bond(rv, -25);
        g.j(-6);
        g.setFlag('bd_rv_abandoned');
        g.mark('窮地の好敵手$nを、見捨てた');
        return text;
      }

      switch (a) {
        case 'bu':
          g.ask('好敵手の窮地', '戦で、$nの隊が敵中に取り残された。助けに行ける近さにいるのは、あなたの隊だけだ。', [
            Choice.h('斬り込んで助け出す', '$nは救われる。乱戦では、命の保証はない', () {
              if (g.rng.chance(.04)) {
                g.die('敵中に取り残された好敵手を救おうと斬り込み、討たれた', 'senshi');
                return '$nの姿が見えたところで、横合いから槍が来た。';
              }
              l.merit += 6;
              return saved('敵の囲みを破って$nの隊を連れ戻した。$nは血まみれの顔で、何か言いかけてやめた。');
            }),
            Choice.h('本陣へ知らせて援けを呼ぶ', '手堅い。援けが間に合うかは分からない', () {
              g.setFlag('bd_rv_helped');
              if (g.rng.chance(.6)) {
                _bond(rv, 10);
                return '援けは間に合い、$nは生きて戻った。';
              }
              _bond(rv, -5);
              return '援けが着いたとき、$nは深手を負っていた。命は取り留めた。';
            }),
            Choice.h('見なかったことにする', '手柄も役目も自分に回ってくる。胸に重いものが残る', () {
              l.merit += 3;
              l.fav = _c(l.fav + 3);
              return left('$nは、半ば死にかけて自力で戻ってきた。あなたの隊の旗を、じっと見ていた。');
            }),
          ], after: next);
        case 'oku':
          g.ask('好敵手の窮地', '$nが、奥方さまの櫛を盗んだと疑われ、暇を出されかけている。その日、$nが別の間にいたのを、あなたは見ていた。', [
            Choice.h('奥方さまの前で、見たことを申し上げる', '$nは救われる。$nを疑った人たちの恨みを買う', () {
              l.fav = _c(l.fav - 3);
              return saved('疑いは晴れた。$nは廊下ですれ違うとき、小さく「借りができた」と言った。');
            }),
            Choice.h('そっと$nに伝え、自分で申し開きをさせる', '角は立たない。$nの言葉だけで通るかは分からない', () {
              g.setFlag('bd_rv_helped');
              if (g.rng.chance(.5)) {
                _bond(rv, 10);
                return '$nは自分で申し開きをし、疑いは晴れた。';
              }
              _bond(rv, -5);
              return '$nの申し開きは通らず、しばらく奥の端へ下げられた。';
            }),
            Choice.h('黙っている', '張り合う相手がいなくなる。胸に重いものが残る', () {
              l.fav = _c(l.fav + 3);
              return left('$nは暇を出されかけ、ひと月のあいだ泣き暮らした。あなたを見る目が変わった。');
            }),
          ], after: next);
        case 'shop':
          g.ask('好敵手の窮地', '$nの店が、船荷を失って潰れかけている。銭の当てがなく、奉公人にも暇を出し始めたという。', [
            Choice.h('銭を貸して支える', '$nは救われる。蔵は軽くなる', () {
              _pay(g, 10);
              return saved('$nは貸した銭で持ちこたえた。「この恩は、商いで返す」と言った。');
            }),
            Choice.h('取引先を引き合わせる', '手堅い。それで足りるかは分からない', () {
              g.setFlag('bd_rv_helped');
              if (g.rng.chance(.6)) {
                _bond(rv, 10);
                return '引き合わせた先が荷を回し、$nの店はどうにか持ち直した。';
              }
              _bond(rv, -5);
              return '$nの店は持ち直せず、表の暖簾が半分に減った。';
            }),
            Choice.h('$nの客を引き取る', '店は大きくなる。恨みは深くなる', () {
              l.gold += 8;
              return left('$nの客は、そっくりあなたの店に流れてきた。$nは、通りで会っても目をそらした。');
            }),
          ], after: next);
        default:
          g.ask('好敵手の窮地', '$nが、本山の教えに背いたと咎められ、寺を追われかけている。', [
            Choice.h('本山に出向いて執り成す', '$nは救われる。あなたも同じ目で見られかねない', () {
              _fameDown(g, 2);
              return saved('長い問答の末、$nの咎めは解かれた。$nは、あなたの袖をつかんで離さなかった。');
            }),
            Choice.h('寺を出たあとの身の寄せ所を探してやる', '手堅い。$nの誇りは傷つくかもしれない', () {
              g.setFlag('bd_rv_helped');
              _bond(rv, 6);
              return '$nは山あいの小さな庵に移った。礼の文は、短かった。';
            }),
            Choice.h('黙って見送る', '張り合う相手がいなくなる。胸に重いものが残る', () {
              return left('$nは寺を追われた。山門を出るとき、一度だけこちらを振り返った。');
            }),
          ], after: next);
      }
    },
  ),

  // 好敵手 四の段: 絆が深ければ認め合い、浅ければ討ち合う。
  SceneDef(
    'bd_rv_end',
    23,
    75,
    (g) => _wait(g, 'rv', 3),
    (g) => _rv(g) != null && _since(g, 'bd_rv_peril', 'rv', 3),
    (g, next) {
      final l = g.l;
      final rv = _rv(g)!;
      final n = rv.name;
      _stamp(g, 'rv');
      final fight = g.canFight && l.rank >= 1 && !_monk(g);
      if (rv.bond >= 50) {
        g.ask('好敵手と盃', '$nが、酒をさげて訪ねてきた。「長いこと張り合ってきたが、お前がいたから、ここまで来られた」', [
          Choice.h('盃を受け、互いを認め合う', '長い張り合いが報われる。張り合う熱は冷めていく', () {
            _bond(rv, 10);
            g.j(10);
            g.setFlag('bd_rv_respect');
            g.mark('好敵手の$nと盃を交わし、互いを認め合った');
            return '盃を干すと、$nは「次に生まれても、お前と張り合いたい」と言った。';
          }),
          Choice.h(fight ? '最後にもう一度、木刀で手合わせを望む' : '碁盤を出して、一局を望む', '昔のように熱くなれる。勝ち負けはまた残る', () {
            _bond(rv, 6);
            if (fight) l.bu = _s(l.bu + 1);
            g.j(8);
            g.setFlag('bd_rv_respect');
            g.setFlag('bd_rv_last_bout');
            return '勝負はつかなかった。二人とも息を切らし、声を上げて笑った。';
          }),
        ], after: next);
        return;
      }
      if (fight) {
        final text = g.hasFlag('bd_rv_abandoned')
            ? '「あの日、お前は俺を見捨てた」。$nから、果たし状が届いた。'
            : '積もり積もった恨みの末に、$nから果たし状が届いた。';
        g.ask('果たし状', text, [
          Choice.h('受けて立つ', '決着はつく。命のやり取りになる。私闘は咎められることもある', () {
            if (g.rng.chance(.05)) {
              g.die('好敵手との果たし合いで斬られた', 'senshi');
              return '夜明けの河原で、$nの太刀が先に届いた。';
            }
            if (g.rng.chance(.35 + l.bu / 300)) {
              l.people.remove('好敵手');
              l.fame += 3;
              g.j(-10);
              if (g.rng.chance(.3)) l.fav = _c(l.fav - 8);
              g.setFlag('bd_rv_slew');
              g.mark('果たし合いで、好敵手の$nを斬った');
              return '$nは膝をつき、「やはり、お前か」と呟いて倒れた。';
            }
            l.hp -= 15;
            rv.bond = 50;
            g.setFlag('bd_rv_draw');
            return '互いに深手を負い、立ち会いの者が割って入った。それきり、$nの目から憎しみが消えた。';
          }),
          Choice.h('果たし状を破り捨てる', '命は惜しめる。臆したと言われる', () {
            _fameDown(g, 3);
            g.j(-4);
            g.setFlag('bd_rv_refused_duel');
            return '臆病者という噂が立った。$nは、それで気が済んだらしかった。';
          }),
          Choice.h('人を介して和を申し入れる', '争いは収まるかもしれない。こちらから折れることになる', () {
            if (g.rng.chance(.5 + l.mi / 300)) {
              rv.bond = 50;
              g.setFlag('bd_rv_peace');
              return '間に立った者の顔を立て、$nは果たし状を取り下げた。';
            }
            _bond(rv, -5);
            return '$nは使いの者を追い返した。';
          }),
        ], after: next);
        return;
      }
      g.ask('訴え', '$nが、あなたの落ち度を上の者に訴え出た。長年の張り合いが、とうとう表沙汰になった。', [
        Choice.h('堂々と申し開きをする', '筋が通れば退けられる。言葉に詰まれば立場が危うい', () {
          if (g.rng.chance(.5 + l.chi / 250)) {
            l.fame += 2;
            g.setFlag('bd_rv_won_case');
            g.mark('好敵手の$nの訴えを、申し開きで退けた');
            return '申し開きは通った。$nは顔を赤くして下がった。';
          }
          if (l.rank >= 1) {
            l.fav = _c(l.fav - 8);
          } else {
            _netDown(g, 2);
          }
          g.j(-5);
          return '言葉に詰まり、訴えの半ばが通ってしまった。';
        }),
        Choice.h('$nの古い不始末を持ち出して返す', '勝ちやすい。縁は二度と戻らない', () {
          rv.bond = 0;
          g.setFlag('bd_rv_feud');
          if (g.rng.chance(.6)) {
            l.fame += 1;
            return '$nの不始末が明るみに出て、訴えはうやむやになった。';
          }
          _netDown(g, 2);
          return '泥仕合になり、二人とも人の笑いものになった。';
        }),
        Choice.h('頭を下げて収める', '騒ぎは静まる。負けを認めることになる', () {
          _bond(rv, 15);
          g.j(-4);
          g.setFlag('bd_rv_bowed');
          return 'あなたが頭を下げると、$nは拍子抜けしたように訴えを取り下げた。';
        }),
      ], after: next);
    },
  ),

  // 好敵手 終の段: 好敵手の死を聞く（好敵手は人物から外れる）。
  SceneDef(
    'bd_rv_death',
    32,
    84,
    (g) => _wait(g, 'rv', 3),
    (g) => _rv(g) != null && _since(g, 'bd_rv_end', 'rv', 3),
    (g, next) {
      final l = g.l;
      final rv = _rv(g)!;
      final n = rv.name;
      _stamp(g, 'rv');
      l.people.remove('好敵手');
      g.setFlag('bd_rv_dead');
      final how = _samurai(g) ? '戦で討たれた' : '病で亡くなった';
      final text = '好敵手の$nが$howと聞いた。張り合う相手のいない朝は、妙に静かだった。';
      if (rv.bond >= 50) {
        g.ask('好敵手の死', text, [
          Choice.h('弔いに駆けつけ、棺を担ぐ', '最後の別れができる。胸の穴は埋まらない', () {
            l.net += 2;
            g.j(-3);
            g.setFlag('bd_rv_mourned');
            g.mark('生涯の好敵手$nの棺を担いだ');
            return '棺は、思っていたよりずっと軽かった。';
          }),
          Choice.h('遺された子に目をかけてやる', '$nへの供養になる。いくらか銭はかかる', () {
            _pay(g, 3);
            l.net += 3;
            g.setFlag('bd_rv_kin');
            g.mark('亡き好敵手$nの遺児に、目をかけてやった');
            return '$nの子は、父親そっくりの負けず嫌いな目をしていた。';
          }),
          Choice.h('一人で、盃を二つ並べる', '静かに偲べる。寂しさは深くなる', () {
            g.j(-2);
            g.setFlag('bd_rv_cup');
            return '向かいの盃は、朝まで減らなかった。';
          }),
        ], after: next);
        return;
      }
      g.ask('好敵手の死', text, [
        Choice.h('弔いに行き、わだかまりを墓に置いてくる', '胸のつかえが下りるかもしれない。遺された者の目は冷たい', () {
          g.j(3);
          g.setFlag('bd_rv_forgave');
          g.mark('いがみ合った好敵手$nの墓に、わだかまりを置いてきた');
          return '墓の前で、言いそびれたことをいくつか口にした。返事はなかった。';
        }),
        Choice.h('行かない。勝ち負けは、もうつかない', '意地は通せる。張り合いの糸は、宙に浮いたままになる', () {
          g.j(-6);
          g.setFlag('bd_rv_unsettled');
          return '勝ったのか負けたのか、とうとう分からないまま終わった。';
        }),
      ], after: next);
    },
  ),

  // ================================================================
  // 師 一の段: 師の教えが役立つ場面。
  SceneDef(
    'bd_ms_lesson',
    17,
    45,
    (g) => _first(g),
    (g) => _ms(g) != null && g.active && !_outlaw(g),
    (g, next) {
      final l = g.l;
      final m = _ms(g)!;
      final n = m.name;
      _stamp(g, 'ms');
      if (_swordMaster(g, m) && g.canFight) {
        g.ask('師の教え', '夜道で、刀を抜いた男たちに囲まれた。ふと、$nの言葉がよみがえる。「囲まれたら、まず一人の後ろへ回れ」', [
          Choice.h('師の教えどおりに動く', '師の目は確かだ。教わったとおりに体が動くかどうか', () {
            _bond(m, 10);
            l.bu = _s(l.bu + 2);
            l.hp -= 3;
            g.setFlag('bd_ms_used');
            g.mark('$nの教えどおりに動き、夜道の囲みを破った');
            return '一人の後ろへ回ると、囲みが崩れた。男たちは散り散りに逃げていった。';
          }),
          Choice.h('己の腕を信じて斬り結ぶ', '腕が立てば切り抜けられる。深手を負うかもしれない', () {
            if (g.rng.chance(.5 + l.bu / 300)) {
              l.bu = _s(l.bu + 1);
              l.fame += 1;
              return '真正面から斬り結び、男たちを追い払った。';
            }
            l.hp -= 20;
            _bond(m, -3);
            return '追い払いはしたが、腕に深い傷を負った。師の言葉を思い出したのは、手当てのあとだった。';
          }),
          Choice.h('走って逃げる', '恥はかく。命は残る', () {
            g.j(-3);
            return '息が切れるまで走った。走り方だけは、師に教わらなかった。';
          }),
        ], after: next);
        return;
      }
      final scene = _retainer(g)
          ? '殿の前で、言い分の割れた二人の裁きを任された。'
          : _merchant(g)
          ? '大きな商いの談判で、相手が無理を押しつけてきた。'
          : _priest(g)
          ? '寺の者どうしの争いを、収めねばならなくなった。'
          : '寄り合いで、水の配り方をめぐって話がこじれた。';
      g.ask('師の教え', '$sceneふと、$nの言葉がよみがえる。「急ぐ者には、まず茶を出せ」', [
        Choice.h('師の教えどおり、間を置く', '場は落ち着く。急ぐ者には侮られるかもしれない', () {
          _bond(m, 10);
          l.sei = _s(l.sei + 2);
          l.net += 2;
          g.setFlag('bd_ms_used');
          g.mark('$nの教えを思い出し、こじれた場を収めた');
          return '茶を出し、相手が飲み干すまで黙っていた。それだけで、話の角が取れた。';
        }),
        Choice.h('自分の考えで押し切る', '早く片がつく。こじれれば長引く', () {
          if (g.rng.chance(.5 + l.sei / 200)) {
            l.fame += 1;
            return '押し切った。誰も文句は言わなかった。';
          }
          _netDown(g, 2);
          return '押し切ったつもりが、恨みだけが残った。';
        }),
      ], after: next);
    },
  ),

  // 師 二の段: 老いた師が頼ってくる。
  SceneDef(
    'bd_ms_old',
    21,
    65,
    (g) => _wait(g, 'ms', 3),
    (g) => _ms(g) != null && _since(g, 'bd_ms_lesson', 'ms', 3),
    (g, next) {
      final m = _ms(g)!;
      final n = m.name;
      _stamp(g, 'ms');
      final text = _swordMaster(g, m)
          ? '年老いた$nが、門の前に立っていた。道場はたたみ、刀も手放したという。「すまぬ。しばらく、置いてもらえぬか」'
          : '$nのいた寺が焼け、老いた$nには身を寄せる先もないと、文が届いた。';
      g.ask('老いた師', text, [
        Choice.h(_priest(g) ? '自分の寺に迎える' : '引き取って世話をする', '師に恩を返せる。暮らしは苦しくなる', () {
          _pay(g, 6);
          _bond(m, 20);
          g.j(4);
          g.setFlag('bd_ms_cared');
          g.mark('老いた師の$nを引き取り、世話をした');
          return '$nは縁側でよく眠った。ときどき、昔と同じ口調で小言を言った。';
        }),
        Choice.h('銭を包んで渡す', '義理は果たせる。師の寂しげな顔が残る', () {
          _pay(g, 2);
          _bond(m, 3);
          g.setFlag('bd_ms_coin');
          return '$nは包みを受け取り、「達者でな」と言って去った。';
        }),
        Choice.h('会わずに帰す', '暮らしは守れる。師との縁は冷える', () {
          _bond(m, -20);
          g.j(-5);
          g.setFlag('bd_ms_turned_away');
          return '取り次ぎの者に断らせた。門の外で、杖の音が遠ざかっていった。';
        }),
      ], after: next);
    },
  ),

  // 師 三の段: 師の最期と形見（師は人物から外れる）。絆が深ければ枕元に呼ばれる。
  SceneDef(
    'bd_ms_keep',
    23,
    75,
    (g) => _wait(g, 'ms', 2),
    (g) => _ms(g) != null && _since(g, 'bd_ms_old', 'ms', 2),
    (g, next) {
      final l = g.l;
      final m = _ms(g)!;
      final n = m.name;
      final sword = _swordMaster(g, m);
      _stamp(g, 'ms');
      l.people.remove('師');
      g.setFlag('bd_ms_dead');
      g.setFlag('bd_ms_name:$n');
      if (m.bond >= 50) {
        g.setFlag('bd_ms_deep');
        final thing = sword ? '使い込んだ一振りの刀' : '手垢のついた書と数珠';
        g.ask('師の形見', '$nが死の床で、あなたを呼んだ。「これを、お前に」。差し出されたのは、$thingだった。', [
          Choice.h(
            sword ? '形見の刀を腰に差す' : '形見の書を読み継ぐ',
            '師がそばにいるように思える。古い流儀だと笑う者もいる',
            () {
              if (sword) {
                l.bu = _s(l.bu + 3);
              } else {
                l.chi = _s(l.chi + 3);
              }
              g.j(5);
              g.setFlag('bd_ms_keepsake');
              g.mark('師の$nから、形見の${sword ? '刀' : '書'}を託された');
              return '$nは、あなたが受け取るのを見届けてから、静かに目を閉じた。';
            },
          ),
          Choice.h('形見は師と共に葬る', '師は安らかに眠れる。手元には何も残らない', () {
            g.j(3);
            g.setFlag('bd_ms_buried');
            g.mark('師の$nを、形見と共に葬った');
            return '棺に形見を納めた。$nの顔は、眠っているようだった。';
          }),
          Choice.h('教えを若い者に伝えると約束する', '教えは続いていく。約束は重い', () {
            l.net += 2;
            g.setFlag('bd_ms_keepsake');
            g.setFlag('bd_ms_vow');
            g.mark('師の$nの枕元で、教えを次に伝えると約束した');
            return '$nは、かすかに笑ってうなずいた。それが最後だった。';
          }),
        ], after: next);
        return;
      }
      g.setFlag('bd_ms_shallow');
      g.ask('師の死', '$nが亡くなったと、だいぶ経ってから聞いた。形見は、最後まで傍にいた弟子に渡ったという。', [
        Choice.h('墓前で、無沙汰を詫びる', '胸のつかえが少し下りる。悔いは消えない', () {
          g.j(-3);
          g.setFlag('bd_ms_regret');
          g.mark('亡き師の$nの墓前で、無沙汰を詫びた');
          return '新しい卒塔婆の前で、長いこと頭を下げていた。';
        }),
        Choice.h('形見を一目見せてもらいに行く', '師の晩年が分かる。冷たい目で迎えられるかもしれない', () {
          if (g.rng.chance(.6)) {
            g.j(4);
            l.net += 1;
            return '弟子は黙って形見を見せ、$nがときどきあなたの話をしていたと教えてくれた。';
          }
          g.j(-4);
          return '弟子は「いまさら何の用か」と言い、戸を開けなかった。';
        }),
        Choice.h('忘れることにする', '心は乱れずに済む。恩は返せないままになる', () {
          g.j(-2);
          g.setFlag('bd_ms_forgot');
          return '$nの名を、それきり口にしなかった。';
        }),
      ], after: next);
    },
  ),

  // 師 終の段: 師の墓参り。
  SceneDef(
    'bd_ms_grave',
    26,
    84,
    (g) => _wait(g, 'ms', 2),
    (g) => g.hasFlag('bd_ms_dead') && !_outlaw(g) && _since(g, 'bd_ms_keep', 'ms', 2),
    (g, next) {
      final l = g.l;
      final n = _msName(g) ?? '師';
      final heir = _heir(g);
      _stamp(g, 'ms');
      final text = g.hasFlag('bd_ms_deep')
          ? '師の$nの命日が巡ってきた。形見を携えて、墓へ向かった。'
          : '師の$nの命日が巡ってきた。長く足の遠のいていた墓へ、ようやく向かった。';
      g.ask('師の墓', text, [
        if (heir != null)
          Choice.h('${heir.name}を連れて墓に参る', '師の教えが次の代へつながる。若い者には退屈かもしれない', () {
            _bond(heir, 5);
            g.j(8);
            g.setFlag('bd_ms_grave_heir');
            g.mark('${heir.name}を連れて、師の$nの墓に参った');
            return '墓の前で、$nに教わったことを一つずつ話して聞かせた。${heir.name}は、黙って聞いていた。';
          }),
        Choice.h('傷んだ墓を建て直す', '師への恩が形に残る。銭はかかる', () {
          _pay(g, 5);
          g.j(6);
          g.setFlag('bd_ms_grave_rebuilt');
          g.mark('師の$nの傷んだ墓を、建て直した');
          return '新しい石に、$nの名を刻ませた。';
        }),
        Choice.h('墓の前で、師の教えを書き留める', '教えは残る。筆の進みは遅い', () {
          l.chi = _s(l.chi + 2);
          g.j(5);
          g.setFlag('bd_ms_book');
          g.mark('師の$nの教えを、書き留めた');
          return '思い出すままに書いた。書き終えると、日はすっかり傾いていた。';
        }),
      ], after: next);
    },
  ),

  // ================================================================
  // 連れ合い 一の段: 所帯を持って間もない頃の諍い。
  SceneDef(
    'bd_sp_new',
    16,
    40,
    // 所帯を持って日の浅いあいだ（上の子が幼いうち）しか出ないので、ほかの最初の段より重い。
    (g) => _first(g) + 5,
    (g) =>
        _spOk(g) &&
        (g.l.kids == 0 || (g.l.eldestKidAge(g.year) ?? 99) <= 4),
    (g, next) {
      final sp = _sp(g)!;
      final n = sp.name;
      _stamp(g, 'sp');
      g.ask('新しい所帯', '所帯を持ってまだ日の浅いころ。味噌汁の味ひとつで、$nと言い合いになった。互いの家の流儀が、何から何まで違う。', [
        Choice.h('自分の家の流儀を通す', '筋は通る。連れ合いの胸にしこりが残る', () {
          _bond(sp, -10);
          g.setFlag('bd_sp_own');
          return '$nは黙って従った。その晩の膳は、やけに静かだった。';
        }),
        Choice.h('連れ合いの流儀に合わせる', '家は穏やかになる。自分の好みは引っ込める', () {
          _bond(sp, 10);
          g.j(-1);
          g.setFlag('bd_sp_yield');
          return '慣れない味も、三月もすると悪くないと思えてきた。';
        }),
        Choice.h('二人の新しい流儀を決める', '話し合えば絆になる。こじれれば長引く', () {
          if (g.rng.chance(.6 + g.l.mi / 300)) {
            _bond(sp, 15);
            g.j(4);
            g.setFlag('bd_sp_ours');
            g.mark('連れ合いの$nと、二人の家の流儀を決めた');
            return '味噌は半分ずつ合わせることにした。$nは、それが気に入ったらしかった。';
          }
          _bond(sp, -5);
          return '話はまとまらず、しばらく膳の上に黙りが続いた。';
        }),
      ], after: next);
    },
  ),

  // 連れ合い 二の段: 苦しい年を支え合う。絆の深さで連れ合いの出方が変わる。
  SceneDef(
    'bd_sp_hard',
    18,
    65,
    (g) => _wait(g, 'sp', 2),
    (g) => _spOk(g) && _since(g, 'bd_sp_new', 'sp', 2),
    (g, next) {
      final l = g.l;
      final sp = _sp(g)!;
      final n = sp.name;
      _stamp(g, 'sp');
      final why = _retainer(g)
          ? '負け戦の咎で、禄を削られた。'
          : _merchant(g)
          ? '品がまるで売れず、店の借りがかさんだ。'
          : l.rank >= 8
          ? '国が荒れ、蔵の米も底が見えてきた。'
          : '日照りで田が割れ、蔵の米は春までもちそうにない。';
      final how = sp.bond >= 50
          ? '$nが、黙って嫁入りの着物を質に入れる支度をしていた。'
          : '$nは何も言わない。ただ、夜ごとにため息が聞こえる。';
      g.ask('苦しい年', '$why$how', [
        Choice.h('連れ合いに打ち明け、二人で凌ぐ', '苦しさは半分になる。弱みも見せることになる', () {
          _bond(sp, 15);
          l.gold += 3;
          g.j(3);
          g.setFlag('bd_sp_together');
          g.mark('苦しい年を、連れ合いの$nと二人で凌いだ');
          return '二人で夜なべをし、粥をすすって冬を越した。春の日差しが、やけにまぶしかった。';
        }),
        Choice.h('一人で抱え込んで働く', '連れ合いに心配はかけない。体にこたえ、心は離れるかもしれない', () {
          l.hp -= 10;
          l.gold += 4;
          _bond(sp, -6);
          g.setFlag('bd_sp_alone');
          return '朝から晩まで働いて、どうにか凌いだ。$nとは、ろくに口もきかなかった。';
        }),
        Choice.h('連れ合いの実家に頭を下げる', '蔵は持ち直す。連れ合いは肩身が狭くなる', () {
          l.gold += 8;
          _bond(sp, sp.bond >= 50 ? 3 : -5);
          g.j(-3);
          g.setFlag('bd_sp_inlaws');
          return '$nの実家から米が届いた。$nは、届けに来た兄に何度も頭を下げていた。';
        }),
      ], after: next);
    },
  ),

  // 連れ合い 三の段: 連れ合いの願い（旅・寺参り）。
  SceneDef(
    'bd_sp_wish',
    24,
    75,
    (g) => _wait(g, 'sp', 3),
    (g) => _spOk(g) && _since(g, 'bd_sp_hard', 'sp', 3),
    (g, next) {
      final l = g.l;
      final sp = _sp(g)!;
      final n = sp.name;
      _stamp(g, 'sp');
      final wish = g.rng.pick(const [
        'お伊勢さまへ参ってみたい',
        '熊野へ詣でてみたい',
        '生まれた里を、もう一度見てみたい',
      ]);
      final text = sp.bond >= 50
          ? '夕餉のあと、$nがぽつりと言った。「一度でいいから、$wish」'
          : '$nが「$wish」と、人にこぼしていたと聞いた。あなたには、一度も言わなかった。';
      final busy = _retainer(g) || l.rank >= 8;
      g.ask('連れ合いの願い', text, [
        Choice.h(busy ? '務めを休み、二人で旅に出る' : '仕事を置いて、二人で旅に出る', '一生の思い出になる。留守のあいだのことが気がかりだ', () {
          _pay(g, 6);
          if (_retainer(g)) l.fav = _c(l.fav - 4);
          _bond(sp, 15);
          g.j(12);
          g.setFlag('bd_sp_journey');
          g.mark('連れ合いの$nの願いをかなえ、二人で旅に出た');
          return '旅の宿で、$nは子どものようにはしゃいだ。帰り道、あなたの袖をずっと握っていた。';
        }),
        Choice.h('供を付けて、連れ合いだけを行かせる', '願いはかなう。隣に自分はいない', () {
          _pay(g, 4);
          _bond(sp, 5);
          g.setFlag('bd_sp_sent');
          return '戻った$nは、土産話を三晩かけて聞かせてくれた。';
        }),
        Choice.h('今は行けぬ、いつか必ずと約束する', '暮らしは崩れない。約束は残る', () {
          _bond(sp, -5);
          g.setFlag('bd_sp_promise');
          return '$nは「きっとですよ」と言って笑った。少しだけ、寂しそうだった。';
        }),
      ], after: next);
    },
  ),

  // 連れ合い 終の段: 晩年の縁側。
  SceneDef(
    'bd_sp_engawa',
    40,
    84,
    (g) => _wait(g, 'sp', 3),
    (g) => _spOk(g) && _since(g, 'bd_sp_wish', 'sp', 3),
    (g, next) {
      final l = g.l;
      final sp = _sp(g)!;
      final n = sp.name;
      final b = sp.bond;
      _stamp(g, 'sp');
      final text = b >= 60
          ? '晩秋の縁側で、$nと並んで日に当たっていた。$nが剥いた柿を、半分よこした。'
          : b >= 40
          ? '縁側に、$nと並んで座った。話すことは、もうあまりない。それでも、立ち去る気にはならなかった。'
          : '縁側に、$nが一人で座っていた。その背中が、思っていたよりずっと小さかった。';
      g.ask('晩年の縁側', text, [
        if (g.hasFlag('bd_sp_promise'))
          Choice.h('あの日の約束を果たしに、二人で旅に出る', '遅すぎた約束も、約束だ。老いた足には遠い道だ', () {
            l.hp -= 6;
            _pay(g, 4);
            _bond(sp, 20);
            g.j(15);
            g.setFlag('bd_sp_promise_kept');
            g.mark('長く待たせた約束を果たし、老いた連れ合いの$nと旅に出た');
            return '杖をつきながらの旅だった。$nは「待った甲斐がありました」と言った。';
          }),
        Choice.h('「苦労をかけた」と礼を言う', '言わずにきた言葉が届く。照れくさい', () {
          _bond(sp, 12);
          g.j(10);
          g.setFlag('bd_sp_thanked');
          g.mark('老いた連れ合いの$nに、苦労をかけたと礼を言った');
          return b >= 40
              ? '$nは「いまさら」と笑い、それから少し目を拭った。'
              : '$nは驚いた顔をして、それから長いこと泣いた。';
        }),
        Choice.h('黙って、同じ茶をすする', '言葉はいらない。伝わっているかは分からない', () {
          g.j(b >= 50 ? 8 : 2);
          g.setFlag('bd_sp_quiet');
          return b >= 50
              ? '茶が冷めるまで、二人で庭の柿の木を眺めていた。'
              : '茶をすする音だけが、縁側に響いていた。';
        }),
      ], after: next);
    },
  ),
];
