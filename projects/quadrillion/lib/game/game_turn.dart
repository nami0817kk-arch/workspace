// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 1か月すすめる・出来事・宿敵の動き
extension GameTurn on Game {
  // ===== 1期すすめる =====
  List<LogEntry> nextQuarter() {
    final news = <LogEntry>[];
    void N(String m, [String t = '']) => news.add(LogEntry(m, t));
    final over0 = over, won0 = won, peak0 = peakRank;
    // 時代（景気は統計の成長率から。株価と技術の波は出来事から）
    econData.fcSeed = fcSeed;
    monthEcon(N);
    perMul = 1;
    techBoom = 1;
    final y = yr();
    final rn = regFor(y);
    final rr = [for (var i = 0; i < 3; i++) rn[i] / reg[i]];
    reg = rn;
    for (final c in cos) {
      for (final b in c.biz) {
        b.power *= rr[c.tier];
      }
    }
    for (final b in biz) {
      final k = rr[tierOf(b)];
      b.power *= k;
      if (b.crew != null && b.crew != 0) b.crew = b.crew! * k;
    }
    for (final c in cycles) {
      if (y >= c.s && y < c.e + .99) {
        econ *= c.econ;
        perMul *= c.per;
        techBoom *= c.tech;
        if (!c.shown) {
          c.shown = true;
          N(M('【{0}】{1}', [c.name, c.news]), 'big');
          chron('era', M('【{0}】{1}', [c.name, c.news]));
        }
      }
    }
    // 市場の大きさに合わせて力を伸び縮みさせる
    final grow = <String, double>{};
    for (final ind in inds) {
      final mk0 = mkt(ind);
      final old = indM[ind.id] ?? 0;
      if (mk0 > 0 && old <= 0 && yr() > startYear) {
        // 新しい業種が生まれた（古いセーブで足した業種は知らせを出さない）
        if (!lateInds.remove(ind.id)) N(M('新しい業種「{0}」が生まれました。まだ大きな会社はいません', [I(ind.id)]), 'big');
        final k = ri(2, 4);
        for (var i = 0; i < k; i++) {
          final t = rnd() < .4
              ? 0
              : rnd() < .4
                  ? 1
                  : 2;
          final c = mkCo(t, ind.cat);
          c.g = .02 + rnd() * .02;
          c.biz.add(CoBiz(ind: ind.id, power: mk0 * reg[t] * (techCats.contains(ind.cat) ? .12 : .05) * (.5 + rnd())));
        }
        Company? gr;
        for (final c in cos) {
          if (c.alive && c.rival != null && c.rival!.type == 'genius') {
            gr = c;
            break;
          }
        }
        if (gr != null && rnd() < .7) {
          gr.biz.add(CoBiz(ind: ind.id, power: mk0 * .08));
          N(M('{0}（{1}）が「{2}」に乗り込みました', [Nm(gr.presName), Nm(gr.name), I(ind.id)]), 'bad');
        }
      } else if (mk0 > 0 && old > 0) {
        // 倍率だけ控えて、あとで会社を1回だけ回してかける（業種ごとに全社を回すと、会社が900社あると重い）。
        // 1つの事業にかかる倍率は自分の業種の1つだけなので、かける順を変えても数字は同じ
        grow[ind.id] = math.pow(mk0 / old, .95).toDouble();
      }
      indM[ind.id] = mk0;
    }
    if (grow.isNotEmpty) {
      for (final c in cos) {
        for (final b in c.biz) {
          final r = grow[b.ind];
          if (r != null) b.power *= r;
        }
      }
      for (final b in biz) {
        final r = grow[b.ind];
        if (r != null) {
          b.power *= r;
          if (b.crew != null && b.crew != 0) b.crew = b.crew! * r;
        }
      }
    }
    // CPU の動き（難しさで伸びと再投資を変える。ふつうは 1 をかけるだけなので試作と同じ）
    final dG = dif.g, dR = dif.r;
    for (final c in cos) {
      if (!c.alive) continue;
      for (final b in c.biz) {
        var gg = (c.g * dG + (rnd() - .5) * .03) / 3;
        if (c.rival != null && c.rival!.k == 'li' && yr() > 1995 && yr() < 2035) gg += .004 * dG;
        if (c.rival != null && c.rival!.type == 'genius' && indm[b.ind]!.b > 1985) gg += .0067 * dG;
        b.power *= math.max(.8, 1 + gg);
        final T = lastT?[b.ind];
        final s = T != null && T[c.tier] > 0 ? b.power / T[c.tier] : 0.0;
        final pr = b.rev * indm[b.ind]!.mg * c.eff;
        if (pr > 0) b.power += pr * cpuReinv * dR * invEff * math.pow(1 - math.min(s, .95), 2);
      }
      c.cash = c.cash * .985 + c.profit * .25;
      c.presAge += 1 / 12;
      c.revHist.add(c.rev);
      if (c.revHist.length > 24) c.revHist.removeAt(0);
    }
    // 若い天才は時々つまずく
    for (final c in cos) {
      if (c.alive && c.rival != null && c.rival!.type == 'genius' && rnd() < .008) {
        for (final b in c.biz) {
          b.power *= .45;
        }
        N(M('{0}の{1}で大きな失敗。事業の力が半分に落ちました', [Nm(c.presName), Nm(c.name)]), 'good');
      }
    }
    // 時々、新しい会社が生まれ、弱い会社が消える
    if (rnd() < .12) {
      final live = liveInds().where((i) => eraF(i, yr()) < 1).toList();
      if (live.isNotEmpty) {
        final ind = pick(live);
        final t = rnd() < .6
            ? 0
            : rnd() < .5
                ? 1
                : 2;
        final c = mkCo(t, ind.cat);
        c.g = .015 + rnd() * .02;
        c.biz.add(CoBiz(ind: ind.id, power: mkt(ind) * reg[t] * .03));
      }
    }
    // 市場の大きさは業種ごとに1回だけ求める。安い条件（現金）を先に見る（どれも乱数を使わないので、結果は同じ）
    final mkC = <String, double>{};
    for (final c in cos.toList()) {
      if (c.alive &&
          c.parent != 'player' &&
          c.rival == null &&
          c.cash <= 0 &&
          c.rev < (mkC[c.biz.isEmpty ? inds[0].id : c.biz[0].ind] ??= mkt(c.biz.isEmpty ? inds[0] : indm[c.biz[0].ind]!)) * .0005 &&
          rnd() < .1) {
        c.alive = false;
      }
    }
    // 儲かっている市場には、大手が後を追って入ってくる
    for (final b in biz) {
      if (b.share > .25 && !inAssoc(b.ind) && rnd() < .04 * (b.share / .25)) {
        final ind = indm[b.ind]!;
        final tb = tierOf(b);
        final bigs = cos.where((c) => c.alive && c.parent != 'player' && c.tier >= tb && !c.biz.any((x) => x.ind == b.ind)).toList()
          ..ssort((a, b2) => b2.cap.compareTo(a.cap));
        final top = bigs.take(12).toList();
        if (top.isNotEmpty) {
          final c = pick(top);
          c.biz.add(CoBiz(ind: b.ind, power: b.power * (.25 + rnd() * .25)));
          N(M('{0}が、あなたの独り勝ちを見て「{1}」に乗り込んできました', [Nm(c.name), I(ind.id)]), 'bad');
        }
      }
    }
    // 宿敵の手
    rivalAI(N);
    // 自分の事業
    for (final b in biz) {
      if (b.attack > 0) {
        final tc = cos.where((c) => c.id == b.target && c.alive).firstOrNull;
        if (tc != null) {
          for (final x in tc.biz) {
            if (x.ind == b.ind) x.power *= .965;
          }
        }
        b.attack--;
        if (b.attack == 0 && tc != null) N(M('「{0}」での{1}との値下げ合戦が終わりました', [I(b.ind), Nm(tc.name)]));
      }
    }
    for (final b in biz) {
      b.age++;
      if (b.ad > 0) b.ad--;
      if (b.war > 0) b.war--;
      final p = staffById(b.mgr);
      // 1.1.0+26 から、店などが売り切れている（客は余っている）あいだは、責任者は稼ぎを客集めに回さない（回しても売上は増えない）
      final full = unitsOn && (capKOf[b.id] ?? 1) < .97;
      if (p != null && b.profit > 0 && !full) {
        var rate = .3;
        if (p.trait == 'careful') rate = .15;
        if (p.trait == 'gambler') rate = .6;
        final gain = b.profit * rate;
        cash -= gain;
        var eff = invEff * math.pow(1 - b.share, 2) * smallBonus(b);
        if (p.trait == 'genius') eff *= .5 + rnd() * 1.6;
        if (p.trait == 'gambler' && rnd() < .2) eff = 0;
        if (p.trait == 'frugal') eff *= .8;
        b.power += gain * eff * .6;
        b.crew = crewOf(b) + gain * eff * .8;
        if (p.amb > 75 && b.share < .15 && b.price != 'cut' && p.trait != 'charm' && rnd() < .08 && !full) {
          b.price = 'cut';
          p.ambKnown = true;
          N(M('{0}が勝手に「{1}」で値下げ合戦を始めました。野心が強い人のようです', [Nm(p.name), I(b.ind)]), 'bad');
        }
      }
    }
    // 稼ぎ方ごとの動き
    if (yr() >= 2022.2 && !ruDone && biz.any((b) => ctryOf(b).contains('ru'))) {
      ruDone = true;
      for (final b in biz) {
        if (ctryOf(b).contains('ru') && home != 'ru') {
          b.ctry = ctryOf(b).where((c) => c != 'ru').toList();
          b.jv = (b.jv ?? []).where((c) => c != 'ru').toList();
          b.power *= .9;
        }
      }
      if (home != 'ru') N(M('【制裁】ロシアへの制裁が始まり、ロシアの事業から手を引くことになりました'), 'bad');
    }
    for (final b in biz) {
      if (b.model == 'plat' && b.share > .15) b.power *= 1.006;
      if (b.model == 'sub' && rnd() < .006) {
        b.power *= .65;
        N(M('元請けの大企業が「{0}」との取引を打ち切りました。注文が大きく減ります', [I(b.ind)]), 'bad');
      }
      if (b.model == 'fc' && rnd() < .006) {
        b.power *= .85;
        scandal = math.max(scandal, 6);
        N(M('「{0}」の加盟店で不祥事が起き、看板に傷がつきました', [I(b.ind)]), 'bad');
      }
    }
    // 店などの育ち・解約・許可・物件（1.1.0+26）
    monthUnits(N);
    // 関税・輸送・海外の難しさ・供給の網（1.1.0+28）
    monthTrade(N);
    // 仕掛かり中の打ち手
    for (final b in biz.toList()) {
      if (b.pipe.isNotEmpty) {
        for (final x in b.pipe) {
          x.left--;
        }
        final done = b.pipe.where((x) => x.left <= 0).toList();
        b.pipe = b.pipe.where((x) => x.left > 0).toList();
        for (final x in done) {
          finishPipe(b, x, N);
        }
      }
    }
    // 人
    for (final p in staff) {
      p.tenure++;
      if (p.tenure == 12 && !p.traitKnown) {
        p.traitKnown = true;
        final t = STRAITS.firstWhere((x) => x.id == p.trait);
        N(M('{0}の特性が分かりました：「{1}」（{2}／{3}）', [Nm(p.name), D(t.nJa), D(t.gJa), D(t.bJa)]));
      }
      p.loy += (const {'merit': -.15, 'family': .15, 'sports': -.1, 'free': 0.0, 'steady': .05}[culture] ?? 0) +
          (cultLeft > 0 ? -.2 : 0) +
          (hasT('oneman') && culture == 'free' ? -.15 : 0) +
          (hasT('charm') && culture == 'family' ? .1 : 0);
      if (hasT('stamina')) p.loy -= .33;
      if (hasT('frugal')) p.loy -= .17;
      if (hasT('genius')) p.loy -= .1;
      if (p.trait == 'stamina') {
        for (final o in staff) {
          if (o != p) o.loy -= .07;
        }
      }
      if (q == 12 && p.real) {
        // 経歴を持つ人は、経験で細かい能力が伸び、年で衰える（1.1.0+27）
        p.age++;
        yearPerson(p);
      } else if (q == 12) {
        p.age++;
        if (p.age > 58 && p.trait != 'stamina') {
          for (final k in abKeys) {
            p.ab[k] = math.max(5, p.ab[k]! - 2);
          }
        }
        if (p.age < 40) {
          for (final k in abKeys) {
            p.ab[k] = math.min(
                99,
                p.ab[k]! +
                    ri(
                        0,
                        culture == 'merit'
                            ? 3
                            : culture == 'family'
                                ? 1
                                : 2));
          }
          final job = biz.where((b) => b.mgr == p.id).firstOrNull;
          if (job != null) {
            final k = indm[job.ind]!.key;
            p.ab[k] = math.min(99, p.ab[k]! + 2);
          }
        }
      }
    }
    // 名前のある部下の1か月（健康・家族・給料への不満・転職。1.1.0+27）
    monthPeople(N);
    // 部下の引退（経歴を持つ人は、国と時代の定年から。相棒は定年が無い）
    if (q == 12) {
      final ra = retireAge();
      for (final p in staff.toList()) {
        final lim = p.real && !p.partner ? ra : 65;
        if (p.age >= lim && (p.age >= lim + 7 || rnd() < .35)) {
          fire(p, 'retired');
          N(M('{0}（{1}歳）が引退しました', [Nm(p.name), p.age]));
        }
      }
    }
    // 社長の年齢
    if (q == 12) {
      pres.age++;
      final lim = hasT('stamina') ? 68 : 58;
      if (pres.age > lim) {
        for (final k in abKeys) {
          pres.ab[k] = math.max(5, pres.ab[k]! - 2);
        }
      }
      for (final k in kids) {
        k.age++;
      }
      if (pres.age >= 30 && pres.age <= 45 && kids.length < 3 && rnd() < .25) {
        final k = mkPerson(0);
        k.age = 0;
        k.name = kidName(pres.name);
        k.kid = true;
        kids.add(k);
        N(M('子どもが生まれました。名前は{0}。後継ぎの候補になるかもしれません', [Nm(Game.givenOf(k.name))]), 'good');
      }
    }
    final dieAge = hasT('stamina') ? 78 : 70;
    if (pres.age > dieAge && rnd() < (pres.age - dieAge) * .004) presDies(N);
    // お金
    for (final b in biz) {
      b.prevRev = b.rev;
    }
    calcAll();
    final p0 = pre;
    // 税金は国と年の法人税率で、今年の利益の積み上げにかける（赤字の月は今年払った分から戻る。1.1.0+25）
    final tax = monthTax(p0);
    cash += p0 - tax;
    // 売掛金：代金をもらうまでの月が長い業種は、売上が伸びた分だけ現金が遅れて入る（1.1.0+26）
    // （売掛は4か月かけて今の売上に追いつく。始めた月に数か月分の現金がいきなり消えないように）
    final ar1 = ar + (receivables() - ar) * .25;
    cash -= ar1 - ar;
    ar = ar1;
    lastTax = tax;
    for (final c in subs()) {
      if (c.profit > 0) cash += c.profit * .4 * pctOf(c) / 100;
    }
    if (scandal > 0) scandal--;
    // 借金の元本を返す・不況の貸しはがし・足りない分の手当て（1.1.0+25）
    expLast = expenses();
    monthLoans(N);
    recessionCall(N);
    coverShort(N);
    // 引き抜きなどの出来事
    rollEvents(N);
    // 候補者（1.1.0+27 から、採用の市場で数と質が決まる）
    cands = [];
    final n = extras ? 0 : (hasT('noble') ? 2 : 3);
    if (extras) cands = rollCands();
    for (var i = 0; i < n; i++) {
      cands.add(mkPerson((hasT('noble')
              ? -.5
              : biz.length > 4
                  ? .5
                  : 0) +
          net * .1 +
          (culture == 'merit' ? .3 : 0)));
    }
    for (final p in staff) {
      if (p.partner && pre > 0) p.loy = math.min(99, p.loy + .17);
    }
    // 記録
    q++;
    if (q > 12) {
      q = 1;
      year++;
    }
    turn++;
    if (q % 3 == 1) holdMeeting(N);
    moneyChecks(N);
    dealsMonthly(N);
    dirtyMonthly(N);
    rivalReturns(N);
    storyMonthly(N);
    rivalScenes(N);
    localMonthly(N);
    countryMonthly(N);
    crisisMonthly();
    // 任せた事業の責任者が、新しい月の手を打つ（任せた事業が無ければ乱数も使わない）
    if (over == null) delegMonthly();
    if (noncomp != null && turn >= noncomp!.until) {
      noncomp = null;
      N(M('売ったときの「同じ業種に入らない」約束の期限が切れました'));
    }
    calcAll();
    for (final b in biz) {
      b.rh.add(b.rev);
      if (b.rh.length > 13) b.rh.removeAt(0);
    }
    hist.add(HistEntry(t: '$year-$q', cap: cap, rev: rev, cash: cash, pre: pre));
    if (hist.length > 1200) hist.removeAt(0);
    // 社長の時間と体力（使った時間で体力が動き、新しい月の時間に戻る）
    monthHours(N);
    rest = 0;
    for (final k in kids) {
      if (k.age < 22 && q == 1) {
        for (final a in abKeys) {
          k.ab[a] = math.min(99, k.ab[a]! + ri(0, 2));
        }
      }
    }
    // シナジー発見
    final own = <String>{for (final b in biz) b.ind};
    for (final c in subs()) {
      for (final b in c.biz) {
        own.add(b.ind);
      }
    }
    for (final s in syns) {
      if (own.contains(s.a) && own.contains(s.b) && found[s.k] == null) {
        found[s.k] = year;
        N(M('シナジー発見！「{0}」×「{1}」＝{2}。両方の事業の力が2割上がります', [I(s.a), I(s.b), D(s.ja)]), 'big');
      }
    }
    for (final g in bigs) {
      if (g.set.every(own.contains) && big[g.k] == null) {
        big[g.k] = year;
        N(M('大シナジー「{0}」が完成！3つの事業の力が4割上がります', [D(g.ja)]), 'big');
      }
    }
    // 勝ち負け
    final rk = rankList();
    final me = rk.indexWhere((x) => x.me) + 1;
    rank = me;
    peakRank = math.min(peakRank, me);
    if (over == null && won == null) {
      if (mode == 'world' && me == 1) won = M('{0}年、世界の企業ランキングで1位になりました', [year]);
      if (mode == 'quad' && cap + wealth >= 1e15) won = M('{0}年、グループの時価総額が1000兆円に届きました（創業から{1}年）', [year, year - startYear]);
    }
    final rivMax = sh.rivMax;
    if (rivMax > 50 && over == null) {
      over = M('宿敵に株の過半数を握られ、社長の座を追われました');
      if (extras) {
        final top = sh.riv.entries.where((e) => e.value == rivMax).firstOrNull;
        final c = coById(top?.key);
        if (c != null) storyEnd(c, 'boughtBy');
      }
    }
    boardMonthly();
    // 社史（記録だけ。乱数は使わない）
    for (final th in rankMarks) {
      if (peak0 > th && peakRank <= th) {
        chron('rank', th == 1 ? M('世界の企業ランキングで1位になった') : M('世界の企業ランキングで初めて{0}位以内に入った（{1}位）', [th, me]));
        break;
      }
    }
    if (won != null && won != won0) chron('won', won!);
    if (over != null && over != over0) chron('over', over!);
    trackPeaks();
    // 実績（記録だけ。乱数は使わない。extras を切ると何もしない）
    for (final a in achCheck()) {
      N(M('実績「{0}」を達成しました', [D(a.nJa)]), 'big');
    }
    lastNews = news;
    log.addAll(news.map((x) => LogEntry(x.m, x.t, year, q)));
    if (log.length > 300) log.removeRange(0, log.length - 300);
    // 新しく来た人・年代をまたいだ人・代替わりした宿敵に顔を割り当てる（乱数は使わない）
    ensureFaces();
    return news;
  }

