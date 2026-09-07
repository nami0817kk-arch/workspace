import 'dart:math';

import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/competition.dart';
import '../models/country.dart';
import '../models/nationality.dart';
import '../models/player.dart';
import '../models/season.dart';
import '../models/traits.dart';
import 'career_engine_extras.dart';
import 'competitions.dart';
import 'eligibility.dart';
import 'formulas.dart';
import 'world.dart';

/// シーズン終了時に届くオファー。残留の契約更改もこの形で扱う。
class TransferOffer {
  const TransferOffer({
    required this.club,
    required this.reason,
    required this.salary,
    required this.role,
    required this.years,
    this.eligibility,
    this.isRenewal = false,
    this.negotiated = false,
  });

  final Club club;
  final String reason;

  /// 提示年俸（万円）。
  final int salary;

  /// 起用の約束。
  final String role;

  /// 契約年数。
  final int years;

  /// 外国人枠と労働許可の判定。国内の移籍や契約更改なら null。
  final EligibilityReport? eligibility;

  /// 今のクラブとの契約更改なら true。
  final bool isRenewal;

  /// 上乗せ交渉を済ませた（もう要求できない）。
  final bool negotiated;

  TransferOffer copyWith({int? salary, bool? negotiated}) => TransferOffer(
        club: club,
        reason: reason,
        salary: salary ?? this.salary,
        role: role,
        years: years,
        eligibility: eligibility,
        isRenewal: isRenewal,
        negotiated: negotiated ?? this.negotiated,
      );
}

/// 上乗せ要求の結果。
enum NegotiationResult {
  raised('上乗せに成功'),
  refused('据え置き'),
  withdrawn('オファー撤回');

  const NegotiationResult(this.label);

  final String label;
}

/// シーズン終了時に、所属クラブがどう動くか。
enum ClubFate {
  stay('残留'),
  promoted('昇格'),
  relegated('降格');

  const ClubFate(this.label);

  final String label;
}

/// キャリアの進行（シーズンの組み立て・結果の反映・移籍・引退）を受け持つ。
class CareerEngine {
  CareerEngine({Random? random})
      : _random = random ?? Random(),
        extras = CareerExtras(random: random);

  final Random _random;

  /// 代表招集と監督の目標。
  final CareerExtras extras;

  /// 大陸カップ・昇格プレーオフ・移籍の窓・登録メンバー。
  late final Competitions competitions = Competitions(random: _random);

  /// 新しいキャリアを始める。2部の下位クラブから、無名の選手として始まる。
  CareerState startCareer({
    required String name,
    required Position position,
    required int age,
    required Agent agent,
    String? countryId,
  }) {
    final home = countryId == null
        ? World.randomHome(_random)
        : World.byId(countryId);
    // 2部から始める。1部しか無い国なら1部の下位から。
    final tier = home.tiers >= 2 ? 2 : 1;
    final league = World.buildLeague(home.id, tier);
    // 下位3クラブのどれかに所属。最初から強豪だと成り上がる余地がない。
    final club = league[league.length - 1 - _random.nextInt(3)];
    final attributes = _startingAttributes(position, age);
    final overall = attributes.overallFor(position);
    final player = Player(
      name: name,
      age: age,
      position: position,
      attributes: attributes,
      potential: rollPotential(overall),
      nationality: _rollNationality(home),
      traits: Trait.roll(_random),
    );
    return CareerState(
      player: player,
      club: club,
      league: league,
      year: 2026,
      fixtures: _buildFixtures(league, club),
      results: [],
      table: _emptyTable(league),
      history: [],
      agent: agent,
      salary: salaryFor(overall: overall, tier: club.tier, prestige: home.prestige),
      contractYears: extras.rollContractYears(),
      countryId: home.id,
      objective: extras.objectiveFor(player: player, club: club),
    );
  }

  /// 国籍を決める。2割でルーツの国籍が付き、代表を選ぶ余地が生まれる。
  ///
  /// ホームグロウンは最初のクラブで育った扱いにする。母国の登録枠で有利になり、
  /// 「出てきたクラブ」という設定にもなる。
  Nationality _rollNationality(Country home) {
    String? roots;
    if (_random.nextDouble() < 0.2) {
      final others =
          World.countries.where((c) => c.id != home.id).toList();
      roots = others[_random.nextInt(others.length)].id;
    }
    return Nationality(
      primary: home.id,
      roots: roots,
      homegrownCountryId: home.id,
    );
  }

