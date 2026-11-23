import 'dart:math';

import '../models/player.dart';
import '../models/team.dart';
import 'division_strength.dart';
import 'lineup_utils.dart';
import 'player_generator.dart';
import 'training_engine.dart';

/// シーズン終了時の高齢選手の引退判定。
class RetirementEngine {
  static final Random _rng = Random();

  /// 32歳未満(31歳まで)は引退しない。32歳から年齢とともに引退確率が上がるが、
  /// 総合力が高い選手ほど現役を長く続けやすい。
  ///
  /// 衰えと同じポジションのずれ([TrainingEngine.positionPeakShift])で年齢を
  /// ずらして見る。キーパーは3年遅く(35歳から)、センターバックは1年遅く、
  /// 走力で勝負するサイドの選手は1年早く引退を考え始める。以前は全員同じで、
  /// 30代後半まで続けるのが普通のキーパーも32歳から引退していった
  /// (2026-11-23)。
  static double retirementChance(Player p) {
    if (p.age < 32) return 0.0;
    final age = p.age - TrainingEngine.positionPeakShift(p.position);
    final ageFactor = (age - 31) * 0.12;
    final skillRelief = (p.overall - 50).clamp(0, 40) * 0.005;
    return (ageFactor - skillRelief).clamp(0.0, 0.9);
  }

