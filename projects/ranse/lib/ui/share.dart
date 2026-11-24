import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// 結果を外へ送る（2026-11-24、ユーザー「シェアボタンにする」）。
///
/// 送るのは「結果カードの画像1枚＋短い文」。文だけでは X も LINE も流れていくので、
/// 画面の結果カード（生まれの稀少度・選んだ道・称号・最期）をそのまま画像にする。
/// 書き方は soccer-career の `share_service.dart` と同じ（共有シート・一時置き場・Web とテストでは何もしない）。

/// この端末で共有シートが使えるか（Web とテストでは使えない）。
bool get canShare {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

/// [key] の付いた `RepaintBoundary` を PNG にする。描けなければ null。
Future<Uint8List?> captureCard(GlobalKey key, {double pixelRatio = 3}) async {
  try {
    final obj = key.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// 共有シートを開く。画像が無ければ文だけ送る。送れなくても遊びは止めない。
///
/// [origin] は iPad で共有シートを出す位置（押した釦の場所）。
Future<void> shareResult({
  required String text,
  Uint8List? image,
  Rect? origin,
}) async {
  if (!canShare) return;
  try {
    final files = <XFile>[];
    if (image != null) {
      // 端末の一時置き場に書く（iOS では NSTemporaryDirectory。OS が片付ける）。
      final dir = await Directory.systemTemp.createTemp('ranse_share');
      final file = File('${dir.path}/ranse_result.png');
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
    // 共有はあると嬉しいもので、人生を遊ぶのに要るものではない。
  }
}
