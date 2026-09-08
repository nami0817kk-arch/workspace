import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/career_controller.dart';

/// 引き継ぎコードの出し入れ。
///
/// 拠点の「⋮」だけに置いていたが、そこに気付かないまま何年も進めた人は、
/// ブラウザのデータを消した瞬間に全部失う。シーズンの区切りからも
/// 開けるようにしたので、画面の外に出してある。
class TransferCode {
  const TransferCode._();

  /// 引き継ぎコードを見せる。開いた時点で「控えた年」を記録する。
  static Future<void> show(
      BuildContext context, CareerController controller) async {
    final code = controller.exportCode();
    if (code == null) return;
    await controller.markBackedUp();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引き継ぎコード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'このコードをコピーして、別の端末で「セーブを読み込む」に貼り付けると、'
              '続きから遊べる。長いので、メモアプリなどに保存しておくとよい。',
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  code,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('引き継ぎコードをコピーした')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
          ),
        ],
      ),
    );
  }

  /// 引き継ぎコードから復元する。今のキャリアは上書きされる。
  static Future<void> import(
      BuildContext context, CareerController controller) async {
    final input = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('セーブを読み込む'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '別の端末で作った引き継ぎコードを貼り付ける。'
              '今のキャリアは上書きされる。',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'SC1:...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(input.text),
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final ok = await controller.importCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? 'キャリアを読み込んだ' : 'コードを読めなかった。今のキャリアはそのまま。'),
      ));
  }
}
