import 'endings_catalog.dart';
import 'endings_castle.dart';
import 'endings_daimyo.dart';
import 'endings_merchant.dart';
import 'endings_peace.dart';
import 'endings_priest.dart';
import 'endings_samurai.dart';
import 'endings_shadow.dart';
import 'endings_tenka.dart';
import 'endings_village.dart';
import 'endings_woman.dart';
import 'endings_young.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'peace.dart';
import 'rng.dart';
import 'ways.dart';

/// 人生の結末（結果カードに載せるもの）。
///
/// 最期の場面1000本（CLAUDE.md「最期の場面を1000本」）を書くまでの土台。
/// いまは「道 × 死に方 × 幸福」で称号を、縁のある人・世界線で最期の文を組み立てる。
/// 1000本を書いたら、[buildEnding] がまず手書きの最期を探し、なければここへ落ちる形にする。
class Ending {
  Ending({
    required this.title,
    required this.text,
    required this.way,
    required this.kind,
    required this.highlights,
    this.witness,
    this.handId,
    this.tier,
  });

  /// 手書きの最期なら、その id（`endings_*.dart`）と希少度。組み立ての最期なら null。
  final String? handId;
  final Tier? tier;

  String? get tierName => tier == null ? null : kTierNames[tier];

  /// 最期の場にいた人の役割（伴侶・子・幼なじみ…）。いなければ null。
  final String? witness;

  /// 図鑑で同じ結末かを見分けるための鍵（名前は含めない）。
  /// 最期1000本を書いたら、手書きの最期の id に置き換える。
  String get key =>
      handId != null ? 'hand:$handId' : '$way/$kind/${witness ?? '-'}';

  /// 結末の称号（例「戦場に散った侍」）。
  final String title;

  /// 最期の場面（3〜4文）。
  final String text;

  /// 道（`kWays` のキー）と死に方（`kDeathKinds` のキー、または 'era' / 'victory'）。
  final String way, kind;

  /// 結果カードに載せる「選んだ道」（3〜4行）。
  final List<String> highlights;

  String get wayName => kWays[way]!.$1;
  String get kindName => switch (kind) {
    'era' => '乱世を生き抜く', // 古い保存（一六〇一年で終わった人生）だけ
    'victory' => '天下統一',
    _ => kDeathKinds[kind]!,
  };
}

String _wayNoun(Life l, String way) {
  final f = l.female;
  return switch (way) {
    'young' => '幼い命',
    'village' => switch (l.cls.id) {
      'fisher' => f ? '浜の女' : '海の男',
      'beggar' => f ? '河原の女' : '河原者',
      _ => f ? '村の女' : '百姓',
    },
    'merchant' => l.flags.contains('goyo') ? '御用商人' : (f ? '女商人' : '商人'),
    'priest' => f ? '尼' : (l.flags.contains('abbot') ? '住持' : '僧'),
    'shadow' =>
      l.cls.id == 'ninja' || l.flags.contains('nukenin')
          ? '忍び'
          : (l.flags.contains('wanderer') ? '流れ者' : '野の者'),
    'samurai' => l.maxRank >= 3 ? '侍' : '足軽',
    'castle' => l.maxRank >= 6 ? '家老' : '城主',
    'daimyo' => l.flags.contains('scene:gekokujo') ? '下剋上の大名' : '大名',
    'tenka' => f ? '女天下人' : '天下人',
    'woman' =>
      l.maxRank >= 8
          ? '女大名'
          : (l.flags.contains('onna_jo')
                ? '女城主'
                : (l.married ? '武家の妻' : '奥の女')),
    _ => '人',
  };
}

