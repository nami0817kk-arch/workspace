import 'dart:math';

import 'player.dart';
import 'traits.dart';

/// 高校卒業(と、大学・実業団の卒業)で選べる進路。
enum Route {
  pro('プロ契約を目指す'),
  university('大学へ進む(4年)'),
  corporate('実業団へ入る(3年)');

  const Route(this.label);
  final String label;

  int get years => switch (this) {
        Route.university => 4,
        Route.corporate => 3,
        Route.pro => 0,
      };
}

/// プロ契約の評価点。能力7割・実績3割に、身長と特性の加点。
/// スカウトは身長を見るので、185cm を超えた分の 15% を足す(低いと引く)。
double offerScore(Player p, double achievement) =>
    p.overall * 0.7 +
    achievement * 0.3 +
    (p.heightCm - 185) * 0.15 +
    scoutBonus(p.traits);

const _sureLine = 70.0;
const _neverLine = 35.0;

/// プロ契約を勝ち取れるか。**一番上は確実、一番下は絶対に無理**、間は運しだい(±10)。
bool winsContract(Player p, double achievement, Random rng) {
  final s = offerScore(p, achievement);
  if (s >= _sureLine) return true;
  if (s < _neverLine) return false;
  return s + (rng.nextDouble() * 20 - 10) >= 55;
}

/// 海外挑戦の条件。21歳以上で総合評価が一定以上。
const abroadMinAge = 21;
const abroadMinOverall = 70.0;

bool canGoAbroad(Player p) =>
    p.age >= abroadMinAge && p.overall >= abroadMinOverall;

/// 戦力外の基準。総合評価がこれ未満の年が続いたら契約を切られる。
const releaseOverall = 35.0;
const releaseYears = 2;
