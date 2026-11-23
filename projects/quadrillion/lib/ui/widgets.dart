import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 試作の :root の配色（明るい紙色）
class Pal {
  static const sky = Color(0xFFF5F2EA);
  static const panel = Color(0xFFFFFFFF);
  static const panel2 = Color(0xFFF1ECE0);
  static const line = Color(0xFFDDD4C0);
  static const ink = Color(0xFF1F2433);
  static const mute = Color(0xFF6A7080);
  static const gold = Color(0xFFF2C14E);
  static const goldtx = Color(0xFF9A6500);
  static const teal = Color(0xFF138F86);
  static const up = Color(0xFF1D8A4C);
  static const down = Color(0xFFD23F3F);
  static const warn = Color(0xFFB86E00);
  static const goldBg = Color(0xFFFFF6DC);
  static const onBg = Color(0xFFFFF3CF);
}

const List<String> faceCols = ['#f2c14e', '#4fd1c5', '#9fb3ff', '#ff8f8f', '#c9a0ff', '#7ff0c8', '#ffb454', '#a0e6ff'];

Color hexColor(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$s', radix: 16));
}

/// WCAG の相対輝度
double relLuminance(Color c) {
  double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

/// WCAG のコントラスト比（1〜21）
double contrastRatio(Color a, Color b) {
  final la = relLuminance(a), lb = relLuminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// 宿敵の色を、白いカードと紙色の背景のどちらの上でも文字として読める濃さ（コントラスト比 4.5 以上）まで暗くする。
/// 色味（色相・彩度）は変えない。顔の丸の塗りは元の色のまま使う
Color rivalInk(String col) {
  var hsl = HSLColor.fromColor(hexColor(col));
  bool ok(Color c) => contrastRatio(c, Pal.panel) >= 4.5 && contrastRatio(c, Pal.sky) >= 4.5;
  while (!ok(hsl.toColor()) && hsl.lightness > 0) {
    hsl = hsl.withLightness(math.max(0, hsl.lightness - .01));
  }
  return hsl.toColor();
}

const fontFamily = 'NotoSansJP';
const _tab = [FontFeature.tabularFigures()];

TextStyle ts({double size = 14, Color color = Pal.ink, bool bold = false, double? height}) =>
    TextStyle(fontFamily: fontFamily, fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, height: height, fontFeatures: _tab);

/// 見た目の決まり（カード・小窓・ボタンの角の丸み、枠、影、余白、見出しの字）。
/// 画面ごとに数字を直書きせず、ここから取る
class Ui {
  /// カード（白い箱・絵の枠・たたんだ行・案内の帯）の角の丸み
  static const rCard = 12.0;

  /// 小窓の角の丸み
  static const rSheet = 18.0;

  /// ボタン・入力欄・選ぶ欄の角の丸み
  static const rBtn = 8.0;

  /// カードの中の箱（吹き出し・知らせの帯）の角の丸み
  static const rBox = 10.0;

  /// カードの内側の余白
  static const pad = 12.0;

  /// 小窓の内側の余白
  static const sheetPad = 16.0;

  /// カードどうしの上下のすきま（片側）
  static const cardGap = 4.0;

  /// カードのごく薄い影
  static const shadow = [BoxShadow(color: Color(0x0F1F2433), blurRadius: 6, offset: Offset(0, 1))];

  /// 小窓の影（後ろの画面から浮かせる）
  static const sheetShadow = [BoxShadow(color: Color(0x261F2433), blurRadius: 18, offset: Offset(0, 4))];

  /// 小窓の後ろの幕
  static const scrim = Color(0x59282832);

  /// 小窓が出入りする時間の決まり
  static const sheetMotionDefault = Duration(milliseconds: 220);

  /// 小窓が出入りする時間（今の値。もとからあるテストは0に差し替えている）
  static Duration sheetMotion = sheetMotionDefault;

  /// 見出し（h2）・カードの見出し・小見出し（h3）の字
  static TextStyle get h2 => ts(size: 17, color: Pal.goldtx, bold: true);
  static TextStyle cardTitle({bool gold = false}) => ts(size: 14, color: gold ? Pal.goldtx : Pal.ink, bold: true);
  static TextStyle get h3 => ts(bold: true);

  /// 欄の中の1行の下の線
  static const rowLine = BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line)));
}