String _kindPhrase(Life l, String kind) {
  final cause = l.dead ?? '';
  return switch (kind) {
    'tenju' => '天寿をまっとうした',
    'byo' => cause.contains('産') ? 'お産で命を落とした' : '病に倒れた',
    'senshi' => RegExp('合戦|戦|陣|討死|籠城|一揆').hasMatch(cause) ? '戦場に散った' : '刃に斃れた',
    'seppuku' => cause.contains('腹') ? '腹を切った' : '刑場の露と消えた',
    'ansatsu' => '闇に討たれた',
    'sai' => '災いに呑まれた',
    'ue' => '飢えに斃れた',
    'yukue' => '行方知れずとなった',
    'era' => '乱世を生き抜いた',
    'victory' => '天下を掴んだ',
    _ => '世を去った',
  };
}

/// 幸福の軸。穏やかな最期にだけ前置きを付ける（地位 × 幸福の皮肉や納得の一行）。
String _joyPrefix(double avgJoy, String kind) {
  if (!const {'tenju', 'byo', 'era', 'victory'}.contains(kind)) return '';
  if (avgJoy >= 65) return '満ち足りて';
  if (avgJoy < 35) return kind == 'victory' ? '孤独に' : '苦しみの果てに';
  return '';
}

/// 稀な道のりには、特別な称号。
String? _specialTitle(Game g, String way, String kind) {
  final l = g.l;
  final n = _wayNoun(l, way);
  const changed = {
    'history_honnoji': '本能寺の炎から信長を救った',
    'history_okehazama': '桶狭間で義元を救い、歴史を変えた',
    'history_yamazaki': '三日天下を覆した',
    'history_sekigahara': '関ヶ原で天下を西へ傾けた',
    'history_nagashino': '長篠で武田の騎馬を救った',
    'history_odawara': '小田原で北条の家を残した',
    'history_kawanakajima': '川中島で信玄を討った',
  };
  for (final e in changed.entries) {
    if (l.flags.contains(e.key)) return '${e.value}$n';
  }
  if (way == 'tenka' && l.cls.id == 'beggar') return '河原から天下へ駆け上がった者';
  if (way == 'tenka' && l.cls.rank == 0) return '名もなき民から天下人となった者';
  if (way == 'tenka' && l.female) return '女の身で天下を取った者';
  return null;
}

/// 乱世を生き抜いた人生の結び。どんな身分で新しい世を迎え、子らにどんな世が来るか。
String _eraEpilogue(Game g, String way) {
  final l = g.l;
  final alive = l.lord != null && (g.fa[l.lord]?.alive ?? false);
  final String who;
  if (l.rank >= 8 && alive) {
    who = '${houseName(g, l.lord)}家の当主として、新しい世の始まりに立った。';
  } else if (l.rank >= 1 && alive) {
    who = '${houseName(g, l.lord)}家の${g.rk[l.rank]}として、泰平の世を迎えた。';
  } else if (way == 'priest') {
    who = '寺の鐘を撞きながら、静かに新しい世を迎えた。';
  } else if (way == 'merchant') {
    who = '戦のない世の商いに、もう一度胸を躍らせた。';
  } else {
    who = '名もなき${_wayNoun(l, way)}として、静かに泰平の世を迎えた。';
  }
  final kids = l.kids > 0 ? '子らは、戦を知らない世を生きていくだろう。' : '';
  return '$who$kids';
}

/// 最期の場にいた人。絆の深い順に、伴侶・子（嫡男・養子・娘）・孫・幼なじみ・弟子・主君・師。
/// 組み立ての最期でだけ使う（手書きの最期の図鑑の鍵は `hand:<id>` なので、候補を足しても変わらない）。
Person? _witness(Game g) {
  final l = g.l;
  // 連れ合いがいれば、最期の場にいるのは連れ合い。
  final sp = l.people['伴侶'];
  if (sp != null && l.married) return sp;
  // 連れ合いを亡くした・別れた人では、伴侶は最期の場にいない（候補から外す）。
  const roles = [
    '嫡男',
    '子',
    '養子',
    '娘',
    '孫',
    '幼なじみ',
    '弟妹',
    '弟子',
    '主君',
    '師',
    '好敵手',
  ];
  Person? best;
  for (final r in roles) {
    final p = l.people[r];
    if (p == null || personDied(g, p.name)) continue;
    if (best == null || p.bond > best.bond) best = p;
  }
  return best;
}

