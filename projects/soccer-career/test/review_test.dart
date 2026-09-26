/// 星を頼む瞬間の見張り。
///
/// **星が0のまま出すと、見つけてもらえても入手されない。** かといって
/// 遊び始めた直後や負けた季に頼めば、低い星が付いて逆に損をする。
/// 頼める回数は OS が年3回までに絞るので、**1回を良い瞬間に使い切る**のが
/// ここの仕事。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_career/feedback/review_prompt.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/season.dart';

import 'ui_test.dart' as ui_test;

/// 頼まれた回数を数えるだけの偽物。
class _FakeReview implements ReviewService {
  _FakeReview({this.available = true});

  final bool available;
  int requested = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> request() async => requested++;
}

const _stats = SeasonStats(
  appearances: 30,
  goals: 4,
  assists: 12,
  averageRating: 7.1,
);

SeasonRecord _season({
  required int year,
  int tier = 2,
  int position = 10,
  bool objectiveMet = false,
}) => SeasonRecord(
  year: year,
  clubName: 'テストFC',
  tier: tier,
  leaguePosition: position,
  stats: _stats,
  objectiveMet: objectiveMet,
);

/// 指定した季数ぶんの記録を持つ状態を作る。
Future<CareerState> stateWith(List<SeasonRecord> history) async {
  final controller = await ui_test.newCareer();
  final state = controller.state!;
  state.history = history;
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ReviewPrompt> prompt(_FakeReview service) async {
    final p = ReviewPrompt(service: service);
    await p.initialize();
    return p;
  }

  test('3季を終えるまでは頼まない', () async {
    final service = _FakeReview();
    final p = await prompt(service);
    // 2季。どちらも目標達成でも、まだ早い。
    final state = await stateWith([
      _season(year: 2026, objectiveMet: true),
      _season(year: 2027, objectiveMet: true),
    ]);
    expect(await p.askIfEarned(state: state, adShown: false), isFalse);
    expect(service.requested, 0);
  });

  test('負けた季には頼まない', () async {
    final service = _FakeReview();
    final p = await prompt(service);
    final state = await stateWith([
      _season(year: 2026),
      _season(year: 2027),
      _season(year: 2028, position: 19),
    ]);
    expect(ReviewPrompt.isGoodSeason(state), isFalse);
    expect(await p.askIfEarned(state: state, adShown: false), isFalse);
    expect(service.requested, 0);
  });

  test('目標を達成した季なら頼む', () async {
    final service = _FakeReview();
    final p = await prompt(service);
    final state = await stateWith([
      _season(year: 2026),
      _season(year: 2027),
      _season(year: 2028, objectiveMet: true),
    ]);
    expect(await p.askIfEarned(state: state, adShown: false), isTrue);
    expect(service.requested, 1);
  });

  test('優勝した季でも、昇格した季でも頼む', () async {
    for (final history in [
      [_season(year: 2026), _season(year: 2027), _season(year: 2028, position: 1)],
      // 3部 → 2部。部が上がっている。
      [_season(year: 2026), _season(year: 2027, tier: 3), _season(year: 2028)],
    ]) {
      SharedPreferences.setMockInitialValues({});
      final service = _FakeReview();
      final p = await prompt(service);
      expect(
        await p.askIfEarned(state: await stateWith(history), adShown: false),
        isTrue,
      );
    }
  });

  test('広告を出した回には頼まない', () async {
    final service = _FakeReview();
    final p = await prompt(service);
    final state = await stateWith([
      _season(year: 2026),
      _season(year: 2027),
      _season(year: 2028, objectiveMet: true),
    ]);
    // **全画面広告を閉じた直後に評価を求めるのは、順番として最悪。**
    expect(await p.askIfEarned(state: state, adShown: true), isFalse);
    expect(service.requested, 0);
    // 広告の出なかった次の機会には頼める。
    expect(await p.askIfEarned(state: state, adShown: false), isTrue);
  });

  test('頼むのは1度だけ', () async {
    final service = _FakeReview();
    final p = await prompt(service);
    final state = await stateWith([
      _season(year: 2026),
      _season(year: 2027),
      _season(year: 2028, objectiveMet: true),
    ]);
    expect(await p.askIfEarned(state: state, adShown: false), isTrue);
    expect(await p.askIfEarned(state: state, adShown: false), isFalse);
    expect(service.requested, 1);

    // 次に起動したときも、頼んだことを覚えている。
    final again = ReviewPrompt(service: service);
    await again.initialize();
    expect(again.asked, isTrue);
    expect(await again.askIfEarned(state: state, adShown: false), isFalse);
  });

  test('ダイアログを出せない環境では、1回を使わない', () async {
    // **OS が出さなかった回と、そもそも頼めない環境は別。**
    // 頼めない環境で数えてしまうと、実機に移したときに機会が無い。
    final service = _FakeReview(available: false);
    final p = await prompt(service);
    final state = await stateWith([
      _season(year: 2026),
      _season(year: 2027),
      _season(year: 2028, objectiveMet: true),
    ]);
    expect(await p.askIfEarned(state: state, adShown: false), isFalse);
    expect(p.asked, isFalse);
  });

  test('Web版とテストでは、何もしない実装になる', () async {
    expect(createReviewService(), isA<NoReviewService>());
    expect(await createReviewService().isAvailable(), isFalse);
  });
}
