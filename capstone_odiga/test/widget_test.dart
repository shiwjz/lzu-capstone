import 'dart:async';

import 'package:capstone_odiga/main.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty and unrecognized searches allow a retry', (tester) async {
    final app = await tester.runAsync(AppState.load);
    await tester.pumpWidget(MyApp(loadState: () async => app!));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byTooltip('추천 검색'), findsOneWidget);
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.text(searchInputMessage), findsOneWidget);
    expect(find.byType(RecommendationsScreen), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '조용한 카페');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.text(searchInputMessage), findsOneWidget);
    expect(find.byType(ConditionsScreen), findsNothing);
    await tester.tap(find.text('검색으로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '성수 카페');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(RankedCourseCard), findsWidgets);
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
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '홍대에서 친구 3명이랑 저녁');
    await tester.tap(find.byTooltip('추천 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(ConditionsScreen), findsNothing);
    expect(find.text('추천 3개 · 토요일 19시 홍대'), findsOneWidget);
    await tester.tap(find.text('조건'));
    await tester.pumpAndSettle();
    expect(find.byType(ConditionsScreen), findsOneWidget);
    expect(find.text('코스 틀'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('수정 조건으로 바로 추천'),
      120,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정 조건으로 바로 추천'));
    await tester.pumpAndSettle();
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    expect(find.byType(OdigaBottomNavigation), findsNothing);
    final firstCard = tester.widget<RankedCourseCard>(
      find.byType(RankedCourseCard).first,
    );
    await tester.tap(find.text(firstCard.title));
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

  testWidgets(
    'keep a Gangnam stop, search again and switch the crowd chart day',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await tester.runAsync(AppState.load);
      await tester.pumpWidget(MyApp(loadState: () async => app!));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '강남');
      await tester.tap(find.byTooltip('추천 검색'));
      await tester.pumpAndSettle();

      final sheet = find.descendant(
        of: find.byType(OdigaContentSheet),
        matching: find.byType(Scrollable),
      );
      final course = app!.repository.course('c_gangnam_1')!;
      final place = app.repository.place(course.stops.first.placeId);
      final placeCard = find.widgetWithText(PlaceCard, place.name);
      final keep = find.descendant(
        of: placeCard,
        matching: find.byTooltip('킵'),
      );
      await tester.scrollUntilVisible(keep, 160, scrollable: sheet);
      await tester.pumpAndSettle();
      await tester.tap(keep);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('이 장소로 다시 찾기'),
        -160,
        scrollable: sheet,
      );
      await tester.tap(find.text('이 장소로 다시 찾기'));
      await tester.pumpAndSettle();
      expect(find.byType(RankedCourseCard), findsWidgets);

      await tester.scrollUntilVisible(placeCard, 160, scrollable: sheet);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: placeCard, matching: find.text(place.name)),
      );
      await tester.pumpAndSettle();
      expect(find.text('주변 혼잡도'), findsOneWidget);
      expect(find.text('9시'), findsOneWidget);
      expect(find.text('23시'), findsOneWidget);
      await tester.tap(find.text('토'));
      await tester.pumpAndSettle();
      expect(find.text('도착 예정 · 19:00'), findsOneWidget);
      expect(find.text(place.address!), findsOneWidget);
      expect(find.text('카카오맵 길찾기'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(course.title),
        -160,
        scrollable: sheet,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(course.title));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('코스 저장'),
        160,
        scrollable: sheet,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('코스 저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 코스'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('강남'));
      await tester.pumpAndSettle();
      expect(find.text(course.title), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('앱 초기 데이터를 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(attempts, 2);
  });
}
