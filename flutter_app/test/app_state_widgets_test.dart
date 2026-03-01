import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('AppEmptyState renders and action callback works', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        AppEmptyState(
          title: '暂无数据',
          subtitle: '请稍后重试',
          actionText: '重试',
          onAction: () {
            tapped = true;
          },
        ),
      ),
    );

    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('AppWeakNetworkBanner displays message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppWeakNetworkBanner(text: '网络较弱，已显示缓存')),
    );

    expect(find.text('网络较弱，已显示缓存'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering_error_rounded), findsOneWidget);
  });

  testWidgets('AppListSkeleton renders expected item count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppListSkeleton(itemCount: 4)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppShimmerBlock), findsWidgets);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('AppGridSkeleton renders grid container', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppGridSkeleton(itemCount: 6, crossAxisCount: 2)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(AppShimmerBlock), findsWidgets);
  });
}
