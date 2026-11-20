import '../l10n/tr.dart';
import '../models/manager_profile.dart';

/// 新聞の一面の見出しと、監督の試合後の一言を作る。
///
/// 見出しは「その節でいちばん大きな話」を1つ選ぶ: 記録(ハットトリック・
/// 通算の節目) → ダービー → 大勝・大敗 → 首位 → ふつうの結果。
class FrontPageEngine {
  const FrontPageEngine._();

  static String headline({
    required String club,
    required String opponent,
    required int goalsFor,
    required int goalsAgainst,
    required bool derby,
    required int rank,
    required List<String> milestones,
  }) {
    final score = '$goalsFor-$goalsAgainst';
    final diff = goalsFor - goalsAgainst;
    if (milestones.isNotEmpty) {
      return Tr.pick('${milestones.first}! $clubは$opponentに$score',
          '${milestones.first}! $club $score $opponent');
    }
    if (derby) {
      if (diff > 0) {
        return Tr.pick('ダービーは$clubのもの! $opponentを$scoreで下す',
            'Derby day belongs to $club: $opponent beaten $score');
      }
      if (diff < 0) {
        return Tr.pick('$club、ダービーで屈辱の敗戦($score)',
            'Derby humiliation for $club ($score)');
      }
      return Tr.pick('ダービーは痛み分け($score)', 'Honours even in the derby ($score)');
    }
    if (diff >= 3) {
      return Tr.pick('$club、$opponentに$scoreの大勝', '$club rout $opponent $score');
    }
    if (diff <= -3) {
      return Tr.pick('$club、$opponentに$scoreの大敗', '$club crushed $score by $opponent');
    }
    if (rank == 1 && diff >= 0) {
      return Tr.pick('首位$club、$opponent戦も$scoreで譲らず',
          'Leaders $club hold firm against $opponent ($score)');
    }
    if (diff > 0) {
      return Tr.pick('$club、$opponentに$scoreで勝利', '$club beat $opponent $score');
    }
    if (diff < 0) {
      return Tr.pick('$club、$opponentに$scoreで敗れる', '$club lose $score to $opponent');
    }
    return Tr.pick('$clubと$opponent、$scoreで分ける', '$club and $opponent draw $score');
  }

  /// 監督の試合後の一言。考え方(攻撃的・堅守など)で言い回しが変わる。
  static String managerQuote({
    required int goalsFor,
    required int goalsAgainst,
    required ManagerStyle style,
  }) {
    final diff = goalsFor - goalsAgainst;
    if (diff > 0) {
      return switch (style) {
        ManagerStyle.attacking => Tr.pick('「前へ出続けた結果だ。次も攻める」',
            '"We kept going forward. We will attack again next time."'),
        ManagerStyle.defensive => Tr.pick('「まず守り切れた。それが全てだ」',
            '"We kept them out first. That is what matters."'),
        ManagerStyle.youth => Tr.pick('「若い選手たちが応えてくれた」',
            '"The young lads delivered for us."'),
        ManagerStyle.pragmatic => Tr.pick('「相手に合わせて戦えた。良い勝ち点3だ」',
            '"We played the game in front of us. Good three points."'),
      };
    }
    if (diff < 0) {
      return switch (style) {
        ManagerStyle.attacking => Tr.pick('「攻めて負けたなら悔いはない。でも決め切らないと」',
            '"No regrets losing on the attack, but we have to finish our chances."'),
        ManagerStyle.defensive => Tr.pick('「失点の場面は練習から見直す」',
            '"We will go back over those goals on the training ground."'),
        ManagerStyle.youth => Tr.pick('「若い選手には良い勉強になった」',
            '"A hard lesson, but a useful one for the youngsters."'),
        ManagerStyle.pragmatic => Tr.pick('「今日は相手が上だった。切り替える」',
            '"They were better today. We move on."'),
      };
    }
    return switch (style) {
      ManagerStyle.attacking => Tr.pick('「勝ち切れなかった。もっと点を取りにいく」',
          '"We should have won it. We need more goals."'),
      ManagerStyle.defensive => Tr.pick('「勝ち点1は悪くない」', '"A point is not a bad result."'),
      ManagerStyle.youth => Tr.pick('「経験を積めた試合だった」',
          '"Good experience for the group."'),
      ManagerStyle.pragmatic => Tr.pick('「妥当な結果だ」', '"A fair result."'),
    };
  }
}
