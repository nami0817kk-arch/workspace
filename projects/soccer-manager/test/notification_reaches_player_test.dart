import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GameState が「利用者に伝えるため」に持っている値が、実際に画面へ
/// 届いているかを固定するテスト。
///
/// GameState は計算結果を last〜 のフィールドに置き、UI 側が拾って表示する
/// 作りになっている。拾い忘れても型は合うしテストも通るため、
/// 「計算しているのに誰にも見えない」状態が静かに残る。実際に2件あった。
///
/// - lastSaveError: 保存の失敗を知らせるために用意されていたが、どの画面
///   からも参照されていなかった。保存が失敗しても完全に沈黙していた。
/// - lastAppearanceFeesPaid: 出場給として資金から引いた額。引き落とし自体は
///   効いていたが金額を出しておらず、資金だけが理由なく減るように見えていた。
void main() {
  test('GameState の通知用フィールドは画面から参照されている', () {
    // 直接は参照されないが、別の経路で利用者に届いているもの。
    // 除外するなら理由を書く。黙って足さない。
    const reachesPlayerAnotherWay = <String, String>{
      'lastMilestones': 'ニュースログへ流し込んでいる(_logNews)',
      'lastPromotionBonus': '金額を lastDivisionChangeMessage の文面に含めている',
    };

    // フィールドの宣言は全て game_state.dart にある。part 側の extension は
    // インスタンスフィールドを宣言できないため。part まで含めると、
    // メソッドの引数名まで拾ってしまう。
    final stateSource = File('lib/state/game_state.dart').readAsStringSync();

    final declared = RegExp(
      r'^  (?:final |late )?[\w<>,?\[\] ]+ (last[A-Z]\w*)\s*[=;]',
      multiLine: true,
    ).allMatches(stateSource).map((m) => m.group(1)!).toSet();

    expect(declared.length, greaterThan(10),
        reason: 'フィールドの抽出に失敗している。宣言の書き方が変わった可能性がある');

    final uiSource = [
      ...Directory('lib/screens').listSync().whereType<File>(),
      ...Directory('lib/widgets').listSync().whereType<File>(),
    ]
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final unreachable = <String>[];
    for (final name in declared) {
      if (reachesPlayerAnotherWay.containsKey(name)) continue;
      // raw 文字列で組む。通常の文字列に '\b' と書くと Dart のエスケープで
      // バックスペース文字になり、常に一致しなくなる(エラーにならないので
      // 気づけない。実際にこれで全件が未参照に見えた)。
      final word = RegExp(r'\b' + name + r'\b');
      if (!word.hasMatch(uiSource)) unreachable.add(name);
    }

    expect(
      unreachable..sort(),
      isEmpty,
      reason: 'GameState が計算しているのに画面へ出していない値がある。\n'
          '表示するか、別経路で届いているなら reachesPlayerAnotherWay に\n'
          '理由を書いて除外すること:\n${unreachable.join('\n')}',
    );
  });

  test('保存失敗の通知がアプリに実際に組み込まれている', () {
    // 上のテストは「どこかのUIファイルが参照しているか」しか見ない。
    // SaveErrorNotifier は lastSaveError を参照するので、main.dart から
    // 外して画面に出なくなっても上は通ってしまう。実際に確認した。
    // 組み込まれていること自体を別に固定する。
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('SaveErrorNotifier('), 
        reason: '保存の失敗を知らせるウィジェットがアプリに組み込まれていない。'
            '外すと、保存が失敗しても利用者は気づけない。');
  });
}
