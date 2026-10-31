package com.capstone.backend.search;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 규칙 기반 조건 추출 테스트 - 김예민
 * - 기준 시각: 2026-10-16(금) 20:00
 * - @최예린 Gemini 정답 문장 50개 만들면 여기에도 몇 개 넣어서 규칙 예비 처리 정확도 같이 보기
 */
class RuleConditionExtractorTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 16, 20, 0);
    private final RuleConditionExtractor rule = new RuleConditionExtractor();

    private SearchConditions x(String q) {
        return rule.extract(q, NOW);
    }

    @Test
    @DisplayName("성수 주말 조용함 (가짜 JSON 시나리오 1)")
    void seongsu() {
        SearchConditions c = x("토요일 오후 3시에 성수에서 친구랑 조용한 카페 가고 저녁도 먹고 싶어");
        assertEquals("SEONGSU", c.region());
        assertEquals("2026-10-17", c.date());
        assertEquals("WEEKEND", c.dayType());
        assertEquals("15:00", c.startTime());
        assertEquals(2, c.partySize().intValue());
        assertEquals(List.of("CAFE", "FOOD"), c.categories());
        assertEquals(List.of("조용함"), c.atmospheres());
        assertEquals("QUIET", c.crowdPreference());
        assertEquals("FRIEND", c.companionType());
        assertEquals("RULE", c.extractedBy());
    }

    @Test
    @DisplayName("홍대 주말 저녁 활기 (가짜 JSON 시나리오 2)")
    void hongdae() {
        SearchConditions c = x("토요일 저녁 7시 홍대에서 남자친구랑 신나게 놀 수 있는 사람 많은 곳");
        assertEquals("HONGDAE", c.region());
        assertEquals("19:00", c.startTime());
        assertEquals(2, c.partySize().intValue());
        assertEquals(List.of("데이트"), c.atmospheres());
        assertEquals("LIVELY", c.crowdPreference());
        assertEquals("COUPLE", c.companionType());
        assertTrue(c.categories().contains("ACTIVITY"));
        assertNull(c.gender());   // 남자친구 = 동행, 사용자 성별 아님
    }

    @Test
    @DisplayName("강남 평일 4명 갑각류 (가짜 JSON 시나리오 3)")
    void gangnam() {
        SearchConditions c = x("금요일 저녁 7시 강남역 근처에서 회사 동기 4명 모임, 한 명이 갑각류 알레르기 있어");
        assertEquals("GANGNAM", c.region());
        assertEquals("2026-10-16", c.date());
        assertEquals("WEEKDAY", c.dayType());
        assertEquals(4, c.partySize().intValue());
        assertEquals(List.of("단체"), c.atmospheres());
        assertEquals("DEFAULT", c.crowdPreference());
        assertEquals(List.of("SHELLFISH"), c.allergies());
        assertEquals("COWORKER", c.companionType());
    }

    @Test
    @DisplayName("내일 점심 혼자")
    void tomorrowLunchSolo() {
        SearchConditions c = x("내일 점심에 홍대에서 혼자 밥 먹을 곳");
        assertEquals("2026-10-17", c.date());
        assertEquals("12:00", c.startTime());
        assertEquals(1, c.partySize().intValue());
        assertEquals("SOLO", c.companionType());
        assertEquals(List.of("FOOD"), c.categories());
    }

    @Test
    @DisplayName("다음 주 일요일, 20대 여자 둘, 전시·디저트")
    void nextWeekGenderAge() {
        SearchConditions c = x("다음 주 일요일 오전 11시 강남에서 20대 여자 둘이 전시 보고 디저트 먹을래");
        assertEquals("2026-10-25", c.date());
        assertEquals("11:00", c.startTime());
        assertEquals(2, c.partySize().intValue());
        assertEquals("F", c.gender());
        assertEquals("20s", c.ageGroup());
        assertTrue(c.categories().contains("CULTURE"));
        assertTrue(c.atmospheres().contains("디저트"));
    }

    @Test
    @DisplayName("다음 주·이번 주는 달력 기준(월요일 시작): 토요일·일요일에 물어봐도 맞게")
    void weeks() {
        LocalDateTime sat = LocalDateTime.of(2026, 10, 31, 19, 0);   // 토
        LocalDateTime sun = LocalDateTime.of(2026, 11, 1, 19, 0);    // 일
        assertEquals("2026-11-07", rule.extract("다음주 토요일 성수 카페", sat).date());
        assertEquals("2026-11-07", rule.extract("담주 토요일 성수 카페", sat).date());
        assertEquals("2026-11-06", rule.extract("다음주 금요일 강남", sat).date());
        assertEquals("2026-11-07", rule.extract("다음 주말 성수", sat).date());
        assertEquals("2026-10-31", rule.extract("토요일 성수", sat).date());
        assertEquals("2026-11-07", rule.extract("다음주 토요일 성수", sun).date());   // 일요일엔 바로 다음 토요일
        assertEquals("2026-11-07", rule.extract("다음 주말 성수", sun).date());
        assertEquals("2026-11-01", rule.extract("이번 주말 성수", sun).date());
        assertEquals("2026-11-06", rule.extract("이번주 금요일 홍대", LocalDateTime.of(2026, 11, 3, 10, 0)).date());
    }

    @Test
    @DisplayName("지역 없으면 null, '2시간'은 시각 아님, 제외 음식")
    void missingAndExcluded() {
        assertNull(x("조용한 카페 가고 싶어").region());
        assertNull(x("성수에서 2시간 정도 놀 곳").startTime());
        SearchConditions c = x("성수에서 저녁 먹을 건데 매운 거 말고");
        assertEquals("18:00", c.startTime());
        assertEquals(List.of("매운"), c.excludedFoods());
        assertEquals(List.of(), x("성수 회사 근처 카페").allergies());   // '회사'의 '회'를 생선으로 안 봄
    }
}
