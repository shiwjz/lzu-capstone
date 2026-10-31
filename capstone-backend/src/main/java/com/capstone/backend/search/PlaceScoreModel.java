package com.capstone.backend.search;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CrowdPreference;
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
 * - 계산식·숫자는 place_score.py랑 똑같이 → 바꿀 때는 둘 다 바꾸기 (@이윤경)
 *   · 같은 입력이면 같은 값인지: PlaceScoreModelTest (윤경 test_place_score.py 10개 그대로)
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
        return (place, hour) -> {
            PlaceStore.Place p = store.find(place.placeId()).orElseThrow();
            Map<String, Integer> tags = new HashMap<>();
            p.tags().forEach(t -> tags.put(t.tag(), t.mentions()));
            double request = requestScore(c.atmospheres(), tags);

            PlaceStore.CellProfile cell = store.cellProfile(p.placeId());
            Map<String, Double> cluster = cell == null ? null : store.clusterAverage(cell.cluster());
            double target = targetScore(cell == null ? null : cell::value, cluster,
                    store.regionAverage(p.region()), c.gender(), c.ageGroup());

            PlaceStore.Congestion cong = store.congestion(p.placeId(), c.dayType(), hour, PlaceStore.Basis.SAME_TIME);
            double fit = congestionFit(crowd, cong.level());
            double total = W_REQUEST * request + W_TARGET * target + W_FIT * fit;
            return new PlaceScore(total, request, target, fit, cong.level(), cong.percentile());
        };
    }

    /** 사용자 요구: 요청 분위기마다 min(언급 수, 3) ÷ 3 → 평균. 분위기 요청 없으면 0.5 */
    static double requestScore(List<String> atmospheres, Map<String, Integer> placeTags) {
        if (atmospheres == null || atmospheres.isEmpty()) return NEUTRAL;
        double total = 0;
        for (String a : atmospheres) {
            total += Math.min(placeTags.getOrDefault(a, 0), MENTION_FULL) / (double) MENTION_FULL;
        }
        return total / atmospheres.size();
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
