// ignore_for_file: constant_identifier_names
/// 人の顔の絵（assets/faces/）と、その割り当て方（1.0.0+21。1.0.0+22 で160枚に増やした。
/// 1.0.0+23 で、本人と絵の年の差を12歳までにし、見た目の地域と年を直した）。
/// Flutter に依存しない。ゲームの乱数は使わず、名前と年齢と「すでに使われている顔」だけで決まる。
library;

import 'dart:math' as math;

import 'data.dart';

/// 顔の絵1枚（[id] は assets/faces/ のファイル名から .png を除いたもの）
class FacePic {
  final String id;

  /// 地域: ea 東アジア / we 欧米 / sa 南アジア / af アフリカ / me 中東 / la 中南米 / sea 東南アジア
  final String region;

  /// 性別: m / f
  final String sex;

  /// 描かれた年齢
  final int age;
  const FacePic(this.id, this.region, this.sex, this.age);
}

/// 顔の絵の一覧（素材の faces.json と同じ。全部で160枚）
const List<FacePic> FACES = [
  FacePic('ea_0', 'ea', 'm', 25), FacePic('ea_1', 'ea', 'm', 45), FacePic('ea_2', 'ea', 'm', 65),
  FacePic('ea_3', 'ea', 'f', 25), FacePic('ea_4', 'ea', 'f', 45), FacePic('ea_5', 'ea', 'f', 65),
  // ea_8 は30代の東南アジアの男に見える（1.0.0+23 で直した。ファイル名はそのまま）
  FacePic('ea_6', 'ea', 'm', 35), FacePic('ea_7', 'ea', 'f', 35), FacePic('ea_8', 'sea', 'm', 38),
  FacePic('we_0', 'we', 'm', 25), FacePic('we_1', 'we', 'm', 45), FacePic('we_2', 'we', 'm', 65),
  // we_4・we_5 は見た目が東アジアなので東アジア（1.0.0+22 で直した。ファイル名はそのまま）
  FacePic('we_3', 'we', 'f', 25), FacePic('we_4', 'ea', 'f', 45), FacePic('we_5', 'ea', 'f', 65),
  // we_8・sa_8・mx_8 は白髪の無い40歳前後に描かれている（1.0.0+23 で年を直した）
  FacePic('we_6', 'we', 'm', 35), FacePic('we_7', 'we', 'f', 35), FacePic('we_8', 'we', 'm', 42),
  // sa_2 は見た目が欧米（we_2 とほぼ同じ絵）、sa_4・sa_5・sa_7 は見た目が東アジア（sa_4・sa_5 は ea_4・ea_5 とほぼ同じ絵）。1.0.0+23 で直した
  FacePic('sa_0', 'sa', 'm', 25), FacePic('sa_1', 'sa', 'm', 45), FacePic('sa_2', 'we', 'm', 65),
  FacePic('sa_3', 'sa', 'f', 25), FacePic('sa_4', 'ea', 'f', 45), FacePic('sa_5', 'ea', 'f', 65),
  FacePic('sa_6', 'sa', 'm', 35), FacePic('sa_7', 'ea', 'f', 35), FacePic('sa_8', 'sa', 'm', 45),
  FacePic('af_0', 'af', 'm', 25), FacePic('af_1', 'af', 'm', 45), FacePic('af_2', 'af', 'm', 65),
  FacePic('af_3', 'af', 'f', 25), FacePic('af_4', 'af', 'f', 45), FacePic('af_5', 'af', 'f', 65),
  FacePic('af_6', 'af', 'm', 35), FacePic('af_7', 'af', 'f', 35), FacePic('af_8', 'af', 'm', 55),
  FacePic('mx_0', 'me', 'm', 25), FacePic('mx_1', 'me', 'm', 45), FacePic('mx_2', 'me', 'm', 65),
  FacePic('mx_3', 'la', 'f', 25), FacePic('mx_4', 'la', 'f', 45), FacePic('mx_5', 'la', 'f', 65),
  FacePic('mx_6', 'me', 'f', 40), FacePic('mx_7', 'la', 'm', 35), FacePic('mx_8', 'sea', 'm', 40),
  FacePic('ea2_0', 'ea', 'm', 30), FacePic('ea2_1', 'ea', 'm', 50), FacePic('ea2_2', 'ea', 'm', 70),
  FacePic('ea2_3', 'ea', 'f', 28), FacePic('ea2_4', 'ea', 'f', 50), FacePic('ea2_5', 'ea', 'f', 70),
  // ea2_8 は見た目が欧米（we2_8 とほぼ同じ絵。1.0.0+23 で直した）
  FacePic('ea2_6', 'ea', 'm', 22), FacePic('ea2_7', 'ea', 'f', 40), FacePic('ea2_8', 'we', 'm', 60),
  FacePic('we2_0', 'we', 'm', 30), FacePic('we2_1', 'we', 'm', 55), FacePic('we2_2', 'we', 'm', 75),
  FacePic('we2_3', 'we', 'f', 27), FacePic('we2_4', 'we', 'f', 50), FacePic('we2_5', 'we', 'f', 70),
  FacePic('we2_6', 'we', 'm', 22), FacePic('we2_7', 'we', 'f', 40), FacePic('we2_8', 'we', 'm', 60),
  FacePic('sa2_0', 'sa', 'm', 28), FacePic('sa2_1', 'sa', 'm', 50), FacePic('sa2_2', 'sa', 'm', 72),
  FacePic('sa2_3', 'sa', 'f', 26), FacePic('sa2_4', 'sa', 'f', 48), FacePic('sa2_5', 'sa', 'f', 68),
  FacePic('sa2_6', 'sa', 'm', 23), FacePic('sa2_7', 'sa', 'f', 38), FacePic('sa2_8', 'sa', 'm', 60),
  FacePic('af2_0', 'af', 'm', 28), FacePic('af2_1', 'af', 'm', 52), FacePic('af2_2', 'af', 'm', 72),
  FacePic('af2_3', 'af', 'f', 26), FacePic('af2_4', 'af', 'f', 47), FacePic('af2_5', 'af', 'f', 68),
  FacePic('af2_6', 'af', 'm', 23), FacePic('af2_7', 'af', 'f', 38), FacePic('af2_8', 'af', 'm', 60),
  FacePic('mx2_0', 'me', 'f', 28), FacePic('mx2_1', 'me', 'm', 55), FacePic('mx2_2', 'me', 'f', 65),
  FacePic('mx2_3', 'la', 'm', 27), FacePic('mx2_4', 'la', 'm', 50), FacePic('mx2_5', 'la', 'm', 70),
  FacePic('mx2_6', 'sea', 'f', 25), FacePic('mx2_7', 'sea', 'f', 50), FacePic('mx2_8', 'sea', 'm', 30),
  // 1.0.0+22 で足した70枚（la3_0・af3_8 は素材から外した）
  FacePic('me3_0', 'me', 'm', 24), FacePic('me3_1', 'me', 'm', 40), FacePic('me3_2', 'me', 'm', 68),
  FacePic('me3_3', 'me', 'f', 30), FacePic('me3_4', 'me', 'f', 45), FacePic('me3_5', 'me', 'f', 55),
  FacePic('me3_6', 'me', 'm', 33), FacePic('me3_7', 'me', 'f', 22), FacePic('me3_8', 'me', 'm', 60),
  FacePic('la3_1', 'la', 'm', 42), FacePic('la3_2', 'la', 'm', 66), FacePic('la3_3', 'la', 'f', 25),
  FacePic('la3_4', 'la', 'f', 40), FacePic('la3_5', 'la', 'f', 62), FacePic('la3_6', 'la', 'm', 35),
  FacePic('la3_7', 'la', 'f', 32), FacePic('la3_8', 'la', 'm', 55),
  // eaf・eam・wef・wem・af3 は年齢の違う別の人の並び（同じ人が年をとった絵ではない）
  FacePic('eaf_0', 'ea', 'f', 32), FacePic('eaf_1', 'ea', 'f', 38), FacePic('eaf_2', 'ea', 'f', 44),
  FacePic('eaf_3', 'ea', 'f', 48), FacePic('eaf_4', 'ea', 'f', 53), FacePic('eaf_5', 'ea', 'f', 58),
  FacePic('eaf_6', 'ea', 'f', 63), FacePic('eaf_7', 'ea', 'f', 70), FacePic('eaf_8', 'ea', 'f', 78),
  FacePic('eam_0', 'ea', 'm', 33), FacePic('eam_1', 'ea', 'm', 38), FacePic('eam_2', 'ea', 'm', 42),
  FacePic('eam_3', 'ea', 'm', 47), FacePic('eam_4', 'ea', 'm', 52), FacePic('eam_5', 'ea', 'm', 56),
  FacePic('eam_6', 'ea', 'm', 62), FacePic('eam_7', 'ea', 'm', 68), FacePic('eam_8', 'ea', 'm', 80),
  FacePic('wef_0', 'we', 'f', 32), FacePic('wef_1', 'we', 'f', 38), FacePic('wef_2', 'we', 'f', 44),
  FacePic('wef_3', 'we', 'f', 48), FacePic('wef_4', 'we', 'f', 53), FacePic('wef_5', 'we', 'f', 58),
  FacePic('wef_6', 'we', 'f', 63), FacePic('wef_7', 'we', 'f', 70), FacePic('wef_8', 'we', 'f', 78),
  FacePic('wem_0', 'we', 'm', 33), FacePic('wem_1', 'we', 'm', 38), FacePic('wem_2', 'we', 'm', 43),
  FacePic('wem_3', 'we', 'm', 47), FacePic('wem_4', 'we', 'm', 52), FacePic('wem_5', 'we', 'm', 57),
  FacePic('wem_6', 'we', 'm', 62), FacePic('wem_7', 'we', 'm', 68), FacePic('wem_8', 'we', 'm', 80),
  FacePic('sea3_0', 'sea', 'm', 26), FacePic('sea3_1', 'sea', 'm', 45), FacePic('sea3_2', 'sea', 'm', 65),
  FacePic('sea3_3', 'sea', 'f', 28), FacePic('sea3_4', 'sea', 'f', 45), FacePic('sea3_5', 'sea', 'f', 65),
  FacePic('sea3_6', 'sea', 'm', 35), FacePic('sea3_7', 'sea', 'f', 38), FacePic('sea3_8', 'sea', 'm', 55),
  FacePic('af3_0', 'af', 'm', 32), FacePic('af3_1', 'af', 'm', 40), FacePic('af3_2', 'af', 'm', 46),
  FacePic('af3_3', 'af', 'm', 52), FacePic('af3_4', 'af', 'f', 33), FacePic('af3_5', 'af', 'f', 55),
  FacePic('af3_6', 'af', 'm', 58), FacePic('af3_7', 'af', 'f', 62),
];

