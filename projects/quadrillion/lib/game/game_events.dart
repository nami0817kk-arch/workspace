// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 選ぶ出来事をセーブに入れる（1.1.0+38）。
///
/// 出来事の選択肢は中身（関数）を持つので、そのままは保存できない。そこで出来事ごとに「種類（k）と材料（a：相手の会社・人・事業の番号や額）」を付けておき、
/// 読み込むときに同じ作り方（ev〇〇）で作り直す。作り方は乱数を引かない（くじは出来事を作る前に引いて、結果を材料に入れる）。
/// 前は保存せず、開き直すと特許の訴え・株主総会の要求・宿敵の出資などを罰なしで飛ばせた。「今月やること」に残した小さな知らせも消えた。
///
/// 決めたときにだけ消す（画面は、選んだときにリストから外す。sheets.dart の showEvent）
extension GameEvents on Game {
  /// 出来事に種類と材料を付ける
  GameEvent tagEv(GameEvent e, String k, [Map<String, dynamic> a = const {}]) {
    e.k = k;
    e.a = a;
    return e;
  }

  /// 文だけの出来事（宿敵の物語の場面・取締役会の報告）。選択肢は「読んだ」の1つだけで、何も動かさない
  GameEvent infoEv(GameEvent e, String done) {
    final v = e.voices;
    return tagEv(e, 'info', {
      't': e.title,
      'x': e.text,
      if (e.lead != null) 'l': e.lead,
      if (e.tail != null) 'tl': e.tail,
      if (v.isNotEmpty) 'v': [for (final x in v) {'n': x.name, 'w': x.who, 'r': x.role, 'k': x.kind, 's': x.say}],
      if (e.who != null) 'c': e.who!.id,
      if (e.face != null) 'f': e.face,
      'cl': e.choices.first.l,
      'cs': e.choices.first.s,
      'd': done,
    });
  }

