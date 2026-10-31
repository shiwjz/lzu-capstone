package com.capstone.backend.search;

import com.capstone.backend.course.CourseGenerator;
import com.capstone.backend.course.CoursePlace;
import com.capstone.backend.course.CoursePlan;
import com.capstone.backend.course.CourseRequest;
import com.capstone.backend.course.CourseRules;
import com.capstone.backend.course.PlaceScore;
import com.capstone.backend.course.PlaceScorer;
import com.capstone.backend.course.Slot;
import com.capstone.backend.course.StopInput;
import com.capstone.backend.place.PlaceStore;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 검색·코스 수정·공유 - 김예민
 *
 * 검색 한 번 흐름 (계획 문서 ①~⑥)
 * 1. 조건: 요청에 conditions 있으면 그대로(USER), 없으면 문장에서 추출(Gemini 자리, 지금 규칙)
 * 2. 날짜·시간·지역 선택기 값이 있으면 문장보다 우선, 빈 값은 기본값
 * 3. 지역 없으면 CONDITION_MISSING → 앱이 지역 다시 물어봄
 * 4. 장소 점수(윤경 모듈 자리) → 칸별 후보 → 추천 장소 10곳 + 코스 3개
 * 5. 코스는 courseId로 저장 → 수정(PUT)·공유(POST share) 가능
 */
@Service
public class SearchService {

    static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final String SHARE_BASE_URL = "https://example.com/share/";   // 배포 주소 나오면 바꾸기 (@성정헌)
    private static final Map<String, String> REGION_LABEL = Map.of("SEONGSU", "성수", "HONGDAE", "홍대", "GANGNAM", "강남");
    private static final Map<String, String> LEVEL_TEXT = Map.of("QUIET", "한산해요", "NORMAL", "보통이에요", "BUSY", "붐벼요");

    // 제외 음식 → 거를 카카오 카테고리·이름 단어 (식당만)
    private static final Map<String, List<String>> EXCLUDE_FOOD_WORDS = Map.ofEntries(
            Map.entry("매운", List.of("마라", "떡볶이", "매운", "불닭", "짬뽕")),
            Map.entry("고기", List.of("고기", "육류", "삼겹살", "갈비", "곱창", "막창", "스테이크")),
            Map.entry("해산물", List.of("해물", "생선", "회", "초밥", "조개", "해산물")),
            Map.entry("회", List.of("회", "초밥", "해물")),
            Map.entry("생선", List.of("생선", "회", "초밥")),
            Map.entry("술", List.of("술집", "호프", "이자카야", "포차", "와인바", "칵테일")),
            Map.entry("면", List.of("국수", "냉면", "라멘", "우동", "파스타")),
            Map.entry("밀가루", List.of("국수", "라멘", "우동", "파스타", "피자")),
            Map.entry("튀김", List.of("튀김", "치킨", "돈까스")),
            Map.entry("양식", List.of("양식")),
            Map.entry("중식", List.of("중식", "중국요리")),
            Map.entry("일식", List.of("일식")),
            Map.entry("한식", List.of("한식")));

    private final PlaceStore store;
    private final ConditionExtractor extractor;
    private final PlaceScorerFactory scorers;
    private final CourseStore courses;
    private final CourseGenerator generator = new CourseGenerator();
    private final AtomicInteger searchSeq = new AtomicInteger();
    private final SecureRandom random = new SecureRandom();
    Clock clock = Clock.system(KST);   // 테스트에서 날짜 고정용

    public SearchService(PlaceStore store, ConditionExtractor extractor, PlaceScorerFactory scorers,
                         CourseStore courses) {
        this.store = store;
        this.extractor = extractor;
        this.scorers = scorers;
        this.courses = courses;
    }

    // ---------- 요청 모양 ----------

    /** POST /api/search 요청. query 필수, 나머지 선택 (conditions 있으면 문장 분석 건너뜀) */
    public record SearchRequest(String query, String date, String startTime, String region,
                                SearchConditions conditions) {
    }

    /** PUT /api/courses/{courseId} 요청. 수정 후 전체 목록, 배열 순서 = 방문 순서 */
    public record UpdateRequest(String startTime, List<StopEdit> stops) {
    }

    public record StopEdit(String placeId, Integer stayMinutes) {
    }

    // ---------- 검색 ----------

