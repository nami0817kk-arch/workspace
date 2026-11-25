import 'package:flutter/material.dart';

import '../models/league_theme.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import 'position_colors.dart';

/// 顔の型と、その型で選べる目・肌の色・髪。絵は `assets/faces/`
/// (手描き風の生成画像を 192px の層に書き出したもの)。体(顔・目・ひげ・肌、
/// 髪なし)の上に、透明な地の髪を重ねる。本人の写真ではなく部品の組み合わせ
/// (実在の選手に似せない)。
class FaceType {
  const FaceType(
    this.name,
    this.tones, {
    this.eyes = 1,
    this.hairs = const [0, 1, 2, 3, 4, 5, 6, 7, 8],
    required this.hairWeights,
    this.lightBeard = false,
  });

  final String name;

  /// 選べる肌の色(0 とても明るい〜5 とても濃い)。絵がある色だけ。
  final List<int> tones;

  /// 目の部品の数。
  final int eyes;

  /// 絵がある髪の番号(型によって抜けがある)。
  final List<int> hairs;

  /// 髪型の出やすさ(先頭が -1 の坊主、続けて髪 0〜8)。
  final List<int> hairWeights;

  /// 童顔は濃いひげを付けない(無精ひげまで)。
  final bool lightBeard;
}

// 髪型の出やすさ(-1 坊主、続けて 0〜8)。
//
// バスケから持ってきた13型の髪: 0 短髪・1 アフロ・2 ドレッド・3 コーンロウ・
// 4 ハイトップ・5 ツイスト・6 茶の短髪・7 金の波髪・8 刈り上げ。
const _hairBlack = [2, 3, 2, 2, 2, 2, 2, 1, 0, 2];
const _hairOther = [1, 3, 0, 0, 0, 1, 0, 3, 2, 3];

// 新しい21型の髪(どれもその型の地毛の色): 0 坊主に近い短髪・1 前髪のある
// 短髪・2 七三・3 クイフ・4 短い巻き毛・5 中くらいの波髪・6 お団子・
// 7 アフロ・8 アンダーカット。お団子は正面から見ると房が1本枠の外へ
// 飛び出して線に見えるので出さない(重み0)。
const _hairEuro = [1, 3, 3, 3, 3, 2, 2, 0, 1, 3];
const _hairCurly = [1, 3, 2, 1, 2, 4, 2, 0, 2, 3];
const _hairAfrican = [2, 4, 1, 1, 1, 4, 1, 0, 4, 2];

const faceTypes = [
  // バスケ由来(黒人系)
  FaceType('base', [2, 3, 4, 5], eyes: 5, hairWeights: _hairBlack),
  FaceType('round', [3, 4, 5], hairWeights: _hairBlack),
  FaceType('longface', [3, 4, 5], hairWeights: _hairBlack),
  FaceType('westafrica', [3, 4, 5], hairWeights: _hairBlack),
  FaceType('veteran', [3, 4, 5], hairWeights: _hairBlack),
  FaceType('babyface', [3, 4, 5], hairWeights: _hairBlack, lightBeard: true),
  // バスケ由来(ほか)
  FaceType('asian', [0, 1, 2], hairWeights: _hairOther),
  FaceType('latino', [1, 2, 3], hairWeights: _hairOther),
  FaceType('southeu', [1, 2, 3], hairWeights: _hairOther),
  FaceType('easteu', [0], hairWeights: _hairOther),
  FaceType('nordic', [0], hairWeights: _hairOther),
  FaceType('mideast', [1, 2, 3], hairWeights: _hairOther),
  FaceType('southasia', [2, 3, 4], hairWeights: _hairOther),
  // 新しい21型
  FaceType('english', [0, 1],
      hairs: [0, 1, 2, 3, 4, 6, 7, 8], hairWeights: _hairEuro),
  FaceType('spanish', [1, 2], hairWeights: _hairEuro),
  FaceType('german', [0, 1], hairWeights: _hairEuro),
  FaceType('italian', [1, 2], hairWeights: _hairEuro),
  FaceType('french', [0, 1, 2], hairWeights: _hairEuro),
  FaceType('northafrica', [2, 3], hairWeights: _hairCurly),
  FaceType('brazil', [2, 3, 4], hairWeights: _hairCurly),
  FaceType('senegal', [4, 5], hairWeights: _hairAfrican),
  FaceType('irish', [0], hairWeights: _hairEuro),
  FaceType('portuguese', [1, 2], hairWeights: _hairEuro),
  FaceType('argentine', [1, 2], hairWeights: _hairEuro),
  FaceType('dutch', [0], hairWeights: _hairEuro),
  FaceType('ghana', [4, 5], hairWeights: _hairAfrican),
  FaceType('japan', [0, 1], hairWeights: _hairEuro),
  FaceType('turkish', [1, 2], hairWeights: _hairEuro),
  FaceType('balkan', [0, 1], hairWeights: _hairEuro),
  FaceType('mixed', [2, 3], hairWeights: _hairCurly),
  FaceType('scottish', [0],
      hairs: [0, 1, 2, 3, 5, 6, 7, 8], hairWeights: _hairEuro),
  FaceType('mexican', [2, 3], hairWeights: _hairEuro),
  FaceType('korea', [0], hairWeights: _hairEuro),
  FaceType('rugged', [1, 2],
      hairs: [0, 1, 2, 3, 6, 7, 8], hairWeights: _hairEuro),
];

