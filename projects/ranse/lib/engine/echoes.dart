import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 伏線の回収（2026-11-23）。前に選んだことが、何年もあとに返ってくる岐路。
/// どれも一生に一度。旗（`setFlag`）を持つ人にだけ出るので、出やすさ（重み）は高めにしてある。
/// id は `e_` で始める（史実の岐路ではないので、その年に必ず出るわけではない）。

int _yr(Game g, int a) => g.l.startYear + a;
int _c(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;

List<SceneDef> buildEchoScenes() => [
  // 滅んだ織田の遺児をかくまった（今川の世）→ 若者になって訪ねてくる。
  SceneDef(
    'e_oda_heir',
    25,
    84,
    (g) => 6,
    (g) => g.hasFlag('hid_oda_heir') && g.active,
    (g, next) {
      final p = g.l.people['織田の遺児'];
      g.ask(
        'あの日の子',
        '戸口に、凛とした若者が立っていた。「清洲が落ちた夜、納戸にかくまってくださった方ですね。${p == null ? '' : '母から、何度も聞かされました。'}」',
        [
          Choice.h('織田の再興に手を貸す', '旧臣たちが集まりつつあるという。今川に知れれば命はない', () {
            if (g.rng.chance(.15)) {
              g.die('織田の遺児の挙兵に加わり、今川の兵に討たれた', 'senshi');
              return '旗を揚げた夜、今川の大軍が押し寄せた。';
            }
            g.l.fame += 20;
            g.setFlag('oda_revival');
            g.mark('かくまった織田の遺児とともに、織田の再興を図った');
            return '若者の目に、あの日の信長と同じ光が宿っていた。';
          }),
          Choice.h('静かに暮らせと諭す', '若者は生き延びる。織田の名は消える', () {
            g.j(4);
            return '若者は深く頭を下げ、どこかへ去っていった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // 伊賀越えで家康を助けた → 家康の天下で報いられる。
  SceneDef(
    'e_iga_goe',
    25,
    84,
    (g) => 8,
    (g) => g.hasFlag('iga_goe') && (g.fa['松平']?.alive ?? false) && g.active,
    (g, next) {
      g.ask('徳川からの使い', '徳川家康から使いが来た。「伊賀の山中で受けた恩を、殿は一日も忘れておられぬ」', [
        Choice.h('徳川の御用を務める', '大きな商いになる。徳川と運命を共にする', () {
          g.l.gold += 50;
          g.setFlag('goyo');
          g.setFlag('tokugawa_goyo');
          g.mark('伊賀越えの恩で、徳川家の御用を務めた');
          return '徳川の御用商人となった。';
        }),
        Choice.h('礼の品だけ受け取る', '身軽なままでいられる', () {
          g.l.gold += 15;
          return '見事な茶碗が一つ届いた。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) >= 1586,
  ),

  // 刀狩で刀を隠した → 関ヶ原の年に掘り出すか。
  SceneDef(
    'e_hid_sword',
    20,
    84,
    (g) => 10,
    (g) => g.hasFlag('hid_sword') && !g.l.female && g.active,
    (g, next) {
      g.ask('床下の刀', '天下がまた二つに割れるという。床下に埋めた刀のことを、ふと思い出した。', [
        Choice.h('掘り出して腰に差す', 'もう一度、刀で身を立てる。百姓には戻れない', () {
          g.setFlag('drew_sword');
          g.l.bu = _c(g.l.bu + 3);
          g.l.ronin = true;
          g.mark('刀狩の日に隠した刀を、乱世の終わりに掘り出した');
          return '油紙を解くと、刀は錆ひとつなく光っていた。';
        }),
        Choice.h('埋めたままにしておく', '百姓として生きる。それでいい', () {
          g.j(4);
          return '鍬を握り直した。刀は、土の中で眠ったままだ。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) >= 1599 && _yr(g, a) <= 1600,
  ),

  // 細川屋敷の侍女たちをかくまった → 細川家からの礼。
  SceneDef(
    'e_gracia',
    20,
    84,
    (g) => 10,
    (g) => g.hasFlag('hid_gracia_maids') && g.active,
    (g, next) {
      g.ask('細川家の礼', '細川家から使いが来た。「奥方さまの最期の折、侍女たちを守ってくださった方に」', [
        Choice.h('礼を受け取る', '細川家との縁ができる', () {
          g.l.gold += 30;
          g.l.net += 3;
          g.meet('恩を受けた家', '細川家', 50);
          return '細川家から、礼の品と書状が届いた。';
        }),
        Choice.h('辞退する', '人として当たり前のことをしたまで', () {
          g.j(6);
          g.l.fame += 5;
          return '辞退した。使いは、深く頭を下げて帰っていった。';
        }),
      ], after: next);
    },
  ),

  // 野の暮らしから足を洗った → 昔の仲間が訪ねてくる。
  SceneDef(
    'e_old_gang',
    25,
    84,
    (g) => 5,
    (g) => g.hasFlag('reformed') && g.active,
    (g, next) {
      final head = g.l.people['頭']?.name ?? '昔の頭';
      g.ask('昔の仲間', '$headの手下だった男が、ひょっこり現れた。「大仕事がある。昔のよしみで、一枚かまねえか」', [
        Choice.h('きっぱり断る', '今の暮らしを守る。恨まれるかもしれない', () {
          if (g.rng.chance(.1)) {
            g.l.hp -= 25;
            return '男は舌打ちして去った。その夜、小屋に火を付けられた。';
          }
          g.j(3);
          return '男は肩をすくめて去っていった。';
        }),
        Choice.h('もう一度だけ手を貸す', '銭になる。二度と戻れなくなるかもしれない', () {
          if (g.rng.chance(.2)) {
            g.die('昔の仲間の仕事に加わり、捕らえられて処刑された', 'seppuku');
            return '仕事の途中で、役人に囲まれた。';
          }
          g.l.gold += 25;
          g.l.flags.remove('reformed');
          g.setFlag('way_outlaw');
          return '一度だけのつもりだった。だが、血が騒いだ。';
        }),
      ], after: next);
    },
  ),

  // 刺客として人を闇に葬った → 依頼主の口封じ。
  SceneDef(
    'e_assassin_past',
    20,
    84,
    (g) => 5,
    (g) => g.hasFlag('assassin') && g.active,
    (g, next) {
      g.ask('口封じ', 'あの仕事の依頼主が、秘密を知る者を消して回っているという噂を聞いた。', [
        Choice.h('先に依頼主を探し出す', '逃げ回るより早い。相手も手練れを抱えている', () {
          if (g.rng.chance(.25)) {
            g.die('かつての依頼主に、口封じに討たれた', 'ansatsu');
            return '探し当てたつもりが、待ち伏せされていた。';
          }
          g.l.fame += 5;
          return '依頼主の屋敷に忍び込み、二度と手を出さぬと誓わせた。';
        }),
        Choice.h('名を変えて遠国へ逃げる', '命は守れる。積み上げたものは捨てる', () {
          g.l.gold = (g.l.gold * .5).floor();
          g.l.net = g.l.net ~/ 2;
          return '名を変え、遠い国へ逃れた。';
        }),
      ], after: next);
    },
  ),

  // 幼なじみと共に道を歩むと決めた → 窮地で駆けつけてくる。
  SceneDef(
    'e_friend_ally',
    28,
    70,
    (g) => 4,
    (g) =>
        g.hasFlag('friend_ally') && g.l.people.containsKey('幼なじみ') && g.active,
    (g, next) {
      final fr = g.l.people['幼なじみ']!;
      g.ask('友の知らせ', '${fr.name}が、息を切らして駆け込んできた。「お前の家を狙っている者がいる。いまなら、まだ間に合う」', [
        Choice.h('友の言葉を信じて備える', '友の目は確かだ。ただの思い過ごしかもしれない', () {
          fr.bond = _c(fr.bond + 10);
          g.l.net += 2;
          g.mark('幼なじみの${fr.name}の知らせで、危うい罠を逃れた');
          return '備えた夜、本当に刺客が来た。${fr.name}がいなければ、命はなかった。';
        }),
        Choice.h('取り合わない', '友を疑うわけではないが、大げさだ', () {
          if (g.rng.chance(.2)) {
            g.l.hp -= 30;
            fr.bond = _c(fr.bond - 10);
            return 'その夜、刺客に襲われ、深手を負った。';
          }
          return '何も起きなかった。${fr.name}は、少し寂しそうだった。';
        }),
      ], after: next);
    },
  ),

  // 人質に出された → 実家と人質先が戦になる。
  SceneDef(
    'e_hostage_war',
    18,
    50,
    (g) => 6,
    (g) => g.hasFlag('hostage') && g.l.female && g.active,
    (g, next) {
      g.ask('盟約が破れた', '実家と、人質として暮らす家との盟約が破れた。人質は斬られるのが習いだ。', [
        Choice.h('夜陰にまぎれて逃げる', '生き延びれば、実家に帰れる', () {
          if (g.rng.chance(.25)) {
            g.die('人質の身で逃げようとして捕らえられ、斬られた', 'seppuku');
            return '城の門で、見張りに見つかった。';
          }
          g.l.fav = _c(g.l.fav + 20);
          g.mark('盟約の破れた夜、人質の城から逃げ延びた');
          return '月のない夜、城を抜け出し、実家にたどり着いた。';
        }),
        Choice.h('覚悟を決めて残る', '城の主の情けにすがる', () {
          if (g.rng.chance(.4)) {
            g.die('盟約が破れ、人質として斬られた', 'seppuku');
            return '覚悟は、できていた。';
          }
          g.l.fame += 10;
          g.mark('盟約が破れても逃げず、人質の城の主に命を許された');
          return '城の主は「見事な覚悟よ」と言い、命を許した。';
        }),
      ], after: next);
    },
  ),

  // 南蛮の薬・南蛮人を見た → 疫病の年に南蛮の薬を頼る。
  SceneDef(
    'e_nanban_cure',
    15,
    84,
    (g) => 4,
    (g) =>
        (g.hasFlag('nanban_medicine') ||
            g.hasFlag('saw_namban') ||
            g.hasFlag('kirishitan')) &&
        g.l.hp < g.l.maxhp * .6,
    (g, next) {
      g.ask('南蛮の薬', '体の具合が思わしくない。昔見た南蛮の医師の薬のことを思い出した。', [
        Choice.h('南蛮寺を訪ねる（銭5貫）', '効くかもしれない。周りの目は冷たい', () {
          if (g.l.gold < 5) return '銭が足りなかった。';
          g.l.gold -= 5;
          _heal(g, 40);
          return '苦い薬を飲むと、嘘のように熱が引いた。';
        }),
        Choice.h('いつもの薬師に頼る', '慣れた手当てだ', () {
          _heal(g, 15);
          return 'いつもの薬湯で、少しだけ楽になった。';
        }),
      ], after: next);
    },
  ),

  // 職人の工房 → 大名に献上される品になる。
  SceneDef(
    'e_craftsman',
    30,
    84,
    (g) => 5,
    (g) => g.hasFlag('craftsman') && g.active,
    (g, next) {
      final lord = g.alive.isEmpty
          ? '国'
          : houseName(
              g,
              (g.alive.toList()..sort((a, b) => b.power.compareTo(a.power)))
                  .first
                  .name,
            );
      g.ask('名工の評判', 'あなたの作った品が、$lord家の目に留まった。献上の品を一つ作れという。', [
        Choice.h('一世一代の品を作る', '名が残る。一年がかりの仕事になる', () {
          g.l.hp -= 15;
          g.l.fame += 20;
          g.l.gold += 30;
          g.mark('$lord家に献上する品を作り、名工と呼ばれた');
          return '献上の品は、天下の名物の一つに数えられた。';
        }),
        Choice.h('弟子に作らせる', '体は楽だ。名は弟子のものになる', () {
          g.l.gold += 10;
          return '弟子の品は、なかなかの出来だった。';
        }),
      ], after: next);
    },
  ),

  // 新田を拓いた → 何年かして実る。
  SceneDef('e_new_field', 25, 84, (g) => 5, (g) => g.hasFlag('new_field'), (
    g,
    next,
  ) {
    g.ask('新田の実り', '若い頃に拓いた田が、今年は見事に実った。', [
      Choice.h('子や村の若い者に分ける', '人望が厚くなる', () {
        g.l.net += 4;
        g.j(8);
        g.mark('若い日に拓いた新田の実りを、村に分けた');
        return '村の者たちが、あの荒れ地の田を「あなたの田」と呼んでいる。';
      }),
      Choice.h('売って蓄える', '暮らしが楽になる', () {
        g.l.gold += 20;
        return '米を売り、蔵に銭が貯まった。';
      }),
    ], after: next);
  }),

  // 庄屋 → 一揆の調停。
  SceneDef('e_shoya', 35, 84, (g) => 5, (g) => g.hasFlag('shoya') && g.active, (
    g,
    next,
  ) {
    g.ask('庄屋の務め', '年貢の取り立てに怒った村の若い者たちが、一揆を起こそうとしている。代官は、庄屋に鎮めろと言う。', [
      Choice.h('代官に年貢の減免を掛け合う', '村は救われるかもしれない。代官ににらまれる', () {
        if (g.rng.chance(.5)) {
          g.l.fame += 10;
          g.l.net += 4;
          g.mark('庄屋として代官に掛け合い、一揆を未然に防いだ');
          return '代官は渋々、年貢を軽くした。';
        }
        g.l.hp -= 15;
        return '代官は怒り、あなたを打ち据えた。';
      }),
      Choice.h('若い者たちを抑える', '村は守られる。若い者の恨みを買う', () {
        g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
        return '若い者たちを説き伏せた。目を合わせない者もいた。';
      }),
    ], after: next);
  }),

  // 子どもの頃に合戦を見た → 初めて戦に出る年に、あの光景がよみがえる。
  SceneDef(
    'e_saw_battle',
    16,
    30,
    (g) => 3,
    (g) =>
        g.hasFlag('saw_battle') &&
        g.l.rank >= 1 &&
        g.canFight &&
        !g.hasFlag('first_battle') &&
        g.active,
    (g, next) {
      g.ask('あの日の戦場', '戦の支度をしていると、幼い日に見た合戦の光景がよみがえった。倒れた兵の顔が、今も忘れられない。', [
        Choice.h('二度と負けぬよう鍛える', '恐れを力に変える', () {
          g.l.bu = _c(g.l.bu + 3);
          g.mark('幼い日に見た戦場を胸に、武芸を磨いた');
          return '恐れを振り払うように、槍を振るった。';
        }),
        Choice.h('戦わずに済む道を探す', '命の重さを知っている', () {
          g.l.chi = _c(g.l.chi + 2);
          g.setFlag('pacifist');
          return '人を殺さずに済む手立てはないかと、考え続けた。';
        }),
      ], after: next);
    },
  ),

  // 父を早くに亡くし家長になった → 弟や妹を養う。
  SceneDef(
    'e_family_head',
    15,
    28,
    (g) => 4,
    (g) => g.hasFlag('family_head') && g.active,
    (g, next) {
      final sib = g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF);
      g.ask('家を背負う', '弟や妹たちは、まだ幼い。末の$sibが、あなたの袖を引いた。', [
        Choice.h('家に残って弟妹を育てる', '家族は守られる。自分の夢は遠のく', () {
          g.l.net += 3;
          g.j(5);
          g.meet('弟妹', '末の$sib', 70);
          g.mark('父亡きあと、家に残って弟や妹を育て上げた');
          return '弟や妹たちは、あなたを父のように慕って育った。';
        }),
        Choice.h('稼ぎに出て仕送りする', '外で身を立てられる。家族とは離れる', () {
          g.l.gold += 5;
          g.mark('父亡きあと、家を出て稼ぎ、弟や妹に仕送りした');
          return '村を出る朝、$sibが泣きながら手を振っていた。';
        }),
      ], after: next);
    },
  ),

  // 歴史を変えたのに名乗り出なかった → 晩年、誰かが気づく。
  SceneDef('e_silent_hero', 45, 84, (g) => 8, (g) => g.hasFlag('silent_hero'), (
    g,
    next,
  ) {
    g.ask('昔語り', '孫ほどの若者が、桶狭間の話をせがんだ。「あの日、今川の本陣に急を知らせた者がいたそうですね。誰だったのでしょう」', [
      Choice.h('自分だったと明かす', '胸のつかえが下りる。信じてもらえるかは分からない', () {
        g.j(8);
        g.mark('晩年、桶狭間で歴史を変えたのは自分だったと明かした');
        return '若者は目を丸くし、それから、ゆっくりとうなずいた。';
      }),
      Choice.h('笑ってはぐらかす', '秘密は墓まで持っていく', () {
        g.j(4);
        return '「さあな。雨の中の、ただの百姓だろうよ」';
      }),
    ], after: next);
  }),
];
