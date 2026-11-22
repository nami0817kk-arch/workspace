part of 'game_state.dart';

/// 記者会見での答え方。
enum RumorAnswer {
  /// 「売らない」と明言する。選手は落ち着くが、その季に売るとサポーターが怒る。
  deny,

  /// 何も言わない。選手は少し落ち着かなくなる。
  noComment,

  /// 「条件しだいで売る」と話す。選手は浮き足立つが、そのクラブから話が来る。
  open,
}

extension RumorAnswerInfo on RumorAnswer {
  String get label => switch (this) {
        RumorAnswer.deny => Tr.pick('売らないと明言する', 'Say he is not for sale'),
        RumorAnswer.noComment => Tr.pick('コメントしない', 'No comment'),
        RumorAnswer.open => Tr.pick('条件しだいと話す', 'Say the price is right'),
      };
}

/// メディアの移籍の噂と、記者会見。
extension GameStateRumors on GameState {
  /// 噂が出る節の確率。
  static const double rumorChance = 0.12;

  /// 「売らない」と言った季に売ったときの、サポーターの期待の下がり幅。
  static const int brokenPromisePenalty = 8;

  /// 噂の相手(他国の1部で、自クラブより強いクラブ)。
  List<Team> get _rumorClubs {
    final s = _save!;
    final mine = userTeam.overallRating;
    return [
      for (final l in s.foreignLeagues.values)
        for (final t in l.teams)
          if (t.overallRating > mine) t,
    ];
  }

  /// 毎節: たまに、自クラブの看板選手に移籍の噂が出る。
  void _maybeRaiseRumor({double? roll}) {
    final s = _save;
    if (s == null || s.pendingRumor != null) return;
    final rng = Random();
    if ((roll ?? rng.nextDouble()) >= rumorChance) return;
    final stars = ([...userTeam.players.where((p) => !p.isLoan && !p.isLoanedOut)]
          ..sort((a, b) => b.marketValue.compareTo(a.marketValue)))
        .take(3)
        .toList();
    final clubs = _rumorClubs;
    if (stars.isEmpty || clubs.isEmpty) return;
    final p = stars[rng.nextInt(stars.length)];
    final club = clubs[rng.nextInt(clubs.length)];
    s.pendingRumor = [p.id, p.name, club.name];
    _logNews(
        Tr.pick('${club.name}が${p.name}に関心と報じられた。記者会見でどう答えるか、決めてください。',
            '${club.name} are reported to be interested in ${p.name}. Decide how to answer at the press conference.'),
        context: Tr.pick('メディア', 'Media'));
  }

  /// 記者会見で噂に答える。
  Future<bool> answerRumor(RumorAnswer a) async {
    final s = _save;
    final r = s?.pendingRumor;
    if (s == null || r == null) return false;
    s.pendingRumor = null;
    final p = userTeam.players.where((x) => x.id == r[0]).firstOrNull;
    if (p != null) {
      switch (a) {
        case RumorAnswer.deny:
          p.happiness = (p.happiness + 10).clamp(0, 100);
          s.rumorDenied[p.id] = s.league.season;
          s.confidence = (s.confidence + 2).clamp(0, 100);
        case RumorAnswer.noComment:
          p.happiness = (p.happiness - 5).clamp(0, 100);
        case RumorAnswer.open:
          p.happiness = (p.happiness - 15).clamp(0, 100);
          if (!s.incomingOffers.any((o) => o.playerId == p.id)) {
            s.incomingOffers.add(IncomingOffer(
              id: 'rumor${_incomingOfferSeq++}',
              playerId: p.id,
              playerName: p.name,
              buyerClubName: r[2],
              // 相場(契約の残り年数の係数込み)の2割増し。
              amount: (TransferValue.worth(p, seasonProgress) * 1.2).round(),
            ));
          }
      }
    }
    _logNews(
        Tr.pick('記者会見で${r[1]}の噂に答えた: ${a.label}。',
            'Answered the ${r[1]} rumour at the press conference: ${a.label}.'),
        context: Tr.pick('メディア', 'Media'));
    _notify();
    await _persist();
    return true;
  }

  /// 売った選手が、その季に「売らない」と言った選手なら、サポーターが怒る。
  void _checkBrokenRumorPromise(Player p) {
    final s = _save!;
    final season = s.rumorDenied.remove(p.id);
    if (season == null || season != s.league.season) return;
    s.confidence = (s.confidence - brokenPromisePenalty).clamp(0, 100);
    _logNews(
        Tr.pick('「売らない」と言った${p.name}を同じ季に売り、サポーターが怒っている。',
            'You sold ${p.name} in the same season you said he was not for sale. The supporters are angry.'),
        context: Tr.pick('メディア', 'Media'));
  }

  /// テスト用: 噂を必ず出す。
  @visibleForTesting
  void debugRaiseRumor() => _maybeRaiseRumor(roll: 0);
}
