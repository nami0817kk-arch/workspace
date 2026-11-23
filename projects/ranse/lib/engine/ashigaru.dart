import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'rng.dart';

/// 足軽（位1〜2）の暮らしの岐路（2026-11-23）。成人した人生で最も多い「足軽・侍」の道なのに、
/// 位1〜2には合戦と縁談のほか固有の岐路がほとんどなかったため。id は `a_`。
/// 足軽の暮らしの岐路（`ashigaru_life.dart`）を足したときに、ここの8つが押し出されないよう重みを上げた（2026-11-23）。

int _c(int v) => clampInt(v, 0, 100);
bool _ashigaru(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank <= 2 &&
    g.canFight &&
    g.active &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

List<SceneDef> buildAshigaruScenes() => [
  SceneDef('a_nagaya', 15, 40, (g) => 3, _ashigaru, (g, next) {
    g.ask('足軽長屋', '長屋の隣の男が、夜ごと酒を飲んで騒ぐ。今夜もまた、壁越しに怒鳴り声が聞こえる。', [
      Choice.h('殴り込んで黙らせる', '静かになるかもしれない。喧嘩は御法度だ', () {
        if (g.rng.chance(.5)) {
          g.l.bu = _c(g.l.bu + 1);
          return '一発で黙った。翌朝、男は気まずそうに頭を下げた。';
        }
        g.l.fav = _c(g.l.fav - 5);
        g.l.hp -= 8;
        return '大喧嘩になり、組頭に二人とも叱られた。';
      }),
      Choice.h('酒を持って隣を訪ねる', '仲良くなれるかもしれない。銭がかかる', () {
        g.l.gold = g.l.gold >= 1 ? g.l.gold - 1 : 0;
        g.l.net += 3;
        g.meet('朋輩', '足軽の${g.rng.pick(kGivenM)}', 45);
        return '男は国に残した妻子の話をして、泣いた。';
      }),
    ], after: next);
  }),

  SceneDef('a_gamble', 15, 45, (g) => 2.5, _ashigaru, (g, next) {
    g.ask('博打', '陣中の暇つぶしに、朋輩たちが賽を振っている。「一口どうだ」', [
      Choice.h('有り金を張る（銭5貫）', '勝てば倍。負ければ素寒貧', () {
        if (g.l.gold < 5) return '張れるほどの銭がなかった。';
        if (g.rng.chance(.45 + g.l.un / 400)) {
          g.l.gold += 5;
          return '賽の目が冴えた。朋輩たちが舌打ちした。';
        }
        g.l.gold -= 5;
        g.j(-3);
        return 'すっからかんになった。';
      }),
      Choice.h('見ているだけにする', '銭は守れる。付き合いが悪いと言われる', () {
        g.l.net = g.l.net >= 1 ? g.l.net - 1 : 0;
        return '朋輩たちは、つまらなそうな顔をした。';
      }),
      if (g.l.un >= 60)
        Choice.h('ここぞの一番にだけ張る', '流れを見て、勘の働いたときだけ賽に乗る', () {
          if (g.l.gold < 2) return '張れるほどの銭がなかった。';
          if (g.luck()) {
            g.l.gold += 6;
            g.l.net += 2;
            return '三番見送り、四番目に張った。賽は思ったとおりの目を出した。朋輩たちが、どよめいた。';
          }
          g.l.gold -= 2;
          return '勘が働いたと思った一番は、外れた。深追いはしなかった。';
        }, via: '運'),
    ], after: next);
  }),

  SceneDef(
    'a_randori',
    15,
    50,
    (g) => 2.5,
    (g) => _ashigaru(g) && g.hasFlag('first_battle'),
    (g, next) {
      g.ask('乱取り', '勝ち戦のあと、足軽たちが敵地の村へなだれ込んでいく。米も、牛も、人までも奪っていく。', [
        Choice.h('自分も加わる', '銭になる。目にしたものは忘れられない', () {
          g.l.gold += g.rng.range(5, 12);
          g.j(-6);
          g.setFlag('randori');
          return '米と反物を担いで帰った。泣き叫ぶ声が耳から離れなかった。';
        }),
        Choice.h('村の者を逃がす', '恨まれずに済む。朋輩には笑われる', () {
          g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
          g.j(4);
          g.setFlag('spared_village');
          g.mark('乱取りの村で、村人を裏山へ逃がした');
          return '裏山への道を教えた。老婆が、何度も手を合わせていた。';
        }),
        Choice.h('陣に残る', '何も得ない。何も失わない', () => '陣で、遠くの煙を見ていた。'),
      ], after: next);
    },
  ),

  SceneDef(
    'a_comrade_death',
    16,
    50,
    (g) => 3.5,
    (g) => _ashigaru(g) && g.l.people.containsKey('朋輩'),
    (g, next) {
      final p = g.l.people['朋輩']!;
      g.ask('朋輩の死', '${p.name}が、先の戦で討たれた。国には妻と幼い子が残されているという。', [
        Choice.h('形見を届けに行く（銭5貫）', '筋は通る。銭と日数がかかる', () {
          g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
          g.l.mi = _c(g.l.mi + 2);
          g.mark('討死した朋輩${p.name}の形見を、国の妻子に届けた');
          return '形見の守り袋を渡すと、妻は声を殺して泣いた。';
        }),
        Choice.h('酒を手向けて弔う', '心の中で別れを告げる', () {
          g.j(-5);
          return '${p.name}の好きだった濁り酒を、地面に注いだ。';
        }),
      ], after: next);
      g.l.people.remove('朋輩');
    },
  ),

  SceneDef('a_spear', 15, 35, (g) => 2.5, _ashigaru, (g, next) {
    g.ask('長槍の稽古', '組頭が、三間の長槍で槍衾を組む稽古をさせている。息が合わねば、敵の騎馬に崩される。', [
      Choice.h('先頭に立って稽古する', '腕と信頼が上がる。体はくたくただ', () {
        g.l.bu = _c(g.l.bu + 2);
        g.l.fav = _c(g.l.fav + 3);
        g.l.hp -= 5;
        return '組頭に名を覚えられた。';
      }),
      Choice.h('後ろで手を抜く', '体は楽だ。いざというとき困るかもしれない', () {
        return '要領よく、稽古をやり過ごした。';
      }),
      if (g.l.bu >= 60)
        Choice.h('槍衾の要を買って出る', '列の真ん中で皆の槍を支える。腕がなければ務まらない', () {
          g.l.hp -= 4;
          if (g.might()) {
            g.l.fav = _c(g.l.fav + 6);
            g.l.net += 3;
            g.l.merit += 2;
            return '馬に見立てた丸太を、列は一歩も退かずに受け止めた。組頭が「次の戦は、お前が要だ」と言った。';
          }
          g.l.fav = _c(g.l.fav + 2);
          return '丸太に押されて列がたわんだ。それでも、要を買って出た心意気は組頭に買われた。';
        }, via: '武'),
    ], after: next);
  }),

  SceneDef(
    'a_reward',
    16,
    50,
    (g) => 2.5,
    (g) => _ashigaru(g) && g.l.merit >= 10,
    (g, next) {
      g.ask('恩賞の分け方', '組の手柄に、恩賞の銭が下された。組頭が、分け方をあなたに任せるという。', [
        Choice.h('手柄に応じて分ける', '筋は通る。少ない者は不満だ', () {
          g.l.gold += 6;
          g.l.fav = _c(g.l.fav + 3);
          return '手柄の多い者ほど多く分けた。文句を言う者もいた。';
        }),
        Choice.h('皆で等しく分ける', '組がまとまる。自分の取り分は減る', () {
          g.l.gold += 2;
          g.l.net += 4;
          g.setFlag('fair_share');
          return '皆で等しく分けた。朋輩たちの目が、少し変わった。';
        }),
        if (g.l.un >= 60)
          Choice.h('籤で分ける', '恨みっこなし。長い籤を誰が引くかは、神仏しだい', () {
            g.l.net += 2;
            if (g.luck(.25)) {
              g.l.gold += 9;
              return 'こよりの籤を皆で引いた。いちばん長い一本は、あなたの手にあった。誰も文句は言えなかった。';
            }
            g.l.gold += 2;
            return 'こよりの籤を皆で引いた。長い一本は若い足軽が引き当て、皆で胴上げをした。';
          }, via: '運'),
      ], after: next);
    },
  ),

  SceneDef(
    'a_desert',
    16,
    45,
    (g) => 1.5 + (g.l.joy < 30 ? 2 : 0) + (g.l.fav < 15 ? 1 : 0),
    _ashigaru,
    (g, next) {
      g.ask('逃げ散る夜', '負け戦続きで、陣から逃げ出す足軽が後を絶たない。朋輩が「今夜、一緒に逃げよう」と囁いた。', [
        Choice.h('一緒に逃げる', '命は守れる。見つかれば斬られる', () {
          if (g.rng.chance(.2)) {
            g.die('陣から逃げようとして見つかり、斬られた', 'seppuku');
            return '柵を越えたところで、見張りに見つかった。';
          }
          final l = g.l;
          l.rank = 0;
          l.lord = null;
          l.ronin = true;
          g.mark('負け戦の陣から逃げ出し、足軽をやめた');
          return '闇にまぎれて、陣を抜け出した。';
        }),
        Choice.h('踏みとどまる', '主家への奉公を貫く', () {
          g.l.fav = _c(g.l.fav + 5);
          return '朋輩は一人で消えた。翌朝、陣は少し静かだった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('a_letter_home', 15, 40, (g) => 2, _ashigaru, (g, next) {
    g.ask('国への便り', '陣に、国の母から便りが届いた。字の読める朋輩に読んでもらうと、「体を大事に」とだけあった。', [
      Choice.h('返事を書いてもらう', '母は安心する', () {
        g.j(5);
        return '「達者でいる」とだけ書いてもらった。';
      }),
      Choice.h('字を習い始める', '自分で読み書きできるようになる', () {
        g.l.chi = _c(g.l.chi + 3);
        g.setFlag('learned_letters');
        return '陣の夜ごと、朋輩に字を教わった。';
      }),
    ], after: next);
  }),
];
