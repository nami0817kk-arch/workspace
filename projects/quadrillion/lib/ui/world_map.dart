/// 世界の地図（1.1.0+41）。国を本物の形で描き、景気で塗る。
///
/// 国の形のデータ（assets/map/world.json）は Natural Earth（https://www.naturalearthdata.com/ ）の
/// 1:110m の国の境（ne_110m_admin_0_countries。パブリックドメイン＝誰でも自由に使え、表示の義務もない）を、
/// 0.35度で間引き、経緯度を0.1度の整数にして小さくしたもの（約33KB。南極と小さな島は落とした）。
/// 形式: {"c": {国のid: [[経度×10, 緯度×10, …], …]}, "o": [[…], …]}（c は24か国、o はそのほかの国）。
/// シンガポールは小さすぎて 1:110m に無いので、点で描く。
///
/// - 地図は Miller 図法（緯度の上ほど少し広げる）。経度 -168〜192、緯度 -56〜76 を描く
/// - ヨーロッパの5か国は国が小さく名前が重なるので、太平洋の南の空いた所に拡大の枠を置き、そこに名前を出す
/// - 国の名前の札は重ならない場所を探して置き、国から離れたら引き出し線でつなぐ
/// - 24か国のほかの国は薄い灰色。まだ出られない国（統計の始まる前）は少し濃い灰色
/// - ★は自社が出ている国、札の右の四角は宿敵の本拠（宿敵の色）
/// - 押すとその国を選ぶ（札・国の形・拡大の枠の中の国。小さな国は近くを押しても選べる）
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'widgets.dart';

/// 国の形（地図の単位：x は経度、y は Miller 図法の緯度を度にしたもの。上が大きい）
class WorldShapes {
  final Map<String, List<List<Offset>>> c;
  final List<List<Offset>> o;
  final Map<String, Path> cPath;
  final Path oPath;
  WorldShapes._(this.c, this.o, this.cPath, this.oPath);

  /// アプリは起動時に rootBundle から、テストはファイルから読む（無ければ、国を丸で描く）
  static WorldShapes? current;

  static WorldShapes parse(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    List<Offset> ring(List<dynamic> flat) {
      final pts = <Offset>[for (var i = 0; i + 1 < flat.length; i += 2) Offset((flat[i] as num) / 10, (flat[i + 1] as num) / 10)];
      // 経度が左の端より西に出た島（ロシアの東の端など）は、右へ回す
      final wrap = pts.every((p) => p.dx < WorldProj.lon0);
      return [for (final p in pts) Offset(wrap ? p.dx + 360 : p.dx, WorldProj.miller(p.dy))];
    }

    Path path(List<List<Offset>> rs) {
      final p = Path();
      for (final r in rs) {
        p.addPolygon(r, true);
      }
      return p;
    }

    final c = <String, List<List<Offset>>>{
      for (final e in (j['c'] as Map<String, dynamic>).entries) e.key: [for (final r in e.value as List) ring(r as List)],
    };
    final o = [for (final r in j['o'] as List) ring(r as List)];
    return WorldShapes._(c, o, {for (final e in c.entries) e.key: path(e.value)}, path(o));
  }
}

/// 地図の図法と枠
class WorldProj {
  static const lon0 = -168.0, lon1 = 192.0, latTop = 76.0, latBot = -56.0;

  /// Miller 図法の y（度）
  static double miller(double lat) {
    final r = lat * math.pi / 180;
    return 1.25 * math.log(math.tan(math.pi / 4 + .4 * r)) * 180 / math.pi;
  }

  static final yTop = miller(latTop), yBot = miller(latBot);

  /// 地図の横と縦の比
  static double get aspect => (lon1 - lon0) / (yTop - yBot);

