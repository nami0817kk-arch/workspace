/// ストア掲載用のスクリーンショットを生成する。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 生成器だからで、実行するとファイルを書き換える。
///
///     flutter test tool/screenshots/capture_test.dart --update-goldens
///
/// 手で撮らずにここで作る理由:
///
/// - ストアが求める解像度を確実に満たせる。実機やエミュレータの
///   スクリーンショットは端末ごとに寸法が違う。
/// - 同じ内容で撮り直せる。文言を直すたびに端末を出してくる必要がない。
///
/// **1.2.0 から横画面。** オーナー型に作り替えたとき、スマホは横向きに固定
/// した(main.dart の `_lockLandscapeOnPhones`)。縦の掲載画像は、今のアプリと
/// 違う見た目を見せることになる。撮るのは、実機と同じ作り
/// (上の帯・左のメニュー・`LandscapeScale`・`FmThemeScope`)の [MainShell] を、
/// 左のメニューとページのタブを実際に押して開いた画面。
///
/// 以前 `marketing/screenshots/` に置かれていた画像は、天気アイコンが
/// 豆腐(□)のまま写っていた。ウィジェットテストの既定ではアイコンフォントが
/// 読み込まれないためで、このファイルでは実物を読み込んでいる。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではない
// コード」になり、@visibleForTesting の項目を使うと警告になる。実体は
// flutter test で走らせる生成器で、テストと同じ立場でアプリを組み立てる。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';

/// 撮る端末の寸法。App Store は iPhone と iPad のそれぞれで
/// スクリーンショットを求める。アプリが iPad でも動く設定
/// (TARGETED_DEVICE_FAMILY = "1,2")になっているため、iPhone だけでは
/// 「13インチのiPadディスプレイのスクリーンショットをアップロードする
/// 必要があります」で提出できない(実際に止まった)。
typedef _Device = ({String dir, Size logical, double ratio, bool tablet});

/// iPhone「Dynamic Island 搭載・中型」の横向き = 2622x1206(iPhone 16 Pro など)。
/// 2026-11 時点で iPhone の必須はこの枠だけ(大型は任意で、無ければ縮めて
/// 使われる)。Apple の仕様:
/// https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
const _phone = (
  dir: 'screenshots',
  logical: Size(874, 402),
  ratio: 3.0,
  tablet: false,
);

/// iPad 13インチの横向き = 2752x2064。
const _tablet = (
  dir: 'screenshots_ipad',
  logical: Size(1376, 1032),
  ratio: 2.0,
  tablet: true,
);

const _devices = <_Device>[_phone, _tablet];

/// 撮る言語。ストアの掲載は言語ごとに画像を持てる。アプリは選手名・クラブ名
/// まで英語のプールを持っているので、英語圏には英語の画面を出す。日本語の
/// 画面に英語の説明文を添えても、中身が伝わらないどころか不信を招く。
typedef _Locale = ({AppLanguage language, String code, String suffix});

const _ja = (language: AppLanguage.japanese, code: 'ja', suffix: '');
const _en = (language: AppLanguage.english, code: 'en', suffix: '_en');

const _locales = <_Locale>[_ja, _en];

/// 1枚の中身。左のメニューの項目と、開くページのタブ(無ければ最初のタブ)。
typedef _Shot = ({
  String name,
  (String ja, String en) menu,
  (String ja, String en)? tab,
  (String ja, String en) caption,
  (int top, int bottom) shade,
});

