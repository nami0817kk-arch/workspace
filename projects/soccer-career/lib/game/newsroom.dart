import 'dart:math';

import '../l10n/lang.dart';
import 'squads.dart';
import 'formulas.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/life_event.dart';
import '../models/news.dart';
import '../models/cup.dart';
import '../models/promise.dart';
import '../models/traits.dart';
import '../models/season.dart';
import '../models/attributes.dart';

/// 世の中の反応を作るところ。
///
/// 数字は積み上がっても、「誰かに見られている」感覚は別に要る。
/// 実際の選手のキャリアは、他人が書いた見出しの連なりとしても残る。
///
/// **毎試合は書かない。** 全部の試合に見出しが付くと、どれも記事に見えなくなる。
/// 目立ったこと・節目だけを拾う。
class Newsroom {
  const Newsroom._();

  /// 保存しておく本数。古いものから捨てる。
  static const int keep = 40;

  /// 試合のあとに出る記事。無ければ空。
  static List<NewsItem> afterMatch(CareerState state, MatchResult result) {
    final items = <NewsItem>[];
    final name = state.player.name;
    final rating = result.rating;
    final day = result.matchday;
    // かつて在籍したクラブとの対戦か。
    final former = state.history.any((h) => h.clubName == result.opponentName);

    // --- 目立った出来事 ---
    if (result.goals >= 3) {
      items.add(
        _match(
          state,
          day,
          tr('$nameがハットトリック', '$name with a hat-trick'),
          tr('${result.opponentName}戦で3ゴール。${result.scoreLine}。', 'Three against ${result.opponentName}. ${result.scoreLine}.'),
        ),
      );
    } else if (former && result.goals > 0) {
      items.add(
        _match(
          state,
          day,
          tr('$nameが古巣に牙を剥く', '$name turns on his old club'),
          tr('かつての本拠地で${result.goals}ゴール。${result.scoreLine}。', '${result.goals} goal(s) at his former home. ${result.scoreLine}.'),
        ),
      );
    } else if (result.goals == 2) {
      items.add(
        _match(state, day, tr('$nameが2ゴール', '$name with two'), tr('${result.opponentName}戦を決定づけた。', 'He settled the match against ${result.opponentName}.')),
      );
    } else if (result.goals == 1 &&
        result.won &&
        result.scored - result.conceded == 1) {
      items.add(
        _match(
          state,
          day,
          tr('$nameの1点が決勝点', '$name scores the winner'),
          tr('${result.opponentName}戦、${result.scoreLine}。', 'Against ${result.opponentName}, ${result.scoreLine}.'),
        ),
      );
    } else if (rating != null &&
        rating >= 8.2 &&
        !_recentlySaid(state, day, _praises, (v) => '$name$v')) {
      items.add(
        _match(
          state,
          day,
          _praise(state, day, name),
          tr('${result.opponentName}戦で評価点${rating.toStringAsFixed(1)}。', 'Rated ${rating.toStringAsFixed(1)} against ${result.opponentName}.'),
        ),
      );
    } else if (rating != null &&
        rating <= 5.2 &&
        !_recentlySaid(state, day, _criticisms, (v) => '$name$v')) {
      items.add(
        _match(
          state,
          day,
          _criticism(state, day, name),
          tr('${result.opponentName}戦は評価点${rating.toStringAsFixed(1)}に終わった。', 'A rating of ${rating.toStringAsFixed(1)} against ${result.opponentName}.'),
        ),
      );
    } else if (result.conceded == 0 &&
        result.appearance != Appearance.benched &&
        _isDefender(state.player.position)) {
      items.add(
        _match(state, day, tr('$nameを軸に完封', 'A clean sheet built around $name'), tr('${result.opponentName}戦を無失点で終えた。', 'They kept ${result.opponentName} out.')),
      );
    } else if (result.conceded >= 4 &&
        !_recentlySaid(state, day, _collapses, (v) => '${state.club.name}$v')) {
      items.add(
        _match(
          state,
          day,
          _vary(state, day, _collapses, (v) => '${state.club.name}$v'),
          tr('${result.opponentName}に${result.conceded}失点。', '${result.conceded} conceded against ${result.opponentName}.'),
        ),
      );
    } else if (result.won &&
        result.scored - result.conceded >= 3 &&
        !_recentlySaid(state, day, _routs, (v) => '${state.club.name}$v')) {
      items.add(
        _match(
          state,
          day,
          _vary(state, day, _routs, (v) => '${state.club.name}$v'),
          tr('${result.opponentName}を${result.scoreLine}で退けた。', '${result.opponentName} beaten ${result.scoreLine}.'),
        ),
      );
    }

    // --- 節目 ---
    items.addAll(_milestones(state, result));
    return items;
  }

