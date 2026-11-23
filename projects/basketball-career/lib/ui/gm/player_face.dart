import 'package:flutter/material.dart';

import '../../gm/player.dart';
import 'common.dart' show colorOf;

/// 顔の型と、その型で選べる目の数・肌の色。絵は `assets/faces/` (charmaker の export_app.py で書き出した 192px の層)。
/// 体(顔・目・ひげ・肌)の上に髪を重ねる。本人の写真ではなく、部品の組み合わせ(実在の選手に似せない)。
class FaceType {
  const FaceType(this.name, this.weight, this.tones, {this.eyes = 1, this.black = false, this.lightBeard = false});
  final String name;

  /// リーグに出てくる多さ。
  final int weight;

  /// 選べる肌の色(0 とても明るい〜5 とても濃い)。
  final List<int> tones;

  /// 目の部品の数(0 は素体のまま)。
  final int eyes;

  /// 髪型の出やすさを黒人系の並びにする。
  final bool black;

  /// 童顔は濃いひげを付けない(無精ひげまで)。
  final bool lightBeard;
}

const faceTypes = [
  FaceType('base', 3, [2, 3, 4, 5], eyes: 5, black: true),
  FaceType('round', 2, [3, 4, 5], black: true),
  FaceType('longface', 2, [3, 4, 5], black: true),
  FaceType('westafrica', 2, [3, 4, 5], black: true),
  FaceType('veteran', 2, [3, 4, 5], black: true),
  FaceType('babyface', 2, [3, 4, 5], black: true, lightBeard: true),
  FaceType('asian', 1, [0, 1, 2]),
  FaceType('latino', 1, [1, 2, 3]),
  FaceType('southeu', 1, [1, 2, 3]),
  FaceType('easteu', 1, [0]),
  FaceType('nordic', 1, [0]),
  FaceType('mideast', 1, [1, 2, 3]),
  FaceType('southasia', 1, [2, 3, 4]),
];

/// 髪の部品の数(0 短髪・1 アフロ・2 ドレッド・3 コーンロウ・4 ハイトップ・5 ツイスト・6 茶の短髪・7 金の波髪・8 刈り上げ)。
const faceHairCount = 9;

/// ひげの部品の数(0 なし・1 無精ひげ・2 あごひげ・3 ヤギひげ)。
const faceBeardCount = 4;

// 髪型の出やすさ(-1 は坊主=髪なし、続けて 0〜8)。
const _hairWeightsBlack = [2, 3, 2, 2, 2, 2, 2, 1, 0, 2];
const _hairWeightsOther = [1, 3, 0, 0, 0, 1, 0, 3, 2, 3];

/// 顔の決まり。選手の id から決まり、年を取ると白髪とひげが増える(一度付いたら消えない)。
class FaceSpec {
  const FaceSpec({required this.type, required this.eyes, required this.beard, required this.tone, required this.hair, required this.gray});

  final FaceType type;
  final int eyes;
  final int beard;
  final int tone;

  /// -1 は坊主(髪の層なし)。
  final int hair;
  final bool gray;

  String get bodyAsset => 'assets/faces/body/${type.name}_e${eyes}_b${beard}_t$tone.webp';
  String? get hairAsset => hair < 0 ? null : 'assets/faces/hair/${type.name}_h$hair${gray ? 'g' : ''}.webp';

  @override
  bool operator ==(Object other) => other is FaceSpec && other.bodyAsset == bodyAsset && other.hairAsset == hairAsset;
  @override
  int get hashCode => Object.hash(bodyAsset, hairAsset);
}

int _h(Player p, int salt) {
  final x = (p.id * 2654435761 + salt * 40503 + 977) & 0x7fffffff;
  return (x ^ (x >> 13)) & 0x7fffffff;
}

int _pick(List<int> weights, int r) {
  final total = weights.fold(0, (a, b) => a + b);
  var x = r % total;
  for (var i = 0; i < weights.length; i++) {
    if (x < weights[i]) return i;
    x -= weights[i];
  }
  return weights.length - 1;
}

/// 日本人の名前か(names.dart の日本人の名前は「姓 名」、それ以外は「名・姓」)。
bool isJapaneseName(String name) => !name.contains('・') && name.contains(' ');

FaceSpec faceOf(Player p) {
  // 日本人の名前(「姓 名」の形で「・」が無い)には、アジア系の顔を付ける
  final type = isJapaneseName(p.name) ? faceTypes.firstWhere((t) => t.name == 'asian') : faceTypes[_pick([for (final t in faceTypes) t.weight], _h(p, 1))];
  final hair = _pick(type.black ? _hairWeightsBlack : _hairWeightsOther, _h(p, 2)) - 1;
  // 白髪は33歳から。年ごとに見込みが上がり、同じ選手は一度白髪になったら戻らない
  final gray = hair >= 0 && _h(p, 3) % 100 < (p.age - 32) * 12;
  // ひげ: 22歳未満はなし。年とともに増える
  var beard = 0;
  if (p.age >= 22) {
    final chance = 18 + (p.age - 22) * 3; // 22歳で18%、32歳で48%
    if (_h(p, 4) % 100 < chance) beard = type.lightBeard ? 1 : 1 + (_h(p, 5) % 3);
  }
  return FaceSpec(
    type: type,
    eyes: _h(p, 6) % type.eyes,
    beard: beard,
    tone: type.tones[_h(p, 7) % type.tones.length],
    hair: hair,
    gray: gray,
  );
}

/// 選手の顔(角の丸い枠にチームの色の縁)。
class PlayerFace extends StatelessWidget {
  const PlayerFace({super.key, required this.p, required this.team, this.size = 40});
  final Player p;
  final int team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = colorOf(team);
    final f = faceOf(p);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 192);
    Widget layer(String path) => Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: px,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.jersey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.jersey.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        layer(f.bodyAsset),
        if (f.hairAsset != null) layer(f.hairAsset!),
      ]),
    );
  }
}
