// App Store の「言語」欄が日本語になるための実体(落とし穴 #5)。
// Info.plist の CFBundleLocalizations だけでは足りず、ja.lproj/InfoPlist.strings が
// Xcode プロジェクトに登録されている必要がある。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('ja と en の InfoPlist.strings がある', () {
    expect(File('ios/Runner/ja.lproj/InfoPlist.strings').readAsStringSync(),
        contains('CFBundleDisplayName'));
    expect(File('ios/Runner/en.lproj/InfoPlist.strings').readAsStringSync(),
        contains('CFBundleDisplayName'));
    expect(File('ios/Runner/ja.lproj/InfoPlist.strings').readAsStringSync(),
        contains('バスケ育成'));
  });

  test('Xcode プロジェクトに登録されている(ファイル参照・変数グループ・リソース・言語)', () {
    expect(pbx, contains('path = ja.lproj/InfoPlist.strings'));
    expect(pbx, contains('path = en.lproj/InfoPlist.strings'));
    expect(pbx, contains('/* InfoPlist.strings in Resources */'));
    expect(pbx, contains('isa = PBXVariantGroup'));
    expect(RegExp(r'knownRegions = \([^)]*\bja,').hasMatch(pbx), isTrue,
        reason: 'knownRegions に ja');
  });

  test('参照するIDが実際に定義されている(登録の取りこぼしが無い)', () {
    for (final id in [
      'B2C3D4E5F6A7081930415001',
      'B2C3D4E5F6A7081930415002',
      'B2C3D4E5F6A7081930415003',
      'B2C3D4E5F6A7081930415004',
    ]) {
      expect(pbx.split(id).length - 1, greaterThanOrEqualTo(2), reason: id);
    }
    expect('{'.allMatches(pbx).length, '}'.allMatches(pbx).length);
    expect('('.allMatches(pbx).length, ')'.allMatches(pbx).length);
  });

  test('Info.plist が日本語と英語を申告している', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('CFBundleLocalizations'));
    expect(plist, contains('<string>ja</string>'));
    expect(plist, contains('<string>en</string>'));
  });
}
