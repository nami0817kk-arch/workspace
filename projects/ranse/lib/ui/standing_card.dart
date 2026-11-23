import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/history_lines.dart';
import '../engine/ways.dart';
import 'theme.dart';

/// いまの立ち位置（2026-11-23、ユーザー「ゲーム中自分の立ち位置がよく分からない」）。
/// 岐路のタブのいちばん上に出す: 名と歳と国、身分と主家、歩んでいる道、身分の段（どこまで来たか）、次の目当て、家族。
class StandingCard extends StatelessWidget {
  const StandingCard(this.g, {super.key});
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    final lord = l.lord;
    final serving = lord != null && l.rank >= 1 && l.rank < 8;
    final house = lord == null ? null : '${houseName(g, lord)}家';
    final sub = g.isChild
        ? '${l.region}国・${l.clsName.replaceAll(RegExp(r'の子$'), '')}の家に育つ'
        : serving
        ? '$houseに仕える'
        : l.rank >= 8 && house != null
        ? '$houseの当主'
        : '${l.region}国に暮らす・主家なし';
    final way = g.isChild ? '幼少期' : (kWays[lifeWay(l)]?.$1 ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  l.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${g.age}歳・${l.female ? '女' : '男'}',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              const Spacer(),
              _Chip(way),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: g.rankName(),
                  style: const TextStyle(
                    color: Pal.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                TextSpan(
                  text: '　$sub',
                  style: const TextStyle(color: Pal.ink, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Ladder(g),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 15, color: Pal.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '次の目当て　${_goalHead(g)}${g.nextPromo()}',
                  style: const TextStyle(fontSize: 12.5, color: Pal.ink),
                ),
              ),
            ],
          ),
          if (!g.isChild) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip(l.married ? (l.female ? '夫あり' : '妻あり') : '独り身'),
                if (l.kids > 0) _Chip('子${l.kids}人'),
                _Chip('銭${l.gold}貫'),
                if (l.troops > 0) _Chip('兵${l.troops}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 身分の段。侍・奥の道なら10段のどこにいるか、子どもなら元服までの年、
/// 仏門・商い・野の道は段を持たないので一行で。
class _Ladder extends StatelessWidget {
  const _Ladder(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    if (g.isChild) {
      final done = (g.age - 4).clamp(0, 11);
      return _Steps(
        count: 11,
        filled: done,
        caption: '${l.female ? '裳着' : '元服'}まで',
        left: '生まれ',
        right: '十五',
      );
    }
    final offLadder =
        l.rank == 0 &&
        (g.hasFlag('priesthood') ||
            g.hasFlag('way_merchant') ||
            g.hasFlag('way_outlaw') ||
            g.hasFlag('retired'));
    if (offLadder) {
      return Text(
        '身分の段の外を歩んでいる（${g.rankName()}）',
        style: const TextStyle(color: Pal.muted, fontSize: 12),
      );
    }
    final rk = g.rk;
    return _Steps(
      count: rk.length,
      filled: l.rank + 1,
      caption: '身分の段　${l.rank + 1} ／ ${rk.length}',
      left: rk.first,
      right: rk.last,
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.count,
    required this.filled,
    required this.caption,
    required this.left,
    required this.right,
  });
  final int count, filled;
  final String caption, left, right;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Expanded(
                child: Container(
                  height: i == filled - 1 ? 10 : 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < filled
                        ? (i == filled - 1 ? Pal.accent : Pal.gold)
                        : Pal.track,
                  ),
                ),
              ),
              if (i < count - 1) const SizedBox(width: 3),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              left,
              style: const TextStyle(color: Pal.muted, fontSize: 10.5),
            ),
            Expanded(
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Pal.muted, fontSize: 10.5),
              ),
            ),
            Text(
              right,
              style: const TextStyle(color: Pal.muted, fontSize: 10.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Pal.panel2,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11.5, color: Pal.ink)),
  );
}

/// 昇進の条件が並ぶときは、どの身分への条件かを頭に添える（「足軽組頭まで　功0/15…」）。
String _goalHead(Game g) {
  final l = g.l;
  if (g.isChild || l.rank < 1 || l.rank >= 7 || g.hasFlag('retired')) return '';
  return '${g.rk[l.rank + 1]}まで　';
}

/// 岐路を選んでいる間に上に出す、一行の立ち位置（身分・主家・段・歳）。くわしいカードは岐路の下にある。
class StandingStrip extends StatelessWidget {
  const StandingStrip(this.g, {super.key});
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    final lord = l.lord;
    final house = lord == null ? null : '${houseName(g, lord)}家';
    final where = g.isChild
        ? '${l.region}国'
        : (house == null ? '主家なし' : (l.rank >= 8 ? '$houseの当主' : house));
    final onLadder =
        !g.isChild &&
        !(l.rank == 0 &&
            (g.hasFlag('priesthood') ||
                g.hasFlag('way_merchant') ||
                g.hasFlag('way_outlaw') ||
                g.hasFlag('retired')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Pal.line),
      ),
      child: Row(
        children: [
          Text(
            g.rankName(),
            style: const TextStyle(
              color: Pal.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              where,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Pal.ink),
            ),
          ),
          if (onLadder)
            Text(
              '段 ${l.rank + 1}／${g.rk.length}',
              style: const TextStyle(fontSize: 12, color: Pal.gold),
            ),
        ],
      ),
    );
  }
}
