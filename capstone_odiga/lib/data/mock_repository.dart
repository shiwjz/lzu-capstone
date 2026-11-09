import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/domain.dart';
import '../api/api_codes.dart';
import '../api/api_mappers.dart';
import '../api/mock_odiga_api.dart';
import '../api/odiga_api.dart';

String? _genderCode(String value) => switch (value) {
  '여성' => 'F',
  '남성' => 'M',
  _ => null,
};

String? _ageGroupCode(String value) => switch (value) {
  '10대' => '10s',
  '20대' => '20s',
  '30대' => '30s',
  '40대' => '40s',
  '50대' => '50s',
  '60대' => '60s',
  _ => null,
};

String _companionCode(String value) => switch (value) {
  '연인' => 'COUPLE',
  '가족' => 'FAMILY',
  '회사' => 'COWORKER',
  '혼자' => 'SOLO',
  _ => 'FRIEND',
};

String _atmosphereCode(String value) => switch (value) {
  '조용함' => '조용한',
  '데이트' || '친구 모임' => '', // Situation tags are derived by the server.
  _ => value,
};

String _crowdPreference(Set<String> atmospheres) {
  if (atmospheres.contains('조용한')) return 'QUIET';
  if (atmospheres.contains('활기찬')) return 'LIVELY';
  return 'DEFAULT';
}

String? _categoryCode(String value) => const {
  '음식점': 'FOOD',
  '카페': 'CAFE',
  '놀거리': 'ACTIVITY',
  '문화시설': 'CULTURE',
  '체험': 'EXPERIENCE',
  '쇼핑': 'SHOPPING',
  '관광': 'TOUR',
  '자연/휴식': 'NATURE',
  '간식': 'SNACK',
}[value];

List<String> _categoryCodes(Set<String> values) =>
    values.map(_categoryCode).whereType<String>().toList();

const _cuisineCodes = {
  '한식': 'KOREAN',
  '일식': 'JAPANESE',
  '양식': 'WESTERN',
  '중식': 'CHINESE',
  '분식': 'BUNSIK',
  '아시아': 'ASIAN',
  '치킨': 'CHICKEN',
  '술집': 'BAR',
};

List<String> _cuisineCodeList(Set<String> values) =>
    values.map((value) => _cuisineCodes[value]).whereType<String>().toList();

List<String> _allergyCodes(String value) => [
  for (final token in value.split(RegExp(r'[,，\s]+')))
    for (final allergy in AllergyCode.values)
      if (token.toUpperCase() == allergy.code || token == allergy.label)
        allergy.code,
];

/// Local API fixtures. Python and the source CSV files are not needed at runtime.
class MockRepository {
  MockRepository._(this.api);
  final OdigaApi api;

