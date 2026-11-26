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

/// 社長の腕ごとの効き目（社長の画面に出す）
const LMap abDesc = LMap({
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

/// 番頭のひとこと1つ（文と、その場で打てる手・飛ぶ先）。1.0.0+20
class Tip {
  final int pri;

  /// 包んだ文
  final String m;

  /// 「今月やること」の行に付けるボタンの種類（null なら付けない）:
  /// start 最初の事業を決める / stock「株」へ / people「人」へ / staff その部下へ / bizTab「事業」へ / biz その事業のカードへ /
  /// newInd 新しい事業の一覧でその業種を探す / hire その事業の足りない人を雇う / hireAll 足りない人をまとめて雇う /
  /// place 空いている部下を責任者に置く / holding 持株会社にする / deleg 責任者のいる事業をまとめて任せる
  final String? act;

  /// 手の相手（事業 [Biz]・部下 [Person]・業種の id）
  final Object? ref;
  const Tip(this.pri, this.m, [this.act, this.ref]);
}

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
  ///
  /// 30年を超えて遊ぶと、同じ種類の記録（順位の節目・現地法人の上場・合併）だけで枠が埋まり、宿敵との決着や解任が出てこなかった（1.0.0+18）:
  /// ・同じ種類は2つまで（順位は、いちばん上まで行った節目から。ほかは古いものから）。枠が余れば、残りを大きい順に足す
  /// ・同じ10年（創業から数えて）からは半分まで。後半の節目も入る
  /// ・宿敵との決着・取締役会での解任・現地法人も節目に数える。現地法人の上場は、自社の上場より小さく数える
  List<Chron> highlights([int n = 5]) {
    int score(Chron e) => switch (e.k) {
          'rank' => msgKey(e.m).contains('1位になった') ? 10 : 7,
          'found' => 9,
          'ipo' => msgKey(e.m).startsWith('現地法人') ? 4 : 8,
          'sold' => 7,
          'swap' || 'merge' || 'first_biz' || 'rival' => 6,
          'buy' || 'abroad' || 'board' => 5,
          'pres' || 'partner' || 'rebirth' => 4,
          'local' => 3,
          'partner_out' => 2,
          _ => 0,
        };
    final idx = [for (var i = 0; i < history.length; i++) if (score(history[i]) > 0) i];
    idx.sort((a, b) {
      final c = score(history[b]) - score(history[a]);
      if (c != 0) return c;
      // 順位の節目は新しいもの（＝上の順位）から。ほかは古いものから
      return history[a].k == 'rank' && history[b].k == 'rank' ? b - a : a - b;
    });
    // 同じ10年からは半分まで（少なくとも2つ）。古いものから選ぶと、創業してすぐの出来事だけで枠が埋まり、後半の節目が出なかった
    final perDecade = math.max(2, n ~/ 2);
    final per = <String, int>{}, dec = <int, int>{};
    final pick = <int>[], rest = <int>[];
    for (final i in idx) {
      final k = history[i].k;
      final d = (history[i].y - startYear) ~/ 10;
      if ((per[k] ?? 0) < 2 && (dec[d] ?? 0) < perDecade) {
        per[k] = (per[k] ?? 0) + 1;
        dec[d] = (dec[d] ?? 0) + 1;
        pick.add(i);
      } else {
        rest.add(i);
      }
    }
    final out = [...pick.take(n), if (pick.length < n) ...rest.take(n - pick.length)]..sort();
    return [for (final i in out) history[i]];
  }

  /// 勝ち負けが決まったか
  bool get ended => won != null || over != null;

  String meetLine(Person p) => M(meetLines.ja[p.place] ?? (yr() < 2008 ? '掲示板で見たよ。俺と組めば勝てる' : 'DMありがとう。で、取り分は？'));

  String goalText() {
    if (mode == 'world') {
      final rk = rankList();
      final me = rk.indexWhere((x) => x.me) + 1;
      if (me == 1) return M('世界1位です。2位との差は{0}', [Y(rk[0].cap - (rk.length > 1 ? rk[1].cap : 0))]);
      // 1.1.0+30 から、世界1位は遠い目標なので、次の順位の節目（500・200・100・50・10・3・1位）までの差と、主な業種での順位を出す
      final next = rankMarks.reversed.firstWhere((m) => m < me, orElse: () => 1);
      final gap = math.max(0.0, rk[next - 1].cap - (cap + wealth));
      final head = (biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).firstOrNull;
      if (head != null) {
        final rivals = cos.where((c) => c.alive && c.parent != 'player' && c.biz.any((x) => x.ind == head.ind)).map((c) => c.biz.firstWhere((x) => x.ind == head.ind).rev);
        final indRank = rivals.where((r) => r > head.rev).length + 1;
        return M('次の目標：世界{0}位以内（あと{1}）。今は{2}位・「{3}」では{4}位', [next, Y(gap), me, I(head.ind), indRank]);
      }
      return M('次の目標：世界{0}位以内（あと{1}）。今は{2}位', [next, Y(gap), me]);
    }
    if (mode == 'quad') return M('1000兆円まで：あと{0}', [Y(math.max(0, 1e15 - cap - wealth))]);
    return M('終わりなし：好きなだけ育てる');
  }

  /// 中盤からの勧め（1.0.0+18）。育った会社で使える仕組み（現地法人・子会社の上場・相性の分かった組み合わせ）と、
  /// 放っておくと痛い目にあうこと（忠誠・現地法人の株の買い集め）を、今ある仕組みのまま言葉にする。数字は何も動かさない
  void _midAdvice(void Function(int, String, [List<Object?>, String?, Object?]) add) {
    // 現地法人の株を宿敵が買い集めている（10%で場面が出る。その手前から知らせる）
    final hit = (locals().where((c) => c.locRivPct >= 5 && coById(c.locRiv) != null).toList()..ssort((a, b) => b.locRivPct.compareTo(a.locRivPct))).firstOrNull;
    if (hit != null) {
      // 25%（口を出される線）が近づいたら急ぎ。その手前と、越えたあとは、ほかの勧めと同じ並びに置く
      add(hit.locRivPct >= 15 && hit.locRivPct < 25 ? 88 : 55, hit.locRivPct >= 25 ? '現地法人{0}の株を、{1}が{2}握っています。「株」で買い戻せます（{3}）' : '現地法人{0}の株を、{1}が{2}まで買い集めています。25%で経営に口を出されます。「株」で買い戻せます（{3}）',
          [Nm(hit.name), Nm(coById(hit.locRiv)!.name), pct(hit.locRivPct), Y(localBuybackCost(hit))], 'stock');
    }
    // 忠誠が引き抜きの線（野心60超・忠誠55未満）を割った部下
    final low = (staff.where((p) => p.loy < 55 && (!p.ambKnown || p.amb > 60)).toList()..ssort((a, b) => a.loy.compareTo(b.loy))).firstOrNull;
    if (low != null) add(78, '{0}の忠誠が下がっています。宿敵の引き抜きの的になります。経営会議で{0}の提案を通すと、忠誠が上がります', [Nm(low.name)], 'staff', low);
    // 相性がよさそうと分かっている組み合わせの、片方だけを持っている（事業の種探しで分かったもの）
    final own = <String>{for (final b in biz) b.ind, for (final c in subs()) for (final b in c.biz) b.ind};
    final live = <String>{for (final i in liveInds()) i.id};
    final half = syns.where((s) => found[s.k] == null && hint[s.k] != null && (own.contains(s.a) != own.contains(s.b)) && live.contains(s.a) && live.contains(s.b)).toList();
    if (half.isNotEmpty) {
      final s = half[(turn ~/ 3) % half.length];
      final (have, need) = own.contains(s.a) ? (s.a, s.b) : (s.b, s.a);
      add(58, '「{0}」と「{1}」は相性がよさそうだと分かっています。「{1}」も始めれば、シナジーが見つかるかもしれません', [I(have), I(need)], 'newInd', need);
    }
    // 子会社の上場（まだ1社も上場させていないとき）
    final sb = subs();
    if (!sb.any((c) => c.listed)) {
      final c = (sb.where((c) => pctOf(c) >= 60).toList()..ssort((a, b) => b.cap.compareTo(a.cap))).firstOrNull;
      if (c != null && c.cap * .3 * .95 >= 1e8 * nom()) {
        add(48, '子会社の{0}は上場させられます。株を30%売って約{1}が入り、70%は持ったままです（「株」の子会社のカードから）', [Nm(c.name), Y(c.cap * .3 * .95)], 'stock');
      }
    }
    // 現地法人（まだ1つも作っていないとき。海外の分がいちばん大きい事業）
    if (locals().isEmpty && biz.length + sb.length >= 5) {
      final b = (biz.where((b) => localCountries(b).isNotEmpty && b.profit > 0).toList()..ssort((a, b) => b.rev.compareTo(a.rev))).firstOrNull;
      if (b != null) {
        add(46, '「{0}」は{1}に出ています。「分社・独立」からその国の分を現地法人に分けると、地元の規制が少し緩み、現地の社長が自分で動かします', [I(b.ind), C(localCountries(b).first)], 'biz', b);
      }
    }
  }

  /// 番頭のひとこと（大事な順に最大3行）。まだ使っていない仕組みは、使いどきに勧める。汚い手は勧めない
  ///
  /// 候補が4つ以上あるときは、いちばん大事な1つを先頭に置いたまま、2つ目と3つ目を月ごとに順ぐりに回す（1.0.0+18）。
  /// 画面の「今月やること」に出るのは3つまでなので、上の3つが片付かないかぎり下の候補はいつまでも出ず、毎月同じ3つの文が並んでいた
  /// （10〜30年目の自動プレイで、先月と同じ文の月が 99.6%）。全部を大事な順に読むのは [adviceAll]（小窓「番頭のひとこと」）
  List<String> advice() => [for (final t in adviceTop()) t.m];

  /// [advice] と同じ選び方で、その場で打てる手・飛ぶ先も付けて返す（「今月やること」の行のボタンに使う）
  List<Tip> adviceTop() {
    final all = adviceTips();
    if (!extras || all.length <= 3) return all.take(3).toList();
    final n = all.length - 1;
    final a = all[1 + turn % n], b = all[1 + (turn + 1) % n];
    // その場で打てる用事（足りない人を雇う・空いている部下を責任者に置く）が候補にあれば、片付くまで2つ目に出し続ける（1.0.0+20。
    // 「今月やること」から1回で打てるように。3つ目は今までどおり月ごとに回るので、ほかの候補も順に全部出る）
    final plan = all.any((t) => t.act == 'place') && managerPlan().isNotEmpty;
    final doable = all.skip(1).where((t) => t.act == 'hire' || t.act == 'hireAll' || (t.act == 'place' && plan)).firstOrNull;
    if (doable == null || doable == a || doable == b) return [all[0], a, b];
    return [all[0], doable, b];
  }

  /// 番頭のひとことの候補を、大事な順にすべて並べる
  List<String> adviceAll() => [for (final t in adviceTips()) t.m];

  /// 番頭のひとことの候補を、大事な順にすべて（その場で打てる手・飛ぶ先つき）
  List<Tip> adviceTips() {
    final a = <Tip>[];
    void add(int pri, String m, [List<Object?> args = const [], String? act, Object? ref]) => a.add(Tip(pri, M(m, args), act, ref));
    final riv = sh.rivMax;
    final y = yr();
    if (biz.isEmpty) add(100, 'まだ事業がありません。相棒を探すか、「最初の事業を決める」から始めましょう', const [], 'start');
    if (riv >= 20) add(95, '宿敵にあなたの株を{0}握られています。「株」でホワイトナイトや自社株買いを考えましょう', [pct(riv)], 'stock');
    final run = biz.where((b) => b.mgr == null).length;
    if (run > presCap()) {
      add(90, '社長が直接見られる事業は{0}つまでです。{1}つの事業が放置されて弱っています。「人」で採用して責任者に置きましょう', [presCap(), run - presCap()], 'place');
    }
    // 同じ文が何か月も出続けないようにする（1.0.0+18。育った会社では「沈み始めています」「人が足りず」が毎月同じ事業の名前で出ていた）:
    // ・名前を挙げる事業は、いちばん困っているもの（人手）か、月ごとに順番に（沈む市場・新しい市場）
    // ・急がない勧めは、起きてすぐ（1〜2年）は毎月、そのあとは数か月に1度だけ出す
    final shorts = biz.where((b) => b.model != 'fc' && b.power > 0 && crewEff(b) < crewWant(b) * .9).toList()
      ..ssort((p, q) => (crewEff(p) / p.power).compareTo(crewEff(q) / q.power));
    if (shorts.length >= 2 && extras) {
      add(
          85,
          biz.length >= bizManyMin
              ? '「{0}」など{1}つの事業で現場の人が足りず、{2}の一部が止まっています。「事業」の「まとめての手」から、まとめて雇えます'
              : '「{0}」など{1}つの事業で現場の人が足りず、{2}の一部が止まっています。「事業」の「現場の人を増やす」で雇いましょう',
          [I(shorts[0].ind), shorts.length, uw(shorts[0])],
          'hireAll');
    } else if (shorts.isNotEmpty) {
      add(85, '「{0}」は現場の人が足りず、{1}の一部が止まっています。「現場の人を増やす」か、統率の強い責任者を置きましょう', [I(shorts[0].ind), uw(shorts[0])], extras ? 'hire' : null, shorts[0]);
    }
    if (pres.age >= 60 && succ == null) add(80, '社長が60歳を超えました。「人」で後継ぎを決めておかないと、急死したとき会社が混乱します', const [], 'people');
    if (canIPO()) add(75, '上場の条件を満たしました。大金が入りますが、宿敵があなたの株を買えるようになります', const [], 'stock');
    final decs = biz.where((b) {
      final i = indm[b.ind]!;
      return i.f != 0 && y > i.f;
    }).toList();
    if (!extras) {
      if (decs.isNotEmpty) add(70, '「{0}」は市場が沈み始めています。売るなら早めに', [I(decs[0].ind)]);
    } else {
      // 沈み始めて1年以内のものは毎月。それより古いものは半年に1度、順番に名前を挙げる
      final fresh = decs.where((b) => y - indm[b.ind]!.f < 1).firstOrNull;
      if (fresh != null) {
        add(70, '「{0}」は市場が沈み始めています。売るなら早めに', [I(fresh.ind)], 'biz', fresh);
      } else if (decs.isNotEmpty && turn % 6 == 0) {
        final b = decs[(turn ~/ 6) % decs.length];
        add(70, pivotTargets(b).any((i) => newIndBlock(i.id) == null) ?'「{0}」は沈む市場に残ったままです。売るか、「業態を変える」で近い業種に移れます' : '「{0}」は沈む市場に残ったままです。売れるうちに売るのも手です', [I(b.ind)], 'biz', b);
      }
    }
    // 子会社のいる業種は自社では始めないので勧めない（1.1.0+36）
    final hots = inds.where((i) => y - i.b >= 0 && y - i.b < 6 && i.size >= 1.5e12 && !biz.any((b) => b.ind == i.id) && subOn(i.id) == null).toList()
      ..ssort((p, q) => q.size.compareTo(p.size));
    if (!extras) {
      if (hots.isNotEmpty) add(65, '生まれたばかりの「{0}」は、これから世界で大きく育つ市場です。早く入って世界に出た会社が、時代の覇者になります', [I(hots[0].id)]);
    } else if (hots.isNotEmpty) {
      // 生まれて2年以内は毎月。そのあとは4か月に1度、順番に
      final fresh = hots.where((i) => y - i.b < 2).firstOrNull;
      if (fresh != null) {
        add(65, '生まれたばかりの「{0}」は、これから世界で大きく育つ市場です。早く入って世界に出た会社が、時代の覇者になります', [I(fresh.id)], 'newInd', fresh.id);
      } else if (turn % 4 == 1) {
        final h = hots[(turn ~/ 4) % hots.length];
        add(65, '「{0}」は生まれて{1}年、まだ伸びている市場です。入るなら、大きな会社が固まる前に', [I(h.id), (y - h.b).floor()], 'newInd', h.id);
      }
    }
    if (extras) _midAdvice(add);
    // 責任者のいる事業が3つ以上あって、まだ1つも任せていない（1.0.0+20。半年に1度だけ言う）
    if (extras && turn % 6 == 2 && !biz.any((b) => b.deleg) && delegable().length >= 3) {
      add(57, '責任者のいる事業が{0}つあります。「任せる」にすると、毎月、責任者が自分で人を雇い、店や商品を増やします（社長の手は使いません）', [delegable().length], 'deleg');
    }
    // あと1か国で規模の利益（5か国から利益率が上がる）
    bool entering(Biz b) => b.pipe.any((x) => x.k == 'enter');
    final four = biz.where((b) => ctryOf(b).length == 4 && !entering(b)).firstOrNull;
    if (four != null) add(62, '「{0}」は4か国に出ています。あと1か国で規模の利益が効き、利益率が上がります', [I(four.ind)], 'biz', four);
    final idle = staff.where((p) => !biz.any((b) => b.mgr == p.id)).toList();
    if (idle.isNotEmpty && run > 0) add(60, '{0}が担当なしです。「事業」で責任者に置けます', [Nm(idle[0].name)], 'place');
    // 株式交換（上場していて、自分より小さい同業の会社がある）
    if (listed && riv < 33.4) {
      final mine = <String>{for (final b in biz) b.ind};
      final tg = (cos
              .where((c) => c.alive && c.parent != 'player' && c.cap < cap && c.cap > cap * .02 && c.biz.any((b) => mine.contains(b.ind)))
              .toList()
            ..ssort((p, q) => q.cap.compareTo(p.cap)))
          .firstOrNull;
      if (tg != null) add(56, '上場した今なら、自分より小さい同業の{0}を「株式交換」で丸ごと買えます。現金を使わずに大きくなれます（「株」の買える会社から）', [Nm(tg.name)], 'stock');
    }
    if (!holding && biz.length + subs().length >= 5) {
      add(54, '事業と子会社が5つを超えました。「株」の会社の形から持株会社にすると、社長が直接見られる事業の上限がなくなります', const [], 'holding');
    }
    // 海外（伸びている事業がまだ1か国だけ）
    final grow = (biz.where((b) => ctryOf(b).length == 1 && !entering(b) && b.prevRev > 0 && b.rev > b.prevRev && b.profit > 0).toList()
          ..ssort((p, q) => q.rev.compareTo(p.rev)))
        .firstOrNull;
    if (grow != null) {
      final cs = CTRY.where((x) => x.c != home && entryModes(grow, x.c).isNotEmpty).toList()
        ..ssort((p, q) => cw(q.c, y).compareTo(cw(p.c, y)));
      final c = cs.where((x) => cash >= entryCost(grow, x.c, entryModes(grow, x.c).contains('jv') ? 'jv' : entryModes(grow, x.c).first)).firstOrNull;
      if (c != null) add(52, '「{0}」が伸びています。まだ{1}だけなので、「海外に出る」で{2}などに広げれば市場が何倍にもなります', [I(grow.ind), C(home), C(c.c)], 'biz', grow);
    }
    if (biz.isNotEmpty && cash > biz.map((b) => b.rev).reduce(math.max) * .5 && canT('invest')) {
      add(50, '現金が余っています。伸びている事業に投資するか、新しい事業を始めましょう', const [], 'bizTab');
    }
    a.ssort((p, q) => q.pri - p.pri);
    return a;
  }
}
