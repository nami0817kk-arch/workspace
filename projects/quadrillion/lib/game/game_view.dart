// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

const LMap meetLines = LMap({
  'lab': 'この技術、まだ誰も商売にしていないんですよ',
  'club': 'お前がやるなら、乗ってもいいぜ',
  'baito': '現場のことなら任せてくれ',
  'meet': '面白い話なら金を出してもいい。ただし見返りはもらう',
});

const LMap traitHints = LMap({
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
});

const LMap trainDesc = LMap({
  'tou': '人を率いる。統率が効く事業が強くなる',
  'kai': 'ものを作る。開発が効く事業が強くなる',
  'ei': '売る。営業が効く事業が強くなる',
  'zai': 'お金を扱う。TOB が成功しやすくなる',
});

String chanceWord(double c) => M(c >= .75
    ? '乗り気だ'
    : c >= .5
        ? '五分五分より上'
        : c >= .3
            ? '迷っている'
            : '見込みは薄い');

String relWord(int rel) => M(rel > 25
    ? '友好'
    : rel > 10
        ? 'やや良い'
        : rel < -30
            ? '敵意'
            : rel < -10
                ? '警戒'
                : 'ふつう@@rel');

/// 画面に出す言葉を組み立てる（試作の画面側にあった、状態から文を作る関数）
extension GameView on Game {
  String officeName() {
    final r = rev * 12 / nom();
    return M(r < 5e7
        ? 'ワンルームの事務所'
        : r < 1e9
            ? '雑居ビルの1フロア'
            : r < 3e10
                ? '自社ビル'
                : r < 1e12
                    ? '本社タワー'
                    : '摩天楼の本社');
  }

  String stageName() => M(biz.length + subs().length >= 10
      ? 'グループ期'
      : biz.length >= 3
          ? '成長期'
          : '創業期');

  /// 終わったときのまとめに出す社史の節目（大きいものから[n]個選び、古い順に並べる。勝ち負けそのものと時代の出来事は除く）
  List<Chron> highlights([int n = 5]) {
    int score(Chron e) => switch (e.k) {
          'rank' => msgKey(e.m).contains('1位になった') ? 10 : 7,
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

  String meetLine(Person p) => M(meetLines.ja[p.place] ?? (yr() < 2008 ? '掲示板で見たよ。俺と組めば勝てる' : 'DMありがとう。で、取り分は？'));

  String goalText() {
    if (mode == 'world') {
      final rk = rankList();
      final top = rk[0];
      var main = '';
      if (top.c != null && top.c!.biz.isNotEmpty) {
        final b = (top.c!.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev)))[0];
        main = M('・主力は「{0}」', [I(b.ind)]);
      }
      return M('世界1位まで：1位は{0}（{1}{2}）。あなたは{3}位', [top.me ? top.name : Nm(top.name), Y(top.cap), main, rk.indexWhere((x) => x.me) + 1]);
    }
    if (mode == 'quad') return M('1000兆円まで：あと{0}', [Y(math.max(0, 1e15 - cap - wealth))]);
    return M('終わりなし：好きなだけ育てる');
  }

  /// 番頭のひとこと（大事な順に最大3行）。まだ使っていない仕組みは、使いどきに勧める。汚い手は勧めない
  List<String> advice() => adviceAll().take(3).toList();

