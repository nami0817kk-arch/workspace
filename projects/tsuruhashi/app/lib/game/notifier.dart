import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 「留守の採掘がいっぱいになりました」の知らせ（2026-10-03 の決まり）。
///
/// - 許可は、初めて留守から戻ったときにゲームが頼む（`{"type":"notifAsk"}`）。起動してすぐには聞かない
/// - 裏に回るたびに、留守の上限（ゲームが `{"type":"notifCap","h":8}` で伝える）の時刻に1件だけ予約し、戻ったら取り消す
abstract class Notifier {
  Future<void> init();
  Future<bool> ask();
  Future<void> scheduleFull(double hours);
  Future<void> cancelAll();
}

class NoOpNotifier implements Notifier {
  @override
  Future<void> init() async {}
  @override
  Future<bool> ask() async => false;
  @override
  Future<void> scheduleFull(double hours) async {}
  @override
  Future<void> cancelAll() async {}
}

class LocalNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const _id = 1;

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          // 起動のときには許可を聞かない（ask で聞く）
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestSoundPermission: false, requestBadgePermission: false),
        ),
      );
      _ready = true;
    } catch (_) {}
  }

  @override
  Future<bool> ask() async {
    await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleFull(double hours) async {
    if (!_ready || hours <= 0) return;
    try {
      await _plugin.cancel(id: _id);
      await _plugin.zonedSchedule(
        id: _id,
        title: 'つるはし採掘',
        body: '留守の採掘がいっぱいになりました。仲間が鉱石を持って待っています',
        scheduledDate: tz.TZDateTime.now(tz.UTC).add(Duration(minutes: (hours * 60).round())),
        notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}

Notifier createNotifier() {
  if (kIsWeb) return NoOpNotifier();
  try {
    if (Platform.isIOS) return LocalNotifier();
  } catch (_) {}
  return NoOpNotifier();
}
