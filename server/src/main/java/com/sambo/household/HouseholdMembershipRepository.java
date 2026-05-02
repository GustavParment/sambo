package com.sambo.household;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface HouseholdMembershipRepository
    extends JpaRepository<HouseholdMembership, HouseholdMembershipId> {

    List<HouseholdMembership> findByUserId(UUID userId);

    List<HouseholdMembership> findByHouseholdId(UUID householdId);

    /**
     * Same as {@link #findByHouseholdId(UUID)} but eagerly loads the
     * {@code user} side so callers can read {@code displayName} / etc
     * outside the transaction. Use this from controller methods where
     * {@code open-in-view: false} would otherwise trip a
     * {@code LazyInitializationException}.
     */
    @Query("SELECT m FROM HouseholdMembership m JOIN FETCH m.user "
        + "WHERE m.household.id = :householdId")
    List<HouseholdMembership> findByHouseholdIdFetchingUser(UUID householdId);

    /**
     * Eager variant of {@link #findByUserId(UUID)} that also pulls the
     * household side, so memberships can be DTO-mapped (with household
     * name) outside the transaction.
     */
    @Query("SELECT m FROM HouseholdMembership m JOIN FETCH m.household "
        + "WHERE m.user.id = :userId")
    List<HouseholdMembership> findByUserIdFetchingHousehold(UUID userId);

    Optional<HouseholdMembership> findByUserIdAndHouseholdId(UUID userId, UUID householdId);

    long countByUserId(UUID userId);

    long countByHouseholdId(UUID householdId);
}
