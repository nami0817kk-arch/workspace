import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../deck/battle.dart';
import '../deck/cards.dart';
import '../deck/mates.dart';
import '../deck/profile.dart';
import '../deck/run.dart';
import '../monetization/monetization.dart';

/// 画面とシーズンの間を取り持つ。保存・記録・広告の番もここで扱う(画面が閉じられていても受け取れるように)。
class DeckController extends ChangeNotifier {
  DeckController({this.money, SharedPreferences? prefs, Random? seedSource})
      : _seeds = seedSource ?? Random(),
        _sp = prefs;

  final Monetization? money;
  SharedPreferences? _sp;
  final Random _seeds;

  static const _runKey = 'deckRun';
  static const _profileKey = 'deckProfile';
  static const _howtoKey = 'deckHowtoSeen';

  Profile profile = Profile();
  RunState? run;

  /// 新しく解放した実績(画面がダイアログで見せて消す)。
  final pending = <Achievement>[];

  /// 「広告を消す」の案内を出す番(全画面広告のあと、ときどき)。
  bool offerRemoveAds = false;

  /// 動画を待っている間(ボタンを止める)。
  bool busy = false;

  /// はじめの画面を出しているか(起動したときは、続きがあってもはじめの画面から)。
  bool atHome = true;

  void goHome() {
    atHome = true;
    notifyListeners();
  }

  void resume() {
    if (run == null) return;
    atHome = false;
    notifyListeners();
  }

  bool get howtoSeen => _sp?.getBool(_howtoKey) ?? false;

  Future<void> markHowtoSeen() async {
    await _sp?.setBool(_howtoKey, true);
    notifyListeners();
  }

  /// 保存を読み込む。続きがあれば true。
  ///
  /// 読むのは最初の1回だけ。読む前に手元で始めた・変えたもの(テストや掲載画像の生成器が作った局面)は上書きしない。
  Future<bool> load() async {
    _sp ??= await SharedPreferences.getInstance();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final p = _sp!;
      final ps = p.getString(_profileKey);
      if (ps != null && !_dirty) {
        try {
          profile = Profile.fromJson(jsonDecode(ps));
        } catch (_) {}
      }
      final rs = p.getString(_runKey);
      if (rs != null && run == null && !_dirty) {
        try {
          run = RunState.fromJson(jsonDecode(rs));
        } catch (_) {
          run = null;
        }
      }
    }
    notifyListeners();
    return run != null;
  }

  bool _loadedOnce = false;
  bool _dirty = false;

  Future<void> _save() async {
    final p = _sp;
    if (p == null) return;
    await p.setString(_profileKey, jsonEncode(profile.toJson()));
    final r = run;
    if (r == null) {
      await p.remove(_runKey);
    } else {
      await p.setString(_runKey, jsonEncode(r.toJson()));
    }
  }

  void _changed() {
    _dirty = true;
    notifyListeners();
    _save();
  }

  /// 新しいシーズンを始める。
  void newRun({int difficulty = 0}) {
    final d = difficulty.clamp(0, profile.maxUnlockedDifficulty);
    run = RunState(
      seed: _seeds.nextInt(0x7fffffff),
      difficulty: d,
      lockedCards: profile.lockedCards,
      lockedMates: profile.lockedMates,
    );
    atHome = false;
    _changed();
  }

  /// シーズンを閉じて、はじめの画面へ。終わったシーズンはここで数える(やり直しで二重に数えない)。
  void closeRun() {
    final r = run;
    if (r != null && r.over) profile.recordSeasonEnd(r);
    run = null;
    atHome = true;
    _changed();
  }

  /// 行き先を選ぶ。全画面広告の番なら、その前に出す。
  Future<void> choose(NodeType t) async {
    final r = run;
    if (r == null || r.phase != Phase.map || busy) return;
    final m = money;
    if (m != null && m.interstitialDue) {
      busy = true;
      notifyListeners();
      try {
        final shown = await m.beforeAction();
        if (shown && m.removeAdsOfferDue) {
          offerRemoveAds = (await m.canBuy) && await m.price != null;
          await m.markRemoveAdsOffered();
        }
      } catch (_) {
      } finally {
        busy = false;
      }
    }
    r.choose(t);
    _record(r);
    _changed();
  }

  void play(CardInstance c) {
    final b = run?.battle;
    if (b == null || !b.play(c)) return;
    notifyListeners();
  }

  void endRound() {
    final b = run?.battle;
    if (b == null || b.over) return;
    b.endRound();
    notifyListeners();
  }

  /// 試合の結果を見たあとに呼ぶ。
  void finishBattle() {
    final r = run;
    final b = r?.battle;
    if (r == null || b == null || !b.over) return;
    pending.addAll(profile.recordBattle(b, r));
    r.finishBattle();
    money?.tournamentPlayed();
    _record(r);
    _changed();
  }

  void _record(RunState r) => pending.addAll(profile.recordProgress(r));

  void takeReward(CardInstance? c) => _act((r) => r.takeReward(c));
  void takeMate(MateDef? m) => _act((r) => r.takeMate(m));
  void upgrade(CardInstance c) => _act((r) => r.upgrade(c));
  void rest() => _act((r) => r.rest());
  void buy(ShopItem it) => _act((r) => r.buy(it));
  void removeCard(CardInstance c) => _act((r) => r.removeCard(c));
  void leaveShop() => _act((r) => r.leaveShop());
  void resolveEvent(int i) => _act((r) => r.resolveEvent(i));

  void _act(void Function(RunState r) f) {
    final r = run;
    if (r == null || busy) return;
    f(r);
    _record(r);
    _changed();
  }

  /// 広告を消した人は、動画なしで受け取れる。
  bool get needsAd => money?.recoverNeedsAd ?? false;

  /// 動画を見て、報酬のカードを選び直す。見られなければ何も変わらない。
  Future<RecoverGate> rerollWithAd({void Function()? onWaiting}) =>
      _withAd((r) => r.phase == Phase.reward && !r.rerolled, (r) => r.rerollReward(), onWaiting);

  /// 動画を見て、決勝をやり直す(1シーズンに1回)。
  Future<RecoverGate> retryWithAd({void Function()? onWaiting}) =>
      _withAd((r) => r.canRetry, (r) => r.retryBoss(), onWaiting);

  Future<RecoverGate> _withAd(
      bool Function(RunState r) allowed, void Function(RunState r) grant, void Function()? onWaiting) async {
    final r = run;
    if (r == null || busy || !allowed(r)) return RecoverGate.unavailable;
    final m = money;
    busy = true;
    notifyListeners();
    RecoverGate gate;
    try {
      // 広告の無い環境(テスト・Web)では、タダでは受け取らせない
      gate = m == null ? RecoverGate.unavailable : await m.beforeRecover(onWaiting: onWaiting);
    } catch (_) {
      gate = RecoverGate.unavailable;
    } finally {
      busy = false;
    }
    // 受け取りは画面に依らずここで(動画の間に画面が閉じられても受け取れる。app-pitfalls #2)
    if (gate == RecoverGate.granted && run == r && allowed(r)) {
      grant(r);
    }
    _changed();
    return gate;
  }

  void dismissAchievement() {
    if (pending.isNotEmpty) pending.removeAt(0);
    notifyListeners();
  }

  void dismissRemoveAdsOffer() {
    offerRemoveAds = false;
    notifyListeners();
  }

  /// テスト用: 試合を自動で最後まで進める。
  @visibleForTesting
  Battle? get battle => run?.battle;
}
