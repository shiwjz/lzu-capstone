
package com.capstone.backend.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(
        name = "user_allergy",
        uniqueConstraints = @UniqueConstraint(
                columnNames = {"user_id", "allergy_name"}
        )
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserAllergy {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "allergy_id")
    private Long allergyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "allergy_name", nullable = false, length = 100)
    private String allergyName;

    public UserAllergy(User user, String allergyName) {
        this.user = user;
        this.allergyName = allergyName;
    }
}
