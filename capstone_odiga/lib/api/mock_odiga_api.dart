import 'dart:convert';

import 'package:flutter/services.dart';

import 'api_codes.dart';
import 'odiga_api.dart';

/// Fixed fixtures, intentionally not a local implementation of the server algorithm.
class MockOdigaApi implements OdigaApi {
  MockOdigaApi({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  final Map<String, Json> _cache = {};
  PreferencesDto? _preferences;
  final _savedCourses = <String>{};
  final _savedPlaces = <String>{};

  @override
  void clearSession() {}

  Future<Json> _read(String file) async {
    try {
      final response = _cache[file] ??= Map<String, dynamic>.from(
        jsonDecode(await _bundle.loadString('assets/mocks/$file')) as Map,
      );
      if (response['success'] != true) {
        throw ApiException(
          response['code'] as String,
          response['message'] as String,
        );
      }
      if (response['data'] is! Map) {
        throw const FormatException('Missing response data');
      }
      return Map<String, dynamic>.from(response['data']);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('MOCK_LOAD_FAILED', '예시 데이터를 불러오지 못했어요.');
    }
  }

  @override
  Future<SearchResultDto> search(SearchRequestDto request) async {
    RegionCode? region;
    if (request.region != null) {
      try {
        region = RegionCode.parse(request.region!);
      } on StateError {
        throw const ApiException('INVALID_INPUT', '지역을 확인해 주세요.');
      }
    } else {
      for (final candidate in RegionCode.values) {
        if (request.query.contains(candidate.label)) {
          region = candidate;
          break;
        }
      }
    }
    if (region == null) {
      return SearchResultDto.fromJson(
        await _read('search_error_condition_missing.json'),
      );
    }
    final file = switch (region) {
      RegionCode.seongsu => 'search_seongsu_weekend_quiet.json',
      RegionCode.hongdae => 'search_hongdae_weekend_lively.json',
      RegionCode.gangnam => 'search_gangnam_weekday_group.json',
    };
    return SearchResultDto.fromJson(await _read(file));
  }

  @override
  Future<PlaceDetailDto> getPlace(String placeId, {String? date}) async {
    final detail = await _read('place_detail.json');
    if (detail['placeId'] == placeId && date == null) {
      return PlaceDetailDto.fromJson(detail);
    }
    if (detail['placeId'] == placeId) {
      return PlaceDetailDto.fromJson({
        ...detail,
        'congestionByHour': _sampleHours(date!),
      });
    }

    const searchFiles = [
      'search_seongsu_weekend_quiet.json',
      'search_hongdae_weekend_lively.json',
      'search_gangnam_weekday_group.json',
    ];
    for (final file in searchFiles) {
      final result = await _read(file);
      final conditions = result['conditions'] as Json;
      final candidates = <Json>[
        for (final place in result['places'] as List)
          Map<String, dynamic>.from(place),
        for (final course in result['courses'] as List)
          for (final stop in course['stops'] as List)
            Map<String, dynamic>.from(stop),
      ];
      for (final place in candidates) {
        if (place['placeId'] != placeId) continue;
        return PlaceDetailDto.fromJson({
          ...place,
          'region': place['region'] ?? conditions['region'],
          'roadAddress': place['roadAddress'] ?? place['address'],
          'openingHours': null,
          'congestionByHour': _sampleHours(date ?? conditions['date']),
        });
      }
    }
    throw const ApiException('PLACE_NOT_FOUND', '장소 정보를 찾을 수 없어요.');
  }

  Json _sampleHours(String date) {
    final weekend = DateTime.parse(date).weekday >= DateTime.saturday;
    final values = weekend
        ? [13, 20, 31, 47, 57, 65, 73, 77, 82, 89, 93, 78, 63, 40, 22]
        : [11, 19, 29, 45, 61, 49, 41, 52, 61, 72, 83, 67, 44, 28, 18];
    return {
      'date': date,
      'dayType': weekend ? 'WEEKEND' : 'WEEKDAY',
      'basis': 'ALL_DAY',
      'hours': [
        for (final (index, value) in values.indexed)
          {
            'hour': index + 9,
            'percentile': value,
            'level': value < 40 ? 'QUIET' : (value < 70 ? 'NORMAL' : 'BUSY'),
          },
      ],
    };
  }

  @override
  Future<PlacePhotosDto> getPlacePhotos(String placeId) async =>
      PlacePhotosDto.fromJson({'available': false, 'photos': []});

  @override
  Future<CongestionGridDto> getCongestionGrid(
    String region, {
    String? date,
    int? hour,
  }) async => CongestionGridDto.fromJson({'cellSizeMeters': 50, 'cells': []});

  @override
  Future<CourseDto> updateCourse(
    String courseId,
    CourseUpdateRequestDto request,
  ) async => CourseDto.fromJson(await _read('course_update_response.json'));
  @override
  Future<ShareCreateDto> createShare(String courseId) async =>
      ShareCreateDto.fromJson(await _read('share_create_response.json'));
  @override
  Future<ShareViewDto> getShare(String shareCode) async =>
      ShareViewDto.fromJson(await _read('share_view_response.json'));
  @override
  Future<UserDto> signup(SignupRequestDto request) async {
    if (request.email == 'taken@example.com') {
      return UserDto.fromJson(await _read('auth_error_duplicate_email.json'));
    }
    return UserDto.fromJson(await _read('auth_signup_response.json'));
  }

  @override
  Future<LoginResultDto> login(LoginRequestDto request) async =>
      LoginResultDto.fromJson(await _read('auth_login_response.json'));
  @override
  Future<PreferencesDto> getPreferences() async =>
      _preferences ??= PreferencesDto.fromJson(await _read('preferences.json'));
  @override
  Future<PreferencesDto> updatePreferences(PreferencesDto preferences) async =>
      _preferences = PreferencesDto.fromJson(preferences.toJson());

  @override
  Future<List<String>> getSavedCourseIds() async => _savedCourses.toList();
  @override
  Future<List<Json>> getSavedCourseRecords() async => const [];
  @override
  Future<void> saveCourseId(String courseId) async {
    _savedCourses.add(courseId);
  }

  @override
  Future<void> deleteSavedCourse(String courseId) async {
    _savedCourses.remove(courseId);
  }

  @override
  Future<List<String>> getSavedPlaceIds() async => _savedPlaces.toList();
  @override
  Future<List<Json>> getSavedPlaceRecords() async => const [];
  @override
  Future<void> savePlaceId(String placeId) async {
    _savedPlaces.add(placeId);
  }

  @override
  Future<void> deleteSavedPlace(String placeId) async {
    _savedPlaces.remove(placeId);
  }
}
