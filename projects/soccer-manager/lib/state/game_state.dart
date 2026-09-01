import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/bank_loan.dart';
import '../models/investment.dart';
import '../models/best_eleven.dart';
import '../models/club_infrastructure.dart';
import '../models/continental_cup.dart';
import '../models/contract_negotiation.dart';
import '../models/cup.dart';
import '../models/formation.dart';
import '../models/incoming_offer.dart';
import '../models/installment.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/press_question.dart';
import '../models/news_item.dart';
import '../models/save_game.dart';
import '../models/season_award.dart';
import '../models/season_record.dart';
import '../models/sponsor.dart';
import '../models/tactic_preset.dart';
import '../models/team_talk.dart';
import '../models/training_result.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/weather.dart';
import '../logic/achievement_engine.dart';
import '../logic/ai_transfer_engine.dart';
import '../logic/calendar_engine.dart';
import '../logic/awards_engine.dart';
import '../logic/background_match_engine.dart';
import '../logic/best_eleven_engine.dart';
import '../logic/board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/continental_cup_engine.dart';
import '../logic/dynamics_engine.dart';
import '../logic/tactics_ai.dart';
import '../logic/cup_engine.dart';
import '../logic/happiness_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../logic/manager_career_engine.dart';
import '../logic/press_conference_engine.dart';
import '../logic/player_generator.dart';
import '../logic/promotion_engine.dart';
import '../logic/retirement_engine.dart';
import '../logic/rotation_engine.dart';
import '../logic/fixture_generator.dart';
import '../logic/free_agent_engine.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/scouting_engine.dart';
import '../logic/season_projection_engine.dart';
import '../logic/sponsor_engine.dart';
import '../logic/super_cup_engine.dart';
import '../logic/training_engine.dart';
import '../logic/transfer_market.dart';
import '../logic/weather_engine.dart';
import '../logic/youth_match_engine.dart';
import '../data/name_pool.dart';
import '../models/first_run_step.dart';
import '../monetization/reward_offer.dart';
import '../l10n/tr.dart';

part 'game_state_squad.dart';
part 'game_state_transfer.dart';
part 'game_state_finance.dart';
part 'game_state_match.dart';

const int maxSquadSize = 26;

/// スカッドの最低人数。放出・ローン放出はこの人数を割り込む操作を拒否し、
/// 契約満了・ローン満了でこれを下回った場合はフリーエージェントで自動補充
/// される。12だと負傷・出場停止が重なった際に11人を組めなくなる危険が
/// あるため(長期実測で12人に張り付く状態を確認)、ベンチ要員を含めて
/// 最低限回る16人とする。
const int minSquadSize = 16;

/// シーズン開始時に自動補強で確保する推奨人数。最低人数ちょうど(16人)で
/// 張り付くと、負傷者と出場停止が数人重なるだけでベンチが空になり、
/// ローテーションの選択肢そのものが消えてしまう(長期実測で毎シーズン
/// 16人に張り付くことを確認)。シーズン開始時だけこの人数まで底上げする。
const int seasonStartSquadSize = 18;

/// ライブ観戦できるカップ試合の種別。リーグ戦([GameState.playNextMatchday])
/// と同じインタラクティブ進行を、どの大会の試合として開始するかを表す。
enum LiveCupKind { domestic, continentalGroup, continentalKnockout, superCup }

/// 1リーグあたりの参加クラブ数(自クラブ含む)。実際の主要リーグに近い規模とする。
const int teamsPerLeague = 20;

/// セーブスロット一覧表示用の概要情報。データが存在しないスロットは
/// clubNameがnullになる。
class SaveSlotSummary {
  final int slot;
  final String? clubName;
  final int? season;
  final int? divisionTier;

  SaveSlotSummary({
    required this.slot,
    this.clubName,
    this.season,
    this.divisionTier,
  });

  bool get hasSave => clubName != null;
}

class GameState extends ChangeNotifier {
  /// 旧バージョンで使われていた単一スロットのキー。起動時にスロット0へ移行する。
  static const _legacyPrefsKey = 'soccer_manager_save_v1';
  static const _slotKeyPrefix = 'soccer_manager_save_slot_';
  static const _currentSlotKey = 'soccer_manager_current_slot';

  /// 対応するセーブスロット数。
  static const int maxSaveSlots = 3;

  static String _slotKey(int slot) => '$_slotKeyPrefix$slot';

  int currentSlot = 0;

  SaveGame? _save;
  bool initialized = false;

  /// シーズン開幕・シーズン終了処理など、重い同期計算を行っている間true。
  /// UI側でローディング表示を出すために使う。
  bool isBusy = false;

  /// 直近の保存(_persist)が失敗した場合のエラーメッセージ。保存に成功すると
  /// nullに戻る。ブラウザのストレージ容量超過など、プレイ自体は継続できるが
  /// 進行状況が保存されていない可能性がある場合にUI側で警告を出すために使う。
  String? lastSaveError;

  /// セーブ未ロード時のフォールバック用の移籍市場(通常はセーブ内の
  /// [SaveGame.transferMarketPlayers]が実体)。
  List<Player> _transferMarketFallback = [];

  /// 移籍市場に出ている選手一覧。毎節数人ずつ入れ替わる持続的な市場で
  /// ([TransferMarket.rotate])、セーブデータに保存されるためロードしても
  /// 同じ顔ぶれが維持される。
  List<Player> get transferMarket =>
      _save?.transferMarketPlayers ?? _transferMarketFallback;

  set transferMarket(List<Player> players) {
    if (_save != null) {
      _save!.transferMarketPlayers = players;
    } else {
      _transferMarketFallback = players;
    }
  }

  /// スカウトが見つけてきた、獲得可能な候補選手一覧(閲覧専用・未確定)。
  List<Player> scoutCandidates = [];

  /// 直近のplayNextMatchdayでローン期間満了により契約元クラブへ復帰した選手名、
  /// または直近のstartNextSeasonで契約(年単位)満了により退団した選手名
  /// （1回表示したら呼び出し側でクリアする想定）。
  List<String> lastContractExpirations = [];

  /// 直近のstartNextSeasonで契約の最終年に入った(事前警告)選手名
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<String> lastContractWarnings = [];

  /// 契約切れでスカッドが最低人数を割り込んだ際、自動的に緊急補強された
  /// フリーエージェントの選手名(1回表示したら呼び出し側でクリアする想定)。
  List<String> lastEmergencySignings = [];

  /// 今週すでにトレーニングを実施済みかどうか(節が進むとリセットされる)。
  bool get trainingDoneThisWeek => _save?.trainingDoneThisWeek ?? false;

  /// 直近のrunWeeklyTrainingで実際に変化(成長・衰え)があった選手の一覧
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<PlayerGrowthSummary> lastTrainingResults = [];

  /// 直近の週次トレーニングで紅白戦に参加した(=実戦感覚を維持できた)
  /// スタメン外の選手の人数。トレーニング結果の表示に使う。
  int lastPracticeMatchCount = 0;

  /// 直近の節送りで行われたユース練習試合の結果(候補が0人ならnull)。
  /// ユース画面での直近戦の表示に使う(セーブデータには保存しない)。
  YouthMatchReport? lastYouthMatchReport;

  /// 直近のstartNextSeasonで引退した選手名(1回表示したら呼び出し側でクリアする想定)。
  List<String> lastRetirements = [];

  /// 直近の自クラブの試合で達成された節目(ハットトリック・通算記録)の説明文
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<String> lastMilestones = [];

  /// 直近の判定で新たに解除された実績(1回表示したら呼び出し側でクリアする想定)。
  List<Achievement> lastUnlockedAchievements = [];

  /// 直近のstartNextSeasonで算出された、前シーズン開始時点からの
  /// 選手成長サマリー(1回表示したら呼び出し側でクリアする想定)。
  List<PlayerGrowthSummary> lastSeasonGrowthSummary = [];

  SaveGame? get save => _save;
  bool get hasSave => _save != null;
  Team get userTeam =>
      _save!.league.teams.firstWhere((t) => t.id == _save!.userTeamId);

  /// 信頼度が0まで落ち、監督が解任された状態かどうか。
  bool get isDismissed => _save != null && _save!.confidence <= 0;

  /// 監督としての通算成績(勝敗数)。保存済みの過去シーズン分に加え、
  /// 進行中のシーズンの現在の順位表の成績もその場で合算して返す
  /// (シーズン終了を待たずに逐次反映されるようにするため)。
  ({int wins, int draws, int losses}) get careerRecordSoFar {
    if (_save == null) return (wins: 0, draws: 0, losses: 0);
    final rows = _save!.league.sortedStandings.where(
      (r) => r.teamId == _save!.userTeamId,
    );
    final row = rows.isEmpty ? null : rows.first;
    return (
      wins: _save!.careerWins + (row?.won ?? 0),
      draws: _save!.careerDraws + (row?.draw ?? 0),
      losses: _save!.careerLosses + (row?.lost ?? 0),
    );
  }

  /// 今シーズンの最終節(まだ日程が組まれていなければ0)。
  int get _totalMatchdaysThisSeason {
    if (_save == null || _save!.league.fixtures.isEmpty) return 0;
    return _save!.league.fixtures.map((f) => f.matchday).reduce(max);
  }

