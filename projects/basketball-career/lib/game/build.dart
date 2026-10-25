import 'match.dart';
import 'player.dart';

/// ビルド(選手のタイプ)。バスケットボールのゲームでよくある「スラッシャー」「シャープシューター」のような型。
/// 目指す型は始めるとき(と育成中)にプレーヤーが選べる(`Player.style`)。選ばなければ、能力のつき方から自動で判定する。
/// 選んだ型は、その型に効く能力の伸びを後押しする(`styleGrowthMultiplier`)。
/// 型に合うプレーが少しだけ強くなる(ティアが上がるほど大きい)。固有名詞は使わず、一般的な呼び名だけ。
enum Build {
  slasher('スラッシャー', '切り込んで決める。ドライブとファウルをもらうのが得意。'),
  sharpshooter('シャープシューター', '外から決める。3Pが得意。'),
  playmaker('プレイメーカー', '試合を作る。パスが得意で、味方を動かす。'),
  lockdown('ロックダウンディフェンダー', '相手のエースを抑える。ディフェンスとスティールが得意。'),
  rimProtector('リムプロテクター', 'ゴール下の番人。ディフェンスとブロックが得意。'),
  stretchBig('ストレッチビッグ', '大きいのに外から決める。3Pとドライブが得意。'),
  allRound('オールラウンダー', '穴がない。どのプレーも少しずつ強い。');

  const Build(this.label, this.description);
  final String label;
  final String description;

  /// 名前から読み戻す(知らない名前・null は null=おまかせ)。
  static Build? parse(String? s) {
    for (final b in values) {
      if (b.name == s) return b;
    }
    return null;
  }

  /// 名乗るのに要る身長(cm)。足りないと、選んでいても自動の判定になる。
  double get minHeight => switch (this) {
        Build.stretchBig => 196,
        Build.rimProtector => 190,
        _ => 0,
      };
}

/// ティア(型の完成度)。型に効く能力の平均で決まる。
const tierLabels = ['ブロンズ', 'シルバー', 'ゴールド', 'レジェンド'];

class BuildInfo {
  const BuildInfo(this.build, this.tier);
  final Build build;

  /// 0=ブロンズ 1=シルバー 2=ゴールド 3=レジェンド。
  final int tier;

  String get tierLabel => tierLabels[tier];
  String get label => '${build.label}($tierLabel)';

  /// ティアごとの大きさ(1〜4)。
  int get level => tier + 1;
}

/// 型ごとの、効く能力。
Map<Build, List<Ability>> _keys = {
  Build.slasher: [Ability.inside, Ability.dribble, Ability.speed, Ability.physical],
  Build.sharpshooter: [Ability.threePoint, Ability.midRange, Ability.freeThrow],
  Build.playmaker: [Ability.pass, Ability.dribble, Ability.speed],
  Build.lockdown: [Ability.defense, Ability.speed, Ability.stamina],
  Build.rimProtector: [Ability.defense, Ability.rebound, Ability.inside],
  Build.stretchBig: [Ability.threePoint, Ability.rebound, Ability.midRange],
};

double _score(Player p, Build b) {
  final keys = _keys[b]!;
  var sum = keys.fold(0.0, (s, a) => s + p.effective(a));
  var n = keys.length;
  // 大きい型は身長も入る。
  if (b == Build.rimProtector) {
    sum += p.heightRating;
    n++;
  }
  return sum / n;
}

/// 型に効く能力(おまかせ・オールラウンダーは空)。おすすめの重点や伸びの後押しに使う。
List<Ability> styleKeys(Build b) => _keys[b] ?? const [];

int _tierOf(double score) =>
    score < 55 ? 0 : (score < 70 ? 1 : (score < 85 ? 2 : 3));

/// 選んだ型での、能力ごとの伸びの倍率。型に効く能力は伸びやすく、それ以外は少し伸びにくい(伸びる年だけ)。
/// オールラウンダーは全体が少しだけ伸びやすい。おまかせ(null)は 1.0。
double styleGrowthMultiplier(Build? style, Ability a) {
  if (style == null) return 1.0;
  if (style == Build.allRound) return 1.03;
  return styleKeys(style).contains(a) ? 1.15 : 0.97;
}

/// 能力から型を判定する。まだ型と呼べるほどの力がなければ null。
/// ストレッチビッグは196cm以上、リムプロテクターは190cm以上でだけ名乗れる。
/// 目指す型を選んでいれば(身長の条件を満たす限り)その型で、ティアは今の力で決まる(ブロンズ以上)。
BuildInfo? buildOf(Player p) {
  final chosen = p.style;
  if (chosen != null && p.heightCm >= chosen.minHeight) {
    if (chosen == Build.allRound) {
      final mean = Ability.values.fold(0.0, (s, a) => s + p.effective(a)) /
          Ability.values.length;
      return BuildInfo(chosen, _tierOf(mean));
    }
    return BuildInfo(chosen, _tierOf(_score(p, chosen)));
  }
  Build? best;
  var bestScore = 0.0;
  for (final b in _keys.keys) {
    if (b == Build.stretchBig && p.heightCm < 196) continue;
    if (b == Build.rimProtector && p.heightCm < 190) continue;
    final s = _score(p, b);
    if (s > bestScore) {
      bestScore = s;
      best = b;
    }
  }
  if (best == null) return null;
  // 全体の平均と大差がなければ、オールラウンダー。
  final mean = Ability.values.fold(0.0, (s, a) => s + p.effective(a)) /
      Ability.values.length;
  final allRound = bestScore - mean < 5;
  final score = allRound ? mean : bestScore;
  if (score < 40) return null;
  final tier = _tierOf(score);
  return BuildInfo(allRound ? Build.allRound : best, tier);
}

/// 勝負どころのプレーごとの加算(0〜1の確率)。型に合うプレーだけ。1ティアあたり1%。
double buildClutchBonus(Player p, Clutch c) {
  final i = buildOf(p);
  if (i == null) return 0;
  final per = 0.01 * i.level;
  return switch ((i.build, c)) {
    (Build.slasher, Clutch.drive) => per,
    (Build.slasher, Clutch.drawFoul) => per * 0.75,
    (Build.sharpshooter, Clutch.threePoint) => per,
    (Build.playmaker, Clutch.pass) => per,
    (Build.lockdown, Clutch.defend) => per,
    (Build.rimProtector, Clutch.defend) => per * 0.75,
    (Build.stretchBig, Clutch.threePoint) => per * 0.75,
    (Build.stretchBig, Clutch.drive) => per * 0.5,
    (Build.allRound, _) => per * 0.4,
    _ => 0.0,
  };
}

/// 1試合のスティール・ブロックの倍率(型による)。
double buildStealMultiplier(Player p) {
  final i = buildOf(p);
  return i != null && i.build == Build.lockdown ? 1 + 0.05 * i.level : 1.0;
}

double buildBlockMultiplier(Player p) {
  final i = buildOf(p);
  return i != null && i.build == Build.rimProtector ? 1 + 0.07 * i.level : 1.0;
}

/// 大会の味方の強さへの加算(プレイメーカーは味方を動かす)。
double buildTeamBonus(Player p) {
  final i = buildOf(p);
  return i != null && i.build == Build.playmaker ? 0.2 * i.level : 0.0;
}
