import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/appearance_fee_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 年俸・市場価値・引退・出場手当を、実際の欧州サッカーに近づけた変更
/// (2026-11-23)の検査。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make({
    required int age,
    int overall = 60,
    int potential = 60,
    Position position = Position.mc,
  }) =>
      Player(
        id: 'p$age$overall$potential${position.name}',
        name: 'テスト',
        age: age,
        position: position,
        attributes: {for (final k in AttributeKeys.all) k: overall},
        potential: potential,
      );

  group('年俸は今の能力と経験(年齢)から', () {
    setUp(() => setHomeWageLevel(LeagueTheme.england, 1));

    test('同じ能力なら、19歳は32歳より安い(以前は約4.6倍高かった)', () {
      final young = make(age: 19, potential: 85);
      final veteran = make(age: 32);
      expect(young.overall, veteran.overall);
      // 移籍金は若手のほうが高い(伸びしろと若さ)。
      expect(young.marketValue, greaterThan(veteran.marketValue * 3));
      // 年俸は経験のあるほうが高い。
      expect(young.fairWeeklyWage(), lessThan(veteran.fairWeeklyWage()));
      expect(young.fairWeeklyWage() / veteran.fairWeeklyWage(),
          inInclusiveRange(0.45, 0.7));
    });

    test('伸びしろは年俸に効かない(移籍金だけに効く)', () {
      final low = make(age: 21, potential: 60);
      final high = make(age: 21, potential: 90);
      expect(high.marketValue, greaterThan(low.marketValue));
      expect(high.fairWeeklyWage(), low.fairWeeklyWage());
    });

    test('経験の係数は20代後半〜30代前半が高く、30代半ばからやや下がる', () {
      expect(wageExperienceFactor(19), lessThan(wageExperienceFactor(24)));
      expect(wageExperienceFactor(24), lessThan(wageExperienceFactor(29)));
      expect(wageExperienceFactor(36), lessThan(wageExperienceFactor(31)));
      expect(wageExperienceFactor(36), greaterThan(0.8));
      // 誕生日で大きく跳ねない。
      for (var a = 17; a < 40; a++) {
        final r = wageExperienceFactor(a + 1) / wageExperienceFactor(a);
        expect(r, inInclusiveRange(0.9, 1.15), reason: '$a→${a + 1}歳');
      }
    });

    test('国・部の水準はそのまま掛かる', () {
      final p = make(age: 27, overall: 75);
      final en = p.fairWeeklyWage(1.0);
      expect(p.fairWeeklyWage(0.45), closeTo(en * 0.45, 2));
    });

    test('作ったばかりの選手の週俸は、見合う週俸', () {
      final p = PlayerGenerator.generate(
          position: Position.st, strengthTier: 70, ageOverride: 20);
      expect(p.wage, p.fairWeeklyWage());
    });

    test('選手全体の人件費は、市場価値から出していた頃と大きく変わらない', () {
      var byAbility = 0, byValue = 0;
      for (var rep = 0; rep < 20; rep++) {
        for (final tier in [45, 55, 65, 75, 85]) {
          final t = PlayerGenerator.generateSquad(
              id: 'w$rep$tier', name: 'x', strengthTier: tier);
          for (final p in t.players) {
            byAbility += p.fairWeeklyWage(1.0);
            byValue += weeklyWageForValue(p.marketValue, 1.0);
          }
        }
      }
      expect(byAbility / byValue, inInclusiveRange(0.85, 1.15));
    });
  });

  group('市場価値の年齢とポジションの係数', () {
    test('年齢の係数は曲線で、誕生日の一晩で大きく落ちない', () {
      for (var a = 17; a < 40; a++) {
        final now = marketValueAgeFactor(a);
        final next = marketValueAgeFactor(a + 1);
        expect(next, lessThanOrEqualTo(now), reason: '$a→${a + 1}歳');
        // 以前は31歳の誕生日に半分(0.8→0.4)になった。
        expect(next / now, greaterThan(0.8), reason: '$a→${a + 1}歳');
      }
      expect(marketValueAgeFactor(20), closeTo(1.4, 0.05));
      expect(marketValueAgeFactor(34), lessThan(0.5));
    });

    test('キーパー・センターバックは安く、フォワードは高い', () {
      expect(marketValuePositionFactor(Position.gk), closeTo(0.6, 0.05));
      expect(marketValuePositionFactor(Position.dc), closeTo(0.85, 0.05));
      expect(marketValuePositionFactor(Position.st), closeTo(1.2, 0.05));
      final gk = make(age: 26, overall: 75, position: Position.gk);
      final st = make(age: 26, overall: 75, position: Position.st);
      expect(gk.marketValue, lessThan(st.marketValue));
      // 年俸はポジションによらない(能力と経験だけ)。
      expect(gk.fairWeeklyWage(), st.fairWeeklyWage());
    });

    test('標準の編成で、ポジションの係数の平均はほぼ1', () {
      var sum = 0.0, n = 0;
      PlayerGenerator.compositionFor(60).forEach((pos, count) {
        sum += marketValuePositionFactor(pos) * count;
        n += count;
      });
      expect(sum / n, closeTo(1.0, 0.05));
    });
  });

  group('引退はポジションでずれる', () {
    test('キーパーは34歳まで引退せず、同じ年のフォワードより続けやすい', () {
      for (final age in [32, 33, 34]) {
        expect(
            RetirementEngine.retirementChance(
                make(age: age, overall: 50, position: Position.gk)),
            0.0,
            reason: '$age歳のキーパー');
      }
      final gk = make(age: 36, overall: 50, position: Position.gk);
      final st = make(age: 36, overall: 50, position: Position.st);
      expect(RetirementEngine.retirementChance(gk), greaterThan(0.0));
      expect(RetirementEngine.retirementChance(gk),
          lessThan(RetirementEngine.retirementChance(st)));
      // 31歳までは誰も引退しない(サイドの選手も)。
      expect(
          RetirementEngine.retirementChance(
              make(age: 31, overall: 50, position: Position.mr)),
          0.0);
    });
  });

  group('出場手当は途中出場・カップ戦にも', () {
    MatchEvent sub(String teamId, Player out, Player incoming) => MatchEvent(
          minute: 60,
          teamId: teamId,
          type: MatchEventType.substitution,
          scorerId: incoming.id,
          scorerName: incoming.name,
          assistId: out.id,
          assistName: out.name,
        );

    test('先発は満額、途中出場は半額、出ていない控えは払わない', () {
      final team = PlayerGenerator.generateSquad(
          id: 'fee', name: 'Fee FC', strengthTier: 60);
      for (final p in team.players) {
        p.appearanceFee = 20;
      }
      final starters = [for (final p in team.players.take(11)) p.id];
      team.startingXI = [...starters];
      final bench =
          team.players.where((p) => !starters.contains(p.id)).toList();
      final out = team.players.firstWhere((p) => p.id == starters.first);
      final incoming = bench.first;
      final r = MatchResult(
        matchday: 1,
        homeTeamId: team.id,
        awayTeamId: 'other',
        homeGoals: 0,
        awayGoals: 0,
        events: [
          sub(team.id, out, incoming),
          sub('other', out, bench[1]), // 相手の交代は数えない
        ],
      );
      expect(AppearanceFeeEngine.feesFor(team, r), 11 * 20 + 10);
      expect(AppearanceFeeEngine.feesFor(team, r, includeStarters: false), 10);

      // ライブの交代で先発の指定が入れ替わっていても、二重に払わない。
      team.startingXI = [
        for (final id in starters) id == out.id ? incoming.id : id,
      ];
      expect(AppearanceFeeEngine.feesFor(team, r), 11 * 20 + 10);
    });

    test('カップ戦(スーパーカップ)の試合のあとに出場手当を払う', () async {
      final game = GameState();
      await game.startNewGame('手当FC');
      final s = game.save!;
      for (final p in game.userTeam.players) {
        p.appearanceFee = 10;
      }
      final opponent = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      s.pendingSuperCup = CupMatch(
        round: 1,
        homeTeamId: game.userTeam.id,
        awayTeamId: opponent.id,
      );
      int fees() =>
          s.ledgerFor(s.league.season).of(LedgerCategory.appearanceFees);
      final before = fees();
      final result = await game.playSuperCup();
      expect(result, isNotNull);
      final paid = before - fees();
      expect(paid, AppearanceFeeEngine.feesFor(game.userTeam, result!));
      expect(paid, greaterThanOrEqualTo(11 * 10));
    });
  });
}
