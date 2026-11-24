import 'childhood.dart';
import 'game.dart';

/// 病（2026-11-24、ユーザー「健康なのに、争い以外で死ぬのはなぜ？」→「両方入れる」）。
///
/// 前は、大人に毎年歳ごとの割合で「病に倒れた」が突然来て、健康の値は30を下回ったときに割合を2倍にするだけだった。
/// 健康が30を下回ることはほとんど無く、4000人生で大人の死の37%が、健康70以上のまま突然の病死だった。
/// - **かかりやすさを健康で変える**（[healthMortFactor]）。健康が高いほど病にかかりにくく、低いほど重い。
/// - **突然死なない**。五十五より前は、まず「病に伏す」（健康がぐっと下がる）。翌年の「この年の心がけ」に
///   「病を養う」が出て、選ぶかどうかで持ち直すか亡くなるかが決まる（[resolveIllness]）。
/// - 五十五からの天寿は前のまま（老いの死は前触れなしに来てよい）。かかりやすさには健康が効く。

/// [healthMortFactor] が1倍になる健康。2026-11-25 に70から下げた（ふだんの暮らしで健康が上下するようにしたので、
/// 前の七十の芯のままだと、並の健康の人まで病にかかりやすくなり、寿命が縮んだ）。
const kHealthPivot = 42;

/// 健康で病のかかりやすさに掛ける倍率。[kHealthPivot] で1倍、高いほど下がって0.4倍まで、低いほど上がって2.4倍まで。
double healthMortFactor(int hp) {
  if (hp >= kHealthPivot) {
    final f = 1 - (hp - kHealthPivot) * .02;
    return f < .4 ? .4 : f;
  }
  final f = 1 + (kHealthPivot - hp) * .02;
  return f > 2.4 ? 2.4 : f;
}

/// 病に伏す割合の、前の病死の割合に対する倍率。病に伏しても多くは持ち直すので、前の病死より多く伏す。
const kIllOnsetScale = 6.0;

/// 病に伏した翌年に亡くなる見込み（病を養ったか）。
const kIllDeathRested = .3;
const kIllDeathWorked = .7;

/// 病に伏した半年の刻み（旗 `sick@<Life.t>`）。伏していなければ null。
/// 年ではなく半年で数える。年で数えると、年の前半に伏した人は同じ年の後半に決まってしまい、
/// 「病を養う」を選ぶ機会がないまま亡くなっていた（測って見つけた）。
int? sickYear(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('sick@')) return int.tryParse(f.substring(5));
  }
  return null;
}

bool isSick(Game g) => sickYear(g) != null;

/// 病に伏す。健康がぐっと下がる（命は取らない）。
void fallIll(Game g) {
  final l = g.l;
  var hp = l.hp - 45;
  if (hp > 35) hp = 35;
  if (hp < 15) hp = 15;
  l.hp = hp;
  g.setFlag('sick@${g.l.t}');
  g.j(-8);
  g.log('重い病に伏した。熱が引かず、床から起き上がれない日が続く。', 'bad');
}

/// 病に伏してから一年たったら（あいだに必ず一度「この年の心がけ」を挟む）、持ち直すか亡くなるかを決める。
/// 決めたら true（亡くなったときも）。
bool resolveIllness(Game g) {
  final t0 = sickYear(g);
  if (t0 == null || g.l.t < t0 + 2) return false;
  final l = g.l;
  final rested = g.hasFlag('sick_rest');
  l.flags.removeWhere((f) => f.startsWith('sick@') || f == 'sick_rest');
  var pd = rested ? kIllDeathRested : kIllDeathWorked;
  if (g.has('herbal')) pd *= .6; // 薬の心得
  if (g.has('hardy')) pd *= .7;
  if (g.has('sickly')) pd *= 1.3;
  pd *= healthMortFactor(l.hp) * .7;
  if (g.rng.chance(pd)) {
    g.die('病に倒れた');
    return true;
  }
  l.hp = l.hp + (rested ? 35 : 15);
  if (l.hp > l.maxhp) l.hp = l.maxhp;
  g.log(rested ? '病を養い、どうにか床を離れた。' : '病を押して務めを続けたが、どうにか持ち直した。', 'good');
  return true;
}