final Map<String, FacePic> faceById = {for (final f in FACES) f.id: f};

/// 絵のファイルの場所
String faceAsset(String id) => 'assets/faces/$id.png';

/// 名前の決まったハッシュ（FNV-1a の32ビット。端末・起動ごとに変わらない）
int nameHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c & 0xff;
    h = (h * 0x01000193) & 0xffffffff;
    h ^= c >> 8;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

String _famOf(String n) => n.contains('・') ? n.split('・').last : n.split(' ')[0];
String _givenOf(String n) {
  if (n.contains('・')) return n.split('・')[0];
  final p = n.split(' ');
  return p.length > 1 && p[1].isNotEmpty ? p[1] : n;
}

// ===== 性別 =====
// 人には性別の情報が無いので、名（下の名前）から決める表を作る。
// 名の一覧（MEI・NAMEP）は、日本の名が「前半15が男・後半15が女」、各国の名が「男・女の交互」に並んでいる（中国語の名だけは別に書く）。
// 宿敵の名は一覧に無いので足す。両方に入る名・どちらにも無い名（自分で付けた名など）は、名前のハッシュで決める。
const _zhFemale = {'芳', '娜', '敏', '静', '麗'};
const _extraFemale = {'麗子', 'アーニャ'};
const _extraMale = {'剛造', 'マーカス', '修', '天佑', '獅郎', '蒼'};

