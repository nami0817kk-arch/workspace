import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scouting_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';
import '../widgets/disabled_reason.dart';
import 'player_actions.dart';

/// ユースコーチの見立て(推定幅)から、伸びしろの言葉とおすすめを出す
/// (2026-11-25。数字の幅だけだと、取るか迷ったときの決め手が無かった)。
class IntakeAdvice {
  const IntakeAdvice._();

  /// 見立ての真ん中の潜在能力で、どこまで行けそうか。
  static String ceiling(int mid) {
    if (mid >= 80) return Tr.pick('スターになりうる', 'Could be a star');
    if (mid >= 70) return Tr.pick('一軍の主力になりうる', 'Could be a regular');
    if (mid >= 60) return Tr.pick('一軍の控えになりうる', 'Could make the squad');
    return Tr.pick('下の部で通用する程度', 'Lower-league level');
  }

  /// スカウトのおすすめの段(0: 見送り 1: 様子見 2: 取る 3: 必ず取る)。
  static int level(int mid) {
    if (mid >= 75) return 3;
    if (mid >= 65) return 2;
    if (mid >= 55) return 1;
    return 0;
  }

  static String recommendation(int mid) => switch (level(mid)) {
        3 => Tr.pick('必ず引き取りたい', 'Must sign'),
        2 => Tr.pick('引き取る価値あり', 'Worth signing'),
        1 => Tr.pick('枠が余れば', 'If there is room'),
        _ => Tr.pick('見送ってよい', 'Can let go'),
      };
}

/// シーズン終了時に一括生成されたユースインテーク候補を選抜する画面。
class YouthIntakeScreen extends StatelessWidget {
  const YouthIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final candidates = gameState.pendingYouthIntake;
    final slotsLeft =
        gameState.maxYouthProspects - gameState.save!.youthProspects.length;

    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('ユースインテーク', 'Youth intake'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick(
                        '今季のアカデミーから${candidates.length}名の新人が入団を希望しています。引き取る選手を選んでください(残り枠: ${slotsLeft.clamp(0, 999)})。',
                        "${candidates.length} youngsters from this year's academy intake want to join. Choose who you take on (places left: ${slotsLeft.clamp(0, 999)})."),
                    style: TextStyle(
                        fontSize: 12,
                        color: SemanticColors.subtleText(context)),
                  ),
                  // 枠が無いと「引き取る」が全員押せない。一覧の上に1回だけ出す。
                  if (slotsLeft <= 0 && candidates.isNotEmpty)
                    DisabledReason(
                      Tr.pick(
                          '昇格候補の枠がいっぱいです(${gameState.maxYouthProspects}人)。これ以上は引き取れません',
                          'Your academy is full (${gameState.maxYouthProspects}). You cannot take on anyone else'),
                      key: const ValueKey('intake-blocked'),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Text(
                        Tr.pick('選抜は完了しました', 'You have finished choosing')))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final p = candidates[i];
                      final range = ScoutingEngine.estimatedPotentialRange(
                        p,
                        scoutLevel: gameState.youthCoachJudgingLevel,
                      );
                      final mid = ((range.$1 + range.$2) / 2).round();
                      final advice = IntakeAdvice.level(mid);
                      final adviceColor = switch (advice) {
                        3 => SemanticColors.positive(context),
                        2 => SemanticColors.ink(context, Colors.green),
                        1 => SemanticColors.subtleText(context),
                        _ => SemanticColors.negative(context),
                      };
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          key: ValueKey('intake-${p.id}'),
                          // 押すと選手の詳しい画面(能力・得意な位置・人柄)。
                          onTap: () => openPlayerDetail(context, p.id),
                          leading: PlayerFaceAvatar(
                            playerId: p.id,
                            position: p.position,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(color: adviceColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  IntakeAdvice.recommendation(mid),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: adviceColor),
                                ),
                              ),
                            ],
                          ),
                          // 潜在能力をそのまま出していたが、これでは選抜に
                          // 判断が要らない(数字の大きい順に取るだけ)。
                          // スカウト候補と同じく見立て(推定幅)にする。
                          // ユースコーチの見極めが高いほど幅が狭くなる。
                          // 幅に加えて、伸びしろの言葉とおすすめを出す。
                          subtitle: Text(
                            Tr.pick(
                                '${p.age}歳・${p.position.label}・総合 ${p.overall}・伸びしろ: ${gameState.growthRoomWordFor(p)}(${IntakeAdvice.ceiling(mid)}。見立て ${range.$1}〜${range.$2})',
                                'Age ${p.age} • ${p.position.label} • overall ${p.overall} • room to grow: ${gameState.growthRoomWordFor(p)} (${IntakeAdvice.ceiling(mid)}; est. ${range.$1}-${range.$2})'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: Tr.pick('解雇', 'Release'),
                                onPressed: () =>
                                    _confirmRelease(context, p.id, p.name),
                              ),
                              FilledButton(
                                onPressed: slotsLeft <= 0
                                    ? null
                                    : () async {
                                        final ok = await gameState
                                            .keepYouthIntakePlayer(p.id);
                                        ok
                                            ? FeedbackService.success()
                                            : FeedbackService.error();
                                      },
                                child: Text(Tr.pick('引き取る', 'Take him on')),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(Tr.pick('完了', 'Done')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRelease(BuildContext context, String playerId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この新人を解雇しますか？', 'Turn this youngster away?')),
        content: Text(Tr.pick('$nameは入団せず解雇されます。この操作は元に戻せません。',
            '$name will not join the club. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().releaseYouthIntakePlayer(
                    playerId,
                  );
              FeedbackService.tap();
            },
            child: Text(Tr.pick('解雇する', 'Release him')),
          ),
        ],
      ),
    );
  }
}
