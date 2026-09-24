import 'dart:math';

import '../models/attributes.dart';
import '../models/club.dart';
import 'world.dart';

/// 他クラブに居る、名前のある1人。
///
/// **保存しない。** クラブIDと年から毎回同じものを組み立てる
/// （`ClubIdentity` / `ClubStyle` / 得点王と同じ理屈）。
/// 25人 × 全クラブを保存に乗せると、端末の localStorage には収まらない。
class SquadPlayer {
  const SquadPlayer({
    required this.name,
    required this.position,
    required this.age,
    required this.overall,
    required this.countryId,
  });

  final String name;
  final Position position;
  final int age;

  /// そのクラブでの力。主力ほど高い。
  final int overall;

  /// 国籍。外国人枠の判定に要る。
  final String countryId;

  /// 同じ枠を争う相手か。**ファミリーで見る**——SB と CB は同じ局面を引き、
  /// 先発の序列でも同じ列に並ぶ（`Attributes` の重みが違うだけ）。
  bool competesWith(Position other) => position.family == other.family;

  @override
  String toString() => '$name($position.label $overall/$age)';
}

/// クラブの名簿。**クラブIDから決まるので、毎回同じ。**
///
/// これを入れる前は、外国人枠の使用数も・登録メンバーに入れるかも・
/// 先発の序列も・得点王も、**全部「クラブの強さから逆算した見積もり」**
/// だった。見積もりは当たっていても、**移籍先に誰が居るのかが見えない**。
class Squad {
  const Squad._(this.club, this.players);

  final Club club;
  final List<SquadPlayer> players;

  /// **1クラブ25人**（登録メンバーの枠と同じ）。
  static const int size = 25;

  /// ポジションの内訳。25人ぶん。
  static const List<Position> _shape = [
    Position.gk,
    Position.gk,
    Position.gk,
    Position.cb,
    Position.cb,
    Position.cb,
    Position.cb,
    Position.sb,
    Position.sb,
    Position.sb,
    Position.sb,
    Position.dm,
    Position.dm,
    Position.dm,
    Position.cm,
    Position.cm,
    Position.cm,
    Position.cm,
    Position.am,
    Position.am,
    Position.wg,
    Position.wg,
    Position.wg,
    Position.st,
    Position.st,
  ];

  static final Map<String, Squad> _cache = {};

  /// そのクラブの、その年の名簿。
  ///
  /// **年で引き直す**ので、歳を取った選手は抜けて若い選手が入る。
  /// 保存しないぶん、続きは持たない——同じ年なら必ず同じ顔ぶれになる。
  static Squad of(Club club, {required int year}) {
    final key = '${club.id}|$year';
    final hit = _cache[key];
    if (hit != null && hit.club.strength == club.strength) return hit;
    final built = Squad._(club, _build(club, year));
    // 引き直しは重いので覚えておく。溜まりすぎたら捨てる
    // （1キャリア19季 × 20クラブ × 11国で、放っておくと数千件になる）。
    if (_cache.length > 600) _cache.clear();
    _cache[key] = built;
    return built;
  }

  /// そのポジションを争う相手を、強い順に。
  List<SquadPlayer> rivalsFor(Position position) => [
    for (final p in players)
      if (p.competesWith(position)) p,
  ]..sort((a, b) => b.overall.compareTo(a.overall));

  /// 外国人枠を使っている人数。
  ///
  /// **以前は `(limit * (strength-30)/62).round()` という見積もりだった。**
  /// いまは実際に名簿を数える——だからクラブごとに空きが違う。
  int get foreignCount =>
      players.where((p) => p.countryId != club.countryId).length;

  /// 主力11人。強い順の上から取る。
  List<SquadPlayer> get starters {
    final sorted = [...players]..sort((a, b) => b.overall.compareTo(a.overall));
    return sorted.take(11).toList();
  }

  /// そのクラブで一番点を取る選手。得点王レースに出る顔。
  SquadPlayer get topScorer {
    final attackers = [
      for (final p in players)
        if (p.position.family == ScenarioFamily.forward) p,
    ]..sort((a, b) => b.overall.compareTo(a.overall));
    return attackers.isEmpty ? players.first : attackers.first;
  }

  /// そのファミリーで、クラブが登録する人数。
  ///
  /// 25人枠の内訳そのもの（GK3・守備8・中盤9・前痚5）。
  /// **別の表を作らない**——名簿の形と登録の定員がずれると、
  /// 「あなたより上が何人」という説明が実際の判定と合わなくなる。
  static int quotaFor(ScenarioFamily family) =>
      _shape.where((p) => p.family == family).length;

  /// 同じ枠で一番強い相手。先発を争うのはこの人。
  SquadPlayer bestRival(Position position) {
    final list = rivalsFor(position);
    return list.isEmpty ? players.first : list.first;
  }

  /// 同じ枠を争う相手のうち、その総合力を上回る人数。
  int aheadOf(Position position, int overall) => players
      .where((p) => p.competesWith(position) && p.overall > overall)
      .length;

  /// 名簿の中で、その総合力が上から何番目に入るか（1始まり）。
  int rankOf(int overall) {
    var above = 0;
    for (final p in players) {
      if (p.overall > overall) above++;
    }
    return above + 1;
  }

