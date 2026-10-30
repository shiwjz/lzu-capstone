import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mock_odiga_api.dart';
import 'odiga_api.dart';

/// 진짜 서버 API (9주차 연결용) - 김예민
/// - OdigaApi 그대로 구현 → 화면 코드는 안 바꾸고 MockOdigaApi 자리에 이것만 넣으면 됨
/// - 서버 주소: --dart-define=ODIGA_API=http://주소:8080 (없으면 가짜 JSON 사용, defaultOdigaApi 참고)
///   · 크롬(웹)·iOS 시뮬레이터: http://localhost:8080
///   · 안드로이드 에뮬레이터: http://10.0.2.2:8080
///   · 실제 폰: 같은 와이파이에서 노트북 IP (예: http://192.168.0.12:8080)
/// - 실패는 전부 ApiException(code, message)로 던짐 → 화면은 MockOdigaApi 쓸 때랑 똑같이 처리
///   · 서버 꺼짐·인터넷 끊김: NETWORK_ERROR
///   · 아직 서버에 없는 API(회원·내 설정, 정헌 작업 중): NOT_READY
class HttpOdigaApi implements OdigaApi {
  HttpOdigaApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Gemini 조건 추출이 붙으면 검색이 몇 초 걸릴 수 있어서 넉넉하게
  final Duration timeout;

  /// 로그인하면 저장, 이후 요청 헤더에 자동으로 붙음
  String? accessToken;

  Future<Json> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    try {
      final Future<http.Response> request = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        _ => throw ArgumentError(method),
      };
      res = await request.timeout(timeout);
    } catch (_) {
      throw const ApiException(
        'NETWORK_ERROR',
        '서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (decoded is! Map || !decoded.containsKey('success')) {
      // 응답 틀이 아님 = 서버에 그 API가 아직 없거나 서버 오류
      if (res.statusCode == 404) {
        throw const ApiException('NOT_READY', '아직 준비 중인 기능이에요.');
      }
      throw ApiException(
        'INTERNAL_SERVER_ERROR',
        '서버 응답을 읽지 못했어요. (${res.statusCode})',
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['success'] != true) {
      throw ApiException(
        json['code'] as String? ?? 'INTERNAL_SERVER_ERROR',
        json['message'] as String? ?? '요청에 실패했어요.',
      );
    }
    final data = json['data'];
    if (data is! Map) {
      throw const ApiException('INTERNAL_SERVER_ERROR', '서버 응답에 data가 없어요.');
    }
    return Map<String, dynamic>.from(data);
  }

  String _id(String value) => Uri.encodeComponent(value);

  @override
  Future<SearchResultDto> search(SearchRequestDto request) async =>
      SearchResultDto.fromJson(
        await _send('POST', '/api/search', body: request.toJson()),
      );

  @override
  Future<PlaceDetailDto> getPlace(String placeId, {String? date}) async =>
      PlaceDetailDto.fromJson(
        await _send(
          'GET',
          '/api/places/${_id(placeId)}',
          query: date == null ? null : {'date': date},
        ),
      );

  @override
  Future<CourseDto> updateCourse(
    String courseId,
    CourseUpdateRequestDto request,
  ) async => CourseDto.fromJson(
    await _send('PUT', '/api/courses/${_id(courseId)}', body: request.toJson()),
  );

  @override
  Future<ShareCreateDto> createShare(String courseId) async =>
      ShareCreateDto.fromJson(
        await _send('POST', '/api/courses/${_id(courseId)}/share'),
      );

  @override
  Future<ShareViewDto> getShare(String shareCode) async =>
      ShareViewDto.fromJson(await _send('GET', '/api/share/${_id(shareCode)}'));

  @override
  Future<UserDto> signup(SignupRequestDto request) async => UserDto.fromJson(
    await _send('POST', '/api/auth/signup', body: request.toJson()),
  );

  @override
  Future<LoginResultDto> login(LoginRequestDto request) async {
    final result = LoginResultDto.fromJson(
      await _send('POST', '/api/auth/login', body: request.toJson()),
    );
    accessToken = result.accessToken;
    return result;
  }

  /// 내 설정: 서버 API 붙기 전(정헌 작업 중)에는 실패하면 앱 안에만 저장
  /// → 내 설정 때문에 홈 화면이 안 뜨는 일 없게
  /// - 없는 주소가 크롬에선 CORS(NETWORK_ERROR), 서버 공통 에러처리에선 500으로 와서 에러 종류 안 가림
  /// - @성정헌 회원·내 설정 API 붙으면 NOT_READY·UNAUTHORIZED만 받게 다시 좁히기
  PreferencesDto? _localPreferences;

  static bool _notReady(ApiException e) => true;

  @override
  Future<PreferencesDto> getPreferences() async {
    try {
      return PreferencesDto.fromJson(await _send('GET', '/api/users/me/preferences'));
    } on ApiException catch (e) {
      if (!_notReady(e)) rethrow;
      return _localPreferences ??=
          PreferencesDto(region: 'SEONGSU', atmospheres: const [], allergies: const []);
    }
  }

  @override
  Future<PreferencesDto> updatePreferences(PreferencesDto preferences) async {
    try {
      return PreferencesDto.fromJson(
        await _send('PUT', '/api/users/me/preferences', body: preferences.toJson()),
      );
    } on ApiException catch (e) {
      if (!_notReady(e)) rethrow;
      return _localPreferences = preferences;
    }
  }
}

/// 실행할 때 서버 주소 넣으면 진짜 서버, 안 넣으면 가짜 JSON
/// - flutter run --dart-define=ODIGA_API=http://localhost:8080
/// - main.dart에서: AppState.load(api: defaultOdigaApi())
OdigaApi defaultOdigaApi() {
  const baseUrl = String.fromEnvironment('ODIGA_API');
  return baseUrl.isEmpty ? MockOdigaApi() : HttpOdigaApi(baseUrl: baseUrl);
}
