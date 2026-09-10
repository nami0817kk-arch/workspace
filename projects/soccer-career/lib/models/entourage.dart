import 'dart:math';

import '../game/formulas.dart';
import 'attributes.dart';
import 'club.dart';
import 'injury.dart';

/// 監督の戦術。
///
/// クラブごとに固定ではなく、監督に付く。監督が代われば、
/// 同じクラブでも求められるものが変わる。
enum Tactic {
  possession('ポゼッション', [AttributeKey.passing, AttributeKey.dribbling]),
  counter('カウンター', [AttributeKey.pace, AttributeKey.shooting]),
  press('ハイプレス', [AttributeKey.physical, AttributeKey.defending]),
  direct('ロングボール', [AttributeKey.physical, AttributeKey.shooting]),
  balanced('バランス', []);

  const Tactic(this.label, this.favours);

  final String label;

  /// この戦術で重く見られる能力。
  final List<AttributeKey> favours;
}

/// 監督。
///
/// 名前も架空。戦術と要求の厳しさを持ち、選手との相性が出場機会に効く。
/// 監督が代わるのはキャリアで一番よくある転機なので、ここを飾りにしない。
class Manager {
  const Manager({
    required this.name,
    required this.tactic,
    required this.demand,
    this.tenure = 0,
  });

  final String name;
  final Tactic tactic;

  /// 要求の厳しさ 1〜5。高いほど信頼が動きやすい。
  final int demand;

  /// 在任年数。
  final int tenure;

  static const List<String> _firstNames = [
    'ラウル', 'ヨナス', 'ミハイル', '相原', 'ディエゴ', 'アルフ',
    'カルロ', '安永', 'ヘンドリク', 'ソン', 'ファビオ', '黒木',
  ];
  static const List<String> _lastNames = [
    'メンドーサ', 'ベルガー', 'ソコロフ', '達郎', 'アルベス', 'ソレンセン',
    'ヴィターリ', '慎司', 'デ・フリース', 'ジュンホ', 'ロッシ', '亮平',
  ];

  factory Manager.roll(Random random) => Manager(
        name: '${_firstNames[random.nextInt(_firstNames.length)]}・'
            '${_lastNames[random.nextInt(_lastNames.length)]}',
        tactic: Tactic.values[random.nextInt(Tactic.values.length)],
        demand: 1 + random.nextInt(5),
      );

  /// 戦術との噛み合い。−1.0〜1.0。
  ///
  /// 求められる能力が自分の得意と重なっているか。バランス型は誰でも中庸。
  double fitFor(Attributes attributes, Position position) {
    if (tactic.favours.isEmpty) return 0;
    final overall = attributes.overallFor(position);
    final favoured = tactic.favours
            .fold(0, (sum, key) => sum + attributes[key]) /
        tactic.favours.length;
    return ((favoured - overall) / 12).clamp(-1.0, 1.0);
  }

  /// 相性が出場機会に与える下駄。
  double appearanceBonus(Attributes attributes, Position position) =>
      fitFor(attributes, position) * 0.18;

  /// その手が、監督の求める形に沿っているか。
  ///
  /// バランス型は何も求めないので、どの手も中立。
  bool favours(AttributeKey key) => tactic.favours.contains(key);

  /// 1試合ぶんの選択が、信頼をどれだけ動かすか。
  ///
  /// 沿った手と逆らった手の差で見る。要求の厳しい監督ほど強く響く。
  double trustShift({required int followed, required int against}) {
    if (tactic.favours.isEmpty) return 0;
    final moments = followed + against;
    if (moments == 0) return 0;
    return (followed - against) /
        moments *
        Formulas.trustPerTacticFit *
        (1 + (demand - 3) * Formulas.trustPerDemand);
  }

  String fitLabel(Attributes attributes, Position position) {
    final fit = fitFor(attributes, position);
    if (fit >= 0.4) return '戦術に嵌まっている';
    if (fit >= 0.1) return '悪くない';
    if (fit > -0.2) return '可も不可も無い';
    return '戦術に合っていない';
  }

  Manager aged() => Manager(
        name: name,
        tactic: tactic,
        demand: demand,
        tenure: tenure + 1,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'tactic': tactic.name,
        'demand': demand,
        'tenure': tenure,
      };

