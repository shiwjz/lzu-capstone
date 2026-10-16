package com.capstone.backend.course;

/**
 * 장소 점수 (0~1)
 * - total = 사용자 요구 0.45 + 타깃 특성 0.30 + 혼잡도 적합도 0.25
 * - level, percentile: 그 시각의 혼잡도 (윤경 데이터 pct_same_time)
 */
public record PlaceScore(
        double total,
        double request,
        double target,
        double congestionFit,
        CongestionLevel level,
        int percentile
) {
}
