import 'dart:math';

import '../models/corner_routine.dart';
import '../models/opposition_plan.dart';
import '../models/player_instruction.dart';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';
import '../models/live_match_progress.dart';
import '../models/weather.dart';
import 'lineup_utils.dart';
import 'style_engine.dart';
import 'training_engine.dart';
import '../l10n/tr.dart';

/// この枚数の警告が貯まると次節出場停止になる(退場は即1試合出場停止)。
const int yellowCardSuspensionThreshold = 5;

/// 1試合で使える交代枠。ライブ観戦の手動の交代
/// ([GameState.maxSubstitutionsPerMatch])と、自動の交代
/// ([MatchEngine.applyHalfTimeSubstitutions])で同じ数を使う。
///
/// 実際の決まり(IFAB の競技規則。2022 年から恒久)に合わせて5人。以前は
/// 3人だった。
const int substitutionsPerMatch = 5;

/// 交代できる回数(ハーフタイムは数えない)。5人を3回までに分けて替える。
/// ハーフタイムにいくら替えても、この回数は減らない(実際の決まりと同じ)。
const int substitutionWindowsPerMatch = 3;

/// ハーフタイムの自動の交代1件。
class AutoSubstitution {
  final Player out;
  final Player incoming;

  /// 下がる選手の、試合の前の試合勘。下がった選手も前半は出ているので、
  /// 試合のあとに「出た」ぶんの試合勘に戻すのに使う。
  final int outSharpnessBefore;

  const AutoSubstitution({
    required this.out,
    required this.incoming,
    required this.outSharpnessBefore,
  });
}

/// あるチームのハーフタイムの自動の交代。試合が終わったら
/// [MatchEngine.finishHalfTimeSubstitutions]に渡し、下がった選手の出場を
/// 数えて、先発の指定を試合の前に戻す(交代は試合の中だけのこと)。
class AutoSubstitutionPlan {
  final Team team;
  final List<String> originalXI;
  final List<AutoSubstitution> swaps;

  const AutoSubstitutionPlan({
    required this.team,
    required this.originalXI,
    required this.swaps,
  });

  List<Player> get subbedOff => [for (final s in swaps) s.out];
}

/// 分単位区間([MatchEngine.simulateMinutes])1回分のスコア・イベント。
class HalfResult {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;
  final int homeShots;
  final int awayShots;
  final int homeShotsOnTarget;
  final int awayShotsOnTarget;

  /// この半で評価された各チャンスのhomeShare(ホームがそのチャンスを
  /// 迎える確率)の合計。ポゼッション率の算出に使う。
  final double possessionShareSum;
  final int chanceCount;

  const HalfResult({
    required this.homeGoals,
    required this.awayGoals,
    required this.events,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.possessionShareSum = 0,
    this.chanceCount = 0,
  });
}

/// 攻撃側の決定機での選択(シュート/パス/ロングシュート)と、守備側の
/// 決定機での選択(積極的にタックル/カバーリングに専念)をまとめた列挙。
/// [PendingChanceDecision.context]に応じてどちらの値を渡すべきかが決まる
/// (不適切な値を渡した場合は既定の安全な選択にフォールバックする)。
enum ChanceDecision { shoot, pass, longShot, aggressiveTackle, coverSpace }

/// [PendingChanceDecision]が攻撃側の決定機か守備側の決定機かを表す。
enum ChanceContext { attack, defense }

/// 試合中いつでも変更できる、自クラブの大まかな采配方針。個別の決定機
/// (シュート/パス等)とは独立して、以降の全ての決定機の成功率に反映される。
enum MatchInstruction { balanced, aggressive, cautious }

extension MatchInstructionLabel on MatchInstruction {
  String get label => switch (this) {
        MatchInstruction.balanced => Tr.pick('通常', 'Normal'),
        MatchInstruction.aggressive => Tr.pick('リスクを取る', 'Take risks'),
        MatchInstruction.cautious => Tr.pick('安全に下がる', 'Sit back'),
      };

  String get description => switch (this) {
        MatchInstruction.balanced => Tr.pick('標準的なバランスで戦う', 'Play it as it is'),
        MatchInstruction.aggressive => Tr.pick('攻撃の成功率が上がるが、守備の負担も増える',
            'Better odds going forward, but more asked of the defence'),
        MatchInstruction.cautious => Tr.pick('守備は安定するが、攻撃の迫力は落ちる',
            'A steadier defence, at the cost of attacking threat'),
      };
}

/// オープンプレーの決定機で、ユーザーチームに判断を求めるための情報。
/// [context]が[ChanceContext.attack]の場合はシュート/パス/ロングシュートを
/// (各選択肢の成功率を[shootChance]/[passChance]/[longShotChance]として
/// 事前に提示する)、[ChanceContext.defense]の場合は積極的にタックルに
/// 行くかカバーリングに専念するかを([aggressiveChanceAgainst]/
/// [safeChanceAgainst]として相手の成功率を提示しつつ)選べる。
class PendingChanceDecision {
  final int minute;
  final ChanceContext context;

  // attackコンテキストのみ有効。
  final Player? shooter;
  final Player? passTarget;
  final double? shootChance;
  final double? passChance;
  final double? longShotChance;

  /// シュートの相手となる守備側GK(存在すれば)。UIでの能力値比較表示用。
  final Player? keeper;

  // defenseコンテキストのみ有効。相手チーム視点の得点成功率を示す。
  final Player? attacker;
  final double? aggressiveChanceAgainst;
  final double? safeChanceAgainst;

  /// この決定機で相手を受け止める自チームの守備者。UIでの能力値比較
  /// 表示用で、積極的タックル選択時のカードリスク判定にも使われる。
  final Player? defender;

  const PendingChanceDecision.attack({
    required this.minute,
    required Player this.shooter,
    this.passTarget,
    required double this.shootChance,
    this.passChance,
    required double this.longShotChance,
    this.keeper,
  })  : context = ChanceContext.attack,
        attacker = null,
        aggressiveChanceAgainst = null,
        safeChanceAgainst = null,
        defender = null;

  const PendingChanceDecision.defense({
    required this.minute,
    required Player this.attacker,
    required double this.aggressiveChanceAgainst,
    required double this.safeChanceAgainst,
    this.defender,
  })  : context = ChanceContext.defense,
        shooter = null,
        passTarget = null,
        shootChance = null,
        passChance = null,
        longShotChance = null,
        keeper = null;
}

/// [MatchEngine.beginInteractiveHalf]/[MatchEngine.resolvePendingChance]が
/// 進行状況を保持するための可変状態。[pending]がセットされている間は
/// 進行が止まっており、[MatchEngine.resolvePendingChance]で解決されるまで
/// 再開しない。
class InteractiveHalfState {
  final Team home;
  final Team away;
  final String interactiveTeamId;
  final List<Player> homeLineup;
  final List<Player> awayLineup;

  /// このハーフの天候とホームアドバンテージ。試合中の交代で攻守力を
  /// 再計算する際に、ハーフ開始時と同じ条件を再現するために保持する。
  final Weather weather;
  final double homeAdvantageFactor;

  // 攻守力は試合中の交代([MatchEngine.applyInteractiveSubstitution])で
  // 再計算されるため可変にしている。
  double homeAttackBase;
  double awayAttackBase;
  double homeDefenseBase;
  double awayDefenseBase;
  final List<int> chanceMinutes;
  final List<MatchEvent> events;

  /// この区間より前(後半なら前半)のイベント。退場した選手を交代で
  /// 下げて11人に戻すことを防ぐのに使う。
  final List<MatchEvent> priorEvents;

  // 決定機の中でカード(警告・退場)が出た場合に更新されるため、
  // 事前生成分と合わせて可変にしている。
  int? homeRedMinute;
  int? awayRedMinute;

  int chanceIndex = 0;
  int homeGoals = 0;
  int awayGoals = 0;
  double homeMomentum = 0;
  double awayMomentum = 0;
  int homeShots = 0;
  int awayShots = 0;
  int homeShotsOnTarget = 0;
  int awayShotsOnTarget = 0;
  double possessionShareSum = 0;

  PendingChanceDecision? pending;
  // pending解決に必要な文脈(次のresolvePendingChance呼び出しでのみ使う)。
  bool? pendingIsHomeChance;

  /// 自クラブの現在の采配方針。[MatchEngine.setInstruction]でいつでも
  /// 変更でき、以降に生成される決定機の成功率へ反映される。
  MatchInstruction instruction = MatchInstruction.balanced;

  /// 直近の[MatchEngine.resolvePendingChance]呼び出しで、この決定機の結果
  /// として実際に発生したイベント(得点・惜しいチャンス・カード)。何も
  /// 起きなかった(攻撃が不発に終わった)場合はnull。UI側の即時フィード
  /// バック表示に使う。
  MatchEvent? lastDecisionEvent;

  /// アプリの再起動で試合を途中から再開したとき、それまでに確定していた
  /// ぶん(シュート数・ポゼッション)。得点とイベントは[applyCarried]で
  /// [homeGoals]/[events]へ直接入れてあるので、ここでは足さない。
  HalfTally? carried;

  InteractiveHalfState({
    required this.home,
    required this.away,
    required this.interactiveTeamId,
    required this.homeLineup,
    required this.awayLineup,
    this.weather = Weather.clear,
    this.homeAdvantageFactor = MatchEngine.defaultHomeAdvantageFactor,
    required this.homeAttackBase,
    required this.awayAttackBase,
    required this.homeDefenseBase,
    required this.awayDefenseBase,
    required this.homeRedMinute,
    required this.awayRedMinute,
    required this.chanceMinutes,
    required this.events,
    this.priorEvents = const [],
  });

  /// このハーフの進行が(判断待ちなく)完了したかどうか。
  bool get isFinished => pending == null && chanceIndex >= chanceMinutes.length;

  /// 再開前に確定していた途中経過を引き継ぐ。得点・イベント・退場は
  /// 画面がそのまま表示に使うので、このハーフの値へ直接入れる。
  void applyCarried(HalfTally tally) {
    carried = tally;
    homeGoals += tally.homeGoals;
    awayGoals += tally.awayGoals;
    events.insertAll(0, tally.events);
    for (final e in tally.events) {
      if (e.type != MatchEventType.redCard) continue;
      if (e.teamId == home.id) {
        homeRedMinute =
            homeRedMinute == null ? e.minute : min(homeRedMinute!, e.minute);
      } else if (e.teamId == away.id) {
        awayRedMinute =
            awayRedMinute == null ? e.minute : min(awayRedMinute!, e.minute);
      }
    }
  }

  /// 次に進める分。判断待ちならその決定機の次の分(判断待ちの決定機は
  /// 再開時には「実らなかった攻撃」として扱う)、終わっていれば[endMinute]+1。
  int resumeMinute(int endMinute) {
    final p = pending;
    if (p != null) return p.minute + 1;
    if (chanceIndex < chanceMinutes.length) return chanceMinutes[chanceIndex];
    return endMinute + 1;
  }

  /// [beforeMinute]より前に確定した途中経過。再起動後の再開に使う。
  /// 警告・退場は前もって全時間ぶん抽選されているので、まだ来ていない分の
  /// ものは含めない。
  HalfTally toTally({required int beforeMinute}) {
    final c = carried;
    final processed = chanceIndex + (pending != null ? 1 : 0);
    return HalfTally(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: [
        for (final e in events)
          if (e.minute < beforeMinute) e,
      ]..sort((a, b) => a.minute.compareTo(b.minute)),
      homeShots: homeShots + (c?.homeShots ?? 0),
      awayShots: awayShots + (c?.awayShots ?? 0),
      homeShotsOnTarget: homeShotsOnTarget + (c?.homeShotsOnTarget ?? 0),
      awayShotsOnTarget: awayShotsOnTarget + (c?.awayShotsOnTarget ?? 0),
      possessionShareSum: possessionShareSum + (c?.possessionShareSum ?? 0),
      chanceCount: processed + (c?.chanceCount ?? 0),
    );
  }

  HalfResult toHalfResult() {
    final sorted = [...events]..sort((a, b) => a.minute.compareTo(b.minute));
    // ライブ観戦でも自動消化と同じ基準でシュート数を記録する
    // (枠外・ブロックされた「打っただけ」のシュートを上乗せする)。
    final speculative = MatchEngine.speculativeShotsForStats(
      chanceIndex,
      chanceIndex == 0 ? 0.5 : possessionShareSum / chanceIndex,
    );
    final c = carried;
    return HalfResult(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: sorted,
      homeShots: homeShots + speculative.home + (c?.homeShots ?? 0),
      awayShots: awayShots + speculative.away + (c?.awayShots ?? 0),
      homeShotsOnTarget: homeShotsOnTarget + (c?.homeShotsOnTarget ?? 0),
      awayShotsOnTarget: awayShotsOnTarget + (c?.awayShotsOnTarget ?? 0),
      possessionShareSum: possessionShareSum + (c?.possessionShareSum ?? 0),
      chanceCount: chanceMinutes.length + (c?.chanceCount ?? 0),
    );
  }
}

class MatchEngine {
  static final Random _rng = Random();

  /// チャンス1回あたりの基礎得点確率。実測で互角対戦の平均総ゴール数が
  /// 約2.6〜2.9(現実のリーグ戦相当)、引き分け率が2割台前半〜半ばに
  /// 収まるよう調整した値。simulate系とインタラクティブ系の両方で
  /// 同じ値を使い、ライブ観戦と自動消化の結果が乖離しないようにする。
  /// 2026-11-22 に PK・直接FK を実際の数まで減らしたぶん(約0.15点/試合)を
  /// 戻すため 0.22 から上げた(1試合の得点 約2.6・引き分け約25%は変えない)。
  static const double _baseScoreProb = 0.23;

  /// 決定機のうちセットプレー(PK・直接FK・CK)から生まれる割合。
  static const double _setPieceChanceShare = 0.25;

  /// ホームアドバンテージの既定倍率。実測でホーム勝率と平均得点差が
  /// 現実(勝率でホーム約45%対アウェイ約29%)に近づくよう調整した値。
  static const double defaultHomeAdvantageFactor = 1.10;

  static double _condition(Player p) =>
      (1 - p.fatigue / 250) *
      (0.85 + p.morale / 500) *
      (0.8 + p.matchSharpness / 500) *
      p.matchFormMultiplier;

  static double _avgOverall(List<Player> lineup) => lineup.isEmpty
      ? 50
      : lineup.fold<int>(0, (s, p) => s + p.overall) / lineup.length;