/// カードの見た目（白い面・1px の枠・角の丸み・ごく薄い影）
BoxDecoration cardDeco({Color border = Pal.line, Color color = Pal.panel, double radius = Ui.rCard, bool shadow = true}) => BoxDecoration(
    color: color, border: Border.all(color: border), borderRadius: BorderRadius.circular(radius), boxShadow: shadow ? Ui.shadow : null);

/// カードの中の箱の見た目（吹き出しなど。枠なしの薄い面、または枠つき）
BoxDecoration boxDeco({Color color = Pal.panel2, Color? border}) =>
    BoxDecoration(color: color, border: border == null ? null : Border.all(color: border), borderRadius: BorderRadius.circular(Ui.rBox));

/// ボタン・選ぶ欄の形
ShapeBorder btnShape(Color border) => RoundedRectangleBorder(side: BorderSide(color: border), borderRadius: BorderRadius.circular(Ui.rBtn));

/// 見出し（試作の h2）
class H2 extends StatelessWidget {
  final String text;
  final bool top;
  const H2(this.text, {super.key, this.top = false});
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: top ? 0 : 18, bottom: 8), child: Text(tx(text), style: Ui.h2));
}

/// 小見出し（h3）
class H3 extends StatelessWidget {
  final String text;
  const H3(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(tx(text), style: Ui.h3));
}

/// カードの見出し（[gold] は社長の行動・番頭のひとことなど、目立たせる欄）
class CardTitle extends StatelessWidget {
  final String text;
  final bool gold;
  const CardTitle(this.text, {super.key, this.gold = false});
  @override
  Widget build(BuildContext context) => Text(tx(text), style: Ui.cardTitle(gold: gold));
}

/// 白いカード
class Panel extends StatelessWidget {
  final Widget child;
  final Color border;
  final EdgeInsets padding;
  final Color color;
  const Panel({super.key, required this.child, this.border = Pal.line, this.padding = const EdgeInsets.all(Ui.pad), this.color = Pal.panel});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: Ui.cardGap),
        padding: padding,
        decoration: cardDeco(border: border, color: color),
        child: child,
      );
}

/// 押せるカード（たたんだ事業の行・案内の帯）。見た目は [Panel] と同じで、全体が押せる
class TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color border, color;
  final Key? inkKey;
  final EdgeInsets margin;
  const TapCard(
      {super.key,
      required this.child,
      this.onTap,
      this.border = Pal.line,
      this.color = Pal.panel,
      this.inkKey,
      this.margin = const EdgeInsets.symmetric(vertical: Ui.cardGap)});
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: cardDeco(border: border, color: color),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(key: inkKey, borderRadius: BorderRadius.circular(Ui.rCard), onTap: onTap, child: child),
        ),
      );
}

/// 絵やグラフの枠（カードと同じ角・枠・影。中身は角で切る）
class Frame extends StatelessWidget {
  final Widget child;
  const Frame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardDeco(border: Colors.transparent),
        foregroundDecoration: BoxDecoration(border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(Ui.rCard)),
        child: ClipRRect(borderRadius: BorderRadius.circular(Ui.rCard), child: child),
      );
}

/// 手を使う数の小さな札（「1手」）
class ApTag extends StatelessWidget {
  final int n;
  const ApTag(this.n, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: Pal.panel, border: Border.all(color: Pal.gold), borderRadius: BorderRadius.circular(99)),
        child: Text(n == 1 ? tr('1手') : tr('{0}手', [n]), maxLines: 1, softWrap: false, style: ts(size: 10.5, color: Pal.goldtx, bold: true, height: 1.5)),
      );
}

/// 上に並べる選ぶ札（並べ替え・絞り込み）。見た目は高さ32、押せる範囲は 44pt
class PickChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  /// 押すと選ぶ小窓が開く札（後ろに下向きの印を付ける）
  final bool more;
  const PickChip(this.label, {super.key, required this.on, required this.onTap, this.more = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: TapArea(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: EdgeInsets.only(left: on ? 8 : 12, right: more ? 4 : 12),
            decoration: BoxDecoration(
                color: on ? Pal.onBg : Pal.panel, border: Border.all(color: on ? Pal.gold : Pal.line), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (on) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.check, size: 15, color: Pal.goldtx)),
              // 行より長い札は、字だけを縮める（押せる範囲は縮めない）
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false, style: ts(size: 12.5, color: on ? Pal.goldtx : Pal.ink, bold: on)))),
              if (more) Icon(Icons.arrow_drop_down, size: 20, color: on ? Pal.goldtx : Pal.mute),
            ]),
          ),
        ),
      );
}

