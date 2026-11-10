package com.capstone.backend.search;

import java.util.List;

/**
 * 코스 감성 제목 만들기 (11주차) - 진짜는 GeminiCourseTitleWriter, 테스트·키 없을 때는 NONE
 * - 코스 여러 개를 한 번에 받아서 같은 순서로 제목 목록을 돌려줌
 * - 실패하면 null (→ 규칙 제목 그대로), 일부만 이상하면 그 자리만 null
 */
public interface CourseTitleWriter {

    /** 제목 만들 때 Gemini에 보내는 것 (개인정보·LG 데이터 없음) */
    record Input(String region, String when, List<String> moods, String route, List<String> keywords) {
    }

    List<String> titles(List<Input> courses);

    CourseTitleWriter NONE = courses -> null;
}
