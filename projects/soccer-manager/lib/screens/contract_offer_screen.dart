import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/contract_terms.dart';
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
import '../widgets/negotiation_table.dart';
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

/// 契約の交渉の画面。左に選手と代理人、右に項目ごとの「選手の要求」と
/// 「こちらの提示」、下に契約の総額と給与の枠。提示すると代理人の返事が
/// 上の帯に出て、要求の列が書き換わる。
///
/// 2026-11-25: 更新でも序列の約束・サイン料を交渉でき、出来高・年ごとの
/// 昇給・リリース条項・降格/昇格の条項を交渉の項目にした(以前は選手の
/// 詳しい画面の「契約」のタブで、交渉なしに付け替えられた)。横画面では
/// 表を2列に割って1画面に収める。部品は widgets/negotiation_table.dart
/// (スタッフの契約と同じ形)。
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

class _ContractOfferScreenState extends State<ContractOfferScreen> {
  late int _wage; // 週俸(万円)。表示は年俸。
  late int _endYear;
  int _bonus = 0;
  SquadStatus _promise = SquadStatus.regular;
  bool _option = false;
  int _goalBonus = 0;
  int _raisePct = 0;
  int? _clause;
  int? _relegationCut;
  int _promotionRise = 0;
  bool _busy = false;
  bool _closed = false; // 話が流れた
  String? _reply;
  NegotiationTone _tone = NegotiationTone.neutral;

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
        // スペインのクラブは条項が必ず付く(既定の額から始める)。
        if (game.releaseClausesRequired) {
          _clause = (p.marketValue * 3).round();
        }
      case ContractKind.renewal:
        final pending = game.pendingContractNegotiation;
        final started = pending?.playerId == p.id ? pending : null;
        final base = game.renewalBaseline(p, n: started);
        _wage = base.wage;
        _endYear = base.endYear;
        _option = base.option;
        _promise = base.promise;
        _bonus = base.signingBonus;
        _clause = base.releaseClause;
        _relegationCut = base.relegationCutPct;
        _promotionRise = base.promotionRisePct;
        if (started == null) {
          _closed = true;
          _reply = game.lastSigningBlockReason;
          _tone = NegotiationTone.bad;
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

  /// 選手が求めるサイン料(移籍: 所属なしの最低額、更新: 既定の額)。
  int _requiredBonus(GameState game) => switch (kind) {
        ContractKind.signing =>
          _isFreeAgent(game) ? game.freeAgentSigningFeeFor(p) : 0,
        ContractKind.renewal => ContractEngine.signingBonusFor(p),
        ContractKind.preContract => 0,
      };

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

  /// いま払うサイン料。
  int _signingBonus(GameState game) => switch (kind) {
        ContractKind.signing => max(_bonus, _requiredBonus(game)),
        ContractKind.renewal => _bonus,
        ContractKind.preContract => 0,
      };

  int _bonusMax(GameState game) => max(
      10,
      max(
          max(annualFromWeekly(max(p.wage, _demand(game)) * 2),
              _transferFee(game) ~/ 10),
          _requiredBonus(game) * 3));

  int _wageStep(GameState game) {
    final ref = max(p.wage, _demand(game));
    return max(1, (ref * 0.05).round());
  }

  /// 今の画面の条件の一式。
  ContractTerms _terms() => ContractTerms(
        wage: _wage,
        endYear: _endYear,
        option: _option,
        promise: _promise,
        signingBonus: _bonus,
        goalBonus: _goalBonus,
        raisePct: _raisePct,
        releaseClause: _clause,
        relegationCutPct: _relegationCut,
        promotionRisePct: _promotionRise,
      );

  /// 条項(出来高・昇給・リリース・降格/昇格)を交渉できるか。
  bool get _hasClauses => kind != ContractKind.preContract;

  /// 選手から見た、年俸以外の項目の値打ち(1週あたり)。
  int _extras(GameState game, [ContractTerms? t]) {
    final terms = t ?? _terms();
    if (!_hasClauses) return 0;
    if (kind == ContractKind.renewal) {
      return game.renewalExtrasWeekly(p, terms);
    }
    int value(ContractTerms x) => ContractTermsEngine.extrasWeekly(p, x,
        requiredBonus: 0,
        defaultRelegationCutPct: game.defaultRelegationCutPct,
        years: _years());
    // 移籍のサイン料は別に年数でならす(PlayerTermsEngine)。ここは条項だけ。
    return value(terms.copyWith(signingBonus: 0)) -
        value(ContractTerms(wage: _wage, endYear: _endYear));
  }

  /// 選手から見た実質の週俸(移籍は、所属なしの最低額を超えたサイン料も含む)。
  int _effective(GameState game) {
    var e = _wage + _extras(game);
    if (kind == ContractKind.signing) {
      e += (max(0, _bonus - _requiredBonus(game)) / (52 * _years())).round();
    }
    return e;
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
            promise: _promise,
            clauses: _terms());
        if (!mounted) return;
        switch (out) {
          case TermsOutcome.signed:
            _finish(Tr.pick('${p.name}と契約しました', 'You signed ${p.name}'));
            return;
          case TermsOutcome.counter:
            final want = game.talkFor(p.id)?.demandWage ?? 0;
            _say(
                Tr.pick(
                    '代理人: 足りません。年俸${formatMoney(annualFromWeekly(want))}ほど(サイン料や条項をならした分を含めて)は欲しい。',
                    'Agent: Not enough. He wants about ${formatMoney(annualFromWeekly(want))} a year, counting the bonus and clauses.'),
                NegotiationTone.neutral);
          case TermsOutcome.refused:
            _closed = true;
            _say(
                game.lastSigningBlockReason ??
                    Tr.pick('話は流れました。', 'The talks are off.'),
                NegotiationTone.bad);
          case TermsOutcome.blocked:
            _say(
                game.lastSigningBlockReason ??
                    Tr.pick('いまは条件を出せません。', 'You cannot make an offer now.'),
                NegotiationTone.bad);
        }
      case ContractKind.renewal:
        final r = await game.offerContractTerms(_terms());
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
                NegotiationTone.neutral);
          case ContractOfferResult.insufficientFunds:
            _say(
                Tr.pick('資金が足りません(手数料とサイン料を先に払います)。',
                    'Not enough money: the fee and bonus are paid up front.'),
                NegotiationTone.bad);
          case ContractOfferResult.walkedAway:
            _closed = true;
            _say(
                Tr.pick('代理人: これ以上は話せません。今季が終わると無償で出ていきます。',
                    'Agent: We are done here. He will leave for free when his deal runs out.'),
                NegotiationTone.bad);
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
            NegotiationTone.bad);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _say(String text, NegotiationTone tone) {
    tone == NegotiationTone.bad
        ? FeedbackService.error()
        : FeedbackService.tap();
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
    final screen = MediaQuery.sizeOf(context);
    final landscape = screen.width > screen.height;
    return Scaffold(
      appBar: AppBar(
        // 横画面は高さが足りないので、上の帯を低くする(表を1画面に収める)。
        toolbarHeight: landscape ? 44 : null,
        title: Text('$title • ${p.name}', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: NegotiationLayout(
          side: _sidePanel(context, game),
          banner: NegotiationReplyBanner(text: _reply ?? '', tone: _tone),
          table: (wide) => NegotiationTable(
            rows: _rows(context, game),
            columns: wide ? 2 : 1,
            compact: wide,
            wantHeader: Tr.pick('選手の要求', 'He wants'),
          ),
          bottom: (narrow) => _bottomBar(context, game, narrow: narrow),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 1),
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
            PlayerFaceAvatar(playerId: p.id, position: p.position, size: 40),
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
        const Divider(height: 12),
        kv(Tr.pick('いまの年俸', 'Current salary'),
            formatMoney(annualFromWeekly(p.wage))),
        kv(Tr.pick('いまの契約', 'Current contract'),
            ContractEngine.untilLabel(p.contractEndYear)),
        if (kind == ContractKind.renewal)
          kv(Tr.pick('いまの序列', 'Current status'), p.squadStatus.label),
        kv(Tr.pick('市場価値', 'Value'), formatMoney(p.marketValue)),
        if (_transferFee(game) > 0)
          kv(Tr.pick('決まった移籍金', 'Agreed fee'), formatMoney(_transferFee(game))),
        const Divider(height: 12),
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
          const Divider(height: 12),
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

  /// 選手から見た1つの項目の値打ちを、年俸の何円分かで書く(0なら null)。
  String? _worth(GameState game, ContractTerms only) {
    final base = kind == ContractKind.renewal
        ? game.renewalBaseline(p).copyWith(
            wage: _wage, endYear: _endYear, promise: _promise)
        : ContractTerms(wage: _wage, endYear: _endYear);
    final v = _extras(game, only) - _extras(game, base);
    if (v == 0) return null;
    final annual = annualFromWeekly(v.abs());
    return v > 0
        ? Tr.pick('年俸+${formatMoney(annual)}相当', 'worth +${formatMoney(annual)}/yr')
        : Tr.pick('年俸-${formatMoney(annual)}相当', 'worth -${formatMoney(annual)}/yr');
  }

  List<NegotiationRow> _rows(BuildContext context, GameState game) {
    final theme = Theme.of(context);
    final demand = _demand(game);
    final unknown = Tr.pick('提示すると分かる', 'Ask to find out');
    final fixed = Tr.pick('決まり', 'Set');
    const cell = TextStyle(fontSize: 12.5);
    final bold = cell.copyWith(fontWeight: FontWeight.bold);
    final subtle = SemanticColors.subtleText(context);
    final rows = <NegotiationRow>[];
    final open = !_closed;
    Text t(String s, {TextStyle? style}) =>
        Text(s, style: style ?? cell, overflow: TextOverflow.ellipsis);
    Text hint(String s) => Text(s,
        style: TextStyle(fontSize: 11, color: subtle),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
    final base = kind == ContractKind.renewal
        ? game.renewalBaseline(p)
            .copyWith(wage: _wage, endYear: _endYear, promise: _promise)
        : ContractTerms(wage: _wage, endYear: _endYear);

    // 年俸
    final wageEditable = kind != ContractKind.preContract && open;
    final meets = demand > 0 && _effective(game) >= demand;
    rows.add(NegotiationRow(
      key: const ValueKey('term-wage'),
      label: Tr.pick('年俸', 'Salary'),
      want: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          t(demand > 0 ? formatMoney(annualFromWeekly(demand)) : unknown,
              style: demand > 0 ? bold : cell),
          if (wageEditable && demand > 0 && _wage != demand)
            InkWell(
              onTap: () => setState(() => _wage = demand),
              child: Text(Tr.pick('要求に合わせる', 'Match it'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline)),
            ),
        ],
      ),
      offer: wageEditable
          ? NegotiationStepper(
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
    ));

    // 契約の期間
    final choices = _endChoices();
    rows.add(NegotiationRow(
      label: Tr.pick('契約の期間', 'Contract length'),
      want: t(ContractEngine.untilLabel(kind == ContractKind.preContract
          ? PreContractEngine.defaultEndYear(p)
          : (kind == ContractKind.renewal
              ? ContractEngine.defaultRenewalEndYear(p)
              : _endYear))),
      offer: choices.length <= 1 || !open
          ? t(ContractEngine.untilLabel(_endYear))
          : NegotiationChoice<int>(
              value: choices.contains(_endYear) ? _endYear : choices.last,
              items: choices,
              labelOf: ContractEngine.untilLabel,
              onChanged: (y) {
                setState(() {
                  _endYear = y;
                  if (!_canOption()) _option = false;
                });
                if (kind == ContractKind.renewal) {
                  game.setNegotiationTerms(endYear: y);
                }
              },
            ),
      note: Tr.pick('${_years()}年', '${_years()} yrs'),
    ));

    // 序列の約束(移籍・更新)
    if (kind != ContractKind.preContract) {
      final current =
          kind == ContractKind.renewal ? p.squadStatus : SquadStatus.regular;
      rows.add(NegotiationRow(
        label: Tr.pick('序列の約束', 'Squad status'),
        want: t(current.label),
        offer: NegotiationChoice<SquadStatus>(
          value: _promise,
          items: SquadStatus.values,
          labelOf: (s) => s.label,
          onChanged: !open
              ? null
              : (s) {
                  setState(() => _promise = s);
                  if (kind == ContractKind.renewal) {
                    game.setNegotiationTerms(promise: s);
                    final n = game.pendingContractNegotiation;
                    if (n != null) setState(() => _wage = n.counterWage);
                  }
                },
        ),
        note: switch (_promise) {
          SquadStatus.keyPlayer => Tr.pick(
              '要求 +15%・3節外すと怒る', 'Wants 15% more; 3 games out and he is upset'),
          SquadStatus.regular =>
            Tr.pick('5節外すと怒る', '5 games out and he is upset'),
          SquadStatus.rotation => Tr.pick('要求 -8%', 'Wants 8% less'),
          SquadStatus.prospect => Tr.pick('要求 -15%', 'Wants 15% less'),
        },
      ));
    }

    // サイン料
    if (kind != ContractKind.preContract) {
      final required = _requiredBonus(game);
      final minB = kind == ContractKind.signing ? required : 0;
      final maxB = _bonusMax(game);
      final step = max(1, max(required, annualFromWeekly(_wage)) ~/ 10);
      rows.add(NegotiationRow(
        key: const ValueKey('term-bonus'),
        label: Tr.pick('サイン料', 'Signing bonus'),
        want: t(required > 0 ? formatMoney(required) : '—',
            style: required > 0 ? bold : cell),
        offer: NegotiationStepper(
          label: formatMoney(_bonus),
          onMinus: _bonus > minB && open
              ? () => setState(() => _bonus = max(minB, _bonus - step))
              : null,
          onPlus: _bonus < maxB && open
              ? () => setState(() => _bonus = min(maxB, _bonus + step))
              : null,
        ),
        note: kind == ContractKind.renewal
            ? Tr.pick('要求より少ないと年俸を上げて求める',
                'Less than he asks and he wants more salary')
            : (required > 0
                ? Tr.pick('所属なしの選手は契約金を必ず求める',
                    'Free agents insist on a signing bonus')
                : Tr.pick('年数でならして年俸に足して見られる', 'Spread over the deal')),
      ));
    }

    // 延長オプション
    if (kind != ContractKind.signing) {
      final can = _canOption();
      rows.add(NegotiationRow(
        label: Tr.pick('1年の延長オプション', '1-year club option'),
        want: t(Tr.pick('年俸 +5%', 'Salary +5%')),
        offer: Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: _option,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: can && open
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
      ));
    }

    if (_hasClauses) {
      // 出来高
      final goalStep = max(1, (_wage * 0.25).round());
      final goalMax = max(goalStep * 12, _wage * 3);
      rows.add(NegotiationRow(
        key: const ValueKey('term-goal-bonus'),
        label: Tr.pick('出来高(1点ごと)', 'Goal bonus'),
        want: hint(_worth(game, base.copyWith(goalBonus: _goalBonus)) ??
            Tr.pick('あれば喜ぶ', 'Welcome')),
        offer: NegotiationStepper(
          label: _goalBonus == 0
              ? Tr.pick('なし', 'None')
              : formatMoney(_goalBonus),
          onMinus: _goalBonus > 0 && open
              ? () => setState(() => _goalBonus = max(0, _goalBonus - goalStep))
              : null,
          onPlus: _goalBonus < goalMax && open
              ? () => setState(
                  () => _goalBonus = min(goalMax, _goalBonus + goalStep))
              : null,
        ),
        note: Tr.pick(
            '見込み 1季${ContractTermsEngine.expectedGoals(p).round()}点',
            'About ${ContractTermsEngine.expectedGoals(p).round()} goals a season'),
      ));
      // 年ごとの昇給
      rows.add(NegotiationRow(
        label: Tr.pick('年ごとの昇給', 'Yearly rise'),
        want: hint(_worth(game, base.copyWith(raisePct: _raisePct)) ??
            Tr.pick('あれば喜ぶ', 'Welcome')),
        offer: NegotiationChoice<int>(
          value: _raisePct,
          items: ContractTermsEngine.raiseChoices,
          labelOf: (v) => v == 0
              ? Tr.pick('なし', 'None')
              : Tr.pick('毎年+$v%', '+$v% a year'),
          onChanged: !open ? null : (v) => setState(() => _raisePct = v),
        ),
        note: Tr.pick('2年目から上がる', 'From the second year'),
      ));
      // リリース条項
      final required = game.releaseClausesRequired;
      final clauseOptions = <int?>[
        if (!required) null,
        for (final m in ContractTermsEngine.releaseMultiples)
          if (m > 0) (p.marketValue * m).round(),
      ];
      if (_clause != null && !clauseOptions.contains(_clause)) {
        clauseOptions.add(_clause);
      }
      rows.add(NegotiationRow(
        key: const ValueKey('term-release-clause'),
        label: Tr.pick('リリース条項', 'Release clause'),
        want: hint(_worth(game, base.copyWith(releaseClause: () => _clause)) ??
            Tr.pick('安いほど喜ぶ', 'The lower the better')),
        offer: NegotiationChoice<int?>(
          value: _clause,
          items: clauseOptions,
          labelOf: (v) => v == null
              ? Tr.pick('付けない', 'None')
              : formatMoney(v),
          onChanged: !open ? null : (v) => setState(() => _clause = v),
        ),
        note: required
            ? Tr.pick('スペインでは必ず付く。この額を払うクラブには売るしかない',
                'Required in Spain; any club paying it can take him')
            : Tr.pick('この額を払うクラブには売るしかない',
                'Any club paying this can take him'),
      ));
      // 降格の条項
      final def = game.defaultRelegationCutPct;
      rows.add(NegotiationRow(
        label: Tr.pick('降格の条項', 'Relegation clause'),
        want: hint(_worth(game,
                base.copyWith(relegationCutPct: () => _relegationCut)) ??
            Tr.pick('軽いほど喜ぶ', 'The lighter the better')),
        offer: NegotiationChoice<int?>(
          value: _relegationCut,
          items: [null, ...ContractTermsEngine.relegationChoices],
          labelOf: (v) => v == null
              ? Tr.pick('既定(年俸$def%減)', 'Default (-$def%)')
              : (v == 0
                  ? Tr.pick('下げない', 'No cut')
                  : Tr.pick('年俸$v%減', '-$v%')),
          onChanged: !open ? null : (v) => setState(() => _relegationCut = v),
        ),
        note: Tr.pick('降格したら年俸を下げる', 'Salary cut on relegation'),
      ));
      // 昇格の条項
      rows.add(NegotiationRow(
        label: Tr.pick('昇格の条項', 'Promotion clause'),
        want: hint(_worth(game,
                base.copyWith(promotionRisePct: _promotionRise)) ??
            Tr.pick('あれば喜ぶ', 'Welcome')),
        offer: NegotiationChoice<int>(
          value: _promotionRise,
          items: ContractTermsEngine.promotionChoices,
          labelOf: (v) =>
              v == 0 ? Tr.pick('なし', 'None') : Tr.pick('年俸$v%増', '+$v%'),
          onChanged: !open ? null : (v) => setState(() => _promotionRise = v),
        ),
        note: Tr.pick('昇格したら年俸を上げる', 'Salary rise on promotion'),
      ));
    }

    // 代理人手数料
    if (kind != ContractKind.preContract) {
      rows.add(NegotiationRow(
        label: Tr.pick('代理人手数料', 'Agent fee'),
        want: t(formatMoney(_agentFee(game)), style: bold),
        offer: t(fixed),
        note: kind == ContractKind.signing
            ? (_isFreeAgent(game)
                ? Tr.pick('年俸の${RelationsEngine.agentOf(p).feePercent}%',
                    '${RelationsEngine.agentOf(p).feePercent}% of the salary')
                : Tr.pick('移籍金の${RelationsEngine.agentOf(p).feePercent}%',
                    '${RelationsEngine.agentOf(p).feePercent}% of the fee'))
            : null,
      ));
    }
    return rows;
  }

  Widget _bottomBar(BuildContext context, GameState game,
      {required bool narrow}) {
    final years = _years();
    final terms = _terms();
    final upfront =
        _signingBonus(game) + _agentFee(game) + _transferFee(game);
    final goals = ContractTermsEngine.expectedGoalBonusPerSeason(p, terms);
    final total =
        ContractTermsEngine.totalSalary(terms, years) + goals * years + upfront;
    // 給与の枠: 更新は今の年俸を差し替える。
    final bill = game.weeklyWageBill -
        (kind == ContractKind.renewal ? p.wage : 0) +
        _wage;
    final cap = game.wageBudgetCap;
    final over = cap > 0 && bill > cap;
    const small = TextStyle(fontSize: 12);
    final canOffer = !_busy && !_closed;
    final demand = _demand(game);
    final effective = _effective(game);
    final info = <Widget>[
      Text(
          Tr.pick('契約の総額 ${formatMoney(total)}',
              'Total cost ${formatMoney(total)}'),
          style: small.copyWith(fontWeight: FontWeight.bold)),
      Text(
          Tr.pick('いま払う ${formatMoney(upfront)}',
              'Up front ${formatMoney(upfront)}'),
          style: small),
      if (kind != ContractKind.preContract && demand > 0)
        Text(
          Tr.pick(
              '選手から見た年俸 ${formatMoney(annualFromWeekly(effective))}',
              'Worth to him ${formatMoney(annualFromWeekly(effective))}'),
          key: const ValueKey('contract-effective'),
          style: small.copyWith(
              color: effective >= demand
                  ? Theme.of(context).colorScheme.primary
                  : SemanticColors.negative(context)),
        ),
      Text(
        Tr.pick(
            '年俸の総額 ${formatMoney(annualFromWeekly(bill))} / 枠 ${formatMoney(annualFromWeekly(cap))}',
            'Wage bill ${formatMoney(annualFromWeekly(bill))} / cap ${formatMoney(annualFromWeekly(cap))}'),
        style: small.copyWith(
            color: over ? SemanticColors.negative(context) : null),
      ),
    ];
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
    return NegotiationBottomBar(info: info, buttons: buttons, narrow: narrow);
  }
}
