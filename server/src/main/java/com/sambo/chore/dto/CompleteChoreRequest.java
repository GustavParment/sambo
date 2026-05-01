package com.sambo.chore.dto;

import java.util.List;
import java.util.UUID;

/**
 * Body for {@code POST /api/chores/{id}/complete}.
 *
 * @param userIds explicit list of participants. Null or empty → defaults to
 *                just the calling user (legacy single-user behaviour).
 */
public record CompleteChoreRequest(List<UUID> userIds) {}
