import '../l10n/tr.dart';
import '../models/club_infrastructure.dart';
import '../models/matchday_promo.dart';
import '../models/owner_work.dart';
import '../state/game_state.dart';
import 'contract_board_engine.dart';
import 'contract_engine.dart';
import 'economy_scale.dart';
import 'next_action_advisor.dart';
import 'signing_proposal_engine.dart';
import 'sponsor_slots.dart';

/// 「やること」の重さ。
///
/// - [must]: 答えないと不利益が出る・期限で自動に片付く・放っておくと損が
///   確定するもの。進むボタンにも件数を出す。
/// - [recommended]: やれば得なこと・回数や時期の限りがある機会。いま実行
///   できるものだけを挙げる。
enum TodoLevel { must, recommended }

/// 左メニューの項目(横画面の並びと同じ順)。
///
/// カレンダーは状況のすぐ下(2026-11-24)。試合日が分かる画面が欲しいという
/// 声で、上の帯の日付から開くだけだったものを、項目にした。
enum TodoMenu {
  status,
  calendar,
  finance,
  club,
  squad,
  transfer,
  league,
  ownerRoom,
}

/// 行き先。左メニューの項目と、その中のタブ(左から0始まり)と、必要なら
/// 中の札の名前。
///
/// **タブの番号を書くのはこのファイルの [TodoPlaces] だけ。** タブの構成を
/// 変えるときは、ここを直せば「やること」の行き先と印が全部ついてくる
/// (tab_places_test.dart が、番号と実際の画面の並びを突き合わせている)。
class TodoPlace {
  const TodoPlace(this.menu, {this.tab = 0, this.card});

  final TodoMenu menu;
  final int tab;

  /// タブの中の札(オーナーの仕事の分野など)。無ければ null。
  final String? card;

  @override
  bool operator ==(Object other) =>
      other is TodoPlace &&
      other.menu == menu &&
      other.tab == tab &&
      other.card == card;

  @override
  int get hashCode => Object.hash(menu, tab, card);

  @override
  String toString() =>
      'TodoPlace(${menu.name}, $tab${card == null ? '' : ', $card'})';
}

/// 行き先の一覧(名前で引く)。
class TodoPlaces {
  const TodoPlaces._();

  /// 状況。その場で答える札はここに出る。
  static const status = TodoPlace(TodoMenu.status);

  /// 状況の、オーナーの目標を選ぶ一覧(下から出る)。
  static const ownerGoal = TodoPlace(TodoMenu.status, card: cardOwnerGoal);

  /// カレンダー(タブなし。中で「月」と「1年の予定」を切り替える)。
  static const calendar = TodoPlace(TodoMenu.calendar);

  // 経営: 概要・お金を作る・方針と投資
  static const financeOverview = TodoPlace(TodoMenu.finance);
  static const financeFunding = TodoPlace(TodoMenu.finance, tab: 1);
  static const financeProjects = TodoPlace(TodoMenu.finance, tab: 2);

  // クラブ: スタッフ・施設・ファンと街・ユースとスカウト
  static const clubStaff = TodoPlace(TodoMenu.club);
  static const clubFacilities = TodoPlace(TodoMenu.club, tab: 1);
  static const clubCommunity = TodoPlace(TodoMenu.club, tab: 2);
  static const clubYouth = TodoPlace(TodoMenu.club, tab: 3);

  // 選手: スカッド・登録と契約
  static const squadList = TodoPlace(TodoMenu.squad);
  static const squadContracts = TodoPlace(TodoMenu.squad, tab: 1);

  // リーグ: 順位と日程・カップ戦
  static const leagueCups = TodoPlace(TodoMenu.league, tab: 1);

  // 移籍: 候補(監督の補強案・注目)・探す(選手・フリー・スカウトの地域)・
  // 交渉とオファー
  static const transferPicks = TodoPlace(TodoMenu.transfer);
  static const transferSearch = TodoPlace(TodoMenu.transfer, tab: 1);
  static const transferTalks = TodoPlace(TodoMenu.transfer, tab: 2);
  static const transferOffers = TodoPlace(TodoMenu.transfer, tab: 2);