final Set<String> femaleGiven = {
  ...MEI.sublist(15),
  for (final e in NAMEP.entries)
    if (e.key == 'zh')
      ...e.value[1].where(_zhFemale.contains)
    else
      for (var i = 1; i < e.value[1].length; i += 2) e.value[1][i],
  ..._extraFemale,
};

final Set<String> maleGiven = {
  ...MEI.sublist(0, 15),
  for (final e in NAMEP.entries)
    if (e.key == 'zh')
      ...e.value[1].where((n) => !_zhFemale.contains(n))
    else
      for (var i = 0; i < e.value[1].length; i += 2) e.value[1][i],
  ..._extraMale,
};

/// 名前（姓名）から決まる性別（m / f）
String faceSex(String name) {
  final g = _givenOf(name);
  final f = femaleGiven.contains(g), m = maleGiven.contains(g);
  if (f != m) return f ? 'f' : 'm';
  return nameHash(name).isEven ? 'm' : 'f';
}

// ===== 地域 =====
/// 名前の組（NAMEP の鍵）→ 顔の地域
const Map<String, String> poolRegion = {
  'jp': 'ea', 'zh': 'ea', 'ko': 'ea',
  'hi': 'sa',
  'id': 'sea', 'th': 'sea', 'vi': 'sea', 'tl': 'sea',
  'en': 'we', 'de': 'we', 'fr': 'we', 'it': 'we', 'ru': 'we',
  'es': 'la', 'pt': 'la',
  'ar': 'me',
  'yo': 'af',
};

