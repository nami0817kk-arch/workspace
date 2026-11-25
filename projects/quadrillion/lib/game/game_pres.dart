// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

// ===== 社長の腕は、事業を進める中で磨かれる（1.1.0+32） =====
// 「腕を磨く」の行動は無くした。実際にやったことで腕ごとに経験がたまり、たまると腕が1上がる。
// 目安は1つの腕で1〜2年に+1、30年で+15〜25。高いほど伸びにくく、50代から鈍り、65歳を過ぎると少しずつ落ちる。
// 決まった計算だけで、ゲームの乱数は使わない（乱数の並びがずれない）。

/// 1か月にたまる経験の上限（腕ごと）。同じ手を何度も繰り返しても、それ以上はたまらない
const double presXpCap = 3;

/// 腕を1上げるのに要る経験（今の腕が高いほど多い）
double presNeedOf(int v) => 8 + math.max(0, v - 40) * .35;

/// 腕ごとの「何をすると伸びるか」
const LMap presGrowHow = LMap({
  'tou': '人を雇う・責任者を置く・会社の人数が増える',
  'kai': '商品を作る・新しい事業を始める・工場や設備を足す・技術の世代を乗り換える',
  'ei': '自分で見ている事業の売上が伸びる・店を開く・新しい国や客をつかむ',
  'zai': '借りる・返す・買収・上場・事業を売る・資金繰りの危機を乗り切る',
});

extension GamePres on Game {
  /// 社長の手で経験をためる（月の終わりに、1か月の上限までが腕の経験になる）
  /// [big] は一度きりの大きな山（上場・合併など）で、1か月の上限に数えない
  void presXp(String k, double v, {bool big = false}) {
    if (v <= 0) return;
    final key = big ? '$k!' : k;
    pres.pend[key] = (pres.pend[key] ?? 0) + v;
  }

  /// 今の腕を1上げるのに要る経験
  double presNeed(String k) => presNeedOf(pres.ab[k]!);

  /// たまった経験の進み具合（0〜1）
  double presXpFrac(String k) => pres.ab[k]! >= 99 ? 1 : clampD((pres.xp[k] ?? 0) / presNeed(k), 0, 1);

  /// 年齢で経験のたまり方が変わる（50代から鈍り、65歳を過ぎるとわずか）
  double presAgeF() => pres.age < 50
      ? 1
      : pres.age < 65
          ? .6
          : .3;

  /// 会社の人数（部下と現場の人のおおよそ）
  double presHeads() {
    var n = staff.length.toDouble();
    for (final b in biz) {
      if (b.model == 'fc') continue;
      final per = crewPerHead(b);
      if (per > 0) n += crewOf(b) / per;
    }
    return n;
  }

  /// 月の終わりに、たまった経験を腕に変える（nextQuarter から。乱数は使わない）
  void presGrowMonth(void Function(String, [String]) N) {
    // 会社の人数がいちばん多かったときを超えた
    final h = presHeads();
    if (pres.hd <= 0) {
      pres.hd = h;
    } else if (h > pres.hd) {
      presXp('tou', math.log(h / pres.hd) * 7);
      pres.hd = h;
    }
    // 自分で見ている事業の売上が伸びた
    var r0 = 0.0, r1 = 0.0;
    for (final b in biz) {
      if (mgrOf(b) != null || b.prevRev <= 0) continue;
      r0 += b.prevRev;
      r1 += math.max(0.0, b.rev);
    }
    if (r0 > 0 && r1 > r0) presXp('ei', math.min(1.5, (r1 / r0 - 1) * 40));
    // 資金繰りの危機（銀行の管理・払えない月）に入った／乗り切った
    if (bankCtl > 0 || missed >= 10) pres.crisis = math.max(pres.crisis, 1);
    var bonus = <String, double>{};
    if (pres.crisis > 0 && bankCtl == 0 && missed == 0 && cash > 0 && pre > 0) {
      // 倒れかけて立て直すと、多めに伸びる（民事再生のあとはもっと）
      final big = pres.crisis >= 2;
      bonus = {'zai': big ? 14 : 7, 'tou': big ? 7 : 3};
      pres.crisis = 0;
      N(M('資金繰りの危機を乗り切りました。財務と統率の経験がたまりました'), 'good');
    }
    final af = presAgeF();
    for (final k in abKeys) {
      final add = (math.min(presXpCap, pres.pend[k] ?? 0) + (pres.pend['$k!'] ?? 0) + (bonus[k] ?? 0)) * af;
      if (add <= 0) continue;
      var x = (pres.xp[k] ?? 0) + add;
      final a0 = pres.ab[k]!;
      var a = a0;
      while (a < 99 && x >= presNeedOf(a)) {
        x -= presNeedOf(a);
        a++;
      }
      if (a >= 99) x = 0;
      pres.xp[k] = x;
      if (a > a0) {
        pres.ab[k] = a;
        N(M('{0}の腕が上がりました（{1} → {2}）', [D(ABN.ja[k]!), a0, a]), 'good');
      }
    }
    pres.pend.clear();
  }
}
