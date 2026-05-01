package com.sambo.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface HouseholdCategoryRepository extends JpaRepository<HouseholdCategory, UUID> {

    List<HouseholdCategory> findByHouseholdIdOrderBySortOrderAsc(UUID householdId);
}
