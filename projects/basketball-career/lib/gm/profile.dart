import 'career.dart';

/// 実績。任期をまたいで端末に残る。
enum Achievement {
  firstTitle('はじめての優勝', 'ファイナルで勝って優勝する'),
  rebuildTitle('どん底からの頂点', '「立て直し」で始めて優勝する'),
  backToBack('連覇', '2年続けて優勝する'),
  dynasty('黄金期', '1回の任期で3回優勝する'),
  bigSeason('圧倒', 'レギュラーシーズンで60勝する'),
  homegrown('生え抜きのエース', '自分で指名した選手の力が80に届く'),
  dealer('やり手', '1回の任期でトレードを8回成立させる'),
  fullTerm('10年の任期', '解任されずに10年を務める'),
  lottery('くじを引き当てる', 'ドラフトで全体1位の指名権を手にする'),
  capMaster('身の丈経営', 'ぜいたく税を払わずに優勝する');

  const Achievement(this.title, this.text);
  final String title;
  final String text;
}

/// 端末に残る記録。
class Profile {
  Profile({Set<Achievement>? done, this.careers = 0, this.titles = 0, this.bestWins = 0, this.bestTitles = 0})
      : done = done ?? {};

  final Set<Achievement> done;
  int careers;
  int titles;
  int bestWins;

  /// 1回の任期での最多の優勝。
  int bestTitles;

  bool has(Achievement a) => done.contains(a);

  List<Achievement> _grant(Iterable<Achievement> list) {
    final got = <Achievement>[];
    for (final a in list) {
      if (done.add(a)) got.add(a);
    }
    return got;
  }

  /// シーズンを終えたとき(プレーオフのあと)に呼ぶ。新しく達成した実績を返す。
  List<Achievement> recordSeason(Career c) {
    final h = c.history.last;
    if (h.wins > bestWins) bestWins = h.wins;
    if (h.champion) titles++;
    final got = <Achievement>[
      if (h.champion) Achievement.firstTitle,
      if (h.champion && c.scenario == Scenario.rebuild) Achievement.rebuildTitle,
      if (h.champion && c.history.length >= 2 && c.history[c.history.length - 2].champion) Achievement.backToBack,
      if (c.titles >= 3) Achievement.dynasty,
      if (h.wins >= 60) Achievement.bigSeason,
      if (h.champion && c.lastTax == 0) Achievement.capMaster,
      if (c.me.roster.any((p) => c.draftedIds.contains(p.id) && p.ovr >= 80)) Achievement.homegrown,
    ];
    return _grant(got);
  }

  /// 動きのたびに呼ぶ(トレード・ドラフトの順番)。
  List<Achievement> recordProgress(Career c) => _grant([
        if (c.tradesDone >= 8) Achievement.dealer,
        if (c.phase == Phase.draft && c.order.isNotEmpty && c.picks[c.order.first].owner == Career.mine) Achievement.lottery,
        if (c.me.roster.any((p) => c.draftedIds.contains(p.id) && p.ovr >= 80)) Achievement.homegrown,
      ]);

  /// 任期を閉じるときに呼ぶ。
  List<Achievement> recordCareerEnd(Career c) {
    careers++;
    if (c.titles > bestTitles) bestTitles = c.titles;
    return _grant([if (!c.fired && c.history.length >= careerSeasons) Achievement.fullTerm]);
  }

  Map<String, dynamic> toJson() => {
        'done': [for (final a in done) a.name],
        'c': careers,
        't': titles,
        'bw': bestWins,
        'bt': bestTitles,
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
      );
}
