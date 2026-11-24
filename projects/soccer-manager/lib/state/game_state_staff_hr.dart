part of 'game_state.dart';

/// スタッフの人事(2026-11-25 の第6段。FM に寄せた)。
///
/// - 一部の役職は何人か雇える(上限は部と施設。効き目は人数で逓減)。
/// - 雇うのも更新するのも、選手と同じく条件の交渉で決める。
/// - 人事を SD(いなければ監督)に任せられる。任せると空いた役職を埋め、
///   満了する人の更新も判断する。オーナーは週俸の総額の上限だけ決める。
extension GameStateStaffHr on GameState {
  /// [role] に雇える人数の上限。
  int maxStaffFor(StaffRole role) =>
      _save?.infrastructure
          .maxStaffFor(role, divisionTier: _save!.currentDivisionTier) ??
      1;

  /// [role] に就いている全員(主任が先)。
  List<StaffMember> staffMembersFor(StaffRole role) =>
      _save?.infrastructure.membersFor(role) ?? const [];

  /// 雇っている人を id で探す。
  StaffMember? staffById(String id) => _save?.infrastructure.allStaff
      .where((s) => s.id == id)
      .firstOrNull;

  /// [role] の仕事の質(1-8。何人かいればまとめた値)。
  int staffRoleLevel(StaffRole role) =>
      _save?.infrastructure.staffLevel(role) ?? 1;

  /// 候補[c]を[role]に雇うと入れ替わる人(人数が上限のとき)。
  StaffMember? staffReplacedBy(StaffRole role) {
    final s = _save;
    if (s == null) return null;
    return StaffTermsEngine.replacedBy(
        s.infrastructure, role, maxStaffFor(role));
  }

