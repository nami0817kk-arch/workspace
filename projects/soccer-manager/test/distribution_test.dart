import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配信まわりの設定が食い違っていないかを固定するテスト。
///
/// これらは実行時ロジックではなく、ビルド設定・ストア掲載情報・アプリ内リンクの
/// 整合性を守るためのもの。ズレていても普通のテストは通ってしまい、
/// 気付くのがストアの審査差し戻しになるため、ここで検出する。
void main() {
  group('配信設定の整合性', () {
    test('プライバシーポリシー・利用規約のURLが公開先と一致している', () {
      // Web版のデプロイ先。ルートの .github/workflows/soccer-pages.yml が
      // Cloudflare Pages へ公開し、legal/*.html をこの下の legal/ へコピーする。
      // base-href が "/" なので、サイトのルート直下がそのまま公開URLになる。
      const publishedLegalBase =
          'https://soccer-manager.pages.dev/legal';

      final settingsSource =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(
        settingsSource,
        contains("'$publishedLegalBase/privacy.html'"),
        reason: 'アプリ内のプライバシーポリシーのリンク先が公開先と食い違っている',
      );
      expect(
        settingsSource,
        contains("'$publishedLegalBase/terms.html'"),
        reason: 'アプリ内の利用規約のリンク先が公開先と食い違っている',
      );

      // ストア掲載情報にも同じURLを書く。Google Play は動作する
      // プライバシーポリシーURLの提出を必須にしているため、
      // ここがアプリ内と食い違うと審査で差し戻される。
      final storeListing = File('STORE_LISTING.md').readAsStringSync();
      expect(storeListing, contains('$publishedLegalBase/privacy.html'));
      expect(storeListing, contains('$publishedLegalBase/terms.html'));
    });

    test('掲載文の対応言語が、アプリが実際に持つ言語と一致する', () {
      // 「対応言語: 日本語」と書いてあったが、アプリは英語にも対応し、
      // 設定画面に切り替えもあった。掲載文が実装に追いついていない例。
      final storeListing = File('STORE_LISTING.md').readAsStringSync();
      final trSource = File('lib/l10n/tr.dart').readAsStringSync();

      final hasEnglish = trSource.contains('AppLanguage.english');
      if (hasEnglish) {
        expect(storeListing, contains('英語'),
            reason: 'アプリは英語に対応しているのに、掲載文が日本語のみになっている');
      }
    });

    test('掲載文が、実装に無い呼び名で機能を説明していない', () {
      // 掲載文だけ先に書き換えると、無い機能を宣伝することになる。
      // 逆に実装だけ変えると、掲載文が古い呼び名のまま残る
      // (スタッフは「強化」から「雇用」に変わった)。
      final storeListing = File('STORE_LISTING.md').readAsStringSync();

      // 掲載文が謳っている機能は、実装側に対応する語がある。
      const claims = {
        'メンター': 'lib/logic/training_engine.dart',
        'スカウティングレポート': 'lib/logic/scout_report_engine.dart',
        'リザーブ': 'lib/logic/reserve_match_engine.dart',
        '育成型レンタル': 'lib/logic/training_engine.dart',
      };
      for (final entry in claims.entries) {
        if (!storeListing.contains(entry.key)) continue;
        expect(File(entry.value).existsSync(), isTrue,
            reason: '掲載文の「${entry.key}」に対応する実装が見当たらない');
      }

      // 古い呼び名が残っていないか。
      expect(storeListing, isNot(contains('スタッフ強化')),
          reason: 'スタッフはレベルを強化する仕組みではなく、人を雇う仕組みになった');
    });

    test('デバッグ機能がリリースビルドに出ない', () {
      // 「デバッグ(管理者専用)」と書いてあるだけで、実際は設定画面を
      // 開けば誰でも押せる状態だった。任意の額の資金を足せるので、
      // 資金のやりくりという経営シミュレーションの根幹が意味を失う。
      // 課金の特典を「資金」に絞って調整してきたことも台無しになる。
      final settings =
          File('lib/screens/settings_screen.dart').readAsStringSync();

      expect(settings, contains('kDebugMode'),
          reason: 'デバッグ導線がビルド種別で守られていない');

      // 資金追加の導線は、必ず kDebugMode の分岐の中にある。
      final debugIndex = settings.indexOf('kDebugMode &&');
      final addFundsIndex = settings.indexOf('_showAddFundsDialog(context)');
      expect(debugIndex, greaterThanOrEqualTo(0));
      expect(addFundsIndex, greaterThan(debugIndex),
          reason: '資金追加の導線が kDebugMode の外にある');
    });

    test('資金を直接足せる導線は、デバッグ用の1つだけ', () {
      // 似た抜け道が増えていないか。増えるときは、それがリリースに
      // 出てよいものかを考える機会になる。
      final callers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('addDebugFunds('))
          .map((f) => f.path)
          .toList();

      // 定義(game_state_squad.dart)と呼び出し(settings_screen.dart)の2つ。
      expect(callers.length, 2,
          reason: 'addDebugFunds を呼ぶ箇所が増えている: $callers');
    });

    test('手順書が作らせる鍵ファイルが、すべて Git から除外されている', () {
      // RELEASE_GUIDE は署名鍵や証明書を作らせ、CI へ渡すために Base64 化
      // させる。**Base64 は鍵そのもので、テキストになっただけ。**
      // 実際 keystore.base64.txt は除外されておらず、手順どおりに作ると
      // リポジトリに入りうる状態だった。
      //
      // 手順書に出てくるファイル名が増えたら、ここにも足すこと。
      const secretsFromGuide = [
        'upload-keystore.jks',
        'keystore.base64.txt',
        'ios_distribution.key',
        'ios_distribution.csr',
        'distribution.cer',
        'distribution.pem',
        'ios_distribution.p12',
        'ios_cert.base64.txt',
        'ios_profile.base64.txt',
        'AuthKey_XXXX.p8',
      ];

      final leaked = <String>[];
      for (final name in secretsFromGuide) {
        final result = Process.runSync('git', ['check-ignore', '-q', name]);
        // 終了コード0が「除外されている」。1は除外されていない。
        if (result.exitCode != 0) leaked.add(name);
      }

      expect(leaked, isEmpty,
          reason: '手順どおりに作るとリポジトリに入る鍵ファイルがある: $leaked');
    });

    test('鍵ファイルが実際にコミットされていない', () {
      // 除外設定より前に追加されていれば、除外は効かない。
      final tracked = Process.runSync('git', ['ls-files']).stdout as String;
      final suspicious = tracked
          .split(String.fromCharCode(10))

          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .where((l) =>
              l.endsWith('.jks') ||
              l.endsWith('.p12') ||
              l.endsWith('.p8') ||
              l.endsWith('.key') ||
              l.endsWith('.cer') ||
              l.endsWith('.base64.txt'))
          .toList();

      expect(suspicious, isEmpty, reason: '鍵ファイルがコミットされている: $suspicious');
    });

    test('旧リポジトリを指すURLが残っていない', () {
      // このプロジェクトは kabu-agari-ranking から claude-code-dev へ移した。
      // 移行時に取り残されたURLが実際にアプリ内とストア掲載情報の両方に
      // 残っていて、どちらも存在しないページを指していた。
      // README の移行経緯の記述だけは対象外。
      for (final path in const [
        'lib/screens/settings_screen.dart',
        'STORE_LISTING.md',
        'legal/privacy.html',
        'legal/terms.html',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('kabu-agari-ranking')),
          reason: '$path に旧リポジトリを指すURLが残っている',
        );
      }
    });

    test('Androidのリリースビルドがデバッグ鍵で署名されない', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      // key.properties があるときは必ず署名設定 release を使う。
      // ここが signingConfigs.debug 固定に戻ると、Google Play に
      // 提出できないAABが黙って出来上がる。
      expect(
        gradle,
        contains('signingConfig = hasKeystore ? signingConfigs.release'),
        reason: 'リリースビルドの署名設定が key.properties を見ていない',
      );
    });

    test('見出しフォントを同梱していて、外部から取得していない', () {
      // google_fonts 経由だと初回起動時に fonts.gstatic.com へ取りに行き、
      // 利用者のIPアドレスが Google に渡る。プライバシーポリシーの
      // 「アプリ版は外部サーバーへの通信を一切行いません」と矛盾するため、
      // アセットとして同梱する方式に戻さないよう固定する。
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains(RegExp(r'^\s*google_fonts:', multiLine: true)),
        isFalse,
        reason: 'google_fonts への依存が復活している',
      );
      expect(pubspec, contains('family: ShipporiMincho'));

      for (final f in const [
        'assets/fonts/ShipporiMincho-Regular.ttf',
        'assets/fonts/ShipporiMincho-SemiBold.ttf',
        // OFL 1.1 はフォントの再配布に際してライセンス文の同梱を求めている。
        'assets/fonts/OFL.txt',
      ]) {
        expect(File(f).existsSync(), isTrue, reason: '$f が無い');
      }

      expect(
        File('lib/main.dart').readAsStringSync(),
        isNot(contains('GoogleFonts')),
        reason: 'main.dart が実行時取得のフォントを参照している',
      );
    });

    test('Web版がCanvasKitをGoogleのCDNから読み込まない', () {
      // Flutter Web は既定で CanvasKit (描画エンジン本体) を
      // www.gstatic.com から読み込むため、ページを開いただけで
      // 利用者のIPアドレスが Google に渡る。ビルド時に
      // build/web/canvaskit/ へ出力されるローカルのコピーを使う。
      final bootstrap = File('web/flutter_bootstrap.js');
      expect(bootstrap.existsSync(), isTrue, reason: 'ブートストラップの上書きが消えている');
      expect(bootstrap.readAsStringSync(), contains('canvasKitBaseUrl'));
    });

    test('広告を入れた事実が法務・掲載情報から漏れていない', () {
      // 実装だけ広告を出して、プライバシーポリシーやストア掲載情報が
      // 「広告なし」のままだと、虚偽の申告で提出することになる。
      // 実装と表記が食い違わないよう固定する。
      final privacy = File('legal/privacy.html').readAsStringSync();
      expect(privacy, contains('AdMob'), reason: 'プライバシーポリシーが広告配信に触れていない');
      expect(privacy, contains('広告識別子'), reason: '広告識別子の取得を開示していない');
      // リワード広告に加えて全画面広告を出すようになった。種類ごとに
      // 開示していないと、実装より狭い申告になる。
      expect(privacy, contains('インタースティシャル'),
          reason: 'プライバシーポリシーが全画面広告に触れていない');

      for (final path in const [
        'STORE_LISTING.md',
        'marketing/landing/index.html',
        'marketing/ANNOUNCEMENT.md',
        'legal/privacy.html',
        'lib/widgets/supporter_section.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, isNot(contains('広告なし・課金なし')),
            reason: '$path に「広告なし・課金なし」が残っている');
        expect(text, isNot(contains('広告も課金も')),
            reason: '$path に広告・課金が無いという記述が残っている');
        // シーズンの切り替わりで全画面広告を出す実装になったので、
        // 「全画面広告は無い」という売り文句はどれも虚偽になる。
        expect(text, isNot(contains('全画面広告なし')),
            reason: '$path に「全画面広告なし」が残っている');
        expect(text, isNot(contains(RegExp(r'全画面広告やバナー(広告)?はありません'))),
            reason: '$path に全画面広告が無いという記述が残っている');
      }
    });

    test('全画面広告はシーズンの切り替わりからしか出ない', () {
      // 試合中やメニュー操作の途中に割り込む全画面広告は、掲載文の説明とも
      // AdMob のポリシー(利用者の操作を遮らない自然な区切りで出す)とも
      // 合わない。呼び出し口が増えていないことをここで固定する。
      final callers = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // 定義側(AdService とその仲介役)は対象外。
        if (entity.path.contains('monetization')) continue;
        final text = entity.readAsStringSync();
        expect(text, isNot(contains('showInterstitialAd(')),
            reason: '${entity.path} が広告サービスを直接呼んでいる');
        if (text.contains('showSeasonInterstitial()')) callers.add(entity.path);
      }
      expect(callers.length, 1, reason: '全画面広告の呼び出し口が1箇所でない: $callers');
      expect(callers.single, contains('home_screen'),
          reason: 'シーズンの切り替わり以外から全画面広告を出している');
    });

    test('バンドルIDが実装・手順書・掲載情報で一致している', () {
      // 手順書は「Apple のフォームにこの文字列を入力する」と指示している。
      // 実装だけ変えて手順書が古いままだと、あとから変更できない App ID を
      // 間違った値で登録してしまう。気付くのは提出の直前になる。
      const marker = 'PRODUCT_BUNDLE_IDENTIFIER = ';
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      final ids = <String>{};
      var at = pbx.indexOf(marker);
      while (at >= 0) {
        final end = pbx.indexOf(';', at);
        ids.add(pbx.substring(at + marker.length, end));
        at = pbx.indexOf(marker, end);
      }
      final appIds = ids.where((id) => !id.endsWith('.RunnerTests')).toSet();
      expect(appIds.length, 1, reason: 'iOS のバンドルIDが1つに定まっていない: $appIds');
      final bundleId = appIds.single;

      // Android 側もこの値で揃えてある(アンダースコアを含まない名前にした)。
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle, contains('applicationId = "$bundleId"'),
          reason: 'Android の applicationId が iOS のバンドルIDと違う');
      expect(gradle, contains('namespace = "$bundleId"'),
          reason: 'Android の namespace が applicationId と違う');

      // Kotlin の package 宣言とディレクトリ階層がずれるとビルドが通らない。
      final activity = File(
          'android/app/src/main/kotlin/${bundleId.replaceAll('.', '/')}'
          '/MainActivity.kt');
      expect(activity.existsSync(), isTrue,
          reason: '${activity.path} が無い(パッケージの移動漏れ)');
      expect(activity.readAsStringSync(), contains('package $bundleId'));

      for (final path in const ['docs/RELEASE_GUIDE.md', 'STORE_LISTING.md']) {
        expect(File(path).readAsStringSync(), contains(bundleId),
            reason: '$path が古いバンドルIDのままになっている');
      }
    });

    test('Androidが広告に必要なインターネット権限を宣言している', () {
      // 権限が無いと広告SDKは通信できず、リワード広告が永久に
      // 読み込まれない (押せないボタンだけが残る)。
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    });

    test('リリース用ワークフローのシェル変数が、非ASCIIと地続きになっていない', () {
      // `echo "プロファイル「$NAME」"` のように $VAR の直後が非ASCII文字だと、
      // macOS ランナーのロケールではそのバイトが識別子の一部と見なされ、
      // 存在しない変数を参照して set -u で落ちる。実際に iOS のリリースが
      // ここで止まり、macOS ランナーの分数(通常の10倍)を1回無駄にした。
      // ログ出力の行なので、ローカルの検査では踏めない。
      final pattern = RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*');
      for (final path in const [
        '../../.github/workflows/soccer-ios-release.yml',
        '../../.github/workflows/soccer-android-release.yml',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path が無い');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final m in pattern.allMatches(lines[i])) {
            if (m.end >= lines[i].length) continue;
            final next = lines[i].codeUnitAt(m.end);
            expect(
              next < 128,
              isTrue,
              reason: '$path:${i + 1} の ${m.group(0)} が非ASCII文字と'
                  '地続きになっている。\${...} で囲むこと: '
                  '${lines[i].trim()}',
            );
          }
        }
      }
    });

    test('iOSが輸出コンプライアンスを申告している', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      // これがないと App Store Connect へのアップロードのたびに
      // 手動での回答を求められ、TestFlight への配信が止まる。
      expect(plist, contains('ITSAppUsesNonExemptEncryption'));
    });
  });
}
