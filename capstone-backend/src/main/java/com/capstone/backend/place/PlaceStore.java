package com.capstone.backend.place;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.CoursePlace;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 장소·혼잡도 저장소 - 김예민
 * - 지금: resources/data/places.tsv, congestion.tsv, cell_profile.tsv 읽음 (mocks/generate_mocks.py가 만듦)
 *   · 장소: 예린 output/places.csv (분류 보정·영어 코드) + 셀 번호 + 예린 블로그 태그(place_tag.csv)
 *     + 음식 큰 종류·세부 (v0.5, 예린 place_cuisine.csv 오기 전엔 임시 분류)
 *   · 혼잡도: 윤경 cell_congestion.csv (sameTime = 같은 시간끼리 비교, allDay = 하루 전체 비교)
 *     → 서울시 생활인구 버전 쓰려면 application.properties odiga.congestion-file=congestion_seoul.tsv
 *   · 셀 성·연령 구성 + 유형(군집): 윤경 cell_gender_age_fake.csv, cell_cluster.csv (타깃 특성 점수용)
 * - ERD 확정되면 이 클래스 안쪽만 DB 조회로 바꾸기 (밖에서 쓰는 메서드는 그대로)
 * - 장소·혼잡도 파일 바뀌면 python mocks/generate_mocks.py 다시 실행
 */
@Component
public class PlaceStore {

    public record Tag(String tag, int mentions) {
    }

    public record Place(String placeId, String name, String region, String category, String kakaoCategory,
                        double lat, double lng, String cellId, List<Tag> tags,
                        String address, String roadAddress, String phone, String placeUrl,
                        String cuisine, String cuisineDetail) {

        public CoursePlace toCoursePlace() {
            return new CoursePlace(placeId, name, region, category, kakaoCategory, lat, lng,
                    tags.stream().map(Tag::tag).toList(), cuisine, cuisineDetail);
        }

        /** 화면 표시용 주소 (도로명 우선) */
        public String displayAddress() {
            return roadAddress != null ? roadAddress : address;
        }
    }

    /** 50m 격자 칸 가운데 좌표 (11주차, 혼잡 레이더용 - resources/data/cells.tsv, 윤경 grid_cells.csv) */
    public record Cell(String cellId, String region, double lat, double lng) {
    }

    /** 혼잡도 한 칸. percentile 0 = 가장 한산, 100 = 가장 붐빔 */
    public record Congestion(int hour, CongestionLevel level, int percentile) {
    }

    /** 셀 성·연령 구성 (비율 0~1). cluster = 셀 유형(군집 번호), 없으면 null */
    public record CellProfile(String cellId, String region, Integer cluster, double femaleRatio, Map<String, Double> ages) {

        /** "female_ratio", "age_20s" 같은 윤경 파일 컬럼 이름으로 값 꺼내기 */
        public double value(String column) {
            return column.equals("female_ratio") ? femaleRatio : ages.getOrDefault(column, 0.0);
        }
    }

    static final List<String> PROFILE_COLUMNS = List.of("female_ratio", "age_10s", "age_20s", "age_30s",
            "age_40s", "age_50s", "age_60s");

    public enum Basis {
        SAME_TIME,   // 추천·코스용: 같은 지역·요일·시간끼리 비교
        ALL_DAY      // 장소 상세 그래프용: 하루 전체 비교
    }

    private final List<Place> places;
    private final Map<String, Place> byId = new LinkedHashMap<>();
    private final List<CoursePlace> coursePlaces;
    private final Map<String, String[][]> congestion = new HashMap<>();   // "cellId|WEEKEND" → [basis][hour]
    private final Map<String, CellProfile> cellProfiles = new HashMap<>();
    private final Map<Integer, Map<String, Double>> clusterAvg = new HashMap<>();   // 유형별 평균 비율
    private final Map<String, Map<String, Double>> regionAvg = new HashMap<>();     // 지역별 평균 비율
    private final List<Cell> cells = new ArrayList<>();
    private final String congestionFile;

    /** 테스트용: 기본 혼잡도(가짜 유동인구, LG 데이터 모양) */
    public PlaceStore() {
        this("congestion.tsv");
    }

    /** 서버: odiga.congestion-file 설정으로 혼잡도 파일 고름 (congestion.tsv / congestion_seoul.tsv) */
    public PlaceStore(String congestionFile) {
        this("/data/places.tsv", "/data/" + congestionFile, "/data/cell_profile.tsv", congestionFile);
    }

    /**
     * 서버 시작할 때 쓰는 것
     * - odiga.data-dir(환경변수 ODIGA_DATA_DIR)가 있으면 LG 진짜 데이터로 만든 혼잡도·성연령을 그 폴더에서 읽음
     *   (lg/make_lg_data.py 결과 congestion_lg.tsv, cell_profile_lg.tsv - 깃허브·jar에는 안 들어감, 11/5 보안)
     * - 없으면 지금처럼 jar 안 가짜 데이터 (odiga.congestion-file)
     */
    @Autowired
    public PlaceStore(@Value("${odiga.congestion-file:congestion.tsv}") String congestionFile,
                      @Value("${odiga.data-dir:}") String dataDir) {
        this("/data/places.tsv",
                dataDir.isBlank() ? "/data/" + congestionFile : FILE + Path.of(dataDir, "congestion_lg.tsv"),
                dataDir.isBlank() ? "/data/cell_profile.tsv" : FILE + Path.of(dataDir, "cell_profile_lg.tsv"),
                dataDir.isBlank() ? congestionFile : "congestion_lg.tsv (외부 폴더)");
    }

