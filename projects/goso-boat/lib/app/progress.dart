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
  final List<Level> levels;

  int stars(Level l) => _prefs.getInt('stars.${l.id}') ?? 0;
  bool cleared(Level l) => stars(l) > 0;

  /// 1つ前の面を解いていれば遊べる。
  bool unlocked(Level l) {
    final i = levels.indexOf(l);
    return i <= 0 || cleared(levels[i - 1]);
  }

  int get totalStars => levels.fold(0, (s, l) => s + stars(l));
  int get maxStars => levels.length * 3;

  /// 「つづきから」で開く面。全部解いていれば最後の面。
  Level get nextLevel => levels.firstWhere((l) => !cleared(l), orElse: () => levels.last);

  Future<void> record(Level l, int stars) async {
    if (stars > this.stars(l)) {
      await _prefs.setInt('stars.${l.id}', stars);
      notifyListeners();
    }
  }

  /// 評価のお願いを出してよいか。舞台の最後の面を星2つ以上で解いた直後だけ、舞台ごとに1回。
  /// （Apple 側でも年3回までに絞られる。気持ちよく解けた瞬間に出すと評価が高くなりやすい）
  bool shouldAskReview(Level l, int stars) {
    final ws = levels.where((x) => x.world == l.world);
    return stars >= 2 && ws.last == l && l.world <= 3 && !(_prefs.getBool('review.${l.world}') ?? false);
  }

  Future<void> markReviewAsked(int world) => _prefs.setBool('review.$world', true);

  bool seenIntro(int world) => _prefs.getBool('intro.$world') ?? false;
  Future<void> markIntro(int world) => _prefs.setBool('intro.$world', true);

  bool get soundOn => _prefs.getBool('sound') ?? true;
  Future<void> setSound(bool v) async {
    await _prefs.setBool('sound', v);
    notifyListeners();
  }
}
