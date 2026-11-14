package com.capstone.backend.search;

import com.capstone.backend.place.PlaceStore;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * 문장에 가게 이름 → 그 가게 킵 (예민 11/14)
 */
class NamedPlaceTest {

    private static final PlaceStore STORE = new PlaceStore();

    @Test
    @DisplayName("이름 첫 단어로 그 지역 지점 찾기 (역전할머니맥주 → 서울성수역점)")
    void chainName() {
        assertEquals("281971020", SearchService.namedPlace(
                "성수에서 다음주 월요일 오후 4시에 역전할머니맥주 가기", "SEONGSU", STORE.coursePlaces()));
    }

    @Test
    @DisplayName("가게 이름 전체 (띄어쓰기 달라도)")
    void fullName() {
        assertEquals("1506847782", SearchService.namedPlace("새촌 호프에서 한잔", "SEONGSU", STORE.coursePlaces()));
    }

    @Test
    @DisplayName("다른 지역 가게나 흔한 말은 안 잡음")
    void noMatch() {
        assertNull(SearchService.namedPlace("성수에서 조용한 카페 가고 싶어", "SEONGSU", STORE.coursePlaces()));
        assertNull(SearchService.namedPlace("성수에서 코인노래방 가자", "SEONGSU", STORE.coursePlaces()));
    }
}
