package com.sambo.budget;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Budgeted amount for a category in a specific period.
 * (period_id, category_id) is unique.
 */
@Entity
@Table(
    name = "budget_allocation",
    uniqueConstraints = @UniqueConstraint(columnNames = {"period_id", "category_id"})
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class BudgetAllocation {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "period_id", nullable = false)
    private BudgetPeriod period;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private HouseholdCategory category;

    @Column(name = "budgeted_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal budgetedAmount;
}
