package com.capstone.backend.user;

import com.capstone.backend.search.CourseStore;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 저장 코스·저장한 장소 (사용자별) - 김예민
 * - 지금은 메모리 (서버 끄면 사라짐, 회원 정보는 DB라 그대로)
 * - ERD에 saved_course, saved_place 테이블 생기면 이 클래스만 DB로 바꾸기 (@성정헌)
 * - 코스는 저장한 순간 그대로 복사 (공유랑 같음) → 원본 코스를 나중에 고쳐도 저장본은 안 바뀜
 */
@Component
public class SavedStore {

    public record SavedCourse(String courseId, OffsetDateTime savedAt, CourseStore.Saved course) {
    }

    public record SavedPlace(String placeId, OffsetDateTime savedAt) {
    }

    // 사용자 번호 → (id → 저장본), 넣은 순서 유지
    private final Map<Long, Map<String, SavedCourse>> courses = new ConcurrentHashMap<>();
    private final Map<Long, Map<String, SavedPlace>> places = new ConcurrentHashMap<>();

    public SavedCourse saveCourse(Long userId, SavedCourse c) {
        Map<String, SavedCourse> m = courses.computeIfAbsent(userId, k -> Collections.synchronizedMap(new LinkedHashMap<>()));
        m.remove(c.courseId());   // 다시 저장하면 맨 뒤(최신)로
        m.put(c.courseId(), c);
        return c;
    }

    public List<SavedCourse> courses(Long userId) {
        return newestFirst(courses.get(userId));
    }

    public boolean deleteCourse(Long userId, String courseId) {
        Map<String, SavedCourse> m = courses.get(userId);
        return m != null && m.remove(courseId) != null;
    }

    public SavedPlace savePlace(Long userId, SavedPlace p) {
        Map<String, SavedPlace> m = places.computeIfAbsent(userId, k -> Collections.synchronizedMap(new LinkedHashMap<>()));
        SavedPlace before = m.get(p.placeId());
        if (before != null) return before;   // 이미 저장한 장소는 처음 저장한 시각 유지
        m.put(p.placeId(), p);
        return p;
    }

    public List<SavedPlace> places(Long userId) {
        return newestFirst(places.get(userId));
    }

    public boolean deletePlace(Long userId, String placeId) {
        Map<String, SavedPlace> m = places.get(userId);
        return m != null && m.remove(placeId) != null;
    }

    private static <T> List<T> newestFirst(Map<String, T> m) {
        if (m == null) return List.of();
        List<T> list;
        synchronized (m) {
            list = new ArrayList<>(m.values());
        }
        Collections.reverse(list);
        return list;
    }
}
