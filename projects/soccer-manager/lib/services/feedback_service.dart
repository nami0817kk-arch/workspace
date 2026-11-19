import 'package:flutter/services.dart';

import '../state/settings_controller.dart';
import 'sfx_service.dart';

/// サウンド・触覚フィードバックをアプリ全体から呼び出すための小さなサービス。
/// SettingsControllerのON/OFF設定を尊重する。BuildContextを持たないロジック層
/// (試合画面のコールバックなど)からも呼べるよう、起動時に一度だけ設定を紐付ける。
class FeedbackService {
  static SettingsController? _settings;

  static void attach(SettingsController settings) {
    _settings = settings;
  }

  static bool get _hapticsOn => _settings?.hapticsEnabled ?? true;
  static bool get _soundOn => _settings?.soundEnabled ?? true;

  /// ボタンタップなど、軽い操作フィードバック。
  static void tap() {
    if (_hapticsOn) HapticFeedback.selectionClick();
  }

  /// 得点シーン。自クラブの得点なら歓声、相手の得点なら相手側スタンドが沸く。
  static void goal({required bool isUserGoal}) {
    if (_hapticsOn) {
      isUserGoal ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    }
    if (_soundOn) {
      SfxService.play(isUserGoal ? Sfx.goalCheer : Sfx.concedeAway);
    }
  }

  /// 試合の始まりの笛。
  static void kickOff() {
    if (_soundOn) SfxService.play(Sfx.whistleStart, volume: 0.7);
  }

  /// 優勝・昇格など、祝いの場面。
  static void celebrate() {
    if (_hapticsOn) HapticFeedback.heavyImpact();
    if (_soundOn) SfxService.play(Sfx.celebrate);
  }

  /// 試合終了時の勝敗結果。終わりの笛のあと、勝てば歓声、負ければ相手側
  /// スタンドが沸く。
  static void matchResult({required bool won, required bool drew}) {
    if (_hapticsOn) {
      if (won) {
        HapticFeedback.heavyImpact();
      } else if (!drew) {
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    if (_soundOn) {
      SfxService.play(Sfx.whistleEnd, volume: 0.7);
      if (!drew) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          SfxService.play(won ? Sfx.goalCheer : Sfx.concedeAway);
        });
      }
    }
  }

  /// 契約更新・移籍成立など、達成感のある操作の完了通知。
  static void success() {
    if (_hapticsOn) HapticFeedback.mediumImpact();
    if (_soundOn) SfxService.play(Sfx.deal, volume: 0.6);
  }

  /// 資金不足など、操作が失敗したことの通知。
  static void error() {
    if (_hapticsOn) HapticFeedback.heavyImpact();
  }
}
