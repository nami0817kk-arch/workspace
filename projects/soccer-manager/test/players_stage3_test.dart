import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/contract_terms.dart';
import 'package:soccer_manager/logic/rating_words.dart';
import 'package:soccer_manager/models/contract_negotiation.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/screens/registration_rules_screen.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 画面の直し 第3段(選手)の中身の検査(2026-11-25)。
///
/// - 契約の交渉の項目(サイン料・出来高・昇給・リリース条項・降格/昇格の
///   条項・序列の約束)が、選手の受け入れと契約の中身に効く
/// - 選手の新しい項目(条項・経歴・移籍の歴)が古いセーブからも読める
/// - 登録ルールの「今 / 上限 / あと何人」
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('三段FC');
    game.save!.budget = 1 << 40;
    return game;
  }

  Player renewable(GameState game) => (game.userTeam.players
          .where((p) => game.renewalBlockReason(p) == null && !p.isLoan)
          .toList()
        ..sort((a, b) => a.contractEndYear.compareTo(b.contractEndYear)))
      .first;

  group('条件の値打ち', () {
    final p = Player(
        id: 'x', name: 'X', age: 25, position: Position.st, potential: 70)
      ..wage = 100;
    const base = ContractTerms(wage: 100, endYear: 2030);
    int v(ContractTerms t) => ContractTermsEngine.extrasWeekly(p, t,
        requiredBonus: 0, defaultRelegationCutPct: 40, years: 3);

    test('出来高・昇給・軽い降格の条項・昇格の条項・安いリリース条項は喜ぶ', () {
      expect(v(base), 0);
      expect(v(base.copyWith(goalBonus: 50)), greaterThan(0));
      expect(v(base.copyWith(raisePct: 10)), greaterThan(0));
      expect(v(base.copyWith(relegationCutPct: () => 0)), greaterThan(0));
      expect(v(base.copyWith(relegationCutPct: () => 50)), lessThan(0),
          reason: '既定より重い降格の条項は嫌がる');
      expect(v(base.copyWith(promotionRisePct: 20)), greaterThan(0));
      expect(v(base.copyWith(releaseClause: () => p.marketValue)),
          greaterThan(v(base.copyWith(releaseClause: () => p.marketValue * 5))),
          reason: '安い条項ほど喜ぶ');
    });

    test('求めるサイン料より少なければ値打ちが下がる', () {
      int withBonus(int bonus) => ContractTermsEngine.extrasWeekly(
          p, base.copyWith(signingBonus: bonus),
          requiredBonus: 5200, defaultRelegationCutPct: 40, years: 2);
      expect(withBonus(5200), 0);
      expect(withBonus(0), lessThan(0));
      expect(withBonus(10400), greaterThan(0));
    });

    test('昇給は契約の総額に入る', () {
      expect(ContractTermsEngine.totalSalary(base, 3), 100 * 52 * 3);
      expect(ContractTermsEngine.totalSalary(base.copyWith(raisePct: 10), 3),
          greaterThan(100 * 52 * 3));
    });
  });

  test('更新: 出来高を足すと、要求より低い年俸でも合意し、条項が契約に入る', () async {
    final game = await newGame();
    final p = renewable(game);
    game.startContractNegotiation(p.id);
    final n = game.pendingContractNegotiation!;
    final base = game.renewalBaseline(p, n: n);
    // 選手が受け入れる最低の年俸を1だけ割る額。年俸だけなら対案が来る。
    final low = ContractEngine.minimumAcceptableWage(p) - 1;
    final offer = base.copyWith(
        wage: low,
        goalBonus: low * 3,
        raisePct: 15,
        relegationCutPct: () => 0,
        promotionRisePct: 30,
        releaseClause: () => p.marketValue * 2);
    // 最低額を1割っているので、出来高などの値打ちが1以上あれば届く。
    // 年俸の安い選手に当たると値打ちがちょうど1になることがあり、
    // 「1より大きい」では乱数でたまに落ちていた(2026-11-26)。
    expect(game.renewalExtrasWeekly(p, offer), greaterThanOrEqualTo(1));
    final r = await game.offerContractTerms(offer);
    expect(r, ContractOfferResult.accepted);
    expect(p.wage, low);
    expect(p.goalBonus, low * 3);
    expect(p.raisePct, 15);
    expect(p.relegationCutPct, 0);
    expect(p.promotionRisePct, 30);
    expect(p.releaseClause, isNotNull);
    expect(n.playerId, p.id);
  });

  test('更新: 何も足さず年俸だけなら、これまでと同じ(offerContractWage)', () async {
    final game = await newGame();
    final p = renewable(game);
    game.startContractNegotiation(p.id);
    final want = game.pendingContractNegotiation!.counterWage;
    final r = await game.offerContractWage(want);
    expect(r, ContractOfferResult.accepted);
    expect(p.wage, want);
    expect(p.goalBonus, 0);
    expect(p.raisePct, 0);
  });

  test('更新: 序列の約束を上げると要求が上がり、合意すると序列が変わる', () async {
    final game = await newGame();
    final p = renewable(game)..squadStatus = SquadStatus.rotation;
    game.startContractNegotiation(p.id);
    final before = game.pendingContractNegotiation!.counterWage;
    game.setNegotiationTerms(promise: SquadStatus.keyPlayer);
    final after = game.pendingContractNegotiation!.counterWage;
    expect(after, greaterThan(before));
    final base = game.renewalBaseline(p, n: game.pendingContractNegotiation);
    expect(base.promise, SquadStatus.keyPlayer);
    final r = await game.offerContractTerms(base.copyWith(wage: after));
    expect(r, ContractOfferResult.accepted);
    expect(p.squadStatus, SquadStatus.keyPlayer);
    expect(p.promisedStatus, SquadStatus.keyPlayer);
  });

  test('交渉の序列の約束はセーブに残り、古いセーブ(項目なし)も読める', () {
    final n = ContractNegotiation(
        playerId: 'a',
        initialWage: 1,
        offeredWage: 1,
        counterWage: 2,
        promise: SquadStatus.keyPlayer);
    expect(ContractNegotiation.fromJson(n.toJson()).promise,
        SquadStatus.keyPlayer);
    final old = n.toJson()..remove('promise');
    expect(ContractNegotiation.fromJson(old).promise, isNull);
  });

  test('選手の条項・経歴・移籍の歴はセーブに残り、古いセーブも読める', () {
    final p = Player(
        id: 'p1', name: 'P', age: 22, position: Position.mc, potential: 70)
      ..relegationCutPct = 20
      ..promotionRisePct = 10
      ..careerLog.add(const PlayerCareerLine(
          seasonEndYear: 2027, club: 'A', apps: 30, goals: 4, rating: 6.95))
      ..moveLog.add(PlayerMoveLine(
          date: DateTime(2026, 8, 1),
          from: 'A',
          to: 'B',
          kind: PlayerMoveKind.transfer,
          fee: 1200));
    final q = Player.fromJson(p.toJson());
    expect(q.relegationCutPct, 20);
    expect(q.promotionRisePct, 10);
    expect(q.careerLog.single.apps, 30);
    expect(q.careerLog.single.rating, closeTo(6.95, 0.001));
    expect(q.careerLog.single.seasonLabel, '2026-27');
    expect(q.moveLog.single.to, 'B');
    expect(q.moveLog.single.fee, 1200);
    expect(q.moveLog.single.date, DateTime(2026, 8, 1));

    final old = p.toJson()
      ..remove('relegationCutPct')
      ..remove('promotionRisePct')
      ..remove('careerLog')
      ..remove('moveLog');
    final r = Player.fromJson(old);
    expect(r.relegationCutPct, isNull);
    expect(r.promotionRisePct, 0);
    expect(r.careerLog, isEmpty);
    expect(r.moveLog, isEmpty);
    // 空なら書き出さない(セーブを大きくしない)。
    final plain = Player(
        id: 'p2', name: 'Q', age: 22, position: Position.mc, potential: 70);
    expect(plain.toJson().containsKey('careerLog'), isFalse);
    expect(plain.toJson().containsKey('relegationCutPct'), isFalse);
  });

  test('季の終わりに、自分のリーグの選手の経歴へ1行足す(二重には足さない)', () async {
    final game = await newGame();
    await game.playNextMatchday();
    if (game.isHalfTime) await game.playSecondHalf();
    game.debugRecordCareerLines();
    game.debugRecordCareerLines();
    final p = game.userTeam.players.first;
    final lines = p.careerLog
        .where((l) => l.seasonEndYear == Player.contractClockYear)
        .toList();
    expect(lines, hasLength(1));
    expect(lines.single.club, game.userTeam.name);
    final other = game.save!.league.teams
        .firstWhere((t) => t.id != game.save!.userTeamId);
    expect(other.players.first.careerLog, isNotEmpty,
        reason: '他クラブの選手にも付く(詳しい画面の経歴)');
  });

  test('昇格の条項は、昇格したときだけ年俸を上げる', () async {
    final game = await newGame();
    final p = game.userTeam.players.firstWhere((x) => !x.isLoan);
    p.promotionRisePct = 20;
    final wage = p.wage;
    game.debugApplyPromotionWageClause(3, 3);
    expect(p.wage, wage);
    game.debugApplyPromotionWageClause(3, 2);
    expect(p.wage, (wage * 1.2).round());
  });

  test('降格の条項は、選手ごとに決めた割合が国の既定より先', () async {
    final game = await newGame();
    final team = game.userTeam;
    final a = team.players.where((x) => !x.isLoan).first;
    final b = team.players.where((x) => !x.isLoan && x.id != a.id).first;
    a.relegationCutPct = 0;
    final wa = a.wage, wb = b.wage;
    game.debugApplyRelegationWageClause([team], fromTier: 1);
    expect(a.wage, wa, reason: '「下げない」と決めた選手は下がらない');
    expect(b.wage, lessThanOrEqualTo(wb));
  });

  test('登録ルール: 項目ごとに今・上限・あと何人', () async {
    final game = await newGame();
    final lines = RegistrationRulesScreen.linesFor(game);
    final senior = lines.first;
    expect(senior.limit, 25);
    expect(senior.room, 25 - senior.now);
    expect(senior.broken, senior.now > 25);
    final total = lines.firstWhere((l) => l.limit == maxSquadSize);
    expect(total.now, game.userTeam.players.length);
    final minimum = lines.last;
    expect(minimum.isMinimum, isTrue);
    expect(minimum.room, game.userTeam.players.length - minSquadSize);
  });

  test('伸びしろ・調子の言葉', () {
    Tr.language = AppLanguage.japanese;
    expect(RatingWords.growthRoomLevel(60, 90), 3);
    expect(RatingWords.growthRoomLevel(88, 90), 0);
    expect(RatingWords.form(null), '—');
    expect(RatingWords.form(7.5), '絶好調');
    expect(RatingWords.form(6.0), 'ふつう');
    expect(RatingWords.form(5.5), '不調');
  });

  test('他クラブの選手も探せ、伸びしろは見えない', () async {
    final game = await newGame();
    final other = game.save!.league.teams
        .firstWhere((t) => t.id != game.save!.userTeamId);
    final p = other.players.first;
    expect(game.anyPlayerById(p.id), same(p));
    expect(game.clubOfPlayer(p.id)?.id, other.id);
    expect(game.isMyPlayer(p.id), isFalse);
    expect(game.growthRoomLevelFor(p), isNull);
    final mine = game.userTeam.players.first;
    expect(game.growthRoomLevelFor(mine), isNotNull);
    final similar = game.similarPlayers(mine);
    expect(similar.every((s) => s.player.position.group == mine.position.group),
        isTrue);
    expect(ContractEngine.untilLabel(p.contractEndYear), isNotEmpty);
  });
}
