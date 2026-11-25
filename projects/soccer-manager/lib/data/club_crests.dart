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
    // 自クラブはオーナーが見た目を決める。決める前も、決めた後と同じ
    // 描いたエンブレムにしておく(決めた途端に絵柄の種類が変わらないよう)。
    if (teamId == ClubLookRegistry.teamId) return null;
    final i = ClubNames.crestIndexOf(name);
    if (i == null || i >= kCrestCount) return null;
    return i;
  }

  /// 番号 [index] の画像の素材のパス。
  static String assetPath(int index) =>
      'assets/crests/${index.toString().padLeft(3, '0')}.webp';

  /// 番号 [index] のエンブレムの (地, 差し色) の色相。-1 は白・黒・灰。
  static (int, int) hues(int index) =>
      (kCrestHues[index * 2], kCrestHues[index * 2 + 1]);
}
