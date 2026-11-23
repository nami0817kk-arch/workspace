import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 生き延びて元服まで進める生まれを探して始める。
Game _survivor(int seed) {
  final rng = Rng(seed);
  var g = Game(rng: rng);
  var guard = 0;
  do {
    g = Game(rng: rng);
    g.start(rollBirth(rng));
  } while (g.finished && guard++ < 50);
  return g;
}

/// 生まれたばかりの人生を、指定の歳にして返す（旗だけを立てて行を確かめる用）。
Game _at(int seed, int age) {
  final g = _survivor(seed);
  g.l.t = age * 2;
  return g;
}

List<String> _ids(Game g) => [for (final r in rememberedEntries(g)) r.id];

/// 旗の名でなく、条件から作った行の id。
const _derived = {
  'focus_tera',
  'focus_dojo',
  'focus_abacus',
  'focus_manners',
  'focus_friend',
  'child_osananajimi',
  'river_rescue',
  'tal_fushin_castle',
  'tal_fushin_river',
  'tal_kenchi_hard',
  'tal_kenchi_new',
  'ps_meibutsu_kept',
  'bd_ms_keepsake_sword',
  'bd_ms_keepsake_book',
  'rg_fuji_top',
  'rg_fuji_half',
  'os_lifelong',
  'sp_close',
  'many_kids',
  'grandchild',
};

final _digits = RegExp('[0-9０-９]');

