package com.capstone.backend.search;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.json.JsonParserFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Gemini 조건 추출 - 최예린
 * - 검색 문장을 Gemini에 보내서 검색 조건(SearchConditions)으로 바꿈
 * - @Primary: 서버가 RuleConditionExtractor 대신 이걸 씀
 * - 키가 없거나 Gemini가 실패하면 RuleConditionExtractor로 예비 처리 (extractedBy = RULE)
 * - API 키는 환경변수 GEMINI_API_KEY (깃허브에 올리지 않기)
 */
@Component
@Primary
public class GeminiConditionExtractor implements ConditionExtractor {

    // =========================================================
    // 1. 허용하는 값 (명세 v0.3 코드표 + 블로그 태그 목록)
    //    Gemini가 목록에 없는 값을 주면 버림
    // =========================================================

    static final Set<String> REGIONS = Set.of("SEONGSU", "HONGDAE", "GANGNAM");
    static final Set<String> CATEGORIES = Set.of(
            "FOOD", "CAFE", "CULTURE", "ACTIVITY", "EXPERIENCE", "SHOPPING", "TOUR", "NATURE", "SNACK");
    // 블로그 태그 이름과 똑같이 (최예린 확정)
    static final List<String> ATMOSPHERES = List.of(
            "조용함", "데이트", "단체", "혼자가능", "디저트", "사진", "가성비");
    static final Set<String> CROWDS = Set.of("QUIET", "DEFAULT", "LIVELY");
    static final Set<String> ALLERGIES = Set.of("SHELLFISH", "SEAFOOD", "PEANUT", "MILK", "EGG", "WHEAT");
    static final Set<String> GENDERS = Set.of("F", "M");
    static final Set<String> AGES = Set.of("10s", "20s", "30s", "40s", "50s", "60s");
    static final Set<String> COMPANIONS = Set.of("FRIEND", "COUPLE", "FAMILY", "COWORKER", "SOLO");

    private static final String URL =
            "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent";

    private final RuleConditionExtractor rule;
    private final String apiKey;
    private final String model;
    private final RestClient http;

