/// 画面の見た目の共通の部品（1.1.0+40。まず「事業」の画面で見本として使う。ほかの画面にもそのまま使える形にしてある）
///
/// - [ScreenTone] 画面ごとの色（見出しの帯・要点のカードの印の色）
/// - [ScreenBand] 画面の見出しの帯（色の面に印・名前・要約の数字・右にボタン）
/// - [KpiCard]・[KpiRow] 要点のカード（大きな数字・前の月からの増減の札。月を進めると数字が前の値から動いて変わり、札が少し光る）
/// - [DeltaChip] 増減の札（矢印と色）
/// - [SectionHead] カードの中の見出し（印・名前・右に飾り）
/// - [IndIcon] 業種の絵（分類の色の角丸の面に、業種の印）
/// - [TrendChart] 推移のグラフ（目盛り・日付つき。押すと、その月の値が出る）
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'widgets.dart';

// ===== 画面の色 =====
/// 画面ごとの色。[c] は帯の面・印の色（白い字が 4.5:1 以上で読める濃さ）、[soft] はカードの印の下地、[ink] は白地の上の字
class ScreenTone {
  final Color c, soft, ink;
  const ScreenTone(this.c, this.soft, this.ink);

  static const town = ScreenTone(Color(0xFF9A6500), Color(0xFFFFF1CC), Color(0xFF8A5A00));
  static const biz = ScreenTone(Color(0xFF1F5FA8), Color(0xFFE3EEFB), Color(0xFF1B5596));
  static const people = ScreenTone(Color(0xFF1D7A55), Color(0xFFDDF3E8), Color(0xFF176B4A));
  static const stock = ScreenTone(Color(0xFF6B4BB0), Color(0xFFEDE6FA), Color(0xFF5E40A0));
  static const money = ScreenTone(Color(0xFF0F7D78), Color(0xFFDCF2F0), Color(0xFF0C6C68));
  static const world = ScreenTone(Color(0xFF2B6C8F), Color(0xFFE0EEF5), Color(0xFF235C7B));
  static const zukan = ScreenTone(Color(0xFF8A4F2A), Color(0xFFF6E8DE), Color(0xFF7A4423));
}

/// 動きの時間（月を進めたときの数字の動き）。テストでは0に差し替えている
class Motion {
  static const numDefault = Duration(milliseconds: 700);
  static Duration num = numDefault;

  /// 端末で「動きを減らす」にしていれば動かさない
  static Duration of(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : num;
}

// ===== 見出しの帯 =====
/// 画面の見出しの帯。左に印と名前、続けて要約の数字（[facts]）、右にボタン（[trailing]）。幅が足りなければ要約は字を縮める
class ScreenBand extends StatelessWidget {
  final ScreenTone tone;
  final IconData icon;
  final String title;
  final List<(String, String)> facts;
  final Widget? trailing;
  const ScreenBand({super.key, required this.tone, required this.icon, required this.title, this.facts = const [], this.trailing});

  @override
  Widget build(BuildContext context) {
    final hi = Color.lerp(tone.c, Colors.white, .18)!;
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tone.c, hi], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(Ui.rCard),
        boxShadow: [BoxShadow(color: tone.c.withValues(alpha: .28), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Semantics(header: true, child: Text(tx(title), style: ts(size: 16, bold: true, color: Colors.white))),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final f in facts)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${f.$1} ', style: ts(size: 11.5, color: Colors.white.withValues(alpha: .85))),
                    TextSpan(text: f.$2, style: ts(size: 13.5, bold: true, color: Colors.white)),
                  ])),
                ),
            ]),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

// ===== 増減の札 =====
/// 増減（[v] の向きで矢印、[good] で色。[text] は「+3.2%」などの書いた値、[label] は「前月」などの比べる先）
class Delta {
  final double v;
  final String text, label;
  final bool good;
  const Delta(this.v, this.text, {required this.label, bool? good}) : good = good ?? v >= 0;

