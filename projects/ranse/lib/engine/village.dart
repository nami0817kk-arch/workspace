import 'childhood.dart';
import 'data.dart';
import 'game.dart';

/// 村の暮らし（身分のない百姓・漁民の大人）の岐路（2026-11-23）。
/// 生まれの約4分の3は農民の子なのに、村で暮らし続ける大人の岐路が数えるほどだったため。id は `v_`。

bool _villager(Game g) =>
    g.l.rank == 0 &&
    const ['farmer', 'fisher', 'beggar'].contains(g.l.cls.id) &&
    !g.hasFlag('priesthood') &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw') &&
    g.active;

List<SceneDef> buildVillageScenes() => [
  SceneDef('v_taue', 16, 70, (g) => 2, _villager, (g, next) {
    g.ask('田植え', '田植えの季節が来た。村じゅう総出で、一枚ずつ田を植えていく。', [
      Choice.h('早乙女たちと歌いながら植える', '仕事ははかどる。村の者と打ち解ける', () {
        g.l.net += 3;
        g.j(4);
        return '田植え歌が、山あいに響いた。';
      }),
      Choice.h('人の倍の田を植える', '秋の実りが増える。腰が悲鳴を上げる', () {
        g.l.gold += 4;
        g.l.hp -= 8;
        return '夕暮れ、腰が伸ばせなくなった。';
      }),
    ], after: next);
  }),

  SceneDef('v_yoriai', 22, 75, (g) => 1.5, _villager, (g, next) {
    g.ask('村の寄合', '寄合で、入会の山の木を誰がどれだけ伐るかで揉めている。', [
      Choice.h('くじで決めようと言う', '公平だ。損をする者も文句は言えない', () {
        g.l.net += 2;
        g.l.fame += 1;
        return 'くじで決まった。誰も文句は言わなかった。';
      }),
      Choice.h('年寄りの言うとおりにする', '揉めずに済む。若い者は不満だ', () {
        return '年寄りの裁きで決まった。若い者たちが舌打ちした。';
      }),
      Choice.h('自分の取り分を強く求める', '薪が多く手に入る。村で浮く', () {
        g.l.gold += 3;
        g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
        return '薪は多く取れた。寄合のあと、誰も話しかけてこなかった。';
      }),
    ], after: next);
  }),

  SceneDef(
    'v_ox',
    20,
    65,
    (g) => 1.2,
    (g) => _villager(g) && g.l.gold >= 10 && !g.hasFlag('ox'),
    (g, next) {
      g.ask('牛', '隣村の馬喰が、よく働く牛を売りたいという。値は銭10貫。', [
        Choice.h('牛を買う（銭10貫）', '田畑の仕事が楽になる。病めば元も子もない', () {
          g.l.gold -= 10;
          g.setFlag('ox');
          g.j(4);
          return '黒い牛を連れて帰った。子どもたちが大喜びした。';
        }),
        Choice.h('手で耕し続ける', '銭は残る。体はきつい', () {
          g.l.hp -= 4;
          return '今年も、鍬一本で耕した。';
        }),
      ], after: next);
    },
  ),

  SceneDef('v_harvest_fest', 18, 75, (g) => 1.5, _villager, (g, next) {
    g.ask('秋祭り', '豊作の年だ。村の鎮守で、秋祭りが開かれる。', [
      Choice.h('神輿を担ぐ', '村の者に認められる。翌日は体が痛い', () {
        g.l.net += 3;
        g.l.fame += 1;
        g.l.hp -= 3;
        return '神輿を担いで、村じゅうを練り歩いた。';
      }),
      Choice.h('家族と屋台を回る', '心が満たされる', () {
        g.j(8);
        return '子どもに飴を買ってやった。笑い声が絶えなかった。';
      }),
    ], after: next);
  }),

  SceneDef(
    'v_child_sick',
    22,
    55,
    (g) => 1.5,
    (g) => _villager(g) && g.l.kids >= 1 && g.l.hasKidAged(g.year, 0, 12),
    (g, next) {
      g.ask('子の熱', '幼い我が子が、ひどい熱を出した。薬師は町にしかいない。', [
        Choice.h('夜道を走って薬師を呼ぶ（銭4貫）', '間に合えば助かる。銭と体がすり減る', () {
          if (g.l.gold < 4) {
            g.l.hp -= 10;
            return '銭が足りず、薬師に断られた。子は自分の力で持ち直した。';
          }
          g.l.gold -= 4;
          g.l.hp -= 8;
          g.j(4);
          return '夜明け前に薬師を連れて戻った。子の熱は下がった。';
        }),
        Choice.h('村の祈祷師に祈ってもらう', '銭はかからない。効くかは分からない', () {
          if (g.rng.chance(.7)) {
            return '三日三晩の祈りののち、子は目を開けた。';
          }
          g.l.loseKid(g.year, 0, 14);
          g.j(-25);
          g.setFlag('fa_lost_child');
          g.mark('幼い我が子を、熱病で失った');
          return '祈りは、届かなかった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('v_merchant_lowball', 18, 70, (g) => 1.2, _villager, (g, next) {
    g.ask('買い叩き', '町の商人が、今年の米を安く買い叩こうとしている。「嫌なら、よそへ持っていきな」', [
      Choice.h('村の皆で売り値をそろえる', '値は守れる。まとまれなければ足元を見られる', () {
        if (g.rng.chance(.55 + g.l.net / 200)) {
          g.l.gold += 6;
          g.l.net += 2;
          return '村が一つになり、商人は渋々、値を上げた。';
        }
        g.l.gold += 1;
        return '抜け駆けする家が出て、結局安く売るしかなかった。';
      }),
      Choice.h('自分で町まで運んで売る', '高く売れる。道中は遠く、危うい', () {
        if (g.rng.chance(.15)) {
          g.l.hp -= 15;
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          return '峠で追い剥ぎに遭い、米も銭も奪われた。';
        }
        g.l.gold += 8;
        return '町の市で、思ったより良い値で売れた。';
      }),
    ], after: next);
  }),

  SceneDef(
    'v_fishing',
    16,
    70,
    (g) => 2,
    (g) => _villager(g) && g.l.cls.id == 'fisher',
    (g, next) {
      g.ask('沖の雲', '漁に出ようとすると、沖に黒い雲が見える。今日は大漁の兆しもある。', [
        Choice.h('沖へ漕ぎ出す', '大漁なら暮らしが潤う。海が荒れれば帰れない', () {
          if (g.rng.chance(.06)) {
            g.die('嵐の海に漁に出て、戻らなかった', 'yukue');
            return '舟は、黒い雲の下に消えていった。';
          }
          if (g.rng.chance(.6)) {
            g.l.gold += 10;
            return '網が破れそうなほどの大漁だった。';
          }
          g.l.hp -= 10;
          return '雨に打たれ、空の網で戻った。';
        }),
        Choice.h('浜で網を繕う', '命は守れる。稼ぎはない', () {
          return '網を繕いながら、荒れる海を眺めた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'v_wedding_village',
    18,
    45,
    (g) => 2,
    (g) => _villager(g) && !g.l.married,
    (g, next) {
      final name = g.rng.pick(g.l.female ? kGivenM : kGivenF);
      g.ask('村の縁', '隣の家の$nameとは、幼い頃からの顔なじみだ。寄合の帰り道、ふと目が合った。', [
        Choice.h('思いを打ち明ける', '一緒になれるかもしれない。断られれば気まずい', () {
          if (g.rng.chance(.55 + g.l.mi / 200)) {
            g.l.married = true;
            g.meet('伴侶', name, 70);
            g.j(12);
            g.mark('村の顔なじみの$nameと夫婦になった');
            return '$nameは、顔を赤くしてうなずいた。';
          }
          g.j(-6);
          return '$nameは困ったように笑い、首を振った。';
        }),
        Choice.h('胸にしまっておく', '何も変わらない', () => '目をそらし、家路を急いだ。'),
      ], after: next);
    },
  ),
];
