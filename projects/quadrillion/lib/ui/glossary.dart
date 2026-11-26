import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'widgets.dart';

/// 用語の説明（辞書）。画面の用語の横の「i」を押すと、ここの文を小窓で出す。
/// 鍵は用語の id、値は（用語・説明）。どちらも日本語で持ち、英語は lib/l10n/ui_en.dart に置く
const Map<String, (String, String)> glossary = {
  'ap': ('社長の時間@@term',
      '社長が1か月に使える時間です。ふつう200時間、無理をすれば300時間。行動ごとに時間がかかり、会社が大きいほど会議に取られます（任せると減る）。無理が続くと体力が尽きて倒れます。'),
  'share': ('シェア@@term', 'その業種の市場のうち、あなたの事業が取っている割合です。店・商品・人・責任者の力を、競争相手と比べて決まります。売上は「市場の大きさ×シェア」です。'),
  'crew': ('現場の力@@term', '店や工場を動かす人手が足りているかを表します。100%なら全部が動きます。90%を切ると一部が止まり、止まった分はほとんど稼ぎません。「現場の人を増やす」で上がります。'),
  'upkeep': ('維持費@@term', '店・工場と現場の人に、毎月かかるお金です。増やすほど上がり、売上が落ちても減りません。事業の利益から引かれます。'),
  'early': ('先行者@@term', '業種が生まれて3年以内に始めた事業に付きます。始めてから5年のあいだ、店・商品・広告などの打ち手がふだんの1.6倍よく効きます。'),
  'scale': ('規模の利益@@term', '1つの事業を5か国以上に出すと、利益率が上がります。5か国目から1か国ごとに＋6%、最大で＋50%です。'),
  'model': ('稼ぎ方@@term', '直営・フランチャイズ・下請け・場をつくる、の4つです。業種によって選べるものが違い、広がる速さ・利益の厚さ・要る人手が変わります。あとから手を使って変えられます。'),
  'own': ('持ち株@@term', 'あなたの会社の株のうち、社長（あなた）が持っている割合です。相棒や投資家に渡すと減ります。宿敵に50%を超えて握られると、社長の座を追われます。'),
  'cap': ('時価総額@@term', '会社の値段です。年の利益に評価の倍率を掛け、現金や資産を足して、借金を引いて決まります。上場すると評価が上がります。世界の企業ランキングはこの額で並びます。'),
  'synergy': ('シナジー@@term', '相性のよい2つの業種を同時に持つと見つかり、両方の事業の力が2割上がります。3つの業種をそろえる大シナジーは、3つとも4割上がります。'),
  'deleg': ('責任者に任せる@@term', '責任者のいる事業を任せると、毎月、責任者が「月の枠」の中で手を1つ打ちます（人・店・商品・広告・値付け）。社長の手は使いません。腕と性格で外れることもあります。海外や売る手は社長が決めます。いつでも戻せます。'),
  'rank': ('世界の企業ランキング@@term', '世界中の会社を時価総額の大きい順に並べたものです。あなたの順位は、会社の時価総額にあなたの財産を足した額で決まります。'),
  // 決算書（1.1.0+34）
  'pl': ('損益計算書@@term', '1年（1月〜12月）か1か月で、いくら売り、いくら使い、いくら儲かったかの表です。売上から原価を引くと粗利、経費を引くと営業利益、利息などを足し引きすると経常利益、税を引いた残りが当期純利益です。'),
  'bs': ('貸借対照表@@term', 'その年の終わりに持っているもの（資産）・借りているもの（負債）・残り（純資産）の表です。資産はいつも負債と純資産の合計と同じです。株と土地は時価、設備は減価償却のあとの額で載せます。'),
  'cf': ('キャッシュフロー計算書@@term', '現金がどこから入り、どこへ出ていったかの表です。本業の稼ぎ（営業）、店・工場や株への支払い（投資）、借りる・返す・増資・配当（財務）の3つに分けます。利益が出ていても、現金が減ることがあります。'),
  'equity': ('純資産@@term', '資産から負債（借金）を引いた残りです。元手と増資（資本金）、利益の積み上げ（利益剰余金）、持っている株や土地の値動き（評価差額）からできています。時価総額とは別のものです。'),
  'opinc': ('営業利益@@term', '本業でいくら稼いだかです。売上から、原価・人件費・家賃・広告・本社の経費・減価償却などを引いたものです。利息や、一度きりの売却益・罰金などは入りません。'),
  'ordinc': ('経常利益@@term', '営業利益に、使用料などを足し、借金の利息を引いたものです。子会社の利益の持ち分は営業利益に入っているので、子会社からの配当は足しません。ふだんの年に会社が稼ぐ力を表します。'),
  'gross': ('粗利@@term', '売上から売上原価（仕入れ・材料）を引いたものです。粗利が厚いほど、家賃や人件費を払ったあとに利益が残りやすくなります。'),
  'dep': ('減価償却@@term', '店・工場・設備・ITに払ったお金を、使える年数に分けて少しずつ費用にすることです。払った年に全部を費用にしないので、設備は貸借対照表に「払った額から減価償却を引いた額」で残ります。'),
  'gw': ('のれん@@term', '会社を買うとき、相手の正味の値打ちより高く払った分です。買った会社が見込みどおりに稼げないと、その分を損として落とします（減損）。'),
  'reval': ('評価差額@@term', '持っている株・子会社の株・土地の値段が上がり下がりした分です。売っていなくても、貸借対照表は今の値段で載せるので、その差を純資産に入れます。'),
  // 1.1.0+39
  'grpdebt': ('グループの借金@@term', '自社の借金に、株を過半持つ子会社の借金のうち持ち分の分を足したものです。銀行は格付け・借りられる上限・金利をこれで見ます。子会社が借りすぎると、親の格付けも下がります。'),
  'seg': ('事業ごとの損益@@term', '事業ひとつずつの、売上・原価・人件費・家賃・広告と、その事業の利益です。部下の給料・本社の経費・減価償却・利息・税は会社全体で払うので、事業には配っていません。'),
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
        // 中身を読み上げから外しているので、押す動きはここで渡す（渡さないと VoiceOver から押せない）
        onTap: () => openGlossary(ctl, terms),
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
