import 'dart:math';

import '../l10n/lang.dart';
import '../models/acquaintance.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/entourage.dart';
import '../models/news.dart';
import 'formulas.dart';
import 'newsroom.dart';
import 'squads.dart';
import 'world.dart';

/// 関わった人の、続き（2026-11-22）。
///
/// **覚える → 1年進める → 次の季の同僚を名簿から据える** の3つ。
/// どれも乱数はキャリアの乱数を使わない——席と年から決める。
/// キャリアの乱数を引くと、その後の判定の並びが全部ずれて、
/// 知り合いが居るかどうかで試合の結果が変わってしまう。
class Acquaintances {
  const Acquaintances._();

  /// シーズンの終わりに、今季関わった人を覚える。
  ///
  /// 覚えるのは **競争相手・相方・得点王レースで1つ上に居た相手** の3人まで。
  /// 名簿の人でなければ覚えない（殿堂の人・乱数で引いた人は続きを持てない）。
  static List<Acquaintance> remember(CareerState state) {
    final out = [...state.acquaintances];
    final squad = Squad.of(
      state.club,
      year: state.year,
      known: state.acquaintances,
    );

    void add(SquadPlayer? p, Bond bond, String clubId) {
      if (p == null || p.seat.isEmpty) return;
      if (out.any((a) => a.seat == p.seat)) return;
      out.add(
        Acquaintance(
          seat: p.seat,
          name: p.name,
          position: p.position,
          countryId: p.countryId,
          born: p.born,
          overall: p.overall,
          clubId: clubId,
          bond: bond,
          metYear: state.year,
          ceiling: ceilingOf(p.seat),
        ),
      );
    }

    SquadPlayer? inSquad(String? seat) {
      if (seat == null) return null;
      for (final p in squad.players) {
        if (p.seat == seat) return p;
      }
      return null;
    }

    add(inSquad(state.competitor?.seat), Bond.rival, state.club.id);
    add(inSquad(state.partner?.seat), Bond.partner, state.club.id);

    // 得点王レースで、自分の1つ上に居た相手。**点を取った季だけ**——
    // 0点の守備の選手に「得点王を争った相手」を作っても縁にならない。
    if (state.seasonStats.goals >= Formulas.acquaintanceScorerGoals) {
      final table = ScorerRace.table(state, take: 999);
      final me = table.indexWhere((s) => s.isPlayer);
      if (me > 0) {
        final above = table[me - 1];
        for (final club in state.league) {
          if (club.name != above.clubName) continue;
          final top = Squad.of(
            club,
            year: state.year,
            known: state.acquaintances,
          ).topScorer;
          add(top, Bond.scorer, club.id);
          break;
        }
      }
    }
    return out;
  }

  /// 1年進める。[year] は**次の季**。続きと、記事にする出来事を返す。
  ///
  /// - 伸び: 名簿と同じ曲線（20歳まで伸び、29歳から落ちる）に、
  ///   その人の器（[Acquaintance.ceiling]）を若いうちだけ乗せる
  /// - 移籍: クラブより力が上なら上へ、下なら下へ。確率で
  /// - 引退: 33歳から確率で、37歳で必ず
  static ({List<Acquaintance> people, List<NewsItem> news}) advance(
    List<Acquaintance> people, {
    required int year,
    required Club nextClub,
  }) {
    final next = <Acquaintance>[];
    final events = <({int priority, NewsItem item})>[];
    for (final a in people) {
      if (a.retired) {
        next.add(a);
        continue;
      }
      final r = Random(_hash('${a.seat}|$year'));
      final age = a.ageIn(year);
      final from = World.clubNameFor(a.clubId) ?? '';

      final retiring =
          age >= Formulas.acquaintanceRetireAt ||
          (age >= Formulas.acquaintanceRetireFrom &&
              r.nextDouble() <
                  0.15 + (age - Formulas.acquaintanceRetireFrom) * 0.15);
      if (retiring) {
        next.add(a.copyWith(retiredYear: year - 1));
        events.add((
          priority: a.bond == Bond.scorer ? 2 : 1,
          item: _item(
            year,
            tr('${a.bond.label}の${a.name}が引退', '${a.bond.label} ${a.name} retires'),
            tr('$fromで${age - 1}歳。', 'At $from, aged ${age - 1}.'),
          ),
        ));
        continue;
      }

      var overall = a.overall + _growth(age) + r.nextInt(3) - 1;
      if (age <= 27 && r.nextDouble() < a.ceiling.abs() / 8) {
        overall += a.ceiling > 0 ? 2 : -1;
      }
      overall = overall.clamp(30, 94);

      var clubId = a.clubId;
      final here = _club(a.clubId);
      if (here != null) {
        final to = _moveFrom(here, overall, r);
        if (to != null) {
          clubId = to.id;
          final toName = World.clubNameFor(to.id) ?? to.name;
          final toYou = to.id == nextClub.id;
          events.add((
            priority: toYou
                ? 0
                : to.strength > nextClub.strength
                ? 2
                : 3,
            item: toYou
                ? _item(
                    year,
                    tr('${a.bond.label}の${a.name}が加入', '${a.bond.label} ${a.name} joins your club'),
                    tr('$fromから。総合力$overall。', 'From $from. Overall $overall.'),
                  )
                : _item(
                    year,
                    tr('${a.bond.label}の${a.name}、$toNameへ移籍', '${a.bond.label} ${a.name} moves to $toName'),
                    tr('$fromから。総合力$overall。', 'From $from. Overall $overall.'),
                  ),
          ));
        }
      }
      next.add(a.copyWith(overall: overall, clubId: clubId));
    }

    events.sort((x, y) => x.priority.compareTo(y.priority));
    return (
      people: _trim(next, keepClub: nextClub.id),
      news: [
        for (final e in events.take(Formulas.acquaintanceNewsPerSeason)) e.item,
      ],
    );
  }

