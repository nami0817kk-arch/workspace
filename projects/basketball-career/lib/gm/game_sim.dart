import 'dart:math' as math;

import 'league.dart';
import 'player.dart';
import 'policy.dart';
import 'rng.dart';

/// 1試合を、1回の攻めずつ実際に進める(2026-11-14、ユーザー「各機能の質を2kに寄せよう」「要素だけのハリボテ」)。
///
/// - コートの5人は、選手ごとの出場時間から1分ごとに入れ替える(先発は始めと終わりに出る)
/// - 攻めごとに、ミス(スティール)→シュートを打つ人と種類(2点・3点)→ファウル→入るか→ブロック→リバウンド→アシストを決める
/// - 入る見込みは、チームの強さの差(けが人・出場時間・方針・相性・コーチを含む。ホーム+1)と、
///   打つ人の能力(コートの5人の中で外・中のシュートがうまいか)と、守る5人の守りから決める
/// - コートにいる5人の力がチームの平均より低いと(控えが多いと)、その時間は弱くなる
/// - 方針も試合の形に出る: 展開の速さ(攻めの長さ)・攻めの重点(3点の割合)・ボールの回し方(アシストと打つ人の偏り)・守り方
/// - 同点なら5分の延長
/// - 個人の数字(点・シュート・リバウンド・アシスト・スティール・ブロック・ミス・分・±)は、ここで起きたことをそのまま数える
class SimTeam {
  SimTeam(this.team, this.str) : order = team.order, mins = team.playMinutes() {
    final n = order.length;
    stat = List.generate(n, (_) => List.filled(_nStat, 0));
    secs = List.filled(n, 0);
    pm = List.filled(n, 0);
    var w = 0.0, s = 0.0;
    for (var i = 0; i < n; i++) {
      w += mins[i];
      s += mins[i] * order[i].ovr;
    }
    avgOvr = w == 0 ? 60 : s / w;
    out = [for (final p in order) p.attr(Attr.outside)];
    ins = [for (final p in order) p.attr(Attr.inside)];
    pas = [for (final p in order) p.attr(Attr.passing)];
    reb = [for (final p in order) p.attr(Attr.rebound)];
    def = [for (final p in order) p.attr(Attr.defense)];
    pace = policy(PolicyAxis.pace);
    focus = policy(PolicyAxis.focus);
    share = policy(PolicyAxis.passing);
    press = policy(PolicyAxis.defense);
    // 細かい能力(画面の35項目のもとの数字)。試合のそれぞれの場面で、対応する項目を使う
    int sub(Player p, String label) => subRatingRaw(p, subRatingByLabel[label]!);
    s3 = [for (final p in order) sub(p, '3ポイント')];
    sRim = [for (final p in order) (sub(p, 'レイアップ') + sub(p, 'ゴール下') + sub(p, 'ダンク')) ~/ 3];
    sFt = [for (final p in order) sub(p, 'フリースロー')];
    sFoul = [for (final p in order) sub(p, 'ファウルのもらいやすさ')];
    sSafe = [for (final p in order) sub(p, 'ターンオーバーの少なさ')];
    sStl = [for (final p in order) sub(p, 'スティール')];
    sPerD = [for (final p in order) sub(p, '外の守り')];
    sIntD = [for (final p in order) sub(p, '中の守り')];
    sStam = [for (final p in order) sub(p, 'スタミナ')];
    tier = [
      for (final p in order) [for (final a in Attr.values) badgeTierOf(p, a)],
    ];
    final usageExp = const [2.1, 1.7, 1.35][share];
    wUse = [for (var i = 0; i < n; i++) _pow((out[i] + ins[i]) / 2 - 40, usageExp)];
    // ボールを持つ人ほどミスに関わり、ミスの少なさが高いほど減る
    wTov = [for (var i = 0; i < n; i++) (0.6 + sub(order[i], 'ボール運び') / 100 * (order[i].pos == Pos.pg ? 1.4 : 1.0)) * (1.5 - sSafe[i] / 100)];
    wStl = [for (var i = 0; i < n; i++) _pow(sStl[i] - 35, 1.3)];
    wBlk = [for (var i = 0; i < n; i++) _pow(sub(order[i], 'ブロック') - 35, 1.4) * _blkPos[order[i].pos]!];
    wOreb = [for (var i = 0; i < n; i++) _pow(sub(order[i], '攻めのリバウンド') - 35, 1.3) * _rebPos[order[i].pos]! * (1 + 0.15 * (tier[i][Attr.rebound.index] + 1))];
    wReb = [
      for (var i = 0; i < n; i++)
        _pow((sub(order[i], '守りのリバウンド') + sub(order[i], 'ボックスアウト')) / 2 - 35, 1.3) * _rebPos[order[i].pos]! * (1 + 0.15 * (tier[i][Attr.rebound.index] + 1)),
    ];
    wAst = [
      for (var i = 0; i < n; i++)
        _pow((sub(order[i], 'パスの正確さ') + sub(order[i], '視野')) / 2 - 35, 1.3) * _astPos[order[i].pos]! * (1 + 0.1 * (tier[i][Attr.passing.index] + 1)),
    ];
  }

