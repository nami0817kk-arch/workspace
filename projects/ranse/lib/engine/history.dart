import 'childhood.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 史実の年表と、史実の岐路。
///
/// 世の動きは史実を土台にする（2026-11-23 決定「歴史はあなたの選択で変わる」）。
/// 勢力が滅ぶのは、この年表と、プレイヤーの侵攻だけ。乱数の小競り合いでは滅ばない。
/// プレイヤーが分岐点で史実を変えると（`history_*` の旗）、その後の年表の一部が別の流れになる。
/// プレイヤー自身が当主の家は、年表で滅ぼされない（あなたが歴史を変えている）。

class HistEvent {
  const HistEvent(this.id, this.year, this.apply, {this.only});
  final String id;
  final int year;

  /// この世界線（`history_lines.dart` の `worldLine`）でだけ起きる。null なら史実の出来事。
  final String? only;

  /// 起きたことを返す（見聞録に【世】として書く）。起きなければ null。
  final String? Function(Game g) apply;
}

Faction? _f(Game g, String n) {
  final x = g.fa[n];
  return (x != null && x.alive) ? x : null;
}

bool _ruled(Game g, String n) => g.l.lord == n && g.l.rank >= 8;

void _grow(Game g, String n, double v) {
  final x = _f(g, n);
  if (x != null) x.power = (x.power + v).clamp(3, 140).toDouble();
}

void _cut(Game g, String n, double k) {
  final x = _f(g, n);
  if (x != null && !_ruled(g, n)) {
    x.power = (x.power * k).clamp(3, 140).toDouble();
  }
}

/// [n] 家が [by] 家に滅ぼされる。プレイヤーが当主なら滅ばない。
bool _fall(Game g, String n, String by) {
  final d = _f(g, n);
  if (d == null || _ruled(g, n)) return false;
  final a = _f(g, by);
  if (a != null) a.power = (a.power + d.power * .6).clamp(3, 140).toDouble();
  d.alive = false;
  d.power = 0;
  if (a != null) g.lordLost(d, a);
  return true;
}

bool _h(Game g, String flag) => g.hasFlag(flag);

