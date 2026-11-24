import 'castle_life.dart';
import 'childhood.dart';
import 'daimyo_life.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'peace.dart';
import 'rng.dart';

/// 家臣の顔ぶれ（2026-11-25、ユーザーが決めた項目「家臣の顔ぶれ」）。id・旗は `kr_`。
///
/// 城主より上（位5〜8。城を預かる身と当主）の人は、名と気質（忠義・野心・知恵・武勇）のある家臣を数人持つ
/// （`Life.retainers`。古い保存は空で読む）。最初の岐路「家臣の顔ぶれ」（`kr_kaobure`）で三人が揃い、誰を筆頭に
/// 取り立てるかを選ぶ。そのあと一生に一度ずつ: 家臣どうしの諍い・増長した家臣を遠ざけるか・野心のある家臣が謀反を囁く
/// （主家に仕える身）／家臣の謀反の兆し（当主）・忠義の家臣が命を張る・牢人を新たに召し抱える・老いた家臣との別れ。
/// 段を踏んだ年は旗 `kr_at:<年>` に残し、次の岐路は年を空けてから出す（[krSince]）。
/// 位は上げない。家臣は功・信頼・名声・兵・銭と、[retainerPlotBonus]（下剋上に効く口）で返す。
/// 人物のタブに「家臣」の欄が出る（[retainerRows]）。

/// 家臣を持つ身（城を預かる城主・家老・宿老と、当主）。
bool krHolder(Game g) => clLord(g) || dmLord(g);

/// 最後に家臣の岐路を踏んでから何年たったか。踏んでいなければ -1。
int krSince(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('kr_at:')) return g.year - int.parse(f.substring(6));
  }
  return -1;
}

void _stamp(Game g) {
  g.l.flags.removeWhere((f) => f.startsWith('kr_at:'));
  g.setFlag('kr_at:${g.year}');
}

int _c(int v) => clampInt(v, 0, 100);
void _fav(Game g, int n) => g.l.fav = _c(g.l.fav + n);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _troops(Game g, int n) => g.l.troops = g.l.troops + n < 0 ? 0 : g.l.troops + n;
void _bond(Retainer r, int n) => r.bond = _c(r.bond + n);

/// まだ使っていない家臣の名（姓と名）。
String _newName(Game g) {
  final used = {for (final r in g.l.retainers) r.name};
  for (var i = 0; i < 20; i++) {
    final n = '${g.rng.pick(kSurnames)}${g.rng.pick(g.l.freeNames(kGivenM))}';
    if (!used.contains(n)) return n;
  }
  return '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
}

/// 家臣の名の姓（名の表 `kSurnames` のうち、名の頭に合ういちばん長いもの）。
String _surname(String name) {
  var best = '';
  for (final s in kSurnames) {
    if (name.startsWith(s) && s.length > best.length) best = s;
  }
  return best.isEmpty ? name.substring(0, name.length > 2 ? 2 : name.length) : best;
}

Retainer _hire(Game g, String temper, {int bond = 50}) {
  final r = Retainer(_newName(g), temper, bond: bond, since: g.year);
  g.l.retainers.add(r);
  return r;
}

/// 気質ごとの、取り立てるときの匂わせ。
const kRetainerHint = {
  RetainerTemper.loyal: '裏切らない。才は並だ',
  RetainerTemper.ambitious: '才は切れる。重く用いれば、野心も育つ',
  RetainerTemper.wise: '政と調略に強い。武辺者には侮られる',
  RetainerTemper.brave: '戦で頼れる。政は苦手だ',
};

/// 仕えている家臣のうち、その気質の者（思いの深い順）。
List<Retainer> _of(Game g, String temper) =>
    g.l.servingRetainers.where((r) => r.temper == temper).toList()
      ..sort((a, b) => b.bond.compareTo(a.bond));

/// 主家に仕える身（城主・家老・宿老。当主でない）。
bool _underLord(Game g) => clLord(g) && g.l.rank <= 7;

