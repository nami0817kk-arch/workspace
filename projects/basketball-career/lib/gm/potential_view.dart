import 'career.dart';
import 'league.dart';
import 'personality.dart';
import 'wishes.dart';
import 'player.dart';

/// 伸びしろの見立て(2026-11-21 の作り込み A-1、ユーザー「やり込みや発見がなく飽きがきそう」)。
///
/// 前は伸びしろの等級(S/A/B/C)が本当の値からそのまま出ていて、見抜く楽しみが無かった。
/// いまは、どれだけその選手を知っているか([knowledgeOf]、0〜100)で、等級を「C〜A」のような幅で見せる。
/// - 自分のチームの選手: 在籍の年数・今季の出場時間・育成コーチの段階・前に対戦した数で知る
/// - ほかのチームの選手: 対戦した試合の数(試合で見た分だけ)とスカウトの段階。幅は広いまま
/// - 28歳以上は伸びしろが無いので、いつも正確(「なし」)
/// 幅は、ふつうは本当の値を含み、知るほど内側へ縮む(前に見せた幅からはみ出さない)。
/// ただし5人に1人くらいは見立てが外れる(A-2。外れても1段)。スカウトが良いほど外れにくく、正確に分かるまで知ると本当の値に落ち着く。

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

  /// 「C〜A」か「A」。伸びしろが無いと分かっていれば「-」。幅の下の端が無しなら「なし〜A」(「-〜A」は読めなかった)。
  String get text => exact ? loText : '${lo == 0 ? 'なし' : loText}〜$hiText';

  /// 表の狭い列用(「無〜A」)。
  String get shortText => exact ? loText : '${lo == 0 ? '無' : loText}〜$hiText';

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
  PotentialView potentialOf(Player p) => potentialViewOf(p, knowledgeOf(p), miss: potentialMissOf(p));

  /// [p] の見立てが外れているか(1 は高く見ている、-1 は低く見ている、0 は外れていない)。
  /// 選手ごとに決まる(乱数は使わない)。外れる割合は、スカウトの段階で 20%・15%・10%。
  int potentialMissOf(Player p) {
    if (p.age >= 28) return 0;
    final rate = const [20, 15, 10][(me.staffLevel(Staff.scout) - 1).clamp(0, 2)];
    final h = (p.id * 1103515245 + 12345) & 0x7fffffff;
    if (h % 100 >= rate) return 0;
    final g = potentialGrades.indexOf(p.grade).clamp(0, 4);
    // 端の等級は、外れようが無い向きには外さない
    final up = (h ~/ 100).isEven;
    if (up && g < 4) return 1;
    if (!up && g > 0) return -1;
    return g < 4 ? 1 : -1;
  }
}

/// 知っている度合い [k] のときの、[p] の伸びしろの見立て。[miss] が 0 でなければ、その向きに1段外す(正確に分かるときは外さない)。
PotentialView potentialViewOf(Player p, int k, {int miss = 0}) {
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
  if (span > 0 && miss > 0 && g < 4) {
    // 高く見ている: 本当の等級のすぐ上から
    final l = g + 1, h = (g + 1 + span).clamp(0, 4);
    final q = (block + 1) * 5;
    return PotentialView(l, h, q.clamp(0, 95), (q + (span + 1) * 5).clamp(0, 99), k);
  }
  if (span > 0 && miss < 0 && g > 0) {
    // 低く見ている: 本当の等級のすぐ下まで
    final h = g - 1, l = (g - 1 - span).clamp(0, 4);
    final q = block * 5 - 1;
    return PotentialView(l, h, (q - (span + 1) * 5 + 1).clamp(0, 95), q.clamp(0, 99), k);
  }
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

/// 選手の詳しい画面の「伸び方」の1行(A-3)。
String growthLine(Career car, Player p) {
  if (!car.growthTypeKnown(p)) return 'まだ分からない(型らしい伸びを見せるか、段階3の育成コーチがいると分かる)';
  final g = growthTypeOf(p);
  return '${g.label}(${g.text})';
}

/// 見える特性(初めから分かる)。ほかの特性は隠れていて、在籍しばらく・特性らしい出来事・下調べとワークアウトで分かる(A-4)。
const visibleTraits = {Trait.hometown, Trait.media, Trait.leader};

/// 隠れた特性が在籍で分かるまでの区切りの数(1〜2。選手ごとに決まる)。
int traitRevealBlocks(Player p) => 1 + ((p.id * 69069 + 1) & 0xffff) % 2;

/// [c] から見た [p] の性格の見え方。(分かっている特性, 価値観が分かっているか, まだ分からない特性があるかもしれないか)。
(List<Trait>, bool, bool) traitsShown(Career? c, Player p) {
  final pers = personalityOf(p);
  if (c == null) return (pers.traits, true, false);
  final mine = c.me.roster.contains(p) || c.me.twoWay.contains(p);
  // 在籍しばらく(区切り1〜2)、前からいる選手(1年以上)、下調べ・ワークアウトをした選手は、全部分かる
  final settled = p.traitsKnown || (mine && ((c.blocksWithMe[p.id] ?? 0) >= traitRevealBlocks(p) || p.tenure >= 1));
  final shown = [
    for (final t in pers.traits)
      if (visibleTraits.contains(t) || settled || c.traitSeen.contains(p.id * 32 + t.index)) t,
  ];
  return (shown, settled, !settled);
}

/// 性格の1行(「性格: 勝ちたい・リーダー」。まだ分からないところは書き添える)。
String traitsLine(Career? c, Player p) {
  final (shown, valueKnown, more) = traitsShown(c, p);
  final pers = personalityOf(p);
  final parts = [
    if (valueKnown) pers.value.label,
    ...shown.map((t) => t.label),
  ];
  final head = parts.isEmpty ? '性格: まだ見えていない' : '性格: ${parts.join('・')}';
  return more ? '$head(ほかはまだ分からない。チームにしばらくいると見えてくる)' : head;
}

/// 性格の説明(分かっている所だけ)。
String traitsText(Career? c, Player p) {
  final (shown, valueKnown, _) = traitsShown(c, p);
  final pers = personalityOf(p);
  return [if (valueKnown) pers.value.text, ...shown.map((t) => t.text)].map((x) => '$x。').join();
}

/// 選手の詳しい画面の「望み」の1行(C-2)。
String wishLine(Career car, Player p) {
  if (!car.wishIsKnown(p)) return '？(面談や契約の話し合い、しばらくチームにいると分かる)';
  final w = wishOf(p);
  final mine = car.me.roster.contains(p);
  return '${w.label}(${w.text})${mine ? (wishMet(car, p, car.me) ? '・満たされている' : '・満たされていない') : ''}';
}
