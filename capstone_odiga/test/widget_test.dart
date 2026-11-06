import 'dart:async';

import 'package:capstone_odiga/main.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home search opens conditions with the entered query', (
    tester,
  ) async {
    final app = await tester.runAsync(AppState.load);
    await tester.pumpWidget(MyApp(loadState: () async => app!));
    await tester.pumpAndSettle();
    expect(find.text('오디가'), findsOneWidget);
    expect(find.byTooltip('추천 검색'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '조용한 카페');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(ConditionsScreen), findsOneWidget);
    expect(find.text('조용한 카페'), findsOneWidget);
    expect(find.byType(RecommendationsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home search opens recommendations and course details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = await tester.runAsync(AppState.load);
    await tester.pumpWidget(MyApp(loadState: () async => app!));
    await tester.pumpAndSettle();
    expect(find.text('오디가'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '홍대에서 친구 3명이랑 저녁');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('수정 조건으로 바로 추천'));
    await tester.tap(find.text('수정 조건으로 바로 추천'));
    await tester.pumpAndSettle();
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    expect(find.byType(OdigaBottomNavigation), findsNothing);
    await tester.tap(find.byType(RankedCourseCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<CourseDetailScreen>(find.byType(CourseDetailScreen))
          .initial
          .id,
      'c_hongdae_1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup shows loading and retries a failed load', (
    tester,
  ) async {
    final app = await tester.runAsync(AppState.load);
    final pending = Completer<AppState>();
    var attempts = 0;
    await tester.pumpWidget(
      MyApp(
        loadState: () {
          attempts++;
          return attempts == 1 ? pending.future : Future.value(app!);
        },
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('missing fixture'));
    await tester.pumpAndSettle();
    expect(find.text('예시 데이터를 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(attempts, 2);
  });
}
