import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';

/// セーブの失敗を利用者に知らせる。
///
/// [GameState] の保存処理は、失敗しても例外を投げずに
/// [GameState.lastSaveError] へ記録するだけで進行を続ける(プレイ自体は
/// メモリ上のセーブデータで継続できるため)。その代わり、どこかで拾って
/// 表示しないと保存できていないことに気づけない。実際、この値は長らく
/// どの画面からも参照されておらず、保存の失敗は完全に沈黙していた。
/// ブラウザのストレージ上限に当たりうるWeb版では、進行が消えるまで
/// 気づけないことになる。
///
/// 保存はどの画面の操作でも起きるので、個々の画面ではなくアプリ全体を
/// 覆うここで面倒を見る。
class SaveErrorNotifier extends StatefulWidget {
  final Widget child;

  const SaveErrorNotifier({super.key, required this.child});

  @override
  State<SaveErrorNotifier> createState() => _SaveErrorNotifierState();
}

class _SaveErrorNotifierState extends State<SaveErrorNotifier> {
  /// 既に見せたメッセージ。同じ失敗で毎フレーム出し続けないために持つ。
  String? _shown;

  /// 控えからの復元を知らせたかどうか。1回の復元につき1度だけ出す。
  bool _restoreShown = false;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final error = gameState.lastSaveError;

    // セーブが壊れていて控えから戻したときの知らせ。黙って古い状態に
    // 戻すと、進めたはずの数節が消えたように見える。
    final restored = gameState.lastBackupRestoreNotice;
    if (restored != null && !_restoreShown) {
      _restoreShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(restored),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 10),
          ),
        );
      });
    }

    if (error == null) {
      // 保存に成功した。次に失敗したときはまた知らせる。
      _shown = null;
    } else if (error != _shown) {
      _shown = error;
      // build 中に SnackBar は出せないのでフレーム後に回す。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      });
    }

    return widget.child;
  }
}
