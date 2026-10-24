import 'package:flutter/material.dart' hide Action, Route;
import 'package:flutter/services.dart';

import '../game/advice.dart';
import '../game/build.dart';
import '../game/epilogue.dart';
import '../game/game.dart';
import '../game/life.dart';
import '../game/match.dart';
import '../game/money.dart';
import '../game/path.dart';
import '../game/player.dart';
import '../game/season.dart';
import 'art/court.dart';
import 'art/title_art.dart';
import 'art/growth_chart.dart';
import 'controller.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'labels.dart';

/// 局面(季節 / 進路 / 引退)に合わせて画面を切り替える。
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.player.name}  ${game.player.age}歳'),
        actions: [
          IconButton(
            tooltip: '殿堂・実績',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(controller: controller))),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(money: controller.money))),
          ),
          if (game.phase != Phase.retired)
            IconButton(
              tooltip: '最初からやり直す',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _confirmRestart(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch (game.phase) {
              Phase.season => _SeasonView(controller: controller, game: game),
              Phase.halftime =>
                _HalftimeView(controller: controller, game: game),
              Phase.clutch => _ClutchView(controller: controller, game: game),
              Phase.event => _EventView(controller: controller, game: game),
              Phase.path => _PathView(controller: controller, game: game),
              Phase.retired => _EndingView(controller: controller, game: game),
            },
          ),
        ),
      ),
    );
  }
}

extension on GameScreen {
  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('最初からやり直しますか?'),
        content: const Text('いまの選手の記録は消えます(殿堂には残りません)。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('やり直す')),
        ],
      ),
    );
    if (ok == true) controller.reset();
  }
}

const _seasonNames = ['春', '夏', '秋', '冬'];

// ── 育成(季節) ──

