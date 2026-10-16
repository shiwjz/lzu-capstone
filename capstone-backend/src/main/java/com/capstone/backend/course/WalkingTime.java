package com.capstone.backend.course;

/**
 * 도보 시간 = 직선거리 × 1.3 ÷ 67m/분(시속 4km), 올림
 * 나중에 길찾기 API로 바꿀 때 이 클래스만 바꾸면 됨
 */
public final class WalkingTime {

    private WalkingTime() {
    }

    public static final double DETOUR = 1.3;            // 길이 직선이 아닌 걸 보정
    public static final double METERS_PER_MINUTE = 67;  // 시속 4km
    private static final double EARTH_RADIUS_M = 6_371_000;

    /** 두 좌표 사이 직선거리(m), 반올림 */
    public static int distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double p1 = Math.toRadians(lat1);
        double p2 = Math.toRadians(lat2);
        double dLat = p2 - p1;
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(p1) * Math.cos(p2) * Math.pow(Math.sin(dLng / 2), 2);
        return (int) Math.rint(2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a)));
    }

    /** 걷는 시간(분), 최소 1분 */
    public static int minutes(int meters) {
        return Math.max(1, (int) Math.ceil(meters * DETOUR / METERS_PER_MINUTE));
    }
}
