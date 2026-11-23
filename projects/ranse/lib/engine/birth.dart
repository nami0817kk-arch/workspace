import 'data.dart';
import 'rng.dart';

/// 生まれの抽選結果。この時点では人生はまだ始まっていない。
class Birth {
  Birth({
    required this.cls,
    required this.region,
    required this.faction,
    required this.startYear,
    required this.month,
    required this.day,
    required this.female,
    required this.order,
    required this.stats,
    required this.traits,
    required this.rarity,
    required this.name,
    required this.label,
    required this.sameClass,
    required this.birthRank,
  });

  final ClassDef cls;
  final Region region;
  final String faction;
  final int startYear, month, day;
  final bool female;
  final int order;
  final Abil stats;
  final List<Trait> traits;

  /// 「この組み合わせで生まれる確率」の逆数。
  final double rarity;
  final String name, label;

  /// 戦国の日本で同じ身分に生まれた人の数（概算）。
  final double sameClass;
  final int birthRank;
}

String clsLabel(ClassDef cls, bool female, int order) {
  if (cls.id == 'daimyo') {
    if (female) return '大名の姫';
    return order == 1 ? '大名の嫡男' : '大名の${['', '', '次', '三'][order]}男';
  }
  return cls.name;
}

String ordLabel(bool female, int order) =>
    '${['', '長', '次', '三'][order]}${female ? '女' : '男'}${order == 3 ? '以下' : ''}';

/// 十五歳で得る身分。女性・次男以下は一つ下がる。
int calcBirthRank(ClassDef cls, bool female, int order) {
  final r = cls.rank;
  if (cls.id == 'daimyo') return female ? 4 : (order == 1 ? 8 : 5);
  if (female) return r - 2 < 0 ? 0 : r - 2;
  if (order >= 2 && r >= 1) {
    final d = r >= 5 ? r - 2 : r - 1;
    return d < 0 ? 0 : d;
  }
  return r;
}

Birth rollBirth(Rng r) {
  final totalC = kClasses.fold<double>(0, (s, c) => s + c.w);
  final cls = r.wpick(kClasses, (c) => c.w);
  final reg = r.wpick(kRegions, (c) => c.w);
  final fac = r.pick(reg.f);
  final startYear = r.range(1525, 1568);
  final month = r.range(1, 12), day = r.range(1, 28);
  final female = r.chance(.49);
  final od = r.wpick(const [(.45, 1), (.3, 2), (.25, 3)], (e) => e.$1);
  final order = od.$2;
  final classP = cls.w / totalC;
  // 生まれの稀少度は「同じような生まれの人が、戦国の民のうちにどれだけ珍しいか」。
  // 数えるのは、身分・性別・生まれ順と、特性を持つか・際立った能力か。生まれた年・月日・国・特性の種類は
  // 誰でも必ずどれかに当たるので数えない（数えると、ありふれた農民の子まで「数千億分の1」になり、
  // 千五百万の民という前提と食い違っていた。2026-11-23 ユーザー指摘）。
  var p = classP * .5 * od.$1;

  int base() => clampInt((40 + r.gauss() * 14).round(), 5, 95);
  final v = {
    'bu': base(),
    'chi': base(),
    'sei': base(),
    'mi': base(),
    'un': base(),
  };
  for (final x in v.values) {
    final z = (x - 40) / 14;
    final tail = 2 * (phi(z) < 1 - phi(z) ? phi(z) : 1 - phi(z));
    // 能力は、際立って高い（低い）ものだけを珍しさに数える（並の能力は誰にでもある）。
    if (tail < .2) p *= (tail < 0.02 ? 0.02 : tail) / .2;
  }
  cls.mod.forEach((k, d) => v[k] = v[k]! + d);
  if (female) {
    v['bu'] = v['bu']! - 4;
    v['mi'] = v['mi']! + 3;
  }

  final nt = r.chance(.45) ? 0 : (r.chance(.73) ? 1 : 2);
  final pool = [...kTraits];
  final tr = <Trait>[];
  for (var i = 0; i < nt; i++) {
    tr.add(pool.removeAt(r.range(0, pool.length - 1)));
  }
  // 特性を持たないのが当たり前（並）。持つことだけを珍しさに数える。
  p *= nt == 0 ? 1 : (nt == 1 ? .40 : .15);
  if (female && r.chance(.04)) {
    tr.add(kTraitOnna);
    p *= .04;
  }

  final a = Abil(v['bu']!, v['chi']!, v['sei']!, v['mi']!, v['un']!, 100);
  for (final t in tr) {
    t.fx(a);
  }
  a
    ..bu = clampInt(a.bu, 3, 99)
    ..chi = clampInt(a.chi, 3, 99)
    ..sei = clampInt(a.sei, 3, 99)
    ..mi = clampInt(a.mi, 3, 99)
    ..un = clampInt(a.un, 3, 99)
    ..maxhp = clampInt(a.maxhp, 50, 130);

  final String name;
  if (cls.id == 'daimyo') {
    name = '$fac家 ${female ? r.pick(kHimeNames) : r.pick(kHeirNames)}';
  } else if (cls.rank >= 1) {
    name = '${r.pick(kSurnames)} ${female ? r.pick(kGivenF) : r.pick(kGivenM)}';
  } else {
    name = '${reg.n}の${female ? r.pick(kGivenF) : r.pick(kGivenM)}';
  }

  return Birth(
    cls: cls,
    region: reg,
    faction: fac,
    startYear: startYear,
    month: month,
    day: day,
    female: female,
    order: order,
    stats: a,
    traits: tr,
    // 民の数より珍しくはなれない（上限は千五百万分の1）。
    rarity: 1 / p > kPopulation ? kPopulation.toDouble() : 1 / p,
    name: name,
    label: clsLabel(cls, female, order),
    sameClass: kPopulation * classP,
    birthRank: calcBirthRank(cls, female, order),
  );
}

String rarityText(double n) {
  if (n >= kPopulation) return '千五百万の民のうち、\nただ一人いるかどうかの生まれ';
  if (n >= 1e6) return '百万に一人の、天に選ばれし生まれ';
  if (n >= 1e5) return '十万に一人。歴史に名を残す器かもしれない';
  if (n >= 1e4) return '万に一人の、稀有な生まれ';
  if (n >= 1e3) return '千人に一人の巡り合わせ';
  return 'ありふれた、しかし確かな一つの命';
}