  void rebirth() {
    chron('rebirth', M('会社が倒産した。残った人脈で、もう一度ゼロから始めた'));
    biz = [];
    staff = [];
    cash = 1e7 * nom();
    loans = [];
    bankCtl = 0;
    missed = 0;
    bankDone = false;
    listed = false;
    sh = Shares();
    region = 0;
    for (final c in cos) {
      c.stakePlayer = 0;
      if (c.parent == 'player') c.parent = null;
    }
  }

  void presDies(void Function(String, [String]) N) {
    Person? s;
    if (succ != null) {
      s = staffById(succ) ?? kids.where((k) => k.id == succ && k.age >= 20).firstOrNull;
    }
    final old = pres.name;
    if (s != null) {
      takeOver(s);
      N(M('{0}が亡くなりました。遺言どおり、{1}が社長を継ぎました', [Nm(old), Nm(s.name)]), 'big');
    } else {
      final cand = staff.where((p) => p.age < 65).toList()..ssort((a, b) => Game.totOf(b) - Game.totOf(a));
      final best = cand.firstOrNull ?? kids.where((k) => k.age >= 20).firstOrNull ?? staff.firstOrNull;
      if (best != null) {
        takeOver(best);
        N(M('{0}が急死。後継ぎが決まっておらず、{1}が急きょ社長になりました', [Nm(old), Nm(best.name)]), 'bad');
      } else {
        over = M('{0}が亡くなり、会社を継ぐ人がいませんでした', [Nm(old)]);
      }
    }
  }

