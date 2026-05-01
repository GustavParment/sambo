package com.sambo.chore.dto;

import com.sambo.chore.Chore;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/**
 * One chore as the client sees it.
 *
 * @param daysSinceCompleted convenience for UI rendering — "3 days since"
 *                           — null if never completed.
 */
public record ChoreDto(
    UUID id,
    String name,
    Instant lastCompletedAt,
    UserSummaryDto lastCompletedBy,
    Long daysSinceCompleted
) {

    public static ChoreDto from(Chore c) {
        Long days = null;
        if (c.getLastCompletedAt() != null) {
            days = Duration.between(c.getLastCompletedAt(), Instant.now()).toDays();
        }
        return new ChoreDto(
            c.getId(),
            c.getName(),
            c.getLastCompletedAt(),
            c.getLastCompletedBy() != null ? UserSummaryDto.from(c.getLastCompletedBy()) : null,
            days
        );
    }
}
