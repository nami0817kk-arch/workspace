import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../widgets/auto_columns.dart';
import '../widgets/club_culture_card.dart';
import '../widgets/club_policy_card.dart';
import '../widgets/era_card.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../widgets/rival_owners_card.dart';

/// オーナー自身と、クラブの外の世界(他のオーナー・他クラブ・国の係数・時代)。
///
/// 以前は経営の「資金・取引」に、融資や預金と一緒に並んでいた。お金の操作と
/// オーナーとしての立ち位置を分け、オーナー室にまとめる。
class OwnerWorldScreen extends StatelessWidget {
  const OwnerWorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveBody(
      child: AutoColumns(
        // 札が3枚でも、横画面では2列に並べる。
        minChildren: 3,
        children: [
          ClubDirectionCard(),
          RivalOwnersCard(),
          EraCard(),
        ],
      ),
    );
  }
}

/// クラブの文化と方針を1枚に(2026-11-25)。
///
/// 以前は文化がオーナー室、方針が経営の「方針と投資」に分かれていた。
/// どちらも「このクラブはどう戦い、何を大事にするか」をオーナーが決めるもので、
/// 変えられる時期の決まりも近い(文化は1季に1回、方針はオフシーズンだけ)。
class ClubDirectionCard extends StatelessWidget {
  const ClubDirectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FmPanel(
      key: const ValueKey('club-direction-card'),
      title: Tr.pick('文化と方針', 'Identity & policy'),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 方針を先に(季の中は1行。オフシーズンに「やること」から来る)。
        children: [
          ClubPolicyCard(embedded: true),
          Divider(height: 1),
          SizedBox(height: 8),
          ClubCultureCard(embedded: true),
        ],
      ),
    );
  }
}
