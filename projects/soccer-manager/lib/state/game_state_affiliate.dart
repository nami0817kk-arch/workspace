part of 'game_state.dart';

/// 系列クラブ。自クラブより弱い国内外のクラブと提携する(年会費)。
/// 提携先の選手は2割引で取れ、貸し出しは提携先へ出場機会付きで送れる。
extension GameStateAffiliate on GameState {
  /// 年会費(5部の物差しの万円)。季の切り替えで払う。
  static const int annualFee = 300;

  /// 提携先の選手の言い値の割引。
  static const double priceDiscount = 0.8;

  /// 今の系列クラブ(無ければ null)。
  Team? get affiliateClub {
    final id = _save?.affiliateClubId;
    return id == null ? null : _worldTeamById(id);
  }

  bool isAffiliateClub(String teamId) => _save?.affiliateClubId == teamId;

  /// 提携できるクラブ(自クラブより弱い、国内の他の部・他国のクラブ)。
  /// 弱すぎない順に[n]件。
  List<Team> affiliateCandidates({int n = 6}) {
    final s = _save;
    if (s == null) return const [];
    final mine = userTeam.overallRating;
    final rival = s.rivalTeamId;
    final list = [
      for (final t in _worldTeams)
        if (t.id != s.userTeamId &&
            t.id != rival &&
            t.overallRating < mine &&
            t.players.isNotEmpty)
          t,
    ]..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    return list.take(n).toList();
  }

  /// 系列クラブと提携する(すでにあれば付け替える)。最初の年会費をすぐ払う。
  Future<bool> setAffiliateClub(String teamId) async {
    final s = _save;
    if (s == null || s.affiliateClubId == teamId) return false;
    if (!affiliateCandidates(n: 999).any((t) => t.id == teamId)) return false;
    final fee = scaledMoney(annualFee);
    if (s.budget < fee) return false;
    s.affiliateClubId = teamId;
    _book(LedgerCategory.facilities, -fee);
    final name = _worldTeamById(teamId)?.name ?? '-';
    _logNews(
        Tr.pick('$nameと系列クラブの提携を結んだ(年会費${formatMoney(fee)})。',
            'Signed an affiliate partnership with $name (${formatMoney(fee)} a year).'),
        context: Tr.pick('系列クラブ', 'Affiliate'));
    _notify();
    await _persist();
    return true;
  }

  /// 提携をやめる。
  Future<bool> endAffiliate() async {
    final s = _save;
    if (s == null || s.affiliateClubId == null) return false;
    s.affiliateClubId = null;
    _notify();
    await _persist();
    return true;
  }

  /// 季の切り替え: 年会費を払う。払えなければ提携は切れる。
  void _rollAffiliate() {
    final s = _save!;
    if (s.affiliateClubId == null) return;
    if (affiliateClub == null) {
      s.affiliateClubId = null;
      return;
    }
    final fee = scaledMoney(annualFee);
    if (s.budget < fee) {
      s.affiliateClubId = null;
      _logNews(
          Tr.pick('年会費が払えず、系列クラブとの提携が切れた。',
              'The affiliate partnership lapsed: we could not pay the fee.'),
          context: Tr.pick('系列クラブ', 'Affiliate'));
      return;
    }
    _book(LedgerCategory.facilities, -fee);
  }
}
