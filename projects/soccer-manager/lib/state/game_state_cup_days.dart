part of 'game_state.dart';

/// カップ戦の試合の日を実際の欧州サッカーに寄せる(2026-11-23)。
///
/// - 入場収入: カップ戦・大陸大会の試合にも入場収入が入る。以前はリーグ戦の
///   節でだけ記帳し、カップ戦は賞金だけだった。国内のカップ戦(国内カップ・
///   リーグカップ)は両クラブで折半(アウェイでも半分入る)、大陸大会は
///   ホームの試合だけで単価が高い。決勝などの中立の会場の試合は折半。
/// - 中立の会場: 決勝(国内カップ・リーグカップ・大陸大会)とスーパーカップは
///   ホームの利が無い。FA カップは準決勝も中立。
/// - 警告と出場停止: 大会ごと([CardCompetition])に数え、季末に警告の数を
///   0に戻す。試合を行う間だけ[CardRules.current]をその大会の決まりにする。
extension GameStateCupDays on GameState {
  /// チャンピオンズカップの入場券は、リーグ戦の何倍か。
  static const double championsCupGateMultiplier = 1.6;

  /// ヨーロッパカップの入場券は、リーグ戦の何倍か。
  static const double europaCupGateMultiplier = 1.3;

  /// 中立の会場の試合(決勝)の入場収入の総額は、自クラブのホームの1試合の
  /// 何倍か(大きな会場で満員になる)。両クラブで折半する。
  static const double neutralVenueGateMultiplier = 2.0;

  /// 自クラブのホームの1試合の入場収入(年間シートの前売りを引く前)。
  ///
  /// リーグ戦の節の入場収入([weeklyIncomeParts]の gate)は、ホームの試合の
  /// 入場料を1季で均して毎節入れる額(ホームは節のおよそ半分)なので、ホームの
  /// 1試合はその2倍。観客数・単価の式はリーグ戦と同じものを使う。
  int get cupHomeMatchGate =>
      _save == null ? 0 : weeklyIncomeParts(_save!.userTeamId).gate * 2;

  /// カップ戦の1試合で自クラブに入る入場収入。
  ///
  /// [neutral]なら中立の会場で、総額([neutralVenueGateMultiplier]倍)を
  /// 折半。[split]なら(国内のカップ戦)ホームでもアウェイでも半分。どちらでも
  /// なければ(大陸大会)ホームの試合だけ全額。[priceMultiplier]は単価の倍率。
  /// アウェイの試合の額は、相手の会場の数字を持たないので自クラブの数字で
  /// 見積もる。
  int cupGateIncome({
    required bool userHome,
    required bool neutral,
    required bool split,
    double priceMultiplier = 1.0,
  }) {
    final gate = cupHomeMatchGate * priceMultiplier;
    if (neutral) return (gate * neutralVenueGateMultiplier / 2).round();
    if (split) return (gate / 2).round();
    return userHome ? gate.round() : 0;
  }

  /// 大陸大会の入場券の倍率(1 はチャンピオンズカップ、2 はヨーロッパカップ)。
  static double continentalGateMultiplier(int level) =>
      level <= 1 ? championsCupGateMultiplier : europaCupGateMultiplier;

  /// 自クラブのカップ戦の1試合([played])の入場収入を記帳する(入場収入の
  /// 区分)。自クラブの出ない試合では何もしない。
  void _bookCupGate(
    MatchResult? played, {
    required bool neutral,
    required bool split,
    double priceMultiplier = 1.0,
  }) {
    final s = _save;
    if (s == null || played == null) return;
    final u = s.userTeamId;
    if (played.homeTeamId != u && played.awayTeamId != u) return;
    if (played.homeTeamId == byeTeamId || played.awayTeamId == byeTeamId) {
      return;
    }
    final money = cupGateIncome(
      userHome: played.homeTeamId == u,
      neutral: neutral,
      split: split,
      priceMultiplier: priceMultiplier,
    );
    if (money > 0) _book(LedgerCategory.gate, money);
  }

  /// 国内のカップ戦([cup])の[match]で、いま終えた試合(2試合制の第1戦の
  /// あとは第1戦)の入場収入を記帳する。
  void _bookDomesticCupGate(Cup cup, CupMatch match) {
    _bookCupGate(match.result ?? match.firstLeg,
        neutral: cup.isNeutral(match), split: true);
  }

  /// ライブ観戦中のカップ戦が中立の会場か(決勝・スーパーカップ)。
  bool get _liveCupNeutral {
    switch (_liveCupKind) {
      case null:
      case LiveCupKind.continentalGroup:
        return false;
      case LiveCupKind.superCup:
        return true;
      case LiveCupKind.domestic:
        final m = _liveCupMatch;
        final cup = domesticCup;
        return m != null && cup != null && cup.isNeutral(m);
      case LiveCupKind.continentalKnockout:
        return _liveCupTie?.singleLeg ?? false;
    }
  }

  // ---- 警告と出場停止 ----

  /// 自国のリーグ戦の第[md]節の警告の決まり。
  CardRules _leagueCardRules(int md) => CardRules.league(
        theme: currentLeagueTheme,
        matchday: md,
        totalMatchdays: _totalMatchdaysThisSeason,
      );

  /// 自国のリーグ戦の、次の節の警告の決まり(画面の「あと◯枚」用)。
  CardRules get leagueCardRulesNow => _save == null
      ? CardRules.generic
      : _leagueCardRules(_save!.league.nextUnplayedFixture?.matchday ??
          _totalMatchdaysThisSeason);

  /// 国内のカップ戦の警告の決まり。
  CardRules get _cupCardRules => CardRules.cup(theme: currentLeagueTheme);

  /// ライブ観戦中の試合の大会の決まり(カップ戦でなければリーグ戦)。
  CardRules get _liveCardRules => switch (_liveCupKind) {
        null => _leagueCardRules(_liveFixture?.matchday ?? 0),
        LiveCupKind.domestic || LiveCupKind.superCup => _cupCardRules,
        LiveCupKind.continentalGroup ||
        LiveCupKind.continentalKnockout =>
          const CardRules.continental(),
      };

  /// 季末: 全クラブの全選手の警告の数を0に戻す(大会ごと。出場停止の残りは
  /// 次の季へ持ち越す)。
  void _resetSeasonCards() {
    final s = _save;
    if (s == null) return;
    for (final p in s.allPlayers) {
      p.resetSeasonYellowCards();
    }
  }

  /// テスト用: 季末の警告の片付けを走らせる。
  @visibleForTesting
  void debugResetSeasonCards() => _resetSeasonCards();
}
