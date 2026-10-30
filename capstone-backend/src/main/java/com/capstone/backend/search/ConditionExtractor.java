package com.capstone.backend.search;

import java.time.LocalDateTime;

/**
 * 문장 → 검색 조건 (자리만 정해둔 인터페이스)
 * - 지금: RuleConditionExtractor (키워드 규칙, Gemini 오류 때 예비용으로도 계속 씀)
 * - @최예린 Gemini 붙일 때: 이 인터페이스 구현한 클래스 만들고 @Primary 붙이면 서버가 그걸 씀
 *   · Gemini 실패하면 안에서 RuleConditionExtractor 불러서 extractedBy = "RULE"로 돌려주기
 * - 못 찾은 값은 null로 (지역 null이면 서버가 CONDITION_MISSING으로 다시 물어봄)
 * - now: 한국 시간 현재 시각 ("토요일", "내일", 시간 없을 때 기본값 계산용)
 */
public interface ConditionExtractor {

    SearchConditions extract(String query, LocalDateTime now);
}
