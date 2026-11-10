package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 코스 모양 정하기 (11주차) - 김예민
 * - 코스 틀 5종류 (사용자가 고름, 안 고르면 문장·시간 보고 자동 = CourseRules.slotOrder)
 *   기본: 식사→카페→놀거리, 카페→놀거리→식사 / 술: 식사→술집, 식사→술집→술집, 놀거리→식사→술집
 *   문화: 전시→카페→식사 / 산책: 공원→카페→식사 / 쇼핑: 쇼핑→카페→식사
 *   순서가 여러 개면 전부 만들어서 점수순으로 섞음 (CourseGenerator)
 * - 빼기 (excluded, "카페 말고"): 뺀 칸은 다른 걸로 채워서 장소 수 유지 (카페→놀거리, 식사→카페, 술집→놀거리)
 * - 추가 (included, "노래방도"): 그 칸이 없으면 넣음 (술집은 맨 끝, 나머지는 술집 앞), 장소 최대 4곳
 * - 종류 코드: FOOD(식사) · CAFE · BAR(술집) · 놀거리 6개(CULTURE·ACTIVITY·EXPERIENCE·SHOPPING·TOUR·NATURE)
 */
public final class CourseShape {

    private CourseShape() {
    }

    public static final List<String> COURSE_TYPES = List.of("BASIC", "DRINK", "CULTURE", "WALK", "SHOPPING");
    public static final List<String> EDIT_CODES = List.of("FOOD", "CAFE", "BAR",
            "CULTURE", "ACTIVITY", "EXPERIENCE", "SHOPPING", "TOUR", "NATURE");

    public static final Map<String, String> TYPE_LABEL = Map.of(
            "BASIC", "기본", "DRINK", "술", "CULTURE", "문화", "WALK", "산책", "SHOPPING", "쇼핑");

    private static final Slot M = Slot.MEAL, C = Slot.CAFE, P = Slot.PLAY, B = Slot.BAR;

    private static final Map<String, List<List<Slot>>> TYPE_ORDERS = Map.of(
            "BASIC", List.of(List.of(M, C, P), List.of(C, P, M)),
            "DRINK", List.of(List.of(M, B), List.of(M, B, B), List.of(P, M, B)),
            "CULTURE", List.of(List.of(P, C, M)),
            "WALK", List.of(List.of(P, C, M)),
            "SHOPPING", List.of(List.of(P, C, M)));

    // 틀이 정하는 놀거리 종류 (문화 = 전시·공연, 산책 = 공원·자연, 쇼핑)
    private static final Map<String, String> TYPE_PLAY = Map.of(
            "CULTURE", "CULTURE", "WALK", "NATURE", "SHOPPING", "SHOPPING");

    /**
     * 칸 순서 후보들
     * @param courseType 고른 틀 (null이면 자동)
     * @param playPool   놀거리 칸에 쓸 종류 (playPool() 결과, 빈 목록 = 전부)
     */
    public static List<List<Slot>> variants(String courseType, int startMinute, Boolean drinking,
                                            List<String> playPicked, Set<String> excluded, Set<String> included) {
        List<List<Slot>> base = courseType != null && TYPE_ORDERS.containsKey(courseType)
                ? TYPE_ORDERS.get(courseType)
                : List.of(CourseRules.slotOrder(startMinute, drinking, playPicked));
        Set<String> ex = excluded == null ? Set.of() : excluded;
        Set<String> in = included == null ? Set.of() : included;
        boolean playGone = CourseRules.PLAY_CATEGORIES.stream().allMatch(ex::contains);
        LinkedHashSet<List<Slot>> out = new LinkedHashSet<>();
        for (List<Slot> order : base) {
            List<Slot> v = new ArrayList<>();
            for (Slot s : order) {
                Slot r = replace(s, ex, playGone, order);
                if (r != null) v.add(r);
            }
            for (String code : in) {
                Slot need = slotOf(code);
                if (v.contains(need) || v.size() >= CourseRules.MAX_STOPS) continue;
                if (need == Slot.BAR) {
                    v.add(Slot.BAR);
                } else {
                    int bar = v.indexOf(Slot.BAR);
                    v.add(bar < 0 ? v.size() : bar, need);
                }
            }
            if (v.size() >= 2) out.add(List.copyOf(v));
        }
        return List.copyOf(out);
    }

    /** 뺀 칸 바꾸기: 카페 → 놀거리, 식사 → 카페(이미 있거나 카페도 뺐으면 놀거리), 술집 → 놀거리, 못 바꾸면 null(빼기) */
    private static Slot replace(Slot s, Set<String> ex, boolean playGone, List<Slot> order) {
        boolean removed = switch (s) {
            case CAFE -> ex.contains("CAFE");
            case MEAL -> ex.contains("FOOD");
            case BAR -> ex.contains("BAR");
            case PLAY -> playGone;
        };
        if (!removed) return s;
        if (s == Slot.MEAL && !ex.contains("CAFE") && !order.contains(Slot.CAFE)) return Slot.CAFE;
        if (s != Slot.PLAY && !playGone) return Slot.PLAY;
        return null;
    }

    /** 종류 코드 → 칸 */
    public static Slot slotOf(String code) {
        return switch (code) {
            case "FOOD" -> Slot.MEAL;
            case "CAFE" -> Slot.CAFE;
            case "BAR" -> Slot.BAR;
            default -> Slot.PLAY;
        };
    }

    /**
     * 놀거리 칸에 쓸 종류 (빈 목록 = 전부)
     * - 틀이 정하면 그 종류 (문화 → CULTURE), 아니면 문장에서 고른 종류
     * - 추가한 놀거리 종류는 더하고, 뺀 종류는 뺌
     */
    public static List<String> playPool(String courseType, List<String> playPicked, Set<String> excluded,
                                        Set<String> included) {
        LinkedHashSet<String> pool = new LinkedHashSet<>();
        if (courseType != null && TYPE_PLAY.containsKey(courseType)) pool.add(TYPE_PLAY.get(courseType));
        else if (playPicked != null) pool.addAll(playPicked);
        if (included != null && !pool.isEmpty()) {
            included.stream().filter(CourseRules.PLAY_CATEGORIES::contains).forEach(pool::add);
        }
        if (excluded == null || excluded.stream().noneMatch(CourseRules.PLAY_CATEGORIES::contains)) {
            return List.copyOf(pool);
        }
        List<String> base = pool.isEmpty() ? CourseRules.PLAY_CATEGORIES : List.copyOf(pool);
        List<String> left = base.stream().filter(c -> !excluded.contains(c)).toList();
        if (left.isEmpty()) {
            left = CourseRules.PLAY_CATEGORIES.stream().filter(c -> !excluded.contains(c)).toList();
        }
        return left;
    }
}
