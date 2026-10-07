/// ストア掲載用のスクリーンショットを生成する。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 生成器だからで、実行するとファイルを書き換える。
///
///     flutter test tool/screenshots/capture_test.dart
///
/// 手で撮らずにここで作る理由:
///
/// - ストアが求める寸法（iPhone 6.7インチ = 1290x2796、iPad 13インチ =
///   2064x2752）を確実に満たせる。実機やシミュレータの画面写しは端末ごとに
///   寸法が違い、App Store はそこを機械で弾く。
/// - 文言や見た目を直したあと、同じ内容で撮り直せる。
///
/// `test/shots.dart` とは役目が違う。あちらは**崩れを見つけるための道具**で、
/// 390x1500 のような実在しない画面で撮る。こちらは**ストアに出す絵**で、
/// 実在する端末の寸法でしか撮らない。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではない
// コード」になる。実体は flutter test で走らせる生成器で、テストと同じ立場で
// アプリを組み立てる。
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/app_theme.dart';
import 'package:soccer_career/ui/club_identity.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:soccer_career/ui/screens/hall_screen.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';
import 'package:soccer_career/ui/screens/season_end_screen.dart';

/// 撮る端末の寸法。
///
/// App Store は iPhone と iPad のそれぞれで求める。`TARGETED_DEVICE_FAMILY`
/// が "1,2"（iPhone と iPad の両方）なので、iPhone だけでは
/// 「13インチのiPadディスプレイのスクリーンショットをアップロードする
/// 必要があります」で提出できない（`soccer-manager` で実際に止まった）。
typedef Device = ({String dir, Size logical, double ratio});

/// iPhone 6.7インチ = 1290x2796。
const phone = (dir: 'screenshots', logical: Size(430, 932), ratio: 3.0);

/// iPad 13インチ = 2064x2752。
const tablet = (
  dir: 'screenshots_ipad',
  logical: Size(1032, 1376),
  ratio: 2.0,
);

const devices = <Device>[phone, tablet];

/// 撮る順番と、上に載せる一行。**ストアでは1枚目しか見られないことが多い**ので、
/// このゲームの核（試合中の選択）を先頭に置く。
const captions = <String, String>{
  // **1枚目は「何のゲームか」から書く。** 以前は「試合は、選ぶことでしか
  // 動かない」だった。中身は言い当てているが、一覧で初めて見た人には
  // 何の試合か分からない。
  '01-match': 'サッカー選手の人生を、1試合ずつ選ぶ',
  '02-create': '自分の選手を、ひとりつくる',
  '03-week': '今週、何に時間を使うか',
  '04-player': '伸びたところが、数字で残る',
  '05-develop': '狙った技だけが、身につく',
  '06-world': '上には、まだ何部もある',
  '07-season': '1年ぶんの答えが出る',
  '08-hall': '終わったあとに、記録が残る',
};

final shotKey = GlobalKey();

/// 書き出した名前。**撮れていないことは、撮った絵を見るまで分からない。**
final written = <String>{};

class _Repo implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

/// 引退させる画面は、これを渡さないと保存領域を待って止まる。
class _Hall implements HallRepository {
  Hall _saved = const Hall();