    private static final String FILE = "file:";

    PlaceStore(String placesPath, String congestionPath, String profilePath, String congestionFile) {
        this.congestionFile = congestionFile;
        List<Place> loaded = new ArrayList<>();
        for (String[] r : readTsv(placesPath, 15)) {
            List<Tag> tags = new ArrayList<>();
            if (!r[8].isEmpty()) {
                for (String t : r[8].split("\\|")) {
                    int colon = t.lastIndexOf(':');
                    tags.add(new Tag(t.substring(0, colon), Integer.parseInt(t.substring(colon + 1))));
                }
            }
            Place p = new Place(r[0], r[1], r[2], r[3], r[4], Double.parseDouble(r[5]), Double.parseDouble(r[6]),
                    r[7], List.copyOf(tags), blankToNull(r[9]), blankToNull(r[10]), blankToNull(r[11]),
                    blankToNull(r[12]), blankToNull(r[13]), blankToNull(r[14]));
            loaded.add(p);
            byId.put(p.placeId(), p);
        }
        places = List.copyOf(loaded);
        coursePlaces = places.stream().map(Place::toCoursePlace).toList();
        for (String[] r : readTsv(congestionPath, 4)) {
            congestion.put(r[0] + "|" + r[1], new String[][]{r[2].split(" "), r[3].split(" ")});
        }
        loadProfiles(profilePath);
        // 셀 좌표는 LG 데이터가 아니라 격자 정보라 항상 jar 안 파일 (없으면 레이더만 빈 목록)
        if (PlaceStore.class.getResource("/data/cells.tsv") != null) {
            for (String[] r : readTsv("/data/cells.tsv", 4)) {
                cells.add(new Cell(r[0], r[1], Double.parseDouble(r[2]), Double.parseDouble(r[3])));
            }
        }
    }

    /** 지역의 격자 칸 목록 */
    public List<Cell> cells(String region) {
        return cells.stream().filter(c -> c.region().equals(region)).toList();
    }

    /** 칸 하나의 혼잡도 (장소 없는 칸·데이터 없는 시간이면 빈 값) */
    public Optional<Congestion> cellCongestion(String cellId, String dayType, int hour, Basis basis) {
        String[][] row = congestion.get(cellId + "|" + dayType);
        int h = Math.floorMod(hour, 24);
        if (row == null || row[basis.ordinal()][h].equals("-")) return Optional.empty();
        return Optional.of(parse(row[basis.ordinal()][h], h));
    }

    /** 셀 성·연령 + 유형·지역 평균 (윤경 load_target_data랑 같은 계산: 단순 평균) */
    private void loadProfiles(String path) {
        Map<Integer, List<CellProfile>> byCluster = new HashMap<>();
        Map<String, List<CellProfile>> byRegion = new HashMap<>();
        for (String[] r : readTsv(path, 3 + PROFILE_COLUMNS.size())) {
            Map<String, Double> ages = new LinkedHashMap<>();
            for (int i = 1; i < PROFILE_COLUMNS.size(); i++) {
                ages.put(PROFILE_COLUMNS.get(i), Double.parseDouble(r[3 + i]));
            }
            Integer cluster = r[2].isEmpty() ? null : Integer.valueOf(r[2]);
            CellProfile cp = new CellProfile(r[0], r[1], cluster, Double.parseDouble(r[3]), Map.copyOf(ages));
            cellProfiles.put(cp.cellId(), cp);
            if (cluster != null) byCluster.computeIfAbsent(cluster, k -> new ArrayList<>()).add(cp);
            byRegion.computeIfAbsent(cp.region(), k -> new ArrayList<>()).add(cp);
        }
        byCluster.forEach((k, list) -> clusterAvg.put(k, average(list)));
        byRegion.forEach((k, list) -> regionAvg.put(k, average(list)));
    }

    private static Map<String, Double> average(List<CellProfile> list) {
        Map<String, Double> avg = new HashMap<>();
        for (String col : PROFILE_COLUMNS) {
            double sum = 0;
            for (CellProfile cp : list) sum += cp.value(col);
            avg.put(col, sum / list.size());
        }
        return Map.copyOf(avg);
    }

    /** 지금 쓰는 혼잡도 파일 이름 (congestion.tsv = 가짜 유동인구, congestion_seoul.tsv = 서울시 생활인구) */
    public String congestionFile() {
        return congestionFile;
    }

    /** 장소가 있는 셀의 성·연령 (없으면 null → 타깃 특성 중립 0.5) */
    public CellProfile cellProfile(String placeId) {
        Place p = byId.get(placeId);
        return p == null ? null : cellProfiles.get(p.cellId());
    }

    /** 같은 유형 셀들의 평균 비율 (유형 없으면 null) */
    public Map<String, Double> clusterAverage(Integer cluster) {
        return cluster == null ? null : clusterAvg.get(cluster);
    }

    /** 지역 평균 비율 */
    public Map<String, Double> regionAverage(String region) {
        return regionAvg.get(region);
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
        return parse(token, h);
    }

    private static Congestion parse(String token, int h) {
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
        InputStream in;
        if (path.startsWith(FILE)) {
            try {
                in = Files.newInputStream(Path.of(path.substring(FILE.length())));
            } catch (IOException e) {
                throw new IllegalStateException(path + " 없음 → ODIGA_DATA_DIR 폴더에 lg/make_lg_data.py 결과가 있는지 확인", e);
            }
        } else {
            in = PlaceStore.class.getResourceAsStream(path);
        }
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
