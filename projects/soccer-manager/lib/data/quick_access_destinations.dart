import 'package:flutter/material.dart';

import '../screens/achievements_screen.dart';
import '../screens/awards_screen.dart';
import '../screens/best_eleven_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/club_screen.dart';
import '../screens/cup_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/hall_of_fame_screen.dart';
import '../screens/league_ranking_screen.dart';
import '../screens/manager_career_screen.dart';
import '../screens/news_screen.dart';
import '../screens/player_search_screen.dart';
import '../screens/season_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/training_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/youth_screen.dart';
import '../l10n/tr.dart';
import '../state/game_state.dart';

/// ホーム画面の「クラブ運営」タイルと、各メインタブのクイックアクセス
/// ドロワーの両方から参照する遷移先の一覧。1箇所で管理することで、
/// 新しい管理画面を追加したときにどちらか一方だけ更新し忘れる事故を防ぐ。
class QuickAccessDestination {
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder builder;

  /// 条件を満たすまで中身が空になる画面の、開放条件の説明を返す。
  /// 開いてよければ null。
  ///
  /// 表彰・シーズン成績・ベストイレブン・殿堂は、シーズンを1つ終えるまで
  /// 「まだ記録がありません」しか出ない。始めたばかりの利用者がメニューを
  /// 開くと、20項目のうち4つが空振りになる。項目を隠すのではなく、
  /// いつ開くかを見せて目標として機能させる。
  final String? Function(GameState)? lockedReason;

  const QuickAccessDestination({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
    this.lockedReason,
  });
}

/// シーズンを1つ終えるまで空になる画面に共通の開放条件。
/// 残り節数が分かるときは具体的な数を出す。
String? _needsFirstSeason(GameState game) {
  if (game.seasonHistory.isNotEmpty) return null;
  final left = game.remainingMatchdaysThisSeason;
  if (left > 0) {
    return Tr.pick('今シーズンを終えると開きます(残り$left節)',
        'Opens when you finish this season ($left to play)');
  }
  return Tr.pick('シーズンの切り替えで開きます', 'Opens when the season rolls over');
}

// 同上。final だと最初のアクセス時の言語でラベルが固定される。
List<QuickAccessDestination> get quickAccessDestinations => [
      QuickAccessDestination(
        icon: Icons.fitness_center,
        label: Tr.pick('トレーニング', 'Training'),
        color: Colors.deepOrange.shade400,
        builder: (_) => const TrainingScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.swap_horiz,
        label: Tr.pick('移籍市場', 'Transfers'),
        color: Colors.indigo.shade400,
        builder: (_) => const TransferScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_people,
        label: Tr.pick('ユース・スカウト', 'Youth & scouting'),
        color: Colors.teal.shade400,
        builder: (_) => const YouthScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.account_balance,
        label: Tr.pick('クラブ経営', 'Club finances'),
        color: Colors.brown.shade400,
        builder: (_) => const FinanceScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.person_search,
        label: Tr.pick('選手検索', 'Player search'),
        color: Colors.pink.shade400,
        builder: (_) => const PlayerSearchScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.newspaper,
        label: Tr.pick('クラブニュース', 'Club news'),
        color: Colors.deepPurple.shade400,
        builder: (_) => const NewsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.apartment,
        label: Tr.pick('施設・スタッフ', 'Facilities & staff'),
        color: Colors.blueGrey.shade400,
        builder: (_) => const ClubScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('カップ戦', 'Cups'),
        color: Colors.purple.shade400,
        builder: (_) => const CupScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.military_tech,
        label: Tr.pick('個人タイトル', 'Individual awards'),
        color: Colors.amber.shade700,
        builder: (_) => const AwardsScreen(),
        lockedReason: _needsFirstSeason,
      ),
      QuickAccessDestination(
        icon: Icons.format_list_numbered,
        label: Tr.pick('リーグランキング', 'League rankings'),
        color: Colors.green.shade700,
        builder: (_) => const LeagueRankingScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.workspace_premium,
        label: Tr.pick('監督キャリア', 'Managerial career'),
        color: Colors.indigo.shade700,
        builder: (_) => const ManagerCareerScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.settings,
        label: Tr.pick('設定', 'Settings'),
        color: Colors.blueGrey.shade700,
        builder: (_) => const SettingsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.history,
        label: Tr.pick('シーズン成績', 'Season archive'),
        color: Colors.teal.shade700,
        builder: (_) => const SeasonHistoryScreen(),
        lockedReason: _needsFirstSeason,
      ),
      QuickAccessDestination(
        icon: Icons.groups,
        label: Tr.pick('ベストイレブン', 'Team of the season'),
        color: Colors.orange.shade700,
        builder: (_) => const BestElevenScreen(),
        lockedReason: _needsFirstSeason,
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('殿堂', 'Hall of fame'),
        color: Colors.brown.shade700,
        builder: (_) => const HallOfFameScreen(),
        // 殿堂はシーズンを終えるだけでは埋まらない。引退した選手が出て
        // 初めて中身ができるので、条件を分けてある。
        lockedReason: (game) => game.save?.retiredLegends.isNotEmpty ?? false
            ? null
            : Tr.pick('選手が引退すると殿堂入りします(シーズン終了時に判定)',
                'Players enter the hall of fame when they retire (checked at season end)'),
      ),
      QuickAccessDestination(
        icon: Icons.menu_book,
        label: Tr.pick('用語集', 'Glossary'),
        color: Colors.cyan.shade700,
        builder: (_) => const GlossaryScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.help_outline,
        label: Tr.pick('ガイド', 'Guide'),
        color: Colors.lightGreen.shade700,
        builder: (_) => const GuideScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('実績', 'Achievements'),
        color: Colors.amber.shade700,
        builder: (_) => const AchievementsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.calendar_month,
        label: Tr.pick('カレンダー', 'Calendar'),
        color: Colors.lightBlue.shade700,
        builder: (_) => const CalendarScreen(),
      ),
    ];