  static Future<MockRepository> load({
    AssetBundle? bundle,
    OdigaApi? api,
  }) async {
    final client = api ?? MockOdigaApi(bundle: bundle);
    final repository = MockRepository._(client);
    Future<SearchResultDto> searchRegion(String region) async {
      try {
        return await client.search(SearchRequestDto(query: region));
      } on ApiException catch (error) {
        throw ApiException(
          error.code,
          '$region 초기 검색에 실패했어요. ${error.message}',
        );
      }
    }

    final results = await Future.wait<ApiDto>([
      for (final region in supportedCongestionRegions) searchRegion(region),
      if (repository.usesSampleData) client.getPlace('780757764'),
      client.getPreferences(),
    ], eagerError: true);
    final responses = results.map((r) => r.json).toList();
    final byId = <String, Place>{};
    for (final data in responses.take(3)) {
      final conditions = data['conditions'] as Map<String, dynamic>;
      final regionCode = conditions['region'] as String;
      final date = conditions['date'] as String;
      final courses = <Course>[];
      for (final json in data['places'] as List) {
        final place = ApiMappers.place(json, regionCode);
        byId[place.id] = place;
        final congestion = json['congestion'] as Json?;
        final hour = congestion?['hour'] as int?;
        if (congestion != null && hour != null) {
          repository._record(
            place.id,
            congestion,
            ApiMappers.time(date, '${hour.toString().padLeft(2, '0')}:00'),
          );
        }
      }
      for (final json in data['courses'] as List) {
        final course = ApiMappers.course(json, conditions);
        courses.add(course);
        final stops = json['stops'] as List;
        for (var i = 0; i < stops.length; i++) {
          final stop = stops[i];
          final id = stop['placeId'] as String;
          byId.putIfAbsent(id, () => ApiMappers.place(stop, regionCode));
          if (stop['congestion'] case final Json congestion) {
            repository._record(id, congestion, course.stops[i].arrival);
          }
        }
      }
      repository._courses[ApiMappers.region(regionCode)] = courses;
    }
    if (repository.usesSampleData) {
      final detail = responses[3];
      final detailPlace = ApiMappers.place(detail, detail['region']);
      // Preserve the search explanation when enriching a place with its detail.
      byId[detailPlace.id] = ApiMappers.place({
        ...detail,
        'reason': byId[detailPlace.id]?.description ?? '',
      }, detail['region']);
      final hourly = detail['congestionByHour'];
      for (final hour in hourly['hours'] as List) {
        repository._detailRecords.add(
          ApiMappers.congestion(
            detailPlace.id,
            hour,
            ApiMappers.time(
              hourly['date'],
              '${(hour['hour'] as int).toString().padLeft(2, '0')}:00',
            ),
          ),
        );
      }
    }
    repository.places.addAll(byId.values);
    final prefs = responses.last;
    repository.initialPreference = UserPreference(
      moods: Set<String>.from(prefs['atmospheres']),
      allergies: (prefs['allergies'] as List).join(', '),
    );
    return repository;
  }

  final List<Place> places = [];
  final List<Congestion> congestionRecords = [];
  final List<Congestion> _detailRecords = [];
  final Map<String, List<Course>> _courses = {};
  late final UserPreference initialPreference;
  List<Course> get initialCourses => List.unmodifiable(_courses['성수'] ?? []);

  void _record(String id, Map<String, dynamic> json, DateTime visit) {
    congestionRecords.removeWhere(
      (c) =>
          c.cellId == 'fixture-place-$id' &&
          c.hour == visit.hour &&
          c.weekend == (visit.weekday >= DateTime.saturday),
    );
    congestionRecords.add(ApiMappers.congestion(id, json, visit));
  }

  Place place(String id) => places.firstWhere((p) => p.id == id);

  Course? course(String id) => _courses.values
      .expand((courses) => courses)
      .where((course) => course.id == id)
      .firstOrNull;

  Course rememberRemoteSavedCourse(Json record) {
    final conditions = ConditionsDto.fromJson(
      Map<String, dynamic>.from(record['conditions'] as Map),
    );
    final dto = CourseDto.fromJson(
      Map<String, dynamic>.from(record['course'] as Map),
    );
    final value = _rememberCourse(dto, conditions);
    final list = _courses.putIfAbsent(value.region, () => <Course>[]);
    list.removeWhere((course) => course.id == value.id);
    list.insert(0, value);
    return value;
  }

  Place rememberRemoteSavedPlace(Json record) {
    final value = ApiMappers.place(record, record['region'] as String? ?? '');
    _putPlace(value);
    return value;
  }

  bool hasHourlyCongestion(String placeId) =>
      _detailRecords.any((c) => c.cellId == place(placeId).cellId);

  /// Sparse fixtures: reuse the closest supplied hour, preferring the same day type.
  /// This is a sample snapshot, not a prediction for the requested visit date.
  Congestion congestion(
    String placeId,
    DateTime visit, {
    bool detail = false,
  }) =>
      congestionOrNull(placeId, visit, detail: detail) ??
      (throw StateError('No congestion fixture for $placeId'));