String _witnessLine(Game g, String kind) {
  final p = _witness(g);
  final calm = const {'tenju', 'byo', 'era', 'victory'}.contains(kind);
  if (p == null) {
    return calm ? '看取る者は、いなかった。' : 'その最期を、知る者はいない。';
  }
  final who = p.role == '好敵手' ? '生涯の好敵手・${p.name}' : p.name;
  if (calm) {
    return p.bond >= 60 ? '$whoが、最期まで手を握っていた。' : '$whoが、枕元に座っていた。';
  }
  if (kind == 'yukue') return '$whoは、いつまでも帰りを待ち続けたという。';
  return '知らせを聞いた$whoは、しばらく口をきかなかったという。';
}

String _joyLine(double aj) => aj >= 65
    ? '振り返れば、満ち足りた一生だった。'
    : (aj >= 42 ? '喜びも苦しみも、人並みに味わった一生だった。' : '苦しいことの多い一生だった。');

// 行の重み: 史実の出来事・有名人(3) > 身分の大きな変化(2) > 人生の節目(1)。
final _heavy = RegExp(
  '信長|秀吉|家康|謙信|景虎|信玄|義元|光秀|政宗|利休|宗易|ザビエル|歴史|天下|'
  '桶狭間|本能寺|比叡山|関ヶ原|長篠|川中島|小田原|山崎|賤ヶ岳|高野山|石山|一揆|朝鮮',
);
final _middle = RegExp('大名|城主|家老|下剋上|家督|取り立て|女城主|御用|後見');
final _light = RegExp('出家|夫婦|輿入れ|仕え|商い|野盗|弟子|庄屋|工房');
int _weight(String s) => _heavy.hasMatch(s)
    ? 3
    : _middle.hasMatch(s)
    ? 2
    : _light.hasMatch(s)
    ? 1
    : 0;

/// 最期の文に入れる「思えば、〜こともあった。」。歩んだ道のうち、いちばん重い出来事（重み2以上）を一つ。
String _memoryLine(Life l) {
  if (l.path.length < 3) return '';
  var best = -1, bw = 1;
  for (var i = 0; i < l.path.length - 1; i++) {
    final w = _weight(l.path[i]);
    if (w > bw) {
      bw = w;
      best = i;
    }
  }
  if (best < 0) return '';
  final m = RegExp(r'^(\d+)歳\s*(.+)$').firstMatch(l.path[best]);
  if (m == null) return '';
  return '思えば、${m.group(1)}歳のとき、${m.group(2)}こともあった。';
}

/// 結果カードに載せる「選んだ道」を3〜4行に絞る（初め・終わり・有名人や歴史の絡む行を優先）。
List<String> pickHighlights(List<String> path, {int max = 4}) {
  if (path.length <= max) return [...path];
  final picked = <int>{0, path.length - 1};
  final order = [for (var i = 1; i < path.length - 1; i++) i]
    ..sort((a, b) => _weight(path[b]).compareTo(_weight(path[a])));
  for (final i in order) {
    if (picked.length >= max || _weight(path[i]) == 0) break;
    picked.add(i);
  }
  final step = (path.length ~/ max).clamp(1, 99);
  for (var i = step; i < path.length - 1 && picked.length < max; i += step) {
    picked.add(i);
  }
  final idx = picked.toList()..sort();
  return [for (final i in idx) path[i]];
}

/// 手書きの最期（道ごとのファイルを足していく）。
final kHandEndings = <EndingDef>[
  ...kYoungEndings,
  ...kVillageEndings,
  ...kMerchantEndings,
  ...kPriestEndings,
  ...kShadowEndings,
  ...kSamuraiEndings,
  ...kCastleEndings,
  ...kDaimyoEndings,
  ...kTenkaEndings,
  ...kWomanEndings,
  ...kPeaceEndings,
];

