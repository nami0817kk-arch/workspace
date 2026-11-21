// 名前（`_name`）は private だが、**`this._name` には書けない**
// ——Dart は名前付き引数を `_` で始められない。
// ignore_for_file: prefer_initializing_formals

import '../game/formulas.dart';
import '../game/world.dart';

/// クラブ。実在の名称は使わず、すべて架空。
class Club {
  const Club({
    required this.id,
    required String name,
    required this.strength,
    required this.tier,
    this.countryId = 'yamato',
  }) : _name = name;

  final String id;

  final String _name;

  /// **名前は ID から作り直す。**
  ///
  /// 保存データには文字列で乗っているが、言語を切り替えると古くなる。
  /// ID は不変なので、そこから引き直す（`World.clubNameFor`）。
  /// 知らない形の ID のときだけ、保存の文字列をそのまま使う。
  String get name => World.clubNameFor(id) ?? _name;

  /// クラブの総合的な強さ（30〜90 程度）。試合結果と移籍先の判定に使う。
  final int strength;

  /// 1 が最上位リーグ。数字が大きいほど下部。
  final int tier;

  /// 所属国。外国人枠と労働許可の判定に使う。
  final String countryId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'strength': strength,
    'tier': tier,
    'countryId': countryId,
  };

  factory Club.fromJson(Map<String, dynamic> json) => Club(
    id: json['id'] as String,
    name: json['name'] as String,
    strength: json['strength'] as int,
    tier: json['tier'] as int,
    // 国を持たせる前の保存データは、既定の国のクラブとして読む。
    countryId: json['countryId'] as String? ?? 'yamato',
  );
}

/// リーグ順位表の1行。
class TableRow {
  TableRow({required this.clubId, required String clubName})
    : _clubName = clubName;

  final String clubId;

  final String _clubName;

  /// クラブ名は ID から作り直す（[Club.name] と同じ理由）。
  String get clubName => World.clubNameFor(clubId) ?? _clubName;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  /// 勝点。**数字は `Formulas` から引く。**
  /// 3 と 1 を直書きしていたので、`Formulas.pointsWin` / `pointsDraw` は
  /// 定義されているだけで誰も読んでいなかった。
  int get points => won * Formulas.pointsWin + drawn * Formulas.pointsDraw;
  int get goalDifference => goalsFor - goalsAgainst;

  void record({required int scored, required int conceded}) {
    played++;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      won++;
    } else if (scored == conceded) {
      drawn++;
    } else {
      lost++;
    }
  }

  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'clubName': clubName,
    'played': played,
    'won': won,
    'drawn': drawn,
    'lost': lost,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
  };

  factory TableRow.fromJson(Map<String, dynamic> json) {
    final row = TableRow(
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String,
    );
    row.played = json['played'] as int;
    row.won = json['won'] as int;
    row.drawn = json['drawn'] as int;
    row.lost = json['lost'] as int;
    row.goalsFor = json['goalsFor'] as int;
    row.goalsAgainst = json['goalsAgainst'] as int;
    return row;
  }
}
