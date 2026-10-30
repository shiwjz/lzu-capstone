package com.capstone.backend.auth;

import com.capstone.backend.global.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 회원가입·로그인 API (명세 v0.3 '회원 API') - 김예민
 * - POST /api/auth/signup   email, password(8자 이상), region → userId, email, region
 *   · 이미 있는 이메일: DUPLICATE_EMAIL 409, 형식 틀림: INVALID_INPUT 400
 * - POST /api/auth/login    email, password → accessToken, tokenType(Bearer), expiresIn(초), user
 *   · 틀리면 LOGIN_FAILED 401
 * - 응답 모양은 mocks/auth_*.json 그대로
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    public record SignupRequest(
            @NotBlank @Email @Size(max = 255) String email,
            @NotBlank @Size(min = 8, max = 64) String password,
            @NotBlank @Pattern(regexp = "SEONGSU|HONGDAE|GANGNAM") String region) {
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {
    }

    @PostMapping("/signup")
    public ResponseEntity<ApiResponse<AuthService.UserResponse>> signup(@Valid @RequestBody SignupRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(auth.signup(request)));
    }

    @PostMapping("/login")
    public ApiResponse<AuthService.LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.success(auth.login(request));
    }
}
