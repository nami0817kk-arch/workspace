/// GM の格(10段階)。シーズンごとに点が入り、通算の点で段階が決まる(2026-11-11 仕様)。
///
/// 点: 優勝100／ファイナル50／地区決勝30／2回戦15／プレーオフ10／勝ち越し5／自分で指名した選手の表彰5〜20／
/// オーナーの目標と黒字は各5。難しさで ×0.7 / ×1 / ×1.5。
library;

/// 各段階に入る通算の点(1段階目は0点から)。
const ratingFloors = [0, 50, 150, 300, 500, 800, 1200, 1800, 2600, 3600];

const ratingNames = ['新任', '見習い', '一人前', '中堅', '敏腕', '名GM', '名参謀', '辣腕', '伝説', '殿堂'];

/// 通算の点から段階(1〜10)。
int ratingLevelOf(int points) {
  var lv = 1;
  for (var i = 0; i < ratingFloors.length; i++) {
    if (points >= ratingFloors[i]) lv = i + 1;
  }
  return lv;
}

String ratingNameOf(int level) => ratingNames[(level - 1).clamp(0, ratingNames.length - 1)];

/// 次の段階に要る通算の点(最高段階なら null)。
int? nextRatingFloor(int points) {
  final lv = ratingLevelOf(points);
  return lv >= ratingFloors.length ? null : ratingFloors[lv];
}

/// 点の内訳1行。
class RatingPart {
  const RatingPart(this.label, this.points);
  final String label;
  final int points;

  List<Object> toJson() => [label, points];
  static RatingPart fromJson(List<dynamic> j) => RatingPart(j[0] as String, j[1] as int);
}

/// プレーオフの結果(0: 出られず〜5: 優勝)ごとの点。
const playoffPoints = [0, 10, 15, 30, 50, 100];