  /// セーブから出来事を作り直す（相手の会社・人・事業がもういなければ null）
  GameEvent? evRebuild(Map<String, dynamic> j) {
    final k = j['k'] as String?;
    final a = ((j['a'] as Map?) ?? const {}).cast<String, dynamic>();
    Company? co(String n) {
      final c = coById((a[n] as num?)?.round());
      return c != null && c.alive ? c : null;
    }

    Person? pe(String n) => staffById((a[n] as num?)?.round());
    Biz? bz(String n) {
      final id = (a[n] as num?)?.round();
      return biz.where((b) => b.id == id).firstOrNull;
    }

    double dn(String n) => (a[n] as num?)?.toDouble() ?? 0;
    String st(String n) => (a[n] as String?) ?? '';
    GameEvent? e;
    try {
      switch (k) {
        case 'info':
          final c = coById((a['c'] as num?)?.round());
          final d = st('d');
          e = GameEvent(
              title: st('t'),
              text: st('x'),
              lead: a['l'] as String?,
              tail: a['tl'] as String?,
              who: c,
              face: a['f'] as String?,
              voices: [
                for (final v in (a['v'] as List? ?? []))
                  Voice(name: (v as Map)['n'] as String?, who: v['w'] as String, role: v['r'] as String, kind: v['k'] as String, say: v['s'] as String),
              ],
              choices: [Choice(st('cl'), st('cs'), () => d)]);
          e = infoEv(e, d);
        case 'hostile':
          final c = co('c');
          if (c != null && c.rival != null) e = evHostile(c, dn('th'));
        case 'poach':
          final c = co('c'), p = pe('p');
          if (c != null && c.rival != null && p != null) e = evPoach(c, p);
        case 'alliance':
          final c = co('c');
          if (c != null && c.rival != null) e = evAlliance(c);
        case 'pleave':
          final p = pe('p');
          if (p != null) e = evPartnerLeave(p);
        case 'scandal':
          final b = bz('b');
          if (b != null) e = evScandal(b, st('what'), pe('liar'));
        case 'star':
          e = evStar(Person.fromJson((a['p'] as Map).cast<String, dynamic>()));
        case 'union':
          e = evUnion();
        case 'indep':
          final p = pe('p'), b = bz('b');
          if (p != null && b != null) e = evIndep(p, b);
        case 'order':
          final b = bz('b');
          if (b != null) e = evOrder(b);
        case 'ill':
          e = evIll();
        case 'buyBiz':
          final c = co('c'), b = bz('b');
          if (c != null && c.rival != null && b != null) e = evBuyBiz(c, b, dn('price'));
        case 'agmRough':
          e = evAgmRough();
        case 'land':
          e = evLand(dn('a'));
        case 'devMiss':
          final p = pe('p');
          if (p != null) e = evDevMiss(p, st('name'));
        case 'clash':
          final x = propFromJson(a['a']), y = propFromJson(a['b']);
          if (staffById(x.by) != null && staffById(y.by) != null) e = evClash(x, y);
        case 'prop':
          final o = propFromJson(a['o']);
          if (staffById(o.by) != null) e = evProp(o);
        case 'vc':
          if (!listed && sh.vc > 0) e = evVc();
        case 'tieOffer':
          final c = co('c');
          if (c != null) e = evTieOffer(c, dn('money'));
        case 'rivfund':
          final c = co('c');
          if (c != null && c.rival != null) e = evRivFund(c, dn('money'));
        case 'deal':
          final c = co('c');
          if (c != null) e = evDealOffer(c, st('type'));
        case 'subRebel':
          final c = co('c');
          if (c != null && c.parent == 'player') e = evSubRebel(c);
        case 'stolen':
          final c = co('c'), b = bz('b');
          if (c != null && c.rival != null && b != null) e = evStolen(c, b);
        case 'agm':
          if (corp.demand != null) e = evAgmDemand(dn('want'));
        case 'sued':
          final b = bz('b');
          if (b != null) e = evSued(b);
        case 'locHostile':
          final c = co('c'), f = co('f');
          if (c != null && f != null && f.rival != null && c.loc != null) e = evLocalHostile(c, f, dn('th'));
        case 'crisis':
          final kind = st('kind');
          final f = co('foe');
          if (kind != 'takeover' || (f != null && f.rival != null)) e = crisisMeeting(kind, foe: f, near: dn('near'), why0: a['why'] as String?);
        case 'ce':
          final d = countryEvents.where((x) => x.id == st('d')).firstOrNull;
          if (d != null) e = evCe(d, dn('s'), dn('unit'), dn('rev0'));
        case 'rs':
          final c = co('c');
          if (c != null && c.rival != null) e = evRivalScene(c, st('kind'), a);
        case 'motion':
          e = evMotion(st('review'), st('eval'), st('motion'), Voice(who: st('bw'), role: st('br'), kind: 'board', say: st('bs')), dn('target'), dn('cost'), dn('p'));
        case 'quarrel':
          final x = pe('a'), y = pe('b');
          if (x != null && y != null) e = quarrelEv(x, y);
      }
    } catch (_) {
      // 作り直せないもの（材料が欠けた古い形など）は落とす
      e = null;
    }
    if (e == null) return null;
    e.small = j['small'] == true || e.small;
    e.poach = (j['poach'] as num?)?.round() ?? e.poach;
    e.pl = (j['pl'] as num?)?.round() ?? e.pl;
    e.subco = (j['subco'] as num?)?.round() ?? e.subco;
    e.vc = j['vc'] == true || e.vc;
    e.rivfund = j['rivfund'] == true || e.rivfund;
    e.em = (j['em'] as String?) ?? e.em;
    // 文は開いた月のもの（額など）を見せる。選択肢の中身は作り直したもの
    return e.withText((j['d'] as Map?)?.cast<String, dynamic>());
  }

  /// 会議の提案を材料にする・材料から戻す
  Map<String, dynamic> propToJson(Proposal o) => {
        'k': o.k,
        'w': o.w,
        'cost': o.cost,
        'l': o.l,
        'd': o.d,
        if (o.ind != null) 'ind': o.ind,
        'by': o.by,
        'bid': o.bid,
        'n': o.n,
        if (o.sz != null) 'sz': o.sz,
        if (o.c != null) 'c': o.c,
        if (o.mode != null) 'mode': o.mode,
      };
  Proposal propFromJson(Object? x) {
    final j = (x as Map).cast<String, dynamic>();
    return Proposal(k: j['k'] as String, w: (j['w'] as num).round(), cost: (j['cost'] as num).toDouble(), l: j['l'] as String, d: j['d'] as String)
      ..ind = j['ind'] as String?
      ..by = (j['by'] as num).round()
      ..bid = (j['bid'] as num).round()
      ..n = (j['n'] as num).round()
      ..sz = (j['sz'] as num?)?.round()
      ..c = j['c'] as String?
      ..mode = j['mode'] as String?;
  }
}
