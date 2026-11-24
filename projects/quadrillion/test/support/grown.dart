import 'package:quadrillion/game/game.dart';

import 'bot.dart';

/// 育った会社（中盤〜終盤）の盤面を、仕組みを実際に進めて作る組み立て役。
/// 数字を書き込んで作るのではなく、毎月ふつうの手（始める・分社・現地法人・上場・組む・持株会社）を打って月を進める。
/// 手の数・お金・条件はどれも本物の手のまま（足りなければ、その月は打てない）。
///
/// できあがる盤面の目安（seed 2024・1985年から25年）: 事業20〜30・子会社・現地法人・持株会社・子会社の上場・提携・投資家の出資
Game grownGame({int seed = 2024, int year = 1985, int years = 25, int bizTarget = 26, String home = 'jp', List<String> traits = const ['charm', 'careful']}) {
  final g = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: traits, home: home), rng: ParkMiller(seed));
  for (var m = 0; m < years * 12 && g.over == null; m++) {
    growMonth(g, bizTarget: bizTarget);
  }
  resolveEvents(g);
  // 任せた事業は戻して渡す（受け取ったテストが自分で任せ方を決める）
  g.undelegAll();
  g.calcAll();
  return g;
}

/// 1か月ぶん：会社の形を育てる手を1つ打ってから、いつもの自動プレイ（1単位の手）で月を進める
void growMonth(Game g, {int bizTarget = 26}) {
  resolveEvents(g);
  if (g.won != null) {
    g.mode = 'endless';
    g.won = null;
  }
  // 1.1.0+25 から、事業が増えると会議に社長の時間を取られる。責任者のいる事業は任せて、会議の時間を減らす（人が遊ぶときと同じ）
  if (g.hNormalLeft() < 60) g.delegAll();
  _shape(g, bizTarget);
  botMonth(g, units: true);
}

void _shape(Game g, int bizTarget) {
  // 会社の形を変える手は時間が長い（16〜24時間）。無理をして使える時間まで見る（1.1.0+25）
  if (g.biz.isEmpty || g.hLeft() < 30) return;
  final n = g.biz.length + g.subs().length;
  // 持株会社（5つ以上で）
  if (!g.holding && n >= 5) {
    g.makeHolding();
    return;
  }
  // 部下を足す（責任者・子会社の社長になる人）
  if (g.staff.length < 6 && g.cands.isNotEmpty && g.pre > g.cands.first.salary * 4 && g.turn % 3 == 0) {
    g.hire(g.cands.first);
    return;
  }
  // 分社（責任者のいる事業を2つまで）
  final plain = g.subs().where((c) => c.loc == null).length;
  if (g.holding && plain < 2 && g.biz.length >= 8 && g.turn % 12 == 6) {
    final b = (g.biz.where((b) => b.mgr != null).toList()..ssort((a, b) => a.rev.compareTo(b.rev))).firstOrNull;
    if (b != null) {
      g.spinOff(b);
      return;
    }
  }
  // 現地法人（海外に出ている事業の、いちばん大きい国の分を2つまで）
  if (g.locals().length < 2 && g.turn % 12 == 9) {
    for (final b in g.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))) {
      // 市場の小さい国の分は分けない（1.0.0+19 から、部下の提案で早いうちに小さい国へ出ることがあり、
      // 最初に出た国をそのまま分けると、時価総額が数千万円の現地法人しかない盤面になった）。大きい国を先に
      final cs = g.localCountries(b).where((c) => !g.hasLocal(c, b.ind) && cw(c, g.year.toDouble()) >= .1).toList()
        ..ssort((p, q) => cw(q, g.year.toDouble()).compareTo(cw(p, g.year.toDouble())));
      if (cs.isEmpty) continue;
      g.makeLocal(b, cs.first);
      return;
    }
  }
  // 子会社の上場（1社）
  if (!g.subs().any((c) => c.listed) && g.turn % 12 == 3) {
    final c = g.subs().where((c) => g.pctOf(c) >= 60).firstOrNull;
    if (c != null) {
      g.subIPO(c);
      return;
    }
  }
  // 提携（同じ業種の、警戒されていない会社と2つまで）
  if (g.deals.length < 2 && g.turn % 12 == 1) {
    final mine = <String>{for (final b in g.biz) b.ind};
    final c = g.cos.where((c) => c.alive && c.parent != 'player' && c.rel >= -20 && g.dealWith(c).isEmpty && c.biz.any((b) => mine.contains(b.ind))).firstOrNull;
    if (c != null) {
      g.makeDeal(c, g.deals.isEmpty ? 'sales' : 'codev');
      return;
    }
  }
  // 事業を増やす（いつもの自動プレイは12で止まるので、その先を足す）
  if (g.biz.length >= 12 && g.biz.length < bizTarget) {
    final cand = g.liveInds().where((i) => !g.biz.any((b) => b.ind == i.id) && g.capexOf(i) < g.cash * .5).toList()
      ..ssort((a, b) => (b.mg * b.size).compareTo(a.mg * a.size));
    if (cand.isNotEmpty) g.startBiz(cand.first.id);
  }
}

