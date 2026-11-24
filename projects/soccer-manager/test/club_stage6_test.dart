import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/staff_terms.dart';
import 'package:soccer_manager/models/affiliate_deal.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/community_activity.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 画面の直し 第6段(2026-11-25): クラブ。
/// スタッフの複数人・交渉・人事の委託、地域貢献の活動、系列クラブの提携。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  StaffMember person(String id, StaffRole role,
          {int ability = 10, int wage = 5, int years = 2, int age = 45}) =>
      StaffMember(
        id: id,
        name: '人$id',
        age: age,
        role: role,
        attributes: {for (final a in StaffAttribute.values) a: ability},
        wage: wage,
        contractYears: years,
      );

  Future<GameState> newGame() async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.budget = 1 << 30;
    gs.save!.wageBudget = 1 << 28;
    return gs;
  }

  group('スタッフの複数人', () {
    test('1人の役職と複数の役職。2人目からは逓減して上乗せ', () {
      expect(ClubInfrastructure.roleAllowsMany(StaffRole.manager), isFalse);
      expect(ClubInfrastructure.roleAllowsMany(StaffRole.headCoach), isFalse);
      expect(ClubInfrastructure.roleAllowsMany(StaffRole.sportingDirector),
          isFalse);
      expect(ClubInfrastructure.roleAllowsMany(StaffRole.scout), isTrue);
      // 1人ならその人の能力のまま。
      expect(ClubInfrastructure.combinedAbility([10]), 10);
      // 2人目は3割、3人目はその半分。
      expect(ClubInfrastructure.combinedAbility([10, 10]), closeTo(13, 1e-9));
      expect(ClubInfrastructure.combinedAbility([10, 10, 10]),
          closeTo(14.5, 1e-9));
      // 1人の名手には人数で届きにくい。
      expect(ClubInfrastructure.combinedAbility([8, 8, 8, 8]),
          lessThan(ClubInfrastructure.combinedAbility([14])));
    });

    test('人数の上限は部と施設で増える(1人の役職はいつも1)', () {
      final infra = ClubInfrastructure();
      expect(infra.maxStaffFor(StaffRole.manager, divisionTier: 1), 1);
      final low = infra.maxStaffFor(StaffRole.physio, divisionTier: 5);
      infra.facilityLevels[FacilityType.medicalCenter] = 7;
      final high = infra.maxStaffFor(StaffRole.physio, divisionTier: 1);
      expect(low, 1);
      expect(high, ClubInfrastructure.maxPerRole);
    });

    test('部下を加えると役職の水準が上がり、主任が抜けると部下が上がる', () {
      final infra = ClubInfrastructure();
      infra.addMember(person('a', StaffRole.scout, ability: 8));
      final one = infra.staffLevel(StaffRole.scout);
      infra.addMember(person('b', StaffRole.scout, ability: 12));
      expect(infra.headcount(StaffRole.scout), 2);
      expect(infra.staffLevel(StaffRole.scout), greaterThan(one));
      expect(infra.removeMember('a')?.id, 'a');
      expect(infra.staffFor(StaffRole.scout)?.id, 'b');
      expect(infra.assistants[StaffRole.scout], isNull);
      expect(infra.totalStaffWeeklyWage, 5);
    });

    test('セーブは役職ごとの全員の形。古い1人ずつの形は2回読んでも同じ', () {
      final infra = ClubInfrastructure();
      infra.addMember(person('a', StaffRole.physio));
      infra.addMember(person('b', StaffRole.physio, ability: 6));
      final json =
          jsonDecode(jsonEncode(infra.toJson())) as Map<String, dynamic>;
      expect(json.containsKey('staffTeams'), isTrue);
      expect(json.containsKey('staff'), isFalse);
      final back = ClubInfrastructure.fromJson(json);
      expect(back.membersFor(StaffRole.physio).map((m) => m.id), ['a', 'b']);

      // 2026-11-25 より前の形('staff' に1人ずつ)。
      final old = {
        'staff': {'scout': person('s', StaffRole.scout).toJson()},
        'facilityLevels': {'stadium': 2},
      };
      final first = ClubInfrastructure.fromJson(
          jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      final second = ClubInfrastructure.fromJson(
          jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      expect(first.staffFor(StaffRole.scout)?.id, 's');
      expect(first.assistants, isEmpty);
      expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
      // 新しい形で書いて読み直しても変わらない(移行は一度だけ)。
      final again = ClubInfrastructure.fromJson(
          jsonDecode(jsonEncode(first.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(again.toJson()), jsonEncode(first.toJson()));
    });
  });

  group('スタッフの交渉', () {
    test('要求どおりなら合意。年俸が9割を割ると断る。年数のずれは上乗せを求める', () {
      final s = person('c', StaffRole.scout, wage: 20, years: 2);
      final ask = StaffTermsEngine.asking(s);
      expect(StaffTermsEngine.reply(ask, ask).accepted, isTrue);
      expect(StaffTermsEngine.reply(ask, ask.copyWith(weeklyWage: 17)).kind,
          StaffReplyKind.wageLow);
      expect(StaffTermsEngine.reply(ask, ask.copyWith(years: 4)).kind,
          StaffReplyKind.yearsOff);
      // 年俸を少し削っても、サイン料を積めば通る。
      final traded = ask.copyWith(
          weeklyWage: 19, signingBonus: ask.signingBonus + 52 * 2 * 2);
      expect(StaffTermsEngine.reply(ask, traded).accepted, isTrue);
    });

    test('交渉の条件で雇うと、空きがあれば部下に加わり、上限なら入れ替わる', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.infrastructure.addMember(person('lead', StaffRole.scout, ability: 6));
      final max = gs.maxStaffFor(StaffRole.scout);
      expect(max, greaterThan(1));
      final c = person('cand', StaffRole.scout, ability: 9);
      s.staffCandidates.add(c);
      final ask = StaffTermsEngine.asking(c);
      expect(await gs.hireStaffOnTerms(c.id, ask), isTrue);
      expect(gs.staffMembersFor(StaffRole.scout).length, 2);
      // 上限まで埋めてから雇うと、いちばん能力の低い人と入れ替わる。
      while (gs.staffMembersFor(StaffRole.scout).length < max) {
        s.infrastructure.addMember(person(
            'fill${gs.staffMembersFor(StaffRole.scout).length}',
            StaffRole.scout,
            ability: 7));
      }
      final weakest = gs.staffReplacedBy(StaffRole.scout)!;
      expect(weakest.id, 'lead');
      final c2 = person('cand2', StaffRole.scout, ability: 11);
      s.staffCandidates.add(c2);
      expect(await gs.hireStaffOnTerms(c2.id, StaffTermsEngine.asking(c2)),
          isTrue);
      expect(gs.staffMembersFor(StaffRole.scout).length, max);
      expect(gs.staffById('lead'), isNull);
      expect(s.staffCandidates.any((x) => x.id == 'cand2'), isFalse);
    });

    test('結び直すと年俸と年数が変わり、サイン料を払う', () async {
      final gs = await newGame();
      final st = person('re', StaffRole.physio, wage: 10, years: 1);
      gs.save!.infrastructure.addMember(st);
      final before = gs.save!.budget;
      final ask = StaffTermsEngine.asking(st, renewal: true);
      expect(ask.weeklyWage, greaterThanOrEqualTo(11));
      expect(await gs.renewStaffOnTerms(st.id, ask.copyWith(years: 3)), isTrue);
      expect(st.contractYears, 3);
      expect(st.wage, ask.weeklyWage);
      expect(gs.save!.budget, before - gs.scaledMoney(ask.signingBonus));
    });
  });

  group('人事の委託', () {
    test('任せると空いた役職を埋め、上限を超える人は雇わない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.infrastructure.addMember(person('sd', StaffRole.sportingDirector));
      for (final r in StaffRole.values) {
        if (r == StaffRole.sportingDirector) continue;
        s.infrastructure.staff[r] = null;
      }
      s.staffCandidates
        ..clear()
        ..add(person('cheap', StaffRole.physio, ability: 6, wage: 3))
        ..add(person('dear', StaffRole.physio, ability: 14, wage: 40))
        ..add(person('coach', StaffRole.headCoach, ability: 9, wage: 4));
      // 年俸の総額の上限: いまの5 + 4 + 3 = 12 まで。
      await gs.setStaffDelegation(on: true, weeklyCap: 12);
      expect(gs.staffFor(StaffRole.physio)?.id, 'cheap',
          reason: '上限を超える高い人は選ばない');
      expect(gs.staffFor(StaffRole.headCoach)?.id, 'coach');
      expect(gs.staffFor(StaffRole.manager), isNull, reason: '監督はオーナーが決める');
    });

    test('満了する人は、上限に収まれば2年延ばし、外れれば去らせる', () async {
      final gs = await newGame();
      final s = gs.save!;
      for (final r in StaffRole.values) {
        s.infrastructure.staff[r] = null;
      }
      s.infrastructure.addMember(person('sd', StaffRole.sportingDirector));
      final good = person('good', StaffRole.physio, ability: 18, years: 1);
      s.infrastructure.addMember(good);
      s.staffDelegated = true;
      s.staffDelegateWeeklyCap = 0;
      gs.debugDelegatedStaffRenewals();
      expect(good.contractYears, 3, reason: '季の切り替えで1つ減って残り2年');
      // 上限が低ければ延ばさない。
      final other = person('other', StaffRole.scout, ability: 18, years: 1);
      s.infrastructure.addMember(other);
      s.staffDelegateWeeklyCap = s.infrastructure.totalStaffWeeklyWage;
      gs.debugDelegatedStaffRenewals();
      expect(other.contractYears, 1);
    });
  });

  group('地域貢献の活動', () {
    test('古い Lv は同じ効き目の活動に移り、2回読んでも同じ', () async {
      final gs = await newGame();
      final json = gs.save!.toJson()
        ..remove('communityActivities')
        ..['communityLevel'] = 3;
      final a = SaveGame.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      final b = SaveGame.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(a.communityActivities, b.communityActivities);
      expect(a.communityLevel, 3, reason: '不祥事を和らげる量は Lv と同じ');
      expect(a.communityActivities.any((x) => x.supporterMonthly > 0), isTrue,
          reason: 'Lv1 以上の「毎月+1」も残す');
      // 新しい形で書いて読んでも同じ。
      final c = SaveGame.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(c.communityActivities, a.communityActivities);
    });

    test('季の切り替えで前の季の結果を残し、続ける活動の費用を払う', () async {
      final gs = await newGame();
      final s = gs.save!;
      expect(await gs.startCommunityActivity(CommunityActivity.localBusiness),
          isTrue);
      s.communitySeasonGain = 4;
      final cost = gs.communityCostOf(CommunityActivity.localBusiness);
      final before = s.budget;
      gs.debugRollCommunity();
      final r = s.lastCommunityReport!;
      expect(r.activities, [CommunityActivity.localBusiness]);
      expect(r.supporterGain, 4);
      expect(r.spent, cost);
      expect(r.backing, greaterThan(0), reason: '地元の協賛が入る');
      expect(s.communityActivities, [CommunityActivity.localBusiness]);
      expect(s.communitySeasonSpent, cost);
      expect(s.budget, before + r.backing - cost);
      expect(s.communitySeasonGain, 0);
    });

    test('払えなければ止まる', () async {
      final gs = await newGame();
      final s = gs.save!;
      await gs.startCommunityActivity(CommunityActivity.invitation);
      s.budget = 0;
      gs.debugRollCommunity();
      expect(s.communityActivities, isEmpty);
    });
  });

  group('系列クラブ', () {
    test('古いセーブ(相手の id だけ)は以前の決まりの提携として読む', () async {
      final gs = await newGame();
      final t = gs.affiliateCandidates().first;
      final json = gs.save!.toJson()..['affiliateClubId'] = t.id;
      json.remove('affiliateDeal');
      final a = SaveGame.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(a.affiliateDeal!.weAreParent, isTrue);
      expect(a.affiliateDeal!.firstRefusal, isTrue);
      expect(a.affiliateDeal!.loanPriority, isTrue);
      expect(a.affiliateDeal!.untilSeason, isNull);
      final b = SaveGame.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(b.affiliateDeal!.toJson()),
          jsonEncode(a.affiliateDeal!.toJson()));
    });

    test('弱い相手なら親で提携費を払い、強い相手なら子で受け取る', () async {
      final gs = await newGame();
      final s = gs.save!;
      final weaker =
          gs.affiliateCandidates().firstWhere((t) => gs.weAreParentWith(t));
      final before = s.budget;
      expect(
          await gs.signAffiliate(weaker.id,
              years: 2,
              loanPriority: true,
              youthDevelopment: true,
              firstRefusal: true,
              sellOnPercent: 10),
          isTrue);
      expect(s.budget, lessThan(before));
      expect(gs.affiliateDeal!.weAreParent, isTrue);
      expect(gs.affiliateDiscountApplies(weaker.id), isTrue);
      expect(gs.affiliateTakesLoans, isTrue);

      final stronger = gs
          .affiliateCandidates()
          .where((t) => !gs.weAreParentWith(t))
          .firstOrNull;
      if (stronger == null) return; // 最強のクラブなら強い相手がいない。
      final mid = s.budget;
      expect(
          await gs.signAffiliate(stronger.id,
              years: 1,
              loanPriority: true,
              youthDevelopment: true,
              firstRefusal: true,
              sellOnPercent: 20),
          isTrue);
      expect(s.budget, greaterThan(mid), reason: '子は提携費を受け取る');
      final d = gs.affiliateDeal!;
      expect(d.weAreParent, isFalse);
      expect(d.youthDevelopment, isFalse, reason: '育成先は親だけの項目');
      expect(gs.affiliateDiscountApplies(stronger.id), isFalse);
      expect(gs.affiliateTakesLoans, isFalse);
    });

    test('期間を過ぎた季の切り替えで切れる', () async {
      final gs = await newGame();
      final s = gs.save!;
      final t = gs.affiliateCandidates().first;
      await gs.signAffiliate(t.id,
          years: 1,
          loanPriority: true,
          youthDevelopment: false,
          firstRefusal: true,
          sellOnPercent: 0);
      gs.debugRollAffiliate();
      expect(s.affiliateClubId, t.id, reason: '同じ季のうちは続く');
      s.affiliateDeal!.untilSeason = s.league.season - 1;
      gs.debugRollAffiliate();
      expect(s.affiliateClubId, isNull);
      expect(s.affiliateDeal, isNull);
    });

    test('提携費は項目が多いほど高い', () {
      int fee({bool y = false, int sell = 0}) => AffiliateDeal.feeFor(
          weAreParent: true,
          gap: 5,
          loanPriority: true,
          youthDevelopment: y,
          firstRefusal: true,
          sellOnPercent: sell);
      expect(fee(y: true), greaterThan(fee()));
      expect(fee(sell: 20), greaterThan(fee()));
    });
  });
}
