// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 任せたときに責任者が月に使えるお金の段（その業種の元手の何倍か。0 は使わせない）。1.0.0+20
const List<int> delegMults = [0, 1, 3, 10];

/// 任せた責任者が打った手1つ（月の報告のまとめに使う。保存しない）
class DelegAct {
  /// 打った月（月を進めたあとの turn）
  final int turn;

  /// 事業の番号と業種
  final int biz;
  final String ind;

  /// 種類: crew 人を雇う / build 店・工場を増やす / ext 広げる / dev 商品 / ad 広告 / price 値付け / none 何もしなかった
  final String k;
  final double cost;
  const DelegAct(this.turn, this.biz, this.ind, this.k, this.cost);
}

/// 責任者が選べる手1つ（種類・値段・打つ中身）
class _DelegOpt {
  final String k;
  final double cost;
  final String Function() run;
  const _DelegOpt(this.k, this.cost, this.run);
}

/// 事業を責任者に任せる（1.0.0+20。extras の内側。任せた事業が無ければ乱数も使わない）。
///
/// ・任せる／自分で動かす はいつでも切り替えられ、手は使わない。任せても、社長が自分で手を打つのは今までどおりできる
/// ・任せた事業は、毎月、責任者が自分で手を1つ打つ（人を雇う・店や工場を増やす／広げる・商品を作る・広告・値付け）。
///   値段と効き目は社長が打つときと同じ。社長の手は使わない
/// ・使えるお金は、事業ごとの「月の枠」（その業種の元手の 0／1／3／10 倍）まで。会社の3か月分の固定費は手元に残す
/// ・腕（その業種に効く能力）が低いほど、様子見で1か月を空費したり、的外れな手を打ったりする。
///   性格でも変わる（博打打ち・野心家は大きく張る、慎重な人は増やさない、技術バカは商品、人たらしは広告、倹約家は広告を打たない）
/// ・店・工場と商品は1件ずつ（前のものが出来上がるまで、次を始めない）。社長は手があるかぎり重ねて打てる
/// ・海外・売る・分社・稼ぎ方の変更・値下げ合戦・裏の手は任せない（社長が決める）
/// ・任せた事業の責任者は、自分で打てる手を経営会議には持ってこない（game_turn.dart の _unitProposal）
///
/// 釣り合い（test/h_balance_test.dart の頭に数字）: 同じお金あたりの伸びの見込みは、人が外さずに最善手を打ったときの 7〜9割。
/// 30年の自動プレイでは「半分任せて、残りは自分で」がいちばん伸び、「全部任せる」が1つだけの勝ち筋にはならない
extension GameDeleg on Game {
  /// 任せられるか（責任者がいる事業だけ）
  bool canDeleg(Biz b) => extras && staffById(b.mgr) != null;

  /// 今、任せているか（責任者がいなくなっていたら、任せていない）
  bool delegated(Biz b) => b.deleg && canDeleg(b);

  /// 任せる・自分で動かすを切り替える（手は使わない）
  void setDeleg(Biz b, bool on) {
    b.deleg = on && canDeleg(b);
    if (!b.deleg) b.did = null;
  }

  /// 月の枠の段を決める（手は使わない）
  void setBudget(Biz b, int i) => b.budget = clampI(i, 0, delegMults.length - 1);

  /// 月の枠（その業種の元手の何倍かの固定額。時代の物価だけが乗る）
  double delegBudget(Biz b) => capexOf(indm[b.ind]!) * delegMults[clampI(b.budget, 0, delegMults.length - 1)];

  /// 月の枠の段ごとの額
  double delegBudgetAt(Biz b, int i) => capexOf(indm[b.ind]!) * delegMults[i];

  /// 責任者がいて、まだ任せていない事業
  List<Biz> delegable() => biz.where((b) => canDeleg(b) && !b.deleg).toList();

  /// 任せている事業
  List<Biz> delegatedBiz() => biz.where(delegated).toList();

