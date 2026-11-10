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
        List<String> keywords,   // 코스 키워드 태그 (v0.5, 예: 조용함·한산·초밥·롤·도보 5분 이내)
        String route,            // 코스 경로 이름 (11주차, 예: 칵테일바 → 카페 → 방탈출) - 제목 밑 태그용
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
        return withMeta(courseId, rank, title, reason, keywords);
    }

    public CoursePlan withMeta(String courseId, Integer rank, String title, String reason, List<String> keywords) {
        return withMeta(courseId, rank, title, reason, keywords, route);
    }

    public CoursePlan withMeta(String courseId, Integer rank, String title, String reason, List<String> keywords,
                               String route) {
        return new CoursePlan(courseId, rank, title, reason, keywords, route, startAt, endAt, totalMinutes,
                totalWalkMinutes, totalDistanceMeters, score, stops);
    }
}
