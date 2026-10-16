package com.capstone.backend.course;

/**
 * 장소 점수 계산 (이윤경 장소 점수 모듈이 구현할 자리)
 * 코스 생성은 이 인터페이스만 보고 동작해서, 점수 방식이 바뀌어도 코스 코드는 그대로
 */
@FunctionalInterface
public interface PlaceScorer {

    /**
     * @param hour 도착 시각의 시(0~23, 자정 넘으면 24 이상이 올 수 있어서 구현에서 % 24 처리)
     */
    PlaceScore score(CoursePlace place, int hour);
}
