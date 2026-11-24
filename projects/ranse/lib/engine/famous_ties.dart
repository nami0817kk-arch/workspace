import 'childhood.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 有名人との縁を続ける（2026-11-25、ユーザーが決めた項目「有名人との縁を続ける」）。id・旗は `ft_`。
///
/// 信長・秀吉・家康・謙信・信玄・政宗とは、史実の年に一度出会うだけの場面が多かった。出会った人とは、
/// その後も節目で再会する筋を足した:
/// - 節目（`ft_<人>_fushime`）: 仕えている人なら祝いの席で言葉を賜る、縁のある人なら祝いに出向く。
///   信長は安土の天主（1576〜79）・秀吉は関白（1585〜88）・家康は征夷大将軍（1603〜05）・謙信は関東管領と上杉の名（1561〜63）・
///   信玄は西上の陣触れ（1571〜72。武田に仕える侍大将から）・政宗は仙台の町開き（1601〜04）。
/// - 敵になる（`ft_<人>_teki`）: 縁のある人が、別の家に仕えるあなたに文をよこす。破って戦うか、寝返るか、懐にしまうか。
/// - 最期を聞く・見送る（`ft_<人>_saigo`）: 没した年と翌年。仕えていれば見送り、縁があれば弔い、見ただけでも噂を聞く。
/// どの人とどれだけ縁があるかは、縁のある人（`Life.people` の名）と歩んだ道の文（`Life.path`）から読む（[ftMet]）。
/// 没年と世界線は必ず見る（[ftDeathYear]。今川の世では信長・謙信・信玄の筋は出さない。秀吉と政宗は史実と西軍の世、
/// 家康の最期と将軍は史実の世だけ）。同じ出来事を描く史実の岐路（太閤の死 `h_hideyoshi_death`・信長の最期 `h_x_nobunaga_end`・
/// 鶴岡八幡宮 `h_e_tsurugaoka`）を見た人には出さない。史実として自信のない話は「〜と伝わる」「〜という」に寄せた。
/// 人の命は奪わない（`die` はない）。

class _Famous {
  const _Famous({
    required this.key,
    required this.name,
    required this.short,
    required this.house,
    required this.closeNames,
    required this.closePaths,
    required this.seenPaths,
  });
  final String key;

  /// 縁のある人に残る名（`personDied` の表と同じ）。
  final String name;

  /// 文の中の呼び名。
  final String short;

  /// 勢力の内部の名。
  final String house;

  /// 縁のある人の名（どの役割でも）。
  final List<String> closeNames;

  /// 親しく言葉を交わした・仕えた・命を救ったなどの、歩んだ道の文の一部。
  final List<String> closePaths;

  /// 見た・噂を聞いた・敵として向き合ったなどの、歩んだ道の文の一部。
  final List<String> seenPaths;
}