  /// 番頭のひとことの候補を、大事な順にすべて並べる
  List<String> adviceAll() {
    final a = <(int, String)>[];
    void add(int pri, String m, [List<Object?> args = const []]) => a.add((pri, M(m, args)));
    final riv = sh.rivMax;
    final y = yr();
    if (biz.isEmpty) add(100, 'まだ事業がありません。相棒を探すか、「最初の事業を決める」から始めましょう');
    if (riv >= 20) add(95, '宿敵にあなたの株を{0}握られています。「株」でホワイトナイトや自社株買いを考えましょう', [pct(riv)]);
    final run = biz.where((b) => b.mgr == null).length;
    if (run > presCap()) add(90, '社長が直接見られる事業は{0}つまでです。{1}つの事業が放置されて弱っています。「人」で採用して責任者に置きましょう', [presCap(), run - presCap()]);
    final short = biz.where((b) => b.model != 'fc' && b.power > 0 && crewEff(b) < b.power * .9).firstOrNull;
    if (short != null) add(85, '「{0}」は現場の人が足りず、{1}の一部が止まっています。「現場の人を増やす」か、統率の強い責任者を置きましょう', [I(short.ind), uw(short)]);
    if (pres.age >= 60 && succ == null) add(80, '社長が60歳を超えました。「人」で後継ぎを決めておかないと、急死したとき会社が混乱します');
    if (canIPO()) add(75, '上場の条件を満たしました。大金が入りますが、宿敵があなたの株を買えるようになります');
    final dec = biz.where((b) {
      final i = indm[b.ind]!;
      return i.f != 0 && y > i.f;
    }).firstOrNull;
    if (dec != null) add(70, '「{0}」は市場が沈み始めています。売るなら早めに', [I(dec.ind)]);
    final hots = IND.where((i) => y - i.b >= 0 && y - i.b < 6 && i.size >= 1.5e12 && !biz.any((b) => b.ind == i.id)).toList()
      ..ssort((p, q) => q.size.compareTo(p.size));
    if (hots.isNotEmpty) add(65, '生まれたばかりの「{0}」は、これから世界で大きく育つ市場です。早く入って世界に出た会社が、時代の覇者になります', [I(hots[0].id)]);
    // あと1か国で規模の利益（5か国から利益率が上がる）
    bool entering(Biz b) => b.pipe.any((x) => x.k == 'enter');
    final four = biz.where((b) => ctryOf(b).length == 4 && !entering(b)).firstOrNull;
    if (four != null) add(62, '「{0}」は4か国に出ています。あと1か国で規模の利益が効き、利益率が上がります', [I(four.ind)]);
    final idle = staff.where((p) => !biz.any((b) => b.mgr == p.id)).toList();
    if (idle.isNotEmpty && run > 0) add(60, '{0}が担当なしです。「事業」で責任者に置けます', [Nm(idle[0].name)]);
    // 株式交換（上場していて、自分より小さい同業の会社がある）
    if (listed && riv < 33.4) {
      final mine = <String>{for (final b in biz) b.ind};
      final tg = (cos
              .where((c) => c.alive && c.parent != 'player' && c.cap < cap && c.cap > cap * .02 && c.biz.any((b) => mine.contains(b.ind)))
              .toList()
            ..ssort((p, q) => q.cap.compareTo(p.cap)))
          .firstOrNull;
      if (tg != null) add(56, '上場した今なら、自分より小さい同業の{0}を「株式交換」で丸ごと買えます。現金を使わずに大きくなれます（「株」の買える会社から）', [Nm(tg.name)]);
    }
    if (!holding && biz.length + subs().length >= 5) add(54, '事業と子会社が5つを超えました。「株」の会社の形から持株会社にすると、社長が直接見られる事業の上限がなくなります');
    // 海外（伸びている事業がまだ1か国だけ）
    final grow = (biz.where((b) => ctryOf(b).length == 1 && !entering(b) && b.prevRev > 0 && b.rev > b.prevRev && b.profit > 0).toList()
          ..ssort((p, q) => q.rev.compareTo(p.rev)))
        .firstOrNull;
    if (grow != null) {
      final cs = CTRY.where((x) => x.c != home && entryModes(grow, x.c).isNotEmpty).toList()
        ..ssort((p, q) => cw(q.c, y).compareTo(cw(p.c, y)));
      final c = cs.where((x) => cash >= entryCost(grow, x.c, entryModes(grow, x.c).contains('jv') ? 'jv' : entryModes(grow, x.c).first)).firstOrNull;
      if (c != null) add(52, '「{0}」が伸びています。まだ{1}だけなので、「海外に出る」で{2}などに広げれば市場が何倍にもなります', [I(grow.ind), C(home), C(c.c)]);
    }
    if (biz.isNotEmpty && cash > biz.map((b) => b.rev).reduce(math.max) * .5 && ap > 0) add(50, '現金が余っています。伸びている事業に投資するか、新しい事業を始めましょう');
    a.ssort((p, q) => q.$1 - p.$1);
    return [for (final x in a) x.$2];
  }
}
