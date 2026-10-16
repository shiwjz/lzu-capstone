import 'dart:math' as math;

import '../models/domain.dart';

/// All records are fixtures. Kakao IDs explicitly identify mock records.
class MockRepository {
  MockRepository() {
    for (final region in ['성수', '홍대']) {
      final lat = region == '성수' ? 37.5445 : 37.5560;
      final lng = region == '성수' ? 127.0557 : 126.9235;
      final names = region == '성수'
          ? [
              '성수 작은 식탁',
              '카페 온도 성수',
              '서울숲 산책',
              '성수 소품상점',
              '성수 아트스페이스',
              '성수 디저트룸',
            ]
          : [
              '홍대 작은 식탁',
              '연남 온도 카페',
              '경의선숲길 산책',
              '홍대 보드게임',
              '연남 전시공간',
              '홍대 디저트룸',
            ];
      for (var i = 0; i < names.length; i++) {
        final category = ['음식점', '카페', '놀거리', '놀거리', '문화시설', '카페'][i];
        places.add(
          Place(
            id: '$region-$i',
            kakaoPlaceId: 'mock-kakao-$region-$i',
            name: names[i],
            category: category,
            region: region,
            latitude: lat - i * .0011,
            longitude: lng - i * .0014,
            cellId: 'mock-cell-$region-$i',
            tags: i == 0
                ? ['한식', '친구 모임']
                : i == 2
                ? ['조용한', '산책', '사진']
                : ['조용한', '디저트', '사진'],
            openingHours: i == 2 ? '상시 개방' : '11:00–22:00',
            imageAsset: i == 0
                ? 'assets/ba01c.png'
                : i == 2
                ? 'assets/5788c.png'
                : 'assets/756cc.png',
            rating: [4.7, 4.8, 4.9, 4.6, 4.7, 4.5][i],
            description: [
              '따뜻한 한 끼와 함께 시작해요',
              '디저트와 조용한 분위기',
              '여유롭게 걷기 좋은 산책길',
              '친구들과 구경하기 좋은 곳',
              '사진과 전시를 함께 즐겨요',
              '달콤한 디저트로 마무리',
            ][i],
          ),
        );
        for (final weekend in [false, true]) {
          for (var hour = 0; hour < 24; hour++) {
            final value = (18 + ((hour * 11 + i * 17) % 57) + (weekend ? 9 : 0))
                .toDouble();
            congestionRecords.add(
              Congestion(
                cellId: 'mock-cell-$region-$i',
                weekend: weekend,
                hour: hour,
                value: value,
                percentile: (value * .91 + 3).clamp(0, 100),
              ),
            );
          }
        }
      }
    }
  }
  final List<Place> places = [];
  final List<Congestion> congestionRecords = [];
  Place place(String id) => places.firstWhere((p) => p.id == id);
  Congestion congestion(String placeId, DateTime visit) {
    final cellId = place(placeId).cellId;
    return congestionRecords.firstWhere(
      (c) =>
          c.cellId == cellId &&
          c.hour == visit.hour &&
          c.weekend == (visit.weekday >= DateTime.saturday),
    );
  }

  List<Place> search(SearchConditions c) {
    final excluded = c.excluded
        .split(RegExp(r'[,\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    return places
        .where(
          (p) =>
              p.region == c.region &&
              !excluded.any(
                (word) =>
                    p.name.contains(word) ||
                    p.category.contains(word) ||
                    p.tags.any((t) => t.contains(word)),
              ),
        )
        .toList();
  }

  /// Straight-line distance multiplied by a mock walking detour factor.
  double distance(Place a, Place b) {
    final dy = (a.latitude - b.latitude) * 111000;
    final dx =
        (a.longitude - b.longitude) *
        111000 *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy) * 1.35;
  }

  Course recalculate(Course course, {DateTime? start}) {
    if (course.stops.isEmpty) return course;
    var arrival = start ?? course.stops.first.arrival;
    final stops = <CourseStop>[];
    for (var i = 0; i < course.stops.length; i++) {
      final old = course.stops[i];
      final meters = i + 1 < course.stops.length
          ? distance(place(old.placeId), place(course.stops[i + 1].placeId))
          : 0.0;
      final travel = meters == 0 ? 0 : math.max(1, (meters / 70).ceil());
      stops.add(
        CourseStop(
          id: old.id,
          placeId: old.placeId,
          order: i + 1,
          arrival: arrival,
          stayMinutes: old.stayMinutes,
          travelMinutesToNext: travel,
          distanceMetersToNext: meters,
        ),
      );
      arrival = arrival.add(Duration(minutes: old.stayMinutes + travel));
    }
    return course.copyWith(stops: stops);
  }

  List<Course> recommend(
    SearchConditions c,
    UserPreference preference, {
    bool group = false,
  }) {
    final candidates = search(c);
    if (candidates.isEmpty) return [];
    candidates.sort((a, b) {
      int score(Place p) =>
          (p.tags.contains(c.mood) ? 4 : 0) +
          (preference.categories.contains(p.category) ? 2 : 0);
      return score(b).compareTo(score(a));
    });
    final results = <Course>[];
    for (var rank = 0; rank < math.min(3, candidates.length); rank++) {
      final selection = List.generate(
        math.min(3, candidates.length),
        (i) => candidates[(i + rank) % candidates.length],
      );
      if (rank == 0 && c.excluded.isEmpty) {
        selection.setAll(0, [
          place('${c.region}-0'),
          place('${c.region}-1'),
          place('${c.region}-2'),
        ]);
      }
      final id = '${group ? 'group' : 'personal'}-${c.region}-$rank';
      results.add(
        recalculate(
          Course(
            id: id,
            title: ['${c.region}의 쉼표', '${c.region} 한 바퀴', '골목의 여유'][rank],
            region: c.region,
            reason: group
                ? '${c.people}명의 취향과 짧은 동선을 고려했어요'
                : '${c.mood} 분위기와 산책을 함께 즐겨요',
            matchScore: 96 - rank * 7,
            stops: [
              for (var i = 0; i < selection.length; i++)
                CourseStop(
                  id: '$id-stop-$i',
                  placeId: selection[i].id,
                  order: i + 1,
                  arrival: c.start,
                  stayMinutes: selection[i].category == '놀거리' ? 55 : 50,
                ),
            ],
          ),
          start: c.start,
        ),
      );
    }
    return results;
  }
}
