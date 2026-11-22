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

  /// 監査法人が、帳簿に懸念を示す。
  auditConcern,

  /// 企業が、スタジアムの命名権に高額を提示する。
  namingOffer,

  /// 他クラブが、ユースの逸材を引き抜こうとする。
  youthPoach,

  /// サポーターが、経営への抗議を行う。
  fanProtest,

  /// 新しいスポンサーが、特別な契約を提案する。
  sponsorProposal,

  /// コーチ陣が、方針をめぐって対立する。
  staffDispute,

  /// 主力が長期離脱し、緊急の補強を求められる。
  injuryCrisis,

  /// 放映権の再交渉の機会が来る。
  broadcastTalks,

  /// 自治体の税制が変わり、スタジアムの負担が増える。
  taxChange,

  /// 経営陣の不祥事が報じられる。
  execScandal,
}

/// 事件への1つの答え。期待の増減と、資金の増減(万円)。
///
/// 資金の増減は元の額(旧5部の規模。economy_scale.dart)で、実際には今いる部の規模に直して動く
/// (GameState.scaledMoney)。だから見出しには額を書かず、画面で添える。
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
        OwnerEventKind.auditConcern =>
          Tr.pick('監査法人が懸念', 'Auditors raise concerns'),
        OwnerEventKind.namingOffer =>
          Tr.pick('命名権の高額オファー', 'A big naming-rights offer'),
        OwnerEventKind.youthPoach =>
          Tr.pick('ユースの逸材に引き抜き', 'A youth gem is being poached'),
        OwnerEventKind.fanProtest => Tr.pick('サポーターが抗議', 'Fans protest'),
        OwnerEventKind.sponsorProposal =>
          Tr.pick('新スポンサーの提案', 'A new sponsor\'s proposal'),
        OwnerEventKind.staffDispute =>
          Tr.pick('コーチ陣が対立', 'The coaching staff are split'),
        OwnerEventKind.injuryCrisis =>
          Tr.pick('主力が長期離脱', 'A key man is out long-term'),
        OwnerEventKind.broadcastTalks =>
          Tr.pick('放映権の再交渉', 'Broadcast talks reopen'),
        OwnerEventKind.taxChange => Tr.pick('税制の変更', 'A tax change'),
        OwnerEventKind.execScandal =>
          Tr.pick('経営陣の不祥事', 'An executive scandal'),
      };

  String get body => switch (this) {
        OwnerEventKind.transferDemand => Tr.pick(
            '他クラブの誘いを受けたエースが、移籍を求めています。残すか、手放すか。',
            'Courted by another club, your ace wants out. Keep him or cash in?'),
        OwnerEventKind.sponsorExit => Tr.pick('成績への不満から、主要スポンサーが契約の見直しを求めています。',
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
        OwnerEventKind.auditConcern => Tr.pick(
            '監査法人が、帳簿の一部に説明を求めています。詳しく調べさせるか、穏便に済ませるか。',
            'The auditors want an explanation of part of the books. Dig deep or smooth it over?'),
        OwnerEventKind.namingOffer => Tr.pick(
            '企業が、スタジアムの命名権に高額を提示しています。長年の呼び名が変わります。',
            'A company is bidding big for the stadium name. The long-used name would change.'),
        OwnerEventKind.youthPoach => Tr.pick('他クラブが、ユースの逸材に違約金つきで声をかけています。',
            'Another club is moving for your best youth prospect, with a release fee.'),
        OwnerEventKind.fanProtest => Tr.pick(
            '補強の少なさに不満を持つサポーターが、スタジアムの外で抗議しています。',
            'Fans unhappy about the lack of signings are protesting outside the ground.'),
        OwnerEventKind.sponsorProposal => Tr.pick(
            '新しいスポンサーが、大きな額と引き換えに、ユニフォームの大幅な変更を求めています。',
            'A new sponsor offers big money in return for a major kit change.'),
        OwnerEventKind.staffDispute => Tr.pick(
            'ヘッドコーチとフィットネスコーチが、練習の方針で対立しています。',
            'The head coach and the fitness coach disagree over training.'),
        OwnerEventKind.injuryCrisis => Tr.pick(
            '主力が長期離脱します。急いで補強するか、いる戦力で乗り切るか。',
            'A key man is out for a long time. Rush a signing or ride it out?'),
        OwnerEventKind.broadcastTalks => Tr.pick(
            '放映権の再交渉が始まりました。強気に出るか、安定を取るか。',
            'Broadcast talks have reopened. Push hard or take security?'),
        OwnerEventKind.taxChange => Tr.pick('自治体の税制が変わり、スタジアムの負担が増えます。',
            'A tax change raises the stadium\'s burden.'),
        OwnerEventKind.execScandal => Tr.pick('経営陣の1人に不祥事が報じられました。処分するか、擁護するか。',
            'One of your executives is caught in a scandal. Punish or defend?'),
      };

  List<OwnerEventOption> get options => switch (this) {
        OwnerEventKind.transferDemand => [
            OwnerEventOption(
                label: Tr.pick('慰留して残す(昇給を約束)', 'Keep him with a raise'),
                supportersDelta: 4,
                shareholdersDelta: -5),
            // 資金は、エースの移籍金(市場価値)が入る。売るのは GameState 側
            // (resolveOwnerEvent)。決まった額をここに書くと、選手が残った
            // まま移籍金だけ入ってしまう。
            OwnerEventOption(
                label: Tr.pick('売却を認める', 'Let him go'),
                supportersDelta: -6,
                shareholdersDelta: 4),
          ],
        OwnerEventKind.sponsorExit => [
            OwnerEventOption(
                label: Tr.pick('違約金を払って引き止める', 'Pay to keep them'),
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
                label: Tr.pick('全面改修する', 'Renovate fully'),
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
                label: Tr.pick('要望を受け入れる', 'Accept'),
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
                label: Tr.pick('報酬を上げて引き止める', 'Raise his pay'),
                supportersDelta: 3,
                shareholdersDelta: -2,
                fundsDelta: -400),
            OwnerEventOption(
                label: Tr.pick('違約金を受け取って送り出す', 'Let him go'),
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
                label: Tr.pick('出資する', 'Invest'),
                supportersDelta: 4,
                shareholdersDelta: -3,
                fundsDelta: -800),
            OwnerEventOption(
                label: Tr.pick('断る', 'Decline'),
                supportersDelta: -2,
                shareholdersDelta: 2),
          ],
        OwnerEventKind.auditConcern => [
            OwnerEventOption(
                label: Tr.pick('徹底的に調べさせる', 'Order a full review'),
                supportersDelta: -1,
                shareholdersDelta: 5,
                fundsDelta: -250),
            OwnerEventOption(
                label: Tr.pick('穏便に済ませる', 'Smooth it over'),
                supportersDelta: 1,
                shareholdersDelta: -5),
          ],
        OwnerEventKind.namingOffer => [
            OwnerEventOption(
                label: Tr.pick('受ける', 'Accept'),
                supportersDelta: -5,
                shareholdersDelta: 3,
                fundsDelta: 900),
            OwnerEventOption(
                label: Tr.pick('断って伝統を守る', 'Refuse, keep the name'),
                supportersDelta: 4,
                shareholdersDelta: -3),
          ],
        OwnerEventKind.youthPoach => [
            OwnerEventOption(
                label: Tr.pick('違約金を受けて送り出す', 'Sell him'),
                supportersDelta: -3,
                shareholdersDelta: 3,
                fundsDelta: 400),
            OwnerEventOption(
                label: Tr.pick('プロ契約で引き止める', 'Tie him down'),
                supportersDelta: 3,
                shareholdersDelta: -2,
                fundsDelta: -200),
          ],
        OwnerEventKind.fanProtest => [
            OwnerEventOption(
                label: Tr.pick('補強予算の増額を約束する', 'Promise more for signings'),
                supportersDelta: 5,
                shareholdersDelta: -4),
            OwnerEventOption(
                label: Tr.pick('方針は変えないと説明する', 'Explain, no change'),
                supportersDelta: -4,
                shareholdersDelta: 2),
          ],
        OwnerEventKind.sponsorProposal => [
            OwnerEventOption(
                label: Tr.pick('受ける', 'Accept'),
                supportersDelta: -3,
                shareholdersDelta: 4,
                fundsDelta: 700),
            OwnerEventOption(
                label: Tr.pick('断る', 'Decline'),
                supportersDelta: 2,
                shareholdersDelta: -3),
          ],
        OwnerEventKind.staffDispute => [
            OwnerEventOption(
                label: Tr.pick('ヘッドコーチの方針を採る', 'Back the head coach'),
                supportersDelta: 2,
                shareholdersDelta: -1),
            OwnerEventOption(
                label: Tr.pick('両者を呼んで折衷案', 'Broker a compromise'),
                supportersDelta: -1,
                shareholdersDelta: 2,
                fundsDelta: -100),
          ],
        OwnerEventKind.injuryCrisis => [
            OwnerEventOption(
                label: Tr.pick('緊急補強する', 'Sign cover'),
                supportersDelta: 4,
                shareholdersDelta: -2,
                fundsDelta: -600),
            OwnerEventOption(
                label: Tr.pick('いる戦力で乗り切る', 'Make do'),
                supportersDelta: -3,
                shareholdersDelta: 2),
          ],
        OwnerEventKind.broadcastTalks => [
            OwnerEventOption(
                label: Tr.pick('強気で交渉する', 'Push hard'),
                supportersDelta: -1,
                shareholdersDelta: 4,
                fundsDelta: 300),
            OwnerEventOption(
                label: Tr.pick('長期の安定契約を取る', 'Take a long, safe deal'),
                supportersDelta: 2,
                shareholdersDelta: -2),
          ],
        OwnerEventKind.taxChange => [
            OwnerEventOption(
                label: Tr.pick('負担を受け入れる', 'Absorb it'),
                supportersDelta: 1,
                shareholdersDelta: -3,
                fundsDelta: -350),
            OwnerEventOption(
                label: Tr.pick('チケット代に転嫁する', 'Pass it to ticket prices'),
                supportersDelta: -4,
                shareholdersDelta: 2),
          ],
        OwnerEventKind.execScandal => [
            OwnerEventOption(
                label: Tr.pick('厳正に処分する', 'Punish firmly'),
                supportersDelta: 4,
                shareholdersDelta: -3),
            OwnerEventOption(
                label: Tr.pick('擁護して沈静化を待つ', 'Defend and wait it out'),
                supportersDelta: -5,
                shareholdersDelta: 2),
          ],
      };
}
