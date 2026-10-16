/// 가짜 API: 서버 없이 assets/mocks/*.json 읽어서 진짜 응답처럼 돌려줌
/// - JSON은 docs/api-spec.md v0.2 형식, 장소는 예린 places.csv, 혼잡도는 윤경 congestion_fake.csv 기준
/// - JSON 새로 만들면 mocks/ → capstone_odiga/assets/mocks/ 로 복사
/// - 검색은 지역별로 하나씩만 있음 (성수 = 주말 오후 조용, 홍대 = 주말 저녁 활기, 강남 = 평일 저녁 4명)
/// - 장소 상세·코스 수정·공유는 어떤 ID 넣어도 같은 JSON
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'api_codes.dart';
import 'api_models.dart';
import 'odiga_api.dart';

/// 파일 읽는 함수. 앱에서는 rootBundle, 테스트에서는 File로 바꿔 끼움
typedef LoadString = Future<String> Function(String assetPath);

class MockOdigaApi implements OdigaApi {
  MockOdigaApi({
    LoadString? loadString,
    this.delay = const Duration(milliseconds: 300),
  }) : _load = loadString ?? rootBundle.loadString;

  final LoadString _load;

  /// 로딩 화면 확인용으로 일부러 기다리는 시간 (테스트에서는 Duration.zero)
  final Duration delay;

  /// PUT으로 저장한 내 설정 (앱 껐다 켜면 사라짐)
  PreferencesDto? _savedPreferences;

  /// 가입 테스트용: 이 이메일로 가입하면 DUPLICATE_EMAIL 에러
  static const takenEmail = 'taken@example.com';

  Future<T> _read<T>(String name, T Function(Json data) parse) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final json = jsonDecode(await _load('assets/mocks/$name.json')) as Json;
    return ApiResponse<T>.fromJson(json, (data) => parse(data as Json)).unwrap();
  }

  @override
  Future<SearchResultDto> search(SearchRequestDto request) {
    final region = request.region ?? _regionInQuery(request.query);
    final file = switch (region) {
      RegionCode.seongsu => 'search_seongsu_weekend_quiet',
      RegionCode.hongdae => 'search_hongdae_weekend_lively',
      RegionCode.gangnam => 'search_gangnam_weekday_group',
      null => 'search_error_condition_missing',
    };
    return _read(file, SearchResultDto.fromJson);
  }

  /// 가짜용 간단 판별. 진짜 조건 추출은 서버(Gemini + 규칙)에서 함
  static RegionCode? _regionInQuery(String query) {
    for (final r in RegionCode.values) {
      if (query.contains(r.label)) return r;
    }
    return null;
  }

  @override
  Future<PlaceDetailDto> placeDetail(String placeId, {String? date}) =>
      _read('place_detail', PlaceDetailDto.fromJson);

  @override
  Future<CourseDto> updateCourse(String courseId, CourseUpdateRequestDto request) =>
      _read('course_update_response', CourseDto.fromJson);

  @override
  Future<ShareDto> createShare(String courseId) =>
      _read('share_create_response', ShareDto.fromJson);

  @override
  Future<SharedCourseDto> sharedCourse(String shareCode) =>
      _read('share_view_response', SharedCourseDto.fromJson);

  @override
  Future<UserDto> signup(SignupRequestDto request) => _read(
    request.email == takenEmail ? 'auth_error_duplicate_email' : 'auth_signup_response',
    UserDto.fromJson,
  );

  @override
  Future<LoginResultDto> login(LoginRequestDto request) =>
      _read('auth_login_response', LoginResultDto.fromJson);

  @override
  Future<PreferencesDto> getPreferences() async =>
      _savedPreferences ?? await _read('preferences', PreferencesDto.fromJson);

  @override
  Future<PreferencesDto> updatePreferences(PreferencesDto preferences) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    _savedPreferences = preferences;
    return preferences;
  }
}