/// 札の列（左に小さな見出し）。札は横に流さず、入りきらなければ次の行へ折り返して、全部がいつも見える。
/// 1枚の札が行より長いときは、その札の字だけを縮める
class ChipRow extends StatelessWidget {
  final String id, label;
  final List<Widget> chips;
  const ChipRow(this.id, this.label, this.chips, {super.key});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 見出しは1行目の札と高さをそろえる
        Container(
            constraints: const BoxConstraints(minWidth: 52, minHeight: minTap),
            alignment: Alignment.centerLeft,
            child: Muted(label, size: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
              builder: (context, c) => Wrap(key: ValueKey('chips-$id'), spacing: 6, runSpacing: 0, children: [
                    for (final chip in chips) ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth), child: chip),
                  ])),
        ),
      ]);
}

/// たためる欄の見出し（h2 と同じ字。右に開閉の印と、たたんだときの件数）。行のどこを押しても開閉する
class FoldHead extends StatelessWidget {
  final String text;
  final bool open;
  final VoidCallback onTap;

  /// たたんでいるときに右に出す短い文（「4社」など）
  final String? note;
  const FoldHead(this.text, {super.key, required this.open, required this.onTap, this.note});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            borderRadius: BorderRadius.circular(Ui.rBtn),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: minTap),
              child: Row(children: [
                Expanded(child: Text(tx(text), style: Ui.h2)),
                if (note != null && !open) Padding(padding: const EdgeInsets.only(right: 4), child: Muted(note!, size: 12.5)),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 24, color: Pal.goldtx),
              ]),
            ),
          ),
        ),
      );
}

/// 能力の細い棒（0〜99）。値が幅でしか分かっていないときは、その幅を薄い帯で見せる
class AbBar extends StatelessWidget {
  final int lo, hi;
  const AbBar(this.lo, this.hi, {super.key});

  /// 棒の高さ
  static const h = 4.0;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(h / 2),
        child: SizedBox(
          height: h,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            double x(int v) => w * v.clamp(0, 99) / 99;
            return Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Pal.panel2)),
              if (lo == hi)
                Positioned(left: 0, top: 0, bottom: 0, width: x(lo), child: const ColoredBox(key: ValueKey('ab-fill'), color: Pal.gold))
              else ...[
                // 確かな分（下の値まで）は金、まだ分からない幅は薄い帯
                Positioned(left: 0, top: 0, bottom: 0, width: x(lo), child: const ColoredBox(key: ValueKey('ab-fill'), color: Pal.gold)),
                Positioned(left: x(lo), top: 0, bottom: 0, width: x(hi) - x(lo), child: const ColoredBox(key: ValueKey('ab-band'), color: Color(0x66F2C14E))),
              ],
            ]);
          }),
        ),
      );
}

/// 能力の1つ（名前と数字の下に細い棒）
class AbKv extends StatelessWidget {
  final String k, text;
  final int lo, hi;
  const AbKv(this.k, this.text, this.lo, this.hi, {super.key});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Kv(k, text),
        const SizedBox(height: 2),
        Semantics(label: '$k $text', child: AbBar(lo, hi)),
      ]);
}

/// 株主の割合の棒に、節目の線（33.4%・50%・66.7%）と小さな字の印を重ねたもの
class MarkBar extends StatelessWidget {
  final List<(double, Color)> parts;
  final double height;
  const MarkBar(this.parts, {super.key, this.height = 14});

  /// 節目（合併を止められる・社長を替えられる・合併も自由）
  static const marks = [33.4, 50.0, 66.7];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        const labelW = 44.0;
        return SizedBox(
          height: height + 4 + 15,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(left: 0, right: 0, top: 2, child: Bar(parts, height: height)),
            for (final m in marks) ...[
              // 線は棒の上下に少しはみ出させて、どの色の上でも見えるよう白で縁取る
              Positioned(
                  key: ValueKey('mark-$m'),
                  left: w * m / 100 - 1.5,
                  top: 0,
                  width: 3,
                  height: height + 4,
                  child: Container(
                      decoration: BoxDecoration(color: Pal.ink, border: Border.all(color: Pal.panel, width: .75), borderRadius: BorderRadius.circular(1.5)))),
              Positioned(
                  left: w * m / 100 - labelW / 2,
                  top: height + 4,
                  width: labelW,
                  child: Text('${m == 50 ? '50' : m}%', key: ValueKey('mark-label-$m'), textAlign: TextAlign.center, maxLines: 1, softWrap: false, style: ts(size: 10.5, color: Pal.mute, height: 1.3))),
            ],
          ]),
        );
      });
}

