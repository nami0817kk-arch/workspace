import 'club_infrastructure.dart';

/// 他のクラブが、こちらのスタッフを引き抜きに来た話。
///
/// オーナーは「補償金を取って手放す」か「昇給して残す」を選ぶ。返事を
/// しないまま期限が来ると、契約の解除の条項でスタッフは移っていく
/// (補償金は入る)。
class StaffOffer {
  final String id;
  final StaffRole role;
  final String staffId;
  final String staffName;
  final String clubId;
  final String clubName;

  /// こちらに入る補償金(5部の物差しの万円。画面では部の物差しに直す)。
  final int compensation;

  /// 残すときに上げる週俸の割合(%)。
  final int raisePercent;

  /// この日を過ぎると、スタッフは移っていく。
  final DateTime expiresOn;

  const StaffOffer({
    required this.id,
    required this.role,
    required this.staffId,
    required this.staffName,
    required this.clubId,
    required this.clubName,
    required this.compensation,
    required this.raisePercent,
    required this.expiresOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'staffId': staffId,
        'staffName': staffName,
        'clubId': clubId,
        'clubName': clubName,
        'compensation': compensation,
        'raisePercent': raisePercent,
        'expiresOn': '${expiresOn.year.toString().padLeft(4, '0')}-'
            '${expiresOn.month.toString().padLeft(2, '0')}-'
            '${expiresOn.day.toString().padLeft(2, '0')}',
      };

  factory StaffOffer.fromJson(Map<String, dynamic> j) {
    final d = DateTime.tryParse(j['expiresOn'] as String? ?? '');
    return StaffOffer(
      id: j['id'] as String,
      role: StaffRole.values.firstWhere((r) => r.name == j['role'],
          orElse: () => StaffRole.headCoach),
      staffId: j['staffId'] as String? ?? '',
      staffName: j['staffName'] as String? ?? '',
      clubId: j['clubId'] as String? ?? '',
      clubName: j['clubName'] as String? ?? '',
      compensation: j['compensation'] as int? ?? 0,
      raisePercent: j['raisePercent'] as int? ?? 30,
      expiresOn: d == null ? DateTime(2027, 1, 1) : DateTime(d.year, d.month, d.day),
    );
  }
}
