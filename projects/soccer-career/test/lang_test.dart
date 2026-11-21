/// 画面の言葉が、言語の切り替えに付いてくるか。
///
/// **この作品で2回踏んだ穴**: `const` の中に `tr()` を置くと、起動時の言語で
/// 固まって切り替えても古い言葉が残る（enum の引数・既定の引数・`static const`）。
/// 文法としては通るので、目で見るまで気付けない——だから機械で見張る。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/l10n/lang.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/share/share_service.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/hall_plaque.dart';

/// 日本語を1文字でも含むか。
final _ja = RegExp(r'[぀-ヿ一-鿿]');

/// **訳し終えたファイル。** 段階が進むたびにここへ足す。
///
/// ここに載っているファイルには、`tr()` か `Say()` に包まれていない
/// 日本語の文字列を置けない（コメントと、その第1引数は数えない）。
///
/// **包み方は2つ。** ふつうは `tr()`。`static const` の表（局面74・
/// 特性75）は定数なので `tr()` が書けず、`Say()` を使う。
// `lib/l10n/lang.dart` はここに載せない——言語そのものの呼び名
// （`'日本語'`）は訳すものではない。
const List<String> translated = [
  'lib/game/match_brief.dart',
  'lib/game/match_engine.dart',
  'lib/game/match_target.dart',
  'lib/game/scenarios.dart',
  'lib/game/world.dart',
  'lib/models/club.dart',
  'lib/models/country.dart',
  'lib/models/development.dart',
  'lib/models/pitch.dart',
  'lib/models/season.dart',
  'lib/models/attributes.dart',
  'lib/models/traits.dart',
  'lib/share/share_service.dart',
  'lib/state/career_controller.dart',
  'lib/ui/budget_lines.dart',
  'lib/ui/hall_plaque.dart',
  'lib/ui/pitch_view.dart',
  'lib/ui/player_banner.dart',
  'lib/ui/share_card.dart',
  'lib/ui/share_sheet.dart',
  'lib/ui/trait_row.dart',
  'lib/ui/training_sheet.dart',
  'lib/ui/transfer_code.dart',
  'lib/ui/screens/create_player_screen.dart',
  'lib/ui/screens/hall_screen.dart',
  'lib/ui/screens/hub_screen.dart',
  'lib/ui/screens/match_screen.dart',
  'lib/ui/screens/retired_screen.dart',
  'lib/ui/screens/season_end_screen.dart',
  'lib/ui/screens/support_screen.dart',
];

/// 文字列の終わり（の次）を返す。`${...}` の中の引用符とコメントを飛ばす。
int _endOfString(String s, int i) {
  final q = s[i];
  final triple = s.startsWith(q * 3, i);
  final end = triple ? q * 3 : q;
  i += end.length;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (s.startsWith(end, i)) return i + end.length;
    if (!triple && (c == '\n' || c == '\r')) return i;
    if (c == r'$' && i + 1 < s.length && s[i + 1] == '{') {
      i = _endOfBraces(s, i + 1);
      continue;
    }
    i++;
  }
  return s.length;
}

int _endOfBraces(String s, int i) {
  var depth = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    } else if (c == "'" || c == '"') {
      i = _endOfString(s, i);
      continue;
    }
    i++;
  }
  return s.length;
}

/// コメントの外にある文字列の開始位置を集める。
List<int> _stringStarts(String s) {
  final out = <int>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      final j = s.indexOf('*/', i + 2);
      i = j < 0 ? s.length : j + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      out.add(i);
      i = _endOfString(s, i);
      continue;
    }
    i++;
  }
  return out;
}

/// 隣り合う文字列をひと続きにまとめて、(開始, 終端) で返す。
List<(int, int)> _runs(String s) {
  final out = <(int, int)>[];
  int? start;
  int? end;
  for (final at in _stringStarts(s)) {
    final stop = _endOfString(s, at);
    if (start == null) {
      start = at;
      end = stop;
      continue;
    }
    // 間が空白とコメントだけなら、つながっている。
    final gap = s.substring(end!, at);
    final onlyGap = gap
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .trim()
        .isEmpty;
    if (onlyGap) {
      end = stop;
    } else {
      out.add((start, end));
      start = at;
      end = stop;
    }
  }
  if (start != null) out.add((start, end!));
  return out;
}

