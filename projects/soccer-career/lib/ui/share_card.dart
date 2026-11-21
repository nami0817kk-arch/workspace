import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../models/club.dart';
import '../models/competition.dart';
import '../models/legend.dart';
import '../models/look.dart';
import '../models/season.dart';
import '../share/share_service.dart';
import 'club_identity.dart';
import 'hall_plaque.dart';
import 'player_banner.dart';
import 'player_portrait.dart';

/// 外に送る1枚。
///
/// **大きさは決め打ちにする**（`cardWidth` × `cardHeight`）。画面の幅に
/// 合わせて作ると、端末によって送られる画像の中身が変わる——文の折り返しも
/// 数字の大きさも変わってしまう。見せるときだけ `FittedBox` で縮める。
/// 4:5 は X と LINE の一覧で切られずに出る形。
const double cardWidth = 360;
const double cardHeight = 450;

/// 送る画像を作るときの倍率。360 × 3 = 1080px。
const double cardPixelRatio = 3;

/// 引退した選手の1枚。
///
/// **20年ぶんがここに出る。** 遊んだ人が自分から見せたくなるものでなければ、
/// 共有の口を付けても誰も押さない。
class CareerShareCard extends StatelessWidget {
  const CareerShareCard({super.key, required this.legend});

  final Legend legend;

  @override
  Widget build(BuildContext context) {
    final plaque = HallPlaque.of(legend);
    // 殿堂の額と同じ色分け（大陸カップなら金、国内のタイトルなら銀、
    // 無ければ銅）。**見た目のためだけの数字は作らない。**
    final club = legend.clubId.isEmpty
        ? null
        : Club(
            id: legend.clubId,
            name: legend.spells.isEmpty ? '' : legend.spells.last.clubName,
            strength: 0,
            tier: 1,
          );
    final titles = <String>[
      if (legend.leagueTitles > 0) tr('リーグ ${legend.leagueTitles}', 'League ${legend.leagueTitles}'),
      if (legend.cupTitles > 0) tr('カップ ${legend.cupTitles}', 'Cup ${legend.cupTitles}'),
      if (legend.continentalTitles > 0) tr('大陸 ${legend.continentalTitles}', 'Continental ${legend.continentalTitles}'),
      if (legend.worldCupBest != WorldCupStage.none)
        tr('世界大会 ${legend.worldCupBest.label}', 'World ${legend.worldCupBest.label}'),
    ];
    return _Frame(
      club: club,
      accent: plaque.color,
      striped: plaque == HallPlaque.gold,
      portrait: PlayerPortrait(
        look: legend.look,
        club: club,
        squadNumber: legend.squadNumber,
        size: 76,
        // 帯の上に乗るので、テーマではなく帯から決める。
        backdrop: const Color(0xFFF2F0E6),
      ),
      title: legend.name,
      subtitle:
          tr('${legend.positionLabel} ・ '
          '${legend.seasons}年のキャリア ・ ${legend.retiredAge}歳で引退', '${legend.positionLabel} - ${legend.seasons} seasons - retired at ${legend.retiredAge}'),
      stats: [
        _Stat(tr('出場', 'Games'), '${legend.appearances}'),
        _Stat(tr('ゴール', 'Goals'), '${legend.goals}'),
        _Stat(tr('代表', 'Caps'), '${legend.caps}'),
      ],
      lines: [
        _Line(tr('ピーク総合力', 'Peak overall'), '${legend.peakOverall}'),
        _Line(tr('平均評価', 'Avg rating'), legend.averageRating.toStringAsFixed(2)),
        if (legend.assists > 0) _Line(tr('アシスト', 'Assists'), '${legend.assists}'),
        _Line(tr('一番上で戦った部', 'Highest tier reached'), tr('${legend.bestTier}部', 'Tier ${legend.bestTier}')),
        _Line(tr('渡り歩いたクラブ', 'Clubs played for'), '${legend.spells.length}'),
      ],
      footnote: titles.isEmpty ? tr('無冠のキャリア', 'A career without a trophy') : titles.join(tr(' ・ ', ' - ')),
    );
  }

  /// この1枚に添える文。
  String get text => ShareText.compose([
    tr('${legend.seasons}年のキャリアを終えました。', 'A ${legend.seasons}-season career is over.'),
    tr('通算 ${legend.appearances}試合 ${legend.goals}ゴール、'
        '代表${legend.caps}キャップ。', '${legend.appearances} games, ${legend.goals} goals, ${legend.caps} caps.'),
    if (legend.leagueTitles > 0) tr('リーグ優勝 ${legend.leagueTitles}回。', '${legend.leagueTitles} league titles.'),
  ]);
}

/// 1シーズンの1枚。**優勝と昇格のときだけ出す。**
///
/// 引退は1キャリアに1回しか来ないが、季末は19回来る。
/// **広まるとしたら、回数が多いこちらのほう。**
class SeasonShareCard extends StatelessWidget {
  const SeasonShareCard({
    super.key,
    required this.club,
    required this.year,
    required this.tier,
    required this.leaguePosition,
    required this.stats,
    required this.look,
    required this.squadNumber,
    required this.playerName,
    required this.headline,
    this.caps = 0,
    this.objectiveMet,
    this.cupWon = false,
    this.continentalWon = false,
  });