  /// 次の季の競争相手と相方を、**名簿の実在の人から**据える。
  ///
  /// 同じクラブに残り、同じ人がまだ居るなら、その人のまま（呼吸も残る）。
  /// 居なくなっていたら（移籍・引退）、名簿から選び直す。
  /// 殿堂の人（`fromLegend`）はそのまま——名簿の外の人として居てよい。
  ///
  /// **乱数は引かない。** 呼ぶ側は `Teammate.roll` をこれまでどおり引いてから
  /// ここに渡す——乱数の並びを変えないため（変えると、知り合いの有無と
  /// 関係なく、その後の試合の結果が全部ずれる）。
  static ({Teammate competitor, Teammate partner}) seat({
    required Club club,
    required int year,
    required Position position,
    required int overall,
    required List<Acquaintance> known,
    required Teammate competitor,
    required Teammate partner,
    required bool movedClub,
  }) {
    final squad = Squad.of(club, year: year, known: known);

    SquadPlayer? find(String? seat) {
      if (seat == null || movedClub) return null;
      for (final p in squad.players) {
        if (p.seat == seat) return p;
      }
      return null;
    }

    Teammate place(Teammate t, SquadPlayer? keep, SquadPlayer? fresh) {
      if (t.fromLegend) return t;
      final p = keep ?? fresh;
      if (p == null) return t;
      return Teammate.fromSquad(
        name: p.name,
        kind: t.kind,
        overall: p.overall,
        age: p.age,
        seat: p.seat,
        // 同じ人なら呼吸は残る。別の人になったら一から。
        synergy: keep != null ? t.synergy : 0,
      );
    }

    return (
      competitor: place(
        competitor,
        find(competitor.seat),
        squad.nearestRival(position, overall),
      ),
      partner: place(partner, find(partner.seat), squad.partnerFor(position)),
    );
  }

  /// 器。席から決める——**待っても引き直せない**（コツと同じ理屈）。
  static int ceilingOf(String seat) => _hash(seat) % 13 - 6;

  /// 名簿と同じ曲線（`Squad._ageAdjust`）を、1年ぶんの差にしたもの。
  static int _growth(int age) {
    if (age <= 20) return 3;
    if (age <= 28) return 0;
    return -2;
  }

  /// 動くなら行き先。**同じ連盟の中**で、力に見合うクラブへ。
  static Club? _moveFrom(Club here, int overall, Random r) {
    final gap = overall - here.strength;
    final double chance;
    final bool Function(Club) fits;
    if (gap >= Formulas.acquaintanceMoveUpGap) {
      chance = min(0.7, 0.3 + (gap - Formulas.acquaintanceMoveUpGap) * 0.05);
      fits = (c) =>
          c.strength > here.strength && (c.strength - overall).abs() <= 3;
    } else if (gap <= -Formulas.acquaintanceMoveDownGap) {
      chance = 0.35;
      fits = (c) =>
          c.strength < here.strength &&
          c.strength <= overall &&
          c.strength >= overall - 6;
    } else {
      chance = 0.05;
      fits = (c) => (c.strength - here.strength).abs() <= 3;
    }
    if (r.nextDouble() >= chance) return null;
    final confed = World.byId(here.countryId).confederation;
    final options = [
      for (final c in _allClubs)
        if (c.id != here.id &&
            World.byId(c.countryId).confederation == confed &&
            fits(c))
          c,
    ];
    if (options.isEmpty) return null;
    return options[r.nextInt(options.length)];
  }

  /// 上限を超えたら忘れる。**引退した人から**、次に知り合ったのが古い人から。
  /// 自分の次のクラブに居る人は忘れない（毎日顔を合わせる）。
  static List<Acquaintance> _trim(
    List<Acquaintance> people, {
    required String keepClub,
  }) {
    if (people.length <= Formulas.acquaintanceKeep) return people;
    final order = [...people]
      ..sort((a, b) {
        int rank(Acquaintance x) =>
            x.retired ? 0 : (x.clubId == keepClub ? 2 : 1);
        final d = rank(a) - rank(b);
        if (d != 0) return d;
        return (a.retiredYear ?? a.metYear).compareTo(
          b.retiredYear ?? b.metYear,
        );
      });
    final drop = order
        .take(people.length - Formulas.acquaintanceKeep)
        .map((a) => a.seat)
        .toSet();
    return [
      for (final a in people)
        if (!drop.contains(a.seat)) a,
    ];
  }

  static NewsItem _item(int year, String headline, String body) => NewsItem(
    year: year,
    matchday: 0,
    kind: NewsKind.people,
    headline: headline,
    body: body,
  );

  static List<Club>? _all;

  /// 全部の国・全部の部のクラブ。1度作れば変わらない。
  static List<Club> get _allClubs => _all ??= [
    for (final c in World.countries)
      for (var t = 1; t <= c.tiers; t++) ...World.buildLeague(c.id, t),
  ];

  static Club? _club(String id) {
    for (final c in _allClubs) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 文字列の和。`String.hashCode` は実行ごとに変わるので使わない。
  static int _hash(String s) =>
      s.codeUnits.fold<int>(11, (a, b) => (a * 31 + b) & 0x3fffffff);
}
