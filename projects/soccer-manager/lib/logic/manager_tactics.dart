import '../l10n/tr.dart';
import '../models/attributes.dart';
import '../models/manager_profile.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'style_engine.dart';
import 'tactics_ai.dart';

/// 監督の考え方から決まる戦い方の基本形。
///
/// プレッシング・ライン・幅・テンポ(0-100)と、選ぶ戦術スタイルの候補、
/// リードした終盤に逃げ切るかどうか。オーナーは試合に手を出さないので、
/// これを監督が毎節チームに当てる([ManagerTactics.apply])。
class ManagerTacticsPlan {
  final int pressing;
  final int lineHeight;
  final int width;
  final int tempo;

  /// この監督が使う戦術スタイル(好みの順)。現実的な監督は全部から選ぶ。
  final List<TacticalStyle> styles;

  /// リードして終盤を迎えたら逃げ切るか。
  final bool holdLeadLate;

  const ManagerTacticsPlan({
    required this.pressing,
    required this.lineHeight,
    required this.width,
    required this.tempo,
    required this.styles,
    required this.holdLeadLate,
  });
}

/// 雇っている監督が、考え方と水準から試合の戦い方を決める。
///
/// 値は試合エンジンの倍率(MatchEngine の lineHeightAttackFactor ほか)の上で、
/// 同じ戦力どうしなら考え方で勝率が大きく偏らないように選んである
/// (前がかりな考え方は攻撃が上がるぶん守備と疲労で払い、守る考え方は
/// その逆)。測り方は test/manager_tactics_test.dart の釣り合いの試験。
class ManagerTactics {
  /// 相手に合わせてラインと勢いを変え始める水準。
  static const int adjustToOpponentLevel = 5;

  /// 相手の戦術スタイルに相性の良い型をぶつけ始める水準。
  static const int counterPickLevel = 6;

  /// 好みの型の中から、いまの選手に合う型を選び始める水準。これより低い
  /// 監督は、いちばん好きな型が使えるときだけ使い、使えなければ柔軟で戦う。
  static const int fitPickLevel = 3;

  static ManagerTacticsPlan planFor(ManagerStyle style) => switch (style) {
        ManagerStyle.attacking => const ManagerTacticsPlan(
            pressing: 66,
            lineHeight: 56,
            width: 44,
            tempo: 54,
            styles: [
              TacticalStyle.gegenpress,
              TacticalStyle.wingPlay,
              TacticalStyle.possession,
            ],
            holdLeadLate: false,
          ),
        ManagerStyle.pragmatic => const ManagerTacticsPlan(
            pressing: 50,
            lineHeight: 50,
            width: 50,
            tempo: 50,
            styles: [
              TacticalStyle.possession,
              TacticalStyle.counter,
              TacticalStyle.gegenpress,
              TacticalStyle.wingPlay,
              TacticalStyle.longBall,
            ],
            holdLeadLate: true,
          ),
        ManagerStyle.defensive => const ManagerTacticsPlan(
            pressing: 46,
            lineHeight: 40,
            width: 58,
            tempo: 62,
            styles: [TacticalStyle.counter, TacticalStyle.longBall],
            holdLeadLate: true,
          ),
        ManagerStyle.youth => const ManagerTacticsPlan(
            pressing: 62,
            lineHeight: 54,
            width: 44,
            tempo: 56,
            styles: [
              TacticalStyle.gegenpress,
              TacticalStyle.possession,
              TacticalStyle.counter,
            ],
            holdLeadLate: false,
          ),
      };

  /// [team] に、監督の考え方 [style] と水準 [level] で戦い方を当てる。
  /// 水準が高い監督は、相手 [opponent] を見てラインと戦術スタイルを変える。
  /// 構え(メンタリティ)と先発はここでは決めない(呼ぶ側の仕事)。
  static void apply(
    Team team, {
    required ManagerStyle style,
    required int level,
    Team? opponent,
  }) {
    final plan = planFor(style);
    var pressing = plan.pressing;
    var lineHeight = plan.lineHeight;
    var width = plan.width;
    var tempo = plan.tempo;
    if (opponent != null && level >= adjustToOpponentLevel) {
      final diff = team.overallRating - opponent.overallRating;
      if (diff <= -CpuTacticsAI.mildGapThreshold) {
        // 格上には、裏を取られないようにラインを下げ、奪ったら速く出る。
        lineHeight -= 6;
        tempo += 6;
      } else if (diff >= CpuTacticsAI.mildGapThreshold) {
        // 格下には、ラインを上げて押し込み、前から奪いにいく。
        lineHeight += 6;
        pressing += 5;
      }
      // 相手の前線が速ければ、ラインを少し下げる。
      final pace = _attackersPace(opponent);
      if (pace >= 70) lineHeight -= 4;
    }
    team.pressing = pressing.clamp(0, 100);
    team.lineHeight = lineHeight.clamp(0, 100);
    team.width = width.clamp(0, 100);
    team.tempo = tempo.clamp(0, 100);
    team.tacticalStyle = styleFor(
      team,
      style: style,
      level: level,
      opponentStyle: opponent == null || level < counterPickLevel
          ? null
          : CpuTacticsAI.styleFor(opponent),
    );
    team.holdLeadLate = plan.holdLeadLate;
    // 試合の頭から時間を使う指示は出さない(逃げ切りは終盤にリードした
    // ときだけ。旧セーブで入っていた値もここで消える)。
    team.timeWastingMode = false;
  }

