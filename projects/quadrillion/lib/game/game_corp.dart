// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 会社どうしの仕組み（1.1.0+29。企画書「現実に寄せる」の段4）。
///
/// - 宿敵・CPU の会社も自社と同じ決まりで動く: 客の数（事業の力とシェア）と、店などが売れる量の小さい方が売上。
///   店などは稼ぎと借金で開き、1か月に開ける数は責任者を育てる速さで決まる。借金には国と年の金利がかかり、
///   不況で貸しはがされ、払えないと倒れる。税を払い、時価総額は自社と同じ株価の式で決まる
/// - M&A は 調べ（デューデリ）→ 申し入れ（株価への上乗せ）→ 当局の審査（独禁法）→ 手続き → 統合（1〜3年。のれんと減損）
/// - 上場は 監査（2期）と社内の決まり（内部統制）を2〜3年かけて整え、主幹事を選んで、市場の地合いで値が決まる
/// - 株価は 利益・伸び・金利・市場の地合い・うわさ。決算発表と株主総会（物言う株主の要求）
/// - 大口の客に頼りすぎると、取引を切られたり、客が倒れて売掛金が戻らない
/// - 他社の中身は、調べないと幅でしか見えない
///
/// CPU の会社が市場から取る分の倍（1.1.0+30。世界の上位を現実の大きさに寄せる）
const double cpuShare = .78;

extension GameCorp on Game {
  // ===== 小道具 =====
  /// 会社と鍵で決まる 0〜1 の数（乱数を使わない。計算のたびに同じ値）
  double hashOf(int id, int k) {
    var x = (id * 2654435761 + k * 40503 + 12345) & 0x7fffffff;
    x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff;
    x = x ^ (x >> 16);
    return (x & 0xffff) / 65535.0;
  }

  double coUnitRev(String ind) => profileOf(indm[ind]!).unitRev * nom();
  double coUnitCapex(String ind) => profileOf(indm[ind]!).unitCapex * nom();

  /// 店などが売れる量（育ちかけは平均で8割）
  double coCapRev(CoBiz b) => (b.u + b.uy * .78) * coUnitRev(b.ind);

  /// 1か月に開き始められる店などの数（自社と同じく、責任者を育てる速さ。ネットは宣伝の伸び、人は採用の市場）
  double coOpenMax(CoBiz b) {
    final ind = indm[b.ind]!;
    final k = kindOf(ind);
    final u = b.u + b.uy;
    return switch (k) {
      'net' => 1 + u * .15,
      'people' => 3 + u * .05,
      _ => (2 + u / 5) / (KIND_LEAD_MONTHS[k] ?? 6),
    };
  }

  /// 会社のお金の控え（無ければ作る。借り方は宿敵の型と会社ごとの性格で決まる）
  CoFin finOf(Company c) => c.fin ??= CoFin(appetite: _appetiteOf(c));

  int _appetiteOf(Company c) {
    final r = c.rival;
    if (r != null) {
      return switch (r.type) {
        'genius' || 'fund' => 2,
        'zaibatsu' => 0,
        _ => 1,
      };
    }
    final h = hashOf(c.id, 1);
    return h < .3
        ? 0
        : h < .85
            ? 1
            : 2;
  }

  /// 宿敵の本拠の国（世界の画面の地図に印を出す。名前の国から決まる。戻ってきた一族・独立した元部下はあなたと同じ国）
  String? rivalHome(Company c) {
    final r = c.rival;
    if (r == null) return null;
    return switch (r.k) {
      'hale' => 'us',
      'li' => 'cn',
      'volkova' => 'ru',
      'kuroda' || 'makabe' || 'saionji' || 'onizuka' || 'yuki' => 'jp',
      _ => home,
    };
  }

  /// 国ごとの、生きている宿敵の会社（地図の印）
  Map<String, List<Company>> rivalsByCountry() {
    final m = <String, List<Company>>{};
    for (final c in cos) {
      if (!c.alive || c.rival == null || c.parent == 'player') continue;
      (m[rivalHome(c)!] ??= []).add(c);
    }
    return m;
  }

  /// 国の政府が後ろにいる会社（潰れそうになると助けが入る）
  bool stateBacked(Company c) => c.rival?.type == 'state';

  /// CPU の会社の借金の上限（自社と同じ式: 稼ぐ力×倍率＋担保の4割）
  double coBorrowLimit(Company c) {
    final a = math.max(0.0, c.profit * 12);
    final coll = c.biz.fold(0.0, (s, b) => s + (b.u + b.uy) * coUnitCapex(b.ind) * .6);
    return a * 2.5 * (econ > 1.05 ? 1.25 : econ < .95 ? .8 : 1) + coll * .4;
  }

  /// 借金が年の利益の何倍か
  double coDebtX(Company c) {
    final d = finOf(c).debt;
    if (d <= 0) return 0;
    final a = c.profit * 12;
    return a > 0 ? d / a : 99;
  }

  double coBorrowRoom(Company c) {
    final x = coDebtX(c);
    if (x >= 8) return 0;
    final room = math.max(0.0, coBorrowLimit(c) - finOf(c).debt);
    return x >= 5 ? room * .5 : room;
  }

  /// 新しく借りるときの金利（自社と同じ: 国の金利＋2%＋借金の倍で上乗せ）
  double coRate(Company c, double extra) {
    final a = c.profit * 12;
    final after = a > 0 ? (finOf(c).debt + extra) / a : 99.0;
    var r = math.max(0.0, rateOf(home)) / 100 + .02;
    for (final s in debtSteps) {
      if (after > s.$1) r += s.$2;
    }
    if (stateBacked(c)) r -= .01;
    return math.max(.005, r);
  }

  void coBorrow(Company c, double a) {
    if (a <= 0) return;
    final f = finOf(c);
    final r = coRate(c, a);
    f.rate = f.debt + a > 0 ? (f.rate * f.debt + r * a) / (f.debt + a) : r;
    f.debt += a;
    c.cash += a;
  }

