import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/game/pitch_game.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/theme/club_palette.dart';

void main() {
  group('クラブカラー', () {
    test('同じクラブなら常に同じ色になる', () {
      final a = ClubPalette.of('team-7');
      final b = ClubPalette.of('team-7');
      expect(a.base, b.base);
      expect(a.accent, b.accent);
      expect(a.kit, b.kit);
    });

    test('ユニフォームは芝の上で沈まない明るさになっている', () {
      // 芝は 0xFF20642A〜0xFF2C7C36。エンブレムの地の色をそのまま
      // ピッチに置くと、暗い色のクラブが芝と同化して選手が見えなくなる。
      for (final id in const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        final palette = ClubPalette.of(id);
        final kitLightness = HSLColor.fromColor(palette.kit).lightness;
        final baseLightness = HSLColor.fromColor(palette.base).lightness;
        expect(kitLightness, greaterThan(baseLightness),
            reason: '$id のユニフォームがエンブレムの地の色より暗い');
        expect(kitLightness, greaterThan(0.5), reason: '$id のユニフォームが暗すぎる');
      }
    });

    test('キーパーは自チームの選手と見分けがつく', () {
      // 固定色にしていたら、色が近いクラブのときに味方と同化した。
      for (var hue = 0.0; hue < 360; hue += 15) {
        final p = ClubPalette.fromHue(hue);
        final gap = ClubPalette.hueDistance(
          HSLColor.fromColor(p.keeperKit).hue,
          HSLColor.fromColor(p.kit).hue,
        );
        expect(gap, greaterThan(90), reason: '色相$hue でキーパーが味方と近すぎる');
      }
    });

    test('色が近いクラブ同士でも、アウェイ側の色をずらして見分けられる', () {
      // クラブの色はIDから決まるので、青いクラブ同士の対戦は普通に起きる。
      for (var hue = 0.0; hue < 360; hue += 15) {
        final home = ClubPalette.fromHue(hue);
        // 最悪の場合(まったく同じ色)を入れる。
        final away = ClubPalette.fromHue(hue).distinguishedFrom(home);
        expect(
          ClubPalette.hueDistance(away.hue, home.hue),
          greaterThanOrEqualTo(ClubPalette.minimumHueSeparation),
          reason: '色相$hue の同士討ちで両チームが同じ色になる',
        );
      }
    });

    test('もともと離れている色は、ずらさずそのまま使う', () {
      // 必要もないのに色を変えると、エンブレムとユニフォームがずれる。
      final home = ClubPalette.fromHue(0);
      final away = ClubPalette.fromHue(180);
      expect(away.distinguishedFrom(home).hue, away.hue);
    });

    test('色の導出は1箇所にまとめられている', () {
      // エンブレムとピッチが別々に色を決めていると、同じクラブなのに
      // 画面ごとに色が変わる。実際そうなっていたので ClubPalette に寄せた。
      final emblem = File('lib/widgets/club_emblem.dart').readAsStringSync();
      expect(emblem, contains('ClubPalette.of(teamId)'));
      expect(emblem, isNot(contains('HSLColor.fromAHSL')),
          reason: 'エンブレムが色を自前で計算している(ClubPalette と二重になる)');
    });
  });

  group('ピッチの布陣', () {
    test('11人で、ゴールキーパーはちょうど1人', () {
      expect(PitchGame.formation.length, 11);
      expect(PitchGame.formation.where((s) => s.keeper).length, 1);
    });

    test('自陣の側に収まっている', () {
      // 正規化座標をそのまま左右反転して相手チームを置いているので、
      // ハーフウェイラインを越える選手がいると両チームが重なって描かれる。
      for (final slot in PitchGame.formation) {
        expect(slot.x, lessThan(0.6), reason: '$slot が中央より前に出ている');
        expect(slot.x, greaterThan(0.0));
        expect(slot.y, inInclusiveRange(0.05, 0.95));
      }
    });

    test('キーパーが一番後ろにいる', () {
      final keeper = PitchGame.formation.firstWhere((s) => s.keeper);
      for (final other in PitchGame.formation.where((s) => !s.keeper)) {
        expect(keeper.x, lessThan(other.x));
      }
    });
  });

  group('進行', () {
    test('区間の終わりまで進めるとイベントが出尽くし、終了が通知される', () async {
      // 描画を作り込んだあとも、実況を出す・終わりを知らせるという
      // 本来の役目が壊れていないことを固定する。
      final seen = <int>[];
      var finished = false;
      final game = PitchGame(
        events: [
          MatchEvent(minute: 10, teamId: 'home'),
          MatchEvent(minute: 30, teamId: 'away'),
        ],
        startMinute: 1,
        endMinute: 45,
        durationSeconds: 1,
        onEvent: (e) => seen.add(e.minute),
        onFinished: () => finished = true,
        homeTeamId: 'home',
        awayTeamId: 'away',
      );
      game.onGameResize(Vector2(320, 180));
      await game.onLoad();

      for (var i = 0; i < 40; i++) {
        game.update(0.05);
      }

      expect(seen, [10, 30]);
      expect(finished, isTrue);
    });

    test('チームIDを渡さなくても動く', () async {
      // 既存の呼び出し元を壊さないための確認。色は既定の青/赤になる。
      var finished = false;
      final game = PitchGame(
        events: const [],
        durationSeconds: 0.5,
        onEvent: (_) {},
        onFinished: () => finished = true,
      );
      game.onGameResize(Vector2(320, 180));
      await game.onLoad();
      for (var i = 0; i < 20; i++) {
        game.update(0.05);
      }
      expect(finished, isTrue);
    });
  });
}
