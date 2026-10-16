/// 서버 응답·요청 모양 그대로 옮긴 모델 (docs/api-spec.md v0.2, mocks/*.json 기준)
/// - 이름 끝 Dto = 서버랑 주고받는 모양. 화면용 모델(models/domain.dart)이랑 구분
/// - 필드 이름은 JSON 키랑 똑같이 맞춤 → 명세 바뀌면 여기부터 고치기
/// - 화면용 Course로 바꾸는 건 api_mappers.dart
library;

import 'api_codes.dart';

typedef Json = Map<String, dynamic>;

double _double(Object? v) => (v as num).toDouble();
int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();
List<String> _strings(Object? v) => [
  for (final e in (v as List? ?? const [])) e as String,
];
List<T> _objects<T>(Object? v, T Function(Json json) parse) => [
  for (final e in (v as List? ?? const [])) parse(e as Json),
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 날짜 → 'YYYY-MM-DD'
String formatDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// 시각 → 'HH:mm'
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

// ---------- 공통 응답 틀 ----------

/// 모든 API 공통: { success, code, message, data }
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.code,
    required this.message,
    this.data,
  });

  final bool success;
  final String code, message;
  final T? data;

  factory ApiResponse.fromJson(Json json, T Function(Object? data) parse) {
    final success = json['success'] as bool;
    final data = json['data'];
    return ApiResponse(
      success: success,
      code: json['code'] as String,
      message: json['message'] as String? ?? '',
      data: success && data != null ? parse(data) : null,
    );
  }

  /// 실패면 ApiException, 성공이면 data
  T unwrap() {
    if (!success) throw ApiException(code, message);
    return data as T;
  }
}

/// success = false일 때. code로 화면 분기 (CONDITION_MISSING → 지역 다시 묻기 등)
class ApiException implements Exception {
  const ApiException(this.code, this.message);
  final String code, message;

  @override
  String toString() => 'ApiException($code): $message';
}

// ---------- 검색·추천 POST /api/search ----------

class SearchRequestDto {
  const SearchRequestDto({
    required this.query,
    this.date,
    this.startTime,
    this.region,
  });

  final String query;

  /// 날짜 선택기 값 'YYYY-MM-DD', 문장 속 날짜보다 우선
  final String? date;

  /// 시간 선택기 값 'HH:mm'
  final String? startTime;

  /// 지역 버튼 눌렀을 때만
  final RegionCode? region;

  Json toJson() => {
    'query': query,
    if (date != null) 'date': date,
    if (startTime != null) 'startTime': startTime,
    if (region != null) 'region': region!.code,
  };
}

class SearchResultDto {
  const SearchResultDto({
    required this.searchId,
    required this.query,
    required this.conditions,
    required this.places,
    required this.courses,
    this.notice,
  });

  final String searchId, query;
  final ConditionsDto conditions;

  /// 추천 장소 최대 10곳, 점수 높은 순
  final List<PlaceSummaryDto> places;

  /// 코스 최대 3개, rank 1이 1등. 없으면 빈 목록 + notice
  final List<CourseDto> courses;

  /// 결과 없거나 조건 바꿨을 때 안내 문구, 평소엔 null
  final String? notice;

  factory SearchResultDto.fromJson(Json j) => SearchResultDto(
    searchId: j['searchId'] as String,
    query: j['query'] as String,
    conditions: ConditionsDto.fromJson(j['conditions'] as Json),
    places: _objects(j['places'], PlaceSummaryDto.fromJson),
    courses: _objects(j['courses'], CourseDto.fromJson),
    notice: j['notice'] as String?,
  );
}

/// 추출된 조건. 공유 보기 응답에는 region·date·dayType·startTime·partySize만 옴
class ConditionsDto {
  const ConditionsDto({
    required this.region,
    required this.date,
    required this.dayType,
    required this.startTime,
    required this.partySize,
    this.categories = const [],
    this.atmospheres = const [],
    this.crowdPreference,
    this.allergies = const [],
    this.extractedBy,
  });

