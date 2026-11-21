import 'player.dart';

/// 選手の型と、コートの5人の組み合わせ(2026-11-21 の作り込み B-1、ユーザー「やり込みや発見がなく飽きがきそう」)。
///
/// 能力の合計が高い5人より、型のかみ合う5人のほうが勝てるようにする。組み合わせは隠れていて、
/// 自分のチームでその組み合わせが一緒に出た時間がたまると分かる(図鑑は B-3)。

/// 組み合わせを見る選手の型(7つ)。細かい型([archetypeOf])をまとめたもの。
enum Role {
  playmaker('司令塔', 'パスで味方を生かす'),
  scorer('点取り屋', '外でも中でも点が取れる'),
  slasher('切り込み役', '速さでゴールへ切り込む'),
  shooter('外の名手', '外のシュートが突き抜けている'),
  stopper('守りの職人', '外で相手のエースを守る'),
  stretch('外も打てる大型', 'リバウンドが取れて、外も打てる'),
  anchor('ゴール下の番人', 'ゴール下を守り、リバウンドを取る');

  const Role(this.label, this.text);
  final String label, text;
}

Role roleOf(Player p) => switch (archetypeOf(p)) {
      'プレーメーカー' || 'プレーメイクビッグ' => Role.playmaker,
      'スラッシャー' => Role.slasher,
      'シューター' => Role.shooter,
      '3&D' || 'ディフェンダー' => Role.stopper,
      'ストレッチビッグ' => Role.stretch,
      'リムプロテクター' => Role.anchor,
      _ => Role.scorer, // スコアラー・ツーウェイ・ポストスコアラー
    };

/// 組み合わせ(良いものと悪いもの)。[off] は攻めのとき、[def] は守りのときの強さの足し引き(チームの強さの単位)。
enum Combo {
  pnr('司令塔＋切り込み役', '速攻と切り込みが決まりやすい', 2.0, 0),
  spacing('外の名手2人＋切り込み役', '中が空いて、切り込みが決まる', 2.5, 0),
  wall('ゴール下の番人＋守りの職人2人', '外も中も守れて、失点が減る', 0, 2.5),
  pop('外も打てる大型＋司令塔', '中が広くなり、パスが通る', 2.0, 0),
  fiveOut('外の名手＋外も打てる大型', '5人とも外にいて、守りが広がる', 1.5, 0),
  ballHog('点取り屋3人', 'ボールの取り合いになり、効率が落ちる', -2.5, 0),
  crowded('外を打てない大型2人(外の打ち手なし)', 'ゴール下が詰まって、攻めが窮屈になる', -2.0, 0.5);

  const Combo(this.label, this.text, this.off, this.def);
  final String label, text;
  final double off, def;
  bool get good => off + def > 0;
}

/// [roles](コートの5人の型)で成り立つ組み合わせ。
List<Combo> combosOf(List<Role> roles, List<bool> bigs) {
  int n(Role r) => roles.where((x) => x == r).length;
  final out = <Combo>[];
  if (n(Role.playmaker) >= 1 && n(Role.slasher) >= 1) out.add(Combo.pnr);
  if (n(Role.shooter) >= 2 && n(Role.slasher) >= 1) out.add(Combo.spacing);
  if (n(Role.anchor) >= 1 && n(Role.stopper) >= 2) out.add(Combo.wall);
  if (n(Role.stretch) >= 1 && n(Role.playmaker) >= 1) out.add(Combo.pop);
  if (n(Role.shooter) >= 1 && n(Role.stretch) >= 1) out.add(Combo.fiveOut);
  if (n(Role.scorer) >= 3) out.add(Combo.ballHog);
  // 外を打てない大型(PF・C)が2人以上いて、外の名手も外も打てる大型もいない(外から打つ人がいない)
  var bigNoShot = 0;
  for (var i = 0; i < roles.length; i++) {
    if (bigs[i] && roles[i] != Role.stretch) bigNoShot++;
  }
  if (bigNoShot >= 2 && n(Role.stretch) == 0 && n(Role.shooter) == 0) out.add(Combo.crowded);
  return out;
}

/// コートの [five] の組み合わせ。
List<Combo> combosOfPlayers(List<Player> five) => combosOf([for (final p in five) roleOf(p)], [for (final p in five) p.pos.big]);

/// 組み合わせが分かるまでに、自分のチームで一緒に出る時間(秒)。
const comboDiscoverSecs = 20 * 60;
