import 'package:capstone_odiga/api/api_codes.dart';
import 'package:capstone_odiga/api/api_mappers.dart';
import 'package:capstone_odiga/api/mock_odiga_api.dart';
import 'package:capstone_odiga/api/odiga_api.dart';
import 'package:capstone_odiga/state/app_state.dart';
import 'package:capstone_odiga/models/domain.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingApi extends MockOdigaApi {
  SearchRequestDto? lastSearch;
  CourseUpdateRequestDto? lastUpdate;
  @override
  Future<SearchResultDto> search(SearchRequestDto request) {
    lastSearch = request;
    return super.search(request);
  }

  @override
  Future<CourseDto> updateCourse(
    String courseId,
    CourseUpdateRequestDto request,
  ) {
    lastUpdate = request;
    return super.updateCourse(courseId, request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OdigaApi api;
  setUp(() => api = MockOdigaApi());

  test(
    'three search scenarios preserve server titles, scores and outgoing legs',
    () async {
      for (final region in RegionCode.values) {
        final response = await api.search(
          SearchRequestDto(query: '${region.label}에서 놀고 싶어'),
        );
        expect(response.conditions.region, region.code);
        expect(response.courses.length, 3);
        expect(response.places.length, lessThanOrEqualTo(10));
        for (final dto in response.courses) {
          final course = ApiMappers.toCourse(dto, response.conditions);
          expect(course.title, dto.title);
          expect(course.reason, dto.reason);
          expect(course.totalMinutes, dto.totalMinutes);
          expect(
            course.distanceKm * 1000,
            closeTo(dto.totalDistanceMeters, .001),
          );
          expect(course.stops.last.travelMinutesToNext, 0);
          expect(dto.score.placeAvg, isNotNull);
        }
      }
    },
  );

  test(
    'missing region exposes fixture error and region selection overrides text',
    () async {
      for (final query in ['', '조용한 카페 가고 싶어']) {
        await expectLater(
          api.search(SearchRequestDto(query: query)),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'CONDITION_MISSING')
                .having(
                  (e) => e.message,
                  'message',
                  '어느 지역에서 찾을까요? (성수·홍대·강남)',
                ),
          ),
        );
      }
      final selected = await api.search(
        const SearchRequestDto(query: '홍대', region: 'GANGNAM'),
      );
      expect(selected.conditions.region, 'GANGNAM');
      await expectLater(
        api.search(const SearchRequestDto(query: '홍대', region: 'UNKNOWN')),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'INVALID_INPUT'),
        ),
      );
    },
  );

  test('detail is fixed for any ID and retains all-day congestion', () async {
    final a = await api.getPlace('some-id', date: '2026-10-16');
    final b = await api.getPlace('other-id');
    expect(a.toJson(), b.toJson());
    expect(a.openingHours, isNull);
    expect(a.congestionByHour.basis, 'ALL_DAY');
    expect(a.congestionByHour.hours.length, 15);
    expect(a.tags.first.mentions, isA<int>());
  });

  test(
    'update sends the full ordered list and returns fixed warnings',
    () async {
      const request = CourseUpdateRequestDto(
        startTime: '15:00',
        stops: [
          StopInputDto(placeId: 'a', stayMinutes: 90),
          StopInputDto(placeId: 'b', stayMinutes: 50),
        ],
      );
      expect(request.toJson(), {
        'startTime': '15:00',
        'stops': [
          {'placeId': 'a', 'stayMinutes': 90},
          {'placeId': 'b', 'stayMinutes': 50},
        ],
      });
      final a = await api.updateCourse('any-id', request);
      final b = await api.updateCourse(
        'other-id',
        const CourseUpdateRequestDto(stops: []),
      );
      expect(a.toJson(), b.toJson());
      expect(a.rank, isNull);
      expect(a.totalMinutes, 212);
      expect(a.warnings.map((w) => w.code), [
        'TOTAL_TIME_OVER',
        'BUSY_AT_ARRIVAL',
      ]);
    },
  );

  test('share creation and lookup use fixed fixtures', () async {
    final created = await api.createShare('any-id');
    expect(Uri.parse(created.shareUrl).pathSegments.last, created.shareCode);
    final view = await api.getShare('any-code');
    expect(view.shareCode, created.shareCode);
    expect(view.course.title, isNotEmpty);
    expect(view.createdAt.isUtc, isTrue);
  });

  test('signup, duplicate email and login match documented examples', () async {
    final user = await api.signup(
      const SignupRequestDto(
        email: 'test@example.com',
        password: 'test1234!',
        region: 'SEONGSU',
      ),
    );
    expect(user.email, 'test@example.com');
    await expectLater(
      api.signup(
        const SignupRequestDto(
          email: 'taken@example.com',
          password: 'test1234!',
          region: 'SEONGSU',
        ),
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'DUPLICATE_EMAIL'),
      ),
    );
    final login = await api.login(
      const LoginRequestDto(email: 'test@example.com', password: 'test1234!'),
    );
    expect(login.user.userId, user.userId);
    expect(login.tokenType, 'Bearer');
    expect(login.accessToken, isNotEmpty);
    expect(login.expiresIn, 3600);
  });

  test(
    'preferences PUT replaces lists and survives subsequent GET in the session',
    () async {
      expect((await api.getPreferences()).region, 'SEONGSU');
      final saved = await api.updatePreferences(
        PreferencesDto(region: 'HONGDAE', atmospheres: ['데이트'], allergies: []),
      );
      expect((await api.getPreferences()).toJson(), saved.toJson());
      expect(saved.allergies, isEmpty);
      expect(RegionCode.seongsu.label, '성수');
      expect(formatDate(DateTime(2026, 1, 2)), '2026-01-02');
      expect(formatTime(DateTime(2026, 1, 2, 3, 4)), '03:04');
    },
  );

  test('app uses injected API for search, updates and preferences', () async {
    final injected = RecordingApi();
    final app = await AppState.load(api: injected);
    addTearDown(app.dispose);
    await app.repository.recommend(
      SearchConditions(query: '홍대', useSelectedRegion: false),
      UserPreference(),
    );
    expect(injected.lastSearch!.query, '홍대');
    expect(injected.lastSearch!.region, isNull);
    final draft = app.savedCourses.first;
    final result = await app.repository.updateCourse(draft);
    expect(
      injected.lastUpdate!.stops.map((s) => s.placeId),
      draft.stops.map((s) => s.placeId),
    );
    for (final stop in result.course.stops) {
      expect(app.repository.place(stop.placeId).name, isNotEmpty);
    }
    await app.savePreference(UserPreference(moods: {'데이트'}, allergies: 'MILK'));
    expect((await injected.getPreferences()).allergies, ['MILK']);
  });
}
