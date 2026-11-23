import 'childhood.dart';
import 'game.dart';
import 'history.dart';
import 'life.dart';
import 'peace.dart';
import 'rng.dart';

/// 歴史の分かれ道（世界線）。
///
/// プレイヤーが史実の分岐点で歴史を変えると（`history_*` の旗）、そこから先は別の世界線になる。
/// - `real`     史実どおり
/// - `imagawa`  桶狭間で今川義元が生き延びた世（1560〜）
/// - `nobunaga` 本能寺で信長が生き延びた世（1582〜）
/// - `akechi`   山崎で明智光秀が勝った世（1582〜）
/// - `west`     関ヶ原で西軍が勝った世（1600〜）
///
/// 世界線ごとに、起きない史実の出来事（[kSkipEvents]）と、出ない史実の岐路（[kSkipScenes]）を決め、
/// 代わりに、その世界線だけの出来事（[kAltHistory]）と岐路（[buildAltScenes]）を置く。

/// 画面や文に出す家の名。勢力の内部の名（`Faction.name`・`Life.lord`）は変えず、
/// 呼び名だけを時代に合わせる: 松平は1566年の暮れに徳川へ改めた（今川が生き延びた世では、松平は今川の下にいるので改めない）。
String houseName(Game g, String? name) {
  if (name == null) return '';
  if (name == '松平' && g.year >= 1567 && worldLine(g) != 'imagawa') {
    return '徳川';
  }
  // 本能寺のあとの '織田' は、羽柴秀吉が引き継いだ家。秀吉が豊臣の姓を賜った1586年から豊臣と呼ぶ
  // （秀吉の天下にならない世と、プレイヤーが織田の当主のときは織田のまま）。
  if (name == '織田' &&
      g.year >= 1586 &&
      const {'real', 'west'}.contains(worldLine(g)) &&
      !(g.l.lord == '織田' && g.l.rank >= 8)) {
    return '豊臣';
  }
  return name;
}

String worldLine(Game g) {
  if (g.hasFlag('history_okehazama')) return 'imagawa';
  if (g.hasFlag('history_yamazaki')) return 'akechi';
  if (g.hasFlag('history_honnoji')) return 'nobunaga';
  if (g.hasFlag('history_sekigahara')) return 'west';
  return 'real';
}

const kLineNames = {
  'real': '史実どおりの世',
  'imagawa': '今川義元が生き延びた世',
  'nobunaga': '織田信長が生き延びた世',
  'akechi': '明智光秀が天下を取った世',
  'west': '西軍が勝った世',
};

/// 秀吉が天下を取ったことを前提にした出来事（信長の世・明智の世では起きない）。
const _hideyoshiEvents = {
  'shizugatake',
  'osakajo',
  'rikyu',
  'bunroku',
  'katanagari',
  'hitobarai',
  'kitano',
  'edo',
  'fushimi',
  'keicho_jishin', // 伏見城の天守が崩れた、という文を含む
  'keicho',
  'toshiie',
  'sekigahara',
};

/// 徳川の世（関ヶ原で東軍が勝ち、江戸に幕府が開かれた世）を前提にした、1600年からの出来事。
/// 歴史が変わった世では起きない（天災・琉球・遣欧の船・飢饉・龍造寺の本家の絶えは、どの世でも起きる）。
const _edoEvents = {
  'kaieki_1600',
  'uesugi_yonezawa',
  'satake_akita',
  'shimazu_ando',
  'edo_bakufu',
  'hidetada',
  'chosen_shisetsu',
  'kinkyo',
  'takayama',
  'osaka_fuyu',
  'osaka_natsu',
  'ikkoku_ichijo',
  'buke_shohatto',
  'ieyasu_death',
  'fukushima',
  'genna_junkyo',
  'mogami_kaieki',
  'iemitsu',
  'hosho',
  'kaikin',
  'sankin',
  'shimabara',
  'hara_jo',
  'sakoku',
  'dejima',
  'denpata',
  'iemitsu_death',
  'keian',
  'meireki',
};

const kSkipEvents = <String, Set<String>>{
  'imagawa': {
    ..._edoEvents,
    'kiyosu',
    'mikawa_ikko',
    'inabayama',
    'jouraku',
    'kanegasaki',
    'anegawa',
    'hiei',
    'mikatagahara',
    'nagashima',
    'nagashino',
    'azuchi',
    'hisahide',
    'arioka',
    'azuchi_shuron',
    'ishiyama',
    'tottori',
    'takamatsu',
    'honnoji',
    'tensho_jingo',
    'kanpaku',
    'kyushu',
    'odawara',
    'hideyoshi_death',
    'shingen_death',
    ..._hideyoshiEvents,
  },
  'nobunaga': {
    ..._hideyoshiEvents,
    ..._edoEvents,
    'takamatsu',
    'tensho_jingo',
    // 伴天連追放・安土での死は信長の世に合わないので、この世だけの出来事に置き換える
    'kyushu',
    'hideyoshi_death',
  },
  'akechi': {
    ..._hideyoshiEvents,
    ..._edoEvents,
    // 「光秀は山崎で秀吉に敗れ」の文を含むので、この世だけの出来事に置き換える
    'honnoji',
    'kanpaku',
    'kyushu',
    'odawara',
    'hideyoshi_death',
  },
  'west': {'sekigahara', ..._edoEvents},
};

/// 秀吉の天下を前提にした岐路（信長の世・明智の世では出ない）。
const _hideyoshiScenes = {
  'h_yamazaki',
  'h_shizugatake',
  'h_rikyu',
  'h_hideyoshi_death',
  'h_hideyoshi_again',
  'h_kenchi',
  'h_katanagari',
  'h_mibun',
  'h_bateren',
  'h_martyrs',
  'h_chosen',
  'h_sekigahara',
  'h_e_shiroshozoku',
  'h_e_kasai_osaki',
  'h_e_edo',
  'h_e_ishigakiyama',
  'h_w_kiyosu_kaigi',
  'h_w_kitano',
  'h_w_shikoku',
  'h_w_neshirozaka',
  'h_w_hetsugigawa',
  'h_l_kitano',
  'h_l_daibutsu',
  'h_l_fushimi',
  'h_l_oichi',
  'h_l_nene',
  'h_l_koya',
};

