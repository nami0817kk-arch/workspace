import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// お金が動く操作を、押した直後の数秒だけ取り消せるようにする。
///
/// 雇う・オーナーの手・施設の増築は1回押すと確定し、押し間違えても戻せ
/// なかった。確認のダイアログを増やすと毎回の手数が増えるので、代わりに
/// 押す直前のセーブを控えておき、知らせの帯に「取り消す」を出す。
Future<bool> runUndoable(
  BuildContext context, {
  required Future<bool> Function() action,
  required String done,
}) async {
  final game = context.read<GameState>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final before = game.exportSaveJson();
  final ok = await action();
  if (!ok || before == null || messenger == null) return ok;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(done),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: Tr.pick('取り消す', 'Undo'),
        onPressed: () => game.importSaveJson(before),
      ),
    ));
  return ok;
}
