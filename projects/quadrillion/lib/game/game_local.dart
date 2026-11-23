// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 現地法人と臨時の会議（1.0.0+9 で足した仕組み。Game.extras で切れる）
///
/// 現地法人で決めたこと:
/// - 事業が出ている国のうち、始めた国以外の1か国の分を、株100%の子会社（現地法人）として分ける。手を1つ使う。お金はかからない。
///   分ける力は「その国の市場の大きさ ÷ 事業の届く市場の大きさ」の割合。事業の力と現場の人はその割合だけ減る。
/// - 現地法人はその国の市場だけで戦う（売上 = 業種の市場 × その国の大きさ × 力 ÷（地元の奪い合い × その国の大きさ ＋ 力）÷ 3）。
///   地域ごとの奪い合い（totals）には入れない。利益の4割が毎月配当として入る（分社した子会社と同じ）。
/// - 社長は部下から選ぶ（相棒は本社に残す）か、現地で雇う（その国の名前・特性はくじ）。
///   社長の特性を持つので、分社した子会社と同じく独断の投資や反発がある（dealsMonthly）。
/// - 地元の規制の緩み:
///   1. 地元の会社と組んで出ていた国でも、現地法人は100%自分の会社なので、利益を半分にされない（組む相手の取り分がなくなる）。
///   2. 中国のネットと金融は、ふつうは地元の会社と組まないと入れない。中国に現地法人が1つでもあれば、
///      ほかの事業も単独・買収で入れる（組む相手なしで入れる）。
///   3. ロシアの制裁のときも、現地法人は現地の会社なので手を引かずに済む（力は2割落ちる）。
/// - 現地法人の株の30%をその国の市場に上場させて、時価総額の3割（手数料5%を引く）を得られる（子会社の上場と同じ）。
/// - 上場した現地法人は、宿敵に株を買い集められることがある（市場に出た30%まで）。10%で知らせ、25%で
///   「買い戻す／持ち株を売り渡す／突っぱねる」を選ぶ。
///
/// 臨時の会議で決めたこと:
/// - きっかけは3つ。乗っ取りの危機（宿敵の持ち分が 17%・30%・45% に届き、20%・33.4%・50% の手前にいる。割合ごとに一度）、
///   大きな不祥事（株価に響く不祥事が10か月以上残る。1年に一度まで）、資金が尽きかける（赤字で手元の資金が3か月分を切る。1年に一度まで）。
/// - 意見を言うのは2〜3人: 相棒（持ち分の多い順）・部下（責任者を先に）から2人まで、株主の代表（上場しているか投資家がいるとき）か
///   メインバンクの担当者。足りなければ両方。人ごとに好む案の順があり、ほかの人と重ならない案を出す。
/// - 案は既存の手を、手を使わずに実行する（ホワイトナイト・自社株買い・新しい株・謝罪会見・資産の売却・借入など）。
/// - 選ばれた部下・相棒は忠誠が3上がり、選ばれなかった部下・相棒は忠誠が10下がる（経営会議と同じく却下の数も1つ増える）。
///   会議を打ち切ると、意見を出した部下・相棒の忠誠が4下がる。株主の代表と銀行には忠誠がない。
extension GameLocal on Game {
  // ===== 現地法人 =====
  /// 現地法人の売上（その国の市場だけで戦う）
  double locRev(String c, Industry ind, double e, Map<String, List<double>> T) {
    final w = cw(c, yr());
    final tot = T[ind.id]![0] * w + e;
    return tot > 0 ? mkt(ind) * w * e / tot / 3 : 0.0;
  }

  /// 自分の現地法人（生きているもの）
  List<Company> locals() => cos.where((c) => c.alive && c.parent == 'player' && c.loc != null).toList();

  /// その国に現地法人があるか（業種を決めれば、その業種のもの）
  bool hasLocal(String c, [String? ind]) => locals().any((x) => x.loc == c && (ind == null || x.biz.any((b) => b.ind == ind)));