final kHistory = <HistEvent>[
  HistEvent('shingen', 1541, (g) {
    _grow(g, '武田', 3);
    return '甲斐の武田晴信（のちの信玄）が、父を駿河へ追い、家督を握った。';
  }),
  HistEvent('teppo', 1543, (g) => '種子島に南蛮の船が流れ着き、鉄砲が伝わった。'),
  HistEvent('xavier', 1549, (g) {
    return '南蛮の僧ザビエルが薩摩に上陸し、デウスの教えを説き始めた。';
  }),
  HistEvent('nagao', 1548, (g) {
    _grow(g, '上杉', 4);
    return '越後の長尾景虎が、兄に代わって家督を継いだ。';
  }),
  HistEvent('kawanakajima1', 1553, (g) {
    return '信濃の川中島で、武田と長尾（上杉）が初めてぶつかった。';
  }),
  HistEvent('itsukushima', 1555, (g) {
    _grow(g, '毛利', 10);
    return '安芸の毛利元就が、厳島で陶晴賢の大軍を破った。';
  }),
  HistEvent('dosan', 1556, (g) {
    _cut(g, '斎藤', .8);
    return '美濃の斎藤道三が、子の義龍に討たれた。';
  }),
  HistEvent('okehazama', 1560, (g) {
    if (_h(g, 'history_okehazama')) {
      _cut(g, '織田', .5);
      _grow(g, '今川', 10);
      return '桶狭間で織田の奇襲が退けられ、今川義元は尾張を手中にした。史書にない一日だった。';
    }
    _cut(g, '今川', .5);
    _grow(g, '織田', 10);
    _grow(g, '松平', 8);
    return '桶狭間で、今川義元が織田信長の奇襲に討たれた。三河の松平元康（のちの徳川家康）は独り立ちした。';
  }),
  HistEvent('kawanakajima4', 1561, (g) {
    _cut(g, '武田', .9);
    _cut(g, '上杉', .9);
    return '川中島で、武田信玄と上杉謙信が激しくぶつかった。両軍とも多くの将を失った。';
  }),
  HistEvent('kiyosu', 1562, (g) {
    _grow(g, '松平', 3);
    return '織田信長と松平元康が、清洲で手を結んだ。';
  }),
  HistEvent('gassan', 1566, (g) {
    if (_fall(g, '尼子', '毛利')) {
      return '出雲の月山富田城が開かれ、尼子家は毛利に降った。';
    }
    return null;
  }),
  HistEvent('inabayama', 1567, (g) {
    if (_f(g, '織田') == null) return null;
    if (_fall(g, '斎藤', '織田')) {
      return '織田信長が美濃の稲葉山城を落とし、岐阜と名を改めた。「天下布武」の印を使い始めた。';
    }
    return null;
  }),
  HistEvent('jouraku', 1568, (g) {
    if (_f(g, '織田') == null) return null;
    _fall(g, '六角', '織田');
    _cut(g, '三好', .6);
    _grow(g, '織田', 10);
    return '織田信長が足利義昭を奉じて京に上った。近江の六角家は城を捨てて逃れた。';
  }),
  HistEvent('imagawa_end', 1569, (g) {
    if (_h(g, 'history_okehazama')) return null;
    if (_fall(g, '今川', '武田')) {
      return '駿河の今川氏真が掛川城を開き、今川家は大名としての力を失った。';
    }
    return null;
  }),
  HistEvent('anegawa', 1570, (g) {
    _cut(g, '浅井', .8);
    _cut(g, '朝倉', .85);
    return '近江の姉川で、織田・徳川と浅井・朝倉が戦った。';
  }),
  HistEvent('hiei', 1571, (g) => '織田信長が比叡山延暦寺を焼き討ちにした。'),
  HistEvent('mikatagahara', 1572, (g) {
    _cut(g, '松平', .8);
    _grow(g, '武田', 6);
    return '遠江の三方ヶ原で、武田信玄が徳川家康を打ち破った。';
  }),
  HistEvent('shingen_death', 1573, (g) {
    _cut(g, '武田', .8);
    final a = _fall(g, '朝倉', '織田');
    final b = _fall(g, '浅井', '織田');
    return '武田信玄が陣中で没した。織田信長は将軍を京から追い、${a || b ? '越前の朝倉、近江の浅井を滅ぼした' : '室町の世は終わった'}。';
  }),
  HistEvent('nagashino', 1575, (g) {
    if (_h(g, 'history_nagashino')) {
      return '三河の長篠で、武田勝頼は織田・徳川の鉄砲の陣を前に兵を退いた。武田の騎馬は無傷のまま甲斐へ戻った。';
    }
    _cut(g, '武田', .6);
    _grow(g, '織田', 6);
    return '三河の長篠で、織田・徳川の鉄砲隊が武田勝頼の騎馬を打ち破った。';
  }),
  HistEvent('azuchi', 1576, (g) => '織田信長が近江に安土城を築き始めた。'),
  HistEvent('kenshin_death', 1578, (g) {
    _cut(g, '上杉', .7);
    _cut(g, '大友', .6);
    _grow(g, '島津', 8);
    return '上杉謙信が春日山で没し、家中は跡目で割れた。日向の耳川では、島津が大友を打ち破った。';
  }),
  HistEvent('ishiyama', 1580, (g) => '十年にわたって織田に抗った石山本願寺が、ついに大坂を明け渡した。'),
  HistEvent('honnoji', 1582, (g) {
    final t = _h(g, 'history_nagashino')
        ? '春、織田の甲州攻めは、長篠で力を残した武田の前に退けられた。'
        : (_fall(g, '武田', '織田') ? '春、武田勝頼が天目山で自害し、武田家は滅んだ。' : '');
    if (_h(g, 'history_honnoji')) {
      _grow(g, '織田', 20);
      return '$t夏、本能寺で謀反を起こした明智光秀は、生き延びた信長に討たれた。織田の天下は、揺るがなかった。';
    }
    _cut(g, '織田', .7);
    return '$t夏、明智光秀が本能寺で織田信長を討った。光秀は山崎で羽柴秀吉に敗れ、天下は秀吉の手に移り始めた。';
  }),
  HistEvent('shizugatake', 1583, (g) {
    if (_h(g, 'history_honnoji')) return null;
    _grow(g, '織田', 5);
    return '賤ヶ岳で羽柴秀吉が柴田勝家を破り、織田家の跡を継ぐ者となった。';
  }),
  HistEvent('okitanawate', 1584, (g) {
    _cut(g, '龍造寺', .5);
    _grow(g, '島津', 5);
    return worldLine(g) == 'real'
        ? '肥前の沖田畷で、龍造寺隆信が島津に討たれた。尾張の小牧・長久手では、秀吉と家康がにらみ合った。'
        : '肥前の沖田畷で、龍造寺隆信が島津に討たれた。';
  }),
  HistEvent('kanpaku', 1585, (g) {
    _cut(g, '長宗我部', .6);
    return _h(g, 'history_honnoji')
        ? '織田信長が朝廷から太政大臣に任じられ、四国の長宗我部も織田に降った。'
        : '羽柴秀吉が関白となり、四国の長宗我部を降した。のちに豊臣の姓を賜る。';
  }),
  HistEvent('kyushu', 1587, (g) {
    _cut(g, '島津', .6);
    _cut(g, '大友', .8);
    return '九州の島津が、天下の大軍の前に降った。バテレン（宣教師）を国外へ追う令が出た。';
  }),
  HistEvent('katanagari', 1588, (g) => '百姓から刀や槍を取り上げる「刀狩」の令が出た。'),
  HistEvent('suriagehara', 1589, (g) {
    if (_fall(g, '蘆名', '伊達')) {
      return '会津の摺上原で伊達政宗が蘆名を破り、蘆名家は滅んだ。';
    }
    return null;
  }),
  HistEvent('odawara', 1590, (g) {
    final t = _fall(g, '北条', '織田') ? '小田原の北条家が降り、滅んだ。' : '';
    _cut(g, '伊達', .8);
    return '$t奥羽の諸大名も膝を屈し、天下はひとつにまとまった。';
  }),
  HistEvent('rikyu', 1591, (g) => '茶人・千利休が、秀吉の怒りを買って腹を切った。'),
  HistEvent('bunroku', 1592, (g) {
    for (final n in ['島津', '毛利', '龍造寺', '大友']) {
      _cut(g, n, .9);
    }
    return '天下の大名たちが海を渡り、朝鮮へ攻め入った。';
  }),
  HistEvent('hideyoshi_death', 1598, (g) {
    return _h(g, 'history_honnoji')
        ? '老いた織田信長が、安土で世を去った。'
        : '豊臣秀吉が伏見で世を去った。朝鮮の兵は引き揚げ、徳川家康が力を伸ばし始めた。';
  }),
  HistEvent('sekigahara', 1600, (g) {
    _grow(g, '松平', 15);
    _cut(g, '毛利', .6);
    return '美濃の関ヶ原で、徳川家康の東軍が石田三成の西軍を破った。';
  }),
  // ---- 2026-11-23 追加: 国ごとの出来事 ----
  HistEvent('koriyama', 1541, (g) {
    _grow(g, '毛利', 5);
    _cut(g, '尼子', .85);
    return '安芸の吉田郡山城を囲んだ尼子の大軍が、毛利元就の籠城の前に退いた。';
  }),
  HistEvent('tenbun', 1542, (g) {
    _cut(g, '伊達', .85);
    return '陸奥の伊達家で、稙宗と晴宗の父子が争い始めた。奥羽の諸家を巻き込む大乱になった。';
  }),
  HistEvent('kawagoe', 1546, (g) {
    _grow(g, '北条', 10);
    return '武蔵の河越で、北条氏康がわずかな兵の夜襲で上杉方の大軍を破った。';
  }),
  HistEvent('miyoshi', 1549, (g) {
    _grow(g, '三好', 6);
    return '三好長慶が主筋の細川晴元を破り、京の実権を握った。';
  }),
  HistEvent('taineiji', 1551, (g) {
    return '周防の大内義隆が、家臣の陶晴賢の謀反で自害した。西国一の大名家が揺らいだ。';
  }),
  HistEvent('sankoku', 1554, (g) {
    return '武田・北条・今川が、互いに娘を嫁がせて手を結んだ（甲相駿三国同盟）。';
  }),
  HistEvent('bouchou', 1557, (g) {
    _grow(g, '毛利', 8);
    return '毛利元就が周防・長門を平らげ、大内家は滅んだ。';
  }),
  HistEvent('kanto_shutsujin', 1561, (g) {
    _cut(g, '北条', .9);
    return '長尾景虎が関東の諸将を率いて小田原城を囲み、上杉の名跡と関東管領を継いで上杉政虎と名乗った。';
  }),
  HistEvent('mikawa_ikko', 1563, (g) {
    _cut(g, '松平', .9);
    return '三河で一向一揆が起こり、松平家の家臣の多くが門徒の側についた。';
  }),
  HistEvent('hanbei', 1564, (g) {
    _cut(g, '斎藤', .85);
    return '美濃の竹中半兵衛が、わずかな手勢で主家の稲葉山城を乗っ取り、のちに返した。';
  }),
  HistEvent('eiroku', 1565, (g) {
    _cut(g, '三好', .9);
    return '京で、将軍足利義輝が三好の軍勢に襲われ、自ら刀を振るって討たれた。';
  }),
  HistEvent('daibutsu', 1567, (g) {
    return '奈良で三好と松永久秀の軍勢が争い、東大寺の大仏殿が焼け落ちた。';
  }),
  HistEvent('mimasetoge', 1569, (g) {
    _cut(g, '北条', .9);
    return '武田信玄が小田原城を囲んで引き揚げる途中、相模の三増峠で北条の追撃を打ち破った。';
  }),
  HistEvent('kanegasaki', 1570, (g) {
    return '越前に攻め入った織田信長は、義弟・浅井長政の裏切りに遭い、金ヶ崎から命からがら京へ逃げ帰った。';
  }),
  HistEvent('motonari_death', 1571, (g) {
    _cut(g, '毛利', .9);
    return '毛利元就が、吉田郡山城で世を去った。「三本の矢」の教えが語り継がれた。';
  }),
  HistEvent('nagashima', 1574, (g) {
    return '伊勢長島の一向一揆が、織田の大軍に囲まれ、焼き尽くされた。';
  }),
  HistEvent('hisahide', 1577, (g) {
    _cut(g, '三好', .7);
    return '大和の松永久秀が信長に背き、信貴山城で名物の茶釜とともに果てた。';
  }),
  HistEvent('otate', 1578, (g) {
    _cut(g, '上杉', .85);
    _grow(g, '武田', 3);
    return '上杉家で、謙信の養子・景勝と景虎が跡目を争った（御館の乱）。景勝が勝った。';
  }),
  HistEvent('arioka', 1579, (g) {
    return '摂津の荒木村重が信長に背いて有岡城に籠もり、城に残された一族は処刑された。';
  }),
  HistEvent(
    'azuchi_shuron',
    1579,
    (g) => '安土城下で、浄土宗と法華宗の僧が信長の前で問答をさせられた（安土宗論）。',
  ),
  HistEvent('tottori', 1581, (g) {
    _cut(g, '毛利', .9);
    return '因幡の鳥取城が、羽柴秀吉の兵糧攻めで開城した。城中は、飢えで地獄のありさまだったという。';
  }),
  HistEvent('kenou', 1582, (g) {
    return '九州のキリシタン大名が、四人の少年を使節としてローマへ送り出した（天正遣欧使節）。';
  }),
  HistEvent('takamatsu', 1582, (g) {
    _cut(g, '毛利', .9);
    return '羽柴秀吉は備中高松城を水攻めにしていたが、本能寺の知らせを受けると毛利と和を結び、京へ駆け戻った。';
  }),
  HistEvent('tensho_jingo', 1582, (g) {
    _grow(g, '北条', 4);
    _grow(g, '松平', 6);
    return '主のいなくなった甲斐・信濃を、徳川・北条・上杉が奪い合った（天正壬午の乱）。';
  }),
  HistEvent('osakajo', 1583, (g) => '羽柴秀吉が、石山本願寺の跡に大坂城を築き始めた。'),
  HistEvent('hitotoribashi', 1585, (g) {
    _cut(g, '佐竹', .9);
    _cut(g, '蘆名', .9);
    return '奥州の人取橋で、伊達政宗が佐竹・蘆名らの連合軍の猛攻をしのいだ。';
  }),
  HistEvent('tensho_jishin', 1586, (g) {
    return '中部から近畿にかけて大地震が起こり、多くの城や町が崩れた（天正地震）。';
  }),
  HistEvent('kitano', 1587, (g) {
    return '京の北野天満宮で大茶会が開かれた。茶の心得があれば、身分を問わず誰でも加われるという触れが出た。';
  }),
  HistEvent('edo', 1590, (g) {
    _grow(g, '松平', 10);
    return '徳川家康が、北条の旧領の関東へ移され、江戸に入った。';
  }),
  HistEvent('hitobarai', 1591, (g) => '武士・百姓・町人の身分を改めて定める令が出た。'),
  HistEvent('fushimi', 1594, (g) => '秀吉が、伏見に新しい城と城下町を築き始めた。'),
  HistEvent('keicho_jishin', 1596, (g) {
    return '畿内を大地震が襲い、伏見城の天守が崩れた。土佐には南蛮船サン・フェリペ号が流れ着いた。';
  }),
  HistEvent('keicho', 1597, (g) => '朝鮮との和議が破れ、大名たちは再び海を渡った（慶長の役）。'),
  HistEvent('toshiie', 1599, (g) {
    return '豊臣家を支えた前田利家が世を去った。徳川家康と石田三成の対立が、表に出始めた。';
  }),
];