  /// 交渉で決めた条件[terms]で候補[candidateId]を雇う。
  ///
  /// 空きがあれば加え、上限なら役職でいちばん能力の低い人(1人の役職なら
  /// 前任)と入れ替わる(違約金を払う)。サイン料・補償金・違約金はすぐ払う。
  Future<bool> hireStaffOnTerms(String candidateId, StaffTerms terms) async {
    final s = _save;
    if (s == null) return false;
    lastSigningBlockReason = null;
    final idx = s.staffCandidates.indexWhere((c) => c.id == candidateId);
    if (idx < 0) return false;
    final cand = s.staffCandidates[idx];
    if (!StaffTermsEngine.rolesFor(cand).contains(terms.role)) return false;
    final replaced = staffReplacedBy(terms.role);
    final severance = staffSeveranceFor(replaced);
    final compensation = scaledMoney(cand.manager?.compensation ?? 0);
    final bonus = scaledMoney(terms.signingBonus);
    final upfront = severance + compensation + bonus;
    if (upfront > 0 && s.budget < upfront) {
      lastSigningBlockReason = Tr.pick(
          '資金が足りません(サイン料${formatMoney(bonus)}・補償金${formatMoney(compensation)}・違約金${formatMoney(severance)})。',
          'You cannot afford it (signing fee ${formatMoney(bonus)}, compensation ${formatMoney(compensation)}, severance ${formatMoney(severance)}).');
      _notify();
      return false;
    }
    if (!_wageBudgetAllowsSigning(
        scaledMoney(terms.weeklyWage - (replaced?.wage ?? 0)),
        isPlayer: false)) {
      _notify();
      return false;
    }
    final hired = cand.copyWith(
        role: terms.role, wage: terms.weeklyWage, contractYears: terms.years)
      ..hiredOn = SeasonCalendar.dateOnly(today);
    if (replaced != null) s.infrastructure.removeMember(replaced.id);
    s.infrastructure.addMember(hired);
    s.staffCandidates.removeAt(idx);
    _dropStaleStaffOffers();
    if (severance > 0) _book(LedgerCategory.staffWages, -severance);
    if (bonus > 0) _book(LedgerCategory.staffWages, -bonus);
    if (hired.role == StaffRole.manager) _onManagerHired(hired, compensation);
    final lead = s.infrastructure.staffFor(hired.role)?.id == hired.id;
    _logNews(
      replaced != null
          ? Tr.pick(
              '${replaced.name}が${replaced.role.label}を退任し、${hired.name}が就任しました。',
              '${replaced.name} leaves as ${replaced.role.label}; ${hired.name} takes over.')
          : lead
              ? Tr.pick('${hired.name}が${hired.role.label}に就任しました。',
                  '${hired.name} joins as ${hired.role.label}.')
              : Tr.pick('${hired.name}が${hired.role.label}に加わりました(${s.infrastructure.headcount(hired.role)}人目)。',
                  '${hired.name} joins the ${hired.role.label}s (number ${s.infrastructure.headcount(hired.role)}).'),
      context: Tr.pick('スタッフ', 'Staff'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 雇っている[staffId]の契約を、交渉で決めた条件[terms]で結び直す
  /// (年数は今日から数え直す)。サイン料はすぐ払う。
  Future<bool> renewStaffOnTerms(String staffId, StaffTerms terms) async {
    final s = _save;
    if (s == null) return false;
    lastSigningBlockReason = null;
    final st = staffById(staffId);
    if (st == null) return false;
    final bonus = scaledMoney(terms.signingBonus);
    if (bonus > s.budget) {
      lastSigningBlockReason = Tr.pick(
          "サイン料${formatMoney(bonus)}に資金が足りません。",
          "You cannot afford the signing fee (${formatMoney(bonus)}).");
      _notify();
      return false;
    }
    if (!_wageBudgetAllowsSigning(scaledMoney(terms.weeklyWage - st.wage),
        isPlayer: false)) {
      _notify();
      return false;
    }
    st.wage = terms.weeklyWage;
    st.contractYears = terms.years;
    if (bonus > 0) _book(LedgerCategory.staffWages, -bonus);
    _logNews(
      Tr.pick('${st.name}(${st.role.label})と契約を結び直した(${terms.years}年)。',
          '${st.name} (${st.role.label}) has signed a new ${Tr.plural(terms.years, 'year')} deal.'),
      context: Tr.pick('スタッフ', 'Staff'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 交渉が決裂した候補を、今月の候補から外す。
  Future<void> withdrawStaffCandidate(String candidateId) async {
    final s = _save;
    if (s == null) return;
    s.staffCandidates.removeWhere((c) => c.id == candidateId);
    _notify();
    await _persist();
  }

  /// [staffId]を解任する(違約金を払う)。主任なら部下が上がる。
  Future<bool> dismissStaffMember(String staffId) async {
    final s = _save;
    if (s == null) return false;
    final st = staffById(staffId);
    if (st == null) return false;
    final severance = staffSeveranceFor(st);
    s.infrastructure.removeMember(staffId);
    _dropStaleStaffOffers();
    if (severance > 0) _book(LedgerCategory.staffWages, -severance);
    _logNews(
      Tr.pick('${st.name}が${st.role.label}を退任しました。',
          '${st.name} leaves his post as ${st.role.label}.'),
      context: Tr.pick('スタッフ', 'Staff'),
    );
    _notify();
    await _persist();
    return true;
  }

  // ---- 人事の委託 ----

  /// 人事を任せる相手(SD、いなければ監督)。どちらもいなければ null。
  StaffMember? get staffDelegate =>
      staffFor(StaffRole.sportingDirector) ?? staffFor(StaffRole.manager);

  bool get staffDelegated => _save?.staffDelegated ?? false;

  /// 任せるときの、スタッフの週俸の総額の上限(5部の物差しの万円。0 は
  /// 給与予算の中ならいくらでも)。
  int get staffDelegateWeeklyCap => _save?.staffDelegateWeeklyCap ?? 0;

  /// 任せる/任せないと、週俸の総額の上限を決める。
  Future<void> setStaffDelegation({bool? on, int? weeklyCap}) async {
    final s = _save;
    if (s == null) return;
    if (on != null) s.staffDelegated = on;
    if (weeklyCap != null) s.staffDelegateWeeklyCap = max(0, weeklyCap);
    if (s.staffDelegated) _runStaffDelegation();
    _notify();
    await _persist();
  }

  /// 任せた人事で、上限の中に収まるか(週俸を[addedWeekly]増やすとき)。
  bool _delegateCapAllows(int addedWeekly) {
    final s = _save!;
    final cap = s.staffDelegateWeeklyCap;
    if (cap <= 0) return true;
    return s.infrastructure.totalStaffWeeklyWage + addedWeekly <= cap;
  }

  /// 任せた人事が自分で動かない役職(監督はオーナーが決める。任された本人の
  /// 役職も)。
  static const _delegateSkips = {StaffRole.manager, StaffRole.sportingDirector};

  /// 任せていれば、空いた役職(主任)を候補から埋める。いちばん能力の高い
  /// 人から、上限と給与予算に収まる人を要求どおりの条件で雇う。
  void _runStaffDelegation() {
    final s = _save;
    if (s == null || !s.staffDelegated || staffDelegate == null) return;
    for (final role in StaffRole.values) {
      if (_delegateSkips.contains(role)) continue;
      if (s.infrastructure.staffFor(role) != null) continue;
      final pool = [
        for (final c in s.staffCandidates)
          if (c.role == role && c.manager == null) c,
      ]..sort((a, b) => b.roleAbility.compareTo(a.roleAbility));
      for (final c in pool) {
        if (!_delegateCapAllows(c.wage)) continue;
        final saved = lastSigningBlockReason;
        final ok = _wageBudgetAllowsSigning(scaledMoney(c.wage),
            isPlayer: false);
        lastSigningBlockReason = saved;
        if (!ok) continue;
        c.hiredOn = SeasonCalendar.dateOnly(today);
        s.infrastructure.addMember(c);
        s.staffCandidates.remove(c);
        _logNews(
          Tr.pick(
              '${staffDelegate!.name}が${c.name}を${role.label}に雇った(任せている人事)。',
              '${staffDelegate!.name} has hired ${c.name} as ${role.label} (you left staffing to him).'),
          context: Tr.pick('スタッフ', 'Staff'),
        );
        break;
      }
    }
  }

  /// 任せていれば、季の終わりで満了する人(残り1年)の更新を判断する。
  /// 役職で並の働き(部の相場から2下まで)をしていて、上限に収まれば、
  /// 要求どおり(1割上げ)で2年延ばす。
  void _delegatedStaffRenewals() {
    final s = _save;
    if (s == null || !s.staffDelegated) return;
    final delegate = staffDelegate;
    if (delegate == null) return;
    final par = StaffMember.expectedAbilityForTier(s.currentDivisionTier) - 2;
    for (final st in [...s.infrastructure.allStaff]) {
      if (st.contractYears != 1) continue;
      if (_delegateSkips.contains(st.role) || st.id == delegate.id) continue;
      final ask = StaffTermsEngine.asking(st, renewal: true);
      if (st.roleAbility < par || !_delegateCapAllows(ask.weeklyWage - st.wage)) {
        _logNews(
          Tr.pick('${delegate.name}は${st.name}(${st.role.label})の契約を延ばさなかった。季の終わりで去る。',
              '${delegate.name} chose not to renew ${st.name} (${st.role.label}). He leaves at the end of the season.'),
          context: Tr.pick('スタッフ', 'Staff'),
        );
        continue;
      }
      st.wage = ask.weeklyWage;
      // 季の切り替えで1つ減るので、2年延ばすには3にしておく。
      st.contractYears = 3;
      _logNews(
        Tr.pick('${delegate.name}が${st.name}(${st.role.label})の契約を2年延ばした。',
            '${delegate.name} has renewed ${st.name} (${st.role.label}) for two more years.'),
        context: Tr.pick('スタッフ', 'Staff'),
      );
    }
  }
}