  /// 歳を取ると落ちる。若いうちはまだ届いていない。
  ///
  /// 選手本人の成長曲線（`growthByAge` と衷え始め）と同じ形を
  /// なぞるだけで、別の式にはしない——名簿は判定に使わない数字なので
  /// ここは「それらしく見える」だけでよい。
  static int _ageAdjust(int age) {
    if (age <= 20) return -(21 - age) * 3;
    if (age <= 28) return 0;
    return -(age - 28) * 2;
  }

  /// 選手1人がこの枠に居られる年数。超えたら次の世代に入れ替わる。
  static const int _span = 18;

  static List<SquadPlayer> _build(Club club, int year) {
    // **種に年を混ぜない。** 混ぜると毎年まるごと別人になる。
    // 生まれ年を持たせて、そこから歳を出す——同じ選手が
    // 歳を取って、約年を越えたら若い選手に入れ替わる。
    final seed = club.id.codeUnits.fold<int>(
      11,
      (a, b) => (a * 31 + b) & 0x3fffffff,
    );
    final random = Random(seed);
    final country = World.byId(club.countryId);
    final limit = country.foreignRule.squadLimit;

    // **外国人は枠の中でクラブごとに違う。** 見積もりの頃は
    // 強さから一意に決まっていたので、「どこも同じだけ埋まっている」ことに
    // なっていた——空きのあるクラブを探す、が成立しない。
    final maxForeign = limit ?? 12;
    final appetite = ((club.strength - 30) / 62).clamp(0.0, 1.0);
    final foreigners =
        (maxForeign * appetite * (0.55 + random.nextDouble() * 0.7))
            .round()
            .clamp(0, maxForeign);

    final others = [
      for (final c in World.countries)
        if (c.id != club.countryId) c.id,
    ];

    final players = <SquadPlayer>[];
    for (var i = 0; i < _shape.length; i++) {
      // 上から順に主力。**クラブの強さを主力の水準に合わせる**
      // （`club.strength` は「そこで主力を張る選手の総合力」）。
      final depth = i / (_shape.length - 1); // 0..1
      final peak = (club.strength + 6 - depth * 22 + random.nextInt(7) - 3)
          .round()
          .clamp(32, 94);
      // 基準の年（`_epoch`）に何歳だったかを引いて、生まれ年に直す。
      var born = _epoch - (19 + random.nextInt(15));
      // 約年を越えた世代は、次の選手に入れ替わる。
      var generation = 0;
      while (year - born > 36) {
        born += _span;
        generation++;
      }
      final age = year - born;
      // **同じ名前が1つの名簿に2人入らないようにする。**
      // 組み合わせは 40×28 しか無いので、25人引けばぶつかる。
      var name = _nameFor(seed + i * 977 + generation * 40009);
      for (var retry = 1; players.any((p) => p.name == name); retry++) {
        name = _nameFor(seed + i * 977 + generation * 40009 + retry * 7919);
      }
      players.add(
        SquadPlayer(
          name: name,
          position: _shape[i],
          age: age,
          overall: (peak + _ageAdjust(age)).clamp(30, 94),
          countryId: i < foreigners && others.isNotEmpty
              ? others[(seed + i * 7 + generation) % others.length]
              : club.countryId,
        ),
      );
    }
    return players;
  }

  /// 生まれ年を数えるための基準の年。この値自体に意味は無い——
  /// ずらしても、全クラブが同じだけずれる。
  static const int _epoch = 2026;

  static String _nameFor(int seed) {
    final random = Random(seed);
    final first = _first[random.nextInt(_first.length)];
    final last = _last[random.nextInt(_last.length)];
    return '$first$last';
  }

  /// 名前は「姓・名」の組み合わせで作る。
  ///
  /// 一覧を手で並べると、20クラブ × 25人 = 500人ぶん要る。
  /// 組み合わせなら 40 × 24 = 960通りで足りる。
  static const List<String> _first = [
    'ルイス・',
    'オマール・',
    'ヤン・',
    'ディエゴ・',
    'マティアス・',
    'サム・',
    'ラウル・',
    'アンドレス・',
    'ヨナス・',
    'イリヤ・',
    'カルロ・',
    'エミル・',
    'タデウス・',
    'ジョアン・',
    'ミゲル・',
    'ニコ・',
    'アダム・',
    'イヴァン・',
    'マテオ・',
    'カイル・',
    'ルカ・',
    'エミール・',
    'トマス・',
    'フェリペ・',
    'オスカル・',
    'ダニエル・',
    'アルベルト・',
    'ヴィクトル・',
    'パウロ・',
    'セルヒオ・',
    '沢渡 ',
    '結城 ',
    '桐生 ',
    '真柴 ',
    '南雲 ',
    '早乙女 ',
    '真木 ',
    '早瀬 ',
    '神無月 ',
    '天羽 ',
  ];

  static const List<String> _last = [
    'カルモナ',
    'ベンサイド',
    'コヴァル',
    'ロメロ',
    'ケラー',
    'アディヤ',
    'ナバス',
    'ピント',
    'ヴィーク',
    'ソローキン',
    'ベルティ',
    'ラーション',
    'ノヴァク',
    'シルヴァ',
    'アロンソ',
    'ヴァルタ',
    'ケリー',
    'ペトロフ',
    'リカルド',
    'ベネット',
    '玲司',
    '隼人',
    '湊',
    '篤',
    '廉',
    '匠',
    '遼',
    '樹',
  ];
}