  /// 責任者のいる事業をまとめて任せる（手は使わない）
  String delegAll() {
    final l = delegable();
    if (l.isEmpty) return M(biz.any(delegated) ? '責任者のいる事業は、もう全部任せています' : '責任者のいる事業がありません。先に責任者を置いてください');
    for (final b in l) {
      setDeleg(b, true);
    }
    return M('{0}つの事業を責任者に任せました。毎月、月の枠の中で、責任者が自分で手を打ちます（社長の手は使いません）', [l.length]);
  }

  /// 任せた事業をまとめて自分に戻す（手は使わない）
  String undelegAll() {
    final l = biz.where((b) => b.deleg).toList();
    if (l.isEmpty) return M('任せている事業はありません');
    for (final b in l) {
      setDeleg(b, false);
    }
    return M('{0}つの事業を、自分で動かすように戻しました', [l.length]);
  }

  /// 責任者が手を付けずに残すお金（会社の毎月決まって出ていくお金の3か月分。給料・維持費・本社の経費・利息）
  double delegReserve() => (salaries() + biz.fold(0.0, (s, b) => s + b.upkeep) + hq + interest) * 3;

  /// 腕が足りずに外す確率（その業種に効く能力が 99 で 4%、50 で 22%、20 で 34%）
  double delegMiss(Biz b, Person p) => clampD(.42 - p.ab[indm[b.ind]!.key]! / 100 * .4, .04, .4);

  /// 毎月：任せた事業の責任者が手を1つ打つ
  void delegMonthly() {
    if (!extras) return;
    final acted = <int>{};
    for (final b in biz.toList()) {
      if (!b.deleg) continue;
      final p = staffById(b.mgr);
      if (p == null) {
        // 責任者が辞めた・外された事業は、自分で動かすに戻る
        b.deleg = false;
        b.did = null;
        continue;
      }
      // 打てるのは責任者1人につき月1つまで
      if (!acted.add(p.id)) {
        b.did = M('今月は別の事業で手いっぱいでした');
        continue;
      }
      b.did = _delegMove(b, p);
    }
    if (delegLog.length > 600) delegLog.removeRange(0, delegLog.length - 600);
  }

  /// 値付けの見直し（変えるなら新しい値付け）
  String? _delegPrice(Biz b, Person p) {
    final t = p.trait;
    if (b.war > 0 || b.attack > 0) return null;
    if (b.price == 'cut' && b.share >= .12 && t != 'gambler') return 'normal';
    if (b.price == 'normal' && b.share >= .2 && (t == 'careful' || t == 'frugal' || t == 'tech')) return 'premium';
    if (b.price == 'premium' && b.share < .05) return 'normal';
    // 店などが売り切れているときは、値下げしても客を入れる場所が無い（1.1.0+26）
    if (b.price == 'normal' && p.amb > 75 && b.share < .08 && t != 'charm' && t != 'careful' && !(unitsOn && (capKOf[b.id] ?? 1) < .97)) return 'cut';
    return null;
  }

  /// 店・工場か商品の仕掛かりがあるか（責任者は、それが出来上がるまで次を始めない）
  bool _delegBusy(Biz b) => b.pipe.any((x) => x.k == 'build' || x.k == 'dev' || x.k == 'hub');

