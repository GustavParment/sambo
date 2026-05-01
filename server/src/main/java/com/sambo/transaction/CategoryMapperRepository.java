package com.sambo.transaction;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CategoryMapperRepository extends JpaRepository<CategoryMapper, UUID> {

    List<CategoryMapper> findByHouseholdId(UUID householdId);
}
