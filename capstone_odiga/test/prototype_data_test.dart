import 'dart:convert';

import 'package:capstone_odiga/data/mock_json_mapper.dart';
import 'package:capstone_odiga/data/mock_repository.dart';
import 'package:capstone_odiga/api/odiga_api.dart';
import 'package:capstone_odiga/models/domain.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('missing fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRepository repo;
  setUpAll(() async => repo = await MockRepository.load());

  test(
    'loads each region and preserves API course times, scores and legs',
    () async {
      for (final entry in {
        '성수': 'search_seongsu_weekend_quiet.json',
        '홍대': 'search_hongdae_weekend_lively.json',
        '강남': 'search_gangnam_weekday_group.json',
      }.entries) {
        final data = jsonDecode(
          await rootBundle.loadString('assets/mocks/${entry.value}'),
        )['data'];
        final courses = await repo.recommend(
          SearchConditions(region: entry.key),
          UserPreference(),
        );
        expect(courses.length, data['courses'].length);
        for (var i = 0; i < courses.length; i++) {
          final actual = courses[i];
          final source = data['courses'][i];
          expect(actual.id, source['courseId']);
          expect(actual.title, source['title']);
          expect(actual.reason, source['reason']);
          expect(actual.totalMinutes, source['totalMinutes']);
          expect(
            actual.distanceKm * 1000,
            closeTo(source['totalDistanceMeters'], .001),
          );
          expect(
            actual.matchScore,
            ((source['score']['total'] as num) * 100).round(),
          );
          for (var j = 0; j < actual.stops.length; j++) {
            final stop = actual.stops[j];
            expect(repo.place(stop.placeId).name, source['stops'][j]['name']);
            expect(
              stop.arrival,
              MockJsonMapper.time(
                data['conditions']['date'],
                source['stops'][j]['arriveAt'],
              ),
            );
            expect(
              stop.travelMinutesToNext,
              j + 1 < actual.stops.length
                  ? source['stops'][j + 1]['walkMinutesFromPrev']
                  : 0,
            );
          }
        }
      }
    },
  );

  test(
    'maps tags, missing metadata, preferences and explicit congestion level',
    () {
      final place = repo.place('20745493');
      expect(place.name, '해피노래연습장');
      expect(place.tags, contains('데이트'));
      expect(place.rating, isNull);
      expect(place.openingHours, '영업시간 정보 없음');
      expect(repo.initialPreference.allergies, 'SHELLFISH');
      final detail = repo.congestion(
        '780757764',
        DateTime(2026, 10, 17, 13),
        detail: true,
      );
      expect(detail.percentile, 34);
      expect(
        detail.band,
        CongestionBand.moderate,
      ); // API NORMAL, despite percentile < 40.
      final sparse = repo.congestion('20745493', DateTime(2026, 10, 16, 0));
      expect(sparse.weekend, isTrue); // Preserve supplied day type on fallback.
    },
  );

  test(
    'exclusions remove fixture courses and unknown regions return empty',
    () async {
      expect(
        await repo.recommend(
          SearchConditions(excluded: '음식점'),
          UserPreference(),
        ),
        isEmpty,
      );
      expect(await repo.search(SearchConditions(region: '없는 지역')), isEmpty);
    },
  );

  test('asset loading failures propagate', () async {
    await expectLater(
      MockRepository.load(bundle: BrokenBundle()),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'MOCK_LOAD_FAILED'),
      ),
    );
  });

  test('recalculation propagates stay changes across midnight and removes last leg', () async {
    final start = DateTime(2026, 10, 16, 23, 50);
    final sample = (await repo.recommend(
      SearchConditions(),
      UserPreference(),
    )).first;
    final course = repo.recalculate(sample, start: start);
    final changed = repo.recalculate(
      course.copyWith(
        stops: [
          course.stops.first.withStay(course.stops.first.stayMinutes + 120),
          ...course.stops.skip(1),
        ],
      ),
    );
    expect(
      changed.stops[1].arrival.difference(course.stops[1].arrival).inMinutes,
      120,
    );
    expect(changed.stops[1].arrival.day, 17);
    expect(changed.stops.last.travelMinutesToNext, 0);
    final reduced = repo.recalculate(
      changed.copyWith(stops: [changed.stops.first]),
    );
    expect(reduced.totalMinutes, changed.stops.first.stayMinutes);
    expect(reduced.distanceKm, 0);
  });

  test('saved and shared snapshots do not change with an editor draft', () {
    final app = AppState(repository: repo);
    final original = app.savedCourses.first;
    app.sendMessage('공유', course: original);
    final changed = repo.recalculate(
      original.copyWith(stops: [original.stops.first.withStay(70)]),
    );
    app.saveCourse(changed);
    expect(app.savedCourses.length, 1);
    expect(app.savedCourses.first.stops.length, 1);
    expect(app.messages.last.course!.stops.length, 3);
    expect(
      app.savedPlaceIds.every((id) => repo.places.any((p) => p.id == id)),
      isTrue,
    );
    app.dispose();
  });
}
