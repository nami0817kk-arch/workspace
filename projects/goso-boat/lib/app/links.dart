import 'package:url_launcher/url_launcher.dart';

/// アプリの中から開く、公開ページの置き場所。
///
/// 審査の決まり（Apple 5.1.1）で、プライバシーポリシーはアプリの中からも開けなければならない。
/// 置き場所が変わったらビルド時に --dart-define=LEGAL_BASE_URL で差し替える。
class Links {
  static const _base = String.fromEnvironment('LEGAL_BASE_URL', defaultValue: 'https://goso-boat.pages.dev');

  static Uri get privacy => Uri.parse('$_base/privacy.html');

  /// 問い合わせ先と「不適切な広告の報告」（Apple 2.5.18）の案内がある。
  static Uri get support => Uri.parse('$_base/support.html');

  /// 外のブラウザで開く。開けなければ false。
  static Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
