package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.Comparator;
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
 * 5. 코스 점수 순으로, 앞에서 고른 코스와 장소 안 겹치는 것만 최대 10개 선택 (v0.5, 예전 3개)
 * - 11주차: 코스 틀(술·문화·밤), 술집 칸(BAR, 같은 칸 두 번 = 1차·2차), 종류별 기본 영업시간, 코스 경로 이름(route)
 *
 * 장소 목록은 PlaceStore(지금은 resources/data 파일, ERD 확정 후 DB), 점수는 PlaceScorer(이윤경 모듈 자리)에서 받아서 사용
 * Spring 빈 아님 → SearchService에서 new 해서 사용
 */
public class CourseGenerator {

    private final CourseCalculator calculator = new CourseCalculator();

    /** 칸별 후보 결과: 칸 순서, 칸별 대략 도착 시각(시, 칸 순서대로), 칸별 후보 (검색 API 추천 장소 목록도 이걸로 만듦) */
    public record Candidates(List<Slot> order, List<Integer> nominalHour, List<List<CoursePlace>> perSlot) {
    }

    /** 1. 칸별 후보: 필터 통과한 장소 중 점수 상위 10곳 (점수 같으면 원래 순서 유지) */
    public Candidates candidates(CourseRequest request, List<CoursePlace> places, PlaceScorer scorer) {
        int start = request.startMinute();
        // 킵한 장소 자리 정하기 (11주차): 그 칸이 없으면 칸 추가, 자리가 없으면 이 순서는 못 씀 → 빈 후보
        Map<Integer, CoursePlace> kept = new HashMap<>();
        List<Slot> order = keepSlots(request.slotOrder(), request.keeps(), places, kept);
        if (order == null) return new Candidates(request.slotOrder(), List.of(), List.of());
        Set<String> allergies = request.allergies() == null ? Set.of() : request.allergies();
        List<String> playCategories = request.playCategoriesOrAll();

        // 칸별 대략 도착 시각 (후보 순위용) - 술집 2번처럼 같은 칸이 두 번 나올 수 있어서 칸 순서대로 목록
        List<Integer> nominalHour = new ArrayList<>();
        int time = start;
        for (Slot slot : order) {
            nominalHour.add(time / 60);
            time += CourseRules.nominalStay(slot) + CourseRules.ASSUMED_MOVE_MINUTES;
        }
        boolean barSlot = order.contains(Slot.BAR);

        List<List<CoursePlace>> perSlot = new ArrayList<>();
        for (int k = 0; k < order.size(); k++) {
            Slot slot = order.get(k);
            int hour = nominalHour.get(k);
            if (kept.containsKey(k)) {               // 킵한 장소 칸은 그 장소 하나만
                perSlot.add(List.of(kept.get(k)));
                continue;
            }
            List<CoursePlace> pool = new ArrayList<>();
            Map<String, Double> scoreById = new HashMap<>();
            for (CoursePlace place : places) {
                if (fitsSlot(place, slot, playCategories, request.wantsQuiet(), barSlot)
                        && CourseRules.allowed(place, request.region(), hour, allergies)) {
                    pool.add(place);
                    scoreById.put(place.placeId(), CourseRules.round2(scorer.score(place, hour).total()));
                }
            }
            // 점수 높은 순, 같으면 tieBreak 큰 순 (원하는 분위기 태그 언급 많은 곳)
            pool.sort(Comparator.<CoursePlace>comparingDouble(p -> -scoreById.get(p.placeId()))
                    .thenComparingDouble(p -> -scorer.tieBreak(p)));
            perSlot.add(List.copyOf(pool.subList(0, Math.min(CourseRules.CANDIDATES_PER_SLOT, pool.size()))));
        }
        return new Candidates(order, List.copyOf(nominalHour), perSlot);
    }

    /** 킵한 장소마다 들어갈 칸 번호 (out에 채움), 칸 순서가 바뀌면 바뀐 순서, 못 넣으면 null */
    static List<Slot> keepSlots(List<Slot> order, List<String> keepIds, List<CoursePlace> places,
                                Map<Integer, CoursePlace> out) {
        if (keepIds.isEmpty()) return order;
        List<Slot> v = new ArrayList<>(order);
        List<CoursePlace> keeps = new ArrayList<>();
        for (String id : keepIds) {
            places.stream().filter(p -> p.placeId().equals(id)).findFirst().ifPresent(keeps::add);
        }
        List<Integer> taken = new ArrayList<>();
        for (CoursePlace k : keeps) {
            Slot need = k.slot();
            int idx = -1;
            for (int i = 0; i < v.size(); i++) {
                if (v.get(i) == need && !taken.contains(i)) {
                    idx = i;
                    break;
                }
            }
            if (idx < 0 && v.size() < CourseRules.MAX_STOPS) {
                int bar = v.indexOf(Slot.BAR);
                idx = need == Slot.BAR || bar < 0 ? v.size() : bar;
                v.add(idx, need);
                for (int t = 0; t < taken.size(); t++) {          // 끼워 넣은 자리 뒤 번호 밀기
                    if (taken.get(t) >= idx) taken.set(t, taken.get(t) + 1);
                }
            }
            if (idx < 0) return null;
            taken.add(idx);
        }
        for (int t = 0; t < taken.size(); t++) out.put(taken.get(t), keeps.get(t));
        return List.copyOf(v);
    }

