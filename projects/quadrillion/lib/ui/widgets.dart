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

/// 見た目の決まり（カード・小窓・部品の角の丸み・余白・影・見出しの字）。
/// 画面のカードと小窓は、ここの値だけを使う（直書きの数を散らさない）
class Ui {
  Ui._();

  /// カードの角の丸み
  static const radius = 12.0;

  /// 小窓の角の丸み（カードより一回り大きく）
  static const sheetRadius = 16.0;

  /// ボタン・選択・札の中の囲みなど、小さな部品の角の丸み
  static const partRadius = 8.0;

  /// 吹き出しの角の丸み
  static const bubbleRadius = 10.0;

  /// カードの内側の余白
  static const pad = 14.0;

  /// 小窓の内側の余白
  static const sheetPad = 16.0;

  /// カードとカードのあいだ（上下それぞれ）
  static const cardGap = 5.0;

  /// 影は1段だけ（ごく薄く、真下に1pt）
  static const shadow = [BoxShadow(color: Color(0x141F2433), blurRadius: 4, offset: Offset(0, 1))];

  /// 小窓の影（浮いて見えるように、カードより少しだけ広く）
  static const sheetShadow = [BoxShadow(color: Color(0x241F2433), blurRadius: 18, offset: Offset(0, -2))];

  /// カードの囲み（白地・線・角丸12・影1段）
  static BoxDecoration card({Color border = Pal.line, Color color = Pal.panel, bool shadow = true}) => BoxDecoration(
      color: color, border: Border.all(color: border), borderRadius: BorderRadius.circular(radius), boxShadow: shadow ? Ui.shadow : null);

  /// カードの形（Material に渡す用）
  static RoundedRectangleBorder cardShape([Color border = Pal.line]) =>
      RoundedRectangleBorder(side: BorderSide(color: border), borderRadius: BorderRadius.circular(radius));

  /// 小さな部品の形
  static RoundedRectangleBorder partShape([Color border = Pal.line]) =>
      RoundedRectangleBorder(side: BorderSide(color: border), borderRadius: BorderRadius.circular(partRadius));

  /// 画面の見出し（h2）17・太字・金の字
  static TextStyle get h2 => ts(size: 17, color: Pal.goldtx, bold: true);

  /// カードの見出し 15・太字
  static TextStyle get title => ts(size: 15, bold: true, height: 1.3);

  /// 金の字のカードの見出し
  static TextStyle get titleGold => ts(size: 15, bold: true, color: Pal.goldtx, height: 1.3);

  /// 小見出し（h3）14・太字
  static TextStyle get h3 => ts(bold: true);
}

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
        decoration: Ui.card(border: border, color: color),
        child: child,
      );
}

/// 手を使う部品に添える小さな札（「1手」）
class ApBadge extends StatelessWidget {
  final int n;
  const ApBadge(this.n, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('ap-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: Pal.goldBg, border: Border.all(color: Pal.gold), borderRadius: BorderRadius.circular(4)),
        child: Text(tr(n == 1 ? '{0}手' : '{0}手@@pl', [n]), maxLines: 1, softWrap: false, style: ts(size: 10.5, bold: true, color: Pal.goldtx, height: 1.25)),
      );
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
              decoration: BoxDecoration(color: Pal.panel2, borderRadius: BorderRadius.circular(Ui.bubbleRadius)),
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

/// 手が足りない部品の薄さ（押せないときの .4 より少し濃くして、押せることは残す）
const apShortOpacity = .45;

/// ふつうのボタン
class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary, small;
  final bool enabled;

  /// 幅が足りないときは字だけを縮める（押せる範囲は縮めない）
  final bool shrink;

  /// 使う手の数（0 なら札を出さない）
  final int ap;

  /// 手が足りない（薄く見せる。押すと今までどおり「今月の手が残っていません」が出る）
  final bool apShort;
  const Btn(this.label, this.onTap,
      {super.key, this.primary = false, this.small = false, this.enabled = true, this.shrink = false, this.ap = 0, this.apShort = false});
  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    final text = Text(tx(label), maxLines: shrink ? 1 : null, style: ts(size: small ? 12.5 : 14, bold: primary, color: primary ? const Color(0xFF1A1300) : Pal.ink));
    final content = ap <= 0
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: text), const SizedBox(width: 6), ApBadge(ap)]);
    return TapArea(
      onTap: on ? onTap : null,
      child: Opacity(
      opacity: !on ? .4 : apShort ? apShortOpacity : 1,
      child: Material(
        color: primary ? Pal.gold : Pal.panel2,
        shape: Ui.partShape(primary ? Pal.gold : Pal.line),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ui.partRadius),
          onTap: on ? onTap : null,
          child: Padding(
            padding: small ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: _fit(content),
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
        shape: Ui.partShape(Pal.down),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ui.partRadius),
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

  /// 使う手の数（0 なら札を出さない）と、手が足りないか（薄く見せるが押せる）
  final int ap;
  final bool apShort;
  const ChoiceBtn(this.label, this.onTap,
      {super.key, this.subs = const [], this.enabled = true, this.primary = false, this.on = false, this.ap = 0, this.apShort = false});
  @override
  Widget build(BuildContext context) {
    final ok = enabled && onTap != null;
    final title = Text(tx(label), style: ts(bold: primary, color: primary ? const Color(0xFF1A1300) : Pal.ink, height: 1.45));
    return Opacity(
      opacity: !ok ? .4 : apShort ? apShortOpacity : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: primary
              ? Pal.gold
              : on
                  ? Pal.onBg
                  : Pal.panel2,
          shape: Ui.partShape(primary || on ? Pal.gold : Pal.line),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ui.partRadius),
            onTap: ok ? onTap : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: minTap),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                ap <= 0
                    ? title
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        Padding(padding: const EdgeInsets.only(top: 3), child: ApBadge(ap)),
                      ]),
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
              decoration: BoxDecoration(color: Pal.panel2, borderRadius: BorderRadius.circular(Ui.bubbleRadius)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx(who), style: ts(size: 12, color: Pal.mute)),
                Text(tx(text), style: ts(size: 13)),
              ]),
            ),
          ),
        ]),
      );
}