/// 一覧に無い姓（宿敵）の地域
const Map<String, String> _famRegion = {'黒田': 'ea', '真壁': 'ea', '西園寺': 'ea', '鬼塚': 'ea', '結城': 'ea', 'ヘイル': 'we', 'ヴォルコワ': 'we'};

/// 姓がどの名前の組のものか（[home] の国の組を先に見る。同じ姓が2つの組にあるため）
String? namePool(String name, {String? home}) {
  final fam = _famOf(name);
  bool has(String k) => k == 'jp' ? SEI.contains(fam) : (NAMEP[k]?[0].contains(fam) ?? false);
  final hp = home == null ? null : NAMEC[home];
  if (hp != null && has(hp)) return hp;
  if (has('jp')) return 'jp';
  for (final k in NAMEP.keys) {
    if (has(k)) return k;
  }
  return null;
}

/// 名前（と始めた国）から決まる顔の地域。
/// 国 → 名前の組 → 地域。始めた国が日本でなくても日本の名の人がいる（8人に1人）ので、国そのものではなく名前の組から決める。
/// 姓が一覧に無いとき（自分で付けた名など）は [home] の国の地域、それも無ければ「・」で区切る名は欧米、ほかは東アジア
String faceRegion(String name, {String? home}) {
  final pool = namePool(name, home: home);
  if (pool != null) {
    // スペインはスペイン語の名でも欧米、南アフリカは英語の名でアフリカと欧米が半々
    if (pool == 'es' && home == 'es') return 'we';
    if (pool == 'en' && home == 'za') return nameHash(name) % 2 == 0 ? 'af' : 'we';
    return poolRegion[pool]!;
  }
  final fr = _famRegion[_famOf(name)];
  if (fr != null) return fr;
  final hp = home == null ? null : NAMEC[home];
  if (hp != null) return hp == 'es' && home == 'es' ? 'we' : poolRegion[hp]!;
  return name.contains('・') ? 'we' : 'ea';
}

/// 年の合う自分の地域の絵が空いていないとき、同じ顔を重ねる前に借りてよい近い地域。
/// 1.0.0+23 から、借りるのは中南米 → 欧米・中東 → 南アジアだけ。
/// 東アジアと東南アジアは互いに借りない（肌の色と顔立ちが違って見える。足りなければ自分の地域の中で重ねる）
const Map<String, List<String>> _secondary = {
  'la': ['we'],
  'me': ['sa'],
};

const _regions = {'ea', 'we', 'sa', 'af', 'me', 'la', 'sea'};

/// ほぼ同じ絵（色だけ違う・ひげだけ違う）の組。並べると同じ顔に見えるので、重なりを数えるときは1つとみる
const Map<String, String> _sameLook = {
  'we_4': 'ea_4', 'sa_4': 'ea_4', 'we_5': 'ea_5', 'sa_5': 'ea_5',
  'ea2_8': 'we2_8', 'sa_2': 'we_2', 'we2_4': 'ea2_4',
};

