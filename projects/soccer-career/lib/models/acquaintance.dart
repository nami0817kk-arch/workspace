import '../l10n/lang.dart';
import 'attributes.dart';

/// どういう縁で知り合ったか。
enum Bond {
  rival(Say('元競争相手', 'Former rival')),
  partner(Say('元相方', 'Former partner')),
  scorer(Say('得点王を争った', 'Scoring rival'));

  const Bond(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;
}

/// 関わった人。**続きを持たせるのは、この人たちだけ**（2026-11-22）。
///
/// 他クラブの名簿は保存せず、クラブIDと年から毎回作り直している
/// （`Squad.of`）。だから競った相手は移籍もせず、決まった曲線で
/// 歳を取るだけだった——翌年も同じ顔で同じクラブに居る。
/// 全員を保存に乗せると約12,000人になり端末に収まらないので、
/// **自分と関わった人だけ**を持って、毎季その人の続きを決める
/// （ユーザーが選んだ範囲）。
///
/// **名簿にも入る**（`Squad.of` の `known`）。移籍した先の名簿で
/// 同じ枠の1人と入れ替わるので、外国人枠・登録・先発の序列にも効く。
/// 「△△へ移籍」と書いたのに△△の名簿に居ない、を起こさないため。
class Acquaintance {
  const Acquaintance({
    required this.seat,
    required this.name,
    required this.position,
    required this.countryId,
    required this.born,
    required this.overall,
    required this.clubId,
    required this.bond,
    required this.metYear,
    this.ceiling = 0,
    this.retiredYear,
  });

  /// 最初に居た名簿の席（`クラブID#枠#世代`）。**この人を見分ける唯一の印。**
  ///
  /// 名前では見分けない——名簿の名前は組み合わせが有限で、
  /// 別のクラブに同じ名前の人が居ることがある。
  final String seat;
  final String name;
  final Position position;
  final String countryId;

  /// 生まれ年。歳はここから出す（名簿と同じ）。
  final int born;
  final int overall;

  /// いま居るクラブ。引退していても、最後のクラブを残す。
  final String clubId;
  final Bond bond;

  /// 知り合った年。上限を超えたら古い順に忘れる。
  final int metYear;

  /// 器。−6〜+6。**若いうちの伸びの上振れ／下振れ**になる。
  /// 知り合った時点で席から決める（引き直せない）。
  final int ceiling;

  /// 引退した年。引退していなければ null。
  final int? retiredYear;

  bool get retired => retiredYear != null;

  int ageIn(int year) => year - born;

  /// このクラブの名簿に関わるか。いま居るか、元はここの席だったか。
  bool touches(String id) => clubId == id || seat.startsWith('$id#');

  Acquaintance copyWith({
    int? overall,
    String? clubId,
    Bond? bond,
    int? retiredYear,
  }) => Acquaintance(
    seat: seat,
    name: name,
    position: position,
    countryId: countryId,
    born: born,
    overall: overall ?? this.overall,
    clubId: clubId ?? this.clubId,
    bond: bond ?? this.bond,
    metYear: metYear,
    ceiling: ceiling,
    retiredYear: retiredYear ?? this.retiredYear,
  );

  Map<String, dynamic> toJson() => {
    'seat': seat,
    'name': name,
    'position': position.name,
    'countryId': countryId,
    'born': born,
    'overall': overall,
    'clubId': clubId,
    'bond': bond.name,
    'metYear': metYear,
    'ceiling': ceiling,
    'retiredYear': retiredYear,
  };

  /// 読めないものは null を返し、呼ぶ側で捨てる。**1人が壊れていても
  /// キャリアは壊さない**（`SaveRepository.load` は投げると新規扱いにする）。
  static Acquaintance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final seat = json['seat'] as String?;
    final name = json['name'] as String?;
    if (seat == null || seat.isEmpty || name == null) return null;
    return Acquaintance(
      seat: seat,
      name: name,
      position: Position.values.any((p) => p.name == json['position'])
          ? Position.values.byName(json['position'] as String)
          : Position.cm,
      countryId: json['countryId'] as String? ?? '',
      born: json['born'] as int? ?? 2000,
      overall: json['overall'] as int? ?? 60,
      clubId: json['clubId'] as String? ?? '',
      bond: Bond.values.any((b) => b.name == json['bond'])
          ? Bond.values.byName(json['bond'] as String)
          : Bond.rival,
      metYear: json['metYear'] as int? ?? 0,
      ceiling: json['ceiling'] as int? ?? 0,
      retiredYear: json['retiredYear'] as int?,
    );
  }
}