  Congestion? congestionOrNull(
    String placeId,
    DateTime visit, {
    bool detail = false,
  }) {
    if (!supportedCongestionRegions.contains(place(placeId).region)) {
      return null;
    }
    final cell = place(placeId).cellId;
    var records = (detail ? _detailRecords : congestionRecords)
        .where((c) => c.cellId == cell)
        .toList();
    if (records.isEmpty && detail) return congestionOrNull(placeId, visit);
    if (records.isEmpty) return null;
    final sameDay = records
        .where((c) => c.weekend == (visit.weekday >= DateTime.saturday))
        .toList();
    if (sameDay.isNotEmpty) records = sameDay;
    records.sort(
      (a, b) =>
          (a.hour - visit.hour).abs().compareTo((b.hour - visit.hour).abs()),
    );
    return records.first;
  }

  Future<List<Place>> search(SearchConditions conditions) async =>
      _matchingPlaces(conditions);

  List<Place> _matchingPlaces(SearchConditions conditions) {
    return places.where((p) => p.region == conditions.region).toList();
  }

  Future<List<Course>> recommend(
    SearchConditions conditions,
    UserPreference preference, {
    bool group = false,
  }) async {
    return (await recommendResult(conditions, preference)).courses;
  }

  Future<({SearchConditions conditions, List<Course> courses})> recommendResult(
    SearchConditions conditions,
    UserPreference preference,
  ) async {
    final explicit = conditions.useSelectedRegion;
    final response = await api.search(
      SearchRequestDto(
        query: conditions.query,
        date: explicit ? formatDate(conditions.start) : null,
        startTime: explicit ? formatTime(conditions.start) : null,
        region: explicit ? RegionCode.parse(conditions.region).code : null,
        conditions: explicit
            ? {
                'region': RegionCode.parse(conditions.region).code,
                'date': formatDate(conditions.start),
                'dayType': conditions.start.weekday >= DateTime.saturday
                    ? 'WEEKEND'
                    : 'WEEKDAY',
                'startTime': formatTime(conditions.start),
                'partySize': conditions.people,
                'categories': _categoryCodes(preference.categories),
                'atmospheres':
                    {
                          ...preference.moods,
                          if (conditions.mood.isNotEmpty) conditions.mood,
                        }
                        .map(_atmosphereCode)
                        .where((mood) => mood.isNotEmpty)
                        .toSet()
                        .toList(),
                'crowdPreference': _crowdPreference({
                  ...preference.moods.map(_atmosphereCode),
                  if (conditions.mood.isNotEmpty)
                    _atmosphereCode(conditions.mood),
                }),
                'cuisines': _cuisineCodeList(preference.cuisines),
                'cuisineDetails': preference.cuisineDetails.toList(),
                'allergies': _allergyCodes(preference.allergies),
                'gender': _genderCode(conditions.gender),
                'ageGroup': _ageGroupCode(conditions.ageGroup),
                'companionType': _companionCode(conditions.companionType),
                'excludedFoods': preference.dislikedFood
                    .split(RegExp(r'[,，]+'))
                    .map((food) => food.trim())
                    .where((food) => food.isNotEmpty)
                    .toList(),
                'extractedBy': 'USER',
              }
            : null,
      ),
    );
    final courses = _rememberSearch(response);
    final resolved = response.conditions;
    final applied = conditions.copy()
      ..region = ApiMappers.region(resolved.region)
      ..start = ApiMappers.time(resolved.date, resolved.startTime)
      ..people = resolved.partySize
      ..gender = switch (resolved.json['gender']) {
        'F' => '여성',
        'M' => '남성',
        _ => '무관',
      }
      ..ageGroup =
          (resolved.json['ageGroup'] as String?)?.replaceFirst('s', '대') ?? '무관'
      ..companionType = switch (resolved.json['companionType']) {
        'COUPLE' => '연인',
        'FAMILY' => '가족',
        'COWORKER' => '회사',
        'SOLO' => '혼자',
        _ => '친구',
      }
      ..mood = resolved.atmospheres.firstOrNull ?? '';
    return (conditions: applied, courses: courses);
  }