/// [year] までにまだ起きていない史実を起こす。[quietBefore] より前の年のものは見聞録に書かない
/// （幼いうちに起きたこと）。
void applyHistory(Game g, int year, {int? quietBefore}) {
  for (final e in [...kHistory, ...kAltHistory]) {
    if (e.year > year || g.hasFlag('h:${e.id}')) continue;
    // 世界線に合わない出来事は起こさない。変わった世界線だけの出来事は、その世界線でだけ起こす。
    if (e.only != null && e.only != worldLine(g)) continue;
    if (e.only == null && eventSkippedInLine(g, e.id)) {
      g.setFlag('h:${e.id}');
      continue;
    }
    g.setFlag('h:${e.id}');
    final txt = e.apply(g);
    if (txt != null && (quietBefore == null || e.year >= quietBefore)) {
      g.log('【世】$txt', 'big');
    }
  }
}

/// 史実の岐路（その年に必ず優先して出る）。
const kHistoryScenes = {'okehazama', 'honnoji', 'hiei', 'earthquake'};

/// 同じ出来事を別の目で描いた岐路の組。片方が出たら、もう片方は出さない。
const _twinPairs = [
  ('h_w_kitano', 'h_l_kitano'),
  ('h_w_sakai', 'h_l_sakai'),
  ('h_w_nagasaki', 'h_l_nagasaki'),
  ('h_w_funai_hospital', 'h_l_funai'),
  ('h_w_tensho_shisetsu', 'h_l_envoys'),
  ('h_w_ishiyama', 'h_l_ishiyama'),
  ('h_e_jukeini', 'h_l_jukeini'),
  ('h_e_erinji', 'h_c_erinji'),
];

/// [id] と同じ出来事の別の岐路（なければ null）。
String? twinScene(String id) {
  for (final (a, b) in _twinPairs) {
    if (a == id) return b;
    if (b == id) return a;
  }
  return null;
}

bool isHistoryScene(String id) =>
    id.startsWith('h_') || kHistoryScenes.contains(id);

int _yr(Game g, int a) => g.l.startYear + a;
bool _at(Game g, int a, int y) => _yr(g, a) == y;
bool _lordIs(Game g, List<String> ns) => ns.contains(g.l.lord);
bool _inRegion(Game g, List<String> rs) => rs.contains(g.l.region);
bool _soldier(Game g) =>
    g.l.rank >= 1 && g.l.rank < 8 && g.canFight && g.active;
int _c(int v) => clampInt(v, 0, 100);
String _anegawaFoe(Game g) => _lordIs(g, ['織田', '松平']) ? '浅井' : '織田';
String _mimiFoe(Game g) => g.l.lord == '島津' ? '大友' : '島津';

