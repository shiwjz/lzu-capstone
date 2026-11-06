package com.capstone.backend.place;

import com.capstone.backend.course.WalkingTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 11주차 장소·혼잡도 API 테스트 (Spring 없이) - 김예민
 * - 실행: ./gradlew test --tests "com.capstone.backend.place.*"
 */
class PlaceApiTest {

    private static final PlaceStore STORE = new PlaceStore();

    @Test
    @DisplayName("장소 상세: 평일·주말 혼잡도 둘 다 9~23시 (15칸)")
    @SuppressWarnings("unchecked")
    void detailHasBothDayTypes() {
        Map<String, Object> d = PlaceController.detailData(STORE, "921699059", LocalDate.parse("2026-10-17"));
        Map<String, List<PlaceStore.Congestion>> byDay = (Map<String, List<PlaceStore.Congestion>>) d.get("congestionByDayType");
        assertEquals(List.of("WEEKDAY", "WEEKEND"), List.copyOf(byDay.keySet()));
        assertEquals(15, byDay.get("WEEKDAY").size());
        assertEquals(9, byDay.get("WEEKEND").get(0).hour());
        // 토요일이면 congestionByHour = 주말 값이랑 같음
        Map<String, Object> byHour = (Map<String, Object>) d.get("congestionByHour");
        assertEquals(byDay.get("WEEKEND"), byHour.get("hours"));
    }

    @Test
    @DisplayName("혼잡 레이더: 지역 전체 / 반경 안 칸만, 개수 합 = 칸 수")
    @SuppressWarnings("unchecked")
    void grid() {
        Map<String, Object> all = CongestionGrid.grid(STORE, "SEONGSU", "WEEKEND", 15, null, null, 500);
        List<Map<String, Object>> cells = (List<Map<String, Object>>) all.get("cells");
        assertFalse(cells.isEmpty());
        assertTrue(cells.stream().allMatch(c -> STORE.cells("SEONGSU").stream().anyMatch(x -> x.cellId().equals(c.get("cellId")))));
        int sum = ((Map<?, Integer>) all.get("count")).values().stream().mapToInt(Integer::intValue).sum();
        assertEquals(cells.size(), sum);

        PlaceStore.Place p = STORE.find("921699059").orElseThrow();
        Map<String, Object> near = CongestionGrid.grid(STORE, "SEONGSU", "WEEKEND", 15, p.lat(), p.lng(), 200);
        List<Map<String, Object>> nearCells = (List<Map<String, Object>>) near.get("cells");
        assertFalse(nearCells.isEmpty());
        assertTrue(nearCells.size() < cells.size());
        for (Map<String, Object> c : nearCells) {
            assertTrue(WalkingTime.distanceMeters(p.lat(), p.lng(), (double) c.get("lat"), (double) c.get("lng")) <= 200);
        }
        // 장소 있는 칸이면 장소 혼잡도랑 같은 값
        assertTrue(nearCells.stream().anyMatch(c -> c.get("cellId").equals(p.cellId())
                && c.get("level") == STORE.congestion(p.placeId(), "WEEKEND", 15, PlaceStore.Basis.SAME_TIME).level()));
    }
}