/// ひげの部品の数(0 なし・1 無精ひげ・2 あごひげ・3 ヤギひげ)。
const faceBeardCount = 4;

/// 国籍ごとの、顔の型の出やすさ(型の名前→重み)。名前は欧州の名前なので、
/// 東アジアの型はごく少なくしてある。
const faceWeightsByNation = <LeagueTheme, Map<String, int>>{
  LeagueTheme.england: {
    'english': 12, 'scottish': 4, 'irish': 4, 'rugged': 2, 'mixed': 3,
    'ghana': 2, 'westafrica': 1, 'base': 1, 'senegal': 1, 'round': 1,
    'babyface': 1, 'nordic': 1, 'dutch': 1, 'portuguese': 1, 'southeu': 1,
    'southasia': 1, 'korea': 1,
  },
  LeagueTheme.spain: {
    'spanish': 12, 'latino': 3, 'argentine': 3, 'southeu': 3,
    'portuguese': 2, 'northafrica': 2, 'brazil': 1, 'mexican': 1,
    'rugged': 1, 'french': 1, 'westafrica': 1, 'senegal': 1, 'mixed': 1,
  },
  LeagueTheme.germany: {
    'german': 12, 'easteu': 3, 'balkan': 3, 'turkish': 3, 'dutch': 2,
    'nordic': 2, 'mixed': 2, 'ghana': 1, 'westafrica': 1, 'base': 1,
    'mideast': 1, 'rugged': 1, 'northafrica': 1, 'japan': 1,
  },
  LeagueTheme.italy: {
    'italian': 12, 'southeu': 4, 'balkan': 2, 'brazil': 2, 'argentine': 2,
    'rugged': 2, 'latino': 1, 'senegal': 1, 'ghana': 1, 'northafrica': 1,
    'easteu': 1, 'french': 1, 'veteran': 1,
  },
  LeagueTheme.france: {
    'french': 10, 'northafrica': 5, 'senegal': 4, 'westafrica': 3,
    'mixed': 3, 'base': 2, 'ghana': 2, 'round': 1, 'longface': 1,
    'veteran': 1, 'babyface': 1, 'portuguese': 1, 'southeu': 1, 'mideast': 1,
  },
};

/// アフリカの国の代表の選手の、顔の型の出やすさ。
const faceWeightsAfrican = <String, int>{
  'senegal': 4, 'ghana': 4, 'northafrica': 4, 'westafrica': 3, 'base': 2,
  'round': 2, 'longface': 2, 'veteran': 1, 'babyface': 1,
};

/// 国籍が分からないときは、5か国の表を足したもの。
final Map<String, int> faceWeightsAll = () {
  final all = <String, int>{};
  for (final table in faceWeightsByNation.values) {
    table.forEach((k, v) => all[k] = (all[k] ?? 0) + v);
  }
  return all;
}();

/// 顔の決まり。選手の id・国籍・年齢から決まり、年を取ると白髪とひげが
/// 増える(一度付いたら同じ選手は戻らない)。
class FaceSpec {
  const FaceSpec({
    required this.type,
    required this.eyes,
    required this.beard,
    required this.tone,
    required this.hair,
    required this.gray,
  });

  final FaceType type;
  final int eyes;
  final int beard;
  final int tone;

  /// -1 は坊主(髪の層なし)。
  final int hair;
  final bool gray;

  String get bodyAsset =>
      'assets/faces/body/${type.name}_e${eyes}_b${beard}_t$tone.webp';
  String? get hairAsset => hair < 0
      ? null
      : 'assets/faces/hair/${type.name}_h$hair${gray ? 'g' : ''}.webp';

