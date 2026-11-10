package com.capstone.backend.place;

import com.capstone.backend.course.CongestionLevel;
import com.capstone.backend.course.WalkingTime;

import java.util.ArrayList;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 주변 혼잡 레이더 (11주차) - 김예민
 * - 지역(또는 지도 가운데 lat·lng 반경 안)의 50m 칸마다 그 시각 혼잡 등급
 * - 같은 지역·요일·시간끼리 비교(SAME_TIME): "지금 이 동네에서 어디가 붐비나"
 * - 장소가 없는 칸은 혼잡도 파일에 없어서 빠짐 (LG 데이터 붙이면 칸이 더 많아짐)
 */
public final class CongestionGrid {

    private CongestionGrid() {
    }

    public static final int CELL_SIZE_METERS = 50;

    /** lat·lng가 null이면 지역 전체, 있으면 그 점에서 radius 미터 안 칸만 */
    public static Map<String, Object> grid(PlaceStore store, String region, String dayType, int hour,
                                           Double lat, Double lng, int radius) {
        List<Map<String, Object>> cells = new ArrayList<>();
        Map<CongestionLevel, Integer> count = new EnumMap<>(CongestionLevel.class);
        for (CongestionLevel l : CongestionLevel.values()) count.put(l, 0);
        for (PlaceStore.Cell c : store.cells(region)) {
            if (lat != null && lng != null && WalkingTime.distanceMeters(lat, lng, c.lat(), c.lng()) > radius) continue;
            store.cellCongestion(c.cellId(), dayType, hour, PlaceStore.Basis.SAME_TIME).ifPresent(cg -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("cellId", c.cellId());
                m.put("lat", c.lat());
                m.put("lng", c.lng());
                m.put("level", cg.level());
                m.put("percentile", cg.percentile());
                cells.add(m);
                count.merge(cg.level(), 1, Integer::sum);
            });
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("region", region);
        data.put("dayType", dayType);
        data.put("hour", Math.floorMod(hour, 24));
        data.put("basis", "SAME_TIME");
        data.put("cellSizeMeters", CELL_SIZE_METERS);
        data.put("count", count);
        data.put("cells", cells);
        return data;
    }
}