  /// 細かい能力: 3ポイント・ゴール下(レイアップ・ゴール下・ダンク)・フリースロー・ファウルのもらいやすさ・ミスの少なさ・スティール・外の守り・中の守り・スタミナ。
  late final List<int> s3, sRim, sFt, sFoul, sSafe, sStl, sPerD, sIntD, sStam;

  /// バッジの段階([Attr] の順。-1 は無し、0 銅〜3 殿堂)。
  late final List<List<int>> tier;
  late final List<double> wOreb;

  final Team team;
  final double str;
  final List<Player> order;
  final List<int> mins;
  late final List<List<int>> stat;
  late final List<int> secs;
  late final List<int> pm;
  late final double avgOvr;
  late final List<int> out, ins, pas, reb, def;
  late final List<double> wUse, wTov, wStl, wBlk, wReb, wAst;
  late final int pace, focus, share, press;
  int pts = 0;
  final periods = <int>[];

  /// コートの5人(order の番号)。
  List<int> court = const [];

  /// コートの5人の平均(外・中・パス・リバウンド・守り・力)。
  double cOut = 0, cIns = 0, cPas = 0, cReb = 0, cDef = 0, cOvr = 0;

  /// コートの5人の平均(3ポイント・ゴール下・ミスの少なさ・スティール・外の守り・中の守り)と、鉄壁と司令塔のバッジの段階の合計。
  double c3 = 0, cRim = 0, cSafe = 0, cStl = 0, cPerD = 0, cIntD = 0;
  int cWall = 0, cGeneral = 0;

  void setCourt(List<int> c) {
    if (identical(c, court)) return;
    court = c;
    if (c.isEmpty) return;
    var o = 0, i2 = 0, pa = 0, rb = 0, df = 0, ov = 0;
    for (final i in c) {
      o += out[i];
      i2 += ins[i];
      pa += pas[i];
      rb += reb[i];
      df += def[i];
      ov += order[i].ovr;
    }
    final n = c.length;
    var a3 = 0, rim = 0, safe = 0, stl = 0, perD = 0, intD = 0;
    cWall = 0;
    cGeneral = 0;
    for (final i in c) {
      a3 += s3[i];
      rim += sRim[i];
      safe += sSafe[i];
      stl += sStl[i];
      perD += sPerD[i];
      intD += sIntD[i];
      cWall += tier[i][Attr.defense.index] + 1;
      cGeneral += tier[i][Attr.passing.index] + 1;
    }
    c3 = a3 / n;
    cRim = rim / n;
    cSafe = safe / n;
    cStl = stl / n;
    cPerD = perD / n;
    cIntD = intD / n;
    cOut = o / n;
    cIns = i2 / n;
    cPas = pa / n;
    cReb = rb / n;
    cDef = df / n;
    cOvr = ov / n;
  }

  int policy(PolicyAxis a) => team.policy.length > a.index ? team.policy[a.index] : 1;
}

const _nStat = 13;
const _pts = 0, _fgm = 1, _fga = 2, _tpm = 3, _tpa = 4, _ftm = 5, _fta = 6, _reb = 7, _ast = 8, _stl = 9, _blk = 10, _tov = 11, _oreb = 12;

