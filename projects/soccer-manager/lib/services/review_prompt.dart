import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ストアの評価を、その場で頼む小さな窓（OS が出すもの）。
///
/// 公開から10日で評価が0件だった。入れるかどうか迷っている人には、星が1つも
/// 無いページは効く材料にならない。ページを見た人の14%しか入れていない。
///
/// **頼む場所を選ぶ。** 遊んでいる最中に割り込むと、むしろ悪い評価を呼ぶ。
/// シーズンを終えて、理事会の目標を達成した直後だけにしてある。
/// 区切りがついていて、かつ結果が良かった瞬間。
class ReviewPrompt {
  ReviewPrompt({InAppReview? review}) : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  /// App Store のアプリID。ストアページを開くのに要る。
  ///
  /// OS の窓（[maybeAsk]）は**出ないことがある**。Apple が年3回までに
  /// 絞っていて、こちらからは出たかどうかも分からない。「評価したい」と
  /// 思った人が自分で辿り着ける道を別に用意しておく。
  static const appStoreId = '6809834913';

  /// ストアのページを開く。評価を書きに行ってもらうための導線。
  Future<void> openStoreListing() async {
    try {
      await _review.openStoreListing(appStoreId: appStoreId);
    } catch (_) {
      // 開けなくても進行には関係ない。
    }
  }

  /// 最後に頼んだシーズン。
  static const _lastAskedSeasonKey = 'review.lastAskedSeason';

  /// これまでに頼んだ回数。
  static const _askCountKey = 'review.askCount';

  /// 前に頼んでから、次に頼むまでに空けるシーズン数。
  ///
  /// OS 側も年3回までに制限するが、こちらでも間隔を空ける。断られた相手に
  /// 毎シーズン出すのは、評価を得るどころか嫌われる。
  static const int seasonsBetweenAsks = 3;

  /// 頼む上限。これを超えたら二度と出さない。
  ///
  /// OS の窓は「出したかどうか」を教えてくれない（出ないこともある）。
  /// 何度も試すより、数回で諦めるほうが筋がよい。
  static const int maxAsks = 3;

  /// 条件が揃っていれば頼む。頼んだら true。
  ///
  /// [season] はいま終えたシーズン。[metBoardTarget] は理事会の目標を
  /// 達成したか。達成していないときは頼まない（うまくいっていない人に
  /// 評価を求めない）。
  Future<bool> maybeAsk({
    required int season,
    required bool metBoardTarget,
  }) async {
    if (!metBoardTarget) return false;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return false;
    }

    final count = prefs.getInt(_askCountKey) ?? 0;
    if (count >= maxAsks) return false;

    final last = prefs.getInt(_lastAskedSeasonKey);
    if (last != null && season - last < seasonsBetweenAsks) return false;

    try {
      if (!await _review.isAvailable()) return false;
      await _review.requestReview();
    } catch (_) {
      // 出せなくても進行には関係ない。黙って諦める。
      return false;
    }

    await prefs.setInt(_lastAskedSeasonKey, season);
    await prefs.setInt(_askCountKey, count + 1);
    return true;
  }
}
