import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game.dart';
import '../game/achievements.dart';
import 'achievements_screen.dart';
import 'admin_screen.dart';
import 'controller.dart';
import 'home_screen.dart' show showHelp;
import 'guide_dialog.dart';
import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';
import 'links.dart';
import 'trait_book_screen.dart';
import 'versus_screen.dart';

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
                  if (controller.adminMode)
                    ListTile(
                      key: const Key('versus-open'),
                      leading: const Icon(Icons.sports_baseball),
                      title: const Text('対戦テスト'),
                      subtitle: const Text(
                          '能力と特性を決めて、打者と投手を何千回も対戦させる(育成中の選手には影響しない)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const VersusScreen()),
                      ),
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
                    key: const Key('sound-switch'),
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('効果音'),
                    subtitle: const Text('能力アップ・節目・ドラフト・優勝などで鳴ります。'),
                    value: controller.soundOn,
                    onChanged: (v) => controller.setFlags(sound: v),
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
                    value: controller.toasts,
                    onChanged: (v) => controller.setFlags(toasts: v),
                  ),
                  if (controller.money != null)
                    _AdsSection(money: controller.money!),
                  ListTile(
                    key: const Key('privacy-open'),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('プライバシーポリシー'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openLink(context, Links.privacy),
                  ),
                  ListTile(
                    key: const Key('support-open'),
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('サポート・お問い合わせ'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openLink(context, Links.support),
                  ),
                  ListTile(
                    key: const Key('terms-open'),
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('利用規約'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openLink(context, Links.terms),
                  ),
                  ListTile(
                    key: const Key('guide-open'),
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('はじめてのガイド'),
                    subtitle: const Text('遊び方の流れを、もう一度見る。'),
                    onTap: () => showGuide(context),
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
                    key: const Key('settings-trait-book'),
                    leading: const Icon(Icons.auto_stories),
                    title: const Text('特性図鑑'),
                    subtitle: Text('特性 ${controller.seenTraitCount}・特殊能力 ${controller.seenSkills.length} 発見'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TraitBookScreen(controller: controller),
                      ),
                    ),
                  ),
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

  Future<void> _openLink(BuildContext context, Uri url) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await Links.open(url);
    if (!ok) m.showSnackBar(const SnackBar(content: Text('ページを開けませんでした')));
  }

  Future<void> _backup(BuildContext context) => showDialog<void>(
        context: context,
        builder: (ctx) => _BackupDialog(
          controller: controller,
          onRestore: (i) => _confirmRestoreAuto(ctx, i),
        ),
      );

  Future<void> _confirmRestoreAuto(BuildContext context, int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この時点に戻しますか?'),
        content: const Text('いまのデータは、自動バックアップにとってから戻します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              key: const Key('autobackup-restore-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('戻す')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await controller.restoreAutoBackup(i);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done ? '戻しました' : '戻せませんでした')));
      if (done) Navigator.pop(context);
    }
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

/// バックアップのダイアログ。入力欄の持ち主はここ(閉じる動きの間も、安全に描かれる)。
class _BackupDialog extends StatefulWidget {
  const _BackupDialog({required this.controller, required this.onRestore});
  final GameController controller;

  /// 自動バックアップ `i` に戻す(確認つき)。
  final Future<void> Function(int i) onRestore;

  static String _fmtTime(DateTime t) =>
      '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<_BackupDialog> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('バックアップ'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('「書き出す」で、いまのデータを文字列としてコピーします。'
              'メモなどに貼っておけば、あとで「読み込む」で戻せます。'),
          const SizedBox(height: 12),
          if (widget.controller.autoBackups.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('自動バックアップ(最新$autoBackupMax件)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (var i = 0; i < widget.controller.autoBackups.length; i++)
              ListTile(
                key: Key('autobackup-$i'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(widget.controller.autoBackups[i].why),
                subtitle: Text(_BackupDialog._fmtTime(
                    widget.controller.autoBackups[i].at)),
                trailing: TextButton(
                  key: Key('autobackup-restore-$i'),
                  onPressed: () => widget.onRestore(i),
                  child: const Text('戻す'),
                ),
              ),
            const SizedBox(height: 8),
          ],
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
        if (widget.controller.sharer != null)
          Builder(
            builder: (bctx) => TextButton(
              key: const Key('backup-share'),
              onPressed: () {
                final box = bctx.findRenderObject() as RenderBox?;
                final origin = box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size;
                widget.controller.sharer!
                    .share(widget.controller.exportBackup(), origin: origin);
              },
              child: const Text('ファイルで共有'),
            ),
          ),
        TextButton(
          key: const Key('backup-export'),
          onPressed: () async {
            final m = ScaffoldMessenger.of(context);
            await Clipboard.setData(
                ClipboardData(text: widget.controller.exportBackup()));
            m.showSnackBar(const SnackBar(content: Text('コピーしました')));
          },
          child: const Text('書き出す'),
        ),
        FilledButton(
          key: const Key('backup-import'),
          onPressed: () async {
            final m = ScaffoldMessenger.of(context);
            final ok = await widget.controller.importBackup(text.text);
            m.showSnackBar(SnackBar(
                content: Text(ok ? '読み込みました' : '読み込めませんでした(文字列が違うかもしれません)')));
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: const Text('読み込む'),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
      ],
    );
  }
}

