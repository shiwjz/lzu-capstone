package com.capstone.backend.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "email", nullable = false,
            unique = true, length = 255)
    private String email;

    @Column(name = "password_hash",
            nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "region", length = 100)
    private String region;

    @Column(name = "created_at",
            insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at",
            insertable = false, updatable = false)
    private LocalDateTime updatedAt;

    public User(String email, String passwordHash,
                String region) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.region = region;
    }
}
