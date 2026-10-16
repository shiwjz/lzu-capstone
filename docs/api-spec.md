# 오디가 API 명세 v0.2

2026-10-16 · 김예민

## v0.2에서 바뀐 점

| 바뀐 것 | v0.1 | v0.2 | 근거 |
| --- | --- | --- | --- |
| 응답 틀 | success · data · error{code, message} | success · code · message · data | 성정헌 ApiResponse |
| 에러 코드 | INVALID_REQUEST, INTERNAL_ERROR | INVALID_INPUT, INTERNAL_SERVER_ERROR + USER_NOT_FOUND, DUPLICATE_EMAIL | 성정헌 ErrorCode |
| 회원가입 | email, password, nickname | email, password, region | users 테이블에 nickname 없음, region 있음 |
| 내 설정 | moods, crowdPreference, allergies, homeRegion | region, atmospheres, allergies | user_preference.atmosphere, user_allergy.allergy_name |
| 장소 데이터 | 2,406곳 (가운데에서 최대 약 0.8km) | 1,795곳 (중심좌표 500m 안) | 최예린 collect_places.py |
| 혼잡도·점수 | 가짜 값 | 혼잡도는 윤경 데이터(가짜 유동인구 기반), 점수·태그는 아직 가짜 | 이윤경 congestion_fake.csv |
| 코스 제목·추천 이유 | 없음 | courses[]에 title, reason 추가 | 서예령 코스 카드 화면 |

혼잡 선호(crowdPreference)는 따로 저장하지 않고 분위기 태그로 대신. 내 설정에 '조용함'이 있으면 QUIET, '활기'가 있으면 LIVELY로, 검색 문장에 따로 쓰면 문장을 따름. 그래서 DB 테이블은 지금 그대로 쓰면 됨.

## 공통 규칙

모든 API는 같은 응답 틀(success · code · message · data)을 쓰고, 값은 영어 대문자 코드로 주고받기. 화면에 보이는 한글은 앱에서 아래 표대로 바꿔 표시.

- **기본 주소:** `/api` (배포 주소는 성정헌 공유)
- **인증:** 로그인 API가 준 토큰을 `Authorization: Bearer <토큰>` 헤더에 넣기. 검색·장소·공유 보기는 로그인 없이도 가능하고, 로그인하면 내 설정(선호·알레르기) 자동 반영.
- **표기:** 날짜 `YYYY-MM-DD`, 시각 `HH:mm`(한국 시간), 좌표 `lat`·`lng`, 거리 m, 시간 분, 점수 0~1(소수 둘째 자리)
- **장소 ID:** 카카오 장소 ID를 문자열로 사용 (예: `"423593118"`)

```json
{ "success": true, "code": "SUCCESS", "message": "요청 성공", "data": { } }

{ "success": false, "code": "CONDITION_MISSING",
  "message": "어느 지역에서 찾을까요? (성수·홍대·강남)", "data": null }
```

| 구분 | 코드 → 화면 표시 |
| --- | --- |
| 지역 `region` | SEONGSU 성수 · HONGDAE 홍대 · GANGNAM 강남 |
| 카테고리 `category` | FOOD 음식 · CAFE 카페 · CULTURE 문화 · ACTIVITY 액티비티 · EXPERIENCE 체험 · SHOPPING 쇼핑 · TOUR 관광 · NATURE 자연/휴식 |
| 코스 칸 `slot` | MEAL 식사(FOOD) · CAFE 카페(CAFE) · PLAY 놀거리(나머지 6개) |
| 혼잡도 `level` | QUIET 한산(하위 30%) · NORMAL 보통 · BUSY 혼잡(상위 30%) |
| 혼잡 선호 `crowdPreference` | QUIET 조용한 곳 · DEFAULT 상관없음 · LIVELY 활기찬 곳 |
| 요일 구분 `dayType` | WEEKDAY 주중 · WEEKEND 주말 |

- Gemini 조건 추출 결과도 이 코드로 통일. 계획 문서 예시의 `"성수"`, `"weekend"`는 `"SEONGSU"`, `"WEEKEND"`로 변경

