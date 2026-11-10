package com.capstone.backend.course;

import java.util.List;
import java.util.Set;

/**
 * 코스 생성 조건 (검색 API의 conditions에서 코스에 필요한 것만)
 * - startMinute: 시작 시각을 0시부터 분으로 (15:00 → 900)
 * - playCategories: 문장에 놀거리 종류가 있으면 그 카테고리, 없으면 빈 목록 → 6개 전부
 * - order: 앱에서 직접 고친 순서 (있으면 이게 제일 우선), 없으면 빈 목록 → variants → 자동 틀
 * - variants (11주차): 코스 틀·빼기·추가로 정한 칸 순서 후보들 (CourseShape.variants), 없으면 자동 틀 하나
 * - keepPlaceIds (11주차): 킵한 장소 (최대 2곳) → 모든 코스에 꼭 넣음
 * - mustPlayIds (11주차): 놀거리 세부 취향("보드게임") 장소들 → 코스마다 이 중 하나를 놀거리 칸에 꼭 넣음
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
        Boolean drinking,         // 11주차: true = 술 원함(음식 취향 술집), false = 술 빼달라고 함, null = 말 없음
        List<List<Slot>> variants,
        List<String> keepPlaceIds,
        List<String> mustPlayIds
) {
    public CourseRequest(String region, int startMinute, int partySize, List<String> atmospheres,
                         CrowdPreference crowdPreference, Set<String> allergies, List<String> playCategories,
                         List<Slot> order, Boolean drinking) {
        this(region, startMinute, partySize, atmospheres, crowdPreference, allergies, playCategories, order,
                drinking, null, null, null);
    }

    /** 술 얘기 없는 예전 모양 */
    public CourseRequest(String region, int startMinute, int partySize, List<String> atmospheres,
                         CrowdPreference crowdPreference, Set<String> allergies, List<String> playCategories,
                         List<Slot> order) {
        this(region, startMinute, partySize, atmospheres, crowdPreference, allergies, playCategories, order, null);
    }

    /** 칸 순서 후보들: 직접 고친 순서 > 틀·빼기·추가 > 자동 틀 */
    public List<List<Slot>> slotOrders() {
        if (order != null && !order.isEmpty()) return List.of(order);
        if (variants != null && !variants.isEmpty()) return variants;
        List<String> picked = playCategories == null ? List.of()
                : playCategories.stream().filter(CourseRules.PLAY_CATEGORIES::contains).toList();
        return List.of(CourseRules.slotOrder(startMinute, drinking, picked));
    }

    /** 첫 번째 칸 순서 (추천 장소 목록용) */
    public List<Slot> slotOrder() {
        return slotOrders().get(0);
    }

    /** 순서만 바꾼 요청 (틀 순서마다 코스 만들 때) */
    public CourseRequest withOrder(List<Slot> newOrder) {
        return new CourseRequest(region, startMinute, partySize, atmospheres, crowdPreference, allergies,
                playCategories, newOrder, drinking, variants, keepPlaceIds, mustPlayIds);
    }

    public List<String> keeps() {
        return keepPlaceIds == null ? List.of() : keepPlaceIds;
    }

    public List<String> mustPlay() {
        return mustPlayIds == null ? List.of() : mustPlayIds;
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
