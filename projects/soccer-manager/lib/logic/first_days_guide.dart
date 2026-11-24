import '../l10n/tr.dart';
import '../state/game_state.dart';
import 'todo_advisor.dart';

/// 最初の数日の案内の1段。
class GuideStep {
  const GuideStep(this.id, this.number, this.title, this.note, this.place);

  /// 保存に使う名前(SaveGame.firstRunStepsSeen に `guide_<id>` で残す)。
  final String id;

  /// 何段目か(1から)。
  final int number;
  final String title;
  final String note;
  final TodoPlace place;
}

/// 最初の数日を、状況の「やること」の行で1つずつ案内する(2026-11-25)。
///
/// 以前は起動したときに5枚の説明(オーナーであること・試合は監督・2つの
/// 期待・手放す条件・続きがあること)を読ませていた。読んでも、どこを
/// 押せばよいかは分からなかった。いまは、オーナーの仕事の場所を1つずつ
/// 押して回ってもらう。行を押すと、その場所へ移り、次の段に替わる。
///
/// 出すのは、1季目の開幕前(自クラブのリーグ戦がまだ無い)のあいだだけ。
/// 最後の段(進むボタン)は押しても消えず、最初のリーグ戦で終わる。
class FirstDaysGuide {
  const FirstDaysGuide._();

  static const String _prefix = 'guide_';

  /// 段の一覧(この順に1つずつ出す)。言語の切り替えに追従させるため getter。
  static List<GuideStep> get steps => [
        GuideStep(
          'finance',
          1,
          Tr.pick('はじめに(1/5): 経営でお金を見る',
              'Getting started (1/5): check the money'),
          Tr.pick('資金・1年の収支・予算がここに。株主の期待は収支で決まります。',
              'Funds, the yearly balance and the budget. Shareholders judge you on the books.'),
          TodoPlaces.financeOverview,
        ),
        GuideStep(
          'squad',
          2,
          Tr.pick('はじめに(2/5): 選手を見る', 'Getting started (2/5): meet the squad'),
          Tr.pick('先発と戦い方は監督が決めます。あなたは契約と補強を決めます。',
              'The manager picks the team. You handle contracts and signings.'),
          TodoPlaces.squadList,
        ),
        GuideStep(
          'transfer',
          3,
          Tr.pick('はじめに(3/5): 補強の候補を見る',
              'Getting started (3/5): look at targets'),
          Tr.pick('監督の補強案から、取りたい選手と交渉します。',
              "Pick from the manager's wish list and open talks."),
          TodoPlaces.transferPicks,
        ),
        GuideStep(
          'office',
          4,
          Tr.pick('はじめに(4/5): オーナー室で手を打つ',
              "Getting started (4/5): the owner's office"),
          Tr.pick('広報は月に1回。サポーターの期待が下がったら、ここで支えます。',
              'One PR move a month. When the fans cool, this is where you win them back.'),
          TodoPlaces.ownerWorks,
        ),
        GuideStep(
          'advance',
          5,
          Tr.pick('はじめに(5/5): 進むボタンで日を進める',
              'Getting started (5/5): move the days on'),
          Tr.pick('上の帯の進むボタンで、次の試合や給料日まで進みます。決めることは「必須」に出ます。',
              'The advance button at the top takes you to the next match or payday. Anything you must decide shows up as a must-do.'),
          TodoPlaces.status,
        ),
      ];

  /// いま出す段。無ければ null。
  static GuideStep? current(GameState gs) {
    final save = gs.save;
    if (save == null || save.firstRunGuideDismissed) return null;
    if (save.league.season != 1 || !gs.isPreseason) return null;
    for (final s in steps) {
      if (!save.firstRunStepsSeen.contains('$_prefix${s.id}')) return s;
    }
    return null;
  }

  /// 段 [id] を見たことにする(行を押したとき)。最後の段は消さない
  /// (最初のリーグ戦で終わる)。
  static void markSeen(GameState gs, String id) {
    if (id == 'advance') return;
    gs.markGuideStepSeen('$_prefix$id');
  }
}
