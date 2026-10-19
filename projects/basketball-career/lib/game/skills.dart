import 'match.dart';
import 'player.dart';

/// 得意技。バスケらしいプレーの型で、条件を満たすと自然に身につく(年末ではなくターンごとに判定)。
/// 勝負どころの成功率に効くものと、チームの動きに効くものがある。
enum Skill {
  stepBack('ステップバック3', '間合いを外して打つ3P。勝負どころの3Pが決まりやすい(+6%)。'),
  floater('フローター', '長身の守りの上から浮かせて決める。勝負どころのドライブが決まりやすい(+6%)。'),
  postHook('ポストフック', '背を向けて体で守り、片手で決める。勝負どころのドライブ(+6%)。'),
  dunk('ダンク', '空中で叩き込む。勝負どころのドライブ(+5%)とファウルをもらう(+4%)。'),
  pickAndRoll('ピック&ロール', '味方と組んで崩す。勝負どころのパスが決まりやすい(+6%)。'),
  shotBlocker('ブロック名人', 'シュートを叩き落とす。勝負どころのディフェンスが決まりやすい(+8%)。'),
  stealer('スティール名人', '読みで奪う。勝負どころのディフェンスが決まりやすい(+6%)。'),
  clutchShooter('フリースローの名手', '重圧でも外さない。ファウルをもらうが決まりやすい(+8%)。'),
  handler('ハンドラー', '司令塔の技術。チームの動きが良くなる(大会の味方の強さ +1.0)。'),
  sniper('3Pスペシャリスト', '外からの精度。勝負どころの3Pが決まりやすい(+5%)。');

  const Skill(this.label, this.description);
  final String label;
  final String description;

  static Skill? parse(String s) {
    for (final k in Skill.values) {
      if (k.name == s) return k;
    }
    return null;
  }

  /// 条件(能力と身長)を満たしているか。
  bool qualifies(Player p) {
    int a(Ability x) => p.of(x);
    final h = p.heightCm;
    return switch (this) {
      Skill.stepBack => a(Ability.threePoint) >= 60 && a(Ability.dribble) >= 55,
      Skill.floater =>
        a(Ability.inside) >= 50 && a(Ability.dribble) >= 60 && h < 195,
      Skill.postHook => a(Ability.inside) >= 65 && h >= 195,
      Skill.dunk =>
        a(Ability.physical) >= 65 && a(Ability.speed) >= 55 && h >= 185,
      Skill.pickAndRoll => a(Ability.pass) >= 60 && a(Ability.dribble) >= 55,
      Skill.shotBlocker => a(Ability.defense) >= 65 && h >= 190,
      Skill.stealer => a(Ability.defense) >= 60 && a(Ability.speed) >= 60,
      Skill.clutchShooter => a(Ability.freeThrow) >= 75,
      Skill.handler => a(Ability.dribble) >= 70 && a(Ability.pass) >= 60,
      Skill.sniper => a(Ability.threePoint) >= 80,
    };
  }

  /// 勝負どころの成功率への加算(0〜1)。
  double clutchBonus(Clutch c) => switch ((this, c)) {
        (Skill.stepBack, Clutch.threePoint) => 0.06,
        (Skill.sniper, Clutch.threePoint) => 0.05,
        (Skill.floater, Clutch.drive) => 0.06,
        (Skill.postHook, Clutch.drive) => 0.06,
        (Skill.dunk, Clutch.drive) => 0.05,
        (Skill.dunk, Clutch.drawFoul) => 0.04,
        (Skill.pickAndRoll, Clutch.pass) => 0.06,
        (Skill.shotBlocker, Clutch.defend) => 0.08,
        (Skill.stealer, Clutch.defend) => 0.06,
        (Skill.clutchShooter, Clutch.drawFoul) => 0.08,
        _ => 0.0,
      };

  /// 大会の味方の強さへの加算。
  double get teamBonus => this == Skill.handler ? 1.0 : 0.0;
}

/// 新しく身についた得意技(いま持っていないものだけ)。
Set<Skill> newlyQualified(Player p) => {
      for (final k in Skill.values)
        if (!p.skills.contains(k) && k.qualifies(p)) k,
    };
