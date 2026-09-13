// GameState は 4700行超の単一クラスだった。関心事ごとに part + extension へ
// 分割してある(game_state_squad / _transfer / _finance / _match / _season)。
//
// これは「見た目の分割」であって結合度は下がっていない。extension は同じ
// ライブラリの一部なので、どのファイルからでも本体の private フィールドに
// 触れる。フィールドと static は extension に置けないため本体に残っている。
//
// 本当に結合を下げるなら、純粋な計算を lib/logic/*_engine.dart へ抽出するのが
// このコードベースの流儀に合う。ただし startNextSeason と playNextMatchday は
// 状態変更と分かちがたいため、出せる範囲は限られる。将来の選択肢として記す。

import 'dart:async';
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
import '../monetization/funds_pack.dart';
import '../monetization/reward_offer.dart';
import '../l10n/tr.dart';
import '../logic/development_advisor.dart';
import '../logic/match_factor_engine.dart';
import '../logic/reserve_match_engine.dart';
import '../logic/staff_market.dart';
import '../models/corner_routine.dart';
import '../models/club_vision.dart';
import '../models/preseason_camp.dart';
import '../models/opposition_plan.dart';
import '../models/player_instruction.dart';
import '../models/staff_member.dart';

part 'game_state_squad.dart';
part 'game_state_transfer.dart';
part 'game_state_finance.dart';
part 'game_state_match.dart';
part 'game_state_season.dart';

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

  /// 直近のリザーブ(Bチーム)の試合結果。人数が足りず行われなかった週は null。
  /// セーブには残さない。次の週次処理で必ず入れ替わるため。
  ReserveMatchResult? lastReserveMatch;

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

  /// 今シーズンの残り節数。シーズンを終えていれば0。
  ///
  /// 表彰・シーズン成績・ベストイレブンはシーズンを1つ終えるまで空のままなので、
  /// 「あと何節で開くか」をメニューに出すために使う。
  int get remainingMatchdaysThisSeason {
    if (_save == null) return 0;
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    if (nextMd == null) return 0; // シーズン終了後
    final total = _totalMatchdaysThisSeason;
    if (total == 0) return 0;
    return (total - nextMd + 1).clamp(0, total);
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

  /// 移籍ウィンドウが閉じるまでの残り節数。
  ///
  /// 閉じているとき、オフシーズン、開幕前(締切は開幕そのもの)は null。
  /// 締切が見えないと「まだ動ける」と思っているうちに閉まってしまう。
  int? get transferWindowMatchdaysLeft {
    if (_save == null || !isTransferWindowOpen) return null;
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    if (nextMd == null) return null; // オフシーズン(期限なし)
    final total = _totalMatchdaysThisSeason;
    if (total == 0) return null;
    if (nextMd <= 1) return 1; // 開幕前。開幕したら閉まる
    final midStart = total ~/ 2;
    return midStart + 2 - nextMd + 1;
  }

  /// この節を終えるとウィンドウが閉じるか。
  bool get isTransferDeadlineMatchday => transferWindowMatchdaysLeft == 1;

  /// UI表示用の移籍ウィンドウ状態文言。
  String get transferWindowStatusLabel {
    if (isTransferWindowOpen) {
      final left = transferWindowMatchdaysLeft;
      if (left == null) {
        return Tr.pick('移籍ウィンドウ: オープン中', 'Transfer window: open');
      }
      if (left <= 1) {
        return Tr.pick('移籍ウィンドウ: 今節で締切', 'Transfer window: deadline is this matchday');
      }
      return Tr.pick('移籍ウィンドウ: オープン中（あと$left節で締切）',
          'Transfer window: open ($left matchdays to the deadline)');
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
  /// 保存をまとめるためのタイマー。
  Timer? _persistTimer;

  /// 保存の間隔。短くすると中断時に失う変更が減るが、まとめる効果も減る。
  static const Duration persistDebounce = Duration(milliseconds: 400);

  /// 「今どのセーブが正か」を表す世代番号。新しくセーブを作る・読み込む
  /// たびに進む。
  ///
  /// 保存をまとめるようにしたことで、書き出しは予約から遅れて起きる。その間に
  /// 別のセーブが正になっていると、古い内容で上書きしてしまう。予約した時点の
  /// 世代を覚えておき、発火時に食い違っていたら書かない。
  ///
  /// static なのは、GameState を作り直しても保存先(端末のストレージ)は
  /// 共有だから。実際、前のインスタンスが残した予約が次のセーブを
  /// 上書きする形で CI が落ちた。
  static int _saveGeneration = 0;

  /// 保存を予約する。呼び出しが続く間は書き出さず、止まってからまとめて1回。
  ///
  /// セーブは1MBを超える(大半は他ディビジョンの選手データ)。設定を1つ変える
  /// たびに丸ごとJSON化していたため、1回あたり約26msかかっていた。60fpsの
  /// 1フレーム(16.7ms)を超えるので、スライダーを動かすと目に見えて引っかかる。
  /// 端から端まで動かすと1.3秒ぶんの処理が走っていた(実測)。
  ///
  /// 中断されると直近の変更を失うため、区切りになる操作([_persistNow])と
  /// アプリが背面に回るとき([flushPendingSave])は即時に書き出す。
  Future<void> _persist() async {
    // 予約時点のスロットを覚えておく。書き出しは後になるので、そのとき
    // currentSlot を読むと、間にスロットを切り替えられていた場合に別の
    // スロットへ書き込んでしまう。
    final slot = currentSlot;
    final generation = _saveGeneration;
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDebounce, () {
      _persistTimer = null;
      if (generation != _saveGeneration) return; // 既に別のセーブが正
      _persistNow(slot: slot);
    });
  }

  /// 予約されている保存があれば、待たずに書き出す。
  /// アプリが背面に回るときなど、中断されうる場面で呼ぶ。
  Future<void> flushPendingSave() async {
    if (_persistTimer == null) return;
    _persistTimer!.cancel();
    _persistTimer = null;
    await _persistNow();
  }

  /// 待たずに書き出す。予約されている保存はこれで置き換わるので取り消す。
  /// 取り消さないと、この書き出しの後から古い内容が上書きしにいく。
  Future<void> _persistNow({int? slot}) async {
    _persistTimer?.cancel();
    _persistTimer = null;
    final target = slot ?? currentSlot;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_save == null) {
        await prefs.remove(_slotKey(target));
      } else {
        await prefs.setString(
          _slotKey(target),
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

  @override
  void dispose() {
    // 破棄した後にタイマーが発火すると、既に別の状態になっている保存先へ
    // 書き込みにいく。テストのように複数の GameState を作る場面で顕在化する。
    _persistTimer?.cancel();
    _persistTimer = null;
    super.dispose();
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
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
    // 切り替える前に、今のスロット宛の保留を書き切る。残したまま切り替えると
    // 直前の変更が失われる(あるいは切り替え先へ書き込まれる)。
    await flushPendingSave();
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
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
    // 消す前に保留を書き切る。消した後に保留が発火すると復活してしまう。
    await flushPendingSave();
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
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
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
    // 新規開始時もキャンプの判断から始まる。
    _save!.preseasonCampPending = true;
    // 開始時は全役職が空席。誰を先に雇うかが最初の判断になる。
    _refreshStaffCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);
    lastContractExpirations = [];
    isBusy = false;
    _notify();
    await _persistNow();
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
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
    _save = null;
    transferMarket = [];
    scoutCandidates = [];
    lastContractExpirations = [];
    _notify();
    await _persistNow();
  }

  /// バックアップ用にセーブデータ全体をJSON文字列として書き出す。
  String? exportSaveJson() {
    if (_save == null) return null;
    return jsonEncode(_save!.toJson());
  }

  /// エクスポートされたJSON文字列からセーブデータを復元する。形式が不正な場合はfalseを返す。
  Future<bool> importSaveJson(String json) async {
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
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
    await _persistNow();
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
  static final Random _campRng = Random();

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

  /// 直近のstartNextSeasonでユーザーが出場しないスーパーカップが自動消化された
  /// 場合のニュース文言。ない場合はnull(表示後は呼び出し側でクリアする想定)。
  String? lastSuperCupNews;

  // ---- カップ戦のライブ観戦と共通後処理 ----

  /// 国内カップで1勝するごとの賞金(単位: 資金)。ラウンドが深いほど高額。
  static int domesticCupWinPrizeFor(int round) => 20 + 15 * round;

  /// 大陸カップのグループステージで1勝するごとの賞金。
  static const int continentalGroupWinPrize = 40;

  /// 大陸カップの決勝トーナメントで1タイ勝ち上がるごとの賞金。
  static const int continentalTieWinPrize = 150;

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

  /// 直近の昇格で理事会から支給された補強予算(万円)。昇格していなければ0。
  int lastPromotionBonus = 0;

  /// 直近のstartNextSeasonでの昇格・降格結果メッセージ(なければnull)。
  String? lastDivisionChangeMessage;

  /// 直近のstartNextSeasonで昇格プレーオフが行われた場合の各試合結果
  /// (準決勝2試合+決勝の順、表示用に整形済み)。行われなかった場合は空。
  List<String> lastPromotionPlayoffResults = [];

  /// 直近のプレーオフにユーザークラブが出場していたかどうか。
  bool userInvolvedInLastPromotionPlayoff = false;
}
