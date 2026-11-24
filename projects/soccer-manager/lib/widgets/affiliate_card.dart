import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../models/affiliate_deal.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'disabled_reason.dart';
import 'fm_panel.dart';
import 'help_button.dart';

/// 系列クラブ(2026-11-25 の第6段で FM の提携クラブに寄せた)。
///
/// 提携があれば中身(親子・相手の部と強さ・期間・提携費・項目)を、無ければ
/// 候補の表(部・強さ・どちらが親か・提携費の目安)を出す。結ぶときは
/// 中身(貸し出しの優先・育成先・優先交渉権・売却時の取り分・年数)を選ぶ。
/// 相手は1つまで。
class AffiliateCard extends StatefulWidget {
  const AffiliateCard({super.key});

  @override
  State<AffiliateCard> createState() => _AffiliateCardState();
}

class _AffiliateCardState extends State<AffiliateCard> {
  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final deal = gs.affiliateDeal;
    final club = gs.affiliateClub;
    return FmPanel(
      key: const ValueKey('affiliate-card'),
      title: Tr.pick('系列クラブ', 'Affiliate club'),
      trailing: HelpButton(
        title: Tr.pick('系列クラブ', 'Affiliate club'),
        text: Tr.pick(
            '提携は1つまで。相手が弱ければこちらが親(提携費を払い、若手の貸し出し先・育成先にし、相手の選手を優先して取れ、相手が選手を売ると取り分が入る)。相手が強ければこちらが子(提携費を受け取り、親の若手を借り賃なしで借りられるが、こちらが選手を売ると取り分を渡す)。',
            'One affiliate at a time. Against a weaker club you are the parent: you pay a fee, use them for loans and development, get first refusal on their players and a share of their sales. Against a stronger club you are the feeder: you receive a fee and borrow their youngsters with no loan fee, but they take a share of your sales.'),
      ),
      child: deal != null && club != null
          ? _current(context, gs, deal, club)
          : _candidates(context, gs),
    );
  }

  String _tierLabel(GameState gs, Team t) {
    final tier = gs.affiliateTierOf(t.id);
    return tier == null
        ? Tr.pick('他国', 'Abroad')
        : Tr.pick('$tier部', 'Tier $tier');
  }

  Widget _current(
      BuildContext context, GameState gs, AffiliateDeal d, Team club) {
    final subtle = SemanticColors.subtleText(context);
    const small = TextStyle(fontSize: 12.5);
    final fee = formatMoney(gs.scaledMoney(d.annualFee));
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              SizedBox(
                  width: 110,
                  child: Text(k, style: small.copyWith(color: subtle))),
              Expanded(
                  child: Text(v,
                      style: small.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(club.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        kv(
            Tr.pick('関係', 'Relationship'),
            d.weAreParent
                ? Tr.pick('こちらが親(相手が系列)', 'We are the parent club')
                : Tr.pick('相手が親(こちらが系列)', 'They are our parent club')),
        kv(
            Tr.pick('相手の部・強さ', 'Their level'),
            Tr.pick(
                '${_tierLabel(gs, club)}・力${club.overallRating}(こちら${gs.userTeam.overallRating})',
                '${_tierLabel(gs, club)}, strength ${club.overallRating} (ours ${gs.userTeam.overallRating})')),
        kv(
            Tr.pick('期間', 'Until'),
            d.untilSeason == null
                ? Tr.pick('1季ごとに続く', 'Rolls on each season')
                : d.untilSeason! <= gs.save!.league.season
                    ? Tr.pick('今季の終わりまで', 'End of this season')
                    : Tr.pick(
                        'あと${d.untilSeason! - gs.save!.league.season + 1}季',
                        '${d.untilSeason! - gs.save!.league.season + 1} more seasons')),
        kv(
            Tr.pick('提携費', 'Fee'),
            d.weAreParent
                ? Tr.pick('毎季 $fee を払う', 'We pay $fee a season')
                : Tr.pick('毎季 $fee を受け取る', 'We receive $fee a season')),
        const SizedBox(height: 4),
        Text(Tr.pick('提携の中身', 'Terms'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        for (final t in d.termLabels())
          Text(Tr.pick('・$t', '- $t'), style: small),
        if (d.termLabels().isEmpty)
          Text(Tr.pick('(項目なし)', '(none)'),
              style: small.copyWith(color: subtle)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('affiliate-end'),
            onPressed: () => gs.endAffiliate(),
            child: Text(Tr.pick('提携をやめる', 'End it')),
          ),
        ),
      ],
    );
  }

  Widget _candidates(BuildContext context, GameState gs) {
    final list = gs.affiliateCandidates();
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    const small = TextStyle(fontSize: 12);
    if (list.isEmpty) {
      return Text(Tr.pick('提携できるクラブがありません', 'No club to partner with yet'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                  flex: 4, child: Text(Tr.pick('クラブ', 'Club'), style: head)),
              SizedBox(
                  width: 44, child: Text(Tr.pick('部', 'Tier'), style: head)),
              SizedBox(
                  width: 36, child: Text(Tr.pick('力', 'Str'), style: head)),
              Expanded(
                  flex: 3, child: Text(Tr.pick('関係', 'Role'), style: head)),
              const SizedBox(width: 70),
            ],
          ),
        ),
        for (final t in list)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small)),
                SizedBox(
                    width: 44, child: Text(_tierLabel(gs, t), style: small)),
                SizedBox(
                    width: 36, child: Text('${t.overallRating}', style: small)),
                Expanded(
                    flex: 3,
                    child: Text(
                        gs.weAreParentWith(t)
                            ? Tr.pick('こちらが親', 'We lead')
                            : Tr.pick('相手が親', 'They lead'),
                        style: small.copyWith(
                            color: gs.weAreParentWith(t)
                                ? null
                                : scheme.primary))),
                SizedBox(
                  width: 70,
                  child: TextButton(
                    key: ValueKey('affiliate-open-${t.id}'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ChangeNotifierProvider<GameState>.value(
                        value: gs,
                        child: _AffiliateTermsDialog(team: t),
                      ),
                    ),
                    child: Text(Tr.pick('条件', 'Terms')),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 提携の中身を選ぶ(項目・年数。提携費はその場で出す)。
class _AffiliateTermsDialog extends StatefulWidget {
  const _AffiliateTermsDialog({required this.team});
  final Team team;

  @override
  State<_AffiliateTermsDialog> createState() => _AffiliateTermsDialogState();
}

class _AffiliateTermsDialogState extends State<_AffiliateTermsDialog> {
  bool _loans = true;
  bool _youth = false;
  bool _first = true;
  int _sellOn = 0;
  int _years = 2;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final t = widget.team;
    final parent = gs.weAreParentWith(t);
    final fee = gs.scaledMoney(gs.affiliateFeeFor(t,
        loanPriority: _loans,
        youthDevelopment: _youth,
        firstRefusal: _first,
        sellOnPercent: _sellOn));
    final short = parent && gs.save!.budget < fee;
    final subtle = SemanticColors.subtleText(context);
    Widget sw(String title, String sub, bool v, ValueChanged<bool>? on) =>
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: v,
          onChanged: on,
          title: Text(title, style: const TextStyle(fontSize: 13)),
          subtitle: Text(sub, style: TextStyle(fontSize: 11, color: subtle)),
        );
    return AlertDialog(
      title: Text(Tr.pick('${t.name}との提携', 'Affiliate deal with ${t.name}')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parent
                    ? Tr.pick('相手が弱いので、こちらが親になります。',
                        'They are weaker, so we are the parent club.')
                    : Tr.pick('相手が強いので、相手が親(こちらが系列)になります。',
                        'They are stronger, so they are the parent and we are the feeder.'),
                style: const TextStyle(fontSize: 12.5),
              ),
              sw(
                  parent
                      ? Tr.pick('貸し出しの優先', 'Loan priority')
                      : Tr.pick('親の若手を借りる', 'Borrow their youngsters'),
                  parent
                      ? Tr.pick('こちらの貸し出しは提携先へ、出場機会付きで送ります',
                          'Our loans go to them, with playing time guaranteed')
                      : Tr.pick('親の選手を借り賃なしで借りられます',
                          'We borrow their players with no loan fee'),
                  _loans,
                  (v) => setState(() => _loans = v)),
              if (parent) ...[
                sw(
                    Tr.pick('若手の育成先', 'Development club'),
                    Tr.pick('提携先に貸した21歳以下の伸びが大きくなります',
                        '21-and-unders we loan to them develop faster'),
                    _youth,
                    (v) => setState(() => _youth = v)),
                sw(
                    Tr.pick('移籍の優先交渉権', 'First refusal'),
                    Tr.pick(
                        '相手の選手の言い値が2割引になります', 'Their players cost us 20% less'),
                    _first,
                    (v) => setState(() => _first = v)),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parent
                          ? Tr.pick('売却時の取り分(相手が売ると入る)',
                              'Sell-on share (theirs to us)')
                          : Tr.pick('売却時の取り分(こちらが売ると渡す)',
                              'Sell-on share (ours to them)'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _sellOn,
                    items: [
                      for (final p in AffiliateDeal.sellOnChoices)
                        DropdownMenuItem(value: p, child: Text('$p%')),
                    ],
                    onChanged: (v) => setState(() => _sellOn = v ?? 0),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick('期間', 'Length'),
                          style: const TextStyle(fontSize: 13))),
                  DropdownButton<int>(
                    value: _years,
                    items: [
                      for (final y in AffiliateDeal.yearChoices)
                        DropdownMenuItem(
                            value: y,
                            child:
                                Text(Tr.pick('$y季', Tr.plural(y, 'season')))),
                    ],
                    onChanged: (v) => setState(() => _years = v ?? 1),
                  ),
                ],
              ),
              const Divider(),
              Text(
                parent
                    ? Tr.pick('提携費: 毎季 ${formatMoney(fee)} を払う(1季目は今)',
                        'Fee: we pay ${formatMoney(fee)} a season (the first now)')
                    : Tr.pick('提携費: 毎季 ${formatMoney(fee)} を受け取る(1季目は今)',
                        'Fee: we receive ${formatMoney(fee)} a season (the first now)'),
                key: const ValueKey('affiliate-fee'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                Tr.pick('項目を増やすほど、親の払う額は高くなります。力の差が大きいほど安くなります。',
                    'More terms cost the parent more; a bigger gap in strength makes it cheaper.'),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
              if (short)
                DisabledReason(fundsShortReason(fee - gs.save!.budget),
                    key: const ValueKey('affiliate-blocked')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Tr.pick('やめる', 'Cancel'))),
        FilledButton(
          key: const ValueKey('affiliate-sign'),
          onPressed: short
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  await gs.signAffiliate(t.id,
                      years: _years,
                      loanPriority: _loans,
                      youthDevelopment: _youth,
                      firstRefusal: _first,
                      sellOnPercent: _sellOn);
                  nav.pop();
                },
          child: Text(Tr.pick('提携を結ぶ', 'Sign')),
        ),
      ],
    );
  }
}
