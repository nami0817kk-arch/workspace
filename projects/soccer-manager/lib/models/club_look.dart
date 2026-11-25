import '../data/own_crest_hues.dart';
import '../l10n/tr.dart';
import '../theme/club_palette.dart';

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

  /// 画像のエンブレム(assets/crests/own_NN.webp。0..[crestCount]-1)の番号。
  /// null なら上の形・模様・頭文字で描く(2026-11-25)。画像を選んでいる
  /// あいだも形・模様・頭文字は残す(「描いたエンブレムに戻す」で使う)。
  final int? crest;

  const ClubLook({
    required this.hue,
    required this.accentHue,
    required this.shape,
    required this.motif,
    required this.initial,
    this.crest,
  });

  /// 選べる画像のエンブレムの数。
  static const int crestCount = kOwnCrestCount;

  /// 画像のエンブレム [crest] の (地, 差し色) の色相。片方が白・黒・灰なら
  /// 色のある方を両方に使う(ClubPalette.fromCrest と同じ決まり)。
  static (double, double) crestHues(int crest) {
    final a = kOwnCrestHues[crest * 2];
    final b = kOwnCrestHues[crest * 2 + 1];
    final base = a >= 0 ? a : b;
    final accent = b >= 0 ? b : base;
    return (base.toDouble(), accent.toDouble());
  }

  /// 画像のエンブレム [crest] にした見た目。色は絵の2色に合わせる。
  ClubLook withCrest(int crest) {
    final (h, a) = crestHues(crest);
    return ClubLook(
      hue: h,
      accentHue: a,
      shape: shape,
      motif: motif,
      initial: initial,
      crest: crest,
    );
  }

  /// 描いたエンブレム(形・模様・頭文字)に戻した見た目。
  ClubLook withoutCrest() => ClubLook(
        hue: hue,
        accentHue: accentHue,
        shape: shape,
        motif: motif,
        initial: initial,
      );

  /// 画像を変えずに、ほかを変える(画像を外すのは [withoutCrest])。
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
        crest: crest,
      );

  /// 同じ見た目か(決める前の下書きと今の見た目を比べる)。
  bool sameAs(ClubLook o) =>
      hue == o.hue &&
      accentHue == o.accentHue &&
      shape == o.shape &&
      motif == o.motif &&
      initial == o.initial &&
      crest == o.crest;

  Map<String, dynamic> toJson() => {
        'hue': hue,
        'accentHue': accentHue,
        'shape': shape,
        'motif': motif,
        'initial': initial,
        if (crest != null) 'crest': crest,
      };

  factory ClubLook.fromJson(Map<String, dynamic> j) {
    // 画像の番号を持たない古いセーブは描いたエンブレム。範囲の外の番号
    // (素材を減らしたとき)も描いたエンブレムに戻す。
    final c = j['crest'];
    final crest = c is int && c >= 0 && c < crestCount ? c : null;
    return ClubLook(
      hue: (j['hue'] as num).toDouble(),
      accentHue: (j['accentHue'] as num).toDouble(),
      shape: j['shape'] as int,
      motif: j['motif'] as int,
      initial: j['initial'] as String,
      crest: crest,
    );
  }

  /// 画像のエンブレムの中身の名前(番号の順。読み上げと札に使う)。
  static List<String> get crestNames => [
        Tr.pick('日の出と波', 'Sunrise'),
        Tr.pick('不死鳥', 'Phoenix'),
        Tr.pick('山と松', 'Pines'),
        Tr.pick('狐', 'Fox'),
        Tr.pick('稲妻', 'Lightning'),
        Tr.pick('王冠', 'Crown'),
        Tr.pick('鯉', 'Koi'),
        Tr.pick('鶴', 'Crane'),
        Tr.pick('虎', 'Tiger'),
        Tr.pick('燕', 'Swallow'),
        Tr.pick('兜', 'Helmet'),
        Tr.pick('鷹', 'Hawk'),
        Tr.pick('楢の葉', 'Oak leaf'),
        Tr.pick('錨と星', 'Anchor'),
        Tr.pick('跳ね馬', 'Horse'),
        Tr.pick('月に吠える狼', 'Wolf'),
        Tr.pick('桜', 'Blossom'),
        Tr.pick('城の塔', 'Tower'),
        Tr.pick('イルカ', 'Dolphin'),
        Tr.pick('獅子', 'Lion'),
        Tr.pick('龍', 'Dragon'),
        Tr.pick('鹿', 'Stag'),
        Tr.pick('炎', 'Flame'),
        Tr.pick('羅針', 'Compass'),
        Tr.pick('鷲', 'Eagle'),
      ];

  /// 決めていない自クラブに最初に付ける画像の番号。クラブの id と名前から
  /// 決まる(同じクラブなら端末や起動の回によらず同じ。String.hashCode は
  /// 環境で変わりうるので使わない)。
  static int defaultCrestFor(String teamId, String clubName) {
    var h = 0x811c9dc5;
    for (final r in '$teamId|${clubName.trim()}'.runes) {
      h = ((h ^ r) * 0x01000193) & 0xffffffff;
    }
    // 名前に色の語があれば(「青嵐FC」)、その色の絵から選ぶ。名前の色と
    // エンブレムの色が食い違うと、作り手が決めた色に見えない。
    final named = ClubPalette.hueForName(clubName);
    if (named != null) {
      final near = [
        for (var i = 0; i < crestCount; i++)
          if (ClubPalette.hueDistance(crestHues(i).$1, named) < 30) i,
      ];
      if (near.isNotEmpty) return near[h % near.length];
    }
    return h % crestCount;
  }

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
