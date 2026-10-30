package com.capstone.backend.user;

import com.capstone.backend.domain.User;
import com.capstone.backend.domain.UserAllergy;
import com.capstone.backend.domain.UserPreference;
import com.capstone.backend.global.CustomException;
import com.capstone.backend.global.ErrorCode;
import com.capstone.backend.repository.UserAllergyRepository;
import com.capstone.backend.repository.UserPreferenceRepository;
import com.capstone.backend.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 내 설정 (지역·분위기·알레르기) - 김예민 (정헌 9주차 할 일 대신)
 * - 저장되는 곳: users.region, user_preference.atmosphere(한 줄씩), user_allergy.allergy_name(한 줄씩)
 * - 수정은 목록 지우고 다시 저장 (명세 '목록은 지우고 다시 저장')
 * - 로그인하고 검색하면 SearchController가 이 값을 검색 조건에 넣음
 */
@Service
public class PreferenceService {

    static final Set<String> REGIONS = Set.of("SEONGSU", "HONGDAE", "GANGNAM");
    static final Set<String> ALLERGIES = Set.of("SHELLFISH", "SEAFOOD", "PEANUT", "MILK", "EGG", "WHEAT");

    private final UserRepository users;
    private final UserPreferenceRepository preferences;
    private final UserAllergyRepository allergies;

    public PreferenceService(UserRepository users, UserPreferenceRepository preferences,
                             UserAllergyRepository allergies) {
        this.users = users;
        this.preferences = preferences;
        this.allergies = allergies;
    }

    /** GET·PUT /api/users/me/preferences 요청·응답 (mocks/preferences.json 모양) */
    public record Preferences(String region, List<String> atmospheres, List<String> allergies) {
    }

    @Transactional(readOnly = true)
    public Preferences get(Long userId) {
        User user = user(userId);
        List<String> moods = preferences.findByUser_UserId(userId).stream()
                .sorted(Comparator.comparing(UserPreference::getPreferenceId))
                .map(UserPreference::getAtmosphere)
                .toList();
        List<String> allergyCodes = allergies.findByUser_UserId(userId).stream()
                .sorted(Comparator.comparing(UserAllergy::getAllergyId))
                .map(UserAllergy::getAllergyName)
                .toList();
        return new Preferences(user.getRegion(), moods, allergyCodes);
    }

    @Transactional
    public Preferences update(Long userId, Preferences req) {
        Preferences clean = validate(req);
        User user = user(userId);
        user.changeRegion(clean.region());

        // 지우고 바로 flush → 같은 값 다시 넣어도 (user_id, 값) 중복 제약에 안 걸림
        preferences.deleteAll(preferences.findByUser_UserId(userId));
        allergies.deleteAll(allergies.findByUser_UserId(userId));
        preferences.flush();
        allergies.flush();

        clean.atmospheres().forEach(a -> preferences.save(new UserPreference(user, a)));
        clean.allergies().forEach(a -> allergies.save(new UserAllergy(user, a)));
        return clean;
    }

    /**
     * 값 검사·정리 (DB 없이 테스트하려고 static)
     * - region: SEONGSU/HONGDAE/GANGNAM 또는 null
     * - atmospheres: 앞뒤 공백 빼고, 빈 값·중복 빼고, 최대 10개·각 30자 (태그 이름은 예린 태그 사전 기준, 서버는 이름 검사 안 함)
     * - allergies: 명세 알레르기 코드 6개만
     */
    static Preferences validate(Preferences req) {
        if (req == null) throw new CustomException(ErrorCode.INVALID_INPUT);
        if (req.region() != null && !REGIONS.contains(req.region())) {
            throw new CustomException(ErrorCode.INVALID_INPUT);
        }
        Set<String> moods = new LinkedHashSet<>();
        for (String a : req.atmospheres() == null ? List.<String>of() : req.atmospheres()) {
            if (a == null || a.isBlank()) continue;
            String t = a.trim();
            if (t.length() > 30) throw new CustomException(ErrorCode.INVALID_INPUT);
            moods.add(t);
        }
        if (moods.size() > 10) throw new CustomException(ErrorCode.INVALID_INPUT);
        Set<String> codes = new LinkedHashSet<>();
        for (String a : req.allergies() == null ? List.<String>of() : req.allergies()) {
            if (a == null || !ALLERGIES.contains(a)) throw new CustomException(ErrorCode.INVALID_INPUT);
            codes.add(a);
        }
        return new Preferences(req.region(), List.copyOf(moods), List.copyOf(codes));
    }

    private User user(Long userId) {
        return users.findById(userId).orElseThrow(() -> new CustomException(ErrorCode.USER_NOT_FOUND));
    }
}