  /// 前の値 [prev] からの割合（前の値が0以下なら null）
  static Delta? pct(double now, double? prev, {required String label, bool higherIsBetter = true}) {
    if (prev == null || prev <= 0 || !now.isFinite) return null;
    final r = now / prev - 1;
    if ((r * 100).abs() < .05) return Delta(0, '±0%', label: label);
    return Delta(r, '${r >= 0 ? '+' : ''}${(r * 100).abs() >= 100 ? (r * 100).round() : (r * 100).toStringAsFixed(1)}%',
        label: label, good: (r >= 0) == higherIsBetter);
  }

  /// 前の値からの差（[fmt] で書く）。書いた値が0になる小さな差は、横ばい（±0）として出す
  static Delta? diff(double now, double? prev, String Function(double) fmt, {required String label}) {
    if (prev == null || !now.isFinite || !prev.isFinite) return null;
    final d = now - prev;
    final t = fmt(d.abs());
    if (d.abs() < 1e-12 || !RegExp(r'[1-9]').hasMatch(t)) return Delta(0, '±${fmt(0)}', label: label);
    return Delta(d, '${d >= 0 ? '+' : '-'}$t', label: label);
  }
}

/// 増減の札（▲ 緑・▼ 赤・横ばいは灰）。[glow]（0〜1）で少し光る
class DeltaChip extends StatelessWidget {
  final Delta d;
  final double glow;
  const DeltaChip(this.d, {super.key, this.glow = 0});

  @override
  Widget build(BuildContext context) {
    final flat = d.v.abs() < 1e-9;
    final c = flat ? Pal.mute : (d.good ? Pal.up : Pal.down);
    final icon = flat ? Icons.trending_flat : (d.v > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down);
    return Container(
      padding: const EdgeInsets.fromLTRB(1, 0, 5, 0),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1 + .22 * glow),
        borderRadius: BorderRadius.circular(99),
        boxShadow: glow > 0 ? [BoxShadow(color: c.withValues(alpha: .35 * glow), blurRadius: 8 * glow)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: c),
        Text(d.text, maxLines: 1, softWrap: false, style: ts(size: 11, bold: true, color: c, height: 1.3)),
        if (d.label.isNotEmpty) Text(' ${tx(d.label)}', maxLines: 1, softWrap: false, style: ts(size: 9.5, color: Pal.mute, height: 1.3)),
      ]),
    );
  }
}

// ===== 要点のカード =====
/// 要点のカード：小さな印と名前、大きな数字、増減の札（と、その下の小さな説明 [sub]）。
/// [turn] が変わった（月を進めた）ときだけ、数字が前の値から今の値へ動き、札が少し光る。
/// ほかの理由で値が替わったとき（別の事業を選んだなど）は、そのまま替える
class KpiCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final double value;
  final String Function(double) fmt;
  final int turn;
  final ScreenTone tone;
  final Color color;
  /// 前の月との増減・前の年との増減（無ければ出さない）
  final Delta? delta, delta2;
  final String? sub;
  final Color? subColor;
  const KpiCard(
      {super.key,
      required this.label,
      required this.icon,
      required this.value,
      required this.fmt,
      required this.turn,
      this.tone = ScreenTone.biz,
      this.color = Pal.ink,
      this.delta,
      this.delta2,
      this.sub,
      this.subColor});

  @override
  State<KpiCard> createState() => KpiCardState();
}

class KpiCardState extends State<KpiCard> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, value: 1);
  double _from = 0;

  /// 動いている途中か（テストから見る）
  bool get moving => _a.isAnimating;

  @override
  void didUpdateWidget(KpiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.turn != widget.turn && old.value != widget.value && old.value.isFinite) {
      final d = Motion.of(context);
      if (d == Duration.zero) return;
      _from = old.value;
      _a.duration = d;
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
    final w = widget;
    final ds = [?w.delta, ?w.delta2];
    final label = '${tx(w.label)} ${w.fmt(w.value)}${ds.map((d) => '${tr('・')}${tx(d.label)} ${d.text}').join()}${w.sub != null ? '${tr('・')}${tx(w.sub)}' : ''}';
    Widget line(Widget c) => SizedBox(height: 16, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: c));
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          color: Pal.panel,
          borderRadius: BorderRadius.circular(Ui.rCard),
          border: Border.all(color: Pal.line),
          boxShadow: const [BoxShadow(color: Color(0x141F2433), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_a.value);
            final v = _a.isAnimating ? _from + (w.value - _from) * t : w.value;
            final glow = _a.isAnimating ? math.sin(math.pi * _a.value) : 0.0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: w.tone.soft, borderRadius: BorderRadius.circular(5)),
                  child: Icon(w.icon, size: 12, color: w.tone.ink),
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(tx(w.label), maxLines: 1, softWrap: false, style: ts(size: 11, color: Pal.mute)))),
              ]),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(w.fmt(v), maxLines: 1, softWrap: false, style: ts(size: 19, bold: true, color: w.color, height: 1.2)),
              ),
              for (final d in ds) line(DeltaChip(d, glow: glow)),
              if (w.sub != null) line(Text(tx(w.sub), maxLines: 1, softWrap: false, style: ts(size: 10.5, color: w.subColor ?? Pal.mute, height: 1.3))),
            ]);
          },
        ),
      ),
    );
  }
}