  @override
  Future<Hall> load() async => _saved;

  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

/// 同梱フォントと、Flutter SDK が持つアイコンフォントを読み込む。
///
/// **アイコンフォントを読まないと、画面のアイコンが全部豆腐（□）になる。**
/// ウィジェットテストの既定では読み込まれない。`soccer-manager` の掲載画像が
/// 実際にそうなっていた。
Future<void> loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('NotoSansJP');
  for (final path in [
    'assets/fonts/NotoSansJP-Regular.ttf',
    'assets/fonts/NotoSansJP-Bold.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) fail('同梱フォントが見つからない: $path');
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await loader.load();

  final icons = File(_materialIconsPath());
  if (!icons.existsSync()) {
    fail(
      'アイコンフォントが見つからない: ${icons.path}\n'
      'FLUTTER_ROOT を設定して実行してください。'
      'このまま撮ると、全アイコンが豆腐（□）で写ります。',
    );
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await iconLoader.load();
}

String _materialIconsPath() {
  // flutter test は FLUTTER_ROOT を渡してくる。渡ってこない実行のために、
  // 動いている Dart の位置からも辿れるようにしておく。
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  return '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
}

/// アプリの地の色。**帯はどの絵でもこの色**にする。クラブの色をそのまま
/// 使っていたら、移籍した季を撮った途端に帯だけ別の色になった。
const brandSeed = Color(0xFF1B5E3F);

ThemeData get bandTheme =>
    appTheme(brandSeed, Brightness.light, fontFamily: 'NotoSansJP');

/// アプリと同じテーマで撮る。自前で組むと、テーマに足したものが絵に出ない。
ThemeData themeFor(dynamic club) =>
    appTheme(ClubIdentity.of(club).primary, Brightness.light,
        fontFamily: 'NotoSansJP');

/// 一行の帯を上に置いて、その下にアプリの画面をそのまま出す。
///
/// 帯の高さと文字は**端末の幅に比例させる**。固定値にしていたときは、
/// iPhone で2行に折り返して下の行が帯からはみ出し、iPad では文字が
/// 豆粒になった（どちらも撮った絵を見るまで気付かなかった）。
/// `FittedBox` を噛ませてあるので、長い一行は縮んで必ず1行に収まる。
Future<void> pump(
  WidgetTester tester,
  Device device,
  Widget screen,
  ThemeData theme,
  String caption,
) async {
  final width = device.logical.width;
  await tester.pumpWidget(
    RepaintBoundary(
      key: shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Material(
          color: bandTheme.colorScheme.primary,
          child: Column(
            children: [
              SizedBox(
                height: width * 0.223,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.056,
                    0,
                    width * 0.056,
                    width * 0.019,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        caption,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: width * 0.060,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: bandTheme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: screen),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> dump(WidgetTester tester, Device device, String name) async {
  await tester.runAsync(() async {
    final boundary =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: device.ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('marketing/${device.dir}')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    written.add('${device.dir}/$name');
    print('wrote marketing/${device.dir}/$name.png '
        '(${image.width}x${image.height})');
  });
}

/// 局面が立つ週まで進めてから、試合を組む。
///
/// **出られない週に `startNextMatch` を呼ぶと、局面ゼロの「終わった試合」が
/// 返る。** 離脱・出場停止・登録外・構想外のどれでもそうなる。気付かずに
/// 真っ白な主画面を書き出していたことがある（`test/shots.dart` の注記）。
Future<void> startPlayableMatch(CareerController controller) async {
  for (var i = 0; i < 80; i++) {
    while (controller.state!.pendingInternational ||
        controller.state!.pendingCup != null) {
      await controller.simulateMatch();
    }
    if (controller.state!.seasonFinished || controller.state!.retired) break;
    controller.startNextMatch();
    final match = controller.currentMatch;
    if (match != null && !match.isFinished) return;
    await controller.simulateMatch();
  }
  fail('局面の立つ試合に辿り着けなかった');
}

/// 撮影に使うキャリア。**種は固定**（`tool/screenshots/probe_test.dart` で
/// 8通り回して選んだ）。この種は 2部11位 → 4位 → 8位 → 1部2位 → 3位 と上がり、
/// 総合力が 61 から 79 まで伸びる。
///
/// 1季目を撮っていた頃は、**20クラブ中19位・0ゴール・「監督の期待には
/// 届かなかった」** がシーズン総括の絵として出ていた。嘘は無いが、
/// ストアの1枚として出すものではない。
const captureSeed = 17;

/// 何季進めてから撮るか。3季目は1部の上位クラブに移った年にあたる。
const captureSeason = 3;

Future<CareerController> newCareer({int seed = captureSeed}) async {
  final controller = CareerController(
    repository: _Repo(),
    hallRepository: _Hall(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await controller.startCareer(
    name: '新堂 陽',
    position: Position.cm,
    age: 18,
    agent: Agent.pool.first,
  );
  return controller;
}

/// 今季を最後まで進める。
Future<void> finishSeason(CareerController controller) async {
  while (!controller.state!.seasonFinished && !controller.state!.retired) {
    if (controller.pendingEvent != null) {
      await controller.resolveEvent(controller.pendingEvent!.choices.first);
    }
    await controller.simulateMatch();
  }
}

/// 来季へ移る。格と年俸で選ぶ（`test/support/career_sim.dart` と同じ選び方）。
/// 話が1つも来なければ false を返す。
Future<bool> nextSeason(CareerController controller) async {
  final offers = [
    if (controller.renewalOffer != null) controller.renewalOffer!,
    ...controller.offers,
  ];
  if (offers.isEmpty) return false;
  final ranked = [...offers]
    ..sort((a, b) {
      int score(TransferOffer o) =>
          (o.loan ? -5000 : 0) + o.salary + (4 - o.club.tier) * 800;
      return score(b).compareTo(score(a));
    });
  await controller.advanceSeason(
    accepted: ranked.first,
    offseason: Offseason.sharpen,
  );
  return true;
}

/// タブを開き、節に割れているタブでは札も押す。
Future<void> openTab(WidgetTester tester, String tab, [String? section]) async {
  await tester.tap(find.widgetWithText(Tab, tab));
  await tester.pumpAndSettle();
  if (section != null) {
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }
}

/// 1台ぶんを撮る。
///
/// **影の描き方をここで戻している。** テストの既定（`debugDisableShadows`）
/// では影が「ぼかさない真っ黒」になり、右下のボタンが黒い輪で囲まれたように
/// 写る。焦点の輪だと思って焦点のほうをいじっていたが、原因は影だった。
/// 枠組みはテスト本体を抜けた時点で「描画の設定を戻したか」を検査するので、
/// 後片付け（`addTearDown`）では間に合わない。
Future<void> capture(WidgetTester tester, Device device) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = device.ratio;
  tester.view.physicalSize = device.logical * device.ratio;

  final controller = await newCareer();
  // 何季か進めてから撮る。1季目は順位も記録も空に近く、
  // シーズン総括が「期待には届かなかった」の絵になる。
  for (var season = 0; season < captureSeason; season++) {
    await finishSeason(controller);
    if (!await nextSeason(controller)) fail('移籍の話が来ない');
  }
  // 節を進めて、順位表と記録に中身を入れる。
  for (var i = 0; i < 12; i++) {
    if (controller.pendingEvent != null) {
      await controller.resolveEvent(controller.pendingEvent!.choices.first);
    }
    await controller.simulateMatch();
  }
  // 代表ウィークで止まっていると、次節の対戦が出ない。
  while (controller.state!.pendingInternational ||
      controller.state!.pendingCup != null) {
    await controller.simulateMatch();
  }
  // 育てる方向は既定で空なので、そのままだと育成の「積み上げ」が写らない。
  for (final detail in [
    Detail.finishing,
    Detail.shortPassing,
    Detail.tackling,
  ]) {
    await controller.toggleFocus(detail);
  }

  final theme = themeFor(controller.state!.club);

  // 1枚目。**このゲームの核**なので先頭に置く。
  await startPlayableMatch(controller);
  await pump(
    tester,
    device,
    MatchScreen(controller: controller),
    theme,
    captions['01-match']!,
  );
  await dump(tester, device, '01-match');

  // 選手を作る画面。新しい人が最初に触るところ。
  final fresh = CareerController(
    repository: _Repo(),
    careerEngine: CareerEngine(random: Random(3)),
    matchEngine: MatchEngine(random: Random(3)),
    random: Random(3),
  );
  await pump(
    tester,
    device,
    CreatePlayerScreen(controller: fresh),
    bandTheme,
    captions['02-create']!,
  );
  // 名前の欄が空のまま撮れていた。入れてから撮る。
  await tester.enterText(find.byType(TextField).first, '新堂 陽');
  await tester.pumpAndSettle();
  await dump(tester, device, '02-create');

  // 今週・選手・育成・クラブ。
  await pump(
    tester,
    device,
    HubScreen(controller: controller),
    theme,
    captions['03-week']!,
  );
  await dump(tester, device, '03-week');

  await pump(
    tester,
    device,
    HubScreen(controller: controller),
    theme,
    captions['04-player']!,
  );
  await openTab(tester, '選手', '能力');
  await dump(tester, device, '04-player');

  await pump(
    tester,
    device,
    HubScreen(controller: controller),
    theme,
    captions['05-develop']!,
  );
  await openTab(tester, '育成', '今週決める');
  await dump(tester, device, '05-develop');

  await pump(
    tester,
    device,
    HubScreen(controller: controller),
    theme,
    captions['06-world']!,
  );
  await openTab(tester, 'クラブ', 'この国と、世界');
  await dump(tester, device, '06-world');

  // シーズンの総括。
  await finishSeason(controller);
  // 控えを取っていないと、総括に赤い「セーブの持ち出し」が出る。
  // 促し自体は正しいが、掲載する1枚としては警告の絵になる。
  // **撮るためだけの細工**（`test/shots.dart` の切り札と同じ扱い）。
  controller.state!.backedUpYear = controller.state!.year - 1;
  await pump(
    tester,
    device,
    SeasonEndScreen(controller: controller),
    theme,
    captions['07-season']!,
  );
  await dump(tester, device, '07-season');

  // 殿堂。**最後まで進めてから**引退させる。3季で引退させていた頃は
  // 「通算33試合・ピーク60」が殿堂の絵として出ていた。
  for (var season = 0; season < 20; season++) {
    if (controller.state!.retired) break;
    if (controller.state!.player.age >= 34 && controller.canRetire) break;
    if (!await nextSeason(controller)) break;
    await finishSeason(controller);
  }
  if (!controller.state!.retired) await controller.retire();
  await pump(
    tester,
    device,
    HallScreen(controller: controller),
    theme,
    captions['08-hall']!,
  );
  await dump(tester, device, '08-hall');

  // **撮り漏らしは、絵を見るまで分からない。**
  final missing = captions.keys
  .where((name) => !written.contains('${device.dir}/$name'))
  .toList();
  if (missing.isNotEmpty) {
    fail('撮れていない画面: ${missing.join(", ")}');
  }
}

void main() {
  setUpAll(() async {
    await loadFonts();
    // **触った札の焦点の輪が、右下のボタンに黒枠で写っていた。**
    // 指で触る扱いにしておくと、焦点の輪そのものが出ない。
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  });

  for (final device in devices) {
    testWidgets('ストア用のスクリーンショットを書き出す (${device.dir})', (
      tester,
    ) async {
      debugDisableShadows = false;
      try {
        await capture(tester, device);
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
