package com.capstone.backend.course;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;

/**
 * 테스트용 가짜 데이터 (/api/dev/courses에서 사용) - 김예민
 * - 파일: resources/dev/places.tsv, congestion.tsv (mocks/generate_mocks.py가 같이 만듦)
 * - 장소: 예린 places.csv 정리본 / 혼잡도: 윤경 congestion_fake.csv (pct_same_time)
 * - 태그·사용자 요구·타깃 점수: 아직 가짜 (generate_mocks.py랑 같은 해시 계산) → 가짜 JSON 코스랑 결과 똑같음
 * - 장소 테이블(정헌)·점수 모듈(윤경) 생기면 이 클래스 지우고 진짜 데이터로 교체
 */
public final class DevCourseData {

    private final List<CoursePlace> places;
    private final Map<String, String> cellOf;            // placeId → cellId
    private final Map<String, String[]> congestion;      // "cellId|WEEKEND" → 0~23시 ("Q25" = 한산 25%)

    private DevCourseData(List<CoursePlace> places, Map<String, String> cellOf, Map<String, String[]> congestion) {
        this.places = places;
        this.cellOf = cellOf;
        this.congestion = congestion;
    }

    public List<CoursePlace> places() {
        return places;
    }

    public static DevCourseData load() {
        List<CoursePlace> places = new ArrayList<>();
        Map<String, String> cellOf = new HashMap<>();
        for (String[] r : readTsv("/dev/places.tsv")) {
            // placeId name region category kakaoCategory lat lng cellId tags
            List<String> tags = r[8].isEmpty() ? List.of() : List.of(r[8].split("\\|"));
            places.add(new CoursePlace(r[0], r[1], r[2], r[3], r[4],
                    Double.parseDouble(r[5]), Double.parseDouble(r[6]), tags));
            cellOf.put(r[0], r[7]);
        }
        Map<String, String[]> congestion = new HashMap<>();
        for (String[] r : readTsv("/dev/congestion.tsv")) {
            congestion.put(r[0] + "|" + r[1], r[2].split(" "));
        }
        return new DevCourseData(List.copyOf(places), cellOf, congestion);
    }

    /**
     * 가짜 장소 점수 (generate_mocks.py place_score랑 같은 계산)
     * - 사용자 요구: 분위기 태그 맞으면 0.9대, 아니면 0.5대
     * - 타깃: 장소·인원별 고정 랜덤값
     * - 혼잡도: 윤경 데이터에서 도착 시각 값 → 혼잡 선호 적합도
     */
    public PlaceScorer scorer(CourseRequest request, String dayType) {
        return (place, hour) -> {
            boolean match = request.atmospheres().stream().anyMatch(place.tags()::contains);
            double req = 0.5 + (match ? 0.4 : 0.0) + 0.1 * hash(place.placeId(), "req");
            double target = 0.5 + 0.45 * hash(place.placeId(), "tgt", request.partySize());

            String token = congestion.get(cellOf.get(place.placeId()) + "|" + dayType)[hour % 24];
            CongestionLevel level = switch (token.charAt(0)) {
                case 'Q' -> CongestionLevel.QUIET;
                case 'N' -> CongestionLevel.NORMAL;
                case 'B' -> CongestionLevel.BUSY;
                default -> throw new IllegalStateException("혼잡도 없음: " + place.placeId() + " " + hour + "시");
            };
            int percentile = Integer.parseInt(token.substring(1));
            double fit = CourseRules.congestionFit(request.crowdPreference(), level);

            double total = 0.45 * req + 0.30 * target + 0.25 * fit;
            return new PlaceScore(total, req, target, fit, level, percentile);
        };
    }

    /** 같은 입력이면 항상 같은 0~1 값 (파이썬 h() 그대로: md5 앞 8자리 ÷ 0xFFFFFFFF) */
    static double hash(Object... parts) {
        StringJoiner joined = new StringJoiner("|");
        for (Object part : parts) {
            joined.add(String.valueOf(part));
        }
        try {
            byte[] digest = MessageDigest.getInstance("MD5").digest(joined.toString().getBytes(StandardCharsets.UTF_8));
            long value = 0;
            for (int i = 0; i < 4; i++) {
                value = (value << 8) | (digest[i] & 0xff);
            }
            return value / (double) 0xFFFFFFFFL;
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static List<String[]> readTsv(String path) {
        InputStream in = DevCourseData.class.getResourceAsStream(path);
        if (in == null) {
            throw new IllegalStateException(path + " 없음 → python mocks/generate_mocks.py 먼저 실행");
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            List<String[]> rows = new ArrayList<>();
            reader.readLine();   // 헤더
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isBlank()) {
                    rows.add(Arrays.copyOf(line.split("\t", -1), 9));
                }
            }
            return rows;
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
