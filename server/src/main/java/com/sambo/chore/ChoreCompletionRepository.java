package com.sambo.chore;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChoreCompletionRepository extends JpaRepository<ChoreCompletion, UUID> {

    Optional<ChoreCompletion> findFirstByChoreIdOrderByCompletedAtDesc(UUID choreId);

    /**
     * Total completion count + how many distinct chores were touched, for a
     * household, within {@code [from, to)}.
     */
    @Query("""
        SELECT new com.sambo.chore.ChoreAggregate(
            COUNT(cc), COUNT(DISTINCT cc.chore.id))
        FROM ChoreCompletion cc
        WHERE cc.chore.household.id = :householdId
          AND cc.completedAt >= :from
          AND cc.completedAt <  :to
    """)
    ChoreAggregate aggregateForHouseholdInWindow(UUID householdId, Instant from, Instant to);

    /**
     * Distinct user IDs that participated in at least one completion in the
     * given household + window. The frontend pairs these with displayName
     * via the household's membership list — ordering is unspecified, the
     * UI presents this as a flat unordered list.
     */
    @Query("""
        SELECT DISTINCT u.id
        FROM ChoreCompletion cc JOIN cc.users u
        WHERE cc.chore.household.id = :householdId
          AND cc.completedAt >= :from
          AND cc.completedAt <  :to
    """)
    List<UUID> participantUserIdsForHouseholdInWindow(UUID householdId, Instant from, Instant to);

    /**
     * Completion count per user for a household within [from, to).
     * Returns one row per user who participated in at least one completion
     * event, sorted descending by count. Uses interface-based projection
     * to avoid constructor expressions.
     */
    @Query("""
        SELECT u.id AS userId, COUNT(cc) AS completionCount
        FROM ChoreCompletion cc JOIN cc.users u
        WHERE cc.chore.household.id = :householdId
          AND cc.completedAt >= :from
          AND cc.completedAt <  :to
        GROUP BY u.id
        ORDER BY COUNT(cc) DESC
    """)
    List<LeaderboardRow> leaderboardForHousehold(UUID householdId, Instant from, Instant to);
}
