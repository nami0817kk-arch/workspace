import 'package:flutter/material.dart';

import '../game/game.dart';
import 'admin_screen.dart';
import 'controller.dart';
import 'home_screen.dart' show showHelp;

/// 設定: 管理者モード・あそびかた・データの削除。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final g = controller.game;
        final canEdit = g != null && g.phase != Phase.retired;
        return Scaffold(
          appBar: AppBar(title: const Text('設定')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                children: [
                  SwitchListTile(
                    key: const Key('admin-switch'),
                    secondary: const Icon(Icons.admin_panel_settings),
                    title: const Text('管理者モード'),
                    subtitle: const Text(
                        '素質・特性・コツ・能力・経験点を、ルールを無視して自由に書き換えられます。通常の遊びでは使いません。'),
                    value: controller.adminMode,
                    onChanged: (_) => controller.toggleAdmin(),
                  ),
                  if (controller.adminMode)
                    ListTile(
                      key: const Key('admin-open-settings'),
                      leading: const Icon(Icons.tune),
                      title: const Text('管理者機能を開く'),
                      subtitle:
                          Text(canEdit ? '育成中の選手を書き換えます' : '育成中の選手がいるときに開けます'),
                      enabled: canEdit,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: canEdit
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AdminScreen(controller: controller)),
                              )
                          : null,
                    ),
                  const Divider(),
                  ListTile(
                    key: const Key('settings-help'),
                    leading: const Icon(Icons.help_outline),
                    title: const Text('あそびかた'),
                    onTap: () => showHelp(context),
                  ),
                  ListTile(
                    key: const Key('erase-all'),
                    leading: const Icon(Icons.delete_outline,
                        color: Color(0xFFD32F2F)),
                    title: const Text('すべてのデータを消す'),
                    subtitle: const Text('育成中の選手と、殿堂の記録を消します。元には戻せません。'),
                    onTap: () => _confirmErase(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('すべてのデータを消しますか?'),
        content: const Text('育成中の選手と、殿堂の記録がすべて消えます。元には戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
            key: const Key('erase-confirm'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('消す'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.eraseAll();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
