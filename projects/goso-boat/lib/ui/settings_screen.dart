import 'package:flutter/material.dart';

import '../app/progress.dart';
import '../app/settings.dart';
import '../l10n/l10n_ext.dart';
import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';
import 'palette.dart';

/// 設定。音・振動・購入の復元（iOS の審査要件）・進み具合を消す・ライセンス。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.progress, required this.money});
  final Progress progress;
  final Monetization money;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _storeAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.money.store.isAvailable().then((v) {
      if (mounted) setState(() => _storeAvailable = v);
    });
  }

  Future<void> _restore() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = await widget.money.restore();
    final msg = switch (r) {
      PurchaseOutcome.purchased => t.purchaseRestored,
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => t.purchaseNothing,
      PurchaseOutcome.failed => t.purchaseFailed,
    };
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reset() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.resetConfirmTitle),
        content: Text(t.resetConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.doReset, style: const TextStyle(color: Palette.bad, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.progress.resetAll();
    messenger.showSnackBar(SnackBar(content: Text(t.resetDone)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final fx = AppScope.of(context);
    return Scaffold(
      backgroundColor: Palette.sky,
      appBar: AppBar(
        backgroundColor: Palette.sky,
        foregroundColor: Palette.ink,
        elevation: 0,
        title: Text(t.settingsTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([fx, widget.money]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Card(children: [
              SwitchListTile(
                title: Text(t.settingSound, style: const TextStyle(fontWeight: FontWeight.w800)),
                secondary: const Icon(Icons.volume_up_rounded, color: Palette.ink),
                value: fx.sound,
                onChanged: (v) {
                  fx.setSound(v);
                  if (v) fx.play(Sfx.tap);
                },
              ),
              SwitchListTile(
                title: Text(t.settingHaptics, style: const TextStyle(fontWeight: FontWeight.w800)),
                secondary: const Icon(Icons.vibration_rounded, color: Palette.ink),
                value: fx.haptics,
                onChanged: (v) {
                  fx.setHaptics(v);
                  if (v) fx.buzz(Buzz.medium);
                },
              ),
            ]),
            if (_storeAvailable || widget.money.adFree)
              _Card(children: [
                if (widget.money.adFree)
                  ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: Palette.ok),
                    title: Text(t.adFreeOn, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                if (_storeAvailable)
                  ListTile(
                    leading: const Icon(Icons.restore_rounded, color: Palette.ink),
                    title: Text(t.restorePurchases, style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: _restore,
                  ),
              ]),
            _Card(children: [
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Palette.ink),
                title: Text(t.licenses, style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => showLicensePage(context: context, applicationName: t.appTitle),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Palette.bad),
                title: Text(t.resetProgress, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.bad)),
                onTap: _reset,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Palette.card,
          border: Border.all(color: Palette.ink, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(color: Colors.transparent, child: Column(children: children)),
      );
}