  final RegionCode region;
  final String date, startTime;
  final DayTypeCode dayType;
  final int partySize;
  final List<CategoryCode> categories;

  /// 블로그 태그 이름 그대로 (조용함, 데이트, 단체석 등)
  final List<String> atmospheres;
  final CrowdCode? crowdPreference;
  final List<AllergyCode> allergies;

  /// GEMINI / RULE
  final String? extractedBy;

  factory ConditionsDto.fromJson(Json j) => ConditionsDto(
    region: RegionCode.fromCode(j['region']),
    date: j['date'] as String,
    dayType: DayTypeCode.fromCode(j['dayType']),
    startTime: j['startTime'] as String,
    partySize: _int(j['partySize']),
    categories: [
      for (final c in (j['categories'] as List? ?? const []))
        CategoryCode.fromCode(c),
    ],
    atmospheres: _strings(j['atmospheres']),
    crowdPreference: j['crowdPreference'] == null
        ? null
        : CrowdCode.fromCode(j['crowdPreference']),
    allergies: [
      for (final a in (j['allergies'] as List? ?? const []))
        AllergyCode.fromCode(a),
    ],
    extractedBy: j['extractedBy'] as String?,
  );
}

class TagDto {
  const TagDto({required this.tag, required this.mentions});
  final String tag;

  /// 블로그 글에서 언급된 횟수
  final int mentions;

  factory TagDto.fromJson(Json j) =>
      TagDto(tag: j['tag'] as String, mentions: _int(j['mentions']));
}

/// 혼잡도. percentile 0 = 가장 한산, 100 = 가장 붐빔
/// - 검색 장소·코스: 같은 시각끼리 비교 (pct_same_time)
/// - 장소 상세 시간대별: 하루 전체 기준 비교 (basis = ALL_DAY)
/// - hour는 장소 카드·장소 상세에만 있고 코스 stop에는 없음
class CongestionDto {
  const CongestionDto({this.hour, required this.level, required this.percentile});
  final int? hour;
  final LevelCode level;
  final int percentile;

  factory CongestionDto.fromJson(Json j) => CongestionDto(
    hour: _intOrNull(j['hour']),
    level: LevelCode.fromCode(j['level']),
    percentile: _int(j['percentile']),
  );
}

/// 장소 점수 (0~1). total = 0.45·request + 0.30·target + 0.25·congestion
class PlaceScoreDto {
  const PlaceScoreDto({
    required this.total,
    required this.request,
    required this.target,
    required this.congestion,
  });
  final double total, request, target, congestion;

  factory PlaceScoreDto.fromJson(Json j) => PlaceScoreDto(
    total: _double(j['total']),
    request: _double(j['request']),
    target: _double(j['target']),
    congestion: _double(j['congestion']),
  );
}

/// 검색 결과 장소 카드
class PlaceSummaryDto {
  const PlaceSummaryDto({
    required this.placeId,
    required this.name,
    required this.category,
    required this.region,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    required this.placeUrl,
    required this.tags,
    required this.congestion,
    required this.score,
    required this.reason,
  });

  final String placeId, name, address, placeUrl, reason;
  final CategoryCode category;
  final RegionCode region;
  final double lat, lng;
  final String? phone;
  final List<TagDto> tags;
  final CongestionDto congestion;
  final PlaceScoreDto score;

  factory PlaceSummaryDto.fromJson(Json j) => PlaceSummaryDto(
    placeId: j['placeId'] as String,
    name: j['name'] as String,
    category: CategoryCode.fromCode(j['category']),
    region: RegionCode.fromCode(j['region']),
    address: j['address'] as String? ?? '',
    lat: _double(j['lat']),
    lng: _double(j['lng']),
    phone: j['phone'] as String?,
    placeUrl: j['placeUrl'] as String? ?? '',
    tags: _objects(j['tags'], TagDto.fromJson),
    congestion: CongestionDto.fromJson(j['congestion'] as Json),
    score: PlaceScoreDto.fromJson(j['score'] as Json),
    reason: j['reason'] as String? ?? '',
  );
}