/// 要点のカードを横に並べる。1枚が [minW] より狭くなるときは、2段に分ける
class KpiRow extends StatelessWidget {
  final List<Widget> cards;
  final double minW;

  /// 1段に並べる最大の数（null なら全部）
  final int? maxPer;
  const KpiRow(this.cards, {super.key, this.minW = 96, this.maxPer});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 6.0;
        final n = cards.length;
        var per = math.min(n, maxPer ?? n);
        while (per > 1 && (c.maxWidth - gap * (per - 1)) / per < minW * Ui.textScale) {
          per--;
        }
        final rows = <List<Widget>>[];
        for (var i = 0; i < n; i += per) {
          rows.add(cards.sublist(i, math.min(n, i + per)));
        }
        return Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < per; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: i < r.length ? r[i] : const SizedBox.shrink()),
                  ],
                ]),
              ),
            ),
        ]);
      });
}

// ===== セクションの見出し =====
/// カードの見出し（色の印・名前・右に飾り）。[CardTitle] の代わりに、印で何の欄かを見せる
class SectionHead extends StatelessWidget {
  final String title;
  final IconData icon;
  final ScreenTone tone;
  final Widget? trailing;
  const SectionHead(this.title, this.icon, {super.key, this.tone = ScreenTone.biz, this.trailing});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        // 右の飾り（「立地ごとの表」などのボタン）は要るだけの幅（最大で6割）を先に取り、名前は残りに収める
        child: LayoutBuilder(
          builder: (context, c) => Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: tone.soft, borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 14, color: tone.ink),
            ),
            const SizedBox(width: 6),
            Expanded(child: Semantics(header: true, child: Text(tx(title), style: Ui.cardTitle()))),
            if (trailing != null) ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth * .6), child: trailing),
          ]),
        ),
      );
}

// ===== 業種の絵 =====
/// 分類の色（白い印が 3:1 以上で見える濃さ）
Color catColor(String cat) => switch (cat) {
      'food' => const Color(0xFFD9622B),
      'live' => const Color(0xFFB8497A),
      'make' => const Color(0xFF5B6B7F),
      'ene' => const Color(0xFFC98A00),
      'link' => const Color(0xFF2C7FB8),
      'money' => const Color(0xFF2E8B57),
      'net' => const Color(0xFF3F5BD6),
      'fun' => const Color(0xFF9B4DCA),
      'med' => const Color(0xFFD64545),
      _ => const Color(0xFF14918A),
    };

