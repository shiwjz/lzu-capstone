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

    public Slot slot() {
        return Slot.of(category);
    }
}