  /// ポテンシャル。今の総合力より必ず上で、上振れは稀。
  int rollPotential(int overall) {
    // 3つ引いて最大を取ると、高い方に少し寄る。凡庸な選手が多すぎると
    // キャリアが伸びず、逆に全員が大器だと差が出ない。
    final rolls = [for (var i = 0; i < 3; i++) _random.nextInt(33)];
    final bonus = rolls.reduce(max);
    return (overall + 8 + bonus).clamp(Formulas.potentialMin, Formulas.potentialMax);
  }

  /// 年俸（万円）。総合力とリーグで決まる。
  static int salaryFor({
    required int overall,
    required int tier,
    int prestige = 3,
  }) {
    final base = pow(max(0, overall - 40), 2).toDouble();
    final tierFactor = tier == 1 ? 4.0 : 1.2;
    // 国の格で水準が変わる。同じ実力でも行き先で年俸が跳ねる。
    final countryFactor = 0.5 + prestige * 0.25;
    return max(120, (base * tierFactor * countryFactor / 10).round() * 10);
  }

  /// 初期能力。ポジションの主要能力を少し高くして、役割の違いを出す。
  /// 年齢が高いほど初期値は上がるが、その分ピークまでの時間は短い。
  Attributes _startingAttributes(Position position, int age) {
    final ageBonus = (age - 17) * 2;
    int roll(int base) => base + ageBonus + _random.nextInt(9) - 4;
    final random = _random;
    return switch (position) {
      Position.gk => Attributes.scattered(
          random: random,
          pace: roll(42),
          shooting: roll(22),
          passing: roll(46),
          dribbling: roll(30),
          defending: roll(50),
          physical: roll(56),
          goalkeeping: roll(58),
        ),
      Position.cb => Attributes.scattered(
          random: random,
          pace: roll(50),
          shooting: roll(30),
          passing: roll(47),
          dribbling: roll(40),
          defending: roll(59),
          physical: roll(58),
        ),
      Position.sb => Attributes.scattered(
          random: random,
          pace: roll(58),
          shooting: roll(36),
          passing: roll(52),
          dribbling: roll(50),
          defending: roll(54),
          physical: roll(50),
        ),
      Position.dm => Attributes.scattered(
          random: random,
          pace: roll(48),
          shooting: roll(40),
          passing: roll(56),
          dribbling: roll(46),
          defending: roll(56),
          physical: roll(54),
        ),
      Position.cm => Attributes.scattered(
          random: random,
          pace: roll(52),
          shooting: roll(48),
          passing: roll(58),
          dribbling: roll(55),
          defending: roll(48),
          physical: roll(50),
        ),
      Position.am => Attributes.scattered(
          random: random,
          pace: roll(54),
          shooting: roll(54),
          passing: roll(58),
          dribbling: roll(58),
          defending: roll(36),
          physical: roll(44),
        ),
      Position.wg => Attributes.scattered(
          random: random,
          pace: roll(62),
          shooting: roll(52),
          passing: roll(50),
          dribbling: roll(60),
          defending: roll(32),
          physical: roll(46),
        ),
      Position.st => Attributes.scattered(
          random: random,
          pace: roll(58),
          shooting: roll(58),
          passing: roll(46),
          dribbling: roll(54),
          defending: roll(30),
          physical: roll(54),
        ),
    };
  }

