import 'actions.dart';
import 'game.dart';
import 'rng.dart';

class EventDef {
  EventDef(this.w, this.c, this.run);
  final double w;
  final bool Function() c;
  final void Function() run;
}

const _poor = ['farmer', 'fisher', 'beggar'];

/// 子ども期（5〜14歳）の出来事。
List<EventDef> buildChildEvents(Game g) {
  final rng = g.rng;
  return [
    EventDef(3, () => true, () {
      g.ask('熱病', '村に熱病が流行り、あなたも床に伏した。', [
        Choice('薬湯を飲ませてもらう（銭3貫）', () {
          final l = g.l;
          if (l.gold >= 3) {
            l.gold -= 3;
            l.hp -= rng.range(3, 8);
            g.j(-2);
            return '薬湯が効き、数日で熱が引いた。';
          }
          l.hp -= rng.range(15, 30);
          g.j(-4);
          return '銭がなく、ただ耐えるしかなかった。';
        }),
        Choice('ただ耐える', () {
          g.l.hp -= rng.range(10, 28);
          g.j(-4);
          return rng.chance(.5 + g.l.un / 300) ? '運よく熱は引いた。' : '長く寝込み、体力を大きく削られた。';
        }),
      ]);
    }),
    EventDef(2.5, () => _poor.contains(g.l.cls.id), () {
      g.ask('飢饉', '凶作で、家の蔵は空になった。', [
        Choice('草の根や木の皮を食べて凌ぐ', () {
          g.l.hp -= 10;
          g.j(-6);
          return '空腹に耐え、冬を越した。';
        }),
        Choice('山に入って獲物を探す', () {
          if (rng.chance(.5)) {
            g.l.bu++;
            g.j(2);
            return 'ウサギを仕留め、家族で分け合った。';
          }
          g.l.hp -= 12;
          g.j(-6);
          return '何も獲れなかった。';
        }),
      ]);
    }),
    EventDef(2, () => true, () {
      g.ask('戦火', '近くで合戦があり、村が焼かれた。', [
        Choice('家族と山に逃げる', () {
          g.l.gold = g.l.gold >= 2 ? g.l.gold - 2 : 0;
          g.j(-8);
          return '命からがら逃げ延びたが、家は焼けた。';
        }),
        Choice('物陰から戦を見つめる', () {
          g.l.chi++;
          g.j(-10);
          return '人が人を殺すさまを、目に焼き付けた。';
        }),
      ]);
    }),
    EventDef(1.5, () => g.age >= 7, () {
      g.ask('父の死', '父が病に倒れ、この世を去った。', [
        Choice('母と家を支える', () {
          final l = g.l;
          l.gold = l.gold >= 2 ? l.gold - 2 : 0;
          l.sei++;
          g.j(-12);
          // 家計の柱を失い、家の格が一つ下がる。実際の身分は元服時に決まる。
          if (l.birthRank >= 1) {
            l.birthRank--;
            return '幼いながら家を支える覚悟を決めた。家の暮らしは苦しくなった。';
          }
          return '幼いながら家を支える覚悟を決めた。';
        }),
        Choice('寺に預けられる', () {
          g.l.chi += 5;
          g.j(-10);
          return '寺に入り、経と文字を学び始めた。';
        }),
      ]);
    }),
    EventDef(1.2, () => _poor.contains(g.l.cls.id), () {
      g.ask('人買い', '戦で攫われ、人買いの手に落ちかけている。', [
        Choice('必死に逃げる', () {
          final l = g.l;
          if (rng.chance(.4 + l.bu / 200 + l.un / 300)) {
            l.bu += 2;
            g.j(-6);
            return '縄を抜け、夜の闇に逃げ延びた。';
          }
          l.hp -= 20;
          l.net = l.net >= 2 ? l.net - 2 : 0;
          g.j(-20);
          return '捕まり、殴られた。心に深い傷が残った。';
        }),
        Choice('耐えて機会を待つ', () {
          g.l.hp -= 8;
          g.l.chi++;
          g.j(-15);
          return '従順に装い、やがて解き放たれた。何かが心から欠け落ちた。';
        }),
      ]);
    }),
    EventDef(2, () => g.age >= 8, () {
      g.ask('旅の師', '旅の者が、一晩の宿の礼に何か教えてやろうと言う。', [
        Choice('文字と算術を教わる', () {
          g.l.chi += 3;
          g.l.sei += 1;
          g.j(3);
          return '知が3上がった。';
        }),
        Choice('棒術を教わる', () {
          g.l.bu += 3;
          g.j(3);
          return '武が3上がった。';
        }),
      ]);
    }),
    EventDef(2, () => true, () {
      g.ask('友', '同じ年頃の子と、ささいな喧嘩になった。', [
        Choice('殴り合って決着をつける', () {
          g.l.bu++;
          g.l.hp -= 4;
          if (rng.chance(.5)) {
            g.l.net += 2;
            g.j(4);
            return '殴り合ううち、無二の友になった。';
          }
          g.j(-2);
          return '痣だけが残った。';
        }),
        Choice('先に謝る', () {
          g.l.mi++;
          g.l.net += 2;
          g.j(2);
          return '先に頭を下げ、友ができた。';
        }),
      ]);
    }),
    EventDef(1.8, () => g.l.order >= 2 && g.l.cls.id != 'beggar' && g.age >= 9, () {
      g.ask('奉公の話', '継ぐ家のない子は、よそへ出される。奉公の口が回ってきた。', [
        Choice('奉公に出る', () {
          g.l.gold += 3;
          g.l.sei += 3;
          g.l.hp -= 5;
          g.j(-5);
          return '見知らぬ家で、朝から晩まで働いた。商いや算盤を覚えた。';
        }),
        Choice('家に居座る', () {
          g.j(-3);
          return '居場所のない家で、肩身の狭い思いをした。';
        }),
      ]);
    }),
  ];
}

