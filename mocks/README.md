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

- `assets/mocks/`로 복사해서 API 대신 읽어서 사용
- 실제 API도 같은 형식으로 오니까 나중에 읽는 부분만 바꾸면 됨