  /// 対戦相手を並べる。同じ相手とホームとアウェイで2回ずつ当たる。
  ///
  /// 試合数は国とクラブ数で決まる。16クラブの国は30試合、20クラブなら38試合。
  List<String> _buildFixtures(List<Club> league, Club club) {
    final opponents = league.where((c) => c.id != club.id).map((c) => c.id);
    final fixtures = [...opponents, ...opponents]..shuffle(_random);
    return fixtures.take((league.length - 1) * 2).toList();
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

    // 代表戦はリーグの順位表に影響しない。キャップだけ増える。
    if (result.international) {
      state.caps++;
      state.internationalGoals += result.goals;
      return;
    }

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

  /// 今シーズンの順位から、所属クラブの去就を決める。
  ClubFate fateOf(CareerState state) {
    final country = World.byId(state.club.countryId);
    final position = state.leaguePosition;
    final size = country.clubsInTier(state.club.tier);

    if (state.club.tier > 1 && position <= Formulas.promotionPlaces) {
      return ClubFate.promoted;
    }
    // 3〜6位はプレーオフ。勝てば昇格、負ければ残留。
    if (inPromotionPlayoff(state) &&
        competitions.winsPromotionPlayoff(position)) {
      return ClubFate.promoted;
    }
    // 降格は下から3クラブ。クラブ数が国ごとに違うので相対で決める。
    if (state.club.tier < country.tiers && position > size - 3) {
      return ClubFate.relegated;
    }
    return ClubFate.stay;
  }

  /// 昇格プレーオフに回ったか（3〜6位）。
  bool inPromotionPlayoff(CareerState state) {
    final country = World.byId(state.club.countryId);
    if (state.club.tier <= 1) return false;
    final position = state.leaguePosition;
    return position > Formulas.promotionPlaces && position <= 6 &&
        country.tiers > 1;
  }



  /// 大陸カップに出られる順位か。
  bool inContinental(CareerState state) {
    final country = World.byId(state.club.countryId);
    return state.club.tier == 1 &&
        state.leaguePosition <= country.continentalSlots;
  }

  /// この年齢で引退を選べるか。
  bool canRetire(CareerState state) =>
      state.player.age >= Formulas.retirementOptionalAge;

  /// この年齢なら引退するしかない。
  bool mustRetire(CareerState state) =>
      state.player.age >= Formulas.retirementForcedAge;

  /// 昇降格後のクラブ（残留した場合の来季の所属）。
  Club nextClubIfStaying(CareerState state) => switch (fateOf(state)) {
        ClubFate.promoted => Club(
            id: state.club.id,
            name: state.club.name,
            strength: state.club.strength + Formulas.promotionStrengthBonus,
            tier: state.club.tier - 1,
            countryId: state.club.countryId,
          ),
        ClubFate.relegated => Club(
            id: state.club.id,
            name: state.club.name,
            strength: state.club.strength - Formulas.promotionStrengthBonus,
            tier: state.club.tier + 1,
            countryId: state.club.countryId,
          ),
        ClubFate.stay => state.club,
      };

  /// 今のクラブとの契約更改。良いシーズンなら上がり、悪ければ下がる。
  TransferOffer renewalOffer(CareerState state) {
    final club = nextClubIfStaying(state);
    final stats = state.seasonStats;
    final base = salaryFor(
      overall: state.player.overall,
      tier: club.tier,
      prestige: World.byId(club.countryId).prestige,
    );
    final performance = stats.appearances == 0
        ? 0.85
        : (0.85 + (stats.averageRating - 6.0) * 0.25).clamp(0.7, 1.4);
    // 監督の目標を達成したかどうかも年俸に効く。
    final objectiveFactor = state.objective == null
        ? 1.0
        : (state.objective!.achieved(stats)
            ? Formulas.objectiveMetSalaryFactor
            : Formulas.objectiveMissedSalaryFactor);
    // 大陸カップに出たシーズンは評価が上がる。
    final continentalFactor = state.continentalStage.participated
        ? Formulas.continentalSalaryBonus
        : 1.0;
    final salary = _round(
        max(base, state.salary) * performance * objectiveFactor * continentalFactor);
    return TransferOffer(
      club: club,
      reason: '${club.name}が契約更改を提示した。',
      salary: salary,
      role: _roleFor(state.player.overall, club),
      years: extras.rollContractYears(),
      isRenewal: true,
    );
  }

  /// シーズン終了時の移籍オファー。
  ///
  /// 良いシーズンを送るほど、強いクラブから声がかかる。代理人の人脈で
  /// 上限が伸びる。何もしなくても残留できるので、常に選択肢として提示する。
  List<TransferOffer> offersFor(CareerState state) {
    // 契約が残っている間は動けない。残り1年になって初めて話が来る。
    if (state.contractYears > 1) return const [];

    final stats = state.seasonStats;
    if (stats.appearances < 10) return const [];
    if (stats.averageRating < Formulas.transferOfferRating) return const [];

    final reach =
        (state.player.overall * Formulas.transferReachFactor).round() +
            state.agent.reach;
    final origin = World.byId(state.club.countryId);
    final candidates = <TransferOffer>[];

    // 声がかかる国。今の国と、代理人の人脈で届く範囲の国。
    for (final country in _reachableCountries(state)) {
      for (final tier in [1, 2]) {
        if (tier > country.tiers) continue;
        final clubs = World.buildLeague(country.id, tier)
            .where((c) => c.name != state.club.name && c.strength <= reach)
            .toList()
          ..sort((a, b) => b.strength.compareTo(a.strength));
        if (clubs.isEmpty) continue;
        final club = clubs.first;

        final eligibility = Eligibility.report(
          nationality: state.player.nationality,
          club: club,
          origin: origin,
          caps: state.caps,
          professionalYears: state.professionalYears,
          marketValue: state.salary,
          continentalExperience: state.continentalExperience,
        );
        // 枠が空いていない、または許可が下りない移籍は成立しない。
        if (!eligibility.canJoin) continue;

        final salary = _round(
          salaryFor(
                overall: state.player.overall,
                tier: tier,
                prestige: country.prestige,
              ) *
              (1 + state.agent.negotiation * 0.03),
        );
        candidates.add(TransferOffer(
          club: club,
          reason: country.id == state.club.countryId
              ? (tier == 1
                  ? '1部の${club.name}が、昨季の活躍を評価して獲得に動いた。'
                  : '${club.name}が、主力としての起用を約束している。')
              : '${country.name}の${club.name}から国外移籍の打診が届いた。',
          salary: salary,
          role: _roleFor(state.player.overall, club),
          years: extras.rollContractYears(),
          eligibility: eligibility,
        ));
      }
    }

    // 良い条件の順に3件まで。並べすぎると選ぶのが作業になる。
    candidates.sort((a, b) => b.salary.compareTo(a.salary));
    return candidates.take(3).toList();
  }

  /// 声がかかる国を決める。
  ///
  /// 今の国は常に対象。国外は「自分の格」と「代理人の人脈」で決まり、
  /// いきなり最上位リーグから声はかからない。
  List<Country> _reachableCountries(CareerState state) {
    final here = World.byId(state.club.countryId);
    final reachPrestige =
        (state.player.overall - 55) ~/ 8 + state.agent.reach ~/ 3;
    return [
      here,
      ...World.countries.where((c) =>
          c.id != here.id && c.prestige <= here.prestige + reachPrestige),
    ];
  }

  /// 起用の見込み。クラブの強さと自分の力の差で決まる。
  String _roleFor(int overall, Club club) {
    final gap = overall - club.strength;
    if (gap >= 5) return '絶対的な主力';
    if (gap >= -3) return '主力';
    if (gap >= -10) return 'ローテーション';
    return '控え';
  }

  /// 上乗せを要求する。
  ///
  /// 通るかは代理人の交渉力と今季の成績で決まる。失敗すると、
  /// 相手が引くこともある。強気の代理人は高く取ってくるが、その分手数料も高い。
  (NegotiationResult, TransferOffer?) negotiate(
    CareerState state,
    TransferOffer offer,
  ) {
    if (offer.negotiated) return (NegotiationResult.refused, offer);

    final stats = state.seasonStats;
    final performance =
        stats.appearances == 0 ? -0.1 : (stats.averageRating - 6.8) * 0.3;
    final chance = (Formulas.negotiationBase +
            state.agent.negotiation * Formulas.negotiationPerSkill +
            performance)
        .clamp(0.05, 0.9);

    if (_random.nextDouble() < chance) {
      return (
        NegotiationResult.raised,
        offer.copyWith(
          salary: _round(offer.salary * Formulas.negotiationRaise),
          negotiated: true,
        ),
      );
    }
    // 契約更改は撤回されない（クラブに残る権利は消えない）。
    if (!offer.isRenewal &&
        _random.nextDouble() < Formulas.withdrawChanceOnFail) {
      return (NegotiationResult.withdrawn, null);
    }
    return (NegotiationResult.refused, offer.copyWith(negotiated: true));
  }

  /// 代理人の手取り差し引き後の年俸。
  int takeHome(CareerState state, int salary) =>
      _round(salary * (1 - state.agent.feePercent / 100));

  int _round(num value) => (value / 10).round() * 10;

  /// 次のシーズンへ進む。受けたオファーのクラブと年俸で始める。
  CareerState advanceSeason(CareerState state, {required TransferOffer accepted}) {
    final record = SeasonRecord(
      year: state.year,
      clubName: state.club.name,
      tier: state.club.tier,
      leaguePosition: state.leaguePosition,
      stats: state.seasonStats,
      salary: state.salary,
      caps: state.seasonCaps,
      objectiveMet: state.objective?.achieved(state.seasonStats) ?? false,
      countryId: state.club.countryId,
      continentalStage: state.continentalStage,
    );

    final league = _leagueContaining(accepted.club);
    final resolved = league.firstWhere((c) => c.name == accepted.club.name);
    // 同じ国に5年いると帰化できる。外国人枠から外れ、行ける先が広がる。
    final yearsHere = 1 +
        state.history.where((h) => h.countryId == state.club.countryId).length;
    var nationality = state.player.nationality;
    if (yearsHere >= 5 && !nationality.has(state.club.countryId)) {
      nationality = nationality.naturalize(state.club.countryId);
    }

    final nextPlayer = state.player.copyWith(
      age: state.player.age + 1,
      condition: Formulas.conditionMax,
      nationality: nationality,
    );
    final stayed = accepted.club.name == state.club.name;

    return CareerState(
      player: nextPlayer,
      club: resolved,
      league: league,
      year: state.year + 1,
      fixtures: _buildFixtures(league, resolved),
      results: [],
      table: _emptyTable(league),
      history: [...state.history, record],
      agent: state.agent,
      salary: accepted.salary,
      training: state.training,
      // 契約更改か移籍なら新しい年数。ただ残っただけなら1年減る。
      contractYears: stayed && !accepted.isRenewal
          ? max(1, state.contractYears - 1)
          : accepted.years,
      countryId: resolved.countryId,
      professionalYears: state.professionalYears + 1,
      continentalExperience: state.continentalExperience ||
          state.continentalStage.participated,
      objective: extras.objectiveFor(player: nextPlayer, club: resolved),
      continentalStage: ContinentalStage.none,
      // 怪我はシーズンを跨いでも消えない。オフの間に少しは進む。
      injury: state.injury == null || state.injury!.matchesOut <= 4
          ? null
          : state.injury,
      caps: state.caps,
      internationalGoals: state.internationalGoals,
    );
  }

  /// そのクラブが入るリーグを組む。
  ///
  /// 名簿はリーグごとに固定なので、昇降格で移ってきたクラブは
  /// 元々の名簿の1クラブと入れ替える（昇格なら一番弱いクラブ、降格なら一番強いクラブ）。
  /// これで20クラブが保たれ、自分のクラブは必ずリーグに存在する。
  List<Club> _leagueContaining(Club club) {
    final league = World.buildLeague(club.countryId, club.tier);
    if (league.any((c) => c.name == club.name)) return league;

    final replaced = club.tier == 1
        ? league.reduce((a, b) => a.strength <= b.strength ? a : b)
        : league.reduce((a, b) => a.strength >= b.strength ? a : b);
    return [
      for (final c in league)
        if (c.id == replaced.id)
          Club(
            id: replaced.id,
            name: club.name,
            strength: club.strength,
            tier: club.tier,
            countryId: club.countryId,
          )
        else
          c,
    ];
  }

  /// シーズン終了時に、大陸カップの結果と来季の登録状況を確定させる。
  ///
  /// リーグ戦を戦い終えてから呼ぶ。出場していなければ none のまま。
  void resolveSeasonEnd(CareerState state) {
    state.continentalStage = competitions.runContinental(
      state,
      qualified: inContinental(state),
    );
    if (state.continentalStage.participated) {
      state.continentalExperience = true;
    }
  }

  /// 引退する。今シーズンの記録を残して、以後は試合をしない。
  CareerState retire(CareerState state) {
    final record = SeasonRecord(
      year: state.year,
      clubName: state.club.name,
      tier: state.club.tier,
      leaguePosition: state.leaguePosition,
      stats: state.seasonStats,
      salary: state.salary,
      caps: state.seasonCaps,
      objectiveMet: state.objective?.achieved(state.seasonStats) ?? false,
      countryId: state.club.countryId,
      continentalStage: state.continentalStage,
    );
    return CareerState(
      player: state.player,
      club: state.club,
      league: state.league,
      year: state.year,
      fixtures: state.fixtures,
      results: [],
      table: state.table,
      history: [...state.history, record],
      agent: state.agent,
      salary: state.salary,
      contractYears: state.contractYears,
      countryId: state.countryId,
      professionalYears: state.professionalYears,
      continentalExperience: state.continentalExperience,
      caps: state.caps,
      internationalGoals: state.internationalGoals,
      retired: true,
    );
  }
}
