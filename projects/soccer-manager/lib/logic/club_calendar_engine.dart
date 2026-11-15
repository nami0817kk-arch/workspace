import '../l10n/tr.dart';

/// 年間予定の種類。
enum ClubEventKind { window, budget, incident, season }

/// クラブ運営の年間予定の1件。
class ClubEvent {
  const ClubEvent({
    required this.matchday,
    required this.kind,
    required this.title,
    required this.detail,
  });

  /// この節の前後に起きる(0 は開幕前、シーズン終了後は total+1)。
  final int matchday;
  final ClubEventKind kind;
  final String title;
  final String detail;
}

/// 1シーズンの、クラブ運営の年間カレンダーを作る。現実のクラブが
/// 年間で回す仕事(移籍期間・予算の確定・決算・総会)を、節に並べる。
///
/// 移籍ウィンドウ・事件の節は、ゲームの規則と同じ式で出す(GameState の
/// isTransferWindowOpen と isOwnerEventMatchday)。
class ClubCalendarEngine {
  const ClubCalendarEngine._();

  /// 中間の移籍ウィンドウの最初の節。
  static int midWindowStart(int total) => total ~/ 2;

  /// 事件が起きる節(12節ごと、6・18・30節)。
  static bool isIncidentMatchday(int matchday) =>
      matchday > 0 && matchday % 12 == 6;

  static List<ClubEvent> build({required int totalMatchdays}) {
    final total = totalMatchdays;
    final mid = midWindowStart(total);
    final events = <ClubEvent>[
      ClubEvent(
        matchday: 0,
        kind: ClubEventKind.window,
        title: Tr.pick('夏の移籍期間(開幕前)', 'Pre-season transfer window'),
        detail: Tr.pick('開幕までに補強と放出を済ませる。開幕で閉まる。',
            'Finish signings and sales before kickoff. It shuts at the start.'),
      ),
      ClubEvent(
        matchday: 0,
        kind: ClubEventKind.budget,
        title: Tr.pick('年の予算を決める', 'Set the annual budget'),
        detail: Tr.pick('補強・育成・施設・営業・配当の配分を確定する。',
            'Fix the split between signings, youth, facilities, sales and dividends.'),
      ),
      for (var md = 1; md <= total; md++)
        if (isIncidentMatchday(md))
          ClubEvent(
            matchday: md,
            kind: ClubEventKind.incident,
            title: Tr.pick('事件の判断(第$md節)', 'Incident decision (MD $md)'),
            detail: Tr.pick('移籍要求・スポンサー撤退など、オーナーの判断が要る。',
                'Transfer demands, sponsor exits and similar calls for the owner.'),
          ),
      if (mid >= 1 && mid <= total)
        ClubEvent(
          matchday: mid,
          kind: ClubEventKind.window,
          title: Tr.pick('冬の移籍期間(第$mid〜${mid + 2}節)', 'Winter window (MD $mid-${mid + 2})'),
          detail: Tr.pick('補強の追加と、不要な選手の放出ができる。',
              'Add signings and move on players you do not need.'),
        ),
      ClubEvent(
        matchday: total + 1,
        kind: ClubEventKind.season,
        title: Tr.pick('決算とライセンスの審査', 'Accounts and licence review'),
        detail: Tr.pick('財務の規則を満たすか審査される。違反は罰金・補強禁止・勝ち点剥奪。',
            'Financial rules are checked. Breaches bring fines, signing bans or point deductions.'),
      ),
      ClubEvent(
        matchday: total + 1,
        kind: ClubEventKind.season,
        title: Tr.pick('株主総会と配当', 'Shareholder meeting and dividend'),
        detail: Tr.pick('配当・増資・返済を決める。期待が足りなければ叱責される。',
            'Decide dividends, capital raises and repayments.'),
      ),
      ClubEvent(
        matchday: total + 1,
        kind: ClubEventKind.season,
        title: Tr.pick('昇降格と契約満了', 'Promotion, relegation and expiries'),
        detail: Tr.pick('契約が切れる選手は無償で去る。主力は更新を。',
            'Players out of contract leave for free. Renew your key men.'),
      ),
    ];
    events.sort((a, b) => a.matchday.compareTo(b.matchday));
    return events;
  }
}
