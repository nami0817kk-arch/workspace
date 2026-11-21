/// 外に送る1枚と、その文。
///
/// **送るものは、送る前に全部決まっていないといけない。** 端末の幅で
/// 中身が変わったり、ストアの住所が落ちたりすると、広めるための1枚が
/// 広める役に立たなくなる。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/look.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/share/share_service.dart';
import 'package:soccer_career/ui/share_card.dart';
import 'package:soccer_career/ui/share_sheet.dart';

/// 送られたものを控えるだけの偽物。
class _FakeShareService implements ShareService {
  String? text;
  Uint8List? image;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> share({
    required String text,
    Uint8List? image,
    String fileName = 'career.png',
    Rect? origin,
  }) async {
    calls++;
    this.text = text;
    this.image = image;
  }
}

Legend _legend({
  String name = '結城 遼',
  int appearances = 412,
  int goals = 136,
  int caps = 38,
  int leagueTitles = 4,
  int cupTitles = 0,
  int continentalTitles = 0,
  bool tampered = false,
}) => Legend(
  name: name,
  positionLabel: 'CM',
  retiredYear: 2044,
  retiredAge: 35,
  seasons: 18,
  appearances: appearances,
  goals: goals,
  assists: 170,
  averageRating: 7.24,
  caps: caps,
  internationalGoals: 12,
  peakOverall: 82,
  potential: 85,
  spells: const [
    LegendSpell(clubName: 'ゾンネ04', seasons: 6, tier: 2, countryId: 'albion'),
    LegendSpell(clubName: 'トヨヴィエント', seasons: 12, tier: 1, countryId: 'albion'),
  ],
  awards: const [],
  traits: const [],
  leagueTitles: leagueTitles,
  cupTitles: cupTitles,
  continentalTitles: continentalTitles,
  worldCupBest: WorldCupStage.none,
  bestTier: 1,
  clubId: 'albion-t1-c0',
  look: const PlayerLook(),
  squadNumber: 10,
  secondCareer: SecondCareer.manager,
  tampered: tampered,
  recordedAt: 0,
);

void main() {
  group('送る文', () {
    test('札とストアの住所で締める', () {
      final text = ShareText.compose(['一行目', '', '三行目']);
      final lines = text.split('\n');
      // 空の行は落ちる。
      expect(lines, ['一行目', '三行目', ShareText.tag, ShareText.storeUrl]);
    });

    test('キャリアの1枚の文に、通算の数字とストアの住所が入る', () {
      final text = CareerShareCard(legend: _legend()).text;
      expect(text, contains('412試合'));
      expect(text, contains('136ゴール'));
      expect(text, contains('代表38キャップ'));
      expect(text, contains('リーグ優勝 4回'));
      // **住所が無ければ、見た人が辿れない。**
      expect(text, contains(ShareText.storeUrl));
    });

    test('タイトルの無いキャリアは、優勝の行を書かない', () {
      final text = CareerShareCard(legend: _legend(leagueTitles: 0)).text;
      expect(text, isNot(contains('リーグ優勝')));
      expect(text, contains(ShareText.storeUrl));
    });

    test('季の1枚の文に、成したことと成績が入る', () {
      final card = SeasonShareCard(
        club: const Club(
          id: 'albion-t1-c0',
          name: 'トヨヴィエント',
          strength: 70,
          tier: 1,
        ),
        year: 2038,
        tier: 1,
        leaguePosition: 1,
        stats: const SeasonStats(
          appearances: 34,
          goals: 12,
          assists: 15,
          averageRating: 7.38,
        ),
        look: const PlayerLook(),
        squadNumber: 10,
        playerName: '結城 遼',
        headline: '1部 優勝',
      );
      expect(card.text, contains('1部 優勝'));
      expect(card.text, contains('34試合'));
      expect(card.text, contains('7.38'));
      expect(card.text, contains(ShareText.storeUrl));
    });
  });

  group('送る1枚', () {
    testWidgets('大きさは端末によらず決め打ち', (tester) async {
      // **ここが画面の幅に追従すると、送られる画像の中身が端末ごとに
      // 変わる**（文の折り返しも数字の大きさも）。
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FittedBox(child: CareerShareCard(legend: _legend())),
          ),
        ),
      );
      final size = tester.getSize(
        find.byType(CareerShareCard, skipOffstage: false),
      );
      expect(size, const Size(cardWidth, cardHeight));
    });

    testWidgets('アプリの名前が入っている', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FittedBox(child: CareerShareCard(legend: _legend())),
          ),
        ),
      );
      expect(find.text(ShareText.appName), findsOneWidget);
    });

    testWidgets('無冠のキャリアでも、そう書いて1枚になる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FittedBox(
              child: CareerShareCard(legend: _legend(leagueTitles: 0)),
            ),
          ),
        ),
      );
      expect(find.text('無冠のキャリア'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('送るところ', () {
    testWidgets('押すまで何も送らない', (tester) async {
      final fake = _FakeShareService();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showShareSheet(
                    context,
                    card: CareerShareCard(legend: _legend()),
                    text: 'ためしの文',
                    service: fake,
                  ),
                  child: const Text('開く'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      // 開いただけでは送らない。
      expect(fake.calls, 0);
      expect(find.text('送る'), findsOneWidget);

      // **画像にするのは本物の非同期**（`RepaintBoundary.toImage`）なので、
      // テストの疑似時計の中では終わらない。`runAsync` の中で待つ
      // （`test/shots.dart` が PNG を書き出すときと同じ理屈）。
      await tester.runAsync(() async {
        await tester.tap(find.text('送る'));
        for (var i = 0; i < 100 && fake.calls == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      expect(fake.calls, 1);
      expect(fake.text, 'ためしの文');
      // 画像まで渡っていること。**文だけでは広まらない。**
      expect(fake.image, isNotNull);
      expect(fake.image!.lengthInBytes, greaterThan(0));
    });
  });
}
