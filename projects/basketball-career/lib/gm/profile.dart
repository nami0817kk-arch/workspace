import 'career.dart';
import 'codex.dart';
import 'legacy.dart';
import 'player.dart';

/// 実績。任期をまたいで端末に残る。
enum Achievement {
  firstTitle('はじめての優勝', 'ファイナルで勝って優勝する'),
  rebuildTitle('どん底からの頂点', '「立て直し」のチームを任されて優勝する'),
  backToBack('連覇', '2年続けて優勝する'),
  dynasty('黄金期', '1回の任期で3回優勝する'),
  bigSeason('圧倒', 'レギュラーシーズンで60勝する'),
  homegrown('生え抜きのエース', '自分で指名した選手の力が80に届く'),
  dealer('やり手', '1回の任期でトレードを8回成立させる'),
  fullTerm('10年の任期', '解任されずに10年を務める'),
  longHaul('長期政権', '解任されずに20年を務める'),
  level5('敏腕', 'GM の格が5になる'),
  level10('殿堂のGM', 'GM の格が10になる'),
  lottery('くじを引き当てる', 'ドラフトで全体1位の指名権を手にする'),
  capMaster('身の丈経営', 'ぜいたく税を払わずに優勝する'),
  mvp('MVPを育てる', '自分のチームの選手がMVPに選ばれる'),

  // 縛りの実績(2026-11-15、ユーザー「更に調査」。Basketball GM の「年俸が上限の半分以下で優勝」のような縛りが、
  // 長く遊ぶ目標になっているという声から)。保存は名前なので、並びは変えてよい
  quickRebuild('3年で頂点', '強さ23位以下のチームを任され、3シーズン以内に優勝する'),
  threePeat('3連覇', '3年続けて優勝する'),
  homegrownCore('生え抜きの先発', '自分で指名した選手を先発に3人以上置いて優勝する'),
  youngTitle('若き王者', '先発5人の平均年齢が25歳以下で優勝する'),
  veteranTitle('ベテランの意地', '先発5人の平均年齢が31歳以上で優勝する'),
  underCap('倹約の優勝', '年俸の合計が上限(1.65億ドル)以下のまま優勝する'),
  sweep('完全制覇', 'プレーオフを1敗もせずに優勝する'),
  allGoals('オーナーの信頼', 'オーナーの目標を1シーズンで全部果たす'),
  wordKeeper('有言実行', 'GMの言葉の重みを90まで上げる');

  const Achievement(this.title, this.text);
  final String title;
  final String text;
}

/// 端末に残る記録。
class Profile {
  Profile({Set<Achievement>? done, this.careers = 0, this.titles = 0, this.bestWins = 0, this.bestTitles = 0, this.bestLevel = 0, this.bestFirst10 = 0})
      : done = done ?? {};

  final Set<Achievement> done;
  int careers;
  int titles;
  int bestWins;

  /// 1回の任期での最多の優勝。
  int bestTitles;

  /// これまでで最も高い GM の格(段階)と、最初の10シーズンで取った点の最高(ランキングで比べる)。
  int bestLevel;
  int bestFirst10;

  bool has(Achievement a) => done.contains(a);

  /// GM の名鑑(D-1)。キャリア(リーグの種)ごとの、任期の札・殿堂の選手・名場面。任期をまたいで残る。
  final Map<int, ({List<TenureCard> tenures, List<LegendCard> legends, List<String> moments})> legacy = {};

  /// [c] の名鑑を書き直す(同じキャリアは上書き)。
  void recordLegacy(Career c) {
    legacy[c.seed] = (tenures: tenuresOf(c), legends: legendsOf(c), moments: momentsOf(c));
    // 古いものから消す(多くなりすぎないように)
    while (legacy.length > 20) {
      legacy.remove(legacy.keys.first);
    }
  }

  /// これまでの殿堂の選手の名前(新しいリーグの伝説にする)。
  List<String> get legendNames => [for (final l in legacy.values) ...l.legends.map((x) => x.name)].take(12).toList();

  /// 図鑑で見つけたもの(項目の key → いつ・何で見つけたか)。任期をまたいで残る(B-3)。
  final Map<String, String> codex = {};

  /// [c] で見つけたものを図鑑に足す(前に見つけたものは、そのまま)。新しく見つけた項目を返す。
  List<CodexEntry> syncCodex(Career c) {
    final got = <CodexEntry>[];
    for (final e in discoveriesOf(c).entries) {
      if (codex.containsKey(e.key)) continue;
      codex[e.key] = e.value;
      final entry = codexEntries.where((x) => x.key == e.key).firstOrNull;
      if (entry != null) got.add(entry);
    }
    return got;
  }

  List<Achievement> _grant(Iterable<Achievement> list) {
    final got = <Achievement>[];
    for (final a in list) {
      if (done.add(a)) got.add(a);
    }
    return got;
  }

