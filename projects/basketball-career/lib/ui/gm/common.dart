import 'package:flutter/material.dart';

import '../../gm/league.dart';
import '../../gm/player.dart';
import '../team_colors.dart';
import 'style.dart';

TeamColor colorOf(int team) => TeamColor.values.firstWhere((c) => c.sprite == teamDefs[team].color, orElse: () => TeamColor.blue);

/// 選手の顔(チームの色のユニフォームの絵)。
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.team, this.size = 42, this.pose});
  final int team;
  final double size;

  /// null なら立ち姿。'shoot' 'dunk' 'defense'。
  final String? pose;

  @override
  Widget build(BuildContext context) {
    final c = colorOf(team);
    final file = pose == null ? 'adult_${c.sprite}' : 'adult_${pose}_${c.sprite}';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.jersey.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.jersey.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/art/players/$file.png',
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.75),
        errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: c.jersey, size: size * 0.7),
      ),
    );
  }
}

/// チームの印(色の丸と地名の頭文字)。
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.team, this.size = 26});
  final int team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = colorOf(team);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
      child: Text(teamDefs[team].nick.substring(0, 1),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.5)),
    );
  }
}

/// 力の数字。
class OvrBadge extends StatelessWidget {
  const OvrBadge(this.ovr, {super.key, this.size = 40, this.delta = 0});
  final int ovr;
  final double size;
  final int delta;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 見せる数字は 2K の幅(shown)。色はもとの力で決める
          Text('${shown(ovr)}',
              style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.bold, color: GmColors.ovr(ovr), height: 1.1)),
          if (shownDelta(ovr, delta) != 0)
            Text(shownDelta(ovr, delta) > 0 ? '+${shownDelta(ovr, delta)}' : '${shownDelta(ovr, delta)}',
                style: TextStyle(fontSize: 11, color: delta > 0 ? GmColors.good : GmColors.bad, height: 1.1)),
        ]),
      );
}

/// 見せる数字での変化。
int shownDelta(int ovr, int delta) => shown(ovr) - shown(ovr - delta);

/// 小さな札。
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = GmColors.sub});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      );
}

/// 選手の1行。[trailing] にボタンなどを置ける。
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.p,
    required this.team,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.showDelta = false,
    this.salaryText,
    this.extra,
    this.showMorale = false,
    this.onLongPress,
  });

  final Player p;
  final int team;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool showDelta;

  /// 年俸の欄を差し替える(求める年俸など)。
  final String? salaryText;
  final Widget? extra;

  /// 自分のチームの選手なら、気持ちの顔を出す。
  final bool showMorale;

  /// 長押し(選手のカードを開くなど)。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final grade = p.grade;
    return Material(
      color: selected ? GmColors.ball.withValues(alpha: 0.16) : GmColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? GmColors.ball : GmColors.line),
          ),
          child: Row(children: [
            PlayerAvatar(team: team, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5))),
                  if (showMorale) ...[const SizedBox(width: 4), MoraleIcon(p: p)],
                ]),
                const SizedBox(height: 2),
                Wrap(spacing: 5, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Tag(p.pos.short, color: p.pos.guard ? const Color(0xFF8FD3FF) : p.pos.big ? GmColors.good : GmColors.ball),
                  Text('${p.age}歳・${archetypeOf(p)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  Text(salaryText ?? '${money(p.salary)}・${p.years <= 0 ? '契約切れ' : '残り${p.years}年'}',
                      style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  if (grade != '-') Tag('伸びしろ$grade', color: grade == 'S' || grade == 'A' ? GmColors.gold : GmColors.sub),
                  if (p.injured > 0) Tag('けが あと${p.injured}試合', color: GmColors.bad),
                ]),
                if (p.stats.gp > 0 || p.prev.gp > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(p.stats.gp > 0 ? p.stats.line : '昨季 ${p.prev.line}',
                        style: const TextStyle(fontSize: 12, color: GmColors.text, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                if (extra != null) ...[const SizedBox(height: 4), extra!],
              ]),
            ),
            OvrBadge(p.ovr, delta: showDelta ? p.lastDelta : 0),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ]),
        ),
      ),
    );
  }
}