  /// 現地法人に分けられる国（始めた国以外で、事業が出ている国）
  List<String> localCountries(Biz b) => extras ? ctryOf(b).where((c) => c != home).toList() : const [];

  /// 現地法人の社長にできる部下（相棒は本社に残す）
  List<Person> localPresCands() => staff.where((p) => !p.partner).toList()..ssort((a, b) => Game.totOf(b) - Game.totOf(a));

  /// その国の名前で人の名前を作る
  String nmIn(String c) {
    final k = NAMEC[c] ?? 'en';
    if (k == 'jp') return '${pick(SEI)} ${pick(MEI)}';
    if (eastPools.contains(k)) return '${pick(NAMEP[k]![0])} ${pick(NAMEP[k]![1])}';
    return '${pick(NAMEP[k]![1])}・${pick(NAMEP[k]![0])}';
  }

  /// 事業のある国の分を現地法人に分ける。presId が null なら現地で社長を雇う
  String makeLocal(Biz b, String c, [int? presId]) {
    if (!extras) return M('今は使えません');
    if (c == home) return M('始めた国の分は分けられません');
    if (!ctryOf(b).contains(c)) return M('その国には出ていません');
    if (hasLocal(c, b.ind)) return M('その国にはもう現地法人があります');
    Person? p;
    if (presId != null) {
      p = staffById(presId);
      if (p == null) return M('その人はもういません');
      if (p.partner) return M('相棒は本社に残します。ほかの部下か、現地で雇う人を選んでください');
    }
    if (!canAP(1)) return M('今月の手が残っていません');
    useAP(1);
    final ind = indm[b.ind]!;
    final frac = clampD(cw(c, yr()) / math.max(reachOf(b), 1e-9), 0, .95);
    final pw = b.power * frac;
    String presName;
    double presAge;
    String trait;
    if (p != null) {
      presName = p.name;
      presAge = p.age.toDouble();
      trait = p.trait;
      for (final x in biz) {
        if (x.mgr == p.id) x.mgr = null;
      }
      if (succ == p.id) succ = null;
      staff.remove(p);
    } else {
      presName = nmIn(c);
      presAge = ri(38, 56).toDouble();
      trait = pick(STRAITS).id;
    }
    final co = mkCo(0, ind.cat, presName: presName, fam: 0);
    co.presAge = presAge;
    co.parent = 'player';
    co.stakePlayer = 100;
    co.loc = c;
    co.biz.add(CoBiz(ind: b.ind, power: pw));
    co.g = .008;
    co.rel = 30;
    co.culture = GameActions._cultOfTrait(trait);
    co.fromStaff = trait;
    b.power -= pw;
    if (b.crew != null) b.crew = b.crew! * (1 - frac);
    b.ctry = ctryOf(b).where((x) => x != c).toList();
    if (b.jv != null) b.jv = b.jv!.where((x) => x != c).toList();
    calcAll();
    chron('local', M('「{0}」の{1}の分を、現地法人{2}として分けた（社長は{3}）', [I(ind.id), C(c), Nm(co.name), Nm(presName)]));
    return Cat([
      M('「{0}」の{1}の分を現地法人{2}に分けました。社長は{3}', [I(ind.id), C(c), Nm(co.name), Nm(presName)]),
      M(p != null ? '{0}が自分の判断で動かします' : '現地で雇った{0}が自分の判断で動かします', [Nm(presName)]),
    ], ja: '。', en: '. ');
  }

