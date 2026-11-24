import 'childhood.dart';
import 'game.dart';
import 'life.dart';
import 'retainers.dart';
import 'rng.dart';
import 'spouse_match.dart';

/// 子の育て方（2026-11-25、ユーザーが決めた項目「子の育て方を決める」）。id・旗は `kd_`。
///
/// 家にいる五〜十四の子に、人物のタブの家族の欄から「寺へ預ける／武芸を仕込む／商いを覚えさせる／家で育てる」を選ぶ
/// （`Kid.raising`。選べるのは年の初めの問いのときだけ。`Game.setKidRaising`）。方針は:
/// - 方針に沿った岐路（[kKidRaisingSceneIds]）: 二年続けると、寺の住職の勧め・若者の試合・市での初めての仕入れ・家の手伝いが出る。
///   四年続けて十五を越えると、その子の行き先（`kd_yukue`）が方針で決まる（祐筆・取り立て・店・家の跡）。
/// - 家族の岐路（`family.dart`）の書き出しと行き先: 元服・裳着の書き出しに一文（[raisingLine]）、子の志（`fa_kokorozashi`）の
///   望む道が方針に沿う、兄弟の跡目（`fa_atome`）の兄弟の描き分け。
/// - 才のある連れ合い（`spouse_match.dart`）と暮らしていれば、子の才が開きやすい。武勇の家臣（`retainers.dart`）がいれば稽古を頼める。

/// 家にいて、歳の分かる五〜十四の子（上から）。画面の家族の欄で育て方を選べる子。
List<Kid> raisableKids(Game g) => [
  for (final k in g.l.kidsInOrder)
    if (k.home && k.alive && k.born != null && g.year - k.born! >= 5 && g.year - k.born! <= 14) k,
];

/// 家を持って暮らす親（仏門・野の道でない、隠居していない）。
bool _parent(Game g) =>
    g.active &&
    !g.hasFlag('priesthood') &&
    !(g.hasFlag('way_outlaw') && g.l.rank == 0);

/// 方針が [r] で、家にいて歳が [lo]〜[hi]、方針を [years] 年以上続けた子（上から）。
Kid? kidRaisedAs(Game g, String r, int lo, int hi, [int years = 2]) {
  for (final k in g.l.kidsInOrder) {
    if (!k.home || !k.alive || k.born == null || k.raising != r) continue;
    final a = g.year - k.born!;
    if (a >= lo && a <= hi && k.raisingYears(g.year) >= years) return k;
  }
  return null;
}

/// 元服・裳着などの書き出しに添える一文（方針がなければ空）。[name] は文に出す名（既定は子の今の名）。
String raisingLine(Kid k, [String? name]) {
  final n = name ?? k.name;
  switch (k.raising) {
    case KidRaising.tera:
      return '寺で学んだ$nは、読み書きでは大人にも負けない。';
    case KidRaising.bugei:
      return k.female ? '薙刀を仕込まれた$nは、背筋がまっすぐ伸びている。' : '武芸を仕込まれた$nは、腕も肩も一回り太くなった。';
    case KidRaising.akinai:
      return '商いを覚えた$nは、市の値の動きを親より先に言い当てる。';
    case KidRaising.ie:
      return '家で育った$nは、親の背中をよく見ていた。';
  }
  return '';
}

/// 子の志（`fa_kokorozashi`）で、子が望む道（方針に沿う。方針がなければ null）。
String? raisingWish(Kid k) => switch (k.raising) {
  KidRaising.tera => '寺で学ぶ',
  KidRaising.bugei => '足軽に出る',
  KidRaising.akinai => '町で商う',
  _ => null,
};