/// 気持ちの顔。
class MoraleIcon extends StatelessWidget {
  const MoraleIcon({super.key, required this.p, this.size = 16});
  final Player p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = p.morale >= 70
        ? (Icons.sentiment_very_satisfied_rounded, GmColors.good)
        : p.morale >= 45
            ? (Icons.sentiment_neutral_rounded, GmColors.sub)
            : p.morale >= 20
                ? (Icons.sentiment_dissatisfied_rounded, GmColors.gold)
                : (Icons.sentiment_very_dissatisfied_rounded, GmColors.bad);
    return Tooltip(message: '気持ち: ${p.moraleLabel}', child: Icon(icon, size: size, color: color));
  }
}

/// 能力の内訳(6つの帯)。
class AttrBars extends StatelessWidget {
  const AttrBars({super.key, required this.p});
  final Player p;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final a in Attr.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 92, child: Text(a.label, style: const TextStyle(fontSize: 13, color: GmColors.sub))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (shown(p.attr(a)) - 40) / 59,
                    minHeight: 8,
                    color: GmColors.ovr(p.attr(a)),
                    backgroundColor: GmColors.line,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: Text('${shown(p.attr(a))}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),
      ]);
}

/// 見出し。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GmColors.text))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// 年俸の合計と上限の帯。
class PayrollBar extends StatelessWidget {
  const PayrollBar({super.key, required this.payroll, this.compact = false});
  final int payroll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final f = (payroll / hardCap).clamp(0.0, 1.0);
    final color = payroll > taxLine ? GmColors.bad : payroll > salaryCap ? GmColors.gold : GmColors.good;
    final room = salaryCap - payroll;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: Text('年俸 ${money(payroll)}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: compact ? 13 : 14)),
        ),
        // 上の帯(狭い)では年俸の合計だけを出す。空きや税は帯の色と線で分かる
        if (!compact)
          Text(
              room >= 0
                  ? '上限まで ${money(room)}'
                  : payroll > taxLine
                      ? 'ぜいたく税 ${money(payroll - taxLine)}分'
                      : '上限を${money(-room)}超え',
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, cons) {
        final w = cons.maxWidth;
        return Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: GmColors.line, borderRadius: BorderRadius.circular(4))),
          Container(width: w * f, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          // 上限とぜいたく税の線
          Positioned(left: w * salaryCap / hardCap - 1, child: Container(width: 2, height: 8, color: Colors.white70)),
          Positioned(left: w * taxLine / hardCap - 1, child: Container(width: 2, height: 8, color: GmColors.bad)),
        ]);
      }),
    ]);
  }
}

/// オーナーの信頼の帯。
class TrustBar extends StatelessWidget {
  const TrustBar({super.key, required this.trust});
  final int trust;

  @override
  Widget build(BuildContext context) {
    final color = trust >= 60 ? GmColors.good : trust >= 30 ? GmColors.gold : GmColors.bad;
    return Row(children: [
      const Icon(Icons.handshake_rounded, size: 16, color: GmColors.sub),
      const SizedBox(width: 4),
      const Text('オーナーの信頼', style: TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(width: 6),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: trust / 100, minHeight: 8, color: color, backgroundColor: GmColors.line),
        ),
      ),
      const SizedBox(width: 6),
      Text('$trust', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

/// 試合の結果の1行。
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.g, required this.mine});
  final GameResult g;
  final int mine;

  @override
  Widget build(BuildContext context) {
    final won = g.winner == mine;
    final opp = g.opponentOf(mine);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 24,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(color: (won ? GmColors.good : GmColors.bad).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)),
          child: Text(won ? '勝' : '負', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: won ? GmColors.good : GmColors.bad)),
        ),
        const SizedBox(width: 8),
        // ホームは vs、アウェーは @(NBA の日程表の書き方)
        SizedBox(width: 20, child: Text(g.home == mine ? 'vs' : '@', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
        const SizedBox(width: 6),
        TeamBadge(team: opp, size: 20),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: Text(teamDefs[opp].short, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
        Text('${g.ptsOf(mine)} - ${g.ptsAgainst(mine)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()])),
        if (g.topName != null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('${g.topName} ${g.topPts}点',
                textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
          ),
        ],
      ]),
    );
  }
}
