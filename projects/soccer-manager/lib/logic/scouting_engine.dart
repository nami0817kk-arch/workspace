import 'dart:math';

import '../models/player.dart';
import '../models/player_stub.dart';
import 'division_strength.dart';
import 'player_generator.dart';
import 'scout_knowledge.dart';

class ScoutingEngine {
  static final Random _rng = Random();

  static const int scoutCost = 300;
  static const int maxProspects = 6;
  static const int baseScoutCandidates = 5;
  static const int refreshCost = 120;

  /// スカウトのレベルが高いほど費用は下がる。
  static int scoutCostFor(int scoutLevel) =>
      (scoutCost - (scoutLevel - 1) * 20).clamp(150, scoutCost);

  /// スカウト網の手動更新(候補選手の顔ぶれの一新)1回あたりの費用。
  /// これがないと「良い候補が出るまで無償で更新し続ける」だけの作業に
  /// なってしまうため、更新にも実際の費用を発生させる。スカウトのレベルが
  /// 高いほど情報網が整っており安く済む。
  static int refreshCostFor(int scoutLevel) =>
      (refreshCost - (scoutLevel - 1) * 10).clamp(60, refreshCost);

  /// 未獲得のスカウト候補について、スカウトレベルに応じた潜在能力の
  /// 推定レンジ(下限・上限)を返す。実際の値([Player.potential])は
  /// スカウトして獲得するまで確定情報として開示しない(フォグ・オブ・
  /// ウォー)。これにより、更新を繰り返して確実に当たりを引くという
  /// プレイが成立しなくなり、スカウトのレベル(=推定精度)そのものに
  /// 投資する価値が生まれる。
  ///
  /// 幅の真ん中は本当の値から選手ごとに決まった分だけずらす(スカウトの
  /// 見立て[ScoutKnowledge.range]と同じ)。以前は本当の値を真ん中にして
  /// いて、幅の中央を読めば答えが分かってしまった。
  static (int low, int high) estimatedPotentialRange(
    Player prospect, {
    int scoutLevel = 1,
  }) {
    final uncertainty = estimateUncertainty(scoutLevel);
    final center = prospect.potential +
        ScoutKnowledge.centerOffset(
            prospect.id, youthEstimateSalt, uncertainty);
    final low = (center - uncertainty).clamp(1, 99);
    final high = (center + uncertainty).clamp(1, 99);
    return (low, high);
  }

  /// ユースの見立てのずれの種。スカウトの見立て(総合力1・伸びしろ2)とは
  /// 別の値にして、同じ選手でずれ方がそろわないようにする。
  static const int youthEstimateSalt = 3;

  /// 見立ての振れ幅(±いくつ)。画面に「どれだけ正確に見えているか」を
  /// 出すために切り出してある。
  static int estimateUncertainty(int scoutLevel) =>
      (18 - (scoutLevel - 1) * 1.5).clamp(6, 18).round();

  /// ユース施設のレベルが高いほど昇格候補の受け入れ枠が増える。
  static int maxProspectsFor(int youthFacilityLevel) =>
      maxProspects + (youthFacilityLevel - 1);

  /// スカウトのレベルが高いほど、一度に閲覧できる候補選手(スカウト網)が広がる。
  static int scoutCandidateCountFor(int scoutLevel) =>
      baseScoutCandidates + (scoutLevel - 1);