  // ===== CPU の会社の数え方（calcAll から） =====
  void coCalcAll(Map<String, List<double>> T, Map<String, double> sm, Map<String, double> mk) {
    final econAdj = <String, double>{};
    for (final c in cos) {
      if (!c.alive) continue;
      final f = finOf(c);
      var rv = 0.0, pr = 0.0;
      for (final b in c.biz) {
        final ind = indm[b.ind]!;
        final e = b.power * (c.parent == 'player' ? (sm[b.ind] ?? 1) : 1);
        double r;
        if (c.loc != null) {
          r = locRev(c.loc!, ind, e, T);
        } else {
          final M = (mk[ind.id] ??= mkt(ind)) * reg[c.tier];
          final tot = T[b.ind]![c.tier];
          r = tot > 0 ? M * e / tot / 3 : 0.0;
        }
        // 1.1.0+30 から、CPU の会社の取り分は名前の無い小さな会社の分を少し厚く見て、0.78倍にする
        // （世界の上位が現実より尖っていた。段4の測りで1980年の1位 約12兆円・2010年の1位 約58兆円。現実は約9兆円・約30兆円）
        // 難しさでも少し変える（やさしいは0.925倍・むずかしいは1.075倍。店などの数で伸びが決まるので、伸びの倍だけでは差が出なかった）
        if (c.parent != 'player') r *= cpuShare * (1 + (dif.g - 1) * .15);
        b.dem = r;
        final ur = coUnitRev(b.ind);
        // 店などが無い事業（生まれたばかりの会社・後から乗り込んだ事業）は、客に見合う数を持って始める。
        // はじめの月は育ちきった店、そのあとは育ちかけの店として
        if (b.u + b.uy <= 0 && r > 0 && ur > 0) {
          if (turn == 0) {
            b.u = r / ur;
          } else {
            b.uy = r / ur;
          }
        }
        final x = math.min(r, coCapRev(b));
        b.rev = x;
        rv += x;
        final p = profileOf(ind);
        final mg = ind.mg * c.eff * (econAdj[ind.id] ??= econ < 1 ? 1 - (1 - econ) * ind.sens : 1);
        // 粗利（利益率＋固定費の分）から、店などの固定費を引く（自社と同じ。売り切れていれば今までの利益率になる）
        pr += x * (mg + p.fixed) - (b.u + b.uy) * ur * p.fixed;
      }
      final interest = f.debt * f.rate / 12;
      c.rev = rv;
      c.profit = pr - interest - rv * .015;
      final h = c.revHist;
      final gg = h.length >= 12 && h[h.length - 12] > 0 ? rv / h[h.length - 12] - 1 : 0.0;
      final ts = rv > 0 ? c.biz.fold(0.0, (s, b) => s + (techCats.contains(indm[b.ind]!.cat) ? b.rev : 0)) / rv : 0.0;
      c.cap = coValue(c, gg, ts);
    }
  }

  /// 時価総額（自社と同じ株価の式: 利益×株価の倍率（伸び・金利・地合い）×上場の有無＋資産＋現金−借金。払えずに苦しんでいると半値）
  double coValue(Company c, double gg, double ts) {
    final f = finOf(c);
    var v = math.max(0.0, c.profit * .9 * 12) * per(gg) * (1 + .6 * ts) * (c.listed ? 1 : .6) + c.rev * .4 + c.cash - f.debt;
    if (f.distress >= 3) v *= .5;
    return math.max(v, math.max(1.0, c.rev * .05));
  }

  /// 遊びの始めに、CPU の会社の借金と上場を決める（店などは最初の計算で客に見合う数になっている）
  void cpuSeed() {
    for (final c in cos) {
      if (!c.alive) continue;
      final f = finOf(c);
      final lev = const [.4, 1.5, 3.0][f.appetite] * (.5 + hashOf(c.id, 2));
      f.debt = math.max(0.0, c.profit * 12 * lev);
      f.rate = math.max(0.0, rateOf(home)) / 100 + .02;
      c.cash = math.max(c.cash, c.rev * 1.5);
      c.listed = c.profit * 12 >= 3e8 * nom() || c.tier >= 1;
    }
  }

  // ===== CPU の会社の1か月（自社と同じ決まり） =====
  void cpuMonth(void Function(String, [String]) N) {
    final tax = corpTaxRate();
    final y = yr();
    final call = econ < .97;
    for (final c in cos.toList()) {
      if (!c.alive) continue;
      final f = finOf(c);
      f.heat = 0;
      // 育ちかけの店などが育つ
      for (final b in c.biz) {
        if (b.uy > 0) {
          final ramp = math.max(3, KIND_RAMP[kindOf(indm[b.ind]!)] ?? 6);
          final mv = b.uy / ramp;
          b.uy -= mv;
          b.u += mv;
        }
      }
      // 税と返済（5年で返す）
      final t = math.max(0.0, c.profit) * tax;
      final pp = f.debt / 60;
      c.cash += c.profit - t - pp;
      f.debt = math.max(0.0, f.debt - pp);
      // 不況のときは、借りすぎた会社から銀行が貸しはがす（自社と同じ）
      if (call && f.debt > 0 && coDebtX(c) > 5 && hashOf(c.id + turn, 3) < .15) {
        final back = f.debt * .1;
        c.cash -= back;
        f.debt -= back;
      }
      // 稼ぎの一部で客を増やす（商品・宣伝。自社の責任者と同じ式: 利益の3割（慎重なら15%・攻めるなら6割）を、手元に余裕があるだけ）。
      // 難しさで割合が変わる
      final free = c.cash - c.rev * .5;
      if (free > 0 && c.profit > 0) {
        final rate = f.appetite == 0
            ? .15
            : f.appetite == 2
                ? .6
                : .3;
        final spend = math.min(free, c.profit * rate * dif.r);
        c.cash -= spend;
        final T = lastT;
        for (final b in c.biz) {
          final tt = T?[b.ind];
          final s = tt != null && tt[c.tier] > 0 ? b.power / tt[c.tier] : 0.0;
          final w = c.rev > 0 ? b.rev / c.rev : 1 / c.biz.length;
          // 1円あたりの効きは、今までの CPU の再投資（利益の12%を力に）と同じ大きさになるよう合わせた（ふつうの会社で 0.3×0.4＝0.12）
          b.power += spend * w * invEff * math.pow(1 - math.min(s, .95), 2) * .4;
        }
      }
      // 客が店などを超えていれば開く（1か月に開ける数・お金・借りられる額まで）。客が大きく足りなければ閉める
      for (final b in c.biz) {
        if (b.dem <= 0) continue;
        final cr = coCapRev(b);
        final ur = coUnitRev(b.ind);
        if (ur <= 0) continue;
        if (b.dem > cr * 1.03) {
          var n = math.min((b.dem - cr) / ur, coOpenMax(b) * dif.g);
          final ind = indm[b.ind]!;
          final one = coUnitCapex(b.ind) + wageCat(ind.cat) * 1.4 * (KIND_LEAD_MONTHS[kindOf(ind)] ?? 6) / 12 / 4;
          final cashOk = math.max(0.0, c.cash - c.rev * .5);
          if (n * one > cashOk && f.appetite > 0) {
            final room = coBorrowRoom(c) * (f.appetite == 2 ? 1 : .5);
            coBorrow(c, math.min(room, n * one - cashOk));
          }
          n = math.min(n, math.max(0.0, c.cash - c.rev * .5) / one);
          if (n > 0) {
            c.cash -= n * one;
            b.uy += n;
            f.heat += n;
          }
        } else if (b.dem < cr * .75 && b.u > 1) {
          final cut = b.u * .02;
          b.u -= cut;
          c.cash += cut * coUnitCapex(b.ind) * .2;
        }
      }
      // 払えない: 借りられるならつなぐ。借りられなければ苦しい月が続き、1年で倒れる（国の後ろ盾があれば助けが入る）
      if (c.cash < 0) {
        final room = coBorrowRoom(c);
        if (room > -c.cash) {
          coBorrow(c, -c.cash * 1.2);
        } else {
          f.distress++;
          if (f.distress == 3 && (c.rival != null || c.tier == 0)) {
            N(M('{0}が借りすぎて資金繰りに苦しんでいます。株価が半分に下がり、安く買えるかもしれません', [Nm(c.name)]), c.rival != null ? 'big' : '');
          }
          if (f.distress >= 12) {
            if (stateBacked(c)) {
              f.debt *= .5;
              c.cash = c.rev;
              f.distress = 0;
              N(M('{0}に国の支援が入り、借金が半分になりました', [Nm(c.name)]));
            } else if (c.parent != 'player') {
              coFail(c, N);
              continue;
            }
          }
        }
      } else if (f.distress > 0) {
        f.distress--;
      }
      // 上場（自社と同じく2〜3年の準備。地合いが悪ければ待つ）
      if (!c.listed && c.parent != 'player' && c.loc == null) {
        if (f.ipoLeft < 0 && c.profit * 12 >= 3e8 * nom()) f.ipoLeft = 24 + (hashOf(c.id, 4) * 12).floor();
        if (f.ipoLeft > 0) f.ipoLeft--;
        if (f.ipoLeft == 0 && perMul >= .85) {
          c.listed = true;
          f.ipoLeft = -1;
          c.cash += c.cap * .2 * .93;
        }
      }
    }
    if (y >= startYear + .5) cpuDeals(N);
  }

