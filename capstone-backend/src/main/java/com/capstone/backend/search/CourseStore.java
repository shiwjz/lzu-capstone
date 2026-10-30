package com.capstone.backend.search;

import com.capstone.backend.course.CoursePlan;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 검색으로 만든 코스·공유 저장 (지금은 메모리, 서버 끄면 사라짐) - 김예민
 * - 로그인 없이도 courseId로 수정·공유 가능하게 (명세 '장소·코스 API')
 * - ERD에 course, course_place, course_share 테이블 생기면 이 클래스만 DB로 바꾸기
 */
@Component
public class CourseStore {

    /** 코스 + 만들 때 쓴 조건 (수정할 때 같은 조건으로 다시 계산) */
    public record Saved(SearchConditions conditions, CoursePlan plan) {
    }

    /** 공유 = 그 순간 코스 그대로 (원본을 나중에 고쳐도 공유 링크는 안 바뀜) */
    public record Share(String shareCode, OffsetDateTime createdAt, SearchConditions conditions, CoursePlan course) {
    }

    private final Map<String, Saved> courses = new ConcurrentHashMap<>();
    private final Map<String, Share> shares = new ConcurrentHashMap<>();

    public void save(String courseId, Saved saved) {
        courses.put(courseId, saved);
    }

    public Optional<Saved> find(String courseId) {
        return Optional.ofNullable(courses.get(courseId));
    }

    public void saveShare(Share share) {
        shares.put(share.shareCode(), share);
    }

    public Optional<Share> findShare(String shareCode) {
        return Optional.ofNullable(shares.get(shareCode));
    }

    public boolean hasShare(String shareCode) {
        return shares.containsKey(shareCode);
    }
}
