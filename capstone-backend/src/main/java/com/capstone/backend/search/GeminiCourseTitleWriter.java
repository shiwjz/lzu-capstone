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
 * Gemini 코스 감성 제목 (11주차) - 서버 연결 김예민, 지시문 최예린 (좋은 예·나쁜 예 10개씩, 지어내기·과장 금지)
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

            [입력 칸 뜻]
            - 지역: 성수 / 홍대 / 강남
            - 언제: 요일·시간 (예: 토요일 오후 3시)
            - 분위기: 사용자가 고른 분위기 (조용한·활기찬·감성적인·가성비좋은·넓고편한·뷰좋은)와
              상황 (데이트·단체·혼자·아이)
            - 경로: 코스 장소 종류 순서 (예: 이자카야 → 칵테일바)
            - 키워드: 코스 특징 (분위기 태그, 한산/북적, 음식 종류, 도보 5분 이내)

            [규칙]
            1. 15자 안팎, 길어도 20자 이내(띄어쓰기 포함), 한 줄. 이모지·따옴표·느낌표·해시태그·숫자 금지
            2. 입력에 있는 정보만 써. 없는 사실은 절대 지어내지 마
               - 날씨(비·눈·햇살), 계절, 기념일, 가격·순위("1위", "가성비 끝판왕"), 웨이팅 여부는 입력에 없으면 금지
               - "야경", "노을", "뷰"는 분위기에 뷰좋은이 있을 때만, "밤"은 언제가 밤 9시 이후일 때만
               - 키워드가 '북적'이면 "조용한·한적한", '한산'이면 "북적이는·핫한"처럼 반대로 쓰지 마
            3. 가게 이름은 넣지 마. 장소는 종류로만 (이자카야, 전시, 보드게임)
            4. 과장 금지: 최고, 완벽한, 인생, 무조건, 레전드, 끝판왕, 꿀잼
            5. 경로에서 가장 특징 있는 장소 하나(많아야 둘)만 골라 + (요일·시간대 / 분위기 / 지역 중 1~2개)를 엮어
               - "A와 B와 C"처럼 장소를 나열하지 말고, "전시 보고", "한잔"처럼 하는 일로 풀어
               - 장소를 둘 쓰면 경로 순서대로
            8. 분위기·키워드 이름을 그대로 붙여 넣지 마. 뜻만 자연스럽게 살리거나 빼
               (도보 5분 이내 → "가까이 걷는"·생략, 넓고편한 → "여유로운", 가성비좋은 → "부담 없는",
                뷰좋은 → "전망 좋은"·"야경", 감성적인 → "분위기 있는")
            9. 시간은 숫자 말고 요일이나 시간대 말로 (오전·점심·오후·저녁·밤)
            6. 코스끼리 제목이 겹치지 않게, 문장 모양도 섞어 (모두 "~코스"로 끝내지 마)
            7. 자연스러운 우리말로. 단어만 나열하거나 번역투로 쓰지 마

            [좋은 예]
            - 성수 / 토요일 오후 3시 / 조용한 / 전시 → 카페 → 국밥
              → 조용한 토요일, 전시 보고 국밥
            - 홍대 / 금요일 저녁 7시 / 활기찬, 단체 / 고기 → 호프 → 노래방
              → 고기에 노래방까지, 신나는 홍대
            - 강남 / 평일 점심 12시 / 혼자 / 라멘 → 카페
              → 혼자여도 좋은 강남 점심
            - 성수 / 일요일 오후 2시 / 감성적인, 데이트 / 공방 → 디저트카페 → 이탈리안
              → 둘이 만드는 공방 데이트
            - 홍대 / 토요일 오후 1시 / 가성비좋은 / 떡볶이 → 만화카페
              → 떡볶이 먹고 만화카페 직행
            - 강남 / 금요일 밤 9시 / 뷰좋은 / 칵테일바 → 와인바
              → 강남 야경과 칵테일 한잔
            - 성수 / 토요일 오전 11시 / 넓고편한 / 카페 → 소품샵 → 이탈리안
              → 넉넉한 카페에서 여는 성수 오전
            - 홍대 / 일요일 오후 4시 / 아이 / 체험 공방 → 카페 → 돈까스·우동
              → 아이랑 공방, 그리고 돈까스
            - 강남 / 수요일 저녁 6시 / 조용한, 데이트 / 초밥·롤 → 와인바
              → 조용히 스시, 이어서 와인
            - 성수 / 토요일 저녁 6시 / 키워드 한산 / 고기 → 이자카야 → 이자카야
              → 한산한 저녁, 고기에서 이자카야로

            [나쁜 예]
            - "성수 맛집 1위 코스" → 순위는 입력에 없음
            - "비 오는 날 홍대 실내 데이트" → 날씨 정보 없음
            - "도보 5분 이내 이탈리안과 와인바" → 키워드를 그대로 붙여 넣음, 장소 나열
            - "○○식당에서 시작하는 코스" → 가게 이름 금지
            - "인생 맛집 투어 끝판왕" → 과장
            - "성수 오후 전시 카페 국밥 코스" → 단어만 나열
            - "북적이는 홍대의 조용한 밤" → 서로 반대되는 말, 키워드와도 안 맞음
            - "웨이팅 없는 강남 라멘" → 웨이팅 정보 없음
            - "감성적인 소품샵과 고기" → 분위기 이름 그대로 + 장소 나열, 어색함
            - "밤 9시 활기찬 포차와 칵테일바" → 시간 숫자, 경로 순서(칵테일바 → 포차)를 뒤집음

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