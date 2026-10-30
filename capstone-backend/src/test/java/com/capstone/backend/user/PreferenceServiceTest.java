package com.capstone.backend.user;

import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * 내 설정 값 검사 테스트 (DB 없이) - 김예민
 */
class PreferenceServiceTest {

    private static PreferenceService.Preferences prefs(String region, List<String> moods, List<String> allergies) {
        return new PreferenceService.Preferences(region, moods, allergies);
    }

    private static void invalid(PreferenceService.Preferences p) {
        CustomException e = assertThrows(CustomException.class, () -> PreferenceService.validate(p));
        assertEquals(ErrorCode.INVALID_INPUT, e.getErrorCode());
    }

    @Test
    @DisplayName("분위기: 공백·빈 값·중복 정리, 순서 유지 / 빈 목록 null 허용")
    void cleans() {
        PreferenceService.Preferences p = PreferenceService.validate(
                prefs("SEONGSU", Arrays.asList(" 조용함 ", "디저트", "", null, "조용함"), List.of("SHELLFISH", "SHELLFISH")));
        assertEquals(List.of("조용함", "디저트"), p.atmospheres());
        assertEquals(List.of("SHELLFISH"), p.allergies());
        assertEquals("SEONGSU", p.region());

        PreferenceService.Preferences empty = PreferenceService.validate(prefs(null, null, null));
        assertEquals(List.of(), empty.atmospheres());
        assertEquals(List.of(), empty.allergies());
    }

    @Test
    @DisplayName("틀린 지역·알레르기 코드·너무 긴 분위기 → INVALID_INPUT")
    void rejects() {
        invalid(prefs("성수", List.of(), List.of()));
        invalid(prefs("SEONGSU", List.of(), List.of("갑각류")));
        invalid(prefs("SEONGSU", List.of("가".repeat(31)), List.of()));
        invalid(prefs("SEONGSU", List.of("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"), List.of()));
        invalid(null);
    }
}
