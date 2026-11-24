import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quick_access_destinations.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../l10n/tr.dart';

/// どのメインタブ(ホーム/スカッド/戦術/順位表)からでも、ホーム画面の
/// 「クラブ運営」グリッドにある管理画面へ直接ジャンプできるドロワー。
/// タブを一度ホームへ戻さなくても主要機能へアクセスできるようにする。
class QuickAccessDrawer extends StatelessWidget {
  const QuickAccessDrawer({super.key, this.onlyOthers = false});

  /// 横画面の上の帯の ≡ から開くとき。操作する画面は左メニューの項目の
  /// 中にまとまっているので、「資料」と「設定とヘルプ」だけを出す。
  final bool onlyOthers;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final clubName = gameState.save?.clubName ??
        Tr.pick('サッカー経営マネージャー', 'Soccer Club Manager');
    return Drawer(
      child: SafeArea(
        child: ListView(
          // 開くたびに上から(画面の一覧の送り位置を引き継がない)。
          primary: false,
          padding: EdgeInsets.zero,
          children: [
            // 上の帯は細く(2026-11-25)。以前の大きな見出し(約160)は、
            // 横画面の低い高さの半分近くを使い、資料が2つしか見えなかった。
            Container(
              key: const ValueKey('drawer-header'),
              height: 44,
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Text(
                clubName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            // 見出しで「資料」「設定とヘルプ」に分ける。横画面では、操作する
            // 画面は左メニューにあるので出さない(2026-11-24)。
            for (final group in QuickAccessGroup.values)
              if (!onlyOthers || group != QuickAccessGroup.manage) ...[
                Padding(
                  key: ValueKey('drawer-group-${group.name}'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    switch (group) {
                      QuickAccessGroup.manage =>
                        Tr.pick('クラブ運営', 'Running the club'),
                      QuickAccessGroup.reference =>
                        Tr.pick('資料(見るだけ)', 'Reference (view only)'),
                      QuickAccessGroup.help =>
                        Tr.pick('設定とヘルプ', 'Settings & help'),
                    },
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final dest in quickAccessDestinations)
                  if (dest.group == group) _DestinationTile(dest: dest),
              ],
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.dest});

  final QuickAccessDestination dest;

  @override
  Widget build(BuildContext context) {
    // まだ中身が空になる画面は、開く前にその旨を見せる。
    // 隠さずに残すのは、機能の存在と到達条件を伝えるため。
    final locked = dest.lockedReason?.call(context.watch<GameState>());
    return ListTile(
      enabled: locked == null,
      leading: CircleAvatar(
        backgroundColor:
            locked == null ? dest.color : dest.color.withValues(alpha: 0.35),
        child: Icon(
          locked == null ? dest.icon : Icons.lock_outline,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(dest.label),
      subtitle: locked == null ? null : Text(locked),
      // 押しても開けないので、無反応にせず理由を出す。
      onTap: locked != null
          ? null
          : () {
              FeedbackService.tap();
              Navigator.of(context).pop();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: dest.builder));
            },
    );
  }
}

/// AppBarにQuickAccessDrawerを開くボタンを明示的に置くためのウィジェット。
/// Scaffoldにdrawerを設定すると、Flutterはpushされた画面でも戻るボタンより
/// ハンバーガーアイコンを優先して自動表示してしまう(AppBar内部の
/// automaticallyImplyLeadingがhasDrawerをcanPopより先に判定するため)。
/// そのため戻るボタンが消えて「戻れない」状態になるのを防ぐには、AppBarの
/// leadingを明示的にBackButtonにし、ドロワーはこのボタンをactionsに置いて
/// 開く必要がある。
class QuickAccessMenuButton extends StatelessWidget {
  const QuickAccessMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    // 横画面で重ねて開いた画面は、左上の戻るだけにする(≡と戻るの入口が
    // 2つあって迷った)。他の画面へは戻ってから、上の帯の左端の≡で行く。
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height && Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: Tr.pick('他の管理画面へ', 'Other screens'),
      onPressed: () {
        FeedbackService.tap();
        Scaffold.of(context).openDrawer();
      },
    );
  }
}
