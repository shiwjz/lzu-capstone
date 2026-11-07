package com.capstone.backend.search;

import com.capstone.backend.course.CoursePlan;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CourseWarning;
import com.capstone.backend.course.Slot;
import com.capstone.backend.place.PlaceStore;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

/**
 * 검색·코스 수정·공유 테스트 (DB·Spring 없이) - 김예민
 * - 장소·혼잡도: resources/data (예린 장소 3,306곳·태그 + 윤경 혼잡도·성연령), 점수는 윤경 장소 점수 모듈
 * - 기대값 = mocks/search_seongsu_weekend_quiet.json 1등 코스 (파이썬 가짜 JSON이랑 서버 결과 같은지)
 * - 실행: ./gradlew test --tests "com.capstone.backend.search.*"
 */
class SearchServiceTest {

    private static final PlaceStore STORE = new PlaceStore();

    private SearchService service() {
        SearchService s = new SearchService(STORE, new RuleConditionExtractor(), new PlaceScoreModel(STORE),
                new CourseStore());
        s.clock = Clock.fixed(Instant.parse("2026-10-16T11:00:00Z"), SearchService.KST);   // 10/16(금) 20시
        return s;
    }

    private static SearchService.SearchRequest query(String q) {
        return new SearchService.SearchRequest(q, null, null, null, null);
    }

    private static SearchConditions seongsuQuiet() {
        return new SearchConditions("SEONGSU", "2026-10-17", null, "15:00", 2, List.of("CAFE", "FOOD"),
                List.of("조용한"), "QUIET", List.of(), null, null, "FRIEND", List.of(), "GEMINI");
    }

    @SuppressWarnings("unchecked")
    private static List<CoursePlan> courses(Map<String, Object> data) {
        return (List<CoursePlan>) data.get("courses");
    }

    private static ApiException expectError(Runnable r) {
        try {
            r.run();
        } catch (ApiException e) {
            return e;
        }
        fail("ApiException이 나야 함");
        return null;
    }

