part of 'game_state.dart';

/// スタッフの行き来: 他のクラブからの引き抜き、候補の月ごとの入れ替え、
/// 引退した選手をスタッフに雇う。
extension GameStateStaffMoves on GameState {
  /// 他のクラブから来ている、こちらのスタッフへの引き抜きの話。
  List<StaffOffer> get staffOffers => _save?.staffOffers ?? const [];

  /// [role]のスタッフへの引き抜きの話(無ければ null)。
  StaffOffer? staffOfferFor(StaffRole role) =>
      staffOffers.where((o) => o.role == role).firstOrNull;

  /// 引き抜きの話が来る、1か月あたりの確率。水準4以上のスタッフだけ狙われ、
  /// 水準が1つ上がるごとに2%ずつ上がる(水準8で16%)。
  static double poachChance(int level) =>
      level < 4 ? 0 : 0.08 + 0.02 * (level - 4);

  /// 返事を待つ日数。過ぎると、スタッフは移っていく。
  static const int staffOfferDays = 14;

  /// 残すときに上げる週俸の割合(%)。
  static const int staffKeepRaisePercent = 30;

  /// 日付が進んだぶん: 月が替われば候補を入れ替え、引き抜きの話を起こす。
  /// 期限の切れた話は、スタッフが移っていく。
  void _advanceStaffMoves(DateTime before, DateTime after) {
    final s = _save;
    if (s == null) return;
    for (final o in [...s.staffOffers]) {
      if (o.expiresOn.isBefore(after)) {
        _releaseStaff(o, answered: false);
      }
    }
    final monthChanged =
        before.year != after.year || before.month != after.month;
    if (!monthChanged) return;
    _refreshStaffCandidates();
    if (s.staffOffers.isNotEmpty) return; // 一度に1件まで
    final rng = GameState._offerRng;
    for (final role in StaffRole.values) {
      final st = s.infrastructure.staffFor(role);
      if (st == null || st.contractYears <= 0) continue;
      if (rng.nextDouble() >= poachChance(st.effectiveLevel)) continue;
      final club = _poachingClub(rng);
      if (club == null) return;
      s.staffOffers.add(StaffOffer(
        id: 'staffoffer-${after.year}-${after.month}-${role.name}',
        role: role,
        staffId: st.id,
        staffName: st.name,
        clubId: club.id,
        clubName: club.name,
        compensation: max(st.wage * 26,
            ManagerHrEngine.compensation(
                weeklyWage: st.wage, contractYears: st.contractYears)),
        raisePercent: staffKeepRaisePercent,
        expiresOn: after.add(const Duration(days: staffOfferDays)),
      ));
      _logNews(
          Tr.pick(
              '${club.name}が、${role.label}の${st.name}を引き抜きに来た。補償金を取って手放すか、昇給して残すかを${TransferWindowCalendar.formatMonthDay(after.add(const Duration(days: staffOfferDays)))}までに決めてください(決めなければ移っていく)。',
              '${club.name} want your ${role.label}, ${st.name}. Let him go for compensation or give him a raise to stay — decide by ${TransferWindowCalendar.formatMonthDay(after.add(const Duration(days: staffOfferDays)))} or he leaves.'),
          context: Tr.pick('スタッフ', 'Staff'));
      return;
    }
  }

  /// 引き抜きに来るクラブ(こちらより上か同じ部のクラブ)。
  Team? _poachingClub(Random rng) {
    final s = _save!;
    final tier = s.currentDivisionTier;
    final clubs = [
      for (final t in _worldTeams)
        if (t.id != s.userTeamId && (_tierOfClub(t.id) ?? 1) <= tier) t,
    ];
    if (clubs.isEmpty) return null;
    return clubs[rng.nextInt(clubs.length)];
  }

  /// 補償金を取って手放す。
  Future<bool> releaseStaffToOffer(String offerId) async {
    final o = staffOffers.where((x) => x.id == offerId).firstOrNull;
    if (o == null) return false;
    _releaseStaff(o, answered: true);
    _notify();
    await _persist();
    return true;
  }

