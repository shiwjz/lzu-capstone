package com.capstone.backend.course;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 코스 생성 규칙 테스트 - 김예민
 * - DB·Spring 없이 돌아감 (가짜 장소 + 고정 점수)
 * - 실행: ./gradlew test --tests "com.capstone.backend.course.*"
 * - 규칙 숫자 바꾸면 여기 기대값도 같이 바꾸기
 */
class CourseGeneratorTest {

    // 성수 근처 기준 좌표, 장소끼리 30m 정도씩 떨어지게 배치
    private static final double BASE_LAT = 37.5445;
    private static final double BASE_LNG = 127.0560;

    private final CourseGenerator generator = new CourseGenerator();
    private final CourseCalculator calculator = new CourseCalculator();

    // ---------- 도보 시간 ----------

    @Test
    @DisplayName("도보: 240m → 5분, 10m → 1분(최소 1분)")
    void walkingMinutes() {
        assertEquals(5, WalkingTime.minutes(240));   // 240 × 1.3 ÷ 67 = 4.66 → 올림 5
        assertEquals(1, WalkingTime.minutes(10));
        assertEquals(1, WalkingTime.minutes(0));
    }

    @Test
    @DisplayName("거리: 위도 0.001도 ≈ 111m")
    void distance() {
        assertEquals(111, WalkingTime.distanceMeters(BASE_LAT, BASE_LNG, BASE_LAT + 0.001, BASE_LNG));
    }

    // ---------- 칸 순서 ----------

