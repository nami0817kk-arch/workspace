import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/game.dart';
import '../game/marks.dart';
import '../game/path.dart' show draftTeams;
import '../game/snapshot.dart';
import '../game/records.dart';
import '../game/rival_story.dart';
import '../game/world.dart';
import 'art/career_chart.dart';
import 'widgets.dart';

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
    final awards = [
      for (final r in rs)
        for (final t in r.awards) (r.age, t),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(records: rs, pro: pro),
        _Highlights(snapshot: snapshot),
        const SizedBox(height: 8),
        _Metrics(records: pro.isNotEmpty ? pro : rs, pro: pro.isNotEmpty),
        const SizedBox(height: 8),
        _Table(records: rs),
        if (titles.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Titles(titles: titles),
        ],
        if (pro.length >= 2) ...[
          const SizedBox(height: 8),
          _Grades(records: pro),
        ],
        if (pro.isNotEmpty && pro.last.rank != null) ...[
          const SizedBox(height: 8),
          _Standings(snapshot: snapshot, record: pro.last),
        ],
        if (careerHighs(pro.isNotEmpty ? pro : rs).isNotEmpty) ...[
          const SizedBox(height: 8),
          _Highs(highs: careerHighs(pro.isNotEmpty ? pro : rs)),
        ],
        if (awards.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Titles(titles: awards, heading: '表彰', icon: Icons.military_tech),
        ],
        if (snapshot.worldRecords.isNotEmpty) ...[
          const SizedBox(height: 8),
          _WorldCard(records: snapshot.worldRecords),
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
  const _Stat(this.label, this.value, {this.hint, this.small = false});
  final String label;
  final String value;

  /// 指標の意味(タップ・長押しで出る)。
  final String? hint;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: (small ? t.titleMedium : t.titleLarge)
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: t.bodySmall),
      ],
    );
    return hint == null
        ? body
        : Tooltip(
            message: hint!,
            triggerMode: TooltipTriggerMode.tap,
            child: body,
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
            if (isPro) ...[
              const SizedBox(height: 10),
              _Stat('通算収入', fmtSalary(careerEarnings(pro))),
            ],
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

/// 指標: 打率・本塁打だけでは見えない、出塁・長打・選球眼・投球の中身。
/// ラベルをタップすると意味が出る。
class _Metrics extends StatelessWidget {
  const _Metrics({required this.records, required this.pro});
  final List<SeasonRecord> records;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final l = totalOf(records);
    if (!l.hasBatting && !l.hasPitching) return const SizedBox.shrink();
    final chances = records.fold<int>(0, (a, r) => a + r.chances);
    final errors = records.fold<int>(0, (a, r) => a + r.errors);
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('metrics'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pro ? '指標(プロ通算)' : '指標(大会通算)', style: t.titleSmall),
            Text('項目をタップすると意味が出ます。100が平均の指標は、大きいほど良い。', style: t.bodySmall),
            if (l.hasBatting) ...[
              const SizedBox(height: 10),
              Text('打者', style: t.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 18, runSpacing: 8, children: [
                _Stat('出塁率', fmtRate(l.onBase),
                    small: true, hint: '出塁率: 打席のうち、塁に出た割合(安打+四球)。'),
                _Stat('長打率', fmtRate(l.slugging),
                    small: true, hint: '長打率: 1打数あたりの塁打。長打を打つ力。'),
                _Stat('OPS', fmtRate(l.ops),
                    small: true, hint: 'OPS: 出塁率+長打率。打者の総合力の目安。'),
                _Stat('OPS+', fmtPlus(l.opsPlus),
                    small: true,
                    hint: 'OPS+: リーグ平均(OPS .720)を100とした指標。120なら平均の2割増し。'),
                _Stat('ISO', fmtRate(l.isolatedPower),
                    small: true, hint: 'ISO: 長打率-打率。長打だけの力(.200超えは強打者)。'),
                _Stat('四球率', fmtPct(l.walkRate),
                    small: true, hint: '四球率: 打席のうち、四球を選んだ割合。'),
                _Stat('三振率', fmtPct(l.strikeoutRate),
                    small: true, hint: '三振率: 打席のうち、三振した割合。低いほど良い。'),
                _Stat('BB/K', fmt2(l.walkPerStrikeout),
                    small: true, hint: 'BB/K: 三振1つあたりの四球。1.0を超えると選球眼が良い。'),
                _Stat('打点', '${l.rbi}',
                    small: true, hint: '打点: 自分の打撃で返した走者の数。'),
                _Stat('盗塁', '${l.stolenBases}',
                    small: true, hint: '盗塁: 走力を生かして進んだ塁の数。'),
                _Stat('二塁打', '${l.doubles}', small: true),
                _Stat('三塁打', '${l.triples}', small: true),
                if (chances > 0)
                  _Stat('守備率', fmtRate(1 - errors / chances),
                      small: true,
                      hint: '守備率: 守備機会のうち、失策をしなかった割合。.990を超えると守備の名手。'),
                if (chances > 0)
                  _Stat('失策', '$errors',
                      small: true, hint: '失策: 守備でのミスの数。少ないほど良い。'),
              ]),
            ],
            if (l.hasPitching) ...[
              const SizedBox(height: 10),
              Text('投手', style: t.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 18, runSpacing: 8, children: [
                _Stat('WHIP', fmt2(l.whip),
                    small: true, hint: 'WHIP: 1回あたりに出した走者(安打+四球)。1.00未満なら超一流。'),
                _Stat('奪三振率', fmt2(l.strikeoutsPer9),
                    small: true, hint: '奪三振率: 9回あたりの三振。高いほど支配的。'),
                _Stat('与四球率', fmt2(l.walksPer9),
                    small: true, hint: '与四球率: 9回あたりの四球。低いほど制球が良い。'),
                _Stat('K/BB', fmt2(l.strikeoutPerWalk),
                    small: true, hint: 'K/BB: 四球1つあたりの三振。3.0を超えると制球・奪三振とも優秀。'),
                _Stat('被打率', fmtRate(l.battingAverageAgainst),
                    small: true, hint: '被打率: 対戦した打者(四球を除く)に打たれた割合。'),
                _Stat('被本塁打率', fmt2(l.homeRunsPer9),
                    small: true, hint: '被本塁打率: 9回あたりに打たれた本塁打。'),
                _Stat('勝率', fmtRate(l.winRate),
                    small: true, hint: '勝率: 勝ち ÷ (勝ち+負け)。'),
                _Stat('ERA+', fmtPlus(l.eraPlus),
                    small: true,
                    hint: 'ERA+: リーグ平均(防御率3.90)を100とした指標。大きいほど良い。'),
              ]),
            ],
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
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text('表は横にスクロールできます。行をタップすると、その年の詳しい成績。',
                  key: const Key('table-hint'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            SingleChildScrollView(
              key: const Key('records-table'),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
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
                    col('OPS', num: true),
                    col('OPS+', num: true),
                    col('打点', num: true),
                    col('盗塁', num: true),
                  ],
                  if (pit) ...[
                    col('登板', num: true),
                    col('勝敗'),
                    col('防御率', num: true),
                    col('ERA+', num: true),
                    col('WHIP', num: true),
                    col('奪三振', num: true)
                  ],
                  if (records.any((r) => r.stage == Stage.pro)) col('年俸'),
                  col('タイトル'),
                ],
                rows: [
                  for (final r in records)
                    DataRow(
                      onSelectChanged: (_) =>
                          _showSeason(context, r, all: records),
                      color: r.champion
                          ? WidgetStatePropertyAll(
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0x33FFC107)
                                  : const Color(0xE6FFF8E1))
                          : null,
                      cells: [
                        DataCell(Text('${r.age}',
                            style: r == records.last
                                ? const TextStyle(fontWeight: FontWeight.bold)
                                : null)),
                        DataCell(
                            Text(r.overseas ? 'プロ(米)' : _stageShort(r.stage))),
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
                          DataCell(Text(fmtPlus(r.line.opsPlus))),
                          DataCell(
                              Text(r.line.hasBatting ? '${r.line.rbi}' : '-')),
                          DataCell(Text(r.line.hasBatting
                              ? '${r.line.stolenBases}'
                              : '-')),
                        ],
                        if (pit) ...[
                          DataCell(Text(
                              r.line.hasPitching ? '${r.line.starts}' : '-')),
                          DataCell(Text(r.line.hasPitching && r.isLeague
                              ? '${r.line.wins}-${r.line.losses}'
                              : '-')),
                          DataCell(Text(fmtEra(r.line.era))),
                          DataCell(Text(fmtPlus(r.line.eraPlus))),
                          DataCell(Text(fmt2(r.line.whip))),
                          DataCell(Text(r.line.hasPitching
                              ? '${r.line.strikeouts}'
                              : '-')),
                        ],
                        if (records.any((r) => r.stage == Stage.pro))
                          DataCell(Text(fmtSalary(salaryOf(r)))),
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
}

String _stageShort(Stage s) => switch (s) {
      Stage.youth => '少年',
      Stage.juniorHigh => '中学',
      Stage.highSchool => '高校',
      Stage.pathChoice => '大学/社会人',
      Stage.pro => 'プロ',
      Stage.retired => '',
    };

/// 年ごとの評価(その年の成績から、ランクで)。
class _Grades extends StatelessWidget {
  const _Grades({required this.records});
  final List<SeasonRecord> records;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('grades'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('年ごとの評価', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 6, children: [
              for (final r in records)
                InkWell(
                  key: Key('grade-${r.age}'),
                  onTap: () => _showSeason(context, r, all: records),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    RankBadge(value: r.line.rating.round()),
                    const SizedBox(width: 4),
                    Text('${r.age}歳', style: t.bodySmall),
                  ]),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// ハイライトの回数(月間MVP・オールスター・表彰・日本一)。
class _Highlights extends StatelessWidget {
  const _Highlights({required this.snapshot});
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    int n(String key) =>
        snapshot.events.where((e) => e.text.contains(key)).length;
    final awards = snapshot.records.fold<int>(0, (a, r) => a + r.awards.length);
    final items = <(String, int)>[
      ('月間MVP', n('の月間MVP')),
      ('オールスター', n('オールスターに選出')),
      ('怪我', snapshot.events.where((e) => e.kind == 'injury').length),
      ('表彰', awards),
    ].where((e) => e.$2 > 0).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(key: const Key('highlights'), spacing: 6, children: [
        for (final (label, count) in items)
          Chip(
              visualDensity: VisualDensity.compact,
              avatar: label == '怪我'
                  ? const Icon(Icons.healing,
                      size: 16, color: Color(0xFFE53935))
                  : const Icon(Icons.star, size: 16, color: Color(0xFFD4AF37)),
              label: Text('$label $count回')),
      ]),
    );
  }
}

/// 直近のプロのシーズンの順位表。
class _Standings extends StatelessWidget {
  const _Standings({required this.snapshot, required this.record});
  final PlayerSnapshot snapshot;
  final SeasonRecord record;

  @override
  Widget build(BuildContext context) {
    final team = (record.overseas ? snapshot.overseasTeam : snapshot.proTeam) ??
        'あなたのチーム';
    final rows = standingsOf(
        team: team,
        rank: record.rank!,
        wins: record.teamWins,
        losses: record.teamLosses,
        age: record.age,
        league: draftTeams);
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('standings'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${record.age}歳シーズンの順位表', style: t.titleSmall),
            const SizedBox(height: 6),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}')),
                  Expanded(
                      child: Text(rows[i].team,
                          style: rows[i].mine
                              ? t.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)
                              : t.bodyMedium)),
                  Text('${rows[i].wins}勝${rows[i].losses}敗'),
                ]),
              ),
            if (record.months.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('月ごとの成績', style: t.titleSmall),
              for (var i = 0; i < record.months.length; i++)
                Text(record.months[i],
                    style: t.bodySmall, key: Key('month-row-$i')),
            ],
          ],
        ),
      ),
    );
  }
}

