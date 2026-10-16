/// 오디가 API 8개 목록 (docs/api-spec.md v0.2)
/// - 화면은 이 인터페이스만 보고 쓰기
/// - 지금: MockOdigaApi (assets/mocks/*.json 읽음)
/// - 9주차: HttpOdigaApi (정헌 서버 주소로 진짜 요청) 만들어서 갈아끼우기 → 화면 코드는 안 바뀜
/// - 실패(success = false)는 전부 ApiException(code, message)로 던짐
library;

import 'api_models.dart';

abstract class OdigaApi {
  /// POST /api/search: 문장 한 줄 → 추천 장소 최대 10곳 + 코스 최대 3개
  /// - 지역 못 찾으면 ApiException('CONDITION_MISSING') → 지역 다시 물어보기
  Future<SearchResultDto> search(SearchRequestDto request);

  /// GET /api/places/{placeId}?date=YYYY-MM-DD: 장소 상세 + 시간대별 혼잡도
  Future<PlaceDetailDto> placeDetail(String placeId, {String? date});

  /// PUT /api/courses/{courseId}: 수정한 전체 목록 보내면 다시 계산된 코스 + warnings
  Future<CourseDto> updateCourse(String courseId, CourseUpdateRequestDto request);

  /// POST /api/courses/{courseId}/share: 공유 코드·링크·카톡용 글
  Future<ShareDto> createShare(String courseId);

  /// GET /api/share/{shareCode}: 공유 링크로 연 코스 (로그인 불필요)
  Future<SharedCourseDto> sharedCourse(String shareCode);

  /// POST /api/auth/signup (이미 있는 이메일이면 DUPLICATE_EMAIL)
  Future<UserDto> signup(SignupRequestDto request);

  /// POST /api/auth/login → 토큰은 이후 요청 헤더에
  Future<LoginResultDto> login(LoginRequestDto request);

  /// GET /api/users/me/preferences (로그인 필요)
  Future<PreferencesDto> getPreferences();

  /// PUT /api/users/me/preferences: 목록은 지우고 다시 저장, 저장된 값 반환
  Future<PreferencesDto> updatePreferences(PreferencesDto preferences);
}