  void takeOver(Person p) {
    if (p.partner && p.stake != 0) {
      sh.own += p.stake;
      sh.pt = math.max(0, sh.pt - p.stake);
      p.partner = false;
      p.stake = 0;
    }
    staff.remove(p);
    kids.remove(p);
    for (final b in biz) {
      if (b.mgr == p.id) b.mgr = null;
    }
    final keep = pres.traits.where((t) => t == 'noble').toList();
    final t2 = TRAITS.any((t) => t.id == p.trait) ? p.trait : pick(TRAITS).id;
    chron('pres', M('{0}から{1}（{2}歳）へ社長が替わった（{3}代目）', [Nm(pres.name), Nm(p.name), p.age, gen + 1]));
    pres = President(name: p.name, age: p.age, ab: {...p.ab}, traits: <String>{t2, ...keep}.take(2).toList(), face: p.face, fb: p.fb);
    if (pres.traits.length < 2) {
      final o = pick(TRAITS.where((t) => !pres.traits.contains(t.id)).toList());
      pres.traits.add(o.id);
    }
    succ = null;
    gen = gen + 1;
  }

  double smallBonus(Biz b) => 1 + 1.4 * math.exp(-b.rev * 3 / (8e7 * nom()));

  double sellValue(Biz b) {
    final held = b.age >= 24;
    return math.max(0, math.max(math.min(b.profit * 12 * 4, b.power * (held ? 2 : .7)), b.power * .15)) * perMul;
  }

  // ===== 宿敵 =====
  void rivalAI(void Function(String, [String]) N) {
    for (final c in cos.toList()) {
      if (!c.alive || c.rival == null || c.parent == 'player') continue;
      final r = c.rival!;
      // 乗っ取り
      if (listed && (r.type == 'fund' || (r.type == 'peer' && c.rel < 0) || (r.type == 'zaibatsu' && c.rel < -40))) {
        var want = r.type == 'fund'
            ? (cap < c.cap * 1.5 ? .12 : .033)
            : .05;
        if (hasT('noble')) want *= 1.5;
        if (hasT('liar')) want *= .5;
        want *= dif.t;
        final afford = c.cash / math.max(cap / 100, 1);
        if (rnd() < want && sh.float > 0.5 && afford > 1) {
          final before = sh.riv[c.id] ?? 0;
          final buy = math.min(math.min(sh.float, ri(1, 4) * (r.type == 'fund' ? 1.3 : 1)), afford);
          sh.float -= buy;
          sh.riv[c.id] = before + buy;
          c.cash -= buy * cap / 100;
          final now = sh.riv[c.id]!;
          for (final th in const [5.0, 20.0, 33.4, 50.0]) {
            if (before < th && now >= th) {
              final k = '${c.id}:${jsNum(th)}';
              if (reported[k] == null) {
                reported[k] = 1;
                tieRec(c, 'h', M('あなたの株を{0}まで買い集められた', [pct(now)]));
                events.add(evHostile(c, th));
              }
            }
          }
        }
      }
      // 値下げ合戦
      final mine = <String>{for (final b in biz) b.ind};
      final shared = c.biz.where((b) => mine.contains(b.ind)).toList();
      final warable = shared.where((b) {
        final my = biz.where((x) => x.ind == b.ind).firstOrNull;
        return my != null && my.war == 0 && !inAssoc(b.ind) && my.share >= (r.type == 'peer' ? .005 : .02);
      }).toList();
      // 恨みが多いと仕掛けてきやすく、恩が多いと控える（張り合う段だけ。extras を切ると 1 をかけるだけ）
      if (warable.isNotEmpty &&
          rnd() <
              (r.type == 'peer'
                      ? .06
                      : r.type == 'zaibatsu'
                          ? .017
                          : .027) *
                  tieMood(r)) {
        final b = pick(warable);
        final my = biz.firstWhere((x) => x.ind == b.ind);
        b.power *= 1.15;
        my.war = 9;
        c.rel -= 5;
        tieRec(c, 'h', M('「{0}」で値下げ合戦を仕掛けられた', [I(b.ind)]));
        N(M('{0}（{1}）が「{2}」で値下げ合戦を仕掛けてきました。9か月のあいだ利益が削られます', [Nm(c.presName), Nm(c.name), I(b.ind)]), 'bad');
      }
      // 同期は真似して追ってくる
      if (r.type == 'peer' && rnd() < .04) {
        final cand = biz.where((b) => !c.biz.any((x) => x.ind == b.ind)).toList();
        if (cand.isNotEmpty) {
          final b = pick(cand);
          c.biz.add(CoBiz(ind: b.ind, power: b.power * .6));
          N(M('{0}が、あなたの後を追って「{1}」に参入しました', [Nm(c.presName), I(b.ind)]), 'bad');
        }
      }
      // 引き抜き
      // （1.1.0+27 から、給料が相場より低い人も狙われる。休んでいる人は狙われない）
      final tgt = staff
          .where((p) => ((p.amb > 60 && p.loy < 55) || (underpaid(p) && p.amb > 45 && p.loy < 65)) && p.away == 0 && !events.any((e) => e.poach == p.id))
          .toList();
      if (tgt.isNotEmpty && rnd() < .027) {
        final p = pick(tgt);
        final e = evPoach(c, p);
        e.poach = p.id;
        tieRec(c, 'h', M('部下の{0}を引き抜かれかけた', [Nm(p.name)]));
        events.add(e);
      }
      // 代替わり
      if (c.presAge > 72 && rnd() < .05) {
        final old = c.presName;
        c.presName = heirName(c.presName, r.k);
        c.presAge = ri(32, 45).toDouble();
        c.rel = rnd() < .5 ? c.rel : 0;
        for (final b in c.biz) {
          b.power *= .85;
        }
        N(M('{0}の{1}が引退し、息子・娘の{2}が継ぎました。代替わりで隙ができています', [Nm(c.name), Nm(old), Nm(c.presName)]), 'big');
      }
      // 提携の申し出
      if (c.rel > 25 && rnd() < .02 * tieWarm(r)) events.add(evAlliance(c));
    }
    // ファンドは株価が上がると売り抜ける
    for (final id in sh.riv.keys.toList()) {
      final c = coById(id);
      if (c != null && c.rival != null && c.rival!.type == 'fund' && g > .3 && rnd() < .07 && sh.riv[id]! > 0) {
        final sell = sh.riv[id]! * .5;
        sh.riv[id] = sh.riv[id]! - sell;
        sh.float += sell;
        N(M('{0}が、値上がりしたあなたの会社の株を半分売り抜けました', [Nm(c.name)]), 'good');
      }
    }
  }

  // ===== 出来事（選ぶもの） =====
  GameEvent evHostile(Company c, double th) {
    final r = c.rival!;
    final x = math.min(sh.float, 8.0);
    return GameEvent(
        who: c,
        face: r.col,
        title: M(th >= 50 ? '過半数を握られた' : '株を買い集められている'),
        text: M(
            th >= 33.4
                ? '{0}（{1}・{2}）が、あなたの会社の株を{3}まで買い集めました。33.4%を超えたので、合併などの大事な決定を止められます。50%を超えられると、社長の座を追われます。'
                : '{0}（{1}・{2}）が、あなたの会社の株を{3}まで買い集めました。50%を超えられると、社長の座を追われます。',
            [Nm(c.presName), Nm(c.name), D(RTYPE.ja[r.label ?? r.type] ?? ''), pct(sh.riv[c.id] ?? 0)]),
        choices: [
          Choice(M('自社株買いで市場の株を減らす'), M('市場の株を{0}買い戻す。費用は時価総額の約{1}%。相手の割合も少し上がる', [pct(x), jsNum(jsRound(x * 1.15))]),
              () => doBuyback(math.min(sh.float, 8))),
          Choice(M('ホワイトナイトに頼む'), M('味方の会社に市場の株を10%持ってもらう。見返りに相手の株5%を買う'), () => doWhiteKnight()),
          Choice(M('新しい株を出して薄める'), M('味方に新しい株を15%分渡し、相手の割合を薄める。自分の割合も下がる'), () => doDilute()),
          Choice(M('様子を見る'), M('何もしない。お金も手も使わない'), () {
            c.rel -= 5;
            return M('様子を見ることにしました');
          }),
        ]);
  }

  GameEvent evPoach(Company c, Person p) => GameEvent(
          who: c,
          face: c.rival!.col,
          title: M('引き抜きの誘い'),
          text: M('{0}が、あなたの部下の{1}を高い給料で誘っています。{1}は迷っているようです。', [Nm(c.presName), Nm(p.name)]),
          choices: [
            Choice(M('給料を1.5倍にして引き留める'), M('毎月の給料が{0}増える', [Y(p.salary * .5)]), () {
              p.salary *= 1.5;
              p.loy += 25;
              p.ambKnown = true;
              return M('{0}は残ってくれました', [Nm(p.name)]);
            }),
            Choice(M('送り出す'), M('{0}は{1}へ移り、相手の事業が強くなる', [Nm(p.name), Nm(c.name)]), () {
              fire(p, 'poached');
              for (final b in c.biz) {
                b.power *= 1.05;
              }
              c.rel -= 3;
              tieRec(c, 'f', M('部下の{0}を送り出した', [Nm(p.name)]));
              return M('{0}は{1}へ移りました', [Nm(p.name), Nm(c.name)]);
            }),
          ]);