  /// チームの引退対象者を判定し、スカッドから除外して返す(呼び出し側で
  /// 殿堂入りの記録などに使う)。
  ///
  /// 借りている選手(ローンで加入)は対象にしない。籍は貸し元にあり、
  /// 季の切り替えで貸し元へ戻る。以前は借りた先で引退し、そのクラブの
  /// 殿堂に入っていた(2026-11-23)。
  static List<Player> resolveRetirements(Team team, {Random? rng}) {
    final r = rng ?? _rng;
    final retirees = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (p.isLoan) continue;
      if (r.nextDouble() < retirementChance(p)) {
        retirees.add(p);
      }
    }
    for (final p in retirees) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return retirees;
  }

  /// 所属なし(フリーエージェント)の選手の引退。クラブの選手と同じ確率で
  /// 振り、引退した選手を[pool]から外して返す。[keep]の選手(移籍の話を
  /// 進めている選手)は残す。以前は所属なしの選手は引退せず、何歳になっても
  /// 名簿に残っていた(2026-11-23)。
  static List<Player> retireFreeAgents(List<Player> pool,
      {Random? rng, Set<String> keep = const {}}) {
    final r = rng ?? _rng;
    final retirees = <Player>[
      for (final p in pool)
        if (!keep.contains(p.id) && r.nextDouble() < retirementChance(p)) p,
    ];
    final gone = retirees.toSet();
    pool.removeWhere(gone.contains);
    return retirees;
  }

  /// CPU/2部クラブの世代交代。ユーザークラブと違って移籍市場で自ら補強
  /// しないため、引退した分をそのまま若手選手で穴埋めして、スカッドが
  /// 何シーズンも高齢化し続けたり選手数が枯渇したりしないようにする。
  ///
  /// 補充選手は18歳前後で生成すると現在能力がポテンシャルの6割程度に
  /// なり(PlayerGeneratorの年齢係数)、退団者より大幅に弱い選手ばかりが
  /// 入ってチーム力が下がり続ける(10シーズン実測で平均総合力51→40の
  /// デフレを確認)。世代交代でリーグ全体が弱体化しないよう、20〜26歳の
  /// 「若手〜即戦力」で補充し、生成基準もチーム力より少し上乗せして
  /// 年齢係数による目減りを相殺する。
  ///
  /// [tier] はクラブのいる部。渡すと、補充の強さを部の水準へ少し寄せる
  /// ([cpuRecruitStrength])。
  static List<Player> resolveAndReplaceForCpu(Team team, {int? tier}) {
    final retirees = resolveRetirements(team);
    for (final p in retirees) {
      team.players.add(_generateCpuRecruit(team, p.position,
          replacedOverall: p.overall, tier: tier));
    }

    // 引退だけに頼るとスカッド全体が少しずつ高齢化し、衰えが若手の成長を
    // 上回ってリーグ平均戦力が漸減する(長期実測で確認)。実際のクラブの
    // ように、シーズンごとに30歳以上の下位1〜2人を放出して若手に入れ
    // 替え、世代のバランスを保つ。
    final elders = team.players.where((p) => p.age >= 30).toList()
      ..sort((a, b) => a.overall.compareTo(b.overall));
    final turnover = min(elders.length, 1 + _rng.nextInt(2));
    for (int i = 0; i < turnover; i++) {
      final leaver = elders[i];
      team.players.remove(leaver);
      team.startingXI.remove(leaver.id);
      if (team.captainId == leaver.id) team.captainId = null;
      if (team.viceCaptainId == leaver.id) team.viceCaptainId = null;
      team.players.add(_generateCpuRecruit(team, leaver.position,
          replacedOverall: leaver.overall, tier: tier));
    }
    // 抜けた先発の枠を組み直す。CPU のクラブは試合の前に先発を組み直さず、
    // 7人以上残っていればそのまま使われるため、以前は季の切り替えの後に
    // 先発9〜10人のまま1季ずっと試合をしていた(2026-11-23)。
    if (retirees.isNotEmpty || turnover > 0) LineupUtils.autoFill(team);
    return retirees;
  }

  /// CPUクラブの補充選手を生成する。年齢は21〜27歳(若手〜脂の乗り始め)、
  /// 生成基準はチーム力+6。PlayerGeneratorの年齢係数(この年齢帯で平均
  /// 約0.88)と掛け合わせると、入団時の現在能力がほぼチーム平均と釣り合い、
  /// リーグ平均戦力が世代交代のたびに漸減も漸増もしない(長期実測で調整)。
  /// CPUクラブの補充選手を、クラブの現在の水準に対してどれだけ上に振るか。
  /// 補充選手の強さはクラブの現在値を基準に決まるため、この上乗せがそのまま
  /// 「補充するたびにクラブが強くなり、次の補充がさらに強くなる」正の
  /// フィードバックの利得になる。かつては+6で、育成強化(CA4)によって
  /// 選手が実際にポテンシャルへ届くようになった結果、24シーズンでリーグ
  /// 平均が42.5→61.0と際限なく上がり続けていた(実測)。+3にすると最初の
  /// 10シーズンほどで+5前後まで上がったあと頭打ちになり、24シーズン
  /// 走らせても+6程度で安定する。0まで下げると今度は長期的に下がり始める
  /// (リーグデフレ)ため、この値が均衡点になる。
  static const int cpuRecruitStrengthBias = 3;

  /// 抜けた主力の穴を、どれだけその主力の水準で埋めるか(0〜1)。部が
  /// 分からないときと1部はこの値、2部は半分、3部は 0([replaceShareFor])。
  ///
  /// 以前は補充の強さがクラブの平均(控えと若手を含む)だけで決まり、
  /// 主力が抜けても平均並みの選手しか来なかった。上位のクラブほど主力と
  /// 平均の差が大きいので、1部の先発の水準が10季で 89→84 と下がり続け、
  /// 1部の強めのクラブを持つと連覇が続いた(2026-11-23 の実測)。
  /// 平均より強い選手が抜けたときは、平均とその選手の間の強さで埋める。
  /// 下の部まで同じにすると、3部の先発の水準が上がり続けた(上の部ほど
  /// 資金があり、主力の穴を主力級で埋められる)。
  static const double cpuRecruitReplaceShare = 0.5;

  /// [tier] 部の [cpuRecruitReplaceShare] の掛かり方。
  static double replaceShareFor(int? tier) => switch (tier) {
        null || 1 => cpuRecruitReplaceShare,
        2 => cpuRecruitReplaceShare / 2,
        _ => 0,
      };

  /// 補充の強さを、クラブのいる部の水準へどれだけ寄せるか(0〜1)。
  ///
  /// 寄せないと、昇格・降格で部をまたいだクラブがいつまでも元の部の
  /// 強さのままで、10季で1部の平均が 82→78 と下がり、3部の先発の水準は
  /// 71→75 と上がって、部の間の差が縮んでいった(上手に経営しても3部から
  /// 抜けられない理由の1つ。2026-11-23)。実在のクラブも、昇格すれば
  /// 予算が増えて上の部の水準の選手を獲り、降格すれば主力を手放す。
  static const double cpuRecruitTierPull = 0.5;

  /// CPU のクラブ[team]が補充する選手の強さ(PlayerGenerator の strengthTier)。
  ///
  /// クラブの平均に [cpuRecruitStrengthBias] を足したものが土台。抜けた
  /// 選手[replacedOverall]が平均より強ければ [replaceShareFor] だけ
  /// その選手へ寄せ、部[tier]が分かれば、その部の水準
  /// ([divisionTypicalSquadLevel])へ [cpuRecruitTierPull] だけ寄せる。
  static int cpuRecruitStrength(Team team, {int? replacedOverall, int? tier}) {
    final level = team.overallRating;
    var base = level.toDouble();
    if (replacedOverall != null && replacedOverall > level) {
      base += (replacedOverall - level) * replaceShareFor(tier);
    }
    if (tier != null) {
      base += (divisionTypicalSquadLevel(tier) - level) * cpuRecruitTierPull;
    }
    return base.round() + cpuRecruitStrengthBias;
  }

  /// 契約満了・仮契約で抜けた CPU クラブの選手の代わり(引退の補充と同じ形)。
  static Player cpuRecruitFor(Team team, Position position,
          {int? replacedOverall, int? tier}) =>
      _generateCpuRecruit(team, position,
          replacedOverall: replacedOverall, tier: tier);

  static Player _generateCpuRecruit(Team team, Position position,
          {int? replacedOverall, int? tier}) =>
      PlayerGenerator.generate(
        position: position,
        strengthTier: cpuRecruitStrength(team,
            replacedOverall: replacedOverall, tier: tier),
        ageOverride: 21 + _rng.nextInt(7),
      );
}
