import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/ending.dart';
import '../engine/game.dart';
import '../engine/life.dart';
import '../engine/life_record.dart';
import '../engine/rng.dart';
import '../monetization/ad_service.dart';
import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';
import 'save.dart';

/// ビルドのときに試しの道具を入れるか（既定は入れない。入れ忘れても App Store の版に出ない側に倒す）。
const kTestTools = bool.fromEnvironment('RANSE_TEST_TOOLS');

enum AppScreen { title, birth, play, dex, guide, lives }

/// 画面の切り替えと、保存・最高点の管理。
class AppController extends ChangeNotifier {
  /// [autoGuide] が真なら、初めて開いたとき（遊び方をまだ見ていなければ）に遊び方を一度だけ出す。
  /// アプリ（`RanseApp` が自分で作るとき）だけ真。テストで作る既定は偽（既存の画面のテストを止めない）。
  AppController({
    SaveStore? store,
    Rng? rng,
    this.autoGuide = false,
    this.money,
    this.testTools = kTestTools,
  }) : store = store ?? SaveStore(),
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

  /// 試しに遊ぶための生まれの画面（題字の長押し）を開けるか。TestFlight に上げるビルドだけ真
  /// （リリースの CI が `--dart-define=RANSE_TEST_TOOLS=true` を渡す。App Store に出すビルドでは偽。2026-11-26 ユーザー決定）。
  final bool testTools;

  /// 広告と「広告を消す」（2026-11-25）。[init] で用意する（テストでは差し替えられる）。
  Monetization? money;

  bool _moneyHooked = false;

  Future<void> _startMoney() async {
    if (money == null) {
      final prefs = await SharedPreferences.getInstance();
      money ??= Monetization(
        prefs,
        ads: createAdService(),
        store: createPurchaseService(),
      );
    }
    if (!_moneyHooked) {
      _moneyHooked = true;
      money!.addListener(notifyListeners);
    }
    await money!.start();
  }

  Future<void> init() async {
    // 広告と課金の準備は待たない（失敗しても遊べるようにする）
    unawaited(_startMoney().catchError((_) {}));
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
    _snapLife = _snapWorld = null;
    _recorded = null;
    unawaited(money?.noteLifeStarted(finishedBefore: lifeCount));
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
    if (!g.finished && g.life != null) {
      // 年の始めの区切りを控える（亡くなったとき、この年の始めからやり直すため）
      _snapLife = jsonEncode(g.l.toJson());
      _snapWorld = jsonEncode(g.fa.values.map((f) => f.toJson()).toList());
      // 章の区切りに入った年なら、区切りの一行を見せてから全画面広告を出す
      if (g.chapterBegan == g.age) {
        g.chapterBegan = null;
        // 出す番のときだけ待ちの時計を置く（最初の人生・広告を消した人・間隔が足りないときは何もしない）
        if (money?.interstitialTurn ?? false) {
          money!.prepareInterstitial();
          unawaited(_chapterAd(g.l));
        }
      }
    }
    if (g.finished && !_scored) {
      _scored = true;
      money?.prepareInterstitial();
      // これまでの人生に一件記す（図鑑と同じ区切りで、終わった人生ごとに一度だけ）。
      // 保存を読むあいだに次の人生が始まることがあるので、記録は先にここで作る。
      final rec = LifeRecord.of(g);
      final key = buildEnding(g).key;
      final r = _recorded = _Recorded(rec.id, key);
      r.done = Future.wait([
        store.recordLife(rec).then((n) {
          lifeCount = n;
          notifyListeners();
        }),
        store.recordEnding(g).then((isNew) {
          r.wasNew = isNew;
          newEnding = isNew;
          if (isNew) dexCount++;
          notifyListeners();
        }),
      ]);
      unawaited(r.done);
    }
  }

  /// 章の区切りの全画面広告。区切りの一行が画面に出てから少し置いて出す（押した指が広告に当たらないように）。
  Future<void> _chapterAd(Life life) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    // そのあいだに人生が変わった・画面を離れたなら出さない
    if (screen != AppScreen.play || !identical(game.life, life) || game.finished) return;
    await money?.maybeInterstitial();
  }

  /// 「新たな生を引く」（人生の終わり）。出す番なら全画面広告を出してから籤へ。
  bool _leaving = false;
  Future<void> nextLife() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await money?.maybeInterstitial();
    } finally {
      _leaving = false;
    }
    draw();
  }

  // ---------- やり直し（2026-11-25、動画と引き換え。一つの人生に一度） ----------

  /// 亡くなった年の始めの区切り（[Life] と世の家の JSON）。
  String? _snapLife, _snapWorld;
  _Recorded? _recorded;

  /// やり直しの最中（動画を見ている・読み込んでいる）。
  bool redoing = false;

  /// 終わった人生をやり直せるか（亡くなった人生で、まだ一度もやり直していない。天下統一では出さない）。
  bool get canRedo {
    final g = game;
    if (g.life == null || !g.finished || g.l.dead == null) return false;
    if (g.l.flags.contains(Game.kRedoFlag)) return false;
    return _snapLife != null && _snapWorld != null;
  }

  /// やり直しのボタンに「動画」の印を付けるか。
  bool get redoNeedsAd => money?.redoNeedsAd ?? false;

  /// 亡くなった年の始めに戻る。広告を消した人はそのまま、それ以外は動画を1本見てから。
  /// 戻れなければ、その理由を返す（動画を最後まで見なかった・読み込めなかった）。
  Future<RedoGate> redo({void Function()? onWaiting}) async {
    if (!canRedo || redoing) return RedoGate.unavailable;
    redoing = true;
    notifyListeners();
    try {
      final m = money;
      final gate = m == null
          ? RedoGate.granted
          : await m.beforeRedo(onWaiting: onWaiting);
      if (gate != RedoGate.granted || !canRedo) return gate;
      final life = Life.fromJson(jsonDecode(_snapLife!) as Map<String, dynamic>);
      // 先に印を立てる（戻った年の始めの保存にも入り、閉じて再開しても二度目は無い）
      life.flags.add(Game.kRedoFlag);
      final world = {
        for (final e in jsonDecode(_snapWorld!) as List)
          (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
      };
      // この人生の最期は図鑑・これまでの人生に記さない（最後に迎えた最期だけを記す）
      final r = _recorded;
      _recorded = null;
      if (r != null) {
        await r.done;
        lifeCount = await store.unrecordLife(r.lifeId);
        await store.unrecordEnding(r.key, wasNew: r.wasNew);
        if (r.wasNew && dexCount > 0) dexCount--;
      }
      _scored = false;
      newEnding = false;
      // その先の運は引き直す（選択と関係ない病死などが、同じにならないように）
      game.restore(life, world, seed: rng.reseed());
      return RedoGate.granted;
    } finally {
      redoing = false;
      notifyListeners();
    }
  }

  // ---------- 広告を消す ----------

  bool get adFree => money?.adFree ?? false;

  Future<PurchaseOutcome> buyRemoveAds() async =>
      await money?.buy() ?? PurchaseOutcome.unavailable;

  Future<PurchaseOutcome> restorePurchases() async =>
      await money?.restore() ?? PurchaseOutcome.unavailable;

  @override
  void dispose() {
    if (_moneyHooked) money?.removeListener(notifyListeners);
    _timer?.cancel();
    game.dispose();
    super.dispose();
  }
}

/// 終わった人生を図鑑とこれまでの人生に記したことの控え（やり直したときに取り消すため）。
class _Recorded {
  _Recorded(this.lifeId, this.key);
  final String lifeId, key;
  bool wasNew = false;
  Future<void> done = Future.value();
}
