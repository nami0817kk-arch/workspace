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
  hometown('地元っ子', '今のチームを離れたがらない。再契約で求める年俸が1割安い'),
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
  final first = Trait.values[(h ~/ 3) % Trait.values.length];
  final traits = [first];
  if ((h ~/ 101) % 10 < 4) {
    final second = Trait.values[(h ~/ 37) % Trait.values.length];
    if (second != first && !_conflict(first, second)) traits.add(second);
  }
  return Personality(value, traits);
}

bool _conflict(Trait a, Trait b) =>
    {a, b}.containsAll([Trait.steady, Trait.streaky]) || {a, b}.containsAll([Trait.leader, Trait.troublemaker]);

/// 性格が見えているか。同じチームに2年以上いると見えてくる(新しい選手は面接・スカウトまで見えない)。
bool personalityKnown(Player p) => p.tenure >= 2;

bool hasTrait(Player p, Trait t) => personalityOf(p).traits.contains(t);

/// 試合ごとの調子の幅(シュートが入る見込みの±)。ムラっ気は大きく、安定感は小さい。
double formRange(Player p) => hasTrait(p, Trait.streaky)
    ? 0.045
    : hasTrait(p, Trait.steady)
        ? 0.008
        : 0.02;

/// けがの起きやすさの倍率。
double injuryProne(Player p) => hasTrait(p, Trait.fragile) ? 1.6 : 1.0;

/// 大舞台に強い選手が、接戦の終盤に上乗せするシュートの入る見込み。
const clutchBonus = 0.03;

/// オフに年齢の伸び・衰え(と育成コーチ・練習)のあとで足す、理由のある伸び。乱数を使わない(リーグの続きを変えない)。
/// [p] は年を取ったあと(年齢と年数は+1済み)、[d] はここまでの伸び。[p.stats] は終わったシーズンの成績。
/// - 出場時間: 25歳までで、20試合以上・平均28分以上出た選手は+1。2年目以上で、シーズンの出場が300分未満なら-1(試合に出ないと伸びない)
/// - 練習の虫: 27歳までは伸びた年に+1、30歳からは落ちた年に+1(落ち幅が小さい)
/// - 遅咲き: 22歳までは伸びた年に-1、24〜28歳は+1(伸びしろも1上がる)
List<(String, int)> extraGrowth(Player p, int d) {
  final parts = <(String, int)>[];
  var ovr = p.ovr;
  bool room() => ovr < p.pot;
  final s = p.stats;
  if (p.age <= 25 && d >= 0) {
    if (s.gp >= 20 && s.mpg >= 28 && room()) {
      parts.add(('出場時間', 1));
      ovr++;
    } else if (p.exp >= 2 && s.min < 300) {
      parts.add(('出場時間', -1));
      ovr--;
    }
  }
  if (hasTrait(p, Trait.grinder)) {
    if (p.age <= 27 && d >= 0 && room()) {
      parts.add((Trait.grinder.label, 1));
      ovr++;
    } else if (p.age >= 30 && d < 0) {
      parts.add((Trait.grinder.label, 1));
      ovr++;
    }
  }
  if (hasTrait(p, Trait.lateBloomer)) {
    if (p.age <= 22 && d > 0) {
      parts.add((Trait.lateBloomer.label, -1));
      ovr--;
    } else if (p.age >= 24 && p.age <= 28) {
      parts.add((Trait.lateBloomer.label, 1));
      ovr++;
    }
  }
  return parts;
}
