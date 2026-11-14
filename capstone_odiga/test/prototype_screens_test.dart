import 'package:capstone_odiga/data/mock_repository.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRepository repository;
  setUpAll(() async => repository = await MockRepository.load());

  testWidgets('course detail shows arrival radar and estimated duration', (
    tester,
  ) async {
    final app = AppState(repository: repository);
    addTearDown(app.dispose);
    final course = app.savedCourses.first;
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailScreen(app: app, initial: course),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('총 ${course.totalMinutes}분 예상'), findsOneWidget);
    expect(find.byType(CircleLayer), findsNWidgets(course.stops.length));

    await tester.tap(find.byTooltip('혼잡 레이더 끄기'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('editor supports stay, delete and recalculated total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState(repository: repository);
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CourseEditorScreen(app: app, initial: app.savedCourses.first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('50분 ⌄').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('70분'));
    await tester.pumpAndSettle();
    expect(find.text('70분 ⌄'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CourseStopTile).first,
        matching: find.text('×'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        '1. ${repository.place(app.savedCourses.first.stops[1].placeId).name}',
      ),
      findsOneWidget,
    );
    expect(app.savedCourses.first.stops.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat recommendations use the group participant count', (
    tester,
  ) async {
    final app = AppState(repository: repository);
    addTearDown(app.dispose);
    app.conditions
      ..people = 3
      ..useSelectedRegion = false;
    await tester.pumpWidget(MaterialApp(home: FriendsScreen(app: app)));
    await tester.pumpAndSettle();

    final create = find.text('새 모임 만들기');
    await tester.scrollUntilVisible(
      create,
      120,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final timeFields = find.byType(DropdownButtonFormField<int>);
    await Scrollable.ensureVisible(
      tester.element(timeFields.first),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(timeFields.first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('18시').hitTestable(),
      160,
      scrollable: find.byWidgetPredicate((widget) => widget is Scrollable).last,
    );
    await tester.tap(find.text('18시').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(timeFields.last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('30분').hitTestable(),
      160,
      scrollable: find.byWidgetPredicate((widget) => widget is Scrollable).last,
    );
    await tester.tap(find.text('30분').hitTestable());
    await tester.pumpAndSettle();
    final friend = find.widgetWithText(CheckboxListTile, '예령');
    await tester.ensureVisible(friend);
    await tester.pumpAndSettle();
    await tester.tap(friend);
    await tester.pumpAndSettle();
    final submit = find.text('모임 만들기');
    await Scrollable.ensureVisible(tester.element(submit), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final group = app.groups.last;
    expect(group.start.hour, 18);
    expect(group.start.minute, 30);
    expect(group.friends.map((friend) => friend.name), ['예령']);
    expect(group.messages, isEmpty);
    expect(app.groups, hasLength(2));
    expect(app.groups.first.messages, hasLength(2));
    expect(find.text('참여자 2명'), findsOneWidget);
    expect(find.textContaining('18:30'), findsOneWidget);
    await tester.tap(find.text('최근 대화'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('코스 추천받기'));
    await tester.pumpAndSettle();
    final recommendations = tester.widget<RecommendationsScreen>(
      find.byType(RecommendationsScreen),
    );
    expect(recommendations.initialConditions!.start, group.start);
    await tester.tap(find.text('조건'));
    await tester.pumpAndSettle();

    final people = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(people.initialValue, 2);
    expect(app.conditions.people, 3);

    app.sendMessage(group, '첫 번째 모임 메시지');
    final second = app.createGroup('토요일 홍대 모임', {
      app.friends.last.id,
    }, DateTime(2026, 11, 21, 19));
    expect(app.groups, hasLength(3));
    expect(group.messages.single.text, '첫 번째 모임 메시지');
    expect(second.messages, isEmpty);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    final secondRoom = find.text(second.name);
    await Scrollable.ensureVisible(tester.element(secondRoom), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(secondRoom);
    await tester.pumpAndSettle();
    expect(find.textContaining('2026.11.21 19:00'), findsOneWidget);
    final delete = find.text('모임 삭제');
    await Scrollable.ensureVisible(tester.element(delete), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(app.groups, contains(second));

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(app.groups, isNot(contains(second)));
    expect(find.text(second.name), findsNothing);
    expect(group.messages.single.text, '첫 번째 모임 메시지');
  });

  testWidgets('all primary screens fit narrow display', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState(repository: repository);
    addTearDown(app.dispose);
    final course = app.savedCourses.first;
    for (final screen in <Widget>[
      HomeScreen(app: app),
      ConditionsScreen(app: app, initialConditions: app.conditions),
      PlaceDetailScreen(app: app, place: app.repository.places.first),
      RecommendationsScreen(app: app, expanded: true),
      CourseDetailScreen(app: app, initial: course),
      CourseEditorScreen(app: app, initial: course),
      FriendsScreen(app: app),
      GroupScreen(app: app, group: app.groups.first),
      GroupPreferenceScreen(app: app, group: app.groups.first),
      ChatScreen(app: app, group: app.groups.first),
      ProfileScreen(app: app),
      PreferencesScreen(app: app),
      SavedPlacesScreen(app: app),
      SavedCoursesScreen(app: app),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: screen.runtimeType.toString(),
      );
    }
  });
}
