import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/squad_registration_engine.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import 'player_actions.dart';

/// 1つの決まりの、今と上限(または下限)。
class RegistrationRuleLine {
  const RegistrationRuleLine({
    required this.label,
    required this.now,
    required this.limit,
    required this.isMinimum,
    required this.note,
    this.players = const [],
  });

  final String label;
  final int now;

  /// 上限([isMinimum] なら下限)。
  final int limit;

  /// 下限の決まり(この人数より少ないと違反)か。
  final bool isMinimum;

  /// 決まりの説明(1行)。
  final String note;

  /// 数えている選手(押すと名前が出る)。
  final List<Player> players;

  /// 違反しているか。
  bool get broken => isMinimum ? now < limit : now > limit;

  /// あと何人(上限まで入れられる人数・下限まで足りない人数)。
  int get room => isMinimum ? now - limit : limit - now;
}

/// 国の選手登録の決まりを、項目ごとに「今 / 上限 / あと何人」で見せる
/// (2026-11-25 新設。以前は「登録と契約」の中に数字だけ並んでいて、
/// あと何人取れるかは自分で引き算するしかなかった)。
class RegistrationRulesScreen extends StatelessWidget {
  const RegistrationRulesScreen({super.key});

  /// 今のクラブに当てはまる決まりの一覧(画面と検査で同じものを使う)。
  static List<RegistrationRuleLine> linesFor(GameState game) {
    final team = game.userTeam;
    final rules = game.registrationRules;
    final seniors = team.players.where(SquadRegistration.isSenior).toList();
    final country = rules.countryLabel;
    final lines = <RegistrationRuleLine>[
      RegistrationRuleLine(
        label: Tr.pick('22歳以上の登録', 'Players aged 22+'),
        now: seniors.length,
        limit: SquadRegistration.seniorLimit,
        isMinimum: false,
        note: Tr.pick(
            '${SquadRegistration.underAge}歳以下は枠の外で、何人でも登録できる',
            'Players aged ${SquadRegistration.underAge} or under do not count'),
        players: seniors,
      ),
    ];
    if (rules.homegrownQuota > 0) {
      final hg = seniors.where((p) => p.isHomegrown).toList();
      final abroad = seniors.where((p) => !p.isHomegrown).toList();
      lines.add(RegistrationRuleLine(
        label: Tr.pick('国内で育った22歳以上', 'Homegrown (22+)'),
        now: hg.length,
        limit: rules.homegrownQuota,
        isMinimum: true,
        note: Tr.pick(
            '足りない分だけ登録の枠が減る(${rules.homegrownQuota}人を入れる)',
            'Each one short costs a registration place (${rules.homegrownQuota} required)'),
        players: hg,
      ));
      lines.add(RegistrationRuleLine(
        label: Tr.pick('国外で育った22歳以上', 'Trained abroad (22+)'),
        now: abroad.length,
        limit: rules.nonHomegrownLimit,
        isMinimum: false,
        note: Tr.pick('超えた分は締切で名簿から外れる',
            'Anyone over the limit drops off the list at the deadline'),
        players: abroad,
      ));
    }
    if (rules.clubTrainedQuota > 0) {
      final club = seniors.where((p) => p.academyGraduate).toList();
      lines.add(RegistrationRuleLine(
        label: Tr.pick('クラブで育った22歳以上(ユース出身)', 'Club-trained (22+)'),
        now: club.length,
        limit: rules.clubTrainedQuota,
        isMinimum: true,
        note: Tr.pick('ほかから来た22歳以上は${rules.nonClubTrainedLimit}人まで',
            'At most ${rules.nonClubTrainedLimit} senior players from elsewhere'),
        players: club,
      ));
    }
    final nonEuLimit = rules.nonEuLimit;
    if (nonEuLimit != null) {
      final nonEu = [
        for (final p in team.players)
          if (!isEuNation(game.nationalityOf(p))) p
      ];
      lines.add(RegistrationRuleLine(
        label: Tr.pick('EU 外の国籍(年齢を問わない)', 'Non-EU nationals (any age)'),
        now: nonEu.length,
        limit: nonEuLimit,
        isMinimum: false,
        note: Tr.pick('$countryの決まり。21歳以下も数える',
            '$country rules; under-21s count too'),
        players: nonEu,
      ));
    }
    final perSeason = rules.nonEuSigningsPerSeason;
    if (perSeason != null) {
      lines.add(RegistrationRuleLine(
        label: Tr.pick('今季、他国から取った EU 外の選手', 'Non-EU signings from abroad'),
        now: game.nonEuSignedThisSeason,
        limit: perSeason,
        isMinimum: false,
        note: Tr.pick('1季に$perSeason人まで(所属なしの選手も数える)',
            '$perSeason a season, free agents included'),
      ));
    }
    final minNationals = rules.minNationals;
    if (minNationals != null) {
      final nationals = [
        for (final p in team.players)
          if (game.nationalityOf(p) == rules.country) p
      ];
      lines.add(RegistrationRuleLine(
        label: Tr.pick('$country国籍の選手', '$country nationals'),
        now: nationals.length,
        limit: minNationals,
        isMinimum: true,
        note: Tr.pick(
            '外国籍は${SquadRegistration.totalLimit - minNationals}人まで',
            'At most ${SquadRegistration.totalLimit - minNationals} foreign players'),
        players: nationals,
      ));
    }
    lines.add(RegistrationRuleLine(
      label: Tr.pick('在籍の総数(21歳以下を含む)', 'Whole squad (incl. U21)'),
      now: team.players.length,
      limit: maxSquadSize,
      isMinimum: false,
      note: Tr.pick('上限に達すると、誰も加えられない',
          'At the limit you cannot add anyone'),
      players: team.players,
    ));
    lines.add(RegistrationRuleLine(
      label: Tr.pick('在籍の下限', 'Squad minimum'),
      now: team.players.length,
      limit: minSquadSize,
      isMinimum: true,
      note: Tr.pick('これより減らす放出・貸し出しはできない',
          'You cannot sell or loan out below this'),
    ));
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    if (game.save == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('登録ルール', 'Registration rules'))),
      body: ResponsiveBody(child: _RulesBody(game: game)),
    );
  }
}

