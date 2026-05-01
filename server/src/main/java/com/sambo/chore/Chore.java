package com.sambo.chore;

import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * A chore in a household. Completion events live in {@link ChoreCompletion}
 * (many-to-many with users so "vi gjorde det tillsammans" works); the
 * {@code last_completed_at} column is denormalised here for fast list-sort.
 *
 * <p>Soft-archive lifecycle: {@code archived_at == null} = active and visible,
 * non-null = hidden from default list but history preserved.
 */
@Entity
@Table(name = "chore")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class Chore {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    @Column(nullable = false)
    private String name;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_completed_at")
    private Instant lastCompletedAt;

    /** Forward-looking — when this chore is supposed to happen next. Null = unscheduled. */
    @Column(name = "scheduled_for")
    private Instant scheduledFor;

    /** Null = active. Set timestamp = soft-archived at that moment. */
    @Column(name = "archived_at")
    private Instant archivedAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }

    public boolean isArchived() {
        return archivedAt != null;
    }
}
