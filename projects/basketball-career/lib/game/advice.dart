import 'game.dart';
import 'life.dart';

/// 今のおすすめの過ごし方。「おすすめで1年進める」が使う。
///
/// 怪我・疲れていれば休養、気持ちが沈んでいれば交流、チームワークが薄れていれば
/// 練習試合(疲れていれば交流)、大会の前の季節は疲れを残さない、疲れが軽ければ特訓、それ以外は練習。
Action recommendedAction(Game g) {
  final a = _base(g);
  // 同じ練習が続いてマンネリなら、別の練習に替える(伸びが落ちるため)。
  if (g.isRut(a)) {
    for (final alt in [Action.study, Action.scrimmage, Action.practice]) {
      if (alt != a && !g.isRut(alt) && canChoose(alt, g.condition)) return alt;
    }
  }
  return a;
}

Action _base(Game g) {
  final c = g.condition;
  if (c.injured || c.fatigue >= 70) return Action.rest;
  if (c.morale < 35) return Action.social;
  if (g.teamwork < 25) {
    return c.fatigue < 45 ? Action.scrimmage : Action.social;
  }
  // 大会は夏(slot 1)と、冬(slot 3、高校・大学のみ)。その1つ前の季節は特訓を避ける。
  final beforeTournament = g.slot == 0 || (g.slot == 2 && g.hasWinterCup);
  if (c.fatigue < 20 && !beforeTournament) return Action.intense;
  return Action.practice;
}