/// 見た目で数えるときの絵の id（ほぼ同じ絵の組は、代表の1つにまとめる）
String faceLook(String id) => _sameLook[id] ?? id;

/// 本人と絵の年の差の上限。これを超えたら、その時点で年の近い絵に替える（1.0.0+23 から。それまでは35歳・55歳の2回だけ替えていた）
const faceGapMax = 12;

/// 替えた絵を少なくとも保つ年数（年の近い絵を選ぶとき、この年数のうちに上限を超える若い絵は後回しにする）
const faceHoldYears = 3;

String _reg(String region) => _regions.contains(region) ? region : 'we';

/// 絵 [id] が地域 [region] の人に使ってよい絵か（自分の地域か、借りてよい地域）。
/// 古いセーブで、地域を直した絵（we_4・we_5・ea_8 など）や東南アジア ⇔ 東アジアで借りた絵を持っていたら選び直すのに使う
bool faceFits(String? id, String region) {
  final f = faceById[id];
  if (f == null) return false;
  final reg = _reg(region);
  return f.region == reg || (_secondary[reg]?.contains(f.region) ?? false);
}

double _gap(FacePic f, num age) => (f.age - age).abs().toDouble();

final _limits = <String, double>{};

/// 地域 [region]・性別 [sex] の [age] 歳の人に許す、本人と絵の年の差。ふつうは [faceGapMax]（12歳）。
/// 使ってよい絵（借りてよい地域も）にそれより近いものが1枚も無いとき（とても年をとった人など）だけ、いちばん近い絵までの差
double faceGapLimit(String region, String sex, num age) {
  final reg = _reg(region);
  return _limits.putIfAbsent('$reg/$sex/$age', () {
    var best = double.infinity;
    for (final f in FACES) {
      if (f.sex == sex && faceFits(f.id, reg)) best = math.min(best, _gap(f, age));
    }
    return math.max(best, faceGapMax.toDouble());
  });
}

/// 年齢の違う別の人を並べた組（0→1→2 が同じ人ではない）
const _ladderSets = {'eaf', 'eam', 'wef', 'wem', 'af3'};

/// 同じ人が年代をまたいだときの続きの絵（同じ組の 0→1→2・3→4→5 は、同じ人が年をとった絵として描かれている）。
/// 地域・性別が同じものだけ（we_4・we_5 は東アジアに直したので、we_3 の続きにはしない）
String? faceNext(String id) {
  final i = id.lastIndexOf('_');
  if (i < 0) return null;
  final set = id.substring(0, i);
  if (_ladderSets.contains(set)) return null;
  final n = int.tryParse(id.substring(i + 1));
  if (n == null || !(n == 0 || n == 1 || n == 3 || n == 4)) return null;
  final next = '${set}_${n + 1}';
  final a = faceById[id], b = faceById[next];
  if (a == null || b == null || a.region != b.region || a.sex != b.sex) return null;
  return next;
}

/// 顔を選び直すときか。絵が無い・知らない絵（素材から消えた）・性別か地域の合わない絵・
/// 本人との年の差が [faceGapLimit]（ふつうは12歳）を超えた絵のとき true。
/// 年の差を超えたその時点で替える（1.0.0+23 から。それまでは35歳・55歳の2回だけだった）
bool faceStale(String? id, num age, {required String region, required String sex}) {
  final f = faceById[id];
  if (f == null || f.sex != sex || !faceFits(id, region)) return true;
  return _gap(f, age) > faceGapLimit(region, sex, age);
}

/// 同じ画面で顔が重なっている人の、重なりの少ない絵（この先 [faceHoldYears] 年は年の差の上限を超えない絵のうち、
/// [shared]（同じ画面でその絵を使っている人数。鍵は [faceLook]）のいちばん少ないもの。
/// 同じ数なら、ほかの画面の人（[used] の重さが [shared] の2倍を超える分）が使っていないもの → 自分の地域 → 年の近いもの → 名前のハッシュ）
String? faceLeastShared(
    {required String name, required num age, required String region, required String sex, required Map<String, int> shared, Map<String, int> used = const {}}) {
  final reg = _reg(region);
  final lim = faceGapLimit(reg, sex, age);
  final c = FACES
      .where((f) => f.sex == sex && faceFits(f.id, reg) && _gap(f, age) <= lim && (lim > faceGapMax || age + faceHoldYears - f.age <= lim))
      .toList();
  if (c.isEmpty) return null;
  int key(FacePic f) {
    final s = shared[faceLook(f.id)] ?? 0;
    return s * 4 + ((used[faceLook(f.id)] ?? 0) > s * 2 ? 2 : 0) + (f.region == reg ? 0 : 1);
  }
  final k = c.map(key).reduce(math.min);
  final best = c.where((f) => key(f) == k).toList();
  double cost(FacePic f) => f.age >= age ? f.age - age.toDouble() : (age - f.age) * 2.0;
  final m = best.map(cost).reduce(math.min);
  final near = best.where((f) => cost(f) <= m + 4).toList();
  return near[nameHash(name) % near.length].id;
}