  /// 毎月の現地法人の動き（制裁・宿敵の買い集め）。extras を切ると何もしない
  void localMonthly(void Function(String, [String]) N) {
    if (!extras) return;
    for (final c in locals()) {
      // ロシアの制裁: 現地法人は手を引かずに済むが、力は2割落ちる
      if (c.loc == 'ru' && home != 'ru' && yr() >= 2022.2 && crisis['ru:${c.id}'] == null) {
        crisis['ru:${c.id}'] = turn;
        for (final b in c.biz) {
          b.power *= .8;
        }
        N(M('【制裁】{0}は現地の会社なので、ロシアから手を引かずに済みました。ただ、取引が細り力は2割落ちました', [Nm(c.name)]), 'bad');
      }
      if (!c.listed) continue;
      final float = math.max(0.0, 100 - c.stakePlayer - c.locRivPct);
      var foe = coById(c.locRiv);
      if (foe != null && (!foe.alive || foe.rival == null || foe.parent == 'player')) {
        c.locRivPct = 0;
        c.locRiv = null;
        foe = null;
      }
      final before = c.locRivPct;
      if (foe == null) {
        if (float > 1 && rnd() < .015 * dif.t) {
          final pool = cos.where((x) => x.alive && x.rival != null && x.parent != 'player' && x.cash > c.cap * .03).toList();
          final f = pickOr(pool);
          if (f != null) {
            final buy = math.min(float, ri(3, 6).toDouble());
            c.locRiv = f.id;
            c.locRivPct = buy;
            f.cash -= c.cap * buy / 100;
            tieRec(f, 'h', M('現地法人{0}の株を買われた', [Nm(c.name)]));
            N(M('{0}（{1}）が、上場した現地法人{2}の株を{3}買いました', [Nm(f.rival!.pres), Nm(f.name), Nm(c.name), pct(buy)]), 'bad');
          }
        }
      } else if (float > .5 && foe.cash > 0 && rnd() < .08 * dif.t) {
        final buy = math.min(float, ri(2, 5).toDouble());
        c.locRivPct += buy;
        foe.cash -= c.cap * buy / 100;
      }
      final f = coById(c.locRiv);
      if (f == null) continue;
      for (final th in const [10.0, 25.0]) {
        if (before < th && c.locRivPct >= th) {
          final k = 'loc:${c.id}:${jsNum(th)}';
          if (crisis[k] == null) {
            crisis[k] = turn;
            events.add(evLocalHostile(c, f, th));
          }
        }
      }
    }
  }

  /// 現地法人の株を買い戻す費用（買値の2割増し）
  double localBuybackCost(Company c) => c.cap * c.locRivPct / 100 * 1.2;

  /// 宿敵が持つ現地法人の株を買い戻す（手は使わない）
  String localBuyback(Company c) {
    final f = coById(c.locRiv);
    if (f == null || c.locRivPct <= 0) return M('買い戻す株はありません');
    final x = localBuybackCost(c);
    if (cash < x) return M('お金が足りず、買い戻せませんでした');
    cash -= x;
    f.cash += x;
    c.locRivPct = 0;
    c.locRiv = null;
    tieRec(f, 'g', M('現地法人{0}の株を買い戻した', [Nm(c.name)]));
    return M('{0}の株を{1}で買い戻しました', [Nm(c.name), Y(x)]);
  }

  GameEvent evLocalHostile(Company c, Company f, double th) {
    final r = f.rival!;
    final cost = localBuybackCost(c);
    final sale = c.cap * c.stakePlayer / 100 * 1.3;
    return GameEvent(
        who: f,
        face: r.col,
        title: M(th >= 25 ? '現地法人が狙われている' : '現地法人の株を買われている'),
        text: M(
            th >= 25
                ? '{0}（{1}）が、{2}の現地法人{3}の株を{4}まで買い集めました。「経営に口を出させてもらう。いやなら、あなたの持ち株を高く買ってやろう」と言っています。'
                : '{0}（{1}）が、{2}の現地法人{3}の株を{4}まで買い集めています。',
            [Nm(r.pres), Nm(f.name), C(c.loc!), Nm(c.name), pct(c.locRivPct)]),
        choices: [
          Choice(M('株を買い戻す'), M('{0}を払い、相手の持ち分をすべて引き取る', [Y(cost)]), () => localBuyback(c)),
          if (th >= 25)
            Choice(M('持ち株を売り渡す'), M('{0}が入る。現地法人は相手のものになる', [Y(sale)]), () {
              final v = c.cap * c.stakePlayer / 100 * 1.3;
              cash += v;
              for (final b in c.biz) {
                f.biz.add(CoBiz(ind: b.ind, power: b.power));
              }
              c.alive = false;
              c.stakePlayer = 0;
              c.parent = null;
              f.rel += 10;
              tieRec(f, 'f', M('現地法人{0}を売り渡した', [Nm(c.name)]));
              calcAll();
              return M('{0}を{1}に売り渡し、{2}を得ました', [Nm(c.name), Nm(f.name), Y(v)]);
            }),
          Choice(M(th >= 25 ? '突っぱねる' : '様子を見る'), M(th >= 25 ? 'お金はかからない。口出しで現地法人の稼ぐ力が1割落ちる' : '何もしない。相手はまだ買い進めるかもしれない'), () {
            if (th >= 25) {
              c.eff *= .9;
              f.rel -= 10;
              return M('突っぱねました。{0}の口出しで、{1}の現場がぎくしゃくしています', [Nm(f.name), Nm(c.name)]);
            }
            return M('様子を見ることにしました');
          }),
        ]);
  }