| 에러 코드 | HTTP | 언제 | 백엔드 코드 |
| --- | --- | --- | --- |
| INVALID_INPUT | 400 | 필수 값이 빠지거나 형식이 틀림 | 있음 |
| USER_NOT_FOUND | 404 | 없는 사용자 | 있음 |
| DUPLICATE_EMAIL | 409 | 이미 가입된 이메일 | 있음 |
| INTERNAL_SERVER_ERROR | 500 | 그 밖의 서버 오류 | 있음 |
| UNAUTHORIZED | 401 | 토큰이 없거나 만료됨 (로그인 필요한 API만) | 추가 필요 |
| LOGIN_FAILED | 401 | 이메일 또는 비밀번호 틀림 | 추가 필요 |
| PLACE_NOT_FOUND · COURSE_NOT_FOUND · SHARE_NOT_FOUND | 404 | 없는 장소·코스·공유 코드 | 추가 필요 |
| CONDITION_MISSING | 422 | 문장에서 지역처럼 꼭 필요한 조건을 못 찾음 → 앱에서 다시 물어보기 | 추가 필요 |
| AI_UNAVAILABLE | 503 | Gemini 오류 + 규칙 기반 예비 처리도 실패 | 추가 필요 |

- '추가 필요'는 ErrorCode에 같은 형식으로 추가 부탁 (@성정헌)
- 조건에 맞는 코스가 없는 건 에러 아님 → `courses: []` + 안내 문구(`notice`) 반환

## API 목록

MVP API 총 8개. 계획 문서 초안에서 공유 코스 보기, 회원가입 따로 추가.

| 기능 | 메서드·경로 | 로그인 | 백엔드 담당 | 쓰는 화면 |
| --- | --- | --- | --- | --- |
| 검색·추천 | POST /api/search | 선택 | 김예민 (조건 추출 최예린, 점수 이윤경) | 검색 → 추천 결과·지도·코스 |
| 장소 상세 | GET /api/places/{placeId} | 불필요 | 성정헌 | 장소 카드 상세 |
| 코스 수정 | PUT /api/courses/{courseId} | 선택 | 김예민 | 커스텀 |
| 공유 만들기 | POST /api/courses/{courseId}/share | 선택 | 김예민 | 공유 |
| 공유 코스 보기 | GET /api/share/{shareCode} | 불필요 | 김예민 | 공유 링크로 연 화면 |
| 회원가입 | POST /api/auth/signup | 불필요 | 성정헌 | 로그인 |
| 로그인 | POST /api/auth/login | 불필요 | 성정헌 | 로그인 |
| 내 설정 보기·수정 | GET·PUT /api/users/me/preferences | 필요 | 성정헌 | 마이페이지 |

## 검색·추천 POST /api/search

문장 한 줄 보내면 추천 장소 최대 10곳 + 코스 최대 3개 한 번에 반환. 전체 형식은 `mocks/search_seongsu_weekend_quiet.json` 참고.

```json
{
  "query": "토요일 오후 3시에 성수에서 친구랑 조용한 카페 가고 저녁도 먹고 싶어",
  "date": "2026-10-17",
  "startTime": "15:00"
}
```

| 요청 필드 | 필수 | 설명 |
| --- | --- | --- |
| query | O | 사용자가 입력한 문장 |
| date | X | 날짜 선택기 값. 문장 속 날짜보다 우선 |
| startTime | X | 시간 선택기 값. 없으면 문장에서 추출, 그것도 없으면 현재 시각 다음 정시 |
| region | X | 지역 버튼 선택 시. 문장보다 우선 |

| 응답 data 필드 | 설명 |
| --- | --- |
| searchId | 검색 1회 ID (로그·평가용) |
| conditions | 추출된 조건: region, date, dayType, startTime, partySize, categories, atmospheres(내 설정과 같은 이름), crowdPreference, allergies, extractedBy(GEMINI / RULE) |
| places | 추천 장소 최대 10곳, 점수 높은 순 |
| courses | 코스 최대 3개, rank 1이 1등. 코스끼리 장소 안 겹침 |
| notice | 결과가 없거나 조건을 바꿨을 때 안내 문구, 평소엔 null |

