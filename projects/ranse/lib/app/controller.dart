import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/game.dart';
import '../engine/rng.dart';
import 'save.dart';

enum AppScreen { title, birth, play, dex }

/// 画面の切り替えと、保存・最高点の管理。
class AppController extends ChangeNotifier {
  AppController({SaveStore? store, Rng? rng})
    : store = store ?? SaveStore(),
      rng = rng ?? Rng() {
    game = Game(rng: this.rng, onCheckpoint: _checkpoint);
  }

  final SaveStore store;
  final Rng rng;
  late final Game game;

  AppScreen screen = AppScreen.title;
  Birth? birth;

  /// 籤を引いている間（演出中）。
  bool rolling = false;
  String flick = '…';
  bool hasSave = false;

  /// 生まれの画面で籤を引き直した回数（この人生を始めるまで）。
  int redraws = 0;

  /// この人生の最期が、図鑑に初めて載ったか。
  bool newEnding = false;

  /// 図鑑に載っている最期の数。
  int dexCount = 0;
  Map<String, DexEntry> dexEntries = {};
  bool _scored = false;
  Timer? _timer;

  Future<void> init() async {
    hasSave = await store.hasSave();
    dexEntries = await store.dex();
    dexCount = dexEntries.length;
    notifyListeners();
  }

  /// 運命の籤を引く。演出のあと、生まれが決まる。
  void draw() {
    _timer?.cancel();
    // 生まれの画面から引き直したときだけ数える（タイトル・終わりの画面から引いたら0から）。
    redraws = screen == AppScreen.birth && birth != null ? redraws + 1 : 0;
    screen = AppScreen.birth;
    birth = null;
    rolling = true;
    var n = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      flick =
          '${rng.pick(kClasses).name} ／ ${rng.pick(kRegions).n}国 ／ '
          '${rng.range(1525, 1568)}年生まれ…';
      if (++n > 14) {
        t.cancel();
        birth = rollBirth(rng);
        rolling = false;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void begin() {
    final b = birth;
    if (b == null) return;
    _scored = false;
    newEnding = false;
    screen = AppScreen.play;
    game.start(b);
    notifyListeners();
  }

  Future<void> resume() async {
    if (await store.restoreInto(game)) {
      _scored = game.finished;
      screen = AppScreen.play;
    } else {
      hasSave = false;
    }
    notifyListeners();
  }

  Future<void> openDex() async {
    dexEntries = await store.dex();
    dexCount = dexEntries.length;
    screen = AppScreen.dex;
    notifyListeners();
  }

  void toTitle() {
    _timer?.cancel();
    screen = AppScreen.title;
    unawaited(init());
    notifyListeners();
  }

  void _checkpoint(Game g) {
    unawaited(store.save(g));
    if (g.finished && !_scored) {
      _scored = true;
      unawaited(
        store.recordEnding(g).then((isNew) {
          newEnding = isNew;
          if (isNew) dexCount++;
          notifyListeners();
        }),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    game.dispose();
    super.dispose();
  }
}
