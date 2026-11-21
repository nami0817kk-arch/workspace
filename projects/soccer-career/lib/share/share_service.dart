import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// 外に送る窓口。
///
/// **文だけでは広まらない。** X も LINE も、画像が付いていないものは
/// 流れていく。だから送るのは「画像1枚＋短い文」で、画像は遊んだ人の
/// 20年がそのまま出ているもの（`ui/share_card.dart`）にする。
///
/// `createAdService` / `createReviewService` と同じ形にしてある。
/// **片方だけ書き方が違うと、テストで実物が動いていることに気付けない。**
abstract class ShareService {
  Future<bool> isAvailable();

  /// 送る。[image] は PNG の中身。
  ///
  /// [origin] は iPad で共有シートを出す位置。渡さないと画面の中央に出る
  /// （落ちはしないが、押した場所から出たほうが分かりやすい）。
  Future<void> share({
    required String text,
    Uint8List? image,
    String fileName = 'career.png',
    Rect? origin,
  });
}

/// 何もしない実装。Web とテストで使う。
class NoShareService implements ShareService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> share({
    required String text,
    Uint8List? image,
    String fileName = 'career.png',
    Rect? origin,
  }) async {}
}

class SystemShareService implements ShareService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> share({
    required String text,
    Uint8List? image,
    String fileName = 'career.png',
    Rect? origin,
  }) async {
    try {
      final files = <XFile>[];
      if (image != null) {
        // **端末の一時置き場に書く。** `path_provider` を足さずに済む
        // （依存は増やさない。`Directory.systemTemp` は iOS では
        // NSTemporaryDirectory なので、OS が勝手に片付ける）。
        final dir = await Directory.systemTemp.createTemp('career_share');
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(image, flush: true);
        files.add(XFile(file.path, mimeType: 'image/png'));
      }
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: files.isEmpty ? null : files,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // **送れなくても遊びは止めない。** 共有はあると嬉しいもので、
      // キャリアを進めるのに要るものではない（殿堂の読み書きと同じ扱い）。
    }
  }
}

/// この端末で使う実装を選ぶ。
ShareService createShareService() {
  if (kIsWeb) return NoShareService();
  try {
    if (Platform.isAndroid || Platform.isIOS) return SystemShareService();
  } catch (_) {
    // テスト環境など、Platform を参照できない場合。
  }
  return NoShareService();
}

/// 送る文を組み立てる。
///
/// **ストアの住所を必ず入れる。** 見た人が辿れないなら、広める意味がない。
/// 名義は出さない（公開文面に本名も社名も載せない、という決まり）。
abstract final class ShareText {
  static const String appName = '選手キャリア';
  static const String storeUrl = 'https://apps.apple.com/jp/app/id6817971889';
  static const String tag = '#選手キャリア';

  /// 行を並べて、札とストアの住所で締める。空の行は落とす。
  static String compose(List<String> lines) =>
      [...lines.where((l) => l.isNotEmpty), tag, storeUrl].join('\n');
}
