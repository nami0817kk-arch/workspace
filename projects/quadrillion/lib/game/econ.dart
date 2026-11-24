/// 本物の経済（1.1.0+25 から）。24か国×1980〜2025年の統計（assets/econ/econ.json）を読み、
/// 国と年月ごとの数字（人口・成長率・名目GDP・物価・金利・為替・賃金・最低賃金・法人税・失業率）を返す。
/// Flutter に依存しない（読み込んだ文字を [EconData.parse] に渡す。アプリは rootBundle、テストはファイルから）。
///
/// 決まり:
/// - 値が null の年は、前後の年から線で補う（片側しか無ければ近い年の値）。国ごとに丸ごと無い項目は既定の値
/// - データに無い国は、[EconData.synth] が日本の数字と国の大きさの曲線から作る（仮。本物が来たら使われなくなる）
/// - データの最後の年より先は、直近の傾向からぶれのある予測（[forecast]）。ぶれは国と年で決まる種から作るので、
///   同じ遊び（同じ [EconData.fcSeed]）なら何度読んでも同じ数字になる
///
/// 単位（assets/econ/econ.json の meta.fields が正）:
/// pop 人 / gdp_growth 実質の成長率% / gdp_usd 名目GDPのドル / cpi 物価の上昇率%（読み込むときに指数へ積み上げる。
/// meta.fields.cpi に「上昇率」が無ければ、はじめから指数として読む） / rate 金利%（年平均） / fx_usd 1ドルが自国の通貨でいくら /
/// wage_usd 年の平均賃金のドル / min_wage 最低賃金（自国の通貨・月額。制度の無い年は、平均賃金との比を近い年から補う） /
/// corp_tax 国と地方を合わせた法人税率% / unemp 失業率%
///
/// 極端な値（ブラジルのハイパーインフレ期の金利38,198%・為替2.68e-09 など）は実際の値のまま持ち、使う側（game_real.dart）で上限を付ける
library;

import 'dart:convert';
import 'dart:math' as math;

/// 1か国・1年の数字（null は「まだ無い」。読み込んだあとは補って埋める）
class EconYear {
  double? pop, gdpGrowth, gdpUsd, cpi, rate, fxUsd, wageUsd, minWage, corpTax, unemp;
  EconYear({this.pop, this.gdpGrowth, this.gdpUsd, this.cpi, this.rate, this.fxUsd, this.wageUsd, this.minWage, this.corpTax, this.unemp});

  static const keys = ['pop', 'gdp_growth', 'gdp_usd', 'cpi', 'rate', 'fx_usd', 'wage_usd', 'min_wage', 'corp_tax', 'unemp'];

  double? get(String k) => switch (k) {
        'pop' => pop,
        'gdp_growth' => gdpGrowth,
        'gdp_usd' => gdpUsd,
        'cpi' => cpi,
        'rate' => rate,
        'fx_usd' => fxUsd,
        'wage_usd' => wageUsd,
        'min_wage' => minWage,
        'corp_tax' => corpTax,
        'unemp' => unemp,
        _ => null,
      };

  void set(String k, double? v) {
    switch (k) {
      case 'pop':
        pop = v;
      case 'gdp_growth':
        gdpGrowth = v;
      case 'gdp_usd':
        gdpUsd = v;
      case 'cpi':
        cpi = v;
      case 'rate':
        rate = v;
      case 'fx_usd':
        fxUsd = v;
      case 'wage_usd':
        wageUsd = v;
      case 'min_wage':
        minWage = v;
      case 'corp_tax':
        corpTax = v;
      case 'unemp':
        unemp = v;
    }
  }

  factory EconYear.fromJson(Map<String, dynamic> j) {
    final y = EconYear();
    for (final k in keys) {
      final v = j[k];
      y.set(k, v is num ? v.toDouble() : null);
    }
    return y;
  }

  EconYear copy() {
    final y = EconYear();
    for (final k in keys) {
      y.set(k, get(k));
    }
    return y;
  }
}

/// 国の中の都市（街の画面と、のちの段の立地に使う）
class EconCity {
  final String ja, en;
  final double pop;
  const EconCity(this.ja, this.en, this.pop);
}

class EconCountry {
  final String code, currency;
  final List<EconCity> cities;

