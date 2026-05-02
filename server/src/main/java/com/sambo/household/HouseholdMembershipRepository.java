package com.sambo.household;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface HouseholdMembershipRepository
    extends JpaRepository<HouseholdMembership, HouseholdMembershipId> {

    List<HouseholdMembership> findByUserId(UUID userId);

    List<HouseholdMembership> findByHouseholdId(UUID householdId);

    Optional<HouseholdMembership> findByUserIdAndHouseholdId(UUID userId, UUID householdId);

    long countByUserId(UUID userId);

    long countByHouseholdId(UUID householdId);
}