/// 撮る画面と、上に乗せる言葉。**番号はストアに並べる順。**
///
/// 検索結果に出るのは先頭の数枚なので、「クラブを買った経営者になる」
/// ことが一目で伝わる順に置く(状況 → 予算 → 2つの期待 → 施設 → 補強 →
/// 順位)。画面をそのまま撮っただけでは、スクロールしている人に何のゲームか
/// 伝わらないので、全カットに帯を入れる(同じ分野の上位もそうしている)。
const _shots = <_Shot>[
  (
    name: '01_home',
    menu: ('状況', 'Status'),
    tab: null,
    caption: ('弱小クラブのオーナーになる', 'Buy a struggling club'),
    shade: (0xFF0B1526, 0xFF14213D),
  ),
  (
    name: '02_budget',
    menu: ('経営', 'Finance'),
    tab: null,
    caption: ('予算を5つに配る', 'Split the budget five ways'),
    shade: (0xFF12324D, 0xFF1D5B7A),
  ),
  (
    name: '03_office',
    menu: ('オーナー室', 'Office'),
    tab: null,
    caption: ('サポーターと株主、2つの期待', 'Keep fans and shareholders on side'),
    shade: (0xFF0F3D22, 0xFF1C6B3A),
  ),
  (
    name: '04_facilities',
    menu: ('クラブ', 'Club'),
    tab: ('施設', 'Facilities'),
    caption: ('施設を建てて、クラブを大きくする', 'Build up the club'),
    shade: (0xFF1A3A2A, 0xFF2E6E46),
  ),
  (
    name: '05_transfer',
    menu: ('移籍', 'Transfers'),
    tab: null,
    caption: ('補強の候補を、買うか見送るか', 'Sign him, or pass'),
    shade: (0xFF0B3B33, 0xFF156B55),
  ),
  (
    name: '06_league',
    menu: ('リーグ', 'League'),
    tab: ('順位表', 'Table'),
    caption: ('3部から、1部の頂点へ', 'From the third tier to the top'),
    shade: (0xFF12324D, 0xFF1D5B7A),
  ),
  (
    name: '07_staff',
    menu: ('クラブ', 'Club'),
    tab: ('スタッフ', 'Staff'),
    caption: ('コーチもスカウトも、選んで雇う', 'Hire coaches and scouts'),
    shade: (0xFF0F3D22, 0xFF1C6B3A),
  ),
  (
    name: '08_community',
    menu: ('クラブ', 'Club'),
    tab: ('ファンと街', 'Fans & city'),
    caption: ('街とファンを味方につける', 'Win over the town and the fans'),
    shade: (0xFF1A3A2A, 0xFF2E6E46),
  ),
];

