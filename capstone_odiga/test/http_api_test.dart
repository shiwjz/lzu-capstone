// 진짜 서버 클라이언트 테스트 - 김예민
// - 서버 없이 가짜 응답(assets/mocks)으로 요청 주소·본문·응답 읽기·에러 처리 확인
// - 실행: flutter test test/http_api_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:capstone_odiga/api/http_odiga_api.dart';
import 'package:capstone_odiga/api/odiga_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _mock(String name) => File('assets/mocks/$name.json').readAsStringSync();

http.Response _ok(String name, {int status = 200}) => http.Response.bytes(
  utf8.encode(_mock(name)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Matcher _apiError(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  late List<http.Request> sent;

  HttpOdigaApi api(Future<http.Response> Function(http.Request) handler) {
    sent = [];
    return HttpOdigaApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((req) {
        sent.add(req);
        return handler(req);
      }),
    );
  }

  test('검색: POST /api/search, 본문 = SearchRequestDto, 응답 읽기', () async {
    final client = api((_) async => _ok('search_seongsu_weekend_quiet'));
    final result = await client.search(
      const SearchRequestDto(query: '성수 조용한 카페', date: '2026-10-31'),
    );
    expect(sent.single.method, 'POST');
    expect(sent.single.url.toString(), 'http://localhost:8080/api/search');
    expect(jsonDecode(sent.single.body), {'query': '성수 조용한 카페', 'date': '2026-10-31'});
    expect(result.conditions.region, 'SEONGSU');
    expect(result.courses, hasLength(3));
    expect(result.courses.first.title, isNotEmpty);
  });

  test('검색: 지역 없음(422) → ApiException CONDITION_MISSING', () async {
    final client = api((_) async => _ok('search_error_condition_missing', status: 422));
    await expectLater(
      client.search(const SearchRequestDto(query: '조용한 카페')),
      _apiError('CONDITION_MISSING'),
    );
  });

  test('장소 상세·코스 수정·공유 주소', () async {
    final client = api((req) async {
      final path = req.url.path;
      if (path.startsWith('/api/places/')) return _ok('place_detail');
      if (req.method == 'PUT') return _ok('course_update_response');
      if (path.endsWith('/share')) return _ok('share_create_response');
      return _ok('share_view_response');
    });
    final place = await client.getPlace('780757764', date: '2026-10-31');
    expect(sent.last.url.toString(), 'http://localhost:8080/api/places/780757764?date=2026-10-31');
    expect(place.congestionByHour.basis, 'ALL_DAY');

    final updated = await client.updateCourse(
      'c_1_1',
      const CourseUpdateRequestDto(stops: [StopInputDto(placeId: '1', stayMinutes: 90)]),
    );
    expect(sent.last.method, 'PUT');
    expect(sent.last.url.path, '/api/courses/c_1_1');
    expect(jsonDecode(sent.last.body), {
      'stops': [
        {'placeId': '1', 'stayMinutes': 90},
      ],
    });
    expect(updated.warnings, isNotEmpty);

    final share = await client.createShare('c_1_1');
    expect(sent.last.url.path, '/api/courses/c_1_1/share');
    final view = await client.getShare(share.shareCode);
    expect(sent.last.url.path, '/api/share/${share.shareCode}');
    expect(view.course.stops, isNotEmpty);
  });

  test('로그인하면 이후 요청에 토큰 헤더', () async {
    final client = api((req) async => req.url.path == '/api/auth/login'
        ? _ok('auth_login_response')
        : _ok('preferences'));
    await client.login(const LoginRequestDto(email: 'test@example.com', password: 'test1234!'));
    await client.getPreferences();
    expect(sent.last.headers['Authorization'], 'Bearer eyJhbGciOiJIUzI1NiJ9.mock.token');
  });

  test('서버 꺼짐 → NETWORK_ERROR, 없는 API(404) → NOT_READY', () async {
    final down = api((_) async => throw const SocketException('refused'));
    await expectLater(down.getShare('x'), _apiError('NETWORK_ERROR'));

    final notReady = api((_) async => http.Response('{"status":404,"error":"Not Found"}', 404));
    await expectLater(
      notReady.signup(const SignupRequestDto(email: 'a@b.c', password: '12345678', region: 'SEONGSU')),
      _apiError('NOT_READY'),
    );
  });

  test('내 설정 API 아직 없으면 앱 안 기본값으로 (앱 안 멈춤)', () async {
    final client = api((_) async => http.Response('{"status":404,"error":"Not Found"}', 404));
    expect((await client.getPreferences()).region, 'SEONGSU');
    await client.updatePreferences(
      PreferencesDto(region: 'HONGDAE', atmospheres: const ['데이트'], allergies: const []),
    );
    expect((await client.getPreferences()).region, 'HONGDAE');
  });
}
