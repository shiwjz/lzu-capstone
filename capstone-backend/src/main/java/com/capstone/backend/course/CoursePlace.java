package com.capstone.backend.course;

import java.util.List;

/**
 * 코스 계산에 필요한 장소 정보만 모은 것
 * - region: SEONGSU / HONGDAE / GANGNAM
 * - category: FOOD / CAFE / CULTURE / ACTIVITY / EXPERIENCE / SHOPPING / TOUR / NATURE (분류 보정 끝난 값)
 * - tags: 블로그 태그 이름 (place_tag), 추천 이유 만들 때 사용
 */
public record CoursePlace(
        String placeId,
        String name,
        String region,
        String category,
        String kakaoCategory,
        double lat,
        double lng,
        List<String> tags,
        String cuisine,          // 음식 큰 종류 (KOREAN·CAFE …, 음식점·카페 아니면 null) - v0.5
        String cuisineDetail     // 세부 (초밥·롤 …, 모르면 null)
) {
    /** 음식 취향 없는 예전 모양 (테스트용) */
    public CoursePlace(String placeId, String name, String region, String category, String kakaoCategory,
                       double lat, double lng, List<String> tags) {
        this(placeId, name, region, category, kakaoCategory, lat, lng, tags, null, null);
    }

    /** 술집이면 BAR, 아니면 카테고리대로 (11주차) */
    public Slot slot() {
        return isBar() ? Slot.BAR : Slot.of(category);
    }

    /** 술집인지: 음식 큰 종류 BAR(예린 확정본) 또는 카카오 카테고리에 '술집' */
    public boolean isBar() {
        return "BAR".equals(cuisine) || kakaoCategory.contains("술집");
    }
}