  /// ヨーロッパの拡大の元（経度・Miller の y。この2つの Rect は y が上ほど大きい向きで、top が南の端・bottom が北の端）と、置く先（地図の単位）
  static final euSrc = Rect.fromLTRB(-11, miller(35.5), 31, miller(60.5));
  static const euScale = 1.9;
  static final euDst = Rect.fromLTWH(-166, miller(-54), euSrc.width * euScale, euSrc.height * euScale);
}

/// ヨーロッパの拡大の枠に出す国
const euInset = ['uk', 'de', 'fr', 'it', 'es'];

/// 国の名前の札を置く元の場所（経度・緯度）
const Map<String, (double, double)> labelAt = {
  'jp': (139, 37), 'cn': (104, 34), 'kr': (127.8, 36.5), 'tw': (121, 23.7), 'in': (78.5, 22), 'id': (113, -1), 'th': (101, 15.5), 'vn': (106, 15), //
  'ph': (122, 12), 'sg': (103.8, 1.3), 'us': (-99, 39), 'ca': (-105, 58), 'mx': (-102, 23), 'br': (-52, -10), 'uk': (-2, 53), 'de': (10, 51), //
  'fr': (2.5, 46.6), 'it': (12.5, 43), 'es': (-3.5, 40), 'ru': (95, 62), 'sa': (45, 24), 'ng': (8, 9.5), 'za': (24, -30), 'au': (134, -25),
};

/// 地図の色
class MapPal {
  static const sea = Color(0xFFDCEEF7);
  static const other = Color(0xFFECE9E1);
  static const closed = Color(0xFFD3D0C8);
  static const border = Color(0xFFFFFFFF);
}

/// 札1枚（国・場所・字・引き出し線の元）
class MapLabel {
  final String c;
  final Rect r;
  final Offset anchor;
  final TextPainter tp;
  final bool star;
  final List<Color> foes;
  final bool inset;
  MapLabel(this.c, this.r, this.anchor, this.tp, this.star, this.foes, this.inset);
  bool get lead => !r.inflate(2).contains(anchor);
}

/// 大きさ・選んでいる国が決まった地図の配置（描く側と押す側で同じものを使う）
class MapLayout {
  final Size size;
  final double k;
  final Rect inset, euBox;
  final List<MapLabel> labels;

  /// 拡大の枠の名前（左上）
  final TextPainter title;
  MapLayout(this.size, this.k, this.inset, this.euBox, this.labels, this.title);

  Rect get titleRect => Rect.fromLTWH(inset.left + 4, inset.top + 2, title.width, title.height);

  /// 地図の単位 → 画面の点
  static Offset px(Offset m, double k) => Offset((m.dx - WorldProj.lon0) * k, (WorldProj.yTop - m.dy) * k);

  /// 経度・緯度 → 画面の点（拡大の枠の国は、枠の中の点）
  Offset at(String c) {
    final p = labelAt[c] ?? (0.0, 0.0);
    final m = Offset(p.$1, WorldProj.miller(p.$2));
    return euInset.contains(c) ? px(euMap(m), k) : px(m, k);
  }

  /// ヨーロッパの元の点 → 拡大の枠の中の点（地図の単位）
  static Offset euMap(Offset m) {
    final s = WorldProj.euSrc, d = WorldProj.euDst;
    return Offset(d.left + (m.dx - s.left) * WorldProj.euScale, d.top + (m.dy - s.top) * WorldProj.euScale);
  }

  static Rect _pxRect(Rect m, double k) => Rect.fromPoints(px(m.topLeft, k), px(m.bottomRight, k));

