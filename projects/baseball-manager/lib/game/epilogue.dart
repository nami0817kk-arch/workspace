import 'game.dart';

/// 引退後のひとこと。結果(称号・プロ年数・結婚・二刀流・ライバル)から選ぶ。
/// 乱数は使わず、同じ一生なら同じ文になる(共有しても同じ)。
String epilogueOf(Ending e, String name) {
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
  if (e.married) {
    parts.add('引退後は、${e.partnerName}と、穏やかな毎日を送っている。');
  } else if (e.madePro && e.proYears >= 10) {
    parts.add('引退後は、少年野球の子どもたちに教える日々が待っている。');
  }
  return parts.join('\n');
}
