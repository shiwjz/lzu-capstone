package com.capstone.backend.search;

import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.CrowdPreference;
import com.capstone.backend.course.PlaceScore;
import com.capstone.backend.course.PlaceScorer;
import com.capstone.backend.place.PlaceStore;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.StringJoiner;

/**
 * 임시 장소 점수 (윤경 장소 점수 모듈 오기 전까지) - 김예민
 * - 사용자 요구: 분위기 태그 맞으면 0.9대, 아니면 0.5대 (태그도 아직 가짜)
 * - 타깃 특성: 장소·인원별 고정 랜덤값 (성·연령 데이터 전)
 * - 혼잡도 적합도: 윤경 혼잡도(같은 시간끼리 비교) → 혼잡 선호별 구간 점수 ← 이것만 진짜 데이터
 * - generate_mocks.py place_score랑 같은 계산 → 가짜 JSON이랑 결과 같음
 */
@Component
public class TemporaryPlaceScorerFactory implements PlaceScorerFactory {

    private final PlaceStore store;

    public TemporaryPlaceScorerFactory(PlaceStore store) {
        this.store = store;
    }

    @Override
    public PlaceScorer forConditions(SearchConditions c) {
        CrowdPreference crowd = CrowdPreference.valueOf(c.crowdPreference());
        return (place, hour) -> {
            boolean match = c.atmospheres().stream().anyMatch(place.tags()::contains);
            double request = 0.5 + (match ? 0.4 : 0.0) + 0.1 * hash(place.placeId(), "req");
            double target = 0.5 + 0.45 * hash(place.placeId(), "tgt", c.partySize());
            PlaceStore.Congestion cong = store.congestion(place.placeId(), c.dayType(), hour, PlaceStore.Basis.SAME_TIME);
            double fit = CourseRules.congestionFit(crowd, cong.level());
            double total = 0.45 * request + 0.30 * target + 0.25 * fit;
            return new PlaceScore(total, request, target, fit, cong.level(), cong.percentile());
        };
    }

    /** 같은 입력이면 항상 같은 0~1 값 (파이썬 h(): md5 앞 8자리 ÷ 0xFFFFFFFF) */
    static double hash(Object... parts) {
        StringJoiner joined = new StringJoiner("|");
        for (Object part : parts) {
            joined.add(String.valueOf(part));
        }
        try {
            byte[] d = MessageDigest.getInstance("MD5").digest(joined.toString().getBytes(StandardCharsets.UTF_8));
            long v = 0;
            for (int i = 0; i < 4; i++) {
                v = (v << 8) | (d[i] & 0xff);
            }
            return v / (double) 0xFFFFFFFFL;
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