  void _releaseStaff(StaffOffer o, {required bool answered}) {
    final s = _save!;
    s.staffOffers.remove(o);
    final st = s.infrastructure.staffFor(o.role);
    if (st == null || st.id != o.staffId) return;
    s.infrastructure.staff[o.role] = null;
    final comp = scaledMoney(o.compensation);
    if (comp > 0) _book(LedgerCategory.other, comp);
    _logNews(
        answered
            ? Tr.pick('${st.name}は${o.clubName}へ移った(補償金${formatMoney(comp)})。${o.role.label}は空席です。',
                '${st.name} has left for ${o.clubName} (compensation ${formatMoney(comp)}). The ${o.role.label} post is vacant.')
            : Tr.pick('返事が無かったので、${st.name}は${o.clubName}へ移った(補償金${formatMoney(comp)})。${o.role.label}は空席です。',
                'With no answer from you, ${st.name} has left for ${o.clubName} (compensation ${formatMoney(comp)}). The ${o.role.label} post is vacant.'),
        context: Tr.pick('スタッフ', 'Staff'));
  }

  /// 昇給して残す(週俸を上げ、契約を1年延ばす)。給与予算に収まらなければ
  /// 残せない(理由は[lastSigningBlockReason])。
  Future<bool> keepStaffWithRaise(String offerId) async {
    final s = _save;
    if (s == null) return false;
    lastSigningBlockReason = null;
    final o = staffOffers.where((x) => x.id == offerId).firstOrNull;
    if (o == null) return false;
    final st = s.infrastructure.staffFor(o.role);
    if (st == null || st.id != o.staffId) {
      s.staffOffers.remove(o);
      return false;
    }
    final newWage = (st.wage * (100 + o.raisePercent) / 100).round();
    if (!_wageBudgetAllowsSigning(scaledMoney(newWage - st.wage))) {
      _notify();
      return false;
    }
    st.wage = newWage;
    st.contractYears += 1;
    s.staffOffers.remove(o);
    _logNews(
        Tr.pick('${st.name}は昇給(+${o.raisePercent}%)と契約の延長で残ることになった。${o.clubName}の話は断った。',
            '${st.name} stays on a ${o.raisePercent}% raise and an extra year. ${o.clubName} have been turned down.'),
        context: Tr.pick('スタッフ', 'Staff'));
    _notify();
    await _persist();
    return true;
  }

  /// 引退した自クラブの選手から、スタッフの候補を足す(最大2人)。
  /// 元選手はクラブへの思いがあるので、相場の8割の週俸で来る。
  void _addFormerPlayerCandidates() {
    final s = _save!;
    final hired = {
      for (final st in s.infrastructure.staff.values)
        if (st?.formerPlayerId != null) st!.formerPlayerId!,
    };
    final pool = [
      for (final p in s.retiredLegends.reversed)
        if (!hired.contains(p.id) && p.overall >= 55) p,
    ].take(2);
    const roles = [
      StaffRole.headCoach,
      StaffRole.youthCoach,
      StaffRole.scout,
      StaffRole.fitnessCoach,
    ];
    for (final p in pool) {
      final h = p.id.codeUnits.fold<int>(17, (a, c) => (a * 31 + c) % 1000003);
      final role = roles[h % roles.length];
      // 現役の格が、そのまま教える力・見る力の下地になる。
      final base = (4 + (p.overall - 50) / 4).round().clamp(4, 16);
      final attrs = {
        StaffAttribute.coaching: (base + h % 3 - 1).clamp(1, 20),
        StaffAttribute.judging: (base + (h ~/ 3) % 3 - 1).clamp(1, 20),
        StaffAttribute.medical: (3 + (h ~/ 9) % 6).clamp(1, 20),
        StaffAttribute.motivating: (base + 1).clamp(1, 20),
      };
      final tmp = StaffMember(
          id: 'staff-former-${p.id}',
          name: p.name,
          age: p.age + 1,
          role: role,
          attributes: attrs,
          wage: 0);
      s.staffCandidates.add(StaffMember(
        id: tmp.id,
        name: tmp.name,
        age: tmp.age,
        role: role,
        attributes: attrs,
        wage: max(1, (StaffMember.askingWage(tmp.roleAbility) * 0.8).round()),
        contractYears: 2,
        specialty: switch (p.position.group) {
          PositionGroup.gk => StaffSpecialty.goalkeeping,
          PositionGroup.def => StaffSpecialty.defending,
          PositionGroup.att => StaffSpecialty.attacking,
          PositionGroup.mid => StaffSpecialty.balanced,
        },
        formerPlayerId: p.id,
      ));
    }
  }
}
