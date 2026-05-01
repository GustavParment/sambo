package com.sambo.budget;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Immutable;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Read-only projection over the {@code v_budget_category_status} SQL view.
 * Each row = one (period, category) pair with budgeted / spent / remaining
 * already aggregated in the database. See V1__init_schema.sql.
 */
@Entity
@Immutable
@Table(name = "v_budget_category_status")
@Getter
@NoArgsConstructor @AllArgsConstructor
public class BudgetCategoryStatusView {

    @Id
    @Column(name = "allocation_id")
    private UUID allocationId;

    @Column(name = "period_id", nullable = false)
    private UUID periodId;

    @Column(name = "household_id", nullable = false)
    private UUID householdId;

    @Column(name = "year", nullable = false)
    private int year;

    @Column(name = "month", nullable = false)
    private int month;

    @Column(name = "category_id", nullable = false)
    private UUID categoryId;

    @Column(name = "category_name", nullable = false)
    private String categoryName;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "budgeted_amount", nullable = false)
    private BigDecimal budgetedAmount;

    @Column(name = "spent_amount", nullable = false)
    private BigDecimal spentAmount;

    @Column(name = "remaining_amount", nullable = false)
    private BigDecimal remainingAmount;
}
