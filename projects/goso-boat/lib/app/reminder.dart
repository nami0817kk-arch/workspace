import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 今日の1問のお知らせ（1日1回）。**最初はオフ**で、設定で入れた人だけに出す。
/// iOS 以外（Web版・テスト）では何もしない。
abstract final class Reminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _id = 1;

  static bool get supported {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        // 許可はオンにした瞬間にだけ聞く（起動時にいきなり聞かない）
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// オンにする。許可が得られなければ false（設定はオフのままにする）。
  static Future<bool> enable({required String title, required String body}) async {
    if (!supported) return false;
    try {
      await _init();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(alert: true, sound: true) ?? false;
      if (!granted) return false;
      // オンにした時刻から24時間おきに出す（「毎日この時間に」）
      await _plugin.periodicallyShow(
        id: _id,
        title: title,
        body: body,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}
