package com.capstone.backend.auth;

import com.capstone.backend.domain.User;
import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import com.capstone.backend.repository.UserRepository;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.Optional;

/**
 * 회원가입·로그인 - 김예민 (정헌 9주차 할 일 대신, 테이블은 정헌 users 그대로)
 * - 비밀번호는 BCrypt로 바꿔서 password_hash에 저장 (원래 비번은 저장 안 함)
 * - 이메일은 앞뒤 공백 빼고 소문자로 저장 → Test@a.com, test@a.com 같은 사람
 * - 로그인 실패는 이메일이 없든 비번이 틀리든 똑같이 LOGIN_FAILED (어느 쪽인지 안 알려줌)
 */
@Service
public class AuthService {

    private final UserRepository users;
    private final JwtProvider jwt;
    private final PasswordEncoder encoder = new BCryptPasswordEncoder();

    public AuthService(UserRepository users, JwtProvider jwt) {
        this.users = users;
        this.jwt = jwt;
    }

    public record UserResponse(Long userId, String email, String region) {
        static UserResponse of(User u) {
            return new UserResponse(u.getUserId(), u.getEmail(), u.getRegion());
        }
    }

    public record LoginResponse(String accessToken, String tokenType, long expiresIn, UserResponse user) {
    }

    @Transactional
    public UserResponse signup(AuthController.SignupRequest req) {
        String email = normalize(req.email());
        if (users.existsByEmail(email)) {
            throw new CustomException(ErrorCode.DUPLICATE_EMAIL);
        }
        User saved = users.save(new User(email, encoder.encode(req.password()), req.region()));
        return UserResponse.of(saved);
    }

    @Transactional(readOnly = true)
    public LoginResponse login(AuthController.LoginRequest req) {
        User user = users.findByEmail(normalize(req.email()))
                .filter(u -> encoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> new CustomException(ErrorCode.LOGIN_FAILED));
        return new LoginResponse(jwt.create(user.getUserId()), "Bearer", jwt.expiresIn(), UserResponse.of(user));
    }

    /** 로그인 필요한 API: Authorization 헤더 → 사용자 번호 (없거나 틀리면 UNAUTHORIZED 401) */
    @Transactional(readOnly = true)
    public Long requireUserId(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new CustomException(ErrorCode.UNAUTHORIZED);
        }
        long id = jwt.userId(authorization.substring("Bearer ".length()).trim());
        if (!users.existsById(id)) {   // 탈퇴·DB 초기화된 사용자 토큰
            throw new CustomException(ErrorCode.UNAUTHORIZED);
        }
        return id;
    }

    /** 로그인 선택 API(검색): 토큰 없거나 틀리면 그냥 비로그인으로 */
    public Optional<Long> optionalUserId(String authorization) {
        if (authorization == null || authorization.isBlank()) return Optional.empty();
        try {
            return Optional.of(requireUserId(authorization));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    static String normalize(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
