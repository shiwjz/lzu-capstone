package com.capstone.backend.repository;

import com.capstone.backend.domain.UserPreference;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserPreferenceRepository
        extends JpaRepository<UserPreference, Long> {

    List<UserPreference> findByUser_UserId(Long userId);
}
