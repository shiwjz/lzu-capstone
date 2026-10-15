
package com.capstone.backend.global;

public record ApiResponse<T>(
        boolean success,
        String code,
        String message,
        T data
) {

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(
                true,
                "SUCCESS",
                "요청 성공",
                data
        );
    }

    public static <T> ApiResponse<T> success(
            String message, T data
    ) {
        return new ApiResponse<>(
                true,
                "SUCCESS",
                message,
                data
        );
    }

    public static ApiResponse<Void> error(
            ErrorCode errorCode
    ) {
        return new ApiResponse<>(
                false,
                errorCode.getCode(),
                errorCode.getMessage(),
                null
        );
    }
}
