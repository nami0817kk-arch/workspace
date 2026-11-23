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
import 'dart:io' as io show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/bank_loan.dart';
import '../models/investment.dart';
import '../models/ledger.dart';
import '../logic/division_strength.dart';
import '../logic/ledger_engine.dart';
import '../logic/economy_engine.dart';
import '../logic/advisor_engine.dart';
import '../logic/club_ranking_engine.dart';
import '../logic/equity_engine.dart';
import '../logic/media_deals_engine.dart';
import '../logic/fan_demand_engine.dart';
import '../logic/relegation_clause.dart';
import '../logic/running_cost_engine.dart';
import '../logic/project_engine.dart';
import '../models/start_scenario.dart';
import '../logic/proposal_engine.dart';
import '../logic/risk_engine.dart';
import '../logic/league_rules.dart';
import '../logic/policy_engine.dart';
import '../logic/club_value_engine.dart';
import '../models/best_eleven.dart';
import '../models/club_infrastructure.dart';
import '../models/continental_cup.dart';
import '../models/contract_negotiation.dart';
import '../models/card_rules.dart';
import '../models/cup.dart';
import '../models/formation.dart';
import '../models/incoming_offer.dart';
import '../models/installment.dart';
import '../models/transfer_talk.dart';
import '../models/sd_brief.dart';
import '../models/staff_offer.dart';
import '../models/rival_owner.dart';
import '../models/manager_profile.dart';
import '../logic/manager_hr_engine.dart';
import '../logic/manager_tactics.dart';
import '../logic/transfer_talk_engine.dart';
import '../logic/transfer_value.dart';
import '../logic/player_terms_engine.dart';
import '../logic/relations_engine.dart';
import '../logic/injury_care.dart';
import '../logic/front_page_engine.dart';
import '../logic/club_culture.dart';
import '../logic/academy_engine.dart';
import '../logic/agm_engine.dart';
import '../logic/appearance_fee_engine.dart';
import '../logic/projection_engine.dart';
import '../logic/owner_history_engine.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/press_question.dart';
import '../models/news_item.dart';
import '../models/youth_league.dart';
import '../models/save_game.dart';
import '../models/season_award.dart';
import '../models/season_record.dart';
import '../models/sponsor.dart';
import '../models/tactic_preset.dart';
import '../models/team_talk.dart';
import '../models/training_result.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/live_match_progress.dart';
import '../models/match_result.dart';
import '../models/weather.dart';
import '../logic/achievement_engine.dart';
import '../logic/ai_transfer_engine.dart';
import '../logic/money_calendar.dart';
import '../logic/season_calendar.dart';
import '../logic/day_events.dart';
import '../logic/summer_tournament.dart';
import '../logic/transfer_window.dart';
import '../logic/awards_engine.dart';
import '../logic/background_match_engine.dart';
import '../logic/best_eleven_engine.dart';
import '../logic/board_engine.dart';
import '../logic/budget_engine.dart';
import '../models/budget_plan.dart';
import '../models/owner_event.dart';
import '../models/owner_work.dart';
import '../logic/transfer_terms_engine.dart';
import '../logic/partner_club_engine.dart';
import '../logic/youth_investment_engine.dart';
import '../logic/facility_investment_engine.dart';
import '../logic/club_health_engine.dart';
import '../models/matchday_promo.dart';
import '../models/owner_goal.dart';
import '../models/owner_legacy.dart';
import '../logic/offscreen_development.dart';
import '../logic/shareholder_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/continental_cup_engine.dart';
import '../logic/dynamics_engine.dart';
import '../logic/tactics_ai.dart';
import '../logic/cup_engine.dart';
import '../logic/happiness_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../logic/manager_career_engine.dart';
import '../logic/player_generator.dart';
import '../logic/promotion_engine.dart';
import '../logic/retirement_engine.dart';
import '../logic/pre_contract_engine.dart';
import '../models/pre_contract.dart';
import '../logic/rotation_engine.dart';
import '../logic/fixture_generator.dart';
import '../logic/free_agent_engine.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/scout_knowledge.dart';
import '../logic/scouting_engine.dart';
import '../logic/season_projection_engine.dart';
import '../logic/sponsor_engine.dart';
import '../logic/era_engine.dart';
import '../logic/analytics_engine.dart';
import '../models/player_stub.dart';
import '../logic/fan_segments.dart';
import '../logic/contract_style.dart';
import '../logic/country_coefficient.dart';
import '../logic/big_moment.dart';
import '../models/club_look.dart';
import '../theme/club_palette.dart';
import '../logic/sponsor_slots.dart';
import '../logic/club_license.dart';
import '../logic/market_trend.dart';
import '../logic/player_popularity.dart';
import '../logic/season_tickets.dart';
import '../logic/super_cup_engine.dart';
import '../logic/training_engine.dart';
import '../logic/weather_engine.dart';
import '../logic/youth_departure_engine.dart';
import '../logic/youth_league_engine.dart';
import '../logic/youth_promotion_engine.dart';
import '../logic/youth_match_engine.dart';
import '../data/name_pool.dart';
import '../data/nation_names.dart';
import '../models/first_run_step.dart';
import '../monetization/funds_pack.dart';
import '../l10n/tr.dart';
import '../logic/match_factor_engine.dart';
import '../logic/reserve_match_engine.dart';
import '../logic/staff_market.dart';
import '../models/corner_routine.dart';
import '../models/club_vision.dart';
import '../models/preseason_camp.dart';
import '../models/opposition_plan.dart';
import '../models/player_instruction.dart';
import '../models/staff_member.dart';
import '../logic/economy_scale.dart';

part 'game_state_squad.dart';
part 'game_state_transfer.dart';
part 'game_state_finance.dart';
part 'game_state_match.dart';
part 'game_state_season.dart';
part 'game_state_contracts.dart';
part 'game_state_talks.dart';
part 'game_state_people.dart';
part 'game_state_sd.dart';
part 'game_state_staff_moves.dart';
part 'game_state_life.dart';
part 'game_state_owner.dart';
part 'game_state_agm.dart';
part 'game_state_plan.dart';
part 'game_state_rivals.dart';
part 'game_state_money_rules.dart';
part 'game_state_injury.dart';
part 'game_state_nation.dart';
part 'game_state_forms.dart';
part 'game_state_league_cup.dart';
part 'game_state_era_group.dart';
part 'game_state_congestion.dart';
part 'game_state_week.dart';
part 'game_state_youth_analytics.dart';
part 'game_state_fans.dart';
part 'game_state_contract_style.dart';
part 'game_state_coefficient.dart';
part 'game_state_moments.dart';
part 'game_state_club_look.dart';
part 'game_state_rumors.dart';
part 'game_state_affiliate.dart';
part 'game_state_foreign.dart';
part 'game_state_records.dart';
part 'game_state_former_clubs.dart';
part 'game_state_club_finance.dart';
part 'game_state_sponsor_slots.dart';
part 'game_state_license.dart';
part 'game_state_season_tickets.dart';
part 'game_state_calendar.dart';
part 'game_state_club_names.dart';
part 'game_state_cups.dart';
part 'game_state_cup_days.dart';
part 'game_state_decisions.dart';

/// 終えたシーズンの締めくくり。シーズン開始レポートに出す絵を決める。
enum SeasonFinale { none, promoted, champion }

/// 在籍の総数の上限(21歳以下を含む)。登録の決まりは [SquadRegistration]。
const int maxSquadSize = SquadRegistration.totalLimit;

/// スカッドの最低人数。放出・ローン放出はこの人数を割り込む操作を拒否し、
/// 契約満了・ローン満了でこれを下回った場合はフリーエージェントで自動補充
/// される。12だと負傷・出場停止が重なった際に11人を組めなくなる危険が
/// あるため(長期実測で12人に張り付く状態を確認)、ベンチ要員を含めて
/// 最低限回る16人とする。
const int minSquadSize = 18;

/// シーズン開始時に自動補強で確保する推奨人数。最低人数ちょうど(16人)で
/// 張り付くと、負傷者と出場停止が数人重なるだけでベンチが空になり、
/// ローテーションの選択肢そのものが消えてしまう(長期実測で毎シーズン
/// 16人に張り付くことを確認)。シーズン開始時だけこの人数まで底上げする。
const int seasonStartSquadSize = 21;

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

