import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/match_factor_engine.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_instruction.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/l10n/tr.dart';

/// 遊んで出てきた4件の指摘に対応する検証。
///
/// 1. 能力値と年齢が上がると契約更新できない
/// 2. クラブが成長してもスポンサー料が変わらない
/// 3. 選手特性とかが確認しにくい
/// 4. 試合への影響が分かりにくい
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 表示文字列を検証するので言語を固定する。SettingsController を
    // 通していないため、ここで指定したものがそのまま使われる。
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Player make({
    int age = 26,
    int attr = 50,
    int wage = 20,
    int fatigue = 20,
    int morale = 70,
    Position position = Position.st,
  }) {
    final p = Player(
      id: 'p$attr$age$wage',
      name: 'p',
      age: age,
      position: position,
      potential: 90,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, attr);
    }
    p.wage = wage;
    p.fatigue = fatigue;
    p.morale = morale;
    return p;
  }

  group('1. 契約更新の費用', () {
    test('残す方が、買い直すより必ず安い', () {
      // この不変条件が崩れると「更新できない」が形を変えて戻ってくる。
      // 前回、これを示していたテストを条件の方を緩めて通してしまい、
      // 高給の主力で問題が残った。今度は条件を守る側を直してある。
      for (final attr in [50, 65, 80, 90]) {
        for (final wage in [10, 50, 200, 500]) {
          final p = make(attr: attr, wage: wage);
          final total = ContractEngine.renewalCost(p) +
              ContractEngine.signingBonusFor(p);
          expect(total, lessThan(p.marketValue * 0.5),
              reason: '能力$attr・週俸$wage で、更新費が市場価値の半分を超えている');
        }
      }
    });

    test('週俸が高いほど手数料も高いが、市場価値による上限がある', () {
      // 更新のたびに要求週俸は上がる(最低希望額は現在の1.05〜1.20倍)。
      // 週俸だけに紐づけると、何度も更新した主力ほど残しにくくなる。
      expect(ContractEngine.renewalCost(make(wage: 40)),
          greaterThan(ContractEngine.renewalCost(make(wage: 10))));

      final inflated = make(attr: 50, wage: 500);
      expect(
        ContractEngine.renewalCost(inflated),
        lessThanOrEqualTo(
            (inflated.marketValue * ContractEngine.maxRenewalShareOfValue)
                .round()),
        reason: '週俸が膨らんでも、手数料は市場価値の一定割合を超えない',
      );
    });

    test('能力が上がるほど、以前の計算との差が大きくなる', () {
      // 以前は基本費用が市場価値の50%だった。能力が上がるほど市場価値が
      // 伸びるので、育てた選手ほど残しにくくなっていた。
      for (final attr in [50, 65, 80, 90]) {
        final p = make(attr: attr, wage: 20);
        final oldBase = (p.marketValue * 0.5).round();
        final newBase = ContractEngine.renewalCost(p);
        expect(newBase, lessThan(oldBase),
            reason: '能力$attr で以前より安くなっていない');
      }

      // 総合90では、以前の1/8以下になっている。
      final star = make(attr: 90, wage: 20);
      expect(ContractEngine.renewalCost(star) * 8,
          lessThan((star.marketValue * 0.5).round()));
    });
  });

  group('2. スポンサー料がクラブの成長に応じて変わる', () {
    test('上のディビジョンほど高く付く', () {
      int offerFor(int tier) =>
          SponsorEngine.generateOffers(70, tier: tier)[1].weeklyIncome;

      expect(offerFor(1), greaterThan(offerFor(3)));
      expect(offerFor(3), greaterThan(offerFor(5)));
      expect(offerFor(1), greaterThan(offerFor(5) * 2),
          reason: '1部と5部で倍以上の差が付かないと、昇格が返ってこない');
    });

    test('実績(監督の評価)が高いほど条件が良くなる', () {
      int offerFor(int reputation) => SponsorEngine.generateOffers(70,
          tier: 1, managerReputation: reputation)[1].weeklyIncome;

      expect(offerFor(90), greaterThan(offerFor(30)));
    });

    test('スタジアムが大きいほど条件が良くなる', () {
      int offerFor(int level) =>
          SponsorEngine.generateOffers(70, stadiumLevel: level)[1].weeklyIncome;

      expect(offerFor(8), greaterThan(offerFor(1)));
    });

    test('高額な提示ほど契約期間が短い(選ぶ意味がある)', () {
      final offers = SponsorEngine.generateOffers(70, tier: 1);
      final sorted = [...offers]
        ..sort((a, b) => a.weeklyIncome.compareTo(b.weeklyIncome));
      expect(sorted.first.yearsRemaining,
          greaterThan(sorted.last.yearsRemaining));
    });
  });

  group('給与予算が収入に連動する', () {
    test('収入が増えると上限も上がる', () {
      final poor = BoardEngine.wageBudgetFor(
          tier: 5, currentWeeklyWageBill: 100, weeklyIncome: 200);
      final rich = BoardEngine.wageBudgetFor(
          tier: 5, currentWeeklyWageBill: 100, weeklyIncome: 900);

      expect(rich, greaterThan(poor),
          reason: 'スタジアムやスポンサーを伸ばしても枠が動かないと、成長が返ってこない');
    });

    test('収入が乏しくても、ティアの基準は下回らない', () {
      final budget = BoardEngine.wageBudgetFor(
          tier: 1, currentWeeklyWageBill: 0, weeklyIncome: 0);
      expect(budget, greaterThanOrEqualTo(BoardEngine.wageBudgetBaseForTier(1)));
    });
  });

  group('4. 試合に効いている要素が読み取れる', () {
    Team teamWith(List<Player> players, {int familiarity = 80}) {
      final t = Team(
        id: 't',
        name: 'T',
        players: players,
        startingXI: players.map((p) => p.id).toList(),
      );
      t.formationFamiliarity[t.formation] = familiarity;
      return t;
    }

    test('習熟度は必ず出る', () {
      final factors = MatchFactorEngine.analyze(
          team: teamWith(const []), startingLineup: const []);
      expect(factors.map((f) => f.label).join(), contains('習熟'));
    });

    test('疲れている選手がいると、悪い要素として名前付きで出る', () {
      final tired = make(fatigue: 95)..name = '疲労太郎';
      final fresh = make(attr: 51, fatigue: 10);
      final factors = MatchFactorEngine.analyze(
        team: teamWith([tired, fresh]),
        startingLineup: [tired, fresh],
      );

      final fatigueFactor =
          factors.firstWhere((f) => f.label.contains('疲労'));
      expect(fatigueFactor.direction, FactorDirection.bad);
      expect(fatigueFactor.detail, contains('疲労太郎'),
          reason: '誰を休ませればいいかが分からないと、判断につながらない');
    });

    test('全員元気なら良い要素として出る', () {
      final p = make(fatigue: 10);
      final factors = MatchFactorEngine.analyze(
          team: teamWith([p]), startingLineup: [p]);
      expect(factors.firstWhere((f) => f.label.contains('疲労')).direction,
          FactorDirection.good);
    });

    test('個別指示を出していなければ、その項目は出ない', () {
      final p = make();
      final factors = MatchFactorEngine.analyze(
          team: teamWith([p]), startingLineup: [p]);
      expect(factors.any((f) => f.label.contains('指示')), isFalse,
          reason: '関係のない項目まで並べると、見るべきものが埋もれる');
    });

    test('個別指示を出すと、攻守どちらに寄せているかが出る', () {
      final p = make()..instruction = PlayerInstruction.getForward;
      final factors = MatchFactorEngine.analyze(
          team: teamWith([p]), startingLineup: [p]);
      final f = factors.firstWhere((f) => f.label.contains('指示'));
      expect(f.detail, contains('攻撃'));
    });

    test('習熟度が低いと悪い要素として出る', () {
      final p = make();
      final low = MatchFactorEngine.analyze(
          team: teamWith([p], familiarity: 20), startingLineup: [p]);
      final high = MatchFactorEngine.analyze(
          team: teamWith([p], familiarity: 95), startingLineup: [p]);

      expect(low.first.direction, FactorDirection.bad);
      expect(high.first.direction, FactorDirection.good);
    });

    test('出している数値は、試合計算が実際に使っているものと一致する', () {
      // それらしい指標を出しても、結果と結びついていなければ判断に使えない。
      final p = make();
      final team = teamWith([p], familiarity: 60);
      final factors =
          MatchFactorEngine.analyze(team: team, startingLineup: [p]);

      expect(factors.first.detail,
          contains(team.familiarityFactor.toStringAsFixed(2)));
    });
  });
}
