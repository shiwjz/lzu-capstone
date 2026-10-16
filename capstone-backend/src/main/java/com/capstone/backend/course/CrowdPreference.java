package com.capstone.backend.course;

/**
 * 혼잡 선호. 검색 문장에서 추출, 없으면 내 설정 분위기 태그로 판단 ('조용함' → QUIET, '활기' → LIVELY)
 */
public enum CrowdPreference {
    QUIET, DEFAULT, LIVELY
}
