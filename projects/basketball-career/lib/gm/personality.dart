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
  grinder('練習の虫', '練習熱心。きつい練習でも気持ちが下がらない'),
  troublemaker('問題児', '和を乱す。相性が下がる'),
  clutch('大舞台に強い', 'プレーオフで頼りになる'),
  hometown('地元っ子', '今のチームを離れたがらない'),
  media('メディア好き', '人気を呼ぶ'),
  fragile('けがしがち', 'けがが多い'),
  lateBloomer('遅咲き', '遅れて伸びる'),
  steady('安定感', '調子の波が小さい'),
  streaky('ムラっ気', '調子の波が大きい');

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

/// 性格が見えているか。同じチームに2年以上いると見えてくる。ドラフトの前にスカウトした選手は、はじめから見える。
bool personalityKnown(Player p) => p.tenure >= 2 || p.traitsKnown;

bool hasTrait(Player p, Trait t) => personalityOf(p).traits.contains(t);
