import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/promise.dart';
import 'package:flutter_test/flutter_test.dart';

/// 出番の不満の知らせが届くところまで進める(先発の力の選手を控えに回す)。
(Career, Player, Message) _minutesAsk() {
  final c = careerAt(11, 8)..startSeason();
  final p = lineup(c.me.roster)[1];
  p.morale = 40;
  c.setRotation([for (final x in [...c.me.order.where((x) => x != p), p]) x.id]);
  c.playBlock();
  final m = c.inbox.firstWhere((m) => m.kind == MsgKind.minutes && m.player == p.id);
  return (c, p, m);
}

void main() {
  test('「先発に入れる」は約束になり、2区切り先発に置けば守ったことになる。言葉の重みが上がる', () {
    final (c, p, m) = _minutesAsk();
    c.answer(m.id, 0);
    expect(c.openPromises.single.kind, PromiseKind.starter);
    expect(c.openPromises.single.player, p.id);
    p.injured = 0;
    c.playBlock();
    if (c.openPromises.isNotEmpty) {
      p.injured = 0;
      c.playBlock();
    }
    final x = c.promises.first;
    expect(x.state, PromiseState.kept);
    expect(c.word, startWord + wordKept);
    expect(c.inbox.any((m) => m.title.startsWith('約束を守った')), isTrue);
  });

  test('約束したのに先発から外すと破ったことになり、本人とチームの気持ち・言葉の重みが下がる', () {
    final (c, p, m) = _minutesAsk();
    c.answer(m.id, 0);
    final others = [for (final x in c.me.roster) if (x != p) x];
    final otherBefore = {for (final x in others) x.id: x.morale};
    final chemBefore = c.me.chem;
    // 約束のすぐあとに控えへ戻す
    c.setRotation([for (final x in [...c.me.order.where((x) => x != p), p]) x.id]);
    p.injured = 0;
    final before = p.morale;
    c.playBlock();
    expect(c.promises.first.state, PromiseState.broken);
    expect(c.word, startWord - wordBroken);
    expect(c.inbox.any((m) => m.title.startsWith('約束を破った')), isTrue);
    // 区切りの気持ちの動きもあるので、約束の分(-20)が効いていることだけを見る
    expect(p.morale, lessThan(before - 10));
    expect(c.me.chem, lessThan(chemBefore + 3));
    expect(others.where((x) => x.morale < otherBefore[x.id]!).length, greaterThan(others.length ~/ 2));
  });

  test('言葉の重みが低いと、同じ約束でも選手はあまり喜ばない', () {
    final (c, p, m) = _minutesAsk();
    c.word = 0;
    final before = p.morale;
    c.answer(m.id, 0);
    expect(p.morale - before, (15 * wordScale(0)).round());
    expect(wordScale(0), lessThan(wordScale(startWord)));
  });

  test('「相手を探す」は締め切りまでに出せば守り、残したままだと破ったことになる', () {
    for (final trade in [true, false]) {
      final c = careerAt(11, 8)..startSeason();
      final p = c.me.order[3];
      c.inbox.insert(
        0,
        Message(id: 9999, season: c.season, from: Sender.player, title: 'トレードの希望', body: '', kind: MsgKind.tradeRequest, choices: const ['探す', '残す'], player: p.id),
      );
      c.answer(9999, 0);
      expect(c.openPromises.single.kind, PromiseKind.trade);
      if (trade) {
        // 出したことにする(ほかのチームへ移す)
        c.me.roster.remove(p);
        c.teams[(c.mine + 1) % c.teams.length].roster.add(p);
      }
      var guard = 0;
      while (c.openPromises.isNotEmpty && c.phase == Phase.season && guard++ < 5) {
        c.playBlock();
      }
      expect(c.promises.first.state, trade ? PromiseState.kept : PromiseState.broken);
    }
  });

  test('オーナーとの目標の話し合い: 下げると目標と信頼が下がり、上を約束すると目標が上がる。区切りを進めたら答えられない', () {
    for (final choice in [0, 1, 2]) {
      final c = careerAt(4, 12)..startSeason();
      final m = c.inbox.firstWhere((m) => m.kind == MsgKind.ownerGoal);
      expect(m.needsAnswer, isTrue);
      expect(m.choices, hasLength(3));
      final target = c.target, trust = c.trust;
      c.answer(m.id, choice);
      expect(c.goalStance, choice);
      expect(c.target, target + const [0, -5, 4][choice]);
      expect(c.trust, trust - (choice == 1 ? 3 : 0));
    }
    final c = careerAt(4, 12)..startSeason();
    final m = c.inbox.firstWhere((m) => m.kind == MsgKind.ownerGoal);
    final target = c.target;
    c.playBlock();
    expect(m.needsAnswer, isFalse, reason: '答えないまま進めたら受けたことになる');
    expect(m.answer, 0);
    c.answer(m.id, 2);
    expect(c.target, target);
  });

  test('上を約束して果たすと、格の点の内訳に出る', () {
    final c = careerAt(2, 1)..startSeason();
    final m = c.inbox.firstWhere((m) => m.kind == MsgKind.ownerGoal);
    c.answer(m.id, 2);
    // 目標を必ず果たせる数にしてから、シーズンを最後まで進める
    c.target = 1;
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 50) {
      botStep(c);
    }
    expect(c.lastRating.any((r) => r.label.contains('オーナーに約束した')), isTrue);
  });

  test('約束と言葉の重みは保存しても残る', () {
    final (c, _, m) = _minutesAsk();
    c.answer(m.id, 0);
    c.word = 63;
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.word, 63);
    expect(back.promises.single.line, c.promises.single.line);
    expect(back.promises.single.due, c.promises.single.due);
    expect(back.goalStance, c.goalStance);
  });
}