  static const List<Say> _praises = [
    Say('、文句なしの出来', ' was faultless'),
    Say('が試合を支配した', ' ran the match'),
    Say('に称賛の声', ' draws praise'),
    Say('の一挙手一投足に沸いた', ' had the crowd on its feet'),
    Say('が違いを見せた', ' made the difference'),
    Say('に地元紙も最高点', ' given top marks by the local paper'),
    Say('の一日だった', ' owned the day'),
    Say('を止められる者がいなかった', ' could not be stopped'),
  ];

  static const List<Say> _criticisms = [
    Say('、精彩を欠く', ' off the pace'),
    Say('は最後まで流れに入れず', ' never got into it'),
    Say('に厳しい採点', ' marked down harshly'),
    Say('の不調が続く', ' still out of form'),
    Say('は影が薄かった', ' barely seen'),
    Say('に立て直しを求める声', ' under pressure to turn it round'),
    Say('は何も起こせず', ' could not make anything happen'),
    Say('に地元紙が苦言', ' criticised by the local paper'),
  ];

  static const List<Say> _collapses = [
    Say('、守備が崩壊', ' as the defence fell apart'),
    Say('の守りが持たなかった', ' could not hold the line'),
    Say('、後ろから崩される', ' opened up from the back'),
    Say('の最終ラインが機能せず', ' and the back line did not work'),
  ];

  static const List<Say> _routs = [
    Say('が快勝', ' win comfortably'),
    Say('が押し切った', ' see it out'),
    Say('が力の差を見せた', ' show the gap in class'),
    Say('が危なげなく勝ち切る', ' win without alarm'),
  ];

  /// 同じ種類の見出しを、続けて出さないための間隔（節）。
  ///
  /// 新聞は不調を11回書かない。**1シーズンに酷評が11本**出ていて、
  /// 記録タブが「また悪かった」の羅列になっていた。
  static const int sameKindGap = 6;

  /// この種類の見出しを、最近書いたか。
  ///
  /// 言い回しの一覧をそのまま使って照合するので、種類を別に持たなくてよい。
  static bool _recentlySaid(
    CareerState state,
    int matchday,
    List<Say> variants,
    String Function(String) build,
  ) {
    final lines = {for (final v in variants) build(v.t)};
    return state.news.any(
      (n) =>
          n.year == state.year &&
          matchday - n.matchday < sameKindGap &&
          lines.contains(n.headline),
    );
  }

  /// 見出しの言い回しを選ぶ。**すでに出ている見出しは避ける。**
  ///
  /// 節番号だけで選んでいた頃は、4節ごとに同じ文が回ってきて、
  /// 記録タブに「◯◯に称賛の声」が並んだ（13本中7本が重複していた）。
  /// 乱数は持たない——同じ状態からは必ず同じ文が出る、という性質は残す。
  static String _vary(
    CareerState state,
    int matchday,
    List<Say> variants,
    String Function(String) build,
  ) {
    final used = state.news.map((n) => n.headline).toSet();
    for (var i = 0; i < variants.length; i++) {
      final line = build(variants[(matchday + i) % variants.length].t);
      if (!used.contains(line)) return line;
    }
    // 全部出尽くしたら、節で選んだものに戻る。
    return build(variants[matchday % variants.length].t);
  }

  static String _praise(CareerState state, int matchday, String name) =>
      _vary(state, matchday, _praises, (v) => '$name$v');

  static String _criticism(CareerState state, int matchday, String name) =>
      _vary(state, matchday, _criticisms, (v) => '$name$v');

