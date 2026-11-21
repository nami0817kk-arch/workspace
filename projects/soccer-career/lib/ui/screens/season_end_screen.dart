import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../budget_lines.dart';
import '../readable_width.dart';
import '../share_card.dart';
import '../share_sheet.dart';
import '../transfer_code.dart';
import '../../game/career_engine.dart';
import '../../game/squads.dart';
import '../../models/player.dart';
import '../../game/formulas.dart';
import '../../game/world.dart';
import '../../models/agent.dart';
import '../../models/competition.dart';
import '../../models/life.dart';
import '../../monetize/monetization.dart';
import 'support_screen.dart';
import '../../state/career_controller.dart';
import '../club_identity.dart';
import '../player_banner.dart';
import '../stat_tile.dart';
import '../../models/career.dart';

/// シーズン終了。成績を振り返り、契約更改・移籍・引退を決める。
///
/// オファーごとに「受け入れる」か「上乗せを要求する」かを選べる。
/// 要求は代理人の交渉力次第で、失敗するとオファーが消えることもある。
class SeasonEndScreen extends StatefulWidget {
  const SeasonEndScreen({
    super.key,
    required this.controller,
    this.monetization,
  });

  final CareerController controller;

  /// 広告と課金。**渡されなければ何も出さない**（テストとブラウザ版）。
  final Monetization? monetization;

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
            found ? tr('代理人が${offers.length}件の話を取ってきた。', 'Your agent came back with ${plural(offers.length, 'offer')}.') : tr('代理人は動いたが、今回は何も取れなかった。', 'Your agent worked the phones, but nothing came of it.'),
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
        title: Text(tr('代理人を変える', 'Change agent')),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              savings < fee
                  ? tr('違約金 $fee万円。貯蓄は$savings万円で、足りない。', 'The release clause is JPY ${(fee / 100).toStringAsFixed(1)}M. You have JPY ${(savings / 100).toStringAsFixed(1)}M saved, which is not enough.')
                  : tr('違約金 $fee万円を貯蓄（$savings万円）から払う。', 'Pay the JPY ${(fee / 100).toStringAsFixed(1)}M release clause out of your savings (JPY ${(savings / 100).toStringAsFixed(1)}M).'),
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
        tr('${before.club.name}が上乗せに応じた。${before.salary}万円 → ${after!.salary}万円', '${before.club.name} came up to meet you. JPY ${(before.salary / 100).toStringAsFixed(1)}M → JPY ${(after.salary / 100).toStringAsFixed(1)}M'),
      NegotiationResult.refused => tr('${before.club.name}は据え置きを譲らなかった。', '${before.club.name} would not move.'),
      NegotiationResult.withdrawn => tr('${before.club.name}がオファーを引き上げた。', '${before.club.name} pulled the offer.'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 「広告を消す」を勧めてよいか。
  ///
  /// 出る前に勧めても何の話か分からないので、**広告が出るようになってから**。
  bool get _offersNoAds {
    final money = widget.monetization;
    if (money == null || money.noAds || !money.storeAvailable) return false;
    return (widget.controller.state?.history.length ?? 0) >=
        Monetization.adsFromSeason;
  }

  void _openSupport() {
    final money = widget.monetization;
    if (money == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(monetization: money),
      ),
    );
  }

