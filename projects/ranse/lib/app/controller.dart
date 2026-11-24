import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/game.dart';
import '../engine/life_record.dart';
import '../engine/rng.dart';
import 'save.dart';

enum AppScreen { title, birth, play, dex, guide, lives }

/// 画面の切り替えと、保存・最高点の管理。
class AppController extends ChangeNotifier {
  /// [autoGuide] が真なら、初めて開いたとき（遊び方をまだ見ていなければ）に遊び方を一度だけ出す。
  /// アプリ（`RanseApp` が自分で作るとき）だけ真。テストで作る既定は偽（既存の画面のテストを止めない）。
  AppController({SaveStore? store, Rng? rng, this.autoGuide = false})
    : store = store ?? SaveStore(),
      rng = rng ?? Rng() {
    game = Game(
      rng: this.rng,
      onCheckpoint: _checkpoint,
      onChoice: (g) => unawaited(this.store.saveChoices(g)),
    )..reseedAtCheckpoint = true;
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

  /// 生まれる性別の選び（null は運に任せる。true は女、false は男）。籤を引く前にタイトルで選ぶ。
  bool? sexChoice;

  void chooseSex(bool? v) {
    sexChoice = v;
    notifyListeners();
  }

  /// 生まれの画面で籤を引き直した回数（この人生を始めるまで）。
  int redraws = 0;

  /// この人生の最期が、図鑑に初めて載ったか。
  bool newEnding = false;

  /// 図鑑に載っている最期の数。
  int dexCount = 0;
  Map<String, DexEntry> dexEntries = {};
  bool _scored = false;
  Timer? _timer;

  final bool autoGuide;
  bool _guideChecked = false;

  /// これまでの人生（新しい順）と、その件数。
  List<LifeRecord> lives = [];
  int lifeCount = 0;

  Future<void> init() async {
    hasSave = await store.hasSave();
    dexEntries = await store.dex();
    dexCount = dexEntries.length;
    lives = await store.lives();
    lifeCount = lives.length;
    if (autoGuide && !_guideChecked) {
      _guideChecked = true;
      if (screen == AppScreen.title && !await store.guideSeen()) {
        screen = AppScreen.guide;
      }
    }
    notifyListeners();
  }

  /// 遊び方を開く（タイトルの「遊び方」から）。
  void openGuide() {
    screen = AppScreen.guide;
    notifyListeners();
  }

  /// 遊び方を閉じてタイトルへ。一度見たことを残す。
  void closeGuide() {
    unawaited(store.markGuideSeen());
    screen = AppScreen.title;
    notifyListeners();
  }

  /// これまでの人生の一覧を開く。
  Future<void> openLives() async {
    lives = await store.lives();
    lifeCount = lives.length;
    screen = AppScreen.lives;
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
        birth = rollBirth(rng, asFemale: sexChoice);
        rolling = false;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// 試しに遊ぶ生まれ（`BirthSpec`）で、生まれの画面へ進む（2026-11-24、テスト用）。
  /// 画面はふつうの籤と同じ生まれの画面で、「この人生を生きる」で始まる。
  void drawCustom(BirthSpec spec) {
    _timer?.cancel();
    redraws = 0;
    rolling = false;
    birth = customBirth(rng, spec);
    screen = AppScreen.birth;
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
      // これまでの人生に一件記す（図鑑と同じ区切りで、終わった人生ごとに一度だけ）。
      // 保存を読むあいだに次の人生が始まることがあるので、記録は先にここで作る。
      final rec = LifeRecord.of(g);
      unawaited(
        store.recordLife(rec).then((n) {
          lifeCount = n;
          notifyListeners();
        }),
      );
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