/// 下剋上（`adult.dart` の `gekokujo`・`Game.betrayChance`）に家臣が効く分。担当Bの「謀反の支度」から足す口。
/// - 野心のある家臣で、あなたへの思いの深い者（五十から）は、ひとりにつき後押しする。
/// - 忠義の家臣で、思いのとても深い者（七十から）は、あなたについてくる。
/// - 謀反の囁きに耳を傾けた（`kr_plot`）なら、家中の支度が進んでいる。主君に告げた（`kr_reported`）なら、家中が口を閉ざす。
/// 家臣がいなければ 0。下げる側も含めて、おおよそ -0.05〜+0.12 に収める。
double retainerPlotBonus(Game g) {
  final l = g.l;
  if (l.retainers.isEmpty) return 0;
  var b = 0.0;
  for (final r in l.servingRetainers) {
    if (r.temper == RetainerTemper.ambitious && r.bond >= 50) b += .04;
    if (r.temper == RetainerTemper.loyal && r.bond >= 70) b += .02;
  }
  if (g.hasFlag('kr_plot')) b += .06;
  if (g.hasFlag('kr_reported')) b -= .04;
  return clampD(b, -.05, .12);
}

/// 人物のタブの「家臣」の欄。気質・名・今（筆頭・思いの深さの言い方・去った・亡くなった）・薄く出すか。
/// 家臣を持つ身でなくなったら、仕えていた者も薄く出す。
List<(String, String, bool)> retainerRows(Game g) {
  final holder = krHolder(g);
  return [
    for (final r in g.l.retainers)
      (
        r.temper,
        [
          r.name,
          if (r.serving && r.head) '筆頭',
          if (r.serving && holder) _bondWord(r.bond),
          if (r.serving && !holder) 'いまは離れている',
          if (!r.serving) RetainerState.label[r.state]!,
        ].join('・'),
        !r.serving || !holder,
      ),
  ];
}

String _bondWord(int b) => b >= 75
    ? '心服している'
    : b >= 50
    ? '従っている'
    : b >= 30
    ? '不満を抱えている'
    : '心が離れている';

/// この岐路の id（テストが使う）。
const kRetainerSceneIds = [
  'kr_kaobure',
  'kr_isakai',
  'kr_tozake',
  'kr_sasayaki',
  'kr_uragiri',
  'kr_inochi',
  'kr_toritate',
  'kr_wakare',
];

/// 家臣が揃ってから [gap] 年たち、仕えている家臣が [min] 人以上いる。
bool _ready(Game g, int gap, [int min = 1]) =>
    krHolder(g) &&
    g.l.retainers.isNotEmpty &&
    krSince(g) >= gap &&
    g.l.servingRetainers.length >= min;

const _w = 6.0;

