import 'dart:async';

import 'package:capstone_odiga/api/odiga_api.dart';

import 'package:capstone_odiga/main.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home search without a region shows API guidance', (
    tester,
  ) async {
    final app = await tester.runAsync(AppState.load);
    // Warm the error fixture outside the widget test's simulated clock.
    await tester.runAsync(() async {
      try {
        await app!.repository.api.search(const SearchRequestDto(query: '카페'));
      } on ApiException {
        /* The screen below must display this response. */
      }
    });
    await tester.pumpWidget(MyApp(loadState: () async => app!));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '조용한 카페');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.text('어느 지역에서 찾을까요? (성수·홍대·강남)'), findsOneWidget);
    expect(find.text('검색 조건 수정'), findsOneWidget);
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
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    await tester.tap(find.text('추천 3개 · 홍대 저녁 보드게임 코스'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('코스 상세').first);
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
    await tester.tap(
      find.widgetWithText(OdigaBottomNavigation, '친구').first,
      warnIfMissed: false,
    );
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
