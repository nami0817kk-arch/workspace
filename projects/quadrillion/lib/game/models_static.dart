/// 変わらない定義（業種・シナジー・特性・宿敵・国など）の型。
/// 名前と説明は日本語で持ち（[ja] など）、`name` などの読み出しで今の言語にする（英語は lib/l10n/data_en.dart）。
library;

import '../l10n/l10n.dart';

class Industry {
  final String id, ja, cat;

  /// 生まれる年・頂点・沈み始め（0 は沈まない）
  final int b, p, f;

  /// 利益率・景気への弱さ
  final double mg, sens;

  /// 元手（2020年の円）・国内の市場（四半期・頂点・2020年の円）
  final double capex, size;

  /// 効く能力
  final String key;
  const Industry(this.id, this.ja, this.cat, this.b, this.p, this.f, this.mg, this.sens, this.capex, this.size, this.key);

  /// 今の言語の名前
  String get name => de(ja);
}

class Synergy {
  final String a, b, ja;
  const Synergy(this.a, this.b, this.ja);
  String get k => '$a+$b';
  String get name => de(ja);
}

class BigSynergy {
  final String k, ja;
  final List<String> set;
  const BigSynergy(this.k, this.ja, this.set);
  String get name => de(ja);
}

class Trait {
  final String id, nJa, gJa, bJa;
  const Trait(this.id, this.nJa, this.gJa, this.bJa);
  String get n => de(nJa);
  String get g => de(gJa);
  String get b => de(bJa);
}

class RivalDef {
  final String k, pres, co, type;
  final String? label;
  final int tier;
  final String col;
  const RivalDef(this.k, this.pres, this.co, this.type, this.label, this.tier, this.col);
}

class Country {
  final String c, ja, cityJa;
  final double a, b, m, k;
  const Country(this.c, this.ja, this.cityJa, this.a, this.b, this.m, this.k);
  String get n => de(ja);
  String get city => de(cityJa);
}

class Culture {
  final String nJa, gJa, bJa;
  const Culture(this.nJa, this.gJa, this.bJa);
  String get n => de(nJa);
  String get g => de(gJa);
  String get b => de(bJa);
}

class Place {
  final String id, nJa, sJa;
  const Place(this.id, this.nJa, this.sJa);
  String get n => de(nJa);
  String get s => de(sJa);
}

/// 日本語の値を持ち、読み出しで今の言語にする表（MODELN などの名前・説明の表に使う）
class LMap {
  final Map<String, String> ja;
  const LMap(this.ja);
  String? operator [](Object? k) {
    final v = ja[k];
    return v == null ? null : de(v);
  }

  Iterable<String> get keys => ja.keys;
  Iterable<MapEntry<String, String>> get entries => ja.keys.map((k) => MapEntry(k, de(ja[k]!)));
  bool containsKey(Object? k) => ja.containsKey(k);
}

/// 日本語の値を持ち、読み出しで今の言語にする並び
class LList {
  final List<String> ja;
  const LList(this.ja);
  String operator [](int i) => de(ja[i]);
  int get length => ja.length;
}
