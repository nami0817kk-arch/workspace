import 'dart:math' as math;

import 'career.dart';
import 'draft.dart';

/// ドラフトを「見せる」ための計算(くじの結果・指名の答え合わせ・ドラフトのまとめ)。
/// どれも乱数を使わない(リーグの続きを変えない)。

/// くじの1行(1巡目の上位、くじに入ったチームの数だけ)。
class LotteryRow {
  LotteryRow({required this.slot, required this.from, required this.owner, required this.preRank, required this.odds});

  /// 何番目の指名か(1始まり)。
  final int slot;

  /// 指名権のもとのチームと、いま持っているチーム。
  final int from, owner;

  /// くじの前の順(成績の悪い順、1始まり)。
  final int preRank;

  /// くじの前に見込まれた、全体1位を引く見込み(0〜1)。
  final double odds;

  /// くじで上がった数(下がったら負)。
  int get jump => preRank - slot;
}

/// 今年のくじの結果。くじの前の並び([Career.lotteryPre])が無ければ空。
List<LotteryRow> lotteryRows(Career c) {
  final pre = c.lotteryPre;
  if (pre.isEmpty) return const [];
  final ws = [for (var i = 0; i < pre.length; i++) lotteryWeights[math.min(i, lotteryWeights.length - 1)]];
  final total = ws.fold(0, (a, b) => a + b);
  final rows = <LotteryRow>[];
  for (final i in c.order) {
    final pk = c.picks[i];
    if (pk.round != 1) continue;
    final r = pre.indexOf(pk.from);
    if (r < 0) continue;
    rows.add(LotteryRow(slot: rows.length + 1, from: pk.from, owner: pk.owner, preRank: r + 1, odds: ws[r] / total));
    if (rows.length >= pre.length) break;
  }
  return rows;
}

/// 本当の力での値打ち(模擬ドラフトの点と同じ重み)。
int trueScoreOf(Prospect p) => (p.player.ovr * 0.45 + p.player.pot * 0.55).round();

/// 今年の候補の中での、本当の力の順位(1始まり)。
int trueRankOf(List<Prospect> pool, Prospect p) {
  final s = trueScoreOf(p);
  return 1 + pool.where((x) => trueScoreOf(x) > s || (trueScoreOf(x) == s && x.player.id < p.player.id)).length;
}

/// 指名の評価(指名した順番に比べて、本当の力の順位がどれだけ上か)。
({String grade, String label}) pickGrade(List<Prospect> pool, Prospect p) {
  final no = p.pickNo ?? 0;
  final d = no - trueRankOf(pool, p);
  if (d >= 10) return (grade: 'A+', label: '大当たり');
  if (d >= 4) return (grade: 'A', label: '掘り出し物');
  if (d >= -3) return (grade: 'B', label: '順当');
  if (d >= -10) return (grade: 'C', label: 'やや早い');
  return (grade: 'D', label: '早すぎた');
}

/// 指名して分かった本当の力を、見えていた幅と比べる。
String revealOf(Prospect p) {
  final d = trueScoreOf(p) - p.mid;
  if (d >= 4) return '見立てより上だった';
  if (d <= -4) return '見立てより下だった';
  return 'ほぼ見立てどおり';
}

/// [from] 番目(draftLog の位置)より後の指名。
List<Prospect> picksSince(Career c, int from) => [for (final i in c.draftLog.skip(from)) c.prospects[i]];

/// ドラフトのまとめ。
class DraftSummary {
  DraftSummary({required this.mine, required this.top, required this.steal, required this.bust, required this.undrafted});

  /// 自分の指名(指名順)。
  final List<Prospect> mine;

  /// 全体の上位5人。
  final List<Prospect> top;

  /// いちばんの掘り出し物と、いちばん早すぎた指名(ほかのチームも含む)。
  final Prospect? steal, bust;

  /// 指名されずに自由契約へ回った人数。
  final int undrafted;
}

DraftSummary draftSummary(Career c) {
  final picked = [for (final i in c.draftLog) c.prospects[i]];
  int diff(Prospect p) => (p.pickNo ?? 0) - trueRankOf(c.prospects, p);
  Prospect? best(bool Function(Prospect) ok, int Function(Prospect) score) {
    Prospect? b;
    for (final p in picked.where(ok)) {
      if (b == null || score(p) > score(b)) b = p;
    }
    return b;
  }

  return DraftSummary(
    mine: [for (final p in picked) if (p.pickedBy == c.mine) p],
    top: picked.take(5).toList(),
    steal: best((p) => (p.pickNo ?? 0) > 5 && diff(p) >= 4, diff),
    bust: best((p) => (p.pickNo ?? 99) <= 20 && diff(p) <= -8, (p) => -diff(p)),
    undrafted: math.min(4, c.prospects.where((p) => p.pickedBy == null).length),
  );
}
