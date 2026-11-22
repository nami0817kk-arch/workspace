import 'adult.dart';
import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'life.dart';
import 'rng.dart';
import 'variety.dart';

/// 歩んだ道と死に方。最期の場面（1000本）は「道 × 死に方 × 縁のある人」で選ぶ
/// （2026-11-23 決定、CLAUDE.md）。ここには、その分け目になる
/// 死に方の種類・道の見分け方と、道ごとの岐路（商い・野・仏門・村・壮年と晩年・
/// 史実の大きな出来事・非業の死の危うさ）を置く。

/// 死に方の8種。
const kDeathKinds = <String, String>{
  'tenju': '天寿',
  'byo': '病',
  'senshi': '戦死',
  'seppuku': '切腹・処刑',
  'ansatsu': '暗殺',
  'sai': '災い・事故',
  'ue': '飢え',
  'yukue': '行方知れず',
};

/// 10の道（最期の本数の配分つき）。
const kWays = <String, (String, int)>{
  'young': ('幼くして亡くなる', 40),
  'village': ('村の暮らし', 70),
  'merchant': ('商いの道', 70),
  'priest': ('仏門', 80),
  'shadow': ('忍び・流れ者・野盗', 90),
  'samurai': ('足軽・侍', 130),
  'castle': ('城主・家老', 150),
  'daimyo': ('大名・下剋上', 180),
  'tenka': ('天下人', 70),
  'woman': ('女の道', 120),
};

/// その人生がどの道を歩んだか。終わった人生にも、途中の人生にも使える。
String lifeWay(Life l) {
  if (l.t ~/ 2 < 15) return 'young';
  if (l.victory || l.maxRank >= 9) return 'tenka';
  if (l.flags.contains('priesthood')) return 'priest';
  if (l.female && (l.maxRank >= 1 || l.flags.contains('onna_jo'))) {
    return 'woman';
  }
  if (l.maxRank >= 8) return 'daimyo';
  if (l.maxRank >= 5) return 'castle';
  if (l.maxRank >= 1) return 'samurai';
  if (l.flags.contains('way_merchant')) return 'merchant';
  if (l.flags.contains('way_outlaw') ||
      l.flags.contains('wanderer') ||
      l.cls.id == 'ninja') {
    return 'shadow';
  }
  if (l.cls.id == 'merchant') return 'merchant';
  return 'village';
}

int _yr(Game g, int a) => g.l.startYear + a;
void _heal(Life l, int n) => l.hp = l.hp + n > l.maxhp ? l.maxhp : l.hp + n;
int _c(int v) => clampInt(v, 0, 100);

String _childName(Game g) => g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF);