  /// 移籍ウィンドウが開いているか。プレシーズン(開幕前)・シーズン中盤の
  /// 数節・シーズン終了後(オフシーズン)にのみ、選手の獲得・放出ができる。
  bool get isTransferWindowOpen {
    if (_save == null) return true;
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    if (nextMd == null) return true; // シーズン終了後(オフシーズン)
    if (nextMd <= 1) return true; // プレシーズン(開幕前)
    final total = _totalMatchdaysThisSeason;
    if (total == 0) return true;
    final midStart = total ~/ 2;
    return nextMd >= midStart && nextMd <= midStart + 2;
  }

  /// UI表示用の移籍ウィンドウ状態文言。
  String get transferWindowStatusLabel {
    if (isTransferWindowOpen) {
      return Tr.pick('移籍ウィンドウ: オープン中', 'Transfer window: open');
    }
    final nextMd = _save?.league.nextUnplayedFixture?.matchday;
    final total = _totalMatchdaysThisSeason;
    if (nextMd == null || total == 0) {
      return Tr.pick('移籍ウィンドウ: クローズ中', 'Transfer window: closed');
    }
    final midStart = total ~/ 2;
    if (nextMd < midStart) {
      return Tr.pick('移籍ウィンドウ: クローズ中(第$midStart節に再開)',
          'Transfer window: closed (reopens on matchday $midStart)');
    }
    return Tr.pick('移籍ウィンドウ: クローズ中(来シーズン開幕前に再開)',
        'Transfer window: closed (reopens before next season)');
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 旧バージョンの単一セーブをスロット0へ移行する(スロット0が未使用の場合のみ)。
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && prefs.getString(_slotKey(0)) == null) {
      await prefs.setString(_slotKey(0), legacy);
      await prefs.remove(_legacyPrefsKey);
    }
    currentSlot = prefs.getInt(_currentSlotKey) ?? 0;
    final raw = prefs.getString(_slotKey(currentSlot));
    if (raw != null) {
      try {
        _save = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _save = null;
      }
    }
    if (_save != null) {
      _reseedPlayerIdCounter(_save!);
      _migrateDivisionPyramidIfNeeded();
      // 市場はセーブに保存された顔ぶれを維持する(旧セーブ等で空の場合のみ
      // 新規生成する)。
      if (transferMarket.isEmpty) {
        transferMarket = TransferMarket.generate();
      }
      _refreshScoutCandidates();
    }
    initialized = true;
    _notify();
  }

  /// セーブデータ内の全選手IDを集め、[PlayerGenerator]のIDカウンターへ反映する。
  void _reseedPlayerIdCounter(SaveGame save) {
    final ids = <String>[
      for (final t in save.allTeams)
        for (final p in t.players) p.id,
      for (final p in save.youthProspects) p.id,
      for (final p in save.pendingYouthIntake) p.id,
      for (final p in save.freeAgents) p.id,
      for (final p in save.retiredLegends) p.id,
    ];
    PlayerGenerator.ensureIdCounterAbove(ids);
  }

  /// [teams]から指定IDのチームを探す。見つからない場合はnull(移籍・世代交代
  /// 等で参照が古くなったフィクスチャがあっても、例外で節送り全体を
  /// 止めないようにするための安全な検索)。
  Team? _findTeam(List<Team> teams, String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 旧セーブデータ(5部制ピラミッド導入前、または一部ディビジョンの日程が
  /// 未生成)を読み込んだ場合に、不足しているディビジョンを補充し、現在の
  /// リーグの節数までその日程をまとめて消化して追いつかせる。
  void _migrateDivisionPyramidIfNeeded() {
    if (_save == null) return;
    final catchUpTo = _currentLeagueMatchdayMarker - 1;
    final rng = Random();
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == _save!.currentDivisionTier) continue;
      final idx = tier - 1;
      final existing = _save!.otherDivisionLeagues[idx];
      if (existing != null && existing.fixtures.isNotEmpty) continue;

      List<Team> teams;
      if (existing != null) {
        // 旧セーブ(secondDivisionTeamsのみ)からの移行: チーム自体は既にある。
        teams = existing.teams;
      } else {
        // 5部制導入前は存在しなかったティア。新規にチームを生成する。
        final names = NamePool.themedClubNames(
          currentLeagueTheme,
          teamsPerLeague,
        );
        teams = [
          for (int i = 0; i < teamsPerLeague; i++)
            PlayerGenerator.generateSquad(
              id: 'migrated_t${tier}_$i',
              name: names[i],
              strengthTier: (55 - (tier - 1) * 10 + rng.nextInt(20)).clamp(
                15,
                90,
              ),
            ),
        ];
        for (final t in teams) {
          LineupUtils.autoFill(t);
        }
      }

      final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
      for (final f in fixtures) {
        if (f.matchday > catchUpTo) continue;
        final home = teams.firstWhere((t) => t.id == f.homeTeamId);
        final away = teams.firstWhere((t) => t.id == f.awayTeamId);
        f.result = BackgroundMatchEngine.simulate(
          home: home,
          away: away,
          matchday: f.matchday,
        );
      }
      _save!.otherDivisionLeagues[idx] = League(
        teams: teams,
        fixtures: fixtures,
        season: _save!.league.season,
      );
    }
  }

  /// 状態変更を購読側へ通知する。
  /// ChangeNotifier.notifyListeners は @protected かつ @visibleForTesting
  /// のため、クラス外(part ファイルの extension)から直接呼ぶと解析警告になる。
  /// 通知はすべてこの委譲を経由させる。
  void _notify() => notifyListeners();

  /// セーブデータをローカルストレージへ書き込む。ブラウザのストレージ容量
  /// 超過など、書き込み自体が失敗する場合がある(特にディビジョン数が増えて
  /// セーブデータが肥大化した場合)。ここで例外を握りつぶさずに外へ伝播させると、
  /// 呼び出し元(新規クラブ作成など)の非同期処理全体が失敗し、ローディング
  /// 表示のまま進行できなくなる(UI側でエラーを拾えないため)。プレイ自体は
  /// メモリ上のセーブデータで継続できるため、保存失敗はここで捕捉して
  /// [lastSaveError] に記録するに留める。
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_save == null) {
        await prefs.remove(_slotKey(currentSlot));
      } else {
        await prefs.setString(
          _slotKey(currentSlot),
          jsonEncode(_save!.toJson()),
        );
      }
      lastSaveError = null;
    } catch (e) {
      lastSaveError = Tr.pick('セーブデータの保存に失敗しました。端末の空き容量を確認してください。',
          'The game could not be saved. Check the free space on your device.');
      _notify();
    }
  }

  /// 各スロットの概要一覧を返す(スロット番号順)。
  Future<List<SaveSlotSummary>> listSaveSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <SaveSlotSummary>[];
    for (int i = 0; i < maxSaveSlots; i++) {
      final raw = prefs.getString(_slotKey(i));
      if (raw == null) {
        result.add(SaveSlotSummary(slot: i));
        continue;
      }
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final league = json['league'] as Map<String, dynamic>?;
        result.add(
          SaveSlotSummary(
            slot: i,
            clubName: json['clubName'] as String?,
            season: league?['season'] as int?,
            divisionTier: json['currentDivisionTier'] as int?,
          ),
        );
      } catch (_) {
        result.add(SaveSlotSummary(slot: i));
      }
    }
    return result;
  }

  /// 指定スロットをカレントスロットにして読み込む(データがなければ空の状態にする)。
  Future<void> loadSlot(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    currentSlot = slot;
    await prefs.setInt(_currentSlotKey, slot);
    final raw = prefs.getString(_slotKey(slot));
    if (raw == null) {
      _save = null;
    } else {
      try {
        _save = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _save = null;
      }
    }
    if (_save != null) {
      _reseedPlayerIdCounter(_save!);
      _migrateDivisionPyramidIfNeeded();
      // 市場はセーブに保存された顔ぶれを維持する(旧セーブ等で空の場合のみ
      // 新規生成する)。
      if (transferMarket.isEmpty) {
        transferMarket = TransferMarket.generate();
      }
      _refreshScoutCandidates();
    } else {
      transferMarket = [];
      scoutCandidates = [];
    }
    lastContractExpirations = [];
    lastRetirements = [];
    _notify();
  }

  /// 指定スロットのセーブデータを完全に削除する。カレントスロットの場合は
  /// メモリ上のセーブも破棄する。
  Future<void> deleteSlot(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slotKey(slot));
    if (slot == currentSlot) {
      _save = null;
      transferMarket = [];
      scoutCandidates = [];
      _notify();
    }
  }

  /// 難易度に応じて理事会の目標順位を緩和/厳格化する。イージーは2つ緩く、
  /// ハードは1つ厳しくなる(1位〜リーグチーム数の範囲でクランプ)。
  int _difficultyAdjustedTarget(int target) {
    final delta = _save?.difficulty.boardTargetDelta ?? 0;
    return (target + delta).clamp(1, teamsPerLeague);
  }

  Future<void> startNewGame(
    String clubName, {
    LeagueTheme theme = LeagueTheme.england,
    GameDifficulty difficulty = GameDifficulty.normal,
  }) async {
    isBusy = true;
    _notify();
    // ローディング表示を1フレーム描画させてから、重いクラブ生成処理に入る。
    await Future<void>.delayed(Duration.zero);
    final userTeam = PlayerGenerator.generateSquad(
      id: 'user',
      name: clubName,
      strengthTier: 60,
    );
    final rng = Random();
    // 5部制ピラミッドの最下層(5部)からスタートする。
    const userStartTier = totalDivisionTiers;
    final allNames = NamePool.themedClubNames(
      theme,
      teamsPerLeague * totalDivisionTiers - 1,
    );
    var nameIndex = 0;
    String nextName() => allNames[nameIndex++];

    // 上位ティアほど平均的なチーム力が高くなるようにする(1部が最強)。
    // ユーザーの開始ティアでの強さ幅は、旧来の1部CPUと同じ(40-74)に揃え、
    // 従来通りの難易度バランスを保つ。
    int strengthForTier(int tier) {
      final tiersAboveUser = userStartTier - tier;
      final base = 40 + tiersAboveUser * 10;
      return (base + rng.nextInt(35)).clamp(20, 99);
    }

    const cpuCount = teamsPerLeague - 1;
    final cpuTeams = <Team>[];
    for (int i = 0; i < cpuCount; i++) {
      cpuTeams.add(
        PlayerGenerator.generateSquad(
          id: 'cpu$i',
          name: nextName(),
          strengthTier: strengthForTier(userStartTier),
        ),
      );
    }
    final teams = [userTeam, ...cpuTeams];
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }

    final otherDivisionLeagues = List<League?>.filled(totalDivisionTiers, null);
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == userStartTier) continue;
      final tierTeams = <Team>[
        for (int i = 0; i < teamsPerLeague; i++)
          PlayerGenerator.generateSquad(
            id: 'div${tier}_$i',
            name: nextName(),
            strengthTier: strengthForTier(tier),
          ),
      ];
      for (final t in tierTeams) {
        LineupUtils.autoFill(t);
      }
      otherDivisionLeagues[tier - 1] = League(
        teams: tierTeams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(tierTeams),
        season: 1,
      );
    }

    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    final league = League(teams: teams, fixtures: fixtures, season: 1);
    _save = SaveGame(
      clubName: clubName,
      userTeamId: 'user',
      league: league,
      leagueName: theme.label,
      boardTargetRank: BoardEngine.estimateTargetRank(league, 'user'),
      cups: [
        CupEngine.createKnockout(
          type: CupType.domestic,
          name: theme.domesticCupName,
          teamIds: teams.map((t) => t.id).toList(),
        ),
      ],
      pendingSponsorOffers: SponsorEngine.generateOffers(
        userTeam.overallRating,
      ),
      friendlies: _generateFriendlies(teams, 'user'),
      otherDivisionLeagues: otherDivisionLeagues,
      currentDivisionTier: userStartTier,
      clubHistory: [clubName],
      difficulty: difficulty,
    );
    // 難易度による初期条件の補正(資金と理事会目標の厳しさ)。
    _save!.budget = (_save!.budget * difficulty.initialBudgetFactor).round();
    _save!.boardTargetRank = _difficultyAdjustedTarget(_save!.boardTargetRank);
    _save!.wageBudget = BoardEngine.wageBudgetFor(
      tier: userStartTier,
      currentWeeklyWageBill: weeklyWageBill,
    );
    _save!.boardCupTargetRound = _estimateDomesticCupTarget();
    _save!.managerContractYears = 3;
    final rival = cpuTeams[rng.nextInt(cpuTeams.length)];
    _save!.rivalTeamId = rival.id;
    _save!.rivalTeamName = rival.name;
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);
    lastContractExpirations = [];
    isBusy = false;
    _notify();
    await _persist();
  }

  /// シーズン開幕前の親善試合を2試合分生成する(ランダムな相手と)。
  List<Fixture> _generateFriendlies(List<Team> teams, String userTeamId) {
    final opponents = teams.where((t) => t.id != userTeamId).toList()
      ..shuffle(Random());
    final count = min(2, opponents.length);
    return List.generate(
      count,
      (i) => Fixture(
        matchday: 0,
        homeTeamId: userTeamId,
        awayTeamId: opponents[i].id,
      ),
    );
  }

  Future<void> deleteSave() async {
    _save = null;
    transferMarket = [];
    scoutCandidates = [];
    lastContractExpirations = [];
    _notify();
    await _persist();
  }

  /// バックアップ用にセーブデータ全体をJSON文字列として書き出す。
  String? exportSaveJson() {
    if (_save == null) return null;
    return jsonEncode(_save!.toJson());
  }

  /// エクスポートされたJSON文字列からセーブデータを復元する。形式が不正な場合はfalseを返す。
  Future<bool> importSaveJson(String json) async {
    final SaveGame restored;
    try {
      restored = SaveGame.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
    _save = restored;
    _reseedPlayerIdCounter(restored);
    _migrateDivisionPyramidIfNeeded();
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    _notify();
    await _persist();
    return true;
  }

  /// 初回ガイドのステップを踏んだことを記録する。
  ///
  /// 画面を開いた側から呼ぶ。既に記録済みなら何もしないので、
  /// build のたびに呼ばれても保存が走り続けることはない。
  void markFirstRunStep(FirstRunStep step) {
    final save = _save;
    if (save == null) return;
    if (save.firstRunStepsSeen.contains(step.name)) return;
    save.firstRunStepsSeen.add(step.name);
    _notify();
    _persist();
  }

  /// 初回ガイドを閉じる。以後このセーブでは表示しない。
  void dismissFirstRunGuide() {
    final save = _save;
    if (save == null) return;
    if (save.firstRunGuideDismissed) return;
    save.firstRunGuideDismissed = true;
    _notify();
    _persist();
  }

  static final Random _transferOfferRng = Random();

  /// 今週の値切り交渉で既にオファーを断られた市場選手のID。断られた選手には
  /// 同じ週に再交渉できない(満額での獲得は引き続き可能)。節が進むとクリア。
  final Set<String> transferOffersRejectedThisWeek = {};

  /// クラブニュース履歴の保持上限。超えた分は古いものから捨てる
  /// (セーブデータの肥大化を防ぎつつ、2〜3シーズン分は見返せる量)。
  static const int newsLogLimit = 120;

  /// 直近の[sellPlayer]で選手が移籍した行き先のニュース文言(表示用)。
  String? lastSaleNews;

  /// 個別声かけ(モチベーショントーク)の基礎士気上昇量。reassure(不満度)
  /// とは異なり士気(morale)を対象にした、より短い周期で使える個別コマンド。
  /// クールダウン週数は[TrainingEngine.talkCooldownWeeks]で一元管理する
  /// (週次トレーニングの性格特性習得判定からも参照するため)。
  static const int talkBaseMoraleBoost = 10;

  /// 戦術ミーティングの再実施までのクールダウン週数。
  static const int tacticalMeetingCooldownWeeks = 3;

  /// ローン(期限付き移籍)で移籍市場の選手を獲得する。頭金は移籍金の2割、
  /// 週俸は6割に軽減される代わりに20週で自動的にチームを離れる。
  static const int loanFeeRatioPercent = 20;
  static const int loanDurationWeeks = 20;

  /// 買取オプション付きローンの場合の買取金額(移籍金に対する割合)。
  static const double loanBuyOptionRatio = 0.6;

  static const int loanOutMinWeeks = 4;
  static const int loanOutMaxWeeks = 16;

  int _incomingOfferSeq = 0;

  /// 移籍オファーの週次処理: 期限切れの削除、新規オファーの抽選発生、
  /// リリース条項の自動成立を行う。売却済み選手の名前を返す(UI通知用)。
  static final Random _offerRng = Random();

  /// 直近のplayNextMatchdayでリリース条項により自動売却された選手名。
  List<String> lastReleaseClauseSales = [];

  /// 直近のplayNextMatchdayで代表召集された選手名。
  List<String> lastInternationalCallUps = [];

  /// 直近のplayNextMatchdayでローン放出から復帰した選手名。
  List<String> lastLoanReturns = [];

  /// 直近のplayNextMatchdayで満期を迎え、利息込みで払い戻された定期預金。
  List<FixedDeposit> lastMaturedDeposits = [];

  /// 直近のplayNextMatchdayで発生したCPUクラブ同士の移籍ニュース。ない場合はnull。
  String? lastAiTransferNews;

  /// 直近のplaySecondHalfでユーザーが月間最優秀監督賞を受賞した場合の対象節ラベル。ない場合はnull。
  String? lastMonthlyManagerAward;

  /// 直近のstartNextSeasonでユーザーが年間最優秀監督賞を受賞したかどうか。
  bool lastSeasonManagerAwardWon = false;

  /// 直近のplayNextMatchdayでスタメン出場手当として支払った総額(万円)。
  int lastAppearanceFeesPaid = 0;

  /// 資金マイナスの長期化により理事会の信頼度が下がった場合の警告文。ない場合はnull。
  String? lastBudgetCrisisWarning;

  static final Random _dutyRng = Random();
  static final Random _aiTransferRng = Random();

  /// ダービー戦は観客動員(収入)・監督への信頼度への影響がともに増幅される。
  static const double derbyAttendanceMultiplier = 1.5;
  static const double derbyConfidenceMultiplier = 1.5;

  /// 直近の試合の観客動員数(ダービーなら増幅される)。未実施の場合はnull。
  int? lastMatchAttendance;

  /// 直近の獲得操作が週給予算でブロックされた場合の理由文言(表示用)。
  String? lastSigningBlockReason;

  int _loanSeq = 0;

  int _depositSeq = 0;

  // ---- ハーフタイム対応の試合進行(自クラブの試合のみ) ----
  Fixture? _liveFixture;
  InteractiveHalfState? _liveFirstHalfState;
  InteractiveHalfState? _liveSecondHalfState;
  int _liveSubstitutionsUsed = 0;
  static const int maxSubstitutionsPerMatch = 3;

  // ---- カップ戦のライブ観戦(リーグ戦と同じ進行を再利用する) ----
  LiveCupKind? _liveCupKind;
  Team? _liveCupHome;
  Team? _liveCupAway;
  Weather? _liveCupWeather;
  CupMatch? _liveCupMatch;
  CupTie? _liveCupTie;

  /// ライブ観戦したカップ試合がPK戦で決着した場合などの補足文言
  /// (フルタイム画面で表示する。次のライブ試合開始時にクリアされる)。
  String? lastLiveCupNote;

  /// 直近のライブ観戦カップ戦がPK戦にもつれた場合の、1本ごとの記録
  /// (フルタイム画面の演出用。セーブには保存しない一時データ)。
  PenaltyShootoutResult? lastShootout;

  /// 現在進行中のライブ試合が「決定機の判断あり(インタラクティブ)」で
  /// 開始されたかどうか。ライブ観戦での勝利数(実績)のカウントに使う。
  bool _liveWasInteractive = false;

  static const List<int> _goalMilestones = [50, 100, 150, 200, 250, 300];
  static const List<int> _appearanceMilestones = [100, 200, 300, 400, 500];

  Cup? _cupOfType(CupType type) {
    for (final c in _save!.cups) {
      if (c.type == type) return c;
    }
    return null;
  }

  /// 現在の実際の暦日(次に消化する節の日付。シーズンが完了している場合は
  /// 最終節の翌週)。カレンダー画面・ホーム画面の日付表示に使う。
  DateTime get currentDate {
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next != null) {
      return CalendarEngine.dateForMatchday(league.season, next.matchday);
    }
    final maxMatchday = league.fixtures.fold<int>(
      0,
      (m, f) => f.matchday > m ? f.matchday : m,
    );
    return CalendarEngine.dateForMatchday(league.season, maxMatchday + 1);
  }

  Cup? get domesticCup => _save == null ? null : _cupOfType(CupType.domestic);

  /// 大陸カップ(グループステージ+決勝トーナメント)。出場資格がない間はnull。
  ContinentalCup? get continentalCup => _save?.continentalCup;

  /// 前シーズンの最終順位に基づき、来季の大陸カップ出場資格があるか。
  bool get qualifiedForContinentalCup => (_save?.lastSeasonRank ?? 99) <= 2;

  /// 国内カップ戦で、ブラケット全体の中で次に消化されるべき試合が自クラブの
  /// 試合であるかどうか。日程画面・ホーム画面から「カップ戦の順番が来ている」
  /// ことに気づけるようにするためのフラグ。
  bool get isUserDomesticCupMatchUpNext {
    final match = domesticCup?.nextUnplayedMatch;
    if (match == null || _save == null) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// リーグの現在の節番号(シーズン終了後は最終節+1)。カップ戦の消化間隔
  /// (現実の試合間隔の再現)を判定する基準として使う。
  int get _currentLeagueMatchdayMarker {
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    return nextMd ?? (_totalMatchdaysThisSeason + 1);
  }

  bool _canAdvanceCup(int? lastPlayedAtMatchday) {
    if (_save == null) return false;
    // リーグ戦が全節消化済み(オフシーズン)の間は、もう間隔を置く相手がいない
    // ため無制限に消化できる。そうしないと、リーグ完了後に残ったカップ戦は
    // 節数が二度と進まず永久に足止めされてしまう。
    if (_save!.league.nextUnplayedFixture == null) return true;
    return lastPlayedAtMatchday == null ||
        _currentLeagueMatchdayMarker > lastPlayedAtMatchday;
  }

  /// 国内カップ戦の次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextDomesticCupMatch =>
      domesticCup?.nextUnplayedMatch != null &&
      _canAdvanceCup(domesticCup!.lastPlayedAtMatchday);

  Future<MatchResult?> playNextCupMatch() async {
    if (_save == null) return null;
    final cup = domesticCup;
    if (cup == null || cup.nextUnplayedMatch == null) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;

    final match = cup.nextUnplayedMatch!;
    if (!match.isBye) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.awayTeamId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = CupEngine.playNextMatch(cup, allTeamsForCups);
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null) {
      _applyUserCupPostMatchEffects(result);
      _afterDomesticCupMatchApplied(match);
    }
    _notify();
    await _persist();
    return result;
  }

  /// 大陸カップに次に消化すべき試合(グループステージ、または決勝
  /// トーナメント)が残っているか。
  bool _continentalHasNextMatch(ContinentalCup cup) {
    if (!cup.isGroupStageComplete) {
      return ContinentalCupEngine.nextGroupMatch(cup) != null;
    }
    return cup.knockoutRounds.isNotEmpty &&
        cup.knockoutRounds.last.any((t) => !t.isComplete);
  }

  /// 大陸カップの次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextContinentalMatch {
    final cup = _save?.continentalCup;
    if (cup == null || !_continentalHasNextMatch(cup)) return false;
    return _canAdvanceCup(cup.lastPlayedAtMatchday);
  }

  /// 大陸カップのグループステージ次の1試合を消化する。全組が終わると
  /// 自動的に決勝トーナメントの組み合わせが決定される。
  Future<MatchResult?> playNextContinentalGroupMatch() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final match = ContinentalCupEngine.nextGroupMatch(cup);
    if (match != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.awayTeamId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = ContinentalCupEngine.playNextGroupMatch(
      cup,
      allTeamsForCups,
    );
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null && match != null) {
      _applyUserCupPostMatchEffects(result);
      _afterContinentalGroupMatchApplied(match);
    }
    _notify();
    await _persist();
    return result;
  }

  /// 大陸カップの決勝トーナメント次の1レグを消化する。
  Future<MatchResult?> playNextContinentalKnockoutLeg() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    if (leg != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == leg.homeId);
      final away = allTeamsForCups.firstWhere((t) => t.id == leg.awayId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = ContinentalCupEngine.playNextKnockoutLeg(
      cup,
      allTeamsForCups,
    );
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null && leg != null) {
      _applyUserCupPostMatchEffects(result);
      _afterContinentalKnockoutLegApplied(leg.tie);
    }
    _notify();
    await _persist();
    return result;
  }

  /// 新シーズン開幕前のスーパーカップ(ユーザークラブが出場する場合のみ保留される)。
  CupMatch? get pendingSuperCup => _save?.pendingSuperCup;

  /// 直近のstartNextSeasonでユーザーが出場しないスーパーカップが自動消化された
  /// 場合のニュース文言。ない場合はnull(表示後は呼び出し側でクリアする想定)。
  String? lastSuperCupNews;

  /// 保留中のスーパーカップを消化する。ユーザークラブが出場する場合のみ有効。
  Future<MatchResult?> playSuperCup() async {
    if (_save == null || _save!.pendingSuperCup == null) return null;
    final match = _save!.pendingSuperCup!;
    final teams = _save!.allTeams;
    final home = teams.firstWhere((t) => t.id == match.homeTeamId);
    final away = teams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: 0,
      weather: WeatherEngine.roll(),
    );
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      match.penaltyWinnerId = CupEngine.decidePenaltyWinner(home, away);
    }
    _applyUserCupPostMatchEffects(result);
    _afterSuperCupApplied(match);
    _notify();
    await _persist();
    return result;
  }

  // ---- カップ戦のライブ観戦と共通後処理 ----

  /// 国内カップで1勝するごとの賞金(単位: 資金)。ラウンドが深いほど高額。
  static int domesticCupWinPrizeFor(int round) => 20 + 15 * round;

  /// 大陸カップのグループステージで1勝するごとの賞金。
  static const int continentalGroupWinPrize = 40;

  /// 大陸カップの決勝トーナメントで1タイ勝ち上がるごとの賞金。
  static const int continentalTieWinPrize = 150;

  bool get _isLiveMatchInProgress =>
      _liveFixture != null || _liveCupKind != null;

  /// 次の国内カップ未消化試合が自クラブの試合で、今すぐライブ観戦で
  /// 戦えるか(消化間隔・他のライブ試合との競合も考慮)。
  bool get canPlayNextDomesticCupMatchLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    if (!canPlayNextDomesticCupMatch) return false;
    final match = domesticCup?.nextUnplayedMatch;
    if (match == null || match.isBye) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// 次の大陸カップの試合(グループまたは決勝トーナメント)が自クラブの
  /// 試合で、今すぐライブ観戦で戦えるか。
  bool get canPlayNextContinentalMatchLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    if (!canPlayNextContinentalMatch) return false;
    final cup = _save!.continentalCup!;
    final userId = _save!.userTeamId;
    if (!cup.isGroupStageComplete) {
      final match = ContinentalCupEngine.nextGroupMatch(cup);
      return match != null &&
          (match.homeTeamId == userId || match.awayTeamId == userId);
    }
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    return leg != null && (leg.homeId == userId || leg.awayId == userId);
  }

  /// 保留中のスーパーカップをライブ観戦で戦えるか。
  bool get canPlaySuperCupLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    final match = _save!.pendingSuperCup;
    if (match == null) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// 自クラブのカップ試合をライブ観戦で開始する。開始できた場合、以降は
  /// リーグ戦のライブ観戦と同じAPI([pendingChanceDecision] /
  /// [resolveChanceDecision] / [playSecondHalf] / [makeLiveSubstitution] /
  /// [setMatchInstruction]等)で進行し、後半完了時に結果が該当大会へ
  /// 適用される(引き分け時のPK戦・賞金・敗退時の信頼度低下を含む)。
  /// [kind]に大陸カップを渡した場合は、現在の進行状況に応じてグループ/
  /// 決勝トーナメントを自動で選び分ける。開始できない場合はfalse。
  Future<bool> startCupMatchLive(LiveCupKind kind) async {
    if (_save == null || _isLiveMatchInProgress) return false;
    final userId = _save!.userTeamId;
    Team? home;
    Team? away;
    CupMatch? cupMatch;
    CupTie? tie;
    var resolvedKind = kind;
    switch (kind) {
      case LiveCupKind.domestic:
        if (!canPlayNextDomesticCupMatchLive) return false;
        cupMatch = domesticCup!.nextUnplayedMatch;
        home = teamById(cupMatch!.homeTeamId);
        away = teamById(cupMatch.awayTeamId);
      case LiveCupKind.continentalGroup:
      case LiveCupKind.continentalKnockout:
        if (!canPlayNextContinentalMatchLive) return false;
        final cup = _save!.continentalCup!;
        if (!cup.isGroupStageComplete) {
          resolvedKind = LiveCupKind.continentalGroup;
          cupMatch = ContinentalCupEngine.nextGroupMatch(cup);
          home = teamById(cupMatch!.homeTeamId);
          away = teamById(cupMatch.awayTeamId);
        } else {
          resolvedKind = LiveCupKind.continentalKnockout;
          final leg = ContinentalCupEngine.nextKnockoutLeg(cup)!;
          tie = leg.tie;
          home = teamById(leg.homeId);
          away = teamById(leg.awayId);
        }
      case LiveCupKind.superCup:
        if (!canPlaySuperCupLive) return false;
        cupMatch = _save!.pendingSuperCup;
        home = teamById(cupMatch!.homeTeamId);
        away = teamById(cupMatch.awayTeamId);
    }
    if (home == null || away == null) return false;
    final weather = WeatherEngine.roll();
    _liveCupKind = resolvedKind;
    _liveCupHome = home;
    _liveCupAway = away;
    _liveCupWeather = weather;
    _liveCupMatch = cupMatch;
    _liveCupTie = tie;
    _liveSubstitutionsUsed = 0;
    lastLiveCupNote = null;
    lastCupPrizeNote = null;
    lastShootout = null;
    _liveWasInteractive = true; // カップのライブ観戦は常に決定機の判断あり
    _liveFirstHalfState = MatchEngine.beginInteractiveHalf(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      interactiveTeamId: userId,
      weather: weather,
      homeAdvantageFactor: _homeAdvantageFor(home.id),
    );
    _notify();
    await _persist();
    return true;
  }

  /// ライブ観戦で確定したカップ試合の結果を、該当大会へ適用する
  /// (試合後効果は_finalizeSecondHalfの共通処理で適用済みのため行わない)。
  void _applyLiveCupResult(MatchResult merged) {
    final kind = _liveCupKind;
    if (kind == null || _save == null) return;
    switch (kind) {
      case LiveCupKind.domestic:
        final cup = domesticCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return;
        if (merged.homeGoals == merged.awayGoals) {
          match.penaltyWinnerId = _runLiveShootout().winnerId;
        }
        CupEngine.applyMatchResult(cup, allTeamsForCups, match, merged);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _noteLiveCupPenalty(match.penaltyWinnerId, merged);
        _afterDomesticCupMatchApplied(match);
      case LiveCupKind.continentalGroup:
        final cup = _save!.continentalCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return;
        ContinentalCupEngine.applyGroupMatchResult(
            cup, allTeamsForCups, match, merged);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterContinentalGroupMatchApplied(match);
      case LiveCupKind.continentalKnockout:
        final cup = _save!.continentalCup;
        final tie = _liveCupTie;
        if (cup == null || tie == null) return;
        // このレグでタイが完了し、合計スコアが同点になる場合のみPK戦。
        if (tie.legs.length + 1 >= tie.totalLegs) {
          final mergedForA = merged.homeTeamId == tie.teamAId
              ? merged.homeGoals
              : merged.awayGoals;
          final mergedForB = merged.homeTeamId == tie.teamBId
              ? merged.homeGoals
              : merged.awayGoals;
          if (tie.goalsFor(tie.teamAId) + mergedForA ==
              tie.goalsFor(tie.teamBId) + mergedForB) {
            tie.penaltyWinnerId = _runLiveShootout().winnerId;
          }
        }
        ContinentalCupEngine.applyKnockoutLegResult(
            cup, allTeamsForCups, tie, merged);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _noteLiveCupPenalty(tie.penaltyWinnerId, merged);
        _afterContinentalKnockoutLegApplied(tie);
      case LiveCupKind.superCup:
        final match = _liveCupMatch;
        if (match == null) return;
        match.result = merged;
        if (merged.homeGoals == merged.awayGoals) {
          match.penaltyWinnerId = _runLiveShootout().winnerId;
        }
        _noteLiveCupPenalty(match.penaltyWinnerId, merged);
        _afterSuperCupApplied(match);
    }
    _evaluateAchievements();
  }

  /// ライブ観戦のカップ戦がPK戦にもつれた際、1本ずつのシュートアウトを
  /// 実施して勝者を決める。記録は[lastShootout]に保持し、フルタイム画面が
  /// 1本ごとの成否を演出表示する。自クラブが勝てばPK戦勝利数も記録する。
  PenaltyShootoutResult _runLiveShootout() {
    final shootout = CupEngine.simulateShootout(_liveCupHome!, _liveCupAway!);
    lastShootout = shootout;
    if (shootout.winnerId == _save!.userTeamId) {
      _save!.pkShootoutWins++;
    }
    return shootout;
  }

  /// ライブ観戦したカップ試合が同点でPK戦にもつれた場合、フルタイム画面で
  /// 表示する決着の文言をセットする。
  void _noteLiveCupPenalty(String? penaltyWinnerId, MatchResult merged) {
    if (penaltyWinnerId == null) return;
    final shootout = lastShootout;
    // 2レグ制では最終レグ自体は引き分けでなくても合計同点でPK戦になり得る
    // ため、シュートアウト記録がある場合はスコア条件を問わず文言を出す。
    if (shootout == null && merged.homeGoals != merged.awayGoals) return;
    final winner = teamById(penaltyWinnerId) ??
        (penaltyWinnerId == _liveCupHome?.id ? _liveCupHome : _liveCupAway);
    if (winner == null) return;
    lastLiveCupNote = shootout != null
        ? Tr.pick(
            'PK戦 ${shootout.homeScore}-${shootout.awayScore} の末、${winner.name}が勝ち上がり!',
            '${winner.name} go through ${shootout.homeScore}-${shootout.awayScore} on penalties!')
        : Tr.pick('PK戦の末、${winner.name}が勝ち上がり!',
            '${winner.name} go through on penalties!');
  }

  /// 自クラブが関わるカップ試合に、リーグ戦と同じ試合後効果(疲労・負傷・
  /// 警告累積・通算出場/得点の記録など)を適用する。カップ戦でも
  /// ローテーションが意味を持つようにするための共通処理で、自動消化の
  /// 経路から呼ぶ(ライブ観戦の経路では確定処理側で適用済み)。
  void _applyUserCupPostMatchEffects(MatchResult result) {
    if (_save == null) return;
    final userId = _save!.userTeamId;
    if (result.homeTeamId != userId && result.awayTeamId != userId) return;
    final home = teamById(result.homeTeamId);
    final away = teamById(result.awayTeamId);
    if (home == null || away == null) return;
    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: _injuryFactorFor(home.id),
      awayInjuryFactor: _injuryFactorFor(away.id),
      events: result.events,
      weather: result.weather,
    );
  }

  /// 直近のカップ戦で自クラブが獲得した賞金の通知文。賞金は従来budgetへ
  /// 無言で加算されており、プレイヤーが「勝つと賞金が入る」ことに気づけ
  /// なかったため、獲得のたびにここへ文言を積み、UI側(クイック消化の
  /// SnackBar/ライブのフルタイム画面)が表示後にnullへ戻す。
  String? lastCupPrizeNote;

  /// シーズン終了時に理事会の目標順位を達成した場合の報奨金の通知文。
  /// UI側(シーズン開始処理後のSnackBar)が表示に使う。
  String? lastBoardBonusNote;

  /// シーズン終了時の監督契約(任期)の去就の通知文。
  String? lastManagerContractNote;

  /// 国内カップのブラケット全ラウンド数(1回戦から決勝まで)。
  int _domesticCupTotalRounds(Cup cup) {
    final firstRoundMatches = cup.rounds.first.length;
    if (firstRoundMatches <= 0) return 0;
    return (log(firstRoundMatches * 2) / ln2).round();
  }

  /// 理事会が期待する国内カップの到達ラウンドを、リーグ内の戦力順位から
  /// 見積もる(国内カップが未生成なら0=期待なし)。
  int _estimateDomesticCupTarget() {
    final cup = domesticCup;
    if (cup == null || _save == null) return 0;
    final teams = [..._save!.league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final rank = teams.indexWhere((t) => t.id == _save!.userTeamId) + 1;
    if (rank <= 0) return 0;
    return BoardEngine.estimateCupTargetRound(
      strengthRank: rank,
      teamCount: teams.length,
      totalRounds: _domesticCupTotalRounds(cup),
    );
  }

  /// 理事会のカップ目標の表示ラベル(例: 「準決勝」)。未設定ならnull。
  String? get boardCupTargetLabel {
    final cup = domesticCup;
    final target = _save?.boardCupTargetRound ?? 0;
    if (cup == null || target <= 0) return null;
    return CupEngine.roundLabel(target, _domesticCupTotalRounds(cup));
  }

  /// 国内カップの1試合が大会へ適用された後の共通処理(自動消化・ライブ
  /// 共通)。自クラブの勝利賞金・敗退時の信頼度低下・優勝報酬を扱う。
  void _afterDomesticCupMatchApplied(CupMatch match) {
    final cup = domesticCup;
    if (cup == null || _save == null) return;
    final userId = _save!.userTeamId;
    final userInvolved =
        match.homeTeamId == userId || match.awayTeamId == userId;
    if (userInvolved) {
      if (match.winnerId == userId) {
        final prize = domesticCupWinPrizeFor(match.round);
        _save!.budget += prize;
        _save!.careerCupPrize += prize;
        lastCupPrizeNote = Tr.pick(
            '勝利賞金として$prize万円を獲得!', 'You collected $prize in prize money!');
        _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
      } else if (cup.isEliminated(userId)) {
        // 理事会のカップ目標(到達ラウンド)と実際の成績を突き合わせる。
        final reached = match.round;
        final target = _save!.boardCupTargetRound;
        final label = boardCupTargetLabel;
        if (target > 0 && reached >= target) {
          _save!.confidence = (_save!.confidence + 2).clamp(0, 100);
          _logNews(
              Tr.pick('国内カップは理事会の期待($label進出)に応えた。敗退したが評価は上々だ',
                  "You met the board's expectation in the domestic cup (reaching the $label). You are out, but they are pleased"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else if (target > 0 && target - reached >= 2) {
          _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
          _logNews(
              Tr.pick('国内カップで早期敗退。理事会の期待($label進出)を大きく裏切った',
                  "An early exit from the domestic cup, well short of the board's expectation of the $label"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else {
          _save!.confidence = (_save!.confidence - 1).clamp(0, 100);
        }
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      _save!.budget += 700;
      _save!.careerCupPrize += 700;
      _save!.confidence = (_save!.confidence + 10).clamp(0, 100);
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
  }

  /// 大陸カップのグループステージ1試合が適用された後の共通処理。
  void _afterContinentalGroupMatchApplied(CupMatch match) {
    final cup = _save?.continentalCup;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInvolved =
        match.homeTeamId == userId || match.awayTeamId == userId;
    if (!userInvolved) return;
    final r = match.result;
    final userWon = r != null &&
        ((r.homeTeamId == userId && r.homeGoals > r.awayGoals) ||
            (r.awayTeamId == userId && r.awayGoals > r.homeGoals));
    if (userWon) {
      _save!.budget += continentalGroupWinPrize;
      _save!.careerCupPrize += continentalGroupWinPrize;
      lastCupPrizeNote = Tr.pick('勝利賞金として$continentalGroupWinPrize万円を獲得!',
          'You collected $continentalGroupWinPrize in prize money!');
      _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
    }
    if (cup.isEliminated(userId)) {
      _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
    }
  }

  /// 大陸カップの決勝トーナメント1レグが適用された後の共通処理。
  void _afterContinentalKnockoutLegApplied(CupTie tie) {
    final cup = _save?.continentalCup;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInTie = tie.teamAId == userId || tie.teamBId == userId;
    if (userInTie) {
      if (tie.isComplete && tie.winnerId == userId) {
        _save!.budget += continentalTieWinPrize;
        _save!.careerCupPrize += continentalTieWinPrize;
        lastCupPrizeNote = Tr.pick('勝ち上がり賞金として$continentalTieWinPrize万円を獲得!',
            'You collected $continentalTieWinPrize for going through!');
        _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
      }
      if (cup.isEliminated(userId)) {
        _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      _save!.budget += 1500;
      _save!.careerCupPrize += 1500;
      _save!.confidence = (_save!.confidence + 20).clamp(0, 100);
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
  }

  /// スーパーカップの結果が確定した後の共通処理。
  void _afterSuperCupApplied(CupMatch match) {
    if (_save == null) return;
    if (match.winnerId == _save!.userTeamId) {
      _save!.trophyHistory.add(Tr.pick('シーズン${_save!.league.season} スーパーカップ優勝',
          'Season ${_save!.league.season} Super Cup winners'));
    }
    _save!.pendingSuperCup = null;
  }

  /// 大陸カップに参加する海外クラブ名を生成する。5つの国風テーマから
  /// バランスよく取り混ぜることで、実際の大陸カップのように様々な国風の
  /// クラブが顔をそろえるようにする(自国リーグと同じ命名規則を流用しつつ、
  /// テーマを散らして「他国のクラブ」らしさを出す)。
  List<Team> _generateContinentalTeams() {
    final rng = Random();
    const totalTeams = 7;
    final themes = List<LeagueTheme>.from(LeagueTheme.values)..shuffle(rng);
    final names = <String>[];
    var remaining = totalTeams;
    for (int i = 0; i < themes.length && remaining > 0; i++) {
      final take = (remaining / (themes.length - i)).ceil();
      names.addAll(NamePool.themedClubNames(themes[i], take));
      remaining -= take;
    }
    final teams = <Team>[];
    for (int i = 0; i < totalTeams; i++) {
      final t = PlayerGenerator.generateSquad(
        id: 'continental$i',
        name: names[i],
        strengthTier: 65 + rng.nextInt(20),
      );
      LineupUtils.autoFill(t);
      teams.add(t);
    }
    return teams;
  }

  /// 直近の昇格で理事会から支給された補強予算(万円)。昇格していなければ0。
  int lastPromotionBonus = 0;

  /// 直近のstartNextSeasonでの昇格・降格結果メッセージ(なければnull)。
  String? lastDivisionChangeMessage;

  /// 直近のstartNextSeasonで昇格プレーオフが行われた場合の各試合結果
  /// (準決勝2試合+決勝の順、表示用に整形済み)。行われなかった場合は空。
  List<String> lastPromotionPlayoffResults = [];

  /// 直近のプレーオフにユーザークラブが出場していたかどうか。
  bool userInvolvedInLastPromotionPlayoff = false;

  Future<void> startNextSeason() async {
    if (_save == null) return;
    isBusy = true;
    _notify();
    // ローディング表示を1フレーム描画させてから、裏ディビジョンの1シーズン分の
    // シミュレーションなど重い処理に入る。
    await Future<void>.delayed(Duration.zero);
    final league = _save!.league;
    final standings = league.sortedStandings;
    final finalRank =
        standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final playedOrder = standings
        .map((r) => league.teams.firstWhere((t) => t.id == r.teamId))
        .toList();
    final playedTier = _save!.currentDivisionTier;

    // シーズン開始時点の総合力からの成長を選手ごとに算出し、シーズン終了時に
    // 一覧表示できるようにする。
    final previousOverallSnapshot = _save!.seasonStartOverallByPlayerId;
    lastSeasonGrowthSummary = [
      for (final p in userTeam.players)
        if (previousOverallSnapshot.containsKey(p.id))
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: previousOverallSnapshot[p.id]!,
            overallAfter: p.overall,
            attributeDeltas: const {},
          ),
    ];

    _save!.seasonAwards.add(AwardsEngine.computeAwards(league, league.season));
    _save!.bestElevenHistory.add(
      BestElevenEngine.compute(league, league.season),
    );

    // 監督としての通算成績を更新する。
    final userRow = standings.firstWhere((r) => r.teamId == _save!.userTeamId);
    _save!.careerWins += userRow.won;
    _save!.careerDraws += userRow.draw;
    _save!.careerLosses += userRow.lost;
    _save!.careerSeasons += 1;
    if (finalRank == 1) {
      final divisionLabel = playedTier == 1
          ? _save!.leagueName
          : Tr.pick('${_save!.leagueName}($playedTier部)',
              '${_save!.leagueName} (tier $playedTier)');
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${league.season}: $divisionLabel 優勝',
          'Season ${league.season}: $divisionLabel champions'));
    }

    // 年間最優秀監督賞: 総合力から見た期待順位を最も上回ったクラブに贈られる。
    lastSeasonManagerAwardWon = false;
    if (AwardsEngine.computeManagerOfSeason(league) == userTeam.name) {
      _save!.trophyHistory.add(Tr.pick('シーズン${league.season} 年間最優秀監督賞',
          'Season ${league.season} Manager of the Year'));
      lastSeasonManagerAwardWon = true;
    }

    // 下位ディビジョンほど観客動員・賞金が少ない(ティアごとに段階的に低下する)。
    var prizeMoney = BoardEngine.seasonPrizeMoney(
      finalRank: finalRank,
      teamCount: league.teams.length,
    );
    prizeMoney = (prizeMoney * pow(0.6, playedTier - 1)).round();
    _save!.budget += prizeMoney;
    final confidenceDelta = BoardEngine.confidenceDeltaForSeasonEnd(
      finalRank: finalRank,
      targetRank: _save!.boardTargetRank,
    );
    _save!.confidence = (_save!.confidence + confidenceDelta).clamp(0, 100);

    // 理事会の目標達成報奨金: シーズン目標順位を達成すると、リーグ賞金と
    // 同じティア係数で減衰する報奨金が理事会から支給される。目標を大きく
    // 上回った場合(3つ以上)は1.5倍に増額し、快挙をしっかり報いる。
    lastBoardBonusNote = null;
    if (finalRank <= _save!.boardTargetRank) {
      var bonus = (300 * pow(0.6, playedTier - 1)).round();
      final exceeded = _save!.boardTargetRank - finalRank >= 3;
      if (exceeded) bonus = (bonus * 1.5).round();
      _save!.budget += bonus;
      lastBoardBonusNote = exceeded
          ? Tr.pick('理事会目標を大きく上回り、報奨金$bonus万円が支給されました!',
              "You beat the board's target comfortably, and they have paid you a $bonus bonus!")
          : Tr.pick('理事会目標を達成し、報奨金$bonus万円が支給されました!',
              "You met the board's target, and they have paid you a $bonus bonus!");
    }

    // 監督契約(任期)の更新。旧セーブ(0=未導入)はまず2年契約を結ぶ。
    lastManagerContractNote = null;
    if (_save!.managerContractYears <= 0) {
      _save!.managerContractYears = 2;
      lastManagerContractNote = Tr.pick(
          '理事会と2年の監督契約を結んだ', 'You signed a two-year contract with the board');
    } else {
      final outcome = BoardEngine.managerContractAfterSeason(
        yearsRemaining: _save!.managerContractYears,
        targetMet: finalRank <= _save!.boardTargetRank,
        confidence: _save!.confidence,
      );
      _save!.managerContractYears = outcome.years;
      switch (outcome.event) {
        case ManagerContractEvent.extended:
          lastManagerContractNote = Tr.pick('目標達成が評価され、監督契約が3年に延長された!',
              'They liked what they saw, and your contract has been extended to three years!');
        case ManagerContractEvent.renewedOneYear:
          lastManagerContractNote = Tr.pick('契約満了。理事会は単年契約での続投を提示し、受け入れた',
              'Your contract expired. The board offered a one-year extension, and you took it');
        case ManagerContractEvent.finalYearWarning:
          lastManagerContractNote = Tr.pick('監督契約は残り1年。今シーズンの成績が去就を左右する',
              'One year left on your contract. This season decides your future');
        case ManagerContractEvent.dismissed:
          // 契約非更新=解任。既存の解任フロー(信頼度0)に合流させる。
          _save!.confidence = 0;
          lastManagerContractNote = Tr.pick('成績不振により契約は更新されなかった(解任)',
              'Results were not good enough, and your contract was not renewed (sacked)');
        case ManagerContractEvent.none:
          break;
      }
    }

    for (final t in _save!.allTeams) {
      for (final p in t.players) {
        p.age += 1;
      }
      // CPUクラブは自クラブ(userTeam、下でRetirementEngine.resolveRetirements
      // を個別に呼ぶ)と違って移籍市場で世代交代しないため、ここで代わりに
      // 引退+若手補充を行う。行わないと選手が永遠に加齢し続けてしまう。
      if (t.id != _save!.userTeamId) {
        RetirementEngine.resolveAndReplaceForCpu(t);
      }
    }
    final infra = _save!.infrastructure;
    // ユースインテーク: 複数候補を一括生成し、選抜はユーザーに委ねる。
    final intakeCount = 3 + Random().nextInt(3);
    _save!.pendingYouthIntake = List.generate(
      intakeCount,
      (_) => ScoutingEngine.generateAcademyGraduate(
        youthCoachLevel: infra.staffLevel(StaffRole.youthCoach),
      ),
    );

    // 監督としての世間の評価を更新する(目標達成なら上昇、大きく未達なら下降)。
    if (finalRank <= _save!.boardTargetRank) {
      _save!.managerReputation = (_save!.managerReputation + 8).clamp(0, 100);
    } else if (finalRank > _save!.boardTargetRank + 2) {
      _save!.managerReputation = (_save!.managerReputation - 5).clamp(0, 100);
    }
    // 評価が高く好成績を残すと、他クラブから監督就任オファーが届くことがある(1部のみ)。
    if (playedTier == 1 &&
        _save!.pendingJobOfferTeamId == null &&
        _save!.managerReputation >= 55 &&
        finalRank <= (league.teams.length / 2).ceil()) {
      final candidates = league.teams
          .where(
            (t) =>
                t.id != _save!.userTeamId &&
                t.overallRating > userTeam.overallRating,
          )
          .toList()
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
      if (candidates.isNotEmpty && Random().nextDouble() < 0.25) {
        _save!.pendingJobOfferTeamId = candidates.first.id;
      }
    }

    // 昇格・降格を解決する。ユーザーの現在ティア以外は節ごとに並行して
    // 消化してきたため、その最終順位順をそのまま使う(改めてシミュレート
    // し直さない)。各境界(1部/2部、2部/3部、…)は隣接ティアの実際の最終
    // 順位のみを根拠に独立して解決する。前の境界の解決結果を次の境界に
    // 連鎖させると、降格してきたばかりのチームがその配列内の並び順の都合で
    // さらに1段降格してしまう(1シーズンで複数ティア移動する)バグになるため、
    // 各ティアの「移動元(outgoing)」「移動先(incoming)」だけを集計し、
    // 最後にまとめて新編成を組み立てる。
    List<Team> orderedTeamsForTier(int tier) {
      if (tier == playedTier) return playedOrder;
      final other = _save!.otherDivisionLeagues[tier - 1]!;
      final otherStandings = other.sortedStandings;
      return otherStandings
          .map((r) => other.teams.firstWhere((t) => t.id == r.teamId))
          .toList();
    }

    final tierOrder = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: orderedTeamsForTier(tier),
    };
    final outgoingIds = <int, Set<String>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <String>{},
    };
    final incomingTeams = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <Team>[],
    };
    var relevantPlayoffMatches = const <PromotionPlayoffMatch>[];
    for (int upperTier = 1; upperTier < totalDivisionTiers; upperTier++) {
      final lowerTier = upperTier + 1;
      final upperOrder = tierOrder[upperTier]!;
      final lowerOrder = tierOrder[lowerTier]!;
      final result = PromotionEngine.resolve(
        tier1Teams: upperOrder,
        tier2Teams: lowerOrder,
        tier1PlayedOrder: upperOrder,
        tier2PlayedOrder: lowerOrder,
      );
      final upperIds = upperOrder.map((t) => t.id).toSet();
      final lowerIds = lowerOrder.map((t) => t.id).toSet();
      final promoted =
          result.tier1.where((t) => !upperIds.contains(t.id)).toList();
      final relegated =
          result.tier2.where((t) => !lowerIds.contains(t.id)).toList();

      outgoingIds[upperTier]!.addAll(relegated.map((t) => t.id));
      outgoingIds[lowerTier]!.addAll(promoted.map((t) => t.id));
      incomingTeams[upperTier]!.addAll(promoted);
      incomingTeams[lowerTier]!.addAll(relegated);

      if (lowerTier == playedTier) {
        relevantPlayoffMatches = result.promotionPlayoff;
      }
    }

    final newTeamsByTier = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: [
          ...tierOrder[tier]!.where((t) => !outgoingIds[tier]!.contains(t.id)),
          ...incomingTeams[tier]!,
        ],
    };

    var newTier = playedTier;
    for (final entry in newTeamsByTier.entries) {
      if (entry.value.any((t) => t.id == _save!.userTeamId)) {
        newTier = entry.key;
        break;
      }
    }
    final newActiveTeams = newTeamsByTier[newTier]!;

    final userInPromotionPlayoff = relevantPlayoffMatches.any(
      (m) => m.homeId == _save!.userTeamId || m.awayId == _save!.userTeamId,
    );
    lastPromotionPlayoffResults = relevantPlayoffMatches
        .map(
          (m) => Tr.pick(
              '${m.roundLabel}: ${m.homeName} ${m.homeGoals}-${m.awayGoals} ${m.awayName}${m.decidedByPenalties ? '(PK: ${m.winnerName}が勝利)' : ''}',
              "${m.roundLabel}: ${m.homeName} ${m.homeGoals}-${m.awayGoals} ${m.awayName}${m.decidedByPenalties ? ' (pens: ${m.winnerName})' : ''}"),
        )
        .toList();
    userInvolvedInLastPromotionPlayoff = userInPromotionPlayoff;
    lastPromotionBonus = 0;
    if (newTier > playedTier) {
      lastDivisionChangeMessage = Tr.pick(
          '降格が決まりました。来シーズンは$newTier部リーグでの再出発です。',
          'You are relegated. Next season starts again in tier $newTier.');
    } else if (newTier < playedTier) {
      // 昇格ボーナス: 上のディビジョンで戦うための補強予算が理事会から
      // 支給される(放映権料・スポンサー収入の増加分)。これがないと
      // 戦力差を埋める資金がなく、昇格と降格を往復し続けることになる。
      final promotionBonus = BoardEngine.promotionBonusFor(newTier);
      _save!.budget += promotionBonus;
      lastPromotionBonus = promotionBonus;
      lastDivisionChangeMessage = userInPromotionPlayoff
          ? Tr.pick(
              '昇格プレーオフを勝ち抜き、来シーズンは$newTier部リーグに昇格します！理事会から補強予算$promotionBonus万円が支給されました。',
              'You came through the play-offs and go up to tier $newTier next season. The board has given you $promotionBonus to strengthen.')
          : Tr.pick(
              '昇格達成！来シーズンは$newTier部リーグに昇格します。理事会から補強予算$promotionBonus万円が支給されました。',
              'Promoted. You go up to tier $newTier next season, and the board has given you $promotionBonus to strengthen.');
    } else if (userInPromotionPlayoff) {
      lastDivisionChangeMessage = Tr.pick(
          '昇格プレーオフで敗れ、来シーズンも$playedTier部リーグで戦います。',
          'You lost in the play-offs, and stay in tier $playedTier next season.');
    } else {
      lastDivisionChangeMessage = null;
    }
    _save!.currentDivisionTier = newTier;
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == newTier) {
        _save!.otherDivisionLeagues[tier - 1] = null;
        continue;
      }
      final tierTeams = newTeamsByTier[tier]!;
      _save!.otherDivisionLeagues[tier - 1] = League(
        teams: tierTeams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(tierTeams),
        season: league.season + 1,
      );
    }

    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(
      newActiveTeams,
    );
    _save!.league = League(
      teams: newActiveTeams,
      fixtures: newFixtures,
      season: league.season + 1,
    );
    _save!.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId),
    );
    // 続投が決まった監督には、新シーズン開幕時に最低限の信頼度を戻す
    // (解任が確定している場合は信頼度0のままにして解任フローを壊さない)。
    if (_save!.confidence > 0 && _save!.managerContractYears > 0) {
      _save!.confidence =
          max(_save!.confidence, BoardEngine.newSeasonConfidenceFloor);
    }
    _save!.wageBudget = BoardEngine.wageBudgetFor(
      tier: _save!.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
    );
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);

    // スポンサー契約(年単位)はシーズン境界で1年分消化する。
    if (_save!.sponsorDeal != null) {
      _save!.sponsorDeal!.yearsRemaining -= 1;
      if (_save!.sponsorDeal!.yearsRemaining <= 0) {
        _save!.sponsorDeal = null;
      }
    }
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
      );
    }

    // 高齢選手の引退判定(ユースプロスペクトは対象外)。
    final retirees = RetirementEngine.resolveRetirements(userTeam);
    for (final p in retirees) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    _save!.retiredLegends.addAll(retirees);
    lastRetirements = retirees.map((p) => p.name).toList();

    // 選手契約(年単位)をシーズン境界で1年分消化する(CPUクラブの契約は
    // 管理対象外)。切れた契約はフリーエージェントプールへ移す。引退判定より
    // 後に行うことで、緊急補強の安全網が最終的なスカッド人数を保証できる
    // ようにする。
    final contractResult = ContractEngine.advanceSeason(userTeam);
    lastContractExpirations =
        contractResult.expired.map((p) => p.name).toList();
    lastContractWarnings =
        contractResult.nearingExpiry.map((p) => p.name).toList();
    for (final p in contractResult.expired) {
      _clearPlayerRoleReferences(userTeam, p.id);
      if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize) {
        _save!.freeAgents.add(p);
      }
    }
    // 契約満了・引退により編成人数が最低人数を割り込んだ場合の緊急補強(安全網)。
    lastEmergencySignings = [];
    while (userTeam.players.length < seasonStartSquadSize) {
      final signing = FreeAgentEngine.generateEmergencySigning();
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }

    _save!.lastSeasonRank = finalRank;

    final cupsWonThisSeason = [
      ..._save!.cups
          .where((c) => c.championId == _save!.userTeamId)
          .map((c) => c.name),
      if (_save!.continentalCup?.championId == _save!.userTeamId)
        _save!.continentalCup!.name,
    ];
    _save!.seasonHistory.add(
      SeasonRecord(
        season: league.season,
        clubName: _save!.clubName,
        leagueName: _save!.leagueName,
        divisionTier: playedTier,
        finalRank: finalRank,
        teamCount: league.teams.length,
        played: userRow.played,
        won: userRow.won,
        draw: userRow.draw,
        lost: userRow.lost,
        goalsFor: userRow.goalsFor,
        goalsAgainst: userRow.goalsAgainst,
        wonLeague: finalRank == 1,
        promoted: newTier < playedTier,
        relegated: newTier > playedTier,
        cupsWon: cupsWonThisSeason,
      ),
    );
    _evaluateAchievements(season: league.season);

    // スーパーカップ: 前シーズンのリーグ王者と国内カップ王者(同一クラブが両方
    // 制した場合はカップ準優勝クラブ)が新シーズン開幕前に対戦する。カップが
    // 未消化のままシーズンが終わった場合は開催しない。
    lastSuperCupNews = null;
    Cup? previousDomesticCup;
    for (final c in _save!.cups) {
      if (c.type == CupType.domestic) {
        previousDomesticCup = c;
        break;
      }
    }
    if (previousDomesticCup != null) {
      final pairing = SuperCupEngine.pairing(
        leagueChampionId: standings.first.teamId,
        domesticCup: previousDomesticCup,
      );
      final teamsThisSeason = newTeamsByTier.values.expand((t) => t).toList();
      Team? findTeam(String id) {
        for (final t in teamsThisSeason) {
          if (t.id == id) return t;
        }
        return null;
      }

      final champion = pairing == null ? null : findTeam(pairing.$1);
      final opponent = pairing == null ? null : findTeam(pairing.$2);
      if (champion != null && opponent != null && champion.id != opponent.id) {
        final superCup = CupMatch(
          round: 1,
          homeTeamId: champion.id,
          awayTeamId: opponent.id,
        );
        if (champion.id == _save!.userTeamId ||
            opponent.id == _save!.userTeamId) {
          _save!.pendingSuperCup = superCup;
        } else {
          final result = MatchEngine.simulate(
            home: champion,
            away: opponent,
            matchday: 0,
            weather: WeatherEngine.roll(),
          );
          superCup.result = result;
          if (result.homeGoals == result.awayGoals) {
            superCup.penaltyWinnerId = CupEngine.decidePenaltyWinner(
              champion,
              opponent,
            );
          }
          final winnerName =
              superCup.winnerId == champion.id ? champion.name : opponent.name;
          lastSuperCupNews = Tr.pick(
              '$winnerNameがスーパーカップを制した。', '$winnerName won the Super Cup.');
        }
      }
    }

    _save!.cups = [
      CupEngine.createKnockout(
        type: CupType.domestic,
        name: currentLeagueTheme.domesticCupName,
        teamIds: newActiveTeams.map((t) => t.id).toList(),
      ),
    ];
    _save!.boardCupTargetRound = _estimateDomesticCupTarget();
    if (playedTier == 1 && finalRank <= 2) {
      final continentalTeams = _generateContinentalTeams();
      _save!.continentalTeams = continentalTeams;
      _save!.continentalCup = ContinentalCupEngine.create(
        name: Tr.pick('大陸チャンピオンズカップ', 'Continental Champions Cup'),
        teamIds: [_save!.userTeamId, ...continentalTeams.map((t) => t.id)],
      );
    } else {
      _save!.continentalTeams = [];
      _save!.continentalCup = null;
    }
    _save!.friendlies = _generateFriendlies(newActiveTeams, _save!.userTeamId);
    _save!.boardReviewDoneThisSeason = false;
    _save!.pendingBoardReviewMessage = null;
    _save!.lastManagerOfMonthCheckpoint = 0;
    // シーズン最終週に自動実施等でトレーニング済みのまま次シーズンへ入ると、
    // プレシーズン中ずっとrunWeeklyTrainingが「実施済み」扱いでブロックされて
    // しまうため、週次フラグも明示的にリセットする。
    _save!.trainingDoneThisWeek = false;

    // 次シーズン終了時の成長算出のため、開始時点の総合力を記録しておく。
    _save!.seasonStartOverallByPlayerId = {
      for (final p in userTeam.players) p.id: p.overall,
    };

    // シーズン開始レポートに載る通知をクラブニュース履歴にも記録する。
    final newsCtx = Tr.pick('シーズン開始', 'Season start');
    if (lastDivisionChangeMessage != null) {
      _logNews(lastDivisionChangeMessage!, context: newsCtx);
    }
    if (lastBoardBonusNote != null) {
      _logNews(lastBoardBonusNote!, context: newsCtx);
    }
    if (lastManagerContractNote != null) {
      _logNews(lastManagerContractNote!, context: newsCtx);
    }
    if (lastSeasonManagerAwardWon) {
      _logNews(Tr.pick('年間最優秀監督賞を受賞しました！', 'You won Manager of the Year!'),
          context: newsCtx);
    }
    if (lastSuperCupNews != null) {
      _logNews(lastSuperCupNews!, context: newsCtx);
    }
    if (lastRetirements.isNotEmpty) {
      _logNews(
          Tr.pick('引退: ${lastRetirements.join('、')}',
              "Retired: ${lastRetirements.join(', ')}"),
          context: newsCtx);
    }
    if (lastContractExpirations.isNotEmpty) {
      _logNews(
          Tr.pick('契約満了で退団: ${lastContractExpirations.join('、')}',
              "Left on a free: ${lastContractExpirations.join(', ')}"),
          context: newsCtx);
    }
    if (lastContractWarnings.isNotEmpty) {
      _logNews(
          Tr.pick('契約最終年に突入: ${lastContractWarnings.join('、')}',
              "Into the final year of their contract: ${lastContractWarnings.join(', ')}"),
          context: newsCtx);
    }
    if (lastEmergencySignings.isNotEmpty) {
      _logNews(
          Tr.pick('緊急補強: ${lastEmergencySignings.join('、')}',
              "Emergency signings: ${lastEmergencySignings.join(', ')}"),
          context: newsCtx);
    }

    isBusy = false;
    _notify();
    await _persist();
  }
}
