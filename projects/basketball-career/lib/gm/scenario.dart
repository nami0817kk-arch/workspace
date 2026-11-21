import 'career.dart';
import 'personality.dart';
import 'player.dart';

/// シナリオ(お題つきの始め方)。チームは同じリーグの中から、お題に合わせて選ぶ。保存は番号なので後ろに足す。
enum Scenario {
  rebuild('どん底からの再建', 'リーグでいちばん弱いチームを、3年以内にプレーオフ(地区6位以内)へ', 3),
  dynasty('優勝候補の重圧', 'いちばん強いチームで、2年以内に優勝する', 2),
  taxHell('年俸の山', '年俸がいちばん高いチームを、2年以内にぜいたく税の線より下にして、勝ち越す', 2),
  // ここから下は、遊ぶうちに出てくるお題(2026-11-21 の作り込み D-2。強さに効く特典は無い)
  legacyMess('伝説の後始末', '主力が年老いて年俸だけ高い強豪を、3年以内にプレーオフ(地区6位以内)へ', 3),
  noPicks('指名権ゼロ', '先の指名権をすべて出しきったチームを、3年以内に勝ち越しへ', 3),
  outdated('流行に取り残されたチーム', '流行と逆の型ばかりのチームを、3年以内にプレーオフ(地区6位以内)へ', 3),
  troubled('問題児だらけ', '不満を抱えた選手の多いチームを、2年以内に相性60以上で勝ち越す', 2),
  expansion('拡張チーム', '主力を引き抜かれた新しいチームを、4年以内にプレーオフ(地区6位以内)へ', 4);

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
    case Scenario.legacyMess:
      // 上の方のチームで、主力(上から8人)がいちばん年寄りのチーム
      double age(int t) {
        final top = [...c.teams[t].roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
        return top.take(8).fold(0, (s, p) => s + p.age) / 8;
      }
      ids.removeWhere((t) => c.strengthRank(t) >= 12);
      ids.sort((a, b) => age(b).compareTo(age(a)));
    case Scenario.noPicks:
      // 真ん中の強さのチーム
      ids.sort((a, b) => (c.strengthRank(a) - 15).abs().compareTo((c.strengthRank(b) - 15).abs()));
    case Scenario.outdated:
      // 流行に合わない型がいちばん多いチーム
      double fit(int t) => [...c.teams[t].roster.map(c.fashion)].fold(0.0, (s, x) => s + x);
      ids.sort((a, b) => fit(a).compareTo(fit(b)));
    case Scenario.troubled:
      int trouble(int t) => c.teams[t].roster.where((p) => hasTrait(p, Trait.troublemaker) || p.morale < 45).length;
      ids.sort((a, b) => trouble(b).compareTo(trouble(a)));
    case Scenario.expansion:
      ids.sort((a, b) => c.strengthRank(b).compareTo(c.strengthRank(a)));
  }
  return ids.first;
}

/// シーズンの終わりに、お題を果たしたか(地区の順位 [rank]、結果 [result] は 5 が優勝)。
bool scenarioDone(Career c, Scenario s, {required int rank, required int result}) => switch (s) {
      Scenario.rebuild => rank <= 6,
      Scenario.dynasty => result >= 5,
      Scenario.taxHell => c.me.payroll < taxLine && c.me.wins > c.me.losses,
      Scenario.legacyMess || Scenario.outdated || Scenario.expansion => rank <= 6,
      Scenario.noPicks => c.me.wins > c.me.losses,
      Scenario.troubled => c.me.chem >= 60 && c.me.wins > c.me.losses,
    };

/// お題が出てくる条件(初めからあるお題は null)。[profile] はこれまでの記録。条件の文は、出る前から見せる(D-2)。
String? scenarioLock(Scenario s) => switch (s) {
      Scenario.rebuild || Scenario.dynasty || Scenario.taxHell => null,
      Scenario.legacyMess => '一度優勝すると出てくる',
      Scenario.noPicks => 'トレードで通算10回勝つと出てくる',
      Scenario.outdated => '1つの任期を5年続けると出てくる',
      Scenario.troubled => '図鑑で隠れた特性「問題児」を見つけると出てくる',
      Scenario.expansion => 'レギュラーシーズンで55勝すると出てくる',
    };
