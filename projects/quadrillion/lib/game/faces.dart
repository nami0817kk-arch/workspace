// ignore_for_file: constant_identifier_names
/// 人の顔の絵（assets/faces/）と、その割り当て方（1.0.0+21。1.0.0+22 で160枚に増やした）。
/// Flutter に依存しない。ゲームの乱数は使わず、名前と年齢と「すでに使われている顔」だけで決まる。
library;

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

  /// 絵の年代（0 若い・1 中年・2 老年）
  int get band => age <= 32 ? 0 : (age <= 52 ? 1 : 2);
}

/// 顔の絵の一覧（素材の faces.json と同じ。全部で160枚）
const List<FacePic> FACES = [
  FacePic('ea_0', 'ea', 'm', 25), FacePic('ea_1', 'ea', 'm', 45), FacePic('ea_2', 'ea', 'm', 65),
  FacePic('ea_3', 'ea', 'f', 25), FacePic('ea_4', 'ea', 'f', 45), FacePic('ea_5', 'ea', 'f', 65),
  FacePic('ea_6', 'ea', 'm', 35), FacePic('ea_7', 'ea', 'f', 35), FacePic('ea_8', 'ea', 'm', 55),
  FacePic('we_0', 'we', 'm', 25), FacePic('we_1', 'we', 'm', 45), FacePic('we_2', 'we', 'm', 65),
  // we_4・we_5 は見た目が東アジアなので東アジア（1.0.0+22 で直した。ファイル名はそのまま）
  FacePic('we_3', 'we', 'f', 25), FacePic('we_4', 'ea', 'f', 45), FacePic('we_5', 'ea', 'f', 65),
  FacePic('we_6', 'we', 'm', 35), FacePic('we_7', 'we', 'f', 35), FacePic('we_8', 'we', 'm', 55),
  FacePic('sa_0', 'sa', 'm', 25), FacePic('sa_1', 'sa', 'm', 45), FacePic('sa_2', 'sa', 'm', 65),
  FacePic('sa_3', 'sa', 'f', 25), FacePic('sa_4', 'sa', 'f', 45), FacePic('sa_5', 'sa', 'f', 65),
  FacePic('sa_6', 'sa', 'm', 35), FacePic('sa_7', 'sa', 'f', 35), FacePic('sa_8', 'sa', 'm', 55),
  FacePic('af_0', 'af', 'm', 25), FacePic('af_1', 'af', 'm', 45), FacePic('af_2', 'af', 'm', 65),
  FacePic('af_3', 'af', 'f', 25), FacePic('af_4', 'af', 'f', 45), FacePic('af_5', 'af', 'f', 65),
  FacePic('af_6', 'af', 'm', 35), FacePic('af_7', 'af', 'f', 35), FacePic('af_8', 'af', 'm', 55),
  FacePic('mx_0', 'me', 'm', 25), FacePic('mx_1', 'me', 'm', 45), FacePic('mx_2', 'me', 'm', 65),
  FacePic('mx_3', 'la', 'f', 25), FacePic('mx_4', 'la', 'f', 45), FacePic('mx_5', 'la', 'f', 65),
  FacePic('mx_6', 'me', 'f', 40), FacePic('mx_7', 'la', 'm', 35), FacePic('mx_8', 'sea', 'm', 50),
  FacePic('ea2_0', 'ea', 'm', 30), FacePic('ea2_1', 'ea', 'm', 50), FacePic('ea2_2', 'ea', 'm', 70),
  FacePic('ea2_3', 'ea', 'f', 28), FacePic('ea2_4', 'ea', 'f', 50), FacePic('ea2_5', 'ea', 'f', 70),
  FacePic('ea2_6', 'ea', 'm', 22), FacePic('ea2_7', 'ea', 'f', 40), FacePic('ea2_8', 'ea', 'm', 60),
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

/// 人の年代（0 〜34歳・1 35〜54歳・2 55歳〜）。絵が替わるのは、この境をまたぐ35歳と55歳の2回だけ
int ageBand(num age) => age < 35 ? 0 : (age < 55 ? 1 : 2);

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

/// 年の合う自分の地域の絵が空いていないとき、年の差を広げる前に借りる近い地域
/// （1.0.0+22: 東南アジアが13枚になったので東アジアと混ぜるのをやめ、東南アジア → 東アジアの順にした。
///  中南米は欧米、中東は南アジアから。どちらも13〜16枚になったので、借りるのは年の合う自分の絵が尽きたときだけ）
const Map<String, List<String>> _secondary = {
  'sea': ['ea'],
  'la': ['we'],
  'me': ['sa'],
};

/// 年の差を広げても自分の地域の絵が空いていないときだけ借りる地域（重ねる前の最後）。
/// 東アジアの人に東南アジアの絵を借りるのは、東アジアの空きが本当に無いときだけ
const Map<String, List<String>> _lastResort = {
  'ea': ['sea'],
};

const _regions = {'ea', 'we', 'sa', 'af', 'me', 'la', 'sea'};

/// 絵 [id] が地域 [region] の人に使ってよい絵か（自分の地域か、借りてよい地域）。
/// 1.0.0+21 までのセーブで、地域を直した絵（we_4・we_5）を欧米の人が持っていたら選び直すのに使う
bool faceFits(String? id, String region) {
  final f = faceById[id];
  if (f == null) return false;
  final reg = _regions.contains(region) ? region : 'we';
  return f.region == reg || (_secondary[reg]?.contains(f.region) ?? false) || (_lastResort[reg]?.contains(f.region) ?? false);
}

/// ふつうに使う年の差の幅（近い地域から借りるのもこの幅の中だけ）と、
/// 空きが無いときに広げる幅（本人より年上の絵は20歳まで・年下の絵は25歳まで）
const _ageSpan = 15, _olderMax = 20, _youngerMax = 25;

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

/// 顔を選び直すときか。[band] は顔を決めたときの年代（人に保存してある）。
/// 年代をまたいだ（35歳・55歳になった）ときと、絵が無い・知らない絵（素材から消えた）のときだけ true。
/// 決めたときの年代で比べるので、絵が替わるのは一生で2回まで
bool faceStale(String? id, int? band, num age) => id == null || band == null || !faceById.containsKey(id) || ageBand(age) > band;

/// 顔を1つ選ぶ。
/// ・地域 [region] と性別 [sex] の絵の中から、今の年齢 [age] にいちばん近いもの（6歳までの差は同じとみて、名前のハッシュで分ける。
///   年代より若い絵は8歳ぶん遠いものとして数え、同じ年代か上の年代の絵を先に選ぶ）
/// ・[used]（同じ会社の人・宿敵どうしがもう使っている顔と、その人数）にあるものは避ける
/// ・年の合う空きが無ければ、近い地域から借りる → 年の差の幅を広げる →（東アジアだけ）東南アジアから借りる →
///   それでも空きが無ければ、年の合う絵のうち使われている数のいちばん少ないものを重ねる
/// ・[prev]（今までの絵）があれば、同じ人が年をとった続きの絵を先に見る
String pickFace({required String name, required num age, required String region, required String sex, Map<String, int> used = const {}, String? prev}) {
  final band = ageBand(age);
  final h = nameHash(name);
  double d(FacePic f) {
    // 老年の人には、老年の絵ならどれでも合う（80歳でも70歳の絵でよい）
    if (band == 2 && f.band == 2) return (f.age - age).abs().clamp(0, _ageSpan).toDouble();
    return ((f.age - age).abs() + (f.band < band ? 8 : 0)).toDouble();
  }

  bool free(FacePic f) => (used[f.id] ?? 0) == 0;
  if (prev != null) {
    final n = faceById[faceNext(prev)];
    if (n != null && n.sex == sex && faceFits(n.id, region) && free(n) && d(n) <= _olderMax) return n.id;
  }
  String? choose(Iterable<FacePic> all) {
    final c = all.toList();
    if (c.isEmpty) return null;
    final best = c.map(d).reduce((a, b) => a < b ? a : b);
    final near = c.where((f) => d(f) <= best + 6).toList();
    return near[h % near.length].id;
  }

  final reg = _regions.contains(region) ? region : 'we';
  final sec = _secondary[reg] ?? const <String>[];
  final last = _lastResort[reg] ?? const <String>[];
  final own = FACES.where((f) => f.region == reg && f.sex == sex).toList();
  final near = FACES.where((f) => sec.contains(f.region) && f.sex == sex).toList();
  final far = FACES.where((f) => last.contains(f.region) && f.sex == sex).toList();
  // 空いている絵があるうちは同じ顔を重ねない。ただし年が離れすぎた絵（20歳より上・25歳より下）は使わない
  // （28歳の人に72歳の絵を当てるより、同じ顔が2人いるほうがまし）
  bool wide(FacePic f) => (band == 2 && f.band == 2) || (f.age - age <= _olderMax && age - f.age <= _youngerMax);
  final got = choose(own.where((f) => free(f) && d(f) <= _ageSpan)) ??
      choose(near.where((f) => free(f) && d(f) <= _ageSpan)) ??
      choose(own.where((f) => free(f) && wide(f))) ??
      choose(far.where((f) => free(f) && d(f) <= _ageSpan));
  if (got != null) return got;
  // 重ねる: 年の合う絵のうち、使われている数の少ないものから
  var pool = own.where((f) => d(f) <= _ageSpan).toList();
  if (pool.isEmpty) pool = own;
  if (pool.isEmpty) pool = FACES.where((f) => f.sex == sex).toList();
  final least = pool.map((f) => used[f.id] ?? 0).reduce((x, y) => x < y ? x : y);
  return choose(pool.where((f) => (used[f.id] ?? 0) == least))!;
}
