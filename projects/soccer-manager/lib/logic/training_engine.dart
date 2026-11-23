import 'dart:math';

import '../models/attributes.dart';
import '../models/club_infrastructure.dart';
import '../models/player.dart';
import '../models/staff_member.dart';
import 'match_engine.dart';
import '../models/team.dart';
import '../models/training_focus.dart';

export '../models/training_focus.dart';

class TrainingEngine {
  static final Random _rng = Random();

  // 練習で溜まる疲れ(通常の強度で1週あたり)と、練習の週の抜け。
  //
  // 以前は全体練習 +10・特化 +12 に対して抜けが -5 で、練習をする自クラブ
  // だけが週に +5〜7 ずつ疲れを溜めていた(CPU は練習をしない)。長く
  // 回すと先発の平均疲労が自クラブ 75〜99・CPU 20〜35 になり、試合の強さ
  // ((1 - 疲労/250))で2〜3割負けて、どの方針でもいつも最下位だった
  // (2026-11-23 の実測)。練習の疲れは軽く、抜けは日々の回復に近づける。
  // 抜けを -8 にすると自クラブが CPU より10ほど元気になったので -6 にした
  // (普通の運び方で先発の平均疲労が CPU と同じ 20〜30 ほど)。
  static const int fatigueBalanced = 4;
  static const int fatigueFocused = 5;
  static const int fatigueFitness = 2;
  static const int fatigueSwitch = 3;
  static const int weeklyRecovery = 6;

  /// チームの全選手に、チームの既定方針でトレーニングを適用する。
  /// 選手ごとの個別の方針は持たない(練習の中身はクラブのコーチ陣に任せる)。
  /// [headCoachLevel]は成長効率、[trainingGroundLevel]は成長効率と疲労回復を高める。
  /// [injuryFactor]はフィジオのレベルに応じた練習中の負傷リスク軽減係数。
  /// [careerGrowthBonus]はクラブの通算実績に応じた成長効率の
  /// 追加倍率(1.0でボーナスなし)。
  /// [weekScale]は1季の成長・衰えの総量を合わせる倍率(1.0でそのまま)。
  /// 週の処理は7日ごとに走るので、1季の回数は節の数と一致しない。
  /// 呼ぶ側が「節の数÷週の数」を渡して、1季の総量を節ごとだった頃に揃える。
  static void applyWeeklyTraining(
    Team team, {
    int headCoachLevel = 1,
    int trainingGroundLevel = 1,
    int fitnessCoachLevel = 1,
    double injuryFactor = 1.0,
    double careerGrowthBonus = 1.0,
    double weekScale = 1.0,
    TrainingFocus? focusOverride,
    TrainingIntensity? intensityOverride,
  }) {
    final growthMultiplier = ClubInfrastructure.trainingGrowthMultiplier(
          headCoachLevel,
          trainingGroundLevel,
        ) *
        careerGrowthBonus;
    final fatigueRecoveryBonus =
        ClubInfrastructure.fatigueRecoveryBonus(trainingGroundLevel) +
            ClubInfrastructure.fitnessCoachRecoveryBonus(fitnessCoachLevel);
    final focus = focusOverride ?? team.defaultTrainingFocus;
    final intensity = intensityOverride ?? team.trainingIntensity;

    for (final p in team.players) {
      // 「才能開花」の発生有無は毎週リセットする(セーブデータには
      // 保存しない一時的なフラグ)。
      p.hadBreakthroughThisWeek = false;
      // ローン放出中の選手は貸出先で練習しているため、自クラブの施設・
      // スタッフによる成長ボーナスは適用せず、貸出先の標準的な環境
      // ([loanHostGrowthMultiplier])で育つ。
      final isLoanedOut = p.isLoanedOut;
      final effectiveGrowthMultiplier =
          (isLoanedOut ? loanHostGrowthMultiplier : growthMultiplier) *
              weekScale;
      final effectiveFatigueRecoveryBonus =
          isLoanedOut ? 0 : fatigueRecoveryBonus;

      _applyToPlayer(
        p,
        focus,
        effectiveGrowthMultiplier,
        effectiveFatigueRecoveryBonus,
        intensity,
        injuryFactor,
        weekScale,
      );
    }
  }

  /// 監督がその週の練習を軽くするか。水準4以上の監督は、先発の平均疲労が
  /// [easeFatigueLine]を超えた週は強度を軽めに、[restFatigueLine]を超えた
  /// 週は休養にする(練習の中身は監督の仕事。2026-11-23)。返すのは
  /// (重点, 強度)。軽くしないなら両方 null。
  static (TrainingFocus?, TrainingIntensity?) managerEasing({
    required int managerLevel,
    required double starterFatigue,
  }) {
    if (managerLevel < easeManagerLevel) return (null, null);
    if (starterFatigue > restFatigueLine) return (TrainingFocus.rest, null);
    if (starterFatigue > easeFatigueLine) {
      return (null, TrainingIntensity.light);
    }
    return (null, null);
  }

  /// 練習を軽くする監督の水準の下限。
  static const int easeManagerLevel = 4;

  /// 先発の平均疲労がこれを超えたら、強度を軽めにする。60では日程の
  /// 詰まったイングランドで自クラブが CPU より5ほど疲れたままだった。
  static const int easeFatigueLine = 45;