  static Player _generateProspect({
    required int tierMin,
    required int tierMax,
  }) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = tierMin + _rng.nextInt(tierMax - tierMin + 1);
    final age = 16 + _rng.nextInt(4);
    return PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
  }

  /// シーズン終了時にアカデミーから無償で昇格候補が生まれる。ユースコーチのレベルが質を高める。
  ///
  /// クラブのいる部[tier]が分かれば、強さの真ん中(55)をその部の水準
  /// ([divisionTypicalSquadLevel])へ [academyTierPull] だけ寄せる。上の部の
  /// クラブほど良い子が集まる(実在のアカデミーも、強いクラブほど選べる)。
  /// 寄せないと、3部の水準(65)に届く子がほとんど入らず、育てても一軍の
  /// 戦力にならなかった(2026-11-23)。
  static Player generateAcademyGraduate({
    int youthCoachLevel = 1,
    int investmentBonus = 0,
    int? tier,
  }) {
    final bonus = (youthCoachLevel - 1) * 3 +
        investmentBonus +
        academyTierShift(tier);
    return _generateProspect(tierMin: 40 + bonus, tierMax: 70 + bonus);
  }

  /// アカデミーの子の強さを、部の水準へ寄せる割合。
  static const double academyTierPull = 0.4;

  /// [tier] 部のクラブのアカデミーの子の強さの上乗せ(3部 +4・2部 +7・
  /// 1部 +11。部が分からなければ 0)。
  static int academyTierShift(int? tier) => tier == null
      ? 0
      : ((divisionTypicalSquadLevel(tier) - 55) * academyTierPull).round();

  /// 資金を払ってスカウトした有望株。アカデミー生より粒ぞろいで、スカウトの
  /// レベルが質を高める。レベルが上がるほど下限が底上げされるだけでなく、
  /// 当たり外れの幅(下限-上限の差)も狭まり、優秀なスカウト網ほど確実に
  /// 良い選手を見つけてくるという体感に近づける。
  static Player generateScoutedProspect({int scoutLevel = 1}) {
    final bonus = (scoutLevel - 1) * 4;
    final rangeWidth = (30 - (scoutLevel - 1) * 2).clamp(14, 30);
    final tierMin = 55 + bonus;
    return _generateProspect(tierMin: tierMin, tierMax: tierMin + rangeWidth);
  }

  /// スカウト網の「埋もれた即戦力」が見つかり始めるスカウトの水準。
  static const int hiddenGemMinScoutLevel = 3;

  /// 一度の顔ぶれに混ざる「埋もれた即戦力」の人数。水準3で1人、水準が
  /// 1つ上がるごとに1人増え、3人まで。
  ///
  /// スカウト網はユースの年代(16〜19歳)しか探さず、良いスカウトを雇っても
  /// 今の戦力には何も足せなかった。3部から抜け出すには、他のクラブで
  /// 出番の無い20代前半の選手を見つけて安く獲る道が要る(2026-11-23)。
  /// 当たりを引き直せないよう、顔ぶれの更新の費用はそのまま掛かる。
  static int hiddenGemCountFor(int scoutLevel) =>
      scoutLevel < hiddenGemMinScoutLevel
          ? 0
          : min(3, scoutLevel - hiddenGemMinScoutLevel + 1);

  /// 「埋もれた即戦力」の移籍金の割引(相場に対して)。水準3で2割、
  /// 1つ上がるごとに5%ずつ、4割まで。所属先が出番を与えていない選手で、
  /// まだ他のクラブに知られていないので安く獲れる。
  static double hiddenGemDiscount(int scoutLevel) =>
      (0.2 + (scoutLevel - hiddenGemMinScoutLevel) * 0.05).clamp(0.2, 0.4);

  /// 「埋もれた即戦力」の潜在能力の上乗せの幅(今の総合力に足す)。
  static const int hiddenGemPotentialMin = 5;
  static const int hiddenGemPotentialMax = 12;

  /// 「埋もれた即戦力」を1人作る。20〜23歳、総合力は[targetOverall]
  /// (今の部の上位11人並み)、潜在は総合力 +5〜+12。
  static Player generateHiddenGem({required int targetOverall}) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final age = 20 + _rng.nextInt(4);
    final potential = (targetOverall +
            hiddenGemPotentialMin +
            _rng.nextInt(hiddenGemPotentialMax - hiddenGemPotentialMin + 1))
        .clamp(40, 99);
    final p = PlayerGenerator.generate(
      position: position,
      strengthTier: potential,
      ageOverride: age,
    );
    p.potential = potential;
    // 総合力を狙いに合わせ、潜在を超えた能力は潜在までに切る。切ると
    // 総合力が少し下がるので、何度か繰り返して寄せる。
    for (var i = 0; i < 4; i++) {
      PlayerStub.matchOverall(p, targetOverall.clamp(25, potential));
      for (final k in p.attributes.keys.toList()) {
        p.attributes[k] = p.attributes[k]!.clamp(1, potential);
      }
    }
    p.wage = p.fairWeeklyWage();
    return p;
  }
}
