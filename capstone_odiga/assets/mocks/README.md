# 가짜 응답 JSON (API 명세 v0.2)

- 서버 없이도 화면 개발할 수 있게 API 응답 형식 그대로 만든 가짜 데이터
- 명세는 `docs/api-spec.md` 참고

## 데이터 출처

- 응답 틀: 백엔드 `ApiResponse`와 동일 (success · code · message · data)
- 장소 이름·좌표·주소: `output/places.csv` (최예린, 중심 500m 안 1,795곳)
- 혼잡도: `congestion_fake.csv` (이윤경)
  - 검색·코스: `pct_same_time` (같은 시간끼리 비교)
  - 장소 상세 시간대 그래프: `pct_all_day` (하루 전체 비교)
- 태그, 사용자 요구·타깃 점수: 아직 가짜 값 (블로그·성연령 데이터 들어오면 교체)
- 거리·도보 시간·도착 시각·코스 조합: 코스 생성 규칙 v0.1로 실제 계산

## 다시 만들기

- 장소나 혼잡도 파일 바뀌면 저장소 맨 위 폴더에서 실행

```
python mocks/generate_mocks.py
```

## Flutter에서 쓰기 (@서예령)

- 이 폴더 JSON을 `capstone_odiga/assets/mocks/`에 복사해둠 (pubspec.yaml에 `- assets/mocks/` 한 줄 추가함)
- JSON 다시 만들면 `assets/mocks/`에도 다시 복사하기
- 읽는 코드는 `capstone_odiga/lib/api/`

| 파일 | 내용 |
| --- | --- |
| `odiga_api.dart` | API 8개 목록 (화면은 이것만 보고 쓰기) |
| `mock_odiga_api.dart` | 가짜 JSON 읽어서 진짜 응답처럼 돌려줌 |
| `api_models.dart` | 서버 응답 모양 그대로 (`CourseDto`, `StopDto` 등) |
| `api_codes.dart` | 코드값 ↔ 한글 (`RegionCode.seongsu.label` → 성수) |
| `api_mappers.dart` | `CourseDto` → 화면용 `Course` 바꾸기 |

```dart
final api = MockOdigaApi();
try {
  final result = await api.search(SearchRequestDto(query: text, date: formatDate(day), startTime: formatTime(day)));
  final cards = result.courses; // title, reason, stops, score
} on ApiException catch (e) {
  if (e.code == 'CONDITION_MISSING') { /* 지역 다시 묻기, e.message 그대로 보여주면 됨 */ }
}
```

- 가짜라서 검색은 지역별로 하나씩만 (문장에 성수·홍대·강남 없으면 CONDITION_MISSING 에러)
- 장소 상세·코스 수정·공유는 어떤 ID 넣어도 같은 JSON
- 가입할 때 `taken@example.com` 넣으면 DUPLICATE_EMAIL 에러 → 에러 화면 확인용
- 테스트: `flutter test test/api_mock_test.dart`
- 9주차: 서버 붙이면 `HttpOdigaApi`만 새로 만들어서 `MockOdigaApi` 자리에 넣기 → 화면 코드는 그대로