/// リバウンドとアシストの、ポジションごとの取りやすさ。
const _rebPos = {Pos.pg: 0.5, Pos.sg: 0.6, Pos.sf: 0.9, Pos.pf: 1.2, Pos.c: 1.35};
const _astPos = {Pos.pg: 2.2, Pos.sg: 1.1, Pos.sf: 0.8, Pos.pf: 0.55, Pos.c: 0.45};
const _blkPos = {Pos.pg: 0.25, Pos.sg: 0.35, Pos.sf: 0.7, Pos.pf: 1.3, Pos.c: 1.8};

/// 強さの差1あたり、シュートが入る見込みがどれだけ動くか(勝つ見込みの式 [winChance] とほぼ合うように測った値)。
const edgePerStrength = 0.0028;

/// 試合の中身(見せる用)。
class SimResult {
  SimResult(this.home, this.away);
  final SimTeam home, away;

  /// 1分ごとの点差(ホーム − アウェー)。延長も続ける。
  final flow = <int>[];

  /// 見せ場(自分の試合だけ使う)。「4Q 0:42 名前の3ポイント 101-99」の形。
  final plays = <String>[];

  /// リードが入れ替わった回数。
  int leadChanges = 0;

  /// それぞれの最大リード。
  int homeMaxLead = 0, awayMaxLead = 0;

  int get overtimes => home.periods.length - 4;
}

double _pow(num x, double e) => math.pow(math.max(1, x), e).toDouble();

/// コートの [c] から、重み [w](order の番号ごと)で1人選ぶ。[skip] の人は除く。
int _pick(Rng r, List<int> c, List<double> w, [int skip = -1]) {
  var sum = 0.0;
  for (final i in c) {
    if (i != skip) sum += w[i];
  }
  final x0 = r.nextInt(1000000) / 1000000;
  if (sum <= 0) {
    for (final i in c) {
      if (i != skip) return i;
    }
    return c.first;
  }
  var x = x0 * sum;
  var last = c.first;
  for (final i in c) {
    if (i == skip) continue;
    last = i;
    if (x < w[i]) return i;
    x -= w[i];
  }
  return last;
}

String _clock(int period, int left) {
  final q = period < 4
      ? '${period + 1}Q'
      : period == 4
      ? '延長'
      : '延長${period - 3}';
  final m = left ~/ 60, s = left % 60;
  return '$q $m:${s.toString().padLeft(2, '0')}';
}

