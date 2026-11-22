import 'life.dart';
import 'data.dart';
import 'game.dart';
import 'rng.dart';

const _lettered = ['priest', 'merchant', 'lowsamurai', 'samurai', 'kokujin', 'daimyo'];
const _martial = ['ronin', 'ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'daimyo', 'ninja'];

/// 故郷の主家。
String homeLord(Game g) => g.rng.pick(kRegions.firstWhere((r) => r.n == g.l.region).f);

/// 子ども期（5〜14歳）の行動。
List<ActionDef> buildChildActions(Game g) {
  Life l() => g.l;
  return [
    ActionDef('help', '家の手伝い', '銭を稼ぐ（体力-2）', () {
      l().gold += g.rng.range(1, 2);
      l().hp -= 2;
      if (g.rng.chance(.25) && l().bu < 60) l().bu++;
      g.j(-1);
      return '朝から晩まで家の手伝いに明け暮れた。';
    }),
    ActionDef('learn', '読み書きを習う', '知を上げる（通える子は限られる）', () {
      final p = _lettered.contains(l().cls.id) ? 1.0 : (l().cls.id == 'beggar' ? .15 : .45);
      if (g.rng.chance(p)) {
        final u = g.rng.range(1, 3) + (l().cls.id == 'priest' ? 1 : 0);
        l().chi = clampInt(l().chi + u, 0, 99);
        g.j(1);
        return '寺や師のもとで学び、知が$u上がった。';
      }
      return '学ぶ機会はなかった。字を覚えられる子は、ほんの一握りだ。';
    }),
    ActionDef('martial', '武芸の真似事', '武を上げる（体力-2）', () {
      final m = _martial.contains(l().cls.id) ? 1.0 : .5;
      final u = g.rng.chance(m) ? g.rng.range(1, 3) : 1;
      l().bu = clampInt(l().bu + u, 0, 99);
      l().hp -= 2;
      return '棒切れを振り回して励み、武が$u上がった。';
    }),
    ActionDef('play', '野山で遊ぶ', '体力と幸福', () {
      l().hp = l().hp + 8 > l().maxhp ? l().maxhp : l().hp + 8;
      g.j(6);
      return '野山を駆け回って、心から笑った。';
    }),
    ActionDef('friend', '友と過ごす', '人間関係と幸福', () {
      l().net += g.rng.range(1, 2);
      g.j(3);
      return '村の子らと、日が暮れるまで過ごした。';
    }),
  ];
}

/// 大人（15歳〜）の行動。
List<ActionDef> buildActions(Game g) {
  final rng = g.rng;
  return [
    ActionDef('work', '働く', '銭を稼ぐ（体力-3）', () {
      final l = g.l;
      var gain = l.cls.id == 'merchant' ? rng.range(6, 16) + l.sei ~/ 10 : rng.range(2, 6);
      if (g.has('abacus')) gain = (gain * 1.5).round();
      l.gold += gain;
      l.hp -= 3;
      if (l.sei < 90 && rng.chance(.25)) l.sei++;
      return '汗を流して働き、銭$gain貫を得た。';
    }, ok: () => g.l.rank < 5),
    ActionDef('train', '武芸を鍛える', '武を上げる（体力-2）', () {
      final l = g.l;
      final up = l.bu > 70 ? (rng.chance(.5) ? 1 : 0) : rng.range(1, 3);
      l.bu = clampInt(l.bu + up, 0, 99);
      l.hp -= 2;
      return up > 0 ? '木刀を振り続け、武が$up上がった。' : '鍛錬を積んだが、これ以上の伸びは感じない。';
    }),
    ActionDef('study', '学問に励む', '知を上げる', () {
      final l = g.l;
      final up = l.chi > 70
          ? (rng.chance(.5) ? 1 : 0)
          : rng.range(1, 3) + (l.cls.id == 'priest' ? 1 : 0);
      l.chi = clampInt(l.chi + up, 0, 99);
      g.j(1);
      return up > 0 ? '書を繙き、知が$up上がった。' : '読み尽くした感がある。';
    }),
    ActionDef('social', '人と会う', '人間関係と幸福', () {
      final l = g.l;
      final n = rng.range(1, 2) + (l.mi > 60 ? 1 : 0);
      l.net += n;
      if (rng.chance(.3)) l.mi = clampInt(l.mi + 1, 0, 99);
      l.gold = l.gold > 0 ? l.gold - 1 : 0;
      g.j(3);
      return '酒を酌み交わし、顔を売った。人間関係+$n。';
    }),
    ActionDef('rest', '休む', '体力と幸福を回復', () {
      final l = g.l;
      l.hp = l.hp + 30 > l.maxhp ? l.maxhp : l.hp + 30;
      g.j(5);
      return '身を休め、心身を取り戻した。';
    }),
    ActionDef('marry', '妻を娶る', '縁談を探す', () {
      final l = g.l;
      final p = clampD(.35 + l.mi / 200 + l.net * .02 + l.fame / 300 + l.rank * .04, .1, .9);
      if (rng.chance(p)) {
        l.married = true;
        l.net += 3;
        l.gold += 5 + l.rank * 4;
        l.hp = l.hp + 10 > l.maxhp ? l.maxhp : l.hp + 10;
        g.j(12);
        return l.female ? '縁談がまとまり、嫁いだ。' : '縁談がまとまり、妻を迎えた。家に灯がともる。';
      }
      g.j(-2);
      return '縁談は流れてしまった。';
    }, labelF: '嫁ぐ', ok: () => !g.l.married && g.age >= 16),
    ActionDef('serve', '仕官を願う', '主家に仕える', () {
      final l = g.l;
      final home = homeLord(g);
      final opts = [home];
      final pool = g.alive.map((f) => f.name).where((n) => n != home).toList();
      while (opts.length < 4 && pool.isNotEmpty) {
        opts.add(pool.removeAt(rng.range(0, pool.length - 1)));
      }
      final base = .25 +
          (l.bu + l.chi + l.mi) / 400 +
          l.net * .03 +
          l.fame / 200 +
          (l.gold / 200 > .2 ? .2 : l.gold / 200) +
          (l.cls.id == 'ronin' ? .1 : 0) -
          (l.female ? .05 : 0);
      g.ask('仕官先を選ぶ', '門を叩く先を選べ。故郷の主家は話が通りやすい。', [
        for (final n in opts)
          Choice('$n家（勢力${g.fa[n]!.power.round()}）${n == home ? '・故郷' : ''}', () {
            final p = clampD(base + (n == home ? .15 : 0), .1, .9);
            if (rng.chance(p)) {
              l.rank = 1;
              if (l.maxRank < 1) l.maxRank = 1;
              l.lord = n;
              l.fav = 20;
              l.merit = 0;
              l.ronin = false;
              g.j(4);
              return '$n家に${g.rk[1]}として取り立てられた！';
            }
            g.j(-3);
            return '$n家に願い出たが、門前払いを食らった。';
          }),
        Choice('やめる', null, true),
      ], after: g.endTurn);
      return null;
    }, labelF: '奉公に上がる', ok: () => g.l.rank == 0),
    ActionDef('war', '合戦に出る', '手柄を立てる（命の危険）', () {
      g.ask('出陣', '主命により合戦へ。どの持ち場に就く？', [
        Choice('先陣を駆ける（大功・危険大）', () => g.battle('van')),
        Choice('本陣に控える（中功・危険中）', () => g.battle('main')),
        Choice('後詰めにまわる（小功・安全）', () => g.battle('rear')),
        Choice('やめておく', null, true),
      ], after: g.endTurn);
      return null;
    }, danger: true, ok: () => g.l.rank >= 1 && g.l.rank < 8 && g.canFight),
    ActionDef('gov', '内政に励む', '功・信頼・銭', () {
      final l = g.l;
      final m = (l.sei / 8).round() + rng.range(1, 4);
      l.merit += m;
      l.fav = clampInt(l.fav + rng.range(2, 5), 0, 100);
      l.gold += (l.sei / 6).round();
      if (l.lord != null && g.fa[l.lord] != null) g.fa[l.lord]!.power += .3;
      return l.female ? '奥向きを切り盛りし、功$mを積んだ。' : '普請や年貢の取りまとめに励み、功$mを積んだ。';
    }, labelF: '家政を取り仕切る', ok: () => g.l.rank >= 3 && g.l.rank < 8),
    ActionDef('recruit', '兵を集める', '銭で兵を雇う', () {
      final l = g.l;
      final cap = kTroopCap[l.rank];
      var n = cap - l.troops;
      if (l.gold < n) n = l.gold;
      final lim = 10 + l.mi ~/ 10;
      if (lim < n) n = lim;
      if (n <= 0) return l.troops >= cap ? 'これ以上は養えない。位が上がれば兵も増やせる。' : '銭が足りず、兵を雇えなかった。';
      l.gold -= n;
      l.troops += n;
      return '銭$n貫で兵$n人を雇った（計${l.troops}）。';
    }, ok: () => g.l.rank >= 2 && g.l.rank < 8 && g.canFight),
    ActionDef('scheme', '調略を仕掛ける', '敵将・敵家を切り崩す', () {
      final l = g.l;
      final p = .3 + (l.chi + l.mi) / 300 + l.un / 500;
      if (rng.chance(p)) {
        final m = 10 + rng.range(0, 8);
        final t = l.female ? 0 : rng.range(3, 10);
        l.merit += m;
        l.fav += 4;
        l.fame += 3;
        l.troops += t;
        return '工作が成功！${t > 0 ? '敵の兵$tを寝返らせ、' : ''}功$m。';
      }
      l.fav -= 6;
      l.hp -= 10;
      g.j(-3);
      return '工作は露見した。信頼を損ねてしまった。';
    }, labelF: '奥向きの工作', ok: () => g.l.rank >= 3 && g.l.rank < 8),
    ActionDef('gift', '進物を贈る', '銭10貫で信頼を得る', () {
      final l = g.l;
      l.gold -= 10;
      final f = rng.range(4, 8) + l.mi ~/ 20;
      l.fav = clampInt(l.fav + f, 0, 100);
      return '主君に進物を贈り、信頼が$f増した。';
    }, ok: () => g.l.rank >= 1 && g.l.rank < 8, dis: () => g.l.gold < 10 ? '銭が足りない' : null),
    ActionDef('betray', '下剋上', '主家を乗っ取る', () {
      final p = g.betrayChance();
      g.ask('下剋上', '主家を討つか。成功すれば大名の座。失敗すれば命はない。\n成功率の目安：約${(p * 100).round()}%', [
        Choice('兵を挙げる！', () => g.doBetray(p), false, true),
        Choice('時期を待つ', null, true),
      ], after: g.endTurn);
      return null;
    }, danger: true, ok: () => g.l.rank >= 5 && g.l.rank < 8 && g.l.lord != null && g.canFight),
    ActionDef('develop', '領国を富ませる', '勢力＋銭', () {
      final l = g.l;
      final f = g.fa[l.lord]!;
      final up = 1 + l.sei / 25 + rng.range(0, 2);
      f.power += up;
      l.gold += (up * 4).round();
      return '検地と治水で国を整え、勢力が${up.toStringAsFixed(1)}伸びた。';
    }, ok: () => g.l.rank == 8),
    ActionDef('arm', '軍備を整える', '銭20貫で勢力を強化', () {
      final l = g.l;
      l.gold -= 20;
      final up = 3 + rng.range(0, 3) + l.bu / 30;
      g.fa[l.lord]!.power += up;
      return '兵を集め鉄砲を揃え、勢力が${up.toStringAsFixed(1)}伸びた。';
    }, ok: () => g.l.rank == 8, dis: () => g.l.gold < 20 ? '銭が足りない' : null),
    ActionDef('invade', '侵攻する', '隣国を攻め取る', () {
      final l = g.l;
      final me = g.fa[l.lord]!;
      final tg = g.alive.where((f) => f != me).toList()..sort((a, b) => a.power.compareTo(b.power));
      final sk = 1 + (l.bu + l.chi + l.un) / 600;
      g.ask('侵攻', 'どの国を攻める？', [
        for (final t in tg.take(8))
          Choice('${t.name}家（勢力${t.power.round()}）勝算約${(100 * g.invadeP(me, t, sk)).round()}%',
              () => g.doInvade(t, sk)),
        Choice('やめる', null, true),
      ], after: g.endTurn);
      return null;
    }, danger: true, ok: () => g.l.rank == 8),
  ];
}
