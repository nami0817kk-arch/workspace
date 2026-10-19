import 'childhood.dart';
import 'game.dart';
import 'marks.dart';

/// 引退後のひとこと。結果(称号・プロ年数・結婚・二刀流・ライバル)から選ぶ。
/// 乱数は使わず、同じ一生なら同じ文になる(共有しても同じ)。
String epilogueOf(Ending e, String name,
    {int worldChampion = 0,
    int worldPlayed = 0,
    int overseasYears = 0,
    int popularity = 0,
    int? retiredNumber,
    Map<String, int> childhood = const {}}) {
  final parts = <String>[];
  if (!e.madePro) {
    parts.add('$nameはプロの舞台には立てなかったが、野球で学んだことを胸に、新しい道を歩き始めた。');
  } else {
    parts.add(switch (e.title) {
      'レジェンド' => '$nameの名は、野球の歴史に長く語り継がれることになった。',
      '一流選手' => '$nameは、ファンの記憶に残る一流選手として、バットとグラブを置いた。',
      'レギュラー' => '$nameは、チームを支えた選手として、静かにユニフォームを脱いだ。',
      _ => '$nameは、${e.proYears}年間をやりきって、ユニフォームを脱いだ。',
    });
    if (e.wasTwoWay) {
      parts.add('二刀流に挑んだ姿は、多くの子どもたちの憧れになった。');
    }
    if (e.rivalWins + e.rivalLosses >= 5) {
      parts.add(e.rivalWins > e.rivalLosses
          ? '最後まで競い合ったライバルとの勝負は、勝ち越しで終えた。'
          : 'ライバルとの勝負は負け越したが、互いを高め合った日々は宝物だ。');
    }
  }
  // 幼いころの選択(憧れ・卒団の夢)を、結果とつなげる。
  final idol = childhood['kid-idol'];
  if (e.madePro && idol != null) {
    parts.add(
        '幼いころ、${childhoodStepById('kid-idol')!.notes[idol]}。その憧れは、最後まで$nameの原点だった。');
  }
  final dream = childhood['kid-dream'];
  if (dream == 0 && e.madePro) {
    parts.add('卒団の日に語った「プロ野球選手になる」という夢を、$nameは本当に叶えた。');
  } else if (dream == 1 && worldChampion > 0) {
    parts.add('卒団の日に語った「世界一」という夢を、$nameは本当に叶えた。');
  } else if (dream == 2 && e.madePro && e.proYears >= 15) {
    parts.add('卒団の日に語った「ずっと野球を楽しむ」という夢のとおり、$nameは長く野球を楽しみ続けた。');
  }
  if (retiredNumber != null && e.title == 'レジェンド' && e.proYears >= 15) {
    parts.add('背番号$retiredNumberは、永久欠番になった。');
  }
  if (e.madePro && popularity >= 70) {
    parts.add('引退セレモニーには満員のファンが詰めかけ、$nameは花束と大きな拍手に包まれた。');
  }
  if (overseasYears > 0) {
    parts.add('海を渡ってアメリカでも$overseasYears年戦った経験は、$nameを一回り大きくした。');
  }
  if (worldChampion > 0) {
    parts.add('日の丸を背負って世界一になった経験は、$nameの何よりの誇りだ。');
  } else if (worldPlayed > 0) {
    parts.add('日本代表として世界と戦った日々は、$nameの野球人生の勲章になった。');
  }
  if (e.married) {
    final kids = childrenOf(e.partnerName!);
    parts.add('引退後は、${e.partnerName}と$kids人の子どもに囲まれて、穏やかな毎日を送っている。');
  } else if (e.madePro && e.proYears >= 10) {
    parts.add('引退後は、少年野球の子どもたちに教える日々が待っている。');
  }
  return parts.join('\n');
}
