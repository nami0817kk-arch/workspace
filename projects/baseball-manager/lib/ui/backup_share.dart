import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// バックアップを、端末の共有メニュー(ファイルに保存・メール・クラウドへ)に渡す係。
/// テストでは使わない(`GameController.sharer` が null のときは、共有のボタンを出さない)。
abstract class BackupSharer {
  Future<void> share(String text, {Rect? origin});
}

/// 実機・Web で使う。バックアップをテキストファイルとして共有する。
class SharePlusSharer implements BackupSharer {
  const SharePlusSharer();

  @override
  Future<void> share(String text, {Rect? origin}) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    await SharePlus.instance.share(ShareParams(
      subject: '野球育成のバックアップ',
      files: [
        XFile.fromData(bytes,
            mimeType: 'text/plain', name: 'baseball-manager-backup.txt')
      ],
      fileNameOverrides: const ['baseball-manager-backup.txt'],
      sharePositionOrigin: origin,
    ));
  }
}
