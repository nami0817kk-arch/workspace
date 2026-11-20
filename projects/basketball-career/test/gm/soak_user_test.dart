import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通し試験(2026-11-20、ユーザー「バグがないか確認して」): ユーザーが触れる操作を乱数でばらばらに押しながら何年も進め、
/// 1手ごとに保存→読み直しをはさむ。落ちないこと・選手が重ならないこと・止まらずに進むことを見る。
Career _reload(Career c) => Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);

void _check(Career c, String where) {
  final ids = <int>[];
  for (final t in c.teams) {
    ids.addAll(t.roster.map((p) => p.id));
    ids.addAll(t.twoWay.map((p) => p.id));
  }
  ids.addAll(c.freeAgents.map((p) => p.id));
  final dup = ids.length - ids.toSet().length;
  expect(dup, 0, reason: '$where: 同じ選手が2か所にいる');
  for (final id in c.camp.keys) {
    expect([...c.me.roster, ...c.me.twoWay].any((p) => p.id == id), isTrue, reason: '$where: 個人練習の選手がチームにいない');
  }
}

void _answerAll(Career c, Random r) {
  for (final m in [...c.inbox]) {
    if (m.needsAnswer) c.answer(m.id, r.nextInt(m.choices.length));
  }
}

void _userActions(Career c, Random r) {
  _answerAll(c, r);
  if (c.phase == Phase.contracts || c.phase == Phase.preseason) {
    if (r.nextBool()) c.playSummerLeague();
    final ps = [...c.me.roster];
    if (ps.isNotEmpty && r.nextBool()) c.setCamp(ps[r.nextInt(ps.length)].id, Attr.values[r.nextInt(Attr.values.length)]);
    final vets = ps.where(c.mentorVet).toList(), young = ps.where(c.mentorYoung).toList();
    if (vets.isNotEmpty && young.isNotEmpty && r.nextBool()) c.setMentor(vets[r.nextInt(vets.length)].id, young[r.nextInt(young.length)].id);
    if (r.nextInt(4) == 0) c.clearMentor();
    final fa = [...c.freeAgents]..sort((a, b) => b.ovr - a.ovr);
    for (final p in fa.take(2)) {
      if (r.nextBool()) c.pitch(p.id, r.nextInt(Career.pitchLines.length));
    }
    if (c.calls.isNotEmpty) {
      if (r.nextBool()) {
        c.acceptCall(r.nextInt(c.calls.length));
      } else {
        c.declineCall(r.nextInt(c.calls.length));
      }
    }
  }
}

void _step(Career c, Random r) {
  switch (c.phase) {
    case Phase.season:
      final o = c.incoming;
      if (o != null && r.nextBool()) c.acceptIncoming();
      switch (r.nextInt(4)) {
        case 0:
          c.playDays(1 + r.nextInt(9));
        case 1:
          final g = c.nextMyGame;
          if (g != null) {
            final calls = List<GameCall?>.generate(liveBreaks.length, (_) => r.nextBool() ? GameCall.values[r.nextInt(GameCall.values.length)] : null);
            c.previewLive(calls, null);
            c.playLiveDay(calls);
          } else {
            c.playBlock();
          }
        default:
          c.playBlock();
      }
    case Phase.playoffs:
      if (!c.poLive && r.nextInt(3) > 0) {
        c.startPlayoffs();
      } else if (!c.poLive) {
        c.playPlayoffs();
      } else {
        switch (r.nextInt(5)) {
          case 0:
            c.playPlayoffSeries();
          case 1:
            c.playPlayoffs();
          case 2:
            final calls = List<GameCall?>.generate(liveBreaks.length, (_) => r.nextBool() ? GameCall.values[r.nextInt(GameCall.values.length)] : null);
            if (c.nextMyGame != null) {
              c.previewLive(calls, null);
              c.playLiveDay(calls);
            } else {
              c.playPlayoffGame();
            }
          default:
            c.playPlayoffGame();
        }
      }
    default:
      botStep(c, trades: true);
  }
}

void main() {
  for (final seed in [11, 12, 13, 14, 15, 16]) {
    test('通し試験 seed $seed: 操作をばらばらに押して8年進めても落ちない', () {
      final r = Random(seed);
      var c = Career.start(seed: seed, team: seed % 30);
      var guard = 0;
      while (c.phase != Phase.over && c.history.length < 8) {
        expect(guard++ < 4000, isTrue, reason: '進まない(${c.phase} season ${c.season} round ${c.roundAt})');
        final before = '${c.phase}/${c.season}';
        _userActions(c, r);
        _step(c, r);
        _check(c, '$before → ${c.phase}');
        if (r.nextInt(3) == 0) {
          c = _reload(c);
          _check(c, '読み直し ${c.phase}');
        }
      }
      // 解任されて終わることはある(成績の決まりどおり)。それ以外は8年進む
      expect(c.history.length >= 8 || c.phase == Phase.over, isTrue);
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
