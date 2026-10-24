import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/domain.dart';
import '../api/api_codes.dart';
import '../api/api_mappers.dart';
import '../api/mock_odiga_api.dart';
import '../api/odiga_api.dart';

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
    final results = await Future.wait<ApiDto>([
      client.search(const SearchRequestDto(query: '성수')),
      client.search(const SearchRequestDto(query: '홍대')),
      client.search(const SearchRequestDto(query: '강남')),
      client.getPlace('780757764'),
      client.getPreferences(),
    ]);
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
        repository._record(
          place.id,
          json['congestion'],
          ApiMappers.time(
            date,
            '${(json['congestion']['hour'] as int).toString().padLeft(2, '0')}:00',
          ),
        );
      }
      for (final json in data['courses'] as List) {
        final course = ApiMappers.course(json, conditions);
        courses.add(course);
        final stops = json['stops'] as List;
        for (var i = 0; i < stops.length; i++) {
          final stop = stops[i];
          final id = stop['placeId'] as String;
          byId.putIfAbsent(id, () => ApiMappers.place(stop, regionCode));
          repository._record(id, stop['congestion'], course.stops[i].arrival);
        }
      }
      repository._courses[ApiMappers.region(regionCode)] = courses;
    }
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
    repository.places.addAll(byId.values);
    final prefs = responses[4];
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

  bool hasHourlyCongestion(String placeId) =>
      _detailRecords.any((c) => c.cellId == place(placeId).cellId);

  /// Sparse fixtures: reuse the closest supplied hour, preferring the same day type.
  /// This is a sample snapshot, not a prediction for the requested visit date.
  Congestion congestion(String placeId, DateTime visit, {bool detail = false}) {
    final cell = place(placeId).cellId;
    var records = (detail ? _detailRecords : congestionRecords)
        .where((c) => c.cellId == cell)
        .toList();
    if (records.isEmpty && detail) return congestion(placeId, visit);
    if (records.isEmpty) throw StateError('No congestion fixture for $placeId');
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
    final excluded = conditions.excluded
        .split(RegExp(r'[,\s]+'))
        .where((s) => s.isNotEmpty);
    return places
        .where(
          (p) =>
              p.region == conditions.region &&
              !excluded.any(
                (word) =>
                    p.name.contains(word) ||
                    p.category.contains(word) ||
                    p.tags.any((t) => t.contains(word)),
              ),
        )
        .toList();
  }

  /// Returns the region's fixed API response; preferences do not regenerate fixtures.
  Future<List<Course>> recommend(
    SearchConditions conditions,
    UserPreference preference, {
    bool group = false,
  }) async {
    final response = await api.search(
      SearchRequestDto(
        query: conditions.query,
        date: formatDate(conditions.start),
        startTime: formatTime(conditions.start),
        region: conditions.useSelectedRegion
            ? RegionCode.parse(conditions.region).code
            : null,
      ),
    );
    _rememberSearch(response);
    // The response's extracted region, rather than a stale screen selection, wins.
    final filteredConditions = conditions.copy()
      ..region = ApiMappers.region(response.conditions.region);
    final responseAllowed = (await search(filteredConditions))
        .map((p) => p.id)
        .toSet();
    return response.courses
        .map((c) => ApiMappers.toCourse(c, response.conditions))
        .where((c) => c.stops.every((s) => responseAllowed.contains(s.placeId)))
        .toList();
  }

  void _rememberSearch(SearchResultDto response) {
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
    for (final dto in response.courses) {
      _rememberCourse(dto, response.conditions);
    }
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
      if (!places.any((p) => p.id == stops[i].placeId)) {
        _putPlace(ApiMappers.toPlace(stops[i], conditions.region));
      }
      _record(
        stops[i].placeId,
        stops[i].congestion!.json,
        course.stops[i].arrival,
      );
    }
    return course;
  }

  Future<Place> loadPlace(String id, DateTime date) async {
    final dto = await api.getPlace(id, date: formatDate(date));
    final value = ApiMappers.toPlace(dto, dto.region!);
    _putPlace(value);
    final hourly = dto.congestionByHour;
    _detailRecords.removeWhere((c) => c.cellId == value.cellId);
    for (final hour in hourly.hours) {
      _detailRecords.add(
        ApiMappers.congestion(
          value.id,
          hour.json,
          ApiMappers.time(
            hourly.date,
            '${hour.hour.toString().padLeft(2, '0')}:00',
          ),
        ),
      );
    }
    return value;
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
}