  /// CPU の会社が倒れる（客と店は市場に戻る。あなたの取引先なら売掛金が戻らない）
  void coFail(Company c, void Function(String, [String]) N) {
    c.alive = false;
    if (c.rival != null) {
      rivalDefeated(c);
      N(M('宿敵の{0}が借金を返せずに倒れました', [Nm(c.name)]), 'big');
    } else if (c.tier == 0 && c.cap > cap * .5) {
      N(M('{0}が借金を返せずに倒れました', [Nm(c.name)]));
    }
    clientGone(c, N);
  }

  /// CPU の会社どうしの買収（自社と同じく、上乗せを払い、独禁法で止められることがある）
  void cpuDeals(void Function(String, [String]) N) {
    final buyers = cos.where((c) => c.alive && c.parent != 'player' && c.loc == null && (c.rival != null || c.tier == 0) && finOf(c).distress == 0).toList();
    for (final b in buyers) {
      final r = b.rival;
      final p = r == null
          ? .004
          : switch (r.type) {
              'fund' => .03,
              'zaibatsu' => .012,
              'genius' => .01,
              _ => .006,
            };
      if (rnd() >= p) continue;
      final inds = {for (final x in b.biz) x.ind};
      final pool = cos
          .where((t) =>
              t.alive &&
              t != b &&
              t.parent != 'player' &&
              t.loc == null &&
              t.rival == null &&
              t.cap < b.cap * .3 &&
              (finOf(t).distress >= 3 || t.biz.any((x) => inds.contains(x.ind)) || r?.type == 'fund'))
          .toList()
        ..ssort((x, y) => (finOf(y).distress - finOf(x).distress) != 0 ? finOf(y).distress - finOf(x).distress : y.cap.compareTo(x.cap));
      final t = pool.firstOrNull;
      if (t == null) continue;
      final price = t.cap * 1.3;
      var have = math.max(0.0, b.cash - b.rev);
      if (have < price && finOf(b).appetite > 0) {
        coBorrow(b, math.min(coBorrowRoom(b), price - have));
        have = math.max(0.0, b.cash - b.rev);
      }
      if (have < price) continue;
      // 独禁法: 同じ業種で合わせたシェアが5割を超えると止められ、3割5分を超えると店の一部を手放させられる
      final sh = mergedShare(b, t);
      if (sh > .5) {
        if (b.rival != null) N(M('{0}による{1}の買収は、独禁法の審査で止められました', [Nm(b.name), Nm(t.name)]));
        continue;
      }
      b.cash -= price;
      t.cash -= finOf(t).debt;
      finOf(b).debt += finOf(t).debt;
      for (final x in t.biz) {
        final k = sh > .35 ? .8 : 1.0;
        final ex = b.biz.where((y) => y.ind == x.ind).firstOrNull;
        if (ex != null) {
          ex.power += x.power * .92 * k;
          ex.u += x.u * k;
          ex.uy += x.uy * k;
        } else {
          b.biz.add(CoBiz(ind: x.ind, power: x.power * .92 * k, u: x.u * k, uy: x.uy * k));
        }
      }
      b.cash += math.max(0.0, t.cash);
      t.alive = false;
      clientGone(t, N, bought: b);
      if (b.rival != null) N(M('{0}が{1}を{2}で買収し、さらに大きくなりました', [Nm(b.name), Nm(t.name), Y(price)]), 'bad');
    }
  }

  /// 2社を合わせたときの、同じ業種でのいちばん大きなシェア（独禁法の審査で見る）
  double mergedShare(Company a, Company b) {
    var best = 0.0;
    for (final x in a.biz) {
      for (final y in b.biz) {
        if (x.ind != y.ind) continue;
        final m = mkt(indm[x.ind]!) * reg[math.max(a.tier, b.tier)] / 3;
        if (m <= 0) continue;
        best = math.max(best, (x.rev + y.rev) / m);
      }
    }
    return best;
  }

