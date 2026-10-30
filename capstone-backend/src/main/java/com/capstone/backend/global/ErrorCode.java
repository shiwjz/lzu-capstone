package com.capstone.backend.global;

import org.springframework.http.HttpStatus;

public enum ErrorCode {

    INVALID_INPUT(
            HttpStatus.BAD_REQUEST,
            "INVALID_INPUT",
            "잘못된 요청입니다."
    ),

    USER_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "USER_NOT_FOUND",
            "사용자를 찾을 수 없습니다."
    ),

    DUPLICATE_EMAIL(
            HttpStatus.CONFLICT,
            "DUPLICATE_EMAIL",
            "이미 사용 중인 이메일입니다."
    ),

    UNAUTHORIZED(
            HttpStatus.UNAUTHORIZED,
            "UNAUTHORIZED",
            "로그인이 필요하거나 인증이 만료되었습니다."
    ),

    LOGIN_FAILED(
            HttpStatus.UNAUTHORIZED,
            "LOGIN_FAILED",
            "이메일 또는 비밀번호가 올바르지 않습니다."
    ),

    PLACE_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "PLACE_NOT_FOUND",
            "장소를 찾을 수 없습니다."
    ),

    COURSE_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "COURSE_NOT_FOUND",
            "코스를 찾을 수 없습니다."
    ),

    SHARE_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "SHARE_NOT_FOUND",
            "공유 코드를 찾을 수 없습니다."
    ),

    CONDITION_MISSING(
            HttpStatus.UNPROCESSABLE_ENTITY,
            "CONDITION_MISSING",
            "필수 검색 조건이 누락되었습니다."
    ),

    AI_UNAVAILABLE(
            HttpStatus.SERVICE_UNAVAILABLE,
            "AI_UNAVAILABLE",
            "AI 서비스를 사용할 수 없습니다."
    ),

    INTERNAL_SERVER_ERROR(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "INTERNAL_SERVER_ERROR",
            "서버 내부 오류가 발생했습니다."
    );

    private final HttpStatus status;
    private final String code;
    private final String message;

    ErrorCode(HttpStatus status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }
}
