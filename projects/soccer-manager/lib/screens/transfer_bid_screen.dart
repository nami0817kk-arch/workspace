import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/transfer_talk_engine.dart';
import '../models/player.dart';
import '../models/transfer_talk.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/disabled_reason.dart';
import '../widgets/estimate_stars.dart';
import '../widgets/negotiation_table.dart';
import '../widgets/player_face_avatar.dart';

/// 移籍金の提示(FM の提示の画面。2026-11-25)。
///
/// 以前は小さな窓で、移籍金の棒と分割の印だけだった。FM と同じく、
/// 移籍金・払い方(一括・分割の年数)・出来高・売却時の上乗せ・選手との
/// 交換を1つの表で組み、相手が見る値打ちと、いま払う額を下に出す。
/// いま払う額が資金を超えると「提示する」は押せず、足りない額を出す。
class TransferBidScreen extends StatefulWidget {
  const TransferBidScreen({super.key, required this.playerId, this.talk});

  final String playerId;

  /// 対案に出し直すときの交渉。
  final TransferTalk? talk;

  @override
  State<TransferBidScreen> createState() => _TransferBidScreenState();
}

class _TransferBidScreenState extends State<TransferBidScreen> {
  late int _fee;
  late int _min;
  late int _max;

  /// 0 は一括、2〜4 は分割の年数。
  int _payYears = 0;