  /// あなたが買うときに合わせたシェア（自社の事業と子会社を含む）
  double myMergedShare(Company c) {
    var best = 0.0;
    for (final y in c.biz) {
      final m = mkt(indm[y.ind]!) / 3;
      if (m <= 0) continue;
      var mine = biz.where((b) => b.ind == y.ind).fold(0.0, (s, b) => s + b.rev);
      for (final s in subs()) {
        if (s == c) continue;
        mine += s.biz.where((b) => b.ind == y.ind).fold(0.0, (a, b) => a + b.rev);
      }
      if (mine <= 0) continue;
      best = math.max(best, (mine + y.rev) / m);
    }
    return best;
  }

  /// 同じ業種で、先月宿敵が開いた店などの数（物件の取り合いの強さ。ほかの CPU の出店は今までの物件の取り合いの数に入っている）
  double heatOf(String ind) {
    var h = 0.0;
    for (final c in cos) {
      if (!c.alive || c.rival == null || c.parent == 'player' || c.fin == null || c.fin!.heat <= 0) continue;
      if (c.biz.any((b) => b.ind == ind)) h += c.fin!.heat;
    }
    return h;
  }

  /// 物件を狙っている他社の数に、同じ業種で店を増やしている宿敵を1社分足す（宿敵も同じ物件を取り合う）
  int offerRivals(String ind, int base) {
    if (!unitsOn) return base;
    return base + (heatOf(ind) >= 1 ? 1 : 0);
  }

  // ===== 隠れた情報 =====
  /// 他社の数字の見え方の幅（上場していれば決算で±10%、未上場は±40%、調べれば±3%）
  double infoWidth(Company c) {
    if (c.parent == 'player' || (c.fin?.dd ?? 0) > 0) return .03;
    return c.listed ? .1 : .4;
  }

  /// 他社の数字を幅で見る（本当の値のまわりに、会社ごとに決まったずれを持つ）
  (double, double) seenRange(Company c, double v, int k) {
    final w = infoWidth(c);
    final off = (hashOf(c.id, 10 + k) - .5) * w;
    final mid = v * (1 + off);
    final lo = mid * (1 - w / 2), hi = mid * (1 + w / 2);
    return v >= 0 ? (lo, hi) : (hi, lo);
  }

  /// 他社の借金（見えている幅の真ん中は本当の値。簿外の借金は調べないと入らない）
  double coDebt(Company c) => finOf(c).debt;
  double coUnits(Company c) => c.biz.fold(0.0, (s, b) => s + b.u + b.uy);

  // ===== 株価 =====
  /// 株価（時価総額÷株の数）
  double sharePrice() => cap / math.max(1, corp.nSh);

  /// 株価を決める部分（利益の稼ぐ力・伸び・金利・地合い・うわさ・資産）
  Map<String, double> capParts() {
    final h = hist;
    final gg = h.length >= 13 && h[h.length - 13].rev > 0 ? h[h.length - 1].rev / h[h.length - 13].rev - 1 : 0.0;
    final ts = rev > 0 ? biz.fold(0.0, (s, b) => s + (techCats.contains(indm[b.ind]!.cat) ? b.rev : 0)) / rev : 0.0;
    return {
      'earn': math.max(0.0, pre * .9 * 12) * 15 * (1 + .6 * ts) * (listed ? 1 : .6),
      'growth': 1 + clampD(gg, -.3, .5),
      'rate': perK,
      'mood': perMul,
      'rumor': (listed ? corp.noise * corp.shock : 1) * (scandal > 0 ? .8 : 1),
      'cap': cap,
    };
  }

  /// 毎月の株価を記録し、先月から動いた理由を並べる
  void recordPrice() {
    final p = sharePrice();
    corp.px.add(p);
    if (corp.px.length > 240) corp.px.removeAt(0);
    final now = capParts();
    final was = corp.pp;
    corp.pp = now;
    corp.why = [];
    if (was.isEmpty || (was['cap'] ?? 0) <= 0) return;
    final total = math.log(math.max(1.0, now['cap']!) / math.max(1.0, was['cap']!));
    if (total.abs() < .005) return;
    final mult = now['earn']! > 0 && was['earn']! > 0;
    final parts = <(String, double)>[];
    double lr(String k) => (now[k]! > 0 && was[k]! > 0) ? math.log(now[k]! / was[k]!) : 0;
    if (mult) {
      parts.add(('earn', lr('earn')));
      parts.add(('growth', lr('growth')));
      parts.add(('rate', lr('rate')));
      parts.add(('mood', lr('mood')));
    }
    parts.add(('rumor', lr('rumor')));
    final known = parts.fold(0.0, (s, x) => s + x.$2);
    parts.add(('book', total - known));
    parts.ssort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
    for (final x in parts.take(3)) {
      if (x.$2.abs() < .003) continue;
      final up = x.$2 > 0;
      final m = switch (x.$1) {
        'earn' => up ? '利益が増えた' : '利益が減った',
        'growth' => up ? '売上の伸びが速まった' : '売上の伸びが鈍った',
        'rate' => up ? '金利が下がった' : '金利が上がった',
        'mood' => up ? '市場の地合いが良くなった' : '市場の地合いが悪くなった',
        'rumor' => up ? 'うわさで買われた' : 'うわさ・不祥事で売られた',
        _ => up ? '現金・資産が増えた' : '借金が増えた・現金が減った',
      };
      corp.why.add(M('{0}（{1}）', [M(m), '${up ? '+' : '−'}${pctD(x.$2.abs() * 100)}%']));
    }
  }

  /// 次の決算発表の月（3か月ごと: 2・5・8・11月）と、次の株主総会の月（6月）
  int nextEarnMonth() => [2, 5, 8, 11].firstWhere((m) => m >= q, orElse: () => 2);
  int nextEarnYear() => q > 11 ? year + 1 : year;
  int nextAgmYear() => q > 6 ? year + 1 : year;

