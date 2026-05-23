package com.sambo.chore.dto;

import java.util.UUID;

public record LeaderboardEntryDto(
    UUID userId,
    String displayName,
    String avatarColor,
    long count
) {}
