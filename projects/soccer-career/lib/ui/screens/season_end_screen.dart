import 'package:flutter/material.dart';

import '../budget_lines.dart';
import '../readable_width.dart';
import '../transfer_code.dart';
import '../../game/career_engine.dart';
import '../../game/formulas.dart';
import '../../game/world.dart';
import '../../models/agent.dart';
import '../../models/competition.dart';
import '../../models/life.dart';
import '../../state/career_controller.dart';
import '../club_identity.dart';

/// シーズン終了。成績を振り返り、契約更改・移籍・引退を決める。
///
/// オファーごとに「受け入れる」か「上乗せを要求する」かを選べる。
/// 要求は代理人の交渉力次第で、失敗するとオファーが消えることもある。
class SeasonEndScreen extends StatefulWidget {
  const SeasonEndScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<SeasonEndScreen> createState() => _SeasonEndScreenState();
}

class _SeasonEndScreenState extends State<SeasonEndScreen> {
  late List<TransferOffer> _offers;
  bool _busy = false;

  /// オフをどう過ごすか。移籍先を決めるのと同じ画面で選ぶ。
  Offseason _offseason = Offseason.sharpen;

  /// 代理人に一度売り込ませたか。1シーズンに1度だけ。
  bool _solicited = false;

  /// 代理人に売り込ませる。前金を払い、取れれば選択肢が増える。
  Future<void> _solicit() async {
    if (_busy || _solicited) return;
    final (found, offers) = widget.controller.solicitOffers();
    setState(() {
      _solicited = true;
      _offers.addAll(offers);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            found ? '代理人が${offers.length}件の話を取ってきた。' : '代理人は動いたが、今回は何も取れなかった。',
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    // 大陸カップの結果をここで確定させる。
    widget.controller.finishSeason();
    final renewal = widget.controller.renewalOffer;
    _offers = [?renewal, ...widget.controller.offers];
  }

  /// 代理人を選び直す。違約金は貯蓄から前払いする。
  Future<void> _changeAgent(BuildContext context) async {
    final c = widget.controller;
    final fee = c.agentSwitchFee;
    final savings = c.state!.finances.savings;
    final picked = await showDialog<Agent>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('代理人を変える'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              savings < fee
                  ? '違約金 $fee万円。貯蓄は$savings万円で、足りない。'
                  : '違約金 $fee万円を貯蓄（$savings万円）から払う。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final a in c.agentChoices)
            SimpleDialogOption(
              onPressed: savings < fee
                  ? null
                  : () => Navigator.of(context).pop(a),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${a.name}（${a.style}）'),
                  Text(
                    a.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    c.changeAgent(picked);
    if (mounted) setState(() {});
  }

  Future<void> _accept(TransferOffer offer, {bool incentive = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.controller.advanceSeason(
      accepted: offer,
      offseason: _offseason,
      incentive: incentive,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _negotiate(int index) {
    if (_busy) return;
    final before = _offers[index];
    final (result, after) = widget.controller.negotiate(before);
    setState(() {
      if (after == null) {
        _offers.removeAt(index);
      } else {
        _offers[index] = after;
      }
    });
    final message = switch (result) {
      NegotiationResult.raised =>
        '${before.club.name}が上乗せに応じた。${before.salary}万円 → ${after!.salary}万円',
      NegotiationResult.refused => '${before.club.name}は据え置きを譲らなかった。',
      NegotiationResult.withdrawn => '${before.club.name}がオファーを引き上げた。',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retire() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引退しますか'),
        content: const Text('引退すると試合はできなくなり、通算成績だけが残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('引退する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await widget.controller.retire();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final state = controller.state!;
    final stats = state.seasonStats;
    final fate = controller.fate;
    final mustRetire = controller.mustRetire;
    final canRetire = controller.canRetire;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // 「戻る」で拠点に抜けさせない。initState で finishSeason() を
    // 済ませているので、抜けてもう一度入ると大陸カップの結果が
    // 二度確定する。抜ける道は 契約を選ぶ／引退する のどちらかだけ。
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${state.year}シーズン終了'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.club.name}  ${state.leaguePosition}位',
                          style: theme.textTheme.titleLarge,
                        ),
                        if (fate != ClubFate.stay) ...[
                          const SizedBox(height: 6),
                          FateChip(fate: fate, tier: state.club.tier),
                        ],
                        if (state.objective != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.objective!.achieved(stats)
                                ? '監督の期待に応えた（${state.objective!.achievedCount(stats)}/3）'
                                : '監督の期待には届かなかった（${state.objective!.achievedCount(stats)}/3）',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: state.objective!.achieved(stats)
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                        if (state.promise != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.promiseKept!
                                ? '約束を果たした（${state.promise!.label}）'
                                : '約束に届かなかった（${state.promise!.label}）',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: state.promiseKept!
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (state.seasonCaps > 0) ...[
                          const SizedBox(height: 4),
                          Text('代表 ${state.seasonCaps}試合', style: muted),
                        ],
                        if (state.cupStage.participated) ...[
                          const SizedBox(height: 6),
                          Chip(
                            label: Text('国内カップ ${state.cupStage.label}'),
                            backgroundColor: state.cupStage == CupStage.winner
                                ? theme.colorScheme.primaryContainer
                                : null,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        if (state.worldCupStage.participated) ...[
                          const SizedBox(height: 6),
                          Chip(
                            label: Text('世界大会 ${state.worldCupStage.label}'),
                            backgroundColor:
                                theme.colorScheme.tertiaryContainer,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        if (state.continentalStage.participated) ...[
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(
                              '大陸カップ ${state.continentalStage.label}',
                            ),
                            backgroundColor:
                                state.continentalStage ==
                                    ContinentalStage.winner
                                ? theme.colorScheme.primaryContainer
                                : null,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(theme, '出場', '${stats.appearances}'),
                            _stat(theme, 'ゴール', '${stats.goals}'),
                            _stat(theme, 'アシスト', '${stats.assists}'),
                            _stat(
                              theme,
                              '平均評価',
                              stats.appearances == 0
                                  ? '—'
                                  : stats.averageRating.toStringAsFixed(2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('今季のお金', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        // 契約を選ぶ前に見えていないと、来季も同じことになる。
                        BudgetLines(state: state),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _BackupCard(
                  years: state.yearsSinceBackup,
                  everBackedUp: state.backedUpYear > 0,
                  onBackup: () => TransferCode.show(context, widget.controller),
                ),
                const SizedBox(height: 24),
                if (mustRetire) ...[
                  Text('${state.player.age}歳。体は限界を迎えた。', style: muted),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _retire,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('引退する'),
                    ),
                  ),
                ] else ...[
                  Text('オフの過ごし方', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${state.player.physique.label}。'
                    'ここで決めたことが、来季まるごとに乗る。',
                    style: muted,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final plan in Offseason.values)
                        ChoiceChip(
                          label: Text(plan.label),
                          selected: _offseason == plan,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _offseason = plan),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 説明はツールチップに隠さない。スマホでは長押ししないと読めない。
                  Text(_offseason.description, style: muted),
                  const Divider(height: 32),
                  Text('契約', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  // 1行に押し込むと「手数料 5…」で切れていた。折り返す。
                  Text(
                    '代理人 ${state.agent.name}（${state.agent.description}）',
                    style: muted,
                  ),
                  const SizedBox(height: 6),
                  // **代理人は変えられる。** 18歳のときに選んだ一人で
                  // 19シーズンを通していた。欲しいものは時期で変わる。
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _changeAgent(context),
                      child: Text(
                        '代理人を変える'
                        '（違約金 ${widget.controller.agentSwitchFee}万）',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_solicited) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : _solicit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '代理人に売り込ませる（前金 ${controller.solicitCost}万円）',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (var i = 0; i < _offers.length; i++) ...[
                    _OfferCard(
                      offer: _offers[i],
                      roleNote: CareerEngine.roleNoteFor(
                        controller.state!.player.overall,
                        _offers[i].club,
                      ),
                      takeHome: controller.takeHome(_offers[i].salary),
                      busy: _busy,
                      onAccept: () => _accept(_offers[i]),
                      onNegotiate: _offers[i].negotiated
                          ? null
                          : () => _negotiate(i),
                      // ローンと復帰には監督の目標が付かないので、賭けようがない。
                      onIncentive: _offers[i].loan || _offers[i].returning
                          ? null
                          : () => _accept(_offers[i], incentive: true),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_offers.length == 1)
                    Text(
                      state.contractYears > 1
                          ? '契約はあと${state.contractYears}年残っている。今は動けない。'
                          : '他クラブからのオファーは無かった。',
                      style: muted,
                    ),
                  if (canRetire) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _busy ? null : _retire,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('引退する'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${Formulas.retirementForcedAge}歳のシーズンを終えると引退になる。',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
    children: [
      Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(value, style: theme.textTheme.titleLarge),
    ],
  );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.takeHome,
    required this.busy,
    required this.onAccept,
    required this.onNegotiate,
    required this.onIncentive,
    this.roleNote,
  });

  /// 起用の約束が実際に何を意味するか。`CareerEngine.roleNoteFor` から引く。
  final String? roleNote;

  final TransferOffer offer;
  final int takeHome;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback? onNegotiate;

  /// 出来高払いでサインする。目標が無い契約（ローン・復帰）では出さない。
  final VoidCallback? onIncentive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      color: offer.isRenewal ? theme.colorScheme.surfaceContainerHigh : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClubCrest(club: offer.club, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${offer.club.name}'
                    '（${World.byId(offer.club.countryId).name} ${offer.club.tier}部）',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(
                    offer.loan
                        ? 'ローン'
                        : offer.returning
                        ? '復帰'
                        : offer.isRenewal
                        ? '契約更改'
                        : '移籍',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(offer.reason, style: muted),
            if (offer.terms.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(offer.terms, style: muted),
            ],
            if (offer.eligibility != null && offer.eligibility!.foreign) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(offer.eligibility!.slotSummary),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (offer.eligibility!.permit.required)
                    Chip(
                      label: Text(offer.eligibility!.permit.summary),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '年俸 ${offer.salary}万円 ・ ${offer.years}年契約',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text('手取り $takeHome万円（手数料差引後）', style: muted),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('起用', style: muted),
                    Text(offer.role, style: theme.textTheme.titleSmall),
                  ],
                ),
              ],
            ),
            // **約束が何を意味するか。** 言葉だけだと、「ローテーション」に
            // 1季を棒に振る危険（実測 4.8%）が含まれることが読めない。
            // 判定と同じ力の差から引く（`CareerEngine.roleNoteFor`）。
            if (roleNote != null) ...[
              const SizedBox(height: 2),
              Text(roleNote!, style: muted, textAlign: TextAlign.right),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onNegotiate,
                    child: Text(offer.negotiated ? '交渉済み' : '上乗せを要求'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: Text(
                      offer.loan
                          ? 'ローンに出る'
                          : offer.returning
                          ? '戻る'
                          : offer.isRenewal
                          ? '残留する'
                          : '移籍する',
                    ),
                  ),
                ),
              ],
            ),
            // **出来高払い。** 年俸を削る代わりに、監督の目標を的にして賭ける。
            if (onIncentive != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : onIncentive,
                child: Text(
                  '出来高払いでサインする'
                  '（年俸 −${Formulas.incentiveCutOf(offer.salary)}万、'
                  '目標2つで全額・3つで'
                  '${(Formulas.incentiveCutOf(offer.salary) * Formulas.incentiveFull).round()}万）',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// セーブの持ち出しを促す。
///
/// 保存は端末の中にしか無い。ブラウザのデータを消せば消えるし、
/// iOS はしばらく開かないサイトの保存領域を自分で消す。
/// 「⋮」の奥に置いてあるだけでは、気付かないまま何年も進んでしまう。
class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.years,
    required this.everBackedUp,
    required this.onBackup,
  });

  final int years;
  final bool everBackedUp;
  final VoidCallback onBackup;

  /// これだけ控えていなければ、色を変えて促す。
  static const int warnAfterYears = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = years >= warnAfterYears;
    return Card(
      color: warn ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'セーブの持ち出し',
              style: theme.textTheme.titleSmall?.copyWith(
                color: warn ? theme.colorScheme.onErrorContainer : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              everBackedUp
                  ? '前に控えてから$years年。ブラウザのデータを消すと、'
                        'そこから先のキャリアは戻せない。'
                  : 'この記録は、この端末の中にしか無い。'
                        'ブラウザのデータを消すと消える。1度だけ控えておけば、'
                        '別の端末でも続きから遊べる。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: warn ? theme.colorScheme.onErrorContainer : null,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onBackup,
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('引き継ぎコードを出す'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 昇格・降格の札。**行き先の部を書く。**
class FateChip extends StatelessWidget {
  const FateChip({super.key, required this.fate, required this.tier});

  final ClubFate fate;

  /// 今季いた部。**行き先はここから決まる。**
  ///
  /// 「1部昇格」「2部降格」と決め打ちで書いていたので、
  /// 3部から2部へ上がったクラブにも「1部昇格」と出ていた。
  final int tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final promoted = fate == ClubFate.promoted;
    return Chip(
      label: Text(promoted ? '${tier - 1}部昇格' : '${tier + 1}部降格'),
      backgroundColor: promoted
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      labelStyle: TextStyle(
        color: promoted
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onErrorContainer,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