List<SceneDef> buildHistoryScenes() {
  return [
    // ---------------- 人との出会い ----------------
    SceneDef(
      'h_tokichiro',
      15,
      40,
      (g) => 1,
      (g) =>
          (_inRegion(g, ['尾張', '美濃']) || g.l.lord == '織田') &&
          g.l.rank <= 3 &&
          !g.hasFlag('priesthood'),
      (g, next) {
        g.ask(
          '猿と呼ばれた男',
          '織田家の足軽に、藤吉郎という猿のような顔の小男がいる。よく働き、よく笑う。その男が、あなたに声をかけてきた。',
          [
            Choice.h('藤吉郎と親しくなる', '妙に人を惹きつける男だ。出世するか、すぐ死ぬか', () {
              g.meet('藤吉郎', '木下藤吉郎', 50);
              g.l.net += 2;
              g.mark('のちの豊臣秀吉、木下藤吉郎と親しくなった');
              return '藤吉郎と、夜通し酒を酌み交わした。';
            }),
            Choice.h('相手にしない', '口の達者な男は信用できない', () => '軽く受け流した。'),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _yr(g, a) >= 1555 && _yr(g, a) <= 1565,
    ),

    SceneDef(
      'h_hideyoshi_again',
      20,
      70,
      (g) => 6,
      (g) =>
          g.l.people.containsKey('藤吉郎') &&
          g.l.rank < 6 &&
          !g.hasFlag('priesthood') &&
          g.active,
      (g, next) {
        final l = g.l;
        g.ask('秀吉', 'あの藤吉郎が、いまや羽柴秀吉と名乗り、城持ちの大将になっていた。「おう、あの時の！ わしのところへ来んか」', [
          Choice.h('秀吉に仕える', '昇る男の背中に乗る。浮き沈みも大きい', () {
            final p = l.people.remove('藤吉郎')!;
            g.meet('主君', '羽柴秀吉', p.bond + 15);
            l.lord = '織田';
            l.rank = l.rank < 2 ? 2 : l.rank;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.fav = 40;
            l.ronin = false;
            g.mark('昔なじみの羽柴秀吉に仕えた');
            return '秀吉のもとに馳せ参じた。秀吉は手を叩いて喜んだ。';
          }),
          Choice.h('今の道を行く', '縁はここで途切れる', () => '丁重に断った。秀吉は少し寂しそうに笑った。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1573 && _yr(g, a) <= 1590,
    ),

    SceneDef(
      'h_xavier',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['薩摩', '豊後', '肥前', '山城']) && !g.hasFlag('kirishitan'),
      (g, next) {
        g.ask('ザビエル', '南蛮の僧フランシスコ・ザビエルが町に来て、デウスの教えを説いている。', [
          Choice.h('教えを聞きに行く', '見知らぬ救いに出会う。周りの目は変わる', () {
            g.setFlag('kirishitan');
            g.meet('南蛮の師', 'ザビエル', 40);
            g.mark('ザビエルから洗礼を受けた');
            return 'ザビエルの手で、洗礼を受けた。';
          }),
          Choice.h('遠くから眺める', '珍しい見ものだ', () => '人だかりの外から、背の高い南蛮人を眺めた。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1549 && _yr(g, a) <= 1551,
    ),

    // ---------------- 合戦 ----------------
    SceneDef(
      'h_kawanakajima',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['武田', '上杉']),
      (g, next) {
        final takeda = g.l.lord == '武田';
        g.ask(
          '川中島',
          takeda
              ? '霧の川中島。軍師の策で、別働隊が妻女山の上杉を背後から突くという。'
              : '妻女山の上で、謙信が「今夜、山を下りる」と言った。霧の八幡原へ向かう。',
          [
            Choice.h(
              takeda ? '本隊で信玄を守る' : '謙信に従い本陣へ斬り込む',
              '戦の只中に立つ。歴史に残る一戦だ',
              () {
                final l = g.l;
                if (g.rng.chance(.12)) {
                  g.die('川中島の霧の中で討死した', 'senshi');
                  return '霧の中から、敵の槍がのびてきた。';
                }
                l.merit += 20;
                l.fame += 10;
                g.mark('川中島の戦いで、信玄と謙信の一騎打ちを間近に見た');
                return '霧が晴れたとき、目の前で信玄と謙信が刃を交えていた。';
              },
            ),
            Choice.h(takeda ? '別働隊に加わる' : '殿（しんがり）を務める', '本陣からは遠い。手柄は小さい', () {
              g.l.merit += 6;
              return '戦が終わったとき、両軍の死者は数え切れなかった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1561),
    ),

    SceneDef(
      'h_anegawa',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['浅井', '朝倉', '織田', '松平']),
      (g, next) {
        g.ask('姉川', '近江の姉川をはさんで、両軍がにらみ合っている。', [
          Choice.h(
            '川を渡って斬り込む',
            '名を上げる好機。川は血に染まる',
            () => g.battle('van', enemy: _anegawaFoe(g)),
          ),
          Choice.h(
            '陣を固めて待つ',
            '堅実だ。手柄は小さい',
            () => g.battle('rear', enemy: _anegawaFoe(g)),
          ),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1570),
    ),

    SceneDef(
      'h_mikatagahara',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '松平',
      (g, next) {
        g.ask('三方ヶ原', '武田の大軍に、徳川の軍勢は総崩れになった。家康が逃げ遅れている。', [
          Choice.h('家康の身代わりとなって敵を引きつける', '主は逃げ延びるかもしれない。自分は助からないだろう', () {
            if (g.rng.chance(.7)) {
              g.die('三方ヶ原で、家康の身代わりとなって討たれた', 'senshi');
              return '「我こそは家康なり」と叫び、敵の只中へ駆け込んだ。';
            }
            g.l.fav = _c(g.l.fav + 40);
            g.l.merit += 40;
            g.mark('三方ヶ原で家康の身代わりとなり、生き延びた');
            return '身代わりを務め、奇跡的に生き延びた。家康は涙を流して手を取った。';
          }),
          Choice.h('家康の馬を守って浜松へ退く', '主と共に生き延びる', () {
            g.l.fav = _c(g.l.fav + 15);
            g.mark('三方ヶ原で、敗走する家康を守って退いた');
            return '家康を守り、浜松城へ逃げ込んだ。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1572),
    ),

    SceneDef(
      'h_odani',
      15,
      70,
      (g) => 20,
      (g) => g.l.lord == '浅井' && g.l.rank >= 1 && g.active,
      (g, next) {
        g.ask('小谷城', '織田の大軍に小谷城が囲まれた。落城は近い。城には浅井長政の妻・お市と、三人の姫がいる。', [
          Choice.h('お市と姫たちを城から落ち延びさせる', '血筋は残る。自分は城に戻れない', () {
            if (g.rng.chance(.3)) {
              g.die('小谷城の落城の中、姫たちを逃がして力尽きた', 'senshi');
              return '姫たちを織田の陣へ送り届けたあと、矢を受けて倒れた。';
            }
            g.meet('姫', 'お市の娘・茶々', 60);
            g.mark('小谷城の落城の日、お市と三人の姫を落ち延びさせた');
            return 'お市と姫たちを、無事に城の外へ送り出した。';
          }),
          Choice.h('長政と運命を共にする', '最後まで主の側にいる', () {
            g.die('小谷城の落城で、浅井長政に殉じた', 'seppuku');
            return '長政に続き、城と運命を共にした。';
          }),
          Choice.h('ひそかに城を抜け出す', '命は守れる。裏切り者と呼ばれる', () {
            g.l.rank = 0;
            g.l.lord = null;
            g.l.ronin = true;
            return '夜陰にまぎれて、城を抜け出した。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1573),
    ),

    SceneDef(
      'h_nagashino',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['武田', '織田', '松平']),
      (g, next) {
        final takeda = g.l.lord == '武田';
        g.ask(
          '長篠',
          takeda
              ? '設楽原の向こうに、馬防柵と三千の鉄砲が並んでいる。勝頼は突撃を命じた。'
              : '馬防柵の内側で、鉄砲を構えて武田の騎馬を待つ。',
          takeda
              ? [
                  Choice.h('命に従い突撃する', '武田の誇りだ。柵の向こうには鉄砲がある', () {
                    if (g.rng.chance(.35)) {
                      g.die('長篠の戦いで、鉄砲の前に散った', 'senshi');
                      return '柵の手前で、轟音とともに馬から落ちた。';
                    }
                    g.l.hp -= 30;
                    g.mark('長篠で鉄砲の雨の中を突撃し、生き延びた');
                    return '仲間の多くが倒れた。自分は、どうにか生き延びた。';
                  }),
                  Choice.h('撤退を進言する', '命は守れる。臆病者と言われる', () {
                    // まれに勝頼が聞き入れ、武田は鉄砲の前で壊滅せずに残る（小さな分岐）。
                    if (g.rng.chance(.08 + g.l.chi / 1500)) {
                      g.setFlag('history_nagashino');
                      g.l.fav = _c(g.l.fav + 30);
                      g.l.merit += 30;
                      g.l.fame += 25;
                      g.mark('長篠で撤退を進言し、武田の騎馬を鉄砲の前から救った');
                      return '勝頼は長い沈黙のあと、兵を退くと言った。武田の騎馬は、無傷で甲斐へ戻った――歴史が、変わった。';
                    }
                    g.l.fav = _c(g.l.fav - 10);
                    return '進言は退けられた。退いた者だけが生き残った。';
                  }),
                ]
              : [
                  Choice.h('鉄砲の列に立つ', '新しい戦の形だ。手柄は約束される', () {
                    g.l.merit += 15;
                    g.l.gun = true;
                    g.mark('長篠の戦いで、鉄砲隊に加わった');
                    return '撃っても撃っても、武田の騎馬は突っ込んできた。そして、尽きた。';
                  }),
                  Choice.h(
                    '柵の外へ打って出る',
                    '大将首を狙える。鉄砲の味方撃ちもある',
                    () => g.battle('van', enemy: '武田'),
                  ),
                ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1575),
    ),

    SceneDef(
      'h_mimikawa',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['大友', '島津']),
      (g, next) {
        g.ask('耳川', '日向の耳川で、大友と島津の大軍が向かい合った。', [
          Choice.h(
            '先陣を駆ける',
            '名を上げる好機。川は深い',
            () => g.battle('van', enemy: _mimiFoe(g)),
          ),
          Choice.h(
            '本陣に控える',
            'ほどほどの手柄',
            () => g.battle('main', enemy: _mimiFoe(g)),
          ),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1578),
    ),

    SceneDef(
      'h_tenmokuzan',
      15,
      84,
      (g) => 20,
      (g) => g.l.lord == '武田' && g.l.rank >= 1 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask('天目山', '織田の大軍が甲斐に攻め入った。家臣は次々と寝返り、勝頼に従う者はわずかになった。', [
          Choice.h('最後まで勝頼に従う', '武田の最期を見届ける', () {
            g.die('天目山で、武田勝頼に殉じた', 'seppuku');
            return '天目山の麓で、勝頼と共に果てた。';
          }),
          Choice.h('織田に降る', '命は守れる。主を見捨てることになる', () {
            g.l.lord = '織田';
            g.l.rank = g.l.rank - 1 < 1 ? 1 : g.l.rank - 1;
            g.l.fav = 10;
            g.j(-10);
            g.mark('武田の滅亡に、織田へ降った');
            return '織田の陣に降った。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1582),
    ),

    SceneDef(
      'h_yamazaki',
      15,
      84,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '織田' && !g.hasFlag('history_honnoji'),
      (g, next) {
        g.ask('山崎', '信長亡きあと、明智光秀と羽柴秀吉が山崎で決戦に及ぶ。どちらにつく？', [
          Choice.h('秀吉につく', '主の仇を討つ。勢いはこちらにある', () {
            g.l.merit += 15;
            g.l.fav = _c(g.l.fav + 10);
            g.mark('山崎の戦いで、秀吉に従い光秀を討った');
            return '天王山を駆け下り、明智の軍勢を打ち破った。';
          }),
          Choice.h('光秀につく', '天下が変わるかもしれない。勝てば、の話だ', () {
            if (g.rng.chance(.06)) {
              g.setFlag('history_yamazaki');
              g.l.merit += 60;
              g.l.fame += 40;
              g.mark('山崎で光秀に味方し、秀吉を退けた');
              return '秀吉の軍勢は崩れた。光秀の天下は、三日では終わらなかった――歴史が、変わった。';
            }
            g.die('山崎の戦いで明智方として敗れ、落ち延びる途中で討たれた', 'senshi');
            return '明智の軍勢は崩れた。落ち延びる竹藪の中で、槍に突かれた。';
          }),
          Choice.h(
            'どちらにもつかず様子を見る',
            '負けた側にはつかずに済む。勝った側にも恩はない',
            () => '洞ヶ峠から、成り行きを見守った。',
          ),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1582),
    ),

    SceneDef(
      'h_shizugatake',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '織田' && !g.hasFlag('history_honnoji'),
      (g, next) {
        g.ask('賤ヶ岳', '秀吉が、柴田勝家の陣へ一気に攻めかかる。若い者たちが槍を手に駆けていく。', [
          Choice.h('若武者たちと共に槍を振るう', '名を上げる好機だ', () {
            final r = g.battle('van');
            if (g.l.dead == null && g.rng.chance(.25)) {
              g.l.fame += 20;
              g.mark('賤ヶ岳で、七本槍と並ぶ働きをした');
              return '$r 七本槍と並び称される働きだった。';
            }
            return r;
          }),
          Choice.h('後詰めにまわる', '命は守りやすい', () => g.battle('rear')),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1583),
    ),

    SceneDef(
      'h_odawara',
      15,
      84,
      (g) => 20,
      (g) => g.l.lord == '北条' && g.l.rank >= 1 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask('小田原評定', '天下の大軍が小田原城を囲んだ。城中では、戦うか降るかの評定が、いつまでも続いている。', [
          Choice.h('降伏を説く', '多くの命が救われる。主の誇りを傷つける', () {
            g.l.net += 3;
            g.mark('小田原の評定で、降伏を説いた');
            return '降伏を説いた。三月ののち、城は開かれた。';
          }),
          Choice.h('徹底して戦うべしと説く', '北条の誇りは守られる。城は飢える', () {
            if (g.rng.chance(.12)) {
              g.die('小田原の籠城の末、城中で病に倒れた', 'byo');
              return '長い籠城の末、城中で病に倒れた。';
            }
            return '評定は決まらず、やがて城は開かれた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1590),
    ),

    SceneDef('h_chosen', 15, 70, (g) => 20, (g) => _soldier(g) && !g.l.female, (
      g,
      next,
    ) {
      g.ask('海の向こうの戦', '主家にも、朝鮮へ渡る命が下った。', [
        Choice.h('海を渡る', '異国の地で戦う。生きて帰れる者は多くない', () {
          if (g.rng.chance(.15)) {
            g.die('朝鮮の地で病に倒れ、二度と故郷を見なかった', 'byo');
            return '異国の冬は、思いのほか厳しかった。';
          }
          g.l.merit += 15;
          g.l.hp -= 20;
          g.setFlag('chosen');
          g.mark('朝鮮へ渡って戦い、生きて帰った');
          return '異国で戦い、痩せ衰えて帰ってきた。';
        }),
        Choice.h('病と称して国に残る', '命は守れる。主の目は冷たい', () {
          g.l.fav = _c(g.l.fav - 12);
          return '国に残った。主は何も言わなかった。';
        }),
      ], after: next);
    }, ageOk: (g, a) => _at(g, a, 1592)),

    SceneDef(
      'h_sekigahara',
      15,
      84,
      (g) => 20,
      (g) => !g.l.female && g.canFight && g.active && !g.hasFlag('priesthood'),
      (g, next) {
        final l = g.l;
        g.ask(
          '関ヶ原',
          '天下を二つに分けた戦が、美濃の関ヶ原で始まろうとしている。${l.rank >= 1 ? '' : '足軽を集める触れが、村にも回ってきた。'}',
          [
            Choice.h('東軍（徳川家康）につく', '勢いはこちらにある', () {
              if (g.rng.chance(.05)) {
                g.die('関ヶ原の戦いで、東軍として討死した', 'senshi');
                return '霧の晴れた関ヶ原で、流れ弾に倒れた。';
              }
              l.merit += 15;
              l.fame += 8;
              g.mark('関ヶ原で東軍に加わった');
              return '昼過ぎ、西軍は崩れた。東軍の勝ちだ。';
            }),
            Choice.h('西軍（石田三成）につく', '義はこちらにある。裏切り者が出なければ…', () {
              if (g.rng.chance(.07)) {
                g.setFlag('history_sekigahara');
                l.merit += 50;
                l.fame += 40;
                g.mark('関ヶ原で西軍を勝利に導いた');
                return '小早川の軍勢が動かなかった。西軍が勝った――歴史が、変わった。';
              }
              if (g.rng.chance(.3)) {
                g.die('関ヶ原で西軍として敗れ、捕らえられて斬られた', 'seppuku');
                return '西軍は崩れた。落ち延びる途中で捕らえられた。';
              }
              l.rank = 0;
              l.lord = null;
              l.ronin = true;
              g.mark('関ヶ原で西軍に加わり、敗れて浪人となった');
              return '西軍は崩れた。命からがら逃げ延び、浪人となった。';
            }),
            Choice.h('どちらにもつかない', '戦が終わるのを待つ', () => '関ヶ原の煙を、遠くから眺めた。'),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1600),
    ),

    // ---------------- 暮らしに届く史実 ----------------
    SceneDef(
      'h_katanagari',
      15,
      84,
      (g) => 20,
      (g) => g.l.rank == 0 && !g.l.female && !g.hasFlag('priesthood'),
      (g, next) {
        g.ask('刀狩', '役人が村に来て、刀や槍を差し出せと言う。大仏を造る釘にするのだという。', [
          Choice.h('差し出す', '百姓として生きる。もう武士にはなれない', () {
            g.setFlag('gave_sword');
            g.mark('刀狩で刀を差し出し、百姓として生きると決めた');
            return '刀を差し出した。肩が、少し軽くなった。';
          }),
          Choice.h('床下に隠す', 'いつか役に立つかもしれない。見つかれば罰を受ける', () {
            if (g.rng.chance(.25)) {
              g.l.hp -= 15;
              g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
              return '隠した刀が見つかり、罰を受けた。';
            }
            g.setFlag('hid_sword');
            return '刀を油紙に包み、床下に埋めた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) == 1588 || _yr(g, a) == 1589,
    ),

    SceneDef('h_bateren', 15, 84, (g) => 20, (g) => g.hasFlag('kirishitan'), (
      g,
      next,
    ) {
      g.ask('伴天連追放', 'バテレンを国から追う令が出た。キリシタンへの目が、日に日に厳しくなる。', [
        Choice.h('信仰を守り抜く', '心は折れない。命を狙われることもある', () {
          if (g.rng.chance(.1)) {
            g.die('信仰を捨てず、捕らえられて処刑された', 'seppuku');
            return '十字架を握りしめたまま、刑場に引かれていった。';
          }
          g.setFlag('kept_faith');
          g.mark('伴天連追放の世にも、信仰を守り抜いた');
          return 'ひそかに祈りを続けた。';
        }),
        Choice.h('教えを捨てる', '身は守られる。心に穴があく', () {
          g.l.flags.remove('kirishitan');
          g.j(-8);
          return '十字架を川に流した。';
        }),
      ], after: next);
    }, ageOk: (g, a) => _yr(g, a) >= 1587 && _yr(g, a) <= 1590),

    SceneDef(
      'h_rikyu',
      15,
      84,
      (g) => 20,
      (g) => g.l.people.containsKey('茶の師'),
      (g, next) {
        final m = g.l.people['茶の師']!;
        g.ask('利休の最期', '茶の師・${m.name}（利休）が、秀吉の怒りを買い、腹を切ることになったと聞いた。', [
          Choice.h('ひそかに別れの茶を点てに行く', '師に会える。秀吉ににらまれるかもしれない', () {
            g.setFlag('rikyu_farewell');
            g.j(-6);
            g.mark('切腹を前にした師・利休に、別れの茶を点てた');
            return '師は黙って茶を飲み、「よい茶だ」とだけ言った。';
          }),
          Choice.h('遠くから師を悼む', '身は守られる', () {
            g.j(-8);
            return '庭の椿が、音もなく落ちた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1591),
    ),

    SceneDef(
      'h_hideyoshi_death',
      15,
      84,
      (g) => 20,
      (g) => g.l.people['主君']?.name == '羽柴秀吉',
      (g, next) {
        final p = g.l.people['主君']!;
        g.ask('太閤の死', 'あの藤吉郎が――太閤秀吉が、伏見で死の床にある。枕元に呼ばれた。', [
          Choice.h('最後まで側にいる', '主を看取る', () {
            p.bond = _c(p.bond + 20);
            g.setFlag('saw_hideyoshi_die');
            g.mark('太閤秀吉の最期を看取った');
            return '「露と落ち 露と消えにし わが身かな」。秀吉は、そう詠んで逝った。';
          }),
          Choice.h('家康に近づいておく', '次の天下に備える。忠義は問われる', () {
            g.l.net += 3;
            g.j(-4);
            return '伏見の徳川屋敷に、ひそかに足を運んだ。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1598),
    ),

    SceneDef(
      'h_ikko_nagashima',
      15,
      84,
      (g) => 20,
      (g) =>
          g.l.rank == 0 &&
          (_inRegion(g, ['尾張', '美濃']) || g.hasFlag('ikko')) &&
          g.active,
      (g, next) {
        g.ask('長島', '伊勢長島の一向門徒が、織田の大軍に囲まれた。村の者にも門徒が多い。', [
          Choice.h('門徒を助けに長島へ行く', '信じる者を見捨てない。囲みの中に入ることになる', () {
            if (g.rng.chance(.4)) {
              g.die('長島の一揆で、織田の囲みの中で焼かれた', 'sai');
              return '囲みの中で、炎に包まれた。';
            }
            g.l.hp -= 20;
            g.mark('長島の門徒を助けに向かい、生き延びた');
            return '囲みが閉じる前に、数人を連れて逃げ出した。';
          }),
          Choice.h('村に留まる', '命は守れる', () => '長島の方角の空が、何日も赤く染まっていた。'),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1574),
    ),
    // ---------------- 国ごとの史実（庶民にも届く） ----------------
    SceneDef(
      'h_takechiyo',
      15,
      40,
      (g) => 20,
      (g) => _inRegion(g, ['駿河', '三河']) && g.active,
      (g, next) {
        g.ask('竹千代', '駿府の今川館に、三河から人質に出された松平の少年・竹千代（のちの徳川家康）がいる。寂しげに鷹を眺めていた。', [
          Choice.h('声をかけて鷹の話をする', '人質の少年は、優しくされた恩を忘れないかもしれない', () {
            g.meet('竹千代', '松平竹千代', 45);
            g.mark('人質の少年・竹千代（のちの徳川家康）と言葉を交わした');
            return '竹千代は、少しだけ笑った。';
          }),
          Choice.h('関わらない', '人質に近づくのは、あらぬ疑いのもとだ', () => '遠くから、少年の背中を見た。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1549 && _yr(g, a) <= 1559,
    ),

    SceneDef(
      'h_ieyasu_again',
      20,
      70,
      (g) => 6,
      (g) =>
          g.l.people.containsKey('竹千代') &&
          g.l.rank < 6 &&
          !g.hasFlag('priesthood') &&
          g.active,
      (g, next) {
        final l = g.l;
        g.ask(
          '家康',
          '駿府の人質だった竹千代は、いまや三河の主・徳川家康となっていた。「駿府で鷹の話をしてくれたのは、そなたであったな」',
          [
            Choice.h('家康に仕える', '辛抱強い主。最後に笑うのは、この男かもしれない', () {
              final p = l.people.remove('竹千代')!;
              g.meet('主君', '徳川家康', p.bond + 15);
              l.lord = '松平';
              l.rank = l.rank < 1 ? 1 : l.rank;
              if (l.rank > l.maxRank) l.maxRank = l.rank;
              l.fav = 40;
              l.ronin = false;
              g.mark('幼き日の縁で、徳川家康に仕えた');
              return '家康のもとに参じた。家康は、静かにうなずいた。';
            }),
            Choice.h('今の道を行く', '縁はここで途切れる', () => '丁重に断った。'),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _yr(g, a) >= 1565 && _yr(g, a) <= 1595,
    ),

    SceneDef(
      'h_shingen_tsutsumi',
      15,
      70,
      (g) => 20,
      (g) => _inRegion(g, ['甲斐', '信濃']) && g.l.rank <= 2 && g.active,
      (g, next) {
        g.ask('信玄堤', 'たびたび暴れる釜無川に、武田信玄が大きな堤を築かせている。人足が足りないという。', [
          Choice.h('人足として堤を築く', '辛い仕事だ。村は水から守られる', () {
            g.l.hp -= 15;
            g.l.gold += 3;
            g.l.net += 2;
            g.mark('武田信玄の命で、釜無川の堤を築いた');
            return '何か月も石を運んだ。堤ができた年、川はあふれなかった。';
          }),
          Choice.h('自分の田を優先する', '暮らしは守れる。役人の目は厳しい', () => '自分の田の世話を続けた。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1542 && _yr(g, a) <= 1560,
    ),

    SceneDef(
      'h_salt',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['甲斐', '信濃']) && g.active,
      (g, next) {
        g.ask('敵に塩を送る', '今川と北条に塩の道を止められ、甲斐の塩が尽きた。そこへ、宿敵の上杉謙信が塩を送ってきたという。', [
          Choice.h('越後の塩を、ありがたく受け取る', '敵の情けを受ける。暮らしは救われる', () {
            g.l.hp = g.l.hp + 15 > g.l.maxhp ? g.l.maxhp : g.l.hp + 15;
            g.j(6);
            g.mark('上杉謙信が送った塩で、飢えをしのいだ');
            return '越後の塩は、少ししょっぱかった。';
          }),
          Choice.h('敵の施しは受けない', '意地は通る。体はもたない', () {
            g.l.hp -= 15;
            return '塩のない飯を、黙って食べた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1568) || _at(g, a, 1569),
    ),

    SceneDef(
      'h_ichiryo_gusoku',
      15,
      55,
      (g) => 20,
      (g) =>
          _inRegion(g, ['土佐']) &&
          g.l.rank == 0 &&
          !g.l.female &&
          !g.hasFlag('priesthood') &&
          (g.fa['長宗我部']?.alive ?? false) &&
          g.active,
      (g, next) {
        g.ask('一領具足', '長宗我部元親は、田を耕しながら槍と具足を畦に置き、触れがあればすぐ駆けつける百姓を集めている。', [
          Choice.h('一領具足になる', '百姓のまま戦に出る。手柄を立てれば取り立てられる', () {
            g.setFlag('ichiryo');
            g.l.lord = '長宗我部';
            g.l.rank = 1;
            if (g.l.maxRank < 1) g.l.maxRank = 1;
            g.l.fav = 25;
            g.mark('長宗我部元親の一領具足となった');
            return '田の畦に、槍と具足を置いた。';
          }),
          Choice.h('百姓に専念する', '戦には出ない', () => '鍬だけを握ることにした。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1562 && _yr(g, a) <= 1584,
    ),

    SceneDef(
      'h_shikanosuke',
      15,
      60,
      (g) => 20,
      (g) => _inRegion(g, ['出雲']) && g.active && !g.hasFlag('priesthood'),
      (g, next) {
        g.ask(
          '山中鹿介',
          '滅んだ尼子家の家臣・山中鹿介が、「願わくば我に七難八苦を与えたまえ」と三日月に祈り、尼子の再興を誓っている。',
          [
            Choice.h('尼子再興の軍に加わる', '忠義の物語に身を投じる。勝ち目は薄い', () {
              if (g.rng.chance(.2)) {
                g.die('尼子再興の戦いに加わり、上月城で果てた', 'senshi');
                return '上月城で、鹿介とともに最後まで戦った。';
              }
              g.l.fame += 12;
              g.l.bu = _c(g.l.bu + 2);
              g.setFlag('amago_loyal');
              g.mark('山中鹿介とともに、尼子再興のために戦った');
              return '再興はならなかった。だが、鹿介の背中は忘れられない。';
            }),
            Choice.h('毛利の世で生きる', '勝った側で暮らす', () => '鹿介の噂は、遠くに聞くだけにした。'),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _yr(g, a) >= 1569 && _yr(g, a) <= 1578,
    ),

    SceneDef(
      'h_masamune',
      15,
      70,
      (g) => 20,
      (g) =>
          _inRegion(g, ['陸奥', '出羽', '会津', '常陸']) &&
          (g.fa['伊達']?.alive ?? false) &&
          g.l.rank < 8 &&
          g.active,
      (g, next) {
        g.ask('独眼竜', '伊達の若き当主・政宗が、片目の竜と恐れられながら奥羽を切り従えている。', [
          Choice.h('政宗の軍に馳せ参じる', '勢いのある主だ。戦は激しい', () {
            final l = g.l;
            if (l.lord != '伊達') {
              l.lord = '伊達';
              l.rank = l.rank < 1 ? 1 : l.rank;
              if (l.rank > l.maxRank) l.maxRank = l.rank;
              l.fav = 25;
              l.ronin = false;
            }
            g.meet('主君', '伊達政宗', 40);
            g.mark('独眼竜・伊達政宗の軍に加わった');
            return '政宗は、ただ一つの目でこちらを見据えた。';
          }),
          Choice.h('戦火を避けて暮らす', '奥羽の戦は激しい。巻き込まれずに済むか', () => '戦の噂から、耳をふさいだ。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1584 && _yr(g, a) <= 1590,
    ),

    SceneDef(
      'h_azuchi_build',
      15,
      70,
      (g) => 20,
      (g) =>
          _inRegion(g, ['近江', '尾張', '美濃', '山城']) && g.l.rank <= 1 && g.active,
      (g, next) {
        g.ask('安土城', '信長が、琵琶湖のほとりに天主のそびえる城を築いている。大石を運ぶ人足、腕のいい大工や絵師が集められている。', [
          Choice.h('城づくりに加わる', '見たこともない城を、自分の手で建てる。石の下敷きになる者もいる', () {
            if (g.rng.chance(.04)) {
              g.die('安土城の普請で、大石の下敷きになった', 'sai');
              return '綱が切れ、大石が転がり落ちてきた。';
            }
            g.l.gold += 8;
            g.l.hp -= 10;
            g.mark('安土城の普請に加わった');
            return '天主が完成したとき、金色の瓦が日に輝いた。';
          }),
          Choice.h('見物だけする', '話の種にはなる', () {
            g.j(3);
            return '遠くから、天主を見上げた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1576 && _yr(g, a) <= 1579,
    ),

    SceneDef(
      'h_rakuichi',
      15,
      80,
      (g) => 20,
      (g) => g.hasFlag('way_merchant') && g.l.rank == 0,
      (g, next) {
        g.ask('楽市楽座', '織田の城下では「座」がなくなり、誰でも自由に商いができるという。', [
          Choice.h('織田の城下に店を移す', '新しい客がいる。古いしがらみは捨てる', () {
            g.l.gold += 15;
            g.l.flags.remove('za');
            g.mark('楽市の城下に店を移した');
            return '新しい城下で、店は繁盛した。';
          }),
          Choice.h('慣れた町に留まる', '得意先は守れる', () => '慣れた町で、商いを続けた。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1567 && _yr(g, a) <= 1582,
    ),

    SceneDef(
      'h_kenchi',
      15,
      84,
      (g) => 20,
      (g) =>
          g.l.rank == 0 &&
          !g.hasFlag('priesthood') &&
          !g.hasFlag('way_merchant') &&
          !g.hasFlag('way_outlaw') &&
          g.active,
      (g, next) {
        g.ask('太閤検地', '役人が竿を持って村に来た。田の広さを測り直し、年貢を決め直すという。', [
          Choice.h('隠し田も正直に申し出る', '後ろ暗いところはなくなる。年貢は増える', () {
            g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
            g.setFlag('honest_kenchi');
            return '正直に申し出た。役人は、少し意外そうな顔をした。';
          }),
          Choice.h('山あいの田は黙っておく', '年貢は軽くなる。見つかれば重い罰', () {
            if (g.rng.chance(.25)) {
              g.l.hp -= 20;
              g.l.gold = 0;
              return '隠し田が見つかり、きつい罰を受けた。';
            }
            g.l.gold += 4;
            return '山あいの田は、帳面に載らなかった。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1583 && _yr(g, a) <= 1594,
    ),

    SceneDef(
      'h_mibun',
      15,
      84,
      (g) => 20,
      (g) =>
          (g.l.rank <= 1 || g.l.ronin) &&
          !g.l.female &&
          !g.hasFlag('priesthood') &&
          g.active,
      (g, next) {
        g.ask('身分を定める令', '武士は武士、百姓は百姓、町人は町人。これからは身分を変えられなくなるという。', [
          Choice.h('武士として生きる', '刀を差して生きる。主を失えば浪人だ', () {
            g.setFlag('chose_samurai');
            g.mark('身分を定める令に、武士として生きると決めた');
            return '武士として生きると決めた。';
          }),
          Choice.h('百姓・町人として生きる', '刀は捨てる。戦に駆り出されることはない', () {
            g.setFlag('chose_commoner');
            g.mark('身分を定める令に、刀を置いて生きると決めた');
            return '刀を置いて生きると決めた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1591 && _yr(g, a) <= 1592,
    ),

    SceneDef(
      'h_martyrs',
      15,
      84,
      (g) => 20,
      (g) =>
          g.hasFlag('kirishitan') &&
          _inRegion(g, ['肥前', '豊後', '薩摩', '山城', '摂津']),
      (g, next) {
        g.ask('二十六人の殉教', '京や大坂で捕らえられたキリシタン二十六人が、長崎まで歩かされ、十字架にかけられることになった。', [
          Choice.h('長崎の丘で祈りを捧げる', '信仰を示す。役人に目をつけられる', () {
            if (g.rng.chance(.1)) {
              g.die('殉教者に祈りを捧げ、捕らえられて処刑された', 'seppuku');
              return '祈りの声は、役人の耳にも届いていた。';
            }
            g.mark('長崎の丘で、二十六人の殉教者に祈りを捧げた');
            return '西坂の丘で、ひざまずいて祈った。';
          }),
          Choice.h('家で静かに祈る', '身は守られる', () => '戸を閉め、声を殺して祈った。'),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1597),
    ),

    SceneDef(
      'h_echizen_ikko',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['越前']) && g.l.rank <= 1 && g.active,
      (g, next) {
        g.ask('越前一向一揆', '朝倉が滅んだあと、越前は一向門徒が治める国になった。そこへ織田の大軍が攻め寄せてきた。', [
          Choice.h('門徒とともに山に立てこもる', '信心を貫く。織田は容赦しない', () {
            if (g.rng.chance(.3)) {
              g.die('越前の一向一揆で、織田の掃討に遭って討たれた', 'senshi');
              return '山狩りの兵に見つかった。';
            }
            g.l.hp -= 20;
            g.mark('越前の一向一揆を、山に潜んで生き延びた');
            return '山に潜み、どうにか生き延びた。';
          }),
          Choice.h('織田に降る', '命は守れる。門徒仲間からは裏切り者と呼ばれる', () {
            g.j(-6);
            return '村ごと、織田に降った。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1575),
    ),

    SceneDef(
      'h_kyoto_jouraku',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['山城', '摂津', '近江']) && g.active,
      (g, next) {
        g.ask('上洛', '尾張の織田信長が、将軍の弟を奉じて大軍で京へ入ってくる。都の人々は、乱暴されるのではと怯えている。', [
          Choice.h('通りに出て行列を見る', '天下が変わる瞬間を見られる', () {
            g.setFlag('saw_jouraku');
            g.j(3);
            g.mark('織田信長の上洛の行列を、京の通りで見た');
            return '行列は整然としていた。一銭でも盗んだ兵は、その場で斬られたという。';
          }),
          Choice.h('家に籠もって戸を閉める', '用心に越したことはない', () => '戸を閉め、嵐が過ぎるのを待った。'),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1568),
    ),

    SceneDef(
      'h_tanegashima',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['薩摩', '豊後', '肥前']) && g.active,
      (g, next) {
        g.ask('鉄砲伝来', '種子島に流れ着いた南蛮人が、火を噴く筒を持っていたという。島の殿様は、それを大金で買い取った。', [
          Choice.h('種子島へ見に行く', '世の中を変える道具かもしれない', () {
            g.l.gun = true;
            g.mark('種子島に伝わったばかりの鉄砲を、この目で見た');
            return '轟音とともに、遠くの的が砕けた。世の中が変わる、と思った。';
          }),
          Choice.h('噂を聞くだけにする', '海の向こうの話だ', () => '妙な話だと思った。'),
        ], after: next);
      },
      ageOk: (g, a) => _yr(g, a) >= 1543 && _yr(g, a) <= 1545,
    ),
  ];
}