// ---------- 코스 ----------

/// 코스 점수 (0~1). total = 0.70·placeAvg + 0.20·moveEfficiency + 0.10·timeFit
class CourseScoreDto {
  const CourseScoreDto({
    required this.total,
    required this.placeAvg,
    required this.moveEfficiency,
    required this.timeFit,
  });
  final double total, placeAvg, moveEfficiency, timeFit;

  factory CourseScoreDto.fromJson(Json j) => CourseScoreDto(
    total: _double(j['total']),
    placeAvg: _double(j['placeAvg']),
    moveEfficiency: _double(j['moveEfficiency']),
    timeFit: _double(j['timeFit']),
  );
}

/// 코스 안 장소 하나
class StopDto {
  const StopDto({
    required this.order,
    required this.slot,
    required this.placeId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.arriveAt,
    required this.leaveAt,
    required this.stayMinutes,
    this.walkMinutesFromPrev,
    this.distanceMetersFromPrev,
    required this.congestion,
    required this.placeScore,
  });

  final int order, stayMinutes;
  final SlotCode slot;
  final String placeId, name;
  final CategoryCode category;
  final double lat, lng;

  /// 'HH:mm', 자정 넘으면 00:xx
  final String arriveAt, leaveAt;

  /// 이전 장소에서 걷는 시간·거리, 첫 장소는 null
  final int? walkMinutesFromPrev, distanceMetersFromPrev;

  /// 이 장소 도착 시각 기준 혼잡도 (검색 시각 아님)
  final CongestionDto congestion;
  final double placeScore;

  factory StopDto.fromJson(Json j) => StopDto(
    order: _int(j['order']),
    slot: SlotCode.fromCode(j['slot']),
    placeId: j['placeId'] as String,
    name: j['name'] as String,
    category: CategoryCode.fromCode(j['category']),
    lat: _double(j['lat']),
    lng: _double(j['lng']),
    arriveAt: j['arriveAt'] as String,
    leaveAt: j['leaveAt'] as String,
    stayMinutes: _int(j['stayMinutes']),
    walkMinutesFromPrev: _intOrNull(j['walkMinutesFromPrev']),
    distanceMetersFromPrev: _intOrNull(j['distanceMetersFromPrev']),
    congestion: CongestionDto.fromJson(j['congestion'] as Json),
    placeScore: _double(j['placeScore']),
  );
}

/// 코스 수정 결과 경고 (TOTAL_TIME_OVER, TOTAL_TIME_UNDER, LONG_WALK, BUSY_AT_ARRIVAL)
/// - 경고 있어도 저장은 됨 → message 그대로 보여주고 사용자가 판단
class WarningDto {
  const WarningDto({required this.code, required this.message});
  final String code, message;

  factory WarningDto.fromJson(Json j) =>
      WarningDto(code: j['code'] as String, message: j['message'] as String);
}

/// 코스. 검색 응답 courses[], 코스 수정 응답, 공유 보기 course 전부 이 모양
/// - rank: 검색 결과일 때 1~3, 수정 후엔 null
/// - warnings: 코스 수정 응답에만 있음, 나머지는 빈 목록
class CourseDto {
  const CourseDto({
    required this.courseId,
    this.rank,
    required this.title,
    required this.reason,
    required this.startAt,
    required this.endAt,
    required this.totalMinutes,
    required this.totalWalkMinutes,
    required this.totalDistanceMeters,
    required this.score,
    required this.stops,
    this.warnings = const [],
  });

  final String courseId, title, reason, startAt, endAt;
  final int? rank;
  final int totalMinutes, totalWalkMinutes, totalDistanceMeters;
  final CourseScoreDto score;
  final List<StopDto> stops;
  final List<WarningDto> warnings;

