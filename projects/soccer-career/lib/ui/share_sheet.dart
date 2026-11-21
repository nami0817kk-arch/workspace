import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../share/share_service.dart';
import 'share_card.dart';

/// 送る前に、送るものを見せる。
///
/// **何が送られるのか分からないまま共有シートが出るのが一番こわい。**
/// 画像をそのまま置いて、押したら送る。押さなければ何も起きない。
///
/// [service] はテスト用に差し替えられる（`createShareService` と同じ形）。
Future<void> showShareSheet(
  BuildContext context, {
  required Widget card,
  required String text,
  ShareService? service,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShareSheet(card: card, text: text, service: service),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.card, required this.text, this.service});

  final Widget card;
  final String text;
  final ShareService? service;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _boundary = GlobalKey();
  late final ShareService _service = widget.service ?? createShareService();
  bool _sending = false;

  /// 画面に出ている1枚を PNG にする。
  ///
  /// **`RepaintBoundary` は自分の大きさで描く**ので、見せるために
  /// `FittedBox` で縮めていても、送る画像は 360×450 の3倍（1080×1350）になる。
  Future<Uint8List?> _capture() async {
    try {
      final object = _boundary.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;
      final image = await object.toImage(pixelRatio: cardPixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      // 画像にできなくても、文だけは送れる。
      return null;
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    // 共有シートを出す位置（iPad）。押したシートの真ん中から出す。
    final box = context.findRenderObject();
    Rect? origin;
    if (box is RenderBox && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    final image = await _capture();
    await _service.share(text: widget.text, image: image, origin: origin);
    if (mounted) {
      setState(() => _sending = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('この1枚を送る', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'アプリの住所も一緒に付きます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // 画像そのもの。幅に合わせて縮めるだけで、中身は変えない。
            Flexible(
              child: FittedBox(
                child: RepaintBoundary(key: _boundary, child: widget.card),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.ios_share),
                label: Text(_sending ? '送っています…' : '送る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
