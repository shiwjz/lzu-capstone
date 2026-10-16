import 'package:capstone_odiga/component_preview.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('course duration and deletion update the parent data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ComponentPreviewApp());
    expect(find.text('체류 155분 · 장소 3개'), findsOneWidget);
    await tester.tap(find.text('50분 ⌄').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('90분'));
    await tester.pumpAndSettle();
    expect(find.text('체류 195분 · 장소 3개'), findsOneWidget);
    expect(find.text('13:40 방문 · 한산'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(CourseStopTile, '1. 성수 작은 식탁'),
        matching: find.text('×'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('체류 105분 · 장소 2개'), findsOneWidget);
    expect(find.text('1. 카페 온도 성수'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet cycles and category selection is controlled by parent', (
    tester,
  ) async {
    await tester.pumpWidget(const ComponentPreviewApp());
    await tester.tap(find.text('카페'));
    await tester.pump();
    expect(
      tester.widget<OdigaTag>(find.widgetWithText(OdigaTag, '카페')).selected,
      isTrue,
    );
    await tester.tap(find.text('코스 수정 · 동선 자동 계산'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseStopTile), findsNothing);
    await tester.tap(find.text('코스 수정 · 동선 자동 계산'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseStopTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text remains usable at narrow width and increased text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: ListView(
              children: const [
                CourseStopTile(
                  order: 1,
                  title: '아주 긴 이름을 가진 성수동의 작은 식탁',
                  visitLabel: '12:00 방문 · 보통',
                  stayMinutes: 120,
                ),
                RecommendationReasonRow(
                  label: '사용자 조건 일치도',
                  value: '96% · 지역·인원·시간·분위기 일치',
                ),
                FriendCard(name: '예민', initial: '예', status: '오늘은 감성 카페가 좋아요'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