  // ===== 臨時の会議 =====
  /// 毎月の終わりに、臨時の会議を開くかを見る（乱数は使わない）。extras を切ると何もしない
  void crisisMonthly() {
    if (!extras || over != null) return;
    if (events.any((e) => e.em != null)) return;
    // 乗っ取りの危機（20%・33.4%・50% に近づいた）
    for (final e in sh.riv.entries) {
      final c = coById(e.key);
      if (c == null || c.rival == null) continue;
      for (final th in const [(45.0, 50.0), (30.0, 33.4), (17.0, 20.0)]) {
        if (e.value >= th.$1 && e.value < th.$2) {
          final k = 'em:t:${e.key}:${jsNum(th.$2)}';
          if (crisis[k] == null) {
            crisis[k] = turn;
            final ev = crisisMeeting('takeover', foe: c, near: th.$2);
            if (ev != null) {
              events.add(ev);
              return;
            }
          }
        }
      }
    }
    // 大きな不祥事
    if (scandal >= 10 && biz.isNotEmpty && turn - (crisis['em:s'] ?? -99) >= 12) {
      crisis['em:s'] = turn;
      final ev = crisisMeeting('scandal');
      if (ev != null) {
        events.add(ev);
        return;
      }
    }
    // 資金が尽きかける
    final burn = -pre;
    if (biz.isNotEmpty && burn > 0 && cash < burn * 3 && turn - (crisis['em:c'] ?? -99) >= 12) {
      crisis['em:c'] = turn;
      final ev = crisisMeeting('cash');
      if (ev != null) events.add(ev);
    }
  }

  /// 意見を言う人（部下・相棒は2人まで、外の声は株主の代表かメインバンク。少なくとも2人）
  List<({Person? p, String who, String role, String kind})> crisisVoices() {
    final out = <({Person? p, String who, String role, String kind})>[];
    final ps = staff.where((p) => p.partner).toList()..ssort((a, b) => b.stake.compareTo(a.stake));
    final mgrs = staff.where((p) => !p.partner).toList()
      ..ssort((a, b) {
        final ma = biz.any((x) => x.mgr == a.id) ? 1 : 0, mb = biz.any((x) => x.mgr == b.id) ? 1 : 0;
        return ma != mb ? mb - ma : Game.totOf(b) - Game.totOf(a);
      });
    for (final p in [...ps, ...mgrs].take(2)) {
      final job = biz.where((x) => x.mgr == p.id).firstOrNull;
      out.add((
        p: p,
        who: Nm(p.name),
        role: p.partner
            ? M('相棒@@role')
            : job != null
                ? M('「{0}」の責任者', [I(job.ind)])
                : M('部下@@role'),
        kind: p.partner ? 'partner' : 'staff',
      ));
    }
    final holders = listed || sh.vc > 0;
    final holder = (p: null, who: M('株主の代表'), role: M(listed ? '市場の株主' : '投資家@@role'), kind: 'holder');
    final bank = (p: null, who: M('メインバンクの担当者'), role: M('銀行@@role'), kind: 'bank');
    out.add(holders ? holder : bank);
    if (out.length < 2) out.add(holders ? bank : holder);
    return out;
  }