  GameEvent evAlliance(Company c) => GameEvent(
          who: c,
          face: c.rival!.col,
          title: M('提携の申し出'),
          text: M('{0}（{1}）から提携の申し出です。組めば、互いに株を5%ずつ持ち合います。', [Nm(c.presName), Nm(c.name)]),
          choices: [
            Choice(M('組む'), M('相手の株5%を{0}で買う。相手も5%持つが、乗っ取りには使わない', [Y(c.cap * .05)]), () {
              if (cash < c.cap * .05) return M('お金が足りず、提携は流れました');
              cash -= c.cap * .05;
              c.stakePlayer = c.stakePlayer + 5;
              sh.ally += math.min(5, sh.float);
              sh.float = math.max(0, sh.float - 5);
              c.rel += 20;
              if (extras && c.rival != null) c.rival!.allied = true;
              tieRec(c, 'f', M('提携の申し出を受けて組んだ'));
              return M('{0}と提携しました', [Nm(c.name)]);
            }),
            Choice(M('断る'), M('相手は少し機嫌を損ねる'), () {
              c.rel -= 15;
              tieRec(c, 'g', M('提携の申し出を断った'));
              return M('提携を断りました');
            }),
          ]);

  GameEvent evPartnerLeave(Person p) => GameEvent(
          title: M('相棒が独立を言い出した'),
          text: M('{0}が「自分の会社を持ちたい」と言い出しました。創業から一緒にやってきた相棒です。株を{1}持っています。', [Nm(p.name), pct(p.stake)]),
          choices: [
            Choice(M('株を5%足して引き留める'), M('あなたの持ち株が5%減る（今 {0}）', [pct(sh.own)]), () {
              if (sh.own < 45) return Cat([M('持ち株が足りず、引き留められませんでした'), partnerOut(p)], ja: '。', en: '. ');
              sh.own -= 5;
              p.stake += 5;
              sh.pt = sh.pt + 5;
              p.loy += 30;
              p.ambKnown = true;
              return M('{0}は残ってくれました。持ち株は{1}になりました', [Nm(p.name), pct(p.stake)]);
            }),
            Choice(M('送り出す'), M('相棒の株は会社の外に残る'), () => partnerOut(p)),
          ]);

  String partnerOut(Person p) {
    final st = p.stake;
    fire(p);
    chron('partner_out', M('相棒の{0}が会社を去った', [Nm(p.name)]));
    return M(listed ? '{0}は会社を去りました。持っていた株{1}は市場で売られました' : '{0}は会社を去りました。持っていた株{1}は投資家の手に渡りました', [Nm(p.name), pct(st)]);
  }

  void rollEvents(void Function(String, [String]) N) {
    for (final p in staff) {
      if (p.partner && p.amb > 65 && p.loy < 50 && rnd() < .02 && !events.any((e) => e.pl == p.id)) {
        final e = evPartnerLeave(p);
        e.pl = p.id;
        events.add(e);
      }
    }
    // 不祥事
    if (biz.isNotEmpty &&
        rnd() <
            (.017 + (staff.any((p) => p.trait == 'liar') ? .017 : 0)) *
                (culture == 'sports'
                    ? 1.5
                    : culture == 'steady'
                        ? .5
                        : 1)) {
      final b = pick(biz);
      final liar = staff.where((p) => p.trait == 'liar').firstOrNull;
      final what = pick(const ['品質の偽装', '帳簿のごまかし', '長時間労働', '顧客情報の流出']);
      events.add(GameEvent(
          title: M('不祥事が発覚'),
          text: Cat([
            M('「{0}」で{1}が見つかりました。', [I(b.ind), M(what)]),
            if (liar != null && !liar.traitKnown) M('どうやら火元は{0}のようです。', [Nm(liar.name)]),
          ]),
          choices: [
            Choice(M('謝罪会見を開く'), M('{0}をかけて謝る。事業の力が1割落ちる', [Y(math.max(b.rev * .1, 1e6))]), () {
              cash -= math.max(b.rev * .1, 1e6);
              b.power *= hasT('careful') ? .95 : .9;
              if (liar != null) liar.traitKnown = true;
              return M('謝罪し、騒ぎは収まりました');
            }),
            Choice(M('もみ消す'), M('お金はかからない。ばれると事業の力が3割5分落ち、株価も下がる。うまくいっても、火種は残る'), () {
              if (rnd() < .5) {
                b.power *= hasT('careful') ? .8 : .65;
                scandal = 12;
                return M('もみ消しがばれ、大炎上しました');
              }
              buried.add(turn + ri(24, 60));
              return M('うまくもみ消せました。ただ、火種は残っています');
            }),
          ]));
    }
    // 天才社員の売り込み
    if (rnd() < .02) {
      final p = mkPerson(1.6);
      p.salary *= 2.5;
      events.add(GameEvent(
          title: M('大物の売り込み'),
          text: M('業界で名の知れた{0}（{1}歳）が、あなたの会社で働きたいと言ってきました。腕は確かと評判ですが、給料の要求も高い。', [Nm(p.name), p.age]),
          choices: [
            Choice(M('雇う'), M('毎月の給料は{0}。手は使わない', [Y(p.salary)]), () {
              staff.add(p);
              return M('{0}が入社しました', [Nm(p.name)]);
            }),
            Choice(M('断る'), M('相手はライバルに流れるかもしれない'), () {
              final c = pickOr(cos.where((x) => x.alive && x.rival != null).toList());
              if (c != null) {
                for (final b in c.biz) {
                  b.power *= 1.03;
                }
              }
              return M('断りました');
            }),
          ]));
    }
    // 労働組合
    if (staff.length >= 3 && rnd() < .017) {
      events.add(GameEvent(title: M('労働組合の要求'), text: M('社員の代表が、給料を1割上げてほしいと言ってきました。'), choices: [
        Choice(M('給料を上げる'), M('毎月の人件費が1割増える。皆の忠誠が上がる'), () {
          for (final p in staff) {
            p.salary *= 1.1;
            p.loy += 10;
          }
          return M('給料を上げました');
        }),
        Choice(M('断る'), M('全事業の力が5%落ちる'), () {
          for (final b in biz) {
            b.power *= .95;
          }
          for (final p in staff) {
            p.loy -= 8;
          }
          return M('要求を断りました');
        }),
      ]));
    }
    // 部下の独立
    final star = staff.where((p) => p.amb > 78 && Game.totOf(p) > 250 && p.tenure > 24 && biz.any((b) => b.mgr == p.id)).firstOrNull;
    if (star != null && rnd() < .017) {
      final b = biz.firstWhere((x) => x.mgr == star.id);
      star.ambKnown = true;
      events.add(GameEvent(
          title: M('独立したい'),
          text: M('「{0}」を任せている{1}が、自分の会社を作りたいと言ってきました。腕が良いぶん、敵に回すと手強い相手です。', [I(b.ind), Nm(star.name)]),
          choices: [
            Choice(M('出資して送り出す'), M('{0}を出資し、新しい会社の株を30%持つ。事業の力は1割5分落ちる', [Y(b.rev * .5)]), () {
              final cost = b.rev * .5;
              if (cash < cost) return M('お金が足りず、出資できませんでした');
              cash -= cost;
              final c = mkCo(0, indm[b.ind]!.cat, presName: star.name, fam: 50);
              c.biz.add(CoBiz(ind: b.ind, power: b.power * .25));
              c.stakePlayer = 30;
              c.rel = 40;
              c.g = .02;
              b.power *= .85;
              fire(star);
              return M('{0}は{1}を立ち上げました。株の30%はあなたのものです', [Nm(star.name), Nm(c.name)]);
            }),
            Choice(M('給料を倍にして引き留める'), M('毎月の給料が{0}増える。野心は消えない', [Y(star.salary)]), () {
              star.salary *= 2;
              star.loy += 15;
              star.amb -= 10;
              return M('{0}は残ってくれました。ただ、いつかまた言い出すかもしれません', [Nm(star.name)]);
            }),
            Choice(M('黙って見送る'), M('お金はかからない。同じ業種に手強い会社が生まれる'), () {
              final rv = Rival(k: 'ex${uid()}', pres: star.name, co: '', type: 'peer', label: 'ex', tier: 0, col: '#ffb454');
              final c = mkCo(0, indm[b.ind]!.cat, presName: star.name, fam: 60, rival: rv);
              rv.co = c.name;
              c.presAge = star.age.toDouble();
              // 元部下は同じ顔のまま宿敵になる
              c.pf = star.face;
              c.pfb = star.fb;
              c.pfn = star.name;
              c.biz.add(CoBiz(ind: b.ind, power: b.power * .4));
              c.g = .025;
              c.rel = -20;
              b.power *= .8;
              fire(star);
              return M('{0}は{1}を立ち上げ、あなたの客を奪い始めました', [Nm(star.name), Nm(c.name)]);
            }),
          ]));
    }
    // 大型の受注
    if (biz.isNotEmpty && rnd() < .017) {
      final b = pick(biz);
      events.add(GameEvent(title: M('大型の受注'), text: M('「{0}」に、大口の取引の話が来ました。受ければ一気に伸びますが、現場はかなり無理をします。', [I(b.ind)]), choices: [
        Choice(M('受ける'), M('事業の力が1割5分上がる。部下全員の忠誠が下がる'), () {
          b.power *= 1.15;
          for (final p in staff) {
            p.loy -= 8;
          }
          return M('受注しました。現場は大忙しです');
        }),
        Choice(M('断る'), M('何も起きない'), () => M('見送りました')),
      ]));
    }
    // 社長の病気
    if (pres.age > 50 && rnd() < .01) {
      events.add(GameEvent(title: M('社長の体調'), text: M('{0}が倒れました。医者は「しばらく休むように」と言っています。', [Nm(pres.name)]), choices: [
        Choice(M('休む'), M('来月は社長の時間が半分になる'), () {
          rest = 1;
          return M('しばらく休むことにしました');
        }),
        Choice(M('働き続ける'), M('時間は減らない。3割の確率で能力が大きく落ちる'), () {
          if (rnd() < .3) {
            for (final k in abKeys) {
              pres.ab[k] = math.max(5, pres.ab[k]! - 10);
            }
            return M('無理がたたり、能力が落ちてしまいました');
          }
          return M('なんとか持ちこたえました');
        }),
      ]));
    }
    // 宿敵からの買い取りの申し出
    final buyer = cos.where((c) => c.alive && c.rival != null && c.parent != 'player' && c.cash > 0).firstOrNull;
    if (buyer != null && biz.length > 1 && rnd() < .013) {
      final b = pick(biz);
      final price = sellValue(b) * 1.5;
      events.add(GameEvent(
          who: buyer,
          face: buyer.rival!.col,
          title: M('事業を売ってほしい'),
          text: M('{0}が、あなたの「{1}」を相場の1.5倍、{2}で買いたいと言っています。', [Nm(buyer.presName), I(b.ind), Y(price)]),
          choices: [
            Choice(M('売る'), M('{0}が入る。その事業は相手のものになる', [Y(price)]), () {
              cash += price;
              buyer.biz.add(CoBiz(ind: b.ind, power: b.power));
              biz.remove(b);
              buyer.rel += 15;
              tieRec(buyer, 'f', M('「{0}」を売り渡した', [I(b.ind)]));
              return M('「{0}」を{1}に売りました', [I(b.ind), Nm(buyer.name)]);
            }),
            Choice(M('断る'), M('相手は機嫌を損ねる'), () {
              buyer.rel -= 10;
              return M('断りました');
            }),
          ]));
    }
    // 株主総会
    final h4 = hist.length >= 12 ? hist[hist.length - 12] : null;
    if (listed && sh.own < 50 && h4 != null && pre < h4.pre * .8 && rnd() < .08) {
      events.add(GameEvent(title: M('荒れる株主総会'), text: M('利益が落ちたことに、株主が怒っています。「社長は責任を取れ」という声も出ています。'), choices: [
        Choice(M('配当を増やして鎮める'), M('{0}を株主に配る', [Y(extras ? meetingDividend() : math.max(cash * .1, 0))]), () {
          if (!extras) {
            cash *= .9;
            return M('配当を増やし、総会は収まりました');
          }
          return Cat([M('配当を増やし、総会は収まりました'), ?payOut(meetingDividend())], ja: '。', en: '. ');
        }),
        Choice(M('強気で押し切る'), M('お金はかからない。4割の確率で株価が下がり、市場の信用を失う'), () {
          if (rnd() < .4) {
            scandal = 12;
            return M('反発を招き、株価が下がりました');
          }
          return M('どうにか押し切りました');
        }),
      ]));
    }
    // 好景気の不動産話
    if (econ > 1.1 && rnd() < .05 && cash > 0) {
      events.add(GameEvent(title: M('銀行からの儲け話'), text: M('取引のある銀行が「土地を買えば必ず上がります。お金はいくらでも貸します」と言っています。'), choices: [
        Choice(M('借りて土地を買う'), M('{0}を借りて土地に回す。景気が続けば大きく増え、崩れれば借金だけが残る', [Y(cash)]), () {
          final a = math.max(cash, 1e7);
          loanFromEvent(a);
          land = land + a;
          return M('土地を買いました');
        }),
        Choice(M('断る'), M('何も起きない'), () => M('断りました')),
      ]));
    }
    // 土地の値動き
    if (land > 0) {
      land *= econ > 1.1
          ? 1.02
          : econ < .95
              ? .96
              : 1.0017;
      if (rnd() < .0001) land = 0;
    }
  }