const _people = <_Famous>[
  _Famous(
    key: 'nobunaga',
    name: '織田信長',
    short: '信長',
    house: '織田',
    closeNames: ['織田信長', '吉法師'],
    closePaths: [
      '吉法師と野で遊んだ',
      '信長に、幼き日の縁',
      '織田信長に仕えた',
      '信長の誘いを断った',
      '信長を救い出した',
      '信長に急を知らせて命を救った',
      '桶狭間で信長に従い',
      '信長の命を救い',
    ],
    seenPaths: [
      '尾張の若殿を、遠くから見た',
      '信長の上洛の行列を',
      '抹香を投げた信長',
      '京に入る織田信長の軍勢を見た',
      '信長の矢銭を拒んだ',
      '信長に従うよう説いた',
      '安土の天主を見上げた',
      '安土の宗論',
    ],
  ),
  _Famous(
    key: 'hideyoshi',
    name: '羽柴秀吉',
    short: '秀吉',
    house: '織田',
    closeNames: ['羽柴秀吉', '木下藤吉郎'],
    closePaths: ['木下藤吉郎と親しくなった', '羽柴秀吉に仕えた', '秀吉の前に出た'],
    seenPaths: [
      '秀吉に従い光秀を討った',
      '秀吉の開いた長浜の町',
      '秀吉の推す三法師',
      '秀吉を追えと説いた',
      '秀吉の軍勢に近道を案内した',
      '高野山が秀吉に降った',
    ],
  ),
  _Famous(
    key: 'ieyasu',
    name: '徳川家康',
    short: '家康',
    house: '松平',
    closeNames: ['徳川家康', '松平竹千代', '竹千代'],
    closePaths: [
      '竹千代（のちの徳川家康）と言葉を交わした',
      '竹千代（のちの徳川家康）に手を振った',
      '徳川家康に仕えた',
      '家康の身代わり',
      '敗走する家康を守って',
      '家康の伊賀越え',
      '若き日の徳川家康を、門前で迎えた',
      '家康のもとで戦った',
    ],
    seenPaths: ['竹千代の行列を見た', '家康の関東移封に従い'],
  ),
  _Famous(
    key: 'kenshin',
    name: '長尾景虎',
    short: '謙信',
    house: '上杉',
    closeNames: ['長尾景虎'],
    closePaths: ['寺に預けられた少年と言葉を交わした', '長尾景虎に仕えた', '謙信とともに本陣へ斬り込み'],
    seenPaths: [
      '上杉謙信の関東管領就任',
      '上杉謙信が送った塩',
      '信玄と謙信の一騎打ちを間近に見た',
      '長尾景虎の小田原攻め',
    ],
  ),
  _Famous(
    key: 'shingen',
    name: '武田信玄',
    short: '信玄',
    house: '武田',
    closeNames: ['武田信玄'],
    closePaths: [],
    seenPaths: ['信玄と謙信の一騎打ちを間近に見た', '武田信玄の命で、釜無川の堤'],
  ),
  _Famous(
    key: 'masamune',
    name: '伊達政宗',
    short: '政宗',
    house: '伊達',
    closeNames: ['伊達政宗'],
    closePaths: ['伊達政宗の軍に加わった', '政宗を逃がして生き延びた', '白い死に装束の伊達政宗に供をし'],
    seenPaths: ['伊達政宗をあと一歩まで追い詰めた'],
  ),
];

_Famous _p(String key) => _people.firstWhere((p) => p.key == key);

/// 有名人の key（テストが使う）。
List<String> get kFamousKeys => [for (final p in _people) p.key];

/// その人の縁のある人の名（`personDied` の表と同じ名）。
String famousName(String key) => _p(key).name;

/// その人とどれだけ縁があるか。0 は縁なし、1 は見た・噂を聞いた、2 は親しく会った・仕えた。
int ftMet(Game g, String key) {
  final p = _p(key);
  final l = g.l;
  if (l.people.values.any((x) => p.closeNames.contains(x.name))) return 2;
  if (key == 'kenshin' && g.hasFlag('met_kenshin')) return 2;
  if (key == 'nobunaga' && g.hasFlag('met_nobunaga')) return 2;
  if (key == 'shingen' && l.lord == '武田' && l.rank >= 5) return 2;
  if (l.path.any((t) => p.closePaths.any(t.contains))) return 2;
  if (l.path.any((t) => p.seenPaths.any(t.contains))) return 1;
  return 0;
}

/// その人の没年（今の世界線で）。その世で筋を出さない人は null。
int? ftDeathYear(Game g, String key) {
  final line = worldLine(g);
  switch (key) {
    case 'nobunaga':
      if (line == 'imagawa') return null;
      return line == 'nobunaga' ? 1598 : 1582;
    case 'hideyoshi':
      return line == 'real' || line == 'west' ? 1598 : null;
    case 'ieyasu':
      // 西軍が勝った世の家康の行く末は描かない。
      return line == 'real' ? 1616 : null;
    case 'kenshin':
      return line == 'imagawa' ? null : 1578;
    case 'shingen':
      if (line == 'imagawa' || g.hasFlag('history_kawanakajima')) return null;
      return 1573;
    case 'masamune':
      return line == 'real' || line == 'west' ? 1636 : null;
  }
  return null;
}

/// その人に仕えている（主君がその人で、その家にいる。信玄は武田に仕える侍大将から）。
bool ftServing(Game g, String key) {
  final p = _p(key);
  final l = g.l;
  if (l.lord != p.house || l.rank < 1) return false;
  if (key == 'shingen') return l.rank >= 5;
  return l.people['主君']?.name == p.name;
}