  factory CourseDto.fromJson(Json j) => CourseDto(
    courseId: j['courseId'] as String,
    rank: _intOrNull(j['rank']),
    title: j['title'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    startAt: j['startAt'] as String,
    endAt: j['endAt'] as String,
    totalMinutes: _int(j['totalMinutes']),
    totalWalkMinutes: _int(j['totalWalkMinutes']),
    totalDistanceMeters: _int(j['totalDistanceMeters']),
    score: CourseScoreDto.fromJson(j['score'] as Json),
    stops: _objects(j['stops'], StopDto.fromJson),
    warnings: _objects(j['warnings'], WarningDto.fromJson),
  );
}

/// 코스 수정 PUT /api/courses/{courseId}
/// - 추가·삭제·교체·순서·체류시간 바뀐 걸 따로 안 보내고, 수정 후 전체 목록 한 번에
/// - 배열 순서 = 방문 순서
class CourseUpdateRequestDto {
  const CourseUpdateRequestDto({this.startTime, required this.stops});

  /// 없으면 원래 코스 시작 시각
  final String? startTime;
  final List<StopEditDto> stops;

  /// 지금 코스 그대로 → 여기서 stops만 바꿔서 보내면 됨
  factory CourseUpdateRequestDto.fromCourse(CourseDto course) =>
      CourseUpdateRequestDto(
        stops: [
          for (final s in course.stops)
            StopEditDto(placeId: s.placeId, stayMinutes: s.stayMinutes),
        ],
      );

  Json toJson() => {
    if (startTime != null) 'startTime': startTime,
    'stops': [for (final s in stops) s.toJson()],
  };
}

class StopEditDto {
  const StopEditDto({required this.placeId, required this.stayMinutes});
  final String placeId;
  final int stayMinutes;

  Json toJson() => {'placeId': placeId, 'stayMinutes': stayMinutes};
}

// ---------- 장소 상세 GET /api/places/{placeId} ----------

class PlaceDetailDto {
  const PlaceDetailDto({
    required this.placeId,
    required this.name,
    required this.category,
    required this.region,
    required this.address,
    this.roadAddress,
    this.phone,
    required this.lat,
    required this.lng,
    required this.kakaoCategory,
    required this.placeUrl,
    this.openingHours,
    required this.tags,
    required this.congestionByHour,
  });

  final String placeId, name, address, kakaoCategory, placeUrl;
  final CategoryCode category;
  final RegionCode region;
  final String? roadAddress, phone;
  final double lat, lng;

  /// 구글 Places 연동 전까지 null → 화면에 "영업시간 정보 없음"
  final String? openingHours;
  final List<TagDto> tags;
  final HourlyCongestionDto congestionByHour;

  factory PlaceDetailDto.fromJson(Json j) => PlaceDetailDto(
    placeId: j['placeId'] as String,
    name: j['name'] as String,
    category: CategoryCode.fromCode(j['category']),
    region: RegionCode.fromCode(j['region']),
    address: j['address'] as String? ?? '',
    roadAddress: j['roadAddress'] as String?,
    phone: j['phone'] as String?,
    lat: _double(j['lat']),
    lng: _double(j['lng']),
    kakaoCategory: j['kakaoCategory'] as String? ?? '',
    placeUrl: j['placeUrl'] as String? ?? '',
    openingHours: j['openingHours'] as String?,
    tags: _objects(j['tags'], TagDto.fromJson),
    congestionByHour: HourlyCongestionDto.fromJson(
      j['congestionByHour'] as Json,
    ),
  );
}

/// 시간대별 혼잡도 9~23시. basis = ALL_DAY (하루 전체 기준이라 몇 시가 붐비는지 보임)
class HourlyCongestionDto {
  const HourlyCongestionDto({
    required this.date,
    required this.dayType,
    required this.basis,
    required this.hours,
  });
  final String date, basis;
  final DayTypeCode dayType;
  final List<CongestionDto> hours;