List<SceneDef> buildWayScenes() {
  int f(Game g, String tag) => g.l.focus[tag] ?? 0;
  bool free(Game g) =>
      g.l.rank == 0 &&
      !g.hasFlag('priesthood') &&
      !g.hasFlag('way_merchant') &&
      !g.hasFlag('way_outlaw') &&
      g.active;
  bool merchant(Game g) =>
      g.hasFlag('way_merchant') && g.l.rank == 0 && g.active;
  bool outlaw(Game g) => g.hasFlag('way_outlaw') && g.l.rank == 0;
  bool monk(Game g) => g.hasFlag('priesthood');
  bool villager(Game g) =>
      free(g) && const ['farmer', 'fisher', 'beggar'].contains(g.l.cls.id);

  return [
    // ==================================================================
    // 道に入る岐路
    // ==================================================================
    SceneDef(
      'merchant_start',
      16,
      45,
      (g) =>
          1.2 +
          f(g, 'work') * .25 +
          (g.l.cls.id == 'merchant' ? 3 : 0) +
          (g.hasFlag('apprentice') ? 1.5 : 0),
      free,
      (g, next) {
        g.ask('商いの誘い', '町の顔役が「お前さん、商いに向いている」と声をかけてきた。元手は貸すという。', [
          Choice.h('店を構える', '当たれば身分より銭がものを言う。借りは返さねばならない', () {
            g.setFlag('way_merchant');
            g.l.gold += 10;
            g.meet('商いの恩人', '町の顔役', 40);
            g.mark('町に小さな店を構え、商いの道に入った');
            return '借りた元手で、小さな店を構えた。';
          }),
          Choice.h('今の暮らしを続ける', '借りも作らず、儲けもない', () => '話は聞くだけにした。'),
        ], after: next);
      },
    ),

    SceneDef(
      'outlaw_join',
      16,
      45,
      (g) =>
          .6 +
          (g.l.gold < 3 ? 1.5 : 0) +
          (g.l.ronin ? 1.5 : 0) +
          (g.hasFlag('rival') ? .5 : 0),
      (g) => free(g) && !g.l.female,
      (g, next) {
        g.ask('野盗の頭', '山の野盗の頭が、腕を見込んで仲間に誘ってきた。「真っ当に生きて、何が残る」', [
          Choice.h('仲間に加わる', '食うには困らない。まっとうな道には戻りにくい', () {
            g.setFlag('way_outlaw');
            g.l.gold += 8;
            g.l.fame -= 5;
            g.meet('頭', '野盗の頭', 35);
            g.mark('山の野盗の仲間に加わった');
            return '山に入り、野盗の一味となった。';
          }),
          Choice.h('断る', '貧しくても、人の道からは外れない', () {
            g.j(1);
            return '頭は鼻で笑い、去っていった。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'wander_start',
      18,
      60,
      (g) => .8 + (g.l.ronin ? 1.5 : 0) + (g.l.joy < 30 ? 1 : 0),
      (g) => free(g) && !g.hasFlag('wanderer'),
      (g, next) {
        g.ask('旅の空', '生まれた土地に、もう未練はない。諸国を流れて生きる者たちの噂を聞いた。', [
          Choice.h('あてのない旅に出る', '自由になる。帰る場所はなくなる', () {
            g.setFlag('wanderer');
            g.setFlag('way_outlaw');
            g.j(4);
            g.mark('故郷を捨て、諸国を流れる身となった');
            return '草鞋をはき、あてのない旅に出た。';
          }),
          Choice.h('土地に根を張る', '暮らしは変わらない', () => '旅の噂は、聞き流した。'),
        ], after: next);
      },
    ),

    SceneDef(
      'late_shukke',
      30,
      75,
      (g) => .25 + (g.l.joy < 30 ? 1 : 0) + (g.hasFlag('temple') ? .5 : 0),
      (g) => !monk(g) && g.l.rank < 8,
      (g, next) {
        g.ask('出家の思い', '世の争いに、ふと疲れを覚えた。寺の鐘の音が、やけに胸に響く。', [
          Choice.h('髪を下ろす', '心は静まる。世の栄達とはここで別れる', () {
            final l = g.l;
            g.setFlag('priesthood');
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.flags.remove('way_outlaw');
            l.flags.remove('way_merchant');
            g.j(6);
            g.mark('世を捨て、髪を下ろした');
            return '髪を下ろし、仏門に入った。';
          }),
          Choice.h('まだ俗世に留まる', 'やり残したことがある', () => '鐘の音に背を向けた。'),
        ], after: next);
      },
    ),

    // ==================================================================
    // 商いの道
    // ==================================================================
    SceneDef(
      'trade_trip',
      16,
      80,
      (g) => 1,
      merchant,
      (g, next) {
        final l = g.l;
        g.ask('仕入れの旅', tradeIntro(g), [
          Choice.h('近くの市へ', '儲けは小さい。危うさも小さい', () {
            l.gold += g.rng.range(3, 8);
            return '近くの市で手堅く仕入れ、売り切った。';
          }),
          Choice.h('峠を越えて隣国へ', '儲けは大きい。山賊が出るという', () {
            if (g.rng.chance(.1 - l.bu / 1500)) {
              g.die('峠で山賊に襲われ、命を落とした', 'senshi');
              return '峠で山賊に囲まれた。荷も命も、奪われた。';
            }
            if (g.rng.chance(.7)) {
              l.gold += g.rng.range(12, 25);
              return '隣国の品は、飛ぶように売れた。';
            }
            l.gold = l.gold >= 8 ? l.gold - 8 : 0;
            l.hp -= 10;
            return '山賊に荷を奪われ、命からがら逃げ帰った。';
          }),
          Choice.h('船で遠国へ', '一度で蔵が建つこともある。海は人を返さないこともある', () {
            if (g.rng.chance(.07)) {
              g.die('仕入れの船が嵐に遭い、戻らなかった', 'yukue');
              return '船は嵐の海に消え、二度と戻らなかった。';
            }
            if (g.rng.chance(.55)) {
              l.gold += g.rng.range(25, 50);
              g.mark('船で遠国と商いし、大きく儲けた');
              return '遠国の品で、蔵が一つ建つほど儲けた。';
            }
            l.gold = l.gold >= 15 ? l.gold - 15 : 0;
            return '荒れた海で荷を捨てた。大損だ。';
          }),
        ], after: next);
      },
      repeat: true,
      onlyForced: true,
    ),

    SceneDef('za', 18, 60, (g) => 2, merchant, (g, next) {
      g.ask('座', '町の商いは「座」が仕切っている。座に入らねば、売る場所がない。', [
        Choice.h('銭10貫で座に入る', '商いは安定する。仲間内の決まりに縛られる', () {
          if (g.l.gold < 10) return '銭が足りず、座には入れなかった。';
          g.l.gold -= 10;
          g.setFlag('za');
          g.l.net += 3;
          return '座に入り、町の商いの仲間になった。';
        }),
        Choice.h('座を通さず売る', '儲けは丸ごと自分のもの。にらまれる', () {
          if (g.rng.chance(.5)) {
            g.l.gold += 12;
            g.setFlag('za_rebel');
            return '安く売って客を集めた。座の者たちの目が冷たい。';
          }
          g.l.hp -= 15;
          g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
          return '座の者たちに店を荒らされた。';
        }),
      ], after: next);
    }),

    SceneDef('nanban_trade', 20, 70, (g) => 1.5, merchant, (g, next) {
      g.ask('南蛮の品', '南蛮の船が、見たこともない品を積んで港に入った。', [
        Choice.h('鉄砲と火薬を扱う', '大名たちが欲しがる。戦の道具で儲けることになる', () {
          g.l.gold += 30;
          g.setFlag('gun_dealer');
          g.l.net += 2;
          g.mark('南蛮渡来の鉄砲を商った');
          return '鉄砲は、いくらでも売れた。';
        }),
        Choice.h('薬や織物を扱う', '手堅い。人に喜ばれる', () {
          g.l.gold += 15;
          g.j(4);
          return '南蛮の薬と織物は、よい値で売れた。';
        }),
        Choice.h('手を出さない', '見知らぬものには近寄らない', () => '南蛮の船は、遠くから眺めるだけにした。'),
      ], after: next);
    }, ageOk: (g, a) => _yr(g, a) >= 1550),

    SceneDef(
      'loan_daimyo',
      25,
      75,
      (g) => 1.5 + g.l.gold / 60,
      (g) => merchant(g) && g.l.gold >= 30,
      (g, next) {
        final lord = homeLord(g);
        g.ask('御用の話', '$lord家の勘定方が、戦の費えを用立ててほしいと頭を下げてきた。', [
          Choice.h('銭30貫を貸す', '御用商人になれるかもしれない。踏み倒されるかもしれない', () {
            g.l.gold -= 30;
            if (g.rng.chance(.6)) {
              g.setFlag('goyo');
              g.l.fame += 10;
              g.meet('御用先', '$lord家', 50);
              g.mark('$lord家の御用商人となった');
              return '$lord家の御用商人となった。店の格が上がった。';
            }
            g.j(-8);
            return '戦は負け、貸した銭は戻らなかった。';
          }),
          Choice.h('断る', '銭は守れる。武家の恨みは怖い', () {
            g.l.fame -= 2;
            return '丁重に断った。勘定方は、黙って帰っていった。';
          }),
        ], after: next);
      },
    ),

    SceneDef('store_fire', 18, 80, (g) => 1, merchant, (g, next) {
      g.ask('店が火に', '夜半、隣家から出た火が、店を舐めた。', [
        Choice.h('火の中に飛び込み帳面を守る', '店の命は帳面だ。火は人を選ばない', () {
          if (g.rng.chance(.08)) {
            g.die('燃える店に飛び込み、戻らなかった', 'sai');
            return '帳面を抱えたまま、炎の向こうに消えた。';
          }
          g.l.hp -= 20;
          g.setFlag('saved_ledger');
          return '火傷を負ったが、帳面は守った。貸しは取り立てられる。';
        }),
        Choice.h('家の者を連れて逃げる', '命は守れる。店は灰になる', () {
          g.l.gold = (g.l.gold * .4).floor();
          g.j(-6);
          return '店は焼け落ちた。家の者は皆、無事だった。';
        }),
      ], after: next);
    }),

    SceneDef(
      'tea_master',
      25,
      70,
      (g) => 1.5,
      (g) => (merchant(g) || g.l.rank >= 4) && g.active,
      (g, next) {
        g.ask('茶の湯', '堺の茶人・千宗易（のちの利休）が、茶の湯の手ほどきをしてくれるという。', [
          Choice.h('弟子入りする', '天下の人々とつながる。茶の道は厳しい', () {
            g.l.chi = _c(g.l.chi + 3);
            g.l.net += 4;
            g.l.fame += 5;
            g.meet('茶の師', '千宗易', 45);
            g.mark('千宗易に茶の湯を学んだ');
            return '宗易の茶室で、静けさというものを知った。';
          }),
          Choice.h('茶より商い（務め）', '日々の暮らしが大事だ', () => '茶室の小さな戸は、くぐらなかった。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1555 && _yr(g, a) <= 1590,
    ),

    SceneDef('shop_heir', 45, 80, (g) => 3, (g) => merchant(g), (g, next) {
      final l = g.l;
      g.ask('店の跡目', '店を誰に任せるか、決める時が来た。', [
        if (l.kids > 0)
          Choice.h('我が子に継がせる', '家は続く。子の器量しだいでもある', () {
            final n = _childName(g);
            g.meet('子', n, 60);
            g.setFlag('retired');
            g.j(6);
            g.mark('店を子の$nに継がせ、隠居した');
            return '店を$nに譲り、隠居の身となった。';
          }),
        Choice.h('番頭に任せる', '店は確かに残る。血筋は残らない', () {
          g.setFlag('retired');
          g.meet('番頭', '番頭の${g.rng.pick(kGivenM)}', 50);
          g.mark('店を番頭に任せ、隠居した');
          return '長年仕えた番頭に、店を任せた。';
        }),
        Choice.h('死ぬまで帳場に座る', '商いが生きがいだ', () {
          g.setFlag('lifelong_trade');
          return 'まだ譲らぬ。帳場が、自分の居場所だ。';
        }),
      ], after: next);
    }),

    // ==================================================================
    // 野に生きる道（野盗・流れ者・抜け忍）
    // ==================================================================
    SceneDef(
      'raid',
      16,
      70,
      (g) => 1,
      outlaw,
      (g, next) {
        final l = g.l;
        g.ask('獲物', raidIntro(g), [
          Choice.h('荷を運ぶ商人の列を襲う', '実入りは大きい。護衛がつくこともある', () {
            if (g.rng.chance(.08 - l.bu / 2000)) {
              g.die('商人の護衛に斬られて死んだ', 'senshi');
              return '護衛の刀が、思いのほか速かった。';
            }
            l.gold += g.rng.range(8, 20);
            l.fame -= 3;
            return '荷を奪い、山へ逃げた。';
          }),
          Choice.h('落ち武者の具足を剥ぐ', '手負いの武者は弱い。だが死にもの狂いだ', () {
            l.gold += g.rng.range(4, 10);
            l.hp -= g.rng.range(0, 12);
            return '具足を剥いで売った。';
          }),
          Choice.h('見逃す', '何も得ない。何も失わない', () {
            g.j(1);
            return '今日は、見送った。';
          }),
        ], after: next);
      },
      repeat: true,
      onlyForced: true,
    ),

    SceneDef(
      'manhunt',
      18,
      75,
      (g) => 1.5 + (g.l.fame < -10 ? 1.5 : 0),
      outlaw,
      (g, next) {
        final l = g.l;
        final lord = homeLord(g);
        g.ask('山狩り', '$lord家が、野盗を根こそぎにする山狩りを始めた。', [
          Choice.h('山奥へ逃げる', '生き延びられるかもしれない。仲間は散る', () {
            if (g.rng.chance(.1)) {
              g.die('山狩りを逃れ山奥へ消え、それきり誰も姿を見なかった', 'yukue');
              return '山の奥へ、奥へ。それきり、誰もその姿を見なかった。';
            }
            l.hp -= 10;
            return '仲間と散り散りになって、山狩りを逃れた。';
          }),
          Choice.h('迎え撃つ', '勝てば名が轟く。捕まれば首を晒される', () {
            if (g.rng.chance(clampD(.35 + l.bu / 200, .2, .8))) {
              l.fame += 5;
              g.mark('山狩りの兵を追い返した');
              return '討手を追い返した。山の者たちの間で、名が上がった。';
            }
            g.die('山狩りで捕らえられ、首を晒された', 'seppuku');
            return '捕らえられ、河原で首を刎ねられた。';
          }),
          Choice.h('名乗り出て降る', '命は助かるかもしれない。野の暮らしは終わる', () {
            if (g.rng.chance(.5)) {
              l.flags.remove('way_outlaw');
              l.fame -= 5;
              g.mark('山狩りに降り、野の暮らしを終えた');
              return '縄を受けたが、命だけは許された。';
            }
            g.die('降ったが許されず、処刑された', 'seppuku');
            return '許しは、なかった。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'assassin_job',
      18,
      65,
      (g) => 1.2 + (g.l.cls.id == 'ninja' ? 2 : 0),
      (g) =>
          (outlaw(g) || (g.l.cls.id == 'ninja' && g.l.rank == 0)) &&
          !g.l.female,
      (g, next) {
        g.ask('刺客の依頼', '覆面の使いが、ある武将の命を絶てと銭を積んできた。', [
          Choice.h('引き受ける', '大きな銭になる。しくじれば、生きては帰れない', () {
            final l = g.l;
            if (g.rng.chance(clampD(.45 + (l.bu + l.chi) / 400, .3, .8))) {
              l.gold += 40;
              g.setFlag('assassin');
              g.mark('依頼を受け、ある武将を闇に葬った');
              return '仕事は果たした。誰が殺したのか、誰も知らない。';
            }
            if (g.rng.chance(.6)) {
              g.die('刺客として忍び込み、捕らえられて処刑された', 'seppuku');
              return '寝所の手前で、捕らえられた。';
            }
            l.hp -= 30;
            return 'しくじったが、どうにか逃げ延びた。';
          }),
          Choice.h('断る', '銭は惜しい。手は汚さずに済む', () => '使いは、黙って去った。'),
        ], after: next);
      },
    ),

    SceneDef(
      'nukenin',
      18,
      45,
      (g) => 2 + (g.l.joy < 40 ? 1.5 : 0),
      (g) =>
          g.l.cls.id == 'ninja' &&
          g.l.rank == 0 &&
          !g.hasFlag('nukenin') &&
          !monk(g),
      (g, next) {
        g.ask('里の掟', '里の掟に縛られた暮らしに、嫌気がさしてきた。抜け忍は、追手に狩られる。', [
          Choice.h('里を抜ける', '自由になる。一生、追手の影がつきまとう', () {
            g.setFlag('nukenin');
            g.setFlag('way_outlaw');
            g.j(6);
            g.mark('忍びの里を抜けた');
            return '月のない夜、里を抜けた。';
          }),
          Choice.h('里に留まる', '掟の中で生きる', () => '掟に従って生きると決めた。'),
        ], after: next);
      },
    ),

    SceneDef('pursuers', 18, 80, (g) => 2.5, (g) => g.hasFlag('nukenin'), (
      g,
      next,
    ) {
      final l = g.l;
      g.ask('追手', '里からの追手が、すぐ近くまで来ている気配がする。', [
        Choice.h('迎え撃つ', '勝てば、しばらくは安らげる', () {
          if (g.rng.chance(clampD(.45 + l.bu / 200, .3, .85))) {
            l.bu = _c(l.bu + 1);
            return '追手を返り討ちにした。';
          }
          g.die('里の追手に討たれた', 'ansatsu');
          return '闇の中から、刃がのびてきた。';
        }),
        Choice.h('名を変え、遠国へ逃れる', '追手は撒ける。積み上げたものは捨てる', () {
          l.gold = (l.gold * .5).floor();
          l.net = l.net ~/ 2;
          return '名を変え、遠い国へ逃れた。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef(
      'wander_road',
      18,
      84,
      (g) => 1,
      outlaw,
      (g, next) {
        final l = g.l;
        g.ask('旅路', wanderIntro(g), [
          Choice.h('街道を西へ', '人の多い道。稼ぎ口もある', () {
            l.gold += g.rng.range(2, 6);
            l.net += 1;
            return '街道沿いの宿場で、日銭を稼いだ。';
          }),
          Choice.h('険しい山を越える', '追手は来ない。山は人を呑む', () {
            if (g.rng.chance(.08)) {
              g.die('山に入ったまま、行方知れずとなった', 'yukue');
              return '霧の深い峠に入ったきり、戻らなかった。';
            }
            _heal(l, 10);
            g.j(3);
            return '峠の上から、見知らぬ国が見えた。';
          }),
          Choice.h('海を渡る', 'まだ見ぬ土地へ。海は気まぐれだ', () {
            if (g.rng.chance(.1)) {
              g.die('海を渡ったまま、消息を絶った', 'yukue');
              return '船出したきり、消息は絶えた。';
            }
            g.setFlag('crossed_sea');
            g.mark('海を渡り、遠い土地へ流れた');
            return '海を渡り、言葉もよく分からない土地に着いた。';
          }),
        ], after: next);
      },
      repeat: true,
      onlyForced: true,
    ),

    SceneDef(
      'go_straight',
      25,
      70,
      (g) => 1 + (g.l.married ? 1.5 : 0) + (g.l.kids > 0 ? 1.5 : 0),
      (g) => outlaw(g) && !g.hasFlag('nukenin'),
      (g, next) {
        g.ask('足を洗う', '野の暮らしにも疲れた。どこかの村で、静かに暮らせないだろうか。', [
          Choice.h('足を洗う', '静かに暮らせる。昔の仲間は黙っていない', () {
            g.l.flags.remove('way_outlaw');
            g.setFlag('reformed');
            g.j(6);
            g.mark('野の暮らしから足を洗った');
            return '刀を捨て、村の外れに小屋を建てた。';
          }),
          Choice.h('まだ野に生きる', 'これしか生き方を知らない', () => 'まだ、野の風の方が性に合う。'),
        ], after: next);
      },
    ),

    // ==================================================================
    // 仏門
    // ==================================================================
    SceneDef('temple_head', 30, 80, (g) => 2 + g.l.fame / 30, monk, (g, next) {
      g.ask('寺を任される', '本山から、ある寺の住持を任せたいと言ってきた。', [
        Choice.h('住持となる', '寺を背負う。名は上がる', () {
          g.setFlag('abbot');
          g.l.fame += 10;
          g.l.gold += 10;
          g.mark('寺の住持となった');
          return '寺の住持として、多くの僧と檀家を預かる身となった。';
        }),
        Choice.h('遊行の僧であり続ける', '寺には縛られない。旅は続く', () {
          g.setFlag('yugyo');
          return '寺には入らず、諸国を歩く道を選んだ。';
        }),
      ], after: next);
    }),

    SceneDef(
      'ikko',
      18,
      70,
      (g) => 2,
      (g) => monk(g) || (g.l.rank == 0 && g.active),
      (g, next) {
        g.ask('一向一揆', '本願寺の門徒が、武家に抗って立ち上がった。「進めば往生極楽、退けば無間地獄」', [
          Choice.h('門徒として戦う', '信じるもののために戦う。命の保証はない', () {
            final l = g.l;
            if (g.rng.chance(.15)) {
              g.die('一向一揆の戦いで、念仏を唱えながら討たれた', 'senshi');
              return '念仏を唱えながら、槍の前に進んだ。';
            }
            l.fame += 6;
            l.hp -= 15;
            g.setFlag('ikko');
            g.mark('一向一揆に加わって戦った');
            return '門徒とともに戦い、生き延びた。';
          }),
          Choice.h('争いから身を引く', '命は守れる。信心を疑われる', () => '戦いの輪には加わらなかった。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1563 && _yr(g, a) <= 1580,
    ),

    SceneDef('hiei', 15, 84, (g) => 20, (g) => monk(g), (g, next) {
      g.ask('比叡山', '織田の軍勢が比叡山を囲み、火を放った。あなたは山の寺にいる。', [
        Choice.h('経典を抱えて逃げる', '命と教えを残す。仲間を見捨てることになる', () {
          if (g.rng.chance(.25)) {
            g.die('比叡山の焼き討ちで、炎に巻かれた', 'sai');
            return '炎の回りは、思いのほか速かった。';
          }
          g.setFlag('hiei_survivor');
          g.mark('比叡山の焼き討ちを、経典を抱えて逃れた');
          return '経典を抱え、燃える山を下った。';
        }),
        Choice.h('寺と運命を共にする', '最後まで仏の前にいる', () {
          g.die('比叡山の焼き討ちで、寺と運命を共にした', 'senshi');
          return '燃える本堂で、最後まで経を読み続けた。';
        }),
      ], after: next);
    }, ageOk: (g, a) => _yr(g, a) == 1571),

    SceneDef(
      'kirishitan',
      18,
      70,
      (g) => 1,
      (g) => !g.hasFlag('kirishitan') && g.l.rank < 8,
      (g, next) {
        g.ask('南蛮の教え', '南蛮の宣教師が「デウス」の教えを説いている。', [
          Choice.h('洗礼を受ける', '新しい救いに出会う。周りの目は変わる', () {
            g.setFlag('kirishitan');
            g.l.flags.remove('priesthood');
            g.j(5);
            g.mark('洗礼を受け、キリシタンとなった');
            return '洗礼を受け、南蛮の名を授かった。';
          }),
          Choice.h('耳を傾けるだけ', '何も変わらない', () => '珍しい話として聞いた。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1550 && _yr(g, a) <= 1595,
    ),

    SceneDef('disciple', 40, 84, (g) => 2, monk, (g, next) {
      final n = '弟子の${g.rng.pick(kGivenM)}';
      g.ask('弟子', '身寄りのない子が、弟子にしてほしいと寺の門の前で待っていた。', [
        Choice.h('弟子に取る', '教えを継ぐ者ができる', () {
          g.meet('弟子', n, 55);
          g.j(6);
          g.mark('身寄りのない子を弟子に取った');
          return '$nと名付け、弟子とした。';
        }),
        Choice.h('別の寺を紹介する', '身軽なままでいられる', () => '知り合いの寺へ送り出した。'),
      ], after: next);
    }),

    SceneDef(
      'pilgrimage',
      30,
      84,
      (g) => 1.5 + (g.hasFlag('yugyo') ? 2 : 0),
      monk,
      (g, next) {
        g.ask('遊行', '諸国の霊場を巡る旅に出ようと思い立った。', [
          Choice.h('旅立つ', '教えが広まる。旅先で倒れる者も多い', () {
            if (g.rng.chance(.08)) {
              g.die('遊行の旅に出たまま、どこで果てたかも知れない', 'yukue');
              return '旅に出たきり、二度と寺には戻らなかった。';
            }
            g.l.fame += 6;
            g.l.net += 3;
            g.l.hp -= 10;
            g.mark('諸国の霊場を巡り歩いた');
            return '諸国を巡り、多くの人に教えを説いた。';
          }),
          Choice.h('寺に留まる', '穏やかな日々が続く', () => '寺の庭を掃く日々を選んだ。'),
        ], after: next);
      },
    ),

    // ==================================================================
    // 村の暮らし
    // ==================================================================
    SceneDef(
      'shoya',
      28,
      70,
      (g) => 1.5 + g.l.net / 10,
      (g) => villager(g) && !g.l.female,
      (g, next) {
        g.ask('庄屋', '村の年寄りたちが、あなたを庄屋に推したいと言ってきた。', [
          Choice.h('引き受ける', '村をまとめる立場になる。武家と村の板挟みになる', () {
            g.setFlag('shoya');
            g.l.fame += 6;
            g.l.net += 3;
            g.mark('村の庄屋となった');
            return '村の庄屋となった。';
          }),
          Choice.h('断る', '気楽な百姓のままでいられる', () => '自分には荷が重いと断った。'),
        ], after: next);
      },
    ),

    SceneDef('water_dispute', 18, 75, (g) => 1.5, villager, (g, next) {
      g.ask('水争い', '日照りが続き、隣村と川の水をめぐって争いになった。', [
        Choice.h('鍬を持って隣村に押しかける', '水は取れるかもしれない。血が流れる', () {
          if (g.rng.chance(.06)) {
            g.die('隣村との水争いで、打ち殺された', 'senshi');
            return '乱闘の中で、頭を打たれた。';
          }
          if (g.rng.chance(.55)) {
            g.l.gold += 4;
            g.l.fame += 2;
            return '水を勝ち取った。今年の稲は育つ。';
          }
          g.l.hp -= 15;
          return '追い返された。体中が痛む。';
        }),
        Choice.h('話し合いで分ける', '水は少しずつ。恨みは残らない', () {
          g.l.net += 2;
          return '水を分け合うことで話がついた。';
        }),
      ], after: next);
    }, repeat: true),

    SceneDef('new_field', 20, 65, (g) => 1.2, villager, (g, next) {
      g.ask('新田', '村はずれの荒れ地を拓けば、田が増える。', [
        Choice.h('荒れ地を拓く', '何年もかかる。拓けば暮らしが変わる', () {
          g.l.hp -= 15;
          g.setFlag('new_field');
          g.l.gold += 6;
          g.mark('荒れ地を拓き、新しい田を作った');
          return '何度も鍬を入れ、新しい田を拓いた。';
        }),
        Choice.h('今の田を守る', '無理はしない', () => '今ある田を、大事に耕した。'),
      ], after: next);
    }),

    SceneDef(
      'master_craft',
      22,
      70,
      (g) => 3,
      (g) => g.hasFlag('apprentice') && free(g),
      (g, next) {
        g.ask('職人の腕', '奉公先で磨いた腕が、評判になり始めた。', [
          Choice.h('自分の工房を開く', '名工と呼ばれるかもしれない', () {
            g.setFlag('craftsman');
            g.l.gold += 8;
            g.l.fame += 4;
            g.mark('自分の工房を開いた');
            return '小さな工房を開いた。客が、少しずつ増えてきた。';
          }),
          Choice.h('親方に仕え続ける', '暮らしは安定する', () => '親方のもとで、腕を磨き続けた。'),
        ], after: next);
      },
    ),

    SceneDef('flood', 15, 84, (g) => 1, (g) => g.l.rank <= 4 && !monk(g), (
      g,
      next,
    ) {
      g.ask('大水', '長雨で川があふれ、濁流が村に迫っている。', [
        Choice.h('高台へ逃げる', '命は守れる。田畑は流される', () {
          g.l.gold = g.l.gold >= 4 ? g.l.gold - 4 : 0;
          g.j(-5);
          return '高台から、流されていく家を見た。';
        }),
        Choice.h('堤を守りに行く', '村を救えるかもしれない。水は人を選ばない', () {
          if (g.rng.chance(.1)) {
            g.die('堤を守ろうとして、濁流に呑まれた', 'sai');
            return '堤が切れ、濁流に呑まれた。';
          }
          g.l.fame += 5;
          g.l.net += 3;
          g.mark('大水の夜、堤を守り抜いた');
          return '夜通し土嚢を積み、堤を守り抜いた。';
        }),
      ], after: next);
    }, repeat: true),

    // ==================================================================
    // 壮年・晩年（誰にでも）
    // ==================================================================
    SceneDef(
      'kid_coming',
      30,
      65,
      (g) => 2.5,
      (g) => g.l.kids > 0 && !g.l.people.containsKey('子'),
      (g, next) {
        final n = _childName(g);
        g.ask('子の門出', '子の$nが、一人前になる歳を迎えた。', [
          Choice.h('自分の道を継がせる', '家は続く。子の望みとは違うかもしれない', () {
            g.meet('子', n, 55);
            g.setFlag('heir');
            g.mark('子の$nを跡継ぎと定めた');
            return '$nを跡継ぎと定め、自分の知ることを教え込んだ。';
          }),
          Choice.h('好きな道を行かせる', '子は喜ぶ。家は誰が継ぐ', () {
            g.meet('子', n, 75);
            g.j(4);
            return '$nは、目を輝かせて家を出ていった。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'retire',
      50,
      84,
      (g) => 1.5 + (g.age >= 60 ? 2 : 0),
      (g) =>
          g.active &&
          (g.l.rank >= 1 || g.l.people.containsKey('子')) &&
          !g.hasFlag('way_merchant') &&
          !monk(g),
      (g, next) {
        final l = g.l;
        final heir = l.people['子'];
        g.ask(
          '隠居',
          '体の衰えを感じる。${heir == null ? '' : '跡継ぎの${heir.name}も一人前だ。'}家督を譲るか。',
          [
            Choice.h('家督を譲り、隠居する', '穏やかな老後。家の行く末は人任せになる', () {
              g.setFlag('retired');
              l.troops = 0;
              g.j(8);
              g.mark('家督を譲り、隠居した');
              return '家督を譲り、隠居の身となった。';
            }),
            Choice.h('まだ譲らぬ', '最後まで自分の手で。老いは待ってくれない', () {
              g.setFlag('never_retire');
              return 'まだ譲らぬ。この手で、やれることがある。';
            }),
          ],
          after: next,
        );
      },
    ),

    SceneDef(
      'friend_death',
      40,
      84,
      (g) => 2,
      (g) => g.l.people.containsKey('幼なじみ') || g.l.people.containsKey('好敵手'),
      (g, next) {
        final p = g.l.people['幼なじみ'] ?? g.l.people['好敵手']!;
        g.ask('旧友の死', '${p.name}が死んだと、風の便りに聞いた。', [
          Choice.h('弔いに駆けつける', '最後の別れができる', () {
            g.setFlag('mourned_friend');
            g.l.hp -= 5;
            g.j(-4);
            g.mark('${p.name}の死を、墓前で弔った');
            return '${p.name}の墓の前で、幼い日のことを思い出した。';
          }),
          Choice.h('遠くから手を合わせる', '心の中で別れを告げる', () {
            g.j(-6);
            return '遠い空に向かって、手を合わせた。';
          }),
        ], after: next);
      },
    ),

    SceneDef('grandchild', 45, 84, (g) => 2, (g) => g.l.kids > 0, (g, next) {
      g.ask('孫', '孫が生まれた。小さな手が、あなたの指を握った。', [
        Choice.h('名付け親になる', '血はつながっていく', () {
          g.setFlag('grandchild');
          g.j(12);
          g.mark('孫の名付け親となった');
          return '孫に名を授けた。';
        }),
        Choice.h('遠くから喜ぶ', 'いまは務めが大事だ', () {
          g.j(5);
          return '便りを読み、ひとり静かに喜んだ。';
        }),
      ], after: next);
    }),

    SceneDef(
      'last_battle',
      55,
      84,
      (g) => 2,
      (g) => g.l.rank >= 1 && g.l.rank < 9 && g.canFight && g.l.lord != null,
      (g, next) {
        g.ask('老いての出陣', '家の存亡をかけた戦が始まる。老いた身にも、声がかかった。', [
          Choice.h('甲冑をまとって出る', '最後の花道になるかもしれない', () {
            if (g.rng.chance(.25)) {
              g.die('老いて最後の戦に出て、討死した', 'senshi');
              return '若い者たちの先頭に立ち、そのまま帰らなかった。';
            }
            g.l.fame += 8;
            g.mark('老いてなお、最後の戦に出た');
            return '老いた体で戦い抜き、生きて帰った。';
          }),
          Choice.h('若い者に任せる', '命は守れる。時代は移る', () => '戦は、若い者に任せた。'),
        ], after: next);
      },
    ),

    SceneDef('old_illness', 55, 84, (g) => 1.5, (g) => true, (g, next) {
      g.ask('老いの病', '胸の痛みが、近ごろ増してきた。', [
        Choice.h('名医を呼ぶ（銭10貫）', '銭はかかる。長生きできるかもしれない', () {
          if (g.l.gold < 10) {
            g.l.hp -= 10;
            return '銭が足りず、名医は呼べなかった。';
          }
          g.l.gold -= 10;
          _heal(g.l, 20);
          return '名医の薬で、痛みが和らいだ。';
        }),
        Choice.h('天命に任せる', '残りの日々を好きに使う', () {
          g.l.hp -= 8;
          g.j(3);
          return '残りの日々を、好きなように過ごすことにした。';
        }),
      ], after: next);
    }),

    SceneDef('jisei', 60, 84, (g) => 2, (g) => g.l.chi >= 30, (g, next) {
      g.ask('辞世', '死を思う歳になった。言い残したいことはあるか。', [
        Choice.h('辞世の句を詠んでおく', '生きた証を、言葉に残す', () {
          g.setFlag('jisei');
          g.j(4);
          g.mark('辞世の句を詠んだ');
          return '筆を取り、辞世の句をしたためた。';
        }),
        Choice.h('言葉は残さない', '生き様がすべてだ', () {
          g.setFlag('no_jisei');
          return '言葉など要らぬ。そう思った。';
        }),
      ], after: next);
    }),

    SceneDef('earthquake', 15, 84, (g) => 8, (g) => true, (g, next) {
      g.ask('大地震', '夜更け、大地が大きく揺れた。家が軋み、梁が落ちてくる。', [
        Choice.h('家の者を助けに戻る', '誰かを救えるかもしれない', () {
          if (g.rng.chance(.12)) {
            g.die('大地震で崩れた家の下敷きになった', 'sai');
            return '家の者を外へ押し出したところで、屋根が崩れた。';
          }
          g.l.hp -= 10;
          g.mark('大地震の夜、家の者を救い出した');
          return '家の者を救い出した。';
        }),
        Choice.h('外へ飛び出す', '自分の命は守れる', () {
          g.l.hp -= 5;
          g.j(-6);
          return '飛び出した背中で、家が崩れる音がした。';
        }),
      ], after: next);
    }, ageOk: (g, a) => _yr(g, a) == 1586),

    // ==================================================================
    // 非業の死の危うさ（身分のある者）
    // ==================================================================
    SceneDef(
      'seppuku_order',
      18,
      84,
      (g) => 1 + (g.l.fav < 15 ? 3 : 0),
      (g) => g.l.rank >= 2 && g.l.rank < 8 && g.l.fav < 25 && g.active,
      (g, next) {
        final l = g.l;
        g.ask('主君の怒り', '主君の不興を買い、腹を切れとの命が下った。', [
          Choice.h('潔く腹を切る', '武士の面目は守られる', () {
            g.die('主君の命で、腹を切った', 'seppuku');
            return '白装束に身を改め、腹を切った。';
          }),
          Choice.h('命乞いをする', '生き恥をさらす。許されるとは限らない', () {
            if (g.rng.chance(.45 + l.mi / 300)) {
              l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
              l.fav = 15;
              g.j(-10);
              return '許された。だが位は下げられ、家中の目は冷たい。';
            }
            g.die('命乞いは聞き入れられず、斬られた', 'seppuku');
            return '命乞いは、聞き入れられなかった。';
          }),
          Choice.h('出奔する', '命は守れる。追われる身になる', () {
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.ronin = true;
            g.setFlag('way_outlaw');
            g.mark('主君の命に背き、出奔した');
            return '夜陰にまぎれて、国を出た。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'assassin_target',
      20,
      84,
      (g) => 1 + (g.l.rank >= 8 ? 1.5 : 0),
      (g) => g.l.rank >= 5,
      (g, next) {
        final l = g.l;
        g.ask('刺客の影', '屋敷の周りに、見慣れぬ者がうろついているという。', [
          Choice.h('警護を固める（銭10貫）', '銭はかかる。安心は買える', () {
            l.gold = l.gold >= 10 ? l.gold - 10 : 0;
            return '警護を固めた。何事もなく、日々が過ぎた。';
          }),
          Choice.h('気に留めない', '臆病者と思われずに済む', () {
            if (g.rng.chance(.12 - l.un / 2000)) {
              g.die('寝所に忍び込んだ刺客に討たれた', 'ansatsu');
              return '夜半、寝所の襖が音もなく開いた。';
            }
            return '噂は噂に過ぎなかった。';
          }),
          Choice.h('逆に刺客を罠にかける', '黒幕が分かるかもしれない', () {
            if (g.rng.chance(clampD(.4 + l.chi / 200, .3, .85))) {
              l.fame += 5;
              g.setFlag('caught_assassin');
              g.mark('自分を狙う刺客を罠にかけた');
              return '刺客を捕らえた。黒幕の名を聞いて、言葉を失った。';
            }
            l.hp -= 20;
            return '罠は見破られ、手傷を負った。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef(
      'siege',
      18,
      84,
      (g) => 1.2,
      (g) => g.l.rank >= 3 && g.l.lord != null && g.active,
      (g, next) {
        final l = g.l;
        g.ask('籠城', '敵の大軍に城を囲まれた。兵糧は日ごとに減っていく。', [
          Choice.h('最後まで籠もる', '援軍が来れば勝てる。来なければ飢える', () {
            if (g.rng.chance(.1)) {
              g.die('長い籠城の末、城中で飢えて死んだ', 'ue');
              return '草の根も、壁の土も食べ尽くした。';
            }
            if (g.rng.chance(.5)) {
              l.fame += 8;
              l.merit += 10;
              g.mark('長い籠城に耐え抜いた');
              return '援軍が来た。城は守られた。';
            }
            l.hp -= 25;
            return '城は開かれた。痩せ衰えた体で、城を出た。';
          }),
          Choice.h('城を出て斬り込む', '囲みを破れば英雄。破れなければ…', () {
            if (g.rng.chance(clampD(.3 + l.bu / 200, .2, .7))) {
              l.fame += 12;
              l.merit += 15;
              g.mark('籠城の囲みを、斬り込んで破った');
              return '囲みを破り、敵を退けた！';
            }
            g.die('籠城の囲みに斬り込み、討死した', 'senshi');
            return '敵陣の只中で、力尽きた。';
          }),
          Choice.h('開城を説く', '城兵の命は救える。臆病と言われる', () {
            l.fav = _c(l.fav - 10);
            l.net += 3;
            return '開城を説き、多くの命が救われた。';
          }),
        ], after: next);
      },
      repeat: true,
    ),

    SceneDef('poison', 25, 84, (g) => 1, (g) => g.l.rank >= 8, (g, next) {
      final l = g.l;
      g.ask('膳の異変', '今夜の膳の汁が、いつもと少し違う色をしている。', [
        Choice.h('毒見をさせる', '疑えば、家中の心は離れる', () {
          l.net = l.net >= 1 ? l.net - 1 : 0;
          return '毒見の者は、何ともなかった。気のせいだったか。';
        }),
        Choice.h('そのまま口にする', '家臣を信じる。信じた相手しだいだ', () {
          if (g.rng.chance(.15)) {
            g.die('膳に盛られた毒で倒れた', 'ansatsu');
            return '汁をすすってほどなく、喉が焼けるように熱くなった。';
          }
          l.net += 2;
          return 'うまい汁だった。家臣たちが、ほっとした顔をした。';
        }),
      ], after: next);
    }, repeat: true),

    // ==================================================================
    // 女の道
    // ==================================================================
    SceneDef(
      'hostage',
      15,
      30,
      (g) => 1.5,
      (g) =>
          g.l.female &&
          g.l.rank >= 3 &&
          g.l.rank < 8 &&
          !g.l.married &&
          g.alive.length >= 2,
      (g, next) {
        final other = g.rng
            .pick(g.alive.where((x) => x.name != g.l.lord).toList())
            .name;
        g.ask('人質', '同盟の証として、$other家へ人質に出されることになった。', [
          Choice.h('家のために行く', '家は守られる。帰れる日が来るとは限らない', () {
            g.setFlag('hostage');
            g.l.fav = _c(g.l.fav + 15);
            g.l.net += 2;
            g.mark('同盟の証に、$other家へ人質として赴いた');
            return '$other家の城で、人質の日々が始まった。';
          }),
          Choice.h('病と偽って逃れる', '家に残れる。家の面目は潰れる', () {
            g.l.fav = _c(g.l.fav - 15);
            return '病と偽り、人質の話を逃れた。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'defend_castle',
      20,
      70,
      (g) => 1.5,
      (g) => g.l.female && g.l.married && g.l.rank >= 3 && g.l.rank < 8,
      (g, next) {
        final l = g.l;
        g.ask('留守の城', '夫の留守に、敵が城へ攻め寄せてきた。城兵は、あなたの指図を待っている。', [
          Choice.h('薙刀を手に、城を守る', '守り抜けば語り草になる。女の身でも戦場は戦場だ', () {
            if (g.rng.chance(.12)) {
              g.die('留守の城を守って戦い、討死した', 'senshi');
              return '城門の前で、薙刀を構えたまま倒れた。';
            }
            if (g.rng.chance(.6 + l.chi / 400)) {
              g.setFlag('onna_jo');
              l.fame += 15;
              l.merit += 20;
              g.mark('夫の留守に城を守り抜き、女城主と呼ばれた');
              return '敵は退いた。人々は、あなたを「女城主」と呼んだ。';
            }
            l.hp -= 20;
            return '城の一角を奪われたが、どうにか持ちこたえた。';
          }),
          Choice.h('城を開いて和を請う', '命は守れる。家の面目は失われる', () {
            l.fav = _c(l.fav - 10);
            return '城を開き、和を請うた。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'oku_rival',
      18,
      60,
      (g) => 1.2,
      (g) => g.l.female && g.l.rank >= 2 && g.l.rank < 8 && g.active,
      (g, next) {
        final l = g.l;
        g.ask('奥の争い', '奥向きで、あなたを疎ましく思う者がいる。', [
          Choice.h('先に手を打つ', '敵を退けられる。恨みは深くなる', () {
            if (g.rng.chance(.55)) {
              l.fav = _c(l.fav + 8);
              g.mark('奥向きの争いを制した');
              return '相手は奥から退いた。';
            }
            l.fav = _c(l.fav - 10);
            return '企みは露見し、立場が悪くなった。';
          }),
          Choice.h('耐えて受け流す', '争いは起きない。相手は止まらないかもしれない', () {
            if (g.rng.chance(.06)) {
              g.die('奥向きの争いの末、毒を盛られた', 'ansatsu');
              return 'ある朝、膳を口にしたあと、起き上がれなくなった。';
            }
            g.j(-3);
            return 'じっと耐えた。';
          }),
        ], after: next);
      },
    ),

    // ==================================================================
    // 史実の大きな出来事（いまは史実どおりの流れ。分岐は今後）
    // ==================================================================
    SceneDef(
      'okehazama',
      15,
      70,
      (g) => 20,
      (g) =>
          (g.l.lord == '織田' || g.l.lord == '今川') &&
          g.l.rank >= 1 &&
          g.l.rank < 8 &&
          g.canFight &&
          g.active,
      (g, next) {
        final oda = g.l.lord == '織田';
        g.ask(
          '桶狭間',
          oda
              ? '今川義元の大軍が尾張に攻め入った。信長は、わずかな手勢で討って出るという。'
              : '今川の大軍の一員として尾張に入った。桶狭間で休息をとるという。',
          [
            Choice.h(
              oda ? '信長に続いて駆ける' : '本陣の守りを固めるよう進言する',
              oda ? '無謀にも見える。歴史に残る一日になるかもしれない' : '聞き入れられれば、運命が変わるかもしれない',
              () {
                final l = g.l;
                if (oda) {
                  if (g.rng.chance(.08)) {
                    g.die('桶狭間の雨の中、討死した', 'senshi');
                    return '激しい雨の中、今川の本陣にたどり着く前に倒れた。';
                  }
                  l.merit += 25;
                  l.fame += 15;
                  g.setFlag('okehazama');
                  g.mark('桶狭間で信長に従い、今川義元を討つ戦に加わった');
                  return '雨の中を駆け、今川義元の首を挙げる戦に加わった！';
                }
                if (g.rng.chance(.08)) {
                  g.setFlag('history_okehazama');
                  l.merit += 40;
                  l.fame += 30;
                  g.mark('桶狭間で義元を守り抜き、歴史を変えた');
                  return '進言が容れられ、織田の奇襲は退けられた。義元は生き延びた――歴史が、変わった。';
                }
                g.die('桶狭間で、奇襲を受けた今川本陣とともに討たれた', 'senshi');
                return '進言は届かず、雨の中、織田の奇襲に呑まれた。';
              },
            ),
            Choice.h('後方に控える', '命は守りやすい', () {
              g.setFlag('saw_okehazama');
              return oda ? '後方から、勝鬨を聞いた。' : '後方で、本陣が崩れたと聞いた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _yr(g, a) == 1560,
    ),

    SceneDef(
      'honnoji',
      15,
      84,
      (g) => 20,
      (g) =>
          (g.l.lord == '織田' || g.l.people['主君']?.name == '織田信長') &&
          g.l.rank >= 1 &&
          g.active,
      (g, next) {
        g.ask('本能寺', '明智光秀が謀反を起こし、京の本能寺に泊まる信長を囲んだ。知らせを受けたのは、あなたが京にいた夜だった。', [
          Choice.h('本能寺へ駆けつける', '主を救えるかもしれない。火の中に飛び込むことになる', () {
            final l = g.l;
            if (g.rng.chance(.06 + l.un / 2000)) {
              g.setFlag('history_honnoji');
              l.merit += 60;
              l.fame += 50;
              g.mark('本能寺の炎の中から、信長を救い出した');
              return '炎の中から、信長を救い出した。歴史が、変わった。';
            }
            if (g.rng.chance(.5)) {
              g.die('本能寺の変で、信長とともに炎の中に消えた', 'senshi');
              return '本能寺の炎の中で、主とともに果てた。';
            }
            l.hp -= 25;
            g.setFlag('honnoji');
            g.mark('本能寺の変に駆けつけたが、主を救えなかった');
            return '駆けつけたときには、寺は炎に包まれていた。';
          }),
          Choice.h('京を落ち延びる', '命は守れる。生き延びた先に、新しい主がいる', () {
            g.setFlag('fled_honnoji');
            return '夜の京を、ひそかに落ち延びた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) == 1582,
    ),
  ];
}