/// その年に、その人が生きている（没年の前）。
bool _alive(Game g, String key) {
  final d = ftDeathYear(g, key);
  return d != null && g.year < d;
}

bool _inYears(Game g, int a, int b) => g.year >= a && g.year <= b;

bool _monk(Game g) => g.hasFlag('priesthood');

int _c(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

// ---------------------------------------------------------------- 節目

class _Fushime {
  const _Fushime(this.from, this.to, this.lines, this.event, this.serveText, this.visitText, this.step, {this.skip});
  final int from, to;
  final Set<String> lines;

  /// 歩んだ道の文に入れる出来事の名。
  final String event;
  final String serveText;

  /// 仕えていない縁のある人の文（null なら仕えている人だけ）。
  final String? visitText;

  /// 仕えている人の、進み出る手の名。
  final String step;
  final String? skip;
}

const _fushime = <String, _Fushime>{
  'nobunaga': _Fushime(
    1576,
    1579,
    {'real', 'akechi', 'nobunaga'},
    '安土の祝い',
    '安土の山に、信長の天主が建った。金と朱に輝く祝いの席で、信長が末席のあなたを見つけて手招きした。「近う寄れ」',
    '安土の山に、信長の天主が建ったと聞いた。金と朱に輝く天主だという。古い縁のある身として、祝いに出向くか。',
    '進み出て、祝いを述べる',
  ),
  'hideyoshi': _Fushime(
    1585,
    1588,
    {'real', 'west'},
    '関白の祝い',
    '主君・秀吉が関白に任じられた。京の祝いの席で、秀吉があなたを見つけ、「おう、来い来い」と扇で手招きした。',
    '秀吉が関白に任じられたと聞いた。あの日の藤吉郎が、帝のそばに立つ身になった。',
    '進み出て、祝いを述べる',
  ),
  'ieyasu': _Fushime(
    1603,
    1605,
    {'real'},
    '将軍の祝い',
    '主君・家康が征夷大将軍に任じられた。伏見での祝いの席で、家康が静かにあなたの名を呼んだ。',
    '家康が征夷大将軍に任じられたと聞いた。若い日に縁のあった人が、天下の主になった。',
    '進み出て、祝いを述べる',
  ),
  'kenshin': _Fushime(
    1561,
    1563,
    {'real', 'akechi', 'nobunaga', 'west'},
    '関東管領の祝い',
    '主君・景虎が、鎌倉で関東管領の職と上杉の名を継いだ（のちの謙信）。帰陣の祝いの席で、景虎が自ら盃を差し出した。',
    '越後の景虎が、上杉の名と関東管領の職を継いだと聞いた（のちの謙信）。寺の庭で言葉を交わした日が、遠くに思える。',
    '盃を受け、祝いを述べる',
    skip: 'h_e_tsurugaoka',
  ),
  'shingen': _Fushime(
    1571,
    1572,
    {'real', 'akechi', 'nobunaga', 'west'},
    '西上の陣触れ',
    '主君・信玄が、西へ兵を発すると触れを出した。出陣の前夜、信玄が侍大将たちを一人ずつ呼び、あなたの番が来た。',
    null,
    '出陣の供を願い出る',
  ),
  'masamune': _Fushime(
    1601,
    1604,
    {'real', 'west'},
    '仙台の町開き',
    '主君・政宗が、青葉山に新しい居所を構え、仙台の町割りを始めた。検分の折、政宗が隻眼でこちらを見て呼び止めた。',
    '政宗が、仙台に新しい町を開いていると聞いた。奥羽の暴れ者が、町を作る主になった。',
    '進み出て、祝いを述べる',
  ),
};

// ---------------------------------------------------------------- 敵になる

class _Teki {
  const _Teki(this.from, this.to, this.lines, this.text);
  final int from, to;
  final Set<String> lines;
  final String text;
}

const _teki = <String, _Teki>{
  'nobunaga': _Teki(
    1560,
    1597,
    {'real', 'akechi', 'nobunaga'},
    '戦の最中、敵方の織田の陣から使いが来た。信長からの文だ。「昔のよしみだ。こちらへ来い。悪いようにはせぬ」',
  ),
  'hideyoshi': _Teki(
    1583,
    1590,
    {'real', 'west'},
    '秀吉の大軍が、主家の国境に迫っている。陣中に、秀吉からの文が届いた。「降れば悪いようにはせん。昔のよしみじゃ、おぬしだけでも来い」',
  ),
  'ieyasu': _Teki(
    1570,
    1599,
    {'real', 'west'},
    '敵方の徳川の陣から、ひそかに使いが来た。家康からの文には、ただ「昔の縁、忘れておらぬ」とだけあった。',
  ),
  'kenshin': _Teki(
    1553,
    1577,
    {'real', 'akechi', 'nobunaga', 'west'},
    '越後の上杉の陣から、使いが来た。景虎（謙信）からの文だ。「義のために、こちらへ来ぬか」',
  ),
  'masamune': _Teki(
    1585,
    1600,
    {'real', 'west'},
    '伊達の陣から、政宗の文が届いた。「奥羽はいずれ我がものになる。今のうちに来い」',
  ),
};

// ---------------------------------------------------------------- 最期

class _Saigo {
  const _Saigo(this.news, this.place, {this.skip = const []});

  /// 世界線 → その死を伝える文。
  final String Function(Game g) news;

  /// 弔いに出向く先。
  final String place;
  final List<String> skip;
}

final _saigo = <String, _Saigo>{
  'nobunaga': _Saigo(
    (g) => worldLine(g) == 'nobunaga'
        ? '安土で、老いた信長が世を去ったと聞いた。天下を見届けての大往生だったという。'
        : '京の本能寺で、信長が明智光秀に襲われ、炎の中で果てたと聞いた。亡骸は見つからなかったという。',
    '京',
    skip: ['h_x_nobunaga_end'],
  ),
  'hideyoshi': _Saigo(
    (g) => '伏見で、太閤秀吉が世を去ったと聞いた。「露と落ち 露と消えにし 我が身かな」と詠んだと伝わる。',
    '伏見',
    skip: ['h_hideyoshi_death'],
  ),
  'ieyasu': _Saigo(
    (g) => '駿府で、大御所・家康が世を去ったと聞いた。亡骸は、久能山に葬られたという。',
    '駿府',
  ),
  'kenshin': _Saigo(
    (g) => '春日山で謙信が倒れ、そのまま帰らぬ人となったと聞いた。辞世は「四十九年 一睡の夢」と伝わる。',
    '春日山',
  ),
  'shingen': _Saigo(
    (g) => '西へ向かった信玄が、陣中で病が重くなり、甲斐へ引き返す途上で没したと伝わる。死は三年隠せと言い残したという。',
    '甲斐',
  ),
  'masamune': _Saigo(
    (g) => '江戸の屋敷で、伊達政宗が世を去ったと聞いた。数えで七十だったという。',
    '仙台',
  ),
};

// ---------------------------------------------------------------- 岐路

/// この岐路の id（テストが使う）。
List<String> get kFamousSceneIds => [
  for (final k in _fushime.keys) 'ft_${k}_fushime',
  for (final k in _teki.keys) 'ft_${k}_teki',
  for (final k in _saigo.keys) 'ft_${k}_saigo',
];

/// 節目の岐路が出てよい年と人（テストが使う）。
bool ftFushimeOk(Game g, String key) {
  final f = _fushime[key]!;
  if (!_inYears(g, f.from, f.to) || !f.lines.contains(worldLine(g))) return false;
  if (!_alive(g, key) || !g.active || _monk(g)) return false;
  if (f.skip != null && g.hasFlag('scene:${f.skip}')) return false;
  if (ftServing(g, key)) return true;
  return f.visitText != null && ftMet(g, key) == 2;
}

/// 敵になる岐路が出てよい年と人（テストが使う）。
bool ftTekiOk(Game g, String key) {
  final t = _teki[key]!;
  final p = _p(key);
  final l = g.l;
  return _inYears(g, t.from, t.to) &&
      t.lines.contains(worldLine(g)) &&
      _alive(g, key) &&
      ftMet(g, key) == 2 &&
      l.rank >= 1 &&
      l.rank <= 7 &&
      g.canFight &&
      g.active &&
      !_monk(g) &&
      l.lord != null &&
      l.lord != p.house &&
      (g.fa[l.lord]?.alive ?? false) &&
      (g.fa[p.house]?.alive ?? false) &&
      l.people['主君']?.name != p.name;
}

/// 最期の岐路が出てよい年と人（テストが使う）。
bool ftSaigoOk(Game g, String key) {
  final d = ftDeathYear(g, key);
  if (d == null || !_inYears(g, d, d + 1)) return false;
  if (_saigo[key]!.skip.any((s) => g.hasFlag('scene:$s'))) return false;
  return ftMet(g, key) >= 1;
}

List<SceneDef> buildFamousTieScenes() => [
  for (final k in _fushime.keys) _fushimeScene(k),
  for (final k in _teki.keys) _tekiScene(k),
  for (final k in _saigo.keys) _saigoScene(k),
];

SceneDef _fushimeScene(String key) => SceneDef(
  'ft_${key}_fushime',
  15,
  85,
  (g) => 14,
  (g) => ftFushimeOk(g, key),
  (g, next) {
    final p = _p(key);
    final f = _fushime[key]!;
    final l = g.l;
    final lordP = l.people['主君'];
    if (ftServing(g, key)) {
      g.ask(f.event, f.serveText, [
        Choice.h(f.step, '覚えはめでたくなる。周りの妬みも買う', () {
          l.fav = _c(l.fav + 6);
          l.fame += 3;
          g.j(4);
          if (lordP != null && lordP.name == p.name) lordP.bond = _c(lordP.bond + 8);
          g.setFlag('ft_${key}_honored');
          g.mark('${p.short}の${f.event}の席で、言葉を賜った');
          return '${p.short}は、あなたの顔を見て短く笑い、「励め」と言った。';
        }),
        Choice.h('願いを一つ申し上げる', '叶えば大きい。図々しいと睨まれるかもしれない', () {
          if (g.rng.chance(clampD(.4 + l.mi / 300, .4, .75))) {
            l.gold += 15 + l.rank * 3;
            l.merit += 5;
            g.setFlag('ft_${key}_granted');
            return '${p.short}は「よかろう」と言った。帰り道、膝が少し震えた。';
          }
          l.fav = _c(l.fav - 6);
          return '${p.short}は眉をひそめ、何も言わずに盃を置いた。';
        }),
        Choice.h('末席で静かに控える', '波風は立たない。何も変わらない', () {
          g.j(1);
          return '人の頭越しに、${p.short}の横顔を眺めていた。';
        }),
      ], after: next);
      return;
    }
    g.ask(f.event, f.visitText!, [
      Choice.h('祝いの品を携え、訪ねていく', '古い縁がまた結ばれる。銭はかかる', () {
        _pay(g, 8);
        l.net += 4;
        l.fame += 2;
        if (g.rng.chance(.6)) {
          g.j(6);
          g.setFlag('ft_${key}_renewed');
          g.mark('${p.short}の${f.event}に出向き、旧縁を温めた');
          return '取り次ぎの者は渋い顔をしたが、${p.short}は名を聞くなり「通せ」と言った。昔の話に、半刻ほど花が咲いた。';
        }
        return '人の波に阻まれ、品だけを預けて帰った。数日のち、短い礼の文が届いた。';
      }),
      Choice.h('文だけを送る', '角は立たない。縁は細くなる', () {
        l.net += 1;
        return '祝いの文を書いた。返事は来なかった。';
      }),
      Choice.h('遠くから噂を聞くだけにする', '何も変わらない。昔の日が遠くなる', () {
        g.j(-1);
        return '噂を聞きながら、あの日のことを少しだけ思い出した。';
      }),
    ], after: next);
  },
);

SceneDef _tekiScene(String key) => SceneDef(
  'ft_${key}_teki',
  16,
  75,
  (g) => 8,
  (g) => ftTekiOk(g, key),
  (g, next) {
    final p = _p(key);
    final t = _teki[key]!;
    final l = g.l;
    final hn = houseName(g, p.house);
    g.ask('旧縁の文', t.text, [
      Choice.h('文を破り、今の主家のために戦う', '主家の信頼は厚くなる。旧縁は敵になる', () {
        l.fav = _c(l.fav + 6);
        l.fame += 3;
        g.setFlag('ft_${key}_foe');
        g.mark('旧縁の${p.short}の誘いを退け、敵として向き合った');
        return '使いの前で文を裂いた。使いは何も言わずに帰っていった。';
      }),
      Choice.h('旧縁を頼って、$hn方へ寝返る', '強い側に付ける。裏切り者の名も付いてまわる', () {
        l.lord = p.house;
        l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
        l.fav = 35;
        l.troops = l.troops ~/ 2;
        l.fame = l.fame >= 3 ? l.fame - 3 : 0;
        l.net = l.net >= 2 ? l.net - 2 : 0;
        l.ronin = false;
        g.meet('主君', p.name, 50);
        g.setFlag('ft_${key}_turned');
        g.mark('旧縁を頼って、$hn方へ寝返った');
        return '夜陰に紛れて陣を抜けた。${p.short}は「来たか」とだけ言った。';
      }),
      Choice.h('返事をせず、文を懐にしまう', '今は何も起きない。迷いは残る', () {
        g.setFlag('ft_${key}_kept_letter');
        return '文は燃やさなかった。誰にも見せず、懐の奥にしまった。';
      }),
    ], after: next);
  },
);

SceneDef _saigoScene(String key) => SceneDef(
  'ft_${key}_saigo',
  15,
  85,
  (g) => 25,
  (g) => ftSaigoOk(g, key),
  (g, next) {
    final p = _p(key);
    final s = _saigo[key]!;
    final l = g.l;
    final serving = ftServing(g, key);
    final close = ftMet(g, key) == 2;
    final news = s.news(g);
    if (serving) {
      final lordP = l.people['主君'];
      g.ask('主君の最期', '$news主君の死に、家中は静まり返っている。', [
        Choice.h('${s.place}へ駆けつけ、亡骸に手を合わせる', '最後の縁を結べる。道中は危うい', () {
          _pay(g, 4);
          g.j(-4);
          l.net += 3;
          l.fame += 2;
          if (lordP != null) lordP.bond = _c(lordP.bond + 10);
          g.setFlag('ft_${key}_mourned');
          g.mark('主君・${p.short}の死を、駆けつけて弔った');
          return '${s.place}で手を合わせた。焼香の煙の向こうに、あの日の${p.short}の顔が見えた気がした。';
        }),
        Choice.h('喪に服し、しばらく務めを控える', '主への思いは示せる。家中の出世は遠のく', () {
          g.j(2);
          l.fav = _c(l.fav - 3);
          g.setFlag('ft_${key}_mourned');
          return '酒を断ち、白い衣で日々を過ごした。';
        }),
        Choice.h('涙をこらえ、次の主に備える', '家は守れる。胸に穴が開く', () {
          l.net += 2;
          g.j(-6);
          return '翌朝には、もう次の評定に出ていた。夜、ひとりになってから泣いた。';
        }),
      ], after: next);
      return;
    }
    g.ask('${p.short}の最期', '$news${close ? '若い日の縁が、胸によみがえる。' : 'いつか見たあの姿を思い出す。'}', [
      Choice.h('手を合わせ、昔の日を思う', '心は静まる。何も変わらない', () {
        g.j(close ? 2 : 1);
        if (close) g.mark('${p.short}の死を聞き、昔の日を思って手を合わせた');
        return close ? '縁側で、ひとり手を合わせた。あの日の声が、まだ耳に残っていた。' : '遠い空に向かって、手を合わせた。';
      }),
      if (close)
        Choice.h('${s.place}まで弔いに出向く', '旧縁の家の者に会える。銭と日数がかかる', () {
          _pay(g, 5);
          l.net += 3;
          g.setFlag('ft_${key}_mourned');
          g.mark('旧縁の${p.short}の弔いに、${s.place}まで出向いた');
          return '${s.place}の寺で、名も告げずに焼香した。帰りの道は、来たときより長く感じた。';
        }),
      Choice.h('世の移りを思い、身の振り方を考える', '先が見える。情は薄いと言われる', () {
        l.chi = clampInt(l.chi + 1, 0, 99);
        l.net += 1;
        return '次に天下を動かすのは誰か、夜更けまで考えた。';
      }),
    ], after: next);
  },
);