  /// 年 → 数字（読み込んだあとは、最初の年から最後の年まで全部の年がそろい、null は無い）
  final Map<int, EconYear> years;

  /// データに無く、作った国か
  final bool synthetic;
  EconCountry(this.code, this.currency, this.cities, this.years, {this.synthetic = false});
}

/// 大きな出来事（バブル崩壊・通貨危機・金融危機・感染症など）
class EconEvent {
  final int year;
  final int? month;
  final List<String> countries;
  final String kind, ja, en, noteJa, noteEn;

  /// その年の成長率への響き（ポイント。マイナスは落ち込み）
  final double gdpHit;
  const EconEvent(
      {required this.year,
      this.month,
      required this.countries,
      required this.kind,
      required this.ja,
      required this.en,
      required this.gdpHit,
      this.noteJa = '',
      this.noteEn = ''});

  /// 世界中に響く出来事か（国の指定が無い・"ALL" がある・6か国以上）
  bool get global => countries.isEmpty || countries.contains('ALL') || countries.length >= 6;
}

/// 統計の全部
class EconData {
  final Map<String, dynamic> meta;
  final Map<String, EconCountry> countries;
  final List<EconEvent> events;

  /// 仮のデータか（meta.provisional が true・meta.note に「仮」）
  final bool provisional;

  /// データの最初と最後の年（日本の数字で決める）
  final int firstYear, lastYear;

  EconData._(this.meta, this.countries, this.events, this.provisional, this.firstYear, this.lastYear);

  /// 今使っている統計（アプリは起動時、テストは test/flutter_test_config.dart で読む）。無ければ仕組みは昔の式で動く
  static EconData? current;