    /** 로그인한 사용자의 내 설정 (검색 조건에 넣을 것만) */
    public record MyPreferences(String region, List<String> atmospheres, List<String> allergies) {
    }

    public Map<String, Object> search(SearchRequest req) {
        return search(req, null);
    }

    /** my: 로그인했으면 내 설정, 아니면 null */
    public Map<String, Object> search(SearchRequest req, MyPreferences my) {
        if (req == null || ((req.query() == null || req.query().isBlank()) && req.conditions() == null)) {
            throw ApiException.invalid("검색 문장(query)을 입력해 주세요.");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        SearchConditions c = req.conditions() != null
                ? withExtractedBy(req.conditions(), "USER")
                : extractor.extract(req.query(), now);
        if (my != null) {
            // 조건 화면에서 직접 고친 조건(USER)이면 알레르기만 더하고, 문장이면 빈 칸을 내 설정으로
            c = req.conditions() != null
                    ? c.withPreferences(null, null, my.allergies())
                    : c.withPreferences(my.region(), my.atmospheres(), my.allergies());
        }

        // 선택기 값 우선
        if (req.region() != null) c = c.withRegion(req.region());
        if (req.date() != null) c = c.withDate(req.date(), null);
        if (req.startTime() != null) c = c.withStartTime(req.startTime());

        // 기본값·검사
        if (c.date() == null) c = c.withDate(now.toLocalDate().toString(), null);
        LocalDate date = parseDate(c.date());
        c = c.withDate(date.toString(), RuleConditionExtractor.dayType(date));
        if (c.startTime() == null) c = c.withStartTime(String.format("%02d:00", (now.getHour() + 1) % 24));
        checkTime(c.startTime());
        c = c.withDefaults();
        if (c.region() == null) {
            throw new ApiException("CONDITION_MISSING", 422, "어느 지역에서 찾을까요? (성수·홍대·강남)");
        }
        if (!REGION_LABEL.containsKey(c.region())) {
            throw ApiException.invalid("region은 SEONGSU / HONGDAE / GANGNAM 중 하나예요.");
        }
        checkCodes(c);

        CourseRequest courseRequest = c.toCourseRequest();
        PlaceScorer scorer = scorers.forConditions(c);
        List<CoursePlace> places = filterExcludedFoods(store.coursePlaces(), c.excludedFoods());

        // 추천 장소: 칸별 후보를 모아서 점수 높은 순 10곳
        CourseGenerator.Candidates cands = generator.candidates(courseRequest, places, scorer);
        List<Map<String, Object>> placeCards = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < cands.order().size(); i++) {
            Slot slot = cands.order().get(i);
            int hour = cands.nominalHour().get(slot);
            for (CoursePlace p : cands.perSlot().get(i)) {
                if (seen.add(p.placeId())) {
                    placeCards.add(placeCard(p, c, hour, scorer.score(p, hour)));
                }
            }
        }
        placeCards.sort(Comparator.comparingDouble(m -> -((Score) m.get("score")).total()));
        if (placeCards.size() > 10) placeCards = new ArrayList<>(placeCards.subList(0, 10));

        // 코스 3개 → 저장
        int seq = searchSeq.incrementAndGet();
        List<CoursePlan> plans = new ArrayList<>();
        for (CoursePlan p : generator.generate(courseRequest, places, scorer)) {
            CoursePlan saved = p.withMeta("c_" + seq + "_" + p.rank(), p.rank(), p.title(), p.reason());
            courses.save(saved.courseId(), new CourseStore.Saved(c, saved));
            plans.add(saved);
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("searchId", "s_" + now.format(DateTimeFormatter.BASIC_ISO_DATE) + "_" + String.format("%04d", seq));
        data.put("query", req.query());
        data.put("conditions", c.toMap());
        data.put("places", placeCards);
        data.put("courses", plans);
        data.put("notice", plans.isEmpty() ? "조건에 맞는 코스를 찾지 못했어요. 시간이나 조건을 바꿔 보세요." : null);
        return data;
    }

    /** 장소 카드 점수 (응답 JSON용, 소수 둘째 자리) */
    public record Score(double total, double request, double target, double congestion) {
    }

    private Map<String, Object> placeCard(CoursePlace cp, SearchConditions c, int hour, PlaceScore s) {
        PlaceStore.Place p = store.find(cp.placeId()).orElseThrow();
        Map<String, Object> cong = new LinkedHashMap<>();
        cong.put("hour", Math.floorMod(hour, 24));
        cong.put("level", s.level());
        cong.put("percentile", s.percentile());
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("placeId", p.placeId());
        m.put("name", p.name());
        m.put("category", p.category());
        m.put("region", p.region());
        m.put("address", p.displayAddress());
        m.put("lat", p.lat());
        m.put("lng", p.lng());
        m.put("phone", p.phone());
        m.put("placeUrl", p.placeUrl());
        m.put("tags", p.tags());
        m.put("congestion", cong);
        m.put("score", new Score(CourseRules.round2(s.total()), CourseRules.round2(s.request()),
                CourseRules.round2(s.target()), CourseRules.round2(s.congestionFit())));
        m.put("reason", reason(p, c, Math.floorMod(hour, 24), s.level().name()));
        return m;
    }

    /** 장소 카드 추천 이유 한 줄: 언급 많은 태그(원하는 분위기 우선) + 그 시각 혼잡도 */
    private static String reason(PlaceStore.Place p, SearchConditions c, int hour, String level) {
        List<PlaceStore.Tag> tags = new ArrayList<>(p.tags());
        tags.sort(Comparator.comparingInt(t -> -t.mentions()));
        String top = tags.stream().map(PlaceStore.Tag::tag).filter(c.atmospheres()::contains).findFirst()
                .orElse(tags.isEmpty() ? null : tags.get(0).tag());
        String day = c.dayType().equals("WEEKEND") ? "주말" : "평일";
        String where = day + " " + hour + "시 주변이 " + LEVEL_TEXT.get(level);
        return top == null ? where : "블로그 후기에서 '" + top + "' 언급이 많고, " + where;   // 태그 없는 곳은 혼잡도만
    }

    // ---------- 코스 수정 ----------

    public Map<String, Object> updateCourse(String courseId, UpdateRequest req) {
        CourseStore.Saved saved = courses.find(courseId)
                .orElseThrow(() -> ApiException.notFound("COURSE_NOT_FOUND", "코스를 찾을 수 없어요."));
        if (req == null || req.stops() == null || req.stops().isEmpty()) {
            throw ApiException.invalid("stops에 장소를 1곳 이상 넣어 주세요.");
        }
        SearchConditions c = saved.conditions();
        if (req.startTime() != null) {
            checkTime(req.startTime());
            c = c.withStartTime(req.startTime());
        }
        List<StopInput> stops = new ArrayList<>();
        Map<String, CoursePlace> byId = new HashMap<>();
        for (StopEdit s : req.stops()) {
            PlaceStore.Place p = store.find(s.placeId())
                    .orElseThrow(() -> ApiException.notFound("PLACE_NOT_FOUND", "장소를 찾을 수 없어요: " + s.placeId()));
            int stay = s.stayMinutes() == null ? CourseRules.stayMinutes(p.category()) : s.stayMinutes();
            if (stay < 10 || stay > 300) {
                throw ApiException.invalid("체류 시간은 10~300분 사이로 넣어 주세요.");
            }
            CoursePlace cp = p.toCoursePlace();
            stops.add(new StopInput(cp, stay));
            byId.put(cp.placeId(), cp);
        }
        CourseRequest courseRequest = c.toCourseRequest();
        PlaceScorer scorer = scorers.forConditions(c);
        CoursePlan recalculated = generator.recalculate(courseRequest, stops, scorer, byId);
        CoursePlan plan = recalculated.withMeta(courseId, null, recalculated.title(), recalculated.reason());
        courses.save(courseId, new CourseStore.Saved(c, plan));

        Map<String, Object> data = courseMap(plan);
        data.put("warnings", generator.warnings(plan, courseRequest.crowdPreference()));
        return data;
    }

    // ---------- 공유 ----------

    public Map<String, Object> createShare(String courseId) {
        CourseStore.Saved saved = courses.find(courseId)
                .orElseThrow(() -> ApiException.notFound("COURSE_NOT_FOUND", "코스를 찾을 수 없어요."));
        String code;
        do {
            code = randomCode();
        } while (courses.hasShare(code));
        OffsetDateTime createdAt = OffsetDateTime.now(clock).truncatedTo(ChronoUnit.SECONDS);
        courses.saveShare(new CourseStore.Share(code, createdAt, saved.conditions(), saved.plan()));

        CoursePlan plan = saved.plan();
        StringBuilder text = new StringBuilder("[오디가] " + saved.conditions().date() + " " + plan.startAt() + " "
                + REGION_LABEL.get(saved.conditions().region()) + " 코스");
        for (CoursePlan.Stop s : plan.stops()) {
            text.append('\n').append(s.order()).append(". ").append(s.arriveAt()).append(' ').append(s.name());
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("shareCode", code);
        data.put("shareUrl", SHARE_BASE_URL + code);
        data.put("shareText", text.toString());
        return data;
    }

    public Map<String, Object> viewShare(String shareCode) {
        CourseStore.Share s = courses.findShare(shareCode)
                .orElseThrow(() -> ApiException.notFound("SHARE_NOT_FOUND", "공유 코스를 찾을 수 없어요."));
        Map<String, Object> cond = new LinkedHashMap<>();
        cond.put("region", s.conditions().region());
        cond.put("date", s.conditions().date());
        cond.put("dayType", s.conditions().dayType());
        cond.put("startTime", s.conditions().startTime());
        cond.put("partySize", s.conditions().partySize());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("shareCode", s.shareCode());
        data.put("createdAt", s.createdAt().toString());
        data.put("conditions", cond);
        data.put("course", s.course());
        return data;
    }

    // ---------- 도우미 ----------

    static Map<String, Object> courseMap(CoursePlan p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("courseId", p.courseId());
        m.put("rank", p.rank());
        m.put("title", p.title());
        m.put("reason", p.reason());
        m.put("startAt", p.startAt());
        m.put("endAt", p.endAt());
        m.put("totalMinutes", p.totalMinutes());
        m.put("totalWalkMinutes", p.totalWalkMinutes());
        m.put("totalDistanceMeters", p.totalDistanceMeters());
        m.put("score", p.score());
        m.put("stops", p.stops());
        return m;
    }

    private static SearchConditions withExtractedBy(SearchConditions c, String by) {
        return new SearchConditions(c.region(), c.date(), c.dayType(), c.startTime(), c.partySize(), c.categories(),
                c.atmospheres(), c.crowdPreference(), c.allergies(), c.gender(), c.ageGroup(), c.companionType(),
                c.excludedFoods(), c.extractedBy() == null ? by : c.extractedBy());
    }

    private static List<CoursePlace> filterExcludedFoods(List<CoursePlace> places, List<String> excluded) {
        if (excluded.isEmpty()) return places;
        List<String> words = excluded.stream()
                .flatMap(e -> EXCLUDE_FOOD_WORDS.getOrDefault(e, List.of(e)).stream()).toList();
        return places.stream()
                .filter(p -> !p.category().equals("FOOD")
                        || words.stream().noneMatch(w -> p.kakaoCategory().contains(w) || p.name().contains(w)))
                .toList();
    }

    private static LocalDate parseDate(String date) {
        try {
            return LocalDate.parse(date);
        } catch (DateTimeParseException e) {
            throw ApiException.invalid("date는 YYYY-MM-DD 형식이에요.");
        }
    }

    private static void checkTime(String hhmm) {
        if (!hhmm.matches("([01]\\d|2[0-3]):[0-5]\\d")) {
            throw ApiException.invalid("startTime은 HH:mm 형식이에요.");
        }
    }

    private static final Set<String> CROWD = Set.of("QUIET", "DEFAULT", "LIVELY");
    private static final Set<String> CATEGORY = Set.of("FOOD", "CAFE", "CULTURE", "ACTIVITY", "EXPERIENCE",
            "SHOPPING", "TOUR", "NATURE", "SNACK");
    private static final Set<String> ALLERGY = Set.of("SHELLFISH", "SEAFOOD", "PEANUT", "MILK", "EGG", "WHEAT");

    private static void checkCodes(SearchConditions c) {
        if (!CROWD.contains(c.crowdPreference())) throw ApiException.invalid("crowdPreference 값을 확인해 주세요.");
        if (!CATEGORY.containsAll(c.categories())) throw ApiException.invalid("categories 값을 확인해 주세요.");
        if (!ALLERGY.containsAll(c.allergies())) throw ApiException.invalid("allergies 값을 확인해 주세요.");
        if (c.partySize() < 1 || c.partySize() > 20) throw ApiException.invalid("partySize는 1~20명이에요.");
    }

    private String randomCode() {
        String chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < 6; i++) b.append(chars.charAt(random.nextInt(chars.length())));
        return b.toString();
    }
}