/// 業種ごとの印（目立つ業種だけ。ほかは分類と稼ぎの型の組で決める [_catKindIcon]）
const Map<String, IconData> _indIcons = {
  'yatai': Icons.storefront, 'teishoku': Icons.rice_bowl, 'ff': Icons.lunch_dining, 'konbini': Icons.local_convenience_store,
  'frozen': Icons.ac_unit, 'bento': Icons.delivery_dining, 'dining': Icons.restaurant, 'estate': Icons.apartment, 'hotel': Icons.hotel,
  'depart': Icons.local_mall, 'apparel': Icons.checkroom, 'furniture': Icons.chair, 'kaden': Icons.kitchen, 'auto': Icons.directions_car,
  'semi': Icons.memory, 'steel': Icons.hardware, 'oil': Icons.oil_barrel, 'power': Icons.bolt, 'solar': Icons.solar_power,
  'logi': Icons.local_shipping, 'telecom': Icons.cell_tower, 'ship': Icons.directions_boat, 'shosha': Icons.handshake,
  'adagency': Icons.campaign, 'bank': Icons.account_balance, 'secur': Icons.candlestick_chart, 'insur': Icons.health_and_safety,
  'pay': Icons.contactless, 'portal': Icons.travel_explore, 'ec': Icons.shopping_cart, 'sns': Icons.forum, 'app': Icons.smartphone,
  'video': Icons.smart_display, 'cloud': Icons.cloud, 'tv': Icons.tv, 'movie': Icons.movie, 'game': Icons.sports_esports,
  'music': Icons.music_note, 'pharma': Icons.medication, 'hospital': Icons.local_hospital, 'care': Icons.elderly, 'ai': Icons.psychology,
  'space': Icons.rocket_launch, 'ev': Icons.electric_car, 'quantum': Icons.blur_on, 'fusion': Icons.flare, 'rentalvideo': Icons.video_library,
  'pager': Icons.textsms, 'keitaishop': Icons.phone_iphone, 'pc': Icons.computer, 'cdshop': Icons.album, 'karaoke': Icons.mic,
  'arcade': Icons.videogame_asset, 'gyudon': Icons.ramen_dining, 'sushi': Icons.set_meal, 'cafe': Icons.local_cafe,
  'drug': Icons.local_pharmacy, 'yen100': Icons.sell, 'homecenter': Icons.handyman, 'kadenstore': Icons.tv, 'juku': Icons.school,
  'eikaiwa': Icons.translate, 'haken': Icons.badge, 'keibi': Icons.security, 'hikkoshi': Icons.moving, 'travel': Icons.luggage,
  'airline': Icons.flight, 'rail': Icons.train, 'taxi': Icons.local_taxi, 'rideshare': Icons.hail, 'delivery': Icons.delivery_dining,
  'minpaku': Icons.cottage, 'matching': Icons.favorite, 'wedding': Icons.celebration, 'ebook': Icons.menu_book, 'publish': Icons.auto_stories,
  'newspaper': Icons.newspaper, 'anime': Icons.animation, 'cosme': Icons.face_retouching_natural, 'chem': Icons.science,
  'shipbuild': Icons.sailing, 'construct': Icons.construction, 'gym': Icons.fitness_center, 'pet': Icons.pets, 'funeral': Icons.local_florist,
  'hoiku': Icons.child_care, 'sake': Icons.liquor, 'drink': Icons.local_drink, 'farm': Icons.agriculture, 'card': Icons.credit_card,
  'consumer': Icons.payments, 'crypto': Icons.currency_bitcoin, 'consult': Icons.insights, 'sier': Icons.integration_instructions,
  'security': Icons.shield, 'robot': Icons.precision_manufacturing, 'autodrive': Icons.directions_car_filled, 'drone': Icons.flight_takeoff,
  'gene': Icons.biotech, 'regen': Icons.healing, 'hydrogen': Icons.water_drop, 'smr': Icons.energy_savings_leaf, 'metaverse': Icons.view_in_ar,
  'flyingcar': Icons.airplanemode_active, 'culturedmeat': Icons.egg_alt, 'seabed': Icons.water, 'dagashi': Icons.cookie,
  'ramen': Icons.ramen_dining, 'izakaya': Icons.sports_bar, 'famires': Icons.restaurant_menu, 'confect': Icons.cake, 'fishery': Icons.phishing,
  'mealkit': Icons.takeout_dining, 'plantmeat': Icons.eco, 'boba': Icons.emoji_food_beverage, 'sento': Icons.hot_tub,
  'laundry': Icons.local_laundry_service, 'photolab': Icons.photo_camera_back, 'salon': Icons.content_cut, 'reform': Icons.format_paint,
  'storage': Icons.inventory_2, 'smarthome': Icons.home_max, 'kimono': Icons.dry_cleaning, 'waste': Icons.recycling, 'textile': Icons.texture,
  'camera': Icons.photo_camera, 'watch': Icons.watch, 'mdplayer': Icons.headphones, 'handset': Icons.phone_android,
  'machine': Icons.settings, 'paper': Icons.description, 'battery': Icons.battery_charging_full, 'printer3d': Icons.view_in_ar,
  'coal': Icons.landscape, 'citygas': Icons.local_fire_department, 'lpg': Icons.propane_tank, 'nuclear': Icons.electric_bolt,
  'wind': Icons.wind_power, 'gasstation': Icons.local_gas_station, 'gridbatt': Icons.battery_full, 'geothermal': Icons.volcano,
  'wholesale': Icons.inventory, 'callcenter': Icons.headset_mic, 'bus': Icons.directions_bus, 'printing': Icons.print,
  'warehouse': Icons.warehouse, 'translation': Icons.g_translate, 'courier': Icons.local_post_office, 'datacenter': Icons.dns,
  'pawn': Icons.diamond, 'lease': Icons.key, 'fx': Icons.currency_exchange, 'crowdfund': Icons.volunteer_activism,
  'reit': Icons.location_city, 'asset': Icons.savings, 'robo': Icons.smart_toy, 'bnpl': Icons.receipt_long,
  'exchange': Icons.currency_yen, 'mobilesite': Icons.phonelink, 'blog': Icons.edit_note, 'jobboard': Icons.work_outline,
  'flea': Icons.storefront, 'review': Icons.reviews, 'saas': Icons.dashboard, 'livestream': Icons.live_tv, 'webdesign': Icons.web,
  'dialup': Icons.router, 'radio': Icons.radio, 'pachinko': Icons.casino, 'bowling': Icons.sports_baseball, 'themepark': Icons.attractions,
  'esports': Icons.emoji_events, 'vtuber': Icons.face, 'talent': Icons.star, 'proteam': Icons.sports_baseball, 'golf': Icons.golf_course,
  'clinic': Icons.medical_services, 'dental': Icons.medical_information, 'generic': Icons.vaccines, 'medequip': Icons.monitor_heart,
  'seitai': Icons.self_improvement, 'telemed': Icons.video_call, 'pharmacy': Icons.local_pharmacy, 'rojin': Icons.elderly_woman,
  'cro': Icons.fact_check, 'bci': Icons.cable, 'android': Icons.smart_toy, 'spaceelev': Icons.elevator, 'moon': Icons.nightlight,
  'longevity': Icons.hourglass_bottom, 'weather': Icons.thunderstorm, 'vertfarm': Icons.grass, 'ccs': Icons.co2,
  'spacetravel': Icons.public, 'foodmaker': Icons.food_bank,
};

