import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';

/// 横画面の iPhone で、右端に並ぶ数字が切り欠きの下に入らないこと。
void main() {
  Widget app(EdgeInsets pad) => MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: pad,
              viewPadding: pad,
            ),
            child: const NotchSideInsets(
              child: Scaffold(
                body: Align(
                  alignment: Alignment.centerRight,
                  child: Text('12,345', key: Key('value')),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> landscape(WidgetTester tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('right-aligned value stays clear of the right notch',
      (tester) async {
    await landscape(tester);
    await tester.pumpWidget(app(const EdgeInsets.only(left: 47, right: 47)));
    final r = tester.getRect(find.byKey(const Key('value')));
    expect(r.right, lessThanOrEqualTo(844 - 47));
  });

  testWidgets('screen body is inset on both sides', (tester) async {
    await landscape(tester);
    await tester.pumpWidget(app(const EdgeInsets.only(left: 47, right: 47)));
    final scaffold = tester.getRect(find.byType(Scaffold));
    expect(scaffold.left, 47);
    expect(scaffold.right, 844 - 47);
  });

  testWidgets('no inset leaves the layout unchanged', (tester) async {
    await landscape(tester);
    await tester.pumpWidget(app(EdgeInsets.zero));
    expect(tester.getRect(find.byType(Scaffold)).width, 844);
  });
}
