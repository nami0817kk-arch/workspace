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

/// [asFemale] を渡すと性別をそれにする（2026-11-23 ユーザー「男か女は選べるように」）。
/// 乱数の流れを変えないよう、性別の籤はいつも引いてから置き換える。選んだ性別は稀少度に数えない。
Birth rollBirth(Rng r, {bool? asFemale}) {
  final female0 = asFemale;
  final totalC = kClasses.fold<double>(0, (s, c) => s + c.w);
  final cls = r.wpick(kClasses, (c) => c.w);
  final reg = r.wpick(kRegions, (c) => c.w);
  final fac = r.pick(reg.f);
  final startYear = r.range(1525, 1568);
  final month = r.range(1, 12), day = r.range(1, 28);
  final rolledFemale = r.chance(.49);
  final female = female0 ?? rolledFemale;
  final od = r.wpick(const [(.45, 1), (.3, 2), (.25, 3)], (e) => e.$1);
  final order = od.$2;
  final classP = cls.w / totalC;
  // 生まれの稀少度は「同じような生まれの人が、戦国の民のうちにどれだけ珍しいか」。
  // 数えるのは、身分・性別・生まれ順と、特性を持つか・際立った能力か。生まれた年・月日・国・特性の種類は
  // 誰でも必ずどれかに当たるので数えない（数えると、ありふれた農民の子まで「数千億分の1」になり、
  // 千五百万の民という前提と食い違っていた。2026-11-23 ユーザー指摘）。
  var p = classP * (female0 == null ? .5 : 1) * od.$1;

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

  // 特性（2026-11-24 に100へ）: 段ごとに一度ずつ籤を引き、当たればその段の特性を一つ持つ
  // （幻→稀→珍しい→よくある の順。多くて kMaxTraits）。身分・性別で付かない特性は籤の前に外す。
  // 特性を持たないのが当たり前（並）。持つことだけを、その段の珍しさとして数える（特性の種類は数えない）。
  final tr = traitDraw(r, cls, female);
  for (final t in tr) {
    p *= t.tier.chance;
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

/// 試しに遊ぶための生まれの指定（2026-11-24、ユーザー「テスト用に、自分で諸々生まれ方を決められるようにして」）。
/// null の項目は籤に任せる。ふつうの遊びには出さない（タイトルの題字を長押しした先だけ）。
class BirthSpec {
  const BirthSpec({
    this.clsId,
    this.region,
    this.faction,
    this.startYear,
    this.female,
    this.order,
    this.traitIds,
    this.stats,
  });

  final String? clsId, region, faction;
  final int? startYear, order;
  final bool? female;

  /// 持たせる特性（多くて [kMaxTraits]）。null なら籤のまま、空なら特性なし。
  final List<String>? traitIds;

  /// 能力（武・知・政・魅・運）。null なら籤と身分・特性の上げ下げのまま。指定すればこの値そのもの。
  final List<int>? stats;
}

/// 指定した生まれを作る。まず籤を引き、指定した項目だけを置き換える（名・特性の効き・身分の名は合わせて作り直す）。
Birth customBirth(Rng r, BirthSpec s) {
  final b = rollBirth(r, asFemale: s.female);
  final cls = s.clsId == null
      ? b.cls
      : kClasses.firstWhere((c) => c.id == s.clsId, orElse: () => b.cls);
  final reg = s.region == null
      ? b.region
      : kRegions.firstWhere((x) => x.n == s.region, orElse: () => b.region);
  final fac = s.faction != null && reg.f.contains(s.faction)
      ? s.faction!
      : (reg.f.contains(b.faction) ? b.faction : reg.f.first);
  final female = s.female ?? b.female;
  final order = clampInt(s.order ?? b.order, 1, 3);
  final traits = s.traitIds == null
      ? b.traits
      : [
          for (final id in s.traitIds!.take(kMaxTraits))
            ...kTraits.where((t) => t.id == id),
        ];

  // 能力: 指定があればその値。無ければ籤の値を、身分・性別・特性の上げ下げごと作り直す
  // （籤の身分の上げ下げを外し、指定した身分の上げ下げを掛け直す）。
  final Abil a;
  if (s.stats != null && s.stats!.length == 5) {
    final v = [for (final x in s.stats!) clampInt(x, 3, 99)];
    a = Abil(v[0], v[1], v[2], v[3], v[4], b.stats.maxhp);
  } else {
    final v = {
      'bu': b.stats.bu,
      'chi': b.stats.chi,
      'sei': b.stats.sei,
      'mi': b.stats.mi,
      'un': b.stats.un,
    };
    if (cls != b.cls) {
      b.cls.mod.forEach((k, d) => v[k] = v[k]! - d);
      cls.mod.forEach((k, d) => v[k] = v[k]! + d);
    }
    if (b.female != female) {
      v['bu'] = v['bu']! + (female ? -4 : 4);
      v['mi'] = v['mi']! + (female ? 3 : -3);
    }
    a = Abil(
      v['bu']!,
      v['chi']!,
      v['sei']!,
      v['mi']!,
      v['un']!,
      b.stats.maxhp,
    );
    // 籤で付いていなかった特性の上げ下げだけを掛ける（籤の特性の分は、もう能力に入っている）。
    for (final t in traits) {
      if (!b.traits.contains(t)) t.fx(a);
    }
    a
      ..bu = clampInt(a.bu, 3, 99)
      ..chi = clampInt(a.chi, 3, 99)
      ..sei = clampInt(a.sei, 3, 99)
      ..mi = clampInt(a.mi, 3, 99)
      ..un = clampInt(a.un, 3, 99)
      ..maxhp = clampInt(a.maxhp, 50, 130);
  }

  final changedName =
      cls != b.cls || reg != b.region || fac != b.faction || female != b.female;
  final String name;
  if (!changedName) {
    name = b.name;
  } else if (cls.id == 'daimyo') {
    name = '$fac家 ${female ? r.pick(kHimeNames) : r.pick(kHeirNames)}';
  } else if (cls.rank >= 1) {
    name = '${r.pick(kSurnames)} ${female ? r.pick(kGivenF) : r.pick(kGivenM)}';
  } else {
    name = '${reg.n}の${female ? r.pick(kGivenF) : r.pick(kGivenM)}';
  }

  final totalC = kClasses.fold<double>(0, (s, c) => s + c.w);
  return Birth(
    cls: cls,
    region: reg,
    faction: fac,
    startYear: clampInt(s.startYear ?? b.startYear, 1525, 1568),
    month: b.month,
    day: b.day,
    female: female,
    order: order,
    stats: a,
    traits: traits,
    // 指定した生まれは、珍しさを数えない（籤で引いたものではないので）。
    rarity: 1,
    name: name,
    label: clsLabel(cls, female, order),
    sameClass: kPopulation * cls.w / totalC,
    birthRank: calcBirthRank(cls, female, order),
  );
}

/// 一人が持つ特性の数の上限。
const kMaxTraits = 3;

/// 生まれの特性の籤（`rollBirth` が使う。テストも使う）。段ごとに必ず一度ずつ籤を引く（乱数の流れを揃えるため）。
List<Trait> traitDraw(Rng r, ClassDef cls, bool female) {
  final tr = <Trait>[];
  for (final tier in const [
    TraitTier.mythic,
    TraitTier.rare,
    TraitTier.uncommon,
    TraitTier.common,
  ]) {
    // 女性の「珍しい」の段だけ、女武者の分を上乗せして引く（籤の回数は変えない）。
    final ch =
        tier.chance +
        (female && tier == TraitTier.uncommon ? kOnnaExtraChance : 0);
    if (!r.chance(ch) || tr.length >= kMaxTraits) continue;
    final pool = [
      for (final t in kTraits)
        if (t.tier == tier && t.fits(cls, female)) t,
    ];
    if (pool.isEmpty) continue;
    tr.add(r.wpick(pool, (t) => t.w));
  }
  return tr;
}

String rarityText(double n) {
  if (n >= kPopulation) return '千五百万の民のうち、\nただ一人いるかどうかの生まれ';
  if (n >= 1e6) return '百万に一人の、天に選ばれし生まれ';
  if (n >= 1e5) return '十万に一人。歴史に名を残す器かもしれない';
  if (n >= 1e4) return '万に一人の、稀有な生まれ';
  if (n >= 1e3) return '千人に一人の巡り合わせ';
  return 'ありふれた、しかし確かな一つの命';
}
