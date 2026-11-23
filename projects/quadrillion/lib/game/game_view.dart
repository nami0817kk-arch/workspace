// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

const Map<String, String> meetLines = {
  'lab': 'この技術、まだ誰も商売にしていないんですよ',
  'club': 'お前がやるなら、乗ってもいいぜ',
  'baito': '現場のことなら任せてくれ',
  'meet': '面白い話なら金を出してもいい。ただし見返りはもらう',
};

const Map<String, String> traitHints = {
  'genius': 'ひらめきは鋭いが、むらがあるらしい',
  'charm': '誰とでもすぐ打ち解ける',
  'oneman': '自分で全部やりたがる',
  'careful': '石橋を叩いて渡る人',
  'gambler': '勝負どころで大きく張る',
  'frugal': '経費にうるさい',
  'tech': '技術の話になると止まらない',
  'liar': '前の会社では揉め事が多かったらしい',
  'stamina': '徹夜が平気',
  'grit': '現場からの叩き上げ',
};

const Map<String, String> trainDesc = {
  'tou': '人を率いる。統率が効く事業が強くなる',
  'kai': 'ものを作る。開発が効く事業が強くなる',
  'ei': '売る。営業が効く事業が強くなる',
  'zai': 'お金を扱う。TOB が成功しやすくなる',
};

String chanceWord(double c) => c >= .75
    ? '乗り気だ'
    : c >= .5
        ? '五分五分より上'
        : c >= .3
            ? '迷っている'
            : '見込みは薄い';

String relWord(int rel) => rel > 25
    ? '友好'
    : rel > 10
        ? 'やや良い'
        : rel < -30
            ? '敵意'
            : rel < -10
                ? '警戒'
                : 'ふつう';

/// 画面に出す言葉を組み立てる（試作の画面側にあった、状態から文を作る関数）
extension GameView on Game {
  String officeName() {
    final r = rev * 12 / nom();
    return r < 5e7
        ? 'ワンルームの事務所'
        : r < 1e9
            ? '雑居ビルの1フロア'
            : r < 3e10
                ? '自社ビル'
                : r < 1e12
                    ? '本社タワー'
                    : '摩天楼の本社';
  }

  String stageName() => biz.length + subs().length >= 10
      ? 'グループ期'
      : biz.length >= 3
          ? '成長期'
          : '創業期';

  /// 終わったときのまとめに出す社史の節目（大きいものから[n]個選び、古い順に並べる。勝ち負けそのものと時代の出来事は除く）
  List<Chron> highlights([int n = 5]) {
    int score(Chron e) => switch (e.k) {
          'rank' => e.m.contains('1位になった') ? 10 : 7,
          'found' => 9,
          'ipo' => 8,
          'sold' => 7,
          'swap' || 'merge' || 'first_biz' => 6,
          'buy' || 'abroad' => 5,
          'pres' || 'partner' || 'rebirth' => 4,
          'partner_out' => 2,
          _ => 0,
        };
    final idx = [for (var i = 0; i < history.length; i++) if (score(history[i]) > 0) i];
    idx.sort((a, b) {
      final c = score(history[b]) - score(history[a]);
      return c != 0 ? c : a - b;
    });
    final pick = idx.take(n).toList()..sort();
    return [for (final i in pick) history[i]];
  }

  /// 勝ち負けが決まったか
  bool get ended => won != null || over != null;

  String meetLine(Person p) => meetLines[p.place] ?? (yr() < 2008 ? '掲示板で見たよ。俺と組めば勝てる' : 'DMありがとう。で、取り分は？');

  String goalText() {
    if (mode == 'world') {
      final rk = rankList();
      final top = rk[0];
      var main = '';
      if (top.c != null && top.c!.biz.isNotEmpty) {
        final b = (top.c!.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev)))[0];
        main = '・主力は「${indm[b.ind]!.name}」';
      }
      return '世界1位まで：1位は${top.name}（${yen(top.cap)}$main）。あなたは${rk.indexWhere((x) => x.me) + 1}位';
    }
    if (mode == 'quad') return '1000兆円まで：あと${yen(math.max(0, 1e15 - cap - wealth))}';
    return '終わりなし：好きなだけ育てる';
  }

  List<String> advice() {
    final a = <String>[];
    final riv = sh.rivMax;
    final y = yr();
    if (biz.isEmpty) a.add('まだ事業がありません。相棒を探すか、「最初の事業を決める」から始めましょう');
    final hots = IND.where((i) => y - i.b >= 0 && y - i.b < 6 && i.size >= 1.5e12 && !biz.any((b) => b.ind == i.id)).toList()
      ..ssort((p, q) => q.size.compareTo(p.size));
    if (hots.isNotEmpty) a.add('生まれたばかりの「${hots[0].name}」は、これから世界で大きく育つ市場です。早く入って世界に出た会社が、時代の覇者になります');
    final short = biz.where((b) => b.model != 'fc' && b.power > 0 && crewEff(b) < b.power * .9).firstOrNull;
    if (short != null) a.add('「${indm[short.ind]!.name}」は現場の人が足りず、${uw(short)}の一部が止まっています。「現場の人を増やす」か、統率の強い責任者を置きましょう');
    if (riv >= 20) a.add('宿敵にあなたの株を${pct(riv)}握られています。「株」でホワイトナイトや自社株買いを考えましょう');
    if (canIPO()) a.add('上場の条件を満たしました。大金が入りますが、宿敵があなたの株を買えるようになります');
    if (biz.isNotEmpty && cash > biz.map((b) => b.rev).reduce(math.max) * .5 && ap > 0) a.add('現金が余っています。伸びている事業に投資するか、新しい事業を始めましょう');
    final run = biz.where((b) => b.mgr == null).length;
    if (run > presCap()) a.add('社長が直接見られる事業は${presCap()}つまでです。${run - presCap()}つの事業が放置されて弱っています。「人」で採用して責任者に置きましょう');
    final idle = staff.where((p) => !biz.any((b) => b.mgr == p.id)).toList();
    if (idle.isNotEmpty && run > 0) a.add('${idle[0].name}が担当なしです。「事業」で責任者に置けます');
    final dec = biz.where((b) {
      final i = indm[b.ind]!;
      return i.f != 0 && y > i.f;
    }).firstOrNull;
    if (dec != null) a.add('「${indm[dec.ind]!.name}」は市場が沈み始めています。売るなら早めに');
    if (pres.age >= 60 && succ == null) a.add('社長が60歳を超えました。「人」で後継ぎを決めておかないと、急死したとき会社が混乱します');
    return a.take(3).toList();
  }
}