/// 分類と稼ぎの型の組の印（[_indIcons] に無い業種）
IconData _catKindIcon(String cat, String kind) => switch (kind) {
      'factory' => Icons.factory,
      'net' => Icons.language,
      'people' => Icons.groups,
      'license' => Icons.verified,
      'hit' => Icons.auto_awesome,
      'infra' => Icons.domain,
      _ => switch (cat) {
          'food' => Icons.restaurant,
          'med' => Icons.local_hospital,
          'fun' => Icons.celebration,
          _ => Icons.storefront,
        },
    };

/// 業種の印
IconData indIconOf(Industry i) => _indIcons[i.id] ?? _catKindIcon(i.cat, kindOf(i));

/// 業種の絵（分類の色の角丸の面に、白い業種の印）。名前は隣に書くので、読み上げからは外す
class IndIcon extends StatelessWidget {
  final Industry ind;
  final double size;
  const IndIcon(this.ind, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final c = catColor(ind.cat);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, .15)!, c], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * .28),
          boxShadow: size >= 32 ? [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(indIconOf(ind), size: size * .6, color: Colors.white),
      ),
    );
  }
}

// ===== 推移のグラフ =====
/// グラフの1本の線（名前・色・値。値は古い順で、無い月は null）
class TrendSeries {
  final String name;
  final Color color;
  final List<double?> values;
  const TrendSeries(this.name, this.color, this.values);
}

/// 推移のグラフ：左に目盛り（きりのよい間隔）、下に日付（はじめ・まん中・終わり）、0の線。
/// 押す・なぞると、その月の縦の線と値の札が出る（もう一度同じ所を押すと消える）
class TrendChart extends StatefulWidget {
  final List<TrendSeries> series;

