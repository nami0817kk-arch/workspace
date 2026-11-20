import '../l10n/tr.dart';

/// オーナーが決めたクラブの見た目(色・エンブレムの形と模様・頭文字)。
class ClubLook {
  /// 主の色と差し色の色相(0..360)。
  final double hue;
  final double accentHue;

  /// エンブレムの形と模様(ClubEmblem の描き分けの番号)。
  final int shape;
  final int motif;

  /// 頭文字(1〜2文字)。
  final String initial;

  const ClubLook({
    required this.hue,
    required this.accentHue,
    required this.shape,
    required this.motif,
    required this.initial,
  });

  ClubLook copyWith({
    double? hue,
    double? accentHue,
    int? shape,
    int? motif,
    String? initial,
  }) =>
      ClubLook(
        hue: hue ?? this.hue,
        accentHue: accentHue ?? this.accentHue,
        shape: shape ?? this.shape,
        motif: motif ?? this.motif,
        initial: initial ?? this.initial,
      );

  Map<String, dynamic> toJson() => {
        'hue': hue,
        'accentHue': accentHue,
        'shape': shape,
        'motif': motif,
        'initial': initial,
      };

  factory ClubLook.fromJson(Map<String, dynamic> j) => ClubLook(
        hue: (j['hue'] as num).toDouble(),
        accentHue: (j['accentHue'] as num).toDouble(),
        shape: j['shape'] as int,
        motif: j['motif'] as int,
        initial: j['initial'] as String,
      );

  /// 選べる12色(色相と名前)。
  static List<(double, String)> get colors => [
        (0, Tr.pick('赤', 'Red')),
        (22, Tr.pick('朱', 'Vermilion')),
        (40, Tr.pick('橙', 'Orange')),
        (52, Tr.pick('黄金', 'Gold')),
        (85, Tr.pick('若草', 'Lime')),
        (130, Tr.pick('緑', 'Green')),
        (160, Tr.pick('常盤', 'Evergreen')),
        (185, Tr.pick('青緑', 'Teal')),
        (205, Tr.pick('空', 'Sky')),
        (225, Tr.pick('紺', 'Navy')),
        (265, Tr.pick('紫', 'Purple')),
        (330, Tr.pick('桃', 'Rose')),
      ];

  /// 形と模様の名前(ClubEmblem の番号の順)。
  static List<String> get shapeNames => [
        Tr.pick('盾', 'Shield'),
        Tr.pick('六角', 'Hexagon'),
        Tr.pick('円', 'Circle'),
        Tr.pick('角丸', 'Rounded'),
        Tr.pick('菱形', 'Diamond'),
        Tr.pick('逆さ盾', 'Round shield'),
      ];

  static List<String> get motifNames => [
        Tr.pick('斜めの帯', 'Sash'),
        Tr.pick('星', 'Star'),
        Tr.pick('上下', 'Halves'),
        Tr.pick('縦じま', 'Stripes'),
        Tr.pick('山形', 'Chevron'),
        Tr.pick('四分割', 'Quarters'),
      ];
}

/// 画面のどこからでも自クラブの見た目を引けるようにする置き場。
/// GameState が変わるたびに入れ直す(エンブレム・ユニフォームの色の出どころ)。
class ClubLookRegistry {
  static String? teamId;
  static ClubLook? look;

  static ClubLook? lookFor(String id) => id == teamId ? look : null;
}