  @override
  bool operator ==(Object other) =>
      other is FaceSpec &&
      other.bodyAsset == bodyAsset &&
      other.hairAsset == hairAsset;
  @override
  int get hashCode => Object.hash(bodyAsset, hairAsset);
}

/// id と塩から決まる 0 以上の整数(FNV-1a 32bit)。String.hashCode は実行ごと・
/// 環境ごとに変わりうるので使わない。Web でも整数の精度に収まるよう、
/// 掛け算は 2^24 と 403 に分けて行う。
int faceHash(String id, int salt) {
  var h = 0x811c9dc5;
  for (final c in '$id#face$salt'.codeUnits) {
    h ^= c;
    h = ((h & 0xff) * 16777216 + h * 403) % 4294967296;
  }
  h ^= h >> 15;
  return h & 0x7fffffff;
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

/// 年齢が分からないときに使う年齢(白髪なし・ひげは少し)。
const _defaultAge = 25;

/// id [id]の選手の顔。[nation]は国籍(null なら5か国の合計)、[african]は
/// アフリカの国の代表の選手か。
FaceSpec faceOf(String id,
    {LeagueTheme? nation, int? age, bool african = false}) {
  final weights = african
      ? faceWeightsAfrican
      : (nation == null ? faceWeightsAll : faceWeightsByNation[nation]!);
  final names = weights.keys.toList();
  final name = names[_pick([for (final n in names) weights[n]!], faceHash(id, 1))];
  final type = faceTypes.firstWhere((t) => t.name == name);

  // 絵の無い髪は重み 0(坊主は常に選べる)。
  final hairWeights = [
    type.hairWeights[0],
    for (var h = 0; h < 9; h++)
      type.hairs.contains(h) ? type.hairWeights[h + 1] : 0,
  ];
  final hair = _pick(hairWeights, faceHash(id, 2)) - 1;

  final a = age ?? _defaultAge;
  // 白髪は33歳から。年ごとに見込みが上がり、同じ選手は一度白髪になったら
  // 戻らない(くじは id で決まっていて、境目だけが年で上がる)。
  final gray = hair >= 0 && faceHash(id, 3) % 100 < (a - 32) * 12;
  // ひげ: 22歳未満はなし。年とともに増える(22歳で18%、32歳で48%)。
  var beard = 0;
  if (a >= 22) {
    final chance = 18 + (a - 22) * 3;
    if (faceHash(id, 4) % 100 < chance) {
      beard = type.lightBeard ? 1 : 1 + (faceHash(id, 5) % 3);
    }
  }
  return FaceSpec(
    type: type,
    eyes: faceHash(id, 6) % type.eyes,
    beard: beard,
    tone: type.tones[faceHash(id, 7) % type.tones.length],
    hair: hair,
    gray: gray,
  );
}

/// 選手の顔(丸い枠にポジション色の縁)。描いた絵の体の上に髪を重ねる。
class PlayerFaceAvatar extends StatelessWidget {
  final String playerId;
  final Position position;
  final double size;
  final bool highlighted;

  /// 国籍。分からなければ null(5か国の合計の重みで決める)。
  final LeagueTheme? nation;

  /// 年齢。白髪とひげが年で増える。分からなければ null。
  final int? age;

  /// アフリカの国の代表の選手か。
  final bool african;

  const PlayerFaceAvatar({
    super.key,
    required this.playerId,
    required this.position,
    this.size = 40,
    this.highlighted = false,
    this.nation,
    this.age,
    this.african = false,
  });

  /// 選手[p]の顔。[game]があれば国籍とアフリカの代表かを引く。
  factory PlayerFaceAvatar.of(
    Player p,
    GameState? game, {
    Key? key,
    double size = 40,
    bool highlighted = false,
  }) {
    final nation = game?.nationalityOf(p);
    return PlayerFaceAvatar(
      key: key,
      playerId: p.id,
      position: p.position,
      size: size,
      highlighted: highlighted,
      nation: nation,
      age: p.age,
      african: nation != null &&
          GameStateNation.africanTeamFor(p.id, nation) != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = position.group.color;
    final f = faceOf(playerId, nation: nation, age: age, african: african);
    final px =
        (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 192);
    Widget layer(String path) => Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: px,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: highlighted ? 2.5 : 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: ColoredBox(
          color: ringColor.withValues(alpha: 0.18),
          child: Stack(fit: StackFit.expand, children: [
            layer(f.bodyAsset),
            if (f.hairAsset != null) layer(f.hairAsset!),
          ]),
        ),
      ),
    );
  }
}
