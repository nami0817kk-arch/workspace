import 'dart:math';

import '../game/formulas.dart';

/// 局面プールの種類。細かいポジションはこのどれかに属する。
///
/// ポジションごとに局面を全部書き分けると量が爆発するので、
/// 「どんな場面に立ち会うか」の単位でまとめてある。
enum ScenarioFamily { goalkeeper, defence, midfield, forward }

/// 選手のポジション。
enum Position {
  gk('GK', 'ゴールキーパー', ScenarioFamily.goalkeeper),
  cb('CB', 'センターバック', ScenarioFamily.defence),
  sb('SB', 'サイドバック', ScenarioFamily.defence),
  dm('DM', '守備的MF', ScenarioFamily.midfield),
  cm('CM', 'セントラルMF', ScenarioFamily.midfield),
  am('OMF', '攻撃的MF', ScenarioFamily.midfield),
  wg('WG', 'ウイング', ScenarioFamily.forward),
  st('ST', 'ストライカー', ScenarioFamily.forward);

  const Position(this.label, this.fullName, this.family);

  final String label;
  final String fullName;
  final ScenarioFamily family;

  /// 左右のある役割か。サイドバックとウイングだけ。
  ///
  /// センターバックやボランチにも左右はあるが、求められるものが
  /// ほとんど変わらない。効きの無い選択肢を増やさない。
  bool get hasSide => this == Position.sb || this == Position.wg;

  /// 保存データから復元する。
  ///
  /// 3ポジションだった頃の保存データ（fw / mf / df）も読めるようにしてある。
  /// 読めないと、更新した途端にキャリアが消える。
  static Position parse(String name) => switch (name) {
        'fw' => Position.st,
        'mf' => Position.cm,
        'df' => Position.cb,
        _ => Position.values.byName(name),
      };
}

/// 能力のカテゴリ。画面の上段と、練習の単位。
enum AttributeKey {
  pace('スピード'),
  shooting('シュート'),
  passing('パス'),
  dribbling('ドリブル'),
  defending('守備'),
  physical('フィジカル'),
  goalkeeping('GK');

  const AttributeKey(this.label);

  final String label;

  List<Detail> get details =>
      Detail.values.where((d) => d.category == this).toList();
}

/// 詳細能力。局面の判定はこの単位で行う。
///
/// 「パスが上手い」で一括りにすると、スルーパスの名手とクロスの名手の
/// 違いが出ない。カテゴリはあくまで見せ方と練習の単位で、判定はこちら。
enum Detail {
  acceleration('加速', AttributeKey.pace),
  sprintSpeed('最高速', AttributeKey.pace),

  finishing('決定力', AttributeKey.shooting),
  shotPower('シュート力', AttributeKey.shooting),
  longShots('ロングシュート', AttributeKey.shooting),
  heading('ヘディング', AttributeKey.shooting),

  shortPassing('ショートパス', AttributeKey.passing),
  longPassing('ロングパス', AttributeKey.passing),
  vision('視野', AttributeKey.passing),
  crossing('クロス', AttributeKey.passing),

  ballControl('ボールコントロール', AttributeKey.dribbling),
  dribbling('ドリブル', AttributeKey.dribbling),
  agility('敏捷性', AttributeKey.dribbling),

  tackling('タックル', AttributeKey.defending),
  marking('マーク', AttributeKey.defending),
  interceptions('インターセプト', AttributeKey.defending),

  strength('筋力', AttributeKey.physical),
  stamina('スタミナ', AttributeKey.physical),
  jumping('ジャンプ', AttributeKey.physical),

  reflexes('セービング', AttributeKey.goalkeeping),
  gkPositioning('ポジショニング', AttributeKey.goalkeeping),
  handling('ハンドリング', AttributeKey.goalkeeping);

  const Detail(this.label, this.category);

  final String label;
  final AttributeKey category;
}

/// 能力値。22の詳細能力を持ち、7カテゴリはその平均。
class Attributes {
  Attributes._(List<int> values) : _values = List.unmodifiable(values);

  /// 詳細能力を直接指定して作る。保存データの読み込みもここを通る。
  ///
  /// 上限を超えた値（超越の特性で伸ばしたぶん）を潰さないよう、
  /// 丸めは [Formulas.absoluteMax] で行う。
  factory Attributes.fromDetails(Map<Detail, int> details) => Attributes._([
        for (final d in Detail.values)
          _clamp(details[d] ?? Formulas.defaultGoalkeeping,
              max: Formulas.absoluteMax),
      ]);

  /// カテゴリの値から作る。各カテゴリの詳細はすべて同じ値になる。
  ///
  /// 初期能力の定義とテスト、7項目だった頃の保存データの読み込みに使う。
  factory Attributes({
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
    int goalkeeping = Formulas.defaultGoalkeeping,
  }) {
    final byCategory = {
      AttributeKey.pace: pace,
      AttributeKey.shooting: shooting,
      AttributeKey.passing: passing,
      AttributeKey.dribbling: dribbling,
      AttributeKey.defending: defending,
      AttributeKey.physical: physical,
      AttributeKey.goalkeeping: goalkeeping,
    };
    return Attributes._([
      for (final d in Detail.values) _clamp(byCategory[d.category]!),
    ]);
  }

