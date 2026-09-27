import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 効果音（assets/sfx、tool/make_sfx.py で合成）。
enum Sfx { board, unboard, depart, arrive, nope, escape, splash, clear, star, hint, tap }

enum Buzz { select, light, medium, heavy }

/// 音と振動の設定、と鳴らす係。端末の中にだけ保存する。
class GameSettings extends ChangeNotifier {
  GameSettings(this._prefs, {this.silent = false});

  final SharedPreferences _prefs;

  /// テスト用。音の再生（プラットフォームの呼び出し）を一切しない。
  final bool silent;

  bool get sound => _prefs.getBool('sound') ?? true;
  bool get haptics => _prefs.getBool('haptics') ?? true;

  /// 今日の1問のお知らせ。最初はオフ。
  bool get reminder => _prefs.getBool('reminder') ?? false;

  Future<void> setReminder(bool v) async {
    await _prefs.setBool('reminder', v);
    notifyListeners();
  }

  Future<void> setSound(bool v) async {
    await _prefs.setBool('sound', v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    await _prefs.setBool('haptics', v);
    notifyListeners();
  }

  final Map<Sfx, AudioPool> _pools = {};

  /// 鳴らす。失敗しても（音の機能が無い環境など）ゲームは止めない。
  Future<void> play(Sfx s) async {
    if (silent || !sound) return;
    try {
      final pool = _pools[s] ??= await AudioPool.create(
        source: AssetSource('sfx/${s.name}.wav'),
        maxPlayers: 3,
      );
      await pool.start(volume: 0.8);
    } catch (_) {}
  }

  void buzz(Buzz b) {
    if (silent || !haptics) return;
    switch (b) {
      case Buzz.select:
        HapticFeedback.selectionClick();
      case Buzz.light:
        HapticFeedback.lightImpact();
      case Buzz.medium:
        HapticFeedback.mediumImpact();
      case Buzz.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

/// 画面のどこからでも設定に届くようにする。
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.settings, required super.child});
  final GameSettings settings;

  static GameSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.settings;

  /// 無ければ null（アプリの外で作ったボタン・テストなど）。
  static GameSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.settings;

  @override
  bool updateShouldNotify(AppScope old) => old.settings != settings;
}
