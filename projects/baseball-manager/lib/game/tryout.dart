import 'life.dart';
import 'path.dart';
import 'player.dart';

/// トライアウト(戦力外通告のあとの、他球団への売り込み)。実際の野球にもある制度。
///
/// 戦力外になった年に、**一生に一度だけ**「トライアウトを受ける」か「引退する」かを選べる。
/// 受けて契約を勝ち取れば、別の球団でもう一度プレーできる(戦力外の連続年数は0に戻る)。
/// 契約が取れなければ、そのまま引退。
const tryoutEventId = 'tryout';

/// トライアウトを選べる最後の年齢(これより上は、そのまま引退)。
const tryoutMaxAge = 39;

/// 戦力外の年に、トライアウトを選べるか(一生に一度・年齢の上限あり)。
bool canTryout({required int age, required bool used}) =>
    !used && age <= tryoutMaxAge;

/// 契約を勝ち取れる確率(0.10〜0.75)。総合評価が基準(35)に近いほど・若いほど高い。
double tryoutChance(Player p) {
  final base = 0.30 + (overall(p) - 30) * 0.02 + (p.age <= 30 ? 0.10 : 0.0);
  final old = p.age >= 36 ? 0.20 : 0.0;
  return (base - old).clamp(0.10, 0.75);
}

final GameEvent tryoutEvent = GameEvent(
  tryoutEventId,
  '戦力外通告を受けた。トライアウトで他球団に売り込むか、ここで現役を退くか。',
  [
    EventChoice('トライアウトを受ける', (p, c, f) => (player: p, condition: c)),
    EventChoice('現役を引退する', (p, c, f) => (player: p, condition: c)),
  ],
);
