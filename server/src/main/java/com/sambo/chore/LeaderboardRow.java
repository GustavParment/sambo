package com.sambo.chore;

import java.util.UUID;

/** Spring Data interface-based projection for leaderboard aggregation. */
public interface LeaderboardRow {
    UUID getUserId();
    long getCompletionCount();
}