class _SeasonView extends StatelessWidget {
  const _SeasonView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final g = game;
    final cond = g.condition;
    final summer = g.slot == 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: g),
        const SizedBox(height: 12),
        _PlayerCard(game: g),
        const SizedBox(height: 12),
        _GoalCard(controller: c, game: g),
        const SizedBox(height: 12),
        if (c.pathMessage != null) ...[
          _Note(text: c.pathMessage!),
          const SizedBox(height: 12),
        ],
        if (c.lastTournament != null) ...[
          _TournamentCard(
              result: c.lastTournament!,
              winter: c.lastTournamentWinter,
              honors: game.lastHonors),
          const SizedBox(height: 12),
        ],
        if (c.recent.isNotEmpty) ...[
          _RecentCard(lines: c.recent),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_seasonNames[g.slot]}の過ごし方',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (summer || (g.slot == 3 && g.hasWinterCup))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(summer ? 'この季節に大会がある。' : 'この季節に冬の全国選手権がある。'),
                  ),
                const SizedBox(height: 12),
                const Text('重点にする能力  (★ ＝ いま伸ばすのがおすすめ)'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final a in Ability.values)
                      ChoiceChip(
                        label: Text(a == recommendedFocus(g.player)
                            ? '★${a.label}'
                            : a.label),
                        selected: c.focus == a,
                        onSelected: (_) => c.setFocus(a),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('勝負どころの方針'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('その場で選ぶ'),
                      selected: c.askClutch,
                      onSelected: (_) => c.setAskClutch(),
                    ),
                    ChoiceChip(
                      label: const Text('おまかせ'),
                      selected: !c.askClutch && c.clutchPolicy == null,
                      onSelected: (_) => c.setClutchPolicy(null),
                    ),
                    for (final k in Clutch.values)
                      ChoiceChip(
                        label: Text(k.label),
                        selected: c.clutchPolicy == k,
                        onSelected: (_) => c.setClutchPolicy(k),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final a in Action.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ActionButton(
                      action: a,
                      recommended: a == recommendedAction(g),
                      enabled: canChoose(a, cond),
                      rut: g.isRut(a),
                      onPressed: () => c.play(a),
                    ),
                  ),
                OutlinedButton(
                  onPressed: c.autoYear,
                  child: const Text('おすすめで1年進める'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => c.autoYears(3),
                  child: const Text('おすすめで3年進める'),
                ),
              ],
            ),
          ),
        ),
        if ((g.canRecover && c.money != null) || c.recoverMessage != null) ...[
          const SizedBox(height: 12),
          _RecoverCard(controller: c, game: g),
        ],
        if (g.rival.activeAt(g.player.age)) ...[
          const SizedBox(height: 12),
          _RivalCard(game: g),
        ],
        const SizedBox(height: 12),
        _AbilityCard(game: g),
        const SizedBox(height: 12),
        _GrowthCard(game: g),
        if (g.canGoAbroad) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: c.goAbroad,
            child: const Text('海外に挑戦する'),
          ),
        ],
        if (g.track == Track.pro) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmRetire(context, c),
            child: const Text('現役を引退する'),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRetire(BuildContext context, GameController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('引退しますか?'),
        content: const Text('この選手の物語は、ここで終わります。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('引退する')),
        ],
      ),
    );
    if (ok == true) c.retire();
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final cond = game.condition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trackLabel(game)}  ${game.number > 0 ? '#${game.number}  ' : ''}${p.position.label}  '
                '${p.heightCm.toStringAsFixed(1)}cm  総合 ${p.overall.round()}'),
            if (buildOf(p) != null)
              Text('ビルド: ${buildOf(p)!.label}',
                  style: const TextStyle(fontSize: 12)),
            if (p.age <= 17)
              Text(
                  '生活習慣: ${game.habit >= 6 ? '良い' : game.habit < 0 ? '乱れ気味' : 'ふつう'}  '
                  '(身長の伸び ${habitHeightMultiplier(game.habit) >= 1 ? '+' : ''}${((habitHeightMultiplier(game.habit) - 1) * 100).round()}%)',
                  style: const TextStyle(fontSize: 12)),
            if (game.track == Track.pro && game.salary > 0)
              Text(
                  '年俸 ${moneyLabel(game.salary)}'
                  '${game.sponsor > 0 ? '  スポンサー 年${moneyLabel(game.sponsor)}' : ''}',
                  style: const TextStyle(fontSize: 12)),
            if (game.track == Track.school && p.age >= 15 ||
                game.track == Track.university ||
                game.track == Track.corporate)
              Text('プロ契約の見込み: ${game.outlook.label}  (評価点 ${game.offerNow.round()})',
                  style: const TextStyle(fontSize: 12)),
            if (p.traits.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in p.traits)
                    Tooltip(
                      message: t.description,
                      child: Chip(
                        label: Text(t.label),
                        visualDensity: VisualDensity.compact,
                        // 明るい地に濃い字(ダークテーマでも読める)。
                        labelStyle: const TextStyle(color: Colors.black87),
                        backgroundColor: t.positive
                            ? Colors.orange.shade200
                            : Colors.blueGrey.shade200,
                      ),
                    ),
                ],
              ),
            ],
            if (p.skills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final k in p.skills)
                    Tooltip(
                      message: k.description,
                      child: Chip(
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(k.label),
                        labelStyle: const TextStyle(color: Colors.black87),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.amber.shade200,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _Meter(label: '疲れ', value: cond.fatigue, bad: true),
            _Meter(label: '気持ち', value: cond.morale),
            _Meter(label: 'チーム', value: game.teamwork),
            _Meter(label: 'コーチ', value: game.coachBond),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('くわしく', style: TextStyle(fontSize: 12)),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                expandedAlignment: Alignment.centerLeft,
                children: [
                  Text('持ち味: ${p.position.perk}',
                      style: const TextStyle(fontSize: 12)),
                  if (buildOf(p) != null)
                    Text('ビルド: ${buildOf(p)!.build.description}',
                        style: const TextStyle(fontSize: 12)),
                  if (game.track == Track.pro && game.draftPick > 0)
                    Text(draftLabel(game.draftPick),
                        style: const TextStyle(fontSize: 12)),
                  if (game.track == Track.pro && game.salary > 0)
                    Text('これまでの収入 ${moneyLabel(game.totalEarnings)}',
                        style: const TextStyle(fontSize: 12)),
                  if (game.mate.isNotEmpty || game.coachLabel.isNotEmpty)
                    Text(
                        'コーチ: ${game.coachLabel.isEmpty ? '-' : game.coachLabel}  /  仲間: ${game.mate.isEmpty ? '-' : game.mate}',
                        style: const TextStyle(fontSize: 12)),
                  if (game.schoolLabel.isNotEmpty)
                    Text(
                        '環境: ${game.schoolLabel} (大会の味方の強さ ${game.schoolBonus >= 0 ? '+' : ''}${game.schoolBonus.toStringAsFixed(0)})',
                        style: const TextStyle(fontSize: 12)),
                  Text(
                      'チームワーク: 味方の強さ ${game.teamBonus >= 0 ? '+' : ''}${game.teamBonus.toStringAsFixed(1)} (交流・練習試合で上がる)',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (cond.injured)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${cond.injuryName.isEmpty ? '怪我' : cond.injuryName}で療養中(あと${cond.injuredTerms}ターン)',
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 過ごし方のボタン。おすすめは濃く塗って「おすすめ」と添える。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.recommended,
    required this.enabled,
    required this.rut,
    required this.onPressed,
  });
  final Action action;
  final bool recommended;
  final bool enabled;
  final bool rut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(recommended ? '${action.label}  (おすすめ)' : action.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (rut)
          Text('マンネリ気味(伸びが少し落ちる)',
              style: TextStyle(
                  fontSize: 11,
                  color: recommended ? Colors.white : const Color(0xFFC62828))),
        Text(action.description, style: const TextStyle(fontSize: 12)),
      ],
    );
    final cb = enabled ? onPressed : null;
    final withIcon = _WithIcon('assets/art/icons/act_${action.name}.png', child);
    return recommended
        ? FilledButton(onPressed: cb, child: withIcon)
        : FilledButton.tonal(onPressed: cb, child: withIcon);
  }
}

