package com.capstone.backend.course;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 놀거리 세부 취향 (11주차) - 김예민
 * - "보드게임하면서 놀고 싶어"처럼 놀거리 종류를 콕 집으면 모든 코스에 그 종류 장소를 하나 꼭 넣음
 *   (음식의 세부 취향 cuisineDetails처럼, 놀거리는 큰 종류 ACTIVITY 안에 오락실·노래방·보드게임이 다 섞여 있어서)
 * - 장소가 그 종류인지: 카카오 카테고리나 가게 이름에 아래 단어가 있으면
 */
public final class PlayDetail {

    private PlayDetail() {
    }

    /** 세부 이름 → 장소 카카오 카테고리·이름에서 찾을 단어 */
    public static final Map<String, List<String>> PLACE_WORDS = new LinkedHashMap<>();
    /** 세부 이름 → 문장에서 찾을 단어 */
    public static final Map<String, List<String>> SENTENCE_WORDS = new LinkedHashMap<>();

    private static void add(String detail, List<String> placeWords, List<String> sentenceWords) {
        PLACE_WORDS.put(detail, placeWords);
        SENTENCE_WORDS.put(detail, sentenceWords);
    }

    static {
        add("보드게임", List.of("보드카페", "보드게임"), List.of("보드게임", "보드 게임", "보드카페"));
        add("방탈출", List.of("방탈출"), List.of("방탈출"));
        add("노래방", List.of("노래방", "노래연습장"), List.of("노래방", "코인노래", "코노"));
        add("볼링", List.of("볼링"), List.of("볼링"));
        add("오락실", List.of("오락실"), List.of("오락실"));
        add("만화카페", List.of("만화카페", "벌툰", "놀숲"), List.of("만화카페", "만화방"));
        add("클라이밍", List.of("클라이밍"), List.of("클라이밍"));
        add("사주·타로", List.of("사주카페", "타로"), List.of("사주", "타로"));
        add("고양이카페", List.of("고양이카페"), List.of("고양이카페", "고양이 카페"));
        add("공방", List.of("공예", "공방", "도자기"), List.of("공방", "원데이클래스", "원데이 클래스", "도자기"));
        add("전시", List.of("전시관", "미술관", "화랑", "갤러리"), List.of("전시", "미술관", "갤러리"));
        add("공연", List.of("공연장", "연극"), List.of("연극", "공연", "뮤지컬"));
        add("영화", List.of("영화관"), List.of("영화"));
        add("사격", List.of("사격"), List.of("사격"));
        add("탁구", List.of("탁구"), List.of("탁구"));
        add("소품샵", List.of("생활용품점", "인테리어장식", "디자인문구", "아트박스"), List.of("소품샵", "소품 샵"));
    }

    /** 문장 속 세부 취향 (빼는 말은 지운 문장을 넣기) */
    public static List<String> find(String text) {
        return SENTENCE_WORDS.entrySet().stream()
                .filter(e -> e.getValue().stream().anyMatch(text::contains))
                .map(Map.Entry::getKey)
                .toList();
    }

    /** 장소가 이 세부 중 하나인지 */
    public static boolean matches(CoursePlace p, List<String> details) {
        String text = p.kakaoCategory() + " " + p.name();
        return details.stream().anyMatch(d -> PLACE_WORDS.getOrDefault(d, List.of()).stream().anyMatch(text::contains));
    }
}
