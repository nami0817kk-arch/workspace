import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/staff_terms.dart';
import '../models/club_infrastructure.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/negotiation_table.dart';

/// スタッフの契約の交渉(2026-11-25 の第6段)。選手の契約と同じ形
/// (左に相手、右に返事の帯と項目の表、下に総額とボタン)。
///
/// 項目: 役職・年俸・期間・サイン料。[renewal] なら雇っている人の結び直し
/// (役職は変えない)。断られるのは[StaffTermsEngine.maxRejections]回まで。
/// 超えると相手は話をやめる(候補なら今月の候補から外れる)。
class StaffNegotiationScreen extends StatefulWidget {
  const StaffNegotiationScreen(
      {super.key, required this.staff, this.renewal = false});

  final StaffMember staff;
  final bool renewal;

  @override
  State<StaffNegotiationScreen> createState() => _StaffNegotiationScreenState();
}

class _StaffNegotiationScreenState extends State<StaffNegotiationScreen> {
  late StaffTerms _ask;
  late StaffTerms _offer;
  String? _reply;
  NegotiationTone _tone = NegotiationTone.neutral;
  int _rejections = 0;
  bool _over = false;

  StaffMember get s => widget.staff;

  @override
  void initState() {
    super.initState();
    _ask = StaffTermsEngine.asking(s, renewal: widget.renewal);
    _offer = _ask;
  }

  void _setRole(StaffRole r) {
    setState(() {
      _ask = StaffTermsEngine.asking(s, role: r, renewal: widget.renewal);
      _offer = _offer.copyWith(role: r, weeklyWage: _ask.weeklyWage);
    });
  }

  /// 週俸の刻み(要求の5%)。
  int get _wageStep => max(1, (_ask.weeklyWage * 0.05).round());