  factory HourlyCongestionDto.fromJson(Json j) => HourlyCongestionDto(
    date: j['date'] as String,
    dayType: DayTypeCode.fromCode(j['dayType']),
    basis: j['basis'] as String,
    hours: _objects(j['hours'], CongestionDto.fromJson),
  );
}

// ---------- 공유 ----------

/// 공유 만들기 POST /api/courses/{courseId}/share (요청 본문 없음)
class ShareDto {
  const ShareDto({
    required this.shareCode,
    required this.shareUrl,
    required this.shareText,
  });
  final String shareCode, shareUrl;

  /// 카톡에 바로 붙여넣기 가능한 글
  final String shareText;

  factory ShareDto.fromJson(Json j) => ShareDto(
    shareCode: j['shareCode'] as String,
    shareUrl: j['shareUrl'] as String,
    shareText: j['shareText'] as String,
  );
}

/// 공유 코스 보기 GET /api/share/{shareCode}
class SharedCourseDto {
  const SharedCourseDto({
    required this.shareCode,
    required this.createdAt,
    required this.conditions,
    required this.course,
  });
  final String shareCode;
  final DateTime createdAt;
  final ConditionsDto conditions;
  final CourseDto course;

  factory SharedCourseDto.fromJson(Json j) => SharedCourseDto(
    shareCode: j['shareCode'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    conditions: ConditionsDto.fromJson(j['conditions'] as Json),
    course: CourseDto.fromJson(j['course'] as Json),
  );
}

// ---------- 회원 ----------

class SignupRequestDto {
  const SignupRequestDto({
    required this.email,
    required this.password,
    required this.region,
  });
  final String email;

  /// 8자 이상
  final String password;
  final RegionCode region;

  Json toJson() => {
    'email': email,
    'password': password,
    'region': region.code,
  };
}

class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});
  final String email, password;

  Json toJson() => {'email': email, 'password': password};
}

class UserDto {
  const UserDto({
    required this.userId,
    required this.email,
    required this.region,
  });
  final int userId;
  final String email;
  final RegionCode region;

  factory UserDto.fromJson(Json j) => UserDto(
    userId: _int(j['userId']),
    email: j['email'] as String,
    region: RegionCode.fromCode(j['region']),
  );
}

/// 로그인 결과. 이후 요청에 Authorization: Bearer <accessToken>
class LoginResultDto {
  const LoginResultDto({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });
  final String accessToken, tokenType;

  /// 초 단위
  final int expiresIn;
  final UserDto user;

  factory LoginResultDto.fromJson(Json j) => LoginResultDto(
    accessToken: j['accessToken'] as String,
    tokenType: j['tokenType'] as String,
    expiresIn: _int(j['expiresIn']),
    user: UserDto.fromJson(j['user'] as Json),
  );
}

/// 내 설정 GET·PUT /api/users/me/preferences (PUT도 같은 모양으로 보냄)
class PreferencesDto {
  const PreferencesDto({
    required this.region,
    this.atmospheres = const [],
    this.allergies = const [],
  });
  final RegionCode region;

  /// 블로그 태그 이름 그대로. '조용함' 있으면 검색 때 QUIET, '활기' 있으면 LIVELY
  final List<String> atmospheres;
  final List<AllergyCode> allergies;

  factory PreferencesDto.fromJson(Json j) => PreferencesDto(
    region: RegionCode.fromCode(j['region']),
    atmospheres: _strings(j['atmospheres']),
    allergies: [
      for (final a in (j['allergies'] as List? ?? const []))
        AllergyCode.fromCode(a),
    ],
  );

  Json toJson() => {
    'region': region.code,
    'atmospheres': atmospheres,
    'allergies': [for (final a in allergies) a.code],
  };
}
