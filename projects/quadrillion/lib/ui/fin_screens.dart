/// 決算書（損益計算書・貸借対照表・キャッシュフロー計算書・推移のグラフ）と、事業ごとの損益（1.1.0+34）。
/// 数は game_fin.dart の記録から。画面は「お金」の「決算書」「事業ごとの損益」
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'glossary.dart';
import 'look.dart';
import 'widgets.dart';

/// 表の1行の決まり（id・名前の鍵・値の求め方・増えると良いか（1 良い・-1 悪い・0 どちらでもない）・段（0 ふつう・1 内訳・2 小計・3 合計）・たたむ組）
class FinLine {
  final String id, label;
  final double Function(Map<String, double> v) f;
  final int good, lv;

  /// 内訳の行なら、たたむ組（小計の行がその組を開閉する）。小計の行なら、開閉する組
  final String? fold, opens;

  /// 用語の説明（「i」）
  final List<String>? info;

  /// どちらの年も 0 なら出さない
  final bool hideZero;
  const FinLine(this.id, this.label, this.f, {this.good = 0, this.lv = 0, this.fold, this.opens, this.info, this.hideZero = false});
}

double _g(Map<String, double> v, String k) => v[k] ?? 0;

/// 損益計算書の行
final List<FinLine> plLines = [
  FinLine('rev', '売上高', (v) => _g(v, 'rev'), good: 1, lv: 2),
  FinLine('cogs', '売上原価', (v) => _g(v, 'cogs'), good: -1),
  FinLine('gross', '売上総利益（粗利）', finGross, good: 1, lv: 2, info: const ['gross']),
  FinLine('sga', '販売費と一般管理費', finSga, good: -1, opens: 'fs-sga'),
  FinLine('labor', '人件費', (v) => _g(v, 'labor'), good: -1, lv: 1, fold: 'fs-sga'),
  FinLine('rent', '家賃', (v) => _g(v, 'rent'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('util', '光熱費', (v) => _g(v, 'util'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('logi', '物流費', (v) => _g(v, 'logi'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('ad', '広告費', (v) => _g(v, 'ad'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('insur', '保険料', (v) => _g(v, 'insur'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('repair', '修繕と更新', (v) => _g(v, 'repair'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('hq', '本社の経費', (v) => _g(v, 'hq'), good: -1, lv: 1, fold: 'fs-sga'),
  FinLine('subc', '子会社の費用（持ち分）', (v) => _g(v, 'subc'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('oth', '関税・輸送・現地の手間など', (v) => _g(v, 'oth'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('grow', '開発・宣伝・採用などに使ったお金', (v) => -_g(v, 'c:grow'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('misc', '上場・調査・寄付などの費用', (v) => -_g(v, 'c:misc'), good: -1, lv: 1, fold: 'fs-sga', hideZero: true),
  FinLine('dep', '減価償却', (v) => _g(v, 'dep'), good: -1, lv: 1, fold: 'fs-sga', info: const ['dep']),
  FinLine('op', '営業利益', finOpInc, good: 1, lv: 2, info: const ['opinc']),
  FinLine('nonop', '営業外の損益', finNonOp, good: 1, opens: 'fs-nonop'),
  // 子会社の配当は営業利益に入った利益の持ち分と同じものなので、ここには足さない（1.1.0+35）
  FinLine('nonopIn', '営業外の収入（使用料など）', (v) => _g(v, 'c:nonop'), good: 1, lv: 1, fold: 'fs-nonop'),
  FinLine('intr', '支払利息', (v) => _g(v, 'intr'), good: -1, lv: 1, fold: 'fs-nonop'),
  FinLine('ord', '経常利益', finOrd, good: 1, lv: 2, info: const ['ordinc']),
  FinLine('sp', '特別損益', (v) => finSpGain(v) - finSpLoss(v), good: 1, opens: 'fs-sp'),
  FinLine('spg', '特別利益', finSpGain, good: 1, lv: 1, fold: 'fs-sp'),
  FinLine('bizSale', '事業の売却', (v) => _g(v, 'c:bizSale'), good: 1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('debtG', '借金の減免', (v) => math.max(0.0, _g(v, 'debtG')), good: 1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('spp', 'そのほかの特別利益（賠償金など）', (v) => _g(v, 'c:sp+'), good: 1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('spl', '特別損失', finSpLoss, good: -1, lv: 1, fold: 'fs-sp'),
  FinLine('gwImp', 'のれんの減損', (v) => _g(v, 'gwImp'), good: -1, lv: 4, fold: 'fs-sp', hideZero: true, info: const ['gw']),
  FinLine('subLoss', '子会社の倒産', (v) => _g(v, 'subLoss'), good: -1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('spm', '罰金・災害・和解など', (v) => -_g(v, 'c:sp-'), good: -1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('unc', '分類していない出入り', (v) => -_g(v, 'c:unc'), good: -1, lv: 4, fold: 'fs-sp', hideZero: true),
  FinLine('pretax', '税引前当期純利益', finPretax, good: 1, lv: 2),
  FinLine('tax', '法人税など', (v) => _g(v, 'tax'), good: -1),
  FinLine('ni', '当期純利益', finNi, good: 1, lv: 3),
];

/// 貸借対照表の行（資産）
final List<FinLine> bsAssetLines = [
  FinLine('cash', '現金', (v) => _g(v, 'b:cash'), good: 1),
  FinLine('ar', '売掛金', (v) => _g(v, 'b:ar'), hideZero: true),
  FinLine('pp', '前払い', (v) => _g(v, 'b:pp'), hideZero: true),
  FinLine('trap', '海外で止められたお金', (v) => _g(v, 'b:trap'), hideZero: true),
  FinLine('eq', '設備（償却のあと）', (v) => _g(v, 'b:eq'), info: const ['dep']),
  FinLine('land', '土地', (v) => _g(v, 'b:land'), hideZero: true),
  FinLine('stk', '持っている株', (v) => _g(v, 'b:stk'), hideZero: true),
  FinLine('sub', '子会社の株', (v) => _g(v, 'b:sub'), hideZero: true),
  FinLine('gw', '（うち、のれん）', (v) => _g(v, 'b:gw'), lv: 1, hideZero: true, info: const ['gw']),
  FinLine('assets', '資産の合計', finAssets, good: 1, lv: 3),
];

/// 貸借対照表の行（負債と純資産）
final List<FinLine> bsLiabLines = [
  FinLine('loan', '借入金', (v) => _g(v, 'b:loan'), good: -1),
  FinLine('bond', '社債', (v) => _g(v, 'b:bond'), good: -1, hideZero: true),
  FinLine('liabs', '負債の合計', finLiabs, good: -1, lv: 2),
  FinLine('cap', '資本金', (v) => _g(v, 'b:cap')),
  FinLine('re', '利益剰余金', (v) => _g(v, 'b:re'), good: 1),
  FinLine('reval', '評価差額', (v) => _g(v, 'b:rev'), hideZero: true, info: const ['reval']),
  FinLine('equity', '純資産の合計', finEquity, good: 1, lv: 2, info: const ['equity']),
  FinLine('gap', '合わない差', (v) => _g(v, 'b:gap'), hideZero: true),
  FinLine('le', '負債と純資産の合計', (v) => finLiabs(v) + finEquity(v), lv: 3),
  // 参考（表の外）：負債に子会社の借金の持ち分を足したグループの借金（「i」で説明）。子会社がお金を借りていなければ出さない（1.1.0+39。
  // iPhone で貸借対照表が長くならないよう1行にした）
  FinLine('grpDebt', '参考：グループ借金', (v) => _g(v, 'b:subDebt') > 0 ? finLiabs(v) + _g(v, 'b:subDebt') : 0, good: -1, lv: 1, hideZero: true, info: const ['grpdebt']),
];

/// キャッシュフロー計算書の行
final List<FinLine> cfLines = [
  FinLine('cfop', '営業キャッシュフロー', finCfOpSum, good: 1, lv: 2, opens: 'fs-cfop'),
  // 営業の行は現金の入り（＋）と出（−）の数。数が上がる（入りが増える・支払いが減る）と緑、下がる（支払い＝費用が増える）と赤（1.1.0+35）
  FinLine('op', '本業で入ったお金（利息と税の前）', (v) => _g(v, 'c:op'), good: 1, lv: 1, fold: 'fs-cfop'),
  FinLine('ar', '売掛金の増減', (v) => _g(v, 'c:ar'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('pp', '仕入れ先への前払い', (v) => _g(v, 'c:pp'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('trap', '海外に留め置かれたお金', (v) => _g(v, 'c:trap'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('div', '子会社からの配当', (v) => _g(v, 'c:div'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('nonop', '使用料などの収入', (v) => _g(v, 'c:nonop'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('intr', '利息の支払い', (v) => _g(v, 'c:intr'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('tax', '税金の支払い', (v) => _g(v, 'c:tax'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('grow', '開発・宣伝・採用などに使ったお金', (v) => _g(v, 'c:grow'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('misc', '上場・調査・寄付などの費用', (v) => _g(v, 'c:misc'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('sp', '罰金・災害・賠償金など', (v) => _g(v, 'c:sp+') + _g(v, 'c:sp-'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('unc', '分類していない出入り', (v) => _g(v, 'c:unc'), good: 1, lv: 1, fold: 'fs-cfop', hideZero: true),
  FinLine('cfinv', '投資キャッシュフロー', finCfInvSum, lv: 2, opens: 'fs-cfinv'),
  FinLine('capex', '設備投資（店・工場・設備・IT）', (v) => _g(v, 'c:capex'), lv: 1, fold: 'fs-cfinv', hideZero: true),
  FinLine('land', '土地の売買', (v) => _g(v, 'c:land'), lv: 1, fold: 'fs-cfinv', hideZero: true),
  FinLine('stock', '株・子会社の売買', (v) => _g(v, 'c:stock'), lv: 1, fold: 'fs-cfinv', hideZero: true),
  FinLine('bizSale', '事業の売却', (v) => _g(v, 'c:bizSale'), lv: 1, fold: 'fs-cfinv', hideZero: true),
  FinLine('cffin', '財務キャッシュフロー', finCfFinSum, lv: 2, opens: 'fs-cffin'),
  // 借り入れが増える（負債が増える）と赤、返済が増える（負債が減る。数はマイナスで大きくなる）と緑（1.1.0+35）
  FinLine('borrow', '借り入れ', (v) => _g(v, 'c:borrow'), good: -1, lv: 1, fold: 'fs-cffin', hideZero: true),
  FinLine('repay', '返済', (v) => _g(v, 'c:repay'), good: -1, lv: 1, fold: 'fs-cffin', hideZero: true),
  FinLine('equity', '増資・上場', (v) => _g(v, 'c:equity'), lv: 1, fold: 'fs-cffin', hideZero: true),
  FinLine('payout', '配当・自社株買い', (v) => _g(v, 'c:payout'), lv: 1, fold: 'fs-cffin', hideZero: true),
  FinLine('reset', '会社の売却・倒産での入れ替え', (v) => _g(v, 'c:reset'), hideZero: true),
  FinLine('delta', '現金の増減', finCfAll, good: 1, lv: 2),
];

/// 説明の文をつなぐ（日本語は詰めて、英語は空白で）
String finJoin(List<String> parts) => parts.where((x) => x.isNotEmpty).join(L.en ? ' ' : '');

/// 割合の増減の文（前が 0 なら「―」）
String finPct(double cur, double prev) {
  if (prev.abs() < 1 || !cur.isFinite) return '―';
  final p = (cur - prev) / prev.abs() * 100;
  if (p.abs() >= 1000) return p > 0 ? '+999%+' : '-999%+';
  return '${p > 0 ? '+' : ''}${pctD(p)}%';
}

/// 増減の色（増えると良い行は増えたら緑、増えると悪い行は増えたら赤）
Color finDiffCol(double d, int good) => good == 0 || d.abs() < 1 ? Pal.mute : ((d > 0) == (good > 0) ? Pal.up : Pal.down);

/// 表のます（数は右寄せ。入りきらなければ字を縮める）
Widget finCell(String t, {double w = 0, bool bold = false, Color c = Pal.ink, TextAlign a = TextAlign.right, double size = 12.5}) {
  final txt = Text(t, maxLines: 1, softWrap: false, textAlign: a, style: ts(size: size, bold: bold, color: c));
  // 右寄せの数は、左の隣とくっつかないように少し間をあける
  final fb = Padding(
      padding: EdgeInsets.only(left: a == TextAlign.left ? 0 : 5),
      child: FittedBox(fit: BoxFit.scaleDown, alignment: a == TextAlign.left ? Alignment.centerLeft : Alignment.centerRight, child: txt));
  return w > 0 ? SizedBox(width: w, child: fb) : Expanded(child: fb);
}

/// 表を左右2列に並べる最小の幅（iPhone の横の画面では1列。数の列が4つあるので、2列だと字が小さくなりすぎる）
const finCols2Min = 760.0;

/// 表の名前の列と数の列の幅の比
const finLabelFlex = 9, finNumFlex = 5;

/// 数のます（左に少し間をあけ、隣の数とくっつかないようにする）
Widget finNum(String t, {bool bold = false, Color c = Pal.ink, double size = 12.5}) => Expanded(
    flex: finNumFlex,
    child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(t, maxLines: 1, softWrap: false, textAlign: TextAlign.right, style: ts(size: size, bold: bold, color: c)))));

/// 前年の流れを、今年と同じ月の数に直す（年の途中・記録を途中から始めた年を比べるとき）
Map<String, double> finScaled(FinRec prev, int n) {
  if (prev.n == n || prev.n == 0) return prev.v;
  final k = n / prev.n;
  return {for (final e in prev.v.entries) e.key: e.key.startsWith('b:') || e.key.startsWith('b0:') ? e.value : e.value * k};
}

/// 決算書で見る年（ctl.fsYear が無い・記録の無い年なら、締めた年の最新。無ければ今年の途中）
int? finSelYear(GameController ctl) {
  final s = ctl.game!;
  final ys = s.finYears();
  if (ys.isEmpty) return null;
  if (ctl.fsYear != null && ys.contains(ctl.fsYear)) return ctl.fsYear;
  return s.books.years.isNotEmpty ? s.books.years.last.y : ys.last;
}

/// 見ている年の名前（今年の途中は月の数つき）
String finYearLabel(Game s, int y) {
  final t = s.finThisYear();
  return t != null && t.y == y ? tr('{0}（{1}か月）', [yearL(y), t.n]) : yearL(y);
}

/// 年を送る「‹ 1996年 ›」（表の見出しの右に置く。札の行を増やさない）
Widget finYearStep(GameController ctl, String id) {
  final s = ctl.game!;
  final ys = s.finYears();
  final sel = finSelYear(ctl)!;
  final i = ys.indexOf(sel);
  Widget arrow(IconData ic, int? to, String k, String label) => Semantics(
        button: true,
        enabled: to != null,
        label: label,
        excludeSemantics: true,
        onTap: to == null ? null : () => ctl.setFs(year: to),
        child: TapArea(key: ValueKey(k), onTap: to == null ? null : () => ctl.setFs(year: to), child: Icon(ic, size: 24, color: to == null ? Pal.line : Pal.goldtx)),
      );
  return Row(key: ValueKey('$id-year'), mainAxisSize: MainAxisSize.min, children: [
    arrow(Icons.chevron_left, i > 0 ? ys[i - 1] : null, '$id-prev', tr('前の年')),
    Text(finYearLabel(s, sel), key: ValueKey('$id-year-label'), style: ts(size: 13.5, bold: true, color: Pal.goldtx)),
    arrow(Icons.chevron_right, i >= 0 && i < ys.length - 1 ? ys[i + 1] : null, '$id-next', tr('次の年')),
  ]);
}

/// 期間の選び方（id・名前）
const finModes = [('year', '年ごと'), ('ytd', '今年の各月'), ('last12', '直近12か月')];

String finModeId(GameController ctl) => ctl.fsMode == 'year' ? 'year' : ctl.fsMonths;
String finModeLabel(GameController ctl) => tr(finModes.firstWhere((m) => m.$1 == finModeId(ctl)).$2);

void _pickMode(GameController ctl) {
  ctl.showSheet((_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        H2(tr('期間'), top: true),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final m in finModes)
            PickChip(tr(m.$2), key: ValueKey('fs-mode-${m.$1}'), on: finModeId(ctl) == m.$1, onTap: () {
              if (m.$1 == 'year') {
                ctl.setFs(mode: 'year');
              } else {
                ctl.setFs(mode: 'month', months: m.$1);
              }
              ctl.closeSheet();
            }),
        ]),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Btn(tr('閉じる'), ctl.closeSheet)),
      ]));
}

/// お金の「決算書」
List<Widget> finView(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[];
  // 自社の名前があれば、どの会社の決算書かを上に出す（1.1.0+37）
  if (s.myCo.isNotEmpty) {
    out.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(tr('{0}の決算書', [nmL(s.myCo)]), key: const ValueKey('fs-co'), style: ts(size: 14, bold: true), maxLines: 1, overflow: TextOverflow.ellipsis)));
  }
  // 表の札と期間の札は1つの行に流す（iPhone の横の画面で、札だけで高さを取らないように）
  out.add(Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Wrap(key: const ValueKey('fs-chips'), spacing: 6, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final t in const [('pl', '損益計算書'), ('bs', '貸借対照表'), ('cf', 'キャッシュフロー'), ('trend', '推移のグラフ')])
        PickChip(tr(t.$2), key: ValueKey('fs-tab-${t.$1}'), on: ctl.fsTab == t.$1, onTap: () => ctl.setFs(tab: t.$1)),
      // 期間は1枚の札にまとめ、押すと選ぶ小窓が開く
      PickChip(finModeLabel(ctl), key: const ValueKey('fs-mode'), on: false, more: true, onTap: () => _pickMode(ctl)),
    ]),
  ));
  if (s.books.months.isEmpty) {
    out.add(Panel(
        key: const ValueKey('fs-empty'),
        child: Muted(tr('まだ締めた月がありません。月を進めると、月の終わりに決算書が作られます（年は1月〜12月で締めます）'))));
    return out;
  }
  if (ctl.fsMode == 'month') {
    out.addAll(_monthView(ctl));
    return out;
  }
  final y = finSelYear(ctl)!;
  final step = finYearStep(ctl, 'fs');
  final cur = s.finYear(y)!;
  final prevRec = s.finYear(y - 1);
  final prev = prevRec == null ? null : finScaled(prevRec, cur.n);
  final note = <String>[
    if (cur.n < 12) tr('{0}は{1}か月分です。', [yearL(y), cur.n]),
    if (prevRec == null) tr('前の年は記録がありません（記録は{0}から）。', [ym(s.books.fy, s.books.fq)]),
    if (prevRec != null && prevRec.n != cur.n) tr('前の年は、同じ月の数に直して比べています。'),
  ].join(L.en ? ' ' : '');
  switch (ctl.fsTab) {
    case 'bs':
      final e = finEquity(cur.v), mc = cur.g('b:mcap');
      // 広い画面は資産と負債・純資産を左右に、狭い画面は1枚の表に続けて（見出しと列の名前を1回にして短くする）
      out.add(LayoutBuilder(
          builder: (context, c) => c.maxWidth >= finCols2Min
              ? Cols2([
                  _table(ctl, 'fs-bs-a', tr('資産'), bsAssetLines, cur.v, prev, ['bs'], yearStep: step),
                ], [
                  _table(ctl, 'fs-bs-l', tr('負債と純資産'), bsLiabLines, cur.v, prev, ['equity']),
                ], min: finCols2Min)
              : _table(ctl, 'fs-bs', tr('貸借対照表'), const [], cur.v, prev, ['bs', 'equity'],
                  yearStep: step, more: [('fs-bs-a', tr('資産'), bsAssetLines), ('fs-bs-l', tr('負債と純資産'), bsLiabLines)])));
      out.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Muted(
            finJoin([
              if (mc > 0 && e > 0) tr('時価総額は{0}（純資産の{1}倍）。株価はこれからの稼ぎの見込みで決まり、帳簿の純資産とは別です。', [yen(mc), timesL(mc / e)]),
              if (mc > 0 && e <= 0) tr('時価総額は{0}。純資産がマイナスでも、稼ぐ見込みがあれば株価はつきます。', [yen(mc)]),
              note,
            ]),
            key: const ValueKey('fs-bs-note'),
            size: 11.5),
      ));
    case 'cf':
      final open = cur.g('b0:cash');
      out.add(_table(ctl, 'fs-cf', tr('キャッシュフロー計算書'), cfLines, cur.v, prev, ['cf'], extra: [
        _row(tr('期首の現金'), open, prevRec?.g('b0:cash'), lv: 0, good: 0, key: 'fs-cf-open'),
        _row(tr('期末の現金'), cur.g('b:cash'), prevRec?.g('b:cash'), lv: 3, good: 1, key: 'fs-cf-close'),
      ], yearStep: step));
      out.add(Padding(padding: const EdgeInsets.only(top: 4), child: Muted(finJoin([tr('現金の動きを、本業・投資・お金の出し入れの3つに分けたものです。行を押すと内訳が開きます。'), note]), key: const ValueKey('fs-cf-note'), size: 11.5)));
    case 'trend':
      out.addAll(_trendView(ctl));
    default:
      out.add(_table(ctl, 'fs-pl', tr('損益計算書'), plLines, cur.v, prev, ['pl'], yearStep: step));
      out.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Muted(finJoin([tr('年は1月〜12月で締めます。行を押すと内訳が開きます。'), note]), key: const ValueKey('fs-pl-note'), size: 11.5)));
  }
  return out;
}

/// 1行（今年・前年・増減・%）
Widget _row(String label, double cur, double? prev, {required int lv, required int good, String? key, VoidCallback? onTap, bool? open, Widget? info}) {
  final d = prev == null ? null : cur - prev;
  // 段: 0 ふつう・1 内訳・2 小計・3 合計・4 内訳の内訳
  final big = lv == 2 || lv == 3, sub = lv == 1 || lv == 4;
  final lab = Row(children: [
    if (sub) SizedBox(width: lv == 4 ? 24 : 12),
    Flexible(
        child: Text(label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ts(size: sub ? 12 : 12.5, bold: big, color: sub ? Pal.mute : Pal.ink, height: 1.25))),
    ?info,
    if (open != null) Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: Pal.goldtx),
  ]);
  final row = Container(
    key: key == null ? null : ValueKey(key),
    constraints: const BoxConstraints(minHeight: 25),
    padding: const EdgeInsets.symmetric(vertical: 2),
    decoration: lv == 3 ? const BoxDecoration(color: Pal.goldBg, border: Border(bottom: BorderSide(color: Pal.line))) : Ui.rowLine,
    child: Row(children: [
      Expanded(flex: finLabelFlex, child: lab),
      finNum(yen(cur), bold: big, c: cur < 0 ? Pal.down : Pal.ink),
      finNum(prev == null ? '―' : yen(prev), c: Pal.mute),
      finNum(d == null || d.abs() < 1 ? '―' : '${d > 0 ? '+' : ''}${yen(d)}', c: d == null ? Pal.mute : finDiffCol(d, good)),
      finCell(prev == null ? '―' : finPct(cur, prev), c: d == null ? Pal.mute : finDiffCol(d, good), w: Ui.sw(56)),
    ]),
  );
  if (onTap == null) return row;
  return Semantics(button: true, expanded: open, child: InkWell(onTap: onTap, child: row));
}

/// 表（見出し・列の名前・行）
Widget _table(GameController ctl, String id, String title, List<FinLine> lines, Map<String, double> cur, Map<String, double>? prev, List<String> info,
    {List<Widget> extra = const [], Widget? yearStep, List<(String, String, List<FinLine>)> more = const []}) {
  final rows = <Widget>[];
  void addLines(String pre, List<FinLine> ls) {
    for (final l in ls) {
      final a = l.f(cur), b = prev == null ? null : l.f(prev);
      if (l.hideZero && a.abs() < 1 && (b == null || b.abs() < 1)) continue;
      if (l.fold != null && !ctl.shown.contains(l.fold)) continue;
      final opens = l.opens;
      rows.add(_row(tr(l.label), a, b,
          lv: l.lv, good: l.good, key: '$pre-${l.id}', open: opens == null ? null : ctl.shown.contains(opens), onTap: opens == null ? null : () => ctl.toggleShown(opens)));
    }
  }

  addLines(id, lines);
  // 同じ表に続けて出す組（狭い画面の貸借対照表で、資産と負債・純資産を1枚にする）。小見出しを挟む
  for (final m in more) {
    rows.add(Padding(padding: const EdgeInsets.only(top: 6, bottom: 1), child: Text(m.$2, style: ts(size: 12.5, bold: true, color: Pal.goldtx))));
    addLines(m.$1, m.$3);
  }
  // 用語の「i」は見出しにまとめる（行に置くと、押せる範囲の分だけ行が高くなる）
  final terms = <String>{...info, for (final l in [...lines, for (final m in more) ...m.$3]) ...?l.info}.toList();
  return Panel(
    key: ValueKey(id),
    padding: const EdgeInsets.fromLTRB(Ui.pad, 4, Ui.pad, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(title, Icons.table_rows_outlined,
          tone: ScreenTone.money, trailing: Row(mainAxisSize: MainAxisSize.min, children: [Info(ctl, terms), ?yearStep])),
      Row(children: [
        Expanded(flex: finLabelFlex, child: Muted(tr('項目'), size: 11.5)),
        finNum(tr('この年'), c: Pal.mute, size: 11.5),
        finNum(tr('前の年'), c: Pal.mute, size: 11.5),
        finNum(tr('増減'), c: Pal.mute, size: 11.5),
        finCell('%', c: Pal.mute, size: 11.5, w: Ui.sw(56)),
      ]),
      ...rows,
      ...extra,
    ]),
  );
}

/// 月の英語の略
const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String finMonL(int q) => L.en ? _monEn[(q - 1).clamp(0, 11)] : '$q月';

/// 月ごとの記録（今年の各月・直近12か月）
List<FinRec> finMonthRecs(GameController ctl) {
  final ms = ctl.game!.books.months;
  if (ctl.fsMonths == 'ytd') {
    final y = ms.last.y;
    return ms.where((m) => m.y == y).toList();
  }
  return ms.length > 12 ? ms.sublist(ms.length - 12) : ms.toList();
}

/// 月ごとの表の列（名前・値・増えると良いか）
List<(String, double Function(FinRec m, FinRec? prev), int)> _monthCols(String tab) => switch (tab) {
      'bs' => [
          ('資産', (m, _) => finAssets(m.v), 1),
          ('負債', (m, _) => finLiabs(m.v), -1),
          ('純資産', (m, _) => finEquity(m.v), 1),
          ('現金', (m, _) => m.g('b:cash'), 1),
          ('借金', (m, _) => m.g('b:loan') + m.g('b:bond'), -1),
        ],
      'cf' => [
          ('営業', (m, _) => finCfOpSum(m.v), 1),
          ('投資', (m, _) => finCfInvSum(m.v), 0),
          ('財務', (m, _) => finCfFinSum(m.v), 0),
          ('増減', (m, _) => finCfAll(m.v), 1),
          ('月末の現金', (m, _) => m.g('b:cash'), 1),
        ],
      _ => [
          ('売上', (m, _) => m.g('rev'), 1),
          ('粗利', (m, _) => finGross(m.v), 1),
          ('営業利益', (m, _) => finOpInc(m.v), 1),
          ('経常利益', (m, _) => finOrd(m.v), 1),
          ('純利益', (m, _) => finNi(m.v), 1),
        ],
    };

List<Widget> _monthView(GameController ctl) {
  final recs = finMonthRecs(ctl);
  if (ctl.fsTab == 'trend') return _trendMonths(ctl, recs);
  final cols = _monthCols(ctl.fsTab);
  final flow = ctl.fsTab != 'bs';
  final rows = <Widget>[];
  FinRec? prev;
  for (final m in recs) {
    rows.add(Container(
      key: ValueKey('fs-m-${m.y}-${m.q}'),
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      decoration: Ui.rowLine,
      child: Row(children: [
        finCell(ym(m.y, m.q), w: Ui.sw(78), a: TextAlign.left),
        for (final c in cols)
          Builder(builder: (_) {
            final v = c.$2(m, prev);
            return finNum(yen(v), c: v < 0 ? Pal.down : Pal.ink);
          }),
      ]),
    ));
    prev = m;
  }
  if (flow && recs.length > 1) {
    rows.add(Container(
      key: const ValueKey('fs-m-total'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Pal.goldBg,
      child: Row(children: [
        finCell(tr('合計'), w: Ui.sw(78), a: TextAlign.left, bold: true),
        for (var i = 0; i < cols.length; i++)
          Builder(builder: (_) {
            // 月末の現金は足さない（最後の月の値）
            final v = ctl.fsTab == 'cf' && i == cols.length - 1 ? recs.last.g('b:cash') : recs.fold(0.0, (s, m) => s + cols[i].$2(m, null));
            return finNum(yen(v), bold: true, c: v < 0 ? Pal.down : Pal.ink);
          }),
      ]),
    ));
  }
  final title = switch (ctl.fsTab) { 'bs' => '貸借対照表（月末）', 'cf' => 'キャッシュフロー（月ごと）', _ => '損益計算書（月ごと）' };
  return [
    Panel(
      key: const ValueKey('fs-month'),
      padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(tr(title), Icons.table_rows_outlined, tone: ScreenTone.money, trailing: Info(ctl, [ctl.fsTab == 'bs' ? 'bs' : ctl.fsTab == 'cf' ? 'cf' : 'pl'])),
        Row(children: [
          finCell(tr('月'), w: Ui.sw(78), a: TextAlign.left, c: Pal.mute, size: 11.5),
          for (final c in cols) finNum(tr(c.$1), c: Pal.mute, size: 11.5),
        ]),
        ...rows,
      ]),
    ),
    Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Muted(tr('記録は直近24か月まで残します。年の決算書は全部の年を残します。'), size: 11.5)),
  ];
}

// ===== 推移のグラフ =====
/// 推移のグラフの色（売上・営業利益・純利益／現金・借金・純資産）
const finTrendCols = [Pal.teal, Pal.gold, Pal.up, Color(0xFF4A78C2), Pal.down, Color(0xFF8E5CC4)];

/// 年ごとの推移（直近5年。今年の途中は薄く）
List<Widget> _trendView(GameController ctl) {
  final s = ctl.game!;
  final ys = s.finYears();
  final show = ys.length > 5 ? ys.sublist(ys.length - 5) : ys;
  final recs = [for (final y in show) s.finYear(y)!];
  return _trendCharts(ctl, [for (final r in recs) r.n < 12 ? tr('{0}（{1}か月）', [r.y, r.n]) : '${r.y}'], recs, [for (final r in recs) r.n < 12],
      tr('直近5年（年は1月〜12月。途中の年は月の数つき）'));
}

List<Widget> _trendMonths(GameController ctl, List<FinRec> recs) =>
    _trendCharts(ctl, [for (final r in recs) finMonLabel(r)], recs, [for (final _ in recs) false], tr('月ごと'));

String finMonLabel(FinRec r) => r.q == 1 ? (L.en ? '${_monEn[0]} ${r.y % 100}' : '${r.y % 100}年1月') : finMonL(r.q);

List<Widget> _trendCharts(GameController ctl, List<String> labels, List<FinRec> recs, List<bool> part, String note) {
  final a = [
    [for (final r in recs) r.g('rev')],
    [for (final r in recs) finOpInc(r.v)],
    [for (final r in recs) finNi(r.v)],
  ];
  final b = [
    [for (final r in recs) r.g('b:cash')],
    [for (final r in recs) r.g('b:loan') + r.g('b:bond')],
    [for (final r in recs) finEquity(r.v)],
  ];
  Widget legend(List<String> names, List<Color> cols) => Wrap(spacing: 12, runSpacing: 2, children: [
        for (var i = 0; i < names.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 10, color: cols[i]), const SizedBox(width: 4), Muted(tr(names[i]), size: 12)]),
      ]);
  // 1.1.0+41 から、棒ではなく推移のグラフ（目盛り・日付つき。押すと、その期間の値が出る）
  Widget chart(String id, String title, List<List<double>> series, List<Color> cols, List<String> names, List<String> info) => Panel(
        key: ValueKey(id),
        padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHead(title, Icons.show_chart, tone: ScreenTone.money, trailing: Info(ctl, info)),
          const SizedBox(height: 4),
          TrendChart(
            key: ValueKey('$id-chart'),
            height: 104,
            labels: labels,
            fmt: yen,
            series: [for (var i = 0; i < names.length; i++) TrendSeries(tr(names[i]), cols[i], series[i])],
            summary: '$title. ${[for (var i = 0; i < names.length; i++) '${tr(names[i])} ${series[i].isEmpty ? '' : yen(series[i].last)}'].join(', ')}',
          ),
          const SizedBox(height: 4),
          legend(names, cols),
        ]),
      );
  // 数の表（グラフの値をそのまま）
  final table = Panel(
    key: const ValueKey('fs-trend-table'),
    padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        finCell('', w: Ui.sw(64), a: TextAlign.left),
        for (final n in const ['売上', '営業利益', '純利益', '現金', '借金', '純資産']) finNum(tr(n), c: Pal.mute, size: 11),
      ]),
      for (var i = 0; i < recs.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: Ui.rowLine,
          child: Row(children: [
            finCell(labels[i], w: Ui.sw(64), a: TextAlign.left, size: 11.5, c: part[i] ? Pal.mute : Pal.ink),
            for (final v in [a[0][i], a[1][i], a[2][i], b[0][i], b[1][i], b[2][i]]) finNum(yen(v), size: 11.5, c: v < 0 ? Pal.down : Pal.ink),
          ]),
        ),
    ]),
  );
  // 売上と利益は桁が違うので、別のグラフにする（同じ目盛りだと利益の棒が見えない）
  return [
    Masonry2([
      chart('fs-trend-rev', tr('売上'), [a[0]], [finTrendCols[0]], const ['売上'], const ['pl']),
      chart('fs-trend-pl', tr('営業利益と純利益'), [a[1], a[2]], finTrendCols.sublist(1, 3), const ['営業利益', '純利益'], const ['opinc']),
      chart('fs-trend-bs', tr('現金・借金・純資産'), b, finTrendCols.sublist(3), const ['現金', '借金', '純資産'], const ['equity']),
    ]),
    // 数の表は列が6つあるので、2列に並べずに幅いっぱいに。はじめはたたんでおく（iPhone で長くしない）
    Align(
        alignment: Alignment.centerLeft,
        child: DetailBtn(key: const ValueKey('fs-trend-num'), open: ctl.shown.contains('fs-trend-num'), onTap: () => ctl.toggleShown('fs-trend-num'), label: tr('数の表'))),
    if (ctl.shown.contains('fs-trend-num')) table,
    Padding(padding: const EdgeInsets.only(top: 2), child: Muted(note, size: 11.5)),
  ];
}

/// 棒グラフ（期間ごとに系列の棒を並べる。マイナスは0の線から下へ。途中の期間は薄く）
class FinBarsPainter extends CustomPainter {
  final List<String> labels;
  final List<List<double>> series;
  final List<Color> cols;
  final List<bool> partial;
  FinBarsPainter(this.labels, this.series, this.cols, this.partial);
  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;
    final all = [for (final s in series) ...s];
    final lo = math.min(0.0, all.reduce(math.min)), hi = math.max(1.0, all.reduce(math.max));
    const lab = 16.0;
    final h = size.height - lab;
    double yy(double v) => 4 + (hi - v) / (hi - lo) * (h - 8);
    final gw = size.width / n;
    final bw = math.min(22.0, gw * .8 / series.length);
    final p = Paint();
    // 細かい月の名前は、入りきらなければ間引く
    final step = math.max(1, (n * 44 / size.width).ceil());
    for (var i = 0; i < n; i++) {
      final x0 = i * gw + (gw - bw * series.length) / 2;
      for (var k = 0; k < series.length; k++) {
        final v = series[k][i];
        p.color = cols[k].withValues(alpha: partial[i] ? .4 : 1);
        final t = yy(math.max(v, 0)), bt = yy(math.min(v, 0));
        canvas.drawRect(Rect.fromLTRB(x0 + k * bw, t, x0 + (k + 1) * bw - 1, math.max(bt, t + 1)), p);
      }
      if (i % step == 0 || i == n - 1) {
        final tp = TextPainter(text: TextSpan(text: labels[i], style: ts(size: 10, color: Pal.mute)), textDirection: TextDirection.ltr, maxLines: 1)
          ..layout(maxWidth: gw * step);
        tp.paint(canvas, Offset(i * gw + (gw - tp.width) / 2, size.height - lab + 2));
      }
    }
    canvas.drawLine(Offset(0, yy(0)), Offset(size.width, yy(0)), Paint()..color = Pal.line);
    // いちばん上の目盛り
    final tp = TextPainter(text: TextSpan(text: yen(hi), style: ts(size: 9.5, color: Pal.mute)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(covariant FinBarsPainter o) => o.labels.join() != labels.join() || o.series.toString() != series.toString();
}

// ===== 事業ごとの損益 =====
/// 事業の行の名前（自社の事業は業種、子会社・現地法人は会社の名前）
String segName(FinBiz r) => r.co == null ? (indm[r.ind]?.name ?? r.ind) : nmL(r.co);

/// 子会社・現地法人の印の文
String? segKind(FinBiz r) => r.co == null ? null : (r.loc != null ? tr('現地法人（{0}）', [cm[r.loc!]?.n ?? r.loc!]) : tr('子会社@@tag'));

/// 事業ごとの損益の1行の値（売上・原価・粗利・人件費・家賃・広告・その他・利益・利益率・売上の前年比）
class SegRow {
  final String key;
  final FinBiz r;
  final FinBiz? prev;
  final double k;
  SegRow(this.key, this.r, this.prev, this.k);
  double get rev => r.v[0];
  double get cogs => r.v[1];
  double get gross => r.v[0] - r.v[1];
  double get labor => r.v[2];
  double get rent => r.v[3];
  double get ad => r.v[4];
  double get other => r.v[5] + r.v[6];
  double get cost => labor + rent + ad + other;
  double get profit => r.v[7];
  double get margin => rev.abs() < 1 ? 0 : profit / rev * 100;
  double? get prevRev => prev == null ? null : prev!.v[0] * k;
  double? get prevProfit => prev == null ? null : prev!.v[7] * k;
  double? get yoy => prevRev == null || prevRev!.abs() < 1 ? null : (rev - prevRev!) / prevRev!.abs() * 100;
}

/// 事業ごとの損益の行（並べ方つき）
List<SegRow> segRows(Game s, int y, String sort) {
  final cur = s.finYear(y);
  if (cur == null) return [];
  final p = s.finYear(y - 1);
  final k = p == null || p.n == 0 ? 1.0 : cur.n / p.n;
  final rows = [for (final e in cur.biz.entries) SegRow(e.key, e.value, p?.biz[e.key], k)];
  int cmp(double a, double b) => b.compareTo(a);
  rows.ssort((a, b) => switch (sort) {
        'rev' => cmp(a.rev, b.rev),
        'margin' => cmp(a.margin, b.margin),
        'yoy' => cmp(a.yoy ?? -1e9, b.yoy ?? -1e9),
        _ => cmp(a.profit, b.profit),
      });
  return rows;
}

/// はじめに出す事業の数（残りは「もっと見る」）
const segFew = 6;

/// 横に全部の列を出す最小の幅（狭いと、原価・人件費などは行を押して開く）
const segWideMin = 640.0;

List<Widget> segView(GameController ctl) {
  final s = ctl.game!;
  final out = <Widget>[];
  final y = finSelYear(ctl);
  if (y == null || s.finYear(y) == null || s.finYear(y)!.biz.isEmpty) {
    out.add(Panel(key: const ValueKey('seg-empty'), child: Muted(tr('まだ締めた月がありません。月を進めると、事業ごとの損益が記録されます'))));
    return out;
  }
  final cur = s.finYear(y)!;
  out.add(ChipRow('seg-sort', tr('並べ方'), [
    for (final t in const [('profit', '利益'), ('rev', '売上'), ('margin', '利益率'), ('yoy', '売上の伸び')])
      PickChip(tr(t.$2), key: ValueKey('seg-sort-${t.$1}'), on: ctl.segSort == t.$1, onTap: () => ctl.setFs(sort: t.$1)),
  ]));
  final rows = segRows(s, y, ctl.segSort);
  final byProfit = rows.toList()..ssort((a, b) => b.profit.compareTo(a.profit));
  final best = byProfit.first, worst = byProfit.last;
  final totalPro = rows.fold(0.0, (a, r) => a + r.profit);
  final ownLabor = rows.where((r) => r.r.co == null).fold(0.0, (a, r) => a + r.labor);
  final pay = cur.g('labor') - ownLabor, hq = cur.g('hq');
  // 稼ぎ頭と、足を引っ張る事業（表の上に置く）
  final summary = Column(
    key: const ValueKey('seg-sum'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHead(tr('事業ごとの損益'), Icons.stacked_bar_chart,
          tone: ScreenTone.money, trailing: Row(mainAxisSize: MainAxisSize.min, children: [Info(ctl, const ['seg']), finYearStep(ctl, 'seg')])),
      Wrap(spacing: 14, runSpacing: 2, children: [
        Row(mainAxisSize: MainAxisSize.min, key: const ValueKey('seg-best'), children: [
          const Icon(Icons.star, size: 16, color: Pal.gold),
          const SizedBox(width: 3),
          Flexible(
              child: Text(tr('稼ぎ頭：{0}（利益 {1}・事業の利益の{2}%）', [segName(best.r), yen(best.profit), totalPro > 0 ? pctD(best.profit / totalPro * 100) : '―']),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(size: 12.5, bold: true, color: Pal.goldtx))),
        ]),
        if (worst.profit < 0)
          Row(mainAxisSize: MainAxisSize.min, key: const ValueKey('seg-worst'), children: [
            const Icon(Icons.trending_down, size: 16, color: Pal.down),
            const SizedBox(width: 3),
            Flexible(
                child: Text(tr('足を引っ張る：{0}（赤字 {1}）', [segName(worst.r), yen(worst.profit)]),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(size: 12.5, bold: true, color: Pal.down))),
          ])
        else
          Row(mainAxisSize: MainAxisSize.min, key: const ValueKey('seg-low'), children: [
            const Icon(Icons.trending_flat, size: 16, color: Pal.mute),
            const SizedBox(width: 3),
            Flexible(
                child: Text(tr('赤字の事業はありません。利益がいちばん少ないのは{0}（{1}）', [segName(worst.r), yen(worst.profit)]),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(size: 12.5, color: Pal.mute))),
          ]),
      ]),
      const SizedBox(height: 4),
    ],
  );
  final open = ctl.shown.contains('seg-all');
  final shown = open ? rows : rows.take(segFew).toList();
  out.add(LayoutBuilder(builder: (context, c) {
    final wide = c.maxWidth >= segWideMin;
    Widget head(String t, {double w = 0}) => finCell(tr(t), c: Pal.mute, size: 11, w: w);
    final nameW = Ui.sw(wide ? 120 : 112);
    final lines = <Widget>[
      summary,
      Row(children: [
        SizedBox(width: nameW, child: Muted(tr('事業'), size: 11)),
        head('売上'),
        if (wide) head('原価'),
        head('粗利'),
        if (wide) ...[head('人件費'), head('家賃'), head('広告'), head('その他')] else head('経費'),
        head('利益'),
        head('利益率', w: Ui.sw(48)),
        // 前年比は売上の（下の注に書く）。列が狭いので見出しは短く
        head('前年比', w: Ui.sw(wide ? 64 : 58)),
      ]),
    ];
    for (final r in shown) {
      final loss = r.profit < 0, top = r == best && best.profit > 0;
      final det = ctl.shown.contains('seg-${r.key}');
      final kind = segKind(r.r);
      final yoy = r.yoy;
      final row = Container(
        key: ValueKey('seg-row-${r.key}'),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
            color: loss
                ? const Color(0xFFFDECEC)
                : top
                    ? Pal.goldBg
                    : null,
            border: const Border(bottom: BorderSide(color: Pal.line))),
        child: Row(children: [
          SizedBox(
            width: nameW,
            child: Row(children: [
              if (top) const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.star, size: 13, color: Pal.gold)),
              if (loss) const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.trending_down, size: 13, color: Pal.down)),
              Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(segName(r.r), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 12, bold: top || loss)),
                if (kind != null) Text(kind, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 10, color: Pal.mute)),
              ])),
            ]),
          ),
          finCell(yen(r.rev)),
          if (wide) finCell(yen(r.cogs), c: Pal.mute),
          finCell(yen(r.gross), c: r.gross < 0 ? Pal.down : Pal.ink),
          if (wide) ...[finCell(yen(r.labor), c: Pal.mute), finCell(yen(r.rent), c: Pal.mute), finCell(yen(r.ad), c: Pal.mute), finCell(yen(r.other), c: Pal.mute)] else finCell(yen(r.cost), c: Pal.mute),
          finCell(yen(r.profit), bold: true, c: loss ? Pal.down : Pal.up),
          finCell('${pctD(r.margin)}%', w: Ui.sw(48), c: r.margin < 0 ? Pal.down : Pal.ink),
          finCell(yoy == null ? tr('新規') : '${yoy > 0 ? '+' : ''}${pctD(yoy.clamp(-999, 999))}%', w: Ui.sw(wide ? 64 : 58), c: yoy == null ? Pal.mute : (yoy >= 0 ? Pal.up : Pal.down)),
        ]),
      );
      lines.add(wide ? row : Semantics(button: true, expanded: det, child: InkWell(onTap: () => ctl.toggleShown('seg-${r.key}'), child: row)));
      if (!wide && det) {
        lines.add(Container(
          key: ValueKey('seg-det-${r.key}'),
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 6),
          color: Pal.panel2,
          child: Wrap(spacing: 14, runSpacing: 2, children: [
            for (final x in [('原価', r.cogs), ('人件費', r.labor), ('家賃', r.rent), ('広告', r.ad), ('その他', r.other)])
              Text('${tr(x.$1)} ${yen(x.$2)}', style: ts(size: 11.5, color: Pal.mute)),
            if (r.prevProfit != null) Text(tr('前の年の利益 {0}', [yen(r.prevProfit!)]), style: ts(size: 11.5, color: Pal.mute)),
          ]),
        ));
      }
    }
    if (rows.length > segFew) lines.add(MoreBtn(key: const ValueKey('seg-more'), open: open, rest: rows.length - segFew, onTap: () => ctl.toggleShown('seg-all')));
    // 事業に配らない費用と、合計（本業の利益）
    Widget tot(String id, String label, double v, {bool bold = false}) => Container(
          key: ValueKey(id),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: bold ? const BoxDecoration(color: Pal.goldBg) : Ui.rowLine,
          child: Row(children: [
            Expanded(child: Text(label, maxLines: 2, style: ts(size: 12, bold: bold))),
            Text(yen(v), style: ts(size: 12.5, bold: true, color: v < 0 ? Pal.down : Pal.ink)),
          ]),
        );
    lines.add(const SizedBox(height: 4));
    lines.add(tot('seg-total', tr('事業の利益の合計'), totalPro));
    lines.add(tot('seg-unalloc', tr('部下の給料・本社の経費（事業に配らない分）'), -(pay + hq)));
    lines.add(tot('seg-core', tr('本業の利益（減価償却・利息・開発などの前）'), totalPro - pay - hq, bold: true));
    return Panel(
        key: const ValueKey('seg-table'), padding: const EdgeInsets.fromLTRB(Ui.pad, 8, Ui.pad, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines));
  }));
  out.add(Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Muted(
          finJoin([
            tr('事業の利益は、売上から原価・人件費・家賃・広告などを引いたもの。子会社・現地法人は持ち分の分です。'),
            tr('売上の前年比は、前の年を同じ月の数に直して比べています。幅が狭いときは、行を押すと原価・人件費などが開きます。'),
          ]),
          key: const ValueKey('seg-note'),
          size: 11.5)));
  return out;
}
