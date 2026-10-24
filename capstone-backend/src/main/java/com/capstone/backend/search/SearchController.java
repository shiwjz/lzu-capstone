package com.capstone.backend.search;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 검색·코스 수정·공유 API (docs/api-spec.md v0.3) - 김예민
 * - POST /api/search                     문장 → 추천 장소 10곳 + 코스 3개
 * - GET  /api/search?q=문장               브라우저로 바로 확인하는 용도 (회의·발표 시연, 앱은 POST 사용)
 * - PUT  /api/courses/{courseId}         수정한 전체 목록 → 다시 계산 + 경고
 * - POST /api/courses/{courseId}/share   공유 코드·링크·카톡용 글
 * - GET  /api/share/{shareCode}          공유 코스 보기
 * - 로그인 없이 전부 사용 가능 (로그인 연동은 정헌 JWT 붙은 뒤)
 * - @CrossOrigin: 예령 Flutter 웹(크롬)으로 테스트할 때 막히지 않게
 */
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api")
public class SearchController {

    private final SearchService service;

    public SearchController(SearchService service) {
        this.service = service;
    }

    @PostMapping("/search")
    public ResponseEntity<Map<String, Object>> search(@RequestBody SearchService.SearchRequest request) {
        try {
            return ApiBody.ok(service.search(request));
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }

    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchByUrl(@RequestParam(name = "q") String query) {
        return search(new SearchService.SearchRequest(query, null, null, null, null));
    }

    @PutMapping("/courses/{courseId}")
    public ResponseEntity<Map<String, Object>> updateCourse(@PathVariable("courseId") String courseId,
                                                            @RequestBody SearchService.UpdateRequest request) {
        try {
            return ApiBody.ok(service.updateCourse(courseId, request));
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }

    @PostMapping("/courses/{courseId}/share")
    public ResponseEntity<Map<String, Object>> createShare(@PathVariable("courseId") String courseId) {
        try {
            return ApiBody.ok(service.createShare(courseId));
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }

    @GetMapping("/share/{shareCode}")
    public ResponseEntity<Map<String, Object>> viewShare(@PathVariable("shareCode") String shareCode) {
        try {
            return ApiBody.ok(service.viewShare(shareCode));
        } catch (ApiException e) {
            return ApiBody.error(e);
        }
    }
}