const kSkipScenes = <String, Set<String>>{
  'imagawa': {
    ..._hideyoshiScenes,
    ...kPeaceEdoScenes,
    'h_tokichiro',
    'h_anegawa',
    'h_odani',
    'h_nagashino',
    'h_tenmokuzan',
    'h_odawara',
    'h_ikko_nagashima',
    'h_ieyasu_again',
    'h_azuchi_build',
    'h_rakuichi',
    'h_echizen_ikko',
    'h_kyoto_jouraku',
    'h_mikatagahara',
    'honnoji',
    'hiei',
    'h_e_erinji',
    'h_e_tensho_jingo',
    'h_e_ueda',
    'h_e_okazaki',
    'h_e_mikawa_ikko',
    'h_w_sunomata',
    'h_w_kannonji',
    'h_w_kanegasaki',
    'h_w_nagahama',
    'h_w_ishiyama',
    'h_w_arioka',
    'h_w_sakai',
    'h_w_ichijodani_fall',
    'h_w_takamatsu',
    'h_c_jouraku',
    'h_c_anegawa',
    'h_c_hiei',
    'h_c_ichijodani',
    'h_c_ikko',
    'h_c_nagashino',
    'h_c_azuchi',
    'h_c_erinji',
    'h_c_honnoji',
    'h_l_sakai',
    'h_l_chaya',
    'h_l_ishiyama',
    'h_l_shuron',
    'h_r_jouraku',
    'h_r_hiei',
    'h_r_nagashino',
    'h_r_honnoji',
    // 義元の死・今川の没落を前提にした岐路
    'h_e_sunpu_1568',
    'h_l_jukeini',
  },
  'nobunaga': {
    ..._hideyoshiScenes,
    ...kPeaceEdoScenes,
    'h_e_tensho_jingo',
    'h_e_ueda',
    'h_l_chaya',
  },
  'akechi': {..._hideyoshiScenes, 'h_odawara', ...kPeaceEdoScenes},
  // 西軍が勝った世には、徳川の世を前提にした泰平の岐路（`peace.dart`）は出ない。
  'west': {...kPeaceEdoScenes},
};

/// 小さな分岐: 世の中全体は史実のまま、一部の出来事だけが変わる（旗 → 出さない岐路）。
/// 例: 長篠で武田が兵を退いた（`history_nagashino`）→ 1582年の武田の滅亡にまつわる岐路は出ない。
const kFlagSkipScenes = <String, Set<String>>{
  'history_nagashino': {
    'h_tenmokuzan',
    'h_e_erinji',
    'h_c_erinji',
    'h_e_tensho_jingo',
  },
  // 家康が江戸に入らないので、江戸の町・江戸の屋敷を前提にした泰平の岐路は出ない。
  'history_odawara': {'h_e_edo', ...kPeaceEdoTownScenes},
  // 川中島で信玄が討たれた: 信玄が生きていることを前提にした岐路は出ない。
  'history_kawanakajima': {
    'h_mikatagahara',
    'h_e_mimase',
    'h_e_sunpu_1568',
    'h_r_shingen',
  },
};

/// 小さな分岐で起きない年表の出来事（旗 → 出来事の id）。
const kFlagSkipEvents = <String, Set<String>>{
  'history_nagashino': {'tensho_jingo'},
  // 小田原で北条が早く降って残った: 家康の関東移封（北条の旧領へ）は起きない。
  // 家康が江戸に入っていないので、幕府は駿府に開かれる（`b_sunpu_bakufu`・`b_sankin_sunpu` に置き換える）。
  'history_odawara': {'edo', 'edo_bakufu', 'sankin', 'meireki'},
  'history_kawanakajima': {'mimasetoge', 'mikatagahara'},
};

bool sceneSkippedInLine(Game g, String id) {
  if (kSkipScenes[worldLine(g)]?.contains(id) ?? false) return true;
  for (final e in kFlagSkipScenes.entries) {
    if (g.hasFlag(e.key) && e.value.contains(id)) return true;
  }
  return false;
}

