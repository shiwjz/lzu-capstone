package com.capstone.backend.user;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 저장 코스·장소 테스트 - 김예민
 */
class SavedStoreTest {

    private static final OffsetDateTime T = OffsetDateTime.parse("2026-10-24T21:00:00+09:00");

    @Test
    @DisplayName("저장 코스: 최근 순, 다시 저장하면 맨 위로, 사람마다 따로")
    void courses() {
        SavedStore s = new SavedStore();
        s.saveCourse(1L, new SavedStore.SavedCourse("c_1", T, null));
        s.saveCourse(1L, new SavedStore.SavedCourse("c_2", T.plusMinutes(1), null));
        s.saveCourse(1L, new SavedStore.SavedCourse("c_1", T.plusMinutes(2), null));
        assertEquals(List.of("c_1", "c_2"), s.courses(1L).stream().map(SavedStore.SavedCourse::courseId).toList());
        assertEquals(List.of(), s.courses(2L));
        assertTrue(s.deleteCourse(1L, "c_2"));
        assertFalse(s.deleteCourse(1L, "c_2"));
        assertFalse(s.deleteCourse(2L, "c_1"));
        assertEquals(1, s.courses(1L).size());
    }

    @Test
    @DisplayName("저장한 장소: 같은 장소 두 번 저장해도 하나, 처음 저장 시각 유지")
    void places() {
        SavedStore s = new SavedStore();
        s.savePlace(1L, new SavedStore.SavedPlace("780757764", T));
        SavedStore.SavedPlace again = s.savePlace(1L, new SavedStore.SavedPlace("780757764", T.plusHours(1)));
        assertEquals(T, again.savedAt());
        s.savePlace(1L, new SavedStore.SavedPlace("20745493", T.plusHours(2)));
        assertEquals(List.of("20745493", "780757764"), s.places(1L).stream().map(SavedStore.SavedPlace::placeId).toList());
        assertTrue(s.deletePlace(1L, "780757764"));
        assertEquals(1, s.places(1L).size());
    }
}
