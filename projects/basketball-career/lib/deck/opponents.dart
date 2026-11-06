/// 対戦相手。毎ラウンド、次に何をしてくるか(予告)を見せる。こちらはそれを見て、攻めるか守るかを決める。
library;

import 'rng.dart';

enum IntentKind {
  shot('ジャンプシュート'),
  three('3P'),
  drive('ドライブ'),
  fast('速攻'),
  post('ゴール下'),
  combo('連続攻撃'),
  press('堅い守り'),
  ace('エースの一撃');

  const IntentKind(this.label);
  final String label;
}

/// 相手の1ラウンドの予告。[hits] は1本ずつの点(守備は前から順に削る)。
class Intent {
  const Intent(this.kind, this.hits, {this.press = 0});
  final IntentKind kind;
  final List<int> hits;

  /// こちらのシュートを1本ごとに減らす点(堅い守り)。
  final int press;

  int get total => hits.fold(0, (a, b) => a + b);

  /// 画面に出す一言。
  String get label {
    final pts = hits.length > 1 ? '${hits.first}点×${hits.length}' : '${hits.first}点';
    if (press > 0) return '${kind.label}(こちらのシュート-$press)・$pts';
    return '${kind.label}・$pts';
  }

  Map<String, dynamic> toJson() => {'k': kind.name, 'h': hits, if (press > 0) 'p': press};
}

enum OppStyle {
  balance('バランス型', '攻めも守りも平均的'),
  fast('速攻型', '速攻とドライブが多い'),
  height('高さ型', 'ゴール下で大きく取ってくる'),
  outside('外角型', '3Pを続けて打ってくる'),
  defense('堅守型', '守りが堅く、こちらのシュートが減る');

  const OppStyle(this.label, this.text);
  final String label;
  final String text;
}

/// 段階(0: 地区予選・1: 県大会・2: 全国大会)。
const stageNames = ['地区予選', '県大会', '全国大会'];

class Opponent {
  Opponent({
    required this.name,
    required this.style,
    required this.stage,
    this.elite = false,
    this.boss = false,
    this.difficulty = 0,
  });

  final String name;
  final OppStyle style;
  final int stage;

  /// 強豪(勝つと仲間が加わる)。
  final bool elite;

  /// 大会の決勝(負けると敗退)。
  final bool boss;
  final int difficulty;

  /// 1本あたりの基準の点。段階・強豪・難しさで上がる。
  double get base =>
      6.0 + stage * 2.6 + (elite ? 1.5 : 0) + (boss ? 2.2 : 0) + difficulty * 0.15;

  String get tag => boss ? '決勝' : elite ? '強豪' : style.label;

  /// [round] は0から。決勝の相手は第4クォーターに勢いが付く。
  Intent intentFor(int round, Rng rng) {
    final kind = rng.weighted(_weights());
    var b = base + (boss && round >= 6 ? 2 : 0);
    int pts(double scale) => (b * scale + rng.nextInt(3) - 1).round().clamp(1, 99);
    return switch (kind) {
      IntentKind.shot => Intent(kind, [pts(1.0)]),
      IntentKind.three => Intent(kind, [pts(1.15)]),
      IntentKind.drive => Intent(kind, [pts(1.05)]),
      IntentKind.fast => Intent(kind, [pts(1.3)]),
      IntentKind.post => Intent(kind, [pts(1.25)]),
      IntentKind.combo => Intent(kind, [pts(0.6), pts(0.6)]),
      IntentKind.press => Intent(kind, [pts(0.55)], press: stage >= 2 || boss ? 2 : 1),
      IntentKind.ace => Intent(kind, [pts(1.8)]),
    };
  }

  Map<IntentKind, int> _weights() {
    final w = switch (style) {
      OppStyle.balance => {
          IntentKind.shot: 4, IntentKind.three: 2, IntentKind.drive: 2,
          IntentKind.fast: 1, IntentKind.post: 1, IntentKind.combo: 1, IntentKind.press: 1,
        },
      OppStyle.fast => {
          IntentKind.shot: 1, IntentKind.drive: 3, IntentKind.fast: 3, IntentKind.combo: 2,
        },
      OppStyle.height => {
          IntentKind.shot: 2, IntentKind.post: 4, IntentKind.drive: 1, IntentKind.press: 1,
        },
      OppStyle.outside => {
          IntentKind.shot: 1, IntentKind.three: 4, IntentKind.combo: 3,
        },
      OppStyle.defense => {
          IntentKind.shot: 2, IntentKind.press: 4, IntentKind.drive: 1, IntentKind.three: 1,
        },
    };
    if (boss || (elite && stage >= 1)) w[IntentKind.ace] = 2;
    return w;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'style': style.name,
        'stage': stage,
        if (elite) 'elite': true,
        if (boss) 'boss': true,
        'dif': difficulty,
      };

  static Opponent fromJson(Map<String, dynamic> j) => Opponent(
        name: j['name'] as String? ?? '対戦校',
        style: OppStyle.values.firstWhere((s) => s.name == j['style'], orElse: () => OppStyle.balance),
        stage: (j['stage'] as num?)?.toInt() ?? 0,
        elite: j['elite'] == true,
        boss: j['boss'] == true,
        difficulty: (j['dif'] as num?)?.toInt() ?? 0,
      );
}

/// チーム名の頭(地名)。色は `lib/ui/team_colors.dart` の `teamPrefixColors` で決まる。
const teamPrefixes = [
  '北嶺', '南陽', '東雲', '西浜', '青葉', '白鷺', '紅葉', '朝日', '双葉', '桜台',
  '星丘', '翠山', '蒼海', '大和', '緑風',
];

/// 決勝で待つライバル校(段階ごと)。
const bossNames = ['東雲学園', '星丘工業', '翠山大附属'];

/// 自分たちの学校。
const homeTeam = '朝日高校';

Opponent makeOpponent(Rng rng, {required int stage, bool elite = false, bool boss = false, int difficulty = 0}) {
  if (boss) {
    final style = [OppStyle.balance, OppStyle.outside, OppStyle.height][stage % 3];
    return Opponent(name: bossNames[stage % 3], style: style, stage: stage, boss: true, difficulty: difficulty);
  }
  final prefixes = teamPrefixes.where((p) => !homeTeam.startsWith(p)).toList();
  final p = rng.pick(prefixes);
  final suffix = elite ? rng.pick(const ['学園', '工業', '大附属']) : rng.pick(const ['高校', '南高校', '北高校', '商業']);
  final style = rng.pick(OppStyle.values);
  return Opponent(name: '$p$suffix', style: style, stage: stage, elite: elite, difficulty: difficulty);
}
