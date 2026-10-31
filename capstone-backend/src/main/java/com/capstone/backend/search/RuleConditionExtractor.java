package com.capstone.backend.search;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 규칙 기반 조건 추출 - 김예민
 * - Gemini 붙기 전 임시 + Gemini 오류 때 예비용 (명세 extractedBy = RULE)
 * - 키워드 사전 방식이라 모르는 표현은 못 잡음 → 못 잡은 값은 null, 서버가 기본값 채움
 * - 단어 추가는 아래 사전에만 하면 됨 (@최예린 태그 사전 확정되면 분위기 단어 맞추기)
 */
@Component
public class RuleConditionExtractor implements ConditionExtractor {

    // 지역 (먼저 나온 단어 기준)
    private static final Map<String, String> REGION_WORDS = ordered(
            "성수", "SEONGSU", "서울숲", "SEONGSU", "뚝섬", "SEONGSU",
            "홍대", "HONGDAE", "연남", "HONGDAE", "합정", "HONGDAE", "상수", "HONGDAE", "홍익", "HONGDAE",
            "강남", "GANGNAM", "신논현", "GANGNAM", "역삼", "GANGNAM");

    // 카테고리 (놀거리 테마카페는 카페로 안 잡히게 먼저 지움)
    private static final List<String> PLAY_CAFE = List.of("만화카페", "보드게임카페", "방탈출카페", "보드카페");
    private static final Map<String, List<String>> CATEGORY_WORDS = orderedList(
            "CAFE", List.of("카페", "커피", "디저트"),
            "FOOD", List.of("밥", "식사", "맛집", "먹", "식당", "술 한잔", "고기"),
            "ACTIVITY", List.of("놀", "노래방", "방탈출", "보드게임", "오락실", "만화카페", "볼링"),
            "CULTURE", List.of("전시", "미술관", "박물관", "갤러리", "공연"),
            "EXPERIENCE", List.of("공방", "클래스", "체험", "원데이"),
            "SHOPPING", List.of("쇼핑", "소품샵", "편집샵", "구경"),
            "NATURE", List.of("산책", "공원", "한강", "숲"),
            "TOUR", List.of("명소", "관광"));

    // 분위기 = 예린 블로그 태그 이름 그대로 (tag_dictionary.py 7개: 조용함·데이트·단체·혼자가능·디저트·사진·가성비)
    private static final Map<String, List<String>> MOOD_WORDS = orderedList(
            "조용함", List.of("조용", "한적", "여유", "차분", "시끄럽지 않", "안 시끄", "덜 붐", "사람 적"),
            "디저트", List.of("디저트", "케이크", "빵"),
            "사진", List.of("사진", "인스타", "감성", "예쁜", "포토"),
            "데이트", List.of("데이트", "남자친구", "여자친구", "남친", "여친", "애인", "연인"),
            "단체", List.of("단체", "모임", "회식", "동기", "동료"),
            "가성비", List.of("가성비", "저렴", "싼 "),
            "혼자가능", List.of("혼밥", "혼자", "혼카페"));

    private static final List<String> QUIET_WORDS = MOOD_WORDS.get("조용함");
    private static final List<String> LIVELY_WORDS = List.of("신나", "활기", "사람 많", "북적", "핫한", "시끌", "힙한");

    // 알레르기 (문장에 '알레르기·알러지·못 먹'이 있을 때만)
    private static final Map<String, List<String>> ALLERGY_WORDS = orderedList(
            "SHELLFISH", List.of("갑각류", "새우", "꽃게", "대게", "랍스터", "게 알레르기"),
            "SEAFOOD", List.of("해산물", "생선", "해물"),
            "PEANUT", List.of("땅콩", "견과"),
            "MILK", List.of("우유", "유제품", "유당"),
            "EGG", List.of("계란", "달걀"),
            "WHEAT", List.of("밀가루", "글루텐", "밀 알레르기"));

    // 제외 음식 ("매운 거 말고", "고기 빼고")
    private static final List<String> FOOD_WORDS = List.of(
            "매운", "고기", "해산물", "회", "생선", "술", "면", "밀가루", "튀김", "양식", "중식", "일식", "한식");
    private static final Pattern EXCLUDE = Pattern.compile("([가-힣]+)\\s*(?:거|것|음식)?\\s*(?:은|는)?\\s*(?:빼고|말고|제외|싫어)");

