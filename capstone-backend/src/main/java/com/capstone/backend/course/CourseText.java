package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 코스 제목·추천 이유 (규칙 기반)
 * - 제목: {지역} {시간대} {놀거리 종류} 코스 (예: 성수 오후 노래방 코스)
 * - 추천 이유: 분위기 태그 맞는 곳 수 · 혼잡 선호에 맞는 곳 수 · 총 도보 시간
 */
public final class CourseText {

    private CourseText() {
    }

    // 카카오 카테고리 이름 → 제목에 쓸 이름
    private static final Map<String, String> PLAY_LABEL = Map.of(
            "미술,공예", "공방", "화랑", "전시", "보드카페", "보드게임",
            "방탈출카페", "방탈출", "만화방", "만화카페");

    public static String timeWord(int startMinute) {
        int hour = startMinute / 60;
        if (hour < 11) return "오전";
        if (hour < 14) return "점심";
        if (hour < 17) return "오후";
        if (hour < 21) return "저녁";
        return "밤";
    }

    /** 카카오 카테고리에서 놀거리 종류 (예: '가정,생활 > 여가시설 > 노래방' → 노래방) */
    public static String playLabel(String kakaoCategory) {
        String[] parts = kakaoCategory.split(" > ");
        int i = Math.min(2, parts.length - 1);
        if (parts[i].equals("테마카페") && parts.length > i + 1) {
            i++;
        }
        return PLAY_LABEL.getOrDefault(parts[i], parts[i].replace(',', '·'));
    }

    public static String title(CoursePlan plan, String region, int startMinute, Map<String, CoursePlace> placesById) {
        String regionLabel = CourseRules.REGION_LABEL.getOrDefault(region, region);
        String when = timeWord(startMinute);
        return plan.stops().stream()
                .filter(s -> s.slot() == Slot.PLAY)
                .findFirst()
                .map(s -> regionLabel + " " + when + " " + playLabel(placesById.get(s.placeId()).kakaoCategory()) + " 코스")
                .orElse(regionLabel + " " + when + " 코스");
    }

    public static String reason(CoursePlan plan, CourseRequest request, Map<String, CoursePlace> placesById) {
        List<String> parts = new ArrayList<>();
        List<CoursePlan.Stop> stops = plan.stops();

        if (request.atmospheres() != null && !request.atmospheres().isEmpty()) {
            String mood = request.atmospheres().get(0);
            long matched = stops.stream()
                    .filter(s -> placesById.get(s.placeId()).tags().contains(mood))
                    .count();
            if (matched > 0) {
                parts.add("'" + mood + "' 후기 많은 곳 " + matched + "곳");
            }
        }
        if (request.crowdPreference() == CrowdPreference.QUIET) {
            long quiet = stops.stream().filter(s -> s.congestion().level() == CongestionLevel.QUIET).count();
            parts.add(stops.size() + "곳 중 " + quiet + "곳이 도착 시간에 한산");
        } else if (request.crowdPreference() == CrowdPreference.LIVELY) {
            long busy = stops.stream().filter(s -> s.congestion().level() == CongestionLevel.BUSY).count();
            parts.add(stops.size() + "곳 중 " + busy + "곳이 도착 시간에 북적");
        }
        parts.add("총 도보 " + plan.totalWalkMinutes() + "분");
        return String.join(" · ", parts);
    }
}