/// 検索の欄（名前で絞る）
class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.controller, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Ui.rBtn), borderSide: BorderSide(color: c, width: w));
    // 欄の中の字の横の位置も、外側の一覧の位置と取り違えないように名前を付ける
    return ConstrainedBox(
      key: const PageStorageKey<String>('search-box'),
      constraints: const BoxConstraints(minHeight: minTap),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        autocorrect: false,
        style: ts(size: 14),
        cursorColor: Pal.goldtx,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Pal.panel,
          hintText: hint,
          hintStyle: ts(size: 14, color: Pal.mute),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          prefixIcon: const Icon(Icons.search, size: 20, color: Pal.mute),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: minTap),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('search-clear'),
                  tooltip: tr('検索を消す'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: minTap, minHeight: minTap),
                  icon: const Icon(Icons.close, size: 18, color: Pal.mute),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: minTap, minHeight: minTap),
          enabledBorder: b(Pal.line),
          focusedBorder: b(Pal.gold, 1.5),
          border: b(Pal.line),
        ),
      ),
    );
  }
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  const Muted(this.text, {super.key, this.size = 12.5});
  @override
  Widget build(BuildContext context) => Text(tx(text), style: ts(size: size, color: Pal.mute));
}

/// 左に名前、右に値。名前も値も1行に収める。
/// 名前は折り返さずにそのままの幅を取り（欄の [labelShare] まで）、値は残りの幅に右寄せで置く。
/// どちらも入りきらないときだけ、字を少し縮める（折り返さない）
class Kv extends StatelessWidget {
  final String k;
  final Object v;
  const Kv(this.k, this.v, {super.key});

  /// 名前が取ってよい幅の割合
  static const labelShare = .64;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final label = Text(tx(k), key: const ValueKey('kv-label'), maxLines: 1, softWrap: false, style: ts(size: 13, color: Pal.mute));
        final value = v is Widget ? v as Widget : Text(v is String ? tx(v as String) : '$v', maxLines: 1, softWrap: false, style: ts(size: 13));
        return Row(children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth.isFinite ? c.maxWidth * labelShare : double.infinity),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: label),
          ),
          const SizedBox(width: 6),
          Expanded(child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: value))),
        ]);
      });
}

/// 2列に並べる（試作の grid2）
class Grid2 extends StatelessWidget {
  final List<Widget> children;
  const Grid2(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: children[i]),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

enum TagKind { plain, good, bad, gold }

class Tag extends StatelessWidget {
  final String text;
  final TagKind kind;
  const Tag(this.text, {super.key, this.kind = TagKind.plain});
  @override
  Widget build(BuildContext context) {
    final c = switch (kind) { TagKind.good => Pal.up, TagKind.bad => Pal.down, TagKind.gold => Pal.goldtx, _ => Pal.mute };
    final bc = switch (kind) { TagKind.good => Pal.up, TagKind.bad => Pal.down, TagKind.gold => Pal.gold, _ => Pal.line };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
          color: kind == TagKind.gold ? Pal.goldBg : null, border: Border.all(color: bc), borderRadius: BorderRadius.circular(99)),
      child: Text(tx(text), style: ts(size: 11.5, color: c)),
    );
  }
}

/// 丸い顔（名前の1文字目）
class Face extends StatelessWidget {
  final String name;
  final String? col;
  const Face(this.name, {super.key, this.col});
  @override
  Widget build(BuildContext context) {
    final n = nmL(name).replaceAll(RegExp(r'\s'), '');
    final c = col ?? faceCols[(n.isEmpty ? 63 : n.codeUnitAt(0)) % faceCols.length];
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: hexColor(c), shape: BoxShape.circle),
      child: Text(n.isEmpty ? '?' : n.characters.first, style: ts(size: 14, bold: true, color: const Color(0xFF0D1426))),
    );
  }
}