  /// 通算の数字が節目を跨いだかを見る。
  ///
  /// 跨いだ瞬間に出したいので、シーズン終了時の称号とは別に持つ。
  /// 称号で出すと「デビュー」が半年後に報じられることになる。
  static List<NewsItem> _milestones(CareerState state, MatchResult result) {
    final items = <NewsItem>[];
    final name = state.player.name;
    final totals = state.careerTotals;
    final played =
        result.appearance == Appearance.start ||
        result.appearance == Appearance.sub;
    if (!played) return items;

    final day = result.matchday;
    final before = totals.appearances - 1;
    for (final mark in const [1, 50, 100, 200, 300, 400, 500]) {
      if (before < mark && totals.appearances >= mark) {
        items.add(
          _milestone(
            state,
            day,
            mark == 1 ? tr('$nameがプロデビュー', '$name makes his professional debut') : tr('$nameが通算$mark試合', '$name reaches $mark appearances'),
            mark == 1
                ? tr('${state.club.name}の一員として、初めてピッチに立った。', 'He took the pitch for ${state.club.name} for the first time.')
                : tr('${state.player.age}歳での到達。', 'Reached at ${state.player.age}.'),
          ),
        );
      }
    }

    if (result.goals > 0) {
      final beforeGoals = totals.goals - result.goals;
      for (final mark in const [1, 25, 50, 100, 150, 200]) {
        if (beforeGoals < mark && totals.goals >= mark) {
          items.add(
            _milestone(
              state,
              day,
              mark == 1 ? tr('$nameが記念すべき初ゴール', '$name scores his first goal') : tr('$nameが通算$markゴール', '$name reaches $mark career goals'),
              tr('${result.opponentName}戦での一撃だった。', 'It came against ${result.opponentName}.'),
            ),
          );
        }
      }
    }

    if (result.international) {
      for (final mark in const [1, 25, 50, 100]) {
        if (state.caps == mark) {
          items.add(
            _national(
              state,
              day,
              mark == 1 ? tr('$nameが代表デビュー', '$name makes his international debut') : tr('$nameが代表$markキャップ', '$name reaches $mark caps'),
              mark == 1 ? tr('呼ばれるだけでは終わらなかった。', 'Being called up was only the start.') : '',
            ),
          );
        }
      }
    }
    return items;
  }

  /// シーズンの終わりに出る記事。
  static List<NewsItem> afterSeason(
    CareerState state, {
    required bool promoted,
    required bool relegated,
    required bool champion,
  }) {
    final items = <NewsItem>[];
    final name = state.player.name;
    final stats = state.seasonStats;

    if (champion) {
      items.add(
        _club(
          state,
          tr('${state.club.name}がリーグ優勝', '${state.club.name} are champions'),
          tr('$nameは${stats.appearances}試合${stats.goals}ゴールで貢献した。', '$name contributed ${stats.goals} goal(s) in ${plural(stats.appearances, 'appearance')}.'),
        ),
      );
    }
    if (promoted) {
      items.add(
        _club(state, tr('${state.club.name}が昇格', '${state.club.name} are promoted'), tr('来季は${state.club.tier - 1}部で戦う。', 'Next season is in tier ${state.club.tier - 1}.')),
      );
    }
    if (relegated) {
      items.add(_club(state, tr('${state.club.name}が降格', '${state.club.name} are relegated'), tr('$nameの去就に注目が集まる。', 'Attention turns to where $name goes next.')));
    }
    if (stats.appearances >= 20 && stats.averageRating >= 7.4) {
      items.add(
        _milestone(
          state,
          0,
          tr('$name、自己最高のシーズン', '$name has his best season yet'),
          tr('${stats.appearances}試合で平均評価${stats.averageRating.toStringAsFixed(2)}。', 'An average rating of ${stats.averageRating.toStringAsFixed(2)} in ${plural(stats.appearances, 'appearance')}.'),
        ),
      );
    }
    if (stats.appearances <= 5) {
      items.add(
        _club(state, tr('$name、出番のないまま1年', 'A year without a game for $name'), tr('今季の出場は${stats.appearances}試合にとどまった。', 'He played just ${stats.appearances} match(es) this season.')),
      );
    }
    return items;
  }