/// 同梱フォントと、Flutter SDK が持つアイコンフォントを読み込む。
///
/// アイコンフォントを読まないと、天気やナビゲーションのアイコンが
/// すべて豆腐(□)になる。実際に前のスクリーンショットがそうなっていた。
Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bundled = {
    'NotoSansJP': ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf'],
    'ShipporiMincho': [
      'ShipporiMincho-Regular.ttf',
      'ShipporiMincho-SemiBold.ttf',
    ],
  };
  for (final entry in bundled.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final icons = File(_materialIconsPath());
  if (!icons.existsSync()) {
    fail('アイコンフォントが見つからない: ${icons.path}\n'
        'FLUTTER_ROOT を設定して実行してください。'
        'このまま撮ると、全アイコンが豆腐(□)で写ります。');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

String _materialIconsPath() {
  // flutter test は FLUTTER_ROOT を渡してくる。渡ってこない実行のために、
  // 実行中の Dart の位置からも辿れるようにしておく。
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  return '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
}

final _japanese = RegExp(r'[ぁ-んァ-ヴ一-龠]');

void main() {
  setUpAll(_loadFonts);

  for (final device in _devices) {
    for (final locale in _locales) {
      final outDir = '${device.dir}${locale.suffix}';
      testWidgets('ストア用スクリーンショットを書き出す ($outDir)', (tester) async {
        addTearDown(tester.view.reset);
        // テストの既定では影が「くっきりした板」で描かれる。明るい見た目は
        // 白い箱を薄い影で浮かせているので、実機と同じ柔らかい影で撮る。
        // 終わる前に戻す(戻さないとテストの枠組みが失敗にする)。
        debugDisableShadows = false;
        tester.view.devicePixelRatio = device.ratio;
        tester.view.physicalSize = device.logical * device.ratio;

        SharedPreferences.setMockInitialValues({});

        addTearDown(() => Tr.language = AppLanguage.system);

        late final SettingsController settings;
        late final MonetizationController monetization;
        late final GameState gameState;
        await tester.runAsync(() async {
          settings = SettingsController();
          await settings.init();
          // **シミュレーションより先に言語を決める。** ニュースや事件の文面は
          // 作られた時点の言語で確定し、セーブにそのまま残る。あとから
          // 切り替えても遡って訳されない。撮影直前に決めていたため、日本語の
          // 画面に英語の記者会見が写った画像がストアに載っていた(1.0)。
          // init() が保存値(既定=端末準拠)を書き戻すので、その後で決めること。
          Tr.language = locale.language;
          monetization = MonetizationController(
            adService: NoOpAdService(),
            purchases: _StubPurchaseService(),
          );
          await monetization.initialize();
          gameState = GameState();
          // **クラブ名も撮る言語に合わせる。** 英語の画面に日本語のクラブ名が
          // 出ていると、英語圏には「訳し切れていないアプリ」に見える。
          // 上の帯に常時出るので、1枚だけの問題ではない。
          // 試合の結果は乱数で決まる。下位に沈んだ回を撮ると、1枚目から
          // 「目標まで勝点6差」「期待 -19」の赤字が並ぶ。理事会の目標より
          // 4つ以上上にいる回を選ぶ(数字は作らない。実際に進めた結果の
          // うち、うまく行っている回を撮る)。3部の弱小クラブなので、
          // 上位3分の1を条件にすると8回続けて届かなかった。
          for (var attempt = 0; attempt < 30; attempt++) {
            await gameState.startNewGame(locale.language == AppLanguage.japanese
                ? '青嵐フットボールクラブ'
                : 'Blue Storm FC');
            // 空の順位表や無得点の名簿を写しても、何ができるゲームか伝わら
            // ない。数節進めて、実際に遊んだ状態にしてから撮る。
            await gameState.simulateAheadMatchdays(8);
            // 移籍ウィンドウが閉じている時期に撮ると、「クローズ中」の帯が
            // 出て何もできない移籍市場がストアに載る(1.1.0 の撮り直しで
            // 気づいた)。開く時期(冬の窓)まで進める。
            var guard = 0;
            while (!gameState.isTransferWindowOpen && guard++ < 40) {
              await gameState.simulateAheadMatchdays(1);
            }
            final standings = gameState.save!.league.sortedStandings;
            final rank =
                standings.indexWhere((r) => r.teamId == gameState.userTeam.id) +
                    1;
            // 締切日は画面いっぱいの知らせが上に被さる(撮れない)。
            if (rank <= gameState.save!.boardTargetRank - 4 &&
                gameState.isTransferWindowOpen &&
                !gameState.isTransferDeadlineDay) {
              break;
            }
          }
          // 昇格や締切日などの「画面いっぱいの1枚」は、遊ぶ人なら閉じて
          // から次へ進む。溜まったまま撮ると、どの画面にも被さる。
          gameState.save!.pendingMoments.clear();
          // スタッフの画面を空席のまま撮ると「就いている人がいない」の赤字
          // だけが目立つ。いちばん質の高い候補を雇った状態にする。
          for (final role in StaffRole.values) {
            final candidates = gameState.staffCandidatesFor(role);
            if (candidates.isEmpty) continue;
            final best = candidates
                .reduce((a, b) => a.effectiveLevel >= b.effectiveLevel ? a : b);
            await gameState.hireStaff(best.id);
          }
          // 初回ガイドは画面の上を占める。何ができるゲームかを見せる場所
          // なので、遊び始めた人の画面として閉じた状態で撮る。
          gameState.save!.firstRunGuideDismissed = true;
        });
        expect(gameState.isTransferWindowOpen, isTrue,
            reason: '移籍ウィンドウが閉じたまま移籍市場を撮ろうとしている');

        // 生成された文面・名前が撮る言語になっているか、撮る前に確かめる。
        // 掲載画像は人が1枚ずつ見返さないので、混ざっていても気づかない。
        final wantJa = locale.language == AppLanguage.japanese;
        final clubName = gameState.userTeam.name;
        expect(_japanese.hasMatch(clubName), wantJa,
            reason: 'クラブ名が${locale.code}になっていない: $clubName');
        final aPlayer = gameState.userTeam.players.first.name;
        expect(_japanese.hasMatch(aPlayer), wantJa,
            reason: '選手名が${locale.code}になっていない: $aPlayer');
        final news = gameState.save!.newsLog;
        if (news.isNotEmpty) {
          final text = news.last.text;
          expect(_japanese.hasMatch(text), wantJa,
              reason: 'ニュースが${locale.code}になっていない: $text');
        }

        final app = const SoccerManagerApp();

        /// 実機と同じ寸法・同じ包み方で組んだアプリの画面。
        ///
        /// **端末の幅で組み直させない。** 帯を乗せるぶん画面は縮めて置くが、
        /// 枠の大きさで組ませると実機と違う割付になり、名前が「Ashwo…」の
        /// ように切れる。実機の寸法で組ませてから縮める。
        Widget realScreen() => FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox.fromSize(
                size: device.logical,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: device.logical,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                    ),
                    child: LandscapeScale(
                      // 掲載画像は既定の見た目(ライト)で撮る(2026-11-24)。
                      child: FmThemeScope(
                        light:
                            app.buildTheme(Brightness.light, boldText: false),
                        dark: app.buildTheme(Brightness.dark, boldText: false),
                        child: const MainShell(),
                      ),
                    ),
                  ),
                ),
              ),
            );

        /// 帯の言葉(書き換えて撮り直す)。地の色も画像ごとに振る。
        final caption = ValueNotifier<_Shot>(_shots.first);

        // 画面の上に言葉の帯を乗せ、下に端末の枠に入れた画面を置く。
        //
        // 縮めても読めるよう、太く大きく、濃い地に白で置く。Material で包む
        // (ColoredBox のままだと「Material の外のテキスト」と見なされ、黄色い
        // 二重下線が引かれる。実際に引かれた)。帯は theme の外なので、
        // fontFamily を明示しないと日本語が豆腐になる(実際になった)。
        //
        // 画面は1回だけ組み、帯だけを差し替える。組み直すと MainShell の
        // 開いているページが最初に戻る。
        final band = device.tablet ? 96.0 : 62.0;
        final side = device.tablet ? 40.0 : 60.0;
        final bezel = device.tablet ? 12.0 : 7.0;
        final body = Material(
          child: ValueListenableBuilder<_Shot>(
            valueListenable: caption,
            child: realScreen(),
            builder: (context, shot, screen) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(shot.shade.$1), Color(shot.shade.$2)],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: band,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        // **1行に収める。** 語の途中で折り返したことがある。
                        // 入らないぶんは縮める。
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            wantJa ? shot.caption.$1 : shot.caption.$2,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'NotoSansJP',
                              color: Colors.white,
                              fontSize: device.tablet ? 50 : 34,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 端末の枠に入れる。黒い縁を回すと、画面が「アプリの中」
                  // だと一目で分かる。下は画像の端で切る。
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: (device.logical.width + bezel * 2) /
                              (device.logical.height + bezel),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.vertical(
                                  top:
                                      Radius.circular(device.tablet ? 36 : 26)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            padding:
                                EdgeInsets.fromLTRB(bezel, bezel, bezel, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  top:
                                      Radius.circular(device.tablet ? 26 : 20)),
                              child: screen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<GameState>.value(value: gameState),
            ChangeNotifierProvider<SettingsController>.value(value: settings),
            ChangeNotifierProvider<MonetizationController>.value(
                value: monetization),
          ],
          child: MaterialApp(
            locale: Locale(locale.code),
            theme: app.buildTheme(Brightness.light, boldText: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // これを外さないと、右上にデバッグ用の赤い帯が写り込む。
            debugShowCheckedModeBanner: false,
            home: body,
          ),
        ));
        await tester.pump();

        Future<void> open((String, String) label) async {
          final text = wantJa ? label.$1 : label.$2;
          final f = find.text(text).hitTestable();
          if (f.evaluate().isEmpty) {
            final shown = find
                .byType(Text)
                .hitTestable()
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .whereType<String>()
                .take(30)
                .join(' | ');
            fail('「$text」が押せる所に無い。見えている文字: $shown');
          }
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
        }

        for (final shot in _shots) {
          caption.value = shot;
          await open(shot.menu);
          if (shot.tab != null) await open(shot.tab!);
          // **裏で読み込みを待つ画面は、疑似時間の pump では終わらない。**
          // 読み込み中の丸だけが写った白紙を、ストアの1枚目として出して
          // いた(2026-09-28 に指摘された)。実時間を少し進めて終わらせる。
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 350));

          // はみ出しや例外を抱えたまま掲載画像を作らない。
          expect(tester.takeException(), isNull,
              reason: '${shot.name} の描画で例外が出ている');

          // **何も描かれていない絵を掲載画像にしない。** 上の白紙は、例外も
          // はみ出しも出さないので、それまでの検査を全部すり抜けていた。
          expect(find.byType(CircularProgressIndicator), findsNothing,
              reason: '${shot.name} が読み込み中のまま撮られている');
          expect(find.byType(Text).hitTestable(), findsAtLeastNWidgets(3),
              reason: '${shot.name} に文字がほとんど無い(描画を待たずに撮っている)');

          // **値段を写さない。** 掲載画像の値段は国ごとに違って見え、
          // 改定のたびに嘘になる(App Review 2.3 でも避けるよう求められる)。
          for (final t in find.byType(Text).hitTestable().evaluate()) {
            final s = (t.widget as Text).data ?? '';
            expect(s.contains(RegExp(r'[¥￥\$]\s?\d')), isFalse,
                reason: '${shot.name} に値段らしきもの「$s」が写っている');
          }

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../../marketing/$outDir/${shot.name}.png'),
          );
        }
        debugDisableShadows = true;
      });
    }
  }
}

class _StubPurchaseService implements PurchaseService {
  /// 受け取り口。本物は待っているかどうかに関係なく呼ぶ。
  @override
  set onDelivered(
          Future<void> Function(String productId, String? purchaseId)?
              callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId, String? purchaseId)?
      onDeliveredCallback;

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<String?> priceLabel() async => null;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}
