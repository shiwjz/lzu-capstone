import 'package:capstone_odiga/data/mock_repository.dart';
import 'package:capstone_odiga/models/domain.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recalculation propagates stay changes across midnight and removes last leg', () {
    final repo = MockRepository();
    final start = DateTime(2026, 10, 16, 23, 50);
    final course = repo.recommend(SearchConditions(start: start), UserPreference()).first;
    final changed = repo.recalculate(course.copyWith(stops: [
      course.stops.first.withStay(120), ...course.stops.skip(1)]));
    expect(changed.stops[1].arrival.difference(course.stops[1].arrival).inMinutes, 70);
    expect(changed.stops[1].arrival.day, 17);
    expect(changed.stops.last.travelMinutesToNext, 0);
    expect(changed.totalMinutes, changed.stops.fold(0, (s, p) => s + p.stayMinutes + p.travelMinutesToNext));
    expect(repo.congestion(changed.stops[1].placeId, changed.stops[1].arrival).weekend, isTrue);
    final reduced = repo.recalculate(changed.copyWith(stops: [changed.stops.first]));
    expect(reduced.totalMinutes, 120);
    expect(reduced.distanceKm, 0);
  });
  test('saved course and shared snapshot do not change with an editor draft', () {
    final app = AppState();
    final original = app.savedCourses.first;
    app.sendMessage('공유', course: original);
    final changed = app.repository.recalculate(original.copyWith(stops: [original.stops.first.withStay(70)]));
    expect(app.savedCourses.first.stops.length, 3);
    app.saveCourse(changed);
    expect(app.savedCourses.length, 1);
    expect(app.savedCourses.first.stops.length, 1);
    expect(app.messages.last.course!.stops.length, 3);
    app.dispose();
  });
  test('congestion uses cell, weekend and hour; excluded categories yield empty results', () {
    final repo = MockRepository();
    final a = repo.congestion('성수-0', DateTime(2026, 10, 16, 12));
    final b = repo.congestion('성수-0', DateTime(2026, 10, 17, 12));
    final c = repo.congestion('성수-0', DateTime(2026, 10, 17, 13));
    expect(a.cellId, b.cellId);
    expect(a.value, isNot(b.value));
    expect(b.value, isNot(c.value));
    expect(b.value, isNot(b.percentile));
    expect(repo.recommend(SearchConditions(excluded: '카페 음식점 놀거리 문화시설'), UserPreference()), isEmpty);
  });
}