// ---------------------------------------------------------------------
// 「乱世を生き抜いた」最期（kinds に era を持つ最期）の読み替え（2026-11-24）
// ---------------------------------------------------------------------
// 前は、一六〇一年を生きて越えた人生がそこで終わり（`end == 'era'`）、era の最期が出ていた。
// いまは人生が亡くなるまで続くので、era の最期は「**一六〇一年からの世に、天寿か病で亡くなった人**」の
// 最期の候補に入れる（死に方ごとの最期と、細かさ `spec` で競う。仕組みは変えていない）。
// era の最期の文は「{年}年、乱世が終わった」「関ヶ原の戦から一年が過ぎた」のように、亡くなった年が
// 関ヶ原のすぐあとである前提で書かれているので、文ごとに「何年までに亡くなった人に出すか」を決める
// （[kEraUntil]。書いていないものは [kEraUntilDefault]＝大坂の陣で戦の世が終わる一六一五年まで）。

/// era の最期を出す、亡くなった年の上限の既定（元和偃武の年）。
const kEraUntilDefault = 1615;

/// era の最期ごとの、亡くなった年の上限（文の言い方に合わせる）。
const kEraUntil = <String, int>{
  // 「関ヶ原の戦から一年が過ぎた」「前の年の関ヶ原で」「関ヶ原の知らせを」: 一六〇一年だけ
  'j_era_east': 1601,
  'j_era_west_ronin': 1601,
  'j_era_west_win': 1601,
  'm_era_tokugawa': 1601,
  's_era_sekigahara': 1601,
  'v_era': 1601,
  'f_era': 1601,
  'f_era_high': 1601,
  'f_era_kids': 1601,
  'f_era_political': 1601,
  'f_era_hostage': 1601,
  'f_era_widow': 1601,
  // 「関ヶ原の戦いが終わり」「天下を分けた戦が終わり」「天下の行方が定まった」: 幕府が開かれる一六〇三年まで
  'd_era_real': 1603,
  'd_era_west': 1603,
  's_era': 1603,
  's_era_sato': 1603,
  's_era_bandit': 1603,
  's_era_assassin': 1603,
  'f_era_low': 1603,
  'b_era_honnoji': 1603, // 「本能寺の夜から、もう二十年近く」
  // 「関ヶ原ののちの世を迎えた」「家康が天下を手にするのを見届けた」「幼い秀頼」: 一六〇五年まで
  'p_era_m': 1605,
  'b_era': 1605,
  'b_era_east': 1605,
  'b_era_west': 1605,
  'b_era_ieyasu': 1605,
  'f_era_lady': 1605,
  'f_era_regent': 1605,
  'f_era_nene': 1605,
  'f_era_hime': 1605,
  'v_era_drew_sword': 1605,
  'm_era_fushimi': 1605,
  'd_era_bunkokuho': 1605,
  // 南蛮寺の鐘・長崎の異国の言葉: 禁教の前の一六一一年まで
  'd_era_kirishitan': 1611,
  'm_era_nagasaki': 1611,
  // 年を限る言い方のないもの（戦のない世の暮らしを書いた文）: いつ亡くなっても出す
  'j_era_office': 9999,
  'j_era_retired': 9999,
  'j_era_heir': 9999,
  'j_era_grandchild': 9999,
  'j_era_castletown': 9999,
  'j_era_chisui': 9999,
  'j_era_odawara': 9999,
  'd_era_old': 9999,
  'd_era_joy': 9999,
  'p_era_f': 9999,
  'p_era_hiei': 9999,
  'b_era_family': 9999,
  'b_era_letters': 9999,
  'v_era_content': 9999,
  'v_era_fisher': 9999,
  'v_era_grand': 9999,
  'v_era_edo': 9999,
};

/// 泰平の世まで生きて、穏やかに亡くなった人か（一六〇一年からの世に、天寿か病で。お産の死は除く）。
bool peaceDeath(Game g) {
  final l = g.l;
  return l.dead != null &&
      !l.victory &&
      g.year >= 1601 &&
      const {'tenju', 'byo'}.contains(l.deathKind ?? 'byo') &&
      !l.dead!.contains('産');
}

