import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:basketball_career/gm/potential_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み A-4: 特性を「見える」と「隠れる」に分ける。
void main() {
  test('見える特性(地元っ子・メディア好き・リーダー)は初めから分かり、隠れる特性はほかのチームの選手では分からない', () {
    final c = careerAt(3, 12);
    var hiddenSeen = 0;
    for (var t = 0; t < c.teams.length; t++) {
      if (t == c.mine) continue;
      for (final p in c.teams[t].roster) {
        if (p.traitsKnown) continue;
        final (shown, valueKnown, more) = traitsShown(c, p);
        final all = personalityOf(p).traits;
        for (final x in all) {
          if (visibleTraits.contains(x)) {
            expect(shown, contains(x));
          } else {
            expect(shown, isNot(contains(x)));
            hiddenSeen++;
          }
        }
        expect(valueKnown, isFalse);
        expect(more, isTrue);
      }
    }
    expect(hiddenSeen, greaterThan(0));
  });

  test('自分のチームに入った選手は、1〜2区切りで隠れた特性まで分かる', () {
    final c = careerAt(4, 12)..startSeason();
    final p = c.me.roster.first;
    p.tenure = 0;
    p.traitsKnown = false;
    c.blocksWithMe.remove(p.id);
    expect(traitsShown(c, p).$3, isTrue);
    c.playBlock();
    c.playBlock();
    expect(c.blocksWithMe[p.id], greaterThanOrEqualTo(2));
    final (shown, valueKnown, more) = traitsShown(c, p);
    expect(shown, personalityOf(p).traits);
    expect(valueKnown, isTrue);
    expect(more, isFalse);
    final y = Career.fromJson(c.toJson());
    expect(y.blocksWithMe[p.id], c.blocksWithMe[p.id]);
  });

  test('下調べ・ワークアウトをした選手は全部分かる。けがしがちは、けがで分かる', () {
    final c = careerAt(5, 12);
    final other = [for (var t = 0; t < c.teams.length; t++) if (t != c.mine) ...c.teams[t].roster];
    final p = other.first..traitsKnown = true;
    expect(traitsShown(c, p).$1, personalityOf(p).traits);
    final fragile = other.where((q) => !q.traitsKnown && hasTrait(q, Trait.fragile)).firstOrNull;
    if (fragile != null) {
      expect(traitsShown(c, fragile).$1, isNot(contains(Trait.fragile)));
      c.traitSeen.add(fragile.id * 32 + Trait.fragile.index);
      expect(traitsShown(c, fragile).$1, contains(Trait.fragile));
    }
    expect(traitsLine(c, other[1]), startsWith('性格'));
  });
}
