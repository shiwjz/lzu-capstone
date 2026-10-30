package com.capstone.backend.place;

import com.capstone.backend.search.ApiBody;
import com.capstone.backend.search.ApiException;
import com.capstone.backend.search.RuleConditionExtractor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 장소 API - 김예민 (원래 정헌 담당, 9주차에 가져옴)
 * - GET /api/places?region=SEONGSU&category=CAFE&date=2026-10-31&hour=15   홈 지도 '내 주변 장소' (v0.3 추가)
 * - GET /api/places/{placeId}?date=2026-10-31                               장소 상세 + 시간대별 혼잡도
 * - 지금은 PlaceStore(파일), ERD 확정 후 DB로 바뀌어도 이 API 모양은 그대로
 */
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/places")
public class PlaceController {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final Set<String> REGIONS = Set.of("SEONGSU", "HONGDAE", "GANGNAM");
    private static final Set<String> CATEGORIES = Set.of("FOOD", "CAFE", "CULTURE", "ACTIVITY", "EXPERIENCE",
            "SHOPPING", "TOUR", "NATURE", "SNACK");

    private final PlaceStore store;

    public PlaceController(PlaceStore store) {
        this.store = store;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> list(
            @RequestParam(name = "region") String region,
            @RequestParam(name = "category", required = false) String category,
            @RequestParam(name = "date", required = false) String date,
            @RequestParam(name = "hour", required = false) Integer hour,
            @RequestParam(name = "limit", defaultValue = "50") int limit) {
        try {
            if (!REGIONS.contains(region)) throw ApiException.invalid("region은 SEONGSU / HONGDAE / GANGNAM 중 하나예요.");
            if (category != null && !CATEGORIES.contains(category)) throw ApiException.invalid("category 값을 확인해 주세요.");
            LocalDateTime now = LocalDateTime.now(KST);
            LocalDate day = parseDate(date, now.toLocalDate());
            String dayType = RuleConditionExtractor.dayType(day);
            int h = hour == null ? now.getHour() : Math.floorMod(hour, 24);
            List<Map<String, Object>> items = new ArrayList<>();
            for (PlaceStore.Place p : store.list(region, category)) {
                if (items.size() >= Math.max(1, Math.min(limit, 500))) break;
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("placeId", p.placeId());
                m.put("name", p.name());
                m.put("category", p.category());
                m.put("region", p.region());
                m.put("address", p.displayAddress());
                m.put("lat", p.lat());
                m.put("lng", p.lng());
                m.put("tags", p.tags());
                m.put("congestion", store.congestion(p.placeId(), dayType, h, PlaceStore.Basis.SAME_TIME));
                items.add(m);
            }
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("date", day.toString());
            data.put("dayType", dayType);
            data.put("hour", h);
            data.put("total", store.list(region, category).size());
            data.put("places", items);
            return ApiBody.ok(data);
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }

    @GetMapping("/{placeId}")
    public ResponseEntity<Map<String, Object>> detail(@PathVariable("placeId") String placeId,
                                                      @RequestParam(name = "date", required = false) String date) {
        try {
            return ApiBody.ok(detailData(store, placeId, parseDate(date, LocalDate.now(KST))));
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }

    /** 장소 상세 응답 data (테스트에서도 씀) */
    static Map<String, Object> detailData(PlaceStore store, String placeId, LocalDate day) {
        PlaceStore.Place p = store.find(placeId)
                .orElseThrow(() -> ApiException.notFound("PLACE_NOT_FOUND", "장소를 찾을 수 없어요."));
        String dayType = RuleConditionExtractor.dayType(day);
        List<PlaceStore.Congestion> hours = new ArrayList<>();
        for (int h = 9; h <= 23; h++) {
            hours.add(store.congestion(placeId, dayType, h, PlaceStore.Basis.ALL_DAY));
        }
        Map<String, Object> byHour = new LinkedHashMap<>();
        byHour.put("date", day.toString());
        byHour.put("dayType", dayType);
        byHour.put("basis", "ALL_DAY");
        byHour.put("hours", hours);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("placeId", p.placeId());
        m.put("name", p.name());
        m.put("category", p.category());
        m.put("region", p.region());
        m.put("address", p.address());
        m.put("roadAddress", p.roadAddress());
        m.put("phone", p.phone());
        m.put("lat", p.lat());
        m.put("lng", p.lng());
        m.put("kakaoCategory", p.kakaoCategory());
        m.put("placeUrl", p.placeUrl());
        m.put("openingHours", null);    // 구글 Places 연동 전까지 null → 화면에 "영업시간 정보 없음"
        m.put("tags", p.tags());
        m.put("congestionByHour", byHour);
        return m;
    }

    private static LocalDate parseDate(String date, LocalDate fallback) {
        if (date == null) return fallback;
        try {
            return LocalDate.parse(date);
        } catch (DateTimeParseException e) {
            throw ApiException.invalid("date는 YYYY-MM-DD 형식이에요.");
        }
    }
}