  factory Manager.fromJson(Map<String, dynamic>? json, Random random) {
    if (json == null) return Manager.roll(random);
    return Manager(
      name: json['name'] as String? ?? '監督',
      tactic: Tactic.values.any((t) => t.name == json['tactic'])
          ? Tactic.values.byName(json['tactic'] as String)
          : Tactic.balanced,
      demand: json['demand'] as int? ?? 3,
      tenure: json['tenure'] as int? ?? 0,
    );
  }
}

/// クラブに自分から出す方針。
///
/// 何を優先したいかを伝える。通る通らないではなく、優先した分だけ
/// 別のものを諦める形にしてある。
enum Directive {
  playingTime('出場機会が欲しい', '序列で優遇されるが、年俸は伸びない'),
  winning('勝ちたい', '監督の信頼は得やすいが、出番は保証されない'),
  money('条件を上げたい', '年俸交渉は通りやすく、ロッカールームでは浮く'),
  develop('育ててほしい', '練習の効きが上がるが、試合では我慢を強いられる'),
  none('特に伝えない', '');

  const Directive(this.label, this.effect);

  final String label;
  final String effect;

  double get appearanceBonus => switch (this) {
        Directive.playingTime => 0.12,
        Directive.develop => -0.08,
        _ => 0,
      };

  double get growthFactor => this == Directive.develop ? 1.15 : 1.0;

  double get negotiationBonus => this == Directive.money ? 0.08 : 0;

  int get managerDrift => switch (this) {
        Directive.winning => 4,
        Directive.money => -3,
        _ => 0,
      };

  int get teammatesDrift => this == Directive.money ? -3 : 0;
}

/// チームメイトとの関係。
///
/// 3種類しか置かないのは、名前のある他人を増やしても管理が増えるだけで、
/// 効くのは「誰と競い、誰と組み、誰に学ぶか」の3つだけだから。
enum TeammateKind {
  rival('同ポジションの競争相手'),
  partner('相方'),
  mentor('メンター');

  const TeammateKind(this.label);

  final String label;
}

/// クラブの中に居る、名前のある1人。
class Teammate {
  const Teammate({
    required this.name,
    required this.kind,
    required this.overall,
    required this.age,
    this.synergy = 0,
  });

  final String name;
  final TeammateKind kind;
  final int overall;
  final int age;

  /// 相方との呼吸 0〜100。一緒に試合を重ねると上がる。
  final int synergy;

  static const List<String> _names = [
    'カイル・ベネット', 'ルカ・ドラガン', '南 廉', 'エミール・ノルド',
    'ジョアン・ピレス', '真木 遼', 'アダム・ケリー', 'ニコ・ヴァルタ',
    'サム・オコエ', '早瀬 樹', 'マテオ・リカルド', 'イヴァン・ペトロフ',
  ];

  factory Teammate.roll(
    Random random, {
    required TeammateKind kind,
    required int clubStrength,
  }) {
    final age = switch (kind) {
      TeammateKind.mentor => 31 + random.nextInt(5),
      TeammateKind.rival => 20 + random.nextInt(8),
      TeammateKind.partner => 22 + random.nextInt(9),
    };
    return Teammate(
      name: _names[random.nextInt(_names.length)],
      kind: kind,
      overall: (clubStrength + random.nextInt(9) - 4).clamp(40, 92),
      age: age,
    );
  }

  Teammate withSynergy(int value) => Teammate(
        name: name,
        kind: kind,
        overall: overall,
        age: age,
        synergy: value.clamp(0, 100),
      );

  /// 相方との呼吸が、味方を活かす手に与える上乗せ。
  double get synergyBonus => kind == TeammateKind.partner ? synergy * 0.0005 : 0;

  /// メンターが練習の効きに与える倍率。若いうちだけ効く。
  double mentorFactor(int age) =>
      kind == TeammateKind.mentor && age <= 23 ? 1.12 : 1.0;

  String get synergyLabel => synergy >= 75
      ? 'ほとんど見なくても分かる'
      : synergy >= 40
          ? '呼吸が合ってきた'
          : 'まだ手探り';

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'overall': overall,
        'age': age,
        'synergy': synergy,
      };

  static Teammate? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Teammate(
      name: json['name'] as String? ?? '同僚',
      kind: TeammateKind.values.any((k) => k.name == json['kind'])
          ? TeammateKind.values.byName(json['kind'] as String)
          : TeammateKind.partner,
      overall: json['overall'] as int? ?? 60,
      age: json['age'] as int? ?? 25,
      synergy: json['synergy'] as int? ?? 0,
    );
  }
}