    private static final Map<String, DayOfWeek> DAYS = ordered(
            "월요일", DayOfWeek.MONDAY, "화요일", DayOfWeek.TUESDAY, "수요일", DayOfWeek.WEDNESDAY,
            "목요일", DayOfWeek.THURSDAY, "금요일", DayOfWeek.FRIDAY, "토요일", DayOfWeek.SATURDAY,
            "일요일", DayOfWeek.SUNDAY, "토욜", DayOfWeek.SATURDAY, "일욜", DayOfWeek.SUNDAY);

    private static final Pattern CLOCK = Pattern.compile("(\\d{1,2}):(\\d{2})");
    private static final Pattern HOUR = Pattern.compile("(새벽|아침|오전|점심|오후|저녁|밤)?\\s*(\\d{1,2})\\s*시(?!간)\\s*(반|(\\d{1,2})\\s*분)?");
    private static final Map<String, String> PERIOD_DEFAULT = ordered(
            "아침", "09:00", "오전", "10:00", "점심", "12:00", "오후", "14:00", "저녁", "18:00", "밤", "20:00");
    private static final Pattern PEOPLE = Pattern.compile("(\\d{1,2})\\s*(?:명|인)");
    private static final Map<String, Integer> PEOPLE_WORDS = ordered(
            "혼자", 1, "둘이", 2, "두 명", 2, "두명", 2, "셋이", 3, "세 명", 3, "세명", 3,
            "넷이", 4, "네 명", 4, "네명", 4, "다섯", 5);
    private static final Pattern AGE = Pattern.compile("([1-6])0대");

    @Override
    public SearchConditions extract(String query, LocalDateTime now) {
        String q = query == null ? "" : query;
        LocalDate date = date(q, now.toLocalDate());
        String companion = companion(q);
        Integer people = people(q, companion);
        List<String> moods = firstAppearance(q, MOOD_WORDS);
        if ("COUPLE".equals(companion) && !moods.contains("데이트")) {
            moods.add("데이트");
        }
        String crowd = anyOf(q, QUIET_WORDS) ? "QUIET" : anyOf(q, LIVELY_WORDS) ? "LIVELY" : "DEFAULT";

        String categoryText = q;
        for (String w : PLAY_CAFE) {
            categoryText = categoryText.replace(w, " 놀거리 ");
        }
        return new SearchConditions(
                firstOf(q, REGION_WORDS),
                date.toString(),
                dayType(date),
                time(q),
                people,
                firstAppearance(categoryText, CATEGORY_WORDS),
                moods,
                crowd,
                allergies(q),
                gender(q),
                age(q),
                companion,
                excludedFoods(q),
                "RULE");
    }

    public static String dayType(LocalDate date) {
        DayOfWeek d = date.getDayOfWeek();
        return d == DayOfWeek.SATURDAY || d == DayOfWeek.SUNDAY ? "WEEKEND" : "WEEKDAY";
    }

    private static LocalDate date(String q, LocalDate today) {
        if (q.contains("모레")) return today.plusDays(2);
        if (q.contains("내일")) return today.plusDays(1);
        if (q.contains("오늘")) return today;
        boolean nextWeek = q.contains("다음 주") || q.contains("다음주");
        int best = Integer.MAX_VALUE;
        DayOfWeek day = null;
        for (Map.Entry<String, DayOfWeek> e : DAYS.entrySet()) {
            int i = q.indexOf(e.getKey());
            if (i >= 0 && i < best) {
                best = i;
                day = e.getValue();
            }
        }
        if (day != null) {
            LocalDate d = today.with(TemporalAdjusters.nextOrSame(day));
            return nextWeek ? d.plusWeeks(1) : d;
        }
        if (q.contains("주말")) {
            return dayType(today).equals("WEEKEND") ? today : today.with(TemporalAdjusters.next(DayOfWeek.SATURDAY));
        }
        if (q.contains("평일")) {
            return dayType(today).equals("WEEKDAY") ? today : today.with(TemporalAdjusters.next(DayOfWeek.MONDAY));
        }
        return today;
    }