/// 中盤（10〜30年目）の単調さの数え方。
/// 「毎月同じボタンを押すだけ」の月 ＝ 次の3つがそろった月:
///  ・選ぶ出来事が1つも来ない（経営会議・宿敵の場面・取締役会・臨時の会議・買収の話など）
///  ・良い／悪い／大きな知らせが1つも無い
///  ・「今月やること」の文が先月とまったく同じ（何も出ていない月どうしも同じと数える）
class MidStats {
  int months = 0, quiet = 0, sameAdvice = 0, mono = 0;

  /// 時代の波（社史の era）と、宿敵との決着（社史の rival）の数
  int eras = 0, rivalEnds = 0;

  /// 出来事の題（日本語の鍵）ごとの数
  final Map<String, int> events = {};

  /// 経営会議の提案の種類ごとの数（題の文の鍵で数える）
  final Map<String, int> proposals = {};

  /// 知らせの種類（good / bad / big など）ごとの数
  final Map<String, int> news = {};

  /// 「今月やること」に出た文（鍵）ごとの月数
  final Map<String, int> advice = {};

  /// 同じ文がいちばん長く続いた月数
  int longestSame = 0;

  /// 選ぶ出来事が2つ以上重なった月（うるさくないかを見る）・宿敵の物語の場面の数（出会い・張り合う・決着）
  int crowded = 0, scenes = 0;
  double get crowdedPct => months == 0 ? 0 : crowded * 100 / months;

  double get monoPct => months == 0 ? 0 : mono * 100 / months;
  double get quietPct => months == 0 ? 0 : quiet * 100 / months;
  double get sameAdvicePct => months == 0 ? 0 : sameAdvice * 100 / months;

  String report() {
    String top(Map<String, int> m, [int n = 12]) =>
        (m.entries.toList()..sort((a, b) => b.value - a.value)).take(n).map((e) => '    ${e.value}  ${e.key.length > 44 ? '${e.key.substring(0, 44)}…' : e.key}').join('\n');
    return '月数 $months・何も起きない月 $quiet（${quietPct.toStringAsFixed(1)}%）・助言が先月と同じ月 $sameAdvice（${sameAdvicePct.toStringAsFixed(1)}%）・'
        '単調な月 $mono（${monoPct.toStringAsFixed(1)}%）・同じ助言の最長 $longestSameか月・時代の波 $eras回・宿敵との決着 $rivalEnds回・'
        '選ぶ出来事が2つ以上の月 $crowded（${crowdedPct.toStringAsFixed(1)}%）・宿敵の場面 $scenes\n'
        '  出来事:\n${top(events, 30)}\n  提案:\n${top(proposals)}\n  知らせ:\n${top(news)}\n  助言:\n${top(advice, 30)}';
  }
}

