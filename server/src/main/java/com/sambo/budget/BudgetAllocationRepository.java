package com.sambo.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BudgetAllocationRepository extends JpaRepository<BudgetAllocation, UUID> {

    List<BudgetAllocation> findByPeriodId(UUID periodId);

    Optional<BudgetAllocation> findByPeriodIdAndCategoryId(UUID periodId, UUID categoryId);
}