  static MapLayout of(Game s, Size size, String sel) {
    final k = size.width / (WorldProj.lon1 - WorldProj.lon0);
    final inset = _pxRect(WorldProj.euDst, k), euBox = _pxRect(WorldProj.euSrc, k);
    final fs = clampD(size.width / 58, 9, 12.5);
    final foes = s.unitsOn ? s.rivalsByCountry() : const <String, List<Company>>{};
    final order = [...CTRY.map((c) => c.c)]..sort((a, b) {
        int pri(String c) => c == sel ? 0 : (c == s.home ? 1 : 2);
        final d = pri(a) - pri(b);
        return d != 0 ? d : cw(b, s.yr()).compareTo(cw(a, s.yr()));
      });
    final placed = <MapLabel>[];
    final mapRect = Offset.zero & size;
    final title = TextPainter(
        text: TextSpan(text: tr('ヨーロッパ'), style: ts(size: clampD(size.width / 70, 8, 11), color: const Color(0xFF4E5767), bold: true)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling)
      ..layout();
    final lay = MapLayout(size, k, inset, euBox, placed, title);
    for (final c in order) {
      final open = s.ctryOpen(c);
      final star = s.biz.any((b) => s.ctryOf(b).contains(c));
      final fl = [for (final x in foes[c] ?? const <Company>[]) rivalInk(x.rival!.col)].take(3).toList();
      final tp = TextPainter(
          text: TextSpan(children: [
            if (star) TextSpan(text: '★', style: ts(size: fs * .95, color: Pal.goldtx, bold: true)),
            TextSpan(text: cm[c]!.n, style: ts(size: fs, bold: c == sel || c == s.home, color: open ? Pal.ink : Pal.mute)),
          ]),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling)
        ..layout();
      final w = tp.width + 8 + fl.length * (fs * .62 + 2), h = tp.height + 3;
      final a = lay.at(c);
      final isIn = euInset.contains(c);
      final bound = isIn ? inset.deflate(2) : mapRect.deflate(1);
      Rect? best;
      // 国の上に置けないときは、まわりを近い順に探す（横は縦より広く探す）
      for (final g in _grid) {
        final d = Offset(g.dx * h, g.dy * h);
        final r = Rect.fromCenter(center: a + d, width: w, height: h);
        if (!bound.contains(r.topLeft) || !bound.contains(r.bottomRight)) continue;
        if (!isIn && (r.overlaps(inset.inflate(2)) || r.overlaps(euBox.inflate(1)))) continue;
        if (placed.any((p) => p.r.inflate(1.5).overlaps(r))) continue;
        if (isIn && r.overlaps(lay.titleRect)) continue;
        best = r;
        break;
      }
      best ??= Rect.fromCenter(center: a, width: w, height: h).shift(Offset(
          clampD(a.dx - w / 2, bound.left, bound.right - w) - (a.dx - w / 2), clampD(a.dy - h / 2, bound.top, bound.bottom - h) - (a.dy - h / 2)));
      placed.add(MapLabel(c, best, a, tp, star, fl, isIn));
    }
    return lay;
  }

  /// 札を探す場所（札の高さを1とした、ずらす量。近い順）
  static final List<Offset> _grid = () {
    final l = <Offset>[
      for (var y = -7.0; y <= 7.0; y += .5)
        for (var x = -12.0; x <= 12.0; x += .6) Offset(x, y),
    ];
    l.sort((a, b) => (a.dx * a.dx / 4 + a.dy * a.dy).compareTo(b.dx * b.dx / 4 + b.dy * b.dy));
    return l;
  }();

  /// 押した場所の国（まだ出られない国と、海は null）
  String? hit(Game s, Offset at) {
    String? ok(String? c) => c != null && s.ctryOpen(c) ? c : null;
    // 1. 名前の札（後から置いた札が上）
    for (final l in labels.reversed) {
      if (l.r.inflate(3).contains(at)) return ok(l.c);
    }
    final sh = WorldShapes.current;
    final m = Offset(at.dx / k + WorldProj.lon0, WorldProj.yTop - at.dy / k);
    // 2. 拡大の枠の中（枠の中の国だけ）
    if (inset.contains(at)) {
      final src = WorldProj.euSrc, d = WorldProj.euDst;
      final e = Offset(src.left + (m.dx - d.left) / WorldProj.euScale, src.top + (m.dy - d.top) / WorldProj.euScale);
      for (final c in euInset) {
        if (sh != null && (sh.c[c] ?? const []).any((r) => _inPoly(r, e))) return ok(c);
      }
      return _near(s, at, euInset);
    }
    // 3. 国の形
    if (sh != null) {
      for (final e in sh.c.entries) {
        if (e.value.any((r) => _inPoly(r, m))) return ok(e.key);
      }
    }
    // 4. 小さな国（シンガポール・台湾など）は近くを押しても
    return _near(s, at, [for (final c in CTRY) if (!euInset.contains(c.c)) c.c]);
  }

  String? _near(Game s, Offset at, List<String> cs) {
    String? best;
    var bd = math.max(14.0, size.width * .02);
    for (final c in cs) {
      final d = (this.at(c) - at).distance;
      if (d < bd && s.ctryOpen(c)) {
        bd = d;
        best = c;
      }
    }
    return best;
  }

  static bool _inPoly(List<Offset> r, Offset p) {
    var inside = false;
    for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
      final a = r[i], b = r[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
    }
    return inside;
  }
}

/// 世界の地図（押すとその国を選ぶ）
class WorldMap extends StatelessWidget {
  final Game s;
  final String sel;
  final void Function(String c) onPick;
  const WorldMap({super.key, required this.s, required this.sel, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final open = CTRY.where((c) => s.ctryOpen(c.c)).length;
    return AspectRatio(
      aspectRatio: WorldProj.aspect,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final lay = MapLayout.of(s, size, sel);
        return Semantics(
          label: tr('世界地図。国の色はその年の成長率。選んでいる国は{0}。押すと国を選べます（{1}か国）', [cm[sel]!.n, open]),
          image: true,
          child: GestureDetector(
            key: const ValueKey('world-map-tap'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final h = lay.hit(s, d.localPosition);
              if (h != null) onPick(h);
            },
            child: RepaintBoundary(child: CustomPaint(painter: WorldPainter(s, sel, lay), size: Size.infinite)),
          ),
        );
      }),
    );
  }
}

