import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/economy_scale.dart';
import '../logic/squad_registration_engine.dart';
import '../models/league.dart';
import '../models/league_theme.dart';
import '../models/save_game.dart';
import '../models/start_scenario.dart';
import '../state/game_state.dart';
import '../widgets/busy_overlay.dart';
import 'main_shell.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late Future<List<SaveSlotSummary>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _loadSlots();
  }

  Future<List<SaveSlotSummary>> _loadSlots() {
    return context.read<GameState>().listSaveSlots();
  }

  void _refreshSlots() {
    setState(() => _slotsFuture = _loadSlots());
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    if (!gameState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BusyOverlay(
      visible: gameState.isBusy,
      label: Tr.pick('クラブを創設しています…', 'Founding your club…'),
      child: Scaffold(
        // タイトル画面だけは絵を敷く。起動のたびに必ず見る画面で、
        // ここだけはアイコン1個と文字しか無かった。絵は上35%が無地、
        // 下は芝になっているので、題字を上に、保存枠を下に置く。
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 右寄せで切る。絵の階段が右寄りにあり、中央で切ると
            // 右端が欠ける。切り落とすのは左の空きスペース側にする。
            Image.asset(
              'assets/art/title_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            // 下へ行くほど暗くする。芝の上にそのまま枠を置くと、
            // 明るい緑と白いカードがぶつかって読みにくい。
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x33000000),
                    Color(0xCC08160E),
                  ],
                  stops: [0.0, 0.5, 0.86],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        // 題字を上、保存枠を下に寄せて、あいだに絵を見せる。
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                context.l10n.appTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                        color: Color(0xCC000000),
                                        blurRadius: 10),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.startTagline,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shadows: const [
                                    Shadow(
                                        color: Color(0xCC000000),
                                        blurRadius: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: FutureBuilder<List<SaveSlotSummary>>(
                              future: _slotsFuture,
                              builder: (context, snapshot) {
                                final slots = snapshot.data;
                                if (slots == null) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                return _StartActions(
                                  slots: slots,
                                  lastSlot: gameState.currentSlot,
                                  onContinue: (slot) =>
                                      _continueSlot(context, slot),
                                  onNewGame: () => _newGame(context, slots),
                                  onManage: () => _openSlots(context, slots),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 「新しく始める」。空いている枠があれば、最初の空き枠に作る。無ければ
  /// セーブ枠の一覧を開く(どれかを消してから作る)。
  Future<void> _newGame(
      BuildContext context, List<SaveSlotSummary> slots) async {
    final empty = slots.where((s) => !s.hasSave).firstOrNull;
    if (empty != null) {
      await _createInSlot(context, empty);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Tr.pick('空いているセーブ枠がありません。使わない枠を消してから始めてください。',
            'No free save slot. Delete one you no longer need, then start.'))));
    await _openSlots(context, slots);
  }

  /// セーブ枠の一覧(続ける・消す・この枠で始める)。
  Future<void> _openSlots(
      BuildContext context, List<SaveSlotSummary> slots) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Tr.pick('セーブ枠', 'Save slots'),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final slot in slots) ...[
                _SlotCard(
                  slot: slot,
                  onContinue: () {
                    Navigator.pop(ctx);
                    _continueSlot(context, slot);
                  },
                  onCreate: () {
                    Navigator.pop(ctx);
                    _createInSlot(context, slot);
                  },
                  onDelete: () {
                    Navigator.pop(ctx);
                    _confirmDeleteSlot(context, slot);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueSlot(BuildContext context, SaveSlotSummary slot) async {
    final gameState = context.read<GameState>();
    try {
      await gameState.loadSlot(slot.slot);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Tr.pick(
                'セーブデータの読み込みに失敗しました', 'The save could not be loaded'))));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  Future<void> _createInSlot(BuildContext context, SaveSlotSummary slot) async {
    final result = await showDialog<_NewClubInput>(
      context: context,
      builder: (ctx) => _NewClubDialog(slotLabel: slot.slot + 1),
    );
    if (result == null || !context.mounted) return;
    final gameState = context.read<GameState>();
    try {
      await gameState.loadSlot(slot.slot);
      await gameState.startNewGame(
        result.clubName,
        theme: result.theme,
        difficulty: result.difficulty,
        scenario: result.scenario,
        difficultyItems: result.items,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(Tr.pick('クラブの作成に失敗しました。もう一度お試しください',
                  'The club could not be created. Please try again'))),
        );
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  void _confirmDeleteSlot(BuildContext context, SaveSlotSummary slot) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.startDeleteSlot(slot.slot + 1)),
        content: Text(Tr.pick('「${slot.clubName}」のセーブデータは完全に削除されます。',
            'The save for "${slot.clubName}" will be deleted for good.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          // 取り消せない操作の確定は、赤く塗ったボタン(2026-11-24)。
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().deleteSlot(slot.slot);
              if (mounted) _refreshSlots();
            },
            child: Text(Tr.pick('削除する', 'Delete')),
          ),
        ],
      ),
    );
  }
}

/// タイトルの操作。「続きから」を大きく1つ、その下に「新しく始める」と
/// 「セーブ枠」(2026-11-25)。
///
/// 以前は3つのセーブ枠を同じ大きさの札で並べていて、毎回いちばん押す
/// 「続ける」が小さなボタンの1つだった。
class _StartActions extends StatelessWidget {
  const _StartActions({
    required this.slots,
    required this.lastSlot,
    required this.onContinue,
    required this.onNewGame,
    required this.onManage,
  });

  final List<SaveSlotSummary> slots;

  /// 最後に遊んだ枠。
  final int lastSlot;
  final void Function(SaveSlotSummary) onContinue;
  final VoidCallback onNewGame;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final saved = slots.where((s) => s.hasSave).toList();
    final last = saved.where((s) => s.slot == lastSlot).firstOrNull ??
        saved.firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last != null)
            FilledButton(
              key: const ValueKey('start-continue'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 64),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => onContinue(last),
              child: Row(
                children: [
                  const Icon(Icons.play_arrow, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Tr.pick('続きから', 'Continue'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          Tr.pick(
                              '${last.clubName} ・ 第${last.season ?? 1}季${last.divisionTier != null ? ' ・ ${last.divisionTier}部' : ''}',
                              "${last.clubName} • Season ${last.season ?? 1}${last.divisionTier != null ? ' • Tier ${last.divisionTier}' : ''}"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (last != null) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: last == null
                    // まだ1つもセーブが無いときは、新しく始めるが主役。
                    ? FilledButton.icon(
                        key: const ValueKey('start-new'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56)),
                        onPressed: onNewGame,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.startCreateClub),
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('start-new'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor:
                              scheme.surface.withValues(alpha: 0.92),
                        ),
                        onPressed: onNewGame,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.startCreateClub),
                      ),
              ),
              if (saved.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('start-slots'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: scheme.surface.withValues(alpha: 0.92),
                  ),
                  onPressed: onManage,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(Tr.pick('セーブ枠', 'Save slots')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final SaveSlotSummary slot;
  final VoidCallback onContinue;
  final VoidCallback onCreate;
  final VoidCallback onDelete;

  const _SlotCard({
    required this.slot,
    required this.onContinue,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: slot.hasSave
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.startSlotLabel(slot.slot + 1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          slot.clubName!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          Tr.pick(
                              '第${slot.season ?? 1}シーズン${slot.divisionTier != null && slot.divisionTier != 1 ? ' ・ ${slot.divisionTier}部' : ''}',
                              "Season ${slot.season ?? 1}${slot.divisionTier != null && slot.divisionTier != 1 ? ' • Tier ${slot.divisionTier}' : ''}"),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: Tr.pick('削除', 'Delete'),
                  ),
                  FilledButton(
                      onPressed: onContinue,
                      child: Text(Tr.pick('続ける', 'Continue'))),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.startSlotLabel(slot.slot + 1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          context.l10n.startEmptySlot,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: SemanticColors.ink(context, Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                  // 言語によってラベルの長さが変わる (日本語より英語が長い)。
                  // ボタンをFlexibleにすると行幅を左右で等分してしまい、
                  // 英語ラベルではボタンが内容より狭く潰されて左右の余白が
                  // 消え、文字が枠線に接してしまう。ボタンは必要な幅を
                  // そのまま取らせ、代わりに左のテキスト列(Expanded)を
                  // 縮ませる。省略指定は極端に長い訳語への保険。
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: Text(
                      context.l10n.startCreateClub,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NewClubInput {
  final String clubName;
  final LeagueTheme theme;
  final GameDifficulty difficulty;
  final StartScenario scenario;
  final Map<DifficultyItem, GameDifficulty> items;
  _NewClubInput(
      this.clubName, this.theme, this.difficulty, this.scenario, this.items);
}

class _NewClubDialog extends StatefulWidget {
  final int slotLabel;
  const _NewClubDialog({required this.slotLabel});

  @override
  State<_NewClubDialog> createState() => _NewClubDialogState();
}

class _NewClubDialogState extends State<_NewClubDialog> {
  final _controller = TextEditingController();
  LeagueTheme _theme = LeagueTheme.england;
  GameDifficulty _difficulty = GameDifficulty.normal;
  StartScenario _scenario = StartScenario.standard;

  /// 項目ごとに変えた難易度(無い項目は全体の難易度)。
  final Map<DifficultyItem, GameDifficulty> _items = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.startNewClubIn(widget.slotLabel)),
      content: SingleChildScrollView(
        // 入力欄の枠の上に乗る見出し(「クラブ名」)が、送る欄の上の端で
        // 切れていた(上半分が欠ける)。上に少し余白を置く(2026-11-25)。
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: context.l10n.startClubNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(context.l10n.startLeagueLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // リーグごとに、始めの予算・登録の決まり・難しさを1行で
            // (2026-11-25。名前だけでは違いが分からなかった)。
            for (final theme in LeagueTheme.values)
              _LeagueOption(
                theme: theme,
                selected: _theme == theme,
                onTap: () => setState(() => _theme = theme),
              ),
            const SizedBox(height: 16),
            Text(context.l10n.startDifficultyLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GameDifficulty.values
                  .map(
                    (d) => ChoiceChip(
                      label: Text(d.label),
                      selected: _difficulty == d,
                      onSelected: (_) => setState(() {
                        _difficulty = d;
                        _items.clear();
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            Text(
              _difficulty.description,
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              // 開いた中身だけ中央寄せになっていた。ほかの欄と同じ左寄せに。
              expandedAlignment: Alignment.centerLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(Tr.pick('項目ごとに決める', 'Set each item'),
                  style: const TextStyle(fontSize: 14)),
              children: [
                for (final item in DifficultyItem.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final d in GameDifficulty.values)
                              ChoiceChip(
                                label: Text(item.effect(d)),
                                selected: (_items[item] ?? _difficulty) == d,
                                onSelected: (_) =>
                                    setState(() => _items[item] = d),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(Tr.pick('シナリオ', 'Scenario'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StartScenario.values
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s.label),
                      selected: _scenario == s,
                      onSelected: (_) => setState(() => _scenario = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            Text(
              _scenario.description,
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
                context,
                _NewClubInput(
                    name, _theme, _difficulty, _scenario, Map.of(_items)));
          },
          child: Text(context.l10n.startCreate),
        ),
      ],
    );
  }
}

/// 新しく始めるの、リーグの1行。名前の下に、始めの予算・登録の決まり・
/// 難しさを並べる。
class _LeagueOption extends StatelessWidget {
  const _LeagueOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final LeagueTheme theme;
  final bool selected;
  final VoidCallback onTap;

  /// 登録の決まりを短く(「国内育成8人・EU外4人まで」)。
  static String registrationLine(LeagueTheme t) {
    final r = RegistrationRules.forCountry(t);
    final parts = <String>[
      if (r.homegrownQuota > 0)
        Tr.pick('国内育成${r.homegrownQuota}人', '${r.homegrownQuota} home-grown'),
      if (r.clubTrainedQuota > 0)
        Tr.pick('うちクラブ育ち${r.clubTrainedQuota}人',
            '${r.clubTrainedQuota} club-trained'),
      if (r.nonEuLimit case final n?) Tr.pick('EU外$n人まで', 'max $n non-EU'),
      if (r.nonEuSigningsPerSeason case final n?)
        Tr.pick('EU外の獲得は1季$n人', '$n non-EU signings a season'),
      if (r.minNationals case final n?)
        Tr.pick('自国籍$n人以上', 'at least $n nationals'),
    ];
    return parts.join(Tr.pick('・', ', '));
  }

  /// 難しさ。財務規則の罰の重さで決めた(league_rules.dart の表)。
  /// イングランド・ドイツは勝ち点の減点、スペインは新加入を登録できない、
  /// イタリアは獲得できない、フランスは降格処分まである。
  static String difficultyLabel(LeagueTheme t) => switch (t) {
        LeagueTheme.england ||
        LeagueTheme.germany =>
          Tr.pick('ふつう', 'normal'),
        LeagueTheme.spain || LeagueTheme.italy => Tr.pick('やや難しい', 'harder'),
        LeagueTheme.france => Tr.pick('難しい', 'hard'),
      };

  /// 1行: 「予算 2.5億・登録 国内育成8人・難しさ ふつう」。
  static String line(LeagueTheme t) {
    final budget =
        formatMoney(GameState.initialBudgetFor(totalDivisionTiers, t));
    return Tr.pick(
        '予算 $budget・登録 ${registrationLine(t)}・難しさ ${difficultyLabel(t)}',
        'Budget $budget • squad: ${registrationLine(t)} • ${difficultyLabel(t)}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('league-option-${theme.name}'),
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Tr.pick('${theme.label}（${theme.flavorLabel}）',
                            '${theme.label} (${theme.flavorLabel})'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        line(theme),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
