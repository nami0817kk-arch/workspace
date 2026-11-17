import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youth_academy/boot.dart';

void main() {
  test('保存した値が window.__BOOT として差し込まれる', () {
    final out = injectBoot('<script>/*__BOOT__*/</script>', {'cfg': '{"a":1}'});
    expect(out, contains('window.__BOOT='));
    expect(out, contains(r'\"a\":1'));
    expect(out, isNot(contains('/*__BOOT__*/')));
  });

  test('別アプリから戻ったとき：中身が無い・答えが無いなら読み直す', () {
    expect(needsReload(null), isTrue);
    expect(needsReload(0), isTrue);
    expect(needsReload('0'), isTrue);
    expect(needsReload('"x"'), isTrue);
    expect(needsReload(3), isFalse);
    expect(needsReload('5'), isFalse);
    expect(needsReload(2.0), isFalse);
    expect(aliveProbe, contains('getElementById("app")'));
  });

  test('main.dart：戻ったときの確かめと、中身が落ちたときの読み直しがつながっている', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('WidgetsBindingObserver'));
    expect(src, contains('AppLifecycleState.resumed'));
    expect(src, contains('webContentProcessTerminated'));
    expect(src, contains('needsReload('));
  });

  test('起動時の読み込み：ya_ に文字の並びが混ざっていても落ちず、文字の値だけ渡す（課金すると起動しなくなっていた）', () {
    final s = collectStore({'ya_world': '{"v":3}', 'ya_ent_seen': <String>['youth_ticket_1:1'], 'ya_n': 3, 'ent_seen': <String>['x'], 'other': 'z'});
    expect(s, {'world': '{"v":3}'});
  });

  test('値に </script> が入っていてもページが壊れない', () {
    final out = injectBoot('<script>/*__BOOT__*/</script>', {'x': '</script><b>'});
    expect('</script>'.allMatches(out).length, 1);
  });

  test('Info.plist: 横向き固定・暗号化の質問に答え済み・AdMob のアプリIDがある', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(plist, contains('UIInterfaceOrientationLandscapeRight'));
    expect(plist, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>').hasMatch(plist), isTrue);
    expect(plist, contains('GADApplicationIdentifier'));
    expect(plist, contains('SKAdNetworkItems'));
  });

  test('Bundle ID が App Store Connect に作ったものと同じ', () {
    final p = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(p, contains('PRODUCT_BUNDLE_IDENTIFIER = com.namiki.youthacademy;'));
    expect(p, isNot(contains('hikari')));
  });
}