/// [home] と [away] の1試合を進める。チームの勝敗・個人成績・けがはここでは触らない(呼ぶ側で行う)。
SimResult simulateGame(Team home, Team away, Rng r, {required double homeStr, required double awayStr, bool record = false}) {
  final h = SimTeam(home, homeStr + 1.0), a = SimTeam(away, awayStr);
  final res = SimResult(h, a);
  // 1分ごとのコートの5人を、残りの出場時間の割合が大きい順に決める(先発が始めに出て、控えと入れ替わり、最後は残りの多い人)
  List<List<int>> plan(SimTeam t) {
    final n = t.order.length;
    final left = [for (final m in t.mins) m.toDouble()];
    final out = <List<int>>[];
    for (var m = 0; m < 48; m++) {
      final idx = [
        for (var i = 0; i < n; i++)
          if (t.mins[i] > 0) i,
      ];
      final rem = 48 - m;
      idx.sort((x, y) {
        final c = (left[y] / rem).compareTo(left[x] / rem);
        return c != 0 ? c : x.compareTo(y);
      });
      final five = idx.take(5).toList()..sort();
      for (final i in five) {
        left[i] -= 1;
      }
      // 前の分と同じ5人なら同じリストを使う(数え直しを省く)
      final prev = out.isEmpty ? null : out.last;
      out.add(prev != null && prev.length == five.length && List.generate(five.length, (k) => prev[k] == five[k]).every((x) => x) ? prev : five);
    }
    return out;
  }

  final hp = plan(h), ap = plan(a);
  // 延長は出場時間の長い5人
  List<int> closers(SimTeam t) {
    final idx = [for (var i = 0; i < t.order.length; i++) i]..sort((x, y) => t.mins[y].compareTo(t.mins[x]));
    return (idx.take(5).toList()..sort());
  }

  final hClose = closers(h), aClose = closers(a);

  final teams = [h, a];
  var offense = r.nextInt(2); // ジャンプボール
  final firstBall = offense;
  var hScore = 0, aScore = 0;
  var lead = 0; // 直前のリードの向き(+1 ホーム、-1 アウェー、0 同点)

  void addPlay(int period, int left, String text) {
    if (!record) return;
    res.plays.add('${_clock(period, left)}  $text  ${h.pts}-${a.pts}');
  }

  for (var period = 0; ; period++) {
    if (period >= 4 && hScore != aScore) break;
    final len = period < 4 ? 720 : 300;
    // 各クォーターの最初の攻めは、交互に(2Qと3Qはジャンプボールで取らなかった側)
    if (period > 0 && period < 4) offense = (period == 1 || period == 2) ? 1 - firstBall : firstBall;
    var clock = len;
    final h0 = hScore, a0 = aScore;
    var nextMinute = len - 60;
    void setCourt() {
      if (period >= 4) {
        h.setCourt(hClose);
        a.setCourt(aClose);
      } else {
        final minute = (period * 12 + (len - clock) ~/ 60).clamp(0, 47);
        h.setCourt(hp[minute]);
        a.setCourt(ap[minute]);
      }
    }

    setCourt();
    while (clock > 0) {
      final o = teams[offense], d = teams[1 - offense];
      var used = (const [13, 10, 7][o.pace]) + r.nextInt(9);
      if (used > clock) used = clock;
      clock -= used;
      // 出ている時間を数える
      for (final t in teams) {
        for (final i in t.court) {
          t.secs[i] += used;
        }
      }
      final before = o.pts;
      _possession(o, d, r, record ? (text) => addPlay(period, clock, text) : null);
      final got = o.pts - before;
      if (got > 0) {
        for (final i in o.court) {
          o.pm[i] += got;
        }
        for (final i in d.court) {
          d.pm[i] -= got;
        }
        if (offense == 0) {
          hScore += got;
        } else {
          aScore += got;
        }
        final nowLead = hScore > aScore
            ? 1
            : hScore < aScore
            ? -1
            : 0;
        if (nowLead != 0 && lead != 0 && nowLead != lead) {
          res.leadChanges++;
          if (record && (period >= 3)) addPlay(period, clock, '逆転');
        }
        if (nowLead != 0) lead = nowLead;
        res.homeMaxLead = math.max(res.homeMaxLead, hScore - aScore);
        res.awayMaxLead = math.max(res.awayMaxLead, aScore - hScore);
      }
      offense = 1 - offense;
      // 1分ごとに5人を入れ替え、点差を残す
      while (clock <= nextMinute && nextMinute >= 0) {
        res.flow.add(hScore - aScore);
        nextMinute -= 60;
      }
      setCourt();
    }
    h.periods.add(hScore - h0);
    a.periods.add(aScore - a0);
    if (period >= 12) break; // 念のため(延長が終わらないことは無いが)
  }
  // 同点のまま上限に来たら(起きないはず)、最後の攻めのチームに1点
  if (hScore == aScore) {
    h.pts++;
    h.periods[h.periods.length - 1]++;
  }
  if (record) _trimPlays(res);
  return res;
}

/// 見せ場を、終盤と逆転を中心に12個までにする。
void _trimPlays(SimResult res) {
  if (res.plays.length <= 12) return;
  final keep = res.plays.sublist(res.plays.length - 12);
  res.plays
    ..clear()
    ..addAll(keep);
}

