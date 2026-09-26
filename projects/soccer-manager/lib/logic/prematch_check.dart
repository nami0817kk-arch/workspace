import '../models/player.dart';
import '../models/formation.dart';
import '../models/team.dart';
import '../l10n/tr.dart';
import 'lineup_utils.dart';

/// 試合前に気づいておきたいこと1件。
class PreMatchWarning {
  /// 画面に出す一文。
  final String message;

  /// 試合の結果に直接響くもの(出られない選手がスタメンにいる等)は true。
  /// 並べ替えと色分けに使う。
  final bool serious;

  const PreMatchWarning({required this.message, this.serious = false});
}

/// 試合を始める前に、スタメンの取りこぼしを拾う。
///
/// 負傷や出場停止の選手をスタメンに置いたまま、疲労が振り切れた選手を
/// 並べたまま試合に入っても、何も言われなかった。気づくのは結果が出た後で、
/// そのときにはもう1試合ぶんの勝点が戻らない。
///
/// 出すのは「いま直せること」だけにする。直しようのない話を並べても、
/// 読み飛ばす画面が1枚増えるだけになる。
class PreMatchCheck {
  const PreMatchCheck._();

  /// この疲労以上は、試合に出しても力を出せない(育成アドバイザーと同じ線)。
  static const int fatigueThreshold = 75;

  /// この実戦感覚未満は、成長にも出来にも不利が付く水準。
  static const int sharpnessThreshold = 40;

  /// 交代枠を使うために要る、出られる控えの人数。
  static const int minBenchPlayers = 3;

  static List<PreMatchWarning> run(Team team) {
    final warnings = <PreMatchWarning>[];
    final starters = team.players
        .where((p) => team.startingXI.contains(p.id))
        .toList();

    // 出られない選手がスタメンに入っている。そのまま試合に入ると、
    // 実質10人以下で戦うことになる。
    final unavailable = starters.where(_cannotPlay).toList();
    for (final p in unavailable) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('${p.name}は${_reasonFor(p)}のため出場できません。スタメンから外してください。',
            '${p.name} cannot play (${_reasonFor(p)}). Take him out of the XI.'),
        serious: true,
      ));
    }

    if (starters.length < 11) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('スタメンが${starters.length}人です。',
            'Only ${starters.length} players are in the XI.'),
        serious: true,
      ));
    }

    // 疲労。1人ずつ挙げると長くなるので、人数でまとめる。
    final tired =
        starters.where((p) => !_cannotPlay(p) && p.fatigue >= fatigueThreshold);
    if (tired.isNotEmpty) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('疲労が濃い選手が${tired.length}人スタメンにいます(${tired.first.name}ほか)。',
            '${tired.length} tired players are starting (${tired.first.name} and others).'),
      ));
    }

    // 実戦感覚。昇格直後や長く出ていない選手がここに入る。
    final rusty = starters.where(
        (p) => !_cannotPlay(p) && p.matchSharpness < sharpnessThreshold);
    if (rusty.isNotEmpty) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('実戦感覚が戻っていない選手が${rusty.length}人います(${rusty.first.name}ほか)。',
            '${rusty.length} players are short of match sharpness (${rusty.first.name} and others).'),
      ));
    }

    // 本職から離れた配置。慣れ度が低いほど力を出せない。
    final slots = team.formation.slots;
    final assignments = LineupUtils.resolveSlotAssignments(team);
    var outOfPosition = 0;
    String? firstName;
    for (var i = 0; i < slots.length && i < assignments.length; i++) {
      final p = assignments[i];
      if (p == null || _cannotPlay(p)) continue;
      if (p.position == slots[i]) continue;
      if (p.secondaryPositions.contains(slots[i])) continue;
      outOfPosition++;
      firstName ??= p.name;
    }
    if (outOfPosition > 0) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('本職ではないポジションの選手が$outOfPosition人います($firstNameほか)。',
            '$outOfPosition players are out of position ($firstName and others).'),
      ));
    }

    // 交代要員。3人残っていないと、負傷や劣勢に手を打てない。
    final bench = team.players
        .where((p) => !team.startingXI.contains(p.id) && !_cannotPlay(p))
        .length;
    if (bench < minBenchPlayers) {
      warnings.add(PreMatchWarning(
        message: Tr.pick('交代で出せる選手が$bench人しかいません。',
            'Only $bench players are available from the bench.'),
      ));
    }

    // 重いものから出す。読み飛ばされても、最初の1行は目に入る。
    warnings.sort((a, b) => (b.serious ? 1 : 0).compareTo(a.serious ? 1 : 0));
    return warnings;
  }

  static bool _cannotPlay(Player p) =>
      p.isInjured || p.isSuspended || p.isLoanedOut || p.isOnInternationalDuty;

  static String _reasonFor(Player p) {
    if (p.isInjured) return Tr.pick('負傷', 'injured');
    if (p.isSuspended) return Tr.pick('出場停止', 'suspended');
    if (p.isLoanedOut) return Tr.pick('ローン放出中', 'out on loan');
    return Tr.pick('代表召集中', 'on international duty');
  }
}