  /// 部下が会社を去る。[why] は社外に残すときの理由（quit 辞めた / poached 引き抜かれた / fired 解雇 / retired 引退）
  void fire(Person p, [String why = 'quit']) {
    if (extras && staff.contains(p)) toAlumni(p, why);
    if (p.partner && p.stake != 0) {
      sh.pt = math.max(0, sh.pt - p.stake);
      if (listed) {
        sh.float += p.stake;
      } else {
        sh.vc += p.stake;
      }
      p.stake = 0;
      p.partner = false;
    }
    staff.remove(p);
    for (final b in biz) {
      if (b.mgr == p.id) {
        b.mgr = null;
        if (p.trait == 'oneman') b.power *= .7;
      }
    }
    if (succ == p.id) succ = null;
  }

  void finishPipe(Biz b, Pipe x, void Function(String, [String]) N) {
    final name = I(b.ind);
    if (finishUnitPipe(b, x, N)) return;
    if (x.k == 'enter') {
      addCtry(b, x.c!, x.mode!, x.pw ?? x.cost);
      N(M(x.mode == 'jv' ? '「{0}」が{1}で始まりました（地元の会社と組んで）' : '「{0}」が{1}で始まりました', [name, C(x.c!)]), 'good');
      return;
    }
    if (x.k == 'build') {
      var eff = pipeEff(b, x.cost) * (b.model == 'fc' ? 1.3 : 1);
      if (hasT('gambler') && rnd() < .2) eff *= .3;
      b.power += x.cost * eff;
      b.upkeep = b.upkeep + x.cost * .006;
      // 1.1.0+26 から、広げる手は改装（今ある単位の売上の倍が上がる）
      if (x.ext && unitsOn) b.upg = math.min(upgMax, b.upg + upgStep);
      // 広げたぶんは「新しい店が開いた」とは言わない（増やしたのと区別がつかなかった。1.0.0+18）
      N(M(x.ext ? '「{0}」の{1}を広げ終わりました' : '「{0}」の新しい{1}が開きました', [name, uw(b)]), 'good');
      return;
    }
    final p = staffById(b.mgr);
    final kai = p != null ? p.ab['kai']! : pres.ab['kai']!;
    final hit = .08 + (culture == 'free' ? .08 : 0) + kai / 1000 + (hasT('genius') ? .08 : 0) + (hasT('tech') ? .05 : 0);
    final miss = math.max(.08, .3 - kai / 500);
    final r = rnd();
    double m;
    String msg;
    if (r < hit) {
      m = 4 + rnd() * 3;
      msg = M('大当たり！「{0}」の新商品が爆発的に売れています', [name]);
    } else if (r < hit + miss) {
      m = .15;
      msg = M('「{0}」の新商品は不発に終わりました', [name]);
    } else {
      m = 1.3;
      msg = M('「{0}」の新商品が出ました。評判はまずまずです', [name]);
    }
    // 単位で作った商品は、大きいほど当たったときの伸びが大きい
    if (x.sz != null && m > 2) m *= devHitMul[x.sz!];
    if (hasDeal('codev', indm[b.ind]!.cat)) m *= 1.5;
    b.power += x.cost * pipeEff(b, x.cost) * m * (b.model == 'fc' ? .6 : 1);
    N(
        msg,
        m > 2
            ? 'big'
            : m < .5
                ? 'bad'
                : 'good');
    final pp = staffById(x.by);
    if (pp != null && m < .5) {
      events.add(GameEvent(title: M('提案が外れた'), text: M('{0}の提案で作った「{1}」の新商品は不発でした。責任をどう取らせますか。', [Nm(pp.name), name]), choices: [
        Choice(M('責任者から外す'), M('忠誠が大きく下がる'), () {
          for (final bb in biz) {
            if (bb.mgr == pp.id) bb.mgr = null;
          }
          pp.loy -= 15;
          return M('{0}を責任者から外しました', [Nm(pp.name)]);
        }),
        Choice(M('そのまま任せる'), M('忠誠が上がる'), () {
          pp.loy += 10;
          return M('{0}に「次で取り返せ」と伝えました', [Nm(pp.name)]);
        }),
      ]));
    }
    if (pp != null && m > 2) pp.loy = math.min(99, pp.loy + 8);
  }

  // ===== 経営会議 =====
  Proposal? proposalFor(Person p) {
    final b = biz.where((x) => x.mgr == p.id).firstOrNull;
    if (b == null) return null;
    if (extras) return _unitProposal(p, b);
    final ind = indm[b.ind]!;
    final t = p.trait;
    final bigF = t == 'gambler'
        ? .5
        : t == 'careful'
            ? .12
            : .25;
    final cost = cash * bigF;
    final opts = <Proposal>[];
    if (crewEff(b) < crewWant(b) * .95) {
      opts.add(Proposal(k: 'crew', w: 3, cost: cash * .15, l: M('「{0}」の現場の人を増やしたい', [I(ind.id)]), d: M('今のままでは{0}の一部が止まっています', [uw(b)])));
    }
    opts.add(Proposal(k: 'build', w: t == 'careful' ? 1 : 2, cost: cost, l: M('「{0}」の{1}を増やしたい', [I(ind.id), uw(b)]), d: M('客は来ています。広げれば確実に伸びます')));
    opts.add(Proposal(k: 'dev', w: t == 'tech' || t == 'genius' ? 4 : 1, cost: cost, l: M('「{0}」で新しい商品を作りたい', [I(ind.id)]), d: M('当たれば大きい。外れるかもしれません')));
    if ((p.amb > 65 || t == 'gambler') && b.price != 'cut') {
      opts.add(Proposal(k: 'cut', w: 2, cost: 0, l: M('「{0}」で値下げして客を奪いたい', [I(ind.id)]), d: M('利益は薄くなりますが、シェアを取りに行きます')));
    }
    if (t == 'frugal' && b.upkeep > 0) opts.add(Proposal(k: 'trim', w: 3, cost: 0, l: M('「{0}」の維持費を削りたい', [I(ind.id)]), d: M('維持費が2割減ります。現場は少し弱ります')));
    if (p.partner) opts.add(Proposal(k: 'newbiz', w: 2, cost: 0, l: M('新しい事業を始めたい'), d: M('自分で立ち上げて、責任者をやります')));
    final tot = opts.fold(0, (s, o) => s + o.w);
    var r = rnd() * tot;
    var o = opts[0];
    for (final x in opts) {
      r -= x.w;
      if (r <= 0) {
        o = x;
        break;
      }
    }
    o = o.copy();
    if (o.k == 'newbiz') {
      final cs = liveInds().where((i) => !biz.any((x) => x.ind == i.id) && capexOf(i) <= cash * .6 && i.cat == ind.cat).toList();
      if (cs.isEmpty) return null;
      final ni = pick(cs);
      o.ind = ni.id;
      o.cost = capexOf(ni);
      o.l = M('新しく「{0}」を始めたい', [I(ni.id)]);
    }
    if ((o.k == 'build' || o.k == 'dev' || o.k == 'crew') && o.cost < capexOf(ind) * .05) return null;
    o.by = p.id;
    o.bid = b.id;
    return o;
  }

