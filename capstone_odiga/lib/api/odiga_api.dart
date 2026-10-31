import 'api_models.dart';

export 'api_models.dart';

class ApiException implements Exception {
  const ApiException(this.code, this.message);
  final String code, message;
  @override
  String toString() => '$code: $message';
}

/// Eight API features from docs/api-spec.md. Preferences support both GET and PUT.
abstract interface class OdigaApi {
  void clearSession();
  Future<SearchResultDto> search(SearchRequestDto request);
  Future<PlaceDetailDto> getPlace(String placeId, {String? date});
  Future<CourseDto> updateCourse(
    String courseId,
    CourseUpdateRequestDto request,
  );
  Future<ShareCreateDto> createShare(String courseId);
  Future<ShareViewDto> getShare(String shareCode);
  Future<UserDto> signup(SignupRequestDto request);
  Future<LoginResultDto> login(LoginRequestDto request);
  Future<PreferencesDto> getPreferences();
  Future<PreferencesDto> updatePreferences(PreferencesDto preferences);
}
