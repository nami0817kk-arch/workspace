import 'game.dart';
import 'history_lines.dart';

/// 歴史が動いた知らせ（2026-11-25）。
///
/// 選んだ手で世界線（`worldLine`）や小さな分岐（`kSmallBranchNames` の旗）が変わった瞬間に、
/// 「歴史が動いた」のカードで、この先の世がどう違うかを一言で伝える。
/// `Game.choose` が選ぶ前と後の [historyKeys] を比べ、増えたものを `Game.historyShift` に置く。
/// 画面はそれを見て一度だけ出す（次の手を選ぶか、閉じれば消える）。

/// 変わった歴史の一つ。[title] は何が変わったか（`changedHistory` の一文と同じ）、[text] はこの先の世の一言。
class HistoryShift {
  const HistoryShift(this.key, this.title, this.text);
  final String key, title, text;
}

/// この先の世がどう違うか（世界線の名と、小さな分岐の旗をキーに）。
const kHistoryShiftNotes = <String, String>{
  'imagawa': '今川の大軍が尾張を呑み、やがて都へ上る。織田信長の天下は、この世には来ない。',
  'nobunaga': '信長は本能寺を生き延びた。羽柴秀吉の天下は来ず、織田の天下が続いていく。',
  'akechi': '光秀の天下は三日では終わらない。秀吉は西へ退き、天下は明智のもとで別の道を行く。',
  'west': '徳川の幕府は開かれない。豊臣の世が、秀頼のもとでなお続いていく。',
  'history_nagashino': '武田の騎馬は無傷のまま甲斐へ帰る。織田の甲州攻めは、この世では実らない。',
  'history_odawara': '北条の家は相模に残る。徳川の幕府は、江戸ではなく駿府に開かれる。',
  'history_kawanakajima': '甲斐の虎は川中島に斃れた。信玄のいない戦国が、ここから始まる。',
};

/// いまの世で変わっている歴史のキー（史実どおりでない世界線の名と、立っている小さな分岐の旗）。
List<String> historyKeys(Game g) => [
  if (worldLine(g) != 'real') worldLine(g),
  for (final k in kSmallBranchNames.keys)
    if (g.hasFlag(k)) k,
];

/// 選ぶ前のキー [before] と比べて、新しく変わった歴史（なければ null。二つ同時なら先のもの）。
HistoryShift? newHistoryShift(Game g, List<String> before) {
  for (final k in historyKeys(g)) {
    if (before.contains(k)) continue;
    final title = kLineNames[k] ?? kSmallBranchNames[k] ?? k;
    return HistoryShift(
      k,
      title,
      kHistoryShiftNotes[k] ?? 'あなたの選択で、歴史は史実と別の道を歩み始めた。',
    );
  }
  return null;
}
