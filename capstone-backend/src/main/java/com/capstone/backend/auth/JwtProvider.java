package com.capstone.backend.auth;

import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Clock;
import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 로그인 토큰 (JWT, HS256) 만들기·확인 - 김예민 (정헌 9주차 할 일 대신)
 * - 라이브러리(jjwt) 대신 자바 기본 HMAC으로 직접 만듦 → build.gradle 버전 충돌 걱정 없음
 * - 토큰 안에는 사용자 번호(sub)·만든 시각(iat)·만료 시각(exp)만 넣음 (이메일·비번 X)
 * - 비밀키: application.properties의 odiga.jwt.secret (배포 서버는 JWT_SECRET 환경변수)
 * - 나중에 jjwt로 바꿔도 토큰 모양(헤더.내용.서명)은 같아서 앱은 그대로
 */
@Component
public class JwtProvider {

    private static final Base64.Encoder ENC = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder DEC = Base64.getUrlDecoder();
    private static final String HEADER = ENC.encodeToString(
            "{\"alg\":\"HS256\",\"typ\":\"JWT\"}".getBytes(StandardCharsets.UTF_8));
    private static final Pattern SUB = Pattern.compile("\"sub\":\"(\\d+)\"");
    private static final Pattern EXP = Pattern.compile("\"exp\":(\\d+)");

    private final byte[] secret;
    private final long expiresIn;
    Clock clock = Clock.systemUTC();   // 테스트에서 시간 돌리기용

    public JwtProvider(@Value("${odiga.jwt.secret}") String secret,
                       @Value("${odiga.jwt.expires-in:3600}") long expiresIn) {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("odiga.jwt.secret(JWT_SECRET)은 32자 이상이어야 해요.");
        }
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.expiresIn = expiresIn;
    }

    /** 토큰 유효 시간(초) → 로그인 응답 expiresIn */
    public long expiresIn() {
        return expiresIn;
    }

    public String create(long userId) {
        long now = clock.instant().getEpochSecond();
        String payload = ENC.encodeToString(
                ("{\"sub\":\"" + userId + "\",\"iat\":" + now + ",\"exp\":" + (now + expiresIn) + "}")
                        .getBytes(StandardCharsets.UTF_8));
        String body = HEADER + "." + payload;
        return body + "." + ENC.encodeToString(sign(body));
    }

    /** 토큰 → 사용자 번호. 모양이 틀리거나 서명이 안 맞거나 만료면 UNAUTHORIZED */
    public long userId(String token) {
        if (token == null) throw unauthorized();
        String[] parts = token.split("\\.");
        if (parts.length != 3 || !parts[0].equals(HEADER)) throw unauthorized();
        byte[] expected = sign(parts[0] + "." + parts[1]);
        byte[] actual;
        String json;
        try {
            actual = DEC.decode(parts[2]);
            json = new String(DEC.decode(parts[1]), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException e) {
            throw unauthorized();
        }
        if (!MessageDigest.isEqual(expected, actual)) throw unauthorized();
        Matcher sub = SUB.matcher(json);
        Matcher exp = EXP.matcher(json);
        if (!sub.find() || !exp.find()) throw unauthorized();
        if (Long.parseLong(exp.group(1)) <= clock.instant().getEpochSecond()) throw unauthorized();
        return Long.parseLong(sub.group(1));
    }

    private byte[] sign(String body) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(body.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static CustomException unauthorized() {
        return new CustomException(ErrorCode.UNAUTHORIZED);
    }
}
