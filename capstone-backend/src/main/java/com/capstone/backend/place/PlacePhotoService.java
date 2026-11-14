package com.capstone.backend.place;

import com.capstone.backend.course.WalkingTime;
import com.capstone.backend.search.ApiException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.json.JsonParserFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 가게 사진 (11주차) - 김예민
 * - 구글 Places API (New)에 그때그때 물어봄: 이름+주소로 Text Search → 사진 이름 → 사진 주소(photoUri)
 * - 구글 정책: 사진·사진 주소는 저장하지 않음 (서버 캐시도 안 함), 앱은 받은 주소로 바로 띄우고
 *   사진 밑에 찍은 사람 이름(authorName)과 "Google" 표시
 * - 키: 환경변수 GOOGLE_PLACES_API_KEY (렌더 환경변수에만, 깃허브·앱에는 절대 안 넣음)
 *   키 없으면 available=false + 빈 목록 → 앱은 사진 칸만 숨기면 됨
 * - 비용: 장소 상세 한 번에 Text Search 1번 + 사진 max장 → 구글 콘솔에서 무료 사용량 확인 (예민)
 */
@Service
public class PlacePhotoService {

    /** 구글에 보내는 요청 (테스트에선 가짜로 바꿈) */
    interface GoogleHttp {
        Map<String, Object> post(String url, Map<String, String> headers, Map<String, Object> body);

        Map<String, Object> get(String url, Map<String, String> headers);
    }

    static final String SEARCH_URL = "https://places.googleapis.com/v1/places:searchText";
    static final String MEDIA_URL = "https://places.googleapis.com/v1/%s/media?maxWidthPx=%d&skipHttpRedirect=true";
    static final int MATCH_METERS = 300;     // 구글 결과가 우리 장소에서 이보다 멀면 다른 가게로 보고 사진 안 줌
    static final int MAX_WIDTH = 800;
    // 영업시간도 같은 검색 한 번에 같이 받음 (구글 정책상 저장 X, 볼 때만 - 예민 11/14)
    // 국내 장소는 구글이 사진을 API로 안 줘도 영업시간은 줌 (자연도소금빵 확인)
    static final String FIELD_MASK = "places.id,places.location,places.photos,places.regularOpeningHours.weekdayDescriptions,places.rating,places.userRatingCount";

    private final PlaceStore store;
    private final String apiKey;
    private final GoogleHttp http;

    @Autowired
    public PlacePhotoService(PlaceStore store, @Value("${GOOGLE_PLACES_API_KEY:}") String apiKey) {
        this(store, apiKey, restHttp());
    }

    PlacePhotoService(PlaceStore store, String apiKey, GoogleHttp http) {
        this.store = store;
        this.apiKey = apiKey;
        this.http = http;
    }

    public boolean enabled() {
        return apiKey != null && !apiKey.isBlank();
    }

