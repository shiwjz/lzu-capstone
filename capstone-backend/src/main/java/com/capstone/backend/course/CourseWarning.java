package com.capstone.backend.course;

/**
 * 코스 수정 결과 경고 (TOTAL_TIME_OVER, TOTAL_TIME_UNDER, LONG_WALK, BUSY_AT_ARRIVAL, OUTSIDE_HOURS)
 * 경고가 있어도 저장은 됨, 앱에서 문구 보여주고 사용자가 판단
 */
public record CourseWarning(String code, String message) {
}