  /// データの文字を読む。[codes] はゲームで使う国（データに無い国は作る）。[shape] は国の大きさの曲線（日本を1とする）
  static EconData parse(String text, {List<String> codes = const [], double Function(String c, double y)? shape}) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final meta = (j['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final fields = (meta['fields'] as Map?) ?? const {};
    // 物価は上昇率（%）で届く。指数として届いたとき（meta に「上昇率」が無い）はそのまま
    final cpiRate = '${fields['cpi'] ?? ''}'.contains('上昇率') || '${fields['cpi'] ?? ''}'.toLowerCase().contains('inflation');
    final cs = <String, EconCountry>{};
    final from = <String, int>{};
    for (final e in ((j['countries'] as Map?) ?? {}).entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      final ys = <int, EconYear>{};
      for (final y in ((m['years'] as Map?) ?? {}).entries) {
        final yi = int.tryParse('${y.key}');
        if (yi == null || y.value is! Map) continue;
        ys[yi] = EconYear.fromJson((y.value as Map).cast<String, dynamic>());
      }
      // 名目GDPが1つも無い国は使わない（作る国に回す）
      final real = [for (final x in ys.entries) if (x.value.gdpUsd != null && x.value.gdpUsd! > 0) x.key];
      if (real.isEmpty) continue;
      from[e.key as String] = real.reduce(math.min);
      final cities = [
        for (final c in (m['cities'] as List? ?? []))
          if (c is Map) EconCity('${c['name_ja'] ?? ''}', '${c['name_en'] ?? c['name_ja'] ?? ''}', (c['pop'] as num? ?? 0).toDouble()),
      ];
      cs[e.key as String] = EconCountry(e.key as String, '${m['currency'] ?? 'USD'}', cities, _fill(ys, cpiRate: cpiRate));
    }
    final evs = <EconEvent>[
      for (final e in (j['events'] as List? ?? []))
        if (e is Map && e['year'] is num)
          EconEvent(
            year: (e['year'] as num).round(),
            month: (e['month'] as num?)?.round(),
            countries: [for (final c in (e['countries'] as List? ?? [])) '$c'],
            kind: '${e['kind'] ?? ''}',
            ja: '${e['name_ja'] ?? e['name_en'] ?? ''}',
            en: '${e['name_en'] ?? e['name_ja'] ?? ''}',
            gdpHit: (e['gdp_hit'] as num? ?? 0).toDouble(),
            noteJa: '${e['note_ja'] ?? ''}',
            noteEn: '${e['note_en'] ?? ''}',
          ),
    ]..sort((a, b) => a.year != b.year ? a.year - b.year : (a.month ?? 0) - (b.month ?? 0));
    final jp = cs['jp'];
    final first = jp?.years.keys.reduce(math.min) ?? 1980;
    final last = jp?.years.keys.reduce(math.max) ?? 2025;
    final note = '${meta['note'] ?? ''}';
    final prov = meta['provisional'] == true || note.contains('仮');
    final d = EconData._(meta, cs, evs, prov, first, last);
    d._from.addAll(from);
    for (final c in codes) {
      if (!cs.containsKey(c)) cs[c] = d.synth(c, shape);
    }
    return d;
  }

  final Map<String, int> _from = {};

  /// その国の数字が本当にある最初の年（それより前は、国として選べない・出られない。例: ロシアは1991年まで無い）。作った国は最初の年
  int availableFrom(String c) => _from[c] ?? firstYear;

  /// 値が null の年を前後から補い、最初の年から最後の年まで全部の年をそろえる。
  /// [cpiRate] なら物価は上昇率として補い、最初の年を100とする指数に積み上げる。最低賃金は平均賃金（自国の通貨の月額）との比で補う
  static Map<int, EconYear> _fill(Map<int, EconYear> ys, {bool cpiRate = false}) {
    final lo = ys.keys.reduce(math.min), hi = ys.keys.reduce(math.max);
    final out = <int, EconYear>{for (var y = lo; y <= hi; y++) y: ys[y]?.copy() ?? EconYear()};
    void fillKey(String k, {required bool ratio, double? def}) {
      final known = [for (var y = lo; y <= hi; y++) if (out[y]!.get(k) != null && out[y]!.get(k)!.isFinite) y];
      if (known.isEmpty) {
        for (final v in out.values) {
          v.set(k, def ?? _defaults[k]);
        }
        return;
      }
      for (var y = lo; y <= hi; y++) {
        if (known.contains(y)) continue;
        final a = known.lastWhere((x) => x < y, orElse: () => -1);
        final b = known.firstWhere((x) => x > y, orElse: () => -1);
        double v;
        if (a < 0) {
          v = out[b]!.get(k)!;
        } else if (b < 0) {
          v = out[a]!.get(k)!;
        } else {
          final va = out[a]!.get(k)!, vb = out[b]!.get(k)!;
          // 大きさの数（人口・GDP・指数・為替・賃金）は比で、率は差で補う
          v = ratio && va > 0 && vb > 0 ? va * math.pow(vb / va, (y - a) / (b - a)) : va + (vb - va) * (y - a) / (b - a);
        }
        out[y]!.set(k, v);
      }
    }

    for (final k in EconYear.keys) {
      if (k == 'min_wage') continue;
      fillKey(k, ratio: _ratioKeys.contains(k) && !(k == 'cpi' && cpiRate));
    }
    // 物価の上昇率を、最初の年を100とする指数に積み上げる（1年に-50%〜+10000%に抑える。ハイパーインフレでも数が壊れないように）
    if (cpiRate) {
      var idx = 100.0;
      for (var y = lo; y <= hi; y++) {
        final r = out[y]!.cpi!.clamp(-50.0, 10000.0);
        if (y > lo) idx *= 1 + r / 100;
        out[y]!.cpi = idx;
      }
    }
    // 最低賃金は、平均賃金（自国の通貨の月額）との比にしてから補う（制度の無い年・無い国でも、賃金の動きについていく）
    double monthly(EconYear v) => v.wageUsd! * v.fxUsd! / 12;
    for (final v in out.values) {
      final w = monthly(v);
      v.minWage = v.minWage != null && w > 0 && v.minWage! > 0 ? (v.minWage! / w).clamp(.05, 2.0) : null;
    }
    fillKey('min_wage', ratio: false, def: .35);
    for (final v in out.values) {
      v.minWage = v.minWage! * monthly(v);
    }
    return out;
  }

  static const _ratioKeys = {'pop', 'gdp_usd', 'cpi', 'fx_usd', 'wage_usd', 'min_wage'};
  static const Map<String, double> _defaults = {
    'pop': 1e7,
    'gdp_growth': 2.5,
    'gdp_usd': 1e11,
    'cpi': 100,
    'rate': 4,
    'fx_usd': 1,
    'wage_usd': 20000,
    'min_wage': 5,
    'corp_tax': 25,
    'unemp': 6,
  };

  /// データに無い国を、日本の数字と国の大きさの曲線から作る（仮。本物のデータが来れば使わない）。
  /// 通貨はドルとして持つ（為替は1）。物価は年3%、金利は5%
  EconCountry synth(String c, double Function(String c, double y)? shape) {
    final jp = countries['jp'];
    final ys = <int, EconYear>{};
    for (var y = firstYear; y <= lastYear; y++) {
      final j = jp?.years[y];
      final sz = shape?.call(c, y.toDouble()) ?? .2;
      final szPrev = shape?.call(c, y - 1.0) ?? .2;
      final jg = j?.gdpUsd ?? 3e12;
      final real = (sz / math.max(szPrev, 1e-9)) * (1 + (j?.gdpGrowth ?? 1) / 100) - 1;
      final pw = _synthWage[c] ?? 15000;
      ys[y] = EconYear(
        pop: (_synthPop[c] ?? 3e7) * math.pow(1.01, y - 2020).toDouble(),
        gdpGrowth: (real * 100).clamp(-8.0, 12.0).toDouble(),
        gdpUsd: jg * sz,
        cpi: 100 * math.pow(1.03, y - 2020).toDouble(),
        rate: 5,
        fxUsd: 1,
        wageUsd: pw * math.pow(1.025, y - 2020).toDouble(),
        minWage: pw * .4 / 12 * math.pow(1.025, y - 2020).toDouble(),
        corpTax: 25,
        unemp: 6,
      );
    }
    return EconCountry(c, 'USD', const [], ys, synthetic: true);
  }

  /// 作った国の2020年の平均賃金（ドル。おおよその目安・仮）
  static const Map<String, double> _synthWage = {
    'cn': 14000, 'kr': 40000, 'tw': 30000, 'in': 3500, 'id': 4500, 'th': 7000, 'vn': 3800, 'ph': 4000, 'sg': 60000, //
    'us': 66000, 'ca': 52000, 'mx': 9000, 'br': 8500, 'uk': 47000, 'de': 52000, 'fr': 45000, 'it': 37000, 'es': 35000, //
    'ru': 9000, 'sa': 28000, 'ng': 2200, 'za': 12000, 'au': 55000, 'jp': 38000,
  };

  /// 作った国の2020年の人口（人。おおよそ・仮）
  static const Map<String, double> _synthPop = {
    'cn': 1.41e9, 'kr': 5.2e7, 'tw': 2.36e7, 'in': 1.38e9, 'id': 2.7e8, 'th': 7e7, 'vn': 9.7e7, 'ph': 1.1e8, 'sg': 5.7e6, //
    'us': 3.31e8, 'ca': 3.8e7, 'mx': 1.29e8, 'br': 2.13e8, 'uk': 6.7e7, 'de': 8.3e7, 'fr': 6.7e7, 'it': 5.9e7, 'es': 4.7e7, //
    'ru': 1.44e8, 'sa': 3.5e7, 'ng': 2.06e8, 'za': 5.9e7, 'au': 2.57e7, 'jp': 1.26e8,
  };

  // ===== 引く =====
  /// 予測の種（遊びごとに決める。Game が持って保存する）。予測の控えはこの種が変わると作り直す
  int fcSeed = 1;
  final Map<String, Map<int, EconYear>> _fc = {};
  int _fcFor = -1;

  /// [c] の [y] 年の数字（データの範囲の外は、前は最初の年、後ろは予測）
  EconYear year(String c, int y) {
    final k = countries[c] ?? countries['jp']!;
    if (y < firstYear) return k.years[firstYear] ?? k.years.values.first;
    final have = k.years[y];
    if (have != null) return have;
    return forecast(c, y);
  }

  /// [c] の小数の年（年＋(月-1)/12）の数字。物価・為替・賃金・金利などは月ごとに前後の年をならす。成長率はその年の値
  double at(String c, double yr, String key) {
    final y0 = yr.floor();
    final f = yr - y0;
    final a = year(c, y0).get(key) ?? 0;
    if (key == 'gdp_growth' || key == 'corp_tax' || f == 0) return a;
    final b = year(c, y0 + 1).get(key) ?? a;
    if (_ratioKeys.contains(key) && a > 0 && b > 0) return a * math.pow(b / a, f).toDouble();
    return a + (b - a) * f;
  }

  /// 2026年より先（データの最後の年より先）の予測。直近5年の傾向にぶれを足す。ぶれは国と年の種で決まる
  EconYear forecast(String c, int y) {
    if (_fcFor != fcSeed) {
      _fc.clear();
      _fcFor = fcSeed;
    }
    final m = _fc.putIfAbsent(c, () => {});
    final got = m[y];
    if (got != null) return got;
    final k = countries[c] ?? countries['jp']!;
    final last = k.years.keys.reduce(math.max);
    if (y <= last) return k.years[y]!;
    final prev = y - 1 <= last ? k.years[y - 1]! : forecast(c, y - 1);
    // 直近5年（データの最後まで）の平均
    double avg(String key, {double lo = -1e18, double hi = 1e18}) {
      var s = 0.0, n = 0;
      for (var i = last - 4; i <= last; i++) {
        final v = k.years[i]?.get(key);
        if (v != null) {
          s += v.clamp(lo, hi);
          n++;
        }
      }
      return n == 0 ? (_defaults[key] ?? 0) : s / n;
    }

    double infl() {
      var s = 0.0, n = 0;
      for (var i = last - 4; i <= last; i++) {
        final a = k.years[i - 1]?.cpi, b = k.years[i]?.cpi;
        if (a != null && b != null && a > 0) {
          s += b / a - 1;
          n++;
        }
      }
      return n == 0 ? .02 : (s / n).clamp(-.01, .08).toDouble();
    }

    final r = math.Random(fcSeed * 7919 + c.codeUnits.fold(0, (a, b) => a * 31 + b) * 131 + y);
    double gauss() {
      final u = math.max(1e-9, r.nextDouble()), v = r.nextDouble();
      return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
    }

    final trend = avg('gdp_growth', lo: -2, hi: 8) * math.pow(.97, y - last).toDouble();
    var g = trend + gauss() * 1.3;
    // 時々の不況（1年に約7%）
    if (r.nextDouble() < .07) g = -1.0 - r.nextDouble() * 3;
    final inf = infl() + gauss() * .008;
    final fxDrift = gauss() * .05;
    final out = EconYear(
      pop: (prev.pop ?? 1e7) * (1 + ((k.years[last]?.pop ?? 1) / (k.years[last - 5]?.pop ?? 1) - 1) / 5 * .8),
      gdpGrowth: g,
      gdpUsd: (prev.gdpUsd ?? 1e11) * (1 + g / 100) * (1 + inf) / (1 + fxDrift),
      cpi: (prev.cpi ?? 100) * (1 + inf),
      rate: ((prev.rate ?? 3) + gauss() * .4 + (inf * 100 + 1.5 - (prev.rate ?? 3)) * .15).clamp(0.0, 20.0).toDouble(),
      fxUsd: (prev.fxUsd ?? 1) * (1 + fxDrift),
      wageUsd: (prev.wageUsd ?? 2e4) * (1 + inf + math.max(0, g) / 100 * .6) / (1 + fxDrift),
      minWage: (prev.minWage ?? 5) * (1 + inf + .01),
      corpTax: prev.corpTax,
      unemp: ((prev.unemp ?? 5) + (g < 0 ? 1.2 : -.25) + gauss() * .2).clamp(1.5, 25.0).toDouble(),
    );
    m[y] = out;
    return out;
  }

  /// その国の都市（データに無ければ空）
  List<EconCity> cities(String c) => countries[c]?.cities ?? const [];

  /// 出来事の名前と説明の英語（日本語 → 英語。画面の文の表に足す）
  Map<String, String> enTexts() => {
        for (final e in events) ...{
          if (e.ja.isNotEmpty) e.ja: e.en,
          // 説明の英語が無い出来事は、景気の向きだけを英語で言う
          if (e.noteJa.isNotEmpty) e.noteJa: e.noteEn.isNotEmpty ? e.noteEn : (e.gdpHit >= 0 ? 'The economy is booming.' : 'The economy has taken a hard hit.'),
        },
        for (final c in countries.values)
          for (final x in c.cities)
            if (x.ja.isNotEmpty) x.ja: x.en,
      };
}