  // オーナー室: オーナーの仕事(分野の札)・オーナーと世界
  static const ownerMatchday =
      TodoPlace(TodoMenu.ownerRoom, card: cardMatchday);
  static const ownerFans = TodoPlace(TodoMenu.ownerRoom, card: cardFans);
  static const ownerWorks = TodoPlace(TodoMenu.ownerRoom, card: cardWorks);
  static const ownerFinanceWorks =
      TodoPlace(TodoMenu.ownerRoom, card: cardFinanceWorks);
  static const ownerCommunityWorks =
      TodoPlace(TodoMenu.ownerRoom, card: cardCommunityWorks);
  static const ownerWorld = TodoPlace(TodoMenu.ownerRoom, tab: 1);

  static const String cardOwnerGoal = 'ownerGoal';
  static const String cardMatchday = 'matchday';
  static const String cardFans = 'fans';
  static const String cardWorks = 'works';
  static const String cardFinanceWorks = 'financeWorks';
  static const String cardCommunityWorks = 'communityWorks';
}

/// 「やること」の種類。上から、一覧に並べる順。
enum TodoKind {
  // ---- 必須 ----
  /// サポーターの最後通告。
  ultimatum,

  /// 季の切り替えの給与で資金が足りなくなる。
  rolloverShortfall,

  /// 資金がマイナス。
  budgetNegative,

  /// サポーターの期待が下がり続けている(低いときは必須、まだ余裕が
  /// あればおすすめ)。
  supporterFalling,

  /// 理事会レビュー(状況の札で了解する)。
  boardReview,

  /// オーナーの判断を待つ事件(状況の札)。
  ownerEvent,

  /// 株主総会の要求(状況の札)。
  agmDemand,

  /// 噂への答え(状況の札)。
  rumor,

  /// 手術か保存療法か(状況の札)。
  surgery,

  /// 自分の選手へのオファー(状況の札。移籍>オファーにも同じものがある)。
  incomingOffers,

  /// スポンサーを選んでいない。
  sponsor,

  /// ユースインテーク(状況の札)。
  youthIntake,

  /// 開幕前の海外ツアーに出るか(状況の札)。
  preseasonTour,

  /// 相手のクラブからの対案。
  counterOffers,

  /// クラブと合意し、選手と話す交渉。
  agreedTalks,

  /// スタッフの引き抜きの話。
  staffOffers,

  // ---- おすすめ ----
  /// 移籍の締切が近い。
  transferDeadline,

  /// スタッフの空席。
  staffVacant,

  /// オーナーの目標が未設定。
  ownerGoal,

  /// 年間シートを売れる(開幕前だけ)。
  seasonTickets,

  /// クラブの方針を変えられる(開幕前だけ)。
  clubPolicy,

  /// 監督からの提案(契約更新・ユース昇格)が承認待ち。
  managerProposals,

  /// 監督の補強候補。
  signingProposals,

  /// 枠ごとのスポンサー・命名権の話。
  sponsorSlots,

  /// ユースの有望株が出ていきそう。
  youthAtRisk,

  /// 更新の時期の選手。
  contractRenewals,

  /// 今月の広報がまだ。
  monthlyPr,

  /// 次の節の試合日のイベントを決めていない。
  matchdayEvent,

  /// 仮契約を話せる時期。
  preContracts,

  /// 増築できる施設がある。
  facilities,

  /// 今季まだ打てるオーナーの手。
  ownerWorks,
}

/// 「やること」1件。
class TodoItem {
  const TodoItem({
    required this.kind,
    required this.level,
    required this.title,
    required this.note,
    required this.place,
    this.count = 1,
    this.inline = false,
    bool? marked,
  }) : marked = marked ?? level == TodoLevel.must;

  final TodoKind kind;
  final TodoLevel level;

  /// 題(1行)。
  final String title;

  /// 一言の説明。期限があればここに書く(「あと2節で自動で決まります」)。
  final String note;

  /// 押したときの行き先。印もここに付く。
  final TodoPlace place;

  /// 件数(オファー3件なら3)。
  final int count;

