import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/player_terms_engine.dart';
import '../logic/pre_contract_engine.dart';
import '../logic/relations_engine.dart';
import '../models/contract_negotiation.dart';
import '../models/player.dart';
import '../models/transfer_talk.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/player_face_avatar.dart';

/// 契約の種類。どれも同じ画面で話す(2026-11-22。FM の契約交渉の画面に寄せた)。
enum ContractKind {
  /// 移籍金がまとまった選手・所属なしの選手と、加入の条件を話す。
  signing,

  /// 自分のクラブの選手と、契約の更新を話す。
  renewal,

  /// 契約が今季末で切れる他のクラブの選手と、7月1日に加入する仮契約を結ぶ。
  preContract,
}

/// 契約の画面を開く。結んだら true。
Future<bool?> openContractOffer(
  BuildContext context, {
  required Player player,
  required ContractKind kind,
  String? fromClubName,
}) {
  if (kind == ContractKind.renewal) {
    // 交渉はここで始める(画面を作る途中で状態を変えないため)。
    final game = context.read<GameState>();
    final n = game.pendingContractNegotiation;
    if (n == null || n.playerId != player.id) {
      game.startContractNegotiation(player.id);
    }
  }
  return Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => ContractOfferScreen(
        player: player, kind: kind, fromClubName: fromClubName),
  ));
}

/// 契約の交渉の画面。左に選手と代理人、中央に項目ごとの「選手の要求」と
/// 「こちらの提示」、下に契約の総額と給与の枠。提示すると代理人の返事が
/// 上の帯に出て、要求の列が書き換わる。
class ContractOfferScreen extends StatefulWidget {
  const ContractOfferScreen({
    super.key,
    required this.player,
    required this.kind,
    this.fromClubName,
  });

  final Player player;
  final ContractKind kind;
  final String? fromClubName;

  @override
  State<ContractOfferScreen> createState() => _ContractOfferScreenState();
}

enum _ReplyTone { neutral, good, bad }

class _ContractOfferScreenState extends State<ContractOfferScreen> {
  late int _wage; // 週俸(万円)。表示は年俸。
  late int _endYear;
  int _bonus = 0;
  SquadStatus _promise = SquadStatus.regular;
  bool _option = false;
  bool _busy = false;
  bool _closed = false; // 話が流れた
  String? _reply;
  _ReplyTone _tone = _ReplyTone.neutral;

