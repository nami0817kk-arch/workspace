import 'package:flutter/material.dart';

import '../../deck/cards.dart';
import '../../deck/mates.dart';
import '../../deck/opponents.dart';
import '../../deck/run.dart';
import '../../monetization/monetization.dart';
import '../deck_controller.dart';
import '../layout.dart';
import '../team_colors.dart';
import 'card_view.dart';
import 'style.dart';

/// シーズンの画面を、いまの局面で切り替える。
class RunScreen extends StatelessWidget {
  const RunScreen({super.key, required this.c, required this.run, required this.battle});
  final DeckController c;
  final RunState run;

  /// 試合の画面(循環を避けるため外から渡す)。
  final Widget Function() battle;

  @override
  Widget build(BuildContext context) => switch (run.phase) {
        Phase.battle => battle(),
        Phase.map => MapScreen(c: c, run: run),
        Phase.reward => RewardScreen(c: c, run: run),
        Phase.mateReward => MateRewardScreen(c: c, run: run),
        Phase.practice => PracticeScreen(c: c, run: run),
        Phase.shop => ShopScreen(c: c, run: run),
        Phase.event => EventScreen(c: c, run: run),
        Phase.finished => FinishedScreen(c: c, run: run),
      };
}

/// 画面の枠(幅をそろえ、上にシーズンの状態を出す)。
class _Frame extends StatelessWidget {
  const _Frame({required this.run, required this.title, required this.children, this.bottom, this.onHome});
  final RunState run;
  final String title;
  final List<Widget> children;
  final Widget? bottom;

  /// はじめの画面へ戻るボタン(行き先を選ぶ画面だけ)。
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        leading: onHome == null
            ? null
            : IconButton(tooltip: 'はじめの画面', icon: const Icon(Icons.home_rounded), onPressed: onHome),
        actions: [
          _RunChips(run: run),
          IconButton(
            tooltip: 'デッキを見る',
            icon: Badge(
              label: Text('${run.deck.length}'),
              child: const Icon(Icons.style_rounded),
            ),
            onPressed: () => showDeckSheet(context, run.deck),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: children,
                  ),
                ),
                if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunChips extends StatelessWidget {
  const _RunChips({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < RunState.maxHearts; i++)
            Icon(i < run.hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18, color: DeckColors.bad, semanticLabel: i == 0 ? '気持ち ${run.hearts}' : null),
          const SizedBox(width: 10),
          const Icon(Icons.payments_rounded, size: 18, color: DeckColors.gold),
          const SizedBox(width: 3),
          Text('${run.money}', style: const TextStyle(fontWeight: FontWeight.bold, color: DeckColors.gold)),
          const SizedBox(width: 4),
        ],
      );
}

/// 仲間の並び(5人まで)。
class MatesRow extends StatelessWidget {
  const MatesRow({super.key, required this.mates});
  final List<MateDef> mates;

