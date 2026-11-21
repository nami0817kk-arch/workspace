/// 始めるたびに違うリーグ(2026-11-21 の作り込み D-3)。チームの名前と街はそのままで、土台がリーグごとに変わる。
/// - 街の大きさ(スポンサーとグッズの収入に掛かる倍率)
/// - ファンの気質(負けたときと勝ったときの人気の動き)
/// - 施設の古さ(任されたときの施設の段階)
/// どれもリーグの種とチームから決まる(乱数の列は使わない)。
library;

enum FanTemper {
  fair('勝てば戻る', '勝てば人気が上がり、負ければ少し下がる'),
  loyal('負けても応援する', '負けが続いても、なかなか離れない'),
  fickle('すぐ離れる', '勝てば大きく上がり、負ければすぐ離れる');

  const FanTemper(this.label, this.text);
  final String label, text;
}

/// [team] の土台(リーグ [seed] での)。
({double market, FanTemper fans, int facility}) leagueBaseOf(int seed, int team) {
  final h = ((seed * 2654435761) ^ (team * 40503 + 131)) & 0x7fffffff;
  return (
    market: 0.75 + (h % 56) / 100,
    fans: FanTemper.values[(h >> 8) % FanTemper.values.length],
    facility: 1 + (h >> 12) % 2,
  );
}

/// 街の大きさの言い方。
String marketLabel(double m) => m >= 1.15
    ? '大きな街'
    : m <= 0.9
        ? '小さな街'
        : 'ふつうの街';

/// 始める前の10年の歴史(古い順。(優勝チーム, ファイナルの相手))を、リーグの種と強さの順から作る。
/// 強いチームほど勝ちやすく、ときどき連覇する(王者)。
List<(int, int)> makePrehistory(int seed, List<int> strengthOrder) {
  final out = <(int, int)>[];
  var last = -1;
  for (var y = 0; y < 10; y++) {
    final h = ((seed * 31 + y * 977) * 2654435761) & 0x7fffffff;
    int pick(int salt) {
      // 上位8チームから、上ほど選ばれやすく(三角の重み)
      final r = ((h >> salt) & 0xffff) % 36;
      var acc = 0;
      for (var k = 0; k < 8; k++) {
        acc += 8 - k;
        if (r < acc) return strengthOrder[k];
      }
      return strengthOrder[0];
    }

    var champ = last >= 0 && h % 3 == 0 ? last : pick(0);
    var loser = pick(5);
    if (loser == champ) loser = strengthOrder[(strengthOrder.indexOf(champ) + 1) % strengthOrder.length];
    out.add((champ, loser));
    last = champ;
  }
  return out;
}