    public GeminiConditionExtractor(RuleConditionExtractor rule,
                                    @Value("${GEMINI_API_KEY:}") String apiKey,
                                    @Value("${GEMINI_MODEL:gemini-3.5-flash-lite}") String model) {
        this.rule = rule;
        this.apiKey = apiKey;
        this.model = model;

        // Gemini가 오래 걸리면 검색이 멈추니까 5초 넘으면 포기 → 규칙 기반으로
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(3));
        factory.setReadTimeout(Duration.ofSeconds(60));
        this.http = RestClient.builder().requestFactory(factory).build();
    }

    // =========================================================
    // 2. 서버가 부르는 곳
    // =========================================================

    @Override
    public SearchConditions extract(String query, LocalDateTime now) {
        // 키가 없으면 바로 규칙 기반으로
        if (apiKey == null || apiKey.isBlank()) {
            return rule.extract(query, now);
        }
        try {
            return callGemini(query, now);
        } catch (Exception e) {
            // Gemini가 실패하면 규칙 기반으로 (서버 로그에 이유만 남김)
            Throwable root = e;
            while (root.getCause() != null) root = root.getCause();
            System.out.println("[Gemini 실패 → RULE] " + e.getMessage()
                    + " / 진짜 이유: " + root.getClass().getSimpleName() + " " + root.getMessage());
            return rule.extract(query, now);
        }
    }

    // =========================================================
    // 3. Gemini 호출
    // =========================================================

    @SuppressWarnings("unchecked")
    private SearchConditions callGemini(String query, LocalDateTime now) {
        Map<String, Object> body = Map.of(
                "systemInstruction", Map.of("parts", List.of(Map.of("text", prompt(now)))),
                "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", query)))),
                "generationConfig", Map.of(
                        "responseMimeType", "application/json",   // JSON으로만 답하게
                        "temperature", 0));                       // 같은 문장엔 같은 답

        // 답을 글자로 받은 다음 직접 JSON으로 읽음 (꼬리표가 JSON이 아니어도 읽을 수 있게)
        String raw = http.post()
                .uri(String.format(URL, model))
                .header("x-goog-api-key", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(String.class);
        Map<String, Object> response = JsonParserFactory.getJsonParser().parseMap(raw);

        // 응답에서 글자 꺼내기: candidates[0].content.parts[0].text
        List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
        Map<String, Object> content = (Map<String, Object>) candidates.get(0).get("content");
        List<Map<String, Object>> parts = (List<Map<String, Object>>) content.get("parts");
        String text = (String) parts.get(0).get("text");

        Map<String, Object> json = JsonParserFactory.getJsonParser().parseMap(text);
        return toConditions(json, now);
    }

    // =========================================================
    // 4. Gemini한테 보내는 지시문
    // =========================================================

    static String prompt(LocalDateTime now) {
        LocalDate today = now.toLocalDate();

        // "토요일", "다음 주 금요일"을 Gemini가 틀리지 않게 앞으로 14일 날짜를 알려줌
        StringBuilder calendar = new StringBuilder();
        for (int i = 0; i < 14; i++) {
            LocalDate d = today.plusDays(i);
            calendar.append(d).append(" (")
                    .append(d.getDayOfWeek().getDisplayName(TextStyle.SHORT, Locale.KOREAN))
                    .append(")")
                    .append(i == 0 ? " 오늘" : i == 1 ? " 내일" : i == 2 ? " 모레" : "")
                    .append("\n");
        }

        return """
                너는 장소 추천 앱 '오디가'의 검색 조건 추출기야.
                사용자의 검색 문장을 읽고 아래 JSON 형식으로만 답해. 설명은 쓰지 마.
                문장에 없는 값은 지어내지 말고 null(목록은 [])로 둬.

                현재 시각: %s

                [날짜표] 요일·"내일"·"이번 주말" 같은 말은 이 표에서 골라서 YYYY-MM-DD로
                %s
                - 그냥 "토요일"은 가장 가까운 토요일(오늘이 토요일이면 오늘), "다음 주 토요일"은 그다음 주
                - "주말"은 가장 가까운 토요일, "평일"은 가장 가까운 평일
                - 날짜 말이 없으면 null

                [JSON 형식]
                {
                  "region": 지역 코드 또는 null,
                  "date": "YYYY-MM-DD" 또는 null,
                  "startTime": "HH:MM"(24시간) 또는 null,
                  "partySize": 사람 수(숫자) 또는 null,
                  "categories": [카테고리 코드],
                  "atmospheres": [분위기 태그],
                  "crowdPreference": "QUIET" / "DEFAULT" / "LIVELY",
                  "allergies": [알레르기 코드],
                  "gender": "F" / "M" / null,
                  "ageGroup": "10s"~"60s" / null,
                  "companionType": 동행 코드 또는 null,
                  "excludedFoods": [빼고 싶은 음식 단어]
                }

                [코드표] 반드시 이 값만 써
                - region: SEONGSU(성수·서울숲·뚝섬), HONGDAE(홍대·연남·합정·상수), GANGNAM(강남·역삼·신논현)
                  다른 지역(이태원, 잠실 등)이거나 지역 말이 없으면 null
                - categories: FOOD(밥·식당·맛집·술집), CAFE(카페·커피), SNACK(빵·베이커리·디저트 가게·간식),
                  ACTIVITY(방탈출·보드게임·노래방·오락실·만화카페), CULTURE(전시·미술관·공연),
                  EXPERIENCE(공방·원데이클래스), SHOPPING(쇼핑·소품샵·편집샵), NATURE(공원·산책), TOUR(관광 명소)
                - atmospheres: %s 중에서만. 비슷한 말은 이 이름으로 바꿔
                  (예: "조용한" → "조용함", "여자친구랑" → "데이트", "회식" → "단체", "혼밥" → "혼자가능",
                   "인스타 감성" → "사진", "싼 곳" → "가성비")
                - crowdPreference: 한적한·사람 적은 곳 → QUIET, 북적이는·활기찬·핫한 곳 → LIVELY, 말 없으면 DEFAULT
                - allergies: SHELLFISH(갑각류·새우·게), SEAFOOD(해산물·생선), PEANUT(땅콩·견과),
                  MILK(우유·유제품), EGG(계란), WHEAT(밀가루·글루텐)
                  "알레르기", "못 먹어"처럼 먹으면 안 된다고 할 때만
                - companionType: FRIEND(친구), COUPLE(연인·남자친구·여자친구·데이트), FAMILY(가족·부모님),
                  COWORKER(회사·동기·팀원), SOLO(혼자)
                - gender: 사용자 일행의 성별이 문장에 있을 때만 ("여자 둘이" → F). "여자친구랑"은 성별 아님
                - ageGroup: "20대" → "20s", "대학생" → "20s"
                - partySize: "둘이" → 2, "혼자" → 1, "친구랑"(나+친구) → 2, "4명" → 4
                - startTime: "3시" → "15:00"(1~8시는 오후로), "저녁" → "18:00", "점심" → "12:00"
                - excludedFoods: "매운 거 말고" → ["매운"], "고기 빼고" → ["고기"]
                """.formatted(now.withNano(0), calendar, String.join(", ", ATMOSPHERES));
    }

    // =========================================================
    // 5. Gemini 결과 검사 → SearchConditions
    //    목록에 없는 값은 버리고, 날짜·시간 모양이 이상하면 null
    // =========================================================

    static SearchConditions toConditions(Map<String, Object> j, LocalDateTime now) {
        String date = validDate(j.get("date"));
        String dayType = date == null ? null : RuleConditionExtractor.dayType(LocalDate.parse(date));

        String companion = pick(j.get("companionType"), COMPANIONS);
        List<String> moods = pickList(j.get("atmospheres"), Set.copyOf(ATMOSPHERES));
        // 명세: 연인이면 '데이트' 분위기 자동 추가
        if ("COUPLE".equals(companion) && !moods.contains("데이트")) {
            moods.add("데이트");
        }

        return new SearchConditions(
                pick(j.get("region"), REGIONS),
                date,
                dayType,
                validTime(j.get("startTime")),
                validPartySize(j.get("partySize")),
                pickList(j.get("categories"), CATEGORIES),
                moods,
                pick(j.get("crowdPreference"), CROWDS),
                pickList(j.get("allergies"), ALLERGIES),
                pick(j.get("gender"), GENDERS),
                pick(j.get("ageGroup"), AGES),
                companion,
                stringList(j.get("excludedFoods")),
                "GEMINI");
    }

    private static String pick(Object value, Set<String> allowed) {
        return value instanceof String s && allowed.contains(s) ? s : null;
    }

    private static List<String> pickList(Object value, Set<String> allowed) {
        List<String> out = new ArrayList<>();
        if (value instanceof List<?> list) {
            for (Object o : list) {
                if (o instanceof String s && allowed.contains(s) && !out.contains(s)) {
                    out.add(s);
                }
            }
        }
        return out;
    }

    private static List<String> stringList(Object value) {
        List<String> out = new ArrayList<>();
        if (value instanceof List<?> list) {
            for (Object o : list) {
                if (o instanceof String s && !s.isBlank() && !out.contains(s.trim())) {
                    out.add(s.trim());
                }
            }
        }
        return out;
    }

    private static String validDate(Object value) {
        if (!(value instanceof String s)) return null;
        try {
            return LocalDate.parse(s).toString();
        } catch (Exception e) {
            return null;
        }
    }

    private static String validTime(Object value) {
        if (!(value instanceof String s) || !s.matches("\\d{1,2}:\\d{2}")) return null;
        String[] p = s.split(":");
        int h = Integer.parseInt(p[0]);
        int m = Integer.parseInt(p[1]);
        return h <= 23 && m <= 59 ? String.format("%02d:%02d", h, m) : null;
    }

    private static Integer validPartySize(Object value) {
        if (!(value instanceof Number n)) return null;
        int size = n.intValue();
        return size >= 1 && size <= 30 ? size : null;
    }
}
