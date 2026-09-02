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
  const QuickAccessDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final clubName = gameState.save?.clubName ??
        Tr.pick('サッカー経営マネージャー', 'Soccer Club Manager');
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  clubName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final dest in quickAccessDestinations)
              Builder(builder: (context) {
                // まだ中身が空になる画面は、開く前にその旨を見せる。
                // 隠さずに残すのは、機能の存在と到達条件を伝えるため。
                final locked =
                    dest.lockedReason?.call(context.watch<GameState>());
                return ListTile(
                  enabled: locked == null,
                  leading: CircleAvatar(
                    backgroundColor: locked == null
                        ? dest.color
                        : dest.color.withValues(alpha: 0.35),
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
              }),
          ],
        ),
      ),
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