  /// 各点の日付の札（古い順。series の値と同じ数）
  final List<String> labels;
  final String Function(double) fmt;
  final double height;

  /// 読み上げで伝える要約
  final String summary;
  const TrendChart({super.key, required this.series, required this.labels, required this.fmt, required this.summary, this.height = 120});

  @override
  State<TrendChart> createState() => TrendChartState();
}

class TrendChartState extends State<TrendChart> {
  /// 押して選んでいる点（null なら札を出さない）。テストから見る
  int? sel;

  _Geo _geo(Size size) => _Geo.of(widget, size);

  void _pick(Offset p, Size size, {bool toggle = false}) {
    final g = _geo(size);
    if (g.n < 1) return;
    final i = g.indexAt(p.dx);
    setState(() => sel = toggle && sel == i ? null : i);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.summary,
        image: true,
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, c) {
            final size = Size(c.maxWidth, widget.height);
            final g = _geo(size);
            final s = sel != null && sel! < g.n ? sel : null;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition, size, toggle: true),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition, size),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: CustomPaint(painter: _TrendPainter(widget, g, s))),
                if (s != null) _tip(g, s, size),
              ]),
            );
          }),
        ),
      );

  Widget _tip(_Geo g, int i, Size size) {
    const w = 132.0;
    final x = g.xOf(i);
    final left = (x + 8 + w > size.width ? x - 8 - w : x + 8).clamp(0.0, math.max(0.0, size.width - w)).toDouble();
    return Positioned(
      left: left,
      top: 0,
      width: w,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('trend-tip'),
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
          decoration: BoxDecoration(
            color: Pal.ink.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x331F2433), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.labels[i], style: ts(size: 11, bold: true, color: Colors.white)),
            for (final s in widget.series)
              if (i < s.values.length && s.values[i] != null)
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${tx(s.name)} ${widget.fmt(s.values[i]!)}', maxLines: 1, softWrap: false, style: ts(size: 11, color: Colors.white)),
                    ),
                  ),
                ]),
          ]),
        ),
      ),
    );
  }
}

/// グラフの形（目盛り・点の位置）。描く側と札を置く側で同じものを使う
class _Geo {
  final int n;
  final double left, right, top, bottom, lo, hi, step;
  final Size size;
  final List<String> ticks;
  _Geo(this.n, this.left, this.right, this.top, this.bottom, this.lo, this.hi, this.step, this.size, this.ticks);

  static _Geo of(TrendChart w, Size size) {
    final n = w.labels.length;
    var hi = 0.0, lo = 0.0;
    for (final s in w.series) {
      for (final v in s.values) {
        if (v == null || !v.isFinite) continue;
        hi = math.max(hi, v);
        lo = math.min(lo, v);
      }
    }
    if (hi <= lo) hi = lo + 1;
    // きりのよい目盛りの幅（1・2・5 × 10の累乗）。3〜4本
    final raw = (hi - lo) / 3;
    final p10 = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1.0, 2.0, 5.0, 10.0].map((k) => k * p10).firstWhere((v) => v >= raw);
    lo = (lo / step).floorToDouble() * step;
    hi = (hi / step).ceilToDouble() * step;
    final ticks = <String>[for (var v = lo; v <= hi + step / 2; v += step) v.abs() < step / 2 ? '0' : w.fmt(v)];
    var lw = 0.0;
    for (final t in ticks) {
      final tp = TextPainter(text: TextSpan(text: t, style: ts(size: 9.5)), textDirection: TextDirection.ltr, textScaler: TextScaler.noScaling)..layout();
      lw = math.max(lw, tp.width);
    }
    return _Geo(n, lw + 6, 8, 6, 16, lo, hi, step, size, ticks);
  }

  double get plotW => math.max(1, size.width - left - right);
  double get plotH => math.max(1, size.height - top - bottom);
  double xOf(int i) => n <= 1 ? left + plotW / 2 : left + i / (n - 1) * plotW;
  double yOf(double v) => top + (hi - v) / (hi - lo) * plotH;
  int indexAt(double x) => n <= 1 ? 0 : ((x - left) / plotW * (n - 1)).round().clamp(0, n - 1);
}

