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
        List<String> tags
) {
    public Slot slot() {
        return Slot.of(category);
    }
}