  /// 移籍・契約のときに出る記事。
  static NewsItem transfer(
    CareerState state, {
    required String toClub,
    required int fee,
    required bool loan,
    required bool renewal,
  }) {
    final name = state.player.name;
    if (renewal) {
      return _transfer(
        state,
        tr('$nameが$toClubと契約を更新', '$name signs a new deal with $toClub'),
        tr('${state.contractYears}年の新しい契約になった。', 'A new ${state.contractYears}-year contract.'),
      );
    }
    if (loan) {
      return _transfer(state, tr('$nameが$toClubへ期限付き移籍', '$name joins $toClub on loan'), tr('出場機会を求めての1年になる。', 'A year in search of game time.'));
    }
    return _transfer(
      state,
      tr('$nameが$toClubへ移籍', '$name joins $toClub'),
      fee > 0 ? tr('移籍金は${_money(fee)}と伝えられている。', 'The fee is reported at ${_money(fee)}.') : '',
    );
  }

  /// 次の試合が持つ意味。順位表とクラブの関係から決まる。
  /// **今日の試合は、じっくりやる試合か。**
  ///
  /// 38試合すべてを同じ濃さでプレイする前提をやめた（2026-09-11）。
  /// 全部を等しく薄くすると、1試合が「数回タップして終わり」に固定され、
  /// 試合の中で段取りを組む余地が無くなる（実測で、刻んでから決める手筋が
  /// 最下位になった）。**重い試合だけを厚くする。**
  ///
  /// 判定はここ1か所。画面（次節カード）も局面の数も、同じここから出す。
  static bool isBigFixture(CareerState state) {
    if (state.seasonFinished) return false;
    // 代表戦は数が少なく、1試合が重い。
    if (state.pendingInternational) return true;
    // カップは勝ち上がるほど重くなる。早いラウンドは控えの出番。
    final tie = state.pendingCup;
    if (tie != null) return tie.round.index >= CupRound.quarter.index;

    // 順位・因縁が絡む試合。
    if (stakeFor(state) != FixtureStake.none) return true;

    // 格上との対戦。試合の中の判断が一番効く日。
    final opponent = state.opponentFor(state.matchday);
    if (opponent.strength - state.club.strength >= Formulas.bigFixtureGap) {
      return true;
    }

    // 終盤、監督の目標か自分の約束に手が届く試合。
    final left = state.fixtures.length - state.matchday;
    if (left <= Formulas.bigFixtureRunIn &&
        (state.objectiveReach != null || state.promiseReach != null)) {
      return true;
    }
    return false;
  }

  static FixtureStake stakeFor(CareerState state) {
    if (state.seasonFinished || state.pendingInternational) {
      return FixtureStake.none;
    }
    final opponent = state.opponentFor(state.matchday);

    // かつて在籍したクラブ。ここが一番効く。
    if (state.history.any((h) => h.clubName == opponent.name)) {
      return FixtureStake.formerClub;
    }
    // 同じ街のクラブ。IDが隣り合うものを同郷として扱う。
    if (_isDerby(state.club, opponent)) return FixtureStake.derby;

    // 順位が絡む対戦。シーズンが進んでからでないと意味が無い。
    final table = state.sortedTable;
    final total = table.length;
    if (state.matchday > total ~/ 2) {
      final mine = table.indexWhere((r) => r.clubId == state.club.id);
      final theirs = table.indexWhere((r) => r.clubId == opponent.id);
      if (mine < 0 || theirs < 0) return FixtureStake.none;
      if (mine < 3 && theirs < 3) {
        return state.club.tier == 1
            ? FixtureStake.titleRace
            : FixtureStake.promotion;
      }
      if (mine >= total - 4 && theirs >= total - 4) {
        return FixtureStake.survival;
      }
    }
    return FixtureStake.none;
  }

  /// 同じ街のクラブか。
  ///
  /// リーグの名簿は固定なので、IDの末尾が隣り合うクラブを同郷とみなす。
  /// 保存もせず、毎回同じ相手が「ダービー」になる。
  static bool _isDerby(Club a, Club b) {
    if (a.countryId != b.countryId || a.tier != b.tier) return false;
    final left = _indexOf(a.id);
    final right = _indexOf(b.id);
    if (left < 0 || right < 0) return false;
    return (left ~/ 2) == (right ~/ 2);
  }

  static int _indexOf(String id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    return match == null ? -1 : int.parse(match.group(1)!);
  }

  static bool _isDefender(Position position) =>
      position == Position.gk ||
      position == Position.cb ||
      position == Position.sb;