/// キャリアハイ(項目ごとに一番良かった年)。
class _Highs extends StatelessWidget {
  const _Highs({required this.highs});
  final List<({String label, String value, int age})> highs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('career-highs'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('キャリアハイ', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 18, runSpacing: 6, children: [
              for (final h in highs)
                Text('${h.label} ${h.value}(${h.age}歳)', style: t.bodyMedium),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 1年ぶんの成績の詳しい中身(表の行をタップ)。
void _showSeason(BuildContext context, SeasonRecord start,
    {List<SeasonRecord> all = const []}) {
  final list = all.isEmpty ? [start] : all;
  showDialog<void>(
    context: context,
    builder: (ctx) {
      var i = list.indexOf(start).clamp(0, list.length - 1);
      return StatefulBuilder(builder: (ctx, setState) {
        final r = list[i];
        final lines = <String>[
          '${r.age}歳 ${r.overseas ? 'プロ(米)' : _stageShort(r.stage)}  ${r.resultText}',
          if (r.isLeague) 'チーム ${r.teamWins}勝${r.teamLosses}敗 ${r.rank}位',
          if (describeLine(r.line).isNotEmpty) describeLine(r.line),
          if (r.line.hasBatting)
            'OPS+ ${fmtPlus(r.line.opsPlus)} ・ 打点 ${r.line.rbi} ・ 盗塁 ${r.line.stolenBases}',
          if (r.chances > 0)
            '守備: 守備機会${r.chances} ・ 失策${r.errors} ・ 守備率${fmtRate(r.fieldingPct)}',
          if (r.line.hasPitching)
            'ERA+ ${fmtPlus(r.line.eraPlus)} ・ WHIP ${fmt2(r.line.whip)} ・ 奪三振 ${r.line.strikeouts}',
          if (r.titles.isNotEmpty) 'タイトル: ${r.titles.join('・')}',
          if (r.awards.isNotEmpty) '表彰: ${r.awards.join('・')}',
          if (r.rivalWon != null) 'ライバル対決: ${r.rivalWon! ? '勝ち' : '負け'}',
          if (r.stage == Stage.pro) '年俸 ${fmtSalary(salaryOf(r))}',
        ];
        return AlertDialog(
          key: const Key('season-detail'),
          title: Row(children: [
            IconButton(
              key: const Key('season-prev'),
              tooltip: '前の年',
              onPressed: i > 0 ? () => setState(() => i--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
                child: Text('${r.age}歳のシーズン', textAlign: TextAlign.center)),
            IconButton(
              key: const Key('season-next'),
              tooltip: '次の年',
              onPressed: i < list.length - 1 ? () => setState(() => i++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(l)),
                if (r.months.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('月ごとの成績',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final m in r.months)
                    Text(m, style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))
          ],
        );
      });
    },
  );
}

class _Titles extends StatelessWidget {
  const _Titles(
      {required this.titles,
      this.heading = '獲得したタイトル',
      this.icon = Icons.workspace_premium});
  final List<(int, String)> titles;
  final String heading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final (age, t) in titles)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
                  label: Text('$age歳 $t'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 日本代表として出た世界大会の一覧。
class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.records});
  final List<WorldRecord> records;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: const Key('world-records'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.public, size: 18, color: Color(0xFFD32F2F)),
              const SizedBox(width: 6),
              Text('世界大会(日本代表)', style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            for (final r in records)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${r.age}歳  ${r.eventName}  '),
                  TextSpan(
                      text: r.resultText,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: r.champion
                              ? const Color(0xFFB8860B)
                              : cs.onSurface)),
                  if (r.lostTo != null) TextSpan(text: '(${r.lostTo}に敗れる)'),
                  if (describeLine(r.line).isNotEmpty)
                    TextSpan(
                        text: '\n${describeLine(r.line)}',
                        style: Theme.of(context).textTheme.bodySmall),
                ])),
              ),
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
        subtitle: Text(
            '通算 $w勝 $l敗'
            '${snapshot.rivalTalent == null ? '' : '\n${rivalStatus(storyOf(rival, snapshot.rivalTalent!).avoiding(snapshot.proTeam), snapshot.age)}'}'
            '${snapshot.rivalTalent == null ? '' : (rivalStatsOf(storyOf(rival, snapshot.rivalTalent!), snapshot.age) == null ? '' : '\n${rivalStatsOf(storyOf(rival, snapshot.rivalTalent!), snapshot.age)}')}',
            key: const Key('rival-status')),
        isThreeLine: snapshot.rivalTalent != null,
      ),
    );
  }
}
