import 'package:flutter/material.dart';

import '../widgets/auto_columns.dart';
import '../widgets/club_culture_card.dart';
import '../widgets/era_group_card.dart';
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
          ClubCultureCard(),
          RivalOwnersCard(),
          EraGroupCard(),
        ],
      ),
    );
  }
}
