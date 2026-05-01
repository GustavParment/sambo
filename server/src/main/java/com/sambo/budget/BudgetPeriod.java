package com.sambo.budget;

import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * One row per (household, year, month). Acts as the parent of monthly allocations.
 */
@Entity
@Table(
    name = "budget_period",
    uniqueConstraints = @UniqueConstraint(columnNames = {"household_id", "year", "month"})
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class BudgetPeriod {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    @Column(name = "year", nullable = false)
    private int year;

    @Column(name = "month", nullable = false)
    private int month;
}
