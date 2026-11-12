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
  Future<PlacePhotosDto> getPlacePhotos(String placeId);
  Future<CongestionGridDto> getCongestionGrid(
    String region, {
    String? date,
    int? hour,
  });
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
  Future<List<String>> getSavedCourseIds();
  Future<List<Json>> getSavedCourseRecords();
  Future<void> saveCourseId(String courseId);
  Future<void> deleteSavedCourse(String courseId);
  Future<List<String>> getSavedPlaceIds();
  Future<List<Json>> getSavedPlaceRecords();
  Future<void> savePlaceId(String placeId);
  Future<void> deleteSavedPlace(String placeId);
}
