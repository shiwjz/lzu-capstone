package com.capstone.backend.place;

import com.capstone.backend.search.ApiBody;
import com.capstone.backend.search.ApiException;
import com.capstone.backend.search.RuleConditionExtractor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.Map;
import java.util.Set;

/**
 * 혼잡 레이더 API (11주차) - 김예민
 * - GET /api/congestion/grid?region=SEONGSU&date=2026-11-14&hour=15                지역 전체
 * - GET /api/congestion/grid?region=SEONGSU&hour=15&lat=37.544&lng=127.056&radius=500   지도 가운데 반경 안만
 */
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/congestion")
public class CongestionController {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final Set<String> REGIONS = Set.of("SEONGSU", "HONGDAE", "GANGNAM");

    private final PlaceStore store;

    public CongestionController(PlaceStore store) {
        this.store = store;
    }

    @GetMapping("/grid")
    public ResponseEntity<Map<String, Object>> grid(
            @RequestParam(name = "region") String region,
            @RequestParam(name = "date", required = false) String date,
            @RequestParam(name = "hour", required = false) Integer hour,
            @RequestParam(name = "lat", required = false) Double lat,
            @RequestParam(name = "lng", required = false) Double lng,
            @RequestParam(name = "radius", defaultValue = "500") int radius) {
        try {
            if (!REGIONS.contains(region)) throw ApiException.invalid("region은 SEONGSU / HONGDAE / GANGNAM 중 하나예요.");
            if (radius < 100 || radius > 2000) throw ApiException.invalid("radius는 100~2000m예요.");
            LocalDateTime now = LocalDateTime.now(KST);
            LocalDate day;
            try {
                day = date == null ? now.toLocalDate() : LocalDate.parse(date);
            } catch (DateTimeParseException e) {
                throw ApiException.invalid("date는 YYYY-MM-DD 형식이에요.");
            }
            int h = hour == null ? now.getHour() : Math.floorMod(hour, 24);
            Map<String, Object> data = CongestionGrid.grid(store, region, RuleConditionExtractor.dayType(day), h,
                    lat, lng, radius);
            data.put("date", day.toString());
            return ApiBody.ok(data);
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }
}
