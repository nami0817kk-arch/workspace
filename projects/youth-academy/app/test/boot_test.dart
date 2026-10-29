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

  test('値に </script> が入っていてもページが壊れない', () {
    final out = injectBoot('<script>/*__BOOT__*/</script>', {'x': '</script><b>'});
    expect('</script>'.allMatches(out).length, 1);
  });

  test('Info.plist: 横向き固定・暗号化の質問に答え済み・AdMob を持ち込んでいない', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(plist, contains('UIInterfaceOrientationLandscapeRight'));
    expect(plist, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>').hasMatch(plist), isTrue);
    expect(plist, isNot(contains('GADApplicationIdentifier')));
  });

  test('Bundle ID が App Store Connect に作ったものと同じ', () {
    final p = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(p, contains('PRODUCT_BUNDLE_IDENTIFIER = com.namiki.youthacademy;'));
    expect(p, isNot(contains('hikari')));
  });
}
