import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/puzzle.dart';
import '../engine/rules.dart';

/// 舞台の名前と、その舞台で初めて出てくるもの。
class WorldInfo {
  const WorldInfo(this.no, this.name, this.intro);
  final int no;
  final String name;
  final Intro? intro;
}

/// 新しい役・仕掛けの紹介。舞台の1面目の前に1回だけ出す。
class Intro {
  const Intro(this.title, this.body, {this.role});
  final String title;
  final String body;
  final Role? role;
}

const worlds = [
  WorldInfo(1, '川べり', Intro('囚人を向こう岸へ', '警官や囚人をタップして舟に乗せ、「向こう岸へ」で渡す。\n岸でも舟の上でも、囚人より警官が少ないと逃げる。\n警官のいない岸に囚人を残しても逃げる。', role: Role.police)),
  WorldInfo(2, '看守長', Intro('看守長が来た', '看守長は1人で囚人2人分を見張れる。舟も漕げる。', role: Role.chief)),
  WorldInfo(3, '手錠', Intro('手錠の2人', '2人はつながっていて離れられない。見張りは2人分、舟の席も2つ使う。', role: Role.cuffed)),
  WorldInfo(4, 'ボス', Intro('ボスが来た', 'ボスは1人でも見張りが2人分いる。舟の上でも同じ。', role: Role.boss)),
  WorldInfo(5, '警察犬', Intro('警察犬が来た', '警察犬は囚人1人を見張れる。でも舟は漕げない。', role: Role.dog)),
  WorldInfo(6, '中州', Intro('川に中州がある', '舟は 手前の岸 ↔ 中州 ↔ 向こう岸 を1区間ずつ進む。\n中州に人を残すこともできる。中州でも見張りが要る。')),
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

  bool seenIntro(int world) => _prefs.getBool('intro.$world') ?? false;
  Future<void> markIntro(int world) => _prefs.setBool('intro.$world', true);

  bool get soundOn => _prefs.getBool('sound') ?? true;
  Future<void> setSound(bool v) async {
    await _prefs.setBool('sound', v);
    notifyListeners();
  }
}