  @override
  Widget build(BuildContext context) {
    final color = teamPrefixColors['朝日']!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            for (var i = 0; i < maxMates; i++)
              Expanded(
                child: i < mates.length
                    ? Tooltip(
                        message: '${mates[i].name}(${mates[i].position}): ${mates[i].text}',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Column(children: [
                          SizedBox(
                            height: 44,
                            child: Image.asset('assets/art/players/${mates[i].sprite}_${color.sprite}.png',
                                errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded)),
                          ),
                          Text(mates[i].name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      )
                    : const Column(children: [
                        SizedBox(height: 44, child: Icon(Icons.person_add_alt_1_rounded, color: DeckColors.line)),
                        Text('あき', style: TextStyle(fontSize: 11, color: DeckColors.line)),
                      ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// 行き先を選ぶ。大会の8つの行き先を上から並べ、いまの階だけ押せる。
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    return _Frame(
      run: run,
      title: run.stageName,
      onHome: c.goHome,
      children: [
        if (run.lastMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(run.lastMessage!, style: const TextStyle(color: DeckColors.sub)),
          ),
        MatesRow(mates: run.mates),
        const SizedBox(height: 12),
        for (var f = 0; f < RunState.floorsPerStage; f++) _floor(context, f),
      ],
    );
  }

  Widget _floor(BuildContext context, int f) {
    final now = f == run.floor;
    final done = f < run.floor;
    final options = run.map[f];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Column(children: [
              Icon(done ? Icons.check_circle_rounded : (now ? Icons.play_circle_fill_rounded : Icons.circle_outlined),
                  size: 20, color: done ? DeckColors.good : (now ? DeckColors.ball : DeckColors.line)),
              Text('${f + 1}', style: const TextStyle(fontSize: 11, color: DeckColors.sub)),
            ]),
          ),
          Expanded(
            child: Row(
              children: [
                for (final t in options)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _NodeTile(
                        type: t,
                        active: now,
                        dim: done || (!now && f < run.floor),
                        onTap: now && !c.busy ? () => c.choose(t) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.type, required this.active, required this.dim, this.onTap});
  final NodeType type;
  final bool active;
  final bool dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = nodeColor(type);
    return Opacity(
      opacity: dim ? 0.35 : (active ? 1 : 0.7),
      child: Material(
        color: active ? color.withValues(alpha: 0.2) : DeckColors.panel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: active ? 12 : 8, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? color : DeckColors.line, width: active ? 2 : 1),
            ),
            child: Column(
              children: [
                Icon(nodeIcon(type), color: color, size: active ? 28 : 20),
                const SizedBox(height: 2),
                Text(type.label,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: active ? 14 : 12)),
                if (active)
                  Text(type.text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 10.5, color: DeckColors.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 勝ったあと。部費と、カードを1枚選ぶ。
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  CardInstance? _picked;
  bool _waiting = false;

  Future<void> _reroll() async {
    final messenger = ScaffoldMessenger.of(context);
    final gate = await widget.c.rerollWithAd(onWaiting: () {
      if (mounted) setState(() => _waiting = true);
    });
    if (mounted) {
      setState(() {
        _waiting = false;
        _picked = null;
      });
    }
    final msg = switch (gate) {
      RecoverGate.granted => null,
      RecoverGate.declined => '動画を最後まで見ると、選び直せる。',
      RecoverGate.unavailable => '動画の準備ができていない。少したってから。',
    };
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final c = widget.c;
    return _Frame(
      run: run,
      title: '勝利!',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _picked == null ? null : () => c.takeReward(_picked),
            child: Text(_picked == null ? 'カードを選ぶ' : '「${_picked!.name}」をデッキに入れる'),
          ),
          TextButton(onPressed: () => c.takeReward(null), child: const Text('今回は取らない')),
        ],
      ),
      children: [
        Text('部費 +${run.lastPrize}', style: const TextStyle(fontSize: 16, color: DeckColors.gold)),
        const SizedBox(height: 6),
        const Text('新しいプレーを1枚、デッキに入れられる。長押しで説明。',
            style: TextStyle(color: DeckColors.sub)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final n = run.rewardCards.length;
          final w = ((box.maxWidth - (n - 1) * 10) / n).clamp(80.0, 170.0);
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in run.rewardCards)
                CardView(
                  key: ValueKey(card.uid),
                  card: card,
                  width: w,
                  selected: identical(card, _picked),
                  onTap: () => setState(() => _picked = card),
                  onLongPress: () => showCardDetail(context, card),
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
        if (!run.rerolled)
          OutlinedButton.icon(
            onPressed: c.busy ? null : _reroll,
            icon: Icon(c.needsAd ? Icons.smart_display_rounded : Icons.refresh_rounded),
            label: Text(_waiting ? '動画を読み込み中…' : (c.needsAd ? '動画を見て、候補を引き直す' : '候補を引き直す')),
          ),
      ],
    );
  }
}

/// 強豪に勝ったあと。仲間を迎える。
class MateRewardScreen extends StatelessWidget {
  const MateRewardScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    return _Frame(
      run: run,
      title: '仲間が加わる',
      bottom: TextButton(onPressed: () => c.takeMate(null), child: const Text('今はいい')),
      children: [
        const Text('強豪を倒したチームに、入りたいという選手が来た。1人だけ迎えられる(5人まで)。',
            style: TextStyle(color: DeckColors.sub)),
        const SizedBox(height: 12),
        for (final m in run.rewardMates) ...[
          MateCard(mate: m, onTap: () => c.takeMate(m), action: '迎える'),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class MateCard extends StatelessWidget {
  const MateCard({super.key, required this.mate, this.onTap, this.action, this.price});
  final MateDef mate;
  final VoidCallback? onTap;
  final String? action;
  final int? price;

  @override
  Widget build(BuildContext context) {
    final color = teamPrefixColors['朝日']!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 64,
              child: Image.asset('assets/art/players/${mate.sprite}_${color.sprite}.png',
                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${mate.name}(${mate.position})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(mate.text, style: const TextStyle(color: DeckColors.good)),
                ],
              ),
            ),
            if (action != null)
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                child: Text(price == null ? action! : '$action\n$price', textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

/// 練習: 1枚強くするか、休む。
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final can = run.deck.any((x) => x.canUpgrade);
    return _Frame(
      run: run,
      title: '練習',
      children: [
        const Text('体育館が空いている。どう使う?', style: TextStyle(color: DeckColors.sub)),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.upgrade_rounded,
          color: DeckColors.good,
          title: 'プレーを磨く',
          text: 'デッキのカードを1枚選んで、強くする(＋になる)。',
          onTap: can
              ? () async {
                  final pick = await showDeckSheet(context, run.deck,
                      title: '強くするカード', selectable: (x) => x.canUpgrade, upgradePreview: true);
                  if (pick != null) c.upgrade(pick);
                }
              : null,
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          icon: Icons.favorite_rounded,
          color: DeckColors.bad,
          title: '休む',
          text: run.hearts >= RunState.maxHearts ? '気持ちはもう満タン。' : '気持ちが1つ戻る。',
          onTap: run.hearts >= RunState.maxHearts ? null : c.rest,
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.color, required this.title, required this.text, this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(text, style: const TextStyle(color: DeckColors.sub)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      );
}

/// 部室: カード・仲間を部費で。カードを外す。
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final cards = run.shopItems.where((s) => s.card != null).toList();
    final mates = run.shopItems.where((s) => s.mate != null).toList();
    return _Frame(
      run: run,
      title: '部室',
      bottom: FilledButton(onPressed: c.leaveShop, child: const Text('部室を出る')),
      children: [
        const Text('部費で新しいプレーを覚えたり、仲間を迎えたりできる。', style: TextStyle(color: DeckColors.sub)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 600 ? 5 : 3;
          final w = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final it in cards)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  CardView(
                    card: it.card!,
                    width: w,
                    enabled: !it.sold && run.money >= it.price,
                    onTap: it.sold || run.money < it.price ? null : () => _confirm(context, it),
                    onLongPress: () => showCardDetail(context, it.card!),
                  ),
                  const SizedBox(height: 4),
                  Text(it.sold ? '買った' : '部費 ${it.price}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: it.sold ? DeckColors.sub : (run.money >= it.price ? DeckColors.gold : DeckColors.bad))),
                ]),
            ],
          );
        }),
        const SizedBox(height: 16),
        for (final it in mates)
          MateCard(
            mate: it.mate!,
            action: it.sold ? '加入' : '迎える',
            price: it.sold ? null : it.price,
            onTap: it.sold || run.money < it.price || run.mates.length >= maxMates ? null : () => c.buy(it),
          ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.content_cut_rounded,
          color: DeckColors.bad,
          title: 'プレーを1つやめる(部費 ${run.removalPrice})',
          text: 'デッキから1枚外す。弱いカードを減らすと、強いカードを引きやすくなる。',
          onTap: run.money >= run.removalPrice && run.deck.length > 5
              ? () async {
                  final pick = await showDeckSheet(context, run.deck, title: '外すカード', selectable: (_) => true);
                  if (pick != null) c.removeCard(pick);
                }
              : null,
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, ShopItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${it.card!.name}」を買う?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CardView(card: it.card!, width: 150),
          const SizedBox(height: 8),
          Text('部費 ${it.price}(残り ${run.money - it.price})'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
              child: const Text('買う')),
        ],
      ),
    );
    if (ok == true) c.buy(it);
  }
}

/// 出来事。
class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final e = run.event!;
    return _Frame(
      run: run,
      title: e.title,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.auto_awesome_rounded, size: 48, color: Color(0xFFB06CE0)),
        const SizedBox(height: 12),
        Text(e.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
        const SizedBox(height: 20),
        for (var i = 0; i < e.choices.length; i++) ...[
          OutlinedButton(
            onPressed: () => c.resolveEvent(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(e.choices[i].label, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 優勝・敗退。
class FinishedScreen extends StatefulWidget {
  const FinishedScreen({super.key, required this.c, required this.run});
  final DeckController c;
  final RunState run;

  @override
  State<FinishedScreen> createState() => _FinishedScreenState();
}

class _FinishedScreenState extends State<FinishedScreen> {
  bool _waiting = false;

  Future<void> _retry() async {
    final messenger = ScaffoldMessenger.of(context);
    final gate = await widget.c.retryWithAd(onWaiting: () {
      if (mounted) setState(() => _waiting = true);
    });
    if (mounted) setState(() => _waiting = false);
    final msg = switch (gate) {
      RecoverGate.granted => null,
      RecoverGate.declined => '動画を最後まで見ると、やり直せる。',
      RecoverGate.unavailable => '動画の準備ができていない。少したってから。',
    };
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final c = widget.c;
    final title = run.champion ? '全国制覇!' : '${run.stageName}で敗退';
    return _Frame(
      run: run,
      title: run.champion ? '優勝' : 'シーズン終了',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (run.canRetry) ...[
          FilledButton.icon(
            onPressed: c.busy ? null : _retry,
            icon: Icon(c.needsAd ? Icons.smart_display_rounded : Icons.replay_rounded),
            label: Text(_waiting
                ? '動画を読み込み中…'
                : (c.needsAd ? '動画を見て、決勝をもう一度(1回だけ)' : '決勝をもう一度(1回だけ)')),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(onPressed: c.closeRun, child: const Text('はじめの画面へ')),
      ]),
      children: [
        const SizedBox(height: 8),
        Icon(run.champion ? Icons.emoji_events_rounded : Icons.sports_basketball_rounded,
            size: 72, color: run.champion ? DeckColors.gold : DeckColors.sub),
        const SizedBox(height: 8),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${run.wins}勝${run.losses}敗・難しさ ${run.difficulty}',
            textAlign: TextAlign.center, style: const TextStyle(color: DeckColors.sub)),
        const SizedBox(height: 16),
        MatesRow(mates: run.mates),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showDeckSheet(context, run.deck, title: '最後のデッキ'),
          icon: const Icon(Icons.style_rounded),
          label: Text('最後のデッキを見る(${run.deck.length}枚)'),
        ),
        if (!run.champion && run.current == NodeType.boss) ...[
          const SizedBox(height: 12),
          Text('決勝の相手: ${run.opponent?.name ?? bossNames[run.stage]}',
              textAlign: TextAlign.center, style: const TextStyle(color: DeckColors.sub)),
        ],
      ],
    );
  }
}