  static NewsItem _match(
    CareerState s,
    int matchday,
    String headline,
    String body,
  ) => NewsItem(
    year: s.year,
    matchday: matchday,
    kind: NewsKind.match,
    headline: headline,
    body: body,
  );

  static NewsItem _milestone(
    CareerState s,
    int matchday,
    String headline,
    String body,
  ) => NewsItem(
    year: s.year,
    matchday: matchday,
    kind: NewsKind.milestone,
    headline: headline,
    body: body,
  );

  static NewsItem _club(CareerState s, String headline, String body) =>
      NewsItem(
        year: s.year,
        matchday: 0,
        kind: NewsKind.club,
        headline: headline,
        body: body,
      );

  /// 退場。次の試合に出られないことまで書く。
  static NewsItem sentOff(CareerState state, MatchResult result) => NewsItem(
    year: state.year,
    matchday: result.matchday,
    kind: NewsKind.match,
    headline: tr('${state.player.name}が退場', '${state.player.name} is sent off'),
    body:
        tr('${result.opponentName}戦で退場を命じられた。'
        '次の${Formulas.banForRedCard}試合は出られない。', 'Sent off against ${result.opponentName}. He misses the next ${Formulas.banForRedCard} match(es).'),
  );

  /// ピッチの外の出来事のうち、世の中に出るもの。
  ///
  /// 出来事は33種あって毎季何度も起きるのに、**見出しには一度も残らなかった**
  /// （`NewsKind.life` を使っていたのはスタッフ解散だけ）。
  /// このゲームの肝は「自分のしたことが世界に映り返ってくる」ことなので、
  /// 腕章・スポンサー・財団のような**外から見える節目だけ**を記事にする。
  /// 全部の出来事に見出しを付けると、どれも記事に見えなくなる。
  static NewsItem? lifeMoment(CareerState state, LifeSpecial special) {
    final name = state.player.name;
    return switch (special) {
      LifeSpecial.takeCaptain => _life(
        state,
        tr('$nameが${state.club.name}のキャプテンに', '$name is named captain of ${state.club.name}'),
        tr('監督とロッカールームの両方に認められた。腕章は移籍すれば外れる。', 'The manager and the dressing room both backed him. The armband comes off if he moves.'),
      ),
      LifeSpecial.acceptSponsor =>
        state.sponsor == null
            ? null
            : _life(
                state,
                tr('$nameが${state.sponsor!.name}と契約', '$name signs with ${state.sponsor!.name}'),
                tr('年${state.sponsor!.annual}万円。'
                    '${state.sponsor!.years}年の契約になる。', 'JPY ${(state.sponsor!.annual / 100).toStringAsFixed(1)}M a year, over ${plural(state.sponsor!.years, 'year')}.'),
              ),
      LifeSpecial.foundCharity => _life(
        state,
        tr('$nameが財団を立ち上げる', '$name sets up a foundation'),
        tr('ピッチの外での顔ができた。', 'He now has a face off the pitch.'),
      ),
      // 断った話は世の中に出ない。
      LifeSpecial.declineSponsor ||
      LifeSpecial.declineCaptain ||
      LifeSpecial.none => null,
    };
  }

  static NewsItem _life(CareerState s, String headline, String body) =>
      NewsItem(
        year: s.year,
        matchday: s.matchday,
        kind: NewsKind.life,
        headline: headline,
        body: body,
      );

