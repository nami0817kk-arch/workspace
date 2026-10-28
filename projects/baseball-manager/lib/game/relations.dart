import 'characters.dart';

/// まわりの人への頼みごと。絆が育った相手に、1年に1回ずつ頼める(行動のターンは使わない)。
/// 頼むと絆を少し使う(`favorBondCost`)。絆は交流・友情タッグ・コーチの授業で育つ。
enum Favor {
  practice('自主練に付き合ってもらう', '次の練習・特訓・練習試合・コーチで、必ず友情タッグになる(経験点1.3倍)'),
  meal('差し入れを頼む', '疲れ-25・やる気+5'),
  cheer('応援に来てもらう', 'やる気+15・疲れ-10'),
  private('個別に見てもらう', 'コーチのコツ+1(4つで、教わる特殊能力のコツが最大に)'),
  joint('合同練習を申し込む', '重点の種類の経験点+10・やる気+5');

  const Favor(this.label, this.description);
  final String label;
  final String description;
}

/// その人に頼めること。
Favor favorOf(Kind k) => switch (k) {
      Kind.teammate => Favor.practice,
      Kind.family => Favor.meal,
      Kind.lover => Favor.cheer,
      Kind.coach => Favor.private,
      Kind.rival => Favor.joint,
    };

/// 頼めるようになる絆。ライバルは「切磋琢磨の度合い」なので低め(毎年の勝負で+5ずつ育つ)。
int favorBondLine(Kind k) => k == Kind.rival ? 30 : 50;

/// 頼むと減る絆。
const favorBondCost = 10;

/// 交流の相手に選んだときに増える絆(選ばないときは恋人か家族に+10)。
const socialTargetBond = 12;

/// コーチに教わるたびに増える絆。
const lessonBond = 8;