/// era の最期 [e] を、この人生の最期の候補に入れてよいか。
bool eraEndingFits(Game g, EndingDef e) =>
    peaceDeath(g) && g.year <= (kEraUntil[e.id] ?? kEraUntilDefault);

/// era の最期は「新しい世を迎えた」ところまでしか書いていないので、亡くなった人には結びを一文添える
/// （最期の文そのものは変えない）。
String _eraDeathTail(Game g, String kind) => kind == 'tenju'
    ? 'それからほどなく、${g.l.name}は静かに息を引き取った。'
    : 'それからほどなく、${g.l.name}は病の床に就き、世を去った。';

// ---------------------------------------------------------------------
// 泰平の世で亡くなった人には、戦の世の言葉の最期より、泰平の最期を先に出す（2026-11-24）
// ---------------------------------------------------------------------
// 既存の最期（約千本）は戦国の言葉で書かれていて、細かさ `spec` が3以上のものは泰平の受け皿より先に出る。
// 一六三〇年代に畳の上で亡くなった人に「陣から戻るたびに」「敵の槍が」と出るのを避けるため、
// **元和偃武のあと（[kPeaceYieldFrom]）に、戦の絶えた世で亡くなった人**に限って、選ばれた最期が
// 「戦の世の言い回し（[kWarWords]）を含む、泰平の側でない最期」なら、泰平の側の最期（`endings_peace.dart` と、
// 年の合う「乱世を生き抜いた」最期）の中で選び直す。泰平の側に候補がなければ、そのまま出す。
// - 家族・信仰・商いなど、戦に触れない既存の最期は押しのけない（これまでどおり細かさで競う）。
// - 幻の最期（歴史を変えた人生など）は押しのけない。
// - 自ら戦を起こして討死した人（泰平の世でも大名は攻め込める）の戦死の最期は押しのけない
//   （大坂の陣・島原の死には、泰平の側に死因で出る最期がある）。
// 最期の文・条件・細かさは一本も変えていない。

/// 泰平の最期へ譲るのは、この年からに亡くなった人（元和偃武の翌年）。
const kPeaceYieldFrom = 1616;

/// 弱い形で譲りはじめる年（戦の絶えた世の始まり）。この年から [kPeaceYieldFrom] の前までは、戦を知る者ばかりの世なので、
/// 戦の昔語りの最期はそのまま出し、「いま戦のただ中にいる」文（[kWarNowWords]）の最期だけを外して選び直す。
const kPeaceSoftFrom = 1601;

/// 戦の世の言い回し（称号と本文の、差し込み前の文字で見る。名に入る「兵衛」などに当たらないように）。
final kWarWords = RegExp(
  '戦|陣|討死|討ち死に|籠城|落城|乱世|敵|軍勢|雑兵|乱取り|首級|首実検|兵|砦|鉄砲|国盗り|下剋上',
);

/// 「いま戦のただ中にいる」言い回し（現在の戦）。[kWarWords] に当たる最期のうち、これに当たるものだけが「現在の戦」で、
/// 当たらないものは「昔語り」（かつての戦を振り返る・戦に明け暮れた一生をまとめる文）とみなす。
/// 陣中や囲まれた城で息を引き取る・戦の世がまだ続いている前提の言葉。差し込み前の文字で見る。
final kWarNowWords = RegExp(
  '陣中で[^。]*(息を引き取|病に倒れ)|陣中で、[^。]*熱を出し|陣小屋|城中で病に倒れ|囲まれた[^。]*城で|'
  '戦の世でも|この乱世に|兵を集めていた矢先',
);

final _peaceIds = {for (final e in kPeaceEndings) e.id};

/// 泰平の世の最期（`endings_peace.dart`）か。
bool isPeaceEnding(EndingDef e) => _peaceIds.contains(e.id);