**헷갈릴 만한 필드**

| 필드 | 뜻 |
| --- | --- |
| places[].score | request·target·congestion = 사용자 요구·타깃 특성·혼잡도 적합도(0~1), total = 0.45·0.30·0.25 가중합 |
| congestion.percentile | 같은 지역·같은 요일 구분·같은 시각 안에서의 순위 (0 가장 한산, 100 가장 붐빔). 윤경 데이터의 pct_same_time |
| places[].reason | 카드에 보여줄 추천 이유 한 줄 (서버에서 생성) |
| stops[].slot | 코스에서 맡은 칸: MEAL / CAFE / PLAY |
| stops[].congestion | 해당 장소 도착 시각 기준 혼잡도 (검색 시각 아님) |
| stops[].walkMinutesFromPrev | 이전 장소에서 걷는 시간(분), 첫 장소는 null |
| courses[].score | placeAvg·moveEfficiency·timeFit = 평균 장소 점수·이동 효율·시간 적합도, total = 0.70·0.20·0.10 가중합 |
| courses[].title | 코스 카드 제목 (예: "성수 오후 노래방 코스"), 서버에서 생성 |
| courses[].reason | 코스 추천 이유 한 줄 (예: "'조용함' 후기 많은 곳 2곳 · 3곳 중 3곳이 도착 시간에 한산 · 총 도보 6분"), 서버에서 생성 |

**코스 안 장소 하나(stops[ ]) 예시** - 이름·좌표는 실제 수집 데이터, 혼잡도는 윤경 데이터, 점수는 가짜 값

```json
{
  "order": 2, "slot": "CAFE",
  "placeId": "780757764", "name": "브레빌 카페앤스토어 성수", "category": "CAFE",
  "lat": 37.5431717, "lng": 127.0538051,
  "arriveAt": "16:05", "leaveAt": "16:55", "stayMinutes": 50,
  "walkMinutesFromPrev": 5, "distanceMetersFromPrev": 244,
  "congestion": { "level": "QUIET", "percentile": 17 },
  "placeScore": 0.89
}
```

## 장소·코스 API

- 검색 때 만든 코스 3개는 서버에 저장하고 courseId 반환 → 로그인 없이도 수정·공유 가능, 로그인하면 내 코스로 연결

**장소 상세 GET /api/places/{placeId}?date=2026-10-17**

- `date`는 선택. 해당 날짜의 요일 구분으로 시간대별 혼잡도 반환, 없으면 오늘 기준
- 응답: 장소 기본 정보(placeId, name, category, region, address, roadAddress, phone, lat, lng, kakaoCategory, placeUrl) + `tags` + `congestionByHour`(9~23시, level·percentile, basis = ALL_DAY: 하루 전체 기준 비교라 몇 시가 붐비는지 확인 가능) + `openingHours`
- `openingHours`는 구글 Places 연동 전까지 null → 화면에는 "영업시간 정보 없음" 표시
- 가짜 JSON: `mocks/place_detail.json`

**코스 수정 PUT /api/courses/{courseId}**

- 추가·삭제·교체·순서 변경·체류시간 변경을 따로 보내지 않고, 수정 후 전체 목록을 한 번에 전송. 배열 순서 = 방문 순서

```json
{
  "startTime": "15:00",
  "stops": [
    { "placeId": "20745493",   "stayMinutes": 90 },
    { "placeId": "332674718",  "stayMinutes": 50 },
    { "placeId": "2091596191", "stayMinutes": 60 }
  ]
}
```

- `startTime`은 선택. 없으면 원래 코스 시작 시각 사용
- 응답: 다시 계산된 코스(검색 응답의 courses[ ]와 같은 형식, rank는 null) + `warnings`
- 경고가 있어도 저장은 됨. 앱에서 경고 문구 보여주고 사용자가 판단
- 가짜 JSON: `mocks/course_update_request.json` → `mocks/course_update_response.json` (1번 체류 90분 + 2번 카페 교체 → 총 212분, TOTAL_TIME_OVER·BUSY_AT_ARRIVAL 경고 2개)