/// ニュースの1行（左の線の色で種類を見せる）
class NewsLine extends StatelessWidget {
  final String text;
  final String kind;
  final String? prefix;
  const NewsLine(this.text, this.kind, {super.key, this.prefix});
  @override
  Widget build(BuildContext context) {
    final c = switch (kind) { 'big' => Pal.gold, 'bad' => Pal.down, 'good' => Pal.up, _ => Pal.line };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 2))),
      child: Text.rich(TextSpan(children: [
        if (prefix != null) TextSpan(text: prefix, style: ts(size: 13, color: Pal.mute)),
        TextSpan(text: tx(text), style: ts(size: 13)),
      ])),
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
        decoration: BoxDecoration(color: Pal.panel2, border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(Ui.partRadius)),
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

/// 丸い札の形の選択（分類の絞り込みなど）。見た目は高さ32の札、押せる範囲は 44pt 四方以上
class SelChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  /// 選んでいるときに頭に付ける印（「始められるものだけ」のような入り切りの札）
  final IconData? icon;
  const SelChip(this.label, {super.key, required this.on, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minTap, minWidth: minTap),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 32,
                padding: EdgeInsets.only(left: icon != null ? 8 : 12, right: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? Pal.gold : Pal.panel,
                  border: Border.all(color: on ? Pal.gold : Pal.line),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(on ? icon : Icons.circle_outlined, size: 16, color: on ? const Color(0xFF1A1300) : Pal.mute), const SizedBox(width: 4)],
                  Text(tx(label), maxLines: 1, softWrap: false, style: ts(size: 13, bold: on, color: on ? const Color(0xFF1A1300) : Pal.ink)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// 分段の選択（並べ替えなど）。つながった帯の中から1つを選ぶ。1つの段の押せる高さは 44pt
class Segmented<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  /// 段ごとの部品の鍵の頭（テストで押す用）
  final String keyPrefix;
  const Segmented({super.key, required this.value, required this.items, required this.onChanged, this.keyPrefix = 'seg'});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Pal.panel2, border: Border.all(color: Pal.line), borderRadius: BorderRadius.circular(Ui.partRadius + 2)),
        child: Row(children: [
          for (final e in items)
            Expanded(
              child: Semantics(
                selected: e.$1 == value,
                button: true,
                child: InkWell(
                  key: ValueKey('$keyPrefix-${e.$1}'),
                  borderRadius: BorderRadius.circular(Ui.partRadius),
                  onTap: () => onChanged(e.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    constraints: const BoxConstraints(minHeight: minTap),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: e.$1 == value ? Pal.panel : null,
                      borderRadius: BorderRadius.circular(Ui.partRadius),
                      border: e.$1 == value ? Border.all(color: Pal.gold) : null,
                      boxShadow: e.$1 == value ? Ui.shadow : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tx(e.$2),
                          maxLines: 1, softWrap: false, style: ts(size: 12.5, bold: e.$1 == value, color: e.$1 == value ? Pal.goldtx : Pal.mute)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
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

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 年と月（日本語は「1980年1月」、[sp] なら「1980年 1月」。英語は「Jan 1980」）
String ym(int y, int q, {bool sp = false}) => L.en ? '${_mon[(q - 1).clamp(0, 11)]} $y' : (sp ? '$y年 $q月' : '$y年$q月');

/// 年（日本語は「1980年」、英語は「1980」）
String yearL(int y) => L.en ? '$y' : '$y年';
