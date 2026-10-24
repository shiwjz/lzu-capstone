package com.capstone.backend.place;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.CoursePlace;
import org.springframework.stereotype.Component;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 장소·혼잡도 저장소 - 김예민
 * - 지금: resources/data/places.tsv, congestion.tsv 읽음 (mocks/generate_mocks.py가 만듦)
 *   · 장소: 예린 output/places.csv (분류 보정·영어 코드) + 셀 번호 + 가짜 태그
 *   · 혼잡도: 윤경 cell_congestion.csv (sameTime = 같은 시간끼리 비교, allDay = 하루 전체 비교)
 * - ERD 확정되면 이 클래스 안쪽만 DB 조회로 바꾸기 (밖에서 쓰는 메서드는 그대로)
 * - 장소·혼잡도 파일 바뀌면 python mocks/generate_mocks.py 다시 실행
 */
@Component
public class PlaceStore {

    public record Tag(String tag, int mentions) {
    }

    public record Place(String placeId, String name, String region, String category, String kakaoCategory,
                        double lat, double lng, String cellId, List<Tag> tags,
                        String address, String roadAddress, String phone, String placeUrl) {

        public CoursePlace toCoursePlace() {
            return new CoursePlace(placeId, name, region, category, kakaoCategory, lat, lng,
                    tags.stream().map(Tag::tag).toList());
        }

        /** 화면 표시용 주소 (도로명 우선) */
        public String displayAddress() {
            return roadAddress != null ? roadAddress : address;
        }
    }

    /** 혼잡도 한 칸. percentile 0 = 가장 한산, 100 = 가장 붐빔 */
    public record Congestion(int hour, CongestionLevel level, int percentile) {
    }

    public enum Basis {
        SAME_TIME,   // 추천·코스용: 같은 지역·요일·시간끼리 비교
        ALL_DAY      // 장소 상세 그래프용: 하루 전체 비교
    }

    private final List<Place> places;
    private final Map<String, Place> byId = new LinkedHashMap<>();
    private final List<CoursePlace> coursePlaces;
    private final Map<String, String[][]> congestion = new HashMap<>();   // "cellId|WEEKEND" → [basis][hour]

    public PlaceStore() {
        this("/data/places.tsv", "/data/congestion.tsv");
    }

    PlaceStore(String placesPath, String congestionPath) {
        List<Place> loaded = new ArrayList<>();
        for (String[] r : readTsv(placesPath, 13)) {
            List<Tag> tags = new ArrayList<>();
            if (!r[8].isEmpty()) {
                for (String t : r[8].split("\\|")) {
                    int colon = t.lastIndexOf(':');
                    tags.add(new Tag(t.substring(0, colon), Integer.parseInt(t.substring(colon + 1))));
                }
            }
            Place p = new Place(r[0], r[1], r[2], r[3], r[4], Double.parseDouble(r[5]), Double.parseDouble(r[6]),
                    r[7], List.copyOf(tags), blankToNull(r[9]), blankToNull(r[10]), blankToNull(r[11]),
                    blankToNull(r[12]));
            loaded.add(p);
            byId.put(p.placeId(), p);
        }
        places = List.copyOf(loaded);
        coursePlaces = places.stream().map(Place::toCoursePlace).toList();
        for (String[] r : readTsv(congestionPath, 4)) {
            congestion.put(r[0] + "|" + r[1], new String[][]{r[2].split(" "), r[3].split(" ")});
        }
    }

    public List<Place> all() {
        return places;
    }

    /** 코스 생성용 (파일 순서 그대로 → 점수 같으면 이 순서로 정렬됨) */
    public List<CoursePlace> coursePlaces() {
        return coursePlaces;
    }

    public Optional<Place> find(String placeId) {
        return Optional.ofNullable(byId.get(placeId));
    }

    /** 지역·카테고리로 장소 목록 (category null이면 전부) */
    public List<Place> list(String region, String category) {
        return places.stream()
                .filter(p -> p.region().equals(region))
                .filter(p -> category == null || p.category().equals(category))
                .toList();
    }

    /** 장소의 (주중/주말, 시각) 혼잡도. hour는 24 넘어가도 됨 (자정 넘는 코스) */
    public Congestion congestion(String placeId, String dayType, int hour, Basis basis) {
        Place p = byId.get(placeId);
        String[][] row = p == null ? null : congestion.get(p.cellId() + "|" + dayType);
        int h = Math.floorMod(hour, 24);
        String token = row == null ? "-" : row[basis.ordinal()][h];
        if (token.equals("-")) {
            throw new IllegalStateException("혼잡도 없음: " + placeId + " " + dayType + " " + h + "시");
        }
        CongestionLevel level = switch (token.charAt(0)) {
            case 'Q' -> CongestionLevel.QUIET;
            case 'N' -> CongestionLevel.NORMAL;
            default -> CongestionLevel.BUSY;
        };
        return new Congestion(h, level, Integer.parseInt(token.substring(1)));
    }

    private static String blankToNull(String s) {
        return s == null || s.isEmpty() ? null : s;
    }

    private static List<String[]> readTsv(String path, int columns) {
        InputStream in = PlaceStore.class.getResourceAsStream(path);
        if (in == null) {
            throw new IllegalStateException(path + " 없음 → 저장소 맨 위에서 python mocks/generate_mocks.py 실행");
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            List<String[]> rows = new ArrayList<>();
            reader.readLine();   // 헤더
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isBlank()) {
                    rows.add(Arrays.copyOf(line.split("\t", -1), columns));
                }
            }
            return rows;
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