    @Test
    @DisplayName("11주차: 경로 이름 + 덜 붐비는 출발 시간 (가짜 JSON 성수랑 같음)")
    void routeAndBetterStart() {
        Map<String, Object> data = service().search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()));
        assertEquals("전시관 → 카페 → 분식", courses(data).get(0).route());
        @SuppressWarnings("unchecked")
        Map<String, Object> better = (Map<String, Object>) data.get("betterStart");
        assertEquals("17:00", better.get("startTime"));
        assertEquals(120, better.get("shiftMinutes"));
        assertEquals("2시간 늦게 출발하면 덜 붐벼요 (혼잡 38% → 29%)", better.get("message"));
    }

    @Test
    @DisplayName("11주차: 술 코스 - 저녁 '술 한잔' → 식사 → 술집 → 술집, 낮이면 안내 문구")
    void drinkSearch() {
        Map<String, Object> data = service().search(query("토요일 저녁 7시 성수에서 친구랑 밥 먹고 술 한잔"));
        List<CoursePlan> cs = courses(data);
        assertFalse(cs.isEmpty());
        for (CoursePlan c : cs) {
            assertEquals(List.of(Slot.MEAL, Slot.BAR, Slot.BAR), c.stops().stream().map(CoursePlan.Stop::slot).toList());
        }
        Map<String, Object> day = service().search(query("토요일 낮 1시 성수에서 술 한잔"));
        assertTrue(courses(day).isEmpty());
        assertEquals("술집은 저녁 6시 이후로 넣어요. 시작 시간을 오후 3시 이후로 바꿔 보세요.", day.get("notice"));
    }

    // ---------- v0.7 (11주차): 코스 틀·빼기·추가·킵·감성 제목 ----------

    private static SearchService.SearchRequest req(String q, String courseType, List<String> order, List<String> keeps) {
        return new SearchService.SearchRequest(q, null, null, null, null, courseType, order, keeps);
    }

    private static List<Slot> slots(CoursePlan c) {
        return c.stops().stream().map(CoursePlan.Stop::slot).toList();
    }

    @Test
    @DisplayName("문장에서 빼기·추가: 카페 말고 / 노래방도 / 밥은 먹고 왔어 / 보드게임카페는 빼고")
    void shapeEditsFromSentence() {
        assertEquals(List.of(List.of("CAFE"), List.of("ACTIVITY")), RuleConditionExtractor.shapeEdits("성수에서 카페 말고 노래방도 가고 싶어"));
        assertEquals(List.of(List.of("FOOD"), List.of()), RuleConditionExtractor.shapeEdits("밥은 먹고 왔어 홍대 놀자"));
        assertEquals(List.of(List.of("ACTIVITY"), List.of()), RuleConditionExtractor.shapeEdits("보드게임카페는 빼고"));
        assertEquals(List.of(List.of("BAR"), List.of("CAFE")), RuleConditionExtractor.shapeEdits("술은 빼고 카페도 넣어줘"));
        assertEquals(List.of(List.of(), List.of()), RuleConditionExtractor.shapeEdits("토요일 성수 데이트"));
    }

    @Test
    @DisplayName("'카페 말고' 검색: 카페 칸 없이 놀거리 2개(서로 다른 종류), 조건에 excludedCategories")
    void excludeCafeSearch() {
        Map<String, Object> data = service().search(query("토요일 오후 3시 성수에서 카페 말고 놀자"));
        Map<?, ?> cond = (Map<?, ?>) data.get("conditions");
        assertEquals(List.of("CAFE"), cond.get("excludedCategories"));
        assertFalse(((List<?>) cond.get("categories")).contains("CAFE"));
        List<CoursePlan> cs = courses(data);
        assertFalse(cs.isEmpty());
        for (CoursePlan c : cs) {
            assertEquals(List.of(Slot.PLAY, Slot.PLAY, Slot.MEAL), slots(c));
            String[] r = c.route().split(" → ");
            assertFalse(r[0].equals(r[1]), c.route());
        }
    }

    @Test
    @DisplayName("코스 틀 칩 '술' (저녁 7시): 식사→술집 / 식사→술집→술집 섞여서, 전부 술집으로 끝남")
    void drinkTypeChip() {
        List<CoursePlan> cs = courses(service().search(req("토요일 저녁 7시 홍대", "DRINK", null, null)));
        assertFalse(cs.isEmpty());
        assertTrue(cs.stream().allMatch(c -> slots(c).get(slots(c).size() - 1) == Slot.BAR));
        assertTrue(cs.stream().allMatch(c -> List.of(List.of(Slot.MEAL, Slot.BAR), List.of(Slot.MEAL, Slot.BAR, Slot.BAR))
                .contains(slots(c))));
        assertEquals("DRINK", ((Map<?, ?>) service().search(req("토요일 저녁 7시 홍대", "DRINK", null, null)).get("conditions")).get("courseType"));
        assertEquals("INVALID_INPUT", expectError(() -> service().search(req("홍대", "PARTY", null, null))).code());
    }

    @Test
    @DisplayName("직접 고친 순서 order: 그 순서로만, 잘못된 값·5칸은 INVALID_INPUT")
    void customOrder() {
        List<CoursePlan> cs = courses(service().search(req("토요일 저녁 7시 홍대", null, List.of("MEAL", "PLAY", "BAR"), null)));
        assertFalse(cs.isEmpty());
        cs.forEach(c -> assertEquals(List.of(Slot.MEAL, Slot.PLAY, Slot.BAR), slots(c)));
        assertEquals("INVALID_INPUT", expectError(() -> service().search(req("홍대", null, List.of("MEAL", "SLEEP"), null))).code());
        assertEquals("INVALID_INPUT", expectError(() -> service().search(req("홍대", null,
                List.of("MEAL", "CAFE", "PLAY", "BAR", "BAR"), null))).code());
    }

    @Test
    @DisplayName("장소 킵: 킵한 곳은 모든 코스에, 코스는 여러 개 그대로, 다른 지역·3곳은 INVALID_INPUT")
    void keepPlaces() {
        SearchService svc = service();
        CoursePlan first = courses(svc.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()))).get(1);
        String keep = first.stops().get(0).placeId();
        Map<String, Object> data = svc.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet(),
                null, null, List.of(keep)));
        List<CoursePlan> cs = courses(data);
        assertTrue(cs.size() > 1);
        cs.forEach(c -> assertTrue(c.stops().stream().anyMatch(s -> s.placeId().equals(keep))));
        assertEquals(List.of(keep), data.get("keepPlaceIds"));
        String hongdae = STORE.coursePlaces().stream().filter(p -> p.region().equals("HONGDAE")).findFirst().orElseThrow().placeId();
        assertEquals("INVALID_INPUT", expectError(() -> svc.search(new SearchService.SearchRequest("성수", null, null, null,
                seongsuQuiet(), null, null, List.of(hongdae)))).code());
        assertEquals("INVALID_INPUT", expectError(() -> svc.search(new SearchService.SearchRequest("성수", null, null, null,
                seongsuQuiet(), null, null, List.of("1", "2", "3")))).code());
    }

    @Test
    @DisplayName("감성 제목: 받은 제목으로 바꿈, 이상한 자리는 규칙 제목, 실패하면 전부 규칙 / 코스 수정해도 감성 제목 유지")
    void sentimentTitles() {
        CourseTitleWriter fake = inputs -> {
            List<String> out = new java.util.ArrayList<>();
            for (int i = 0; i < inputs.size(); i++) out.add(i == 1 ? null : "감성 " + (i + 1) + " " + inputs.get(i).when());
            return out;
        };
        SearchService svc = new SearchService(STORE, new RuleConditionExtractor(), new PlaceScoreModel(STORE),
                new CourseStore(), fake);
        Map<String, Object> data = svc.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()));
        List<CoursePlan> cs = courses(data);
        assertEquals("감성 1 토요일 오후 3시", cs.get(0).title());
        assertEquals(courses(service().search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()))).get(1).title(),
                cs.get(1).title());
        assertEquals("GEMINI", data.get("titlesBy"));
        List<SearchService.StopEdit> edit = cs.get(0).stops().stream().map(s -> new SearchService.StopEdit(s.placeId(), null)).toList();
        assertEquals("감성 1 토요일 오후 3시", svc.updateCourse(cs.get(0).courseId(), new SearchService.UpdateRequest(null, edit)).get("title"));

        SearchService broken = new SearchService(STORE, new RuleConditionExtractor(), new PlaceScoreModel(STORE),
                new CourseStore(), inputs -> { throw new IllegalStateException("timeout"); });
        assertEquals("RULE", broken.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet())).get("titlesBy"));
    }

    @Test
    @DisplayName("Gemini 제목 정리: 개수 다르면 전부 버림, 너무 긴 것·빈 것만 null, 따옴표 떼기")
    void titleCleaning() {
        assertNull(GeminiCourseTitleWriter.clean(List.of("하나"), 2));
        assertEquals(java.util.Arrays.asList("성수 산책", null, null),
                GeminiCourseTitleWriter.clean(List.of("\"성수 산책\"", "", "가".repeat(30)), 3));
        String text = GeminiCourseTitleWriter.userText(List.of(new CourseTitleWriter.Input("성수", "토요일 오후 3시",
                List.of("조용한"), "전시관 → 카페 → 분식", List.of("한산"))));
        assertEquals("1. 지역: 성수 / 언제: 토요일 오후 3시 / 분위기: 조용한 / 경로: 전시관 → 카페 → 분식 / 키워드: 한산\n", text);
    }

    @Test
    @DisplayName("데이터: 장소 3,306곳, 혼잡도 자정 넘어도 조회")
    void store() {
        assertEquals(3306, STORE.all().size());
        assertTrue(STORE.list("SEONGSU", "CAFE").stream().allMatch(p -> p.category().equals("CAFE")));
        assertEquals(1, STORE.congestion("20745493", "WEEKEND", 25, PlaceStore.Basis.SAME_TIME).hour());
    }

    @Test
    @DisplayName("조건 직접 전달 → 가짜 JSON 성수 1등 코스랑 같음")
    void sameAsMock() {
        Map<String, Object> data = service().search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()));
        CoursePlan best = courses(data).get(0);
        assertEquals(List.of("1292703398", "921699059", "1327766448"),
                best.stops().stream().map(CoursePlan.Stop::placeId).toList());
        assertEquals("성수 오후 전시관 코스", best.title());
        assertEquals(173, best.totalMinutes());
        assertEquals(0.86, best.score().total());
        assertEquals(7, courses(data).size());                       // v0.5 최대 10개, 가짜 JSON도 7개 (11/5 예린 태그·음식 확정본 후)
        assertEquals(List.of("조용한", "한산", "분식", "도보 5분 이내"), best.keywords());
        assertTrue(((List<?>) data.get("places")).size() <= 10);
    }

    @Test
    @DisplayName("상황 태그 자동 (예린 태그 v3): 1명·혼자 → 혼자, 연인 → 데이트, 4명·회사 → 단체, 가족 → 아이")
    void partyMoods() {
        assertEquals(List.of("혼자"), ((Map<?, ?>) service().search(query("토요일 점심 홍대에서 혼자 밥 먹을 곳")).get("conditions")).get("atmospheres"));
        assertEquals(List.of("조용한"), ((Map<?, ?>) service().search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet())).get("conditions")).get("atmospheres"));
        assertEquals(List.of("단체"), ((Map<?, ?>) service().search(query("토요일 저녁 강남 4명 밥집")).get("conditions")).get("atmospheres"));
        assertEquals(List.of(), ((Map<?, ?>) service().search(query("토요일 저녁 강남 밥집")).get("conditions")).get("atmospheres"));
        SearchConditions two = new SearchConditions("HONGDAE", "2026-10-17", null, "19:00", 2, List.of(), List.of(),
                "DEFAULT", List.of(), null, null, null, List.of(), "USER");
        assertEquals(List.of(), two.withPartyMoods().atmospheres());                    // 2명이어도 연인 아니면 안 붙임
        SearchConditions couple = new SearchConditions("HONGDAE", "2026-10-17", null, "19:00", 2, List.of(), List.of("활기찬"),
                "DEFAULT", List.of(), null, null, "COUPLE", List.of(), "USER");
        assertEquals(List.of("활기찬", "데이트"), couple.withPartyMoods().atmospheres());
        SearchConditions family = new SearchConditions("HONGDAE", "2026-10-17", null, "12:00", 5, List.of(), List.of(),
                "DEFAULT", List.of(), null, null, "FAMILY", List.of(), "USER");
        assertEquals(List.of("단체", "아이"), family.withPartyMoods().atmospheres());
    }

    @Test
    @DisplayName("v0.5 음식 취향: 큰 종류 고르면 식사 칸은 그 종류만, 세부 맞으면 사용자 요구 점수 올라감, 이상한 코드는 400")
    void cuisines() {
        SearchConditions c = new SearchConditions("HONGDAE", "2026-10-17", "WEEKEND", "19:00", 3, List.of(), List.of(),
                "DEFAULT", List.of(), null, null, null, List.of(), "USER");
        for (CoursePlan course : courses(service().search(new SearchService.SearchRequest("홍대", null, null, null,
                c.withCuisines(List.of("JAPANESE"), List.of()))))) {
            for (CoursePlan.Stop s : course.stops()) {
                if (s.slot() == Slot.MEAL) assertEquals("JAPANESE", STORE.find(s.placeId()).orElseThrow().cuisine(), s.name());
            }
        }
        PlaceScoreModel model = new PlaceScoreModel(STORE);
        PlaceStore.Place sushi = STORE.all().stream()
                .filter(p -> "초밥·롤".equals(p.cuisineDetail()) && p.region().equals("HONGDAE")).findFirst().orElseThrow();
        double plain = model.forConditions(c.withDefaults()).score(sushi.toCoursePlace(), 19).request();
        double liked = model.forConditions(c.withCuisines(List.of(), List.of("초밥·롤")).withDefaults()).score(sushi.toCoursePlace(), 19).request();
        assertEquals(0.5, plain);
        assertEquals(1.0, liked);
        assertEquals("INVALID_INPUT", expectError(() -> service().search(new SearchService.SearchRequest("홍대", null, null, null,
                c.withCuisines(List.of("PIZZA"), List.of())))).code());
        assertEquals("INVALID_INPUT", expectError(() -> service().search(new SearchService.SearchRequest("홍대", null, null, null,
                new SearchConditions("HONGDAE", "2026-10-17", null, "19:00", 3, List.of(), List.of(), "DEFAULT",
                        List.of("PEANUT"), null, null, null, List.of(), "USER")))).code());   // 알레르기는 2개만
    }

    @Test
    @DisplayName("문장 검색: 조용한 곳이면 놀거리 칸에 노래방·오락실 없음")
    void sentenceQuiet() {
        Map<String, Object> data = service().search(query("토요일 오후 3시에 성수에서 친구랑 조용한 카페 가고 저녁도 먹고 싶어"));
        assertEquals("RULE", ((Map<?, ?>) data.get("conditions")).get("extractedBy"));
        for (CoursePlan c : courses(data)) {
            for (CoursePlan.Stop s : c.stops()) {
                if (s.slot() == Slot.PLAY) {
                    assertFalse(CourseRules.isNoisy(STORE.find(s.placeId()).orElseThrow().toCoursePlace()), s.name());
                }
            }
        }
    }

    @Test
    @DisplayName("에러: 지역 없음 422, 문장 없음 400, 잘못된 시간 400")
    void errors() {
        ApiException e = expectError(() -> service().search(query("조용한 카페 가고 싶어")));
        assertEquals("CONDITION_MISSING", e.code());
        assertEquals(422, e.status());
        assertEquals("INVALID_INPUT", expectError(() -> service().search(query("  "))).code());
        assertEquals("INVALID_INPUT", expectError(() -> service().search(
                new SearchService.SearchRequest("성수 카페", null, "25:00", null, null))).code());
    }

    @Test
    @DisplayName("선택기 값이 문장보다 우선 (일요일 10시 → 카페부터)")
    void pickersWin() {
        Map<String, Object> data = service().search(
                new SearchService.SearchRequest("토요일 저녁 성수 카페", "2026-10-18", "10:00", "HONGDAE", null));
        Map<?, ?> cond = (Map<?, ?>) data.get("conditions");
        assertEquals("HONGDAE", cond.get("region"));
        assertEquals("WEEKEND", cond.get("dayType"));
        assertEquals(Slot.CAFE, courses(data).get(0).stops().get(0).slot());
    }

    @Test
    @DisplayName("로그인: 문장에 지역·분위기 없으면 내 설정으로, 알레르기는 합치기, 문장 지역이 우선")
    void myPreferences() {
        SearchService.MyPreferences my = new SearchService.MyPreferences("SEONGSU", List.of("조용한"), List.of("SHELLFISH"));
        Map<?, ?> cond = (Map<?, ?>) service().search(query("토요일 오후 3시에 카페 가고 싶어"), my).get("conditions");
        assertEquals("SEONGSU", cond.get("region"));
        assertEquals(List.of("조용한"), cond.get("atmospheres"));
        assertEquals("QUIET", cond.get("crowdPreference"));
        assertEquals(List.of("SHELLFISH"), cond.get("allergies"));

        Map<?, ?> hongdae = (Map<?, ?>) service().search(
                query("토요일 저녁 7시 홍대에서 남자친구랑 신나게 놀 수 있는 사람 많은 곳"), my).get("conditions");
        assertEquals("HONGDAE", hongdae.get("region"));
        assertEquals(List.of("데이트", "활기찬"), hongdae.get("atmospheres"));
        assertEquals("LIVELY", hongdae.get("crowdPreference"));
        assertEquals(List.of("SHELLFISH"), hongdae.get("allergies"));

        // 로그인 안 하면 예전처럼 지역 다시 물어봄
        assertEquals("CONDITION_MISSING", expectError(() -> service().search(query("토요일 오후 3시에 카페 가고 싶어"))).code());
    }

    @Test
    @DisplayName("제외 음식: 고기 빼면 식사 칸에 고깃집 없음")
    void excludedFoods() {
        SearchConditions c = new SearchConditions("HONGDAE", "2026-10-17", null, "19:00", 2, List.of(), List.of(),
                "DEFAULT", List.of(), null, null, null, List.of("고기"), "USER");
        for (CoursePlan course : courses(service().search(new SearchService.SearchRequest("홍대", null, null, null, c)))) {
            for (CoursePlan.Stop s : course.stops()) {
                if (s.slot() == Slot.MEAL) {
                    String kakao = STORE.find(s.placeId()).orElseThrow().kakaoCategory();
                    assertFalse(kakao.contains("고기") || kakao.contains("갈비") || kakao.contains("삼겹살"), kakao);
                }
            }
        }
    }

    @Test
    @DisplayName("코스 수정: 다시 계산 + 경고, 없는 코스·장소·이상한 체류시간은 에러")
    void update() {
        SearchService svc = service();
        CoursePlan best = courses(svc.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()))).get(0);
        List<SearchService.StopEdit> stops = best.stops().stream()
                .map(s -> new SearchService.StopEdit(s.placeId(), 120)).toList();

        Map<String, Object> updated = svc.updateCourse(best.courseId(), new SearchService.UpdateRequest(null, stops));
        assertEquals(best.courseId(), updated.get("courseId"));
        assertNull(updated.get("rank"));
        @SuppressWarnings("unchecked")
        List<CourseWarning> warnings = (List<CourseWarning>) updated.get("warnings");
        assertTrue(warnings.stream().anyMatch(w -> w.code().equals("TOTAL_TIME_OVER")));

        assertEquals("COURSE_NOT_FOUND", expectError(() -> svc.updateCourse("c_없음", new SearchService.UpdateRequest(null, stops))).code());
        assertEquals("PLACE_NOT_FOUND", expectError(() -> svc.updateCourse(best.courseId(),
                new SearchService.UpdateRequest(null, List.of(new SearchService.StopEdit("0", 60))))).code());
        assertEquals("INVALID_INPUT", expectError(() -> svc.updateCourse(best.courseId(),
                new SearchService.UpdateRequest(null, List.of(new SearchService.StopEdit(stops.get(0).placeId(), 5))))).code());
    }

    @Test
    @DisplayName("공유: 카톡 글 + 공유 보기, 원본 고쳐도 공유한 코스는 그대로")
    void share() {
        SearchService svc = service();
        CoursePlan best = courses(svc.search(new SearchService.SearchRequest("성수", null, null, null, seongsuQuiet()))).get(0);
        Map<String, Object> share = svc.createShare(best.courseId());
        assertTrue(((String) share.get("shareText")).startsWith("[오디가] 2026-10-17 15:00 성수 코스\n1. 15:00 "));

        svc.updateCourse(best.courseId(), new SearchService.UpdateRequest(null,
                List.of(new SearchService.StopEdit(best.stops().get(0).placeId(), 60))));
        CoursePlan shared = (CoursePlan) svc.viewShare((String) share.get("shareCode")).get("course");
        assertEquals(3, shared.stops().size());
        assertEquals("SHARE_NOT_FOUND", expectError(() -> svc.viewShare("없는코드")).code());
    }
}
