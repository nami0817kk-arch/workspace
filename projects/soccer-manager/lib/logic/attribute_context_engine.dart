import '../models/attributes.dart';
import '../models/league.dart';
import '../models/player.dart';
import 'match_engine.dart';
import '../l10n/tr.dart';

/// この選手にとって、その能力値がなぜ効くのか。
enum AttributeReason {
  /// いま設定しているロールが見ている能力。
  role,

  /// 持っている特性の発動条件になっている能力。
  traitGate,

  /// そのポジションの総合力に大きく効く能力。
  position,
}

/// 「効いている能力」1件ぶん。
class KeyAttribute {
  final String key;
  final int value;
  final AttributeReason reason;

  /// なぜ効くのかの一言。
  final String why;

  /// 同じリーグ・同じポジション大分類での平均。比べる相手がいなければ null。
  final double? leagueAverage;

  const KeyAttribute({
    required this.key,
    required this.value,
    required this.reason,
    required this.why,
    this.leagueAverage,
  });

  /// リーグ平均に対する位置。
  String? get standingLabel {
    final avg = leagueAverage;
    if (avg == null) return null;
    final diff = value - avg;
    if (diff >= 12) return Tr.pick('リーグでも上位', 'Among the best in the league');
    if (diff >= 5) return Tr.pick('平均より上', 'Above average');
    if (diff <= -12) return Tr.pick('リーグでは見劣りする', 'Well below the league');
    if (diff <= -5) return Tr.pick('平均より下', 'Below average');
    return Tr.pick('平均的', 'About average');
  }
}

/// 42項目の能力値のうち、その選手で実際に効いているものを選び出す。
///
/// 能力値は全員に42項目ある。FW のタックルも GK のクロスも並んでいて、
/// **どれを見ればいいのかが分からない**。数字は出ているのに判断に使えない、
/// という状態だった。
///
/// ここでは推測しない。ロールが見ている能力(PlayerRole.keyAttributes)、
/// 特性の発動条件(MatchEngine.attributeGatedTraits)、総合力の内訳
/// (Player の attack/defense などの重み)——**実際に計算へ使われているもの**
/// だけを拾う。
class AttributeContextEngine {
  /// ポジション大分類ごとに、総合力へ強く効く能力。
  ///
  /// Player の attack / defense / technique / goalkeeping の重み付けから、
  /// 重み2以上のものを抜き出したもの。ここが動くと総合力が動く。
  static List<String> positionKeyAttributes(Position position) =>
      switch (position.group) {
        PositionGroup.gk => const [
            AttributeKeys.reflexes,
            AttributeKeys.handling,
            AttributeKeys.oneOnOnes,
            AttributeKeys.aerialReach,
          ],
        PositionGroup.def => const [
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.anticipation,
          ],
        PositionGroup.mid => const [
            AttributeKeys.passing,
            AttributeKeys.firstTouch,
            AttributeKeys.vision,
            AttributeKeys.technique,
          ],
        PositionGroup.att => const [
            AttributeKeys.finishing,
            AttributeKeys.longShots,
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
          ],
      };

  /// 同じリーグの同じポジション大分類での、その能力の平均。
  static double? leagueAverageFor(
    League league,
    PositionGroup group,
    String attribute,
  ) {
    var sum = 0;
    var count = 0;
    for (final team in league.teams) {
      for (final p in team.players) {
        if (p.position.group != group) continue;
        sum += p.attributeValue(attribute);
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  /// [player]で効いている能力を、理由つきで返す。
  ///
  /// 同じ能力が複数の理由で効くときは、より具体的な理由(特性 → ロール →
  /// ポジション)を1つだけ残す。同じ行が3回並んでも読みづらいだけ。
  static List<KeyAttribute> keyAttributesFor(Player player, {League? league}) {
    final byKey = <String, KeyAttribute>{};

    double? avg(String key) => league == null
        ? null
        : leagueAverageFor(league, player.position.group, key);

    void add(String key, AttributeReason reason, String why) {
      if (byKey.containsKey(key)) return; // 先に入れた理由の方が具体的
      byKey[key] = KeyAttribute(
        key: key,
        value: player.attributeValue(key),
        reason: reason,
        why: why,
        leagueAverage: avg(key),
      );
    }

    // 1. 特性の発動条件。届いていなければ特性がまるごと死ぬので最優先。
    final trait = player.trait;
    if (trait != null) {
      final gate = MatchEngine.attributeGatedTraits[trait];
      if (gate != null) {
        final reached = player.attributeValue(gate.attribute) >= gate.threshold;
        add(
          gate.attribute,
          AttributeReason.traitGate,
          reached
              ? Tr.pick('特性「${trait.label}」が発動する条件（達成済み）',
                  'Keeps his "${trait.label}" trait active')
              : Tr.pick('特性「${trait.label}」は${gate.threshold}以上で発動',
                  'His "${trait.label}" needs ${gate.threshold} here'),
        );
      }
    }

    // 2. ロールが見ている能力。
    for (final key in player.role.keyAttributes) {
      add(
        key,
        AttributeReason.role,
        Tr.pick('ロール「${player.role.label}」が見ている能力',
            'What the ${player.role.label} role is judged on'),
      );
    }

    // 3. そのポジションの総合力に効く能力。
    for (final key in positionKeyAttributes(player.position)) {
      add(
        key,
        AttributeReason.position,
        Tr.pick('${player.position.label}の総合力に強く効く',
            'Drives overall for a ${player.position.label}'),
      );
    }

    return byKey.values.toList();
  }
}
