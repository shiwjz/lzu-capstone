package com.capstone.backend.controller;

import com.capstone.backend.global.ApiResponse;
import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {

    @GetMapping("/api/test")
    public ApiResponse<String> test() {
        return ApiResponse.success(
                "공통 응답 테스트 성공!"
        );
    }

    @GetMapping("/api/test/error")
    public ApiResponse<String> testError() {
        throw new CustomException(ErrorCode.USER_NOT_FOUND);
    }
}