/// 手動で取った控え(復元ポイント)の中身の説明。
///
/// 「戻せます」とだけ書かれていても、どこへ戻るのか分からなければ押せない。
/// いつ・どのシーズンの・何節時点かを添えて、戻す前に判断できるようにする。
class RestorePointInfo {
  final DateTime takenAt;
  final String clubName;
  final int season;

  /// 控えを取った時点で次に控えていた節。シーズンを終えていれば null。
  final int? matchday;

  RestorePointInfo({
    required this.takenAt,
    required this.clubName,
    required this.season,
    this.matchday,
  });
}

/// [GameState.encodeSaveOffMain] が別の処理で呼ぶ(トップレベルでないと渡せない)。
String _encodeSave(SaveGame save) => jsonEncode(save.toJson());

class GameState extends ChangeNotifier {
  /// 旧バージョンで使われていた単一スロットのキー。起動時にスロット0へ移行する。
  static const _legacyPrefsKey = 'soccer_manager_save_v1';
  static const _slotKeyPrefix = 'soccer_manager_save_slot_';
  static const _currentSlotKey = 'soccer_manager_current_slot';

  /// 対応するセーブスロット数。
  static const int maxSaveSlots = 3;

  static String _slotKey(int slot) => '$_slotKeyPrefix$slot';
  static String _restorePointKey(int slot) => '$_restorePointKeyPrefix$slot';

  /// 直近に読み込めたセーブの控え。スロットごとに持つと容量を倍使うため、
  /// 控えは1つだけ持ち、どのスロットのものかを別に覚えておく。
  /// 手動で取る控えの保存先。スロットごとに1つ持つ。
  ///
  /// 自動の控え([_backupKey])と分けているのは、あちらが「壊れたときに
  /// 戻す」ためのもので、スロットを跨いで上書きされるため。手で取った
  /// 控えが別スロットを開いただけで消えると、取った意味が無くなる。
  static const _restorePointKeyPrefix = 'soccer_manager_restore_point_';
  static const _backupKey = 'soccer_manager_save_backup';
  static const _backupSlotKey = 'soccer_manager_save_backup_slot';

  int currentSlot = 0;

  SaveGame? _save;
  bool initialized = false;

  /// シーズン開幕・シーズン終了処理など、重い同期計算を行っている間true。
  /// UI側でローディング表示を出すために使う。
  bool isBusy = false;

  /// 壊れたセーブの代わりに控えから復元したときの知らせ。復元が起きた
  /// ときだけ入る。黙って古い状態に戻すと、進めたはずの数節が消えたように
  /// 見えるため、必ず伝える。
  String? lastBackupRestoreNotice;

  /// 直近の保存(_persist)が失敗した場合のエラーメッセージ。保存に成功すると
  /// nullに戻る。ブラウザのストレージ容量超過など、プレイ自体は継続できるが
  /// 進行状況が保存されていない可能性がある場合にUI側で警告を出すために使う。
  String? lastSaveError;

  /// セーブ未ロード時のフォールバック用の移籍市場(通常はセーブ内の
  /// [SaveGame.transferMarketPlayers]が実体)。
  List<Player> _transferMarketFallback = [];

  /// 作り物の移籍市場の選手。**ゲームはもう作らない**(獲得の相手は
  /// [transferTargets]の他のクラブの選手)。テストが選手を置くためと、
  /// 獲得の関数が先に見る場所として残してある。
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

