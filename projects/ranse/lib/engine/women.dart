import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 女性の人生に固有の岐路（2026-11-23）。生まれの半分は女性で、全人生の約2割が「女の道」に進むのに、
/// 女性だけの岐路が数えるほどしかなかったため。id は `w_`。

int _c(int v) => clampInt(v, 0, 100);
bool _oku(Game g) => g.l.female && g.l.rank >= 1 && g.l.rank < 8 && g.active;

List<SceneDef> buildWomenScenes() => [
  SceneDef('w_oku_lesson', 15, 30, (g) => 2, (g) => _oku(g) && g.l.rank <= 3, (
    g,
    next,
  ) {
    g.ask('奥の作法', '奥に上がって間もない。年かさの女中が、茶・香・書のうち、ひとつは身につけておけと言う。', [
      Choice.h('茶の湯を習う', '客あしらいが上手くなる。上の方々の目に留まりやすい', () {
        g.l.mi = _c(g.l.mi + 3);
        g.l.fav = _c(g.l.fav + 3);
        return '湯の沸く音を聞き分けられるようになった。';
      }),
      Choice.h('書を習う', '文が書ければ、使いを任される', () {
        g.l.chi = _c(g.l.chi + 3);
        g.setFlag('oku_letters');
        return '奥方さまの文の代筆を任されるようになった。';
      }),
      Choice.h('香を聞く', '雅な遊びだ。役に立つかは分からない', () {
        g.j(6);
        return '香の名を、十ほど言い当てられるようになった。';
      }),
    ], after: next);
  }),

  SceneDef(
    'w_lord_eye',
    16,
    32,
    (g) => 1.2 + (g.l.mi >= 60 ? 2 : 0),
    (g) => _oku(g) && !g.l.married && g.l.rank <= 5,
    (g, next) {
      final l = g.l;
      g.ask(
        '殿の目',
        '${houseName(g, l.lord)}家の殿が、廊下ですれ違ったあなたに目を留めた。側に上がれ、という内々の話が来た。',
        [
          Choice.h('お側に上がる', '身分は上がる。正室や他の側室の目は厳しい', () {
            l.rank = l.rank + 2 > 7 ? 7 : l.rank + 2;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.fav = _c(l.fav + 15);
            g.j(-5);
            g.setFlag('sokushitsu');
            g.mark('${houseName(g, l.lord)}家の殿の側室に上がった');
            return '殿の側室となった。奥の空気が、少し冷たくなった。';
          }),
          Choice.h('丁重にお断りする', '心は自分のものだ。殿の機嫌を損ねるかもしれない', () {
            l.fav = _c(l.fav - 10);
            g.j(3);
            return '丁重に辞退した。殿は何も言わなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  SceneDef(
    'w_childbirth',
    17,
    40,
    (g) => 2,
    (g) => g.l.female && g.l.married && g.l.kids <= 2,
    (g, next) {
      g.ask('お産の床', '腹の子が大きくなってきた。お産は、女の戦場だと言われる。', [
        Choice.h('腕のいい産婆を呼ぶ（銭8貫）', '銭はかかる。母子ともに助かりやすい', () {
          if (g.l.gold < 8) return '銭が足りず、村の産婆に頼んだ。';
          g.l.gold -= 8;
          g.setFlag('good_midwife');
          g.l.hp = g.l.hp + 20 > g.l.maxhp ? g.l.maxhp : g.l.hp + 20;
          return '腕のいい産婆が来てくれることになった。';
        }),
        Choice.h('実家に帰って産む', '母がいれば心強い。道中は体にこたえる', () {
          g.l.hp -= 5;
          g.j(6);
          return '実家の母が、温かい粥を作って待っていた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'w_home_letter',
    18,
    60,
    (g) => 1.2,
    (g) => g.l.female && g.l.married && g.active,
    (g, next) {
      g.ask('実家からの文', '実家から文が届いた。凶作で、父母が難儀しているという。', [
        Choice.h('こっそり銭を送る（銭10貫）', '父母は助かる。嫁ぎ先に知れれば角が立つ', () {
          if (g.l.gold < 10) return '送れるほどの銭がなかった。';
          g.l.gold -= 10;
          g.j(5);
          g.mark('凶作に苦しむ実家に、ひそかに銭を送った');
          return '銭を包み、信の置ける者に託した。';
        }),
        Choice.h('夫に相談する', '筋は通る。夫の考えしだいだ', () {
          final sp = g.l.people['伴侶'];
          if (sp != null && sp.bond >= 50) {
            sp.bond = _c(sp.bond + 5);
            return '${sp.name}は黙ってうなずき、米を送ってくれた。';
          }
          g.j(-5);
          return '「嫁いだ身で、実家のことを言うな」と言われた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'w_remarry',
    20,
    50,
    (g) => 3,
    (g) =>
        g.l.female &&
        !g.l.married &&
        g.l.people.containsKey('伴侶') &&
        !g.hasFlag('priesthood') &&
        g.active,
    (g, next) {
      final old = g.l.people['伴侶']!;
      final name = '${g.rng.pick(kSurnames)}家の${g.rng.pick(kGivenM)}';
      g.ask('後家への縁談', '${old.name}を亡くして時が経った。$nameとの縁談が持ち込まれた。', [
        Choice.h('再び嫁ぐ', '新しい暮らしが始まる。亡き人の面影は胸にしまう', () {
          g.l.married = true;
          g.meet('伴侶', name, 40);
          g.j(6);
          g.mark('$nameに再び嫁いだ');
          return '$nameのもとへ、再び嫁いだ。';
        }),
        Choice.h('亡き夫の菩提を弔って生きる', '静かに暮らせる。ひとりの身は心細い', () {
          old.bond = _c(old.bond + 10);
          g.setFlag('faithful_widow');
          g.mark('再縁を断り、亡き${old.name}の菩提を弔って生きた');
          return '縁談は断った。仏壇の前で、${old.name}に手を合わせた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'w_daughter',
    34,
    60,
    (g) => 2,
    (g) =>
        g.l.female &&
        marriageableDaughter(g) != null &&
        g.l.rank >= 1 &&
        g.active,
    (g, next) {
      // 裳着・祝い（family.dart）で名のある娘がその歳ならその娘、でなければ家にいる年頃の娘。
      final kid = marriageableDaughter(g)!;
      final hime = kid.name;
      g.ask('娘の嫁ぎ先', '娘の$himeに、二つの縁談が来ている。家のためになる縁と、娘が慕う若侍との縁だ。', [
        Choice.h('家のためになる縁を選ぶ', '家は強くなる。娘は泣くかもしれない', () {
          g.l.fav = _c(g.l.fav + 8);
          g.j(-4);
          g.meet('娘', hime, 45);
          g.l.kidLeft(kid, KidFate.wed, g.year);
          g.mark('娘の$himeを、家のための縁組に出した');
          return '$himeは、黙って嫁いでいった。';
        }),
        Choice.h('娘の想いを通してやる', '娘は喜ぶ。家中には不満が残る', () {
          g.l.fav = _c(g.l.fav - 5);
          g.j(8);
          g.meet('娘', hime, 80);
          g.l.kidLeft(kid, KidFate.wed, g.year);
          g.mark('娘の$himeを、慕う相手に嫁がせた');
          return '$himeは、泣きながら笑って嫁いでいった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('w_oku_fire', 16, 60, (g) => 1, (g) => _oku(g), (g, next) {
    g.ask('奥御殿の火事', '夜更け、奥御殿から火が出た。幼い姫君の寝所は、炎の向こうだ。', [
      Choice.h('姫君を助けに飛び込む', '姫君を救えば、生涯の誉れ。火は容赦しない', () {
        if (g.rng.chance(.12)) {
          g.die('奥御殿の火事で、姫君を救おうとして炎に巻かれた', 'sai');
          return '姫君を窓から外へ渡したところで、梁が落ちてきた。';
        }
        g.l.fav = _c(g.l.fav + 25);
        g.l.merit += 20;
        g.l.hp -= 20;
        g.mark('奥御殿の火事で、炎の中から姫君を救い出した');
        return '姫君を抱いて、炎の中から転がり出た。';
      }),
      Choice.h('人を呼びに走る', '自分の命は守れる。間に合うかは分からない', () {
        return '人を呼んで戻ったときには、火は消し止められていた。';
      }),
    ], after: next);
  }),

  SceneDef(
    'w_naginata',
    15,
    45,
    (g) => 1.5,
    (g) => g.l.female && (g.has('onna') || g.l.rank >= 3) && g.active,
    (g, next) {
      g.ask('薙刀の稽古', '武家の女は、いざというとき家を守らねばならない。薙刀の稽古が始まった。', [
        Choice.h('本気で打ち込む', '腕が上がる。手の豆は絶えない', () {
          g.l.bu = _c(g.l.bu + 4);
          g.setFlag('naginata');
          return '薙刀を振る音が、道場に響いた。';
        }),
        Choice.h('形だけ習う', '体は楽だ', () => '型だけは覚えた。'),
        if (g.l.bu >= 55)
          Choice.h('師範役の老女に、立ち合いを願い出る', '筋がよければ、奥の手まで教えてもらえる。打たれれば痣になる', () {
            g.setFlag('naginata');
            if (g.might(.35)) {
              g.l.bu = _c(g.l.bu + 5);
              g.l.fame += 2;
              return '三本のうち一本、老女の脛を払った。老女は目を細め、「久しぶりに、教え甲斐のある娘が来た」と言って、その日から居残りの稽古が始まった。';
            }
            g.l.bu = _c(g.l.bu + 3);
            g.l.hp -= 3;
            return '三本とも、面を取られた。老女は「負け方がよい」とだけ言った。';
          }, via: '武'),
      ], after: next);
    },
  ),

  SceneDef(
    'w_weave',
    16,
    60,
    (g) => 1.5,
    (g) => g.l.female && g.l.rank == 0 && !g.hasFlag('priesthood') && g.active,
    (g, next) {
      g.ask('機織り', '村の女たちと、夜なべに機を織っている。町の商人が、上物なら高く買うと言う。', [
        Choice.h('上物の小袖を織る', '高く売れる。目と肩を痛める', () {
          g.l.gold += 10;
          g.l.hp -= 8;
          g.setFlag('weaver');
          return '織り上がった小袖は、町で良い値がついた。';
        }),
        Choice.h('皆で分けて織る', '稼ぎは少ない。村の女たちとの縁は深まる', () {
          g.l.gold += 3;
          g.l.net += 3;
          return '囲炉裏端で、皆で笑いながら織った。';
        }),
      ], after: next);
    },
  ),

  SceneDef('w_spy', 20, 60, (g) => 1.2, (g) => _oku(g) && g.l.rank >= 3, (
    g,
    next,
  ) {
    g.ask('新しい女中', '奥に新しく入った女中の手が、妙に硬い。剣だこではないか。', [
      Choice.h('問い詰める', '間者なら手柄。思い違いなら恨まれる', () {
        if (g.rng.chance(.5 + g.l.chi / 300)) {
          g.l.fav = _c(g.l.fav + 15);
          g.l.merit += 15;
          g.mark('奥に入り込んだ敵の間者を見抜いた');
          return '女中は敵方の間者だった。奥方さまから、お褒めの言葉を賜った。';
        }
        g.l.fav = _c(g.l.fav - 5);
        return 'ただの百姓の娘だった。気まずい思いをした。';
      }),
      Choice.h('そっと様子を見る', '何も起きないかもしれない。起きるかもしれない', () {
        return 'しばらく目を配っていたが、女中はいつの間にか姿を消していた。';
      }),
    ], after: next);
  }),
];