  /// 選手特性による、この試合限りのパフォーマンス倍率を算出する。
  /// [selfAvg]は自チーム、[oppAvg]は相手チームの先発平均総合力。
  /// [isHome]はこの選手のチームがホームかどうか、[weather]はこの試合の天候。
  /// 能力値がある水準に届いて初めて発動する特性の一覧。
  ///
  /// 例えば『冷徹なフィニッシャー』は決定力80以上でなければ何も起きない。
  /// この条件は実装の中にしか無く、画面には出ていなかったため、特性を
  /// 持っているのに効果が無い状態が説明されないままだった。
  ///
  /// 説明と実装が食い違わないよう、判定もこの表を引く(gatedTraitBonus)。
  static const Map<PlayerTrait, ({String attribute, int threshold, double bonus})>
      attributeGatedTraits = {
    PlayerTrait.warriorSpirit: (attribute: AttributeKeys.determination, threshold: 80, bonus: 1.09),
    PlayerTrait.calmHead: (attribute: AttributeKeys.composure, threshold: 80, bonus: 1.09),
    PlayerTrait.leaderOnPitch: (attribute: AttributeKeys.leadership, threshold: 80, bonus: 1.09),
    PlayerTrait.visionary: (attribute: AttributeKeys.vision, threshold: 80, bonus: 1.07),
    PlayerTrait.paceMerchant: (attribute: AttributeKeys.pace, threshold: 80, bonus: 1.07),
    PlayerTrait.powerhouse: (attribute: AttributeKeys.strength, threshold: 80, bonus: 1.07),
    PlayerTrait.enginesRunning: (attribute: AttributeKeys.stamina, threshold: 80, bonus: 1.07),
    PlayerTrait.silkyDribbler: (attribute: AttributeKeys.dribbling, threshold: 80, bonus: 1.07),
    PlayerTrait.playmakerTrait: (attribute: AttributeKeys.passing, threshold: 80, bonus: 1.07),
    PlayerTrait.ballWinner: (attribute: AttributeKeys.tackling, threshold: 80, bonus: 1.07),
    PlayerTrait.shadowMarker: (attribute: AttributeKeys.marking, threshold: 80, bonus: 1.07),
    PlayerTrait.clinicalFinisher: (attribute: AttributeKeys.finishing, threshold: 80, bonus: 1.07),
    PlayerTrait.distanceShooter: (attribute: AttributeKeys.longShots, threshold: 80, bonus: 1.07),
    PlayerTrait.aerialThreat: (attribute: AttributeKeys.jumpingReach, threshold: 80, bonus: 1.07),
    PlayerTrait.showman: (attribute: AttributeKeys.flair, threshold: 80, bonus: 1.07),
    PlayerTrait.sureTouch: (attribute: AttributeKeys.firstTouch, threshold: 80, bonus: 1.06),
    PlayerTrait.crossSpecialist: (attribute: AttributeKeys.crossing, threshold: 80, bonus: 1.06),
    PlayerTrait.setPieceMaestro: (attribute: AttributeKeys.freeKick, threshold: 80, bonus: 1.06),
    PlayerTrait.clockwork: (attribute: AttributeKeys.anticipation, threshold: 80, bonus: 1.06),
    PlayerTrait.decisiveMind: (attribute: AttributeKeys.decisions, threshold: 80, bonus: 1.06),
    PlayerTrait.teamPlayer: (attribute: AttributeKeys.teamwork, threshold: 80, bonus: 1.06),
    PlayerTrait.tirelessRunner: (attribute: AttributeKeys.workRate, threshold: 80, bonus: 1.06),
    PlayerTrait.explosiveStart: (attribute: AttributeKeys.acceleration, threshold: 80, bonus: 1.06),
    PlayerTrait.fearlessDefender: (attribute: AttributeKeys.bravery, threshold: 80, bonus: 1.06),
    PlayerTrait.divineReflexes: (attribute: AttributeKeys.reflexes, threshold: 80, bonus: 1.07),
  };

  /// 能力値で発動する特性の倍率。条件を満たさなければ 1.0(効果なし)。
  static double gatedTraitBonus(
    PlayerTrait trait,
    double Function(String) attr,
  ) {
    final gate = attributeGatedTraits[trait];
    if (gate == null) return 1.0;
    return attr(gate.attribute) >= gate.threshold ? gate.bonus : 1.0;
  }

  static double _traitFormMultiplier(
    Player p, {
    required double selfAvg,
    required double oppAvg,
    required bool isHome,
    required Weather weather,
  }) {
    final trait = p.trait;
    if (trait == null) return 1.0;
    final diff = selfAvg - oppAvg;
    double attr(String key) => p.attributeValue(key).toDouble();
    switch (trait) {
      // 対戦相手との相対的な実力差
      case PlayerTrait.giantKiller:
        return -diff >= 5 ? 1.08 : 1.0;
      case PlayerTrait.frontRunner:
        return diff >= 5 ? 1.08 : 1.0;
      case PlayerTrait.underdogSpirit:
        return -diff >= 10 ? 1.13 : 1.0;
      case PlayerTrait.dominantForce:
        return diff >= 10 ? 1.13 : 1.0;
      // 対戦相手の絶対的な実力
      case PlayerTrait.bigGameHunter:
        return oppAvg >= 75 ? 1.10 : 1.0;
      case PlayerTrait.bullyBall:
        return oppAvg <= 55 ? 1.06 : 1.0;
      // ホーム/アウェイ
      case PlayerTrait.homeBoy:
        return isHome ? 1.05 : 1.0;
      case PlayerTrait.roadWarrior:
        return !isHome ? 1.05 : 1.0;
      // 天候
      case PlayerTrait.rainMaster:
        return weather == Weather.rain ? 1.08 : 1.0;
      case PlayerTrait.windMaster:
        return weather == Weather.wind ? 1.09 : 1.0;
      case PlayerTrait.heatwaveMaster:
        return weather == Weather.heatwave ? 1.10 : 1.0;
      case PlayerTrait.snowMaster:
        return weather == Weather.snow ? 1.14 : 1.0;
      case PlayerTrait.fairWeatherPlayer:
        return weather == Weather.clear ? 1.05 : 1.0;
      // 疲労・コンディション
      case PlayerTrait.ironLungs:
        return p.fatigue >= 70 ? 1.07 : 1.0;
      case PlayerTrait.freshLegs:
        return p.fatigue <= 20 ? 1.08 : 1.0;
      case PlayerTrait.confidentMind:
        return p.morale >= 80 ? 1.06 : 1.0;
      case PlayerTrait.clutchNerves:
        return p.morale <= 30 ? 1.10 : 1.0;
      case PlayerTrait.contentPlayer:
        return p.happiness >= 80 ? 1.05 : 1.0;
      case PlayerTrait.sharpShooter:
        return p.matchSharpness >= 90 ? 1.09 : 1.0;
      case PlayerTrait.rustyButReady:
        return p.matchSharpness <= 40 ? 1.08 : 1.0;
      // 年齢
      case PlayerTrait.wonderkid:
        return p.age <= 21 ? 1.08 : 1.0;
      case PlayerTrait.oldHead:
        return p.age >= 32 ? 1.08 : 1.0;
      case PlayerTrait.primeTime:
        return p.age >= 26 && p.age <= 29 ? 1.05 : 1.0;
      // メンタル属性依存
      case PlayerTrait.warriorSpirit:
        return gatedTraitBonus(PlayerTrait.warriorSpirit, attr);
      case PlayerTrait.calmHead:
        return gatedTraitBonus(PlayerTrait.calmHead, attr);
      case PlayerTrait.leaderOnPitch:
        return gatedTraitBonus(PlayerTrait.leaderOnPitch, attr);
      // 波・安定性。streaky/volatileTalentは他の47特性と同様、期待値が
      // 1.0をわずかに上回るようレンジを設計する(=リスクを取るだけの
      // 見返りがある)。metronomeだけは「安定こそが持ち味」という特性の
      // 性質上、期待値をあえて1.0のまま(振れ幅の小ささのみが価値)にする。
      case PlayerTrait.streaky:
        return 0.85 + _rng.nextDouble() * 0.4;
      case PlayerTrait.volatileTalent:
        return 0.75 + _rng.nextDouble() * 0.65;
      case PlayerTrait.metronome:
        return 0.95 + _rng.nextDouble() * 0.1;
      // 技術・フィジカル属性依存
      case PlayerTrait.visionary:
        return gatedTraitBonus(PlayerTrait.visionary, attr);
      case PlayerTrait.paceMerchant:
        return gatedTraitBonus(PlayerTrait.paceMerchant, attr);
      case PlayerTrait.powerhouse:
        return gatedTraitBonus(PlayerTrait.powerhouse, attr);
      case PlayerTrait.enginesRunning:
        return gatedTraitBonus(PlayerTrait.enginesRunning, attr);
      case PlayerTrait.silkyDribbler:
        return gatedTraitBonus(PlayerTrait.silkyDribbler, attr);
      case PlayerTrait.playmakerTrait:
        return gatedTraitBonus(PlayerTrait.playmakerTrait, attr);
      case PlayerTrait.ballWinner:
        return gatedTraitBonus(PlayerTrait.ballWinner, attr);
      case PlayerTrait.shadowMarker:
        return gatedTraitBonus(PlayerTrait.shadowMarker, attr);
      case PlayerTrait.clinicalFinisher:
        return gatedTraitBonus(PlayerTrait.clinicalFinisher, attr);
      case PlayerTrait.distanceShooter:
        return gatedTraitBonus(PlayerTrait.distanceShooter, attr);
      case PlayerTrait.aerialThreat:
        return gatedTraitBonus(PlayerTrait.aerialThreat, attr);
      case PlayerTrait.showman:
        return gatedTraitBonus(PlayerTrait.showman, attr);
      case PlayerTrait.sureTouch:
        return gatedTraitBonus(PlayerTrait.sureTouch, attr);
      case PlayerTrait.crossSpecialist:
        return gatedTraitBonus(PlayerTrait.crossSpecialist, attr);
      case PlayerTrait.setPieceMaestro:
        return gatedTraitBonus(PlayerTrait.setPieceMaestro, attr);
      case PlayerTrait.clockwork:
        return gatedTraitBonus(PlayerTrait.clockwork, attr);
      case PlayerTrait.decisiveMind:
        return gatedTraitBonus(PlayerTrait.decisiveMind, attr);
      case PlayerTrait.teamPlayer:
        return gatedTraitBonus(PlayerTrait.teamPlayer, attr);
      case PlayerTrait.tirelessRunner:
        return gatedTraitBonus(PlayerTrait.tirelessRunner, attr);
      case PlayerTrait.explosiveStart:
        return gatedTraitBonus(PlayerTrait.explosiveStart, attr);
      case PlayerTrait.fearlessDefender:
        return gatedTraitBonus(PlayerTrait.fearlessDefender, attr);
      // サッカー漫画のような劇的な特性(複合条件はより希少なので、その分
      // 倍率も他の単一条件の特性より大きくする)
      case PlayerTrait.divineReflexes:
        return gatedTraitBonus(PlayerTrait.divineReflexes, attr);
      case PlayerTrait.awayDayHero:
        return !isHome && -diff >= 8 ? 1.12 : 1.0;
      case PlayerTrait.risingPhoenix:
        return p.morale <= 35 && attr(AttributeKeys.determination) >= 75
            ? 1.14
            : 1.0;
      case PlayerTrait.veteranAce:
        return p.age >= 30 && oppAvg >= 70 ? 1.11 : 1.0;
    }
  }

  /// 試合開始時(前半開始時)に、両チームの全選手の「今試合分の算出済み」
  /// フラグをリセットしたうえで、先発選手の特性由来のパフォーマンス倍率を
  /// 算出して[Player.matchFormMultiplier]に格納する。
  static void _rollMatchForm(Team home, Team away, Weather weather) {
    for (final p in home.players) {
      p.matchFormRolledThisMatch = false;
    }
    for (final p in away.players) {
      p.matchFormRolledThisMatch = false;
    }
    _rollMatchFormForCurrentLineup(home, away, weather);
  }

