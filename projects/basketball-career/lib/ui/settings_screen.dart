import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/links.dart';
import '../monetization/monetization.dart';
import '../sound/sound.dart';
import 'howto_screen.dart';
import '../monetization/purchase_service.dart';
import 'layout.dart';
import 'remove_ads_offer.dart';

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
    final msg = purchaseMessage(r, restore: restore);
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
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (m != null)
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.volume_up_rounded),
                          title: const Text('効果音'),
                          subtitle: const Text('区切りのブザー・契約やトレードの成立音など。'),
                          value: Sfx.enabled,
                          onChanged: (v) async {
                            setState(() => Sfx.enabled = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('gmSound', v);
                            if (v) await Sfx.play(SoundEffect.chime);
                          },
                        ),
                      ],
                    ),
                  ),
                // 「広告を消す」は効果音と分けて1つの枠にする(2026-11-23「課金の画面をわかりやすく」)
                if (m != null && (m.adFree || _storeAvailable)) ...[
                  const SizedBox(height: 12),
                  _RemoveAdsCard(
                    adFree: m.adFree,
                    price: _storeAvailable && _price != null ? displayPrice(_price!) : null,
                    busy: _busy,
                    onBuy: () => _run(restore: false),
                    // 復元の導線は審査の要件(Apple)
                    onRestore: _storeAvailable ? () => _run(restore: true) : null,
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('遊び方'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HowToScreen())),
                      ),
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
                            context: context, applicationName: 'バスケGM'),
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

/// 設定画面の「広告を消す」の枠。値段・買い切り・買うと変わることを並べ、買ったあとはお礼を出す。
class _RemoveAdsCard extends StatelessWidget {
  const _RemoveAdsCard({required this.adFree, required this.price, required this.busy, required this.onBuy, required this.onRestore});
  final bool adFree;

  /// 表示する値段(ストアに繋がらないと null。そのときは買うボタンを出さない)。
  final String? price;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(adFree ? Icons.check_circle_rounded : Icons.block_rounded, color: adFree ? Colors.green : cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(adFree ? '広告を消しています' : '広告を消す', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (!adFree && price != null)
                Text('$price・買い切り', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
            ]),
            const SizedBox(height: 8),
            if (adFree)
              const Text('お買い上げありがとうございます。全画面広告は出ず、スカウトの追加とオーナーの説得も動画なしで使えます。',
                  style: TextStyle(fontSize: 14, height: 1.4))
            else ...[
              line(Icons.tv_off_rounded, '30試合ごとと、新しいシーズンに入るときの全画面広告が出なくなる'),
              line(Icons.play_disabled_rounded, 'スカウトの追加とオーナーの説得が、動画を見ずに使える(回数は同じ)'),
              line(Icons.all_inclusive_rounded, '一度買えばずっと。月額ではない'),
              if (price != null) ...[
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('remove-ads-buy'),
                  onPressed: busy ? null : onBuy,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('広告を消す($price)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
            if (onRestore != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(adFree ? '購入を復元' : '購入を復元(機種を変えた人はこちら)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
