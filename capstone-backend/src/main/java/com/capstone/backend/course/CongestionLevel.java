package com.capstone.backend.course;

/**
 * 혼잡도 구간. 같은 지역·같은 요일 구분·같은 시간 안에서 하위 30% 한산 / 상위 30% 혼잡
 */
public enum CongestionLevel {
    QUIET, NORMAL, BUSY
}
