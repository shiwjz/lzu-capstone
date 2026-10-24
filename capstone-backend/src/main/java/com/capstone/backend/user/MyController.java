package com.capstone.backend.user;

import com.capstone.backend.auth.AuthService;
import com.capstone.backend.global.ApiResponse;
import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import com.capstone.backend.place.PlaceStore;
import com.capstone.backend.search.CourseStore;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 내 정보 API (전부 로그인 필요: Authorization: Bearer 토큰, 없으면 UNAUTHORIZED 401) - 김예민
 * - GET·PUT  /api/users/me/preferences          내 설정 (region, atmospheres, allergies)
 * - GET·POST /api/users/me/courses              저장 코스 목록·저장 (요청 { "courseId": "c_1_1" })
 * - DELETE   /api/users/me/courses/{courseId}
 * - GET·POST /api/users/me/places               저장한 장소 목록·저장 (요청 { "placeId": "780757764" })
 * - DELETE   /api/users/me/places/{placeId}
 * - 목록은 최근 저장한 순
 */
@RestController
@RequestMapping("/api/users/me")
public class MyController {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private final AuthService auth;
    private final PreferenceService preferenceService;
    private final SavedStore saved;
    private final CourseStore courseStore;
    private final PlaceStore placeStore;

    public MyController(AuthService auth, PreferenceService preferenceService, SavedStore saved,
                        CourseStore courseStore, PlaceStore placeStore) {
        this.auth = auth;
        this.preferenceService = preferenceService;
        this.saved = saved;
        this.courseStore = courseStore;
        this.placeStore = placeStore;
    }

    public record CourseIdRequest(String courseId) {
    }

    public record PlaceIdRequest(String placeId) {
    }

    // ---------- 내 설정 ----------

    @GetMapping("/preferences")
    public ApiResponse<PreferenceService.Preferences> preferences(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return ApiResponse.success(preferenceService.get(auth.requireUserId(authorization)));
    }

    @PutMapping("/preferences")
    public ApiResponse<PreferenceService.Preferences> updatePreferences(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody PreferenceService.Preferences request) {
        return ApiResponse.success(preferenceService.update(auth.requireUserId(authorization), request));
    }

    // ---------- 저장 코스 ----------

    @GetMapping("/courses")
    public ApiResponse<Map<String, Object>> courses(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long userId = auth.requireUserId(authorization);
        return ApiResponse.success(Map.of("courses", saved.courses(userId).stream().map(MyController::courseItem).toList()));
    }

    @PostMapping("/courses")
    public ApiResponse<Map<String, Object>> saveCourse(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody CourseIdRequest request) {
        Long userId = auth.requireUserId(authorization);
        if (request == null || request.courseId() == null) throw new CustomException(ErrorCode.INVALID_INPUT);
        CourseStore.Saved course = courseStore.find(request.courseId())
                .orElseThrow(() -> new CustomException(ErrorCode.COURSE_NOT_FOUND));
        return ApiResponse.success(courseItem(saved.saveCourse(userId,
                new SavedStore.SavedCourse(request.courseId(), now(), course))));
    }

    @DeleteMapping("/courses/{courseId}")
    public ApiResponse<Map<String, Object>> deleteCourse(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable("courseId") String courseId) {
        if (!saved.deleteCourse(auth.requireUserId(authorization), courseId)) {
            throw new CustomException(ErrorCode.COURSE_NOT_FOUND);
        }
        return ApiResponse.success(Map.of("courseId", courseId, "deleted", true));
    }

    // ---------- 저장한 장소 ----------

    @GetMapping("/places")
    public ApiResponse<Map<String, Object>> places(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long userId = auth.requireUserId(authorization);
        List<Map<String, Object>> items = saved.places(userId).stream()
                .flatMap(s -> placeStore.find(s.placeId()).map(p -> placeItem(p, s)).stream())
                .toList();
        return ApiResponse.success(Map.of("places", items));
    }

    @PostMapping("/places")
    public ApiResponse<Map<String, Object>> savePlace(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody PlaceIdRequest request) {
        Long userId = auth.requireUserId(authorization);
        if (request == null || request.placeId() == null) throw new CustomException(ErrorCode.INVALID_INPUT);
        PlaceStore.Place place = placeStore.find(request.placeId())
                .orElseThrow(() -> new CustomException(ErrorCode.PLACE_NOT_FOUND));
        return ApiResponse.success(placeItem(place,
                saved.savePlace(userId, new SavedStore.SavedPlace(place.placeId(), now()))));
    }

    @DeleteMapping("/places/{placeId}")
    public ApiResponse<Map<String, Object>> deletePlace(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable("placeId") String placeId) {
        if (!saved.deletePlace(auth.requireUserId(authorization), placeId)) {
            throw new CustomException(ErrorCode.PLACE_NOT_FOUND);
        }
        return ApiResponse.success(Map.of("placeId", placeId, "deleted", true));
    }

    // ---------- 응답 모양 ----------

    /** 저장 코스 한 개: courseId, savedAt, conditions(검색 조건), course(검색 응답 courses[]와 같은 모양) */
    static Map<String, Object> courseItem(SavedStore.SavedCourse s) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("courseId", s.courseId());
        m.put("savedAt", s.savedAt().toString());
        m.put("conditions", s.course().conditions().toMap());
        m.put("course", s.course().plan());
        return m;
    }

    /** 저장한 장소 한 개: 장소 목록 API랑 같은 기본 정보 + savedAt */
    static Map<String, Object> placeItem(PlaceStore.Place p, SavedStore.SavedPlace s) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("placeId", p.placeId());
        m.put("name", p.name());
        m.put("category", p.category());
        m.put("region", p.region());
        m.put("address", p.displayAddress());
        m.put("lat", p.lat());
        m.put("lng", p.lng());
        m.put("tags", p.tags());
        m.put("savedAt", s.savedAt().toString());
        return m;
    }

    private static OffsetDateTime now() {
        return OffsetDateTime.now(KST).withNano(0);
    }
}
