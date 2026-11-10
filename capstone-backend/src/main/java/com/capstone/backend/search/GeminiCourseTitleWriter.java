package com.capstone.backend.search;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.json.JsonParserFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Gemini 코스 감성 제목 (11주차) - 서버 연결 김예민, 지시문은 최예린이 다듬을 예정 (PROMPT만 바꾸면 됨)
 * - 검색 한 번에 Gemini 1번: 코스 최대 10개를 묶어서 보냄
 * - 4초 안에 답 없거나 이상하면 null → 규칙 제목 그대로 (검색은 안 깨짐)
 * - 보내는 것: 지역, 요일·시간, 분위기, 경로 이름, 키워드 (사용자 문장·개인정보·LG 데이터는 안 보냄)
 * - 키: GEMINI_API_KEY (조건 추출이랑 같은 키), 끄고 싶으면 GEMINI_TITLES=false
 */
@Component
public class GeminiCourseTitleWriter implements CourseTitleWriter {

    static final int MAX_LENGTH = 25;     // 지시문은 20자, 조금 넘는 건 봐줌
    private static final String URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent";

    // ---------- 지시문 (@최예린 여기만 고치면 돼) ----------
    static final String PROMPT = """
            너는 서울 성수·홍대·강남 코스 추천 앱 '오디가'의 카피라이터야.
            입력으로 코스 목록이 번호와 함께 와. 코스마다 감성적인 한국어 제목을 하나씩 지어.

            규칙
            - 20자 이내, 한 줄, 이모지·따옴표·느낌표 여러 개 금지
            - 입력에 있는 정보(지역, 요일·시간, 분위기, 경로, 키워드)만 써. 없는 사실 지어내지 마
              (나쁜 예: "성수 맛집 1위 코스", "인스타 핫플 총정리", "비 오는 날" ← 날씨 정보 없음)
            - 가게 이름은 넣지 마
            - 코스끼리 제목이 겹치지 않게
            - 좋은 예: "조용한 오후, 성수 전시 산책", "홍대 밤, 1차는 이자카야", "토요일 낮 소품샵 구경 코스"

            JSON으로만 답해: {"titles": ["1번 제목", "2번 제목", ...]} (입력 순서 그대로, 개수 똑같이)
            """;

    private final String apiKey;
    private final String model;
    private final boolean enabled;
    private final RestClient http;

    public GeminiCourseTitleWriter(@Value("${GEMINI_API_KEY:}") String apiKey,
                                   @Value("${GEMINI_MODEL:gemini-3.5-flash-lite}") String model,
                                   @Value("${GEMINI_TITLES:true}") boolean enabled) {
        this.apiKey = apiKey;
        this.model = model;
        this.enabled = enabled;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(2));
        factory.setReadTimeout(Duration.ofSeconds(4));
        this.http = RestClient.builder().requestFactory(factory).build();
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<String> titles(List<Input> courses) {
        if (!enabled || apiKey == null || apiKey.isBlank() || courses.isEmpty()) return null;
        try {
            Map<String, Object> body = Map.of(
                    "systemInstruction", Map.of("parts", List.of(Map.of("text", PROMPT))),
                    "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", userText(courses))))),
                    "generationConfig", Map.of("responseMimeType", "application/json", "temperature", 0.7));
            String raw = http.post()
                    .uri(String.format(URL, model))
                    .header("x-goog-api-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(String.class);
            Map<String, Object> response = JsonParserFactory.getJsonParser().parseMap(raw);
            List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
            Map<String, Object> content = (Map<String, Object>) candidates.get(0).get("content");
            List<Map<String, Object>> parts = (List<Map<String, Object>>) content.get("parts");
            String text = (String) parts.get(0).get("text");
            return clean(JsonParserFactory.getJsonParser().parseMap(text).get("titles"), courses.size());
        } catch (RuntimeException e) {
            System.out.println("[감성 제목 실패 → 규칙 제목] " + e.getClass().getSimpleName());
            return null;
        }
    }

    /** "1. 지역: 성수 / 언제: 토요일 오후 3시 / 분위기: 조용한, 데이트 / 경로: 전시관 → 카페 → 분식 / 키워드: 한산" */
    static String userText(List<Input> courses) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < courses.size(); i++) {
            Input c = courses.get(i);
            b.append(i + 1).append(". 지역: ").append(c.region())
                    .append(" / 언제: ").append(c.when())
                    .append(" / 분위기: ").append(c.moods().isEmpty() ? "없음" : String.join(", ", c.moods()))
                    .append(" / 경로: ").append(c.route())
                    .append(" / 키워드: ").append(String.join(", ", c.keywords()))
                    .append('\n');
        }
        return b.toString();
    }

    /** 개수 안 맞으면 전부 버림, 이상한 제목(빈 것·너무 긴 것·줄바꿈)은 그 자리만 null */
    static List<String> clean(Object value, int size) {
        if (!(value instanceof List<?> list) || list.size() != size) return null;
        List<String> out = new ArrayList<>();
        for (Object o : list) {
            String t = o instanceof String s ? s.strip().replaceAll("^[\"'“”]+|[\"'“”]+$", "") : "";
            out.add(t.isEmpty() || t.length() > MAX_LENGTH || t.contains("\n") ? null : t);
        }
        return out;
    }
}
