package com.capstone.backend.repository;

import com.capstone.backend.domain.UserAllergy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserAllergyRepository
        extends JpaRepository<UserAllergy, Long> {

    List<UserAllergy> findByUser_UserId(Long userId);
}
