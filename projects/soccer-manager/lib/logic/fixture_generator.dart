import '../models/team.dart';
import '../models/league.dart';

class FixtureGenerator {
  static List<Fixture> generateDoubleRoundRobin(List<Team> teams) {
    final ids = teams.map((t) => t.id).toList();
    final hasBye = ids.length.isOdd;
    if (hasBye) ids.add('__BYE__');

    final n = ids.length;
    final rounds = n - 1;
    final half = n ~/ 2;
    final arr = List<String>.from(ids);
    final firstLeg = <List<Fixture>>[];

    for (int r = 0; r < rounds; r++) {
      final roundFixtures = <Fixture>[];
      for (int i = 0; i < half; i++) {
        // 円周法でそのまま組むと、動かない先頭のクラブ(1年目の自クラブ)は
        // 前半戦がすべてホーム、後半戦がすべてアウェイになる。先頭の組は
        // 節ごとに、ほかの組は位置ごとに入れ替えて、ホームとアウェイが
        // 交互に近くなるようにする(どのクラブも同じ側が3節より長く続かない)。
        // 日程はセーブに残るので、既存のセーブの日程は変わらない。
        final swap = i == 0 ? r.isOdd : i.isOdd;
        final home = swap ? arr[n - 1 - i] : arr[i];
        final away = swap ? arr[i] : arr[n - 1 - i];
        if (home != '__BYE__' && away != '__BYE__') {
          roundFixtures.add(
            Fixture(matchday: r + 1, homeTeamId: home, awayTeamId: away),
          );
        }
      }
      firstLeg.add(roundFixtures);
      final last = arr.removeLast();
      arr.insert(1, last);
    }

    final all = <Fixture>[];
    for (final round in firstLeg) {
      all.addAll(round);
    }
    // 後半戦は前半戦の単純な裏返し(同じ順番でホームとアウェイを入れ替え
    // るだけ)にしない。実際のリーグも後半戦の対戦順は前半と変えている。
    // 前半戦の節の並びをずらした候補から、ホームとアウェイが3節続く数が
    // いちばん少ないものを選ぶ(前半の最終節と後半の初戦が同じ組み合わせに
    // なる並び=同じ相手と連戦するものは選ばない)。日程はセーブに残るので、
    // 既存のセーブの日程は変わらない。
    final order =
        _secondHalfOrder(firstLeg, ids.where((id) => id != '__BYE__'));
    for (var k = 0; k < order.length; k++) {
      for (final f in firstLeg[order[k]]) {
        all.add(
          Fixture(
            matchday: rounds + k + 1,
            homeTeamId: f.awayTeamId,
            awayTeamId: f.homeTeamId,
          ),
        );
      }
    }
    return all;
  }

  /// 後半戦に前半戦のどの節をどの順で使うか(後半の k 節目 → 前半の節の添字)。
  ///
  /// 候補は「前半の節を s 節ずらした並び」(s = 1〜節の数-1)と、その逆順。
  /// 前半の最終節と同じ組み合わせで後半を始める並び(同じ相手と連戦)は
  /// 外し、全クラブで「同じ側が3節続く」回数が少ないもの、並べば同じ側の
  /// 最長が短いもの、さらに並べば同じ相手との2試合の間がいちばん詰まって
  /// いないものを選ぶ。くじは使わない(同じクラブの並びなら同じ日程)。
  static List<int> _secondHalfOrder(
      List<List<Fixture>> firstLeg, Iterable<String> teamIds) {
    final rounds = firstLeg.length;
    if (rounds < 2) return [for (var i = 0; i < rounds; i++) i];
    final teams = teamIds.toList();
    // 前半の節ごとの、クラブ → (ホームか, 相手)。
    final byRound = [
      for (final round in firstLeg)
        {
          for (final f in round) ...{
            f.homeTeamId: (true, f.awayTeamId),
            f.awayTeamId: (false, f.homeTeamId),
          },
        },
    ];
    final candidates = <List<int>>[
      for (var s = 1; s < rounds; s++) ...[
        [for (var k = 0; k < rounds; k++) (k + s) % rounds],
        [for (var k = 0; k < rounds; k++) (rounds - 1 - k + s) % rounds],
      ],
    ];
    List<int>? best;
    (int, int, int)? bestScore;
    for (final order in candidates) {
      // 前半の最終節と同じ組み合わせで始めると、同じ相手と2節続けて当たる。
      if (order.first == rounds - 1) continue;
      var triples = 0;
      var longest = 0;
      var closest = 1 << 30;
      for (final t in teams) {
        final venues = <bool>[];
        final meetings = <String, int>{};
        for (var r = 0; r < rounds; r++) {
          final e = byRound[r][t];
          if (e == null) continue;
          venues.add(e.$1);
          meetings[e.$2] = r;
        }
        for (var k = 0; k < rounds; k++) {
          final e = byRound[order[k]][t];
          if (e == null) continue;
          venues.add(!e.$1);
          final first = meetings[e.$2];
          if (first != null) {
            final gap = rounds + k - first;
            if (gap < closest) closest = gap;
          }
        }
        var run = 0;
        for (var i = 0; i < venues.length; i++) {
          run = i > 0 && venues[i] == venues[i - 1] ? run + 1 : 1;
          if (run >= 3) triples++;
          if (run > longest) longest = run;
        }
      }
      final score = (triples, longest, -closest);
      if (bestScore == null ||
          score.$1 < bestScore.$1 ||
          (score.$1 == bestScore.$1 &&
              (score.$2 < bestScore.$2 ||
                  (score.$2 == bestScore.$2 && score.$3 < bestScore.$3)))) {
        best = order;
        bestScore = score;
      }
    }
    return best ?? [for (var i = 0; i < rounds; i++) i];
  }
}