  /// カップ戦の1試合を記事にする。
  ///
  /// **毎試合は書かない。** 勝ち上がりが決まった試合と、敗れた試合だけ。
  /// グループの1試合ごとに見出しを出すと、記録タブがカップで埋まる。
  static List<NewsItem> afterCup(
    CareerState state,
    CupRun run,
    CupTie tie,
    MatchResult result,
  ) {
    final name = state.player.name;
    if (run.won) {
      return [
        NewsItem(
          year: state.year,
          matchday: state.matchday,
          kind: NewsKind.club,
          headline: tr('${state.club.name}、${tie.kind.label}優勝', '${state.club.name} win the ${tie.kind.label}'),
          body:
              tr('${tie.opponentName}を破った。'
              '${result.goals > 0 ? '$nameが決勝の舞台で${result.goals}点。' : ''}', 'They beat ${tie.opponentName}. ${result.goals > 0 ? '$name scored ${result.goals} on the big stage.' : ''}'),
        ),
      ];
    }
    if (run.eliminated) {
      return [
        NewsItem(
          year: state.year,
          matchday: state.matchday,
          kind: NewsKind.club,
          headline: tie.round == CupRound.finalRound
              ? tr('${state.club.name}、${tie.kind.label}決勝で敗れる', '${state.club.name} lose the ${tie.kind.label} final')
              : tr('${state.club.name}、${tie.kind.label}${tie.round.label}で敗退', '${state.club.name} go out of the ${tie.kind.label} in the ${tie.round.label}'),
          body:
              tr('${tie.opponentName}に屈した。'
              '${result.appearance == Appearance.benched ? '$nameはベンチから見ていた。' : ''}', 'They fell to ${tie.opponentName}. ${result.appearance == Appearance.benched ? '$name watched from the bench.' : ''}'),
        ),
      ];
    }
    return const [];
  }

  /// コツを掴んだことを世に出す。
  ///
  /// 20年やってきたことが、最後に1つだけ性質になった瞬間。
  static NewsItem knackLearned(CareerState state, Trait trait) => NewsItem(
    year: state.year,
    matchday: state.matchday,
    kind: NewsKind.milestone,
    headline: tr('${state.player.name}、${trait.label}の域に', '${state.player.name} has grown into ${trait.label}'),
    body:
        tr('${trait.description}。'
        '長く同じ場面で勝負してきたことが、形になった。', '${trait.description}. Years in the same situations have taken shape.'),
  );

  /// 監督に約束したことを世に出す。
  ///
  /// 口にした瞬間に逃げ道が消えるのが、この機能の要。
  /// 胸の内に留めておけるなら、それは約束ではない。
  static NewsItem promiseMade(CareerState state, ManagerPromise promise) =>
      NewsItem(
        year: state.year,
        matchday: state.matchday,
        kind: NewsKind.club,
        headline: tr('${state.player.name}、${promise.label}を公言', '${state.player.name} promises ${promise.label}'),
        body:
            tr('「${promise.label}。それが自分の仕事だ」'
            '${state.manager?.name ?? '監督'}の前で言い切った。', 'He said it to ${state.manager?.name ?? 'the manager'}: that ${promise.label} is his job.'),
      );

  /// シーズンの終わりに、その約束がどうなったかを書く。
  static NewsItem promiseSettled(CareerState state) {
    final promise = state.promise!;
    final kept = promise.achievedBy(state.seasonStats);
    final reached = promise.kind == PromiseKind.rating
        ? promise.reached(state.seasonStats).toStringAsFixed(2)
        : promise.reached(state.seasonStats).round().toString();
    return NewsItem(
      year: state.year,
      matchday: state.fixtures.length,
      kind: NewsKind.club,
      headline: kept
          ? tr('${state.player.name}、公言どおり${promise.label}を達成', '${state.player.name} delivers ${promise.label} as promised')
          : tr('${state.player.name}、${promise.label}に届かず', '${state.player.name} falls short of ${promise.label}'),
      body: kept ? tr('$reached。言ったことをやってみせた。', '$reached. He did what he said he would.') : tr('$reached で終えた。言葉の重さだけが残る。', '$reached in the end. Only the weight of the words is left.'),
    );
  }

  /// 貯蓄が尽きて専属スタッフが離れたことを知らせる。
  ///
  /// これまで黙って全員が消えていた。次のシーズンから練習の効きが
  /// 落ちるのに、理由がどこにも出ていなかった。
  static NewsItem staffDismissed(CareerState state) => NewsItem(
    year: state.year,
    matchday: 0,
    kind: NewsKind.life,
    headline: tr('${state.player.name}、専属スタッフとの契約を打ち切り', '${state.player.name} lets his personal staff go'),
    body: tr('貯蓄が尽きた。練習の効きは元に戻る。', 'The savings ran out. Training goes back to normal.'),
  );

  static NewsItem _national(
    CareerState s,
    int matchday,
    String headline,
    String body,
  ) => NewsItem(
    year: s.year,
    matchday: matchday,
    kind: NewsKind.national,
    headline: headline,
    body: body,
  );

