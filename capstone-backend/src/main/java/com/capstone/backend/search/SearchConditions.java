package com.capstone.backend.search;

import com.capstone.backend.course.CourseRequest;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CrowdPreference;

import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 검색 조건 (POST /api/search 응답의 conditions, 요청의 conditions 직접 전달도 같은 모양) - 김예민
 * - 값은 전부 명세 코드값 (region SEONGSU, dayType WEEKEND, categories CAFE …)
 * - v0.3 추가: gender(F/M), ageGroup(10s~60s), companionType(FRIEND/COUPLE/FAMILY/COWORKER/SOLO), excludedFoods
 *   → 성별·나이는 타깃 점수(윤경), 동행 유형은 분위기, 제외 음식은 식당 거르기에 사용
 * - extractedBy: GEMINI / RULE / USER(사용자가 조건 화면에서 직접 고침)
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
        String extractedBy
) {

    public SearchConditions withDate(String newDate, String newDayType) {
        return new SearchConditions(region, newDate, newDayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy);
    }

    public SearchConditions withStartTime(String newStartTime) {
        return new SearchConditions(region, date, dayType, newStartTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy);
    }

    public SearchConditions withRegion(String newRegion) {
        return new SearchConditions(newRegion, date, dayType, startTime, partySize, categories, atmospheres,
                crowdPreference, allergies, gender, ageGroup, companionType, excludedFoods, extractedBy);
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
                List.copyOf(allAllergies), gender, ageGroup, companionType, excludedFoods, extractedBy);
    }

    /** 빈 값 채우기: 인원 2명, 목록은 빈 목록, 혼잡 선호는 분위기 태그로 ('조용함' → QUIET, '활기' → LIVELY) */
    public SearchConditions withDefaults() {
        List<String> moods = atmospheres == null ? List.of() : atmospheres;
        String crowd = crowdPreference;
        if (crowd == null) {
            crowd = moods.contains("조용함") ? "QUIET" : moods.contains("활기") ? "LIVELY" : "DEFAULT";
        }
        return new SearchConditions(region, date, dayType, startTime, partySize == null ? 2 : partySize,
                categories == null ? List.of() : categories, moods, crowd,
                allergies == null ? List.of() : allergies, gender, ageGroup, companionType,
                excludedFoods == null ? List.of() : excludedFoods, extractedBy);
    }

    /** 코스 생성용 요청으로 바꾸기 (withDefaults 끝난 조건) */
    public CourseRequest toCourseRequest() {
        return new CourseRequest(region, toMinutes(startTime), partySize, atmospheres,
                CrowdPreference.valueOf(crowdPreference), new HashSet<>(allergies),
                categories.stream().filter(CourseRules.PLAY_CATEGORIES::contains).toList(), List.of());
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
        m.put("extractedBy", extractedBy);
        return m;
    }
}
