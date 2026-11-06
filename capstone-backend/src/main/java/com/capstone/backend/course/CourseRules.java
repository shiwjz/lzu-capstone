package com.capstone.backend.course;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 코스 생성 규칙 v0.1 (docs/api-spec.md '코스 생성 규칙'과 같은 값)
 * 숫자는 전부 초기값, LG 데이터 받은 뒤 조정
 */
public final class CourseRules {

    private CourseRules() {
    }

    public static final int TARGET_MINUTES = 180;        // 총 3시간
    public static final int TOLERANCE_MINUTES = 30;      // ±30분 → 150~210분만 남김
    public static final int WALK_ZERO_MINUTES = 40;      // 총 도보 40분이면 이동 효율 0
    public static final int CANDIDATES_PER_SLOT = 10;    // 칸별 후보 수 → 10 × 10 × 10 조합
    public static final int COURSE_COUNT = 10;           // 추천 코스 최대 수 (v0.5, 예전 3)
    public static final int BAR_FROM_HOUR = 18;          // 술집은 18시 이후 도착일 때만
    public static final int ASSUMED_MOVE_MINUTES = 10;   // 후보 고를 때 칸 사이 이동 시간 가정

    // 코스 점수 = 0.70 × 평균 장소 점수 + 0.20 × 이동 효율 + 0.10 × 시간 적합도
    public static final double W_PLACE_AVG = 0.70;
    public static final double W_MOVE = 0.20;
    public static final double W_TIME = 0.10;

    public static final List<String> PLAY_CATEGORIES =
            List.of("CULTURE", "ACTIVITY", "EXPERIENCE", "SHOPPING", "TOUR", "NATURE");

    public static final Map<String, String> REGION_LABEL =
            Map.of("SEONGSU", "성수", "HONGDAE", "홍대", "GANGNAM", "강남");

    // 카테고리별 체류 시간 초기값(분)
    private static final Map<String, Integer> STAY_MINUTES = Map.of(
            "FOOD", 60, "CAFE", 50, "CULTURE", 60, "ACTIVITY", 60,
            "EXPERIENCE", 90, "SHOPPING", 40, "TOUR", 40, "NATURE", 40, "SNACK", 30);

    // 후보 고를 때 쓰는 칸별 대략 체류 시간
    private static final Map<Slot, Integer> NOMINAL_STAY = Map.of(
            Slot.MEAL, 60, Slot.CAFE, 50, Slot.PLAY, 60, Slot.BAR, 60);

    /**
     * 종류별 기본 영업시간 {여는 시, 닫는 시} (11주차) - 가게별 영업시간 정보가 없어서 임시로 종류별 숫자
     * - 닫는 시가 24 넘으면 다음날 (술집 17~26 = 오후 5시 ~ 새벽 2시)
     * - 도착 시(hour)가 여는 시 이상, 닫는 시 미만이면 열려 있다고 봄
     * - 구글 영업시간 붙이면 이 표 대신 가게별 값
     */
    private static final Map<String, int[]> DEFAULT_HOURS = Map.of(
            "FOOD", new int[]{11, 22}, "CAFE", new int[]{9, 22}, "SNACK", new int[]{9, 21},
            "CULTURE", new int[]{10, 19}, "EXPERIENCE", new int[]{10, 21}, "ACTIVITY", new int[]{10, 24},
            "SHOPPING", new int[]{11, 21}, "TOUR", new int[]{0, 24}, "NATURE", new int[]{0, 24});
    private static final int[] BAR_HOURS = {17, 26};
    private static final int[] LATE_CULTURE_HOURS = {10, 24};   // 영화관·공연장은 밤늦게까지

    // 문화·산책·쇼핑 코스 틀: 놀거리 종류를 하나만 말하면 놀거리부터 (전시 → 카페 → 식사)
    private static final List<String> THEME_PLAY = List.of("CULTURE", "NATURE", "SHOPPING", "TOUR");

    // 조용한 곳 원하면 놀거리 칸에서 빼는 곳 (카카오 카테고리·이름 기준, '조용한데 노래방' 문제 대책)
    private static final List<String> NOISY_PLAY = List.of(
            "노래방", "노래연습장", "코인노래", "멀티방", "오락실", "PC방", "볼링", "당구", "클럽", "VR", "사격");

    // 알레르기 → 제외할 카카오 카테고리 단어 (초안, 나머지 알레르기는 블로그 메뉴 경고로 보완)
    private static final Map<String, List<String>> ALLERGY_EXCLUDE = Map.of(
            "SHELLFISH", List.of("해물", "조개", "게,대게", "랍스터"),
            "SEAFOOD", List.of("해물", "생선", "회", "초밥"));

    public static int stayMinutes(String category) {
        return STAY_MINUTES.getOrDefault(category, 60);
    }

    public static int nominalStay(Slot slot) {
        return NOMINAL_STAY.get(slot);
    }

