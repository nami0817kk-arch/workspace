import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game.dart';
import '../game/achievements.dart';
import 'achievements_screen.dart';
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('文字の大きさ',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: SegmentedButton<double>(
                      key: const Key('text-scale'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0.9, label: Text('小')),
                        ButtonSegment(value: 1.0, label: Text('標準')),
                        ButtonSegment(value: 1.2, label: Text('大')),
                        ButtonSegment(value: 1.4, label: Text('特大')),
                      ],
                      selected: {controller.textScale},
                      onSelectionChanged: (s) =>
                          controller.setTextScale(s.first),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('画面の色',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: SegmentedButton<ThemeMode>(
                      key: const Key('theme-mode'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system, label: Text('自動')),
                        ButtonSegment(
                            value: ThemeMode.light, label: Text('明るい')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('暗い')),
                      ],
                      selected: {controller.themeMode},
                      onSelectionChanged: (s) =>
                          controller.setThemeMode(s.first),
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('reduce-motion'),
                    secondary: const Icon(Icons.motion_photos_off),
                    title: const Text('アニメーションを減らす'),
                    subtitle: const Text('画面の動きを止めます。'),
                    value: controller.reduceMotion,
                    onChanged: (v) => controller.setFlags(reduceMotion: v),
                  ),
                  SwitchListTile(
                    key: const Key('haptics-switch'),
                    secondary: const Icon(Icons.vibration),
                    title: const Text('触覚フィードバック'),
                    subtitle: const Text('行動や振り分けのとき、軽く振動します(対応する端末のみ)。'),
                    value: controller.haptics,
                    onChanged: (v) => controller.setFlags(haptics: v),
                  ),
                  SwitchListTile(
                    key: const Key('toasts-switch'),
                    secondary: const Icon(Icons.notifications_none),
                    title: const Text('行動の結果を画面の下に出す'),
                    subtitle: const Text('「戻す」ボタンもここに出ます。'),
                    value: controller.toasts,
                    onChanged: (v) => controller.setFlags(toasts: v),
                  ),
                  ListTile(
                    key: const Key('keys-open'),
                    leading: const Icon(Icons.keyboard),
                    title: const Text('キーボード操作'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('キーボード操作'),
                        content: const Text('Enter: おすすめの行動\n'
                            'R: 休養\n'
                            '1〜7: 練習・特訓・休養・研究・交流・練習試合・コーチ\n'
                            'Z: ひとつ前に戻す\n'
                            '(パソコンのブラウザなどで使えます)'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('閉じる'))
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('settings-achievements'),
                    leading: const Icon(Icons.military_tech),
                    title: const Text('実績'),
                    subtitle: Text(
                        '${controller.unlocked.length} / ${achievements.length} 解除'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AchievementsScreen(controller: controller),
                      ),
                    ),
                  ),
                  ListTile(
                    key: const Key('settings-help'),
                    leading: const Icon(Icons.help_outline),
                    title: const Text('あそびかた'),
                    onTap: () => showHelp(context),
                  ),
                  ListTile(
                    key: const Key('backup-open'),
                    leading: const Icon(Icons.save_alt),
                    title: const Text('バックアップ'),
                    subtitle: const Text('データを文字列で書き出して控えを取る・読み込んで戻す。'),
                    onTap: () => _backup(context),
                  ),
                  if (controller.game != null &&
                      controller.game!.phase != Phase.retired)
                    ListTile(
                      key: const Key('restart-open'),
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('この選手をやめて、はじめから'),
                      subtitle: Text(controller.lastSaved == null
                          ? '殿堂の記録は消えません。'
                          : '殿堂の記録は消えません。さいごの保存 ${controller.lastSaved!.hour.toString().padLeft(2, '0')}:${controller.lastSaved!.minute.toString().padLeft(2, '0')}'),
                      onTap: () => _confirmRestart(context),
                    ),
                  ListTile(
                    key: const Key('about-open'),
                    leading: const Icon(Icons.info_outline),
                    title: const Text('このアプリについて'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: '野球育成',
                      applicationVersion: appVersion,
                      children: const [
                        Text('6歳から、プロを引退するまで。1人の野球選手を育てる一代記。\n'
                            'データはこの端末にだけ保存されます。'),
                      ],
                    ),
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

  Future<void> _backup(BuildContext context) async {
    final text = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップ'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('「書き出す」で、いまのデータを文字列としてコピーします。'
                'メモなどに貼っておけば、あとで「読み込む」で戻せます。'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('backup-text'),
              controller: text,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), hintText: '読み込むときは、ここに貼り付け'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            key: const Key('backup-export'),
            onPressed: () async {
              final m = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                  ClipboardData(text: controller.exportBackup()));
              m.showSnackBar(const SnackBar(content: Text('コピーしました')));
            },
            child: const Text('書き出す'),
          ),
          FilledButton(
            key: const Key('backup-import'),
            onPressed: () async {
              final m = ScaffoldMessenger.of(context);
              final ok = await controller.importBackup(text.text);
              m.showSnackBar(SnackBar(
                  content: Text(ok ? '読み込みました' : '読み込めませんでした(文字列が違うかもしれません)')));
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('読み込む'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
    text.dispose();
  }

  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この選手をやめますか?'),
        content: const Text('育成中の選手はここで終わり、殿堂には残りません。\n新しい選手を最初から始められます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              key: const Key('restart-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('はじめから')),
        ],
      ),
    );
    if (ok == true) {
      await controller.reset();
      if (context.mounted) Navigator.of(context).pop();
    }
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
