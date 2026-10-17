import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/game.dart';
import '../game/snapshot.dart';
import '../game/records.dart';
import 'art/career_chart.dart';

/// 成績画面: 通算・年度別の成績表・タイトル・ライバルとの対戦・総合評価の推移。
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${game.player.name} の成績')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [RecordsView(snapshot: PlayerSnapshot.fromGame(game))],
          ),
        ),
      ),
    );
  }
}

/// 成績の中身。成績画面とエンディングで共用する。
class RecordsView extends StatelessWidget {
  const RecordsView({super.key, required this.snapshot});
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rs = snapshot.records;
    if (rs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('まだ成績がありません。\n夏の大会(プロは10月のシーズン終了)のあとに記録されます。'),
        ),
      );
    }
    final pro = rs.where((r) => r.stage == Stage.pro).toList();
    final titles = [
      for (final r in rs)
        for (final t in r.titles) (r.age, t),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(records: rs, pro: pro),
        const SizedBox(height: 8),
        _Table(records: rs),
        if (titles.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Titles(titles: titles),
        ],
        const SizedBox(height: 8),
        _RivalCard(snapshot: snapshot),
        if (snapshot.overallHistory.length >= 2) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('総合評価の歩み',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  CareerChart(
                      history: snapshot.overallHistory,
                      proStartAge: snapshot.proStartAge),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.records, required this.pro});
  final List<SeasonRecord> records;
  final List<SeasonRecord> pro;

  @override
  Widget build(BuildContext context) {
    final isPro = pro.isNotEmpty;
    final rs = isPro ? pro : records;
    final l = totalOf(rs);
    final wins = rs.where((r) => r.champion).length;
    final titles = rs.fold<int>(0, (a, r) => a + r.titles.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isPro ? 'プロ通算 (${pro.length}年)' : 'アマチュア通算 (大会)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (l.hasBatting)
              Wrap(spacing: 20, runSpacing: 8, children: [
                _Stat('試合', '${l.games}'),
                _Stat('打率', fmtRate(l.battingAverage)),
                _Stat('安打', '${l.hits}'),
                _Stat('本塁打', '${l.homeRuns}'),
                _Stat('OPS', fmtRate(l.ops)),
              ]),
            if (l.hasBatting && l.hasPitching) const SizedBox(height: 10),
            if (l.hasPitching)
              Wrap(spacing: 20, runSpacing: 8, children: [
                _Stat('登板', '${l.starts}'),
                _Stat('勝敗', '${l.wins}勝${l.losses}敗'),
                _Stat('防御率', fmtEra(l.era)),
                _Stat('奪三振', '${l.strikeouts}'),
                _Stat('投球回', l.inningsText),
              ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.emoji_events,
                    size: 16, color: Color(0xFFF9A825)),
                label: Text(isPro ? 'リーグ優勝 $wins回' : '大会優勝 $wins回'),
              ),
              if (titles > 0)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.workspace_premium,
                      size: 16, color: Color(0xFFD4AF37)),
                  label: Text('タイトル $titles個'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.records});
  final List<SeasonRecord> records;

  @override
  Widget build(BuildContext context) {
    final bat = records.any((r) => r.line.hasBatting);
    final pit = records.any((r) => r.line.hasPitching);
    final cs = Theme.of(context).colorScheme;
    DataColumn col(String s, {bool num = false}) =>
        DataColumn(label: Text(s), numeric: num);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child:
                  Text('年度別成績', style: Theme.of(context).textTheme.titleSmall),
            ),
            SingleChildScrollView(
              key: const Key('records-table'),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 8,
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columns: [
                  col('年齢', num: true),
                  col('段階'),
                  col('結果'),
                  if (bat) ...[
                    col('試合', num: true),
                    col('打率', num: true),
                    col('本', num: true),
                    col('OPS', num: true)
                  ],
                  if (pit) ...[
                    col('登板', num: true),
                    col('勝敗'),
                    col('防御率', num: true),
                    col('奪三振', num: true)
                  ],
                  col('タイトル'),
                ],
                rows: [
                  for (final r in records)
                    DataRow(
                      color: r.champion
                          ? WidgetStatePropertyAll(
                              const Color(0xFFFFF8E1).withValues(alpha: 0.9))
                          : null,
                      cells: [
                        DataCell(Text('${r.age}')),
                        DataCell(Text(_stageShort(r.stage))),
                        DataCell(Text(
                          r.resultText,
                          style: r.champion
                              ? const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB8860B))
                              : null,
                        )),
                        if (bat) ...[
                          DataCell(Text(
                              r.line.hasBatting ? '${r.line.games}' : '-')),
                          DataCell(Text(fmtRate(r.line.battingAverage))),
                          DataCell(Text(
                              r.line.hasBatting ? '${r.line.homeRuns}' : '-')),
                          DataCell(Text(fmtRate(r.line.ops))),
                        ],
                        if (pit) ...[
                          DataCell(Text(
                              r.line.hasPitching ? '${r.line.starts}' : '-')),
                          DataCell(Text(r.line.hasPitching && r.isLeague
                              ? '${r.line.wins}-${r.line.losses}'
                              : '-')),
                          DataCell(Text(fmtEra(r.line.era))),
                          DataCell(Text(r.line.hasPitching
                              ? '${r.line.strikeouts}'
                              : '-')),
                        ],
                        DataCell(Text(
                            r.titles.isEmpty ? '' : r.titles.join('・'),
                            style: TextStyle(color: cs.tertiary))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stageShort(Stage s) => switch (s) {
        Stage.youth => '少年',
        Stage.juniorHigh => '中学',
        Stage.highSchool => '高校',
        Stage.pathChoice => '大学/社会人',
        Stage.pro => 'プロ',
        Stage.retired => '',
      };
}

class _Titles extends StatelessWidget {
  const _Titles({required this.titles});
  final List<(int, String)> titles;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('獲得したタイトル', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final (age, t) in titles)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.workspace_premium,
                      size: 16, color: Color(0xFFD4AF37)),
                  label: Text('$age歳 $t'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RivalCard extends StatelessWidget {
  const _RivalCard({required this.snapshot});
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rival = snapshot.rivalName;
    if (rival == null) return const SizedBox.shrink();
    final w = snapshot.rivalWins, l = snapshot.rivalLosses;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sports_kabaddi),
        title: Text('ライバル $rival'),
        subtitle: Text('通算 $w勝 $l敗'),
      ),
    );
  }
}
