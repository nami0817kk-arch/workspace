import 'dart:math';

import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/competition.dart';
import '../models/aptitude.dart';
import '../models/country.dart';
import '../models/entourage.dart';
import '../models/life.dart';
import '../models/nationality.dart';
import '../models/personality.dart';
import '../models/look.dart';
import '../models/physique.dart';
import '../models/player.dart';
import '../models/reputation.dart';
import '../models/season.dart';
import '../models/support.dart';
import '../models/training.dart';
import '../models/traits.dart';
import 'career_engine_extras.dart';
import 'competitions.dart';
import 'eligibility.dart';
import 'person.dart';
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
    this.fee = 0,
    this.releaseClause,
    this.loan = false,
    this.buyOption,
    this.returning = false,
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

  /// クラブ間で動く移籍金（万円）。自分の懐には入らないが、
  /// 高く買われるほど期待も重くなる。
  final int fee;

  /// 新しい契約に付く違約金（万円）。
  final int? releaseClause;

  /// ローン（期限付き移籍）か。1シーズンで戻る。
  final bool loan;

  /// ローンに付いた買い取り option の金額。無ければ null。
  final int? buyOption;

  /// ローンから保有元へ戻る契約か。
  final bool returning;

  TransferOffer copyWith({int? salary, bool? negotiated}) => TransferOffer(
        club: club,
        reason: reason,
        salary: salary ?? this.salary,
        role: role,
        years: years,
        eligibility: eligibility,
        isRenewal: isRenewal,
        negotiated: negotiated ?? this.negotiated,
        fee: fee,
        releaseClause: releaseClause,
        loan: loan,
        buyOption: buyOption,
        returning: returning,
      );

  /// 画面に出す但し書き。
  String get terms {
    final parts = <String>[
      if (loan) 'ローン（1年）',
      if (buyOption != null) '買い取りオプション ${_money(buyOption!)}',
      if (fee > 0) '移籍金 ${_money(fee)}',
      if (releaseClause != null) '違約金 ${_money(releaseClause!)}',
    ];
    return parts.join(' ・ ');
  }

  static String _money(int value) => value >= 10000
      ? '${(value / 10000).toStringAsFixed(1)}億円'
      : '$value万円';
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

  /// 性格・市場価値・評判・関係・お金。
  late final Person person = Person(random: _random);

  /// 新しいキャリアを始める。2部の下位クラブから、無名の選手として始まる。
  CareerState startCareer({
    required String name,
    required Position position,
    required int age,
    required Agent agent,
    String? countryId,
    Side side = Side.center,
    Physique? physique,
    PlayerLook? look,
    int? squadNumber,
    Map<AttributeKey, int> tweaks = const {},
  }) {
    final home = countryId == null
        ? World.randomHome(_random)
        : World.byId(countryId);
    // 2部から始める。1部しか無い国なら1部の下位から。
    //
    // 16〜17歳で始めた選手は育成年代の扱いで、一番下の部から。
    // 遠回りだが、その分だけ長く伸びる時間がある。
    final tier = age <= Formulas.youthAge
        ? home.tiers
        : (home.tiers >= 2 ? 2 : 1);
    final league = World.buildLeague(home.id, tier);
    // 下位3クラブのどれかに所属。最初から強豪だと成り上がる余地がない。
    final club = league[league.length - 1 - _random.nextInt(3)];
    final attributes = _startingAttributes(position, age, tweaks: tweaks);
    final overall = attributes.overallFor(position);
    // そのポジションで意味を持つ特性からだけ引く。
    // 天才はポテンシャルに乗るので、ポテンシャルより先に引く。
    final traits = Trait.roll(_random, position: position);
    final player = Player(
      name: name,
      age: age,
      position: position,
      // 左右のある役割でなければ、指定されていても中央に倒す。
      side: position.hasSide ? side : Side.center,
      attributes: attributes,
      potential: (rollPotential(overall) + traits.potentialBonus)
          .clamp(Formulas.potentialMin, Formulas.maxAttribute),
      nationality: _rollNationality(home),
      personality: Personality.roll(_random),
      physique: physique ?? Physique.roll(_random, position),
      look: look ?? PlayerLook.roll(_random),
      aptitude: Aptitude.initial(position),
      traits: traits,
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
      squadNumber: squadNumber ?? squadNumberFor(position, _random),
      // 最初から練習している状態で始める。休養が既定だと、育成タブを
      // 開かない人は何も伸びないまま1年が過ぎる。
      menu: TrainingMenu.defaultFor(position),
      nationalTeamId: home.id,
      manager: Manager.roll(_random),
      competitor: Teammate.roll(_random,
          kind: TeammateKind.rival, clubStrength: club.strength),
      partner: Teammate.roll(_random,
          kind: TeammateKind.partner, clubStrength: club.strength),
      mentor: Teammate.roll(_random,
          kind: TeammateKind.mentor, clubStrength: club.strength),
      // 同期のライバル。別のクラブで、同じ年に出てきた選手。
      rival: Rival.roll(_random,
          overall: overall, clubName: league[_random.nextInt(league.length)].name),
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
    // 3つ引いて最大を取ると高いほうに寄る。幅を広く取りすぎると、
    // 到達しようのない上限が付いて「頭打ち」がただの飾りになる。
    final rolls = [for (var i = 0; i < 3; i++) _random.nextInt(24)];
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

  /// ポジションごとの初期能力の基準値。
  ///
  /// 選手作成画面の割り振りもここを起点にする。数字を2か所に持つと、
  /// 画面に見せている基準と実際に配られる能力がずれる。
  static Map<AttributeKey, int> startingBaseFor(Position position) =>
      switch (position) {
        Position.gk => const {AttributeKey.pace: 42, AttributeKey.shooting: 22, AttributeKey.passing: 46, AttributeKey.dribbling: 30, AttributeKey.defending: 50, AttributeKey.physical: 56, AttributeKey.goalkeeping: 58},
        Position.cb => const {AttributeKey.pace: 50, AttributeKey.shooting: 30, AttributeKey.passing: 47, AttributeKey.dribbling: 40, AttributeKey.defending: 59, AttributeKey.physical: 58},
        Position.sb => const {AttributeKey.pace: 58, AttributeKey.shooting: 36, AttributeKey.passing: 52, AttributeKey.dribbling: 50, AttributeKey.defending: 54, AttributeKey.physical: 50},
        Position.dm => const {AttributeKey.pace: 48, AttributeKey.shooting: 40, AttributeKey.passing: 56, AttributeKey.dribbling: 46, AttributeKey.defending: 56, AttributeKey.physical: 54},
        Position.cm => const {AttributeKey.pace: 52, AttributeKey.shooting: 48, AttributeKey.passing: 58, AttributeKey.dribbling: 55, AttributeKey.defending: 48, AttributeKey.physical: 50},
        Position.am => const {AttributeKey.pace: 54, AttributeKey.shooting: 54, AttributeKey.passing: 58, AttributeKey.dribbling: 58, AttributeKey.defending: 36, AttributeKey.physical: 44},
        Position.wg => const {AttributeKey.pace: 62, AttributeKey.shooting: 52, AttributeKey.passing: 50, AttributeKey.dribbling: 60, AttributeKey.defending: 32, AttributeKey.physical: 46},
        Position.st => const {AttributeKey.pace: 58, AttributeKey.shooting: 58, AttributeKey.passing: 46, AttributeKey.dribbling: 54, AttributeKey.defending: 30, AttributeKey.physical: 54},
      };

  /// 初期能力。ポジションの主要能力を少し高くして、役割の違いを出す。
  /// 年齢が高いほど初期値は上がるが、その分ピークまでの時間は短い。
  ///
  /// [tweaks] は選手作成画面での割り振り。合計0で渡ってくるので、
  /// 平均の総合力は振らない場合と変わらない。
  Attributes _startingAttributes(
    Position position,
    int age, {
    Map<AttributeKey, int> tweaks = const {},
  }) {
    final ageBonus = (age - 17) * 2;
    final base = startingBaseFor(position);
    int roll(AttributeKey key) =>
        (base[key] ?? Formulas.defaultGoalkeeping) +
        ageBonus +
        (tweaks[key] ?? 0) +
        _random.nextInt(9) -
        4;
    return Attributes.scattered(
      random: _random,
      pace: roll(AttributeKey.pace),
      shooting: roll(AttributeKey.shooting),
      passing: roll(AttributeKey.passing),
      dribbling: roll(AttributeKey.dribbling),
      defending: roll(AttributeKey.defending),
      physical: roll(AttributeKey.physical),
      goalkeeping: position == Position.gk
          ? roll(AttributeKey.goalkeeping)
          : Formulas.defaultGoalkeeping,
    );
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
    // 前年に国内カップを獲っていれば、順位に関係なく出られる。
    final viaCup = state.history.isNotEmpty &&
        state.history.last.cupStage.qualifiesContinental &&
        state.history.last.clubName == state.club.name;
    if (viaCup) return true;
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
  ///
  /// ローンに出ている間は「保有元に戻る」契約がこの位置に来る。
  /// 残留の選択肢は常に1つ提示する（無いと、失敗した瞬間に無所属になる）。
  TransferOffer renewalOffer(CareerState state) {
    if (state.onLoan) {
      final parent = state.parentClub!;
      return TransferOffer(
        club: parent,
        reason: 'ローンが明ける。${parent.name}に戻る。',
        salary: state.salary,
        role: _roleFor(state.player.overall, parent),
        years: max(1, state.contractYears),
        isRenewal: true,
        returning: true,
      );
    }
    final club = nextClubIfStaying(state);

    // 契約が残っているうちは、残留しても条件は動かない。1年減るだけ。
    //
    // 以前はここで毎年新しい契約年数を配っていたため、残留し続けると
    // 契約が永久に残り1年より短くならず、移籍の話が一度も来なかった
    // （100キャリアで平均0.13件）。契約は減るものとして扱う。
    if (state.contractYears > 1) {
      return TransferOffer(
        club: club,
        reason: '${club.name}との契約はあと${state.contractYears - 1}年ある。',
        salary: state.salary,
        role: _roleFor(state.player.overall, club),
        years: state.contractYears - 1,
        isRenewal: true,
        releaseClause: state.releaseClause,
      );
    }

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
    // 実力に見合う額（base）を軸にする。前の年俸に倍率を掛け続けると、
    // 良いシーズンが続くだけで年俸が指数で伸びる（100シーズン回して
    // 平均11億円、最大200億円になっていた）。
    // 下げ幅も緩めて、1年の不調で半減しないようにする。
    final target = base * performance * objectiveFactor * continentalFactor;
    final salary = _round(target.clamp(
      max(base * 0.6, state.salary * 0.7),
      max(base * 1.8, state.salary * 1.1),
    ));
    return TransferOffer(
      club: club,
      reason: '${club.name}が契約更改を提示した。',
      salary: salary,
      role: _roleFor(state.player.overall, club),
      years: extras.rollContractYears(),
      isRenewal: true,
      releaseClause: releaseClauseFor(state.reputation.marketValue),
    );
  }

  /// 契約に付く違約金。今の値札から決まる。
  ///
  /// 年俸を基準にしていた頃は、年俸の8倍＝市場価値の10倍以上になり、
  /// どれだけ伸びても一度も発動しなかった。値札の2.5倍なら、
  /// 伸びた選手は数年で追い越す。
  int releaseClauseFor(int marketValue) => _round(max(400, marketValue * 4));

  /// 違約金を超える評価になったか。ここを超えると契約が残っていても話が動く。
  bool clauseTriggered(CareerState state) {
    final clause = state.releaseClause;
    if (clause == null) return false;
    return state.reputation.marketValue >= clause;
  }

  /// シーズン終了時の移籍オファー。
  ///
  /// 良いシーズンを送るほど、強いクラブから声がかかる。代理人の人脈で
  /// 上限が伸びる。何もしなくても残留できるので、常に選択肢として提示する。
  List<TransferOffer> offersFor(CareerState state) {
    // ローン中は、買い取りの話が出るかどうかだけ。戻る契約は renewalOffer 側。
    if (state.onLoan) return _buyOutOffers(state);

    final offers = <TransferOffer>[];
    // 出番の無い若手には、試合に出るためのローンの話が来る。
    offers.addAll(_loanOffers(state));

    final clause = clauseTriggered(state);
    // 契約が残っている間は動けない。ただし違約金を追い越したときは別。
    if (state.contractYears > 1 && !clause) return offers;

    final stats = state.seasonStats;
    if (!clause) {
      if (stats.appearances < 10) return offers;
      if (stats.averageRating < Formulas.transferOfferRating) return offers;
    }
    return [...offers, ..._marketOffers(state)];
  }

  /// ローン先が買い取りに動くか。
  ///
  /// 買い取りオプションが付いていて、そのシーズンに結果を出したときだけ。
  /// 出せなければ、黙って保有元に戻ることになる。
  List<TransferOffer> _buyOutOffers(CareerState state) {
    final option = state.loanBuyOption;
    if (option == null) return const [];
    final stats = state.seasonStats;
    if (stats.appearances < 15 || stats.averageRating < 6.6) return const [];

    final salary = _round(state.salary * 1.15);
    return [
      TransferOffer(
        club: state.club,
        reason: '${state.club.name}が買い取りオプションを行使する構えを見せている。',
        salary: salary,
        role: _roleFor(state.player.overall, state.club),
        years: extras.rollContractYears(),
        fee: option,
        releaseClause: releaseClauseFor(state.reputation.marketValue),
      ),
    ];
  }

  /// 出番の無い若手に届くローンの話。
  ///
  /// 登録から外れている、力が足りない、出場が少ない。どれかに当てはまる
  /// 若手だけに来る。移籍と違って成績は問わない。出られないことが理由だから。
  List<TransferOffer> _loanOffers(CareerState state) {
    if (state.player.age > Formulas.loanMaxAge) return const [];
    // 先発で見る。途中出場だけを積み重ねている選手こそ、
    // 「出られる場所」を探す動機がある。
    final starts = state.leagueResults
        .where((r) => r.appearance == Appearance.start)
        .length;
    final stuck = !state.squadStatus.canPlay ||
        state.player.overall - state.club.strength < -6 ||
        starts < Formulas.loanStartsThreshold;
    if (!stuck) return const [];

    final country = World.byId(state.club.countryId);
    final tier = min(country.tiers, state.club.tier + 1);
    final clubs = World.buildLeague(country.id, tier)
        .where((c) => c.name != state.club.name)
        .toList()
      ..sort((a, b) => b.strength.compareTo(a.strength));
    if (clubs.isEmpty) return const [];

    final club = clubs[_random.nextInt(min(4, clubs.length))];
    // 買い取りオプションは半々。付いていると、出れば道が開ける。
    final option = _random.nextBool()
        ? _round(max(state.reputation.marketValue * 1.2, 300))
        : null;
    return [
      TransferOffer(
        club: club,
        reason: '${club.name}が期限付きでの獲得を打診してきた。試合に出られる。',
        salary: _round(state.salary * 0.85),
        role: '主力として使う',
        years: 1,
        loan: true,
        buyOption: option,
      ),
    ];
  }

  /// 移籍市場から届くオファー。
  List<TransferOffer> _marketOffers(CareerState state) {
    final reach =
        (state.player.overall * Formulas.transferReachFactor).round() +
            state.agent.reach;
    final origin = World.byId(state.club.countryId);
    final candidates = <TransferOffer>[];
    // 移籍金は値札そのもの。契約が短いほど安く買われる。
    final fee = _round(
        state.reputation.marketValue * (0.7 + state.contractYears * 0.2));

    // 声がかかる国。今の国と、代理人の人脈で届く範囲の国。
    for (final country in _reachableCountries(state)) {
      for (final tier in [1, 2]) {
        if (tier > country.tiers) continue;
        // 手の届く範囲の中から、格の近いクラブを選ぶ。
        //
        // 常に「届く中で一番強いクラブ」を出していた頃は、誰もが最短で
        // 強豪に行き着き、キャリアで平均2回リーグ優勝していた。
        // 大きく格下のクラブは声をかけてこないので、下も切る。
        final clubs = World.buildLeague(country.id, tier)
            .where((c) =>
                c.name != state.club.name &&
                c.strength <= reach &&
                c.strength >= state.player.overall - 14)
            .toList()
          ..sort((a, b) => b.strength.compareTo(a.strength));
        if (clubs.isEmpty) continue;
        final club = clubs[_random.nextInt(min(4, clubs.length))];

        final eligibility = Eligibility.report(
          nationality: state.player.nationality,
          club: club,
          origin: origin,
          caps: state.caps,
          professionalYears: state.professionalYears,
          marketValue: state.reputation.marketValue,
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
          fee: fee,
          releaseClause: releaseClauseFor(state.reputation.marketValue),
        ));
      }
    }

    // 晩年になると、古巣が最後の1年を過ごさないかと声をかけてくる。
    // 条件は良くないが、始まった場所で終われる。
    // 条件では選ばれない特別な話は、別に持っておく。年俸順に切ると
    // 「古巣からの薄給の誘い」が必ず消えてしまう。
    final special = <TransferOffer>[];
    final formerNames = {
      for (final h in state.history)
        if (h.clubName != state.club.name) h.clubName,
    };
    if (state.player.age >= Formulas.lastDanceAge &&
        formerNames.isNotEmpty &&
        _random.nextDouble() < 0.4) {
      final name = formerNames.first;
      final home = World.byId(state.history
          .lastWhere((h) => h.clubName == name)
          .countryId);
      final league = World.buildLeague(
          home.id, min(home.tiers, state.club.tier + 1));
      final club = league.firstWhere((c) => c.name == name,
          orElse: () => league.first);
      special.add(TransferOffer(
        club: club,
        reason: '古巣の$nameが、最後の1年をここで過ごさないかと言っている。',
        salary: _round(state.salary * 0.7),
        role: '経験を買われての加入',
        years: 1,
      ));
    }

    // 恩師が別のクラブで待っていることがある。条件は良く、起用も約束される。
    final mentorName = state.mentorManager;
    if (mentorName != null && candidates.isNotEmpty && _random.nextDouble() < 0.3) {
      final base = candidates.first;
      special.add(TransferOffer(
        club: base.club,
        reason: '${base.club.name}の監督に就任した恩師・$mentorNameが、'
            'あなたを呼んでいる。',
        salary: _round(base.salary * 1.15),
        role: '絶対的な主力',
        years: base.years,
        eligibility: base.eligibility,
        fee: base.fee,
        releaseClause: base.releaseClause,
      ));
    }

    // 良い条件の順に3件まで。並べすぎると選ぶのが作業になる。
    candidates.sort((a, b) => b.salary.compareTo(a.salary));
    return [...candidates.take(3), ...special];
  }

  /// 声がかかる国を決める。
  ///
  /// 今の国は常に対象。国外は「自分の格」と「代理人の人脈」で決まり、
  /// いきなり最上位リーグから声はかからない。
  List<Country> _reachableCountries(CareerState state) {
    final here = World.byId(state.club.countryId);
    // 上の国へ行くには、実力に加えて「名前が知られていること」が要る。
    //
    // 以前は総合力55から1段ずつ届いたので、普通に育てた選手の半数以上が
    // 最上位の国の1部に流れ着いていた。代表歴を条件に足して、
    // 格上の国は一段ハードルを上げる。
    final reachPrestige = (state.player.overall - 66) ~/ 7 +
        state.agent.reach ~/ 4 +
        (state.caps >= 10 ? 1 : 0);
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
    // 気性が荒いほど強気に出られる。代理人の腕とは別の要素。
    final chance = (Formulas.negotiationBase +
            state.agent.negotiation * Formulas.negotiationPerSkill +
            performance +
            state.player.personality.negotiationModifier)
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

  /// 代理人に売り込ませる。
  ///
  /// 待っていても声がかからない選手のための道。前金を払って動いてもらい、
  /// 人脈と交渉力で決まる確率で話を取ってくる。空振りなら金だけが減る。
  /// 失敗しうるからこそ、雇う代理人の選択に意味が出る。
  (bool, List<TransferOffer>) solicitOffers(CareerState state) {
    final cost = solicitCostFor(state);
    if (state.finances.savings < cost) return (false, const []);

    state.finances = state.finances.spend(cost);
    final chance = (0.15 +
            state.agent.reach * 0.04 +
            state.agent.negotiation * 0.05 +
            (state.seasonStats.averageRating - 6.4) * 0.1)
        .clamp(0.05, 0.85);
    if (_random.nextDouble() >= chance) return (false, const []);

    // 売り込みで取れるのは、待っていれば来た話より1段落ちる条件。
    final found = _marketOffers(state)
        .map((o) => o.copyWith(salary: _round(o.salary * 0.92)))
        .take(2)
        .toList();
    return (found.isNotEmpty, found);
  }

  /// 売り込みの前金（万円）。
  int solicitCostFor(CareerState state) =>
      max(100, _round(state.salary * 0.1));

  /// 代理人の手取り差し引き後の年俸。
  int takeHome(CareerState state, int salary) =>
      _round(salary * (1 - state.agent.feePercent / 100));

  int _round(num value) => (value / 10).round() * 10;

  /// 次のシーズンへ進む。受けたオファーのクラブと年俸で始める。
  CareerState advanceSeason(
    CareerState state, {
    required TransferOffer accepted,
    BodyPlan bodyPlan = BodyPlan.maintain,
  }) {
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
      cupStage: state.cupStage,
      worldCupStage: state.worldCupStage,
      onLoan: state.onLoan,
      overall: state.player.overall,
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

    // オフの肉体改造。体重が動き、筋力と機動力が入れ替わる。
    var nextPlayer = state.player.copyWith(
      age: state.player.age + 1,
      condition: Formulas.conditionMax,
      nationality: nationality,
      personality: person.evolve(state),
      physique: state.player.physique.afterOffseason(bodyPlan),
      attributes: _afterOffseason(state.player.attributes, bodyPlan),
    );
    // 限界突破。頭打ちのまま腐らせない代わりに、条件は厳しくしてある。
    var development = state.development;
    if (breaksThrough(state)) {
      nextPlayer = Player.rebuild(
        nextPlayer,
        attributes: nextPlayer.attributes,
        potential: nextPlayer.potential + Formulas.breakthroughGain,
      );
      development =
          development.copyWith(breakthroughs: development.breakthroughs + 1);
    }
    final stayed = accepted.club.name == state.club.name;

    // ローンの扱い。保有元はローンの間だけ持ち、戻るか買われるかで消える。
    final parentClub = accepted.loan ? (state.parentClub ?? state.club) : null;
    final releaseClause =
        accepted.returning ? state.releaseClause : accepted.releaseClause;

    // 称号・知名度・関係・お金は、シーズンを終えた時点で確定させる。
    final promoted = fateOf(state) == ClubFate.promoted;
    var reputation = state.reputation;
    for (final award in person.awardsFor(state, promoted: promoted)) {
      reputation = reputation.earn(award);
    }
    reputation = reputation.copyWith(
      fame: person.fameFor(state),
      marketValue: person.marketValueFor(state),
    );
    final finances = state.finances.afterSeason(
      salary: state.salary,
      agentFeePercent: state.agent.feePercent,
      staffCost: state.staff.costPerSeason,
      extraLivingRate: state.habits.livingCostExtra,
    );
    // 払えない専属は契約を切る。金の裏付けの無い環境は続かない。
    final staff = finances.savings < 0 ? const StaffTeam() : state.staff;
    var relations = person.updateRelations(state);
    // 高く買われた選手には、それだけの期待が乗る。信頼は最初から厚い。
    if (accepted.fee >= state.reputation.marketValue * 1.3 &&
        accepted.fee > 0) {
      relations = relations.bump(manager: 8);
    }

    // 監督。飛べば戦術が変わり、信頼は白紙に戻る。
    // 信頼の厚かった監督は「恩師」として覚えておく。
    var manager = state.manager ?? Manager.roll(_random);
    var mentorManager = state.mentorManager;
    final movedClub = resolved.name != state.club.name;
    if (movedClub || managerLeaves(state)) {
      if (state.relations.manager >= 75) mentorManager = manager.name;
      manager = Manager.roll(_random);
      relations = Relations(
        manager: 50,
        teammates: movedClub ? 45 : relations.teammates,
      );
    } else {
      manager = manager.aged();
    }

    // 同僚。移籍すれば総入れ替えで、呼吸も一から。
    final mates = movedClub
        ? rollTeammates(resolved)
        : (
            competitor: state.competitor ??
                Teammate.roll(_random,
                    kind: TeammateKind.rival, clubStrength: resolved.strength),
            partner: state.partner ??
                Teammate.roll(_random,
                    kind: TeammateKind.partner, clubStrength: resolved.strength),
            mentor: state.mentor ??
                Teammate.roll(_random,
                    kind: TeammateKind.mentor, clubStrength: resolved.strength),
          );

    // スポンサー・疲労・キャプテン・愛称・代表。シーズンの切れ目で動く。
    var sponsor = state.sponsor?.aged();
    if (sponsor != null && sponsor.expired) sponsor = null;
    final sponsorOffer = sponsor == null
        ? Sponsor.offerFor(
            fame: reputation.fame,
            random: _random,
            marketValue: reputation.marketValue,
          )
        : null;
    // スポンサー料は年俸とは別に入る。
    final withSponsor = sponsor == null
        ? finances
        : Finances(
            savings: finances.savings + sponsor.annual,
            lifestyle: finances.lifestyle,
          );

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
      menu: state.menu,
      drill: state.drill,
      staff: staff,
      habits: state.habits,
      development: development,
      manager: manager,
      directive: state.directive,
      competitor: mates.competitor,
      partner: mates.partner,
      mentor: mates.mentor,
      rival: state.rival?.advanced(_random, clubName: state.rival!.clubName),
      rehab: state.rehab,
      mentorManager: mentorManager,
      // 契約更改か移籍なら新しい年数。ただ残っただけなら1年減る。
      // ローンの間は保有元との契約が凍る。戻ってきた年から再び減り始める。
      contractYears: accepted.loan
          ? max(1, state.contractYears)
          : stayed && !accepted.isRenewal
              ? max(1, state.contractYears - 1)
              : accepted.years,
      parentClub: parentClub,
      releaseClause: releaseClause,
      loanBuyOption: accepted.loan ? accepted.buyOption : null,
      countryId: resolved.countryId,
      professionalYears: state.professionalYears + 1,
      continentalExperience: state.continentalExperience ||
          state.continentalStage.participated,
      objective: extras.objectiveFor(player: nextPlayer, club: resolved),
      continentalStage: ContinentalStage.none,
      cupStage: CupStage.none,
      worldCupStage: WorldCupStage.none,
      reputation: reputation,
      relations: relations,
      finances: withSponsor,
      // 稼ぎの使い道は、気持ちに小さく返ってくる。
      morale: state.morale.bump(state.finances.moraleShift),
      // 疲れはオフでだいたい抜けるが、歳を取るほど残る。
      fatigue: state.fatigue
          .afterOffseason(nextPlayer.age)
          .add(state.preseason.fatigue),
      preseason: state.preseason,
      captain: movedClub ? false : state.captain,
      // 腕章の話は、認められた選手にオフの間に来る。
      captaincyOffered: !movedClub && offersCaptaincy(state),
      squadNumber: movedClub
          ? squadNumberFor(nextPlayer.position, _random,
              senior: nextPlayer.overall >= 78)
          : state.squadNumber,
      nickname: state.nickname ?? nicknameFor(state, reputation.fame),
      sponsor: sponsor,
      sponsorOffer: sponsorOffer,
      charity: state.charity,
      nationalTeamId: state.nationalTeamId,
      seenEvents: state.seenEvents,
      // 見出しはキャリアの記録。シーズンを跨いでも消さない。
      news: state.news,
      backedUpYear: state.backedUpYear,
      autoRestBelow: state.autoRestBelow,
      focus: state.focus,
      // 累積警告はシーズンをまたぐと消える。出場停止は持ち越す。
      yellowCards: 0,
      suspension: state.suspension,
      // 改変の印は消さない。消すと、1年跨いだだけで普通の記録に見える。
      tampered: state.tampered,
      // 怪我はシーズンを跨いでも消えない。オフの間に少しは進む。
      injury: state.injury == null || state.injury!.matchesOut <= 4
          ? null
          : state.injury,
      caps: state.caps,
      internationalGoals: state.internationalGoals,
    );
  }

  /// 限界を超えるか。
  ///
  /// ポテンシャルに届いた選手が、まだ若く、身体を作り込み、試合を重ねている
  /// ときだけ起きる。ここを緩めると上限が飾りになる。
  bool breaksThrough(CareerState state) {
    final player = state.player;
    if (!player.atPotential) return false;
    if (player.age > Formulas.peakAge + 2) return false;
    if (player.personality.professionalism < 14) return false;
    if (state.development.experience < 300) return false;
    if (player.potential >= Formulas.maxAttribute) return false;
    return _random.nextDouble() <
        Formulas.breakthroughChance * player.traits.breakthroughFactor;
  }

  /// オフの肉体改造が能力に与える増減。
  ///
  /// 体重そのものは [Physique] が持つ。ここで動かすのは、増やした身体を
  /// 使えるようにする筋力と、絞って戻ってくるキレのほう。
  Attributes _afterOffseason(Attributes attributes, BodyPlan plan) =>
      switch (plan) {
        BodyPlan.bulk => attributes
            .bumpDetail(Detail.strength, 2)
            .bumpDetail(Detail.stamina, -1),
        BodyPlan.cut => attributes
            .bumpDetail(Detail.acceleration, 1)
            .bumpDetail(Detail.stamina, 1)
            .bumpDetail(Detail.strength, -1),
        BodyPlan.maintain => attributes,
      };

  /// 背番号を決める。ポジションらしい番号から引く。
  ///
  /// 若いうちは大きい番号しか空いていない。エースナンバーは、
  /// 実績を積んでクラブの中心になってから回ってくる。
  static int squadNumberFor(Position position, Random random,
      {bool senior = false}) {
    final classic = switch (position) {
      Position.gk => [1, 12, 21],
      Position.cb => [4, 5, 15],
      Position.sb => [2, 3, 26],
      Position.dm => [6, 16, 24],
      Position.cm => [8, 14, 18],
      Position.am => [10, 20, 23],
      Position.wg => [7, 11, 17],
      Position.st => [9, 19, 29],
    };
    if (senior) return classic.first;
    return classic[random.nextInt(classic.length)];
  }

  /// キャプテンの打診が来る条件。
  ///
  /// 監督にもロッカールームにも認められていて、若すぎないこと。
  /// 数字だけでは腕章は回ってこない。
  bool offersCaptaincy(CareerState state) =>
      !state.captain &&
      state.player.age >= 24 &&
      state.relations.manager >= 70 &&
      state.relations.teammates >= 65;

  /// 愛称。知名度が上がってから付く。
  ///
  /// 呼ばれ方が変わることが、有名になったということの実感になる。
  String? nicknameFor(CareerState state, int fame) {
    if (fame < 50) return null;
    final identity = state.development.identity;
    final base = switch (identity) {
      AttributeKey.pace => '弾丸',
      AttributeKey.shooting => '点取り屋',
      AttributeKey.passing => '司令塔',
      AttributeKey.dribbling => '仕掛け人',
      AttributeKey.defending => '壁',
      AttributeKey.physical => '猛牛',
      AttributeKey.goalkeeping => '門番',
      null => '${state.club.name}の心臓',
    };
    return base;
  }

  /// 引退後の道を、やってきたことから見立てる。
  SecondCareer secondCareerFor(CareerState state) {
    final p = state.player.personality;
    final totals = state.careerTotals;
    if (state.finances.savings >= 30000 && p.ambition >= 14) {
      return SecondCareer.entrepreneur;
    }
    if (state.captain && p.professionalism >= 13) return SecondCareer.manager;
    if (state.reputation.fame >= 60) return SecondCareer.pundit;
    if (p.professionalism >= 14) return SecondCareer.coach;
    if (totals.appearances >= 300) return SecondCareer.director;
    return SecondCareer.quiet;
  }

  /// 監督が代わるか。
  ///
  /// 成績が期待を下回ると飛ぶ。長くやっている監督ほど、次の1年で切られる。
  /// 代われば戦術が変わり、自分の立ち位置も変わる。
  bool managerLeaves(CareerState state) {
    final manager = state.manager;
    if (manager == null) return true;
    final expected = _expectedPosition(state);
    final under = state.leaguePosition - expected;
    final chance =
        (0.12 + under * 0.035 + manager.tenure * 0.05).clamp(0.05, 0.85);
    return _random.nextDouble() < chance;
  }

  /// そのクラブが本来居るべき順位。クラブの強さをリーグの中で見る。
  int _expectedPosition(CareerState state) {
    final sorted = [...state.league]
      ..sort((a, b) => b.strength.compareTo(a.strength));
    return sorted.indexWhere((c) => c.id == state.club.id) + 1;
  }

  /// 新しいクラブでの同僚を引き直す。
  ///
  /// 相方との呼吸は移籍で失われる。積み上げたものが移籍で消えるのは
  /// 現実の通りで、だから移籍が「良い話」だけではなくなる。
  ({Teammate competitor, Teammate partner, Teammate mentor}) rollTeammates(
          Club club) =>
      (
        competitor: Teammate.roll(_random,
            kind: TeammateKind.rival, clubStrength: club.strength),
        partner: Teammate.roll(_random,
            kind: TeammateKind.partner, clubStrength: club.strength),
        mentor: Teammate.roll(_random,
            kind: TeammateKind.mentor, clubStrength: club.strength),
      );

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
    // 国内カップは毎年ある。順位に関係なく全クラブが出る。
    state.cupStage = competitions.runDomesticCup(state);
    // 世界大会は4年に1度。代表に呼ばれている選手だけ。
    state.worldCupStage = Competitions.isWorldCupYear(state.year)
        ? competitions.runWorldCup(state, calledUp: state.calledUp)
        : WorldCupStage.none;
    if (state.worldCupStage.participated) {
      // 本大会は代表の試合として数える。
      state.caps += 3 + state.worldCupStage.points;
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
      cupStage: state.cupStage,
      worldCupStage: state.worldCupStage,
      onLoan: state.onLoan,
      overall: state.player.overall,
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
      continentalStage: state.continentalStage,
      caps: state.caps,
      internationalGoals: state.internationalGoals,
      // 改変の印は引退しても消さない。
      tampered: state.tampered,
      reputation: state.reputation,
      relations: state.relations,
      finances: state.finances.afterSeason(
        salary: state.salary,
        agentFeePercent: state.agent.feePercent,
        staffCost: state.staff.costPerSeason,
        extraLivingRate: state.habits.livingCostExtra,
      ),
      staff: state.staff,
      habits: state.habits,
      development: state.development,
      morale: state.morale,
      fatigue: state.fatigue,
      captain: state.captain,
      squadNumber: state.squadNumber,
      nickname: state.nickname,
      sponsor: state.sponsor,
      charity: state.charity,
      nationalTeamId: state.nationalTeamId,
      secondCareer: state.secondCareer ?? secondCareerFor(state),
      seenEvents: state.seenEvents,
      news: state.news,
      backedUpYear: state.backedUpYear,
      autoRestBelow: state.autoRestBelow,
      focus: state.focus,
      manager: state.manager,
      directive: state.directive,
      competitor: state.competitor,
      partner: state.partner,
      mentor: state.mentor,
      rival: state.rival,
      retired: true,
    );
  }
}
