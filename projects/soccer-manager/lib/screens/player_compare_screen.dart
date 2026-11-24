import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../models/attributes.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/fm_panel.dart';
import '../widgets/player_face_avatar.dart';
import '../l10n/tr.dart';
import '../logic/economy_scale.dart';

/// 2人の選手を並べて比べる画面(FM の比較に寄せた。2026-11-25)。
///
/// 上に年齢・位置・総合・伸びしろ・年俸・契約・市場価値、その下に今季の
/// 成績、能力は1つずつの行(分類ごと)。良いほうの数字を色で示す。
/// 以前は攻撃・守備などのまとめた5つと年齢・年俸・市場価値だけだった。
class PlayerCompareScreen extends StatelessWidget {
  final String playerAId;
  final String playerBId;

  const PlayerCompareScreen({
    super.key,
    required this.playerAId,
    required this.playerBId,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    // 自軍だけを見ていると、市場やスカウト候補の選手を渡された瞬間に落ちる
    // (firstWhere が要素なしで投げる)。移籍で居なくなった選手でも同じ。
    final a = gameState.anyPlayerById(playerAId);
    final b = gameState.anyPlayerById(playerBId);
    if (a == null || b == null) {
      return Scaffold(
        appBar: AppBar(title: Text(Tr.pick('選手比較', 'Compare players'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              Tr.pick('比較する選手が見つかりませんでした。移籍などで居なくなった可能性があります。',
                  'One of the players could not be found. He may have moved on.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final stats = gameState.seasonStatsForAll([a.id, b.id]);
    final sa = stats[a.id] ?? const PlayerSeasonStats();
    final sb = stats[b.id] ?? const PlayerSeasonStats();
    final clubA = gameState.clubOfPlayer(a.id)?.name ??
        gameState.clubNameOf(a.id) ??
        Tr.pick('所属なし', 'Free agent');
    final clubB = gameState.clubOfPlayer(b.id)?.name ??
        gameState.clubNameOf(b.id) ??
        Tr.pick('所属なし', 'Free agent');
    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (a.position == Position.gk || b.position == Position.gk)
        AttributeCategory.goalkeeping,
    ];

    final basics = FmPanel(
      title: Tr.pick('基本', 'Basics'),
      padding: EdgeInsets.zero,
      child: Column(children: [
        _TextRow(label: Tr.pick('所属', 'Club'), left: clubA, right: clubB),
        _TextRow(
            label: Tr.pick('位置', 'Position'),
            left: a.position.label,
            right: b.position.label),
        _NumRow(
            label: Tr.pick('年齢', 'Age'),
            left: a.age,
            right: b.age,
            lowerIsBetter: true),
        _NumRow(label: Tr.pick('総合力', 'Overall'), left: a.overall, right: b.overall),
        // 伸びしろは見えている選手だけ(他クラブの選手は見立てが要る)。
        _NumRow(
          label: Tr.pick('伸びしろ', 'Room to grow'),
          left: gameState.growthRoomLevelFor(a) ?? -1,
          right: gameState.growthRoomLevelFor(b) ?? -1,
          neutral: gameState.growthRoomLevelFor(a) == null ||
              gameState.growthRoomLevelFor(b) == null,
          format: (v) => switch (v) {
            -1 => Tr.pick('分からない', 'Unknown'),
            0 => Tr.pick('ほぼ上限', 'Almost none'),
            1 => Tr.pick('少し', 'A little'),
            2 => Tr.pick('まだ伸びる', 'Some'),
            _ => Tr.pick('大きい', 'Plenty'),
          },
        ),
        _NumRow(
          label: Tr.pick('年俸', 'Salary'),
          left: annualFromWeekly(a.wage),
          right: annualFromWeekly(b.wage),
          lowerIsBetter: true,
          format: formatMoney,
        ),
        _TextRow(
          label: Tr.pick('契約', 'Contract'),
          left: a.isLoan ? Tr.pick('ローン', 'Loan') : ContractEngine.untilLabel(a.contractEndYear),
          right: b.isLoan ? Tr.pick('ローン', 'Loan') : ContractEngine.untilLabel(b.contractEndYear),
        ),
        _NumRow(
          label: Tr.pick('市場価値', 'Value'),
          left: a.marketValue,
          right: b.marketValue,
          format: formatMoney,
          neutral: true,
        ),
      ]),
    );
    final season = FmPanel(
      title: Tr.pick('今季の成績(リーグ戦)', 'This season (league)'),
      padding: EdgeInsets.zero,
      child: Column(children: [
        _NumRow(
            label: Tr.pick('出場', 'Appearances'),
            left: sa.appearances,
            right: sb.appearances),
        _NumRow(label: Tr.pick('得点', 'Goals'), left: sa.goals, right: sb.goals),
        _NumRow(
          label: Tr.pick('平均採点', 'Average rating'),
          left: ((sa.averageRating ?? 0) * 100).round(),
          right: ((sb.averageRating ?? 0) * 100).round(),
          format: (v) => v == 0 ? '—' : (v / 100).toStringAsFixed(2),
        ),
        _NumRow(
            label: Tr.pick('警告', 'Yellow cards'),
            left: sa.yellowCards,
            right: sb.yellowCards,
            lowerIsBetter: true),
      ]),
    );
    final attributePanels = [
      for (final c in categories)
        FmPanel(
          title: c.label,
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final k in c.keys)
              _NumRow(
                label: AttributeKeys.labelOf(k),
                left: a.attributeValue(k),
                right: b.attributeValue(k),
                dense: true,
              ),
          ]),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('選手比較', 'Compare players'))),
      body: LayoutBuilder(builder: (context, c) {
        final header = Row(
          children: [
            Expanded(child: _PlayerHeader(player: a, club: clubA)),
            const SizedBox(width: 8),
            Expanded(child: _PlayerHeader(player: b, club: clubB)),
          ],
        );
        if (c.maxWidth < 640) {
          return ListView(
            padding: const EdgeInsets.all(10),
            children: [header, const SizedBox(height: 8), basics, season, ...attributePanels],
          );
        }
        // 横画面: 左に基本と今季、右に能力(2列)。
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
                children: [header, const SizedBox(height: 8), basics, season],
              ),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(children: [
                          for (var i = 0; i < attributePanels.length; i += 2)
                            attributePanels[i],
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(children: [
                          for (var i = 1; i < attributePanels.length; i += 2)
                            attributePanels[i],
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final Player player;
  final String club;

  const _PlayerHeader({required this.player, required this.club});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlayerFaceAvatar(
          playerId: player.id,
          position: player.position,
          size: 40,
          highlighted: true,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                club,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: SemanticColors.subtleText(context), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 左の値・項目・右の値の1行。良いほう(大きい・[lowerIsBetter]なら小さい)
/// を色で示す。[neutral]なら色を付けない。
class _NumRow extends StatelessWidget {
  const _NumRow({
    required this.label,
    required this.left,
    required this.right,
    this.lowerIsBetter = false,
    this.neutral = false,
    this.dense = false,
    this.format,
  });

  final String label;
  final int left;
  final int right;
  final bool lowerIsBetter;
  final bool neutral;
  final bool dense;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    final leftWins =
        !neutral && (lowerIsBetter ? left < right : left > right);
    final rightWins =
        !neutral && (lowerIsBetter ? right < left : right > left);
    final win = SemanticColors.positive(context);
    Widget value(int v, bool wins, TextAlign align) => Expanded(
          flex: 3,
          child: Text(
            format?.call(v) ?? '$v',
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 12 : 13,
              fontWeight: wins ? FontWeight.bold : FontWeight.normal,
              color: wins ? win : null,
            ),
          ),
        );
    return _RowFrame(
      dense: dense,
      children: [
        value(left, leftWins, TextAlign.left),
        Expanded(
          flex: 4,
          child: Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, color: SemanticColors.subtleText(context))),
        ),
        value(right, rightWins, TextAlign.right),
      ],
    );
  }
}

/// 字だけの行(所属・位置・契約)。
class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.left, required this.right});

  final String label;
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5);
    return _RowFrame(children: [
      Expanded(
          flex: 3,
          child: Text(left,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      Expanded(
        flex: 4,
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: SemanticColors.subtleText(context))),
      ),
      Expanded(
          flex: 3,
          child: Text(right,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style)),
    ]);
  }
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.children, this.dense = false});

  final List<Widget> children;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 2.5 : 5),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(children: children),
    );
  }
}