void main() {
  tearDown(() => Language.setForTest(Lang.ja));

  group('言葉の切り替え', () {
    test('既定は日本語', () {
      // **端末の言語から決めない。** テストと撮影は端末の言語を英語として
      // 起動するので、既定を端末に合わせると画面を確かめる道具が全部
      // 英語になり、日本語の画面を二度と見られなくなる。
      expect(currentLang, Lang.ja);
      expect(tr('日本語', 'English'), '日本語');
    });

    test('英語にすると、英語が返る', () {
      Language.setForTest(Lang.en);
      expect(tr('日本語', 'English'), 'English');
    });

    test('その言語自身の呼び名で並べる', () {
      // 英語しか読めない人に「日本語」と漢字で出しても選べない。
      expect(Lang.ja.label, '日本語');
      expect(Lang.en.label, 'English');
    });
  });

  group('const に固めない', () {
    test('enum の字は、切り替えに付いてくる（額の格）', () {
      expect(HallPlaque.gold.label, '金');
      Language.setForTest(Lang.en);
      expect(HallPlaque.gold.label, 'Gold');
    });

    test('enum の字は、切り替えに付いてくる（止まった理由）', () {
      expect(SimStop.injury.label, '負傷');
      Language.setForTest(Lang.en);
      expect(SimStop.injury.label, 'Injury');
    });

    test('送る文の名前と札も、切り替えに付いてくる', () {
      // 日本語の札は、英語で探している人には届かない。
      expect(ShareText.tag, '#選手キャリア');
      Language.setForTest(Lang.en);
      expect(ShareText.appName, 'Player Career');
      expect(ShareText.tag, '#PlayerCareer');
      // 住所は言語で変わらない（同じアプリなので）。
      expect(ShareText.compose(['a']), contains(ShareText.storeUrl));
    });
  });

  group('const の表は Say で持つ', () {
    test('Say は、読むたびに今の言語を返す', () {
      const say = Say('金', 'Gold');
      expect(say.t, '金');
      Language.setForTest(Lang.en);
      expect(say.t, 'Gold');
      // **const なのに切り替えに付いてくる**のが要。tr() を const の中に
      // 書くと、起動時の言語で固まって古い言葉が残る。
      expect(say.toString(), 'Gold');
    });

    test('特性の名前と説明は、切り替えに付いてくる', () {
      expect(Trait.clutch.label, 'クラッチ');
      expect(Trait.clutch.description, contains('成功率'));
      Language.setForTest(Lang.en);
      expect(Trait.clutch.label, 'Clutch');
      expect(Trait.clutch.description, isNot(contains('成功率')));
    });

    test('局面の文は、切り替えに付いてくる', () {
      final gk = ScenarioPool.goalkeeper.first;
      expect(gk.situation, contains('相手'));
      final option = gk.options.first;
      expect(option.label, contains('飛び出'));
      Language.setForTest(Lang.en);
      expect(gk.situation, isNot(contains('相手')));
      expect(option.label, isNot(contains('飛び出')));
      expect(option.successText, isNotEmpty);
      expect(option.failureText, isNotEmpty);
    });

    test('能力とポジションの名前は、切り替えに付いてくる', () {
      expect(AttributeKey.pace.label, 'スピード');
      expect(Detail.vision.label, '視野');
      expect(Position.am.label, 'OMF');
      expect(Position.cm.fullName, 'セントラルMF');
      Language.setForTest(Lang.en);
      expect(AttributeKey.pace.label, 'Pace');
      expect(Detail.vision.label, 'Vision');
      // 略称は英語の慣習に合わせる（日本では OMF、英語では AM）。
      expect(Position.am.label, 'AM');
      expect(Position.cm.fullName, 'Central midfielder');
    });

    test('特性の効き方の文に、日本語が残らない', () {
      // **ここが段階2で一番危ないところ。** 効き方の文は
      // `Detail.label` を埋め込むので、能力の名前を訳さないと
      // 英語の画面に「視野 ceiling +10」と混ざって出る。
      Language.setForTest(Lang.en);
      for (final trait in Trait.values) {
        for (final line in trait.effects) {
          expect(
            _ja.hasMatch(line),
            isFalse,
            reason: '${trait.name} の効き方に日本語が残っている: $line',
          );
        }
      }
    });

    test('局面の役どころは、言語で変わらない', () {
      // 役どころは難易度から決まる（`roleOf`）。言語で変わったら、
      // 英語で遊んだ人だけ布石と仕留めが別の手になる。
      final before = [
        for (final s in ScenarioPool.midfield)
          for (final o in s.options) s.roleOf(o),
      ];
      Language.setForTest(Lang.en);
      final after = [
        for (final s in ScenarioPool.midfield)
          for (final o in s.options) s.roleOf(o),
      ];
      expect(after, before);
    });
  });

  group('訳し終えたファイルに、素の日本語を残さない', () {
    test('tr() に包まれていない日本語の文字列が無い', () {
      final leaks = <String>[];
      for (final path in translated) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path が無い');
        final s = file.readAsStringSync();
        // **並べた文字列はひと続きで見る。** Dart は隣り合う文字列を
        // つなげるので、`tr('a' 'b', 'ab')` の 'b' の手前は `tr(` ではない。
        // 1本ずつ見ると、包んであるものを漏れと数えてしまう。
        for (final run in _runs(s)) {
          final lit = s.substring(run.$1, run.$2);
          if (!_ja.hasMatch(lit)) continue;
          final before = s.substring(0, run.$1).trimRight();
          if (before.endsWith('tr(') || before.endsWith('Say(')) continue;
          final line = s.substring(0, run.$1).split('\n').length;
          leaks.add('$path:$line  ${lit.replaceAll('\n', ' ')}');
        }
      }
      expect(
        leaks,
        isEmpty,
        reason:
            '訳していない日本語が残っている:\n${leaks.join('\n')}\n'
            'tr(\'日本語\', \'English\') に包むこと。'
            'const の中には置けないので、enum や既定の引数なら getter にし、'
            'static const の表なら Say(\'日本語\', \'English\') を使う。',
      );
    });
  });
}
