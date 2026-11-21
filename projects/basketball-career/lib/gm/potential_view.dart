import 'career.dart';
import 'league.dart';
import 'player.dart';

/// 伸びしろの見立て(2026-11-21 の作り込み A-1、ユーザー「やり込みや発見がなく飽きがきそう」)。
///
/// 前は伸びしろの等級(S/A/B/C)が本当の値からそのまま出ていて、見抜く楽しみが無かった。
/// いまは、どれだけその選手を知っているか([knowledgeOf]、0〜100)で、等級を「C〜A」のような幅で見せる。
/// - 自分のチームの選手: 在籍の年数・今季の出場時間・育成コーチの段階・前に対戦した数で知る
/// - ほかのチームの選手: 対戦した試合の数(試合で見た分だけ)とスカウトの段階。幅は広いまま
/// - 28歳以上は伸びしろが無いので、いつも正確(「なし」)
/// 幅は、本当の値を必ず含む(外れることがあるのは A-2 で入れる)。知るほど幅は内側へ縮む(前に見せた幅からはみ出さない)。

/// 等級の並び(0 は伸びしろなし)。
const potentialGrades = ['-', 'C', 'B', 'A', 'S'];

/// 見立て。[lo]〜[hi] は等級の番号([potentialGrades])、[potLo]〜[potHi] は伸びきったときの力(見せる値)。
class PotentialView {
  const PotentialView(this.lo, this.hi, this.potLo, this.potHi, this.knowledge);
  final int lo, hi, potLo, potHi;

  /// どれだけ知っているか(0〜100)。
  final int knowledge;
  bool get exact => lo == hi;
  String get loText => potentialGrades[lo];
  String get hiText => potentialGrades[hi];

  /// 「C〜A」か「A」。伸びしろが無いと分かっていれば「-」。
  String get text => exact ? loText : '$loText〜$hiText';

  /// 一覧に札を出すか(伸びしろが無いと分かっている選手には出さない)。
  bool get worthShowing => hi > 0;

  /// 上の端が A 以上(金の札にする)。
  bool get bright => hi >= 3;
}

/// 画面で見ているキャリア(伸びしろの見立てに使う)。無ければ、前と同じく正確に見せる。
Career? viewingCareer;

/// 知っている度合いから、等級の幅(段階の数、0 は正確)。
int potentialSpan(int knowledge) => knowledge >= 90
    ? 0
    : knowledge >= 60
        ? 1
        : knowledge >= 30
            ? 2
            : 3;

extension PotentialKnowledge on Career {
  /// [p] をどれだけ知っているか(0〜100)。乱数は使わない。
  int knowledgeOf(Player p) {
    if (p.age >= 28) return 100;
    final seen = seenGames[p.id] ?? 0;
    final mineNow = me.roster.contains(p) || me.twoWay.contains(p);
    if (mineNow) {
      // 育成コーチの段階(1〜3)で、0・5・10
      final dev = (me.staffLevel(Staff.development) - 1) * 5;
      return (30 + p.tenure * 30 + (p.stats.min ~/ 40).clamp(0, 30) + dev + seen * 2).clamp(0, 100);
    }
    final scout = (me.staffLevel(Staff.scout) - 1) * 5;
    return (seen * 5 + scout).clamp(0, 55);
  }

  /// [p] の伸びしろの見立て。
  PotentialView potentialOf(Player p) => potentialViewOf(p, knowledgeOf(p));
}

/// 知っている度合い [k] のときの、[p] の伸びしろの見立て。
PotentialView potentialViewOf(Player p, int k) {
  final g = potentialGrades.indexOf(p.grade).clamp(0, 4);
  final v = shown(p.pot);
  if (p.age >= 28) return PotentialView(g, g, v ~/ 5 * 5, (v ~/ 5 * 5 + 5).clamp(0, 99), 100);
  final span = potentialSpan(k);
  // いちばん広い幅(3段)の中で、本当の値がどこにあるか(選手ごとに決まる)。狭い幅はその内側に取る
  final r = ((p.id * 2654435761 + 40503) & 0x7fffffff) % 4;
  var lo = g - (r * span) ~/ 3;
  var hi = lo + span;
  if (lo < 0) {
    hi -= lo;
    lo = 0;
  }
  if (hi > 4) {
    lo = (lo - (hi - 4)).clamp(0, 4);
    hi = 4;
  }
  // 伸びきったときの力: 5刻みの (span+1) 区間
  final block = v ~/ 5;
  final pLo = ((block - (r * span) ~/ 3) * 5).clamp(0, 95);
  final pHi = (pLo + (span + 1) * 5).clamp(0, 99);
  return PotentialView(lo, hi, pLo, pHi, k);
}

/// 画面で見ているキャリアでの、[p] の伸びしろの見立て(キャリアが無ければ正確に)。
PotentialView potentialShown(Player p) {
  final c = viewingCareer;
  return c == null ? potentialViewOf(p, 100) : c.potentialOf(p);
}

/// 選手の詳しい画面の「伸びしろ」の1行。
String potentialLine(Career car, Player p) {
  if (p.age >= 28) return p.age >= 30 ? 'なし(これから落ちていく)' : 'なし';
  const desc = ['なし', 'あまり伸びない', '少し伸びる', 'まだ伸びる', '大きく伸びる見込み'];
  final pv = car.potentialOf(p);
  final mine = car.me.roster.contains(p) || car.me.twoWay.contains(p);
  if (pv.exact) return '${pv.lo == 0 ? 'なし' : pv.text}(${desc[pv.lo]}。見立ては確か)';
  final how = mine ? '在籍の年数・出場・育成コーチで絞れる' : '試合で対戦するほど絞れる';
  return '${pv.text}(${desc[pv.lo]}〜${desc[pv.hi]}。見立ての確かさ${pv.knowledge}%・$how)';
}
