import 'player.dart';

/// 選手の価値観(何を大事にするか)。
enum Value {
  win('勝ちたい', '勝てるチームにいたい。勝つと気持ちが上がり、負けが続くと下がる'),
  money('お金', '年俸を大事にする。値切りに応じにくい'),
  loyal('忠誠', '今のチームを大事にする。再契約で値切りに応じやすい');

  const Value(this.label, this.text);
  final String label;
  final String text;
}

/// 選手の特徴。
enum Trait {
  leader('リーダー', 'チームをまとめる。相性が上がる'),
  grinder('練習の虫', '練習熱心。27歳までは毎オフ伸びやすく、30歳からは落ちにくい。きつい練習でも気持ちが下がらない'),
  troublemaker('問題児', '和を乱す。相性が下がる'),
  clutch('大舞台に強い', '接戦の終盤(4Q残り5分・8点差以内と延長)でシュートが入りやすい'),
  hometown('地元っ子', '今のチームを離れたがらない。1年以上いたチームとの再契約で、求める年俸が1割安い'),
  media('メディア好き', '人気を呼ぶ。主力にいるとシーズンの終わりにチームの人気が上がる'),
  fragile('けがしがち', 'けがが多い(起きやすさ1.6倍)'),
  lateBloomer('遅咲き', '遅れて伸びる。22歳までは伸びが鈍く、24〜28歳でもう一段伸びる'),
  steady('安定感', '試合ごとの調子の波が小さい'),
  streaky('ムラっ気', '試合ごとの調子の波が大きい(当たる日も外す日もある)');

  const Trait(this.label, this.text);
  final String label;
  final String text;
}

/// 選手の性格。選手の id から決める(乱数を使わないので、リーグの続きを変えない)。
class Personality {
  const Personality(this.value, this.traits);
  final Value value;
  final List<Trait> traits;

  String get line => '${value.label}・${traits.map((t) => t.label).join('・')}';
}

Personality personalityOf(Player p) {
  final h = (p.id * 2654435761 + 12345) & 0x7fffffff;
  final value = Value.values[h % Value.values.length];
  // 「遅咲き」は伸び方の型([GrowthType])に移したので、特性には付けない(付く選手は次の特性に)
  var first = Trait.values[(h ~/ 3) % Trait.values.length];
  if (first == Trait.lateBloomer) first = Trait.values[((h ~/ 3) + 1) % Trait.values.length];
  final traits = [first];
  if ((h ~/ 101) % 10 < 4) {
    final second = Trait.values[(h ~/ 37) % Trait.values.length];
    if (second != first && second != Trait.lateBloomer && !_conflict(first, second)) traits.add(second);
  }
  return Personality(value, traits);
}

bool _conflict(Trait a, Trait b) =>
    {a, b}.containsAll([Trait.steady, Trait.streaky]) || {a, b}.containsAll([Trait.leader, Trait.troublemaker]);

/// 性格が見えているか。同じチームに2年以上いると見えてくる。ドラフトの前にスカウトした選手は、はじめから見える。
bool personalityKnown(Player p) => p.tenure >= 2 || p.traitsKnown;

bool hasTrait(Player p, Trait t) => personalityOf(p).traits.contains(t);

/// 試合ごとの調子の幅(シュートが入る見込みの±)。ムラっ気は大きく、安定感は小さい。
double formRange(Player p) => hasTrait(p, Trait.streaky)
    ? 0.025
    : hasTrait(p, Trait.steady)
        ? 0.004
        : 0.01;

/// けがの起きやすさの倍率。
double injuryProne(Player p) => hasTrait(p, Trait.fragile) ? 1.6 : 1.0;

/// 大舞台に強い選手が、接戦の終盤に上乗せするシュートの入る見込み。
const clutchBonus = 0.03;