// ======================================================================
// ふだんの体の上下（2026-11-25、ユーザーが決めた「健康の棒を動かす」）
// ======================================================================
//
// 前は、半年ごとに体が4ずつ戻り、大人のほぼ全員が年の初めに健康70以上で、棒が動かなかった
// （4000人生で、年の初めの健康が70を下回るのは大人の年の4%足らず。多くは重い病に伏した年）。
// - **戻り方を歳で細らせる**（[healthRegen]）。若いうちはよく戻り、四十を過ぎると戻りが鈍る。
// - **歳で体の上限が下がる**（[healthCap]）。四十から少しずつ、戻る先が低くなる。休めばそこまでは戻る。
// - **季節の軽い病**（[seasonalAilment]）。風邪や腹の病で寝込み、少し下がる。命は取らない。
// - 心がけの無理（働く・鍛える・務め）は前から体を削っている。休む（体を休める・家族と過ごす）で戻る。
// 健康が下がると重い病に伏しやすくなる（[healthMortFactor]）ので、[healthMortFactor] の芯を
// [kHealthPivot] に下げ、寿命と遊ぶ時間が前と近くなるよう測って合わせた（CLAUDE.md の「健康の棒を動かす」）。

/// 半年ごとに、ひとりでに戻る体（歳で細る）。
int healthRegen(int age) => age < 30
    ? 3
    : age < 40
    ? 2
    : age < 55
    ? 1
    : 0;

/// 歳で下がる体の上限（ひとりでに戻る先と、年の終わりに上限まで下がる先）。四十から一年に1ずつ、半分まで。
int healthCap(int maxhp, int age) {
  if (age < 40) return maxhp;
  final c = maxhp - (age - 40);
  final floor = maxhp ~/ 2;
  return c < floor ? floor : c;
}

/// 季節の軽い病にかかる見込み（一年に一度引く）。
double ailmentChance(Game g) {
  var p = .2 + (g.age > 30 ? (g.age - 30) * .004 : 0);
  if (g.has('sickly')) p *= 1.5;
  if (g.has('hardy')) p *= .6;
  return p;
}

const _ailments = [
  '風邪をこじらせ、半月ほど寝込んだ。',
  '腹を下し、しばらく粥しか喉を通らなかった。',
  '季節の変わり目に熱を出し、床に就いた。',
  '咳が長引き、夜も眠れない日が続いた。',
  '暑気あたりで寝込み、食が細った。',
];

/// 季節の軽い病（年の初めの半年に一度引く。寝込んで少し下がる。命は取らない）。
/// 重い病に伏しているあいだは引かない。
void seasonalAilment(Game g) {
  // 弱りきった体（三十まで）には引かない（飢えや深手で弱った人を、軽い病で死なせない）。
  if (isSick(g) || g.l.hp <= 30 || !g.rng.chance(ailmentChance(g))) return;
  final l = g.l;
  final d = g.rng.range(10, 22);
  l.hp = l.hp - d < 5 ? 5 : l.hp - d;
  g.j(-2);
  g.log(_ailments[g.rng.range(0, _ailments.length - 1)]);
}

/// 半年ぶんの体の戻りと、歳による衰え（`Game._halfYearUpkeep` が呼ぶ）。
/// [hungry]（身分がなく銭の尽きた半年）は、前と同じく4戻す（飢え死にの出方を、この直しで変えない）。
void healthUpkeep(Game g, {bool hungry = false}) {
  final l = g.l;
  final cap = healthCap(l.maxhp, g.age);
  final up = hungry ? 4 : healthRegen(g.age);
  if (l.hp < cap) l.hp = l.hp + up > cap ? cap : l.hp + up;
  // 上限より上に残っている分は、ゆっくり下がる（休んで上限まで戻した体も、歳には勝てない）。
  if (l.hp > cap) l.hp = l.hp - 2 < cap ? cap : l.hp - 2;
}

/// 病に伏しているあいだの「この年の心がけ」。いつもの重点の先頭に出す。
List<FocusDef> illnessFocusOptions(Game g) => [
  if (isSick(g))
    FocusDef('yojo', '病を養う', '体は持ち直しやすい。この年の務めは進まない', (g) {
      g.setFlag('sick_rest');
      g.j(2);
    }),
];

/// 病に伏しているときの、年の初めの一言。
String illnessNote(Game g) => isSick(g) ? '\n病の床にある。無理をすれば、命に関わる。' : '';
