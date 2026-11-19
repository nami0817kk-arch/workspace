import '../logic/player_generator.dart';
import 'player.dart';

/// 自クラブがいない部や他国のクラブの選手を、軽い形で保存する。
///
/// 全クラブ(数千人)の選手を細かい能力値ごと保存すると、セーブが数MBになる。
/// そこで名前・年齢・ポジション・能力の目安・潜在・契約などだけを残し、
/// 細かい能力値は、選手の id から決まる種で作り直す。同じ軽い形からは、
/// 何度読み込んでも同じ選手になる(総合力は保存した値にそろえる)。
///
/// 並び: [id, 名前, 年齢, ポジション, 潜在, 総合力, 週俸, 満了の年(旧セーブは契約年数),
///        印(1=国内育成, 2=ユース出身), 性格, 成長の型, 特性(-1=無し),
///        怪我のしやすさ, 通算出場, 通算得点, 大会で上がった価値(%), 大会明けの休み(1/0)]
/// 最後の2つは後から足した。無いセーブは0として読む。
class PlayerStub {
  static List<Object> encode(Player p) => [
        p.id,
        p.name,
        p.age,
        p.position.index,
        p.potential,
        p.overall,
        p.wage,
        p.contractEndYear,
        (p.homegrown ? 1 : 0) | (p.academyGraduate ? 2 : 0),
        p.personality.index,
        p.growthType.index,
        p.trait?.index ?? -1,
        p.injuryProneness,
        p.careerAppearances,
        p.careerGoals,
        p.tournamentBoostPct,
        p.onTournamentLeave ? 1 : 0,
      ];

  /// 8番目(添字7)の値を満了の年に直す。旧セーブは残り年数(0〜10)を
  /// 入れていたので、年に見えない小さな値は年数として換算する
  /// ([Player.contractEndYearFromYears]と同じ式)。
  static int contractEndYearOf(int raw) =>
      raw < 1000 ? Player.contractEndYearFromYears(raw) : raw;

  /// id から決まる種。文字列の hashCode は実行ごとに同じとは限らないので、
  /// 文字コードから自前で作る。
  static int seedOf(String id) {
    var h = 17;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static Player decode(List<dynamic> s) {
    final id = s[0] as String;
    final position = Position.values[(s[3] as int).clamp(0, Position.values.length - 1)];
    final potential = s[4] as int;
    final targetOverall = s[5] as int;
    final age = s[2] as int;
    final base = PlayerGenerator.withSeed(
      seedOf(id),
      () => PlayerGenerator.generate(
        position: position,
        strengthTier: potential,
        ageOverride: age,
      ),
    );
    final json = base.toJson();
    final flags = s[8] as int;
    final traitIndex = s[11] as int;
    json
      ..['id'] = id
      ..['name'] = s[1] as String
      ..['age'] = age
      ..['potential'] = potential
      ..['wage'] = s[6] as int
      ..['contractEndYear'] = contractEndYearOf(s[7] as int)
      ..['homegrown'] = flags & 1 == 1
      ..['academyGraduate'] = flags & 2 == 2
      ..['personality'] = PlayerPersonality
          .values[(s[9] as int).clamp(0, PlayerPersonality.values.length - 1)]
          .name
      ..['growthType'] = PlayerGrowthType
          .values[(s[10] as int).clamp(0, PlayerGrowthType.values.length - 1)]
          .name
      ..['trait'] = traitIndex < 0 || traitIndex >= PlayerTrait.values.length
          ? null
          : PlayerTrait.values[traitIndex].name
      ..['injuryProneness'] = s[12] as int
      ..['careerAppearances'] = s[13] as int
      ..['careerGoals'] = s[14] as int
      ..['tournamentBoostPct'] = s.length > 15 ? s[15] as int : 0
      ..['onTournamentLeave'] = s.length > 16 && s[16] == 1;
    final player = Player.fromJson(json);
    matchOverall(player, targetOverall);
    return player;
  }

  /// 能力値を一律にずらして、総合力を[target]にそろえる(1〜99の範囲で)。
  /// 他の部の選手の成長・衰えにも使う。
  static void matchOverall(Player p, int target) {
    for (var i = 0; i < 6 && p.overall != target; i++) {
      final delta = target - p.overall;
      for (final key in p.attributes.keys.toList()) {
        p.attributes[key] = (p.attributes[key]! + delta).clamp(1, 99);
      }
    }
    // 一律にずらすと、上限(99)・下限(1)に張り付いた能力が動かず、総合98の
    // 選手が97にしかならないことがあった(読み戻すたびに力が落ちる)。
    // 届かないときは、まだ動かせる能力だけを1ずつ動かす。
    for (var guard = 0; guard < 400 && p.overall != target; guard++) {
      final up = p.overall < target;
      final keys = [
        for (final e in p.attributes.entries)
          if (up ? e.value < 99 : e.value > 1) e.key,
      ]..sort((a, b) => up
          ? p.attributes[a]!.compareTo(p.attributes[b]!)
          : p.attributes[b]!.compareTo(p.attributes[a]!));
      if (keys.isEmpty) break;
      final k = keys.first;
      p.attributes[k] = p.attributes[k]! + (up ? 1 : -1);
    }
  }
}