    private static String time(String q) {
        Matcher c = CLOCK.matcher(q);
        if (c.find()) {
            return String.format("%02d:%02d", Integer.parseInt(c.group(1)) % 24, Integer.parseInt(c.group(2)));
        }
        Matcher m = HOUR.matcher(q);
        if (m.find()) {
            String period = m.group(1);
            int h = Integer.parseInt(m.group(2));
            int min = m.group(3) == null ? 0 : m.group(3).equals("반") ? 30 : Integer.parseInt(m.group(4));
            if (period == null) {
                if (h >= 1 && h <= 8) h += 12;            // "3시" → 오후 3시로 봄
            } else if ((period.equals("오후") || period.equals("저녁") || period.equals("밤")) && h < 12) {
                h += 12;
            } else if (period.equals("점심") && h <= 5) {
                h += 12;
            }
            return String.format("%02d:%02d", h % 24, min % 60);
        }
        for (Map.Entry<String, String> e : PERIOD_DEFAULT.entrySet()) {
            if (q.contains(e.getKey())) {
                return e.getValue();
            }
        }
        return null;                                      // 서버가 다음 정시로 채움
    }

    private static String companion(String q) {
        if (anyOf(q, List.of("남자친구", "여자친구", "남친", "여친", "애인", "연인", "데이트"))) return "COUPLE";
        if (anyOf(q, List.of("회사", "동기", "동료", "팀원", "회식"))) return "COWORKER";
        if (anyOf(q, List.of("가족", "엄마", "아빠", "부모님", "동생"))) return "FAMILY";
        if (anyOf(q, List.of("혼자", "혼밥"))) return "SOLO";
        if (q.contains("친구")) return "FRIEND";
        return null;
    }

    private static Integer people(String q, String companion) {
        Matcher m = PEOPLE.matcher(q);
        if (m.find()) {
            return Integer.parseInt(m.group(1));
        }
        for (Map.Entry<String, Integer> e : PEOPLE_WORDS.entrySet()) {
            if (q.contains(e.getKey())) {
                return e.getValue();
            }
        }
        if (companion == null) return null;
        return switch (companion) {
            case "SOLO" -> 1;
            case "COUPLE", "FRIEND" -> 2;     // "친구랑" = 나 + 친구
            default -> null;
        };
    }

    private static List<String> allergies(String q) {
        if (!anyOf(q, List.of("알레르기", "알러지", "못 먹", "못먹"))) {
            return new ArrayList<>();
        }
        return firstAppearance(q, ALLERGY_WORDS);
    }

    private static String gender(String q) {
        String t = q.replace("남자친구", "").replace("여자친구", "");
        if (anyOf(t, List.of("여자", "여성", "여대생"))) return "F";
        if (anyOf(t, List.of("남자", "남성"))) return "M";
        return null;
    }

    private static String age(String q) {
        Matcher m = AGE.matcher(q);
        if (m.find()) return m.group(1) + "0s";
        if (q.contains("대학생")) return "20s";
        if (q.contains("고등학생") || q.contains("중학생")) return "10s";
        return null;
    }

    private static List<String> excludedFoods(String q) {
        List<String> out = new ArrayList<>();
        Matcher m = EXCLUDE.matcher(q);
        while (m.find()) {
            String w = m.group(1);
            for (String food : FOOD_WORDS) {
                if (w.startsWith(food) && !out.contains(food)) {
                    out.add(food);
                }
            }
        }
        return out;
    }

    // ---------- 도우미 ----------

    private static boolean anyOf(String q, List<String> words) {
        return words.stream().anyMatch(q::contains);
    }

    private static String firstOf(String q, Map<String, String> words) {
        int best = Integer.MAX_VALUE;
        String found = null;
        for (Map.Entry<String, String> e : words.entrySet()) {
            int i = q.indexOf(e.getKey());
            if (i >= 0 && i < best) {
                best = i;
                found = e.getValue();
            }
        }
        return found;
    }

    /** 문장에 먼저 나온 순서대로 코드 목록 */
    private static List<String> firstAppearance(String q, Map<String, List<String>> dict) {
        List<Map.Entry<Integer, String>> hits = new ArrayList<>();
        for (Map.Entry<String, List<String>> e : dict.entrySet()) {
            int first = Integer.MAX_VALUE;
            for (String w : e.getValue()) {
                int i = q.indexOf(w);
                if (i >= 0) first = Math.min(first, i);
            }
            if (first != Integer.MAX_VALUE) hits.add(Map.entry(first, e.getKey()));
        }
        hits.sort(Map.Entry.comparingByKey());
        List<String> out = new ArrayList<>();
        hits.forEach(h -> out.add(h.getValue()));
        return out;
    }

    @SuppressWarnings("unchecked")
    private static <K, V> Map<K, V> ordered(Object... kv) {
        Map<K, V> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) m.put((K) kv[i], (V) kv[i + 1]);
        return m;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, List<String>> orderedList(Object... kv) {
        return ordered(kv);
    }
}
