package com.capstone.backend.course;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 음식 취향 (v0.5, 10/31 회의) - 김예민
 * - 큰 종류(cuisine) = 식사 칸 거르기, 세부(detail) = 사용자 요구 점수 가점
 * - 장소별 큰 종류·세부는 resources/data/places.tsv (generate_mocks.py: 예린 place_cuisine.csv 있으면 그걸, 없으면 임시 분류)
 * - 이름·목록은 예린 확정본 나오면 여기 + generate_mocks.py 같이 바꾸기
 */
public final class Cuisine {

    private Cuisine() {
    }

    /** 큰 종류 코드 → 화면 이름 (CAFE·ETC는 거르기 코드로는 안 받음) */
    public static final Map<String, String> LABEL = ordered(
            "KOREAN", "한식", "JAPANESE", "일식", "WESTERN", "양식", "CHINESE", "중식", "BUNSIK", "분식",
            "ASIAN", "아시아", "CHICKEN", "치킨", "BAR", "술집", "CAFE", "카페", "ETC", "기타");

    /** 검색 조건 cuisines로 받는 코드 (식사 칸 거르기용) */
    public static final Set<String> FILTER_CODES = Set.of(
            "KOREAN", "JAPANESE", "WESTERN", "CHINESE", "BUNSIK", "ASIAN", "CHICKEN", "BAR");

    /** 세부 → 큰 종류 */
    public static final Map<String, String> DETAIL_FAMILY = Map.ofEntries(
            Map.entry("고기", "KOREAN"), Map.entry("국밥", "KOREAN"), Map.entry("찌개·전골", "KOREAN"),
            Map.entry("국수", "KOREAN"), Map.entry("해물·생선", "KOREAN"),
            Map.entry("초밥·롤", "JAPANESE"), Map.entry("라멘", "JAPANESE"), Map.entry("돈까스·우동", "JAPANESE"),
            Map.entry("덮밥", "JAPANESE"),
            Map.entry("이탈리안", "WESTERN"), Map.entry("피자", "WESTERN"), Map.entry("햄버거", "WESTERN"),
            Map.entry("스테이크", "WESTERN"), Map.entry("멕시칸", "WESTERN"),
            Map.entry("중국요리", "CHINESE"), Map.entry("양꼬치", "CHINESE"),
            Map.entry("떡볶이", "BUNSIK"), Map.entry("김밥", "BUNSIK"),
            Map.entry("동남아", "ASIAN"), Map.entry("인도", "ASIAN"),
            Map.entry("호프·요리주점", "BAR"), Map.entry("이자카야", "BAR"), Map.entry("칵테일바", "BAR"),
            Map.entry("와인바", "BAR"), Map.entry("포장마차", "BAR"),
            Map.entry("디저트카페", "CAFE"), Map.entry("개인카페", "CAFE"), Map.entry("프랜차이즈", "CAFE"),
            Map.entry("갤러리·북카페", "CAFE"), Map.entry("차·음료", "CAFE"));

    /** 식사 칸 거르기: 큰 종류 골랐으면 음식점은 그 종류만 (카페·놀거리는 상관없음) */
    public static boolean wanted(CoursePlace place, List<String> cuisines) {
        return cuisines == null || cuisines.isEmpty() || !place.category().equals("FOOD")
                || cuisines.contains(place.cuisine());
    }

    /**
     * 세부 취향 가점: 딱 맞음 1.0 / 같은 큰 종류인데 세부 없음 0.5 / 같은 큰 종류인데 다른 세부 0.2 / 해당 없음 null
     * - 사용자가 고른 세부가 속한 큰 종류에서만 판단 (일식 세부만 골랐으면 카페는 계산 안 함)
     */
    public static Double detailFit(String placeCuisine, String placeDetail, List<String> wanted) {
        if (wanted == null || wanted.isEmpty() || placeCuisine == null) return null;
        boolean family = wanted.stream().anyMatch(d -> placeCuisine.equals(DETAIL_FAMILY.get(d)));
        if (!family) return null;
        if (placeDetail != null && wanted.contains(placeDetail)) return 1.0;
        return placeDetail == null ? 0.5 : 0.2;
    }

    private static Map<String, String> ordered(String... kv) {
        Map<String, String> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) m.put(kv[i], kv[i + 1]);
        return java.util.Collections.unmodifiableMap(m);
    }
}
