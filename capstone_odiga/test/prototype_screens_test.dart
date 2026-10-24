import 'package:capstone_odiga/data/mock_repository.dart';
import 'package:capstone_odiga/screens/app_screens.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/widgets/odiga_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRepository repository;
  setUpAll(() async => repository = await MockRepository.load());
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
      ConditionsScreen(app: app),
      PlaceDetailScreen(app: app, place: app.repository.places.first),
      RecommendationsScreen(app: app, expanded: true),
      ReasonScreen(app: app, course: course, rank: 1),
      CourseDetailScreen(app: app, initial: course),
      CourseEditorScreen(app: app, initial: course),
      FriendsScreen(app: app),
      GroupScreen(app: app),
      GroupPreferenceScreen(app: app),
      ChatScreen(app: app),
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
