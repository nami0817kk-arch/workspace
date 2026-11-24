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

/// 健康で病のかかりやすさに掛ける倍率。七十で前と同じ（1倍）、百で0.4倍、三十で1.8倍、零で2.4倍。
double healthMortFactor(int hp) {
  if (hp >= 70) {
    final f = 1 - (hp - 70) * .02;
    return f < .4 ? .4 : f;
  }
  final f = 1 + (70 - hp) * .02;
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
  g.log(
    rested ? '病を養い、どうにか床を離れた。' : '病を押して務めを続けたが、どうにか持ち直した。',
    'good',
  );
  return true;
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
String illnessNote(Game g) =>
    isSick(g) ? '\n病の床にある。無理をすれば、命に関わる。' : '';