  List<Course> _rememberSearch(SearchResultDto response) {
    for (final p in response.places) {
      _putPlace(ApiMappers.toPlace(p, response.conditions.region));
      if (p.congestion != null) {
        _record(
          p.placeId,
          p.congestion!.json,
          ApiMappers.time(
            response.conditions.date,
            '${p.congestion!.hour.toString().padLeft(2, '0')}:00',
          ),
        );
      }
    }
    return [
      for (final dto in response.courses)
        _rememberCourse(dto, response.conditions),
    ];
  }

  void _putPlace(Place value) {
    final index = places.indexWhere((p) => p.id == value.id);
    if (index == -1) {
      places.add(value);
    } else {
      places[index] = value;
    }
  }

  Course _rememberCourse(CourseDto dto, ConditionsDto conditions) {
    final course = ApiMappers.toCourse(dto, conditions);
    final stops = dto.stops;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (!places.any((p) => p.id == stop.placeId)) {
        _putPlace(ApiMappers.toPlace(stop, conditions.region));
      }
      final congestion = stop.congestion;
      if (congestion != null) {
        _record(stop.placeId, congestion.json, course.stops[i].arrival);
      }
    }
    return course;
  }

  bool get usesSampleData => api is MockOdigaApi;

  Future<({Place place, Map<int, Congestion> hours})> loadPlaceDetails(
    String id,
    DateTime date,
  ) async {
    final dto = await api.getPlace(id, date: formatDate(date));
    final value = ApiMappers.toPlace(dto, dto.region ?? place(id).region);
    _putPlace(value);
    final hourly = dto.congestionByHour;
    final hours = <int, Congestion>{};
    if (supportedCongestionRegions.contains(value.region)) {
      for (final hour in hourly.hours) {
        final time = hour.hour;
        if (time == null) continue;
        hours[time] = ApiMappers.congestion(
          value.id,
          hour.json,
          ApiMappers.time(hourly.date, '${time.toString().padLeft(2, '0')}:00'),
        );
      }
    }
    return (place: value, hours: hours);
  }

  Future<({Course course, List<WarningDto> warnings})> updateCourse(
    Course draft,
  ) async {
    final dto = await api.updateCourse(
      draft.id,
      CourseUpdateRequestDto(
        startTime: draft.stops.isEmpty
            ? null
            : formatTime(draft.stops.first.arrival),
        stops: [
          for (final s in draft.stops)
            StopInputDto(placeId: s.placeId, stayMinutes: s.stayMinutes),
        ],
      ),
    );
    final source =
        _courses.values
            .expand((c) => c)
            .where((c) => c.id == dto.courseId)
            .firstOrNull ??
        draft;
    final conditions = ConditionsDto.fromJson({
      'region': RegionCode.parse(source.region).code,
      'date': formatDate(source.stops.firstOrNull?.arrival ?? DateTime.now()),
    });
    return (course: _rememberCourse(dto, conditions), warnings: dto.warnings);
  }

  Future<Course> loadSharedCourse(String shareCode) async {
    final dto = await api.getShare(shareCode);
    return _rememberCourse(dto.course, dto.conditions);
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
          name: old.name,
          order: i + 1,
          arrival: arrival,
          stayMinutes: old.stayMinutes,
          travelMinutesToNext: travel,
          distanceMetersToNext: meters,
          congestionBand: old.congestionBand,
          congestionPercentile: old.congestionPercentile,
        ),
      );
      arrival = arrival.add(Duration(minutes: old.stayMinutes + travel));
    }
    return course.copyWith(stops: stops);
  }
}
