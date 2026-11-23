import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/academy_engine.dart';
import 'package:soccer_manager/logic/club_culture.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/live_match_progress.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/staff_offer.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 品質改善の11回目: セーブデータで利用者の進みが消える・壊れる所。
///
/// 1 保存して読み直しても、どの項目も変わらない(数季回したセーブと、
///   この数日で足した項目を全部埋めたセーブ)。
/// 2 古い形式(項目が無い・null)を読んでも落ちず、移行は一度だけ掛かる。
/// 3 本体が書きかけで壊れたとき・スロットを替えたとき・セーブを消したとき。
/// 4 書き出しの終わる順番が入れ替わっても、古い内容で上書きしない。
/// 5 クラブを買い直した直後の保存。

const _slot0 = 'soccer_manager_save_slot_0';
const _slot1 = 'soccer_manager_save_slot_1';

/// 2つの JSON の違う場所を全部出す(配列の添字は [] にまとめる)。
List<String> jsonDiff(Object? a, Object? b, [String path = r'$']) {
  if (a is Map && b is Map) {
    return [
      for (final k in {...a.keys, ...b.keys})
        if (!a.containsKey(k))
          '$path.$k: (無い) -> ${_short(b[k])}'
        else if (!b.containsKey(k))
          '$path.$k: ${_short(a[k])} -> (無い)'
        else
          ...jsonDiff(a[k], b[k], '$path.$k'),
    ];
  }
  if (a is List && b is List) {
    if (a.length != b.length) return ['$path: 長さ ${a.length} -> ${b.length}'];
    return [
      for (var i = 0; i < a.length; i++) ...jsonDiff(a[i], b[i], '$path[]'),
    ];
  }
  if (a == b) return const [];
  if (a is num && b is num && a.toDouble() == b.toDouble()) return const [];
  return ['$path: ${_short(a)} -> ${_short(b)}'];
}

String _short(Object? v) {
  final s = jsonEncode(v);
  return s.length > 60 ? '${s.substring(0, 60)}...' : s;
}

/// 項目ごとに1行へまとめる(同じ項目が何百人ぶん出ないように)。
List<String> _summary(List<String> diffs) =>
    {for (final d in diffs) d.split(': ').first}.toList()..sort();

Map<String, dynamic> _json(SaveGame s) =>
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

/// [json]をスロット0に置いて、新しい GameState で起動し直す。
Future<GameState> _boot(Map<String, dynamic> json) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_slot0, jsonEncode(json));
  final g = GameState();
  await g.init();
  return g;
}

Future<void> _playSeasons(GameState game, int seasons) async {
  for (var i = 0; i < seasons; i++) {
    var guard = 0;
    while (!game.save!.league.isSeasonComplete && guard++ < 60) {
      await game.simulateAheadMatchdays(10);
    }
    if (i < seasons - 1) await game.startNextSeason();
  }
}

