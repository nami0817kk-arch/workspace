import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'rng.dart';

/// 縁談の相手を選ぶ（2026-11-25、ユーザーが決めた項目「縁談の相手を選ぶ」）。id・旗は `en_`。
///
/// 前の縁談は、来た一人を受けるか断るかだけだった。いまは家柄・気立て・才の違う二、三人の候補から選ぶ
/// （`adult.dart` の `engagement` が [spouseCandidates] と [marrySpouse] を使う）。
/// - 家柄の良い家（[kSpouseNoble]）: 持参が多く、主君の信頼（武家）・村での顔（庶民）も増える。相手の家の頼みも背負う
///   （のちに「舅の家の頼み」`en_shuto` が出る）。
/// - 気立ての良い人（[kSpouseGentle]）: 持参は少ないが、幸福が大きく、絆も深い。苦しい年に支えてくれる（`en_sasae`）。
/// - 才のある人（[kSpouseClever]）: 銭回りがよくなる（`en_saikaku`）。子の育て方の岐路（`kid_raising.dart`）で、子の才が開きやすい。
/// どれを選んでも、文は前と同じ「◯◯と夫婦になった」（最期の条件と遺されたものが見ている）。縁のある人は `伴侶`。
/// 選んだ型は旗 `en_kind:<型>` に残す（連れ合いが変われば置き換わる）。

const kSpouseNoble = 'noble';
const kSpouseGentle = 'gentle';
const kSpouseClever = 'clever';

/// 縁談の候補ひとり。
class SpouseCand {
  SpouseCand(this.kind, this.name, this.label, this.hint);
  final String kind;

  /// 縁のある人に残る名（武家なら「◯◯家の◯◯」）。
  final String name;
  final String label, hint;
}

/// 連れ合いの型（いま連れ添っている人の）。いなければ null。
String? spouseKind(Game g) {
  if (!g.l.married || g.l.people['伴侶'] == null) return null;
  for (final f in g.l.flags) {
    if (f.startsWith('en_kind:')) return f.substring(8);
  }
  return null;
}

/// 才のある連れ合いと暮らしている（子の育て方の岐路が見る）。
bool cleverSpouse(Game g) => spouseKind(g) == kSpouseClever;

/// 縁談の候補を二、三人。家柄の良い家と気立ての良い人はいつも、才のある人はときどき。
List<SpouseCand> spouseCandidates(Game g) {
  final l = g.l;
  final r = g.rng;
  final buke = l.rank >= 1;
  final pool = l.female ? kGivenM : kGivenF;
  final names = [...l.freeNames(pool)];
  String given() {
    final n = r.pick(names);
    if (names.length > 1) names.remove(n);
    return n;
  }

  final whose = l.female ? '息子' : '娘';
  final cands = <SpouseCand>[];
  // 野に生きる者（野盗・流れ者・抜け忍）には、家柄の良い家は子を出さない。
  final outlaw = g.hasFlag('way_outlaw') && l.rank == 0;

  // 家柄の良い家
  if (!outlaw) {
    final s = r.pick(kSurnames);
    final gv = given();
    final name = buke ? '$s家の$gv' : gv;
    final from = buke
        ? '重臣の$s家の$gv'
        : switch (l.cls.id) {
            'fisher' => '網元の$whoseの$gv',
            'merchant' => '大店の$whoseの$gv',
            _ => '庄屋の$whoseの$gv',
          };
    cands.add(
      SpouseCand(
        kSpouseNoble,
        name,
        from,
        buke ? '持参が多く、主君の覚えもよくなる。相手の家の頼みも背負う' : '持参が多く、土地での顔も広がる。相手の家の頼みも背負う',
      ),
    );
  }
  // 気立ての良い人
  {
    final s = r.pick(kSurnames);
    final gv = given();
    final name = buke ? '$s家の$gv' : gv;
    cands.add(
      SpouseCand(
        kSpouseGentle,
        name,
        buke ? '気立てのよい小身の$s家の$gv' : '気立てのよいと評判の$gv',
        '持参は少ない。日々に笑いが絶えず、苦しい年も支えてくれる',
      ),
    );
  }
  // 才のある人（ときどき）
  if (r.chance(.65)) {
    final s = r.pick(kSurnames);
    final gv = given();
    final name = buke ? '$s家の$gv' : gv;
    final sai = l.female ? '才子' : '才女';
    cands.add(
      SpouseCand(
        kSpouseClever,
        name,
        buke ? '$saiと噂の$s家の$gv' : '$saiと噂の$gv',
        '才気のある人。家の銭回りがよくなり、子も聡く育つという',
      ),
    );
  }
  return cands;
}

