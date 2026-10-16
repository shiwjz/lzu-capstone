package com.capstone.backend.course;

import java.util.ArrayList;
import java.util.List;

/**
 * 장소 목록 + 체류 시간 → 도착·출발 시각, 도보, 점수 계산
 * 코스 생성(조합 1,000개)과 코스 수정(PUT /api/courses/{courseId}) 둘 다 이 계산을 사용
 */
public class CourseCalculator {

    /**
     * 도착 = 이전 장소 출발 + 도보 시간, 출발 = 도착 + 체류 시간
     * 혼잡도·장소 점수는 각 장소의 실제 도착 시각 기준으로 다시 계산
     */
    public CoursePlan calculate(List<StopInput> inputs, int startMinute, PlaceScorer scorer) {
        int time = startMinute;
        int walkTotal = 0;
        int distanceTotal = 0;
        double placeScoreSum = 0;
        CoursePlace prev = null;
        List<CoursePlan.Stop> stops = new ArrayList<>();

        for (int i = 0; i < inputs.size(); i++) {
            CoursePlace place = inputs.get(i).place();
            int stay = inputs.get(i).stayMinutes();
            Integer distance = null;
            Integer walk = null;
            if (prev != null) {
                distance = WalkingTime.distanceMeters(prev.lat(), prev.lng(), place.lat(), place.lng());
                walk = WalkingTime.minutes(distance);
                time += walk;
                walkTotal += walk;
                distanceTotal += distance;
            }
            PlaceScore score = scorer.score(place, time / 60);
            double placeScore = CourseRules.round2(score.total());
            stops.add(new CoursePlan.Stop(
                    i + 1, place.slot(), place.placeId(), place.name(), place.category(),
                    place.lat(), place.lng(),
                    CourseRules.hhmm(time), CourseRules.hhmm(time + stay), stay,
                    walk, distance,
                    new CoursePlan.Congestion(score.level(), score.percentile()),
                    placeScore));
            placeScoreSum += placeScore;
            time += stay;
            prev = place;
        }

        int total = time - startMinute;
        double placeAvg = stops.isEmpty() ? 0 : placeScoreSum / stops.size();
        double move = Math.max(0.0, 1 - (double) walkTotal / CourseRules.WALK_ZERO_MINUTES);
        double timeFit = Math.max(0.0,
                1 - Math.abs(total - CourseRules.TARGET_MINUTES) / (double) CourseRules.TOLERANCE_MINUTES);
        double courseTotal = CourseRules.W_PLACE_AVG * placeAvg
                + CourseRules.W_MOVE * move
                + CourseRules.W_TIME * timeFit;

        CoursePlan.Score courseScore = new CoursePlan.Score(
                CourseRules.round2(courseTotal), CourseRules.round2(placeAvg),
                CourseRules.round2(move), CourseRules.round2(timeFit));
        return new CoursePlan(null, null, null, null,
                CourseRules.hhmm(startMinute), CourseRules.hhmm(time),
                total, walkTotal, distanceTotal, courseScore, List.copyOf(stops));
    }

    /** 총 3시간 ±30분 안인지 */
    public static boolean withinTimeWindow(CoursePlan plan) {
        return Math.abs(plan.totalMinutes() - CourseRules.TARGET_MINUTES) <= CourseRules.TOLERANCE_MINUTES;
    }

    /** 코스 수정 결과 경고 */
    public List<CourseWarning> warnings(CoursePlan plan, CrowdPreference crowdPreference) {
        List<CourseWarning> warnings = new ArrayList<>();
        int total = plan.totalMinutes();
        if (total > CourseRules.TARGET_MINUTES + CourseRules.TOLERANCE_MINUTES) {
            warnings.add(new CourseWarning("TOTAL_TIME_OVER", "총 " + total + "분으로 3시간 30분을 넘어요"));
        }
        if (total < CourseRules.TARGET_MINUTES - CourseRules.TOLERANCE_MINUTES) {
            warnings.add(new CourseWarning("TOTAL_TIME_UNDER", "총 " + total + "분으로 2시간 30분보다 짧아요"));
        }
        for (CoursePlan.Stop stop : plan.stops()) {
            if (stop.walkMinutesFromPrev() != null && stop.walkMinutesFromPrev() > 15) {
                warnings.add(new CourseWarning("LONG_WALK",
                        stop.name() + "까지 걸어서 " + stop.walkMinutesFromPrev() + "분 걸려요"));
            }
            if (crowdPreference == CrowdPreference.QUIET && stop.congestion().level() == CongestionLevel.BUSY) {
                warnings.add(new CourseWarning("BUSY_AT_ARRIVAL",
                        stop.arriveAt() + "에 " + stop.name() + " 주변이 붐벼요"));
            }
        }
        return warnings;
    }
}
