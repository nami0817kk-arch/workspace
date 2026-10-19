/// 中学・高校の進学先。入学の年に1度だけ選べる(選ばなければ地元の学校)。
/// 強豪は勝ちやすい代わりに毎月ハード、進学校は勝ちにくい代わりに学びが多い。
enum School {
  powerhouse('強豪校', 'チーム力+7。毎月の練習がハードで、疲れが+2たまる。', 7, 1.0, 2),
  local('地元の学校', '普通の環境。', 0, 1.0, 0),
  academic('進学校', 'チーム力-4。落ち着いて学べて、経験点+4%。', -4, 1.04, 0);

  const School(this.label, this.description, this.teamAdjust,
      this.expMultiplier, this.fatigue);
  final String label;
  final String description;

  /// アマチュアの大会でのチーム力の増減。
  final int teamAdjust;

  /// 経験点の倍率。
  final double expMultiplier;

  /// 毎月増える疲れ。
  final int fatigue;

  static School parse(Object? s) =>
      School.values.firstWhere((e) => e.name == s, orElse: () => School.local);
}
