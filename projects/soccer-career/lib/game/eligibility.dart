import '../models/club.dart';
import '../models/country.dart';
import '../models/nationality.dart';
import 'world.dart';

/// 労働許可の審査結果。
class PermitCheck {
  const PermitCheck({
    required this.required,
    required this.points,
    required this.needed,
    required this.reasons,
  });

  /// そもそも許可が要るか。
  final bool required;

  final int points;
  final int needed;

  /// 何で点が付いた（付かなかった）か。画面に出す。
  final List<String> reasons;

  bool get granted => !required || points >= needed;

  String get summary => !required
      ? '労働許可は不要'
      : granted
          ? '労働許可: 要件を満たす（$points / $needed）'
          : '労働許可: 不足（$points / $needed）';
}

/// 移籍できるかの判定材料。
class EligibilityReport {
  const EligibilityReport({
    required this.foreign,
    required this.permit,
    required this.slotUsed,
    required this.slotLimit,
  });

  /// その国で外国人として扱われるか。
  final bool foreign;

  final PermitCheck permit;

  /// クラブが使っている外国人枠と上限。上限が null なら無制限。
  final int slotUsed;
  final int? slotLimit;

  bool get slotAvailable => slotLimit == null || slotUsed < slotLimit!;
  bool get canJoin => permit.granted && slotAvailable;

  String get slotSummary => !foreign
      ? '外国人枠の対象外'
      : slotLimit == null
          ? '外国人枠 制限なし'
          : '外国人枠 $slotUsed/$slotLimit';
}

/// 国籍と外国人枠の判定。
class Eligibility {
  const Eligibility._();

  /// その国でこの選手が外国人として扱われるか。
  ///
  /// 国籍を持っていれば当然に自国民。連盟内自由移動の国なら同じ連盟も自国扱い。
  /// 提携国も枠の外に置かれる。
  static bool isForeignIn(Nationality nationality, Country country) {
    if (nationality.has(country.id)) return false;

    final rule = country.foreignRule;
    if (rule.confederationFree) {
      final sameConfederation = nationality.all
          .map(World.byId)
          .any((c) => c.confederation == country.confederation);
      if (sameConfederation) return false;
    }
    if (rule.partnerCountries.any(nationality.has)) return false;
    return true;
  }

  /// 労働許可を審査する。
  static PermitCheck checkPermit({
    required Nationality nationality,
    required Country destination,
    required Country origin,
    required int caps,
    required int professionalYears,
    required int marketValue,
    required bool continentalExperience,
  }) {
    final rule = destination.permitRule;
    if (!rule.isRequired || !isForeignIn(nationality, destination)) {
      return const PermitCheck(
          required: false, points: 0, needed: 0, reasons: []);
    }

    var points = 0;
    final reasons = <String>[];

    // 代表での出場率。年に10試合を目安に見る。
    final expected = (professionalYears * 10).clamp(10, 200);
    final ratio = caps / expected;
    if (ratio >= rule.minCapsRatio) {
      points += rule.capsRatioPoints;
      reasons.add('代表での出場実績 +${rule.capsRatioPoints}');
    } else {
      reasons.add('代表での出場実績が足りない（$caps キャップ）');
    }

    if (origin.prestige >= rule.minLeaguePrestige) {
      points += rule.leaguePrestigePoints;
      reasons.add('${origin.name}リーグの格 +${rule.leaguePrestigePoints}');
    } else {
      reasons.add('${origin.name}リーグの格が足りない');
    }

    // 市場価値が高いほど「即戦力」と見なされる。
    if (marketValue >= 8000) {
      points += rule.feePoints;
      reasons.add('市場価値 +${rule.feePoints}');
    } else {
      reasons.add('市場価値が足りない');
    }

    if (continentalExperience) {
      points += rule.continentalPoints;
      reasons.add('大陸カップ出場歴 +${rule.continentalPoints}');
    }

    return PermitCheck(
      required: true,
      points: points,
      needed: rule.required,
      reasons: reasons,
    );
  }

  /// クラブが今どれだけ外国人枠を使っているか。
  ///
  /// 他の選手を1人ずつ持つとデータが重くなるので、クラブの強さと国の規則から
  /// もっともらしい人数を決める。強いクラブほど枠は埋まっている。
  static int usedSlots(Club club, Country country) {
    final limit = country.foreignRule.squadLimit;
    if (limit == null) return 0;
    final ratio = (club.strength - 30) / 62; // 0..1
    return (limit * ratio.clamp(0, 1) * 0.9).round().clamp(0, limit);
  }

  /// 加入できるかをまとめて判定する。
  static EligibilityReport report({
    required Nationality nationality,
    required Club club,
    required Country origin,
    required int caps,
    required int professionalYears,
    required int marketValue,
    required bool continentalExperience,
  }) {
    final country = World.byId(club.countryId);
    final foreign = isForeignIn(nationality, country);
    return EligibilityReport(
      foreign: foreign,
      permit: checkPermit(
        nationality: nationality,
        destination: country,
        origin: origin,
        caps: caps,
        professionalYears: professionalYears,
        marketValue: marketValue,
        continentalExperience: continentalExperience,
      ),
      slotUsed: foreign ? usedSlots(club, country) : 0,
      slotLimit: foreign ? country.foreignRule.squadLimit : null,
    );
  }
}
