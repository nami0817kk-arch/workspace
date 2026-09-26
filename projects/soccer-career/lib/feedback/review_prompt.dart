import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/career.dart';

/// 星を頼む窓口。
///
/// iOS の評価ダイアログ（`SKStoreReviewController`）は**こちらから何回も
/// 出せるものではない**。OS が年3回までに絞り、しかも出すかどうかは OS が
/// 決める。だから「頼んだら出る」前提では書けない——頼める機会そのものを
/// 大事に使う。
abstract class ReviewService {
  Future<bool> isAvailable();

  Future<void> request();
}

/// 何もしない実装。Web とテストで使う。
class NoReviewService implements ReviewService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> request() async {}
}

class StoreReviewService implements ReviewService {
  final InAppReview _review = InAppReview.instance;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _review.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> request() async {
    try {
      await _review.requestReview();
    } catch (_) {
      // 出せなくても遊びは止めない。
    }
  }
}

/// この端末で使う実装を選ぶ。
///
/// 評価ダイアログは Android/iOS でしか出ないので、それ以外では何もしない
/// 実装を返す。**`createAdService` と同じ形**にしてある（片方だけ
/// 書き方が違うと、テストで実物が動いていることに気付けない）。
ReviewService createReviewService() {
  if (kIsWeb) return NoReviewService();
  try {
    if (Platform.isAndroid || Platform.isIOS) return StoreReviewService();
  } catch (_) {
    // テスト環境など、Platform を参照できない場合。
  }
  return NoReviewService();
}

/// いつ星を頼むかを1か所で決める。
///
/// **星が0のまま出すと、見つけてもらえても入手されない。** ストアの一覧では
/// アイコンと名前の次に星が目に入る。かといって、遊び始めた直後や負けた季に
/// 頼めば、低い星が付くだけで逆に損をする。
///
/// ここは「**頼んでよい瞬間かどうか**」だけを決める。実際に出るかどうかは
/// OS が決めるので、こちらは頼める1回を良い瞬間に使い切ることに集中する。
class ReviewPrompt extends ChangeNotifier {
  ReviewPrompt({ReviewService? service})
    : _service = service ?? createReviewService();

  static const String _askedKey = 'review.asked';

  /// これだけ季を終えるまでは頼まない。
  ///
  /// 1季目は 2部の下位で終わることが多く（実測で19位のこともある）、
  /// そこで頼んでも良い星は付かない。3季あれば昇格か代表か、
  /// 何かしら手応えのある出来事が1つは起きている。
  static const int askFromSeason = 3;

  final ReviewService _service;

  /// もう頼んだか。**頼むのはキャリアを通して1度だけ。**
  bool asked = false;

  bool initialized = false;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    asked = prefs.getBool(_askedKey) ?? false;
    initialized = true;
    notifyListeners();
  }

  /// 終わったばかりの季が「良い季」か。
  ///
  /// 監督の期待に応えた／優勝した／昇格した、のどれか。**負けた季に頼むと
  /// 低い星が付く**ので、そこは見送る（頼める回数は限られているので、
  /// 見送っても損にならない）。
  static bool isGoodSeason(CareerState state) {
    final history = state.history;
    if (history.isEmpty) return false;
    final last = history.last;
    if (last.objectiveMet || last.promiseKept) return true;
    if (last.leaguePosition == 1) return true;
    // 昇格（前の季より上の部にいる）。
    if (history.length >= 2 && last.tier < history[history.length - 2].tier) {
      return true;
    }
    return false;
  }

  /// 頼んでよい瞬間か。
  ///
  /// [adShown] は、この季の切れ目に全画面広告を出したか。**広告を閉じた
  /// 直後に星を頼むのは最悪の順番**なので、出した回は見送る。
  bool shouldAsk({
    required CareerState state,
    required bool adShown,
  }) {
    if (asked || adShown) return false;
    if (state.history.length < askFromSeason) return false;
    return isGoodSeason(state);
  }

  /// 頼める瞬間なら頼む。頼んだら true。
  Future<bool> askIfEarned({
    required CareerState state,
    required bool adShown,
  }) async {
    if (!shouldAsk(state: state, adShown: adShown)) return false;
    if (!await _service.isAvailable()) return false;
    // **先に「頼んだ」ことにする。** OS が出さなかった回も1回と数える。
    // 数えないと、出ないたびに毎季ここへ来て、いつか悪い巡り合わせで
    // 出ることになる。
    await _markAsked();
    await _service.request();
    return true;
  }

  Future<void> _markAsked() async {
    asked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
    notifyListeners();
  }
}