  // ===== 自社の1か月 =====
  void corpMonthly(void Function(String, [String]) N) {
    ipoMonthly(N);
    dealsProgress(N);
    integMonthly(N);
    clientsMonthly(N);
    // 格付けが下がると、仕入れ先が支払いを早めるよう求める（払う前に現金が出ていく）
    // （条件が戻れば、前倒しで払った分は元の支払いの月に戻るので、手元に戻る）
    final tight = ratingIdx() >= 2 && biz.isNotEmpty;
    if (tight && !corp.tight) {
      // 1.1.0+30 から、早めるのは半月分から1週間分ほど（0.25か月分）に。前は1度の格下げで資金が尽き、そこから倒れることが多かった
      final hit = cogsOf.values.fold(0.0, (a, b) => a + b) * .25;
      cash -= hit;
      corp.tightAmt = hit;
      N(M('格付けが下がり、仕入れ先が支払いを早めるよう求めてきました。{0}を前倒しで払いました', [Y(hit)]), 'bad');
    } else if (!tight && corp.tight) {
      cash += corp.tightAmt;
      corp.tightAmt = 0;
      N(M('格付けが戻り、仕入れ先への支払いの条件も元に戻りました'), 'good');
    }
    corp.tight = tight;
    if (listed) {
      // うわさは少しずつ1へ戻り、毎月少し揺れる
      corp.noise = 1 + (corp.noise - 1) * .85 + (rnd() - .5) * .04;
      corp.shock = 1 + (corp.shock - 1) * .9;
      // 上場している会社は、3か月ごとの決算発表と開示の費用がかかる
      cash -= listCost();
      if ([2, 5, 8, 11].contains(q)) earnings(N);
      if (q == 6 && corp.agmY != year) agm(N);
    }
  }

  /// 上場を続ける毎月の費用（監査・開示・株主の窓口）
  double listCost() => 3e6 * nom() + rev * .0005;

  /// 決算発表（3か月の利益を見込みと比べ、上ぶれ・下ぶれで株価が動く）
  void earnings(void Function(String, [String]) N) {
    final h = hist;
    if (h.length < 3) return;
    final qp = h.sublist(h.length - 3).fold(0.0, (s, x) => s + x.pre);
    final exp = corp.expQ != 0 ? corp.expQ : qp;
    final base = math.max(exp.abs(), math.max(1.0, rev * .3));
    final d = clampD((qp - exp) / base, -.5, .5);
    corp.noise *= 1 + d * .15;
    corp.lastQ = qp;
    // 次の見込みは、今の3か月に、去年からの伸びの半分を足したもの
    corp.expQ = qp * (1 + clampD(g, -.3, .3) * .5 / 4);
    if (d.abs() >= .1) {
      N(M(d > 0 ? '決算発表：3か月の利益は{0}。見込みを上回り、株が買われました' : '決算発表：3か月の利益は{0}。見込みを下回り、株が売られました', [Y(qp)]), d > 0 ? 'good' : 'bad');
    } else {
      N(M('決算発表：3か月の利益は{0}。ほぼ見込みどおりでした', [Y(qp)]));
    }
  }

  /// 物言う株主がいるか（市場の株が多く、現金を貯めこんでいるか、伸びが止まっている）
  bool activist() => listed && sh.float >= 25 && (cash > cap * .2 || g < 0);

  /// 株主総会（6月）。物言う株主は配当か自社株買いを求める
  void agm(void Function(String, [String]) N) {
    corp.agmY = year;
    if (!activist()) {
      corp.demand = null;
      N(M('株主総会を開きました。議案はすべて通りました'));
      return;
    }
    final want = math.max(0.0, cash * .2);
    corp.demand = 'pay';
    events.add(GameEvent(
      title: M('株主総会：物言う株主の要求'),
      text: M('市場の株を持つ投資家が、貯めこんだ現金を株主に返すよう求めています（{0}の配当か自社株買い）。断ると社長の選び直しの議案が出され、株価も下がります。', [Y(want)]),
      choices: [
        Choice(M('配当を出す'), M('{0}を株主に払う', [Y(want)]), () {
          cash -= want;
          corp.noise *= 1.04;
          corp.demand = null;
          return M('配当を出し、株主に{0}を返しました', [Y(want)]);
        }),
        Choice(M('自社株買いをする'), M('市場の株を買い戻す（{0}まで）', [Y(want)]), () {
          final x = math.min(sh.float, want / math.max(1, cap) * 100 / 1.15);
          corp.demand = null;
          return doBuyback(x);
        }),
        Choice(M('断る'), M('お金は出さない。株価が下がり、社長の信任が揺らぐ'), () {
          corp.noise *= .93;
          stamina = math.max(0, stamina - 10);
          corp.demand = null;
          return M('要求を断りました。社長の選任は僅差で通りましたが、株は売られました');
        }),
      ],
    ));
  }

  // ===== 上場 =====
  /// 上場の準備を始められるか（事業があり、1年の利益が出ている。未上場で、準備中でない）
  bool canIpoPrep() => !listed && corp.ipo == null && biz.isNotEmpty && annualProfit() > 0;

  /// 上場の準備にかかる月（基本は30か月。会計士がいれば6か月、弁護士がいれば3か月縮む。経理・法務の腕でも縮む）
  int ipoMonths() {
    var m = 30.0;
    if (staff.any((p) => p.lic.contains('cpa'))) m -= 6;
    if (staff.any((p) => p.lic.contains('lawyer'))) m -= 3;
    final acct = staff.fold(0, (a, p) => math.max(a, (p.sk?['acct'] ?? 0) + (p.sk?['law'] ?? 0)));
    m -= clampD((acct - 100) / 20, 0, 3);
    // 締め切り直前に強い人がいると、準備が早く進む（1.1.0+33。いつもの下限24か月より短くなる）
    if (anyTr('deadline')) return clampI(m.round() - 4, 20, 36);
    return clampI(m.round(), 24, 36);
  }

  /// 上場の準備の毎月の費用（監査法人・社内の決まりを作る助言・人）
  double ipoMonthCost() => 4e6 * nom() + rev * .001;

  String ipoPrepStart() {
    if (!canIpoPrep()) return M('今は上場の準備を始められません（未上場で、事業と1年の利益が要ります）');
    final nt = spendT('ipo');
    if (nt != null) return nt;
    final m = ipoMonths();
    corp.ipo = IpoPrep(start: turn, total: m);
    presXp('zai', 2);
    chron('ipo', M('上場の準備を始めた（監査と社内の決まり。約{0}か月）', [m]));
    return M('上場の準備を始めました。監査法人と契約し、社内の決まりを整えます。約{0}か月、毎月{1}ほどかかります', [m, Y(ipoMonthCost())]);
  }

  String ipoPrepStop() {
    if (corp.ipo == null) return M('準備をしていません');
    corp.ipo = null;
    return M('上場の準備をやめました。かかった費用は戻りません');
  }

