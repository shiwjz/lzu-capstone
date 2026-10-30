package com.capstone.backend.course;

/**
 * 코스 칸. 식사 = FOOD, 카페 = CAFE, 놀거리 = 나머지 6개 카테고리
 * - SNACK(베이커리·아이스크림)은 코스 생성엔 안 쓰고, 코스에 직접 추가하면 카페 칸으로 표시
 */
public enum Slot {
    MEAL, CAFE, PLAY;

    public static Slot of(String category) {
        return switch (category) {
            case "FOOD" -> MEAL;
            case "CAFE", "SNACK" -> CAFE;
            default -> PLAY;
        };
    }
}