  /// サイン料の刻み(要求の4分の1)。
  int get _bonusStep => max(1, (_ask.signingBonus / 4).round());

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: landscape ? 44 : null,
        title: Text(
            widget.renewal
                ? Tr.pick('契約の結び直し • ${s.name}', 'New contract • ${s.name}')
                : Tr.pick('スタッフの契約 • ${s.name}', 'Staff contract • ${s.name}'),
            overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: NegotiationLayout(
          side: _side(context, gs),
          banner: NegotiationReplyBanner(
              text: _reply ??
                  Tr.pick('条件を決めて「提示する」を押してください。',
                      'Set the terms and press Offer.'),
              tone: _tone),
          table: (wide) => NegotiationTable(
            rows: _rows(context, gs),
            columns: wide ? 2 : 1,
            compact: wide,
            wantHeader:
                wide ? Tr.pick('要求', 'Wants') : Tr.pick('相手の要求', 'He wants'),
          ),
          bottom: (narrow) => _bottom(context, gs, narrow),
        ),
      ),
    );
  }

  String _annual(GameState gs, int weekly) =>
      formatMoney(annualFromWeekly(gs.scaledMoney(weekly)));

  Widget _side(BuildContext context, GameState gs) {
    const small = TextStyle(fontSize: 12);
    final subtle = SemanticColors.subtleText(context);
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Expanded(child: Text(k, style: small.copyWith(color: subtle))),
              // 値は短い(数字・役職)ので幅を取らせず、項目の名前に回す
              // (英語の「Physiotherapy」が割れていた)。
              const SizedBox(width: 6),
              Text(v,
                  textAlign: TextAlign.right,
                  style: small.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        );
    final replaced = widget.renewal ? null : gs.staffReplacedBy(_offer.role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${s.name} (${s.age})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(
            widget.renewal
                ? Tr.pick('いまの役職: ${s.role.label}', 'Now: ${s.role.label}')
                : Tr.pick(
                    '希望の役職: ${s.role.label}', 'Applied as: ${s.role.label}'),
            style: small.copyWith(color: subtle)),
        const SizedBox(height: 6),
        for (final a in StaffAttribute.values) kv(a.label, '${s.attribute(a)}'),
        kv(Tr.pick('この役職での能力', 'Ability in this role'),
            StaffTermsEngine.abilityAs(s, _offer.role).toStringAsFixed(1)),
        if (s.shownSpecialty != StaffSpecialty.balanced)
          kv(Tr.pick('得意分野', 'Speciality'), s.shownSpecialty.label),
        if (widget.renewal)
          kv(Tr.pick('今の年俸', 'Current salary'), _annual(gs, s.wage)),
        const SizedBox(height: 6),
        Text(
          Tr.pick('断られるのはあと${StaffTermsEngine.maxRejections - _rejections}回まで',
              '${StaffTermsEngine.maxRejections - _rejections} rejections left before he walks away'),
          style: small.copyWith(color: subtle),
        ),
        if (replaced != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              Tr.pick(
                  '${_offer.role.label}は枠がいっぱいです。雇うと${replaced.name}と入れ替わります(違約金${formatMoney(gs.staffSeveranceFor(replaced))})。',
                  'The ${_offer.role.label}s are full. He replaces ${replaced.name} (severance ${formatMoney(gs.staffSeveranceFor(replaced))}).'),
              key: const ValueKey('staff-nego-replaces'),
              style: small.copyWith(
                  color: SemanticColors.ink(context, Colors.orange.shade800)),
            ),
          ),
      ],
    );
  }

  List<NegotiationRow> _rows(BuildContext context, GameState gs) {
    final want =
        TextStyle(fontSize: 12.5, color: SemanticColors.subtleText(context));
    final roles = widget.renewal ? [s.role] : StaffTermsEngine.rolesFor(s);
    final perRoleCount = Map.fromEntries([
      for (final r in roles)
        MapEntry(r, '${gs.staffMembersFor(r).length}/${gs.maxStaffFor(r)}'),
    ]);
    return [
      NegotiationRow(
        key: const ValueKey('staff-term-role'),
        label: Tr.pick('役職', 'Role'),
        note: Tr.pick('役職によって効く能力が違います。人数が上限なら入れ替えになります。',
            'Each role uses different abilities. If the department is full, he replaces someone.'),
        want: Text(s.role.label, style: want, overflow: TextOverflow.ellipsis),
        offer: NegotiationChoice<StaffRole>(
          value: _offer.role,
          items: roles,
          labelOf: (r) => ClubInfrastructure.roleAllowsMany(r)
              ? '${r.label} (${perRoleCount[r]})'
              : r.label,
          onChanged: _over || widget.renewal ? null : _setRole,
        ),
      ),
      NegotiationRow(
        key: const ValueKey('staff-term-wage'),
        label: Tr.pick('年俸', 'Salary'),
        note: Tr.pick(
            '要求の9割を割ると断られます。', 'Below 90% of what he asks, he says no.'),
        want: Text(_annual(gs, _ask.weeklyWage), style: want),
        offer: NegotiationStepper(
          label: _annual(gs, _offer.weeklyWage),
          onMinus: _over || _offer.weeklyWage <= _wageStep
              ? null
              : () => setState(() => _offer =
                  _offer.copyWith(weeklyWage: _offer.weeklyWage - _wageStep)),
          onPlus: _over
              ? null
              : () => setState(() => _offer =
                  _offer.copyWith(weeklyWage: _offer.weeklyWage + _wageStep)),
        ),
      ),
      NegotiationRow(
        key: const ValueKey('staff-term-years'),
        label: Tr.pick('期間', 'Length'),
        note: Tr.pick('希望の年数からずれると、その分を上乗せして求められます。',
            'Away from the length he wants, he asks for more.'),
        want: Text(Tr.pick('${_ask.years}年', Tr.plural(_ask.years, 'year')),
            style: want),
        offer: NegotiationChoice<int>(
          value: _offer.years,
          items: StaffTermsEngine.yearChoices,
          labelOf: (y) => Tr.pick(
              '$y年(${Player.contractClockYear + y - 1}/6まで)',
              '${Tr.plural(y, 'year')} (to 6/${Player.contractClockYear + y - 1})'),
          onChanged: _over
              ? null
              : (y) => setState(() => _offer = _offer.copyWith(years: y)),
        ),
      ),
      NegotiationRow(
        key: const ValueKey('staff-term-bonus'),
        label: Tr.pick('サイン料', 'Signing fee'),
        note: Tr.pick('一度だけ払います。年俸を抑える代わりに積むこともできます。',
            'Paid once. You can lean on it to keep the salary down.'),
        want: Text(formatMoney(gs.scaledMoney(_ask.signingBonus)), style: want),
        offer: NegotiationStepper(
          label: formatMoney(gs.scaledMoney(_offer.signingBonus)),
          onMinus: _over || _offer.signingBonus <= 0
              ? null
              : () => setState(() => _offer = _offer.copyWith(
                  signingBonus: max(0, _offer.signingBonus - _bonusStep))),
          onPlus: _over
              ? null
              : () => setState(() => _offer = _offer.copyWith(
                  signingBonus: _offer.signingBonus + _bonusStep)),
        ),
      ),
    ];
  }

  Widget _bottom(BuildContext context, GameState gs, bool narrow) {
    const small = TextStyle(fontSize: 12);
    final total =
        annualFromWeekly(gs.scaledMoney(_offer.weeklyWage)) * _offer.years +
            gs.scaledMoney(_offer.signingBonus);
    return NegotiationBottomBar(
      narrow: narrow,
      info: [
        Text(
            Tr.pick('年俸 ${_annual(gs, _offer.weeklyWage)}',
                'Salary ${_annual(gs, _offer.weeklyWage)}'),
            style: small),
        Text(
            Tr.pick('総額 ${formatMoney(total)}(${_offer.years}年)',
                'Total ${formatMoney(total)} (${Tr.plural(_offer.years, 'year')})'),
            style: small),
        Text(
            Tr.pick('資金 ${formatMoney(gs.save?.budget ?? 0)}',
                'Funds ${formatMoney(gs.save?.budget ?? 0)}'),
            style: small),
      ],
      buttons: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(Tr.pick('やめる', 'Back')),
        ),
        const SizedBox(width: 6),
        FilledButton(
          key: const ValueKey('staff-nego-offer'),
          onPressed: _over ? null : () => _propose(gs),
          child: Text(Tr.pick('提示する', 'Offer')),
        ),
      ],
    );
  }

  Future<void> _propose(GameState gs) async {
    final reply = StaffTermsEngine.reply(_ask, _offer);
    if (!reply.accepted) {
      FeedbackService.error();
      _rejections++;
      if (_rejections >= StaffTermsEngine.maxRejections) {
        if (!widget.renewal) await gs.withdrawStaffCandidate(s.id);
        setState(() {
          _over = true;
          _tone = NegotiationTone.bad;
          _reply = widget.renewal
              ? Tr.pick('今は話をしたくないそうです。しばらく置いてから。',
                  'He does not want to talk about it now. Try again later.')
              : Tr.pick('${s.name}は交渉を打ち切りました。今月の候補から外れます。',
                  '${s.name} has broken off talks and is off this month\'s list.');
        });
        return;
      }
      setState(() {
        _tone = NegotiationTone.bad;
        _reply = StaffTermsEngine.replyText(
            reply, (w) => formatMoney(annualFromWeekly(gs.scaledMoney(w))));
      });
      return;
    }
    final ok = widget.renewal
        ? await gs.renewStaffOnTerms(s.id, _offer)
        : await gs.hireStaffOnTerms(s.id, _offer);
    if (!mounted) return;
    if (!ok) {
      FeedbackService.error();
      setState(() {
        _tone = NegotiationTone.bad;
        _reply = gs.lastSigningBlockReason ??
            Tr.pick('合意はしましたが、契約を結べませんでした。',
                'He agreed, but the contract could not be completed.');
      });
      return;
    }
    FeedbackService.success();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
        content: Text(widget.renewal
            ? Tr.pick('${s.name}と契約を結び直しました', 'New deal agreed with ${s.name}')
            : Tr.pick('${s.name}を${_offer.role.label}に雇いました',
                'Hired ${s.name} as ${_offer.role.label}'))));
  }
}