/// 泰平の側の最期か（泰平の最期と、死に方 [kind] の人に読み替えで出る「乱世を生き抜いた」最期）。
bool isPeaceSideEnding(EndingDef e, String kind) =>
    isPeaceEnding(e) ||
    (e.kinds != null && e.kinds!.contains('era') && !e.kinds!.contains(kind));

/// 最期の称号と本文に、戦の世の言い回しがあるか。
bool hasWarWords(EndingDef e) => kWarWords.hasMatch('${e.title}${e.text}');

/// 最期の文が「現在の戦」（いま戦のただ中にいる）か。「乱世を生き抜いた」最期と泰平の最期は、新しい世の文なので当たらない。
bool isWarNow(EndingDef e) =>
    !isPeaceEnding(e) &&
    !(e.kinds?.contains('era') ?? false) &&
    kWarNowWords.hasMatch('${e.title}${e.text}');

/// 最期の文が「戦の昔語り」（戦の言い回しはあるが、現在の戦ではない）か。
bool isWarTale(EndingDef e) => hasWarWords(e) && !isWarNow(e);

/// 選ばれた最期 [e] を、ほかの最期に譲るか（選び直す先は [yieldPool]）。
/// - 一六〇一〜一五年（[kPeaceSoftFrom] から）: 「現在の戦」の最期だけが譲る。昔語りはそのまま。
/// - 一六一六年（[kPeaceYieldFrom]）から: 戦の言い回しのある最期は譲る。ただし稀な最期の昔語り
///   （北ノ庄の落城を思い返す女 など）は、戦を知る老いた者の最期として残す。
bool yieldsToPeace(Game g, EndingDef e, String kind) {
  final l = g.l;
  if (l.dead == null || l.victory) return false;
  if (g.year < kPeaceSoftFrom || !peaceTime(g)) return false;
  if (e.tier == Tier.phantom || isPeaceSideEnding(e, kind)) return false;
  // 自ら起こした戦での討死（大坂・島原のほか）は、戦の言葉のままでよい。
  if (kind == 'senshi' && !RegExp('大坂|島原').hasMatch(l.dead!)) return false;
  if (g.year < kPeaceYieldFrom) return isWarNow(e);
  if (e.tier == Tier.rare && isWarTale(e)) return false;
  return hasWarWords(e);
}

/// 譲った先の候補。一六一六年からは泰平の側の最期だけ、一六〇一〜一五年は「現在の戦」でない最期すべて
/// （昔語りの既存の最期も、泰平の側の最期も、細かさで競う）。
List<EndingDef> yieldPool(Game g, String kind) => [
  for (final e in kHandEndings)
    if (g.year >= kPeaceYieldFrom ? isPeaceSideEnding(e, kind) : !isWarNow(e))
      e,
];

/// 手書きの最期がそろっている道（この道の人生には必ず手書きの最期が付く）。
const kHandWays = {
  'young',
  'village',
  'merchant',
  'priest',
  'shadow',
  'samurai',
  'castle',
  'daimyo',
  'tenka',
  'woman',
};