List<SceneDef> buildRetainerScenes() => [
  // ============================================ 家臣の顔ぶれ（家臣を持つ身になって最初の年に）
  SceneDef(
    'kr_kaobure',
    15,
    80,
    (g) => 30,
    (g) => krHolder(g) && g.l.retainers.isEmpty,
    (g, next) {
      final l = g.l;
      final ts = [...RetainerTemper.all];
      // 気質の違う三人（並びは乱数で）。
      final picked = <String>[];
      while (picked.length < 3) {
        final t = g.rng.pick(ts);
        ts.remove(t);
        picked.add(t);
      }
      final rs = [for (final t in picked) _hire(g, t)];
      _stamp(g);
      final lord = l.rank >= 8;
      g.ask(
        '家臣の顔ぶれ',
        '${lord ? '当主として家を束ねる身となり' : '城を預かる身となり'}、仕える者たちが顔を揃えた。'
            '${rs.map((r) => '${r.temper}の${r.name}').join('、')}。誰を筆頭に据えるかで、家中の色が決まる。',
        [
          for (final r in rs)
            Choice.h('${r.name}を筆頭に取り立てる', kRetainerHint[r.temper]!, () {
              r.head = true;
              _bond(r, 25);
              switch (r.temper) {
                case RetainerTemper.loyal:
                  _fav(g, 3);
                case RetainerTemper.ambitious:
                  l.merit += 4;
                  g.setFlag('kr_ambit_head');
                case RetainerTemper.wise:
                  l.gold += 8;
                  l.sei = clampInt(l.sei + 1, 0, 99);
                default:
                  _troops(g, 10);
              }
              for (final o in rs.where((x) => x != r)) {
                _bond(o, -5);
              }
              g.mark('家臣の${r.name}を筆頭に取り立てた');
              return '${r.name}は深く頭を下げた。ほかの者たちは、それぞれの顔で黙っていた。';
            }),
          Choice.h('誰も特に重く用いない', '家中は平らかに保てる。頼れる懐刀はいない', () {
            for (final o in rs) {
              _bond(o, 5);
            }
            return '皆に同じ言葉をかけ、同じ盃を取らせた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 家臣どうしの諍い
  SceneDef('kr_isakai', 20, 80, (g) => _w, (g) => _ready(g, 2, 2), (g, next) {
    final l = g.l;
    final ss = l.servingRetainers.toList();
    // 武勇と知恵の者がいれば、その二人。いなければ思いの深い順に上の二人。
    final brave = _of(g, RetainerTemper.brave).firstOrNull;
    final wise = _of(g, RetainerTemper.wise).firstOrNull;
    final a = brave ?? ss[0];
    final b = (wise != null && wise != a) ? wise : ss.firstWhere((x) => x != a);
    _stamp(g);
    g.ask(
      '家臣の諍い',
      '評定の席で、${a.temper}の${a.name}と${b.temper}の${b.name}が言い争いになった。'
          '「槍も持たぬ者が戦を語るな」「算盤も弾けぬ者が国を語るな」。どちらも引かない。皆の目が、あなたに集まった。',
      [
        Choice.h('${a.name}の肩を持つ', '${a.name}は恩に着る。${b.name}の胸にはしこりが残る', () {
          _bond(a, 12);
          _bond(b, -15);
          if (a.temper == RetainerTemper.brave) _troops(g, 5);
          return '${b.name}は一礼して席に戻った。目は伏せたままだった。';
        }),
        Choice.h('${b.name}の肩を持つ', '${b.name}は恩に着る。${a.name}の胸にはしこりが残る', () {
          _bond(b, 12);
          _bond(a, -15);
          if (b.temper == RetainerTemper.wise) l.gold += 4;
          return '${a.name}は拳を握ったまま、黙って下がった。';
        }),
        Choice.h('喧嘩は両成敗と、二人とも叱る', '家中の筋は通る。二人とも少し冷める', () {
          _bond(a, -6);
          _bond(b, -6);
          _fav(g, 2);
          return '二人は揃って額を床につけた。評定は、それきり静かになった。';
        }),
        if (l.mi >= 55)
          Choice.h('酒席を設け、二人に盃を交わさせる', '人を和ませる才が当たれば、二人は互いを認める。外れれば座が白ける', () {
            _pay(g, 4);
            if (g.rng.chance(clampD(.45 + l.mi / 250, .45, .85))) {
              _bond(a, 8);
              _bond(b, 8);
              g.setFlag('kr_isakai_made_up');
              g.mark('諍う家臣の${a.name}と${b.name}に、盃を交わさせた');
              return '三杯目で${a.name}が笑い、${b.name}が酌を返した。夜更けには、二人で肩を組んで歌っていた。';
            }
            _bond(a, -3);
            _bond(b, -3);
            return '二人は盃に口もつけず、膳を挟んで睨み合ったまま夜が更けた。';
          }, via: '魅'),
      ],
      after: next,
    );
  }),

  // ============================================ 増長した家臣を遠ざけるか
  SceneDef('kr_tozake', 22, 80, (g) => _w, (g) => _ready(g, 3), (g, next) {
    final l = g.l;
    // 筆頭か、野心の者か、いちばん思いの浅い者。
    final ss = l.servingRetainers.toList();
    final r =
        ss.where((x) => x.head).firstOrNull ??
        _of(g, RetainerTemper.ambitious).firstOrNull ??
        (ss..sort((a, b) => a.bond.compareTo(b.bond))).first;
    _stamp(g);
    g.ask(
      '家臣の増長',
      '${r.temper}の${r.name}が、近ごろ、あなたの名で勝手に村々へ触れを出しているという。咎めた者を、${r.name}は皆の前で笑いものにした。',
      [
        Choice.h('暇を出す', '家中の筋は通る。腕の立つ者を一人失う', () {
          r.state = RetainerState.away;
          r.head = false;
          _fav(g, 2);
          for (final o in l.servingRetainers) {
            _bond(o, 3);
          }
          g.setFlag('kr_dismissed');
          g.mark('増長した家臣の${r.name}に暇を出した');
          return '${r.name}は荷をまとめ、振り返らずに去った。翌朝、家中の空気が少し軽くなっていた。';
        }),
        Choice.h('役を外し、遠ざけて様子を見る', '大事にはならない。恨みは静かに積もる', () {
          r.head = false;
          _bond(r, -20);
          g.setFlag('kr_kept_far');
          return '${r.name}を城下の外れの役に移した。挨拶に来た顔は、笑っていなかった。';
        }),
        Choice.h('才を惜しみ、目をつぶる', '才は手元に残る。増長は止まらない', () {
          _bond(r, 6);
          if (r.temper == RetainerTemper.ambitious) g.setFlag('kr_ambit_grown');
          for (final o in l.servingRetainers.where((x) => x != r)) {
            _bond(o, -5);
          }
          return '何も言わなかった。${r.name}は、ますます大きな顔で城の廊下を歩くようになった。';
        }),
      ],
      after: next,
    );
  }),

  // ============================================ 野心のある家臣が謀反を囁く（主家に仕える身）
  SceneDef(
    'kr_sasayaki',
    22,
    70,
    (g) => g.hasFlag('kr_ambit_grown') || g.hasFlag('kr_ambit_head') ? 14 : _w,
    (g) =>
        _ready(g, 2) &&
        _underLord(g) &&
        g.canFight &&
        _of(g, RetainerTemper.ambitious).any((r) => r.bond >= 40),
    (g, next) {
      final l = g.l;
      final r = _of(g, RetainerTemper.ambitious).first;
      final house = houseName(g, l.lord);
      _stamp(g);
      g.ask(
        '家臣の囁き',
        '夜更け、野心の家臣${r.name}が人払いを願い出た。「$house家の殿は、もはや器ではございませぬ。家中には、殿を担ぎたいと申す者が少なくない。お心ひとつにございます」',
        [
          Choice.h('黙って耳を傾ける', '心強い味方になる。事が漏れれば、身の破滅を招く', () {
            _bond(r, 12);
            g.setFlag('kr_plot');
            if (g.rng.chance(.12)) {
              _fav(g, -10);
              return '話は誰にも漏らさなかったはずだった。だが数日のち、主君の目が冷たくなっていた。';
            }
            g.mark('野心の家臣${r.name}の囁きに、黙って耳を傾けた');
            return '${r.name}は、家中で誰と誰が頼れるかを、指を折って数え上げた。';
          }),
          Choice.h('叱りつけて黙らせる', '主家への筋は守れる。家臣の心は離れる', () {
            _bond(r, -25);
            if (r.bond < 20) {
              r.state = RetainerState.away;
              r.head = false;
              return '${r.name}は青ざめて下がり、月の変わらぬうちに出奔した。';
            }
            return '${r.name}は平伏したまま、二度とその話をしなかった。';
          }),
          Choice.h('主君に告げる', '主君の信頼は厚くなる。家中は口を閉ざす', () {
            r.state = RetainerState.away;
            r.head = false;
            _fav(g, 8);
            g.j(-3);
            for (final o in l.servingRetainers) {
              _bond(o, -6);
            }
            g.setFlag('kr_reported');
            g.mark('謀反を囁いた家臣の${r.name}を、主君に告げた');
            return '${r.name}は捕らえられ、国を追われた。家中の者たちは、それからあなたの前で余計なことを言わなくなった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 家臣の謀反の兆し（当主）
  SceneDef(
    'kr_uragiri',
    20,
    80,
    (g) => g.hasFlag('kr_ambit_grown') ? 14 : _w,
    (g) =>
        _ready(g, 2) &&
        dmLord(g) &&
        _of(g, RetainerTemper.ambitious).any((r) => r.bond < 70),
    (g, next) {
      final l = g.l;
      final r = _of(g, RetainerTemper.ambitious).last;
      _stamp(g);
      g.ask(
        '家臣の謀反の兆し',
        '野心の家臣${r.name}の屋敷に、隣国の使いが夜ごと出入りしているという。証はない。だが、知らせてきた者の顔は青かった。',
        [
          Choice.h('先手を打って討つ', '禍の芽は摘める。家中は震え上がる', () {
            r.state = RetainerState.dead;
            r.head = false;
            g.j(-4);
            g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
            for (final o in l.servingRetainers) {
              _bond(o, -5);
            }
            g.setFlag('kr_struck_first');
            g.mark('謀反の噂のあった家臣の${r.name}を、先手を打って討たせた');
            return '${r.name}の屋敷は夜のうちに囲まれた。証は、ついに出てこなかった。';
          }),
          if (l.chi >= 55)
            Choice.h('泳がせて、証を掴む', '知恵が当たれば、隣国の企みごと暴ける。読み違えれば先を越される', () {
              if (g.rng.chance(clampD(.45 + l.chi / 250, .45, .85))) {
                r.state = RetainerState.away;
                r.head = false;
                _fame(g, 5);
                g.setFlag('kr_plot_exposed');
                g.mark('家臣の${r.name}と隣国の企みを、証を掴んで暴いた');
                return '隣国の密書を押さえた。${r.name}は言い逃れできず、国を追われた。隣国の当主は、何も知らぬと文をよこした。';
              }
              r.state = RetainerState.away;
              r.head = false;
              _troops(g, -(l.troops ~/ 5));
              return '泳がせているうちに、${r.name}は手勢を連れて隣国へ走った。兵の一部が、そのあとを追っていった。';
            }, via: '知'),
          Choice.h('厚く報いて、引き留める', '家は割れない。銭がかかり、ほかの者は不公平に思う', () {
            _pay(g, 15);
            _bond(r, 25);
            for (final o in l.servingRetainers.where((x) => x != r)) {
              _bond(o, -4);
            }
            return '加増の書状を渡すと、${r.name}は一瞬だけ目を泳がせ、それから深く頭を下げた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 忠義の家臣が命を張る
  SceneDef(
    'kr_inochi',
    20,
    80,
    (g) => _w,
    (g) => _ready(g, 2) && _of(g, RetainerTemper.loyal).any((r) => r.bond >= 50),
    (g, next) {
      final l = g.l;
      final r = _of(g, RetainerTemper.loyal).first;
      final peace = peaceTime(g) || !g.canFight;
      _stamp(g);
      g.ask(
        '忠義の家臣',
        peace
            ? '寝所に忍び込んだ刺客の刃を、宿直の${r.name}が身を挺して受けた。刺客は逃げた。${r.name}は肩から血を流しながら「追わせてくだされ」と言う。'
            : '退き戦の殿を誰が務めるか。忠義の家臣${r.name}が進み出た。「殿は先へ。ここはそれがしが」',
        [
          Choice.h(
            '${r.name}に任せる',
            peace ? '刺客の雇い主に迫れる。手負いの身には重い' : '自分は確かに逃れられる。家臣は戻らないかもしれない',
            () {
              if (g.rng.chance(.4)) {
                r.state = RetainerState.dead;
                r.head = false;
                g.j(-8);
                for (final o in l.servingRetainers) {
                  _bond(o, 6);
                }
                g.setFlag('kr_loyal_died');
                g.mark('忠義の家臣${r.name}が、身を挺して果てた');
                return peace
                    ? '${r.name}は刺客を追い詰め、相討ちになった。懐から、あなたに宛てた短い文が出てきた。'
                    : '${r.name}は戻らなかった。夜明けに届いたのは、刃こぼれした太刀だけだった。';
              }
              _bond(r, 15);
              _fame(g, 3);
              g.setFlag('kr_loyal_saved');
              return peace
                  ? '${r.name}は刺客の隠れ家を突き止めて戻った。雇い主の名は、胸にしまっておくことにした。'
                  : '${r.name}は傷だらけで戻ってきた。殿の背を守り抜いたと、皆が噂した。';
            },
          ),
          Choice.h(
            peace ? '追わせず、傷の手当てを命じる' : '共に退き、二人とも生きて帰る',
            peace ? '家臣の命は守れる。刺客の雇い主は闇の中だ' : '腕が当たれば皆が生きて戻る。外れれば二人とも危うい',
            () {
              if (peace) {
                _bond(r, 10);
                g.j(2);
                return '${r.name}は不服そうだったが、医者の前で大人しく肩を出した。';
              }
              if (g.might()) {
                _bond(r, 18);
                _fame(g, 4);
                g.setFlag('kr_loyal_saved');
                g.mark('忠義の家臣${r.name}と共に、退き戦を斬り抜けた');
                return '二人で追っ手を三度押し返し、夜明けに味方の陣へ転がり込んだ。';
              }
              l.hp -= 18;
              if (g.rng.chance(.3)) {
                r.state = RetainerState.dead;
                r.head = false;
                g.j(-8);
                g.setFlag('kr_loyal_died');
                g.mark('忠義の家臣${r.name}が、身を挺して果てた');
                return '${r.name}はあなたをかばって槍を受けた。あなたも深手を負った。';
              }
              _bond(r, 10);
              return '深手を負ったが、${r.name}に担がれて生きて戻った。';
            },
            via: peace ? null : '武',
          ),
        ],
        after: next,
      );
    },
  ),

  // ============================================ 牢人を新たに召し抱える
  SceneDef(
    'kr_toritate',
    20,
    75,
    (g) => g.l.servingRetainers.length <= 2 ? 10 : 4,
    (g) => _ready(g, 2, 0) && g.l.servingRetainers.length < 5,
    (g, next) {
      final l = g.l;
      final t = g.rng.pick(RetainerTemper.all);
      final n = _newName(g);
      _stamp(g);
      final what = switch (t) {
        RetainerTemper.loyal => '前の主家が滅びたあとも、主の墓を守り続けていたという',
        RetainerTemper.ambitious => '三つの家を渡り歩き、どこでも手柄を立てたという',
        RetainerTemper.wise => '寺で学び、算盤と築城の書に通じているという',
        _ => '槍一本で三人を突き伏せたという',
      };
      g.ask('牢人の仕官', '牢人の$nが、門を叩いて仕官を願い出た。$what。', [
        Choice.h('召し抱える', kRetainerHint[t]!, () {
          _pay(g, 5);
          final r = Retainer(n, t, bond: 55, since: g.year);
          l.retainers.add(r);
          g.mark('牢人の$nを、家臣に召し抱えた');
          return '$nは、その日のうちに屋敷の長屋に荷を解いた。';
        }),
        Choice.h('ひと月だけ試しに使う', '人となりは見極められる。相手は軽んじられたと思うかもしれない', () {
          if (g.rng.chance(.6)) {
            l.retainers.add(Retainer(n, t, bond: 45, since: g.year));
            return 'ひと月ののち、$nを正式に召し抱えた。';
          }
          return '$nは、ひと月を待たずに去っていった。';
        }),
        Choice.h('断る', '何も変わらない', () => '$nは黙って一礼し、次の町へ向かった。'),
      ], after: next);
    },
  ),

  // ============================================ 老いた家臣との別れ
  SceneDef(
    'kr_wakare',
    30,
    85,
    (g) => 8,
    (g) =>
        _ready(g, 2) &&
        g.l.servingRetainers.any((r) => r.since != null && g.year - r.since! >= 12),
    (g, next) {
      final l = g.l;
      final r = l.servingRetainers.firstWhere(
        (r) => r.since != null && g.year - r.since! >= 12,
      );
      _stamp(g);
      g.ask(
        '老臣の床',
        '長く仕えてきた${r.temper}の${r.name}が病の床に就いた。見舞うと、${r.name}は細い声で「せがれを、よしなに」と言った。',
        [
          Choice.h('せがれを跡に取り立てると約束する', '家臣の家は続く。せがれの器は分からない', () {
            r.state = RetainerState.dead;
            final heir = Retainer(
              '${_surname(r.name)}${g.rng.pick(l.freeNames(kGivenM))}',
              g.rng.chance(.6) ? r.temper : g.rng.pick(RetainerTemper.all),
              bond: 60,
              since: g.year,
            );
            l.retainers.add(heir);
            for (final o in l.servingRetainers) {
              _bond(o, 4);
            }
            g.mark('老いた家臣の${r.name}を看取り、せがれを跡に取り立てた');
            return '${r.name}は安心したように目を閉じた。葬儀のあと、せがれの${heir.name}が挨拶に来た。';
          }),
          Choice.h('手厚く弔う', '家中の者は、主の情を知る。銭がかかる', () {
            r.state = RetainerState.dead;
            _pay(g, 5);
            g.j(2);
            for (final o in l.servingRetainers) {
              _bond(o, 6);
            }
            return '寺で七日の法要を営んだ。家臣たちは、黙って手を合わせていた。';
          }),
          Choice.h('静かに見送る', '何も変わらない。寂しさだけが残る', () {
            r.state = RetainerState.dead;
            g.j(-2);
            return '${r.name}の座っていた評定の席は、しばらく空けたままにした。';
          }),
        ],
        after: next,
      );
    },
  ),
];
