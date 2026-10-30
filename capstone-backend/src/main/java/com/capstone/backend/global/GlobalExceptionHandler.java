package com.capstone.backend.global;

import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(CustomException.class)
    public ResponseEntity<ApiResponse<Void>> handleCustom(
            CustomException exception
    ) {
        ErrorCode errorCode = exception.getErrorCode();

        return ResponseEntity
                .status(errorCode.getStatus())
                .body(ApiResponse.error(errorCode));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(
            MethodArgumentNotValidException exception
    ) {
        return ResponseEntity
                .badRequest()
                .body(ApiResponse.error(ErrorCode.INVALID_INPUT));
    }

    // 9주차 추가 (예민)
    // - 없는 주소: 500 대신 404 NOT_READY → 앱이 '준비 중'으로 처리
    @ExceptionHandler({NoResourceFoundException.class, HttpRequestMethodNotSupportedException.class})
    public ResponseEntity<ApiResponse<Void>> handleNotFound(
            Exception exception
    ) {
        return ResponseEntity
                .status(ErrorCode.NOT_READY.getStatus())
                .body(ApiResponse.error(ErrorCode.NOT_READY));
    }

    // - JSON 모양이 틀리거나 필수 파라미터 빠짐: 500 대신 400 INVALID_INPUT
    @ExceptionHandler({HttpMessageNotReadableException.class, MissingServletRequestParameterException.class})
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(
            Exception exception
    ) {
        return ResponseEntity
                .badRequest()
                .body(ApiResponse.error(ErrorCode.INVALID_INPUT));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(
            Exception exception
    ) {
        // 실제 운영 환경에서는 로깅 도구로 예외 기록
        return ResponseEntity
                .internalServerError()
                .body(ApiResponse.error(
                        ErrorCode.INTERNAL_SERVER_ERROR
                ));
    }
}
