import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'lineup_screen.dart';
import 'squad_screen.dart';

/// 下タブの「チーム」。選手の一覧と先発(戦術)を、上の切り替えで行き来する。
///
/// 普段のオーナーは選手や先発を細かく触らない。勝負の試合を宣言したときと
/// 選手を確かめたいときだけ開くので、2つを1つのタブにまとめている。
class TeamTabs extends StatefulWidget {
  const TeamTabs({super.key});

  @override
  State<TeamTabs> createState() => _TeamTabsState();
}

class _TeamTabsState extends State<TeamTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // 上の切り替えが状態バーの下に収まるよう、全体を SafeArea に入れる。
    // 中の画面の AppBar は、ここで消費された余白を二重に取らない。
    return SafeArea(
      bottom: false,
      child: Column(
      children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(Tr.pick('選手', 'Players'))),
                ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.checklist_outlined),
                    label: Text(Tr.pick('先発', 'Lineup'))),
              ],
              selected: {_index},
              onSelectionChanged: (s) => setState(() => _index = s.first),
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [SquadScreen(), LineupScreen()],
          ),
        ),
      ],
      ),
    );
  }
}
