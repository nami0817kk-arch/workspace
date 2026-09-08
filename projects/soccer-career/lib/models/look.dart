import 'dart:math';

/// 髪型。
enum HairStyle {
  short('短髪'),
  crop('刈り上げ'),
  curly('くせ毛'),
  long('長髪'),
  bun('結ぶ'),
  bald('坊主');

  const HairStyle(this.label);

  final String label;
}

/// 見た目。
///
/// **試合の判定には一切効かない。** 能力や特性と混ぜると、
/// 見た目を選ぶことが最適解探しになる。ここは純粋に「自分の選手」を
/// 作るためだけのもの。
///
/// 色は番号で持つ。名前で持つと、色を足したときに保存データが読めなくなる。
class PlayerLook {
  const PlayerLook({
    this.skin = 1,
    this.hair = HairStyle.short,
    this.hairColor = 0,
  });

  /// 肌の色。[skinTones] の番号。
  final int skin;

  final HairStyle hair;

  /// 髪の色。[hairColors] の番号。
  final int hairColor;

  /// 肌の色。実在の人を並べたときに偏らないよう、明暗を等間隔に取ってある。
  static const List<int> skinTones = [
    0xFFF2D3B8,
    0xFFE0B295,
    0xFFC68A62,
    0xFF9C6340,
    0xFF6F452B,
    0xFF4A2E1E,
  ];

  static const List<int> hairColors = [
    0xFF1E1A18, // 黒
    0xFF4A3427, // 焦茶
    0xFF8A6234, // 栗
    0xFFD9B26A, // 金
    0xFF8C3B25, // 赤茶
    0xFFBFBFBF, // 白髪
  ];

  static const List<String> hairColorLabels = [
    '黒',
    '焦茶',
    '栗',
    '金',
    '赤茶',
    '白',
  ];

  PlayerLook copyWith({int? skin, HairStyle? hair, int? hairColor}) =>
      PlayerLook(
        skin: skin ?? this.skin,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
      );

  factory PlayerLook.roll(Random random) => PlayerLook(
        skin: random.nextInt(skinTones.length),
        hair: HairStyle.values[random.nextInt(HairStyle.values.length)],
        hairColor: random.nextInt(hairColors.length),
      );

  Map<String, dynamic> toJson() =>
      {'skin': skin, 'hair': hair.name, 'hairColor': hairColor};

  factory PlayerLook.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlayerLook();
    final hairName = json['hair'];
    return PlayerLook(
      skin: (json['skin'] as int? ?? 1).clamp(0, skinTones.length - 1),
      hair: HairStyle.values.any((h) => h.name == hairName)
          ? HairStyle.values.byName(hairName as String)
          : HairStyle.short,
      hairColor:
          (json['hairColor'] as int? ?? 0).clamp(0, hairColors.length - 1),
    );
  }
}