/// 役割の印の丸（株主の代表・銀行・取締役など、名前の無い話し手）
class RoleFace extends StatelessWidget {
  final String kind;
  const RoleFace(this.kind, {super.key});
  @override
  Widget build(BuildContext context) {
    final (icon, col) = switch (kind) {
      'bank' => (Icons.account_balance, const Color(0xFF9FB3FF)),
      'board' => (Icons.gavel, const Color(0xFFC9A0FF)),
      _ => (Icons.pie_chart, const Color(0xFF7FF0C8)),
    };
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: const Color(0xFF0D1426)),
    );
  }
}

/// 会議の発言者1人（顔の丸＋名前と肩書き＋言ったこと）
class VoiceSay extends StatelessWidget {
  final String? name;
  final String who, role, kind, say;
  const VoiceSay({super.key, this.name, required this.who, required this.role, required this.kind, required this.say});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          name != null ? Face(name!) : RoleFace(kind),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: boxDeco(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: tx(who), style: ts(size: 12.5, bold: true)),
                  TextSpan(text: '  ${tx(role)}', style: ts(size: 12, color: Pal.mute)),
                ])),
                const SizedBox(height: 2),
                Text(tx(say), style: ts(size: 13.5, height: 1.45)),
              ]),
            ),
          ),
        ]),
      );
}

/// 押せる部品の最小の大きさ（Apple の目安 44pt）
const minTap = 44.0;

/// 見た目の大きさは変えずに、押せる範囲だけ [minTap] 四方まで広げる。
/// 見た目の外側（透明な余白）を押しても [onTap] が動く
class TapArea extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const TapArea({super.key, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: minTap, minHeight: minTap),
          child: Align(widthFactor: 1, heightFactor: 1, child: child),
        ),
      );
}

/// ふつうのボタン
class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary, small;
  final bool enabled;

  /// 幅が足りないときは字だけを縮める（押せる範囲は縮めない）
  final bool shrink;

  /// 押すと選ぶ小窓が開くボタン（後ろに「›」の印を付ける）
  final bool more;

  /// 使う手の数（1以上なら「1手」の小さな札を付ける）
  final int ap;

  /// 薄く見せるが押せる（押すと「今月の手が残っていません」などを出す）
  final bool dim;

  /// 手の札を字の下に置く（幅の狭い列のボタン用）
  final bool apBelow;
  const Btn(this.label, this.onTap,
      {super.key,
      this.primary = false,
      this.small = false,
      this.enabled = true,
      this.shrink = false,
      this.more = false,
      this.ap = 0,
      this.dim = false,
      this.apBelow = false});
  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    final text = Text(tx(label),
        maxLines: shrink ? 1 : null, style: ts(size: small ? 12.5 : 14, bold: primary, color: primary ? const Color(0xFF1A1300) : Pal.ink));
    return TapArea(
      onTap: on ? onTap : null,
      child: Opacity(
      opacity: on && !dim ? 1 : .4,
      child: Material(
        color: primary ? Pal.gold : Pal.panel2,
        shape: btnShape(primary ? Pal.gold : Pal.line),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ui.rBtn),
          onTap: on ? onTap : null,
          child: Padding(
            padding: small ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: _fit(ap > 0 && apBelow
                ? Column(mainAxisSize: MainAxisSize.min, children: [text, const SizedBox(height: 1), ApTag(ap)])
                : more || ap > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: text),
                    if (ap > 0) Padding(padding: const EdgeInsets.only(left: 5), child: ApTag(ap)),
                    if (more) Icon(Icons.chevron_right, size: small ? 16 : 18, color: Pal.mute),
                  ])
                : text),
          ),
        ),
      ),
    ));
  }

  Widget _fit(Widget t) => shrink ? FittedBox(fit: BoxFit.scaleDown, child: t) : t;
}

/// 取り返しのつかない操作のボタン（赤）
class DangerBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const DangerBtn(this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => TapArea(
      onTap: onTap,
      child: Material(
        color: Pal.down,
        shape: btnShape(Pal.down),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ui.rBtn),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(tx(label), style: ts(bold: true, color: Pal.panel)),
          ),
        ),
      ));
}

