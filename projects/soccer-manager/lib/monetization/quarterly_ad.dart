import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import 'monetization_controller.dart';

/// 節を進め終えたところで呼ぶ。ゲームの中で前回から3か月たっていれば、
/// 全画面広告を出して閉じられるまで待つ
/// ([MonetizationController.showQuarterlyInterstitial])。
///
/// 呼ぶのは進める入口(進むボタン・まとめて進める・次の決めごとまで
/// 進める・次のシーズンへ)の**最後**だけ。結果のダイジェストやお知らせを
/// 出し終えてから出すので、試合中やメニュー操作の途中には割り込まない。
Future<void> maybeShowQuarterlyAd(BuildContext context) async {
  if (!context.mounted) return;
  final MonetizationController money;
  try {
    money = context.read<MonetizationController>();
  } on ProviderNotFoundException {
    // 広告の仕組みを載せていない画面の検査など。何もしない。
    return;
  }
  final gs = context.read<GameState>();
  if (gs.save == null) return;
  await money.showQuarterlyInterstitial(gs.currentMonthKey);
}