  Player get p => widget.player;
  ContractKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameState>();
    switch (kind) {
      case ContractKind.signing:
        final demand = game.talkFor(p.id)?.demandWage ?? 0;
        _wage = demand > 0 ? demand : p.wage;
        final choices = ContractEngine.endYearChoicesNow(p.age);
        _endYear = choices.isEmpty
            ? Player.contractClockYear + 1
            : choices[(choices.length - 1).clamp(0, 2)];
        // 所属なしの選手は契約金を必ず求めるので、最低額から始める。
        if (_isFreeAgent(game)) _bonus = game.freeAgentSigningFeeFor(p);
      case ContractKind.renewal:
        final pending = game.pendingContractNegotiation;
        final started = pending?.playerId == p.id ? pending : null;
        _wage = started?.counterWage ?? p.wage;
        _endYear = started?.endYear ?? ContractEngine.defaultRenewalEndYear(p);
        _option = started?.option ?? false;
        if (started == null) {
          _closed = true;
          _reply = game.lastSigningBlockReason;
          _tone = _ReplyTone.bad;
        }
      case ContractKind.preContract:
        _endYear = PreContractEngine.defaultEndYear(p);
        _wage = game.preContractWageDemand(p);
    }
    _reply ??= _openingLine();
  }

  String _openingLine() {
    final agent = RelationsEngine.agentOf(p);
    return switch (kind) {
      ContractKind.signing => Tr.pick('代理人(${agent.label}): まずは条件を聞かせてください。',
          'Agent (${agent.label}): Let us hear what you have in mind.'),
      ContractKind.renewal => Tr.pick(
          '代理人(${agent.label}): 残ってもいい。ただ、今のままの額では困ります。',
          'Agent (${agent.label}): He is open to staying, but not on the same money.'),
      ContractKind.preContract => Tr.pick(
          '代理人(${agent.label}): 7月から移る話なら、この額なら決めます。',
          'Agent (${agent.label}): For a move on 1 July, this is the figure.'),
    };
  }

  // ---- 交渉の数字 ----

  List<int> _endChoices() => switch (kind) {
        ContractKind.preContract => PreContractEngine.endYearChoices(p),
        _ => ContractEngine.endYearChoicesNow(p.age),
      };

  bool _canOption() => switch (kind) {
        ContractKind.signing => false,
        ContractKind.renewal => ContractEngine.canAttachOption(_endYear, p.age),
        ContractKind.preContract => ContractEngine.canAttachOption(
            _endYear, p.age,
            nextSeasonStart: true),
      };

  int _years() => max(
      1,
      _endYear -
          Player.contractClockYear +
          (kind == ContractKind.preContract ? 0 : 1));

  /// 選手の求める週俸。分からなければ 0。
  int _demand(GameState game) => switch (kind) {
        ContractKind.signing => game.talkFor(p.id)?.demandWage ?? 0,
        ContractKind.renewal =>
          game.pendingContractNegotiation?.counterWage ?? 0,
        ContractKind.preContract =>
          game.preContractWageDemand(p, option: _option),
      };

  int _roundsUsed(GameState game) => switch (kind) {
        ContractKind.signing => game.talkFor(p.id)?.termsRound ?? 0,
        ContractKind.renewal =>
          game.pendingContractNegotiation?.roundsUsed ?? 0,
        ContractKind.preContract => 0,
      };

  int get _maxRounds => switch (kind) {
        ContractKind.signing => PlayerTermsEngine.maxRounds,
        ContractKind.renewal => ContractEngine.maxNegotiationRounds,
        ContractKind.preContract => 1,
      };

  /// 所属なしの選手との話か(移籍金の代わりに契約金がかかる)。
  bool _isFreeAgent(GameState game) =>
      kind == ContractKind.signing && game.freeAgents.any((q) => q.id == p.id);

  /// 所属なしの選手が必ず求める契約金の最低額(それ以外は0)。
  int _requiredBonus(GameState game) =>
      _isFreeAgent(game) ? game.freeAgentSigningFeeFor(p) : 0;

  int _transferFee(GameState game) {
    if (kind != ContractKind.signing) return 0;
    final t = game.talkFor(p.id);
    if (t == null || t.freeAgent) return 0;
    return t.fee;
  }

  int _agentFee(GameState game) => switch (kind) {
        // 所属なしの選手は移籍金が無いので、年俸に対する割合で払う。
        ContractKind.signing => _isFreeAgent(game)
            ? game.freeAgentAgentFeeFor(p, _wage)
            : (_transferFee(game) * RelationsEngine.agentOf(p).feePercent / 100)
                .round(),
        ContractKind.renewal => ContractEngine.renewalCost(p),
        ContractKind.preContract => 0,
      };

  /// 更新で払う一時金。移籍では提示したサイン料(所属なしの選手は最低額以上)。
  int _signingBonus([GameState? game]) => switch (kind) {
        ContractKind.signing =>
          game == null ? _bonus : max(_bonus, _requiredBonus(game)),
        ContractKind.renewal => ContractEngine.signingBonusFor(p),
        ContractKind.preContract => 0,
      };

  int _bonusMax(GameState game) => max(
      10,
      max(annualFromWeekly(max(p.wage, _demand(game)) * 2),
          _transferFee(game) ~/ 10));

  int _wageStep(GameState game) {
    final ref = max(p.wage, _demand(game));
    return max(1, (ref * 0.05).round());
  }

  // ---- 提示 ----

  Future<void> _submit() async {
    final game = context.read<GameState>();
    setState(() => _busy = true);
    switch (kind) {
      case ContractKind.signing:
        final out = await game.offerPersonalTerms(p.id,
            weeklyWage: _wage,
            endYear: _endYear,
            signingBonus: _bonus,
            promise: _promise);
        if (!mounted) return;
        switch (out) {
          case TermsOutcome.signed:
            _finish(Tr.pick('${p.name}と契約しました', 'You signed ${p.name}'));
            return;
          case TermsOutcome.counter:
            final want = game.talkFor(p.id)?.demandWage ?? 0;
            _say(
                Tr.pick(
                    '代理人: 足りません。年俸${formatMoney(annualFromWeekly(want))}ほど(サイン料を年数でならした分を含めて)は欲しい。',
                    'Agent: Not enough. He wants about ${formatMoney(annualFromWeekly(want))} a year, counting the bonus spread over the deal.'),
                _ReplyTone.neutral);
          case TermsOutcome.refused:
            _closed = true;
            _say(
                game.lastSigningBlockReason ??
                    Tr.pick('話は流れました。', 'The talks are off.'),
                _ReplyTone.bad);
          case TermsOutcome.blocked:
            _say(
                game.lastSigningBlockReason ??
                    Tr.pick('いまは条件を出せません。', 'You cannot make an offer now.'),
                _ReplyTone.bad);
        }
      case ContractKind.renewal:
        final r = await game.offerContractWage(_wage);
        if (!mounted) return;
        switch (r) {
          case ContractOfferResult.accepted:
            _finish(Tr.pick(
                '${p.name}と契約を更新しました', 'You renewed ${p.name}\'s contract'));
            return;
          case ContractOfferResult.countered:
            final want = game.pendingContractNegotiation?.counterWage ?? 0;
            _say(
                Tr.pick('代理人: 年俸${formatMoney(annualFromWeekly(want))}なら考えます。',
                    'Agent: ${formatMoney(annualFromWeekly(want))} a year and we can talk.'),
                _ReplyTone.neutral);
          case ContractOfferResult.insufficientFunds:
            _say(
                Tr.pick('資金が足りません(手数料と一時金を先に払います)。',
                    'Not enough money: the fee and bonus are paid up front.'),
                _ReplyTone.bad);
          case ContractOfferResult.walkedAway:
            _closed = true;
            _say(
                Tr.pick('代理人: これ以上は話せません。今季が終わると無償で出ていきます。',
                    'Agent: We are done here. He will leave for free when his deal runs out.'),
                _ReplyTone.bad);
        }
      case ContractKind.preContract:
        final ok = await game.signPreContract(p.id,
            endYear: _endYear, option: _option);
        if (!mounted) return;
        if (ok) {
          _finish(Tr.pick('${p.name}と仮契約を結びました(7月1日に加入)',
              'Pre-contract agreed with ${p.name} (joins on 1 Jul)'));
          return;
        }
        _say(
            game.lastSigningBlockReason ??
                Tr.pick('仮契約を結べませんでした。', 'The pre-contract fell through.'),
            _ReplyTone.bad);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _say(String text, _ReplyTone tone) {
    tone == _ReplyTone.bad ? FeedbackService.error() : FeedbackService.tap();
    setState(() {
      _reply = text;
      _tone = tone;
      // 返された額を、次の提示の起点にする。
      final want = _demand(context.read<GameState>());
      if (want > 0 && kind == ContractKind.renewal) _wage = want;
    });
  }

  void _finish(String text) {
    FeedbackService.success();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    Navigator.of(context).pop(true);
  }

  void _walkAway() {
    if (kind == ContractKind.renewal) {
      context.read<GameState>().cancelContractNegotiation();
    }
    Navigator.of(context).pop(false);
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final title = switch (kind) {
      ContractKind.signing => Tr.pick('契約の交渉', 'Contract negotiation'),
      ContractKind.renewal => Tr.pick('契約の更新', 'Contract renewal'),
      ContractKind.preContract => Tr.pick('仮契約の交渉', 'Pre-contract talks'),
    };
    return Scaffold(
      appBar: AppBar(title: Text('$title • ${p.name}')),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final side = _sidePanel(context, game);
          final table = _termsTable(context, game, narrow: !wide);
          if (wide) {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: 230,
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(8), child: side)),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _replyBanner(context),
                              const SizedBox(height: 6),
                              table,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _bottomBar(context, game, narrow: false),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    side,
                    const SizedBox(height: 8),
                    _replyBanner(context),
                    const SizedBox(height: 6),
                    table,
                  ],
                ),
              ),
              _bottomBar(context, game, narrow: true),
            ],
          );
        }),
      ),
    );
  }

  Widget _sidePanel(BuildContext context, GameState game) {
    final theme = Theme.of(context);
    final agent = RelationsEngine.agentOf(p);
    final talk = kind == ContractKind.signing ? game.talkFor(p.id) : null;
    final used = _roundsUsed(game);
    final left = max(0, _maxRounds - used);
    const small = TextStyle(fontSize: 12);
    final club = switch (kind) {
      ContractKind.renewal => game.userTeam.name,
      _ =>
        widget.fromClubName ?? talk?.clubName ?? Tr.pick('所属なし', 'Free agent'),
    };
    Widget kv(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            children: [
              Expanded(
                  child: Text(k,
                      style: small.copyWith(
                          color: SemanticColors.subtleText(context)))),
              Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: small.copyWith(
                        fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PlayerFaceAvatar(playerId: p.id, position: p.position, size: 48),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text(
                      Tr.pick('${p.position.label}・${p.age}歳・総合${p.overall}',
                          '${p.position.label} • ${p.age} • OVR ${p.overall}'),
                      style: small),
                  Text(club,
                      style: small.copyWith(
                          color: SemanticColors.subtleText(context)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 14),
        kv(Tr.pick('いまの年俸', 'Current salary'),
            formatMoney(annualFromWeekly(p.wage))),
        kv(Tr.pick('いまの契約', 'Current contract'),
            ContractEngine.untilLabel(p.contractEndYear)),
        kv(Tr.pick('市場価値', 'Value'), formatMoney(p.marketValue)),
        if (_transferFee(game) > 0)
          kv(Tr.pick('決まった移籍金', 'Agreed fee'), formatMoney(_transferFee(game))),
        const Divider(height: 14),
        kv(Tr.pick('代理人', 'Agent'), agent.label),
        Text(agent.description,
            style: TextStyle(
                fontSize: 11, color: SemanticColors.subtleText(context))),
        if (talk != null && talk.hasRival) ...[
          const SizedBox(height: 4),
          Text(
            Tr.pick(
                '${talk.rivalClubName}も年俸${formatMoney(annualFromWeekly(talk.rivalWage))}で誘っています。',
                '${talk.rivalClubName} offer ${formatMoney(annualFromWeekly(talk.rivalWage))} a year too.'),
            style: TextStyle(
                fontSize: 12,
                color: SemanticColors.ink(context, Colors.orange.shade800)),
          ),
        ],
        if (kind != ContractKind.preContract) ...[
          const Divider(height: 14),
          Text(Tr.pick('代理人の我慢', "Agent's patience"),
              style: small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < _maxRounds; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < left
                          ? (left == 1
                              ? SemanticColors.negative(context)
                              : theme.colorScheme.primary)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(Tr.pick('あと$left回、条件を出せます', '${Tr.plural(left, 'offer')} left'),
              style: TextStyle(
                  fontSize: 11, color: SemanticColors.subtleText(context))),
        ],
      ],
    );
  }

  Widget _replyBanner(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (_tone) {
      _ReplyTone.bad => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer
        ),
      _ReplyTone.good => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer
        ),
      _ReplyTone.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_outlined, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_reply ?? '',
                  style: TextStyle(fontSize: 13, color: fg))),
        ],
      ),
    );
  }

  Widget _termsTable(BuildContext context, GameState game,
      {required bool narrow}) {
    final theme = Theme.of(context);
    final demand = _demand(game);
    final unknown = Tr.pick('提示すると分かる', 'Ask to find out');
    final fixed = Tr.pick('決まり', 'Set');
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: SemanticColors.subtleText(context));
    const cell = TextStyle(fontSize: 13);
    final bold = cell.copyWith(fontWeight: FontWeight.bold);
    final rows = <Widget>[];

    void row(String label, Widget want, Widget offer, {String? note}) {
      rows.add(Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: () {
          final name = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: bold),
              if (note != null)
                Text(note,
                    style: TextStyle(
                        fontSize: 10,
                        color: SemanticColors.subtleText(context))),
            ],
          );
          // 狭い画面では、提示の欄を下の段に回す。
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(flex: 3, child: name),
                  Expanded(flex: 3, child: want),
                ]),
                Align(alignment: Alignment.centerLeft, child: offer),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: name),
              Expanded(flex: 3, child: want),
              Expanded(flex: 5, child: offer),
            ],
          );
        }(),
      ));
    }

    Text t(String s, {TextStyle? style}) =>
        Text(s, style: style ?? cell, overflow: TextOverflow.ellipsis);

    // 年俸
    final wageEditable = kind != ContractKind.preContract && !_closed;
    final meets = demand > 0 && _wage >= demand;
    row(
      Tr.pick('年俸', 'Salary'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          t(demand > 0 ? formatMoney(annualFromWeekly(demand)) : unknown,
              style: demand > 0 ? bold : cell),
          if (wageEditable && demand > 0 && _wage != demand)
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => setState(() => _wage = demand),
              child: Text(Tr.pick('要求に合わせる', 'Match it'),
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      wageEditable
          ? _Stepper(
              label: formatMoney(annualFromWeekly(_wage)),
              color: demand > 0
                  ? (meets
                      ? theme.colorScheme.primary
                      : SemanticColors.negative(context))
                  : null,
              onMinus: _wage > minWeeklyWage
                  ? () => setState(
                      () => _wage = max(minWeeklyWage, _wage - _wageStep(game)))
                  : null,
              onPlus: () => setState(() => _wage += _wageStep(game)),
            )
          : t(formatMoney(annualFromWeekly(demand)), style: bold),
      note: kind == ContractKind.preContract
          ? Tr.pick('仮契約は要求どおり', 'Fixed for a pre-contract')
          : null,
    );

    // 契約の期間
    final choices = _endChoices();
    row(
      Tr.pick('契約の期間', 'Contract length'),
      t(ContractEngine.untilLabel(kind == ContractKind.preContract
          ? PreContractEngine.defaultEndYear(p)
          : (kind == ContractKind.renewal
              ? ContractEngine.defaultRenewalEndYear(p)
              : _endYear))),
      choices.length <= 1 || _closed
          ? t(ContractEngine.untilLabel(_endYear))
          : Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<int>(
                value: choices.contains(_endYear) ? _endYear : choices.last,
                isDense: true,
                items: [
                  for (final y in choices)
                    DropdownMenuItem(
                        value: y,
                        child: Text(ContractEngine.untilLabel(y), style: cell)),
                ],
                onChanged: (y) {
                  if (y == null) return;
                  setState(() {
                    _endYear = y;
                    if (!_canOption()) _option = false;
                  });
                  if (kind == ContractKind.renewal) {
                    game.setNegotiationTerms(endYear: y);
                  }
                },
              ),
            ),
      note: Tr.pick('${_years()}年', '${_years()} yrs'),
    );

    // 序列の約束(移籍のときだけ)
    if (kind == ContractKind.signing) {
      row(
        Tr.pick('序列の約束', 'Squad status'),
        t(SquadStatus.regular.label),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<SquadStatus>(
            value: _promise,
            isDense: true,
            items: [
              for (final s in SquadStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label, style: cell)),
            ],
            onChanged: _closed
                ? null
                : (s) => setState(() => _promise = s ?? _promise),
          ),
        ),
        note: switch (_promise) {
          SquadStatus.keyPlayer => Tr.pick(
              '要求 +15%・3節外すと怒る', 'Wants 15% more; 3 games out and he is upset'),
          SquadStatus.regular =>
            Tr.pick('5節外すと怒る', '5 games out and he is upset'),
          SquadStatus.rotation => Tr.pick('要求 -8%', 'Wants 8% less'),
          SquadStatus.prospect => Tr.pick('要求 -15%', 'Wants 15% less'),
        },
      );
    }

    // サイン料
    if (kind == ContractKind.signing) {
      final required = _requiredBonus(game);
      final maxB = max(_bonusMax(game), required * 3);
      final step = max(1, maxB ~/ 20);
      row(
        Tr.pick('サイン料', 'Signing bonus'),
        t(required > 0 ? formatMoney(required) : '—'),
        _Stepper(
          label: formatMoney(_bonus),
          onMinus: _bonus > required && !_closed
              ? () => setState(() => _bonus = max(required, _bonus - step))
              : null,
          onPlus: _bonus < maxB && !_closed
              ? () => setState(() => _bonus = min(maxB, _bonus + step))
              : null,
        ),
        note: required > 0
            ? Tr.pick('所属なしの選手は契約金を必ず求める。超えた分は年数でならして見られる',
                'Free agents insist on a signing bonus; anything above it is spread over the deal')
            : Tr.pick('年数でならして年俸に足して見られる', 'Spread over the deal'),
      );
    } else if (kind == ContractKind.renewal) {
      row(Tr.pick('サイン料', 'Signing bonus'),
          t(formatMoney(_signingBonus()), style: bold), t(fixed));
    }

    // 延長オプション
    if (kind != ContractKind.signing) {
      final can = _canOption();
      row(
        Tr.pick('1年の延長オプション', '1-year club option'),
        t(Tr.pick('年俸 +5%', 'Salary +5%')),
        Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: _option,
            onChanged: can && !_closed
                ? (v) {
                    setState(() => _option = v);
                    if (kind == ContractKind.renewal) {
                      game.setNegotiationTerms(option: v);
                      final n = game.pendingContractNegotiation;
                      if (n != null) setState(() => _wage = n.counterWage);
                    }
                  }
                : null,
          ),
        ),
        note: can
            ? Tr.pick('クラブが決めれば1年延びる', 'The club can add a year')
            : Tr.pick('最長の期間なので付けられない', 'Not at the longest length'),
      );
    }

    // 代理人手数料
    if (kind != ContractKind.preContract) {
      row(
        Tr.pick('代理人手数料', 'Agent fee'),
        t(formatMoney(_agentFee(game)), style: bold),
        t(fixed),
        note: kind == ContractKind.signing
            ? (_isFreeAgent(game)
                ? Tr.pick('年俸の${RelationsEngine.agentOf(p).feePercent}%',
                    '${RelationsEngine.agentOf(p).feePercent}% of the salary')
                : Tr.pick('移籍金の${RelationsEngine.agentOf(p).feePercent}%',
                    '${RelationsEngine.agentOf(p).feePercent}% of the fee'))
            : null,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                    flex: 3, child: Text(Tr.pick('項目', 'Term'), style: head)),
                Expanded(
                    flex: 3,
                    child: Text(Tr.pick('選手の要求', 'He wants'), style: head)),
                Expanded(
                    flex: 5,
                    child: Text(Tr.pick('こちらの提示', 'Your offer'), style: head)),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, GameState game,
      {required bool narrow}) {
    final theme = Theme.of(context);
    final years = _years();
    final annual = annualFromWeekly(_wage);
    final upfront = _signingBonus(game) + _agentFee(game) + _transferFee(game);
    final total = annual * years + upfront;
    // 給与の枠: 更新は今の年俸を差し替える。
    final bill = game.weeklyWageBill -
        (kind == ContractKind.renewal ? p.wage : 0) +
        _wage;
    final cap = game.wageBudgetCap;
    final over = cap > 0 && bill > cap;
    const small = TextStyle(fontSize: 12);
    final canOffer = !_busy && !_closed;
    final info = Wrap(
      spacing: 14,
      runSpacing: 2,
      children: [
        Text(
            Tr.pick('契約の総額 ${formatMoney(total)}',
                'Total cost ${formatMoney(total)}'),
            style: small.copyWith(fontWeight: FontWeight.bold)),
        Text(
            Tr.pick('いま払う ${formatMoney(upfront)}',
                'Up front ${formatMoney(upfront)}'),
            style: small),
        Text(
          Tr.pick(
              '年俸の総額 ${formatMoney(annualFromWeekly(bill))} / 枠 ${formatMoney(annualFromWeekly(cap))}',
              'Wage bill ${formatMoney(annualFromWeekly(bill))} / cap ${formatMoney(annualFromWeekly(cap))}'),
          style: small.copyWith(
              color: over ? SemanticColors.negative(context) : null),
        ),
      ],
    );
    final buttons = [
      TextButton(
        onPressed: _busy ? null : _walkAway,
        child: Text(
            _closed ? Tr.pick('閉じる', 'Close') : Tr.pick('交渉をやめる', 'Walk away')),
      ),
      const SizedBox(width: 4),
      FilledButton(
        key: const ValueKey('contract-offer-submit'),
        onPressed: canOffer ? _submit : null,
        child: Text(kind == ContractKind.preContract
            ? Tr.pick('仮契約を結ぶ', 'Agree')
            : Tr.pick('提示する', 'Offer')),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: narrow
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: buttons),
              ],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 8),
                ...buttons,
              ],
            ),
    );
  }
}

/// [-] 金額 [+]。
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    this.onMinus,
    this.onPlus,
    this.color,
  });

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: Tr.pick('下げる', 'Lower'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onMinus,
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ),
        IconButton(
          tooltip: Tr.pick('上げる', 'Raise'),
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onPlus,
        ),
      ],
    );
  }
}
