import 'package:flutter/material.dart';

import '../models/match_result.dart';
import '../theme/semantic_colors.dart';
import '../l10n/tr.dart';

/// [event]の分数・選手名などから、テンプレートを一意に選び安定した実況文を
/// 生成する(乱数を使わず内容から決定するため、再描画されても同じ文になる)。
String matchCommentaryText(MatchEvent event, String teamName) {
  final scorer = event.scorerName ?? Tr.pick('選手', 'Players');
  final assist = event.assistName;
  final seed = event.minute * 31 +
      scorer.length * 7 +
      teamName.length * 3 +
      (assist?.length ?? 0) * 11;

  List<String> templates;
  switch (event.type) {
    case MatchEventType.substitution:
      // 交代は決まった形で出す(scorer が入った選手、assist が下がった選手)。
      final out = assist ?? Tr.pick('選手', 'Player');
      return Tr.pick('交代: $out → $scorer', 'Substitution: $out → $scorer');
    case MatchEventType.goal:
      if (assist != null) {
        templates = [
          Tr.pick('$assistのスルーパスに抜け出した$scorerが流し込む！$teamNameゴール！',
              "$scorer runs onto $assist's through ball and slots it home. Goal for $teamName!"),
          Tr.pick('$assistの絶妙なクロスに$scorerが合わせた！$teamNameが加点！',
              '$assist whips it in and $scorer meets it. $teamName add another!'),
          Tr.pick('$assistからのパスを受けた$scorerが冷静に決めた！',
              "$scorer takes $assist's pass and finishes calmly."),
          Tr.pick('$scorer、$assistとの見事なコンビネーションでゴール！',
              "A lovely one-two between $scorer and $assist, and it's a goal!"),
          Tr.pick('$assistが作った決定機を$scorerが確実に仕留める！',
              '$assist makes the chance and $scorer takes it.'),
          Tr.pick('$teamNameお得意の形！$assistのお膳立てに$scorerが応えた！',
              'Classic $teamName. $assist lays it on and $scorer obliges!'),
          Tr.pick('一瞬の隙を突いた$assistのパス、$scorerが逃さず沈める！',
              '$assist spots the gap, and $scorer makes no mistake!'),
          Tr.pick('$scorerと$assistの息の合った崩しから$teamNameが突き放す！',
              '$scorer and $assist carve them open, and $teamName pull clear!'),
        ];
      } else {
        templates = [
          Tr.pick('$teamName!! $scorerが値千金の一撃！これはゴラッソだ！',
              '$teamName!! What a strike from $scorer. That is a golazo!'),
          Tr.pick('$scorerが冷静にゴールを射抜く！$teamNameに勢いが生まれる！',
              '$scorer picks his spot coolly. $teamName have their tails up!'),
          Tr.pick('$teamNameのチャンス、こぼれ球を$scorerが押し込んだ！',
              'It breaks for $teamName, and $scorer bundles it in!'),
          Tr.pick('$scorer、値千金の一撃！$teamNameが加点！',
              'A priceless goal from $scorer. $teamName extend it!'),
          Tr.pick('$scorer、個の力でねじ込んだ！$teamNameスタンドが沸く！',
              '$scorer forces it home on his own. The $teamName end erupts!'),
          Tr.pick('誰も予想しなかった一撃、$scorerが決めた！',
              'Nobody saw that coming. $scorer scores!'),
          Tr.pick('$teamName会心の攻撃！$scorerが仕留めた！',
              'A perfect $teamName move, finished by $scorer!'),
          Tr.pick('$scorer、執念のゴール！$teamNameに流れを引き寄せる一撃！',
              "$scorer refuses to give up on it. That could turn the game $teamName's way!"),
        ];
      }
      break;
    case MatchEventType.chance:
      templates = [
        Tr.pick('$scorerのシュートが枠をとらえるもGKが好セーブ！',
            '$scorer hits the target, but the keeper saves well!'),
        Tr.pick(
            '$scorer、惜しい！ポストに嫌われた！', 'So close from $scorer, off the post!'),
        Tr.pick('$teamName、$scorerのシュートは決めきれず。',
            '$scorer shoots for $teamName, but cannot finish it.'),
        Tr.pick('$scorerのシュートはわずかに枠の外へ…', "$scorer's effort drifts just wide…"),
        Tr.pick('$teamNameに決定機！$scorerが放つもGKの正面…',
            'A big chance for $teamName, but $scorer shoots straight at the keeper…'),
        Tr.pick('$scorer渾身の一撃、クロスバーに跳ね返される！',
            '$scorer lets fly, and the crossbar keeps it out!'),
        Tr.pick('惜しい！$scorerのシュートはブロックに阻まれた。',
            "So close. $scorer's shot is blocked."),
      ];
      break;
    case MatchEventType.yellowCard:
      templates = [
        Tr.pick('$scorerに主審からイエローカード。$teamNameは規律が問われる場面。',
            'A yellow for $scorer. $teamName need to keep their discipline.'),
        Tr.pick('$scorer、荒いプレーで警告を受ける。',
            '$scorer is booked for a rough challenge.'),
        Tr.pick('$teamNameの$scorerにカード提示。',
            '$scorer of $teamName goes into the book.'),
        Tr.pick('$scorer、抗議のあまり警告を受けてしまう。',
            '$scorer argues once too often and is booked.'),
        Tr.pick('際どいタックルの$scorerに主審が笛、イエローが提示される。',
            "The referee whistles for $scorer's late tackle and shows yellow."),
      ];
      break;
    case MatchEventType.redCard:
      templates = [
        Tr.pick('$scorerに一発退場が言い渡された！$teamNameは数的不利に…',
            'A straight red for $scorer! $teamName are down to ten…'),
        Tr.pick('$scorer、看過できないプレーで退場処分！',
            '$scorer goes for a challenge the referee cannot ignore!'),
        Tr.pick('$teamNameにとって痛恨の退場、$scorerがピッチを去る。',
            'A costly red card for $teamName as $scorer walks.'),
        Tr.pick('まさかの一発レッド！$scorerが涙のピッチ退場。',
            'A straight red out of nowhere. $scorer leaves the pitch in tears.'),
        Tr.pick('$scorer、この試合最大の誤算…退場でチームに大きな痛手。',
            'The moment that decides it: $scorer is sent off, and the team is in trouble.'),
      ];
      break;
  }
  return templates[seed % templates.length];
}