  /// 出来高(市場価値に対する割合%。0 なら無し)。
  int _addOnPct = 0;
  int _sellOn = 0;
  String? _exchangeId;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameState>();
    final p = game.anyPlayerById(widget.playerId);
    final value = max(1, p?.marketValue ?? 1);
    final t = widget.talk;
    _min = t == null ? max(1, (value * 0.3).round()) : t.bid + 1;
    _max = [value * 3, (t?.fee ?? 0) * 2, _min + 1].reduce(max);
    _fee = (t?.fee ?? value).clamp(_min, _max);
    if (t != null) {
      _payYears = t.installments
          ? (t.installmentYears > 0 ? t.installmentYears : 3)
          : 0;
      _sellOn = t.offeredSellOn;
      _addOnPct = value <= 0 ? 0 : (t.addOn * 100 / value).round();
      if (!_addOnChoices.contains(_addOnPct)) _addOnPct = 0;
      _exchangeId = t.exchangePlayerId;
    }
  }

  static const List<int> _addOnChoices = [0, 10, 20, 30];

  int get _step => max(1, (_max / 60).round());

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = game.anyPlayerById(widget.playerId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(Tr.pick('移籍金の提示', 'Make a bid'))),
        body: Center(
            child: Text(Tr.pick('この選手は見つかりません', 'Player not found'))),
      );
    }
    final screen = MediaQuery.sizeOf(context);
    final landscape = screen.width > screen.height;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: landscape ? 44 : null,
        title: Text(Tr.pick('移籍金の提示 • ${p.name}', 'Bid • ${p.name}'),
            overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: NegotiationLayout(
          side: _side(context, game, p),
          banner: _banner(context, game, p),
          table: (wide) => NegotiationTable(
            rows: _rows(context, game, p),
            columns: wide ? 2 : 1,
            compact: wide,
            splitAt: 3,
            wantHeader: wide
                ? Tr.pick('相手', 'Club')
                : Tr.pick('相手のクラブ', 'Their club'),
          ),
          bottom: (narrow) => _bottom(context, game, p, narrow: narrow),
        ),
      ),
    );
  }

  // ---- 中身 ----

  bool get _installments => _payYears > 0;
  int _addOn(Player p) => (p.marketValue * _addOnPct / 100).round();

  int _value(GameState game, Player p) => game.packageValueOf(p,
      cash: _fee,
      installments: _installments,
      installmentYears: _payYears,
      addOn: _addOn(p),
      sellOn: _sellOn,
      exchangePlayerId: _exchangeId);

  Widget _side(BuildContext context, GameState game, Player p) {
    const small = TextStyle(fontSize: 12);
    final subtle = SemanticColors.subtleText(context);
    final club = game.clubNameOf(p.id) ?? Tr.pick('所属なし', 'Free agent');
    final ref = EstimateStars.referenceOf(game.userTeam);
    final clause = game.releaseClauseOf(p);
    final t = widget.talk ?? game.talkFor(p.id);
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Expanded(child: Text(k, style: small.copyWith(color: subtle))),
              Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: small.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    final round = t?.round ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PlayerFaceAvatar(playerId: p.id, position: p.position, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text(
                      Tr.pick('${p.position.label}・${p.age}歳',
                          '${p.position.label} • ${p.age}'),
                      style: small),
                  Text(club,
                      style: small.copyWith(color: subtle),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(Tr.pick('総合(見立て) ', 'OVR (est.) '),
                style: small.copyWith(color: subtle)),
            EstimateStars(range: game.overallEstimate(p), reference: ref),
          ],
        ),
        const Divider(height: 10),
        kv(Tr.pick('市場価値', 'Value'), formatMoney(p.marketValue)),
        kv(Tr.pick('契約', 'Contract'), ContractEngine.contractLabel(p)),
        kv(Tr.pick('年俸', 'Salary'), formatMoney(annualFromWeekly(p.wage))),
        if (clause != null)
          kv(Tr.pick('リリース条項', 'Release clause'), formatMoney(clause)),
        if (game.isListedByClub(p))
          Text(Tr.pick('移籍リスト入り(売りに出ている)', 'Transfer listed by his club'),
              style: small.copyWith(
                  color: SemanticColors.ink(context, Colors.green.shade700))),
        const Divider(height: 10),
        Text(
            Tr.pick('提示は${TransferTalkEngine.maxRounds}回まで(いま${round + 1}回目)',
                'Bid ${round + 1} of ${TransferTalkEngine.maxRounds}'),
            style: small.copyWith(color: subtle)),
      ],
    );
  }

  Widget _banner(BuildContext context, GameState game, Player p) {
    final t = widget.talk;
    if (t != null && t.stage == TransferTalkStage.countered) {
      final extra = [
        if (t.sellOnPercent > 0)
          Tr.pick('売却条項${t.sellOnPercent}%', '${t.sellOnPercent}% sell-on'),
        if (t.installments && !t.installmentsOk)
          Tr.pick('一括払い', 'paid up front'),
      ];
      return NegotiationReplyBanner(
        tone: NegotiationTone.neutral,
        text: Tr.pick(
            '${t.clubName}の対案: 移籍金${formatMoney(t.fee)}${extra.isEmpty ? '' : '(${extra.join('・')})'}。前の提示より高い額でないと出し直せません。',
            '${t.clubName} want ${formatMoney(t.fee)}${extra.isEmpty ? '' : ' (${extra.join(', ')})'}. A new bid has to beat your last one.'),
      );
    }
    return NegotiationReplyBanner(
      text: Tr.pick(
          '相手の言い値は、返事が来るまで分かりません。値打ちが言い値の${(TransferTalkEngine.walkAwayRatio * 100).round()}%を切ると、話を打ち切られます。',
          'Their asking price stays hidden until they reply. Fall below ${(TransferTalkEngine.walkAwayRatio * 100).round()}% of it and they walk away.'),
    );
  }

  List<NegotiationRow> _rows(BuildContext context, GameState game, Player p) {
    final t = widget.talk;
    final subtle = SemanticColors.subtleText(context);
    Widget want(String s) => Text(s,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: subtle));
    final budget = game.save!.budget;
    final need = game.upfrontForBid(_fee, installments: _installments);
    final candidates = game.exchangeCandidates(forPlayerId: p.id);
    if (_exchangeId != null && !candidates.any((q) => q.id == _exchangeId)) {
      _exchangeId = null;
    }
    return [
      NegotiationRow(
        key: const ValueKey('bid-fee'),
        label: Tr.pick('移籍金', 'Fee'),
        note: Tr.pick('相手に払うお金。分割なら、いま払うのは3割。',
            'The cash part. With instalments, 30% is due now.'),
        want: want(t?.stage == TransferTalkStage.countered
            ? formatMoney(t!.fee)
            : Tr.pick('相場 ${formatMoney(p.marketValue)}',
                'Worth ${formatMoney(p.marketValue)}')),
        offer: NegotiationStepper(
          label: formatMoney(_fee),
          color: need > budget ? SemanticColors.negative(context) : null,
          onMinus: _fee > _min
              ? () => setState(() => _fee = max(_min, _fee - _step))
              : null,
          onPlus: _fee < _max
              ? () => setState(() => _fee = min(_max, _fee + _step))
              : null,
        ),
      ),
      NegotiationRow(
        key: const ValueKey('bid-pay'),
        label: Tr.pick('払い方', 'Payment'),
        note: Tr.pick(
            '分割は頭金3割と、残りを毎年の季の締めに。年数が長いほど相手の見る値打ちは下がります(1年あたり3%)。',
            '30% now and the rest at the end of each season. The longer it runs, the less it is worth to them (3% a year).'),
        want: want(t?.stage == TransferTalkStage.countered
            ? (t!.installments && !t.installmentsOk
                ? Tr.pick('一括のみ', 'Up front only')
                : Tr.pick('どちらでも', 'Either'))
            : '—'),
        offer: NegotiationChoice<int>(
          key: const ValueKey('bid-pay-choice'),
          value: _payYears,
          items: [0, ...TransferTalkEngine.installmentYearChoices],
          labelOf: (y) => y == 0
              ? Tr.pick('一括', 'Up front')
              : Tr.pick('分割 $y年', '$y-year instalments'),
          onChanged: (v) => setState(() => _payYears = v),
        ),
      ),
      NegotiationRow(
        key: const ValueKey('bid-addon'),
        label: Tr.pick('出来高', 'Add-on'),
        note: Tr.pick(
            '加入後に${TransferTalkEngine.addOnApps}試合に出たら払う額。届くか分からないので、相手は半分に見ます。',
            'Paid once he makes ${TransferTalkEngine.addOnApps} appearances for you. They count it at half, as it may never be due.'),
        want: want('—'),
        offer: NegotiationChoice<int>(
          value: _addOnPct,
          items: _addOnChoices,
          labelOf: (pct) => pct == 0
              ? Tr.pick('なし', 'None')
              : Tr.pick(
                  '${formatMoney((p.marketValue * pct / 100).round())}(${TransferTalkEngine.addOnApps}試合)',
                  '${formatMoney((p.marketValue * pct / 100).round())} (${TransferTalkEngine.addOnApps} apps)'),
          onChanged: (v) => setState(() => _addOnPct = v),
        ),
      ),
      NegotiationRow(
        key: const ValueKey('bid-sellon'),
        label: Tr.pick('売却時の上乗せ', 'Sell-on'),
        note: Tr.pick('将来この選手を売るとき、売値のこの割合を元のクラブへ払う約束。',
            'If you sell him on later, this share of the fee goes back to them.'),
        want: want(t != null && t.sellOnPercent > 0
            ? '${t.sellOnPercent}%'
            : '—'),
        offer: NegotiationChoice<int>(
          value: _sellOn,
          items: TransferTalkEngine.sellOnChoices,
          labelOf: (v) => v == 0 ? Tr.pick('なし', 'None') : '$v%',
          onChanged: (v) => setState(() => _sellOn = v),
        ),
      ),
      NegotiationRow(
        key: const ValueKey('bid-exchange'),
        label: Tr.pick('選手との交換', 'Player exchange'),
        note: Tr.pick(
            '自クラブの選手を1人付ける。相手はその位置に欲しい選手ほど高く見ます(市場価値の6〜8.5割)。',
            'Add one of your players. They value him at 60-85% of his worth, more if they need his position.'),
        want: want('—'),
        offer: NegotiationChoice<String>(
          key: const ValueKey('bid-exchange-choice'),
          value: _exchangeId ?? '',
          items: ['', for (final q in candidates) q.id],
          labelOf: (id) {
            if (id.isEmpty) return Tr.pick('なし', 'None');
            final q = candidates.firstWhere((x) => x.id == id);
            return Tr.pick(
                '${q.name}(${q.position.label}・${formatMoney(q.marketValue)})',
                '${q.name} (${q.position.label}, ${formatMoney(q.marketValue)})');
          },
          onChanged: (v) => setState(() => _exchangeId = v.isEmpty ? null : v),
        ),
      ),
    ];
  }

  Widget _bottom(BuildContext context, GameState game, Player p,
      {required bool narrow}) {
    final budget = game.save!.budget;
    final need = game.upfrontForBid(_fee, installments: _installments);
    final value = _value(game, p);
    final pct = p.marketValue <= 0 ? 0 : (value * 100 / p.marketValue).round();
    final clause = game.releaseClauseOf(p);
    final short = need > budget;
    final windowShut = !game.isTransferWindowOpen;
    final ex = _exchangeId;
    final tooFew =
        ex != null && game.userTeam.players.length <= minSquadSize;
    final blocked = windowShut
        ? game.transferWindowStatusLabel
        : short
            ? Tr.pick(
                'いま払う${formatMoney(need)}に資金が足りません(あと${formatMoney(need - budget)})',
                '${formatMoney(need)} is due now: ${formatMoney(need - budget)} short')
            : tooFew
                ? Tr.pick('スカッドが下限の$minSquadSize人なので、交換には出せません',
                    'Your squad is at the minimum of $minSquadSize, so nobody can go the other way')
                : null;
    const label = TextStyle(fontSize: 12);
    return NegotiationBottomBar(
      narrow: narrow,
      info: [
        Text(
            Tr.pick('相手の見る値打ち ${formatMoney(value)}(市場価値の$pct%)',
                'Worth to them ${formatMoney(value)} ($pct% of value)'),
            key: const ValueKey('bid-value'),
            style: label.copyWith(fontWeight: FontWeight.bold)),
        Text(
            Tr.pick('いま払う ${formatMoney(need)}(手数料込み)',
                'Due now ${formatMoney(need)} (with agent fee)'),
            style: label.copyWith(
                color: short ? SemanticColors.negative(context) : null)),
        Text(Tr.pick('資金 ${formatMoney(budget)}', 'Funds ${formatMoney(budget)}'),
            style: label),
        if (blocked != null)
          DisabledReason(blocked,
              key: const ValueKey('bid-blocked'), padding: EdgeInsets.zero),
      ],
      buttons: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(Tr.pick('やめる', 'Cancel')),
        ),
        if (clause != null && widget.talk == null) ...[
          const SizedBox(width: 4),
          OutlinedButton(
            key: const ValueKey('pay-release-clause'),
            onPressed: windowShut ? null : () => _payClause(context, game, p),
            child: Text(Tr.pick(
                '条項${formatMoney(clause)}を払う', 'Pay ${formatMoney(clause)}')),
          ),
        ],
        const SizedBox(width: 4),
        FilledButton(
          key: const ValueKey('bid-submit'),
          onPressed: blocked != null ? null : () => _submit(context, game, p),
          child: Text(Tr.pick('提示する', 'Make the bid')),
        ),
      ],
    );
  }

  Future<void> _payClause(BuildContext context, GameState game, Player p) async {
    final paid = await game.triggerReleaseClause(p.id);
    if (!context.mounted) return;
    paid ? FeedbackService.tap() : FeedbackService.error();
    final messenger = ScaffoldMessenger.of(context);
    if (paid) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(paid
          ? Tr.pick('条項の額を払うと伝えました。「交渉とオファー」から選手と条件を話してください。',
              'Clause triggered. Agree personal terms under Talks & offers.')
          : (game.lastSigningBlockReason ??
              Tr.pick('条項の額を払えませんでした', 'The clause could not be paid'))),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _submit(BuildContext context, GameState game, Player p) async {
    final ok = await game.openTransferTalk(p.id, _fee,
        installments: _installments,
        installmentYears: _payYears,
        addOn: _addOn(p),
        sellOn: _sellOn,
        exchangePlayerId: _exchangeId);
    if (!context.mounted) return;
    ok ? FeedbackService.tap() : FeedbackService.error();
    final messenger = ScaffoldMessenger.of(context);
    final reason = game.lastSigningBlockReason;
    if (ok) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? Tr.pick('提示しました。返事は「交渉とオファー」に届きます。',
              'Bid made. The reply will appear under Talks & offers.')
          : (reason ?? Tr.pick('提示できませんでした', 'The bid could not be made'))),
      duration: Duration(seconds: reason != null && !ok ? 6 : 4),
    ));
  }
}