  /// 先発の平均疲労がこれを超えたら、休養にする。
  static const int restFatigueLine = 60;

  static void _applyToPlayer(
    Player p,
    TrainingFocus focus,
    double growthMultiplier,
    int fatigueRecoveryBonus,
    TrainingIntensity intensity,
    double injuryFactor,
    double weekScale,
  ) {
    final intensityFactor = intensity.factor;
    final effectiveGrowth = growthMultiplier * intensityFactor;

    switch (focus) {
      case TrainingFocus.balanced:
        // ポジションに応じた「全体練習」。攻撃特化・守備特化のちょうど中間で、
        // どのポジションの選手もそれぞれの主戦場の能力を伸ばせる。特化練習の
        // 0.5に対して0.35なので、狙いを定めた方が伸びは速い。
        if (p.position.group == PositionGroup.gk) {
          for (final k in AttributeKeys.goalkeeping) {
            _grow(p, k, 0.35 * effectiveGrowth);
          }
        } else if (p.position.group == PositionGroup.def) {
          for (final k in [
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.anticipation,
          ]) {
            _grow(p, k, 0.35 * effectiveGrowth);
          }
        } else {
          for (final k in [
            AttributeKeys.finishing,
            AttributeKeys.longShots,
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
          ]) {
            _grow(p, k, 0.35 * effectiveGrowth);
          }
        }
        // 技術系はポジションを問わず全員が取り組む。
        for (final k in [
          AttributeKeys.passing,
          AttributeKeys.firstTouch,
          AttributeKeys.technique,
        ]) {
          _grow(p, k, 0.25 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (fatigueBalanced * intensityFactor).round())
            .clamp(0, 100);
        break;
      case TrainingFocus.attack:
        final primary = (p.position.group == PositionGroup.att ||
                p.position.group == PositionGroup.mid)
            ? 0.5
            : 0.15;
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, primary * effectiveGrowth);
        }
        for (final k in [
          AttributeKeys.passing,
          AttributeKeys.firstTouch,
          AttributeKeys.technique,
        ]) {
          _grow(p, k, 0.25 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (fatigueFocused * intensityFactor).round())
            .clamp(0, 100);
        break;
      case TrainingFocus.defense:
        if (p.position.group == PositionGroup.gk) {
          // GKはタックル/マーキングではなく、ゴールキーピング系の能力を伸ばす。
          for (final k in AttributeKeys.goalkeeping) {
            _grow(p, k, 0.5 * effectiveGrowth);
          }
        } else {
          final primary = p.position.group == PositionGroup.def ? 0.5 : 0.15;
          for (final k in [
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.anticipation,
          ]) {
            _grow(p, k, primary * effectiveGrowth);
          }
          for (final k in [
            AttributeKeys.passing,
            AttributeKeys.firstTouch,
            AttributeKeys.technique,
          ]) {
            _grow(p, k, 0.2 * effectiveGrowth);
          }
        }
        p.fatigue = (p.fatigue + (fatigueFocused * intensityFactor).round())
            .clamp(0, 100);
        break;
      case TrainingFocus.fitness:
        for (final k in [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ]) {
          _grow(p, k, 0.45 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (fatigueFitness * intensityFactor).round())
            .clamp(0, 100);
        break;
      case TrainingFocus.positionSwitch:
        for (final pos in p.secondaryPositions) {
          if (_rng.nextDouble() < (0.5 * effectiveGrowth).clamp(0, 1)) {
            p.growFamiliarity(pos, amount: 2);
          }
        }
        p.fatigue = (p.fatigue + (fatigueSwitch * intensityFactor).round())
            .clamp(0, 100);
        break;
      case TrainingFocus.rest:
        p.fatigue = (p.fatigue - 30 - fatigueRecoveryBonus).clamp(0, 100);
        p.morale = (p.morale + 8).clamp(0, 100);
        break;
    }

    // 日々の全体練習による底上げ。重点練習で伸びるのは7項目前後だが、
    // 総合力([Player.overall])は28項目前後の加重平均なので、重点練習だけ
    // では総合力がポテンシャルの7割強で頭打ちになり、どれだけ育てても
    // 才能を出し切れない(長期実測で到達率73%・95%到達者0%を確認)。
    // 重点項目より大幅に低い確率で、総合力に効く能力値全体をゆっくり
    // 底上げすることで、丁寧に育てた選手はキャリアをかけてポテンシャルへ
    // 近づける。休養週は練習しないので底上げも起きない。
    if (focus != TrainingFocus.rest) {
      final taper = _conditioningAgeTaper(p);
      if (taper > 0) {
        for (final k in _conditioningKeysFor(p)) {
          _grow(p, k, _conditioningChance * effectiveGrowth * taper);
        }
      }
    }

    p.fatigue = (p.fatigue - weeklyRecovery - fatigueRecoveryBonus ~/ 2)
        .clamp(0, 100);

    if (focus != TrainingFocus.rest) {
      _rollTrainingInjury(p, intensityFactor, injuryFactor);
      _rollBreakthrough(p, focus, effectiveGrowth);
    }

    _rollWeeklyDecline(p, weekScale);
  }

  /// 週ごとの衰え。衰えの始まる年齢を過ぎると、確率で能力が落ちる。
  /// 確率は[declineSeverity]倍(1を超えると1週に2回以上落ちることがある)。
  static void _rollWeeklyDecline(Player p, double weekScale) {
    if (p.age < declineStartAge(p)) return;
    final expected =
        _declineChance(p.growthType) * declineSeverity(p) * weekScale;
    var events = expected.floor();
    if (_rng.nextDouble() < expected - events) events++;
    for (var i = 0; i < events; i++) {
      _decline(p);
    }
  }

  /// 衰えが速まる年齢(衰えの始まる年齢の翌年。標準の型の真ん中の選手なら32歳)。
  static int declineAccelerationAge(Player p) => declineStartAge(p) + 1;

  /// 衰えの強さの倍率。衰えの始まった年は1倍で、速まる年齢
  /// ([declineAccelerationAge])から1年ごとに0.8倍ずつ足す(上限4.5倍)。
  ///
  /// 以前は衰えの始まりから何歳になっても同じ速さ(年1〜1.5)で、35歳を
  /// 過ぎても主力のまま残っていた。実在の選手は32〜33歳から落ち方が
  /// はっきり速くなる(2026-11-22)。
  static double declineSeverity(Player p) {
    final over = p.age - declineAccelerationAge(p) + 1;
    if (over <= 0) return 1.0;
    return min(4.5, 1.0 + 0.8 * over);
  }

  /// 画面に出ない選手([OffscreenDevelopment])の1年ぶんの衰えの目安
  /// (総合力)。画面に出る他のクラブの選手が1年の練習([applyPassiveCpuGrowth]。
  /// 底上げで少し戻る分を含む)で落ちる量に合わせてある(実測で
  /// 倍率1倍あたり約0.95、練習で戻る分が約0.45)。戻りは以前 0.25 だったが、
  /// CPU の練習を自クラブの全体練習と同じ数にした(技術3項目が足された)
  /// ので測り直した(2026-11-23。31・33・35歳で画面の内外の差 0.2 前後)。
  static double yearlyDeclineEstimate(Player p) {
    if (p.age < declineStartAge(p)) return 0;
    final net = max(0.0, 0.95 * declineSeverity(p) - 0.45);
    return net *
        _declineChance(p.growthType) /
        _declineChance(PlayerGrowthType.balanced);
  }

  /// 高強度の練習メニューによる軽度の負傷判定。基礎体力(naturalFitness)が
  /// 高い選手ほど負傷しにくい。試合中の負傷より短期で済む(1〜2週)。
  static void _rollTrainingInjury(
    Player p,
    double intensityFactor,
    double injuryFactor,
  ) {
    // 怪我をしている選手は練習に出ていない。ここで新しく怪我を振ると、
    // 残りの離脱が1〜3週に上書きされ、長い怪我が短くなっていた(5週が2週に)。
    if (p.injuryWeeks > 0) return;
    final naturalFitnessFactor =
        (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200).clamp(
      0.5,
      1.5,
    );
    final chance = (0.01 + p.fatigue / 100 * 0.015) *
        intensityFactor *
        naturalFitnessFactor *
        MatchEngine.injuryPronenessFactor(p) *
        injuryFactor;
    if (_rng.nextDouble() < chance) {
      p.injuryWeeks = (p.injuryWeeks + 1 + _rng.nextInt(2)).clamp(1, 3);
      p.injuryType = InjuryType.muscle;
      p.injuryHistoryCounts[InjuryType.muscle.name] =
          (p.injuryHistoryCounts[InjuryType.muscle.name] ?? 0) + 1;
    }
  }

  /// 出場経験を通じたメンタル系能力の成長。試合に出場した選手に対して
  /// [MatchEngine.applyPostMatchEffects]から呼ばれ、判断力・冷静さ・視野・
  /// 予測・リーダーシップのいずれか1項目をわずかな確率で伸ばす。
  static const List<String> matchExperienceGrowthKeys = [
    AttributeKeys.composure,
    AttributeKeys.decisions,
    AttributeKeys.vision,
    AttributeKeys.anticipation,
    AttributeKeys.leadership,
  ];

  static void growFromMatchExperience(Player p) {
    final key = matchExperienceGrowthKeys[_rng.nextInt(
      matchExperienceGrowthKeys.length,
    )];
    _grow(p, key, 0.06);
  }

  /// 戦術ミーティングによる、スカッド全体のメンタル面(判断力・位置取り・
  /// チームワーク)への小さな底上げ。個別方針とは別枠のクールダウン制コマンド
  /// として扱う(呼び出し側がクールダウンを管理する)。
  static void applyTacticalMeeting(List<Player> players) {
    for (final p in players) {
      _grow(p, AttributeKeys.decisions, 0.35);
      _grow(p, AttributeKeys.positioning, 0.35);
      _grow(p, AttributeKeys.teamwork, 0.35);
    }
  }

  /// ローン放出中(武者修行中)の選手が貸出先で毎週得る成長。貸出先で
  /// 実戦に出場している前提のため、実戦感覚(マッチシャープネス)を保ち、
  /// ポジション・育成方針に応じた能力と実戦経験によるメンタルが伸びる。
  /// 若い選手ほど武者修行の効果が大きく、ベテランには効果が薄い。
  /// 自クラブの施設・スタッフのボーナスは引き続き適用されない
  /// ([applyWeeklyTraining]側で除外)。
  /// ローン放出中の選手が貸出先で受ける成長倍率。かつては1.0(施設・
  /// スタッフの補正なし)で、自クラブの施設をレベル3まで上げていると
  /// 1.46倍との差が大きく、武者修行に出すと控えに置くより育たなかった
  /// (実測で4シーズンの成長が武者修行8.4に対し紅白戦つきの控え9.5)。
  /// 貸出先にもコーチと練習場があるという前提で、自クラブの施設を
  /// 育てる意味は残しつつ差を縮める。
  static const double loanHostGrowthMultiplier = 1.35;

  static const double loanDevelopmentYoungFactor = 1.5;
  static const double loanDevelopmentVeteranFactor = 0.6;
  static const int loanDevelopmentSharpnessGain = 6;

  /// 出場を約束させた貸出(育成型)で、成長に掛かる倍率。
  ///
  /// ただ貸し出すと、出番があるかは貸出先の都合次第になる。約束させると
  /// 確実に試合に出るので伸びるが、貸出先はその見返りを求める
  /// (レンタル料が入らない)。
  static const double loanPlayingTimeFactor = 1.6;

  static void applyLoanDevelopment(Player p, {double weekScale = 1.0}) {
    p.matchSharpness =
        (p.matchSharpness + loanDevelopmentSharpnessGain).clamp(0, 100);
    growFromMatchExperience(p);
    var factor = (p.age < 24
            ? loanDevelopmentYoungFactor
            : loanDevelopmentVeteranFactor) *
        weekScale;
    if (p.loanedWithPlayingTime) factor *= loanPlayingTimeFactor;
    for (final k in _youthGrowthKeysFor(p)) {
      _grow(p, k, 0.5 * factor);
    }
  }

  /// 成長推移([Player.overallHistory])として保存する週次スナップショットの
  /// 上限数。おおむね1シーズン分を保持し、古いものから捨てる。
  static const int overallHistoryLimit = 40;

  /// 現在の総合力を成長推移の末尾に記録する(節送りごとに1回呼ばれる)。
  static void recordOverallHistory(Player p) {
    p.overallHistory.add(p.overall);
    while (p.overallHistory.length > overallHistoryLimit) {
      p.overallHistory.removeAt(0);
    }
  }

  /// 紅白戦(スカッド内の練習試合)によるマッチシャープネスの回復量。
  static const int practiceMatchSharpnessGain = 8;

  /// 紅白戦で溜まる疲労。実戦形式のぶん、通常練習に少し上乗せされる。
  static const int practiceMatchFatigue = 4;

  /// 紅白戦で実戦経験によるメンタル成長([growFromMatchExperience])の
  /// 判定が走る確率。公式戦出場(毎試合確定で判定)よりは控えめ。
  static const double practiceMatchExperienceChance = 0.35;

  /// 紅白戦(スカッド内の練習試合)。週次トレーニングの一環として自動で
  /// 行われ、スタメン以外の選手が実戦感覚(マッチシャープネス)を保ち、
  /// まれに実戦経験によるメンタル成長の機会も得る。公式戦に出ている
  /// スタメン組はそちらで感覚を保っているため対象外。負傷・代表招集・
  /// ローン放出中の選手は参加できない(出場停止は公式戦のみの処分の
  /// ため参加できる)。効果を受けた選手のリストを返す。
  static List<Player> applyIntraSquadMatch(Team team) {
    final participants = <Player>[];
    for (final p in team.players) {
      if (team.startingXI.contains(p.id)) continue;
      if (p.isInjured || p.isOnInternationalDuty || p.isLoanedOut) continue;
      p.matchSharpness =
          (p.matchSharpness + practiceMatchSharpnessGain).clamp(0, 100);
      p.fatigue = (p.fatigue + practiceMatchFatigue).clamp(0, 100);
      if (_rng.nextDouble() < practiceMatchExperienceChance) {
        growFromMatchExperience(p);
      }
      participants.add(p);
    }
    return participants;
  }

  /// CPU のクラブの練習の伸びの倍率。自クラブの標準(ヘッドコーチ・練習
  /// 施設とも Lv1 の全体練習)を 1.0 として、部が上がるほど良いコーチと
  /// 設備を持っている分だけ伸びる(3部 1.0・2部 1.15・1部 1.3。部が
  /// 分からないときは 1.0)。
  static double cpuStandardGrowthMultiplier(int? tier) => switch (tier) {
        1 => 1.3,
        2 => 1.15,
        _ => 1.0,
      };

  /// CPU のクラブの週の練習。自クラブの全体練習([TrainingFocus.balanced]
  /// の通常の強度)と同じ数を、部の倍率([cpuStandardGrowthMultiplier])で
  /// 掛けて与える。主戦場の能力 0.35・技術3項目 0.25・底上げ
  /// [_conditioningChance](年齢で効かなくなる)。衰えも同じ決まりで入る。
  ///
  /// 練習の疲れ・練習中の怪我・才能開花は CPU には付けない(疲れを付けると
  /// 試合の強さに効き、CPU だけ試合の前に休ませる仕組みが無いので弱くなる)。
  ///
  /// **以前は年齢で倍率を変えていた(2026-11-23 にやめた)。** 24歳未満は
  /// 0.5×0.4×2.5=0.5(主戦場)と底上げ 0.085、24歳以上は 0.2 と 0.034
  /// だった。若手の底上げが自クラブ Lv1 の2倍あり、補充で入る21〜27歳が
  /// 数季で潜在の上限まで届いた。他の部は年1回の伸び([OffscreenDevelopment])
  /// で育つので、膨らむのは自クラブのいる部だけになり、上手に経営しても
  /// 3部の上位の総合力が季ごとに上がって抜け出せなかった。逆に年齢の倍率を
  /// 0.4 のまま全体に掛けると、リーグ平均が 51→40 まで下がった(過去の実測)。
  /// 自クラブの標準と同じ数にそろえるのが、どちらにも倒れない形。
  static void applyPassiveCpuGrowth(
    Team team, {
    int? tier,
    double weekScale = 1.0,
  }) {
    final m = cpuStandardGrowthMultiplier(tier) * weekScale;
    for (final p in team.players) {
      if (p.isLoanedOut) continue;
      if (p.position.group == PositionGroup.gk) {
        for (final k in AttributeKeys.goalkeeping) {
          _grow(p, k, 0.35 * m);
        }
      } else if (p.position.group == PositionGroup.def) {
        for (final k in [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ]) {
          _grow(p, k, 0.35 * m);
        }
      } else {
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, 0.35 * m);
        }
      }
      for (final k in [
        AttributeKeys.passing,
        AttributeKeys.firstTouch,
        AttributeKeys.technique,
      ]) {
        _grow(p, k, 0.25 * m);
      }
      final taper = _conditioningAgeTaper(p);
      if (taper > 0) {
        for (final k in _conditioningKeysFor(p)) {
          _grow(p, k, _conditioningChance * m * taper);
        }
      }
      _rollWeeklyDecline(p, weekScale);
    }
  }

  /// ユース施設のレベルに応じた昇格候補(有望株)の週次成長係数。
  /// レベルが高いほど、昇格を焦らずじっくり育てる価値が生まれる。
  static double youthAcademyGrowthFactor(int facilityLevel) =>
      0.5 + facilityLevel * 0.2;

  /// ユース昇格候補(とローン先の選手)が伸ばす属性群。GKはゴールキーピング系、
  /// DFは守備系、それ以外は攻撃系。
  static List<String> _youthGrowthKeysFor(Player p) {
    if (p.position.group == PositionGroup.gk) {
      return AttributeKeys.goalkeeping;
    }
    return p.position.group == PositionGroup.def
        ? const [
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.anticipation,
          ]
        : const [
            AttributeKeys.finishing,
            AttributeKeys.longShots,
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
          ];
  }

  /// スカウトした昇格候補は、昇格させるまでユース施設で育成され続ける。
  /// 実戦がない分CPUの週次成長よりは緩やかだが、ユース施設のレベルが
  /// 高いほど伸びが早く、昇格のタイミングを見極めるゲーム性が生まれる。
  /// 伸びる属性群はポジションで決まる([_youthGrowthKeysFor])。

  /// ユースコーチの得意分野で、重点的に伸びる能力値。
  ///
  /// 能力値(1-20)は「どれだけ上手いか」しか表さないため、誰を雇っても
  /// 育つ能力が同じだった。得意分野を見て伸ばす先を変えると、コーチの
  /// 人選がそのままユースの色になる。
  /// ユースコーチの指導で、追加で伸びる項目。
  ///
  /// **倍率を上げても効かない。** [_grow]は1週1項目につき最大+1で、確率が
  /// 1を超えている選手は倍率を上げても毎週+1のままになる(実測済み)。指導が高いほど「手の回る項目が増える」という
  /// 形にすると、確率が飽和していても差が出る。
  static List<String> coachTeachingKeys(int coachLevel, Player p) {
    final keys = _youthGrowthKeysFor(p);
    final count = (coachLevel - 1).clamp(0, keys.length);
    return keys.take(count).toList();
  }

  static List<String> specialtyKeys(StaffSpecialty specialty, Player p) {
    final isKeeper = p.position.group == PositionGroup.gk;
    switch (specialty) {
      case StaffSpecialty.balanced:
        return const [];
      case StaffSpecialty.attacking:
        // GKに決定力を教えても意味がない。担当が違う分野は効かない。
        return isKeeper
            ? const []
            : const [
                AttributeKeys.finishing,
                AttributeKeys.offTheBall,
                AttributeKeys.technique,
              ];
      case StaffSpecialty.defending:
        return isKeeper
            ? const []
            : const [
                AttributeKeys.tackling,
                AttributeKeys.marking,
                AttributeKeys.positioning,
              ];
      case StaffSpecialty.goalkeeping:
        return isKeeper ? AttributeKeys.goalkeeping : const [];
      case StaffSpecialty.physical:
        return const [
          AttributeKeys.stamina,
          AttributeKeys.strength,
          AttributeKeys.acceleration,
        ];
    }
  }

  static void applyYouthAcademyGrowth(
    List<Player> prospects,
    int facilityLevel, {
    /// ユースコーチの得意分野。その分野の能力が追加で伸びる。
    StaffSpecialty coachSpecialty = StaffSpecialty.balanced,

    /// ユースコーチの指導のレベル(1-8)。高いほど手の回る項目が増える。
    int coachLevel = 1,

    /// 1季の総量を合わせる倍率([applyWeeklyTraining]の weekScale と同じ)。
    double weekScale = 1.0,
  }) {
    final factor = youthAcademyGrowthFactor(facilityLevel) * weekScale;

    for (final p in prospects) {
      for (final k in _youthGrowthKeysFor(p)) {
        _grow(p, k, 0.5 * factor);
      }

      // ユースコーチの指導。手が回る項目が増える形で効く。
      for (final k in coachTeachingKeys(coachLevel, p)) {
        _grow(p, k, 0.5 * factor);
      }

      // ユースコーチの得意分野。担当が違う分野(GKに決定力など)は効かない。
      for (final k in specialtyKeys(coachSpecialty, p)) {
        _grow(p, k, 0.5 * factor);
      }

      // 一軍の全体練習と同じ底上げ(ユース施設の係数つき)。以前はポジションの
      // 4項目しか伸びず、総合力は28項目前後の加重平均なので、アカデミーで
      // 何年育てても総合力が上がりきらず、一軍の戦力に届かなかった
      // (2026-11-23)。
      final taper = _conditioningAgeTaper(p);
      if (taper > 0) {
        for (final k in _conditioningKeysFor(p)) {
          _grow(p, k, _conditioningChance * factor * taper);
        }
      }
    }
  }

  /// ポジションによるピークのずれ(年)。GK は長く保ち、センターバックも
  /// 経験で補える。走力で勝負するサイドの選手は早く落ちる(実在の傾向)。
  static int positionPeakShift(Position pos) => switch (pos) {
        Position.gk => 3,
        Position.dc => 1,
        Position.dr ||
        Position.dl ||
        Position.wbr ||
        Position.wbl ||
        Position.mr ||
        Position.ml ||
        Position.amr ||
        Position.aml =>
          -1,
        _ => 0,
      };

  /// 成長タイプ(早熟/標準/大器晩成)とポジションに応じて衰えが始まる年齢。
  static int declineStartAge(Player p) =>
      switch (p.growthType) {
        PlayerGrowthType.early => 28,
        PlayerGrowthType.balanced => 31,
        PlayerGrowthType.late => 34,
      } +
      positionPeakShift(p.position);

  /// 衰え開始年齢に達した後、週次で実際に衰えが発生する確率。
  /// 1回の衰えは能力値1〜2項目が1ずつ下がるだけで、総合力([Player.overall])
  /// への影響は0.04程度しかない。かつてはこの値が0.1前後で、衰えの総量が
  /// 年0.2程度にしかならず、ベテランがまったく衰えなかった(実測でピーク
  /// からの下落0.1)。年1〜1.5程度は落ちる確率に引き上げている。
  static double _declineChance(PlayerGrowthType type) => switch (type) {
        PlayerGrowthType.early => 0.45,
        PlayerGrowthType.balanced => 0.4,
        PlayerGrowthType.late => 0.3,
      };

  /// 成長タイプ・年齢に応じた伸びやすさの倍率。早熟は10代後半〜20代前半で
  /// 大きく伸びる代わりに20代後半以降は急速に伸び悩み、大器晩成はその逆に
  /// 若いうちの伸びは控えめだが20代後半〜30代前半まで高い伸びしろを保つ。
  static double _growthAgeFactor(Player p) {
    final age = p.age;
    switch (p.growthType) {
      case PlayerGrowthType.early:
        if (age <= 21) return 1.3;
        if (age <= 27) return 1.0;
        if (age <= 30) return 0.6;
        return 0.3;
      case PlayerGrowthType.balanced:
        if (age <= 27) return 1.0;
        if (age <= 30) return 0.8;
        return 0.4;
      case PlayerGrowthType.late:
        if (age <= 21) return 0.7;
        if (age <= 27) return 1.0;
        if (age <= 32) return 1.15;
        return 0.6;
    }
  }

  /// 「才能開花」(ブレイクスルー)が発生する基本確率。地道な毎週の成長
  /// ([_grow])とは別に、まれに複数の能力値が一気に伸びる特別な瞬間を
  /// 用意することで、育成の手応え・驚きを演出する。
  static const double _breakthroughBaseChance = 0.015;

  /// ブレイクスルー確率に対する、成長タイプ・年齢による倍率。早熟は若い
  /// うちに、大器晩成はより長い期間にわたって開花が起きやすい。
  static double _breakthroughAgeFactor(Player p) {
    final age = p.age;
    switch (p.growthType) {
      case PlayerGrowthType.early:
        if (age <= 23) return 1.5;
        if (age <= 27) return 0.8;
        return 0.2;
      case PlayerGrowthType.balanced:
        if (age <= 26) return 1.2;
        if (age <= 29) return 0.7;
        return 0.2;
      case PlayerGrowthType.late:
        if (age <= 24) return 0.6;
        if (age <= 30) return 1.4;
        return 0.5;
    }
  }

  /// フォーカス・ポジションに応じて、ブレイクスルーで伸ばす能力値の候補群を
  /// 返す。実際に取り組んでいる練習内容と無関係な能力が伸びると不自然な
  /// ため、通常成長([_applyToPlayer]の各focus分岐)と同じ属性群を使う。
  static List<String> _breakthroughPoolFor(Player p, TrainingFocus focus) {
    if (p.position.group == PositionGroup.gk) {
      return AttributeKeys.goalkeeping;
    }
    switch (focus) {
      case TrainingFocus.attack:
        return const [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
          AttributeKeys.technique,
        ];
      case TrainingFocus.defense:
        return const [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ];
      case TrainingFocus.fitness:
        return const [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ];
      case TrainingFocus.balanced:
      case TrainingFocus.positionSwitch:
      case TrainingFocus.rest:
        return p.position.group == PositionGroup.def
            ? const [
                AttributeKeys.tackling,
                AttributeKeys.marking,
                AttributeKeys.positioning,
                AttributeKeys.anticipation,
              ]
            : const [
                AttributeKeys.finishing,
                AttributeKeys.longShots,
                AttributeKeys.dribbling,
                AttributeKeys.offTheBall,
              ];
    }
  }

  /// 才能開花イベントの判定。発生すると、フォーカスに応じた能力値群のうち
  /// 2〜4個がまとめて+2〜4伸びる(ポテンシャル上限まで)。通常の地道な成長
  /// とは独立して判定される特別なボーナスで、[Player.hadBreakthroughThisWeek]
  /// に反映してUI側で「才能開花」として強調表示できるようにする。
  static void _rollBreakthrough(
    Player p,
    TrainingFocus focus,
    double effectiveGrowth,
  ) {
    var chance = _breakthroughBaseChance *
        _breakthroughAgeFactor(p) *
        effectiveGrowth.clamp(0.4, 2.5);
    chance *= 0.7 + p.attributeValue(AttributeKeys.determination) / 165;
    if (_rng.nextDouble() >= chance) return;

    final pool = _breakthroughPoolFor(p, focus);
    final shuffled = [...pool]..shuffle(_rng);
    final count = min(2 + _rng.nextInt(3), shuffled.length);
    for (var i = 0; i < count; i++) {
      final key = shuffled[i];
      final current = p.attributeValue(key);
      final boost = 2 + _rng.nextInt(3);
      p.setAttributeValue(key, (current + boost).clamp(1, p.potential));
    }
    p.hadBreakthroughThisWeek = true;
  }

  /// 選手特性ごとに対応する属性キー(能力値ベースで適性を判定する特性のみ)。
  static const Map<PlayerTrait, String> _traitAttributeKeys = {
    PlayerTrait.warriorSpirit: AttributeKeys.determination,
    PlayerTrait.calmHead: AttributeKeys.composure,
    PlayerTrait.leaderOnPitch: AttributeKeys.leadership,
    PlayerTrait.visionary: AttributeKeys.vision,
    PlayerTrait.paceMerchant: AttributeKeys.pace,
    PlayerTrait.powerhouse: AttributeKeys.strength,
    PlayerTrait.enginesRunning: AttributeKeys.stamina,
    PlayerTrait.silkyDribbler: AttributeKeys.dribbling,
    PlayerTrait.playmakerTrait: AttributeKeys.passing,
    PlayerTrait.ballWinner: AttributeKeys.tackling,
    PlayerTrait.shadowMarker: AttributeKeys.marking,
    PlayerTrait.clinicalFinisher: AttributeKeys.finishing,
    PlayerTrait.distanceShooter: AttributeKeys.longShots,
    PlayerTrait.aerialThreat: AttributeKeys.jumpingReach,
    PlayerTrait.showman: AttributeKeys.flair,
    PlayerTrait.sureTouch: AttributeKeys.firstTouch,
    PlayerTrait.crossSpecialist: AttributeKeys.crossing,
    PlayerTrait.setPieceMaestro: AttributeKeys.freeKick,
    PlayerTrait.clockwork: AttributeKeys.anticipation,
    PlayerTrait.decisiveMind: AttributeKeys.decisions,
    PlayerTrait.teamPlayer: AttributeKeys.teamwork,
    PlayerTrait.tirelessRunner: AttributeKeys.workRate,
    PlayerTrait.explosiveStart: AttributeKeys.acceleration,
    PlayerTrait.fearlessDefender: AttributeKeys.bravery,
    PlayerTrait.divineReflexes: AttributeKeys.reflexes,
  };

  /// [trait]の適性判定に使う対応能力値キー(能力値ベースの特性のみ、
  /// なければnull)。生成時の「その選手にあり得ない特性」の除外判定
  /// (PlayerGenerator)からも参照する。
  static String? traitAttributeKeyOf(PlayerTrait trait) =>
      _traitAttributeKeys[trait];

  /// 選手が[trait]にどれだけ向いているかを表す倍率(生成時の特性の抽選の重み)。
  /// 対応する能力値・年齢が特性の発動条件に近い選手ほど高くなる
  /// (概ね0.3〜1.6の範囲)。対戦相手や天候・試合当日のコンディションに
  /// 依存する特性(判官びいき・天候系・波がある、等)は個人の資質だけでは
  /// 適性を判断できないため中立(1.0)を返す。
  static double traitSuitability(Player p, PlayerTrait trait) {
    final attrKey = _traitAttributeKeys[trait];
    if (attrKey != null) {
      final value = p.attributeValue(attrKey);
      return (0.5 + value / 100).clamp(0.3, 1.6);
    }
    switch (trait) {
      case PlayerTrait.wonderkid:
        return p.age <= 21
            ? 1.5
            : p.age <= 24
                ? 1.0
                : 0.3;
      case PlayerTrait.oldHead:
        return p.age >= 32
            ? 1.5
            : p.age >= 28
                ? 1.0
                : 0.3;
      case PlayerTrait.primeTime:
        return (p.age >= 26 && p.age <= 29) ? 1.5 : 0.7;
      default:
        return 1.0;
    }
  }

  /// 全体練習による底上げの1項目あたりの成長確率。重点練習(0.35〜0.5)の
  /// 10分の1程度に抑えており、方針を選ぶ意味は失われない。
  static const double _conditioningChance = 0.04;

  /// 全体的な底上げが効かなくなっていく年齢カーブ。重点練習は年を取っても
  /// ある程度は効く(ベテランが一芸を磨くのは自然)が、全体的な地力の
  /// 底上げは選手としてのピークを過ぎると止まる。これがないと総合力が
  /// 生涯上がり続け、35歳がキャリア最高という不自然なカーブになる
  /// (実測でピーク年齢29〜34歳・ピークからの下落0.1を確認)。
  static double _conditioningAgeTaper(Player p) {
    final peakAge = switch (p.growthType) {
          PlayerGrowthType.early => 25,
          PlayerGrowthType.balanced => 27,
          PlayerGrowthType.late => 29,
        } +
        positionPeakShift(p.position);
    if (p.age <= peakAge) return 1.0;
    return (1.0 - (p.age - peakAge) * 0.34).clamp(0.0, 1.0);
  }

  /// 総合力([Player.overall])の算出に使われる能力値。ここを底上げしないと
  /// 総合力が頭打ちになるため、全体練習の対象にする。
  static List<String> _conditioningKeysFor(Player p) {
    if (p.position.group == PositionGroup.gk) {
      return const [
        ...AttributeKeys.goalkeeping,
        AttributeKeys.tackling,
        AttributeKeys.marking,
        AttributeKeys.positioning,
        AttributeKeys.anticipation,
        AttributeKeys.strength,
        AttributeKeys.concentration,
        AttributeKeys.bravery,
        AttributeKeys.stamina,
        AttributeKeys.naturalFitness,
        AttributeKeys.workRate,
        AttributeKeys.acceleration,
      ];
    }
    return const [
      // 攻撃力
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.dribbling,
      AttributeKeys.offTheBall,
      AttributeKeys.composure,
      AttributeKeys.pace,
      AttributeKeys.flair,
      AttributeKeys.balance,
      // 守備力
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.anticipation,
      AttributeKeys.strength,
      AttributeKeys.aggression,
      AttributeKeys.concentration,
      AttributeKeys.bravery,
      // 技術
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.vision,
      AttributeKeys.technique,
      AttributeKeys.crossing,
      AttributeKeys.decisions,
      AttributeKeys.teamwork,
      // スタミナ
      AttributeKeys.stamina,
      AttributeKeys.naturalFitness,
      AttributeKeys.workRate,
      AttributeKeys.acceleration,
    ];
  }

  static void _grow(Player p, String key, double chance) {
    final current = p.attributeValue(key);
    if (current >= p.potential) return;
    var c = chance * _growthAgeFactor(p);
    // 闘志(determination)が高い選手ほど伸びやすく、低い選手は伸びにくい。
    c *= 0.7 + p.attributeValue(AttributeKeys.determination) / 165;
    // 性格によって自主練習への取り組み方が異なり、成長効率に差が出る。
    c *= p.personality.growthFactor;
    // 向上心(人柄の軸)の高い選手ほど伸びる。
    c *= p.traits.growthFactor;
    // 出場機会が乏しく実戦感覚(マッチシャープネス)が低い選手は伸び悩む。
    if (p.matchSharpness < 40) c *= 0.7;
    // ポテンシャルに近づくほど伸びしろが少なくなり、成長は緩やかになる
    // (残り10未満から徐々に減衰する。それまでは全く減衰しない)。
    final gapToPotential = p.potential - current;
    if (gapToPotential < 10) {
      c *= (0.2 + 0.8 * gapToPotential / 10).clamp(0.2, 1.0);
    }
    if (_rng.nextDouble() > c) return;
    p.setAttributeValue(key, (current + 1).clamp(1, p.potential));
  }

  /// 1回の衰えで下がる能力値の項目数。1項目だけだと総合力への影響が
  /// 小さすぎるため、2項目まとめて下げる。
  static const int declineAttributesPerEvent = 2;

  static void _decline(Player p) {
    final candidates = _declineCandidates(p);
    for (var i = 0; i < declineAttributesPerEvent; i++) {
      final key = candidates[_rng.nextInt(candidates.length)];
      final current = p.attributeValue(key);
      p.setAttributeValue(key, (current - 1).clamp(20, 99));
    }
  }

  /// ポジションごとに衰えやすい能力値グループを重み付けした候補リストを返す。
  /// GKはGK系・フィジカル系、それ以外はフィジカル系(スピード・跳躍力等)が
  /// 優先的に(重複を増やして)選ばれやすくなる。
  static List<String> _declineCandidates(Player p) {
    const physicalHeavy = [
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.agility,
      AttributeKeys.jumpingReach,
      AttributeKeys.stamina,
    ];
    if (p.position.group == PositionGroup.gk) {
      return [
        ...AttributeKeys.all,
        ...AttributeKeys.goalkeeping,
        ...AttributeKeys.goalkeeping,
        ...physicalHeavy,
      ];
    }
    return [...AttributeKeys.all, ...physicalHeavy, ...physicalHeavy];
  }
}