/// 1回の攻め。点は o.pts に足す。オフェンスリバウンドを取れば続ける。[play] は見せ場を残すとき(自分の試合)だけ。
void _possession(SimTeam o, SimTeam d, Rng r, void Function(String)? play) {
  final oc = o.court, dc = d.court;
  if (oc.isEmpty || dc.isEmpty) return;
  // チームの強さの差と、いまコートにいる5人がチームの平均よりどれだけ強いか
  final diff = (o.str - d.str) + 0.35 * ((o.cOvr - o.avgOvr) - (d.cOvr - d.avgOvr));
  final edge = diff * edgePerStrength;
  final press = d.press; // 0 中を固める / 2 前から当たる
  final focus = o.focus; // 0 外 / 2 中
  final share = o.share; // 0 エース任せ / 2 パス回し

  for (var tries = 0; tries < 4; tries++) {
    // ミス
    // ミスの見込み: 相手のスティールの力とこちらのミスの少なさ。司令塔のバッジがコートにいると減る
    final toP = (0.125 - edge * 0.6 + (d.cStl - o.cSafe) / 900 + (press == 2 ? 0.015 : 0) - o.cGeneral * 0.002).clamp(0.06, 0.2);
    if (r.nextInt(10000) < (toP * 10000).round()) {
      final who = _pick(r, oc, o.wTov);
      o.stat[who][_tov]++;
      if (r.nextInt(100) < 55) {
        d.stat[_pick(r, dc, d.wStl)][_stl]++;
      }
      return;
    }
    // 打つ人(点を取る力の高い人ほど多く打つ。エース任せなら偏り、パス回しなら散る)
    final shooter = _pick(r, oc, o.wUse);
    final p = o.order[shooter];
    final out = o.s3[shooter], ins = o.sRim[shooter];
    final tiers = o.tier[shooter];
    // 3点の割合: 外のうまさとポジション、攻めの重点、相手が中を固めると増える
    final share3 = (0.14 + (out - 55) / 80 + (p.pos.guard ? 0.12 : (p.pos == Pos.c ? -0.2 : 0.02)) + const [0.08, 0, -0.08][focus] + (press == 0 ? 0.04 : 0))
        .clamp(0.0, 0.62);
    final three = r.nextInt(1000) < (share3 * 1000).round();
    // コートの5人の中での、打つ人のうまさ(3ポイントは「3ポイント」、2点は「レイアップ・ゴール下・ダンク」)
    final skill = three ? out - o.c3 : ins - o.cRim;
    final paint = press == 0 ? (three ? 0.01 : -0.02) : 0.0;
    // 守る5人の得意(外の守りと中の守りのどちらが高いか)と、鉄壁のバッジ
    final guard = (three ? d.cPerD - d.cDef : d.cIntD - d.cDef) / 400 + d.cWall * 0.003;
    // バッジ(シューターは3点、フィニッシャーは2点)
    final badge = 0.008 * ((three ? tiers[Attr.outside.index] : tiers[Attr.inside.index]) + 1);
    // 疲れ: その試合で30分を超えて出ると、スタミナが低いほど入りにくい
    final played = o.secs[shooter] / 60 - 30;
    final tired = played <= 0 ? 0.0 : played * 0.002 * (1.6 - o.sStam[shooter] / 100);
    var make = (three ? 0.35 + skill / 300 + edge * 0.85 + paint : 0.52 + skill / 300 + edge + paint) + badge - guard - tired;
    make = make.clamp(three ? 0.18 : 0.3, three ? 0.52 : 0.72);
    // ファウルをもらう(中で多い。前から当たる守りは増える)
    // ファウルのもらいやすさと、身体能力のバッジ
    final foulP = three ? 0.02 : (0.15 + (o.sFoul[shooter] - 70) / 500 + (press == 2 ? 0.02 : 0) + 0.008 * (tiers[Attr.athletic.index] + 1)).clamp(0.08, 0.26);
    final fouled = r.nextInt(1000) < (foulP * 1000).round();
    final pft = (0.74 + (o.sFt[shooter] - 70) / 200).clamp(0.45, 0.93);
    final st = o.stat[shooter];
    void freeThrows(int n) {
      for (var k = 0; k < n; k++) {
        st[_fta]++;
        if (r.nextInt(1000) < (pft * 1000).round()) {
          st[_ftm]++;
          st[_pts]++;
          o.pts++;
        }
      }
    }

    final made = r.nextInt(1000) < ((fouled ? make * 0.45 : make) * 1000).round();
    if (fouled && !made) {
      freeThrows(three ? 3 : 2);
      return;
    }
    st[_fga]++;
    if (three) st[_tpa]++;
    if (made) {
      final v = three ? 3 : 2;
      st[_fgm]++;
      if (three) st[_tpm]++;
      st[_pts] += v;
      o.pts += v;
      // アシスト
      final astP = (three ? 0.82 : 0.5) + const [-0.1, 0, 0.08][share];
      var by = -1;
      if (oc.length > 1 && r.nextInt(100) < (astP * 100).round()) {
        by = _pick(r, oc, o.wAst, shooter);
        o.stat[by][_ast]++;
      }
      if (fouled) freeThrows(1);
      if (play != null) {
        final kind = three ? '3ポイント' : (fouled ? 'バスケットカウント' : 'シュート');
        play('${p.name}の$kind${by < 0 ? '' : '(アシスト ${o.order[by].name})'}');
      }
      return;
    }
    // 外れた: ブロック
    if (!three && r.nextInt(100) < 17) {
      d.stat[_pick(r, dc, d.wBlk)][_blk]++;
    }
    // リバウンド
    final orebP = (0.24 + (o.cReb - d.cReb) / 250 + (press == 0 ? -0.02 : 0)).clamp(0.12, 0.36);
    if (r.nextInt(1000) < (orebP * 1000).round()) {
      final ri = _pick(r, oc, o.wOreb);
      o.stat[ri][_reb]++;
      o.stat[ri][_oreb]++;
      continue; // もう一度攻める
    }
    d.stat[_pick(r, dc, d.wReb)][_reb]++;
    return;
  }
}