  /// 経営会議の提案を1単位の手で作る（extras のとき）。部下の特性で大きさが変わる。
  /// 博打打ちは10店・大型開発・人も50人から、慎重は1店・小さな改良、ほかは3店・新商品。払えなければ1段ずつ小さくし、どれも払えない案は出さない
  Proposal? _unitProposal(Person p, Biz b) {
    final ind = indm[b.ind]!;
    final t = p.trait;
    final bigI = t == 'gambler'
        ? 2
        : t == 'careful'
            ? 0
            : 1;
    final opts = <Proposal>[];
    // 任せた事業の責任者は、自分で打てる手（人・店や工場・商品・広告・値付け）を会議に持ってこない（毎月、自分で打つ。1.0.0+20）。
    // 社長が決めること（海外・稼ぎ方・撤退・社風・新しい事業・維持費を削る）だけを提案する
    final self = delegated(b);
    final need = self ? 0 : crewNeedPeople(b);
    if (need > 0) {
      var n = t == 'gambler' ? math.max(need, crewUnits.last) : need;
      if (hireCost(b, n) > cash) n = need;
      if (hireCost(b, n) <= cash) {
        opts.add(Proposal(
            k: 'crew',
            w: 3,
            cost: hireCost(b, n),
            l: M('「{0}」の現場の人を{1}人増やしたい', [I(ind.id), n]),
            d: M('今のままでは{0}の一部が止まっています。毎月の人件費が{1}増えます', [uw(b), Y(payPerMonth(b, n))]))
          ..n = n);
      }
    }
    // 1.1.0+26 から、店などを増やす提案は、今いちばん要る伸ばす手（責任者を育てる・本部・拠点・開く）
    final go = self || !unitsOn ? null : growOpt(b, cash * .6, want: buildUnits[bigI]);
    if (go != null) {
      opts.add(Proposal(k: 'grow', w: t == 'careful' ? 1 : 2, cost: go.cost, l: go.l, d: M('客は来ています。広げれば確実に伸びます')));
    }
    final bi = self || unitsOn ? null : [for (var i = bigI; i >= 0; i--) i].where((i) => buildCost(b, buildUnits[i]) <= cash).firstOrNull;
    if (bi != null) {
      final n = buildUnits[bi];
      opts.add(Proposal(k: 'build', w: t == 'careful' ? 1 : 2, cost: buildCost(b, n), l: M('「{0}」で{1}増やしたい', [I(ind.id), unitsOf(b, n)]), d: M('客は来ています。広げれば確実に伸びます'))
        ..n = n);
    }
    final di = self ? null : [for (var i = bigI; i >= 0; i--) i].where((i) => devCost(b, i) <= cash).firstOrNull;
    if (di != null) {
      opts.add(Proposal(
          k: 'dev',
          w: t == 'tech' || t == 'genius' ? 4 : 1,
          cost: devCost(b, di),
          l: M(
              di == 2
                  ? '「{0}」で大型開発をしたい'
                  : di == 0
                      ? '「{0}」で小さな改良をしたい'
                      : '「{0}」で新しい商品を作りたい',
              [I(ind.id)]),
          d: M(di == 2
              ? '時間はかかりますが、当たれば会社が変わります'
              : di == 0
                  ? '今の商品を少し良くします。早く出せます'
                  : '当たれば大きい。外れるかもしれません'))
        ..sz = di);
    }
    if (!self && (p.amb > 65 || t == 'gambler') && b.price != 'cut') {
      opts.add(Proposal(k: 'cut', w: 2, cost: 0, l: M('「{0}」で値下げして客を奪いたい', [I(ind.id)]), d: M('利益は薄くなりますが、シェアを取りに行きます')));
    }
    if (t == 'frugal' && b.upkeep > 0) opts.add(Proposal(k: 'trim', w: 3, cost: 0, l: M('「{0}」の維持費を削りたい', [I(ind.id)]), d: M('維持費が2割減ります。現場は少し弱ります')));
    if (p.partner) opts.add(Proposal(k: 'newbiz', w: 2, cost: 0, l: M('新しい事業を始めたい'), d: M('自分で立ち上げて、責任者をやります')));
    // 提案の種類を足した（1.0.0+19）。中盤の経営会議は提案の半分が「店・工場を増やしたい」（10〜30年目・3本で 51件中25件）だった。
    // 1.0.0+18 で試したときの経緯:
    // ・海外（どの国にも）: 単位の手の自動プレイで、30年後の事業の力の中央値が 7.3兆→18〜19.9兆 に跳ねる → 強すぎるので入れない
    // ・海外（自国だけの事業の最初の1か国だけ）・広告: 単位の手の力は変わらない（7.0〜9.0兆）が、乱数の流れが変わって、
    //   自動プレイの中央値で測っている線（test/fixed_price_test.dart「自動プレイの比べ」・test/polish3_test.dart「難しさ」）のどちらかを外れた
    // 今回は強すぎない方（最初の1か国だけ）で入れた。国ごとの事件・宿敵の場面と合わせて測ると、2本の線はどちらも引き直さずに通った
    // （単位の手の順位の中央値 132位→155位・事業の力 7.28兆→6.09兆、難しさ ふつう 123位→179位。前後の数字は、それぞれのテストの注釈にある）。
    // どれも画面にある手と同じ値段・同じ効き目で、手を使わないだけ
    // 広告（打っていないとき）
    final adC = invBase(b) * .25;
    if (!self && b.ad == 0 && adC <= cash) {
      opts.add(Proposal(k: 'ad', w: t == 'charm' ? 2 : 1, cost: adC, l: M('「{0}」で広告を打ちたい', [I(ind.id)]), d: M('6か月のあいだ客が増えます。終われば元に戻ります')));
    }
    // 海外（始めた国だけの事業の、最初の1か国だけ。払える中で市場がいちばん大きい国）
    if (ctryOf(b).length == 1 && ctryOf(b).first == home && !b.pipe.any((x) => x.k == 'enter')) {
      String? modeOf(String c) {
        final ms = entryModes(b, c);
        return ms.contains('solo') ? 'solo' : ms.firstOrNull;
      }

      final cs = CTRY.where((x) => x.c != home && modeOf(x.c) != null && !hasLocal(x.c, b.ind) && entryCost(b, x.c, modeOf(x.c)!) <= cash).toList()
        ..ssort((p, q) => cw(q.c, yr()).compareTo(cw(p.c, yr())));
      if (cs.isNotEmpty) {
        final c = cs.first.c;
        opts.add(Proposal(
            k: 'abroad',
            w: 2,
            cost: entryCost(b, c, modeOf(c)!),
            l: M('「{0}」を{1}に出したい', [I(ind.id), C(c)]),
            d: M('初めての海外です。{0}で、準備に何か月かかかります', [D(ENTRYN.ja[modeOf(c)!]!)]))
          ..c = c
          ..mode = modeOf(c));
      }
    }
    // 値付けの見直し（値下げを続けて客が付いたら戻す・客をしっかりつかんでいるなら高くする）
    if (self) {
      // 値付けは責任者が自分で直す
    } else if (b.price == 'cut' && b.war == 0 && b.share >= .12 && t != 'gambler') {
      opts.add(Proposal(k: 'price', w: 2, cost: 0, l: M('「{0}」の値下げをやめたい', [I(ind.id)]), d: M('客は付きました。値段をふつうに戻して利益を取ります'))..ind = 'normal');
    } else if (b.price == 'normal' && b.share >= .2 && (t == 'careful' || t == 'frugal' || t == 'tech')) {
      opts.add(Proposal(k: 'price', w: 1, cost: 0, l: M('「{0}」の値段を高くしたい', [I(ind.id)]), d: M('利益は厚くなりますが、客は少し減ります'))..ind = 'premium');
    }
    // 稼ぎ方の変更（3年たっても直営のままで、ほかの稼ぎ方ができる業種）
    final alt = modelsFor(ind.id).where((m) => m != b.model).toList();
    if (b.model == 'direct' && b.age >= 36 && alt.isNotEmpty && (t == 'genius' || t == 'gambler' || p.amb > 70)) {
      final m = alt.first;
      opts.add(Proposal(k: 'model', w: 1, cost: 0, l: M('「{0}」を{1}に切り替えたい', [I(ind.id), D(MODELN.ja[m]!)]), d: M('切り替えの混乱で、力が1割5分落ちます。{0}', [D(MODELD.ja[m]!)]))
        ..ind = m);
    }
    // 撤退（3年たっても赤字で、シェアも小さい）
    if (b.profit < 0 && b.age >= 36 && b.share < .03 && biz.length > 1 && b.pipe.isEmpty) {
      opts.add(Proposal(k: 'exit', w: 3, cost: 0, l: M('「{0}」から手を引きたい', [I(ind.id)]), d: M('3年たっても赤字です。{0}で売って、ほかに回しましょう', [Y(sellValue(b))])));
    }
    // 社風（長く勤めた人が、自分に合う社風を言い出す。10年に一度まで）
    final cu = GameActions._cultOfTrait(t);
    if (cultLeft == 0 && cu != culture && p.tenure >= 36 && turn - (crisis['pc'] ?? -999) >= 120) {
      opts.add(Proposal(k: 'culture', w: 1, cost: 0, l: M('社風を「{0}」に変えたい', [D(CULT[cu]!.nJa)]), d: M('変わるまで2年かかり、その間は人が辞めやすくなります。{0}', [D(CULT[cu]!.gJa)]))
        ..ind = cu);
    }
    if (opts.isEmpty) return null;
    final tot = opts.fold(0, (s, o) => s + o.w);
    var r = rnd() * tot;
    var o = opts[0];
    for (final x in opts) {
      r -= x.w;
      if (r <= 0) {
        o = x;
        break;
      }
    }
    o = o.copy();
    if (o.k == 'newbiz') {
      final cs = liveInds().where((i) => !biz.any((x) => x.ind == i.id) && capexOf(i) <= cash * .6 && i.cat == ind.cat).toList();
      if (cs.isEmpty) return null;
      final ni = pick(cs);
      o.ind = ni.id;
      o.cost = capexOf(ni);
      o.l = M('新しく「{0}」を始めたい', [I(ni.id)]);
    }
    o.by = p.id;
    o.bid = b.id;
    return o;
  }

