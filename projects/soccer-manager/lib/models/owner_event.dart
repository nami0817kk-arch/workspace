import '../l10n/tr.dart';

/// オーナーの判断を迫る事件。どの選択も、サポーターか株主のどちらかを傷つける。
enum OwnerEventKind {
  /// エースが移籍を要求する。
  transferDemand,

  /// スポンサーが撤退をほのめかす。
  sponsorExit,

  /// 監督と主力選手が対立する。
  managerClash,

  /// スタジアムが老朽化する。
  stadiumAging,
}

/// 事件への1つの答え。期待の増減と、資金の増減(万円)。
class OwnerEventOption {
  final String label;
  final int supportersDelta;
  final int shareholdersDelta;
  final int fundsDelta;

  const OwnerEventOption({
    required this.label,
    required this.supportersDelta,
    required this.shareholdersDelta,
    this.fundsDelta = 0,
  });
}

extension OwnerEventInfo on OwnerEventKind {
  String get title => switch (this) {
        OwnerEventKind.transferDemand =>
          Tr.pick('エースが移籍を要求', 'Your ace demands a transfer'),
        OwnerEventKind.sponsorExit =>
          Tr.pick('スポンサーが撤退をほのめかす', 'A sponsor hints at pulling out'),
        OwnerEventKind.managerClash =>
          Tr.pick('監督と主力が対立', 'Manager and a key player clash'),
        OwnerEventKind.stadiumAging =>
          Tr.pick('スタジアムが老朽化', 'The stadium is showing its age'),
      };

  String get body => switch (this) {
        OwnerEventKind.transferDemand => Tr.pick(
            '他クラブの誘いを受けたエースが、移籍を求めています。残すか、手放すか。',
            'Courted by another club, your ace wants out. Keep him or cash in?'),
        OwnerEventKind.sponsorExit => Tr.pick(
            '成績への不満から、主要スポンサーが契約の見直しを求めています。',
            'Unhappy with results, a main sponsor wants to renegotiate.'),
        OwnerEventKind.managerClash => Tr.pick(
            '起用をめぐって、監督と主力選手が衝突しました。どちらの肩を持ちますか。',
            'A row over selection has split the manager and a key player. Whose side are you on?'),
        OwnerEventKind.stadiumAging => Tr.pick(
            '観客席の一部が危険だと指摘されました。改修するか、先送りするか。',
            'Part of the stands has been flagged as unsafe. Renovate or postpone?'),
      };

  List<OwnerEventOption> get options => switch (this) {
        OwnerEventKind.transferDemand => [
            OwnerEventOption(
                label: Tr.pick('慰留して残す(昇給を約束)', 'Keep him with a raise'),
                supportersDelta: 4,
                shareholdersDelta: -5),
            OwnerEventOption(
                label: Tr.pick('売却を認める(+800万円)', 'Let him go (+800)'),
                supportersDelta: -6,
                shareholdersDelta: 4,
                fundsDelta: 800),
          ],
        OwnerEventKind.sponsorExit => [
            OwnerEventOption(
                label: Tr.pick('違約金を払って引き止める(-600万円)', 'Pay to keep them (-600)'),
                supportersDelta: 0,
                shareholdersDelta: -2,
                fundsDelta: -600),
            OwnerEventOption(
                label: Tr.pick('条件を下げて継続(株主が不満)', 'Accept worse terms'),
                supportersDelta: 2,
                shareholdersDelta: -5),
          ],
        OwnerEventKind.managerClash => [
            OwnerEventOption(
                label: Tr.pick('監督を支持する', 'Back the manager'),
                supportersDelta: -4,
                shareholdersDelta: 2),
            OwnerEventOption(
                label: Tr.pick('選手を支持する', 'Back the player'),
                supportersDelta: 4,
                shareholdersDelta: -3),
          ],
        OwnerEventKind.stadiumAging => [
            OwnerEventOption(
                label: Tr.pick('全面改修する(-1200万円)', 'Renovate fully (-1200)'),
                supportersDelta: 5,
                shareholdersDelta: -4,
                fundsDelta: -1200),
            OwnerEventOption(
                label: Tr.pick('応急処置で済ます', 'Patch it up'),
                supportersDelta: -4,
                shareholdersDelta: 3),
          ],
      };
}
