package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 코스 제목·추천 이유 (규칙 기반)
 * - 제목: {지역} {시간대} {놀거리 종류} 코스 (예: 성수 오후 노래방 코스)
 * - 추천 이유: 분위기 태그 맞는 곳 수 · 혼잡 선호에 맞는 곳 수 · 총 도보 시간
 * - 경로 이름(route, 11주차): 장소 종류를 이어서 "칵테일바 → 카페 → 방탈출" (제목 밑 태그, 감성 제목은 회의 후)
 */
public final class CourseText {

    private CourseText() {
    }

    // 카카오 카테고리 이름 → 제목에 쓸 이름
    private static final Map<String, String> PLAY_LABEL = Map.ofEntries(
            Map.entry("미술,공예", "공방"), Map.entry("화랑", "전시"), Map.entry("보드카페", "보드게임"),
            Map.entry("방탈출카페", "방탈출"), Map.entry("만화방", "만화카페"),
            // 쇼핑: 카카오 분류 그대로 쓰면 "인테리어장식판매 코스"처럼 어색해서 사람이 쓰는 말로 (예민 11/13)
            Map.entry("인테리어장식판매", "소품샵"), Map.entry("디자인문구", "소품샵"), Map.entry("생활용품점", "소품샵"),
            Map.entry("문구,사무용품", "문구점"), Map.entry("의류판매", "옷 구경"), Map.entry("패션잡화점", "편집숍"),
            Map.entry("공연장,연극극장", "공연"), Map.entry("전시관", "전시"), Map.entry("미술관", "전시"));

    // 카카오 술집 종류 → 경로 이름
    private static final Map<String, String> BAR_LABEL = Map.of(
            "호프,요리주점", "호프", "일본식주점", "이자카야", "실내포장마차", "포차");

    /** 경로 이름: 장소 종류를 → 로 이어서 (예: 칵테일바 → 카페 → 방탈출) */
    public static String route(CoursePlan plan, Map<String, CoursePlace> placesById) {
        List<String> labels = new ArrayList<>();
        for (CoursePlan.Stop s : plan.stops()) {
            CoursePlace p = placesById.get(s.placeId());
            labels.add(p == null ? s.name() : stopLabel(p));
        }
        return String.join(" → ", labels);
    }

    /** 장소 하나의 종류 이름: 술집은 술집 종류, 식당은 세부·큰 종류, 카페는 테마카페면 종류, 놀거리는 카카오 종류 */
    public static String stopLabel(CoursePlace p) {
        String[] parts = p.kakaoCategory().split(" > ");
        if (p.isBar()) {
            return parts.length > 2 ? BAR_LABEL.getOrDefault(parts[2], parts[2].replace(',', '·')) : "술집";
        }
        return switch (p.category()) {
            case "FOOD" -> p.cuisineDetail() != null ? p.cuisineDetail()
                    : (p.cuisine() != null && !p.cuisine().equals("ETC")) ? Cuisine.LABEL.get(p.cuisine())
                    : parts.length > 1 ? parts[1].replace(',', '·') : "식당";
            case "CAFE" -> p.kakaoCategory().contains("테마카페") ? playLabel(p.kakaoCategory()) : "카페";
            case "SNACK" -> "디저트";
            default -> playLabel(p.kakaoCategory());
        };
    }

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

    /**
     * 코스 키워드 태그 (최대 4개, v0.5) - 예령 추천 리스트용
     * 원하는 분위기 중 2곳 이상 태그 있는 것 → 한산/북적(2곳 이상) → 식사 음식 종류(세부 우선) → 도보 5분 이내
     */
    public static List<String> keywords(CoursePlan plan, CourseRequest request, Map<String, CoursePlace> placesById) {
        List<String> out = new ArrayList<>();
        List<CoursePlan.Stop> stops = plan.stops();
        for (String mood : request.atmospheres() == null ? List.<String>of() : request.atmospheres()) {
            long n = stops.stream().filter(s -> placesById.get(s.placeId()).tags().contains(mood)).count();
            if (n >= 2) out.add(mood);
        }
        long quiet = stops.stream().filter(s -> s.congestion().level() == CongestionLevel.QUIET).count();
        long busy = stops.stream().filter(s -> s.congestion().level() == CongestionLevel.BUSY).count();
        if (quiet >= 2) out.add("한산");
        else if (busy >= 2) out.add("북적");
        stops.stream().filter(s -> s.slot() == Slot.MEAL).findFirst()
                .map(s -> placesById.get(s.placeId()))
                .filter(p -> p.cuisine() != null && !p.cuisine().equals("ETC"))
                .ifPresent(p -> out.add(p.cuisineDetail() != null ? p.cuisineDetail() : Cuisine.LABEL.get(p.cuisine())));
        if (plan.totalWalkMinutes() <= 5) out.add("도보 5분 이내");
        return List.copyOf(out.subList(0, Math.min(4, out.size())));
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
