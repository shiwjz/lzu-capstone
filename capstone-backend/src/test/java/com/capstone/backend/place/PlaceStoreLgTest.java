package com.capstone.backend.place;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * LG 결과 폴더(ODIGA_DATA_DIR) 읽기 테스트 - 진짜 LG 파일 대신 열 이름만 같은 가짜 파일을 임시 폴더에 만들어서
 * - cell_profile_lg.tsv에 성별×연령 12열 (f_10s~m_60s) 더 있어도 읽음
 * - cell_congestion_dow_lg.csv (윤경 make_lg_data.py 결과 그대로) 읽음
 */
class PlaceStoreLgTest {

    private static String resource(String name) throws IOException {
        try (InputStream in = PlaceStore.class.getResourceAsStream("/data/" + name)) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    private static Path fakeLgDir() throws IOException {
        Path dir = Files.createTempDirectory("fake_lg");
        Files.writeString(dir.resolve("congestion_lg.tsv"), resource("congestion.tsv"));
        // 성·연령: 가짜 파일 + 성별×연령 12열 (f_20s = 여성 비율 × 20대 비율로 대충)
        List<String> out = new ArrayList<>();
        String[] lines = resource("cell_profile.tsv").split("\n");
        StringBuilder head = new StringBuilder(lines[0].strip());
        for (String sx : List.of("f", "m")) for (int a = 10; a <= 60; a += 10) head.append('\t').append(sx).append('_').append(a).append('s');
        out.add(head.toString());
        for (int i = 1; i < lines.length; i++) {
            if (lines[i].isBlank()) continue;
            String[] r = lines[i].strip().split("\t", -1);
            double f = Double.parseDouble(r[3]);
            StringBuilder b = new StringBuilder(lines[i].strip());
            for (double share : List.of(f, 1 - f)) {
                for (int k = 0; k < 6; k++) b.append('\t').append(share * Double.parseDouble(r[4 + k]));
            }
            out.add(b.toString());
        }
        Files.write(dir.resolve("cell_profile_lg.tsv"), out);
        // 요일별: 921699059 칸만, 금요일 15시 = 붐빔 91, 나머지 한산 10
        String cell = new PlaceStore().find("921699059").orElseThrow().cellId();
        List<String> dow = new ArrayList<>();
        dow.add("﻿cell_id,region,dow,hour,cell_value,smooth_value,pct_same_time,level_same_time,pct_all_day,level_all_day");
        for (String d : PlaceStore.DOWS) {
            for (int h = 0; h < 24; h++) {
                boolean busy = d.equals("FRI") && h == 15;
                dow.add(cell + ",SEONGSU," + d + "," + h + ",1,1,50.0,NORMAL," + (busy ? "90.6,BUSY" : "10.0,QUIET"));
            }
        }
        Files.write(dir.resolve("cell_congestion_dow_lg.csv"), dow);
        return dir;
    }

    @Test
    @DisplayName("LG 폴더: 성별×연령 열 읽기 + 지역 평균에도 들어감, 요일별 csv 그대로 읽기")
    void readsLgFolder() throws IOException {
        Path dir = fakeLgDir();
        PlaceStore store = new PlaceStore("congestion.tsv", dir.toString());
        PlaceStore.CellProfile cp = store.cellProfile("921699059");
        assertNotNull(cp.valueOrNull("f_20s"));
        assertEquals(cp.femaleRatio() * cp.value("age_20s"), cp.valueOrNull("f_20s"), 1e-9);
        Map<String, Double> avg = store.regionAverage("SEONGSU");
        assertNotNull(avg.get("m_60s"));
        assertEquals("cell_congestion_dow_lg.csv (외부 폴더)", store.dowSource());
        PlaceStore.Congestion fri = store.congestionByDow("921699059", "FRI", 15);
        assertEquals("BUSY", fri.level().name());
        assertEquals(91, fri.percentile());
        assertEquals(10, store.congestionByDow("921699059", "MON", 15).percentile());
    }

    @Test
    @DisplayName("기본(가짜 혼잡도): 성별×연령 열 없음, 요일별도 없음 / 서울시 혼잡도면 서울시 요일별 짝")
    void defaultsAndSeoul() {
        PlaceStore fake = new PlaceStore("congestion.tsv", "");
        assertNull(fake.cellProfile("921699059").valueOrNull("f_20s"));
        assertNull(fake.dowSource());
        PlaceStore seoul = new PlaceStore("congestion_seoul.tsv", "");
        assertEquals("congestion_dow_seoul.tsv", seoul.dowSource());
        assertNotNull(seoul.congestionByDow("921699059", "FRI", 15));
    }
}