/// ポゼッション率・シュート数・枠内シュート数を表示するスタッツバー。
/// 旧セーブデータ由来などでスタッツが記録されていない試合では何も表示しない。
class MatchStatsBar extends StatelessWidget {
  final MatchResult result;
  final String homeTeamName;
  final String awayTeamName;

  const MatchStatsBar({
    super.key,
    required this.result,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final hp = result.homePossession;
    final ap = result.awayPossession;
    if (hp == null || ap == null) return const SizedBox.shrink();
    final barHp = hp.clamp(1, 99);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          _statRow(context, '$hp%', Tr.pick('ポゼッション', 'Possession'), '$ap%'),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: barHp,
                    child: Container(color: SemanticColors.positive(context)),
                  ),
                  Expanded(
                    flex: 100 - barHp,
                    child: Container(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _statRow(
            context,
            '${result.homeShots ?? 0}',
            Tr.pick('シュート', 'Shot'),
            '${result.awayShots ?? 0}',
          ),
          const SizedBox(height: 4),
          _statRow(
            context,
            '${result.homeShotsOnTarget ?? 0}',
            Tr.pick('枠内シュート', 'Shots on target'),
            '${result.awayShotsOnTarget ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context,
    String homeValue,
    String label,
    String awayValue,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            homeValue,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            awayValue,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