/// 選択肢のボタン（左寄せ・下に小さな説明）
class ChoiceBtn extends StatelessWidget {
  final String label;
  final List<String> subs;
  final VoidCallback? onTap;
  final bool enabled, primary, on;

  /// 薄く見せるが押せる（押すと「お金が足りません」などを出す）
  final bool dim;

  /// 使う手の数（1以上なら右上に「1手」の小さな札を付ける）
  final int ap;
  const ChoiceBtn(this.label, this.onTap,
      {super.key, this.subs = const [], this.enabled = true, this.primary = false, this.on = false, this.dim = false, this.ap = 0});
  @override
  Widget build(BuildContext context) {
    final ok = enabled && onTap != null;
    final title = Text(tx(label), style: ts(bold: primary, color: primary ? const Color(0xFF1A1300) : Pal.ink, height: 1.45));
    return Opacity(
      opacity: ok && !dim ? 1 : .4,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: primary
              ? Pal.gold
              : on
                  ? Pal.onBg
                  : Pal.panel2,
          shape: btnShape(primary || on ? Pal.gold : Pal.line),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ui.rBtn),
            onTap: ok ? onTap : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: minTap),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (ap > 0) Row(children: [Expanded(child: title), const SizedBox(width: 6), ApTag(ap)]) else title,
                for (final s in subs)
                  if (s.isNotEmpty) Text(tx(s), style: ts(size: 12, color: primary ? const Color(0xFF3A2E00) : Pal.mute, height: 1.4)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顔＋吹き出し
class Say extends StatelessWidget {
  final Widget face;
  final String who;
  final String text;
  const Say({super.key, required this.face, required this.who, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          face,
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: boxDeco(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx(who), style: ts(size: 12, color: Pal.mute)),
                Text(tx(text), style: ts(size: 13)),
              ]),
            ),
          ),
        ]),
      );
}

/// ニュースの1行。左の線の色で大事さ（大きな知らせ・悪い・良い）を見せ、[icon] があれば種類のアイコンも付ける
class NewsLine extends StatelessWidget {
  final String text;
  final String kind;
  final String? prefix;

  /// 種類のアイコン（時代の事件・宿敵・社内・人・良い知らせ・悪い知らせ）
  final IconData? icon;
  const NewsLine(this.text, this.kind, {super.key, this.prefix, this.icon});

  /// 大事さの色（線）
  static Color lineColor(String kind) => switch (kind) { 'big' => Pal.gold, 'bad' => Pal.down, 'good' => Pal.up, _ => Pal.line };

  /// アイコンの色（白い面の上で見える濃さ）
  static Color iconColor(String kind) => switch (kind) { 'big' => Pal.goldtx, 'bad' => Pal.down, 'good' => Pal.up, _ => Pal.mute };

  @override
  Widget build(BuildContext context) {
    final body = Text.rich(TextSpan(children: [
      if (prefix != null) TextSpan(text: prefix, style: ts(size: 13, color: Pal.mute)),
      TextSpan(text: tx(text), style: ts(size: 13)),
    ]));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.only(left: icon != null ? 6 : 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: lineColor(kind), width: 2))),
      child: icon == null
          ? body
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2, right: 6), child: Icon(icon, size: 16, color: iconColor(kind))),
              Expanded(child: body),
            ]),
    );
  }
}

/// 割合の棒（いくつかの色を並べる）
class Bar extends StatelessWidget {
  final List<(double, Color)> parts;
  final double height;
  const Bar(this.parts, {super.key, this.height = 8});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: Pal.line,
          child: LayoutBuilder(builder: (context, c) {
            return Row(children: [
              for (final p in parts) Container(width: c.maxWidth * (p.$1.clamp(0, 100) / 100), color: p.$2),
            ]);
          }),
        ),
      );
}

/// 小さな選択（試作の select）
class Pick<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const Pick({super.key, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: Pal.panel2, border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(Ui.rBtn)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: items.any((e) => e.$1 == value) ? value : items.first.$1,
            isExpanded: true,
            // 押せる高さを 44pt 以上にする（isDense だと 24pt ほどしかない）
            isDense: false,
            style: ts(size: 13),
            items: [for (final e in items) DropdownMenuItem<T>(value: e.$1, child: Text(tx(e.$2), overflow: TextOverflow.ellipsis, style: ts(size: 13)))],
            onChanged: (v) {
              if (v is T) onChanged(v);
            },
          ),
        ),
      );
}