/// 同期のライバル。
///
/// 同じ年に出てきた選手。別のクラブで別のキャリアを歩み、シーズンごとに
/// 比べられる。追い抜かれると発奮する。比較対象が無いと、自分の成績が
/// 良いのか悪いのか分からない。
class Rival {
  const Rival({
    required this.name,
    required this.clubName,
    required this.overall,
    this.goals = 0,
    this.caps = 0,
  });

  final String name;
  final String clubName;
  final int overall;
  final int goals;
  final int caps;

  static const List<String> _names = [
    'ラファ・ドミンゴ', '御堂 陸', 'エリク・ハンセン', 'ジョシュ・ベイリー',
    'アンドレア・コンティ', '雨宮 蒼', 'パヴェル・ノヴァク', 'テオ・ランベール',
  ];

  factory Rival.roll(Random random, {required int overall, required String clubName}) =>
      Rival(
        name: _names[random.nextInt(_names.length)],
        clubName: clubName,
        overall: (overall + random.nextInt(7) - 2).clamp(40, 92),
      );

  /// 1シーズンぶん進む。伸び方は自分と関係なく決まる。
  Rival advanced(Random random, {required String clubName}) => Rival(
        name: name,
        clubName: clubName,
        overall: (overall + random.nextInt(4) - 1).clamp(40, 94),
        goals: goals + random.nextInt(14),
        caps: caps + random.nextInt(6),
      );

  /// 自分より先を行っているか。
  bool leads(int myOverall) => overall > myOverall + 2;

  Map<String, dynamic> toJson() => {
        'name': name,
        'clubName': clubName,
        'overall': overall,
        'goals': goals,
        'caps': caps,
      };

  static Rival? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : Rival(
          name: json['name'] as String? ?? 'ライバル',
          clubName: json['clubName'] as String? ?? 'クラブ',
          overall: json['overall'] as int? ?? 60,
          goals: json['goals'] as int? ?? 0,
          caps: json['caps'] as int? ?? 0,
        );
}

/// クラブの環境。練習場と医療。
///
/// 保存はしない。クラブの強さと国の格から決まる。同じ努力でも、
/// 環境の良いクラブに居るほうが伸びるし、怪我からも早く戻る。
class Facilities {
  const Facilities({required this.training, required this.medical});

  /// 1〜5。
  final int training;
  final int medical;

  factory Facilities.of(Club club, {required int prestige}) {
    int scale(int base) =>
        (1 + (base - 45) / 12).round().clamp(1, 5);
    return Facilities(
      training: scale(club.strength + prestige * 2),
      medical: scale(club.strength + prestige),
    );
  }

  /// 練習の効きやすさ。
  double get growthFactor => 0.9 + training * 0.05;

  /// 怪我からの戻りの早さ。離脱試合数に掛ける。
  double get recoveryFactor => 1.2 - medical * 0.06;

  String get label => '練習環境 ${'★' * training}  医療 ${'★' * medical}';
}

/// 復帰の進め方。
///
/// 早く戻れば試合に出られるが、無理をすれば長く響く。
/// 怪我を「数試合休むだけ」にしないための選択。
enum RehabPlan {
  cautious('慎重に', '長く休む代わりに、後を引かない'),
  standard('標準', 'クラブの言う通りに進める'),
  rush('強行', '早く戻るが、再発しやすく、身体に残る');

  const RehabPlan(this.label, this.effect);

  final String label;
  final String effect;

  /// 離脱試合数に掛かる倍率。
  double get lengthFactor => switch (this) {
        RehabPlan.cautious => 1.3,
        RehabPlan.standard => 1.0,
        RehabPlan.rush => 0.6,
      };

  /// 復帰直後の怪我のしやすさ。
  double get relapseFactor => switch (this) {
        RehabPlan.cautious => 0.7,
        RehabPlan.standard => 1.0,
        RehabPlan.rush => 1.8,
      };

  /// 復帰時のコンディション。
  int get conditionOnReturn => switch (this) {
        RehabPlan.cautious => 65,
        RehabPlan.standard => 45,
        RehabPlan.rush => 30,
      };

  /// 復帰までにかかる試合数を決める。
  int lengthFor(Injury injury) =>
      max(1, (injury.matchesOut * lengthFactor).round());
}
