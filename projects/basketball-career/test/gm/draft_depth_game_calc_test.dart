import 'package:basketball_career/gm/block_report.dart';
import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ドラフトの候補は約100人で、2巡目の最後の指名でも30人以上が残っている', () {
    final c = careerAt(3, 25)..startSeason();
    while (c.phase != Phase.draft) {
      botStep(c);
    }
    expect(c.prospects.length, c.order.length + 8 + deepProspects);
    // 足した候補の名前は、ほかの候補と重ならない
    final names = [for (final p in c.prospects) p.player.name];
    final deepNames = names.skip(c.order.length + 8).toList();
    expect(deepNames.toSet().length, deepNames.length);
    expect(deepNames.where(names.take(c.order.length + 8).contains), isEmpty);
    while (c.phase == Phase.draft) {
      if (c.canDraftPick) {
        c.pickProspect(byMid(c).first);
      } else {
        c.passPick();
      }
    }
    final left = c.prospects.where((p) => p.pickedBy == null).length;
    expect(left, greaterThanOrEqualTo(30));
  });

  test('自分の試合には、試合前の強さと勝つ見込みが残り、保存しても読み戻せる', () {
    final c = careerAt(7, 10)..startSeason();
    c.playBlock();
    final games = c.lastGames;
    expect(games, isNotEmpty);
    for (final g in games) {
      expect(g.hasChance, isTrue);
      expect(g.chanceOf(c.mine), inInclusiveRange(0.0, 1.0));
      expect(g.chanceOf(c.mine) + g.chanceOf(g.opponentOf(c.mine)), closeTo(1, 1e-9));
      expect(g.chance, closeTo(winChance(g.homeStr, g.awayStr), 1e-9));
      final back = GameResult.fromJson(g.toJson());
      expect(back.chance, closeTo(g.chance, 0.001));
      expect(back.homeStr, closeTo(g.homeStr, 0.05));
    }
    // 前の版の保存(見込みが無い)は -1
    expect(GameResult.fromJson({'h': 0, 'a': 1, 'hp': 100, 'ap': 90}).hasChance, isFalse);
  });

  test('強いチームほど見込みが高く、区切りの報告に見込みどおりの勝ち数が出る', () {
    final c = careerAt(11, 0)..startSeason();
    final snap = BlockSnapshot.of(c);
    c.playBlock();
    final r = BlockReport.make(c, snap);
    expect(r.hasChances, isTrue);
    final exp = r.expectedWinsOf(c.mine);
    expect(exp, inInclusiveRange(0.0, r.games.length.toDouble()));
    // 強さ1位のチームは、平均すると勝つ見込みが5割を超える
    expect(exp / r.games.length, greaterThan(0.5));
    expect(r.upsetWinsOf(c.mine) + r.letdownsOf(c.mine), lessThanOrEqualTo(r.games.length));
  });
}
