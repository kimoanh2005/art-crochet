import 'package:crochet_charts/main.dart';
import 'package:crochet_charts/models/crochet_chart.dart';
import 'package:crochet_charts/screens/auth/auth_screens.dart';
import 'package:crochet_charts/screens/charts/create_chart_screen.dart';
import 'package:crochet_charts/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows Supabase configuration guidance instead of demo data', (
    tester,
  ) async {
    await tester.pumpWidget(const SupabaseConfigErrorApp());

    expect(find.textContaining('Chưa cấu hình Supabase'), findsOneWidget);
    expect(find.text('Hoa cúc mini'), findsNothing);
  });

  testWidgets('mobile navigation fits a narrow viewport', (tester) async {
    setMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Thiết kế'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login screen fits a narrow mobile viewport', (tester) async {
    setMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onRegister: () {}, onSignedIn: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Art Crochet'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create chart form fits a narrow mobile viewport', (
    tester,
  ) async {
    setMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateChartScreen(onCancel: () {}, onCreated: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tạo chart mới'), findsOneWidget);
    expect(find.text('Tạo chart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('chart progress and unit follow its configured type', () {
    final chart = CrochetChart(
      id: 'chart-id',
      name: 'Chart thử',
      category: 'Hoa',
      description: '',
      chartType: ChartType.circular,
      rowsCount: 8,
      columnsCount: 12,
      status: ChartStatus.inProgress,
      completedRows: 3,
      isFavorite: false,
      updatedAt: DateTime.utc(2026, 10, 27),
    );

    expect(chart.progress, 3 / 8);
    expect(chart.progressUnit, 'vòng');
    expect(chart.currentRow, 4);
  });
}