  final Club club;
  final int year;
  final int tier;
  final int leaguePosition;

  /// **`SeasonRecord` は受け取らない。** 季末の画面では今季の記録が
  /// まだ `history` に入っていない（入るのは次の季を組み立てるとき）ので、
  /// 記録を待つと「送れるのは翌季から」になってしまう。
  final SeasonStats stats;

  final PlayerLook look;
  final int squadNumber;
  final String playerName;

  /// 「1部 優勝」「2部から昇格」など。何を成したかの一言。
  final String headline;

  /// 今季の代表の数。0 なら行を出さない。
  final int caps;

  /// 監督の期待を3つのうちいくつ満たしたか。目標が無い季は null。
  final int? objectiveMet;

  final bool cupWon;
  final bool continentalWon;

  @override
  Widget build(BuildContext context) {
    final identity = ClubIdentity.of(club);
    final extra = <String>[
      if (cupWon) tr('国内カップ優勝', 'Domestic cup winner'),
      if (continentalWon) tr('大陸カップ優勝', 'Continental cup winner'),
    ];
    return _Frame(
      club: club,
      accent: identity.primary,
      striped: identity.striped,
      portrait: PlayerPortrait(
        look: look,
        club: club,
        squadNumber: squadNumber,
        size: 76,
        backdrop: const Color(0xFFF2F0E6),
      ),
      title: headline,
      subtitle: tr('${club.name} ・ $year年 ・ $playerName', '${club.name} - $year - $playerName'),
      stats: [
        _Stat(tr('出場', 'Games'), '${stats.appearances}'),
        _Stat(tr('ゴール', 'Goals'), '${stats.goals}'),
        _Stat(tr('アシスト', 'Assists'), '${stats.assists}'),
      ],
      lines: [
        _Line(tr('平均評価', 'Avg rating'), stats.averageRating.toStringAsFixed(2)),
        _Line(tr('順位', 'Finish'), tr('$tier部 $leaguePosition位', 'T$tier #$leaguePosition')),
        _Line(tr('得点に絡んだ数', 'Goal involvements'), '${stats.goals + stats.assists}'),
        if (objectiveMet != null) _Line(tr('監督の期待', 'Manager targets'), '$objectiveMet / 3'),
        if (caps > 0) _Line(tr('今季の代表', 'Caps this season'), tr('$caps キャップ', '$caps caps')),
      ],
      footnote: extra.isEmpty ? '' : extra.join(tr(' ・ ', ' - ')),
    );
  }

  String get text => ShareText.compose([
    tr('$headline（${club.name}・$year年）', '$headline (${club.name}, $year)'),
    tr('${stats.appearances}試合 ${stats.goals}ゴール '
        '${stats.assists}アシスト、平均評価 '
        '${stats.averageRating.toStringAsFixed(2)}。', '${stats.appearances} games, ${stats.goals} goals, ${stats.assists} assists, ${stats.averageRating.toStringAsFixed(2)} average.'),
  ]);
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _Line {
  const _Line(this.label, this.value);
  final String label;
  final String value;
}

/// 1枚の枠。**帯はクラブの色、紙は生成り。**
///
/// 明暗のテーマに引きずられない（自前の色で描く）。送った画像が
/// 送った人の端末の設定で変わるのは、記録として正しくない。
class _Frame extends StatelessWidget {
  const _Frame({
    required this.club,
    required this.accent,
    required this.striped,
    required this.portrait,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.lines,
    required this.footnote,
  });

  final Club? club;
  final Color accent;
  final bool striped;
  final Widget portrait;
  final String title;
  final String subtitle;
  final List<_Stat> stats;
  final List<_Line> lines;
  final String footnote;

  static const Color _paper = Color(0xFFF7F5EC);
  static const Color _ink = Color(0xFF26251F);
  static const Color _muted = Color(0xFF6B6A60);

  @override
  Widget build(BuildContext context) {
    final on = readableOn(accent);
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _paper),
        child: Column(
          children: [
            // 帯。クラブの色と、似顔と、名前。
            KitBackground(
              primary: accent,
              secondary: const Color(0xFFF2F0E6),
              striped: striped,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    portrait,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: on,
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: on.withValues(alpha: 0.88),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (club != null) ...[
                      const SizedBox(width: 8),
                      ClubCrest(club: club!, size: 34),
                    ],
                  ],
                ),
              ),
            ),
            // 大きな数字3つ。**読まなくても目に入るのはここだけ。**
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: [
                  for (final s in stats)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            s.value,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 34,
                              height: 1.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.label,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x1A26251F)),
            // 細かい行。**区切り線1本の行にする**（灰色のベタ塗りの表は、
            // この作品で一番安っぽく見えた部品）。
            // **上に詰める。** 真ん中に寄せると、行が2つしかない季の1枚で
            // 画面の真ん中に穴が空いて、作りかけに見えた（書き出して見つけた）。
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (final l in lines) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Text(
                              l.label,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              l.value,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (l != lines.last)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0x0F26251F),
                        ),
                    ],
                    // タイトルは行の続きに置く。**下端に貼り付けると、
                    // 行が少ないときに宙に浮く。**
                    if (footnote.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        footnote,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.78),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 下端。アプリの名前だけを置く（名義は出さない）。
            Container(
              width: double.infinity,
              color: accent,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                ShareText.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: on,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
