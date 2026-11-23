import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'widgets.dart';

/// 用語の説明（辞書）。画面の用語の横の「i」を押すと、ここの文を小窓で出す。
/// 鍵は用語の id、値は（用語・説明）。どちらも日本語で持ち、英語は lib/l10n/ui_en.dart に置く
const Map<String, (String, String)> glossary = {
  'ap': ('手@@term', '1か月にできる行動の数です。金色の四角が今月の残りで、月が替わると元に戻ります。事業が増えると、使える手も増えます。'),
  'share': ('シェア@@term', 'その業種の市場のうち、あなたの事業が取っている割合です。店・商品・人・責任者の力を、競争相手と比べて決まります。売上は「市場の大きさ×シェア」です。'),
  'crew': ('現場の力@@term', '店や工場を動かす人手が足りているかを表します。100%なら全部が動きます。90%を切ると一部が止まり、止まった分はほとんど稼ぎません。「現場の人を増やす」で上がります。'),
  'upkeep': ('維持費@@term', '店・工場と現場の人に、毎月かかるお金です。増やすほど上がり、売上が落ちても減りません。事業の利益から引かれます。'),
  'early': ('先行者@@term', '業種が生まれて3年以内に始めた事業に付きます。始めてから5年のあいだ、店・商品・広告などの打ち手がふだんの1.6倍よく効きます。'),
  'scale': ('規模の利益@@term', '1つの事業を5か国以上に出すと、利益率が上がります。5か国目から1か国ごとに＋6%、最大で＋50%です。'),
  'model': ('稼ぎ方@@term', '直営・フランチャイズ・下請け・場をつくる、の4つです。業種によって選べるものが違い、広がる速さ・利益の厚さ・要る人手が変わります。あとから手を使って変えられます。'),
  'own': ('持ち株@@term', 'あなたの会社の株のうち、社長（あなた）が持っている割合です。相棒や投資家に渡すと減ります。宿敵に50%を超えて握られると、社長の座を追われます。'),
  'cap': ('時価総額@@term', '会社の値段です。年の利益に評価の倍率を掛け、現金や資産を足して、借金を引いて決まります。上場すると評価が上がります。世界の企業ランキングはこの額で並びます。'),
  'synergy': ('シナジー@@term', '相性のよい2つの業種を同時に持つと見つかり、両方の事業の力が2割上がります。3つの業種をそろえる大シナジーは、3つとも4割上がります。'),
  'rank': ('世界の企業ランキング@@term', '世界中の会社を時価総額の大きい順に並べたものです。あなたの順位は、会社の時価総額にあなたの財産を足した額で決まります。'),
};

/// 用語の説明の小窓（いくつかまとめて出せる）
void openGlossary(GameController ctl, List<String> terms) {
  ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        H2(tr('用語の説明'), top: true),
        for (final t in terms)
          if (glossary[t] case final g?)
            Padding(
              key: ValueKey('term-$t'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(g.$1), style: Ui.h3),
                const SizedBox(height: 2),
                Text(tr(g.$2), style: ts(size: 13.5, height: 1.55)),
              ]),
            ),
        Align(alignment: Alignment.centerLeft, child: Btn(tr('閉じる'), ctl.closeSheet, primary: true)),
      ]));
}

/// 用語の横に置く小さな「i」。見た目は小さく、押せる範囲は 44pt 四方
class Info extends StatelessWidget {
  final GameController ctl;
  final List<String> terms;
  const Info(this.ctl, this.terms, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr('用語の説明：{0}', [terms.map((t) => tr(glossary[t]!.$1)).join(tr('、'))]),
        excludeSemantics: true,
        child: TapArea(
          key: ValueKey('info-${terms.join('-')}'),
          onTap: () => openGlossary(ctl, terms),
          child: const Icon(Icons.info_outline, size: 17, color: Pal.mute),
        ),
      );
}

/// 見出し（h2）の横に「i」を付けたもの。高さは [H2] とほぼ同じ
class H2Info extends StatelessWidget {
  final String text;
  final GameController ctl;
  final List<String> terms;
  const H2Info(this.text, this.ctl, this.terms, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Flexible(child: Text(tx(text), style: Ui.h2)),
          Info(ctl, terms),
        ]),
      );
}