/// 宿敵の物語の場面の題（頭の言葉）
const sceneTitles = ['宿敵との出会い', '因縁が深まる', '決着：', '宿敵：'];

/// 経営会議の提案の種類（文に入っている言葉 → 呼び名）
const proposalKinds = {
  '現場の人を': '現場の人',
  '大型開発': '大型開発',
  '小さな改良': '小さな改良',
  '新しい商品': '新しい商品',
  '値下げして': '値下げ',
  '維持費を削': '維持費',
  '新しく「': '新しい事業',
  '新しい事業': '新しい事業',
  '広告を打ちたい': '広告',
  'に出したい': '海外',
  '値下げをやめたい': '値付け',
  '値段を高くしたい': '値付け',
  'に切り替えたい': '稼ぎ方',
  '手を引きたい': '撤退',
  '社風を': '社風',
  '増やしたい': '店・工場',
};

/// 育てる自動プレイで [from]〜[to] 年目を回し、単調な月を数える
MidStats measureMid({int seed = 2024, int year = 1985, int from = 10, int to = 30, MidStats? into}) {
  final st = into ?? MidStats();
  final g = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
  var prev = '';
  var run = 0;
  for (var m = 0; m < to * 12 && g.over == null; m++) {
    resolveEvents(g);
    if (g.won != null) {
      g.mode = 'endless';
      g.won = null;
    }
    _shape(g, 26);
    // botMonth は月を進める前に出来事を片付けるので、進めたあとに残っている出来事が「今月来たもの」
    botMonth(g, units: true);
    if (m < from * 12) {
      prev = g.advice().map(msgKey).join('|');
      continue;
    }
    st.months++;
    if (g.events.length >= 2) st.crowded++;
    for (final e in g.events) {
      if (e.who?.rival != null && sceneTitles.any((t) => msgKey(e.title).startsWith(t))) st.scenes++;
      final k = msgKey(e.title);
      st.events[k] = (st.events[k] ?? 0) + 1;
      if (k.startsWith('経営会議')) {
        for (final part in e.voices.isEmpty ? [e.text] : e.voices.map((v) => v.say)) {
          final ja = txIn(part, 'ja');
          final kind = proposalKinds.entries.where((x) => ja.contains(x.key)).map((x) => x.value).firstOrNull ?? 'ほか';
          st.proposals[kind] = (st.proposals[kind] ?? 0) + 1;
        }
      }
    }
    for (final n in g.lastNews.where((n) => n.t.isNotEmpty)) {
      st.news[n.t] = (st.news[n.t] ?? 0) + 1;
    }
    final quiet = g.events.isEmpty && !g.lastNews.any((n) => n.t == 'big' || n.t == 'bad');
    final adv = g.advice();
    for (final a in adv) {
      st.advice[msgKey(a)] = (st.advice[msgKey(a)] ?? 0) + 1;
    }
    // 文の鍵で比べる（中の金額や割合が少し動いただけの文は、同じ文と数える）
    final now = adv.map(msgKey).join('|');
    final same = now == prev;
    run = same ? run + 1 : 0;
    if (run > st.longestSame) st.longestSame = run;
    prev = now;
    if (quiet) st.quiet++;
    if (same) st.sameAdvice++;
    if (quiet && same) st.mono++;
  }
  st.eras += g.history.where((e) => e.k == 'era' && e.y >= year + from).length;
  st.rivalEnds += g.history.where((e) => e.k == 'rival' && e.y >= year + from).length;
  return st;
}

/// 盤面の要約（点検の出力用）
String grownSummary(Game g) => '${g.year}年${g.q}月 事業${g.biz.length} 子会社${g.subs().where((c) => c.loc == null).length} 現地法人${g.locals().length} '
    '上場${g.listed} 持株${g.holding} 子会社上場${g.subs().where((c) => c.listed).length} 提携${g.deals.length} 投資家${g.sh.vc.toStringAsFixed(1)}% '
    '部下${g.staff.length} 社史${g.history.length} 終わり${g.over}';
