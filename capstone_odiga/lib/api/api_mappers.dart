import '../models/domain.dart';
import 'api_models.dart';

/// Converts API-shaped fixtures to the presentation models.
class ApiMappers {
  static Course toCourse(CourseDto dto, ConditionsDto conditions) =>
      course(dto.json, conditions.json);
  static Place toPlace(PlaceDto dto, String regionCode) =>
      place(dto.json, regionCode);
  static String region(String code) =>
      const {'SEONGSU': '성수', 'HONGDAE': '홍대', 'GANGNAM': '강남'}[code] ?? code;

  static Place place(Map<String, dynamic> json, String regionCode) {
    final category =
        const {
          'FOOD': '음식점',
          'CAFE': '카페',
          'CULTURE': '문화시설',
          'ACTIVITY': '놀거리',
          'EXPERIENCE': '체험',
          'SHOPPING': '쇼핑',
          'TOUR': '관광',
          'NATURE': '자연/휴식',
        }[json['category']] ??
        json['category'] as String;
    final id = json['placeId'] as String;
    return Place(
      id: id,
      kakaoPlaceId: id,
      name: json['name'] as String,
      category: category,
      region: region(json['region'] ?? regionCode),
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      // Fixtures expose no grid cell ID; this key only groups local snapshots.
      cellId: 'fixture-place-$id',
      tags: [
        for (final tag in json['tags'] as List? ?? []) tag['tag'] as String,
      ],
      openingHours: json['openingHours'] as String? ?? '정보 없음',
      imageAsset: category == '음식점' ? 'assets/ba01c.png' : 'assets/756cc.png',
      rating: null,
      description:
          json['reason'] as String? ?? json['address'] as String? ?? '',
    );
  }

  static DateTime time(String date, String clock) =>
      DateTime.parse('${date}T$clock:00');

  static Course course(
    Map<String, dynamic> json,
    Map<String, dynamic> conditions,
  ) {
    final stops = json['stops'] as List;
    final date = conditions['date'] as String;
    var previous = time(date, json['startAt']);
    final result = <CourseStop>[];
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      var arrival = time(date, stop['arriveAt']);
      while (arrival.isBefore(previous)) {
        arrival = arrival.add(const Duration(days: 1));
      }
      previous = arrival;
      final next = i + 1 < stops.length ? stops[i + 1] : null;
      result.add(
        CourseStop(
          id: '${json['courseId']}-stop-$i',
          placeId: stop['placeId'],
          order: stop['order'],
          arrival: arrival,
          stayMinutes: stop['stayMinutes'],
          travelMinutesToNext:
              (next?['walkMinutesFromPrev'] as num?)?.toInt() ?? 0,
          distanceMetersToNext:
              (next?['distanceMetersFromPrev'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    final label = region(conditions['region']);
    return Course(
      id: json['courseId'],
      title: json['title'] as String? ?? '$label 추천 코스 ${json['rank']}',
      region: label,
      stops: result,
      reason:
          json['reason'] as String? ??
          '지역별 예시 코스 · ${conditions['date']} ${json['startAt']} 기준',
      matchScore: ((json['score']['total'] as num) * 100).round(),
    );
  }

  static Congestion congestion(
    String id,
    Map<String, dynamic> json,
    DateTime visit,
  ) => Congestion(
    cellId: 'fixture-place-$id',
    weekend: visit.weekday >= DateTime.saturday,
    hour: visit.hour,
    value: (json['percentile'] as num).toDouble(),
    percentile: (json['percentile'] as num).toDouble(),
    reportedBand: switch (json['level']) {
      'QUIET' => CongestionBand.quiet,
      'BUSY' => CongestionBand.busy,
      _ => CongestionBand.moderate,
    },
  );
}