/// 顔を1つ選ぶ（1.0.0+23 から。見た目の食い違いを、同じ顔の重なりより重く見る）。
/// ・使ってよいのは、本人との年の差が [faceGapLimit]（ふつうは12歳）までの絵だけ。それより離れた絵は、重ねてでも使わない
/// ・[prev]（今までの絵）があれば、同じ人が年をとった続きの絵を先に見る
/// ・自分の地域で空いている絵 → 借りてよい地域（中南米 → 欧米・中東 → 南アジア）で空いている絵 → 同じ顔を重ねる、の順。
///   重ねるときは [used] の数（同じ画面に並ぶ人ほど重い）のいちばん少ないもの
/// ・選ぶときは、この先 [faceHoldYears] 年は上限を超えない絵（年上の絵か、少し若い絵）を先にする。毎年替わってちらつかないように
/// ・年の近いもの（年上の絵はそのままの差、年下の絵は2倍の差で数えて、4歳までの差は同じとみる）を、名前のハッシュで分ける
/// [used] の鍵は [faceLook]（ほぼ同じ絵の組は1つ）
String pickFace({required String name, required num age, required String region, required String sex, Map<String, int> used = const {}, String? prev}) {
  final reg = _reg(region);
  final h = nameHash(name);
  final lim = faceGapLimit(reg, sex, age);
  double cost(FacePic f) => f.age >= age ? f.age - age.toDouble() : (age - f.age) * 2.0;
  bool ok(FacePic f) => _gap(f, age) <= lim;
  bool lasts(FacePic f) => ok(f) && (lim > faceGapMax || age + faceHoldYears - f.age <= lim);
  int use(FacePic f) => used[faceLook(f.id)] ?? 0;
  bool free(FacePic f) => use(f) == 0;
  if (prev != null) {
    final n = faceById[faceNext(prev)];
    if (n != null && n.sex == sex && faceFits(n.id, reg) && free(n) && lasts(n)) return n.id;
  }
  String? choose(Iterable<FacePic> all) {
    final c = all.toList();
    if (c.isEmpty) return null;
    final best = c.map(cost).reduce(math.min);
    final near = c.where((f) => cost(f) <= best + 4).toList();
    return near[h % near.length].id;
  }

  final own = FACES.where((f) => f.region == reg && f.sex == sex).toList();
  final sec = FACES.where((f) => (_secondary[reg]?.contains(f.region) ?? false) && f.sex == sex).toList();
  String? least(Iterable<FacePic> pool) {
    final c = pool.toList();
    if (c.isEmpty) return null;
    final n = c.map(use).reduce(math.min);
    return choose(c.where((f) => use(f) == n));
  }

  // 保てる絵: 空いているもの（自分の地域 → 借りてよい地域）→ 自分の地域で重ねる
  // （すぐ上限を超える若い絵に替えて数年のうちにまた替わるより、同じ顔が2人いるほうがまし）
  // 保てる絵が無いときだけ、年の差が上限までの絵（空いているもの → 重ねる）
  return choose(own.where((f) => free(f) && lasts(f))) ??
      choose(sec.where((f) => free(f) && lasts(f))) ??
      least(own.where(lasts)) ??
      least(sec.where(lasts)) ??
      choose(own.where((f) => free(f) && ok(f))) ??
      choose(sec.where((f) => free(f) && ok(f))) ??
      least(own.where(ok)) ??
      least(sec.where(ok)) ??
      choose(own)!;
}
