import 'dart:math';

import 'formulas.dart';
import '../models/career.dart';
import '../models/club.dart';
import '../models/life_event.dart';
import '../models/news.dart';
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
    final former =
        state.history.any((h) => h.clubName == result.opponentName);

    // --- 目立った出来事 ---
    if (result.goals >= 3) {
      items.add(_match(state, day, '$nameがハットトリック',
          '${result.opponentName}戦で3ゴール。${result.scoreLine}。'));
    } else if (former && result.goals > 0) {
      items.add(_match(state, day, '$nameが古巣に牙を剥く',
          'かつての本拠地で${result.goals}ゴール。${result.scoreLine}。'));
    } else if (result.goals == 2) {
      items.add(_match(state, day, '$nameが2ゴール',
          '${result.opponentName}戦を決定づけた。'));
    } else if (result.goals == 1 &&
        result.won &&
        result.scored - result.conceded == 1) {
      items.add(_match(state, day, '$nameの1点が決勝点',
          '${result.opponentName}戦、${result.scoreLine}。'));
    } else if (rating != null &&
        rating >= 8.2 &&
        !_recentlySaid(state, day, _praises, (v) => '$name$v')) {
      items.add(_match(state, day, _praise(state, day, name),
          '${result.opponentName}戦で評価点${rating.toStringAsFixed(1)}。'));
    } else if (rating != null &&
        rating <= 5.2 &&
        !_recentlySaid(state, day, _criticisms, (v) => '$name$v')) {
      items.add(_match(state, day, _criticism(state, day, name),
          '${result.opponentName}戦は評価点${rating.toStringAsFixed(1)}に終わった。'));
    } else if (result.conceded == 0 &&
        result.appearance != Appearance.benched &&
        _isDefender(state.player.position)) {
      items.add(_match(state, day, '$nameを軸に完封',
          '${result.opponentName}戦を無失点で終えた。'));
    } else if (result.conceded >= 4 &&
        !_recentlySaid(
            state, day, _collapses, (v) => '${state.club.name}$v')) {
      items.add(_match(
          state,
          day,
          _vary(state, day, _collapses, (v) => '${state.club.name}$v'),
          '${result.opponentName}に${result.conceded}失点。'));
    } else if (result.won &&
        result.scored - result.conceded >= 3 &&
        !_recentlySaid(state, day, _routs, (v) => '${state.club.name}$v')) {
      items.add(_match(
          state,
          day,
          _vary(state, day, _routs, (v) => '${state.club.name}$v'),
          '${result.opponentName}を${result.scoreLine}で退けた。'));
    }

    // --- 節目 ---
    items.addAll(_milestones(state, result));
    return items;
  }

  static const List<String> _praises = [
    '、文句なしの出来',
    'が試合を支配した',
    'に称賛の声',
    'の一挙手一投足に沸いた',
    'が違いを見せた',
    'に地元紙も最高点',
    'の一日だった',
    'を止められる者がいなかった',
  ];

  static const List<String> _criticisms = [
    '、精彩を欠く',
    'は最後まで流れに入れず',
    'に厳しい採点',
    'の不調が続く',
    'は影が薄かった',
    'に立て直しを求める声',
    'は何も起こせず',
    'に地元紙が苦言',
  ];

  static const List<String> _collapses = [
    '、守備が崩壊',
    'の守りが持たなかった',
    '、後ろから崩される',
    'の最終ラインが機能せず',
  ];

  static const List<String> _routs = [
    'が快勝',
    'が押し切った',
    'が力の差を見せた',
    'が危なげなく勝ち切る',
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
    List<String> variants,
    String Function(String) build,
  ) {
    final lines = {for (final v in variants) build(v)};
    return state.news.any((n) =>
        n.year == state.year &&
        matchday - n.matchday < sameKindGap &&
        lines.contains(n.headline));
  }

  /// 見出しの言い回しを選ぶ。**すでに出ている見出しは避ける。**
  ///
  /// 節番号だけで選んでいた頃は、4節ごとに同じ文が回ってきて、
  /// 記録タブに「◯◯に称賛の声」が並んだ（13本中7本が重複していた）。
  /// 乱数は持たない——同じ状態からは必ず同じ文が出る、という性質は残す。
  static String _vary(
    CareerState state,
    int matchday,
    List<String> variants,
    String Function(String) build,
  ) {
    final used = state.news.map((n) => n.headline).toSet();
    for (var i = 0; i < variants.length; i++) {
      final line = build(variants[(matchday + i) % variants.length]);
      if (!used.contains(line)) return line;
    }
    // 全部出尽くしたら、節で選んだものに戻る。
    return build(variants[matchday % variants.length]);
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
    final played = result.appearance == Appearance.start ||
        result.appearance == Appearance.sub;
    if (!played) return items;

    final day = result.matchday;
    final before = totals.appearances - 1;
    for (final mark in const [1, 50, 100, 200, 300, 400, 500]) {
      if (before < mark && totals.appearances >= mark) {
        items.add(_milestone(
          state,
          day,
          mark == 1 ? '$nameがプロデビュー' : '$nameが通算$mark試合',
          mark == 1
              ? '${state.club.name}の一員として、初めてピッチに立った。'
              : '${state.player.age}歳での到達。',
        ));
      }
    }

    if (result.goals > 0) {
      final beforeGoals = totals.goals - result.goals;
      for (final mark in const [1, 25, 50, 100, 150, 200]) {
        if (beforeGoals < mark && totals.goals >= mark) {
          items.add(_milestone(
            state,
            day,
            mark == 1 ? '$nameが記念すべき初ゴール' : '$nameが通算$markゴール',
            '${result.opponentName}戦での一撃だった。',
          ));
        }
      }
    }

    if (result.international) {
      for (final mark in const [1, 25, 50, 100]) {
        if (state.caps == mark) {
          items.add(_national(
            state,
            day,
            mark == 1 ? '$nameが代表デビュー' : '$nameが代表$markキャップ',
            mark == 1 ? '呼ばれるだけでは終わらなかった。' : '',
          ));
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
      items.add(_club(state, '${state.club.name}がリーグ優勝',
          '$nameは${stats.appearances}試合${stats.goals}ゴールで貢献した。'));
    }
    if (promoted) {
      items.add(_club(state, '${state.club.name}が昇格',
          '来季は${state.club.tier - 1}部で戦う。'));
    }
    if (relegated) {
      items.add(_club(state, '${state.club.name}が降格',
          '$nameの去就に注目が集まる。'));
    }
    if (stats.appearances >= 20 && stats.averageRating >= 7.4) {
      items.add(_milestone(state, 0, '$name、自己最高のシーズン',
          '${stats.appearances}試合で平均評価${stats.averageRating.toStringAsFixed(2)}。'));
    }
    if (stats.appearances <= 5) {
      items.add(_club(state, '$name、出番のないまま1年',
          '今季の出場は${stats.appearances}試合にとどまった。'));
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
      return _transfer(state, '$nameが$toClubと契約を更新',
          '${state.contractYears}年の新しい契約になった。');
    }
    if (loan) {
      return _transfer(
          state, '$nameが$toClubへ期限付き移籍', '出場機会を求めての1年になる。');
    }
    return _transfer(
      state,
      '$nameが$toClubへ移籍',
      fee > 0 ? '移籍金は${_money(fee)}と伝えられている。' : '',
    );
  }

  /// 次の試合が持つ意味。順位表とクラブの関係から決まる。
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
          CareerState s, int matchday, String headline, String body) =>
      NewsItem(
          year: s.year,
          matchday: matchday,
          kind: NewsKind.match,
          headline: headline,
          body: body);

  static NewsItem _milestone(
          CareerState s, int matchday, String headline, String body) =>
      NewsItem(
          year: s.year,
          matchday: matchday,
          kind: NewsKind.milestone,
          headline: headline,
          body: body);

  static NewsItem _club(CareerState s, String headline, String body) =>
      NewsItem(
          year: s.year,
          matchday: 0,
          kind: NewsKind.club,
          headline: headline,
          body: body);

  /// 退場。次の試合に出られないことまで書く。
  static NewsItem sentOff(CareerState state, MatchResult result) => NewsItem(
        year: state.year,
        matchday: result.matchday,
        kind: NewsKind.match,
        headline: '${state.player.name}が退場',
        body: '${result.opponentName}戦で退場を命じられた。'
            '次の${Formulas.banForRedCard}試合は出られない。',
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
          '$nameが${state.club.name}のキャプテンに',
          '監督とロッカールームの両方に認められた。腕章は移籍すれば外れる。'),
      LifeSpecial.acceptSponsor => state.sponsor == null
          ? null
          : _life(
              state,
              '$nameが${state.sponsor!.name}と契約',
              '年${state.sponsor!.annual}万円。'
                  '${state.sponsor!.years}年の契約になる。'),
      LifeSpecial.foundCharity => _life(
          state, '$nameが財団を立ち上げる', 'ピッチの外での顔ができた。'),
      // 断った話は世の中に出ない。
      LifeSpecial.declineSponsor ||
      LifeSpecial.declineCaptain ||
      LifeSpecial.none =>
        null,
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

  /// 貯蓄が尽きて専属スタッフが離れたことを知らせる。
  ///
  /// これまで黙って全員が消えていた。次のシーズンから練習の効きが
  /// 落ちるのに、理由がどこにも出ていなかった。
  static NewsItem staffDismissed(CareerState state) => NewsItem(
        year: state.year,
        matchday: 0,
        kind: NewsKind.life,
        headline: '${state.player.name}、専属スタッフとの契約を打ち切り',
        body: '貯蓄が尽きた。練習の効きは元に戻る。',
      );

  static NewsItem _national(
          CareerState s, int matchday, String headline, String body) =>
      NewsItem(
          year: s.year,
          matchday: matchday,
          kind: NewsKind.national,
          headline: headline,
          body: body);

  static NewsItem _transfer(CareerState s, String headline, String body) =>
      NewsItem(
          year: s.year,
          matchday: 0,
          kind: NewsKind.transfer,
          headline: headline,
          body: body);

  static String _money(int value) => value >= 10000
      ? '${(value / 10000).toStringAsFixed(1)}億円'
      : '$value万円';
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

  static const List<String> _names = [
    'ルイス・カルモナ', '沢渡 玲司', 'オマール・ベンサイド', 'ヤン・コヴァル',
    'ディエゴ・ロメロ', '結城 隼人', 'マティアス・ケラー', 'サム・アディヤ',
    'ラウル・ナバス', '桐生 湊', 'アンドレス・ピント', 'ヨナス・ヴィーク',
    'イリヤ・ソローキン', '真柴 篤', 'ファン・デル・メイ', 'カルロ・ベルティ',
    'エミル・ラーション', '南雲 廉', 'タデウス・ノヴァク', 'ジョアン・シルヴァ',
    'ミゲル・アロンソ', '早乙女 匠', 'ペーター・ハウゼン', 'ニコラ・ミラン',
  ];

  /// 順位表。自分を含めて、上から [take] 人。
  static List<Scorer> table(CareerState state, {int take = 6}) {
    final played = state.leagueResults.length;
    final scorers = <Scorer>[
      for (final club in state.league)
        if (club.id != state.club.id)
          Scorer(
            name: _nameFor(club),
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

  static String _nameFor(Club club) =>
      _names[_seed(club.id) % _names.length];

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