| 경고 코드 | 언제 |
| --- | --- |
| TOTAL_TIME_OVER | 총 소요시간 210분 초과 |
| TOTAL_TIME_UNDER | 총 소요시간 150분 미만 |
| LONG_WALK | 한 구간 도보 15분 초과 |
| BUSY_AT_ARRIVAL | 조용한 곳을 원했는데 도착 시각에 혼잡 |
| OUTSIDE_HOURS | 영업시간 밖 (영업시간 데이터 들어오면 사용) |

**공유 만들기 POST /api/courses/{courseId}/share**

- 요청 본문 없음. 응답: `shareCode`, `shareUrl`, `shareText`(카톡에 바로 붙여넣기 가능한 글)
- 가짜 JSON: `mocks/share_create_response.json`

**공유 코스 보기 GET /api/share/{shareCode}**

- 응답: `shareCode`, `createdAt`, `conditions`(region, date, dayType, startTime, partySize), `course`
- 가짜 JSON: `mocks/share_view_response.json`

## 회원 API

- 성정헌이 만든 테이블 3개(users, user_preference, user_allergy) 기준
- 로그인하면 내 설정이 검색 조건에 자동 추가. 문장에 쓴 조건과 다르면 문장 우선, 알레르기는 항상 추가

| API | 요청 | 응답 data | 저장되는 곳 | 가짜 JSON |
| --- | --- | --- | --- | --- |
| POST /api/auth/signup | email, password(8자 이상), region | userId, email, region | users | auth_signup_request.json, auth_signup_response.json, auth_error_duplicate_email.json |
| POST /api/auth/login | email, password | accessToken, tokenType(Bearer), expiresIn(초), user | - | auth_login_request.json, auth_login_response.json |
| GET /api/users/me/preferences | 없음 | region, atmospheres, allergies | users.region, user_preference, user_allergy | preferences.json |
| PUT /api/users/me/preferences | GET 응답과 같은 형식 | 저장된 값 | 위와 같음 (목록은 지우고 다시 저장) | preferences.json |

- 비밀번호는 BCrypt로 암호화해서 password_hash에 저장. 현재 build.gradle에 암호화·JWT 라이브러리 없음 → 추가 필요 (spring-security-crypto, jjwt 등)
- region은 지역 코드(SEONGSU 등)로 저장
- atmospheres는 블로그 태그 사전의 태그 이름 그대로(조용함, 디저트, 사진·인테리어, 데이트, 단체석 등) user_preference.atmosphere에 한 줄씩 저장. 태그 목록은 최예린 확정
- allergies는 아래 코드 그대로 user_allergy.allergy_name에 저장

| 알레르기 코드 | 화면 표시 | v0.1 처리 |
| --- | --- | --- |
| SHELLFISH | 갑각류 | 해물·조개·게 음식점 제외 |
| SEAFOOD | 해산물·생선 | 해물·생선·회·초밥 음식점 제외 |
| PEANUT | 땅콩·견과류 | 블로그 메뉴 언급 시 경고만 |
| MILK | 우유·유제품 | 블로그 메뉴 언급 시 경고만 |
| EGG | 달걀 | 블로그 메뉴 언급 시 경고만 |
| WHEAT | 밀·글루텐 | 블로그 메뉴 언급 시 경고만 |

- 카카오에 메뉴 정보가 없어서 음식점 종류로 거를 수 있는 건 갑각류·해산물뿐 → 나머지는 블로그 메뉴 경고로 보완 (최예린)

## 코스 생성 규칙 v0.1

- 칸 3개(식사·카페·놀거리)를 시작 시각에 맞는 순서로 채우고, 총 3시간 ±30분 안에서 점수 가장 높은 조합 3개 선택
- 숫자는 전부 초기값, LG 데이터 받은 뒤 조정
- 구현: `capstone-backend/src/main/java/com/capstone/backend/course/` (`CourseGenerator`가 시작점, 숫자는 전부 `CourseRules`에)
  - 같은 장소·점수 넣었을 때 `mocks/` 가짜 JSON 코스(성수·홍대·강남 3개씩 + 코스 수정·경고)와 결과 똑같은 거 확인함
  - 규칙 바꾸면 `CourseRules` + 이 문서 + `mocks/generate_mocks.py` 같이 바꾸기
  - 테스트: `./gradlew test --tests "com.capstone.backend.course.*"` (DB 없이 돌아감)
  - 확인용 주소: 서버 켜고 `GET /api/dev/courses` → 가짜 점수로 코스 3개 JSON (기본값 = 성수 가짜 JSON이랑 같은 조건, 파라미터는 `DevCourseController` 주석 참고). /api/search 붙으면 지우기