  /// IDから選手を探す。自軍だけでなく、ユースの有望株・スカウト候補・
  /// 移籍市場・フリーエージェントまで見る。
  ///
  /// 比較や詳細の画面が自軍しか見ていないと、市場の選手を開いた瞬間に
  /// 落ちる(firstWhere が要素なしで投げる)。見つからないときは null を
  /// 返し、画面側で「もう居ない」と伝えられるようにする。
  Player? playerById(String id) {
    final save = _save;
    if (save == null) return null;
    for (final pool in [
      userTeam.players,
      save.youthProspects,
      save.pendingYouthIntake,
      scoutCandidates,
      transferMarket,
      freeAgents,
    ]) {
      for (final p in pool) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  /// 直近のstartNextSeasonで契約(年単位)満了により退団した選手名
  /// （1回表示したら呼び出し側でクリアする想定）。
  List<String> lastContractExpirations = [];

  /// 借りていた選手のうち、ローン期間満了で貸し元へ戻った選手名
  /// （1回表示したら呼び出し側でクリアする想定）。以前は
  /// [lastContractExpirations]に混ぜていたため、季の切り替えで
  /// 「契約満了で退団」と出ていた(2026-11-23)。
  List<String> lastLoanEndings = [];

  /// 直近のstartNextSeasonで契約の最終年に入った(事前警告)選手名
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<String> lastContractWarnings = [];

  /// 直近のstartNextSeasonで「契約を延長しない」と言い出した選手名。
  List<String> lastRenewalRefusals = [];

  /// 直近のstartNextSeasonで仮契約(ボスマン)により加入した選手名。
  List<String> lastPreContractArrivals = [];

  /// 契約切れでスカッドが最低人数を割り込んだ際、自動的に緊急補強された
  /// フリーエージェントの選手名(1回表示したら呼び出し側でクリアする想定)。
  List<String> lastEmergencySignings = [];

  /// 今週すでにトレーニングを実施済みかどうか(節が進むとリセットされる)。
  bool get trainingDoneThisWeek => _save?.trainingDoneThisWeek ?? false;

  /// 直近のrunWeeklyTrainingで実際に変化(成長・衰え)があった選手の一覧
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<PlayerGrowthSummary> lastTrainingResults = [];

  /// 直近の節送りで行われたユース練習試合の結果(候補が0人ならnull)。
  /// ユース画面での直近戦の表示に使う(セーブデータには保存しない)。
  YouthMatchReport? lastYouthMatchReport;

  /// 直近の節送りでユースを去った有望株(セーブには残さない)。
  /// 画面で1度知らせたら消える、その週だけの出来事として扱う。
  List<YouthDeparture> lastYouthDepartures = [];

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

  /// サポーターの期待(信頼度)が0まで落ち、クラブを手放すことになった
  /// 状態かどうか(旧名のまま。オーナーが解任されるわけではない)。
  bool get isDismissed => _save != null && _save!.confidence <= 0;

  /// 株主の期待が0まで落ちた状態かどうか。クラブを手放す理由にはならない
  /// (手放すのは資金とサポーターの期待が尽きたときだけ。saleReason)。
  bool get isShareholderRevolt =>
      _save != null && _save!.shareholderExpectation <= 0;

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

  /// いま開いている移籍の窓。閉じていれば null。
  ///
  /// 窓は日付で開け閉めする(国ごとに実在の日付。[TransferWindowCalendar])。
  TransferWindowPeriod? get currentTransferWindow => _save == null
      ? null
      : TransferWindowCalendar.openOn(today, currentLeagueTheme);

  /// 移籍の窓が開いているか。開いている間だけ、移籍金のかかる獲得・
  /// ローン・売却・貸し出しができる(自由契約の選手はいつでも取れる)。
  bool get isTransferWindowOpen =>
      _save == null || currentTransferWindow != null;

  /// 締切まで残り何日か(締切日の当日は0)。閉じていれば null。
  int? get transferWindowDaysLeft {
    final w = currentTransferWindow;
    if (w == null) return null;
    return TransferWindowCalendar.daysBetween(today, w.closes);
  }

  /// 次に開く窓。開いている間は null。
  TransferWindowPeriod? get nextTransferWindow {
    if (_save == null || isTransferWindowOpen) return null;
    return TransferWindowCalendar.nextAfter(today, currentLeagueTheme);
  }

  /// 今日より後で最初のリーグ戦の日(残っていなければ null)。
  DateTime? get _nextLeagueDateAfterToday {
    if (_save == null || _save!.league.fixtures.isEmpty) return null;
    final t = today;
    for (final d in seasonCalendar.matchdayDates) {
      if (d.isAfter(t)) return d;
    }
    return null;
  }

  /// 締切日か。今日が締切日のとき、または次のリーグ戦の日には窓が
  /// 閉じているとき(この節のあいだが最後の機会)。
  ///
  /// 日付は試合をするたびに進むので、締切日ちょうどに止まるとは限らない。
  /// 「次の試合の前に閉まる」も締切日として目立たせる。
  bool get isTransferDeadlineDay {
    final w = currentTransferWindow;
    if (w == null) return false;
    if (TransferWindowCalendar.daysBetween(today, w.closes) <= 0) return true;
    final next = _nextLeagueDateAfterToday;
    return next != null && next.isAfter(w.closes);
  }

  /// 締切日(閉じていれば null)。
  DateTime? get transferDeadline => currentTransferWindow?.closes;

  /// UI表示用の移籍の窓の状態の文言。
  String get transferWindowStatusLabel {
    final w = currentTransferWindow;
    if (_save == null) {
      return Tr.pick('移籍の窓: 開いています', 'Transfer window: open');
    }
    if (w != null) {
      final left = TransferWindowCalendar.daysBetween(today, w.closes);
      final deadline = TransferWindowCalendar.formatMonthDay(w.closes);
      if (left <= 0) {
        return Tr.pick(
          '${w.kind.label}: 今日が締切です($deadline)',
          'Transfer window: deadline day today ($deadline)',
        );
      }
      if (isTransferDeadlineDay) {
        return Tr.pick(
          '${w.kind.label}: 締切まで残り$left日($deadline)。次の試合の前に閉まります',
          'Transfer window: ${Tr.plural(left, 'day')} to the deadline ($deadline). It shuts before the next match',
        );
      }
      return Tr.pick(
        '${w.kind.label}: 締切まで残り$left日($deadline)',
        'Transfer window: ${Tr.plural(left, 'day')} to the deadline ($deadline)',
      );
    }
    final next = TransferWindowCalendar.nextAfter(today, currentLeagueTheme);
    final opens = TransferWindowCalendar.formatMonthDay(next.opens);
    return Tr.pick(
      '移籍の窓: 閉じています。次の窓は$opensから',
      'Transfer window: shut. The next one opens on $opens',
    );
  }

  /// 登録中の GK が全員出られない(怪我・出場停止・代表・貸し出し中・
  /// 名簿の外)か。窓の外でも GK を1人だけ取れる特例の条件。
  bool get isGoalkeeperEmergency {
    if (_save == null || isTransferWindowOpen) return false;
    return !userTeam.players.any(
      (p) =>
          p.position == Position.gk &&
          !p.isInjured &&
          !p.isSuspended &&
          !p.isOnInternationalDuty &&
          !p.isLoanedOut &&
          !p.notRegistered,
    );
  }

  /// [player]を今とれるか(窓の開閉と GK の特例)。
  bool _windowAllowsSigning(Player player, {bool permanent = true}) {
    if (isTransferWindowOpen) return true;
    // GK の緊急獲得は期限付き(ローン)だけ。完全移籍は次の窓まで待つ。
    if (permanent) return false;
    return player.position == Position.gk && isGoalkeeperEmergency;
  }

  /// 18歳未満で、他の国から来る選手か(国をまたいで移れない)。
  /// EU の中の16〜17歳は例外で移れる([minorMayMoveBetween])。
  bool _isInternationalMinor(Player player) {
    if (player.age >= 18) return false;
    final origin = player.originLeague;
    if (origin == null) return false;
    if (origin == currentLeagueTheme.name) return false;
    final from = LeagueTheme.values.where((t) => t.name == origin).firstOrNull;
    if (from == null) return true;
    return !minorMayMoveBetween(player.age, from, currentLeagueTheme);
  }

  /// 他の国のクラブ[clubId]にいる[p]が、18歳未満の国際移籍の禁止に当たるか
  /// (自国のクラブなら当たらない)。
  bool _minorBlockedFromClub(Player p, String clubId) {
    if (p.age >= 18) return false;
    final name = _foreignTeamIds()[clubId];
    if (name == null) return false;
    final from = LeagueTheme.values.where((t) => t.name == name).firstOrNull;
    if (from == null) return true;
    return !minorMayMoveBetween(p.age, from, currentLeagueTheme);
  }

  /// [clubName]が他の国のクラブか。
  bool _isForeignClub(String clubName) {
    if (_save == null) return false;
    for (final l in _save!.foreignLeagues.values) {
      if (l.teams.any((t) => t.name == clubName)) return true;
    }
    return false;
  }

  /// 保存文字列からセーブを復元する。壊れていれば null。
  SaveGame? _decodeSave(String raw) {
    try {
      return SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// スロットを読み込む。本体が壊れていれば控えから戻す。
  ///
  /// セーブが1つしか無いと、書き込みの途中で中断されたときに積み上げた
  /// 数十シーズンがまとめて消える。読み込めた時点の内容を控えに残しておき、
  /// 壊れていたらそちらを使う。
  Future<SaveGame?> _loadSlotData(SharedPreferences prefs, int slot) async {
    final raw = prefs.getString(_slotKey(slot));
    if (raw == null) return null;
    final loaded = _decodeSave(raw);
    if (loaded != null) {
      // 読めたものが正。次に壊れたときのために控えを更新する。
      await prefs.setString(_backupKey, raw);
      await prefs.setInt(_backupSlotKey, slot);
      return loaded;
    }

    final backup = prefs.getString(_backupKey);
    final backupSlot = prefs.getInt(_backupSlotKey);
    if (backup == null || backupSlot != slot) return null;
    final restored = _decodeSave(backup);
    if (restored == null) return null;

    lastBackupRestoreNotice = Tr.pick(
      'セーブデータが壊れていたため、直前の控えから復元しました。進行が少し戻っている場合があります。',
      'Your save was damaged, so the last good copy was restored. You may be a little behind where you left off.',
    );
    return restored;
  }

  /// いまのセーブを控えとして書き出す。シーズンの切り替わりで呼ぶ。
  ///
  /// 控えを読み込み時にしか取らないと、1回の起動で何十シーズン進めた場合に
  /// 戻る先が起動時点になる。区切りで取り直して、失う量を1シーズン以内に抑える。
  Future<void> refreshSaveBackup() async {
    if (_save == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupKey, jsonEncode(_save!.toJson()));
      await prefs.setInt(_backupSlotKey, currentSlot);
    } catch (_) {
      // 控えが取れなくても進行は止めない(本体の保存が正)。
    }
  }

  /// いまの状態を、あとで戻れる控えとして取っておく(スロットごとに1つ)。
  ///
  /// クリップボードへの書き出しは端末を移すためのもので、1MBを超える
  /// JSONをどこかに貼って保管しておく必要がある。移籍や試合の前に
  /// 「念のため」取るには重すぎるので、端末の中に1つだけ置けるようにする。
  Future<bool> saveRestorePoint() async {
    if (_save == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _restorePointKey(currentSlot),
        jsonEncode({
          'takenAt': DateTime.now().toIso8601String(),
          'clubName': _save!.clubName,
          'season': _save!.league.season,
          'matchday': _save!.league.nextUnplayedFixture?.matchday,
          'save': _save!.toJson(),
        }),
      );
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// いまのスロットに控えがあれば、その中身の説明を返す。
  Future<RestorePointInfo?> restorePointInfo([int? slot]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_restorePointKey(slot ?? currentSlot));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RestorePointInfo(
        takenAt: DateTime.parse(json['takenAt'] as String),
        clubName: json['clubName'] as String? ?? '',
        season: json['season'] as int? ?? 1,
        matchday: json['matchday'] as int?,
      );
    } catch (_) {
      // 読めない控えは無いものとして扱う(戻せないものを見せない)。
      return null;
    }
  }

  /// 控えの時点まで戻す。戻せたら true。
  Future<bool> restoreFromRestorePoint() async {
    // ここから先は控えが正。予約されている保存(戻す前の状態)を取り消す。
    // 残したままだと、戻した直後に戻す前の内容が上書きしにくる。
    _saveGeneration++;
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_restorePointKey(currentSlot));
      if (raw == null) return false;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final restored = SaveGame.fromJson(json['save'] as Map<String, dynamic>);
      _save = restored;
      _repairLoadedSave(restored);
      _migrateDivisionPyramidIfNeeded();
      _refreshScoutCandidates();
      // 戻す前の節の出来事を持ち越すと、戻した後にそれを知らせてしまう。
      lastContractExpirations = [];
      lastLoanEndings = [];
      lastRetirements = [];
      lastLoanReturns = [];
      lastYouthDepartures = [];
      await _persistNow();
      _notify();
      return true;
    } catch (_) {
      return false;
    }
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
    _save = await _loadSlotData(prefs, currentSlot);
    if (_save != null) {
      _repairLoadedSave(_save!);
      _migrateDivisionPyramidIfNeeded();
      // 作り物の移籍市場はやめた(獲得の相手は他のクラブの選手)。旧セーブに
      // 残っている市場の選手は捨てる。
      transferMarket = [];
      _refreshScoutCandidates();
    }
    initialized = true;
    _notify();
  }