  void ipoMonthly(void Function(String, [String]) N) {
    final p = corp.ipo;
    if (p == null || listed) return;
    final was = ipoReady();
    final c = ipoMonthCost();
    cash -= c;
    p.spent += c;
    p.done++;
    p.audit++;
    // 社内の決まりは、経理・法務の腕のある人がいるほど早く整う
    final best = staff.fold(0, (a, x) => math.max(a, (x.sk?['acct'] ?? 0) + (x.sk?['law'] ?? 0)));
    p.ctrl = math.min(1, p.ctrl + (1 / p.total) * (.8 + clampD(best / 200, 0, .6)));
    // 経理・法務に強い人がいないと、社内の決まりが整うまで予定より数か月延びる
    if (!was && ipoReady()) N(M('上場の準備が整いました。主幹事を選んで上場できます'), 'good');
  }

  /// 上場できるか（監査2期分・社内の決まり・かかる月が済み、利益が出ている）
  bool ipoReady() => corp.ipo != null && corp.ipo!.done >= corp.ipo!.total && corp.ipo!.audit >= 24 && corp.ipo!.ctrl >= .95 && annualProfit() > 0;

  /// 主幹事（手数料の率・値付けの強さ・要る大きさ）
  static const Map<String, (double, double, double)> uwTerms = {'big': (.08, 1.0, 1e10), 'mid': (.07, .93, 2e9), 'small': (.09, .85, 0)};

  bool uwOk(String k) => annualProfit() * 15 >= uwTerms[k]!.$3 * nom();

  /// 上場で集まるお金の見込み（新しい株を2割。値付けは主幹事と市場の地合いで、公開の値引き1割5分）
  double ipoRaise([String? uw]) {
    final t = uwTerms[uw ?? corp.ipo?.uw ?? 'mid']!;
    final listedCap = math.max(0.0, pre * .9 * 12) * per(g) + biz.fold(0.0, (s, b) => s + b.rev * .4) + cash - debt;
    return math.max(0.0, listedCap) * .2 * .85 * t.$2 * clampD(perMul, .6, 1.4);
  }

  double ipoFee([String? uw]) => ipoRaise(uw) * uwTerms[uw ?? corp.ipo?.uw ?? 'mid']!.$1 + 2e7 * nom();

  String chooseUw(String k) {
    final p = corp.ipo;
    if (p == null) return M('準備をしていません');
    if (!uwOk(k)) return M('この証券会社は、もっと大きな会社でないと引き受けてくれません');
    p.uw = k;
    return M('主幹事を決めました');
  }

  /// 上場する（準備が整っていれば）
  String ipoList() {
    if (!ipoReady()) return M('上場の準備がまだ整っていません');
    final nt = spendT('offer');
    if (nt != null) return nt;
    final money = ipoRaise();
    final fee = ipoFee();
    cash += money - fee;
    const k = 100 / 120;
    _dilute(k);
    sh.float = sh.float * k + 20 * k;
    sh.float += sh.vc;
    sh.vc = 0;
    listed = true;
    vcDeadline = 0;
    corp.ipo = null;
    corp.noise = 1;
    presXp('zai', 6, big: true);
    calcAll();
    chron('ipo', M('株式を上場した。{0}が入った（時価総額 {1}）', [Y(money - fee), Y(cap)]));
    return M('上場しました！{0}が集まり、手数料と上場の費用{1}を払いました。これからは3か月ごとに決算を発表します', [Y(money), Y(fee)]);
  }

  // ===== 買う話（M&A） =====
  MaDeal? dealOf(Company c) => corp.deals.where((d) => d.co == c.id).firstOrNull;

  /// 隠れた問題を決める（話を始めたときに一度だけ。調べれば見つかる）
  void rollHidden(Company c) {
    final f = finOf(c);
    if (f.rolled) return;
    f.rolled = true;
    final weak = f.distress > 0 || c.profit <= 0;
    if (rnd() < (weak ? .45 : .2)) f.offDebt = .05 + rnd() * .25;
    if (rnd() < .15) f.suit = .02 + rnd() * .08;
    if (rnd() < .3) f.flight = .05 + rnd() * .15;
  }

  /// 調べの費用と月（会社が大きいほど高い。会計士・弁護士がいると安く早い）
  double ddCost(Company c) {
    // 小さな会社でも監査法人・弁護士・助言の会社に2,000万円ほど。大きな会社は時価総額の0.1%ほど
    var x = math.max(2e7 * nom(), c.cap * .001) * (c.listed ? 1 : 1.3);
    if (staff.any((p) => p.lic.contains('cpa'))) x *= .8;
    if (staff.any((p) => p.lic.contains('lawyer'))) x *= .9;
    return x;
  }

  int ddMonths(Company c) {
    var m = 2 + (c.biz.length > 2 ? 1 : 0) + (c.listed ? 0 : 1);
    if (staff.any((p) => p.lic.contains('cpa'))) m--;
    if (staff.any((p) => p.lic.contains('lawyer'))) m--;
    // 締め切り直前に強い人・目利きがいると早い（1.1.0+33）
    if (anyTr('deadline') || anyTr('eye')) m--;
    return math.max(1, m);
  }

  /// 買う話を始める。[dd] を立てると先に調べる（調べないと隠れた問題が買ったあとに出る）
  String maStart(Company c, {bool dd = true, double target = 50.1, double prem = .3, String pay = 'cash'}) {
    if (dealOf(c) != null) return M('この会社とはもう話を進めています');
    if (pctOf(c) >= target) return M('もう{0}持っています', [pct(target)]);
    if (pay == 'swap' && !listed) return M('上場してからです');
    final check = dd && finOf(c).dd == 0;
    if (check && cash < ddCost(c)) return M('調べる費用が足りません（{0} 必要）', [Y(ddCost(c))]);
    final nt = spendT(check ? 'merge' : 'tob');
    if (nt != null) return nt;
    rollHidden(c);
    if (check) {
      final cost = ddCost(c);
      cash -= cost;
      corp.deals.add(MaDeal(co: c.id, stage: 'dd', left: ddMonths(c), target: target, prem: prem, pay: pay, spent: cost));
      return M('{0}を調べ始めました（{1}か月・{2}）。帳簿・契約・人を見て、隠れた問題を探します', [Nm(c.name), ddMonths(c), Y(cost)]);
    }
    corp.deals.add(MaDeal(co: c.id, stage: 'offer', left: 1, target: target, prem: prem, pay: pay));
    return offerMsg(c);
  }