int _c(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

/// その子を指す縁の役割の絆を動かす（なければ何もしない）。
void _bondKid(Game g, Kid k, int n) {
  for (final r in kKidRoles) {
    final p = g.l.people[r];
    if (p != null && p.name == k.name) p.bond = _c(p.bond + n);
  }
}

/// 才が開いた子の印（行き先の岐路が見る）。
String _giftFlag(Kid k) => 'kd_gift:${k.name}';

/// この岐路の id（テストが使う）。
const kKidRaisingSceneIds = ['kd_tera', 'kd_bugei', 'kd_akinai', 'kd_ie', 'kd_yukue'];

List<SceneDef> buildKidRaisingScenes() => [
  // ============================================ 寺へ預けた子
  SceneDef(
    'kd_tera',
    20,
    75,
    (g) => 8,
    (g) => _parent(g) && kidRaisedAs(g, KidRaising.tera, 8, 15) != null,
    (g, next) {
      final l = g.l;
      final k = kidRaisedAs(g, KidRaising.tera, 8, 15)!;
      final n = k.name;
      final clever = cleverSpouse(g);
      g.ask('寺の住職の勧め', '寺に預けた$nの手習いを見に行くと、住職が言った。「この子は筋がよい。いっそ仏門に入れては」。$nは、黙って父母の顔を見ている。', [
        Choice.h('仏門に入れる', '寺で道を究めるだろう。家には戻らない', () {
          g.meet('寺に入った子', n, 60);
          g.l.net += 2;
          g.j(-2);
          g.mark('寺で学んだ子の$nを、仏門に入れた');
          return '$nは、小さな衣を着せられて頭を下げた。顔を上げたとき、もう泣いてはいなかった。';
        }),
        Choice.h('礼を厚くして、学問だけ続けさせる', '読み書きの達者な子に育つ。寺への礼はかさむ', () {
          _pay(g, 6);
          if (clever || g.rng.chance(.5)) g.setFlag(_giftFlag(k));
          _bondKid(g, k, 5);
          return '住職は「惜しいことよ」と笑った。$nは、前より熱心に筆を取るようになった。';
        }),
        if (clever)
          Choice.h('才ある${l.people['伴侶']!.name}に、子の学びを見させる', '親譲りの才が開くかもしれない。寺との縁は薄くなる', () {
            g.setFlag(_giftFlag(k));
            k.raising = KidRaising.ie;
            k.raisingSince = g.year;
            _bondKid(g, k, 8);
            g.j(4);
            return '${l.people['伴侶']!.name}は夜ごと$nに書を読ませた。半年で、寺の誰よりも早く経を写すようになった。';
          }),
        Choice.h('家に連れ戻す', '親子の暮らしが戻る。学びはここまでだ', () {
          k.raising = KidRaising.ie;
          k.raisingSince = g.year;
          _bondKid(g, k, 6);
          g.j(3);
          return '$nは、寺の門を出ると、急に子どもの顔に戻って駆け出した。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 武芸を仕込んだ子
  SceneDef(
    'kd_bugei',
    20,
    75,
    (g) => 8,
    (g) => _parent(g) && kidRaisedAs(g, KidRaising.bugei, 10, 16) != null,
    (g, next) {
      final l = g.l;
      final k = kidRaisedAs(g, KidRaising.bugei, 10, 16)!;
      final n = k.name;
      final buke = l.rank >= 1;
      final brave = krHolder(g)
          ? l.servingRetainers.where((r) => r.temper == RetainerTemper.brave).firstOrNull
          : null;
      final what = k.female ? '薙刀の手合わせ' : (buke ? '家中の若者の試合' : '村祭りの棒術の試合');
      void win() {
        l.fame += 3;
        g.setFlag(_giftFlag(k));
        _bondKid(g, k, 6);
        g.j(5);
      }

      g.ask('子の試合', '武芸を仕込んできた$nが、$whatに出たいと言う。相手は年上ばかりだ。', [
        Choice.h('そのまま出させる', '勝てば名が上がる。負ければ子の鼻が折れる', () {
          if (g.rng.chance(cleverSpouse(g) ? .55 : .45)) {
            win();
            g.mark('武芸を仕込んだ子の$nが、年上を相手に勝ちを収めた');
            return '$nは三人目まで勝ち抜いた。見物の中から、どよめきが起きた。';
          }
          _bondKid(g, k, 2);
          return '$nは一本目で打ち据えられた。帰り道、ずっと黙っていたが、夜、庭で木刀を振っていた。';
        }),
        Choice.h('ひと月、自ら稽古をつけてから出させる', '勝ちは近づく。自分の体もきしむ', () {
          l.hp -= 5;
          if (g.rng.chance(.65)) {
            win();
            g.mark('自ら稽古をつけた子の$nが、試合で勝ちを収めた');
            return 'ひと月の稽古の甲斐あって、$nは相手の小手を鮮やかに打った。';
          }
          _bondKid(g, k, 8);
          return '勝てはしなかった。だが$nは「父上との稽古のほうが痛かった」と笑った。';
        }),
        if (brave != null)
          Choice.h('家臣の${brave.name}に稽古を頼む', '武勇の家臣の腕が子に移る。家臣は子守を嫌がるかもしれない', () {
            brave.bond = _c(brave.bond - 3);
            if (g.rng.chance(.7)) {
              win();
              g.mark('子の$nが、家臣の${brave.name}に鍛えられ、試合に勝った');
              return '${brave.name}は文句を言いながらも、毎朝$nを叩き起こした。試合の日、$nは相手を場外まで押し出した。';
            }
            return '${brave.name}の稽古は厳しすぎた。$nは試合の前日に足をくじいた。';
          }),
        Choice.h('まだ早いと止める', '怪我はしない。子は不満を抱く', () {
          _bondKid(g, k, -6);
          return '$nは口をとがらせたが、木刀を置いた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 商いを覚えさせた子
  SceneDef(
    'kd_akinai',
    20,
    75,
    (g) => 8,
    (g) => _parent(g) && kidRaisedAs(g, KidRaising.akinai, 10, 16) != null,
    (g, next) {
      final l = g.l;
      final k = kidRaisedAs(g, KidRaising.akinai, 10, 16)!;
      final n = k.name;
      g.ask('子の初めての仕入れ', '商いを覚えさせてきた$nが、自分の見立てで品を仕入れて、市で売ってみたいと言う。', [
        Choice.h('元手を渡して任せる', '当たれば子は自信をつける。外れれば元手は消える', () {
          _pay(g, 6);
          if (g.rng.chance(cleverSpouse(g) ? .65 : .5)) {
            l.gold += 14;
            g.setFlag(_giftFlag(k));
            _bondKid(g, k, 6);
            g.mark('商いを覚えた子の$nが、初めての仕入れで儲けを出した');
            return '$nは、雨の前に笠を買い込んでいた。夕立の市で、笠は昼の倍の値で売れた。';
          }
          _bondKid(g, k, 2);
          return '仕入れた瓜は、売り切る前に傷んでしまった。$nは泣かなかった。帳面に、何かを書きつけていた。';
        }),
        Choice.h('町の大店へ修業に出す', '一流の商いを覚える。子は家を離れる', () {
          l.kidLeft(k, KidFate.service, g.year);
          g.setFlag(_giftFlag(k));
          g.l.net += 2;
          g.mark('商いを覚えた子の$nを、町の大店へ修業に出した');
          return '$nは、風呂敷包み一つを背負って、町の大店の暖簾をくぐった。';
        }),
        if (l.rank >= 1)
          Choice.h('武家の子に商いは要らぬと、やめさせる', '家の体面は保てる。子の目から光が消える', () {
            k.raising = KidRaising.ie;
            k.raisingSince = g.year;
            _bondKid(g, k, -8);
            l.fav = _c(l.fav + 1);
            return '$nは算盤を棚に戻した。それきり、市の話をしなくなった。';
          })
        else
          Choice.h('まだ早いと、見習いを続けさせる', '大きな損はない。子は焦れる', () {
            _bondKid(g, k, -2);
            return '$nは不満そうに、また店先の掃除に戻った。';
          }),
      ], after: next);
    },
  ),

  // ============================================ 家で育てた子
  SceneDef(
    'kd_ie',
    20,
    75,
    (g) => 6,
    (g) => _parent(g) && kidRaisedAs(g, KidRaising.ie, 8, 14) != null,
    (g, next) {
      final l = g.l;
      final k = kidRaisedAs(g, KidRaising.ie, 8, 14)!;
      final n = k.name;
      final work = l.rank >= 1 ? '書状の整理' : (l.cls.id == 'merchant' ? '店番' : '田の水見');
      g.ask('家の手伝い', '家で育ててきた$nが、近ごろ黙って$workを手伝うようになった。親のやり方を、よく見て覚えている。', [
        Choice.h('褒めて、少しずつ任せる', '子は誇らしく育つ。外の世を知らないまま大きくなる', () {
          _bondKid(g, k, 10);
          g.j(5);
          g.setFlag('kd_ie_trusted:${k.name}');
          g.mark('家で育てた子の$nに、家の仕事を少しずつ任せた');
          return '$nは、褒められた夜、嬉しそうに何度も寝返りを打っていた。';
        }),
        Choice.h('外の世も見せようと、寺の手習いに通わせる', '世が広がる。親子の時は減る', () {
          k.raising = KidRaising.tera;
          k.raisingSince = g.year;
          _pay(g, 2);
          _bondKid(g, k, 2);
          return '$nは、少し不安そうに寺の門をくぐっていった。';
        }),
        Choice.h('今のまま、のびのびと育てる', '親子の情は深まる。何も変わらない', () {
          _bondKid(g, k, 5);
          g.j(3);
          return '夕暮れ、二人で並んで家路についた。';
        }),
      ], after: next);
    },
  ),

  // ============================================ 子の行き先（方針を四年続け、十五を越えた子）
  SceneDef(
    'kd_yukue',
    28,
    80,
    (g) => 10,
    (g) => _parent(g) && _yukueKid(g) != null,
    (g, next) {
      final l = g.l;
      final k = _yukueKid(g)!;
      final n = k.name;
      final buke = l.rank >= 1;
      final gift = g.hasFlag(_giftFlag(k));
      final heirRole = k.female ? '娘' : (buke ? '嫡男' : '子');
      String intro;
      String goLabel, goHint, goMark, goText;
      void Function() goFx;
      switch (k.raising) {
        case KidRaising.tera:
          intro = '寺で学んだ$nの筆の評判が広まり、${buke ? '主家の祐筆の見習いに' : '名主の家の書役に'}という話が来た。';
          goLabel = '召し出しに応じさせる';
          goHint = '子は筆で身を立てる。家からは離れる';
          goMark = '寺で学んだ子の$nが、筆の才で召し出された';
          goText = '$nは、${gift ? '初めて書いた書状を殿に褒められたと、文をよこした' : '慣れない勤めに戸惑いながらも、毎月文をよこした'}。';
          goFx = () {
            l.kidLeft(k, KidFate.service, g.year);
            l.net += 2;
            if (buke) l.fav = _c(l.fav + (gift ? 5 : 2));
          };
        case KidRaising.bugei:
          intro = k.female
              ? '薙刀を仕込んだ$nの腕を見込んで、奥の警固に上がらぬかと話が来た。'
              : (buke ? '武芸を仕込んだ$nが家中の目に留まり、殿の近くに取り立てたいと話が来た。' : '武芸を仕込んだ$nに、足軽の組頭が目をつけ、組に入れたいと言ってきた。');
          goLabel = '送り出す';
          goHint = '子は腕で身を立てる。危うい場にも出る';
          goMark = '武芸を仕込んだ子の$nが、腕を見込まれて召し出された';
          goText = gift ? '$nは、ほどなく家中で一番の若武者と呼ばれるようになった。' : '$nは、胸を張って出ていった。';
          goFx = () {
            l.kidLeft(k, KidFate.service, g.year);
            l.fame += gift ? 4 : 2;
            if (buke) l.fav = _c(l.fav + 2);
          };
        case KidRaising.akinai:
          intro = '商いを覚えた$nが、自分の店を持ちたいと言い出した。目をつけた空き店が、町の辻にあるという。';
          goLabel = '元手を出して、店を持たせる';
          goHint = '子は一本立ちする。蔵の銭は大きく出ていく';
          goMark = '商いを覚えた子の$nに、元手を出して店を持たせた';
          goText = gift ? '$nの店は、一年で隣の店を買い取るほどになった。' : '$nの店は小さいながら、毎朝いちばんに暖簾を上げた。';
          goFx = () {
            _pay(g, 15);
            l.kidLeft(k, KidFate.away, g.year);
            if (gift) l.gold += 10;
            l.net += 2;
          };
        default:
          intro = '家で育てた$nは、親の仕事をひと通り覚えた。そろそろ行く末を決めねばならない。';
          goLabel = '広い世を見に、旅に出す';
          goHint = '子は世を知る。戻るかどうかは分からない';
          goMark = '家で育てた子の$nを、広い世を見に旅立たせた';
          goText = '$nは、何度も振り返りながら村の外れの道を下っていった。';
          goFx = () {
            l.kidLeft(k, KidFate.away, g.year);
            g.j(-2);
          };
      }
      g.ask('子の行き先', intro, [
        Choice.h(goLabel, goHint, () {
          goFx();
          g.setFlag('kd_yukue_out');
          g.mark(goMark);
          return goText;
        }),
        Choice.h(
          k.female ? '家に残し、婿を取って家を継がせる' : '家に残し、跡を継がせる',
          '家は手堅く続く。子の才は家の中に収まる',
          () {
            g.meet(heirRole, n, gift ? 80 : 70);
            g.setFlag('kd_yukue_home');
            g.mark('育て上げた子の$nを、家の跡継ぎと定めた');
            return '$nは、少し残念そうに、それでも嬉しそうにうなずいた。';
          },
        ),
      ], after: next);
    },
  ),
];

/// 行き先の岐路に出る子（方針を四年以上続け、家にいる十五〜二十の子。上から）。
Kid? _yukueKid(Game g) {
  for (final r in KidRaising.all) {
    final k = kidRaisedAs(g, r, 15, 20, 4);
    if (k != null) return k;
  }
  return null;
}
