package com.capstone.backend.search;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.CrowdPreference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * 장소 점수 모듈 테스트 - 윤경 test_place_score.py 10개 그대로 Java로 (예민)
 * - 파이썬이랑 같은 입력 → 같은 값이면 옮기기 성공
 * - 실행: ./gradlew test --tests "com.capstone.backend.search.PlaceScoreModelTest"
 */
class PlaceScoreModelTest {

    private static final Map<String, Double> AVG = Map.of("female_ratio", 0.5, "age_20s", 0.25, "age_30s", 0.25);       // 지역 평균
    private static final Map<String, Double> CELL = Map.of("female_ratio", 0.6, "age_20s", 0.5, "age_30s", 0.2);        // 이 칸
    private static final Map<String, Double> CLUSTER = Map.of("female_ratio", 0.4, "age_20s", 0.3, "age_30s", 0.3);     // 같은 유형 평균
    // 반반 섞으면 → 여성 0.5, 20대 0.4, 30대 0.25

    private static final PlaceScoreModel.Shares CELL_SHARES = CELL::get;

    private static void near(double expected, double actual) {
        assertEquals(expected, actual, 1e-4);
    }

    @Test
    @DisplayName("1~4 사용자 요구: 언급 충분 1 / 2개 중 1개 0.5 / 언급 1번 1/3 / 분위기 없음 0.5")
    void request() {
        near(1.0, PlaceScoreModel.requestScore(List.of("조용함"), Map.of("조용함", 3)));
        near(0.5, PlaceScoreModel.requestScore(List.of("조용함", "데이트"), Map.of("조용함", 3)));
        near(1.0 / 3, PlaceScoreModel.requestScore(List.of("조용함"), Map.of("조용함", 1)));
        near(0.5, PlaceScoreModel.requestScore(List.of(), Map.of("조용함", 3)));
    }

    @Test
    @DisplayName("5~8 타깃 특성: 유형 반영 여20대 1.6/2.6, 남30대 0.5, 유형 없음 2.4/3.4, 성별·연령 없음 0.5")
    void target() {
        near(1.6 / 2.6, PlaceScoreModel.targetScore(CELL_SHARES, CLUSTER, AVG, "F", "20s"));
        near(0.5, PlaceScoreModel.targetScore(CELL_SHARES, CLUSTER, AVG, "M", "30s"));
        near(2.4 / 3.4, PlaceScoreModel.targetScore(CELL_SHARES, null, AVG, "F", "20s"));
        near(0.5, PlaceScoreModel.targetScore(CELL_SHARES, CLUSTER, AVG, null, null));
    }

    @Test
    @DisplayName("9 혼잡도 적합도: 조용한 곳 원하는데 혼잡 0.1")
    void fit() {
        near(0.1, PlaceScoreModel.congestionFit(CrowdPreference.QUIET, CongestionLevel.BUSY));
    }

    @Test
    @DisplayName("10 장소 점수 전체: 0.45×1.0 + 0.30×(1.6/2.6) + 0.25×1.0 = 0.8846")
    void total() {
        double req = PlaceScoreModel.requestScore(List.of("조용함"), Map.of("조용함", 3));
        double tgt = PlaceScoreModel.targetScore(CELL_SHARES, CLUSTER, AVG, "F", "20s");
        double fit = PlaceScoreModel.congestionFit(CrowdPreference.QUIET, CongestionLevel.QUIET);
        double total = PlaceScoreModel.W_REQUEST * req + PlaceScoreModel.W_TARGET * tgt + PlaceScoreModel.W_FIT * fit;
        near(0.45 * 1.0 + 0.30 * (1.6 / 2.6) + 0.25 * 1.0, total);
    }
}
