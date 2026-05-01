package com.sambo.chore;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ChoreRepository extends JpaRepository<Chore, UUID> {

    List<Chore> findByHouseholdIdOrderByNameAsc(UUID householdId);
}
