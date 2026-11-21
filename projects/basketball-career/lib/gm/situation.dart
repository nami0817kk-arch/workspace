import 'career.dart';
import 'league.dart';
import 'personality.dart';
import 'player.dart';

/// チームの事情(2026-11-21 の作り込み T-2)。事情によって、欲しいものと手放したいものが変わる。
/// 事情はうわさで知る(受信箱。当たることが多いが外れもある。締め切りの前ほど確か)。
enum Situation {
  contend('優勝を狙う', '今すぐ使える選手が欲しい。若手と指名権は安く出す'),
  rebuild('立て直し中', '若手と指名権が欲しい。高い年俸のベテランを早く手放したい'),
  cash('お金に困っている', '年俸を減らしたい。年俸を引き取ってくれるなら、良い選手もつける'),
  hole('ポジションの穴', 'ある位置の選手が急ぎで要る。その位置の選手には上乗せして払う'),
  feud('選手ともめている', '不満を持つ主力を、安くても出したい');

  const Situation(this.label, this.text);
  final String label, text;
}

/// [t] の事情(本当のもの)。(事情, ひとこと)。
List<(Situation, String)> situationsOf(Team t) {
  final out = <(Situation, String)>[];
  if (t.mode == TeamMode.contend) out.add((Situation.contend, '優勝を狙っている'));
  if (t.mode == TeamMode.rebuild) out.add((Situation.rebuild, '立て直しに入っている'));
  if (t.mode == TeamMode.cutCost || t.payroll > taxLine) out.add((Situation.cash, '年俸を減らしたいらしい'));
  final hole = holeOf(t);
  if (hole != null) out.add((Situation.hole, '${hole.label}が足りないらしい'));
  final f = feudOf(t);
  if (f != null) out.add((Situation.feud, '${f.name}ともめているらしい'));
  return out;
}

/// けが人を除いて、1人以下しかいないポジション(穴)。
Pos? holeOf(Team t) {
  for (final pos in Pos.values) {
    if (t.roster.where((p) => p.pos == pos && p.injured == 0).length <= 1) return pos;
  }
  return null;
}

/// 主力(力の上から4人)で、もめている選手(問題児か、気持ちがとても低い)。
Player? feudOf(Team t) {
  final top = [...t.roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
  for (final p in top.take(4)) {
    if (hasTrait(p, Trait.troublemaker) || p.morale < 30) return p;
  }
  return null;
}

/// うわさ1つ。[real] が false なら外れのうわさ。
class Rumor {
  const Rumor(this.team, this.situation, this.text, this.season, this.block, this.real);
  final int team;
  final Situation situation;
  final String text;
  final int season, block;
  final bool real;

  List<Object> toJson() => [team, situation.index, text, season, block, real ? 1 : 0];

  static Rumor? fromJson(Object? x) {
    if (x is! List || x.length != 6) return null;
    return Rumor(x[0] as int, Situation.values[(x[1] as int).clamp(0, Situation.values.length - 1)], x[2] as String, x[3] as int, x[4] as int, x[5] == 1);
  }
}

/// その区切りのうわさを作る(乱数を使わない)。締め切りの前の区切りからは外れない。それより前は5つに1つ外れる。
Rumor? makeRumor(Career c) {
  final n = c.teams.length;
  var t = ((c.seed * 31 + c.season * 7 + c.block * 13) & 0x7fffffff) % n;
  if (t == c.mine) t = (t + 1) % n;
  final team = c.teams[t];
  final real = situationsOf(team);
  final h = ((c.seed * 131 + c.season * 17 + c.block * 29 + t) & 0x7fffffff);
  final sure = c.block >= tradeDeadlineBlock - 1;
  if (!sure && h % 5 == 0) {
    // 外れのうわさ: 本当には無い事情
    final fake = Situation.values.where((s) => !real.any((r) => r.$1 == s) && s != Situation.feud && s != Situation.hole).toList();
    if (fake.isNotEmpty) {
      final s = fake[h ~/ 5 % fake.length];
      return Rumor(t, s, '${team.def.short}は${s.label}らしい', c.season, c.block, false);
    }
  }
  if (real.isEmpty) return null;
  final (s, text) = real[h ~/ 7 % real.length];
  return Rumor(t, s, '${team.def.short}は$text', c.season, c.block, true);
}