  static NewsItem _transfer(CareerState s, String headline, String body) =>
      NewsItem(
        year: s.year,
        matchday: 0,
        kind: NewsKind.transfer,
        headline: headline,
        body: body,
      );

  static String _money(int value) =>
      value >= 10000 ? tr('${(value / 10000).toStringAsFixed(1)}億円', 'JPY ${(value / 100).toStringAsFixed(1)}M') : tr('$value万円', 'JPY ${(value / 100).toStringAsFixed(1)}M');
}

/// 得点ランキングの1人。
class Scorer {
  const Scorer({
    required this.name,
    required this.clubName,
    required this.goals,
    this.isPlayer = false,
  });

  final String name;
  final String clubName;
  final int goals;

  /// 自分かどうか。
  final bool isPlayer;
}

/// リーグの得点ランキング。
///
/// 他クラブの選手を1人ずつ持つとデータが重くなるので、クラブごとに
/// 「点を取る選手」を1人だけ、IDから決めて置く。保存はしない。
/// 節が進むと積み上がり、実行しても毎回同じ数字になる。
class ScorerRace {
  const ScorerRace._();

  /// 順位表。自分を含めて、上から [take] 人。
  static List<Scorer> table(CareerState state, {int take = 6}) {
    final played = state.leagueResults.length;
    final scorers = <Scorer>[
      for (final club in state.league)
        if (club.id != state.club.id)
          Scorer(
            // **そのクラブに実際に居る選手の名前。**
            // 以前は名前の一覧からIDで1つ引いていたので、
            // 得点王レースに出てくる相手と、移籍先に居る選手が
            // 別の世界の人だった。
            name: Squad.of(club, year: state.year).topScorer.name,
            clubName: club.name,
            goals: _goalsFor(club, played),
          ),
      Scorer(
        name: state.player.name,
        clubName: state.club.name,
        goals: state.seasonStats.goals,
        isPlayer: true,
      ),
    ]..sort((a, b) => b.goals.compareTo(a.goals));

    final top = scorers.take(take).toList();
    // 自分が圏外なら、最後に付け足して見せる。
    if (!top.any((s) => s.isPlayer)) {
      top.add(scorers.firstWhere((s) => s.isPlayer));
    }
    return top;
  }

  /// 自分の順位（1始まり）。
  static int rankOf(CareerState state) {
    final all = table(state, take: 999);
    return all.indexWhere((s) => s.isPlayer) + 1;
  }

  /// シーズンの終盤で、得点王に手が届くならその一言。
  ///
  /// これまで得点ランキングは**他人の数字を眺めるだけ**で、
  /// 自分がどこにいるかも、届くかどうかも出ていなかった
  /// （`rankOf` はどこからも呼ばれていなかった）。
  /// 終盤の1本が「得点王への1本」になる。
  static String? chaseFor(CareerState state) {
    // 序盤に出しても意味が無い。残り10節を切ってから。
    final left = state.fixtures.length - state.leagueResults.length;
    if (left > 10 || left <= 0) return null;

    final all = table(state, take: 999);
    final me = all.firstWhere((s) => s.isPlayer);
    if (me.goals == 0) return null;
    final rank = all.indexWhere((s) => s.isPlayer) + 1;
    if (rank == 1) return tr('得点王を走っている（${me.goals}点）', 'Leading the scoring charts (${me.goals})');
    final gap = all.first.goals - me.goals;
    // 残り試合で届かない差なら、煽らない。
    if (gap > left) return null;
    return tr('得点王まであと$gap点（いま$rank位）', '$gap behind the top scorer (currently #$rank)');
  }

  /// そのクラブのエースが、その時点までに決めている数。
  static int _goalsFor(Club club, int matchdays) {
    final random = Random(_seed(club.id));
    // 強いクラブほど点を取る選手がいる。1試合あたり0.2〜0.7点。
    final rate = (0.2 + (club.strength - 55) / 90).clamp(0.15, 0.7);
    var goals = 0;
    for (var i = 0; i < matchdays; i++) {
      if (random.nextDouble() < rate) goals++;
      // たまに複数得点。
      if (random.nextDouble() < rate * 0.18) goals++;
    }
    return goals;
  }

  static int _seed(String id) =>
      id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x3fffffff);
}