Ending buildEnding(Game g) {
  final l = g.l;
  final way = lifeWay(l);
  final kind = l.victory
      ? 'victory'
      : (l.end == 'era' ? 'era' : (l.deathKind ?? 'byo'));
  var hand = findHandEnding(
    g,
    way,
    kind,
    kHandEndings,
    eraFits: (e) => eraEndingFits(g, e),
  );
  // 戦の絶えた世で亡くなった人に、戦の世の言葉の最期が当たったら譲る（一六〇一〜一五年は「現在の戦」の文だけ。`yieldsToPeace`）。
  if (hand != null && yieldsToPeace(g, hand, kind)) {
    hand =
        findHandEnding(
          g,
          way,
          kind,
          yieldPool(g, kind),
          eraFits: (e) => eraEndingFits(g, e),
        ) ??
        hand;
  }
  if (hand != null) {
    // era の最期が、亡くなった人に出たとき（古い保存の `end == 'era'` では kind も era なので添えない）。
    final viaEra =
        hand.kinds != null &&
        hand.kinds!.contains('era') &&
        !hand.kinds!.contains(kind);
    // 歴史を変えた人生なら、どの最期にも「その世は、〜世だった。」を添える（幼くして亡くなった子は除く）。
    final changed = [
      for (final c in changedHistory(g))
        c.endsWith('世') ? c.substring(0, c.length - 1) : c,
    ];
    final tail = changed.isEmpty || way == 'young'
        ? ''
        : 'その世は、${changed.join('、')}世だった。';
    return Ending(
      title: hand.title,
      text:
          '${fillEnding(g, hand.text)}${viaEra ? _eraDeathTail(g, kind) : ''}$tail',
      way: way,
      kind: kind,
      highlights: pickHighlights(l.path),
      handId: hand.id,
      tier: hand.tier,
    );
  }
  final aj = g.avgJoy;
  final title =
      _specialTitle(g, way, kind) ??
      '${_joyPrefix(aj, kind)}${_kindPhrase(l, kind)}${_wayNoun(l, way)}';

  final String text;
  if (way == 'young') {
    text =
        '${g.year}年（${gengo(g.year)}）、${g.age}歳。${l.dead ?? '幼くして世を去った'}。'
        '${l.people['幼なじみ'] != null ? '一緒に遊んだ${l.people['幼なじみ']!.name}は、長くその名を忘れなかった。' : 'その小さな墓に、母は毎朝花を手向けた。'}'
        'この時代、五つ、十になる前に命を落とす子は珍しくなかった。';
  } else {
    final head = switch (kind) {
      'victory' => '${g.year}年（${gengo(g.year)}）、${g.age}歳。天下の過半を、その手に収めた。',
      'era' =>
        '${g.year}年（${gengo(g.year)}）、${g.age}歳。長い乱世が終わるのを、その目で見届けた。${_eraEpilogue(g, way)}',
      _ => '${g.year}年（${gengo(g.year)}）、${g.age}歳。${l.dead}。',
    };
    // 世界線の名は「〜世」で終わるので、小さな分岐（「〜た」）とそろえて最後に「世」を付ける。
    final changed = [
      for (final c in changedHistory(g))
        c.endsWith('世') ? c.substring(0, c.length - 1) : c,
    ];
    text =
        '$head${_memoryLine(l)}${_witnessLine(g, kind)}${_joyLine(aj)}'
        '${changed.isEmpty ? '' : 'その世は、${changed.join('、')}世だった。'}';
  }
  return Ending(
    title: title,
    text: text,
    way: way,
    kind: kind,
    highlights: pickHighlights(l.path),
    witness: way == 'young' ? null : _witness(g)?.role,
  );
}

/// SNS に貼る文（結果カードの文字版）。
String shareText(Game g, Ending e) {
  final l = g.l;
  return [
    '【乱世下剋上】',
    '約${fmtN(l.rarity)}分の1の生まれ',
    '${l.region}国の${l.clsName}の${l.female ? '娘' : '子'}・${l.name}',
    for (final h in e.highlights) '・$h',
    '結末：${e.title}（${g.age}歳）',
    // よくある最期は書かない。珍しいほど、共有したくなる一行になる。
    if (e.tier != null && e.tier != Tier.common) '― ${e.tierName} ―',
  ].join('\n');
}

/// 終わりの画面に必ず出す、いつ・何歳で・なぜ亡くなったかの一行
/// （2026-11-24 ユーザー「死んだ理由がないことがある」。手書きの最期の文は死因に触れないものがあるため）。
String deathLine(Game g) {
  final l = g.l;
  final head = '${g.year}年（${gengo(g.year)}）、${g.age}歳。';
  if (l.victory) return '$head天下を統一した。';
  final cause = l.dead;
  if (cause != null && cause.isNotEmpty) {
    return '$head$cause${cause.endsWith('。') ? '' : '。'}';
  }
  // 古い保存の「乱世を生き抜いた」終わりなど、死因のない終わり。
  return '$head${kDeathKinds[l.deathKind] ?? '世を去った'}。';
}