/// この数日で足した項目と、ふだんの数季では空のままの項目を埋める。
void _fillRareFields(GameState game) {
  final s = game.save!;
  final team = game.userTeam;
  final ids = team.players.map((p) => p.id).toList();
  final today = game.today;
  final cpu = s.league.teams.firstWhere((t) => t.id != s.userTeamId);

  // 施設の工事中・スタジアムの猶予
  s.infrastructure.startConstruction(
      FacilityType.trainingGround, DateTime(today.year, today.month + 3, 28));
  s.infrastructure.startConstruction(
      FacilityType.medicalCenter, DateTime(today.year + 1, 1, 31));
  s
    ..licenseGraceTier = 2
    ..licenseGraceSeason = s.league.season;

  // サポーターの最後通告と内訳
  s
    ..supporterUltimatumUntil = DateTime(today.year, today.month + 2, 1)
    ..supporterMonth = {'results': -4, 'ticket': 2, 'pr': 3}
    ..supporterLastMonth = {'results': 5, 'sale': -6}
    ..supporterLastMonthKey = today.year * 12 + today.month - 1
    ..supporterMonthEnds = [55, 41, 33]
    ..supporterMonthPoints = 7
    ..supporterMonthGames = 4
    ..fanWorkMonthKey = today.year * 12 + today.month;

  // 監督の戦術・逃げ切り・セットプレーの担当
  team
    ..pressing = 81
    ..lineHeight = 23
    ..width = 67
    ..tempo = 12
    ..mentality = TeamMentality.values.last
    ..tacticalStyle = TacticalStyle.values.last
    ..holdLeadLate = true
    ..timeWastingMode = true
    ..captainId = ids[0]
    ..viceCaptainId = ids[1]
    ..penaltyTakerId = ids[2]
    ..freeKickTakerId = ids[3]
    ..cornerTakerId = ids[4]
    ..manMarkerId = ids[5]
    ..setPieceDefenderId = ids[6];

  // 職員(雇った日)と、引き抜きの話・その版
  final hired = s.staffCandidates.first;
  hired.hiredOn = DateTime(today.year, today.month, today.day);
  s.infrastructure.staff[hired.role] = hired;
  s.staffCandidates.remove(hired);
  s.staffOffers = [
    StaffOffer(
      id: 'so-1',
      role: hired.role,
      staffId: hired.id,
      staffName: hired.name,
      clubId: cpu.id,
      clubName: cpu.name,
      compensation: 1234,
      raisePercent: 15,
      expiresOn: DateTime(today.year, today.month, today.day + 9),
    ),
  ];
  s
    ..staffPoachSeason = s.league.season
    ..visionPressSeason = s.league.season
    ..visionPressUses = 2;

  // 移籍の話(競合あり)と仮契約
  final target = cpu.players.first;
  s.transferTalks = [
    TransferTalk(
      playerId: target.id,
      playerName: target.name,
      clubId: cpu.id,
      clubName: cpu.name,
      bid: 4321,
      stage: TransferTalkStage.values.last,
      round: 2,
      installments: true,
      replyOn: DateTime(today.year, today.month, today.day + 3),
      fee: 5000,
      sellOnPercent: 10,
      installmentsOk: true,
      deadline: DateTime(today.year, today.month + 1, 1),
      termsRound: 1,
      demandWage: 77,
      rivalClubId: s.league.teams.last.id,
      rivalClubName: s.league.teams.last.name,
      rivalWage: 88,
      rivalDecidesOn: DateTime(today.year, today.month, today.day + 5),
      bySd: true,
    ),
  ];
  s.preContracts = [
    PreContract(
      playerId: cpu.players.last.id,
      playerName: cpu.players.last.name,
      fromClubId: cpu.id,
      fromClubName: cpu.name,
      toClubId: s.userTeamId,
      toClubName: s.clubName,
      wage: 66,
      endYear: today.year + 3,
      option: true,
      signedOn: DateTime(today.year, 1, 2),
    ),
  ];

  // 1部の連覇の数を数える元(季の記録)
  s.seasonHistory.addAll([
    for (var i = 0; i < 2; i++)
      SeasonRecord.fromJson({
        'season': s.league.season - 2 + i,
        'clubName': s.clubName,
        'leagueName': s.leagueName,
        'divisionTier': 1,
        'finalRank': 1,
        'teamCount': 20,
        'played': 38,
        'won': 28,
        'draw': 6,
        'lost': 4,
        'goalsFor': 80,
        'goalsAgainst': 30,
        'wonLeague': true,
        'cupsWon': ['カップ'],
      }),
  ]);

  // 途中で止まった試合
  s.liveMatchProgress = LiveMatchProgress(
    season: s.league.season,
    matchday: 3,
    resumeMinute: 61,
    substitutionsUsed: 2,
    substitutionWindowsUsed: 1,
    firstHalf: const HalfTally(homeGoals: 1, homeShots: 6, chanceCount: 3),
    secondHalf: const HalfTally(awayGoals: 2, possessionShareSum: 12.5),
  );

  // その他の、ふだん空の項目
  s
    ..ownerLoanBalance = 900
    ..ownerInjectionSeason = s.league.season
    ..agmPayout = 30
    ..agmWageRatio = 0.62
    ..agmWageRatioPledge = 0.58
    ..taxLossCarry = 400
    ..parachuteFromTier = 1
    ..parachuteSeasonsLeft = 2
    ..wageFreezeSeasons = 1
    ..wageFreezeCap = 5000
    ..adminRelegation = true
    ..youthPolicy = YouthPolicy.values.last.name
    ..clubCulture = ClubCulture.values.last.name
    ..clubCultureChangedSeason = s.league.season
    ..stadiumSubsidyPct = 20
    ..municipalityAskSeason = s.league.season
    ..hasAnalytics = true
    ..lastWeekCongested = true
    ..planStartSeason = s.league.season
    ..planTargetTier = 1
    ..planTargetValue = 99999
    ..planTargetStadium = 30000
    ..managerWarned = true
    ..managerTargetRank = 3
    ..sdSignedThisWindow = 2
    ..nonEuSignings = 1
    ..nonEuSigningsSeason = s.league.season
    ..squadCostAllowance = 1000
    ..squadCostAllowanceSeason = s.league.season
    ..squadCostObserved = 800
    ..recordSigningFee = 3000
    ..recordSaleFee = 4000
    ..newsSeenTotal = 3
    ..unpaidWagesNoticeGiven = true
    ..watchlistPlayerIds.add(target.id)
    ..retiredNumberIds.add(ids[7])
    ..declinedProposalIds.add('p-x')
    ..achievedGoals.add('clubValue')
    ..partnerClubId = cpu.id
    ..pendingJobOfferTeamId = cpu.id
    ..transferBanSeasons = 1
    ..pendingPointsDeduction = 3;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => GameState.debugEncodeOverride = null);

  group('1 保存して読み直しても、どの項目も変わらない', () {
    test('3季目の途中まで回したセーブ(読み込みの直しも何も変えない)', () async {
      final game = GameState();
      await game.startNewGame('往復FC');
      await _playSeasons(game, 2);
      await game.startNextSeason();
      await game.simulateAheadMatchdays(4);
      await game.flushPendingSave();

      final before = _json(game.save!);
      final again = _json(SaveGame.fromJson(_json(game.save!)));
      expect(_summary(jsonDiff(before, again)), isEmpty,
          reason: 'toJson → fromJson で変わる項目がある');

      // 起動し直す(移行・直しが走る)。今の版のセーブなら何も変わらない。
      final reloaded = await _boot(before);
      expect(_summary(jsonDiff(before, _json(reloaded.save!))), isEmpty,
          reason: '今の版のセーブに、読み込みの直し・移行が掛かっている');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('この数日で足した項目を全部埋めても、読み直して同じ', () async {
      final game = GameState();
      await game.startNewGame('埋め尽くしFC');
      await game.simulateAheadMatchdays(2);
      _fillRareFields(game);
      final before = _json(game.save!);

      final again = _json(SaveGame.fromJson(_json(game.save!)));
      expect(_summary(jsonDiff(before, again)), isEmpty);

      final reloaded = await _boot(before);
      final s = reloaded.save!;
      // 読み込みの直しで消えてよいものは無い(オファーの相手は同じリーグ)。
      expect(_summary(jsonDiff(before, _json(s))), isEmpty);

      // 中身でも確かめる(書き出しの形が両方で同じ誤りをしていないか)。
      final t = reloaded.userTeam;
      expect(s.infrastructure.isUnderConstruction(FacilityType.trainingGround),
          isTrue);
      expect(
          s.infrastructure.constructionReadyOn(FacilityType.medicalCenter),
          game.save!.infrastructure
              .constructionReadyOn(FacilityType.medicalCenter));
      expect(s.licenseGraceTier, 2);
      expect(s.supporterUltimatumUntil, game.save!.supporterUltimatumUntil);
      expect(s.supporterMonth['pr'], 3);
      expect(s.supporterLastMonth['sale'], -6);
      expect(s.supporterMonthEnds, [55, 41, 33]);
      expect(t.holdLeadLate, isTrue);
      expect(t.timeWastingMode, isTrue);
      expect(t.pressing, 81);
      expect(t.tacticalStyle, TacticalStyle.values.last);
      expect(t.cornerTakerId, game.userTeam.cornerTakerId);
      expect(t.setPieceDefenderId, game.userTeam.setPieceDefenderId);
      expect(s.staffOffers.single.compensation, 1234);
      expect(s.staffOffers.single.expiresOn,
          game.save!.staffOffers.single.expiresOn);
      final hired = s.infrastructure.staff.values.whereType<StaffMember>();
      expect(hired.single.hiredOn, isNotNull);
      expect(s.staffWageVersion, SaveGame.currentStaffWageVersion);
      expect(s.transferTalks.single.rivalDecidesOn,
          game.save!.transferTalks.single.rivalDecidesOn);
      expect(s.preContracts.single.option, isTrue);
      expect(s.liveMatchProgress!.resumeMinute, 61);
      expect(s.liveMatchProgress!.secondHalf!.possessionShareSum, 12.5);
      expect(reloaded.reigningTitleStreak, game.reigningTitleStreak,
          reason: '1部の連覇の数が読み直しで変わった');
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('2 古い形式のセーブ', () {
    test('この数日で足した項目が無い・null でも、起動して1節進められる', () async {
      final game = GameState();
      await game.startNewGame('古株FC');
      _fillRareFields(game);
      final base = _json(game.save!);
      const keys = [
        'supporterUltimatumUntil',
        'supporterMonth',
        'supporterLastMonth',
        'supporterLastMonthKey',
        'supporterMonthEnds',
        'staffOffers',
        'staffWageVersion',
        'staffPoachSeason',
        'licenseGraceTier',
        'transferTalks',
        'preContracts',
        'liveMatchProgress',
        'today',
        'infrastructure',
        'seasonHistory',
      ];
      // 1項目ずつ外して起動する検査は手元で全項目(約200)について済ませた
      // (どれを外しても起動して1節進めた)。ここでは足したばかりの項目を
      // まとめて外す・null にする形で固める(1分以内に収めるため)。
      final problems = <String>[];
      for (final asNull in [false, true]) {
        final j = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        for (final k in keys) {
          asNull ? j[k] = null : j.remove(k);
        }
        try {
          final g = await _boot(j);
          if (g.save == null) {
            problems.add('${asNull ? 'null' : '無し'}: 読めない');
            continue;
          }
          g.userTeam;
          await g.simulateAheadMatchdays(1);
          g.dispose();
        } catch (e) {
          problems.add('${asNull ? 'null' : '無し'}: $e');
        }
      }
      // 自クラブのリーグのチームの、戦術・担当の項目
      final j = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      for (final t in (j['league']['teams'] as List)) {
        for (final k in [
          'holdLeadLate',
          'timeWastingMode',
          'tacticalStyle',
          'mentality',
          'pressing',
          'cornerTakerId',
          'setPieceDefenderId',
          'manMarkerId',
        ]) {
          (t as Map)[k] = null;
        }
      }
      try {
        final g = await _boot(j);
        await g.simulateAheadMatchdays(1);
      } catch (e) {
        problems.add('team(null): $e');
      }
      expect(problems, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('版の無い古いセーブの移行は一度だけ掛かる(読み直しても二度目は無い)', () async {
      final game = GameState();
      await game.startNewGame('移行FC');
      final cand = game.save!.staffCandidates.first;
      final wage0 = cand.wage;
      final old = _json(game.save!)
        ..remove('staffWageVersion')
        ..remove('clubValueVersion')
        ..remove('wageLevelVersion')
        ..['economyVersion'] = SaveGame.currentEconomyVersion;

      final first = await _boot(old);
      final s1 = first.save!;
      expect(s1.staffWageVersion, SaveGame.currentStaffWageVersion);
      expect(s1.clubValueVersion, SaveGame.currentClubValueVersion);
      expect(s1.wageLevelVersion, SaveGame.currentWageLevelVersion);
      final wage1 = s1.staffCandidates.firstWhere((c) => c.id == cand.id).wage;
      expect(wage1, isNot(wage0), reason: '前提: 版1のスタッフの週俸が直っていない');

      // 直したものを保存して、もう一度起動する。
      await first.flushPendingSave();
      final json1 = _json(s1);
      final second = await _boot(json1);
      expect(_summary(jsonDiff(json1, _json(second.save!))), isEmpty,
          reason: '二度目の読み込みでも移行が掛かった');
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('3 壊れた本体・スロットの切り替え・セーブを消す', () {
    test('自動の控えが別スロットのものでも、手で取った控えから戻す', () async {
      final game = GameState();
      await game.startNewGame('しおりFC');
      await game.saveRestorePoint();
      // 別のスロットを開く(自動の控えはそちらのものになる)。
      await game.loadSlot(1);
      await game.startNewGame('別枠FC');
      await game.loadSlot(0);
      await game.loadSlot(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('soccer_manager_save_backup_slot'), 1);

      // スロット0の本体が書きかけで壊れた。
      await prefs.setString(_slot0, '{"clubName": "しおり');

      final slots = await game.listSaveSlots();
      expect(slots[0].clubName, 'しおりFC', reason: '戻せるのに空きに見え、新しいクラブで上書きされる');

      await game.loadSlot(0);
      expect(game.save?.clubName, 'しおりFC', reason: '控えがあるのに戻せていない');
      expect(game.lastBackupRestoreNotice, isNotNull);
    });

    test('控えから戻したら、本体も書き直す(壊れたまま残さない)', () async {
      final game = GameState();
      await game.startNewGame('復元FC');
      await game.flushPendingSave();
      await GameState().init(); // 控えを作る
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_slot0, '{"clubName": "壊れ');

      final restored = GameState();
      await restored.init();
      expect(restored.save!.clubName, '復元FC');
      final raw = prefs.getString(_slot0)!;
      expect(() => jsonDecode(raw), returnsNormally, reason: '本体が壊れたまま残っている');
      expect((await restored.listSaveSlots())[0].clubName, '復元FC');
    });

    test('「セーブを消す」は控えも消す(消したクラブに戻れない)', () async {
      final game = GameState();
      await game.startNewGame('解散FC');
      await game.saveRestorePoint();
      await game.flushPendingSave();
      await GameState().init(); // 自動の控えも作る

      await game.deleteSave();

      expect(await game.restorePointInfo(0), isNull, reason: '消したクラブに戻せる');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('soccer_manager_save_backup'), isNull);

      // 同じ枠で始めたクラブが壊れても、消したクラブは戻らない。
      await game.startNewGame('新生FC');
      await game.flushPendingSave();
      await prefs.setString(_slot0, '壊れた');
      final g = GameState();
      await g.init();
      expect(g.save?.clubName, isNot('解散FC'));
    });

    test('スロットを替えると、前のスロットの出来事の知らせは残らない', () async {
      final game = GameState();
      await game.startNewGame('優勝FC');
      await game.loadSlot(1);
      await game.startNewGame('別枠FC');
      game
        ..lastSeasonFinale = SeasonFinale.values.last
        ..lastDivisionChangeMessage = '昇格しました'
        ..lastSeasonResultLines = ['1位']
        ..lastLoanReturns = ['戻り']
        ..lastYouthDepartures = []
        ..lastAutoDecisions = ['自動']
        ..lastMonthlyManagerAward = '月間最優秀';

      await game.loadSlot(0);

      expect(game.lastSeasonFinale, SeasonFinale.none);
      expect(game.lastDivisionChangeMessage, isNull);
      expect(game.lastSeasonResultLines, isNull);
      expect(game.lastLoanReturns, isEmpty);
      expect(game.lastAutoDecisions, isEmpty);
      expect(game.lastMonthlyManagerAward, isNull);
    });
  });

  group('4 書き出しの終わる順番が入れ替わっても', () {
    test('先に始めた古い書き出しは、後の新しい内容を上書きしない', () async {
      final game = GameState();
      await game.startNewGame('順番FC');
      await game.flushPendingSave();
      final slow = Completer<void>();
      var calls = 0;
      GameState.debugEncodeOverride = (s) async {
        final encoded = jsonEncode(s.toJson());
        if (calls++ == 0) await slow.future; // 1回目だけ遅れて終わる
        return encoded;
      };

      game.save!.budget = 111;
      final older = game.debugPersistNow();
      // 1回目が JSON にし始めるまで待ってから変える。
      await Future<void>.delayed(Duration.zero);
      game.save!.budget = 222;
      await game.debugPersistNow();
      slow.complete();
      await older;

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(_slot0)!) as Map;
      expect(saved['budget'], 222, reason: '古い内容で上書きした');
    });

    test('消した後に、消す前に始めた書き出しが終わってもセーブは戻らない', () async {
      final game = GameState();
      await game.startNewGame('幽霊FC');
      await game.flushPendingSave();
      final slow = Completer<void>();
      GameState.debugEncodeOverride = (s) async {
        await slow.future;
        return jsonEncode(s.toJson());
      };

      final pending = game.debugPersistNow();
      await game.deleteSave();
      slow.complete();
      await pending;

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_slot0), isNull, reason: '消したセーブが戻った');
    });

    test('書き出しの途中でスロットを替えても、替えた先の中身を前のスロットへ書かない', () async {
      final game = GameState();
      await game.startNewGame('一番FC');
      await game.loadSlot(1);
      await game.startNewGame('二番FC');
      await game.loadSlot(0);
      await game.flushPendingSave();
      final slow = Completer<void>();
      var calls = 0;
      GameState.debugEncodeOverride = (s) async {
        final encoded = jsonEncode(s.toJson());
        if (calls++ == 0) await slow.future;
        return encoded;
      };

      final pending = game.debugPersistNow();
      await game.loadSlot(1);
      slow.complete();
      await pending;

      final prefs = await SharedPreferences.getInstance();
      expect((jsonDecode(prefs.getString(_slot0)!) as Map)['clubName'], '一番FC');
      expect((jsonDecode(prefs.getString(_slot1)!) as Map)['clubName'], '二番FC');
    });
  });

  group('5 クラブを買い直した直後', () {
    test('すぐに書き出し、前のクラブの止まった試合の経過を持ち越さない', () async {
      final gs = GameState();
      await gs.startNewGame('手放しFC');
      await gs.simulateAheadMatchdays(2);
      await gs.flushPendingSave();
      final s = gs.save!;
      s.liveMatchProgress = LiveMatchProgress(
        season: s.league.season,
        matchday: s.league.nextUnplayedFixture!.matchday,
        resumeMinute: 70,
        substitutionsUsed: 3,
        substitutionWindowsUsed: 2,
        firstHalf: const HalfTally(homeGoals: 3),
        secondHalf: const HalfTally(homeGoals: 1),
      );
      s
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      final target = gs.buyoutCandidates.first;
      final writes = gs.debugSaveWriteCount;

      expect(await gs.buyClub(target.id), isTrue);

      expect(s.liveMatchProgress, isNull, reason: '新しいクラブの試合が前のクラブの経過から始まる');
      expect(gs.debugSaveWriteCount, greaterThan(writes),
          reason: '買い直しを待ち時間の後にしか書いていない');
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(_slot0)!) as Map;
      expect(saved['userTeamId'], target.id);
    });
  });
}
