import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 子と家族の岐路（2026-11-23）。親として、子の元服・裳着・初陣・志・縁談・病・反抗・出奔・
/// 跡目・養子・家督・孫・人質と、連れ合いとの諍いと病を描く。id・新しい旗は `fa_` で始める。
///
/// 子は `Life.kids`（数）と `Life.kidYears`（生まれた年）で持つ。場面は子の歳で出し分ける
/// （年の分からない子＝古い保存がいれば、今までどおり親の歳の窓だけで見る）。名のある子は縁のある人として残す:
/// - 「嫡男」（武家の跡継ぎ。元服・初陣・出奔・跡目で付く。城主・大名の岐路と同じ役割）
/// - 「娘」（裳着・祝い）／「子」（百姓・町人の跡継ぎ）／「養子」
/// - 「人質に出した子」「勘当した子」「出奔した子」「寺に入った子」「孫」
/// 子を亡くすのは文と `l.kids` で表す（旗 `fa_lost_child`。家族の悲しみの岐路が続く）。
/// 親が死ぬのは、初陣に付き添う・人質の子を救いに行く、の二つだけで稀。
/// 城主・大名の跡目・人質・娘の縁組は `lords.dart` に、村の子の熱は `village.dart` に、
/// 女性の娘の嫁ぎ先は `women.dart` にあるので、ここでは身分を分けて重ならないようにしている。

int _c(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

bool _monk(Game g) => g.hasFlag('priesthood');
bool _outlaw(Game g) => g.hasFlag('way_outlaw') && g.l.rank == 0;
bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);

/// 主家に仕える武家（城主・家老まで。大名その人は除く）。
bool _buke(Game g) =>
    g.l.rank >= 1 && g.l.rank <= 7 && g.active && !_monk(g) && _lordAlive(g);

/// 武家の親（男か、武家に嫁いだ女）。
bool _bukeParent(Game g) => _buke(g) && (!g.l.female || g.l.married);

/// 身分のない暮らし（仏門・野の道を除く）。
bool _commoner(Game g) => g.l.rank == 0 && g.active && !_monk(g) && !_outlaw(g);

bool _merchant(Game g) =>
    _commoner(g) && (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

bool _craft(Game g) => _commoner(g) && g.hasFlag('craftsman');

bool _villager(Game g) =>
    _commoner(g) &&
    !_merchant(g) &&
    !_craft(g) &&
    const ['farmer', 'fisher', 'beggar'].contains(g.l.cls.id);

/// 家を持って暮らす（仏門・野の道でない）。
bool _home(Game g) => !_monk(g) && !_outlaw(g);

String _house(Game g) => houseName(g, g.l.lord);

/// 名のある子（跡継ぎ・娘・養子の順）。
Person? _child(Game g) =>
    g.l.people['嫡男'] ?? g.l.people['子'] ?? g.l.people['養子'] ?? g.l.people['娘'];

void _bond(Person? p, int v) {
  if (p != null) p.bond = _c(p.bond + v);
}

/// 歳が [lo]〜[hi] の子がいるか（年の分からない子がいれば真）。
bool _kidAged(Game g, int lo, [int hi = 999]) => g.l.hasKidAged(g.year, lo, hi);

/// いちばん上の子が [min] 歳以上か（年の分からない子がいれば真）。
bool _eldestAtLeast(Game g, int min) {
  final a = g.l.eldestKidAge(g.year);
  return a == null ? g.l.kids > 0 : a >= min;
}

/// 子を亡くす。役割があれば人物から外し、悲しみの旗を立てる。歳が [lo]〜[hi] の子を外す。
void _loseChild(Game g, String? role, String text, [int lo = 0, int hi = 999]) {
  g.l.loseKid(g.year, lo, hi);
  if (role != null) g.l.people.remove(role);
  g.setFlag('fa_lost_child');
  g.j(-25);
  g.mark(text);
}

/// 跡継ぎを置く役割（武家は嫡男、ほかは子）。
String _heirRole(Game g) => g.l.rank >= 1 ? '嫡男' : '子';

/// 人質に出した年（旗 `fa_hostage_at:<年>`）。
int? _hostageYear(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('fa_hostage_at:')) return int.tryParse(f.substring(14));
  }
  return null;
}