  String offerMsg(Company c) => M('{0}に買い付けを申し入れました。相手の返事を待ちます（約1か月）', [Nm(c.name)]);

  /// 買う値段（足りない分の株×時価総額×（1＋上乗せ））
  double dealPrice(Company c, MaDeal d) => c.cap * math.max(0, d.target - pctOf(c)) / 100 * (1 + d.prem) * trDealPriceF();

  /// 相手が応じる見込み（今までの TOB の見込みに、上乗せの大きさを足す）
  double dealChance(Company c, MaDeal d) => clampD(tobChance(c, d.target) + (d.prem - .3) * 1.2 + (finOf(c).distress >= 3 ? .2 : 0), .03, .97);

  /// 審査の長さと、止められる見込み（合わせたシェアが3割5分を超えると長く、5割を超えると止められやすい）
  (int, double, double) reviewOf(Company c) {
    final s = myMergedShare(c);
    if (s > .6) return (12, .7, .3);
    if (s > .5) return (9, .4, .25);
    if (s > .35) return (6, .1, .15);
    return (1, 0, 0);
  }

  String maCancel(Company c) {
    final d = dealOf(c);
    if (d == null) return M('この会社とは話を進めていません');
    corp.deals.remove(d);
    return M('{0}を買う話をやめました。かかった費用は戻りません', [Nm(c.name)]);
  }

  void dealsProgress(void Function(String, [String]) N) {
    for (final d in corp.deals.toList()) {
      final c = coById(d.co);
      if (c == null || !c.alive || c.parent == 'player' && pctOf(c) >= d.target) {
        corp.deals.remove(d);
        continue;
      }
      d.left--;
      if (d.left > 0) continue;
      switch (d.stage) {
        case 'dd':
          final f = finOf(c);
          f.dd = 1;
          final found = <Object?>[];
          if (f.offDebt > 0) found.add(M('帳簿に載っていない借金 {0}', [Y(c.cap * f.offDebt)]));
          if (f.suit > 0) found.add(M('抱えている訴訟 {0}', [Y(c.cap * f.suit)]));
          if (f.flight > 0) found.add(M('買われると辞めそうな人が多い（統合で約{0}が辞める）', [pct(f.flight * 100)]));
          N(found.isEmpty ? M('{0}の調べが終わりました。大きな問題は見つかりませんでした', [Nm(c.name)]) : M('{0}の調べが終わりました。見つかったこと：{1}', [Nm(c.name), J(found)]), found.isEmpty ? 'good' : 'bad');
          // 見つかった問題の分だけ、上乗せを下げて申し入れる
          d.prem = math.max(.1, d.prem - f.offDebt - f.suit);
          d.stage = 'offer';
          d.left = 1;
        case 'offer':
          final price = dealPrice(c, d);
          if (d.pay == 'cash' && cash < price) {
            corp.deals.remove(d);
            N(M('{0}を買うお金（{1}）が足りず、話は流れました', [Nm(c.name), Y(price)]), 'bad');
            continue;
          }
          if (rnd() > dealChance(c, d)) {
            corp.deals.remove(d);
            c.rel -= 20;
            tieRec(c, 'g', M('TOBを仕掛けた'));
            cash -= price * .01;
            N(M('{0}の株主は買い付けに応じませんでした（助言の手数料 {1}）', [Nm(c.name), Y(price * .01)]), 'bad');
            continue;
          }
          final rv = reviewOf(c);
          d.block = rv.$2;
          d.divest = rv.$3;
          d.stage = 'review';
          d.left = rv.$1;
          if (rv.$1 > 1) N(M('{0}の株主が応じました。合わせたシェアが大きいため、当局の審査に入ります（約{1}か月）', [Nm(c.name), rv.$1]));
        case 'review':
          // 根回し上手がいると、当局の審査で止められにくい（1.1.0+33）
          if (d.block > 0 && rnd() < d.block * trBlockF()) {
            corp.deals.remove(d);
            N(M('独禁法の審査で、{0}の買収は止められました', [Nm(c.name)]), 'bad');
            chron('buy', M('{0}の買収は独禁法の審査で止められた', [Nm(c.name)]));
            continue;
          }
          d.stage = 'close';
          d.left = 1;
        case 'close':
          corp.deals.remove(d);
          N(closeDeal(c, d), 'big');
      }
    }
  }

  /// 手続き（払って株を受け取り、のれんを付け、統合を始める。調べていなければ隠れた問題がここで出る）
  String closeDeal(Company c, MaDeal d) {
    final f = finOf(c);
    final price = dealPrice(c, d);
    final before = pctOf(c);
    final need = d.target - before;
    if (d.pay == 'swap') {
      final rest0 = c.cap * need / 100 * (1 + d.prem);
      final n = rest0 / (cap + rest0);
      final k = 1 - n;
      _dilute(k);
      sh.float = sh.float * k + n * 100;
    } else {
      cash -= price;
    }
    final fromFloat = math.min(need, floatOf(c));
    c.fam = math.max(0, c.fam - math.max(0, need - fromFloat));
    c.stakePlayer = d.target;
    c.rel -= 10;
    // のれん＝払った値段−相手の正味の値打ち（店などの値打ち＋現金−借金）×買った割合
    final book = math.max(0.0, coUnits(c) == 0 ? 0 : c.biz.fold(0.0, (s, b) => s + (b.u + b.uy) * coUnitCapex(b.ind) * .6) + c.cash - f.debt);
    f.gw += math.max(0.0, price - book * need / 100);
    f.plan = math.max(f.plan, c.profit * 12);
    final m = clampI(12 + (c.cap / math.max(1, cap) * 18).round() + (cultureOf(c) != culture ? 6 : 0), 12, 36);
    f.integ = m;
    f.integAll = m;
    f.attr = 0;
    // 審査で求められた分の店などを手放す
    if (d.divest > 0) {
      for (final b in c.biz) {
        b.u *= 1 - d.divest;
        b.uy *= 1 - d.divest;
      }
    }
    final out = <Object?>[];
    // 目利きがいると、調べなくても帳簿の嘘に気づいて手を打てる（1.1.0+33）
    if (f.dd == 0 && anyTr('eye')) {
      if (f.offDebt > 0 || f.suit > 0) out.add(M('目利きの部下が帳簿の嘘に気づき、隠れた借金と訴訟を前の持ち主に引き取らせました'));
      f.dd = 1;
    }
    if (f.dd == 0) {
      // 調べずに買った: 隠れた問題が、ここで表に出る
      if (f.offDebt > 0) {
        final x = c.cap * f.offDebt;
        c.cash -= x;
        out.add(M('買ったあとに、帳簿に載っていない借金{0}が見つかりました', [Y(x)]));
      }
      if (f.suit > 0) {
        final x = c.cap * f.suit;
        c.cash -= x;
        out.add(M('買った会社が訴訟に負け、{0}を払いました', [Y(x)]));
      }
      f.dd = 1;
    }
    if (c.parent != 'player' && d.target > 50) {
      c.parent = 'player';
      rivalDefeated(c);
      presXp('zai', 4, big: true);
      chron('buy', M(c.rival != null ? '{0}（宿敵）の株を{1}握り、子会社にした' : '{0}の株を{1}握り、子会社にした', [Nm(c.name), pct(pctOf(c))]));
    }
    calcAll();
    // 株式交換で丸ごと買ったときは、そのまま合併する
    if (d.pay == 'swap' && canMerge(c)) {
      return Cat([M('株式交換で{0}を丸ごと買いました。あなたの持ち株は{1}に下がりました', [Nm(c.name), pct(sh.own)]), merge(c, viaSwap: true), ...out], ja: '。', en: '. ');
    }
    return Cat([
      M('{0}を買いました（{1}・上乗せ{2}）。統合に約{3}か月かかります', [Nm(c.name), Y(price), pct(d.prem * 100), m]),
      ...out
    ], ja: '。', en: '. ');
  }

