package com.sambo.chore;

import com.sambo.household.AppUser;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * Append-only event: a single instance of "this chore got done at this time
 * by these participants". The set of users is many-to-many via
 * {@code chore_completion_user}.
 */
@Entity
@Table(name = "chore_completion")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class ChoreCompletion {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "chore_id", nullable = false)
    private Chore chore;

    @Column(name = "completed_at", nullable = false)
    private Instant completedAt;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "chore_completion_user",
        joinColumns = @JoinColumn(name = "completion_id"),
        inverseJoinColumns = @JoinColumn(name = "user_id")
    )
    @Builder.Default
    private Set<AppUser> users = new HashSet<>();
}