  /// 読み込んだセーブを、遊べる状態に整える(読み込み口すべてから呼ぶ)。
  ///
  /// - 選手IDのカウンターを全選手より上へ引き上げ、既に重複したIDを振り直す。
  /// - 相手クラブが今のリーグに居ない監督オファーを消す(残っているとホーム
  ///   画面が開くたびに落ち、セーブが詰む)。
  void _repairLoadedSave(SaveGame save) {
    _syncContractClock(save);
    _reseedPlayerIdCounter(save);
    // 足りないクラブの選手を作る(_ensureWorldSquads)より前に行う。新しく
    // 作る選手は初めから今の水準なので、掛けてはいけない。
    _migrateWageLevelIfNeeded(save);
    _ensureWorldSquads(save);
    save.renumberDuplicatePlayerIds(PlayerGenerator.nextPlayerId);
    _dropDanglingJobOffer(save);
    _migrateEconomyIfNeeded(save);
    _migrateClubValueIfNeeded(save);
    // ファンの需要を持たない旧セーブは、部と規模から作る。
    _ensureFanDemand(save);
    // 今日の日付を持たない旧セーブは、ここで日付を作る。
    save.today ??= _rebuiltToday();
    _migrateLoanDates(save);
    _dropInternationalMinorsFromMarket(save);
  }

  /// お金の桁を部ごとに変える前(版1)のセーブを、一度だけ新しい桁に直す。
  ///
  /// - 全選手(自クラブ・他クラブ・他国・移籍市場・フリーエージェント・
  ///   ユース)の週俸を、新しい価値の曲線から作り直す。違約金条項と
  ///   買い取りオプションは、価値が何倍になったかに合わせて直す。
  /// - 資金・災害基金・スポンサーと命名権の契約の額・融資の残り・分割払い
  ///   の残り・預金を、今の部の収入の倍率(incomeScale)倍にする。
  /// - 古い桁で始まった交渉と移籍の申し出は、額が合わないので取り下げる。
  void _migrateEconomyIfNeeded(SaveGame save) {
    if (save.economyVersion >= SaveGame.currentEconomyVersion) return;
    final scale = incomeScale(save.currentDivisionTier);
    int up(int v) => (v * scale).round();
    // 週俸は、選手のいるクラブの国・部の水準で作り直す(新しいゲームと同じ)。
    final home = _homeWageLevelOf(save);
    final teamLevels = _wageLevelsByTeamId(save);
    final playerLevels = <String, double>{
      for (final t in [
        ...save.allTeams,
        for (final l in save.foreignLeagues.values) ...l.teams,
      ])
        for (final p in t.players) p.id: teamLevels[t.id] ?? home,
    };

    for (final p in save.allPlayers) {
      final ratio = p.marketValue / max(1, GameState.legacyMarketValue(p));
      p.wage = p.fairWeeklyWage(playerLevels[p.id] ?? home);
      if (p.releaseClause != null) {
        p.releaseClause = (p.releaseClause! * ratio).round();
      }
      if (p.loanBuyOptionFee != null) {
        p.loanBuyOptionFee = (p.loanBuyOptionFee! * ratio).round();
      }
    }

    save.budget = up(save.budget);
    save.reserveFund = up(save.reserveFund);
    for (final deal in [
      if (save.sponsorDeal != null) save.sponsorDeal!,
      if (save.namingDeal != null) save.namingDeal!,
      ...save.pendingSponsorOffers,
      ...save.pendingNamingOffers,
    ]) {
      deal.weeklyIncome = up(deal.weeklyIncome);
    }
    save.bankLoans = [
      for (final l in save.bankLoans)
        BankLoan(
          id: l.id,
          principal: up(l.principal),
          weeklyRepayment: up(l.weeklyRepayment),
          termWeeks: l.termWeeks,
          weeksRemaining: l.weeksRemaining,
        ),
    ];
    for (final i in save.pendingInstallments) {
      i.weeklyAmount = up(i.weeklyAmount);
    }
    save.fixedDeposits = [
      for (final d in save.fixedDeposits)
        FixedDeposit(
          id: d.id,
          principal: up(d.principal),
          maturityValue: up(d.maturityValue),
          termWeeks: d.termWeeks,
          weeksRemaining: d.weeksRemaining,
        ),
    ];
    save.incomingOffers = [];
    save.pendingContractNegotiation = null;
    // 給与の枠は新しい桁で引き直す(古い枠のままだと誰も獲れない)。
    final userTeam = _findTeam(save.league.teams, save.userTeamId);
    if (userTeam != null) {
      save.wageBudget = BoardEngine.wageBudgetFor(
        tier: save.currentDivisionTier,
        currentWeeklyWageBill: ContractEngine.weeklyWageBill(userTeam) +
            scaleMoneyForTier(
              save.currentDivisionTier,
              save.infrastructure.totalStaffWeeklyWage,
            ),
        theme: leagueThemeFromName(save.leagueName) ?? LeagueTheme.england,
      );
    }
    save.economyVersion = SaveGame.currentEconomyVersion;
  }

  /// 施設のレベル1を0円にしていた頃(版1)のセーブの、覚えているクラブ
  /// 価値の基準を一度だけ直す(2026-11-23)。
  ///
  /// 施設を建て直す額で数えるようにして、同じクラブの価値が施設のぶん
  /// 上がった。目標「クラブ価値を2倍に」の開始時の価値と、5か年計画の
  /// 目標の価値が古い数え方のままだと、読み込んだだけで目標に近づく。
  /// 今の施設のレベルで、新旧の数え方の差を足す(目標を立てたあとに増築
  /// していれば、そのぶんは正確ではないが、差の大半はレベル1の値)。
  void _migrateClubValueIfNeeded(SaveGame save) {
    if (save.clubValueVersion >= SaveGame.currentClubValueVersion) return;
    final levels = {
      for (final f in FacilityType.values)
        f: save.infrastructure.facilityLevel(f),
    };
    final now = levels.entries.fold<int>(
        0, (s, e) => s + ClubValueEngine.facilityValue(e.key, e.value));
    // 版1の数え方: レベル1つぶん300万 × 今の部の規模、レベル1は0。
    final before = (levels.values.fold<int>(0, (s, l) => s + max(0, l - 1)) *
            300 *
            moneyScale(save.currentDivisionTier))
        .round();
    final delta = max(0, now - before);
    if (save.ownerGoalStartValue > 0) save.ownerGoalStartValue += delta;
    if (save.planTargetValue > 0) save.planTargetValue += delta;
    save.clubValueVersion = SaveGame.currentClubValueVersion;
  }

  /// [save]の自クラブのいる国・部の年俸の水準([wageCountryFactor])。
  static double _homeWageLevelOf(SaveGame save) => wageCountryFactor(
        leagueThemeFromName(save.leagueName) ?? LeagueTheme.england,
        save.currentDivisionTier,
      );