  /// 人ごとの好む案の順
  static const Map<String, Map<String, List<String>>> _prefs = {
    'takeover': {
      'partner': ['wk', 'talk', 'bb', 'dil'],
      'staff': ['dil', 'bb', 'wk', 'talk'],
      'holder': ['bb', 'wk', 'talk', 'dil'],
      'bank': ['talk', 'wk', 'bb', 'dil'],
    },
    'scandal': {
      'partner': ['resign', 'apology', 'pr', 'wait'],
      'staff': ['pr', 'apology', 'resign', 'wait'],
      'holder': ['apology', 'resign', 'pr', 'wait'],
      'bank': ['apology', 'wait', 'resign', 'pr'],
    },
    'cash': {
      'partner': ['loan', 'equity', 'cut', 'sell'],
      'staff': ['sell', 'cut', 'loan', 'equity'],
      'holder': ['cut', 'sell', 'loan', 'equity'],
      'bank': ['loan', 'sell', 'cut', 'equity'],
    },
  };

  /// 臨時の会議の案（鍵 → 呼び名・ひとこと・中身・実行）。使えない案は入れない
  Map<String, ({String l, String say, String d, String Function() f})> crisisOptions(String kind, {Company? foe}) {
    final o = <String, ({String l, String say, String d, String Function() f})>{};
    final n = nom();
    if (kind == 'takeover') {
      final ally = cos.where((c) => c.alive && c.rival == null && c.parent != 'player' && c.tier == 0).isNotEmpty;
      if (ally && sh.float > .5) {
        o['wk'] = (
          l: M('ホワイトナイトに頼む'),
          say: M('味方の会社に株を持ってもらいましょう。信用できる相手なら、乗っ取りの壁になります'),
          d: M('味方の会社に市場の株を10%持ってもらう。見返りに相手の株5%を買う'),
          f: doWhiteKnight,
        );
      }
      if (listed && sh.float > .5) {
        final x = math.min(sh.float, 8.0);
        o['bb'] = (
          l: M('自社株買いで市場の株を減らす'),
          say: M('市場の株を買い戻せば、株価も上がります。株主にとっても一番です'),
          d: M('市場の株を{0}買い戻す（約{1}）。相手の割合も少し上がる', [pct(x), Y(cap * x / 100 * 1.15)]),
          f: () => doBuyback(math.min(sh.float, 8)),
        );
      }
      o['dil'] = (
        l: M('新しい株を出して薄める'),
        say: M('味方に新しい株を渡して、相手の割合を薄めましょう。お金も入ります'),
        d: M('味方に新しい株を15%分渡し、相手の割合を薄める。自分の割合も下がる'),
        f: doDilute,
      );
      final fc = foe;
      if (fc != null && fc.rival != null) {
        o['talk'] = (
          l: M('相手の社長と話し合う'),
          say: M('争えば双方が傷つきます。一度、{0}と腹を割って話すべきです', [Nm(fc.rival!.pres)]),
          d: M('お金はかからない。相手との関係が良くなり、買い進める気が弱まることがある'),
          f: () {
            fc.rel += 20;
            tieRec(fc, 'f', M('臨時の会議のあと、話し合いに出向いた'));
            return M('{0}と話し合い、関係が少し和らぎました', [Nm(fc.rival!.pres)]);
          },
        );
      }
    } else if (kind == 'scandal') {
      final apo = math.max(rev * .1, 1e6 * n);
      o['apology'] = (
        l: M('謝罪会見を開く'),
        say: M('すぐに頭を下げるべきです。長引くほど株価に響きます'),
        d: M('{0}をかけて謝る。騒ぎが半年ほど早く収まる', [Y(apo)]),
        f: () {
          cash -= apo;
          scandal = math.max(0, scandal - 6);
          return M('謝罪会見を開き、騒ぎは収まり始めました');
        },
      );
      o['resign'] = (
        l: M('社長の報酬を返上する'),
        say: M('社長が自ら身を切る姿を見せれば、社員も客もついてきます'),
        d: M('あなたの財産から{0}を返上する。騒ぎが少し早く収まり、部下の忠誠が上がる', [Y(wealth * .1)]),
        f: () {
          wealth *= .9;
          scandal = math.max(0, scandal - 4);
          for (final p in staff) {
            p.loy = math.min(99, p.loy + 3);
          }
          return M('社長の報酬を返上し、けじめをつけました');
        },
      );
      final pr = math.max(rev * .3, 2e6 * n);
      o['pr'] = (
        l: M('広告で信用を取り戻す'),
        say: M('謝るより、良い話で上書きしましょう。広告を打てば客は戻ります'),
        d: M('{0}をかけて広告を打つ。騒ぎがかなり早く収まる', [Y(pr)]),
        f: () {
          cash -= pr;
          scandal = math.max(0, scandal - 8);
          return M('広告を打ち、信用を取り戻しにかかりました');
        },
      );
      o['wait'] = (
        l: M('騒ぎが収まるのを待つ'),
        say: M('下手に動くと火に油です。静かに待つのが一番です'),
        d: M('何もしない。お金はかからない'),
        f: () => M('静かに待つことにしました'),
      );
    } else {
      final burn = math.max(0.0, -pre);
      final want = math.max(burn * 6, 1e7 * n);
      o['loan'] = (
        l: M('銀行から借りる'),
        say: M('今は手元のお金が命です。借りられるだけ借りておきましょう'),
        d: M('{0}まで借りる。会議で話をつけたので、いつもより2割多く借りられる', [Y(want)]),
        f: () {
          final room = math.max(0.0, borrowLimit() * 1.2 - debt);
          final a = math.min(want, room);
          if (a <= 0) return M('銀行はこれ以上貸してくれませんでした');
          debt += a;
          cash += a;
          return M('銀行から{0}を借りました', [Y(a)]);
        },
      );
      if (land > 0 || biz.length > 1) {
        o['sell'] = (
          l: M('資産を売る'),
          say: M('稼がない資産は売りましょう。身軽になれば立て直せます'),
          d: land > 0 ? M('土地を{0}で売る', [Y(land)]) : M('一番稼がない事業を売る'),
          f: () {
            if (land > 0) return sellLand();
            if (biz.length < 2) return M('売れる資産がありませんでした');
            final w = (biz.toList()..ssort((a, b) => a.profit.compareTo(b.profit)))[0];
            final v = sellValue(w);
            cash += v;
            biz.remove(w);
            calcAll();
            return M('「{0}」を{1}で手放しました', [I(w.ind), Y(v)]);
          },
        );
      }
      o['cut'] = (
        l: M('経費を削る'),
        say: M('まずは出ていくお金を止めることです。給料と維持費を削りましょう'),
        d: M('給料と事業の維持費を1割5分削る。部下の忠誠が下がる'),
        f: () {
          for (final p in staff) {
            p.salary *= .85;
            p.loy -= 6;
          }
          for (final b in biz) {
            b.upkeep *= .85;
          }
          calcAll();
          return M('給料と維持費を削りました');
        },
      );
      if (listed) {
        o['equity'] = (
          l: M('新しい株を出して集める'),
          say: M('株を出せば返さなくていいお金が入ります。今は背に腹は代えられません'),
          d: M('新しい株を市場に出して{0}を集める。持ち株が薄まる', [Y(cap * .1 * .95)]),
          f: () {
            final money = cap * .1 * .95;
            const k = 100 / 110;
            _dilute(k);
            sh.float = sh.float * k + 10 * k;
            cash += money;
            calcAll();
            return M('新しい株を出し、{0}を集めました', [Y(money)]);
          },
        );
      } else if (sh.own > 40) {
        o['equity'] = (
          l: M('投資家から集める'),
          say: M('投資家に株を渡せば、返さなくていいお金が入ります'),
          d: M('株を10%渡して{0}を集める。上場の約束がつく', [Y(cap * .1)]),
          f: () {
            final money = cap * .1;
            cash += money;
            sh.own -= 10;
            sh.vc += 10;
            if (vcDeadline == 0) vcDeadline = turn + 36;
            calcAll();
            return M('投資家から{0}を集めました', [Y(money)]);
          },
        );
      }
    }
    return o;
  }

