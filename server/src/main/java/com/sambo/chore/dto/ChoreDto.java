package com.sambo.chore.dto;

import com.sambo.chore.Chore;
import com.sambo.chore.ChoreCompletion;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * One chore as the client sees it.
 *
 * @param lastCompletedBy    participants of the most recent completion (0/1/many).
 * @param daysSinceCompleted UI shortcut — null if never completed.
 * @param archivedAt         null = active. Non-null = soft-archived at that time.
 * @param scheduledFor       null = unscheduled. Future-looking deadline.
 */
public record ChoreDto(
    UUID id,
    String name,
    Instant createdAt,
    Instant lastCompletedAt,
    Instant scheduledFor,
    Instant archivedAt,
    List<UserSummaryDto> lastCompletedBy,
    Long daysSinceCompleted
) {

    public static ChoreDto from(Chore c, ChoreCompletion lastCompletion) {
        Long days = c.getLastCompletedAt() != null
            ? Duration.between(c.getLastCompletedAt(), Instant.now()).toDays()
            : null;
        List<UserSummaryDto> participants = lastCompletion == null
            ? List.of()
            : lastCompletion.getUsers().stream()
                .sorted(Comparator.comparing(u -> u.getDisplayName().toLowerCase()))
                .map(UserSummaryDto::from)
                .toList();
        return new ChoreDto(
            c.getId(),
            c.getName(),
            c.getCreatedAt(),
            c.getLastCompletedAt(),
            c.getScheduledFor(),
            c.getArchivedAt(),
            participants,
            days
        );
    }
}
