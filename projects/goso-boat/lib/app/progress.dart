import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/puzzle.dart';
import '../engine/rules.dart';

/// 舞台。名前と紹介文は lib/l10n の world{no} / intro{no}Title / intro{no}Body。
class WorldInfo {
  const WorldInfo(this.no, {this.role});
  final int no;

  /// 紹介で絵を出す役（中州の舞台は役ではなく仕掛けなので無し）。
  final Role? role;
}

const worlds = [
  WorldInfo(1, role: Role.police),
  WorldInfo(2, role: Role.chief),
  WorldInfo(3, role: Role.cuffed),
  WorldInfo(4, role: Role.boss),
  WorldInfo(5, role: Role.dog),
  WorldInfo(6),
  WorldInfo(7, role: Role.boss),
  WorldInfo(8, role: Role.chief),
];

WorldInfo worldOf(Level l) => worlds[l.world - 1];

/// 収録面の読み込み。
Future<List<Level>> loadLevels() async {
  final raw = await rootBundle.loadString('assets/levels.json');
  final data = jsonDecode(raw) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

/// 進み具合（面ごとの星と、紹介を見たか）。端末の中にだけ保存する。
class Progress extends ChangeNotifier {
  Progress._(this._prefs, this.levels);

  static Future<Progress> open(List<Level> levels) async =>
      Progress._(await SharedPreferences.getInstance(), levels);

  final SharedPreferences _prefs;

  /// テストで同じ保存先を広告の設定にも渡すため。
  @visibleForTesting
  SharedPreferences get prefsForTest => _prefs;
  final List<Level> levels;

  int stars(Level l) => _prefs.getInt('stars.${l.id}') ?? 0;
  bool cleared(Level l) => stars(l) > 0;

  /// テスト用 Web版だけ全面を最初から開ける（goso-boat-web-test.yml が
  /// `--dart-define=GOSO_UNLOCK_ALL=true` を付ける）。iOS アプリには付けない。
  static const unlockAll = bool.fromEnvironment('GOSO_UNLOCK_ALL');

  /// 舞台8「鬼門」を開くのに要る、舞台1〜7の星の数（最大306）。
  /// 前の面を星3で解き直す理由にする（2026-09-27）。
  static const nightmareStars = 200;

  int get starsBeforeNightmare => levels.where((l) => l.world < 8).fold(0, (s, l) => s + stars(l));
  bool get nightmareOpen => unlockAll || starsBeforeNightmare >= nightmareStars;

  /// 1つ前の面を解いていれば遊べる。舞台8の1面目だけは星も要る。
  bool unlocked(Level l) {
    if (unlockAll) return true;
    final i = levels.indexOf(l);
    if (i <= 0) return true;
    if (!cleared(levels[i - 1])) return false;
    if (l.world == 8 && levels[i - 1].world != 8) return nightmareOpen;
    return true;
  }

  int get totalStars => levels.fold(0, (s, l) => s + stars(l));
  int get maxStars => levels.length * 3;

  /// 「つづきから」で開く面。まだ解いていない遊べる面、なければ星3でない面、なければ最後の面。
  Level get nextLevel => levels.firstWhere(
        (l) => !cleared(l) && unlocked(l),
        orElse: () => levels.firstWhere((l) => stars(l) < 3, orElse: () => levels.last),
      );

  int get clearedCount => levels.where(cleared).length;
  int get threeStarCount => levels.where((l) => stars(l) == 3).length;

  // ---- 記録（回数） ----

  int stat(String key) => _prefs.getInt('stat.$key') ?? 0;
  Future<void> bump(String key, [int by = 1]) async {
    await _prefs.setInt('stat.$key', stat(key) + by);
  }

  // ---- 今日の1問 ----

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 今日の1問。解いたけれど星3でない面から、日付で1つ選ぶ（なければ解いた面から）。
  /// 選んだ面はその日のあいだ固定する（星3にした途端に別の面へ変わらないように）。
  Level? dailyLevel(DateTime now) {
    final key = dayKey(now);
    final saved = _prefs.getString('daily.pick.$key');
    if (saved != null) {
      for (final l in levels) {
        if (l.id == saved) return l;
      }
    }
    var pool = levels.where((l) => cleared(l) && stars(l) < 3).toList();
    if (pool.isEmpty) pool = levels.where(cleared).toList();
    if (pool.isEmpty) return null;
    final h = key.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    final pick = pool[h % pool.length];
    _prefs.setString('daily.pick.$key', pick.id);
    return pick;
  }

  bool dailyDone(DateTime now) => _prefs.getBool('daily.done.${dayKey(now)}') ?? false;

  /// 今日（済んでいなければ昨日）から遡って、続けて達成した日数。
  int dailyStreak(DateTime now) {
    var d = DateTime(now.year, now.month, now.day);
    if (!dailyDone(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (dailyDone(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 今日の1問を星3で解いたら達成にする。今回はじめて達成したときだけ true。
  Future<bool> recordDaily(Level l, int stars, DateTime now) async {
    if (stars < 3 || dailyDone(now) || dailyLevel(now) != l) return false;
    await _prefs.setBool('daily.done.${dayKey(now)}', true);
    final streak = dailyStreak(now);
    if (streak > stat('maxStreak')) await _prefs.setInt('stat.maxStreak', streak);
    notifyListeners();
    return true;
  }

  /// 自己ベスト（最少の往復回数）。まだ解いていなければ null。
  int? best(Level l) => _prefs.getInt('best.${l.id}');

  /// クリアを記録する。自己ベストを縮めたとき（前の記録があって、それより少ない）だけ true。
  Future<bool> record(Level l, int stars, {int? trips}) async {
    if (stars > this.stars(l)) await _prefs.setInt('stars.${l.id}', stars);
    var improved = false;
    if (trips != null) {
      final prev = best(l);
      if (prev == null || trips < prev) {
        await _prefs.setInt('best.${l.id}', trips);
        improved = prev != null;
      }
    }
    notifyListeners();
    return improved;
  }

  /// 評価のお願いを出してよいか。舞台の最後の面を星2つ以上で解いた直後だけ、舞台ごとに1回。
  /// （Apple 側でも年3回までに絞られる。気持ちよく解けた瞬間に出すと評価が高くなりやすい）
  bool shouldAskReview(Level l, int stars) {
    final ws = levels.where((x) => x.world == l.world);
    return stars >= 2 && ws.last == l && l.world <= 3 && !(_prefs.getBool('review.${l.world}') ?? false);
  }

  Future<void> markReviewAsked(int world) => _prefs.setBool('review.$world', true);

  /// 星・自己ベスト・紹介の既読・評価のお願い・記録・今日の1問・実績をすべて消す（設定画面の「進み具合を消す」）。
  /// 広告を消した購入と、音・振動の設定は残す。
  Future<void> resetAll() async {
    for (final k in _prefs.getKeys().toList()) {
      if (['stars.', 'best.', 'intro.', 'review.', 'stat.', 'daily.', 'ach.'].any(k.startsWith)) {
        await _prefs.remove(k);
      }
    }
    notifyListeners();
  }

  bool seenIntro(int world) => _prefs.getBool('intro.$world') ?? false;
  Future<void> markIntro(int world) => _prefs.setBool('intro.$world', true);

  // ---- 実績（lib/app/achievements.dart が条件を持つ） ----

  bool hasAchievement(String id) => _prefs.getBool('ach.$id') ?? false;
  Future<void> markAchievement(String id) => _prefs.setBool('ach.$id', true);

}
