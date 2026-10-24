package com.capstone.backend.search;

import org.springframework.http.ResponseEntity;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 응답 틀 { success, code, message, data } (정헌 ApiResponse랑 같은 모양)
 * - 정헌 ApiResponse에 실패 응답 만드는 메서드 생기면 그걸로 바꿔도 JSON은 똑같음
 */
public final class ApiBody {

    private ApiBody() {
    }

    public static ResponseEntity<Map<String, Object>> ok(Object data) {
        return ResponseEntity.ok(body(true, "SUCCESS", "요청 성공", data));
    }

    public static ResponseEntity<Map<String, Object>> error(ApiException e) {
        return ResponseEntity.status(e.status()).body(body(false, e.code(), e.getMessage(), null));
    }

    public static Map<String, Object> body(boolean success, String code, String message, Object data) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("success", success);
        m.put("code", code);
        m.put("message", message);
        m.put("data", data);
        return m;
    }
}