/// 成長率の色（不況は赤、足踏みは黄、ふつうは薄い緑、好景気は濃い緑）
Color growthColor(double g) => g < 0
    ? const Color(0xFFE57373)
    : g < 1.5
        ? const Color(0xFFF2D98A)
        : g < 4
            ? const Color(0xFFA5D6A7)
            : const Color(0xFF43A047);

class WorldPainter extends CustomPainter {
  final Game s;
  final String sel;
  final MapLayout lay;
  final int stamp;
  WorldPainter(this.s, this.sel, this.lay) : stamp = Object.hash(s.turn, sel, s.biz.length, L.lang, lay.size);

  Color _fill(String c) => s.ctryOpen(c) ? growthColor(s.growthOf(c)) : MapPal.closed;

  /// 国の形を地図の単位で描く（[toPx] で画面に移す）
  void _shapes(Canvas canvas, WorldShapes sh, double k) {
    final fill = Paint()..isAntiAlias = true;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..color = MapPal.border
      ..strokeWidth = .7 / k;
    fill.color = MapPal.other;
    canvas.drawPath(sh.oPath, fill);
    canvas.drawPath(sh.oPath, edge);
    for (final e in sh.cPath.entries) {
      fill.color = _fill(e.key);
      canvas.drawPath(e.value, fill);
      canvas.drawPath(e.value, edge);
    }
    // 自分の国と選んでいる国は縁を濃く
    for (final c in {s.home, sel}) {
      final p = sh.cPath[c];
      if (p == null) continue;
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..color = c == sel ? Pal.goldtx : Pal.ink
            ..strokeWidth = (c == sel ? 2.2 : 1.2) / k);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = lay.k;
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawRect(Offset.zero & size, Paint()..color = MapPal.sea);
    final sh = WorldShapes.current;
    // 地図の単位 → 画面（x は経度の左の端から、y は上から）
    void toPx(Canvas c, double kk) {
      c.scale(kk, -kk);
      c.translate(-WorldProj.lon0, -WorldProj.yTop);
    }

    if (sh != null) {
      canvas.save();
      toPx(canvas, k);
      _shapes(canvas, sh, k);
      canvas.restore();
    }
    // シンガポール（形が無いので点）と、形の無いときの国の点
    for (final c in CTRY) {
      if (sh != null && sh.c.containsKey(c.c)) continue;
      final o = lay.at(c.c);
      if (euInset.contains(c.c) && sh != null) continue;
      final r = math.max(3.5, k * 2.2);
      canvas.drawCircle(o, r, Paint()..color = _fill(c.c));
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = c.c == sel ? 2 : 1
            ..color = c.c == sel ? Pal.goldtx : Pal.ink.withValues(alpha: .6));
    }
    // ヨーロッパの元の枠（点線）と、拡大の枠
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF7A8496);
    _dashRect(canvas, lay.euBox, dash);
    final ins = RRect.fromRectAndRadius(lay.inset, const Radius.circular(6));
    canvas.drawRRect(ins.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x221F2433));
    canvas.drawRRect(ins, Paint()..color = MapPal.sea);
    if (sh != null) {
      final s0 = WorldProj.euSrc;
      final kk = k * WorldProj.euScale;
      canvas.save();
      canvas.clipRRect(ins);
      // 拡大の枠の中：画面の点 = 枠の左上 + ((m.x − 元の左) × kk, (元の上の端 − m.y) × kk)
      canvas.translate(lay.inset.left, lay.inset.top);
      canvas.scale(kk, -kk);
      canvas.translate(-s0.left, -s0.bottom);
      _shapes(canvas, sh, kk);
      canvas.restore();
    }
    canvas.drawRRect(
        ins,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF7A8496));
    // 枠の名前（左上）
    lay.title.paint(canvas, lay.titleRect.topLeft);
    // 札（引き出し線 → 札の面 → 字 → 宿敵の印）
    for (final l in lay.labels) {
      if (!l.lead) continue;
      final to = Offset(clampD(l.anchor.dx, l.r.left, l.r.right), clampD(l.anchor.dy, l.r.top, l.r.bottom));
      canvas.drawLine(l.anchor, to, Paint()
        ..color = const Color(0xCC4E5767)
        ..strokeWidth = 1);
      canvas.drawCircle(l.anchor, 2, Paint()..color = const Color(0xFF4E5767));
    }
    for (final l in lay.labels) {
      final rr = RRect.fromRectAndRadius(l.r, Radius.circular(l.r.height / 2));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: .9));
      final on = l.c == sel, home = l.c == s.home;
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 2 : (home ? 1.2 : .8)
            ..color = on ? Pal.goldtx : (home ? Pal.ink : const Color(0xFFB9B2A2)));
      l.tp.paint(canvas, Offset(l.r.left + 4, l.r.center.dy - l.tp.height / 2));
      final ds = l.tp.height * .55;
      for (var i = 0; i < l.foes.length; i++) {
        final x = l.r.left + 4 + l.tp.width + 2 + i * (ds + 2);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, l.r.center.dy - ds / 2, ds, ds), Radius.circular(ds * .28)), Paint()..color = l.foes[i]);
      }
    }
    canvas.restore();
  }

  void _dashRect(Canvas canvas, Rect r, Paint p) {
    final pts = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft, r.topLeft];
    for (var i = 0; i < 4; i++) {
      final a = pts[i], b = pts[i + 1];
      final len = (b - a).distance;
      for (var t = 0.0; t < len; t += 6) {
        canvas.drawLine(a + (b - a) * (t / len), a + (b - a) * (math.min(len, t + 3) / len), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter o) => o.s != s || o.stamp != stamp;
}