  /// [save]の選手を持つクラブ(自国の全部・他国の1部)の id → 年俸の水準。
  /// 新しいゲームで選手を作るときと同じ係数(自国は今いる部、他国は1部)。
  static Map<String, double> _wageLevelsByTeamId(SaveGame save) {
    final home = leagueThemeFromName(save.leagueName) ?? LeagueTheme.england;
    return {
      for (final e in save.foreignLeagues.entries)
        for (final t in e.value.teams)
          t.id: wageCountryFactor(
            LeagueTheme.values.where((x) => x.name == e.key).firstOrNull ??
                LeagueTheme.england,
            1,
          ),
      for (var i = 0; i < save.otherDivisionLeagues.length; i++)
        for (final t in save.otherDivisionLeagues[i]?.teams ?? const <Team>[])
          t.id: wageCountryFactor(home, i + 1),
      for (final t in save.league.teams)
        t.id: wageCountryFactor(home, save.currentDivisionTier),
    };
  }

  /// 年俸が国・部によらなかった頃(版1)のセーブの週俸を、一度だけ今の
  /// 水準に直す。
  ///
  /// 版1の年俸は、どこもイングランドの1部と同じ水準(係数1)で作られていた。
  /// 新しいゲームは、選手のいるクラブの国・部の係数([wageCountryFactor])を
  /// 掛けて作るので、同じ係数を掛ける。
  /// - クラブの選手(自クラブ・自国の他の部・他国の1部・大陸大会の写し):
  ///   そのクラブの係数。大陸大会の「その他の国」のクラブは、新しいゲーム
  ///   と同じく自クラブの国・部の係数。
  /// - 所属なし・ユース・移籍市場の選手: 自クラブの国・部の係数。
  /// - ローン中の選手の元の週俸(戻るときの額)は、元のクラブの係数。
  /// - 年俸と結びついた値も同じ向きにそろえる: 仮契約の週俸は加入先の
  ///   係数、交渉中の週俸(移籍・契約更新)は自クラブの係数。理事会の給与の
  ///   枠は、余裕(枠 − 人件費)が変わらないように選手の週俸が減った分だけ
  ///   下げる。スペインの「最後に見た人件費」は、下がった分を「売った分」と
  ///   数えないように見ていない(0)に戻す。フランスの人件費の上限は自クラブの
  ///   係数を掛ける。
  /// 係数は1以下なので週俸は下がるだけで、資金は動かさない(財政は悪く
  /// ならない)。
  ///
  /// 版3→4: 国・部の水準を、部が下がるほど同じか低い形に直した
  /// (economy_scale.dart の wageCountryFactor。2026-11-23)。版2→3 と同じ
  /// 形で、クラブの選手と所属なしの選手の週俸を新しい水準で一度だけ作り
  /// 直す(版3より前のセーブは、版3への作り直しが新しい水準で行われるので、
  /// 二度は行わない)。
  void _migrateWageLevelIfNeeded(SaveGame save) {
    if (save.wageLevelVersion >= SaveGame.currentWageLevelVersion) return;
    if (save.wageLevelVersion < 2) _migrateWageLevelToV2(save);
    _migrateWageToAbilityBased(save);
    save.wageLevelVersion = SaveGame.currentWageLevelVersion;
  }

  /// 版2→3: 年俸の決め方を「市場価値から」から「今の能力×年齢の経験」に
  /// 変えた([Player.fairWeeklyWage])。古いままだと、若手は高すぎ、
  /// ベテランは見合う額の7割を下回って一斉に不満を持つ。
  /// クラブの選手と所属なしの選手の週俸を新しい式で作り直す(全体の額は
  /// 旧式とほぼ同じになるよう式の倍率を合わせてある)。理事会の給与の枠は、
  /// 余裕(枠 − 人件費)が変わらないように人件費の増減ぶん動かす。
  void _migrateWageToAbilityBased(SaveGame save) {
    final home = _homeWageLevelOf(save);
    final levels = _wageLevelsByTeamId(save);
    final userTeam = _findTeam(save.league.teams, save.userTeamId);
    final billBefore =
        userTeam == null ? 0 : ContractEngine.weeklyWageBill(userTeam);
    final done = Set<Player>.identity();
    void redo(Player p, double level) {
      if (!done.add(p) || p.wage <= 0) return;
      p.wage = p.fairWeeklyWage(level);
    }

    for (final t in [
      ...save.allTeams,
      for (final l in save.foreignLeagues.values) ...l.teams,
      ...save.continentalTeams,
    ]) {
      final f = levels[t.id] ?? home;
      for (final p in t.players) {
        // ローン中の選手は、元の契約の額(loanBaseWage)との釣り合いを
        // 崩さないよう触らない。
        if (p.isLoanedOut || p.loanBaseWage != null) continue;
        redo(p, f);
      }
    }
    for (final p in save.freeAgents) {
      redo(p, home);
    }
    if (userTeam != null && save.wageBudget > 0) {
      final delta = ContractEngine.weeklyWageBill(userTeam) - billBefore;
      save.wageBudget = max(0, save.wageBudget + delta);
    }
    save.squadCostObserved = 0;
  }

  void _migrateWageLevelToV2(SaveGame save) {
    final home = _homeWageLevelOf(save);
    final levels = _wageLevelsByTeamId(save);
    // 週俸の下限より下には下げない。もとから下限より低い額は上げない。
    int scaled(int w, double f) =>
        w <= 0 ? w : min(w, max(minWeeklyWage, (w * f).round()));
    final done = Set<Player>.identity();
    void scalePlayer(Player p, double f) {
      if (!done.add(p)) return;
      p.wage = scaled(p.wage, f);
      if (p.loanBaseWage != null) {
        p.loanBaseWage = scaled(p.loanBaseWage!, levels[p.loanFromClubId] ?? f);
      }
    }

    final userTeam = _findTeam(save.league.teams, save.userTeamId);
    final billBefore =
        userTeam == null ? 0 : ContractEngine.weeklyWageBill(userTeam);
    for (final t in [
      ...save.allTeams,
      for (final l in save.foreignLeagues.values) ...l.teams,
      ...save.continentalTeams,
    ]) {
      final f = levels[t.id] ?? home;
      for (final p in t.players) {
        scalePlayer(p, f);
      }
    }
    for (final p in [
      ...save.youthProspects,
      ...save.pendingYouthIntake,
      ...save.freeAgents,
      ...save.transferMarketPlayers,
    ]) {
      scalePlayer(p, home);
    }

    save.preContracts = [
      for (final c in save.preContracts)
        PreContract.fromJson({
          ...c.toJson(),
          'wage': scaled(c.wage, levels[c.toClubId] ?? home),
        }),
    ];
    for (final talk in save.transferTalks) {
      talk.demandWage = scaled(talk.demandWage, home);
      talk.rivalWage = scaled(talk.rivalWage, home);
    }
    final n = save.pendingContractNegotiation;
    if (n != null) {
      save.pendingContractNegotiation = ContractNegotiation.fromJson({
        ...n.toJson(),
        'initialWage': scaled(n.initialWage, home),
        'offeredWage': scaled(n.offeredWage, home),
        'counterWage': scaled(n.counterWage, home),
      });
    }

    if (userTeam != null && save.wageBudget > 0) {
      final drop = billBefore - ContractEngine.weeklyWageBill(userTeam);
      save.wageBudget = max(0, save.wageBudget - drop);
    }
    save.squadCostObserved = 0;
    if (save.wageFreezeCap > 0) {
      save.wageFreezeCap = max(1, (save.wageFreezeCap * home).round());
    }
  }

  /// 桁を変える前の市場価値(万円)。旧セーブの換算で、価値が何倍に
  /// なったかを測るためだけに使う。
  @visibleForTesting
  static int legacyMarketValue(Player p) {
    final b = p.marketValueBreakdown;
    final ovr = (p.overall - 40).clamp(0, 60);
    final base = pow(ovr, 1.8) * 3;
    final potentialBonus = (p.potential - p.overall).clamp(0, 40) * 15;
    final value = (base + potentialBonus) *
        b.ageFactor *
        b.personalityFactor *
        b.leadershipFactor;
    return value.round().clamp(50, 20000);
  }

