package com.capstone.backend.search;

import com.capstone.backend.course.PlaceScorer;

/**
 * 검색 조건 → 장소 점수 계산기 (자리만 정해둔 인터페이스)
 * - 지금: TemporaryPlaceScorerFactory (사용자 요구·타깃은 가짜, 혼잡도는 윤경 데이터)
 * - @이윤경 장소 점수 모듈 붙일 때: 이 인터페이스 구현한 클래스 만들고 @Primary 붙이기
 *   · 장소 점수 = 0.45 × 사용자 요구 + 0.30 × 타깃 특성 + 0.25 × 혼잡도 적합도 (각 0~1)
 *   · 조건의 gender·ageGroup으로 타깃 특성, atmospheres ↔ 장소 태그로 사용자 요구
 *   · hour는 도착 시각(시), 24 넘을 수 있음 → % 24
 */
public interface PlaceScorerFactory {

    PlaceScorer forConditions(SearchConditions conditions);
}
