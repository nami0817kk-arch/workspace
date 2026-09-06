import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/models.dart';
import 'format.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _offlineShown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeShowOfflineGain();
  }

  void _maybeShowOfflineGain() {
    final gain = widget.controller.offlineGain;
    if (_offlineShown || gain < 1) return;
    _offlineShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('おかえりなさい'),
          content: Text('留守の間にコーチが ${formatEp(gain)} EP 稼いでくれました。'),
          actions: [
            FilledButton(
              onPressed: () {
                widget.controller.dismissOfflineGain();
                Navigator.of(context).pop();
              },
              child: const Text('受け取る'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _maybeShowOfflineGain();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('育成クリッカー'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '練習', icon: Icon(Icons.sports_soccer)),
              Tab(text: 'スカッド', icon: Icon(Icons.groups)),
              Tab(text: '試合', icon: Icon(Icons.emoji_events)),
            ],
          ),
        ),
        body: Column(
          children: [
            _StatusBar(controller: controller),
            Expanded(
              child: TabBarView(
                children: [
                  _TrainingTab(controller: controller),
                  _SquadTab(controller: controller),
                  _MatchTab(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Stat(label: 'EP', value: formatEp(state.ep), emphasis: true),
            _Stat(label: '毎秒', value: '+${formatEp(controller.epPerSecond)}'),
            _Stat(label: '総合力', value: '${state.squadRating}'),
            _Stat(label: 'ランク', value: '${state.clubRank}'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            value,
            style: (emphasis
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleSmall)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('タップで練習', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '1回 +${formatEp(controller.epPerTap)} EP',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: FilledButton(
              onPressed: controller.tap,
              style: FilledButton.styleFrom(shape: const CircleBorder()),
              child: const Icon(Icons.sports_soccer, size: 72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '累計 ${controller.state.totalTaps} 回',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _UpgradeCard(
            controller: controller,
            kind: UpgradeKind.training,
            title: 'トレーニング強化',
            description: 'タップ1回の獲得 EP が増える',
            level: controller.state.trainingLevel,
          ),
          const SizedBox(height: 8),
          _UpgradeCard(
            controller: controller,
            kind: UpgradeKind.coach,
            title: 'コーチを雇う',
            description: 'アプリを閉じていても EP が貯まる（最大8時間分）',
            level: controller.state.coachLevel,
          ),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.controller,
    required this.kind,
    required this.title,
    required this.description,
    required this.level,
  });

  final GameController controller;
  final UpgradeKind kind;
  final String title;
  final String description;
  final int level;

  @override
  Widget build(BuildContext context) {
    final cost = controller.upgradeCost(kind);
    final affordable = controller.canBuy(kind);

    return Card(
      child: ListTile(
        title: Text('$title  Lv.$level'),
        subtitle: Text(description),
        trailing: FilledButton.tonal(
          onPressed: affordable ? () => controller.buyUpgrade(kind) : null,
          child: Text('${formatEp(cost.toDouble())} EP'),
        ),
      ),
    );
  }
}

class _SquadTab extends StatelessWidget {
  const _SquadTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final players = controller.state.players;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length + 1,
      itemBuilder: (context, index) {
        if (index == players.length) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('選手を獲得する'),
              subtitle: const Text('素質はスカウトしてみるまで分からない'),
              trailing: FilledButton.tonal(
                onPressed: controller.canScout ? controller.scout : null,
                child: Text('${formatEp(controller.scoutCost.toDouble())} EP'),
              ),
            ),
          );
        }
        return _PlayerCard(controller: controller, player: players[index]);
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.controller, required this.player});

  final GameController controller;
  final Player player;

  static const _positionColors = {
    Position.gk: Color(0xFFD9A441),
    Position.def: Color(0xFF3F6FB0),
    Position.mid: Color(0xFF2F8F5B),
    Position.att: Color(0xFFC2503F),
  };

  @override
  Widget build(BuildContext context) {
    final cost = controller.trainCost(player);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _positionColors[player.position],
          foregroundColor: Colors.white,
          child: Text(
            player.position.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(player.name),
        subtitle: Text('総合 ${player.rating}  ・  Lv.${player.level}'),
        trailing: FilledButton.tonal(
          onPressed: controller.canTrain(player)
              ? () => controller.trainPlayer(player.id)
              : null,
          child: Text('${formatEp(cost.toDouble())} EP'),
        ),
      ),
    );
  }
}

class _MatchTab extends StatefulWidget {
  const _MatchTab({required this.controller});
  final GameController controller;

  @override
  State<_MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<_MatchTab> {
  MatchResult? _last;

  void _play() {
    final (result, _) = widget.controller.playMatch();
    setState(() => _last = result);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.state;
    final theme = Theme.of(context);
    final result = _last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('ランク ${state.clubRank} の対戦相手',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('相手の総合力 ${controller.opponentRating}'),
                  Text('こちらの総合力 ${state.squadRating}'),
                  const SizedBox(height: 8),
                  Text(
                    'あと ${controller.winsForRankUp - state.wins} 勝でランクアップ',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.canPlayMatch ? _play : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('試合する'),
          ),
          const SizedBox(height: 16),
          if (result != null)
            Card(
              color: result.won
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      result.won ? '勝利' : '敗戦',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text('相手の総合力 ${result.opponentRating}'),
                    if (result.won)
                      Text('報酬 +${formatEp(result.reward)} EP'),
                    if (result.rankedUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'ランクアップ！',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('通算 ${state.wins} 勝 ${state.losses} 敗',
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