  /// 責任者が今月選べる手（月の枠と手元のお金に収まるものだけ）
  List<_DelegOpt> _delegOpts(Biz b, Person p, double room) {
    final t = p.trait;
    final bold = t == 'gambler' || p.amb > 75;
    final steady = t == 'careful';
    final out = <_DelegOpt>[];
    // 足りない人を雇う（枠に収まらなければ、収まる人数だけ）
    var need = crewNeedPeople(b);
    if (need > 0) {
      if (hireCost(b, need) > room) need = (room / hireCost(b, 1)).floor();
      if (need > 0) {
        final n = need, c = hireCost(b, n);
        out.add(_DelegOpt('crew', c, () {
          cash -= c;
          _addHeads(b, n);
          return M('現場の人を{0}人雇いました（{1}）', [n, Y(c)]);
        }));
      }
    }
    // 店・工場と商品は、1件ずつ。前に始めたものが出来上がるまで、次は始めない
    // （社長は手があるかぎり重ねて打てる。責任者は、始めたものを仕上げてから次へ進む）
    if (!_delegBusy(b)) {
      // 張り方：博打打ち・野心家は、枠に収まるいちばん大きい単位。ふつうの人は、4割は1段小さく張る。慎重な人はいつも1段小さく
      int size(int top) => math.max(
          0,
          top -
              (bold
                  ? 0
                  : steady || rnd() < .4
                      ? 1
                      : 0));
      // 店・工場を増やす（慎重な人は増やさない）。払えなければ今あるものを広げる。
      // 1.1.0+26 から、店などの数の決まり（責任者・本部・拠点・物件・上限）に沿って、今いちばん要る手を打つ
      if (!steady && unitsOn) {
        final go = growOpt(b, room, want: bold ? 10 : 3);
        if (go != null) {
          out.add(_DelegOpt('build', go.cost, go.run));
        } else if (extendCost(b) <= room && b.upg < upgMax - 1e-9 && unitTotal(b) > 0) {
          final c = extendCost(b);
          out.add(_DelegOpt('ext', c, () {
            cash -= c;
            b.pipe.add(Pipe(k: 'build', cost: c, left: 1, ext: true));
            return M('今ある{0}を広げ始めました（{1}）', [uw(b), Y(c)]);
          }));
        }
      } else if (!steady) {
        final top = [2, 1, 0].where((i) => buildCost(b, buildUnits[i]) <= room).firstOrNull;
        final bi = top == null ? null : size(top);
        if (bi != null) {
          final n = buildUnits[bi], c = buildCost(b, n);
          out.add(_DelegOpt('build', c, () {
            cash -= c;
            b.pipe.add(Pipe(k: 'build', cost: c, left: b.model == 'fc' ? 1 : ri(1, 2)));
            return M('{0}増やし始めました（{1}）', [unitsOf(b, n), Y(c)]);
          }));
        } else if (extendCost(b) <= room) {
          final c = extendCost(b);
          out.add(_DelegOpt('ext', c, () {
            cash -= c;
            b.pipe.add(Pipe(k: 'build', cost: c, left: 1, ext: true));
            return M('今ある{0}を広げ始めました（{1}）', [uw(b), Y(c)]);
          }));
        }
      }
      // 商品を作る
      final dTop = [2, 1, 0].where((i) => devCost(b, i) <= room).firstOrNull;
      final di = dTop == null ? null : size(dTop);
      if (di != null) {
        final c = devCost(b, di);
        out.add(_DelegOpt('dev', c, () {
          cash -= c;
          b.pipe.add(Pipe(k: 'dev', cost: c, left: ri(devMonths[di].$1, devMonths[di].$2), sz: di));
          return M('{0}を始めました（{1}）', [devName(di), Y(c)]);
        }));
      }
    }
    // 広告（倹約家は打たない）
    final adC = invBase(b) * .25;
    if (b.ad == 0 && t != 'frugal' && adC <= room) {
      out.add(_DelegOpt('ad', adC, () {
        cash -= adC;
        b.ad = 6;
        b.adCost = 0;
        return M('広告を打ちました（{0}）', [Y(adC)]);
      }));
    }
    // 値付け（お金はかからない）
    final pr = _delegPrice(b, p);
    if (pr != null) {
      out.add(_DelegOpt('price', 0, () {
        b.price = pr;
        return M(pr == 'cut'
            ? '値段を安くしました'
            : pr == 'premium'
                ? '値段を高くしました'
                : '値段をふつうに戻しました');
      }));
    }
    return out;
  }

