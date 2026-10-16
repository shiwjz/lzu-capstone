/// 서버 모양(CourseDto) → 예령 화면용 모델(Course)로 바꾸기
/// - 코스 카드·커스텀 화면이 지금 Course를 쓰고 있어서 이쪽으로 맞춤
/// - 화면에서 장소 정보는 placeId로 찾는데, 지금 MockRepository 장소 ID랑 서버 장소 ID(카카오 ID)가 다름
///   → 화면 연결은 9주차에 예령이랑 같이 (장소 목록도 검색 응답 places로 바꾸기)
library;

import '../models/domain.dart';
import 'api_codes.dart';
import 'api_models.dart';

extension CourseDtoMapper on CourseDto {
  /// date = 검색 조건 날짜 (conditions.date), region = 검색 조건 지역
  Course toCourse({required DateTime date, required RegionCode region}) {
    final result = <CourseStop>[];
    var prev = _at(date, startAt);
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final next = i + 1 < stops.length ? stops[i + 1] : null;
      var arrival = _at(date, s.arriveAt);
      // 자정 넘어서 00:xx가 되면 다음 날로
      while (arrival.isBefore(prev)) {
        arrival = arrival.add(const Duration(days: 1));
      }
      prev = arrival;
      result.add(
        CourseStop(
          id: '$courseId-${s.order}',
          placeId: s.placeId,
          order: s.order,
          arrival: arrival,
          stayMinutes: s.stayMinutes,
          travelMinutesToNext: next?.walkMinutesFromPrev ?? 0,
          distanceMetersToNext: (next?.distanceMetersFromPrev ?? 0).toDouble(),
        ),
      );
    }
    return Course(
      id: courseId,
      title: title,
      region: region.label,
      stops: result,
      reason: reason,
      matchScore: (score.total * 100).round(),
    );
  }
}

/// 'HH:mm' → 그 날짜의 DateTime
DateTime _at(DateTime date, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}
