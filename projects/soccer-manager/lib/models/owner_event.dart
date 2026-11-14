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

  /// サポーターの代表が、チケット価格と応援の席について会合を求める。
  supporterMeeting,

  /// 他クラブが、監督を引き抜こうとする。
  managerPoach,

  /// ライバルクラブが、記者会見で挑発してくる。
  rivalProvocation,

  /// 地元の自治体が、スタジアム周辺の再開発への出資を持ちかける。
  townRedevelopment,
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
        OwnerEventKind.supporterMeeting =>
          Tr.pick('サポーター会合', 'Supporters\' meeting'),
        OwnerEventKind.managerPoach =>
          Tr.pick('監督に引き抜きの話', 'Another club courts your manager'),
        OwnerEventKind.rivalProvocation =>
          Tr.pick('ライバルが挑発', 'The rivals taunt you'),
        OwnerEventKind.townRedevelopment =>
          Tr.pick('街の再開発の誘い', 'A town redevelopment offer'),
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
        OwnerEventKind.supporterMeeting => Tr.pick(
            'サポーターの代表が、チケットの値下げと応援席の拡大を求めています。',
            'Supporter leaders want cheaper tickets and a bigger standing section.'),
        OwnerEventKind.managerPoach => Tr.pick(
            '他クラブが、あなたの監督に高い条件を示しています。引き止めますか。',
            'Another club is offering your manager a big deal. Will you keep him?'),
        OwnerEventKind.rivalProvocation => Tr.pick(
            'ライバルの会長が「次の対戦は負けない」と公言しました。どう応えますか。',
            'The rival chairman says they will not lose the next meeting. How do you respond?'),
        OwnerEventKind.townRedevelopment => Tr.pick(
            '自治体が、スタジアム周辺の再開発への出資を求めています。',
            'The town asks you to invest in redeveloping the area around the stadium.'),
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
        OwnerEventKind.supporterMeeting => [
            OwnerEventOption(
                label: Tr.pick('要望を受け入れる(-300万円)', 'Accept (-300)'),
                supportersDelta: 6,
                shareholdersDelta: -3,
                fundsDelta: -300),
            OwnerEventOption(
                label: Tr.pick('現状の価格で理解を求める', 'Hold firm and explain'),
                supportersDelta: -3,
                shareholdersDelta: 3),
          ],
        OwnerEventKind.managerPoach => [
            OwnerEventOption(
                label: Tr.pick('報酬を上げて引き止める(-400万円)', 'Raise his pay (-400)'),
                supportersDelta: 3,
                shareholdersDelta: -2,
                fundsDelta: -400),
            OwnerEventOption(
                label: Tr.pick('違約金を受け取って送り出す(+500万円)', 'Let him go (+500)'),
                supportersDelta: -5,
                shareholdersDelta: 3,
                fundsDelta: 500),
          ],
        OwnerEventKind.rivalProvocation => [
            OwnerEventOption(
                label: Tr.pick('強気で応じる', 'Fire back'),
                supportersDelta: 5,
                shareholdersDelta: -2),
            OwnerEventOption(
                label: Tr.pick('相手にしない', 'Ignore it'),
                supportersDelta: -2,
                shareholdersDelta: 2),
          ],
        OwnerEventKind.townRedevelopment => [
            OwnerEventOption(
                label: Tr.pick('出資する(-800万円)', 'Invest (-800)'),
                supportersDelta: 4,
                shareholdersDelta: -3,
                fundsDelta: -800),
            OwnerEventOption(
                label: Tr.pick('断る', 'Decline'),
                supportersDelta: -2,
                shareholdersDelta: 2),
          ],
      };
}
