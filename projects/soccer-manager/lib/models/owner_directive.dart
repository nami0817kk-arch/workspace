import '../l10n/tr.dart';
import 'team.dart';

/// オーナーが監督に出す、次の節への一言の指示。勝負の試合を宣言しなくても、
/// 構えだけは伝えられる。節を終えると使い切る。
enum OwnerDirective { attack, allOut, defend, parkTheBus }

extension OwnerDirectiveInfo on OwnerDirective {
  String get label => switch (this) {
        OwnerDirective.attack => Tr.pick('攻めろ', 'Attack'),
        OwnerDirective.allOut => Tr.pick('総攻撃', 'All-out attack'),
        OwnerDirective.defend => Tr.pick('守りを固めろ', 'Defend'),
        OwnerDirective.parkTheBus => Tr.pick('徹底して守れ', 'Park the bus'),
      };

  String get description => switch (this) {
        OwnerDirective.attack => Tr.pick('攻撃的な構えで臨む。得点も失点も増えやすい。',
            'Go on the front foot. More goals, for and against.'),
        OwnerDirective.allOut => Tr.pick('全員で攻める。勝つしかない試合に。守りは大きく薄くなる。',
            'Everyone forward. For must-win games; the defence is wide open.'),
        OwnerDirective.defend => Tr.pick('守備的な構えで臨む。失点を抑えるが、点は取りにくい。',
            'Sit deeper. Concede less, score less.'),
        OwnerDirective.parkTheBus => Tr.pick('引き分け以上を狙う構え。攻撃はほとんど捨てる。',
            'Play for a point. Attack is almost abandoned.'),
      };

  /// 監督が取る構え。
  TeamMentality get mentality => switch (this) {
        OwnerDirective.attack => TeamMentality.attacking,
        OwnerDirective.allOut => TeamMentality.veryAttacking,
        OwnerDirective.defend => TeamMentality.defensive,
        OwnerDirective.parkTheBus => TeamMentality.veryDefensive,
      };
}