    /** 시작 시각별 기본 순서 (문장에 순서가 있으면 그 순서가 우선) */
    public static List<Slot> slotOrder(int startMinute) {
        int hour = startMinute / 60;
        if (hour < 11) return List.of(Slot.CAFE, Slot.PLAY, Slot.MEAL);   // 브런치 후 점심
        if (hour < 14) return List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY);   // 점심부터
        if (hour < 17) return List.of(Slot.PLAY, Slot.CAFE, Slot.MEAL);   // 저녁 식사로 마무리
        return List.of(Slot.MEAL, Slot.CAFE, Slot.PLAY);                  // 저녁 먼저
    }

    /**
     * 코스 틀 고르기 (11주차, 문장에 순서가 있으면 그 순서가 우선)
     * - 술 (음식 취향에 술집): 저녁 5시 이후 식사 → 술집 → 술집(2차), 4시 출발 놀거리 → 식사 → 술집
     *   (술집은 6시 이후만이라 그보다 이르면 술집 칸 후보가 없어서 코스 0개 → 앱에 안내)
     * - 문화·산책·쇼핑 (놀거리 종류 하나만, 5시 전): 놀거리 → 카페 → 식사
     * - 밤 8시 이후 (술 싫다고 안 했으면): 식사 → 놀거리 → 술집 (카페는 대부분 10시에 닫음)
     * - 나머지: 시작 시각별 기본 순서
     * - drinking: true = 술 원함, false = 술 빼달라고 함, null = 말 없음
     */
    public static List<Slot> slotOrder(int startMinute, Boolean drinking, List<String> playCategories) {
        int hour = startMinute / 60;
        if (Boolean.TRUE.equals(drinking)) {
            return hour >= 17 ? List.of(Slot.MEAL, Slot.BAR, Slot.BAR) : List.of(Slot.PLAY, Slot.MEAL, Slot.BAR);
        }
        if (hour < 17 && playCategories != null && playCategories.size() == 1
                && THEME_PLAY.contains(playCategories.get(0))) {
            return List.of(Slot.PLAY, Slot.CAFE, Slot.MEAL);
        }
        if (hour >= 20 && drinking == null) {
            return List.of(Slot.MEAL, Slot.PLAY, Slot.BAR);
        }
        return slotOrder(startMinute);
    }

    /** 기본 영업시간 안에 도착하는지 (hour는 24 넘어가도 됨: 자정 넘는 코스) */
    public static boolean openAt(CoursePlace place, int hour) {
        int[] oc = place.isBar() ? BAR_HOURS
                : (place.kakaoCategory().contains("영화관") || place.kakaoCategory().contains("공연장")) ? LATE_CULTURE_HOURS
                : DEFAULT_HOURS.getOrDefault(place.category(), new int[]{0, 24});
        int h = Math.floorMod(hour, 24);
        return (oc[0] <= h && h < oc[1]) || (oc[0] <= h + 24 && h + 24 < oc[1]);
    }

    /** 칸에 넣을 수 있는 장소인지 (지역·술집 시간·식사 칸 제외·알레르기) */
    public static boolean allowed(CoursePlace place, String region, int arriveHour, Set<String> allergies) {
        if (!place.region().equals(region)) return false;
        String kakao = place.kakaoCategory();
        if (kakao.contains("술집") && arriveHour < BAR_FROM_HOUR) return false;
        if (!openAt(place, arriveHour)) return false;     // 종류별 기본 영업시간 (11주차)
        if (place.category().equals("FOOD") && (kakao.contains("간식") || kakao.contains("구내식당"))) {
            return false;   // 베이커리·아이스크림·구내식당은 식사 칸 제외
        }
        for (String allergy : allergies) {
            for (String word : ALLERGY_EXCLUDE.getOrDefault(allergy, List.of())) {
                if (kakao.contains(word)) return false;
            }
        }
        return true;
    }

    /** 시끄러운 놀거리인지 (노래방·오락실 등) */
    public static boolean isNoisy(CoursePlace place) {
        String text = place.kakaoCategory() + " " + place.name();
        return NOISY_PLAY.stream().anyMatch(text::contains);
    }

    /** 혼잡도 적합도 (이윤경 확정 전 초안) */
    public static double congestionFit(CrowdPreference preference, CongestionLevel level) {
        return switch (preference) {
            case QUIET -> switch (level) { case QUIET -> 1.0; case NORMAL -> 0.5; case BUSY -> 0.1; };
            case DEFAULT -> switch (level) { case QUIET -> 0.8; case NORMAL -> 1.0; case BUSY -> 0.5; };
            case LIVELY -> switch (level) { case QUIET -> 0.2; case NORMAL -> 0.6; case BUSY -> 1.0; };
        };
    }

    /** 점수는 소수 둘째 자리 (화면에 보이는 값과 계산에 쓰는 값을 같게) */
    public static double round2(double value) {
        return new BigDecimal(value).setScale(2, RoundingMode.HALF_EVEN).doubleValue();
    }

    public static String hhmm(int minutes) {
        return String.format("%02d:%02d", (minutes / 60) % 24, minutes % 60);
    }
}
