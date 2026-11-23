/// 変わらない定義（業種・シナジー・特性・宿敵・国など）の型。
library;

class Industry {
  final String id, name, cat;

  /// 生まれる年・頂点・沈み始め（0 は沈まない）
  final int b, p, f;

  /// 利益率・景気への弱さ
  final double mg, sens;

  /// 元手（2020年の円）・国内の市場（四半期・頂点・2020年の円）
  final double capex, size;

  /// 効く能力
  final String key;
  const Industry(this.id, this.name, this.cat, this.b, this.p, this.f, this.mg, this.sens, this.capex, this.size, this.key);
}

class Synergy {
  final String a, b, name;
  const Synergy(this.a, this.b, this.name);
  String get k => '$a+$b';
}

class BigSynergy {
  final String k, name;
  final List<String> set;
  const BigSynergy(this.k, this.name, this.set);
}

class Trait {
  final String id, n, g, b;
  const Trait(this.id, this.n, this.g, this.b);
}

class RivalDef {
  final String k, pres, co, type;
  final String? label;
  final int tier;
  final String col;
  const RivalDef(this.k, this.pres, this.co, this.type, this.label, this.tier, this.col);
}

class Country {
  final String c, n, city;
  final double a, b, m, k;
  const Country(this.c, this.n, this.city, this.a, this.b, this.m, this.k);
}

class Culture {
  final String n, g, b;
  const Culture(this.n, this.g, this.b);
}

class Place {
  final String id, n, s;
  const Place(this.id, this.n, this.s);
}