    /** GET /api/places/{placeId}/photos 응답 data */
    @SuppressWarnings("unchecked")
    public Map<String, Object> photos(String placeId, int max) {
        PlaceStore.Place p = store.find(placeId)
                .orElseThrow(() -> ApiException.notFound("PLACE_NOT_FOUND", "장소를 찾을 수 없어요."));
        int n = Math.max(1, Math.min(max, 3));
        List<Map<String, Object>> photos = new ArrayList<>();
        String notice = null;
        List<String> openingHours = null;
        Object rating = null;
        Object ratingCount = null;
        if (!enabled()) {
            notice = "사진 기능이 꺼져 있어요.";
        } else {
            try {
                Map<String, Object> place = search(p);
                if (place == null) {
                    notice = "구글에서 같은 가게를 찾지 못했어요.";
                } else {
                    openingHours = weekdayHours(place);
                    rating = place.get("rating");               // 구글 평점 (저장 X, 볼 때만)
                    ratingCount = place.get("userRatingCount");
                    List<Map<String, Object>> list = (List<Map<String, Object>>) place.getOrDefault("photos", List.of());
                    for (Map<String, Object> ph : list.subList(0, Math.min(n, list.size()))) {
                        Map<String, Object> media = http.get(String.format(MEDIA_URL, ph.get("name"), MAX_WIDTH), headers(null));
                        Object uri = media == null ? null : media.get("photoUri");
                        if (uri == null) continue;
                        Map<String, Object> author = firstAuthor(ph);
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("url", uri);
                        m.put("width", ph.get("widthPx"));
                        m.put("height", ph.get("heightPx"));
                        m.put("authorName", author.get("displayName"));
                        m.put("authorUri", author.get("uri"));
                        if (ph.get("googleMapsUri") != null) {
                            m.put("googleMapsUri", ph.get("googleMapsUri"));
                        }
                        photos.add(m);
                    }
                    if (photos.isEmpty()) notice = "사진이 없어요.";
                }
            } catch (RuntimeException e) {
                // 키·요청 내용은 로그에 안 남김
                System.out.println("[사진 실패] " + placeId + " " + e.getClass().getSimpleName());
                notice = "사진을 불러오지 못했어요.";
            }
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("placeId", placeId);
        data.put("available", enabled());
        data.put("attribution", "사진 제공: Google");
        data.put("photos", photos);
        data.put("notice", notice);
        data.put("openingHours", openingHours);
        data.put("rating", rating);
        data.put("ratingCount", ratingCount);   // 월~일 7줄 (예: "월요일: 오전 9:00~오후 10:00"), 없으면 null
        return data;
    }

    /** 구글 regularOpeningHours.weekdayDescriptions (월요일부터 7줄), 없으면 null */
    @SuppressWarnings("unchecked")
    static List<String> weekdayHours(Map<String, Object> place) {
        Object hours = place.get("regularOpeningHours");
        if (!(hours instanceof Map<?, ?> m)) return null;
        Object lines = m.get("weekdayDescriptions");
        if (!(lines instanceof List<?> list) || list.size() != 7) return null;
        return List.copyOf((List<String>) list);
    }

    /** 이름 + 주소로 찾고, 우리 좌표에서 300m 안이면 그 가게 */
    @SuppressWarnings("unchecked")
    private Map<String, Object> search(PlaceStore.Place p) {
        Map<String, Object> center = Map.of("latitude", p.lat(), "longitude", p.lng());
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("textQuery", p.name() + (p.displayAddress() == null ? "" : " " + p.displayAddress()));
        body.put("languageCode", "ko");
        body.put("maxResultCount", 1);
        body.put("locationBias", Map.of("circle", Map.of("center", center, "radius", 500.0)));
        Map<String, Object> res = http.post(SEARCH_URL, headers(FIELD_MASK), body);
        List<Map<String, Object>> places = res == null ? null : (List<Map<String, Object>>) res.get("places");
        if (places == null || places.isEmpty()) return null;
        Map<String, Object> place = places.get(0);
        Map<String, Object> loc = (Map<String, Object>) place.get("location");
        if (loc == null) return null;
        int d = WalkingTime.distanceMeters(p.lat(), p.lng(),
                ((Number) loc.get("latitude")).doubleValue(), ((Number) loc.get("longitude")).doubleValue());
        return d <= MATCH_METERS ? place : null;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> firstAuthor(Map<String, Object> photo) {
        List<Map<String, Object>> a = (List<Map<String, Object>>) photo.get("authorAttributions");
        return a == null || a.isEmpty() ? Map.of() : a.get(0);
    }

    private Map<String, String> headers(String fieldMask) {
        Map<String, String> h = new LinkedHashMap<>();
        h.put("X-Goog-Api-Key", apiKey);
        if (fieldMask != null) h.put("X-Goog-FieldMask", fieldMask);
        return h;
    }

    private static GoogleHttp restHttp() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(3));
        factory.setReadTimeout(Duration.ofSeconds(5));
        RestClient client = RestClient.builder().requestFactory(factory).build();
        return new GoogleHttp() {
            @Override
            public Map<String, Object> post(String url, Map<String, String> headers, Map<String, Object> body) {
                RestClient.RequestBodySpec spec = client.post().uri(URI.create(url))
                        .contentType(MediaType.APPLICATION_JSON).accept(MediaType.APPLICATION_JSON);
                headers.forEach(spec::header);
                return JsonParserFactory.getJsonParser().parseMap(spec.body(body).retrieve().body(String.class));
            }

            @Override
            public Map<String, Object> get(String url, Map<String, String> headers) {
                var spec = client.get().uri(URI.create(url));
                headers.forEach(spec::header);
                return JsonParserFactory.getJsonParser().parseMap(spec.retrieve().body(String.class));
            }
        };
    }
}