  /// 監督が選ぶ戦術スタイル。CPU と同じ物差し(StyleEngine の適性と
  /// CpuTacticsAI の下限)で、好みの型の中から選ぶ。どれも下限に届かなければ
  /// 柔軟で戦う。[opponentStyle] が分かっていれば、相性で勝つ型を優先し、
  /// 負ける型は避ける。
  static TacticalStyle styleFor(
    Team team, {
    required ManagerStyle style,
    required int level,
    TacticalStyle? opponentStyle,
  }) {
    const threshold = CpuTacticsAI.styleSuitabilityThreshold;
    final prefs = planFor(style).styles;
    if (level < fitPickLevel) {
      final first = prefs.first;
      return StyleEngine.suitability(team, first) >= threshold
          ? first
          : TacticalStyle.flexible;
    }
    var best = TacticalStyle.flexible;
    var bestScore = threshold;
    for (final s in prefs) {
      final fit = StyleEngine.suitability(team, s);
      if (fit < threshold) continue;
      var score = fit;
      if (opponentStyle != null) {
        // 相性で負ける型ははっきり避け、勝てる型は少しだけ選びやすくする
        // (勝てる型を強く追うと、水準の高い監督だけが一方的に勝ち越す)。
        final m = StyleEngine.matchupAttackFactor(s, opponentStyle);
        if (m < 1) score -= 0.12;
        if (m > 1) score += 0.03;
      }
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  /// [team] の前線(FW)の平均スピード。
  static double _attackersPace(Team team) {
    final front = team.players
        .where((p) => p.position.group == PositionGroup.att)
        .toList();
    if (front.isEmpty) return 50;
    final sum = front.fold<int>(
      0,
      (s, p) => s + p.attributeValue(AttributeKeys.pace),
    );
    return sum / front.length;
  }

  /// キャプテンにふさわしい度合い。統率力を最も重く、年齢(経験)・
  /// 通算出場・実力を足す。肩書は数えない(今のキャプテンを贔屓しない)。
  static double captaincyScore(Player p) =>
      p.attributeValue(AttributeKeys.leadership) * 1.0 +
      (p.age.clamp(18, 32) - 18) * 1.0 +
      (p.careerAppearances.clamp(0, 300)) / 30 +
      p.overall * 0.3;

  /// キャプテンになれる選手(借りている選手・貸し出している選手は除く)。
  static bool canCaptain(Player p) => !p.isLoan && !p.isLoanedOut;

  /// 監督がキャプテンと副キャプテンを指名する。変わったら true。
  static bool appointCaptains(Team team) {
    final candidates = team.players.where(canCaptain).toList()
      ..sort((a, b) {
        final c = captaincyScore(b).compareTo(captaincyScore(a));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final captain = candidates.isEmpty ? null : candidates[0].id;
    final vice = candidates.length < 2 ? null : candidates[1].id;
    final changed = team.captainId != captain || team.viceCaptainId != vice;
    team.captainId = captain;
    team.viceCaptainId = vice;
    return changed;
  }

  /// いまのキャプテンが空き・退団・貸し出しなどで務められないか。
  static bool needsNewCaptain(Team team) {
    final id = team.captainId;
    if (id == null) return true;
    for (final p in team.players) {
      if (p.id == id) return !canCaptain(p);
    }
    return true;
  }

  /// 監督の画面に出す戦い方の説明(1行目: 守り方と速さ、2行目: 戦術の型と
  /// リードしたときの采配)。
  static String summary(ManagerStyle style) {
    final plan = planFor(style);
    final shape = switch (style) {
      ManagerStyle.attacking => Tr.pick(
          '高い位置からの強いプレスと高めのライン・速いテンポで、中央から前へ出る',
          'Presses hard and high, holds a high line and goes quickly through the middle',
        ),
      ManagerStyle.pragmatic => Tr.pick(
          'プレス・ライン・テンポは中くらいで、相手に合わせやすい',
          'Middle-of-the-road pressing, line and tempo, easy to adapt',
        ),
      ManagerStyle.defensive => Tr.pick(
          '低いラインと弱めのプレスで守りを固め、奪ったら速いテンポでサイドから速攻',
          'Sits deep with a low line and gentle press, then breaks quickly down the flanks',
        ),
      ManagerStyle.youth => Tr.pick(
          '前からのプレスと速いテンポで、中央からよく走る',
          'Presses from the front and plays at a quick tempo through the middle, lots of running',
        ),
    };
    final styles = style == ManagerStyle.pragmatic
        ? Tr.pick('戦術は選手にいちばん合う型', 'whichever style suits the squad best')
        : Tr.pick(
            '戦術は${plan.styles.map((s) => s.label).join('・')}から選ぶ',
            'chooses from ${plan.styles.map((s) => s.label).join(', ')}',
          );
    final lead = plan.holdLeadLate
        ? Tr.pick('リードした終盤は逃げ切る', 'shuts up shop when ahead late on')
        : Tr.pick('リードしても攻め続ける', 'keeps attacking even when ahead');
    return Tr.pick(
      '$shape。\n$styles。$lead。',
      '$shape.\n${_cap(styles)}; $lead.',
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