void main() {
  test('遺されたものの表: 候補が80以上・id が重複しない・旗の行は旗がゲームにある', () {
    expect(kRemembrances.length, greaterThanOrEqualTo(80));
    final ids = kRemembrances.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id の重複');
    expect(kRemembrances.where((r) => r.child).length, greaterThanOrEqualTo(20));
    final src = Directory('lib/engine')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('remembrance.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    for (final id in ids) {
      if (_derived.contains(id)) continue;
      expect(src.contains("'$id'"), isTrue, reason: '旗 $id がゲームのどこにもない');
    }
  });

  test('ランダムな人生を流しても、遺されたものは最大5行・重複なし・空なし・数字なし', () {
    var withLine = 0, adults = 0, adultWithLine = 0, total = 0;
    for (var i = 0; i < 400; i++) {
      final rng = Rng(9000 + i);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final pick = Rng(7000 + i);
      var n = 0;
      while (!g.finished && n++ < 1500) {
        final p = g.prompt!;
        final k = i.isEven
            ? pick.range(0, p.choices.length - 1)
            : pickAmbitious(g, p, pick);
        g.choose(k);
      }
      final lines = remembrances(g);
      total++;
      expect(lines.length, lessThanOrEqualTo(kRemembranceMax));
      expect(lines.toSet().length, lines.length, reason: '重複: $lines');
      for (final s in lines) {
        expect(s.trim(), isNotEmpty);
        expect(_digits.hasMatch(s), isFalse, reason: '数字: $s');
        expect(s.contains(r'$'), isFalse, reason: '差し込み漏れ: $s');
      }
      final entries = rememberedEntries(g);
      final groups = entries.map((e) => e.group).whereType<String>().toList();
      expect(groups.toSet().length, groups.length, reason: '同じ組から二行');
      for (var j = 1; j < entries.length; j++) {
        expect(entries[j - 1].weight >= entries[j].weight, isTrue);
      }
      if (g.age < 15) {
        expect(entries.every((e) => e.child), isTrue, reason: '子どもに大人の行');
      } else {
        adults++;
        if (lines.isNotEmpty) adultWithLine++;
      }
      if (lines.isNotEmpty) withLine++;
    }
    // ignore: avoid_print
    print('【遺されたもの】$total人生のうち1行以上 $withLine'
        '（成人 $adults人生のうち $adultWithLine）');
    expect(withLine, greaterThan(total ~/ 3));
  });

  test('何もない人生は空', () {
    final g = _at(1, 30);
    g.l.flags.clear();
    g.l.people.clear();
    g.l.focus.clear();
    g.l.kids = 0;
    expect(remembrances(g), isEmpty);
  });

  test('旗を立てると、その行が出る', () {
    void expectLine(String flag, String id, String part, {int age = 40}) {
      final g = _at(3, age);
      g.setFlag(flag);
      expect(_ids(g), contains(id), reason: flag);
      expect(remembrances(g).any((s) => s.contains(part)), isTrue, reason: flag);
    }

    expectLine('tal_tenka_ichi', 'tal_tenka_ichi', '天下一');
    expectLine('tal_ikki_head', 'tal_ikki_head', '一揆の頭');
    expectLine('ps_hawk_kind', 'ps_hawk_kind', '詫びの銭');
    expectLine('wl_hid_hime', 'wl_hid_hime', '落ち延びた姫');
    expectLine('rg_aki_fune', 'rg_aki_fune', '厳島');
    expectLine('bt_rearguard_done', 'bt_rearguard_done', '殿を務め');
    expectLine('tm_orphans', 'tm_orphans', '親を亡くした子ら');
    expectLine('fa_kakun', 'fa_kakun', '家の掟');
    expectLine('bd_rv_mourned', 'bd_rv_mourned', '棺');
  });

  test('幼なじみ・師・連れ合いの名が行に入る', () {
    final g = _at(4, 50);
    g.meet('幼なじみ', '与一', 70);
    g.setFlag('bd_os_close');
    expect(remembrances(g), contains('幼なじみの与一とは、最後まで盃を交わす仲だった。'));

    final h = _at(5, 50);
    h.setFlag('bd_ms_dead');
    h.setFlag('bd_ms_name:源斎');
    h.setFlag('bd_ms_keepsake');
    h.mark('師の源斎から、形見の刀を託された');
    expect(remembrances(h), contains('師の源斎の形見の刀を、生涯手放さなかった。'));
    // 教えを伝える約束（同じ旗 bd_ms_keepsake も立つ）は、形見を持ち続けた行にしない。
    h.setFlag('bd_ms_vow');
    expect(_ids(h), isNot(contains('bd_ms_keepsake_sword')));
    expect(_ids(h), contains('bd_ms_vow'));

    final k = _at(6, 60);
    k.l.married = true;
    k.meet('伴侶', 'お菊', 60);
    k.setFlag('bd_sp_promise');
    k.setFlag('bd_sp_promise_kept');
    final ls = remembrances(k);
    expect(ls.any((s) => s.contains('お菊') && s.contains('約束を果たし')), isTrue);
    expect(ls.any((s) => s.contains('果たせぬまま')), isFalse);
  });

  test('同じ旗でも、歩んだ道の文で中身を見分ける（縄張りと堤・名物を差し出したか）', () {
    final a = _at(7, 40);
    a.setFlag('tal_fushin');
    a.mark('出城の縄張りを任され、守りの堅い城を築いた');
    expect(_ids(a), contains('tal_fushin_castle'));
    expect(_ids(a), isNot(contains('tal_fushin_river')));

    final b = _at(8, 40);
    b.setFlag('tal_fushin');
    b.mark('暴れ川の堤を工夫し、村の田を守った');
    expect(_ids(b), contains('tal_fushin_river'));

    final c = _at(9, 40);
    c.setFlag('ps_meibutsu');
    expect(_ids(c), contains('ps_meibutsu_kept'));
    c.setFlag('e2_gave_meibutsu');
    expect(_ids(c), isNot(contains('ps_meibutsu_kept')));
    expect(_ids(c), contains('e2_gave_meibutsu'));
  });

  test('重みの高い順に最大5行、同じ組からは一行', () {
    final g = _at(10, 55);
    for (final f in [
      'bd_rv_mourned',
      'bd_rv_kin',
      'bd_rv_cup',
      'tal_tenka_ichi',
      'tal_ikki',
      'tal_chorayaku',
      'tal_night_raid',
      'bt_slew_general',
      'tm_orphans',
      'fa_hostage_rescued',
      'ps_wish_home',
    ]) {
      g.setFlag(f);
    }
    final ids = _ids(g);
    expect(ids.length, kRemembranceMax);
    expect(ids.first, 'tal_tenka_ichi');
    expect(ids.where((i) => i.startsWith('bd_rv_')).length, 1);
    expect(ids.contains('tal_ikki'), isFalse, reason: '同じ組（武）は天下一の一行だけ');
    expect(ids.contains('ps_wish_home'), isFalse, reason: '軽い行は押し出される');
  });

  test('子どもで亡くなったときは、子ども向けの行だけ', () {
    final g = _at(11, 10);
    g.setFlag('tal_tenka_ichi');
    g.setFlag('bd_os_close');
    g.setFlag('tera_diligent');
    g.setFlag('tal_c_white_deer');
    final ids = _ids(g);
    expect(ids, containsAll(['tal_c_white_deer', 'tera_diligent']));
    expect(ids.contains('tal_tenka_ichi'), isFalse);
    expect(ids.contains('bd_os_close'), isFalse);

    final y = _at(12, 3);
    y.l.flags.clear();
    y.l.people.clear();
    y.l.focus.clear();
    expect(remembrances(y), isEmpty);
  });
}