class _RulesBody extends StatefulWidget {
  const _RulesBody({required this.game});

  final GameState game;

  @override
  State<_RulesBody> createState() => _RulesBodyState();
}

class _RulesBodyState extends State<_RulesBody> {
  /// 名前を開いている行。
  int? _open;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final rules = game.registrationRules;
    final lines = RegistrationRulesScreen.linesFor(game);
    final broken = lines.where((l) => l.broken).length;
    final theme = Theme.of(context);
    final subtle = SemanticColors.subtleText(context);
    final head = TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: subtle);
    final planned = game.plannedRegistrationExclusions;
    final outNow = [
      for (final p in game.userTeam.players)
        if (p.notRegistered) p
    ];

    Widget num(String s, double w, {Color? color, bool bold = false}) =>
        SizedBox(
          width: w,
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        );

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        FmPanel(
          key: const ValueKey('rules-summary'),
          title: Tr.pick('${rules.countryLabel}式の登録の決まり',
              '${rules.countryLabel} registration rules'),
          trailing: Text(
            broken == 0
                ? Tr.pick('すべて守っています', 'All rules met')
                : Tr.pick('$broken項目で違反', '$broken broken'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: broken == 0
                  ? SemanticColors.positive(context)
                  : theme.colorScheme.error,
            ),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(Tr.pick('項目', 'Rule'), style: head)),
                    SizedBox(
                        width: 48,
                        child: Text(Tr.pick('今', 'Now'),
                            textAlign: TextAlign.center, style: head)),
                    SizedBox(
                        width: 64,
                        child: Text(Tr.pick('上限/下限', 'Limit'),
                            textAlign: TextAlign.center, style: head)),
                    SizedBox(
                        width: 104,
                        child: Text(Tr.pick('あと何人', 'Room'),
                            textAlign: TextAlign.center, style: head)),
                  ],
                ),
              ),
              for (var i = 0; i < lines.length; i++) ...[
                InkWell(
                  key: ValueKey('rule-line-$i'),
                  onTap: lines[i].players.isEmpty
                      ? null
                      : () => setState(() => _open = _open == i ? null : i),
                  child: Container(
                    // 押せる行は指の大きさ(48)にそろえる。
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(lines[i].label,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (lines[i].players.isNotEmpty)
                                  Icon(
                                      _open == i
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 16,
                                      color: subtle),
                              ]),
                              Text(lines[i].note,
                                  style: TextStyle(fontSize: 11, color: subtle)),
                            ],
                          ),
                        ),
                        num('${lines[i].now}', 48, bold: true),
                        num(
                            lines[i].isMinimum
                                ? Tr.pick('${lines[i].limit}以上',
                                    '${lines[i].limit}+')
                                : Tr.pick('${lines[i].limit}まで',
                                    'max ${lines[i].limit}'),
                            64),
                        SizedBox(
                          width: 104,
                          child: Text(
                            _roomText(lines[i]),
                            key: ValueKey('rule-room-$i'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: lines[i].broken
                                  ? theme.colorScheme.error
                                  : (lines[i].room == 0 && !lines[i].isMinimum
                                      ? SemanticColors.ink(
                                          context, Colors.orange)
                                      : SemanticColors.positive(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_open == i)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final p in [...lines[i].players]
                          ..sort((a, b) => b.overall.compareTo(a.overall)))
                          ActionChip(
                            label: Text(
                                Tr.pick('${p.name}(${p.age})',
                                    '${p.name} (${p.age})'),
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () => openPlayerDetail(context, p.id),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        FmPanel(
          title: Tr.pick('名簿から外れる選手', 'Left off the squad list'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outNow.isEmpty
                    ? Tr.pick('いま名簿の外の選手はいません。',
                        'Nobody is off the list right now.')
                    : Tr.pick(
                        'いま名簿の外(次の窓まで公式戦に出られない): ${outNow.map((p) => p.name).join('、')}',
                        'Off the list now (ineligible until the next window): ${outNow.map((p) => p.name).join(', ')}'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                planned.isEmpty
                    ? Tr.pick('次の締切で外れる選手はいません(枠に収まっています)。',
                        'Nobody will drop off at the next deadline.')
                    : Tr.pick(
                        '次の締切で外れる予定: ${planned.map((p) => p.name).join('、')}(移籍の画面の「名簿を選ぶ」で選べます)',
                        'Due to drop off at the next deadline: ${planned.map((p) => p.name).join(', ')} (choose under "Choose the list" on the transfers screen)'),
                style: TextStyle(
                    fontSize: 12,
                    color: planned.isEmpty ? null : theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _roomText(RegistrationRuleLine l) {
    if (l.isMinimum) {
      return l.broken
          ? Tr.pick('あと${-l.room}人足りない', '${-l.room} short')
          : Tr.pick('満たしている(+${l.room})', 'Met (+${l.room})');
    }
    return l.broken
        ? Tr.pick('${-l.room}人超えている', '${-l.room} over')
        : Tr.pick('あと${l.room}人', '${l.room} more');
  }
}
