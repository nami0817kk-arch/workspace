import '../l10n/tr.dart';
import 'player.dart';

/// 選手の人柄の6つの軸(1〜20)。
///
/// 性格([PlayerPersonality])は1つの型でしかなく、同じ「野心家」でも
/// 中身が同じだった。軸に分けると「忠誠は高いが気性は荒い」のような
/// 人が出て、扱い方を考えることになる。
///
/// 保存はしない。選手の id と性格から毎回同じ値を作る(選手は数千人いる
/// ので、軸を6つ持たせるとセーブが重くなる)。
enum TraitAxis { drive, loyalty, professionalism, temperament, ambition, adaptability }

extension TraitAxisInfo on TraitAxis {
  String get label => switch (this) {
        TraitAxis.drive => Tr.pick('向上心', 'Drive'),
        TraitAxis.loyalty => Tr.pick('忠誠', 'Loyalty'),
        TraitAxis.professionalism => Tr.pick('プロ意識', 'Professionalism'),
        TraitAxis.temperament => Tr.pick('気性の荒さ', 'Temper'),
        TraitAxis.ambition => Tr.pick('野心', 'Ambition'),
        TraitAxis.adaptability => Tr.pick('順応', 'Adaptability'),
      };

  String get description => switch (this) {
        TraitAxis.drive =>
          Tr.pick('高いほど練習で伸びる。', 'The higher, the more he gains from training.'),
        TraitAxis.loyalty => Tr.pick('高いほど、不満があっても移籍を言い出しにくい。',
            'The higher, the less likely he is to ask for a move.'),
        TraitAxis.professionalism => Tr.pick('高いほど、不満が溜まりにくい。',
            'The higher, the less his mood sinks.'),
        TraitAxis.temperament => Tr.pick('高いほど、控えに置かれたときに荒れる。',
            'The higher, the worse he takes being benched.'),
        TraitAxis.ambition => Tr.pick('高いほど、下の部へ移りたがらず、移籍も言い出しやすい。',
            'The higher, the more he resists stepping down and the sooner he asks to leave.'),
        TraitAxis.adaptability => Tr.pick('高いほど、加入してすぐ馴染む(加入時の機嫌が良い)。',
            'The higher, the faster he settles after joining.'),
      };
}

class PlayerTraits {
  final Map<TraitAxis, int> values;
  const PlayerTraits(this.values);

  int operator [](TraitAxis a) => values[a] ?? 10;

  int get drive => this[TraitAxis.drive];
  int get loyalty => this[TraitAxis.loyalty];
  int get professionalism => this[TraitAxis.professionalism];
  int get temperament => this[TraitAxis.temperament];
  int get ambition => this[TraitAxis.ambition];
  int get adaptability => this[TraitAxis.adaptability];

  /// 練習の伸びに掛ける倍率(0.91〜1.10)。
  double get growthFactor => 0.9 + drive / 100;

  /// 控えに置かれたときの不満に掛ける倍率(0.82〜1.20)。
  double get benchFactor => 0.8 + temperament / 50;

  /// 不満が下がるときに掛ける倍率(1.18〜0.80)。
  double get gloomFactor => 1.2 - professionalism / 50;

  /// 移籍を言い出す線のずれ(野心で上がり、忠誠で下がる)。
  int get transferLineShift => (ambition - 10) ~/ 2 - (loyalty - 10) ~/ 2;

  /// 加入したときの機嫌(46〜75)。
  int get arrivalHappiness => 45 + (adaptability * 1.5).round();

  /// 下の部へ移るときの上乗せの強さ(野心10で1.0)。
  double get stepDownFactor => 0.5 + ambition / 20;

  static PlayerTraits of(String id, PlayerPersonality personality) {
    var h = id.codeUnits.fold<int>(23, (a, c) => (a * 31 + c) % 2147483647);
    int next() {
      h = (h * 1103515245 + 12345) % 2147483647;
      return 6 + h % 9; // 6〜14
    }

    final v = {for (final a in TraitAxis.values) a: next()};
    void add(TraitAxis a, int d) => v[a] = (v[a]! + d).clamp(1, 20);
    switch (personality) {
      case PlayerPersonality.professional:
        add(TraitAxis.professionalism, 5);
        add(TraitAxis.temperament, -3);
      case PlayerPersonality.ambitious:
        add(TraitAxis.ambition, 5);
        add(TraitAxis.loyalty, -3);
      case PlayerPersonality.temperamental:
      case PlayerPersonality.volatile:
        add(TraitAxis.temperament, 6);
        add(TraitAxis.professionalism, -3);
      case PlayerPersonality.loyal:
        add(TraitAxis.loyalty, 6);
        add(TraitAxis.ambition, -2);
      case PlayerPersonality.modelCitizen:
        add(TraitAxis.professionalism, 4);
        add(TraitAxis.temperament, -4);
        add(TraitAxis.loyalty, 2);
      case PlayerPersonality.resolute:
        add(TraitAxis.drive, 3);
        add(TraitAxis.temperament, -2);
      case PlayerPersonality.spirited:
        add(TraitAxis.drive, 2);
        add(TraitAxis.temperament, 2);
      case PlayerPersonality.determined:
      case PlayerPersonality.driven:
        add(TraitAxis.drive, 5);
      case PlayerPersonality.perfectionist:
        add(TraitAxis.drive, 3);
        add(TraitAxis.professionalism, 3);
        add(TraitAxis.temperament, 2);
      case PlayerPersonality.laidBack:
        add(TraitAxis.drive, -3);
        add(TraitAxis.professionalism, -2);
        add(TraitAxis.adaptability, 3);
      case PlayerPersonality.easilyDiscouraged:
        add(TraitAxis.drive, -2);
        add(TraitAxis.adaptability, -3);
      case PlayerPersonality.veryAmbitious:
        add(TraitAxis.ambition, 6);
      case PlayerPersonality.mercenary:
        add(TraitAxis.ambition, 4);
        add(TraitAxis.loyalty, -5);
      case PlayerPersonality.clubLegendType:
        add(TraitAxis.loyalty, 7);
      case PlayerPersonality.unambitious:
        add(TraitAxis.ambition, -5);
      case PlayerPersonality.lowDetermination:
        add(TraitAxis.drive, -4);
      case PlayerPersonality.fairlyProfessional:
        add(TraitAxis.professionalism, 2);
      default:
        break;
    }
    return PlayerTraits(v);
  }
}
