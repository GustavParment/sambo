package com.sambo.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.YearMonth;
import java.util.Optional;
import java.util.UUID;

public interface BudgetPeriodRepository extends JpaRepository<BudgetPeriod, UUID> {

    Optional<BudgetPeriod> findByHouseholdIdAndYearAndMonth(UUID householdId, int year, int month);

    default Optional<BudgetPeriod> findByHouseholdAndYearMonth(UUID householdId, YearMonth ym) {
        return findByHouseholdIdAndYearAndMonth(householdId, ym.getYear(), ym.getMonthValue());
    }
}