/// ボタンの左に置く絵(Gemini で生成した 192px の PNG)。無ければ何も出さず、文字だけにする。
class _WithIcon extends StatelessWidget {
  const _WithIcon(this.asset, this.child);
  final String asset;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Image.asset(
            asset,
            width: 36,
            height: 36,
            errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      );
}

/// 今年の目標。まだ選んでいなければ2つの候補を出す。
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    if (g.goal != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('今年の目標', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(g.goal!.label, style: const TextStyle(fontSize: 16)),
              Text(g.goalProgress ?? '', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
    if (g.goalOptions.isEmpty || g.slot > 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今年の目標を選ぼう(年末に判定)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < g.goalOptions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => controller.adoptGoal(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${g.goalOptions[i].stretch ? '【挑戦】' : '【確実】'}${g.goalOptions[i].label}',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      Text(g.goalOptions[i].rewardText,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 動画を見て元気になる。広告を消した人は動画なしで使える。1ターンに1回。
class _RecoverCard extends StatelessWidget {
  const _RecoverCard({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final needsAd = c.money?.recoverNeedsAd ?? true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (game.canRecover && c.money != null)
              OutlinedButton.icon(
                onPressed: c.recoverBusy ? null : c.recover,
                icon: Icon(needsAd
                    ? Icons.smart_display_outlined
                    : Icons.favorite_border),
                label: Text(c.recoverBusy
                    ? '読み込み中…'
                    : needsAd
                        ? '動画を見て元気になる'
                        : '元気になる'),
              ),
            if (game.canRecover && c.money != null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('疲れ -40 / 気持ち +10 / 怪我が1ターン早く治る(1ターンに1回)',
                    style: TextStyle(fontSize: 12)),
              ),
            if (c.recoverMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(c.recoverMessage!),
              ),
          ],
        ),
      ),
    );
  }
}

/// ライバルの紹介と通算成績。
class _RivalCard extends StatelessWidget {
  const _RivalCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final r = game.rival;
    final level = r.levelAt(game.league, game.player.age);
    final mine = game.player.overall.round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ライバル', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(r.name, style: const TextStyle(fontSize: 18)),
            Text('通算 ${r.wins}勝${r.losses}敗  /  強さの目安 $level (自分 $mine)'),
            const Text('大会の準決勝あたりで立ちはだかる。',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// 能力の重みの印。無印は総合評価に効かない。
String _mark(int? w) => switch (w) {
      null => '',
      >= 3 => '◎',
      2 => '○',
      _ => '△',
    };

/// 成長の軌跡(総合評価と身長の推移)。
class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('成長の軌跡  (太線: 総合 / 細線: 身長)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GrowthChart(points: game.growthLog),
            ],
          ),
        ),
      );
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('能力  (◎○△ ＝ ${p.position.label} で効く度合い)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // 身長も能力の1つ(総合評価に入る。素質=ポテンシャルとは別)。
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                      width: 124,
                      child: Text('身長 ${_mark(heightWeightOf(p.position))}')),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (p.heightCm / 220).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text('${p.heightCm.round()}cm',
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            for (final a in Ability.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                        width: 124,
                        child: Text('${a.label} ${_mark(weightsOf(p.position)[a])}')),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: p.of(a) / abilityCap,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text('${p.of(a)} ${rankOf(p.of(a))}',
                          textAlign: TextAlign.right),
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

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.bad = false});
  final String label;
  final int value;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final warn = bad ? value >= 70 : value < 35;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              color: warn ? Colors.red : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// 大会の結果。試合ごとに ○● と得点・個人成績・流れの一言を並べる。
