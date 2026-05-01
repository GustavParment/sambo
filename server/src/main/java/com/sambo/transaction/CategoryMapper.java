package com.sambo.transaction;

import com.sambo.budget.HouseholdCategory;
import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * Maps a substring keyword (case-insensitive, e.g. "willys", "hemköp")
 * found in a transaction description to a household category.
 * The "secret sauce" — Tink's own categories are too coarse.
 */
@Entity
@Table(
    name = "category_mapper",
    uniqueConstraints = @UniqueConstraint(columnNames = {"household_id", "keyword"})
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class CategoryMapper {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    /** Matched as a case-insensitive substring against the transaction description. */
    @Column(nullable = false)
    private String keyword;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private HouseholdCategory category;
}
