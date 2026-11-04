package com.capstone.backend.search;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.CoursePlace;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CrowdPreference;
import com.capstone.backend.course.Cuisine;
import com.capstone.backend.course.PlaceScore;
import com.capstone.backend.course.PlaceScorer;
import com.capstone.backend.place.PlaceStore;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 장소 점수 모듈 (윤경 place_score.py → Java로 옮김, 예민)
 * - 장소 점수 = 0.45 × 사용자 요구 + 0.30 × 타깃 특성 + 0.25 × 혼잡도 적합도 (각 0~1)
 * - v0.5: 사용자 요구에 세부 음식 취향 섞음 (course/Cuisine.detailFit), 11/4 윤경 확정
 * - 11/4: 태그가 하나도 없는 장소는 분위기 점수 0 → 0.5 (모르니까 중립, 윤경 B안)
 * - 11/4: 점수 같으면 원하는 분위기 태그 언급 많은 곳 먼저 (tieBreak) → 윤경 평가 9개 시나리오 구글 리뷰 채점 Precision@5 0.40 → 0.76
 * - 계산식·숫자는 place_score.py랑 똑같이 → 바꿀 때는 둘 다 바꾸기 (@이윤경)
 *   · 같은 입력이면 같은 값인지: PlaceScoreModelTest (윤경 test_place_score.py 17개 그대로)
 *   · 가짜 JSON(generate_mocks.py가 place_score.py import)이랑 서버 결과 비교로도 확인
 * - 데이터: 태그 = 예린 place_tag.csv, 성·연령·유형 = 윤경 cell_gender_age_fake.csv·cell_cluster.csv,
 *   혼잡 등급 = 도착 시각의 level_same_time (같은 시간끼리 비교)
 */
@Primary
@Component
public class PlaceScoreModel implements PlaceScorerFactory {

    // place_score.py 맨 위 숫자 그대로
    static final double W_REQUEST = 0.45, W_TARGET = 0.30, W_FIT = 0.25;
    static final double NEUTRAL = 0.5;           // 정보 없을 때 중립 점수
    static final int MENTION_FULL = 3;           // (가정) 태그 언급 3번 이상이면 확실한 태그
    static final double CLUSTER_WEIGHT = 0.5;    // (가정) 칸 비율과 같은 유형 평균을 섞는 비율

    private final PlaceStore store;

    public PlaceScoreModel(PlaceStore store) {
        this.store = store;
    }

    @Override
    public PlaceScorer forConditions(SearchConditions c) {
        CrowdPreference crowd = CrowdPreference.valueOf(c.crowdPreference());
        return new PlaceScorer() {
            @Override
            public PlaceScore score(CoursePlace place, int hour) {
                return scoreOf(c, crowd, place, hour);
            }

            /** 동점일 때: 원하는 분위기 태그 언급 수(3개 넘어도 그대로) 합이 큰 곳 먼저 */
            @Override
            public double tieBreak(CoursePlace place) {
                return mentionSum(store.find(place.placeId()).orElseThrow(), c.atmospheres());
            }
        };
    }

    private PlaceScore scoreOf(SearchConditions c, CrowdPreference crowd, CoursePlace place, int hour) {
        {
            PlaceStore.Place p = store.find(place.placeId()).orElseThrow();
            Map<String, Integer> tags = new HashMap<>();
            p.tags().forEach(t -> tags.put(t.tag(), t.mentions()));
            double request = requestScore(c.atmospheres(), tags, c.cuisineDetails(), p.cuisine(), p.cuisineDetail());

            PlaceStore.CellProfile cell = store.cellProfile(p.placeId());
            Map<String, Double> cluster = cell == null ? null : store.clusterAverage(cell.cluster());
            double target = targetScore(cell == null ? null : cell::value, cluster,
                    store.regionAverage(p.region()), c.gender(), c.ageGroup());

            PlaceStore.Congestion cong = store.congestion(p.placeId(), c.dayType(), hour, PlaceStore.Basis.SAME_TIME);
            double fit = congestionFit(crowd, cong.level());
            double total = W_REQUEST * request + W_TARGET * target + W_FIT * fit;
            return new PlaceScore(total, request, target, fit, cong.level(), cong.percentile());
        }
    }

