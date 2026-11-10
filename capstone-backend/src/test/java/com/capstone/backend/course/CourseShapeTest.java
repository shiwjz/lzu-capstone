package com.capstone.backend.course;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

/** 11주차 코스 틀·빼기·추가·킵 자리·장소 수별 시간 */
class CourseShapeTest {

    private static final Slot M = Slot.MEAL, C = Slot.CAFE, P = Slot.PLAY, B = Slot.BAR;

    @Test
    @DisplayName("틀 5종류: 기본 2개, 술 3개, 문화·산책·쇼핑 1개 + 놀거리 종류")
    void types() {
        assertEquals(List.of(List.of(M, C, P), List.of(C, P, M)),
                CourseShape.variants("BASIC", 15 * 60, null, List.of(), Set.of(), Set.of()));
        assertEquals(List.of(List.of(M, B), List.of(M, B, B), List.of(P, M, B)),
                CourseShape.variants("DRINK", 19 * 60, true, List.of(), Set.of(), Set.of()));
        assertEquals(List.of(List.of(P, C, M)), CourseShape.variants("WALK", 13 * 60, null, List.of(), Set.of(), Set.of()));
        assertEquals(List.of("CULTURE"), CourseShape.playPool("CULTURE", List.of("ACTIVITY"), Set.of(), Set.of()));
        assertEquals(List.of("NATURE"), CourseShape.playPool("WALK", List.of(), Set.of(), Set.of()));
        assertEquals(List.of(), CourseShape.playPool(null, List.of(), Set.of(), Set.of()));   // 전부
    }

    @Test
    @DisplayName("빼기: 카페 → 놀거리, 식사 → 카페(이미 있으면 놀거리), 술집 → 놀거리, 놀거리 종류 빼기")
    void exclude() {
        // 자동 15시 = 놀거리 → 카페 → 식사
        assertEquals(List.of(List.of(P, P, M)), CourseShape.variants(null, 15 * 60, null, List.of(), Set.of("CAFE"), Set.of()));
        // 자동 12시 = 식사 → 카페 → 놀거리, 카페가 이미 있으니 식사 → 놀거리
        assertEquals(List.of(List.of(P, C, P)), CourseShape.variants(null, 12 * 60, null, List.of(), Set.of("FOOD"), Set.of()));
        // 기본 틀에서 식사·카페 둘 다 빼면 놀거리만 → 같은 순서 하나로 합쳐짐
        assertEquals(List.of(List.of(P, P, P)), CourseShape.variants("BASIC", 15 * 60, null, List.of(), Set.of("FOOD", "CAFE"), Set.of()));
        assertEquals(List.of(List.of(M, P, P)), CourseShape.variants(null, 20 * 60, null, List.of(), Set.of("BAR"), Set.of()));
        assertEquals(List.of("CULTURE", "EXPERIENCE", "SHOPPING", "TOUR", "NATURE"),
                CourseShape.playPool(null, List.of(), Set.of("ACTIVITY"), Set.of()));
    }

    @Test
    @DisplayName("추가: 없는 칸만 넣음 (술집은 맨 끝, 나머지는 술집 앞), 최대 4곳")
    void include() {
        assertEquals(List.of(List.of(M, C, P, B), List.of(C, P, M, B)),
                CourseShape.variants("BASIC", 15 * 60, null, List.of(), Set.of(), Set.of("BAR")));
        assertEquals(List.of(List.of(M, C, B), List.of(M, C, B, B), List.of(P, M, C, B)),
                CourseShape.variants("DRINK", 19 * 60, true, List.of(), Set.of(), Set.of("CAFE")));
        assertEquals(List.of(List.of(P, C, M)),       // 놀거리 칸은 이미 있음
                CourseShape.variants(null, 15 * 60, null, List.of(), Set.of(), Set.of("ACTIVITY")));
        assertEquals(List.of("CULTURE", "ACTIVITY"), CourseShape.playPool("CULTURE", List.of(), Set.of(), Set.of("ACTIVITY")));
    }

    @Test
    @DisplayName("장소 수별 시간 기준: 2곳 100~170분, 3곳 150~210분(예전), 4곳 200~290분")
    void timeWindows() {
        assertEquals(List.of(135, 35), List.of(CourseRules.targetMinutes(2), CourseRules.toleranceMinutes(2)));
        assertEquals(List.of(180, 30), List.of(CourseRules.targetMinutes(3), CourseRules.toleranceMinutes(3)));
        assertEquals(List.of(245, 45), List.of(CourseRules.targetMinutes(4), CourseRules.toleranceMinutes(4)));
        assertEquals("2시간 50분", CourseRules.durationText(170));
        assertEquals("3시간", CourseRules.durationText(180));
    }

    @Test
    @DisplayName("킵 자리: 같은 칸 있으면 거기, 없으면 칸 추가(술집 앞), 4곳 넘으면 못 씀")
    void keepSlots() {
        CoursePlace cafe = new CoursePlace("k1", "카페", "SEONGSU", "CAFE", "음식점 > 카페", 0, 0, List.of());
        CoursePlace bar = new CoursePlace("k2", "바", "SEONGSU", "FOOD", "음식점 > 술집 > 칵테일바", 0, 0, List.of());
        Map<Integer, CoursePlace> out = new HashMap<>();
        assertEquals(List.of(M, C, P), CourseGenerator.keepSlots(List.of(M, C, P), List.of("k1"), List.of(cafe), out));
        assertEquals(Map.of(1, cafe), out);
        out.clear();
        assertEquals(List.of(M, C, B), CourseGenerator.keepSlots(List.of(M, B), List.of("k1"), List.of(cafe), out));
        assertEquals(Map.of(1, cafe), out);
        out.clear();
        assertEquals(List.of(M, C, P, B), CourseGenerator.keepSlots(List.of(M, C, P), List.of("k2", "k1"), List.of(cafe, bar), out));
        assertEquals(Map.of(3, bar, 1, cafe), out);
        out.clear();
        assertNull(CourseGenerator.keepSlots(List.of(M, C, P, P), List.of("k2"), List.of(bar), out));
    }
}
