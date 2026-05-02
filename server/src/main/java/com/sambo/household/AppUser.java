package com.sambo.household;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_user", uniqueConstraints = @UniqueConstraint(columnNames = "email"))
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class AppUser {

    @Id
    @GeneratedValue
    private UUID id;

    /**
     * The household the user is currently "logged into". Nullable so that a
     * user who has left every household can still authenticate and pick or
     * create one. Membership is the source of truth — see HouseholdMembership.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "active_household_id")
    private Household activeHousehold;

    @Column(nullable = false)
    private String email;

    @Column(nullable = false)
    private String displayName;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
