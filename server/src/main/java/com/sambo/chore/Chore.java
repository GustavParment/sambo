package com.sambo.chore;

import com.sambo.household.AppUser;
import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Lean MVP shape per design notes: a fixed list of chores, each with
 * "last completed when, by whom". UI shows e.g.
 * "3 days since vacuumed (Sven did it last)".
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

    @Column(name = "last_completed_at")
    private Instant lastCompletedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_completed_by")
    private AppUser lastCompletedBy;
}
