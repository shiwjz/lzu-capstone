package com.capstone.backend.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "user_preference",
        uniqueConstraints = @UniqueConstraint(
                columnNames = {"user_id", "atmosphere"}
        )
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserPreference {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "preference_id")
    private Long preferenceId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "atmosphere", nullable = false, length = 100)
    private String atmosphere;

    @Column(name = "updated_at",
            insertable = false, updatable = false)
    private LocalDateTime updatedAt;

    public UserPreference(User user, String atmosphere) {
        this.user = user;
        this.atmosphere = atmosphere;
    }
}
