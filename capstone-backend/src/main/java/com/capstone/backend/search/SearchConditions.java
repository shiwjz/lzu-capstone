package com.capstone.backend.search;

import com.capstone.backend.course.CourseRequest;
import com.capstone.backend.course.Cuisine;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CourseShape;
import com.capstone.backend.course.Slot;
import com.capstone.backend.course.CrowdPreference;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 검색 조건 (POST /api/search 응답의 conditions, 요청의 conditions 직접 전달도 같은 모양) - 김예민
 * - 값은 전부 명세 코드값 (region SEONGSU, dayType WEEKEND, categories CAFE …)
 * - v0.3 추가: gender(F/M), ageGroup(10s~60s), companionType(FRIEND/COUPLE/FAMILY/COWORKER/SOLO), excludedFoods
 *   → 성별·나이는 타깃 점수(윤경), 동행 유형은 분위기, 제외 음식은 식당 거르기에 사용
 * - extractedBy: GEMINI / RULE / USER(사용자가 조건 화면에서 직접 고침)
 * - v0.5 추가: cuisines(음식 큰 종류), cuisineDetails(세부) → course/Cuisine
 * - v0.7 추가 (11주차): courseType(코스 틀 BASIC·DRINK·CULTURE·WALK·SHOPPING),
 *   excludedCategories("카페 말고"), includedCategories("노래방도") → course/CourseShape
 */