/// 金額などに色を付けて出す
Text colored(String s, Color c, {double size = 13, bool bold = false}) => Text(tx(s), style: ts(size: size, color: c, bold: bold));

/// 上の帯の数字。月を進めて値が変わったとき、0.6秒ほど緑（よくなった）か赤（悪くなった）にふわっと光る
class FlashStat extends StatefulWidget {
  final String label, text;
  final Color color;
  final double value;
  final int turn;
  final bool higherIsBetter;
  const FlashStat(this.label, this.text,
      {super.key, required this.value, required this.turn, this.color = Pal.ink, this.higherIsBetter = true});
  @override
  State<FlashStat> createState() => _FlashStatState();
}

class _FlashStatState extends State<FlashStat> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  bool _good = true;

  @override
  void didUpdateWidget(FlashStat old) {
    super.didUpdateWidget(old);
    if (old.turn != widget.turn && old.value != widget.value) {
      _good = (widget.value > old.value) == widget.higherIsBetter;
      _a.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(TextSpan(children: [
      TextSpan(text: tx(widget.label), style: ts(size: 12.5, color: Pal.mute)),
      TextSpan(text: widget.text, style: ts(size: 12.5, color: widget.color, bold: true)),
    ]));
    return AnimatedBuilder(
      animation: _a,
      child: text,
      builder: (context, child) {
        // 上がって下がる山形（はじめ速く光り、ゆっくり消える）
        final t = _a.value;
        final glow = _a.isAnimating ? math.sin(math.pi * math.pow(t, .6)) : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: (_good ? Pal.up : Pal.down).withValues(alpha: .22 * glow),
            borderRadius: BorderRadius.circular(4),
            boxShadow: glow > 0 ? [BoxShadow(color: (_good ? Pal.up : Pal.down).withValues(alpha: .25 * glow), blurRadius: 6 * glow)] : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// 横に並べた切り替え（図鑑の「シナジー・業種・実績」）。1つが 44pt の高さで、選んでいるものは金
class Segments extends StatelessWidget {
  /// （id・名前）
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;

  /// 鍵の頭（「zukan」なら zukan-syn など）
  final String id;
  const Segments(this.id, this.items, {super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Pal.panel2, border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(Ui.rBtn + 3)),
        child: Row(children: [
          for (final e in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == e.$1,
                child: Material(
                  color: value == e.$1 ? Pal.gold : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.rBtn)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('$id-${e.$1}'),
                    onTap: () => onChanged(e.$1),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: minTap),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(e.$2,
                              maxLines: 1, softWrap: false, style: ts(size: 13.5, bold: value == e.$1, color: value == e.$1 ? const Color(0xFF1A1300) : Pal.mute))),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// 進み具合の棒（「12 / 141」の数字つき）
class Progress extends StatelessWidget {
  final int done, total;
  final String label;
  const Progress(this.label, this.done, this.total, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(label, style: ts(size: 13, color: Pal.mute))),
            Text('$done / $total', key: const ValueKey('progress-count'), style: ts(size: 14, bold: true, color: Pal.goldtx)),
          ]),
          const SizedBox(height: 6),
          Semantics(label: '$label $done / $total', child: Bar([(total > 0 ? done * 100 / total : 0, Pal.gold)], height: 10)),
        ]),
      );
}

/// 金額の横棒（決算の内訳）。プラスは緑、マイナスは赤。長さは [frac]（0〜1。いちばん大きい額を1とした比）
class AmountBar extends StatelessWidget {
  final double frac;
  final bool minus;
  const AmountBar(this.frac, {super.key, required this.minus});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: Pal.panel2,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: frac.isFinite ? frac.clamp(0.0, 1.0) : 0, child: ColoredBox(color: minus ? Pal.down : Pal.up, child: const SizedBox.expand())),
        ),
      );
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 年と月（日本語は「1980年1月」、[sp] なら「1980年 1月」。英語は「Jan 1980」）
String ym(int y, int q, {bool sp = false}) => L.en ? '${_mon[(q - 1).clamp(0, 11)]} $y' : (sp ? '$y年 $q月' : '$y年$q月');

/// 年（日本語は「1980年」、英語は「1980」）
String yearL(int y) => L.en ? '$y' : '$y年';
