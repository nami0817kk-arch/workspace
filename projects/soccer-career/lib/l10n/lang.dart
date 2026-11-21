import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 画面に出す言葉の言語。
enum Lang {
  ja('日本語', 'ja'),
  en('English', 'en');

  const Lang(this.label, this.code);

  /// 切り替えの画面に出す名前。**その言語自身の呼び名で書く**——
  /// 英語しか読めない人に「日本語」と漢字で出しても選べない。
  final String label;

  final String code;

  static Lang fromCode(String? code) =>
      Lang.values.firstWhere((l) => l.code == code, orElse: () => Lang.ja);

  Locale get locale => Locale(code);
}

/// 今の言語。**ここだけが答えを持つ。**
///
/// 既定は日本語にしてある。**端末の言語から決めない**のは、
/// テストと撮影（`test/shots.dart`）が端末の言語を英語として起動するため
/// ——既定を端末に合わせると、画面を確かめる道具が全部英語になり、
/// 日本語の画面を二度と見られなくなる。実際のアプリは起動時に
/// `Language.initialize()` が端末の言語と保存した設定で上書きする。
Lang _lang = Lang.ja;

Lang get currentLang => _lang;

/// 訳を、使う場所に置く。
///
/// **別の表に切り出してキーを付けない。** 文を直したときに片方だけ
/// 古くなるのが、このプロジェクトで一番よく出る壊れ方
/// （数字を `Formulas` から引かずに書き写したときと同じ）。
/// 2つを隣に置いておけば、片方だけ直すことが目で見て分かる。
///
/// `const Text(...)` は使えなくなるが、どちらも `build` の中なので
/// 作り直しの手間は変わらない。
String tr(String ja, String en) => _lang == Lang.en ? en : ja;

/// 文ではないもの（札の枠の幅など）を言語で選ぶ。
///
/// **見た目の数字を言語で変えるのは、一番長い語に合わせた枠だけに留める。**
/// 英語は1語が長いので、日本語の2〜3文字に合わせた枠では途中で割れる
/// （「Opponent」が「Oppone / nt」になった）。文の中の数字は `tr()` に埋める。
T pick<T>(T ja, T en) => _lang == Lang.en ? en : ja;

/// 英語の数え方。**1のときだけ s を落とす。**
///
/// 日本語に単複は無いので、`tr()` の英語側にだけ要る。埋め込む数が
/// 1になり得るなら、ここを通す——実際に「1 seasons」「1 bookings」が
/// 画面に出ていた。形の変わる語は `many` を渡す。
String plural(int n, String one, [String? many]) =>
    '$n ${n.abs() == 1 ? one : (many ?? '${one}s')}';

/// 言語の設定。端末の言語を初期値にして、アプリの中で変えられる。
///
/// **ゲームの状態とは別に持つ**（`Monetization` と同じ理屈）。
/// 何語で読むかは、どのキャリアを遊んでいるかとは関係がない。
class Language extends ChangeNotifier {
  static const String _key = 'lang.code';

  bool initialized = false;

  Lang get value => _lang;

  /// 保存した設定があればそれを、無ければ端末の言語を使う。
  ///
  /// 日本語以外は全部英語にする——他の言語に対応していないのに
  /// 日本語で出すと、何も読めない画面を渡すことになる。
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        _lang = Lang.fromCode(saved);
      } else {
        final device = PlatformDispatcher.instance.locale.languageCode;
        _lang = device == 'ja' ? Lang.ja : Lang.en;
      }
    } catch (_) {
      // 読めなくても遊びは止めない。日本語のまま始める
      // （殿堂や共有と同じ扱い。設定はあると嬉しいもので、
      // キャリアを進めるのに要るものではない）。
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> set(Lang lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang.code);
    } catch (_) {
      // 保存できなくても、この起動のあいだは切り替わっている。
    }
  }

  /// テストと撮影のため。**アプリからは呼ばない。**
  @visibleForTesting
  static void setForTest(Lang lang) => _lang = lang;
}

/// **日本語と英語を隣に置いたまま、`const` の表に入れる文。**
///
/// `tr()` は関数なので `const` の中には書けない（enum の引数・既定の
/// 引数・`static const` と同じ壁）。局面74（`Scenarios`）と特性75
/// （`Trait`）は `static const` の表なので、**文の側に2つ持たせて、
/// 読むときに今の言語を選ぶ**。
///
/// 訳を別の表へ切り出さずに済むのが要——`tr('引退', 'Retire')` と
/// 同じく2つが隣に並ぶので、片方だけ直したことが目で見て分かる。
/// 使う側は `String get label => _label.t;` のように getter で包み、
/// **外には `String` のまま見せる**（呼ぶ側を書き換えないため）。
class Say {
  const Say(this.ja, this.en);

  final String ja;
  final String en;

  /// 今の言語の文。**読むたびに選ぶ**ので、切り替えに付いてくる。
  String get t => tr(ja, en);

  @override
  String toString() => t;
}
