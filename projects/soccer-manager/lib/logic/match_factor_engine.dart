import '../models/player.dart';
import '../models/player_instruction.dart';
import '../models/team.dart';
import '../l10n/tr.dart';
import 'lineup_utils.dart';
import 'match_engine.dart';

/// 次の試合の結果に効いている要素と、その向き。
enum FactorDirection { good, bad, neutral }

/// 「いま何が効いているか」1件ぶん。
class MatchFactor {
  /// 要素の名前(例: 布陣の習熟度)。
  final String label;

  /// いまの状態を数値や語で表したもの(例: 82%)。
  final String value;

  /// なぜそれが効くのかの一言。
  final String detail;

  final FactorDirection direction;

  const MatchFactor({
    required this.label,
    required this.value,
    required this.detail,
    required this.direction,
  });
}

/// 試合前に、自チームの状態のうち結果に効いているものを並べる。
///
/// 戦術・習熟度・個別指示・疲労・士気と、結果に効く要素が増えたのに、
/// どれがどう効いているかを見る場所が無かった。負けた理由も勝った理由も
/// 分からないままでは、次に何を変えればいいか決められない。
///
/// ここでは**実際に試合計算が見ている値**だけを出す。それらしい指標を
/// 並べても、結果と結びついていなければ判断の材料にならない。
class MatchFactorEngine {
  /// 疲労がここを超えると、出来に響く選手として数える。
  static const int fatigueWarning = 70;

  /// 士気がここを下回ると、落ちている選手として数える。
  static const int moraleWarning = 40;

  static List<MatchFactor> analyze({
    required Team team,
    required List<Player> startingLineup,
  }) {
    final factors = <MatchFactor>[];

    // 1. 布陣の習熟度。チーム力に 0.88〜1.00 で掛かる。
    final fam = team.currentFamiliarity;
    factors.add(MatchFactor(
      label: Tr.pick('布陣の習熟度', 'Formation familiarity'),
      value: '$fam%',
      detail: Tr.pick(
          'チーム力 ×${team.familiarityFactor.toStringAsFixed(2)}。練習を重ねると上がる。',
          'Team strength x${team.familiarityFactor.toStringAsFixed(2)}. It climbs with training.'),
      direction: fam >= 80
          ? FactorDirection.good
          : fam <= 50
              ? FactorDirection.bad
              : FactorDirection.neutral,
    ));

    if (startingLineup.isEmpty) return factors;

    // 2. 疲労。出来(condition)に直接効く。
    final tired =
        startingLineup.where((p) => p.fatigue >= fatigueWarning).toList();
    final avgFatigue =
        startingLineup.fold<int>(0, (s, p) => s + p.fatigue) ~/
            startingLineup.length;
    factors.add(MatchFactor(
      label: Tr.pick('疲労', 'Fatigue'),
      value: Tr.pick('平均$avgFatigue / $fatigueWarning超が${tired.length}人',
          'avg $avgFatigue / ${tired.length} over $fatigueWarning'),
      detail: tired.isEmpty
          ? Tr.pick('重い選手はいない。', 'Nobody is carrying heavy legs.')
          : Tr.pick('${tired.take(3).map((p) => p.name).join('、')}が重い。休ませるか入れ替えを。',
              '${tired.take(3).map((p) => p.name).join(', ')} need a rest or a change.'),
      direction:
          tired.isEmpty ? FactorDirection.good : FactorDirection.bad,
    ));

    // 3. 士気。
    final lowMorale =
        startingLineup.where((p) => p.morale < moraleWarning).toList();
    final avgMorale = startingLineup.fold<int>(0, (s, p) => s + p.morale) ~/
        startingLineup.length;
    factors.add(MatchFactor(
      label: Tr.pick('士気', 'Morale'),
      value: Tr.pick('平均$avgMorale / 低いのが${lowMorale.length}人',
          'avg $avgMorale / ${lowMorale.length} low'),
      detail: lowMorale.isEmpty
          ? Tr.pick('落ちている選手はいない。', 'Nobody is down.')
          : Tr.pick('${lowMorale.take(3).map((p) => p.name).join('、')}が落ちている。',
              '${lowMorale.take(3).map((p) => p.name).join(', ')} are down.'),
      direction:
          lowMorale.isEmpty ? FactorDirection.good : FactorDirection.bad,
    ));

    // 4. 本職以外での起用。慣れていない位置は貢献度が下がる。
    //    試合計算が使っているのと同じ割り当て(LineupUtils)を見る。
    final slotById = LineupUtils.assignedSlotByPlayerId(team);
    final outOfPosition = startingLineup.where((p) {
      final slot = slotById[p.id];
      return slot != null &&
          MatchEngine.positionFitMultiplier(p, slot) < 1.0;
    }).toList();
    if (outOfPosition.isNotEmpty) {
      factors.add(MatchFactor(
        label: Tr.pick('本職以外での起用', 'Out of position'),
        value: Tr.pick('${outOfPosition.length}人', '${outOfPosition.length}'),
        detail: Tr.pick(
            '${outOfPosition.take(3).map((p) => p.name).join('、')}が慣れない位置。貢献度が落ちる。',
            '${outOfPosition.take(3).map((p) => p.name).join(', ')} are playing out of position.'),
        direction: FactorDirection.bad,
      ));
    }

    // 5. 個別指示。攻守どちらに寄せているかが分かる。
    final forward = startingLineup
        .where((p) => p.instruction == PlayerInstruction.getForward)
        .length;
    final back = startingLineup
        .where((p) => p.instruction == PlayerInstruction.stayBack)
        .length;
    if (forward > 0 || back > 0) {
      factors.add(MatchFactor(
        label: Tr.pick('個別指示の偏り', 'Instruction balance'),
        value: Tr.pick('前がかり$forward人 / 後ろ残り$back人',
            '$forward forward / $back back'),
        detail: forward > back
            ? Tr.pick('攻撃に寄せている。守備の枚数が減る。',
                'Weighted to attack, at the cost of defensive numbers.')
            : back > forward
                ? Tr.pick('守備に寄せている。攻撃に人数を割けない。',
                    'Weighted to defence, with fewer bodies going forward.')
                : Tr.pick('攻守の枚数は釣り合っている。', 'Attack and defence are balanced.'),
        direction: FactorDirection.neutral,
      ));
    }

    return factors;
  }

}
