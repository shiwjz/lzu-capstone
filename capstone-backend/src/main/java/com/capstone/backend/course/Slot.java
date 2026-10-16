package com.capstone.backend.course;

/**
 * 코스 칸. 식사 = FOOD, 카페 = CAFE, 놀거리 = 나머지 6개 카테고리
 */
public enum Slot {
    MEAL, CAFE, PLAY;

    public static Slot of(String category) {
        return switch (category) {
            case "FOOD" -> MEAL;
            case "CAFE" -> CAFE;
            default -> PLAY;
        };
    }
}
