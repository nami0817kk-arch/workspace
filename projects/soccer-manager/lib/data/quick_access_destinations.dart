import 'package:flutter/material.dart';

import '../screens/achievements_screen.dart';
import '../screens/reference_screens.dart';
import '../screens/club_screen.dart';
import '../screens/contract_board_screen.dart';
import '../screens/registration_rules_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/cup_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/hall_of_fame_screen.dart';
import '../screens/owner_work_screen.dart';
import '../screens/season_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/youth_screen.dart';
import '../l10n/tr.dart';
import '../state/game_state.dart';

/// ホーム画面の「クラブ運営」タイルと、各メインタブのクイックアクセス
/// ドロワーの両方から参照する遷移先の一覧。1箇所で管理することで、
/// 新しい管理画面を追加したときにどちらか一方だけ更新し忘れる事故を防ぐ。
/// 引き出しの中のまとまり。
///
/// - [manage]: 操作する画面。横画面では左メニューにあるので、引き出しには
///   出さない。
/// - [reference]: 見るだけの画面(資料)。横画面では、ここが唯一の入口。
/// - [help]: 設定・用語集・ガイド。
enum QuickAccessGroup { manage, reference, help }

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

  /// 引き出しの中のまとまり。
  final QuickAccessGroup group;

  const QuickAccessDestination({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
    this.lockedReason,
    this.group = QuickAccessGroup.manage,
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
      // カレンダー(月のマス目と1年の予定)。縦画面はここから開く。
      // 横画面では左メニューの項目(状況のすぐ下)。上の帯の日付からも移る。
      QuickAccessDestination(
        icon: Icons.event_note,
        label: Tr.pick('カレンダー', 'Calendar'),
        color: Colors.teal.shade600,
        builder: (_) => const CalendarHubScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.badge_outlined,
        label: Tr.pick('登録と契約', 'Registration & contracts'),
        color: Colors.brown.shade600,
        builder: (_) => const ContractBoardScreen(),
      ),
      // 国の登録の決まり(2026-11-25)。横画面では「選手」の3つ目のタブ。
      QuickAccessDestination(
        icon: Icons.rule,
        label: Tr.pick('登録ルール', 'Registration rules'),
        color: Colors.brown.shade400,
        builder: (_) => const RegistrationRulesScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.work_outline,
        label: Tr.pick('オーナーの仕事', 'Owner\'s work'),
        color: Colors.indigo.shade600,
        builder: (_) => const OwnerWorkScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.swap_horiz,
        label: Tr.pick('移籍市場', 'Transfers'),
        color: Colors.indigo.shade400,
        builder: (_) => const TransferScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_people,
        label: Tr.pick('ユース・新人発掘', 'Youth & intake'),
        color: Colors.teal.shade400,
        builder: (_) => const YouthScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.account_balance,
        label: Tr.pick('クラブ経営', 'Club finances'),
        color: Colors.brown.shade400,
        builder: (_) => const FinanceScreen(),
      ),
      // ---- 資料(見るだけ)。経営・オーナー室のタブから移した ----
      QuickAccessDestination(
        icon: Icons.table_chart_outlined,
        label: Tr.pick('収支の詳しい表', 'Accounts in detail'),
        color: Colors.brown.shade500,
        builder: (_) => const FinanceReportScreen(),
        group: QuickAccessGroup.reference,
      ),
      QuickAccessDestination(
        icon: Icons.shield_outlined,
        label: Tr.pick('クラブとオーナーの記録', 'Club & owner records'),
        color: Colors.blueGrey.shade600,
        builder: (_) => const ClubRecordsScreen(),
        group: QuickAccessGroup.reference,
      ),
      QuickAccessDestination(
        icon: Icons.apartment,
        label: Tr.pick('施設・スタッフ', 'Facilities & staff'),
        color: Colors.blueGrey.shade400,
        builder: (_) => const ClubScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.query_stats,
        label: Tr.pick('シーズン分析', 'Season analysis'),
        color: Colors.teal.shade400,
        builder: (_) => const AnalysisScreen(),
        group: QuickAccessGroup.reference,
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('カップ戦', 'Cups'),
        color: Colors.purple.shade400,
        builder: (_) => const CupScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.settings,
        label: Tr.pick('設定', 'Settings'),
        color: Colors.blueGrey.shade700,
        builder: (_) => const SettingsScreen(),
        group: QuickAccessGroup.help,
      ),
      QuickAccessDestination(
        icon: Icons.history,
        label: Tr.pick('シーズン成績', 'Season archive'),
        color: Colors.teal.shade700,
        builder: (_) => const SeasonHistoryScreen(),
        group: QuickAccessGroup.reference,
        lockedReason: _needsFirstSeason,
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('殿堂', 'Hall of fame'),
        color: Colors.brown.shade700,
        builder: (_) => const HallOfFameScreen(),
        group: QuickAccessGroup.reference,
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
        group: QuickAccessGroup.help,
      ),
      QuickAccessDestination(
        icon: Icons.help_outline,
        label: Tr.pick('ガイド', 'Guide'),
        color: Colors.lightGreen.shade700,
        builder: (_) => const GuideScreen(),
        group: QuickAccessGroup.help,
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('実績', 'Achievements'),
        color: Colors.amber.shade700,
        builder: (_) => const AchievementsScreen(),
        group: QuickAccessGroup.reference,
      ),
    ];
