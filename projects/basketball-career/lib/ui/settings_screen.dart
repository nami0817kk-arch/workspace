import 'package:flutter/material.dart';

import '../app/links.dart';
import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// 設定。広告を消す・購入の復元・プライバシー・問い合わせ・ライセンス。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.money});
  final Monetization? money;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _storeAvailable = false;
  String? _price;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.money?.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    widget.money?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final m = widget.money;
    if (m == null) return;
    final available = await m.store.isAvailable();
    final price = available && !m.adFree ? await m.price : null;
    if (mounted) {
      setState(() {
        _storeAvailable = available;
        _price = price;
      });
    }
  }

  Future<void> _openLink(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await Links.open(url)) {
      messenger.showSnackBar(SnackBar(content: Text('ページを開けなかった: $url')));
    }
  }

  Future<void> _run({required bool restore}) async {
    final m = widget.money;
    if (m == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    PurchaseOutcome r;
    try {
      r = await (restore ? m.restore() : m.buy());
    } catch (_) {
      r = PurchaseOutcome.failed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final msg = switch (r) {
      PurchaseOutcome.purchased =>
        restore ? '購入を復元した。広告が出なくなった。' : 'ありがとう! 広告が出なくなった。',
      PurchaseOutcome.pending => '承認待ち。承認されると広告が消える。',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => restore ? '復元できる購入が見つからなかった。' : '購入できなかった。',
      PurchaseOutcome.failed => restore ? '復元に失敗した。あとでもう一度。' : '購入に失敗した。あとでもう一度。',
    };
    if (msg != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.money;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (m != null)
                  Card(
                    child: Column(
                      children: [
                        if (m.adFree)
                          const ListTile(
                            leading: Icon(Icons.check_circle_rounded),
                            title: Text('広告を消している'),
                          ),
                        if (_storeAvailable && !m.adFree && _price != null)
                          ListTile(
                            leading: const Icon(Icons.block_rounded),
                            title: Text('広告を消す($_price)'),
                            subtitle: const Text('全画面広告が出なくなり、動画なしで回復できる。'),
                            enabled: !_busy,
                            onTap: () => _run(restore: false),
                          ),
                        // 復元の導線は審査の要件(Apple)
                        if (_storeAvailable)
                          ListTile(
                            leading: const Icon(Icons.restore_rounded),
                            title: const Text('購入を復元'),
                            enabled: !_busy,
                            onTap: () => _run(restore: true),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      // プライバシーポリシーはアプリの中からも開けること(Apple 5.1.1)
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('プライバシーポリシー'),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => _openLink(Links.privacy),
                      ),
                      // 不適切な広告を報告できる手段を用意すること(Apple 2.5.18)
                      ListTile(
                        leading: const Icon(Icons.support_agent_rounded),
                        title: const Text('問い合わせ・広告の報告'),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => _openLink(Links.support),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('ライセンス'),
                        onTap: () => showLicensePage(
                            context: context, applicationName: 'バスケ育成'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
