package com.sambo.overview.dto;

import java.util.UUID;

/**
 * A user who completed at least one chore in the overview window.
 * Deliberately carries no count — the dashboard shows the household total
 * and a flat list of participants, not a per-person scoreboard.
 */
public record ChoreParticipantDto(UUID userId, String displayName) {}