  /// その時点のスタメン([lineupOf])のうち、まだ今試合分の倍率を
  /// 算出していない選手だけに算出する。前半に出場しなかった選手が
  /// 後半途中出場で初めて[lineupOf]に現れた場合(交代・負傷者の穴埋め等)
  /// にも、この試合用の値を正しく算出できるようにするための下位関数。
  /// 既に算出済みの選手は前後半を通して同じ値を使い続ける(再算出しない)。
  static void _rollMatchFormForCurrentLineup(
    Team home,
    Team away,
    Weather weather,
  ) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    final homeAvg = _avgOverall(homeLineup);
    final awayAvg = _avgOverall(awayLineup);
    for (final p in homeLineup) {
      if (p.matchFormRolledThisMatch) continue;
      p.matchFormMultiplier = _traitFormMultiplier(
        p,
        selfAvg: homeAvg,
        oppAvg: awayAvg,
        isHome: true,
        weather: weather,
      );
      p.matchFormRolledThisMatch = true;
    }
    for (final p in awayLineup) {
      if (p.matchFormRolledThisMatch) continue;
      p.matchFormMultiplier = _traitFormMultiplier(
        p,
        selfAvg: awayAvg,
        oppAvg: homeAvg,
        isHome: false,
        weather: weather,
      );
      p.matchFormRolledThisMatch = true;
    }
  }

  /// 先発11人を解決する。未設定・不整合な場合は負傷者を除いた総合力上位11人で代用する。
  static List<Player> lineupOf(Team t) {
    if (t.startingXI.isNotEmpty) {
      final byId = {for (final p in t.players) p.id: p};
      final lineup = t.startingXI
          .map((id) => byId[id])
          .whereType<Player>()
          .where(
            (p) =>
                !p.isInjured &&
                !p.isOnInternationalDuty &&
                !p.isLoanedOut &&
                !p.isSuspended &&
                !p.notRegistered,
          )
          .toList();
      if (lineup.length >= 7) return lineup;
    }
    final available = t.players
        .where(
          (p) =>
              !p.isInjured &&
              !p.isOnInternationalDuty &&
              !p.isLoanedOut &&
              !p.isSuspended &&
              !p.notRegistered,
        )
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    if (available.isNotEmpty) return available.take(11).toList();
    // 負傷・出場停止・ローン放出が重なって出場可能な選手が1人もいない場合、
    // 空のスタメンを返すと試合エンジンが得点者を選べず落ちる(実測で
    // 「全員負傷」「全員出場停止」「全員ローン放出中」のいずれでも
    // Null check operator の例外になることを確認)。現実のクラブが
    // 満身創痍でもピッチに11人を並べるのと同じように、状態を問わず
    // 総合力上位から緊急編成する。
    final emergency = [...t.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return emergency.take(11).toList();
  }

  /// スカウティングレポート・マンマーク指令の対象となる「キープレイヤー」
  /// (出場想定メンバーの中で最も総合力が高い選手)を1人特定する。
  static Player? identifyKeyPlayer(List<Player> lineup) {
    Player? keyPlayer;
    for (final p in lineup) {
      if (keyPlayer == null || p.overall > keyPlayer.overall) keyPlayer = p;
    }
    return keyPlayer;
  }

  /// デューティ(攻撃的/バランス/守備的)による攻撃貢献度の補正。
  static double dutyAttackMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.attack => 1.20,
        PlayerDuty.support => 1.0,
        PlayerDuty.defend => 0.80,
      };

  /// デューティによる守備貢献度の補正(攻撃的デューティは守備が手薄になる)。
  static double dutyDefenseMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.defend => 1.20,
        PlayerDuty.support => 1.0,
        PlayerDuty.attack => 0.80,
      };

  /// ロールに応じた貢献度補正。ロールが重視する能力値の平均が選手の
  /// 総合力より高ければボーナス、低ければペナルティになる
  /// (=適性の合わないロールを割り当てると損をする)。基準を総合力に
  /// 揃えているのは、ロール自動割当(PlayerGenerator._pickRole)が
  /// 「重視する能力値の平均が総合力を明確に上回るか」で判定しているため。
  /// 攻撃/守備どちらの位相で評価する場合も基準は同じ総合力であり、
  /// forAttackはあくまで「今どちらの位相の貢献として使うか」を表す。
  /// 個別指示による攻撃力の補正。
  ///
  /// 「持ち上がれ」「守備に残れ」は攻守の引き換え。「シュートを狙え」
  /// 「内側へ切れ込め」は、その選手に向いていれば得、向いていなければ損。
  /// 全員に付ければ強くなる作りにはしていない。
  static double instructionAttackMultiplier(Player p) =>
      p.instruction?.attackFactor(p.attributeValue) ?? 1.0;

  /// 個別指示による守備力の補正。
  static double instructionDefenseMultiplier(Player p) =>
      p.instruction?.defenseFactor ?? 1.0;

  /// 対策指示による攻撃力の補正。
  ///
  /// 「弱いサイドを突く」だけは相手を見て決まる。相手の左右の守備を比べ、
  /// 弱い側がどれだけ弱いかがそのまま効き目になる。手薄なサイドが無ければ
  /// ほとんど得をしない(空振りする)。
  static double planAttackFactor(
    Team team,
    List<Player> opponentLineup,
  ) {
    final plan = team.oppositionPlan;
    if (plan != OppositionPlan.targetWeakFlank) return plan.ownAttackFactor;

    double sideStrength(bool right) {
      final side = opponentLineup.where((p) {
        if (p.position.group != PositionGroup.def) return false;
        return right
            ? (p.position == Position.dr || p.position == Position.wbr)
            : (p.position == Position.dl || p.position == Position.wbl);
      }).toList();
      if (side.isEmpty) return 40; // サイドに人がいない=最も手薄
      return side.fold<int>(0, (s, p) => s + p.defense) / side.length;
    }

    final weaker = sideStrength(true) < sideStrength(false)
        ? sideStrength(true)
        : sideStrength(false);
    // 守備力50を基準に、弱いほど効き目が大きい。上下は 0.97〜1.08。
    return (1 + (50 - weaker) / 250).clamp(0.97, 1.08);
  }

  static double roleMultiplier(Player p, {required bool forAttack}) {
    final keyAttributes = p.role.keyAttributes;
    if (keyAttributes.isEmpty) return 1.0;
    final roleRating =
        keyAttributes.fold<int>(0, (s, k) => s + p.attributeValue(k)) /
            keyAttributes.length;
    return (1 + (roleRating - p.overall) / 130).clamp(0.8, 1.3);
  }

  /// 本職以外のポジションで起用された際の貢献度ペナルティ。副ポジションと
  /// して登録済みなら軽微(慣れが増すほど解消)、それ以外(同グループの
  /// 代役)はより大きなペナルティになる。
  static double positionFitMultiplier(Player p, Position assignedSlot) {
    if (assignedSlot == p.position) return 1.0;
    final familiarity = p.familiarityFor(assignedSlot) / 100;
    if (p.secondaryPositions.contains(assignedSlot)) {
      return 0.90 + 0.10 * familiarity;
    }
    return 0.75 + 0.15 * familiarity;
  }

  /// スカッド崩壊などで該当グループの選手が1人もいない場合の攻守力。
  /// フォーメーション上想定されない稀なケースの安全策であり、通常の
  /// チーム(40〜90程度)と互角に渡り合えてしまわないよう、明確に低い
  /// 値にする(先発全体も空なら、なお一段と低い値にする)。
  static double _emptyGroupPower(List<Player> lineup) =>
      lineup.isEmpty ? 8 : 15;

  static double _attackPower(
    Team t,
    List<Player> lineup, {
    String? suppressedId,
    TacticalStyle? opponentStyle,
  }) {
    final relevant = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.att ||
              p.position.group == PositionGroup.mid,
        )
        .toList();
    if (relevant.isEmpty) return _emptyGroupPower(lineup);
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.attack *
              _condition(p) *
              dutyAttackMultiplier(p.duty) *
              roleMultiplier(p, forAttack: true) *
              instructionAttackMultiplier(p) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position) *
              (p.id == suppressedId ? 0.8 : 1.0),
    );
    final avgStamina = _avgAttribute(lineup, AttributeKeys.stamina);
    final result = (total / relevant.length) *
        t.formation.attackBias *
        t.familiarityFactor *
        t.mentality.attackFactor *
        StyleEngine.powerFactor(t, lineup: lineup) *
        (opponentStyle == null
            ? 1.0
            : StyleEngine.matchupAttackFactor(t.tacticalStyle, opponentStyle)) *
        lineHeightAttackFactor(t.lineHeight) *
        widthAttackFactor(t.width) *
        tempoAttackFactor(t.tempo, avgStamina);
    return t.timeWastingMode ? result * 0.92 : result;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.def ||
              p.position.group == PositionGroup.gk,
        )
        .toList();
    if (relevant.isEmpty) return _emptyGroupPower(lineup);
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.defense *
              _condition(p) *
              dutyDefenseMultiplier(p.duty) *
              roleMultiplier(p, forAttack: false) *
              instructionDefenseMultiplier(p) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position),
    );
    final avgWorkRate = _avgAttribute(lineup, AttributeKeys.workRate);
    final result = (total / relevant.length) *
        t.formation.defenseBias *
        t.familiarityFactor *
        t.mentality.defenseFactor *
        StyleEngine.powerFactor(t, lineup: lineup) *
        pressingDefenseFactor(t.pressing, avgWorkRate) *
        lineHeightDefenseRiskFactor(t.lineHeight) *
        widthDefenseRiskFactor(t.width);
    return t.timeWastingMode ? result * 1.08 : result;
  }

  /// [markingTeam]がマンマーク役を出場させている場合、[targetLineup]の
  /// キープレイヤーのIDを返す(攻撃力算出時にそのプレイヤーの貢献を抑える)。
  static String? markedTargetId(
    Team markingTeam,
    List<Player> markingLineup,
    List<Player> targetLineup,
  ) {
    final markerId = markingTeam.manMarkerId;
    if (markerId == null) return null;
    final markerActive = markingLineup.any((p) => p.id == markerId);
    if (!markerActive) return null;
    return identifyKeyPlayer(targetLineup)?.id;
  }

  static Player? _pickScorer(List<Player> lineup) {
    final candidates = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.att ||
              p.position.group == PositionGroup.mid,
        )
        .toList();
    if (candidates.isEmpty) return lineup.isNotEmpty ? lineup.first : null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  /// 得点者以外のラインナップから、パス能力で重み付けしてアシスト選手を
  /// 選出する。ゴールの一定割合は個人技によるものとして、そもそも
  /// アシストなし(null)になる。
  static Player? _pickAssist(List<Player> lineup, Player? scorer) {
    if (_rng.nextDouble() < 0.22) return null;
    final candidates =
        lineup.where((p) => scorer == null || p.id != scorer.id).toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(
      0,
      (s, p) => s + p.attributeValue(AttributeKeys.passing),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = p.attributeValue(AttributeKeys.passing);
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  static bool _isRightWide(Position p) =>
      p == Position.dr ||
      p == Position.wbr ||
      p == Position.mr ||
      p == Position.amr;
  static bool _isLeftWide(Position p) =>
      p == Position.dl ||
      p == Position.wbl ||
      p == Position.ml ||
      p == Position.aml;

  /// 攻撃側のサイドで仕掛ける選手を1人選ぶ(右サイド/左サイドはランダムに
  /// 決める)。ワイドなポジションの選手がいなければnull(中央からの
  /// 崩ししか起こらないフォーメーションを想定)。
  static Player? _pickWideAttacker(List<Player> lineup, bool right) {
    final candidates = lineup
        .where(
          (p) => right ? _isRightWide(p.position) : _isLeftWide(p.position),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  /// 攻撃側の仕掛けと同サイドを守る守備者を探す(最も守備寄りの選手を
  /// マーカーとみなす)。同サイドに守備者がいなければnull(=数的優位)。
  static Player? _findSameSideDefender(List<Player> lineup, bool right) {
    final candidates = lineup
        .where(
          (p) => right ? _isRightWide(p.position) : _isLeftWide(p.position),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.defense.compareTo(a.defense));
    return candidates.first;
  }

  /// サイドでの1対1(スピード・ドリブル・敏捷性・ひらめき vs スピード・
  /// 対応・ポジショニング)の突破成功率。対面の守備者がいなければ数的優位
  /// として高確率で突破できる。
  static double _wideDuelWinProb(Player attacker, Player? defender) {
    final attackSkill = attacker.attributeValue(AttributeKeys.pace) * 0.35 +
        attacker.attributeValue(AttributeKeys.dribbling) * 0.35 +
        attacker.attributeValue(AttributeKeys.agility) * 0.15 +
        attacker.attributeValue(AttributeKeys.flair) * 0.15;
    if (defender == null) return 0.85;
    final defendSkill = defender.attributeValue(AttributeKeys.pace) * 0.35 +
        defender.attributeValue(AttributeKeys.tackling) * 0.4 +
        defender.attributeValue(AttributeKeys.positioning) * 0.25;
    return (0.5 + (attackSkill - defendSkill) / 150).clamp(0.15, 0.9);
  }

  /// クロスに合わせる標的を、ヘディング・ジャンプ力で重み付けして選ぶ。
  /// コーナーキックを解決する。ライブ観戦と一括シミュレーションの両方から
  /// 呼ばれる。以前は同じ処理が2箇所に写してあり、片方だけ直す事故が
  /// 起きうる形だった。
  ///
  /// 狙い(CornerRoutine)によって、合わせる選手に求められる能力が変わる。
  /// 手持ちの選手に合う狙いを選べているかが結果に出る。
  static ({Player? scorer, Player? taker, double scoreProb}) resolveCorner({
    required Team attackingTeam,
    required List<Player> attackingLineup,
    required Team defendingTeam,
    required List<Player> defendingLineup,
    required double baseProb,
  }) {
    final routine = attackingTeam.cornerRoutine;
    final taker = _pickSetPieceTaker(
      attackingTeam.cornerTakerId,
      attackingLineup,
    );
    final scorer = _pickCornerTarget(
      attackingLineup,
      routine,
      excludeId: taker?.id,
    );

    var scoreProb = baseProb;
    if (taker != null) {
      final cornersAttr = taker.attributeValue(AttributeKeys.corners);
      // ロングスローもコーナーと同様に、ワイドからの精度あるボールの供給と
      // いう点で質に少し寄与させる(コーナーの専門性を主としつつ)。
      final longThrowsAttr = taker.attributeValue(AttributeKeys.longThrows);
      final deliveryQuality =
          (cornersAttr * 0.8 + longThrowsAttr * 0.2).round();
      scoreProb =
          (scoreProb * (1 + (deliveryQuality - 50) / 200)).clamp(0.05, 0.75);
    }

    // 狙いに合った選手が入っているかを、そのまま決定率に反映する。
    // 長身がいないのにファーで競っても、こぼれ球を狙う形で長距離砲が
    // いないのと同じで、形だけになる。
    final fit = scorer?.attributeValue(routine.targetAttribute) ?? 50;
    scoreProb = (scoreProb * (1 + (fit - 50) / 200)).clamp(0.05, 0.75);

    scoreProb = applySetPieceDefense(scoreProb, defendingTeam, defendingLineup);
    if (routine.isAerial) {
      scoreProb = _applyHeaderQuality(scoreProb, scorer);
    }
    return (scorer: scorer, taker: taker, scoreProb: scoreProb);
  }

  /// 狙いに応じて、合わせる選手を選ぶ。
  ///
  /// ファー・ニアは前線の選手から、エリア手前とショートは中盤も含めて
  /// 選ぶ。ミドルを狙う形で前線しか見ないのは実態に合わない。
  static Player? _pickCornerTarget(
    List<Player> lineup,
    CornerRoutine routine, {
    String? excludeId,
  }) {
    if (routine == CornerRoutine.farPost) {
      // 従来どおり、空中戦に強い前線の選手。
      return _pickAerialTarget(lineup, excludeId: excludeId);
    }
    final pool = lineup
        .where(
          (p) =>
              p.id != excludeId &&
              p.position != Position.gk &&
              (routine == CornerRoutine.nearPost
                  ? p.position.group == PositionGroup.att
                  : p.position.group == PositionGroup.att ||
                      p.position.group == PositionGroup.mid),
        )
        .toList();
    if (pool.isEmpty) {
      return _pickAerialTarget(lineup, excludeId: excludeId);
    }
    pool.sort((a, b) => b
        .attributeValue(routine.targetAttribute)
        .compareTo(a.attributeValue(routine.targetAttribute)));
    return pool.first;
  }

  static Player? _pickAerialTarget(List<Player> lineup, {String? excludeId}) {
    final candidates = lineup
        .where(
          (p) => p.position.group == PositionGroup.att && p.id != excludeId,
        )
        .toList();
    if (candidates.isEmpty) {
      return lineup.where((p) => p.id != excludeId).isEmpty
          ? null
          : lineup.firstWhere((p) => p.id != excludeId);
    }
    final total = candidates.fold<int>(
      0,
      (s, p) =>
          s +
          p.attributeValue(AttributeKeys.heading) +
          p.attributeValue(AttributeKeys.jumpingReach),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = p.attributeValue(AttributeKeys.heading) +
          p.attributeValue(AttributeKeys.jumpingReach);
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  /// 相手最終ラインの中で最も空中戦に強い選手をマーカーとみなし、標的との
  /// 空中戦の優劣をスコア確率への倍率(0.7〜1.3)として返す。
  static double _aerialDuelFactor(Player target, List<Player> defendingLineup) {
    final defenders = defendingLineup
        .where((p) => p.position.group == PositionGroup.def)
        .toList();
    if (defenders.isEmpty) return 1.0;
    Player marker = defenders.first;
    for (final d in defenders) {
      final dSkill = d.attributeValue(AttributeKeys.heading) +
          d.attributeValue(AttributeKeys.jumpingReach);
      final mSkill = marker.attributeValue(AttributeKeys.heading) +
          marker.attributeValue(AttributeKeys.jumpingReach);
      if (dSkill > mSkill) marker = d;
    }
    final targetSkill = target.attributeValue(AttributeKeys.heading) +
        target.attributeValue(AttributeKeys.jumpingReach);
    final markerSkill = marker.attributeValue(AttributeKeys.heading) +
        marker.attributeValue(AttributeKeys.jumpingReach);
    return (1 + (targetSkill - markerSkill) / 300).clamp(0.7, 1.3);
  }

  /// クロスに合わせるヘディングシュートの質(フィニッシュ属性ではなく
  /// ヘディング・ジャンプ力・冷静さを基準にする)。
  static double _applyHeaderQuality(double scoreProb, Player? scorer) {
    if (scorer == null) return scoreProb;
    final quality = scorer.attributeValue(AttributeKeys.heading) * 0.5 +
        scorer.attributeValue(AttributeKeys.jumpingReach) * 0.3 +
        scorer.attributeValue(AttributeKeys.composure) * 0.2;
    return (scoreProb * (1 + (quality - 50) / 150)).clamp(0.05, 0.85);
  }

  /// セットプレー担当に指名された選手を出場中のメンバーから探す。
  /// 指名なし、または指名選手が出場していない(負傷・出場停止など)場合はnull。
  static Player? _pickSetPieceTaker(String? takerId, List<Player> lineup) {
    if (takerId == null) return null;
    for (final p in lineup) {
      if (p.id == takerId) return p;
    }
    return null;
  }

  static void _applyFatigue(
    Team t,
    List<Player> lineup, {
    double weatherFactor = 1.0,
    double intensity = 1.0,
  }) {
    final timeWastingFactor = t.timeWastingMode ? 0.85 : 1.0;
    for (final p in lineup) {
      final gain = (12 + _rng.nextInt(8)) *
          pressingFatigueFactor(t.pressing) *
          tempoFatigueFactor(t.tempo) *
          weatherFactor *
          timeWastingFactor *
          intensity;
      p.fatigue = (p.fatigue + gain.round()).clamp(0, 100);
    }
  }

  /// ライン高さがチームの攻撃力に与える倍率(高いラインほど攻撃的)。
  static double lineHeightAttackFactor(int lineHeight) =>
      1 + (lineHeight - 50) / 400;

  /// 攻撃の幅がチームの攻撃力に与える倍率。
  static double widthAttackFactor(int width) => 1 + (width - 50) / 500;

  /// 選手のある能力値の、出場メンバー内での平均値。
  static double _avgAttribute(List<Player> lineup, String key) {
    if (lineup.isEmpty) return 50;
    final total = lineup.fold<double>(0, (s, p) => s + p.attributeValue(key));
    return total / lineup.length;
  }

  /// 戦術とスカッドの適性係数(0.7〜1.3)。狙った戦術に必要な能力値が
  /// 高い選手が多いほど、その戦術のボーナス(またはリスク)がより強く出る。
  /// 低いと「やろうとしていることに選手がついていけない」形で減衰する。
  static double tacticalFitFactor(double avgAttribute) =>
      (0.7 + avgAttribute / 165).clamp(0.7, 1.3);

  /// テンポがチームの攻撃力に与える倍率。スタミナの高い選手が多いほど
  /// 高テンポのメリットを最大限に活かせる。
  static double tempoAttackFactor(int tempo, [double avgStamina = 50]) =>
      1 + (tempo - 50) / 500 * tacticalFitFactor(avgStamina);

  /// プレッシングがチームの守備力(ボール奪取)に与える倍率。労働量
  /// (workRate)の高い選手が多いほど、狙い通りにボールを奪いにいける。
  static double pressingDefenseFactor(
    int pressing, [
    double avgWorkRate = 50,
  ]) =>
      1 + (pressing - 50) / 400 * tacticalFitFactor(avgWorkRate);

  /// ライン高さがチームの守備力に与えるリスク倍率(高いラインほど守備が手薄になる)。
  static double lineHeightDefenseRiskFactor(int lineHeight) =>
      1 + (50 - lineHeight) / 500;

  /// 攻撃の幅がチームの守備力に与えるリスク倍率(幅が広いほど守備が手薄になる)。
  static double widthDefenseRiskFactor(int width) => 1 - (width - 50) / 800;

  /// プレッシングが1試合あたりの疲労蓄積に与える倍率。
  static double pressingFatigueFactor(int pressing) =>
      1 + (pressing - 50) / 200;

  /// テンポが1試合あたりの疲労蓄積に与える倍率。
  static double tempoFatigueFactor(int tempo) => 1 + (tempo - 50) / 300;

  /// 現在の戦術スライダー設定が攻撃力・守備力・疲労蓄積にどれだけ影響しているかを
  /// 倍率として要約する(戦術画面での定量的なフィードバック用)。
  static ({
    double attackMultiplier,
    double defenseMultiplier,
    double fatigueMultiplier,
  }) tacticalImpact(Team t) {
    final lineup = lineupOf(t);
    final avgStamina = _avgAttribute(lineup, AttributeKeys.stamina);
    final avgWorkRate = _avgAttribute(lineup, AttributeKeys.workRate);
    return (
      attackMultiplier: lineHeightAttackFactor(t.lineHeight) *
          widthAttackFactor(t.width) *
          tempoAttackFactor(t.tempo, avgStamina),
      defenseMultiplier: pressingDefenseFactor(t.pressing, avgWorkRate) *
          lineHeightDefenseRiskFactor(t.lineHeight) *
          widthDefenseRiskFactor(t.width),
      fatigueMultiplier:
          pressingFatigueFactor(t.pressing) * tempoFatigueFactor(t.tempo),
    );
  }

  /// 前半終了時点(ハーフタイム)で、そこまでの運動量に応じた疲労を先に
  /// 反映する。従来は試合終了後にまとめて疲労を加算していたため、後半の
  /// シミュレーションが前半の運動量を全く考慮しないという問題があった。
  /// ここで前半分(intensity 0.5)を反映し、残り半分は
  /// [applyPostMatchEffects]で後半終了時にまとめて反映する。
  static void applyHalfTimeFatigue({
    required Team home,
    required Team away,
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    _applyFatigue(
      home,
      homeLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _applyFatigue(
      away,
      awayLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
  }

  /// ハーフタイムの自動の交代で「疲れた」とみなす疲労。試合前の疲労の
  /// 警告(70)より少し手前で替える。
  static const int autoSubTiredFatigue = 60;

  /// 後半の途中(60〜75分)の自動の交代で「疲れた」とみなす疲労。疲労は
  /// ハーフタイムと試合のあとにしか足さないので、ハーフタイムからの
  /// 15〜30分ぶんを見込んで低めにする。
  static const int lateAutoSubTiredFatigue = 50;

  /// 後半の途中の自動の交代を行う分の幅(この間のどこか1回)。
  static const int lateSubWindowEarliest = 60;
  static const int lateSubWindowLatest = 75;

  /// 後半の途中の交代の分を決める(60〜75分)。
  static int rollLateSubMinute() =>
      lateSubWindowEarliest +
      _rng.nextInt(lateSubWindowLatest - lateSubWindowEarliest + 1);

  /// 負けているときに替える選手は、控えがこの割合以上の力なら替える
  /// (少し力が落ちても、流れを変えにいく)。
  static const double autoSubChasingRatio = 0.95;

  /// 疲れを差し引いた、その時点での力。
  static double _freshStrength(Player p) => p.overall * (1 - p.fatigue / 250);

  static bool _canPlay(Player p) =>
      !p.isInjured &&
      !p.isOnInternationalDuty &&
      !p.isLoanedOut &&
      !p.isSuspended &&
      !p.notRegistered;

  /// ハーフタイムの自動の交代を選ぶ(選ぶだけで、先発には触れない)。
  ///
  /// ライブ観戦では利用者が自分で交代するが、結果だけ見る試合と CPU 同士の
  /// 試合には交代が一切無かった。そこで監督が替えるときの考え方を、
  /// 乱数を使わない決まりにした:
  /// 1. 疲労が[autoSubTiredFatigue]以上の選手(GK は替えない)を、疲れている
  ///    順に、疲れを差し引いた力で上回る控えと替える。
  /// 2. 負けていれば([goalDiff] < 0)、中盤・前線で今いちばん力の落ちている
  ///    選手を1人、[autoSubChasingRatio]以上の控えと替える。
  /// 控えは 主ポジション → 副ポジション → 同じ大分類 の順に探す(自動編成と同じ)。
  /// [excludedIds]は替えてはいけない選手(退場した選手)と、もう入れては
  /// いけない選手(この試合で一度下がった選手)。枠は[maxSubs]まで。
  /// [tiredFatigue]は「疲れた」とみなす疲労(後半の途中の交代では、ハーフ
  /// タイムより走っているぶん低めにする)。
  /// 試合の中の怪我は無い(怪我は試合のあとに決まる)ので、怪我人の交代は無い。
  static List<AutoSubstitution> chooseHalfTimeSubstitutions(
    Team team,
    List<Player> lineup, {
    required int goalDiff,
    int maxSubs = substitutionsPerMatch,
    Set<String> excludedIds = const {},
    int tiredFatigue = autoSubTiredFatigue,
  }) {
    final swaps = <AutoSubstitution>[];
    if (maxSubs <= 0) return swaps;
    final onPitch = {for (final p in lineup) p.id};
    final bench = team.players
        .where((p) =>
            !onPitch.contains(p.id) &&
            !excludedIds.contains(p.id) &&
            _canPlay(p))
        .toList();
    final usedBench = <String>{};

    Player? replacementFor(Player out, double minStrength) {
      final tiers = <bool Function(Player)>[
        (p) => p.position == out.position,
        (p) => p.secondaryPositions.contains(out.position),
        (p) => p.position.group == out.position.group,
      ];
      for (final fits in tiers) {
        Player? best;
        for (final p in bench) {
          if (usedBench.contains(p.id) || !fits(p)) continue;
          if (_freshStrength(p) < minStrength) continue;
          if (best == null || _freshStrength(p) > _freshStrength(best)) {
            best = p;
          }
        }
        if (best != null) return best;
      }
      return null;
    }

    void swap(Player out, Player incoming) {
      usedBench.add(incoming.id);
      swaps.add(AutoSubstitution(
        out: out,
        incoming: incoming,
        outSharpnessBefore: out.matchSharpness,
      ));
    }

    final tired = lineup
        .where(
          (p) =>
              p.position != Position.gk &&
              !excludedIds.contains(p.id) &&
              p.fatigue >= tiredFatigue,
        )
        .toList()
      ..sort((a, b) => b.fatigue.compareTo(a.fatigue));
    for (final out in tired) {
      if (swaps.length >= maxSubs) break;
      final incoming = replacementFor(out, _freshStrength(out));
      if (incoming != null) swap(out, incoming);
    }

    if (goalDiff < 0 && swaps.length < maxSubs) {
      final replaced = {for (final s in swaps) s.out.id};
      final attackers = lineup
          .where(
            (p) =>
                (p.position.group == PositionGroup.mid ||
                    p.position.group == PositionGroup.att) &&
                !excludedIds.contains(p.id) &&
                !replaced.contains(p.id),
          )
          .toList()
        ..sort((a, b) => _freshStrength(a).compareTo(_freshStrength(b)));
      for (final out in attackers) {
        final incoming =
            replacementFor(out, _freshStrength(out) * autoSubChasingRatio);
        if (incoming == null) continue;
        swap(out, incoming);
        break;
      }
    }
    return swaps;
  }

  /// ハーフタイムの自動の交代を選び、後半の先発([Team.startingXI])に
  /// 入れる。試合が終わったら[finishHalfTimeSubstitutions]で戻すこと。
  static AutoSubstitutionPlan applyHalfTimeSubstitutions(
    Team team, {
    required int goalDiff,
    int maxSubs = substitutionsPerMatch,
    Set<String> excludedIds = const {},
    int tiredFatigue = autoSubTiredFatigue,
  }) {
    final original = List<String>.of(team.startingXI);
    final lineup = lineupOf(team);
    final swaps = chooseHalfTimeSubstitutions(
      team,
      lineup,
      goalDiff: goalDiff,
      maxSubs: maxSubs,
      excludedIds: excludedIds,
      tiredFatigue: tiredFatigue,
    );
    if (swaps.isNotEmpty) {
      final byOut = {for (final s in swaps) s.out.id: s.incoming.id};
      team.startingXI = [for (final p in lineup) byOut[p.id] ?? p.id];
    }
    return AutoSubstitutionPlan(
      team: team,
      originalXI: original,
      swaps: swaps,
    );
  }

  /// 試合のあと([applyPostMatchEffects]のあと)に呼ぶ。下がった選手も前半は
  /// 出ているので出場1・得点([events]から)・試合勘・試合の経験を数え、
  /// 先発の指定を試合の前に戻す。
  static void finishHalfTimeSubstitutions(
    AutoSubstitutionPlan plan, {
    List<MatchEvent> events = const [],
  }) {
    for (final s in plan.swaps) {
      s.out.careerAppearances += 1;
      for (final e in events) {
        if (e.type == MatchEventType.goal && e.scorerId == s.out.id) {
          s.out.careerGoals += 1;
        }
      }
      s.out.matchSharpness = (s.outSharpnessBefore + 6).clamp(0, 100);
      TrainingEngine.growFromMatchExperience(s.out);
    }
    if (plan.swaps.isNotEmpty) plan.team.startingXI = plan.originalXI;
  }

  /// 続けて行った2つの区間([a]のあとに[b])の結果を1つにまとめる。
  static HalfResult combineHalves(HalfResult a, HalfResult b) => HalfResult(
        homeGoals: a.homeGoals + b.homeGoals,
        awayGoals: a.awayGoals + b.awayGoals,
        events: [...a.events, ...b.events],
        homeShots: a.homeShots + b.homeShots,
        awayShots: a.awayShots + b.awayShots,
        homeShotsOnTarget: a.homeShotsOnTarget + b.homeShotsOnTarget,
        awayShotsOnTarget: a.awayShotsOnTarget + b.awayShotsOnTarget,
        possessionShareSum: a.possessionShareSum + b.possessionShareSum,
        chanceCount: a.chanceCount + b.chanceCount,
      );

  /// この試合で退場した選手(交代で下げてはいけない)。
  static Set<String> sentOffIds(Iterable<MatchEvent> events) => {
        for (final e in events)
          if (e.type == MatchEventType.redCard && e.scorerId != null)
            e.scorerId!,
      };

  /// 本職外のスロットで出場した選手のポジション慣れ度を積み増す。
  static void _growPositionFamiliarity(Team t, List<Player> lineup) {
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    for (final p in lineup) {
      final slot = slotById[p.id];
      if (slot == null) continue;
      p.growFamiliarity(slot);
    }
  }

  /// 出場した選手はマッチシャープネスが上昇し、出場しなかった選手は
  /// 緩やかに低下する(下限あり)。
  static void _updateMatchSharpness(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (lineupIds.contains(p.id)) {
        p.matchSharpness = (p.matchSharpness + 6).clamp(0, 100);
      } else {
        p.matchSharpness = (p.matchSharpness - 3).clamp(30, 100);
      }
    }
  }

  /// 「怪我のしやすさ」による負傷確率の倍率(0.6〜1.4)。
  ///
  /// 同じ疲労・同じ基礎体力でも、壊れやすい選手と壊れにくい選手がいる。
  /// 練習中の負傷にも同じ係数を掛ける(TrainingEngine)。
  static double injuryPronenessFactor(Player p) =>
      (0.6 + p.injuryProneness / 20 * 0.8).clamp(0.6, 1.4);

  static void _rollInjuries(List<Player> lineup, double injuryFactor) {
    for (final p in lineup) {
      // 基礎体力(naturalFitness)が高い選手ほど負傷しにくい。
      final naturalFitnessFactor =
          (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200)
              .clamp(0.5, 1.5);
      final chance = (0.03 + (p.fatigue / 100) * 0.05) *
          injuryFactor *
          naturalFitnessFactor *
          injuryPronenessFactor(p);
      if (_rng.nextDouble() < chance) {
        final type = _rollInjuryType(p);
        final range = type.durationRange;
        final weeks =
            (range.$1 + _rng.nextInt(range.$2 - range.$1 + 1)) * injuryFactor;
        p.injuryWeeks = weeks.round().clamp(1, range.$2);
        p.injuryType = type;
        p.injuryHistoryCounts[type.name] =
            (p.injuryHistoryCounts[type.name] ?? 0) + 1;
      }
    }
  }

  /// 負傷の種類を重み付き抽選で決める。同じ種類を過去に負ったことが
  /// あると再発しやすい(重みが増す)。
  static InjuryType _rollInjuryType(Player p) {
    final weights = <InjuryType, double>{
      InjuryType.bruise: 3.0,
      InjuryType.muscle: 2.0,
      InjuryType.ligament: 1.0,
      // 長期の怪我はまれ。試合での怪我の約3%で、1季に1クラブ0〜2人ほど
      // (reality2_match_test で固定している)。
      InjuryType.fracture: 0.10,
      InjuryType.acl: 0.07,
      InjuryType.achilles: 0.03,
    };
    for (final type in InjuryType.values) {
      final history = p.injuryHistoryCounts[type.name] ?? 0;
      if (history > 0) weights[type] = weights[type]! * (1 + 0.3 * history);
    }
    final total = weights.values.fold<double>(0, (s, w) => s + w);
    var r = _rng.nextDouble() * total;
    for (final entry in weights.entries) {
      if (r < entry.value) return entry.key;
      r -= entry.value;
    }
    return InjuryType.bruise;
  }

  /// 規律ボーナスの対象となるリーダーを探す。キャプテンが出場していれば
  /// それを、出場していなければ(負傷・出場停止・ベンチ等で)副キャプテンを
  /// 代わりに用いる。どちらも出場していなければnull。
  static Player? _findCaptainOrVice(Team team, List<Player> lineup) {
    if (team.captainId != null) {
      for (final p in lineup) {
        if (p.id == team.captainId) return p;
      }
    }
    if (team.viceCaptainId != null) {
      for (final p in lineup) {
        if (p.id == team.viceCaptainId) return p;
      }
    }
    return null;
  }

  /// カード事象1回あたりに一発退場(直接レッド)となる確率。
  /// 実際のサッカーでは退場は20〜25試合に1枚(0.04〜0.08枚/試合)しか
  /// 出ないが、かつてはこの値が0.08と高く、実測で0.29枚/試合(実際の
  /// 4〜6倍)の退場が発生していた。2枚目の警告による退場も別途あるため、
  /// 直接レッドはごく稀な事象として扱う。
  static const double _directRedChance = 0.015;

  /// 「積極的にタックル」を選んだ場合の一発退場の確率。ユーザーが自分で
  /// リスクを取った結果なので通常より高いが、それでも稀な事象に留める。
  static const double _aggressiveTackleRedChance = 0.05;

  /// 決定機1回あたりに上乗せする「打っただけ」のシュート本数の目安。
  /// このエンジンが数えているのは得点に絡む決定機だけなので、そのままでは
  /// スタッツのシュート数が実際の試合(両チーム合計25本前後)の半分ほど
  /// (実測13本)にしかならない。枠を外した・ブロックされたシュートを
  /// ポゼッションに応じて振り分けて上乗せし、記録としての現実感を出す。
  /// 枠内シュートには加算しないため、枠内率も現実的な水準に近づく。
  static const double _speculativeShotsPerChance = 1.0;

  /// [chances]回の決定機と平均ポゼッション[homeShare]から、両チームの
  /// 「打っただけ」のシュート本数を見積もる。
  static ({int home, int away}) speculativeShotsForStats(
    int chances,
    double homeShare,
  ) {
    var home = 0;
    var away = 0;
    final total = (chances * _speculativeShotsPerChance).round();
    for (var i = 0; i < total; i++) {
      if (_rng.nextDouble() < homeShare) {
        home++;
      } else {
        away++;
      }
    }
    return (home: home, away: away);
  }

  /// 1分あたりにカードの場面(反則で審判が笛を吹き、カードを考える場面)が
  /// 起きる確率。キャプテンの規律で見送られる分と、警告を受けている選手が
  /// 自重する分を引いて、警告が両チーム合計で1試合4〜5枚(欧州5大リーグの
  /// 実際の数)になるように合わせた(実測 約4.8枚)。以前は1試合に1〜4回
  /// (平均2.5回)で、警告は約2.8枚/試合だった。
  static const double _cardIncidentPerMinute = 0.062;

  /// 既に警告を受けている選手が、もう一度カードの場面に絡んだときに
  /// 自重して(反則を避けて)カードを免れる確率。実際には2枚目の警告での
  /// 退場は1試合に0.1枚ほどしか無い。警告が4〜5枚に増えると、何もしない
  /// ままでは同じ選手に2枚目が出る数が実際の3倍ほどになる(0.7でも退場は
  /// 2枚目込みで約0.34枚/試合あった。0.85で約0.17枚)。
  static const double _bookedPlayerCaution = 0.85;

  /// 前の区間(前半など)で[teamId]の選手が退場していれば、この区間の
  /// 始めから数的不利にするための分([startMinute]の1分前)。
  static int? _priorRedMinute(
    List<MatchEvent> priorEvents,
    String teamId,
    int startMinute,
  ) {
    for (final e in priorEvents) {
      if (e.type == MatchEventType.redCard && e.teamId == teamId) {
        return startMinute - 1;
      }
    }
    return null;
  }

  static List<Player> _withoutIds(List<Player> lineup, Set<String> ids) =>
      ids.isEmpty
          ? lineup
          : [
              for (final p in lineup)
                if (!ids.contains(p.id)) p,
            ];

  /// [minute]の時点でまだピッチにいる選手([events]でそれより前に退場した
  /// 選手を除く)。退場した選手が同じ半のうちに得点・アシストしないように。
  static List<Player> _stillOnPitch(
    List<Player> lineup,
    List<MatchEvent> events,
    int minute,
  ) {
    Set<String>? gone;
    for (final e in events) {
      if (e.type == MatchEventType.redCard &&
          e.scorerId != null &&
          e.minute < minute) {
        (gone ??= <String>{}).add(e.scorerId!);
      }
    }
    if (gone == null) return lineup;
    final left = _withoutIds(lineup, gone);
    return left.isEmpty ? lineup : left;
  }

  /// この区間の警告・退場を決めて[events]へ入れ、両チームの退場の分を返す。
  /// [homeRedMinute]/[awayRedMinute]は前の区間から続く数的不利(あれば)。
  ///
  /// カードの場面は分の順に処理する(以前は抽選した順で、2枚目の警告が
  /// 1枚目より前の分に記録されることがあった)。退場した選手はその後の
  /// カードの対象にしない。
  static ({int? home, int? away}) _rollCards({
    required Team home,
    required Team away,
    required List<Player> homeLineup,
    required List<Player> awayLineup,
    required int startMinute,
    required int span,
    required Set<int> minutesUsed,
    required List<MatchEvent> events,
    int? homeRedMinute,
    int? awayRedMinute,
    Set<String> excludedIds = const {},
  }) {
    // (分, 時間稼ぎで目を付けられたチーム)。時間稼ぎでないものは null。
    final incidents = <(int, Team?)>[];
    for (var m = startMinute; m < startMinute + span; m++) {
      if (_rng.nextDouble() < _cardIncidentPerMinute) incidents.add((m, null));
    }
    // 時間稼ぎモードは疲労軽減の恩恵がある一方、遅延行為として審判の
    // 目を引きやすくなるリスクを負う(追加の警告チャンスを1回だけ判定)。
    for (final t in [home, away]) {
      if (!t.timeWastingMode) continue;
      if (_rng.nextDouble() >= 0.18 * span / 90) continue;
      incidents.add((startMinute + _rng.nextInt(span), t));
    }
    incidents.sort((a, b) => a.$1.compareTo(b.$1));

    final sentOff = <String>{...excludedIds};
    for (final (minute, wastingTeam) in incidents) {
      if (minutesUsed.contains(minute)) continue;
      final isHomeTeam =
          wastingTeam == null ? _rng.nextBool() : wastingTeam.id == home.id;
      final lineup = isHomeTeam ? homeLineup : awayLineup;
      final team = isHomeTeam ? home : away;
      if (wastingTeam == null) {
        // キャプテン(不在なら副キャプテン)が出場しているチームは規律が
        // 保たれ、カードをやや受けにくい。効果の大きさはそのリーダーの
        // leadership値で変わる。
        final leader = _findCaptainOrVice(team, lineup);
        if (leader != null &&
            !sentOff.contains(leader.id) &&
            _rng.nextDouble() <
                (0.15 +
                    leader.attributeValue(AttributeKeys.leadership) / 400)) {
          continue;
        }
      }
      final target = _pickCardTarget(lineup, exclude: sentOff);
      if (target == null) continue;
      // この試合で既に警告を受けている選手は自重することが多い。それでも
      // カードを受けたら、実際のルール通り2枚目の警告は退場。
      final isSecondYellow = target.yellowCardedThisMatch;
      if (isSecondYellow && _rng.nextDouble() < _bookedPlayerCaution) continue;
      final isRed = isSecondYellow ||
          (wastingTeam == null && _rng.nextDouble() < _directRedChance);
      minutesUsed.add(minute);
      if (!isRed) target.yellowCardedThisMatch = true;
      events.add(
        MatchEvent(
          minute: minute,
          teamId: team.id,
          scorerName: target.name,
          scorerId: target.id,
          type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
        ),
      );
      if (isRed) {
        sentOff.add(target.id);
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
      // 警告・退場の累積処理は試合終了後にapplyPostMatchEffectsでまとめて行う
      // (出場停止の消化判定より後に反映しないと、今節退場した選手の出場停止が
      // 同じ試合の後処理で即座に解除されてしまうため)。
    }
    return (home: homeRedMinute, away: awayRedMinute);
  }

  /// セットプレーのうち PK になる割合。決定機は1試合に約14回で、その25%が
  /// セットプレーなので、PK は 約14×0.25×この値 ≒ 0.3本/試合(実際の欧州
  /// 5大リーグは0.25〜0.3本)。以前は0.15で約0.5本/試合あった。
  static const double _penaltyShare = 0.085;

  /// セットプレーのうち直接フリーキックになる割合。以前は0.40(決まる確率も
  /// 約16%)で、直接FKの得点が全得点の約9%を占めていた(実際は1〜2%)。
  static const double _directFreeKickShare = 0.18;

  /// セットプレー(PK・直接FK・CK)由来のチャンス。担当に指名された選手が
  /// いれば優先的に関わり、専門の能力値でチャンスの質が変わる。
  static ({
    Player? scorer,
    Player? forcedAssist,
    double scoreProb,
    SetPieceKind? kind,
  }) _rollSetPiece({
    required Team attackingTeam,
    required List<Player> attackingLineup,
    required Team defendingTeam,
    required List<Player> defendingLineup,
    required double baseProb,
  }) {
    final subRoll = _rng.nextDouble();
    if (subRoll < _penaltyShare) {
      final scorer = _pickSetPieceTaker(
            attackingTeam.penaltyTakerId,
            attackingLineup,
          ) ??
          _pickScorer(attackingLineup);
      final penaltyAttr = scorer?.attributeValue(AttributeKeys.penalties) ?? 50;
      // PK は実際には蹴った数の約75%が決まる。
      return (
        scorer: scorer,
        forcedAssist: null,
        scoreProb: (0.75 + (penaltyAttr - 50) / 300).clamp(0.6, 0.9),
        kind: SetPieceKind.penalty,
      );
    }
    if (subRoll < _penaltyShare + _directFreeKickShare) {
      final scorer = _pickSetPieceTaker(
            attackingTeam.freeKickTakerId,
            attackingLineup,
          ) ??
          _pickScorer(attackingLineup);
      final freeKickAttr = scorer?.attributeValue(AttributeKeys.freeKick) ?? 50;
      // 直接FKが決まるのは実際には蹴った数の5〜7%ほど。
      final prob = (0.06 + (freeKickAttr - 50) / 600).clamp(0.02, 0.15);
      return (
        scorer: scorer,
        forcedAssist: null,
        scoreProb: applySetPieceDefense(prob, defendingTeam, defendingLineup),
        kind: SetPieceKind.directFreeKick,
      );
    }
    final corner = resolveCorner(
      attackingTeam: attackingTeam,
      attackingLineup: attackingLineup,
      defendingTeam: defendingTeam,
      defendingLineup: defendingLineup,
      baseProb: baseProb,
    );
    return (
      scorer: corner.scorer,
      forcedAssist: corner.taker,
      scoreProb: corner.scoreProb,
      kind: null,
    );
  }

  static Player? _pickCardTarget(
    List<Player> lineup, {
    Set<String> exclude = const {},
  }) {
    final candidates = lineup
        .where((p) =>
            p.position.group != PositionGroup.gk && !exclude.contains(p.id))
        .toList();
    if (candidates.isEmpty) return null;
    final weights = candidates
        .map(
          (p) =>
              1 +
              p.attributeValue(AttributeKeys.aggression) ~/ 10 +
              (100 - p.attributeValue(AttributeKeys.composure)) ~/ 25,
        )
        .toList();
    final total = weights.fold<int>(0, (s, w) => s + w);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (int i = 0; i < candidates.length; i++) {
      if (r < weights[i]) return candidates[i];
      r -= weights[i];
    }
    return candidates.last;
  }

  /// 試合の始まりに、前の試合から残っている警告の印を消す。
  static void resetMatchCards(Team home, Team away) {
    for (final p in home.players) {
      p.yellowCardedThisMatch = false;
    }
    for (final p in away.players) {
      p.yellowCardedThisMatch = false;
    }
  }

  /// この試合でもう出た警告を、選手の印に戻す。何度呼んでも同じ結果になる。
  /// 再起動して試合を途中から再開したとき、保存しない印をイベントから
  /// 復元するのに使う(前半の警告を後半へ引き継ぐため)。
  static void markYellowCardsFromEvents(
    Team home,
    Team away,
    Iterable<MatchEvent> events,
  ) {
    final byId = {
      for (final p in [...home.players, ...away.players]) p.id: p,
    };
    for (final e in events) {
      if (e.type != MatchEventType.yellowCard) continue;
      byId[e.scorerId]?.yellowCardedThisMatch = true;
    }
  }

  /// [startMinute]〜[endMinute](両端含む)の区間だけをシミュレートする。
  /// ハーフタイムでの交代・戦術変更を反映できるよう、前半・後半を別々に
  /// 呼び出せるようにするための下位レベルAPI。疲労・負傷はここでは
  /// 適用しない([applyPostMatchEffects]を試合終了後に別途呼ぶこと)。
  ///
  /// [priorEvents]はこの試合でこの区間より前に起きたこと(後半なら前半の
  /// イベント)。そこで退場した選手はこの区間に出さず、そのチームは区間の
  /// 始めから数的不利のまま戦う。以前は渡す口が無く、前半に退場した選手が
  /// 後半も出て、数的不利も消えていた。
  static HalfResult simulateMinutes({
    required Team home,
    required Team away,
    required int startMinute,
    required int endMinute,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = defaultHomeAdvantageFactor,
    List<MatchEvent> priorEvents = const [],
  }) {
    // 前半開始時に全選手のフラグをリセットして先発の倍率を算出する。
    // 後半開始時は、前半に出場せず後半で初めて起用された選手(途中出場の
    // 交代選手・負傷者の穴埋め等)にのみ改めて算出する。
    if (startMinute == 1) {
      _rollMatchForm(home, away, weather);
    } else {
      _rollMatchFormForCurrentLineup(home, away, weather);
    }
    // 警告の数は1試合を通して数える(2枚目の警告=退場)。消すのは試合の
    // 始まり(前半の1分)だけで、ハーフタイムでは消さない。
    if (startMinute == 1) resetMatchCards(home, away);

    final priorSentOff = sentOffIds(priorEvents);
    final homeLineup = _withoutIds(lineupOf(home), priorSentOff);
    final awayLineup = _withoutIds(lineupOf(away), priorSentOff);

    final homeMarkedId = markedTargetId(away, awayLineup, homeLineup);
    final awayMarkedId = markedTargetId(home, homeLineup, awayLineup);

    // 対策指示。自分の攻守に掛かるぶんと、相手の攻撃を鈍らせるぶんがある。
    final homeAttackBase = _attackPower(home, homeLineup,
            suppressedId: homeMarkedId, opponentStyle: away.tacticalStyle) *
        planAttackFactor(home, awayLineup) *
        away.oppositionPlan.opponentAttackFactor *
        homeAdvantageFactor *
        weather.attackMultiplier;
    final awayAttackBase = _attackPower(away, awayLineup,
            suppressedId: awayMarkedId, opponentStyle: home.tacticalStyle) *
        planAttackFactor(away, homeLineup) *
        home.oppositionPlan.opponentAttackFactor *
        weather.attackMultiplier;
    final homeDefenseBase = _defensePower(home, homeLineup) *
        home.oppositionPlan.ownDefenseFactor *
        weather.defenseMultiplier;
    final awayDefenseBase = _defensePower(away, awayLineup) *
        away.oppositionPlan.ownDefenseFactor *
        weather.defenseMultiplier;

    final events = <MatchEvent>[];
    int homeGoals = 0;
    int awayGoals = 0;
    final span = endMinute - startMinute + 1;
    final minutesUsed = <int>{};

    // カードイベント(警告・退場)を先に生成し、退場が発生した分数を記録する。
    // ゴールチャンスの評価時にこの分数以降は数的不利として攻守力を下げる。
    // 前の区間(前半)で退場した選手がいれば、この区間の始めから数的不利。
    final reds = _rollCards(
      home: home,
      away: away,
      homeLineup: homeLineup,
      awayLineup: awayLineup,
      startMinute: startMinute,
      span: span,
      minutesUsed: minutesUsed,
      events: events,
      homeRedMinute: _priorRedMinute(priorEvents, home.id, startMinute),
      awayRedMinute: _priorRedMinute(priorEvents, away.id, startMinute),
    );
    final homeRedMinute = reds.home;
    final awayRedMinute = reds.away;

    // ゴールチャンスは時系列(分)順に評価し、退場による数的不利と
    // 直近の得点による「勢い」を反映する。
    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90 * weather.chanceCountMultiplier)
            .round()
            .clamp(1, 20);
    final chanceMinutes = <int>[];
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);
      chanceMinutes.add(minute);
    }
    chanceMinutes.sort();

    double homeMomentum = 0;
    double awayMomentum = 0;
    int homeShots = 0;
    int awayShots = 0;
    int homeShotsOnTarget = 0;
    int awayShotsOnTarget = 0;
    double possessionShareSum = 0;
    for (final minute in chanceMinutes) {
      final homeRedActive = homeRedMinute != null && minute > homeRedMinute;
      final awayRedActive = awayRedMinute != null && minute > awayRedMinute;
      final homeAttack = homeAttackBase * (homeRedActive ? 0.85 : 1.0);
      final awayAttack = awayAttackBase * (awayRedActive ? 0.85 : 1.0);
      final homeDefense = homeDefenseBase * (homeRedActive ? 0.82 : 1.0);
      final awayDefense = awayDefenseBase * (awayRedActive ? 0.82 : 1.0);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      possessionShareSum += homeShare;
      final isHomeChance = _rng.nextDouble() < homeShare;
      if (isHomeChance) {
        homeShots++;
      } else {
        awayShots++;
      }
      // 同じ半のうちに退場した選手は、その分より後は数えない。
      final attackingLineup =
          _stillOnPitch(isHomeChance ? homeLineup : awayLineup, events, minute);
      final defendingLineup =
          _stillOnPitch(isHomeChance ? awayLineup : homeLineup, events, minute);
      final attackingTeam = isHomeChance ? home : away;
      final defendingTeam = isHomeChance ? away : home;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;
      final momentum = isHomeChance ? homeMomentum : awayMomentum;

      final diff = attackingPower - defendingDefense;
      var scoreProb =
          (_baseScoreProb + diff / 220 + momentum).clamp(0.05, 0.75);
      Player? scorer;
      Player? forcedAssist;
      SetPieceKind? setPiece;
      if (_rng.nextDouble() < _setPieceChanceShare) {
        final sp = _rollSetPiece(
          attackingTeam: attackingTeam,
          attackingLineup: attackingLineup,
          defendingTeam: defendingTeam,
          defendingLineup: defendingLineup,
          baseProb: scoreProb,
        );
        scorer = sp.scorer;
        forcedAssist = sp.forcedAssist;
        scoreProb = sp.scoreProb;
        setPiece = sp.kind;
      } else {
        // オープンプレー: まずサイドでの1対1を判定する。ワイドな選手が
        // いれば、対面の守備者とのデュエルに勝った場合のみクロス→空中戦の
        // 流れになり、負ければ質の落ちた通常の崩しに留まる。
        final right = _rng.nextBool();
        final wideAttacker = _pickWideAttacker(attackingLineup, right);
        final isWidePlay = wideAttacker != null && _rng.nextDouble() < 0.55;
        if (isWidePlay) {
          final marker = _findSameSideDefender(defendingLineup, right);
          final wonDuel =
              _rng.nextDouble() < _wideDuelWinProb(wideAttacker, marker);
          if (wonDuel) {
            scorer = _pickAerialTarget(
              attackingLineup,
              excludeId: wideAttacker.id,
            );
            forcedAssist = wideAttacker;
            final crossQuality = wideAttacker.attributeValue(
              AttributeKeys.crossing,
            );
            scoreProb = (scoreProb * (1 + (crossQuality - 50) / 250)).clamp(
              0.05,
              0.8,
            );
            if (scorer != null) {
              scoreProb =
                  scoreProb * _aerialDuelFactor(scorer, defendingLineup);
            }
            scoreProb = _applyHeaderQuality(scoreProb, scorer);
          } else {
            scorer = _pickScorer(attackingLineup);
            scoreProb = (scoreProb * 0.7).clamp(0.05, 0.75);
            scoreProb = _applyFinisherQuality(scoreProb, scorer);
          }
        } else {
          scorer = _pickScorer(attackingLineup);
          scoreProb = _applyFinisherQuality(scoreProb, scorer);
        }
      }
      if (_rng.nextDouble() < scoreProb) {
        final assist = setPiece != null
            ? null
            : (forcedAssist ?? _pickAssist(attackingLineup, scorer));
        events.add(
          MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: scorer?.name,
            scorerId: scorer?.id,
            assistName: assist?.name,
            assistId: assist?.id,
            setPiece: setPiece,
          ),
        );
        if (isHomeChance) {
          homeGoals++;
          homeShotsOnTarget++;
          homeMomentum = (homeMomentum + 0.05).clamp(-0.08, 0.08);
          awayMomentum = (awayMomentum - 0.02).clamp(-0.08, 0.08);
        } else {
          awayGoals++;
          awayShotsOnTarget++;
          awayMomentum = (awayMomentum + 0.05).clamp(-0.08, 0.08);
          homeMomentum = (homeMomentum - 0.02).clamp(-0.08, 0.08);
        }
      } else if (setPiece == SetPieceKind.penalty) {
        // PK は外れても必ず記録する(PK の本数を数えられるように)。
        if (isHomeChance) {
          homeShotsOnTarget++;
        } else {
          awayShotsOnTarget++;
        }
        events.add(
          MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: scorer?.name,
            scorerId: scorer?.id,
            type: MatchEventType.chance,
            setPiece: setPiece,
          ),
        );
      } else if (_rng.nextDouble() < 0.45) {
        // 得点には至らなかった惜しいチャンスを実況として記録する(枠内シュート)。
        final shooter = _pickScorer(attackingLineup);
        if (isHomeChance) {
          homeShotsOnTarget++;
        } else {
          awayShotsOnTarget++;
        }
        events.add(
          MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: shooter?.name,
            scorerId: shooter?.id,
            type: MatchEventType.chance,
          ),
        );
      }
      homeMomentum *= 0.9;
      awayMomentum *= 0.9;
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    // 記録としてのシュート数を現実的な水準にするため、枠外・ブロックされた
    // 「打っただけ」のシュートを上乗せする(得点計算には一切影響しない)。
    final speculative = speculativeShotsForStats(
      chanceMinutes.length,
      chanceMinutes.isEmpty ? 0.5 : possessionShareSum / chanceMinutes.length,
    );
    homeShots += speculative.home;
    awayShots += speculative.away;
    return HalfResult(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: events,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
      possessionShareSum: possessionShareSum,
      chanceCount: chanceMinutes.length,
    );
  }

  /// 相手が守備セットプレー担当を指名して出場させている場合、その選手の
  /// ヘディング・ジャンプ力に応じてセットプレー由来のチャンスの質を下げる。
  static double applySetPieceDefense(
    double scoreProb,
    Team defendingTeam,
    List<Player> defendingLineup,
  ) {
    final defender = _pickSetPieceTaker(
      defendingTeam.setPieceDefenderId,
      defendingLineup,
    );
    if (defender == null) return scoreProb;
    final defSkill = (defender.attributeValue(AttributeKeys.heading) +
            defender.attributeValue(AttributeKeys.jumpingReach)) /
        2;
    return (scoreProb * (1 - (defSkill - 50) / 250)).clamp(0.05, 0.9);
  }

  /// オープンプレー・コーナーのチャンスにおいて、実際にそのチャンスを迎えた
  /// 選手個人のフィニッシュの質(決定力・冷静さ・オフザボール)を得点確率に
  /// 反映する。チーム総合力の平均値だけでチャンスの成否が決まってしまうと、
  /// 個々の選手の能力(誰がその1本を任されるか)が結果に表れなくなるため、
  /// PK・FKの専門能力反映と同じ考え方をオープンプレーにも適用する。
  static double _applyFinisherQuality(double scoreProb, Player? scorer) {
    if (scorer == null) return scoreProb;
    final quality = (scorer.attributeValue(AttributeKeys.finishing) * 0.5 +
        scorer.attributeValue(AttributeKeys.composure) * 0.3 +
        scorer.attributeValue(AttributeKeys.offTheBall) * 0.2);
    return (scoreProb * (1 + (quality - 50) / 150)).clamp(0.05, 0.85);
  }

  /// 試合終了後に一度だけ呼ぶ、疲労蓄積・負傷判定・出場停止の消化と新規カードの反映。
  /// [events]はこの試合(前後半通し)で発生した全イベント。
  static void applyPostMatchEffects({
    required Team home,
    required Team away,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    List<MatchEvent> events = const [],
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    // 前半分の疲労は既にapplyHalfTimeFatigueで反映済みのため、ここでは
    // 後半分(intensity 0.5)のみを加算する。
    _applyFatigue(
      home,
      homeLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _applyFatigue(
      away,
      awayLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);
    _growPositionFamiliarity(home, homeLineup);
    _growPositionFamiliarity(away, awayLineup);
    _updateMatchSharpness(home, homeLineup);
    _updateMatchSharpness(away, awayLineup);
    for (final p in [...homeLineup, ...awayLineup]) {
      TrainingEngine.growFromMatchExperience(p);
    }
    // 出場停止の消化は既存の出場停止(前節以前に受けたもの)にのみ適用し、
    // その後で今節に新たに受けたカードを反映する。
    _advanceSuspensions(home, homeLineup);
    _advanceSuspensions(away, awayLineup);
    _applyCardAccumulation(home, away, events);
    _applyCareerStats(homeLineup, awayLineup, events);
  }

  /// 出場選手の通算出場数・通算得点数を加算する(親善試合はこの関数を
  /// 呼ばないため対象外)。
  static void _applyCareerStats(
    List<Player> homeLineup,
    List<Player> awayLineup,
    List<MatchEvent> events,
  ) {
    final lineupIds = <String, Player>{
      for (final p in [...homeLineup, ...awayLineup]) p.id: p,
    };
    for (final p in lineupIds.values) {
      p.careerAppearances += 1;
    }
    for (final e in events) {
      if (e.type != MatchEventType.goal) continue;
      lineupIds[e.scorerId]?.careerGoals += 1;
    }
  }

  /// 出場停止選手のうち、今節の対象外だった(実際に1試合を消化した)選手だけ
  /// 出場停止試合数を1減らす。今節新たに出場停止となった選手(今節は出場して
  /// カードを受けた側)は対象外で、次節から出場停止が適用される。
  static void _advanceSuspensions(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (p.suspendedMatches > 0 && !lineupIds.contains(p.id)) {
        p.suspendedMatches -= 1;
      }
    }
  }

  /// 今節発生した警告・退場イベントを選手の累積数に反映する。
  static void _applyCardAccumulation(
    Team home,
    Team away,
    List<MatchEvent> events,
  ) {
    final byId = {
      for (final p in [...home.players, ...away.players]) p.id: p,
    };
    for (final e in events) {
      if (e.type != MatchEventType.yellowCard &&
          e.type != MatchEventType.redCard) {
        continue;
      }
      final target = byId[e.scorerId];
      if (target == null) continue;
      if (e.type == MatchEventType.redCard) {
        target.suspendedMatches += 1;
      } else {
        target.yellowCards += 1;
        if (target.yellowCards >= yellowCardSuspensionThreshold) {
          target.yellowCards = 0;
          target.suspendedMatches += 1;
        }
      }
    }
  }

  /// 出場した選手の試合内採点(1.0〜10.0)を算出する。基準点6.0から、得点・
  /// 決定機創出でプラス、警告・退場でマイナス、所属チームの勝敗で補正する。
  static Map<String, double> computePlayerRatings({
    required Team home,
    required Team away,
    required List<MatchEvent> events,
    required int homeGoals,
    required int awayGoals,
    List<Player> subbedOff = const [],
  }) {
    // 自動の交代で下がった選手も、前半は出ているので採点する。
    final homeIds = {for (final p in home.players) p.id};
    final homeLineup = [
      ...lineupOf(home),
      ...subbedOff.where((p) => homeIds.contains(p.id)),
    ];
    final awayLineup = [
      ...lineupOf(away),
      ...subbedOff.where((p) => !homeIds.contains(p.id)),
    ];
    final ratings = <String, double>{};
    for (final p in [...homeLineup, ...awayLineup]) {
      ratings[p.id] = 6.0;
    }

    for (final e in events) {
      final id = e.scorerId;
      if (id != null && ratings.containsKey(id)) {
        switch (e.type) {
          case MatchEventType.goal:
            ratings[id] = ratings[id]! + 1.0;
            break;
          case MatchEventType.chance:
            // 外した PK は「惜しい決定機」ではないので加点しない。
            if (e.setPiece != SetPieceKind.penalty) {
              ratings[id] = ratings[id]! + 0.3;
            }
            break;
          case MatchEventType.yellowCard:
            ratings[id] = ratings[id]! - 0.5;
            break;
          case MatchEventType.redCard:
            ratings[id] = ratings[id]! - 1.5;
            break;
        }
      }
      // アシスト提供者にも得点者ほどではないが小幅な採点ボーナスを与える。
      final assistId = e.assistId;
      if (e.type == MatchEventType.goal &&
          assistId != null &&
          ratings.containsKey(assistId)) {
        ratings[assistId] = ratings[assistId]! + 0.5;
      }
    }

    final resultBonus = homeGoals > awayGoals
        ? 0.4
        : homeGoals < awayGoals
            ? -0.4
            : 0.0;
    for (final p in homeLineup) {
      ratings[p.id] = ratings[p.id]! + resultBonus;
    }
    for (final p in awayLineup) {
      ratings[p.id] = ratings[p.id]! - resultBonus;
    }

    return ratings.map(
      (id, r) => MapEntry(id, (r.clamp(1.0, 10.0) * 2).round() / 2),
    );
  }

  /// 前半・後半をまとめて一括シミュレートする(CPU同士の試合・カップ戦など、
  /// ハーフタイム操作が不要な場合に使う)。
  /// マンマーク指令が未指定のチームに対し、相手のキープレイヤーが自チームの
  /// 平均総合力を大きく上回る場合に限り、守備力最高の選手へ自動で指令する。
  /// 既に指名済み(=ユーザーが手動で指名した、または前節までに自動指令済み)
  /// の場合は上書きしない。CPUクラブが一切マンマークを使わず、ユーザーの
  /// キープレイヤーが常にノーマークになる一方的な状況を防ぐための処置。
  static void _maybeAutoAssignManMarker(Team team, List<Player> oppLineup) {
    if (team.manMarkerId != null) return;
    if (team.players.isEmpty) return;
    final keyPlayer = identifyKeyPlayer(oppLineup);
    if (keyPlayer == null) return;
    final avgOverall = team.players.fold<int>(0, (s, p) => s + p.overall) /
        team.players.length;
    if (keyPlayer.overall - avgOverall < 8) return;
    Player? marker;
    for (final p in team.players) {
      if (marker == null || p.defense > marker.defense) marker = p;
    }
    team.manMarkerId = marker?.id;
  }

  // ============================================================
  // インタラクティブ進行(自クラブの試合でシュート/パスを選べるモード)
  //
  // 以下は[simulateMinutes]/[simulate]とは完全に独立した並行実装。
  // 既存の一括シミュレーション(CPU同士の試合・カップ戦・クイックシム)は
  // 引き続き[simulateMinutes]/[simulate]をそのまま使い、一切変更しない。
  // ここでは、ユーザーが出場する試合のオープンプレーの決定機でのみ
  // [InteractiveHalfState.pending]に判断材料をセットして進行を一時停止し、
  // [resolvePendingChance]で選んだ結果を反映して再開できるようにする。
  // ============================================================

  /// パス/シュートの選択を求める判断材料。ダイアログ表示に使う。
  static const double _passWeightAttack = 1.0;

  /// パスでチャンスを継続する際につなぐ味方を選ぶ。攻撃力で重み付けし、
  /// 現状シュートする予定の選手は除外する(つなげる相手がいなければnull)。
  static Player? _pickPassTarget(List<Player> lineup, {String? excludeId}) {
    final candidates = lineup
        .where(
          (p) =>
              p.id != excludeId &&
              (p.position.group == PositionGroup.att ||
                  p.position.group == PositionGroup.mid),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(
      0,
      (s, p) => s + (p.attack * _passWeightAttack).round(),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = (p.attack * _passWeightAttack).round();
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  /// このチャンスを最終的な成功率([scoreProb])で判定し、結果に応じた
  /// イベントを[s.events]に追加する。実際に発生したイベント(得点/惜しい
  /// チャンス)を返す。何も起きなかった場合はnull。
  static MatchEvent? _finalizeChance(
    InteractiveHalfState s, {
    required int minute,
    required bool isHomeChance,
    required Team attackingTeam,
    required Player? scorer,
    required Player? forcedAssist,
    required double scoreProb,
    SetPieceKind? setPiece,
  }) {
    final attackingLineup = _stillOnPitch(
        isHomeChance ? s.homeLineup : s.awayLineup, s.events, minute);
    MatchEvent? produced;
    if (_rng.nextDouble() < scoreProb) {
      final assist = setPiece != null
          ? null
          : (forcedAssist ?? _pickAssist(attackingLineup, scorer));
      produced = MatchEvent(
        minute: minute,
        teamId: attackingTeam.id,
        scorerName: scorer?.name,
        scorerId: scorer?.id,
        assistName: assist?.name,
        assistId: assist?.id,
        setPiece: setPiece,
      );
      s.events.add(produced);
      if (isHomeChance) {
        s.homeGoals++;
        s.homeShotsOnTarget++;
        s.homeMomentum = (s.homeMomentum + 0.05).clamp(-0.08, 0.08);
        s.awayMomentum = (s.awayMomentum - 0.02).clamp(-0.08, 0.08);
      } else {
        s.awayGoals++;
        s.awayShotsOnTarget++;
        s.awayMomentum = (s.awayMomentum + 0.05).clamp(-0.08, 0.08);
        s.homeMomentum = (s.homeMomentum - 0.02).clamp(-0.08, 0.08);
      }
    } else if (setPiece == SetPieceKind.penalty || _rng.nextDouble() < 0.45) {
      // PK は外れても必ず記録する(PK の本数を数えられるように)。
      if (isHomeChance) {
        s.homeShotsOnTarget++;
      } else {
        s.awayShotsOnTarget++;
      }
      produced = MatchEvent(
        minute: minute,
        teamId: attackingTeam.id,
        scorerName: scorer?.name,
        scorerId: scorer?.id,
        type: MatchEventType.chance,
        setPiece: setPiece,
      );
      s.events.add(produced);
    }
    s.homeMomentum *= 0.9;
    s.awayMomentum *= 0.9;
    return produced;
  }

  /// 決定機の対象になった選手のオープンプレー基礎成功率([baseScoreProb])
  /// から、ロングシュートを選んだ場合の成功率を算出する。近距離のシュート
  /// より成功率は下がる一方、ロングシュート適性(longShots・technique)が
  /// 高い選手ほどその下げ幅が小さくなる。
  static double _applyLongShotQuality(double baseScoreProb, Player? shooter) {
    final reduced = (baseScoreProb * 0.55).clamp(0.03, 0.4);
    if (shooter == null) return reduced;
    final quality = shooter.attributeValue(AttributeKeys.longShots) * 0.65 +
        shooter.attributeValue(AttributeKeys.technique) * 0.35;
    return (reduced * (1 + (quality - 50) / 120)).clamp(0.03, 0.55);
  }

  /// 守備側が「積極的にタックル」を選んだ場合に、相手の得点成功率へ乗じる
  /// 倍率。より大きく下げる代わり、後述の警告/退場リスクを伴う。
  static const double _aggressiveTackleReduction = 0.72;

  /// 守備側が「カバーリングに専念」を選んだ場合の、相手の得点成功率への
  /// 倍率。警告/退場のリスクを負わない安全な選択肢。CPU同士の試合
  /// (simulate)には守備側の決定機判断が存在しないため、この中立選択を
  /// 1.0未満にすると「自クラブだけが恒常的に失点を割り引かれる」不公平が
  /// 生じる(実測で約9%の失点減を確認)。よって中立=1.0とし、リスクを
  /// 取ってタックルに行く場合のみ成功率が動くようにする。
  static const double _coverSpaceReduction = 1.0;

  /// 積極的にタックルへ行った際に警告(まれに退場)を受ける基礎確率。
  static const double _aggressiveTackleCardChance = 0.16;

  /// 「リスクを取る」采配時に、自クラブの攻撃側決定機の各成功率へ乗じる倍率。
  static const double _aggressiveInstructionAttackMultiplier = 1.10;

  /// 「リスクを取る」采配時に、自クラブの守備側決定機で相手に献上する
  /// 成功率へ乗じる倍率(前掛かりになる分、守備の負担が増える)。
  static const double _aggressiveInstructionDefenseMultiplier = 1.12;

  /// 「安全に下がる」采配時に、自クラブの攻撃側決定機の各成功率へ乗じる倍率。
  static const double _cautiousInstructionAttackMultiplier = 0.90;

  /// 「安全に下がる」采配時に、自クラブの守備側決定機で相手に献上する
  /// 成功率へ乗じる倍率(態勢を整える分、守備が安定する)。
  static const double _cautiousInstructionDefenseMultiplier = 0.88;

  static double _attackInstructionMultiplier(MatchInstruction instruction) =>
      switch (instruction) {
        MatchInstruction.aggressive => _aggressiveInstructionAttackMultiplier,
        MatchInstruction.cautious => _cautiousInstructionAttackMultiplier,
        MatchInstruction.balanced => 1.0,
      };

  static double _defenseInstructionMultiplier(MatchInstruction instruction) =>
      switch (instruction) {
        MatchInstruction.aggressive => _aggressiveInstructionDefenseMultiplier,
        MatchInstruction.cautious => _cautiousInstructionDefenseMultiplier,
        MatchInstruction.balanced => 1.0,
      };

  /// 自クラブの現在の采配方針を変更する。試合中いつでも呼び出せ、
  /// 次に生成される決定機から反映される。
  static void setInstruction(
    InteractiveHalfState state,
    MatchInstruction instruction,
  ) {
    state.instruction = instruction;
  }

  /// ライブ観戦中(インタラクティブ進行中)の交代を適用する。ハーフタイム
  /// を待たず試合中に選手を入れ替えられる。交代枠の消費とstartingXIの
  /// 更新は呼び出し側(GameState)の責務で、ここでは進行中ハーフの状態
  /// (出場中ラインナップと攻守力)だけを交代後の内容へ再計算する。
  ///
  /// 未終了の状態は常に次の決定機([InteractiveHalfState.pending])で
  /// 停止しているため、pendingが立っていても交代は許可する。ただし、
  /// その決定機に関与している選手(シューター/パス先/GK/攻撃者/守備者)
  /// を出入りさせると、提示済みの成功率や得点者の帰属が実態と食い違う
  /// ため拒否する。成功時true、適用できない場合は何もせずfalse。
  static bool applyInteractiveSubstitution(
    InteractiveHalfState state, {
    required String teamId,
    required String outPlayerId,
    required String inPlayerId,
  }) {
    if (state.isFinished) return false;
    final isHome = teamId == state.home.id;
    if (!isHome && teamId != state.away.id) return false;
    final pending = state.pending;
    if (pending != null) {
      final involvedIds = {
        pending.shooter?.id,
        pending.passTarget?.id,
        pending.keeper?.id,
        pending.attacker?.id,
        pending.defender?.id,
      };
      if (involvedIds.contains(outPlayerId) ||
          involvedIds.contains(inPlayerId)) {
        return false;
      }
    }
    // 退場した選手を下げて控えを入れると、11人に戻ってしまう。
    if (sentOffIds([...state.priorEvents, ...state.events])
        .contains(outPlayerId)) {
      return false;
    }
    final team = isHome ? state.home : state.away;
    final lineup = isHome ? state.homeLineup : state.awayLineup;
    final outIndex = lineup.indexWhere((p) => p.id == outPlayerId);
    if (outIndex < 0) return false;
    if (lineup.any((p) => p.id == inPlayerId)) return false;
    Player? incoming;
    for (final p in team.players) {
      if (p.id == inPlayerId) incoming = p;
    }
    if (incoming == null) return false;
    if (incoming.isInjured ||
        incoming.isSuspended ||
        incoming.isOnInternationalDuty ||
        incoming.isLoanedOut ||
        incoming.notRegistered) {
      return false;
    }

    lineup[outIndex] = incoming;
    // 途中出場の選手に、この試合分の特性由来パフォーマンス倍率をまだ
    // 持っていなければ割り当てる(前半に出場済みなら同じ値を使い続ける)。
    if (!incoming.matchFormRolledThisMatch) {
      final homeAvg = _avgOverall(state.homeLineup);
      final awayAvg = _avgOverall(state.awayLineup);
      incoming.matchFormMultiplier = _traitFormMultiplier(
        incoming,
        selfAvg: isHome ? homeAvg : awayAvg,
        oppAvg: isHome ? awayAvg : homeAvg,
        isHome: isHome,
        weather: state.weather,
      );
      incoming.matchFormRolledThisMatch = true;
    }
    _recomputeInteractiveBases(state);
    return true;
  }

  /// 交代でラインナップが変わった後、このハーフの残りのチャンス評価に
  /// 使う攻守力をハーフ開始時と同じ算出条件で計算し直す。
  static void _recomputeInteractiveBases(InteractiveHalfState s) {
    final homeMarkedId = markedTargetId(s.away, s.awayLineup, s.homeLineup);
    final awayMarkedId = markedTargetId(s.home, s.homeLineup, s.awayLineup);
    s.homeAttackBase = _attackPower(s.home, s.homeLineup,
            suppressedId: homeMarkedId, opponentStyle: s.away.tacticalStyle) *
        s.homeAdvantageFactor *
        s.weather.attackMultiplier;
    s.awayAttackBase = _attackPower(s.away, s.awayLineup,
            suppressedId: awayMarkedId, opponentStyle: s.home.tacticalStyle) *
        s.weather.attackMultiplier;
    s.homeDefenseBase =
        _defensePower(s.home, s.homeLineup) * s.weather.defenseMultiplier;
    s.awayDefenseBase =
        _defensePower(s.away, s.awayLineup) * s.weather.defenseMultiplier;
  }

  /// [lineup]からゴールキーパーを探す(見つからなければnull)。
  static Player? _findGoalkeeper(List<Player> lineup) {
    for (final p in lineup) {
      if (p.position.group == PositionGroup.gk) return p;
    }
    return null;
  }

  /// 決定機で相手の攻撃を最も受け止められる守備者(タックル+
  /// ポジショニングが最も高い選手、GKを除く)を選ぶ。
  static Player? _pickChallenger(List<Player> lineup) {
    final candidates =
        lineup.where((p) => p.position.group != PositionGroup.gk).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aScore = a.attributeValue(AttributeKeys.tackling) +
          a.attributeValue(AttributeKeys.positioning);
      final bScore = b.attributeValue(AttributeKeys.tackling) +
          b.attributeValue(AttributeKeys.positioning);
      return bScore.compareTo(aScore);
    });
    return candidates.first;
  }

  /// シューター(またはパス先)とGKの一騎打ちを、決定力・テクニック・
  /// 冷静さ vs GKの反応速度・一対一・ハンドリングで比較し、成功率への
  /// 倍率(0.7〜1.3)として返す。GK不在(データ不整合)の場合は等倍。
  static double _shooterVsKeeperFactor(Player shooter, Player? keeper) {
    final shootSkill = shooter.attributeValue(AttributeKeys.finishing) * 0.5 +
        shooter.attributeValue(AttributeKeys.technique) * 0.3 +
        shooter.attributeValue(AttributeKeys.composure) * 0.2;
    if (keeper == null) return 1.0;
    final keeperSkill = keeper.attributeValue(AttributeKeys.reflexes) * 0.4 +
        keeper.attributeValue(AttributeKeys.oneOnOnes) * 0.4 +
        keeper.attributeValue(AttributeKeys.handling) * 0.2;
    return (1.0 + (shootSkill - keeperSkill) / 300).clamp(0.7, 1.3);
  }

  /// 守備側の決定機で、対応する自チーム守備者と相手選手の突破力を
  /// タックル・ポジショニング・積極性 vs ドリブル・スピード・敏捷性・閃きで
  /// 比較し、相手の得点成功率への倍率(0.7〜1.3)として返す。対応できる
  /// 守備者がいない(数的不利)場合は相手に有利な倍率を返す。
  static double _defenderVsAttackerFactor(Player? defender, Player attacker) {
    final attackSkill =
        attacker.attributeValue(AttributeKeys.dribbling) * 0.35 +
            attacker.attributeValue(AttributeKeys.pace) * 0.25 +
            attacker.attributeValue(AttributeKeys.agility) * 0.15 +
            attacker.attributeValue(AttributeKeys.flair) * 0.25;
    if (defender == null) return 1.15;
    final defendSkill = defender.attributeValue(AttributeKeys.tackling) * 0.45 +
        defender.attributeValue(AttributeKeys.positioning) * 0.35 +
        defender.attributeValue(AttributeKeys.aggression) * 0.2;
    return (1.0 + (attackSkill - defendSkill) / 300).clamp(0.7, 1.3);
  }

  /// [simulateMinutes]と同じ区間シミュレーションのセットアップ(カード生成・
  /// チャンス発生分の抽選・攻守力算出)を行い、チャンス評価に進む前の
  /// [InteractiveHalfState]を返す。呼び出し直後に内部で最初のチャンス評価まで
  /// 進めるため、[interactiveTeamId]の決定機が最初のチャンスにあれば
  /// 即座に[InteractiveHalfState.pending]がセットされた状態で返る。
  static InteractiveHalfState beginInteractiveHalf({
    required Team home,
    required Team away,
    required int startMinute,
    required int endMinute,
    required String interactiveTeamId,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = defaultHomeAdvantageFactor,
    HalfTally? carried,
    List<MatchEvent> priorEvents = const [],
  }) {
    if (startMinute > endMinute) {
      // 再開した時点で、このハーフはもう終わっていた。
      return finishedHalfFrom(
        home: home,
        away: away,
        interactiveTeamId: interactiveTeamId,
        weather: weather,
        homeAdvantageFactor: homeAdvantageFactor,
        carried: carried ?? const HalfTally(),
      );
    }
    if (startMinute == 1) {
      _rollMatchForm(home, away, weather);
    } else {
      _rollMatchFormForCurrentLineup(home, away, weather);
    }
    // 警告は1試合を通して数える。試合の始まりでだけ消し、途中から
    // 再開するときは、それまでの警告を引き継いだ途中経過から戻す
    // (フラグは保存しないので、再起動するとここでしか戻らない)。
    if (startMinute == 1) {
      resetMatchCards(home, away);
    } else if (carried != null) {
      markYellowCardsFromEvents(home, away, carried.events);
    }

    // 前の区間(前半)と、再開する前のこの区間で退場した選手は出さない。
    final sentOffBefore = sentOffIds([...priorEvents, ...?carried?.events]);
    final homeLineup = _withoutIds(lineupOf(home), sentOffBefore);
    final awayLineup = _withoutIds(lineupOf(away), sentOffBefore);
    final homeMarkedId = markedTargetId(away, awayLineup, homeLineup);
    final awayMarkedId = markedTargetId(home, homeLineup, awayLineup);

    // 対策指示。自分の攻守に掛かるぶんと、相手の攻撃を鈍らせるぶんがある。
    final homeAttackBase = _attackPower(home, homeLineup,
            suppressedId: homeMarkedId, opponentStyle: away.tacticalStyle) *
        planAttackFactor(home, awayLineup) *
        away.oppositionPlan.opponentAttackFactor *
        homeAdvantageFactor *
        weather.attackMultiplier;
    final awayAttackBase = _attackPower(away, awayLineup,
            suppressedId: awayMarkedId, opponentStyle: home.tacticalStyle) *
        planAttackFactor(away, homeLineup) *
        home.oppositionPlan.opponentAttackFactor *
        weather.attackMultiplier;
    final homeDefenseBase = _defensePower(home, homeLineup) *
        home.oppositionPlan.ownDefenseFactor *
        weather.defenseMultiplier;
    final awayDefenseBase = _defensePower(away, awayLineup) *
        away.oppositionPlan.ownDefenseFactor *
        weather.defenseMultiplier;

    final events = <MatchEvent>[];
    final span = endMinute - startMinute + 1;
    final minutesUsed = <int>{};

    final reds = _rollCards(
      home: home,
      away: away,
      homeLineup: homeLineup,
      awayLineup: awayLineup,
      startMinute: startMinute,
      span: span,
      minutesUsed: minutesUsed,
      events: events,
      homeRedMinute: _priorRedMinute(priorEvents, home.id, startMinute),
      awayRedMinute: _priorRedMinute(priorEvents, away.id, startMinute),
      excludedIds: sentOffBefore,
    );
    final homeRedMinute = reds.home;
    final awayRedMinute = reds.away;

    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90 * weather.chanceCountMultiplier)
            .round()
            .clamp(1, 20);
    final chanceMinutes = <int>[];
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);
      chanceMinutes.add(minute);
    }
    chanceMinutes.sort();

    final state = InteractiveHalfState(
      home: home,
      away: away,
      interactiveTeamId: interactiveTeamId,
      homeLineup: homeLineup,
      awayLineup: awayLineup,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
      homeAttackBase: homeAttackBase,
      awayAttackBase: awayAttackBase,
      homeDefenseBase: homeDefenseBase,
      awayDefenseBase: awayDefenseBase,
      homeRedMinute: homeRedMinute,
      awayRedMinute: awayRedMinute,
      chanceMinutes: chanceMinutes,
      events: events,
      priorEvents: priorEvents,
    );
    if (carried != null) state.applyCarried(carried);
    _advanceInteractiveHalf(state);
    return state;
  }

  /// 途中経過[carried]だけを持つ、終わったハーフ。再起動後に試合を
  /// 再開するとき、既に終えていた前半を作り直すのに使う。
  static InteractiveHalfState finishedHalfFrom({
    required Team home,
    required Team away,
    required String interactiveTeamId,
    required HalfTally carried,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = defaultHomeAdvantageFactor,
  }) {
    final state = InteractiveHalfState(
      home: home,
      away: away,
      interactiveTeamId: interactiveTeamId,
      homeLineup: lineupOf(home),
      awayLineup: lineupOf(away),
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
      homeAttackBase: 0,
      awayAttackBase: 0,
      homeDefenseBase: 0,
      awayDefenseBase: 0,
      homeRedMinute: null,
      awayRedMinute: null,
      chanceMinutes: <int>[],
      events: <MatchEvent>[],
    );
    state.applyCarried(carried);
    return state;
  }

  static void _advanceInteractiveHalf(InteractiveHalfState s) {
    while (s.chanceIndex < s.chanceMinutes.length) {
      final minute = s.chanceMinutes[s.chanceIndex];
      final homeRedActive =
          s.homeRedMinute != null && minute > s.homeRedMinute!;
      final awayRedActive =
          s.awayRedMinute != null && minute > s.awayRedMinute!;
      final homeAttack = s.homeAttackBase * (homeRedActive ? 0.85 : 1.0);
      final awayAttack = s.awayAttackBase * (awayRedActive ? 0.85 : 1.0);
      final homeDefense = s.homeDefenseBase * (homeRedActive ? 0.82 : 1.0);
      final awayDefense = s.awayDefenseBase * (awayRedActive ? 0.82 : 1.0);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      s.possessionShareSum += homeShare;
      final isHomeChance = _rng.nextDouble() < homeShare;
      if (isHomeChance) {
        s.homeShots++;
      } else {
        s.awayShots++;
      }
      // 同じ半のうちに退場した選手は、その分より後は数えない。
      final attackingLineup = _stillOnPitch(
          isHomeChance ? s.homeLineup : s.awayLineup, s.events, minute);
      final defendingLineup = _stillOnPitch(
          isHomeChance ? s.awayLineup : s.homeLineup, s.events, minute);
      final attackingTeam = isHomeChance ? s.home : s.away;
      final defendingTeam = isHomeChance ? s.away : s.home;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;
      final momentum = isHomeChance ? s.homeMomentum : s.awayMomentum;

      final diff = attackingPower - defendingDefense;
      var scoreProb =
          (_baseScoreProb + diff / 220 + momentum).clamp(0.05, 0.75);
      Player? scorer;
      Player? forcedAssist;
      SetPieceKind? setPiece;
      bool isInteractiveOpenPlay = false;

      if (_rng.nextDouble() < _setPieceChanceShare) {
        // セットプレー(PK・直接FK・CK): 従来通り即座に解決する
        // (シュート/パスの選択はオープンプレーの通常シュートに限定する)。
        final sp = _rollSetPiece(
          attackingTeam: attackingTeam,
          attackingLineup: attackingLineup,
          defendingTeam: defendingTeam,
          defendingLineup: defendingLineup,
          baseProb: scoreProb,
        );
        scorer = sp.scorer;
        forcedAssist = sp.forcedAssist;
        scoreProb = sp.scoreProb;
        setPiece = sp.kind;
      } else {
        // オープンプレー: サイドでの1対1をまず判定する。
        final right = _rng.nextBool();
        final wideAttacker = _pickWideAttacker(attackingLineup, right);
        final isWidePlay = wideAttacker != null && _rng.nextDouble() < 0.55;
        if (isWidePlay) {
          final marker = _findSameSideDefender(defendingLineup, right);
          final wonDuel =
              _rng.nextDouble() < _wideDuelWinProb(wideAttacker, marker);
          if (wonDuel) {
            // クロス→ヘディング: 従来通り即座に解決する(選択の対象外)。
            scorer = _pickAerialTarget(
              attackingLineup,
              excludeId: wideAttacker.id,
            );
            forcedAssist = wideAttacker;
            final crossQuality = wideAttacker.attributeValue(
              AttributeKeys.crossing,
            );
            scoreProb = (scoreProb * (1 + (crossQuality - 50) / 250)).clamp(
              0.05,
              0.8,
            );
            if (scorer != null) {
              scoreProb =
                  scoreProb * _aerialDuelFactor(scorer, defendingLineup);
            }
            scoreProb = _applyHeaderQuality(scoreProb, scorer);
          } else {
            scorer = _pickScorer(attackingLineup);
            scoreProb = (scoreProb * 0.7).clamp(0.05, 0.75);
            isInteractiveOpenPlay = true;
          }
        } else {
          scorer = _pickScorer(attackingLineup);
          isInteractiveOpenPlay = true;
        }
      }

      // スカッドが空でスタメンを組めない場合、得点者が選べない。判断を
      // 求めようがないので自動解決に任せる(ここで握らないと落ちる)。
      if (scorer == null) isInteractiveOpenPlay = false;

      if (isInteractiveOpenPlay) {
        if (attackingTeam.id == s.interactiveTeamId) {
          // 自クラブの攻撃側決定機: シュート/パス/ロングシュートを選べる。
          final passTarget = _pickPassTarget(
            attackingLineup,
            excludeId: scorer?.id,
          );
          final attackMult = _attackInstructionMultiplier(s.instruction);
          final keeper = _findGoalkeeper(defendingLineup);
          s.pending = PendingChanceDecision.attack(
            minute: minute,
            shooter: scorer!,
            passTarget: passTarget,
            shootChance: (_applyFinisherQuality(scoreProb, scorer) *
                    attackMult *
                    _shooterVsKeeperFactor(scorer, keeper))
                .clamp(0.0, 1.0),
            passChance: passTarget != null
                ? (_applyFinisherQuality(scoreProb, passTarget) *
                        attackMult *
                        _shooterVsKeeperFactor(passTarget, keeper))
                    .clamp(0.0, 1.0)
                : null,
            longShotChance: (_applyLongShotQuality(scoreProb, scorer) *
                    attackMult *
                    _shooterVsKeeperFactor(scorer, keeper))
                .clamp(0.0, 1.0),
            keeper: keeper,
          );
          s.pendingIsHomeChance = isHomeChance;
          return; // ここで一時停止。再開はresolvePendingChanceから。
        }
        if (defendingTeam.id == s.interactiveTeamId) {
          // 自クラブの守備側決定機: 積極的にタックルに行くか、カバーリングに
          // 専念するかを選べる(相手の得点成功率が変わる)。
          final baseAgainst = _applyFinisherQuality(scoreProb, scorer);
          final defenseMult = _defenseInstructionMultiplier(s.instruction);
          final defender = _pickChallenger(defendingLineup);
          final duelFactor = _defenderVsAttackerFactor(defender, scorer!);
          s.pending = PendingChanceDecision.defense(
            minute: minute,
            attacker: scorer,
            aggressiveChanceAgainst: (baseAgainst *
                    _aggressiveTackleReduction *
                    defenseMult *
                    duelFactor)
                .clamp(0.0, 1.0),
            safeChanceAgainst:
                (baseAgainst * _coverSpaceReduction * defenseMult * duelFactor)
                    .clamp(0.0, 1.0),
            defender: defender,
          );
          s.pendingIsHomeChance = isHomeChance;
          return; // ここで一時停止。再開はresolvePendingChanceから。
        }
        // 理論上どちらのチームもinteractiveTeamIdでない場合の安全策として、
        // 従来通りシュートとして即座に解決する。
        scoreProb = _applyFinisherQuality(scoreProb, scorer);
      }

      _finalizeChance(
        s,
        minute: minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: scorer,
        forcedAssist: forcedAssist,
        scoreProb: scoreProb,
        setPiece: setPiece,
      );
      s.chanceIndex++;
    }
  }

  /// [state.pending]をユーザーの選択([decision])に基づいて解決し、次の決定機
  /// (または半終了)まで進行を再開する。攻撃側の決定機でパスを選んでも
  /// つなげる味方がいない場合や、文脈に合わない選択(例えば守備側の決定機に
  /// シュートを渡した場合)は既定の安全な選択(シュート/カバーリング)に
  /// フォールバックする。この決定機の結果として実際に発生したイベント
  /// (得点・惜しいチャンス・積極的タックルによるカード)を返す。何も
  /// 起きなかった場合はnull。UI側の即時フィードバック表示に使う。
  static MatchEvent? resolvePendingChance(
    InteractiveHalfState state,
    ChanceDecision decision,
  ) {
    final pending = state.pending;
    if (pending == null) return null;
    final isHomeChance = state.pendingIsHomeChance!;
    final attackingTeam = isHomeChance ? state.home : state.away;
    final defendingTeam = isHomeChance ? state.away : state.home;
    final defendingLineup = isHomeChance ? state.awayLineup : state.homeLineup;

    state.pending = null;
    state.pendingIsHomeChance = null;

    MatchEvent? produced;
    if (pending.context == ChanceContext.attack) {
      Player finalScorer;
      Player? forcedAssist;
      double finalScoreProb;
      if (decision == ChanceDecision.pass && pending.passTarget != null) {
        finalScorer = pending.passTarget!;
        forcedAssist = pending.shooter;
        finalScoreProb = pending.passChance!;
      } else if (decision == ChanceDecision.longShot) {
        finalScorer = pending.shooter!;
        forcedAssist = null;
        finalScoreProb = pending.longShotChance!;
      } else {
        finalScorer = pending.shooter!;
        forcedAssist = null;
        finalScoreProb = pending.shootChance!;
      }
      produced = _finalizeChance(
        state,
        minute: pending.minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: finalScorer,
        forcedAssist: forcedAssist,
        scoreProb: finalScoreProb,
      );
    } else {
      // 守備側の決定機: attackerは相手チームの選手で、選んだ対応に応じた
      // 成功率でそのまま相手の攻撃を判定する。
      final aggressive = decision == ChanceDecision.aggressiveTackle;
      final finalScoreProb = aggressive
          ? pending.aggressiveChanceAgainst!
          : pending.safeChanceAgainst!;
      produced = _finalizeChance(
        state,
        minute: pending.minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: pending.attacker,
        forcedAssist: null,
        scoreProb: finalScoreProb,
      );
      if (aggressive && _rng.nextDouble() < _aggressiveTackleCardChance) {
        final tackler = pending.defender ??
            _pickCardTarget(defendingLineup,
                exclude: sentOffIds([...state.priorEvents, ...state.events]));
        if (tackler != null) {
          final isSecondYellow = tackler.yellowCardedThisMatch;
          final isRed =
              isSecondYellow || _rng.nextDouble() < _aggressiveTackleRedChance;
          if (!isRed) tackler.yellowCardedThisMatch = true;
          final cardEvent = MatchEvent(
            minute: pending.minute,
            teamId: defendingTeam.id,
            scorerName: tackler.name,
            scorerId: tackler.id,
            type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
          );
          state.events.add(cardEvent);
          if (isRed) {
            if (isHomeChance) {
              state.awayRedMinute = state.awayRedMinute == null
                  ? pending.minute
                  : min(state.awayRedMinute!, pending.minute);
            } else {
              state.homeRedMinute = state.homeRedMinute == null
                  ? pending.minute
                  : min(state.homeRedMinute!, pending.minute);
            }
          }
          // 得点が発生していなければ、カードをこの決定機の結果として扱う。
          produced ??= cardEvent;
        }
      }
    }

    state.lastDecisionEvent = produced;
    state.chanceIndex++;
    _advanceInteractiveHalf(state);
    return produced;
  }

  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = defaultHomeAdvantageFactor,
  }) {
    _maybeAutoAssignManMarker(home, lineupOf(away));
    _maybeAutoAssignManMarker(away, lineupOf(home));
    final first = simulateMinutes(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
    );
    applyHalfTimeFatigue(home: home, away: away, weather: weather);
    // ハーフタイムに、疲れた選手・負けているときの交代を監督が自動で行う。
    final sentOff = sentOffIds(first.events);
    final homePlan = applyHalfTimeSubstitutions(
      home,
      goalDiff: first.homeGoals - first.awayGoals,
      excludedIds: sentOff,
    );
    final awayPlan = applyHalfTimeSubstitutions(
      away,
      goalDiff: first.awayGoals - first.homeGoals,
      excludedIds: sentOff,
    );
    // 後半は、60〜75分の交代(ハーフタイムとは別の1回)を挟んで2つに分けて
    // 進める。前半に退場した選手は後半に出さず、数的不利も続ける。
    final lateMinute = rollLateSubMinute();
    final secondA = simulateMinutes(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: lateMinute,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
      priorEvents: first.events,
    );
    final beforeLate = [...first.events, ...secondA.events];
    final lateExcluded = {
      ...sentOffIds(beforeLate),
      for (final s in [...homePlan.swaps, ...awayPlan.swaps]) s.out.id,
    };
    final homeLatePlan = applyHalfTimeSubstitutions(
      home,
      goalDiff: first.homeGoals +
          secondA.homeGoals -
          first.awayGoals -
          secondA.awayGoals,
      maxSubs: substitutionsPerMatch - homePlan.swaps.length,
      excludedIds: lateExcluded,
      tiredFatigue: lateAutoSubTiredFatigue,
    );
    final awayLatePlan = applyHalfTimeSubstitutions(
      away,
      goalDiff: first.awayGoals +
          secondA.awayGoals -
          first.homeGoals -
          secondA.homeGoals,
      maxSubs: substitutionsPerMatch - awayPlan.swaps.length,
      excludedIds: lateExcluded,
      tiredFatigue: lateAutoSubTiredFatigue,
    );
    final secondB = simulateMinutes(
      home: home,
      away: away,
      startMinute: lateMinute + 1,
      endMinute: 90,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
      priorEvents: beforeLate,
    );
    final second = combineHalves(secondA, secondB);
    final allEvents = [...first.events, ...second.events];
    final homeGoals = first.homeGoals + second.homeGoals;
    final awayGoals = first.awayGoals + second.awayGoals;
    final homeShots = first.homeShots + second.homeShots;
    final awayShots = first.awayShots + second.awayShots;
    final homeShotsOnTarget =
        first.homeShotsOnTarget + second.homeShotsOnTarget;
    final awayShotsOnTarget =
        first.awayShotsOnTarget + second.awayShotsOnTarget;
    final totalChanceCount = first.chanceCount + second.chanceCount;
    final homePossession = totalChanceCount > 0
        ? ((first.possessionShareSum + second.possessionShareSum) /
                totalChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final awayPossession = 100 - homePossession;
    // 採点は今節の出場停止・負傷が反映される前(=今節の出場者がまだ
    // lineupOfに残っている状態)で算出する必要があるため、
    // applyPostMatchEffectsより先に計算する。
    final ratings = computePlayerRatings(
      home: home,
      away: away,
      events: allEvents,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      subbedOff: [
        ...homePlan.subbedOff,
        ...awayPlan.subbedOff,
        ...homeLatePlan.subbedOff,
        ...awayLatePlan.subbedOff,
      ],
    );
    applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: homeInjuryFactor,
      awayInjuryFactor: awayInjuryFactor,
      events: allEvents,
      weather: weather,
    );
    // 後の交代から戻す(後半の途中の交代の「元」はハーフタイムの交代のあと)。
    finishHalfTimeSubstitutions(homeLatePlan, events: allEvents);
    finishHalfTimeSubstitutions(awayLatePlan, events: allEvents);
    finishHalfTimeSubstitutions(homePlan, events: allEvents);
    finishHalfTimeSubstitutions(awayPlan, events: allEvents);

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
      weather: weather,
      homePossession: homePossession,
      awayPossession: awayPossession,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
    );
  }
}