    @Test
    @DisplayName("시작 시각별 기본 순서")
    void slotOrderByStartTime() {
        assertEquals(List.of(Slot.CAFE, Slot.PLAY, Slot.MEAL), CourseRules.slotOrder(10 * 60));
        assertEquals(List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY), CourseRules.slotOrder(12 * 60));
        assertEquals(List.of(Slot.PLAY, Slot.CAFE, Slot.MEAL), CourseRules.slotOrder(15 * 60));
        assertEquals(List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY), CourseRules.slotOrder(19 * 60));
    }

    @Test
    @DisplayName("문장에 순서 있으면 그 순서가 우선")
    void requestOrderWins() {
        Fixture f = new Fixture();
        f.basicSet();
        CourseRequest req = request(15 * 60, Set.of(), List.of(), List.of(Slot.CAFE, Slot.MEAL, Slot.PLAY));

        List<CoursePlan> courses = generator.generate(req, f.places, f.scorer(CongestionLevel.QUIET));

        assertFalse(courses.isEmpty());
        for (CoursePlan c : courses) {
            assertEquals(List.of(Slot.CAFE, Slot.MEAL, Slot.PLAY), c.stops().stream().map(CoursePlan.Stop::slot).toList());
        }
    }

    // ---------- 코스 생성 기본 ----------

    @Test
    @DisplayName("코스 여러 개(최대 10개), 장소 안 겹침, 150~210분, 점수 순")
    void generatesThreeNonOverlappingCourses() {
        Fixture f = new Fixture();
        f.basicSet();
        f.add("HD1", "HONGDAE", "FOOD", "음식점 > 한식", 0.99);   // 다른 지역은 안 나와야 함

        List<CoursePlan> courses = generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET));

        assertTrue(courses.size() >= 3 && courses.size() <= CourseRules.COURSE_COUNT, "코스 " + courses.size() + "개");
        Set<String> used = new HashSet<>();
        double prevScore = Double.MAX_VALUE;
        for (int i = 0; i < courses.size(); i++) {
            CoursePlan c = courses.get(i);
            assertEquals(i + 1, c.rank().intValue());
            assertEquals(3, c.stops().size());
            assertTrue(c.totalMinutes() >= 150 && c.totalMinutes() <= 210, "총 " + c.totalMinutes() + "분");
            assertTrue(c.score().total() <= prevScore, "점수 순서");
            prevScore = c.score().total();
            for (CoursePlan.Stop s : c.stops()) {
                assertTrue(used.add(s.placeId()), "장소 겹침: " + s.placeId());
                assertFalse(s.placeId().startsWith("HD"), "다른 지역 장소");
            }
            assertEquals("15:00", c.startAt());
        }
    }

    @Test
    @DisplayName("1등 코스는 점수 제일 높은 장소들로")
    void bestCourseUsesTopPlaces() {
        Fixture f = new Fixture();
        f.basicSet();

        CoursePlan best = generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET)).get(0);

        // 15시 시작 → 놀거리 → 카페 → 식사, 각 칸 점수 1등 (P1, C1, F1)
        assertEquals(List.of("P1", "C1", "F1"), best.stops().stream().map(CoursePlan.Stop::placeId).toList());
    }

    @Test
    @DisplayName("칸에 넣을 장소가 없으면 빈 목록")
    void emptyWhenSlotHasNoPlace() {
        Fixture f = new Fixture();
        for (int i = 1; i <= 4; i++) {
            f.add("F" + i, "SEONGSU", "FOOD", "음식점 > 한식", 0.9);
            f.add("P" + i, "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 노래방", 0.9);
        }   // 카페 없음

        assertTrue(generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET)).isEmpty());
    }

    @Test
    @DisplayName("놀거리 종류 지정하면 그 카테고리만")
    void playCategoryFilter() {
        Fixture f = new Fixture();
        f.basicSet();
        for (int i = 1; i <= 4; i++) {
            f.add("X" + i, "SEONGSU", "CULTURE", "문화,예술 > 문화시설 > 전시관", 0.5);
        }

        List<CoursePlan> courses = generator.generate(
                request(15 * 60, Set.of(), List.of("CULTURE"), List.of()), f.places, f.scorer(CongestionLevel.QUIET));

        assertFalse(courses.isEmpty());
        for (CoursePlan c : courses) {
            CoursePlan.Stop play = c.stops().stream().filter(s -> s.slot() == Slot.PLAY).findFirst().orElseThrow();
            assertEquals("CULTURE", play.category());
        }
    }

    // ---------- 제외 규칙 ----------

    @Test
    @DisplayName("술집은 18시 이후 도착일 때만")
    void barOnlyAfterSix() {
        CoursePlace bar = place("B1", "SEONGSU", "FOOD", "음식점 > 술집 > 호프,요리주점", 0);
        assertFalse(CourseRules.allowed(bar, "SEONGSU", 17, Set.of()));
        assertTrue(CourseRules.allowed(bar, "SEONGSU", 18, Set.of()));

        Fixture f = new Fixture();
        f.basicSet();
        f.add("B1", "SEONGSU", "FOOD", "음식점 > 술집 > 호프,요리주점", 0.99);
        f.add("A1", "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 방탈출카페", 0.5);   // 밤 놀거리 (전시관은 19시에 닫음)

        // 15시 시작 → 식사 칸 17시대 도착 → 술집 빠짐
        assertFalse(usedIds(generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET))).contains("B1"));
        // 19시 시작 → 식사 먼저 19시 도착 → 술집 가능 (점수 제일 높으니 1등 코스에)
        List<CoursePlan> night = generator.generate(request(19 * 60), f.places, f.scorer(CongestionLevel.QUIET));
        assertEquals("B1", night.get(0).stops().get(0).placeId());
    }

    // ---------- 11주차: 코스 틀·영업시간·경로 이름 ----------

    @Test
    @DisplayName("코스 틀: 술(저녁 식사→술집→술집, 4시 놀거리→식사→술집), 문화(놀거리→카페→식사), 밤 8시 이후")
    void courseTemplates() {
        assertEquals(List.of(Slot.MEAL, Slot.BAR, Slot.BAR), CourseRules.slotOrder(19 * 60, true, List.of()));
        assertEquals(List.of(Slot.PLAY, Slot.MEAL, Slot.BAR), CourseRules.slotOrder(16 * 60, true, List.of()));
        assertEquals(List.of(Slot.PLAY, Slot.CAFE, Slot.MEAL), CourseRules.slotOrder(12 * 60, null, List.of("CULTURE")));
        assertEquals(List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY), CourseRules.slotOrder(12 * 60, null, List.of("CULTURE", "ACTIVITY")));
        assertEquals(List.of(Slot.MEAL, Slot.PLAY, Slot.BAR), CourseRules.slotOrder(20 * 60, null, List.of()));
        assertEquals(List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY), CourseRules.slotOrder(20 * 60, false, List.of()));
        assertEquals(List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY), CourseRules.slotOrder(19 * 60, null, List.of()));
    }

    @Test
    @DisplayName("기본 영업시간: 카페 22시 닫음, 술집 새벽 2시까지, 전시 19시 닫음, 영화관은 늦게까지")
    void defaultOpeningHours() {
        assertTrue(CourseRules.openAt(place("C", "SEONGSU", "CAFE", "음식점 > 카페", 0), 21));
        assertFalse(CourseRules.openAt(place("C", "SEONGSU", "CAFE", "음식점 > 카페", 0), 22));
        CoursePlace bar = place("B", "SEONGSU", "FOOD", "음식점 > 술집 > 칵테일바", 0);
        assertTrue(CourseRules.openAt(bar, 25));    // 새벽 1시
        assertFalse(CourseRules.openAt(bar, 26));
        assertFalse(CourseRules.openAt(bar, 16));
        assertFalse(CourseRules.openAt(place("P", "SEONGSU", "CULTURE", "문화,예술 > 문화시설 > 전시관", 0), 19));
        assertTrue(CourseRules.openAt(place("M", "SEONGSU", "CULTURE", "문화,예술 > 영화,영상 > 영화관", 0), 21));
        assertTrue(CourseRules.openAt(place("N", "SEONGSU", "NATURE", "여행 > 공원", 0), 23));
    }

    @Test
    @DisplayName("술 코스: 식사(술집 아님) → 술집 → 다른 술집, 경로 이름에 술집 종류")
    void drinkCourse() {
        Fixture f = new Fixture();
        f.basicSet();
        f.add("B1", "SEONGSU", "FOOD", "음식점 > 술집 > 칵테일바", 0.9);
        f.add("B2", "SEONGSU", "FOOD", "음식점 > 술집 > 일본식주점", 0.85);
        f.add("B3", "SEONGSU", "FOOD", "음식점 > 술집 > 와인바", 0.8);
        CourseRequest req = new CourseRequest("SEONGSU", 19 * 60, 2, List.of(), CrowdPreference.DEFAULT,
                Set.of(), List.of(), List.of(), true);
        List<CoursePlan> plans = generator.generate(req, f.places, f.scorer(CongestionLevel.NORMAL));
        assertFalse(plans.isEmpty());
        for (CoursePlan c : plans) {
            assertEquals(List.of(Slot.MEAL, Slot.BAR, Slot.BAR), c.stops().stream().map(CoursePlan.Stop::slot).toList());
            assertTrue(c.stops().get(0).placeId().startsWith("F"));
            assertFalse(c.stops().get(1).placeId().equals(c.stops().get(2).placeId()));
        }
        assertEquals("한식 → 칵테일바 → 이자카야", plans.get(0).route());
    }

    @Test
    @DisplayName("경로 이름: 식당은 세부 > 큰 종류, 카페, 테마카페·놀거리는 종류")
    void routeLabels() {
        assertEquals("초밥·롤", CourseText.stopLabel(new CoursePlace("1", "a", "SEONGSU", "FOOD", "음식점 > 일식 > 초밥,롤",
                0, 0, List.of(), "JAPANESE", "초밥·롤")));
        assertEquals("일식", CourseText.stopLabel(new CoursePlace("1", "a", "SEONGSU", "FOOD", "음식점 > 일식",
                0, 0, List.of(), "JAPANESE", null)));
        assertEquals("호프", CourseText.stopLabel(place("2", "SEONGSU", "FOOD", "음식점 > 술집 > 호프,요리주점", 0)));
        assertEquals("술집", CourseText.stopLabel(place("2", "SEONGSU", "FOOD", "음식점 > 술집", 0)));
        assertEquals("카페", CourseText.stopLabel(place("3", "SEONGSU", "CAFE", "음식점 > 카페", 0)));
        assertEquals("보드게임", CourseText.stopLabel(place("4", "SEONGSU", "ACTIVITY", "음식점 > 카페 > 테마카페 > 보드카페", 0)));
        assertEquals("방탈출", CourseText.stopLabel(place("5", "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 방탈출카페", 0)));
    }

    @Test
    @DisplayName("음식 취향 술집: 식사 거르기엔 안 씀 (술집만 → 식사는 아무 데나, 일식+술집 → 식사는 일식)")
    void barCuisineFilter() {
        CoursePlace korean = new CoursePlace("1", "a", "SEONGSU", "FOOD", "음식점 > 한식", 0, 0, List.of(), "KOREAN", null);
        CoursePlace japanese = new CoursePlace("2", "b", "SEONGSU", "FOOD", "음식점 > 일식", 0, 0, List.of(), "JAPANESE", null);
        CoursePlace bar = new CoursePlace("3", "c", "SEONGSU", "FOOD", "음식점 > 술집", 0, 0, List.of(), "BAR", null);
        assertTrue(Cuisine.wanted(korean, List.of("BAR")));
        assertTrue(Cuisine.wanted(bar, List.of("BAR")));
        assertFalse(Cuisine.wanted(korean, List.of("JAPANESE", "BAR")));
        assertTrue(Cuisine.wanted(japanese, List.of("JAPANESE", "BAR")));
        assertFalse(Cuisine.wanted(bar, List.of("JAPANESE")));
    }

    @Test
    @DisplayName("코스 수정: 기본 영업시간 밖 도착이면 MAYBE_CLOSED 경고")
    void maybeClosedWarning() {
        CoursePlace cafe = place("C9", "SEONGSU", "CAFE", "음식점 > 카페", 0);
        CourseRequest req = request(22 * 60);
        CoursePlan plan = generator.recalculate(req, List.of(new StopInput(cafe, 50)), fixedScorer(0.5, CongestionLevel.QUIET),
                Map.of("C9", cafe));
        assertTrue(generator.warnings(plan, CrowdPreference.QUIET, Map.of("C9", cafe)).stream()
                .anyMatch(w -> w.code().equals("MAYBE_CLOSED")));
    }

    @Test
    @DisplayName("간식(베이커리 등)·구내식당은 식사 칸에서 빠짐")
    void snackAndCafeteriaNotMeal() {
        Fixture f = new Fixture();
        f.basicSet();
        f.add("S1", "SEONGSU", "FOOD", "음식점 > 간식 > 제과,베이커리", 0.99);
        f.add("S2", "SEONGSU", "FOOD", "음식점 > 구내식당", 0.99);

        Set<String> used = usedIds(generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET)));
        assertFalse(used.contains("S1"));
        assertFalse(used.contains("S2"));
    }

    @Test
    @DisplayName("갑각류 알레르기 → 해물·조개 식당 빠짐")
    void shellfishExcluded() {
        CoursePlace clam = place("A1", "SEONGSU", "FOOD", "음식점 > 한식 > 해물,생선 > 조개", 0);
        assertFalse(CourseRules.allowed(clam, "SEONGSU", 19, Set.of("SHELLFISH")));
        assertTrue(CourseRules.allowed(clam, "SEONGSU", 19, Set.of()));

        Fixture f = new Fixture();
        f.basicSet();
        f.add("A1", "SEONGSU", "FOOD", "음식점 > 한식 > 해물,생선 > 조개", 0.99);

        Set<String> used = usedIds(generator.generate(
                request(19 * 60, Set.of("SHELLFISH"), List.of(), List.of()), f.places, f.scorer(CongestionLevel.QUIET)));
        assertFalse(used.contains("A1"));
    }

    @Test
    @DisplayName("조용한 곳 원하면 노래방·오락실은 놀거리 칸에서 빠짐, 활기찬 곳이면 나옴")
    void quietExcludesNoisyPlay() {
        Fixture f = new Fixture();
        f.basicSet();
        f.add("K1", "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 노래방", 0.99);
        f.add("K2", "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 오락실", 0.99);

        Set<String> quiet = usedIds(generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET)));
        assertFalse(quiet.contains("K1"));
        assertFalse(quiet.contains("K2"));

        CourseRequest lively = new CourseRequest("SEONGSU", 15 * 60, 2, List.of("데이트"), CrowdPreference.LIVELY,
                Set.of(), List.of(), List.of());
        Set<String> busy = usedIds(generator.generate(lively, f.places, f.scorer(CongestionLevel.BUSY)));
        assertTrue(busy.contains("K1") || busy.contains("K2"), busy.toString());
    }

    // ---------- 시간 계산·경고 (코스 수정 API) ----------

    @Test
    @DisplayName("도착 = 이전 출발 + 도보, 출발 = 도착 + 체류")
    void calculatorTimes() {
        CoursePlace a = place("A", "SEONGSU", "ACTIVITY", "가정,생활 > 여가시설 > 노래방", 0);
        CoursePlace b = place("B", "SEONGSU", "CAFE", "음식점 > 카페", 0.001);   // 111m → 3분

        CoursePlan plan = calculator.calculate(
                List.of(new StopInput(a, 60), new StopInput(b, 50)), 15 * 60, fixedScorer(0.876, CongestionLevel.QUIET));

        CoursePlan.Stop second = plan.stops().get(1);
        assertEquals(111, second.distanceMetersFromPrev().intValue());
        assertEquals(3, second.walkMinutesFromPrev().intValue());
        assertEquals("16:03", second.arriveAt());
        assertEquals("16:53", second.leaveAt());
        assertEquals(113, plan.totalMinutes());
        assertEquals(0.88, second.placeScore());   // 소수 둘째 자리
        assertNull(plan.stops().get(0).walkMinutesFromPrev());   // 첫 장소는 도보 없음
    }

    @Test
    @DisplayName("자정 넘어가면 00:xx로 표시")
    void wrapsAfterMidnight() {
        CoursePlace a = place("A", "SEONGSU", "FOOD", "음식점 > 한식", 0);
        CoursePlace b = place("B", "SEONGSU", "CAFE", "음식점 > 카페", 0.001);

        CoursePlan plan = calculator.calculate(
                List.of(new StopInput(a, 60), new StopInput(b, 50)), 23 * 60, fixedScorer(0.8, CongestionLevel.QUIET));

        assertEquals("00:03", plan.stops().get(1).arriveAt());
    }

    @Test
    @DisplayName("경고: 3시간 30분 초과, 도보 15분 초과, 조용한 곳 원했는데 붐빔")
    void warnings() {
        CoursePlace a = place("A", "SEONGSU", "EXPERIENCE", "가정,생활 > 여가시설 > 공방", 0);
        CoursePlace far = place("B", "SEONGSU", "FOOD", "음식점 > 한식", 0.015);   // 약 1.7km → 33분
        CoursePlace c = place("C", "SEONGSU", "CAFE", "음식점 > 카페", 0.0151);

        CoursePlan plan = calculator.calculate(
                List.of(new StopInput(a, 120), new StopInput(far, 60), new StopInput(c, 50)),
                15 * 60, fixedScorer(0.8, CongestionLevel.BUSY));

        List<String> codes = calculator.warnings(plan, CrowdPreference.QUIET).stream().map(CourseWarning::code).toList();
        assertTrue(codes.contains("TOTAL_TIME_OVER"), codes.toString());
        assertTrue(codes.contains("LONG_WALK"), codes.toString());
        assertTrue(codes.contains("BUSY_AT_ARRIVAL"), codes.toString());
        assertFalse(CourseCalculator.withinTimeWindow(plan));

        // 혼잡 상관없음이면 붐빔 경고 없음
        List<String> defaultCodes = calculator.warnings(plan, CrowdPreference.DEFAULT).stream().map(CourseWarning::code).toList();
        assertFalse(defaultCodes.contains("BUSY_AT_ARRIVAL"));
    }

    @Test
    @DisplayName("경고: 2시간 30분보다 짧음")
    void warningTooShort() {
        CoursePlace a = place("A", "SEONGSU", "SHOPPING", "가정,생활 > 소품샵", 0);
        CoursePlan plan = calculator.calculate(List.of(new StopInput(a, 40)), 15 * 60, fixedScorer(0.8, CongestionLevel.QUIET));

        assertEquals(List.of("TOTAL_TIME_UNDER"), calculator.warnings(plan, CrowdPreference.DEFAULT).stream().map(CourseWarning::code).toList());
    }

    // ---------- 제목·추천 이유 ----------

    @Test
    @DisplayName("제목: 시간대 단어, 놀거리 이름")
    void titleWords() {
        assertEquals("오전", CourseText.timeWord(10 * 60));
        assertEquals("점심", CourseText.timeWord(12 * 60));
        assertEquals("오후", CourseText.timeWord(15 * 60));
        assertEquals("저녁", CourseText.timeWord(19 * 60));
        assertEquals("밤", CourseText.timeWord(22 * 60));

        assertEquals("노래방", CourseText.playLabel("가정,생활 > 여가시설 > 노래방"));
        assertEquals("보드게임", CourseText.playLabel("음식점 > 카페 > 테마카페 > 보드카페"));
        assertEquals("공연장·연극극장", CourseText.playLabel("문화,예술 > 문화시설 > 공연장,연극극장"));
    }

    @Test
    @DisplayName("제목·추천 이유 붙어서 나옴")
    void titleAndReason() {
        Fixture f = new Fixture();
        f.basicSet();

        CoursePlan best = generator.generate(request(15 * 60), f.places, f.scorer(CongestionLevel.QUIET)).get(0);

        assertEquals("성수 오후 전시 코스", best.title());
        // 기본 장소 태그 = 조용함 → 3곳 다 맞음, 혼잡도 전부 한산
        assertTrue(best.reason().startsWith("'조용함' 후기 많은 곳 3곳 · 3곳 중 3곳이 도착 시간에 한산 · 총 도보 "), best.reason());
    }

    // ---------- 테스트용 ----------

    private static CourseRequest request(int startMinute) {
        return request(startMinute, Set.of(), List.of(), List.of());
    }

    private static CourseRequest request(int startMinute, Set<String> allergies, List<String> playCategories, List<Slot> order) {
        return new CourseRequest("SEONGSU", startMinute, 2, List.of("조용함"), CrowdPreference.QUIET,
                allergies, playCategories, order);
    }

    private static CoursePlace place(String id, String region, String category, String kakao, double latOffset) {
        return new CoursePlace(id, id + " 이름", region, category, kakao,
                BASE_LAT + latOffset, BASE_LNG, List.of("조용함"));
    }

    private static PlaceScorer fixedScorer(double total, CongestionLevel level) {
        return (p, hour) -> new PlaceScore(total, total, total, 1.0, level, 20);
    }

    private static Set<String> usedIds(List<CoursePlan> courses) {
        Set<String> ids = new HashSet<>();
        courses.forEach(c -> c.stops().forEach(s -> ids.add(s.placeId())));
        return ids;
    }

    /** 가짜 장소 목록 + 장소별 고정 점수 */
    private static class Fixture {
        final List<CoursePlace> places = new ArrayList<>();
        final Map<String, Double> scores = new HashMap<>();

        void add(String id, String region, String category, String kakao, double score) {
            places.add(place(id, region, category, kakao, places.size() * 0.0003));
            scores.put(id, score);
        }

        /** 칸마다 4곳 (식사 F, 카페 C, 놀거리 P), 숫자 작을수록 점수 높음 */
        void basicSet() {
            for (int i = 1; i <= 4; i++) {
                double s = 0.95 - i * 0.05;
                add("F" + i, "SEONGSU", "FOOD", "음식점 > 한식", s);
                add("C" + i, "SEONGSU", "CAFE", "음식점 > 카페", s);
                add("P" + i, "SEONGSU", "CULTURE", "문화,예술 > 문화시설 > 전시관", s);
            }
        }

        PlaceScorer scorer(CongestionLevel level) {
            return (p, hour) -> {
                double s = scores.get(p.placeId());
                return new PlaceScore(s, s, s, 1.0, level, 20);
            };
        }
    }
}
