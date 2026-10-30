package com.capstone.backend.auth;

import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 로그인 토큰 테스트 (DB·Spring 없이) - 김예민
 * - 실행: ./gradlew test --tests "com.capstone.backend.auth.*"
 */
class JwtProviderTest {

    private static final String SECRET = "test-secret-test-secret-test-secret!!";
    private static final Instant T0 = Instant.parse("2026-10-24T12:00:00Z");

    private JwtProvider jwt(Instant now) {
        JwtProvider p = new JwtProvider(SECRET, 3600);
        p.clock = Clock.fixed(now, ZoneOffset.UTC);
        return p;
    }

    private static void unauthorized(Runnable r) {
        CustomException e = assertThrows(CustomException.class, r::run);
        assertEquals(ErrorCode.UNAUTHORIZED, e.getErrorCode());
    }

    @Test
    @DisplayName("만든 토큰 → 같은 사용자 번호, 모양은 헤더.내용.서명")
    void roundTrip() {
        String token = jwt(T0).create(42);
        assertEquals(3, token.split("\\.").length);
        assertTrue(token.startsWith("eyJ"));
        assertEquals(42L, jwt(T0.plusSeconds(3599)).userId(token));
    }

    @Test
    @DisplayName("만료(1시간)·위조·다른 비밀키·이상한 값이면 UNAUTHORIZED")
    void rejects() {
        String token = jwt(T0).create(1);
        unauthorized(() -> jwt(T0.plus(Duration.ofHours(1))).userId(token));

        String[] p = token.split("\\.");
        String other = jwt(T0).create(2).split("\\.")[1];
        unauthorized(() -> jwt(T0).userId(p[0] + "." + other + "." + p[2]));   // 내용만 바꿔치기

        JwtProvider otherKey = new JwtProvider("another-secret-another-secret-12345", 3600);
        unauthorized(() -> otherKey.userId(token));

        unauthorized(() -> jwt(T0).userId("abc"));
        unauthorized(() -> jwt(T0).userId(null));
        unauthorized(() -> jwt(T0).userId(p[0] + "." + p[1] + ".%%%"));
    }

    @Test
    @DisplayName("비밀키 32자 안 되면 서버 시작 때 바로 에러")
    void shortSecret() {
        assertThrows(IllegalStateException.class, () -> new JwtProvider("short", 3600));
    }
}