1. **칸별 후보:** 지역·알레르기·술집 시간 필터 통과한 장소 중 칸마다 점수 상위 10곳 (점수는 그 칸의 대략적인 도착 시각 기준)
2. **조합:** 10 × 10 × 10 = 1,000개
3. **시간 계산:** 도착 = 이전 장소 출발 + 도보 시간, 출발 = 도착 + 체류 시간
4. **시간 걸러내기:** 총 소요시간 150~210분만 남기기
5. **점수:** 장소마다 실제 도착 시각 혼잡도로 다시 계산 후 코스 점수 산출
6. **상위 3개:** 점수 순으로, 앞에서 고른 코스와 장소 안 겹치는 것만 선택

| 시작 시각 | 기본 순서 | 이유 |
| --- | --- | --- |
| 11시 전 | 카페 → 놀거리 → 식사 | 브런치 후 점심 |
| 11~14시 | 식사 → 카페 → 놀거리 | 점심부터 |
| 14~17시 | 놀거리 → 카페 → 식사 | 저녁 식사로 마무리 |
| 17시 이후 | 식사 → 카페 → 놀거리 | 저녁 먼저, 노래방·방탈출은 늦게까지 |

- 문장에 순서가 있으면(예: "밥 먹고 카페") 그 순서 따름

| 카테고리 | 체류 시간 초기값(분) |
| --- | --- |
| FOOD 음식 | 60 |
| CAFE 카페 | 50 |
| CULTURE 문화 · ACTIVITY 액티비티 | 60 |
| EXPERIENCE 체험 (원데이클래스 등) | 90 |
| SHOPPING 쇼핑 · TOUR 관광 · NATURE 자연/휴식 | 40 |

**코스 제목·추천 이유**

- 제목: `{지역} {시간대} {놀거리 종류} 코스` (예: 성수 오후 노래방 코스). 시간대는 시작 시각 기준 오전(~11시)·점심(~14시)·오후(~17시)·저녁(~21시)·밤, 놀거리 종류는 카카오 카테고리에서 가져옴
- 추천 이유: 분위기 태그 맞는 곳 수 · 혼잡 선호에 맞는 곳 수(조용한 곳이면 한산, 활기찬 곳이면 북적) · 총 도보 시간을 ` · `로 연결

**칸 채우는 규칙**

- 식사 칸: FOOD 중 간식(베이커리·아이스크림·도넛)과 구내식당 제외. 술집은 도착이 18시 이후일 때만
- 카페 칸: CAFE
- 놀거리 칸: 문장에 놀거리 종류가 있으면 그 카테고리(예: 방탈출 → ACTIVITY), 없으면 나머지 6개 전부

**이동과 점수**

- 도보 시간 = 직선거리 × 1.3 ÷ 67m/분(시속 4km), 올림. 1.3은 길이 직선이 아닌 걸 보정한 값. 나중에 길찾기 API로 바꿀 수 있게 함수 하나로 분리
- 코스 점수 = 0.70 × 평균 장소 점수 + 0.20 × 이동 효율 + 0.10 × 시간 적합도
- 이동 효율 = 1 − 총 도보 시간 ÷ 40분 (0보다 작으면 0)
- 시간 적합도 = 1 − |총 소요시간 − 180| ÷ 30 (0보다 작으면 0)

| 혼잡도 적합도 (이윤경 확정 전 초안) | 도착 때 한산 | 보통 | 혼잡 |
| --- | --- | --- | --- |
| QUIET 조용한 곳 | 1.0 | 0.5 | 0.1 |
| DEFAULT 상관없음 | 0.8 | 1.0 | 0.5 |
| LIVELY 활기찬 곳 | 0.2 | 0.6 | 1.0 |

