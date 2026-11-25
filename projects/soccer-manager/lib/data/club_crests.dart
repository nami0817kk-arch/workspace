import '../models/club_look.dart';
import 'club_names.dart';
import 'crest_hues.dart';

/// 画像生成で作ったクラブのエンブレム(assets/crests/NNN.webp。2026-11-25)。
///
/// [ClubNames] の表にある名前のクラブだけが画像を持つ。名前を書き換えて
/// 表に無い名前になったクラブ・自クラブ(オーナーが見た目を決めるクラブ)は、
/// 今までどおり ClubEmblem が描く。
class ClubCrests {
  ClubCrests._();

  /// [teamId] のクラブ([name])のエンブレム画像の番号。画像を使わないなら null。
  static int? indexFor(String teamId, String name) {
    // 自クラブで見た目を決めてあれば、そちら(自クラブ用の25枚か、描いた
    // エンブレム)。決めていない自クラブ(表のクラブを買い直した直後)は、
    // そのクラブの元の画像のまま。
    if (ClubLookRegistry.lookFor(teamId) != null) return null;
    final i = ClubNames.crestIndexOf(name);
    if (i == null || i >= kCrestCount) return null;
    return i;
  }

  /// 番号 [index] の画像の素材のパス。
  static String assetPath(int index) =>
      'assets/crests/${index.toString().padLeft(3, '0')}.webp';

  /// 自クラブ用の画像 [index](ClubLook.crest)の素材のパス。
  static String ownAssetPath(int index) =>
      'assets/crests/own_${index.toString().padLeft(2, '0')}.webp';

  /// [teamId] が自クラブで、見た目を決めておらず、表の画像も無いときに出す
  /// 自クラブ用の画像の番号。それ以外は null。
  static int? ownFallbackFor(String teamId, String name) {
    if (teamId != ClubLookRegistry.teamId) return null;
    if (ClubLookRegistry.look != null) return null;
    if (ClubNames.crestIndexOf(name) != null) return null;
    return ClubLook.defaultCrestFor(teamId, name);
  }

  /// 番号 [index] のエンブレムの (地, 差し色) の色相。-1 は白・黒・灰。
  static (int, int) hues(int index) =>
      (kCrestHues[index * 2], kCrestHues[index * 2 + 1]);
}
