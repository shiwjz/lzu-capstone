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
            return Map.of("places", List.of(Map.of("id", "G1", "location", Map.of("latitude", lat, "longitude", lng),
                    "photos", List.of(photo1, photo2))));
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
        assertEquals(List.of("search places.id,places.location,places.photos",
                "media https://places.googleapis.com/v1/places/G1/photos/P1/media?maxWidthPx=800&skipHttpRedirect=true"), g.calls);
        assertEquals(2, ((List<?>) new PlacePhotoService(STORE, "k", new FakeGoogle(p.lat(), p.lng())).photos(ID, 5).get("photos")).size());
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