  Future<void> _retire() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('引退しますか', 'Retire?')),
        content: Text(tr('引退すると試合はできなくなり、通算成績だけが残ります。', 'Once you retire there are no more matches, only the career totals.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('引退する', 'Retire')),
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

    // この季に何を成したか。**成していない季には送る口を出さない。**
    final String? shareHeadline;
    if (state.leaguePosition == 1) {
      shareHeadline = tr('${state.club.tier}部 優勝', 'Tier ${state.club.tier} champions');
    } else if (fate == ClubFate.promoted) {
      shareHeadline = tr('${state.club.tier - 1}部へ昇格', 'Promoted to tier ${state.club.tier - 1}');
    } else if (state.continentalStage == ContinentalStage.winner) {
      shareHeadline = tr('大陸カップ優勝', 'Continental cup winners');
    } else if (state.cupStage == CupStage.winner) {
      shareHeadline = tr('国内カップ優勝', 'Domestic cup winners');
    } else {
      shareHeadline = null;
    }

    // 「戻る」で拠点に抜けさせない。initState で finishSeason() を
    // 済ませているので、抜けてもう一度入ると大陸カップの結果が
    // 二度確定する。抜ける道は 契約を選ぶ／引退する のどちらかだけ。
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('${state.year}シーズン終了', 'End of ${state.year}')),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // **1年の結末に、クラブの色が一つも無かった。**
                      // 38試合の締めくくりが白いカードの小さな文字で、
                      // 選手証にも対戦カードにもクラブタブにも帯があるのに、
                      // ここだけ「どこで戦った1年か」が文字の中に埋もれていた。
                      _SeasonBand(
                        state: state,
                        fate: fate,
                        position: state.leaguePosition,
                      ),
                      // **送る口は、成した季だけに出す。**
                      // 19季ぶん毎回出すと、何でもない季まで「送れ」と
                      // 言われているように見える。引退は1キャリアに1回しか
                      // 来ないので、広まるとしたら回数が多いこちら。
                      if (shareHeadline case final headline?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final card = SeasonShareCard(
                                  club: state.club,
                                  year: state.year,
                                  tier: state.club.tier,
                                  leaguePosition: state.leaguePosition,
                                  stats: stats,
                                  look: state.player.look,
                                  squadNumber: state.squadNumber,
                                  playerName: state.player.name,
                                  headline: headline,
                                  caps: state.seasonCaps,
                                  objectiveMet: state.objective
                                      ?.achievedCount(stats),
                                  cupWon: state.cupStage == CupStage.winner,
                                  continentalWon:
                                      state.continentalStage ==
                                      ContinentalStage.winner,
                                );
                                showShareSheet(
                                  context,
                                  card: card,
                                  text: card.text,
                                );
                              },
                              icon: const Icon(Icons.ios_share, size: 18),
                              label: Text(tr('$headline を送る', 'Share: $headline')),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.objective != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                state.objective!.achieved(stats)
                                    ? tr('監督の期待に応えた（${state.objective!.achievedCount(stats)}/3）', 'You met what the manager asked for (${state.objective!.achievedCount(stats)}/3)')
                                    : tr('監督の期待には届かなかった（${state.objective!.achievedCount(stats)}/3）', 'You fell short of what the manager asked for (${state.objective!.achievedCount(stats)}/3)'),
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
                                    ? tr('約束を果たした（${state.promise!.label}）', 'You kept your word (${state.promise!.label})')
                                    : tr('約束に届かなかった（${state.promise!.label}）', 'You did not keep your word (${state.promise!.label})'),
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
                              Text(tr('代表 ${state.seasonCaps}試合', 'National team ${plural(state.seasonCaps, 'game')}'), style: muted),
                            ],
                            if (state.cupStage.participated) ...[
                              const SizedBox(height: 6),
                              Tag(
                                tr('国内カップ ${state.cupStage.label}', 'Domestic cup ${state.cupStage.label}'),
                                background: state.cupStage == CupStage.winner
                                    ? theme.colorScheme.primaryContainer
                                    : null,
                                foreground: state.cupStage == CupStage.winner
                                    ? theme.colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ],
                            if (state.worldCupStage.participated) ...[
                              const SizedBox(height: 6),
                              Tag(
                                tr('世界大会 ${state.worldCupStage.label}', 'World tournament ${state.worldCupStage.label}'),
                                background: theme.colorScheme.tertiaryContainer,
                                foreground:
                                    theme.colorScheme.onTertiaryContainer,
                              ),
                            ],
                            if (state.continentalStage.participated) ...[
                              const SizedBox(height: 6),
                              Tag(
                                tr('大陸カップ ${state.continentalStage.label}', 'Continental cup ${state.continentalStage.label}'),
                                background:
                                    state.continentalStage ==
                                        ContinentalStage.winner
                                    ? theme.colorScheme.primaryContainer
                                    : null,
                                foreground:
                                    state.continentalStage ==
                                        ContinentalStage.winner
                                    ? theme.colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _stat(theme, tr('出場', 'Games'), '${stats.appearances}'),
                                _stat(theme, tr('ゴール', 'Goals'), '${stats.goals}'),
                                _stat(theme, tr('アシスト', 'Assists'), '${stats.assists}'),
                                _stat(
                                  theme,
                                  tr('平均評価', 'Avg rating'),
                                  stats.appearances == 0
                                      ? '—'
                                      : stats.averageRating.toStringAsFixed(2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('今季のお金', 'Money this season'), style: theme.textTheme.titleSmall),
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
                // **広告を消せることは、広告が出る場所で伝える。**
                // ⋮ の奥にしか置いていなかったので、出るのは知っていても
                // 消せることを知らないままになる。
                // 広告が出る前（`adsFromSeason` に届く前）と、買った人には出さない。
                if (_offersNoAds) ...[
                  const SizedBox(height: 12),
                  _NoAdsCard(onOpen: _openSupport),
                ],
                const SizedBox(height: 24),
                if (mustRetire) ...[
                  Text(tr('${state.player.age}歳。体は限界を迎えた。', 'You are ${state.player.age}. Your body has had enough.'), style: muted),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _retire,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr('引退する', 'Retire')),
                    ),
                  ),
                ] else ...[
                  Text(tr('オフの過ごし方', 'How you spend the off-season'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    tr('${state.player.physique.label}。'
                    'ここで決めたことが、来季まるごとに乗る。', '${state.player.physique.label}. What you choose here carries through all of next season.'),
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
                  Text(tr('契約', 'Contract'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  // 1行に押し込むと「手数料 5…」で切れていた。折り返す。
                  Text(
                    tr('代理人 ${state.agent.name}（${state.agent.description}）', 'Agent ${state.agent.name} (${state.agent.description})'),
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
                        tr('代理人を変える'
                        '（違約金 ${widget.controller.agentSwitchFee}万）', 'Change agent (fee JPY ${(widget.controller.agentSwitchFee / 100).toStringAsFixed(1)}M)'),
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
                          tr('代理人に売り込ませる（前金 ${controller.solicitCost}万円）', 'Have your agent tout you around (JPY ${(controller.solicitCost / 100).toStringAsFixed(1)}M up front)'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (var i = 0; i < _offers.length; i++) ...[
                    _OfferCard(
                      offer: _offers[i],
                      player: controller.state!.player,
                      year: controller.state!.year,
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
                          ? tr('契約はあと${state.contractYears}年残っている。今は動けない。', '${plural(state.contractYears, 'year')} are left on your contract. You cannot move now.')
                          : tr('他クラブからのオファーは無かった。', 'No other club came in for you.'),
                      style: muted,
                    ),
                  if (canRetire) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _busy ? null : _retire,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(tr('引退する', 'Retire')),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('${Formulas.retirementForcedAge}歳のシーズンを終えると引退になる。', 'The season you turn ${Formulas.retirementForcedAge} is your last.'),
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
    required this.player,
    required this.year,
    this.roleNote,
  });

  /// 名簿の中での位置を出すために要る。
  final Player player;
  final int year;

  /// 起用の約束が実際に何を意味するか。`CareerEngine.roleNoteFor` から引く。
  final String? roleNote;

  final TransferOffer offer;
  final int takeHome;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback? onNegotiate;

  /// 出来高払いでサインする。目標が無い契約（ローン・復帰）では出さない。
  final VoidCallback? onIncentive;

  /// 行き先の名簿の中で、自分がどこに入るか。
  ///
  /// 登録メンバーの判定（`Competitions.registrationFor`）と
  /// **同じ数え方を読む**——別に書くと、画面の数字と
  /// 加入した後の扱いがずれる。
  String _squadLine() {
    final squad = Squad.of(offer.club, year: year);
    final ahead = squad.aheadOf(player.position, player.overall);
    final quota = Squad.quotaFor(player.position.family);
    final rivals = squad.rivalsFor(player.position);
    final top = rivals.isEmpty ? null : rivals.first;
    final head = ahead == 0 ? tr('あなたの枠では一番上', 'You are first in your slot') : tr('あなたの枠に上が $ahead 人', '$ahead ahead of you in your slot');
    final fate = ahead >= quota ? tr('（登録外になる）', ' (you would be left off the squad list)') : tr('（定員 $quota）', ' (quota $quota)');
    final face = top == null ? '' : tr(' ・ 筆頭は ${top.name}（${top.overall}）', ' - the first of them is ${top.name} (${top.overall})');
    return '$head $fate$face';
  }

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
                    tr('${offer.club.name}'
                    '（${World.byId(offer.club.countryId).name} ${offer.club.tier}部）', '${offer.club.name} (${World.byId(offer.club.countryId).name}, tier ${offer.club.tier})'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(
                    offer.loan
                        ? tr('ローン', 'Loan')
                        : offer.returning
                        ? tr('復帰', 'Return')
                        : offer.isRenewal
                        ? tr('契約更改', 'Renewal')
                        : tr('移籍', 'Transfer'),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(offer.reason, style: muted),
            // **そのクラブに、あなたの枠に誰が居るか。**
            // 行き先を決める材料は年俸・移籍金・契約年数と
            // 起用の約束だけで、**誰と先発を争うのかは書いていなかった**。
            if (!offer.isRenewal) ...[
              const SizedBox(height: 4),
              Text(_squadLine(), style: muted),
            ],
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
                        tr('年俸 ${offer.salary}万円 ・ ${offer.years}年契約', 'Wage JPY ${(offer.salary / 100).toStringAsFixed(1)}M - ${offer.years}-year deal'),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(tr('手取り $takeHome万円（手数料差引後）', 'Take-home JPY ${(takeHome / 100).toStringAsFixed(1)}M (after the fee)'), style: muted),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(tr('起用', 'Your role'), style: muted),
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
                    child: Text(offer.negotiated ? tr('交渉済み', 'Already negotiated') : tr('上乗せを要求', 'Ask for more')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: Text(
                      offer.loan
                          ? tr('ローンに出る', 'Go on loan')
                          : offer.returning
                          ? tr('戻る', 'Go back')
                          : offer.isRenewal
                          ? tr('残留する', 'Stay')
                          : tr('移籍する', 'Join them'),
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
                  tr('出来高払いでサインする'
                  '（年俸 −${Formulas.incentiveCutOf(offer.salary)}万、'
                  '目標2つで全額・3つで'
                  '${(Formulas.incentiveCutOf(offer.salary) * Formulas.incentiveFull).round()}万）', 'Sign on performance terms (wage −JPY ${(Formulas.incentiveCutOf(offer.salary) / 100).toStringAsFixed(1)}M; two targets pays all of it back, three pays JPY ${(Formulas.incentiveCutOf(offer.salary) * Formulas.incentiveFull / 100).toStringAsFixed(1)}M)'),
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
///
/// **何を消すと消えるかは、動いている先で違う。** Web なら「ブラウザの
/// データ」だが、アプリで遊んでいる人にブラウザの話をしても通じない
/// （掲載用の絵を撮ったときに、iPhone の画面に「ブラウザのデータを消すと
/// 消える」と出ていた）。
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

  /// 何をすると消えるか。動いている先で言い方を変える。
  static String get erases => kIsWeb ? tr('ブラウザのデータを消す', 'clearing your browser data') : tr('アプリを消す', 'deleting the app');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = years >= warnAfterYears;
    final erases = _BackupCard.erases;
    return Card(
      color: warn ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('セーブの持ち出し', 'Taking your save with you'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: warn ? theme.colorScheme.onErrorContainer : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              everBackedUp
                  ? tr('前に控えてから$years年。$erasesと、'
                        'そこから先のキャリアは戻せない。', '${plural(years, 'year')} since you last backed this up. If it comes to $erases, the career from that point on cannot be recovered.')
                  : tr('この記録は、この端末の中にしか無い。'
                        '$erasesと消える。1度だけ控えておけば、'
                        '別の端末でも続きから遊べる。', 'This record lives only on this device, and $erases wipes it. Back it up once and you can carry on from another device.'),
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
                label: Text(tr('引き継ぎコードを出す', 'Show the transfer code')),
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
      label: Text(promoted ? tr('${tier - 1}部昇格', 'Promoted to tier ${tier - 1}') : tr('${tier + 1}部降格', 'Relegated to tier ${tier + 1}')),
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

/// シーズンの結末の帯。**クラブの色・エンブレム・順位を大きく出す。**
///
/// 選手証（`PlayerBanner`）と同じ `KitBackground` を使う——見た目のために
/// 別の色を作らない。順位は「38試合の答え」なので、この画面で一番大きい数字。
class _SeasonBand extends StatelessWidget {
  const _SeasonBand({
    required this.state,
    required this.fate,
    required this.position,
  });

  final CareerState state;
  final ClubFate fate;
  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = ClubIdentity.of(state.club);
    final on = readableOn(identity.primary);
    return KitBackground(
      primary: identity.primary,
      secondary: identity.secondary,
      striped: identity.striped,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            ClubCrest(club: state.club, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.club.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: on,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tr('${World.byId(state.club.countryId).name} '
                    '${state.club.tier}部 ・ ${state.year}シーズン', '${World.byId(state.club.countryId).name}, tier ${state.club.tier} - ${state.year}'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: on.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 順位は 38試合の答え。この画面で一番大きい数字にする。
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$position',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  tr('位 / ${state.league.length}', ' of ${state.league.length}'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: on.withValues(alpha: 0.75),
                  ),
                ),
                // 昇格・降格の札。順位のすぐ下が居場所。
                if (fate != ClubFate.stay) ...[
                  const SizedBox(height: 6),
                  FateChip(fate: fate, tier: state.club.tier),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 「広告を消す」への入口。シーズンの切れ目——広告が出る場所に置く。
class _NoAdsCard extends StatelessWidget {
  const _NoAdsCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('広告', 'Ads'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              tr('シーズンの切れ目に1回だけ出る。買い切りで消せる。'
              '強くなる課金は置いていない。', 'One ad between seasons. A single purchase removes it. Nothing on sale makes you stronger.'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.block, size: 18),
                label: Text(tr('広告を消す', 'Remove ads')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