  String doProposal(Proposal o) {
    final b = biz.where((x) => x.id == o.bid).firstOrNull;
    final p = staffById(o.by);
    if (b == null || p == null) return M('その提案はもう意味がなくなっていました');
    if (o.cost > cash) return M('お金が足りず、提案は実行できませんでした');
    if (o.k == 'crew' && o.n > 0) {
      cash -= o.cost;
      _addHeads(b, o.n);
    } else if (o.k == 'crew') {
      cash -= o.cost;
      b.crew = crewOf(b) + o.cost * 4;
      b.upkeep = b.upkeep + o.cost * .008;
    } else if (o.k == 'dev' && o.sz != null) {
      cash -= o.cost;
      b.pipe.add(Pipe(k: 'dev', cost: o.cost, left: ri(devMonths[o.sz!].$1, devMonths[o.sz!].$2), by: p.id, sz: o.sz));
    } else if (o.k == 'grow') {
      final go = growOpt(b, cash);
      if (go == null) return M('その提案はもう意味がなくなっていました');
      go.run();
    } else if (o.k == 'build' || o.k == 'dev') {
      cash -= o.cost;
      b.pipe.add(Pipe(k: o.k, cost: o.cost, left: o.k == 'dev' ? ri(3, 6) : ri(1, 2), by: p.id));
    } else if (o.k == 'cut') {
      b.price = 'cut';
    } else if (o.k == 'trim') {
      b.upkeep *= .8;
      b.crew = crewOf(b) * .93;
    } else if (o.k == 'ad') {
      cash -= o.cost;
      b.ad = 6;
      b.adCost = 0;
    } else if (o.k == 'abroad') {
      final c = o.c!, mode = o.mode!;
      if (ctryOf(b).contains(c) || b.pipe.any((x) => x.k == 'enter') || !entryModes(b, c).contains(mode)) return M('その提案はもう意味がなくなっていました');
      cash -= o.cost;
      b.pipe.add(Pipe(k: 'enter', c: c, mode: mode, cost: o.cost, pw: o.cost * 1.1 + b.power * cw(c, yr()) / reachOf(b) * .5, left: mode == 'jv' ? 3 : 6));
    } else if (o.k == 'price') {
      b.price = o.ind!;
    } else if (o.k == 'model') {
      if (b.model == o.ind) return M('その提案はもう意味がなくなっていました');
      b.model = o.ind!;
      b.power *= .85;
    } else if (o.k == 'exit') {
      if (biz.length < 2) return M('その提案はもう意味がなくなっていました');
      cash += sellValue(b);
      biz.remove(b);
    } else if (o.k == 'culture') {
      if (cultLeft > 0 || culture == o.ind) return M('その提案はもう意味がなくなっていました');
      cultNext = o.ind;
      cultLeft = 24;
      crisis['pc'] = turn;
    } else if (o.k == 'newbiz') {
      if (biz.any((x) => x.ind == o.ind)) return M('その業種にはもう入っていました');
      cash -= o.cost;
      b.mgr = null;
      final nb = Biz(id: uid(), ind: o.ind!, power: o.cost * newPow, crew: o.cost * newPow * 1.2, mgr: p.id);
      biz.add(nb);
      initUnits(nb, o.cost);
    }
    p.loy = math.min(99, p.loy + 3);
    p.rej = 0;
    calcAll();
    return M('{0}の提案を通しました', [Nm(p.name)]);
  }

  String rejectProposal(Proposal o) {
    final p = staffById(o.by);
    if (p == null) return '';
    p.rej = p.rej + 1;
    p.loy -= p.amb > 65 ? 10 : 6;
    if (p.rej >= 3) p.ambKnown = true;
    return M(p.rej >= 3 ? '{0}の提案を却下しました。不満がたまっているようです' : '{0}の提案を却下しました', [Nm(p.name)]);
  }

  void holdMeeting(void Function(String, [String]) N) {
    final mgrs = staff.where((p) => biz.any((b) => b.mgr == p.id)).toList();
    if (mgrs.isEmpty) return;
    final props = <Proposal>[];
    shuffle(mgrs);
    for (final p in mgrs) {
      if (props.length >= 3) break;
      if (rnd() < (p.partner ? .7 : .5)) {
        final o = proposalFor(p);
        if (o != null) props.add(o);
      }
    }
    if (props.isEmpty) return;
    for (final o in props.where((o) => staffById(o.by)!.auto)) {
      final name = staffById(o.by)!.name;
      N(M('{0}（まかせている）：{1}。{2}', [Nm(name), o.l, doProposal(o)]));
    }
    final restP = props.where((o) => staffById(o.by) != null && !staffById(o.by)!.auto).toList();
    if (restP.length >= 2 && restP[0].cost + restP[1].cost > cash * .6) {
      final a = restP[0], b = restP[1];
      final pa = staffById(a.by)!, pb = staffById(b.by)!;
      String says(Proposal o) => M(o.cost > 0 ? '{0}。{1}（{2}）' : '{0}。{1}', [o.l, o.d, Y(o.cost)]);
      events.add(GameEvent(
          title: M('経営会議：意見がぶつかった'),
          text: M('{0}は「{1}」、{2}は「{3}」と言って譲りません。両方やるお金はありません。', [Nm(pa.name), a.l, Nm(pb.name), b.l]),
          lead: M('二人とも自分の案を譲りません。両方やるお金はありません。'),
          voices: [voiceOf(pa, says(a)), voiceOf(pb, says(b))],
          choices: [
        Choice(M('{0}の案を通す', [Nm(pa.name)]), M('{0}の忠誠が大きく下がる', [Nm(pb.name)]), () {
          pb.loy -= 12;
          pb.rej = pb.rej + 1;
          return doProposal(a);
        }),
        Choice(M('{0}の案を通す', [Nm(pb.name)]), M('{0}の忠誠が大きく下がる', [Nm(pa.name)]), () {
          pa.loy -= 12;
          pa.rej = pa.rej + 1;
          return doProposal(b);
        }),
        Choice(M('どちらも却下する'), M('二人とも不満を持つ'), () => Cat([rejectProposal(a), rejectProposal(b)], ja: '。', en: '. ')),
      ]));
      restP.removeRange(0, 2);
    }
    for (final o in restP) {
      final p = staffById(o.by)!;
      events.add(GameEvent(title: M('経営会議の提案'), person: p, text: M(o.cost > 0 ? '{0}。{1}（{2}）' : '{0}。{1}', [o.l, o.d, Y(o.cost)]), choices: [
        Choice(M('承認する'), M('手は使わない。忠誠が少し上がる'), () => doProposal(o)),
        Choice(M('却下する'), M(p.amb > 65 ? '忠誠が大きく下がる' : '忠誠が下がる'), () => rejectProposal(o)),
        Choice(M('この人に全部まかせる'), M('これからの提案は自動で通す'), () {
          p.auto = true;
          return Cat([doProposal(o), M('これからは任せます')], ja: '。', en: '. ');
        }),
      ]));
    }
  }

  // ===== お金の縛り =====
  void moneyChecks(void Function(String, [String]) N) {
    if (cultLeft > 0) {
      cultLeft--;
      if (cultLeft == 0) {
        culture = cultNext!;
        N(M('社風が「{0}」に変わりました', [D(CULT[culture]!.nJa)]), 'good');
      }
    }
    if (!listed && vcDeadline != 0 && turn >= vcDeadline && sh.vc > 0 && !events.any((e) => e.vc)) {
      final cost = cap * sh.vc / 100 * 1.2;
      events.add(GameEvent(vc: true, title: M('投資家が上場を迫る'), text: M('「3年以内に上場する」という約束の期限が来ました。投資家は株{0}を持っています。', [pct(sh.vc)]), choices: [
        Choice(M('株を買い戻す'), M('{0}を払い、投資家の株をすべて引き取る', [Y(cost)]), () {
          if (cash < cost) return M('お金が足りません。投資家はあと1年だけ待つと言いました');
          cash -= cost;
          sh.own += sh.vc;
          sh.vc = 0;
          vcDeadline = 0;
          return M('投資家の株を買い戻しました');
        }),
        Choice(M('あと1年待ってもらう'), M('投資家に株を5%渡して、期限を1年延ばす'), () {
          final x = math.min(5, sh.own - 30);
          sh.own -= x;
          sh.vc += x;
          vcDeadline = turn + 12;
          return M('期限が1年延びました');
        }),
        Choice(M('社長の座を降りる'), M('投資家が選んだ部下が社長になる'), () {
          final cand = staff.where((p) => p.age < 65).toList()..ssort((a, b) => Game.totOf(b) - Game.totOf(a));
          final best = cand.firstOrNull;
          if (best == null) return M('代わりの人がおらず、投資家は株を市場で売り払いました');
          final old = pres.name;
          takeOver(best);
          vcDeadline = turn + 24;
          return M('{0}は社長を降り、{1}が社長になりました', [Nm(old), Nm(best.name)]);
        }),
      ]));
    }
    if (vcDeadline != 0 && !listed && turn == vcDeadline - 12) N(M('投資家との上場の約束まで、あと1年です'), 'bad');
    if (tie != null) {
      final hit = biz.where((b) => tie!.inds.contains(b.ind)).firstOrNull;
      final c = coById(tie!.co);
      if (hit != null || c == null || !c.alive) {
        if (hit != null && c != null) {
          for (final b in biz) {
            b.power *= .92;
          }
          c.rel -= 30;
          N(M('取引先の{0}が「うちと同じ商売を始めるとは」と怒り、取引を打ち切りました', [Nm(c.name)]), 'bad');
        }
        tie = null;
      }
    }
    if (tie == null && biz.isNotEmpty && rnd() < .008) {
      final c = pickOr(cos.where((x) => x.alive && x.rival == null && x.parent != 'player' && x.tier == 0 && x.cap > cap * 2).toList());
      if (c != null) {
        final money = cap * .12 + 1e7 * nom();
        final inds = c.biz.map((b) => b.ind).toList();
        final cats = <String>{for (final i in inds) indm[i]!.cat}.toList();
        events.add(GameEvent(
            title: M('取引先からの出資の話'),
            text: M('取引のある{0}が「{1}を出資するので、株を8%もらいたい。注文も回します」と言っています。ただし{0}と同じ業種（{2}）に入ると、取引を切られます。',
                [Nm(c.name), Y(money), J(inds.take(4).map(I))]),
            choices: [
              Choice(M('受ける'), M('{0}が入る。同じ分類の事業の力が少し上がる', [Y(money)]), () {
                if (sh.own < 40) return M('持ち株が足りず、話は流れました');
                cash += money;
                sh.own -= 8;
                sh.ally += 8;
                tie = Tie(co: c.id, inds: inds, cats: cats);
                c.rel += 15;
                return M('{0}の出資を受けました', [Nm(c.name)]);
              }),
              Choice(M('断る'), M('何も起きない'), () => M('断りました')),
            ]));
      }
    }
    final burn = math.max(0.0, -pre);
    if (biz.isNotEmpty && cash < burn * 3 + 1e6 && rnd() < .15 && !events.any((e) => e.rivfund)) {
      final c = cos.where((x) => x.alive && x.rival != null && x.parent != 'player' && x.cash > cap * .3).firstOrNull;
      if (c != null) {
        final money = math.max(cap * .25, burn * 12);
        events.add(GameEvent(
            rivfund: true,
            who: c,
            face: c.rival!.col,
            title: M('宿敵からの出資'),
            text: M('{0}が「資金に困っているそうだな。{1}出してやろう。そのかわり株を20%もらう」と言っています。', [Nm(c.presName), Y(money)]),
            choices: [
              Choice(M('受ける'), M('お金は助かるが、宿敵があなたの株を20%持つ'), () {
                cash += money;
                final x = math.min(20.0, sh.own - 10);
                sh.own -= x;
                sh.riv[c.id] = (sh.riv[c.id] ?? 0) + x;
                return M('{0}の出資を受けました。株を{1}握られています', [Nm(c.name), pct(x)]);
              }),
              Choice(M('断る'), M('自力でしのぐ'), () {
                c.rel -= 5;
                return M('断りました');
              }),
            ]));
      }
    }
  }

