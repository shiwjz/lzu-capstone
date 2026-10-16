// 가짜 API 테스트 - 김예민
// - assets/mocks/*.json 15개가 전부 모델로 읽히는지 + 값이 명세대로인지
// - 실행: flutter test test/api_mock_test.dart
// - mocks JSON 다시 만들면 이 테스트 먼저 돌려보기

import 'dart:convert';
import 'dart:io';

import 'package:capstone_odiga/api/api_codes.dart';
import 'package:capstone_odiga/api/api_mappers.dart';
import 'package:capstone_odiga/api/api_models.dart';
import 'package:capstone_odiga/api/mock_odiga_api.dart';
import 'package:flutter_test/flutter_test.dart';

Json _mock(String name) =>
    jsonDecode(File('assets/mocks/$name.json').readAsStringSync()) as Json;

Matcher _apiError(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  late MockOdigaApi api;

  setUp(() {
    api = MockOdigaApi(
      loadString: (path) => File(path).readAsString(),
      delay: Duration.zero,
    );
  });

  test('검색: 지역별 가짜 JSON 3개 다 읽힘', () async {
    final cases = [
      ('토요일 오후 3시에 성수에서 조용한 카페', RegionCode.seongsu),
      ('홍대에서 신나게', RegionCode.hongdae),
      ('강남역 근처 4명 모임', RegionCode.gangnam),
    ];
    for (final (query, region) in cases) {
      final result = await api.search(SearchRequestDto(query: query));
      expect(result.conditions.region, region);
      expect(result.places, hasLength(10));
      expect(result.courses, hasLength(3));
      expect(result.notice, isNull);
      for (final course in result.courses) {
        expect(course.title, isNotEmpty);
        expect(course.reason, isNotEmpty);
        expect(course.stops, hasLength(3));
        expect(course.stops.first.walkMinutesFromPrev, isNull);
        expect(course.warnings, isEmpty);
        // 총 소요시간 = 체류 합 + 도보 합
        final sum = course.stops.fold<int>(
          0,
          (t, s) => t + s.stayMinutes + (s.walkMinutesFromPrev ?? 0),
        );
        expect(sum, course.totalMinutes);
      }
    }
  });

  test('검색: 지역 버튼 값이 문장보다 우선', () async {
    final result = await api.search(
      const SearchRequestDto(query: '성수 카페', region: RegionCode.gangnam),
    );
    expect(result.conditions.region, RegionCode.gangnam);
  });

  test('검색: 지역 못 찾으면 CONDITION_MISSING', () async {
    await expectLater(
      api.search(const SearchRequestDto(query: '조용한 카페 가고 싶어')),
      _apiError('CONDITION_MISSING'),
    );
  });

  test('성수 1등 코스 값', () async {
    final result = await api.search(const SearchRequestDto(query: '성수'));
    final best = result.courses.first;
    expect(best.rank, 1);
    expect(best.title, '성수 오후 노래방 코스');
    expect(best.totalMinutes, 176);
    expect(best.score.total, 0.87);
    expect(best.stops.map((s) => s.slot), [SlotCode.play, SlotCode.cafe, SlotCode.meal]);
    expect(best.stops[1].arriveAt, '16:05');
    expect(best.stops[1].congestion.level, LevelCode.quiet);
    expect(result.conditions.crowdPreference, CrowdCode.quiet);
    expect(result.conditions.dayType, DayTypeCode.weekend);
    expect(result.conditions.categories, [CategoryCode.cafe, CategoryCode.food]);
  });

  test('강남: 갑각류 알레르기 조건', () async {
    final result = await api.search(const SearchRequestDto(query: '강남'));
    expect(result.conditions.allergies, [AllergyCode.shellfish]);
    expect(result.conditions.partySize, 4);
  });

  test('코스 수정 → 다시 계산된 코스 + 경고 2개', () async {
    final best = (await api.search(const SearchRequestDto(query: '성수'))).courses.first;
    final request = CourseUpdateRequestDto.fromCourse(best);
    expect(request.toJson()['stops'], hasLength(3));

    final updated = await api.updateCourse(best.courseId, request);
    expect(updated.rank, isNull);
    expect(updated.totalMinutes, 212);
    expect(updated.warnings.map((w) => w.code), ['TOTAL_TIME_OVER', 'BUSY_AT_ARRIVAL']);
  });

  test('장소 상세: 시간대별 혼잡도 9~23시, 영업시간 null', () async {
    final place = await api.placeDetail('780757764', date: '2026-10-17');
    expect(place.category, CategoryCode.cafe);
    expect(place.congestionByHour.basis, 'ALL_DAY');
    expect(place.congestionByHour.hours.map((h) => h.hour), List.generate(15, (i) => i + 9));
    expect(place.openingHours, isNull);
    expect(place.tags, isNotEmpty);
  });

  test('공유 만들기 → 공유 보기', () async {
    final share = await api.createShare('c_seongsu_1');
    expect(share.shareText, startsWith('[오디가]'));
    final view = await api.sharedCourse(share.shareCode);
    expect(view.shareCode, share.shareCode);
    expect(view.conditions.region, RegionCode.seongsu);
    expect(view.conditions.categories, isEmpty); // 공유 보기 conditions엔 5개만
    expect(view.course.title, '성수 오후 노래방 코스');
  });

  test('회원: 가입·중복 이메일·로그인', () async {
    final user = await api.signup(
      const SignupRequestDto(email: 'test@example.com', password: 'test1234!', region: RegionCode.seongsu),
    );
    expect(user.userId, 1);
    await expectLater(
      api.signup(
        const SignupRequestDto(email: MockOdigaApi.takenEmail, password: 'test1234!', region: RegionCode.seongsu),
      ),
      _apiError('DUPLICATE_EMAIL'),
    );
    final login = await api.login(
      const LoginRequestDto(email: 'test@example.com', password: 'test1234!'),
    );
    expect(login.tokenType, 'Bearer');
    expect(login.user.region, RegionCode.seongsu);
  });

  test('내 설정: 보기 → 수정 → 다시 보기', () async {
    final pref = await api.getPreferences();
    expect(pref.atmospheres, contains('조용함'));
    expect(pref.allergies, [AllergyCode.shellfish]);

    await api.updatePreferences(
      const PreferencesDto(region: RegionCode.hongdae, atmospheres: ['데이트']),
    );
    final again = await api.getPreferences();
    expect(again.region, RegionCode.hongdae);
    expect(again.allergies, isEmpty);
  });

  test('요청 toJson = 가짜 요청 JSON (키 이름 확인)', () {
    expect(
      const LoginRequestDto(email: 'test@example.com', password: 'test1234!').toJson(),
      _mock('auth_login_request'),
    );
    expect(
      const SignupRequestDto(email: 'test@example.com', password: 'test1234!', region: RegionCode.seongsu).toJson(),
      _mock('auth_signup_request'),
    );
    final edit = _mock('course_update_request');
    final request = CourseUpdateRequestDto(
      stops: [
        for (final s in edit['stops'] as List)
          StopEditDto(placeId: s['placeId'] as String, stayMinutes: s['stayMinutes'] as int),
      ],
    );
    expect(request.toJson(), edit);
    final pref = PreferencesDto.fromJson(_mock('preferences')['data'] as Json);
    expect(pref.toJson(), _mock('preferences')['data']);
  });

  test('예령 화면 모델(Course)로 바꾸기', () async {
    final result = await api.search(const SearchRequestDto(query: '성수'));
    final course = result.courses.first.toCourse(
      date: DateTime.parse(result.conditions.date),
      region: result.conditions.region,
    );
    expect(course.title, '성수 오후 노래방 코스');
    expect(course.region, '성수');
    expect(course.totalMinutes, 176);
    expect(course.matchScore, 87);
    expect(course.stops[1].arrival, DateTime(2026, 10, 17, 16, 5));
    expect(course.stops.last.travelMinutesToNext, 0);
  });

  test('코드값 ↔ 한글', () {
    expect(RegionCode.fromCode('HONGDAE').label, '홍대');
    expect(CrowdCode.fromCode('DEFAULT'), CrowdCode.any);
    expect(LevelCode.busy.label, '혼잡');
    expect(() => CategoryCode.fromCode('BAR'), throwsFormatException);
  });
}
