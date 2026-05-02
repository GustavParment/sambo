package com.sambo.chore;

/**
 * Tiny projection used by {@link ChoreCompletionRepository#aggregateForHouseholdInWindow}.
 * Lives outside the {@code dto} convention because it's repository-internal —
 * the service maps it into the public {@code ChoreSummaryDto}.
 */
public record ChoreAggregate(long totalCompletions, long distinctChoresDone) {}
