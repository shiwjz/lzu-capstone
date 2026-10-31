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
                List.of("조용함"), "QUIET", List.of(), null, null, "FRIEND", List.of(), "GEMINI");
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
        assertEquals(3, courses(data).size());
        assertTrue(((List<?>) data.get("places")).size() <= 10);
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
        SearchService.MyPreferences my = new SearchService.MyPreferences("SEONGSU", List.of("조용함"), List.of("SHELLFISH"));
        Map<?, ?> cond = (Map<?, ?>) service().search(query("토요일 오후 3시에 카페 가고 싶어"), my).get("conditions");
        assertEquals("SEONGSU", cond.get("region"));
        assertEquals(List.of("조용함"), cond.get("atmospheres"));
        assertEquals("QUIET", cond.get("crowdPreference"));
        assertEquals(List.of("SHELLFISH"), cond.get("allergies"));

        Map<?, ?> hongdae = (Map<?, ?>) service().search(
                query("토요일 저녁 7시 홍대에서 남자친구랑 신나게 놀 수 있는 사람 많은 곳"), my).get("conditions");
        assertEquals("HONGDAE", hongdae.get("region"));
        assertEquals(List.of("데이트"), hongdae.get("atmospheres"));
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
