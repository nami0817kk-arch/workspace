import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'rng.dart';

/// 幼少期（5〜14歳）の岐路を足す（2026-11-23）。
/// 史実以外の子どもの場面が12しかなく、生まれ直しても子ども時代が同じ場面の繰り返しになっていたため。
/// 身分・生まれ順・性別で出る場面を変える。id は `c_`。子どもの死は稀にとどめる。

int _c(int v) => clampInt(v, 0, 100);
const _poor = ['farmer', 'fisher', 'beggar'];
const _samuraiKids = ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'daimyo'];
int _f(Game g, String tag) => g.l.focus[tag] ?? 0;

List<SceneDef> buildMoreChildScenes() => [
  SceneDef('c_river', 5, 10, (g) => 1.5, (g) => true, (g, next) {
    g.ask('川遊び', '夏の川で遊んでいると、年下の子が深みに足を取られた。', [
      Choice.h('飛び込んで助ける', '助けられるかもしれない。川は子どもにも容赦しない', () {
        if (g.rng.chance(.03)) {
          g.die('川で溺れた子を助けようとして、流された', 'sai');
          return '水が、思ったよりずっと冷たかった。';
        }
        g.l.net += 3;
        g.l.fame += 2;
        g.mark('幼い日、川で溺れかけた子を助けた');
        return '必死で手をつかみ、岸まで引き上げた。';
      }),
      Choice.h('大人を呼びに走る', '確かだ。間に合えば', () {
        g.l.net += 1;
        return '大人が飛び込み、子は助かった。';
      }),
    ], after: next);
  }),

  SceneDef('c_sibling', 6, 13, (g) => 1.5, (g) => g.l.order >= 2, (g, next) {
    g.ask('兄弟げんか', '兄が、あなたの大事にしていた木彫りの馬を壊した。わざとではないと言うが…', [
      Choice.h('殴りかかる', '気は晴れる。兄は手加減しない', () {
        g.l.bu = _c(g.l.bu + 1);
        g.l.hp -= 5;
        return '派手に取っ組み合い、二人とも母に叱られた。';
      }),
      Choice.h('許してやる', '兄は恩に着る。悔しさは残る', () {
        g.setFlag('kind_sibling');
        g.l.net += 2;
        return '兄はばつが悪そうに、新しい馬を彫ってくれた。';
      }),
    ], after: next);
  }),

  SceneDef(
    'c_mother_sick',
    6,
    14,
    (g) => 1.2,
    (g) => !g.hasFlag('fatherdead'),
    (g, next) {
      g.ask('母の病', '母が床に伏した。父は野良仕事で手が離せない。', [
        Choice.h('付きっきりで看病する', '母は心強い。遊ぶ暇はなくなる', () {
          g.j(-2);
          g.l.mi = _c(g.l.mi + 2);
          g.setFlag('nursed_mother');
          return '母の額の手ぬぐいを、何度も替えた。母は持ち直した。';
        }),
        Choice.h('山へ薬草を採りに行く', '薬草が効くかもしれない。山は子ども一人には危ない', () {
          if (g.rng.chance(.4)) {
            g.l.chi = _c(g.l.chi + 2);
            return '見つけた薬草を煎じると、母の熱が下がった。';
          }
          g.l.hp -= 6;
          return '山で道に迷い、夜になってようやく帰り着いた。';
        }),
      ], after: next);
    },
  ),

  SceneDef('c_bear', 8, 14, (g) => 1, (g) => _poor.contains(g.l.cls.id), (
    g,
    next,
  ) {
    g.ask('山の熊', '薪拾いの山道で、黒い大きな影が動いた。熊だ。', [
      Choice.h('じっと動かずにいる', '熊が去るのを待つ。待てるかどうか', () {
        if (g.rng.chance(.7)) {
          g.l.un = _c(g.l.un + 1);
          return '熊は鼻を鳴らし、のそのそと去っていった。';
        }
        g.l.hp -= 20;
        return '熊が近づいてきた。夢中で逃げ、背中を引っかかれた。';
      }),
      Choice.h('大声を上げて追い払う', '熊が驚くかもしれない。怒るかもしれない', () {
        if (g.rng.chance(.5)) {
          g.l.bu = _c(g.l.bu + 2);
          g.mark('幼い日、山で熊を追い払った');
          return '熊は驚いて藪に逃げ込んだ。村じゅうの話の種になった。';
        }
        g.l.hp -= 25;
        return '熊が向かってきた。命からがら逃げ帰った。';
      }),
    ], after: next);
  }),

  SceneDef('c_nengu', 7, 14, (g) => 1.5, (g) => _poor.contains(g.l.cls.id), (
    g,
    next,
  ) {
    g.ask('年貢の取り立て', '代官の手下が、父の前で米俵を数えている。足りない、と怒鳴る声がする。', [
      Choice.h('父の前に立ちはだかる', '子どもの勇気が、何かを変えるかもしれない', () {
        if (g.rng.chance(.4)) {
          g.l.fame += 2;
          return '手下は鼻で笑ったが、それ以上は取らずに帰っていった。';
        }
        g.l.hp -= 8;
        return '突き飛ばされた。父が、黙って頭を下げていた。';
      }),
      Choice.h('物陰で見ている', '何もできない。忘れられない光景になる', () {
        g.setFlag('saw_nengu');
        g.mark('幼い日、年貢を取り立てられる父の背中を見た');
        return '父の背中が、いつもより小さく見えた。';
      }),
    ], after: next);
  }),

  SceneDef('c_puppy', 5, 10, (g) => 1.2, (g) => true, (g, next) {
    g.ask('子犬', '道端で、痩せた子犬が鳴いていた。', [
      Choice.h('連れて帰る', '友ができる。餌をやる余裕はあるか', () {
        g.j(8);
        g.setFlag('dog');
        g.meet('犬', 'シロ', 70);
        return '子犬にシロと名付けた。どこへ行くにもついてきた。';
      }),
      Choice.h('そっと餌をやって去る', '情けはかける。家には連れて帰れない', () {
        g.j(2);
        return '握り飯を半分やった。子犬は尻尾を振った。';
      }),
    ], after: next);
  }),

  SceneDef(
    'c_bushi_kid',
    7,
    14,
    (g) => 1.2,
    (g) => _poor.contains(g.l.cls.id) || g.l.cls.id == 'merchant',
    (g, next) {
      g.ask('侍の子', '道で、身なりのいい侍の子とぶつかった。「無礼者」と、木刀を向けてくる。', [
        Choice.h('受けて立つ', '勝てば名が上がる。負ければ痛い。勝っても後が怖い', () {
          if (g.rng.chance(.4 + g.l.bu / 200)) {
            g.l.bu = _c(g.l.bu + 2);
            g.setFlag('beat_bushi_kid');
            g.mark('幼い日、侍の子を打ち負かした');
            return '木刀を取り上げてやった。侍の子は泣きながら帰っていった。';
          }
          g.l.hp -= 10;
          return 'こっぴどく打ち据えられた。';
        }),
        Choice.h('頭を下げる', '面倒は避けられる。悔しさが残る', () {
          g.j(-3);
          return '土下座した。いつか見返してやる、と思った。';
        }),
        Choice.h('名を尋ねて友になろうとする', '身分違いの友ができるかもしれない', () {
          if (g.rng.chance(.4 + g.l.mi / 200)) {
            g.meet('身分違いの友', '侍の子・${g.rng.pick(kGivenM)}', 45);
            return '侍の子は目を丸くして、それから笑った。';
          }
          return '「下郎と口をきく気はない」と言われた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'c_sword_lesson',
    7,
    14,
    (g) => 1.5 + _f(g, 'martial') * .3,
    (g) => _samuraiKids.contains(g.l.cls.id) && !g.l.female,
    (g, next) {
      g.ask('剣の稽古', '家に出入りする剣術指南が、筋を見てやると言う。稽古は朝が早く、厳しい。', [
        Choice.h('朝稽古に通う', '腕は上がる。手の皮がむける', () {
          g.l.bu = _c(g.l.bu + 4);
          g.l.hp -= 4;
          g.setFlag('sword_lessons');
          return '冬の朝も休まず通った。指南役が、一度だけうなずいた。';
        }),
        Choice.h('書物を読む方が好きだ', '頭は鍛えられる。武家の子としては頼りない', () {
          g.l.chi = _c(g.l.chi + 3);
          return '縁側で、兵法の書を読みふけった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('c_ninja_training', 6, 14, (g) => 4, (g) => g.l.cls.id == 'ninja', (
    g,
    next,
  ) {
    g.ask('里の修行', '忍びの里の修行は、子どもにも容赦がない。今日は、夜の山を一人で越えろという。', [
      Choice.h('一人で山を越える', '一人前に近づく。夜の山は何が出るか分からない', () {
        if (g.rng.chance(.03)) {
          g.die('忍びの修行で夜の山に入り、戻らなかった', 'yukue');
          return '夜明けになっても、帰ってこなかった。';
        }
        g.l.bu = _c(g.l.bu + 2);
        g.l.chi = _c(g.l.chi + 2);
        return '夜明け前に、山の向こうの祠にたどり着いた。';
      }),
      Choice.h('仲間と組んで越える', '心強い。掟には背く', () {
        g.l.net += 3;
        return '仲間と励まし合って越えた。頭目には叱られた。';
      }),
    ], after: next);
  }),

  SceneDef(
    'c_merchant_shop',
    8,
    14,
    (g) => 2,
    (g) => g.l.cls.id == 'merchant',
    (g, next) {
      g.ask('店番', '親の店で店番をしていると、客が釣り銭を多く渡してきた。気づいていないようだ。', [
        Choice.h('正直に返す', '信用を得る。得はしない', () {
          g.l.mi = _c(g.l.mi + 2);
          g.setFlag('honest_child');
          return '客は驚き、その日からこの店の常連になった。';
        }),
        Choice.h('黙ってもらっておく', '小遣いになる。後ろめたい', () {
          g.l.gold += 1;
          g.j(-2);
          return '銭を懐に入れた。夜、なかなか寝つけなかった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('c_girl_hina', 5, 12, (g) => 1.5, (g) => g.l.female, (g, next) {
    g.ask('手習い', '母が、糸と針を持ってきた。「女は縫い物ができなければ」。兄は、外で木刀を振っている。', [
      Choice.h('縫い物を覚える', '母は喜ぶ。手先が器用になる', () {
        g.l.sei = _c(g.l.sei + 2);
        return '初めて縫った巾着を、母が大事にしまった。';
      }),
      Choice.h('兄に混ぜてもらう', '体は鍛わる。母は眉をひそめる', () {
        g.l.bu = _c(g.l.bu + 2);
        g.setFlag('tomboy');
        return '木刀を握ると、兄が面白がって相手をしてくれた。';
      }),
      Choice.h('こっそり字を習う', '知恵がつく。女に学問は要らぬと言われる', () {
        g.l.chi = _c(g.l.chi + 2);
        return '寺の和尚が、こっそり手ほどきしてくれた。';
      }),
    ], after: next);
  }),

  SceneDef('c_fox', 6, 12, (g) => 1, (g) => true, (g, next) {
    g.ask('狐火', '夜の田んぼに、青白い火がいくつも揺れている。狐火だと、婆さまが言った。', [
      Choice.h('近くまで見に行く', '怖いもの見たさ。何が待っているか', () {
        if (g.rng.chance(.5)) {
          g.l.un = _c(g.l.un + 2);
          return '近づくと、火はすっと消えた。あれは何だったのか、今も分からない。';
        }
        g.l.hp -= 5;
        return '田の畦で足を滑らせ、泥だらけで帰った。';
      }),
      Choice.h('布団をかぶって寝る', '何も起きない', () => '朝になると、田んぼには何も残っていなかった。'),
    ], after: next);
  }),

  SceneDef(
    'c_heir_duty',
    10,
    14,
    (g) => 2,
    (g) => _samuraiKids.contains(g.l.cls.id) && g.l.order == 1 && !g.l.female,
    (g, next) {
      g.ask('跡取りの務め', '父が、家臣たちの前にあなたを座らせた。「この子が跡取りだ」。皆の目が集まる。', [
        Choice.h('堂々と挨拶する', '家臣たちが一目置く。重圧も背負う', () {
          g.l.mi = _c(g.l.mi + 2);
          g.l.fame += 2;
          g.mark('幼くして、跡取りとして家臣の前で挨拶した');
          return '声は震えたが、最後まで言い切った。';
        }),
        Choice.h('父の陰に隠れる', '子どもらしい。家臣たちは心配する', () {
          g.j(-1);
          return '父は苦笑して、あなたの頭をなでた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'c_beggar_kindness',
    5,
    12,
    (g) => 2,
    (g) => g.l.cls.id == 'beggar',
    (g, next) {
      g.ask('施し', '寺の門前で、旅の尼が握り飯を分けてくれた。「何か一つ、望みを言ってごらん」', [
        Choice.h('字を教えてほしいと頼む', '知恵は誰にも奪えない', () {
          g.l.chi = _c(g.l.chi + 3);
          g.setFlag('nun_teacher');
          return '尼は、地面に枝で字を書いて教えてくれた。';
        }),
        Choice.h('腹いっぱい食べたいと言う', '今日は救われる', () {
          g.l.hp = g.l.hp + 15 > g.l.maxhp ? g.l.maxhp : g.l.hp + 15;
          g.j(6);
          return '尼は笑って、もう一つ握り飯をくれた。';
        }),
      ], after: next);
    },
  ),
];