**가짜 데이터로 돌려본 결과**

- 새 장소 데이터(1,795곳) + 윤경 혼잡도 데이터로 시나리오 3개 실행
- 1,000개 조합 중 81~100%가 시간 기준 통과, 1등 코스는 총 174~180분·도보 4~10분
- 장소가 전부 중심 500m 안이라 도보 시간보다 체류 시간이 총 시간을 좌우함

## 가짜 응답 JSON과 장소 데이터 점검

- 가짜 JSON 15개는 저장소 `mocks/` 폴더에 있음
- 장소: 최예린 `output/places.csv`(중심 500m 안 1,795곳) / 혼잡도: 이윤경 `congestion_fake.csv`
- 셀 매칭 없는 9곳은 가장 가까운 셀로 대체
- 태그, 사용자 요구·타깃 점수는 블로그·성연령 데이터 전이라 아직 가짜 값
- 거리·도보 시간·도착 시각은 위 코스 규칙대로 실제 계산

| 파일 | 내용 | 쓰는 사람 |
| --- | --- | --- |
| search_seongsu_weekend_quiet.json | 성수 · 토 15시 · 2명 · 조용함 | 서예령 |
| search_hongdae_weekend_lively.json | 홍대 · 토 19시 · 커플 · 활기 | 서예령 |
| search_gangnam_weekday_group.json | 강남 · 금 19시 · 4명 · 갑각류 알레르기 | 서예령 |
| search_error_condition_missing.json | 지역 없는 문장 → CONDITION_MISSING | 서예령 |
| place_detail.json | 장소 상세 + 시간대별 혼잡도 | 서예령 |
| course_update_request.json, course_update_response.json | 코스 수정 → 다시 계산 + 경고 | 서예령, 김예민 |
| share_create_response.json, share_view_response.json | 공유 만들기·보기 | 서예령 |
| auth_signup_request.json, auth_signup_response.json, auth_error_duplicate_email.json | 회원가입 성공·중복 이메일 | 서예령, 성정헌 |
| auth_login_request.json, auth_login_response.json, preferences.json | 로그인·내 설정 | 서예령, 성정헌 |
| generate_mocks.py | 위 파일 다시 만드는 스크립트 (코스 규칙 v0.1 구현). 저장소 맨 위 폴더에서 `python mocks/generate_mocks.py` 실행 | 김예민 |

**places.csv 점검 (@최예린 확인 부탁)**

- 500m 필터 적용으로 범위 문제 해결 (가장 먼 장소 495~500m), place_id 중복 없음
- 분류 문제는 아직 남아 있어서 가짜 JSON에서는 아래처럼 정리해서 사용 (정리 후 1,773곳)

| 발견한 점 | 개수 | 제안 |
| --- | --- | --- |
| 카페인데 보드게임·만화카페 (카카오: 가정,생활 > 여가시설) | 32 | ACTIVITY로 옮기기 |
| 카페 > 테마카페 중 사주·고양이·애견·라이브카페 | 23 | ACTIVITY로 옮기기 (디저트·갤러리·북·무인카페는 카페 유지) |
| 세부 종류 없는 테마카페 (방탈출·수면카페 등 섞임) | 32 | 직접 훑어보고 옮기거나 빼기 (가짜 JSON에서는 ACTIVITY) |
| 서비스·교육·의료·교통 대분류 (공간대여 8, 미술학원 2, 주차장 2 등) | 21 | 빼기 |
| 키즈카페 | 1 | 빼기 |
| 음식 중 간식 (베이커리·아이스크림·도넛) | 59 | 식사 칸에서 제외 (카페 칸에 넣을지는 결정 필요) |
| 음식 중 술집 | 110 | 18시 이후에만 사용 |
| 도로명주소 없음 32, 전화번호 없음 558, 검색 키워드 없음 1,125 | - | 문제 없음. 빈 값은 null로 보내고, 키워드 없는 건 카테고리 검색으로 모은 것 |
