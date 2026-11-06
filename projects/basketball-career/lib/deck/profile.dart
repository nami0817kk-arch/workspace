/// シーズンをまたいで残るもの: 記録・実績・解放したカードと仲間・難しさ。
library;

import 'battle.dart';
import 'run.dart';

class Achievement {
  const Achievement(this.id, this.title, this.text, {this.cards = const [], this.mates = const []});
  final String id;
  final String title;

  /// 条件。
  final String text;

  /// 解放されるカード・仲間。
  final List<String> cards;
  final List<String> mates;

  String get rewardText {
    final parts = <String>[];
    if (cards.isNotEmpty) parts.add('カード ${cards.length}枚');
    if (mates.isNotEmpty) parts.add('仲間 ${mates.length}人');
    return parts.isEmpty ? '' : '${parts.join('・')}が出るようになる';
  }
}

const allAchievements = <Achievement>[
  Achievement('firstWin', 'はじめての勝利', '試合に1回勝つ', cards: ['alleyoop']),
  Achievement('stage1', '県大会へ', '地区予選で優勝する', cards: ['buzzer']),
  Achievement('stage2', '全国大会へ', '県大会で優勝する', cards: ['deepthree'], mates: ['ace']),
  Achievement('champion', '日本一', '全国大会で優勝する', cards: ['clutch'], mates: ['closer']),
  Achievement('bigWin', '大差の勝利', '30点差以上で勝つ', mates: ['captain']),
  Achievement('fullTeam', '5人そろった', '仲間を5人そろえる', cards: ['timeout']),
  Achievement('hundred', '100点ゲーム', '1試合で100点取る'),
  Achievement('shutout', '完封のクォーター', '相手を0点に抑えたまま1試合に4ラウンド以上'),
  Achievement('comeback', '大逆転', '第4クォーターに入るときに10点以上負けていて、勝つ'),
  Achievement('hard5', '難しさ5で日本一', '難しさ5以上で全国大会に優勝する'),
];

final achievementById = {for (final a in allAchievements) a.id: a};

/// 最初は出ないカード・仲間(実績で解放)。
Set<String> get lockableCards => {for (final a in allAchievements) ...a.cards};
Set<String> get lockableMates => {for (final a in allAchievements) ...a.mates};

const maxDifficulty = 10;

class Profile {
  Profile();

  final unlocked = <String>{};
  int seasons = 0;
  int championships = 0;
  int gamesWon = 0;
  int gamesLost = 0;

  /// 一番遠くまで行った大会(0〜2)。優勝したら3。
  int bestStage = 0;

  /// 選べる難しさの上限(優勝した難しさ+1)。
  int maxUnlockedDifficulty = 0;
  int bestScore = 0;

  /// デッキに入れたことのあるカード(図鑑)。
  final seenCards = <String>{};

  Set<String> get lockedCards => lockableCards.difference({
        for (final id in unlocked) ...achievementById[id]?.cards ?? const <String>[],
      });
  Set<String> get lockedMates => lockableMates.difference({
        for (final id in unlocked) ...achievementById[id]?.mates ?? const <String>[],
      });

  /// 実績を解放する。新しく解放したものだけを返す。
  List<Achievement> _unlock(Iterable<String> ids) {
    final out = <Achievement>[];
    for (final id in ids) {
      if (unlocked.add(id)) out.add(achievementById[id]!);
    }
    return out;
  }

  /// 試合が終わったときに呼ぶ。
  List<Achievement> recordBattle(Battle b, RunState r) {
    if (b.won) {
      gamesWon++;
    } else {
      gamesLost++;
    }
    if (b.mine > bestScore) bestScore = b.mine;
    final ids = <String>[];
    if (b.won) {
      ids.add('firstWin');
      if (b.mine - b.theirs >= 30) ids.add('bigWin');
      if (b.rounds.length >= 6) {
        var mine = 0, theirs = 0;
        for (final s in b.rounds.take(6)) {
          mine += s.mine;
          theirs += s.theirs;
        }
        if (theirs - mine >= 10) ids.add('comeback');
      }
    }
    if (b.mine >= 100) ids.add('hundred');
    if (b.rounds.where((s) => s.theirs == 0).length >= 4) ids.add('shutout');
    return _unlock(ids);
  }

  /// 局面が進んだときに呼ぶ(大会の優勝・仲間の数・カードの記録)。
  List<Achievement> recordProgress(RunState r) {
    seenCards.addAll(r.deck.map((c) => c.def.id));
    final reached = r.champion ? 3 : r.stage;
    if (reached > bestStage) bestStage = reached;
    final ids = <String>[
      if (r.stage >= 1 || r.champion) 'stage1',
      if (r.stage >= 2 || r.champion) 'stage2',
      if (r.champion) 'champion',
      if (r.champion && r.difficulty >= 5) 'hard5',
      if (r.mates.length >= 5) 'fullTeam',
    ];
    return _unlock(ids);
  }

  /// シーズンが終わったときに呼ぶ(1シーズンにつき1回)。
  void recordSeasonEnd(RunState r) {
    seasons++;
    if (r.champion) {
      championships++;
      if (r.difficulty >= maxUnlockedDifficulty && maxUnlockedDifficulty < maxDifficulty) {
        maxUnlockedDifficulty = r.difficulty + 1;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'unlocked': unlocked.toList(),
        'seasons': seasons,
        'champs': championships,
        'won': gamesWon,
        'lost': gamesLost,
        'bestStage': bestStage,
        'maxDif': maxUnlockedDifficulty,
        'bestScore': bestScore,
        'seen': seenCards.toList(),
      };

  static Profile fromJson(Object? raw) {
    final p = Profile();
    if (raw is! Map) return p;
    int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
    p.unlocked.addAll(((raw['unlocked'] as List?) ?? const []).whereType<String>().where(achievementById.containsKey));
    p.seasons = n('seasons');
    p.championships = n('champs');
    p.gamesWon = n('won');
    p.gamesLost = n('lost');
    p.bestStage = n('bestStage').clamp(0, 3);
    p.maxUnlockedDifficulty = n('maxDif').clamp(0, maxDifficulty);
    p.bestScore = n('bestScore');
    p.seenCards.addAll(((raw['seen'] as List?) ?? const []).whereType<String>());
    return p;
  }
}