/// 縁談の問いの文。
String spouseIntro(Game g, List<SpouseCand> cs) {
  final whose = g.l.female ? '息子' : '娘';
  if (cs.length == 1) {
    return '縁談が持ち上がった。野に生きる身に、$whoseをやろうという家は少ない。それでも、ひとりだけ話が来た。';
  }
  final n = cs.length == 3 ? '三' : '二';
  final what = cs.any((c) => c.kind == kSpouseNoble) ? '家柄、気立て、才' : '気立てと才';
  return '縁談が持ち上がった。仲人が、$nつの家の$whoseの名を挙げてきた。$what。誰と添うかで、これからの暮らしが変わる。';
}

/// 候補と夫婦になる（前の縁談の「受ける」と同じ文を残す）。
String marrySpouse(Game g, SpouseCand c) {
  final l = g.l;
  l.married = true;
  l.flags.removeWhere((f) => f.startsWith('en_kind:') || f.startsWith('en_at:'));
  g.setFlag('en_kind:${c.kind}');
  g.setFlag('en_at:${g.year}');
  final String tail;
  switch (c.kind) {
    case kSpouseNoble:
      l.net += 4;
      l.gold += 10 + l.rank * 7;
      if (l.rank >= 1) l.fav = clampInt(l.fav + 5, 0, 100);
      g.j(6);
      g.meet('伴侶', c.name, 45);
      tail = '持参の品が蔵に運び込まれ、相手の家の者が大勢祝いに来た。';
    case kSpouseGentle:
      l.net += 2;
      l.gold += 2 + l.rank * 2;
      g.j(14);
      g.meet('伴侶', c.name, 65);
      tail = '祝言の夜、${c.name}は緊張したあなたを見て、くすりと笑った。';
    default:
      l.net += 3;
      l.gold += 5 + l.rank * 4;
      g.j(9);
      g.meet('伴侶', c.name, 55);
      tail = '${c.name}は、嫁いだ明くる日から家の帳面に目を通していた。';
  }
  g.mark('${c.name}と夫婦になった');
  return '${c.name}と夫婦になった。家に灯がともる。$tail';
}

// ---------------------------------------------------------------- 連れ合いの型で出る岐路

/// 夫婦になってから何年たったか。分からなければ -1。
int enSince(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('en_at:')) return g.year - int.parse(f.substring(6));
  }
  return -1;
}

