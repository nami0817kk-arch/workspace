import 'build.dart';
import 'game.dart';
import 'honors.dart';
import 'skills.dart';
import 'traits.dart';

/// 図鑑。何人の人生をまたいで、集めた個人タイトル・ビルド・特性・得意技を覚えておく。
/// 殿堂の履歴(30人まで)とは別に、集めたものは消えない。引退したときに1度だけ足す。
class Collection {
  const Collection({
    this.honors = const {},
    this.traits = const {},
    this.skills = const {},
    this.builds = const {},
  });

  const Collection.empty() : this();

  /// 取ったことのある個人タイトル(`Honor`)。
  final Set<String> honors;

  /// 持ったことのある特性(`Trait.name`)。
  final Set<String> traits;

  /// 身につけたことのある得意技(`Skill.name`)。
  final Set<String> skills;

  /// ビルドごとの、到達した最高のティア(`Build.name` → 0〜3)。
  final Map<String, int> builds;

  /// 図鑑の総数。
  static int get honorTotal => Honor.all.length;
  static int get traitTotal => Trait.values.length;
  static int get skillTotal => Skill.values.length;
  static int get buildTotal => Build.values.length;

  /// 集めた数(全部の合計)と、全体の数。
  int get collected => honors.length + traits.length + skills.length + builds.length;
  int get total => honorTotal + traitTotal + skillTotal + buildTotal;

  /// 1人の人生で集めたものを足す。
  Collection merge(Game g) {
    final seen = {...g.buildsSeen};
    final now = buildOf(g.player);
    if (now != null) seen.add('${now.build.name}:${now.tier}');
    final b = {...builds};
    for (final s in seen) {
      final parts = s.split(':');
      if (parts.length != 2) continue;
      final tier = int.tryParse(parts[1]) ?? 0;
      if (Build.values.any((x) => x.name == parts[0])) {
        b[parts[0]] = tier > (b[parts[0]] ?? -1) ? tier : (b[parts[0]] ?? tier);
      }
    }
    return Collection(
      honors: {...honors, ...g.honorCounts.keys},
      traits: {...traits, for (final t in g.player.traits) t.name},
      skills: {...skills, for (final k in g.player.skills) k.name},
      builds: b,
    );
  }

  Map<String, dynamic> toJson() => {
        'honors': honors.toList()..sort(),
        'traits': traits.toList()..sort(),
        'skills': skills.toList()..sort(),
        'builds': builds,
      };

  factory Collection.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Collection.empty();
    // 壊れた保存でも、読めるところだけ読む(型が違えば空として扱う)。
    Set<String> set(String k, bool Function(String) ok) {
      final raw = j[k];
      return {
        if (raw is List)
          for (final v in raw)
            if (v is String && ok(v)) v,
      };
    }

    final rawBuilds = j['builds'];
    return Collection(
      honors: set('honors', Honor.all.contains),
      traits: set('traits', (v) => Trait.parse(v) != null),
      skills: set('skills', (v) => Skill.parse(v) != null),
      builds: {
        for (final e in (rawBuilds is Map ? rawBuilds : const {}).entries)
          if (e.key is String &&
              Build.values.any((x) => x.name == e.key) &&
              e.value is num)
            e.key as String: (e.value as num).toInt().clamp(0, tierLabels.length - 1),
      },
    );
  }
}
