package com.capstone.backend.course;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 진짜 장소 데이터 + 가짜 점수로 코스 3개 나오는지 (8주차 완료 기준) - 김예민
 * - 기대값 = mocks/search_*.json의 1등 코스 → 파이썬 가짜 JSON이랑 자바 결과가 같은지 확인
 * - mocks 다시 만들어서 코스가 바뀌면 여기 기대값도 같이 바꾸기
 */
class DevCourseDataTest {

    private static final DevCourseData DATA = DevCourseData.load();
    private final CourseGenerator generator = new CourseGenerator();

    private List<CoursePlan> run(CourseRequest request, String dayType) {
        return generator.generate(request, DATA.places(), DATA.scorer(request, dayType));
    }

    @Test
    @DisplayName("데이터 읽기: 장소 1,773곳")
    void loads() {
        assertEquals(1773, DATA.places().size());
    }

    @Test
    @DisplayName("성수 주말 15시 조용한 곳 → search_seongsu_weekend_quiet.json이랑 같음")
    void seongsu() {
        CourseRequest req = new CourseRequest("SEONGSU", 15 * 60, 2, List.of("조용함"), CrowdPreference.QUIET,
                Set.of(), List.of(), List.of());
        List<CoursePlan> courses = run(req, "WEEKEND");

        assertEquals(3, courses.size());
        CoursePlan best = courses.get(0);
        assertEquals(List.of("20745493", "780757764", "2091596191"), ids(best));
        assertEquals("성수 오후 노래방 코스", best.title());
        assertEquals("'조용함' 후기 많은 곳 2곳 · 3곳 중 3곳이 도착 시간에 한산 · 총 도보 6분", best.reason());
        assertEquals(176, best.totalMinutes());
        assertEquals(0.87, best.score().total());
        assertEquals("16:05", best.stops().get(1).arriveAt());
    }

    @Test
    @DisplayName("홍대 주말 19시 활기찬 곳 → search_hongdae_weekend_lively.json이랑 같음")
    void hongdae() {
        CourseRequest req = new CourseRequest("HONGDAE", 19 * 60, 2, List.of("데이트"), CrowdPreference.LIVELY,
                Set.of(), List.of("ACTIVITY"), List.of());
        CoursePlan best = run(req, "WEEKEND").get(0);

        assertEquals(List.of("19382069", "26644181", "205320302"), ids(best));
        assertEquals("홍대 저녁 보드게임 코스", best.title());
        assertEquals(0.93, best.score().total());
    }

    @Test
    @DisplayName("강남 평일 19시 4명 갑각류 → search_gangnam_weekday_group.json이랑 같음")
    void gangnam() {
        CourseRequest req = new CourseRequest("GANGNAM", 19 * 60, 4, List.of("단체석"), CrowdPreference.DEFAULT,
                Set.of("SHELLFISH"), List.of(), List.of());
        List<CoursePlan> courses = run(req, "WEEKDAY");

        assertEquals(List.of("1131298228", "1233664289", "372992819"), ids(courses.get(0)));
        assertEquals("강남 저녁 노래방 코스", courses.get(0).title());
        for (CoursePlan c : courses) {
            assertTrue(c.totalMinutes() >= 150 && c.totalMinutes() <= 210);
        }
    }

    private static List<String> ids(CoursePlan plan) {
        return plan.stops().stream().map(CoursePlan.Stop::placeId).toList();
    }
}
