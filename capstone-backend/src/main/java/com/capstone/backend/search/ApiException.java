package com.capstone.backend.search;

/**
 * 검색·코스 API 에러 (명세 에러 코드표랑 같은 코드·HTTP 상태)
 * - CONDITION_MISSING 422, PLACE_NOT_FOUND·COURSE_NOT_FOUND·SHARE_NOT_FOUND 404, INVALID_INPUT 400
 * - 정헌 ErrorCode에 같은 코드 추가되면 CustomException으로 바꿔도 됨
 */
public class ApiException extends RuntimeException {

    private final String code;
    private final int status;

    public ApiException(String code, int status, String message) {
        super(message);
        this.code = code;
        this.status = status;
    }

    public static ApiException invalid(String message) {
        return new ApiException("INVALID_INPUT", 400, message);
    }

    public static ApiException notFound(String code, String message) {
        return new ApiException(code, 404, message);
    }

    public String code() {
        return code;
    }

    public int status() {
        return status;
    }
}