  void dealsMonthly(void Function(String, [String]) N) {
    for (final d in deals.toList()) {
      final c = coById(d.co);
      if (c == null || !c.alive) {
        deals.remove(d);
        continue;
      }
      if (d.type == 'outsrc' && rnd() < .004) {
        for (final b in biz) {
          if (['make', 'food'].contains(indm[b.ind]!.cat)) b.power *= .92;
        }
        scandal = math.max(scandal, 6);
        N(M('製造を任せていた{0}の工場で不正が見つかりました。こちらの看板に傷がつきました', [Nm(c.name)]), 'bad');
      }
    }
    if (biz.isNotEmpty && rnd() < .008) {
      final cats = <String>{for (final b in biz) indm[b.ind]!.cat};
      final c = pickOr(cos
          .where((x) => x.alive && x.parent != 'player' && x.rel >= 0 && x.biz.any((b) => cats.contains(indm[b.ind]!.cat)) && dealWith(x).isEmpty)
          .toList());
      if (c != null) {
        final type = pick(const ['sales', 'codev', 'outsrc']);
        events.add(GameEvent(
            who: c.rival != null ? c : null,
            face: c.rival?.col,
            title: M('組みたいという話'),
            text: M('{0}から「{1}」の話が来ました。{2}', [Nm(c.name), D(DEALN.ja[type]!), D(DEALD.ja[type]!)]),
            choices: [
              Choice(M('組む'), M('手は使わない'), () {
                deals.add(Deal(co: c.id, type: type, since: year));
                c.rel += 10;
                tieRec(c, 'f', M('「{0}」で組んだ', [D(DEALN.ja[type]!)]));
                calcAll();
                return M('{0}と組みました', [Nm(c.name)]);
              }),
              Choice(M('断る'), M('相手は少し機嫌を損ねる'), () {
                c.rel -= 5;
                return M('断りました');
              }),
            ]));
      }
    }
    for (final c in subs()) {
      if (c.fromStaff == null && !c.listed) continue;
      if (rnd() < .01) {
        for (final b in c.biz) {
          b.power *= 1.1;
        }
        c.cash -= math.max(0, c.cash * .3);
        N(M('子会社{0}の社長{1}が、独断で大きな投資をしました', [Nm(c.name), Nm(c.presName)]));
      }
      if (c.rel < 10 && rnd() < .006 && !events.any((e) => e.subco == c.id)) {
        events.add(GameEvent(subco: c.id, title: M('子会社の社長が反発'), text: M('{0}の社長{1}が「親会社の口出しは迷惑だ」と言い出しました。', [Nm(c.name), Nm(c.presName)]), choices: [
          Choice(M('社長を替える'), M('子会社の力が1割落ちるが、言うことを聞くようになる'), () {
            for (final b in c.biz) {
              b.power *= .9;
            }
            c.presName = nm();
            c.presAge = ri(40, 55).toDouble();
            c.rel = 40;
            return M('{0}の社長を替えました', [Nm(c.name)]);
          }),
          Choice(M('好きにさせる'), M('関係は良くなるが、配当が減る'), () {
            c.rel += 25;
            c.eff *= .95;
            return M('{0}には口を出さないことにしました', [Nm(c.name)]);
          }),
        ]));
      }
    }
  }

  void dirtyMonthly(void Function(String, [String]) N) {
    if (cooked > 0) {
      cooked--;
      if (rnd() < .03) {
        cooked = 0;
        scandal = 24;
        final wl = listed;
        if (wl) {
          listed = false;
          sh.vc += sh.float;
          sh.float = 0;
        }
        N(M(wl ? '【粉飾発覚】決算の粉飾が明るみに出ました。上場廃止となりました' : '【粉飾発覚】決算の粉飾が明るみに出ました。信用は地に落ちました'), 'bad');
      }
    }
    for (final b in biz) {
      if (b.cartel > 0) {
        b.cartel--;
        if (rnd() < .015) {
          b.cartel = 0;
          final fine = b.rev * 12 * .15;
          cash -= fine;
          scandal = math.max(scandal, 12);
          N(M('「{0}」の談合が発覚し、罰金{1}を払いました', [I(b.ind), Y(fine)]), 'bad');
        }
      }
    }
    if (buried.isNotEmpty && turn >= buried[0]) {
      buried.removeAt(0);
      for (final b in biz) {
        b.power *= .75;
      }
      scandal = 18;
      N(M('【古い不祥事が再燃】昔もみ消した不祥事が、もっと大きな事件として報じられました'), 'bad');
    }
    bool sharesInd(Company c) => c.biz.any((x) => biz.any((y) => y.ind == x.ind));
    final kur = cos.where((c) => c.alive && c.rival != null && c.rival!.k == 'kuroda' && c.parent != 'player' && c.rel < 0 && sharesInd(c)).firstOrNull;
    if (biz.isNotEmpty && rnd() < (kur != null ? .01 : .004)) {
      final foe = kur != null && rnd() < .6
          ? kur
          : pickOr(cos.where((c) => c.alive && c.rival != null && c.parent != 'player' && c.rel < 0 && sharesInd(c)).toList());
      if (foe != null) {
        final b = biz.where((y) => foe.biz.any((x) => x.ind == y.ind)).firstOrNull;
        if (b != null) {
          b.power *= .93;
          for (final x in foe.biz) {
            if (x.ind == b.ind) x.power *= 1.1;
          }
          tieRec(foe, 'h', M('「{0}」の開発の中身を盗まれた', [I(b.ind)]));
          events.add(GameEvent(
              who: foe,
              face: foe.rival!.col,
              title: M('情報が盗まれた'),
              text: M('「{0}」の主力の開発者が突然辞め、半年後、{1}から同じような商品が出ました。', [I(b.ind), Nm(foe.name)]),
              choices: [
                Choice(M('訴える'), M('2年後に判決。勝てば賠償金が入る'), () {
                  suits.add(Suit(at: turn + 24, co: foe.id, amt: math.max(foe.cap * .01, b.rev * 6)));
                  foe.rel -= 20;
                  tieRec(foe, 'g', M('情報を盗まれて訴えた'));
                  return M('{0}を訴えました', [Nm(foe.name)]);
                }),
                Choice(M('やり返す'), M('こちらも相手の中身を盗む（社長の時間は使わない）'), () {
                  hUsed -= hrs('dirty');
                  return doDirty('spy', foe);
                }),
                Choice(M('黙って次の商品で勝負する'), M('評判は守られる'), () {
                  rep = rep + 3;
                  return M('騒がず、次の商品で取り返すことにしました');
                }),
              ]));
        }
      }
    }
    if (suits.isNotEmpty && turn >= suits[0].at) {
      final s = suits.removeAt(0);
      final c = coById(s.co);
      if (s.against) {
        cash -= s.amt;
        N(M('約束破りの裁判に負け、{0}を払いました', [Y(s.amt)]), 'bad');
      } else if (rnd() < .6 && c != null) {
        cash += s.amt;
        N(M('{0}との裁判に勝ち、賠償金{1}を受け取りました', [Nm(c.name), Y(s.amt)]), 'good');
      } else {
        N(M('裁判に負けました。訴えは退けられました'), 'bad');
      }
    }
  }

  void rivalReturns(void Function(String, [String]) N) {
    if (ret.isEmpty || turn < ret[0].at) return;
    final r = ret.removeAt(0);
    final presN = r.west ? '${given()}・${r.fam}' : '${r.fam} ${given()}';
    final name = '${r.fam}・ネクスト';
    final rv = Rival(k: 'ret${uid()}', pres: presN, co: name, type: 'peer', label: 'avenger', tier: 0, col: r.col);
    final c = mkCo(0, 'link', name: name, presName: presN, rival: rv, fam: 60);
    c.presAge = ri(25, 35).toDouble();
    c.rel = -60;
    c.g = .03;
    if (extras) rv.from = r.from;
    if (extras && r.end != null) {
      rv.grudge = r.grudge;
      rv.ties.add(M('{0}年：{1}', [year, M('一族は、{0}が買収された恨みを覚えている', [Nm(r.from)])]));
    }
    c.cash = cap * .05;
    for (final b in (biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).take(2)) {
      c.biz.add(CoBiz(ind: b.ind, power: b.power * .3));
    }
    calcAll();
    N(M('{0}を失った一族の{1}が、新しい会社「{2}」を立ち上げました。狙いはあなたです', [Nm(r.from), Nm(presN), Nm(name)]), 'big');
  }
}