    public List<CoursePlan> generate(CourseRequest request, List<CoursePlace> places, PlaceScorer scorer) {
        int start = request.startMinute();

        // 2~4. 조합 → 계산 → 시간 기준 통과한 것만 (11주차: 틀 순서가 여러 개면 순서마다 만들어서 합침)
        List<CoursePlan> plans = new ArrayList<>();
        for (List<Slot> order : request.slotOrders()) {
            List<List<CoursePlace>> candidates = candidates(request.withOrder(order), places, scorer).perSlot();
            if (candidates.isEmpty() || candidates.stream().anyMatch(List::isEmpty)) continue;
            combine(candidates, 0, new ArrayList<>(), start, scorer, plans);
        }
        Set<String> keepIds = new HashSet<>(request.keeps());

        // 5. 점수 순 (같으면 조합 순서 유지), 장소 안 겹치게 최대 COURSE_COUNT개
        plans.sort(Comparator.comparingDouble(p -> -p.score().total()));
        Map<String, CoursePlace> placesById = new HashMap<>();
        places.forEach(p -> placesById.put(p.placeId(), p));

        List<CoursePlan> chosen = new ArrayList<>();
        Set<String> used = new HashSet<>();
        for (CoursePlan plan : plans) {
            // 킵한 장소는 모든 코스에 들어가니까 겹침 검사에서 뺌
            List<String> ids = plan.stops().stream().map(CoursePlan.Stop::placeId)
                    .filter(id -> !keepIds.contains(id)).toList();
            if (ids.stream().anyMatch(used::contains)) continue;
            int rank = chosen.size() + 1;
            chosen.add(plan.withMeta(null, rank,
                    CourseText.title(plan, request.region(), start, placesById),
                    CourseText.reason(plan, request, placesById),
                    CourseText.keywords(plan, request, placesById),
                    CourseText.route(plan, placesById)));
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
                CourseText.reason(plan, request, placesById),
                CourseText.keywords(plan, request, placesById),
                CourseText.route(plan, placesById));
    }

    public List<CourseWarning> warnings(CoursePlan plan, CrowdPreference crowdPreference) {
        return calculator.warnings(plan, crowdPreference);
    }

    /** 코스 수정 경고 + 기본 영업시간 밖 도착 (11주차) */
    public List<CourseWarning> warnings(CoursePlan plan, CrowdPreference crowdPreference,
                                        Map<String, CoursePlace> placesById) {
        List<CourseWarning> out = new ArrayList<>(calculator.warnings(plan, crowdPreference));
        for (CoursePlan.Stop s : plan.stops()) {
            CoursePlace p = placesById.get(s.placeId());
            int hour = Integer.parseInt(s.arriveAt().substring(0, 2));
            if (p != null && !CourseRules.openAt(p, hour)) {
                out.add(new CourseWarning("MAYBE_CLOSED",
                        s.arriveAt() + "에는 " + s.name() + " 영업이 끝났을 수 있어요 (종류별 기본 영업시간 기준)"));
            }
        }
        return out;
    }

    /** barSlot: 코스 틀에 술집 칸이 따로 있으면 식사 칸엔 술집 안 넣음 (술집 → 술집 → 술집 방지) */
    private static boolean fitsSlot(CoursePlace place, Slot slot, List<String> playCategories, boolean quiet,
                                    boolean barSlot) {
        return switch (slot) {
            case MEAL -> place.category().equals("FOOD") && !(barSlot && place.isBar());
            case BAR -> place.isBar();
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
            if (picked.contains(place)) continue;    // 술집 → 술집처럼 같은 칸 두 번이면 같은 곳은 안 됨
            if (place.slot() == Slot.PLAY && picked.stream().anyMatch(q -> q.slot() == Slot.PLAY
                    && CourseText.playLabel(q.kakaoCategory()).equals(CourseText.playLabel(place.kakaoCategory())))) {
                continue;                            // 놀거리 두 번이면 다른 종류로 (방탈출 → 볼링)
            }
            picked.add(place);
            combine(candidates, depth + 1, picked, start, scorer, out);
            picked.remove(picked.size() - 1);
        }
    }
}