class _TournamentCard extends StatelessWidget {
  const _TournamentCard(
      {required this.result, required this.winter, this.honors = const []});
  final TournamentResult result;
  final bool winter;
  final List<String> honors;

  @override
  Widget build(BuildContext context) {
    final t = result;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: t.champion ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${tournamentName(t.league, winter)}  '
                '${t.wins}勝${t.games - t.wins}敗${t.champion ? '  優勝!' : ''}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (honors.isNotEmpty)
              Text('表彰: ${honors.join('・')}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
            if (t.award != null)
              Text('個人賞: ${t.award}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
            Text('実績 ${t.achievement.round()}(${achievementWord(t.achievement)})  '
                '平均 ${t.ppg.toStringAsFixed(1)}点 ${t.rpg.toStringAsFixed(1)}R ${t.apg.toStringAsFixed(1)}A',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (t.league.playoffRounds > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    'レギュラーシーズン ${t.regularWins}勝${t.league.rounds - t.regularWins}敗'
                    '${t.reachedPlayoffs ? '  →  プレーオフ ${t.playoffWins}勝${t.playoffMatches.length - t.playoffWins}敗' : '  (プレーオフ進出ならず。${t.league.qualifyWins}勝が必要)'}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            for (var i = 0; i < t.matches.length; i++)
              _MatchRow(index: i, m: t.matches[i], league: t.league),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.index, required this.m, required this.league});
  final int index;
  final MatchResult m;
  final League league;

  @override
  Widget build(BuildContext context) {
    final story = matchStory(m);
    final color = m.won ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(m.won ? '勝' : '負',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${league.playoffRounds > 0 && index >= league.rounds ? roundLabelOf(league, index) : '${index + 1}試合目'}  ${m.teamScore}-${m.oppScore}'
                    '${m.opponent.isEmpty ? '' : '  vs ${m.vsRival ? 'ライバル ' : ''}${m.opponent}'}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('得点${m.points} リバウンド${m.rebounds} アシスト${m.assists}'
                    '${m.steals > 0 ? ' スティール${m.steals}' : ''}'
                    '${m.blocks > 0 ? ' ブロック${m.blocks}' : ''}'
                    '${m.threes > 0 ? ' 3P${m.threes}本' : ''}'
                    '${m.clutch == null ? '' : '  勝負どころ:${m.clutch!.label}${m.clutchSuccess == true ? '成功' : '失敗'}'}',
                    style: const TextStyle(fontSize: 12)),
                if (story != null)
                  Text(story,
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('いまの結果',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(l),
                ),
            ],
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
      );
}

// ── ハーフタイム ──

class _HalftimeView extends StatelessWidget {
  const _HalftimeView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final run = game.run!;
    final h = run.pendingHalf!;
    final m = h.margin;
    final situation = m == 0
        ? '同点で折り返した。'
        : m > 0
            ? '$m点リードで折り返した。'
            : '${-m}点ビハインドで折り返した。';
    final rec = bestHalftime(game.player, h);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: game, height: 110, versus: h.vsRival),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ハーフタイム  ${run.league.label} ${run.roundLabel(run.round)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (h.opponent.isNotEmpty)
                  Text(h.vsRival
                      ? '相手: ライバル ${h.opponent}  (通算 ${game.rival.wins}勝${game.rival.losses}敗)'
                      : '相手: ${h.opponent}'),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      h.foulTrouble
                          ? 'ファウル: ${h.fouls}  ファウルトラブル!  強く当たる作戦は退場の危険'
                          : 'ファウル: ${h.fouls}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: h.foulTrouble ? FontWeight.bold : FontWeight.normal)),
                ),
                if (run.streak != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '勢い: ${run.streak > 0 ? '${run.streak}連勝中' : '${-run.streak}連敗中'}  '
                        '(味方の強さ ${run.momentum >= 0 ? '+' : ''}${run.momentum.toStringAsFixed(1)})',
                        style: const TextStyle(fontSize: 12)),
                  ),
                if (h.style != OppStyle.balanced)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('持ち味: ${h.style.label}\n${h.style.description}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                if (run.scout > 0 && h.style != OppStyle.balanced)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('分析済み: 相性の良い作戦の効きが上がる',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 8),
                Text(_scoreRow('自チーム', h.teamQuarters, h.team)),
                Text(_scoreRow('相手    ', h.oppQuarters, h.opp)),
                const SizedBox(height: 8),
                Text(situation,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('後半の作戦を選ぼう。'),
                const SizedBox(height: 12),
                for (final k in Halftime.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () => controller.playHalftime(k),
                      child: _WithIcon(
                        'assets/art/icons/half_${k.name}.png',
                        Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(k == rec ? '${k.label}  (おすすめ)' : k.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(k.description,
                              style: const TextStyle(fontSize: 12)),
                          if (h.style.fit(k, game.player) >= 0.5)
                            const Text('相手との相性: 良い',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold))
                          else if (h.style.fit(k, game.player) <= -0.5)
                            const Text('相手との相性: 悪い',
                                style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (controller.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: controller.recent),
        ],
        if (run.matches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: [
            'ここまでの試合',
            for (var i = 0; i < run.matches.length; i++)
              matchLine(i, run.matches[i].won, run.matches[i].teamScore,
                  run.matches[i].oppScore, run.matches[i].points,
                  run.matches[i].rebounds, run.matches[i].assists,
                  opponent: run.matches[i].opponent,
                  rival: run.matches[i].vsRival,
                  fouls: run.matches[i].fouls,
                  fouledOut: run.matches[i].fouledOut),
          ]),
        ],
      ],
    );
  }
}

// ── 勝負どころ ──

String _scoreRow(String label, List<int> q, int total) =>
    '$label  ${q.join(' - ')}  計 $total';

class _ClutchView extends StatelessWidget {
  const _ClutchView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final run = game.run!;
    final s = run.pending!;
    final info = game.clutchInfo!;
    final m = s.margin;
    final situation = m == 0
        ? '同点。残りはあと1回の攻防。'
        : m > 0
            ? '$m点リード。守り切れば勝ち。'
            : '${-m}点ビハインド。決めれば逆転だ。';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: game, height: 110, versus: s.vsRival),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('勝負どころ!  ${run.league.label} ${run.roundLabel(run.round)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (s.opponent.isNotEmpty)
                  Text(s.vsRival
                      ? '相手: ライバル ${s.opponent}  (通算 ${game.rival.wins}勝${game.rival.losses}敗)'
                      : '相手: ${s.opponent}'),
                const SizedBox(height: 8),
                Text(_scoreRow('自チーム', s.teamQuarters, s.team)),
                Text(_scoreRow('相手    ', s.oppQuarters, s.opp)),
                const SizedBox(height: 8),
                Text(situation,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (s.timeout)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('タイムアウト中: +5%',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else if (run.timeouts > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: controller.useTimeout,
                      child: Text('タイムアウトを取る(残り${run.timeouts}回・+5%)'),
                    ),
                  ),
                for (final k in Clutch.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () => controller.playClutch(k),
                      child: _WithIcon(
                        'assets/art/icons/clutch_${k.name}.png',
                        Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${k.label}  成功率 ${(info.chances[k]! * 100).round()}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          if (game.player.skills.any((s) => s.clutchBonus(k) > 0))
                            const Text('得意技が効く',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(k.description,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (controller.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: controller.recent),
        ],
        if (run.matches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: [
            'ここまでの試合',
            for (var i = 0; i < run.matches.length; i++)
              matchLine(i, run.matches[i].won, run.matches[i].teamScore,
                  run.matches[i].oppScore, run.matches[i].points,
                  run.matches[i].rebounds, run.matches[i].assists,
                  opponent: run.matches[i].opponent,
                  rival: run.matches[i].vsRival,
                  fouls: run.matches[i].fouls,
                  fouledOut: run.matches[i].fouledOut),
          ]),
        ],
      ],
    );
  }
}

// ── 出来事 ──

class _EventView extends StatelessWidget {
  const _EventView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final e = game.pendingEvent!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtHeader(game: game, height: 110),
        const SizedBox(height: 12),
        if (controller.pathMessage != null) ...[
          _Note(text: controller.pathMessage!),
          const SizedBox(height: 12),
        ],
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(game.fill(e.body)),
                const SizedBox(height: 16),
                for (var i = 0; i < e.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () => controller.chooseEvent(i),
                      child: Text(e.options[i].label),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (controller.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentCard(lines: controller.recent),
        ],
        const SizedBox(height: 12),
        _PlayerCard(game: game),
        const SizedBox(height: 12),
        _AbilityCard(game: game),
      ],
    );
  }
}