  /// セーブデータ内の全選手IDを集め、[PlayerGenerator]のIDカウンターへ反映する。
  ///
  /// **選手を持つ場所は [SaveGame.allPlayers] で漏れなく数える。** 移籍市場を
  /// 数えていなかったため、再起動後に作った選手が市場の選手と同じIDになっていた。
  /// スカウト候補はセーブに入らないが、メモリ上に残っていれば一緒に数える。
  void _reseedPlayerIdCounter(SaveGame save) {
    PlayerGenerator.ensureIdCounterAbove([
      for (final p in save.allPlayers) p.id,
      for (final p in scoutCandidates) p.id,
    ]);
  }

  /// 相手クラブが今のリーグに居ない監督オファーを消す。
  ///
  /// 以前のバージョンで、保留中に相手が別のリーグへ移ったセーブは、ホーム
  /// 画面が開くたびに落ちて先へ進めなくなっていた。読み込みで直す。
  void _dropDanglingJobOffer(SaveGame save) {
    final teamId = save.pendingJobOfferTeamId;
    if (teamId == null) return;
    if (_findTeam(save.league.teams, teamId) == null) {
      save.pendingJobOfferTeamId = null;
    }
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
        final names = NamePool.clubNamesForTier(
          currentLeagueTheme,
          tier,
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
    // 順位の決め方を国ごとにし、イングランド以外のリーグカップを捨てる。
    _migrateCupsAndRules();
  }

  /// 状態変更を購読側へ通知する。
  /// ChangeNotifier.notifyListeners は @protected かつ @visibleForTesting
  /// のため、クラス外(part ファイルの extension)から直接呼ぶと解析警告になる。
  /// 通知はすべてこの委譲を経由させる。
  void _notify() {
    // スペイン式の「売った分の一部だけ使える額」を、人件費の動きで更新する。
    _observeSquadCost();
    // エンブレムとユニフォームの色の出どころを、今のクラブの見た目に合わせる。
    ClubLookRegistry.teamId = _save?.userTeamId;
    ClubLookRegistry.look = _save?.clubLook;
    notifyListeners();
  }

  /// セーブデータをローカルストレージへ書き込む。ブラウザのストレージ容量
  /// 超過など、書き込み自体が失敗する場合がある(特にディビジョン数が増えて
  /// セーブデータが肥大化した場合)。ここで例外を握りつぶさずに外へ伝播させると、
  /// 呼び出し元(新規クラブ作成など)の非同期処理全体が失敗し、ローディング
  /// 表示のまま進行できなくなる(UI側でエラーを拾えないため)。プレイ自体は
  /// メモリ上のセーブデータで継続できるため、保存失敗はここで捕捉して
  /// [lastSaveError] に記録するに留める。
  /// 保存をまとめるためのタイマー。
  Timer? _persistTimer;

  /// 見せる前の大事な場面([SaveGame.pendingMoments])を溜めておく上限。
  static const int maxPendingMoments = 20;

  /// 何節もまとめて進めている間([_inBulkSave])は、節ごとの保存
  /// ([_persistNow])を書かずに印だけ付け、終わったときに1回だけ書く。
  /// セーブは約3MBあり、節ごとに丸ごと書き出すと1節の処理時間の大半を
  /// 占めていた(2026-11-23)。1節ずつ進めるときは今までどおり毎回書く
  /// (途中でアプリが落ちても進めた分を失わない)。
  int _bulkSaveDepth = 0;
  bool _bulkSavePending = false;
  int _saveWriteCount = 0;

  /// テスト用: セーブを書き出した回数。
  @visibleForTesting
  int get debugSaveWriteCount => _saveWriteCount;

  /// [body]の間の保存を1回にまとめる。入れ子にしてよい(外側の終わりで書く)。
  /// [body]が途中で投げても、それまでの分は書く。
  Future<T> _inBulkSave<T>(Future<T> Function() body) async {
    _bulkSaveDepth++;
    try {
      return await body();
    } finally {
      _bulkSaveDepth--;
      if (_bulkSaveDepth == 0 && _bulkSavePending) {
        _bulkSavePending = false;
        await _persistNow();
      }
    }
  }

  /// セーブを JSON にする重い処理を、画面を描く処理とは別のところで行う。
  ///
  /// セーブは約1.5MB あり、JSON にするのに PC でも約160ms かかっていた
  /// (60fps の10コマ分)。節を進めるたびに画面が一瞬止まる元になる。
  /// 別の処理へは中身を写して渡すので、写した後に元が変わっても混ざらない。
  /// 写せないものが混じっていた場合と Web では、これまでどおりここで行う。
  static bool get _underTest {
    // flutter test は FLUTTER_TEST を立てる(画面を使わないテストでも分かる)。
    if (!kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Future<String> encodeSaveOffMain(SaveGame save) async {
    // Web と、テスト(時間を止めて動かす画面のテストでは別の処理が終わらず、
    // 待ち続けてしまう)では、これまでどおりここで行う。
    if (kIsWeb || _underTest) return jsonEncode(save.toJson());
    try {
      return await compute(_encodeSave, save);
    } catch (_) {
      return jsonEncode(save.toJson());
    }
  }

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
      if (_bulkSaveDepth > 0 && slot == currentSlot) {
        _bulkSavePending = true; // まとめて進めている間は、終わりに書く
        return;
      }
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
    if (_bulkSaveDepth > 0 && slot == null) {
      // まとめて進めている間は、終わったときに1回だけ書く。
      _bulkSavePending = true;
      return;
    }
    _saveWriteCount++;
    final target = slot ?? currentSlot;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_save == null) {
        await prefs.remove(_slotKey(target));
      } else {
        await prefs.setString(
          _slotKey(target),
          await encodeSaveOffMain(_save!),
        );
      }
      lastSaveError = null;
    } catch (e) {
      lastSaveError = Tr.pick(
        'セーブデータの保存に失敗しました。端末の空き容量を確認してください。',
        'The game could not be saved. Check the free space on your device.',
      );
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
    _save = await _loadSlotData(prefs, slot);
    if (_save != null) {
      _repairLoadedSave(_save!);
      _migrateDivisionPyramidIfNeeded();
      // 作り物の移籍市場はやめた(獲得の相手は他のクラブの選手)。旧セーブに
      // 残っている市場の選手は捨てる。
      transferMarket = [];
      _refreshScoutCandidates();
    } else {
      transferMarket = [];
      scoutCandidates = [];
    }
    lastContractExpirations = [];
    lastLoanEndings = [];
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
    // 控えも一緒に消す。残すと、消したはずのクラブに戻せてしまう。
    await prefs.remove(_restorePointKey(slot));
    // 壊れたとき用の自動の控えも、この枠のものなら消す。残すと、同じ枠に
    // 作った新しいセーブが壊れたとき、消したはずのクラブに戻ってしまう。
    if (prefs.getInt(_backupSlotKey) == slot) {
      await prefs.remove(_backupKey);
      await prefs.remove(_backupSlotKey);
    }
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
    final delta =
        _save?.difficultyOf(DifficultyItem.boardTarget).boardTargetDelta ?? 0;
    return (target + delta).clamp(
      1,
      _save?.league.teams.length ?? teamsPerLeague,
    );
  }

  Future<void> startNewGame(
    String clubName, {
    LeagueTheme theme = LeagueTheme.england,
    GameDifficulty difficulty = GameDifficulty.normal,
    StartScenario scenario = StartScenario.standard,
    Map<DifficultyItem, GameDifficulty>? difficultyItems,
  }) async {
    // ここから先はこのセーブが正。古い予約は無効になる。
    _saveGeneration++;
    isBusy = true;
    _notify();
    // ローディング表示を1フレーム描画させてから、重いクラブ生成処理に入る。
    await Future<void>.delayed(Duration.zero);
    // 契約の満了の年は第1季から数える(前に遊んでいたセーブの年のままに
    // しない)。
    Player.contractClockYear = Player.seasonEndYearOf(1);
    ContractEngine.adultContractYearsCap = ContractEngine.adultCapFor(theme);
    // 選手の名前はリーグの国の名前で作る(他国の選手は後で国籍に合わせる)。
    NamePool.homeTheme = theme;
    // ピラミッドの最下層(3部制なので3部)からスタートする。
    const userStartTier = totalDivisionTiers;
    // 年俸の水準は国・部で違う。自クラブの部の水準を基準にし、他の部の
    // クラブはその部の水準で作る(economy_scale.dart の wageCountryFactor)。
    setHomeWageLevel(theme, userStartTier);
    final userTeam = generateUserStartSquad(
      name: clubName,
      tier: userStartTier,
      theme: theme,
    );
    final rng = Random();
    // クラブ名は実在の今季の顔ぶれに寄せて、部ごとに決まっている
    // (data/club_names.dart。2026-11-22)。自クラブと同じ名前は避ける。
    final namesByTier = {
      for (var t = 1; t <= totalDivisionTiers; t++)
        t: NamePool.clubNamesForTier(
          theme,
          t,
          theme.teamsInTier(t),
          avoid: {clubName},
        ),
    };
    final nameCursor = <int, int>{};
    String nextName(int tier) {
      final i = nameCursor[tier] ?? 0;
      nameCursor[tier] = i + 1;
      return namesByTier[tier]![i];
    }

    // 上位ティアほど強い(1部が最強)。部ごとの幅は division_strength.dart。
    int strengthForTier(int tier) => rollDivisionStrength(tier, rng);

    final cpuCount = theme.teamsInTier(userStartTier) - 1;
    final cpuTeams = <Team>[];
    for (int i = 0; i < cpuCount; i++) {
      cpuTeams.add(
        PlayerGenerator.generateSquad(
          id: 'cpu$i',
          name: nextName(userStartTier),
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
      final tierTeams = withWageLevel(
        wageCountryFactor(theme, tier),
        () => <Team>[
          for (int i = 0; i < theme.teamsInTier(tier); i++)
            PlayerGenerator.generateSquad(
              id: 'div${tier}_$i',
              name: nextName(tier),
              strengthTier: strengthForTier(tier),
            ),
        ],
      );
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
      ruleSet: RuleSet.forTheme(theme),
      boardTargetRank: BoardEngine.estimateTargetRank(league, 'user'),
      // カップは下で組む(1〜3部の全クラブが出るので、セーブが要る)。
      cups: [],
      pendingSponsorOffers: SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: userStartTier,
      ),
      friendlies: _generateFriendlies(teams, 'user'),
      otherDivisionLeagues: otherDivisionLeagues,
      currentDivisionTier: userStartTier,
      clubHistory: [clubName],
      difficulty: difficulty,
      difficultyItems: {
        for (final e in (difficultyItems ?? const {}).entries)
          if (e.value != difficulty) e.key.name: e.value.name,
      },
      scenario: scenario,
    );
    // 国内カップは1〜3部の全クラブ、リーグカップはイングランドだけ。
    _save!.cups = _newSeasonCups();
    // 最初のシーズンは平常。来季の予報だけ引いておく。
    _save!.economyNext = EconomyEngine.next(
      EconomyPhase.normal,
      Random().nextDouble(),
    );
    // 難易度による初期条件の補正(資金と理事会目標の厳しさ)。
    _save!.budget = (initialBudgetFor(userStartTier, theme) *
            _save!.difficultyOf(DifficultyItem.funds).initialBudgetFactor)
        .round();
    _save!.boardTargetRank = _difficultyAdjustedTarget(_save!.boardTargetRank);
    _save!.wageBudget = BoardEngine.wageBudgetFor(
      tier: userStartTier,
      currentWeeklyWageBill: weeklyWageBill,
      theme: theme,
    );
    _save!.boardCupTargetRound = _estimateDomesticCupTarget();
    _applyScenario(scenario);
    // スタジアムに来たいファンの数(部と評判から)。
    _ensureFanDemand(_save!);
    final rival = cpuTeams[rng.nextInt(cpuTeams.length)];
    _save!.rivalTeamId = rival.id;
    _save!.rivalTeamName = rival.name;
    transferMarket = [];
    _refreshScoutCandidates();
    // 新規開始時もキャンプの判断から始まる。
    _save!.preseasonCampPending = true;
    _save!.today = SeasonCalendar.preseasonDate(league.season);
    // 袖・背中・練習着のスポンサーの最初の提示。
    _offerEmptySlotSponsors();
    // 開始時は全役職が空席。誰を先に雇うかが最初の判断になる。
    _refreshStaffCandidates();
    _assignRivalOwners();
    FreeAgentEngine.topUp(_save!.freeAgents);
    // 自クラブの選手にも、CPU と同じ国・部の割合で外国籍を混ぜる
    // (名前を国籍に合わせる前に)。
    _assignUserNationalitiesAtStart(userStartTier);
    _ensureWorldSquads(_save!);
    _applyTieBreakRules();
    // 第1季から大陸大会がある(自国の1部の強い順と、他国の1部の強い順)。
    _rememberForeignTop();
    _setUpContinentalCups(
      tier1Order: [...?_teamsByTierNow()[1]]
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating)),
    );
    // 第1季の前の夏(2026年)はワールドカップ。出た選手は遅れて合流する。
    _startSummerTournament();
    lastContractExpirations = [];
    lastLoanEndings = [];
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
    lastLoanEndings = [];
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
    _repairLoadedSave(restored);
    _migrateDivisionPyramidIfNeeded();
    transferMarket = [];
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

  /// 交渉中の選手を他のクラブが狙い始めるか。乱数で起きるので、交渉の
  /// 流れそのものを確かめるテストでは止める。
  @visibleForTesting
  bool rivalsEnabled = true;

  /// クラブニュース履歴の保持上限。超えた分は古いものから捨てる
  /// (セーブデータの肥大化を防ぎつつ、2〜3シーズン分は見返せる量)。
  static const int newsLogLimit = 120;

  /// 戦術ミーティングの再実施までのクールダウン週数。
  static const int tacticalMeetingCooldownWeeks = 3;

  /// ローン(期限付き移籍)で移籍市場の選手を獲得する。頭金は移籍金の2割、
  /// 週俸は6割に軽減される代わりに、決めた日(半年なら冬の窓が開く日、
  /// 1年ならシーズン末)で自動的にチームを離れる。
  static const int loanFeeRatioPercent = 20;

  /// 買取オプション付きローンの場合の買取金額(移籍金に対する割合)。
  ///
  /// 以前は0.6で、借りてすぐ買い取れば完全移籍より4割安い抜け道だった。
  /// 実際の買取額は相場と同じか少し上(貸す側は先に借り賃も受け取る)なので、
  /// 市場価値の1.05倍にした(2026-11-22)。
  static const double loanBuyOptionRatio = 1.05;

  /// 同時に借りていられる人数と、同時に貸し出していられる人数の上限。
  /// FIFA の決まり(国外へ・国外から各6人まで)を、ゲームでは国内外を
  /// 合わせた人数で数える(2026-11-22)。
  static const int maxLoansIn = 6;
  static const int maxLoansOut = 6;

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

  // この窓で CPU どうしの移籍で動いた選手は SaveGame.aiMovedThisWindow に
  // 保存する(2026-11-23。以前は保存せず、読み込み直すと同じ窓で二度動いた)。

  /// 直近のplaySecondHalfでユーザーが月間最優秀監督賞を受賞した場合の対象節ラベル。ない場合はnull。
  String? lastMonthlyManagerAward;

  /// 直近のstartNextSeasonでユーザーが年間最優秀監督賞を受賞したかどうか。
  bool lastSeasonManagerAwardWon = false;

  /// 年間最優秀監督賞を受けた監督の名前(受賞の時点の監督。季の替わり目に
  /// 監督が入れ替わっても、受けた人の名前で知らせるため)。
  String? lastSeasonManagerAwardName;

  /// 直近のplayNextMatchdayでスタメン出場手当として支払った総額(万円)。
  int lastAppearanceFeesPaid = 0;

  /// 資金マイナスの長期化により理事会の信頼度が下がった場合の警告文。ない場合はnull。
  String? lastBudgetCrisisWarning;

  static final Random _aiTransferRng = Random();

  /// ダービー戦は観客動員(収入)・監督への信頼度への影響がともに増幅される。
  static const double derbyAttendanceMultiplier = 1.5;

  /// ダービーの収入。**入れる人数以上からは入場料を取れない。**
  ///
  /// 観客数だけを収容人数で頭打ちにして、収入には倍率をそのまま掛けていた。
  /// 画面に「満員」と出ているのに、収入はその1.5倍で計算されていた。
  /// 実際に入った人数の比で掛ける。空席があるダービーでは今まで通り伸び、
  /// 既に満員のクラブでは伸びない(その代わり、スタジアムを大きくする価値が
  /// そのぶん増える)。
  static int derbyAdjustedIncome(
    int income, {
    required int baseAttendance,
    required int actualAttendance,
  }) {
    if (baseAttendance <= 0) return income;
    return (income * (actualAttendance / baseAttendance)).round();
  }

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

  /// 試合中に交代した回数(ハーフタイムは数えない)と、最後に交代した
  /// 止まった場面の印(同じ場面の続けての交代は1回と数える)。
  int _liveSubWindowsUsed = 0;
  String? _liveSubWindowKey;

  /// 再起動後に後半の途中から再開するときの、後半の途中経過と再開する分。
  /// [GameStateMatch.playSecondHalf]が一度だけ使う。
  ({HalfTally tally, int resumeMinute})? _liveSecondHalfResume;
  static const int maxSubstitutionsPerMatch = substitutionsPerMatch;
  static const int maxSubstitutionWindowsPerMatch = substitutionWindowsPerMatch;

  /// 結果だけ見る自クラブの試合で、ハーフタイムと後半の途中(60〜75分)に
  /// 自動で行った交代(行った順)。
  /// 試合の確定([GameStateMatch._finalizeSecondHalf])で出場を数え、先発の
  /// 指定を元に戻してから空にする。
  List<AutoSubstitutionPlan> _liveAutoSubPlans = [];

  /// ハーフタイムに利用者が行った交代の出来事(46分)。後半を始めるときに
  /// 後半の出来事の頭に入れ、試合経過に「交代: A → B」と出す。
  List<MatchEvent> _liveHalfTimeSubEvents = [];

  // ---- カップ戦のライブ観戦(リーグ戦と同じ進行を再利用する) ----
  LiveCupKind? _liveCupKind;
  Team? _liveCupHome;
  Team? _liveCupAway;
  Weather? _liveCupWeather;
  CupMatch? _liveCupMatch;
  CupTie? _liveCupTie;

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

  /// 国内カップ優勝の報酬(5部の額)。
  static const int domesticCupChampionPrize = 700;

  /// 古い形の大陸カップ優勝の報酬(5部の額)。
  static const int continentalChampionPrize = 1500;

  /// 新しいゲームの初期資金(5部の額)。5部の年収の半年分ほど。
  static const int initialBudgetTier5 = 20000;

  /// [tier] 部から始めるときの初期資金。その部の年収の半年分
  /// (5部なら [initialBudgetTier5] と同じ 2億)。3部制にして3部から
  /// 始まるようになった(2026-11-22)。
  /// 国で年収の目安が違う(放映権の差)ので、初期の資金も国で違う。
  static int initialBudgetFor(
    int tier, [
    LeagueTheme theme = LeagueTheme.england,
  ]) =>
      typicalAnnualIncome(tier, theme) ~/ 2;

  /// [tier] 部から始めるときの自クラブの強さ。その部の真ん中
  /// (3部なら 72)。人件費率がその部の真ん中のクラブと同じくらいになる。
  static int userStartStrength(int tier) {
    final (lo, hi) = divisionStrengthRange(tier);
    return (lo + hi) ~/ 2;
  }

  /// 自クラブの初めの人件費率(年俸の合計 ÷ 年収の目安)の幅。
  static const double userStartWageRatioMin = 0.7;
  static const double userStartWageRatioMax = 1.0;

  /// 人件費率が幅に入るまで作り直す回数の上限。
  static const int userStartSquadTries = 12;

  /// 自クラブの初めの選手を作る(年俸の水準は [setHomeWageLevel] で今の
  /// 国・部に合わせてから呼ぶ)。
  ///
  /// 強さは部の真ん中([userStartStrength])でも、年俸は能力に対して指数で
  /// 伸びるので、数人の主力の引きで人件費率が大きく振れる。3部から始めると
  /// 60ゲームのうち1〜3割で 110% を超え(最大 177%)、運営費もあって数季で
  /// 資金が尽きる回があった(2026-11-23)。人件費率が [userStartWageRatioMin]〜
  /// [userStartWageRatioMax] に入る選手の組を選ぶ(入らなければ、いちばん
  /// 近いもの)。部の真ん中のクラブを買う、という前提に合わせる。
  static Team generateUserStartSquad({
    required String name,
    required int tier,
    required LeagueTheme theme,
  }) {
    final income = typicalAnnualIncome(tier, theme);
    Team? best;
    var bestGap = double.infinity;
    for (var i = 0; i < userStartSquadTries; i++) {
      final team = PlayerGenerator.generateSquad(
        id: 'user',
        name: name,
        strengthTier: userStartStrength(tier),
      );
      final ratio =
          annualFromWeekly(ContractEngine.weeklyWageBill(team)) / income;
      if (ratio >= userStartWageRatioMin && ratio <= userStartWageRatioMax) {
        return team;
      }
      final gap = ratio < userStartWageRatioMin
          ? userStartWageRatioMin - ratio
          : ratio - userStartWageRatioMax;
      if (gap < bestGap) {
        best = team;
        bestGap = gap;
      }
    }
    return best!;
  }

  /// 古い形の大陸カップ(2026-11-22 より前のセーブ)のグループの1勝の
  /// 賞金(5部の額)。今の大会の賞金は economy_scale.dart の
  /// championsCup* と continentalPrize。
  static const int continentalGroupWinPrize = 40;

  /// 古い形の大陸カップの決勝トーナメントで1タイ勝ち上がるごとの賞金。
  static const int continentalTieWinPrize = 150;

  /// 直近のカップ戦で自クラブが獲得した賞金の通知文。賞金は従来budgetへ
  /// 無言で加算されており、プレイヤーが「勝つと賞金が入る」ことに気づけ
  /// なかったため、獲得のたびにここへ文言を積み、UI側(クイック消化の
  /// SnackBar/ライブのフルタイム画面)が表示後にnullへ戻す。
  String? lastCupPrizeNote;

  /// シーズン終了時に理事会の目標順位を達成した場合の報奨金の通知文。
  /// UI側(シーズン開始処理後のSnackBar)が表示に使う。
  String? lastBoardBonusNote;

  /// シーズン終了時の、雇っている監督の任期の通知文(残り1年など)。
  String? lastManagerContractNote;

  /// 直近の昇格で理事会から支給された補強予算(万円)。昇格していなければ0。
  int lastPromotionBonus = 0;

  /// 直近のstartNextSeasonでの昇格・降格結果メッセージ(なければnull)。
  String? lastDivisionChangeMessage;

  /// 直近に終えたシーズンの締めくくり。シーズン開始レポートに出す絵を
  /// 決めるために持つ。優勝は昇格より上に置く(優勝すればたいてい昇格も
  /// しているが、見せたいのは優勝のほう)。
  SeasonFinale lastSeasonFinale = SeasonFinale.none;

  /// 直近のstartNextSeasonで昇格プレーオフが行われた場合の各試合結果
  /// (準決勝2試合+決勝の順、表示用に整形済み)。行われなかった場合は空。
  List<String> lastPromotionPlayoffResults = [];

  /// 直近のプレーオフにユーザークラブが出場していたかどうか。
  bool userInvolvedInLastPromotionPlayoff = false;

  /// 直近に終えた季の、自クラブの結果のまとめ(シーズン開始レポートの
  /// 先頭に出す)。出したら null に戻す。
  List<String>? lastSeasonResultLines;

  /// 締切を過ぎて既定の答えで片付けた決めごとの知らせ(1件1行)。
  /// 節の知らせに出したら空に戻す。
  List<String> lastAutoDecisions = [];
}