  /// 統合の進み（そのあいだは人が辞め、事業の力が少し落ちる。終われば戻る）と、年に一度の減損の見直し
  void integMonthly(void Function(String, [String]) N) {
    for (final c in subs()) {
      final f = c.fin;
      if (f == null) continue;
      if (f.integ > 0) {
        final rate = (.006 + f.flight / math.max(1, f.integAll)) * (cultureOf(c) != culture ? 1.4 : 1);
        f.attr += rate;
        for (final b in c.biz) {
          b.power *= 1 - rate * .5;
        }
        f.integ--;
        if (f.integ == 0) N(M('{0}の統合が終わりました（そのあいだに約{1}が辞めました）', [Nm(c.name), pct(f.attr * 100)]), 'good');
      }
      // 年に一度、のれんの値打ちを見直す: 買ったときの見込みの6割に届かなければ減損
      if (q == 12 && f.gw > 0 && f.plan > 0 && c.profit * 12 < f.plan * .6) {
        final cut = f.gw * clampD(1 - c.profit * 12 / f.plan, .2, 1);
        f.gw -= cut;
        f.impaired += cut;
        corp.shock *= 1 - clampD(cut / math.max(1, cap), 0, .3);
        N(M('{0}が買ったときの見込みに届かず、のれんを{1}減損しました。株が売られました', [Nm(c.name), Y(cut)]), 'bad');
        chron('buy', M('{0}ののれんを{1}減損した', [Nm(c.name), Y(cut)]));
      }
    }
  }

  // ===== 取引先（大口の客） =====
  /// 会社や役所に売る業種か（大口の客を持つ）
  bool hasClients(Biz b) => profileOf(indm[b.ind]!).cust != 'b2c';

  void clientsMonthly(void Function(String, [String]) N) {
    final ids = {for (final b in biz) b.id};
    corp.clients.removeWhere((k, _) => !ids.contains(k));
    for (final b in biz) {
      if (!hasClients(b) || b.rev <= 0) continue;
      var cl = corp.clients[b.id];
      if (cl == null) {
        final gov = profileOf(indm[b.ind]!).cust == 'gov';
        final pool = cos.where((c) => c.alive && c.parent != 'player' && c.tier == 0 && c.cap > rev * 12).toList();
        final who = gov || pool.isEmpty ? 0 : pick(pool).id;
        cl = Client(co: who, share: gov ? .3 + rnd() * .4 : .15 + rnd() * .4, since: year);
        corp.clients[b.id] = cl;
        continue;
      }
      // 頼りすぎるほど、取引を切られたときの痛みが大きい（年に約5%の見込みで、次の入札や契約の見直しで切られる）
      // 記憶力が抜群の人がいると、半分は客をつなぎ止める（1.1.0+33。乱数は別の並び）
      if (rnd() < .003 && !trKeepClient(b, N)) {
        final lost = cl.share;
        // 切られた客の分のうち、半分ほどはほかの客で埋まる
        b.power *= 1 - lost * .5;
        final who = cl.co == 0 ? M('役所') : Nm(coById(cl.co)?.name ?? '?');
        N(M('「{0}」の大口の客（{1}）との取引が切られました。売上の約{2}を失います', [I(b.ind), who, pct(lost * 100)]), 'bad');
        corp.clients[b.id] = Client(co: cl.co, share: .1 + rnd() * .15, since: year);
      }
    }
  }

  /// 取引先の会社が倒れた・買われた（大口の客なら、売掛金が戻らず売上も減る）
  void clientGone(Company c, void Function(String, [String]) N, {Company? bought}) {
    for (final e in corp.clients.entries.toList()) {
      if (e.value.co != c.id) continue;
      final b = biz.where((x) => x.id == e.key).firstOrNull;
      if (b == null) continue;
      if (bought != null) {
        e.value.co = bought.id;
        continue;
      }
      final share = e.value.share;
      final lost = b.rev * share * math.max(1, profileOf(indm[b.ind]!).payLag);
      cash -= lost;
      b.power *= 1 - share * .8;
      corp.clients[e.key] = Client(co: 0, share: .1, since: year);
      N(M('大口の客の{0}が倒れ、「{1}」の売掛金{2}が戻らなくなりました', [Nm(c.name), I(b.ind), Y(lost)]), 'bad');
    }
  }

  /// 取引先を広げる（営業の時間と費用で、大口の客の割合を下げる）
  double spreadCost(Biz b) => b.rev * .5 + 5e6 * nom();

  String spreadClients(Biz b) {
    final cl = corp.clients[b.id];
    if (cl == null || cl.share <= .1) return M('大口の客に頼りすぎてはいません');
    final nt = needT('deal');
    if (nt != null) return nt;
    final cost = spreadCost(b);
    if (cash < cost) return M('お金が足りません');
    cash -= cost;
    useT('deal');
    cl.share = math.max(.08, cl.share * .7);
    presXp('ei', 2);
    return M('新しい客を回り、大口の客の割合を{0}に下げました', [pct(cl.share * 100)]);
  }
}
