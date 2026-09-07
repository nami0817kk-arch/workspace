import 'dart:math';

import '../models/attributes.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/season.dart';
import 'formulas.dart';
import 'names.dart';

/// シーズン終了時に届く移籍オファー。
class TransferOffer {
  const TransferOffer({required this.club, required this.reason});

  final Club club;
  final String reason;
}

/// キャリアの進行（シーズンの組み立て・結果の反映・移籍）を受け持つ。
class CareerEngine {
  CareerEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 新しいキャリアを始める。2部の下位クラブから、無名の選手として始まる。
  CareerState startCareer({
    required String name,
    required Position position,
    required int age,
  }) {
    final league = Names.buildLeague(2);
    // 下位3クラブのどれかに所属。最初から強豪だと成り上がる余地がない。
    final club = league[league.length - 1 - _random.nextInt(3)];
    return CareerState(
      player: Player(
        name: name,
        age: age,
        position: position,
        attributes: _startingAttributes(position),
      ),
      club: club,
      league: league,
      year: 2026,
      fixtures: _buildFixtures(league, club),
      results: [],
      table: _emptyTable(league),
      history: [],
    );
  }

  /// 初期能力。ポジションの主要能力を少し高くして、役割の違いを出す。
  Attributes _startingAttributes(Position position) {
    int roll(int base) => base + _random.nextInt(9) - 4;
    return switch (position) {
      Position.fw => Attributes(
          pace: roll(58),
          shooting: roll(57),
          passing: roll(48),
          dribbling: roll(55),
          defending: roll(32),
          physical: roll(52),
        ),
      Position.mf => Attributes(
          pace: roll(52),
          shooting: roll(48),
          passing: roll(58),
          dribbling: roll(55),
          defending: roll(48),
          physical: roll(50),
        ),
      Position.df => Attributes(
          pace: roll(52),
          shooting: roll(32),
          passing: roll(48),
          dribbling: roll(42),
          defending: roll(58),
          physical: roll(57),
        ),
    };
  }

  /// 対戦相手を並べる。同じ相手とホームとアウェイで2回ずつ当たる。
  List<String> _buildFixtures(List<Club> league, Club club) {
    final opponents = league.where((c) => c.id != club.id).map((c) => c.id);
    final fixtures = [...opponents, ...opponents]..shuffle(_random);
    return fixtures.take(Formulas.matchesPerSeason).toList();
  }

  List<TableRow> _emptyTable(List<Club> league) =>
      [for (final c in league) TableRow(clubId: c.id, clubName: c.name)];

  /// 1試合ぶんの結果をキャリアに反映する。
  ///
  /// 自分の試合は確定した結果を使い、他クラブ同士の試合はその場で簡易に
  /// 決めて順位表に足す。順位表が自分の試合ぶんしか動かないと、
  /// リーグが生きている感じがしない。
  void applyResult(CareerState state, MatchResult result) {
    state.results.add(result);

    final opponent = state.opponentFor(result.matchday);
    _row(state, state.club.id)
        .record(scored: result.scored, conceded: result.conceded);
    _row(state, opponent.id)
        .record(scored: result.conceded, conceded: result.scored);

    _simulateOtherMatches(state, exclude: {state.club.id, opponent.id});
  }

  void _simulateOtherMatches(CareerState state, {required Set<String> exclude}) {
    final others = state.league.where((c) => !exclude.contains(c.id)).toList()
      ..shuffle(_random);
    for (var i = 0; i + 1 < others.length; i += 2) {
      final a = others[i];
      final b = others[i + 1];
      final advantage = a.strength - b.strength;
      final goalsA = _goals(1.3 + advantage / 40);
      final goalsB = _goals(1.3 - advantage / 40);
      _row(state, a.id).record(scored: goalsA, conceded: goalsB);
      _row(state, b.id).record(scored: goalsB, conceded: goalsA);
    }
  }

  int _goals(double mean) {
    final m = mean.clamp(0.2, 4.0);
    var goals = 0;
    for (var i = 0; i < 6; i++) {
      if (_random.nextDouble() < m / 6) goals++;
    }
    return goals;
  }

  TableRow _row(CareerState state, String clubId) =>
      state.table.firstWhere((r) => r.clubId == clubId);

  /// シーズン終了時の移籍オファー。
  ///
  /// 良いシーズンを送るほど、強いクラブから声がかかる。
  /// 何もしなくても残留できるので、オファーは常に選択肢として提示する。
  List<TransferOffer> offersFor(CareerState state) {
    final stats = state.seasonStats;
    if (stats.appearances < 10) return const [];
    if (stats.averageRating < Formulas.transferOfferRating) return const [];

    final reach =
        (state.player.overall * Formulas.transferReachFactor).round();
    final candidates = <TransferOffer>[];

    for (final tier in [1, 2]) {
      final clubs = Names.buildLeague(tier)
          .where((c) => c.id != state.club.id && c.strength <= reach)
          .toList()
        ..sort((a, b) => b.strength.compareTo(a.strength));
      if (clubs.isEmpty) continue;
      final club = clubs.first;
      candidates.add(TransferOffer(
        club: club,
        reason: tier == 1
            ? '1部の${club.name}が、昨季の活躍を評価して獲得に動いた。'
            : '${club.name}が、主力としての起用を約束している。',
      ));
    }
    return candidates;
  }

  /// 次のシーズンへ進む。移籍先が null なら残留。
  CareerState advanceSeason(CareerState state, {Club? moveTo}) {
    final stats = state.seasonStats;
    final record = SeasonRecord(
      year: state.year,
      clubName: state.club.name,
      tier: state.club.tier,
      leaguePosition: state.leaguePosition,
      stats: stats,
    );

    final club = moveTo ?? state.club;
    final league = Names.buildLeague(club.tier);
    // 移籍先リストは毎回組み直すので、同名クラブの実体を差し替えておく。
    final resolved = league.firstWhere((c) => c.name == club.name,
        orElse: () => club);

    return CareerState(
      player: state.player.copyWith(age: state.player.age + 1),
      club: resolved,
      league: league,
      year: state.year + 1,
      fixtures: _buildFixtures(league, resolved),
      results: [],
      table: _emptyTable(league),
      history: [...state.history, record],
    );
  }
}