// ── 進路 ──

class _PathView extends StatelessWidget {
  const _PathView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final c = controller;
    final first = !g.secondChance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ArtBanner('assets/art/path.jpg'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first ? '卒業、そして進路' : '卒業のとき',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(first
                    ? '高校を卒業する。スカウトは、能力と実績と身長を見ている。'
                    : '最後の挑戦。プロ契約を取れなければ、競技人生はここまで。'),
                const SizedBox(height: 8),
                Text('総合 ${g.player.overall.round()} / '
                    '身長 ${g.player.heightCm.toStringAsFixed(1)}cm / '
                    '実績 ${g.achievement.round()}(${achievementWord(g.achievement)})'),
                const SizedBox(height: 8),
                Text('プロ契約の評価点 ${g.offerNow.round()}  →  見込み: ${g.outlook.label}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(g.outlook.description, style: const TextStyle(fontSize: 12)),
                const Text('(70点以上なら確実、35点未満は難しい。間は運しだい)',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        if (g.proRejected) ...[
          const SizedBox(height: 12),
          const _Note(text: 'プロ契約には届かなかった。大学か実業団で力をつけよう。'),
        ],
        const SizedBox(height: 12),
        for (final r in g.availableRoutes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              onPressed: () => c.chooseRoute(r),
              child: Text(r.label),
            ),
          ),
        TextButton(
          onPressed: c.giveUp,
          child: const Text('競技の道を離れる'),
        ),
      ],
    );
  }
}

