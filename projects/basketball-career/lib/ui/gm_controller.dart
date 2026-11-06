import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gm/career.dart';
import '../gm/draft.dart';
import '../gm/profile.dart';
import '../gm/trade.dart';
import '../monetization/monetization.dart';

/// 画面と任期の間を取り持つ。保存・記録・広告の番もここで扱う(画面が閉じられていても受け取れるように)。
class GmController extends ChangeNotifier {
  GmController({this.money, SharedPreferences? prefs, Random? seedSource})
      : _seeds = seedSource ?? Random(),
        _sp = prefs;

  final Monetization? money;
  SharedPreferences? _sp;
  final Random _seeds;

  static const _careerKey = 'gmCareer';
  static const _profileKey = 'gmProfile';
  static const _howtoKey = 'gmHowtoSeen';

  Profile profile = Profile();
  Career? career;

  /// 新しく達成した実績(画面がダイアログで見せて消す)。
  final pending = <Achievement>[];

  /// 「広告を消す」の案内を出す番(全画面広告のあと、ときどき)。
  bool offerRemoveAds = false;

  /// 広告を待っている間(ボタンを止める)。
  bool busy = false;

  /// はじめの画面を出しているか(起動したときは、続きがあってもはじめの画面から)。
  bool atHome = true;

  void goHome() {
    atHome = true;
    notifyListeners();
  }

  void resume() {
    if (career == null) return;
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
      final cs = p.getString(_careerKey);
      if (cs != null && career == null && !_dirty) {
        try {
          career = Career.fromJson(jsonDecode(cs));
        } catch (_) {
          career = null;
        }
      }
    }
    notifyListeners();
    return career != null;
  }

  bool _loadedOnce = false;
  bool _dirty = false;

  Future<void> _save() async {
    final p = _sp;
    if (p == null) return;
    await p.setString(_profileKey, jsonEncode(profile.toJson()));
    final c = career;
    if (c == null) {
      await p.remove(_careerKey);
    } else {
      await p.setString(_careerKey, jsonEncode(c.toJson()));
    }
  }

  void _changed() {
    _dirty = true;
    notifyListeners();
    _save();
  }

  /// チームを選ぶ前に見せるリーグの種(選ぶ画面と、任されたあとで同じリーグになる)。
  int newSeed() => _seeds.nextInt(0x7fffffff);

  /// [seed] のリーグで、[team] のGMに任される。
  void newCareer(int team, {int? seed}) {
    career = Career.start(seed: seed ?? newSeed(), team: team);
    atHome = false;
    _changed();
  }

  /// 任期を閉じて、はじめの画面へ。終わった任期はここで数える。
  void closeCareer() {
    final c = career;
    if (c != null && c.phase == Phase.over) pending.addAll(profile.recordCareerEnd(c));
    career = null;
    atHome = true;
    _changed();
  }

  /// 試合を進める前に、全画面広告の番なら出す。
  Future<void> _maybeInterstitial() async {
    final m = money;
    if (m == null || !m.interstitialDue) return;
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

  void startSeason() => _act((c) => c.startSeason());

  /// 次の区切り(20〜21試合)を進める。
  Future<void> playBlock() async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy) return;
    await _maybeInterstitial();
    c.playBlock();
    await money?.tournamentPlayed();
    _record(c);
    _changed();
  }

  Future<void> playPlayoffs() async {
    final c = career;
    if (c == null || c.phase != Phase.playoffs || busy) return;
    await _maybeInterstitial();
    c.playPlayoffs();
    await money?.tournamentPlayed();
    pending.addAll(profile.recordSeason(c));
    _record(c);
    _changed();
  }

  void toOffseason() => _act((c) => c.toOffseason());
  void pickProspect(Prospect p) => _act((c) => c.pickProspect(p));
  void passPick() => _act((c) => c.passPick());
  void scoutProspect(Prospect p) => _act((c) => c.scoutProspect(p));
  void resign(int id, int years) => _act((c) => c.resign(id, years));
  void letGo(int id) => _act((c) => c.letGo(id));
  void signFreeAgent(int id, int years) => _act((c) => c.signFreeAgent(id, years));
  void release(int id) => _act((c) => c.release(id));
  void finishContracts() => _act((c) => c.finishContracts());
  void setRotation(List<int> ids) => _act((c) => c.setRotation(ids));
  void acceptIncoming() => _act((c) => c.acceptIncoming());
  void declineIncoming() => _act((c) => c.declineIncoming());

  /// トレードを申し込む。成立したら true。
  bool propose(TradeOffer o) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.propose(o);
    _record(c);
    _changed();
    return ok;
  }

  void _record(Career c) => pending.addAll(profile.recordProgress(c));

  void _act(void Function(Career c) f) {
    final c = career;
    if (c == null || busy) return;
    f(c);
    _record(c);
    _changed();
  }

  /// 広告を消した人は、動画なしで受け取れる。
  bool get needsAd => money?.recoverNeedsAd ?? false;

  /// 動画を見て、スカウトを2回増やす(ドラフトごとに1度)。
  Future<RecoverGate> scoutsWithAd({void Function()? onWaiting}) =>
      _withAd((c) => c.canAddScouts, (c) => c.addScouts(), onWaiting);

  /// 動画を見て、オーナーを説得する(解任を1度だけ取り消す)。
  Future<RecoverGate> rescueWithAd({void Function()? onWaiting}) =>
      _withAd((c) => c.canRescue, (c) => c.rescue(), onWaiting);

  Future<RecoverGate> _withAd(
      bool Function(Career c) allowed, void Function(Career c) grant, void Function()? onWaiting) async {
    final c = career;
    if (c == null || busy || !allowed(c)) return RecoverGate.unavailable;
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
    if (gate == RecoverGate.granted && career == c && allowed(c)) {
      grant(c);
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

  /// テスト・掲載画像の生成器用: 任期を差し替える。
  @visibleForTesting
  void setCareer(Career c) {
    career = c;
    atHome = false;
    _changed();
  }
}