  /// 責任者が手を1つ選んで打つ。返すのは、やったこと（か、やらなかった理由）の1行
  String _delegMove(Biz b, Person p) {
    final t = p.trait;
    final cap = delegBudget(b);
    final room = math.min(cap, cash - delegReserve());
    final opts = _delegOpts(b, p, room);
    _DelegOpt? by(String k) => opts.where((o) => o.k == k).firstOrNull;
    String none(String why) {
      delegLog.add(DelegAct(turn, b.id, b.ind, 'none', 0));
      return M(why);
    }

    _DelegOpt? o;
    // 腕が足りないと、様子見で1か月を空費するか、的外れな手を打つ
    if (rnd() < delegMiss(b, p)) {
      if (opts.isEmpty || rnd() < .5) return none('様子を見ました');
      o = pick(opts);
    } else {
      // 1. 人が足りなければ雇う　2. 値付けを直す　3. 伸ばす（商品か店・工場）　4. 広告
      final short = b.model != 'fc' && b.power > 0 && crewEff(b) < crewWant(b) * .95;
      if (short) o = by('crew');
      o ??= by('price');
      if (o == null) {
        final ad = by('ad');
        if (ad != null && t == 'charm' && rnd() < .35) {
          o = ad;
        } else {
          final devFirst = rnd() <
              (t == 'tech' || t == 'genius'
                  ? .7
                  : t == 'gambler'
                      ? .5
                      : .4);
          final dev = by('dev'), bld = by('build') ?? by('ext');
          o = devFirst ? (dev ?? bld) : (bld ?? dev);
          o ??= ad ?? by('crew');
        }
      }
    }
    if (o == null) {
      if (cap <= 0) return none('月の枠が0なので、お金のかかる手は打ちませんでした');
      if (_delegBusy(b)) return none('仕掛かりが出来上がるのを待っています');
      if (room < cap) return none('会社の手元のお金を残すため、見送りました');
      return none('月の枠に収まる手がありませんでした');
    }
    final m = o.run();
    delegLog.add(DelegAct(turn, b.id, b.ind, o.k, o.cost));
    return m;
  }

  /// 月の報告に出す「任せた事業でやったこと」（[since] より後の月の分を1〜3行にまとめる。任せた事業が無ければ空）
  List<String> delegSummary(int since) {
    final acts = delegLog.where((a) => a.turn > since).toList();
    if (acts.isEmpty) return const [];
    final done = acts.where((a) => a.k != 'none').toList();
    final nBiz = <int>{for (final a in acts) a.biz}.length;
    final spent = done.fold(0.0, (s, a) => s + a.cost);
    int n(List<String> ks) => done.where((a) => ks.contains(a.k)).length;
    final parts = <String>[
      if (n(const ['crew']) > 0) M('人を雇う {0}', [n(const ['crew'])]),
      if (n(const ['build', 'ext']) > 0) M('店・工場を増やす {0}', [n(const ['build', 'ext'])]),
      if (n(const ['dev']) > 0) M('商品を作る {0}', [n(const ['dev'])]),
      if (n(const ['ad']) > 0) M('広告を打つ {0}', [n(const ['ad'])]),
      if (n(const ['price']) > 0) M('値付けを変える {0}', [n(const ['price'])]),
    ];
    final idle = acts.length - done.length;
    return [
      done.isEmpty
          ? M('任せた{0}つの事業で、責任者は手を打ちませんでした', [nBiz])
          : M('任せた{0}つの事業で、責任者が{1}つの手を打ちました（使ったお金 {2}）', [nBiz, done.length, Y(spent)]),
      if (parts.isNotEmpty) M('内訳：{0}', [J(parts)]),
      if (idle > 0 && done.isNotEmpty) M('手を打たなかったのは{0}回（様子見・枠やお金が足りない）', [idle]),
    ];
  }
}