  /// シーズンを終えたとき(プレーオフのあと)に呼ぶ。新しく達成した実績を返す。
  List<Achievement> recordSeason(Career c) {
    syncCodex(c);
    recordLegacy(c);
    final h = c.history.last;
    if (h.wins > bestWins) bestWins = h.wins;
    if (h.champion) titles++;
    if (c.gmLevel > bestLevel) bestLevel = c.gmLevel;
    if (c.gmPointsFirst10 > bestFirst10) bestFirst10 = c.gmPointsFirst10;
    final got = <Achievement>[
      if (h.champion) Achievement.firstTitle,
      if (h.champion && c.outlook == Outlook.rebuild) Achievement.rebuildTitle,
      if (h.champion && c.history.length >= 2 && c.history[c.history.length - 2].champion) Achievement.backToBack,
      if (c.titles >= 3) Achievement.dynasty,
      // 解任されずに続けた年数(誘いを受けて移った任期は数えない)
      if (!c.fired && c.stints.length <= 1 && c.history.length >= 10) Achievement.fullTerm,
      if (!c.fired && c.stints.length <= 1 && c.history.length >= 20) Achievement.longHaul,
      if (c.gmLevel >= 5) Achievement.level5,
      if (c.gmLevel >= 10) Achievement.level10,
      if (h.wins >= 60) Achievement.bigSeason,
      if (h.champion && c.lastTax == 0) Achievement.capMaster,
      if (c.awardsOf(c.season).any((a) => a.kind == AwardKind.mvp && a.team == c.mine)) Achievement.mvp,
      if (c.me.roster.any((p) => c.draftedIds.contains(p.id) && p.ovr >= 80)) Achievement.homegrown,
      ...challengesOf(c),
    ];
    return _grant(got);
  }

  /// 縛りの実績のうち、このシーズンで果たしたもの(シーズンの終わりに見る)。
  static List<Achievement> challengesOf(Career c) {
    final h = c.history.last;
    final starters = c.me.order.take(5).toList();
    final age = starters.isEmpty ? 0.0 : starters.fold(0, (n, p) => n + p.age) / starters.length;
    final mine = [for (final s in c.playoffs) if (s.high == c.mine || s.low == c.mine) s];
    final lost = mine.fold(0, (n, s) => n + (s.high == c.mine ? s.lowWins : s.highWins));
    final n = c.history.length;
    // 立て直しの早さは、今の任期の年数で数える
    final stintYears = c.history.where((r) => r.season >= c.stintStart).length;
    return [
      if (h.champion && c.startRank >= 22 && stintYears <= 3) Achievement.quickRebuild,
      if (h.champion && n >= 3 && c.history[n - 2].champion && c.history[n - 3].champion) Achievement.threePeat,
      if (h.champion && starters.where((p) => c.draftedIds.contains(p.id)).length >= 3) Achievement.homegrownCore,
      if (h.champion && starters.length == 5 && age <= 25) Achievement.youngTitle,
      if (h.champion && starters.length == 5 && age >= 31) Achievement.veteranTitle,
      if (h.champion && c.me.payroll <= salaryCap) Achievement.underCap,
      if (h.champion && mine.isNotEmpty && lost == 0) Achievement.sweep,
      if (c.goals.isNotEmpty && c.goals.every((g) => g.met == true)) Achievement.allGoals,
      if (c.word >= 90) Achievement.wordKeeper,
    ];
  }

  /// 動きのたびに呼ぶ(トレード・ドラフトの順番)。
  List<Achievement> recordProgress(Career c) {
    syncCodex(c);
    return _grant([
        if (c.tradesDone >= 8) Achievement.dealer,
        if (c.word >= 90) Achievement.wordKeeper,
        if (c.phase == Phase.draft && c.order.isNotEmpty && c.picks[c.order.first].owner == c.mine) Achievement.lottery,
        if (c.me.roster.any((p) => c.draftedIds.contains(p.id) && p.ovr >= 80)) Achievement.homegrown,
      ]);
  }

  /// 任期を閉じるときに呼ぶ。
  List<Achievement> recordCareerEnd(Career c) {
    syncCodex(c);
    recordLegacy(c);
    careers++;
    if (c.titles > bestTitles) bestTitles = c.titles;
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'done': [for (final a in done) a.name],
        'c': careers,
        't': titles,
        'bw': bestWins,
        'bt': bestTitles,
        'bl': bestLevel,
        'bp': bestFirst10,
        if (codex.isNotEmpty) 'cx': codex,
        if (legacy.isNotEmpty)
          'lg': [
            for (final e in legacy.entries)
              {
                's': e.key,
                't': [for (final x in e.value.tenures) x.toJson()],
                'l': [for (final x in e.value.legends) x.toJson()],
                'm': e.value.moments,
              },
          ],
      };

  static Profile fromJson(Map<String, dynamic> j) => Profile(
        done: {
          for (final n in (j['done'] as List? ?? const []))
            for (final a in Achievement.values)
              if (a.name == n) a,
        },
        careers: (j['c'] as int?) ?? 0,
        titles: (j['t'] as int?) ?? 0,
        bestWins: (j['bw'] as int?) ?? 0,
        bestTitles: (j['bt'] as int?) ?? 0,
        bestLevel: (j['bl'] as int?) ?? 0,
        bestFirst10: (j['bp'] as int?) ?? 0,
      )
        ..codex.addAll({for (final e in (j['cx'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'})
        ..legacy.addAll({
          for (final x in (j['lg'] as List? ?? const []))
            if (x is Map)
              x['s'] as int: (
                tenures: [for (final t in (x['t'] as List? ?? const [])) TenureCard.fromJson(Map<String, dynamic>.from(t as Map))],
                legends: [for (final t in (x['l'] as List? ?? const [])) LegendCard.fromJson(Map<String, dynamic>.from(t as Map))],
                moments: [for (final t in (x['m'] as List? ?? const [])) '$t'],
              ),
        });
}