public record SearchConditions(
        String region,
        String date,
        String dayType,
        String startTime,
        Integer partySize,
        List<String> categories,
        List<String> atmospheres,
        String crowdPreference,
        List<String> allergies,
        String gender,
        String ageGroup,
        String companionType,
        List<String> excludedFoods,
        String extractedBy,
        List<String> cuisines,          // v0.5 음식 큰 종류 (KOREAN·JAPANESE …) → 식사 칸 거르기
        List<String> cuisineDetails,    // v0.5 세부 (초밥·롤·라멘 …) → 사용자 요구 점수 가점
        String courseType,              // v0.7 코스 틀 (null = 자동)
        List<String> excludedCategories,// v0.7 뺄 종류 (FOOD·CAFE·BAR·놀거리 6개)
        List<String> includedCategories // v0.7 넣을 종류
) {

    /** 코스 틀·빼기·추가 없는 v0.5 모양 (Gemini·규칙 추출·테스트 호환용) */
    public SearchConditions(String region, String date, String dayType, String startTime, Integer partySize,
                            List<String> categories, List<String> atmospheres, String crowdPreference,
                            List<String> allergies, String gender, String ageGroup, String companionType,
                            List<String> excludedFoods, String extractedBy, List<String> cuisines,
                            List<String> cuisineDetails) {
        this(region, date, dayType, startTime, partySize, categories, atmospheres, crowdPreference, allergies,
                gender, ageGroup, companionType, excludedFoods, extractedBy, cuisines, cuisineDetails,
                null, null, null);
    }

    /** 코스 틀·빼기·추가만 바꾸기 */
    public SearchConditions withShape(String newType, List<String> newExcluded, List<String> newIncluded) {
        return new SearchConditions(region, date, dayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, newType, newExcluded, newIncluded);
    }

    public SearchConditions withExtractedBy(String by) {
        return new SearchConditions(region, date, dayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods,
                extractedBy == null ? by : extractedBy, cuisines, cuisineDetails, courseType, excludedCategories,
                includedCategories);
    }

    /** 음식 취향 없는 예전 모양 (Gemini·테스트 코드 호환용) */
    public SearchConditions(String region, String date, String dayType, String startTime, Integer partySize,
                            List<String> categories, List<String> atmospheres, String crowdPreference,
                            List<String> allergies, String gender, String ageGroup, String companionType,
                            List<String> excludedFoods, String extractedBy) {
        this(region, date, dayType, startTime, partySize, categories, atmospheres, crowdPreference, allergies,
                gender, ageGroup, companionType, excludedFoods, extractedBy, List.of(), List.of());
    }

    /** 음식 취향만 바꾸기 */
    public SearchConditions withCuisines(List<String> newCuisines, List<String> newDetails) {
        return new SearchConditions(region, date, dayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                newCuisines, newDetails, courseType, excludedCategories, includedCategories);
    }

    /**
     * 동행·인원 → 상황 태그 자동 (예린 tag_dictionary.py v3 SITUATION_RULES, 11/4)
     * - 데이트: 동행 COUPLE / 단체: 4명 이상 또는 COWORKER / 혼자: 1명 또는 SOLO / 아이: FAMILY
     * - 사용자가 고르는 태그가 아니라 점수용 (앱 분위기 칩에는 없음)
     */
    public SearchConditions withPartyMoods() {
        List<String> moods = atmospheres == null ? List.of() : atmospheres;
        List<String> next = new ArrayList<>(moods);
        String comp = String.valueOf(companionType);
        if (comp.equals("COUPLE")) addOnce(next, "데이트");
        if ((partySize != null && partySize >= 4) || comp.equals("COWORKER")) addOnce(next, "단체");
        if ((partySize != null && partySize == 1) || comp.equals("SOLO")) addOnce(next, "혼자");
        if (comp.equals("FAMILY")) addOnce(next, "아이");
        if (next.size() == moods.size()) return this;
        return new SearchConditions(region, date, dayType, startTime, partySize, categories, List.copyOf(next),
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, courseType, excludedCategories, includedCategories);
    }

    private static void addOnce(List<String> list, String tag) {
        if (!list.contains(tag)) list.add(tag);
    }

    public SearchConditions withDate(String newDate, String newDayType) {
        return new SearchConditions(region, newDate, newDayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, courseType, excludedCategories, includedCategories);
    }

    public SearchConditions withStartTime(String newStartTime) {
        return new SearchConditions(region, date, dayType, newStartTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, courseType, excludedCategories, includedCategories);
    }

    public SearchConditions withRegion(String newRegion) {
        return new SearchConditions(newRegion, date, dayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, courseType, excludedCategories, includedCategories);
    }

    /**
     * 로그인했을 때 내 설정 넣기 (명세 '회원 API': 문장이랑 다르면 문장 우선, 알레르기는 항상 추가) - 9주차
     * - 지역: 문장·조건에 없을 때만 내 설정 지역 → 지역 없는 문장도 CONDITION_MISSING 안 나옴 (지역 버튼 값은 이후에 덮어씀)
     * - 분위기: 문장에 분위기가 하나도 없을 때만 내 설정 분위기, 이때 혼잡 선호도 분위기 기준으로 다시 ('조용함' → QUIET)
     * - 알레르기: 문장 + 내 설정 합치기
     */
    public SearchConditions withPreferences(String myRegion, List<String> myAtmospheres, List<String> myAllergies) {
        String newRegion = region != null ? region : myRegion;
        List<String> moods = atmospheres;
        String crowd = crowdPreference;
        if ((moods == null || moods.isEmpty()) && myAtmospheres != null && !myAtmospheres.isEmpty()) {
            moods = List.copyOf(myAtmospheres);
            if (crowd == null || crowd.equals("DEFAULT")) crowd = null;   // withDefaults에서 분위기 보고 다시 정함
        }
        LinkedHashSet<String> allAllergies = new LinkedHashSet<>(allergies == null ? List.of() : allergies);
        if (myAllergies != null) allAllergies.addAll(myAllergies);
        return new SearchConditions(newRegion, date, dayType, startTime, partySize, categories, moods, crowd,
                List.copyOf(allAllergies), gender, ageGroup, companionType, excludedFoods, extractedBy,
                cuisines, cuisineDetails, courseType, excludedCategories, includedCategories);
    }

    /** 빈 값 채우기: 인원 2명, 목록은 빈 목록, 혼잡 선호는 분위기 태그로 ('조용한' → QUIET, '활기찬' → LIVELY) */
    public SearchConditions withDefaults() {
        List<String> moods = atmospheres == null ? List.of() : atmospheres;
        String crowd = crowdPreference;
        if (crowd == null) {
            crowd = moods.contains("조용한") ? "QUIET" : moods.contains("활기찬") ? "LIVELY" : "DEFAULT";
        }
        return new SearchConditions(region, date, dayType, startTime, partySize == null ? 2 : partySize,
                categories == null ? List.of() : categories, moods, crowd,
                allergies == null ? List.of() : allergies, gender, ageGroup, companionType,
                excludedFoods == null ? List.of() : excludedFoods, extractedBy,
                cuisines == null ? List.of() : cuisines, cuisineDetails == null ? List.of() : cuisineDetails,
                courseType, excludedCategories == null ? List.of() : excludedCategories,
                includedCategories == null ? List.of() : includedCategories);
    }

    /** 코스 생성용 요청으로 바꾸기 (withDefaults 끝난 조건) */
    public CourseRequest toCourseRequest() {
        return toCourseRequest(List.of(), List.of());
    }

    /**
     * 코스 생성용 요청 (11주차): order = 앱에서 직접 고친 칸 순서, keepPlaceIds = 킵한 장소
     * - 코스 틀·빼기·추가가 없으면 예전과 똑같음 (자동 틀)
     */
    public CourseRequest toCourseRequest(List<Slot> order, List<String> keepPlaceIds) {
        int start = toMinutes(startTime);
        List<String> picked = categories.stream().filter(CourseRules.PLAY_CATEGORIES::contains).toList();
        Set<String> ex = new LinkedHashSet<>(excludedCategories == null ? List.of() : excludedCategories);
        Set<String> in = new LinkedHashSet<>(includedCategories == null ? List.of() : includedCategories);
        boolean shaped = courseType != null || !ex.isEmpty() || !in.isEmpty();
        List<String> play = shaped ? CourseShape.playPool(courseType, picked, ex, in) : picked;
        List<List<Slot>> variants = shaped ? CourseShape.variants(courseType, start, drinking(), picked, ex, in) : null;
        return new CourseRequest(region, start, partySize, atmospheres,
                CrowdPreference.valueOf(crowdPreference), new HashSet<>(allergies), play,
                order == null ? List.of() : order, drinking(), variants,
                keepPlaceIds == null ? List.of() : keepPlaceIds);
    }

    /** 술 코스인지 (11주차): 음식 취향에 술집(BAR)이나 술집 세부(이자카야 등) → true, 제외 음식에 술 → false, 말 없으면 null */
    public Boolean drinking() {
        if (excludedFoods != null && excludedFoods.contains("술")) return false;
        if (excludedCategories != null && excludedCategories.contains("BAR")) return false;
        if ("DRINK".equals(courseType)) return true;
        if (cuisines != null && cuisines.contains("BAR")) return true;
        if (cuisineDetails != null && cuisineDetails.stream().anyMatch(d -> "BAR".equals(Cuisine.DETAIL_FAMILY.get(d)))) {
            return true;
        }
        return null;
    }

    public static int toMinutes(String hhmm) {
        String[] p = hhmm.split(":");
        return Integer.parseInt(p[0]) * 60 + Integer.parseInt(p[1]);
    }

    /** 응답 JSON 순서 고정용 */
    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("region", region);
        m.put("date", date);
        m.put("dayType", dayType);
        m.put("startTime", startTime);
        m.put("partySize", partySize);
        m.put("categories", categories);
        m.put("atmospheres", atmospheres);
        m.put("crowdPreference", crowdPreference);
        m.put("allergies", allergies);
        m.put("gender", gender);
        m.put("ageGroup", ageGroup);
        m.put("companionType", companionType);
        m.put("excludedFoods", excludedFoods);
        m.put("cuisines", cuisines);
        m.put("cuisineDetails", cuisineDetails);
        m.put("courseType", courseType);
        m.put("excludedCategories", excludedCategories);
        m.put("includedCategories", includedCategories);
        m.put("extractedBy", extractedBy);
        return m;
    }
}
