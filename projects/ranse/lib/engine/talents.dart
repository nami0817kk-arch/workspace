import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';
import 'trait_scenes.dart';

/// 能力で起きる岐路（2026-11-23、ユーザー指示「武芸数値が上がったり何かしらの能力が高い場合に
/// 何かしらのイベントがあるなど、色々作り込んで欲しい」）。
///
/// - 大人の岐路: 武・知・政・魅・運のそれぞれに、高さの段（60・75・90）で出るもの。
///   二つの能力の組み合わせで出るもの、低い能力で出るものも少し。
/// - 幼少期の岐路: 才のある子に起きる出来事。
/// - 段の一言: ある能力がはじめて 60・75・90 を越えた年に、見聞録へ【才】の一行（[talentMilestones]）。
///
/// id は `tal_`（天下人の最期の `t_` と紛れないように）。旗も `tal_` で始める。

int _c(int v) => clampInt(v, 0, 99);
void _hurt(Game g, int n) => g.l.hp -= n;

bool _monk(Game g) => g.hasFlag('priesthood');
bool _outlaw(Game g) => g.hasFlag('way_outlaw');
bool _merchant(Game g) =>
    g.l.rank == 0 &&
    !_monk(g) &&
    (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

/// 主家に仕える身（大名その人は除く）。
bool _retainer(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    g.active &&
    !_monk(g) &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 主家に仕える侍（戦える人。奥で仕える女性は除く）。
bool _samurai(Game g) => _retainer(g) && g.canFight;

/// 身分のない暮らし（仏門・野の道を除く）。
bool _commoner(Game g) => g.l.rank == 0 && g.active && !_monk(g) && !_outlaw(g);

bool _villager(Game g) =>
    _commoner(g) &&
    !_merchant(g) &&
    const ['farmer', 'fisher', 'beggar', 'ashigaru'].contains(g.l.cls.id);

String _house(Game g) => houseName(g, g.l.lord);

/// 段の一言の「どこで」の言い方。身分で変える。
String _where(Game g) {
  if (g.isChild) {
    const martial = ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'daimyo'];
    if (martial.contains(g.l.cls.id)) return '家中';
    if (g.l.cls.id == 'merchant') return '町内';
    if (g.l.cls.id == 'priest') return '寺の界隈';
    return '村';
  }
  if (_monk(g)) return '寺々';
  if (g.l.rank >= 8) return '領内';
  if (g.l.rank >= 1 && g.l.lord != null) return g.l.female ? '奥' : '家中';
  if (_outlaw(g)) return '街道筋';
  if (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant') return '町';
  return '村';
}

// ======================================================================
// 段の一言
// ======================================================================

const _tiers = [60, 75, 90];

/// 能力ごと・段ごとの一言（大人）。{w} は「どこで」。
const _adultLines = <String, List<String>>{
  'bu': [
    '武芸の腕が、{w}の外にまで聞こえはじめた。',
    '「{w}で一、二を争う使い手」と言われるようになった。',
    '武芸の名が国境を越えた。「天下に並ぶ者なし」と噂する者もいる。',
  ],
  'chi': [
    '物知りとして、{w}で頼られるようになった。',
    '学のある人として、{w}の外からも問いが届くようになった。',
    '「当代に稀な知恵者」との評が、遠国にまで届いた。',
  ],
  'sei': [
    '帳面や段取りを任せれば間違いがない、と{w}で言われはじめた。',
    '{w}の揉め事が、あなたのもとへ持ち込まれるようになった。',
    '「あの人に任せれば国が治まる」と、{w}の外でも噂された。',
  ],
  'mi': [
    '{w}で、あなたの周りに自然と人が集まるようになった。',
    'あなたが口をきけば、こじれた話もまとまる、と{w}で言われる。',
    'あなたを慕う者が、遠くからも訪ねてくるようになった。',
  ],
  'un': [
    '「あの人は運が強い」と、{w}で囁かれはじめた。',
    '危ういところで、なぜかいつも難を逃れる。{w}の者は不思議がった。',
    '「神仏に守られた人」と、{w}の者が手を合わせるようになった。',
  ],
};

/// 能力ごと・段ごとの一言（子ども）。
const _childLines = <String, List<String>>{
  'bu': [
    '力比べで、年上の子にも負けなくなった。',
    '大人を相手にしても引けを取らない、と{w}で評判になった。',
    '「末恐ろしい子だ」と、{w}の大人たちが囁き合った。',
  ],
  'chi': [
    '読み書きを、誰よりも早く覚えた。',
    '大人が首をひねる問いに、すらすら答えるようになった。',
    '「神童だ」と{w}で評判になった。',
  ],
  'sei': [
    '小遣いの勘定を、一文も違えたことがない。',
    '家の帳面の誤りを見つけて、大人を驚かせた。',
    '大人に交じって、{w}の段取りを任されるほどになった。',
  ],
  'mi': [
    '{w}の子らが、いつもあなたの後をついてくる。',
    '大人にも可愛がられ、どこへ行っても菓子をもらった。',
    '「あの子のためなら」と、大人まで動くようになった。',
  ],
  'un': [
    '籤を引けば、なぜか当たりを引く。',
    '崖から落ちても、かすり傷ひとつ負わなかった。',
    '「福の神がついている」と、{w}で言われた。',
  ],
};

int _stat(Game g, String s) => switch (s) {
  'bu' => g.l.bu,
  'chi' => g.l.chi,
  'sei' => g.l.sei,
  'mi' => g.l.mi,
  _ => g.l.un,
};

const _statVia = {'bu': '武', 'chi': '知', 'sei': '政', 'mi': '魅', 'un': '運'};

/// 能力の組み合わせで起きる岐路の印（並びは 武→知→政→魅→運）。
const _comboVia = {
  'tal_combo_yasyu': '武知',
  'tal_combo_machiwari': '知政',
  'tal_combo_shisha': '政魅',
  'tal_combo_jinbo': '武魅',
};

/// 子どもの能力の岐路の印。
const _childVia = {
  'tal_c_sumo': '武',
  'tal_c_uma': '武',
  'tal_c_kosatsu': '知',
  'tal_c_kuchi': '魅',
  'tal_c_soroban': '政',
  'tal_c_shika': '運',
};

Map<String, String>? _traitSceneNames;

/// その場面が起きた訳（[Prompt.cause]）。能力で起きる岐路（`tal_`）は能力の字（組み合わせは二字）、
/// 特性の場面（`tr_`。`kTraitScenesDone` の表）は特性の名。低い能力で起きる岐路（`tal_low_`）と、ふつうの岐路は null。
String? sceneCauseFor(String? id) {
  if (id == null) return null;
  if (id.startsWith('tal_')) {
    final p = id.split('_');
    return _comboVia[id] ?? _childVia[id] ?? (p.length > 2 ? _statVia[p[1]] : null);
  }
  if (id.startsWith('tr_')) {
    final m = _traitSceneNames ??= {
      for (final e in kTraitScenesDone.entries)
        for (final s in e.value) s: kTraits.firstWhere((t) => t.id == e.key).name,
    };
    return m[id];
  }
  return null;
}

/// 毎年の終わりに呼ぶ。ある能力がはじめて 60・75・90 を越えたら、見聞録に【才】の一行を書く。
/// 同じ段は一生に一度（`talent:<能力>:<段>` の旗）。一度に二つ以上の段を越えたときは、高いほうの一行だけ書く。
void talentMilestones(Game g) {
  if (g.life == null || g.l.dead != null) return;
  final lines = g.isChild ? _childLines : _adultLines;
  for (final s in lines.keys) {
    final v = _stat(g, s);
    String? txt;
    for (var i = 0; i < _tiers.length; i++) {
      final flag = 'talent:$s:${_tiers[i]}';
      if (v < _tiers[i] || g.hasFlag(flag)) continue;
      g.setFlag(flag);
      txt = lines[s]![i];
    }
    if (txt != null) g.log('【才】${txt.replaceAll('{w}', _where(g))}', 'good', _statVia[s]);
  }
}

// ======================================================================
// 大人の岐路
// ======================================================================

List<SceneDef> buildTalentScenes() => [
  // ------------------------------------------------------------------ 武
  SceneDef(
    'tal_bu_challenger',
    16,
    50,
    (g) => 4,
    (g) => g.l.bu >= 60 && g.canFight && g.active && !_monk(g),
    (g, next) {
      g.ask('武芸者', '腕の評判を聞きつけて、旅の武芸者が訪ねてきた。「一手、お手合わせ願いたい」', [
        Choice.h('木刀で受けて立つ', '勝てば名が上がる。負ければ骨の一本は折れる', () {
          if (g.rng.chance(.35 + g.l.bu / 250)) {
            g.l.fame += 5;
            g.l.bu = _c(g.l.bu + 1);
            g.setFlag('tal_beat_challenger');
            return '三合目で、相手の木刀を打ち落とした。武芸者は深く礼をして去った。';
          }
          _hurt(g, 15);
          g.l.fame = g.l.fame >= 3 ? g.l.fame - 3 : 0;
          return '肩を打たれ、膝をついた。武芸者は黙って去っていった。';
        }),
        Choice.h('真剣での立ち合いを望む', '命のやりとりになる。勝てば名は一気に広まる', () {
          if (g.rng.chance(.12 - g.l.bu / 1500)) {
            g.die('旅の武芸者と真剣で立ち合い、斬られた', 'sai');
            return '一瞬の差だった。';
          }
          g.l.fame += 12;
          g.l.bu = _c(g.l.bu + 2);
          g.j(-3);
          g.setFlag('tal_beat_challenger');
          g.mark('旅の武芸者と真剣で立ち合い、斬り伏せた');
          return '相手の刃が袖を裂いた。こちらの刃は、相手を斬っていた。';
        }),
        Choice.h('丁重に断る', '体は無事だ。臆したと言われるかもしれない', () {
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          return '茶を出して帰ってもらった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_bu_guard',
    16,
    40,
    (g) => 3,
    (g) => g.l.bu >= 60 && g.canFight && _commoner(g),
    (g, next) {
      final m = _merchant(g);
      g.ask(
        '腕っぷし',
        m
            ? '腕が立つと聞いた隣の店の主が、荷を京まで運ぶ道中の守りを頼みに来た。山には野盗が出るという。'
            : '腕が立つと聞いた商人が、荷を運ぶ道中の守りを頼みに来た。村の若い衆も、武芸を教えてほしいと言っている。',
        [
          Choice.h('用心棒を引き受ける', '銭になる。野盗と斬り合うことになるかもしれない', () {
            if (g.rng.chance(.4)) {
              if (g.rng.chance(.1)) {
                g.die('荷の守りの道中、野盗と斬り合って討たれた', 'senshi');
                return '峠で、十人を超す野盗に囲まれた。';
              }
              _hurt(g, 12);
              g.l.gold += 12;
              g.l.bu = _c(g.l.bu + 1);
              return '峠で野盗を追い払った。手傷は負ったが、礼ははずんでもらえた。';
            }
            g.l.gold += 8;
            return '何事もなく荷を届け、礼の銭を受け取った。';
          }),
          Choice.h('若い衆に武芸を教える', '慕われる。銭にはならない', () {
            g.l.net += 4;
            g.l.mi = _c(g.l.mi + 1);
            g.setFlag('tal_taught_youth');
            g.mark('村の若い衆に武芸を教えた');
            return '夕暮れごとに、若い衆が棒を持って集まるようになった。';
          }),
          Choice.h('断る', '静かに暮らせる', () => '頼みは断った。'),
        ],
        after: next,
      );
    },
  ),

  SceneDef(
    'tal_bu_sohei',
    18,
    55,
    (g) => 4,
    (g) => g.l.bu >= 60 && _monk(g) && !g.l.female && g.active,
    (g, next) {
      g.ask('寺を襲う者', '夜半、野盗の一団が寺の蔵を狙って押し入ってきた。若い僧たちは震えている。', [
        Choice.h('錫杖を手に立ちはだかる', '寺は守れるかもしれない。殺生の戒めに触れる', () {
          if (g.rng.chance(.08)) {
            g.die('寺に押し入った野盗と争い、斬られた', 'sai');
            return '錫杖が折れた。';
          }
          g.l.fame += 6;
          g.j(-2);
          g.setFlag('tal_monk_warrior');
          g.mark('寺に押し入った野盗を、錫杖ひとつで追い払った');
          return '錫杖で三人を打ち倒すと、残りは逃げ散った。';
        }),
        Choice.h('経を唱えて説く', '仏の道に沿う。聞く耳を持つ相手かは分からない', () {
          if (g.rng.chance(.5)) {
            g.l.mi = _c(g.l.mi + 2);
            return '野盗の頭が、ふと手を止めた。米を一俵だけ持って、去っていった。';
          }
          g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
          return '経は届かなかった。蔵は空になった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_bu_gozen',
    18,
    45,
    (g) => 4,
    (g) => g.l.bu >= 75 && g.canFight && _retainer(g),
    (g, next) {
      g.ask('御前試合', '${_house(g)}家の殿の御前で、試合が催される。あなたも名を挙げられた。相手は家老の息子だ。', [
        Choice.h('全力で勝ちにいく', '殿の目に留まる。家老の家には恨まれる', () {
          if (g.rng.chance(.55 + g.l.bu / 400)) {
            g.l.fav = _c(g.l.fav + 10);
            g.l.fame += 8;
            g.setFlag('tal_gozen_win');
            g.setFlag('tal_karo_grudge');
            g.mark('${_house(g)}家の御前試合で、家老の息子を打ち負かした');
            return '一本を取った。殿が膝を打った。家老は笑っていなかった。';
          }
          g.l.fame += 2;
          return '紙一重で敗れた。殿は「よい試合だった」と言った。';
        }),
        Choice.h('相手に花を持たせる', '家中の受けはよい。名は上がらない', () {
          g.l.net += 4;
          g.l.fav = _c(g.l.fav + 3);
          return 'きわどいところで、一本を譲った。家老がこちらを見て頷いた。';
        }),
        Choice.h('病と称して辞退する', '波風は立たない。殿は残念がる', () {
          g.l.fav = _c(g.l.fav - 3);
          return '試合には出なかった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_bu_shinan',
    24,
    55,
    (g) => 4,
    (g) => g.l.bu >= 75 && g.canFight && _retainer(g) && g.l.rank >= 2,
    (g, next) {
      g.ask('指南役', '「家中の若侍に、槍を教えてやってくれぬか」と、上役から内々の話があった。', [
        Choice.h('指南役を引き受ける', '家中に弟子ができる。戦場からは少し遠のく', () {
          g.l.fav = _c(g.l.fav + 6);
          g.l.net += 6;
          g.l.merit += 8;
          g.setFlag('tal_shinan');
          g.mark('${_house(g)}家で、槍の指南役を務めた');
          return '朝ごとに、若侍たちの掛け声が庭に響くようになった。';
        }),
        Choice.h('戦場での働きを望む', '手柄の機会は残る。上役は少しがっかりする', () {
          g.l.bu = _c(g.l.bu + 1);
          return '「槍は戦場で振るうもの」と答えた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_bu_ikki',
    18,
    50,
    (g) => 4,
    (g) =>
        g.l.bu >= 75 && g.canFight && _retainer(g) && g.hasFlag('first_battle'),
    (g, next) {
      g.ask('名乗り', '戦場で、敵方の武者が馬を進めて名乗りを上げた。「そこの者、名のある武者と見た。勝負せよ」', [
        Choice.h('一騎打ちに応じる', '勝てば大手柄。負ければ首を取られる', () {
          if (g.rng.chance(.15 - g.l.bu / 1000)) {
            g.die('戦場で一騎打ちに応じ、討たれた', 'senshi');
            return '槍が交わった。相手のほうが、わずかに速かった。';
          }
          g.l.merit += 25;
          g.l.fame += 10;
          g.l.fav = _c(g.l.fav + 5);
          g.setFlag('tal_ikki');
          g.mark('戦場で一騎打ちに応じ、名のある武者を討ち取った');
          return '組み打ちの末、相手の首を取った。味方から歓声が上がった。';
        }),
        Choice.h('鉄砲で撃たせる', '手柄にはなる。卑怯と言われるかもしれない', () {
          g.l.merit += 10;
          g.l.fame = g.l.fame >= 3 ? g.l.fame - 3 : 0;
          g.j(-3);
          return '鉄砲の音が響き、武者は馬から落ちた。';
        }),
        Choice.h('取り合わずに退く', '命は守れる。手柄は逃す', () => '相手の罵る声を背に、隊列に戻った。'),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_bu_tenka',
    20,
    60,
    (g) => 5,
    (g) => g.l.bu >= 90 && g.canFight && g.active && !_monk(g),
    (g, next) {
      final rival = '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
      g.ask('天下一の噂', '「天下一の使い手」という噂が広まった。それを妬んだ$rivalという者が、闇討ちを企てていると耳にした。', [
        Choice.h('正面から立ち合いを申し込む', '決着はつく。相手も腕は立つ', () {
          if (g.rng.chance(.06)) {
            g.die('天下一の名を賭けた立ち合いで、相討ちになった', 'sai');
            return '刃が交わったまま、二人とも倒れた。';
          }
          g.l.fame += 15;
          g.setFlag('tal_tenka_ichi');
          g.mark('天下一の名を賭けて$rivalと立ち合い、勝った');
          return '一太刀で決まった。$rivalは刀を置き、頭を下げた。';
        }),
        Choice.h('天下一の名を返上する', '妬みは消える。名声も少し消える', () {
          g.l.fame = g.l.fame >= 8 ? g.l.fame - 8 : 0;
          g.j(4);
          return '「天下は広い。上には上がいる」とだけ言った。噂は静まっていった。';
        }),
        Choice.h('放っておく', '何も変わらない。夜道は危うい', () {
          if (g.rng.chance(.12)) {
            g.die('天下一の名を妬んだ$rivalに、夜道で闇討ちされた', 'ansatsu');
            return '月のない夜だった。';
          }
          _hurt(g, 10);
          g.setFlag('tal_tenka_ichi');
          return '夜道で襲われたが、刺客を返り討ちにした。腕に浅い傷が残った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------ 知
  SceneDef(
    'tal_chi_hyojo',
    18,
    60,
    (g) => 4,
    (g) => g.l.chi >= 60 && _samurai(g),
    (g, next) {
      g.ask('評定', '${_house(g)}家の評定で、攻め口が決まらない。上座の重臣が、ふとあなたに目を向けた。「その方はどう見る」', [
        Choice.h('奇策を献じる', '当たれば大手柄。外れれば笑い者だ', () {
          if (g.rng.chance(.35 + g.l.chi / 250)) {
            g.l.merit += 20;
            g.l.fav = _c(g.l.fav + 8);
            g.l.fame += 6;
            g.setFlag('tal_strategy');
            g.mark('${_house(g)}家の評定で奇策を献じ、採られた');
            return '策は採られ、見事に当たった。重臣たちの見る目が変わった。';
          }
          g.l.fav = _c(g.l.fav - 6);
          return '策は採られたが、敵に読まれていた。評定の席で肩身が狭い。';
        }),
        Choice.h('堅実な策を述べる', '大きくは外さない。目立ちもしない', () {
          g.l.fav = _c(g.l.fav + 3);
          g.l.merit += 4;
          return '理にかなった策だと、重臣が頷いた。';
        }),
        Choice.h('上役に譲って黙る', '角は立たない', () => '「それがしには分かりかねます」と頭を下げた。'),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_chi_forgery',
    20,
    60,
    (g) => 4,
    (g) => g.l.chi >= 75 && (_samurai(g) || _merchant(g)) && g.active,
    (g, next) {
      final r = _samurai(g);
      g.ask(
        '偽りの書状',
        r
            ? '同輩の一人が敵に内通しているという書状が、殿のもとに届いた。読ませてもらうと、花押の筆の運びがどこかおかしい。'
            : '取引先が持ち込んだ証文の判が、どこかおかしい。前に見た同じ家の判と、墨の色も筆の癖も違う。',
        [
          Choice.h(
            r ? '偽書だと申し上げる' : '偽りを突きつける',
            r ? '同輩の命が救われる。外れれば立場を失う' : '損は防げる。相手は逆恨みするかもしれない',
            () {
              if (g.rng.chance(.5 + g.l.chi / 300)) {
                if (r) {
                  g.l.fav = _c(g.l.fav + 10);
                  g.l.merit += 12;
                  g.l.net += 3;
                  g.setFlag('tal_saw_forgery');
                  g.mark('敵の偽書を見抜き、同輩の命を救った');
                  return '調べると、敵方の謀りごとと分かった。同輩が涙を流して礼を言った。';
                }
                g.l.gold += 15;
                g.l.fame += 3;
                g.setFlag('tal_saw_forgery');
                return '相手は顔色を変え、詫びの銭を置いて帰った。';
              }
              if (r) g.l.fav = _c(g.l.fav - 8);
              return r ? '証は見つからなかった。殿は不機嫌に席を立った。' : '相手は言い逃れ、話は物別れになった。';
            },
          ),
          Choice.h('黙っておく', r ? '巻き込まれずに済む。同輩はどうなるか' : '揉め事は避けられる。損をかぶる', () {
            g.j(-4);
            if (!r) g.l.gold = g.l.gold >= 10 ? g.l.gold - 10 : 0;
            return r
                ? '同輩は蟄居を命じられた。胸の奥に、重いものが残った。'
                : '黙って判を押した。あとで、やはり騙されたと分かった。';
          }),
        ],
        after: next,
      );
    },
  ),

  SceneDef('tal_chi_mondo', 20, 70, (g) => 4, (g) => g.l.chi >= 75 && g.active, (
    g,
    next,
  ) {
    final nanban = g.year >= 1555 && g.rng.chance(.5);
    final who = nanban ? '南蛮の伴天連' : '諸国を巡る学僧';
    g.ask(
      '問答',
      '学があると聞いて、$whoが訪ねてきた。${nanban ? '天地の成り立ちについて、語り合いたいという。' : '経の解釈について、問答をしたいという。'}',
      [
        Choice.h('教えを請う', '学びが深まる', () {
          g.l.chi = _c(g.l.chi + 3);
          if (nanban) g.setFlag('tal_nanban_talk');
          return nanban ? '大地は丸いという。夜通し話を聞いた。' : '夜を徹して、経の深いところを教わった。';
        }),
        Choice.h('論を戦わせる', '勝てば名が上がる。負ければ恥をかく', () {
          if (g.rng.chance(.4 + g.l.chi / 300)) {
            g.l.fame += 6;
            g.l.chi = _c(g.l.chi + 1);
            g.setFlag('tal_mondo_win');
            g.mark('$whoとの問答で、一歩も引かなかった');
            return '$whoは最後に笑い、「よき問答であった」と言った。';
          }
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          return '言葉に詰まった。見物の者たちが、くすくす笑った。';
        }),
        Choice.h('会わずに帰す', '何も起きない', () => '留守と言って帰ってもらった。'),
      ],
      after: next,
    );
  }),

  SceneDef(
    'tal_chi_fushin',
    20,
    60,
    (g) => 4,
    (g) => g.l.chi >= 75 && (_samurai(g) || _villager(g)),
    (g, next) {
      final r = _samurai(g);
      g.ask(
        r ? '城の縄張り' : '暴れ川',
        r
            ? '${_house(g)}家で出城を築くことになり、縄張りの案を出せと命じられた。'
            : '毎年のように、村の川があふれて田が流される。工夫のある者として、村の衆があなたを頼ってきた。',
        [
          Choice.h(
            r ? '堀を幾重にもめぐらす案を出す' : '堤に切れ目を設け、水を逃がす',
            '工夫が生きれば、長く頼られる。人手と日数がかかる',
            () {
              if (g.rng.chance(.6 + g.l.chi / 400)) {
                g.l.fame += 6;
                if (r) {
                  g.l.merit += 15;
                  g.l.fav = _c(g.l.fav + 5);
                } else {
                  g.l.net += 6;
                }
                g.setFlag('tal_fushin');
                g.mark(r ? '出城の縄張りを任され、守りの堅い城を築いた' : '暴れ川の堤を工夫し、村の田を守った');
                return r
                    ? '城は堅く仕上がった。攻め手が見上げて溜め息をつくだろう。'
                    : '翌年の大水で、田はひとつも流されなかった。';
              }
              g.l.sei = _c(g.l.sei + 1);
              return '工夫はしたが、思うようには仕上がらなかった。';
            },
          ),
          Choice.h('昔からのやり方に従う', '無難に済む', () => '昔ながらのやり方で、手を入れた。'),
        ],
        after: next,
      );
    },
  ),

  SceneDef(
    'tal_chi_gunshi',
    25,
    65,
    (g) => 5,
    (g) =>
        g.l.chi >= 90 &&
        g.canFight &&
        g.active &&
        !_monk(g) &&
        g.l.rank < 6 &&
        g.alive.length >= 3,
    (g, next) {
      final l = g.l;
      final others = g.alive.where((f) => f.name != l.lord).toList();
      final near = l.lord != null
          ? nearest(others, (f) => f.name, faction: l.lord, n: 3)
          : nearest(others, (f) => f.name, region: l.region, n: 3);
      final to = g.rng.pick(near);
      final toName = houseName(g, to.name);
      g.ask('軍師の招き', '$toName家から使いが来た。「当家の軍師として、お迎えしたい」。知恵者の噂を聞いたのだという。', [
        Choice.h(
          '招きに応じる',
          '重く用いられる。${l.lord != null ? '今の主家には裏切りと見られる' : '身分を得る'}',
          () {
            final had = l.lord;
            l.lord = to.name;
            l.rank = l.rank < 4 ? 4 : l.rank;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.fav = 45;
            l.merit += 20;
            l.ronin = false;
            l.fame += 10;
            g.setFlag('tal_gunshi');
            if (had != null) g.setFlag('tal_left_lord');
            g.mark('$toName家に軍師として招かれた');
            return '$toName家の陣で、軍配を預けられた。';
          },
        ),
        Choice.h(
          '今の${l.lord != null ? '主家' : '暮らし'}にとどまる',
          l.lord != null ? '主君の信頼は深まる' : '静かに暮らせる',
          () {
            if (l.lord != null) {
              l.fav = _c(l.fav + 10);
              return '招きを断ったと知った殿が、自ら盃を注いでくれた。';
            }
            g.j(3);
            return '使いには丁重に帰ってもらった。';
          },
        ),
        Choice.h('世を離れて書を著す', '名は後の世に残るかもしれない。出世の道は閉じる', () {
          l.chi = _c(l.chi + 2);
          g.j(6);
          g.setFlag('tal_wrote_book');
          g.mark('招きを断り、兵法の書を著した');
          return '筆をとり、見聞きした戦の理を書き留めはじめた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------ 政
  SceneDef(
    'tal_sei_nengu',
    18,
    55,
    (g) => 4,
    (g) => g.l.sei >= 60 && _retainer(g),
    (g, next) {
      // 男は年貢の帳面、奥で仕える女は奥の台所の掛かりの帳面。
      final f = g.l.female && !g.canFight;
      final who = f ? '台所を預かる女中' : '代官';
      final up = f ? '老女さま' : '殿';
      g.ask(
        '帳尻',
        f
            ? '奥の掛かりの帳面を見ていて、台所の米と油の出入りだけ、毎月わずかに数が合わないことに気づいた。'
            : '年貢の帳面を見ていて、ある代官の村だけ、毎年わずかに数が合わないことに気づいた。',
        [
          Choice.h('$upに申し上げる', '主君の信頼が増す。$whoには恨まれる', () {
            if (!f && g.rng.chance(.05)) {
              g.die('代官の不正を訴え出たのち、何者かに襲われた', 'ansatsu');
              return '訴え出た夜、帰り道で襲われた。';
            }
            g.l.fav = _c(g.l.fav + 10);
            g.l.merit += 10;
            g.setFlag('tal_exposed_fraud');
            g.mark('$whoのごまかしを見抜き、$upに申し上げた');
            return f
                ? '女中は暇を出された。奥の掛かりが、ひと月で目に見えて減った。'
                : '代官は役を解かれた。村の者たちから、礼の餅が届いた。';
          }),
          Choice.h('$whoに詰め寄って返させる', '穏便に済む。不正は表に出ない', () {
            g.l.net += 2;
            g.l.sei = _c(g.l.sei + 1);
            return '$whoは青い顔で、ごまかした分を蔵に戻した。';
          }),
          Choice.h('分け前をもらって黙る', '懐は潤う。露見すれば身の破滅だ', () {
            g.l.gold += f ? 8 : 15;
            g.j(-5);
            g.setFlag('tal_bribe');
            return '$whoは、にやりと笑って銭の包みを差し出した。';
          }),
        ],
        after: next,
      );
    },
  ),

  SceneDef(
    'tal_sei_sabaki',
    20,
    65,
    (g) => 4,
    (g) => g.l.sei >= 60 && g.active && !_outlaw(g),
    (g, next) {
      final place = _monk(g)
          ? '寺の門前の二つの村'
          : (_merchant(g)
                ? '町の二つの座'
                : (g.l.rank >= 1 && g.canFight
                      ? '知行地の二つの村'
                      : (g.l.rank >= 1 ? '城下の二つの町' : '隣り合う二つの村')));
      g.ask('裁き', '$placeが境目を争い、どちらもあなたに裁いてほしいと言ってきた。', [
        Choice.h('双方の言い分を聞いて間を取る', '両方に恩を売れる。時間がかかる', () {
          g.l.net += 5;
          g.l.mi = _c(g.l.mi + 1);
          g.setFlag('tal_judge');
          g.mark('$placeの争いを、間を取って裁いた');
          return '三日かけて話を聞き、境に石を置いた。双方が渋々ながら頷いた。';
        }),
        Choice.h('古い証文に従う', '筋は通る。負けた側は恨む', () {
          g.l.sei = _c(g.l.sei + 2);
          g.l.fame += 3;
          return '古い証文を読み上げ、そのとおりに裁いた。';
        }),
        Choice.h('力のある側につく', '礼の品が届く。弱い側の恨みは深い', () {
          g.l.gold += 10;
          g.j(-4);
          return '力のある村が勝った。負けた村の老人が、じっとこちらを見ていた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_sei_machi',
    22,
    65,
    (g) => 4,
    (g) => g.l.sei >= 75 && _merchant(g) && g.active,
    (g, next) {
      g.ask('町の年寄', '町の年寄の一人が亡くなり、後を継いでほしいという話が来た。町の掟や揉め事を預かる役だ。', [
        Choice.h('年寄を引き受ける', '町での重みが増す。商いの時間は減る', () {
          g.l.net += 6;
          g.l.fame += 5;
          g.setFlag('tal_machi_toshiyori');
          g.mark('町の年寄に推され、町の差配を預かった');
          return '町の寄合で、上座に座ることになった。';
        }),
        Choice.h('商いに専念する', '身軽なままでいられる', () {
          g.l.gold += 6;
          return '「まだ若輩ゆえ」と辞退した。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_sei_bugyo',
    22,
    60,
    (g) => 4,
    (g) => g.l.sei >= 75 && _samurai(g),
    (g, next) {
      g.ask('奉行の推挙', '算用に明るいと見込まれ、${_house(g)}家の奉行に推す声が上がっている。', [
        Choice.h('奉行を引き受ける', '家中で重く用いられる。戦場の手柄は遠のく', () {
          g.l.merit += 15;
          g.l.fav = _c(g.l.fav + 8);
          g.l.sei = _c(g.l.sei + 1);
          g.setFlag('tal_bugyo');
          g.mark('${_house(g)}家の奉行に任じられた');
          return '奉行として、城下の米と銭の出入りを預かることになった。';
        }),
        Choice.h('同輩に譲る', '同輩に恩が売れる', () {
          g.l.net += 5;
          return '「あの者のほうが向いております」と、同輩を推した。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_sei_kenchi',
    25,
    60,
    (g) => 5,
    (g) => g.l.sei >= 90 && _samurai(g),
    (g, next) {
      g.ask(
        '検地',
        '${_house(g)}家の領内の検地を、あなたが差配することになった。田を測り直せば年貢は増えるが、村は苦しくなる。',
        [
          Choice.h('一筆ずつ厳しく測る', '主家は富む。村には恨まれる', () {
            g.l.fav = _c(g.l.fav + 12);
            g.l.merit += 20;
            g.j(-4);
            final f = g.fa[g.l.lord];
            if (f != null) f.power += 1;
            g.setFlag('tal_kenchi');
            g.mark('${_house(g)}家の検地を差配し、隠し田を残らず改めた');
            return '隠し田が次々と見つかった。蔵が満ちた。';
          }),
          Choice.h('村の事情を汲んで測る', '村に慕われる。主君は物足りなく思う', () {
            g.l.net += 6;
            g.l.fav = _c(g.l.fav - 3);
            g.j(4);
            return '痩せ地は痩せ地として記した。村の長が、深く頭を下げた。';
          }),
          Choice.h('新田を開かせて年貢を増やす', '双方が立つ。手間は倍かかる', () {
            if (g.rng.chance(.5 + g.l.sei / 400)) {
              g.l.fav = _c(g.l.fav + 8);
              g.l.net += 4;
              g.l.merit += 15;
              g.setFlag('tal_kenchi');
              g.mark('検地のかわりに新田を開かせ、主家と村の双方を立てた');
              return '三年のうちに、新しい田が広がった。';
            }
            g.l.fav = _c(g.l.fav - 4);
            return '新田は思うように実らず、殿は眉をひそめた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ------------------------------------------------------------------ 魅
  SceneDef(
    'tal_mi_hitotsudoi',
    16,
    50,
    (g) => 4,
    (g) => g.l.mi >= 60 && g.active && !_monk(g),
    (g, next) {
      final l = g.l;
      if (!l.married) {
        final names = l.female ? kGivenM : kGivenF;
        final ga = g.rng.pick(names);
        final a = '${l.rank >= 1 ? '${g.rng.pick(kSurnames)}家の' : ''}$ga';
        final b = g.rng.pick(names.where((n) => n != ga).toList());
        g.ask(
          '縁談が重なる',
          '人好きのする人柄の噂が広まり、縁談が一度に三つも舞い込んだ。中でも、$aとの話と、幼い頃から知る$bとの話が気にかかる。',
          [
            Choice.h('$aとの話を受ける', '家どうしの縁ができる。気心は知れない', () {
              l.married = true;
              l.net += 5;
              l.gold += 8 + l.rank * 4;
              g.j(6);
              g.meet('伴侶', a, 45);
              g.mark('$aと夫婦になった');
              return '$aと夫婦になった。';
            }),
            Choice.h('$bとの話を受ける', '気心が知れている。家の得にはならない', () {
              l.married = true;
              g.j(12);
              g.meet('伴侶', b, 65);
              g.mark('幼い頃から知る$bと夫婦になった');
              return '$bと夫婦になった。照れくさそうに笑っていた。';
            }),
            Choice.h('どれも断る', '身軽なままでいられる。仲人の顔はつぶれる', () {
              l.net = l.net >= 2 ? l.net - 2 : 0;
              return '三つとも断った。';
            }),
          ],
          after: next,
        );
        return;
      }
      g.ask('人が集まる', '家に、何かと人が訪ねてくるようになった。今夜も、相談事を抱えた者が三人、戸口で待っている。', [
        Choice.h('夜更けまで話を聞く', '頼りにされる。体は休まらない', () {
          l.net += 6;
          _hurt(g, 5);
          g.setFlag('tal_many_friends');
          return '酒を出し、一人ずつ話を聞いた。帰るときには皆、晴れた顔をしていた。';
        }),
        Choice.h('家族との時を守る', '心は休まる', () {
          g.j(5);
          return '「また明日」と帰ってもらった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_mi_chorayaku',
    22,
    55,
    (g) => 4,
    (g) => g.l.mi >= 75 && g.canFight && !g.l.female && _retainer(g),
    (g, next) {
      g.ask('調略の使い', '敵方の城将を味方に引き入れたい。人をそらさぬ者として、殿があなたを使いに選んだ。', [
        Choice.h('敵の城へ乗り込んで説く', '成れば大手柄。敵の城で捕らえられれば命はない', () {
          if (g.rng.chance(.1)) {
            g.die('調略に赴いた敵の城で捕らえられ、斬られた', 'seppuku');
            return '城門が閉ざされた。城将は、はじめから会う気などなかった。';
          }
          if (g.rng.chance(.45 + g.l.mi / 250)) {
            g.l.merit += 30;
            g.l.fav = _c(g.l.fav + 10);
            g.l.fame += 8;
            g.setFlag('tal_chorayaku');
            g.mark('敵の城将を説き伏せ、城ごと味方に引き入れた');
            return '一晩、膝をつき合わせて語った。翌朝、城に味方の旗が立った。';
          }
          g.l.fav = _c(g.l.fav - 3);
          return '話は聞いてもらえたが、城将は首を縦に振らなかった。';
        }),
        Choice.h('書状だけで誘う', '危うさは少ない。心は動きにくい', () {
          if (g.rng.chance(.3)) {
            g.l.merit += 12;
            return '返書が来た。「時が来れば」とあった。';
          }
          return '返書は来なかった。';
        }),
        Choice.h('辞退する', '殿の期待を裏切る', () {
          g.l.fav = _c(g.l.fav - 6);
          return '「それがしには荷が重うございます」と断った。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_mi_ikki',
    18,
    55,
    (g) => 4,
    (g) => g.l.mi >= 75 && _villager(g),
    (g, next) {
      g.ask('一揆の頭', '年貢の取り立てが厳しく、村々が一揆を起こそうとしている。皆が「頭に立つのはあなたしかいない」と言う。', [
        Choice.h('頭に立つ', '年貢が下がるかもしれない。しくじれば磔だ', () {
          if (g.rng.chance(.22)) {
            g.die('一揆の頭として捕らえられ、処刑された', 'seppuku');
            return '一揆は鎮められた。頭として、あなた一人が罪を負った。';
          }
          g.l.fame += 10;
          g.l.net += 8;
          g.setFlag('tal_ikki_head');
          g.mark('一揆の頭に担がれ、年貢を下げさせた');
          return '村々が鍬を手に城下へ押しかけた。年貢は下げられた。';
        }),
        Choice.h('訴状を届ける役だけ引き受ける', '穏やかに訴えられる。聞き届けられるかは分からない', () {
          if (g.rng.chance(.4)) {
            g.l.net += 4;
            return '訴状は聞き届けられ、年貢がわずかに下がった。';
          }
          _hurt(g, 8);
          return '代官の屋敷で門前払いされ、棒で打たれた。';
        }),
        Choice.h('断る', '身は守れる。村での顔はつぶれる', () {
          g.l.net = g.l.net >= 4 ? g.l.net - 4 : 0;
          g.j(-3);
          return '黙って首を振った。村の者たちの目が冷たくなった。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_mi_chouai',
    18,
    40,
    (g) => 4,
    (g) => g.l.mi >= 75 && _retainer(g) && !g.hasFlag('sokushitsu'),
    (g, next) {
      final f = g.l.female;
      g.ask(
        '殿の覚え',
        f
            ? '${_house(g)}家の奥方さまが、あなたの気配りをいたく気に入られた。殿への取り次ぎを任せたいという。'
            : '${_house(g)}家の殿が、あなたの人柄を気に入り、近習としてそばに置きたいと仰せだ。',
        [
          Choice.h(f ? '取り次ぎ役を務める' : '近習として仕える', '殿の信頼は厚くなる。同輩の妬みを買う', () {
            g.l.fav = _c(g.l.fav + 15);
            g.l.merit += 10;
            g.setFlag('tal_favorite');
            g.setFlag('tal_envied');
            g.mark(
              f ? '${_house(g)}家の奥で、殿への取り次ぎを任された' : '${_house(g)}家の殿の近習に召された',
            );
            return f ? '殿の御前に、たびたび上がるようになった。' : '殿の側近くに仕えることになった。朝夕に言葉をかけられる。';
          }),
          Choice.h('身を慎んで今の務めを続ける', '周りの目は穏やかなままだ', () {
            g.l.fav = _c(g.l.fav + 4);
            g.l.net += 3;
            return '「身に余るお言葉」と辞退した。かえって殿の覚えはよくなった。';
          }),
          Choice.h('同輩を推して取り立ててもらう', '同輩に深く感謝される', () {
            g.l.net += 6;
            g.l.mi = _c(g.l.mi + 1);
            g.meet(
              '朋輩',
              '${g.rng.pick(kSurnames)}${g.rng.pick(f ? kGivenF : kGivenM)}',
              60,
            );
            return '推した同輩が召された。あとで、手を取って礼を言われた。';
          }),
        ],
        after: next,
      );
    },
  ),

  SceneDef('tal_mi_uta', 20, 65, (g) => 5, (g) => g.l.mi >= 90 && g.active, (
    g,
    next,
  ) {
    g.ask('流行り歌', 'あなたのことを謡った歌が、市で流行っているという。旅の者まで口ずさんでいる。', [
      Choice.h('笑って聞き流す', '心が晴れる。名も広まる', () {
        g.l.fame += 8;
        g.j(5);
        return '子どもたちが、あなたの顔を見て歌いだした。';
      }),
      Choice.h(
        '慕う者を束ねて頼れる仲間にする',
        '人の輪が広がる。${g.l.lord != null ? '主君には怪しまれるかもしれない' : '目立ちすぎるかもしれない'}',
        () {
          g.l.net += 10;
          if (g.l.lord != null) g.l.fav = _c(g.l.fav - 5);
          g.setFlag('tal_followers');
          g.mark('慕って集まった者たちを束ね、頼れる仲間にした');
          return '集まった者たちと、盃を交わした。';
        },
      ),
      Choice.h('歌をやめさせる', '目立たずに済む。名は広まらない', () {
        g.l.fame = g.l.fame >= 3 ? g.l.fame - 3 : 0;
        return '歌い手に銭を渡し、ほかの歌を歌ってもらった。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------------ 運
  SceneDef('tal_un_find', 16, 70, (g) => 4, (g) => g.l.un >= 60 && g.active, (
    g,
    next,
  ) {
    g.ask('古道具屋', '市の古道具屋の隅で、埃をかぶった茶碗が目に留まった。どこか、ただならぬ気配がある。', [
      Choice.h('有り金をはたいて買う', '掘り出し物かもしれない。ただの古茶碗かもしれない', () {
        final pay = g.l.gold < 10 ? g.l.gold : 10;
        g.l.gold -= pay;
        if (g.rng.chance(.3 + g.l.un / 250)) {
          g.l.gold += 60;
          g.setFlag('tal_meibutsu');
          g.mark('古道具屋で、名のある茶碗を掘り出した');
          return '目利きに見せると、名のある窯の茶碗だった。高値で引き取られた。';
        }
        return 'ただの古茶碗だった。毎朝、それで白湯を飲んでいる。';
      }),
      Choice.h('見るだけにする', '銭は減らない', () => '茶碗を棚に戻した。翌日には、もう売れていた。'),
    ], after: next);
  }),

  SceneDef(
    'tal_un_purse',
    16,
    60,
    (g) => 3,
    (g) => g.l.un >= 60 && g.active && !_monk(g),
    (g, next) {
      g.ask('落とし物', '道端に、ずしりと重い財布が落ちていた。家紋の入った、上等な布の財布だ。', [
        Choice.h('紋を頼りに届ける', '礼が来るかもしれない。来ないかもしれない', () {
          if (g.rng.chance(.5)) {
            g.l.gold += 12;
            g.l.net += 3;
            g.meet('恩を受けた家', '${g.rng.pick(kSurnames)}家', 45);
            return '届け先は、ある家の用人だった。主人から丁寧な礼状と銭が届いた。';
          }
          g.l.fame += 2;
          return '届け先の門番は、礼も言わずに財布を受け取った。';
        }),
        Choice.h('懐に入れる', '銭になる。後ろめたさが残る', () {
          g.l.gold += 15;
          g.j(-4);
          return '誰にも見られていない。…はずだ。';
        }),
      ], after: next);
    },
  ),

  SceneDef('tal_un_plague', 18, 70, (g) => 4, (g) => g.l.un >= 75 && g.active, (
    g,
    next,
  ) {
    g.ask('疫病の年', '疫病が流行り、あなたも高い熱に倒れた。ところが三日で熱が引いた。周りでは、まだ多くの者が苦しんでいる。', [
      Choice.h('病人の看病に回る', '慕われる。病がぶり返すかもしれない', () {
        if (g.rng.chance(.05)) {
          g.die('疫病の看病のさなか、病がぶり返して亡くなった', 'byo');
          return '看病の五日目、再び熱が上がった。';
        }
        g.l.net += 6;
        g.l.fame += 4;
        g.j(3);
        g.setFlag('tal_nursed');
        g.mark('疫病の年、病み上がりの身で病人の看病に回った');
        return '粥を炊き、額を冷やして回った。命拾いした者たちが、何度も手を合わせた。';
      }),
      Choice.h('家に籠もって養生する', '体は守れる', () {
        g.l.hp = g.l.hp + 10 > g.l.maxhp ? g.l.maxhp : g.l.hp + 10;
        return '戸を閉めて、病が過ぎるのを待った。';
      }),
    ], after: next);
  }),

  SceneDef(
    'tal_un_arrow',
    18,
    55,
    (g) => 4,
    (g) =>
        g.l.un >= 75 &&
        g.canFight &&
        g.hasFlag('first_battle') &&
        g.active &&
        !_monk(g),
    (g, next) {
      g.ask('流れ矢', '戦場で、流れ矢が兜をかすめて後ろの木に突き立った。あと一寸ずれていれば、命はなかった。', [
        Choice.h('兜を社に奉納する', '心が落ち着く', () {
          g.l.un = _c(g.l.un + 1);
          g.j(5);
          return '戦のあと、兜を社に納めて手を合わせた。';
        }),
        Choice.h('運を頼んで前へ出る', '手柄の好機。運はいつまで続くか', () {
          if (g.rng.chance(.08)) {
            g.die('運を頼んで敵陣へ踏み込み、討たれた', 'senshi');
            return '次の矢は、逸れなかった。';
          }
          g.l.merit += 15;
          g.l.fame += 4;
          return '矢の雨の中を駆け抜け、敵の旗を奪った。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_un_bakuchi',
    16,
    55,
    (g) => 4,
    (g) =>
        g.l.un >= 75 && g.active && !_monk(g) && !(g.l.female && g.l.rank >= 1),
    (g, next) {
      g.ask('強運の噂', '「あの人の手が触れた荷は、なぜか無事に着く」。そんな噂を聞いた商人が、荒れる季節に出す大口の荷の差配を任せたいと言ってきた。蓄えを荷に乗せれば、儲けを分けるとも言う。', [
        Choice.h('差配を引き受け、蓄えも荷に乗せる', '荷が着けば一財産。沈めば、乗せた蓄えは海の底だ', () {
          if (g.rng.chance(.3 + g.l.un / 300)) {
            g.l.gold += 50;
            g.setFlag('tal_big_win');
            g.mark('強運を見込まれて大口の荷を任され、一財産を得た');
            return '荷は嵐の合間を縫って着いた。商人は、震える手で儲けを分けてよこした。';
          }
          g.l.gold = g.l.gold ~/ 2;
          g.j(-8);
          return '荷を積んだ船は、沖で嵐に呑まれた。乗せた蓄えも、海の底へ消えた。';
        }),
        Choice.h('差配だけ引き受け、礼を受け取る', '手堅く稼げる', () {
          g.l.gold += 10;
          return '荷のことは船頭に任せ、差配の礼だけを懐に帰った。';
        }),
        Choice.h('縁起物扱いは御免だと、笑って断る', '心は軽い', () {
          g.l.gold += 2;
          g.j(5);
          g.l.un = _c(g.l.un + 1);
          return '「運は、借り物ではござらぬ」と断った。商人は苦笑して、手土産だけ置いていった。';
        }),
      ], after: next);
    },
  ),

  SceneDef('tal_un_ship', 20, 70, (g) => 5, (g) => g.l.un >= 90 && g.active, (
    g,
    next,
  ) {
    g.ask('沈んだ船', '乗るはずだった船が、寝過ごして乗り遅れた。その船は、沖で嵐に遭って沈んだという。', [
      Choice.h('社を建てて神仏に感謝する', '銭はかかる。心は晴れる', () {
        g.l.gold = g.l.gold >= 10 ? g.l.gold - 10 : 0;
        g.j(8);
        g.l.fame += 4;
        g.setFlag('tal_shrine');
        g.mark('沈んだ船に乗り遅れて命拾いし、小さな社を建てた');
        return '浜に小さな社を建てた。人々は「強運の社」と呼んで参るようになった。';
      }),
      Choice.h('沈んだ船の家族を見舞う', '人の縁が深まる', () {
        g.l.net += 5;
        g.l.mi = _c(g.l.mi + 1);
        return '船乗りの家々を回って、手を合わせた。';
      }),
      Choice.h('誰にも話さない', '何も変わらない', () => '寝過ごした朝のことは、胸にしまった。'),
    ], after: next);
  }),

  // ------------------------------------------------------------ 組み合わせ
  SceneDef(
    'tal_combo_yasyu',
    22,
    55,
    (g) => 5,
    (g) =>
        g.l.bu >= 70 &&
        g.l.chi >= 70 &&
        g.canFight &&
        _retainer(g) &&
        g.hasFlag('first_battle'),
    (g, next) {
      g.ask('別働隊', '腕も知恵も立つと見込まれ、殿から別働隊を預けられた。敵の背後へ回る山道は険しい。', [
        Choice.h('夜襲を仕掛ける', '成れば戦の勝ちを決める。敵中で孤立すれば命はない', () {
          if (g.rng.chance(.1)) {
            g.die('別働隊を率いて夜襲をかけ、敵中で討たれた', 'senshi');
            return '山を下りたところで、待ち伏せに遭った。';
          }
          g.l.merit += 35;
          g.l.fame += 12;
          g.l.fav = _c(g.l.fav + 8);
          g.setFlag('tal_night_raid');
          g.mark('別働隊を率いて敵の本陣に夜襲をかけ、戦の勝ちを決めた');
          return '敵の本陣に火を放った。夜明けには、敵は総崩れになっていた。';
        }),
        Choice.h('山の上に旗を立てて敵を惑わす', '手堅い働きになる', () {
          g.l.merit += 15;
          g.l.chi = _c(g.l.chi + 1);
          return '山の上の旗を見て、敵は兵を分けた。本隊がその隙を突いた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_combo_machiwari',
    22,
    60,
    (g) => 5,
    (g) => g.l.chi >= 70 && g.l.sei >= 70 && (_samurai(g) || _merchant(g)),
    (g, next) {
      final r = _samurai(g);
      g.ask(
        '町割り',
        r
            ? '${_house(g)}家の城下を広げることになり、町割りの差配を命じられた。'
            : '町に大火があり、焼け跡の町割りを考えてほしいと、町の衆に頼まれた。',
        [
          Choice.h('市を開き、商人を呼び込む町にする', '町が栄える。古い座の者は嫌がる', () {
            g.l.fame += 8;
            if (r) {
              g.l.merit += 20;
              g.l.fav = _c(g.l.fav + 6);
            } else {
              g.l.gold += 20;
              g.l.net += 4;
            }
            g.setFlag('tal_machiwari');
            g.mark(r ? '${_house(g)}家の城下の町割りを差配し、市を開いた' : '大火の焼け跡に、新しい町割りを引いた');
            return '道を広げ、市の日を定めた。一年もせぬうちに、町はにぎわいはじめた。';
          }),
          Choice.h('火に強い町にする', '堅実だ。にぎわいは後回しになる', () {
            g.l.net += 4;
            g.l.sei = _c(g.l.sei + 1);
            return '辻ごとに水の溜めを置き、家の間をあけた。';
          }),
        ],
        after: next,
      );
    },
  ),

  SceneDef(
    'tal_combo_shisha',
    22,
    60,
    (g) => 5,
    (g) => g.l.mi >= 70 && g.l.sei >= 70 && _samurai(g) && g.alive.length >= 3,
    (g, next) {
      final others = g.alive.where((f) => f.name != g.l.lord).toList();
      final to = g.rng.pick(
        nearest(others, (f) => f.name, faction: g.l.lord, n: 3),
      );
      final toName = houseName(g, to.name);
      g.ask('同盟の使者', '${_house(g)}家と$toName家とで、手を結ぶ話が持ち上がった。あなたが使者に選ばれた。', [
        Choice.h('婚姻の約定まで取りつける', '成れば大きな手柄。欲張れば話が壊れる', () {
          if (g.rng.chance(.4 + (g.l.mi + g.l.sei) / 600)) {
            g.l.merit += 30;
            g.l.fav = _c(g.l.fav + 10);
            g.l.fame += 8;
            g.setFlag('tal_alliance');
            g.mark('使者として$toName家に赴き、婚姻の約定まで取りつけた');
            return '両家の縁組まで決めて帰った。殿が自ら門まで出迎えた。';
          }
          g.l.fav = _c(g.l.fav - 6);
          return '話を急ぎすぎた。$toName家の重臣が顔をしかめ、席を立った。';
        }),
        Choice.h('誠意だけを伝える', '話はゆっくり進む', () {
          g.l.merit += 10;
          g.l.net += 3;
          return '贈り物を届け、殿の言葉を伝えた。$toName家の主が、静かに頷いた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_combo_jinbo',
    22,
    55,
    (g) => 5,
    (g) =>
        g.l.bu >= 70 &&
        g.l.mi >= 70 &&
        g.canFight &&
        _retainer(g) &&
        g.l.rank >= 2,
    (g, next) {
      g.ask('慕い寄る兵', '腕が立ち、面倒見のよいあなたの下で戦いたいと、兵が自ら集まってくる。', [
        Choice.h('皆を引き受ける', '兵が増える。養う銭がかかる', () {
          g.l.troops += 20;
          g.l.gold = g.l.gold >= 10 ? g.l.gold - 10 : 0;
          g.setFlag('tal_beloved_captain');
          g.mark('慕って集まった兵を引き受け、一隊を率いた');
          return '集まった兵たちと、一人ずつ盃を交わした。';
        }),
        Choice.h('殿の直臣に推す', '主君の信頼が増す', () {
          g.l.fav = _c(g.l.fav + 8);
          return '兵たちを殿に引き合わせた。殿は「よい者を育てた」と笑った。';
        }),
        Choice.h('同輩の組に分ける', '家中がまとまる', () {
          g.l.net += 6;
          return '手の足りない同輩の組に、兵を分けた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------ 低い能力
  SceneDef(
    'tal_low_jinpu',
    16,
    45,
    (g) => 4,
    (g) => g.l.bu < 25 && !g.l.female && _villager(g),
    (g, next) {
      g.ask('陣触れ', '領主の陣触れで、村から人足を出すことになった。腕に覚えのない者から先に、荷運びに駆り出されるという。', [
        Choice.h('陣夫として荷を担ぐ', '手間賃が出る。流れ矢が飛んでくるかもしれない', () {
          if (g.rng.chance(.06)) {
            g.die('陣夫として戦場へ駆り出され、流れ矢に当たった', 'senshi');
            return '荷を下ろしたところへ、矢が飛んできた。';
          }
          g.l.gold += 4;
          g.l.bu = _c(g.l.bu + 2);
          g.setFlag('tal_jinpu');
          return '米俵を担いで、戦場の後ろを行き来した。遠くで鬨の声が聞こえた。';
        }),
        Choice.h('銭を出して代わりを立てる', '身は無事だ。銭がかかる', () {
          g.l.gold = g.l.gold >= 6 ? g.l.gold - 6 : 0;
          return '隣村の若者に銭を渡して、代わりに行ってもらった。';
        }),
        Choice.h('山へ隠れる', '見つかれば罰を受ける', () {
          if (g.rng.chance(.4)) {
            _hurt(g, 10);
            g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
            return '見つかって引き立てられ、さんざん打たれた。';
          }
          return '三日、山の洞に隠れていた。';
        }),
      ], after: next);
    },
  ),

  SceneDef(
    'tal_low_shomon',
    18,
    60,
    (g) => 4,
    (g) => g.l.chi < 25 && g.active && (_commoner(g) || _merchant(g)),
    (g, next) {
      g.ask('証文', '金貸しが、借りた銭の証文に判を押せと言う。字はよく読めないが、どうも口で聞いた話より長い。', [
        Choice.h('言われるまま判を押す', '話は早い。何が書いてあるかは分からない', () {
          g.l.gold = g.l.gold >= 15 ? g.l.gold - 15 : 0;
          g.j(-5);
          g.setFlag('tal_cheated');
          return '利息が倍になる一文が入っていた。気づいたときには遅かった。';
        }),
        Choice.h('字の読める者に読んでもらう', '騙されずに済む。礼がいる', () {
          g.l.gold = g.l.gold >= 1 ? g.l.gold - 1 : 0;
          g.l.chi = _c(g.l.chi + 2);
          g.setFlag('tal_read_deed');
          return '寺の小坊主に読んでもらうと、余計な一文があった。突き返した。';
        }),
        Choice.h('判を押さずに帰る', '銭は借りられない', () {
          return '金貸しの舌打ちを背に、帰ってきた。';
        }),
      ], after: next);
    },
  ),

  SceneDef('tal_low_yaku', 16, 60, (g) => 3, (g) => g.l.un < 20 && g.active, (
    g,
    next,
  ) {
    g.ask('厄', '屋根が抜け、飼っていた鶏が狐に取られ、足をくじいた。悪いことが続く。「厄が憑いている」と人が言う。', [
      Choice.h('厄払いの祈祷を頼む', '銭はかかる。気は晴れる', () {
        g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
        g.l.un = _c(g.l.un + 4);
        g.j(4);
        return '祈祷のあと、なぜか少しずつ物事がうまく回りはじめた。';
      }),
      Choice.h('気にせず働く', '運に頼らない。身にはつく', () {
        g.l.sei = _c(g.l.sei + 1);
        g.l.bu = _c(g.l.bu + 1);
        g.j(-2);
        return '屋根を自分で葺き直した。腕は上がった。';
      }),
    ], after: next);
  }),
];

// ======================================================================
// 幼少期の岐路
// ======================================================================

const _martialKids = [
  'ronin',
  'ashigaru',
  'lowsamurai',
  'samurai',
  'kokujin',
  'daimyo',
];

List<SceneDef> buildTalentChildScenes() => [
  SceneDef('tal_c_sumo', 8, 14, (g) => 3, (g) => g.l.bu >= 55 && !g.l.female, (
    g,
    next,
  ) {
    g.ask(
      '祭りの相撲',
      '祭りの子ども相撲で、勝ち進んだ。最後の相手は、${_martialKids.contains(g.l.cls.id) ? '上役の家の息子' : '庄屋の息子'}だ。周りの大人たちが、なぜか目配せしている。',
      [
        Choice.h('本気で投げる', '勝てば力自慢と認められる。相手の親は面白くない', () {
          g.l.bu = _c(g.l.bu + 2);
          g.l.fame += 2;
          g.setFlag('tal_c_sumo_win');
          g.mark('祭りの子ども相撲で、年上の子を投げ飛ばして勝った');
          return '相手を土俵の外へ投げ飛ばした。見物の衆がどっと沸いた。';
        }),
        Choice.h('わざと負ける', '大人たちは胸をなで下ろす', () {
          g.l.net += 2;
          g.l.mi = _c(g.l.mi + 1);
          return '紙一重で負けてみせた。あとで、庄屋の家から餅が届いた。';
        }),
      ],
      after: next,
    );
  }),

  SceneDef(
    'tal_c_uma',
    10,
    14,
    (g) => 3,
    (g) => g.l.bu >= 55 && _martialKids.contains(g.l.cls.id),
    (g, next) {
      g.ask('暴れ馬', '厩から馬が逃げ出し、通りを暴れ回っている。その先には、幼い子が立ちすくんでいる。', [
        Choice.h('轡に飛びつく', '子は助かるかもしれない。蹴られれば大怪我だ', () {
          if (g.rng.chance(.6)) {
            g.l.bu = _c(g.l.bu + 2);
            g.l.fame += 3;
            g.setFlag('tal_c_horse');
            g.mark('暴れ馬の轡に飛びつき、幼い子を救った');
            return '轡にしがみつき、馬を止めた。大人たちが目を丸くした。';
          }
          _hurt(g, 18);
          return '蹴り飛ばされ、しばらく起き上がれなかった。子は、大人が抱きかかえて逃げた。';
        }),
        Choice.h('大声で大人を呼ぶ', '身は無事だ', () {
          g.l.net += 1;
          return '大人たちが駆けつけ、馬を取り押さえた。';
        }),
      ], after: next);
    },
  ),

  SceneDef('tal_c_kosatsu', 7, 14, (g) => 3, (g) => g.l.chi >= 55, (g, next) {
    g.ask('辻の高札', '辻に新しい高札が立った。字の読めない大人たちが、首をひねって見上げている。あなたには、すらすら読める。', [
      Choice.h('声に出して読み上げる', '大人たちに感心される。役人の耳にも入るかもしれない', () {
        g.l.chi = _c(g.l.chi + 2);
        g.l.fame += 2;
        g.l.net += 2;
        g.setFlag('tal_c_read_sign');
        g.mark('辻の高札を、大人たちに読んで聞かせた');
        return '読み終えると、大人たちがどよめいた。通りがかった役人が、こちらを振り返った。';
      }),
      Choice.h('親にだけ、そっと教える', '目立たずに済む', () {
        g.l.chi = _c(g.l.chi + 1);
        return '親は、あなたの顔をまじまじと見た。';
      }),
    ], after: next);
  }),

  SceneDef('tal_c_kuchi', 8, 14, (g) => 3, (g) => g.l.mi >= 55, (g, next) {
    g.ask('大人の喧嘩', '水路の水の分け方で、大人たちが鍬を振り上げて言い争っている。誰も止められない。', [
      Choice.h('間に割って入る', '収まるかもしれない。子どもが口を出すなと叱られるかもしれない', () {
        if (g.rng.chance(.6)) {
          g.l.mi = _c(g.l.mi + 2);
          g.l.net += 3;
          g.setFlag('tal_c_peacemaker');
          g.mark('大人たちの喧嘩に割って入り、笑わせて収めた');
          return '「みんなの田に水が来ないと、おらの飯も減る」と言うと、大人たちが吹き出した。';
        }
        return '「子どもは引っ込んでおれ」と叱られた。';
      }),
      Choice.h('長老を呼びに走る', '確かに収まる', () {
        g.l.net += 1;
        return '長老が来ると、大人たちは黙った。';
      }),
    ], after: next);
  }),

  SceneDef('tal_c_soroban', 9, 14, (g) => 3, (g) => g.l.sei >= 55, (g, next) {
    g.ask('市の勘定', '親と市に行くと、商人が釣り銭を数えている。どうも、数文足りない気がする。', [
      Choice.h('その場で言う', '銭は戻る。商人は嫌な顔をする', () {
        g.l.sei = _c(g.l.sei + 2);
        g.l.gold += 1;
        g.setFlag('tal_c_sharp');
        return '指を折って数えてみせると、商人は苦笑して銭を足した。「末は勘定奉行だ」';
      }),
      Choice.h('あとで親にそっと告げる', '角は立たない', () {
        g.l.sei = _c(g.l.sei + 1);
        return '親は驚いて、頭を撫でてくれた。';
      }),
    ], after: next);
  }),

  SceneDef('tal_c_shika', 5, 12, (g) => 3, (g) => g.l.un >= 55, (g, next) {
    g.ask('白い鹿', '山で道に迷い、日が暮れかけた。ふと見ると、白い鹿がこちらを振り返っている。', [
      Choice.h('鹿のあとをついていく', '不思議なことが起きるかもしれない', () {
        g.l.un = _c(g.l.un + 2);
        g.l.gold += 2;
        g.setFlag('tal_c_white_deer');
        g.mark('山で迷い、白い鹿に導かれて帰った');
        return '鹿のあとを行くと、見慣れた道に出た。足もとに、古い銭が何枚も落ちていた。';
      }),
      Choice.h('来た道を引き返す', '確かだが、夜道は寒い', () {
        _hurt(g, 6);
        return '夜更けに、泣きながら家にたどり着いた。';
      }),
    ], after: next);
  }),
];
