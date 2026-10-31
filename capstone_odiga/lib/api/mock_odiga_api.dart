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
  Future<PlaceDetailDto> getPlace(String placeId, {String? date}) async =>
      PlaceDetailDto.fromJson(await _read('place_detail.json'));
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
}
