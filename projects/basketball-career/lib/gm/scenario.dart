import 'career.dart';
import 'player.dart';

/// シナリオ(お題つきの始め方)。チームは同じリーグの中から、お題に合わせて選ぶ。保存は番号なので後ろに足す。
enum Scenario {
  rebuild('どん底からの再建', 'リーグでいちばん弱いチームを、3年以内にプレーオフ(地区6位以内)へ', 3),
  dynasty('優勝候補の重圧', 'いちばん強いチームで、2年以内に優勝する', 2),
  taxHell('年俸の山', '年俸がいちばん高いチームを、2年以内にぜいたく税の線より下にして、勝ち越す', 2);

  const Scenario(this.label, this.goal, this.years);
  final String label, goal;

  /// 期限(何年目のシーズンまで)。
  final int years;
}

/// [c] のリーグで、シナリオに合うチーム。
int scenarioTeam(Career c, Scenario s) {
  final ids = [for (var i = 0; i < c.teams.length; i++) i];
  switch (s) {
    case Scenario.rebuild:
      ids.sort((a, b) => c.strengthRank(b).compareTo(c.strengthRank(a)));
    case Scenario.dynasty:
      ids.sort((a, b) => c.strengthRank(a).compareTo(c.strengthRank(b)));
    case Scenario.taxHell:
      ids.sort((a, b) => c.teams[b].payroll.compareTo(c.teams[a].payroll));
  }
  return ids.first;
}

/// シーズンの終わりに、お題を果たしたか(地区の順位 [rank]、結果 [result] は 5 が優勝)。
bool scenarioDone(Career c, Scenario s, {required int rank, required int result}) => switch (s) {
      Scenario.rebuild => rank <= 6,
      Scenario.dynasty => result >= 5,
      Scenario.taxHell => c.me.payroll < taxLine && c.me.wins > c.me.losses,
    };
