package com.sambo.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface BudgetCategoryStatusRepository extends JpaRepository<BudgetCategoryStatusView, UUID> {

    List<BudgetCategoryStatusView> findByHouseholdIdAndYearAndMonthOrderBySortOrderAsc(
        UUID householdId, int year, int month
    );
}
