import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/pilot.dart';

/// 通しの点検。画面を実際に押して遊ぶ役（test/support/pilot.dart）が、日本語と英語で、
/// 1980年・2000年・2025年のそれぞれを、はじめの画面から人が押す道筋で進める。
/// 途中で見つけた例外・はみ出し・押せないボタン・閉じられない小窓・壊れた数字・文の抜け・値段の食い違いは、1つでもあれば落ちる。
///
/// CI では1本を短く（[_years] 年）回す。20年ぶんの通しは、環境変数を渡したときだけ回す:
///   QUAD_PILOT_YEARS=20 flutter test test/playthrough_test.dart
final _years = int.tryParse(Platform.environment['QUAD_PILOT_YEARS'] ?? '') ?? 4;

void main() {
  for (final lang in const ['ja', 'en']) {
    for (final c in const [(1980, 'world', 'jp', 11), (2000, 'world', 'us', 23), (2025, 'endless', 'jp', 35)]) {
      testWidgets('通しの点検：${c.$1}年から$_years年（$lang）', (tester) async {
        final p = await Pilot.launch(tester, lang: lang, seed: c.$4);
        await p.play(year: c.$1, years: _years, mode: c.$2, home: c.$3, traits: c.$1 == 2000 ? const ['genius', 'gambler'] : const ['charm', 'careful']);
        final sw = p.seen.entries.map((e) => '${e.key}×${e.value}').join('、');
        // ignore: avoid_print
        print('通しの点検 ${c.$1} $lang: ${p.ctl.game?.year}年${p.ctl.game?.q}月まで。$sw / pump ${p.pumps}回 ${p.swPump.elapsedMilliseconds}ms・check ${p.swCheck.elapsedMilliseconds}ms・ひと回り ${p.tourMs}ms${p.shareSumOff == null ? '' : '・株主の割合のずれ ${p.shareSumOff}'}');
        expect(p.found, isEmpty, reason: p.found.join('\n'));
        // 途中で倒れずに、決めた年数を進めていること
        expect(p.ctl.game!.year, greaterThanOrEqualTo(c.$1 + _years), reason: '途中で終わった: ${p.ctl.game!.over}');
        // 主な道筋を通っていること（通らなければ点検になっていない）
        for (final k in ['最初の事業', '店・工場を増やす', '次の月へ', 'ひと回り', '出来事の選択']) {
          expect(p.seen[k] ?? 0, greaterThan(0), reason: '$k を通っていない');
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  }
}
