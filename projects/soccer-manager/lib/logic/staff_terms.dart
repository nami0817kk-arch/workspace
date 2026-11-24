import 'dart:math';

import '../l10n/tr.dart';
import '../models/club_infrastructure.dart';
import '../models/staff_member.dart';

/// スタッフの契約の条件(2026-11-25 の第6段。選手と同じく交渉で決める)。
///
/// 金額はすべて5部の物差しの万円(画面では部の倍率を掛けて出す)。
class StaffTerms {
  const StaffTerms({
    required this.role,
    required this.weeklyWage,
    required this.years,
    required this.signingBonus,
  });

  final StaffRole role;
  final int weeklyWage;
  final int years;

  /// サイン料(一度だけ払う)。
  final int signingBonus;

  StaffTerms copyWith(
          {StaffRole? role, int? weeklyWage, int? years, int? signingBonus}) =>
      StaffTerms(
        role: role ?? this.role,
        weeklyWage: weeklyWage ?? this.weeklyWage,
        years: years ?? this.years,
        signingBonus: signingBonus ?? this.signingBonus,
      );
}

/// 交渉の返事。
enum StaffReplyKind { accept, wageLow, valueLow, yearsOff }

class StaffReply {
  const StaffReply(this.kind, {this.shortWeekly = 0});
  final StaffReplyKind kind;

  /// 足りない週俸(5部の物差しの万円)。
  final int shortWeekly;

  bool get accepted => kind == StaffReplyKind.accept;
}

/// スタッフの交渉の決まり。
class StaffTermsEngine {
  const StaffTermsEngine._();

  /// 契約の年数の選び方。
  static const yearChoices = [1, 2, 3, 4];

  /// 交渉が決裂するまでの、断られた提示の回数。
  static const maxRejections = 3;

  /// 本人が望む年数。年を取っているほど短く。候補は作られたときの年数。
  static int preferredYears(StaffMember s, {bool renewal = false}) {
    if (s.age >= 58) return 1;
    if (renewal) return s.age >= 48 ? 2 : 3;
    return s.contractYears.clamp(1, 4);
  }

  /// [s] を [role] に就けたときの能力(役職に効く能力の加重平均)。
  static double abilityAs(StaffMember s, StaffRole role) =>
      s.copyWith(role: role).roleAbility;

  /// 本人の要求。更新なら今の週俸から1割上げた額と相場の高い方。
  static StaffTerms asking(StaffMember s,
      {StaffRole? role, bool renewal = false}) {
    final r = role ?? s.role;
    final market = StaffMember.askingWage(abilityAs(s, r));
    final wage = renewal
        ? max((s.wage * 1.1).round(), market)
        : r == s.role
            ? s.wage
            : market;
    return StaffTerms(
      role: r,
      weeklyWage: max(1, wage),
      years: preferredYears(s, renewal: renewal),
      // サイン料は週俸の8週ぶん(だいたい2か月)。
      signingBonus: max(1, wage) * 8,
    );
  }

  /// 年あたりにならした値打ち(週俸+サイン料を年数で割った分)。
  static double _perWeek(StaffTerms t) =>
      t.weeklyWage + t.signingBonus / (52 * max(1, t.years));

  /// 提示 [offer] への返事。週俸は要求の9割を割ると断る。年数が望みから
  /// 1年ずれるごとに、求める値打ちが5%上がる。
  static StaffReply reply(StaffTerms ask, StaffTerms offer) {
    final minWage = (ask.weeklyWage * 0.9).ceil();
    if (offer.weeklyWage < minWage) {
      return StaffReply(StaffReplyKind.wageLow,
          shortWeekly: minWage - offer.weeklyWage);
    }
    final gap = (offer.years - ask.years).abs();
    final need = _perWeek(ask) * (1 + 0.05 * gap);
    final have = _perWeek(offer);
    if (have + 1e-9 < need) {
      return StaffReply(
          gap > 0 ? StaffReplyKind.yearsOff : StaffReplyKind.valueLow,
          shortWeekly: (need - have).ceil());
    }
    return const StaffReply(StaffReplyKind.accept);
  }

  /// 返事の文(代理人の帯)。[money] は週俸を年俸の字にする関数。
  static String replyText(StaffReply r, String Function(int weekly) money) =>
      switch (r.kind) {
        StaffReplyKind.accept =>
          Tr.pick('この条件で合意できます。', 'We have a deal on these terms.'),
        StaffReplyKind.wageLow => Tr.pick(
            '年俸が低すぎます。あと${money(r.shortWeekly)}は上げてください。',
            'The salary is too low. Add at least ${money(r.shortWeekly)}.'),
        StaffReplyKind.valueLow => Tr.pick(
            'もう少し出してください(年あたりあと${money(r.shortWeekly)})。年俸かサイン料で。',
            'A little more, please (${money(r.shortWeekly)} a year), in salary or a signing fee.'),
        StaffReplyKind.yearsOff => Tr.pick(
            '期間が希望と違います。その分を上乗せするか、期間を合わせてください(年あたりあと${money(r.shortWeekly)})。',
            'That is not the length he wants. Make up the difference (${money(r.shortWeekly)} a year) or match the length.'),
      };

  /// [role] に就ける役職か。監督は監督の経歴を持つ人だけ、監督の経歴を持つ
  /// 人は監督だけ。
  static List<StaffRole> rolesFor(StaffMember s) => s.manager != null
      ? const [StaffRole.manager]
      : [
          for (final r in StaffRole.values)
            if (r != StaffRole.manager) r,
        ];

  /// 人数が上限のとき、新しく雇うと入れ替わる人(役職でいちばん能力の
  /// 低い人。1人だけの役職なら主任)。空きがあれば null。
  static StaffMember? replacedBy(
      ClubInfrastructure infra, StaffRole role, int maxCount) {
    final members = infra.membersFor(role);
    if (members.length < maxCount) return null;
    if (!ClubInfrastructure.roleAllowsMany(role)) return infra.staffFor(role);
    return (members..sort((a, b) => a.roleAbility.compareTo(b.roleAbility)))
        .first;
  }
}