class _TrendPainter extends CustomPainter {
  final TrendChart w;
  final _Geo g;
  final int? sel;
  _TrendPainter(this.w, this.g, this.sel);

  void _text(Canvas c, String t, Offset at, {Color color = Pal.mute, double size = 9.5, Alignment align = Alignment.centerLeft}) {
    final tp = TextPainter(text: TextSpan(text: t, style: ts(size: size, color: color)), textDirection: TextDirection.ltr, textScaler: TextScaler.noScaling)
      ..layout();
    final dx = switch (align) { Alignment.centerRight => at.dx - tp.width, Alignment.center => at.dx - tp.width / 2, _ => at.dx };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE6E0D2)
      ..strokeWidth = 1;
    var i = 0;
    for (var v = g.lo; v <= g.hi + g.step / 2; v += g.step, i++) {
      final y = g.yOf(v);
      final zero = v.abs() < g.step / 2;
      canvas.drawLine(
          Offset(g.left, y),
          Offset(size.width - g.right, y),
          zero
              ? (Paint()
                ..color = const Color(0xFF9A927F)
                ..strokeWidth = 1.2)
              : grid);
      if (i < g.ticks.length) _text(canvas, g.ticks[i], Offset(g.left - 4, y), align: Alignment.centerRight);
    }
    if (g.n == 0) return;
    // 日付（はじめ・まん中・終わり）
    final idx = <int>{0, if (g.n >= 5) (g.n - 1) ~/ 2, g.n - 1};
    for (final k in idx) {
      final a = k == 0 ? Alignment.centerLeft : (k == g.n - 1 ? Alignment.centerRight : Alignment.center);
      _text(canvas, w.labels[k], Offset(g.xOf(k), size.height - 6), align: g.n == 1 ? Alignment.center : a);
    }
    // 線の下を薄く塗り、線を引き、終わりの点を打つ
    for (final s in w.series) {
      final pts = <Offset>[];
      for (var k = 0; k < s.values.length && k < g.n; k++) {
        final v = s.values[k];
        if (v != null && v.isFinite) pts.add(Offset(g.xOf(k), g.yOf(v)));
      }
      if (pts.isEmpty) continue;
      if (pts.length >= 2) {
        final zy = g.yOf(math.max(g.lo, math.min(0, g.hi)));
        final fill = Path()..moveTo(pts.first.dx, zy);
        for (final p in pts) {
          fill.lineTo(p.dx, p.dy);
        }
        fill
          ..lineTo(pts.last.dx, zy)
          ..close();
        canvas.drawPath(fill, Paint()..color = s.color.withValues(alpha: .1));
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
            path,
            Paint()
              ..color = s.color
              ..strokeWidth = 2.2
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round);
      }
      canvas.drawCircle(pts.last, 3.2, Paint()..color = s.color);
      canvas.drawCircle(pts.last, 1.6, Paint()..color = Colors.white);
    }
    final si = sel;
    if (si != null) {
      final x = g.xOf(si);
      canvas.drawLine(
          Offset(x, g.top),
          Offset(x, size.height - g.bottom),
          Paint()
            ..color = Pal.ink.withValues(alpha: .45)
            ..strokeWidth = 1);
      for (final s in w.series) {
        if (si < s.values.length && s.values[si] != null) {
          final o = Offset(x, g.yOf(s.values[si]!));
          canvas.drawCircle(o, 4.5, Paint()..color = Colors.white);
          canvas.drawCircle(o, 3.2, Paint()..color = s.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

/// 月の短い日付（日本語「97年3月」・英語「Mar 97」）
String ymShort(int y, int q) {
  const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final yy = (y % 100).toString().padLeft(2, '0');
  return L.en ? '${mon[(q - 1).clamp(0, 11)]} $yy' : '$yy年$q月';
}

/// 今の月（[y] 年 [q] 月）から [back] か月前の短い日付
String ymBack(int y, int q, int back) {
  final t = y * 12 + (q - 1) - back;
  return ymShort(t ~/ 12, t % 12 + 1);
}
