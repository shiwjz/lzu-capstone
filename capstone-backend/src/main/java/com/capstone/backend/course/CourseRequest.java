package com.capstone.backend.course;

import java.util.List;
import java.util.Set;

/**
 * 코스 생성 조건 (검색 API의 conditions에서 코스에 필요한 것만)
 * - startMinute: 시작 시각을 0시부터 분으로 (15:00 → 900)
 * - playCategories: 문장에 놀거리 종류가 있으면 그 카테고리, 없으면 빈 목록 → 6개 전부
 * - order: 문장에 순서가 있으면 그 순서, 없으면 빈 목록 → 코스 틀 (술·문화·밤 등, CourseRules.slotOrder)
 */
public record CourseRequest(
        String region,
        int startMinute,
        int partySize,
        List<String> atmospheres,
        CrowdPreference crowdPreference,
        Set<String> allergies,
        List<String> playCategories,
        List<Slot> order,
        Boolean drinking          // 11주차: true = 술 원함(음식 취향 술집), false = 술 빼달라고 함, null = 말 없음
) {
    /** 술 얘기 없는 예전 모양 */
    public CourseRequest(String region, int startMinute, int partySize, List<String> atmospheres,
                         CrowdPreference crowdPreference, Set<String> allergies, List<String> playCategories,
                         List<Slot> order) {
        this(region, startMinute, partySize, atmospheres, crowdPreference, allergies, playCategories, order, null);
    }

    /** 칸 순서: 문장에 순서가 있으면 그대로, 없으면 코스 틀 (CourseRules.slotOrder) */
    public List<Slot> slotOrder() {
        if (order != null && !order.isEmpty()) return order;
        List<String> picked = playCategories == null ? List.of()
                : playCategories.stream().filter(CourseRules.PLAY_CATEGORIES::contains).toList();
        return CourseRules.slotOrder(startMinute, drinking, picked);
    }

    /** 조용한 곳을 원하는지 (혼잡 선호 QUIET 또는 분위기 '조용한') */
    public boolean wantsQuiet() {
        return crowdPreference == CrowdPreference.QUIET
                || (atmospheres != null && atmospheres.contains("조용한"));
    }

    public List<String> playCategoriesOrAll() {
        List<String> picked = playCategories == null ? List.of()
                : playCategories.stream().filter(CourseRules.PLAY_CATEGORIES::contains).toList();
        return picked.isEmpty() ? CourseRules.PLAY_CATEGORIES : picked;
    }
}
