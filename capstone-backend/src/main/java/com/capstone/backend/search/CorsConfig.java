package com.capstone.backend.search;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;

/**
 * 크롬(Flutter 웹)에서 서버 부를 때 막히지 않게 /api 전체 허용 - 김예민
 * - 컨트롤러별 @CrossOrigin만 있으면 아직 없는 API(회원·내 설정)는 CORS로 막혀서
 *   앱이 '없음'이 아니라 '연결 실패'로 받음 → 필터로 전체에 적용
 * - 배포 후에는 allowedOriginPatterns를 앱 주소로 좁히기 (@성정헌)
 */
@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return new CorsFilter(source);
    }
}