/// オフに年齢の伸び・衰え(と育成コーチ・練習)のあとで足す、理由のある伸び。乱数を使わない(リーグの続きを変えない)。
/// [p] は年を取ったあと(年齢と年数は+1済み)、[d] はここまでの伸び。[p.stats] は終わったシーズンの成績。
/// - 出場時間: 23歳までで、20試合以上・平均30分以上出た選手は+1。2年目以上で、シーズンの出場が300分未満なら-1(試合に出ないと伸びない)
/// - 練習の虫: 27歳までは伸びた年に+1、30歳からは落ちた年に+1(落ち幅が小さい)
/// - 伸び方の型([GrowthType]。2026-11-21 の作り込み A-3): 早熟・遅咲き・化ける・伸び悩む
List<(String, int)> extraGrowth(Player p, int d) {
  final parts = <(String, int)>[];
  var ovr = p.ovr;
  bool room() => ovr < p.pot;
  final s = p.stats;
  if (p.age <= 23 && d >= 0) {
    if (p.exp >= 2 && s.min < 300) {
      parts.add(('出場時間', -1));
      ovr--;
    }
  }
  if (hasTrait(p, Trait.grinder)) {
    if (p.age <= 27 && d >= 0 && d <= 1 && room()) {
      parts.add((Trait.grinder.label, 1));
      ovr++;
    } else if (p.age >= 30 && d < 0) {
      parts.add((Trait.grinder.label, 1));
      ovr++;
    }
  }
  switch (growthTypeOf(p)) {
    case GrowthType.normal:
      break;
    case GrowthType.early:
      // 早熟: 22歳までは伸びた年にもう1、25歳からは伸びた年に1減る(早く止まる)
      if (p.age <= 22 && d >= 0 && room()) {
        parts.add((GrowthType.early.label, 1));
        ovr++;
      } else if (p.age >= 25 && d > 0) {
        parts.add((GrowthType.early.label, -1));
        ovr--;
      }
    case GrowthType.late:
      // 遅咲き: 22歳までは伸びた年に1減り、24〜28歳は+1(伸びしろも1上がる)
      if (p.age <= 22 && d > 0) {
        parts.add((GrowthType.late.label, -1));
        ovr--;
      } else if (p.age >= 24 && p.age <= 28) {
        parts.add((GrowthType.late.label, 1));
        ovr++;
      }
    case GrowthType.boom:
      // 化ける: 21〜24歳のどこか1年で、いっきに+3(伸びしろも上がる)
      if (p.age == boomAgeOf(p)) {
        parts.add((GrowthType.boom.label, 3));
        ovr += 3;
      }
    case GrowthType.bust:
      // 伸び悩む: 25歳までは伸びた年に1減る(伸びしろも1ずつ下がる)
      if (p.age <= 25 && d > 0) {
        parts.add((GrowthType.bust.label, -1));
        ovr--;
      }
  }
  return parts;
}

/// 伸び方の型(隠れている。2026-11-21 の作り込み A-3)。選手ごとに決まる(乱数を使わない)。
/// ふつう約半分・早熟15%・遅咲き15%・化ける10%・伸び悩む10%。型らしい伸びを見せるか、良い育成コーチ(段階3)がいると分かる。
enum GrowthType {
  normal('ふつう', '年齢どおりに伸びる'),
  early('早熟', '若いうちに早く伸び、25歳ごろから止まりやすい'),
  late('遅咲き', '22歳までは伸びが鈍く、24〜28歳でもう一段伸びる'),
  boom('化ける', '21〜24歳のどこか1年で、いっきに大きく伸びる'),
  bust('伸び悩む', '若いうちの伸びが小さく、伸びしろも下がっていく');

  const GrowthType(this.label, this.text);
  final String label, text;
}

GrowthType growthTypeOf(Player p) {
  final h = ((p.id * 2246822519 + 3266489917) & 0x7fffffff) % 100;
  return h < 50
      ? GrowthType.normal
      : h < 65
          ? GrowthType.early
          : h < 80
              ? GrowthType.late
              : h < 90
                  ? GrowthType.boom
                  : GrowthType.bust;
}

/// 化ける選手が化ける年齢(21〜24)。
int boomAgeOf(Player p) => 21 + ((p.id * 40503) & 0xffff) % 4;