// ── エンディング ──

class _EndingView extends StatelessWidget {
  const _EndingView({required this.controller, required this.game});
  final GameController controller;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final p = g.player;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ArtBanner(gloriousEnding(g)
            ? 'assets/art/ending_glory.jpg'
            : 'assets/art/ending_quiet.jpg'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.name}の物語',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('称号「${careerTitle(g)}」  (${g.difficulty.label})${g.number > 0 ? '\n背番号${g.number}${retiredNumber(g) ? '(永久欠番)' : ''}' : ''}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                for (final line in epilogueLines(g))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line),
                  ),
                const Divider(height: 24),
                Text('最終身長 ${p.heightCm.toStringAsFixed(1)}cm / '
                    'ポジション ${p.position.label} / 総合 ${p.overall.round()}'),
                if (g.rival.games > 0)
                  Text('宿敵 ${g.rival.name}との通算: ${g.rival.wins}勝${g.rival.losses}敗'),
                Text('通算 ${g.totalGames}試合 平均${g.careerPpg.toStringAsFixed(1)}得点'
                    ' / 優勝 ${g.titles}回 / 個人賞 ${g.awardCount}回'),
                Text('通算 ${g.totalPoints}得点 ${g.totalRebounds}リバウンド ${g.totalAssists}アシスト'),
                Text('スティール ${g.totalSteals} / ブロック ${g.totalBlocks} / 3P ${g.totalThrees}本'),
                if (g.careerHigh != null)
                  Text('キャリアハイ ${g.careerHigh!.points}得点(${g.careerHigh!.age}歳)'),
                if (g.abroad) const Text('海外プロでプレーした。'),
                if (p.traits.isNotEmpty)
                  Text('特性: ${p.traits.map((t) => t.label).join('・')}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _GrowthCard(game: g),
        if (controller.newlyUnlocked.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('実績解除!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final a in controller.newlyUnlocked)
                    Text('${a.title}: ${a.description}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('年ごとの成績',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (final r in g.records)
                  Text('${r.age}歳 ${leagueLabel(r.league)}${r.winter ? '(冬)' : ''} '
                      '${r.wins}勝${r.games - r.wins}敗'
                      '${r.champion ? ' 優勝' : ''}${r.award == null ? '' : ' [${r.award}]'}  '
                      '${r.ppg.toStringAsFixed(1)}点 '
                      '${r.rpg.toStringAsFixed(1)}R '
                      '${r.apg.toStringAsFixed(1)}A'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Clipboard.setData(ClipboardData(text: shareText(g)));
              messenger.showSnackBar(
                  const SnackBar(content: Text('結果をコピーした。好きな場所に貼り付けて共有できる。')));
            } catch (_) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('コピーできなかった。')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('結果をコピー'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: controller.reset,
          child: const Text('新しい選手を育てる'),
        ),
      ],
    );
  }
}