  /// カテゴリの値に、詳細ごとのばらつきを足して作る。
  ///
  /// 新規キャリアで使う。全部同じ値だと「決定力だけ高いFW」のような
  /// 個性が最初から無い。
  factory Attributes.scattered({
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
    int goalkeeping = Formulas.defaultGoalkeeping,
    required Random random,
    int spread = 6,
  }) {
    final base = Attributes(
      pace: pace,
      shooting: shooting,
      passing: passing,
      dribbling: dribbling,
      defending: defending,
      physical: physical,
      goalkeeping: goalkeeping,
    );
    return Attributes._([
      for (final d in Detail.values)
        _clamp(base.detail(d) + random.nextInt(spread * 2 + 1) - spread),
    ]);
  }

  final List<int> _values;

  static int _clamp(int v, {int max = Formulas.maxAttribute}) =>
      v.clamp(Formulas.minAttribute, max).toInt();

  int detail(Detail d) => _values[d.index];

  /// カテゴリの値（そのカテゴリの詳細の平均）。
  int operator [](AttributeKey key) {
    final ds = key.details;
    final sum = ds.fold(0, (s, d) => s + _values[d.index]);
    return (sum / ds.length).round();
  }

  int get pace => this[AttributeKey.pace];
  int get shooting => this[AttributeKey.shooting];
  int get passing => this[AttributeKey.passing];
  int get dribbling => this[AttributeKey.dribbling];
  int get defending => this[AttributeKey.defending];
  int get physical => this[AttributeKey.physical];
  int get goalkeeping => this[AttributeKey.goalkeeping];

  /// ポジションごとの重み付き総合力。同じ能力でも ST と CB で評価が変わる。
  int overallFor(Position position) {
    final w = _weights[position]!;
    final sum = pace * w[0] +
        shooting * w[1] +
        passing * w[2] +
        dribbling * w[3] +
        defending * w[4] +
        physical * w[5] +
        goalkeeping * w[6];
    return (sum / w.reduce((a, b) => a + b)).round();
  }

  static const Map<Position, List<int>> _weights = {
    //                pace sho pas dri def phy gk
    Position.gk: [1, 0, 1, 0, 2, 3, 10],
    Position.cb: [2, 0, 2, 1, 6, 5, 0],
    Position.sb: [4, 1, 3, 3, 4, 3, 0],
    Position.dm: [2, 1, 4, 2, 5, 4, 0],
    Position.cm: [2, 2, 5, 4, 3, 3, 0],
    Position.am: [3, 4, 5, 5, 1, 2, 0],
    Position.wg: [5, 3, 3, 5, 1, 2, 0],
    Position.st: [3, 6, 2, 3, 0, 4, 0],
  };

  /// そのポジションの総合力に占める、あるカテゴリの重み（0〜1）。
  ///
  /// GK は総合力の6割が GK 能力で、しかも詳細が3つしかない。同じ1回の
  /// 練習でも総合力の動き方がポジションで倍近く違い、GK だけが
  /// 9割ポテンシャルに到達していた。成長の側で割り戻すために使う。
  static double weightShare(Position position, AttributeKey key) {
    final w = _weights[position]!;
    final total = w.reduce((a, b) => a + b);
    return w[AttributeKey.values.indexOf(key)] / total;
  }

  /// 詳細能力を1つ増減させた新しい能力値を返す。上下限で丸める。
  ///
  /// [max] はその詳細能力の上限。超越の特性を持つ選手はここが 99 を超える。
  Attributes bumpDetail(Detail d, int delta,
      {int max = Formulas.maxAttribute}) {
    final next = [..._values];
    next[d.index] = _clamp(next[d.index] + delta, max: max);
    return Attributes._(next);
  }

  /// カテゴリの中の詳細を1つ選んで増減させる。練習と試合の成長で使う。
  Attributes bump(AttributeKey key, int delta, {Random? random}) {
    final ds = key.details;
    final d = ds[(random ?? Random()).nextInt(ds.length)];
    return bumpDetail(d, delta);
  }

  Map<String, dynamic> toJson() => {
        'details': {for (final d in Detail.values) d.name: _values[d.index]},
      };

  factory Attributes.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>?;
    if (details != null) {
      return Attributes.fromDetails({
        for (final d in Detail.values)
          if (details[d.name] is int) d: details[d.name] as int,
      });
    }
    // 7項目だった頃の保存データ。カテゴリの値を詳細に展開する。
    return Attributes(
      pace: json['pace'] as int,
      shooting: json['shooting'] as int,
      passing: json['passing'] as int,
      dribbling: json['dribbling'] as int,
      defending: json['defending'] as int,
      physical: json['physical'] as int,
      goalkeeping: json['goalkeeping'] as int? ?? Formulas.defaultGoalkeeping,
    );
  }
}