/// 買い切りの商品(広告を消す・継承ブースト)と、購入の復元。
/// ストアに繋がらない環境では、持っている商品だけ出す。
class _AdsSection extends StatefulWidget {
  const _AdsSection({required this.money});
  final Monetization money;

  @override
  State<_AdsSection> createState() => _AdsSectionState();
}

/// 商品の名前と中身(表示用)。
const _items = <(String, String, String, IconData)>[
  (
    PurchaseService.removeAdsId,
    '広告を消す',
    '年替わりの全画面広告が出なくなり、動画の特典(疲れを取る・経験点・継承ポイント)も動画なしでもらえます。',
    Icons.block
  ),
  (
    PurchaseService.legacyBoostId,
    '継承ブースト',
    '引退のたびに貯まる継承ポイントが2倍になります。次の選手を強く始めやすくなります。',
    Icons.card_giftcard
  ),
];

class _AdsSectionState extends State<_AdsSection> {
  bool _storeAvailable = false;
  final Map<String, String?> _prices = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.money.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    widget.money.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final v = await widget.money.storeAvailable;
    final prices = <String, String?>{};
    if (v) {
      for (final it in _items) {
        prices[it.$1] = await widget.money.priceOf(it.$1);
      }
    }
    if (!mounted) return;
    setState(() {
      _storeAvailable = v;
      _prices
        ..clear()
        ..addAll(prices);
    });
  }

  Future<void> _run(String? id) async {
    setState(() => _busy = true);
    final m = ScaffoldMessenger.of(context);
    final restore = id == null;
    PurchaseOutcome r;
    try {
      r = await (restore ? widget.money.restore() : widget.money.buyItem(id));
    } catch (_) {
      r = PurchaseOutcome.failed;
    }
    if (mounted) setState(() => _busy = false);
    final text = switch (r) {
      PurchaseOutcome.purchased => restore ? '購入を復元しました。' : 'ありがとうございます。購入が完了しました。',
      PurchaseOutcome.pending => '保護者の承認を待っています。承認されると届きます。',
      PurchaseOutcome.canceled => '',
      PurchaseOutcome.unavailable => restore ? '復元できる購入が見つかりませんでした。' : '今は購入できません。しばらくしてからもう一度どうぞ。',
      PurchaseOutcome.failed => restore ? '復元できませんでした。通信を確かめてください。' : '購入できませんでした。もう一度どうぞ。',
    };
    if (text.isNotEmpty) m.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final money = widget.money;
    final rows = <Widget>[];
    for (final it in _items) {
      final (id, label, desc, icon) = it;
      if (money.owns(id)) {
        rows.add(ListTile(
          key: Key(id == PurchaseService.removeAdsId ? 'ad-free-on' : 'owned-$id'),
          leading: const Icon(Icons.check_circle, color: Color(0xFF43A047)),
          title: Text('$label(購入済み)'),
          subtitle: Text(desc),
        ));
      } else if (_storeAvailable && _prices[id] != null) {
        rows.add(ListTile(
          key: Key(id == PurchaseService.removeAdsId ? 'remove-ads' : 'buy-$id'),
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text('$desc(買い切り)'),
          trailing: Text(_prices[id]!,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          enabled: !_busy,
          onTap: () => _run(id),
        ));
      }
    }
    // 商品情報が取れなくても復元の入口は残す(審査で復元の導線が見えないと困る)。
    if (_storeAvailable) {
      rows.add(ListTile(
        key: const Key('restore-purchases'),
        leading: const Icon(Icons.restore),
        title: const Text('購入を復元'),
        enabled: !_busy,
        onTap: () => _run(null),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: rows);
  }
}