List<SceneDef> buildFamilyScenes() => [
  // ------------------------------------------------------------------
  // 嫡男の元服（武家）。烏帽子親を誰に頼むか。
  SceneDef(
    'fa_genpuku',
    30,
    60,
    (g) => 3,
    (g) =>
        _bukeParent(g) &&
        g.l.kids >= 1 &&
        _kidAged(g, 11, 17) &&
        !g.l.people.containsKey('嫡男'),
    (g, next) {
      final l = g.l;
      final young = l.rank >= 5 ? g.rng.pick(kHeirNames) : null;
      final n = g.rng.pick(kGivenM);
      final friend = l.people['幼なじみ'] ?? l.people['朋輩'];
      final who = l.female ? '夫と、' : '';
      g.ask(
        '嫡男の元服',
        '${young == null ? '嫡男' : '幼名を$youngという嫡男'}が、元服の歳を迎えた。名を$nと改める。$who烏帽子親を誰に頼むか、決めねばならない。',
        [
          Choice.h('主君に烏帽子親を願い出る', '主家との結びつきは深まる。子は殿の名を背負う', () {
            if (l.fav < 20 && g.rng.chance(.3)) {
              g.meet('嫡男', n, 55);
              return '願いは取り次ぎで止まり、家老が代わりに冠を載せた。';
            }
            l.fav = _c(l.fav + 6);
            g.meet('嫡男', n, 60);
            g.setFlag('fa_eboshi_lord');
            g.mark('嫡男の$nの元服に、${_house(g)}の殿を烏帽子親に仰いだ');
            return '殿は$nの頭に烏帽子を載せ、名の一字を与えた。';
          }),
          if (friend != null)
            Choice.h('旧友の${friend.name}に頼む', '古い縁が子にも続く。家中では小さく見られる', () {
              _bond(friend, 8);
              g.meet('嫡男', n, 70);
              g.setFlag('fa_eboshi_friend');
              g.mark('嫡男の$nの烏帽子親を、旧友の${friend.name}に頼んだ');
              return '${friend.name}は照れくさそうに、$nの頭に烏帽子を載せた。';
            }),
          Choice.h('自ら烏帽子を載せる', '借りは作らない。祝いはささやかになる', () {
            g.j(4);
            g.meet('嫡男', n, 75);
            g.setFlag('fa_eboshi_self');
            return '家の者だけで祝った。$nは、少し大人びた顔をした。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------
  // 娘の裳着（武家）／一人前の祝い（町や村）。
  SceneDef(
    'fa_mogi',
    28,
    60,
    (g) => 2.5,
    (g) =>
        _home(g) &&
        g.active &&
        g.l.kids >= 1 &&
        _kidAged(g, 11, 17) &&
        !g.l.people.containsKey('娘'),
    (g, next) {
      final l = g.l;
      final buke = l.rank >= 1;
      final n = g.rng.pick(l.rank >= 5 ? kHimeNames : kGivenF);
      final sp = l.married ? l.people['伴侶'] : null;
      g.ask(
        buke ? '娘の裳着' : '娘の祝い',
        buke
            ? '娘の$nが、裳着の歳を迎えた。髪を上げ、裳を着ければ、もう子どもではない。'
            : '娘の$nが、一人前の祝いの歳を迎えた。近所の女たちが、髪を結ってやろうと集まってきた。',
        [
          Choice.h('晴れ着を誂える', '娘の晴れの日になる。蔵は軽くなる', () {
            _pay(g, 8);
            g.j(6);
            g.meet('娘', n, 75);
            g.mark('娘の$nの${buke ? '裳着' : '祝い'}に、晴れ着を誂えた');
            return '晴れ着の$nは、照れながらくるりと回ってみせた。';
          }),
          Choice.h(
            l.female ? '自分が嫁いだ日の櫛を渡す' : '亡き母の形見の櫛を渡す',
            '銭はかからない。思いは伝わる',
            () {
              g.j(4);
              g.meet('娘', n, 82);
              g.setFlag('fa_comb');
              g.mark('娘の$nに、家に伝わる櫛を渡した');
              return '$nは櫛を胸に抱いて、しばらく黙っていた。';
            },
          ),
          if (buke && !l.female)
            Choice.h(
              '務めを優先し、祝いは${sp == null ? '家の者' : sp.name}に任せる',
              '務めは果たせる。娘は寂しがる',
              () {
                l.fav = _c(l.fav + 3);
                g.meet('娘', n, 45);
                return '城から戻ると、祝いはもう終わっていた。$nは何も言わなかった。';
              },
            ),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------
  // 嫡男の初陣を許すか（武家）。
  SceneDef(
    'fa_uijin',
    33,
    64,
    (g) => 4,
    (g) =>
        _buke(g) &&
        g.l.kids >= 1 &&
        _kidAged(g, 13, 20) &&
        g.l.people.containsKey('嫡男'),
    (g, next) {
      final l = g.l;
      final k = l.people['嫡男']!;
      final n = k.name;
      g.ask('子の初陣', '元服を終えた嫡男の$nが、次の戦で初陣を飾りたいと願い出た。', [
        if (g.canFight)
          Choice.h('自分の隊に置き、傍らで戦わせる', '親の目が届く。親子そろって危うい場に立つ', () {
            if (g.rng.chance(.04)) {
              g.die('嫡男の初陣で、子をかばって討死した', 'senshi');
              return '$nに迫った槍の前へ、体が先に出た。';
            }
            if (g.rng.chance(.04)) {
              _loseChild(g, '嫡男', '嫡男の$nを、初陣で亡くした', 13, 20);
              return '乱戦の中で、$nの姿を見失った。見つけたときには、もう冷たかった。';
            }
            _bond(k, 10);
            l.fame += 4;
            g.setFlag('fa_uijin_together');
            g.mark('嫡男の$nの初陣に、自ら付き添った');
            return '$nは震えながらも槍を構え、最後まで退かなかった。';
          }),
        Choice.h('古参の侍に預ける', '戦の作法は身につく。親は戦場で見守れない', () {
          if (g.rng.chance(.06)) {
            _loseChild(g, '嫡男', '嫡男の$nを、初陣で亡くした', 13, 20);
            return '古参の侍が、$nの兜を抱えて戻ってきた。';
          }
          _bond(k, 3);
          l.merit += 3;
          g.mark('嫡男の$nが、初陣を果たした');
          return '$nは手柄こそなかったが、生きて帰った。少し背が伸びて見えた。';
        }),
        Choice.h('まだ早いと止める', '子の命は守れる。子は家中で肩身が狭い', () {
          _bond(k, -10);
          g.setFlag('fa_uijin_kept');
          return '$nは唇を噛んで引き下がった。同じ年頃の者たちは、皆出ていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 家業を継がせるか、別の道を許すか（百姓・漁民・商人・職人）。
  SceneDef(
    'fa_kokorozashi',
    36,
    64,
    (g) => 2.5,
    (g) =>
        (_merchant(g) || _craft(g) || _villager(g)) &&
        g.l.kids >= 1 &&
        _kidAged(g, 13, 22) &&
        !g.l.people.containsKey('子'),
    (g, next) {
      final n = g.rng.pick(kGivenM);
      final String text;
      final String want;
      if (_merchant(g)) {
        text = '店を継ぐはずの子の$nが、寺に入って学問を究めたいと言い出した。帳場に座らせても、上の空だ。';
        want = '寺で学ぶ';
      } else if (_craft(g)) {
        text = '工房を継ぐはずの子の$nが、堺へ出て南蛮渡りの技を学びたいと言い出した。';
        want = '堺で学ぶ';
      } else {
        text = '田を継ぐはずの子の$nが、通りがかった陣触れを聞いて、足軽に出たいと言い出した。';
        want = '足軽に出る';
      }
      final soldier = want == '足軽に出る';
      g.ask('子の志', text, [
        Choice.h('家業を継がせる', '家は守れる。子の胸には火がくすぶる', () {
          g.meet('子', n, 45);
          g.setFlag('fa_kept_home');
          g.mark('別の道を望んだ子の$nに、家業を継がせた');
          return '$nは黙ってうなずいた。その夜、長いこと外で星を見ていた。';
        }),
        Choice.h(
          '望む道へ送り出す',
          soldier ? '子は目を輝かせる。戦に出れば、無事は分からない' : '子は目を輝かせる。家は誰が継ぐ',
          () {
            if (soldier && g.rng.chance(.08)) {
              _loseChild(g, null, '足軽に出た子の$nを、戦で亡くした', 13, 30);
              return 'その年の秋、$nの討死を知らせる者が来た。';
            }
            g.meet('旅立った子', n, 75);
            g.setFlag('fa_let_go');
            g.mark('子の$nを、$wantという望みのままに送り出した');
            return '$nは何度も振り返りながら、村の外れの道を下っていった。';
          },
        ),
        Choice.h('一年だけと約束して試させる', '答えは先に延ばせる。子は戻らないかもしれない', () {
          if (g.rng.chance(.5)) {
            g.meet('子', n, 65);
            g.setFlag('fa_kid_returned');
            return '一年ののち、$nは日に焼けて戻ってきた。「家を継ぎます」と言った。';
          }
          g.meet('旅立った子', n, 60);
          return '一年ののち、文が届いた。もう戻らないと書いてあった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 息子の嫁取り（政略か、子の望みか）。城主・大名と女性の娘の縁組は別の岐路にある。
  SceneDef(
    'fa_yome',
    38,
    68,
    (g) => 2,
    (g) =>
        _home(g) &&
        g.active &&
        g.l.kids >= 1 &&
        _kidAged(g, 15, 28) &&
        g.l.rank <= 4,
    (g, next) {
      final l = g.l;
      final buke = l.rank >= 1;
      final role = l.people.containsKey('嫡男')
          ? '嫡男'
          : (l.people.containsKey('子') ? '子' : _heirRole(g));
      final k = l.people[role];
      final n = k?.name ?? g.rng.pick<String>(kGivenM);
      final good = buke ? '組頭の${g.rng.pick(kSurnames)}家の娘' : '隣村の名主の娘';
      final loved = g.rng.pick(kGivenF);
      g.ask(
        '子の縁談',
        '子の$nに、$goodとの縁談が来た。だが$n自身は、${buke ? '城下の小さな家の' : '村の貧しい家の'}娘、$lovedを嫁にしたいと言う。',
        [
          Choice.h(
            '家の得になる縁を取る',
            buke ? '家の後ろ盾ができる。子の目は曇る' : '田も銭も増える。子の目は曇る',
            () {
              if (buke) {
                l.fav = _c(l.fav + 4);
              } else {
                l.gold += 5;
              }
              l.net += 3;
              g.meet(role, n, _c((k?.bond ?? 55) - 10));
              g.setFlag('fa_bride_match');
              g.mark('子の$nに、家のための嫁を迎えた');
              return '祝言の日、$nは一度も笑わなかった。';
            },
          ),
          Choice.h('子の見初めた娘を迎える', '子は喜ぶ。相手の家は貧しく、周りは眉をひそめる', () {
            g.j(6);
            g.meet(role, n, _c((k?.bond ?? 55) + 12));
            g.setFlag('fa_bride_love');
            g.mark('子の$nに、見初めた娘の$lovedを嫁に迎えた');
            return '$lovedはよく働き、よく笑った。家の中が明るくなった。';
          }),
          Choice.h('両家と話し合い、時を待つ', '角は立たない。話が流れることもある', () {
            if (g.rng.chance(.5)) {
              g.meet(role, n, _c((k?.bond ?? 55) + 6));
              g.setFlag('fa_bride_love');
              return '縁談の相手のほうから話を引いてくれた。$nは$lovedを嫁に迎えた。';
            }
            g.meet(role, n, _c((k?.bond ?? 55) - 4));
            return '話は宙に浮いたまま、季節が過ぎた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------
  // 子が病に伏す（村の暮らしは `village.dart` の「子の熱」）。
  SceneDef(
    'fa_sick',
    22,
    58,
    (g) => 2,
    (g) => g.l.kids >= 1 && _kidAged(g, 0, 12) && !_monk(g) && !_villager(g),
    (g, next) {
      final l = g.l;
      final n = g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF);
      g.ask('子の病', '下の子の$nが高い熱を出し、目を覚まさない。額は火のように熱い。', [
        Choice.h('名医を呼び、薬を求める', '効き目は確か。蔵が軽くなる', () {
          if (l.gold < 12) {
            if (g.rng.chance(.12)) {
              _loseChild(g, null, '幼い我が子の$nを、病で亡くした', 0, 12);
              return '薬代が足りなかった。$nは、明け方に息を引き取った。';
            }
            return '薬代が足りず、半分だけ薬を分けてもらった。$nは何とか持ち直した。';
          }
          _pay(g, 12);
          if (g.rng.chance(.03)) {
            _loseChild(g, null, '幼い我が子の$nを、病で亡くした', 0, 12);
            return '薬も届かなかった。$nは、小さく息を吐いて動かなくなった。';
          }
          g.j(3);
          return '薬が効き、$nの熱は三日で下がった。';
        }),
        Choice.h('寺社に祈祷を頼む', '心は静まる。効くかどうかは神仏しだい', () {
          if (g.rng.chance(.15)) {
            _loseChild(g, null, '幼い我が子の$nを、病で亡くした', 0, 12);
            return '祈りは、届かなかった。';
          }
          return '護摩の煙の中で夜を明かした。朝、$nが水を欲しがった。';
        }),
        Choice.h('寺に預け、仏に仕える身として助けを乞う', '命は助かりやすい。子は家に戻らない', () {
          if (g.rng.chance(.02)) {
            _loseChild(g, null, '寺に預けた幼い我が子の$nを、病で亡くした', 0, 12);
            return '寺からの使いは、うつむいたまま口を開いた。';
          }
          g.meet('寺に入った子', n, 60);
          g.setFlag('fa_kid_temple');
          g.mark('病の子の$nを寺に預け、仏に仕える身とした');
          return '熱の引いた$nは、小さな衣を着せられ、寺の門の内へ消えた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 子を亡くした悲しみ（この岐路で、病で、熱で、戦で）。
  SceneDef(
    'fa_grief',
    20,
    84,
    (g) => 6,
    (g) => g.hasFlag('fa_lost_child') && !_monk(g),
    (g, next) {
      final l = g.l;
      final sp = l.married ? l.people['伴侶'] : null;
      g.ask('子を亡くして', '子を亡くしてから、家の中の音が少なくなった。小さな草履が、まだ戸口に揃えてある。', [
        Choice.h('寺に供養を頼み、月ごとに参る', '悲しみは消えない。手を合わせる場ができる', () {
          _pay(g, 3);
          g.j(6);
          g.setFlag('fa_grief_temple');
          g.mark('亡くした子の供養を寺に頼み、月ごとに墓に参った');
          return '小さな墓に、野の花を供えた。';
        }),
        Choice.h(l.rank >= 1 ? '務めに打ち込む' : '仕事に打ち込む', '気はまぎれる。胸の穴は塞がらない', () {
          if (l.rank >= 1) {
            l.merit += 3;
          } else {
            l.gold += 4;
          }
          g.j(-3);
          g.setFlag('fa_grief_work');
          return '朝から晩まで働いた。夜になると、また思い出した。';
        }),
        if (sp != null)
          Choice.h('${sp.name}と、子の思い出を語り合う', '夫婦の絆は深まる。涙は止まらない', () {
            _bond(sp, 12);
            g.j(4);
            g.mark('子を亡くした悲しみを、連れ合いの${sp.name}と分け合った');
            return '二人で、子の好きだった歌を口ずさんだ。';
          }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 子が身を持ち崩す（町や村）。
  SceneDef(
    'fa_hoto',
    36,
    68,
    (g) => 2,
    (g) => _commoner(g) && g.l.kids >= 1 && _kidAged(g, 13, 22),
    (g, next) {
      final l = g.l;
      final k = l.people['子'];
      final n = k?.name ?? g.rng.pick<String>(kGivenM);
      g.ask('子の放蕩', '子の$nが、悪い仲間と賭場に入り浸り、家の銭を持ち出すようになった。', [
        Choice.h('賭場に乗り込んで連れ戻す', '子は目を覚ますかもしれない。荒くれ者が相手だ', () {
          if (g.rng.chance(.25)) {
            l.hp -= 15;
            g.meet('子', n, _c((k?.bond ?? 55) - 5));
            return '荒くれ者に叩き出され、額を割った。$nは、それを物陰から見ていた。';
          }
          g.meet('子', n, _c((k?.bond ?? 55) + 8));
          g.setFlag('fa_hoto_back');
          g.mark('賭場に入り浸る子の$nを、乗り込んで連れ戻した');
          return '襟首をつかんで連れ帰った。$nは、道中ずっと泣いていた。';
        }),
        Choice.h('勘当する', '家は守れる。子は帰る場所をなくす', () {
          l.people.remove('子');
          g.meet('勘当した子', n, 20);
          g.setFlag('fa_disowned');
          g.j(-8);
          g.mark('身を持ち崩した子の$nを勘当した');
          return '戸口に立つ$nに、二度と敷居をまたぐなと告げた。';
        }),
        Choice.h('借りを肩代わりし、黙って待つ', '子は救われる。蔵はまた空になるかもしれない', () {
          _pay(g, 10);
          if (g.rng.chance(.6)) {
            g.meet('子', n, _c((k?.bond ?? 55) + 12));
            g.setFlag('fa_hoto_reformed');
            return 'ある朝、$nが黙って仕事に出ていた。賭場には、それきり行かなくなった。';
          }
          g.meet('子', n, _c((k?.bond ?? 55) - 5));
          return '半年ののち、$nはまた賭場にいた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 嫡男の出奔（武家）。
  SceneDef(
    'fa_shuppon',
    40,
    66,
    (g) => 2,
    (g) =>
        _buke(g) &&
        g.l.kids >= 1 &&
        _eldestAtLeast(g, 16) &&
        g.l.people.containsKey('嫡男'),
    (g, next) {
      final l = g.l;
      final k = l.people['嫡男']!;
      final n = k.name;
      g.ask('嫡男の出奔', '嫡男の$nが、家中の者と諍いを起こし、置き文を残して出奔した。他家に仕えるつもりらしい。', [
        Choice.h('追っ手を出して連れ戻す', '家の恥は表に出ない。子は縛られて戻る', () {
          _bond(k, -15);
          l.fav = _c(l.fav + 2);
          g.mark('出奔した嫡男の$nを、追っ手を出して連れ戻した');
          return '国境の宿で$nを捕らえた。縄を解いても、目を合わせなかった。';
        }),
        Choice.h('主君に詫び、嫡男を廃する', '家中の筋は通る。跡継ぎを失う', () {
          l.people.remove('嫡男');
          g.meet('出奔した子', n, 25);
          l.fav = _c(l.fav + 4);
          g.setFlag('fa_shuppon_cut');
          g.j(-8);
          g.mark('出奔した嫡男の$nを廃した');
          return '${_house(g)}の殿の前で、額を床にすりつけた。$nの名は、家の系図から消した。';
        }),
        Choice.h('黙って見送り、行く先の家に文を送る', '子の道は開けるかもしれない。主家の目は冷たくなる', () {
          l.fav = _c(l.fav - 6);
          _bond(k, 10);
          g.setFlag('fa_shuppon_let');
          g.mark('出奔した嫡男の$nを、黙って見送った');
          return '「よしなに」とだけ書いた文を、$nの行く先の家に送った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 兄弟の跡目争い（城主・大名の世継ぎは `lords.dart`）。
  SceneDef(
    'fa_atome',
    45,
    72,
    (g) => 2.5,
    (g) =>
        _home(g) &&
        g.active &&
        g.l.kids >= 2 &&
        g.l.kidsAtLeast(g.year, 14) >= 2 &&
        g.l.rank <= 4,
    (g, next) {
      final l = g.l;
      final role = _heirRole(g);
      final elder = l.people[role]?.name ?? g.rng.pick<String>(kGivenM);
      final younger = g.rng.pick(kGivenM.where((x) => x != elder).toList());
      final what = l.rank >= 1
          ? '家督'
          : (_merchant(g) ? '店' : (_craft(g) ? '工房' : '田畑'));
      g.ask(
        '兄弟の跡目',
        '$whatを誰が継ぐかで、兄の$elderと弟の$youngerが言い争うようになった。兄は実直だが、才は弟のほうが上だと皆が言う。',
        [
          Choice.h('兄に継がせる', '筋目は守れる。弟は不満を抱く', () {
            g.meet(role, elder, 65);
            g.setFlag('fa_atome_elder');
            g.mark('$whatを、兄の$elderに継がせると定めた');
            return '$youngerは黙って頭を下げ、その年のうちに家を出た。';
          }),
          Choice.h('才のある弟に継がせる', '家は伸びる。兄弟に溝が残る', () {
            g.meet(role, younger, 60);
            g.setFlag('fa_atome_younger');
            g.j(-4);
            g.mark('$whatを、兄をさしおいて弟の$youngerに継がせた');
            return '$elderは「父上の決めたことなら」と言った。目は笑っていなかった。';
          }),
          Choice.h('$whatを分けて与える', '争いは起きない。家は小さくなる', () {
            l.gold = l.gold * 2 ~/ 3;
            g.meet(role, elder, 70);
            g.setFlag('fa_atome_split');
            g.j(3);
            g.mark('$whatを、二人の子に分けて与えた');
            return '二人は、それぞれの取り分を手にして頭を下げた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------
  // 子のない家の養子。
  SceneDef(
    'fa_yoshi',
    35,
    62,
    (g) => 3,
    (g) =>
        _home(g) &&
        g.active &&
        g.l.married &&
        g.l.kids == 0 &&
        g.l.rank <= 7 &&
        !g.l.people.containsKey('養子'),
    (g, next) {
      final l = g.l;
      final buke = l.rank >= 1;
      // 迎えた子の生まれた年も残す（親類・奉公人の子は少年、捨て子は乳飲み子）。
      void adopt(String name, int bond, int age) {
        l.kids = 0;
        l.kidYears.clear();
        l.addKid(g.year - age);
        g.meet('養子', name, bond);
      }

      final kin = g.rng.pick(kGivenM);
      final other = g.rng.pick(kGivenM.where((x) => x != kin).toList());
      final foundling = g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF);
      g.ask('養子', '連れ合いとのあいだに、子が授からない。家の行く末を思い、養子の話が持ち上がった。', [
        Choice.h('親類の子を迎える', '血は近い。親類の口出しが増える', () {
          adopt(kin, 60, 8);
          g.setFlag('fa_yoshi_kin');
          g.mark('親類の子の$kinを、養子に迎えた');
          return '$kinは、はにかみながら「父上、母上」と呼んだ。';
        }),
        if (buke)
          Choice.h('主君の勧める家の次男を迎える', '主家の覚えはよくなる。家の中に他人の目が入る', () {
            adopt(other, 45, 10);
            l.fav = _c(l.fav + 6);
            g.setFlag('fa_yoshi_lord');
            g.mark('主君の勧めで、$otherを養子に迎えた');
            return '$otherは礼儀正しかった。正しすぎて、どこか遠かった。';
          })
        else
          Choice.h('働き者の奉公人の子を迎える', '家はよく回る。親類は眉をひそめる', () {
            adopt(other, 60, 10);
            l.net = l.net >= 2 ? l.net - 2 : 0;
            g.setFlag('fa_yoshi_servant');
            g.mark('奉公人の子の$otherを、養子に迎えた');
            return '$otherは、明くる朝から誰よりも早く起きて働いた。';
          }),
        Choice.h('寺の門前の捨て子を引き取る', '小さな命が救われる。口さがない噂も立つ', () {
          adopt(foundling, 75, 0);
          g.j(8);
          g.setFlag('fa_yoshi_foundling');
          g.mark('寺の門前の捨て子を引き取り、$foundlingと名付けて育てた');
          return '籠の中の子は、指をつかんで離さなかった。';
        }),
        Choice.h('迎えず、夫婦二人で生きる', '気楽だ。家は一代で終わるかもしれない', () {
          _bond(l.people['伴侶'], 6);
          g.j(3);
          g.setFlag('fa_no_heir');
          return '縁側で、二人で茶を飲んだ。それも悪くないと思えた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 家督を譲る前に（隠居の岐路より前）。
  SceneDef(
    'fa_tameshi',
    48,
    72,
    (g) => 2.5,
    (g) =>
        _home(g) &&
        g.active &&
        g.l.rank <= 7 &&
        !g.hasFlag('scene:retire') &&
        g.l.kids > 0 &&
        _eldestAtLeast(g, 20) &&
        _child(g) != null &&
        g.l.people['娘'] != _child(g),
    (g, next) {
      final l = g.l;
      final k = _child(g)!;
      final n = k.name;
      final what = l.rank >= 1 ? '家の差配' : (_merchant(g) ? '店' : '仕事');
      g.ask('家督の前に', 'そろそろ家督を譲る頃合いだ。だが、$nに任せきれるかどうか、まだ心が決まらない。', [
        Choice.h('しばらく、すべてを任せて見守る', '子は育つ。しくじりの尻拭いは自分に回る', () {
          if (g.rng.chance(.65)) {
            _bond(k, 8);
            g.j(5);
            g.setFlag('fa_tested_ok');
            g.mark('家督を譲る前に、$nに$whatを任せてみた');
            return '$nは迷いながらも、一つずつ片付けていった。口を出さずに見ているのは、骨が折れた。';
          }
          if (l.rank >= 1) {
            l.fav = _c(l.fav - 4);
          } else {
            _pay(g, 5);
          }
          _bond(k, 2);
          return '$nは大きくしくじった。頭を下げて回るのは、自分の役目だった。';
        }),
        Choice.h('家の掟を書き残す', '思いは残る。子が読むかは分からない', () {
          l.chi += 1;
          g.setFlag('fa_kakun');
          g.mark('子孫のために、家の掟を書き残した');
          return '夜ごと筆を執り、家の掟を一巻にまとめた。';
        }),
        Choice.h('まだ早いと、自ら差配を続ける', '家は揺れない。子は待ちくたびれる', () {
          _bond(k, -8);
          g.setFlag('fa_held_on');
          return '$nは何か言いかけて、やめた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 孫の名付け（孫の岐路のあと、二人目の孫）。
  SceneDef(
    'fa_mago',
    50,
    84,
    (g) => 3,
    (g) =>
        g.hasFlag('scene:grandchild') &&
        g.l.kids >= 1 &&
        _eldestAtLeast(g, 18) &&
        !_monk(g),
    (g, next) {
      final m = g.rng.pick(g.rng.chance(.5) ? kGivenM : kGivenF);
      final lost = g.hasFlag('fa_lost_child');
      g.ask('孫の名', 'また孫が生まれた。名をめぐって、子と、その連れ合いの家とで話がまとまらないという。', [
        Choice.h('自分の名から一字を与える', '家の名は続く。向こうの家は渋い顔をする', () {
          g.meet('孫', m, 70);
          g.j(6);
          g.setFlag('fa_mago_name');
          g.mark('孫に、自分の名の一字を与えた');
          return '小さな孫が、自分と同じ字を背負って泣いている。';
        }),
        Choice.h(
          lost ? '亡くした子の名をもらう' : '亡き父母の名をもらう',
          '亡き人を思い出す。重い名を背負わせるかもしれない',
          () {
            g.meet('孫', m, 75);
            g.j(lost ? 8 : 4);
            g.setFlag('fa_mago_memorial');
            g.mark(lost ? '亡くした子の名を、孫に継がせた' : '亡き父母の名を、孫に継がせた');
            return '名を呼ぶたびに、もう会えない顔が浮かんだ。';
          },
        ),
        Choice.h('向こうの家に任せる', '角は立たない。少し寂しい', () {
          g.meet('孫', m, 55);
          g.j(2);
          return '向こうの家が付けた名は、$mだった。いい名だと思った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 子が若殿の人質の供に出される（武家。城主の人質は `lords.dart`）。
  SceneDef(
    'fa_hitojichi',
    32,
    60,
    (g) => 2,
    (g) =>
        _bukeParent(g) &&
        g.l.rank >= 2 &&
        g.l.rank <= 4 &&
        g.l.kids >= 1 &&
        _kidAged(g, 7, 15),
    (g, next) {
      final l = g.l;
      final heir = l.people['嫡男'];
      final n = heir?.name ?? g.rng.pick<String>(kGivenM);
      final sub = g.rng.pick(kGivenM.where((x) => x != n).toList());
      void send(String name, int joy, int fav) {
        l.fav = _c(l.fav + fav);
        g.j(joy);
        if (heir != null && name == heir.name) l.people.remove('嫡男');
        g.meet('人質に出した子', name, 60);
        g.setFlag('fa_hostage_sent');
        g.setFlag('fa_hostage_at:${g.year}');
        g.mark('子の$nameを、若殿の人質の供として送り出した');
      }

      g.ask(
        '人質の供',
        '${_house(g)}が隣国と和を結び、若殿が人質として向こうへ赴くことになった。供として家臣の子らが添えられる。あなたの子の$nにも声がかかった。',
        [
          Choice.h('$nを供に出す', '主家の信は厚くなる。和が破れれば、子の身が危うい', () {
            send(n, -6, 8);
            return '$nは若殿の輿の脇に付き、振り返らずに国境を越えていった。';
          }),
          if (l.kids >= 2)
            Choice.h('下の子の$subを代わりに出す', '跡継ぎは手元に残る。下の子には酷な務めだ', () {
              send(sub, -8, 5);
              return '$subは、兄の代わりだと知っていた。それでも笑って手を振った。';
            }),
          Choice.h('病を言い立てて断る', '子は手元に残る。家中の目は冷たくなる', () {
            l.fav = _c(l.fav - 8);
            g.setFlag('fa_hostage_refused');
            return '使者は黙って帰った。供には、ほかの家の子が選ばれた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------
  // 人質の供に出した子の、その後（数年のち）。
  SceneDef(
    'fa_hitojichi_back',
    35,
    75,
    (g) => 6,
    (g) {
      final y = _hostageYear(g);
      return y != null &&
          g.year >= y + 4 &&
          g.l.people.containsKey('人質に出した子') &&
          g.l.kids >= 1 &&
          !_monk(g);
    },
    (g, next) {
      final l = g.l;
      final k = l.people['人質に出した子']!;
      final n = k.name;
      if (g.rng.chance(.7)) {
        g.ask(
          '人質の子の帰り',
          '人質の供に出した$nが、立派な若者になって帰ってきた。向こうの家の作法も言葉も、すっかり身につけている。',
          [
            Choice.h('主家に取り立てを願う', '子は家中で重く用いられる。家を継ぐ者は別に要る', () {
              l.people.remove('人質に出した子');
              g.meet('子', n, _c(k.bond + 10));
              if (l.lord != null) l.fav = _c(l.fav + 4);
              g.setFlag('fa_hostage_home');
              g.mark('人質の供から戻った$nを、主家に取り立ててもらった');
              return '$nは、向こうの家の内情に通じた者として、殿の側に召された。';
            }),
            Choice.h('家に置き、跡を継がせる', '家は落ち着く。子は少し窮屈そうだ', () {
              l.people.remove('人質に出した子');
              g.meet(l.rank >= 1 ? '嫡男' : '子', n, _c(k.bond + 6));
              g.setFlag('fa_hostage_home');
              g.mark('人質の供から戻った$nに、家を継がせると定めた');
              return '久しぶりに、家族そろって膳を囲んだ。';
            }),
          ],
          after: next,
        );
        return;
      }
      g.ask('人質の子の危うさ', '主家と隣国の和が破れたという知らせが届いた。向こうの家にいる$nの身が危うい。', [
        if (g.canFight)
          Choice.h('夜陰にまぎれて迎えに行く', '子を取り戻せるかもしれない。敵地に入るのは命がけだ', () {
            if (g.rng.chance(.08)) {
              g.die('人質の子を救いに敵地へ忍び入り、討たれた', 'senshi');
              return '城の堀を越えたところで、篝火に照らされた。';
            }
            if (g.rng.chance(.3)) {
              _loseChild(g, '人質に出した子', '人質に出した子の$nを、和が破れた年に亡くした', 10, 40);
              return '忍び入った屋敷は、もう空だった。';
            }
            l.people.remove('人質に出した子');
            g.meet('子', n, _c(k.bond + 20));
            l.fame += 5;
            g.setFlag('fa_hostage_rescued');
            g.mark('和が破れた年、人質の$nを敵地から連れ戻した');
            return '$nを背負い、夜明けの川を渡った。';
          }),
        Choice.h('主家に、子の命乞いの使者を願う', '筋は通る。向こうが聞くかは分からない', () {
          if (g.rng.chance(.4)) {
            _loseChild(g, '人質に出した子', '人質に出した子の$nを、和が破れた年に亡くした', 10, 40);
            return '使者が持ち帰ったのは、$nの遺髪だった。';
          }
          l.people.remove('人質に出した子');
          g.meet('子', n, _c(k.bond + 8));
          g.setFlag('fa_hostage_home');
          return '人質の交換が整い、$nは痩せこけて帰ってきた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 連れ合いとの諍いと和解。
  SceneDef(
    'fa_kenka',
    22,
    72,
    (g) => 2,
    (g) => g.l.married && g.l.people.containsKey('伴侶') && !_monk(g),
    (g, next) {
      final l = g.l;
      final sp = l.people['伴侶']!;
      final why = l.rank >= 1
          ? (l.female ? '務めばかりで家を顧みない夫に、たまりかねて言い返した' : '務めで家を空けすぎると責められ、言い返した')
          : '銭の使い道のことで言い合いになった';
      final k = _child(g);
      g.ask('連れ合いとの諍い', '$why。それから${sp.name}と、口をきかなくなった。', [
        Choice.h('先に折れて詫びる', '家は穏やかに戻る。意地は飲み込む', () {
          _bond(sp, 10);
          g.j(3);
          g.setFlag('fa_couple_made_up');
          g.mark('諍いののち、連れ合いの${sp.name}に先に詫びた');
          return '頭を下げると、${sp.name}はふっと笑って、湯を沸かしに立った。';
        }),
        Choice.h('意地を通す', '気は晴れる。冷えた空気は長引く', () {
          _bond(sp, -12);
          g.setFlag('fa_couple_cold');
          return '家の中は、冬のように冷えた。';
        }),
        if (k != null && l.kids >= 1)
          Choice.h('${k.name}に間を取り持ってもらう', '子の一言は効く。子に気を遣わせる', () {
            _bond(sp, 6);
            _bond(k, 4);
            g.j(4);
            g.setFlag('fa_couple_made_up');
            return '${k.name}が、二人の膳を並べて置いた。それで、なんとなく済んだ。';
          })
        else
          Choice.h('市で土産を買って帰る', '言葉より早い。蔵は少し軽くなる', () {
            _pay(g, 3);
            _bond(sp, 8);
            g.setFlag('fa_couple_made_up');
            return '黙って差し出した土産を、${sp.name}は黙って受け取った。';
          }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 連れ合いの病。
  SceneDef(
    'fa_spouse_sick',
    30,
    78,
    (g) => 2,
    (g) => g.l.married && g.l.people.containsKey('伴侶') && !_monk(g),
    (g, next) {
      final l = g.l;
      final sp = l.people['伴侶']!;
      final s = sp.name;
      String lose(String how) {
        l.married = false;
        g.setFlag('fa_spouse_died');
        g.j(-25);
        g.mark('連れ合いの$sを、病で亡くした');
        return how;
      }

      g.ask('連れ合いの病', '$sが胸を患い、床から起き上がれなくなった。咳の音が、夜ごとに重くなる。', [
        Choice.h('遠くまで薬を求めに行く', '薬が手に入れば助かりやすい。家を空け、蔵も軽くなる', () {
          _pay(g, 12);
          if (g.rng.chance(.05)) {
            return lose('薬を抱えて戻ったとき、$sはもう目を閉じていた。');
          }
          _bond(sp, 10);
          g.setFlag('fa_spouse_cured');
          g.mark('病の$sのために、遠くまで薬を求めに行った');
          return '煎じた薬を飲ませると、$sの咳は少しずつ静まっていった。';
        }),
        Choice.h('寺社に籠もって祈る', '心は通う。効くかは神仏しだい', () {
          if (g.rng.chance(.15)) {
            return lose('七日目の朝、知らせの者が社の石段を駆け上がってきた。');
          }
          _bond(sp, 6);
          return '籠もりを終えて戻ると、$sが床の上で起き上がっていた。';
        }),
        Choice.h('務めを置いて、枕元を離れない', '$sは心強い。務めは滞る', () {
          if (l.rank >= 1) {
            l.fav = _c(l.fav - 5);
          } else {
            _pay(g, 3);
          }
          if (g.rng.chance(.1)) {
            return lose('手を握ったまま、$sは静かに息を引き取った。');
          }
          _bond(sp, 15);
          g.setFlag('fa_spouse_nursed');
          g.mark('病の$sの枕元を、治るまで離れなかった');
          return 'ひと月ののち、$sは粥を自分の手で口に運んだ。';
        }),
      ], after: next);
    },
  ),
];