  /// 状況の画面に、その場で答えられる札が出ているか。出ているものは
  /// 一覧に行としては並べない(札そのものが並ぶ)。
  final bool inline;

  /// 左メニューとタブに印を付けるか。必須は必ず付ける。おすすめは、期限や
  /// 時期があって「今だけ」のものにだけ付ける([TodoAdvisor.markedKinds])。
  /// いつでも出がちなもの(増築できる施設・更新の時期・打てるオーナーの手)
  /// にまで付けると、左メニューのほぼ全部に点が付いて、印の意味が無くなった。
  final bool marked;

  bool get isMust => level == TodoLevel.must;

  /// 保存や検査で使う名前。
  String get id => kind.name;
}

/// 一覧から件数を引く。印(左メニュー・タブ・進むボタン)と見出しは、
/// 全部ここを通す(数え方を1つにする)。
extension TodoCounts on List<TodoItem> {
  Iterable<TodoItem> get must => where((t) => t.isMust);
  Iterable<TodoItem> get recommended => where((t) => !t.isMust);

  /// 必須の件数(見出し・進むボタン・状況の印)。
  int get mustCount => must.fold(0, (n, t) => n + t.count);

  /// おすすめの数(行の数。見出しに出す)。
  int get recommendedCount => recommended.length;

  /// [menu](と [tab])に付ける必須の件数。
  ///
  /// 状況は一覧そのものがある場所なので、全部の必須を数える。ほかの項目は
  /// 行き先がそこのものだけ。届いたオファーは状況の札と移籍>オファーの
  /// 両方で答えられるので、両方に数える。
  int mustAt(TodoMenu menu, [int? tab]) {
    if (menu == TodoMenu.status) return mustCount;
    var n = 0;
    for (final t in must) {
      for (final p in _placesOf(t)) {
        if (p.menu == menu && (tab == null || p.tab == tab)) n += t.count;
      }
    }
    return n;
  }

  /// [menu](と [tab])に付けるおすすめの数。状況には付けない(一覧が
  /// その場にあり、ほぼ常に何かあるので、印の意味が無くなる)。
  int recommendedAt(TodoMenu menu, [int? tab]) {
    if (menu == TodoMenu.status) return 0;
    var n = 0;
    for (final t in recommended) {
      if (!t.marked) continue;
      if (t.place.menu == menu && (tab == null || t.place.tab == tab)) n++;
    }
    return n;
  }

  static Iterable<TodoPlace> _placesOf(TodoItem t) sync* {
    if (t.place.menu != TodoMenu.status) yield t.place;
    if (t.kind == TodoKind.incomingOffers) yield TodoPlaces.transferOffers;
  }
}

/// いまのゲームの状態から「やること」の一覧を作る。
///
/// 以前は、左メニューの印・状況の「決めること」・「今週の決断」が別々の
/// 条件で数えていて、どこにも出ない用件(監督からの提案・今月の広報・
/// 開幕前の決めごとなど)があった。ここを唯一の源にする。
///
/// 判定そのものは既存のもの([GameStateRivals.inboxEntries]・
/// [NextActionAdvisor.all])を呼んで使い、ここでは種類ごとの題・重さ・
/// 行き先を決めるだけ(条件を写して二重に持たない)。
class TodoAdvisor {
  const TodoAdvisor._();

  /// おすすめのうち、左メニューとタブに青い点を付ける種類。期限や時期が
  /// あって今だけのもの。スタッフの空席は開幕前だけ([build] の中で見る)。
  static const Set<TodoKind> markedKinds = {
    TodoKind.supporterFalling,
    TodoKind.transferDeadline,
    TodoKind.seasonTickets,
    TodoKind.clubPolicy,
    TodoKind.managerProposals,
    TodoKind.signingProposals,
    TodoKind.sponsorSlots,
    TodoKind.youthAtRisk,
    TodoKind.monthlyPr,
    TodoKind.matchdayEvent,
    TodoKind.preContracts,
  };

