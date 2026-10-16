package com.capstone.backend.course;

import java.util.List;

/**
 * 계산된 코스 (API 응답 courses[]와 같은 형식)
 * courseId는 저장할 때 붙이고, rank는 코스 수정 결과면 null
 */
public record CoursePlan(
        String courseId,
        Integer rank,
        String title,
        String reason,
        String startAt,
        String endAt,
        int totalMinutes,
        int totalWalkMinutes,
        int totalDistanceMeters,
        Score score,
        List<Stop> stops
) {

    public record Score(double total, double placeAvg, double moveEfficiency, double timeFit) {
    }

    public record Stop(
            int order,
            Slot slot,
            String placeId,
            String name,
            String category,
            double lat,
            double lng,
            String arriveAt,
            String leaveAt,
            int stayMinutes,
            Integer walkMinutesFromPrev,       // 첫 장소는 null
            Integer distanceMetersFromPrev,    // 첫 장소는 null
            Congestion congestion,             // 도착 시각 기준
            double placeScore
    ) {
    }

    public record Congestion(CongestionLevel level, int percentile) {
    }

    public CoursePlan withMeta(String courseId, Integer rank, String title, String reason) {
        return new CoursePlan(courseId, rank, title, reason, startAt, endAt, totalMinutes,
                totalWalkMinutes, totalDistanceMeters, score, stops);
    }
}
