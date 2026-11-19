import 'player.dart';

/// オーナーがSD(スポーツディレクター)に渡す補強の方針。
///
/// オーナーが決めるのは「任せるか・1人あたりの移籍金の上限・欲しい位置・
/// 年齢の上限・この窓で取る人数」だけ。クラブとの交渉と選手との交渉は
/// SD が進める。
class SdBrief {
  /// 補強をSDに任せるか。
  bool active;

  /// 1人あたりの移籍金の上限(万円)。
  int maxFee;

  /// 欲しい位置(空なら位置は問わない)。
  Set<PositionGroup> groups;

  /// 年齢の上限。
  int maxAge;

  /// この窓で取る人数(1〜3)。
  int maxSignings;

  SdBrief({
    this.active = false,
    this.maxFee = 0,
    Set<PositionGroup>? groups,
    this.maxAge = 29,
    this.maxSignings = 1,
  }) : groups = groups ?? {};

  Map<String, dynamic> toJson() => {
        'active': active,
        'maxFee': maxFee,
        'groups': [for (final g in groups) g.name],
        'maxAge': maxAge,
        'maxSignings': maxSignings,
      };

  factory SdBrief.fromJson(Map<String, dynamic> j) => SdBrief(
        active: j['active'] as bool? ?? false,
        maxFee: j['maxFee'] as int? ?? 0,
        groups: {
          for (final n in (j['groups'] as List? ?? const []))
            ...PositionGroup.values.where((g) => g.name == n),
        },
        maxAge: j['maxAge'] as int? ?? 29,
        maxSignings: j['maxSignings'] as int? ?? 1,
      );
}
