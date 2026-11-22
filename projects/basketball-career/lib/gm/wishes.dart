import 'career.dart';
import 'league.dart';
import 'personality.dart';
import 'player.dart';

/// 選手の望み(2026-11-21 の作り込み C-2)。年齢と立場で移る。望みが満たされるかで、FA の行き先・気持ち・再契約の額が変わる。
enum Wish {
  minutes('出番', '試合に出たい。育ててくれるチームへ行きたい'),
  money('大きな契約', '年俸を大事にする'),
  star('主役', 'チームの中心になりたい'),
  ring('優勝', '安くても勝てるチームへ行きたい'),
  home('古巣で終わりたい', '長くいたチーム(初めのチーム)で終わりたい'),
  milestone('記録の大台', '通算の大台が近い。出番の多いチームを選ぶ');

  const Wish(this.label, this.text);
  final String label, text;
}

/// [p] のいまの望み(年齢・力・価値観・通算の点から。乱数は使わない)。
Wish wishOf(Player p) {
  final total = p.careerTotals.pts;
  final next = (total ~/ 5000 + 1) * 5000;
  if (total >= 8000 && next - total <= 1200 && p.age >= 28) return Wish.milestone;
  if (p.age <= 23) return Wish.minutes;
  if (p.age <= 29) {
    final v = personalityOf(p).value;
    if (p.ovr >= 78) return v == Value.money ? Wish.money : Wish.star;
    return v == Value.win ? Wish.ring : Wish.money;
  }
  if (p.age <= 33) return personalityOf(p).value == Value.money ? Wish.money : Wish.ring;
  return Wish.home;
}

/// [p] の望みが、チーム [t] で満たされているか。
bool wishMet(Career c, Player p, Team t) {
  final gp = p.stats.gp, mpg = gp == 0 ? 0.0 : p.stats.min / gp;
  switch (wishOf(p)) {
    case Wish.minutes:
    case Wish.milestone:
      return gp == 0 || mpg >= 24;
    case Wish.money:
      return p.salary >= fairSalary(p.ovr, p.age) * 1.05;
    case Wish.star:
      final top = [...t.roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
      return top.take(2).contains(p);
    case Wish.ring:
      return c.strengthRank(t.index) < 8;
    case Wish.home:
      return p.tenure >= 3;
  }
}

/// FA で、望みに合うチームへの関心の上乗せ(0〜15)。
double wishInterest(Career c, Player p, int team) {
  final t = c.teams[team];
  switch (wishOf(p)) {
    case Wish.ring:
      return c.strengthRank(team) < 6 ? 15 : c.strengthRank(team) < 10 ? 8 : 0;
    case Wish.minutes:
    case Wish.milestone:
      final better = t.roster.where((x) => x.ovr > p.ovr && x.pos == p.pos).length;
      return better == 0 ? 12 : better == 1 ? 5 : 0;
    case Wish.star:
      return t.roster.where((x) => x.ovr > p.ovr).length < 2 ? 12 : 0;
    case Wish.home:
      return c.lastTeamOf(p) == team || p.career.isNotEmpty && p.career.first[1] == team ? 15 : 0;
    case Wish.money:
      return 0;
  }
}
