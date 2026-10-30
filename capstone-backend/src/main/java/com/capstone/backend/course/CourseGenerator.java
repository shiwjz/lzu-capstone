package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 코스 생성 v1 - 김예민
 *
 * 1. 칸별 후보: 필터 통과한 장소 중 칸마다 점수 상위 10곳 (그 칸의 대략적인 도착 시각 기준)
 *    - 조용한 곳 원하면 놀거리 칸에서 노래방·오락실 등 제외 (v0.3)
 * 2. 조합: 10 × 10 × 10 = 1,000개
 * 3. 시간 계산 + 도착 시각 혼잡도로 점수 다시 계산 (CourseCalculator)
 * 4. 총 소요시간 150~210분만 남기기
 * 5. 코스 점수 순으로, 앞에서 고른 코스와 장소 안 겹치는 것만 3개 선택
 *
 * 장소 목록은 PlaceStore(지금은 resources/data 파일, ERD 확정 후 DB), 점수는 PlaceScorer(이윤경 모듈 자리)에서 받아서 사용
 * Spring 빈 아님 → SearchService에서 new 해서 사용
 */
public class CourseGenerator {

    private final CourseCalculator calculator = new CourseCalculator();

    /** 칸별 후보 결과: 칸 순서, 칸별 대략 도착 시각(시), 칸별 후보 (검색 API 추천 장소 목록도 이걸로 만듦) */
    public record Candidates(List<Slot> order, Map<Slot, Integer> nominalHour, List<List<CoursePlace>> perSlot) {
    }

    /** 1. 칸별 후보: 필터 통과한 장소 중 점수 상위 10곳 (점수 같으면 원래 순서 유지) */
    public Candidates candidates(CourseRequest request, List<CoursePlace> places, PlaceScorer scorer) {
        int start = request.startMinute();
        List<Slot> order = request.slotOrder();
        Set<String> allergies = request.allergies() == null ? Set.of() : request.allergies();
        List<String> playCategories = request.playCategoriesOrAll();

        // 칸별 대략 도착 시각 (후보 순위용)
        Map<Slot, Integer> nominalHour = new EnumMap<>(Slot.class);
        int time = start;
        for (Slot slot : order) {
            nominalHour.put(slot, time / 60);
            time += CourseRules.nominalStay(slot) + CourseRules.ASSUMED_MOVE_MINUTES;
        }

        List<List<CoursePlace>> perSlot = new ArrayList<>();
        for (Slot slot : order) {
            int hour = nominalHour.get(slot);
            List<CoursePlace> pool = new ArrayList<>();
            Map<String, Double> scoreById = new HashMap<>();
            for (CoursePlace place : places) {
                if (fitsSlot(place, slot, playCategories, request.wantsQuiet())
                        && CourseRules.allowed(place, request.region(), hour, allergies)) {
                    pool.add(place);
                    scoreById.put(place.placeId(), CourseRules.round2(scorer.score(place, hour).total()));
                }
            }
            pool.sort(Comparator.comparingDouble(p -> -scoreById.get(p.placeId())));
            perSlot.add(List.copyOf(pool.subList(0, Math.min(CourseRules.CANDIDATES_PER_SLOT, pool.size()))));
        }
        return new Candidates(order, nominalHour, perSlot);
    }

    public List<CoursePlan> generate(CourseRequest request, List<CoursePlace> places, PlaceScorer scorer) {
        int start = request.startMinute();
        List<List<CoursePlace>> candidates = candidates(request, places, scorer).perSlot();

        // 2~4. 조합 → 계산 → 시간 기준 통과한 것만
        List<CoursePlan> plans = new ArrayList<>();
        combine(candidates, 0, new ArrayList<>(), start, scorer, plans);

        // 5. 점수 순 (같으면 조합 순서 유지), 장소 안 겹치게 3개
        plans.sort(Comparator.comparingDouble(p -> -p.score().total()));
        Map<String, CoursePlace> placesById = new HashMap<>();
        places.forEach(p -> placesById.put(p.placeId(), p));

        List<CoursePlan> chosen = new ArrayList<>();
        Set<String> used = new HashSet<>();
        for (CoursePlan plan : plans) {
            List<String> ids = plan.stops().stream().map(CoursePlan.Stop::placeId).toList();
            if (ids.stream().anyMatch(used::contains)) continue;
            int rank = chosen.size() + 1;
            chosen.add(plan.withMeta(null, rank,
                    CourseText.title(plan, request.region(), start, placesById),
                    CourseText.reason(plan, request, placesById)));
            used.addAll(ids);
            if (chosen.size() == CourseRules.COURSE_COUNT) break;
        }
        return chosen;
    }

    /** 코스 수정 (추가·삭제·교체·순서·체류시간 바뀐 전체 목록) → 다시 계산 */
    public CoursePlan recalculate(CourseRequest request, List<StopInput> stops, PlaceScorer scorer,
                                  Map<String, CoursePlace> placesById) {
        CoursePlan plan = calculator.calculate(stops, request.startMinute(), scorer);
        return plan.withMeta(null, null,
                CourseText.title(plan, request.region(), request.startMinute(), placesById),
                CourseText.reason(plan, request, placesById));
    }

    public List<CourseWarning> warnings(CoursePlan plan, CrowdPreference crowdPreference) {
        return calculator.warnings(plan, crowdPreference);
    }

    private static boolean fitsSlot(CoursePlace place, Slot slot, List<String> playCategories, boolean quiet) {
        return switch (slot) {
            case MEAL -> place.category().equals("FOOD");
            case CAFE -> place.category().equals("CAFE");      // SNACK은 코스 생성에서 제외
            case PLAY -> playCategories.contains(place.category())
                    && !(quiet && CourseRules.isNoisy(place));  // 조용한 곳 원하면 노래방·오락실 등 제외
        };
    }

    private void combine(List<List<CoursePlace>> candidates, int depth, List<CoursePlace> picked,
                         int start, PlaceScorer scorer, List<CoursePlan> out) {
        if (depth == candidates.size()) {
            List<StopInput> stops = picked.stream()
                    .map(p -> new StopInput(p, CourseRules.stayMinutes(p.category())))
                    .toList();
            CoursePlan plan = calculator.calculate(stops, start, scorer);
            if (CourseCalculator.withinTimeWindow(plan)) out.add(plan);
            return;
        }
        for (CoursePlace place : candidates.get(depth)) {
            picked.add(place);
            combine(candidates, depth + 1, picked, start, scorer, out);
            picked.remove(picked.size() - 1);
        }
    }
}