/// 試合の数字を、ボックススコアの行にする(出場した選手だけ)。
List<BoxLine> boxLinesOf(SimTeam t) => [
  for (var i = 0; i < t.order.length; i++)
    if (t.secs[i] > 0) boxLineAt(t, i),
];

BoxLine boxLineAt(SimTeam t, int i) {
  final s = t.stat[i];
  return BoxLine(
    t.order[i].name,
    t.order[i].pos.short,
    minutesOf(t, i),
    s[_pts],
    s[_reb],
    s[_ast],
    fgm: s[_fgm],
    fga: s[_fga],
    tpm: s[_tpm],
    tpa: s[_tpa],
    ftm: s[_ftm],
    fta: s[_fta],
    stl: s[_stl],
    blk: s[_blk],
    tov: s[_tov],
    pm: t.pm[i],
  );
}

/// 出場時間(分)。合計がちょうど 240分(延長は+25分ずつ)になるよう、端数の大きい順に1分ずつ配る。出ていれば1分以上。
int minutesOf(SimTeam t, int i) => _minutes(t)[i];

final _minCache = Expando<List<int>>();

List<int> _minutes(SimTeam t) {
  final cached = _minCache[t];
  if (cached != null) return cached;
  final n = t.secs.length;
  final total = t.secs.fold(0, (a, b) => a + b) ~/ 60;
  final out = [for (final s in t.secs) s ~/ 60];
  for (var i = 0; i < n; i++) {
    if (t.secs[i] > 0 && out[i] == 0) out[i] = 1;
  }
  var left = total - out.fold(0, (a, b) => a + b);
  final byRem = [for (var i = 0; i < n; i++) i]..sort((a, b) => (t.secs[b] % 60).compareTo(t.secs[a] % 60));
  for (var k = 0; left > 0 && k < n * 2; k++) {
    final i = byRem[k % n];
    if (t.secs[i] <= 0) continue;
    out[i]++;
    left--;
  }
  // 1分に繰り上げた人の分が多すぎたら、いちばん長く出た人から引く
  while (left < 0) {
    var top = 0;
    for (var i = 1; i < n; i++) {
      if (out[i] > out[top]) top = i;
    }
    out[top]--;
    left++;
  }
  return _minCache[t] = out;
}

/// 個人成績に足す。
void addSeasonStats(SimTeam t) {
  for (var i = 0; i < t.order.length; i++) {
    if (t.secs[i] <= 0) continue;
    final s = t.stat[i];
    t.order[i].stats
      ..gp += 1
      ..pts += s[_pts]
      ..reb += s[_reb]
      ..ast += s[_ast]
      ..min += minutesOf(t, i)
      ..fgm += s[_fgm]
      ..fga += s[_fga]
      ..tpm += s[_tpm]
      ..tpa += s[_tpa]
      ..ftm += s[_ftm]
      ..fta += s[_fta]
      ..stl += s[_stl]
      ..blk += s[_blk]
      ..tov += s[_tov];
  }
}

/// いちばん点を取った選手(order の番号)。
int topScorerOf(SimTeam t) {
  var top = 0;
  for (var i = 1; i < t.order.length; i++) {
    if (t.stat[i][_pts] > t.stat[top][_pts]) top = i;
  }
  return top;
}

int ptsAt(SimTeam t, int i) => t.stat[i][_pts];