    /** 원하는 분위기 태그 언급 수 합 (동점 정렬용, generate_mocks.py tie_break랑 같게) */
    static double mentionSum(PlaceStore.Place p, List<String> atmospheres) {
        if (atmospheres == null || atmospheres.isEmpty()) return 0;
        return p.tags().stream().filter(t -> atmospheres.contains(t.tag())).mapToInt(PlaceStore.Tag::mentions).sum();
    }

    /** 분위기 하나: min(언급 수, 3) ÷ 3. 태그가 하나도 없는 장소는 모르니까 0.5 (11/4 윤경 B안) */
    static double moodScore(String atmosphere, Map<String, Integer> placeTags) {
        if (placeTags == null || placeTags.isEmpty()) return NEUTRAL;
        return Math.min(placeTags.getOrDefault(atmosphere, 0), MENTION_FULL) / (double) MENTION_FULL;
    }

    /**
     * 사용자 요구 (place_score.py request_score): (분위기 점수 합 + 음식 세부 점수) ÷ (분위기 수 + 1)
     * - 세부 점수 계산 안 하면 분위기 점수 평균, 분위기도 없으면 0.5
     */
    static double requestScore(List<String> atmospheres, Map<String, Integer> placeTags,
                               List<String> cuisineDetails, String placeCuisine, String placeDetail) {
        double total = 0;
        int n = 0;
        for (String a : atmospheres == null ? List.<String>of() : atmospheres) {
            total += moodScore(a, placeTags);
            n++;
        }
        Double d = Cuisine.detailFit(placeCuisine, placeDetail, cuisineDetails);
        if (d != null) {
            total += d;
            n++;
        }
        return n == 0 ? NEUTRAL : total / n;
    }

    /** 분위기만 (음식 세부 없음) */
    static double requestScore(List<String> atmospheres, Map<String, Integer> placeTags) {
        return requestScore(atmospheres, placeTags, null, null, null);
    }

    /** 칸 값 꺼내기 ("female_ratio", "age_20s" …) */
    interface Shares {
        double get(String column);
    }

    /**
     * 타깃 특성: (칸 비율 ÷ 지역 평균 비율)을 성별·연령 곱해서 배수 → 배수 ÷ (1 + 배수)
     * - 성별·연령 둘 다 없거나 칸 정보 없으면 0.5
     * - 같은 유형 평균 있으면 칸 비율과 반반 섞음
     */
    static double targetScore(Shares cell, Map<String, Double> cluster, Map<String, Double> regionAvg,
                              String gender, String ageGroup) {
        if (cell == null || regionAvg == null || (gender == null && ageGroup == null)) return NEUTRAL;
        double index = 1.0;
        if (gender != null) {
            double f = share(cell, cluster, "female_ratio");
            double fAvg = regionAvg.get("female_ratio");
            index *= gender.equals("F") ? f / fAvg : (1 - f) / (1 - fAvg);
        }
        if (ageGroup != null) {
            String col = "age_" + ageGroup;
            index *= share(cell, cluster, col) / regionAvg.get(col);
        }
        return index / (1 + index);
    }

    private static double share(Shares cell, Map<String, Double> cluster, String col) {
        double v = cell.get(col);
        if (cluster != null) v = (1 - CLUSTER_WEIGHT) * v + CLUSTER_WEIGHT * cluster.get(col);
        return v;
    }

    /** 혼잡도 적합도 (명세 표 = CourseRules.congestionFit), 등급 없으면 0.5 */
    static double congestionFit(CrowdPreference crowd, CongestionLevel level) {
        if (level == null) return NEUTRAL;
        return CourseRules.congestionFit(crowd, level);
    }
}
