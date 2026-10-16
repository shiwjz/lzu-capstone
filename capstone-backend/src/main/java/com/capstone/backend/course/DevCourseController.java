package com.capstone.backend.course;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 코스 생성 확인용 주소 (8주차 완료 기준: 가짜 장소 점수 → 코스 3개 JSON) - 김예민
 * - 진짜 검색 API(POST /api/search) 붙기 전까지 브라우저로 코스 결과 확인하는 용도
 * - 기본값 그대로 열면 mocks/search_seongsu_weekend_quiet.json 코스랑 똑같이 나옴
 * - 응답 모양은 ApiResponse(success · code · message · data)랑 같게 맞춤
 * - 9주차에 /api/search 붙으면 지우기
 *
 * 예시 (가짜 JSON 3개랑 같은 조건)
 * - http://localhost:8080/api/dev/courses
 * - http://localhost:8080/api/dev/courses?region=HONGDAE&start=19:00&mood=데이트&crowd=LIVELY&play=ACTIVITY
 * - http://localhost:8080/api/dev/courses?region=GANGNAM&start=19:00&dayType=WEEKDAY&party=4&mood=단체석&crowd=DEFAULT&allergy=SHELLFISH
 *
 * 파라미터 (전부 선택)
 * - region SEONGSU / HONGDAE / GANGNAM, start HH:mm, dayType WEEKDAY / WEEKEND, party 인원
 * - mood 분위기 태그 (여러 개면 쉼표), crowd QUIET / DEFAULT / LIVELY
 * - allergy SHELLFISH 등, play 놀거리 카테고리 (CULTURE, ACTIVITY …, 없으면 6개 전부)
 */
@RestController
@RequestMapping("/api/dev")
public class DevCourseController {

    private final CourseGenerator generator = new CourseGenerator();
    private DevCourseData data;   // 처음 호출할 때 읽음 (서버 켤 때 안 느려지게)

    @GetMapping("/courses")
    public Map<String, Object> courses(
            @RequestParam(name = "region", defaultValue = "SEONGSU") String region,
            @RequestParam(name = "start", defaultValue = "15:00") String start,
            @RequestParam(name = "dayType", defaultValue = "WEEKEND") String dayType,
            @RequestParam(name = "party", defaultValue = "2") int party,
            @RequestParam(name = "mood", defaultValue = "조용함") List<String> mood,
            @RequestParam(name = "crowd", defaultValue = "QUIET") String crowd,
            @RequestParam(name = "allergy", required = false) List<String> allergy,
            @RequestParam(name = "play", required = false) List<String> play) {

        if (!CourseRules.REGION_LABEL.containsKey(region)) {
            return error("INVALID_INPUT", "region은 SEONGSU / HONGDAE / GANGNAM 중 하나");
        }
        if (!dayType.equals("WEEKDAY") && !dayType.equals("WEEKEND")) {
            return error("INVALID_INPUT", "dayType은 WEEKDAY / WEEKEND 중 하나");
        }
        int startMinute;
        CrowdPreference crowdPreference;
        try {
            String[] hm = start.split(":");
            startMinute = Integer.parseInt(hm[0]) * 60 + Integer.parseInt(hm[1]);
            crowdPreference = CrowdPreference.valueOf(crowd);
        } catch (RuntimeException e) {
            return error("INVALID_INPUT", "start는 HH:mm, crowd는 QUIET / DEFAULT / LIVELY");
        }

        Set<String> allergies = allergy == null ? Set.of() : new HashSet<>(allergy);
        CourseRequest request = new CourseRequest(region, startMinute, party, mood, crowdPreference,
                allergies, play == null ? List.of() : play, List.of());

        List<CoursePlan> courses = generator.generate(request, data().places(), data().scorer(request, dayType))
                .stream()
                .map(c -> c.withMeta("dev_" + c.rank(), c.rank(), c.title(), c.reason()))
                .toList();

        Map<String, Object> conditions = new LinkedHashMap<>();
        conditions.put("region", region);
        conditions.put("dayType", dayType);
        conditions.put("startTime", start);
        conditions.put("partySize", party);
        conditions.put("atmospheres", mood);
        conditions.put("crowdPreference", crowd);
        conditions.put("allergies", allergies);
        conditions.put("playCategories", play == null ? List.of() : play);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("conditions", conditions);
        body.put("courses", courses);
        body.put("notice", courses.isEmpty() ? "조건에 맞는 코스를 찾지 못했어요. 시간이나 조건을 바꿔 보세요." : null);
        return response(true, "SUCCESS", "요청 성공", body);
    }

    private synchronized DevCourseData data() {
        if (data == null) {
            data = DevCourseData.load();
        }
        return data;
    }

    private static Map<String, Object> error(String code, String message) {
        return response(false, code, message, null);
    }

    private static Map<String, Object> response(boolean success, String code, String message, Object data) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("success", success);
        map.put("code", code);
        map.put("message", message);
        map.put("data", data);
        return map;
    }
}