/// 大人（15歳〜）の出来事。
List<EventDef> buildEvents(Game g) {
  final rng = g.rng;
  return [
    EventDef(3, () => g.l.rank == 0 && _poor.contains(g.l.cls.id), () {
      g.ask('凶作', '長雨で稲が実らない。年貢の取り立ては容赦ない。', [
        Choice('蓄えを切り崩して食いつなぐ', () {
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          g.l.hp -= 8;
          g.j(-5);
          return '飢えをしのいだが、体力を削られた。';
        }),
        Choice('山に入って獲物を狩る', () {
          g.l.bu++;
          g.l.hp -= 5;
          if (rng.chance(.5)) {
            g.l.gold += 4;
            return '獲物を捕らえ、肉と毛皮で銭4貫を得た。';
          }
          g.j(-4);
          return '収穫なく、ひもじさだけが残った。';
        }),
      ]);
    }),
    EventDef(2, () => true, () {
      g.ask('疫病', '近隣で熱病が広がっている。', [
        Choice('薬師に頼る（銭5貫）', () {
          final l = g.l;
          if (l.gold < 5) {
            l.hp -= rng.range(15, 30);
            return '銭が足りず、薬師に断られて寝込んだ。';
          }
          l.gold -= 5;
          l.hp -= rng.range(3, 10);
          return '薬のおかげで軽く済んだ。';
        }),
        Choice('耐えしのぐ', () {
          if (rng.chance(.4 + g.l.un / 250)) {
            g.l.hp -= rng.range(5, 12);
            return '運よく熱は早く引いた。';
          }
          g.l.hp -= rng.range(20, 40);
          g.j(-4);
          return '高熱にうなされ、死の淵を見た。';
        }),
      ]);
    }),
    EventDef(3, () => g.l.rank <= 2, () {
      g.ask('野盗の襲来', '野盗の一団が村を襲った。', [
        Choice('立ち向かう', () {
          final l = g.l;
          if (rng.chance(clampD(.2 + l.bu / 130 + l.un / 400, .1, .85))) {
            l.fame += 5;
            l.bu += 2;
            l.merit += 3;
            g.j(3);
            return '野盗を撃退し、名が少し知れ渡った。';
          }
          l.hp -= 20;
          l.gold = l.gold >= 4 ? l.gold - 4 : 0;
          g.j(-5);
          return '返り討ちにあい、傷を負い金品も奪われた。';
        }),
        Choice('隠れてやり過ごす', () {
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          return '身を隠して難を逃れたが、蓄えを奪われた。';
        }),
      ]);
    }),
    EventDef(2, () => g.l.rank == 0 && g.l.chi < 80, () {
      g.ask('旅の僧', '旅の僧が、読み書きを教えてやろうと言う。', [
        Choice('弟子入りして学ぶ', () {
          g.l.chi += 4;
          g.l.hp -= 5;
          return '寝食を忘れて学び、知が4上がった。';
        }),
        Choice('断る', () => '忙しい身。誘いは断った。'),
      ]);
    }),
    EventDef(2, () => g.l.bu < 75, () {
      g.ask('剣客との出会い', '腕の立つ剣客が、手ほどきを授けてもよいと言う。', [
        Choice('銭5貫で教えを乞う', () {
          if (g.l.gold < 5) return '銭が足りず、教えを乞えなかった。';
          g.l.gold -= 5;
          g.l.bu += 4;
          return '一手の理を得て、武が4上がった。';
        }),
        Choice('丁重に断る', () => '独学で行くことにした。'),
      ]);
    }),
    EventDef(2, () => g.l.gold >= 10, () {
      g.ask('商人の儲け話', '商人が、銭10貫を預ければ倍にすると持ちかけてきた。', [
        Choice('乗る（銭10貫）', () {
          g.l.gold -= 10;
          if (rng.chance(.45 + g.l.un / 250 + g.l.chi / 500)) {
            g.l.gold += 25;
            return '商いは当たり、銭25貫になって戻った！';
          }
          g.j(-4);
          return '商人は姿をくらました。騙されたのだ。';
        }),
        Choice('断る', () => 'うまい話には裏がある。断った。'),
      ]);
    }),
    EventDef(2.5, () => g.year >= 1543 && !g.l.gun && g.canFight, () {
      g.ask('鉄砲', '南蛮渡来の鉄砲を目にする機会を得た。', [
        Choice('銭8貫で撃ち方を習う', () {
          if (g.l.gold < 8) return '銭が足りなかった。';
          g.l.gold -= 8;
          g.l.gun = true;
          if (g.has('gunner')) {
            g.l.bu += 5;
            return '見事な筋！鉄砲の腕を身につけた。合戦で有利になる。';
          }
          return '鉄砲の扱いを覚えた。合戦で有利になる。';
        }),
        Choice('見るだけにする', () => '轟音に肝を冷やしただけだった。'),
      ]);
    }),
    EventDef(3, () => g.l.rank >= 2 && g.l.rank < 8, () {
      g.ask('同僚の讒言', '出世を妬む者が、主君に根も葉もない噂を吹き込んだ。', [
        Choice('銭10貫で口を封じる', () {
          if (g.l.gold < 10) {
            g.l.fav -= 8;
            return '銭が足りず、噂は広まってしまった。';
          }
          g.l.gold -= 10;
          return '銭で黙らせ、事なきを得た。';
        }),
        Choice('堂々と申し開く', () {
          final l = g.l;
          if (rng.chance(clampD(.3 + (l.chi + l.mi) / 250, .2, .85))) {
            l.fav += 5;
            return '筋道だった弁明が評価され、かえって信頼が増した。';
          }
          l.fav -= 10;
          g.j(-4);
          return '弁明は通らず、信頼を損ねた。';
        }),
        Choice('放っておく', () {
          g.l.fav -= 10;
          return '噂は広まり、信頼が落ちた。';
        }),
      ]);
    }),
    EventDef(3, () => g.l.rank >= 2 && g.l.rank < 8, () {
      g.ask('密命', '主君が、人目を忍んで重大な役目を命じた。', [
        Choice('引き受ける', () {
          final l = g.l;
          if (rng.chance(clampD(.35 + (l.chi + l.mi + l.un) / 400, .2, .85))) {
            l.merit += 12;
            l.fav += 10;
            l.fame += 3;
            return '密命を果たし、主君の覚えがめでたくなった。功12。';
          }
          l.hp -= 15;
          l.fav -= 4;
          return '密命は失敗に終わり、傷を負った。';
        }),
        Choice('辞退する', () {
          g.l.fav -= 5;
          return '辞退したが、主君は不満げだった。';
        }),
      ]);
    }),
    EventDef(1.2, () => g.l.rank >= 3 && g.l.rank < 8, () {
      g.ask('主君の急死', '主君が急死した。後継をめぐり家中が割れている。', [
        Choice('嫡子を支持する', () {
          g.l.fav += g.has('loyal') ? 18 : 10;
          g.l.merit += 5;
          return '嫡子を支え、忠義の臣と目された。';
        }),
        Choice('弟君を担ぐ（賭け）', () {
          final l = g.l;
          if (rng.chance(.4 + (g.has('amb') ? .1 : 0) + l.un / 400)) {
            l.fav += 20;
            l.merit += 20;
            return '弟君が家督を継ぎ、擁立の功で厚遇された！';
          }
          l.rank--;
          l.fav = l.fav - 20 < 5 ? 5 : l.fav - 20;
          g.j(-8);
          return '擁立に失敗し、降格された。';
        }),
        Choice('静観する', () => '成り行きを見守った。'),
      ]);
    }),
    EventDef(2, () => !g.l.married && g.age >= 16, () {
      g.ask('縁談', '近隣の家から縁談が舞い込んだ。', [
        Choice('受ける', () {
          g.l.married = true;
          g.l.net += 3;
          g.l.gold += 8 + g.l.rank * 4;
          g.j(10);
          return '縁談を受け、縁を結んだ。親族の縁も広がった。';
        }),
        Choice('断る', () => 'まだ身を固める時ではない。'),
      ]);
    }),
    EventDef(2, () => g.l.rank >= 4 && g.l.rank < 8, () {
      g.ask('茶会', '名のある人物が茶会に招いてくれた。', [
        Choice('出席する（銭5貫）', () {
          if (g.l.gold < 5) return '銭が足りず、出席を見送った。';
          g.l.gold -= 5;
          g.l.fame += 8;
          g.l.net += 3;
          g.j(3);
          return '茶会で名を上げ、人脈も広がった。';
        }),
        Choice('欠席する', () => '茶の湯より鍛錬を選んだ。'),
      ]);
    }),
    EventDef(3, () => g.l.rank == 0 && !g.l.female && !g.l.ronin && g.l.cls.rank == 0, () {
      final home = homeLord(g);
      g.ask('足軽の徴募', '$home家が合戦に備え、百姓から人手を集めている。', [
        Choice('足軽として従う', () {
          g.l.rank = 1;
          if (g.l.maxRank < 1) g.l.maxRank = 1;
          g.l.lord = home;
          g.l.fav = 20;
          return '$home家の足軽となった。';
        }),
        Choice('逃げ隠れる', () {
          g.l.hp -= 6;
          g.l.fame -= 2;
          g.j(-2);
          return '山に隠れてやり過ごした。';
        }),
      ]);
    }),
    EventDef(2.5, () => g.l.rank == 0 && g.l.female && !g.l.ronin, () {
      final home = homeLord(g);
      g.ask('奉公の口', '$home家の奥向きで、下女を探している。', [
        Choice('奉公に上がる', () {
          g.l.rank = 1;
          if (g.l.maxRank < 1) g.l.maxRank = 1;
          g.l.lord = home;
          g.l.fav = 20;
          return '$home家の下女として奉公に上がった。';
        }),
        Choice('断る', () => '慣れた暮らしに留まることにした。'),
      ]);
    }),
    EventDef(2, () => g.l.rank == 0, () {
      g.ask('村が戦火に', '近くで合戦があり、村に火の手が上がった。', [
        Choice('家財を持って逃げる', () {
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          g.l.hp -= 6;
          g.j(-8);
          return '命だけは守ったが、蓄えを失った。';
        }),
        Choice('落ち武者を襲い、具足を奪う', () {
          if (rng.chance(.4 + g.l.bu / 200)) {
            g.l.gold += 12;
            g.l.bu += 1;
            g.j(-4);
            return '具足と刀を手に入れ、銭12貫になった。';
          }
          g.l.hp -= 20;
          g.j(-6);
          return '反撃され、手傷を負った。';
        }),
      ]);
    }),
    EventDef(1.5, () => g.l.rank == 0 && _poor.contains(g.l.cls.id), () {
      g.ask('一揆の誘い', '村の者が、年貢の引き下げを求め一揆に加われと誘ってきた。', [
        Choice('加わる', () {
          final l = g.l;
          if (rng.chance(clampD(.3 + (l.bu + l.un) / 300, .2, .7))) {
            l.fame += 12;
            l.gold += 8;
            g.j(5);
            return '一揆は成功し、名が知れた。銭8貫の分け前も。';
          }
          l.hp -= 30;
          l.fame -= 5;
          g.j(-8);
          return '一揆は鎮圧された。傷を負い、逃げ延びた。';
        }),
        Choice('断る', () => '関わらずに過ごした。'),
      ]);
    }),
    EventDef(1.5, () => g.l.rank == 0 && !g.l.female && g.l.mi >= 45, () {
      final al = g.alive..sort((a, b) => b.power.compareTo(a.power));
      final top = al.first.name;
      g.ask('草履取りの口', '有力な$top家の重臣が、草履取りを探している。', [
        Choice('志願する', () {
          final l = g.l;
          if (rng.chance(clampD(.25 + l.mi / 200 + l.un / 400, .1, .8))) {
            l.rank = 1;
            if (l.maxRank < 1) l.maxRank = 1;
            l.lord = top;
            l.fav = 30;
            l.ronin = false;
            g.j(5);
            return '気に入られ、$top家に取り立てられた！';
          }
          return '他の志願者に押し負けた。';
        }),
        Choice('見送る', () => '縁がなかったと思うことにした。'),
      ]);
    }),
    EventDef(2, () => g.l.cls.id == 'ninja' && g.l.rank < 8, () {
      g.ask('忍びの務め', '里から、他国への潜入任務が届いた。', [
        Choice('引き受ける', () {
          final l = g.l;
          if (rng.chance(.5 + l.chi / 300)) {
            l.gold += 15;
            l.fame += 3;
            l.net += 2;
            return '任務を果たし、銭15貫と情報網を得た。';
          }
          l.hp -= 25;
          g.j(-5);
          return '任務は失敗。深手を負って逃げ帰った。';
        }),
        Choice('断る', () => '里の頭目は不満げだったが、受け入れた。'),
      ]);
    }),
    EventDef(3, () => g.l.rank == 8, () {
      g.ask('重臣の不穏', '重臣の一人が謀反を企てているとの噂がある。', [
        Choice('先手を打って粛清する', () {
          g.fa[g.l.lord]!.power -= 2;
          g.j(-4);
          return '重臣を粛清した。勢力はやや削がれたが、家中は引き締まった。';
        }),
        Choice('様子を見る', () {
          if (rng.chance(.35)) {
            g.fa[g.l.lord]!.power -= 6;
            return '謀反が起き、勢力が大きく損なわれた！';
          }
          return '噂は噂に過ぎなかった。';
        }),
      ]);
    }),
    EventDef(2, () => g.l.rank == 8, () {
      g.ask('同盟の申し出', '近隣の大名が、縁組を通じた同盟を求めてきた。', [
        Choice('受ける', () {
          g.fa[g.l.lord]!.power += 3;
          g.l.gold += 20;
          return '同盟が成り、勢力と銭が増えた。';
        }),
        Choice('断る', () => '独力で道を切り開くと決めた。'),
      ]);
    }),
    EventDef(2, () => g.l.rank == 8, () {
      g.ask('領内の不作', '領内が不作に見舞われた。', [
        Choice('蔵を開いて救う（銭20貫）', () {
          if (g.l.gold < 20) {
            g.fa[g.l.lord]!.power -= 3;
            g.j(-4);
            return '銭が足りず民を救えなかった。勢力が落ちた。';
          }
          g.l.gold -= 20;
          g.fa[g.l.lord]!.power += 1;
          g.j(4);
          return '民を救い、領国の信望が高まった。';
        }),
        Choice('年貢を取り立てる', () {
          g.fa[g.l.lord]!.power -= 2;
          g.l.gold += 15;
          g.j(-3);
          return '銭は得たが、民は疲弊した。';
        }),
      ]);
    }),
    // 女性・家族の出来事
    EventDef(2, () => g.l.female && g.l.married && g.l.rank >= 1, () {
      g.ask('夫の死', '夫が戦で命を落とした。', [
        Choice('家を守り抜く', () {
          g.j(-25);
          g.l.merit += 10;
          g.l.fav += 8;
          return '悲しみを胸に、家を守る決意をした。';
        }),
        Choice('出家して尼となる', () {
          final l = g.l;
          g.j(-5);
          l.married = false;
          l.rank = 0;
          l.lord = null;
          l.troops = 0;
          l.ronin = true;
          l.hp = l.hp + 15 > l.maxhp ? l.maxhp : l.hp + 15;
          return '髪を下ろし、亡き夫の菩提を弔う日々が始まった。';
        }),
      ]);
    }),
    EventDef(1.5, () => g.l.female && g.l.rank >= 3 && g.l.rank < 8 && !g.l.married && g.age >= 16, () {
      g.ask('政略結婚', '家のため、有力な家への輿入れが決まった。', [
        Choice('受け入れる', () {
          final l = g.l;
          l.married = true;
          l.rank = l.rank + 1 > 7 ? 7 : l.rank + 1;
          if (l.rank > l.maxRank) l.maxRank = l.rank;
          l.fav += 10;
          l.net += 4;
          g.j(-6);
          return '輿入れを果たし、家の絆を結んだ。位が上がった。';
        }),
        Choice('拒む', () {
          g.l.fav -= 12;
          g.j(2);
          return '縁談を拒み、家中の不興を買った。';
        }),
      ]);
    }),
    EventDef(1.2, () => g.l.female && g.l.rank >= 6 && g.l.rank < 8 && g.l.kids >= 1, () {
      g.ask('後見', '当主が急死した。幼い嫡子に代わり、後見を求める声が上がっている。', [
        Choice('後見を引き受ける', () {
          final l = g.l;
          l.rank = 8;
          l.maxRank = 8;
          l.fame += 25;
          l.gold += 40;
          l.troops = 0;
          g.j(5);
          return '幼い当主の後見として、一国の政を担うことになった！';
        }),
        Choice('奥に退く', () {
          g.j(3);
          return '政争から身を引き、静かに暮らすことにした。';
        }),
      ]);
    }),
  ];
}