int _c(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

bool _home(Game g) =>
    g.active &&
    !g.hasFlag('priesthood') &&
    !(g.hasFlag('way_outlaw') && g.l.rank == 0);

/// この型の連れ合いと、[years] 年以上連れ添っている。
bool _with(Game g, String kind, int years) =>
    _home(g) && spouseKind(g) == kind && enSince(g) >= years;

/// この岐路の id（テストが使う）。
const kSpouseSceneIds = ['en_shuto', 'en_sasae', 'en_saikaku'];

/// 連れ合いの型の岐路の重み。一生に一度で、連れ添う年は長いので軽くしてある
/// （5 にすると商人・忍びの道の岐路を押しのけ、`trade_farm_test`・`shadow_life_test` の線を割った。2026-11-25）。
/// 気立ての良い人の岐路は、幸福か健康が低い年に4倍。
const kSpouseSceneWeight = 1.5;

List<SceneDef> buildSpouseScenes() => [
  // 家柄の良い家から迎えた人: 相手の家の頼み。
  SceneDef('en_shuto', 18, 70, (g) => kSpouseSceneWeight, (g) => _with(g, kSpouseNoble, 2), (g, next) {
    final l = g.l;
    final sp = l.people['伴侶']!;
    final buke = l.rank >= 1;
    final kin = l.female ? '夫の実家' : '妻の実家';
    g.ask(
      '舅の家の頼み',
      '$kinから使いが来た。${buke ? '跡取りの若者を、あなたの主家に取り立ててもらえるよう口を利いてほしい' : '不作で蔵が空になった。秋まで銭を融通してほしい'}という。${sp.name}は、黙ってこちらの顔を見ている。',
      [
        Choice.h(
          buke ? '主君に口を利く' : '銭を融通する',
          buke ? '相手の家とは固く結ばれる。主君には借りができる' : '相手の家とは固く結ばれる。蔵は軽くなる',
          () {
            if (buke) {
              l.fav = _c(l.fav - 3);
            } else {
              _pay(g, 10);
            }
            l.net += 4;
            sp.bond = _c(sp.bond + 12);
            g.setFlag('en_shuto_helped');
            g.mark('連れ合いの実家の頼みを聞き入れた');
            return buke
                ? '殿は渋い顔をしたが、若者は足軽頭の下に付けられた。$kinからは、礼の品が山と届いた。'
                : '蔵の銭を包んで届けた。秋、$kinの米俵が倍になって返ってきた。';
          },
        ),
        Choice.h('できる限りのことだけをする', '角は立たない。相手の家は物足りなく思う', () {
          _pay(g, 3);
          sp.bond = _c(sp.bond + 3);
          return '少しの品を添えて、丁寧な文を返した。';
        }),
        Choice.h('はっきり断る', '家の筋は通る。連れ合いの肩身は狭くなる', () {
          sp.bond = _c(sp.bond - 12);
          g.j(-3);
          g.setFlag('en_shuto_refused');
          return 'その夜、${sp.name}は口をきかなかった。';
        }),
      ],
      after: next,
    );
  }),

  // 気立ての良い人: 苦しい年に支えてくれる。
  SceneDef(
    'en_sasae',
    18,
    80,
    (g) => g.l.joy < 40 || g.l.hp < g.l.maxhp * .5 ? kSpouseSceneWeight * 4 : kSpouseSceneWeight,
    (g) => _with(g, kSpouseGentle, 1),
    (g, next) {
      final l = g.l;
      final sp = l.people['伴侶']!;
      final hard = l.joy < 40 || l.hp < l.maxhp * .5;
      g.ask(
        '連れ合いの手',
        hard
            ? '何をしても上手くいかない年だった。夜更けに帰ると、${sp.name}が灯を残して待っていた。「冷えたでしょう」と、温めた粥を出してくれた。'
            : '何ということのない夕暮れ、${sp.name}が庭の柿が色づいたと言って、ひとつもいで持ってきた。',
        [
          Choice.h('胸のうちを打ち明ける', '心は軽くなる。弱みも見せる', () {
            g.j(hard ? 10 : 6);
            sp.bond = _c(sp.bond + 10);
            g.setFlag('en_sasae_told');
            g.mark('連れ合いの${sp.name}に、胸のうちを打ち明けた');
            return '${sp.name}は口を挟まずに聞き、最後に「それでも、あなたはよくやっています」とだけ言った。';
          }),
          Choice.h('礼を言って、黙って箸を取る', '静かに温まる。何も変わらない', () {
            g.j(3);
            sp.bond = _c(sp.bond + 3);
            return '黙って食べた。体の芯が、少し温まった。';
          }),
          Choice.h('二人で寺社に詣でる', '心は静まる。少し銭がかかる', () {
            _pay(g, 2);
            g.j(5);
            l.hp = l.hp + 5 > l.maxhp ? l.maxhp : l.hp + 5;
            sp.bond = _c(sp.bond + 6);
            return '二人で長い石段を上った。帰り道、${sp.name}が団子を半分くれた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // 才のある人: 家の銭回りを任せるか。
  SceneDef('en_saikaku', 18, 75, (g) => kSpouseSceneWeight, (g) => _with(g, kSpouseClever, 1), (g, next) {
    final l = g.l;
    final sp = l.people['伴侶']!;
    final buke = l.rank >= 1;
    g.ask(
      '連れ合いの才覚',
      '${sp.name}が、家の帳面を広げて言った。「${buke ? '知行の米の売り時を変えれば、もっと残ります' : '冬の手すきの間に、糸を紡いで町へ卸しましょう'}。任せてもらえませんか」',
      [
        Choice.h('すべて任せる', '才が当たれば家は豊かになる。外れれば笑い者だ', () {
          if (g.rng.chance(.7)) {
            l.gold += 12 + l.rank * 3;
            sp.bond = _c(sp.bond + 10);
            g.setFlag('en_saikaku_ok');
            g.mark('才ある連れ合いの${sp.name}に、家の銭回りを任せた');
            return '一年ののち、蔵には前の年よりずっと多くの銭が残っていた。${sp.name}は得意げに算盤を弾いてみせた。';
          }
          _pay(g, 5);
          sp.bond = _c(sp.bond + 2);
          return '相場が読みと逆に動いた。${sp.name}は悔しそうに唇を噛み、次は外さないと言った。';
        }),
        Choice.h('半分だけ任せて、様子を見る', '大きくは外れない。大きくも当たらない', () {
          l.gold += 5;
          sp.bond = _c(sp.bond + 4);
          return '任せた分だけ、確かに銭が増えた。';
        }),
        Choice.h('家の差配は自分がすると断る', '家の主の面目は保てる。連れ合いの才は眠ったままだ', () {
          sp.bond = _c(sp.bond - 8);
          return '${sp.name}は帳面を閉じ、二度とその話をしなかった。';
        }),
      ],
      after: next,
    );
  }),
];