bool eventSkippedInLine(Game g, String id) {
  if (kSkipEvents[worldLine(g)]?.contains(id) ?? false) return true;
  for (final e in kFlagSkipEvents.entries) {
    if (g.hasFlag(e.key) && e.value.contains(id)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------
// 変わった世界線だけの出来事
// ---------------------------------------------------------------------

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

/// 明智の世: 織田の勢力の半ばを引き継いで、明智家が立つ。光秀に味方した織田の家臣は明智家に移る。
void _riseAkechi(Game g) {
  if (g.fa['明智'] != null) return;
  final oda = _f(g, '織田');
  final base = oda == null ? 25.0 : oda.power * .5;
  if (oda != null && !_ruled(g, '織田')) {
    oda.power = (oda.power * .5).clamp(3, 140).toDouble();
  }
  g.fa['明智'] = Faction('明智', base < 10 ? 10 : base);
  final l = g.l;
  if (l.lord == '織田' && l.rank < 8 && g.hasFlag('history_yamazaki')) {
    l.lord = '明智';
    g.meet('主君', '明智光秀', 55);
  }
}

final kAltHistory = <HistEvent>[
  // ---- 今川の世 ----
  HistEvent('x_owari', 1561, only: 'imagawa', (g) {
    final t = _fall(g, '織田', '今川') ? '織田家は滅んだ。' : '織田家は追いつめられた。';
    return '桶狭間の勝ちに乗った今川義元が、清洲城を落とした。$t三河の松平元康は、今川の先手として尾張に入った。';
  }),
  HistEvent('x_mino', 1564, only: 'imagawa', (g) {
    _cut(g, '斎藤', .8);
    _grow(g, '今川', 6);
    return '今川の大軍が、尾張から美濃へ攻め入った。';
  }),
  HistEvent('x_mino_fall', 1567, only: 'imagawa', (g) {
    if (_fall(g, '斎藤', '今川')) {
      return '美濃の稲葉山城が今川の手に落ち、斎藤家は滅んだ。駿河・遠江・三河・尾張・美濃、五か国の主が生まれた。';
    }
    return null;
  }),
  HistEvent('x_imagawa_jouraku', 1568, only: 'imagawa', (g) {
    _fall(g, '六角', '今川');
    _cut(g, '三好', .6);
    _grow(g, '今川', 10);
    return '今川義元が、足利義昭を奉じて京へ上った。「海道一の弓取り」が、ついに都に旗を立てた。';
  }),
  HistEvent('x_takeda_break', 1570, only: 'imagawa', (g) {
    _grow(g, '武田', 5);
    _cut(g, '今川', .9);
    return '武田信玄が今川との盟約を破り、駿河へ攻め入った。';
  }),
  HistEvent('x_shingen_death', 1573, only: 'imagawa', (g) {
    _cut(g, '武田', .8);
    return '武田信玄が陣中で没した。今川義元は将軍を支え、室町の世はなお続いた。';
  }),
  HistEvent('x_yoshimoto_death', 1575, only: 'imagawa', (g) {
    _cut(g, '今川', .8);
    return '今川義元が京で世を去った。跡を継いだ氏真は、和歌と蹴鞠を好む穏やかな当主だった。';
  }),
  HistEvent('x_imagawa_split', 1580, only: 'imagawa', (g) {
    _cut(g, '今川', .8);
    _grow(g, '松平', 8);
    return '三河の松平元康が今川から離れ、独り立ちした。今川の天下は、ゆっくりとほどけ始めた。';
  }),
  HistEvent('x_sengoku_goes_on', 1585, only: 'imagawa', (g) {
    return '天下はいまだ定まらず、今川・武田・北条・上杉・毛利が、それぞれの国を固めて睨み合っている。';
  }),
  HistEvent('x_imagawa_1600', 1600, only: 'imagawa', (g) {
    return '乱世はなお続いている。もし桶狭間で義元が討たれていたら――そう語る者は、もう誰もいない。';
  }),

  // ---- 信長の世 ----
  HistEvent('x_mori_kneel', 1583, only: 'nobunaga', (g) {
    _cut(g, '毛利', .6);
    _grow(g, '織田', 10);
    return '本能寺の変をしのいだ信長は、中国へ大軍を進め、毛利を膝下に降した。';
  }),
  HistEvent('x_osaka_nobunaga', 1584, only: 'nobunaga', (g) {
    return '信長が、石山本願寺の跡に安土をしのぐ大城を築かせ、安土から大坂へ移った。';
  }),
  HistEvent('x_nobutada', 1586, only: 'nobunaga', (g) {
    _cut(g, '島津', .7);
    return '織田信忠が大軍を率いて九州へ渡った。';
  }),
  HistEvent('x_kyushu_nobunaga', 1587, only: 'nobunaga', (g) {
    _cut(g, '島津', .6);
    _cut(g, '大友', .8);
    return '九州の島津が、織田信忠の大軍の前に降った。';
  }),
  HistEvent('x_fleet', 1588, only: 'nobunaga', (g) {
    return '信長が、南蛮の国々と交わるため、堺と長崎から大きな船団を送り出した。';
  }),
  HistEvent('x_ming', 1592, only: 'nobunaga', (g) {
    return '信長が、明国へ使者を送った。海の向こうと戦をするのではなく、商いをするつもりらしい。';
  }),
  HistEvent('x_nobunaga_death', 1598, only: 'nobunaga', (g) {
    return '老いた織田信長が、大坂の城で世を去った。「人間五十年」と謡った男は、六十を越えるまで生きた。';
  }),
  HistEvent('x_nobunaga_1600', 1600, only: 'nobunaga', (g) {
    return '織田信忠のもとで、天下は静かに新しい世紀を迎えた。関ヶ原という地名を、知る者はほとんどいない。';
  }),

  // ---- 明智の世 ----
  HistEvent('x_honnoji_akechi', 1582, only: 'akechi', (g) {
    final t = g.hasFlag('history_nagashino')
        ? ''
        : (_fall(g, '武田', '織田') ? '春、武田勝頼が天目山で自害し、武田家は滅んだ。' : '');
    _riseAkechi(g);
    return '$t夏、明智光秀が本能寺で織田信長を討ち、山崎で羽柴秀吉を退けた。光秀の天下は、三日では終わらなかった。';
  }),
  HistEvent('x_akechi_rule', 1583, only: 'akechi', (g) {
    _cut(g, '織田', .6);
    _grow(g, '明智', 8);
    return '明智光秀が京で政を整え始めた。敗れた羽柴秀吉は、播磨へ退いて機をうかがっている。';
  }),
  HistEvent('x_akechi_kinai', 1585, only: 'akechi', (g) {
    return '光秀が、細川・筒井らを従えて畿内を固めた。朝廷は光秀に、征夷大将軍の位を与えた。';
  }),
  HistEvent('x_harima', 1587, only: 'akechi', (g) {
    _cut(g, '毛利', .9);
    return '羽柴秀吉が毛利と結び、再び東へ攻め上ったが、播磨で明智の軍勢に阻まれた。';
  }),
  HistEvent('x_four', 1590, only: 'akechi', (g) {
    return '天下は、明智・羽柴・徳川・北条の四つに割れたまま、睨み合いが続いている。';
  }),
  HistEvent('x_mitsuhide_death', 1598, only: 'akechi', (g) {
    return '明智光秀が世を去った。「三日天下」と呼ばれるはずだった男の治世は、十六年に及んだ。';
  }),
  HistEvent('x_akechi_1600', 1600, only: 'akechi', (g) {
    return '光秀の子らの世に、徳川家康が東から兵を挙げた。天下の行方は、まだ誰にも分からない。';
  }),

  // ---- 西軍が勝った世 ----
  HistEvent('x_west', 1600, only: 'west', (g) {
    _cut(g, '松平', .5);
    _grow(g, '毛利', 10);
    return '関ヶ原で、石田三成の西軍が徳川家康を破った。豊臣の世は、もうしばらく続くことになった。';
  }),
  // ---- 2026-11-24 追加: 西軍が勝った世の、1601年からの続き ----
  HistEvent('x_west_kanto', 1601, only: 'west', (g) {
    _cut(g, '松平', .7);
    _grow(g, '織田', 8);
    return '敗れた徳川家康は関東へ退き、領地を大きく削られた。大坂では、石田三成ら奉行衆が幼い秀頼を戴いて政を執った。';
  }),
  HistEvent('x_west_ieyasu', 1603, only: 'west', (g) {
    return '徳川家康が、江戸で髪を下ろして隠居した。征夷大将軍の位に就く者は、ついに現れなかった。';
  }),
  HistEvent('x_west_kanpaku', 1608, only: 'west', (g) {
    _grow(g, '織田', 6);
    return '年頃になった豊臣秀頼が、関白に任じられた。大坂城のまわりには、諸国の大名の屋敷が軒を連ねた。';
  }),
  HistEvent('x_west_rift', 1612, only: 'west', (g) {
    _cut(g, '毛利', .9);
    return '豊臣の政を支える奉行衆と、毛利・上杉ら大老たちのあいだに溝が生まれた。戦にはならなかったが、大坂の評定は長引くようになった。';
  }),
  HistEvent('x_west_ieyasu_death', 1616, only: 'west', (g) {
    return '徳川家康が、江戸で世を去った。関ヶ原の負けを、最期まで口にしなかったという。';
  }),
  HistEvent('x_west_trade', 1624, only: 'west', (g) {
    return '豊臣の朱印を携えた船が、堺と博多から南の海へ盛んに出ていった。この世では、海は閉じられなかった。';
  }),
  HistEvent('x_west_1640', 1640, only: 'west', (g) {
    return '豊臣の世は、秀頼の子の代へ移った。大坂は天下の台所として栄え、戦を知る者は少なくなった。';
  }),
  // ---- 信長が生き延びた世の続き ----
  HistEvent('x_nobu_nobutada', 1603, only: 'nobunaga', (g) {
    _grow(g, '織田', 6);
    return '織田信忠が、朝廷から太政大臣に任じられた。征夷大将軍の位を口にする者は、もういなかった。';
  }),
  HistEvent('x_nobu_nanban', 1609, only: 'nobunaga', (g) {
    return '安土と大坂に、南蛮の学問を教える学び舎が建った。伴天連の教えは禁じられず、寺と南蛮寺が同じ町に並んだ。';
  }),
  HistEvent('x_nobu_ieyasu_death', 1616, only: 'nobunaga', (g) {
    return '織田の天下を東で支え続けた徳川家康が、世を去った。';
  }),
  HistEvent('x_nobu_fleet', 1620, only: 'nobunaga', (g) {
    return '織田の船団が、呂宋や暹羅の湊に日ノ本の者の町を築いた。海を渡る者は、年ごとに増えた。';
  }),
  HistEvent('x_nobu_hidenobu', 1630, only: 'nobunaga', (g) {
    return '織田信忠が世を去り、子の秀信が跡を継いだ。本能寺の夜を知る者は、もうわずかになった。';
  }),
  HistEvent('x_nobu_1645', 1645, only: 'nobunaga', (g) {
    return '織田の世は三代を数えた。大坂の湊には、異国の帆が絶えることがなかった。';
  }),
  // ---- 明智の世の続き ----
  HistEvent('x_ake_standoff', 1601, only: 'akechi', (g) {
    _cut(g, '松平', .9);
    return '東から攻め上った徳川の軍勢と、明智の軍勢が美濃で睨み合った。大きな戦にはならず、冬を前に双方が兵を退いた。';
  }),
  HistEvent('x_ake_peace', 1604, only: 'akechi', (g) {
    return '明智と徳川が和議を結んだ。西は明智、東は徳川。天下は二つのまま、戦だけが遠のいた。';
  }),
  HistEvent('x_ake_ieyasu_death', 1616, only: 'akechi', (g) {
    return '徳川家康が世を去った。東の国々は秀忠が継ぎ、和議は破られなかった。';
  }),
  HistEvent('x_ake_kyoto', 1622, only: 'akechi', (g) {
    return '明智の治める京で、古い寺社の再興が相次いだ。光秀の定めた掟は、子らの代にも守られた。';
  }),
  HistEvent('x_ake_1640', 1640, only: 'akechi', (g) {
    return '東西ふたつの天下は、互いに使者を送り合うようになった。境の関所を、商人の荷が行き来した。';
  }),
  // ---- 今川の世の続き ----
  HistEvent('x_ima_league', 1608, only: 'imagawa', (g) {
    return '戦に倦んだ今川・武田・北条が、ふたたび三国の盟約を結んだ。東国の戦は、ようやく下火になった。';
  }),
  HistEvent('x_ima_ujizane', 1614, only: 'imagawa', (g) {
    _cut(g, '今川', .9);
    return '今川氏真が世を去った。和歌と蹴鞠の当主のもとで、今川の国はゆるやかに小さくなっていた。';
  }),
  HistEvent('x_ima_west', 1620, only: 'imagawa', (g) {
    return '西国では、毛利と大友、島津が境を争い続けていた。乱世は、百五十年を越えた。';
  }),
  HistEvent('x_ima_hyojo', 1630, only: 'imagawa', (g) {
    return '足利の将軍のもとで、諸国の大名が京に集い、国の境を定める評定が開かれた。刀を抜かずに境を決める、初めての試みだった。';
  }),
  HistEvent('x_ima_1645', 1645, only: 'imagawa', (g) {
    return '大きな戦は絶えて久しい。天下人のいないまま、国々はそれぞれの主のもとで静かに暮らしている。';
  }),
];

// ---------------------------------------------------------------------
// 変わった世界線だけの岐路（`h_x_`）
// ---------------------------------------------------------------------

int _yr(Game g, int a) => g.l.startYear + a;
bool _inLine(Game g, String line) => worldLine(g) == line;
bool _inRegion(Game g, List<String> rs) => rs.contains(g.l.region);
int _c(int v) => clampInt(v, 0, 100);

List<SceneDef> buildAltScenes() => [
  // ---------------- 今川の世 ----------------
  SceneDef(
    'h_x_oda_orphan',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'imagawa') &&
        _f(g, '織田') == null &&
        (_inRegion(g, ['尾張', '美濃']) ||
            g.l.lord == '織田' ||
            g.hasFlag('met_nobunaga')) &&
        g.active,
    (g, next) {
      g.ask(
        '落ち延びた若殿',
        '清洲が落ちた夜、織田の若い侍が、幼い子を抱いて戸口に立っていた。「信長さまのお子だ。どうか、かくまってほしい」',
        [
          Choice.h('子をかくまう', '見つかれば命はない。織田の血はつながる', () {
            if (g.rng.chance(.08)) {
              g.die('織田の遺児をかくまったことが露見し、処刑された', 'seppuku');
              return '今川の侍が、戸を蹴破って入ってきた。';
            }
            g.setFlag('hid_oda_heir');
            g.meet('織田の遺児', '信長の忘れ形見', 60);
            g.mark('滅んだ織田家の幼い遺児をかくまった');
            return '子を納戸の奥にかくまった。その子は、声ひとつ立てなかった。';
          }),
          Choice.h('今川に知らせる', '恩賞が出るかもしれない。夢見は悪くなる', () {
            g.l.gold += 15;
            g.j(-10);
            return '今川の陣に知らせた。銭を受け取ったが、あの子の顔が忘れられない。';
          }),
          Choice.h('戸を閉ざす', '巻き込まれずに済む', () => '戸を閉め、息をひそめた。足音は遠ざかっていった。'),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => _yr(g, a) == 1561,
  ),

  SceneDef(
    'h_x_imagawa_kana',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'imagawa') &&
        // 「昔の主」は織田。三河はもとから今川領、美濃が落ちるのは1567年
        _inRegion(g, ['尾張']) &&
        g.l.rank <= 2 &&
        g.active,
    (g, next) {
      g.ask('今川の掟', '新しい主・今川家の役人が村に来て、「仮名目録」という掟を読み上げた。勝手な争いは、喧嘩両成敗だという。', [
        Choice.h('新しい掟に従う', '争いは減る。古いしきたりは捨てる', () {
          g.l.net += 2;
          g.setFlag('imagawa_subject');
          return '掟に従った。村の争いは、目に見えて減った。';
        }),
        Choice.h('昔の主を懐かしむ', '心は織田に残る。役人ににらまれる', () {
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          g.setFlag('oda_loyal_heart');
          return '口には出さず、尾張の大うつけの殿さまを思い出した。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) >= 1562 && _yr(g, a) <= 1566,
  ),

  SceneDef(
    'h_x_imagawa_jouraku',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'imagawa') &&
        (_inRegion(g, ['山城', '近江', '駿河']) || g.l.lord == '今川') &&
        g.active,
    (g, next) {
      final l = g.l;
      final retainer = l.lord == '今川' && l.rank >= 1;
      g.ask(
        '義元の上洛',
        retainer
            ? '主・今川義元が、亡き将軍の弟・足利義昭を奉じて京へ上る。行列に加われという。'
            : '駿河の今川義元が、公家のような装いで京へ上ってくる。お歯黒をつけた大名だと噂されている。',
        [
          Choice.h(
            retainer ? '行列の先頭を務める' : '行列を見に行く',
            retainer ? '晴れの役目。都で名が知れる' : '天下が変わる瞬間を見られる',
            () {
              if (retainer) {
                l.merit += 15;
                l.fame += 10;
                l.fav = _c(l.fav + 8);
              } else {
                g.j(3);
              }
              g.mark(retainer ? '今川義元の上洛で、行列の先頭を務めた' : '今川義元の上洛を、この目で見た');
              return '雅な行列だった。誰もが「海道一の弓取り」の天下が来たと思った。';
            },
          ),
          Choice.h('関わらない', '何も変わらない', () => '都の騒ぎを、遠くに聞いた。'),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => _yr(g, a) == 1568,
  ),

  SceneDef(
    'h_x_okehazama_thanks',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'imagawa') &&
        g.hasFlag('scene:h_x_okehazama_warn') &&
        g.l.rank <= 2 &&
        (g.fa['今川']?.alive ?? false) &&
        g.active,
    (g, next) {
      final l = g.l;
      g.ask(
        '義元の使い',
        '今川の使いが、村を訪ねてきた。「桶狭間の雨の中、本陣へ急を知らせた者を探しておる。屋形さまが、礼をしたいと仰せだ」',
        [
          if (!l.female)
            Choice.h('侍に取り立ててもらう', '身分が得られる。戦に出る身になる', () {
              l.lord = '今川';
              l.rank = 3;
              if (l.maxRank < 3) l.maxRank = 3;
              l.fav = 50;
              l.ronin = false;
              g.meet('主君', '今川義元', 60);
              g.mark('桶狭間の知らせの功で、今川義元に侍として取り立てられた');
              return '名字と刀を賜り、今川の侍となった。';
            }),
          Choice.h('田と銭を賜る', '暮らしは豊かになる。身分は変わらない', () {
            l.gold += 40;
            l.fame += 10;
            g.mark('桶狭間の知らせの功で、今川義元から田と銭を賜った');
            return '田を一枚と、銭四十貫を賜った。';
          }),
          Choice.h('名乗り出ない', '何も変わらない。それでいいと思える', () {
            g.j(6);
            g.setFlag('silent_hero');
            return '自分のことだとは言わなかった。歴史を変えたのが誰なのか、誰も知らない。';
          }),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => g.l.startYear + a >= 1561 && g.l.startYear + a <= 1563,
  ),

  SceneDef(
    'h_x_okehazama_hero',
    20,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'imagawa') &&
        g.hasFlag('scene:okehazama') &&
        g.l.lord == '今川' &&
        g.active,
    (g, next) {
      final l = g.l;
      g.ask(
        '義元の召し出し',
        '今川義元が、桶狭間で本陣を守るよう進言した者を覚えていた。「あの日、そなたの一言がなければ、わしの首はなかった」',
        [
          Choice.h('城を賜る', '一城の主になる。背負うものも増える', () {
            l.rank = l.rank < 5 ? 5 : l.rank;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.troops += 30;
            g.mark('桶狭間の功で、今川義元から城を賜った');
            return '尾張の城を一つ賜り、城主となった。';
          }),
          Choice.h('名物の茶器を賜る', '一国にも値するという。戦の役には立たない', () {
            l.fame += 20;
            g.setFlag('meibutsu');
            g.mark('桶狭間の功で、今川義元から名物の茶器を賜った');
            return '義元秘蔵の茶入を賜った。手が震えた。';
          }),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => _yr(g, a) >= 1562 && _yr(g, a) <= 1574,
  ),

  // ---------------- 信長の世 ----------------
  SceneDef(
    'h_x_nobunaga_reward',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'nobunaga') &&
        g.hasFlag('history_honnoji') &&
        _f(g, '織田') != null &&
        g.l.rank < 8 &&
        g.active,
    (g, next) {
      final l = g.l;
      final saved = !g.hasFlag('scene:h_x_honnoji_warn');
      g.ask(
        '信長の召し出し',
        saved
            ? '安土の天主で、信長が待っていた。「本能寺の火の中から、わしを引きずり出した者よ。望みを申せ」'
            : '安土の天主で、信長が待っていた。「あの夜明け、本能寺へ急を知らせに走った者よ。望みを申せ」',
        [
          Choice.h('国を一つ望む', '一国を任される。信長の家臣であることに変わりはない', () {
            l.lord = '織田';
            if (l.rank < 7) l.rank = 7;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            if (g.canFight) l.troops += 60;
            l.fav = 80;
            g.mark('本能寺の功で、信長から一国を任された');
            return '信長は笑って、一国を任せると言った。';
          }),
          Choice.h('南蛮の船に乗りたいと願う', '海の向こうを見られる。帰れる保証はない', () {
            g.setFlag('nanban_voyage');
            g.mark('信長の許しを得て、南蛮の船で海を渡った');
            if (g.rng.chance(.3)) {
              g.die('信長の船で南蛮へ渡り、そのまま帰らなかった', 'yukue');
              return '船は南へ、南へと進み、やがて見えなくなった。';
            }
            l.chi = _c(l.chi + 10);
            return '海の向こうの国々を見て、帰ってきた。';
          }),
          Choice.h('何も望まない', '信長は不思議そうな顔をする', () {
            l.fame += 15;
            g.j(5);
            g.mark('信長の命を救い、何も望まなかった');
            return '「欲のない奴よ」。信長は、天下一の名物の茶碗を投げてよこした。';
          }),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => _yr(g, a) == 1583,
  ),

  SceneDef(
    'h_x_osaka_nobunaga',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'nobunaga') &&
        _inRegion(g, ['摂津', '山城', '近江']) &&
        g.l.rank <= 1 &&
        g.active,
    (g, next) {
      g.ask('信長の大坂城', '信長が、大坂に安土をしのぐ城を築かせている。石垣の石を運ぶ人足が、国中から集められている。', [
        Choice.h('普請に加わる', '銭になる。石の下敷きになる者もいる', () {
          if (g.rng.chance(.04)) {
            g.die('信長の大坂城の普請で、石垣の石に打たれた', 'sai');
            return '綱が切れ、石が転がってきた。';
          }
          g.l.gold += 10;
          g.l.hp -= 10;
          g.mark('信長の大坂城の普請に加わった');
          return '天主の屋根に、金の鯱が上がった。';
        }),
        Choice.h('城下で商いをする', '人が集まれば、物も売れる', () {
          g.l.gold += 6;
          return '人足相手の飯屋は、毎日満員だった。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) >= 1584 && _yr(g, a) <= 1586,
  ),

  SceneDef(
    'h_x_fleet',
    15,
    70,
    (g) => 20,
    (g) =>
        _inLine(g, 'nobunaga') &&
        (_inRegion(g, ['摂津', '肥前', '豊後']) || g.hasFlag('way_merchant')) &&
        g.active,
    (g, next) {
      g.ask('南蛮への船団', '信長の船団が、南蛮の国々へ向けて船出する。水夫や商人を募っている。', [
        Choice.h('船に乗る', '見たこともない国を見られる。海は人を返さないこともある', () {
          if (g.rng.chance(.2)) {
            g.die('信長の船団で南蛮へ渡り、帰らなかった', 'yukue');
            return '船団は水平線の向こうへ消えた。';
          }
          g.l.gold += 30;
          g.l.chi = _c(g.l.chi + 6);
          g.setFlag('saw_world');
          g.mark('信長の船団に乗り、南蛮の国々を見て帰った');
          return '天竺の向こうまで行き、山のような土産を積んで帰ってきた。';
        }),
        Choice.h('見送る', '陸で待つ', () => '港で、帆が小さくなるまで見送った。'),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1588,
  ),

  SceneDef(
    'h_x_nobunaga_end',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'nobunaga') &&
        (g.l.lord == '織田' || g.hasFlag('history_honnoji')) &&
        g.active,
    (g, next) {
      g.ask('信長の最期', '老いた信長が、大坂の城で死の床にある。「人間五十年と謡うたが、ずいぶん長く生きてしもうた」', [
        Choice.h('枕元に参じる', '天下人を看取る', () {
          g.setFlag('saw_nobunaga_die');
          g.mark('天寿をまっとうした信長を看取った');
          return '信長は、最後に小さく笑った。';
        }),
        Choice.h('遠くから手を合わせる', '身分をわきまえる', () => '大坂の方角に、手を合わせた。'),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1598,
  ),

  // ---------------- 明智の世 ----------------
  SceneDef(
    'h_x_akechi_reward',
    15,
    84,
    (g) => 20,
    (g) => _inLine(g, 'akechi') && g.hasFlag('history_yamazaki') && g.active,
    (g, next) {
      final l = g.l;
      g.ask('光秀の礼', '明智光秀が、山崎の勝ちを助けた者を坂本城に招いた。「そなたのおかげで、わしは逆臣で終わらずに済んだ」', [
        // 明智の世では、1582年に明智家が勢力として立つ（x_honnoji_akechi）。
        if (_f(g, '明智') != null && l.rank < 8)
          Choice.h('光秀の重臣となる', '新しい天下の柱になる。敵も多い', () {
            l.lord = '明智';
            l.rank = l.rank < 6 ? 6 : l.rank;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
            l.fav = 70;
            g.meet('主君', '明智光秀', 70);
            g.setFlag('akechi_retainer');
            g.mark('山崎の功で、明智光秀の重臣となった');
            return '光秀の重臣に取り立てられた。';
          }),
        Choice.h('褒美を辞して野に下る', '勝ち馬から降りる。命は守りやすい', () {
          l.gold += 30;
          g.j(5);
          return '銭だけ受け取り、坂本を去った。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1583,
  ),

  SceneDef(
    'h_x_akechi_gov',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'akechi') &&
        _inRegion(g, ['山城', '近江', '摂津']) &&
        g.l.rank <= 2 &&
        g.active,
    (g, next) {
      g.ask('光秀の政', '明智の役人が、川の堤を直し、年貢を軽くすると触れて回っている。代わりに、町の人足を出せという。', [
        Choice.h('人足に出る', '町は良くなる。体はきつい', () {
          g.l.hp -= 10;
          g.l.net += 2;
          g.mark('明智光秀の世で、川の堤を直す普請に出た');
          return '堤ができた年、町の者たちは光秀を「よい殿さま」と呼んだ。';
        }),
        Choice.h('銭を出して免れる', '体は楽だ', () {
          g.l.gold = g.l.gold >= 3 ? g.l.gold - 3 : 0;
          return '銭を出して、人足を免れた。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) >= 1584 && _yr(g, a) <= 1590,
  ),

  SceneDef(
    'h_x_hideyoshi_west',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'akechi') &&
        g.l.lord == '明智' &&
        g.l.rank >= 1 &&
        g.l.rank < 8 &&
        g.canFight &&
        g.active,
    (g, next) {
      g.ask('播磨の戦', '羽柴秀吉が、毛利の後ろ盾を得て、播磨から再び攻め上ってきた。', [
        Choice.h('明智方として迎え撃つ', '天下の行方を決める戦だ', () {
          if (g.rng.chance(.1)) {
            g.die('明智の世の播磨の戦で、羽柴の軍勢に討たれた', 'senshi');
            return '羽柴の旗が、目の前に迫ってきた。';
          }
          g.l.merit += 15;
          g.mark('明智方として、播磨で羽柴秀吉を退けた');
          return '秀吉の軍勢を、播磨で食い止めた。';
        }),
        Choice.h('ひそかに秀吉に通じる', '勝ち馬が変わるかもしれない。露見すれば終わりだ', () {
          if (g.rng.chance(.3)) {
            g.die('羽柴に通じたことが露見し、斬られた', 'seppuku');
            return '密書が、明智の手に落ちた。';
          }
          g.setFlag('hideyoshi_secret');
          return '秀吉からの返書を、懐の奥にしまった。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1587,
  ),
  // ---------------- 庶民が立てる分岐点（歴史を変える入口） ----------------
  SceneDef(
    'h_x_okehazama_warn',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'real') &&
        _inRegion(g, ['尾張', '三河']) &&
        g.l.lord != '織田' &&
        g.l.rank <= 2 &&
        g.active,
    (g, next) {
      g.ask(
        '雨の中の軍勢',
        '激しい雨の中、織田の旗を伏せた一団が、桶狭間の方へ山道を急いでいるのを見た。今川の本陣は、谷で昼の休みをとっているという。',
        [
          Choice.h('今川の本陣へ知らせに走る', '間に合えば、何かが変わるかもしれない。織田に見つかれば斬られる', () {
            if (g.rng.chance(.08)) {
              g.die('桶狭間へ知らせに走る途中、織田の兵に斬られた', 'senshi');
              return 'ぬかるんだ道で、背後から呼び止められた。';
            }
            if (g.rng.chance(.12)) {
              g.setFlag('history_okehazama');
              g.l.fame += 30;
              g.mark('桶狭間で今川の本陣に急を知らせ、義元を救った');
              return '本陣は間一髪で備えを固め、織田の奇襲は退けられた。義元は生き延びた――歴史が、変わった。';
            }
            g.mark('桶狭間の雨の中、今川の本陣へ知らせに走った');
            return '本陣にたどり着いたときには、もう勝鬨が上がっていた。織田の勝鬨だった。';
          }),
          Choice.h('見なかったことにする', '巻き込まれずに済む', () => '笠を深くかぶり、家路を急いだ。'),
          if (g.l.un >= 60)
            Choice.h('足の向くまま、軍勢のあとをつけてみる', '何が起きるのか、この目で見たい。巻き込まれるかどうかは成り行きしだい', () {
              if (g.luck()) {
                g.l.gold += 5;
                g.l.fame += 2;
                g.j(3);
                return '丘の上の藪から、雨上がりの谷へ織田の兵がなだれ込むのを見た。逃げ散った今川の荷駄のそばで、蒔絵の文箱を一つ拾った。あの日のことを、村で語れるのはあなただけだった。';
              }
              g.l.hp -= 8;
              return '山道で織田の物見に見つかり、槍の柄で打ち据えられた。「去ね」。泥の中を這って帰った。';
            }, via: '運'),
        ],
        after: next,
      );
    },
    ageOk: (g, a) => _yr(g, a) == 1560,
  ),

  SceneDef(
    'h_x_honnoji_warn',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'real') &&
        _inRegion(g, ['山城', '近江', '摂津']) &&
        g.l.lord != '織田' &&
        g.active,
    (g, next) {
      g.ask('夜明け前の京', '夜明け前、桔梗の旗を掲げた大軍が、西から京へ入ってきた。「敵は本能寺にあり」という声が聞こえた気がした。', [
        Choice.h('本能寺へ知らせに走る', '信長に届けば、天下が変わるかもしれない。明智の兵に見つかれば終わりだ', () {
          if (g.rng.chance(.1)) {
            g.die('本能寺へ知らせに走り、明智の兵に討たれた', 'senshi');
            return '辻を曲がったところで、槍の穂先が光った。';
          }
          if (g.rng.chance(.1)) {
            g.setFlag('history_honnoji');
            g.l.fame += 40;
            g.mark('本能寺の変の夜明け、信長に急を知らせて命を救った');
            return '知らせを受けた信長は、裏の門から寺を抜け出した。本能寺は焼けたが、信長は生きていた――歴史が、変わった。';
          }
          g.mark('本能寺の変の夜明け、寺へ知らせに走った');
          return '寺に着いたときには、もう火の手が上がっていた。';
        }),
        Choice.h('戸を閉めて息をひそめる', '命は守れる', () => '軍勢の足音が遠ざかるまで、戸の陰でじっとしていた。'),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1582,
  ),

  SceneDef(
    'h_x_tennozan',
    15,
    84,
    (g) => 20,
    (g) =>
        _inLine(g, 'real') &&
        _inRegion(g, ['山城', '摂津']) &&
        g.l.lord != '織田' &&
        g.l.rank <= 2 &&
        g.active,
    (g, next) {
      g.ask('天王山の道', '中国から駆け戻った羽柴秀吉の軍勢が、山崎への近道を案内できる者を探している。', [
        Choice.h('近道を案内する', '恩賞が出る。勝つ側につける', () {
          g.l.gold += 10;
          g.mark('山崎の戦いの前、秀吉の軍勢に近道を案内した');
          return '秀吉の軍勢は、天王山を駆け上っていった。';
        }),
        Choice.h('わざと遠回りの道を教える', '明智の勝ちを助けるかもしれない。ばれれば命はない', () {
          if (g.rng.chance(.25)) {
            g.die('秀吉の軍勢に偽りの道を教えたことが知れ、斬られた', 'seppuku');
            return '道が違うと気づいた侍が、刀を抜いた。';
          }
          if (g.rng.chance(.15)) {
            g.setFlag('history_yamazaki');
            g.l.fame += 25;
            g.mark('山崎の戦いの前、秀吉の軍勢を遠回りさせ、明智の勝ちを呼んだ');
            return '秀吉の軍勢が着いたとき、天王山はすでに明智の旗で埋まっていた。光秀が勝った――歴史が、変わった。';
          }
          return '遠回りをさせたが、秀吉の軍勢は驚くほど速かった。';
        }),
      ], after: next);
    },
    ageOk: (g, a) => _yr(g, a) == 1582,
  ),
];

/// 変わった世界線で、今いる世を知らせる一文（見聞録・結果に使える）。
String lineName(Game g) => kLineNames[worldLine(g)]!;

/// 主君などに登録しうる有名人の没年。世界線で変わるものは [personDied] で上書きする。
const _deathYear = {
  '織田信長': 1582,
  '羽柴秀吉': 1598,
  '長尾景虎': 1578,
  '今川義元': 1560,
  '斎藤道三': 1556,
  '長宗我部元親': 1599,
  '明智光秀': 1582,
  '千宗易': 1591,
  '徳川家康': 1616,
  '伊達政宗': 1636,
  'ザビエル': 1552,
};

/// 縁のある人のうち、名の知れた人がもう亡くなっているか（世界線に合わせる）。最期の場の人選びと人物のタブで使う。
bool personDied(Game g, String name) {
  var y = _deathYear[name];
  if (y == null) return false;
  final line = worldLine(g);
  if (name == '織田信長' && line == 'nobunaga') y = 1598;
  if (name == '今川義元' && line == 'imagawa') y = 1575;
  if (name == '明智光秀' && line == 'akechi') y = 1598;
  return g.year > y;
}

/// 小さな分岐の呼び名。
const kSmallBranchNames = {
  'history_nagashino': '長篠で武田の騎馬が崩れなかった',
  'history_odawara': '小田原で北条の家が残った',
  'history_kawanakajima': '川中島で武田信玄が討たれた',
};

/// あなたが変えた歴史（世界線と小さな分岐）を、短い文で並べる。史実どおりなら空。
List<String> changedHistory(Game g) => [
  if (worldLine(g) != 'real') lineName(g),
  for (final e in kSmallBranchNames.entries)
    if (g.hasFlag(e.key)) e.value,
];

/// テスト用: 出し分けの表に書いた id が、すべて実在するか。
Set<String> skipTableIds() => {
  for (final v in kSkipScenes.values) ...v,
  for (final v in kFlagSkipScenes.values) ...v,
};

Set<String> skipEventIds() => {
  for (final v in kSkipEvents.values) ...v,
  for (final v in kFlagSkipEvents.values) ...v,
};

/// [Life] を受けて世界線名を返す（保存済みの人生を見るとき用）。
String worldLineOfLife(Life l) {
  if (l.flags.contains('history_okehazama')) return 'imagawa';
  if (l.flags.contains('history_yamazaki')) return 'akechi';
  if (l.flags.contains('history_honnoji')) return 'nobunaga';
  if (l.flags.contains('history_sekigahara')) return 'west';
  return 'real';
}