  /// 臨時の会議の出来事を作る（案が2つそろわなければ null）
  GameEvent? crisisMeeting(String kind, {Company? foe, double near = 0}) {
    final voices = crisisVoices();
    final opts = crisisOptions(kind, foe: foe);
    final picks = <({Person? p, String who, String role, String kind, String k})>[];
    final used = <String>{};
    for (final v in voices) {
      final k = _prefs[kind]![v.kind]!.where((x) => opts.containsKey(x) && !used.contains(x)).firstOrNull;
      if (k == null) continue;
      used.add(k);
      picks.add((p: v.p, who: v.who, role: v.role, kind: v.kind, k: k));
    }
    if (picks.length < 2) return null;
    final why = switch (kind) {
      'takeover' => M('{0}（{1}）の持ち分が{2}になり、{3}%に近づいています', [Nm(foe!.rival!.pres), Nm(foe.name), pct(sh.riv[foe.id] ?? 0), jsNum(near)]),
      'scandal' => M('不祥事で信用が揺らぎ、株価も下がっています（あと{0}か月は響きます）', [scandal]),
      _ => M('赤字が続き、手元の資金はあと{0}か月分ほどしかありません', [pre < 0 ? jsNum(math.min(99, (math.max(0.0, cash) / -pre).floorToDouble())) : 0]),
    };
    final title = M('臨時の会議：{0}', [M(switch (kind) { 'takeover' => '乗っ取りの危機', 'scandal' => '大きな不祥事', _ => '資金が尽きかけている' })]);
    final staffIn = picks.where((x) => x.p != null).toList();
    final choices = <Choice>[
      for (final x in picks)
        Choice(
            M('{0}の案：{1}', [x.who, opts[x.k]!.l]),
            Cat([
              opts[x.k]!.d,
              if (staffIn.any((y) => y.p != x.p)) M('{0}の忠誠が下がる', [J(staffIn.where((y) => y.p != x.p).map((y) => y.who))]),
            ], ja: '。', en: '. '), () {
          for (final y in staffIn) {
            final p = staffById(y.p!.id);
            if (p == null) continue;
            if (y.p == x.p) {
              p.loy = math.min(99, p.loy + 3);
              p.rej = 0;
            } else {
              p.loy -= 10;
              p.rej = p.rej + 1;
            }
          }
          return Cat([M('{0}の案を選びました', [x.who]), opts[x.k]!.f()], ja: '。', en: '. ');
        }),
      Choice(M('会議を打ち切る'), M(staffIn.isEmpty ? '何もしない' : '何もしない。意見を出した部下の忠誠が少し下がる'), () {
        for (final y in staffIn) {
          final p = staffById(y.p!.id);
          if (p != null) p.loy -= 4;
        }
        return M('結論を出さずに会議を打ち切りました');
      }),
    ];
    return GameEvent(
        em: kind,
        who: kind == 'takeover' ? foe : null,
        face: kind == 'takeover' ? foe!.rival!.col : null,
        title: title,
        text: Cat([
          why,
          M('急いで臨時の会議を開きました。意見は割れています'),
          for (final x in picks) M('{0}（{1}）：{2}', [x.who, x.role, opts[x.k]!.say]),
        ], ja: '\n', en: '\n'),
        choices: choices);
  }
}
