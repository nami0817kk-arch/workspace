import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/data/glossary_entries.dart';
import 'package:soccer_manager/data/guide_sections.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/screens/club_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/squad_table.dart';

/// 品質改善の13回目(2026-11-23): 1.2.0 の掲載画像を撮ったときに見つかった
/// 画面の不具合(補強の候補を出す人の呼び名・スタッフの得意分野の札・
/// クラブのタブの上の集計・人数の桁区切り・契約の列・施設のボタンの英語・
/// iPad の移籍画面の空き)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  StaffMember staff(String id, StaffRole role, StaffSpecialty sp) =>
      StaffMember(
        id: id,
        name: '担当$id',
        age: 40,
        role: role,
        attributes: {for (final a in StaffAttribute.values) a: 10},
        wage: 5,
        specialty: sp,
      );

  Future<(GameState, SettingsController)> start(WidgetTester tester,
      {Size size = const Size(1704, 786)}) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('十三FC');
    });
    Tr.language = AppLanguage.japanese;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return (game, settings);
  }

  Future<void> pump(WidgetTester tester, GameState game,
      SettingsController settings, Widget home) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: Locale(Tr.isEnglish ? 'en' : 'ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('1. 補強の候補を出すのは監督(SD がいても)', () {
    testWidgets('SD を雇っていても、移籍の最初の札は「監督の補強案」', (tester) async {
      final (game, settings) = await start(tester);
      game.save!.infrastructure.staff[StaffRole.sportingDirector] =
          staff('sd', StaffRole.sportingDirector, StaffSpecialty.balanced);
      expect(game.currentSd, isNotNull);
      await pump(tester, game, settings, const TransferScreen());
      // 2026-11-24 に、タブを「候補」にまとめ、中の札を「監督の補強案」にした
      // (経営の「監督からの提案」と紛れない名前)。
      expect(find.text('監督の補強案'), findsOneWidget);
      expect(find.text('SDの案'), findsNothing);
      // SD の方針のカードは残る(任せるのは別の役目)。
      expect(find.textContaining('SD(担当sd)に補強を任せる'), findsOneWidget);
      await tester.pump(GameState.persistDebounce);
    });

    testWidgets('英語でも同じ呼び名(DoF shortlist は出ない)', (tester) async {
      final (game, settings) = await start(tester);
      Tr.language = AppLanguage.english;
      game.save!.infrastructure.staff[StaffRole.sportingDirector] =
          staff('sd', StaffRole.sportingDirector, StaffSpecialty.balanced);
      await pump(tester, game, settings, const TransferScreen());
      expect(find.text("Manager's signing picks"), findsOneWidget);
      expect(find.text('DoF shortlist'), findsNothing);
      expect(find.text('Proposals'), findsNothing);
      await tester.pump(GameState.persistDebounce);
    });

    testWidgets('状況の「次にやること」も監督から(日英)', (tester) async {
      final (game, _) = await start(tester);
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        final msgs = NextActionAdvisor.all(game.save!, game.userTeam,
                hasSigningProposals: true)
            .map((a) => a.message)
            .toList();
        final m = msgs.firstWhere(
            (s) => s.contains('補強の候補') || s.contains('signing candidates'));
        expect(m, Tr.isEnglish ? contains('Your manager') : contains('監督から'));
        expect(m, isNot(contains('SD')));
        expect(m, isNot(contains('DoF')));
      }
    });

    test('用語集・ガイドに SD が候補を出すという書き方が無い', () {
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        final texts = [
          for (final e in glossaryEntries) '${e.term} ${e.description}',
          for (final s in guideSections) ...[
            s.overview,
            for (final t in s.topics) '${t.title} ${t.description}',
          ],
        ].join('\n');
        expect(texts, isNot(contains('SDの案')));
        expect(texts, isNot(contains('DoF shortlist')));
        expect(texts, isNot(contains('Proposals or Search')));
      }
    });
  });

  group('2. スタッフの得意分野は役に合うものだけ', () {
    test('ユースコーチ以外は札を出さない(値は持ったまま)', () {
      for (final role in StaffRole.values) {
        final s = staff('x', role, StaffSpecialty.attacking);
        expect(
            s.shownSpecialty,
            role == StaffRole.youthCoach
                ? StaffSpecialty.attacking
                : StaffSpecialty.balanced,
            reason: role.name);
      }
    });

    test('保存済みのスタッフ(攻撃のスカウト)にも効く', () {
      final saved =
          staff('old', StaffRole.scout, StaffSpecialty.attacking).toJson();
      final loaded = StaffMember.fromJson(saved);
      expect(loaded.specialty, StaffSpecialty.attacking);
      expect(loaded.shownSpecialty, StaffSpecialty.balanced);
    });

    testWidgets('スタッフ画面: スカウト・フィジオに「攻撃」の札が付かない', (tester) async {
      final (game, settings) =
          await start(tester, size: const Size(1704, 8000));
      final infra = game.save!.infrastructure;
      infra.staff[StaffRole.scout] =
          staff('sc', StaffRole.scout, StaffSpecialty.attacking);
      infra.staff[StaffRole.physio] =
          staff('ph', StaffRole.physio, StaffSpecialty.attacking);
      infra.staff[StaffRole.youthCoach] =
          staff('yc', StaffRole.youthCoach, StaffSpecialty.physical);
      game.save!.staffCandidates.clear();
      await pump(
          tester, game, settings, const ClubScreen(section: ClubSection.staff));
      expect(find.widgetWithText(Chip, '攻撃'), findsNothing);
      expect(find.widgetWithText(Chip, 'フィジカル'), findsOneWidget);
      await tester.pump(GameState.persistDebounce);
    });
  });

  group('3. 充実度・スタッフの年俸はスタッフのタブだけ', () {
    testWidgets('施設・ファンと街のタブには出ない', (tester) async {
      final (game, settings) = await start(tester);
      for (final section in ClubSection.values) {
        await pump(tester, game, settings, ClubScreen(section: section));
        final expected =
            section == ClubSection.staff ? findsOneWidget : findsNothing;
        expect(find.byKey(const ValueKey('club-staff-summary-level')), expected,
            reason: section.name);
        expect(find.byKey(const ValueKey('club-staff-summary-wages')), expected,
            reason: section.name);
      }
      await tester.pump(GameState.persistDebounce);
    });
  });

  group('4. 人数の桁区切り', () {
    test('formatCount', () {
      expect(formatCount(12000), '12,000');
      expect(formatCount(950), '950');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount(-4500), '-4,500');
    });

    testWidgets('スタジアムの欄の人数に区切りがある(日英)', (tester) async {
      final (game, settings) = await start(tester);
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        await pump(tester, game, settings,
            const ClubScreen(section: ClubSection.facilities));
        final cap = ClubInfrastructure.stadiumCapacity(
            game.save!.infrastructure.facilityLevel(FacilityType.stadium));
        final label = Tr.isEnglish ? 'holds ' : 'いま: ';
        final text = tester
            .widgetList<Text>(find.textContaining(label))
            .map((t) => t.data ?? '')
            .firstWhere((s) => s.contains(formatCount(cap)));
        expect(text, isNot(contains('$cap')));
        expect(RegExp(r'\d{4,}').hasMatch(text), isFalse, reason: text);
      }
      await tester.pump(GameState.persistDebounce);
    });
  });

  group('5. 選手一覧の契約の列', () {
    test('満了の年は4桁(年数に読めない)', () {
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        expect(ContractEngine.untilTinyLabel(2030), '2030');
        expect(ContractEngine.untilTinyLabel(2030), isNot(contains('年')));
        expect(ContractEngine.untilTinyLabel(2030), isNot(contains("'")));
      }
    });

    testWidgets('表の見出しは「満了」で、列は西暦', (tester) async {
      final (game, settings) = await start(tester);
      final players = game.userTeam.players.where((p) => !p.isLoan).toList();
      await pump(
          tester,
          game,
          settings,
          Scaffold(
            body: SquadTable(
              players: players,
              startingIds: const {},
              onTap: (_) {},
            ),
          ));
      expect(find.textContaining('満了'), findsOneWidget);
      final p = players.first;
      final cell =
          tester.widget<Text>(find.byKey(ValueKey('squad-table-term-${p.id}')));
      expect(cell.data, '${p.contractEndYear}');
      await tester.pump(GameState.persistDebounce);
    });
  });

  group('6. 施設のボタンの英語', () {
    testWidgets('"Upgrade for X" で、(Build cost) を後ろに付けない', (tester) async {
      final (game, settings) = await start(tester);
      Tr.language = AppLanguage.english;
      await pump(tester, game, settings,
          const ClubScreen(section: ClubSection.facilities));
      expect(find.textContaining('(Build cost)'), findsNothing);
      expect(find.textContaining('Upgrade for '), findsWidgets);
      await tester.pump(GameState.persistDebounce);
    });
  });

  group('7. iPad の移籍画面の空き', () {
    testWidgets('候補の下に「探す」「注目」への入り口があり、押すと切り替わる', (tester) async {
      // iPad の横画面(1366x1024)。
      final (game, settings) =
          await start(tester, size: const Size(2732, 2048));
      await pump(tester, game, settings, const TransferScreen());
      expect(
          find.byKey(const ValueKey('transfer-more-targets')), findsOneWidget);
      final hint = find.byKey(const ValueKey('transfer-more-targets'));
      await tester.tap(find.descendant(
          of: hint, matching: find.widgetWithText(OutlinedButton, '探す')));
      await tester.pumpAndSettle();
      // 「探す」のタブの中身(該当N人)が出ている。
      expect(find.textContaining('該当'), findsWidgets);
      await tester.pump(GameState.persistDebounce);
    });
  });
}
