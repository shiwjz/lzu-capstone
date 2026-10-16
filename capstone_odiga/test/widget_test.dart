import 'package:capstone_odiga/main.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home search opens recommendations and course details', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('오디가'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '홍대에서 친구 3명이랑 저녁');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    await tester.tap(find.text('추천 3개 · 홍대의 쉼표'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('코스 상세').first);
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailScreen), findsOneWidget);
    expect(find.textContaining('홍대 작은 식탁'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(OdigaBottomNavigation, '친구').first,
      warnIfMissed: false);
  });
}