  /// [hasSigningProposals] は、監督の補強候補があるか。省くとここで調べる
  /// (他のクラブの選手を見て回るので、分かっているなら渡す)。
  static List<TodoItem> build(GameState gs, {bool? hasSigningProposals}) {
    final save = gs.save;
    if (save == null || gs.saleReason != null) return const [];
    final team = gs.userTeam;
    final items = <TodoItem>[];
    final preseason = gs.isPreseason;
    void add(TodoItem t) => items.add(TodoItem(
          kind: t.kind,
          level: t.level,
          title: t.title,
          note: t.note,
          place: t.place,
          count: t.count,
          inline: t.inline,
          marked: t.isMust ||
              markedKinds.contains(t.kind) ||
              (t.kind == TodoKind.staffVacant && preseason),
        ));

    String deadline(String key) => gs.isPreseason
        ? ''
        : Tr.pick('あと${gs.decisionMatchdaysLeft(key)}節で自動で決まります。',
            'Decided for you in ${Tr.plural(gs.decisionMatchdaysLeft(key), 'matchday')}.');

    // ---- 答えを待つもの(受信箱と同じ判定) ----
    final inbox = gs.inboxEntries;
    final surgeries = inbox.where((e) => e.kind == InboxKind.surgery).toList();
    for (final e in inbox) {
      switch (e.kind) {
        case InboxKind.ownerEvent:
          add(TodoItem(
            kind: TodoKind.ownerEvent,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('状況の札で答えます。', 'Answer on the status page.'),
            place: TodoPlaces.status,
            inline: true,
          ));
        case InboxKind.rumor:
          add(TodoItem(
            kind: TodoKind.rumor,
            level: TodoLevel.must,
            title: e.text,
            note: deadline('rumor'),
            place: TodoPlaces.status,
            inline: true,
          ));
        case InboxKind.surgery:
          // 選手ごとに1行来るが、札は1枚なので1件にまとめる。
          if (e != surgeries.first) break;
          add(TodoItem(
            kind: TodoKind.surgery,
            level: TodoLevel.must,
            title: surgeries.length == 1
                ? e.text
                : Tr.pick('治療(手術か保存療法か)を決めていない選手が${surgeries.length}人',
                    '${surgeries.length} players need a treatment decision'),
            note: deadline('surgery:${e.ref}'),
            place: TodoPlaces.status,
            count: surgeries.length,
            inline: true,
          ));
        case InboxKind.agmDemand:
          add(TodoItem(
            kind: TodoKind.agmDemand,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('状況の札で答えます。', 'Answer on the status page.'),
            place: TodoPlaces.status,
            inline: true,
          ));
        case InboxKind.incomingOffers:
          add(TodoItem(
            kind: TodoKind.incomingOffers,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('承認するか断るかを決めます。移籍のオファーのタブにも同じものがあります。',
                'Accept or turn them down. The same offers are under Transfers.'),
            place: TodoPlaces.status,
            count: e.count,
            inline: true,
          ));
        case InboxKind.counterOffers:
          add(TodoItem(
            kind: TodoKind.counterOffers,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('受けるか、条件を出し直すかを決めます。放っておくと話は流れます。',
                'Accept or come back with new terms. Left alone, the talks lapse.'),
            place: TodoPlaces.transferTalks,
            count: e.count,
          ));
        case InboxKind.agreedTalks:
          add(TodoItem(
            kind: TodoKind.agreedTalks,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('選手に条件を出すと契約がまとまります。放っておくと話は流れます。',
                'Offer the player terms to finish the deal. Left alone, it lapses.'),
            place: TodoPlaces.transferTalks,
            count: e.count,
          ));
        case InboxKind.staffOffers:
          add(TodoItem(
            kind: TodoKind.staffOffers,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('引き止めるか送り出すかを決めます。',
                'Decide whether to keep them or let them go.'),
            place: TodoPlaces.clubStaff,
            count: e.count,
          ));
        case InboxKind.sponsor:
          final n = save.pendingSponsorOffers.length;
          add(TodoItem(
            kind: TodoKind.sponsor,
            level: TodoLevel.must,
            title: e.text,
            note: Tr.pick('オファーが$n件届いています。結ぶと毎節の収入が増えます。${deadline('sponsor')}',
                '${Tr.plural(n, 'offer')} waiting. Signing one adds income every matchday. ${deadline('sponsor')}'),
            place: TodoPlaces.financeFunding,
          ));
      }
    }

    // 理事会レビュー(受信箱の行には無いが、答えを待つものとして数えている)。
    if (gs.pendingBoardReviewMessage != null) {
      add(TodoItem(
        kind: TodoKind.boardReview,
        level: TodoLevel.must,
        title: Tr.pick(
            'シーズン中盤の理事会レビューが届いています', 'The mid-season board review is in'),
        note: Tr.pick('読んで了解します。', 'Read it and acknowledge.'),
        place: TodoPlaces.status,
        inline: true,
      ));
    }

    // ユースインテークと開幕前の海外ツアー。どちらも状況の札で答える。
    if (gs.pendingYouthIntake.isNotEmpty) {
      final n = gs.pendingYouthIntake.length;
      add(TodoItem(
        kind: TodoKind.youthIntake,
        level: TodoLevel.must,
        title: Tr.pick('ユースの新人候補が$n名、加入を待っています',
            '${Tr.plural(n, 'young hopeful')} waiting to join'),
        note: Tr.pick('誰を受け入れるかを選びます。', 'Choose who to take on.'),
        place: TodoPlaces.status,
        count: n,
        inline: true,
      ));
    }
    if (gs.preseasonTourPending) {
      add(TodoItem(
        kind: TodoKind.preseasonTour,
        level: TodoLevel.must,
        title: Tr.pick(
            '開幕前の海外ツアーに出るか決めていません', 'Decide on the pre-season overseas tour'),
        note: Tr.pick(
            '開幕すると、出ないことになります。', 'Once the season starts, the chance is gone.'),
        place: TodoPlaces.status,
        inline: true,
      ));
    }

    // ---- 「今週の決断」が挙げていたもの(同じ判定を呼ぶ) ----
    final signing = hasSigningProposals ??
        (gs.isTransferWindowOpen &&
            SigningProposalEngine.propose(team, gs.proposalTargets,
                    budget: save.budget)
                .isNotEmpty);
    final actions = NextActionAdvisor.all(
      save,
      team,
      hasSigningProposals: signing,
      transferDeadlineDaysLeft: gs.transferWindowDaysLeft,
      transferDeadlineBeforeNextMatch: gs.isTransferDeadlineDay,
      includeSetup: true,
      supporterTrend: gs.supporterTrend,
      rolloverShortfall: gs.rolloverShortfall,
      supporterUltimatumDaysLeft: gs.supporterUltimatumDaysLeft,
    );
    NextAction? contractAction;
    NextAction? staffAction;
    for (final a in actions) {
      switch (a.kind) {
        case NextActionKind.ultimatum:
          add(TodoItem(
            kind: TodoKind.ultimatum,
            level: TodoLevel.must,
            title: Tr.pick('サポーターの最後通告が出ています',
                'The supporters have issued a final warning'),
            note: a.message,
            place: TodoPlaces.ownerFans,
          ));
        case NextActionKind.rolloverShortfall:
          add(TodoItem(
            kind: TodoKind.rolloverShortfall,
            level: TodoLevel.must,
            title: Tr.pick('季の切り替えで資金が足りなくなります',
                'You will run short at the season changeover'),
            note: a.message,
            place: TodoPlaces.financeFunding,
          ));
        case NextActionKind.budgetNegative:
          add(TodoItem(
            kind: TodoKind.budgetNegative,
            level: TodoLevel.must,
            title: Tr.pick('資金がマイナスです', 'You are in the red'),
            note: Tr.pick('放っておくと株主の期待が下がります。売却・借入・オーナーの仕事の非常手段で戻します。',
                'Shareholder expectation falls while it lasts. Sell, borrow, or use an emergency move.'),
            place: TodoPlaces.financeFunding,
          ));
        case NextActionKind.supporterFalling:
          add(TodoItem(
            kind: TodoKind.supporterFalling,
            level: a.urgent ? TodoLevel.must : TodoLevel.recommended,
            title:
                Tr.pick('サポーターの期待が下がっています', 'Supporter expectation is falling'),
            note: a.message,
            place: TodoPlaces.ownerFans,
          ));
        case NextActionKind.transferDeadline:
          add(TodoItem(
            kind: TodoKind.transferDeadline,
            level: TodoLevel.recommended,
            title: a.message,
            note: Tr.pick('過ぎると、次の窓まで補強も放出もできません。',
                'After that you cannot buy or sell until the next window.'),
            place: TodoPlaces.transferPicks,
          ));
        case NextActionKind.signingProposals:
          add(TodoItem(
            kind: TodoKind.signingProposals,
            level: TodoLevel.recommended,
            title: Tr.pick(
                '監督から補強の候補が届いています', 'Your manager has signing candidates'),
            note: Tr.pick('買うか見送るかを決めます。', 'Sign them or pass.'),
            place: TodoPlaces.transferPicks,
          ));
        case NextActionKind.youthAtRisk:
          add(TodoItem(
            kind: TodoKind.youthAtRisk,
            level: TodoLevel.recommended,
            title: Tr.pick('ユースの有望株が出ていきそうです', 'An academy prospect may leave'),
            note: a.message,
            place: TodoPlaces.clubYouth,
          ));
        case NextActionKind.contractExpiring:
          contractAction = a;
        case NextActionKind.staffVacant:
          staffAction = a;
        // 受信箱の行と同じ用件は上で挙げてある。オーナーの目標は、開幕前に
        // 限らず下で挙げる。
        case NextActionKind.ownerGoal:
        case NextActionKind.incomingOffer:
        case NextActionKind.sponsor:
          break;
      }
    }

    // ---- どこにも出ていなかったもの ----

    // スタッフの空席。開幕前に限らず、候補がいれば挙げる。
    final vacant = [
      for (final r in StaffRole.values)
        if (save.infrastructure.staffFor(r) == null &&
            gs.staffCandidatesFor(r).isNotEmpty)
          r,
    ];
    if (vacant.isNotEmpty || staffAction != null) {
      add(TodoItem(
        kind: TodoKind.staffVacant,
        level: TodoLevel.recommended,
        title: Tr.pick(
            'スタッフに空席があります',
            vacant.length == 1
                ? 'A staff post is empty'
                : 'Staff posts are empty'),
        // 題と同じことを繰り返さないよう、空いている役の名前を出す。
        note: vacant.isEmpty
            ? (staffAction?.message ?? '')
            : Tr.pick(
                '空いている役: ${vacant.map((r) => r.label).join('・')}。候補から雇えます。',
                'Empty: ${vacant.map((r) => r.label).join(', ')}. Candidates are waiting.'),
        place: TodoPlaces.clubStaff,
        count: vacant.isEmpty ? 1 : vacant.length,
      ));
    }

    // オーナーの目標。開幕前に限らず、未設定なら挙げる。
    if (save.ownerGoal == null && gs.selectableOwnerGoals.isNotEmpty) {
      add(TodoItem(
        kind: TodoKind.ownerGoal,
        level: TodoLevel.recommended,
        title: Tr.pick('オーナーの目標が未設定です', 'No owner goal is set'),
        note: Tr.pick('決めると、達成が殿堂に残ります(売却後も消えません)。',
            'Achieving one puts it in the hall of fame, even after a sale.'),
        place: TodoPlaces.ownerGoal,
      ));
    }

    // 開幕前だけの決めごと。
    if (gs.canSellSeasonTickets) {
      add(TodoItem(
        kind: TodoKind.seasonTickets,
        level: TodoLevel.recommended,
        title: Tr.pick('年間シートを売れます', 'You can sell season tickets'),
        note: Tr.pick('開幕前だけ。入場券の一部を先にまとめて売って、いまお金を入れられます。',
            'Only before the season starts: sell part of your tickets up front for cash now.'),
        place: TodoPlaces.clubCommunity,
      ));
    }
    if (gs.canChangeClubPolicy) {
      add(TodoItem(
        kind: TodoKind.clubPolicy,
        level: TodoLevel.recommended,
        title: Tr.pick('クラブの方針を選べます', 'You can set the club policy'),
        note: Tr.pick('変えられるのはオフシーズン(季の終わり〜開幕前)だけ(いまは「${gs.nextClubPolicy.label}」)。季末に採点されます。',
            'Only in the off-season, from the end of the season to kick-off (now: ${gs.nextClubPolicy.label}). Scored at the end.'),
        // 方針はオーナー室の「文化と方針」にある(2026-11-25)。
        place: TodoPlaces.ownerWorld,
      ));
    }

    // 監督からの提案(契約更新・ユース昇格)。
    if (save.proposals.isNotEmpty) {
      final n = save.proposals.length;
      add(TodoItem(
        kind: TodoKind.managerProposals,
        level: TodoLevel.recommended,
        title: Tr.pick(
            '監督からの提案(契約更新・昇格)が$n件',
            "${Tr.plural(n, 'proposal')} from your manager (renewals & promotions)"),
        note: Tr.pick(
            '${save.proposals.map((p) => '${p.kind.label}: ${p.playerName}').join('、')}。承認か却下を決めます。',
            '${save.proposals.map((p) => '${p.kind.label}: ${p.playerName}').join(', ')}. Approve or decline.'),
        place: TodoPlaces.financeOverview,
        count: n,
      ));
    }

    // 枠ごとのスポンサーと命名権。結ぶだけで収入が増える。
    final slotOffers = SponsorSlot.values
        .where(
            (s) => gs.slotSponsor(s) == null && gs.slotSponsorOffer(s) != null)
        .length;
    final naming =
        save.namingDeal == null && save.pendingNamingOffers.isNotEmpty ? 1 : 0;
    if (slotOffers + naming > 0) {
      add(TodoItem(
        kind: TodoKind.sponsorSlots,
        level: TodoLevel.recommended,
        title: naming > 0 && slotOffers > 0
            ? Tr.pick('スポンサー枠と命名権の話が届いています',
                'Offers for sponsor slots and naming rights')
            : naming > 0
                ? Tr.pick('スタジアムの命名権の話が届いています', 'Naming-rights offers are in')
                : Tr.pick('空いているスポンサー枠に提示が$slotOffers件',
                    '${Tr.plural(slotOffers, 'offer')} for empty sponsor slots'),
        note: Tr.pick('結ぶと毎節の収入が増えます。', 'Signing adds income every matchday.'),
        place: TodoPlaces.financeFunding,
        count: slotOffers + naming,
      ));
    }

    // 更新の時期の選手。いま更新を申し込める選手だけ数える。
    final renewable = ContractBoardEngine.expiring(team)
        .where((p) =>
            save.budget >=
                ContractEngine.renewalCost(p) +
                    ContractEngine.signingBonusFor(p) &&
            gs.renewalBlockReason(p) == null)
        .length;
    if (renewable > 0 || contractAction != null) {
      add(TodoItem(
        kind: TodoKind.contractRenewals,
        level: TodoLevel.recommended,
        title: renewable > 0
            ? Tr.pick('更新の時期の選手が$renewable人',
                '${Tr.plural(renewable, 'player')} due for renewal')
            : Tr.pick('主力の契約が切れかけています', 'A key contract is running out'),
        note: contractAction?.message ??
            Tr.pick('契約が切れると無償で去ります。更新するか、売るかを決めます。',
                'They leave for nothing when the deal ends. Renew or sell.'),
        place: TodoPlaces.squadContracts,
        count: renewable > 0 ? renewable : 1,
      ));
    }

    // 今月の広報(月に1回)。資金が足りる手があるときだけ。
    if (!gs.fanWorkDoneThisMonth &&
        ownerWorks.any((w) => w.monthly && gs.canDoOwnerWork(w))) {
      add(TodoItem(
        kind: TodoKind.monthlyPr,
        level: TodoLevel.recommended,
        title: Tr.pick('今月の広報がまだです', "This month's PR move is still open"),
        note: Tr.pick('広報・ファンの手は月に1回。サポーターの期待を上げられます。',
            'One fans & PR move a month. It lifts supporter expectation.'),
        place: TodoPlaces.ownerFans,
      ));
    }

    // 次の節の試合日のイベント。資金が足りるものがあるときだけ。
    final seasonOn = !save.league.isSeasonComplete &&
        save.league.nextUnplayedFixture != null;
    // 「続ける」に決めてあれば出さない(資金が足りない節は打たないだけ)。
    if (seasonOn &&
        gs.activeMatchdayPromo == null &&
        gs.matchdayPromoKeep == null &&
        matchdayPromos.any((p) => gs.scaledMoney(p.cost) <= save.budget)) {
      add(TodoItem(
        kind: TodoKind.matchdayEvent,
        level: TodoLevel.recommended,
        title: Tr.pick('試合日のイベントを決めていません',
            'No matchday event is set'),
        note: Tr.pick('観客収入かサポーターの期待を動かせます。一度決めると毎節続けます。',
            'Moves gate income or supporter expectation. Set it once and it runs every game.'),
        place: TodoPlaces.ownerMatchday,
      ));
    }

    // 仮契約を話せる時期(まだ1件も結んでいないあいだだけ)。
    if (gs.preContractWindowOpen &&
        gs.incomingPreContracts.isEmpty &&
        gs.preContractTargets(limit: 1).isNotEmpty) {
      add(TodoItem(
        kind: TodoKind.preContracts,
        level: TodoLevel.recommended,
        title: Tr.pick('仮契約を話せる時期です', 'Pre-contracts are open'),
        note: Tr.pick('今季末で契約が切れる他のクラブの選手を、移籍金なしで来季に迎えられます(6月30日まで)。',
            'Sign players whose deals end this summer for no fee, to join next season (until 30 June).'),
        place: TodoPlaces.squadContracts,
      ));
    }

    // 増築できる施設(上限でなく、工事中でなく、資金が足りる)。
    final buildable = [
      for (final t in FacilityType.values)
        if (save.infrastructure.facilityLevel(t) <
                ClubInfrastructure.maxLevel &&
            save.infrastructure.constructionReadyOn(t) == null &&
            save.budget >= gs.facilityUpgradeCostFor(t))
          t,
    ];
    if (buildable.isNotEmpty) {
      add(TodoItem(
        kind: TodoKind.facilities,
        level: TodoLevel.recommended,
        title: Tr.pick('増築できる施設が${buildable.length}つ',
            '${Tr.plural(buildable.length, 'facility', 'facilities')} can be upgraded'),
        note: Tr.pick(
            '${buildable.map((t) => t.label).join('・')}。いちばん安いもので${formatMoney(buildable.map(gs.facilityUpgradeCostFor).reduce((a, b) => a < b ? a : b))}。',
            '${buildable.map((t) => t.label).join(', ')}. From ${formatMoney(buildable.map(gs.facilityUpgradeCostFor).reduce((a, b) => a < b ? a : b))}.'),
        place: TodoPlaces.clubFacilities,
        count: buildable.length,
      ));
    }

    // 今季まだ打てるオーナーの手(広報は上で別に挙げる)。1件ずつは並べない。
    final works =
        ownerWorks.where((w) => !w.monthly && gs.canDoOwnerWork(w)).length;
    if (works > 0) {
      add(TodoItem(
        kind: TodoKind.ownerWorks,
        level: TodoLevel.recommended,
        title: Tr.pick('今季まだ打てるオーナーの手が$works件',
            '${Tr.plural(works, 'owner move')} still open this season'),
        note: Tr.pick('資金と2つの期待を動かす手。それぞれ1シーズンに1回です。',
            'Moves that shift funds and the two expectations. Once a season each.'),
        place: TodoPlaces.ownerWorks,
        count: works,
      ));
    }

    // 並べる順は種類の順(必須が先)。同じ重さの中は [TodoKind] の順。
    items.sort((a, b) {
      final l = a.level.index.compareTo(b.level.index);
      return l != 0 ? l : a.kind.index.compareTo(b.kind.index);
    });
    return items;
  }
}
