package com.capstone.backend.place;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 가게 사진 테스트 - 구글에는 진짜로 안 보냄 (가짜 응답)
 */
class PlacePhotoServiceTest {

    private static final PlaceStore STORE = new PlaceStore();
    private static final String ID = "921699059";

    /** 구글 가짜: 검색하면 lat·lng 위치 가게 하나(사진 2장), 사진 주소 요청엔 photoUri */
    static class FakeGoogle implements PlacePhotoService.GoogleHttp {
        final List<String> calls = new ArrayList<>();
        double lat;
        double lng;

        FakeGoogle(double lat, double lng) {
            this.lat = lat;
            this.lng = lng;
        }

        @Override
        public Map<String, Object> post(String url, Map<String, String> headers, Map<String, Object> body) {
            calls.add("search " + headers.get("X-Goog-FieldMask"));
            Map<String, Object> photo1 = Map.of("name", "places/G1/photos/P1", "widthPx", 1200, "heightPx", 800,
                    "authorAttributions", List.of(Map.of("displayName", "작성자1", "uri", "https://maps.google.com/u1")));
            Map<String, Object> photo2 = Map.of("name", "places/G1/photos/P2", "widthPx", 900, "heightPx", 900);
            List<String> week = List.of("월요일: 오전 9:00~오후 10:00", "화요일: 오전 9:00~오후 10:00",
                    "수요일: 오전 9:00~오후 10:00", "목요일: 오전 9:00~오후 10:00", "금요일: 오전 9:00~오후 10:00",
                    "토요일: 오전 9:00~오후 10:00", "일요일: 휴무일");
            return Map.of("places", List.of(Map.of("id", "G1", "location", Map.of("latitude", lat, "longitude", lng),
                    "photos", List.of(photo1, photo2), "regularOpeningHours", Map.of("weekdayDescriptions", week),
                    "rating", 4.4, "userRatingCount", 1004)));
        }

        @Override
        public Map<String, Object> get(String url, Map<String, String> headers) {
            calls.add("media " + url);
            return Map.of("photoUri", "https://lh3.googleusercontent.com/" + url.substring(url.indexOf("photos/") + 7, url.indexOf("/media")));
        }
    }

    @Test
    @DisplayName("키 없으면 구글에 안 물어보고 빈 목록")
    void noKey() {
        FakeGoogle g = new FakeGoogle(0, 0);
        Map<String, Object> d = new PlacePhotoService(STORE, "", g).photos(ID, 1);
        assertEquals(false, d.get("available"));
        assertTrue(((List<?>) d.get("photos")).isEmpty());
        assertTrue(g.calls.isEmpty());
    }

    @Test
    @DisplayName("같은 가게면 사진 주소 + 찍은 사람, max장까지만")
    @SuppressWarnings("unchecked")
    void photos() {
        PlaceStore.Place p = STORE.find(ID).orElseThrow();
        FakeGoogle g = new FakeGoogle(p.lat() + 0.0005, p.lng());    // 55m 옆
        Map<String, Object> d = new PlacePhotoService(STORE, "test-key", g).photos(ID, 1);
        List<Map<String, Object>> photos = (List<Map<String, Object>>) d.get("photos");
        assertEquals(1, photos.size());
        assertEquals("https://lh3.googleusercontent.com/P1", photos.get(0).get("url"));
        assertEquals("작성자1", photos.get(0).get("authorName"));
        assertNull(d.get("notice"));
        assertEquals(List.of("search places.id,places.location,places.photos,places.regularOpeningHours.weekdayDescriptions,places.rating,places.userRatingCount",
                "media https://places.googleapis.com/v1/places/G1/photos/P1/media?maxWidthPx=800&skipHttpRedirect=true"), g.calls);
        assertEquals(2, ((List<?>) new PlacePhotoService(STORE, "k", new FakeGoogle(p.lat(), p.lng())).photos(ID, 5).get("photos")).size());
    }

    @Test
    @DisplayName("영업시간: 구글 요일별 7줄 그대로, 다른 가게면 안 줌")
    @SuppressWarnings("unchecked")
    void openingHours() {
        PlaceStore.Place p = STORE.find(ID).orElseThrow();
        Map<String, Object> d = new PlacePhotoService(STORE, "k", new FakeGoogle(p.lat(), p.lng())).photos(ID, 1);
        List<String> hours = (List<String>) d.get("openingHours");
        assertEquals(7, hours.size());
        assertEquals("일요일: 휴무일", hours.get(6));
        assertEquals(4.4, d.get("rating"));
        assertEquals(1004, d.get("ratingCount"));
        assertNull(new PlacePhotoService(STORE, "k", new FakeGoogle(p.lat() + 0.01, p.lng())).photos(ID, 1).get("openingHours"));
        assertNull(new PlacePhotoService(STORE, "", new FakeGoogle(0, 0)).photos(ID, 1).get("openingHours"));
    }

    @Test
    @DisplayName("구글 영업시간 구간: 오후 5시 오픈 가게는 토 15시 닫힘, 토 18시 열림, 자정 넘는 영업도")
    void openAt() {
        // 토요일(6) 17:00 ~ 일요일(0) 02:00
        List<int[]> h = List.of(new int[]{6, 17 * 60, 0, 2 * 60});
        assertFalse(PlacePhotoService.openAt(h, 6, 15 * 60));
        assertTrue(PlacePhotoService.openAt(h, 6, 18 * 60));
        assertTrue(PlacePhotoService.openAt(h, 6, 25 * 60));      // 토요일 기준 새벽 1시 (24시 넘김)
        assertFalse(PlacePhotoService.openAt(h, 5, 18 * 60));     // 금요일은 안 엶
        assertTrue(PlacePhotoService.openAt(List.of(new int[]{0, 0, 7, 0}), 3, 4 * 60));   // 24시간
    }

    @Test
    @DisplayName("구글 결과가 300m 넘게 떨어져 있으면 다른 가게 → 사진 안 줌")
    void farAway() {
        PlaceStore.Place p = STORE.find(ID).orElseThrow();
        FakeGoogle g = new FakeGoogle(p.lat() + 0.01, p.lng());     // 1.1km
        Map<String, Object> d = new PlacePhotoService(STORE, "k", g).photos(ID, 1);
        assertTrue(((List<?>) d.get("photos")).isEmpty());
        assertEquals("구글에서 같은 가게를 찾지 못했어요.", d.get("notice"));
        assertFalse(g.calls.stream().anyMatch(c -> c.startsWith("media")));
    }
}
