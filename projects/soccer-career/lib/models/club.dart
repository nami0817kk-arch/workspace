/// クラブ。実在の名称は使わず、すべて架空。
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.strength,
    required this.tier,
  });

  final String id;
  final String name;

  /// クラブの総合的な強さ（30〜90 程度）。試合結果と移籍先の判定に使う。
  final int strength;

  /// 1 が最上位リーグ。数字が大きいほど下部。
  final int tier;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'strength': strength, 'tier': tier};

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['name'] as String,
        strength: json['strength'] as int,
        tier: json['tier'] as int,
      );
}

/// リーグ順位表の1行。
class TableRow {
  TableRow({required this.clubId, required this.clubName});

  final String clubId;
  final String clubName;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => won * 3 + drawn;
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
