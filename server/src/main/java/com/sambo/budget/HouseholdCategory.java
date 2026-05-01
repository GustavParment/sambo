package com.sambo.budget;

import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * A category template at the household level (e.g. "Mat", "Hushåll", "Städ").
 * Persists across months — monthly amounts live in {@link BudgetAllocation}.
 */
@Entity
@Table(
    name = "household_category",
    uniqueConstraints = @UniqueConstraint(columnNames = {"household_id", "name"})
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class HouseholdCategory {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    @Column(nullable = false)
    private String name;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;
}
